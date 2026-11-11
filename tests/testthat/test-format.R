# Stage 1a: the fmt_*() functions, glue_vec(), plural(), the weft_text record.

MINUS <- "−"   # the default minus sign (design note, 9.1.5)
TIMES <- "×"

txt <- function(x) as.character(x)
rec <- function(x) {
  list(
    text = as.character(x),
    number = attr(x, "number"),
    decimals = attr(x, "decimals"),
    relation = attr(x, "relation")
  )
}
# a bound such as "< 1", built by hand from the record layout of the design note
bound <- function(text, number) {
  structure(text, class = c("weft_text", "character"),
            number = number, decimals = FALSE, relation = "<")
}

# ---- the weft_text record ----------------------------------------------

test_that("1.4.11, 3.4.2: a fmt_*() result is a weft_text holding the printed record", {
  x <- fmt_num(3.14159)
  expect_identical(class(x), c("weft_text", "character"))
  expect_equal(txt(x), "3.1")
  expect_equal(attr(x, "number"), 3.1)
  expect_identical(attr(x, "decimals"), TRUE)
  expect_equal(attr(x, "relation"), "=")

  y <- fmt_num(3)
  expect_equal(txt(y), "3")
  expect_equal(attr(y, "number"), 3)
  expect_identical(attr(y, "decimals"), FALSE)
  expect_equal(attr(y, "relation"), "=")
})

test_that("1.4.11: every fmt_*() returns a weft_text", {
  fs <- list(
    fmt_num(2), fmt_pct(0.2), fmt_sci(1234), fmt_no(2), fmt_word(2),
    fmt_count(2), fmt_ord(2), fmt_and(c("a", "b")), fmt_or(c("a", "b")),
    fmt_strong("a"), fmt_em("a")
  )
  for (i in seq_along(fs)) {
    expect_s3_class(fs[[i]], "weft_text")
    expect_type(fs[[i]], "character")
  }
})

test_that("1.4.11: the number is the number as printed, not the raw value", {
  expect_equal(attr(fmt_num(2.04), "number"), 2.0)
  expect_equal(attr(fmt_num(2.06), "number"), 2.1)
  expect_equal(attr(fmt_num(3.14159, digits = 2), "number"), 3.14)
  expect_equal(attr(fmt_num(0.012345, sigfig = 2), "number"), 0.012)
})

test_that("1.4.11, 3.4.2: stages ii to iv pass the record through", {
  x <- fmt_word(fmt_num(3))
  expect_equal(txt(x), "three")
  expect_equal(attr(x, "number"), 3)
  expect_identical(attr(x, "decimals"), FALSE)
  expect_equal(attr(x, "relation"), "=")

  x <- fmt_strong(fmt_num(3.14159))
  expect_match(txt(x), "^(\\*\\*|__)3\\.1(\\*\\*|__)$")
  expect_equal(attr(x, "number"), 3.1)
  expect_identical(attr(x, "decimals"), TRUE)

  x <- fmt_ord(fmt_num(21))
  expect_equal(txt(x), "21st")
  expect_equal(attr(x, "number"), 21)

  x <- fmt_no(fmt_num(0))
  expect_equal(txt(x), "no")
  expect_equal(attr(x, "number"), 0)
})

test_that("1.4.11: a collapse has no number and length one", {
  x <- fmt_and(fmt_num(c(1, 2.5, 3)))
  expect_length(x, 1L)
  expect_true(is.na(attr(x, "number")))
  x <- fmt_or(c("a", "b"))
  expect_length(x, 1L)
  expect_true(is.na(attr(x, "number")))
})

test_that("1.4.1: stages i and ii are element-wise", {
  x <- fmt_num(c(1, 2.5, 3))
  expect_equal(txt(x), c("1", "2.5", "3"))
  expect_equal(attr(x, "number"), c(1, 2.5, 3))
  expect_equal(txt(fmt_word(c(1, 2, 3))), c("one", "two", "three"))
  expect_equal(txt(fmt_ord(c(1, 2, 3))), c("1st", "2nd", "3rd"))
})

test_that("3.4.2: carrying a record through a chain of calls", {
  x <- fmt_em(fmt_word(fmt_no(fmt_num(0))))
  expect_s3_class(x, "weft_text")
  expect_equal(attr(x, "number"), 0)
})

# ---- .num / fmt_num ----------------------------------------------------

