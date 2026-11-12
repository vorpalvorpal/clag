# Package 2h: the unit ladder (rule 4.4.23). Contract: dev/design-2h.md "The contract", "Expected
# output", "Errors", L1-L18. `~` in an expected string is U+00A0; the minus is U+2212 and the en dash
# U+2013, written as \uXXXX. Made-up content only. A ladder is "mm|m|km"; "L" in the contract's table.
if (!exists("h2_row")) source(Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))[[1]])
h2_need()

L <- 'unit="mm|m|km"'
# `r <value>`{<attrs>}
cx <- function(value, attrs) paste0("`r ", value, "`{", attrs, "}")

# ---- the expected-output table (mode weft, .num) -------------------------------------------------------------

h2_row(cx("u(1500, m)", L), "1.5~km")
h2_row(cx("u(250, m)", L), "250~m")
h2_row(cx("u(0.25, m)", L), "250~mm")
h2_row(cx("u(1, m)", L), "1~m")
h2_row(cx("u(1000, m)", L), "1~km")
h2_row(cx("u(999.96, m)", L), "1.0~km")        # 999.96 m prints "1,000.0" and does not fit; km does
h2_row(cx("u(0.99996, m)", L), "1.0~m")        # 999.96 mm prints "1,000.0" and does not fit; m does
h2_row(cx("u(0.0004, m)", L), "0.4~mm")
h2_row(cx("u(5e6, m)", L), "5,000~km")
h2_row(cx("u(0, m)", L), "0~mm")
h2_row(cx("u(-1500, m)", L), "\u22121.5~km")

h2_row(cx("u(1500, m)", 'unit="mm | m | km"'), "1.5~km")
h2_row(cx("u(0.05, m)", 'unit="mm|cm|m"'), "50~mm")
h2_row(cx("u(0.05, m)", 'unit="cm|mm|m"'), "5~cm")
h2_row(cx("u(5, m)", 'unit="mm|km"'), "5,000~mm")
h2_row(cx("u(150, cm)", 'unit="m"'), "1.5~m")
h2_row(cx("u(0.002, mg/L)", 'unit="ug/L|mg/L"'), "2~ug/L")
h2_row(cx("u(5, mg/L)", 'unit="ug/L|mg/L"'), "5~mg/L")
h2_row(cx("u(0.002, mg/L)", '.uname unit="ug/L|mg/L"'), "2~micrograms per litre")
h2_row(cx("u(0.002, ppm)", 'unit="ppm|ppb"'), "2~ppb")
h2_row(cx("u(0.002, ppm)", '.uname unit="ppm|ppb"'), "2~parts per billion")
h2_row(cx("u(1000, m)", paste(".uname", L)), "1~kilometre")
h2_row(cx("u(2500, m)", paste(".uname", L)), "2.5~kilometres")
h2_row(cx("u(3000, m)", '.word unit="m|km"'), "three~kilometres")
h2_row(cx("u(0, m)", '.no unit="mm|m"'), "no~millimetres")
h2_row(cx("u(1234.5, m)", 'unit="m|km" digits="2"'), "1.23~km")
h2_row(cx("u(999.6, m)", 'unit="m|km" sigfig="2"'), "1.0~km")
h2_row(paste0("[# was | # were]{n=\"u(1000, m)\" ", L, "}"), "1~km was")
h2_row(paste0("[# was | # were]{n=\"u(999, m)\" ", L, "}"), "999~m were")
h2_row("[rose by # | fell by #]{sign=\"u(-0.5, m)\" unit=\"mm|m\"}", "fell by 500~mm")
h2_row("[none | # was | # were]{list=\"u(c(1500, 2500), m)\" unit=\"m|km\"}", "1.5 and 2.5~km were")
h2_row(cx("u(c(3, 50, 800, 2500), m)", '.and unit="m|km"'), "3, 50, 800 and 2,500~m")
h2_row(cx("u(c(500, 2000), m)", '.and unit="km|m"'), "0.5 and 2~km")              # a tie: the earlier rung
h2_row(cx("u(c(0.5, 2), m)", paste(".range", L)), "500\u20132,000~mm")
h2_row(cx("u(c(0.5, 0.8), m)", '.range unit="mm|m"'), "500\u2013800~mm")
h2_row(cx("u(c(1500, 2500, 300, 400), m)", '.and trunc="2" unit="m|km"'), "1,500, 2,500~m and 2 others")
h2_row(cx("u(c(a = 0.4, b = 2), km)", '.pairs unit="m|km"'), "a (400~m) and b (2,000~m)")
h2_row(cx("u(c(0.5, 0.7), km)", 'unit="m|km"'), "500~m, 700~m")
h2_row(cx("u(c(0, 0), m)", '.and unit="mm|m"'), "0 and 0~mm")

h2_row(paste0(cx("u(1500, m)", '#d unit="m|km"'), " then [#]{n=\"#d\"}"), "1.5~km then 1.5~km")
h2_row(paste0(cx("u(1500, m)", '#d unit="m|km"'), " then [#]{n=\"#d\" .uname}"), "1.5~km then 1.5~kilometres")
h2_row(paste0(cx("u(1500, m)", '#d unit="m|km"'), " then [#]{n=\"#d\" unit=\"m\"}"), "1.5~km then 1,500~m")

h2_row(cx("u(100, km/h)", 'unit="mph|km/h"'), "62.1~mph")
h2_row_err(cx("u(100, km/h)", 'unit="mph|km/h"'), has = c("unit = mph|km/h", "rung", "mph"), yml = "unit_defaults: si")
h2_row_err(cx("u(2, Sv)", 'unit="mSv|Sv|Gy"'), has = c("unit = mSv|Sv|Gy", "rung", "Gy"))                       # twins, though Sv would be picked
h2_row_err(cx("u(5, m)", 'unit="mm|kg"'), has = c("unit = mm|kg", "rung", "kg"))
h2_row_err(cx("u(5, m)", 'unit="m|1/m"'), has = c("unit = m|1/m", "rung", "1/m"))
h2_row_err(cx("u(5, t)", 'unit="kg|mt"'), has = c("unit = kg|mt", "rung", "mt"))                            # refused (4.4.20)
h2_row_err(cx("u(5, m)", 'unit="m|metre"'), has = c("unit = m|metre", "same size", "metre"))
h2_row_err(cx("u(5, m)", 'unit="m|m"'), class = "weft_construct_error")
h2_row_err(cx("u(5, m)", 'unit="mm||km"'), class = "weft_construct_error")

