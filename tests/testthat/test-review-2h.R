# Regression tests for the review of package 2h (dev/review-2h.md), decided by the "Rulings on the
# review of 2h" at the end of dev/design-2h.md (the rulings win over the contract above them and over
# the review). One or more tests per finding 1-13 and per ruling a, b, e, f, g, i; c, d and h are kept
# as built (one small test each pins the stated behaviour); j is wording in the spec, no test.
# The `units` database is session-global: every test installs nothing, or only made-up tokens that are
# its own, and the default state comes back when it ends (h2_restore()).
# `~` in an expected string is U+00A0 (f2()). Non-ASCII is written as \uXXXX. Made-up content only.
if (!exists("h2_row")) source(Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))[[1]])
h2_need()

r2h_cx <- function(value, attrs) paste0("`r ", value, "`{", attrs, "}")

# the line of a dictionary error's message that names the key `key`
r2h_line <- function(e, key) {
  grep(sprintf("`%s`", key), strsplit(f2_msg(e), "\n", fixed = TRUE)[[1]], fixed = TRUE, value = TRUE)
}

# the weft_dict_error read_dict() raises for one entry line
r2h_dict_err <- function(line, env = parent.frame()) {
  e <- f2_cond(read_dict(f2_dict_file(line, env)))
  f2_has_class(e, "weft_dict_error")
  e
}

# ---- 1 and g: .nounit / unit_form = "none" with a ladder is a value error ----------------------------------------------------

test_that("review 2h #1: .nounit with a ladder of more than one rung is a value error, not a bare number (ruling g)", {
  h2_restore()
  for (v in c("u(1500, m)", "u(400, m)")) {
    e <- f2_err(r2h_cx(v, '.nounit unit="m|km"'))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, "unit")
  }
})

test_that("review 2h #1: unit_form = \"none\" with a ladder is a value error, for a number and for a vector (ruling g)", {
  h2_restore()
  for (x in list(u(400, m), u(1500, m), u(c(1000, 1500), m))) {
    e <- f2_cond(fmt_num(x, unit = "m|km", unit_form = "none"))
    f2_has_class(e, "weft_value_error")
    e2 <- f2_cond(fmt_num(x, unit = c("m", "km"), unit_form = "none"))
    f2_has_class(e2, "weft_value_error")
  }
})

test_that("review 2h #1: control - none with one unit, and a ladder with a unit shown, still print (ruling g)", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(1500, m)", '.nounit unit="km"')), "1.5")
  expect_equal(h2_ws(r2h_cx("u(1500, m)", '.nounit unit="m|km "')), "1.5")        # a ladder of one, trimmed
  expect_equal(f2_tx(fmt_num(u(400, m), unit = "m", unit_form = "none")), "400")
  expect_equal(f2_tx(fmt_num(u(400, m), unit = c("m"), unit_form = "none")), "400")
  expect_equal(h2_ws(r2h_cx("u(1500, m)", '.usym unit="m|km"')), f2("1.5~km"))
  expect_equal(f2_tx(fmt_num(u(400, m), unit = "m|km", unit_form = "symbol")), f2("400~m"))
})

# ---- 2 and a: the display: ladder (a read_dict() problem); finding 2's sums and drop_units() ---------------------------------

test_that("review 2h #2: a display ladder is a problem, so a one-character edit cannot move the held unit (ruling a)", {
  h2_restore()
  for (v in c(800, 8000)) {
    e <- r2h_dict_err(sprintf("pipe: {value: %s, type: quantity, unit: m, display: \"m|km\", definition: x}", v))
    f2_msg_has(e, "`pipe`", "display", "`unit` key")
  }
})

test_that("review 2h #2: the sum of two entries has one unit whatever the operand order, with a single display (control, ruling a)", {
  h2_restore()
  d <- read_dict(f2_dict_file(c(
    "long: {value: 2000, type: quantity, unit: m, display: km, definition: x}",
    "short: {value: 900, type: quantity, unit: m, display: km, definition: x}")))
  expect_equal(units::deparse_unit(d$long + d$short), units::deparse_unit(d$short + d$long))
  expect_equal(as.numeric(units::drop_units(d$long + d$short)), as.numeric(units::drop_units(d$short + d$long)))
  expect_equal(as.numeric(units::drop_units(d$short)), 0.9)
})

# ---- 3 and e: an offset unit on a ladder --------------------------------------------------------------------------------------

