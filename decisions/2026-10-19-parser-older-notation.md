# Decision log: parse_plays() fixes for 1980s and 1990s notation

Context: running `data-raw/cwevent-crosscheck.R` on 1988, 1993, and 1999,
seasons the earlier cross-checks never covered, turned up five notations the
parser misread: 34 values in 1988, and thousands of plays in 1993 and 1999,
almost all from one of them. The fixes change `parse_plays()` output for
those plays, so they ship apart from the phase 1 work that found them. As with the original parser (see
2026-07-10-play-parser.md), the spec decides, and Chadwick's source (0.11.0)
settles what the spec leaves open.

## Hit locations follow Chadwick where the spec is silent

The spec says a trajectory code "may be followed by a hit location code" but
doesn't list every location, and it doesn't document the bare `B` (bunt) that
1988 files put before one (`/SH/B3S`). Chadwick accepts a location after an
optional `B` and an optional trajectory letter, checks it against a list of
known codes that includes archaic ones (`2R`, `8RS`, `8RXD`, `7LDW`), and lets
a later location overwrite an earlier one. Two changes bring the parser in
line:

* `R` is now a location character. It appears in archaic codes such as `2R`,
  `8RS`, and `8RXD`, which are common in 1990s files: 5,686 plays in 1993
  and 8,954 in 1999 had lost their location and trajectory. Chadwick's list
  uses only digits
  and S, M, L, D, X, F, W, and R, and the parser accepts those characters
  after a leading digit rather than copying the list. That keeps it literal
  to the file, and no checked season has a location outside the list.
* The location now comes from the first modifier that carries one after a
  trajectory or bunt code, and failing that from a bare location. Before, only
  the first trajectory modifier counted, so `6/L/L6` lost its location.
  Chadwick keeps the last location rather than the first; across the six
  checked seasons that never changes the result, and taking the first leaves
  every location the parser already read unchanged.

The bunt flag is unchanged. In the six checked seasons every `B`-prefixed
location comes with another bunt marker such as `/SH`, so `is_bunt` already
agrees with Chadwick.

## I is IW in compound events

The spec defines `I` and `IW` as the same intentional walk and documents walk
compounds as `IW+event`, so `I+CS3(25)` is that compound written with the
short code.

## Runs implied by a steal carry no RBI

Chadwick credits RBIs only through explicit advances (`3-H`) and to a batter
who homers, so a run implied by a stolen base never gets one. The parser let
the run implied by the second half of a walk (`W+SBH`) inherit the walk's
default credit. Runner moves implied by SB, CS, and PO events now never carry
an RBI. Chadwick has one more walk rule, crediting only the runner from
third on a `W`, which agrees with rule 9.04(a)(2): a walk drives in a run
only by forcing it home with the bases full. No checked season has a play
where that rule changes the count, so it isn't added.

## Ground rule doubles credit no fielder

The notation guide says "DGR is the code for a ground rule double. No
fielding player is specified." Some 1990s files add one anyway (`DGR7`, one
play in 1993 and six in 1999). Chadwick skips the digit, noting that BEVENT
does too, and `fielded_by` now does the same.

## Validation

Full-season cross-checks of 1954, 1988, 1993, 1999, 2024, and 2025, regular
season and postseason, found no mismatches in 30.7 million comparisons across
33 fields, apart from the documented divergences (the event-code exceptions
and `U` pitch codes). Against the previous parser, output changed
for 32 plays in 1988, 5,729 in 1993, and 8,960 in 1999, and for none in 1954,
2024, or 2025.
