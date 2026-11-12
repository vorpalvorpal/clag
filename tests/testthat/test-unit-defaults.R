# Package 2g: weft's default units. Contract: dev/design-2g.md "Expected output", "The default
# table", "Modes", "Registration", "unit_defaults()". Rules 4.4.20, 4.4.21, 3.4.10.
# `~` in an expected string is U+00A0. Non-ASCII is written as \uXXXX.
if (!exists("g2_row")) source(file.path(dirname(Filter(file.exists, c(testthat::test_path("helper-2g.R"), testthat::test_path("..", "helper-2g.R")))[[1]]), "helper-2g.R"))
g2_need()

DASH <- "–"

# ---- the expected-output table, mode weft, no project rows ---------------------------------------------------

g2_row("`r u(7.2, pH)`{.num}", "pH~7.2")
g2_row("`r u(7.2, pH)`{.uname}", "pH~7.2")
g2_row("`r u(7.2, pH)`{.nounit}", "7.2")
g2_row("`r u(7, pH)`{.word}", "pH~seven")
g2_row("`r u(c(6.5, 8.5), pH)`{.range}", paste0("pH~6.5", DASH, "8.5"))
g2_row("`r u(c(6.5, 7.2), pH)`{.and}", "pH~6.5 and 7.2")
g2_row("`r u(c(a = 6.5, b = 7.2), pH)`{.pairs}", "a (pH~6.5) and b (pH~7.2)")
g2_row("[# was | # were]{n=\"u(1, pH)\"}", "pH~1 was")
g2_row("[# was | # were]{n=\"u(7.2, pH)\"}", "pH~7.2 were")   # the contract's row says "was"; see the report
g2_row("`r u(7.2, pH)`{.strong}", "**pH~7.2**")
g2_row("`r u(7.2, pH)`{.num}", "pH7.2", c("units:", "  pH:", "    space: false"))
g2_row("`r u(0.2, pH/h)`{.num}", "0.2~pH/h")
g2_row("`r u(0.2, pH/h)`{.uname}", "0.2~pH per hour")

g2_row("`r u(60, mph)`{.uname}", "60~miles per hour")
g2_row("`r u(1, mph)`{.uname}", "1~mile per hour")
g2_row("`r u(60, mph)`{.num}", "60~mph")
g2_row("`r u(60, mph)`{.num unit=\"km/h\"}", "96.6~km/h")

g2_row("`r u(3, nmi)`{.uname}", "3~nautical miles")
g2_row("`r u(1, nmi)`{.uname}", "1~nautical mile")
g2_row("`r u(3, nmi)`{.num}", "3~nmi")
g2_row("`r u(3, nmi)`{.num unit=\"km\"}", "5.6~km")

g2_row("`r u(65, Ma)`{.uname}", "65~million years")
g2_row("`r u(1, Ma)`{.uname}", "1~million years")
g2_row("`r u(65, Ma)`{.num unit=\"ka\"}", "65,000~ka")
g2_row("`r u(12, ka)`{.num unit=\"yr\"}", "12,000~years")
g2_row("`r u(12, ka)`{.num}", "12~ka")
g2_row("`r u(12, ka)`{.uname}", "12~thousand years")

g2_row("`r u(10, gal)`{.uname}", "10~gallons")
g2_row("`r u(1, gal)`{.uname}", "1~gallon")
g2_row("`r u(10, gal)`{.num}", "10~gal")
g2_row("`r u(10, gal)`{.num unit=\"L\"}", "37.9~L")

g2_row("`r u(5, ppm)`{.word}", "five~parts per million")
g2_row("`r u(1, ppm)`{.uname}", "1~part per million")
g2_row("`r u(5, ppm)`{.num unit=\"ppb\"}", "5,000~ppb")
g2_row("`r u(20, ppb)`{.uname}", "20~parts per billion")

g2_row("`r u(3, NTU)`{.word}", "three~nephelometric turbidity units")
g2_row("`r u(1, NTU)`{.uname}", "1~nephelometric turbidity unit")
g2_row("`r u(35, PSU)`{.uname}", "35~practical salinity units")
g2_row("`r u(40, CFU)`{.uname}", "40~colony-forming units")
g2_row("`r u(40, MPN)`{.num}", "40~MPN")
g2_row_err("`r u(40, MPN)`{.uname}", has = "MPN")
g2_row("`r u(150, \"CFU/100 mL\")`{.num}", "150~CFU/100 mL")
g2_row("`r u(150, \"MPN/100 mL\")`{.num}", "150~MPN/100 mL")
g2_row_err("`r u(150, \"CFU/100 mL\")`{.uname}")

