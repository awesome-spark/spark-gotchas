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

So far so good but there is something wrong with this picture. If we check [the old (Spark <= 1.3.0) PySpark implementation](https://github.com/apache/spark/blob/v1.3.0/python/pyspark/rdd.py#L1754-L1781) as well as [the Scala implementation](https://github.com/apache/spark/blob/v2.0.0/core/src/main/scala/org/apache/spark/rdd/PairRDDFunctions.scala#L500-L510) we'll realize that, excluding some optimizations, we just reimplemented `groupByKey`. So no improvement after all.


### Not All groupBy Methods Are Equal

#### PySpark RDD.groupByKey and SPARK-3074

#### DataFrame.groupBy



