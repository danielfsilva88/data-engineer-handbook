
-- The homework this week will be using the `players`, `players_scd`, and `player_seasons` tables from week 1

select * from players limit 10;
select * from players_scd limit 10;
select * from player_seasons limit 10;
select * from games;
select * from game_details;
select * from games where game_id = '22000050';

select * from players limit 10;
SELECT player_name, COUNT(*) FROM players GROUP BY player_name order by 2 desc;

-- 1.
-- - A query that does state change tracking for `players`
--   - A player entering the league should be `New`
--   - A player leaving the league should be `Retired`
--   - A player staying in the league should be `Continued Playing`
--   - A player that comes out of retirement should be `Returned from Retirement`
--   - A player that stays out of the league should be `Stayed Retired`

-- CTE to get the previous "is_active" state and use it
-- to compare to the current one and create state change tracking
WITH player_previous_state AS (
  SELECT player_name, current_season, is_active,
         LAG(is_active, 1) OVER (PARTITION BY player_name ORDER BY current_season) previous_active_state
  FROM players
)
SELECT player_name, current_season, CASE
                                      WHEN previous_active_state IS NULL THEN 'New'
                                      WHEN is_active = FALSE AND previous_active_state = TRUE THEN 'Retired'
                                      WHEN is_active = TRUE AND previous_active_state = TRUE THEN 'Continued Playing'
                                      WHEN is_active = TRUE AND previous_active_state = FALSE THEN 'Returned from Retirement'
                                      WHEN is_active = FALSE AND previous_active_state = FALSE THEN 'Stayed Retired'
  END AS state_change_tracking
FROM player_previous_state;

-- 2.
-- A query that uses GROUPING SETS to do efficient aggregations of game_details data
-- - Aggregate this dataset along the following dimensions
-- -- player and team
-- --- Answer questions like who scored the most points playing for one team?
-- -- player and season
-- --- Answer questions like who scored the most points in one season?
-- -- team
-- --- Answer questions like which team has won the most games?

SELECT * FROM game_details LIMIT 50;
SELECT * FROM player_seasons LIMIT 50;
SELECT * FROM game_details gd JOIN player_seasons ps ON ps.player_name = gd.player_name LIMIT 50;

WITH team_points AS (
  SELECT game_id, team_abbreviation, sum(pts) total_pts
  from game_details
  group by game_id, team_abbreviation order by 1
),
     team_winners AS (
       select tp1.*, tp2.total_pts, tp2.team_abbreviation,
              case when tp1.total_pts > tp2.total_pts then tp1.team_abbreviation
                   when tp1.total_pts < tp2.total_pts then tp2.team_abbreviation
                   else 'DRAW' end winners,
              row_number() OVER (PARTITION BY tp1.game_id order by tp1.total_pts)
       from team_points tp1
              join team_points tp2 on tp1.game_id = tp2.game_id and tp1.team_abbreviation != tp2.team_abbreviation
     )
select * from team_winners where winners = 'DRAW';

WITH team_points AS (
  SELECT game_id, team_abbreviation, sum(pts) total_own_pts
  from game_details
  group by game_id, team_abbreviation order by 1
)
   , teams_comparison AS (
  select *, LAG(total_own_pts, 1) OVER
    (PARTITION BY game_id order by total_own_pts ASC ) total_vs_pts,
         LAG(team_abbreviation, 1) OVER
           (PARTITION BY game_id order by total_own_pts ASC ) team_vs
    , LEAD(total_own_pts, 1) OVER
    (PARTITION BY game_id order by total_own_pts ASC) total_vs_pts2,
         LEAD(team_abbreviation, 1) OVER
           (PARTITION BY game_id order by total_own_pts ASC) team_vs2
  from team_points
)
select * from teams_comparison;
, teams_winners AS (
  SELECT game_id,
         CASE WHEN total_own_pts > total_vs_pts THEN team_abbreviation
              WHEN total_own_pts < total_vs_pts THEN team_vs
              ELSE 'Draw' END team_winner
--     CONCAT(game_id, '-',
--            CASE WHEN total_own_pts > total_vs_pts THEN team_abbreviation
--                 WHEN total_own_pts < total_vs_pts THEN team_vs
--                 ELSE 'Draw' END ) team_winner
  FROM teams_comparison -- where game_id = '22000050'
  WHERE team_vs IS NOT NULL -- AND total_own_pts != total_vs_pts
)
--   SELECT * FROM teams_winners;
;

