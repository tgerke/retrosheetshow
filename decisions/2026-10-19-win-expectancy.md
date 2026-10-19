# Decision log: win expectancy, leverage index, and WPA

Context: phase 2 of the times-through-the-order (TTOP) work. Phase 3 needs,
for every plate appearance, the batting team's chance of winning (win
expectancy, WE), how much the plate appearance can swing it (leverage index,
LI), and the change each play caused (win probability added, WPA), credited
to the responsible batter and pitcher from `track_game_state()`. This note is
the design, written for review before any model code. Development is
LLM-assisted. The figures below come from descriptive scripts (counts and
rates, no model fitting) run on 2026-10-19 over the 1954, 1988, and 2015-2025
regular seasons with the package at 0163c46. The scripts were exploratory and
aren't committed; phase 2's count tables compute the same quantities. The
eventfile spec, `cwevent -d`, Baseball-Reference's methodology page, and every
published table cited here were fetched or run that day rather than taken from
memory.

## The model

The state before a play is the inning, the batting team, the outs, the bases,
and the score difference d (team batting second minus team batting first). WE
comes from two pieces:

1. For each of the 24 base-out states, the empirical distribution of runs
   scored from that state to the end of the half-inning, f(r | bases, outs).
2. A backward recursion over half-innings on a grid of score differences,
   from the scheduled last inning N down to the first. Mid-inning, WE at
   (bases, outs, d) is the sum over r of f(r | bases, outs) times the WE at
   the start of the next half-inning with d moved by r.

The game ends when the team batting second leads after the top of an inning
at or past N, when the team batting first leads after the bottom of one, and
on the play in the bottom of one that puts the team batting second ahead.
Score differences live on a ±30 grid and run totals are capped at 20; no
plate-appearance start in the 13 seasons led to more than 14 runs.

A walk-off ends a half-inning early but never changes the winner, so if both
teams have the same run distributions, the pregame WE is exactly 0.5. Batting
last is worth nothing in this model. That gives the tests an exact oracle, and
it means all of home-field advantage has to live in the run distributions.

## Reference window: shape from five seasons, level from the season

The plan was era-specific distributions from a window of seasons. The data
split that into two problems.

* The level moves too fast for a window. Runs per regulation half-inning
  (complete halves before inning N, both teams) went from 0.503 in 2018 to
  0.546 in 2019, and from 0.478 in 2022 to 0.518 in 2023. A season's
  standard error is about 0.005, so each jump is five to six standard errors
  of the difference. A centered five-season window would put 2019's level
  0.023 too low and 2022's 0.025 too high.
* The shape needs more than a season. Per team, the rarest state, a runner on
  third with nobody out, had 125 and 139 plate-appearance starts in 2024 (47
  and 48 in the 60-game 2020 season). The chance of scoring from there then
  has a standard error of about 0.035, and that state matters most in the
  late, close spots where WE gets used.

Recommendation: estimate the shape f(r | bases, outs) from five seasons
centered on the target season (shifted at the ends of the data so it always
spans five), pooling both teams. Then tilt it to the target season's level,
f_season(r) ∝ f_window(r) exp(θr), with θ chosen so the tilted half-inning
distribution matches the season's mean runs per regulation half-inning. The
exponential tilt is the I-projection onto that mean, the smallest change in
Kullback-Leibler terms that hits it. It keeps the empirical shape and adds one
parameter per season.

With each season left out of its own window, the untilted window's 24 state
means miss the season's observed means by an RMS of 1.2 to 2.5 standard
errors (2.25 in 2019, 2.46 in 2022). With the tilt the RMS falls to 1.0 to
1.5, against about 1.1 expected from sampling noise alone. The worst season
left is 2023, the first with the pitch clock and larger bases. Windows that
stop at the 2023 rule change did worse: 2023 against 2024-2025 alone gave 1.66
(1.50 with 2021-2025), and 2024 against 2023 and 2025 gave 1.23 (1.11 with
2021-2025). So the default has no built-in era breaks, and `shape_years` stays
an argument.

