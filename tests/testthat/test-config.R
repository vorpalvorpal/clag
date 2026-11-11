# Stage 1a: weft:::read_config(dir, front = list()) (9.1, 1.4.8, 9.4.1).

defaults <- list(
  digits = 1,
  decimal_mark = ".",
  big_mark = ",",
  minus = "−",
  governor_class = ".num",
  pct_proportion = TRUE,
  count_threshold = 10,
  word_limit = 100,
  draft = FALSE
)

new_project <- function(yml = NULL, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir <- file.path(root, "proj")
  dir.create(dir)
  if (!is.null(yml)) writeLines(yml, file.path(dir, "_weft.yml"))
  dir
}

cfg <- function(dir, front = list()) weft:::read_config(dir, front = front)

# these tests must not see a WEFT_DRAFT from the environment of the runner
local_no_draft_env <- function(env = parent.frame()) {
  withr::local_envvar(WEFT_DRAFT = NA, .local_envir = env)
}

test_that("9.1.5: with no _weft.yml the config is the defaults, as a named list", {
  local_no_draft_env()
  d <- new_project()
  x <- cfg(d)
  expect_type(x, "list")
  expect_false(is.null(names(x)))
  for (nm in names(defaults)) {
    expect_equal(x[[nm]], defaults[[nm]], label = nm)
  }
  expect_length(x$formatters, 0L)
  expect_length(x$severity, 0L)
})

test_that("9.1.5: an empty _weft.yml (only a comment) gives the defaults", {
  local_no_draft_env()
  d <- new_project("# weft settings go here")
  x <- cfg(d)
  for (nm in names(defaults)) {
    expect_equal(x[[nm]], defaults[[nm]], label = nm)
  }
})

test_that("9.1.1: _weft.yml values override the defaults, setting by setting", {
  local_no_draft_env()
  d <- new_project(c("digits: 2", "big_mark: \" \"", "count_threshold: 20",
                     "pct_proportion: false", "governor_class: .pct"))
  x <- cfg(d)
  expect_equal(x$digits, 2)
  expect_equal(x$big_mark, " ")
  expect_equal(x$count_threshold, 20)
  expect_false(x$pct_proportion)
  expect_equal(x$governor_class, ".pct")
  # untouched settings keep their defaults
  expect_equal(x$decimal_mark, ".")
  expect_equal(x$word_limit, 100)
  expect_equal(x$minus, "−")
})

test_that("9.1.1: a document's weft: front matter overrides setting by setting", {
  local_no_draft_env()
  d <- new_project(c("digits: 2", "big_mark: \" \"", "word_limit: 50"))
  x <- cfg(d, front = list(digits = 3, count_threshold = 5))
  expect_equal(x$digits, 3)             # front beats _weft.yml
  expect_equal(x$big_mark, " ")         # _weft.yml beats default
  expect_equal(x$word_limit, 50)        # _weft.yml beats default
  expect_equal(x$count_threshold, 5)    # front beats default
  expect_equal(x$decimal_mark, ".")     # default
})

test_that("9.1.1: front matter works with no _weft.yml", {
  local_no_draft_env()
  d <- new_project()
  x <- cfg(d, front = list(digits = 4, minus = "-"))
  expect_equal(x$digits, 4)
  expect_equal(x$minus, "-")
  expect_equal(x$big_mark, ",")
})

test_that("9.1.4: draft in front matter is an error where a _weft.yml exists", {
  local_no_draft_env()
  d <- new_project("digits: 2")
  expect_error(cfg(d, front = list(draft = TRUE)), "draft")
  expect_error(cfg(d, front = list(draft = FALSE)), "draft")
})

test_that("9.1.4: draft in front matter is allowed when there is no _weft.yml", {
  local_no_draft_env()
  d <- new_project()
  expect_true(cfg(d, front = list(draft = TRUE))$draft)
  expect_false(cfg(d, front = list(draft = FALSE))$draft)
})

test_that("9.1.2, 9.4.1: draft in _weft.yml itself is allowed", {
  local_no_draft_env()
  d <- new_project(c("draft: true"))
  expect_true(cfg(d)$draft)
})

test_that("9.4.1: WEFT_DRAFT=1 turns draft on", {
  d <- new_project()
  withr::local_envvar(WEFT_DRAFT = "1")
  expect_true(cfg(d)$draft)
  d2 <- new_project("digits: 2")
  expect_true(cfg(d2)$draft)
  d3 <- new_project("draft: false")
  expect_true(cfg(d3)$draft)
})

test_that("9.4.1: with WEFT_DRAFT unset and draft unset, draft is off", {
  local_no_draft_env()
  d <- new_project("digits: 2")
  expect_false(cfg(d)$draft)
})

test_that("1.4.8: a project formatter is read with its function and stage", {
  local_no_draft_env()
  d <- new_project(c(
    "formatters:",
    "  .compact:",
    "    function: base::round",
    "    stage: number"
  ))
  x <- cfg(d)
  expect_true(".compact" %in% names(x$formatters))
  f <- x$formatters[[".compact"]]
  expect_equal(f[["function"]], "base::round")
  expect_equal(f$stage, "number")
})

test_that("1.4.8: a project formatter's stage is number by default", {
  local_no_draft_env()
  d <- new_project(c(
    "formatters:",
    "  .compact:",
    "    function: base::round"
  ))
  x <- cfg(d)
  expect_true(".compact" %in% names(x$formatters))
  stage <- x$formatters[[".compact"]]$stage
  expect_true(is.null(stage) || identical(stage, "number"))
})

test_that("1.4.8: a project formatter may not shadow a shipped class name", {
  local_no_draft_env()
  for (shipped in c(".num", ".pct", ".sci", ".no", ".word", ".count", ".ord",
                    ".and", ".or", ".strong", ".em")) {
    d <- new_project(c(
      "formatters:",
      paste0("  ", shipped, ":"),
      "    function: base::round",
      "    stage: number"
    ))
    expect_error(cfg(d), regexp = sub("^\\.", "", shipped), label = shipped)
  }
})

test_that("1.4.8: a formatter in a document's front matter may not shadow one either", {
  local_no_draft_env()
  d <- new_project()
  front <- list(formatters = list(.num = list(`function` = "base::round",
                                              stage = "number")))
  expect_error(cfg(d, front = front), "num")
})

test_that("1.4.8: an unknown stage name is an error", {
  local_no_draft_env()
  d <- new_project(c(
    "formatters:",
    "  .compact:",
    "    function: base::round",
    "    stage: bogus"
  ))
  expect_error(cfg(d), "bogus")
})
