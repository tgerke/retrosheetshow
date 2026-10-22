#' Download and Parse Retrosheet Event Files
#'
#' Downloads Retrosheet event files and parses them into a tidy tibble format.
#' This function can accept either a tibble from `list_events()` or direct
#' parameters to specify which files to download.
#'
#' @param events Optional tibble from `list_events()`. If provided, downloads
#'   all files specified in the tibble. If NULL, uses `year` and `type` parameters.
#' @param year Numeric vector of years to download. Ignored if `events` is provided.
#' @param type Character vector of event types ("regular", "allstar", "post").
#'   Default is "regular". Ignored if `events` is provided.
#' @param parse Logical. If TRUE (default), parses the event files into a tibble.
#'   If FALSE, returns raw text content.
#' @param verbose Logical. If TRUE (default), displays progress messages.
#'
#' @return A tibble with one row per record in the event files:
#'   * `game_id` - Unique game identifier (filled down from `id` records)
#'   * `record_type` - Type of record (id, version, info, start, play, sub, etc.)
#'   * `f1`-`f6` - The record's fields as character columns; their meaning
#'     depends on `record_type` (use [parse_event_records()] to interpret them)
#'   * `line_number` - Line number within the source event file
#'   * `year` - Year of the game
#'   * `type` - Type of event file (regular, allstar, post)
#'
#'   If `parse = FALSE`, a tibble with `year`, `type`, and `content` (one raw
#'   line per row) instead.
#'
#' @details
#' Retrosheet event files contain play-by-play data in a structured text format.
#' Each line represents a different type of record (game info, starting lineups,
#' plays, substitutions, etc.). This function downloads the files and parses them
#' into a tidy format suitable for analysis.
#'
#' ## Caching
#'
#' Downloaded files are cached by default to speed up repeated access.
#' Use `cache_status()` to view cached files and `clear_cache()` to remove them.
#' Disable caching with `use_cache(FALSE)`.
#'
#' @examples
#' \dontrun{
#' # Download and parse specific years
#' events_2024 <- get_events(year = 2024)
#'
#' # Use with list_events() in a pipe
#' recent_games <- list_events(year = 2020:2024) |>
#'   get_events()
#'
#' # Download multiple types
#' postseason_2023 <- get_events(year = 2023, type = "post")
#'
#' # Get raw data without parsing
#' raw_data <- get_events(year = 2024, parse = FALSE)
#' }
#'
#' @export
get_events <- function(events = NULL,
                       year = NULL,
                       type = "regular",
                       parse = TRUE,
                       verbose = TRUE) {

  # If events tibble not provided, create one
  if (is.null(events)) {
    if (is.null(year)) {
      cli::cli_abort("Must provide either {.arg events} tibble or {.arg year}")
    }
    events <- list_events(year = year, type = type, check_availability = TRUE)
  }

  # Validate events tibble
  required_cols <- c("year", "type", "url")
  if (!all(required_cols %in% names(events))) {
    cli::cli_abort(
      "{.arg events} must have columns: {.field {required_cols}}"
    )
  }

  if (nrow(events) == 0) {
    cli::cli_warn("No events to download")
    return(tibble::tibble())
  }

  if (verbose) {
    cli::cli_alert_info("Downloading {nrow(events)} event file{?s}")
  }

  # Download and parse each file
  all_data <- purrr::pmap_dfr(
    list(events$url, events$year, events$type),
    function(url, yr, event_type) {
      if (verbose) {
        cli::cli_progress_step("Processing {yr} {event_type} events")
      }

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

        # Event files use .EVA, .EVN, or .EVE extensions
        extracted <- retro_extract(zip_file, pattern = "\\.(EVA|EVN|EVE)$")
        on.exit(unlink(extracted$dir, recursive = TRUE), add = TRUE)

        if (length(extracted$files) == 0) {
          cli::cli_warn("No event files found in {yr} {event_type} archive")
          return(tibble::tibble())
        }

        # lapply() rather than purrr::map_dfr(), which would wrap a parse
        # error in its own error and hide the class the handler below expects
        all_events <- dplyr::bind_rows(lapply(extracted$files, function(file) {
          if (parse) {
            tryCatch(
              parse_event_file(file, year = yr),
              error = function(e) {
                cli::cli_abort(
                  "{conditionMessage(e)}",
                  file = basename(file),
                  class = "retrosheetshow_parse_error"
                )
              }
            )
          } else {
            tibble::tibble(
              year = yr,
              content = readr::read_lines(file, lazy = FALSE)
            )
          }
        }))

        all_events$type <- event_type
        all_events

      }, retrosheetshow_parse_error = function(e) {
        cli::cli_warn(
          "Failed to parse {e$file} in {yr} {event_type} events: {e$message}"
        )
        tibble::tibble()
      }, error = function(e) {
        cli::cli_warn("Failed to download {yr} {event_type} events: {e$message}")
        tibble::tibble()
      })
    }
  )

  if (verbose) {
    cli::cli_alert_success(
      "Downloaded and parsed {format(nrow(all_data), big.mark = ',')} {cli::qty(nrow(all_data))}record{?s}"
    )
  }

  all_data
}

