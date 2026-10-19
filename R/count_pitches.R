#' Count Pitches in Retrosheet Pitch Sequences
#'
#' Counts the pitches thrown in the `pitches` strings returned by
#' [get_plays()], following the pitch codes documented at
#' <https://www.retrosheet.org/eventfile.htm>.
#'
#' Every code for a pitch thrown counts: balls (`B`), strikes called,
#' swinging, foul, foul-tipped, or of unknown type (`C`, `S`, `F`, `T`, `K`),
#' bunt attempts (`L`, `M`, `O`), pitchouts (`P`, `Q`, `R`, `Y`), intentional
#' balls (`I`), hit batters (`H`), balls put in play (`X`), and unknown or
#' missed pitches (`U`). Pickoff throws (`1`, `2`, `3`, with `+` marking a
#' catcher's throw), the markers `*`, `>`, and `.`, no-pitch calls on balks
#' and interference (`N`), and automatic strikes and balls (`A`, `V`: pitch
#' timer violations, intentional walks since 2017, a pitcher going to his
#' mouth) do not.
#'
#' Chadwick's `cwevent` leaves `U` out of its counts of balls and strikes
#' thrown, since it cannot say which one the pitch was; it is still a pitch.
#'
#' Within a plate appearance, each play record repeats the pitches of the
#' records before it, so summing `count_pitches()` over play records counts
#' some pitches more than once. [track_game_state()] returns per-record and
#' running pitch counts that handle this.
#'
#' Most Retrosheet games have no pitch sequences. The `pitches` field from
#' [get_game_info()] says whether a game has them (`"pitches"`) or records
#' only the count (`"count"`) or neither (`"none"`). [get_events()] stores
#' an empty sequence as `NA`, and `count_pitches()` returns `NA` for it
#' rather than guess between "no pitches yet" and "not recorded".
#'
#' @param pitches Character vector of Retrosheet pitch sequences
#'
#' @return Integer vector of pitch counts, `NA` where `pitches` is `NA`
#'
#' @examples
#' count_pitches(c("BBSF1*BS", "C1>*B", "..CCBFX", "VVVV", "", NA))
#'
#' @export
count_pitches <- function(pitches) {
  if (!is.character(pitches) && !all(is.na(pitches))) {
    cli::cli_abort("{.arg pitches} must be a character vector.")
  }
  pitches <- as.character(pitches)

  unknown <- stringr::str_detect(
    pitches, paste0("[^", thrown_codes, "+*.>123NAV]")
  )
  n_unknown <- sum(unknown, na.rm = TRUE)
  if (n_unknown > 0) {
    cli::cli_warn(c(
      "{n_unknown} pitch sequence{?s} contain{?s/} characters that are not
       Retrosheet pitch codes.",
      "i" = "Only documented pitch codes are counted."
    ))
  }

  stringr::str_count(pitches, paste0("[", thrown_codes, "]"))
}

#' Retrosheet pitch codes for a pitch actually thrown
#' @noRd
thrown_codes <- "BCFHIKLMOPQRSTUXY"
