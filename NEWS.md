# retrosheetshow 0.0.0.9000 (development version)

## New features

* New `parse_plays()` interprets Retrosheet event notation into typed,
  analysis-ready columns: event type, plate-appearance/at-bat/hit flags,
  hit value, fielding and trajectory detail, modifier flags, and outs,
  runs, RBI, and per-runner advancement. The parser follows the published
  event grammar and is validated field-by-field against Chadwick's
  `cwevent` on committed World Series golden files, with full-season
  cross-checks covering about 283,000 events from 1954 and 2024.
* New vignette "Analyzing Play-by-Play Data" builds batting lines,
  count-based splits, and a 1954 World Series reconstruction from parsed
  plays.

## Breaking changes

* `get_events()` now returns the record fields in wide character columns
  `f1`-`f6` instead of a `fields` list-column. `parse_event_records()`,
  `get_plays()`, and `get_game_info()` work as before but run vectorized
  and are much faster.
* `list_events()`, `list_gamelogs()`, and `list_schedules()` no longer
  return the `available` column (it was constant `TRUE` because
  unavailable files are filtered out).

## Bug fixes

* `get_events()` no longer duplicates every record when the same year is
  requested with more than one `type`; the event type now travels with each
  file's records instead of being joined back by year.
* Archives are extracted into a fresh per-call directory. Previously all
  functions shared `tempdir()` with partial cleanup, so records from one
  call could silently leak into a later call's results.
* Event files are parsed with a quote-aware CSV reader, so `com` records
  containing quoted commas stay intact.
* `get_schedules()` works again: Retrosheet moved schedules to
  `{year}SKED.zip` archives containing a headered CSV (the old
  `{year}SKED.TXT` endpoint returns 404). Both the historical 12-column and
  current 13-column layouts (which add `location`) parse to one schema.
* `get_player_ids()` works again: the biofile moved to `BIOFILE.TXT` and
  has a 33-field headered layout.
* `get_park_ids()` returns correct values: the parser now accounts for the
  header row and the `AKA` column, which previously shifted every column
  after `name` (city held the alternate name, state held the city, and so
  on).
* `get_gamelogs()` parses scores, counting statistics, attendance, and game
  numbers as integers, so comparisons like `home_score > visiting_score`
  are numeric rather than alphabetical.
* `list_gamelogs()` and `list_schedules()` no longer error when called
  without `year`.
* Interrupted downloads can no longer poison the cache: files are
  downloaded to a temporary location and moved into the cache only on
  success, and zero-byte cache files are ignored.
* `get_team_ids()` uses the cached event archive instead of re-downloading
  it on every call.

## Improvements

* `cache_status()` and `clear_cache()` now recognize game log and schedule
  artifacts, and `clear_cache(type =)` accepts `"gamelog"` and
  `"schedule"`.
* `clear_cache(confirm = TRUE)` errors in non-interactive sessions instead
  of silently reading an empty answer.
* Default year ranges extend through the 2025 season.
* Full offline test suite with real-data fixtures, plus opt-in live tests
  (`RETROSHEETSHOW_LIVE_TESTS=true`).

## Features

* `list_events()` / `get_events()` — discover, download, and parse
  play-by-play event files (regular season, All-Star, post-season), with
  `parse_event_records()`, `get_plays()`, and `get_game_info()` to
  interpret them
* `list_gamelogs()` / `get_gamelogs()` / `gamelog_fields()` — game logs
  with one row per game and 161 documented fields
* `get_rosters()` — team rosters by year, extracted from the event archives
* `list_schedules()` / `get_schedules()` — season schedules including
  postponement and makeup information
* `get_park_ids()`, `get_team_ids()`, `get_player_ids()` — reference data
* `cache_dir()`, `cache_status()`, `clear_cache()`, `use_cache()` — cache
  management; downloads are cached across R sessions

## Known limitations

* Event files prior to 1911 use box score format (not supported)
* Some years have incomplete coverage (see Retrosheet documentation)
* The maximum default season (currently 2025) is a package constant that
  needs a bump when Retrosheet publishes a new season; explicit `year`
  arguments beyond it still work
