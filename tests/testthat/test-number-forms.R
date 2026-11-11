# Stage 1b: .p, clamp(), .range, .date (1.4.3, 1.4.4, 1.4.11, 1.5.11, 3.5.4, 5.3.2).
# Markup rows: helper-1b.R, batch A, groups "p", "clamp", "range", "date".
# Defaults and formats are the decisions of dev/design-1b.md.

sc <- function(x, ...) weft:::scan_text(x, ...)

# ---- .p ----------------------------------------------------------------------

test_that("1.4.3 + design: fmt_p() prints p = 0.030, p < 0.001, never p = 0.000", {
  cases <- c(
    "0.03" = "p = 0.030", "0.2" = "p = 0.20", "0.5" = "p = 0.50", "0.01" = "p = 0.010",
    "0.0123" = "p = 0.012", "0.0678" = "p = 0.068", "0.004" = "p = 0.004",
    "0.0049" = "p = 0.005", "0.001" = "p = 0.001", "0.0004" = "p < 0.001",
    "0" = "p < 0.001", "0.99" = "p = 0.99", "0.995" = "p > 0.99", "1" = "p > 0.99"
  )
  for (nm in names(cases)) {
    x <- fmt_p(as.numeric(nm))
    expect_s3_class(x, "weft_text")
    expect_equal(b_txt(x), cases[[nm]], label = paste("fmt_p(", nm, ")"))
  }
  expect_false(any(grepl("0\\.000", vapply(c(0, 1e-9, 0.0001), function(v) b_txt(fmt_p(v)), ""))))
})

test_that("1.4.3: fmt_p() is element-wise", {
  expect_equal(b_txt(fmt_p(c(0.03, 0.0004, 0.2))), c("p = 0.030", "p < 0.001", "p = 0.20"))
})

test_that("1.4.11 + design: .p's printed record is the number printed and its relation", {
  a <- b_rec(fmt_p(0.03))
  expect_equal(a$number, 0.03)
  expect_equal(a$relation, "=")
  expect_true(a$decimals)
  b <- b_rec(fmt_p(0.0004))
  expect_equal(b$number, 0.001)
  expect_equal(b$relation, "<")
  d <- b_rec(fmt_p(0.999))
  expect_equal(d$number, 0.99)
  expect_equal(d$relation, ">")
})

test_that("1.4.12 + 1.4.11: a wording class on a p bound is a value error; a text class keeps the relation", {
  expect_error(fmt_word(fmt_p(0.0004)), class = "weft_value_error")
  expect_error(fmt_count(fmt_p(0.0004)), class = "weft_value_error")
  s <- fmt_strong(fmt_p(0.0004))
  expect_equal(b_txt(s), "**p < 0.001**")
  expect_equal(attr(s, "relation"), "<")
})

test_that("5.3.2: .p outside 0 to 1 is a value error", {
  expect_error(fmt_p(-0.1), class = "weft_value_error")
  expect_error(fmt_p(1.1), class = "weft_value_error")
  expect_error(fmt_p(c(0.5, 2)), class = "weft_value_error")
})

test_that("1.3.4: a missing value reaching .p is a weft_no_value error", {
  expect_error(fmt_p(NA_real_), class = "weft_no_value")
  expect_error(fmt_p(NaN), class = "weft_no_value")
  expect_error(fmt_p(c(0.5, NA)), class = "weft_no_value")
  expect_error(fmt_p(numeric(0)), class = "weft_no_value")
})

# ---- clamp() -----------------------------------------------------------------

test_that("3.5.1: clamp() inside the bounds prints the value as .num does, relation =", {
  x <- clamp(5, floor = 1, ceiling = 99)
  expect_s3_class(x, "weft_text")
  expect_equal(b_txt(x), "5")
  expect_equal(attr(x, "relation"), "=")
  expect_equal(attr(x, "number"), 5)
  expect_equal(b_txt(clamp(2.46, 1, 99)), "2.5")
  expect_equal(b_txt(clamp(12345.678, 1, 99999)), "12,345.7")
  expect_equal(b_txt(clamp(5)), "5")                # no bounds at all
})