WITH team_points AS (
  SELECT game_id, team_abbreviation, sum(pts) total_own_pts
  FROM game_details
  GROUP BY game_id, team_abbreviation ORDER BY 1
)
   , team_winner AS (
  SELECT  *,
--     game_id, team_abbreviation,
          CASE WHEN COALESCE(LAG(total_own_pts, 1) OVER (PARTITION BY game_id ORDER BY total_own_pts), total_own_pts) -- total_vs_pts
            < total_own_pts THEN 1 ELSE 0 END winner
  FROM team_points
)
-- select * from team_winner -- where game_id = '22000050';
   , analysis as (
  SELECT COALESCE(ps.player_name, 'Overall') AS player_name,
         COALESCE(CAST(ps.season AS TEXT), 'Overall') AS season,
         COALESCE(gd.team_abbreviation, 'Overall') AS team,
         SUM(ps.pts) sum_pts, COUNT(DISTINCT CASE WHEN tw.winner = 1 THEN gd.game_id END) sum_winners
  FROM game_details gd
         JOIN team_winner tw ON tw.game_id = gd.game_id AND tw.team_abbreviation = gd.team_abbreviation
         JOIN player_seasons ps ON ps.player_name = gd.player_name
  GROUP BY GROUPING SETS (
    (ps.player_name, gd.team_abbreviation),
    (ps.player_name, ps.season),
    (gd.team_abbreviation) )
)
select * from analysis --;
-- where player_name is null
-- where season is null;
--   where team_abbreviation is null;

-- FINAL VERSION

WITH team_points AS (
  SELECT game_id, team_abbreviation, sum(pts) total_own_pts
  FROM game_details
  GROUP BY game_id, team_abbreviation ORDER BY 1
)
   , team_winner AS (
  SELECT  *,
          CASE WHEN COALESCE(LAG(total_own_pts, 1) OVER
            (PARTITION BY game_id ORDER BY total_own_pts), total_own_pts) -- total_vs_pts
            < total_own_pts THEN 1 ELSE 0 END winner
  FROM team_points
)
   , team_player_season_analysis AS (
  SELECT COALESCE(ps.player_name, 'Overall') AS player_name,
         COALESCE(CAST(ps.season AS TEXT), 'Overall') AS season,
         COALESCE(gd.team_abbreviation, 'Overall') AS team,
         SUM(ps.pts) sum_pts, COUNT(DISTINCT CASE WHEN tw.winner = 1 THEN gd.game_id END) sum_winners
  FROM game_details gd
         JOIN team_winner tw ON tw.game_id = gd.game_id AND tw.team_abbreviation = gd.team_abbreviation
         JOIN player_seasons ps ON ps.player_name = gd.player_name
  GROUP BY GROUPING SETS (
    (ps.player_name, gd.team_abbreviation),
    (ps.player_name, ps.season),
    (gd.team_abbreviation) )
)
  (SELECT * FROM team_player_season_analysis
   WHERE team != 'Overall' AND player_name != 'Overall' AND season = 'Overall'
   ORDER BY sum_pts DESC LIMIT 1) -- who scored most points playing for one team - Stephen Curry - GSW - 184137.56
UNION
(SELECT * FROM team_player_season_analysis
 WHERE team = 'Overall' AND player_name != 'Overall' AND season != 'Overall'
 ORDER BY sum_pts DESC LIMIT 1) -- who scored the most points in one season - James Harden - 2019 - 21587.672
UNION
(SELECT * FROM team_player_season_analysis
 WHERE team != 'Overall' AND player_name = 'Overall' AND season = 'Overall'
 ORDER BY sum_winners DESC LIMIT 1) -- which team has won the most games - GSW - 445
;

SELECT *
FROM games g
       JOIN game_details gd ON gd.game_id = g.game_id
       JOIN player_seasons ps ON ps.player_name = gd.player_name AND ps.season = g.season;



-- FINAL QUERY
WITH team_winner AS (
  SELECT g.game_id, g.season, gd.team_abbreviation, CASE
                                                      WHEN g.home_team_id = gd.team_id AND g.home_team_wins = 1 THEN 1
                                                      WHEN g.visitor_team_id = gd.team_id AND g.home_team_wins = 0 THEN 1
                                                      ELSE 0 END winner_ind, -- winner
         gd.player_name, gd.pts
  FROM games g
         JOIN game_details gd ON gd.game_id = g.game_id
--   WHERE gd.pts IS NOT NULL
)
-- select * from team_winner -- where game_id = 22200162
   , team_player_season_analysis AS (
  SELECT COALESCE(tw.player_name, 'Overall') AS player_name,
         COALESCE(CAST(tw.season AS TEXT), 'Overall') AS season,
         COALESCE(tw.team_abbreviation, 'Overall') AS team,
         SUM(CASE WHEN tw.pts IS NOT NULL THEN tw.pts ELSE 0 END) sum_pts,
         COUNT(DISTINCT CASE WHEN tw.winner_ind = 1 THEN tw.game_id END) sum_winners
  FROM team_winner tw
  GROUP BY GROUPING SETS (
    (tw.player_name, tw.team_abbreviation),
    (tw.player_name, tw.season),
    (tw.team_abbreviation) )
)
  (SELECT * FROM team_player_season_analysis
   WHERE team != 'Overall' AND player_name != 'Overall' AND season = 'Overall'
   ORDER BY sum_pts DESC LIMIT 1) -- who scored most points playing for one team - Giannis Antetokounmpo - MIL - 15591
