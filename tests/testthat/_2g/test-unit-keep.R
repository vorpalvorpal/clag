# Package 2g: keeping the token (4.4.20), twin conversions (4.4.14), refusals (4.4.20, 4.4.21).
# Contract: dev/design-2g.md "Keeping the token", "Errors". `~` in an expected string is U+00A0.
if (!exists("g2_row")) source(file.path(dirname(Filter(file.exists, c(testthat::test_path("helper-2g.R"), testthat::test_path("..", "helper-2g.R")))[[1]]), "helper-2g.R"))
g2_need()

SI <- "unit_defaults: si"
dep <- function(x) units::deparse_unit(x)

# ---- keeping the token, both modes ---------------------------------------------------------------------------------

test_that("2g 4.4.20: Sv, Bq, Bd, VA, Mg, ut, sievert and becquerel are stored as written (weft)", {
  g2_cfg(NULL)
  for (tok in c("Sv", "Bq", "Bd", "VA", "Mg", "ut", "sievert", "becquerel")) {
    x <- g2_u(2, tok)
    expect_equal(dep(x), tok, label = paste("deparse_unit of", tok))
  }
})

test_that("2g 4.4.20: the same tokens, and mt, are stored as written under si", {
  g2_cfg(SI)
  for (tok in c("Sv", "Bq", "Bd", "VA", "Mg", "ut", "sievert", "becquerel", "mt")) {
    expect_equal(dep(g2_u(2, tok)), tok, label = paste("deparse_unit of", tok))
  }
  expect_equal(dep(g2_u(1, "mt/d")), "mt/d")
})

test_that("2g 4.4.20: gallon, nautical_mile and Myr are stored as written", {
  g2_cfg(NULL)
  for (tok in c("gallon", "nautical_mile", "Myr")) expect_equal(dep(g2_u(2, tok)), tok, label = tok)
})

test_that("2g 4.4.20: the symbol units substitutes for a token's own row is taken (control: metre m, degC, lux, degree)", {
  g2_cfg(NULL)
  expect_equal(dep(g2_u(1, "metre")), "m")
  expect_equal(dep(g2_u(1, "degC")), dep(g2_u(1, "celsius")))
  expect_equal(dep(g2_u(1, "lux")), "lx")
  expect_equal(dep(g2_u(1, "degree")), "°")
  expect_equal(dep(g2_u(1, "celsius")), "°C")
})

test_that("2g 4.4.20: Sv written as Sv prints Sv, never Gy, and a Bq never prints as Hz", {
  g2_cfg(NULL)
  expect_equal(g2_num(g2_u(2, "Sv")), f2("2~Sv"))
  expect_equal(g2_num(g2_u(2, "Bq")), f2("2~Bq"))
  expect_equal(g2_num(g2_u(2, "Bd")), f2("2~Bd"))
  expect_equal(g2_num(g2_u(2, "VA")), f2("2~VA"))
  expect_equal(g2_num(g2_u(2, "Mg")), f2("2~Mg"))
  expect_equal(g2_num(g2_u(2, "Gy")), f2("2~Gy"))          # control
})

test_that("2g 4.4.20: keeping the token changes no database entry: Gy and Hz still read as themselves", {
  g2_cfg(NULL)
  invisible(g2_u(2, "Sv")); invisible(g2_u(2, "Bq"))
  expect_equal(dep(g2_u(1, "Gy")), "Gy")
  expect_equal(dep(g2_u(1, "Hz")), "Hz")
  expect_equal(g2_factor("Gy", "J/kg"), 1)
  expect_equal(g2_factor("Hz", "s^-1"), 1)
  expect_equal(g2_factor("kHz", "Hz"), 1000)
})

test_that("2g 4.4.20: weft sets no units option globally", {
  g2_cfg(NULL)
  invisible(g2_u(2, "Sv"))
  expect_null(getOption("units.auto_convert_names_to_symbols"))
  expect_true(units::units_options("auto_convert_names_to_symbols"))
})

test_that("2g 4.4.20: read_dict() keeps the token of unit: and holds Sv", {
  g2_cfg(NULL)
  d <- read_dict(f2_dict_file("dose: {value: 3, type: quantity, unit: Sv, definition: \"A dose.\"}"))
  expect_equal(dep(d$dose), "Sv")
  d2 <- read_dict(f2_dict_file("act: {value: 3, type: quantity, unit: kBq, definition: \"Activity.\"}"))
  expect_equal(dep(d2$act), "kBq")
})

