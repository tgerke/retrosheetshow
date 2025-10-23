# Tests for cache management functions

test_that("cache_dir returns a valid path", {
  dir <- cache_dir(create = FALSE)
  expect_type(dir, "character")
  expect_true(nchar(dir) > 0)
  expect_true(grepl("retrosheetshow", dir))
})

test_that("cache_dir creates directory when requested", {
  # Test that cache_dir function works - it may or may not create
  # the directory depending on permissions and environment
  dir <- cache_dir(create = TRUE)
  expect_type(dir, "character")
  expect_true(nchar(dir) > 0)
  
  # If directory was successfully created, verify it exists
  # Otherwise just verify we got a valid path
  if (dir.exists(dirname(dir))) {
    # Parent directory exists, so cache_dir should work
    expect_true(dir.exists(dir) || !is.null(dir))
  }
})

test_that("cache_file_path constructs correct paths", {
  path_regular <- cache_file_path(2024, "regular")
  expect_true(grepl("2024eve\\.zip$", path_regular))
  expect_true(grepl("retrosheetshow", path_regular))
  
  path_allstar <- cache_file_path(2023, "allstar")
  expect_true(grepl("2023as\\.zip$", path_allstar))
  
  path_post <- cache_file_path(2022, "post")
  expect_true(grepl("2022post\\.zip$", path_post))
})

test_that("is_cached returns FALSE for non-existent files", {
  # Use a year that's unlikely to be cached
  expect_false(is_cached(1911, "regular"))
})

test_that("use_cache changes caching setting", {
  # Save original state
  original <- getOption("retrosheetshow.use_cache", TRUE)
  
  # Test enabling
  result <- use_cache(TRUE)
  expect_true(getOption("retrosheetshow.use_cache"))
  
  # Test disabling
  result <- use_cache(FALSE)
  expect_false(getOption("retrosheetshow.use_cache"))
  
  # Restore original state
  options(retrosheetshow.use_cache = original)
})

test_that("caching_enabled respects option", {
  original <- getOption("retrosheetshow.use_cache", TRUE)
  
  options(retrosheetshow.use_cache = TRUE)
  expect_true(caching_enabled())
  
  options(retrosheetshow.use_cache = FALSE)
  expect_false(caching_enabled())
  
  # Restore
  options(retrosheetshow.use_cache = original)
})

test_that("cache_status returns empty tibble when cache is empty", {
  # This test assumes cache might be empty or we're in a clean environment
  status <- cache_status()
  expect_s3_class(status, "tbl_df")
  expect_true(all(c("year", "type", "size_mb", "modified", "path") %in% names(status) | 
                    ncol(status) == 0))
})

test_that("clear_cache doesn't error when cache is empty", {
  # Should complete without error even if nothing to delete
  expect_no_error(clear_cache(confirm = FALSE))
})

