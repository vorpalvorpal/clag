# Package 2f: unit forms (symbol, name, none), plurals, the unit classes, unit_form =.
# Contract: dev/design-2f.md "Forms", "Plurals", "Functions", "The weft_text",
# "Expected output" and "Errors"; U2-U6, U19. Rules 1.4.2, 1.4.7, 1.4.19, 3.4.4, 3.4.8, 4.4.2-4.4.4, 4.4.13, 4.4.15.
# `~` in an expected string is U+00A0; weft_str() gives the Pandoc `\ `, undone by f2_ws().
if (!exists("f2_ws")) source(testthat::test_path("helper-2f.R"))

SITES_YML <- c("units:", "  sites:", "    name: site", "    symbol: false")

# ---- the expected-output table, row by row ------------------------------------------------------

test_that("2f table: u(5, m) under .num, .word, .uname, .nounit (4.4.2, 4.4.15)", {
  f2_rows(c("`r u(5, m)`{.num}", "`r u(5, m)`{.word}", "`r u(5, m)`{.uname}", "`r u(5, m)`{.nounit}"),
          c("5~m", "five~metres", "5~metres", "5"))
})

test_that("2f table: u(1, m) is singular under a name when its number prints 1 (4.4.15)", {
  f2_rows(c("`r u(1, m)`{.word}", "`r u(1, m)`{.uname}", "`r u(1, m)`{.uname digits=\"1\"}"),
          c("one~metre", "1~metre", "1.0~metres"))
})

test_that("2f table: .no on zero is 'no metres' and on 2 is '2 m' (U2, 4.4.13)", {
  f2_rows(c("`r u(0, m)`{.no}", "`r u(2, m)`{.no}"), c("no~metres", "2~m"))
})

test_that("2f table: 0.04 under .uname prints 0.0 metres, the warned check (4.4.13)", {
  got <- suppressWarnings(f2_ws("`r u(0.04, m)`{.uname}"))
  expect_equal(got, f2("0.0~metres"))
})

test_that("2f table: .nounit and a class that wraps the unit (4.4.2)", {
  f2_rows(c("`r u(3, m)`{.word .nounit}", "`r u(3, m)`{.strong .word}"),
          c("three", "**three~metres**"))
})

test_that("2f table: a unit typed as a name prints its symbol (U11)", {
  f2_rows(c("`r u(5, metre)`{.num}", "`r u(2, kilometre)`{.num}"), c("5~m", "2~km"))
})

test_that("2f table: compound names (4.4.18)", {
  f2_rows(c("`r u(5, mg/L)`{.uname}", "`r u(2, m^2)`{.uname}", "`r u(1, m^3)`{.uname}",
            "`r u(9.81, m/s^2)`{.uname}", "`r u(1200, kg/m^3)`{.uname}",
            "`r u(2, \"1/m^3\")`{.uname}", "`r u(3, kW*h)`{.uname}"),
          c("5~milligrams per litre", "2~square metres", "1~cubic metre",
            "9.8~metres per second squared", "1,200~kilograms per cubic metre",
            "2~per cubic metre", "3~kilowatt hours"))
})

test_that("2f table: years have no symbol and print their name, in digits and in words (U9)", {
  f2_rows(c("`r u(10, year)`{.num}", "`r u(10, yr)`{.num}", "`r u(1, year)`{.num}",
            "`r u(10, year)`{.word}", "`r u(1, year)`{.word}"),
          c("10~years", "10~years", "1~year", "ten~years", "one~year"))
})

test_that("2f table: d is a symbol, a week a name, ha a symbol (U10)", {
  f2_rows(c("`r u(5, d)`{.num}", "`r u(3, week)`{.num}", "`r u(2, ha)`{.num}"),
          c("5~d", "3~weeks", "2~ha"))
})

test_that("2f table: ft, ft singular, Hz under .uname (4.4.17)", {
  f2_rows(c("`r u(5, ft)`{.uname}", "`r u(1, ft)`{.uname}", "`r u(20, Hz)`{.uname}"),
          c("5~feet", "1~foot", "20~hertz"))
})

test_that("2f table: no space before % and the degree sign, one before a degree Celsius (R3, U13, 4.4.8)", {
  f2_rows(c("`r u(35, \"%\")`{.num}", "`r u(45, \"°\")`{.num}", "`r u(20, degC)`{.num}"),
          c("35%", paste0("45", F2_DEG), paste0("20~", F2_DEG, "C")))
})

