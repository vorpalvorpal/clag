# Stage 1d: .pairs, trunc, and the list formatters .ul .ol .dl (1.4.3, 1.4.6,
# 1.4.7, 1.4.2). Markup rows: helper-1b.R, batch C, groups "pairs", "trunc",
# "lists". The language errors for these names (1.6.8) are in test-collected.R.

sc <- function(x, ...) weft:::scan_text(x, ...)

means <- c(A = 1.2, B = 3.4, C = 5.6)

# ---- .pairs ------------------------------------------------------------------------------

test_that("1.4.3: fmt_pairs() prints 'A (1.2), B (3.4) and C (5.6)'", {
  x <- fmt_pairs(means)
  expect_s3_class(x, "weft_text")
  expect_length(x, 1L)
  expect_equal(b_txt(x), "A (1.2), B (3.4) and C (5.6)")
  expect_equal(b_txt(fmt_pairs(means[1:2])), "A (1.2) and B (3.4)")
  expect_equal(b_txt(fmt_pairs(means[1])), "A (1.2)")
})

test_that("design: fmt_pairs() prints the values as .num prints them, the names as they are", {
  expect_equal(b_txt(fmt_pairs(c(A = 1, B = 2.5))), "A (1) and B (2.5)")
  expect_equal(b_txt(fmt_pairs(c(A = 12345.678, B = 2))), "A (12,345.7) and B (2)")
  expect_equal(b_txt(fmt_pairs(c(`*a*` = 1, `b c` = 2))), "*a* (1) and b c (2)")
  expect_equal(b_txt(fmt_pairs(c(A = -1, B = 2))), paste0("A (", B_MINUS, "1) and B (2)"))
})

test_that("1.4.11: a collapsed vector has no number", {
  expect_true(is.na(attr(fmt_pairs(means), "number")))
})

test_that("design: an unnamed vector to .pairs is a value error", {
  expect_error(fmt_pairs(c(1.2, 3.4)), class = "weft_value_error")
  expect_error(fmt_pairs(c("a", "b")), class = "weft_value_error")
})

test_that("1.3.4: a missing value reaching .pairs is a weft_no_value error", {
  expect_error(fmt_pairs(c(A = 1, B = NA)), class = "weft_no_value")
  expect_error(fmt_pairs(numeric(0)), class = "weft_no_value")
})

# ---- trunc ------------------------------------------------------------------------------------

test_that("1.4.7 + design: trunc shows the first k items then 'and N others'", {
  x <- fmt_and(letters[1:7], trunc = 3)
  expect_s3_class(x, "weft_text")
  expect_equal(b_txt(x), "a, b, c and 4 others")
  expect_equal(b_txt(fmt_and(letters[1:7], trunc = 1)), "a and 6 others")
  expect_equal(b_txt(fmt_and(letters[1:7], trunc = 2)), "a, b and 5 others")
  expect_equal(b_txt(fmt_and(letters[1:7], trunc = 6)), "a, b, c, d, e, f and 1 other")
})

test_that("design: trunc, one over is 'and 1 other'", {
  expect_equal(b_txt(fmt_and(letters[1:4], trunc = 3)), "a, b, c and 1 other")
})

test_that("design: trunc applies only to more than k items", {
  expect_equal(b_txt(fmt_and(letters[1:3], trunc = 3)), "a, b and c")
  expect_equal(b_txt(fmt_and(letters[1:2], trunc = 3)), "a and b")
  expect_equal(b_txt(fmt_and(letters[1:7], trunc = NULL)), "a, b, c, d, e, f and g")
})

test_that("1.4.7: trunc composes with sep and last", {
  expect_equal(b_txt(fmt_and(letters[1:5], sep = "; ", trunc = 2)), "a; b and 3 others")
})

test_that("design: trunc under .or shows the same 'N others' tail", {
  x <- b_txt(fmt_or(letters[1:7], trunc = 3))
  expect_match(x, "^a, b, c (and|or) 4 others$")
  expect_match(b_txt(fmt_or(letters[1:4], trunc = 3)), "^a, b, c (and|or) 1 other$")
  expect_equal(b_txt(fmt_or(letters[1:3], trunc = 3)), "a, b or c")
})

test_that("1.4.11: a truncated list has no number", {
  expect_true(is.na(attr(fmt_and(letters[1:7], trunc = 3), "number")))
})

# ---- .ul .ol .dl --------------------------------------------------------------------------------

