#' Download a Retrosheet file, using the cache when enabled
#'
#' Downloads to a temporary file first and only moves the result into the
#' cache on success, so an interrupted or failed download can never leave a
#' corrupt file behind at the cache path.
#'
#' @param url URL to download
#' @param cache_filename Basename under which to store the file in the cache
#' @param timeout Request timeout in seconds
#' @param verbose Logical. Print download/cache messages.
#' @return Path to the local file. When caching is disabled this is a
#'   tempfile the caller may unlink after use.
#' @noRd
retro_download <- function(url, cache_filename, timeout = 60, verbose = TRUE) {
  use_cache <- caching_enabled()
  cache_path <- file.path(cache_dir(), cache_filename)

  if (use_cache && file.exists(cache_path) && file.size(cache_path) > 0) {
    if (verbose) {
      cli::cli_alert_info("Using cached {.file {cache_filename}}")
    }
    return(cache_path)
  }

  if (verbose) {
    cli::cli_alert_info("Downloading {.url {url}}")
  }

  tmp <- tempfile(fileext = paste0(".", tools::file_ext(cache_filename)))
  httr2::request(url) |>
    httr2::req_retry(max_tries = 3, backoff = ~2) |>
    httr2::req_timeout(timeout) |>
    httr2::req_perform(path = tmp)

  if (!use_cache) {
    return(tmp)
  }

  # rename fails across filesystems; fall back to copy
  if (!suppressWarnings(file.rename(tmp, cache_path))) {
    file.copy(tmp, cache_path, overwrite = TRUE)
    unlink(tmp)
  }
  cache_path
}

#' Extract files matching a pattern from a zip archive
#'
#' Extracts into a fresh per-call directory so sequential or nested calls can
#' never pick up files left behind by an earlier extraction.
#'
#' @param zip_path Path to the zip archive
#' @param pattern Regular expression matched against extracted filenames
#'   (case-insensitive)
#' @return A list with `dir` (the extraction directory, which the caller
#'   should remove with `unlink(dir, recursive = TRUE)` when done) and
#'   `files` (full paths of the extracted files matching `pattern`)
#' @noRd
retro_extract <- function(zip_path, pattern) {
  exdir <- tempfile("retrosheetshow-")
  dir.create(exdir)
  utils::unzip(zip_path, exdir = exdir, overwrite = TRUE)

  list(
    dir = exdir,
    files = list.files(
      exdir,
      pattern = pattern,
      full.names = TRUE,
      ignore.case = TRUE
    )
  )
}