#' Parse a Retrosheet event file
#'
#' Reads a full event file with a quote-aware CSV parser (comment records can
#' contain quoted commas) into one row per record, with the record's fields in
#' character columns `f1`, `f2`, ... Fields a record doesn't have are NA.
#'
#' A record never spans lines, but `read.csv()` lets a quoted field run on
#' into the next line, so one stray quote would swallow every record after
#' it. The quotes are therefore paired up line by line first: a curly double
#' quote that opens or closes a field is read as a straight one, and a quote
#' still open at the end of a line is closed there. Lines with neither
#' problem reach `read.csv()` unchanged.
#'
#' @param file Path to an event file (.EVA/.EVN/.EVE)
#' @param year Year of the data
#' @noRd
parse_event_file <- function(file, year) {

  lines <- readLines(file, warn = FALSE)
  # 1976BAL.EVA has comments opened with a curly quote and closed with a
  # straight one
  lines <- gsub(
    "(^|,)(\u201c|\u201d)", "\\1\"", lines, perl = TRUE, useBytes = TRUE
  )
  lines <- gsub(
    "(\u201c|\u201d)(,|$)", "\"\\2", lines, perl = TRUE, useBytes = TRUE
  )
  n_quotes <- nchar(lines, type = "bytes") -
    nchar(gsub("\"", "", lines, fixed = TRUE, useBytes = TRUE), type = "bytes")
  unclosed <- n_quotes %% 2 == 1
  lines[unclosed] <- paste0(lines[unclosed], "\"")

  # Not read.csv(text = ), which marks non-ASCII strings as UTF-8: reading
  # from a file returns them exactly as reading the event file itself does
  paired <- tempfile(fileext = ".csv")
  on.exit(unlink(paired), add = TRUE)
  writeLines(lines, paired, useBytes = TRUE)

  # Play records have 7 fields (the most of any standard record type); size
  # the read to the widest record actually present
  n_fields <- max(
    7L,
    utils::count.fields(paired, sep = ",", quote = "\"", comment.char = "")
  )

  raw <- utils::read.csv(
    paired,
    header = FALSE,
    fill = TRUE,
    quote = "\"",
    comment.char = "",
    colClasses = "character",
    col.names = c("record_type", paste0("f", seq_len(n_fields - 1))),
    blank.lines.skip = TRUE
  )

  tibble::as_tibble(raw) |>
    dplyr::mutate(
      dplyr::across(dplyr::starts_with("f"), ~ dplyr::na_if(.x, "")),
      line_number = dplyr::row_number(),
      year = year,
      game_id = dplyr::if_else(
        .data$record_type == "id", .data$f1, NA_character_
      )
    ) |>
    tidyr::fill("game_id", .direction = "down") |>
    dplyr::relocate("game_id", "record_type")
}
