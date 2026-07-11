test_that("retro_download serves a cached file without touching the network", {
  local_temp_cache()
  cached <- file.path(cache_dir(), "2024eve.zip")
  writeLines("cached content", cached)

  path <- suppressMessages(
    retro_download("https://127.0.0.1:9/2024eve.zip", "2024eve.zip")
  )

  expect_equal(path, cached)
  expect_equal(readLines(path)[1], "cached content")
})

test_that("retro_download ignores zero-byte cache files", {
  local_temp_cache()
  cached <- file.path(cache_dir(), "2024eve.zip")
  file.create(cached)

  # regression: an interrupted download used to leave an empty file that was
  # treated as a valid cache forever; now it re-downloads (and fails here
  # because the host is unreachable) instead of returning the empty file
  expect_error(
    suppressMessages(
      retro_download("https://127.0.0.1:9/2024eve.zip", "2024eve.zip")
    )
  )
  expect_equal(file.size(cached), 0)
})

test_that("retro_extract uses a fresh directory per call", {
  skip_if(Sys.which("zip") == "", "zip binary not available")

  stage <- withr::local_tempdir()
  writeLines("game data", file.path(stage, "2024AAA.EVE"))
  zip_path <- file.path(stage, "test.zip")
  withr::with_dir(stage, utils::zip(zip_path, "2024AAA.EVE", flags = "-q9X"))

  first <- retro_extract(zip_path, "\\.EVE$")
  withr::defer(unlink(first$dir, recursive = TRUE))
  second <- retro_extract(zip_path, "\\.EVE$")
  withr::defer(unlink(second$dir, recursive = TRUE))

  expect_length(first$files, 1)
  expect_false(identical(first$dir, second$dir))

  # a leftover file in one extraction dir can't leak into another
  none <- retro_extract(zip_path, "\\.ROS$")
  withr::defer(unlink(none$dir, recursive = TRUE))
  expect_length(none$files, 0)
})
