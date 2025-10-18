#' List Available Retrosheet Schedule Files
#'
#' Returns a tibble of available Retrosheet schedule files. Schedules contain
#' planned game dates, times, and teams.
#'
#' @param year Numeric vector of years to check. If NULL (default), checks
#'   recent years (1877-2024).
#' @param check_availability Logical. If TRUE (default), verifies that files
#'   actually exist.
#'
#' @return A tibble with columns:
#'   * `year` - The year
#'   * `type` - Always "schedule"
#'   * `url` - The URL to download
#'   * `available` - Logical (only if `check_availability = TRUE`)
#'
#' @examples
#' \dontrun{
#' # List recent schedules
#' list_schedules(year = 2020:2024)
#' }
#'
#' @export
list_schedules <- function(year = NULL, check_availability = TRUE) {
  
  # Schedules available from 1877-2024
  years <- if (is.null(year)) 1877:2024 else year
  
  schedules_df <- tibble::tibble(
    year = years,
    type = "schedule",
    url = glue::glue("https://www.retrosheet.org/schedule/{year}SKED.TXT")
  )
  
  if (check_availability) {
    cli::cli_progress_step(
      "Checking availability of {nrow(schedules_df)} schedule file{?s}",
      msg_done = "Checked {nrow(schedules_df)} schedule file{?s}"
    )
    
    schedules_df <- schedules_df |>
      dplyr::mutate(
        available = purrr::map_lgl(.data$url, url_exists)
      )
    
    n_available <- sum(schedules_df$available)
    schedules_df <- schedules_df |>
      dplyr::filter(.data$available)
    
    if (n_available == 0) {
      cli::cli_warn("No schedule files found")
    }
  }
  
  schedules_df |>
    dplyr::arrange(dplyr::desc(.data$year))
}

#' Download and Parse Retrosheet Schedule Files
#'
#' Downloads Retrosheet schedule files and parses them into a tidy tibble.
#'
#' @param schedules Optional tibble from `list_schedules()`. If NULL, uses `year`.
#' @param year Numeric vector of years. Ignored if `schedules` provided.
#' @param verbose Logical. If TRUE (default), displays progress.
#'
#' @return A tibble with columns:
#'   * `date` - Game date (YYYYMMDD)
#'   * `game_number` - Game number
#'   * `day_of_week` - Day of week
#'   * `visiting_team` - Visiting team code
#'   * `visiting_league` - Visiting team league
#'   * `home_team` - Home team code
#'   * `home_league` - Home team league
#'   * `game_time` - Scheduled time
#'   * `postponement_indicator` - If postponed
#'   * `year` - Year
#'
#' @examples
#' \dontrun{
#' # Get 2024 schedule
#' schedule_2024 <- get_schedules(year = 2024)
#'
#' # Find all day games
#' schedule_2024 |>
#'   filter(grepl("^1[0-4]:", game_time))
#' }
#'
#' @export
get_schedules <- function(schedules = NULL, year = NULL, verbose = TRUE) {
  
  if (is.null(schedules)) {
    if (is.null(year)) {
      cli::cli_abort("Must provide either {.arg schedules} tibble or {.arg year}")
    }
    schedules <- list_schedules(year = year, check_availability = TRUE)
  }
  
  if (nrow(schedules) == 0) {
    cli::cli_warn("No schedules to download")
    return(tibble::tibble())
  }
  
  if (verbose) {
    cli::cli_alert_info("Downloading {nrow(schedules)} schedule file{?s}")
  }
  
  # Download and parse each file
  all_data <- purrr::map2_dfr(
    schedules$url,
    schedules$year,
    function(url, yr) {
      if (verbose) {
        cli::cli_progress_step("Processing {yr} schedule")
      }
      
      # Check cache
      use_cached <- caching_enabled()
      cache_path <- if (use_cached) {
        file.path(cache_dir(), glue::glue("{yr}SKED.TXT"))
      } else {
        NULL
      }
      cached <- use_cached && !is.null(cache_path) && file.exists(cache_path)
      
      if (cached) {
        if (verbose) {
          cli::cli_alert_info("Using cached file for {yr}")
        }
        file_path <- cache_path
      } else {
        file_path <- if (use_cached) cache_path else tempfile(fileext = ".txt")
        
        if (verbose) {
          cli::cli_alert_info("Downloading {yr} schedule...")
        }
      }
      
      tryCatch({
        # Download if not cached
        if (!cached) {
          httr2::request(url) |>
            httr2::req_retry(max_tries = 3, backoff = ~2) |>
            httr2::req_timeout(15) |>
            httr2::req_perform(path = file_path)
        }
        
        # Read and parse
        schedule_data <- readr::read_csv(
          file_path,
          col_names = c(
            "date", "game_number", "day_of_week",
            "visiting_team", "visiting_league",
            "home_team", "home_league",
            "game_time", "postponement_indicator", "makeup_date"
          ),
          col_types = readr::cols(.default = "c"),
          show_col_types = FALSE
        ) |>
          dplyr::mutate(year = yr)
        
        # Clean up temp file if not using cache
        if (!use_cached || is.null(cache_path) || cache_path != file_path) {
          unlink(file_path)
        }
        
        schedule_data
        
      }, error = function(e) {
        cli::cli_warn("Failed to download {yr}: {e$message}")
        tibble::tibble()
      })
    }
  )
  
  if (verbose && nrow(all_data) > 0) {
    cli::cli_alert_success(
      "Downloaded {scales::comma(nrow(all_data))} scheduled game{?s}"
    )
  }
  
  all_data
}

