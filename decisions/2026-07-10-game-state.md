# Decision log: track_game_state() game-state layer

Context: phase 2 of the play-by-play work (see 2026-07-10-play-parser.md).
`parse_plays()` deliberately stopped at string-level parsing; this layer adds
what conditioning on the situation requires: outs, base occupancy with
runner identities, and score before every play.

## One sequential pass, plain R loop

State is inherently recursive (each play's pre-state depends on every record
before it), so the tracker walks a merged stream of play/start/sub/radj
records per game in an R `for` loop with preallocated outputs. Scores and
outs could be vectorized separately, but keeping every transition in one
place makes the state machine auditable. Measured cost: ~1.5 s for a full
postseason, a few seconds for a regular season — acceptable without C.

## Lineup tracking exists to serve pinch runners

Base occupancy alone doesn't need lineups, but runner *identity* does: a
`sub` record for a pinch runner (fielding position 12) names only the
batting-order slot, so the tracker maintains slot → player per team to find
which base the outgoing runner occupies. The 2020+ automatic extra-inning
runner (`radj`) is buffered as pending and placed when its half-inning
begins, because the half-change reset is only detectable at the next play
record — applying it immediately would see it wiped by that reset. A pinch
runner announced for a pending ghost runner swaps the pending entry.

## Runners not mentioned by a play hold their base

The transition rule is exactly the spec's: explicit destinations move or
remove runners; silence means hold. A play that moves a runner from a base
the tracker believes empty increments a "phantom" counter and triggers a
single warning. Across the 1954 and 2024 full-season validations the
counter stayed at zero.

## Validation: runner identities, not just occupancy

The cwevent golden comparison covers outs, both scores, and the player id
on each base (`BASE1/2/3_RUN_ID`) — identity matching is a much stronger
check than occupancy, since any mistracked substitution or advancement
would surface as a wrong id. Result: exact agreement on all ~283,000
cross-checked events (1954 + 2024, regular season and World Series).

## The rbi column from track_game_state() is authoritative

With the out count known, the rule 9.04(a)(3) exception (no RBI for a
runner from third scoring on an error with two outs) is applied as a
post-hoc correction to the parsed `rbi`, unless the file marks `(RBI)`
explicitly. This closed the final 2-play gap from the string-level
validation; `track_game_state()`'s RBI now matches cwevent everywhere.