g2_row("`r u(2, Sv)`{.uname}", "2~sieverts")
g2_row("`r u(1500, mSv)`{.num unit=\"Sv\"}", "1.5~Sv")
g2_row("`r u(40, Bq)`{.uname}", "40~becquerels")
g2_row("`r u(2, kBq)`{.num unit=\"Bq\"}", "2,000~Bq")
g2_row("`r u(5, kVA)`{.num}", "5~kVA")
g2_row("`r u(3, Mg)`{.uname}", "3~megagrams")
g2_row("`r u(3, Mg)`{.num unit=\"t\"}", "3~t")
g2_row_err("`r u(2, Sv)`{.num unit=\"Gy\"}")
g2_row_err("`r u(2, Bq/L)`{.num unit=\"Hz/L\"}")
g2_row("`r u(2, Gy)`{.num}", "2~Gy")          # control: the unit it was once read as
g2_row("`r u(5, Hz)`{.num}", "5~Hz")          # control

test_that("2g 4.4.20 table (weft): mt, kph, Ga, kmph and kNTU are a weft_unit_error from u()", {
  g2_restore()
  for (tok in c("mt", "kph", "Ga", "kmph", "kNTU")) {
    e <- f2_cond(g2_u(5, tok))
    f2_has_class(e, "weft_unit_error")
    f2_msg_has(e, tok)
  }
})

# ---- the table, mode si -------------------------------------------------------------------------------------

SI <- "unit_defaults: si"
g2_row("`r u(7.2, pH)`{.num}", "7.2~pH", SI, "si")
g2_row("`r u(7.2, pH)`{.uname}", "7.2~picohenries", SI, "si")
g2_row("`r u(60, mph)`{.uname}", "60~milliphots", SI, "si")
g2_row("`r u(65, Ma)`{.uname}", "65~megaares", SI, "si")
g2_row("`r u(3, nmi)`{.uname}", "3~nanomiles", SI, "si")
g2_row("`r u(5, gal)`{.uname}", "5~gals", SI, "si")
g2_row("`r u(5, mt)`{.uname}", "5~millitonnes", SI, "si")
g2_row_err("`r u(60, mph)`{.num unit=\"km/h\"}", SI, "si")
g2_row("`r u(5, ppm)`{.uname}", "5~parts per million", SI, "si")
g2_row("`r u(3, NTU)`{.uname}", "3~nephelometric turbidity units", SI, "si")
g2_row("`r u(2, Sv)`{.uname}", "2~sieverts", SI, "si")
g2_row("`r u(7.2, pH)`{.num}", "pH~7.2",
       c(SI, "units:", "  pH:", "    is: base", "    name: pH", "    plural: pH", "    before: true"),
       "si, the pH row copied into units:")

test_that("2g 4.4.20 table (si): the weft refusals do not apply, mt and kph read as units says", {
  g2_cfg(SI)
  expect_no_error(g2_u(5, "mt"))
  expect_no_error(g2_u(5, "kph"))
  expect_no_error(g2_u(1, "Ga"))
})

test_that("2g 4.4.21 table (si): a prefix on a default row with is: in force is still refused (kNTU)", {
  g2_cfg(SI)
  e <- f2_cond(g2_u(1, "kNTU"))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "`kNTU`", "prefix `k`", "(kilo)", "`NTU`", "weft's default table", "(rule 4.4.20)")
})

# ---- the table with project rows ------------------------------------------------------------------------------------

g2_row("`r u(10, gal)`{.num unit=\"L\"}", "45.5~L", c("units:", "  gal:", "    is: 4.54609 L"),
       "weft, units: gal imperial")
g2_row("`r u(10, gal)`{.uname}", "10~gallons", c("units:", "  gal:", "    is: 4.54609 L"),
       "weft, units: gal imperial")
g2_row_err("`r u(7.2, pH)`{.num}", c("units:", "  pH: false"), class = "weft_unit_error")
g2_row("`r u(3, NTU)`{.uname}", "3~turbidity units",
       c("units:", "  NTU:", "    name: turbidity unit"), "weft, units: NTU name")

# ---- unit_defaults() (3.4.10) ---------------------------------------------------------------------------------------------

test_that("2g 3.4.10: unit_defaults() is exported", {
  expect_true("unit_defaults" %in% getNamespaceExports("weft"))
})

