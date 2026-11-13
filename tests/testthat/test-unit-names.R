# Package 2f: unit names (resolving, the shipped table, plurals, compounds, no-name cases).
# Contract: dev/design-2f.md "Names", "Plurals", "Functions" (fmt_unit), "Errors"; U7-U12.
# `~` in an expected string is U+00A0.
if (!exists("f2_ws")) source(testthat::test_path("helper-2f.R"))
if (!exists("render_rmd")) source(testthat::test_path("..", "helper-render.R"))

nm <- function(x) f2_tx(fmt_unit(x, unit_form = "name"))   # the name, via fmt_unit()
sy <- function(x) f2_tx(fmt_unit(x))                       # the symbol text, via fmt_unit()

# ---- the shipped table, row by row (4.4.17, U7-U10) ------------------------------------------

test_that("2f shipped table: m, L and t take their non-US names; a plural for a number other than 1 (4.4.17)", {
  expect_equal(nm(u(2, m)), "metres")
  expect_equal(nm(u(2, L)), "litres")
  expect_equal(nm(u(2, t)), "tonnes")
  expect_equal(nm(u(1, m)), "metre")
  expect_equal(nm(u(1, L)), "litre")
  expect_equal(nm(u(1, t)), "tonne")
})

test_that("2f shipped table: ha, hectare, yr, year, bar, ft, in, mi, lb (4.4.17)", {
  expect_equal(nm(u(2, ha)), "hectares")
  expect_equal(nm(u(1, hectare)), "hectare")
  expect_equal(nm(u(2, yr)), "years")
  expect_equal(nm(u(1, year)), "year")
  expect_equal(nm(u(2, bar)), "bars")
  expect_equal(nm(u(2, ft)), "feet")
  expect_equal(nm(u(1, ft)), "foot")
  expect_equal(nm(u(3, "in")), "inches")
  expect_equal(nm(u(1, "in")), "inch")
  expect_equal(nm(u(2, mi)), "miles")
  expect_equal(nm(u(2, lb)), "pounds")
  expect_equal(nm(u(1, lb)), "pound")
})

test_that("2f shipped table: the symbols of ha and bar are as shipped, and year and yr have none (4.4.17, U9)", {
  expect_equal(sy(u(2, ha)), "ha")
  expect_equal(sy(u(2, hectare)), "ha")           # a unit typed as a name prints its symbol (U11)
  expect_equal(sy(u(2, bar)), "bar")
  expect_equal(sy(u(2, year)), "years")           # no symbol: the name, plural in a numerator
  expect_equal(sy(u(2, yr)), "years")
  expect_equal(sy(u(1, year)), "year")
})

test_that("2f shipped table: degree, the arc marks and per cent (4.4.17)", {
  expect_equal(nm(u(2, "°")), "degrees")
  expect_equal(nm(u(1, "°")), "degree")
  expect_equal(nm(u(35, "%")), "per cent")          # as the singular, whatever the number
  expect_equal(nm(u(1, "%")), "per cent")
  expect_equal(sy(u(35, "%")), "%")
})

test_that("2f shipped table: Hz, lx and S are their own plural (4.4.17)", {
  expect_equal(nm(u(20, Hz)), "hertz")
  expect_equal(nm(u(1, Hz)), "hertz")
  expect_equal(nm(u(5, lx)), "lux")
  expect_equal(nm(u(5, S)), "siemens")
})

test_that("2f shipped table: a degree Celsius is 'degrees Celsius' (database name, plural on the first word)", {
  expect_equal(nm(u(20, degC)), "degrees Celsius")
  expect_equal(nm(u(1, degC)), "degree Celsius")
})

test_that("2f shipped table: min, Pa, d, h have database names (4.4.16)", {
  expect_equal(nm(u(5, min)), "minutes")
  expect_equal(nm(u(5, Pa)), "pascals")
  expect_equal(nm(u(5, d)), "days")
  expect_equal(nm(u(5, h)), "hours")
  expect_equal(sy(u(5, d)), "d")                  # d, h, min print as symbols under auto (U10)
  expect_equal(sy(u(5, h)), "h")
  expect_equal(sy(u(5, min)), "min")
})

