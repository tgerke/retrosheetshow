#' Parse Retrosheet Play Event Notation
#'
#' Interprets the Retrosheet event notation in the `event` column returned by
#' [get_plays()] (e.g. `"S7/G56"`, `"64(1)3/GDP"`, `"K+SB2"`) and appends
#' typed columns describing each play: the event type, batting-statistic
#' flags, hit and fielding detail, modifier flags, and baserunner advancement.
#'
#' The parser follows the event grammar documented at
#' <https://www.retrosheet.org/eventfile.htm>. An event string has up to three
#' sections: the basic play, `/`-separated modifiers, and `.`-separated runner
#' advances. Compound strikeout/walk events (`K+SB2`, `W+WP`) are classified
#' by their primary event with the secondary event reflected in the
#' baserunning columns. Pickoff-caught-stealing (`POCS`) plays are classified
#' as `"caught_stealing"`, matching how they are officially scored.
#'
#' The parser works from the event string alone, without tracking game state
#' across plays, and is validated field-by-field against Chadwick's
#' `cwevent` reference implementation (see the package test suite). One
#' documented limit of string-level parsing: a runner from third scoring on
#' an error with two outs officially carries no RBI (rule 9.04(a)(3)), but
#' the out count is not knowable from the string, so the RBI is credited.
#' [track_game_state()] tracks the out count and corrects it.
#'
#' @param plays_data Tibble of plays from [get_plays()], containing at least
#'   an `event` column
#'
#' @return The input tibble with these columns appended:
#'   * `event_type`: one of `"single"`, `"double"`, `"triple"`, `"home_run"`,
#'     `"strikeout"`, `"walk"`, `"intentional_walk"`, `"hit_by_pitch"`,
#'     `"generic_out"`, `"fielders_choice"`, `"error"`, `"interference"`,
#'     `"foul_error"`, `"stolen_base"`, `"caught_stealing"`, `"pickoff"`,
#'     `"wild_pitch"`, `"passed_ball"`, `"balk"`, `"defensive_indifference"`,
#'     `"other_advance"`, `"no_play"` (`NA` if the string is unrecognized)
#'   * `is_plate_appearance`, `is_at_bat`, `is_hit`: batting-statistic flags
#'     under standard scoring rules (sacrifices and catcher's interference
#'     are plate appearances but not at bats)
#'   * `hit_value`: 0 for non-hits through 4 for a home run
#'   * `fielded_by`: the first fielder to touch the ball (position number),
#'     `NA` when not recorded
#'   * `hit_location`: Retrosheet hit location code from the modifiers
#'     (e.g. `"78"`, `"9LS"`), `NA` when not recorded
#'   * `trajectory`: `"ground"`, `"fly"`, `"line"`, or `"popup"`
#'   * `is_bunt`, `is_sac_fly`, `is_sac_hit`, `is_gdp`: modifier flags
#'   * `outs_on_play`, `runs_on_play`, `rbi`: outs recorded, runs scored, and
#'     runs batted in on the play; RBI honors explicit `(RBI)`/`(NR)` markers
#'     and otherwise follows standard scoring rules
#'   * `batter_dest`: base reached by the batter (0 = out or no advance,
#'     1-3 = base, 4 = scored)
#'   * `runner1_dest`, `runner2_dest`, `runner3_dest`: destination of the
#'     runners starting at each base, coded like `batter_dest`. These are
#'     `NA` when the play does not mention the runner: event strings only
#'     record movement, so a runner who holds is indistinguishable from an
#'     empty base without full game-state tracking.
#'
#' @examples
#' \dontrun{
#' events <- get_events(year = 2024, type = "post")
#' plays <- get_plays(events) |>
#'   parse_plays()
#'
#' # Batting outcomes are now typed columns
#' plays |>
#'   dplyr::count(event_type, sort = TRUE)
#' }
#'
#' @export
parse_plays <- function(plays_data) {
  if (!"event" %in% names(plays_data)) {
    cli::cli_abort(c(
      "{.arg plays_data} must contain an {.field event} column.",
      "i" = "Did you extract plays with {.fun get_plays} first?"
    ))
  }

  n <- nrow(plays_data)
  rows <- tibble::tibble(.row = seq_len(n))

  # "!" (exceptional play), "#"/"?" (uncertainty) can be safely ignored
  ev <- stringr::str_remove_all(plays_data$event, "[!#?]")

  # Sections: basic-play [/modifier...] [.advances]
  main <- stringr::str_extract(ev, "^[^.]*")
  adv_str <- stringr::str_remove(stringr::str_extract(ev, "\\..*$"), "^\\.")
  # the basic play ends at the first "/" outside parentheses: fielding
  # parameters like "CS2(E1/TH)" contain slashes that are not separators
  basic <- stringr::str_extract(main, "^(?:[^/(]+|\\([^)]*\\))+")
  mods_str <- substr(main, nchar(basic) + 2L, nchar(main))

  # K+event / W+event / IW+event compounds; a trailing "+"/"-" elsewhere is a
  # hard/softly-hit-ball marker
  is_compound <- stringr::str_detect(basic, "^(K|I?W)[^+]*\\+") &
    !stringr::str_detect(basic, "^WP")
  is_compound[is.na(is_compound)] <- FALSE
  secondary <- ifelse(is_compound, stringr::str_extract(basic, "(?<=\\+).*"), NA)
  primary <- ifelse(
    is_compound,
    stringr::str_extract(basic, "^[^+]+"),
    stringr::str_remove(basic, "[-+]+$")
  )

  event_type <- classify_event(primary)

  mod_info <- summarize_modifiers(mods_str, rows)

  # Advancement records: explicit advances override outs/advances implied by
  # the basic play (GDP parentheses, SB/CS/PO), which override the batter's
  # implicit advance for his event type.
  batter_out <- batter_out_on_basic(primary, event_type)
  recs <- dplyr::bind_rows(
    implicit_batter_records(event_type, batter_out),
    basic_paren_out_records(primary, rows),
    implied_runner_records(primary, secondary, rows),
    explicit_advance_records(adv_str, rows)
  ) |>
    dplyr::slice_max(
      .data$priority,
      n = 1, with_ties = FALSE,
      by = c(".row", "runner")
    )

  # runs scored on batter events carry an RBI unless marked (NR)/(NORBI) or
  # on a GDP; Retrosheet marks the exceptions (e.g. runs that score on the
  # error part of a play) explicitly
  default_rbi <- event_type %in% c(
    "single", "double", "triple", "home_run", "generic_out",
    "fielders_choice", "error", "walk", "intentional_walk", "hit_by_pitch",
    "interference"
  ) & !mod_info$is_gdp

  is_error_event <- event_type == "error" & !is.na(event_type)
  recs <- recs |>
    dplyr::mutate(
      rbi_credit = dplyr::case_when(
        .data$rbi_yes ~ TRUE,
        .data$rbi_no ~ FALSE,
        # a run that scores via an error on the advance itself carries no RBI
        .data$err_param ~ FALSE,
        # on an error event only the runner from third ordinarily scores
        # (rule 9.04(a)(3)); its two-out exception needs game state, which
        # string-level parsing does not have
        is_error_event[.data$.row] & .data$runner != "3" ~ FALSE,
        .default = default_rbi[.data$.row]
      )
    )

  totals <- recs |>
    dplyr::summarize(
      outs_on_play = sum(.data$out),
      runs_on_play = sum(.data$dest == 4L, na.rm = TRUE),
      rbi = sum(.data$dest == 4L & .data$rbi_credit, na.rm = TRUE),
      .by = ".row"
    )

  dests <- recs |>
    dplyr::filter(.data$runner %in% c("B", "1", "2", "3")) |>
    dplyr::select(".row", "runner", "dest") |>
    tidyr::pivot_wider(
      names_from = "runner",
      values_from = "dest",
      names_prefix = "dest_"
    )
  for (col in c("dest_B", "dest_1", "dest_2", "dest_3")) {
    if (!col %in% names(dests)) dests[[col]] <- NA_integer_
  }

  parsed <- rows |>
    dplyr::left_join(totals, by = ".row") |>
    dplyr::left_join(dests, by = ".row") |>
    dplyr::mutate(
      event_type = event_type,
      is_plate_appearance = event_type %in% c(
        "single", "double", "triple", "home_run", "strikeout", "walk",
        "intentional_walk", "hit_by_pitch", "generic_out", "fielders_choice",
        "error", "interference"
      ),
      is_at_bat = .data$is_plate_appearance &
        !event_type %in% c(
          "walk", "intentional_walk", "hit_by_pitch", "interference"
        ) &
        !mod_info$is_sac_fly & !mod_info$is_sac_hit,
      is_hit = event_type %in% c("single", "double", "triple", "home_run"),
      hit_value = dplyr::case_when(
        event_type == "single" ~ 1L,
        event_type == "double" ~ 2L,
        event_type == "triple" ~ 3L,
        event_type == "home_run" ~ 4L,
        .default = 0L
      ),
      # "99" codes an unknown play: no fielding credit is given
      fielded_by = dplyr::if_else(
        event_type %in% c(
          "single", "double", "triple", "home_run", "generic_out",
          "fielders_choice", "error", "foul_error"
        ) & !stringr::str_detect(primary, "^99"),
        int_or_na(stringr::str_extract(primary, "[1-9]")),
        NA_integer_
      ),
      hit_location = mod_info$hit_location,
      trajectory = mod_info$trajectory,
      is_bunt = mod_info$is_bunt,
      is_sac_fly = mod_info$is_sac_fly,
      is_sac_hit = mod_info$is_sac_hit,
      is_gdp = mod_info$is_gdp,
      outs_on_play = dplyr::coalesce(.data$outs_on_play, 0L),
      runs_on_play = dplyr::coalesce(.data$runs_on_play, 0L),
      rbi = dplyr::coalesce(.data$rbi, 0L),
      batter_dest = dplyr::coalesce(.data$dest_B, 0L)
    ) |>
    dplyr::select(
      "event_type", "is_plate_appearance", "is_at_bat", "is_hit",
      "hit_value", "fielded_by", "hit_location", "trajectory",
      "is_bunt", "is_sac_fly", "is_sac_hit", "is_gdp",
      "outs_on_play", "runs_on_play", "rbi", "batter_dest",
      runner1_dest = "dest_1", runner2_dest = "dest_2",
      runner3_dest = "dest_3"
    )

  unparsed <- sum(is.na(event_type) & !is.na(ev))
  if (unparsed > 0) {
    cli::cli_warn(
      "{unparsed} event string{?s} could not be classified; {.field event_type} is NA for {?it/them}."
    )
  }

  dplyr::bind_cols(plays_data, parsed)
}

