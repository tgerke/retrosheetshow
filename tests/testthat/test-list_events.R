test_that("list_events returns year, type, and url columns", {
  result <- list_events(year = 2024, check_availability = FALSE)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("year", "type", "url"))
  expect_equal(result$year, 2024)
  expect_equal(result$type, "regular")
  expect_match(result$url, "2024eve\\.zip$")
})

test_that("list_events handles multiple years and types", {
  result <- list_events(
    year = 2022:2024,
    type = c("regular", "allstar", "post"),
    check_availability = FALSE
  )

  expect_equal(nrow(result), 9)
  expect_setequal(unique(result$year), 2022:2024)
  expect_setequal(unique(result$type), c("regular", "allstar", "post"))
})

test_that("list_events validates the type argument", {
  expect_error(
    list_events(year = 2024, type = "invalid"),
    "'arg' should be one of"
  )
})

test_that("list_events orders results by year descending", {
  result <- list_events(year = 2020:2024, check_availability = FALSE)
  expect_equal(result$year[1], 2024)
  expect_true(all(diff(result$year) <= 0))
})

test_that("list_events uses the full year range when year is NULL", {
  result <- list_events(year = NULL, type = "regular", check_availability = FALSE)
  expect_gt(nrow(result), 100) # regular season events go back to 1911
  expect_equal(min(result$year), 1911)
})