test_that("2f table: per cent, degrees Celsius and tonnes in words and names", {
  f2_rows(c("`r u(5, \"%\")`{.word}", "`r u(20, degC)`{.word}", "`r u(2, t)`{.uname}"),
          c("five~per cent", "twenty~degrees Celsius", "2~tonnes"))
})

test_that("2f table: a collapsed vector puts the unit once after the last item, in its form (4.4.3)", {
  f2_rows(c("`r u(c(3, 5, 7), m)`{.and}", "`r u(c(3, 5, 7), m)`{.word .and}", "`r u(c(3, 5, 7), m)`{.uname .and}"),
          c("3, 5 and 7~m", "three, five and seven~metres", "3, 5 and 7~metres"))
})

test_that("2f table: .range, with both ends 1 singular (4.4.3, 4.4.15)", {
  f2_rows(c("`r u(c(3, 5), m)`{.range .uname}", "`r u(c(1, 1), m)`{.range .uname}"),
          c(paste0("3", F2_ENDASH, "5~metres"), "1~metre"))
})

test_that("2f table: trunc, singular only when exactly one number prints and it is 1 (U5)", {
  f2_rows(c("`r u(c(3, 5, 7, 9), m)`{.and .uname trunc=\"2\"}", "`r u(c(1, 5, 7), m)`{.and .uname trunc=\"1\"}"),
          c("3, 5~metres and 2 others", "1~metre and 2 others"))
})

test_that("2f table: .pairs judges each element (4.4.3, 4.4.15)", {
  f2_rows("`r u(c(a = 1, b = 3), m)`{.pairs .word}", "a (one~metre) and b (three~metres)")
})

test_that("2f table: .count prints each element in its own form (4.4.3)", {
  f2_rows("`r u(c(3, 12), m)`{.count}", "three~metres, 12~m")
})

test_that("2f table: a ratio has no unit, so .word prints the number and .uname is a value error (1.4.19)", {
  expect_equal(f2_ws("`r u(6, m) / u(3, m)`{.word}"), "two")
  e <- f2_err("`r u(6, m) / u(3, m)`{.uname}")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, ".uname", "no unit left")
})

test_that("2f table: PSU under .num prints the symbol; under .word and .count it is a value error naming PSU (4.4.19)", {
  f2_register()
  expect_equal(f2_ws("`r u(3, PSU)`{.num}"), f2("3~PSU"))
  for (s in c("`r u(3, PSU)`{.word}", "`r u(12, PSU)`{.count}")) {
    e <- f2_err(s)
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, "PSU")
  }
})

test_that("2f table: CFU/100 mL prints units' symbol under .num and has no name (4.4.19)", {
  f2_register()
  expect_equal(f2_ws("`r u(150, \"CFU/100 mL\")`{.num}"), f2("150~CFU/(100mL)"))
  f2_has_class(f2_err("`r u(150, \"CFU/100 mL\")`{.uname}"), "weft_value_error")
})

test_that("2f table: a project unit with no symbol prints its name in every form; a compound over it too (U9, U14)", {
  f2_register()
  f2_rows(c("`r u(1, sites)`{.num}", "`r u(12, sites)`{.num}", "`r u(3, sites)`{.count}",
            "`r u(5, sites) / u(2, ha)`{.num}", "`r u(5, sites) / u(2, ha)`{.uname}"),
          c("1~site", "12~sites", "three~sites", "2.5~sites/ha", "2.5~sites per hectare"), SITES_YML)
})

test_that("2f table: unit_form in the project, .num and .usym at the use (nearest wins)", {
  f2_rows(c("`r u(5, m)`{.num}", "`r u(5, m)`{.usym}"), c("5~metres", "5~m"), "unit_form: name")
})

test_that("2f table: unit_form symbol makes a spelled number a value error, and .uname overrides it (U4)", {
  yml <- "unit_form: symbol"
  e <- f2_err("`r u(3, m)`{.word}", yml)
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, ".word", "symbol")
  expect_equal(f2_ws("`r u(3, m)`{.word .uname}", yml), f2("three~metres"))
})