#' Classify the basic-play token into an event type
#' @noRd
classify_event <- function(primary) {
  dplyr::case_when(
    stringr::str_detect(primary, "^NP") ~ "no_play",
    primary == "C" ~ "interference",
    stringr::str_detect(primary, "^SB") ~ "stolen_base",
    stringr::str_detect(primary, "^POCS") ~ "caught_stealing",
    stringr::str_detect(primary, "^PO") ~ "pickoff",
    stringr::str_detect(primary, "^CS") ~ "caught_stealing",
    primary == "BK" ~ "balk",
    primary == "DI" ~ "defensive_indifference",
    primary == "OA" ~ "other_advance",
    primary == "PB" ~ "passed_ball",
    primary == "WP" ~ "wild_pitch",
    stringr::str_detect(primary, "^FLE") ~ "foul_error",
    stringr::str_detect(primary, "^DGR") ~ "double",
    stringr::str_detect(primary, "^HP") ~ "hit_by_pitch",
    stringr::str_detect(primary, "^(HR|H$|H[1-9])") ~ "home_run",
    stringr::str_detect(primary, "^K") ~ "strikeout",
    primary %in% c("I", "IW") ~ "intentional_walk",
    primary == "W" ~ "walk",
    stringr::str_detect(primary, "^FC") ~ "fielders_choice",
    stringr::str_detect(primary, "^S([1-9U]|$)") ~ "single",
    stringr::str_detect(primary, "^D([1-9U]|$)") ~ "double",
    stringr::str_detect(primary, "^T([1-9U]|$)") ~ "triple",
    stringr::str_detect(primary, "^E[1-9]") ~ "error",
    stringr::str_detect(primary, "^[1-9]") &
      stringr::str_detect(primary, "E") ~ "error",
    stringr::str_detect(primary, "^[1-9]") ~ "generic_out",
    .default = NA_character_
  )
}