# ---- the database: names with underscores, aliases, plurals, prefixes (4.4.16) -------------------

test_that("2f database: a name with an underscore reads as words (4.4.16)", {
  expect_equal(nm(u(2, light_year)), "light years")
  expect_equal(nm(u(1, light_year)), "light year")
  expect_equal(sy(u(2, light_year)), "light years")      # a unit with no symbol prints its name
})

test_that("2f database: a token is a symbol, alias, singular or plural name, or the English plural (4.4.16)", {
  expect_equal(nm(u(2, metre)), "metres")                 # a name alias
  expect_equal(nm(u(2, meter)), "metres")                 # the singular name
  expect_equal(nm(u(2, years)), "years")                  # the English plural of a name
  expect_equal(nm(u(2, hr)), "hours")                     # a symbol alias
  expect_equal(nm(u(2, hours)), "hours")
})

test_that("2f database: a prefix by symbol and by name, longest prefix first (4.4.16)", {
  expect_equal(nm(u(2, km)), "kilometres")
  expect_equal(nm(u(2, kilometers)), "kilometres")
  expect_equal(nm(u(2, mL)), "millilitres")
  expect_equal(nm(u(2, ug)), "micrograms")                # u counts as micro
  expect_equal(nm(u(2, mg)), "milligrams")
  expect_equal(nm(u(2, dam)), "decametres")               # da, not d + am: and 'deca' for 'deka'
  expect_equal(nm(u(2, kW)), "kilowatts")
  expect_equal(nm(u(1, km)), "kilometre")
})

test_that("2f database: a prefix goes before the plural, as a prefixed degree Celsius does (4.4.16)", {
  expect_equal(nm(u(2, mdegC)), "millidegrees Celsius")
  expect_equal(nm(u(2, mg)), "milligrams")
})

test_that("2f database: an exact row is taken before a prefix (4.4.16)", {
  # `min` is a minute, not milli-inch; `Pa` a pascal; `ha` a hectare (not h + a)
  expect_equal(nm(u(2, min)), "minutes")
  expect_equal(nm(u(2, Pa)), "pascals")
  expect_equal(nm(u(2, ha)), "hectares")
})

test_that("2f database: a unit typed as a name prints its symbol; one typed as a symbol prints as typed (U11, 4.4.16)", {
  expect_equal(f2_tx(fmt_num(u(2, kilometre))), f2("2~km"))
  expect_equal(f2_tx(fmt_num(u(5, metre))), f2("5~m"))
  expect_equal(f2_tx(fmt_num(u(3, microgram))), f2("3~µg"))
  expect_equal(f2_tx(fmt_num(u(3, ug))), f2("3~ug"))
})

test_that("2f database: an unknown token has no name and prints itself as a symbol (4.4.16, 4.4.19)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  withr::defer(weft:::read_config(f2_proj()))
  weft:::read_config(f2_proj(c("units:", "  zzpsu:", "    is: base")))
  expect_equal(sy(u(3, zzpsu)), "zzpsu")
  e <- f2_cond(nm(u(3, zzpsu)))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "zzpsu")
})

# ---- the same-unit rule (4.4.16) -------------------------------------------------------------------

test_that("2f same unit: metre and m are one unit, so a units: key for one names the other (4.4.16)", {
  yml <- c("units:", "  metre:", "    name: emm")
  expect_equal(f2_ws("`r u(5, m)`{.uname}", yml), f2("5~emms"))
  expect_equal(f2_ws("`r u(5, metre)`{.uname}", yml), f2("5~emms"))
})

test_that("2f same unit: year, years and yr are one unit (4.4.16)", {
  yml <- c("units:", "  yr:", "    name: twelvemonth")
  expect_equal(f2_ws("`r u(2, year)`{.uname}", yml), f2("2~twelvemonths"))
  expect_equal(f2_ws("`r u(2, years)`{.uname}", yml), f2("2~twelvemonths"))
  expect_equal(f2_ws("`r u(2, yr)`{.uname}", yml), f2("2~twelvemonths"))
})

