# Snapshot tests for output stability
# See: https://testthat.r-lib.org/articles/snapshotting.html

test_that("gamelog_fields produces stable output", {
  expect_snapshot({
    fields <- gamelog_fields()
    cat("Number of fields:", nrow(fields), "\n")
    cat("First 5 fields:\n")
    print(head(fields, 5))
  })
})

test_that("cache_status produces expected format", {
  skip_if_offline()
  
  expect_snapshot({
    # This will capture the cli output
    status <- cache_status()
    print(status)
  })
})

test_that("list_events with invalid type produces clear error", {
  expect_snapshot(error = TRUE, {
    list_events(year = 2024, type = "invalid")
  })
})