test_that("1.4.13: .num prints a whole number with no decimals, others to default digits", {
  cases <- list(
    list(3, "3"), list(0, "0"), list(1, "1"), list(100, "100"),
    list(3.14159, "3.1"), list(0.5, "0.5"), list(2.04, "2.0"),
    list(1.04, "1.0"), list(99.96, "100.0")
  )
  for (cs in cases) {
    expect_equal(txt(fmt_num(cs[[1]])), cs[[2]], label = format(cs[[1]]))
  }
})

test_that("1.4.13: digits and sigfig on the construct ask for decimals", {
  cases <- list(
    list(quote(fmt_num(3, digits = 2)), "3.00"),
    list(quote(fmt_num(1, digits = 1)), "1.0"),
    list(quote(fmt_num(3.14159, digits = 3)), "3.142"),
    list(quote(fmt_num(2.7, digits = 0)), "3"),
    list(quote(fmt_num(0.012345, sigfig = 2)), "0.012"),
    list(quote(fmt_num(123.456, sigfig = 4)), "123.5"),
    list(quote(fmt_num(1234.5, sigfig = 3)), "1,230")
  )
  for (cs in cases) {
    expect_equal(txt(eval(cs[[1]])), cs[[2]], label = deparse(cs[[1]]))
  }
  expect_identical(attr(fmt_num(3, digits = 2), "decimals"), TRUE)
  expect_identical(attr(fmt_num(2.7, digits = 0), "decimals"), FALSE)
})

test_that("9.1.5: thousands mark applies from 1000 up (entry 34), never below; minus is U+2212", {
  cases <- list(
    list(999, "999"), list(1000, "1,000"), list(9999, "9,999"),
    list(10000, "10,000"), list(1234567, "1,234,567"),
    list(12345.678, "12,345.7"),
    list(-5, paste0(MINUS, "5")), list(-1234.5, paste0(MINUS, "1,234.5")),
    list(-12345, paste0(MINUS, "12,345"))
  )
  for (cs in cases) {
    expect_equal(txt(fmt_num(cs[[1]])), cs[[2]], label = format(cs[[1]]))
  }
})

test_that("1.4.13: a negative number's record keeps its sign", {
  expect_equal(attr(fmt_num(-5), "number"), -5)
})

# ---- .pct --------------------------------------------------------------

test_that("1.4.3, design note: .pct reads a proportion and applies 1.4.13 to the percentage", {
  cases <- list(
    list(0.12, "12%"), list(0.5, "50%"), list(1, "100%"), list(0, "0%"),
    list(0.125, "12.5%"), list(0.1234, "12.3%"), list(0.0123, "1.2%"),
    list(0.29, "29%"), list(0.07, "7%"), list(0.58, "58%"),
    list(-0.05, paste0(MINUS, "5%"))
  )
  for (cs in cases) {
    expect_equal(txt(fmt_pct(cs[[1]])), cs[[2]], label = format(cs[[1]]))
  }
  expect_equal(txt(fmt_pct(0.12, digits = 2)), "12.00%")
  expect_equal(txt(fmt_pct(0.1234, digits = 0)), "12%")
  expect_equal(txt(fmt_pct(0.1234, sigfig = 3)), "12.3%")
})

test_that("1.4.11: .pct records the number as printed and whether decimals show", {
  x <- fmt_pct(0.12)
  expect_equal(attr(x, "number"), 12)
  expect_identical(attr(x, "decimals"), FALSE)
  x <- fmt_pct(0.125)
  expect_equal(attr(x, "number"), 12.5)
  expect_identical(attr(x, "decimals"), TRUE)
})

# ---- .sci --------------------------------------------------------------

test_that("design note: .sci prints a markdown-superscript exponent", {
  expect_equal(txt(fmt_sci(1234)), paste0("1.2 ", TIMES, " 10^3^"))
  expect_equal(txt(fmt_sci(1234, digits = 2)), paste0("1.23 ", TIMES, " 10^3^"))
  expect_equal(txt(fmt_sci(1234, sigfig = 3)), paste0("1.23 ", TIMES, " 10^3^"))
  expect_equal(txt(fmt_sci(56700, digits = 1)), paste0("5.7 ", TIMES, " 10^4^"))
  expect_match(txt(fmt_sci(0.00012)), paste0("^1\\.2 ", TIMES, " 10\\^.4\\^$"))
})

# ---- .no ---------------------------------------------------------------

