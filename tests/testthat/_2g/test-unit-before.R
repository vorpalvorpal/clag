# Package 2g: a unit written before the number (before: true, rule 4.4.22 and the changes to 3.4.4,
# 4.4.3, 4.4.4 and 4.4.8). Contract: dev/design-2g.md "A unit before the number". pH is the
# default table's only row with before: true. `~` in an expected string is U+00A0.
if (!exists("g2_row")) source(file.path(dirname(Filter(file.exists, c(testthat::test_path("helper-2g.R"), testthat::test_path("..", "helper-2g.R")))[[1]]), "helper-2g.R"))
g2_need()

DASH <- "–"
ub <- function(x) attr(x, "unit_before")
chr <- function(x) as.character(unclass(x))
ph <- function(...) u(c(...), pH)

# ---- one value ---------------------------------------------------------------------------------------------------------

test_that("2g 4.4.22: before: true puts the unit before the number, joined by the space", {
  g2_cfg(NULL)
  expect_equal(g2_num(u(7.2, pH)), f2("pH~7.2"))
  expect_equal(g2_nm(u(7.2, pH)), f2("pH~7.2"))
  expect_equal(f2_tx(fmt_word(u(7, pH))), f2("pH~seven"))
})

test_that("2g 4.4.22: fmt_unit() prints pH alone, and the printed record holds the number", {
  g2_cfg(NULL)
  expect_equal(f2_tx(fmt_unit(u(7.2, pH))), "pH")
  expect_equal(attr(fmt_num(u(7.2, pH)), "number"), 7.2)
})

test_that("2g 4.4.22: only the token alone, power 1, goes before; in a compound the unit follows", {
  g2_cfg(NULL)
  expect_equal(g2_num(u(0.2, pH/h)), f2("0.2~pH/h"))
  expect_equal(g2_nm(u(0.2, pH/h)), f2("0.2~pH per hour"))
  expect_equal(g2_num(u(3, pH)), f2("pH~3"))
})

test_that("2g 4.4.22: .nounit prints the number, .strong wraps the unit with it, .cap never changes a symbol", {
  g2_restore()
  expect_equal(f2_ws("`r u(7.2, pH)`{.nounit}"), "7.2")
  expect_equal(f2_ws("`r u(7.2, pH)`{.strong}"), f2("**pH~7.2**"))
  expect_equal(f2_ws("`r u(7.2, pH)`{.cap}"), f2("pH~7.2"))
  expect_equal(f2_tx(fmt_cap(fmt_num(u(7.2, pH)))), f2("pH~7.2"))
  expect_equal(f2_tx(fmt_cap(fmt_num(u(7.2, pH), unit_form = "name"))), f2("pH~7.2"))
})

test_that("2g 4.4.22: space: false removes the space between the symbol and the number", {
  g2_cfg(c("units:", "  pH:", "    space: false"))
  expect_equal(g2_num(u(7.2, pH)), "pH7.2")
  expect_equal(g2_num(u(0.2, pH/h)), f2("0.2~pH/h"))     # a compound keeps its own default
})

test_that("2g 4.4.22: a project row may turn before off again for the default's token (merged per field)", {
  g2_cfg(c("units:", "  pH:", "    before: false"))
  expect_equal(g2_num(u(7.2, pH)), f2("7.2~pH"))
  expect_equal(attr(fmt_num(u(7.2, pH)), "unit_before"), FALSE)
})

test_that("2g 4.4.22: before: true on a project token with a symbol, alone and in a compound", {
  g2_cfg(c("units:", "  zzg2bf:", "    is: base", "    symbol: zq", "    name: quark", "    before: true"))
  expect_equal(g2_num(u(3, zzg2bf)), f2("zq~3"))
  expect_equal(g2_num(u(3, zzg2bf/h)), f2("3~zq/h"))
})

