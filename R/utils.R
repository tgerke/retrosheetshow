#' Retrosheet Base URL
#' @noRd
retrosheet_base_url <- function() {
  "https://www.retrosheet.org"
}

#' Most recent season with published Retrosheet files
#'
#' Bump this constant when Retrosheet releases a new season. Requested years
#' beyond it are still honored when passed explicitly; this only bounds the
#' default "all years" ranges in the list_* functions.
#' @noRd
retro_max_year <- function() {
  2025L
}

#' Construct Retrosheet Event File URLs
#' @param year Year of the data
#' @param type Type of events ("regular", "allstar", "post")
#' @noRd
construct_event_url <- function(year, type = "regular") {
  base <- retrosheet_base_url()

  type <- match.arg(type, c("regular", "allstar", "post"))

  filename <- switch(type,
    regular = glue::glue("{year}eve.zip"),
    allstar = glue::glue("{year}as.zip"),
    post = glue::glue("{year}post.zip")
  )

  glue::glue("{base}/events/{filename}")
}

#' Check if URL exists
#' @noRd
url_exists <- function(url) {
  tryCatch({
    resp <- httr2::request(url) |>
      httr2::req_method("HEAD") |>
      httr2::req_retry(max_tries = 2) |>
      httr2::req_timeout(10) |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform()
    httr2::resp_status(resp) == 200
  }, error = function(e) {
    FALSE
  })
}

#' Get available years for a given event type
#' @noRd
get_available_years <- function(type = "regular") {
  type <- match.arg(type, c("regular", "allstar", "post"))

  # No All-Star game in 1945 or 2020; no post-season in 1904 or 1994
  year_ranges <- list(
    regular = 1911:retro_max_year(),
    allstar = c(1933:1944, 1946:2019, 2021:retro_max_year()),
    post = c(1903, 1905:1993, 1995:retro_max_year())
  )

  year_ranges[[type]]
}
