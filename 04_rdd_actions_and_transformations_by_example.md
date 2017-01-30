# RDD actions and Transformations by Example

## Be Smart About groupByKey

[_Avoid GroupByKey_](https://databricks.gitbooks.io/databricks-spark-knowledge-base/content/best_practices/prefer_reducebykey_over_groupbykey.html) (a.k.a. _Prefer reduceByKey over groupByKey_) is one of the best known documents in Spark ecosystem.

Unfortunately despite of all it's merits it is quite often misunderstood by Spark beginners. This often results in completely useless attempts to optimize grouping without addressing any of the core issues.


### What Exactly Is Wrong With groupByKey

Main issues with `groupByKey` can be summarized as follows (see [SPARK-722](https://issues.apache.org/jira/browse/SPARK-772), [Avoid GroupByKey](https://databricks.gitbooks.io/databricks-spark-knowledge-base/content/best_practices/prefer_reducebykey_over_groupbykey.html)):

- Amount of data that has to be transfered between worker nodes.
- Possible OOM exceptions, during or after the shuffle, when size of the aggregate structure exceeds amount of available memory.
- Cost of garbage collection of the temporary data structures used for shuffle as well as large aggregated collections.

### How Not to Optimize

A naive attempt to optimize `groupByKey` in Python can be expressed as follows:


```python
rdd = sc.parallelize([(1, "foo"), (1, "bar"), (2, "foobar")])

(rdd
    .map(lambda kv: (kv[0], [kv[1]]))
    .reduceByKey(lambda x, y: x + y))
```

with Scala equivalent being roughly similar to this:


```scala
val rdd = sc.parallelize(Seq((1, "foo"), (1, "bar"), (2, "foobar")))

rdd
  .mapValues(_ :: Nil)
  .reduceByKey(_ ::: _)
```

It should be quite obvious that these methods don't address the first two issues we enumerated above:

- Amount of data that has to shuffled is exactly the same.
- Size of the aggregated structures can still exceed amount of available memory.

What about the third one? This is actually the place where we make things significantly worse. For starters we have to create a new list object for each record. If it wasn't bad enough each `seqOp` and `mergeOp` creates a new list as well. In practice both Scala and Python (before Spark 1.4.0. We'll cover PySpark specific improvements later) implementations of the `groupByKey` use mutable buffers to avoid this issue.

If it wasn't bad enough in the process we significantly increased time complexity of each operation. Since concatenating two list of size N and M requires a full copy in Python (_O(N + M)_) and traversing the first one (_O(N)_)) in Scala we increased the cost of processing each partition from roughly _O(N)_ to _O(N^2)_.

How can we implement `groupBy`-like operation the right way?

The first problem we have to address in unacceptable complexity of the map-side combine. In practice it means we'll have to use a data structure which effectively provides constant time append operation and naive concatenation won't work for us. It also means that we'll have to use either `combineByKey` or `aggregateByKey` to be able to express operation where input and output types differ. Since these methods can be safely initialized with mutable buffers we can also avoid creating temporary objects for each merge.

Keeping all of that in mind we could propose following Python implementation:


```python
def create_combiner(x):
    return [x]


def merge_value(acc, x):
    acc.append(x)  # Mutating acc in place O(C)
    return acc


def merge_combiners(acc1, acc2):
    acc1.extend(acc2)  # Mutating acc1 in place O(M)
    return acc1


rdd.combineByKey(create_combiner, merge_value, merge_combiners)

```

Similarly custom grouping in Scala could look like this:


```scala
import scala.collection.mutable.ArrayBuffer

rdd.combineByKey(
  (x: String) => ArrayBuffer(x),
  (acc: ArrayBuffer[String], x: String) => acc += x,
  (acc1: ArrayBuffer[String], acc2: ArrayBuffer[String]) => acc1 ++= acc2
)
```

So far so good but there is something wrong with this picture. If we check [the old (Spark <= 1.3.0) PySpark implementation](https://github.com/apache/spark/blob/v1.3.0/python/pyspark/rdd.py#L1754-L1781) as well as [the Scala implementation](https://github.com/apache/spark/blob/v2.0.0/core/src/main/scala/org/apache/spark/rdd/PairRDDFunctions.scala#L500-L510) we'll realize that, excluding some optimizations, we just reimplemented `groupByKey`.

Take away message here is simple. Don't try to fix things that aren't broken. The fundamental problem with `groupByKey` is not implementation but a combination of a distributed architecture and contract.

### Not All groupBy Methods Are Equal

It is important to note that Spark API provides a few methods which suggest `groupBy`-like behavior as described in __Avoid GroupByKey__ but don't exhibit the same behavior or have different semantics.

#### PySpark RDD.groupByKey and SPARK-3074

Since version 1.4 PySpark provides a specialized `groupByKey` operation which has much properties than a naive `combineByKey`. It uses [`ExternalMerger`](https://github.com/apache/spark/blob/branch-2.0/python/pyspark/shuffle.py#L140) and [`ExternalGroupBy`](https://github.com/apache/spark/blob/branch-2.0/python/pyspark/shuffle.py#L660) to deal with data which exceeds defined memory limits. If needed data can sorted and dumped to disk. While overall it is still an expensive operation it is much more stable in practice.

It also exposes grouped data as a lazy collection (subclass of `collections.Iterable`).

#### DataFrame.groupBy

In general `groupBy` on is equivalent to standard `combineByKey` and doesn't physically group data. Based on the execution plan for a simple aggregation:


```scala
rdd.toDF("k", "v").groupBy("k").agg(sum("v")).queryExecution.executedPlan

// *HashAggregate(keys=[k#41], functions=[sum(cast(v#42 as double))], output=[k#41, sum(v)#50])
// +- Exchange hashpartitioning(k#41, 200)
//    +- *HashAggregate(keys=[k#41], functions=[partial_sum(cast(v#42 as double))], output=[k#41, sum#55])
//       +- *Project [_1#38 AS k#41, _2#39 AS v#42]
//          +- Scan ExistingRDD[_1#38,_2#39]
```

we can see that `sum` is expressed as `partial_sum` followed by `shuffle` followed by `sum`.

It is worth noting that functions like `collect_list` or `collect_set` don't use these optimizations and are effectively equivalent to `groupByKey`.


#### Dataset.groupByKey

Excluding certain `Dataset` specific optimizations `groupByKey` with `mapGroups` / `flatMapGroups` is comparable to it's RDD counterpart but, similarly to PySpark `RDD.groupByKey`, exposes grouped data as a lazy data structure and can be preferable when expected number of values per key is large.

### When to Use groupByKey and When to Avoid It

#### When to Avoid groupByKey

- If operataion is expressed using `groupByKey` followed by associative and commutative reducing operation on values (`sum`, `count`, `max` / `min`) it should be replaced by `reduceByKey`.
- If operation can be expressed using a comination of local sequence operation and merge operation (online variance / mean, top-n observations) it should be expressed with `combineByKey` or `aggregateByKey`.
- If final goal is to traverse values in a specific order (`groupByKey` followed by sorting values followed by iteration) it can be typically rewritten as `repartitionAndSortWithinPartitions` with custom partitioner and ordering followed by `mapPartitions`.

#### When to Use groupByKey

- If operation has similar semantics to `groupByKey` (doesn't reduce amount of data, doesn't benefit from map side combine) it is typcially better to use `groupByKey`.

#### When to Optimize groupByKey

There are legitimate cases that can benefit from implementing `groupBy`-like operations from scratch.

For example if keys are large compared to aggregated values we prefer to enable map side combine to reduce amount of data that will shuffled.

Similarly, if we have some a priori knowledge about the data we can use specialized data structures to encode observations. For example we can use [run-length encoding](https://en.wikipedia.org/wiki/Run-length_encoding) to handle multidimensional values with low cardinality of individual dimensions.

### Hidden groupByKey

We should remember that Spark API provides other methods which either use `groupByKey` directly or have similar limiations. The most notable examples are `cogroup` and `join` on RDDs. While exact implementation differs between language (Scala implements `PairRDDFunctions.join` using `cogroup` and provides specialized `CoGroupedRDD` while Python implements both `RDD.join` and `RDD.cogroup` via `RDD.groupByKey`) overall performance implications are comparable to using `groupByKey` directly.

## Immutability of a Data Structure Does Not Imply Immutability of the Data

While distributed data structures (`RDDs`, `Datasets`) are immutable, ensuring that functions operating on the data are either side effect free or idempotent, is user responsibility. As a rule of thumb mutable state should be used only in the context in which it is explicitly allowed. In practice it means global or `byKey` aggregations with neutral element (`fold` / `foldByKey`, `aggregate` / `aggregateByKey`) or combiner.

Let's illustrate that with a simple vector summation example. A correct solution, using mutable buffer, can be expressed as follows:

```scala
import breeze.linalg.Dense

val rdd = sc.parallelize(Seq(DenseVector(1, 1), DenseVector(1, 1)), 1)
rdd.fold(DenseVector(0, 0))(_ += _)

// breeze.linalg.DenseVector[Int] = DenseVector(2, 2)
```

It can be tempting to express the logic using simple `reduce`. At the first glance it looks OK:

```scala
val rdd = sc.parallelize(Seq(DenseVector(1, 1), DenseVector(1, 1)), 1)
rdd.reduce(_ += _)

// breeze.linalg.DenseVector[Int] = DenseVector(2, 2)
```

and seems to work even just fine even if we repeat operation multiple times:

```scala
rdd.reduce(_ += _)
// breeze.linalg.DenseVector[Int] = DenseVector(2, 2)

rdd.reduce(_ += _)
// breeze.linalg.DenseVector[Int] = DenseVector(2, 2)
```

Now let's check what happens if we cache data:

```scala
rdd.cache

rdd.reduce(_ += _)
// breeze.linalg.DenseVector[Int] = DenseVector(2, 2)

rdd.reduce(_ += _)
// breeze.linalg.DenseVector[Int] = DenseVector(3, 3)

rdd.reduce(_ += _)
// breeze.linalg.DenseVector[Int] = DenseVector(4, 4)

rdd.first
// breeze.linalg.DenseVector[Int] = DenseVector(4, 4)
```

As you can see data has been modified and each execution yields different results. In practice outcomes can be nondeterministic if data is not fully cached in memory or has been evicted from cache.

Behavior described above is of course not limited to aggregations and any operation mutating data in place can lead to similar problems.

__Note__:

Problems described in this section are JVM specific. Due to indirect caching mechanism PySpark applications provide much stronger isolation. Nevertheless we shouldn't depend on that in general and we should apply the same rules as in Scala.
