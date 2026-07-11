# Opt-in tests against the live Retrosheet server. Run with:
#   RETROSHEETSHOW_LIVE_TESTS=true Rscript -e 'devtools::test(filter = "live")'

skip_if_not_live <- function() {
  skip_on_cran()
  skip_if(
    !identical(Sys.getenv("RETROSHEETSHOW_LIVE_TESTS"), "true"),
    "Set RETROSHEETSHOW_LIVE_TESTS=true to run live tests"
  )
  skip_if_offline("retrosheet.org")
}

test_that("live: postseason events download and parse end to end", {
  skip_if_not_live()
  local_temp_cache()

  events <- suppressMessages(get_events(year = 2024, type = "post", verbose = FALSE))

  expect_gt(nrow(events), 5000)
  expect_gt(length(unique(events$game_id)), 30)
  expect_true(all(events$type == "post"))

  plays <- get_plays(events)
  expect_gt(nrow(plays), 3000)
  expect_true(all(plays$inning >= 1, na.rm = TRUE))

  # second call hits the cache
  expect_message(
    get_events(year = 2024, type = "post"),
    "Using cached"
  )
  status <- suppressMessages(cache_status())
  expect_equal(status$type, "post")
})

test_that("live: schedules download with the current format", {
  skip_if_not_live()
  local_temp_cache()

  sched <- suppressMessages(get_schedules(year = 2024, verbose = FALSE))

  expect_gte(nrow(sched), 2430)
  expect_true(all(nchar(sched$home_team) == 3))
  expect_true("SDN" %in% sched$home_team)
})

test_that("live: game logs have integer scores", {
  skip_if_not_live()
  local_temp_cache()

  logs <- suppressMessages(get_gamelogs(year = 2024, verbose = FALSE))

  expect_gte(nrow(logs), 2400)
  expect_type(logs$home_score, "integer")
  home_win_pct <- mean(logs$home_score > logs$visiting_score)
  expect_gt(home_win_pct, 0.45)
  expect_lt(home_win_pct, 0.62)
})

test_that("live: park reference data lands in the right columns", {
  skip_if_not_live()

  parks <- suppressMessages(get_park_ids())

  expect_gt(nrow(parks), 200)
  fenway <- parks[grepl("Fenway", parks$name), ]
  expect_equal(fenway$city[1], "Boston")
  expect_equal(fenway$state[1], "MA")
})

test_that("live: player database downloads", {
  skip_if_not_live()

  players <- suppressMessages(get_player_ids())

  expect_gt(nrow(players), 20000)
  expect_equal(players$player_id[1], "aardd001")
  expect_true("HOF" %in% players$hof)
})
