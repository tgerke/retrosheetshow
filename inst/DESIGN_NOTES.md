# Package Design Notes

## Architecture Overview

The `retrosheetshow` package follows a layered architecture with clear separation of concerns:

```
User-Facing Functions
  ├── list_events()        # Discovery layer
  ├── get_events()         # Download/parse layer
  ├── get_game_info()      # Extraction helpers
  ├── get_plays()          # Extraction helpers
  └── parse_event_records()# Manual parsing
  
Internal Helpers (R/utils.R)
  ├── construct_event_url()
  ├── url_exists()
  └── get_available_years()
  
Parsing Functions (R/parse_events.R)
  ├── parse_record_by_type()
  ├── parse_info_record()
  ├── parse_start_record()
  ├── parse_play_record()
  ├── parse_sub_record()
  └── parse_data_record()
  
Core Parsing (R/get_events.R)
  ├── parse_event_file()
  └── extract_game_id()
```

## Design Principles

### 1. Tidyverse-First

Every function returns a tibble and works seamlessly with the pipe operator (`|>` or `%>%`):

```r
list_events(year = 2024) |>
  get_events() |>
  get_plays()
```

### 2. Progressive Disclosure

Users can work at different levels of abstraction:

- **Simple**: `get_events(year = 2024)` - Just get the data
- **Intermediate**: `list_events() |> filter(year > 2020) |> get_events()` - Discover then fetch
- **Advanced**: `parse_event_records(events, record_types = "play")` - Manual control

### 3. Fail Gracefully

- Network errors return empty tibbles with warnings
- Invalid years are caught early
- Missing files are reported but don't crash the session

### 4. Performance Considerations

- Availability checking is optional (can be disabled for speed)
- Downloads happen in parallel where possible
- Temporary files are cleaned up automatically
- Progress feedback via `cli` package

## Key Design Decisions

### Why httr2 over httr?

- Modern API with better request building
- Better error handling
- Pipe-friendly interface
- Active development

### Why Parse to Long Format First?

The raw Retrosheet format is inherently line-oriented. We parse to long format first (one row per line) and provide helpers to reshape:

```r
# Raw format preserved
events <- get_events(year = 2024)
# record_type | fields (list-column) | game_id | year

# Helpers for specific formats
games <- get_game_info(events)  # Wide format, one row per game
plays <- get_plays(events)       # One row per play
```

This approach:
- Preserves all data without loss
- Allows flexible downstream parsing
- Maintains traceability to source lines

### Why List-Columns?

Retrosheet records have varying field counts. List-columns let us:
- Store variable-length data without waste
- Delay parsing until needed
- Preserve original structure
- Enable type-safe parsing later

### URL Construction Strategy

URLs follow predictable patterns:
- Regular season: `https://www.retrosheet.org/events/{year}eve.zip`
- All-star: `https://www.retrosheet.org/events/{year}as.zip`
- Post-season: `https://www.retrosheet.org/events/{year}post.zip`

We use `construct_event_url()` as a single source of truth.

### Error Handling Strategy

Three-level approach:

1. **Validate early**: Check parameters before making requests
2. **Fail gracefully**: Network errors become warnings + empty tibbles
3. **Inform users**: `cli` messages explain what happened

```r
tryCatch({
  # Download attempt
}, error = function(e) {
  cli::cli_warn("Failed to download {year}: {e$message}")
  tibble::tibble()
})
```

## File Organization

```
retrosheetshow/
├── R/
│   ├── retrosheetshow-package.R  # Package-level docs + imports
│   ├── list_events.R             # Discovery functions
│   ├── get_events.R              # Download + basic parsing
│   ├── parse_events.R            # Advanced parsing helpers
│   ├── utils.R                   # Internal utilities
│   └── zzz.R                     # Package startup
├── inst/
│   └── RETROSHEET_FORMAT.md      # Format reference
├── examples/
│   └── getting_started.R         # Usage examples
├── man/                           # Generated documentation
├── DESCRIPTION                    # Package metadata
├── NAMESPACE                      # Generated exports
├── README.md                      # User-facing intro
├── NEWS.md                        # Changelog
├── INSTALL.md                     # Installation guide
└── DESIGN_NOTES.md               # This file
```

## Function Naming Conventions