# ---- the functions: unit = as a string, a character vector, with a ladder ---------------------------------------

test_that("2h 3.4.4: fmt_num() takes a ladder as a string and as a character vector", {
  h2_restore()
  x <- u(1500, m)
  expect_equal(f2_tx(fmt_num(x, unit = "m|km")), f2("1.5~km"))
  expect_equal(f2_tx(fmt_num(x, unit = c("mm", "m", "km"))), f2("1.5~km"))
  expect_equal(f2_tx(fmt_num(x, unit = "mm | m | km")), f2("1.5~km"))
  expect_equal(f2_tx(fmt_num(x, unit = c("mm", "m", "km"))), f2_tx(fmt_num(x, unit = "mm|m|km")))
})

test_that("2h 3.4.4: the units attribute holds the picked rung", {
  h2_restore()
  r <- fmt_num(u(1500, m), unit = "m|km")
  expect_equal(as.character(attr(r, "units")), "km")
  expect_equal(attr(r, "unit"), "km")
  r2 <- fmt_num(u(250, m), unit = "m|km")
  expect_equal(as.character(attr(r2, "units")), "m")
  expect_equal(attr(r2, "unit"), "m")
})

test_that("2h 3.4.4: fmt_range(), fmt_num() on a vector and glue_vec() take the vector rule", {
  h2_restore()
  expect_equal(f2_tx(fmt_range(u(c(0.5, 2), m), unit = "mm|m|km")), f2("500\u20132,000~mm"))
  expect_equal(f2_tx(fmt_num(u(c(0.5, 0.7), km), unit = "m|km")), f2(c("500~m", "700~m")))
  expect_equal(f2_tx(glue_vec(fmt_num(u(c(0.5, 0.7), km), unit = "m|km"))),
               f2_tx(glue_vec(fmt_num(u(c(0.5, 0.7), km), unit = "m"))))
})

test_that("2h L2: a one-item vector is the rung, as today (control)", {
  h2_restore()
  expect_equal(f2_tx(fmt_num(u(150, cm), unit = c("m"))), f2("1.5~m"))
  expect_equal(f2_tx(fmt_num(u(150, cm), unit = "m")), f2("1.5~m"))
})

# ---- the choice rule, L6-L12 ----------------------------------------------------------------------------------------

test_that("2h L7: a number fits a rung from 1 up to, not including, 1,000 (the window's edges)", {
  h2_restore()
  expect_equal(h2_ws(cx("u(1, m)", 'unit="m|km"')), f2("1~m"))
  expect_equal(h2_ws(cx("u(999, m)", 'unit="m|km"')), f2("999~m"))
  expect_equal(h2_ws(cx("u(999.9, m)", 'unit="m|km"')), f2("999.9~m"))
  expect_equal(h2_ws(cx("u(1000, m)", 'unit="m|km"')), f2("1~km"))
  expect_equal(h2_ws(cx("u(0.9, m)", 'unit="m|mm"')), f2("900~mm"))
  expect_equal(h2_ws(cx("u(1, m)", 'unit="m|mm"')), f2("1~m"))
})

test_that("2h L6: the number tested is the number as printed, so it rounds into the next rung", {
  h2_restore()
  # 999.96 m prints "1,000.0", not 999.96: it goes to km, and is never printed "1,000.0 m"
  expect_equal(h2_ws(cx("u(999.96, m)", 'unit="m|km"')), f2("1.0~km"))
  # digits and sigfig change what is printed, so they change the pick
  expect_equal(h2_ws(cx("u(999.6, m)", 'unit="m|km" digits="0"')), f2("1~km"))
  expect_equal(h2_ws(cx("u(999.96, m)", 'unit="m|km" digits="2"')), f2("999.96~m"))
  expect_equal(h2_ws(cx("u(999.996, m)", 'unit="m|km" digits="2"')), f2("1.00~km"))
  expect_equal(h2_ws(cx("u(999.6, m)", 'unit="m|km" sigfig="2"')), f2("1.0~km"))
  expect_equal(h2_ws(cx("u(994, m)", 'unit="m|km" sigfig="2"')), f2("990~m"))
  expect_false(grepl("1,000", h2_ws(cx("u(999.96, m)", 'unit="m|km"')), fixed = TRUE))
})

test_that("2h L8: a number that fits no rung takes the rung whose number is nearest the window", {
  h2_restore()
  expect_equal(h2_ws(cx("u(0.5, m)", 'unit="m|km"')), f2("0.5~m"))          # too small: the smallest unit
  expect_equal(h2_ws(cx("u(5000, m)", 'unit="mm|m"')), f2("5,000~m"))       # too large: the largest unit
  expect_equal(h2_ws(cx("u(2e7, m)", 'unit="m|km"')), f2("20,000~km"))
  expect_equal(h2_ws(cx("u(0.0004, m)", 'unit="mm|m"')), f2("0.4~mm"))
  expect_equal(h2_ws(cx("u(5, m)", 'unit="mm|km"')), f2("5,000~mm"))        # a gap: 5000 is nearer than 0.005
  expect_equal(h2_ws(cx("u(5000, m)", 'unit="km|mm"')), f2("5~km"))
})

test_that("2h L8: no fit is judged the same way for a descending ladder", {
  h2_restore()
  expect_equal(h2_ws(cx("u(5000, m)", 'unit="km|m|mm"')), f2("5~km"))
  expect_equal(h2_ws(cx("u(0.0004, m)", 'unit="km|m|mm"')), f2("0.4~mm"))
})

