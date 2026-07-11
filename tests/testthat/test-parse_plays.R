# Parse a bare event string; expectations reference the notation guide at
# https://www.retrosheet.org/eventfile.htm
pp <- function(event) {
  parse_plays(tibble::tibble(event = event))
}

test_that("parse_plays() requires an event column", {
  expect_snapshot(
    parse_plays(tibble::tibble(x = 1)),
    error = TRUE
  )
})

test_that("parse_plays() handles zero-row input", {
  out <- pp(character())
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
  expect_contains(
    names(out),
    c("event_type", "is_at_bat", "outs_on_play", "batter_dest")
  )
})

test_that("hits are classified with value, fielder, and batter destination", {
  out <- pp(c("S7", "D8/78", "T9/F9LD.2-H", "DGR/L9LS.2-H", "H/L7D", "HR9/F9LS.3-H;1-H"))
  expect_equal(
    out$event_type,
    c("single", "double", "triple", "double", "home_run", "home_run")
  )
  expect_equal(out$hit_value, c(1L, 2L, 3L, 2L, 4L, 4L))
  expect_equal(out$fielded_by, c(7L, 8L, 9L, NA, NA, 9L))
  expect_equal(out$batter_dest, c(1L, 2L, 3L, 2L, 4L, 4L))
  expect_true(all(out$is_hit))
  expect_true(all(out$is_at_bat))
})

test_that("simple and multi-fielder outs retire the batter", {
  out <- pp(c("8/F78", "63/G6M", "143/G1", "3/G.2-3"))
  expect_equal(unique(out$event_type), "generic_out")
  expect_equal(out$outs_on_play, rep(1L, 4))
  expect_equal(out$batter_dest, rep(0L, 4))
  expect_equal(out$fielded_by, c(8L, 6L, 1L, 3L))
  expect_equal(out$runner2_dest, c(NA, NA, NA, 3L))
})

test_that("force outs leave the batter safe at first", {
  out <- pp("54(1)/FO/G5.3-H;B-1")
  expect_equal(out$event_type, "generic_out")
  expect_equal(out$batter_dest, 1L)
  expect_equal(out$runner1_dest, 0L)
  expect_equal(out$runner3_dest, 4L)
  expect_equal(out$outs_on_play, 1L)
  expect_equal(out$runs_on_play, 1L)
  expect_equal(out$rbi, 1L)
})

test_that("double and triple plays count all outs", {
  out <- pp(c(
    "64(1)3/GDP/G6",       # runner on first, then batter at first
    "8(B)84(2)/LDP/L8",    # batter, then runner doubled off second
    "3(B)3(1)/LDP",        # unassisted
    "1(B)16(2)63(1)/LTP/L1"
  ))
  expect_equal(out$outs_on_play, c(2L, 2L, 2L, 3L))
  expect_equal(out$batter_dest, rep(0L, 4))
  expect_equal(out$runner1_dest, c(0L, NA, 0L, 0L))
  expect_equal(out$runner2_dest, c(NA, 0L, NA, 0L))
  expect_equal(out$is_gdp, c(TRUE, FALSE, FALSE, FALSE))
})

test_that("no RBI is credited on a ground-ball double play", {
  out <- pp(c("64(1)3/GDP.3-H", "64(1)3/G6.3-H"))
  expect_equal(out$runs_on_play, c(1L, 1L))
  expect_equal(out$rbi, c(0L, 1L))
})

test_that("strikeouts retire the batter unless he reaches on the third strike", {
  out <- pp(c("K", "K23", "K+PB.1-2", "K+WP.B-1", "K23+WP.2-3", "K/DP.1X2(26)", "K.1-2(WP)"))
  expect_equal(unique(out$event_type), "strikeout")
  expect_equal(out$batter_dest, c(0L, 0L, 0L, 1L, 0L, 0L, 0L))
  expect_equal(out$outs_on_play, c(1L, 1L, 1L, 0L, 1L, 2L, 1L))
  expect_equal(out$runner1_dest, c(NA, NA, 2L, NA, NA, 0L, 2L))
  expect_equal(out$runner2_dest, c(NA, NA, NA, NA, 3L, NA, NA))
})

