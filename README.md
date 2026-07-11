
<!-- README.md is generated from README.Rmd. Please edit that file -->

# retrosheetshow <a href="https://tgerke.github.io/retrosheetshow"><img src="man/figures/logo.jpg" align="right" height="138" alt="retrosheetshow website" /></a>

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/tgerke/retrosheetshow/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/tgerke/retrosheetshow/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/tgerke/retrosheetshow/branch/main/graph/badge.svg)](https://app.codecov.io/gh/tgerke/retrosheetshow?branch=main)
[![License:
MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

> **RETROSHEET DATA NOTICE**
>
> The information used here was obtained free of charge from and is
> copyrighted by Retrosheet. Interested parties may contact Retrosheet
> at 20 Sunset Rd., Newark, DE 19711.
>
> Website: <https://www.retrosheet.org>

**retrosheetshow** provides a convenient and tidy interface for
accessing [Retrosheet](https://www.retrosheet.org) baseball data in R.
The package follows tidyverse principles, making it easy to integrate
Retrosheet’s play-by-play event files, game logs, rosters, and schedules
into your data analysis workflows.

## Installation

You can install the development version of retrosheetshow from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("tgerke/retrosheetshow")
```

## Basic Usage

### Play-by-Play Events

``` r
library(retrosheetshow)
library(dplyr)

# See what's available
list_events(year = 2020:2024)
#> # A tibble: 5 × 3
#>    year type    url                                          
#>   <int> <chr>   <chr>                                        
#> 1  2024 regular https://www.retrosheet.org/events/2024eve.zip
#> 2  2023 regular https://www.retrosheet.org/events/2023eve.zip
#> 3  2022 regular https://www.retrosheet.org/events/2022eve.zip
#> 4  2021 regular https://www.retrosheet.org/events/2021eve.zip
#> 5  2020 regular https://www.retrosheet.org/events/2020eve.zip
```

``` r
# Download and parse event files (cached after the first download)
events <- get_events(year = 2024, type = "post")

# One row per game with all metadata
games <- get_game_info(events)
games
#> # A tibble: 43 × 35
#>    game_id     year type  visteam hometeam site  date  number gametype starttime
#>    <chr>      <dbl> <chr> <chr>   <chr>    <chr> <chr> <chr>  <chr>    <chr>    
#>  1 NYA202410…  2024 post  CLE     NYA      NYC21 2024… 0      lcs      7:38PM   
#>  2 NYA202410…  2024 post  CLE     NYA      NYC21 2024… 0      lcs      7:38PM   
#>  3 CLE202410…  2024 post  NYA     CLE      CLE08 2024… 0      lcs      5:08PM   
#>  4 CLE202410…  2024 post  NYA     CLE      CLE08 2024… 0      lcs      8:08PM   
#>  5 CLE202410…  2024 post  NYA     CLE      CLE08 2024… 0      lcs      8:08PM   
#>  6 CLE202410…  2024 post  DET     CLE      CLE08 2024… 0      divisio… 1:08PM   
#>  7 CLE202410…  2024 post  DET     CLE      CLE08 2024… 0      divisio… 4:08PM   
#>  8 DET202410…  2024 post  CLE     DET      DET05 2024… 0      divisio… 3:08PM   
#>  9 DET202410…  2024 post  CLE     DET      DET05 2024… 0      divisio… 6:08PM   
#> 10 CLE202410…  2024 post  DET     CLE      CLE08 2024… 0      divisio… 1:08PM   
#> # ℹ 33 more rows
#> # ℹ 25 more variables: daynight <chr>, innings <chr>, tiebreaker <chr>,
#> #   usedh <chr>, umphome <chr>, ump1b <chr>, ump2b <chr>, ump3b <chr>,
#> #   umplf <chr>, umprf <chr>, inputtime <chr>, howscored <chr>, pitches <chr>,
#> #   oscorer <chr>, temp <chr>, winddir <chr>, windspeed <chr>, fieldcond <chr>,
#> #   precip <chr>, sky <chr>, timeofgame <chr>, attendance <chr>, wp <chr>,
#> #   lp <chr>, save <chr>
```

``` r
# One row per play
plays <- get_plays(events)
plays
#> # A tibble: 3,978 × 11
#>    game_id      record_type line_number  year type  inning  team player_id count
#>    <chr>        <chr>             <int> <dbl> <chr>  <int> <int> <chr>     <chr>
#>  1 NYA202410140 play                 55  2024 post       1     0 kwans001  32   
#>  2 NYA202410140 play                 56  2024 post       1     0 fry-d001  20   
#>  3 NYA202410140 play                 57  2024 post       1     0 ramij003  21   
#>  4 NYA202410140 play                 58  2024 post       1     0 thoml002  22   
#>  5 NYA202410140 play                 59  2024 post       1     0 thoml002  32   
#>  6 NYA202410140 play                 60  2024 post       1     1 torrg001  00   
#>  7 NYA202410140 play                 61  2024 post       1     1 sotoj001  12   
#>  8 NYA202410140 play                 62  2024 post       1     1 judga001  12   
#>  9 NYA202410140 play                 63  2024 post       1     1 wella002  12   
#> 10 NYA202410140 play                 64  2024 post       1     1 stanm004  21   
#> # ℹ 3,968 more rows
#> # ℹ 2 more variables: pitches <chr>, event <chr>
```

``` r
# Interpret the event notation: event types, batting flags, outs, runs, RBI
parsed <- parse_plays(plays)
parsed |>
  count(event_type, sort = TRUE)
#> # A tibble: 21 × 2
#>    event_type       n
#>    <chr>        <int>
#>  1 generic_out   1459
#>  2 strikeout      739
#>  3 no_play        599
#>  4 single         443
#>  5 walk           309
#>  6 double         107
#>  7 home_run        98
#>  8 stolen_base     57
#>  9 hit_by_pitch    44
#> 10 wild_pitch      26
#> # ℹ 11 more rows
```

``` r
# Or go straight to full game state: outs, runners, and score before
# every play (the foundation for run expectancy and leverage)
states <- track_game_state(events)
states
#> # A tibble: 3,978 × 36
#>    game_id      record_type line_number  year type  inning  team player_id count
#>    <chr>        <chr>             <int> <dbl> <chr>  <int> <int> <chr>     <chr>
#>  1 NYA202410140 play                 55  2024 post       1     0 kwans001  32   
#>  2 NYA202410140 play                 56  2024 post       1     0 fry-d001  20   
#>  3 NYA202410140 play                 57  2024 post       1     0 ramij003  21   
#>  4 NYA202410140 play                 58  2024 post       1     0 thoml002  22   
#>  5 NYA202410140 play                 59  2024 post       1     0 thoml002  32   
#>  6 NYA202410140 play                 60  2024 post       1     1 torrg001  00   
#>  7 NYA202410140 play                 61  2024 post       1     1 sotoj001  12   
#>  8 NYA202410140 play                 62  2024 post       1     1 judga001  12   
#>  9 NYA202410140 play                 63  2024 post       1     1 wella002  12   
#> 10 NYA202410140 play                 64  2024 post       1     1 stanm004  21   
#> # ℹ 3,968 more rows
#> # ℹ 27 more variables: pitches <chr>, event <chr>, event_type <chr>,
#> #   is_plate_appearance <lgl>, is_at_bat <lgl>, is_hit <lgl>, hit_value <int>,
#> #   fielded_by <int>, hit_location <chr>, trajectory <chr>, is_bunt <lgl>,
#> #   is_sac_fly <lgl>, is_sac_hit <lgl>, is_gdp <lgl>, outs_on_play <int>,
#> #   runs_on_play <int>, rbi <int>, batter_dest <int>, runner1_dest <int>,
#> #   runner2_dest <int>, runner3_dest <int>, outs_before <int>, …
```

### Game Logs, Rosters, and Schedules

``` r
# Game logs: one row per game with 161 summary fields.
# Scores and counting stats are integers, ready for analysis:
gamelogs <- get_gamelogs(year = 2024)
gamelogs |>
  summarize(home_win_pct = mean(home_score > visiting_score))
#> # A tibble: 1 × 1
#>   home_win_pct
#>          <dbl>
#> 1        0.522
```

``` r
# Team rosters by year
get_rosters(year = 2024, team = "NYA")
#> # A tibble: 54 × 8
#>    player_id last_name first_name bats  throws team  position  year
#>    <chr>     <chr>     <chr>      <chr> <chr>  <chr> <chr>    <dbl>
#>  1 andrc002  Andrews   Clayton    L     L      NYA   P         2024
#>  2 beetc001  Beeter    Clayton    R     R      NYA   P         2024
#>  3 bertj001  Berti     Jon        R     R      NYA   3B        2024
#>  4 bickp001  Bickford  Phil       R     R      NYA   P         2024
#>  5 burdn001  Burdi     Nick       R     R      NYA   P         2024
#>  6 cabro002  Cabrera   Oswaldo    B     R      NYA   3B        2024
#>  7 chisj001  Chisholm  Jazz       L     R      NYA   3B        2024
#>  8 coleg001  Cole      Gerrit     R     R      NYA   P         2024
#>  9 cortn001  Cortes    Nestor     R     L      NYA   P         2024
#> 10 cousj001  Cousins   Jake       R     R      NYA   P         2024
#> # ℹ 44 more rows
```

``` r
# Season schedules, including postponements and makeup dates
schedule <- get_schedules(year = 2024)
schedule |> filter(!is.na(postponed))
#> # A tibble: 35 × 14
#>    date     game_number day_of_week visiting_team visiting_league
#>    <chr>          <int> <chr>       <chr>         <chr>          
#>  1 20240328           0 Thursday    MIL           NL             
#>  2 20240328           0 Thursday    ATL           NL             
#>  3 20240402           0 Tuesday     DET           AL             
#>  4 20240403           0 Wednesday   ATL           NL             
#>  5 20240403           0 Wednesday   DET           AL             
#>  6 20240407           0 Sunday      CLE           AL             
#>  7 20240410           0 Wednesday   NYN           NL             
#>  8 20240411           0 Thursday    MIL           NL             
#>  9 20240411           0 Thursday    MIN           AL             
#> 10 20240412           0 Friday      NYA           AL             
#> # ℹ 25 more rows
#> # ℹ 9 more variables: visiting_game_number <int>, home_team <chr>,
#> #   home_league <chr>, home_game_number <int>, day_night <chr>, location <chr>,
#> #   postponed <chr>, makeup_date <chr>, year <dbl>
```

### Reference Data

``` r
parks <- get_park_ids()     # ballpark codes and locations
teams <- get_team_ids(2024) # team codes for a season
players <- get_player_ids() # player biographical database

parks |> filter(grepl("Fenway", name))
#> # A tibble: 1 × 9
#>   park_id name        aka   city   state start      end   league notes          
#>   <chr>   <chr>       <chr> <chr>  <chr> <chr>      <chr> <chr>  <chr>          
#> 1 BOS07   Fenway Park <NA>  Boston MA    04/20/1912 <NA>  AL     BOS:1912-date;…
```

## Workflow Example

A complete workflow to analyze recent World Series games:

``` r
# Get recent post-season data
postseason <- list_events(year = 2020:2024, type = "post") |>
  get_events()

# World Series games are played at the two pennant winners' parks in
# late October; the gametype info record identifies them directly
games <- get_game_info(postseason)
world_series <- games |> filter(gametype == "worldseries")

# Home run leaders across five World Series, from the raw play-by-play
get_plays(postseason) |>
  semi_join(world_series, by = "game_id") |>
  parse_plays() |>
  filter(event_type == "home_run") |>
  count(player_id, sort = TRUE) |>
  left_join(
    get_player_ids() |> select(player_id, first_name, last_name),
    by = "player_id"
  )
#> # A tibble: 46 × 4
#>    player_id     n first_name              last_name
#>    <chr>     <int> <chr>                   <chr>    
#>  1 freef001      6 Frederick Charles       Freeman  
#>  2 seagc001      5 Corey Drew              Seager   
#>  3 arozr001      3 Randy                   Arozarena
#>  4 loweb001      3 Brandon Norman          Lowe     
#>  5 schwk001      3 Kyle Joseph             Schwarber
#>  6 solej001      3 Jorge Carlos (Castillo) Soler    
#>  7 altuj001      2 Jose Carlos             Altuve   
#>  8 bettm001      2 Markus Lynn             Betts    
#>  9 darnt001      2 Travis Emmanuel         d'Arnaud 
#> 10 duvaa001      2 Adam Lynn               Duvall   
#> # ℹ 36 more rows
```

## Data Types

### Play-by-Play Events

Detailed play-by-play data (the core of Retrosheet). Event files contain
several types of records, which `get_events()` reads into a tidy tibble
and `parse_event_records()` / `get_plays()` / `get_game_info()`
interpret. `parse_plays()` then turns the play notation itself into
typed columns (event type, batting statistics, outs, runs, RBI, runner
advancement), and `track_game_state()` attaches the pre-play situation
(outs, runner identities, score) by replaying each game. Both are
validated against Chadwick’s `cwevent`:

- **`id`**: Game identifier
- **`info`**: Game metadata (date, teams, site, attendance, …)
- **`start`** / **`sub`**: Starting lineups and substitutions
- **`play`**: Play-by-play events (the heart of the data)
- **`com`**: Comments
- **`data`**: Earned run data

See the [Retrosheet Format
Reference](https://tgerke.github.io/retrosheetshow/articles/RETROSHEET_FORMAT.html)
article for the notation.

### Game Logs

Summary statistics for each game (one row per game, 161 fields): team
statistics, pitcher decisions, starting lineups, umpires, attendance,
and more. Much smaller and faster than event files.

### Rosters and Schedules

Team rosters by year (names, IDs, bats/throws, position) and season
schedules (dates, teams, day/night, postponements with makeup dates).

## Caching

Downloads are cached across R sessions under
`tools::R_user_dir("retrosheetshow", "cache")`, so only the first call
for a given file touches the network:

``` r
cache_status() # view cached files
clear_cache()  # remove them
use_cache(FALSE) # disable for this session
```

## Data Coverage

Retrosheet has digitized data spanning over a century:

- **Regular season events**: 1911 onward
- **All-Star games**: 1933 onward (no game in 1945 or 2020)
- **Post-season**: 1903 onward (no World Series in 1904 or 1994)
- **Game logs**: 1871 onward
- **Schedules**: 1877 onward

See the [Retrosheet website](https://www.retrosheet.org/game.htm) for
complete details on data availability.

## Retrosheet Attribution

**This package uses Retrosheet data.** Per Retrosheet’s requirements,
this notice must appear prominently:

> The information used here was obtained free of charge from and is
> copyrighted by Retrosheet. Interested parties may contact Retrosheet
> at 20 Sunset Rd., Newark, DE 19711.

Retrosheet is an all-volunteer 501(c)(3) charitable organization. To
support their work, visit [retrosheet.org](https://www.retrosheet.org)
or [donate](https://www.retrosheet.org/donate/index.html).

The retrosheetshow package is not affiliated with Retrosheet but is
grateful for their work in preserving baseball history.

## Related Resources

### Retrosheet Documentation

- [Retrosheet home](https://www.retrosheet.org)
- [Event file documentation](https://www.retrosheet.org/eventfile.htm)
- [Game log field
  descriptions](https://www.retrosheet.org/gamelogs/glfields.txt)

### Related Baseball Data Packages

**R Packages:**

- [**Lahman**](https://cdalzell.github.io/Lahman/) - R package for Sean
  Lahman’s Baseball Database with historical player and team statistics
- [**baseballr**](https://billpetti.github.io/baseballr/) - Functions
  for scraping and analyzing baseball data from FanGraphs, Baseball
  Reference, and Statcast
- [**mlbgameday**](https://github.com/keberwein/mlbgameday) - R package
  for accessing MLB GameDay data

**Python Packages:**

- [**pybaseball**](https://github.com/jldbc/pybaseball) - Python package
  for baseball data analysis with Statcast, FanGraphs, and Baseball
  Reference scrapers
- [**collegebaseball**](https://github.com/nathanblumenfeld/collegebaseball) -
  Python tools for college baseball data

## License

MIT + file LICENSE