test_that("2f table: # in an n span takes the governor's form, unit included (4.4.4)", {
  f2_rows(c("[# was | # were]{n=\"u(5, m)\" .word}", "[# was | # were]{n=\"u(1, m)\" .word}"),
          c("five~metres were", "one~metre was"))
})

test_that("2f table: # in a count span and in a sign span (4.4.4)", {
  f2_rows(c("[# long]{n=\"u(3, m)\" .count}", "[rose by # | fell by #]{sign=\"u(-1, m)\" .uname}"),
          c("three~metres long", "fell by 1~metre"))
})

test_that("2f table: a list span with a wording class (4.4.4, 4.4.3)", {
  f2_rows("[none | # was | # were]{list=\"u(c(3, 5), m)\" .word}", "three and five~metres were")
})

test_that("2f table: plural(), and a number class given a word's text, in their own form (3.4.4)", {
  expect_equal(f2_tx(plural(u(1, year), "# ago")), f2("1~year ago"))
  x <- u(5, m)
  expect_equal(f2_tx(fmt_num(fmt_word(x))), f2("5~m"))
})

test_that("2f table: a collapse given digits and unit_form = 'name' (3.4.8)", {
  x <- u(c(3, 5), m)
  expect_equal(f2_tx(fmt_and(fmt_num(x), unit_form = "name")), f2("3 and 5~metres"))
})

# ---- controls: symbol printing as before -----------------------------------------------------------------

test_that("2f control: a quantity prints its symbol after a no-break space under .num as before", {
  f2_rows(c("`r u(5, m)`{.num}", "`r u(20, degC)`{.num}", "`r u(5, mg/L)`{.num}", "`r u(35, m)`{.num}",
            "`r u(c(3, 5), m)`{.range}", "`r u(c(3, 5, 7), m)`{.and}", "`r u(1200, m)`{.sci}"),
          c("5~m", paste0("20~", F2_DEG, "C"), "5~mg/L", "35~m", paste0("3", F2_ENDASH, "5~m"),
            "3, 5 and 7~m", paste0("1.2 × 10^3^~m")))
  expect_equal(f2_tx(fmt_num(u(5, m))), f2("5~m"))
})

test_that("2f control: a plain number prints as before and carries no unit attributes", {
  expect_equal(f2_tx(fmt_num(3.14159)), "3.1")
  r <- fmt_num(3.14159)
  expect_null(attr(r, "unit")); expect_null(attr(r, "unit_form")); expect_null(attr(r, "units"))
})

# ---- plurals at 0, 0.5, 1, 1.0, -1 and in each collapse (4.4.15, U5, U6) ---------------------------------------

test_that("2f plurals: a name is singular only when its number prints 1 or one (4.4.15)", {
  nmf <- function(v, ...) f2_tx(fmt_num(u(v, m), unit_form = "name", ...))
  expect_equal(nmf(0.5), f2("0.5~metres"))
  expect_equal(nmf(0), f2("0~metres"))
  expect_equal(nmf(1), f2("1~metre"))
  expect_equal(nmf(1, digits = 1), f2("1.0~metres"))
  expect_equal(nmf(-1), f2(paste0(F2_MINUS, "1~metres")))
  expect_equal(nmf(2), f2("2~metres"))
  expect_equal(f2_tx(fmt_word(u(1, m))), f2("one~metre"))
  expect_equal(f2_tx(fmt_word(u(0, m))), f2("zero~metres"))
})

test_that("2f plurals: a symbol never changes (4.4.15)", {
  expect_equal(f2_tx(fmt_num(u(1, m))), f2("1~m"))
  expect_equal(f2_tx(fmt_num(u(2, m))), f2("2~m"))
})

test_that("2f plurals: in a collapse the name is singular only when exactly one number prints and it is 1 (U5)", {
  expect_equal(f2_tx(fmt_and(u(c(3, 5, 1), m), unit_form = "name")), f2("3, 5 and 1~metres"))
  expect_equal(f2_tx(fmt_and(u(c(1, 2), m), unit_form = "name")), f2("1 and 2~metres"))
  expect_equal(f2_tx(fmt_and(u(c(1, 5, 7), m), unit_form = "name", trunc = 1)), f2("1~metre and 2 others"))
  expect_equal(f2_tx(fmt_range(u(c(1, 1), m), unit_form = "name")), f2("1~metre"))
  expect_equal(f2_tx(fmt_range(u(c(1, 2), m), unit_form = "name")), f2(paste0("1", F2_ENDASH, "2~metres")))
  expect_equal(f2_tx(fmt_or(u(c(1, 3), m), unit_form = "name")), f2("1 or 3~metres"))
})

