# Full-season cross-check of parse_plays() and track_game_state() against
# Chadwick's cwevent.
#
# The World Series goldens from make-cwevent-golden.R run offline in the test
# suite. This script runs the same comparison over whole seasons, where the
# rare situations live: mid-count substitutions, the extra-inning automatic
# runner, pitchers who are also the designated hitter, unusual notation. It
# downloads each season's regular-season and postseason archives, runs
# cwevent over every event file, runs the package over the same files, and
# reports agreement field by field. Disagreeing rows are written to
# crosscheck-mismatches.csv in the output directory.
#
# Usage, from the package root (needs network access and cwevent on the
# PATH; see make-cwevent-golden.R):
#
#   Rscript data-raw/cwevent-crosscheck.R [output_dir] [year ...]
#
# Defaults: a temporary directory and the 1954, 2024, and 2025 seasons.
#
# Some rows are not compared: BATTEDBALL_CD and RUN*_DEST_ID only where the
# notation records them (cwevent infers trajectories and fills in holding
# runners), and pitch counts only in games with pitch sequences. Rows
# covered by a documented divergence are counted separately from mismatches
# (see the golden tests and decisions/):
#   * EVENT_CD: POCS is a caught stealing, and $E$ plays are errors, per the
#     spec; cwevent codes them as pickoffs and (sometimes) generic outs.
#   * PA_PITCHES: count_pitches() counts the unknown-pitch code U, which
#     cwevent leaves out of its balls and strikes thrown.
#
# The information used here was obtained free of charge from and is
# copyrighted by Retrosheet: https://www.retrosheet.org

devtools::load_all(quiet = TRUE)
library(dplyr, warn.conflicts = FALSE)

stopifnot(nzchar(Sys.which("cwevent")))

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else tempdir()
years <- if (length(args) >= 2) as.integer(args[-1]) else c(1954, 2024, 2025)

fields <- paste(
  c(0, 2, 3, 4, 8, 9, 10, 12, 14, 16, 18:29, 34, 36:40, 43, 46:48, 50,
    58:61, 96),
  collapse = ","
)
extended <- "33,39"

event_cd <- c(
  generic_out = 2, strikeout = 3, stolen_base = 4,
  defensive_indifference = 5, caught_stealing = 6, pickoff = 8,
  wild_pitch = 9, passed_ball = 10, balk = 11, other_advance = 12,
  foul_error = 13, walk = 14, intentional_walk = 15, hit_by_pitch = 16,
  interference = 17, error = 18, fielders_choice = 19, single = 20,
  double = 21, triple = 22, home_run = 23
)
trajectory_cd <- c(F = "fly", G = "ground", L = "line", P = "popup")
`%||%` <- function(x, y) if (is.null(x)) y else x
num <- function(x) as.integer(x)
flag <- function(x) x == "T"
# cwevent dest codes 5 and 6 are unearned-run variants of "scored"
clamp <- function(x) pmin(num(x), 4L)

