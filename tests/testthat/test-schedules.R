test_that("read_schedule_file parses the current 13-column format", {
  sched <- read_schedule_file(
    test_path("fixtures", "2024schedule-excerpt.csv"),
    year = 2024
  )

  expect_equal(nrow(sched), 3)
  expect_named(
    sched,
    c(
      "date", "game_number", "day_of_week",
      "visiting_team", "visiting_league", "visiting_game_number",
      "home_team", "home_league", "home_game_number",
      "day_night", "location", "postponed", "makeup_date", "year"
    )
  )

  expect_equal(sched$date[1], "20240320")
  expect_equal(sched$visiting_team[1], "LAN")
  expect_equal(sched$home_team[1], "SDN")
  expect_type(sched$game_number, "integer")
  expect_type(sched$visiting_game_number, "integer")
  expect_equal(sched$location[1], "SEO01")
  expect_equal(sched$postponed[3], "Rain")
  expect_equal(sched$makeup_date[3], "20240329")
})

test_that("read_schedule_file parses the historical 12-column format", {
  sched <- read_schedule_file(
    test_path("fixtures", "1877schedule-excerpt.csv"),
    year = 1877
  )

  expect_equal(nrow(sched), 3)
  # location is absent historically but the schema stays consistent
  expect_true("location" %in% names(sched))
  expect_true(all(is.na(sched$location)))
  expect_equal(sched$visiting_team[1], "BSN")
  expect_equal(sched$year[1], 1877)
})

test_that("read_schedule_file rejects unknown layouts", {
  bad <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b,c", "1,2,3"), bad)

  expect_error(
    read_schedule_file(bad, year = 2024),
    "Unexpected schedule format"
  )
})
