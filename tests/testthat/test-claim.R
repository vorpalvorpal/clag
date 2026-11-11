# Stage 1a: claim() outside a knit (3.1, 2.4.2, 2.4.3).

failure_message <- function(expr) {
  e <- tryCatch(expr, error = function(e) e)
  expect_s3_class(e, "weft_claim_failed")
  conditionMessage(e)
}

test_that("3.1.1: claim() returns x visibly and unchanged", {
  expect_visible(claim(5, . > 1))
  expect_identical(claim(5, . > 1), 5)
  expect_identical(claim(5L, . > 1), 5L)
  expect_identical(claim("abc", nchar(.) == 3), "abc")
  expect_identical(claim(c(1, 2, 3), length(.) == 3), c(1, 2, 3))
  expect_identical(claim(TRUE, .), TRUE)
  expect_identical(claim(NA, is.na(.)), NA)
  expect_identical(claim(NULL, is.null(.)), NULL)
  expect_identical(claim(list(a = 1, b = "x"), length(.) == 2),
                   list(a = 1, b = "x"))
  df <- data.frame(a = 1:3, b = letters[1:3])
  expect_identical(claim(df, nrow(.) == 3), df)
  f <- factor(c("u", "v", "u"))
  expect_identical(claim(f, nlevels(.) == 2), f)
  expect_identical(claim(mean, is.function(.)), mean)
  s <- structure(1:3, foo = "bar", class = "odd")
  expect_identical(claim(s, length(.) == 3), s)
  d <- as.Date("2020-01-02")
  expect_identical(claim(d, . > as.Date("2020-01-01")), d)
})

test_that("3.1.2: . in a check stands for x", {
  expect_identical(claim(10, . >= 10), 10)
  x <- 7
  expect_identical(claim(x * 2, . == 14), 14)
  expect_identical(claim(c(3, 4), sum(.) == 7, all(. > 0)), c(3, 4))
})

test_that("3.1.2: a check may use variables of the caller, with or without .", {
  lim <- 3
  expect_identical(claim(5, . > lim), 5)
  depth <- 0.7
  expect_identical(claim(depth, depth > 0.5), 0.7)
  expect_identical(claim(depth, . > lim / 10, depth < 1), 0.7)
})

test_that("3.1.3: several checks are all applied", {
  expect_identical(claim(5, . > 1, . < 10), 5)
  expect_error(claim(5, . > 1, . > 10), class = "weft_claim_failed")
  expect_error(claim(5, . > 10, . > 1), class = "weft_claim_failed")
})

test_that("3.1.3, 3.1.4: each failing check is reported, as written, with the value", {
  msg <- failure_message(claim(4217, . > 10000, . < 1))
  expect_match(msg, ". > 10000", fixed = TRUE)
  expect_match(msg, ". < 1", fixed = TRUE)
  expect_match(msg, "4217", fixed = TRUE)
})

test_that("3.1.3: a check that passes is not reported", {
  msg <- failure_message(claim(4217, . > 10000, . < 99999))
  expect_match(msg, ". > 10000", fixed = TRUE)
  expect_false(grepl(". < 99999", msg, fixed = TRUE))
})

test_that("3.1.4: the check is quoted as written, not evaluated into its value", {
  limit <- 987654
  msg <- failure_message(claim(1, . > limit))
  expect_match(msg, "limit", fixed = TRUE)
})

test_that("2.6.2: the failure shows the value of a non-numeric x", {
  msg <- failure_message(claim("abcdef", nchar(.) > 20))
  expect_match(msg, "abcdef", fixed = TRUE)
  expect_match(msg, "nchar(.) > 20", fixed = TRUE)
})

test_that("3.1.5, 2.4.2: outside a knit a failed check stops with class weft_claim_failed", {
  expect_error(claim(1, . > 5), class = "weft_claim_failed")
  expect_error(claim(1, FALSE), class = "weft_claim_failed")
  f <- function() claim(1, . > 5)
  expect_error(f(), class = "weft_claim_failed")
})

test_that("2.4.1, 3.1: a check that is not a single TRUE fails", {
  bad <- list(
    "NA" = quote(claim(1, NA)),
    "NA from comparison" = quote(claim(NA_real_, . > 0)),
    "a vector of TRUEs" = quote(claim(1:3, . > 0)),
    "c(TRUE, TRUE)" = quote(claim(5, c(TRUE, TRUE))),
    "length zero" = quote(claim(5, logical(0))),
    "FALSE" = quote(claim(5, . < 0)),
    "number 1" = quote(claim(5, 1)),
    "string" = quote(claim(5, "TRUE"))
  )
  for (nm in names(bad)) {
    expect_error(eval(bad[[nm]]), class = "weft_claim_failed", label = nm)
  }
})

test_that("3.1.10: claim(x) with no check is a weft_claim_no_check error", {
  expect_error(claim(5), class = "weft_claim_no_check")
  expect_error(claim("a"), class = "weft_claim_no_check")
  expect_error(claim(NULL), class = "weft_claim_no_check")
  e <- tryCatch(claim(5), error = function(e) e)
  expect_false(inherits(e, "weft_claim_failed"))
})

test_that("3.1.1: claim() works inside a larger expression", {
  trend <- function(v) if (v > 0) "up" else "down"
  expect_identical(trend(claim(4, . > 0)), "up")
  expect_identical(sum(claim(c(1, 2), length(.) == 2)), 3)
  expect_identical(paste("n =", claim(3L, . > 2)), "n = 3")
  expect_identical(claim(claim(2, . > 1), . < 3), 2)
  expect_error(trend(claim(-4, . > 0)), class = "weft_claim_failed")
  expect_error(sum(claim(c(1, 2), length(.) == 3)), class = "weft_claim_failed")
})

test_that("2.4.3: claim() does not depend on knitr being active", {
  expect_identical(claim(2, . == 2), 2)
})
