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

  all_rosters <- purrr::map_dfr(year, function(yr) {
    if (verbose) {
      cli::cli_progress_step("Processing {yr} rosters")
    }

    url <- construct_event_url(yr, "regular")

    tryCatch({
      zip_file <- retro_download(
        url,
        cache_filename = basename(url),
        timeout = 60,
        verbose = verbose
      )
      if (!caching_enabled()) {
        on.exit(unlink(zip_file), add = TRUE)
      }

      extracted <- retro_extract(zip_file, pattern = "\\.ROS$")
      on.exit(unlink(extracted$dir, recursive = TRUE), add = TRUE)

      if (length(extracted$files) == 0) {
        cli::cli_warn("No roster files found for {yr}")
        return(tibble::tibble())
      }

      purrr::map_dfr(extracted$files, read_roster_file) |>
        dplyr::mutate(year = yr)

    }, error = function(e) {
      cli::cli_warn("Failed to extract rosters for {yr}: {e$message}")
      tibble::tibble()
    })
  })

  # Filter by team if requested
  if (!is.null(team)) {
    team_filter <- team
    all_rosters <- all_rosters |>
      dplyr::filter(.data$team %in% team_filter)
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

#' Read a single Retrosheet roster (.ROS) file
#' @param file Path to a roster file (e.g. NYA2024.ROS)
#' @noRd
read_roster_file <- function(file) {
  roster_data <- readr::read_csv(
    file,
    col_names = c(
      "player_id", "last_name", "first_name",
      "bats", "throws", "team", "position"
    ),
    col_types = readr::cols(.default = "c"),
    show_col_types = FALSE
  )

  # Some historical files omit the team column; fall back to the filename
  # (e.g. NYA2024.ROS -> NYA)
  if (all(is.na(roster_data$team) | roster_data$team == "")) {
    roster_data$team <- stringr::str_extract(basename(file), "^[A-Z]{3}")
  }

  roster_data
}
