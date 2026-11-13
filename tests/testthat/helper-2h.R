# Helpers for the 2h tests (the unit ladder). Contract: dev/design-2h.md.
# "~" in an expected string stands for U+00A0 (f2()). Non-ASCII is written as \uXXXX.
# A ladder is one string of rungs separated by "|". The `units` database is session-global: a
# test that installs a unit of its own uses a made-up token unique to that test.

# Source a helper that lives in tests/testthat/ when its function is not defined yet, whether
# the file runs from _2h/ or after it has been moved up.
h2_need <- function() {
  need <- c(f2_ws = "helper-2f.R", g2_restore = "helper-2g.R", expect_qty = "helper-2a.R",
            render_rmd = "helper-render.R")
  for (i in seq_along(need)) {
    if (!exists(names(need)[i])) {
      p <- Filter(file.exists, c(testthat::test_path(need[[i]]), testthat::test_path("..", need[[i]])))
      if (length(p)) source(p[[1]], local = globalenv())
    }
  }
}
h2_need()

H2_MINUS <- "−"
H2_EN <- "–"

# the "weft" state, now and when the calling test ends (g2_restore())
h2_restore <- function(env = parent.frame()) g2_restore(env)

# weft_str() of `src` run from inside an empty project, as plain text with U+00A0
h2_ws <- function(src, yml = NULL) f2_ws(src, yml)

# the warnings an expression raises, and its value
h2_warns <- function(expr) {
  w <- character()
  v <- withCallingHandlers(expr, warning = function(c) { w <<- c(w, conditionMessage(c)); invokeRestart("muffleWarning") })
  list(v = v, w = w)
}

# a test per table row: `src` through weft_str() prints `want` ("~" is U+00A0)
h2_row <- function(src, want, yml = NULL) {
  force(src); force(want); force(yml)
  testthat::test_that(sprintf("2h 4.4.23 table: %s prints %s", src, want), {
    h2_restore()
    testthat::expect_equal(h2_ws(src, yml), f2(want))
  })
}

# a test per table row that is an error from weft_str(); `has` pieces occur in the message
h2_row_err <- function(src, class = "weft_value_error", has = NULL, yml = NULL) {
  force(src); force(class); force(has); force(yml)
  testthat::test_that(sprintf("2h errors: %s is a %s", src, class), {
    h2_restore()
    e <- f2_err(src, yml)
    f2_has_class(e, class)
    if (!is.null(has)) do.call(f2_msg_has, c(list(e), as.list(has)))
  })
}

# the construct errors the scanner finds in a text (no R evaluated)
h2_scan_errs <- function(text) {
  r <- weft:::scan_text(text)
  r$error[!is.na(r$error)]
}

# a dictionary file with one quantity entry `x` of `value` m and a `display:` field
h2_dict <- function(display, value = 2000, unit = "m", extra = NULL, env = parent.frame()) {
  f2_dict_file(c(sprintf("x: {value: %s, type: quantity, unit: %s, display: %s, definition: \"A length.\"}",
                         value, unit, display), extra), env)
}

# weft_str() with the `dict` the caller passes in scope
h2_wsd <- function(src, dict) f2_unesc(withr::with_dir(f2_proj(), weft_str(src)))
