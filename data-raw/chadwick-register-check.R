# Check get_chadwick_register() against Retrosheet's own rosters and
# biographical file.
#
# Every player on a Retrosheet roster should be in the Chadwick register
# under his Retrosheet ID, and joining Retrosheet data to Statcast needs his
# MLBAM ID too. This script reports:
#
#   * IDs that belong to more than one person in the register.
#   * The share of people in Retrosheet's biofile (BIOFILE.TXT, every season)
#     the register knows, and the share of those with an MLBAM ID, by era.
#   * The same shares for the players on each requested season's rosters,
#     with their Baseball-Reference and FanGraphs IDs.
#   * Signs of a wrong mapping for those roster players: a roster name that
#     differs from the register's (after folding accents, case, and
#     punctuation), a season outside the register's major league playing
#     years, or a birth date in the biofile that differs from the register's.
#
# Roster players with any of these are written to
# chadwick-register-conflicts.csv in the output directory.
#
# Usage, from the package root (needs network access):
#
#   Rscript data-raw/chadwick-register-check.R [output_dir] [year ...]
#
# Defaults: a temporary directory and the 1954, 1988, 2024, and 2025
# seasons. The script uses the cached register if there is one; run
# get_chadwick_register(refresh = TRUE) first to check the current version.
#
# Contains information from the Chadwick Baseball Bureau Register
# (https://github.com/chadwickbureau/register), which is made available under
# the ODC Attribution License (http://opendatacommons.org/licenses/by/1.0/).
# The information used here was obtained free of charge from and is
# copyrighted by Retrosheet: https://www.retrosheet.org

devtools::load_all(quiet = TRUE)
library(dplyr, warn.conflicts = FALSE)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else tempdir()
years <- if (length(args) >= 2) as.integer(args[-1]) else c(1954, 1988, 2024, 2025)

register <- get_chadwick_register(retro_only = FALSE)
rosters <- get_rosters(years, verbose = FALSE)
biofile <- get_player_ids()

# get_chadwick_register() leaves out birth dates; read them from the archive
# it just cached
extracted <- retro_extract(
  file.path(cache_dir(), "chadwick-register.zip"),
  pattern = "^people-[0-9a-f]\\.csv$",
  recursive = TRUE
)
register_births <- readr::read_csv(
  extracted$files,
  col_select = c("key_retro", "birth_year", "birth_month", "birth_day"),
  col_types = readr::cols(.default = "c"),
  na = "",
  progress = FALSE
) |>
  filter(!is.na(key_retro)) |>
  transmute(
    key_retro,
    register_birth = as.Date(
      paste(birth_year, birth_month, birth_day, sep = "-"),
      format = "%Y-%m-%d"
    )
  )
unlink(extracted$dir, recursive = TRUE)

# Partial biofile dates ("02/  /1842") become NA and aren't compared
biofile_births <- biofile |>
  transmute(
    player_id,
    biofile_birth = as.Date(birth_date, format = "%m/%d/%Y")
  )

fold <- function(x) {
  x |>
    stringi::stri_trans_general("Latin-ASCII") |>
    tolower() |>
    stringr::str_remove_all("[^a-z]")
}

keys <- c(
  "key_retro", "key_mlbam", "key_bbref", "key_fangraphs", "key_uuid",
  "key_person"
)
duplicates <- tibble(
  key = keys,
  people_with_id = purrr::map_int(keys, \(k) sum(!is.na(register[[k]]))),
  duplicated_ids = purrr::map_int(keys, \(k) {
    ids <- register[[k]]
    sum(duplicated(ids[!is.na(ids)]))
  })
)

eras <- c(
  "debut before 1900", "debut 1900-1949", "debut 1950-1999", "debut 2000 on",
  "never played (managers, coaches, umpires)"
)
biofile_coverage <- biofile |>
  mutate(
    debut = as.integer(stringr::str_extract(play_debut, "[0-9]{4}$")),
    era = case_when(
      is.na(debut) ~ eras[5],
      debut < 1900 ~ eras[1],
      debut < 1950 ~ eras[2],
      debut < 2000 ~ eras[3],
      .default = eras[4]
    ),
    era = factor(era, levels = eras)
  ) |>
  left_join(register, by = c(player_id = "key_retro")) |>
  summarize(
    people = n(),
    found = sum(!is.na(key_uuid)),
    with_mlbam = sum(!is.na(key_mlbam)),
    .by = "era"
  ) |>
  arrange(era) |>
  mutate(mlbam_pct = 100 * with_mlbam / found)

# A player traded during a season is on more than one roster
roster_ids <- rosters |>
  distinct(year, player_id, .keep_all = TRUE) |>
  select("year", "player_id", "first_name", "last_name")

matched <- roster_ids |>
  left_join(register, by = c(player_id = "key_retro")) |>
  left_join(biofile_births, by = "player_id") |>
  left_join(register_births, by = c(player_id = "key_retro"))

coverage <- matched |>
  summarize(
    roster_ids = n(),
    found = sum(!is.na(key_uuid)),
    with_mlbam = sum(!is.na(key_mlbam)),
    with_bbref = sum(!is.na(key_bbref)),
    with_fangraphs = sum(!is.na(key_fangraphs)),
    births_compared = sum(!is.na(biofile_birth) & !is.na(register_birth)),
    .by = "year"
  ) |>
  mutate(
    found_pct = 100 * found / roster_ids,
    mlbam_pct = 100 * with_mlbam / found
  )

conflicts <- matched |>
  filter(!is.na(key_uuid)) |>
  mutate(
    last_name_differs = fold(last_name) != fold(name_last),
    first_name_differs = coalesce(fold(first_name) != fold(name_first), TRUE),
    outside_mlb_years = coalesce(
      year < mlb_played_first | year > mlb_played_last,
      TRUE
    ),
    birth_date_differs = coalesce(biofile_birth != register_birth, FALSE)
  ) |>
  filter(
    last_name_differs | first_name_differs | outside_mlb_years |
      birth_date_differs
  )

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
conflicts_path <- file.path(out_dir, "chadwick-register-conflicts.csv")
readr::write_csv(conflicts, conflicts_path)
readr::write_csv(coverage, file.path(out_dir, "chadwick-register-coverage.csv"))

cli::cli_h2("Duplicate IDs in the register")
print(duplicates)
cli::cli_h2("Retrosheet biofile people found in the register")
print(biofile_coverage, width = Inf)
cli::cli_h2("Roster players found in the register")
print(coverage, width = Inf)
cli::cli_h2("Roster players with a conflict, by season")
conflicts |>
  summarize(
    last_name = sum(last_name_differs),
    first_name = sum(first_name_differs),
    mlb_years = sum(outside_mlb_years),
    birth_date = sum(birth_date_differs),
    .by = "year"
  ) |>
  print()
cli::cli_inform(c(
  "v" = "{nrow(conflicts)} roster player{?s} with a conflict written to
         {.path {conflicts_path}}"
))
