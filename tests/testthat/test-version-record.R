# 4d: recorded_version(root) (G32): the weft_version a project records in
# _weft.yml, read as text; NA when there is none.

rv <- function(lines = NULL) {
  d <- u4_dir()
  if (!is.null(lines)) writeLines(lines, file.path(d, "_weft.yml"))
  weft:::recorded_version(d)
}

test_that("4d G32: no _weft.yml records nothing: NA", {
  expect_true(is.na(rv()))
})

test_that("4d G32: a _weft.yml without the key records nothing: NA", {
  expect_true(is.na(rv(c("digits: 2", "serial_comma: true"))))
  expect_true(is.na(rv(character())))
})

test_that("4d G32: an unquoted version is read", {
  expect_identical(rv(c("digits: 2", "weft_version: 0.1.0")), "0.1.0")
})

test_that("4d G32: a double-quoted and a single-quoted version are read without the quotes", {
  expect_identical(rv("weft_version: \"0.2.1\""), "0.2.1")
  expect_identical(rv("weft_version: '0.2.1'"), "0.2.1")
})

test_that("4d G32: a version with a build part and one followed by a comment are read whole", {
  expect_identical(rv("weft_version: 0.1.0.9000"), "0.1.0.9000")
  expect_identical(rv("weft_version: 0.1.0   # set up by use_setup()"), "0.1.0")
  expect_identical(rv("weft_version: \"0.1.0\"  # note"), "0.1.0")
})

test_that("4d G32: the key may be anywhere in the file", {
  expect_identical(rv(c("# weft settings", "weft_version: 3.4.5", "digits: 1")), "3.4.5")
  expect_identical(rv(c("digits: 1", "", "weft_version: 3.4.5")), "3.4.5")
})

test_that("4d G32: a commented-out key and `null` (the default of G31) record nothing", {
  expect_true(is.na(rv("# weft_version: 0.1.0")))
  expect_true(is.na(rv("weft_version: null")))
  expect_true(is.na(rv("weft_version:")))
})

test_that("4d G32: the value is text: a version that is also a number keeps its spelling", {
  expect_identical(rv("weft_version: 1.10"), "1.10")
})

test_that("4d G32: the file is read as text and not parsed: a file that is not valid YAML elsewhere still yields the version", {
  expect_identical(rv(c("weft_version: 0.1.0", "units: {unclosed")), "0.1.0")
})

test_that("4d G32: reading writes nothing", {
  d <- u4_dir(list(`_weft.yml` = "weft_version: 0.1.0"))
  before <- u4_md5(d)
  weft:::recorded_version(d)
  expect_identical(u4_md5(d), before)
})
