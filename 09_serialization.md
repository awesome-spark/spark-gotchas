# Serialization

## JVM

### Java Serialization

### Kryo Serialization

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

`AutoBatchedSerializer` is used to serialize a stream of objects in batches of size which is dynamically adjusted on runtime to keep size of an individual batch in bytes close to `bestSize` parameter. By default it is 65536 bytes. General algorithm can be described as follows:


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

In Spark 2.0.0+ you have to create `SparkContext` before `SparkSession` if you builder or pass it explicitly to `SparkSession` constructor.


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


