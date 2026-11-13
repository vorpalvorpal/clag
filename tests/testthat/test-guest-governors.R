# Stage 5b: governors given a guest value (G13, 1.11.8 to 1.11.10, 2.12.7).
# When a governor's expression is exactly one guest read, or a claim() whose
# first argument is exactly one guest read, the kind read must suit the key.
# There is no truthiness: [], 0 and "" given to `if` are value errors. An R
# length-zero vector stays "no value" (1.3.4, V4). Documents are knitted in
# draft mode so the markers show; the failures table carries the messages.

PY_GOV <- c(
  "import datetime, decimal",
  "t_g5_true = True",
  "t_g5_false = False",
  "t_g5_empty = []",
  "t_g5_one_true = [True]",
  "t_g5_zero = 0",
  "t_g5_estr = ''",
  "t_g5_fstr = 'False'",
  "t_g5_none = None",
  "t_g5_n3 = 3",
  "t_g5_n1 = 1",
  "t_g5_dec3 = decimal.Decimal('3')",
  "t_g5_f3 = 3.0",
  "t_g5_list1 = [3]",
  "t_g5_date = datetime.date(2026, 1, 2)",
  "t_g5_sites = ['a', 'b']",
  "t_g5_one = ['a']",
  "t_g5_pos = 0.5",
  "t_g5_neg = decimal.Decimal('-0.5')"
)

R_GOV <- c("```{r}", "r_empty <- logical(0)", "```", "")

GOV <- c(
  # if: a bool
  I01 = "[yes | no]{if=\"py$t_g5_true\"} x",
  I02 = "[yes | no]{if=\"py$t_g5_false\"} x",
  I03 = "[yes | no]{if=\"py$t_g5_empty\"} x",
  I04 = "[yes | no]{if=\"py$t_g5_one_true\"} x",
  I05 = "[yes | no]{if=\"py$t_g5_zero\"} x",
  I06 = "[yes | no]{if=\"py$t_g5_estr\"} x",
  I07 = "[yes | no]{if=\"py$t_g5_fstr\"} x",
  I08 = "[yes | no]{if=\"py$t_g5_none\"} x",
  I09 = "[yes | no]{if=\"py$t_g5_true, py$t_g5_true\"} x",
  I10 = "[yes | no]{if=\"py$t_g5_true, py$t_g5_empty\"} x",
  I11 = "[yes | no]{if=\"py$t_g5_zero, py$t_g5_empty\"} x",
  I12 = "[yes | no]{if=\"claim(py$t_g5_empty, length(.) == 0)\"} x",
  I13 = "[yes | no]{if=\"length(py$t_g5_empty) > 0\"} x",
  I14 = "[yes | no]{if=\"r_empty\"} x",
  I15 = "[yes | no]{if=\"py_value('t_g5_true')\"} x",
  I16 = "[yes | no]{if=\"py_value('t_g5_empty')\"} x",
  I17 = "[yes | no]{if=\"py[['t_g5_zero']]\"} x",
  I18 = "[yes | no]{if=\"!py$t_g5_true\"} x",
  I19 = "[yes | no]{if=\"py$t_g5_n3 > 2\"} x",
  # n and sign: a number
  N01 = "[a site | # sites]{n=\"py$t_g5_n3\"} x",
  N02 = "[a site | # sites]{n=\"py$t_g5_n1\"} x",
  N03 = "[a site | # sites]{n=\"py$t_g5_dec3\"} x",
  N04 = "[a site | # sites]{n=\"py$t_g5_f3\"} x",
  N05 = "[a site | # sites]{n=\"py$t_g5_list1\"} x",
  N06 = "[a site | # sites]{n=\"py$t_g5_true\"} x",
  N07 = "[a site | # sites]{n=\"py$t_g5_fstr\"} x",
  N08 = "[a site | # sites]{n=\"py$t_g5_date\"} x",
  N09 = "[a site | # sites]{n=\"claim(py$t_g5_sites, length(.) > 0)\"} x",
  N10 = "[a site | # sites]{n=\"py$t_g5_none\"} x",
  S01 = "[rose | fell | unchanged]{sign=\"py$t_g5_pos\"} x",
  S02 = "[rose | fell | unchanged]{sign=\"py$t_g5_neg\"} x",
  S03 = "[rose | fell | unchanged]{sign=\"py$t_g5_zero\"} x",
  S04 = "[rose | fell | unchanged]{sign=\"py$t_g5_list1\"} x",
  S05 = "[rose | fell | unchanged]{sign=\"py$t_g5_true\"} x",
  S06 = "[rose | fell | unchanged]{sign=\"py$t_g5_fstr\"} x",
  S07 = "[rose | fell | unchanged]{sign=\"py$t_g5_date\"} x",
  S08 = "[rose | fell | unchanged]{sign=\"py$t_g5_none\"} x",
  # list: a list
  L01 = "[No sites were | # was | # were]{list=\"py$t_g5_sites\"} x",
  L02 = "[No sites were | # was | # were]{list=\"py$t_g5_one\"} x",
  L03 = "[No sites were | # was | # were]{list=\"py$t_g5_empty\"} x",
  L04 = "[No sites were | # was | # were]{list=\"py$t_g5_fstr\"} x",
  L05 = "[No sites were | # was | # were]{list=\"py$t_g5_n3\"} x",
  L06 = "[No sites were | # was | # were]{list=\"py$t_g5_none\"} x",
  L07 = "[No sites were | # was | # were]{list=\"py$t_g5_date\"} x"
)

