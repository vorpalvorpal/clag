# Package 2g: the configuration fields unit_defaults, is, before and a false row.
# Contract: dev/design-2g.md "Configuration fields", "Errors". Rules 9.1.2, 9.1.5-9.1.7.
# `~` in an expected string is U+00A0.
if (!exists("g2_row")) source(file.path(dirname(Filter(file.exists, c(testthat::test_path("helper-2g.R"), testthat::test_path("..", "helper-2g.R")))[[1]]), "helper-2g.R"))
g2_need()

cfg <- function(dir, front = list()) weft:::read_config(dir, front = front)
SI <- "unit_defaults: si"

# the problems of a units: block in a project, as one error
units_err <- function(lines, env = parent.frame()) g2_cfg_err(c("units:", lines), env = env)

# ---- unit_defaults: ---------------------------------------------------------------------------------------------------

test_that("2g 9.1.5: with no _weft.yml unit_defaults is weft", {
  g2_restore()
  expect_equal(cfg(f2_proj())$unit_defaults, "weft")
})

test_that("2g 9.1.2: _weft.yml sets unit_defaults to weft or si, and it is not an ignored key", {
  g2_restore()
  expect_no_warning(x <- cfg(f2_proj(SI)))
  expect_equal(x$unit_defaults, "si")
  expect_equal(cfg(f2_proj("unit_defaults: weft"))$unit_defaults, "weft")
})

test_that("2g 9.1.1: front matter overrides the project's unit_defaults, and a document may set it", {
  g2_restore()
  d <- f2_proj(SI)
  expect_no_warning(x <- cfg(d, front = list(unit_defaults = "weft")))   # a known setting, not "ignored"
  expect_equal(x$unit_defaults, "weft")
  expect_no_warning(y <- cfg(f2_proj(), front = list(unit_defaults = "si")))
  expect_equal(y$unit_defaults, "si")
  expect_equal(cfg(d)$unit_defaults, "si")
})

test_that("2g 9.1.6: a unit_defaults that is not weft or si is a weft_config_error in the contract's words", {
  g2_restore()
  e <- f2_cond(cfg(f2_proj("unit_defaults: bogus")))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`unit_defaults` must be `weft` or `si`; got `bogus` (rule 9.1.6).")
  for (bad in c("Si", "none", "[weft, si]", "5", "true")) {
    f2_has_class(f2_cond(cfg(f2_proj(paste0("unit_defaults: ", bad)))), "weft_config_error")
  }
  e2 <- f2_cond(cfg(f2_proj(), front = list(unit_defaults = "bogus")))
  f2_has_class(e2, "weft_config_error")
  f2_msg_has(e2, "`unit_defaults` must be `weft` or `si`; got `bogus`")
})

# ---- is: forms ----------------------------------------------------------------------------------------------------------------

test_that("2g 9.1.7: is: base registers a unit of its own, with no conversion to anything", {
  g2_cfg(c("units:", "  zzg2bs:", "    is: base", "    name: widget"))
  expect_equal(g2_num(g2_u(2, "zzg2bs")), f2("2~zzg2bs"))
  expect_equal(g2_nm(g2_u(2, "zzg2bs")), f2("2~widgets"))
  f2_has_class(f2_cond(g2_cv(g2_u(2, "zzg2bs"), "m")), "weft_value_error")
  expect_equal(g2_cv(g2_u(2, "zzg2bs"), "zzg2bs"), f2("2~zzg2bs"))
})

test_that("2g 9.1.7: is: a number alone is a dimensionless unit", {
  g2_cfg(c("units:", "  zzg2pt:", "    is: 0.001", "    name: part per thousand"))
  expect_equal(g2_cv(g2_u(5, "zzg2pt"), "ppm"), f2("5,000~ppm"))
  expect_equal(g2_nm(g2_u(5, "zzg2pt")), f2("5~parts per thousand"))
  g2_cfg(c("units:", "  zzg2pu:", "    is: \"0.002\""))              # a YAML string
  expect_equal(g2_cv(g2_u(5, "zzg2pu"), "ppm"), f2("10,000~ppm"))
})

