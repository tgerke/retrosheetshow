# Decision log: evaluated output in the README

Context: README.Rmd previously ran every chunk with `eval = FALSE`, so the
rendered README showed code but no results. The vignettes had already
solved this with hand-built `tribble()` snapshots of captured output; the
README had neither approach.

## Evaluate the README for real instead of snapshotting

For a data-access package the deliverable is the shape of the returned
tibble, so the usage sections now run live and print their results. Real
evaluation was chosen over the vignettes' snapshot pattern because the two
documents face different constraints: vignettes rebuild during `R CMD
check` and on CI, where network access is unacceptable, so they must fake
it; README.md is rendered manually with `devtools::build_readme()` and
committed, so nothing downstream ever re-runs it. Live output also can't
drift from the actual interface — a stale README render fails loudly,
which the snapshots never will.

## What stays unevaluated

Installation (`install_github()` has no output worth showing) and the
caching section — `clear_cache()` and `use_cache(FALSE)` would mutate the
very cache state the render depends on.

## Maintenance cost accepted

`build_readme()` now needs the network on a cold cache and reflects live
Retrosheet data, so outputs can change when new seasons post. Re-render
whenever the interface changes or examples reference a new season; the
committed README.md is the source of record between renders. The vignette
snapshots still carry silent-drift risk; if that ever bites, the fix is to
regenerate them from these same live calls, not to snapshot the README.
