# Decision log: Chadwick register lookup

Context: phase 3 of the times-through-the-order (TTOP) work, in the separate
`ttop` project, may add pitch-level data from Baseball Savant (velocity,
spin, release point) to model when managers pull starters. Savant identifies
players by MLBAM ID, so `ttop` needs a map from Retrosheet IDs to MLBAM IDs.
On 2026-10-20 that map came into this package as `get_chadwick_register()`.
It follows the scope in `2026-10-19-model-scope.md` (on branch
`claude/blissful-hopper-1f34de`, not yet on main): models live outside the
package, and data access lives in it. Development was LLM-assisted, so the
register's file layout, columns, update history, and license were checked
against its repository and the license text on 2026-10-20 rather than taken
from memory.

## Why the register belongs here

The register is data access keyed on Retrosheet IDs, which is this
package's job, and anyone joining Retrosheet data to another source needs
it. Two projects already use the package (`ttop` and `kalshi-alcs`). It also
comes from the Chadwick Baseball Bureau, which maintains `cwevent`, the
reference implementation `parse_plays()` and `track_game_state()` are
validated against. And it can be checked the way the rest of the package is,
against Retrosheet's own files, where the right answer is known (see
Validation below).

baseballr's `chadwick_player_lu()` reads the same files, but depending on
baseballr would bring in all of that package for one download. The
function reads the register itself, with no new dependencies.

## Why Statcast and the MLB Stats API stay out

Their data belongs to MLB Advanced Media. Every Stats API response carries
its copyright notice and a link to MLBAM's terms of use, which is a
different arrangement from Retrosheet's notice or the register's open
license. There is no `cwevent` for that data to validate a wrapper against.
And Savant's search is an undocumented endpoint that can change without
notice, so a wrapper would need upkeep nothing else in the package does.
The Retrosheet-to-Statcast link will be prototyped in `ttop` and may later
become its own package; the register gives it the IDs to join on.

## Name: `get_chadwick_register()`

`get_player_ids()` already downloads Retrosheet's biographical file, so the
new function needed another name. Naming it after its source keeps the two
apart and signals that its data comes under a different license. It is also
the name the data goes by elsewhere: pybaseball's function for it is
`chadwick_register()`. It sits with the other reference data in the pkgdown
index.

## One archive, cached, refreshed on request

The register spreads its people across 16 files, `data/people-0.csv`
through `people-f.csv` (69 MB). The function downloads GitHub's zip of the
whole repository instead (`archive/HEAD.zip`, 28 MB). One download is one
consistent version, where 16 could straddle an update, and one zip fits the
package's cache: `cache_status()` lists it as type `"register"`,
`clear_cache(type = "register")` removes it, and clearing by year leaves it
alone. `HEAD` follows the default branch (now `master`) if it is ever
renamed. `retro_extract()` gained a `recursive` argument for the archive's
nested `data/` folder. It defaults to off, so Retrosheet archives extract as
before. The download gets 300 seconds before timing out, against 60 for
event files.

GitHub names the archive's top folder after the commit it holds
(`register-781c175e.../`), so the message after each call says which version
is in use, along with the date it was downloaded. The plan was to report the
version's date instead, but the timestamps on the archive's files are in an
undocumented time zone (02:35 for a commit made at 09:35 UTC), which could
put that date a day off.

`refresh = TRUE` passes a new `force` argument to `retro_download()`, which
downloads even when a copy is cached and replaces that copy only after the
new download succeeds. A failed refresh warns, returns an empty tibble as
the other reference downloads do on failure, and leaves the old copy in
place. The register's README says it updates about weekly, but its commit
history shows monthly updates through 2026, the latest on 2 October, so the
docs say only that it updates periodically.

## Ten of the register's 40 columns, under its own names

The function keeps the six keys (`key_retro`, `key_mlbam`, `key_bbref`,
`key_fangraphs`, `key_uuid`, `key_person`), first and last name, and the
first and last major league seasons played. The seasons help tell apart
people with the same name; the 2025 rosters have two Luis Castillos, and
the register calls both of them Luis. It leaves out the other sports' IDs,
NPB, Wikidata, Baseball-Reference minor league pages, the other name
fields, and birth, death, college, managing, and umpiring details; anyone
who needs them can read the cached archive. The column names are already
snake_case, so the register's own documentation applies to them directly.

Types:

* `key_mlbam` is an integer. Statcast and the Stats API give MLBAM IDs as
  numbers, and dplyr joins an integer column to a double one but refuses a
  character one. All 135,208 MLBAM IDs in the register are whole numbers,
  the largest 844,499, none with a leading zero, so nothing is lost.
* `key_fangraphs` is an integer for the same reason, and it was the closer
  call. All 21,200 FanGraphs IDs in the register are whole numbers (the
  largest 75,423,998, no leading zeros). FanGraphs' own IDs for minor
  leaguers are text, though, like the `sa917940` in baseballr's
  documentation, so a FanGraphs table that includes minor leaguers will need
  `as.character()` on this column before a join.
