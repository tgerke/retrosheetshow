test_that("read_roster_file parses a roster", {
  roster <- read_roster_file(test_path("fixtures", "NYA2024.ROS"))

  expect_equal(nrow(roster), 8)
  expect_named(
    roster,
    c("player_id", "last_name", "first_name", "bats", "throws", "team", "position")
  )
  expect_equal(roster$team, rep("NYA", 8))
  expect_equal(roster$last_name[1], "Andrews")
})

test_that("read_roster_file falls back to the filename for missing team", {
  dir <- withr::local_tempdir()
  file <- file.path(dir, "BOS2024.ROS")
  writeLines("smitj001,Smith,John,R,R,,P", file)

  roster <- read_roster_file(file)
  expect_equal(roster$team, "BOS")
})

test_that("get_rosters extracts rosters from a cached event archive", {
  local_temp_cache()
  seed_event_zip(2024, "regular", include_rosters = TRUE)

  rosters <- suppressMessages(get_rosters(year = 2024, verbose = FALSE))

  expect_equal(nrow(rosters), 8)
  expect_equal(unique(rosters$team), "NYA")
  expect_equal(unique(rosters$year), 2024)

  # team filter (the roster's own `team` column, not the argument, is matched)
  filtered <- suppressMessages(
    get_rosters(year = 2024, team = "NYA", verbose = FALSE)
  )
  expect_equal(nrow(filtered), 8)

  none <- suppressMessages(
    get_rosters(year = 2024, team = "BOS", verbose = FALSE)
  )
  expect_equal(nrow(none), 0)
})
