# Package 7s: the new settings in R (dev/design-7.md N12 `ci_short`, N25, N51, N70; E8, E9, E20, E30).
# Settings: ci_short (default FALSE), p_digits (NULL), p_label ("p"), output_refs ("fail"),
# output_missing ("warn"), output_markup ("fail"), chunk_claims ("stop").
# ASCII only.

c7_project <- function(yml = NULL, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir <- file.path(root, "proj")
  dir.create(dir)
  if (!is.null(yml)) writeLines(yml, file.path(dir, "_weft.yml"))
  dir
}

c7_cfg <- function(dir, front = list()) {
  withr::local_envvar(WEFT_DRAFT = NA)
  weft:::read_config(dir, front = front)
}

# the condition raised by reading the configuration
c7_cond <- function(dir, front = list()) {
  withr::local_envvar(WEFT_DRAFT = NA)
  tryCatch({ weft:::read_config(dir, front = front); NULL }, condition = function(e) e)
}

c7_expect_error <- function(dir, msg, front = list()) {
  e <- c7_cond(dir, front)
  expect_false(is.null(e), label = "a configuration error was raised")
  expect_s3_class(e, "weft_config_error")
  expect_s3_class(e, "weft_error")
  expect_identical(conditionMessage(e), msg)
}

E8 <- "The setting `p_digits` must be a whole number from 1 to 6, or null."
E9 <- "The setting `p_label` must be a single string."
E20 <- function(nm) sprintf("The setting `%s` must be fail, warn or off.", nm)
E30 <- "The setting `chunk_claims` must be stop or collect."
E_CI <- "The setting `ci_short` must be TRUE or FALSE."   # the house wording of validate_config(); E3 is for keys

# ---- defaults -------------------------------------------------------------------------------------

test_that("N12, N25, N51, N70: each new setting has its default with no _weft.yml", {
  x <- c7_cfg(c7_project())
  expect_identical(x$ci_short, FALSE)
  expect_null(x$p_digits)
  expect_identical(x$p_label, "p")
  expect_identical(x$output_refs, "fail")
  expect_identical(x$output_missing, "warn")
  expect_identical(x$output_markup, "fail")
  expect_identical(x$chunk_claims, "stop")
})

test_that("N12, N25, N51, N70: the defaults are in default_config(), so no setting is reported unknown", {
  d <- weft:::default_config()
  expect_true(all(c("ci_short", "p_digits", "p_label", "output_refs", "output_missing",
                    "output_markup", "chunk_claims") %in% names(d)))
  expect_identical(d$ci_short, FALSE)
  expect_identical(d$p_label, "p")
  expect_identical(d$output_refs, "fail")
  expect_identical(d$output_missing, "warn")
  expect_identical(d$output_markup, "fail")
  expect_identical(d$chunk_claims, "stop")
  dir <- c7_project(c("ci_short: true", "p_digits: 3", "p_label: q", "output_refs: warn",
                      "output_missing: off", "output_markup: warn", "chunk_claims: collect"))
  expect_no_warning(c7_cfg(dir))
})

# ---- values read from _weft.yml ---------------------------------------------------------------------

test_that("N12, N25, N51, N70: _weft.yml values are read", {
  x <- c7_cfg(c7_project(c("ci_short: true", "p_digits: 3", "p_label: q", "output_refs: warn",
                           "output_missing: off", "output_markup: warn", "chunk_claims: collect")))
  expect_identical(x$ci_short, TRUE)
  expect_equal(x$p_digits, 3)
  expect_identical(x$p_label, "q")
  expect_identical(x$output_refs, "warn")
  expect_identical(x$output_missing, "off")
  expect_identical(x$output_markup, "warn")
  expect_identical(x$chunk_claims, "collect")
})

test_that("N25: p_digits takes the ends of 1 to 6, and null is the default", {
  expect_equal(c7_cfg(c7_project("p_digits: 1"))$p_digits, 1)
  expect_equal(c7_cfg(c7_project("p_digits: 6"))$p_digits, 6)
  expect_null(c7_cfg(c7_project("p_digits: null"))$p_digits)
})

