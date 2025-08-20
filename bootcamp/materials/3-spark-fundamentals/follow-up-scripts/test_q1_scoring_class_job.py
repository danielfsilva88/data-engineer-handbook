from chispa.dataframe_comparer import *
from ..jobs.q1_scoring_class_job import do_player_scoring_class_calc
from collections import namedtuple
from pyspark.sql.types import StructType, StructField, StringType

PlayerPts = namedtuple("player", "player pts")
PlayerScoringClass = namedtuple("player_sc", "player scoring_class")

def test_scoring_class_calc(spark):

	source_data = [
		PlayerPts("Michael", 30),
		PlayerPts("Jordan", 18),
		PlayerPts("Curry", 12),
		PlayerPts("Steph", 3)
	]

	source_df = spark.createDataFrame(source_data)

	transformed_df = do_player_scoring_class_calc(spark, source_df)


	expected_data = [
		PlayerScoringClass("Michael", "star"),
		PlayerScoringClass("Jordan", "good"),
		PlayerScoringClass("Curry", "average"),
		PlayerScoringClass("Steph", "bad")
	]

	expected_schema = StructType([
    	StructField("player", StringType(), nullable=True),  
    	StructField("scoring_class", StringType(), nullable=False)
	])

	expected_df = spark.createDataFrame(expected_data, expected_schema)

	assert_df_equality(transformed_df, expected_df)
