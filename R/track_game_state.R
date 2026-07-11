#' Track Game State Through Play-by-Play Events
#'
#' Replays every game's records in order to reconstruct the situation before
#' each play: the number of outs, the runners on base (with player
#' identities), and the score. This is the state that situational analysis
#' conditions on -- base-out states, run expectancy, leverage.
#'
#' The tracker consumes the full record stream from [get_events()], not just
#' the play records: `start`/`sub` records maintain each team's lineup so
#' pinch runners replace the correct runner on base, and `radj` records place
#' the automatic runner that begins extra innings from 2020 onward. Plays are
#' parsed with [parse_plays()] and runner destinations drive the base-state
#' transitions; a runner not mentioned by a play holds his base.
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

  state_cols <- tibble::tibble(
    outs_before = integer(nrow(plays)),
    runner1_id = NA_character_,
    runner2_id = NA_character_,
    runner3_id = NA_character_,
    bat_score = integer(nrow(plays)),
    fld_score = integer(nrow(plays))
  )
  if (nrow(plays) == 0) {
    return(dplyr::bind_cols(plays, state_cols[0, ]))
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

  stream <- dplyr::bind_rows(
    plays |>
      dplyr::mutate(.idx = dplyr::row_number()) |>
      dplyr::select(
        "game_id", "line_number", ".idx", "team", "inning", "player_id",
        "batter_dest", "runner1_dest", "runner2_dest", "runner3_dest",
        "outs_on_play", "runs_on_play"
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

  out <- dplyr::bind_cols(
    plays,
    tibble::tibble(
      outs_before = walked$outs,
      runner1_id = walked$r1,
      runner2_id = walked$r2,
      runner3_id = walked$r3,
      bat_score = walked$bat_score,
      fld_score = walked$fld_score
    )
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
  order <- stream$batting_order
  pos <- stream$position
  radj_base <- stream$radj_base

  st_outs <- integer(n_plays)
  st_r <- matrix(NA_character_, nrow = n_plays, ncol = 3)
  st_bat <- integer(n_plays)
  st_fld <- integer(n_plays)

  cur_game <- ""
  cur_inning <- -1L
  cur_team <- -1L
  bases <- rep(NA_character_, 3)
  pending <- rep(NA_character_, 3)
  outs <- 0L
  score <- c(0L, 0L)
  lineup <- character()
  phantom <- 0L

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
    }

    k <- kind[i]
    if (k == 2L) {
      key <- paste0(team[i], ".", order[i])
      if (!is.na(pos[i]) && pos[i] == 12L) {
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
    }
  }

  list(
    outs = st_outs,
    r1 = st_r[, 1], r2 = st_r[, 2], r3 = st_r[, 3],
    bat_score = st_bat, fld_score = st_fld,
    phantom = phantom
  )
}
