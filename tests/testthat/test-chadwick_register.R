# The fixture rows are an excerpt of the Chadwick Baseball Bureau Register;
# fixtures/README.md gives its source and license.

unreachable <- function() "https://127.0.0.1:9/HEAD.zip"

test_that("read_chadwick_people types the ids and keeps names intact", {
  people <- read_chadwick_people(
    test_path("fixtures", "chadwick-people-excerpt.csv")
  )

  expect_named(
    people,
    c(
      "key_retro", "key_mlbam", "key_bbref", "key_fangraphs",
      "key_uuid", "key_person", "name_first", "name_last",
      "mlb_played_first", "mlb_played_last"
    )
  )
  expect_equal(nrow(people), 7)
  for (col in c("key_mlbam", "key_fangraphs", "mlb_played_first", "mlb_played_last")) {
    expect_type(people[[col]], "integer")
  }
  for (col in c("key_retro", "key_bbref", "key_uuid", "key_person", "name_first", "name_last")) {
    expect_type(people[[col]], "character")
  }

  judge <- people[people$key_retro %in% "judga001", ]
  expect_equal(judge$key_mlbam, 592450L)
  expect_equal(judge$key_bbref, "judgeaa01")
  expect_equal(judge$key_fangraphs, 15640L)
  expect_equal(judge$key_uuid, "06c9f502-3131-481f-b8ec-6a985c2ff7cd")
  expect_equal(judge$key_person, "06c9f502")
  expect_equal(judge$mlb_played_first, 2016L)

  # UTF-8 names come through, and a quoted comma stays inside its field
  expect_equal(
    people$name_last[people$key_retro %in% "hernl003"],
    "Hernández"
  )
  expect_equal(
    people$name_first[people$key_person == "6fee424d"],
    "Jr., Darian"
  )

  # empty fields are NA in character and integer columns alike
  brady <- people[people$key_retro %in% "bradu901", ]
  expect_true(is.na(brady$name_first))
  expect_true(is.na(brady$key_mlbam))
  expect_true(is.na(brady$mlb_played_first))

  # sorted by Retrosheet ID, with people who have none last
  expect_equal(
    people$key_retro,
    c("bradu901", "hernl003", "judga001", "ohtas001", "ruthb101", NA, NA)
  )
})

test_that("get_chadwick_register keeps people with a Retrosheet ID by default", {
  local_temp_cache()
  seed_register_zip()
  local_mocked_bindings(chadwick_register_url = unreachable)

  msgs <- capture_messages(ids <- get_chadwick_register())

  expect_equal(
    ids$key_retro,
    c("bradu901", "hernl003", "judga001", "ohtas001", "ruthb101")
  )
  expect_match(msgs, "Using cached", all = FALSE)
  expect_match(
    msgs,
    "Read 5 people from the Chadwick register \\(commit abc1234, downloaded",
    all = FALSE
  )

  everyone <- get_chadwick_register(retro_only = FALSE, verbose = FALSE)
  expect_equal(nrow(everyone), 7)
  expect_equal(sum(is.na(everyone$key_retro)), 2)
  expect_equal(sum(!is.na(everyone$key_mlbam)), 5)
})

test_that("refresh = TRUE replaces the cached copy with the current register", {
  local_temp_cache()
  # an older version of the register, before Ohtani reached the majors
  cached <- seed_register_zip(drop = "270bfa31")
  current <- make_register_zip(withr::local_tempfile(fileext = ".zip"))
  local_mocked_bindings(chadwick_register_url = \() file_url(current))

  expect_false("ohtas001" %in% get_chadwick_register(verbose = FALSE)$key_retro)

  refreshed <- get_chadwick_register(refresh = TRUE, verbose = FALSE)
  expect_true("ohtas001" %in% refreshed$key_retro)
  expect_equal(unname(tools::md5sum(cached)), unname(tools::md5sum(current)))
})

test_that("a failed refresh warns and keeps the cached copy", {
  local_temp_cache()
  cached <- seed_register_zip()
  before <- tools::md5sum(cached)
  local_mocked_bindings(chadwick_register_url = unreachable)

  expect_warning(
    out <- get_chadwick_register(refresh = TRUE, verbose = FALSE),
    "Failed to get the Chadwick register"
  )
  expect_equal(nrow(out), 0)
  expect_equal(tools::md5sum(cached), before)
  expect_equal(nrow(get_chadwick_register(verbose = FALSE)), 5)
})

test_that("with caching off the register is downloaded and not kept", {
  local_temp_cache()
  withr::local_options(retrosheetshow.use_cache = FALSE)
  current <- make_register_zip(withr::local_tempfile(fileext = ".zip"))
  local_mocked_bindings(chadwick_register_url = \() file_url(current))

  ids <- get_chadwick_register(verbose = FALSE)

  expect_equal(nrow(ids), 5)
  expect_length(list.files(cache_dir()), 0)
})
