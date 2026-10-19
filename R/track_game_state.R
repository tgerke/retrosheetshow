#' Track Game State Through Play-by-Play Events
#'
#' Replays every game's records in order to reconstruct the situation before
#' each play: the number of outs, the runners on base (with player
#' identities), the score, and the defense on the field. This is the state
#' that situational analysis conditions on -- base-out states, run
#' expectancy, leverage.
#'
#' The tracker consumes the full record stream from [get_events()], not just
#' the play records: `start`/`sub` records maintain each team's lineup and
#' fielding positions, so pinch runners replace the correct runner on base
#' and every play knows its pitcher and fielders. `radj` records place the
#' automatic runner that begins extra innings from 2020 onward. Plays are
#' parsed with [parse_plays()] and runner destinations drive the base-state
#' transitions; a runner not mentioned by a play holds his base.
#'
#' Fielders are tracked by position: each `start` or `sub` record puts its
#' player at the position it names, which covers double switches, players
#' changing positions, and pinch hitters or runners who stay in the game on
#' defense. A starting pitcher who is also the designated hitter (allowed
#' from 2022) holds both roles until a relief pitcher replaces him on the
#' mound.
#'
#' ## Responsible pitcher and batter
#'
#' When a pitcher or batter is replaced in the middle of a plate appearance,
#' the official scoring rules can charge the outcome to the player who left.
#' A walk is charged to the departed pitcher if the batter was ahead 2-0,
#' 2-1, 3-0, 3-1, or 3-2 when the reliever entered (rule 9.16(h)); a
#' strikeout is charged to the departed batter if he left with two strikes
#' (rule 9.15(b)). The count at the change is the one on the play record
#' preceding the substitution. When that count is unknown (`??`, common in
#' older files), the reliever or pinch hitter is charged.
#'
#' ## Pitch counts
#'
#' Pitch counts use [count_pitches()] and need pitch sequences, which only
#' some games have; the game's `info,pitches` record says which (see
#' [get_game_info()]). In games without them both pitch-count columns are
#' `NA`. Within a game that has them, a completed plate appearance with no
#' sequence is a gap in the data: its count is `NA`, and so is the
#' pitcher's running total from then on.
#'
#' Knowing the out count also closes the one RBI gap in string-level parsing:
#' the `rbi` column returned here removes the credit when a runner from third
#' scores on an error with two outs (rule 9.04(a)(3)), unless the file marks
#' `(RBI)` explicitly.
#'
#' @param events_data Tibble from [get_events()] containing the raw records
#'   (`record_type`, `f1`-`f6`, `line_number`)
#'
#' @return One row per play record, in file order: the columns of
#'   [get_plays()] and [parse_plays()], plus the pre-play state:
#'   * `outs_before`: outs when the play began (0-2)
#'   * `runner1_id`, `runner2_id`, `runner3_id`: Retrosheet player ids of the
#'     runners on first, second, and third (`NA` for an empty base)
#'   * `bat_score`, `fld_score`: runs already scored by the batting and
#'     fielding teams
#'   * `pitcher_id`: the pitcher on the mound
#'   * `resp_pitcher_id`: the pitcher charged with the play; differs from
#'     `pitcher_id` only for a walk after a mid-count pitching change (rule
#'     9.16(h))
#'   * `resp_batter_id`: the batter charged with the play; differs from
#'     `player_id` only for a strikeout after a two-strike pinch hitter
#'     (rule 9.15(b))
#'   * `fielder2_id` through `fielder9_id`: the fielders at positions 2
#'     (catcher) through 9 (right field)
#'   * `pitches_on_play`: pitches thrown during this record. Every record of
#'     a plate appearance repeats the pitches before it, so only the new ones
#'     are counted, and summing over a pitcher's records gives his total.
#'   * `pitch_count_before`: pitches the current pitcher had thrown in the
#'     game before this record
#'
#' @examples
#' \dontrun{
#' states <- get_events(year = 2024, type = "post") |>
#'   track_game_state()
#'
#' # the eight base states by out count
#' states |>
#'   dplyr::count(
#'     outs_before,
#'     bases = paste0(
#'       ifelse(is.na(runner1_id), "-", "1"),
#'       ifelse(is.na(runner2_id), "-", "2"),
#'       ifelse(is.na(runner3_id), "-", "3")
#'     )
#'   )
#'
#' # pitches thrown by each pitcher in each game
#' states |>
#'   dplyr::summarize(
#'     pitches = sum(pitches_on_play),
#'     .by = c(game_id, pitcher_id)
#'   )
#' }
#'
#' @export
track_game_state <- function(events_data) {
  required <- c("game_id", "record_type", "line_number")
  missing <- setdiff(required, names(events_data))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{.arg events_data} must contain {.field {required}}.",
      "i" = "Pass the tibble returned by {.fun get_events}."
    ))
  }

  plays <- get_plays(events_data)
  # with no play records the f-columns (and thus `event`) are absent
  if (!"event" %in% names(plays)) plays$event <- character()
  plays <- parse_plays(plays)

  if (nrow(plays) == 0) {
    return(dplyr::bind_cols(
      plays,
      state_columns(walk_game_state(NULL, 0L), integer(), integer())
    ))
  }

  empty_lineup <- tibble::tibble(
    game_id = character(), line_number = integer(), player_id = character(),
    team = integer(), batting_order = integer(), position = integer()
  )
  lineup_recs <- events_data |>
    dplyr::filter(.data$record_type %in% c("start", "sub")) |>
    parse_event_records() |>
    dplyr::bind_rows(empty_lineup)
  radj_recs <- events_data |>
    dplyr::filter(.data$record_type == "radj") |>
    dplyr::bind_rows(
      tibble::tibble(
        game_id = character(), line_number = integer(),
        f1 = character(), f2 = character()
      )
    )

  balls <- int_or_na(substr(plays$count, 1, 1))
  strikes <- int_or_na(substr(plays$count, 2, 2))

  stream <- dplyr::bind_rows(
    plays |>
      dplyr::mutate(
        .idx = dplyr::row_number(),
        # rule 9.16(h)(1): the counts at which a walk stays with the
        # departing pitcher
        walk_count = (balls %in% 2L & strikes %in% 0:1) |
          (balls %in% 3L & strikes %in% 0:2),
        two_strikes = strikes %in% 2L,
        is_walk = .data$event_type %in% c("walk", "intentional_walk"),
        is_strikeout = .data$event_type %in% "strikeout",
        is_no_play = .data$event_type %in% "no_play"
      ) |>
      dplyr::select(
        "game_id", "line_number", ".idx", "team", "inning", "player_id",
        "batter_dest", "runner1_dest", "runner2_dest", "runner3_dest",
        "outs_on_play", "runs_on_play", "is_plate_appearance",
        "walk_count", "two_strikes", "is_walk", "is_strikeout", "is_no_play"
      ) |>
      dplyr::mutate(kind = 1L),
    lineup_recs |>
      dplyr::select(
        "game_id", "line_number", "player_id", "team",
        "batting_order", "position"
      ) |>
      dplyr::mutate(kind = 2L),
    radj_recs |>
      dplyr::transmute(
        .data$game_id, .data$line_number,
        player_id = .data$f1,
        radj_base = int_or_na(.data$f2),
        kind = 3L
      )
  ) |>
    dplyr::arrange(.data$game_id, .data$line_number)

  walked <- walk_game_state(stream, nrow(plays))

  if (walked$phantom > 0) {
    cli::cli_warn(c(
      "{walked$phantom} play{?s} moved a runner from a base the tracker
       believed empty.",
      "i" = "State columns may be unreliable for the affected games."
    ))
  }
  if (walked$misaligned > 0) {
    cli::cli_warn(c(
      "{walked$misaligned} defensive alignment{?s} had a vacant position or
       one player at two positions.",
      "i" = "Fielder columns may be unreliable for the affected games."
    ))
  }

  pitches <- pitch_counts(plays, walked$pitcher, events_data)
  if (pitches$broken > 0) {
    cli::cli_warn(c(
      "{pitches$broken} play record{?s} had fewer pitches than the previous
       record of the same plate appearance.",
      "i" = "Their pitch counts, and the pitcher's later running totals in
             that game, are {.val NA}."
    ))
  }

  out <- dplyr::bind_cols(
    plays,
    state_columns(walked, pitches$on_play, pitches$count_before)
  )

  # rule 9.04(a)(3): no RBI for a runner from third scoring on an error with
  # two outs; parse_plays() cannot know the out count, so correct it here.
  # An explicit (RBI) or an error on the advance itself already decided it.
  third_entry <- stringr::str_extract(out$event, "3-H[^;.]*")
  correct <- out$event_type == "error" &
    !is.na(out$event_type) &
    out$outs_before == 2L &
    !is.na(out$runner3_dest) & out$runner3_dest == 4L &
    !is.na(third_entry) &
    !stringr::str_detect(third_entry, "E|\\(RBI\\)") &
    out$rbi > 0L
  out$rbi[correct] <- out$rbi[correct] - 1L

  out
}

