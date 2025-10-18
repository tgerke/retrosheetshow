# Retrosheet Event File Format Reference

This document provides a quick reference for understanding Retrosheet event file formats and how they are parsed by `retrosheetshow`.

## Record Types

Retrosheet event files contain several types of records, each on a separate line:

### `id` - Game Identifier

Format: `id,GAMEID`

Example: `id,NYA202304070`

- First 3 characters: Home team code
- Next 4 digits: Year
- Next 2 digits: Month
- Next 2 digits: Day
- Last digit: Game number (0 for single game, 1-2 for doubleheaders)

### `version` - File Format Version

Format: `version,VERSION`

Example: `version,2`

Indicates the version of the Retrosheet event file format.

### `info` - Game Information

Format: `info,TYPE,VALUE`

Examples:
- `info,visteam,BOS` - Visiting team code
- `info,hometeam,NYA` - Home team code
- `info,date,2023/04/07` - Game date
- `info,number,0` - Game number
- `info,site,NYA03` - Ballpark code
- `info,starttime,7:05PM` - Start time
- `info,daynight,night` - Day or night game
- `info,usedh,true` - Designated hitter used
- `info,umphome,smithj01` - Home plate umpire
- `info,temp,72` - Temperature
- `info,winddir,torf` - Wind direction
- `info,windspeed,10` - Wind speed
- `info,fieldcond,unknown` - Field condition
- `info,precip,unknown` - Precipitation
- `info,sky,unknown` - Sky condition
- `info,timeofgame,180` - Game duration in minutes
- `info,attendance,45678` - Attendance

### `start` - Starting Lineup

Format: `start,PLAYERID,"PLAYERNAME",TEAM,BATTINGPOS,FIELDPOS`

Example: `start,judga001,"Aaron Judge",0,1,9`

- PLAYERID: Retrosheet player ID
- PLAYERNAME: Player's name (in quotes)
- TEAM: 0 for visiting team, 1 for home team
- BATTINGPOS: Position in batting order (1-9)
- FIELDPOS: Defensive position (1-10, see below)

### `play` - Play-by-Play Event

Format: `play,INNING,TEAM,PLAYERID,COUNT,PITCHES,EVENT`

Example: `play,1,0,judga001,22,BCFBX,S7/G`

- INNING: Inning number (top of 1st inning is 1)
- TEAM: 0 for visiting team, 1 for home team
- PLAYERID: Batter's Retrosheet ID
- COUNT: Balls and strikes (e.g., "32" = 3 balls, 2 strikes)
- PITCHES: Sequence of pitches (B=ball, C=called strike, S=swinging strike, etc.)
- EVENT: Play outcome (complex notation, see below)

### `sub` - Substitution

Format: `sub,PLAYERID,"PLAYERNAME",TEAM,BATTINGPOS,FIELDPOS`

Example: `sub,carpe001,"Carpenter",0,3,5`

Same format as `start` but indicates a substitution.

### `com` - Comment

Format: `com,"COMMENT TEXT"`

Example: `com,"$Hit hard to left field"`

Contains additional information or annotations.

### `data` - Additional Data

Format: `data,TYPE,PLAYERID,VALUE`

Example: `data,er,judga001,2`

- TYPE: Usually "er" for earned runs
- PLAYERID: Player ID
- VALUE: Numeric value

## Defensive Positions

1. Pitcher
2. Catcher
3. First Base
4. Second Base
5. Third Base
6. Shortstop
7. Left Field
8. Center Field
9. Right Field
10. Designated Hitter
11. Pinch Hitter
12. Pinch Runner

## Event Codes (Common Examples)

Retrosheet uses a detailed notation system for events. Here are common examples:

### Basic Outcomes

- `S7` - Single to left field (7)
- `D8` - Double to center field (8)
- `T9` - Triple to right field (9)
- `HR` - Home run
- `K` - Strikeout
- `W` - Walk
- `HP` - Hit by pitch
- `E5` - Error on third baseman (5)

### Outs

- `3/G` - Ground out to first baseman (3)
- `8/F` - Fly out to center fielder (8)
- `6-3` - Ground out, shortstop (6) to first baseman (3)
- `4-3` - Ground out, second baseman (4) to first baseman (3)
- `K` - Strikeout

### Advanced Plays

- `S7/L` - Line drive single to left
- `D9/F` - Fly ball double to right
- `HR/F` - Fly ball home run
- `64(1)3/GDP` - Ground into double play, 6-4-3, runner on first out
- `FC5/G` - Fielder's choice, ground ball to third
- `SB2` - Stolen base, second
- `CS2(26)` - Caught stealing second, catcher (2) to shortstop (6)

### Modifiers

- `/G` - Ground ball
- `/F` - Fly ball
- `/L` - Line drive
- `/P` - Pop up
- `/BG` - Bunt, ground ball
- `.1-3` - Runner advances from first to third
- `.2-H` - Runner scores from second
- `.3XH(92)` - Runner out at home from third, right fielder (9) to catcher (2)

## Using retrosheetshow with Event Codes

```r
library(retrosheetshow)
library(dplyr)
library(stringr)

# Get 2024 data
events_2024 <- get_events(year = 2024)
plays <- get_plays(events_2024)

# Find all home runs
home_runs <- plays |>
  filter(str_detect(event, "^HR"))

# Find all strikeouts
strikeouts <- plays |>
  filter(str_detect(event, "^K"))

# Find all stolen bases
stolen_bases <- plays |>
  filter(str_detect(event, "SB[23H]"))

# Find ground into double plays
gdp <- plays |>
  filter(str_detect(event, "GDP"))
```

## Resources

- [Retrosheet Event File Documentation](https://www.retrosheet.org/eventfile.htm)
- [Retrosheet Home](https://www.retrosheet.org)
- [Play-by-Play Files](https://www.retrosheet.org/game.htm)
- [Team Codes](https://www.retrosheet.org/TEAMABR.TXT)
- [Ballpark Codes](https://www.retrosheet.org/parkcode.txt)

## Attribution

Per Retrosheet's requirements:

> The information used here was obtained free of charge from and is copyrighted by Retrosheet. Interested parties may contact Retrosheet at 20 Sunset Rd., Newark, DE 19711.

