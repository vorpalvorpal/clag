# Stage 7a, F1: ci() with plus, pct and short (dev/design-7.md section 2.A,
# N12, the messages E3 and E4, decision D8). Helpers: helper-7a.R. Tests
# marked "control" pass before the new arguments exist.

E4 <- function(level) {
  sprintf(paste0("ci(): the short form prints no level, and `level = %s` was given; ",
                 "give `short = FALSE` to print it, or drop `level` (rule 3.5.3)."), level)
}
E3_BOOL <- function(arg) sprintf("`%s` must be TRUE or FALSE.", arg)
E3_SHORT <- "`short` must be TRUE, FALSE or NULL."

# ---- the signature ----------------------------------------------------------

test_that("N12: ci() takes plus, pct and short after sigfig", {
  expect_identical(names(formals(ci)),
                   c("est", "lo", "hi", "level", "digits", "sigfig", "plus", "pct", "short"))
  expect_identical(formals(ci)$plus, FALSE)
  expect_identical(formals(ci)$pct, FALSE)
  expect_null(formals(ci)$short)
})

# ---- the five outputs of N12 ------------------------------------------------

test_that("N12: the exact outputs", {
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9)), "2.1 (95% CI 1.3 to 2.9)")            # control
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, short = TRUE)), "2.1 (1.3 to 2.9)")
  expect_equal(p7_txt(ci(0.12, 0.08, 0.16, pct = TRUE)), "12% (95% CI 8% to 16%)")
  expect_equal(p7_txt(ci(-0.4, -1.2, 0.4, plus = TRUE)),
               paste0(P7_MINUS, "0.4 (95% CI ", P7_MINUS, "1.2 to +0.4)"))
  expect_equal(p7_txt(ci(0.031, 0.012, 0.052, pct = TRUE, plus = TRUE, short = TRUE)),
               "+3.1% (+1.2% to +5.2%)")
})

test_that("N12: plus signs all three numbers by N2 to N4", {
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, plus = TRUE)), "+2.1 (95% CI +1.3 to +2.9)")
  expect_equal(p7_txt(ci(0, -0.1, 0.1, plus = TRUE)),
               paste0("0 (95% CI ", P7_MINUS, "0.1 to +0.1)"))
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, level = 0.9, plus = TRUE)), "+2.1 (90% CI +1.3 to +2.9)")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, digits = 2, plus = TRUE)), "+2.10 (95% CI +1.30 to +2.90)")
})

test_that("N12: plus = FALSE, pct = FALSE and short = FALSE are the old output (control)", {
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, plus = FALSE, pct = FALSE, short = FALSE)),
               "2.1 (95% CI 1.3 to 2.9)")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, level = 0.9)), "2.1 (90% CI 1.3 to 2.9)")
})

test_that("N12: pct prints every number as .pct prints it; digits and sigfig act on the percentage", {
  expect_equal(p7_txt(ci(0.031, 0.012, 0.052, pct = TRUE, digits = 2)), "3.10% (95% CI 1.20% to 5.20%)")
  expect_equal(p7_txt(ci(0.031, 0.012, 0.052, pct = TRUE, sigfig = 1)), "3% (95% CI 1% to 5%)")
  expect_equal(p7_txt(ci(0.12, 0.08, 0.16, pct = TRUE, level = 0.9)), "12% (90% CI 8% to 16%)")
  expect_equal(p7_txt(ci(0.12, 0.08, 0.16, pct = TRUE, short = TRUE)), "12% (8% to 16%)")
})

test_that("N12: pct with pct_proportion false takes the numbers as percentages already", {
  g2_cfg("pct_proportion: false")
  expect_equal(p7_txt(ci(12, 8, 16, pct = TRUE)), "12% (95% CI 8% to 16%)")
  expect_equal(p7_txt(ci(3.1, 1.2, 5.2, pct = TRUE, plus = TRUE, short = TRUE)),
               "+3.1% (+1.2% to +5.2%)")
  expect_equal(p7_txt(ci(0.12, 0.08, 0.16, pct = TRUE)), "0.1% (95% CI 0.1% to 0.2%)")
})