test_that("2h L8: zero takes the first rung, whatever its order", {
  h2_restore()
  expect_equal(h2_ws(cx("u(0, m)", 'unit="mm|m|km"')), f2("0~mm"))
  expect_equal(h2_ws(cx("u(0, m)", 'unit="km|m|mm"')), f2("0~km"))
  expect_equal(h2_ws(cx("u(0, m)", '.uname unit="km|m"')), f2("0~kilometres"))
  expect_equal(h2_ws(cx("u(0, m)", '.no unit="km|m"')), f2("no~kilometres"))
  expect_no_warning(h2_ws(cx("u(0, m)", 'unit="km|m"')))                         # an exact zero is not the zero rule
})

test_that("2h L3: the order is the author's preference, not sorted", {
  h2_restore()
  expect_equal(h2_ws(cx("u(0.05, m)", 'unit="mm|cm|m"')), f2("50~mm"))
  expect_equal(h2_ws(cx("u(0.05, m)", 'unit="cm|mm|m"')), f2("5~cm"))
  expect_equal(h2_ws(cx("u(2500, m)", 'unit="km|m"')), f2("2.5~km"))
  expect_equal(h2_ws(cx("u(250, m)", 'unit="km|m"')), f2("250~m"))
  expect_equal(h2_ws(cx("u(1500, m)", 'unit="km|m"')), f2("1.5~km"))             # the first rung that fits
})

test_that("2h L12: a negative number is judged by its magnitude, and so is a sign governor", {
  h2_restore()
  expect_equal(h2_ws(cx("u(-1500, m)", L)), f2("\u22121.5~km"))
  expect_equal(h2_ws(cx("u(-0.25, m)", L)), f2("\u2212250~mm"))
  expect_equal(h2_ws(cx("u(-999, m)", 'unit="m|km"')), f2("\u2212999~m"))
  expect_equal(h2_ws("[rose by # | fell by #]{sign=\"u(-0.5, m)\" unit=\"mm|m\"}"), f2("fell by 500~mm"))
  expect_equal(h2_ws("[rose by # | fell by #]{sign=\"u(0.5, m)\" unit=\"mm|m\"}"), f2("rose by 500~mm"))
  expect_equal(h2_ws("[rose by # | fell by #]{sign=\"u(-2500, m)\" unit=\"m|km\"}"), f2("fell by 2.5~km"))
})

test_that("2h L9: a vector takes the rung where the most of its numbers fit, ties to the earlier rung", {
  h2_restore()
  expect_equal(h2_ws(cx("u(c(3, 50, 800, 2500), m)", '.and unit="m|km"')), f2("3, 50, 800 and 2,500~m"))
  expect_equal(h2_ws(cx("u(c(500, 2000), m)", '.and unit="km|m"')), f2("0.5 and 2~km"))
  expect_equal(h2_ws(cx("u(c(500, 2000), m)", '.and unit="m|km"')), f2("500 and 2,000~m"))
  expect_equal(h2_ws(cx("u(c(0.5, 2), m)", '.range unit="mm|m|km"')), f2("500\u20132,000~mm"))
  expect_equal(h2_ws(cx("u(c(0.5, 2), m)", '.range unit="m|mm"')), f2("0.5\u20132.0~m"))     # the tie, the earlier rung
  # three of four fit km: the majority wins over the largest value and the first rung
  expect_equal(h2_ws(cx("u(c(1500, 2500, 3500, 400), m)", '.and unit="m|km"')), f2("1.5, 2.5, 3.5 and 0.4~km"))
})

test_that("2h L9: with no fit in any rung, the largest absolute value decides alone by the one-number rule", {
  h2_restore()
  expect_equal(h2_ws(cx("u(c(2e7, 5e7), m)", '.and unit="m|km"')), f2("20,000 and 50,000~km"))
  expect_equal(h2_ws(cx("u(c(0.003, 0.004), m)", '.and unit="m|km" digits="3"')), f2("0.003 and 0.004~m"))
})

test_that("2h L9: negatives count by their magnitude in a vector", {
  h2_restore()
  expect_equal(h2_ws(cx("u(c(-1500, -2500, 300), m)", '.and unit="m|km"')), f2("\u22121.5, \u22122.5 and 0.3~km"))
})

test_that("2h L10: trunc hides elements from the print, not from the pick", {
  h2_restore()
  # m and km each fit two of the four, so the tie goes to m; had the hidden pair not counted, km would win
  expect_equal(h2_ws(cx("u(c(1500, 2500, 300, 400), m)", '.and trunc="2" unit="m|km"')), f2("1,500, 2,500~m and 2 others"))
  expect_equal(h2_ws(cx("u(c(1500, 2500, 3, 4, 5), m)", '.and trunc="2" unit="m|km"')), f2("1,500, 2,500~m and 3 others"))
})

test_that("2h L9: the vector rule holds for .or, .range, .pairs, the list classes and an uncollapsed vector", {
  h2_restore()
  expect_equal(h2_ws(cx("u(c(3, 50, 800, 2500), m)", '.or unit="m|km"')), f2("3, 50, 800 or 2,500~m"))
  expect_equal(h2_ws(cx("u(c(0.5, 0.8), m)", '.range unit="mm|m"')), f2("500\u2013800~mm"))
  expect_equal(h2_ws(cx("u(c(a = 0.4, b = 2), km)", '.pairs unit="m|km"')), f2("a (400~m) and b (2,000~m)"))
  expect_equal(h2_ws(cx("u(c(0.5, 0.7), km)", 'unit="m|km"')), f2("500~m, 700~m"))
  for (cls in c(".ul", ".ol", ".count", ".word")) {       # whole numbers, so every class can print them
    expect_equal(h2_ws(cx("u(c(3, 50), m)", paste(cls, 'unit="m|km"'))),
                 h2_ws(cx("u(c(3, 50), m)", paste(cls, 'unit="m"'))), label = cls)
    expect_equal(h2_ws(cx("u(c(2000, 3000), m)", paste(cls, 'unit="m|km"'))),
                 h2_ws(cx("u(c(2, 3), km)", paste(cls, 'unit="km"'))), label = cls)
  }
  for (cls in c(".ul", ".ol")) {
    expect_equal(h2_ws(cx("u(c(2500, 3500), m)", paste(cls, 'unit="m|km"'))),
                 h2_ws(cx("u(c(2.5, 3.5), km)", paste(cls, 'unit="km"'))), label = cls)
  }
})