#' Single ordered pass over the merged record stream
#'
#' Sequential by nature: each play's pre-state depends on every record
#' before it. Runs in a few seconds per season.
#' @noRd
walk_game_state <- function(stream, n_plays) {
  g <- stream$game_id
  kind <- stream$kind
  idx <- stream$.idx
  team <- stream$team
  inning <- stream$inning
  pid <- stream$player_id
  b_dest <- stream$batter_dest
  r_dest <- cbind(
    stream$runner1_dest, stream$runner2_dest, stream$runner3_dest
  )
  outs_play <- stream$outs_on_play
  runs_play <- stream$runs_on_play
  ends_pa <- stream$is_plate_appearance
  walk_count <- stream$walk_count
  two_strikes <- stream$two_strikes
  is_walk <- stream$is_walk
  is_strikeout <- stream$is_strikeout
  is_no_play <- stream$is_no_play
  order <- stream$batting_order
  pos <- stream$position
  radj_base <- stream$radj_base

  st_outs <- integer(n_plays)
  st_r <- matrix(NA_character_, nrow = n_plays, ncol = 3)
  st_bat <- integer(n_plays)
  st_fld <- integer(n_plays)
  st_pit <- rep(NA_character_, n_plays)
  st_resp_pit <- rep(NA_character_, n_plays)
  st_resp_bat <- rep(NA_character_, n_plays)
  st_def <- matrix(NA_character_, nrow = n_plays, ncol = 8)

  cur_game <- ""
  cur_inning <- -1L
  cur_team <- -1L
  bases <- rep(NA_character_, 3)
  pending <- rep(NA_character_, 3)
  outs <- 0L
  score <- c(0L, 0L)
  lineup <- character()
  phantom <- 0L
  # fielders by team (row 1 visitors, row 2 home) and position (columns 1-9)
  fld <- matrix(NA_character_, nrow = 2, ncol = 9)
  fld_changed <- c(TRUE, TRUE)
  misaligned <- 0L
  # where the current plate appearance stands, for substitutions made during
  # it: the count and batter on its latest record, and who would be charged
  pa_open <- FALSE
  pa_walk_count <- FALSE
  pa_two_strikes <- FALSE
  pa_batter <- NA_character_
  walk_pitcher <- NA_character_
  k_batter <- NA_character_

  for (i in seq_along(g)) {
    if (g[i] != cur_game) {
      cur_game <- g[i]
      cur_inning <- -1L
      cur_team <- -1L
      bases[] <- NA_character_
      pending[] <- NA_character_
      outs <- 0L
      score <- c(0L, 0L)
      lineup <- character()
      fld[] <- NA_character_
      fld_changed[] <- TRUE
      pa_open <- FALSE
      walk_pitcher <- NA_character_
      k_batter <- NA_character_
    }

    k <- kind[i]
    if (k == 2L) {
      ps <- pos[i]
      tm <- team[i] + 1L
      if (pa_open && !is.na(ps)) {
        if (ps == 1L && team[i] != cur_team) {
          # rule 9.16(h): judged on the count at each change
          walk_pitcher <- if (pa_walk_count) fld[tm, 1L] else NA_character_
        } else if (ps == 11L && team[i] == cur_team && pa_two_strikes &&
                   is.na(k_batter)) {
          # rule 9.15(b): the strikeout goes to the first two-strike batter
          k_batter <- pa_batter
        }
      }
      key <- paste0(team[i], ".", order[i])
      if (!is.na(ps) && ps == 12L) {
        prev <- lineup[key]
        if (length(prev) == 1 && !is.na(prev)) {
          b <- match(prev, bases)
          if (!is.na(b)) {
            bases[b] <- pid[i]
          } else {
            p <- match(prev, pending)
            if (!is.na(p)) pending[p] <- pid[i]
          }
        }
      }
      lineup[key] <- pid[i]
      if (!is.na(ps) && ps >= 1L && ps <= 9L) {
        fld[tm, ps] <- pid[i]
        fld_changed[tm] <- TRUE
      }
    } else if (k == 3L) {
      # automatic extra-inning runner: takes effect when the half begins
      if (!is.na(radj_base[i]) && radj_base[i] %in% 1:3) {
        pending[radj_base[i]] <- pid[i]
      }
    } else {
      if (inning[i] != cur_inning || team[i] != cur_team) {
        cur_inning <- inning[i]
        cur_team <- team[i]
        outs <- 0L
        bases[] <- NA_character_
        walk_pitcher <- NA_character_
        k_batter <- NA_character_
      }
      if (any(!is.na(pending))) {
        place <- !is.na(pending)
        bases[place] <- pending[place]
        pending[] <- NA_character_
      }

      j <- idx[i]
      st_outs[j] <- outs
      st_r[j, ] <- bases
      st_bat[j] <- score[team[i] + 1L]
      st_fld[j] <- score[2L - team[i]]

      # substitutions can pass through incomplete alignments between NP
      # records, so audit only once a real play is made
      ft <- 2L - team[i]
      if (fld_changed[ft] && !is_no_play[i]) {
        if (anyNA(fld[ft, ]) || anyDuplicated(fld[ft, ]) > 0L) {
          misaligned <- misaligned + 1L
        }
        fld_changed[ft] <- FALSE
      }
      st_pit[j] <- fld[ft, 1L]
      st_resp_pit[j] <- if (is_walk[i] && !is.na(walk_pitcher)) {
        walk_pitcher
      } else {
        fld[ft, 1L]
      }
      st_resp_bat[j] <- if (is_strikeout[i] && !is.na(k_batter)) {
        k_batter
      } else {
        pid[i]
      }
      st_def[j, ] <- fld[ft, -1L]

      new_bases <- bases
      for (b in 1:3) {
        d <- r_dest[i, b]
        if (!is.na(d)) {
          if (is.na(bases[b])) phantom <- phantom + 1L
          new_bases[b] <- NA_character_
        }
      }
      for (b in 1:3) {
        d <- r_dest[i, b]
        if (!is.na(d) && d >= 1L && d <= 3L) {
          new_bases[d] <- bases[b]
        }
      }
      if (b_dest[i] >= 1L && b_dest[i] <= 3L) {
        new_bases[b_dest[i]] <- pid[i]
      }
      bases <- new_bases
      outs <- outs + outs_play[i]
      score[team[i] + 1L] <- score[team[i] + 1L] + runs_play[i]

      if (ends_pa[i]) {
        pa_open <- FALSE
        walk_pitcher <- NA_character_
        k_batter <- NA_character_
      } else {
        pa_open <- TRUE
        pa_walk_count <- walk_count[i]
        pa_two_strikes <- two_strikes[i]
        pa_batter <- pid[i]
      }
    }
  }

  list(
    outs = st_outs,
    r1 = st_r[, 1], r2 = st_r[, 2], r3 = st_r[, 3],
    bat_score = st_bat, fld_score = st_fld,
    pitcher = st_pit, resp_pitcher = st_resp_pit, resp_batter = st_resp_bat,
    fielders = st_def,
    phantom = phantom, misaligned = misaligned
  )
}

