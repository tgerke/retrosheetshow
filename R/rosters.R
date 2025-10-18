#' Get Retrosheet Rosters
#'
#' Extracts team rosters from Retrosheet event files. Roster files are included
#' in the event archives and contain player information by team.
#'
#' @param year Numeric vector of years
#' @param team Optional. Character vector of team codes to filter. If NULL
#'   (default), returns all teams.
#' @param verbose Logical. If TRUE (default), displays progress.
#'
#' @return A tibble with columns:
#'   * `year` - Year
#'   * `player_id` - Retrosheet player ID
#'   * `last_name` - Last name
#'   * `first_name` - First name
#'   * `bats` - Batting hand (R/L/B)
#'   * `throws` - Throwing hand (R/L)
#'   * `team` - Team code
#'   * `position` - Primary position
#'
#' @details
#' Rosters are extracted from event file ZIP archives. The first call for a
#' year will download the event file if not cached. Subsequent calls use the
#' cached file.
#'
#' @examples
#' \dontrun{
#' # Get all 2024 rosters
#' rosters_2024 <- get_rosters(year = 2024)
#'
#' # Get Yankees roster
#' yankees <- get_rosters(year = 2024, team = "NYA")
#'
#' # Get multiple years
#' rosters <- get_rosters(year = 2020:2024)
#' }
#'
#' @export
get_rosters <- function(year, team = NULL, verbose = TRUE) {
  
  if (is.null(year)) {
    cli::cli_abort("Must provide {.arg year}")
  }
  
  if (verbose) {
    cli::cli_alert_info("Extracting rosters for {length(year)} year{?s}")
  }
  
  # Download rosters for each year
  all_rosters <- purrr::map_dfr(year, function(yr) {
    if (verbose) {
      cli::cli_progress_step("Processing {yr} rosters")
    }
    
    # Construct URL for regular season events (rosters are in there)
    url <- construct_event_url(yr, "regular")
    temp_dir <- tempdir()
    
    # Check cache
    use_cached <- caching_enabled()
    cache_path <- if (use_cached) cache_file_path(yr, "regular") else NULL
    cached <- use_cached && !is.null(cache_path) && file.exists(cache_path)
    
    if (cached) {
      if (verbose) {
        cli::cli_alert_info("Using cached event file for {yr}")
      }
      zip_file <- cache_path
    } else {
      zip_file <- if (use_cached) cache_path else tempfile(fileext = ".zip")
      
      if (verbose) {
        cli::cli_alert_info("Downloading {yr} event file for rosters...")
      }
    }
    
    tryCatch({
      # Download if not cached
      if (!cached) {
        httr2::request(url) |>
          httr2::req_retry(max_tries = 3, backoff = ~2) |>
          httr2::req_timeout(60) |>
          httr2::req_perform(path = zip_file)
      }
      
      # Extract ZIP
      unzip(zip_file, exdir = temp_dir, overwrite = TRUE)
      
      # Find roster files (.ROS extension)
      roster_files <- list.files(
        temp_dir,
        pattern = "\\.ROS$",
        full.names = TRUE,
        ignore.case = TRUE
      )
      
      if (length(roster_files) == 0) {
        cli::cli_warn("No roster files found for {yr}")
        return(tibble::tibble())
      }
      
      # Read and combine all roster files
      rosters <- purrr::map_dfr(roster_files, function(file) {
        # Get team code from filename (e.g., NYA2024.ROS -> NYA)
        team_code <- stringr::str_extract(basename(file), "^[A-Z]{3}")
        
        # Read roster file
        roster_data <- readr::read_csv(
          file,
          col_names = c(
            "player_id", "last_name", "first_name",
            "bats", "throws", "team", "position"
          ),
          col_types = readr::cols(.default = "c"),
          show_col_types = FALSE
        )
        
        # If team not in file, use from filename
        if (all(is.na(roster_data$team)) || all(roster_data$team == "")) {
          roster_data$team <- team_code
        }
        
        roster_data
      })
      
      rosters <- rosters |>
        dplyr::mutate(year = yr)
      
      # Clean up extracted files
      unlink(roster_files)
      
      # Clean up temp zip if not using cache
      if (!use_cached || is.null(cache_path) || cache_path != zip_file) {
        unlink(zip_file)
      }
      
      rosters
      
    }, error = function(e) {
      cli::cli_warn("Failed to extract rosters for {yr}: {e$message}")
      tibble::tibble()
    })
  })
  
  # Filter by team if requested
  if (!is.null(team)) {
    all_rosters <- all_rosters |>
      dplyr::filter(.data$team %in% {{team}})
  }
  
  if (verbose && nrow(all_rosters) > 0) {
    n_teams <- all_rosters |> 
      dplyr::distinct(.data$year, .data$team) |> 
      nrow()
    cli::cli_alert_success(
      "Extracted {scales::comma(nrow(all_rosters))} player{?s} from {n_teams} team{?s}"
    )
  }
  
  all_rosters |>
    dplyr::arrange(.data$year, .data$team, .data$last_name)
}

