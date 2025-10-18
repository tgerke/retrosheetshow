#' Parse Retrosheet Event Records into Structured Format
#'
#' Takes a tibble of raw event records and parses them into a more structured
#' format with separate columns for different record types.
#'
#' @param events_raw Tibble from `get_events()` containing raw parsed records
#' @param record_types Character vector of record types to include. If NULL
#'   (default), includes all record types. Common types include:
#'   * `"id"` - Game ID
#'   * `"version"` - File format version
#'   * `"info"` - Game information (date, teams, site, etc.)
#'   * `"start"` - Starting lineups
#'   * `"play"` - Play-by-play events
#'   * `"sub"` - Substitutions
#'   * `"com"` - Comments
#'   * `"data"` - Additional data
#'
#' @return A tibble with parsed and structured event data
#'
#' @examples
#' \dontrun{
#' # Get raw events and parse them
#' events_raw <- get_events(year = 2024)
#' 
#' # Parse into structured format
#' events_parsed <- parse_event_records(events_raw)
#' 
#' # Get only play-by-play records
#' plays <- parse_event_records(events_raw, record_types = "play")
#' }
#'
#' @export
parse_event_records <- function(events_raw, record_types = NULL) {
  
  if (!is.null(record_types)) {
    events_raw <- events_raw |>
      dplyr::filter(.data$record_type %in% record_types)
  }
  
  # Parse different record types
  events_raw |>
    dplyr::mutate(
      parsed_data = purrr::map2(.data$record_type, .data$fields, parse_record_by_type)
    ) |>
    tidyr::unnest_wider(.data$parsed_data, names_repair = "unique")
}

#' Parse individual record based on type
#' @keywords internal
parse_record_by_type <- function(type, fields) {
  
  # Handle empty fields
  if (length(fields) == 0) {
    return(list(value = NA_character_))
  }
  
  result <- switch(type,
    "id" = list(
      game_id = fields[1]
    ),
    "version" = list(
      version = fields[1]
    ),
    "info" = parse_info_record(fields),
    "start" = parse_start_record(fields),
    "play" = parse_play_record(fields),
    "sub" = parse_sub_record(fields),
    "com" = list(
      comment = paste(fields, collapse = ",")
    ),
    "data" = parse_data_record(fields),
    # Default: just combine fields
    list(
      value = paste(fields, collapse = ",")
    )
  )
  
  result
}

#' Parse info record
#' @keywords internal
parse_info_record <- function(fields) {
  list(
    info_type = fields[1],
    info_value = if (length(fields) > 1) fields[2] else NA_character_
  )
}

#' Parse starting lineup record
#' @keywords internal
parse_start_record <- function(fields) {
  list(
    player_id = fields[1],
    player_name = if (length(fields) > 1) fields[2] else NA_character_,
    team = if (length(fields) > 2) as.integer(fields[3]) else NA_integer_,
    batting_order = if (length(fields) > 3) as.integer(fields[4]) else NA_integer_,
    position = if (length(fields) > 4) as.integer(fields[5]) else NA_integer_
  )
}

#' Parse play record
#' @keywords internal
parse_play_record <- function(fields) {
  list(
    inning = if (length(fields) > 0) as.integer(fields[1]) else NA_integer_,
    team = if (length(fields) > 1) as.integer(fields[2]) else NA_integer_,
    player_id = if (length(fields) > 2) fields[3] else NA_character_,
    count = if (length(fields) > 3) fields[4] else NA_character_,
    pitches = if (length(fields) > 4) fields[5] else NA_character_,
    event = if (length(fields) > 5) fields[6] else NA_character_
  )
}

#' Parse substitution record
#' @keywords internal
parse_sub_record <- function(fields) {
  list(
    player_id = fields[1],
    player_name = if (length(fields) > 1) fields[2] else NA_character_,
    team = if (length(fields) > 2) as.integer(fields[3]) else NA_integer_,
    batting_order = if (length(fields) > 3) as.integer(fields[4]) else NA_integer_,
    position = if (length(fields) > 4) as.integer(fields[5]) else NA_integer_
  )
}

#' Parse data record
#' @keywords internal
parse_data_record <- function(fields) {
  list(
    data_type = fields[1],
    player_id = if (length(fields) > 1) fields[2] else NA_character_,
    earned_runs = if (length(fields) > 2) as.integer(fields[3]) else NA_integer_
  )
}

#' Get Game Information from Parsed Events
#'
#' Extracts game-level information (date, teams, site, etc.) from parsed
#' event data.
#'
#' @param events_data Tibble from `get_events()`
#'
#' @return A tibble with one row per game containing game metadata
#'
#' @examples
#' \dontrun{
#' events <- get_events(year = 2024)
#' game_info <- get_game_info(events)
#' }
#'
#' @export
get_game_info <- function(events_data) {
  events_data |>
    dplyr::filter(.data$record_type == "info") |>
    parse_event_records() |>
    dplyr::select(.data$game_id, .data$year, .data$type, .data$info_type, .data$info_value) |>
    tidyr::pivot_wider(
      names_from = .data$info_type,
      values_from = .data$info_value
    )
}

#' Get Play-by-Play Data from Events
#'
#' Extracts and parses play-by-play records from event data.
#'
#' @param events_data Tibble from `get_events()`
#'
#' @return A tibble with one row per play
#'
#' @examples
#' \dontrun{
#' events <- get_events(year = 2024)
#' plays <- get_plays(events)
#' }
#'
#' @export
get_plays <- function(events_data) {
  events_data |>
    dplyr::filter(.data$record_type == "play") |>
    parse_event_records()
}

