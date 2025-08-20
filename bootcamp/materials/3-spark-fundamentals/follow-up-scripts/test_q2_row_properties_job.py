from chispa.dataframe_comparer import assert_df_equality
from ..jobs.q2_row_properties_job import do_properties_struct
from collections import namedtuple
from pyspark.sql.types import StructType, StructField, StringType, LongType

PlayerStats = namedtuple("player_stats", "player season gp pts ast reb")
PlayerStatsStruct = namedtuple("player_stats_struct", "player player_properties")

def test_properties_struct(spark):

  source_data = [
    PlayerStats("Michael", 2025, 7, 30, 5, 3),
	PlayerStats("Jordan", 2025, 7, 30, 5, 3),
    PlayerStats("Curry", 2025, 7, 30, 5, 3),
    PlayerStats("Steph", None, None, None, None, None)
  ]

  source_df = spark.createDataFrame(source_data)

  transformed_df = do_properties_struct(spark, source_df)

  expected_data = [
	PlayerStatsStruct("Michael", (2025, 7, 30, 5, 3)),
    PlayerStatsStruct("Jordan", (2025, 7, 30, 5, 3)),
    PlayerStatsStruct("Curry", (2025, 7, 30, 5, 3)),
    PlayerStatsStruct("Steph", (None, None, None, None, None))
  ]

  expected_schema = StructType([
    StructField("player", StringType(), nullable=True),
    StructField("player_properties", StructType([
      StructField("season", LongType(), nullable=True),
      StructField("gp", LongType(), nullable=True),
      StructField("pts", LongType(), nullable=True),
      StructField("ast", LongType(), nullable=True),
      StructField("reb", LongType(), nullable=True)
    ]), nullable=False)
  ])
  expected_df = spark.createDataFrame(expected_data, expected_schema)

  assert_df_equality(transformed_df, expected_df)