test_that("2h L9: the # of a list span takes the rung by the vector rule", {
  h2_restore()
  expect_equal(h2_ws("[none | # was | # were]{list=\"u(c(3, 50, 800, 2500), m)\" unit=\"m|km\"}"), f2("3, 50, 800 and 2,500~m were"))
  expect_equal(h2_ws("[none | # was | # were]{list=\"u(c(1500, 2500), m)\" unit=\"m|km\"}"), f2("1.5 and 2.5~km were"))
})

test_that("2h L11: NA is ignored in picking, and fmt_unit() shows it; a vector with nothing to test takes the first rung", {
  h2_restore()
  expect_equal(f2_tx(fmt_unit(u(c(NA, 1500), m), unit = "m|km")), "km")
  expect_equal(f2_tx(fmt_unit(u(c(NA_real_, NA_real_), m), unit = "km|m")), "km")
  expect_equal(f2_tx(fmt_unit(u(numeric(0), m), unit = "km|m")), "km")
  expect_equal(f2_tx(fmt_unit(u(numeric(0), m), unit = "m|km")), "m")
})

test_that("2h L11: a formatter given NA is the no-value failure of 4.4.13, with a ladder as without one", {
  h2_restore()
  e1 <- f2_err(cx("u(NA_real_, m)", '.num unit="m"'))
  e2 <- f2_err(cx("u(NA_real_, m)", '.num unit="m|km"'))
  expect_false(is.null(e1))
  expect_false(is.null(e2))
  expect_equal(class(e2), class(e1))
  expect_equal(f2_msg(e2), f2_msg(e1))
})

# ---- names, plurals, forms (4.4.16, 4.4.22) -------------------------------------------------------------------------

test_that("2h 4.4.23: names and plurals are those of the picked rung", {
  h2_restore()
  expect_equal(h2_ws(cx("u(1000, m)", paste(".uname", L))), f2("1~kilometre"))
  expect_equal(h2_ws(cx("u(2500, m)", paste(".uname", L))), f2("2.5~kilometres"))
  expect_equal(h2_ws(cx("u(1, m)", paste(".uname", L))), f2("1~metre"))
  expect_equal(h2_ws(cx("u(250, m)", paste(".uname", L))), f2("250~metres"))
  expect_equal(h2_ws(cx("u(0.25, m)", paste(".uname", L))), f2("250~millimetres"))
  expect_equal(h2_ws(cx("u(3000, m)", '.word unit="m|km"')), f2("three~kilometres"))
  expect_equal(h2_ws(cx("u(2, m)", '.word unit="mm|m|km"')), f2("two~metres"))
})

test_that("2h 4.4.23: .usym and .nounit act on the picked rung", {
  h2_restore()
  expect_equal(h2_ws(cx("u(1500, m)", paste(".nounit", L))), "1.5")
  expect_equal(h2_ws(cx("u(1500, m)", paste(".usym", L))), f2("1.5~km"))
  expect_equal(h2_ws(cx("u(1500, m)", paste(".uname", L))), f2("1.5~kilometres"))
})

test_that("2h 4.4.23: the unit_form setting acts on the picked rung", {
  h2_restore()
  expect_equal(h2_ws(cx("u(1500, m)", L), "unit_form: name"), f2("1.5~kilometres"))
  expect_equal(h2_ws(cx("u(1500, m)", L), "unit_form: symbol"), f2("1.5~km"))
})

test_that("2h 4.4.23: the picked rung prints as unit=<rung> would (symbol as typed, compound, default and project units)", {
  h2_restore()
  for (case in list(list("u(0.002, mg/L)", "ug/L|mg/L", "ug/L"), list("u(5, mg/L)", "ug/L|mg/L", "mg/L"),
                    list("u(0.002, ppm)", "ppm|ppb", "ppb"), list("u(100, km/h)", "mph|km/h", "mph"),
                    list("u(3, nmi)", "m|nmi", "nmi"))) {
    for (cls in c(".num", ".uname")) {
      expect_equal(h2_ws(cx(case[[1]], paste0(cls, ' unit="', case[[2]], '"'))),
                   h2_ws(cx(case[[1]], paste0(cls, ' unit="', case[[3]], '"'))), label = paste(case[[1]], cls))
    }
  }
  # a unit of the project's: picked, with its name and plural
  yml <- c("units:", "  zzh2sp:", "    is: 2 m", "    name: span", "    plural: spans")
  expect_equal(h2_ws(cx("u(1500, m)", 'unit="zzh2sp|km"'), yml), f2("750~zzh2sp"))
  expect_equal(h2_ws(cx("u(1500, m)", '.uname unit="zzh2sp|km"'), yml), f2("750~spans"))
  expect_equal(h2_ws(cx("u(3, m)", '.uname unit="m|zzh2sp"'), yml), f2("3~metres"))
  expect_equal(h2_ws(cx("u(3000, m)", '.uname unit="m|zzh2sp"'), yml), f2("1,500~spans"))
})

test_that("2h 4.4.23: a unit written before the number is a rung like any other", {
  h2_restore()
  yml <- c("units:", "  zzh2bf:", "    is: 1000 m", "    before: true")
  got <- h2_ws(cx("u(2500, m)", 'unit="m|zzh2bf"'), yml)
  expect_equal(got, h2_ws(cx("u(2500, m)", 'unit="zzh2bf"'), yml))
  expect_true(startsWith(got, "zzh2bf"))
  expect_equal(h2_ws(cx("u(250, m)", 'unit="m|zzh2bf"'), yml), f2("250~m"))
})

test_that("2h 4.4.23: a ladder is read in the unit_defaults mode in force (mph is a milliphot under si)", {
  h2_restore()
  expect_equal(h2_ws(cx("u(100, km/h)", 'unit="mph|km/h"')), f2("62.1~mph"))
  e <- f2_err(cx("u(100, km/h)", 'unit="mph|km/h"'), "unit_defaults: si")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "mph")
})

# ---- n, #, arms, back-references -------------------------------------------------------------------------------------