test_that("2g 4.4.20: read_dict() reads pH with the default table, and holds pH", {
  g2_cfg(NULL)
  d <- read_dict(g2_dict_row("pH", value = 7.2))
  expect_equal(dep(d$q), "pH")
  expect_equal(g2_num(d$q), f2("pH~7.2"))
})

test_that("2g 4.4.20: fmt_unit() on a string keeps the token", {
  g2_cfg(NULL)
  expect_equal(f2_tx(fmt_unit("pH")), "pH")
  expect_equal(f2_tx(fmt_unit("Sv")), "Sv")
  expect_equal(f2_tx(fmt_unit("Sv", unit_form = "name")), "sieverts")
})

test_that("2g 4.4.20: a units: key and an is: may use a swapped token", {
  g2_cfg(c("units:", "  Sv:", "    name: sievert", "  zzg2dose:", "    is: 2 Sv"))
  expect_equal(g2_factor("zzg2dose", "J/kg"), 2, tolerance = 1e-9)
  expect_equal(g2_nm(g2_u(2, "Sv")), f2("2~sieverts"))
})

test_that("2g 4.4.20: unit = and display: accept a swapped token as the target (mSv to Sv, Sv to J/kg)", {
  g2_cfg(NULL)
  expect_equal(g2_cv(g2_u(1500, "mSv"), "Sv"), f2("1.5~Sv"))
  expect_equal(g2_cv(g2_u(2, "Sv"), "J/kg"), f2("2~J/kg"))
  d <- read_dict(g2_dict_row("mSv", ", display: Sv", 1500))
  expect_s3_class(d$q, "units")
})

# ---- twin units ----------------------------------------------------------------------------------------------------------------

test_that("2g G2: a conversion from one member of a twin group to another is a weft_value_error (unit =)", {
  g2_cfg(NULL)
  pairs <- list(c("Sv", "Gy"), c("Gy", "Sv"), c("Bq", "Hz"), c("Hz", "Bq"), c("Bq", "Bd"), c("Bd", "Hz"),
                c("VA", "W"), c("W", "VA"), c("mSv", "Gy"), c("kBq", "Hz"), c("kVA", "W"), c("Sv", "mGy"))
  for (p in pairs) {
    e <- f2_cond(fmt_num(g2_u(2, p[[1]]), unit = p[[2]]))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, paste0("`", p[[2]], "`"), paste0("`", p[[1]], "`"))
  }
})

test_that("2g G2: a twin conversion inside a compound is a weft_value_error (Bq/L to Hz/L)", {
  g2_cfg(NULL)
  f2_has_class(f2_cond(fmt_num(g2_u(2, "Bq/L"), unit = "Hz/L")), "weft_value_error")
  f2_has_class(f2_cond(fmt_num(g2_u(2, "kVA/h"), unit = "kW/h")), "weft_value_error")
})

test_that("2g G2: the twin conversion error names both units, says they are alike, and cites rule 4.4.14", {
  g2_cfg(NULL)
  e <- f2_cond(fmt_num(g2_u(2, "Sv"), unit = "Gy"))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "`Gy`: the quantity is in `Sv`", "alike", "they measure different things",
             "weft does not convert one to the other", "(rule 4.4.14)")
})

test_that("2g G2: a twin conversion through unit = in weft_str() is a value error too", {
  g2_restore()
  f2_has_class(f2_err("`r u(2, Sv)`{.num unit=\"Gy\"}"), "weft_value_error")
})

test_that("2g G2: display: that converts to a twin is a dictionary problem", {
  g2_cfg(NULL)
  e <- f2_cond(read_dict(g2_dict_row("Sv", ", display: Gy", 2)))
  f2_has_class(e, "weft_dict_error")
  f2_msg_has(e, "`Gy`: the quantity is in `Sv`", "(rule 4.4.14)")
  e2 <- f2_cond(read_dict(g2_dict_row("Bq/L", ", display: Hz/L", 2)))
  f2_has_class(e2, "weft_dict_error")
  f2_msg_has(e2, "`Hz/L`", "`Bq/L`")
})

test_that("2g G2: twin conversions are refused under si too", {
  g2_cfg(SI)
  f2_has_class(f2_cond(fmt_num(g2_u(2, "Sv"), unit = "Gy")), "weft_value_error")
})

