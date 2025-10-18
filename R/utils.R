#' Retrosheet Base URL
#' @keywords internal
retrosheet_base_url <- function() {
  "https://www.retrosheet.org"
}

#' Construct Retrosheet Event File URLs
#' @keywords internal
#' @param year Year of the data
#' @param type Type of events ("regular", "allstar", "post")
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
#' @keywords internal
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
#' @keywords internal
get_available_years <- function(type = "regular") {
  type <- match.arg(type, c("regular", "allstar", "post"))
  
  # These ranges are based on the Retrosheet documentation
  year_ranges <- list(
    regular = 1911:2024,
    allstar = c(1933:1944, 1946:2019, 2021:2024),
    post = c(1903, 1905:1993, 1995:2024)
  )
  
  year_ranges[[type]]
}