One addition: in seasons where only one league used the DH (1973-2021), set
the level separately for games with and without it, from `info,usedh`. DH
games scored 13% more per regulation half-inning in 1988 (0.493 against
0.435), and between 1.5% and 6% more in 2016-2019 and 2021. That is the same
size as the season-to-season drift the tilt exists to fix. It costs one
parameter in those seasons and needs no league lookup.

## Home-field advantage

Recommendation: a second tilt on the pooled shape, with the home team at
θ + η/2 and the visitors at θ − η/2, where η is set over the five-season
window so the tilted home and visitor half-inning means match the window's.
"Home" means `team == 1`, the listed home team, even when it bats first.

* HFA looks constant across seasons, so it should borrow strength. Over
  2015-2025, leaving out 2020, home teams outscored visitors by 0.045 runs per
  regulation half-inning, about 9% of the level. Across seasons that
  difference has an SD of 0.009, against a sampling standard error of 0.010
  per season. Home win percentage in games that ended normally ran from .521
  to .543, an SD of .008 against a binomial standard error of .010. Neither
  varies more than noise. A single season's η would carry about 22% relative
  error, a five-season η about 10%.
* Separate empirical distributions for home and visitors would halve every
  cell, and the per-team counts above are already the thin ones.
* 2020, played without fans, had a home win percentage of .557 (897 games,
  standard error .017), which gives no reason to treat it specially.

Validation checks that the pregame WE lands near the observed home win
percentage (.534 for 2015-2019, .532 for 2021-2025) instead of forcing it
there.

## Extra innings: the automatic runner and termination

Every extra inning starts tied under the same rules, so the recursion needs no
truncation. The probability p that the team batting second wins from the start
of a tied extra inning solves p = A + Bp, so p = A / (1 − B), where A is the
chance it outscores its opponent in one extra inning and B the chance they
score the same. That is exact.

The automatic runner applies when a game comes from a regular-season archive
and its `tiebreaker` info is set. The `tiebreaker` record alone is not enough:
22 of the 41 games in the 2023 postseason files carry `info,tiebreaker,2`,
while no postseason file from 2020 through 2024 has a single `radj` record
(nor does the 18-inning game in the 2025 World Series fixture).
Regular-season files set `tiebreaker` to 2 in every game from 2020 through
2025, and in no game of the earlier seasons checked. `gametype` can't stand in
either: the checked regular-season files lack it before 2023, apart from two
2018 games marked `playoff`. A game whose `radj` records contradict its rules
raises a warning.

Recommendation: estimate how automatic-runner innings unfold from those
innings, not from the regulation state with a runner on second and nobody
out. In 2021-2025 the visitors scored in 57.6% of automatic-runner top halves
(1,501 of them), against 60.9% of regulation plate appearances that began with
a runner on second and nobody out (5,462), 2.3 standard errors apart. Mean
runs matched (1.13 each), but the extra innings had more scoreless frames,
fewer one-run frames, and more frames of three runs or more. Selection may
explain it, since games tied after nine lean toward low-scoring matchups and
spent bullpens, but the cause doesn't change the choice: these are the innings
extra-inning WE describes.

Only top halves are used, because walk-offs cut bottom halves short. They are
pooled over the five automatic-runner seasons nearest the target and get the
same season and home-field tilts, measured from the visitors' level in those
seasons. After the first plate appearance of an extra inning, states use the
regulation f. Extra innings before 2020 and in the postseason start with the
bases empty and use the regulation distribution.

## Seven-inning games, walk-offs, and the home team batting first

* N comes from `info,innings`, which the checked regular-season files carry
  only from 2020 (N is otherwise 9). 2020 had 111 scheduled seven-inning games
  and 2021 had 121. They share f with nine-inning games; only N changes.
* The team batting second is the home team unless `info,htbf` is true. In
  those games the play records keep 0 for the visitors and 1 for the home
  team, and only the order changes, so every terminal rule keys on batting
  order. They are not rare: 28 games in 2020, 3 each in 2015 and 2017, and one
  each in 2021 and 2022. An ending classifier keyed on batting order scored
  all of them as normal endings.