# one knit for the whole file (Python start-up and knitting are slow)
gov <- function() {
  if (is.null(.w5$gov)) .w5$gov <- k5_cases(GOV, before = R_GOV, py = PY_GOV, draft = TRUE)
  .w5$gov
}

# the output line is `<tag> <what> x`, or a marker in place of what
expect_prints <- function(res, tag, what) {
  expect_identical(res$line(tag), paste(tag, what, "x"))
  expect_equal(nrow(res$fail(tag)), 0L, label = paste(tag, "has no failure"))
}

# a collected failure: the marker, the kind and each exact message
expect_collected <- function(res, tag, kind, details) {
  expect_identical(res$line(tag), paste(tag, res$marker(tag, kind), "x"), label = tag)
  f <- res$fail(tag)
  expect_equal(nrow(f), length(details), label = paste(tag, "failures"))
  expect_true(all(f$kind == kind), label = paste(tag, "kind"))
  expect_setequal(vapply(f$detail, msg5, ""), details)
}

test_that("the governor document knits to its end in draft mode", {
  res <- gov()
  expect_false(res$failed, label = res$message)
  expect_false(res$searched)
})

# ---- if ----------------------------------------------------------------------------

test_that("G13 + 1.11.8: a bool given to `if` chooses the arm", {
  res <- gov()
  expect_prints(res, "I01", "yes")
  expect_prints(res, "I02", "no")
  expect_prints(res, "I09", "yes")
  expect_prints(res, "I15", "yes")
})

test_that("G13 + 1.11.8 + M10: [], [True], 0, '' and 'False' given to `if` are value errors, not false", {
  res <- gov()
  expect_collected(res, "I03", "value error", m10("py$t_g5_empty", "list"))
  expect_collected(res, "I04", "value error", m10("py$t_g5_one_true", "list"))
  expect_collected(res, "I05", "value error", m10("py$t_g5_zero", "int"))
  expect_collected(res, "I06", "value error", m10("py$t_g5_estr", "str"))
  expect_collected(res, "I07", "value error", m10("py$t_g5_fstr", "str"))
})

test_that("G13: the read is named as R deparses it, for py_value() and py[[ ]] too", {
  res <- gov()
  expect_collected(res, "I16", "value error", m10("py_value(\"t_g5_empty\")", "list"))
  expect_collected(res, "I17", "value error", m10("py[[\"t_g5_zero\"]]", "int"))
})

test_that("G13: in an `if` with several conditions each is judged on its own", {
  res <- gov()
  expect_collected(res, "I10", "value error", m10("py$t_g5_empty", "list"))
  expect_collected(res, "I11", "value error",
                   c(m10("py$t_g5_zero", "int"), m10("py$t_g5_empty", "list")))
})

test_that("G13: a claim() whose first argument is one guest read is judged by the kind read", {
  res <- gov()
  expect_collected(res, "I12", "value error", m10("py$t_g5_empty", "list"))
})

test_that("G13 + V4: a missing guest value in `if` is \"no value\", not a value error", {
  res <- gov()
  expect_identical(res$line("I08"), paste("I08", res$marker("I08", "no value"), "x"))
  f <- res$fail("I08")
  expect_equal(nrow(f), 1L)
  expect_identical(f$kind, "no value")
})

