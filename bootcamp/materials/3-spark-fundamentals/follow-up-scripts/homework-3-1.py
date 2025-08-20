from pyspark.sql import SparkSession
from pyspark.sql.functions import broadcast, split, lit

spark = SparkSession.builder.appName("hw-3-1").config("spark.sql.autoBroadcastJoinThreshold", "-1").getOrCreate()
spark.conf.set("spark.sql.sources.commitProtocolClass", "org.apache.spark.sql.execution.datasources.SQLHadoopMapReduceCommitProtocol")

# load tables and store them bucketed in Iceberg

## matchesBucketed
matchesBucketed = spark.read.option("header", "true") \
                        .option("inferSchema", "true") \
                        .csv("/home/iceberg/data/matches.csv")

spark.sql("""DROP TABLE IF EXISTS bootcamp.matches_bucketed""")
bucketedDDL = """
CREATE TABLE IF NOT EXISTS bootcamp.matches_bucketed (
 match_id STRING,
 mapid STRING,
 is_team_game BOOLEAN,
 playlist_id STRING,
 completion_date TIMESTAMP
)
USING iceberg
PARTITIONED BY (completion_date, bucket(16, match_id));
"""
spark.sql(bucketedDDL)

(
matchesBucketed.select("match_id", "mapid", "is_team_game", "playlist_id", "completion_date")
.write.mode("append")
.partitionBy("completion_date")
.bucketBy(16, "match_id").saveAsTable("bootcamp.matches_bucketed")
)


## matchDetailsBucketed
matchDetailsBucketed = ( spark.read.option("header", "true")
                        .option("inferSchema", "true")
                        .csv("/home/iceberg/data/match_details.csv")
                       )

spark.sql("""DROP TABLE IF EXISTS bootcamp.match_details_bucketed""")
bucketedDetailsDDL = """
CREATE TABLE IF NOT EXISTS bootcamp.match_details_bucketed (
    match_id STRING,
    player_gamertag STRING,
    player_total_kills INTEGER,
    player_total_deaths INTEGER
)
USING iceberg
PARTITIONED BY (bucket(16, match_id));
"""
spark.sql(bucketedDetailsDDL)

(
matchDetailsBucketed.select("match_id", "player_gamertag", "player_total_kills", "player_total_deaths")
.write.mode("append")
.bucketBy(16, "match_id").saveAsTable("bootcamp.match_details_bucketed")
)


## medal_matches_players_bucketed
medal_matches_players_bucketed = ( spark.read.option("header", "true")
                        .option("inferSchema", "true")
                        .csv("/home/iceberg/data/medals_matches_players.csv")
                       )

spark.sql("""DROP TABLE IF EXISTS bootcamp.medal_matches_players_bucketed""")
bucketedDetailsDDL = """
CREATE OR REPLACE TABLE bootcamp.medal_matches_players_bucketed (
    match_id STRING,
    player_gamertag STRING,
    medal_id BIGINT,
    count INTEGER
)
USING iceberg
PARTITIONED BY (bucket(16, match_id));
"""
spark.sql(bucketedDetailsDDL)

(
medal_matches_players_bucketed.select("match_id", "player_gamertag", "medal_id", "count")
.write.mode("append")
.bucketBy(16, "match_id").saveAsTable("bootcamp.medal_matches_players_bucketed")
)


## small tables - medals and maps
medals = ( spark.read.option("header", "true")
          .option("inferSchema", "true")
          .csv("/home/iceberg/data/medals.csv")
          )

maps = ( spark.read.option("header", "true")
          .option("inferSchema", "true")
          .csv("/home/iceberg/data/maps.csv")
          .withColumnRenamed('name', 'map_name')
          .withColumnRenamed('description', 'map_description')
          )


# join all to denormalized table
joined_df = (spark.table("bootcamp.matches_bucketed").alias("mb")
             .join(spark.table("bootcamp.match_details_bucketed").alias("mdb"),
                   col("mb.match_id") == col("mdb.match_id"), "inner")
             .join(spark.table("bootcamp.medal_matches_players_bucketed").alias("mmpb"),
                   (col("mdb.match_id") == col("mmpb.match_id")) & (col("mdb.player_gamertag") == col("mmpb.player_gamertag")) )
             .join(broadcast(medals), ["medal_id"], "inner")
             .join(broadcast(maps), col("mb.mapid") == maps["mapid"])
            )

