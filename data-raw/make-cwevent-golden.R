# Regenerate the Chadwick golden files used by test-parse_plays.R and
# test-track_game_state.R.
#
# parse_plays() and track_game_state() are validated against cwevent, the
# Chadwick Baseball Bureau's reference implementation of the Retrosheet event
# grammar (https://github.com/chadwickbureau/chadwick, `brew install
# chadwick`). This script downloads the 1954, 2024, and 2025 postseason
# archives, extracts the World Series event files, and runs cwevent over
# them. The committed golden CSVs let the comparison tests run offline; run
# this script only to refresh them (e.g. after Retrosheet corrects
# historical data). The committed goldens were generated with Chadwick
# 0.11.0.
#
# The three seasons are chosen deliberately: 1954 exercises the older
# conventions (missing counts, sparse trajectories, unknown-fielder codes),
# 2024 exercises modern notation (pitch-level detail, replay-era modifiers),
# and 2025 adds two World Series starts by a pitcher who was also his team's
# designated hitter (Shohei Ohtani, Games 4 and 7), an 18-inning game, and
# pitch-timer codes.
#
# Fields (`cwevent -d`): game, inning, batting team, outs, scores, batter,
# responsible batter, pitcher, responsible pitcher, fielders at positions
# 2-9, runners, event text and parsed event detail, destinations, and event
# number; extended fields 33 and 39 are the balls and strikes thrown in the
# plate appearance so far.
#
# The information used here was obtained free of charge from and is
# copyrighted by Retrosheet: https://www.retrosheet.org

stopifnot(nzchar(Sys.which("cwevent")))

version <- system2("cwevent", "-h", stdout = TRUE, stderr = TRUE)
cli::cli_inform(
  "Using {grep('version', version, value = TRUE)[1]}"
)

fields <- paste(
  c(0, 2, 3, 4, 8, 9, 10, 12, 14, 16, 18:29, 34, 36:40, 43, 46:48, 50,
    58:61, 96),
  collapse = ","
)
extended <- "33,39"
fixtures <- file.path("tests", "testthat", "fixtures")

for (year in c(2025, 2024, 1954)) {
  work <- withr::local_tempdir()
  zip <- file.path(work, "post.zip")
  download.file(
    glue::glue("https://www.retrosheet.org/events/{year}post.zip"),
    zip,
    quiet = TRUE
  )
  utils::unzip(zip, exdir = work)

  eve <- glue::glue("{year}WS.EVE")
  file.copy(file.path(work, eve), file.path(fixtures, eve), overwrite = TRUE)
  withr::with_dir(work, {
    system2(
      "cwevent",
      c("-n", "-y", year, "-f", fields, "-x", extended, eve),
      stdout = file.path(work, "golden.csv")
    )
  })
  file.copy(
    file.path(work, "golden.csv"),
    file.path(fixtures, glue::glue("cwevent-{year}WS.csv")),
    overwrite = TRUE
  )
}