test_that("N12: the record is the estimate as it prints (sign kept; pct as .pct records it)", {
  r <- ci(-0.4, -1.2, 0.4, plus = TRUE)
  expect_equal(attr(r, "number"), -0.4)
  expect_equal(attr(r, "relation"), "=")
  expect_equal(attr(ci(2.1, 1.3, 2.9, plus = TRUE), "number"), 2.1)
  expect_equal(attr(ci(2.1, 1.3, 2.9, short = TRUE), "number"), 2.1)               # control
  expect_equal(attr(ci(0.12, 0.08, 0.16, pct = TRUE), "number"), p7_rec(0.12, ".pct")$number)
  expect_equal(attr(ci(0.12, 0.08, 0.16, pct = TRUE), "decimals"), p7_rec(0.12, ".pct")$decimals)
})

test_that("N12: the result is still finished wording (a number class on it is a value error)", {
  for (x in list(ci(2.1, 1.3, 2.9, plus = TRUE), ci(2.1, 1.3, 2.9, short = TRUE),
                 ci(0.12, 0.08, 0.16, pct = TRUE))) {
    expect_error(weft:::apply_formatters(x, ".num"), class = "weft_value_error")
  }
})

test_that("N12: the checks on lo, hi and est are on the raw numbers, as now", {
  expect_error(ci(2.1, 2.9, 1.3, plus = TRUE), class = "weft_value_error")
  expect_error(ci(3.5, 1.3, 2.9, pct = TRUE), class = "weft_value_error")
  expect_error(ci(0.5, 1.3, 2.9, short = TRUE), class = "weft_value_error")
  expect_error(ci(2.1, 1.3, 2.9, level = 1.5), class = "weft_value_error")                 # control
  expect_error(ci(NA_real_, 1.3, 2.9, plus = TRUE), class = "weft_no_value")
})

# ---- the setting ci_short ---------------------------------------------------

test_that("N12: short = NULL takes the setting ci_short (default false)", {
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, short = NULL)), "2.1 (95% CI 1.3 to 2.9)")
  g2_cfg("ci_short: true")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9)), "2.1 (1.3 to 2.9)")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, short = NULL)), "2.1 (1.3 to 2.9)")
  expect_equal(p7_txt(ci(0.12, 0.08, 0.16, pct = TRUE, plus = TRUE)), "+12% (+8% to +16%)")
})

test_that("N12: short = FALSE beats ci_short: true", {
  g2_cfg("ci_short: true")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, short = FALSE)), "2.1 (95% CI 1.3 to 2.9)")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, level = 0.9, short = FALSE)), "2.1 (90% CI 1.3 to 2.9)")
})

test_that("N12: ci_short: false is the default behaviour (control)", {
  g2_cfg("ci_short: false")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9)), "2.1 (95% CI 1.3 to 2.9)")
})

# ---- E4 ---------------------------------------------------------------------

test_that("E4: short with a level given in the call is a value error", {
  e <- tryCatch(ci(1, 0, 2, level = 0.9, short = TRUE), error = function(e) e)
  expect_s3_class(e, "weft_value_error")
  expect_equal(conditionMessage(e), E4("0.9"))
  e2 <- tryCatch(ci(1, 0, 2, level = 0.99, short = TRUE, plus = TRUE), error = function(e) e)
  expect_s3_class(e2, "weft_value_error")
  expect_equal(conditionMessage(e2), E4("0.99"))
})

test_that("E4: the same under ci_short: true, with short left to the setting", {
  g2_cfg("ci_short: true")
  e <- tryCatch(ci(1, 0, 2, level = 0.9), error = function(e) e)
  expect_s3_class(e, "weft_value_error")
  expect_equal(conditionMessage(e), E4("0.9"))
})

test_that("E4: a level given with short = FALSE, or with short left at its default, is fine (control)", {
  expect_equal(p7_txt(ci(1, 0, 2, level = 0.9, short = FALSE)), "1 (90% CI 0 to 2)")
  expect_equal(p7_txt(ci(1, 0, 2, level = 0.9)), "1 (90% CI 0 to 2)")
})

