# Tests for parsing functions

test_that("parse_info_record parses info correctly", {
  result <- parse_info_record(c("visteam", "NYA"))
  expect_equal(result$info_type, "visteam")
  expect_equal(result$info_value, "NYA")
  
  # Handle single field
  result <- parse_info_record(c("version"))
  expect_equal(result$info_type, "version")
  expect_true(is.na(result$info_value))
})

test_that("parse_start_record parses starting lineups", {
  fields <- c("jeted001", "Derek Jeter", "0", "1", "6")
  result <- parse_start_record(fields)
  
  expect_equal(result$player_id, "jeted001")
  expect_equal(result$player_name, "Derek Jeter")
  expect_equal(result$team, 0)
  expect_equal(result$batting_order, 1)
  expect_equal(result$position, 6)
})

test_that("parse_play_record parses plays correctly", {
  fields <- c("1", "0", "jeted001", "32", "BCFBX", "S7")
  result <- parse_play_record(fields)
  
  expect_equal(result$inning, 1)
  expect_equal(result$team, 0)
  expect_equal(result$player_id, "jeted001")
  expect_equal(result$count, "32")
  expect_equal(result$pitches, "BCFBX")
  expect_equal(result$event, "S7")
})

test_that("parse_sub_record parses substitutions", {
  fields <- c("rodra001", "Alex Rodriguez", "0", "5", "5")
  result <- parse_sub_record(fields)
  
  expect_equal(result$player_id, "rodra001")
  expect_equal(result$player_name, "Alex Rodriguez")
  expect_equal(result$team, 0)
  expect_equal(result$batting_order, 5)
  expect_equal(result$position, 5)
})

test_that("parse_data_record parses data correctly", {
  fields <- c("er", "sabac001", "3")
  result <- parse_data_record(fields)
  
  expect_equal(result$data_type, "er")
  expect_equal(result$player_id, "sabac001")
  expect_equal(result$earned_runs, 3)
})

test_that("parse_record_by_type handles different record types", {
  # ID record
  result <- parse_record_by_type("id", c("NYA202404100"))
  expect_equal(result$game_id, "NYA202404100")
  
  # Version record
  result <- parse_record_by_type("version", c("2"))
  expect_equal(result$version, "2")
  
  # Comment record
  result <- parse_record_by_type("com", c("This", "is", "a", "comment"))
  expect_equal(result$comment, "This,is,a,comment")
  
  # Unknown record type
  result <- parse_record_by_type("unknown", c("test"))
  expect_equal(result$value, "test")
})

test_that("parse_record_by_type handles empty fields", {
  result <- parse_record_by_type("test", character(0))
  expect_true(is.na(result$value))
})

test_that("parse_start_record handles missing fields gracefully", {
  # Minimum fields
  result <- parse_start_record(c("jeted001"))
  expect_equal(result$player_id, "jeted001")
  expect_true(is.na(result$player_name))
  expect_true(is.na(result$team))
  expect_true(is.na(result$batting_order))
  expect_true(is.na(result$position))
})

test_that("parse_play_record handles missing fields gracefully", {
  # Minimum fields
  result <- parse_play_record(c("1"))
  expect_equal(result$inning, 1)
  expect_true(is.na(result$team))
  expect_true(is.na(result$player_id))
  expect_true(is.na(result$count))
  expect_true(is.na(result$pitches))
  expect_true(is.na(result$event))
})

