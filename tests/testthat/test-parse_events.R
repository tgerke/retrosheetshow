fixture_events <- function() {
  parse_event_file(test_path("fixtures", "2024ALCS-excerpt.EVE"), year = 2024)
}

test_that("parse_event_file reads every record with game ids filled down", {
  raw <- fixture_events()

  expect_s3_class(raw, "tbl_df")
  expect_equal(nrow(raw), 106)
  expect_named(
    raw,
    c("game_id", "record_type", paste0("f", 1:6), "line_number", "year"),
    ignore.order = TRUE
  )

  # two games, id filled down to every record with no gaps
  expect_equal(
    unique(raw$game_id),
    c("NYA202410140", "NYA202410150")
  )
  expect_false(anyNA(raw$game_id))

  # records after the second id record belong to the second game
  second_id <- which(raw$record_type == "id")[2]
  expect_true(all(raw$game_id[second_id:nrow(raw)] == "NYA202410150"))
})

test_that("parse_event_file handles quoted and empty fields", {
  raw <- fixture_events()

  # quoted commas inside com records survive as a single field
  com <- raw[raw$record_type == "com", ]
  expect_match(
    com$f1[1],
    "challenged \\(tag play\\), call on the field was upheld"
  )

  # quoted player names are unquoted
  starts <- raw[raw$record_type == "start", ]
  expect_true("Alex Verdugo" %in% starts$f2)

  # fields a record doesn't have are NA (info records have 2 fields)
  info <- raw[raw$record_type == "info", ]
  expect_true(all(is.na(info$f3)))

  # empty trailing field is NA, not "" (one tiebreaker record per game)
  tiebreaker <- info[info$f1 == "tiebreaker", ]
  expect_identical(tiebreaker$f2, c(NA_character_, NA_character_))
})

test_that("parse_event_records types play records", {
  plays <- parse_event_records(fixture_events(), record_types = "play")

  expect_equal(nrow(plays), 3)
  expect_type(plays$inning, "integer")
  expect_type(plays$team, "integer")
  expect_equal(
    plays[1, c("inning", "team", "player_id", "count", "pitches", "event")],
    tibble::tibble(
      inning = 1L, team = 0L, player_id = "kwans001",
      count = "32", pitches = "BFFFBFFBX", event = "7/F7S"
    )
  )

  # a play with no pitch sequence keeps NA there but parses the event
  np <- plays[plays$event == "NP", ]
  expect_identical(np$pitches, NA_character_)
  expect_equal(np$count, "00")
})

test_that("parse_event_records types start, sub, and data records", {
  raw <- fixture_events()

  starts <- parse_event_records(raw, record_types = "start")
  expect_equal(nrow(starts), 32)
  expect_type(starts$batting_order, "integer")
  expect_type(starts$position, "integer")
  verdugo <- starts[starts$player_id == "verda001", ][1, ]
  expect_equal(verdugo$player_name, "Alex Verdugo")
  expect_equal(verdugo$team, 1L)
  expect_equal(verdugo$batting_order, 9L)

  dat <- parse_event_records(raw, record_types = "data")
  expect_equal(dat$data_type, rep("er", 2))
  expect_type(dat$earned_runs, "integer")
  expect_equal(dat$earned_runs[dat$player_id == "cobba001"], 3L)
})

test_that("parse_event_records combines all types and preserves row order", {
  raw <- fixture_events()
  parsed <- parse_event_records(raw)

  expect_equal(nrow(parsed), nrow(raw))
  expect_equal(parsed$record_type, raw$record_type)
  expect_false(any(grepl("^f\\d+$", names(parsed))))

  # columns from different record types coexist, NA where not applicable
  expect_true(all(c("inning", "info_type", "comment", "earned_runs") %in% names(parsed)))
  expect_true(all(is.na(parsed$inning[parsed$record_type == "info"])))

  # com fields keep their embedded comma
  expect_match(
    parsed$comment[parsed$record_type == "com"][1],
    "\\(tag play\\),"
  )
})

test_that("get_game_info returns one row per game", {
  raw <- fixture_events()
  raw$type <- "post"

  info <- get_game_info(raw)

  expect_equal(nrow(info), 2)
  expect_equal(info$visteam, c("CLE", "CLE"))
  expect_equal(info$hometeam, c("NYA", "NYA"))
  expect_equal(info$site[1], "NYC21")
  expect_identical(info$tiebreaker[1], NA_character_)
})

test_that("get_game_info collapses duplicated info types", {
  raw <- tibble::tibble(
    game_id = "TST202401010",
    record_type = "info",
    f1 = c("visteam", "oscorer", "oscorer"),
    f2 = c("BOS", "scorer1", "scorer2"),
    f3 = NA_character_, f4 = NA_character_,
    f5 = NA_character_, f6 = NA_character_,
    line_number = 1:3,
    year = 2024,
    type = "regular"
  )

  info <- get_game_info(raw)
  expect_equal(nrow(info), 1)
  expect_equal(info$oscorer, "scorer1; scorer2")
})

test_that("get_plays extracts play records", {
  plays <- get_plays(fixture_events())
  expect_equal(nrow(plays), 3)
  expect_true(all(plays$record_type == "play"))
})