test_that("1.4.3: .no prints a printed zero as no", {
  expect_equal(txt(fmt_no(0)), "no")
  expect_equal(txt(fmt_no(3)), "3")
  expect_equal(txt(fmt_no(2.5)), "2.5")
  expect_equal(txt(fmt_no(c(0, 1, 0))), c("no", "1", "no"))
  expect_equal(attr(fmt_no(0), "relation"), "=")
})

# ---- .word / .count / .ord ---------------------------------------------

test_that("1.4.3, design note: .word spells with hyphens and no and", {
  cases <- list(
    list(0, "zero"), list(1, "one"), list(3, "three"), list(10, "ten"),
    list(12, "twelve"), list(13, "thirteen"), list(20, "twenty"),
    list(21, "twenty-one"), list(40, "forty"), list(99, "ninety-nine"),
    list(55, "fifty-five")
  )
  for (cs in cases) {
    expect_equal(txt(fmt_word(cs[[1]])), cs[[2]], label = format(cs[[1]]))
  }
})

test_that("1.4.12: .word prints digits from the limit (default 100) up", {
  expect_equal(txt(fmt_word(99)), "ninety-nine")
  expect_equal(txt(fmt_word(100)), "100")
  expect_equal(txt(fmt_word(101)), "101")
  expect_equal(txt(fmt_word(150)), "150")
  expect_equal(txt(fmt_word(1000)), "1,000")
  expect_equal(txt(fmt_word(12345)), "12,345")
})

test_that("1.4.3, 1.4.12: .count is a word below the threshold (default 10), digits from it up", {
  cases <- list(
    list(0, "zero"), list(3, "three"), list(9, "nine"),
    list(10, "10"), list(12, "12"), list(100, "100")
  )
  for (cs in cases) {
    expect_equal(txt(fmt_count(cs[[1]])), cs[[2]], label = format(cs[[1]]))
  }
})

test_that("1.4.3, design note: .ord prints 1st 2nd 3rd 4th 11th 21st", {
  cases <- list(
    list(0, "0th"), list(1, "1st"), list(2, "2nd"), list(3, "3rd"),
    list(4, "4th"), list(10, "10th"), list(11, "11th"), list(12, "12th"),
    list(13, "13th"), list(21, "21st"), list(22, "22nd"), list(23, "23rd"),
    list(24, "24th"), list(101, "101st"), list(111, "111th"),
    list(112, "112th"), list(113, "113th"), list(122, "122nd")
  )
  for (cs in cases) {
    expect_equal(txt(fmt_ord(cs[[1]])), cs[[2]], label = format(cs[[1]]))
  }
})

test_that("1.4.12: wording classes refuse a decimal, a negative", {
  fs <- list(word = fmt_word, count = fmt_count, ord = fmt_ord)
  for (nm in names(fs)) {
    expect_error(fs[[nm]](2.5), class = "weft_value_error", label = paste(nm, "2.5"))
    expect_error(fs[[nm]](-1), class = "weft_value_error", label = paste(nm, "-1"))
    expect_error(fs[[nm]](c(1, 2.5)), class = "weft_value_error",
                 label = paste(nm, "vector"))
    expect_error(fs[[nm]](fmt_num(3.14159)), class = "weft_value_error",
                 label = paste(nm, "printed 3.1"))
  }
})

test_that("1.4.12: a bound is refused by a wording class", {
  b <- bound("< 1", 1)
  expect_error(fmt_word(b), class = "weft_value_error")
  expect_error(fmt_count(b), class = "weft_value_error")
  expect_error(fmt_ord(b), class = "weft_value_error")
})

test_that("1.4.12: whole-ness is judged on the number as printed", {
  # 2.04 printed to no decimals is 2: whole
  x <- fmt_num(2.04, digits = 0)
  expect_equal(txt(fmt_word(x)), "two")
  expect_equal(txt(fmt_ord(x)), "2nd")
  # 3.0000 is whole as printed whatever digits show
  expect_equal(txt(fmt_word(fmt_num(21))), "twenty-one")
})

# ---- 1.4.12 / 1.3.4 failures -------------------------------------------