test_that("N25: p_label may be empty, or markdown, and is kept as written", {
  expect_identical(c7_cfg(c7_project("p_label: \"\""))$p_label, "")
  expect_identical(c7_cfg(c7_project("p_label: \"*p*\""))$p_label, "*p*")
})

test_that("N51: each output_* setting takes fail, warn and off", {
  for (nm in c("output_refs", "output_missing", "output_markup")) {
    for (v in c("fail", "warn", "off")) {
      x <- c7_cfg(c7_project(sprintf("%s: %s", nm, v)))
      expect_identical(x[[nm]], v, label = paste(nm, v))
    }
  }
})

# ---- a document's weft: overrides _weft.yml ------------------------------------------------------------

test_that("N12, N25, N51, N70: a document's weft: block overrides _weft.yml", {
  dir <- c7_project(c("ci_short: false", "p_digits: 3", "p_label: q", "output_refs: fail",
                      "output_missing: warn", "output_markup: fail", "chunk_claims: stop"))
  x <- c7_cfg(dir, front = list(ci_short = TRUE, p_digits = 2, p_label = "", output_refs = "off",
                                output_missing = "fail", output_markup = "warn",
                                chunk_claims = "collect"))
  expect_identical(x$ci_short, TRUE)
  expect_equal(x$p_digits, 2)
  expect_identical(x$p_label, "")
  expect_identical(x$output_refs, "off")
  expect_identical(x$output_missing, "fail")
  expect_identical(x$output_markup, "warn")
  expect_identical(x$chunk_claims, "collect")
})

test_that("N12, N25, N51, N70: a document's weft: block sets them with no _weft.yml at all", {
  x <- c7_cfg(c7_project(), front = list(p_digits = 4, p_label = "q", chunk_claims = "collect"))
  expect_equal(x$p_digits, 4)
  expect_identical(x$p_label, "q")
  expect_identical(x$chunk_claims, "collect")
})

# ---- wrong values: E8, E9, E20, E30, and ci_short -----------------------------------------------------

test_that("N25, E8: a wrong p_digits is a weft_config_error with the E8 text", {
  for (v in c("0", "7", "1.5", "-1", "three", "true")) {
    c7_expect_error(c7_project(paste0("p_digits: ", v)), E8)
  }
  c7_expect_error(c7_project(), E8, front = list(p_digits = 7))
})

test_that("N25, E9: a wrong p_label is a weft_config_error with the E9 text", {
  for (v in c("5", "true")) c7_expect_error(c7_project(paste0("p_label: ", v)), E9)
  c7_expect_error(c7_project(), E9, front = list(p_label = c("a", "b")))
})

test_that("N51, E20: a wrong output_* value is a weft_config_error with the E20 text naming the setting", {
  for (nm in c("output_refs", "output_missing", "output_markup")) {
    for (v in c("maybe", "true", "1")) {
      c7_expect_error(c7_project(sprintf("%s: %s", nm, v)), E20(nm))
    }
    c7_expect_error(c7_project(), E20(nm), front = stats::setNames(list("loud"), nm))
  }
})

test_that("N70, E30: a wrong chunk_claims is a weft_config_error with the E30 text", {
  for (v in c("sometimes", "true", "1", "off")) c7_expect_error(c7_project(paste0("chunk_claims: ", v)), E30)
  c7_expect_error(c7_project(), E30, front = list(chunk_claims = "all"))
})

test_that("N12: a ci_short that is not true or false is a weft_config_error", {
  for (v in c("maybe", "1")) c7_expect_error(c7_project(paste0("ci_short: ", v)), E_CI)
  c7_expect_error(c7_project(), E_CI, front = list(ci_short = "no"))
})

test_that("control: an existing wrong setting still raises its own error, not the new ones", {
  # passes today
  e <- c7_cond(c7_project("digits: two"))
  expect_s3_class(e, "weft_config_error")
  expect_match(conditionMessage(e), "`digits`", fixed = TRUE)
})
