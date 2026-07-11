#' Parse Retrosheet Event Records into Structured Format
#'
#' Takes a tibble of raw event records from `get_events()` and interprets the
#' generic field columns (`f1`-`f6`) according to each record type, adding
#' named, typed columns.
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
#' @return A tibble with one row per record. Columns depend on the record
#'   types present:
#'   * `info`: `info_type`, `info_value`
#'   * `start`/`sub`: `player_id`, `player_name`, `team`, `batting_order`,
#'     `position`
#'   * `play`: `inning`, `team`, `player_id`, `count`, `pitches`, `event`
#'   * `com`: `comment`
#'   * `data`: `data_type`, `player_id`, `earned_runs`
#'   * `version`: `version`
#'
#'   Records of other types get their fields combined into a `value` column.
#'   When multiple record types are included, columns not applying to a row
#'   are NA.
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

  if (nrow(events_raw) == 0) {
    return(events_raw |> dplyr::select(-dplyr::starts_with("f")))
  }

  # Parse each record type with vectorized operations, then restore the
  # original row order
  events_raw |>
    dplyr::mutate(.row = dplyr::row_number()) |>
    (\(df) split(df, df$record_type))() |>
    purrr::imap(parse_records_of_type) |>
    dplyr::bind_rows() |>
    dplyr::arrange(.data$.row) |>
    dplyr::select(-".row")
}

#' Parse all records of one type (vectorized)
#' @param df Tibble of records sharing one record_type, with f1-f6 columns
#' @param type The record type
#' @noRd
parse_records_of_type <- function(df, type) {

  base <- df |>
    dplyr::select(-dplyr::matches("^f\\d+$"))

  parsed <- switch(type,
    # game_id column already carries the id
    "id" = NULL,
    "version" = tibble::tibble(
      version = df$f1
    ),
    "info" = tibble::tibble(
      info_type = df$f1,
      info_value = df$f2
    ),
    "start" = ,
    "sub" = tibble::tibble(
      player_id = df$f1,
      player_name = df$f2,
      team = int_or_na(df$f3),
      batting_order = int_or_na(df$f4),
      position = int_or_na(df$f5)
    ),
    "play" = tibble::tibble(
      inning = int_or_na(df$f1),
      team = int_or_na(df$f2),
      player_id = df$f3,
      count = df$f4,
      pitches = df$f5,
      event = df$f6
    ),
    "com" = tibble::tibble(
      comment = combine_fields(df)
    ),
    "data" = tibble::tibble(
      data_type = df$f1,
      player_id = df$f2,
      earned_runs = int_or_na(df$f3)
    ),
    # Default (badj, padj, radj, ...): combine fields
    tibble::tibble(
      value = combine_fields(df)
    )
  )

  if (is.null(parsed)) base else dplyr::bind_cols(base, parsed)
}

#' Combine a record's non-missing fields into one string
#' @noRd
combine_fields <- function(df) {
  df |>
    dplyr::select(dplyr::matches("^f\\d+$")) |>
    purrr::pmap_chr(function(...) {
      fields <- c(...)
      paste(fields[!is.na(fields)], collapse = ",")
    })
}

#' Convert to integer, mapping unparseable values to NA without warnings
#' @noRd
int_or_na <- function(x) {
  suppressWarnings(as.integer(x))
}

#' Get Game Information from Parsed Events
#'
#' Extracts game-level information (date, teams, site, etc.) from parsed
#' event data.
#'
#' @param events_data Tibble from `get_events()`
#'
#' @return A tibble with one row per game containing game metadata, one
#'   column per info type present in the data (e.g. `visteam`, `hometeam`,
#'   `date`, `site`, `attendance`). If a game repeats an info type, the
#'   values are collapsed with "; ".
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
    dplyr::select(
      dplyr::any_of(c("game_id", "year", "type")),
      "info_type", "info_value"
    ) |>
    tidyr::pivot_wider(
      names_from = "info_type",
      values_from = "info_value",
      values_fn = collapse_info_values
    )
}

#' Collapse duplicated info values for one game without stringifying NA
#' @noRd
collapse_info_values <- function(x) {
  x <- unique(x[!is.na(x)])
  if (length(x) == 0) NA_character_ else paste(x, collapse = "; ")
}

#' Get Play-by-Play Data from Events
#'
#' Extracts and parses play-by-play records from event data.
#'
#' @param events_data Tibble from `get_events()`
#'
#' @return A tibble with one row per play, with columns `inning`, `team`
#'   (0 = visiting, 1 = home), `player_id`, `count`, `pitches`, and `event`,
#'   in addition to the identifying columns from `events_data`
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