#' Pitches thrown on each play record and the pitcher's running total
#'
#' A plate appearance spanning several records (a stolen base, a pitching
#' change) repeats its earlier pitches in each one, `B` then `B.CBSX`, so a
#' record's own pitches are its total minus the previous record's. The
#' comparison is by count, not string: older files re-annotate markers,
#' pickoffs, and pitch types between records (`BBN` then `BB.CBSS`, `Q` then
#' `P.CBCX`), and often leave the sequence off an NP record in mid plate
#' appearance entirely.
#' @noRd
pitch_counts <- function(plays, pitcher, events_data) {
  n <- nrow(plays)
  info <- events_data[
    events_data$record_type == "info" & events_data$f1 %in% "pitches",
  ]
  has_sequences <- plays$game_id %in% info$game_id[info$f2 %in% "pitches"]

  # get_events() stores an empty sequence (no pitches yet) as NA
  sequence <- dplyr::coalesce(plays$pitches, "")
  total <- count_pitches(sequence)

  continues_pa <- c(
    FALSE,
    plays$game_id[-1] == plays$game_id[-n] &
      plays$inning[-1] == plays$inning[-n] &
      plays$team[-1] == plays$team[-n] &
      !plays$is_plate_appearance[-n]
  ) %in% TRUE
  pa <- cumsum(!continues_pa)

  # a record in mid plate appearance with no pitches on it adds nothing; the
  # next record is compared with the last one that had pitches
  blank <- total == 0L & !plays$is_plate_appearance
  base <- c(0L, cummax(ifelse(blank, 0L, seq_len(n)))[-n])
  has_base <- base > 0L & pa[pmax(base, 1L)] == pa
  prev_total <- ifelse(has_base, total[pmax(base, 1L)], 0L)

  # even automatic outcomes are coded (VVVV, A), so a completed plate
  # appearance with no sequence is a gap in the data, not zero pitches
  missing <- plays$is_plate_appearance & sequence == ""
  broken <- !blank & !missing & total < prev_total

  on_play <- ifelse(blank, 0L, total - prev_total)
  on_play[!has_sequences | missing | broken] <- NA_integer_
  # one pasted key: ave() crosses multiple grouping vectors into every
  # game x pitcher combination
  count_before <- stats::ave(
    on_play, paste(plays$game_id, pitcher),
    FUN = function(x) c(0L, cumsum(x)[-length(x)])
  )
  count_before[!has_sequences] <- NA_integer_

  list(
    on_play = on_play,
    count_before = count_before,
    broken = sum(has_sequences & broken)
  )
}

#' Assemble the state columns appended to the plays
#' @noRd
state_columns <- function(walked, pitches_on_play, pitch_count_before) {
  fielders <- walked$fielders
  colnames(fielders) <- paste0("fielder", 2:9, "_id")
  dplyr::bind_cols(
    tibble::tibble(
      outs_before = walked$outs,
      runner1_id = walked$r1,
      runner2_id = walked$r2,
      runner3_id = walked$r3,
      bat_score = walked$bat_score,
      fld_score = walked$fld_score,
      pitcher_id = walked$pitcher,
      resp_pitcher_id = walked$resp_pitcher,
      resp_batter_id = walked$resp_batter
    ),
    tibble::as_tibble(fielders),
    tibble::tibble(
      pitches_on_play = pitches_on_play,
      pitch_count_before = pitch_count_before
    )
  )
}
