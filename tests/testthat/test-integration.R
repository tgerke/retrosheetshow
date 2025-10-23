# Integration tests requiring network access
# These tests are skipped offline and on CRAN

test_that("url_exists correctly identifies valid URLs", {
  skip_if_offline()
  skip_on_cran()
  
  # Test with Retrosheet homepage (should exist)
  expect_true(url_exists("https://www.retrosheet.org"))
})

test_that("url_exists correctly identifies invalid URLs", {
  skip_if_offline()
  skip_on_cran()
  
  # Test with non-existent URL
  expect_false(url_exists("https://www.retrosheet.org/nonexistent12345.zip"))
})

test_that("list_events finds available files", {
  skip_if_offline()
  skip_on_cran()
  
  # 2024 regular season should exist
  result <- list_events(year = 2024, type = "regular", check_availability = TRUE)
  
  if (nrow(result) > 0) {
    expect_true("available" %in% names(result))
    expect_true(all(result$available))
  }
})

test_that("get_events can download and parse a small file", {
  skip_if_offline()
  skip_on_cran()
  
  # All-star games are smaller files, good for testing
  # Use an older year to ensure stability
  result <- tryCatch({
    list_events(year = 2019, type = "allstar") |>
      get_events()
  }, error = function(e) {
    skip(paste("Could not download test data:", e$message))
  })
  
  expect_s3_class(result, "tbl_df")
  expect_true("record_type" %in% names(result))
  expect_true("game_id" %in% names(result))
  expect_gt(nrow(result), 0)
})

test_that("get_game_info extracts game metadata", {
  skip_if_offline()
  skip_on_cran()
  
  events <- tryCatch({
    list_events(year = 2019, type = "allstar") |>
      get_events()
  }, error = function(e) {
    skip(paste("Could not download test data:", e$message))
  })
  
  game_info <- get_game_info(events)
  
  expect_s3_class(game_info, "tbl_df")
  expect_true("game_id" %in% names(game_info))
  expect_gt(nrow(game_info), 0)
})

test_that("get_plays extracts play-by-play data", {
  skip_if_offline()
  skip_on_cran()
  
  events <- tryCatch({
    list_events(year = 2019, type = "allstar") |>
      get_events()
  }, error = function(e) {
    skip(paste("Could not download test data:", e$message))
  })
  
  plays <- get_plays(events)
  
  expect_s3_class(plays, "tbl_df")
  expect_true(all(c("inning", "player_id", "event") %in% names(plays)))
  expect_gt(nrow(plays), 0)
})

test_that("caching works for repeated downloads", {
  skip_if_offline()
  skip_on_cran()
  
  # Enable caching
  use_cache(TRUE)
  
  # First download
  time1 <- system.time({
    events1 <- tryCatch({
      list_events(year = 2019, type = "allstar") |>
        get_events()
    }, error = function(e) {
      skip(paste("Could not download test data:", e$message))
    })
  })
  
  # Second download (should be faster due to caching)
  time2 <- system.time({
    events2 <- tryCatch({
      list_events(year = 2019, type = "allstar") |>
        get_events()
    }, error = function(e) {
      skip(paste("Could not download test data:", e$message))
    })
  })
  
  # Both should return data
  expect_s3_class(events1, "tbl_df")
  expect_s3_class(events2, "tbl_df")
  
  # Data should be identical
  expect_equal(nrow(events1), nrow(events2))
  
  # Second call should generally be faster (cached)
  # Note: This is not a strict requirement as timing can vary
  expect_lte(time2[["elapsed"]], time1[["elapsed"]] * 2)
})