test_that("2f same unit: L and dm^3 are not the same unit, so a key for L does not name dm^3 (4.4.16)", {
  yml <- c("units:", "  L:", "    name: lit")
  expect_equal(f2_ws("`r u(2, L)`{.uname}", yml), f2("2~lits"))
  expect_equal(f2_ws("`r u(2, dm^3)`{.uname}", yml), f2("2~cubic decimetres"))
})

# ---- plural sources: project, shipped, database, English rule (4.4.16, 4.4.15) -----------------------

test_that("2f plurals: the English rule on the last word of a project name (4.4.16)", {
  yml <- c("units:",
           "  zorpa: {name: patch}",
           "  zorpb: {name: box}",
           "  zorpc: {name: quiz}",
           "  zorpd: {name: baby}",
           "  zorpe: {name: toy}",
           "  zorpf: {name: bus}",
           "  zorpg: {name: wash}",
           "  zorph: {name: lab report}")
  want <- c(zorpa = "patches", zorpb = "boxes", zorpc = "quizes", zorpd = "babies",
            zorpe = "toys", zorpf = "buses", zorpg = "washes", zorph = "lab reports")
  for (k in names(want)) {
    expect_equal(f2_ws(sprintf("`r u(2, %s)`{.uname}", k), yml), f2(paste0("2~", want[[k]])), label = k)
  }
  expect_equal(f2_ws("`r u(1, zorpd)`{.uname}", yml), f2("1~baby"))
})

test_that("2f plurals: a project plural beats the shipped one, which beats the database's (4.4.16)", {
  # shipped: foot -> feet; the database has international_feet. A project plural wins over both.
  expect_equal(nm(u(2, ft)), "feet")
  yml <- c("units:", "  ft:", "    plural: footsies")
  expect_equal(f2_ws("`r u(2, ft)`{.uname}", yml), f2("2~footsies"))
  expect_equal(f2_ws("`r u(1, ft)`{.uname}", yml), f2("1~foot"))      # plural alone re-plurals the name weft finds
})

test_that("2f plurals: a project name and plural both given are used as written (4.4.16, 9.1.7)", {
  yml <- c("units:", "  zorpm:", "    name: mouse", "    plural: mice")
  expect_equal(f2_ws("`r u(2, zorpm)`{.uname}", yml), f2("2~mice"))
  expect_equal(f2_ws("`r u(1, zorpm)`{.uname}", yml), f2("1~mouse"))
})

# ---- compounds (4.4.18) ----------------------------------------------------------------------------

test_that("2f compounds: a power of 2 or 3 is 'square' or 'cubic' before the name of a length (4.4.18, U12)", {
  expect_equal(nm(u(2, m^2)), "square metres")
  expect_equal(nm(u(1, m^3)), "cubic metre")
  expect_equal(nm(u(2, km^2)), "square kilometres")
  expect_equal(nm(u(2, ft^2)), "square feet")
})

test_that("2f compounds: a power of 2 or 3 is 'squared' or 'cubed' after the name of anything else (4.4.18)", {
  expect_equal(nm(u(2, s^2)), "seconds squared")
  expect_equal(nm(u(1, s^2)), "second squared")
  expect_equal(nm(u(3, kg^3)), "kilograms cubed")
})

test_that("2f compounds: numerator factors joined by a space, ' per ', the denominator's joined by a space (4.4.18)", {
  expect_equal(nm(u(5, mg/L)), "milligrams per litre")
  expect_equal(nm(u(2, kg/(m * s))), "kilograms per metre second")
  expect_equal(nm(u(3, kW * h)), "kilowatt hours")
  expect_equal(nm(u(2, kg * m/s^2)), "kilogram metres per second squared")
  expect_equal(nm(u(9.81, m/s^2)), "metres per second squared")
  expect_equal(nm(u(1200, kg/m^3)), "kilograms per cubic metre")
})