* Walk-offs need no special distribution. From the bottom of an inning at or
  past N with d ≤ 0, WE is P(R ≥ 1 − d) + P(R = −d) p, and stopping the
  half-inning at the winning run changes neither term.

## Estimation sample

Regular-season games only. Half-innings that ended with three outs, in innings
before N, for both teams. Leaving out the bottom of inning N and later removes
walk-off truncation, and leaving out the top of N as well keeps the home and
visitor samples symmetric for η. States are observed at plate-appearance
starts (the first non-NP record of a half-inning and the first after each
record that ends a plate appearance), so a plate appearance counts once however
many records it spans. The automatic-runner start distribution comes from the
top halves of automatic-runner extra innings. Called and suspended games
contribute their complete half-innings.

## Sparse states

Recommendation: no parametric smoothing. Pooled over both teams and five
seasons, every state had at least 1,523 plate-appearance starts in 2015-2019
(runner on third, nobody out, was the smallest), and the chance of scoring from
it has a standard error under 0.01. The tilt supplies each season's level, so
thin single-season counts never enter directly. 1954, with eight-team leagues,
had 227 starts in its rarest pooled state, so a 1950s window holds roughly
1,100. The tails are thin but harmless: in 2015-2019 no state produced eight or
more runs in more than 1.1% of its starts, and totals that large matter only
at score differences where WE is already near 0 or 1.

The fit stops with a cli error if any state has fewer than 500 starts in its
window, which keeps the standard error of the chance of scoring at about 0.02
or less. The error names the state and suggests a wider `shape_years`. Only
the earliest seasons, where Retrosheet's coverage thins, should hit it.

If validation turns up state-specific era effects (2023 is the candidate), the
next step is Dirichlet shrinkage of each season's own counts toward the tilted
window shape, so that common states follow their own season and rare ones
borrow. With the RMS already near noise, it isn't worth another tuning
constant yet.

## Leverage index

LI for a state is the expected absolute change in WE over one plate
appearance, Σ P(outcome | bases, outs) |WE(after) − WE(before)|, divided by a
constant c.

* Outcomes run from the base-out state at a plate-appearance start to the
  state at the next start or the end of the half-inning, with the runs in
  between, so a steal or wild pitch during the plate appearance is part of
  it. The transitions come from the same window and sample as f, pooled over
  both teams.
* c is the mean unnormalized swing over the target season's regular-season
  plate-appearance starts, which makes that season's average LI exactly 1 (a
  test).
* LI depends only on the state, so every row gets one, including the NP rows
  where pitching changes happen. Phase 3 cares about exactly that moment.
* f and the transitions are estimated separately, so the expected WE after a
  plate appearance won't exactly equal the WE before it. Validation reports
  the size of that drift.

## WPA and who gets credit

`wpa` is `we_after - we_before` from the batting team's side, on every row.
`we_after` is the next row's `we_before`. On a game's last play it is the
result (1 or 0) when the game ended normally, and otherwise the model WE of
the state after the play, so a rain call earns no WPA. In a game that ended
normally, the WPA sums to the result minus the pregame WE.

