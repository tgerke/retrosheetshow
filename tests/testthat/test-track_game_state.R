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

# Complete starting lineups without a DH: visitors bat1-bat9 and home
# home1-home9, with batting slot k playing position c(7, 8, 9, 3, 5, 6, 4,
# 2, 1)[k] (pitchers bat ninth)
lineups <- function() {
  pos <- c(7, 8, 9, 3, 5, 6, 4, 2, 1)
  c(
    sprintf('start,bat%d,"B %d",0,%d,%d', 1:9, 1:9, 1:9, pos),
    sprintf('start,home%d,"H %d",1,%d,%d', 1:9, 1:9, 1:9, pos)
  )
}

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
    c(
      "outs_before", "runner1_id", "runner3_id", "bat_score", "fld_score",
      "pitcher_id", "resp_pitcher_id", "resp_batter_id",
      paste0("fielder", 2:9, "_id"), "pitches_on_play", "pitch_count_before"
    )
  )
})

test_that("outs, bases, and score track through a half-inning", {
  out <- track_game_state(mini_events(c(
    lineups(),
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
    lineups(),
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
    lineups(),
    "play,10,0,bat3,00,,K",
    "radj,bat2,2",
    "play,10,1,home1,00,,S8.2-H"
  )))

  # top of the 10th: no radj consumed yet for team 0's half shown here
  expect_equal(out$runner2_id, c(NA, "bat2"))
  expect_equal(out$outs_before, c(0L, 0L))
  expect_equal(out$runs_on_play[2], 1L)
})

test_that("the defense follows double switches and position changes", {
  expect_no_warning(out <- track_game_state(mini_events(c(
    lineups(),
    "play,1,0,bat1,00,,K",
    "play,1,0,bat2,00,,NP",
    # double switch: the reliever bats in the left fielder's slot and the
    # new left fielder in the pitcher's
    "sub,relief1,\"R One\",1,1,1",
    "sub,newlf,\"N Lf\",1,9,7",
    "play,1,0,bat2,00,,K",
    "play,1,0,bat3,00,,NP",
    # third baseman and shortstop trade positions
    "sub,home5,\"H 5\",1,5,6",
    "sub,home6,\"H 6\",1,6,5",
    "play,1,0,bat3,00,,K"
  ))))

  expect_equal(
    out$pitcher_id,
    c("home9", "home9", "relief1", "relief1", "relief1")
  )
  expect_equal(out$fielder7_id, c("home1", "home1", "newlf", "newlf", "newlf"))
  expect_equal(out$fielder5_id[c(1, 5)], c("home5", "home6"))
  expect_equal(out$fielder6_id[c(1, 5)], c("home6", "home5"))
  expect_equal(out$fielder2_id, rep("home8", 5))
})

test_that("pinch hitters and runners who stay in the game take the field", {
  expect_no_warning(out <- track_game_state(mini_events(c(
    lineups(),
    "play,1,0,bat1,00,,K",
    "play,1,0,bat2,00,,K",
    "play,1,0,bat3,00,,K",
    "play,1,1,home1,00,,NP",
    "sub,phx,\"P X\",1,1,11",
    "play,1,1,phx,00,,K",
    "play,1,1,home2,00,,S8",
    "play,1,1,home3,00,,NP",
    "sub,pry,\"P Y\",1,2,12",
    "play,1,1,home3,00,,K",
    "play,1,1,home4,00,,K",
    # the NP record before the defensive subs still shows the replaced
    # fielders; the subs put both substitutes in the field
    "play,2,0,bat4,00,,NP",
    "sub,phx,\"P X\",1,1,7",
    "sub,pry,\"P Y\",1,2,8",
    "play,2,0,bat4,00,,K"
  ))))

  expect_equal(out$runner1_id[8], "pry")
  expect_equal(out$fielder7_id[c(1, 10, 11)], c("home1", "home1", "phx"))
  expect_equal(out$fielder8_id[c(1, 10, 11)], c("home2", "home2", "pry"))
})

test_that("a starting pitcher who is also the DH bats after leaving the mound", {
  # the 2022 "Ohtani rule": one player in two start records, at DH and pitcher
  home <- c(
    "start,twoway,\"Two Way\",1,1,10",
    sprintf(
      'start,home%d,"H %d",1,%d,%d', 2:9, 2:9, 2:9, c(8, 9, 3, 5, 6, 4, 2, 7)
    ),
    "start,twoway,\"Two Way\",1,0,1"
  )
  expect_no_warning(out <- track_game_state(mini_events(c(
    lineups()[1:9],
    home,
    "play,1,0,bat1,00,,K",
    "play,1,1,twoway,00,,S8",
    "play,2,0,bat2,00,,NP",
    "sub,relief1,\"R One\",1,0,1",
    "play,2,0,bat2,00,,K",
    "play,2,1,twoway,00,,K"
  ))))

  expect_equal(
    out$pitcher_id,
    c("twoway", "bat9", "twoway", "relief1", "bat9")
  )
  expect_equal(out$player_id[c(2, 5)], c("twoway", "twoway"))
  expect_equal(out$fielder7_id[4], "home9")
})