test_that("1.3.4: a missing value reaching a formatter is a weft_no_value error", {
  fs <- list(
    num = fmt_num, pct = fmt_pct, sci = fmt_sci, no = fmt_no,
    word = fmt_word, count = fmt_count, ord = fmt_ord
  )
  missing_vals <- list(
    "NA" = NA_real_, "NaN" = NaN, "Inf" = Inf, "-Inf" = -Inf,
    "length zero" = numeric(0), "NA in a vector" = c(1, NA),
    "integer NA" = NA_integer_
  )
  for (f in names(fs)) {
    for (m in names(missing_vals)) {
      expect_error(fs[[f]](missing_vals[[m]]), class = "weft_no_value",
                   label = paste0("fmt_", f, "(", m, ")"))
    }
  }
})

test_that("1.3.4: fmt_and and fmt_or refuse a missing element and an empty vector", {
  expect_error(fmt_and(character(0)), class = "weft_no_value")
  expect_error(fmt_or(character(0)), class = "weft_no_value")
  expect_error(fmt_and(c("a", NA)), class = "weft_no_value")
  expect_error(fmt_or(c(NA_character_, "b")), class = "weft_no_value")
})

# ---- collapse ----------------------------------------------------------

test_that("3.4.3, 1.4.3: glue_vec joins with a final and", {
  expect_equal(txt(glue_vec(c("a", "b", "c"))), "a, b and c")
  expect_equal(txt(glue_vec(c("a", "b"))), "a and b")
  expect_equal(txt(glue_vec("a")), "a")
  expect_equal(txt(glue_vec(c("a", "b", "c", "d"))), "a, b, c and d")
})

test_that("3.4.3, 1.4.7: glue_vec takes sep and last", {
  expect_equal(txt(glue_vec(c("a", "b", "c"), sep = "; ")), "a; b and c")
  expect_equal(txt(glue_vec(c("a", "b", "c"), last = " or ")), "a, b or c")
  expect_equal(txt(glue_vec(c("a", "b", "c"), last = ", and ")), "a, b, and c")
  expect_equal(txt(glue_vec(c("a", "b", "c"), sep = "; ", last = " & ")), "a; b & c")
  # with two items only the last separator is used
  expect_equal(txt(glue_vec(c("a", "b"), sep = "; ", last = " & ")), "a & b")
  expect_equal(txt(glue_vec(c("a", "b", "c"), sep = "", last = "")), "abc")
})

test_that("1.4.3, 3.4.1: fmt_and and fmt_or collapse with their words", {
  expect_equal(txt(fmt_and(c("a", "b", "c"))), "a, b and c")
  expect_equal(txt(fmt_or(c("a", "b", "c"))), "a, b or c")
  expect_equal(txt(fmt_and(c("a", "b"))), "a and b")
  expect_equal(txt(fmt_or(c("a", "b"))), "a or b")
  expect_equal(txt(fmt_and("a")), "a")
  expect_equal(txt(fmt_or("a")), "a")
})

test_that("1.4.7: fmt_and and fmt_or take sep and last", {
  expect_equal(txt(fmt_and(c("a", "b", "c"), sep = "; ")), "a; b and c")
  expect_equal(txt(fmt_and(c("a", "b", "c"), last = " & ")), "a, b & c")
  expect_equal(txt(fmt_or(c("a", "b", "c"), sep = " / ", last = " or ")), "a / b or c")
  expect_equal(txt(fmt_or(c("a", "b", "c"), last = ", or ")), "a, b, or c")
})

test_that("1.4.1: a collapse acts on the elements as printed by earlier stages", {
  expect_equal(txt(fmt_and(fmt_num(c(1, 2.5, 3)))), "1, 2.5 and 3")
  expect_equal(txt(fmt_or(fmt_word(c(1, 2, 3)))), "one, two or three")
  expect_equal(txt(fmt_and(fmt_num(c(12345, -2)))),
               paste0("12,345 and ", MINUS, "2"))
})

# ---- .strong / .em -----------------------------------------------------

test_that("1.4.3: .strong and .em are markdown emphasis", {
  expect_match(txt(fmt_strong("results")), "^(\\*\\*|__)results(\\*\\*|__)$")
  expect_match(txt(fmt_em("results")), "^(\\*|_)results(\\*|_)$")
  expect_false(grepl("^(\\*\\*|__)", txt(fmt_em("results"))))
  expect_true(is.na(attr(fmt_strong("results"), "number")))
})

# ---- plural() ----------------------------------------------------------

test_that("1.5.1, 3.2.2: plural with two arms is one / other", {
  expect_equal(plural(1, "a person", "# people"), "a person")
  expect_equal(plural(2, "a person", "# people"), "2 people")
  expect_equal(plural(0, "a person", "# people"), "0 people")
  expect_equal(plural(37, "a person", "# people"), "37 people")
  expect_equal(plural(2, "file", "files"), "files")
})

