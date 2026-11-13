# Stage 1d: the phrase functions of_n(), about(), ci(), pm() (3.5.1 to 3.5.3).
# Markup rows: helper-1b.R, batch B, group "phrases"; the configuration
# document (ci_level, about_tolerance) from helper-1b.R. Value failures in a
# render are in test-collected.R; the language errors (1.6.8) too.

# ---- of_n() -------------------------------------------------------------------------

test_that("3.5.1: of_n() prints none, the only, both, all and k of n", {
  expect_equal(b_txt(of_n(0, 4, "site", "sites")), "none of the 4 sites")
  expect_equal(b_txt(of_n(0, 2, "site", "sites")), "none of the 2 sites")
  expect_equal(b_txt(of_n(1, 1, "site", "sites")), "the only site")
  expect_equal(b_txt(of_n(2, 2, "site", "sites")), "both sites")
  expect_equal(b_txt(of_n(5, 5, "site", "sites")), "all 5 sites")
  expect_equal(b_txt(of_n(3, 3, "site", "sites")), "all 3 sites")
  expect_equal(b_txt(of_n(3, 7, "site", "sites")), "3 of the 7 sites")
  expect_equal(b_txt(of_n(1, 7, "site", "sites")), "1 of the 7 sites")
  expect_equal(b_txt(of_n(2, 7, "site", "sites")), "2 of the 7 sites")
  expect_equal(b_txt(of_n(1, 2, "site", "sites")), "1 of the 2 sites")
  expect_equal(b_txt(of_n(6, 12, "sample", "samples")), "6 of the 12 samples")
})

test_that("3.5.2: of_n() returns a weft_text whose number is k", {
  for (a in list(c(0, 4), c(1, 1), c(2, 2), c(5, 5), c(3, 7))) {
    x <- of_n(a[1], a[2], "site", "sites")
    expect_s3_class(x, "weft_text")
    expect_equal(attr(x, "number"), a[1], label = paste("of_n(", a[1], ",", a[2], ")"))
    expect_equal(attr(x, "relation"), "=")
    expect_identical(attr(x, "decimals"), FALSE)
  }
})

test_that("3.5.2: an n span (plural()) given of_n()'s result agrees with k", {
  one <- of_n(1, 7, "site", "sites")
  many <- of_n(3, 7, "site", "sites")
  none <- of_n(0, 4, "site", "sites")
  expect_equal(plural(one, "was", "were"), "was")
  expect_equal(plural(many, "was", "were"), "were")
  expect_equal(plural(none, "was", "were"), "were")
  expect_equal(plural(none, "none were", "was", "were"), "none were")
  expect_equal(plural(of_n(1, 1, "site", "sites"), "was", "were"), "was")
})

test_that("5.3.2 + design: of_n() with n = 0, k > n, or a k or n that is not a whole non-negative number is a value error", {
  expect_error(of_n(0, 0, "site", "sites"), class = "weft_value_error")
  expect_error(of_n(5, 3, "site", "sites"), class = "weft_value_error")
  expect_error(of_n(1.5, 3, "site", "sites"), class = "weft_value_error")
  expect_error(of_n(1, 2.5, "site", "sites"), class = "weft_value_error")
  expect_error(of_n(-1, 3, "site", "sites"), class = "weft_value_error")
  expect_error(of_n(1, -3, "site", "sites"), class = "weft_value_error")
})

test_that("1.3.4: a missing value reaching of_n() is a weft_no_value error", {
  expect_error(of_n(NA_real_, 3, "site", "sites"), class = "weft_no_value")
  expect_error(of_n(1, NA_real_, "site", "sites"), class = "weft_no_value")
  expect_error(of_n(numeric(0), 3, "site", "sites"), class = "weft_no_value")
})

# ---- about() -------------------------------------------------------------------------

