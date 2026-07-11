# Decision log: July 2026 package overhaul

Context: a full review (LLM-assisted, verified against the live Retrosheet
server on 2026-07-10) found broken endpoints, silent data corruption bugs, and
no test suite. The fixes involved several non-obvious design choices worth
recording. See NEWS.md for the user-facing changelog.

## `get_events()` returns wide `f1`-`f6` columns, not a list-column

The original format stored each record's fields in a `fields` list-column,
which forced row-wise parsing (one `switch()` + `unnest_wider()` per record;
minutes per season). Wide character columns let every downstream operation be
vectorized: a full season now parses in ~2 seconds. This was a breaking format
change made deliberately while the package has no released users (0.0.0.9000,
never on CRAN). If the package had users, we would have deprecated instead.

## Event files are parsed with `utils::read.csv(fill = TRUE)`

Not `readr`: ragged rows (records have 2-7 fields) make readr emit per-row
parsing problems, while `read.csv(fill = TRUE)` handles them silently at
C speed and respects quoted commas (real `com` records contain them, e.g.
`com,"$Yankees challenged (tag play), call ..."`). The column count is sized
by `count.fields()` with a floor of 7 (play records) so unexpectedly wide
historical records widen the frame instead of erroring.

## Maximum season is a constant, not discovered from the server

`retro_max_year()` (currently 2025) bounds the default "all years" ranges in
the `list_*()` functions. Dynamic discovery would mean probing URLs on every
call (slow, and a network failure would silently shrink the range). The
tradeoff: one one-line bump per year when Retrosheet publishes a new season.
Explicit `year` arguments beyond the constant still work, so a stale constant
degrades gracefully.

## Downloads are atomic; extraction dirs are per-call

Downloads go to a tempfile and move into the cache only on success, because a
partial file written directly to the cache path was previously treated as a
valid cache forever (`file.exists()` check only). Zero-byte cache files are
ignored for the same reason. Archives extract into a fresh
`tempfile("retrosheetshow-")` directory per call because the previous shared
`tempdir()` let one call's leftover event files leak into another call's
results — the worst kind of bug in a data package, since the output looks
plausible.

## Tests are offline-first with real-data fixtures; live tests are opt-in

Fixtures are excerpts of real Retrosheet files (not synthesized), so format
assumptions are tested against reality: 2024 ALCS events, a real roster and
TEAM file, both the 12- and 13-column schedule variants, parkcode/biofile
headers. Event zips are assembled at test time and seeded into a temporary
cache (`R_USER_CACHE_DIR`), which exercises the full download-path plumbing
without network. Live end-to-end tests exist but require
`RETROSHEETSHOW_LIVE_TESTS=true` so CI and CRAN never depend on the
Retrosheet server. Fake URLs in tests point at `https://127.0.0.1:9/` rather
than `.invalid` domains because macOS DNS resolution of `.invalid` hangs for
seconds while loopback refuses instantly.

## Documentation shows real outputs only

The previous README/vignettes displayed hand-written "static example" tables
presented as outputs; several were wrong (invalid team codes like TB/KC,
columns that don't exist like `game_time`, incorrect statistics). Policy going
forward: any table presented as output must be computed from real data (the
current ones come from the 2024 season) and the prose must say the chunks are
not evaluated at build time. No invented benchmark numbers.

## Dropped `scales`

Its only use was `scales::comma()` inside cli glue strings, which R CMD check
can't see (flagged as an unused Import). `format(x, big.mark = ",")` does the
same job with no dependency.
