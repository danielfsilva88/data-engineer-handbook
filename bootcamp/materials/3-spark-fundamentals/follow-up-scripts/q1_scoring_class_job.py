from pyspark.sql import SparkSession

def do_player_scoring_class_calc(spark, dataframe):

	transformation_query = """

		SELECT player,
		CASE WHEN pts > 20 THEN 'star'
	      WHEN pts > 15 THEN 'good'
	      WHEN pts > 10 THEN 'average'
	    ELSE 'bad' END AS scoring_class
	    FROM players


	"""

	dataframe.createOrReplaceTempView("players")
	return spark.sql(transformation_query)


def main():

	spark = SparkSession.builder().appName("scoring_class_app").getOrCreate()

	sink_df = do_player_scoring_class_calc(spark, spark.table("player"))

	sink_df.write.mode("overwrite").saveAsTable("player_scoring_class")