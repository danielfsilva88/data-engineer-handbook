# To overcome `OutOfMemoryError: Java heap space`

- Context:
  - In a Notebook with 16 GB RAM, 
  - the step in `bucket-joins-in-iceberg` notebook that add bucketed data into pre-created table
	- (e.g. bootcamp.matches_bucketed USING iceberg PARTITIONED BY (completion_date, bucket(16, match_id)))
  - was leading to an error `OutOfMemoryError: Java heap space`;
  - Trying to change Spark configurations in SparkSession didn't work
	- ( e.g. .config("spark.driver.memory", "16g").config("spark.memory.offHeap.enabled", "true").config("spark.memory.offHeap.size", "16g") ) 

- Solution:
  - Update spark configs in the iceberg container:
    - On the Docker desktop, go to Containers > 3-spark-fundamentals > spark-iceberg > Files. 
	- Scroll down to opt > config, right click on spark-defaults.conf to edit it, 
	  - scroll to the bottom, add the following 4 lines
	    - spark.serializer                       org.apache.spark.serializer.KryoSerializer
		- spark.driver.memory                    16g
		- spark.memory.offHeap.enabled           true
		- spark.memory.offHeap.size              16g