UNION
(SELECT * FROM team_player_season_analysis
 WHERE team = 'Overall' AND player_name != 'Overall' AND season != 'Overall'
 ORDER BY sum_pts DESC LIMIT 1) -- who scored the most points in one season - James Harden - 2019 - 3247
UNION
(SELECT * FROM team_player_season_analysis
 WHERE team != 'Overall' AND player_name = 'Overall' AND season = 'Overall'
 ORDER BY sum_winners DESC LIMIT 1) -- which team has won the most games - GSW - 445
;

SELECT g.game_id, g.season, gd.team_abbreviation, CASE
                                                    WHEN g.home_team_id = gd.team_id AND g.home_team_wins = 1 THEN 1
                                                    WHEN g.visitor_team_id = gd.team_id AND g.home_team_wins = 0 THEN 1
                                                    ELSE 0 END winner_ind, -- winner
       gd.player_name, gd.pts
FROM games g
       JOIN game_details gd ON gd.game_id = g.game_id
WHERE g.season = 2019 AND gd.player_name = 'James Harden';

-- 3.
-- - A query that uses window functions on `game_details` to find out the following things:
--   - What is the most games a team has won in a 90 game stretch?
--   - How many games in a row did LeBron James score over 10 points a game?

--1

WITH team_calendar AS (
  SELECT DISTINCT g.game_id, g.game_date_est, gd.team_abbreviation, CASE
                                                                      WHEN g.home_team_id = gd.team_id AND g.home_team_wins = 1 THEN 1
                                                                      WHEN g.visitor_team_id = gd.team_id AND g.home_team_wins = 0 THEN 1
                                                                      ELSE 0 END winner_ind -- winner
  FROM games g
         JOIN game_details gd ON gd.game_id = g.game_id
)
SELECT *
  , row_number() OVER (PARTITION BY team_abbreviation ORDER BY game_date_est) game_order,
       sum(winner_ind) OVER (PARTITION BY team_abbreviation ORDER BY game_date_est
         ROWS BETWEEN 90 PRECEDING AND CURRENT ROW) winner_streak
FROM team_calendar order by 3, 2;


-- part 1
WITH team_calendar AS (
  SELECT DISTINCT g.game_id, g.game_date_est, gd.team_abbreviation, CASE
                                                                      WHEN g.home_team_id = gd.team_id AND g.home_team_wins = 1 THEN 1
                                                                      WHEN g.visitor_team_id = gd.team_id AND g.home_team_wins = 0 THEN 1
                                                                      ELSE 0 END winner_ind -- winner
  FROM games g
         JOIN game_details gd ON gd.game_id = g.game_id
)
SELECT *
  , row_number() OVER (PARTITION BY team_abbreviation ORDER BY game_date_est) game_order,
       sum(winner_ind) OVER (PARTITION BY team_abbreviation ORDER BY game_date_est
         ROWS BETWEEN 90 PRECEDING AND CURRENT ROW) winner_streak
FROM team_calendar
ORDER BY winner_streak DESC LIMIT 1;
--   - What is the most games a team has won in a 90 game stretch?
-- Answer: GSW achieved 78 wins in a 90 games stretch in 2017-06-07


-- part 2
--   - How many games in a row did LeBron James score over 10 points a game?
WITH lebron_calendar AS (
  SELECT DISTINCT g.game_id, g.game_date_est, gd.team_abbreviation, gd.pts
  FROM games g
         JOIN game_details gd ON gd.game_id = g.game_id
  WHERE player_name = 'LeBron James'
)
   , cummulative_order as (
  select *
       , row_number() OVER (ORDER BY game_date_est) game_order
       , sum(case when pts > 10 then 1 else 0 end) OVER (ORDER BY game_date_est) cum_10_pts
  from lebron_calendar)
   , grouped_order as (
  select *, game_order - cum_10_pts as streak_groups
  from cummulative_order
)
select streak_groups, count(*) n_streak,
       min(game_date_est) streak_start, max(game_date_est) streak_end
from grouped_order
group by streak_groups order by n_streak desc;

-- this second query is considered from a "family" of queries (pattern) called "gaps and islands"