test_that("2h 4.4.9: arm selection follows the number printed in the picked rung", {
  h2_restore()
  expect_equal(h2_ws(paste0("[# was | # were]{n=\"u(1000, m)\" ", L, "}")), f2("1~km was"))
  expect_equal(h2_ws(paste0("[# was | # were]{n=\"u(999, m)\" ", L, "}")), f2("999~m were"))
  expect_equal(h2_ws(paste0("[# was | # were]{n=\"u(1500, m)\" ", L, "}")), f2("1.5~km were"))
  expect_equal(h2_ws(paste0("[# was | # were]{n=\"u(0.001, m)\" ", L, "}")), f2("1~mm was"))
  expect_equal(h2_ws(paste0("[none | # was | # were]{n=\"u(0, m)\" ", L, "}")), f2("none"))
})

test_that("2h 4.4.9: # carries the picked rung through n, sign and list spans", {
  h2_restore()
  expect_equal(h2_ws("[# was | # were]{n=\"u(1000, m)\" unit=\"m|km\"}"), f2("1~km was"))
  expect_equal(h2_ws("[rose by # | fell by #]{sign=\"u(-0.5, m)\" unit=\"mm|m\"}"), f2("fell by 500~mm"))
  expect_equal(h2_ws("[rose by # | fell by # | level]{sign=\"u(0, m)\" unit=\"mm|m\"}"), f2("level"))
})

test_that("2h 4.4.23: n=\".\" inherits the governor as printed, in the picked rung", {
  h2_restore()
  expect_equal(h2_ws("[[# m | # ms]{n=\".\"}]{n=\"u(1000, m)\" unit=\"m|km\"}"), f2("1~km m"))
  expect_equal(h2_ws("[[# m | # ms]{n=\".\"}]{n=\"u(2500, m)\" unit=\"m|km\"}"), f2("2.5~km ms"))
  expect_equal(h2_ws("[[# m | # ms]{n=\".\"}]{n=\"u(999, m)\" unit=\"m|km\"}"), f2("999~m ms"))
})

test_that("2h L15: a back-reference prints what the value printed, in the picked rung", {
  h2_restore()
  src <- function(second) paste0(cx("u(1500, m)", '#d unit="m|km"'), " then ", second)
  expect_equal(h2_ws(src("[#]{n=\"#d\"}")), f2("1.5~km then 1.5~km"))
  expect_equal(h2_ws(src("[# was | # were]{n=\"#d\"}")), f2("1.5~km then 1.5~km were"))
  expect_equal(h2_ws(src("[#]{n=\"#d\" .uname}")), f2("1.5~km then 1.5~kilometres"))
  expect_equal(h2_ws(src("[#]{n=\"#d\" digits=\"2\"}")), f2("1.5~km then 1.50~km"))
  expect_equal(h2_ws(src("[#]{n=\"#d\" unit=\"m\"}")), f2("1.5~km then 1,500~m"))
  expect_equal(h2_ws(src("[#]{n=\"#d\" unit=\"mm|m|km\"}")), f2("1.5~km then 1.5~km"))
  expect_equal(h2_ws(src("[#]{n=\"#d\" unit=\"mm|m\"}")), f2("1.5~km then 1,500~m"))
  # a value the other way: the id holds the quantity in the rung it printed in
  expect_equal(h2_ws(paste0(cx("u(250, m)", '#e unit="mm|m|km"'), " then [#]{n=\"#e\" .uname}")), f2("250~m then 250~metres"))
  expect_equal(h2_ws(paste0(cx("u(0.25, m)", '#e unit="mm|m|km"'), " then [#]{n=\"#e\" .uname}")), f2("250~mm then 250~millimetres"))
})

# ---- the zero rule (4.4.13) -------------------------------------------------------------------------------------------

test_that("2h L16: a ladder prints 0.0 only when every rung prints zero, takes the first rung, and warns once", {
  h2_restore()
  r <- h2_warns(h2_ws(cx("u(0.04, m)", 'unit="m|km"')))
  expect_equal(r$v, f2("0.0~m"))
  expect_length(r$w, 1L)
  expect_match(r$w, "printed as 0.0", fixed = TRUE)
})

test_that("2h L16: the advice names the ladder with the prefixed unit put first when the first rung is one SI token", {
  h2_restore()
  r <- h2_warns(h2_ws(cx("u(0.04, m)", 'unit="m|km"')))
  expect_length(r$w, 1L)
  expect_true(grepl('unit="mm|m|km"', r$w, fixed = TRUE), label = r$w)
  expect_match(r$w, "digits", fixed = TRUE)
  expect_match(r$w, "sigfig", fixed = TRUE)
  r2 <- h2_warns(h2_ws(cx("u(0.002, g)", 'unit="g|kg"')))
  expect_equal(r2$v, f2("0.0~g"))
  expect_true(grepl('unit="mg|g|kg"', r2$w, fixed = TRUE), label = r2$w)
})

test_that("2h L16: the same through the function (an R warning, not a knit's record)", {
  h2_restore()
  r <- h2_warns(fmt_num(u(0.04, m), unit = "m|km"))
  expect_equal(f2_tx(r$v), f2("0.0~m"))
  expect_length(r$w, 1L)
  expect_true(grepl('unit="mm|m|km"', r$w, fixed = TRUE), label = r$w)
})

test_that("2h L16: for a compound first rung the advice names digits and sigfig only", {
  h2_restore()
  r <- h2_warns(h2_ws(cx("u(0.001, mg/L)", 'unit="mg/L|g/L"')))
  expect_equal(r$v, f2("0.0~mg/L"))
  expect_length(r$w, 1L)
  expect_match(r$w, "digits", fixed = TRUE)
  expect_match(r$w, "sigfig", fixed = TRUE)
  expect_false(grepl("unit\\s*=", r$w))
})

test_that("2h L16: for a vector whose picked rung prints only some elements as zero the advice names digits and sigfig only", {
  h2_restore()
  r <- h2_warns(h2_ws(cx("u(c(0.0001, 500), m)", '.and unit="m|km"')))
  expect_equal(r$v, f2("0.0 and 500~m"))
  expect_length(r$w, 1L)
  expect_match(r$w, "digits", fixed = TRUE)
  expect_match(r$w, "sigfig", fixed = TRUE)
  expect_false(grepl("unit\\s*=", r$w))
})

