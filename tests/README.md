# retrosheetshow Tests

This directory contains the test suite for the retrosheetshow package.

## Test Structure

The tests are organized into the following files:

### Core Functionality Tests

- **`test-utils.R`** - Tests for utility functions
  - URL construction (`construct_event_url`)
  - Base URL retrieval
  - Year range functions (`get_available_years`)
  - Input validation

- **`test-cache.R`** - Tests for cache management
  - Cache directory management
  - Cache file path construction
  - Cache status and clearing
  - Caching enable/disable functionality

- **`test-parse.R`** - Tests for parsing functions
  - Info record parsing
  - Play record parsing
  - Substitution record parsing
  - Starting lineup parsing
  - Data record parsing
  - Edge cases and error handling

- **`test-list-events.R`** - Tests for event listing
  - Event file listing
  - Multiple year and type handling
  - URL construction
  - Sorting and filtering

- **`test-gamelogs.R`** - Tests for gamelog functions
  - Gamelog field descriptions
  - Gamelog file listing
  - URL construction
  - (Integration tests for downloading - skipped offline)

### Integration Tests

- **`test-integration.R`** - Network-dependent integration tests
  - URL existence checking
  - File downloading
  - End-to-end data retrieval
  - Cache performance verification
  
  **Note:** These tests are automatically skipped when:
  - No internet connection is available
  - Running on CRAN (via `skip_on_cran()`)

### Helper Files

- **`helper.R`** - Shared helper functions
  - `skip_if_offline()` - Skip tests when no internet
  - `has_internet()` - Check for internet connectivity

## Running Tests

### Run all tests

```r
devtools::test()
```

### Run specific test file

```r
testthat::test_file("tests/testthat/test-utils.R")
```

### Run with coverage

```r
covr::package_coverage()
```

## Test Results

- **97 passing tests** - Core functionality
- **10 skipped tests** - Network-dependent tests (skipped when offline)
- **0 failures**

## Test Philosophy

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test complete workflows (marked with `skip_if_offline()`)
3. **Edge Cases**: Test error handling and boundary conditions
4. **CRAN-Friendly**: Network tests are skipped on CRAN

## Adding New Tests

When adding new functions, please add corresponding tests:

```r
test_that("descriptive test name", {
  # Arrange
  input <- setup_test_data()
  
  # Act
  result <- my_function(input)
  
  # Assert
  expect_equal(result, expected_value)
})
```

For functions requiring network access:

```r
test_that("network-dependent function works", {
  skip_if_offline()
  skip_on_cran()
  
  result <- download_data()
  expect_s3_class(result, "tbl_df")
})
```

## Test Coverage

The test suite covers:

- ✅ URL construction and validation
- ✅ Cache management
- ✅ Record parsing (all types)
- ✅ Event listing and filtering
- ✅ Gamelog functionality
- ✅ Error handling
- ✅ Edge cases
- ✅ Integration workflows (when online)

## CI/CD

Tests are automatically run on:
- Every commit (local development)
- Pull requests (GitHub Actions)
- CRAN submission checks

Network-dependent tests are skipped in CI environments without internet access.