test_that("2g 9.1.7: is: a number and a unit, and a unit alone", {
  g2_cfg(c("units:", "  zzg2sp:", "    is: 2 km/h", "  zzg2mh:", "    is: km/d"))
  expect_equal(g2_cv(g2_u(3, "zzg2sp"), "km/h"), f2("6~km/h"))
  expect_equal(g2_cv(g2_u(3, "zzg2mh"), "km/d"), f2("3~km/d"))
  expect_equal(g2_factor("zzg2mh", "km/h"), 1 / 24, tolerance = 1e-9)
})

test_that("2g 9.1.7: is: an optional number, so 1 mi/h and mi/h are one unit (spacing and a fractional number)", {
  g2_cfg(c("units:", "  zzg2fr:", "    is: 0.5 L"))
  expect_equal(g2_cv(g2_u(4, "zzg2fr"), "L"), f2("2~L"))
})

test_that("2g 9.1.7: is: is read against units installed before it, in file order, defaults first", {
  g2_cfg(c("units:", "  zzgbtwo:", "    is: base", "  zzgbone:", "    is: 2 zzgbtwo", "  zzgbthree:", "    is: 3 NTU"))
  expect_equal(g2_cv(g2_u(1, "zzgbone"), "zzgbtwo"), f2("2~zzgbtwo"))
  expect_equal(g2_cv(g2_u(1, "zzgbthree"), "NTU"), f2("3~NTU"))
})

