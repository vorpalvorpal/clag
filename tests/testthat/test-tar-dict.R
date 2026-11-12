# Package 2e-1: a pipeline built with tar_dict() and tar_dict_deps(), run with tar_make()
# (dev/design-2e.md P3-P8, rules 4.6.1-4.6.4). Written before the code. Made-up values only.
# tar_make() runs in its default callr process, which sees the development weft through a
# temporary library, so this session never has `weft:dict` attached.

script <- function(f_body = "dict$a + 10", extra = character()) c(
  "library(targets)",
  sprintf("f <- function() %s", f_body),
  "c(weft::tar_dict(\"dict.yml\"),",
  "  weft::tar_dict_deps(list(",
  "    tar_target(t_a, dict$a + 1),",
  "    tar_target(t_fn, f()),",
  "    tar_target(t_b, dict$b * 2),",
  "    tar_target(t_none, 1),",
  "    tar_target(br, 1:3),",
  "    tar_target(t_pat, br * dict$b, pattern = map(br))",
  "  )))")

# One pipeline taken through a series of edits; each element holds the names built by that make.
tar_seq <- function() e1_memo("tar-seq", function() {
  skip_if_not_installed("targets")
  skip_on_cran()
  d <- e1_tmp()
  put <- function(vals = list(a = 1, b = 2), defs = list(a = "First."), f = "dict$a + 10") {
    e1_dict(d, vals, defs)
    writeLines(script(f), file.path(d, "_targets.R"))
  }
  out <- list(dir = d)
  put()
  out$first <- e1_make(d)
  out$second <- e1_make(d)
  put(list(a = 5, b = 2))
  out$a_value <- e1_make(d)
  out$t_fn_value <- withr::with_dir(d, targets::tar_read(t_fn))
  out$dict_a_value <- withr::with_dir(d, targets::tar_read(dict_a))
  put(list(a = 5, b = 2), list(a = "Changed definition."))
  out$a_definition <- e1_make(d)
  put(list(a = 5, b = 3), list(a = "Changed definition."))
  out$b_value <- e1_make(d)
  put(list(a = 5, b = 3, c = 9), list(a = "Changed definition."))
  out$new_key <- e1_make(d)
  put(list(b = 3, a = 5, c = 9), list(a = "Changed definition."))
  out$reordered <- e1_make(d)
  put(list(b = 3, a = 5, c = 9), list(a = "Changed definition."), f = "dict$a + 20")
  out$f_body <- e1_make(d)
  out$t_fn_value2 <- withr::with_dir(d, targets::tar_read(t_fn))
  out
})

test_that("2e-1 P4: the first make builds every target, a second builds none", {
  s <- tar_seq()
  expect_setequal(s$first, c("br", "t_a", "t_b", "t_fn", "t_none", "t_pat"))
  expect_identical(s$second, character())
})

test_that("2e-1 P7 (4.6.3): a changed value of `a` re-runs exactly its readers, through a function too", {
  s <- tar_seq()
  expect_identical(s$a_value, c("t_a", "t_fn"))
  expect_equal(s$t_fn_value, 15)
})

test_that("2e-1 P4 (4.6.3): a changed definition re-runs no reader", {
  expect_identical(tar_seq()$a_definition, character())
})

test_that("2e-1 P7 (4.6.3): a changed value of `b` re-runs t_b and the pattern t_pat, and nothing else", {
  expect_identical(tar_seq()$b_value, c("t_b", "t_pat"))
})

test_that("2e-1 P4 (4.6.3): a new key re-runs no reader, and neither does reordering the file", {
  s <- tar_seq()
  expect_identical(s$new_key, character())
  expect_identical(s$reordered, character())
})

test_that("2e-1 P7: a changed function body re-runs its target only", {
  s <- tar_seq()
  expect_identical(s$f_body, "t_fn")
  expect_equal(s$t_fn_value2, 25)
})

test_that("2e-1 P4: tar_read(dict_a) is the value the dictionary holds", {
  s <- tar_seq()
  expect_equal(s$dict_a_value, 5)
  d <- withr::local_tempdir()
  p <- e1_dict(d, list(a = 5, b = 2))
  expect_equal(s$dict_a_value, weft::read_dict(p)[["a"]])
})

test_that("2e-1 P4: dict_file, dict_<key> and the keys are in the store", {
  s <- tar_seq()
  m <- withr::with_dir(s$dir, targets::tar_meta(fields = "type"))
  expect_true(all(c("dict_file", "dict_values", "dict_a", "dict_b", "dict_c") %in% m$name))
})

test_that("2e-1 P5 (control): the same pipeline with a global dict runs under stock targets, which tracks the global", {
  skip_if_not_installed("targets")
  skip_on_cran()
  d <- e1_tmp()
  e1_dict(d)
  writeLines(c(
    "library(targets)",
    "dict <- list(a = list(value = 1, def = 'First.'), b = list(value = 2))",
    "list(tar_target(t_a, dict$a$value + 1), tar_target(t_none, 1))"), file.path(d, "_targets.R"))
  expect_setequal(e1_make(d), c("t_a", "t_none"))
  expect_identical(e1_make(d), character())
  # measured 1: a changed attribute of the tracked global re-runs the reader
  writeLines(c(
    "library(targets)",
    "dict <- list(a = list(value = 1, def = 'Changed.'), b = list(value = 2))",
    "list(tar_target(t_a, dict$a$value + 1), tar_target(t_none, 1))"), file.path(d, "_targets.R"))
  expect_identical(e1_make(d), "t_a")
})

test_that("2e-1 P5: a _targets.R that also holds `dict <- read_dict()` fails with the P5 message", {
  skip_if_not_installed("targets")
  skip_on_cran()
  d <- e1_tmp()
  e1_dict(d)
  writeLines(c(
    "library(targets)",
    "dict <- weft::read_dict(\"dict.yml\")",
    "c(weft::tar_dict(\"dict.yml\"), weft::tar_dict_deps(list(tar_target(t_a, dict$a + 1))))"),
    file.path(d, "_targets.R"))
  lib <- e1_libpath()
  e <- e1_err(withr::with_dir(d, targets::tar_make(
    callr_arguments = list(libpath = lib), reporter = "silent")))
  expect_false(is.null(e))
  msg <- e1_flat(e)
  expect_true(grepl("is an object in the pipeline's environment", msg, fixed = TRUE))
  expect_true(grepl("rule 4.6.3", msg, fixed = TRUE))
  expect_false(dir.exists(file.path(d, "_targets", "objects")))
})

test_that("2e-1 P8: a _targets.R reading dict$zz fails at tar_manifest(), before any target runs", {
  skip_if_not_installed("targets")
  skip_on_cran()
  d <- e1_tmp()
  e1_dict(d)
  writeLines(c(
    "library(targets)",
    "c(weft::tar_dict(\"dict.yml\"), weft::tar_dict_deps(list(tar_target(t_a, dict$zz + 1))))"),
    file.path(d, "_targets.R"))
  lib <- e1_libpath()
  e <- e1_err(withr::with_dir(d, targets::tar_manifest(callr_arguments = list(libpath = lib))))
  expect_false(is.null(e))
  msg <- e1_flat(e)
  expect_true(grepl("1 unknown key(s) read by the pipeline", msg, fixed = TRUE))
  expect_true(grepl("`t_a` reads `dict$zz`, which dict.yml does not hold (rule 4.6.4)", msg, fixed = TRUE))
  expect_false(dir.exists(file.path(d, "_targets", "objects")))
})
