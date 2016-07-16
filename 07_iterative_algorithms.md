# Iterative Algorithms

One of the strong suits of the Apache Spark is that it provides elegant and concise ways to express iterative algorithms without adding significant computational overhead. It is important though, to understand what are the implications of iterative processing and how to monitor and manage its different aspects.

## Iterative Applications and Lineage

Distributed data structures in Spark can be perceived as recursive data structures where each RDD depends on some set of the parent RDDs. To quote [the source](https://github.com/apache/spark/blob/2.0.0-preview/core/src/main/scala/org/apache/spark/rdd/RDD.scala#L60-L67):

> Internally, each RDD is characterized by five main properties:
>
>  - A list of partitions
>  - A function for computing each split
>  - A list of dependencies on other RDDs
>  - Optionally, a Partitioner for key-value RDDs (e.g. to say that the RDD is hash-partitioned)
>  - Optionally, a list of preferred locations to compute each split on (e.g. block locations for
>    an HDFS file)

Since RDDs are immutable every transformation extends the lineage creating a deeper stack of dependencies. While it is not an issue in case of simple chaining, it can become a serious in iterative processing up to the point where evaluation may become impossible due to stack overflow. Spark provides two different methods to address this problem - checkpointing and flat transformations.

### Checkpointing

### "Flat transformations"

### Truncating Lineage in `Dataset` API

## Controling Number of Partitions in Iterative Applications