test_that("2g 3.4.10: unit_defaults() has the eight columns in order", {
  x <- unit_defaults()
  expect_s3_class(x, "data.frame")
  expect_equal(names(x), c("unit", "is", "name", "plural", "symbol", "space", "before", "redefines"))
})

test_that("2g 3.4.10: unit_defaults() has the fourteen rows in file order", {
  x <- unit_defaults()
  expect_equal(x$unit, c("pH", "mph", "nmi", "Ma", "ka", "gal", "ppm", "ppb", "NTU", "PSU", "CFU", "MPN",
                         "CFU/100 mL", "MPN/100 mL"))
})

test_that("2g 3.4.10: unit_defaults() column types, NA for a blank text and FALSE for a blank before", {
  x <- unit_defaults()
  for (col in c("unit", "is", "name", "plural", "symbol")) expect_type(x[[col]], "character")
  expect_type(x$space, "logical")
  expect_type(x$before, "logical")
  expect_type(x$redefines, "logical")
  expect_true(all(is.na(x$space)))
  expect_false(anyNA(x$before))
  expect_equal(x$before, x$unit == "pH")
  expect_equal(x$symbol, c(rep(NA_character_, 12), "CFU/100 mL", "MPN/100 mL"))
})

test_that("2g 3.4.10: unit_defaults() holds each row's is: and name as the table writes them", {
  x <- unit_defaults()
  row <- function(u) x[x$unit == u, , drop = FALSE]
  expect_equal(row("pH")$is, "base")
  expect_equal(row("mph")$is, "1 mi/h")
  expect_equal(row("nmi")$is, "1852 m")
  expect_equal(row("Ma")$is, "1 Myr")
  expect_equal(row("ka")$is, "1 kyr")
  expect_equal(row("gal")$is, "1 gallon")
  expect_true(is.na(row("ppm")$is))
  expect_true(is.na(row("ppb")$is))
  for (u in c("NTU", "PSU", "CFU", "MPN")) expect_equal(row(u)$is, "base")
  expect_equal(row("pH")$name, "pH")
  expect_equal(row("pH")$plural, "pH")
  expect_equal(row("mph")$name, "mile per hour")
  expect_equal(row("nmi")$name, "nautical mile")
  expect_equal(row("Ma")$plural, "million years")
  expect_equal(row("ka")$plural, "thousand years")
  expect_equal(row("gal")$name, "gallon")
  expect_equal(row("ppm")$name, "part per million")
  expect_equal(row("ppb")$name, "part per billion")
  expect_equal(row("NTU")$name, "nephelometric turbidity unit")
  expect_equal(row("PSU")$name, "practical salinity unit")
  expect_equal(row("CFU")$name, "colony-forming unit")
  expect_true(is.na(row("MPN")$name))
})

test_that("2g 3.4.10: redefines is true for exactly the six rows the units package already parses", {
  x <- unit_defaults()
  expect_type(x$redefines, "logical")
  expect_equal(x$unit[x$redefines], c("pH", "mph", "nmi", "Ma", "ka", "gal"))
  expect_equal(sum(x$redefines), 6L)
})

test_that("2g 3.4.10: attribute file is the YAML path of the table, and it exists", {
  f <- attr(unit_defaults(), "file")
  expect_type(f, "character")
  expect_length(f, 1L)
  expect_true(file.exists(f))
  expect_equal(basename(f), "weft-units.yml")
})

test_that("2g 4.4.21: the table file is inst/weft-units.yml, found by system.file()", {
  expect_true(nzchar(system.file("weft-units.yml", package = "weft")))
})

test_that("2g 4.4.21: the table file is written as a units: block of rows, so it may be copied", {
  y <- yaml::read_yaml(system.file("weft-units.yml", package = "weft"))
  expect_equal(names(y), "units")
  expect_equal(names(y$units)[1:3], c("pH", "mph", "nmi"))
  expect_equal(length(y$units), 14L)
})

