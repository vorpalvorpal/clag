# Stage 5J-a: governors given a Julia value (J11, 1.11.8 to 1.11.10, 2.12.17).
# When a governor's expression is exactly one jl_value() read, or a claim()
# whose first argument is exactly one jl_value() read, the kind read must suit
# the key. There is no truthiness: Int[], 0 and "" given to `if` are value
# errors. An R length-zero vector stays "no value" (1.3.4). In an attribute
# value the argument takes single quotes. Documents are knitted in draft mode
# so the markers show; the failures table carries the messages. A missing
# value is `nothing` here (a scalar `missing` is read only in a child process,
# test-julia-types.R and test-julia-prose.R). Names are t_j5g_...

gset <- function() {
  jl_set(
    t_j5g_true = "true", t_j5g_false = "false", t_j5g_empty = "Int[]",
    t_j5g_one_true = "[true]", t_j5g_zero = "0", t_j5g_estr = "\"\"",
    t_j5g_fstr = "\"false\"", t_j5g_none = "nothing", t_j5g_nan = "NaN",
    t_j5g_n3 = "3", t_j5g_n1 = "1", t_j5g_f3 = "3.0", t_j5g_big = "2^40",
    t_j5g_list1 = "[3]", t_j5g_date = "Dates.Date(2026, 1, 2)",
    t_j5g_sites = "[\"a\", \"b\"]", t_j5g_one = "[\"a\"]",
    t_j5g_pos = "0.5", t_j5g_neg = "-0.5", t_j5g_nesites = "String[]")
}

R_GOV_J <- c("```{r}", "r_empty <- logical(0)", "```", "")

GOV_J <- c(
  # if: a Bool
  I01 = "[yes | no]{if=\"jl_value('t_j5g_true')\"} x",
  I02 = "[yes | no]{if=\"jl_value('t_j5g_false')\"} x",
  I03 = "[yes | no]{if=\"jl_value('t_j5g_empty')\"} x",
  I04 = "[yes | no]{if=\"jl_value('t_j5g_one_true')\"} x",
  I05 = "[yes | no]{if=\"jl_value('t_j5g_zero')\"} x",
  I06 = "[yes | no]{if=\"jl_value('t_j5g_estr')\"} x",
  I07 = "[yes | no]{if=\"jl_value('t_j5g_fstr')\"} x",
  I08 = "[yes | no]{if=\"jl_value('t_j5g_none')\"} x",
  I09 = "[yes | no]{if=\"jl_value('t_j5g_true'), jl_value('t_j5g_true')\"} x",
  I10 = "[yes | no]{if=\"jl_value('t_j5g_true'), jl_value('t_j5g_empty')\"} x",
  I11 = "[yes | no]{if=\"jl_value('t_j5g_zero'), jl_value('t_j5g_empty')\"} x",
  I12 = "[yes | no]{if=\"claim(jl_value('t_j5g_empty'), length(.) == 0)\"} x",
  I13 = "[yes | no]{if=\"length(jl_value('t_j5g_empty')) > 0\"} x",
  I14 = "[yes | no]{if=\"r_empty\"} x",
  I15 = "[yes | no]{if=\"weft::jl_value('t_j5g_true')\"} x",
  I16 = "[yes | no]{if=\"!jl_value('t_j5g_true')\"} x",
  I17 = "[yes | no]{if=\"jl_value('t_j5g_n3') > 2\"} x",
  I18 = "[yes | no]{if=\"jl_value('t_j5g_nan')\"} x",
  I19 = "[yes | no]{if=\"JuliaCall::julia_eval('t_j5g_zero')\"} x",
  # n and sign: a number
  N01 = "[a site | # sites]{n=\"jl_value('t_j5g_n3')\"} x",
  N02 = "[a site | # sites]{n=\"jl_value('t_j5g_n1')\"} x",
  N03 = "[a site | # sites]{n=\"jl_value('t_j5g_f3')\"} x",
  N05 = "[a site | # sites]{n=\"jl_value('t_j5g_list1')\"} x",
  N06 = "[a site | # sites]{n=\"jl_value('t_j5g_true')\"} x",
  N07 = "[a site | # sites]{n=\"jl_value('t_j5g_fstr')\"} x",
  N08 = "[a site | # sites]{n=\"jl_value('t_j5g_date')\"} x",
  N09 = "[a site | # sites]{n=\"claim(jl_value('t_j5g_sites'), length(.) > 0)\"} x",
  N10 = "[a site | # sites]{n=\"jl_value('t_j5g_none')\"} x",
  S01 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_pos')\"} x",
  S02 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_neg')\"} x",
  S03 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_zero')\"} x",
  S04 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_list1')\"} x",
  S05 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_true')\"} x",
  S06 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_fstr')\"} x",
  S07 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_date')\"} x",
  S08 = "[rose | fell | unchanged]{sign=\"jl_value('t_j5g_none')\"} x",
  # list: a list
  L01 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_sites')\"} x",
  L02 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_one')\"} x",
  L03 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_nesites')\"} x",
  L04 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_fstr')\"} x",
  L05 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_n3')\"} x",
  L06 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_none')\"} x",
  L07 = "[No sites were | # was | # were]{list=\"jl_value('t_j5g_date')\"} x"
)

