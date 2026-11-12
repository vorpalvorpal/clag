# 2i In: I1-I9 (dev/design-2i.md): fixes to units and printing that the stage 2 field trial showed to be
# needed. `~` in an expected string is U+00A0 (f2()). Non-ASCII is written as \uXXXX. Made-up values only.
if (!exists("i2_run")) source(Filter(file.exists, c(testthat::test_path("helper-2i.R"), testthat::test_path("..", "helper-2i.R")))[[1]])

# ---- I1: chains of spans (1.5.20) ---------------------------------------------------------------------------

I2_T <- function(txt) sprintf('[%s|]{if="TRUE"}', txt)
I2_F <- function(txt) sprintf('[%s|]{if="FALSE"}', txt)

test_that("2i I1: control - a single span and a chain of two print as before", {
  expect_equal(i2_text(paste0("A: ", I2_T("y"), ".")), "A: y.")
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_T("y"), ".")), "A: y.")
  expect_equal(i2_text(paste0("A: ", I2_T("x"), I2_F("y"), ".")), "A: x.")
  expect_equal(i2_text(paste0("A: ", I2_F("x"), ".")), "A:.")
})

test_that("2i I1: a chain of three keeps the space before it, whichever span prints", {
  expect_equal(i2_text(paste0("A: ", I2_T("x"), I2_F("q"), I2_F("y"), ".")), "A: x.")      # control today
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_T("q"), I2_F("y"), ".")), "A: q.")      # control today
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_F("q"), I2_T("y"), ".")), "A: y.")      # the trial's case
})

test_that("2i I1: the design's example, written as in the ruling", {
  expect_equal(i2_text('A: [x|]{if="FALSE"}[q|]{if="FALSE"}[y|]{if="TRUE"}.'), "A: y.")
})

test_that("2i I1: a chain of four keeps the space before it, whichever span prints", {
  expect_equal(i2_text(paste0("A: ", I2_T("a"), I2_F("b"), I2_F("c"), I2_F("d"), ".")), "A: a.")
  expect_equal(i2_text(paste0("A: ", I2_F("a"), I2_T("b"), I2_F("c"), I2_F("d"), ".")), "A: b.")
  expect_equal(i2_text(paste0("A: ", I2_F("a"), I2_F("b"), I2_T("c"), I2_F("d"), ".")), "A: c.")
  expect_equal(i2_text(paste0("A: ", I2_F("a"), I2_F("b"), I2_F("c"), I2_T("d"), ".")), "A: d.")
})

test_that("2i I1: the space after the chain is kept when any span of it prints", {
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_F("q"), I2_T("y"), " B.")), "A: y B.")
  expect_equal(i2_text(paste0("A: ", I2_F("a"), I2_F("b"), I2_F("c"), I2_T("d"), " B.")), "A: d B.")
  expect_equal(i2_text(paste0("A: ", I2_T("x"), I2_F("q"), I2_F("y"), " B.")), "A: x B.")
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_T("q"), I2_F("y"), " B.")), "A: q B.")
})

test_that("2i I1: a chain at the start of a paragraph", {
  expect_equal(i2_text(paste0(I2_F("x"), I2_T("y"), " B.")), "y B.")                          # control today
  expect_equal(i2_text(paste0(I2_F("x"), I2_F("q"), I2_T("y"), " B.")), "y B.")
  expect_equal(i2_text(paste0(I2_F("a"), I2_F("b"), I2_F("c"), I2_T("d"), " B.")), "d B.")
  expect_equal(i2_text(paste0(I2_T("x"), I2_F("q"), I2_F("y"), " B.")), "x B.")
})

test_that("2i I1: a chain before a full stop, and before a comma", {
  expect_equal(i2_text(paste0("Totals ", I2_F("x"), I2_F("q"), I2_T("y"), ", then more.")), "Totals y, then more.")
  expect_equal(i2_text(paste0("Totals ", I2_F("x"), I2_F("q"), I2_F("z"), I2_T("y"), ".")), "Totals y.")
})

test_that("2i I1: a chain in which nothing prints is treated as one empty span is now", {
  one <- i2_text(paste0("A: ", I2_F("x"), " B."))
  expect_equal(one, "A: B.")                                                                   # control: the single span
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_F("q"), " B.")), one)                        # control today (two)
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_F("q"), I2_F("y"), " B.")), one)
  expect_equal(i2_text(paste0("A: ", I2_F("a"), I2_F("b"), I2_F("c"), I2_F("d"), " B.")), one)
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_F("q"), I2_F("y"), ".")), i2_text(paste0("A: ", I2_F("x"), ".")))
  expect_equal(i2_text(paste0(I2_F("x"), I2_F("q"), I2_F("y"), " B.")), i2_text(paste0(I2_F("x"), " B.")))
})

