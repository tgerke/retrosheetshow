#' List Available Retrosheet Game Log Files
#'
#' Returns a tibble of available Retrosheet game log files. Game logs contain
#' summary statistics for each game (one row per game) rather than play-by-play
#' detail.
#'
#' @param year Numeric vector of years to check. If NULL (default), checks all
#'   available years (1871-2024).
#' @param check_availability Logical. If TRUE (default), verifies that files
#'   actually exist on Retrosheet servers.
#'
#' @return A tibble with columns:
#'   * `year` - The year of the data
#'   * `type` - Always "gamelog"
#'   * `url` - The URL to download the file
#'   * `available` - Logical indicating if file exists (only if
#'     `check_availability = TRUE`)
#'
#' @details
#' Game logs provide summary statistics for each game including runs, hits,
#' errors, pitchers, umpires, and more. They are much smaller than event files
#' and faster to download/parse. See [glfields.txt](https://www.retrosheet.org/gamelogs/glfields.txt)
#' for complete field descriptions.
#'
#' @examples
#' \dontrun{
#' # List recent game logs
#' list_gamelogs(year = 2020:2024)
#'
#' # List all available (fast check)
#' list_gamelogs(check_availability = FALSE)
#' }
#'
#' @export
list_gamelogs <- function(year = NULL, check_availability = TRUE) {
  
  # Game logs available from 1871-2024
  years <- if (is.null(year)) 1871:2024 else year
  
  # Construct URLs
  gamelogs_df <- tibble::tibble(
    year = years,
    type = "gamelog",
    url = glue::glue("https://www.retrosheet.org/gamelogs/gl{year}.zip")
  )
  
  # Check availability if requested
  if (check_availability) {
    cli::cli_progress_step(
      "Checking availability of {nrow(gamelogs_df)} game log file{?s}",
      msg_done = "Checked {nrow(gamelogs_df)} game log file{?s}"
    )
    
    gamelogs_df <- gamelogs_df |>
      dplyr::mutate(
        available = purrr::map_lgl(.data$url, url_exists)
      )
    
    n_available <- sum(gamelogs_df$available)
    gamelogs_df <- gamelogs_df |>
      dplyr::filter(.data$available)
    
    if (n_available == 0) {
      cli::cli_warn("No game log files found")
    }
  }
  
  gamelogs_df |>
    dplyr::arrange(dplyr::desc(.data$year))
}

