# Tests for utility functions

test_that("retrosheet_base_url returns correct URL", {
  expect_equal(retrosheet_base_url(), "https://www.retrosheet.org")
})

test_that("construct_event_url builds correct URLs", {
  # Regular season
  expect_equal(
    construct_event_url(2024, "regular"),
    "https://www.retrosheet.org/events/2024eve.zip"
  )
  
  # All-star
  expect_equal(
    construct_event_url(2023, "allstar"),
    "https://www.retrosheet.org/events/2023as.zip"
  )
  
  # Post-season
  expect_equal(
    construct_event_url(2022, "post"),
    "https://www.retrosheet.org/events/2022post.zip"
  )
})

test_that("construct_event_url validates type argument", {
  expect_error(
    construct_event_url(2024, "invalid"),
    "'arg' should be one of"
  )
})

test_that("get_available_years returns expected ranges", {
  regular_years <- get_available_years("regular")
  expect_true(is.numeric(regular_years))
  expect_true(1911 %in% regular_years)
  expect_true(2024 %in% regular_years)
  expect_true(all(regular_years >= 1911 & regular_years <= 2024))
  
  allstar_years <- get_available_years("allstar")
  expect_true(1933 %in% allstar_years)
  expect_false(1945 %in% allstar_years)  # No all-star game in 1945
  
  post_years <- get_available_years("post")
  expect_true(1903 %in% post_years)
  expect_false(1904 %in% post_years)  # Gap in post-season data
})

test_that("get_available_years validates type argument", {
  expect_error(
    get_available_years("invalid"),
    "'arg' should be one of"
  )
})

