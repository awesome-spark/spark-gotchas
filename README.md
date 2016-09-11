# Spark Gotchas
[![DOI](https://zenodo.org/badge/19086/awesome-spark/spark-gotchas.svg)](https://zenodo.org/badge/latestdoi/19086/awesome-spark/spark-gotchas)
## Table of Contents
-   [Introduction](00_introduction.md#introduction)
    -   [Version compatibility](00_introduction.md#version-compatibility)
-   [Understanding Spark
    Architecture](01_understanding_spark_architecure.md#understanding-spark-architecture)
    -   [Lack of Global Shared State and Spark
        Closures](01_understanding_spark_architecure.md#lack-of-global-shared-state-and-spark-closures)
    -   [Distributed Processing and its
        Scope](01_understanding_spark_architecure.md#distributed-processing-and-its-scope)
    -   [Feature Parity and Architecture of the Guest
        Languages](01_understanding_spark_architecure.md#feature-parity-and-architecture-of-the-guest-languages)
-   [Spark Application Deployment](02_spark_application_deployment.md#spark-application-deployment)
-   [Spark Application Building](03_spark_application_building.md#spark-application-building)
-   [RDD actions and Transformations by
    Example](04_rdd_actions_and_transformations_by_example.md#rdd-actions-and-transformations-by-example)
    -   [Be Smart About groupByKey](04_rdd_actions_and_transformations_by_example.md#be-smart-about-groupbykey)
        -   [What Exactly Is Wrong With
            groupByKey](04_rdd_actions_and_transformations_by_example.md#what-exactly-is-wrong-with-groupbykey)
        -   [How Not to Optimize](04_rdd_actions_and_transformations_by_example.md#how-not-to-optimize)
        -   [Not All groupBy Methods Are
            Equal](04_rdd_actions_and_transformations_by_example.md#not-all-groupby-methods-are-equal)
        -   [When to Use groupByKey and When to Avoid
            It](04_rdd_actions_and_transformations_by_example.md#when-to-use-groupbykey-and-when-to-avoid-it)
        -   [Hidden groupByKey](04_rdd_actions_and_transformations_by_example.md#hidden-groupbykey)
-   [Spark SQL and Dataset API](05_spark_sql_and_dataset_api.md#spark-sql-and-dataset-api)
    -   [Non-lazy Evaluation in
        `DataFrameReader.load`](05_spark_sql_and_dataset_api.md#non-lazy-evaluation-in-dataframereader.load)
        -   [Explicit Schema](05_spark_sql_and_dataset_api.md#explicit-schema)
        -   [Sampling for Schema
            Inference](05_spark_sql_and_dataset_api.md#sampling-for-schema-inference)
        -   [PySpark Specific
            Considerations](05_spark_sql_and_dataset_api.md#pyspark-specific-considerations)
    -   [Window Functions](05_spark_sql_and_dataset_api.md#window-functions)
        -   [Understanding Window
            Functions](05_spark_sql_and_dataset_api.md#understanding-window-functions)
        -   [Window Definitions](05_spark_sql_and_dataset_api.md#window-definitions)
        -   [Example Usage](05_spark_sql_and_dataset_api.md#example-usage)
        -   [Requirements and Performance
            Considerations](05_spark_sql_and_dataset_api.md#requirements-and-performance-considerations)
-   [Data Preparation](06_data_preparation.md#data-preparation)
    -   [DataFrame Metadata](06_data_preparation.md#dataframe-metadata)
        -   [Metadata in ML pipelines](06_data_preparation.md#metadata-in-ml-pipelines)
        -   [Setting custom column
            metadata](06_data_preparation.md#setting-custom-column-metadata)
-   [Iterative Algorithms](07_iterative_algorithms.md#iterative-algorithms)
    -   [Iterative Applications and
        Lineage](07_iterative_algorithms.md#iterative-applications-and-lineage)
        -   [Checkpointing](07_iterative_algorithms.md#checkpointing)
        -   ["Flat Transformations"](07_iterative_algorithms.md#flat-transformations)
        -   [Truncating Lineage in `Dataset`
            API](07_iterative_algorithms.md#truncating-lineage-in-dataset-api)
    -   [Controling Number of Partitions in Iterative
        Applications](07_iterative_algorithms.md#controling-number-of-partitions-in-iterative-applications)
-   [PySpark Applications](08_pyspark_applications.md#pyspark-applications)
-   [Serialization](09_serialization.md#serialization)
    -   [JVM](09_serialization.md#jvm)
        -   [Java Serialization](09_serialization.md#java-serialization)
        -   [Kryo Serialization](09_serialization.md#kryo-serialization)
    -   [PySpark Serialization](09_serialization.md#pyspark-serialization)
        -   [Python Serializers
            Characteristics](09_serialization.md#python-serializers-characteristics)
        -   [PySpark Serialization
            Strategies](09_serialization.md#pyspark-serialization-strategies)
        -   [Configuring PySpark
            Serialization](09_serialization.md#configuring-pyspark-serialization)
        -   [PySpark and Kryo](09_serialization.md#pyspark-and-kryo)
    -   [SerDe During JVM - Guest
        Communication](09_serialization.md#serde-during-jvm---guest-communication)
-   [External Data Sources - Die or Die
    Trying](10_date_timestamps_and_lies.md#external-data-sources---die-or-die-trying)
    -   [MySQL](10_date_timestamps_and_lies.md#mysql)
        -   [Dates, Timestamps and Lies](10_date_timestamps_and_lies.md#dates-timestamps-and-lies)

## License

This work, excluding code examples, is licensed under [Creative Commons Attribution-ShareAlike 4.0 International license](LICENSE/CC-SA-BY-4.0.txt).

Accompanying code and code snippets are licensed under [MIT license](LICENSE/MIT.txt).
