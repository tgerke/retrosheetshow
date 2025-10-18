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
#' @return A tibble containing the parsed event data with columns depending on
#'   the record type. Common columns include:
#'   * `game_id` - Unique game identifier
#'   * `record_type` - Type of record (id, version, info, start, play, sub, etc.)
#'   * `year` - Year of the game
#'   * `type` - Type of event file (regular, allstar, post)
#'
#' @details
#' Retrosheet event files contain play-by-play data in a structured text format.
#' Each line represents a different type of record (game info, starting lineups,
#' plays, substitutions, etc.). This function downloads the files and parses them
#' into a tidy format suitable for analysis.
#'
#' ## Caching
#'
#' Downloaded files are cached by default to speed up repeated access. The first
#' download may take 1-2 minutes, but subsequent calls will be much faster (seconds).
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
  
  # Determine event types for each year
  events_with_type <- events |>
    dplyr::mutate(
      event_type = dplyr::case_when(
        grepl("eve\\.zip$", .data$url) ~ "regular",
        grepl("as\\.zip$", .data$url) ~ "allstar",
        grepl("post\\.zip$", .data$url) ~ "post",
        TRUE ~ "regular"
      )
    )
  
  # Download and parse each file
  all_data <- purrr::pmap_dfr(
    list(events_with_type$url, events_with_type$year, events_with_type$event_type),
    function(url, yr, event_type) {
      if (verbose) {
        cli::cli_progress_step("Processing {yr} {event_type} events")
      }
      
      temp_dir <- tempdir()
      
      # Check cache first
      use_cached <- caching_enabled()
      cache_path <- if (use_cached) cache_file_path(yr, event_type) else NULL
      cached <- use_cached && !is.null(cache_path) && file.exists(cache_path)
      
      if (cached) {
        if (verbose) {
          cli::cli_alert_info("Using cached file for {yr} {event_type}")
        }
        zip_file <- cache_path
      } else {
        # Download to cache or temp
        if (use_cached) {
          zip_file <- cache_path
        } else {
          zip_file <- tempfile(fileext = ".zip")
        }
        
        if (verbose) {
          cli::cli_alert_info("Downloading {yr} {event_type}...")
        }
      }
      
      tryCatch({
        # Download file if not cached
        if (!cached) {
          httr2::request(url) |>
            httr2::req_retry(max_tries = 3, backoff = ~2) |>
            httr2::req_timeout(60) |>
            httr2::req_perform(path = zip_file)
        }
        
        # Extract zip
        unzip(zip_file, exdir = temp_dir, overwrite = TRUE)
        
        # Find event files (typically .EVA, .EVN, or .EVE extensions)
        event_files <- list.files(
          temp_dir, 
          pattern = "\\.(EVA|EVN|EVE)$",
          full.names = TRUE,
          ignore.case = TRUE
        )
        
        if (length(event_files) == 0) {
          cli::cli_warn("No event files found in {yr} archive")
          return(tibble::tibble())
        }
        
        # Read and combine all event files
        all_events <- purrr::map_dfr(event_files, function(file) {
          lines <- readr::read_lines(file, lazy = FALSE)
          
          if (parse) {
            parse_event_file(lines, year = yr)
          } else {
            tibble::tibble(
              year = yr,
              content = lines
            )
          }
        })
        
        # Clean up extracted files (but keep cached zip)
        unlink(event_files)
        
        # Clean up temp zip if not using cache
        if (!use_cached || is.null(cache_path) || cache_path != zip_file) {
          unlink(zip_file)
        }
        
        all_events
        
      }, error = function(e) {
        cli::cli_warn("Failed to download {yr}: {e$message}")
        tibble::tibble()
      })
    }
  )
  
  # Add event type information
  all_data <- all_data |>
    dplyr::left_join(
      events |> dplyr::select(.data$year, .data$type),
      by = "year"
    )
  
  if (verbose) {
    cli::cli_alert_success(
      "Downloaded and parsed {scales::comma(nrow(all_data))} record{?s}"
    )
  }
  
  all_data
}

#' Parse Retrosheet Event File Lines
#' @keywords internal
#' @param lines Character vector of lines from event file
#' @param year Year of the data
parse_event_file <- function(lines, year) {
  
  # Split each line by comma
  parsed <- purrr::map_dfr(seq_along(lines), function(i) {
    line <- lines[i]
    
    if (nchar(line) == 0) {
      return(NULL)
    }
    
    # Split by comma, handling quoted fields
    parts <- stringr::str_split(line, ",", simplify = FALSE)[[1]]
    
    if (length(parts) == 0) {
      return(NULL)
    }
    
    record_type <- parts[1]
    
    # Create a row with the record type and remaining fields
    # Store as list-columns to handle varying field counts
    tibble::tibble(
      line_number = i,
      record_type = record_type,
      fields = list(parts[-1])
    )
  })
  
  parsed <- parsed |>
    dplyr::mutate(year = year)
  
  # Further parse based on record type
  parsed |>
    dplyr::mutate(
      game_id = extract_game_id(.data$record_type, .data$fields),
      .before = 1
    ) |>
    tidyr::fill(.data$game_id, .direction = "down")
}

#' Extract game ID from record
#' @keywords internal
extract_game_id <- function(record_type, fields) {
  ifelse(record_type == "id", 
         purrr::map_chr(fields, ~.x[1], .default = NA_character_),
         NA_character_)
}

