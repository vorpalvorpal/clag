# Stage 1b: ids and back-references (1.2.8, 1.7.5 to 1.7.12, 1.5.16, 5.3.1).
# Markup rows: helper-1b.R, batch A, group "ids" (and "phrases" for of_n()).

sc <- function(x, ...) weft:::scan_text(x, ...)

# ---- the scanner: rows ---------------------------------------------------------

test_that("1.7.5: an #id on a value or a governed span is the row's id", {
  r <- sc("Depth `r d`{#zd .num} and [a | b]{n=\"k\" #zs}.")
  expect_equal(r$id, c("zd", "zs"))
  expect_identical(r$error, c(NA_character_, NA_character_))
  # no id: NA
  expect_true(is.na(sc("`r d`{.num}")$id))
})

test_that("1.7.6: a back-reference has the expr '#id' (n and sign)", {
  r <- sc("`r d`{#zd .num} [# a | # b]{n=\"#zd\"} [x | y]{sign=\"#zd\"}")
  expect_equal(r$expr, c("d", "#zd", "#zd"))
  expect_equal(r$kind, c("value", "n", "sign"))
  expect_identical(r$error, rep(NA_character_, 3))
})

test_that("1.7.6: a back-reference is not parsed as R (5.3.5 excepts it)", {
  expect_identical(b_errs("`r d`{#zd .num} [a | b]{n=\"#zd\"}"), character())
})

# ---- the scanner: construct errors (5.3.1) -------------------------------------

test_that("1.7.5 + 1.1.9: an #id on a text span is a construct error", {
  b_expect_scan_error("Text [results]{#zt .strong} here.", "Text [results]{.strong} here.")
  b_expect_scan_error("Text [results]{#zt .cap} here.")
})

test_that("1.7.5: an #id on a cite span is a construct error", {
  b_expect_scan_error("[x]{#zc cite=\"@smith2020\"}", "[x]{cite=\"@smith2020\"}")
  b_expect_scan_error("[x]{#zc cite=\"smith2020\"}")
})

test_that("1.7.5: a duplicate id is a construct error", {
  b_expect_scan_error("`r a`{#zd .num} and `r b`{#zd .num}",
                      "`r a`{#zd .num} and `r b`{#ze .num}")
  # a value and a span may not share one
  b_expect_scan_error("`r a`{#zd .num} and [a | b]{n=\"k\" #zd}")
  # in different paragraphs too
  b_expect_scan_error("`r a`{#zd .num}\n\nLater `r b`{#zd .num}.")
})

test_that("1.7.10: an unknown id is a construct error", {
  b_expect_scan_error("[a | b]{n=\"#znope\"}", "`r k`{#znope .num} [a | b]{n=\"#znope\"}")
  b_expect_scan_error("[a | b]{sign=\"#znope\"}")
  # an id from another document is unknown: each scan is one document
  expect_gte(length(b_errs("[a | b]{n=\"#zd\"}")), 1L)
})

test_that("1.7.10: an id defined further down is a construct error", {
  b_expect_scan_error("[a | b]{n=\"#zd\"}\n\nLater `r k`{#zd .num}.",
                      "Earlier `r k`{#zd .num}.\n\n[a | b]{n=\"#zd\"}")
  b_expect_scan_error("[x | y]{sign=\"#zd\"} and then `r k`{#zd .num}.")
})

test_that("1.7.10: an id defined in an earlier paragraph, heading or list is known later", {
  expect_identical(b_errs("## Head `r k`{#zd .num}\n\nBody [a | b]{n=\"#zd\"}."), character())
  expect_identical(b_errs("- item `r k`{#zd .num}\n\nBody [a | b]{n=\"#zd\"}."), character())
})

test_that("1.7.11 + 1.5.16: a back-reference to an id defined in a different arm is a construct error", {
  same <- "[A `r k`{#za .num}; [a | b]{n=\"#za\"} | B]{if=\"flag\"}"
  other <- "[A `r k`{#za .num} | B [a | b]{n=\"#za\"}]{if=\"flag\"}"
  expect_identical(b_errs(same), character())
  b_expect_scan_error(other, same)
})