test_that("2g G2: control - within a member and to the SI definition converts, and ordinary conversions are untouched", {
  g2_cfg(NULL)
  expect_equal(g2_cv(g2_u(1500, "mSv"), "Sv"), f2("1.5~Sv"))
  expect_equal(g2_cv(g2_u(2, "kBq"), "Bq"), f2("2,000~Bq"))
  expect_equal(g2_cv(g2_u(2, "kVA"), "VA"), f2("2,000~VA"))
  expect_equal(g2_cv(g2_u(2, "Sv"), "J/kg"), f2("2~J/kg"))
  expect_equal(g2_cv(g2_u(2, "Gy"), "J/kg"), f2("2~J/kg"))
  expect_equal(g2_cv(g2_u(5, "km"), "m"), f2("5,000~m"))
  expect_equal(g2_cv(g2_u(2, "Hz"), "kHz"), f2("0.002~kHz"))
})

# ---- refusals under weft: u() -------------------------------------------------------------------------------------------------

READING <- list(
  pH = "picohenry", mph = "milliphot", nmi = "nanomile", Ma = "megaare", ka = "kiloare",
  gal = "galileo")

test_that("2g 4.4.20: under weft a misread-list token its table has no row for is a weft_unit_error with the contract's text (mt)", {
  g2_cfg(NULL)
  e <- f2_cond(g2_u(5, "mt"))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "u(): ", "`mt` is read by the units package as a millitonne (`m` + `t`), which is 1 kg",
             "Write `t` for a tonne, or `Mt` for a megatonne.",
             "To take that reading, set `unit_defaults: si` in _weft.yml (rule 4.4.20).")
})

test_that("2g 4.4.20: under weft each of pH mph nmi Ma ka gal is refused once its row is false, with its reading and the advice", {
  for (tok in names(READING)) {
    g2_cfg(c("units:", paste0("  ", tok, ": false")))
    e <- f2_cond(g2_u(5, tok))
    f2_has_class(e, "weft_unit_error")
    f2_msg_has(e, "u(): ", paste0("`", tok, "` is read by the units package as"), READING[[tok]],
               paste0("weft's default table defines it, and `", tok, ": false` in `units:` removed that row"),
               "define it there with `is:` (see unit_defaults())",
               "To take that reading, set `unit_defaults: si` in _weft.yml (rule 4.4.20)")
  }
})

test_that("2g 4.4.20: the readings carry their prefix and unit as the contract writes them", {
  want <- c(pH = "a picohenry (`p` + `H`)", mph = "a milliphot (`m` + `ph`)", nmi = "a nanomile (`n` + `mi`)",
            Ma = "a megaare (`M` + `a`)", ka = "a kiloare (`k` + `a`)", gal = "the galileo, a unit of acceleration")
  for (tok in names(want)) {
    g2_cfg(c("units:", paste0("  ", tok, ": false")))
    f2_msg_has(f2_cond(g2_u(5, tok)), want[[tok]])
  }
})

test_that("2g 4.4.20: a trap, a prefix on the phot or the are but ha, is refused under weft (kph, Ga, ca)", {
  g2_cfg(NULL)
  rd <- c(kph = "a kilophot (`k` + `ph`)", Ga = "a gigaare (`G` + `a`)", ca = "a centiare (`c` + `a`)")
  for (tok in names(rd)) {
    e <- f2_cond(g2_u(5, tok))
    f2_has_class(e, "weft_unit_error")
    f2_msg_has(e, "u(): ", paste0("`", tok, "` is read by the units package as ", rd[[tok]]),
               "Write the unit you mean (`km/h` for kilometres per hour, `Gyr` for a billion years).",
               "To take that reading, set `unit_defaults: si` in _weft.yml (rule 4.4.20).")
  }
})

test_that("2g 4.4.20: control - ha, ordinary prefixed units and the intended spellings are accepted under weft", {
  g2_cfg(NULL)
  for (tok in c("ha", "km/h", "mi/h", "Gyr", "mm", "kPa", "mL", "t", "Mt", "yr", "mg/L", "m/s")) {
    expect_no_error(g2_u(5, tok))
  }
})

test_that("2g 4.4.20: a refusal is raised alone and in a compound (mt/d, kph/h)", {
  g2_cfg(NULL)
  e <- f2_cond(g2_u(5, "mt/d"))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "`mt`", "millitonne")
  e2 <- f2_cond(g2_u(5, "kph/h"))
  f2_has_class(e2, "weft_unit_error")
  f2_msg_has(e2, "`kph`", "kilophot")
})

