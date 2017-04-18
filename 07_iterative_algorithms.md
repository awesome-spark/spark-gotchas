# Iterative Algorithms

One of the strong suits of the Apache Spark is that it provides elegant and concise ways to express iterative algorithms without adding significant computational overhead. It is important though, to understand what are the implications of iterative processing and how to monitor and manage its different aspects.

## Iterative Applications and Lineage

Distributed data structures in Spark can be perceived as recursive data structures where each RDD depends on some set of the parent RDDs. To quote [the source](https://github.com/apache/spark/blob/2.0.0-preview/core/src/main/scala/org/apache/spark/rdd/RDD.scala#L60-L67):

> Internally, each RDD is characterized by five main properties:
>
>  - A list of partitions
>  - A function for computing each split
>  - __A list of dependencies on other RDDs__
>  - Optionally, a Partitioner for key-value RDDs (e.g. to say that the RDD is hash-partitioned)
>  - Optionally, a list of preferred locations to compute each split on (e.g. block locations for
>    an HDFS file)

Since RDDs are immutable every transformation extends the lineage creating a deeper stack of dependencies. While it is not an issue in case of simple chaining, it can become a serious in iterative processing up to the point where evaluation may become impossible due to stack overflow. Spark provides two different methods to address this problem - checkpointing and flat transformations.

### Checkpointing

Checkpointing (don't be mistaken with [checkpointing in Spark Streaming](https://spark.apache.org/docs/latest/streaming-programming-guide.html#checkpointing)) is a mechanism which enables truncating the lineage. It has following consequences:

- It saves RDD to Spark checkpoint directory.
- It removes references to the partent RDDs.

`checkpoint` is lazy and unless given RDD is cached it will have to be reevaluated.

The biggest advantage of checkpointing is that it is universal. It can be used with any lineage independent of particular transformations.

### "Flat Transformations"

As a complementary to truncating lineage we can use transformations which keep lineage short. This can be achieved either with built-in methods like `SparkContext.union` and `PairRDDFunctions.cogroup` or by preferring flat transformations over transformation chaining.

#### Creating an Union of Multiple RDDs

Whenever we perform and iterative union without referencing partial results we can replace transformation chaining with a single call to `SparkContext.union`. Lets use DAG to illustrate the difference between these two methods. Let's assume that we have a sequence of RDDs:

```scala
val rdds = (0L to 4L).map(i => sc.range(10L * i, 10L * (i + 1L)))
```

If we chain `union` calls:

```scala
rdds.foldLeft(sc.emptyRDD[Long])((acc, rdd) => acc.union(rdd))

```

we'll get a following DAG:

![Iterative union](images/07_iterative_algorithms/01_iterative_union.png)


In contrast with a single call to `SparkContext.union`:

```scala
sc.union(rdds)
```

we'll get a shallow DAG which looks as shown below:

![Single union](images/07_iterative_algorithms/02_sc_union.png)

#### Joining Multiple RDDs

Similarly to creating an `union` it is possible to `join` multiple RDDs at once using `RDD.cogroup` although this approach is fairly limited. First of all Spark provide ability to `cogroup` up to 4 RDDs at the time. Moreover this process is quite expensive and it is not recommended when number of values per key is large. Nevertheless it can be useful in certain situations.


#### Pushing Transformations to the Local Data Structures

Relatively simple but powerful and efficient way to reduce the length of the lineage is to replace consecutive narrow transformations with their local equivalent. Since basic methods from RDD API have identical equivalents in `Iterator` API it is as simple as using `mapPartitions`. For example following chain of transformations:

```scala
val rdd = sc.range(0L, 100L)


rdd.filter(_ % 17 == 3).map(x => x until x * x).flatMap(_.map(_ + 1)).filter(_ % 2 != 0)

```
can be expressed as:

```scala
rdd.mapPartitions(
  _.filter(_ % 17 == 3).map(x => x until x * x).flatMap(_.map(_ + 1)).filter(_ % 2 != 0)
)

```
with minimal changes in the code.

This method is particularly useful when working with simple simulations and Monte Carlo methods. Consider following example:

```scala
import breeze.stats.distributions.Gaussian

val rdd = sc.parallelize(Array.fill(1000)(0.0))

def simulate(iter: Iterator[Double]) = {
  val g = Gaussian.distribution((0.0, 1.0))
  iter.map(_ + g.get)
}


// This will result in java.lang.StackOverflowError
(0 to 1000).foldLeft(rdd)((acc, _) => acc.mapPartitions(simulate _)).stats

```

which should result in `java.lang.StackOverflowError` while alternative approach:


```scala
rdd.mapPartitions(iter => {
  (0 to 1000).foldLeft(iter)((acc, _) => simulate(acc))
}).stats
```

should finish without any issues.

Another advantage of this approach is that it can be easily tested using local data structures without initializing `SparkContext`.

Unfortunately there is no drop in replacement in Python so working with PySpark requires a little bit more effort. For example with [`toolz`](https://github.com/pytoolz/toolz) library we can replace:


```python
rdd = sc.parallelize(range(100))

(rdd
    .filter(lambda x: x % 17 == 3)
    .map(lambda x: range(x, x * x))
    .flatMap(lambda xs: (x + 1 for x in xs)))
```

with:

```python
from toolz.curried import filter, pipe, map, mapcat as flatMap

def f(iter):
    return pipe(
        iter,
        filter(lambda x: x % 17 == 3),
        map(lambda x: range(x, x * x)),
        flatMap(lambda xs: (x + 1 for x in xs)))

rdd.mapPartitions(f)
```

### Truncating Lineage in `Dataset` API

## Controling Number of Partitions in Iterative Applications