test_that("2i I1: a chain is only spans with nothing between them; text between them makes two chains", {
  expect_equal(i2_text(paste0("A: ", I2_F("x"), I2_T("y"), " and ", I2_F("p"), I2_F("q"), I2_T("r"), ".")), "A: y and r.")
})

# ---- I2: u() takes a missing logical ------------------------------------------------------------------------

test_that("2i I2: u(NA, mm) is a missing quantity and u(logical(0), mm) an empty one", {
  h2_restore()
  a <- u(NA, mm)
  expect_s3_class(a, "units")
  expect_length(a, 1L)
  expect_true(is.na(a))
  expect_identical(units::deparse_unit(a), "mm")
  b <- u(logical(0), mm)
  expect_s3_class(b, "units")
  expect_length(b, 0L)
  expect_identical(units::deparse_unit(b), "mm")
})

test_that("2i I2: u(c(NA, 1.5), mm) and a missing number are quantities as before (control)", {
  h2_restore()
  x <- u(c(NA, 1.5), mm)
  expect_s3_class(x, "units")
  expect_equal(as.numeric(x), c(NA, 1.5))
  expect_true(is.na(u(NA_real_, mm)))
  expect_length(u(numeric(0), mm), 0L)
})

test_that("2i I2: TRUE and FALSE are still refused, with the logical message", {
  h2_restore()
  for (v in list(TRUE, FALSE, c(TRUE, NA))) {
    e <- f2_cond(u(v, mm))
    expect_false(is.null(e))
    f2_msg_has(e, "logical")
  }
  expect_error(u(c(NA, TRUE), mm), "logical")
})

test_that("2i I2: printing a missing quantity made from NA is the missing-value stop it is for NA_real_", {
  want <- i2_run("`r u(NA_real_, mm)`{.num}")
  got <- i2_run("`r u(NA, mm)`{.num}")
  expect_false(is.null(want$e))
  expect_false(is.null(got$e))
  expect_identical(class(got$e), class(want$e))
  expect_identical(conditionMessage(got$e), conditionMessage(want$e))
  got0 <- i2_run("`r u(logical(0), mm)`{.num}")
  expect_identical(class(got0$e), class(want$e))
})

# ---- I3: a bare quantity (4.4.10, decision 58) -----------------------------------------------------------------

test_that("2i I3: a bare quantity prints as stock prints it and raises exactly one weft_unit_warning naming .num and .nounit", {
  r <- i2_run("`r u(3, mm)`")
  expect_null(r$e)
  expect_equal(r$v, "3")
  expect_length(r$w, 1L)
  ws <- i2_unit_warnings(r)
  expect_length(ws, 1L)
  m <- conditionMessage(ws[[1]])
  expect_match(m, ".num", fixed = TRUE)
  expect_match(m, ".nounit", fixed = TRUE)
})

test_that("2i I3: the warning is raised once per construct, in prose around other text", {
  r <- i2_run("The gauge read `r u(3, mm)` today and `r u(4, mm)` yesterday.")
  expect_equal(r$v, "The gauge read 3 today and 4 yesterday.")
  expect_length(i2_unit_warnings(r), 2L)
})

test_that("2i I3: {.nounit} alone prints the number with weft's formatting, and no warning", {
  r <- i2_run("`r u(3, mm)`{.nounit}")
  expect_equal(r$v, "3")
  expect_length(r$w, 0L)
  r2 <- i2_run("`r u(12345, mm)`{.nounit}")
  expect_length(r2$w, 0L)
  expect_equal(r2$v, "12,345")
})

test_that("2i I3: a bare plain number raises no warning (control)", {
  for (s in c("`r 3`", "`r 0.5`", "`r c(2, 3)`")) {
    r <- i2_run(s)
    expect_length(r$w, 0L)
    expect_null(r$e)
  }
})

test_that("2i I3: a quantity with a class that prints its unit is not bare (control)", {
  r <- i2_run("`r u(3, mm)`{.num}")
  expect_equal(r$v, f2("3~mm"))
  expect_length(r$w, 0L)
})

test_that("2i I3: a bare quantity inside a governed span's n= is not bare (no warning)", {
  r <- i2_run('[# was | # were]{n="u(3, m)"}')
  expect_null(r$e)
  expect_length(r$w, 0L)
  r2 <- i2_run('[# was | # were]{n="u(3, mm)"}')
  expect_length(i2_unit_warnings(r2), 0L)
})

# ---- I4: a unit name typed after the value (decision 59) -----------------------------------------------------------