test_that("review 2h #3: a ladder with an offset rung is a value error naming the rung (ruling e)", {
  h2_restore()
  for (case in list(list("u(0.5, degC)", "degC|K", "K"), list("u(300, K)", "K|degC", "degC"),
                    list("u(30, degF)", "degF|degC", "degC"), list("u(20, degC)", "degC|degF", "degF"))) {
    e <- f2_err(r2h_cx(case[[1]], sprintf('unit="%s"', case[[2]])))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, paste0("unit = ", case[[2]]), "rung")
    expect_true(grepl(sprintf("rung `%s`", case[[3]]), f2_msg(e), fixed = TRUE), label = f2_msg(e))
  }
})

test_that("review 2h #3: the same from the function, with a vector of rungs and a frost value (ruling e)", {
  h2_restore()
  for (v in c(0.5, 0, -0.5, 20)) {
    e <- f2_cond(fmt_num(u(v, degC), unit = "degC|K"))
    f2_has_class(e, "weft_value_error")
  }
  f2_has_class(f2_cond(fmt_num(u(0.5, degC), unit = c("degC", "K"))), "weft_value_error")
})

test_that("review 2h #3: control - one offset unit is a conversion as before, and a ratio ladder is unaffected (ruling e)", {
  h2_restore()
  expect_equal(f2_tx(fmt_num(u(0.5, degC), unit = "K")), f2("273.7~K"))
  expect_equal(f2_tx(fmt_num(u(0.5, degC), unit = "degC")), f2("0.5~°C"))
  expect_equal(h2_ws(r2h_cx("u(1500, m)", 'unit="m|km"')), f2("1.5~km"))
})

test_that("review 2h #3: a display ladder with an offset unit is a read_dict() problem, not an entry held in kelvin (ruling a)", {
  h2_restore()
  e <- r2h_dict_err("d: {value: 0.5, type: quantity, unit: degC, display: \"degC|K\", definition: x}")
  f2_msg_has(e, "`d`", "display", "`unit` key")
})

# ---- 4 and f: a class that spells the number, with a ladder ----------------------------------------------------------------

test_that("review 2h #4: .word with a ladder picks only a rung where the number prints whole, so it does not come and go (ruling f)", {
  h2_restore()
  for (v in c("u(1200, m)", "u(1500, m)", "u(2500, m)")) {
    expect_equal(h2_ws(r2h_cx(v, '.word unit="m|km"')), h2_ws(r2h_cx(v, '.word unit="m"')), label = v)
  }
})

test_that("review 2h #4: .count, a vector and a span with a ladder do the same (ruling f)", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(c(1000, 1500), m)", '.and .count unit="m|km"')),
               h2_ws(r2h_cx("u(c(1000, 1500), m)", '.and .count unit="m"')))
  expect_equal(h2_ws(r2h_cx("u(1500, m)", '.count unit="m|km"')), h2_ws(r2h_cx("u(1500, m)", '.count unit="m"')))
  expect_equal(h2_ws('[# was | # were]{n="u(1500, m)" .word unit="m|km"}'), h2_ws('[# was | # were]{n="u(1500, m)" .word unit="m"}'))
})

test_that("review 2h #4: control - a whole number in the first rung that fits still spells in that rung (ruling f)", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(2000, m)", '.word unit="m|km"')), f2("two~kilometres"))
  expect_equal(h2_ws(r2h_cx("u(1000, m)", '.word unit="m|km"')), f2("one~kilometre"))
  expect_equal(h2_ws(r2h_cx("u(999, m)", '.word unit="m|km"')), f2("999~m"))
  expect_equal(h2_ws(r2h_cx("u(c(2000, 3000), m)", '.and .count unit="m|km"')), h2_ws(r2h_cx("u(c(2, 3), km)", '.and .count unit="km"')))
})

test_that("review 2h #4: when no rung prints the number whole the error is 1.4.12's, as without a ladder (ruling f, control)", {
  h2_restore()
  e1 <- f2_err(r2h_cx("u(1.5, m)", '.word unit="m"'))
  e2 <- f2_err(r2h_cx("u(1.5, m)", '.word unit="m|km"'))
  f2_has_class(e1, "weft_value_error")
  f2_has_class(e2, "weft_value_error")
  f2_msg_has(e2, "(rule 1.4.12)")
})

