test_that("cache_dir creates the directory on demand", {
  local_temp_cache()

  path <- cache_dir(create = FALSE)
  expect_false(dir.exists(path))

  path <- cache_dir(create = TRUE)
  expect_true(dir.exists(path))
})

test_that("use_cache toggles the session option", {
  withr::local_options(retrosheetshow.use_cache = TRUE)

  old <- suppressMessages(use_cache(FALSE))
  expect_true(old)
  expect_false(caching_enabled())

  suppressMessages(use_cache(TRUE))
  expect_true(caching_enabled())
})

test_that("cache_file_path covers every artifact type", {
  local_temp_cache()

  expect_equal(basename(cache_file_path(2024, "regular")), "2024eve.zip")
  expect_equal(basename(cache_file_path(2024, "allstar")), "2024as.zip")
  expect_equal(basename(cache_file_path(2024, "post")), "2024post.zip")
  expect_equal(basename(cache_file_path(2024, "gamelog")), "gl2024.zip")
  expect_equal(basename(cache_file_path(2024, "schedule")), "2024SKED.zip")
  expect_error(cache_file_path(2024, "boxscore"))
})

test_that("cache_status identifies all cached artifact types", {
  local_temp_cache()

  files <- c("2024eve.zip", "2023as.zip", "2022post.zip", "gl2024.zip", "2024SKED.zip")
  for (f in files) {
    writeLines("x", file.path(cache_dir(), f))
  }

  status <- suppressMessages(cache_status())

  expect_equal(nrow(status), 5)
  expect_setequal(
    status$type,
    c("regular", "allstar", "post", "gamelog", "schedule")
  )
  expect_equal(sort(unique(status$year)), c(2022, 2023, 2024))
})

test_that("clear_cache removes files by year and type", {
  local_temp_cache()

  files <- c("2024eve.zip", "2023eve.zip", "gl2024.zip", "2024SKED.zip")
  for (f in files) {
    writeLines("x", file.path(cache_dir(), f))
  }

  # by type
  n <- suppressMessages(clear_cache(type = "gamelog", confirm = FALSE))
  expect_equal(n, 1)
  expect_false(file.exists(file.path(cache_dir(), "gl2024.zip")))

  # by year and type
  n <- suppressMessages(clear_cache(year = 2024, type = "regular", confirm = FALSE))
  expect_equal(n, 1)
  expect_true(file.exists(file.path(cache_dir(), "2023eve.zip")))

  # everything
  n <- suppressMessages(clear_cache(confirm = FALSE))
  expect_equal(n, 2)
  expect_equal(suppressMessages(clear_cache(confirm = FALSE)), 0)
})

test_that("clear_cache with confirm requires an interactive session", {
  local_temp_cache()
  writeLines("x", file.path(cache_dir(), "2024eve.zip"))

  expect_error(clear_cache(confirm = TRUE), "confirm = FALSE")
  expect_true(file.exists(file.path(cache_dir(), "2024eve.zip")))
})
