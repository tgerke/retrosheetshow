test_that("count_pitches() counts pitches thrown in real sequences", {
  # from the 2024 World Series: pickoff throws (1), blocked-pitch (*) and
  # runner-going (>) markers, play markers (.), and an automatic walk
  expect_equal(
    count_pitches(c("BBSF1*BS", "C1>*B", "..CCBFX", "VVVV", "", NA)),
    c(6L, 2L, 5L, 0L, 0L, NA)
  )
})

test_that("every pitch code counts and every other code does not", {
  expect_equal(count_pitches("BCFHIKLMOPQRSTUXY"), 17L)
  # pickoffs, catcher pickoffs, markers, no pitch, automatic strike and ball
  expect_equal(count_pitches("123+1+2+3*.>NAV"), 0L)
})

test_that("count_pitches() warns about characters outside the pitch codes", {
  expect_warning(
    expect_equal(count_pitches(c("BB?X", "CX")), c(3L, 2L)),
    "not\\s+Retrosheet pitch codes"
  )
})

test_that("count_pitches() requires character input", {
  expect_snapshot(count_pitches(3), error = TRUE)
  expect_equal(count_pitches(NA), NA_integer_)
})
