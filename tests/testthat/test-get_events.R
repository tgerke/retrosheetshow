test_that("get_events validates its inputs", {
  expect_error(get_events(), "events.*tibble or.*year")
  expect_error(
    get_events(events = tibble::tibble(year = 2024)),
    "must have columns"
  )
  expect_warning(
    out <- get_events(events = fake_events_tibble(integer(), character())),
    "No events to download"
  )
  expect_equal(nrow(out), 0)
})

test_that("get_events reads from the cache without network", {
  local_temp_cache()
  seed_event_zip(2024, "post")

  out <- suppressMessages(
    get_events(events = fake_events_tibble(2024, "post"), verbose = FALSE)
  )

  expect_equal(nrow(out), 106)
  expect_true(all(out$type == "post"))
  expect_true(all(out$year == 2024))
})

test_that("same year with two types is not duplicated by the type join", {
  local_temp_cache()
  seed_event_zip(2024, "regular")
  seed_event_zip(2024, "post")

  single <- suppressMessages(
    get_events(events = fake_events_tibble(2024, "post"), verbose = FALSE)
  )
  both <- suppressMessages(
    get_events(
      events = fake_events_tibble(c(2024, 2024), c("regular", "post")),
      verbose = FALSE
    )
  )

  # regression: a year-only join used to cross records with every type
  expect_equal(nrow(both), 2 * nrow(single))
  expect_equal(sum(both$type == "post"), nrow(single))
  expect_false(any(duplicated(both[c("type", "line_number", "game_id")])))
})

test_that("sequential years do not contaminate each other's extraction", {
  local_temp_cache()
  seed_event_zip(2023, "regular")
  seed_event_zip(2024, "regular")

  first <- suppressMessages(
    get_events(events = fake_events_tibble(2023, "regular"), verbose = FALSE)
  )
  # regression: extraction into a shared tempdir used to sweep up the
  # leftover 2023 files here
  second <- suppressMessages(
    get_events(events = fake_events_tibble(2024, "regular"), verbose = FALSE)
  )

  expect_equal(nrow(first), 106)
  expect_equal(nrow(second), 106)
  expect_true(all(second$year == 2024))
})

test_that("parse = FALSE returns raw lines", {
  local_temp_cache()
  seed_event_zip(2024, "post")

  out <- suppressMessages(
    get_events(
      events = fake_events_tibble(2024, "post"),
      parse = FALSE,
      verbose = FALSE
    )
  )

  expect_named(out, c("year", "content", "type"))
  expect_equal(nrow(out), 106)
  expect_equal(out$content[1], "id,NYA202410140")
})

test_that("a failed download warns and returns remaining data", {
  local_temp_cache()
  seed_event_zip(2024, "post")

  events <- fake_events_tibble(c(2019, 2024), c("post", "post"))
  expect_warning(
    out <- suppressMessages(get_events(events = events, verbose = FALSE)),
    "Failed to download"
  )
  expect_equal(nrow(out), 106)
  expect_true(all(out$year == 2024))
})

test_that("a curly quote in an event file doesn't empty the season", {
  local_temp_cache()
  seed_cache_zip(1976, "regular", c("1976BAL.EVA" = "1976BAL-excerpt.EVA"))

  # regression: 1976 came back with no records and a warning blaming the
  # download
  expect_no_warning(
    out <- suppressMessages(
      get_events(events = fake_events_tibble(1976, "regular"), verbose = FALSE)
    )
  )
  expect_equal(nrow(out), 170)
})

test_that("a parse failure warns naming the file, not the download", {
  local_temp_cache()
  seed_event_zip(2024, "post")
  local_mocked_bindings(
    parse_event_file = function(file, year) stop("line 12 is malformed")
  )

  expect_warning(
    out <- suppressMessages(
      get_events(events = fake_events_tibble(2024, "post"), verbose = FALSE)
    ),
    "Failed to parse 2024ALCS.EVE in 2024 post events: line 12 is malformed",
    fixed = TRUE
  )
  # as with a failed download, nothing from that year and type comes back
  expect_equal(nrow(out), 0)
})

test_that("get_events pluralizes the record count in its summary", {
  local_temp_cache()
  seed_event_zip(2024, "post")

  # expect_message() lets the unmatched progress messages bubble up
  suppressMessages(
    expect_message(
      get_events(events = fake_events_tibble(2024, "post")),
      "Downloaded and parsed 106 records"
    )
  )
})