test_that("3.5.1: about() half, nearly half, just over half (compared as whole percentages)", {
  expect_equal(b_txt(about(0.5)), "half")
  expect_equal(b_txt(about(0.49)), "nearly half")
  expect_equal(b_txt(about(0.51)), "just over half")
  expect_equal(b_txt(about(0.46)), "nearly half")
  expect_equal(b_txt(about(0.54)), "just over half")
  # 49.6% and 50.4% are both 50% when rounded
  expect_equal(b_txt(about(0.496)), "half")
  expect_equal(b_txt(about(0.504)), "half")
})

test_that("design: about() takes to = 1/4, 1/3, 1/2, 2/3, 3/4", {
  expect_equal(b_txt(about(0.25, to = 1/4)), "a quarter")
  expect_equal(b_txt(about(0.24, to = 1/4)), "nearly a quarter")
  expect_equal(b_txt(about(0.26, to = 1/4)), "just over a quarter")
  expect_equal(b_txt(about(0.33, to = 1/3)), "a third")
  expect_equal(b_txt(about(0.32, to = 1/3)), "nearly a third")
  expect_equal(b_txt(about(0.34, to = 1/3)), "just over a third")
  expect_equal(b_txt(about(0.5, to = 1/2)), "half")
  expect_equal(b_txt(about(0.67, to = 2/3)), "two-thirds")
  expect_equal(b_txt(about(0.66, to = 2/3)), "nearly two-thirds")
  expect_equal(b_txt(about(0.68, to = 2/3)), "just over two-thirds")
  expect_equal(b_txt(about(0.75, to = 3/4)), "three-quarters")
  expect_equal(b_txt(about(0.74, to = 3/4)), "nearly three-quarters")
  expect_equal(b_txt(about(0.76, to = 3/4)), "just over three-quarters")
})

test_that("design: about() with another target is an error", {
  expect_true(is.function(about))
  expect_error(about(0.2, to = 1/5), class = "weft_value_error")
  expect_error(about(0.5, to = 0.4), class = "weft_value_error")
})

test_that("design: an x further than the tolerance from `to` is a value error (the sentence would be false)", {
  expect_error(about(0.4), class = "weft_value_error")
  expect_error(about(0.56), class = "weft_value_error")
  expect_error(about(0.9), class = "weft_value_error")
  expect_error(about(0.5 + 0.03, tolerance = 0.01), class = "weft_value_error")
})

test_that("3.5.3: about() takes a tolerance argument", {
  expect_equal(b_txt(about(0.56, tolerance = 0.1)), "just over half")
  expect_equal(b_txt(about(0.42, tolerance = 0.1)), "nearly half")
  expect_equal(b_txt(about(0.52, tolerance = 0.05)), "just over half")
})

test_that("3.5.3: with no setting, about()'s default tolerance is 0.05 (design) and ci()'s level 0.95", {
  expect_equal(b_txt(about(0.54)), "just over half")
  expect_error(about(0.56), class = "weft_value_error")
  expect_match(b_txt(ci(2.1, 1.3, 2.9)), "95% CI", fixed = TRUE)
})

test_that("1.3.4: a missing value reaching about() is a weft_no_value error", {
  expect_error(about(NA_real_), class = "weft_no_value")
  expect_error(about(NaN), class = "weft_no_value")
  expect_error(about(numeric(0)), class = "weft_no_value")
})

test_that("3.5.1: about() returns a weft_text", {
  expect_s3_class(about(0.5), "weft_text")
})

# ---- ci() ---------------------------------------------------------------------------

test_that("3.5.1 + 3.5.3: ci() writes 'to' between the bounds", {
  x <- ci(2.1, 1.3, 2.9)
  expect_s3_class(x, "weft_text")
  expect_equal(b_txt(x), "2.1 (95% CI 1.3 to 2.9)")
})