test_that("2g 4.4.20: a project row defining the token lifts the refusal (mt, Ga)", {
  g2_cfg(c("units:", "  mt:", "    is: 1 t", "  Ga:", "    is: 1 Gyr", "    name: billion years",
           "    plural: billion years"))
  expect_equal(g2_num(g2_u(2, "mt")), f2("2~mt"))
  expect_equal(g2_cv(g2_u(2, "mt"), "kg"), f2("2,000~kg"))
  expect_equal(g2_nm(g2_u(1, "Ga")), f2("1~billion years"))
  expect_equal(g2_cv(g2_u(3, "Ga"), "Myr"), f2("3,000~Myr"))
})

# ---- refusals in both modes: a prefix on a default row -------------------------------------------------------------------

test_that("2g 4.4.20: a prefix on a default row with is: in force is refused in the contract's words (kmph, kNTU, mNTU)", {
  g2_cfg(NULL)
  e <- f2_cond(g2_u(1, "kmph"))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "u(): ", "`kmph` is read as the prefix `k` (kilo) on `mph`, a unit of weft's default table, and weft refuses a prefix on its own units.",
             "Write the unit you mean (`km/h` for kilometres per hour) (rule 4.4.20).")
  for (tok in c("kNTU", "mPSU", "kCFU", "kMPN")) {
    e2 <- f2_cond(g2_u(1, tok))
    f2_has_class(e2, "weft_unit_error")
    f2_msg_has(e2, paste0("`", tok, "` is read as the prefix"), "weft's default table", "(rule 4.4.20)")
  }
})

test_that("2g 4.4.20: the same refusal holds under si for the base rows (NTU PSU CFU MPN)", {
  g2_cfg(SI)
  for (tok in c("kNTU", "mPSU", "kCFU", "kMPN")) {
    e <- f2_cond(g2_u(1, tok))
    f2_has_class(e, "weft_unit_error")
    f2_msg_has(e, paste0("`", tok, "` is read as the prefix"), "weft's default table", "(rule 4.4.20)")
  }
})

test_that("2g 4.4.20: a prefix on a default row with is: in force refused inside a compound (kNTU/d)", {
  g2_cfg(NULL)
  e <- f2_cond(g2_u(1, "kNTU/d"))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "`kNTU` is read as the prefix `k` (kilo) on `NTU`", "weft's default table")
})

# ---- refusals through read_dict() ---------------------------------------------------------------------------------------------

test_that("2g 4.2.6: read_dict() has a problem for mt, alone and in a compound, naming the token and the reading", {
  g2_cfg(NULL)
  for (unit in c("mt", "mt/d")) {
    e <- f2_cond(read_dict(g2_dict_row(unit)))
    f2_has_class(e, "weft_dict_error")
    f2_msg_has(e, "`mt`", "millitonne", "unit_defaults: si", "(rule 4.4.20)")
  }
})

test_that("2g 4.2.6: read_dict() has a problem for a trap and for a prefix on a default row", {
  g2_cfg(NULL)
  e <- f2_cond(read_dict(g2_dict_row("kph")))
  f2_has_class(e, "weft_dict_error")
  f2_msg_has(e, "`kph`", "kilophot")
  e2 <- f2_cond(read_dict(g2_dict_row("kNTU")))
  f2_has_class(e2, "weft_dict_error")
  f2_msg_has(e2, "`kNTU`", "weft's default table")
})

test_that("2g 4.2.6: read_dict() reads the same units under si", {
  g2_cfg(SI)
  expect_no_error(read_dict(g2_dict_row("mt")))
  expect_no_error(read_dict(g2_dict_row("kph")))
})

# ---- someone else installed the token (refusal text) ------------------------------------------------------------------

test_that("2g 4.4.21: unit_defaults: si does not refuse a mph that someone else installed differently (child session)", {
  out <- g2_child(paste(
    'units::install_unit("mph", "1 km/h")',
    'd <- tempfile(); dir.create(d); writeLines("unit_defaults: si", file.path(d, "_weft.yml"))',
    'weft:::read_config(d)',
    'cat("OK=", !inherits(tryCatch(u(60, mph), error = function(e) e), "error"), "\\n", sep = "")',
    sep = "\n"))
  expect_equal(g2_kv(out, "OK"), "TRUE")
})