test_that("2i I4: a value followed by its unit's symbol warns once, naming the word", {
  r <- i2_run("`r u(5, m)`{.num} m")
  expect_equal(r$v, f2("5~m m"))                                                                 # nothing is removed
  ws <- i2_unit_warnings(r)
  expect_length(ws, 1L)
  expect_length(r$w, 1L)
  expect_match(conditionMessage(ws[[1]]), "m m", fixed = TRUE)
})

test_that("2i I4: the singular and the plural name of the unit warn, naming the word", {
  r1 <- i2_run("`r u(1, day)`{.num} day")
  expect_length(i2_unit_warnings(r1), 1L)
  expect_match(conditionMessage(i2_unit_warnings(r1)[[1]]), "day", fixed = TRUE)
  r2 <- i2_run("`r u(3, day)`{.num} days")
  expect_equal(r2$v, f2("3~d days"))
  ws <- i2_unit_warnings(r2)
  expect_length(ws, 1L)
  expect_match(conditionMessage(ws[[1]]), "days", fixed = TRUE)
  r3 <- i2_run("`r u(5, m)`{.num} metres")
  expect_length(i2_unit_warnings(r3), 1L)
  expect_match(conditionMessage(i2_unit_warnings(r3)[[1]]), "metres", fixed = TRUE)
  r4 <- i2_run("`r u(5, m)`{.num} metre")
  expect_length(i2_unit_warnings(r4), 1L)
})

test_that("2i I4: the same under .word, and after any amount of white space", {
  r <- i2_run("`r u(3, day)`{.word} days")
  expect_equal(r$v, f2("three~days days"))
  expect_length(i2_unit_warnings(r), 1L)
  r2 <- i2_run("`r u(5, m)`{.num}  m")
  expect_length(i2_unit_warnings(r2), 1L)
})

test_that("2i I4: a project unit typed by its name after a value warns", {
  yml <- c("units:", "  zzsite:", "    name: site", "    symbol: false")
  r <- i2_run("`r u(3, zzsite)`{.num} sites", yml)
  expect_equal(r$v, f2("3~sites sites"))
  ws <- i2_unit_warnings(r)
  expect_length(ws, 1L)
  expect_match(conditionMessage(ws[[1]]), "sites", fixed = TRUE)
})

test_that("2i I4: an arm that types the unit after # warns, naming the word", {
  r <- i2_run('[# day | # days]{n="u(3, day)"}')
  ws <- i2_unit_warnings(r)
  expect_length(ws, 1L)
  expect_match(conditionMessage(ws[[1]]), "days", fixed = TRUE)
  r1 <- i2_run('[# day | # days]{n="u(1, day)"}')
  expect_length(i2_unit_warnings(r1), 1L)
  expect_match(conditionMessage(i2_unit_warnings(r1)[[1]]), "day", fixed = TRUE)
  yml <- c("units:", "  zzfam:", "    name: family", "    plural: families", "    symbol: false")
  r2 <- i2_run('[# family | # families]{n="u(3, zzfam)"}', yml)
  ws2 <- i2_unit_warnings(r2)
  expect_length(ws2, 1L)
  expect_match(conditionMessage(ws2[[1]]), "families", fixed = TRUE)
})

test_that("2i I4: no warning when the following word only starts with the unit's letters", {
  r <- i2_run("`r u(5, m)`{.num} more")
  expect_equal(r$v, f2("5~m more"))
  expect_length(r$w, 0L)
  r2 <- i2_run("`r u(3, day)`{.num} daily")
  expect_equal(r2$v, f2("3~d daily"))
  expect_length(r2$w, 0L)
  r3 <- i2_run("`r u(3, day)`{.num} dayside")
  expect_length(r3$w, 0L)
  r4 <- i2_run("`r u(5, m)`{.num}, m is a symbol")                                               # a comma is between them
  expect_length(r4$w, 0L)
})

test_that("2i I4: no warning for a plain number, or under .nounit, or for another word after the unit", {
  expect_length(i2_run("`r 5`{.num} m")$w, 0L)
  expect_length(i2_run("`r 3`{.num} days")$w, 0L)
  r <- i2_run("`r u(5, m)`{.nounit} m")
  expect_equal(r$v, f2("5 m"))
  expect_length(r$w, 0L)
  expect_length(i2_run("`r u(3, day)`{.nounit} days")$w, 0L)
  expect_length(i2_run("`r u(5, m)`{.num} long")$w, 0L)
})

test_that("2i I4: control - the arm of an ordinary governed span raises no warning", {
  r <- i2_run('[# was | # were]{n="u(3, m)"}')
  expect_length(r$w, 0L)
})

