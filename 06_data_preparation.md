# Data Preparation

## DataFrame Metadata

Column metadata is one of the most useful and the least known features of the Spark `Dataset`. Although it is widely used by [ML `Pipelines`](https://spark.apache.org/docs/latest/ml-pipeline.html) to indicate variable types and levels a whole process is usually completely transparent and at least partially hidden from the final user so let's look at a simple pipeline and see what happens behind the scenes.

We'll start with a simple dataset:


```scala
val df = Seq(
  (0, "x", 2.0),
  (1, "y", 3.0)
).toDF("label", "x1", "x2")
```

and a following pipeline:

```scala
import org.apache.spark.ml.Pipeline
import org.apache.spark.ml.feature.{StringIndexer, VectorAssembler}

val stages = Array(
  new StringIndexer().setInputCol("x1").setOutputCol("x1_"),
  new VectorAssembler().setInputCols(Array("x1_", "x2")).setOutputCol("features")
)


val model = new Pipeline().setStages(stages).fit(df)
```

Now we can extract `stages`, `transform` data step-by-step:

```scala
val dfs = model.stages.scanLeft(df)((df, stage) => stage.transform(df))
```

and see what is going on at each stage:

1. Our initial dataset has no metadata:

  ```scala
  dfs(0).schema.map(_.metadata)

  // Seq[org.apache.spark.sql.types.Metadata] = List({}, {}, {}, {})
  ```

2. After transforming with `StringIndexerModel`:

  ```scala
  dfs(1).schema.last.metadata

  // org.apache.spark.sql.types.Metadata =
  //   {"ml_attr":{"vals":["x","y"],"type":"nominal","name":"x1_"}}
  ```

3. Finally metadata for assembled feature vector:

  ```scala
  dfs(2).schema.last.metadata

  // org.apache.spark.sql.types.Metadata = {"ml_attr":{"attrs":{
  //   "numeric":[{"idx":1,"name":"x2"}],
  //   "nominal":[{"vals":["x","y"],"idx":0,"name":"x1_"}]
  // },"num_attrs":2}}
  ```