test_that("strikeout plus stolen base records both outcomes", {
  out <- pp("K+SB2")
  expect_equal(out$event_type, "strikeout")
  expect_equal(out$outs_on_play, 1L)
  expect_equal(out$runner1_dest, 2L)
})

test_that("walks and hit-by-pitch put the batter on first without an at bat", {
  out <- pp(c("W.1-2", "IW", "I", "HP.1-2", "W+WP.2-3", "W+PB.3-H(NR);1-3"))
  expect_equal(
    out$event_type,
    c("walk", "intentional_walk", "intentional_walk", "hit_by_pitch", "walk", "walk")
  )
  expect_equal(out$batter_dest, rep(1L, 6))
  expect_true(all(out$is_plate_appearance))
  expect_false(any(out$is_at_bat))
  # run scored on the passed ball, not the walk: explicit (NR)
  expect_equal(out$runs_on_play[6], 1L)
  expect_equal(out$rbi[6], 0L)
})

test_that("errors and fielder's choices put the batter on first with an at bat", {
  out <- pp(c("E1/TH/BG15.1-3", "E3.1-2;B-1", "3E1", "FC5/G5.3XH(52)", "FC3/G3S.3-H;1-2"))
  expect_equal(
    out$event_type,
    c("error", "error", "error", "fielders_choice", "fielders_choice")
  )
  expect_equal(out$batter_dest, rep(1L, 5))
  expect_true(all(out$is_at_bat))
  expect_equal(out$outs_on_play, c(0L, 0L, 0L, 1L, 0L))
  expect_equal(out$runner3_dest, c(NA, NA, NA, 0L, 4L))
})

test_that("RBI honors explicit markers and error-advance exclusions", {
  out <- pp(c(
    "E6/G6.3-H;2-3;B-1",       # runner from third scores on the batter event
    "E6/G6.3-H(RBI);2-3;B-1",  # explicit credit
    "S7.3-H;1-H(E7/TH)",       # second run scored on the throwing error
    "D7.2-H(NR)"               # explicit no-RBI
  ))
  expect_equal(out$runs_on_play, c(1L, 1L, 2L, 1L))
  expect_equal(out$rbi, c(1L, 1L, 1L, 0L))
})

test_that("catcher's interference is a plate appearance but not an at bat", {
  out <- pp("C/E2.1-2")
  expect_equal(out$event_type, "interference")
  expect_equal(out$batter_dest, 1L)
  expect_true(out$is_plate_appearance)
  expect_false(out$is_at_bat)
})

test_that("sacrifices are plate appearances but not at bats", {
  out <- pp(c("9/SF.3-H", "23/SH.1-2", "54(B)/BG25/SH.1-2"))
  expect_equal(out$is_sac_fly, c(TRUE, FALSE, FALSE))
  expect_equal(out$is_sac_hit, c(FALSE, TRUE, TRUE))
  expect_true(all(out$is_plate_appearance))
  expect_false(any(out$is_at_bat))
  expect_equal(out$rbi, c(1L, 0L, 0L))
  expect_equal(out$outs_on_play, c(1L, 1L, 1L))
})

test_that("baserunning events do not involve the batter", {
  out <- pp(c(
    "BK.3-H;1-2", "CSH(12)", "CS2(24).2-3", "DI.1-2", "OA.2X3(25)",
    "WP.2-3;1-2", "PB.2-3", "PO2(14)", "POCS2(1361)", "SB2", "FLE5/P5F"
  ))
  expect_equal(
    out$event_type,
    c(
      "balk", "caught_stealing", "caught_stealing", "defensive_indifference",
      "other_advance", "wild_pitch", "passed_ball", "pickoff",
      "caught_stealing", "stolen_base", "foul_error"
    )
  )
  expect_false(any(out$is_plate_appearance))
  expect_equal(out$batter_dest, rep(0L, 11))
  expect_equal(
    out$outs_on_play,
    c(0L, 1L, 1L, 0L, 1L, 0L, 0L, 1L, 1L, 0L, 0L)
  )
})

