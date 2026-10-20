#' Get the Chadwick Register of Player IDs
#'
#' Downloads the Chadwick Baseball Bureau's register of people in baseball
#' and returns a lookup table from Retrosheet player IDs to the IDs used by
#' MLB Advanced Media (Statcast and the MLB Stats API), Baseball-Reference,
#' and FanGraphs.
#'
#' @param retro_only Logical. If TRUE (default), returns only people with a
#'   Retrosheet ID. If FALSE, returns everyone in the register, most of whom
#'   (minor leaguers, college players, and others) don't have one.
#' @param refresh Logical. If TRUE, downloads the current register even when
#'   a copy is cached. The cached copy is replaced only once the new download
#'   succeeds.
#' @param verbose Logical. If TRUE (default), displays progress messages.
#'
#' @return A tibble with one row per person, sorted by `key_retro`:
#'   * `key_retro` - Retrosheet player ID
#'   * `key_mlbam` - MLB Advanced Media ID (integer), as in the `batter` and
#'     `pitcher` columns of Statcast data
#'   * `key_bbref` - Baseball-Reference ID for major league pages
#'   * `key_fangraphs` - FanGraphs ID (integer)
#'   * `key_uuid` - Chadwick's permanent ID for the person
#'   * `key_person` - Chadwick's short ID, the first eight characters of
#'     `key_uuid`
#'   * `name_first`, `name_last` - First and last name
#'   * `mlb_played_first`, `mlb_played_last` - First and last seasons played
#'     in the major leagues (integer)
#'
#'   IDs and names the register doesn't have are `NA`.
#'
#' @details
#' ## Joining to other data
#'
#' Join on `key_retro`, `key_mlbam`, or `key_uuid`. Chadwick never reuses a
#' `key_uuid` for a different person. `key_person` is unique within any one
#' version of the register, but a later version can give it to someone else,
#' so it is not a safe key for data you keep.
#'
#' Not everyone with a Retrosheet ID has an MLBAM ID; most of those without
#' one are umpires.
#'
#' ## Caching and updates
#'
#' The register is downloaded from GitHub as one zip archive (about 28 MB)
#' and cached like the Retrosheet files: [cache_status()] lists it, and
#' `clear_cache(type = "register")` removes it. Chadwick updates the public
#' register periodically, so the cached copy ages; `refresh = TRUE` replaces
#' it with the current version. The message after each call names the
#' register commit the copy came from and the date it was downloaded.
#'
#' ## License
#'
#' Contains information from the
#' [Chadwick Baseball Bureau Register](https://github.com/chadwickbureau/register),
#' which is made available under the
#' [ODC Attribution License](http://opendatacommons.org/licenses/by/1.0/).
#' If you publish work that uses it, the license asks you to include a notice
#' like this one.
#'
#' @seealso [get_player_ids()] for Retrosheet's own biographical file.
#'
#' @examples
#' \dontrun{
#' ids <- get_chadwick_register()
#'
#' # MLBAM IDs for the pitchers in tracked game states, for joining to
#' # Statcast data
#' events <- get_events(year = 2024, type = "post")
#' track_game_state(events) |>
#'   dplyr::distinct(pitcher_id) |>
#'   dplyr::left_join(ids, by = c(pitcher_id = "key_retro"))
#'
#' # Replace the cached copy with the current register
#' ids <- get_chadwick_register(refresh = TRUE)
#'
#' # Everyone in the register, with or without a Retrosheet ID
#' everyone <- get_chadwick_register(retro_only = FALSE)
#' }
#'
#' @export
get_chadwick_register <- function(retro_only = TRUE,
                                  refresh = FALSE,
                                  verbose = TRUE) {

  tryCatch({
    zip_file <- retro_download(
      chadwick_register_url(),
      cache_filename = "chadwick-register.zip",
      timeout = 300,
      verbose = verbose,
      force = refresh
    )
    if (!caching_enabled()) {
      on.exit(unlink(zip_file), add = TRUE)
    }

    extracted <- retro_extract(
      zip_file,
      pattern = "^people-[0-9a-f]\\.csv$",
      recursive = TRUE
    )
    on.exit(unlink(extracted$dir, recursive = TRUE), add = TRUE)

    if (length(extracted$files) == 0) {
      cli::cli_warn("No people files found in the Chadwick register archive")
      return(tibble::tibble())
    }

    register <- read_chadwick_people(extracted$files)
    if (retro_only) {
      register <- dplyr::filter(register, !is.na(.data$key_retro))
    }

    if (verbose) {
      # GitHub names the archive's top directory after the commit it holds
      commit <- stringr::str_match(
        basename(dirname(dirname(extracted$files[1]))),
        "^register-([0-9a-f]{7})[0-9a-f]{33}$"
      )[, 2]
      version <- paste0(
        if (!is.na(commit)) paste0("commit ", commit, ", "),
        "downloaded ", format(file.mtime(zip_file), "%Y-%m-%d")
      )
      n <- nrow(register)
      cli::cli_alert_success(
        "Read {format(n, big.mark = ',')} {cli::qty(n)}{?person/people} from the Chadwick register ({version})"
      )
    }

    register

  }, error = function(e) {
    cli::cli_warn("Failed to get the Chadwick register: {e$message}")
    tibble::tibble()
  })
}

#' URL of the Chadwick register on GitHub
#'
#' A zip archive of the repository at its current commit. HEAD follows the
#' default branch whatever its name.
#' @noRd
chadwick_register_url <- function() {
  "https://github.com/chadwickbureau/register/archive/HEAD.zip"
}

#' Read the register's people files
#'
#' The register marks missing values with empty fields, so only those are
#' read as NA.
#'
#' @param files Paths to people-*.csv files from the register
#' @noRd
read_chadwick_people <- function(files) {
  readr::read_csv(
    files,
    col_select = c(
      "key_retro", "key_mlbam", "key_bbref", "key_fangraphs",
      "key_uuid", "key_person", "name_first", "name_last",
      "mlb_played_first", "mlb_played_last"
    ),
    col_types = readr::cols(
      .default = readr::col_character(),
      key_mlbam = readr::col_integer(),
      key_fangraphs = readr::col_integer(),
      mlb_played_first = readr::col_integer(),
      mlb_played_last = readr::col_integer()
    ),
    na = "",
    progress = FALSE
  ) |>
    dplyr::arrange(.data$key_retro, .data$key_person)
}