test_that("design + 1.4.13: ci() numbers print as .num prints them", {
  expect_equal(b_txt(ci(2, 1, 3)), "2 (95% CI 1 to 3)")
  expect_equal(b_txt(ci(12345.678, 10000, 20000.5)), "12,345.7 (95% CI 10,000 to 20,000.5)")
  expect_equal(b_txt(ci(-0.5, -1.2, 0.3)), paste0(B_MINUS, "0.5 (95% CI ", B_MINUS, "1.2 to 0.3)"))
})

test_that("3.5.3: ci() takes a level argument", {
  expect_equal(b_txt(ci(2.1, 1.3, 2.9, level = 0.9)), "2.1 (90% CI 1.3 to 2.9)")
  expect_equal(b_txt(ci(2.1, 1.3, 2.9, level = 0.99)), "2.1 (99% CI 1.3 to 2.9)")
})

test_that("design: ci() takes digits", {
  expect_equal(b_txt(ci(2.1, 1.3, 2.9, digits = 2)), "2.10 (95% CI 1.30 to 2.90)")
  expect_equal(b_txt(ci(2.14, 1.26, 2.9, digits = 1)), "2.1 (95% CI 1.3 to 2.9)")
})

test_that("design: ci()'s record number is the estimate", {
  expect_equal(attr(ci(2.1, 1.3, 2.9), "number"), 2.1)
  expect_equal(attr(ci(2, 1, 3), "number"), 2)
})

test_that("1.3.4: a missing value reaching ci() is a weft_no_value error", {
  expect_error(ci(NA_real_, 1, 2), class = "weft_no_value")
  expect_error(ci(1, NA_real_, 2), class = "weft_no_value")
  expect_error(ci(1, 0, NA_real_), class = "weft_no_value")
})

# ---- pm() ---------------------------------------------------------------------------

test_that("3.5.1: pm() writes est ± se, each as .num prints it", {
  x <- pm(2.1, 0.3)
  expect_s3_class(x, "weft_text")
  expect_equal(b_txt(x), "2.1 ± 0.3")
  expect_equal(b_txt(pm(2, 0.5)), "2 ± 0.5")
  expect_equal(b_txt(pm(2.14, 0.31)), "2.1 ± 0.3")
  expect_equal(b_txt(pm(-2.1, 0.3)), paste0(B_MINUS, "2.1 ± 0.3"))
})

test_that("design: pm() takes digits; its record number is the estimate", {
  expect_equal(b_txt(pm(2.1, 0.3, digits = 2)), "2.10 ± 0.30")
  expect_equal(attr(pm(2.1, 0.3), "number"), 2.1)
})

test_that("1.3.4: a missing value reaching pm() is a weft_no_value error", {
  expect_error(pm(NA_real_, 0.3), class = "weft_no_value")
  expect_error(pm(2.1, NA_real_), class = "weft_no_value")
})

# ---- the transformations after a phrase ----------------------------------------------

test_that("1.4.1: a text class after a phrase function keeps the printed record", {
  x <- fmt_strong(of_n(3, 7, "site", "sites"))
  expect_equal(b_txt(x), "**3 of the 7 sites**")
  expect_equal(attr(x, "number"), 3)
  expect_equal(b_txt(fmt_cap(about(0.49))), "Nearly half")
  expect_equal(b_txt(fmt_cap(of_n(5, 5, "site", "sites"))), "All 5 sites")
})

# ---- rendered, both engines ---------------------------------------------------------------

test_that("3.5.x: the phrase functions render as the rules say (rmarkdown)", {
  b_expect_rows("B", "phrases", "rmd")
})

test_that("3.5.x: the phrase functions render the same under Quarto", {
  b_expect_rows("B", "phrases", "qmd")
})

test_that("3.5.3: ci_level and about_tolerance in _weft.yml are the defaults; an argument beats them", {
  res <- b_cfg()
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  for (tag in c("G02", "G03", "G04")) {
    row <- Filter(function(r) r$tag == tag, CFG_ROWS)[[1]]
    expect_equal(grep(paste0("^", tag, " "), res$text, value = TRUE), row$want, label = row$rule)
  }
})