test_that("stolen bases imply the runner's advance, including double steals", {
  out <- pp(c("SB2", "SB3;SB2", "SBH;SB2"))
  expect_equal(out$runner1_dest, c(2L, 2L, 2L))
  expect_equal(out$runner2_dest, c(NA, 3L, NA))
  expect_equal(out$runner3_dest, c(NA, NA, 4L))
  # a steal of home scores a run but never an RBI
  expect_equal(out$runs_on_play, c(0L, 0L, 1L))
  expect_equal(out$rbi, c(0L, 0L, 0L))
})

test_that("an error in the advance or event parameters negates the out", {
  out <- pp(c(
    "CS2(2E4).1-3",              # explicit advance overrides the negated out
    "CS2(2E4)",                  # runner safe at the target base
    "PO1(E3).1-2",               # pickoff error, runner advances
    "PO1(E3)",                   # pickoff error, runner holds
    "S7/L7LD.3-H;2-H;BX2(7E4)",  # batter safe at second on the error
    "S8/L78.BX2(8434)"           # out at second stands
  ))
  expect_equal(out$outs_on_play, c(0L, 0L, 0L, 0L, 0L, 1L))
  expect_equal(out$runner1_dest, c(3L, 2L, 2L, 1L, NA, NA))
  expect_equal(out$batter_dest, c(0L, 0L, 0L, 0L, 2L, 0L))
})

test_that("uncertainty markers are ignored", {
  out <- pp(c("PB.2-3#", "S7/G56!", "K?"))
  expect_equal(out$event_type, c("passed_ball", "single", "strikeout"))
})

test_that("modifiers yield trajectory, location, and bunt flags", {
  out <- pp(c("63/G6M", "8/F78", "T9/F9LD", "5/P5", "E1/TH/BG15", "S7/L7LD", "D8/78"))
  expect_equal(
    out$trajectory,
    c("ground", "fly", "fly", "popup", "ground", "line", NA)
  )
  expect_equal(
    out$hit_location,
    c("6M", "78", "9LD", "5", "15", "7LD", "78")
  )
  expect_equal(out$is_bunt, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE))
})

test_that("no-play records carry no statistics", {
  out <- pp("NP")
  expect_equal(out$event_type, "no_play")
  expect_false(out$is_plate_appearance)
  expect_equal(out$outs_on_play, 0L)
  expect_equal(out$batter_dest, 0L)
})

test_that("unrecognized events warn and yield NA event_type", {
  expect_warning(out <- pp("ZZZ"), "could not be classified")
  expect_equal(out$event_type, NA_character_)
  expect_false(out$is_plate_appearance)
})

