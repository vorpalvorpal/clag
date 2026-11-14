# Stage 1b: .weft-literal, span and div (1.1.6, 1.8.9 to 1.8.11, 5.3.1).
# Markup rows: helper-1b.R, batch B, group "literal".

sc <- function(x, ...) weft:::scan_text(x, ...)

# ---- the scanner -----------------------------------------------------------------------

test_that("design: a .weft-literal span is a row of kind literal, with its why among the keys", {
  r <- sc("filtered through [0.45 µm]{.weft-literal why=\"pore size, SOP 12\"} membranes")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "literal")
  expect_identical(r$error, NA_character_)
  expect_true(".weft-literal" %in% r$classes[[1]])
  expect_equal(unname(r$keys[[1]][["why"]]), "pore size, SOP 12")
})

test_that("design: a .weft-literal div is a row of kind literal whose range is its opening fence line", {
  txt <- paste("Before.", "", "::: {.weft-literal why=\"laboratory method\"}",
               "Samples were filtered through 0.45 µm membranes.", ":::", "", "After.", sep = "\n")
  r <- sc(txt)
  expect_equal(sum(r$kind == "literal"), 1L)
  d <- r[r$kind == "literal", ]
  expect_equal(d$line, 3L)
  expect_identical(d$error, NA_character_)
  expect_equal(trimws(substr(txt, d$start, d$end)), "::: {.weft-literal why=\"laboratory method\"}")
})

test_that("1.5.15: a value inside a literal span or div is still a construct row", {
  r <- sc("[`r x`{.num} µm]{.weft-literal why=\"w\"}")
  expect_true(all(c("literal", "value") %in% r$kind))
  r2 <- sc("::: {.weft-literal why=\"w\"}\nMean `r x`{.num} m.\n:::")
  expect_true(all(c("literal", "value") %in% r2$kind))
})

test_that("1.8.10 + 5.3.1: a .weft-literal span without a why is a construct error", {
  b_expect_scan_error("filtered through [0.45]{.weft-literal} membranes",
                      "filtered through [0.45]{.weft-literal why=\"SOP 12\"} membranes")
  b_expect_scan_error("[0.45]{.weft-literal .smallcaps}")
})

test_that("1.8.10 + 5.3.1: a .weft-literal div without a why is a construct error", {
  b_expect_scan_error("::: {.weft-literal}\nText.\n:::",
                      "::: {.weft-literal why=\"SOP 12\"}\nText.\n:::")
})

test_that("1.2.4: the why may stand anywhere in the block", {
  expect_identical(b_errs("[a]{why=\"w\" .weft-literal}"), character())
  expect_identical(b_errs("[a]{.smallcaps why=\"w\" .weft-literal}"), character())
})

test_that("1.9.1: an ordinary Pandoc div or span with a class that is not .weft-literal is left alone", {
  expect_equal(nrow(sc("::: {.note why=\"x\"}\nText.\n:::")), 0L)
  expect_equal(nrow(sc("[abc]{.smallcaps why=\"x\"}")), 0L)
})

test_that("1.1.10, 1.9.1: a .weft-literal inside a fence that is not executed is not scanned", {
  r <- sc("```text\n[0.45]{.weft-literal}\n```")
  expect_equal(nrow(r), 0L)
})

# ---- the render ---------------------------------------------------------------------------------

test_that("1.8.9 to 1.8.11: literals render with the why removed and the class kept (rmarkdown)", {
  b_expect_rows("B", "literal", "rmd")
})

test_that("1.8.9 to 1.8.11: literals render the same under Quarto", {
  b_expect_rows("B", "literal", "qmd")
})

test_that("1.8.11: the why text appears nowhere in the output of a literal row", {
  res <- b_batch("B", "rmd")
  b_need(res)
  idx <- which(vapply(res$rows, function(r) r$grp == "literal", NA))
  expect_gt(length(idx), 0L)
  for (i in idx) {
    expect_false(grepl("why", res$got[i], fixed = TRUE), label = res$rows[[i]]$rule)
  }
  expect_false(any(grepl("pore size", res$got[idx], fixed = TRUE)))
  expect_false(any(grepl("laboratory method", res$got[idx], fixed = TRUE)))
  # and the class is on every one of them
  expect_true(all(grepl("weft-literal", res$got[idx], fixed = TRUE)))
})

test_that("1.8.10 + 2.6.5: a literal without a why stops the render, naming file:line", {
  res <- render_rmd(c("Intro.", "", "Filtered through [0.45]{.weft-literal} membranes.", "", "End."),
                    code = PRE_B)
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, at_line(res, 3))
  expect_false(grepl("not built yet", res$message))
})
