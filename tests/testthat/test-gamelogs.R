test_that("gamelog field names and descriptions stay in sync", {
  fields <- gamelog_field_names()

  # the Retrosheet game log specification defines 161 fields
  expect_length(fields, 161)
  expect_false(any(duplicated(fields)))

  descriptions <- gamelog_fields()
  expect_equal(descriptions$field_name, fields)
  expect_false(anyNA(descriptions$description))

  # one compact col_types character per field
  expect_equal(nchar(gamelog_col_types()), 161)
})

test_that("read_gamelog_file types scores and counting stats", {
  logs <- read_gamelog_file(
    test_path("fixtures", "gl2024-excerpt.txt"),
    year = 2024
  )

  expect_equal(nrow(logs), 3)
  expect_equal(ncol(logs), 162) # 161 fields + year

  expect_equal(logs$date[1], "20240320")
  expect_equal(logs$visiting_team[1], "LAN")
  expect_equal(logs$home_team[1], "SDN")

  expect_type(logs$visiting_score, "integer")
  expect_type(logs$home_score, "integer")
  expect_type(logs$attendance, "integer")
  expect_type(logs$visiting_hr, "integer")
  expect_equal(logs$visiting_score[1], 5L)
  expect_equal(logs$home_score[1], 2L)

  # so comparisons are numeric, not alphabetical
  expect_type(logs$home_score > logs$visiting_score, "logical")

  expect_type(logs$winning_pitcher_name, "character")
  expect_type(logs$park_id, "character")
})