test_that("2f compounds: only the last numerator factor takes the plural; none singular only for exactly one printed '1' (4.4.18, 4.4.15)", {
  expect_equal(nm(u(1, kg * m)), "kilogram metre")
  expect_equal(nm(u(2, kg * m)), "kilogram metres")
  expect_equal(nm(u(1, mg/L)), "milligram per litre")
  expect_equal(nm(u(5, mg/L)), "milligrams per litre")
})

test_that("2f compounds: no numerator gives 'per ...' (4.4.18)", {
  expect_equal(nm(u(2, "1/m^3")), "per cubic metre")
  expect_equal(nm(u(2, "1/s")), "per second")
})

test_that("2f compounds: a whole-unit units: key wins over its factors (4.4.18)", {
  yml <- c("units:", "  kg/m^3:", "    name: density unit")
  expect_equal(f2_ws("`r u(5, kg/m^3)`{.uname}", yml), f2("5~density units"))
  expect_equal(f2_ws("`r u(1, kg/m^3)`{.uname}", yml), f2("1~density unit"))
})

test_that("2f compounds: a factor key gives its name to the compound (4.4.18, 4.4.16)", {
  yml <- c("units:", "  PSU:", "    name: practical salinity unit")
  f2_register()
  expect_equal(f2_ws("`r u(2, PSU/d)`{.uname}", yml), f2("2~practical salinity units per day"))
})

# ---- no name: each case and its message (4.4.19, U3) -------------------------------------------------

test_that("2f no name: a unit with an unknown factor and no units: entry (4.4.19)", {
  f2_register()
  yml <- c("units:", "  zzpsu:", "    is: base")
  e <- f2_err("`r u(3, zzpsu)`{.uname}", yml)
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "zzpsu", "units:", "_weft.yml", ".usym", ".nounit")
  e2 <- f2_err("`r u(3, zzpsu/d)`{.uname}", yml)
  f2_has_class(e2, "weft_value_error")
  f2_msg_has(e2, "zzpsu")
})

test_that("2f no name: a unit that holds a number (4.4.19)", {
  f2_register()
  e <- f2_err("`r u(150, \"CFU/100 mL\")`{.uname}")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "CFU", "units:", ".usym", ".nounit")
  f2_msg_has(e, "100")
})

test_that("2f no name: a power that is not 1, 2 or 3 (4.4.19)", {
  e <- f2_err("`r u(2, m^4)`{.uname}")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "units:", ".usym", ".nounit")
  e2 <- f2_err("`r u(2, s^-2)`{.uname}")
  f2_has_class(e2, "weft_value_error")
})

test_that("2f no name: the message carries a YAML example keyed by the unit (4.4.19)", {
  f2_register()
  yml <- c("units:", "  zzpsu:", "    is: base")
  e <- f2_err("`r u(3, zzpsu)`{.uname}", yml)
  f2_msg_has(e, "zzpsu:")
  f2_msg_has(e, "name:")
})

test_that("2f no name: control, a unit with a name in the units: table does not error (4.4.19)", {
  f2_register()
  yml <- c("units:", "  PSU:", "    name: salinity unit")
  expect_equal(f2_ws("`r u(3, PSU)`{.uname}", yml), f2("3~salinity units"))
  expect_equal(f2_ws("`r u(1, PSU)`{.uname}", yml), f2("1~salinity unit"))
})

test_that("2f no name: the error is judged on the classes, not the data (U3, 4.4.19)", {
  f2_register()
  yml <- c("units:", "  zzpsu:", "    is: base")
  # a wording class on a quantity a name may print: the error comes for 3 and for 12 alike
  for (src in c("`r u(3, zzpsu)`{.word}", "`r u(12, zzpsu)`{.word}", "`r u(12, zzpsu)`{.count}",
                "`r u(3, zzpsu)`{.count}", "`r u(0, zzpsu)`{.no}")) {
    e <- f2_err(src, yml)
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, "zzpsu")
  }
  # control: a digit class on the same unit under auto prints the symbol
  expect_equal(f2_ws("`r u(3, zzpsu)`{.num}", yml), f2("3~zzpsu"))
  expect_equal(f2_ws("`r u(12, zzpsu)`{.num}", yml), f2("12~zzpsu"))
})