test_that("2g 9.1.7: a key defined with is: may not end in a digit", {
  e <- units_err(c("  zzg2dg1:", "    is: base"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2dg1`", "digit", "(rule 9.1.7)")
})

test_that("2g 9.1.7: a forward reference is a problem on the row that makes it", {
  e <- units_err(c("  zzg2f1:", "    is: 2 zzg2f2", "  zzg2f2:", "    is: base"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2f1`", "`is` `2 zzg2f2` is not a unit the units package can read:", "(rule 9.1.7)")
})

test_that("2g 9.1.7: a circular reference is a problem", {
  e <- units_err(c("  zzg2c1:", "    is: 2 zzg2c2", "  zzg2c2:", "    is: 3 zzg2c1"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`is` `2 zzg2c2` is not a unit the units package can read:", "(rule 9.1.7)")
})

test_that("2g 9.1.7: is: a unit weft refuses is a problem carrying the refusal text without the rule", {
  e <- units_err(c("  zzg2r1:", "    is: 1 mt"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2r1`", "`is` `1 mt`:", "`mt` is read by the units package as a millitonne", "(rule 9.1.7)")
  expect_false(grepl("(rule 4.4.20)", f2_msg(e), fixed = TRUE), label = f2_msg(e))
})

test_that("2g 9.1.7: is: that is not base, a positive number or a number and a unit is a problem, one line each", {
  for (bad in c("-3", "0", "[1, 2]", "true", ".inf", "\"\"", "\"2 x y z\"")) {
    e <- units_err(c("  zzg2bd:", paste0("    is: ", bad)))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "`zzg2bd`", "(rule 9.1.7)")
  }
  e <- units_err(c("  zzg2bd:", "    is: -3"))
  f2_msg_has(e, "`is` must be `base`, a positive number, or a number and a unit, such as `1 mi/h`")
})

test_that("2g 9.1.7: a key with is: is one token (no space, no digit first, none of * / ^ ( ) . + -)", {
  for (key in c("\"zzg2 two\"", "\"zzg2/x\"", "\"zzg2*x\"", "\"zzg2^2\"", "\"zzg2(x)\"", "\"zzg2.x\"", "\"zzg2+x\"",
                "\"zzg2-x\"", "\"2zzg2\"")) {
    e <- units_err(c(paste0("  ", key, ":"), "    is: base"))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "`is` defines one unit, so the key must be one token, with no space and none of * / ^ ( ) . + -",
               "(rule 9.1.7)")
  }
})

test_that("2g 9.1.7: without is: a key may still be a compound or have a space (2f)", {
  expect_no_error(g2_cfg(c("units:", "  zzg2cs/zzg2ct:", "    name: widget per gadget")))
})

test_that("2g 9.1.7: is: on a unit the units database holds as a symbol or name of its own row is a problem", {
  for (row in list(c("m", "ft"), c("ppt", "0.001"), c("kg", "2 lb"))) {
    e <- units_err(c(paste0("  ", row[[1]], ":"), paste0("    is: ", row[[2]])))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, paste0("`is` cannot redefine `", row[[1]], "`, a unit of the units database; choose another key"),
               "(rule 9.1.7)")
  }
})

test_that("2g 9.1.7: control - is: on a misread-list token or a default key is not a problem (gal, mt, pH)", {
  expect_no_error(g2_cfg(c("units:", "  gal:", "    is: 4.54609 L", "  mt:", "    is: 1 t")))
  expect_no_error(g2_cfg(c("units:", "  pH:", "    is: base", "    name: pH")))
})

test_that("2g 9.1.7: two keys that give the same unit are a problem naming the other", {
  e <- units_err(c("  zzg2s1:", "    is: 3 m", "  zzg2s2:", "    is: 3 m"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2s2`", "`is` gives the same unit as `zzg2s1`; give it one row", "(rule 9.1.7)")
})

test_that("2g 9.1.7: a key that gives the same unit as a default row names it, and says it is the default table's", {
  e <- units_err(c("  zzg2s3:", "    is: 1 mi/h"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`is` gives the same unit as `mph` (weft's default table); give it one row", "(rule 9.1.7)")
})

test_that("2g 9.1.7: a prefix on a default row with is: in force is a problem in is:", {
  e <- units_err(c("  zzg2k1:", "    is: 3 kNTU"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2k1`", "`is` `3 kNTU`:", "`kNTU` is read as the prefix `k` (kilo) on `NTU`", "(rule 9.1.7)")
})

# ---- before: and the unknown-field line ---------------------------------------------------------------------------------

test_that("2g 9.1.7: before must be true or false", {
  for (bad in c("maybe", "1", "\"yes\"")) {
    e <- units_err(c("  zzg2bf:", "    is: base", paste0("    before: ", bad)))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "`zzg2bf`", "`before` must be true or false", "(rule 9.1.7)")
  }
})

test_that("2g 9.1.7: before true and false are read, and before is a field a row may carry on its own", {
  expect_no_error(g2_cfg(c("units:", "  zzg2bt:", "    is: base", "    before: true", "  zzg2bu:", "    before: false")))
})

test_that("2g 9.1.7: the unknown-field line lists the six fields", {
  e <- units_err(c("  zzg2uf:", "    plurl: x"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2uf`", "plurl", "name", "plural", "symbol", "space", "is", "before", "(rule 9.1.7)")
})

# ---- false ------------------------------------------------------------------------------------------------------------------

test_that("2g 9.1.7: false removes a default row: its redefinition is undone and the misread is refused again", {
  g2_cfg(c("units:", "  mph: false"))
  e <- f2_cond(g2_u(60, "mph"))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "`mph: false` in `units:`")
  expect_equal(g2_factor("mph", "mi/h"), NA_real_)
})

test_that("2g 9.1.7: false drops a default row's names, a base registration stays (NTU)", {
  g2_cfg(c("units:", "  NTU: false", "  ppm: false"))
  expect_equal(g2_num(g2_u(3, "NTU")), f2("3~NTU"))
  f2_has_class(f2_cond(g2_nm(g2_u(3, "NTU"))), "weft_value_error")
  f2_has_class(f2_cond(g2_nm(g2_u(5, "ppm"))), "weft_value_error")
  expect_equal(g2_num(g2_u(5, "ppm")), f2("5~ppm"))
})

test_that("2g 9.1.7: false on a unit with no default row is a problem in the contract's words", {
  e <- units_err(c("  zzg2nr: false"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2nr`", "`false` removes a row of weft's default table, and it has no row `zzg2nr`", "(rule 9.1.7)")
})

test_that("2g 9.1.7: under si, false on a redefining default row is not a problem (the row is skipped whole)", {
  expect_no_error(g2_cfg(c(SI, "units:", "  pH: false")))
})

# ---- precedence --------------------------------------------------------------------------------------------------------------

test_that("2g 9.1.7: a project row merges per field over the default row (space on pH keeps is, name, plural and before)", {
  g2_cfg(c("units:", "  pH:", "    space: false"))
  expect_equal(g2_num(u(7.2, pH)), "pH7.2")
  expect_equal(g2_nm(u(7.2, pH)), f2("pH~7.2"))      # review 2g ruling c: space: false governs the symbol form only
  expect_equal(g2_nm(u(7, pH)), f2("pH~7"))
  expect_equal(g2_cv(u(7.2, pH), "pH"), "pH7.2")          # still its own base unit
})

test_that("2g 9.1.7: a project name over a default row's keeps the default's other fields", {
  g2_cfg(c("units:", "  mph:", "    name: mile per hr"))
  expect_equal(g2_nm(u(60, mph)), f2("60~miles per hr"))
  expect_equal(g2_cv(u(60, mph), "km/h"), f2("96.6~km/h"))
})

test_that("2g 9.1.7: a document's row replaces the project's whole, and merges per field over the default", {
  g2_cfg(c("units:", "  mph:", "    name: mile an hour", "    plural: miles an hour"),
         front = list(units = list(mph = list(plural = "miles per hr"))))
  expect_equal(g2_nm(u(60, mph)), f2("60~miles per hr"))
  expect_equal(g2_nm(u(1, mph)), f2("1~mile per hour"))     # the project's name was replaced; the default's name shows
  expect_equal(g2_cv(u(60, mph), "km/h"), f2("96.6~km/h"))
})

test_that("2g 9.1.7: a document over a project over a default, field by field (NTU)", {
  g2_cfg(c("units:", "  NTU:", "    name: turbidity unit"),
         front = list(units = list(NTU = list(name = "nephelo unit"))))
  expect_equal(g2_nm(u(3, NTU)), f2("3~nephelo units"))
  g2_cfg(c("units:", "  NTU:", "    name: turbidity unit"))
  expect_equal(g2_nm(u(3, NTU)), f2("3~turbidity units"))
  g2_cfg(NULL)
  expect_equal(g2_nm(u(3, NTU)), f2("3~nephelometric turbidity units"))
})

test_that("2g 9.1.7: a project is: replaces the default's redefinition, a document's is: replaces the project's", {
  g2_cfg(c("units:", "  gal:", "    is: 4.54609 L"), front = list(units = list(gal = list(is = "3.5 L"))))
  expect_equal(g2_factor("gal", "L"), 3.5, tolerance = 1e-9)
  g2_cfg(c("units:", "  gal:", "    is: 4.54609 L"))
  expect_equal(g2_factor("gal", "L"), 4.54609, tolerance = 1e-9)
})

test_that("2g 9.1.7: project and document rows apply on top under si, and under si a project may redefine gal and pH", {
  g2_cfg(c(SI, "units:", "  gal:", "    is: 4.54609 L", "  pH:", "    is: base", "    name: pH", "    plural: pH",
           "    before: true"))
  expect_equal(g2_cv(u(10, gal), "L"), f2("45.5~L"))
  expect_equal(g2_num(u(7.2, pH)), f2("pH~7.2"))
})

test_that("2g 9.1.7: every new problem is raised together with 2f's in one error with a count line", {
  e <- units_err(c("  zzg2e1:", "    nmae: x",                         # 2f: unknown field
                   "  zzg2e2:", "    is: -3",                          # 9.1.7: bad is
                   "  zzg2e3:", "    is: base", "    before: maybe",   # bad before
                   "  m:", "    is: ft",                              # redefines a database unit
                   "  zzg2e5: false"))                                 # false with no default row
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "5 problem(s) in `units:`", "`zzg2e1`", "`zzg2e2`", "`zzg2e3`", "`m`", "`zzg2e5`")
})

test_that("2g 9.1.7: the check also runs on a front-matter units: table", {
  e <- g2_cfg_err(NULL, front = list(units = list(zzg2fm = list(is = "-3"))))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2fm`", "`is` must be `base`, a positive number, or a number and a unit", "(rule 9.1.7)")
})

test_that("2g 9.1.7: a read with a problem registers none of the project's is: tokens", {
  e <- units_err(c("  zzg2ok2:", "    is: 2 m", "  zzg2bad2:", "    is: -3"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg2bad2`", "`is` must be `base`, a positive number, or a number and a unit")
  expect_true(is.na(g2_factor("zzg2ok2", "m")))
})
