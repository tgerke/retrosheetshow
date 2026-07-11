# Regenerate the Chadwick golden files used by test-parse_plays.R.
#
# parse_plays() is validated against cwevent, the Chadwick Baseball Bureau's
# reference implementation of the Retrosheet event grammar
# (https://github.com/chadwickbureau/chadwick, `brew install chadwick`).
# This script downloads the 2024 and 1954 postseason archives, extracts the
# World Series event files, and runs cwevent over them. The committed golden
# CSVs let the comparison test run offline; run this script only to refresh
# them (e.g. after Retrosheet corrects historical data).
#
# The two seasons are chosen deliberately: 2024 exercises modern notation
# (pitch-level detail, replay-era modifiers), 1954 exercises the older
# conventions (missing counts, sparse trajectories, unknown-fielder codes).
#
# The information used here was obtained free of charge from and is
# copyrighted by Retrosheet: https://www.retrosheet.org

stopifnot(nzchar(Sys.which("cwevent")))

fields <- "0,2,3,4,8,9,10,26,27,28,29,34,36,37,38,39,40,43,46,47,48,50,58,59,60,61,96"
fixtures <- file.path("tests", "testthat", "fixtures")

for (year in c(2024, 1954)) {
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
      c("-n", "-y", year, "-f", fields, eve),
      stdout = file.path(work, "golden.csv")
    )
  })
  file.copy(
    file.path(work, "golden.csv"),
    file.path(fixtures, glue::glue("cwevent-{year}WS.csv")),
    overwrite = TRUE
  )
}
