test_that("construct_event_url builds the right URLs", {
  expect_equal(
    as.character(construct_event_url(2024, "regular")),
    "https://www.retrosheet.org/events/2024eve.zip"
  )
  expect_equal(
    as.character(construct_event_url(2024, "allstar")),
    "https://www.retrosheet.org/events/2024as.zip"
  )
  expect_equal(
    as.character(construct_event_url(2024, "post")),
    "https://www.retrosheet.org/events/2024post.zip"
  )
  expect_error(construct_event_url(2024, "gamelog"))
})

test_that("get_available_years reflects seasons without games", {
  allstar <- get_available_years("allstar")
  expect_false(1945 %in% allstar) # no All-Star game (WWII)
  expect_false(2020 %in% allstar) # no All-Star game (COVID)

  post <- get_available_years("post")
  expect_false(1904 %in% post) # no World Series
  expect_false(1994 %in% post) # strike

  regular <- get_available_years("regular")
  expect_equal(min(regular), 1911)
  expect_gte(max(regular), 2025)
})

test_that("url_exists returns FALSE for unreachable URLs", {
  expect_false(url_exists("https://127.0.0.1:9/nope.zip"))
})