test_that("1.7.11: an id defined inside an arm is not referred to from outside the span", {
  b_expect_scan_error("[A `r k`{#za .num} | B]{if=\"flag\"} then [a | b]{n=\"#za\"}",
                      "[A `r k`{#za .num} | B]{if=\"flag\"}")
  # and not from before it either (the arm does not exist yet)
  b_expect_scan_error("[a | b]{n=\"#za\"} then [A `r k`{#za .num} | B]{if=\"flag\"}")
})

test_that("1.7.11: an id on the governed span itself may be referred to afterwards", {
  expect_identical(b_errs("[# a | # b]{n=\"k\" #zs} and [x | y]{n=\"#zs\"}"), character())
})

test_that("1.7.11: an id defined in an n arm is local to that arm, and one in the same arm is fine", {
  ok <- "[A `r k`{#za .num} [x | y]{n=\"#za\"} | B # ]{n=\"k\"}"
  bad <- "[A `r k`{#za .num} | B [x | y]{n=\"#za\"}]{n=\"k\"}"
  expect_identical(b_errs(ok), character())
  b_expect_scan_error(bad, ok)
})

# ---- the render --------------------------------------------------------------

test_that("1.7.x: ids and back-references render as the rules say (rmarkdown)", {
  b_expect_rows("A", "ids", "rmd")
})

test_that("1.7.x: ids and back-references render the same under Quarto", {
  b_expect_rows("A", "ids", "qmd")
})

test_that("3.5.2 + 1.7.5: an id on of_n()'s value and an n span that refers to it (rmarkdown)", {
  b_expect_rows("B", "phrases", "rmd")
})

test_that("1.2.8: an id is never emitted to the output (every row of the batch, both engines)", {
  for (engine in c("rmd", "qmd")) {
    res <- b_batch("A", engine)
    expect_false(res$failed, label = paste(engine, "render"))
    if (res$failed) next
    expect_false(grepl("zid", res$md, fixed = TRUE), label = paste(engine, "no id in the output"))
    expect_false(grepl("{#", res$md, fixed = TRUE), label = paste(engine, "no #id attribute"))
  }
})

test_that("1.7.7: the referring spans evaluate nothing: the value's side effect ran once", {
  res <- b_batch("A", "rmd")
  b_need(res)
  for (tag in c("zc1", "zc2")) {
    r_i <- which(vapply(res$rows, function(r) grepl(tag, r$src, fixed = TRUE), NA))
    expect_length(r_i, 1L)
    expect_match(res$got[r_i], "Runs: 1\\.$", label = tag)
  }
})

test_that("1.7.12 + design: last_knit()$constructs has an id column, and a back-reference's expr is '#id'", {
  res <- b_batch("A", "rmd")
  b_need(res)
  cs <- res$knit$constructs
  expect_true("id" %in% names(cs))
  ids <- cs$id[!is.na(cs$id)]
  expect_true(all(c("zid1", "zid2", "zid12", "zid17") %in% ids))
  refs <- cs[!is.na(cs$expr) & cs$expr == "#zid1", ]
  expect_equal(nrow(refs), 1L)
  expect_equal(refs$kind, "n")
  expect_true(refs$evaluated)
})

test_that("1.5.16 + 1.7.11: an id defined in an arm that is not chosen does not exist (nothing evaluated there)", {
  res <- b_batch("A", "rmd")
  b_need(res)
  cs <- res$knit$constructs
  chosen <- cs[!is.na(cs$id) & cs$id == "zid15a", ]
  other <- cs[!is.na(cs$id) & cs$id == "zid15b", ]
  expect_equal(nrow(chosen), 1L)
  expect_true(chosen$evaluated)
  # the unchosen arm's value is recorded (it is in the source) but never evaluated
  if (nrow(other)) expect_false(other$evaluated)
})

test_that("1.7.7: a back-reference is evaluated as part of its own span, never as R code", {
  # `#zid1` is not R: were it parsed, the render would be a construct error
  res <- b_batch("A", "rmd")
  expect_false(res$failed, label = substr(res$message, 1, 200))
})