test_that("2f plurals: .pairs, the list classes and an uncollapsed vector judge each element (4.4.15)", {
  expect_equal(f2_tx(fmt_pairs(u(c(a = 1, b = 3), m), unit_form = "name")), f2("a (1~metre) and b (3~metres)"))
  expect_equal(f2_tx(fmt_num(u(c(1, 3), m), unit_form = "name")), f2(c("1~metre", "3~metres")))
  ul <- f2_tx(fmt_ul(u(c(1, 3), m), unit_form = "name"))
  expect_true(grepl(f2("1~metre"), ul, fixed = TRUE))
  expect_true(grepl(f2("3~metres"), ul, fixed = TRUE))
  expect_false(grepl(f2("1~metres"), ul, fixed = TRUE))
})

test_that("2f plurals: # in a sign span judges the magnitude (4.4.15, U6)", {
  f2_rows(c("[rose by # | fell by #]{sign=\"u(1, m)\" .uname}", "[rose by # | fell by #]{sign=\"u(-1, m)\" .uname}",
            "[rose by # | fell by #]{sign=\"u(-2, m)\" .uname}", "[rose by # | fell by #]{sign=\"u(2, m)\" .uname}"),
          c("rose by 1~metre", "fell by 1~metre", "fell by 2~metres", "rose by 2~metres"))
})

test_that("2f plurals: # in an n span follows the governor's printed number, not the arm chosen (4.4.15)", {
  f2_rows(c("[# was | # were]{n=\"u(1, m)\" .uname}", "[# was | # were]{n=\"u(2, m)\" .uname}"),
          c("1~metre was", "2~metres were"))
})

test_that("2f plurals: plural() takes the unit form from the text it is given (3.4.8)", {
  r <- plural(fmt_num(u(1, m), unit_form = "name"), "# long")
  expect_equal(f2_tx(r), f2("1~metre long"))
})

# ---- the weft_text: unit, unit_form, units; chains (3.4.4, U19) ---------------------------------------------------

test_that("2f attributes: a quantity's text carries unit, unit_form and units (3.4.4)", {
  r <- fmt_num(u(5, m))
  expect_equal(attr(r, "unit"), "m")
  expect_equal(attr(r, "unit_form"), "symbol")
  expect_s3_class(attr(r, "units"), "symbolic_units")
  expect_equal(as.character(attr(r, "units")), as.character(units(u(5, m))))
})

test_that("2f attributes: unit holds the symbol text as printed for a plural number, in either form (3.4.4)", {
  expect_equal(attr(fmt_num(u(10, year)), "unit"), "years")
  expect_equal(attr(fmt_num(u(1, year)), "unit"), "years")
  rn <- fmt_num(u(5, m), unit_form = "name")
  expect_equal(attr(rn, "unit"), "m")
  expect_equal(attr(rn, "unit_form"), "name")
  expect_equal(attr(fmt_word(u(3, m)), "unit"), "m")
  expect_equal(attr(fmt_word(u(3, m)), "unit_form"), "name")
})

test_that("2f attributes: unit_form is long as the text, symbol, name or NA per element; .nounit gives NA (3.4.4)", {
  expect_equal(attr(fmt_count(u(c(3, 12), m)), "unit_form"), c("name", "symbol"))
  expect_equal(attr(fmt_num(u(c(3, 12), m)), "unit_form"), c("symbol", "symbol"))
  expect_equal(attr(fmt_num(u(c(3, 12), m), unit_form = "none"), "unit_form"), c(NA_character_, NA_character_))
  expect_equal(f2_tx(fmt_num(u(5, m), unit_form = "none")), "5")
})

test_that("2f attributes: units is the unit after conversion (3.4.4)", {
  r <- fmt_num(u(150, cm), unit = "m")
  expect_equal(as.character(attr(r, "units")), as.character(units(u(1, m))))
})