Plate-appearance rows credit `wpa` to `resp_batter_id` and charge it to
`resp_pitcher_id`, as specified. The other rows need a decision: steals,
caught stealing, pickoffs, wild pitches, passed balls, balks, defensive
indifference, and other advances. Charging a batter for a teammate caught
stealing is hard to defend. Baseball-Reference credits pitchers and hitters
with everything except baserunning events; when the batter makes no play, all
of the credit goes to the baserunner, the lead runner whose state changes when
there are several (https://www.baseball-reference.com/about/wpa.shtml).

Recommendation: credit plate-appearance rows only, and show that convention in
the documentation and vignette rather than in a helper function. It keeps
batting and pitching WPA zero-sum and matches phase 3's unit, the plate
appearance. The other rows keep their `wpa` for anyone who wants to credit
runners, catchers, or pitchers (adding wild pitches and balks to a pitcher's
total is one filter).

## Calibration exclusions and validation

Calibration uses plate-appearance starts from regular-season games that ended
normally under the terminal rules above.

* Ties: excluded, since there is no binary outcome. There was one in
  2015-2025 (2016), five in 1954, and two in 1988.
* Games called before a normal ending: excluded, since the model plays every
  game out and can't forecast weather. There were 1 to 10 a season in
  2015-2025 and 17 in 1954. Their complete half-innings still count toward
  estimation.
* Suspended games: included. Retrosheet stores the whole game with a
  `com,"Suspend=..."` record, and every one in the checked seasons (up to 8 a
  season) ended normally.
* Forfeits: excluded as abnormal endings.
* Games where the home team bats first, seven-inning games, and extra-inning
  games: included, and reported as strata.
* Postseason: never used for estimation; scored with the same season's
  regular-season model (without the automatic runner) and reported
  separately. All-Star games are left out of everything.

Held-out seasons: 1954, 1988, 2016, 2019, 2022, 2023, and 2024, which cover
two older eras, high and low run levels, the DH split, the 2023 rule changes,
and the automatic runner. Each test season is removed from its own shape and
HFA windows. Its level tilt still uses its own mean runs per half-inning, as
deployed. The model never fits to wins, so the outcomes stay out of sample; a
stricter run takes the level from the neighboring seasons to show what the
level is worth.

Metrics: Brier score, with skill against a constant home-win rate; observed
against predicted home wins in WE bins of 0.05; strata by inning (1-3, 4-6,
7-8, 9 and later, extras), by score difference, and by the game types above;
and game-clustered bootstrap intervals, since plays within a game aren't
independent. Two checks need no outcomes: the mean observed WPA per plate
appearance in each WE bin should be near zero, and the mean observed |WPA| in
each LI bin should match the predicted swing.

Published tables:

* Greg Stoll's Win Expectancy Finder
  (https://gregstoll.com/~gregstoll/baseball/stats.html), whose per-season
  counts are on GitHub (https://github.com/gregstoll/baseballstats,
  `statsyears/stats.YYYY`; fetched 2026-10-19, last data commit 58d464c on
  2026-03-12). Each cell gives the batting team's wins and games from an
  inning, half, outs, bases, and score difference, counted from Retrosheet.
  Only seasons before 2020 are usable. His parser drops every game that
  reached extra innings under the automatic-runner rule, and every
  seven-inning game, so in 2021 the team batting in the bottom of the ninth,
  tied, with the bases empty and nobody out won 81 of 81 games, and 72 of 73
  in 2024. For 2015-2019 the same cell is 768 of 1,158 (66.3%). The
  comparison runs cell by cell where a cell has at least 500 games, with
  binomial z-scores, and looks for patterns by inning. His files include
  postseason games and treat the team batting second as home, both small
  effects.
* Tango's LI table (http://www.insidethebook.com/li.shtml) and WE charts for
  innings 7-9 (http://www.tangotiger.net/welist.html) don't state their run
  environment, so they are only a loose check, reported without a pass
  threshold.

Before any of that, `data-raw/cwevent-crosscheck.R` should cover the run
bookkeeping phase 2 depends on, using extended fields confirmed with
`cwevent -d` (Chadwick 0.11.0): 3 (half-inning, which differs from the
batting team when the home team bats first), 4 and 5 (start and end of the
half-inning), 8 (runs earlier in the half-inning), 11 and 12 (new and
truncated plate appearance), 13 and 14 (bases before and after), 45 (runs on
the play), 55 (runs in the half-inning after the play), and 64-66
(automatic-runner flags). In Game 1 of the 2024 World Series, the sixth-inning
two-run homer shows 2 runs on the play and 0 after it, and the single before
it shows 2 after it, so the runs from a play to the end of its half-inning are
field 45 plus field 55. 2020 should join the cross-check seasons for its
htbf, seven-inning, and first automatic-runner games.

## Where the preferred design is weak

1. A window alone gets the level wrong in volatile seasons, by four to five
   times the season's standard error. The tilt fixes it.
2. Innings aren't interchangeable. Home teams score 11-13% above their
   average in the first inning, while visitors stay within 5% of theirs, and
   both score 7-11% below average in the second. Visitors' ninth innings ran
   6% below their average in 2015-2019 but not in 2021-2025. The model treats
   every inning alike. A
   back-of-envelope estimate (no model was run) puts the effect on late-game
   WE under 0.01, so the default keeps the homogeneous model from the original
   plan and lets calibration by inning decide. If it fails, a tilt per inning
   group is the cheap fix.
3. The bottom of the ninth and later never enter estimation, though that is
   where strategy changes most (playing for one run). The Stoll comparison on
   those cells is the check. If it fails, those halves can come back as
   censored data, since a walk-off still shows the needed runs scored.
4. WE is context-neutral. Both teams are treated as average and every
   half-inning as independent, but a team leading by five is probably the
   better team, so the model should be too cautious about big leads.
   Calibration at the extremes will show by how much. For phase 3, WE and LI
   describe the situation, not the matchup.
5. The regulation state with a runner on second and nobody out doesn't stand
   in for the automatic runner (above).
6. There is no park adjustment. Baseball-Reference scales its run environment
   by park factor; that is out of scope here.
7. The specified WPA crediting doesn't cover plays that aren't plate
   appearances (above).

## Data flow and API

* One pass of `track_game_state()` per season feeds small count tables: runs
  to the end of the half-inning by state, team, and DH; plate-appearance
  transitions; half-inning totals; automatic-runner top halves; and each
  game's rules and ending. They are cached as one RDS per season under the
  package cache, with a schema version, so a window is a sum of cached tables
  and only one season's plays (about 65 MB) are ever in memory.
  `cache_status()` and `clear_cache()` learn the new type.
* `win_expectancy_model(season, shape_years = NULL)` builds the model: the
  tilted distributions, the WE and LI tables for each rule variant present
  (N of 7 or 9, with or without the automatic runner), c, and the counts
  behind each cell. Printing it shows the Retrosheet notice.
* `add_win_expectancy(states, model = NULL)` appends `we_before`, `we_after`,
  `wpa`, and `li` to `track_game_state()` output, building a model for each
  season present when `model` is NULL. WE is from the batting team's side,
  like `bat_score`; the home team's is
  `if_else(team == 1, we_before, 1 - we_before)`.
* `win_expectancy_table(model)` returns the tidy table for the vignette and
  the Stoll comparison.

Existing outputs don't change. The RE24 example in `analyzing_plays.Rmd`
counts NP and mid-plate-appearance rows and keeps bottom-of-the-ninth halves
that didn't end in a walk-off, so its table will differ slightly from the
model's run expectancies. Aligning it would change that vignette's output, so
it belongs in a separate, flagged change.

Tests run offline: exact oracles (equal distributions give 0.5, half-innings
of zero or one run give a closed form from `dbinom()`, the extra-inning fixed
point, walk-off and game-over states), seven-inning and automatic-runner
variants on toy distributions, a game where the home team bats first, the
tilt hitting its target mean, LI averaging 1, and each game's WPA summing to
its result minus the pregame WE. The World Series fixtures give an end-to-end
smoke test.

The vignette, "Win Expectancy and Leverage", shows tables from real data as
snapshots, like the existing vignettes: a model for 2024, WE and LI through
Game 1 of the 2024 World Series, the distribution of LI, plate-appearance WPA
leaders, and the calibration and Stoll comparison from a new
`data-raw/we-validation.R`. The Retrosheet notice goes at the top and bottom.

## Review

Approved as written on 2026-10-19. That settles the six questions left open
for review: phase 2 uses the five-season shape window with a season-level
tilt, separate DH and non-DH levels for 1973-2021, home-field advantage as a
tilt with η from the window, an empirical start distribution for
automatic-runner innings, WPA credited on plate-appearance rows only, and the
held-out seasons listed above.

The information used here was obtained free of charge from and is copyrighted
by Retrosheet. Interested parties may contact Retrosheet at 20 Sunset Rd.,
Newark, DE 19711.
