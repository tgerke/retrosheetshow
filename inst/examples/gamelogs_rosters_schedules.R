# retrosheetshow - Game Logs, Rosters, and Schedules Examples
# ============================================================

# RETROSHEET DATA NOTICE
# ======================
# The information used here was obtained free of charge from and is 
# copyrighted by Retrosheet. Interested parties may contact Retrosheet 
# at 20 Sunset Rd., Newark, DE 19711.
# Website: https://www.retrosheet.org

library(retrosheetshow)
library(dplyr)

# GAME LOGS: Summary statistics (one row per game)
# =================================================

# Example 1: Download 2024 Game Logs
# -----------------------------------

gamelogs_2024 <- get_gamelogs(year = 2024)

# View structure
glimpse(gamelogs_2024)

# Basic stats
gamelogs_2024 |>
  summarize(
    total_games = n(),
    avg_attendance = mean(as.numeric(attendance), na.rm = TRUE),
    total_home_runs = sum(as.numeric(visiting_hr) + as.numeric(home_hr), na.rm = TRUE)
  )


# Example 2: Home Field Advantage Analysis
# -----------------------------------------

gamelogs_2024 |>
  mutate(
    home_won = as.numeric(home_score) > as.numeric(visiting_score)
  ) |>
  summarize(
    home_win_pct = mean(home_won, na.rm = TRUE)
  )


# Example 3: Highest Scoring Games
# ---------------------------------

gamelogs_2024 |>
  mutate(
    total_runs = as.numeric(visiting_score) + as.numeric(home_score)
  ) |>
  arrange(desc(total_runs)) |>
  select(date, visiting_team, home_team, visiting_score, home_score, total_runs) |>
  head(10)


# Example 4: Team Performance
# ----------------------------

# Calculate win-loss records
team_records <- bind_rows(
  gamelogs_2024 |>
    mutate(
      team = visiting_team,
      won = as.numeric(visiting_score) > as.numeric(home_score)
    ),
  gamelogs_2024 |>
    mutate(
      team = home_team,
      won = as.numeric(home_score) > as.numeric(visiting_score)
    )
) |>
  group_by(team) |>
  summarize(
    games = n(),
    wins = sum(won),
    losses = games - wins,
    win_pct = wins / games
  ) |>
  arrange(desc(win_pct))

print(team_records)


# Example 5: Pitcher Decisions
# -----------------------------

# Most wins by pitcher
gamelogs_2024 |>
  count(winning_pitcher_name, sort = TRUE) |>
  head(10)

# Most saves
gamelogs_2024 |>
  filter(!is.na(saving_pitcher_name) & saving_pitcher_name != "") |>
  count(saving_pitcher_name, sort = TRUE) |>
  head(10)


# Example 6: Field Descriptions
# ------------------------------

# See all available fields
fields <- gamelog_fields()
print(fields)

# Find fields related to home runs
fields |>
  filter(grepl("hr|home run", field_name, ignore.case = TRUE))


# ROSTERS: Team Rosters by Year
# ==============================

# Example 7: Get All 2024 Rosters
# --------------------------------

rosters_2024 <- get_rosters(year = 2024)

# View structure
glimpse(rosters_2024)

# Count players by team
rosters_2024 |>
  count(team, sort = TRUE)


# Example 8: Get Specific Team Roster
# ------------------------------------

# Yankees roster
yankees <- get_rosters(year = 2024, team = "NYA")
print(yankees)

# Multiple teams
ny_teams <- get_rosters(year = 2024, team = c("NYA", "NYN"))


# Example 9: Batting Hand Analysis
# ---------------------------------

rosters_2024 |>
  count(bats) |>
  mutate(pct = n / sum(n))


# Example 10: Multi-Year Roster Tracking
# ---------------------------------------

# Track roster changes over time
multi_year_rosters <- get_rosters(year = 2022:2024, team = "NYA")

# Find players who were on roster multiple years
multi_year_rosters |>
  count(player_id, last_name, first_name, sort = TRUE) |>
  filter(n > 1)


# SCHEDULES: Game Schedules
# ==========================

# Example 11: Get 2024 Schedule
# ------------------------------

schedule_2024 <- get_schedules(year = 2024)

# View structure
glimpse(schedule_2024)


# Example 12: Find Day Games
# ---------------------------

schedule_2024 |>
  filter(grepl("^1[0-4]:", game_time)) |>
  count(home_team, sort = TRUE)


# Example 13: Games by Day of Week
# ---------------------------------

schedule_2024 |>
  count(day_of_week, sort = TRUE)


# Example 14: Team Schedule
# --------------------------

# Yankees home games
schedule_2024 |>
  filter(home_team == "NYA") |>
  select(date, visiting_team, game_time, day_of_week)


# Example 15: Postponed Games
# ----------------------------

schedule_2024 |>
  filter(!is.na(postponement_indicator) & postponement_indicator != "")


# COMBINED ANALYSIS
# =================

# Example 16: Join Game Logs with Rosters
# ----------------------------------------

# Get winning pitchers from Yankees
yankees_wins <- gamelogs_2024 |>
  filter(home_team == "NYA" | visiting_team == "NYA") |>
  left_join(
    rosters_2024 |> select(player_id, last_name, first_name, team),
    by = c("winning_pitcher_id" = "player_id")
  ) |>
  filter(team == "NYA") |>
  select(date, visiting_team, home_team, winning_pitcher_name)


# Example 17: Schedule vs Actual Games
# -------------------------------------

# Compare scheduled vs actual
scheduled <- schedule_2024 |>
  count(date, name = "scheduled_games")

actual <- gamelogs_2024 |>
  count(date, name = "actual_games")

scheduled |>
  left_join(actual, by = "date") |>
  filter(scheduled_games != actual_games | is.na(actual_games))


# Example 18: Complete Team Analysis
# -----------------------------------

# Combine rosters, schedule, and game logs for comprehensive analysis
yankees_2024_analysis <- list(
  roster = get_rosters(year = 2024, team = "NYA"),
  schedule = get_schedules(year = 2024) |>
    filter(home_team == "NYA" | visiting_team == "NYA"),
  games = get_gamelogs(year = 2024) |>
    filter(home_team == "NYA" | visiting_team == "NYA")
)

# Roster size
cat("Roster size:", nrow(yankees_2024_analysis$roster), "players\n")

# Games played
cat("Games played:", nrow(yankees_2024_analysis$games), "\n")

# Home vs away
yankees_2024_analysis$games |>
  mutate(location = if_else(home_team == "NYA", "Home", "Away")) |>
  count(location)


# PERFORMANCE TIPS
# ================

# Tip 1: Game logs are much faster than full events for summary stats
system.time({
  gamelogs <- get_gamelogs(year = 2024)  # Fast! ~5-10 seconds with cache
})

# Tip 2: Rosters reuse event file cache
system.time({
  rosters <- get_rosters(year = 2024)  # Very fast if events already cached
})

# Tip 3: Download once, analyze many times
data_2024 <- list(
  events = get_events(year = 2024),
  gamelogs = get_gamelogs(year = 2024),
  rosters = get_rosters(year = 2024),
  schedule = get_schedules(year = 2024)
)

# Now analyze without re-downloading
# ... your analysis here ...


# CACHE MANAGEMENT
# ================

# Check what's cached
cache_status()

# Clear old cache if needed
# clear_cache(year = 2020:2021)

