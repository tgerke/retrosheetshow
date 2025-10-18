# retrosheetshow 0.0.0.9000

## New features

* **Game Logs** - Access summary game statistics
  - `list_gamelogs(year)` - List available game log files
  - `get_gamelogs(year)` - Download and parse game logs
  - `gamelog_fields()` - Get field descriptions for ~170 columns
  - One row per game with team stats, lineups, umpires, decisions
  - Much smaller/faster than full play-by-play events
  - Cached automatically like event files
  - Example: `gamelogs <- get_gamelogs(year = 2024)`

* **Team Rosters** - Get player rosters by team and year
  - `get_rosters(year, team)` - Extract rosters from event files
  - Player names, IDs, batting/throwing hands, positions
  - Filter by specific teams
  - Example: `yankees <- get_rosters(year = 2024, team = "NYA")`

* **Game Schedules** - Access scheduled games
  - `list_schedules(year)` - List available schedules
  - `get_schedules(year)` - Download and parse schedules
  - Planned dates, times, teams, postponement info
  - Cached automatically
  - Example: `schedule <- get_schedules(year = 2024)`

* **Reference Data Helpers** - Get Retrosheet codes and IDs
  - `get_park_ids()` - Ballpark codes and stadium information
  - `get_team_ids(year)` - Team codes for a given year
  - `get_player_ids()` - Complete player biographical database
  - All helpers return tidy tibbles
  - Example: `parks |> filter(grepl("Fenway", name))`

* **Enhanced Network Robustness** - Downloads are more reliable
  - Automatic retry logic with exponential backoff (up to 3 attempts)
  - Configurable timeouts (60s for data, 10s for availability checks)
  - Better error handling and user feedback
  - Uses modern httr2 retry capabilities

* **Smart Caching System** - Downloads are now cached automatically
  - First download: ~2 minutes
  - Subsequent access: ~5 seconds (uses local cache)
  - `cache_status()` - View cached files
  - `clear_cache()` - Remove cached files to free space
  - `use_cache()` - Enable/disable caching for current session
  - Cache persists across R sessions
  - See `PERFORMANCE.md` for details

* `list_events()` - List available Retrosheet event files by year and type
  - Supports regular season, all-star, and post-season games
  - Optional availability checking
  - Returns tidy tibble format
  
* `get_events()` - Download and parse Retrosheet event files
  - Automatically downloads and extracts ZIP files
  - **Now with smart caching for fast repeated access**
  - Parses Retrosheet format into structured tibbles
  - Pipe-friendly interface
  - Works seamlessly with `list_events()`
  
* `parse_event_records()` - Parse raw event records into structured format
  - Handles different record types (id, info, play, sub, etc.)
  - Returns nested tibbles with parsed fields
  
* `get_game_info()` - Extract game-level metadata
  - Converts info records to wide format
  - One row per game with all metadata columns
  
* `get_plays()` - Extract play-by-play data
  - Filters and parses play records
  - Returns structured play-by-play tibble

## Design Principles

* Follows tidyverse conventions
* Pipe-friendly functions
* Returns tibbles
* Progress feedback via cli
* Automatic cleanup of temporary files
* Type-safe parsing

## Data Coverage

* Regular season: 1911-2024
* All-Star games: 1933-2024 (with gaps)
* Post-season: 1903-2024 (with gaps)

## Known Limitations

* Event files prior to 1911 use box score format (not yet supported)
* Some years have incomplete coverage (see Retrosheet documentation)
* Large downloads may take time depending on connection speed

