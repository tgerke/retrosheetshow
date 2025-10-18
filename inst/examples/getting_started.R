# retrosheetshow - Getting Started Examples
# ==========================================

# RETROSHEET DATA NOTICE
# ======================
# The information used here was obtained free of charge from and is 
# copyrighted by Retrosheet. Interested parties may contact Retrosheet 
# at 20 Sunset Rd., Newark, DE 19711.
# Website: https://www.retrosheet.org

library(retrosheetshow)
library(dplyr)

# IMPORTANT: First downloads take 1-2 minutes but are cached!
# Subsequent runs will be much faster (~5 seconds)

# Example 1: List Available Event Files
# --------------------------------------

# List recent regular season files
recent_regular <- list_events(year = 2023:2024)
print(recent_regular)

# List all available postseason files for recent years
recent_postseason <- list_events(
  year = 2020:2024,
  type = "post"
)
print(recent_postseason)

# List multiple types for a specific year
all_2024 <- list_events(
  year = 2024,
  type = c("regular", "allstar", "post")
)
print(all_2024)


# Example 2: Download and Parse Event Files
# ------------------------------------------

# Download 2024 regular season events
# First time: ~2 minutes (downloads and caches)
# Subsequent times: ~5 seconds (uses cache)
events_2024 <- get_events(year = 2024)

# View the structure
glimpse(events_2024)

# See what record types are available
events_2024 |>
  count(record_type, sort = TRUE)


# Example 2b: Cache Management
# -----------------------------

# Check what's cached
cache_status()

# Clear specific year from cache
# clear_cache(year = 2020, confirm = FALSE)

# Disable caching for this session (always download fresh)
# use_cache(FALSE)


# Example 3: Extract Game Information
# ------------------------------------

# Get game metadata
game_info <- get_game_info(events_2024)

# View columns
names(game_info)

# Filter to specific teams (e.g., New York Yankees)
yankees_games <- game_info |>
  filter(visteam == "NYA" | hometeam == "NYA")


# Example 4: Extract Play-by-Play Data
# -------------------------------------

# Get all plays
all_plays <- get_plays(events_2024)

# View structure
glimpse(all_plays)

# Get plays for a specific game
game_plays <- all_plays |>
  filter(game_id == first(game_id))


# Example 5: Pipe Workflow
# -------------------------

# Get recent World Series plays
ws_plays <- list_events(year = 2020:2024, type = "post") |>
  get_events() |>
  get_plays() |>
  left_join(
    get_game_info(get_events(list_events(year = 2020:2024, type = "post"))),
    by = c("game_id", "year", "type")
  ) |>
  filter(grepl("^WS", game_id))


# Example 6: Parse Specific Record Types
# ---------------------------------------

# Get only substitution records
subs <- events_2024 |>
  parse_event_records(record_types = "sub")

# Get starting lineups
starters <- events_2024 |>
  parse_event_records(record_types = "start")


# Example 7: Multi-Year Analysis
# -------------------------------

# Download multiple years
multi_year <- get_events(year = 2022:2024)

# Count games by year
multi_year |>
  filter(record_type == "id") |>
  count(year)


# Example 8: All-Star Game Analysis
# ----------------------------------

# Get All-Star game data
allstar <- list_events(year = 2010:2024, type = "allstar") |>
  get_events()

# Extract game info
allstar_info <- get_game_info(allstar)

# Get plays from all-star games
allstar_plays <- get_plays(allstar)


# Example 9: Error Handling
# --------------------------

# Gracefully handle unavailable years
tryCatch({
  old_data <- get_events(year = 1850)
}, error = function(e) {
  message("No data available for that year")
})


# Example 10: Quick Analysis Example
# -----------------------------------

# Count home runs in 2024 season
# (Note: Retrosheet event codes use "HR" for home runs in the event field)
hr_2024 <- events_2024 |>
  get_plays() |>
  filter(grepl("HR", event, fixed = TRUE)) |>
  count(player_id, sort = TRUE)

print(head(hr_2024, 10))