test_that("2f no name: .count on 12 prints digits yet still needs a name (U3)", {
  # the dictionary is read in the project that then formats: its units go with the project (decision 63)
  dir <- f2_proj()
  e <- tryCatch(withr::with_dir(dir, { f2_register(); weft_str("`r u(12, sites)`{.count}"); NULL }), error = function(e) e)
  f2_has_class(e, "weft_value_error")
  expect_equal(f2_ws("`r u(12, sites)`{.count}", c("units:", "  sites: {name: site}")), f2("12~sites"))
})

# ---- fmt_unit() (3.4.9) ----------------------------------------------------------------------------------

test_that("2f fmt_unit: it is exported and attached (2.1.8)", {
  expect_true("fmt_unit" %in% getNamespaceExports("weft"))
  expect_true(is.function(weft::fmt_unit))
})

test_that("2f fmt_unit: auto and symbol print the symbol text, name the name (3.4.9)", {
  x <- u(5, mg/L)
  expect_equal(f2_tx(fmt_unit(x)), "mg/L")
  expect_equal(f2_tx(fmt_unit(x, unit_form = "symbol")), "mg/L")
  expect_equal(f2_tx(fmt_unit(x, unit_form = "auto")), "mg/L")
  expect_equal(f2_tx(fmt_unit(x, unit_form = "name")), "milligrams per litre")
})

test_that("2f fmt_unit: it is a weft_text of length one with no record and no unit attributes (3.4.9)", {
  r <- fmt_unit(u(5, mg/L), unit_form = "name")
  expect_s3_class(r, "weft_text")
  expect_length(r, 1L)
  expect_null(attr(r, "unit"))
  expect_null(attr(r, "unit_form"))
  expect_null(attr(r, "units"))
  expect_null(attr(r, "number"))
  expect_null(attr(r, "raw"))
})

test_that("2f fmt_unit: fmt_cap() works on it (3.4.9)", {
  expect_equal(f2_tx(fmt_cap(fmt_unit(u(5, mg/L), unit_form = "name"))), "Milligrams per litre")
})

test_that("2f fmt_unit: plural unless x has length one and its number prints '1' (3.4.9)", {
  expect_equal(f2_tx(fmt_unit(u(1, m), unit_form = "name")), "metre")
  expect_equal(f2_tx(fmt_unit(u(1.04, m), unit_form = "name")), "metres")     # prints 1.0
  expect_equal(f2_tx(fmt_unit(u(0, m), unit_form = "name")), "metres")
  expect_equal(f2_tx(fmt_unit(u(c(1, 1), m), unit_form = "name")), "metres")  # length two
  expect_equal(f2_tx(fmt_unit(u(10, year))), "years")
  expect_equal(f2_tx(fmt_unit(u(1, year))), "year")
})

test_that("2f fmt_unit: a string is read as u() reads a unit and takes the plural (3.4.9)", {
  expect_equal(f2_tx(fmt_unit("m^2", unit_form = "name")), "square metres")
  expect_equal(f2_tx(fmt_unit("m", unit_form = "name")), "metres")
  expect_equal(f2_tx(fmt_unit("m")), "m")
  expect_equal(f2_tx(fmt_unit("mg/L")), "mg/L")
})

test_that("2f fmt_unit: unit converts first (3.4.9)", {
  expect_equal(f2_tx(fmt_unit(u(150, cm), unit = "m")), "m")
  expect_equal(f2_tx(fmt_unit(u(150, cm), unit_form = "name", unit = "m")), "metres")
  expect_equal(f2_tx(fmt_unit(u(150, cm))), "cm")
})

test_that("2f fmt_unit: NA is allowed and no number prints (3.4.9)", {
  x <- u(NA_real_, m)
  expect_equal(f2_tx(fmt_unit(x)), "m")
  expect_equal(f2_tx(fmt_unit(x, unit_form = "name")), "metres")
})

