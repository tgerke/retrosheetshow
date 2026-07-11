#' List Available Retrosheet Schedule Files
#'
#' Returns a tibble of available Retrosheet schedule files. Schedules contain
#' planned game dates, times, and teams.
#'
#' @param year Numeric vector of years to check. If NULL (default), checks
#'   all years (1877 onward).
#' @param check_availability Logical. If TRUE (default), verifies that files
#'   actually exist and drops those that don't.
#'
#' @return A tibble with columns:
#'   * `year` - The year
#'   * `type` - Always "schedule"
#'   * `url` - The URL to download
#'
#' @examples
#' \dontrun{
#' # List recent schedules
#' list_schedules(year = 2020:2024)
#' }
#'
#' @export
list_schedules <- function(year = NULL, check_availability = TRUE) {

  years <- if (is.null(year)) 1877:retro_max_year() else year

  schedules_df <- tibble::tibble(
    year = years,
    type = "schedule",
    url = as.character(
      glue::glue("{retrosheet_base_url()}/schedule/{years}SKED.zip")
    )
  )

  if (check_availability) {
    cli::cli_progress_step(
      "Checking availability of {nrow(schedules_df)} schedule file{?s}",
      msg_done = "Checked {nrow(schedules_df)} schedule file{?s}"
    )

    schedules_df <- schedules_df |>
      dplyr::filter(purrr::map_lgl(.data$url, url_exists))

    if (nrow(schedules_df) == 0) {
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
#'   * `game_number` - 0 for a single game, 1-2 for doubleheaders
#'   * `day_of_week` - Day of week
#'   * `visiting_team`, `visiting_league`, `visiting_game_number`
#'   * `home_team`, `home_league`, `home_game_number`
#'   * `day_night` - Day/night indicator
#'   * `location` - Park ID when the game was scheduled at a non-home site
#'     (only recorded in recent seasons; NA otherwise)
#'   * `postponed` - Postponement/cancellation reason, if any
#'   * `makeup_date` - Makeup date for postponed games
#'   * `year` - Year
#'
#' @examples
#' \dontrun{
#' # Get 2024 schedule
#' schedule_2024 <- get_schedules(year = 2024)
#'
#' # Find postponed games
#' schedule_2024 |>
#'   dplyr::filter(!is.na(postponed))
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

  all_data <- purrr::map2_dfr(
    schedules$url,
    schedules$year,
    function(url, yr) {
      if (verbose) {
        cli::cli_progress_step("Processing {yr} schedule")
      }

      tryCatch({
        zip_file <- retro_download(
          url,
          cache_filename = basename(url),
          timeout = 30,
          verbose = verbose
        )
        if (!caching_enabled()) {
          on.exit(unlink(zip_file), add = TRUE)
        }

        extracted <- retro_extract(zip_file, pattern = "schedule\\.csv$")
        on.exit(unlink(extracted$dir, recursive = TRUE), add = TRUE)

        if (length(extracted$files) == 0) {
          cli::cli_warn("No schedule file found in {yr} archive")
          return(tibble::tibble())
        }

        read_schedule_file(extracted$files[1], year = yr)

      }, error = function(e) {
        cli::cli_warn("Failed to download {yr} schedule: {e$message}")
        tibble::tibble()
      })
    }
  )

  if (verbose && nrow(all_data) > 0) {
    cli::cli_alert_success(
      "Downloaded {format(nrow(all_data), big.mark = ',')} scheduled game{?s}"
    )
  }

  all_data
}

#' Read a Retrosheet schedule CSV
#'
#' Schedule files have a header row. Recent seasons (2024+) include a
#' `Location` column between Day/Night and Postponed; older files have 12
#' columns. Both variants are normalized to the same 13-column layout.
#'
#' @param path Path to a {year}schedule.csv file
#' @param year Year of the data
#' @noRd
read_schedule_file <- function(path, year) {

  schedule_names <- c(
    "date", "game_number", "day_of_week",
    "visiting_team", "visiting_league", "visiting_game_number",
    "home_team", "home_league", "home_game_number",
    "day_night", "location", "postponed", "makeup_date"
  )

  raw <- readr::read_csv(
    path,
    col_names = FALSE,
    skip = 1,
    col_types = readr::cols(.default = "c"),
    show_col_types = FALSE
  )

  if (ncol(raw) == 13) {
    names(raw) <- schedule_names
  } else if (ncol(raw) == 12) {
    names(raw) <- setdiff(schedule_names, "location")
    raw$location <- NA_character_
  } else {
    cli::cli_abort(
      "Unexpected schedule format for {year}: {ncol(raw)} columns"
    )
  }

  raw |>
    dplyr::mutate(
      dplyr::across(
        c("game_number", "visiting_game_number", "home_game_number"),
        as.integer
      ),
      year = year
    ) |>
    dplyr::relocate(dplyr::all_of(schedule_names))
}
