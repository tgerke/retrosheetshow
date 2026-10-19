# retrosheetshow 0.0.0.9000 (development version)

## New features

* `track_game_state()` now reports the defense on every play: the pitcher
  (`pitcher_id`) and the fielders at positions 2-9 (`fielder2_id` through
  `fielder9_id`), followed through double switches, position changes,
  pinch hitters and runners who stay in the game, and starting pitchers
  who are also the designated hitter (allowed since 2022). Two more columns
  name the pitcher and batter charged with each play (`resp_pitcher_id`,
  `resp_batter_id`). They differ from the players involved only for a walk
  issued by a reliever who entered with the batter ahead in the count (rule
  9.16(h)) or a strikeout by a pinch hitter who entered with two strikes
  (rule 9.15(b)). Where Retrosheet has pitch sequences, `pitches_on_play`
  and `pitch_count_before` give each record's pitches and the pitcher's
  running total. The new player columns matched Chadwick's `cwevent` on
  every one of ~480,000 cross-checked events from 1954, 2024, and 2025.
  Pitch counts matched `cwevent`'s per-plate-appearance totals wherever
  those seasons have pitch sequences, and the official box scores for all
  60 pitching appearances in the 2024 World Series. The 13 new columns
  come after the existing ones, which are unchanged. A new warning flags a
  play whose defense has a vacant position or one player at two positions.
* New `count_pitches()` counts the pitches thrown in Retrosheet pitch
  sequences, leaving out pickoff throws, markers, no-pitch calls, and
  automatic balls and strikes.
* New `track_game_state()` replays each game's record stream to attach the
  pre-play situation to every play: outs, runner identities on each base,
  and both teams' scores. Lineup tracking handles pinch-runner swaps and
  the 2020+ automatic extra-inning runner (`radj`). With the out count
  known it also applies the rule 9.04(a)(3) RBI exception, making the
  `rbi` column exact. State columns matched Chadwick's `cwevent` on every
  one of ~283,000 cross-checked events from 1954 and 2024.
* New `parse_plays()` interprets Retrosheet event notation into typed,
  analysis-ready columns: event type, plate-appearance/at-bat/hit flags,
  hit value, fielding and trajectory detail, modifier flags, and outs,
  runs, RBI, and per-runner advancement. The parser follows the published
  event grammar and is validated field-by-field against Chadwick's
  `cwevent` on committed World Series golden files, with full-season
  cross-checks covering about 283,000 events from 1954 and 2024.
* New vignette "Analyzing Play-by-Play Data" builds batting lines,
  count-based splits, a 1954 World Series reconstruction, and a full run
  expectancy (RE24) matrix from parsed plays and tracked game state.

## Breaking changes

* `get_events()` now returns the record fields in wide character columns
  `f1`-`f6` instead of a `fields` list-column. `parse_event_records()`,
  `get_plays()`, and `get_game_info()` work as before but run vectorized
  and are much faster.
* `list_events()`, `list_gamelogs()`, and `list_schedules()` no longer
  return the `available` column (it was constant `TRUE` because
  unavailable files are filtered out).

## Bug fixes

* `parse_plays()` now reads the older hit location codes that contain an R
  (`8RS`, `8RXD`, `2RF`), along with the trajectory before them. About 5,700
  plays in 1993 and 9,000 in 1999 gain a `hit_location` and `trajectory`;
  1954, 2024, and 2025 are unaffected.
* `parse_plays()` keeps a hit location written after a bare bunt code or a
  repeated trajectory (`34/SH/B3S`, `6/L/L6`) instead of dropping it.
* `parse_plays()` recognizes the one-letter intentional walk `I` in a
  compound event (`I+CS3(25)`), as it already did `IW`. The play used to
  come back unclassified, without its out.
* `parse_plays()` no longer credits an RBI for a run stolen during ball
  four (`W+SBH`).
* `parse_plays()` no longer reports a fielder for a ground rule double
  written with one (`DGR7`); the notation guide says it names none.
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

* `parse_plays()`, and with it `track_game_state()`, is about ten times
  faster: three seasons of plays parse in 6 seconds instead of more than a
  minute, with identical output.
* The full-season `cwevent` cross-check is now a script,
  `data-raw/cwevent-crosscheck.R`, and the 2025 World Series joins the
  golden test fixtures. The 1954, 1988, 1993, 1999, 2024, and 2025 seasons
  match on every compared field.
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