# one knit for the whole file (Julia start-up and knitting are slow)
gov_j <- function() {
  if (is.null(.w5j$gov)) {
    gset()
    .w5j$gov <- k5j_cases(GOV_J, before = R_GOV_J, draft = TRUE)
  }
  .w5j$gov
}

test_that("the governor document knits to its end in draft mode, with no JuliaCall attached", {
  res <- gov_j()
  expect_false(res$failed, label = res$message)
  expect_false(res$searched)
})

# ---- if ----------------------------------------------------------------------------

test_that("J11 + 1.11.8: a Bool given to `if` chooses the arm, the argument in single quotes", {
  res <- gov_j()
  expect_prints_j(res, "I01", "yes")
  expect_prints_j(res, "I02", "no")
  expect_prints_j(res, "I09", "yes")
  expect_prints_j(res, "I15", "yes")
})

test_that("J11 + JM10: Int[], [true], 0, \"\" and \"false\" given to `if` are value errors, not false", {
  res <- gov_j()
  expect_collected_j(res, "I03", "value error", jm10("jl_value(\"t_j5g_empty\")", "Vector{Int64}"))
  expect_collected_j(res, "I04", "value error", jm10("jl_value(\"t_j5g_one_true\")", "Vector{Bool}"))
  expect_collected_j(res, "I05", "value error", jm10("jl_value(\"t_j5g_zero\")", "Int64"))
  expect_collected_j(res, "I06", "value error", jm10("jl_value(\"t_j5g_estr\")", "String"))
  expect_collected_j(res, "I07", "value error", jm10("jl_value(\"t_j5g_fstr\")", "String"))
})

test_that("J11: the read is named as R deparses it, with weft:: when it was written so", {
  res <- gov_j()
  expect_prints_j(res, "I15", "yes")
  jl_set(t_j5g_zz = "0")
  res2 <- k5j_cases(c(I20 = "[yes | no]{if=\"weft::jl_value('t_j5g_zz')\"} x"), draft = TRUE)
  expect_collected_j(res2, "I20", "value error", jm10("weft::jl_value(\"t_j5g_zz\")", "Int64"))
})

test_that("J11: in an `if` with several conditions each is judged on its own", {
  res <- gov_j()
  expect_collected_j(res, "I10", "value error", jm10("jl_value(\"t_j5g_empty\")", "Vector{Int64}"))
  expect_collected_j(res, "I11", "value error",
                     c(jm10("jl_value(\"t_j5g_zero\")", "Int64"), jm10("jl_value(\"t_j5g_empty\")", "Vector{Int64}")))
})

test_that("J11: a claim() whose first argument is one Julia read is judged by the kind read", {
  res <- gov_j()
  expect_collected_j(res, "I12", "value error", jm10("jl_value(\"t_j5g_empty\")", "Vector{Int64}"))
})

test_that("J11 + 1.3.4: a missing Julia value in `if` is \"no value\", not a value error", {
  res <- gov_j()
  for (tag in c("I08", "I18")) expect_no_value_j(res, tag)
})

test_that("J11: any other expression is judged by R's rules on the R form, as today", {
  res <- gov_j()
  expect_prints_j(res, "I13", "no")      # length(Int[]) > 0 is FALSE: the false arm
  expect_prints_j(res, "I16", "no")      # !TRUE
  expect_prints_j(res, "I17", "yes")     # 3 > 2
})

test_that("J11 + 1.3.4: an R length-zero vector stays \"no value\" under `if`", {
  res <- gov_j()
  expect_identical(res$line("I14"), paste("I14", res$marker("I14", "no value"), "x"))
  expect_identical(res$fail("I14")$kind, "no value")
})

