# Tests for list_events function

test_that("list_events returns a tibble", {
  skip_if_offline()
  
  result <- list_events(year = 2024, check_availability = FALSE)
  expect_s3_class(result, "tbl_df")
})

test_that("list_events has expected columns", {
  result <- list_events(year = 2024, check_availability = FALSE)
  expect_true(all(c("year", "type", "url") %in% names(result)))
})

test_that("list_events constructs URLs correctly", {
  result <- list_events(year = 2024, type = "regular", check_availability = FALSE)
  expect_equal(nrow(result), 1)
  expect_equal(result$year, 2024)
  expect_equal(result$type, "regular")
  expect_true(grepl("2024eve\\.zip$", result$url))
})

test_that("list_events handles multiple years", {
  result <- list_events(year = 2022:2024, check_availability = FALSE)
  expect_gte(nrow(result), 3)
  expect_true(all(2022:2024 %in% result$year))
})

test_that("list_events handles multiple types", {
  result <- list_events(
    year = 2024, 
    type = c("regular", "allstar", "post"),
    check_availability = FALSE
  )
  expect_gte(nrow(result), 3)
  expect_true(all(c("regular", "allstar", "post") %in% result$type))
})

test_that("list_events validates type argument", {
  expect_error(
    list_events(year = 2024, type = "invalid"),
    "'arg' should be one of"
  )
})

test_that("list_events orders results by year descending", {
  result <- list_events(year = 2020:2024, check_availability = FALSE)
  expect_equal(result$year[1], 2024)
  expect_true(all(diff(result$year) <= 0))  # Non-increasing
})

test_that("list_events uses default years when year is NULL", {
  # This will use all available years, so should have many rows
  result <- list_events(year = NULL, type = "regular", check_availability = FALSE)
  expect_gt(nrow(result), 50)  # Should have many years of regular season
})

test_that("list_events with check_availability adds available column", {
  skip_if_offline()
  skip_on_cran()  # Skip on CRAN to avoid network dependency
  
  result <- list_events(year = 2024, check_availability = TRUE)
  expect_true("available" %in% names(result))
  expect_type(result$available, "logical")
})

test_that("list_events without check_availability excludes available column", {
  result <- list_events(year = 2024, check_availability = FALSE)
  expect_false("available" %in% names(result))
})