crosscheck_archive <- function(year, type) {
  work <- withr::local_tempdir()
  zip <- file.path(work, "events.zip")
  suffix <- if (type == "regular") "eve" else "post"
  download.file(
    glue::glue("https://www.retrosheet.org/events/{year}{suffix}.zip"),
    zip,
    quiet = TRUE
  )
  utils::unzip(zip, exdir = work)
  files <- list.files(work, pattern = "\\.EV[A-Z]$")

  gold_csv <- file.path(work, "cwevent.csv")
  withr::with_dir(work, {
    system2(
      "cwevent",
      c("-n", "-y", year, "-f", fields, "-x", extended, files),
      stdout = gold_csv, stderr = FALSE
    )
  })
  gold <- readr::read_csv(
    gold_csv,
    col_types = readr::cols(.default = readr::col_character())
  ) |>
    mutate(seq = row_number(), .by = "GAME_ID")

  events <- purrr::map(
    file.path(work, files),
    \(f) parse_event_file(f, year = year)
  ) |>
    bind_rows()
  warnings <- character()
  seconds <- system.time(
    states <- withCallingHandlers(
      track_game_state(events),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  )[["elapsed"]]

  pitch_games <- events$game_id[
    events$record_type == "info" & events$f1 %in% "pitches" &
      events$f2 %in% "pitches"
  ]

  ours <- states |>
    filter(.data$event != "NP") |>
    mutate(seq = row_number(), .by = "game_id")
  j <- inner_join(ours, gold, by = c(game_id = "GAME_ID", seq = "seq"))
  stopifnot(nrow(j) == nrow(gold), nrow(j) == nrow(ours))
  stopifnot(all(j$event == j$EVENT_TX))

  bat_home <- j$team == 1
  pa_pitches <- j$game_id %in% pitch_games
  checks <- list(
    EVENT_CD = list(
      unname(event_cd[j$event_type]), num(j$EVENT_CD),
      divergence = (grepl("^POCS", j$event) & j$EVENT_CD == "8") |
        (j$event_type %in% "pickoff" & j$EVENT_CD == "7") |
        (j$event_type %in% "error" & j$EVENT_CD == "2")
    ),
    AB_FL = list(j$is_at_bat, flag(j$AB_FL)),
    H_CD = list(j$hit_value, num(j$H_CD)),
    SH_FL = list(j$is_sac_hit, flag(j$SH_FL)),
    SF_FL = list(j$is_sac_fly, flag(j$SF_FL)),
    EVENT_OUTS_CT = list(j$outs_on_play, num(j$EVENT_OUTS_CT)),
    RBI_CT = list(j$rbi, num(j$RBI_CT)),
    FLD_CD = list(coalesce(j$fielded_by, 0L), num(j$FLD_CD)),
    BATTEDBALL_CD = list(
      j$trajectory, unname(trajectory_cd[j$BATTEDBALL_CD]),
      skip = is.na(j$trajectory)
    ),
    BUNT_FL = list(j$is_bunt, flag(j$BUNT_FL)),
    BATTEDBALL_LOC_TX = list(
      coalesce(j$hit_location, ""), coalesce(j$BATTEDBALL_LOC_TX, "")
    ),
    BAT_DEST_ID = list(j$batter_dest, clamp(j$BAT_DEST_ID)),
    RUN1_DEST_ID = list(
      j$runner1_dest, clamp(j$RUN1_DEST_ID),
      skip = is.na(j$runner1_dest)
    ),
    RUN2_DEST_ID = list(
      j$runner2_dest, clamp(j$RUN2_DEST_ID),
      skip = is.na(j$runner2_dest)
    ),
    RUN3_DEST_ID = list(
      j$runner3_dest, clamp(j$RUN3_DEST_ID),
      skip = is.na(j$runner3_dest)
    ),
    OUTS_CT = list(j$outs_before, num(j$OUTS_CT)),
    BAT_SCORE = list(
      j$bat_score, num(ifelse(bat_home, j$HOME_SCORE_CT, j$AWAY_SCORE_CT))
    ),
    FLD_SCORE = list(
      j$fld_score, num(ifelse(bat_home, j$AWAY_SCORE_CT, j$HOME_SCORE_CT))
    ),
    BASE1_RUN_ID = list(j$runner1_id, j$BASE1_RUN_ID),
    BASE2_RUN_ID = list(j$runner2_id, j$BASE2_RUN_ID),
    BASE3_RUN_ID = list(j$runner3_id, j$BASE3_RUN_ID),
    PIT_ID = list(j$pitcher_id, j$PIT_ID),
    RESP_PIT_ID = list(j$resp_pitcher_id, j$RESP_PIT_ID),
    RESP_BAT_ID = list(j$resp_batter_id, j$RESP_BAT_ID),
    POS2_FLD_ID = list(j$fielder2_id, j$POS2_FLD_ID),
    POS3_FLD_ID = list(j$fielder3_id, j$POS3_FLD_ID),
    POS4_FLD_ID = list(j$fielder4_id, j$POS4_FLD_ID),
    POS5_FLD_ID = list(j$fielder5_id, j$POS5_FLD_ID),
    POS6_FLD_ID = list(j$fielder6_id, j$POS6_FLD_ID),
    POS7_FLD_ID = list(j$fielder7_id, j$POS7_FLD_ID),
    POS8_FLD_ID = list(j$fielder8_id, j$POS8_FLD_ID),
    POS9_FLD_ID = list(j$fielder9_id, j$POS9_FLD_ID),
    PA_PITCHES = list(
      count_pitches(coalesce(j$pitches, "")),
      num(j$PA_BALL_CT) + num(j$PA_STRIKE_CT),
      skip = !pa_pitches,
      divergence = grepl("U", coalesce(j$pitches, ""))
    )
  )

  compared <- purrr::imap(checks, function(chk, field) {
    ours_val <- as.character(chk[[1]])
    theirs_val <- as.character(chk[[2]])
    skip <- chk$skip %||% rep(FALSE, nrow(j))
    divergence <- !skip & (chk$divergence %||% rep(FALSE, nrow(j)))
    differs <- !skip & !divergence &
      !(coalesce(ours_val, "") == coalesce(theirs_val, ""))
    list(
      summary = tibble(
        year = year, type = type, field = field,
        compared = sum(!skip & !divergence), mismatches = sum(differs),
        divergences = sum(divergence)
      ),
      rows = tibble(
        year = year, type = type, field = field,
        game_id = j$game_id[differs], seq = j$seq[differs],
        event = j$event[differs], ours = ours_val[differs],
        cwevent = theirs_val[differs]
      )
    )
  })

  pitch_states <- states[states$game_id %in% pitch_games, ]
  list(
    summary = bind_rows(purrr::map(compared, "summary")),
    rows = bind_rows(purrr::map(compared, "rows")),
    info = tibble(
      year = year, type = type, files = length(files),
      games = n_distinct(j$game_id), events = nrow(j),
      play_records = nrow(states), pitch_games = n_distinct(pitch_games),
      u_codes = sum(grepl("U", coalesce(pitch_states$pitches, ""))),
      zero_pitch_pas = sum(
        pitch_states$is_plate_appearance &
          !grepl("[BCFHIKLMOPQRSTUXY]", coalesce(pitch_states$pitches, ""))
      ),
      tracker_seconds = seconds,
      warnings = paste(unique(warnings), collapse = " | ")
    )
  )
}

results <- purrr::map(years, function(year) {
  purrr::map(c("regular", "post"), function(type) {
    cli::cli_inform("Cross-checking {year} {type} season")
    crosscheck_archive(year, type)
  })
}) |>
  purrr::list_flatten()

summary <- bind_rows(purrr::map(results, "summary"))
info <- bind_rows(purrr::map(results, "info"))
mismatches <- bind_rows(purrr::map(results, "rows"))

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
readr::write_csv(mismatches, file.path(out_dir, "crosscheck-mismatches.csv"))
readr::write_csv(summary, file.path(out_dir, "crosscheck-summary.csv"))
readr::write_csv(info, file.path(out_dir, "crosscheck-info.csv"))

cli::cli_h2("Archives")
print(info, n = Inf, width = Inf)
cli::cli_h2("Agreement by field")
summary |>
  summarize(
    compared = sum(compared), mismatches = sum(mismatches),
    divergences = sum(divergences),
    .by = c("year", "field")
  ) |>
  mutate(match_rate = 1 - mismatches / compared) |>
  print(n = Inf)
cli::cli_inform(c(
  "v" = "{nrow(mismatches)} mismatched value{?s} written to
         {.path {file.path(out_dir, 'crosscheck-mismatches.csv')}}"
))