#' Is the batter out on the basic play itself?
#'
#' For fielded outs, the batter is out unless the play consists solely of
#' outs on parenthesized runners (a force out / fielder's choice, e.g.
#' "54(1)"). "64(1)3" retires the batter at first after the runner; "(B)"
#' marks the batter explicitly.
#' @noRd
batter_out_on_basic <- function(primary, event_type) {
  has_paren <- stringr::str_detect(primary, "\\(")
  dplyr::case_when(
    event_type == "strikeout" ~ TRUE,
    event_type != "generic_out" ~ FALSE,
    !has_paren ~ TRUE,
    stringr::str_detect(primary, "\\(B\\)") ~ TRUE,
    stringr::str_detect(primary, "\\)[1-9]+$") ~ TRUE,
    .default = FALSE
  )
}

#' The batter advance implied by the event type (lowest priority)
#' @noRd
implicit_batter_records <- function(event_type, batter_out) {
  dest <- dplyr::case_when(
    event_type == "single" ~ 1L,
    event_type == "double" ~ 2L,
    event_type == "triple" ~ 3L,
    event_type == "home_run" ~ 4L,
    event_type %in% c(
      "walk", "intentional_walk", "hit_by_pitch", "interference",
      "error", "fielders_choice"
    ) ~ 1L,
    event_type == "strikeout" ~ 0L,
    event_type == "generic_out" & batter_out ~ 0L,
    event_type == "generic_out" ~ 1L,
    .default = NA_integer_
  )
  tibble::tibble(
    .row = seq_along(event_type),
    runner = "B",
    dest = dest,
    out = batter_out & !is.na(dest),
    rbi_yes = FALSE,
    rbi_no = FALSE,
    err_param = FALSE,
    priority = 0L
  ) |>
    dplyr::filter(!is.na(.data$dest))
}