- `list_*()` - Discovery/listing functions (read-only, fast)
- `get_*()` - Fetch/download functions (network access, slower)
- `parse_*()` - Parsing/transformation functions (local, fast)

## Dependencies Rationale

### Core Dependencies

- **httr2**: Modern HTTP client for downloads
- **readr**: Fast file reading with good encoding handling
- **dplyr**: Data manipulation (filter, select, mutate, etc.)
- **tidyr**: Data reshaping (pivot, unnest, fill)
- **tibble**: Modern data frames
- **purrr**: Functional programming tools
- **stringr**: String manipulation
- **cli**: User feedback and progress bars
- **glue**: String interpolation
- **scales**: Number formatting
- **rlang**: Non-standard evaluation (`.data`)

### Why NOT use rvest?

Initially suggested, but not needed because:
- Retrosheet URLs are predictable (no scraping required)
- Files are direct downloads (ZIP format)
- No HTML parsing needed

Kept in IMPORTS for potential future features (scraping available years dynamically).

## Extension Points

The package is designed for easy extension:

### Adding New Event Types

```r
# In utils.R, extend construct_event_url()
construct_event_url <- function(year, type) {
  # ... existing code ...
  filename <- switch(type,
    regular = glue::glue("{year}eve.zip"),
    allstar = glue::glue("{year}as.zip"),
    post = glue::glue("{year}post.zip"),
    negro = glue::glue("{year}nl.zip")  # Add new type
  )
}
```

### Adding New Parsers

```r
# In parse_events.R, add to parse_record_by_type()
parse_record_by_type <- function(type, fields) {
  result <- switch(type,
    # ... existing parsers ...
    "newtype" = parse_newtype_record(fields)
  )
}

# Create dedicated parser
parse_newtype_record <- function(fields) {
  list(
    field1 = fields[1],
    field2 = if (length(fields) > 1) fields[2] else NA
  )
}
```

### Adding Convenience Functions

```r
# New file: R/convenience.R
#' Get Home Runs
#' @export
get_home_runs <- function(events_data) {
  events_data |>
    get_plays() |>
    dplyr::filter(stringr::str_detect(event, "^HR"))
}
```

## Testing Strategy

Suggested test structure (not yet implemented):

```r
# tests/testthat/test-list_events.R
test_that("list_events returns tibble", {
  result <- list_events(year = 2024, check_availability = FALSE)
  expect_s3_class(result, "tbl_df")
})

# tests/testthat/test-url_construction.R
test_that("URLs are constructed correctly", {
  url <- construct_event_url(2024, "regular")
  expect_equal(url, "https://www.retrosheet.org/events/2024eve.zip")
})

# Mock tests for network calls
test_that("get_events handles network errors", {
  # Use httptest or webmockr to mock responses
})
```

## Performance Considerations

### Memory Usage

Large multi-year downloads can consume significant memory:

- 1 year regular season: ~50-100 MB uncompressed
- 10 years: ~500 MB - 1 GB
- Full history (100+ years): Several GB

Mitigation strategies:
- Download years individually
- Filter immediately after download
- Use `rm()` and `gc()` for intermediate results

### Download Speed

Factors affecting speed:
- Network connection
- Retrosheet server load
- Number of files requested
- Whether availability checking is enabled

Optimization:
- Set `check_availability = FALSE` when URLs are known
- Download during off-peak hours
- Cache results locally for reuse

## Future Enhancements

Potential additions:

1. **Caching**: Local cache of downloaded files
2. **Box Score Format**: Support for pre-1911 data
3. **Game Logs**: Daily logs and game logs
4. **Player IDs**: Helper functions to look up player IDs
5. **Team Codes**: Helper functions for team abbreviations
6. **Advanced Stats**: Calculate derived statistics
7. **Visualization**: Integration with ggplot2
8. **Database Export**: Export to SQLite/PostgreSQL

## Contributing Guidelines

When contributing:

1. Follow tidyverse style guide
2. Use roxygen2 for documentation
3. Include examples in function docs
4. Add tests for new features
5. Update NEWS.md
6. Run `devtools::check()` before submitting

## References

- [Tidyverse Design Guide](https://design.tidyverse.org/)
- [R Packages Book](https://r-pkgs.org/)
- [Retrosheet Documentation](https://www.retrosheet.org/eventfile.htm)
- [httr2 Documentation](https://httr2.r-lib.org/)

