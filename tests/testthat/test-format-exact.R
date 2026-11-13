# Package 5a: whole numbers print exactly (rule 1.4.13; dev/design-5.md,
# section A, rules G1 to G3, decision V17, and amendment item 2).
#
# A double that is an exact integer of magnitude at most 2^53 prints every
# digit. A double of 15 or more significant digits beyond that prints the
# digits after the fifteenth as zeros, never the binary expansion. What
# already worked (halves away from zero, 0.15 to "0.2", small decimals,
# sigfig) must not change.

EX_MINUS <- "−"   # U+2212, the default minus sign

ex <- function(x, ...) as.character(unclass(fmt_num(x, ...)))

# ---- G1: no digits or sigfig given ------------------------------------------

test_that("G1: whole doubles up to 2^53 print every digit", {
  expect_identical(ex(999999999999999), "999,999,999,999,999")
  expect_identical(ex(1e15 + 1), "1,000,000,000,000,001")
  expect_identical(ex(1e15), "1,000,000,000,000,000")
  expect_identical(ex(2^53), "9,007,199,254,740,992")
  expect_identical(ex(2^53 - 1), "9,007,199,254,740,991")
  expect_identical(ex(2147483648), "2,147,483,648")
  expect_identical(ex(123456789012), "123,456,789,012")
  expect_identical(ex(1e14), "100,000,000,000,000")
  expect_identical(ex(100000000000001), "100,000,000,000,001")
  expect_identical(ex(999999999999998), "999,999,999,999,998")
})

test_that("G1: negative whole doubles print every digit with U+2212", {
  expect_identical(ex(-(2^53)), paste0(EX_MINUS, "9,007,199,254,740,992"))
  expect_identical(ex(-999999999999999), paste0(EX_MINUS, "999,999,999,999,999"))
  expect_identical(ex(-(1e15 + 1)), paste0(EX_MINUS, "1,000,000,000,000,001"))
  expect_identical(ex(-2147483648), paste0(EX_MINUS, "2,147,483,648"))
})

test_that("G1: R integers and integers stored as doubles print the same", {
  expect_identical(ex(2147483647L), "2,147,483,647")
  expect_identical(ex(-2147483647L), paste0(EX_MINUS, "2,147,483,647"))
  expect_identical(ex(1234567L), ex(1234567))
  expect_identical(ex(0L), "0")
  expect_identical(ex(0), "0")
  expect_identical(ex(7L), "7")
  expect_identical(ex(1000), "1,000")
})

test_that("G1: the number in the record is the whole number", {
  x <- fmt_num(999999999999999)
  expect_identical(attr(x, "number"), 999999999999999)
  expect_identical(attr(x, "decimals"), FALSE)
})

# ---- G2: digits and sigfig --------------------------------------------------

test_that("G2: digits = k keeps the integer digits and adds k zeros", {
  expect_identical(ex(2^53, digits = 2), "9,007,199,254,740,992.00")
  expect_identical(ex(999999999999999, digits = 1), "999,999,999,999,999.0")
  expect_identical(ex(1e15 + 1, digits = 3), "1,000,000,000,000,001.000")
  expect_identical(ex(2^53, digits = 0), "9,007,199,254,740,992")
  expect_identical(ex(-(2^53), digits = 1), paste0(EX_MINUS, "9,007,199,254,740,992.0"))
})

test_that("G2: sigfig still rounds as 1.4.13 rounds", {
  expect_identical(ex(2^53, sigfig = 3), "9,010,000,000,000,000")
  expect_identical(ex(999999999999999, sigfig = 3), "1,000,000,000,000,000")
  expect_identical(ex(1e15 + 1, sigfig = 3), "1,000,000,000,000,000")
  expect_identical(ex(2^53, sigfig = 1), "9,000,000,000,000,000")
  expect_identical(ex(-(2^53), sigfig = 3), paste0(EX_MINUS, "9,010,000,000,000,000"))
})

# ---- G3: ord and count ------------------------------------------------------

test_that("G3: fmt_ord() and fmt_count() print every digit", {
  expect_identical(as.character(unclass(fmt_ord(1e15 + 1))), "1,000,000,000,000,001st")
  expect_identical(as.character(unclass(fmt_count(1e15 + 1))), "1,000,000,000,000,001")
  expect_identical(as.character(unclass(fmt_count(2^53))), "9,007,199,254,740,992")
  expect_identical(as.character(unclass(fmt_ord(999999999999999))), "999,999,999,999,999th")
})

# ---- amendment item 2: past 15 significant digits ----------------------------

test_that("amendment 2: digits after the fifteenth print as zeros, never the binary expansion", {
  expect_identical(ex(2^70), "1,180,591,620,717,410,000,000")
  expect_identical(ex(1e23), "100,000,000,000,000,000,000,000")
  expect_identical(ex(-(2^70)), paste0(EX_MINUS, "1,180,591,620,717,410,000,000"))
  expect_identical(ex(1e22), "10,000,000,000,000,000,000,000")
  # above 2^53 but of 16 digits: read to 15 significant digits
  expect_identical(ex(2^53 + 2), "9,007,199,254,740,990")
  # read to 15 significant digits, rounded: 2^64 = 18446744073709551616
  expect_identical(ex(2^64), "18,446,744,073,709,600,000")
  # no digit of the binary expansion of 1e23 (99999999999999991611392)
  expect_false(grepl("991", ex(1e23), fixed = TRUE))
})

