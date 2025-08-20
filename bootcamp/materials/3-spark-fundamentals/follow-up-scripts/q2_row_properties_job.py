from pyspark.sql import SparkSession, DataFrame

def do_properties_struct(spark, dataframe) -> DataFrame:

	"""
	Transform a set of columns of player's attributes into a single struct.
	"""

	transformation_query = """
		SELECT player,
			STRUCT(season, gp, pts, ast, reb) AS player_properties
		FROM player_stats
	"""

	dataframe.createOrReplaceTempView("player_stats")

	return spark.sql(transformation_query)

def main():

	spark.SparkSession.builder().appName("player_properties").getOrCreate()

	source_df = spark.table("player_stats")

	sink_df = do_properties_row_aggregation(source_df)

	sink_df.write.mode("overwrite").saveAsTable("player_stats_struct")
