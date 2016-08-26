# RDD actions and Transformations by Example

## Be Smart About groupByKey

[_Avoid GroupByKey_](https://databricks.gitbooks.io/databricks-spark-knowledge-base/content/best_practices/prefer_reducebykey_over_groupbykey.html) (a.k.a. _Prefer reduceByKey over groupByKey_) is one of the best known documents in Spark ecosystem.

Unfortunately despite of all it's merits it is quite often misunderstood by Spark beginners. This often results in completely useless attempts to optimize grouping without addressing any of the core issues.


### What Exactly Is Wrong With groupByKey


### How Not to Optimize


### Not All groupBy Methods Are Equal



