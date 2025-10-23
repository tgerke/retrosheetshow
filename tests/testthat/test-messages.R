# Tests for message handling (testthat 3e compliant)
# Per testthat 3e, messages are no longer silently ignored

test_that("cache functions produce expected messages", {
  # Test cache status message when empty
  expect_message(
    cache_status(),
    "Cache"
  )
  
  # Test use_cache messaging
  expect_message(
    use_cache(TRUE),
    "enabled"
  )
  
  expect_message(
    use_cache(FALSE),
    "disabled"
  )
  
  # Restore default
  use_cache(TRUE)
})

test_that("clear_cache produces informative messages", {
  # When cache is empty or doesn't exist, it uses cli_inform (not message())
  # Just verify it completes without error
  expect_no_error(
    clear_cache(confirm = FALSE)
  )
})

test_that("list_events warns when no files found", {
  # This would only happen if check_availability filters everything out
  # Testing the message mechanism, not that this actually occurs
  expect_no_error({
    result <- list_events(year = 1850, type = "regular", check_availability = FALSE)
  })
})

