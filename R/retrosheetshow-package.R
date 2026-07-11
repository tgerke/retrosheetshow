#' retrosheetshow: Access and Parse Retrosheet Baseball Data
#'
#' Provides a convenient and tidy interface for accessing Retrosheet baseball 
#' data, including play-by-play event files, game logs, rosters, schedules, 
#' and reference data. Functions follow tidyverse principles for easy 
#' integration into data analysis workflows.
#'
#' @section Main Functions:
#' 
#' **Events (Play-by-Play)**
#' * [list_events()], [get_events()], [get_plays()], [get_game_info()]
#' 
#' **Game Logs (Summary Stats)**
#' * [list_gamelogs()], [get_gamelogs()], [gamelog_fields()]
#' 
#' **Rosters and Schedules**
#' * [get_rosters()], [list_schedules()], [get_schedules()]
#' 
#' **Reference Data**
#' * [get_park_ids()], [get_team_ids()], [get_player_ids()]
#' 
#' **Cache Management**
#' * [cache_status()], [clear_cache()], [use_cache()]
#'
#' @section Retrosheet Data Notice:
#' 
#' **IMPORTANT:** The information used here was obtained free of charge from 
#' and is copyrighted by Retrosheet. Interested parties may contact Retrosheet 
#' at 20 Sunset Rd., Newark, DE 19711.
#' 
#' Website: \url{https://www.retrosheet.org}
#'
#' @section Getting Started:
#' 
#' ```
#' library(retrosheetshow)
#' 
#' # Download play-by-play events
#' events <- get_events(year = 2024)
#' 
#' # Get game logs (faster, summary stats)
#' gamelogs <- get_gamelogs(year = 2024)
#' 
#' # Get team rosters
#' rosters <- get_rosters(year = 2024, team = "NYA")
#' ```
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
## usethis namespace: end
NULL