test_that("1.5.1: plural with one arm is a template for #", {
  expect_equal(plural(5, "# sites"), "5 sites")
  expect_equal(plural(1, "# site"), "1 site")
  expect_equal(plural(0, "# sites"), "0 sites")
  expect_equal(plural(5, "# of # sites"), "5 of 5 sites")
})

test_that("1.5.1: plural with three arms is zero / one / other", {
  arms <- c("no people", "a person", "# people")
  expect_equal(plural(0, arms[1], arms[2], arms[3]), "no people")
  expect_equal(plural(1, arms[1], arms[2], arms[3]), "a person")
  expect_equal(plural(2, arms[1], arms[2], arms[3]), "2 people")
  expect_equal(plural(7, arms[1], arms[2], arms[3]), "7 people")
})

test_that("1.5.1, 3.2.2: plural with four arms is zero / one / two / other", {
  f <- function(k) plural(k, "never", "once", "twice", "# times")
  expect_equal(f(0), "never")
  expect_equal(f(1), "once")
  expect_equal(f(2), "twice")
  expect_equal(f(3), "3 times")
  expect_equal(f(40), "40 times")
})

test_that("1.5.9: selection sees the value as it prints (1.0 takes other)", {
  expect_equal(plural(1.04, "one", "other"), "other")
  expect_equal(plural(1.04, "a person", "# people"), "1.0 people")
  expect_equal(plural(1.04, "none", "one", "# other"), "1.0 other")
  expect_equal(plural(1.04, "never", "once", "twice", "# times"), "1.0 times")
  # a whole number prints with no decimals (1.5.18), so 1 is one
  expect_equal(plural(1, "one", "other"), "one")
  expect_equal(plural(1L, "one", "other"), "one")
})

test_that("1.5.8: # is the governor printed by the default class", {
  expect_equal(plural(12345, "# site", "# sites"), "12,345 sites")
  expect_equal(plural(2.5, "# site", "# sites"), "2.5 sites")
  expect_equal(plural(-3, "# site", "# sites"), paste0(MINUS, "3 sites"))
  expect_equal(plural(1234, "# site", "# sites"), "1,234 sites")
})

test_that("1.5.12: arms are trimmed", {
  expect_equal(plural(1, "  a  ", "  b  "), "a")
  expect_equal(plural(2, "  a  ", "  b  "), "b")
  expect_equal(plural(2, "x", "  # y  "), "2 y")
})

test_that("1.5.12: escapes in plural() (no separators: each argument is one arm)", {
  expect_equal(plural(1, "a||b", "c"), "a|b")
  expect_equal(plural(2, "a||b", "c||d"), "c|d")
  expect_equal(plural(1, "a\\|b", "c"), "a|b")
  expect_equal(plural(1, "## #", "x"), "# 1")
  expect_equal(plural(1, "a \\# b", "c"), "a 1 b")
  # a single | in an argument is not a separator: still one arm
  expect_length(plural(1, "a | b", "c"), 1L)
})

test_that("3.2.2: plural returns a length-one character", {
  r <- plural(3, "a", "# b")
  expect_type(r, "character")
  expect_length(r, 1L)
})

test_that("1.6.2, 3.2.2: plural allows 1 to 4 arms in English", {
  expect_error(plural(1), class = "weft_construct_error")
  expect_error(plural(1, "a", "b", "c", "d", "e"), class = "weft_construct_error")
  expect_identical(as.character(plural(5, "# things")), "5 things")
  expect_identical(as.character(plural(2, "none", "one", "a pair", "# things")), "a pair")
})

test_that("1.5.11: a vector or a string is a value error that says to write length()", {
  for (bad in list(c(1, 2), 1:3, "3", c("a", "b"), list(1))) {
    e <- expect_error(plural(bad, "a", "b"), class = "weft_value_error")
    expect_match(conditionMessage(e), "length\\(")
  }
})

test_that("1.5.11, 1.3.4: NA, NaN, Inf and length zero are no-value errors", {
  for (bad in list(NA_real_, NaN, Inf, -Inf, numeric(0), NULL, NA_integer_)) {
    expect_error(plural(bad, "a", "b"), class = "weft_no_value",
                 label = paste(deparse(bad), collapse = ""))
  }
})
