#' List Available Retrosheet Event Files
#'
#' Returns a tibble of available Retrosheet event files that can be downloaded.
#' This function checks which files are actually available on the Retrosheet
#' servers based on the specified criteria.
#'
#' @param year Numeric vector of years to check. If NULL (default), checks all
#'   available years for the specified type. Can be a single year or a vector
#'   of years.
#' @param type Character vector specifying the type(s) of events to list.
#'   Options are:
#'   * `"regular"` - Regular season games (1911-2024)
#'   * `"allstar"` - All-Star games (1933-2024, with gaps)
#'   * `"post"` - Post-season games (1903-2024, with gaps)
#'   Default is `"regular"`.
#' @param check_availability Logical. If TRUE (default), verifies that files
#'   actually exist on Retrosheet servers. If FALSE, returns all years in the
#'   theoretical range (faster but may include non-existent files).
#'
#' @return A tibble with columns:
#'   * `year` - The year of the data
#'   * `type` - The type of events ("regular", "allstar", or "post")
#'   * `url` - The URL to download the file
#'   * `available` - Logical indicating if the file exists (only if
#'     `check_availability = TRUE`)
#'
#' @examples
#' \dontrun{
#' # List all available regular season files
#' list_events()
#'
#' # List events for specific years
#' list_events(year = 2020:2024)
#'
#' # List all types for recent years
#' list_events(year = 2023, type = c("regular", "allstar", "post"))
#'
#' # Quick list without checking availability
#' list_events(year = 2020:2024, check_availability = FALSE)
#'
#' # Use with get_events() in a pipe
#' list_events(year = 2024) |>
#'   get_events()
#' }
#'
#' @export
list_events <- function(year = NULL, 
                       type = "regular",
                       check_availability = TRUE) {
  
  # Validate type argument
  type <- match.arg(type, c("regular", "allstar", "post"), several.ok = TRUE)
  
  # Build tibble of all requested combinations
  events_df <- purrr::map_dfr(type, function(event_type) {
    years <- if (is.null(year)) {
      get_available_years(event_type)
    } else {
      year
    }
    
    tibble::tibble(
      year = years,
      type = event_type,
      url = purrr::map_chr(years, ~construct_event_url(.x, event_type))
    )
  })
  
  # Check availability if requested
  if (check_availability) {
    cli::cli_progress_step(
      "Checking availability of {nrow(events_df)} file{?s}",
      msg_done = "Checked {nrow(events_df)} file{?s}"
    )
    
    events_df <- events_df |>
      dplyr::mutate(
        available = purrr::map_lgl(.data$url, url_exists)
      )
    
    # Filter to only available files
    n_available <- sum(events_df$available)
    n_unavailable <- nrow(events_df) - n_available
    
    events_df <- events_df |>
      dplyr::filter(.data$available)
    
    if (n_available == 0) {
      cli::cli_warn("No files found matching the specified criteria")
    } else if (n_unavailable > 0) {
      cli::cli_inform("Found {n_available} available file{?s} ({n_unavailable} unavailable)")
    }
  }
  
  events_df |>
    dplyr::arrange(dplyr::desc(.data$year), .data$type)
}