test_that("3.5.1 + 3.5.4: clamp() outside the bounds prints a bound and sets the relation", {
  lo <- clamp(0.5, floor = 1)
  expect_equal(b_txt(lo), "< 1")
  expect_equal(attr(lo, "relation"), "<")
  hi <- clamp(150, ceiling = 99)
  expect_equal(b_txt(hi), "> 99")
  expect_equal(attr(hi, "relation"), ">")
  expect_equal(b_txt(clamp(c(0.5, 5, 150), floor = 1, ceiling = 99)), c("< 1", "5", "> 99"))
})

test_that("3.5.1: a value equal to a bound is inside it", {
  expect_equal(b_txt(clamp(1, floor = 1, ceiling = 99)), "1")
  expect_equal(b_txt(clamp(99, floor = 1, ceiling = 99)), "99")
  expect_equal(attr(clamp(1, floor = 1), "relation"), "=")
  expect_equal(attr(clamp(99, ceiling = 99), "relation"), "=")
})

test_that("3.5.4 + 1.4.1: a text class after clamp() keeps the bound and its relation", {
  x <- fmt_strong(clamp(0.5, floor = 1))
  expect_equal(b_txt(x), "**< 1**")
  expect_equal(attr(x, "relation"), "<")
  y <- fmt_em(clamp(150, ceiling = 99))
  expect_equal(b_txt(y), "*> 99*")
  expect_equal(attr(y, "relation"), ">")
})

test_that("1.4.12 + 1.4.11: clamp() then a wording class is a value error when it printed a bound", {
  expect_error(fmt_word(clamp(0.5, floor = 1)), class = "weft_value_error")
  expect_error(fmt_count(clamp(150, ceiling = 99)), class = "weft_value_error")
  expect_error(fmt_ord(clamp(0.5, floor = 1)), class = "weft_value_error")
  # inside the bounds the same call is a plain whole number
  expect_equal(b_txt(fmt_word(clamp(5, floor = 1))), "five")
})

test_that("1.3.4: a missing value reaching clamp() is a weft_no_value error", {
  expect_error(clamp(NA_real_, floor = 1), class = "weft_no_value")
  expect_error(clamp(NaN, floor = 1), class = "weft_no_value")
  expect_error(clamp(numeric(0), floor = 1), class = "weft_no_value")
})

# ---- .range ------------------------------------------------------------------

test_that("1.4.3 + 1.4.4: fmt_range() prints an en dash, a single number, or ' to '", {
  expect_equal(b_txt(fmt_range(c(3, 5))), paste0("3", B_EN, "5"))
  expect_equal(b_txt(fmt_range(c(1.5, 2.5))), paste0("1.5", B_EN, "2.5"))
  expect_equal(b_txt(fmt_range(c(3, 3))), "3")
  expect_equal(b_txt(fmt_range(c(-5, -3))), paste0(B_MINUS, "5 to ", B_MINUS, "3"))
  expect_equal(b_txt(fmt_range(c(-2, 3))), paste0(B_MINUS, "2 to 3"))
  # (a first end above the second is a value error: ruling C, test-review-d.R)
  expect_equal(b_txt(fmt_range(c(-3, 2))), paste0(B_MINUS, "3 to 2"))
  expect_equal(b_txt(fmt_range(c(-5, -5))), paste0(B_MINUS, "5"))
  expect_equal(b_txt(fmt_range(c(10000, 20000))), paste0("10,000", B_EN, "20,000"))
})

test_that("1.4.1: fmt_range() joins what the number stage printed, and has no number", {
  expect_equal(b_txt(fmt_range(fmt_num(c(3, 5), digits = 1))), paste0("3.0", B_EN, "5.0"))
  expect_equal(b_txt(fmt_range(fmt_pct(c(0.1, 0.2)))), paste0("10%", B_EN, "20%"))
  expect_equal(b_txt(fmt_range(fmt_num(c(-5, -3)))), paste0(B_MINUS, "5 to ", B_MINUS, "3"))
  x <- fmt_range(c(3, 5))
  expect_s3_class(x, "weft_text")
  expect_length(x, 1L)
  expect_true(is.na(attr(x, "number")))
})

test_that("5.3.2: .range on a value that is not of length 2 is a value error", {
  expect_error(fmt_range(1), class = "weft_value_error")
  expect_error(fmt_range(c(1, 2, 3)), class = "weft_value_error")
})

test_that("1.3.4: a missing end reaching .range is a weft_no_value error", {
  expect_error(fmt_range(c(1, NA)), class = "weft_no_value")
  expect_error(fmt_range(c(NaN, 2)), class = "weft_no_value")
})

