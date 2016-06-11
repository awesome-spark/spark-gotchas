# DataFrame by example

## Non-lazy evaluation in `DataFrameReader.load`

Lets start with a simple example:

```scala
val rdd = spark.sparkContext.parallelize(Seq(
  """{"foo": 1}""", """{"bar": 2}"""
))

val foos = rdd.filter(_.contains("foo"))

val df = spark.read.json(foos)

```

This piece of code looks quite innocent. There is no obvious action here so one could expect it will be lazily evaluated. Reality is quite different though.

To be able to infer schema for `df` Spark will have to evaluate `foos` with all its dependencies and by default it requires full data scan. While in this particular case it is not a huge problem, when working on a large dataset with complex dependencies this can become expensive.


Non-lazy evaluation takes place when schema cannot by directly established by source type alone (like for example `text` data source) and can take one of two forms:

- metadata access - This is specific to structured sources like relational databases, [Cassandra](http://stackoverflow.com/q/33897586/1560062) or Parquet where schema can be determined without accessing data directly.
- data access - This happens with unstructured source which cannot provide schema information. Some examples include JSON, XML or MongoDB.

While the impact of the former variant should be negligible, the latter one can severely overall performance and put significant pressure on the external systems.

### Explicit schema

The most efficient and universal solution is to provide schema directly:

```scala
import org.apache.spark.sql.types.{LongType, StructType, StructField}

val schema = StructType(Seq(
  StructField("bar", LongType, true),
  StructField("foo", LongType, true)
))

val dfWithSchema = spark.read.schema(schema).json(foos)

```

It not only can provide significant performance boost but also serve as simple input validation mechanism.

While initially schema may be unknown or to complex to be created manually it can be easily converted to and from JSON string and reused if needed.

```scala
import org.apache.spark.sql.types.DataType

val schemaJson: String = df.schema.json

val schemaOption: Option[StructType] =  DataType.fromJson(schemaJson) match {
  case s: StructType => Some(s)
  case _ => None
}

```

###  Sampling for schema inference

Another possible approach is to infer schema on a subset of the input data. It can take one of two forms.

Some data sources provide `samplingRatio` option or its equivalent which can be used to reduced number of records considered for schema inference. For example with JSON source:

```scala
val sampled = spark.read.option("samplingRatio", "0.4").json(rdd)
```


The first problem with this approach becomes obvious when we take a look at the created schema (it can vary from run to run):


```scala
sampled.printSchema

// root
// |-- foo: long (nullable = true)

```

If data contains infrequent fields these will be missing from the final output. But it is only the part of the problem. There is no guarantee that sampling can or will be pushed down to the source. For example JSON source is using standard `RDD.sample`. It means that even with low sampling ratio [we don't avoid full data scan](http://stackoverflow.com/q/32229941/1560062).

If we can access data directly, we can try to create a representative sample outside standard Spark workflow. This sample can further used to infer schema. This can be particularly beneficial when we have a priori knowledge about data structure which allows us to achieve good coverage with a small number of records. General approach can summarized as follows:

- Create representative sample of the original data source.
- Read it using `DataFrameReader`.
- Extract `schema`.
- Pass `schema` to `DataFrameReader.schema` method to read main dataset.


### PySpark specific considerations


Unlike Scala Pyspark cannot use static type information when we convert existing `RDD` to `DataFrame`. If `createDataFrame` (`toDF`) is called without providing `schema`, or `schema` is not a `DataType`, column types have to be inferred by performing data scan.

By default (`samplingRatio` is `None`) Spark [tries to establish schema using the first 100 rows](https://github.com/apache/spark/blob/branch-2.0/python/pyspark/sql/session.py#L324-L328). At the first glance it doesn't look that bad. Problems start when `RDD` has been created using "wide" transformations. Lets illustrate this with a simple example:


```python
import requests

def get_jobs(sc):
    """ A simple helper to get a list of jobs for a given app"""
    base = "http://localhost:4040/api/v1/applications/{0}/jobs"
    url = base.format(sc.applicationId)
    for job in requests.get(url).json():
        yield job.get("jobId"), job.get("numTasks")

data = [(chr(i % 7 + 65), ) for i in range(1000)]

(sc
    .parallelize(data, 10)
    .toDF())

list(get_jobs(sc))
## [(0, 1)]
```

So far so good. Now lets add a simple aggregation before calling `toDF` and repeat this experiment with a clean context:

```python
from operator import add

(sc.parallelize(data, 10)
    .map(lambda x: x + (1, ))
    .reduceByKey(add)
    .toDF())

list(get_jobs(sc))
## [(1, 14), (0, 11)]
```

As you can see we had to had evaluate complete lineage. If you're not convinced by the numbers you can check Spark UI.

Finally we can add schema to make this operation lazy:

```python
from pyspark.sql.types import *

schema = StructType([
    StructField("_1", StringType(), False),
    StructField("_2", LongType(), False)
])

(sc.parallelize(data, 10)
    .map(lambda x: x + (1, ))
    .reduceByKey(add)
    .toDF(schema))

list(get_jobs(sc))
## []
```