# ---- I5: a project unit with a name and no symbol ------------------------------------------------------------------

test_that("2i I5: a row with a name and no symbol prints by name, with the right plural after digits", {
  expect_equal(i2_text("`r u(3, zzsite)`{.num}", I2_SITE), f2("3~sites"))
  expect_equal(i2_text("`r u(1, zzsite)`{.num}", I2_SITE), f2("1~site"))
  expect_equal(i2_text("`r u(0, zzsite)`{.num}", I2_SITE), f2("0~sites"))
  expect_equal(i2_text("`r u(2.5, zzsite)`{.num}", I2_SITE), f2("2.5~sites"))
})

test_that("2i I5: the same under .word, and .uname", {
  expect_equal(i2_text("`r u(3, zzsite)`{.word}", I2_SITE), f2("three~sites"))
  expect_equal(i2_text("`r u(1, zzsite)`{.word}", I2_SITE), f2("one~site"))
  expect_equal(i2_text("`r u(3, zzsite)`{.uname}", I2_SITE), f2("3~sites"))
})

test_that("2i I5: an explicit plural is used", {
  yml <- c("units:", "  zzfam:", "    name: family", "    plural: families")
  expect_equal(i2_text("`r u(2, zzfam)`{.num}", yml), f2("2~families"))
  expect_equal(i2_text("`r u(1, zzfam)`{.num}", yml), f2("1~family"))
  expect_equal(i2_text("`r u(2, zzfam)`{.word}", yml), f2("two~families"))
})

test_that("2i I5: a name over digits agrees with a span's arm, as with symbol: false (control)", {
  yml <- c("units:", "  zzsite:", "    name: site", "    symbol: false")
  expect_equal(i2_text("`r u(3, zzsite)`{.num}", yml), f2("3~sites"))
  expect_equal(i2_text("`r u(1, zzsite)`{.num}", yml), f2("1~site"))
})

test_that("2i I5: a row with a symbol prints the symbol after digits (control)", {
  yml <- c("units:", "  zzquark:", "    name: quark", "    symbol: zq")
  expect_equal(i2_text("`r u(3, zzquark)`{.num}", yml), f2("3~zq"))
  expect_equal(i2_text("`r u(3, zzquark)`{.uname}", yml), f2("3~quarks"))
})

test_that("2i I5: a row with neither a name nor a symbol prints its key (control)", {
  yml <- c("units:", "  zzbare:", "    is: 1 m")
  expect_equal(i2_text("`r u(3, zzbare)`{.num}", yml), f2("3~zzbare"))
})

# ---- I6: grade is read as an angle ------------------------------------------------------------------------------------

test_that("2i I6: u(3, grade) is a unit error naming grade, with advice that names a project unit", {
  h2_restore()
  e <- f2_cond(u(3, grade))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "grade")
  expect_match(f2_msg(e), "units:|project unit|_weft.yml")
})

test_that("2i I6: a compound with grade is refused the same way, and the string form too", {
  h2_restore()
  expect_true(inherits(f2_cond(u(5, "grade/h")), "weft_unit_error"))
  expect_true(inherits(f2_cond(u(5, "grade")), "weft_unit_error"))
})

test_that("2i I6: through weft_str() it is an error, not a printed 'grades'", {
  r <- i2_run("`r u(3, grade)`{.num}")
  expect_false(is.null(r$e))
  expect_false(grepl("grades", if (is.na(r$v)) "" else r$v, fixed = TRUE))
})

test_that("2i I6: control - a project unit under another key is fine", {
  h2_restore()
  expect_equal(i2_text("`r u(3, zzscore)`{.num}", c("units:", "  zzscore:", "    name: grade", "    symbol: false")),
               f2("3~grades"))
})

# ---- I7: a token is kept as typed inside a compound (4.4.20) ---------------------------------------------------

test_that("2i I7: u(2, \"mm/hr\") prints mm/hr, and u(2, \"mm/h\") prints mm/h", {
  expect_equal(i2_text('`r u(2, "mm/hr")`{.num}'), f2("2~mm/hr"))
  expect_equal(i2_text('`r u(2, "mm/h")`{.num}'), f2("2~mm/h"))
  expect_equal(i2_text('`r u(2, "mm/hr")`{.num digits="1"}'), f2("2.0~mm/hr"))
})

test_that("2i I7: other non-canonical tokens inside a compound are kept as typed", {
  expect_equal(i2_text('`r u(2, "km/hr")`{.num}'), f2("2~km/hr"))
  expect_equal(i2_text('`r u(2, "mm/day")`{.num}'), f2("2~mm/day"))
  expect_equal(i2_text('`r u(2, "ha/yr")`{.num}'), f2("2~ha/yr"))
})

