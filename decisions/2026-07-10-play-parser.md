# Decision log: parse_plays() event-string parser

Context: a documentation review found that the package's play-by-play story
stopped at raw event notation — `get_plays()` returned strings like `7/F7S`
with no way to compute anything from them. `parse_plays()` closes that gap.
Development was LLM-assisted; the choices below were verified against the
published grammar and the Chadwick reference implementation as described.

## Spec is the authority, Chadwick is the oracle

The parser was written from the published grammar
(https://www.retrosheet.org/eventfile.htm), not from memory or from
Chadwick's source. It is then validated against `cwevent` output
field-by-field: committed golden files cover the 2024 and 1954 World Series
(run offline in CI; regenerate with `data-raw/make-cwevent-golden.R`), and
full-season cross-checks on 1954 and 2024 regular seasons (~283,000 events)
were run during development. Disagreements were resolved by consulting the
spec and scoring rules, not by auto-matching Chadwick. Two deliberate
divergences, documented in the golden test:

* `POCS` (pickoff caught stealing) is classified `caught_stealing` because
  the spec says the runner is charged with a CS; Chadwick codes it as a
  pickoff. Users counting CS from `event_type` get the official totals.
* `$E$` plays (`3E1`) are `error` per the spec's explicit definition;
  Chadwick sometimes emits generic-out for them.

## String-level parsing only — no game state

`parse_plays()` interprets one event string at a time. Consequences, chosen
deliberately and documented in the function and vignette:

* `runnerN_dest` is `NA` when a play does not mention that runner (a holding
  runner and an empty base are indistinguishable without state tracking).
  Chadwick emits 0 for both; we prefer honest missingness.
* Trajectory and bunt flags are only populated when the notation records
  them. Chadwick infers defaults (ground for `63`, fly for `7`) from scoring
  conventions; we stay literal to the file, which mainly matters pre-1980s.
* The rule 9.04(a)(3) RBI exception (runner from third scoring on an error
  with two outs gets no RBI) requires the out count. We credit the RBI, the
  best string-level default: it was wrong on 2 of ~283,000 validation events.

Base-out state, run expectancy, and win probability are a planned future
layer (lineup tracking from `start`/`sub` records) on top of this parser.

## RBI defaults encode official scoring, with explicit markers winning

Retrosheet marks exceptions explicitly (`(RBI)`, `(NR)`/`(NORBI)`), and those
always win. When unmarked: no RBI on strikeouts, baserunning events, or GDPs;
no RBI when the scoring advance itself carries an error parameter (the run
scored on the error, not the event); on error events only the runner from
third gets the default credit (rule 9.04(a)(3)). Each of these was confirmed
empirically against full-season cwevent output before adoption.

## Outs negated by errors follow Chadwick's reading

An `X` advance (out) with an error parameter means the runner is safe —
unless a separate parenthesized fielding string without an error records a
putout (`1XH(82)(E2/TH)`: out stands, error charged on other action). The
spec text does not address the multi-parameter case; the 1954+2024 corpus
confirmed Chadwick's interpretation on every instance.

## Fixtures are complete World Series files, not excerpts

Golden validation needs whole games (half-inning out totals, era-specific
notation). The 1954 and 2024 World Series files are small (~45 KB combined),
freely redistributable with the Retrosheet notice, and deliberately span the
notation's evolution: 1954 exercises missing counts, sparse trajectories,
and unknown-fielder codes; 2024 exercises modern pitch-level and replay-era
notation.