# Golden-file validation against Chadwick's cwevent, the community reference
# implementation of the event grammar. Fixtures are full World Series event
# files (modern and historical notation); regenerate them with
# data-raw/make-cwevent-golden.R. cwevent tracks full game state, so rows
# align 1:1 with non-NP play records, and columns we derive from the string
# alone are compared directly. Documented divergences from cwevent:
#   * POCS is classified "caught_stealing" (the runner is charged with a CS
#     per the spec); cwevent codes it as a pickoff (EVENT_CD 8).
#   * $E$ plays like "3E1" are "error" per the spec ("E$ (or $E$) is the code
#     for an error allowing a batter to get on base"); cwevent occasionally
#     codes them as generic outs (EVENT_CD 2).
#   * trajectory/is_bunt are only compared where the notation records them;
#     cwevent infers defaults (e.g. ground for "63") from scoring context.
test_that("parse_plays() matches Chadwick cwevent on World Series goldens", {
  event_cd <- c(
    generic_out = 2, strikeout = 3, stolen_base = 4,
    defensive_indifference = 5, caught_stealing = 6, pickoff = 8,
    wild_pitch = 9, passed_ball = 10, balk = 11, other_advance = 12,
    foul_error = 13, walk = 14, intentional_walk = 15, hit_by_pitch = 16,
    interference = 17, error = 18, fielders_choice = 19, single = 20,
    double = 21, triple = 22, home_run = 23
  )
  trajectory_cd <- c(F = "fly", G = "ground", L = "line", P = "popup")
  # cwevent dest codes 5 and 6 are unearned-run variants of "scored"
  clamp <- function(dest) pmin(dest, 4)

  for (fixture in c("2024WS", "1954WS")) {
    raw <- readr::read_lines(test_path("fixtures", paste0(fixture, ".EVE")))
    game_of_line <- cumsum(startsWith(raw, "id,"))
    plays <- tibble::tibble(line = raw) |>
      dplyr::mutate(
        game_id = sub("^id,", "", raw[startsWith(raw, "id,")])[game_of_line]
      ) |>
      dplyr::filter(startsWith(.data$line, "play,")) |>
      tidyr::separate_wider_delim(
        "line", ",",
        names = c("rec", "inning", "team", "player_id", "count", "pitches", "event"),
        too_many = "merge"
      )

    ours <- parse_plays(plays) |>
      dplyr::filter(.data$event != "NP") |>
      dplyr::mutate(seq = dplyr::row_number(), .by = "game_id")
    gold <- readr::read_csv(
      test_path("fixtures", paste0("cwevent-", fixture, ".csv")),
      col_types = readr::cols(
        BATTEDBALL_CD = "c", BATTEDBALL_LOC_TX = "c", .default = readr::col_guess()
      )
    ) |>
      dplyr::mutate(seq = dplyr::row_number(), .by = "GAME_ID")

    j <- dplyr::inner_join(ours, gold, by = c(game_id = "GAME_ID", seq = "seq"))
    expect_equal(nrow(j), nrow(gold))
    expect_equal(j$event, j$EVENT_TX)

    expected_cd <- unname(event_cd[j$event_type])
    cd_exception <- (grepl("^POCS", j$event) & j$EVENT_CD == 8) |
      (j$event_type == "pickoff" & j$EVENT_CD == 7) |
      (j$event_type == "error" & j$EVENT_CD == 2)
    expect_equal(ifelse(cd_exception, j$EVENT_CD, expected_cd), j$EVENT_CD)

    expect_equal(j$is_at_bat, j$AB_FL)
    expect_equal(j$hit_value, j$H_CD)
    expect_equal(j$is_sac_hit, j$SH_FL)
    expect_equal(j$is_sac_fly, j$SF_FL)
    expect_equal(j$outs_on_play, as.integer(j$EVENT_OUTS_CT))
    expect_equal(j$rbi, as.integer(j$RBI_CT))
    expect_equal(dplyr::coalesce(j$fielded_by, 0L), as.integer(j$FLD_CD))
    expect_equal(j$is_bunt, j$BUNT_FL)
    expect_equal(
      dplyr::coalesce(j$hit_location, ""),
      dplyr::coalesce(j$BATTEDBALL_LOC_TX, "")
    )
    expect_equal(j$batter_dest, as.integer(clamp(j$BAT_DEST_ID)))

    recorded_traj <- !is.na(j$trajectory)
    expect_equal(
      j$trajectory[recorded_traj],
      unname(trajectory_cd[j$BATTEDBALL_CD[recorded_traj]])
    )

    for (base in 1:3) {
      mine <- j[[paste0("runner", base, "_dest")]]
      theirs <- as.integer(clamp(j[[paste0("RUN", base, "_DEST_ID")]]))
      expect_equal(mine[!is.na(mine)], theirs[!is.na(mine)])
    }
  }
})

test_that("parse_plays() appends columns to get_plays() output", {
  local_temp_cache()
  seed_event_zip(2024, "post")
  events <- suppressMessages(
    get_events(events = fake_events_tibble(2024, "post"), verbose = FALSE)
  )
  out <- get_plays(events) |>
    parse_plays()
  expect_equal(nrow(out), 3)
  expect_contains(names(out), c("game_id", "inning", "player_id", "event"))
  expect_equal(out$event_type, c("generic_out", "strikeout", "no_play"))
  expect_equal(out$outs_on_play, c(1L, 1L, 0L))
  expect_equal(out$fielded_by, c(7L, NA, NA))
})
