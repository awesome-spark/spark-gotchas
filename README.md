-   [Introduction](00_introduction.md#introduction)
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