test_that("1.4.3 + design: fmt_ul() prints '- item' lines", {
  x <- fmt_ul(c("a", "b", "c"))
  expect_s3_class(x, "weft_text")
  expect_equal(trimws(b_txt(x)), "- a\n- b\n- c")
  expect_equal(trimws(b_txt(fmt_ul("a"))), "- a")
})

test_that("1.4.3 + design: fmt_ol() prints '1. item' lines", {
  x <- b_txt(fmt_ol(c("a", "b", "c")))
  expect_match(trimws(x), "^1\\. a\n(1|2)\\. b\n(1|3)\\. c$")
  expect_match(trimws(b_txt(fmt_ol("a"))), "^1\\. a$")
})

test_that("1.4.3 + design: fmt_dl() prints a Pandoc definition list from a named vector", {
  x <- b_txt(fmt_dl(c(a = "x", b = "y")))
  expect_match(x, "a\n:   x", fixed = TRUE)
  expect_match(x, "b\n:   y", fixed = TRUE)
  expect_lt(regexpr("a\n:   x", x, fixed = TRUE), regexpr("b\n:   y", x, fixed = TRUE))
})

test_that("1.4.1: a number-stage class before a list formatter", {
  expect_equal(trimws(b_txt(fmt_ul(fmt_num(c(1.5, 2))))), "- 1.5\n- 2")
  expect_equal(trimws(b_txt(fmt_ul(fmt_word(c(1, 2))))), "- one\n- two")
})

test_that("1.3.4: a missing value reaching a list formatter is a weft_no_value error", {
  expect_error(fmt_ul(character(0)), class = "weft_no_value")
  expect_error(fmt_ol(character(0)), class = "weft_no_value")
  expect_error(fmt_dl(character(0)), class = "weft_no_value")
  expect_error(fmt_ul(c("a", NA)), class = "weft_no_value")
})

# ---- the scanner ------------------------------------------------------------------------------------

test_that("1.4.6 + 5.3.1: a list class on a value alone in its paragraph is legal", {
  for (cls in c(".ul", ".ol", ".dl")) {
    expect_identical(b_errs(sprintf("`r sites`{%s}", cls)), character(), label = cls)
    expect_identical(b_errs(sprintf("Intro.\n\n`r sites`{%s}\n\nOutro.", cls)), character(), label = cls)
    expect_identical(b_errs(sprintf("`r sites`{.num %s}", cls)), character(), label = cls)
  }
})

test_that("1.4.6 + 5.3.1: a list class on a value that is not alone in its paragraph is a construct error", {
  for (cls in c(".ul", ".ol", ".dl")) {
    b_expect_scan_error(sprintf("Sites: `r sites`{%s}", cls), sprintf("`r sites`{%s}", cls),
                        label = paste(cls, "text before"))
    b_expect_scan_error(sprintf("`r sites`{%s} were sampled.", cls), label = paste(cls, "text after"))
    b_expect_scan_error(sprintf("Intro line\n`r sites`{%s}", cls), label = paste(cls, "same paragraph"))
    b_expect_scan_error(sprintf("`r a`{.num} `r sites`{%s}", cls), label = paste(cls, "another value"))
  }
})

test_that("1.4.2: two classes of the collapse group are a construct error (.pairs .ul .ol .dl)", {
  b_expect_scan_error("`r x`{.ul .ol}", "`r x`{.ul}")
  b_expect_scan_error("`r x`{.ul .and}")
  b_expect_scan_error("`r x`{.pairs .or}", "`r x`{.pairs}")
  b_expect_scan_error("`r x`{.dl .pairs}")
  b_expect_scan_error("`r x`{.and .or}")
})

test_that("1.4.7: trunc with a collapse class, or alone, or after a number class, is legal", {
  expect_identical(b_errs("`r x`{.and trunc=\"3\"}"), character())
  expect_identical(b_errs("`r x`{trunc=\"3\"}"), character())
  expect_identical(b_errs("`r x`{.num .and trunc=\"3\"}"), character())
  expect_identical(b_errs("`r x`{.pairs trunc=\"3\"}"), character())
})

# ---- rendered, both engines --------------------------------------------------------------------------

test_that("1.4.3 + 1.4.6 + 1.4.7: .pairs, trunc and the list formatters render as the rules say (rmarkdown)", {
  b_expect_rows("C", c("pairs", "trunc", "lists"), "rmd")
})

test_that("1.4.3 + 1.4.6 + 1.4.7: .pairs, trunc and the list formatters render the same under Quarto", {
  b_expect_rows("C", c("pairs", "trunc", "lists"), "qmd")
})