test_that("the pitcher entering the batting order ends the DH", {
  home <- c(
    sprintf(
      'start,home%d,"H %d",1,%d,%d', 1:9, 1:9, 1:9,
      c(10, 8, 9, 3, 5, 6, 4, 2, 7)
    ),
    "start,homep,\"H P\",1,0,1"
  )
  expect_no_warning(out <- track_game_state(mini_events(c(
    lineups()[1:9],
    home,
    "play,1,0,bat1,00,,K",
    "play,1,0,bat2,00,,NP",
    # the DH moves to left field and the pitcher takes the left fielder's
    # batting slot
    "sub,home1,\"H 1\",1,1,7",
    "sub,homep,\"H P\",1,9,1",
    "play,1,0,bat2,00,,K"
  ))))

  expect_equal(out$fielder7_id, c("home9", "home9", "home1"))
  expect_equal(out$pitcher_id, rep("homep", 3))
})

test_that("a walk after a mid-count pitching change follows rule 9.16(h)", {
  expect_no_warning(out <- track_game_state(mini_events(c(
    lineups(),
    # batter ahead 3-1 when the reliever enters: the walk is the starter's
    "play,1,0,bat1,31,BBCB,NP",
    "sub,relief1,\"R One\",1,9,1",
    "play,1,0,bat1,31,BBCB.B,W",
    # 1-0 is not a decided advantage: the walk is the reliever's
    "play,1,0,bat2,10,B,NP",
    "sub,relief2,\"R Two\",1,9,1",
    "play,1,0,bat2,30,B.BBB,W.1-2",
    # an outcome other than a walk is the reliever's
    "play,1,0,bat3,20,BB,NP",
    "sub,relief3,\"R Three\",1,9,1",
    "play,1,0,bat3,20,BB.X,S7.2-3;1-2",
    # a second change at 2-2 hands the batter to the newest reliever
    "play,1,0,bat4,20,BB,NP",
    "sub,relief4,\"R Four\",1,9,1",
    "play,1,0,bat4,22,BB.CS,NP",
    "sub,relief5,\"R Five\",1,9,1",
    "play,1,0,bat4,32,BB.CS.BB,W.3-H;2-3;1-2",
    # responsibility ends with the plate appearance
    "play,1,0,bat5,30,BBBB,W.3-H;2-3;1-2"
  ))))

  walks <- out[out$event_type == "walk", ]
  expect_equal(
    walks$pitcher_id,
    c("relief1", "relief2", "relief5", "relief5")
  )
  expect_equal(
    walks$resp_pitcher_id,
    c("home9", "relief2", "relief5", "relief5")
  )
  expect_equal(out$resp_pitcher_id[out$event_type == "single"], "relief3")
})

test_that("a two-strike pinch hitter's strikeout is the first batter's", {
  expect_no_warning(out <- track_game_state(mini_events(c(
    lineups(),
    "play,1,0,bat1,02,CS,NP",
    "sub,ph1,\"P One\",0,1,11",
    "play,1,0,ph1,12,CS.BS,K",
    # any other outcome belongs to the pinch hitter (rule 9.15(b))
    "play,1,0,bat2,02,CS,NP",
    "sub,ph2,\"P Two\",0,2,11",
    "play,1,0,ph2,32,CS.BBBB,W",
    # with fewer than two strikes the strikeout is the pinch hitter's
    "play,1,0,bat3,01,C,NP",
    "sub,ph3,\"P Three\",0,3,11",
    "play,1,0,ph3,12,C.BSS,K"
  ))))

  batted <- out[out$event != "NP", ]
  expect_equal(batted$player_id, c("ph1", "ph2", "ph3"))
  expect_equal(batted$resp_batter_id, c("bat1", "ph2", "ph3"))
})

test_that("an unknown count at the change leaves the outcome with the substitute", {
  out <- track_game_state(mini_events(c(
    lineups(),
    "play,1,0,bat1,??,,NP",
    "sub,relief1,\"R One\",1,9,1",
    "play,1,0,bat1,??,,W",
    "play,1,0,bat2,??,,NP",
    "sub,ph2,\"P Two\",0,2,11",
    "play,1,0,ph2,??,,K"
  )))

  expect_equal(out$resp_pitcher_id[2], "relief1")
  expect_equal(out$resp_batter_id[4], "ph2")
})

test_that("pitches are counted once and split across a pitching change", {
  expect_no_warning(out <- track_game_state(mini_events(c(
    "info,pitches,pitches",
    lineups(),
    "play,1,0,bat1,10,B,NP",
    "sub,relief1,\"R One\",1,9,1",
    "play,1,0,bat1,22,B.CBSX,S9",
    "play,1,0,bat2,01,C1>*B,SB2",
    "play,1,0,bat2,12,C1>*B.F*S,K",
    "play,1,0,bat3,30,VVVV,IW",
    "play,1,0,bat4,00,,NP",
    "play,1,0,bat4,00,X,63/G"
  ))))

  expect_equal(out$pitcher_id[1:2], c("home9", "relief1"))
  expect_equal(out$pitches_on_play, c(1L, 4L, 2L, 2L, 0L, 0L, 1L))
  expect_equal(out$pitch_count_before, c(0L, 0L, 4L, 6L, 8L, 8L, 8L))
})

