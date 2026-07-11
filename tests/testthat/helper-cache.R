# Point the package cache at a throwaway directory for the calling test.
# tools::R_user_dir() respects R_USER_CACHE_DIR.
local_temp_cache <- function(env = parent.frame()) {
  cache_root <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(R_USER_CACHE_DIR = cache_root, .local_envir = env)
  invisible(cache_root)
}

# Build a zip archive containing the fixture event file (plus optionally the
# fixture roster and TEAM files) and place it in the cache under the filename
# retro_download() expects, so get_events()/get_rosters() run without network.
seed_event_zip <- function(year,
                           type = "regular",
                           include_rosters = FALSE,
                           env = parent.frame()) {
  skip_if(Sys.which("zip") == "", "zip binary not available")

  stage <- withr::local_tempdir(.local_envir = env)
  files <- paste0(year, "ALCS.EVE")
  file.copy(
    test_path("fixtures", "2024ALCS-excerpt.EVE"),
    file.path(stage, files)
  )

  if (include_rosters) {
    file.copy(
      test_path("fixtures", "NYA2024.ROS"),
      file.path(stage, paste0("NYA", year, ".ROS"))
    )
    file.copy(
      test_path("fixtures", "TEAM2024"),
      file.path(stage, paste0("TEAM", year))
    )
    files <- c(files, paste0("NYA", year, ".ROS"), paste0("TEAM", year))
  }

  zip_path <- cache_file_path(year, type)
  withr::with_dir(stage, utils::zip(zip_path, files = files, flags = "-q9X"))
  invisible(zip_path)
}

# A tibble in the shape list_events() returns, pointing at an unreachable
# host: downloads must be served from the seeded cache
fake_events_tibble <- function(year, type) {
  filename <- purrr::map2_chr(
    year, type,
    \(y, t) basename(cache_file_path(y, t))
  )
  tibble::tibble(
    year = year,
    type = type,
    url = paste0("https://127.0.0.1:9/", filename)
  )
}