test_that("2f fmt_unit: 'none' is a construct error naming the allowed values (3.4.9, errors)", {
  e <- f2_cond(fmt_unit(u(5, m), unit_form = "none"))
  f2_has_class(e, "weft_construct_error")
  f2_msg_has(e, "unit_form", "none")
})

test_that("2f fmt_unit: a bad unit_form is a construct error (errors)", {
  f2_has_class(f2_cond(fmt_unit(u(5, m), unit_form = "bogus")), "weft_construct_error")
})

test_that("2f fmt_unit: neither a quantity nor a string is a value error; a string u() refuses is a unit error (3.4.9)", {
  f2_has_class(f2_cond(fmt_unit(5)), "weft_value_error")
  f2_has_class(f2_cond(fmt_unit(TRUE)), "weft_value_error")
  f2_has_class(f2_cond(fmt_unit("not a unit!!")), "weft_unit_error")
})

test_that("2f fmt_unit: a name that does not exist is the no-name value error (4.4.19)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  withr::defer(weft:::read_config(f2_proj()))
  weft:::read_config(f2_proj(c("units:", "  zzpsu:", "    is: base")))
  e <- f2_cond(fmt_unit(u(3, zzpsu), unit_form = "name"))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "zzpsu")
  expect_equal(f2_tx(fmt_unit(u(3, zzpsu))), "zzpsu")      # control: the symbol needs no name
})

test_that("2f fmt_unit: it takes a unit from a units: entry, with its symbol and name (3.4.9, 9.1.7)", {
  yml <- c("units:", "  zorps:", "    name: zorp", "    symbol: false")
  d <- f2_proj(yml)
  withr::with_dir(d, {
    weft_str("`r u(1, zorps)`{.num}")        # reads the project: registers zorps
    expect_equal(f2_tx(fmt_unit(u(2, zorps), unit_form = "name")), "zorps")
    expect_equal(f2_tx(fmt_unit(u(2, zorps))), "zorps")       # no symbol: the name, plural
    expect_equal(f2_tx(fmt_unit(u(1, zorps))), "zorp")
  })
})

# ---- the spelling by lang: one batched render, en-US (U8, 4.4.16) ------------------------------------------

BATCH_NAMES_US <- c(
  "`r u(5, m)`{.uname}",                    #  1 meters
  "`r u(5, mg/L)`{.uname}",                 #  2 milligrams per liter
  "`r u(2, t)`{.uname}",                    #  3 metric tons
  "`r u(5, \"%\")`{.word}",                 #  4 five percent
  "`r u(2, L)`{.uname}",                    #  5 liters
  "`r u(2, dam)`{.uname}",                  #  6 dekameters
  "`r u(2, kilometers)`{.uname}",           #  7 kilometers
  "`r u(35, \"%\")`{.num}",                 #  8 35% (symbol unchanged)
  "`r u(5, m)`{.num}",                      #  9 5 m
  "`r u(2, ft)`{.uname}",                   # 10 feet
  "`r u(2, m^2)`{.uname}"                   # 11 square meters
)
WANT_NAMES_US <- c("5~meters", "5~milligrams per liter", "2~metric tons", "five~percent", "2~liters",
                   "2~dekameters", "2~kilometers", "35%", "5~m", "2~feet", "2~square meters")

names_us <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- render_rmd(batch_cases(BATCH_NAMES_US), front = "lang: en-US",
                                             in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    cache
  }
})

test_that("2f lang en-US: the en-US spellings apply to names, not to symbols (U8, 4.4.16)", {
  res <- names_us()
  expect_false(res$failed, label = res$message)
  if (res$failed) return(invisible())
  got <- f2_unesc(split_cases(res, length(BATCH_NAMES_US)))
  for (i in seq_along(WANT_NAMES_US)) {
    expect_equal(got[i], f2(WANT_NAMES_US[i]), label = BATCH_NAMES_US[i])
  }
})