test_that("2h L16: digits or sigfig silence it as before", {
  h2_restore()
  r <- h2_warns(h2_ws(cx("u(0.04, m)", 'unit="m|km" digits="2"')))
  expect_equal(r$v, f2("0.04~m"))
  expect_length(r$w, 0L)
  r2 <- h2_warns(h2_ws(cx("u(0.04, m)", 'unit="m|km" sigfig="1"')))
  expect_equal(r2$v, f2("0.04~m"))
  expect_length(r2$w, 0L)
  expect_no_warning(fmt_num(u(0.04, m), unit = "m|km", digits = 2))
})

test_that("2h L16: a rung that prints a non-zero number is nearer, so there is no zero and no warning", {
  h2_restore()
  r <- h2_warns(h2_ws(cx("u(0.04, m)", 'unit="m|mm"')))
  expect_equal(r$v, f2("40~mm"))
  expect_length(r$w, 0L)
  r2 <- h2_warns(h2_ws(cx("u(0.04, m)", 'unit="m|km|mm"')))
  expect_equal(r2$v, f2("40~mm"))
  expect_length(r2$w, 0L)
})

test_that("2h L16: control - a single unit warns as 2g has it, naming the prefixed unit", {
  h2_restore()
  r <- h2_warns(fmt_num(u(0.001, m)))
  expect_equal(f2_tx(r$v), f2("0.0~m"))
  expect_length(r$w, 1L)
  expect_match(r$w, "unit\\s*=\\s*\"mm\"")
})

# ---- fmt_unit() (3.4.9, L18) -------------------------------------------------------------------------------------------------

test_that("2h 3.4.9: fmt_unit() with a ladder and a quantity picks as .num would print x", {
  h2_restore()
  x <- u(1500, m)
  expect_equal(f2_tx(fmt_unit(x, unit = "m|km")), "km")
  expect_equal(f2_tx(fmt_unit(x, unit = "m|km", unit_form = "name")), "kilometres")
  expect_equal(f2_tx(fmt_unit(u(1000, m), unit = "m|km", unit_form = "name")), "kilometre")
  expect_equal(f2_tx(fmt_unit(u(250, m), unit = "m|km", unit_form = "name")), "metres")
  expect_equal(f2_tx(fmt_unit(u(c(1500, 2500), m), unit = "m|km", unit_form = "name")), "kilometres")
  expect_equal(f2_tx(fmt_unit(u(c(NA, 1500), m), unit = "m|km")), "km")
  expect_equal(f2_tx(fmt_unit(u(numeric(0), m), unit = "km|m")), "km")
  expect_equal(f2_tx(fmt_unit(x, unit = c("m", "km"))), "km")
})

test_that("2h 3.4.9: plural unless x has length one and prints 1", {
  h2_restore()
  expect_equal(f2_tx(fmt_unit(u(1, m), unit = "mm|m|km", unit_form = "name")), "metre")
  expect_equal(f2_tx(fmt_unit(u(c(1000), m), unit = "mm|m|km", unit_form = "name")), "kilometre")
  expect_equal(f2_tx(fmt_unit(u(c(1000, 1000), m), unit = "mm|m|km", unit_form = "name")), "kilometres")
  expect_equal(f2_tx(fmt_unit(u(0, m), unit = "mm|m|km", unit_form = "name")), "millimetres")
})

test_that("2h L18: fmt_unit() of a string with a ladder of more than one rung is a value error", {
  h2_restore()
  e <- f2_cond(fmt_unit("m", unit = "mm|m"))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "fmt_unit(): a ladder picks its unit by the quantity's numbers, and a string has none", "(rule 3.4.9)")
  e2 <- f2_cond(fmt_unit("m", unit = c("mm", "m")))
  f2_has_class(e2, "weft_value_error")
})

test_that("2h L18: control - a string with a ladder of one rung is today's fmt_unit()", {
  h2_restore()
  expect_equal(f2_tx(fmt_unit("m", unit = "cm")), "cm")
  expect_equal(f2_tx(fmt_unit(u(150, cm), unit = "m")), "m")
})

test_that("2h 3.4.9: a heading agrees with its column given the same ladder", {
  h2_restore()
  for (v in list(u(c(0.5, 2), m), u(1500, m), u(c(3, 50, 800, 2500), m), u(0.25, m))) {
    col <- f2_tx(fmt_num(v, unit = "mm|m|km"))
    head <- f2_tx(fmt_unit(v, unit = "mm|m|km"))
    expect_true(all(endsWith(col, f2(paste0("~", head)))), label = paste(col, collapse = ","))
  }
})

# ---- errors from a construct and a function ------------------------------------------------------------------------------

test_that("2h 4.4.23: an empty rung is a weft_construct_error from a construct and a call", {
  h2_restore()
  for (bad in c("mm||km", "m|", "|m", "mm| |km")) {
    e <- f2_err(cx("u(5, m)", paste0('unit="', bad, '"')))
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, "the ladder has an empty rung", "(rule 4.4.23)", paste0("unit = ", bad))
    e2 <- f2_cond(fmt_num(u(5, m), unit = bad))
    f2_has_class(e2, "weft_construct_error")
    f2_msg_has(e2, "the ladder has an empty rung", "(rule 4.4.23)")
  }
  e3 <- f2_cond(fmt_num(u(5, m), unit = c("mm", "", "km")))
  f2_has_class(e3, "weft_construct_error")
  f2_msg_has(e3, "ladder")
  e4 <- f2_err(cx("u(5, m)", 'unit="mm||km"'))
  f2_msg_has(e4, "separate units with `|`")
})

test_that("2h 4.4.23: a rung written twice is a weft_construct_error from a construct and a call", {
  h2_restore()
  e <- f2_err(cx("u(5, m)", 'unit="m|km|m"'))
  f2_has_class(e, "weft_construct_error")
  f2_msg_has(e, "`unit = m|km|m`", "`m` is on the ladder twice", "(rule 4.4.23)")
  for (bad in c("m|m", "m| m", "mm | m | m")) {
    f2_has_class(f2_err(cx("u(5, m)", paste0('unit="', bad, '"'))), "weft_construct_error")
    f2_has_class(f2_cond(fmt_num(u(5, m), unit = bad)), "weft_construct_error")
  }
  f2_has_class(f2_cond(fmt_num(u(5, m), unit = c("m", "km", "m"))), "weft_construct_error")
})