# ---- 5 and b: the vector rule ----------------------------------------------------------------------------------------------------

test_that("review 2h #5: a rung that prints a non-zero element as zero is passed over when another prints none as zero (ruling b)", {
  h2_restore()
  r <- h2_warns(h2_ws(r2h_cx("u(c(0.3, 0.4, 2000, 3000), m)", '.and unit="m|km"')))
  expect_equal(r$v, f2("0.3, 0.4, 2,000 and 3,000~m"))
  expect_length(r$w, 0L)
  r2 <- h2_warns(h2_ws(r2h_cx("u(c(0.3, 0.4, 2000, 3000), m)", '.and unit="km|m"')))
  expect_equal(r2$v, f2("0.3, 0.4, 2,000 and 3,000~m"))
  expect_length(r2$w, 0L)
  expect_equal(h2_ws(r2h_cx("u(c(0.3, 0.4, 2000, 3000), m)", '.and unit="m"')), f2("0.3, 0.4, 2,000 and 3,000~m"))   # control
})

test_that("review 2h #5: one added element does not flip the whole vector to a rung that zeroes five (ruling b)", {
  h2_restore()
  ten <- "u(c(5, 6, 7, 8, 9, 25000, 30000, 40000, 50000, 60000), m)"
  eleven <- "u(c(5, 6, 7, 8, 9, 25000, 30000, 40000, 50000, 60000, 70000), m)"
  r10 <- h2_warns(h2_ws(r2h_cx(ten, '.and unit="m|km"')))
  expect_equal(r10$v, f2("5, 6, 7, 8, 9, 25,000, 30,000, 40,000, 50,000 and 60,000~m"))          # control: passes before
  r11 <- h2_warns(h2_ws(r2h_cx(eleven, '.and unit="m|km"')))
  expect_equal(r11$v, f2("5, 6, 7, 8, 9, 25,000, 30,000, 40,000, 50,000, 60,000 and 70,000~m"))
  expect_length(r11$w, 0L)
})

test_that("review 2h #5: a descending ladder does not tie to the rung that zeroes elements (ruling b)", {
  h2_restore()
  r <- h2_warns(h2_ws(r2h_cx("u(c(0.0002, 0.003, 5), mg/L)", '.and unit="mg/L|ug/L|ng/L"')))
  expect_equal(r$v, f2("0.2, 3 and 5,000~ug/L"))
  expect_length(r$w, 0L)
  expect_equal(h2_ws(r2h_cx("u(c(0.0002, 0.003, 5), mg/L)", '.and unit="ug/L"')), f2("0.2, 3 and 5,000~ug/L"))   # control
})

test_that("review 2h #5: control - where every rung zeroes an element the pick and the warned check are as built (ruling b)", {
  h2_restore()
  r <- h2_warns(h2_ws(r2h_cx("u(c(0.0001, 500), m)", '.and unit="m|km"')))
  expect_equal(r$v, f2("0.0 and 500~m"))
  expect_length(r$w, 1L)
})

test_that("review 2h #5: a value may print in one unit alone and another in a vector, and trunc's hidden elements take part (ruling b, stated)", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(400, m)", 'unit="m|km"')), f2("400~m"))
  expect_equal(h2_ws(r2h_cx("u(c(400, 2500, 3000), m)", '.and unit="m|km"')), f2("0.4, 2.5 and 3~km"))
  expect_equal(h2_ws(r2h_cx("u(c(1500, 300, 400, 500), m)", '.and trunc="1" unit="m|km"')), f2("1,500~m and 3 others"))
})

# ---- 6 and i (re-ruled, decision 54): with no fit, a rung at 1,000 or more beats one below 1 ----------------------------------

test_that("review 2h #6: under mm|km every length from 1 m up to the one that prints 1.0 km prints in mm (ruling i)", {
  h2_restore()
  for (v in c(5, 40, 46, 50, 60, 140, 149, 151, 500, 940)) {
    expect_equal(f2_tx(fmt_num(u(v, m), unit = "mm|km")), f2(paste0(format(v * 1000, big.mark = ",", trim = TRUE, scientific = FALSE), "~mm")), label = v)
  }
  expect_equal(f2_tx(fmt_num(u(149, m), unit = "mm|km")), f2("149,000~mm"))
  expect_equal(h2_ws(r2h_cx("u(149, m)", 'unit="mm|km"')), f2("149,000~mm"))
  expect_equal(f2_tx(fmt_num(u(32.5, m), unit = "mm|km", digits = 2)), f2("32,500.00~mm"))
  # control: 960 m prints 1.0 km, so it fits
  expect_equal(f2_tx(fmt_num(u(960, m), unit = "mm|km")), f2("1.0~km"))
})