test_that("2f attributes: text with no unit carries none of the three (3.4.4)", {
  for (r in list(fmt_num(5), fmt_num(u(6, m) / u(3, m)), fmt_num(u(5, m), unit_form = "none"))) {
    expect_null(attr(r, "units"))
  }
  r <- fmt_num(5)
  expect_null(attr(r, "unit")); expect_null(attr(r, "unit_form")); expect_null(attr(r, "units"))
  r2 <- fmt_num(u(6, m) / u(3, m))
  expect_null(attr(r2, "unit")); expect_null(attr(r2, "unit_form")); expect_null(attr(r2, "units"))
})

test_that("2f chains: a collapse with unit_form NULL keeps each element's form (3.4.4)", {
  expect_equal(f2_tx(fmt_and(fmt_word(u(c(3, 5, 7), m)))), f2("three, five and seven~metres"))
  expect_equal(f2_tx(fmt_and(fmt_count(u(c(3, 12), m)))), f2("three and 12~m"))   # ruling: the unit once, in the last item's form
})

test_that("2f chains: a number class given a text formats raw afresh in its own form in force (3.4.4)", {
  expect_equal(f2_tx(fmt_num(fmt_word(u(5, m)))), f2("5~m"))
  expect_equal(f2_tx(fmt_word(fmt_num(u(5, m)))), f2("five~metres"))
  expect_equal(f2_tx(fmt_and(fmt_num(u(c(3, 5), m)), unit_form = "name")), f2("3 and 5~metres"))
})

test_that("2f chains: the doubled form of a spelled number holds one unit after a collapse (4.4.3)", {
  # D24 replaced: the unit after the last item takes that item's form
  expect_equal(f2_tx(fmt_and(fmt_word(u(c(200, 5), m)))), f2("200 and five~metres"))
  expect_equal(f2_ws("`r u(c(200, 5), m)`{.word .and}"), f2("200 and five~metres"))
})

# ---- unit_form = on every listed function (3.4.8) ----------------------------------------------------------------

test_that("2f unit_form: each listed function takes it, last, and prints the form (3.4.8)", {
  x <- u(c(3, 5), m)
  expect_equal(f2_tx(fmt_num(u(5, m), unit_form = "name")), f2("5~metres"))
  expect_equal(f2_tx(fmt_sci(u(1200, m), unit_form = "name")), f2("1.2 × 10^3^~metres"))
  expect_equal(f2_tx(fmt_range(x, unit_form = "name")), f2(paste0("3", F2_ENDASH, "5~metres")))
  expect_equal(f2_tx(fmt_no(u(0, m), unit_form = "name")), f2("no~metres"))
  expect_equal(f2_tx(fmt_word(u(3, m), unit_form = "name")), f2("three~metres"))
  expect_equal(f2_tx(fmt_count(u(3, m), unit_form = "name")), f2("three~metres"))
  # ruling a on the review of 2f: a rank has no unit, so .ord on a quantity is a value error
  f2_has_class(f2_cond(fmt_ord(u(3, m), unit_form = "name")), "weft_value_error")
  expect_equal(f2_tx(fmt_and(u(c(3, 5, 7), m), unit_form = "name")), f2("3, 5 and 7~metres"))
  expect_equal(f2_tx(fmt_or(x, unit_form = "name")), f2("3 or 5~metres"))
  expect_equal(f2_tx(fmt_pairs(u(c(a = 1, b = 3), m), unit_form = "name")), f2("a (1~metre) and b (3~metres)"))
  for (f in list(fmt_ul, fmt_ol, fmt_dl)) {
    out <- f2_tx(f(u(c(a = 3, b = 5), m), unit_form = "name"))
    expect_true(grepl(f2("3~metres"), out, fixed = TRUE))
    expect_true(grepl(f2("5~metres"), out, fixed = TRUE))
  }
  expect_equal(names(formals(fmt_num)), c("x", "digits", "sigfig", "unit", "unit_form"))
  for (f in list(fmt_sci, fmt_range, fmt_no, fmt_word, fmt_count, fmt_ord, fmt_and, fmt_or, fmt_pairs, fmt_ul, fmt_ol, fmt_dl)) {
    expect_equal(tail(names(formals(f)), 1), "unit_form")
  }
})

