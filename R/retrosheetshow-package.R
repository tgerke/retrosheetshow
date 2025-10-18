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
#' @importFrom tibble tibble
#' @importFrom dplyr mutate filter select arrange left_join case_when
#' @importFrom tidyr unnest_wider pivot_wider fill
#' @importFrom purrr map_dfr map_chr map_lgl map2_dfr map2 pmap_dfr
#' @importFrom stringr str_split str_extract
#' @importFrom cli cli_progress_step cli_alert_info cli_alert_success cli_warn cli_abort cli_inform
#' @importFrom glue glue
#' @importFrom httr2 request req_perform req_method req_error resp_status req_retry req_timeout resp_body_string
#' @importFrom readr read_lines read_csv
#' @importFrom scales comma
#' @importFrom rlang .data
#' @importFrom tools R_user_dir
#' @importFrom utils unzip
## usethis namespace: end
NULL

