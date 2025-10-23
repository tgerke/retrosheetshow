# Tests for gamelog functions

test_that("gamelog_fields returns a tibble", {
  result <- gamelog_fields()
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("field_name", "description") %in% names(result)))
  expect_gt(nrow(result), 100)  # Should have ~170 fields
})

test_that("gamelog_fields can filter by search term", {
  skip_if_not_installed("dplyr")
  
  result <- gamelog_fields()
  
  # Search for pitcher-related fields
  pitcher_fields <- result[grepl("pitcher", result$description, ignore.case = TRUE), ]
  expect_gt(nrow(pitcher_fields), 0)
  
  # Search for attendance
  attendance_fields <- result[grepl("attendance", result$description, ignore.case = TRUE), ]
  expect_gt(nrow(attendance_fields), 0)
})

test_that("list_gamelogs returns expected structure", {
  result <- list_gamelogs(year = 2024, check_availability = FALSE)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("year", "url") %in% names(result)))
  expect_equal(result$year, 2024)
})

test_that("list_gamelogs handles multiple years", {
  result <- list_gamelogs(year = 2022:2024, check_availability = FALSE)
  expect_gte(nrow(result), 3)
  expect_true(all(2022:2024 %in% result$year))
})

test_that("list_gamelogs constructs correct URLs", {
  result <- list_gamelogs(year = 2024, check_availability = FALSE)
  expect_true(grepl("gl2024\\.zip$", result$url, ignore.case = TRUE))
  expect_true(grepl("retrosheet\\.org", result$url))
})

test_that("get_gamelogs downloads and parses data", {
  skip_if_offline()
  skip_on_cran()
  
  result <- tryCatch({
    get_gamelogs(year = 2019)  # Use older year for stability
  }, error = function(e) {
    skip(paste("Could not download gamelog data:", e$message))
  })
  
  expect_s3_class(result, "tbl_df")
  expect_gt(ncol(result), 100)  # Should have many columns
  expect_gt(nrow(result), 1000)  # Should have thousands of games
  
  # Check for expected columns
  expected_cols <- c("date", "visiting_team", "home_team", 
                     "visiting_score", "home_score")
  expect_true(all(expected_cols %in% names(result)))
})

