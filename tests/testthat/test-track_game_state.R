# Build a get_events()-shaped tibble from record strings like
# "play,1,0,bat1,00,X,S8"
mini_events <- function(lines, game_id = "TST202400010") {
  parts <- strsplit(lines, ",", fixed = TRUE)
  tibble::tibble(
    game_id = game_id,
    record_type = purrr::map_chr(parts, 1),
    f1 = purrr::map_chr(parts, ~ .x[2] %||% NA_character_),
    f2 = purrr::map_chr(parts, ~ .x[3] %||% NA_character_),
    f3 = purrr::map_chr(parts, ~ .x[4] %||% NA_character_),
    f4 = purrr::map_chr(parts, ~ .x[5] %||% NA_character_),
    f5 = purrr::map_chr(parts, ~ .x[6] %||% NA_character_),
    f6 = purrr::map_chr(parts, ~ .x[7] %||% NA_character_),
    line_number = seq_along(lines)
  )
}
`%||%` <- function(x, y) if (length(x) == 0 || is.na(x)) y else x

test_that("track_game_state() validates its input", {
  expect_snapshot(
    track_game_state(tibble::tibble(event = "S7")),
    error = TRUE
  )
})

test_that("track_game_state() handles events with no plays", {
  out <- track_game_state(mini_events("start,bat1,\"B One\",0,1,7"))
  expect_equal(nrow(out), 0)
  expect_contains(
    names(out),
    c("outs_before", "runner1_id", "runner3_id", "bat_score", "fld_score")
  )
})

test_that("outs, bases, and score track through a half-inning", {
  out <- track_game_state(mini_events(c(
    "start,bat1,\"B One\",0,1,7",
    "start,bat2,\"B Two\",0,2,8",
    "play,1,0,bat1,00,,W",
    "play,1,0,bat2,00,,K",
    "play,1,0,bat3,00,,S8.1-3",
    "play,1,0,bat4,00,,D9/L9.3-H;1-H",
    "play,1,0,bat5,00,,43/G",
    "play,1,0,bat6,00,,K",
    "play,1,1,home1,00,,HR/F78",
    "play,1,1,home2,00,,8/F"
  )))

  expect_equal(out$outs_before, c(0L, 0L, 1L, 1L, 1L, 2L, 0L, 0L))
  expect_equal(
    out$runner1_id,
    c(NA, "bat1", "bat1", "bat3", NA, NA, NA, NA)
  )
  expect_equal(
    out$runner3_id,
    c(NA, NA, NA, "bat1", NA, NA, NA, NA)
  )
  # bat4's double stays on second through the rest of the half
  expect_equal(out$runner2_id[5:6], c("bat4", "bat4"))
  expect_equal(out$bat_score, c(0L, 0L, 0L, 0L, 2L, 2L, 0L, 1L))
  expect_equal(out$fld_score, c(0L, 0L, 0L, 0L, 0L, 0L, 2L, 2L))
})

test_that("a pinch runner replaces the correct runner on base", {
  out <- track_game_state(mini_events(c(
    "start,bat1,\"B One\",0,1,7",
    "start,bat2,\"B Two\",0,2,8",
    "play,1,0,bat1,00,,W",
    "play,1,0,bat2,00,,NP",
    "sub,speedy,\"S Peedy\",0,1,12",
    "play,1,0,bat2,00,,S8.1-3",
    "play,1,0,bat3,00,,9/SF.3-H"
  )))

  expect_equal(out$runner1_id, c(NA, "bat1", "speedy", "bat2"))
  expect_equal(out$runner3_id, c(NA, NA, NA, "speedy"))
  expect_equal(out$runs_on_play[4], 1L)
})

test_that("the radj automatic runner starts the half on base", {
  out <- track_game_state(mini_events(c(
    "start,bat1,\"B One\",0,1,7",
    "play,10,0,bat3,00,,K",
    "radj,bat2,2",
    "play,10,1,home1,00,,S8.2-H"
  )))

  # top of the 10th: no radj consumed yet for team 0's half shown here
  expect_equal(out$runner2_id, c(NA, "bat2"))
  expect_equal(out$outs_before, c(0L, 0L))
  expect_equal(out$runs_on_play[2], 1L)
})

test_that("state matches Chadwick cwevent on the World Series goldens", {
  for (fixture in c("2024WS", "1954WS")) {
    year <- as.integer(substr(fixture, 1, 4))
    ours <- parse_event_file(
      test_path("fixtures", paste0(fixture, ".EVE")), year
    ) |>
      track_game_state() |>
      dplyr::filter(.data$event != "NP") |>
      dplyr::mutate(seq = dplyr::row_number(), .by = "game_id")
    gold <- readr::read_csv(
      test_path("fixtures", paste0("cwevent-", fixture, ".csv")),
      col_types = readr::cols(
        BASE1_RUN_ID = "c", BASE2_RUN_ID = "c", BASE3_RUN_ID = "c",
        .default = readr::col_guess()
      )
    ) |>
      dplyr::mutate(seq = dplyr::row_number(), .by = "GAME_ID")

    j <- dplyr::inner_join(ours, gold, by = c(game_id = "GAME_ID", seq = "seq"))
    expect_equal(nrow(j), nrow(gold))
    expect_equal(j$event, j$EVENT_TX)

    expect_equal(j$outs_before, as.integer(j$OUTS_CT))
    expect_equal(
      j$bat_score,
      as.integer(ifelse(j$team == 1, j$HOME_SCORE_CT, j$AWAY_SCORE_CT))
    )
    expect_equal(
      j$fld_score,
      as.integer(ifelse(j$team == 1, j$AWAY_SCORE_CT, j$HOME_SCORE_CT))
    )
    expect_equal(
      dplyr::coalesce(j$runner1_id, ""),
      dplyr::coalesce(j$BASE1_RUN_ID, "")
    )
    expect_equal(
      dplyr::coalesce(j$runner2_id, ""),
      dplyr::coalesce(j$BASE2_RUN_ID, "")
    )
    expect_equal(
      dplyr::coalesce(j$runner3_id, ""),
      dplyr::coalesce(j$BASE3_RUN_ID, "")
    )
    # with outs known, RBI matches cwevent exactly (incl. rule 9.04(a)(3))
    expect_equal(j$rbi, as.integer(j$RBI_CT))
  }
})

test_that("track_game_state() works end-to-end from the cache", {
  local_temp_cache()
  seed_event_zip(2024, "post")
  events <- suppressMessages(
    get_events(events = fake_events_tibble(2024, "post"), verbose = FALSE)
  )
  out <- track_game_state(events)
  expect_equal(nrow(out), 3)
  expect_equal(out$outs_before, c(0L, 0L, 0L))
  expect_equal(out$bat_score, c(0L, 0L, 0L))
})