test_that("E4: the setting ci_level with the short form is not an error", {
  g2_cfg("ci_level: 0.9")
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9)), "2.1 (90% CI 1.3 to 2.9)")             # control
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9, short = TRUE)), "2.1 (1.3 to 2.9)")
  g2_cfg(c("ci_level: 0.9", "ci_short: true"))
  expect_equal(p7_txt(ci(2.1, 1.3, 2.9)), "2.1 (1.3 to 2.9)")
})

# ---- E3 ---------------------------------------------------------------------

test_that("E3: plus, pct and short must be TRUE or FALSE (short also NULL)", {
  for (bad in list("yes", NA, 1, c(TRUE, FALSE))) {
    for (arg in c("plus", "pct")) {
      e <- tryCatch(do.call(ci, c(list(2.1, 1.3, 2.9), stats::setNames(list(bad), arg))),
                    error = function(e) e)
      expect_s3_class(e, "weft_construct_error")
      expect_equal(conditionMessage(e), E3_BOOL(arg))
    }
    e <- tryCatch(ci(2.1, 1.3, 2.9, short = bad), error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
    expect_equal(conditionMessage(e), E3_SHORT)
  }
  expect_error(ci(2.1, 1.3, 2.9, plus = NULL), class = "weft_construct_error")
  expect_error(ci(2.1, 1.3, 2.9, pct = NULL), class = "weft_construct_error")
})

# ---- the printed-as-zero check ----------------------------------------------

test_that("N12: with pct the printed-as-zero check judges the percentage; one warning for the call", {
  r <- p7_zero_warnings(ci(0.0004, 0.0001, 0.0009, pct = TRUE))
  expect_length(r$zero, 1L)
  expect_equal(p7_txt(r$value), "0.0% (95% CI 0.0% to 0.1%)")
})

test_that("N12: a percentage that prints as a number is not warned, though the proportion is small", {
  r <- p7_zero_warnings(ci(0.004, 0.003, 0.005, pct = TRUE))
  expect_length(r$zero, 0L)
  expect_equal(p7_txt(r$value), "0.4% (95% CI 0.3% to 0.5%)")
})

test_that("N12: without pct the check is as it was (control)", {
  r <- p7_zero_warnings(ci(0.04, 0.01, 0.09))
  expect_length(r$zero, 1L)
  r2 <- p7_zero_warnings(ci(0.0004, 0.0001, 0.0009))
  expect_length(r2$zero, 1L)
})

test_that("N3 via ci(): a bound that prints as zero has no sign, and warns once", {
  r <- p7_zero_warnings(ci(0.5, -0.04, 1.2, plus = TRUE))
  expect_equal(p7_txt(r$value), "+0.5 (95% CI 0.0 to +1.2)")
  expect_length(r$zero, 1L)
})

# ---- knitting ---------------------------------------------------------------

test_that("F1 knit: ci() with plus and short in a sentence", {
  res <- p7_knit(c(
    "```{r, include=FALSE}",
    "b <- 2.1; b_lo <- 1.3; b_hi <- 2.9",
    "```",
    "",
    "The effect was `r ci(b, b_lo, b_hi, plus = TRUE, short = TRUE)`."))
  expect_equal(res$text, "The effect was +2.1 (+1.3 to +2.9).")
})

test_that("F1 knit: ci_short in _weft.yml and a level argument stops the render with E4's text", {
  res <- p7_knit(c("The effect was `r ci(2.1, 1.3, 2.9, level = 0.9)`."),
                 yml = "ci_short: true", may_fail = TRUE)
  expect_true(res$failed)
  expect_match(res$error$message, E4("0.9"), fixed = TRUE)
})

test_that("F1 knit: ci_short: true in _weft.yml prints the short form", {
  res <- p7_knit(c("The effect was `r ci(2.1, 1.3, 2.9)`."), yml = "ci_short: true")
  expect_equal(res$text, "The effect was 2.1 (1.3 to 2.9).")
})

test_that("F1 knit: a ci() with no new argument knits as before (control)", {
  res <- p7_knit(c("The effect was `r ci(2.1, 1.3, 2.9)` and `r ci(2.1, 1.3, 2.9, level = 0.9)`."))
  expect_equal(res$text, "The effect was 2.1 (95% CI 1.3 to 2.9) and 2.1 (90% CI 1.3 to 2.9).")
})