test_that("2h L2: a list item holding | or a blank or NA item is a weft_construct_error from a call", {
  h2_restore()
  for (bad in list(c("mm", "m|km"), c("m", NA_character_), c("m", " "), c("m", ""))) {
    e <- f2_cond(fmt_num(u(5, m), unit = bad))
    f2_has_class(e, "weft_construct_error")
    f2_msg_has(e, "ladder", "(rule 4.4.23)")
  }
})

test_that("2h 4.4.14: every rung is checked, whichever is picked (L4)", {
  h2_restore()
  # km is the rung 1500 m takes; the error is about kg all the same
  e <- f2_err(cx("u(1500, m)", 'unit="km|kg"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "unit = km|kg", "rung", "kg")
  # and the error does not come and go with the data
  for (v in c("u(1, m)", "u(250, m)", "u(0, m)", "u(1e6, m)")) {
    f2_has_class(f2_err(cx(v, 'unit="mm|m|kg"')), "weft_value_error")
  }
})

test_that("2h 4.4.14: a rung that does not parse, does not convert, converts by inversion or is a twin is a value error naming it", {
  h2_restore()
  e <- f2_err(cx("u(5, m)", 'unit="mm|not a unit!!"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "unit = mm|not a unit!!", "rung", "not a unit!!")
  e <- f2_err(cx("u(5, m)", 'unit="mm|kg"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "unit = mm|kg", "rung", "kg")
  e <- f2_err(cx("u(5, m)", 'unit="m|1/m"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "1/m", "(rule 4.4.14)")
  e <- f2_err(cx("u(2, Sv)", 'unit="mSv|Sv|Gy"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "Gy", "(rule 4.4.14)")
  e <- f2_err(cx("u(5, t)", 'unit="kg|mt"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "mt", "(rule 4.4.20)")
})

test_that("2h 4.4.14: the same errors come from the function", {
  h2_restore()
  for (case in list(list(u(5, m), "mm|kg", "kg"), list(u(5, m), "m|1/m", "1/m"), list(u(2, Sv), "mSv|Sv|Gy", "Gy"),
                    list(u(5, t), "kg|mt", "mt"))) {
    e <- f2_cond(fmt_num(case[[1]], unit = case[[2]]))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, "rung", case[[3]])
  }
  e <- f2_cond(fmt_num(u(5, m), unit = c("mm", "kg")))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "kg")
})

test_that("2h L5: two rungs of the same size are a value error naming both", {
  h2_restore()
  e <- f2_err(cx("u(5, m)", 'unit="m|metre"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "`unit = m|metre`: `m` and `metre` are the same size, so `metre` could never be picked; keep one (rule 4.4.23).")
  e2 <- f2_cond(fmt_num(u(5, L), unit = "L|dm^3"))
  f2_has_class(e2, "weft_value_error")
  f2_msg_has(e2, "same size", "dm^3")
  e3 <- f2_cond(fmt_num(u(5, mg/L), unit = "mg/L|g/m^3"))
  f2_has_class(e3, "weft_value_error")
  f2_msg_has(e3, "same size", "g/m^3")
  # not a construct error: the two are written differently
  expect_false(inherits(e, "weft_construct_error"))
})

test_that("2h 4.4.14: unit on a value that is not a quantity is a value error, with a ladder as with one unit", {
  h2_restore()
  f2_has_class(f2_cond(fmt_num(5, unit = "m")), "weft_value_error")
  f2_has_class(f2_cond(fmt_num(5, unit = "m|km")), "weft_value_error")
  f2_has_class(f2_err(cx("5", 'unit="m|km"')), "weft_value_error")
})

# ---- controls: a single unit behaves exactly as before ----------------------------------------------------------------------

test_that("2h control: unit=\"m\" and unit=\"km\" behave as in 2b, 2f and 2g", {
  h2_restore()
  expect_equal(h2_ws(cx("u(150, cm)", '.num unit="m"')), f2("1.5~m"))
  expect_equal(h2_ws(cx("u(1500, m)", 'unit="km"')), f2("1.5~km"))
  expect_equal(h2_ws(cx("u(1500, m)", '.uname unit="km"')), f2("1.5~kilometres"))
  expect_equal(h2_ws(cx("u(60, mph)", '.num unit="km/h"')), f2("96.6~km/h"))
  expect_equal(h2_ws(cx("u(65, Ma)", '.num unit="ka"')), f2("65,000~ka"))
  expect_equal(h2_ws(cx("u(1500, m)", 'unit="mm"')), f2("1,500,000~mm"))     # one unit is never re-picked
  suppressWarnings(expect_equal(h2_ws(cx("u(0.25, m)", 'unit="km"')), f2("0.0~km")))
  expect_equal(h2_ws(paste0(cx("u(150, 'cm')", '#k9 .num unit="m"'), " then [# a | # b]{n=\"#k9\"}")), f2("1.5~m then 1.5~m b"))
  e <- f2_err(cx("u(5, m)", 'unit="kg"'))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "kg")
})

test_that("2h control: a ladder of one on the 2b and 2f unit= rows is the same as the one unit", {
  h2_restore()
  for (case in list(list("u(150, cm)", "m"), list("u(1500, m)", "km"), list("u(2, kBq)", "Bq"), list("u(12, ka)", "yr"),
                    list("u(0.002, mg/L)", "ug/L"))) {
    for (cls in c(".num", ".uname", ".nounit")) {
      one <- h2_ws(cx(case[[1]], paste0(cls, ' unit="', case[[2]], '"')))
      expect_equal(h2_ws(cx(case[[1]], paste0(cls, ' unit="', case[[2]], ' "'))), one, label = paste(case[[1]], cls))
    }
  }
})

test_that("2h control: a ladder of one in a function is the unit, whatever its value", {
  h2_restore()
  expect_equal(f2_tx(fmt_num(u(0.25, m), unit = "km", digits = 4)), f2("0.0003~km"))
  expect_equal(as.character(attr(fmt_num(u(1500, m), unit = "km"), "units")), "km")
  expect_equal(as.character(attr(fmt_num(u(1500, m), unit = c("km")), "units")), "km")
})

# ---- determinism (the rung depends only on the value, ladder and keys) -------------------------------------------------

test_that("2h determinism: the same value and ladder print in the same rung, every time", {
  h2_restore()
  src <- cx("u(1500, m)", 'unit="mm|m|km"')
  first <- h2_ws(src)
  for (i in 1:3) expect_equal(h2_ws(src), first)
  expect_equal(h2_ws(paste(src, src)), f2(paste(c("1.5~km", "1.5~km"), collapse = " ")))
  expect_equal(f2_tx(fmt_num(u(1500, m), unit = "mm|m|km")), f2_tx(fmt_num(u(1500, m), unit = "mm|m|km")))
})

test_that("2h determinism: a value whose numbers change may print in another rung", {
  h2_restore()
  expect_equal(h2_ws(cx("u(999, m)", 'unit="m|km"')), f2("999~m"))
  expect_equal(h2_ws(cx("u(1001, m)", 'unit="m|km"')), f2("1.0~km"))   # 1.001 prints as .num prints it
})

# ---- in a knit: last_knit()$constructs, the table cell, a collected failure, determinism across knits -----------------

LADDER_DOC <- c(
  "A `r x`{unit=\"m|km\"}.",                                                        # 1
  "",
  "B `r x`{unit=\"km\"}.",                                                          # 3
  "",
  "C `r x`{.num}.",                                                                 # 5
  "",
  "D `r x`{unit=\"m|km\"}.",                                                        # 7
  "",
  "| a | b |",                                                                      # 9
  "|---|---|",
  "| `r x`{unit=\"mm\\|m\\|km\"} | [# was \\| # were]{n=\"x\" unit=\"mm\\|m\\|km\"} |",   # 11
  "",
  "E `r z`{unit=\"m|km\"}."                                                         # 13
)

ladder_knit <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- list(a = render_rmd(LADDER_DOC, code = "x <- u(1500, m); z <- u(0.04, m)", in_process = TRUE,
                                    env = c(WEFT_DRAFT = "1")),
                     b = render_rmd(LADDER_DOC, code = "x <- u(1500, m); z <- u(0.04, m)", in_process = TRUE,
                                    env = c(WEFT_DRAFT = "1")))
    }
    cache
  }
})

ladder_line <- function(res, line) {
  cs <- res$knit$constructs
  cs[cs$line == res$offset + line, , drop = FALSE]
}

test_that("2h L17: last_knit()$constructs has unit_picked: the rung printed, as written in the ladder; NA with no unit key", {
  res <- ladder_knit()$a
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the document did not render")
  cs <- res$knit$constructs
  expect_true("unit_picked" %in% names(cs))
  expect_equal(ladder_line(res, 1)$unit_picked, "km")
  expect_equal(ladder_line(res, 3)$unit_picked, "km")                      # a single unit gives itself
  expect_true(all(is.na(ladder_line(res, 5)$unit_picked)))                 # no unit key
  expect_equal(ladder_line(res, 7)$unit_picked, "km")
  expect_true(all(is.na(cs$unit_picked[cs$kind %in% c("text")])))
})

test_that("2h L17: unit_picked is the rung as written, for a rung that is not the last", {
  res <- ladder_knit()$a
  skip_if(res$failed, "the document did not render")
  expect_equal(ladder_line(res, 13)$unit_picked, "m")                      # 0.04 m printed 0.0 in the first rung
})

test_that("2h 1.5.13: in a pipe-table cell \\| in unit is the separator, in a value and in a span", {
  res <- ladder_knit()$a
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the document did not render")
  row <- f2_unesc(res$text[grepl("were", res$text, fixed = TRUE)])   # the table row, as pandoc lays it out
  expect_length(row, 1L)
  expect_true(grepl(f2("1.5~km"), row, fixed = TRUE), label = row)
  expect_true(grepl(f2("1.5~km were"), row, fixed = TRUE), label = row)
  # the table's cells and the unit_picked of both constructs
  cells <- ladder_line(res, 11)
  expect_equal(nrow(cells), 2L)
  expect_equal(cells$unit_picked, c("km", "km"))
})

test_that("2h L5/5.3.2: a value error in a knit is a collected failure naming the rung", {
  res <- f2_render(c("E `r u(5, m)`{unit=\"mm|kg\"} here.", "", "F `r u(5, m)`{.num} fine."))
  skip_if(res$failed, "the document did not render")
  f <- f2_failures(res)
  expect_length(f, 1L)
  expect_true(grepl("kg", f, fixed = TRUE), label = f)
  expect_true(grepl("rung", f, fixed = TRUE), label = f)
})

test_that("2h L17: a construct error in a knit stops it with the weft_construct_error", {
  res <- render_rmd(c("E `r u(5, m)`{unit=\"mm||km\"} here."), in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "empty rung", fixed = TRUE)
})

test_that("2h 4.4.23 zero rule: the warned check is recorded once in a knit and its advice names the ladder", {
  res <- ladder_knit()$a
  skip_if(res$failed, "the document did not render")
  w <- res$knit$warnings
  r <- w[w$line == res$offset + 13, , drop = FALSE]
  expect_equal(NROW(r), 1L)
  txt <- paste(unlist(r), collapse = " ")
  expect_true(grepl('unit="mm|m|km"', txt, fixed = TRUE), label = txt)
})

test_that("2h determinism: one value twice in a document, and across two knits, prints in the same rung", {
  both <- ladder_knit()
  skip_if(both$a$failed || both$b$failed, "the document did not render")
  ta <- f2_unesc(both$a$text)
  tb <- f2_unesc(both$b$text)
  expect_equal(ta, tb)
  expect_true(any(grepl(f2("A 1.5~km."), ta, fixed = TRUE)))
  expect_true(any(grepl(f2("D 1.5~km."), ta, fixed = TRUE)))
})