test_that("G13: any other expression is judged by R's rules on the R form, as today", {
  res <- gov()
  expect_prints(res, "I13", "no")      # length(py$empty) > 0 is FALSE: the false arm
  expect_prints(res, "I19", "yes")     # py$n3 > 2 is TRUE
})

test_that("G13 + 1.3.4: an R length-zero vector stays \"no value\" under `if`", {
  res <- gov()
  expect_identical(res$line("I14"), paste("I14", res$marker("I14", "no value"), "x"))
  expect_identical(res$fail("I14")$kind, "no value")
})

# ---- n and sign -------------------------------------------------------------------------

test_that("G13 + 1.11.9: an integer, a float or a decimal governs `n`", {
  res <- gov()
  expect_prints(res, "N01", "3 sites")
  expect_prints(res, "N02", "a site")
  expect_prints(res, "N03", "3 sites")
  expect_prints(res, "N04", "3 sites")
})

test_that("G13 + M11: a list (even of one number), a bool, a string or a date given to `n` is a value error", {
  res <- gov()
  expect_collected(res, "N05", "value error", m11n("py$t_g5_list1", "list"))
  expect_collected(res, "N06", "value error", m11n("py$t_g5_true", "bool"))
  expect_collected(res, "N07", "value error", m11n("py$t_g5_fstr", "str"))
  expect_collected(res, "N08", "value error", m11n("py$t_g5_date", "datetime.date"))
})

test_that("G13 + M11: n=\"claim(py$sites, length(.) > 0)\" with sites = ['a'] is M11", {
  res <- gov()
  expect_collected(res, "N09", "value error", m11n("py$t_g5_sites", "list"))
})

test_that("G13: a missing guest value in `n` is \"no value\"", {
  res <- gov()
  expect_identical(res$line("N10"), paste("N10", res$marker("N10", "no value"), "x"))
  expect_identical(res$fail("N10")$kind, "no value")
})

test_that("G13 + 1.11.9: an integer, a float or a decimal governs `sign`", {
  res <- gov()
  expect_prints(res, "S01", "rose")
  expect_prints(res, "S02", "fell")
  expect_prints(res, "S03", "unchanged")
})

test_that("G13 + M11: a list, a bool, a string or a date given to `sign` is a value error", {
  res <- gov()
  expect_collected(res, "S04", "value error", m11s("py$t_g5_list1", "list"))
  expect_collected(res, "S05", "value error", m11s("py$t_g5_true", "bool"))
  expect_collected(res, "S06", "value error", m11s("py$t_g5_fstr", "str"))
  expect_collected(res, "S07", "value error", m11s("py$t_g5_date", "datetime.date"))
})

test_that("G13: a missing guest value in `sign` is \"no value\"", {
  res <- gov()
  expect_identical(res$line("S08"), paste("S08", res$marker("S08", "no value"), "x"))
  expect_identical(res$fail("S08")$kind, "no value")
})

# ---- list -------------------------------------------------------------------------------

test_that("G13 + 1.11.10: a list governs a `list` span as 1.5.19 says", {
  res <- gov()
  expect_prints(res, "L01", "a and b were")
  expect_prints(res, "L02", "a was")
  expect_prints(res, "L03", "No sites were")
})

test_that("G13 + M12: a string or a number or a date given to `list` is a value error", {
  res <- gov()
  expect_collected(res, "L04", "value error", m12("py$t_g5_fstr", "str"))
  expect_collected(res, "L05", "value error", m12("py$t_g5_n3", "int"))
  expect_collected(res, "L07", "value error", m12("py$t_g5_date", "datetime.date"))
})

test_that("G13: a missing guest value in `list` is \"no value\"", {
  res <- gov()
  expect_identical(res$line("L06"), paste("L06", res$marker("L06", "no value"), "x"))
  expect_identical(res$fail("L06")$kind, "no value")
})

# ---- the failures, once, in a render that fails -------------------------------------------

test_that("G13 + 2.6.2: a refused governor fails the render once, with the message in the report", {
  res <- k5_cases(GOV[c("I03", "I01")], before = R_GOV, py = PY_GOV)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  expect_equal(nrow(res$failures), 1L)
  expect_true(grepl("a Python list; an `if` condition must be a bool (rule 1.11.8)",
                    res$message, fixed = TRUE))
})
