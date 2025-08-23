
-- The homework this week will be using the `players`, `players_scd`, and `player_seasons` tables from week 1


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

WITH team_winner AS (
  SELECT g.game_id, g.season, gd.team_abbreviation, CASE
    WHEN g.home_team_id = gd.team_id AND g.home_team_wins = 1 THEN 1
    WHEN g.visitor_team_id = gd.team_id AND g.home_team_wins = 0 THEN 1
    ELSE 0 END winner_ind, -- winner
  gd.player_name, gd.pts
  FROM games g
  JOIN game_details gd ON gd.game_id = g.game_id
)
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


-- 3.
-- - A query that uses window functions on `game_details` to find out the following things:
--   - What is the most games a team has won in a 90 game stretch?
--   - How many games in a row did LeBron James score over 10 points a game?


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

--   - How many games in a row did LeBron James score over 10 points a game?
-- The max number of games in a row over 10 points a game were 63 games between 2019-10-18 and 2020-07-25