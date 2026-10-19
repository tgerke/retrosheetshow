# Decision log: defense, responsibility, and pitch counts in track_game_state()

Context: phase 1 of the times-through-the-order (TTOP) work. The analysis
needs to know, for every plate appearance, who was pitching, who was charged
with the outcome when a pitcher or batter changed mid-count, and how many
pitches the pitcher had thrown. Win probability added, the next layer, needs
the same responsibility columns. Development was LLM-assisted, so the rule
text, field numbers, and pitch codes below were checked against their sources
(the 2026 Official Baseball Rules, `cwevent -d` for Chadwick 0.11.0, and
Retrosheet's eventfile.htm) rather than taken from memory.

## Fielders are tracked by position, inside the existing loop

Each `start` or `sub` record puts its player at the position it names, in a
team-by-position matrix, and nothing else changes the alignment. That one
rule covers double switches, players swapping positions, and pinch hitters
and runners who stay in the game (their later `sub` carries the new
position). It also covers the 2022 rule that lets a starting pitcher be the
DH: Retrosheet lists that player in two `start` records, at positions 10 and
1, and since 10 is not a fielding position a relief pitcher replaces only the
pitcher. Chadwick models the defense the same way. The alignment lives in
the existing record loop, per the 2026-07-10 game-state note, because a
vectorized version would need a rolling join of every play against nine
positions.

A play whose fielding team has a vacant position or one player at two
positions raises a warning, like the phantom-runner check. The audit skips
NP records: substitutions arrive one record at a time, sometimes with NP
records between them, so the alignment can be briefly incomplete on an NP
row.

## Responsibility follows the rules; the count comes from the record before the substitution

Rule 9.16(h) charges a walk to the departed pitcher when the reliever entered
with the count at 2-0, 2-1, 3-0, 3-1, or 3-2, and any other outcome to the
reliever. Rule 9.15(b) charges a strikeout to the departed batter when he
left with two strikes, and any other outcome to the pinch hitter. Chadwick's
source cites these as 10.18(h) and 10.17(b), their numbers in older editions
of the rules. The count at the change is the count on the play record just
before the `sub`, usually an NP record. That is what Chadwick uses, and in
the fixtures it is the live count (`play,...,10,B,NP`, then the `sub`, then
`B.CBSX`). An unknown count (`??`, common in older files) leaves the
outcome with the substitute.

`pitcher_id` and `resp_pitcher_id` answer different questions. The rules'
comment on the three-batter minimum credits the pitcher on the mound at the
end of a plate appearance with facing that batter, even when the walk is
charged to his predecessor. Counts of batters faced should use `pitcher_id`;
crediting outcomes (WPA, pitching lines) should use the responsible columns.

Two deliberate departures from Chadwick, neither of which occurs in the
seasons cross-checked:

* A second pitching change in the same plate appearance re-judges the count.
  If the batter is no longer ahead, the reliever who walks him is charged
  (rule 9.16(h)(3)). Chadwick keeps charging the first departed pitcher.
* Responsibility ends with the half-inning and with the plate appearance.
  Chadwick carries it across a half-inning that ends on a baserunning out,
  and judges a substitution that directly follows a completed plate
  appearance, with no NP record between them, on the finished plate
  appearance's count.

## Pitch counts

`count_pitches()` counts the codes for pitches thrown. These match Chadwick's
balls plus strikes thrown except for `U` (unknown or missed pitch), which
Chadwick leaves out because it can't say whether the pitch was a ball or a
strike. A `U` was still a pitch, and it is common in early pitch data: 201
records in 1988, 69 in 1993, one in 1999, none by 2005.

Each record of a plate appearance repeats the pitches before it (`B` on the
NP record before a pitching change, then `B.CBSX`). A record's own pitches
are therefore its count minus the previous record's, and the pitcher's
running total is their cumulative sum. The comparison is by count rather than
by string because the 1980s and 1990s files re-annotate between records: a
marker moves (`BBC`, then `BB.C.BB`), a no-pitch code disappears (`BBN`, then
`BB.CBSS`), a pitchout changes type (`Q`, then `P.CBCX`), or an NP record
carries no sequence at all. Only a record with fewer thrown pitches than the
one before it is inconsistent; its count is `NA` and a warning is raised.
That happened twice in 1999 and never in 1988, 1993, 2024, or 2025.

Availability starts from the game's `info,pitches` record, as planned, but
that flag overstates coverage in some older games. In 1988, 34 of 2,070
games marked as having pitches lack sequences for whole stretches, and in
1999, 212 of 2,428 do (one is missing innings 10-16); 2010, 2024, and 2025
have no such gaps. Every completed plate appearance has at least one pitch
code, even an automatic walk (`VVVV`), so a completed plate appearance with
no sequence is missing data. Its count is `NA`, and so is the pitcher's
running total for the rest of the game. Analyses should treat pitch count as
available where `pitch_count_before` is not `NA`, not wherever the game flag
says "pitches".

## Validation

* Goldens: the field list gained RESP_BAT_ID (12), PIT_ID (14), RESP_PIT_ID
  (16), POS2-POS9_FLD_ID (18-25), and the extended per-PA balls and strikes
  thrown (33 and 39), all confirmed with `cwevent -d`. Regenerated with
  Chadwick 0.11.0, the existing columns of both goldens and both `.EVE` files
  came back identical. The 2025 World Series joined as a third fixture for
  Shohei Ohtani's two starts as pitcher and DH (Games 4 and 7), an 18-inning
  game with no automatic runner, and pitch-timer codes.
* Full seasons (`data-raw/cwevent-crosscheck.R`, 1954, 2024, and 2025,
  regular season and postseason, 480,398 events): no mismatches in 14.3
  million comparisons across 33 fields. These seasons exercise the new
  logic: walks charged to a departed pitcher (9, 8, and 15 of them),
  strikeouts charged to a departed batter (1, 1, and 7), and 18 starts by
  Ohtani as pitcher and DH in 2025.
* Pitch totals summed by pitcher matched MLB's official box scores for all
  60 pitching appearances in the 2024 World Series.
* An extra 1988 run, chosen for its early pitch data, matched on every state
  and new column but found 34 disagreements in `parse_plays()` string
  parsing. The compound intentional walk `I+CS3(25)` isn't recognized,
  because the old one-letter code `I` isn't treated as a compound. An RBI
  is credited on `W+SBH` for a run that scored on the steal. And 30 hit
  locations attached to bunt or repeated trajectory modifiers (`34/SH/B3S`,
  `6/L/L6`) come back `NA`. None of these notations appear in the 1954, 2024,
  or 2025 files. Fixing them changes `parse_plays()` output, so they are left
  for a separate change.

## Performance: the bottleneck was the parser, and the fix stays in R

Profiling `track_game_state()` on the 2022-2024 regular seasons (680,639 play
records) measured 71 seconds before this change, over 90% of it in
`parse_plays()`, where a `summarize()` and a `slice_max()` each formed one
group per play. The vectorized replacements match every modifier at once
and keep each play's first hit, use a stable `arrange()` plus `distinct()`,
and total with `rowsum()`. They cut `parse_plays()` from 67 seconds to 6,
with output `identical()` to the old version on 1954, 1988, and 2022-2024.
`track_game_state()`, now with its 13 new columns, takes about 15 seconds for
the three seasons, of which the record loop is 2.3, under a second per
season. Compiling the loop would save less than that second, which doesn't
justify C++.

At scale the limit is memory. Three seasons of output take
197 MB (49 columns), so the full history in one tibble would run to several
gigabytes. Multi-season work should process one season at a time.

## Test fixtures use complete lineups

The synthetic games in test-track_game_state.R listed one or two starters,
which the new alignment check flags. They now start from full nine-man
lineups for both teams; the plays and expectations are unchanged.
