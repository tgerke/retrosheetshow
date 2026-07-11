test_that("read_parkcode_file maps columns correctly", {
  content <- paste(
    readLines(test_path("fixtures", "parkcode-excerpt.txt")),
    collapse = "\n"
  )
  parks <- read_parkcode_file(content)

  expect_named(
    parks,
    c("park_id", "name", "aka", "city", "state", "start", "end", "league", "notes")
  )
  # regression: the parser used to skip the AKA column, shifting every
  # field after `name` (and kept the header as a data row)
  expect_false("PARKID" %in% parks$park_id)
  expect_equal(parks$park_id[1], "ALB01")
  expect_equal(parks$name[1], "Riverside Park")
  expect_equal(parks$city[1], "Albany")
  expect_equal(parks$state[1], "NY")
  expect_equal(parks$league[1], "NL")

  # quoted commas in notes stay in one field
  expect_match(parks$notes[1], ";")
})

test_that("read_biofile parses the 33-field player database", {
  players <- read_biofile(test_path("fixtures", "biofile-excerpt.txt"))

  expect_equal(ncol(players), 33)
  expect_equal(nrow(players), 2)

  expect_equal(players$player_id[1], "aardd001")
  expect_equal(players$last_name[1], "Aardsma")
  expect_equal(players$first_name[1], "David Allan")
  expect_equal(players$birth_date[1], "12/27/1981")
  expect_equal(players$bats[1], "R")

  # Hank Aaron: Hall of Fame flag and death date land in the right columns
  aaron <- players[players$player_id == "aaroh101", ]
  expect_equal(aaron$hof, "HOF")
  expect_equal(aaron$death_date, "01/22/2021")
})

test_that("get_team_ids reads the TEAM file from a cached archive", {
  local_temp_cache()
  seed_event_zip(2024, "regular", include_rosters = TRUE)

  teams <- suppressMessages(get_team_ids(2024))

  expect_named(teams, c("team_id", "league", "city", "name"))
  expect_equal(nrow(teams), 6)
  expect_true("BAL" %in% teams$team_id)
  expect_equal(teams$city[teams$team_id == "BAL"], "Baltimore")
})