#' Download and Parse Retrosheet Game Log Files
#'
#' Downloads Retrosheet game log files and parses them into a tidy tibble.
#' Game logs contain one row per game with summary statistics.
#'
#' @param gamelogs Optional tibble from `list_gamelogs()`. If NULL, uses `year`.
#' @param year Numeric vector of years to download. Ignored if `gamelogs` provided.
#' @param verbose Logical. If TRUE (default), displays progress messages.
#'
#' @return A tibble with game-level statistics. Columns include:
#'   * `date` - Game date
#'   * `game_number` - Game number (0 = single game, 1-2 = doubleheader)
#'   * `day_of_week` - Day of week
#'   * `visiting_team` - Visiting team code
#'   * `visiting_league` - Visiting team league
#'   * `visiting_game_number` - Visiting team's game number
#'   * `home_team` - Home team code
#'   * `home_league` - Home team league
#'   * `home_game_number` - Home team's game number
#'   * `visiting_score` - Visiting team runs
#'   * `home_score` - Home team runs
#'   * And ~160 more fields with detailed statistics
#'
#' @details
#' ## Caching
#'
#' Game log files are cached automatically for fast repeated access. Use
#' `cache_status()` to view cached files and `clear_cache()` to remove them.
#'
#' ## Field Descriptions
#'
#' Game logs contain extensive statistics. See
#' [glfields.txt](https://www.retrosheet.org/gamelogs/glfields.txt) for
#' complete field descriptions. Use `gamelog_fields()` to get a vector of all
#' field names with descriptions.
#'
#' @examples
#' \dontrun{
#' # Download 2024 game log
#' gamelogs_2024 <- get_gamelogs(year = 2024)
#'
#' # Pipe from list
#' gamelogs <- list_gamelogs(year = 2020:2024) |>
#'   get_gamelogs()
#'
#' # Analyze home field advantage
#' gamelogs_2024 |>
#'   mutate(home_win = home_score > visiting_score) |>
#'   summarize(home_win_pct = mean(home_win))
#' }
#'
#' @export
get_gamelogs <- function(gamelogs = NULL, year = NULL, verbose = TRUE) {
  
  # If gamelogs tibble not provided, create one
  if (is.null(gamelogs)) {
    if (is.null(year)) {
      cli::cli_abort("Must provide either {.arg gamelogs} tibble or {.arg year}")
    }
    gamelogs <- list_gamelogs(year = year, check_availability = TRUE)
  }
  
  if (nrow(gamelogs) == 0) {
    cli::cli_warn("No game logs to download")
    return(tibble::tibble())
  }
  
  if (verbose) {
    cli::cli_alert_info("Downloading {nrow(gamelogs)} game log file{?s}")
  }
  
  # Download and parse each file
  all_data <- purrr::map2_dfr(
    gamelogs$url,
    gamelogs$year,
    function(url, yr) {
      if (verbose) {
        cli::cli_progress_step("Processing {yr} game log")
      }
      
      temp_dir <- tempdir()
      
      # Check cache
      use_cached <- caching_enabled()
      cache_path <- if (use_cached) {
        file.path(cache_dir(), glue::glue("gl{yr}.zip"))
      } else {
        NULL
      }
      cached <- use_cached && !is.null(cache_path) && file.exists(cache_path)
      
      if (cached) {
        if (verbose) {
          cli::cli_alert_info("Using cached file for {yr}")
        }
        zip_file <- cache_path
      } else {
        zip_file <- if (use_cached) cache_path else tempfile(fileext = ".zip")
        
        if (verbose) {
          cli::cli_alert_info("Downloading {yr} game log...")
        }
      }
      
      tryCatch({
        # Download if not cached
        if (!cached) {
          httr2::request(url) |>
            httr2::req_retry(max_tries = 3, backoff = ~2) |>
            httr2::req_timeout(30) |>
            httr2::req_perform(path = zip_file)
        }
        
        # Extract ZIP
        unzip(zip_file, exdir = temp_dir, overwrite = TRUE)
        
        # Find CSV file (should be GL{YEAR}.TXT)
        csv_files <- list.files(
          temp_dir,
          pattern = glue::glue("^GL{yr}\\.TXT$"),
          full.names = TRUE,
          ignore.case = TRUE
        )
        
        if (length(csv_files) == 0) {
          cli::cli_warn("No game log file found in {yr} archive")
          return(tibble::tibble())
        }
        
        # Read CSV (no headers in Retrosheet game logs)
        game_data <- readr::read_csv(
          csv_files[1],
          col_names = gamelog_field_names(),
          col_types = readr::cols(.default = "c"),
          show_col_types = FALSE
        ) |>
          dplyr::mutate(year = yr)
        
        # Clean up extracted files
        unlink(csv_files)
        
        # Clean up temp zip if not using cache
        if (!use_cached || is.null(cache_path) || cache_path != zip_file) {
          unlink(zip_file)
        }
        
        game_data
        
      }, error = function(e) {
        cli::cli_warn("Failed to download {yr}: {e$message}")
        tibble::tibble()
      })
    }
  )
  
  if (verbose && nrow(all_data) > 0) {
    cli::cli_alert_success(
      "Downloaded {scales::comma(nrow(all_data))} game{?s}"
    )
  }
  
  all_data
}

#' Get Game Log Field Names
#' @keywords internal
gamelog_field_names <- function() {
  c(
    "date", "game_number", "day_of_week",
    "visiting_team", "visiting_league", "visiting_game_number",
    "home_team", "home_league", "home_game_number",
    "visiting_score", "home_score", "length_outs",
    "day_night", "completion_info", "forfeit_info", "protest_info",
    "park_id", "attendance", "time_of_game",
    "visiting_line_score", "home_line_score",
    "visiting_ab", "visiting_h", "visiting_d", "visiting_t", "visiting_hr",
    "visiting_rbi", "visiting_sh", "visiting_sf", "visiting_hbp",
    "visiting_bb", "visiting_ibb", "visiting_k", "visiting_sb", "visiting_cs",
    "visiting_gidp", "visiting_ci", "visiting_lob",
    "visiting_pitchers_used", "visiting_individual_er", "visiting_team_er",
    "visiting_wp", "visiting_balks", "visiting_po", "visiting_a",
    "visiting_e", "visiting_passed_balls", "visiting_dp", "visiting_tp",
    "home_ab", "home_h", "home_d", "home_t", "home_hr",
    "home_rbi", "home_sh", "home_sf", "home_hbp",
    "home_bb", "home_ibb", "home_k", "home_sb", "home_cs",
    "home_gidp", "home_ci", "home_lob",
    "home_pitchers_used", "home_individual_er", "home_team_er",
    "home_wp", "home_balks", "home_po", "home_a",
    "home_e", "home_passed_balls", "home_dp", "home_tp",
    "hp_umpire_id", "hp_umpire_name",
    "1b_umpire_id", "1b_umpire_name",
    "2b_umpire_id", "2b_umpire_name",
    "3b_umpire_id", "3b_umpire_name",
    "lf_umpire_id", "lf_umpire_name",
    "rf_umpire_id", "rf_umpire_name",
    "visiting_manager_id", "visiting_manager_name",
    "home_manager_id", "home_manager_name",
    "winning_pitcher_id", "winning_pitcher_name",
    "losing_pitcher_id", "losing_pitcher_name",
    "saving_pitcher_id", "saving_pitcher_name",
    "game_winning_rbi_id", "game_winning_rbi_name",
    "visiting_starting_pitcher_id", "visiting_starting_pitcher_name",
    "home_starting_pitcher_id", "home_starting_pitcher_name",
    "visiting_player_1_id", "visiting_player_1_name", "visiting_player_1_pos",
    "visiting_player_2_id", "visiting_player_2_name", "visiting_player_2_pos",
    "visiting_player_3_id", "visiting_player_3_name", "visiting_player_3_pos",
    "visiting_player_4_id", "visiting_player_4_name", "visiting_player_4_pos",
    "visiting_player_5_id", "visiting_player_5_name", "visiting_player_5_pos",
    "visiting_player_6_id", "visiting_player_6_name", "visiting_player_6_pos",
    "visiting_player_7_id", "visiting_player_7_name", "visiting_player_7_pos",
    "visiting_player_8_id", "visiting_player_8_name", "visiting_player_8_pos",
    "visiting_player_9_id", "visiting_player_9_name", "visiting_player_9_pos",
    "home_player_1_id", "home_player_1_name", "home_player_1_pos",
    "home_player_2_id", "home_player_2_name", "home_player_2_pos",
    "home_player_3_id", "home_player_3_name", "home_player_3_pos",
    "home_player_4_id", "home_player_4_name", "home_player_4_pos",
    "home_player_5_id", "home_player_5_name", "home_player_5_pos",
    "home_player_6_id", "home_player_6_name", "home_player_6_pos",
    "home_player_7_id", "home_player_7_name", "home_player_7_pos",
    "home_player_8_id", "home_player_8_name", "home_player_8_pos",
    "home_player_9_id", "home_player_9_name", "home_player_9_pos",
    "additional_info", "acquisition_info"
  )
}