test_that("J11: a governor that reads through JuliaCall keeps today's message, with no JM10", {
  res <- gov_j()
  expect_true(grepl("^I19 <<weft: ", res$line("I19")))
  f <- res$fail("I19")
  expect_gte(nrow(f), 1L)
  txt <- vapply(f$detail, msg5, "")
  expect_true(any(grepl("must be a single TRUE or FALSE", txt, fixed = TRUE)))
  expect_false(any(grepl("an `if` condition must be a Bool", txt, fixed = TRUE)))
})

# ---- n and sign -------------------------------------------------------------------------

test_that("J11 + 1.11.9: an integer or a float governs `n`", {
  res <- gov_j()
  expect_prints_j(res, "N01", "3 sites")
  expect_prints_j(res, "N02", "a site")
  expect_prints_j(res, "N03", "3 sites")
})

test_that("J11 + JM11: a list (even of one number), a Bool, a string or a date given to `n` is a value error", {
  res <- gov_j()
  expect_collected_j(res, "N05", "value error", jm11n("jl_value(\"t_j5g_list1\")", "Vector{Int64}"))
  expect_collected_j(res, "N06", "value error", jm11n("jl_value(\"t_j5g_true\")", "Bool"))
  expect_collected_j(res, "N07", "value error", jm11n("jl_value(\"t_j5g_fstr\")", "String"))
  expect_collected_j(res, "N08", "value error", jm11n("jl_value(\"t_j5g_date\")", "Date"))
})

test_that("J11 + JM11: n=\"claim(jl_value('sites'), length(.) > 0)\" with sites = [\"a\"] is JM11", {
  res <- gov_j()
  expect_collected_j(res, "N09", "value error", jm11n("jl_value(\"t_j5g_sites\")", "Vector{String}"))
})

test_that("J11: a missing Julia value in `n` is \"no value\"", {
  res <- gov_j()
  expect_no_value_j(res, "N10")
})

test_that("J11 + 1.11.9: an integer or a float governs `sign`", {
  res <- gov_j()
  expect_prints_j(res, "S01", "rose")
  expect_prints_j(res, "S02", "fell")
  expect_prints_j(res, "S03", "unchanged")
})

test_that("J11 + JM11: a list, a Bool, a string or a date given to `sign` is a value error", {
  res <- gov_j()
  expect_collected_j(res, "S04", "value error", jm11s("jl_value(\"t_j5g_list1\")", "Vector{Int64}"))
  expect_collected_j(res, "S05", "value error", jm11s("jl_value(\"t_j5g_true\")", "Bool"))
  expect_collected_j(res, "S06", "value error", jm11s("jl_value(\"t_j5g_fstr\")", "String"))
  expect_collected_j(res, "S07", "value error", jm11s("jl_value(\"t_j5g_date\")", "Date"))
})

test_that("J11: a missing Julia value in `sign` is \"no value\"", {
  res <- gov_j()
  expect_no_value_j(res, "S08")
})

# ---- list -------------------------------------------------------------------------------

test_that("J11 + 1.11.10: a list governs a `list` span as 1.5.19 says", {
  res <- gov_j()
  expect_prints_j(res, "L01", "a and b were")
  expect_prints_j(res, "L02", "a was")
  expect_prints_j(res, "L03", "No sites were")
})

test_that("J11 + JM12: a string, a number or a date given to `list` is a value error", {
  res <- gov_j()
  expect_collected_j(res, "L04", "value error", jm12("jl_value(\"t_j5g_fstr\")", "String"))
  expect_collected_j(res, "L05", "value error", jm12("jl_value(\"t_j5g_n3\")", "Int64"))
  expect_collected_j(res, "L07", "value error", jm12("jl_value(\"t_j5g_date\")", "Date"))
})

test_that("J11: a missing Julia value in `list` is \"no value\"", {
  res <- gov_j()
  expect_no_value_j(res, "L06")
})

# ---- the failures, once, in a render that fails -------------------------------------------

test_that("J11 + 2.6.2: a refused governor fails the render once, with the message in the report", {
  gset()
  res <- k5j_cases(GOV_J[c("I03", "I01")], before = R_GOV_J)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  expect_equal(nrow(res$failures), 1L)
  expect_true(grepl("a Julia Vector{Int64}; an `if` condition must be a Bool (rule 1.11.8)",
                    res$message, fixed = TRUE))
})
