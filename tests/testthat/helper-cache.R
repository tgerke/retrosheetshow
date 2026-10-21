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

# Zip fixture files into the cache under the filename retro_download()
# expects for `type`. names(fixtures) are the file names inside the archive.
seed_cache_zip <- function(year, type, fixtures, env = parent.frame()) {
  skip_if(Sys.which("zip") == "", "zip binary not available")

  stage <- withr::local_tempdir(.local_envir = env)
  file.copy(test_path("fixtures", fixtures), file.path(stage, names(fixtures)))

  zip_path <- cache_file_path(year, type)
  withr::with_dir(
    stage,
    utils::zip(zip_path, files = names(fixtures), flags = "-q9X")
  )
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

# Build a zip laid out like GitHub's archive of the Chadwick register: the
# fixture rows under register-<commit SHA>/data/, split into people-*.csv
# files by the first character of key_person, as the register shards them.
# `drop` leaves out the rows with those key_person values, to stand in for
# another version of the register.
make_register_zip <- function(path, drop = character()) {
  skip_if(Sys.which("zip") == "", "zip binary not available")

  lines <- readLines(test_path("fixtures", "chadwick-people-excerpt.csv"))
  rows <- lines[-1]
  rows <- rows[!substr(rows, 1, 8) %in% drop]

  stage <- withr::local_tempdir()
  top <- paste0("register-abc1234", strrep("0", 33))
  data_dir <- file.path(stage, top, "data")
  dir.create(data_dir, recursive = TRUE)
  shard <- substr(rows, 1, 1)
  for (s in unique(shard)) {
    writeLines(
      c(lines[1], rows[shard == s]),
      file.path(data_dir, paste0("people-", s, ".csv")),
      useBytes = TRUE
    )
  }

  # zip adds to an existing archive rather than replacing it
  unlink(path)
  withr::with_dir(stage, utils::zip(path, files = top, flags = "-qr9X"))
  invisible(path)
}

# Place a register archive in the cache under the name get_chadwick_register()
# expects
seed_register_zip <- function(drop = character()) {
  make_register_zip(file.path(cache_dir(), "chadwick-register.zip"), drop)
}

# A file:// URL for a local file, which httr2 downloads through libcurl like
# any other URL. libcurl wants three slashes before a Windows drive letter
# too.
file_url <- function(path) {
  skip_if_not_installed("curl")
  skip_if_not(
    "file" %in% curl::curl_version()$protocols,
    "libcurl can't read file:// URLs"
  )
  paste0("file:///", sub("^/", "", normalizePath(path, winslash = "/")))
}
