# Stage 1d: lookup() and brk() (3.3.1 to 3.3.5). Markup rows: helper-1b.R,
# batch B, group "lookup"; failures in values are in test-collected.R.

# ---- lookup() ---------------------------------------------------------------------

tiers <- c(hi = "high", lo = "low", mid = "middling")

test_that("3.3.2: lookup() builds a function of one argument from a named vector", {
  f <- lookup(tiers)
  expect_type(f, "closure")
  expect_length(formals(f), 1L)
  expect_equal(as.character(f("hi")), "high")
  expect_equal(as.character(f("lo")), "low")
  expect_equal(as.character(f("mid")), "middling")
})

test_that("design: a lookup() function vectorises", {
  f <- lookup(tiers)
  expect_equal(as.character(f(c("lo", "hi", "lo"))), c("low", "high", "low"))
})

test_that("3.3.2: a factor is looked up by label, never by integer code", {
  f <- lookup(tiers)
  # integer codes: lo = 1, hi = 2 (the keys are hi, lo, mid, so code 1 would be 'hi')
  fct <- factor(c("lo", "hi"), levels = c("lo", "hi"))
  expect_equal(as.character(f(fct)), c("low", "high"))
  expect_equal(as.character(f(factor("mid", levels = c("zz", "mid")))), "middling")
})

test_that("3.3.2 + design: an unknown key is an error of class weft_value_error", {
  f <- lookup(tiers)
  expect_error(f("zzz"), class = "weft_value_error")
  expect_error(f(c("hi", "zzz")), class = "weft_value_error")
  expect_error(f(factor("zzz")), class = "weft_value_error")
  # case matters: a key is a key
  expect_error(f("HI"), class = "weft_value_error")
})

test_that("3.3.5: given NA a lookup() function raises weft_no_value", {
  f <- lookup(tiers)
  expect_error(f(NA_character_), class = "weft_no_value")
  expect_error(f(NA), class = "weft_no_value")
  expect_error(f(c("hi", NA)), class = "weft_no_value")
  expect_error(f(factor(c("hi", NA))), class = "weft_no_value")
})

test_that("3.3.5: a missing key is never confused with an unknown one", {
  f <- lookup(tiers)
  e <- tryCatch(f(NA_character_), error = function(e) e)
  expect_false(inherits(e, "weft_value_error"))
  e2 <- tryCatch(f("zzz"), error = function(e) e)
  expect_false(inherits(e2, "weft_no_value"))
})

test_that("3.3.2: two lookup() functions do not share their maps", {
  f <- lookup(c(a = "A"))
  g <- lookup(c(a = "other"))
  expect_equal(as.character(f("a")), "A")
  expect_equal(as.character(g("a")), "other")
  expect_error(f("b"), class = "weft_value_error")
})

# ---- brk() ---------------------------------------------------------------------------

trend <- brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")

test_that("3.3.3: brk() takes its formulas in order", {
  expect_equal(as.character(trend(0.9)), "a fall in")
  expect_equal(as.character(trend(0.949)), "a fall in")
  expect_equal(as.character(trend(0.95)), "steady")
  expect_equal(as.character(trend(1)), "steady")
  expect_equal(as.character(trend(1.05)), "steady")
  expect_equal(as.character(trend(1.06)), "a rise in")
  expect_equal(as.character(trend(50)), "a rise in")
})

test_that("3.3.3: the first formula that takes the value wins", {
  f <- brk(. < 10 ~ "a", . < 5 ~ "b", TRUE ~ "c")
  expect_equal(as.character(f(3)), "a")
  expect_equal(as.character(f(7)), "a")
  expect_equal(as.character(f(11)), "c")
})

test_that("3.3.3: a brk() function is a function of one argument and vectorises", {
  expect_type(trend, "closure")
  expect_length(formals(trend), 1L)
  expect_equal(as.character(trend(c(0.5, 1, 2))), c("a fall in", "steady", "a rise in"))
})

test_that("3.3.3: a formula may use any R expression of ., and a variable from where it was written", {
  lim <- 5
  f <- brk(. < lim ~ "low", . %% 2 == 0 ~ "even high", TRUE ~ "odd high")
  expect_equal(as.character(f(c(1, 6, 7))), c("low", "even high", "odd high"))
})

test_that("design: a value no formula takes is an error of class weft_value_error", {
  f <- brk(. < 0 ~ "negative", . > 100 ~ "huge")
  expect_equal(as.character(f(-1)), "negative")
  expect_error(f(5), class = "weft_value_error")
  expect_error(f(c(-1, 5)), class = "weft_value_error")
})

test_that("3.3.5: given NA a brk() function raises weft_no_value and never falls through to TRUE ~", {
  expect_error(trend(NA_real_), class = "weft_no_value")
  expect_error(trend(NA), class = "weft_no_value")
  expect_error(trend(c(1, NA)), class = "weft_no_value")
  expect_error(trend(NaN), class = "weft_no_value")
  # a brk() with no default formula raises the same, not a value error
  f <- brk(. < 0 ~ "negative")
  expect_error(f(NA_real_), class = "weft_no_value")
})

# ---- rendered, both engines ---------------------------------------------------------------

test_that("3.3.1: a lookup() or brk() function in a value renders its phrase (rmarkdown)", {
  b_expect_rows("B", "lookup", "rmd")
})

test_that("3.3.1: a lookup() or brk() function in a value renders its phrase (Quarto)", {
  b_expect_rows("B", "lookup", "qmd")
})