test_that("2g 3.4.10: unit_defaults() registers nothing (a fresh session still reads pH as picohenries after it)", {
  out <- g2_child(paste(
    'x <- unit_defaults()',
    'cat("ROWS=", nrow(x), "\\n", sep = "")',
    'cat("PH=", as.numeric(units::set_units(units::set_units(1, "pH", mode = "standard"), "H", mode = "standard")), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(g2_kv(out, "ROWS"), "14")
  expect_equal(as.numeric(g2_kv(out, "PH")), 1e-12)
})

# ---- registration (4.4.21): one session ---------------------------------------------------------------------------

test_that("2g G9: si, weft and si again in one session each read right, outside a knit after each read", {
  g2_cfg(SI)
  expect_equal(g2_nm(u(7.2, pH)), f2("7.2~picohenries"))
  expect_equal(g2_num(u(60, mph)), f2("60~mph"))
  expect_equal(g2_nm(u(60, mph)), f2("60~milliphots"))
  weft:::read_config(f2_proj())
  expect_equal(g2_num(u(7.2, pH)), f2("pH~7.2"))
  expect_equal(g2_nm(u(60, mph)), f2("60~miles per hour"))
  weft:::read_config(f2_proj(SI))
  expect_equal(g2_num(u(7.2, pH)), f2("7.2~pH"))
  expect_equal(g2_nm(u(7.2, pH)), f2("7.2~picohenries"))
})

test_that("2g G9: two documents knit with weft_str() in different modes each see their own", {
  g2_restore()
  expect_equal(f2_ws("`r u(7.2, pH)`{.uname}", SI), f2("7.2~picohenries"))
  expect_equal(f2_ws("`r u(7.2, pH)`{.uname}"), f2("pH~7.2"))
  expect_equal(f2_ws("`r u(7.2, pH)`{.uname}", SI), f2("7.2~picohenries"))
  expect_equal(g2_nm(u(7.2, pH)), f2("7.2~picohenries"))     # outside a knit: the last read
})

test_that("2g G9: a document's own unit_defaults: si applies to its knit, and the next knit is back to weft", {
  g2_restore()
  res <- f2_render(c("`r u(7.2, pH)`{.uname}"), front = c("weft:", "  unit_defaults: si"),
                   format = "knit")
  expect_equal(f2_unesc(res$md), f2("7.2~picohenries"))
  res2 <- f2_render(c("`r u(7.2, pH)`{.uname}"))
  expect_equal(f2_unesc(res2$md), f2("pH~7.2"))
})

test_that("2g G9: a project's _weft.yml unit_defaults: si applies to a render", {
  g2_restore()
  res <- f2_render(c("`r u(60, mph)`{.uname}"), files = list("_weft.yml" = "unit_defaults: si"))
  expect_equal(f2_unesc(res$md), f2("60~milliphots"))
})

test_that("2g 4.4.21: a quantity holds only its token: pH made under weft and printed under si is picohenries", {
  g2_restore()
  weft:::read_config(f2_proj())
  x <- u(7.2, pH)
  expect_equal(g2_num(x), f2("pH~7.2"))
  g2_cfg(SI)
  expect_equal(g2_nm(x), f2("7.2~picohenries"))
  expect_equal(g2_num(x), f2("7.2~pH"))
})

test_that("2g 4.4.21: a second read of the same configuration and a second u() change nothing in the database", {
  g2_cfg(NULL)
  s1 <- g2_sig()
  weft:::read_config(f2_proj())
  u(7.2, pH); u(60, mph)
  s2 <- g2_sig()
  expect_equal(s2, s1)
  weft:::read_config(f2_proj())
  expect_equal(g2_sig(), s1)
  expect_false(all(is.na(s1["mph", ])))                      # the table is in: mph converts
  expect_equal(s1["mph", "mi/h"], 1)
})

test_that("2g 4.4.21: the default rows of weft change what the database says, and si puts it back", {
  g2_cfg(NULL)
  w <- g2_sig()
  expect_equal(w["gal", "L"], 3.785411784, tolerance = 1e-6)    # the US gallon
  expect_true(is.na(w["gal", "m/s^2"]))
  expect_equal(w["mph", "mi/h"], 1)
  expect_equal(w["nmi", "m"], 1852)
  expect_equal(w["Ma", "yr"], 1e6, tolerance = 1e-3)
  expect_equal(w["ka", "yr"], 1e3, tolerance = 1e-3)
  expect_true(is.na(w["pH", "H"]))
  weft:::read_config(f2_proj(SI))
  s <- g2_sig()
  expect_equal(s["gal", "m/s^2"], 0.01)                          # the galileo, restored from the database
  expect_true(is.na(s["gal", "L"]))
  expect_equal(s["pH", "H"], 1e-12)
  expect_false(isTRUE(all.equal(s["nmi", "m"], 1852)))
  expect_false(isTRUE(all.equal(s["mph", "mi/h"], 1)))
})

test_that("2g 4.4.21: a changed definition is removed and reinstalled, and goes back when the row goes", {
  g2_restore()
  weft:::read_config(f2_proj(c("units:", "  gal:", "    is: 4.54609 L")))
  expect_equal(g2_factor("gal", "L"), 4.54609, tolerance = 1e-9)
  weft:::read_config(f2_proj())
  expect_equal(g2_factor("gal", "L"), 3.785411784, tolerance = 1e-6)
  weft:::read_config(f2_proj(c("units:", "  mph:", "    is: 1 km/h")))
  expect_equal(g2_factor("mph", "km/h"), 1, tolerance = 1e-9)
  weft:::read_config(f2_proj())
  expect_equal(g2_factor("mph", "mi/h"), 1, tolerance = 1e-9)
})

test_that("2g 4.4.21: a project token no longer wanted is removed from the database", {
  g2_restore()
  weft:::read_config(f2_proj(c("units:", "  zzg2gone:", "    is: 2 m", "    name: gone")))
  expect_equal(g2_factor("zzg2gone", "m"), 2, tolerance = 1e-9)
  weft:::read_config(f2_proj())
  expect_true(is.na(g2_factor("zzg2gone", "m")))
  f2_has_class(f2_cond(g2_u(1, "zzg2gone")), "weft_unit_error")
})

test_that("2g 4.4.21: a misread-list token a project redefines is restored when the row goes", {
  g2_restore()
  weft:::read_config(f2_proj(c("units:", "  mt:", "    is: 1 t")))
  expect_equal(g2_factor("mt", "kg"), 1000, tolerance = 1e-9)
  expect_equal(g2_num(u(2, mt)), f2("2~mt"))
  weft:::read_config(f2_proj())
  f2_has_class(f2_cond(g2_u(2, "mt")), "weft_unit_error")
  expect_equal(g2_factor("mt", "kg"), 1, tolerance = 1e-9)        # the database's millitonne is back
})

test_that("2g 4.4.21: base registrations are never undone in a session, and false removes only their names", {
  g2_cfg(SI)
  expect_equal(g2_num(u(3, NTU)), f2("3~NTU"))                     # NTU applies in both modes
  weft:::read_config(f2_proj(c("units:", "  NTU: false")))
  expect_equal(g2_num(u(3, NTU)), f2("3~NTU"))                     # still registered
  f2_has_class(f2_cond(g2_nm(u(3, NTU))), "weft_value_error")      # its name is gone
  weft:::read_config(f2_proj())
  expect_equal(g2_nm(u(3, NTU)), f2("3~nephelometric turbidity units"))
})

test_that("2g 4.4.21: a failed read leaves the session at weft with the default rows only", {
  g2_cfg(c(SI, "units:", "  gal:", "    is: 4.54609 L"))
  expect_equal(g2_nm(u(7.2, pH)), f2("7.2~picohenries"))
  e <- f2_cond(weft:::read_config(f2_proj(c("units:", "  zzg2bad:", "    nmae: x"))))
  f2_has_class(e, "weft_config_error")
  expect_equal(g2_num(u(7.2, pH)), f2("pH~7.2"))
  expect_equal(g2_cv(u(10, gal), "L"), f2("37.9~L"))
  f2_has_class(f2_cond(g2_u(1, "zzg2bad")), "weft_unit_error")
})

test_that("2g 4.4.21: a failed read after a project row with is: leaves none of the project's tokens", {
  g2_restore()
  e <- f2_cond(weft:::read_config(f2_proj(c("units:", "  zzg2ok:", "    is: 2 m", "  zzg2no:", "    is: bad bad"))))
  f2_has_class(e, "weft_config_error")
  f2_has_class(f2_cond(g2_u(1, "zzg2ok")), "weft_unit_error")
})

# ---- registration: fresh sessions (skipped on CRAN) ------------------------------------------------------------------

PH_TO_H <- 'as.numeric(units::set_units(units::as_units("pH"), "H", mode = "standard"))'

test_that("2g G8: attaching weft leaves pH convertible to H, and the first u() makes it not", {
  out <- g2_child(paste(
    sprintf('cat("BEFORE=", %s, "\\n", sep = "")', PH_TO_H),
    'x <- u(7.2, pH)',
    'cat("AFTER=", tryCatch(as.character(%s), error = function(e) "error"), "\\n", sep = "")',
    sep = "\n") |> sprintf(PH_TO_H))
  expect_equal(as.numeric(g2_kv(out, "BEFORE")), 1e-12)
  expect_equal(g2_kv(out, "AFTER"), "error")
})

test_that("2g G8: the first parse in a session registers the default table, with no configuration read", {
  out <- g2_child(paste(
    'cat("W=", paste(fmt_num(u(7.2, pH)), collapse = ""), "\\n", sep = "")',
    'cat("N=", as.character(fmt_num(u(3, NTU), unit_form = "name")), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(g2_kv(out, "W"), f2("pH~7.2"))
  expect_equal(g2_kv(out, "N"), f2("3~nephelometric turbidity units"))
})

test_that("2g 4.4.21: a pH installed before weft's first use is accepted", {
  out <- g2_child(paste(
    'units::install_unit("pH")',
    'cat("W=", paste(fmt_num(u(7.2, pH)), collapse = ""), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(g2_kv(out, "W"), f2("pH~7.2"))
})

test_that("2g 4.4.21: an mph installed as 1 mi/h before weft's first use is accepted", {
  out <- g2_child(paste(
    'units::install_unit("mph", "1 mi/h")',
    'cat("W=", paste(fmt_num(u(60, mph)), collapse = ""), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(g2_kv(out, "W"), f2("60~mph"))
})

test_that("2g 4.4.21: an mph installed as 1 km/h is the weft_unit_error, naming the token and the way out", {
  out <- g2_child(paste(
    'units::install_unit("mph", "1 km/h")',
    'e <- tryCatch(u(60, mph), error = function(e) e)',
    'cat("CLASS=", paste(class(e), collapse = ","), "\\n", sep = "")',
    'cat("MSG=", gsub("\\n", " ", conditionMessage(e)), "\\n", sep = "")',
    sep = "\n"))
  expect_match(g2_kv(out, "CLASS"), "weft_unit_error", fixed = TRUE)
  m <- g2_kv(out, "MSG")
  for (p in c("`mph`", "was installed in this session, not by weft", "`1 mi/h`",
              "units::remove_unit(\"mph\")", "unit_defaults: si", "(rule 4.4.21)"))
    expect_true(grepl(p, m, fixed = TRUE), label = sprintf("message holds `%s` (message: %s)", p, m))
})

test_that("2g 4.4.21: weft never removes what it did not install: an mph of someone else's stays under si", {
  out <- g2_child(paste(
    'units::install_unit("mph", "1 mi/h")',
    'invisible(u(60, mph))',
    'weft:::read_config(tempdir())',
    'writeLines("unit_defaults: si", file.path(tempdir(), "_weft.yml"))',
    'weft:::read_config(tempdir())',
    'cat("F=", as.numeric(units::set_units(units::set_units(1, "mph", mode = "standard"), "mi/h", mode = "standard")), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(as.numeric(g2_kv(out, "F")), 1)
})

test_that("2g 4.4.21: unloading weft restores gal, and removes what it installed that is not a base registration", {
  out <- g2_child(paste(
    'invisible(u(10, gal))',
    'f <- function(a, b) tryCatch(as.numeric(units::set_units(units::set_units(1, a, mode = "standard"), b, mode = "standard")), error = function(e) NA)',
    'cat("GAL_L=", f("gal", "L"), "\\n", sep = "")',
    'cat("MPH_MI=", f("mph", "mi/h"), "\\n", sep = "")',
    'pkgload::unload("weft")',
    'cat("GAL_ACC=", f("gal", "m/s^2"), "\\n", sep = "")',
    'cat("MPH_PHOT=", f("mph", "phot"), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(as.numeric(g2_kv(out, "GAL_L")), 3.785411784, tolerance = 1e-6)
  expect_equal(as.numeric(g2_kv(out, "MPH_MI")), 1)
  expect_equal(as.numeric(g2_kv(out, "GAL_ACC")), 0.01)         # the galileo is back
  expect_equal(as.numeric(g2_kv(out, "MPH_PHOT")), 1e-3)         # the milliphot is back
})

test_that("2g 4.4.21: under si no redefining row is registered, so a fresh si session reads the units package's meaning", {
  out <- g2_child(paste(
    'd <- tempfile(); dir.create(d); writeLines("unit_defaults: si", file.path(d, "_weft.yml"))',
    'weft:::read_config(d)',
    'cat("W=", paste(fmt_num(u(7.2, pH), unit_form = "name"), collapse = ""), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(g2_kv(out, "W"), f2("7.2~picohenries"))
})