spark.sql("""DROP TABLE IF EXISTS bootcamp.medal_matches_players_maps""")
bucketedDetailsDDL = """
CREATE OR REPLACE TABLE bootcamp.medal_matches_players_maps (
    mapid string,
    match_id STRING,
    medal_id BIGINT,
    is_team_game boolean,
    playlist_id string,
    completion_date timestamp,
    player_gamertag string,
    player_total_kills integer,
    player_total_deaths integer,
    count INTEGER,
    sprite_uri string,
    sprite_left integer,
    sprite_top integer,
    sprite_sheet_width integer,
    sprite_sheet_height integer,
    sprite_width integer,
    sprite_height integer,
    classification string,
    description string,
    name string,
    difficulty integer,
    map_name string,
    map_description string
)
USING iceberg
PARTITIONED BY (mapid);
"""

spark.sql(bucketedDetailsDDL)

(
joined_df
    .select('mapid', 'mb.match_id', 'medal_id', 'is_team_game', 'playlist_id', 'completion_date', 'player_gamertag', 
                 'player_total_kills', 'player_total_deaths','count','sprite_uri','sprite_left','sprite_top',
                 'sprite_sheet_width', 'sprite_sheet_height','sprite_width','sprite_height','classification',
                 'description', 'name', 'difficulty', 'map_name', 'map_description'
    )
    .write.mode('append').partitionBy('mapid').saveAsTable('bootcamp.medal_matches_players_maps')
)


# Data Analysis

df_mmpm = spark.table('bootcamp.medal_matches_players_maps')

## Which player averages the most kills per game?
(df_mmpm
 .groupBy('player_gamertag', 'match_id')
 .agg(avg('player_total_kills').alias('avg_total_kills_game'))
 .sort(desc('avg_total_kills_game'))
 .limit(1)
 .show()
)

### Answer: gimpinator14 - 109 avg kills

### Check sortWithinPartitions effect
(df_mmpm
 .groupBy('player_gamertag', 'match_id')
 .agg(avg('player_total_kills').alias('avg_total_kills_game'))
 .sortWithinPartitions(desc('avg_total_kills_game'))
 .limit(10)
 .show()
)

## Which playlist gets played the most?
df_playlist = df_mmpm.groupBy('playlist_id').agg(count('match_id').alias('cnt_playlist_id')).sort(desc('cnt_playlist_id')).limit(1)

print(df_playlist.collect()[0])

df_playlist.show()

### Answer: playlist_id='f72e0ef0-7c4a-4307-af78-8e38dac3fdba', cnt_playlist_id=202489

### Check sortWithinPartitions effect
df_playlist = df_mmpm.groupBy('playlist_id').agg(count('match_id').alias('cnt_playlist_id')).sortWithinPartitions(desc('cnt_playlist_id')).limit(3)

print(df_playlist.collect()[0])

df_playlist.show()


## Which map gets played the most?
df_mostmap = df_mmpm.groupBy('map_name').agg(count('match_id').alias('cnt_map_name')).sort(desc('cnt_map_name')).limit(3)

print(df_mostmap.collect()[0])

df_mostmap.show()
### Answer: map_name='Breakout Arena', cnt_map_name=186118

### Check sortWithinPartitions effect
df_mostmap = df_mmpm.groupBy('map_name').agg(count('match_id').alias('cnt_map_name')).sortWithinPartitions(desc('cnt_map_name')).limit(3)

print(df_mostmap.collect()[0])

df_mostmap.show()


## Which map do players get the most Killing Spree medals on?
df_mostmap_ks = (df_mmpm
                 .filter("name = 'Killing Spree'")
                 .groupBy('map_name').agg(count('match_id').alias('cnt_map_name'))
                 .sort(desc('cnt_map_name')).limit(3)
                )

print(df_mostmap_ks.collect()[0])

df_mostmap_ks.show()
### Answer: map_name='Breakout Arena', cnt_map_name=6553

### Check sortWithinPartitions effect
df_mostmap_ks = (df_mmpm
                 .filter("name = 'Killing Spree'")
                 .groupBy('map_name').agg(count('match_id').alias('cnt_map_name'))
                 .sortWithinPartitions(desc('cnt_map_name')).limit(3)
                )

print(df_mostmap_ks.collect()[0])

df_mostmap_ks.show()