# ---- .date -------------------------------------------------------------------

test_that("1.4.3 + design: fmt_date() prints '3 June 2024' with no leading zero", {
  expect_equal(b_txt(fmt_date(as.Date("2024-06-03"))), "3 June 2024")
  expect_equal(b_txt(fmt_date(as.Date("2024-01-05"))), "5 January 2024")
  expect_equal(b_txt(fmt_date(as.Date("2024-12-31"))), "31 December 2024")
  expect_equal(b_txt(fmt_date(as.POSIXct("2024-06-03 23:30:00", tz = "UTC"))), "3 June 2024")
  expect_equal(b_txt(fmt_date(as.POSIXlt("2024-06-03 08:00:00", tz = "UTC"))), "3 June 2024")
})

test_that("1.4.1: fmt_date() is element-wise; a date has no number", {
  x <- fmt_date(as.Date(c("2024-06-03", "2024-07-04")))
  expect_s3_class(x, "weft_text")
  expect_equal(b_txt(x), c("3 June 2024", "4 July 2024"))
  expect_true(all(is.na(attr(fmt_date(as.Date("2024-06-03")), "number"))))
  expect_equal(attr(fmt_date(as.Date("2024-06-03")), "relation"), "=")
})

test_that("design + 5.3.2: .date on anything but a Date or POSIXt is a value error", {
  expect_error(fmt_date("2024-06-03"), class = "weft_value_error")
  expect_error(fmt_date(19000), class = "weft_value_error")
  expect_error(fmt_date(TRUE), class = "weft_value_error")
})

test_that("1.3.4: a missing date reaching .date is a weft_no_value error", {
  expect_error(fmt_date(as.Date(NA)), class = "weft_no_value")
  expect_error(fmt_date(as.Date(c("2024-06-03", NA))), class = "weft_no_value")
  expect_error(fmt_date(as.Date(character(0))), class = "weft_no_value")
})

# ---- the scanner ----------------------------------------------------------------

test_that("1.4.2: two number-stage classes with .p or .date are a construct error", {
  b_expect_scan_error("Value `r x`{.p .num}", "Value `r x`{.p}")
  b_expect_scan_error("Value `r x`{.p .pct}")
  b_expect_scan_error("Value `r x`{.pct .p}")
  b_expect_scan_error("Value `r d`{.date .num}", "Value `r d`{.date}")
  b_expect_scan_error("Value `r d`{.date .p}")
})

test_that("1.4.7 + design: digits or sigfig with .p is a construct error", {
  b_expect_scan_error("Value `r x`{.p digits=\"2\"}", "Value `r x`{.p}")
  b_expect_scan_error("Value `r x`{.p sigfig=\"2\"}")
  b_expect_scan_error("Value `r x`{.p digits=\"2\" .strong}")
})

test_that("1.4.2: .range with another collapse class is a construct error", {
  b_expect_scan_error("Value `r x`{.range .and}", "Value `r x`{.range}")
  b_expect_scan_error("Value `r x`{.or .range}")
})

test_that("1.5.11 + 1.5.7: .range on an n span is legal; two collapse classes on one are not", {
  expect_identical(b_errs("[# site | # sites]{.range n=\"c(lo, hi)\"}"), character())
  b_expect_scan_error("[# site | # sites]{.range .and n=\"c(lo, hi)\"}")
})

test_that("1.4.7: .p, .range and .date are formatters, so a text span with them is not weft's (1.1.9)", {
  # a formatter class on a bracket with no governor or marker key passes through
  r <- sc("[0.03]{.p}")
  expect_equal(nrow(r), 0L)
})

# ---- rendered, both engines ------------------------------------------------------

test_that("1.4.3 + 1.4.4 + 3.5.1: .p, clamp(), .range and .date render as the rules say (rmarkdown)", {
  b_expect_rows("A", c("p", "clamp", "range", "date"), "rmd")
})

test_that("1.4.3 + 1.4.4 + 3.5.1: .p, clamp(), .range and .date render the same under Quarto", {
  b_expect_rows("A", c("p", "clamp", "range", "date"), "qmd")
})

test_that("design: date_format in _weft.yml changes .date", {
  res <- b_cfg()
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  expect_equal(grep("^G01 ", res$text, value = TRUE), "G01 03/06/2024")
})