* The major league seasons are integers.
* Everything else stays character. `key_person` has to: it is hexadecimal
  and can start with zeros (`000007d9`).

## People with a Retrosheet ID by default

By default the function returns the 25,799 people with a Retrosheet ID, of
the register's 526,894. `retro_only = FALSE` returns everyone, mostly minor
leaguers and amateurs. Rows are sorted by `key_retro`, with people who have
none last, by `key_person`. The docs steer joins to `key_retro`,
`key_mlbam`, or `key_uuid`: the register's README promises that a
`key_uuid` is never reused, while a `key_person` is unique only within one
version and can later go to someone else.

## Attribution

The register is under the Open Data Commons Attribution License 1.0. The
license's own sample notice (section 4.3a), with links, is in the function
docs, the package help page, the README, and the validation script. The
test fixture is a small excerpt of the register, and a CSV can't hold a
notice, so `tests/testthat/fixtures/README.md` carries it, as section 4.2(d)
asks. The register names no copyright holder, so the notice names the
database and the license only.

## Tests

The fixture is seven real rows from the register: Aaron Judge, Shohei
Ohtani, Babe Ruth, Liván Hernández (for UTF-8), an 1877 umpire with no first
name or MLBAM ID, a minor leaguer with no Retrosheet ID, and a row whose
first name holds a quoted comma. The tests zip them at run time in GitHub's
layout under a made-up commit, and never touch the network.

The register's URL comes from an internal function, which the tests replace
with `local_mocked_bindings()`. Pointed at an unreachable loopback address,
it shows that a cached copy is used and that a failed refresh keeps it.
Pointed at a `file://` URL for a second archive, it runs a successful
refresh end to end, because libcurl reads `file://` URLs like any other. The
helper that builds those URLs handles Windows drive letters, and the tests
skip if libcurl lacks the protocol. With `force` switched off inside the
function, four of these expectations fail. An opt-in live test downloads
the real register.

## Validation

`data-raw/chadwick-register-check.R` ran on the register at commit 781c175
(the 2 October 2026 update), downloaded on 20 October, with the 1954, 1988,
2024, and 2025 seasons the package's other cross-checks use.

* No ID belongs to two people, for any of the six keys.
* Retrosheet's biofile lists 21,913 people. The register has all but two,
  both players whose major league careers lasted a single day (Spencer in
  1872, Henry Stein in 1900). Every player who debuted in 1950 or later has an MLBAM ID, as do
  6,040 of the 6,042 who debuted from 1900 to 1949 and 2,176 of the 2,201
  before that. Of the 1,443 managers, coaches, and umpires who never played,
  527 have one.
* Every player on the four seasons' rosters (536, 973, 1,454, and 1,471) is
  in the register with an MLBAM ID and a Baseball-Reference ID. All but one
  have a FanGraphs ID; the exception is Chase DeLauter in 2025.
* Last names agree for every roster player. First names differ for 17,
  each a naming choice for the same person: a nickname against a given name
  (Jay and Jehosie Heard, Moose and Guy Morton), a short name against a
  formal one (Curt and Curtis Roberts, Jim and James Steels), a different
  given name (Guillermo and Willie Hernández, Jose and Luisangel Acuña), or
  a middle initial Retrosheet adds to tell same-named players apart (Luis M.
  and Luis F. Castillo, Dave J. Schmidt).
* One roster season falls outside the register's major league years. Chase
  DeLauter is on Cleveland's 2025 roster, but his only 2025 games were two
  in the postseason, and the register starts his major league years in
  2026, so its years appear to count regular-season games only.
* Birth dates were compared where the biofile and the register both have a
  full date: 3,353 roster entries. The biofile doesn't have 454 of the 2024
  players or 627 of the 2025 players yet. Twelve players' dates differ, all
  with matching names, by a digit or two or by a swapped day and month
  (Thyago Vieira, 07/01 against 01/07). The two sources record the same
  person's birthday differently, and the check doesn't decide which is
  right.

None of these points to a wrong mapping. The check can't confirm the MLBAM
side directly, since that would mean querying MLBAM's own data, which stays
out of the package. That check belongs with the Statcast prototype in
`ttop`: for example, whether the MLBAM IDs of a season's Retrosheet
pitchers all appear among that season's Statcast pitchers, under the same
names.

The information used here was obtained free of charge from and is
copyrighted by Retrosheet. Interested parties may contact Retrosheet at 20
Sunset Rd., Newark, DE 19711. Contains information from the Chadwick
Baseball Bureau Register (https://github.com/chadwickbureau/register),
which is made available under the ODC Attribution License
(http://opendatacommons.org/licenses/by/1.0/).