test_that("2f unit_form: 'symbol' prints the symbol where digits are printed (3.4.8)", {
  expect_equal(f2_tx(fmt_num(u(5, year), unit_form = "symbol")), f2("5~years"))     # no symbol: the name
  expect_equal(f2_tx(fmt_and(u(c(3, 5), m), unit_form = "symbol")), f2("3 and 5~m"))
  expect_equal(f2_tx(fmt_range(u(c(3, 5), m), unit_form = "symbol")), f2(paste0("3", F2_ENDASH, "5~m")))
})

test_that("2f unit_form: 'none' prints the number alone (3.4.8)", {
  expect_equal(f2_tx(fmt_num(u(5, m), unit_form = "none")), "5")
  expect_equal(f2_tx(fmt_word(u(3, m), unit_form = "none")), "three")
  expect_equal(f2_tx(fmt_and(u(c(3, 5), m), unit_form = "none")), "3 and 5")
})

test_that("2f unit_form: 'auto' is the default and changes nothing (3.4.8)", {
  expect_equal(f2_tx(fmt_num(u(5, m), unit_form = "auto")), f2("5~m"))
  expect_equal(f2_tx(fmt_word(u(3, m), unit_form = "auto")), f2("three~metres"))
})

test_that("2f unit_form: a bad value is a construct error on every function (3.4.8, errors)", {
  x <- u(c(3, 5), m)
  for (f in list(fmt_num, fmt_sci, fmt_range, fmt_no, fmt_word, fmt_count, fmt_ord, fmt_and, fmt_or, fmt_pairs, fmt_ul, fmt_ol, fmt_dl)) {
    e <- f2_cond(f(x, unit_form = "bogus"))
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, "unit_form")
  }
  f2_has_class(f2_cond(fmt_num(u(5, m), unit_form = c("name", "symbol"))), "weft_construct_error")
  f2_has_class(f2_cond(fmt_num(u(5, m), unit_form = NA_character_)), "weft_construct_error")
})

test_that("2f unit_form: 'symbol' on fmt_no(), fmt_word() and fmt_count() is a construct error (3.4.8, errors)", {
  for (f in list(fmt_no, fmt_word, fmt_count)) {
    e <- f2_cond(f(u(3, m), unit_form = "symbol"))
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, "symbol")
  }
  # control: symbol is fine where digits print
  expect_no_error(fmt_num(u(3, m), unit_form = "symbol"))
})

test_that("2f unit_form: a form other than auto on a value with no unit is a value error; auto is not (1.4.19)", {
  for (f in list(fmt_num, fmt_word)) {
    e <- f2_cond(f(5, unit_form = "name"))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, "unit_form")
  }
  f2_has_class(f2_cond(fmt_num(u(6, m) / u(3, m), unit_form = "name")), "weft_value_error")
  f2_has_class(f2_cond(fmt_num(5, unit_form = "none")), "weft_value_error")
  expect_equal(f2_tx(fmt_num(5, unit_form = "auto")), "5")
  expect_equal(f2_tx(fmt_num(5, unit_form = NULL)), "5")
})

# ---- the unit classes (1.4.2, 1.4.7, 1.4.19, 4.4.3) ---------------------------------------------------------------

test_that("2f classes: a unit class implies .num when no number class is given (1.4.7)", {
  f2_rows(c("`r u(1200, m)`{.uname}", "`r u(1200, m)`{.usym}", "`r u(1200, m)`{.nounit}"),
          c("1,200~metres", "1,200~m", "1,200"))
})

test_that("2f classes: a unit class on a number or a ratio is a value error naming the class (1.4.19)", {
  for (cl in c(".uname", ".usym", ".nounit")) {
    e <- f2_err(sprintf("`r 5`{%s}", cl))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, cl)
  }
  e <- f2_err("`r u(6, m) / u(3, m)`{.usym}")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, ".usym", "no unit left")
})

test_that("2f classes: on an n, sign or list span the class acts on # (1.4.7)", {
  f2_rows(c("[# was | # were]{n=\"u(5, m)\" .uname}", "[up # | down #]{sign=\"u(5, m)\" .usym}",
            "[none | # was | # were]{list=\"u(c(3, 5), m)\" .uname}"),
          c("5~metres were", "up 5~m", "3 and 5~metres were"))
})

test_that("2f classes: on a text span with no key a unit class passes through (1.1.9, 1.4.7)", {
  expect_no_error(f2_ws("[abc]{.uname}"))
  expect_no_error(f2_ws("[abc]{.nounit}"))
})