test_that("2g 4.4.22: before: false is the default, a unit follows the number", {
  g2_cfg(c("units:", "  zzg2bg:", "    is: base", "    symbol: zq", "    before: false"))
  expect_equal(g2_num(u(3, zzg2bg)), f2("3~zq"))
  expect_equal(g2_num(u(3, m)), f2("3~m"))
})

# ---- a collapse: once, before the first item printed ----------------------------------------------------------------

test_that("2g 4.4.22: a collapse puts the unit once before the first item (.and, .or, .range)", {
  g2_cfg(NULL)
  expect_equal(f2_tx(fmt_and(fmt_num(ph(6.5, 7.2)))), f2("pH~6.5 and 7.2"))
  expect_equal(f2_tx(fmt_or(fmt_num(ph(6.5, 7.2)))), f2("pH~6.5 or 7.2"))
  expect_equal(f2_tx(fmt_range(ph(6.5, 8.5))), f2(paste0("pH~6.5", DASH, "8.5")))
  expect_equal(f2_tx(fmt_and(fmt_num(ph(6.5, 7.2, 8.1)))), f2("pH~6.5, 7.2 and 8.1"))
})

test_that("2g 4.4.22: the same collapses through weft_str()", {
  g2_restore()
  expect_equal(f2_ws("`r u(c(6.5, 7.2), pH)`{.and}"), f2("pH~6.5 and 7.2"))
  expect_equal(f2_ws("`r u(c(6.5, 7.2), pH)`{.or}"), f2("pH~6.5 or 7.2"))
  expect_equal(f2_ws("`r u(c(6.5, 8.5), pH)`{.range}"), f2(paste0("pH~6.5", DASH, "8.5")))
})

test_that("2g 4.4.22: trunc and glue_vec() put it once before the first item printed", {
  g2_cfg(NULL)
  expect_equal(f2_tx(fmt_and(fmt_num(ph(6.5, 7.2, 8.1)), trunc = 1)), f2("pH~6.5 and 2 others"))
  expect_equal(f2_tx(glue_vec(fmt_num(ph(6.5, 7.2, 8.1)))), f2("pH~6.5, 7.2 and 8.1"))
})

test_that("2g 4.4.22: a collapse of a compound unit follows the numbers as 4.4.3 gives", {
  g2_cfg(NULL)
  expect_equal(f2_tx(fmt_and(fmt_num(u(c(1, 2), pH/h)))), f2("1 and 2~pH/h"))
})

test_that("2g 4.4.22: a collapse of a unit written after the number is as before (control)", {
  g2_cfg(NULL)
  expect_equal(f2_tx(fmt_and(fmt_num(u(c(6.5, 7.2), m)))), f2("6.5 and 7.2~m"))
  expect_equal(f2_tx(fmt_range(u(c(6.5, 8.5), m))), f2(paste0("6.5", DASH, "8.5~m")))
})

# ---- before each element -------------------------------------------------------------------------------------------------

test_that("2g 4.4.22: .pairs puts the unit before each element", {
  g2_cfg(NULL)
  x <- u(c(a = 6.5, b = 7.2), pH)
  expect_equal(f2_tx(fmt_pairs(fmt_num(x))), f2("a (pH~6.5) and b (pH~7.2)"))
  g2_restore()
  expect_equal(f2_ws("`r u(c(a = 6.5, b = 7.2), pH)`{.pairs}"), f2("a (pH~6.5) and b (pH~7.2)"))
})

test_that("2g 4.4.22: an uncollapsed vector and list classes put the unit before each element", {
  g2_cfg(NULL)
  expect_equal(chr(fmt_num(ph(6.5, 7.2))), f2(c("pH~6.5", "pH~7.2")))
  expect_equal(chr(fmt_ul(fmt_num(ph(6.5, 7.2)))), f2("\n- pH~6.5\n- pH~7.2\n"))
  expect_equal(chr(fmt_ol(fmt_num(ph(6.5, 7.2)))), f2("\n1. pH~6.5\n2. pH~7.2\n"))
})

# ---- # carries it ---------------------------------------------------------------------------------------------------------