test_that("pitch counts are NA in games without pitch sequences", {
  out <- track_game_state(mini_events(c(
    "info,pitches,count",
    lineups(),
    "play,1,0,bat1,22,,S9"
  )))

  expect_equal(out$pitches_on_play, NA_integer_)
  expect_equal(out$pitch_count_before, NA_integer_)
})

test_that("an NP record without a sequence in mid plate appearance adds nothing", {
  # 1990s files often leave the sequence off substitution markers
  expect_no_warning(out <- track_game_state(mini_events(c(
    "info,pitches,pitches",
    lineups(),
    "play,1,0,bat1,02,CC,NP",
    "play,1,0,bat1,02,,NP",
    "sub,relief1,\"R One\",1,9,1",
    "play,1,0,bat1,12,CC.BX,63/G"
  ))))

  expect_equal(out$pitcher_id, c("home9", "home9", "relief1"))
  expect_equal(out$pitches_on_play, c(2L, 0L, 2L))
  expect_equal(out$pitch_count_before, c(0L, 2L, 0L))
})

test_that("a completed plate appearance without a sequence is a gap, not zero", {
  expect_no_warning(out <- track_game_state(mini_events(c(
    "info,pitches,pitches",
    lineups(),
    "play,1,0,bat1,12,,7",
    "play,1,0,bat2,00,X,63/G"
  ))))

  expect_equal(out$pitches_on_play, c(NA, 1L))
  expect_equal(out$pitch_count_before, c(0L, NA))
})

test_that("re-annotated markers and pitch types between records still count", {
  # both from 1988 files: a dropped no-pitch code, a pitchout relabeled
  expect_no_warning(out <- track_game_state(mini_events(c(
    "info,pitches,pitches",
    lineups(),
    "play,1,0,bat1,20,BBN,NP",
    "play,1,0,bat1,22,BB.CBSS,K",
    "play,1,0,bat2,00,Q,NP",
    "play,1,0,bat2,22,P.CBCX,63/G"
  ))))

  expect_equal(out$pitches_on_play, c(2L, 4L, 1L, 4L))
})

test_that("a pitch sequence that loses pitches mid plate appearance is flagged", {
  expect_warning(
    out <- track_game_state(mini_events(c(
      "info,pitches,pitches",
      lineups(),
      "play,1,0,bat1,12,CSF,NP",
      "play,1,0,bat1,12,FX,63/G",
      "play,1,0,bat2,00,X,63/G"
    ))),
    "fewer pitches"
  )

  expect_equal(out$pitches_on_play, c(3L, NA, 1L))
  expect_equal(out$pitch_count_before, c(0L, 3L, NA))
})

test_that("an incomplete defensive alignment is flagged", {
  expect_warning(
    track_game_state(mini_events(c(
      lineups()[-18],
      "play,1,0,bat1,00,,K"
    ))),
    "vacant position"
  )
})

test_that("state matches Chadwick cwevent on the World Series goldens", {
  id_cols <- c(
    "BASE1_RUN_ID", "BASE2_RUN_ID", "BASE3_RUN_ID", "PIT_ID", "RESP_PIT_ID",
    "RESP_BAT_ID", paste0("POS", 2:9, "_FLD_ID")
  )
  for (fixture in c("2025WS", "2024WS", "1954WS")) {
    year <- as.integer(substr(fixture, 1, 4))
    ours <- parse_event_file(
      test_path("fixtures", paste0(fixture, ".EVE")), year
    ) |>
      track_game_state() |>
      dplyr::filter(.data$event != "NP") |>
      dplyr::mutate(seq = dplyr::row_number(), .by = "game_id")
    gold <- readr::read_csv(
      test_path("fixtures", paste0("cwevent-", fixture, ".csv")),
      col_types = do.call(
        readr::cols,
        c(
          stats::setNames(rep(list("c"), length(id_cols)), id_cols),
          .default = readr::col_guess()
        )
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

    expect_equal(j$pitcher_id, j$PIT_ID)
    expect_equal(j$resp_pitcher_id, j$RESP_PIT_ID)
    expect_equal(j$resp_batter_id, j$RESP_BAT_ID)
    for (pos in 2:9) {
      expect_equal(
        j[[paste0("fielder", pos, "_id")]],
        j[[paste0("POS", pos, "_FLD_ID")]]
      )
    }

    # each record carries the plate appearance's pitches so far, which
    # cwevent counts as balls plus strikes thrown (it skips only the
    # unknown-pitch code U, absent from these files)
    expect_equal(
      count_pitches(dplyr::coalesce(j$pitches, "")),
      as.integer(j$PA_BALL_CT + j$PA_STRIKE_CT)
    )
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
