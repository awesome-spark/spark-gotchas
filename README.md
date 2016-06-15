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
-   [`DataFrame` by Example](05_dataframe_by_example.md#dataframe-by-example)
    -   [Non-lazy Evaluation in
        `DataFrameReader.load`](05_dataframe_by_example.md#non-lazy-evaluation-in-dataframereader.load)
        -   [Explicit Schema](05_dataframe_by_example.md#explicit-schema)
        -   [Sampling for Schema
            Inference](05_dataframe_by_example.md#sampling-for-schema-inference)
        -   [PySpark Specific
            Considerations](05_dataframe_by_example.md#pyspark-specific-considerations)
    -   [Window Functions](05_dataframe_by_example.md#window-functions)
        -   [Understanding Window
            Functions](05_dataframe_by_example.md#understanding-window-functions)
        -   [Window Definitions](05_dataframe_by_example.md#window-definitions)
        -   [Example Usage](05_dataframe_by_example.md#example-usage)
        -   [Requirements and Performance
            Considerations](05_dataframe_by_example.md#requirements-and-performance-considerations)
-   [Data Preparation](06_data_preparation.md#data-preparation)
-   [Iterative Algorithms](07_iterative_algorithms.md#iterative-algorithms)
    -   [Iterative applications and
        lineage](07_iterative_algorithms.md#iterative-applications-and-lineage)
        -   [Truncating lineage in `Dataset`
            API](07_iterative_algorithms.md#truncating-lineage-in-dataset-api)
    -   [Controling number of partitions in iterative
        applications](07_iterative_algorithms.md#controling-number-of-partitions-in-iterative-applications)
-   [PySpark Applications](08_pyspark_applications.md#pyspark-applications)