#' Outs on parenthesized runners in a fielded basic play, e.g. "64(1)3"
#' @noRd
basic_paren_out_records <- function(primary, rows) {
  fielded <- stringr::str_detect(primary, "^[1-9]") |
    stringr::str_detect(primary, "^E[1-9]")
  fielded[is.na(fielded)] <- FALSE
  outs <- rep(list(character()), nrow(rows))
  outs[fielded] <- stringr::str_extract_all(
    primary[fielded], "(?<=\\()[B123](?=\\))"
  )
  rows |>
    dplyr::mutate(runner = outs) |>
    tidyr::unnest_longer("runner") |>
    dplyr::mutate(
      runner = as.character(.data$runner),
      dest = 0L,
      out = TRUE,
      rbi_yes = FALSE,
      rbi_no = FALSE,
      err_param = FALSE,
      priority = 1L
    )
}

#' Runner movement implied by SB/CS/POCS/PO basic or secondary events
#' @noRd
implied_runner_records <- function(primary, secondary, rows) {
  base_before <- c("2" = "1", "3" = "2", "H" = "3")

  toks <- dplyr::bind_rows(
    rows |> dplyr::mutate(tok = primary),
    rows |> dplyr::mutate(tok = secondary)
  ) |>
    dplyr::filter(!is.na(.data$tok)) |>
    tidyr::separate_longer_delim("tok", ";") |>
    dplyr::filter(stringr::str_detect(.data$tok, "^(SB|CS|POCS|PO)[123H]"))

  toks |>
    dplyr::mutate(
      code = stringr::str_extract(.data$tok, "^(SB|CS|POCS|PO)"),
      base = stringr::str_extract(.data$tok, "(?<=^SB|^CS|^POCS|^PO)[123H]"),
      params = stringr::str_extract(.data$tok, "\\(.*"),
      negated = out_negated_by_error(.data$params),
      runner = dplyr::if_else(
        .data$code == "PO", .data$base, base_before[.data$base]
      ),
      out = .data$code != "SB" & !.data$negated,
      # when an error negates the out, CS/POCS runners reach the target base
      # and picked-off runners hold, unless an explicit advance says otherwise
      dest = dplyr::case_when(
        .data$out ~ 0L,
        .data$base == "H" ~ 4L,
        .default = int_or_na(.data$base)
      ),
      rbi_yes = FALSE,
      rbi_no = FALSE,
      err_param = FALSE,
      priority = 2L
    ) |>
    dplyr::select(
      ".row", "runner", "dest", "out", "rbi_yes", "rbi_no", "err_param",
      "priority"
    )
}