test_that("2f classes: .pct is not a unit, so unit_form name leaves its % alone (4.4.15)", {
  expect_equal(f2_ws("`r 0.35`{.pct}", "unit_form: name"), "35%")
  expect_equal(f2_ws("`r 0.35`{.pct}", "unit_form: symbol"), "35%")
})

test_that("2f classes: a quantity under .pct is still the value error (control, 4.4.8)", {
  f2_has_class(f2_err("`r u(3, m)`{.pct}"), "weft_value_error")
})

# ---- the errors that come from the value, with their wording (Errors) ------------------------------------------------

test_that("2f errors: a wording class under form symbol names the class, the form, where set and the remedies (4.4.15)", {
  e <- f2_err("`r u(3, m)`{.word}", "unit_form: symbol")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, ".word", "symbol", ".uname", ".nounit", "_weft.yml")
  e2 <- f2_err("`r u(3, m)`{.count}", "unit_form: symbol")
  f2_has_class(e2, "weft_value_error")
  e3 <- f2_err("`r u(0, m)`{.no}", "unit_form: symbol")
  f2_has_class(e3, "weft_value_error")
})

test_that("2f errors: unit_form symbol with .num, .range, .and prints symbols and is not an error (control)", {
  yml <- "unit_form: symbol"
  f2_rows(c("`r u(5, m)`{.num}", "`r u(c(3, 5), m)`{.range}", "`r u(c(3, 5, 7), m)`{.and}"),
          c("5~m", paste0("3", F2_ENDASH, "5~m"), "3, 5 and 7~m"), yml)
})

test_that("2f errors: judged on the classes, a spelled number under form symbol is an error for every value (U3, U4)", {
  yml <- "unit_form: symbol"
  for (v in c(3, 12, 100)) {
    f2_has_class(f2_err(sprintf("`r u(%g, m)`{.word}", v), yml), "weft_value_error")
  }
  f2_has_class(f2_err("`r u(12, m)`{.count}", yml), "weft_value_error")
})

# ---- construct errors from the source (Errors, 1.4.2, 1.4.19, 5.3.1) -------------------------------------------------

test_that("2f construct: two unit classes (1.4.2)", {
  for (cl in c(".uname .usym", ".usym .nounit", ".uname .nounit")) {
    e <- f2_err(sprintf("`r u(5, m)`{%s}", cl))
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, "unit")
  }
})

test_that("2f construct: .usym with .no, .word or .count (1.4.19)", {
  for (cl in c(".no", ".word", ".count")) {
    e <- f2_err(sprintf("`r u(3, m)`{.usym %s}", cl))
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, ".usym", cl)
  }
})

test_that("2f construct: a unit class on an if or cite span (1.4.19)", {
  for (src in c("[a | b]{if=\"TRUE\" .uname}", "[a | b]{if=\"TRUE\" .usym}", "[a | b]{if=\"TRUE\" .nounit}",
                "[10 m]{cite=\"@smith2020\" .uname}")) {
    e <- f2_err(src)
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, "unit")
  }
})

test_that("2f construct: controls, .uname with .word, .num and .nounit with .word are accepted (1.4.2)", {
  expect_no_error(f2_ws("`r u(3, m)`{.uname .word}"))
  expect_no_error(f2_ws("`r u(3, m)`{.num .uname}"))
  expect_no_error(f2_ws("`r u(3, m)`{.usym .num}"))
  expect_no_error(f2_ws("`r u(3, m)`{.nounit .word}"))
})

test_that("2f construct: .uname .word on a spelled quantity names the unit (4.4.4, name after a spelled number)", {
  expect_equal(f2_ws("`r u(3, m)`{.uname .word}"), f2("three~metres"))
  expect_equal(f2_ws("`r u(3, m)`{.uname .word .strong}"), f2("**three~metres**"))
})

test_that("2f zero rule: .no on a zero prints 'no metres' under the name and a name is judged by the class (U2)", {
  expect_equal(f2_ws("`r u(0, m)`{.no}"), f2("no~metres"))
  expect_equal(f2_ws("`r u(0, m)`{.no .nounit}"), "no")
  expect_equal(f2_ws("`r u(0, m)`{.no .uname}"), f2("no~metres"))
  expect_equal(f2_ws("`r u(3, m)`{.no}"), f2("3~m"))
})
