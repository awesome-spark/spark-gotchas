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

It should be quite obvious that these methods don't address the firs two issues we enumerated above:

- Amount of data that has to shuffled is exactly the same.
- Size of the aggregated structures can still exceed amount of available memory.

What about the third one? This is actually the place where we make things significantly worse. For starters we have to create a new list object for each record. If it wasn't bad enough each `seqOp` and `mergeOp` creates a new list as well. In practice both Scala and Python (before Spark 1.4.0. We'll cover PySpark specific improvements later) implementations of the `groupByKey` use mutable buffers to avoid this issue.

If it wasn't bad enough in the process we significantly increased time complexity of each operation. Since concatenating two list of size N and M requires a full copy in Python (_O(N + M)_) and traversing the first one (_O(N)_)) in Scala we increased the cost of processing each partition from roughly _O(N)_ to _O(N^2)_.


### Not All groupBy Methods Are Equal

#### PySpark RDD.groupByKey and SPARK-3074

#### DataFrame.groupBy