test_that("review 2h #6: a negative number, a span and a vector's last resort follow the same rule (ruling i)", {
  h2_restore()
  expect_equal(f2_tx(fmt_num(u(-149, m), unit = "mm|km")), f2("−149,000~mm"))
  expect_equal(h2_ws('[# was | # were]{n="u(149, m)" unit="mm|km"}'), f2("149,000~mm were"))
  # no rung fits any element: the largest value, 500 m, decides alone, and takes mm
  expect_equal(h2_ws(r2h_cx("u(c(149, 500), m)", '.and unit="mm|km"')), f2("149,000 and 500,000~mm"))
})

test_that("review 2h #6: too small for every rung takes the smallest unit and too large the largest, ascending or descending (ruling i, control)", {
  h2_restore()
  for (lad in c("mm|m|km", "km|m|mm")) {
    expect_equal(h2_ws(r2h_cx("u(0.0005, m)", sprintf('unit="%s"', lad))), f2("0.5~mm"), label = lad)
    expect_equal(h2_ws(r2h_cx("u(5e6, m)", sprintf('unit="%s"', lad))), f2("5,000~km"), label = lad)
  }
  expect_equal(h2_ws(r2h_cx("u(-5e6, m)", 'unit="mm|m|km"')), f2("−5,000~km"))
})

test_that("review 2h #6: a tie in the printed number goes to the earlier rung (ruling i, control)", {
  h2_restore()
  yml <- c("units:", "  zzh2t:", "    is: 1.0001 m")      # 5000.3 m prints 5,000 in both rungs at digits 0
  expect_equal(h2_ws(r2h_cx("u(5000.3, m)", 'unit="m|zzh2t" digits="0"'), yml), f2("5,000~m"))
  expect_equal(h2_ws(r2h_cx("u(5000.3, m)", 'unit="zzh2t|m" digits="0"'), yml), f2("5,000~zzh2t"))
})

# ---- 7: the digits of the project and a ladder ---------------------------------------------------------------------------------------

test_that("review 2h #7: a display ladder is a problem, so no entry prints 1,000 m under digits: 0 from a ladder (ruling a)", {
  h2_restore()
  f <- f2_dict_file("reach: {value: 999.6, type: quantity, unit: m, display: \"m|km\", definition: x}")
  e <- withr::with_dir(f2_proj("digits: 0"), f2_cond(read_dict(f)))
  f2_has_class(e, "weft_dict_error")
  f2_msg_has(e, "`reach`", "display", "`unit` key")
})

test_that("review 2h #7: control - a ladder at the use under digits: 0 picks by the digits in force, and a single display is never re-picked", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(999.6, m)", 'unit="m|km"'), "digits: 0"), f2("1~km"))
  expect_equal(h2_ws(r2h_cx("u(999.6, m)", 'unit="m|km"')), f2("999.6~m"))
  d <- read_dict(f2_dict_file("reach: {value: 999.6, type: quantity, unit: m, display: m, definition: x}"))
  expect_equal(units::deparse_unit(d$reach), "m")
})

# ---- 8: plural() ----------------------------------------------------------------------------------------------------------------------

test_that("review 2h #8: plural() of a formatted ladder value chooses its arm by the number as printed in the picked rung, as a span does", {
  h2_restore()
  for (v in c(1000, 999, 999.96, 1500, 1, 0)) {
    span <- h2_ws(sprintf('[# was | # were]{n="u(%s, m)" unit="m|km"}', v))
    w <- h2_warns(plural(fmt_num(u(v, m), unit = "m|km"), "was", "were"))$v
    expect_true(endsWith(span, w), label = sprintf("%s: span `%s`, plural `%s`", v, span, w))
  }
  expect_equal(plural(fmt_num(u(1000, m), unit = "m|km"), "was", "were"), "was")
  expect_equal(plural(fmt_num(u(999, m), unit = "m|km"), "was", "were"), "were")
})

# ---- 9: unit_picked for a construct that failed -----------------------------------------------------------------------------------------

