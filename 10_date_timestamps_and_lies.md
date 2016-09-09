# External Data Sources - Die or die trying

### Dates, Timestamps and lies

I was working once with some legacy database on MySQL and one of the most common
problems is actually dealing with dates and timestamps. But so we think.

It is also not enough to know how to use the `jdbc` connector to know how to
pull data from MySQL. You actually need to understand the mechanism of the
connector, the database; in occurence MySQL and also Spark's in these cases.

So here is the drill. I was reading some data from MySQL. Some columns are of
type `timestamp` with a default value is "0000-00-00 00:00:00". Something like
this :

```
+--------------------------+---------------+---------------------+----------------+
| Field                    | Type          | Default             | Extra          |
+--------------------------+---------------+---------------------+----------------+
| lastUpdate               | timestamp     | 0000-00-00 00:00:00 |                |
+--------------------------+---------------+---------------------+----------------+
```

Spark doesn't seem to like that :

```
java.sql.SQLException: Cannot convert value '0000-00-00 00:00:00' from column lastUpdate to TIMESTAMP.
    at com.mysql.jdbc.SQLError.createSQLException(SQLError.java:1055)
    [...]
```

***So how to we deal with that ?***

The first thing that comes in mind always when dealing with such issue is converting into
a string then dealing with the date through parsing with some
[Joda](http://www.joda.org/joda-time/) or such.

Well, that ~~isn't always~~, is never the best solution.

And here is why :

Well first, because the MySQL jdbc connector helps setting your driver's class
inside spark's `jdbc` options allows to deal with this issue in a very clean
manner. You need to dig in the connector's
[configuration properties](https://dev.mysql.com/doc/connector-j/5.1/en/connector-j-reference-configuration-properties.html).

And here is a excerpt, at least the one we need:
> **zeroDateTimeBehavior**

> What should happen when the driver encounters DATETIME values that are composed entirely of zeros (used by MySQL to represent invalid dates)? Valid values are "exception", "round" and "convertToNull".

> Default: exception

> Since version: 3.1.4

So basically, all you have to do is setting this up in the in your data source connection configuration url as following :

```
jdbc:mysql://yourserver:3306/yourdatabase?zeroDateTimeBehavior=convertToNull
```

But ***why doesn't casting work ?***

I feel silly saying this, by I've tried casting to string which doesn't seem to work.

Actually I tought that the solution works but...

```scala
df.filter(columns.isNull)
```

returns zero rows and the schema confirms that the columns is a `timestamp` and that the column contains `null`.

let's take again a look at the `DataFrame`'s schema :

```
|-- lastUpdate: timestamp (nullable = false)
```

***Is this a spark issue ?***

Well, no, it's not !

```scala
df.select(to_date($"lastUpdate").as("lastUpdate"))
  .groupBy($"lastUpdate").count
  .orderBy($"lastUpdate").show
// +----------+-----+
// |lastUpdate|count|
// +----------+-----+
// |      null|   10|
// |2011-03-24|   16|
// |2011-03-25|    3|
// |2011-04-03|    1|
// |2011-04-04|    1|
// |2011-04-12|    1|
// |2011-05-14|  283|
// |2011-05-15|    3|
// |2011-05-16|    5|
// |2011-05-17|    6|
// |2011-05-18|   30|
// |2011-05-19|   21|
// |2011-05-20|    4|
// |2011-05-21|    2|
// +----------+-----+
```

and

```scala
df.select(to_date($"lastUpdate").as("lastUpdate"))
   .groupBy($"lastUpdate").count
   .orderBy($"lastUpdate").printSchema
```

gives the following:

```scala
// root
//  |-- lastUpdate: date (nullable = false)
//  |-- count: long (nullable = false)
```

whereas,

```scala
df.select(to_date($"lastUpdate").as("lastUpdate"))
  .groupBy($"lastUpdate")
  .count
  .orderBy($"lastUpdate")
  .filter($"lastUpdate".isNull)
  .show
```

returns nothing :

```scala
// +----------+-----+
// |lastUpdate|count|
// +----------+-----+
// +----------+-----+
```

But the data isn't on MySQL anymore, I have pulled it using the
`zeroDateTimeBehavior=convertToNull` argument in the connection URL and I have
cached it. It's actually converting zeroDateTime to null as you can see in
group by result we saw above, but why filters aren't working correctly then ?

@zero323 comment on that : *When you create data frame it fetches schema from database, and the column used
has most likely NOT NULL constraint.*

So let's check our data again,

```scala
// +--------------------------+---------------+------+-----+---------------------+----------------+
// | Field                    | Type          | Null | Key | Default             | Extra          |
// +--------------------------+---------------+------+-----+---------------------+----------------+
// | lastUpdate               | timestamp     | NO   |     | 0000-00-00 00:00:00 |                |
// +--------------------------+---------------+------+-----+---------------------+----------------+
```

The `DataFrame` schema (shown before) is not null, so spark doesn't actually have
any reason to check if there are nulls out there.

but *what then explains the filter not working ?*

It doesn't work because spark "knows" there are no null values, even thought MySQL lies.

So here is the solution:

We have to create a new schema where the field `lastUpdate` is actually `nullable`
and use it to rebuild Dataframe.

So, this basically something like this:

```scala
import org.apache.spark.sql.types._

case class Foo(x: Integer)
val df = Seq(Foo(1), Foo(null)).toDF
val schema =  StructType(Seq(StructField("x", IntegerType, false)))

df.where($"x".isNull).count
// 1

spark.createDataFrame(df.rdd, schema).where($"x".isNull).count
// 0
```

We are lying to Spark, and the way to update the old schema changing all the `timestamp`s to `nullable`
can be done by taking fields and modify the problematic ones as followed :

```scala
df.schema.map {
  case ts @ StructField(_, TimestampType, false, _) => ts.copy(nullable = true)
  case sf => sf
}

spark.createDataFrame(products.rdd, StructType(newSchema))
```
