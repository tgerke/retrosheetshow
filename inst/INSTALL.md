# Installation and Setup

## Prerequisites

The `retrosheetshow` package requires R version 4.0.0 or higher and depends on several tidyverse packages.

## Installation

### From GitHub (Development Version)

```r
# Install remotes if you don't have it
install.packages("remotes")

# Install retrosheetshow
remotes::install_github("yourusername/retrosheetshow")
```

### Install Dependencies Separately (if needed)

```r
install.packages(c(
  "httr2",
  "rvest", 
  "readr",
  "dplyr",
  "tibble",
  "tidyr",
  "purrr",
  "stringr",
  "cli",
  "glue",
  "scales",
  "rlang"
))
```

## Quick Start

```r
library(retrosheetshow)

# List available 2024 regular season data
list_events(year = 2024)

# Download and parse the data
events <- get_events(year = 2024)

# Extract game information
games <- get_game_info(events)

# Get play-by-play data
plays <- get_plays(events)
```

## Verifying Installation

Run this to verify the package is working:

```r
library(retrosheetshow)

# Should return a tibble of available files
test <- list_events(year = 2024, check_availability = FALSE)
print(test)

# If this works, installation is successful!
```

## Troubleshooting

### Network Issues

If downloads fail, check your internet connection and firewall settings. The package needs to access `https://www.retrosheet.org`.

### Memory Issues

For large multi-year downloads, you may need to increase R's memory limit:

```r
# Increase memory limit (Windows)
memory.limit(size = 16000)

# Or download years individually
events_2023 <- get_events(year = 2023)
events_2024 <- get_events(year = 2024)
all_events <- bind_rows(events_2023, events_2024)
```

### Package Load Errors

If you get namespace errors, try reinstalling with dependencies:

```r
remotes::install_github("yourusername/retrosheetshow", 
                       dependencies = TRUE,
                       force = TRUE)
```

## Development Setup

If you want to contribute or modify the package:

```r
# Clone the repository
# git clone https://github.com/yourusername/retrosheetshow.git
# cd retrosheetshow

# Install development dependencies
install.packages(c("devtools", "roxygen2", "testthat", "pkgdown"))

# Load the package for development
devtools::load_all()

# Run tests
devtools::test()

# Build documentation
devtools::document()

# Check package
devtools::check()
```

## Next Steps

- Read the [README](README.md) for usage examples
- Check [examples/getting_started.R](examples/getting_started.R) for detailed examples
- Review [inst/RETROSHEET_FORMAT.md](inst/RETROSHEET_FORMAT.md) to understand the data format
- See [NEWS.md](NEWS.md) for latest changes

## Getting Help

- Check function documentation: `?list_events`, `?get_events`
- Review examples: `example(list_events)`
- Visit the [Retrosheet website](https://www.retrosheet.org) for data documentation

## License

[Your chosen license]

## Citation

If you use this package in research, please cite both the package and Retrosheet:

```
# Package citation
citation("retrosheetshow")

# Retrosheet data attribution (required)
The information used here was obtained free of charge from and is 
copyrighted by Retrosheet. Interested parties may contact Retrosheet 
at 20 Sunset Rd., Newark, DE 19711.
```