# ---- what must NOT change ----------------------------------------------------

test_that("unchanged: halves round away from zero", {
  expect_identical(ex(0.15), "0.2")
  expect_identical(ex(0.15, digits = 1), "0.2")
  expect_identical(ex(0.25, digits = 1), "0.3")
  expect_identical(ex(0.35, digits = 1), "0.4")
  expect_identical(ex(2.5, digits = 0), "3")
  expect_identical(ex(0.5, digits = 0), "1")
  expect_identical(ex(1.5, digits = 0), "2")
  expect_identical(ex(-2.5, digits = 0), paste0(EX_MINUS, "3"))
  expect_identical(ex(-0.15), paste0(EX_MINUS, "0.2"))
  expect_identical(ex(1.005, digits = 2), "1.01")
  expect_identical(ex(2.5), "2.5")
})

test_that("unchanged: ordinary decimals, small decimals and large non-integers", {
  expect_identical(ex(3.14159), "3.1")
  expect_identical(ex(3.14159, digits = 3), "3.142")
  expect_identical(ex(1234567.891), "1,234,567.9")
  expect_identical(ex(123456789.5), "123,456,789.5")
  expect_identical(ex(12.5), "12.5")
  expect_identical(ex(0.1 + 0.2 - 0.3), "0")
  expect_identical(ex(1e-12), "0")
  expect_identical(ex(0.3 + 1e-12), "0.3")
  expect_identical(ex(0.012345, digits = 3), "0.012")
  expect_identical(ex(0.0004, digits = 4), "0.0004")
})

test_that("unchanged: sigfig at ordinary sizes", {
  expect_identical(ex(0.012345, sigfig = 2), "0.012")
  expect_identical(ex(123.456, sigfig = 4), "123.5")
  expect_identical(ex(1234.5, sigfig = 3), "1,230")
  expect_identical(ex(0.15, sigfig = 1), "0.2")
  expect_identical(ex(123456, sigfig = 2), "120,000")
  expect_identical(ex(99999, sigfig = 1), "100,000")
})

test_that("unchanged: whole numbers well inside the exact range keep their digits", {
  expect_identical(ex(12345678), "12,345,678")
  expect_identical(ex(99999999), "99,999,999")
})

# ---- in a knitted document ---------------------------------------------------

EX_PRE <- c("big <- 999999999999999", "one <- 1", "two53 <- 2^53")

test_that("G1, G2, amendment 2: the .num class in a knitted document", {
  cases <- c(
    "`r 999999999999999`{.num}",                          # 1
    "`r 2^53`{.num}",                                     # 2
    "`r 1e15 + 1`{.num}",                                 # 3
    "`r -(2^53)`{.num}",                                  # 4
    "`r 2147483648`{.num}",                               # 5
    "`r 2147483647L`{.num}",                              # 6
    "`r 2^53`{.num digits=\"2\"}",                        # 7
    "`r 2^53`{.num sigfig=\"3\"}",                        # 8
    "`r 2^70`{.num}",                                     # 9
    "`r 1e23`{.num}",                                     # 10
    "`r 0.15`{.num digits=\"1\"} and `r 2.5`{.num}",      # 11
    "`r 1e15 + 1`{.ord}",                                 # 12
    "`r 1e15 + 1`{.count}"                                # 13
  )
  res <- render_rmd(batch_cases(cases), code = EX_PRE, in_process = TRUE)
  expect_false(res$failed, info = res$message)
  got <- unlist(split_cases(res, length(cases)))
  expect_identical(got, c(
    "999,999,999,999,999",
    "9,007,199,254,740,992",
    "1,000,000,000,000,001",
    paste0(EX_MINUS, "9,007,199,254,740,992"),
    "2,147,483,648",
    "2,147,483,647",
    "9,007,199,254,740,992.00",
    "9,010,000,000,000,000",
    "1,180,591,620,717,410,000,000",
    "100,000,000,000,000,000,000,000",
    "0.2 and 2.5",
    "1,000,000,000,000,001st",
    "1,000,000,000,000,001"
  ))
})

test_that("G1: the # of an n span prints every digit", {
  cases <- c(
    "[# site | # sites]{n=\"big\"}",
    "[# site | # sites]{n=\"two53\"}",
    "[# site | # sites]{n=\"one\"}"
  )
  res <- render_rmd(batch_cases(cases), code = EX_PRE, in_process = TRUE)
  expect_false(res$failed, info = res$message)
  got <- unlist(split_cases(res, length(cases)))
  expect_identical(got, c(
    "999,999,999,999,999 sites",
    "9,007,199,254,740,992 sites",
    "1 site"
  ))
})

test_that("G1: weft_str() prints the same digits outside a knit", {
  expect_identical(weft_str("`r 999999999999999`{.num}"), "999,999,999,999,999")
  expect_identical(weft_str("`r 2^53`{.num}"), "9,007,199,254,740,992")
  x <- 1e15 + 1
  expect_identical(weft_str("[# site | # sites]{n=\"x\"}"), "1,000,000,000,000,001 sites")
})
