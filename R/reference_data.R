#' Get Retrosheet Park IDs
#'
#' Downloads and returns the official Retrosheet ballpark codes with current
#' stadium names.
#'
#' @return A tibble with columns:
#'   * `park_id` - Retrosheet ballpark code
#'   * `name` - Stadium name
#'   * `aka` - Alternate name(s), if any
#'   * `city` - City
#'   * `state` - State/Province
#'   * `start` - First date used (MM/DD/YYYY)
#'   * `end` - Last date used (MM/DD/YYYY); NA if still in use
#'   * `league` - League(s)
#'   * `notes` - Usage notes
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
  url <- glue::glue("{retrosheet_base_url()}/parkcode.txt")

  cli::cli_progress_step("Downloading park codes")

  tryCatch({
    resp <- httr2::request(url) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(15) |>
      httr2::req_perform()

    read_parkcode_file(httr2::resp_body_string(resp))

  }, error = function(e) {
    cli::cli_warn("Failed to download park codes: {e$message}")
    tibble::tibble()
  })
}

#' Parse the parkcode.txt reference file
#'
#' The file is comma-separated with a header row
#' (PARKID,NAME,AKA,CITY,STATE,START,END,LEAGUE,NOTES) and quoted fields that
#' can contain commas.
#'
#' @param content Full text of parkcode.txt
#' @noRd
read_parkcode_file <- function(content) {
  readr::read_csv(
    I(content),
    col_types = readr::cols(.default = "c"),
    show_col_types = FALSE
  ) |>
    dplyr::rename_with(tolower) |>
    dplyr::rename(park_id = "parkid")
}

#' Get Retrosheet Team IDs
#'
#' Returns the official Retrosheet team codes for a given year, extracted
#' from the TEAM file in that year's regular-season event archive (cached
#' like other event downloads).
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
  url <- construct_event_url(year, "regular")

  cli::cli_progress_step("Downloading team codes for {year}")

  tryCatch({
    zip_file <- retro_download(
      url,
      cache_filename = basename(url),
      timeout = 60,
      verbose = FALSE
    )
    if (!caching_enabled()) {
      on.exit(unlink(zip_file), add = TRUE)
    }

    extracted <- retro_extract(zip_file, pattern = "^TEAM")
    on.exit(unlink(extracted$dir, recursive = TRUE), add = TRUE)

    if (length(extracted$files) == 0) {
      cli::cli_warn("No team file found for {year}")
      return(tibble::tibble())
    }

    readr::read_csv(
      extracted$files[1],
      col_names = c("team_id", "league", "city", "name"),
      col_types = readr::cols(.default = "c"),
      show_col_types = FALSE
    )

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
#' @return A tibble with one row per person and columns including:
#'   * `player_id` - Retrosheet player ID
#'   * `last_name`, `first_name`, `nickname`
#'   * `birth_date`, `birth_city`, `birth_state`, `birth_country`
#'   * `play_debut`, `play_lastgame` - First/last game as a player
#'   * `mgr_debut`, `coach_debut`, `ump_debut` (and matching `*_lastgame`)
#'   * `death_date`, `death_city`, `death_state`, `death_country`
#'   * `bats`, `throws`, `height`, `weight`
#'   * `hof` - "HOF" for Hall of Fame members
#'   * Plus cemetery and name-change fields
#'
#' @details
#' This downloads a multi-megabyte file and may take a moment. The file is
#' not cached because Retrosheet updates it continuously.
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
  url <- glue::glue("{retrosheet_base_url()}/BIOFILE.TXT")

  cli::cli_progress_step("Downloading player database (this may take a moment)")

  tryCatch({
    temp_file <- tempfile(fileext = ".txt")
    on.exit(unlink(temp_file), add = TRUE)

    httr2::request(url) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_timeout(60) |>
      httr2::req_perform(path = temp_file)

    players <- read_biofile(temp_file)

    cli::cli_alert_success(
      "Downloaded {scales::comma(nrow(players))} player records"
    )

    players

  }, error = function(e) {
    cli::cli_warn("Failed to download player database: {e$message}")
    tibble::tibble()
  })
}

#' Parse the BIOFILE.TXT player database
#'
#' The file has a header row (PLAYERID,LAST,FIRST,NICKNAME,BIRTHDATE,
#' BIRTH CITY,...) with 33 fields; names are normalized to snake_case.
#'
#' @param path Path to a downloaded BIOFILE.TXT
#' @noRd
read_biofile <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = "c"),
    show_col_types = FALSE
  ) |>
    dplyr::rename_with(\(x) gsub(" ", "_", tolower(x))) |>
    dplyr::rename(
      player_id = "playerid",
      last_name = "last",
      first_name = "first",
      birth_date = "birthdate",
      death_date = "deathdate"
    )
}