test_that("2g 4.4.8: # carries the unit before the number, in n= and with a sign span", {
  g2_restore()
  expect_equal(f2_ws("[# was | # were]{n=\"u(1, pH)\"}"), f2("pH~1 was"))
  expect_equal(f2_ws("[# was | # were]{n=\"u(7.2, pH)\"}"), f2("pH~7.2 were"))
  expect_equal(f2_ws("[# was]{n=\"u(7.2, pH)\" .sign}"), f2("[pH~7.2 was]{.sign}"))
})

test_that("2g 4.4.8: # for a unit that follows is as before (control)", {
  g2_restore()
  expect_equal(f2_ws("[# was | # were]{n=\"u(1, m)\"}"), f2("1~m was"))
})

test_that("2g 4.4.4: plural() on a quantity printed with the unit before keeps it", {
  g2_cfg(NULL)
  expect_equal(f2_tx(plural(fmt_num(u(7.2, pH)), "# reading", "# readings")), f2("pH~7.2 readings"))
})

# ---- the attribute ----------------------------------------------------------------------------------------------------------

test_that("2g 3.4.4: unit_before is TRUE for a unit before, as long as the text", {
  g2_cfg(NULL)
  expect_equal(ub(fmt_num(u(7.2, pH))), TRUE)
  expect_equal(ub(fmt_num(ph(6.5, 7.2))), c(TRUE, TRUE))
  expect_equal(ub(fmt_word(u(7, pH))), TRUE)
})

test_that("2g 3.4.4: unit_before is FALSE after the number, and for a compound with pH in it", {
  g2_cfg(NULL)
  expect_equal(ub(fmt_num(u(7.2, m))), FALSE)
  expect_equal(ub(fmt_num(u(c(1, 2), m))), c(FALSE, FALSE))
  expect_equal(ub(fmt_num(u(0.2, pH/h))), FALSE)
})

test_that("2g 3.4.4: unit_before is absent when no element has a unit", {
  g2_cfg(NULL)
  expect_null(ub(fmt_num(7.2)))
  expect_null(ub(fmt_num(c(1, 2))))
  expect_false("unit_before" %in% names(attributes(fmt_num(7.2))))
})

test_that("2g 3.4.4: a collapse gives a text of length one, TRUE for a unit before", {
  g2_cfg(NULL)
  expect_equal(attr(fmt_and(fmt_num(u(c(6.5, 7.2), pH))), "unit_before"), TRUE)
  expect_equal(ub(fmt_range(ph(6.5, 8.5))), TRUE)
  expect_equal(ub(fmt_and(fmt_num(u(c(6.5, 7.2), m)))), FALSE)
})

test_that("2g 3.4.4: unit_before survives a chain of formatters (fmt_cap, fmt_strong, fmt_em)", {
  g2_cfg(NULL)
  x <- fmt_and(fmt_num(ph(6.5, 7.2)))
  expect_equal(ub(fmt_cap(x)), TRUE)
  expect_equal(ub(fmt_strong(x)), TRUE)
  expect_equal(ub(fmt_em(x)), TRUE)
  expect_equal(ub(fmt_strong(fmt_cap(fmt_num(u(7.2, pH))))), TRUE)
})

test_that("2g 3.4.4: unit_before is FALSE, not NA, for a unit after the number in the same chain", {
  g2_cfg(NULL)
  expect_equal(ub(fmt_strong(fmt_num(u(c(1, 2), m)))), c(FALSE, FALSE))
})

test_that("2g 4.4.22: under si a pH row copied into units: with before: true works the same, once", {
  g2_cfg(c(SI <- "unit_defaults: si", "units:", "  pH:", "    is: base", "    name: pH", "    plural: pH",
           "    before: true"))
  expect_equal(f2_tx(fmt_and(fmt_num(ph(6.5, 7.2)))), f2("pH~6.5 and 7.2"))
  expect_equal(ub(fmt_num(u(7.2, pH))), TRUE)
})