#' Explicit advance records from the "." section (highest priority)
#' @noRd
explicit_advance_records <- function(adv_str, rows) {
  rows |>
    dplyr::mutate(adv = adv_str) |>
    dplyr::filter(!is.na(.data$adv)) |>
    tidyr::separate_longer_delim("adv", ";") |>
    dplyr::filter(
      stringr::str_detect(.data$adv, "^[B123][-X][123H]")
    ) |>
    dplyr::mutate(
      runner = stringr::str_sub(.data$adv, 1, 1),
      to = stringr::str_sub(.data$adv, 3, 3),
      params = stringr::str_extract(.data$adv, "\\(.*"),
      out = stringr::str_sub(.data$adv, 2, 2) == "X" &
        !out_negated_by_error(.data$params),
      dest = dplyr::case_when(
        .data$out ~ 0L,
        .data$to == "H" ~ 4L,
        .default = int_or_na(.data$to)
      ),
      rbi_yes = !is.na(.data$params) &
        stringr::str_detect(.data$params, "\\(RBI\\)"),
      rbi_no = !is.na(.data$params) &
        stringr::str_detect(.data$params, "\\(NO?RBI\\)|\\(NR\\)"),
      err_param = !is.na(.data$params) &
        stringr::str_detect(.data$params, "E"),
      priority = 3L
    ) |>
    dplyr::select(
      ".row", "runner", "dest", "out", "rbi_yes", "rbi_no", "err_param",
      "priority"
    )
}

#' Does an error in the advance parameters negate the out?
#'
#' An "X" advance with an error parameter means the runner is safe
#' ("BX2(7E4)"), unless a separate parenthesized fielding string without an
#' error records a putout ("1XH(82)(E2/TH)": the out stands, the error is
#' charged on other action).
#' @noRd
out_negated_by_error <- function(params) {
  purrr::map_lgl(
    stringr::str_extract_all(
      dplyr::coalesce(params, ""), "(?<=\\()[^)]*(?=\\))"
    ),
    function(groups) {
      has_e <- stringr::str_detect(groups, "E")
      any(has_e) && !any(stringr::str_detect(groups, "^[1-9]") & !has_e)
    }
  )
}

#' Per-play modifier summaries: flags, trajectory, and hit location
#' @noRd
summarize_modifiers <- function(mods_str, rows) {
  traj_re <- "^(BG|BP|BL|G|F|L|P)([1-9][0-9SMLDXFW]*)?$"
  loc_re <- "^[1-9][0-9SMLDXFW]*$"

  per_row <- rows |>
    dplyr::mutate(mod = mods_str) |>
    dplyr::filter(!is.na(.data$mod), .data$mod != "") |>
    tidyr::separate_longer_delim("mod", "/") |>
    dplyr::mutate(mod = stringr::str_remove(.data$mod, "[-+]+$")) |>
    dplyr::filter(.data$mod != "") |>
    dplyr::summarize(
      # a sacrifice hit is a bunt by definition; BF is a foul bunt
      is_bunt = any(stringr::str_detect(.data$mod, "^B[GPLF]|^SH")),
      is_sac_fly = any(stringr::str_detect(.data$mod, "^SF")),
      is_sac_hit = any(stringr::str_detect(.data$mod, "^SH")),
      is_gdp = any(stringr::str_detect(.data$mod, "^B?GDP")),
      traj_mod = .data$mod[stringr::str_detect(.data$mod, traj_re)][1],
      loc_mod = .data$mod[stringr::str_detect(.data$mod, loc_re)][1],
      .by = ".row"
    )

  rows |>
    dplyr::left_join(per_row, by = ".row") |>
    dplyr::mutate(
      is_bunt = dplyr::coalesce(.data$is_bunt, FALSE),
      is_sac_fly = dplyr::coalesce(.data$is_sac_fly, FALSE),
      is_sac_hit = dplyr::coalesce(.data$is_sac_hit, FALSE),
      is_gdp = dplyr::coalesce(.data$is_gdp, FALSE),
      traj_code = stringr::str_extract(.data$traj_mod, "^(BG|BP|BL|G|F|L|P)"),
      trajectory = dplyr::case_when(
        .data$traj_code %in% c("G", "BG") ~ "ground",
        .data$traj_code %in% c("P", "BP") ~ "popup",
        .data$traj_code %in% c("L", "BL") ~ "line",
        .data$traj_code == "F" ~ "fly",
        .default = NA_character_
      ),
      hit_location = dplyr::coalesce(
        dplyr::na_if(
          stringr::str_remove(.data$traj_mod, "^(BG|BP|BL|G|F|L|P)"), ""
        ),
        .data$loc_mod
      )
    )
}
