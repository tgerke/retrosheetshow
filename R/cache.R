#' Get Retrosheet Cache Directory
#'
#' Returns the path to the retrosheetshow cache directory where downloaded
#' files are stored.
#'
#' @param create Logical. If TRUE (default), creates the directory if it
#'   doesn't exist.
#'
#' @return Character string with the cache directory path
#'
#' @details
#' The cache directory is determined by `tools::R_user_dir("retrosheetshow", "cache")`.
#' On most systems this will be:
#' - macOS: `~/Library/Caches/org.R-project.R/R/retrosheetshow`
#' - Linux: `~/.cache/R/retrosheetshow`
#' - Windows: `C:/Users/<user>/AppData/Local/R/cache/R/retrosheetshow`
#'
#' @examples
#' \dontrun{
#' # Get cache directory
#' cache_dir()
#'
#' # List cached files
#' list.files(cache_dir())
#' }
#'
#' @export
cache_dir <- function(create = TRUE) {
  dir <- tools::R_user_dir("retrosheetshow", "cache")
  
  if (create && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  dir
}

#' Get Cache File Path
#' @keywords internal
cache_file_path <- function(year, type = "regular") {
  type <- match.arg(type, c("regular", "allstar", "post"))
  
  filename <- switch(type,
    regular = glue::glue("{year}eve.zip"),
    allstar = glue::glue("{year}as.zip"),
    post = glue::glue("{year}post.zip")
  )
  
  file.path(cache_dir(), filename)
}

#' Check if File is in Cache
#' @keywords internal
is_cached <- function(year, type = "regular") {
  cache_path <- cache_file_path(year, type)
  file.exists(cache_path)
}

#' Clear Retrosheet Cache
#'
#' Removes cached Retrosheet files to free up disk space or force fresh downloads.
#'
#' @param year Optional. Numeric vector of specific years to remove from cache.
#'   If NULL (default), removes all cached files.
#' @param type Optional. Character vector of types to remove ("regular", "allstar", "post").
#'   If NULL (default), removes all types.
#' @param confirm Logical. If TRUE (default), asks for confirmation before deleting.
#'
#' @return Invisibly returns the number of files deleted
#'
#' @examples
#' \dontrun{
#' # Clear all cache
#' clear_cache()
#'
#' # Clear specific year
#' clear_cache(year = 2024)
#'
#' # Clear multiple years without confirmation
#' clear_cache(year = 2020:2023, confirm = FALSE)
#'
#' # Clear only postseason cache
#' clear_cache(type = "post")
#' }
#'
#' @export
clear_cache <- function(year = NULL, type = NULL, confirm = TRUE) {
  
  cache_path <- cache_dir(create = FALSE)
  
  if (!dir.exists(cache_path)) {
    cli::cli_inform("Cache directory does not exist")
    return(invisible(0))
  }
  
  # Get all cached files
  cached_files <- list.files(cache_path, pattern = "\\.zip$", full.names = TRUE)
  
  if (length(cached_files) == 0) {
    cli::cli_inform("Cache is already empty")
    return(invisible(0))
  }
  
  # Filter by year and type if specified
  if (!is.null(year) || !is.null(type)) {
    types <- if (is.null(type)) c("regular", "allstar", "post") else type
    years <- if (is.null(year)) NULL else year
    
    files_to_delete <- character()
    for (t in types) {
      if (is.null(years)) {
        # All years for this type
        pattern <- switch(t,
          regular = "eve\\.zip$",
          allstar = "as\\.zip$",
          post = "post\\.zip$"
        )
        files_to_delete <- c(files_to_delete, 
                            cached_files[grepl(pattern, cached_files)])
      } else {
        # Specific years for this type
        for (y in years) {
          file_path <- cache_file_path(y, t)
          if (file.exists(file_path)) {
            files_to_delete <- c(files_to_delete, file_path)
          }
        }
      }
    }
  } else {
    files_to_delete <- cached_files
  }
  
  if (length(files_to_delete) == 0) {
    cli::cli_inform("No matching files found in cache")
    return(invisible(0))
  }
  
  # Calculate size
  total_size <- sum(file.size(files_to_delete))
  size_mb <- round(total_size / 1024^2, 1)
  
  # Confirm deletion
  if (confirm) {
    response <- readline(
      glue::glue("Delete {length(files_to_delete)} file(s) ({size_mb} MB)? (y/N): ")
    )
    if (!tolower(response) %in% c("y", "yes")) {
      cli::cli_inform("Cancelled")
      return(invisible(0))
    }
  }
  
  # Delete files
  deleted <- file.remove(files_to_delete)
  n_deleted <- sum(deleted)
  
  if (n_deleted > 0) {
    cli::cli_alert_success(
      "Deleted {n_deleted} file{?s} ({size_mb} MB)"
    )
  }
  
  invisible(n_deleted)
}

#' Show Cache Status
#'
#' Displays information about the retrosheetshow cache, including size and
#' contents.
#'
#' @return A tibble with information about cached files
#'
#' @examples
#' \dontrun{
#' # View cache status
#' cache_status()
#' }
#'
#' @export
cache_status <- function() {
  cache_path <- cache_dir(create = FALSE)
  
  if (!dir.exists(cache_path)) {
    cli::cli_inform("Cache directory does not exist")
    return(tibble::tibble())
  }
  
  cached_files <- list.files(cache_path, pattern = "\\.zip$", full.names = TRUE)
  
  if (length(cached_files) == 0) {
    cli::cli_inform("Cache is empty")
    cli::cli_inform("Location: {.path {cache_path}}")
    return(tibble::tibble())
  }
  
  # Parse filenames to get year and type
  info <- purrr::map_dfr(cached_files, function(file) {
    basename <- basename(file)
    
    # Determine type
    type <- dplyr::case_when(
      grepl("eve\\.zip$", basename) ~ "regular",
      grepl("as\\.zip$", basename) ~ "allstar",
      grepl("post\\.zip$", basename) ~ "post",
      TRUE ~ "unknown"
    )
    
    # Extract year
    year <- as.integer(stringr::str_extract(basename, "^\\d{4}"))
    
    tibble::tibble(
      year = year,
      type = type,
      size_mb = round(file.size(file) / 1024^2, 2),
      modified = file.mtime(file),
      path = file
    )
  })
  
  # Summary
  total_size <- sum(info$size_mb)
  cli::cli_alert_info("Cache location: {.path {cache_path}}")
  cli::cli_alert_info("Total: {nrow(info)} file{?s}, {round(total_size, 1)} MB")
  
  info |>
    dplyr::arrange(dplyr::desc(.data$year), .data$type)
}

#' Enable or Disable Caching
#'
#' Sets the caching behavior for retrosheetshow downloads.
#'
#' @param enabled Logical. TRUE to enable caching, FALSE to disable.
#'
#' @return The previous caching setting (invisibly)
#'
#' @details
#' When caching is disabled, files are always downloaded fresh and not stored
#' in the cache directory. This can be useful for testing or when you need
#' the absolute latest data.
#'
#' The setting is stored as an environment variable `RETROSHEETSHOW_CACHE`
#' for the current R session only.
#'
#' @examples
#' \dontrun{
#' # Disable caching for this session
#' use_cache(FALSE)
#'
#' # Re-enable caching
#' use_cache(TRUE)
#' }
#'
#' @export
use_cache <- function(enabled = TRUE) {
  old_value <- getOption("retrosheetshow.use_cache", TRUE)
  options(retrosheetshow.use_cache = enabled)
  
  if (enabled) {
    cli::cli_alert_success("Caching enabled")
  } else {
    cli::cli_alert_info("Caching disabled for this session")
  }
  
  invisible(old_value)
}

#' Check if Caching is Enabled
#' @keywords internal
caching_enabled <- function() {
  getOption("retrosheetshow.use_cache", TRUE)
}

