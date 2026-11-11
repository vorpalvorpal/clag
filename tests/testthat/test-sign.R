# Stage 1b: `sign` spans (rules 1.5.1, 1.5.3, 1.5.8, 1.5.10, 1.5.17, 1.7.2).
# The markup rows are in helper-1b.R (batch A, group "sign"); the collected
# failures of a sign span (1.5.3, 1.5.17, 5.3.2) are in test-collected.R.

sc <- function(x, ...) weft:::scan_text(x, ...)

# ---- the scanner -----------------------------------------------------------

test_that("1.1.5 + design: a sign span is a row of kind sign, with its arms and governor expression", {
  r <- sc("It [rose by # | fell by # | did not change]{.pct sign=\"d\"}.")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "sign")
  expect_equal(r$expr, "d")
  expect_equal(r$arms[[1]], c("rose by #", "fell by #", "did not change"))
  expect_identical(r$error, NA_character_)
  # the governor's formatter class is kept, as written
  expect_true(".pct" %in% r$classes[[1]])
})

test_that("1.1.5 + 1.2.10: sign in any letter case, quoted or not, is a sign span", {
  expect_equal(sc("[a | b]{Sign=\"d\"}")$kind, "sign")
  expect_equal(sc("[a | b]{sign=d}")$kind, "sign")
  expect_equal(sc("[a | b]{sign=d}")$expr, "d")
})

test_that("1.5.1: a sign span takes two or three arms", {
  expect_identical(b_errs("[a | b]{sign=\"d\"}"), character())
  expect_identical(b_errs("[a | b | c]{sign=\"d\"}"), character())
})

test_that("1.5.2 + 5.3.1: any other arm count for sign is a construct error found from the source", {
  b_expect_scan_error("[a]{sign=\"d\"}", "[a | b]{sign=\"d\"}")
  b_expect_scan_error("[a | b | c | d]{sign=\"d\"}", "[a | b | c]{sign=\"d\"}")
  b_expect_scan_error("[a | b | c | d | e]{sign=\"d\"}")
})

test_that("1.7.2 + 5.3.1: there is no sign=\".\"", {
  b_expect_scan_error("[a | b]{sign=\".\"}", "[a | b]{sign=\"d\"}")
  b_expect_scan_error("[# x[ | s]{sign=\".\"} | # y]{sign=\"d\"}")
})

test_that("1.7.2: n=\".\" is legal inside a sign span, and an error outside any n or sign span", {
  ok <- "[rose by # point[ | s]{n=\".\"} | fell by # point[ | s]{n=\".\"}]{sign=\"d\"}"
  expect_identical(b_errs(ok), character())
  b_expect_scan_error("[a | b]{n=\".\"}", ok)
  # inside an if span there is nothing to inherit
  b_expect_scan_error("[x [a | b]{n=\".\"} | y]{if=\"flag\"}")
})

test_that("1.5.7 + 5.3.1: two governor keys, one of them sign, are one construct and an error", {
  b_expect_scan_error("[a | b]{sign=\"d\" n=\"k\"}", "[a | b]{sign=\"d\"}")
  b_expect_scan_error("[a | b]{sign=\"d\" if=\"flag\"}")
  b_expect_scan_error("[a | b]{sign=\"d\" cite=\"@k\"}")
})

test_that("1.3.3 + 5.3.1: sign on a value is a construct error", {
  b_expect_scan_error("`r d`{sign=\"d\"}", "`r d`{.num}")
})

test_that("1.5.7 + 1.4.2: two number-stage classes on a sign span are a construct error", {
  b_expect_scan_error("[a | b]{.num .pct sign=\"d\"}", "[a | b]{.pct sign=\"d\"}")
})

test_that("5.3.5: a sign governor that does not parse is a construct error", {
  b_expect_scan_error("[a | b]{sign=\"d +* 1\"}", "[a | b]{sign=\"d + 1\"}")
})

test_that("1.2.3: a quote or a backslash in the sign governor is a construct error", {
  b_expect_scan_error("[a | b]{sign='d'}", "[a | b]{sign=\"d\"}")
})

test_that("1.7.6: sign takes a back-reference as the whole value; the row's expr is #id", {
  r <- sc("Change `r d`{#zd .num}. [rose | fell]{sign=\"#zd\"}")
  expect_equal(r$kind, c("value", "sign"))
  expect_equal(r$id[1], "zd")
  expect_equal(r$expr[2], "#zd")
  expect_identical(r$error, c(NA_character_, NA_character_))
})

# ---- rendered, both engines --------------------------------------------------

test_that("1.5.x + 1.7.2: sign spans render as the rules say (rmarkdown)", {
  b_expect_rows("A", "sign", "rmd")
})

test_that("1.5.x + 1.7.2: sign spans render the same under Quarto", {
  b_expect_rows("A", "sign", "qmd")
})

test_that("1.5.8: a span with no magnitude in its output prints no sign character", {
  # the negative arm's # is the magnitude: neither a hyphen-minus nor U+2212
  res <- b_batch("A", "rmd")
  b_need(res)
  r <- Filter(function(r) r$rule == "1.5.8: the magnitude under the default class (negative, 3)", res$rows)[[1]]
  i <- which(vapply(res$rows, identical, NA, r))
  expect_false(grepl("[-−]", res$got[i]))
  expect_match(res$got[i], "fell by 3", fixed = TRUE)
})