R2H_PICK_DOC <- c(
  "A `r vv`{.and unit=\"m|km\"}.",                       # 1: fails after the pick (an NA element)
  "",
  "B `r x`{unit=\"m|km\"}.",                             # 3: succeeds
  "",
  "C `r x`{unit=\"m|kg\"}."                              # 5: fails before the pick
)

r2h_pick_knit <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(R2H_PICK_DOC, code = "x <- u(1500, m); vv <- u(c(NA, 1500), m)", in_process = TRUE,
                           env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

r2h_pick_line <- function(res, line) {
  cs <- res$knit$constructs
  cs[cs$line == res$offset + line, , drop = FALSE]
}

test_that("review 2h #9: unit_picked is NA for a construct that failed after the pick", {
  res <- r2h_pick_knit()
  skip_if(res$failed, "the document did not render")
  expect_true(any(grepl("no value", res$text, fixed = TRUE)), label = "the construct failed with a marker")
  row <- r2h_pick_line(res, 1)
  expect_equal(nrow(row), 1L)
  expect_true(is.na(row$unit_picked))
})

test_that("review 2h #9: controls - a construct that printed has its rung, one that failed before the pick has NA", {
  res <- r2h_pick_knit()
  skip_if(res$failed, "the document did not render")
  expect_equal(r2h_pick_line(res, 3)$unit_picked, "km")
  expect_true(is.na(r2h_pick_line(res, 5)$unit_picked))
})

# ---- 10: dictionary messages ---------------------------------------------------------------------------------------------------------------

test_that("review 2h #10: a display problem cites its rule once, for every shape of ladder (rule 4.2.7)", {
  h2_restore()
  for (disp in c("\"m||km\"", "\"|\"", "[m, m]", "[\"\", km]", "[m|km, mm]", "\"m|km\"")) {
    e <- r2h_dict_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    line <- r2h_line(e, "w")
    expect_length(line, 1L)
    expect_equal(lengths(regmatches(line, gregexpr("(rule ", line, fixed = TRUE))), 1L, label = line)
  }
})

test_that("review 2h #10: a one-item list holding | is a problem, no longer accepted as one unit (ruling a)", {
  h2_restore()
  e <- r2h_dict_err("w: {value: 1, type: quantity, unit: m, display: [\"m|km\"], definition: x}")
  f2_msg_has(e, "`w`", "display", "`unit` key")
  e2 <- r2h_dict_err("w: {value: 1, type: quantity, unit: m, display: [m|km], definition: x}")
  f2_msg_has(e2, "`w`", "display", "`unit` key")
})

test_that("review 2h #10: control - a one-item list without | is one unit, and a single unit reads", {
  h2_restore()
  d <- read_dict(f2_dict_file("w: {value: 2000, type: quantity, unit: m, display: [km], definition: x}"))
  expect_equal(units::deparse_unit(d$w), "km")
  expect_equal(as.numeric(d$w), 2)
})

test_that("review 2h #10: control - a ladder at the use cites its rule once (rule 4.4.23)", {
  h2_restore()
  e <- f2_err(r2h_cx("u(5, m)", 'unit="mm||km"'))
  expect_equal(lengths(regmatches(f2_msg(e), gregexpr("(rule ", f2_msg(e), fixed = TRUE))), 1L, label = f2_msg(e))
})

# ---- 11: the twin message names the rung once -----------------------------------------------------------------------------------------------

test_that("review 2h #11: the twin message names the rung once, and still ends with the rule (rule 4.4.14)", {
  h2_restore()
  e <- f2_err(r2h_cx("u(2, Sv)", 'unit="mSv|Sv|Gy"'))
  f2_has_class(e, "weft_value_error")
  m <- f2_msg(e)
  expect_false(grepl("`Gy`: `Gy`", m, fixed = TRUE), label = m)
  expect_equal(lengths(regmatches(m, gregexpr("`Gy`", m, fixed = TRUE))), 1L, label = m)
  f2_msg_has(e, "rung", "the quantity is in `Sv`")
  expect_true(grepl("\\(rule 4\\.4\\.14\\)\\.?$", trimws(m)), label = m)
  e2 <- f2_cond(fmt_num(u(2, Sv), unit = "mSv|Sv|Gy"))
  expect_false(grepl("`Gy`: `Gy`", f2_msg(e2), fixed = TRUE), label = f2_msg(e2))
})

test_that("review 2h #11: control - another rung failure reads cleanly (rule 4.4.14)", {
  h2_restore()
  e <- f2_err(r2h_cx("u(5, m)", 'unit="mm|kg"'))
  f2_msg_has(e, "rung `kg`", "the quantity (m) cannot be converted to it")
})

# ---- 12: unit = that is not a string or a character vector ------------------------------------------------------------------------------------

test_that("review 2h #12: unit = that is neither a string nor a character vector names both forms", {
  h2_restore()
  for (bad in list(character(0), NA_character_, list("m", "km"), factor("km"), 5)) {
    e <- f2_cond(fmt_num(u(5, m), unit = bad))
    f2_has_class(e, "weft_value_error")
    m <- f2_msg(e)
    expect_true(grepl("vector", m, fixed = TRUE), label = m)
    expect_true(grepl("string", m, fixed = TRUE), label = m)
    expect_true(grepl("(rule 4.4.14)", m, fixed = TRUE) || grepl("(rule 4.4.23)", m, fixed = TRUE), label = m)
  }
})

test_that("review 2h #12: control - a vector with a missing item is the ladder message", {
  h2_restore()
  e <- f2_cond(fmt_num(u(5, m), unit = c("m", NA)))
  f2_has_class(e, "weft_construct_error")
  f2_msg_has(e, "ladder", "(rule 4.4.23)")
})

# ---- 13: small points -------------------------------------------------------------------------------------------------------------------------------

test_that("review 2h #13: the back-reference form that works prints the unit name; on a value the key n is still the 1.3.3 error", {
  h2_restore()
  expect_equal(h2_ws('`r u(1500, m)`{#d unit="m|km"} [#]{n="#d" .uname}'), f2("1.5~km 1.5~kilometres"))
  e <- f2_err('`r u(1500, m)`{n="#d" .uname}')
  f2_has_class(e, "weft_construct_error")
  f2_msg_has(e, "(rule 1.3.3)")
})

test_that("review 2h #13: .pct with any quantity stays the 4.4.8 error, with a ladder as without one (control)", {
  h2_restore()
  e1 <- f2_cond(fmt_pct(u(1500, m), unit = "km"))
  e2 <- f2_cond(fmt_pct(u(1500, m), unit = "m|km"))
  f2_has_class(e1, "weft_value_error")
  f2_has_class(e2, "weft_value_error")
  f2_msg_has(e2, "(rule 4.4.8)")
})

# ---- c, d, h: kept as built ---------------------------------------------------------------------------------------------------------------------

test_that("review 2h c: | separates the rungs, in a value, a span and a call (kept as built)", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(1500, m)", 'unit="m|km"')), f2("1.5~km"))
  expect_equal(h2_ws('[#]{n="u(1500, m)" unit="m|km"}'), f2("1.5~km"))
  expect_equal(f2_tx(fmt_num(u(1500, m), unit = "m|km")), f2("1.5~km"))
})

