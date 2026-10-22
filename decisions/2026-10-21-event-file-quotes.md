# Decision log: quotes in event files

Context: `ttop` needs the 1976 regular season to re-check its win
expectancy model, and `get_events(year = 1976)` returned no records, with
the warning "Failed to download 1976 regular events: In index: 2." The
archive had downloaded fine. Lines 6153 and 6154 of `1976BAL.EVA` are
comments that open with a curly quote (U+201D). The first also closes with
one; the second closes with a straight quote. `read.csv()` lets a quoted
field continue onto the next line, so the lone straight quote on line 6154
started a quoted field that ran on into the lines after it:
`count.fields()` returned NA for that line and nearly every one after it,
and `parse_event_file()` errored. purrr wrapped the error as
"In index: 2", and `get_events()` reported every error, whatever its
cause, as a failed download.

## A record ends at the end of its line

Retrosheet records never span lines, so `parse_event_file()` now pairs up
the quotes on each line before `read.csv()` sees the file:

* A curly double quote (U+201C or U+201D) at the start or end of a field
  becomes a straight quote. Each 1976 comment then parses as one field.
* A line that still has an odd number of straight quotes gets a closing
  quote at its end.

All other lines reach the same `read.csv()` call unchanged, so they parse
exactly as before. A new line-by-line parser would have had to copy R's
reader on every line to promise that. R has rules of its own: for example,
it reads `com,"earlier in inning".` (2025ATL.EVN) as `earlier in inning.`.
The lines go to `read.csv()` through a temporary file rather than
`read.csv(text = )`, which marks non-ASCII strings as UTF-8; read from a
file they come back as before.

Checked on every archive in the local cache, 56 regular seasons and 12
postseasons from 1952 to 2025 (1,602 event files). The 67 archives that
parsed before give the same tibbles, compared by `rlang::hash()`, which
also covers string encodings, and for 1954, 1988, and 2024 by `identical()`
as well. 1976 now returns 296,807 records, and each of its 24 files
contributes as many records as it has lines. A full season takes about 0.5
seconds to parse instead of 0.3, mostly for reading the lines first.

## Curly quotes only at the edges of a field

In the cached files, only `1976BAL.EVA` has curly double quotes, and all of
them are at the edge of a field, so converting every curly quote would give
the same result today. Converting only those at the edges leaves alone any
curly quotes inside a straight-quoted comment. Converted, such a quote could
end the comment early and split it at the next comma.

## An unclosed quote closes at the end of its line

Once the curly quotes are converted, no cached file has an unclosed quote,
so this rule changes no current output. It keeps a future one from
swallowing the records that follow. Closing at the end of the line keeps a
comment whose closing quote is missing in one piece, and the one quote
problem found so far was in comments.

`cwevent` 0.11.0 does no better with a missing closing quote. Given a copy
of the 1976 fixture game in which a `sub` record had lost it
(`sub,dragd101,"Dick Drago,0,0,1`), `cwevent` dropped the substitution and
kept Monge pitching. This parser reads the rest of that line as the name,
leaving the team, batting order, and position empty. With the opening quote
missing instead (`Dick Drago",0,0,1`), `cwevent` kept the substitution,
while this parser again puts the rest of the line in the name. Reading the
quotes on such a line as plain characters would keep that substitution
too, but would split a comment with a missing closing quote at every comma.
The repair adds no warning.

## Parse failures are reported as parse failures

When a file can't be parsed, `get_events()` now warns "Failed to parse
<file> in <year> <type> events: <reason>". Download and unzip errors still
say "Failed to download". As before, nothing from that year and type is
returned. A season missing one team's home games could go unnoticed; an
empty one can't. The loop over files uses `lapply()`, because
`purrr::map_dfr()` wraps errors in an error of its own, which hid both the
cause and the class the handler looks for.

The warning names a line only when R's error message does. With the quote
repairs in place, no input I could construct fails at a particular line, so
there was no line number to add.
