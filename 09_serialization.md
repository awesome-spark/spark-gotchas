# Serialization

## JVM

### Java Serialization

### Kryo Serialization

## PySpark Serialization

In general PySpark provides 2-tier serialization mechanism defined by actual serialization engine, like `PickleSerializer`, and batching mechanism. An additional specialized serializer is used to serialize closures. It is important to note that Python classes cannot be serialized. It means that modules containing class definitions have to be accessible on every machine in the cluster.

### Python Serializers Characteristics

### PySpark Serialization Strategies

### Congiguring PySpark Serialization

### PySpark and Kryo

## SerDe During JVM - Guest Communication