test_that("review 2h d: the order is the author's preference, and a descending ladder breaks a tie toward the larger unit (kept as built)", {
  h2_restore()
  expect_equal(h2_ws(r2h_cx("u(0.05, m)", 'unit="cm|mm|m"')), f2("5~cm"))
  expect_equal(h2_ws(r2h_cx("u(0.05, m)", 'unit="mm|cm|m"')), f2("50~mm"))
  expect_equal(h2_ws(r2h_cx("u(c(500, 2000), m)", '.and unit="km|m"')), f2("0.5 and 2~km"))
  expect_equal(h2_ws(r2h_cx("u(c(500, 2000), m)", '.and unit="m|km"')), f2("500 and 2,000~m"))
})

test_that("review 2h h: a back-reference formatted again with digits may print outside the window (kept as built)", {
  h2_restore()
  expect_equal(h2_ws('`r u(999.6, m)`{#e unit="m|km"} then [#]{n="#e" digits="0"}'), f2("999.6~m then 1,000~m"))
  expect_equal(h2_ws('`r u(999.6, m)`{#e unit="m|km"} then [# is | # are]{n="#e" digits="0"}'), f2("999.6~m then 1,000~m are"))
  expect_equal(h2_ws('`r u(999.6, m)`{#e unit="m|km"} then [#]{n="#e" digits="0" unit="m|km"}'), f2("999.6~m then 1~km"))
})