test_that("2i I7: the token kept as typed is still the same unit (a conversion works)", {
  h2_restore()
  x <- u(3600, "mm/hr")
  expect_equal(as.numeric(units::set_units(x, "mm/h", mode = "standard")), 3600)
  expect_equal(i2_text('`r u(2, "mm/hr")`{.num}'), f2("2~mm/hr"))
})

test_that("2i I7: control - a token that is canonical, and one typed as written, print as before", {
  expect_equal(i2_text('`r u(2, "mg/L")`{.num}'), f2("2~mg/L"))
  expect_equal(i2_text('`r u(2, "m/sec")`{.num}'), f2("2~m/sec"))
  expect_equal(i2_text("`r u(2, mm)`{.num}"), f2("2~mm"))
})

# ---- I8: .pct on a quantity in per cent -----------------------------------------------------------------------------------

test_that("2i I8: .pct on a quantity in percent is a value error that says to drop .pct", {
  r <- i2_run("`r u(0.25, percent)`{.pct}")
  f2_has_class(r$e, "weft_value_error")
  m <- conditionMessage(r$e)
  expect_match(m, "drop `.pct`", fixed = TRUE)
  expect_false(grepl("give it a number with no unit", m, fixed = TRUE))
})

test_that("2i I8: the message still says the unit already prints %, and the quantity without .pct prints it", {
  r <- i2_run("`r u(0.25, percent)`{.pct}")
  expect_match(conditionMessage(r$e), "%", fixed = TRUE)
  expect_equal(i2_text("`r u(25, percent)`{.num}"), f2("25%"))
})

test_that("2i I8: control - .pct on a plain number prints the per cent", {
  expect_equal(i2_text("`r 0.3`{.pct}"), "30%")
})

# ---- I9: zero on a ladder (4.4.13) ---------------------------------------------------------------------------------------

test_that("2i I9: a lone zero takes the rung of the unit it is held in, when that rung is on the ladder", {
  expect_equal(i2_text(i2_cx("u(0, t)", 'unit="kg|t"')), f2("0~t"))
  expect_equal(i2_text(i2_cx("u(0, t)", 'unit="t|kg"')), f2("0~t"))                             # control today
  expect_equal(i2_text(i2_cx("u(0, kg)", 'unit="t|kg"')), f2("0~kg"))
  expect_equal(i2_text(i2_cx("u(0, kg)", 'unit="kg|t"')), f2("0~kg"))                           # control today
})

test_that("2i I9: the same in the other forms, and with three rungs", {
  expect_equal(i2_text(i2_cx("u(0, t)", '.uname unit="kg|t"')), f2("0~tonnes"))
  expect_equal(i2_text(i2_cx("u(0, t)", '.no unit="kg|t"')), f2("no~tonnes"))
  expect_equal(i2_text(i2_cx("u(0, m)", 'unit="mm|m|km"')), f2("0~m"))
  expect_equal(i2_text(i2_cx("u(0, m)", 'unit="km|m|mm"')), f2("0~m"))
  expect_equal(i2_text(i2_cx("u(0, m)", '.word unit="km|m"')), f2("zero~metres"))
})

test_that("2i I9: a held unit that is not on the ladder takes the first rung (control)", {
  expect_equal(i2_text(i2_cx("u(0, mg)", 'unit="kg|t"')), f2("0~kg"))
  expect_equal(i2_text(i2_cx("u(0, mg)", 'unit="t|kg"')), f2("0~t"))
  expect_equal(i2_text(i2_cx("u(0, cm)", 'unit="mm|m"')), f2("0~mm"))
})

test_that("2i I9: a lone zero warns nothing (an exact zero is not the zero rule), as before", {
  r <- i2_run(i2_cx("u(0, t)", 'unit="kg|t"'))
  expect_length(r$w, 0L)
})

test_that("2i I9: a vector with a zero follows the vector rule, as today: the held unit does not decide", {
  for (lad in c("kg|t", "t|kg")) {
    in_kg <- i2_text(i2_cx("u(c(0, 2500), kg)", sprintf('.and unit="%s"', lad)))
    in_t <- i2_text(i2_cx("u(c(0, 2.5), t)", sprintf('.and unit="%s"', lad)))
    expect_equal(in_kg, in_t, label = lad)
    expect_false(grepl("ERROR", in_kg, fixed = TRUE), label = in_kg)
  }
  expect_equal(i2_text(i2_cx("u(c(0, 0), m)", '.and unit="mm|m"')), f2("0 and 0~mm"))          # an all-zero vector: the first rung
})