#' Get Game Log Field Descriptions
#'
#' Returns a tibble describing all fields in Retrosheet game logs.
#'
#' @return A tibble with columns `field_name` and `description`
#'
#' @examples
#' \dontrun{
#' # See all field descriptions
#' gamelog_fields()
#'
#' # Find fields about home runs
#' gamelog_fields() |> filter(grepl("hr", field_name, ignore.case = TRUE))
#' }
#'
#' @export
gamelog_fields <- function() {
  tibble::tibble(
    field_name = gamelog_field_names(),
    description = c(
      "Date (YYYYMMDD)", "Game number (0=single, 1-2=doubleheader)", "Day of week",
      "Visiting team", "Visiting team league", "Visiting team game number",
      "Home team", "Home team league", "Home team game number",
      "Visiting team score", "Home team score", "Length in outs",
      "Day/night indicator", "Completion information", "Forfeit information", "Protest information",
      "Park ID", "Attendance", "Time of game (minutes)",
      "Visiting line score", "Home line score",
      paste("Visiting", c("at bats", "hits", "doubles", "triples", "home runs",
                           "RBI", "sacrifice hits", "sacrifice flies", "hit by pitch",
                           "walks", "intentional walks", "strikeouts", "stolen bases", "caught stealing",
                           "grounded into DP", "catcher interference", "left on base",
                           "pitchers used", "individual ER", "team ER",
                           "wild pitches", "balks", "putouts", "assists",
                           "errors", "passed balls", "double plays", "triple plays")),
      paste("Home", c("at bats", "hits", "doubles", "triples", "home runs",
                       "RBI", "sacrifice hits", "sacrifice flies", "hit by pitch",
                       "walks", "intentional walks", "strikeouts", "stolen bases", "caught stealing",
                       "grounded into DP", "catcher interference", "left on base",
                       "pitchers used", "individual ER", "team ER",
                       "wild pitches", "balks", "putouts", "assists",
                       "errors", "passed balls", "double plays", "triple plays")),
      "Home plate umpire ID", "Home plate umpire name",
      "1st base umpire ID", "1st base umpire name",
      "2nd base umpire ID", "2nd base umpire name",
      "3rd base umpire ID", "3rd base umpire name",
      "Left field umpire ID", "Left field umpire name",
      "Right field umpire ID", "Right field umpire name",
      "Visiting manager ID", "Visiting manager name",
      "Home manager ID", "Home manager name",
      "Winning pitcher ID", "Winning pitcher name",
      "Losing pitcher ID", "Losing pitcher name",
      "Saving pitcher ID", "Saving pitcher name",
      "Game winning RBI ID", "Game winning RBI name",
      "Visiting starting pitcher ID", "Visiting starting pitcher name",
      "Home starting pitcher ID", "Home starting pitcher name",
      rep(c("Visiting player ID", "Visiting player name", "Visiting player position"), 9),
      rep(c("Home player ID", "Home player name", "Home player position"), 9),
      "Additional information", "Acquisition information"
    )
  )
}

