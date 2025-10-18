#' Get Retrosheet Park IDs
#'
#' Downloads and returns the official Retrosheet ballpark codes with current
#' stadium names.
#'
#' @return A tibble with columns:
#'   * `park_id` - Retrosheet ballpark code
#'   * `name` - Stadium name
#'   * `city` - City
#'   * `state` - State/Province
#'   * `start` - First date used
#'   * `end` - Last date used
#'   * `league` - League(s)
#'
#' @examples
#' \dontrun{
#' # Get all park IDs
#' parks <- get_park_ids()
#'
#' # Find Fenway Park
#' parks |> filter(grepl("Fenway", name))
#' }
#'
#' @export
get_park_ids <- function() {
  url <- "https://www.retrosheet.org/parkcode.txt"
  
  cli::cli_progress_step("Downloading park codes")
  
  tryCatch({
    # Download with retry logic
    resp <- httr2::request(url) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(15) |>
      httr2::req_perform()
    
    # Parse the text
    content <- httr2::resp_body_string(resp)
    lines <- strsplit(content, "\n")[[1]]
    
    # Parse fixed-width format
    # Format: PARKID,NAME,CITY,STATE,START,END,LEAGUE
    parks <- purrr::map_dfr(lines, function(line) {
      if (nchar(line) < 10) return(NULL)
      parts <- strsplit(line, ",")[[1]]
      if (length(parts) < 5) return(NULL)
      
      tibble::tibble(
        park_id = parts[1],
        name = parts[2],
        city = if (length(parts) > 2) parts[3] else NA_character_,
        state = if (length(parts) > 3) parts[4] else NA_character_,
        start = if (length(parts) > 4) parts[5] else NA_character_,
        end = if (length(parts) > 5) parts[6] else NA_character_,
        league = if (length(parts) > 6) parts[7] else NA_character_
      )
    })
    
    parks
    
  }, error = function(e) {
    cli::cli_warn("Failed to download park codes: {e$message}")
    tibble::tibble()
  })
}

#' Get Retrosheet Team IDs
#'
#' Downloads and returns the official Retrosheet team codes for a given year.
#'
#' @param year Four-digit year
#'
#' @return A tibble with columns:
#'   * `team_id` - Three-letter team code
#'   * `league` - League (AL/NL)
#'   * `city` - City
#'   * `name` - Team name
#'
#' @examples
#' \dontrun{
#' # Get 2024 teams
#' teams <- get_team_ids(2024)
#'
#' # Get Yankees info
#' teams |> filter(team_id == "NYA")
#' }
#'
#' @export
get_team_ids <- function(year) {
  # Retrosheet stores team files in the event archives
  url <- construct_event_url(year, "regular")
  
  cli::cli_progress_step("Downloading team codes for {year}")
  
  tryCatch({
    # Download and extract
    temp_zip <- tempfile(fileext = ".zip")
    temp_dir <- tempdir()
    
    httr2::request(url) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(30) |>
      httr2::req_perform(path = temp_zip)
    
    unzip(temp_zip, exdir = temp_dir)
    
    # Find TEAM file
    team_file <- list.files(temp_dir, pattern = "^TEAM", 
                           full.names = TRUE, ignore.case = TRUE)
    
    if (length(team_file) == 0) {
      cli::cli_warn("No team file found for {year}")
      return(tibble::tibble())
    }
    
    # Read team file
    lines <- readr::read_lines(team_file[1])
    
    # Parse format: TEAMID,LEAGUE,CITY,NAME
    teams <- purrr::map_dfr(lines, function(line) {
      parts <- strsplit(line, ",")[[1]]
      if (length(parts) < 4) return(NULL)
      
      tibble::tibble(
        team_id = parts[1],
        league = parts[2],
        city = parts[3],
        name = parts[4]
      )
    })
    
    # Cleanup
    unlink(temp_zip)
    unlink(team_file)
    
    teams
    
  }, error = function(e) {
    cli::cli_warn("Failed to download team codes: {e$message}")
    tibble::tibble()
  })
}

#' Get Retrosheet Player IDs
#'
#' Downloads the Retrosheet biofile database containing player biographical
#' information and IDs.
#'
#' @return A tibble with player information including:
#'   * `player_id` - Retrosheet player ID
#'   * `last_name` - Last name
#'   * `first_name` - First name
#'   * `mlb_debut` - MLB debut date
#'   * And other biographical fields
#'
#' @details
#' This downloads a large file (~3 MB) and may take a moment. The result
#' should be cached for repeated use.
#'
#' @examples
#' \dontrun{
#' # Get all player IDs
#' players <- get_player_ids()
#'
#' # Find Aaron Judge
#' players |> filter(grepl("Judge", last_name))
#' }
#'
#' @export
get_player_ids <- function() {
  url <- "https://www.retrosheet.org/biofile.txt"
  
  cli::cli_progress_step("Downloading player database (this may take a moment)")
  
  tryCatch({
    # Download with retry
    temp_file <- tempfile()
    
    httr2::request(url) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(60) |>
      httr2::req_perform(path = temp_file)
    
    # Read the CSV file
    # Format is comma-delimited with many fields
    players <- readr::read_csv(
      temp_file,
      col_names = c(
        "player_id", "last_name", "first_name", "nickname",
        "bats", "throws", "birth_year", "birth_month", "birth_day",
        "birth_country", "birth_state", "birth_city",
        "death_year", "death_month", "death_day",
        "death_country", "death_state", "death_city",
        "height", "weight", "debut_date", "manager_debut", 
        "coach_debut", "umpire_debut"
      ),
      show_col_types = FALSE
    )
    
    unlink(temp_file)
    
    cli::cli_alert_success("Downloaded {scales::comma(nrow(players))} player records")
    
    players
    
  }, error = function(e) {
    cli::cli_warn("Failed to download player database: {e$message}")
    tibble::tibble()
  })
}

