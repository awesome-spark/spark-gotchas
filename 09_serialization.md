# Serialization

## JVM

### Java Serialization

### Kryo Serialization

#### Kryo Registration

#### Closures Use Standard Java Serialization

#### Common Problems

##### Scala Maps With Defaults

While Kryo serializer can handle basic Scala `Maps`:


```scala
import org.apache.spark.{SparkContext, SparkConf}

val aMap = Map[String, Long]("foo" -> 1).withDefaultValue(0L)
aMap("bar")
// Long = 0

val conf = new SparkConf()
  .setAppName("bar")
  .set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")

val sc = new SparkContext(conf)
val rdd = sc.parallelize(Seq(aMap))

rdd.map(_("foo")).first
// Long = 1

```
unfortunately it doesn't serialize default arguments:

```scala

rdd.map(_("bar")).first

// 16/09/30 15:20:39 ERROR Executor: Exception in task 2.0 in stage 2.0 (TID 7)
// java.util.NoSuchElementException: key not found: bar
//     at scala.collection.MapLike$class.default(MapLike.scala:228)
//     ...
```

As [pointed out](http://apache-spark-developers-list.1001551.n3.nabble.com/java-util-NoSuchElementException-when-serializing-Map-with-default-value-tp19123p19139.html) by [Jakob Odersky](https://github.com/jodersky) this happens due to optimizations introduced in the [Chill](https://github.com/twitter/chill/blob/develop/chill-scala/src/main/scala/com/twitter/chill/Traversable.scala) library.

In general to ensure correct behavior it is better to use safe methods (`get`, `getOrElse`) instead of depending on defaults (`withDefault`, `withDefaultValue`).

## PySpark Serialization

In general PySpark provides 2-tier serialization mechanism defined by actual serialization engine, like `PickleSerializer`, and batching mechanism. An additional specialized serializer is used to serialize closures. It is important to note that Python classes cannot be serialized. It means that modules containing class definitions have to be accessible on every machine in the cluster.

### Python Serializers Characteristics

#### PickleSerializer

[`PickleSerializer`](https://spark.apache.org/docs/latest/api/python/pyspark.html?highlight=autobatchedserializer#pyspark.PickleSerializer) is a default serialization engine which wraps Python [`pickle`](https://docs.python.org/3.5/library/pickle.html#module-pickle). As already mentioned it is a default serialization engine used to serialize data in PySpark.

##### Python 2 vs Python 3

There is a subtle difference in `pickle` imports between Python 2 and Python 3. While the former one [imports `cPickle` directly](https://github.com/apache/spark/blob/v2.0.0-rc2/python/pyspark/serializers.py#L62), the latter one [depends on built-in fallback mechanism](https://github.com/apache/spark/blob/v2.0.0-rc2/python/pyspark/serializers.py#L66). It means that in Python 3 it is possible, although highly unlikely, that PySpark will use pure Python implementation. See also [What difference between pickle and _pickle in python 3?](http://stackoverflow.com/a/19191885/1560062).

#### MarshalSerializer

[`MarshalSerializer`](https://spark.apache.org/docs/latest/api/python/pyspark.html?highlight=autobatchedserializer#pyspark.MarshalSerializer) is a wrapper around [`marhsal`](https://docs.python.org/3.5/library/marshal.html) module which implements internal Python serialization mechanism. While in some cases it can be slightly faster than a default `pickle` it is significantly more limited and performance gain is probably to limited to make it useful in practice.

#### CloudPickle

[`CloudPickle`](https://github.com/apache/spark/blob/2.0.0-preview/python/pyspark/cloudpickle.py) is an [extended version of the original `cloudpickle` project](https://github.com/cloudpipe/cloudpickle). It is used in PySpark to serialize closures. Among other interesting properties it can serialize functions defined in the `__main__` module. See for example [Passing Python functions as objects to Spark](http://stackoverflow.com/q/37641103/1560062).

### PySpark Serialization Strategies

#### AutoBatchedSerializer

`AutoBatchedSerializer` is used to serialize a stream of objects in batches of size which is dynamically adjusted on runtime to keep the size of an individual batch in bytes close to the `bestSize` parameter. By default it is 65536 bytes. The general algorithm can be described as follows:

1. Set `batchSize` to 1
2. While input stream is not empty

  - read `batchSize` elements and serialize,
  - compute `size` in bytes of the serialized batch,
    - if `size` is less than `bestSize` set `batchSize` to `batchSize` * 2
    - else if `size` is greater than `bestSize` set `batchSize` to `batchSize` / 2
    - else keep current value


#### BatchedSerializer

`BatchedSerializer` is used to serialize a stream of objects using either fixed size batches or unlimited batches.

### Configuring PySpark Serialization

By default PySpark uses `AutoBatchedSerializer` with `PickleSerializer`. Global serialization mechanism can be configured during `SparkContext` initialization and provides two configurable properties - `batchSize` and `serializer`.


- `batchsize` argument is used to configure batching strategy and takes an intger which has following interpretation:

  - `0` -  `AutoBatchedSerializer`.
  - `-1` - `BatchedSerializer` with unlimited batch size.
  - positive integer - `BatchedSerializer` with fixed batch size.


- `serializer` accepts an instance of a `pyspark.serializer` for example:


  ```python
  from pyspark import SparkContext
  from pyspark.serializers import MarshalSerializer

  sc = SparkContext(serializer=MarshalSerializer())
  ```

In Spark 2.0.0+, you will need to create `SparkContext` before the `SparkSession` if you use the session builder, otherwise pass it explicitly to `SparkSession` constructor.

It is also possible, although for obvious reasons not recommended, to use internal API to modify serialization mechanism for specific RDD:


```python

from pyspark import SparkContext
from pyspark.serializers import  BatchedSerializer, MarshalSerializer

sc = SparkContext()

rdd = sc.parallelize(range(10))
rdd._reserialize(BatchedSerializer(MarshalSerializer(), 1))
```


### PySpark and Kryo

## SerDe During JVM - Guest Communication


