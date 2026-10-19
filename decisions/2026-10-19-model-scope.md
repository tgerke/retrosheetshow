# Decision log: statistical models live outside the package

Context: phase 2 of the times-through-the-order (TTOP) work designed a win
expectancy model, with leverage index and WPA, and first planned it as
exported functions with a vignette. The design was approved on 2026-10-19 and
moved the same day to a separate analysis project, `ttop`, which phase 3 will
also use. The design note moved with it, to
`decisions/2026-10-19-win-expectancy.md` in that project.

## Why it isn't here

retrosheetshow is for data access and wrangling. Its functions are
deterministic transforms with a ground truth: `parse_plays()` and
`track_game_state()` either match Chadwick's `cwevent` or they're wrong. A
win expectancy model is an estimate that rests on judgment calls (the
reference window, the run-level and home-field tilts, which half-innings enter
estimation). Validating it takes dozens of seasons of downloads, which can't
run in `R CMD check`, and phase 3 is likely to change it. Exporting it now
would freeze an API before it settles and blur what the package promises.

The package's outputs don't change.

## What could come back

The model needs some deterministic pieces that are wrangling. They can move
into the package later, each with a `cwevent` cross-check (extended fields
confirmed with `cwevent -d`, Chadwick 0.11.0):

* Per-game rules: scheduled innings (`info,innings`), which team bats second
  (`info,htbf`; extended field 3), and whether the automatic runner applies.
  `info,tiebreaker` alone doesn't settle the last one: 22 of the 41 games in
  the 2023 postseason files carry `info,tiebreaker,2`, yet no postseason file
  from 2020 through 2024 has a `radj` record.
* How each game ended: normally, called early, or tied.
* Plate-appearance starts (extended field 11).
* Runs from each play to the end of its half-inning (extended fields 45 and
  55; field 55 leaves out the play's own runs).

The information used here was obtained free of charge from and is copyrighted
by Retrosheet. Interested parties may contact Retrosheet at 20 Sunset Rd.,
Newark, DE 19711.
