# Spark SQL and Dataset API

## Non-lazy Evaluation in `DataFrameReader.load`

Let's start with a simple example:

```scala
val rdd = spark.sparkContext.parallelize(Seq(
  """{"foo": 1}""", """{"bar": 2}"""
))

val foos = rdd.filter(_.contains("foo"))

val df = spark.read.json(foos)

```

This piece of code looks quite innocent. There is no obvious action here so one could expect it will be lazily evaluated. Reality is quite different though.

To be able to infer schema for `df`, Spark will have to evaluate `foos` with all it's dependencies. By default, that will require full data scan. In this particular case it is not a huge problem. Nevertheless, when working on a large dataset with complex dependencies this can become expensive.


Non-lazy evaluation takes place when a schema cannot by directly established by it's source type alone (like for example the `text` data source).

Non-lazy evaluation can take one of following forms:

- metadata access - This is specific to structured sources like relational databases, [Cassandra](http://stackoverflow.com/q/33897586/1560062) or Parquet where schema can be determined without accessing data directly.
- data access - This happens with unstructured source which cannot provide schema information. Some examples include JSON, XML or MongoDB.

While the impact of the former variant should be negligible, the latter one can severely overall performance and put significant pressure on the external systems.

### Explicit Schema

The most efficient and universal solution is to provide schema directly:

```scala
import org.apache.spark.sql.types.{LongType, StructType, StructField}

val schema = StructType(Seq(
  StructField("bar", LongType, true),
  StructField("foo", LongType, true)
))

val dfWithSchema = spark.read.schema(schema).json(foos)

```

It not only can provide significant performance boost but also serves as simple an input validation mechanism.

While initially schema may be unknown or to complex to be created manually, it can be easily converted to and from a JSON string and reused if needed.

```scala
import org.apache.spark.sql.types.DataType

val schemaJson: String = df.schema.json

val schemaOption: Option[StructType] =  DataType.fromJson(schemaJson) match {
  case s: StructType => Some(s)
  case _ => None
}

```

###  Sampling for Schema Inference

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

If data contains infrequent fields, these fields will be missing from the final output. But it is only the part of the problem. There is no guarantee that sampling can or will be pushed down to the source. For example JSON source is using standard `RDD.sample`. It means that even with low sampling ratio [we don't avoid full data scan](http://stackoverflow.com/q/32229941/1560062).

If we can access data directly, we can try to create a representative sample outside standard Spark workflow. This sample can further be used to infer schema. This can be particularly beneficial when we have a priori knowledge about the data structure which allows us to achieve good coverage with a small number of records. General approach can be summarized as follows:

- Create representative sample of the original data source.
- Read it using `DataFrameReader`.
- Extract `schema`.
- Pass the `schema` to `DataFrameReader.schema` method to read the main dataset.


### PySpark Specific Considerations


Unlike Scala, Pyspark cannot use static type information when we convert existing `RDD` to `DataFrame`. If `createDataFrame` (`toDF`) is called without providing `schema`, or `schema` is not a `DataType`, column types have to be inferred by performing data scan.

By default (`samplingRatio` is `None`), Spark [tries to establish schema using the first 100 rows](https://github.com/apache/spark/blob/branch-2.0/python/pyspark/sql/session.py#L324-L328). At the first glance it doesn't look that bad. Problems start when `RDD` are created using "wide" transformations.

Let's illustrate this with a simple example:


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

So far so good. Now let's perform a simple aggregation before calling `toDF` and repeat this experiment with a clean context:

```python
from operator import add

(sc.parallelize(data, 10)
    .map(lambda x: x + (1, ))
    .reduceByKey(add)
    .toDF())

list(get_jobs(sc))
## [(1, 14), (0, 11)]
```

As you can see we had to had evaluate the complete lineage. If you're not convinced by the numbers you can always check the Spark UI.

Finally, we can add schema to make this operation lazy:

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

## Window Functions

### Understanding Window Functions

Window functions can be used to perform a multi-row operation without collapsing the final results. While many window operations can be expressed using some combination of aggregations and joins, window functions provide concise and highly expressive syntax with capabilities reaching much beyond standard SQL expressions.

Each window function call require `OVER` clause which provides a window definition based on grouping (`PARTITION BY`), ordering (`ORDER BY`) and range (`ROWS` / `RANGE BETWEEN`). Window definition can be empty or use some subset of these rules depending on the function being used.


### Window Definitions

#### `PARTITION BY` Clause

`PARTITION BY` clause partitions data into groups based on a sequence of expressions. It is more or less equivalent to `GROUP BY` clause in standard aggregations. If not provided it will apply operation on all records. See [Requirements and Performance Considerations](#requirements-and-performance-considerations).

#### `ORDER BY` Clause

`ORDER BY` clause is used to order data based on a sequence of expressions. It is required for window functions which depend on the order of rows like `LAG` / `LEAD` or `FIRST` / `LAST`.

#### `ROWS BETWEEN` and `RANGE BETWEEN` Clauses

`ROWS BETWEEN` / `RANGE BETWEEN` clauses defined respectively number of rows and range of rows to be included in a single window frame. Each frame definitions contains two parts:

- window frame preceding (`UNBOUNDED PRECEDING`, `CURRENT ROW`, value)
- window frame following (`UNBOUNDED FOLLOWING`, `CURRENT ROW`, value)

In raw SQL both values should be positive numbers:


```SQL

OVER (ORDER BY ... ROWS BETWEEN 1 AND 5)  -- include one preceding and 5 following rows

```

In `DataFrame` DSL values should be negative for preceding and positive for following range:

```scala

Window.orderBy($"foo").rangeBetween(-10.0, 15.0)  // Take rows where `foo` is between current - 10.0 and current + 15.0.

```

For unbounded windows one should use  `-sys.maxsize` / `sys.maxsize` and `Long.MinValue` / `Long.MaxValue` in Python and Scala respectively.


Default frame specification depends on other aspects of a given window defintion:

- if the `ORDER BY` clause is specified and the function accepts the frame specification, then the frame specification is defined by `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`,
- otherwise the frame specification is defined by `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

The first rules has some interesting consequences. For `last("foo").over(Window.orderBy($"foo"))` will always return the current `foo`.

It is also important to note that right now performance impact of unbounded frame definition is asymmetric with `UNBOUNDED FOLLOWING` being significantly more expensive than `UNBOUNDED PRECEDING`. See [SPARK-8816](https://issues.apache.org/jira/browse/SPARK-8816).


### Example Usage

Select the row with maximum `value` per `group`:

```python
from pyspark.sql.functions import row_number
from pyspark.sql.window import Window

w = Window().partitionBy("group").orderBy(col("value").desc())

(df
  .withColumn("rn", row_number().over(w))
  .where(col("rn") == 1))

```

Select rows with `value` larger than an average for `group`


```scala
import org.apache.spark.sql.avg
import org.apache.spark.sql.expressions.Window

val w = Window.partitionBy($"group")

df.withColumn("group_avg", avg($"value").over(w)).where($"value" > $"group_avg")

```

Compute sliding average of the `value` with window [-3, +3] rows per `group` ordered by `date`

```r
w <- window.partitionBy(df$group) %>% orderBy(df$date) %>% rowsBetween(-3, 3)

df %>% withColumn("sliding_mean", over(avg(df$value), w))

```


### Requirements and Performance Considerations

- In Spark < 2.0.0 window functions are supported only with `HiveContext`. Since Spark 2.0.0 Spark provides native window functions implementation independent of Hive.
- As a rule of thumb window functions should always contain `PARTITION BY` clause. Without it all data will be moved to a single partition:

  ```scala
  val df = sc.parallelize((1 to 100).map(x => (x, x)), 10).toDF("id", "x")

  val w = Window.orderBy($"x")

  df.rdd.glom.map(_.size).collect
  // Array[Int] = Array(10, 10, 10, 10, 10, 10, 10, 10, 10, 10)

  df.withColumn("foo", lag("x", 1).over(w)).rdd.glom.map(_.size).collect
  // Array[Int] = Array(100)
  ```

- in SparkR < 2.0.0 window functions are supported only in raw SQL by calling `sql` method on registered table.

## DataFrame Schema Nullablility

`org.apache.spark.sql.types.StructField` takes `nullable` argument that can be confusing for users which are used to RDBMS and can have unexpected runtime implications. Typically it is set automatically based on the few simple rules:

- If `DataFrame` is created from a local collection or RDD columns inherit nullability semantics of the input data:

  - If input type cannot be `null` (for example Scala numeric types) then `nullable` is set to `false`.
  - If input type can be `null` (Java boxed numerics, `String`) then `nullable` is set to `false`.

- Optional values are always nullable with `None` mapped to SQL `NULL`.

- If data is loaded from a source which doesn't support nullability constraints, like csv or JSON, fields are marked as `nullable`, even when [coressponding Scala type](https://spark.apache.org/docs/latest/sql-programming-guide.html#data-types) is not.

- Columns created from Python objects are always marked as `nullable`.

### Marking StructFields as Nullable

### Nullable Is not a Constraint

### Nullable Is Used to Optimize Query Plan

### Schema Inference by Reflection

## Reading Data Using JDBC Source

### Parallelizing Reads

Apache Spark provides a number of methods which can be used to import data using JDBC connections. When working with `RDD` API we can use [`JdbcRDD`](https://spark.apache.org/docs/latest/api/scala/index.html#org.apache.spark.rdd.JdbcRDD). For `Dataset` API we can choose between different `jdbc` readers. It is important to note that in the latter case reads are not always distributed.

While range based implementation:

```scala
jdbc(url: String, table: String, predicates: Array[String], connectionProperties: Properties): DataFrame
```

and predicate based implementation:

```scala
def jdbc(url: String, table: String, predicates: Array[String], connectionProperties: Properties): DataFrame
```

distribute reads between workers, the simplest implementation:

```scala
def jdbc(url: String, table: String, properties: Properties): DataFrame
```

as well as `format("jdbc")` followed by `load` (with a single exception shown below), delegate reads to a single worker.

This behavior has two main consequences:

- Reads are essentially sequential.
- Initial data distribution is skewed to a single machine.

Let's illustrate this behavior with examples. First let's create a simple database:

```shell
docker pull postgres:9.5

mkdir /tmp/docker-entrypoint-initdb.d
ENTRY='#!/bin/bash'"
set -e

echo \"log_statement = 'all'\" >> /var/lib/postgresql/data/postgresql.conf

psql -v ON_ERROR_STOP=1 --username 'postgres' <<-EOSQL
    SELECT pg_reload_conf();
    CREATE ROLE spark PASSWORD 'spark' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN;
    CREATE DATABASE spark OWNER spark;
    \\\\c spark
    CREATE TABLE data (
      id INTEGER,
      name TEXT,
      valid BOOLEAN DEFAULT true,
      ts TIMESTAMP DEFAULT now()
    );
    GRANT ALL PRIVILEGES ON TABLE data TO spark;

    INSERT INTO data VALUES
        (1, 'foo', TRUE, '2012-01-01 00:03:00'),
        (2, 'foo', FALSE, '2013-04-02 10:10:00'),
        (3, 'bar', TRUE, '2015-11-02 22:00:00'),
        (4, 'bar', FALSE, '2010-11-02 22:00:00');
EOSQL
"

printf "%s" "$ENTRY" > /tmp/docker-entrypoint-initdb.d/init-spark-db.sh

docker run \
    -v /tmp/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
    --name some-postgres \
    --rm \
    -p :5432:5432 \
    postgres:9.5
```

and start Spark loading JDBC driver:

```shell
bin/spark-shell --master "local[4]" --packages org.postgresql:postgresql:9.4.1212
```

And load the table:

```scala
val options = Map(
  "url" -> "jdbc:postgresql://127.0.0.1:5432/spark",
  "dbtable" -> "data",
  "driver" -> "org.postgresql.Driver",
  "user" -> "spark",
  "password" -> "spark"
)
val df = spark.read.format("jdbc").options(options).load

df.rdd.partitions.size
// Int = 1
```

As you can see there is only one partition created. While this experiment is not exactly reliable due to low number of records you can easily check that this behavior holds independent of the number of rows to be fetched (subsequent examples assume that we have only four records shown above):

```scala
val newData = spark.range(1000000)
  .select($"id", lit(""), lit(true), current_timestamp())
  .toDF("id", "name", "valid", "ts")

newData.write.format("jdbc").options(options).mode("append") .save
```
Since we enabled query logging in our database we can further confirm that by executing:

```scala`
df.rdd.foreach(_ => ())
```

and checking database logs. You should see only one `SELECT` statement executed against `data` table.

This behavior has a number of positive and negative consequences. Positive ones:

- It doesn't induce significant stress on the input source.
- It keeps consistent view of the input data (all records can be fetched in the same transactions).

Negative ones:

- It doesn't utilize cluster resources.
- Results in the highest possible data skew.
- Can easily overwhelm the single executor which has been choosen to fetch the data.

As mentioned above Spark provides two methods which be used for distributed data loading over JDBC. The first one partitions data using an integer column:

```scala
val dfPartitionedWithRanges = spark.read.options(options)
  .jdbc(options("url"), options("dbtable"), "id", 1, 5, 4, new java.util.Properties())

dfPartitionedWithRanges.rdd.partitions.size
// Int = 4

dfPartitionedWithRanges.rdd.glom.collect
// Array[Array[org.apache.spark.sql.Row]] = Array(
//   Array([1,foo,true,2012-01-01 00:03:00.0]),
//   Array([2,foo,false,2013-04-02 10:10:00.0]),
//   Array([3,bar,true,2015-11-02 22:00:00.0]),
//   Array([4,bar,false,2010-11-02 22:00:00.0]))
```

Partition column and bounds can provided using `options` as well:

```scala
val optionsWithBounds = options ++ Map(
  "partitionColumn" -> "id",
  "lowerBound" -> "1",
  "upperBound" -> "5",
  "numPartitions" -> "4"
)

spark.read.options(optionsWithBounds).format("jdbc").load
```

Another option we have is to use a sequence of predicates:

```scala
val predicates = Array(
  "valid", "NOT valid"
)

val dfPartitionedWithPreds = spark.read.options(options)
  .jdbc(options("url"), options("dbtable"), predicates, new java.util.Properties())

dfPartitionedWithPreds.rdd.partitions.size
// Int = 2

dfPartitionedWithPreds.rdd.glom.collect
// Array[Array[org.apache.spark.sql.Row]] = Array(
//   Array([1,foo,true,2012-01-01 00:03:00.0], [3,bar,true,2015-11-02 22:00:00.0]),
//   Array([2,foo,false,2013-04-02 10:10:00.0], [4,bar,false,2010-11-02 22:00:00.0]))
```

Compared to the basic reader these methods load data in a distributed mode but introduce a couple of problems:

- High number of concurrent reads can easily trothle the database.
- Every executor loads data using separate transaction so when operating on live databse it is not possible to guarantee consitent view.
- We need a set of mutually exclusive predicates to avoid duplicates.
- To get all relevant records we have to carefully adjust lower and upper bounds or predicates. For example `predicates` show above wouldn't include records with `valid` being `NULL`.

Conclusions:

- If available, consider using specialized data sources over JDBC connections.
- Consider using specialized (like PostgreSQL `COPY`) or genaric (like Apache Sqoop) bulk import / export tools.
- Be sure to understand performance implications of different JDBC data source variants, especially when working with production database.
- Consider using a separate replica for Spark jobs.

