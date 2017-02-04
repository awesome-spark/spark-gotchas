# Small deployments and dynamic allocation

## Yet Another Dynamic Resource Allocation YA(D)RN

Let's talk a bit about dynamic allocation with YARN. So in YARN terminology, executors and application masters run inside “containers”.
Spark offers yarn specific properties so you can run your application :

- `spark.yarn.executor.memoryOverhead` is the amount of off-heap memory (in megabytes) to be allocated per executor. This is memory that accounts for things like VM overheads, interned strings, other native overheads, etc. This tends to grow with the executor size (typically 6-10%).
- `spark.yarn.driver.memoryOverhead` is the amount of off-heap memory (in megabytes) to be allocated per driver in cluster mode with the memory properties as the executor's memoryOverhead.

So it's not about storing data, it's just the resources needed for YARN to run properly.

In some cases, **e.g** if you enable `dynamicAllocation` you might want to set these properties explicitly along with the maximum number of executor (`spark.dynamicAllocation.maxExecutors`) that can be created during the process which can easily overwhelm YARN by asking for thousands of executors and thus loosing the already running executors.

- `spark.dynamicAllocation.maxExecutors` is set to infinity by default which set the upper bound for the number of executors if dynamic allocation is enabled. Ref. [Official documentation - Configuration](http://spark.apache.org/docs/latest/configuration.html#dynamic-allocation).

- According to the code documentation : Ref. [ExecutorAllocationManager.scala](https://github.com/apache/spark/blob/8ef3399aff04bf8b7ab294c0f55bcf195995842b/core/src/main/scala/org/apache/spark/ExecutorAllocationManager.scala#L43).

Increasing the target number of executors happens in response to backlogged tasks waiting to be scheduled. If the scheduler queue is not drained in N seconds, then new executors are added. If the queue persists for another M seconds, then more executors are added and so on. The number added in each round increases exponentially from the previous round until an upper bound has been reached. The upper bound is based both on a configured property and on the current number of running and pending tasks, as described above.

This can lead into an exponential increase of the number of executors in some cases which can break the YARN resource manager. In my case :

```16/03/31 07:15:44 INFO ExecutorAllocationManager: Requesting 8000 new executors because tasks are backlogged (new desired total will be 40000)```

This doesn't cover all the use case which one can use those property, but it gives a general idea about how it's been used.
