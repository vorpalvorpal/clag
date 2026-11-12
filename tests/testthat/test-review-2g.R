# Regression tests for the review of package 2g (dev/review-2g.md), decided by the
# "Rulings on the review of 2g" at the end of dev/design-2g.md (the rulings win over the
# contract above them and over the review). One or more tests per finding 1-18 and per ruling
# a, b, c, d, k and the zero rule's advice. i and j are "Left", and g is documentation; none.
# The `units` database is session-global: every test installs only made-up tokens (zzg...) that
# are its own, and the default state comes back when it ends (g2_cfg(), g2_restore()). Tests
# about session state run in a child R session (g2_child()).
# `~` in an expected string is U+00A0 (f2()). Non-ASCII is written as \uXXXX.
if (!exists("g2_row")) source(file.path(dirname(Filter(file.exists, c(testthat::test_path("helper-2g.R"), testthat::test_path("..", "helper-2g.R")))[[1]]), "helper-2g.R"))
g2_need()

R2G_SI <- "unit_defaults: si"
R2G_MINUS <- "\u2212"

# helpers every child session starts with: kv() prints KEY=value; rc() reads a project's
# _weft.yml (NULL on success, the condition on failure); cap() returns the value of an
# expression with the warnings it raised.
R2G_CHILD <- paste(
  'kv <- function(k, v) cat(k, "=", gsub("[\\r\\n]+", " ", paste(v, collapse = " ")), "\\n", sep = "")',
  'rc <- function(lines) { d <- tempfile(); dir.create(d); if (length(lines)) writeLines(lines, file.path(d, "_weft.yml")); tryCatch({ weft:::read_config(d); NULL }, error = function(e) e) }',
  'cap <- function(expr) { W <- character(); v <- withCallingHandlers(tryCatch(expr, error = function(e) e), warning = function(w) { W <<- c(W, conditionMessage(w)); invokeRestart("muffleWarning") }); list(v = v, w = W) }',
  'show <- function(r) if (inherits(r, "error")) paste("ERROR:", conditionMessage(r)) else as.character(unclass(r))',
  sep = "\n")
r2g_child <- function(...) g2_child(paste(R2G_CHILD, paste(c(...), collapse = "\n"), sep = "\n"))

# the value of an expression and the warning messages it raised
r2g_warn <- function(expr) {
  w <- character()
  v <- withCallingHandlers(expr, warning = function(c) { w <<- c(w, conditionMessage(c)); invokeRestart("muffleWarning") })
  list(v = v, w = w)
}

# ---- 1: a failed configuration read leaves nothing installed ------------------------------------------------------------

test_that("review 2g #1: a failed read leaves no project token behind, and the next valid read is not poisoned (4.4.21, ruling 1)", {
  out <- r2g_child(
    'for (i in 1:3) {',
    '  def <- c("mi/h", "degC", "1 gal")[i]; tok <- paste0("zzgone", c("a", "b", "c")[i])',
    '  e <- rc(c("units:", paste0("  ", tok, ":"), paste0("    is: ", def)))',
    '  gone <- inherits(tryCatch(units::as_units(tok), error = function(e) e), "error")',
    '  kv(paste0("OK", i), is.null(e) || gone)',
    '}',
    'e1 <- rc(c("units:", "  zzgoned:", "    is: mi/h"))',
    'kv("ERR1", if (is.null(e1)) "none" else class(e1)[1])',
    'e2 <- rc(c("units:", "  zzgoned:", "    is: 2 m"))',
    'kv("ERR2", if (is.null(e2)) "none" else conditionMessage(e2))')
  for (i in 1:3) expect_equal(g2_kv(out, paste0("OK", i)), "TRUE", label = paste("variant", i))
  expect_equal(g2_kv(out, "ERR1"), "weft_config_error")   # control: the read does fail
  expect_equal(g2_kv(out, "ERR2"), "none")
})

test_that("review 2g #1: a failed read leaves the knit session as it was; the token is not a unit afterwards (4.4.21, ruling 1)", {
  out <- r2g_child(
    'e <- rc(c("units:", "  zzgknit:", "    is: mi/h"))',
    'r <- tryCatch(fmt_num(u(2, zzgknit), unit = "m"), error = function(e) e)',
    'kv("R", show(r))',
    'u1 <- tryCatch(u(2, zzgknit), error = function(e) class(e)[1])',
    'kv("U", if (is.character(u1)) u1 else "a unit")')
  expect_false(g2_kv(out, "R") %in% c("2~m", f2("2~m")))
  expect_equal(g2_kv(out, "U"), "weft_unit_error")
})

# ---- 2 and e: a key the units package already reads -----------------------------------------------------------------

test_that("review 2g #2: a base key that units reads in another letter case is a problem that says so (9.1.7, ruling e)", {
  for (row in list(c("Bags", "name: bag"), c("Hours", "name: hour"), c("Meter", "name: emm"))) {
    e <- g2_cfg_err(c("units:", paste0("  ", row[[1]], ":"), "    is: base", paste0("    ", row[[2]])))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, paste0("`", row[[1]], "`"), "(rule 9.1.7)")
    expect_match(f2_msg(e), "read", fixed = TRUE, label = paste(row[[1]], "message says how units reads it"))
  }
  # control: a made-up base key is fine
  expect_null(g2_cfg_err(c("units:", "  zzg2bk:", "    is: base", "    name: widget")))
})

test_that("review 2g #2: a foreign base token that converts to a database unit is not accepted (4.4.21, ruling 2)", {
  out <- r2g_child(
    'units::install_unit("NTU", "1 m")',
    'r <- cap(fmt_num(u(3, NTU), unit = "m"))',
    'kv("R", show(r$v))')
  expect_false(g2_kv(out, "R") == f2("3~m"))
})

# ---- 3: a name over a default row takes its own plural ----------------------------------------------------------------

test_that("review 2g #3: a project name over a default row with a plural derives its own plural (9.1.7, ruling 3)", {
  g2_cfg(c("units:", "  ka:", "    name: kiloyear"))
  expect_equal(g2_nm(u(1, ka)), f2("1~kiloyear"))
  expect_equal(g2_nm(u(12, ka)), f2("12~kiloyears"))
  g2_cfg(c("units:", "  Ma:", "    name: megayear"))
  expect_equal(g2_nm(u(1, Ma)), f2("1~megayear"))
  expect_equal(g2_nm(u(65, Ma)), f2("65~megayears"))
  g2_cfg(c("units:", "  pH:", "    name: acid"))
  expect_match(g2_nm(u(7.2, pH)), "^acids?\u00a07\\.2$")
  expect_false(grepl("pH", g2_nm(u(7.2, pH)), fixed = TRUE))
})

test_that("review 2g #3: a name with its own plural still wins, and a row with no default plural is as before (control)", {
  g2_cfg(c("units:", "  ka:", "    name: kiloyear", "    plural: kiloyeari"))
  expect_equal(g2_nm(u(12, ka)), f2("12~kiloyeari"))
  g2_cfg(c("units:", "  NTU:", "    name: turbidity unit"))
  expect_equal(g2_nm(u(1, NTU)), f2("1~turbidity unit"))
  expect_equal(g2_nm(u(3, NTU)), f2("3~turbidity units"))
})

# ---- 4 and f: weft_str() raises a configuration error -----------------------------------------------------------------

test_that("review 2g #4: weft_str() in a project whose _weft.yml has an error raises the weft_config_error (9.1, ruling f)", {
  g2_restore()
  e <- f2_err("`r u(7.2, pH)`{.num}", "digits: many")
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "digits")
  e2 <- f2_err("`r u(150, \"CFU/100 mL\")`{.num} `r u(3, NTU)`{.uname}", c(R2G_SI, "digits: many"))
  f2_has_class(e2, "weft_config_error")
})

test_that("review 2g #4: control - the same strings from a good project print the default rows", {
  g2_restore()
  expect_equal(f2_ws("`r u(7.2, pH)`{.num} / `r u(60, mph)`{.num}", "unit_form: symbol"), f2("pH~7.2 / 60~mph"))
  expect_equal(f2_ws("`r u(3, NTU)`{.uname}"), f2("3~nephelometric turbidity units"))
})

# ---- 5 and e: a prefix on a database unit ------------------------------------------------------------------------------

test_that("review 2g #5: is: on a key units reads as a prefix and a unit is a problem naming the reading (9.1.7, ruling e)", {
  for (row in list(c("km", "1 mi", "kilo"), c("mL", "1 L", "milli"), c("kft", "1 m", "kilo"))) {
    e <- g2_cfg_err(c("units:", paste0("  ", row[[1]], ":"), paste0("    is: ", row[[2]])))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, paste0("`", row[[1]], "`"), row[[3]], "(rule 9.1.7)")
  }
})

test_that("review 2g #5: a refused row rewrites nothing for the session; the exceptions still read (control)", {
  g2_cfg_err(c("units:", "  km:", "    is: 1 mi"))
  expect_equal(g2_cv(u(5000, m), "km"), f2("5~km"))
  expect_equal(g2_cv(u(5, km/h), "m/s"), f2("1.4~m/s"))
  expect_null(g2_cfg_err(c("units:", "  gal:", "    is: 4.54609 L", "  mt:", "    is: 1 t")))    # default key, misread key
})

# ---- 6 and h: a conflicting foreign token disables its own row only ----------------------------------------------------

test_that("review 2g #6: a conflicting foreign mph disables that row with a warning, and every other unit works (4.4.21, ruling h)", {
  out <- r2g_child(
    'units::install_unit("mph", "1 km/h")',
    'r <- cap(fmt_num(u(5, m)))',
    'kv("M", show(r$v)); kv("W", r$w)',
    'kv("N", show(cap(fmt_num(u(5, NTU)))$v))',
    'kv("P", show(cap(fmt_num(u(7.2, pH)))$v))',
    'e <- rc(NULL)',
    'kv("RC", if (is.null(e)) "ok" else class(e)[1])',
    'kv("M2", show(cap(fmt_num(u(5, m)))$v))')
  expect_equal(g2_kv(out, "M"), f2("5~m"))
  expect_match(g2_kv(out, "W"), "mph", fixed = TRUE)
  expect_equal(g2_kv(out, "N"), f2("5~NTU"))
  expect_equal(g2_kv(out, "P"), f2("pH~7.2"))
  expect_equal(g2_kv(out, "RC"), "ok")
  expect_equal(g2_kv(out, "M2"), f2("5~m"))
})

test_that("review 2g #6: a token weft installed that someone then removes is noticed at the next read (4.4.21, ruling h)", {
  out <- r2g_child(
    'invisible(u(7.2, pH))',
    'units::remove_unit("pH")',
    'e <- rc(NULL)',
    'kv("F", tryCatch(as.numeric(units::set_units(units::set_units(1, "pH", mode = "standard"), "H", mode = "standard")), error = function(e) "not convertible"))',
    'kv("P", show(cap(fmt_num(u(7.2, pH)))$v))')
  expect_equal(g2_kv(out, "F"), "not convertible")        # acidity again, not the picohenry
  expect_equal(g2_kv(out, "P"), f2("pH~7.2"))
})

# ---- 7 and g: what a plain units user sees (stated, not worked around) -----------------------------------------------

test_that("review 2g #7: after weft's first use units shows the redefined symbols, and unloading restores them (4.4.21, ruling g)", {
  out <- r2g_child(
    'dp <- function(tok) tryCatch(units::deparse_unit(units::set_units(5, tok, mode = "standard")), error = function(e) "error")',
    'toks <- c("Myr", "kyr", "gallon", "nautical_mile")',
    'kv("B", vapply(toks, dp, ""))',
    'invisible(u(1, m))',
    'kv("A", vapply(toks, dp, ""))',
    'kv("I", tryCatch({ units::install_unit("zzgmyr", "1 Myr"); "ok" }, error = function(e) "error"))',
    'pkgload::unload("weft")',
    'kv("U", vapply(toks, dp, ""))')
  expect_equal(g2_kv(out, "B"), "Myr kyr gallon nautical_mile")
  expect_equal(g2_kv(out, "A"), "Ma ka gal nmi")      # the ruling states it; weft does not work around it
  expect_equal(g2_kv(out, "I"), "error")
  expect_equal(g2_kv(out, "U"), "Myr kyr gallon nautical_mile")
})

# ---- 8: an is: that names a unit weft installed -----------------------------------------------------------------------

test_that("review 2g #8: an is: naming a unit weft installed is read, and converts (9.1.7, ruling 8)", {
  e <- g2_cfg_err(c("units:", "  zzg8r:", "    is: 1 m", "  zzg8q:", "    is: 1 zzg8r"))   # exactly another row's unit
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg8q`", "`zzg8r`", "same unit")
  g2_cfg(c("units:", "  zzg8r:", "    is: 1 m", "  zzg8q:", "    is: 2 zzg8r"))     # control: a factor was always read
  expect_equal(g2_cv(u(10, zzg8q), "m"), f2("20~m"))
})

test_that("review 2g #8: an is: that is the same unit as another row's is that problem, not 'cannot read' (9.1.7)", {
  e <- g2_cfg_err(c("units:", "  zzg8a:", "    is: 1 s", "  zzg8b:", "    is: 1 sec"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg8b`", "gives the same unit as `zzg8a`")
  expect_false(grepl("not a unit the units package can read", f2_msg(e), fixed = TRUE))
})

# ---- 9: a key units reads is not "installed in this session" ----------------------------------------------------------

test_that("review 2g #9: a key that reads as a prefix on a row above says so, as a configuration error (9.1.7, ruling e)", {
  e <- g2_cfg_err(c("units:", "  zzg9q:", "    is: 1 s", "  kzzg9q:", "    is: 1 m"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`kzzg9q`", "prefix `k`", "`zzg9q`")
  expect_false(grepl("installed in this session", f2_msg(e), fixed = TRUE))
  # control: a key that no row above makes a prefix reads
  expect_null(g2_cfg_err(c("units:", "  kzzg9r:", "    is: 1 m", "  zzg9r:", "    is: 1 s")))
})

test_that("review 2g #9: a key that is the metre's name to units is a problem, not 'installed in this session' (9.1.7, ruling e)", {
  e <- g2_cfg_err(c("units:", "  Meter:", "    is: 1 ft"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`Meter`", "(rule 9.1.7)")
  expect_false(grepl("installed in this session", f2_msg(e), fixed = TRUE))
  e2 <- g2_cfg_err(c(R2G_SI, "units:", "  zzg9s:", "    is: 1 s", "  kzzg9s:", "    is: 1 m"))
  f2_has_class(e2, "weft_config_error")
})

# ---- 10 and c: a spelled number, .no and space: false with a unit before ------------------------------------------------

test_that("review 2g #10: .no on a unit written before the number is a value error (4.4.22, ruling c)", {
  g2_cfg(NULL)
  f2_has_class(f2_cond(fmt_no(u(0, pH))), "weft_value_error")
  f2_has_class(f2_cond(fmt_and(fmt_no(u(c(0, 0), pH)))), "weft_value_error")
  f2_has_class(f2_err("`r u(0, pH)`{.no}"), "weft_value_error")
  # control: a unit after the number says "no metres"; a unit before keeps .word and .count
  expect_equal(f2_tx(fmt_no(u(0, m))), f2("no~metres"))
  expect_equal(f2_tx(fmt_word(u(0, pH))), f2("pH~zero"))
  expect_equal(f2_tx(fmt_word(u(7, pH))), f2("pH~seven"))
  expect_equal(f2_tx(fmt_count(u(3, pH))), f2("pH~three"))
})

test_that("review 2g #10: space: false keeps the space before a spelled number and in the name form of pH (4.4.22, ruling c)", {
  g2_cfg(c("units:", "  pH:", "    space: false"))
  expect_equal(f2_tx(fmt_word(u(7, pH))), f2("pH~seven"))
  expect_equal(f2_tx(fmt_count(u(3, pH))), f2("pH~three"))
  expect_equal(g2_nm(u(7.2, pH)), f2("pH~7.2"))
  f2_has_class(f2_cond(fmt_no(u(0, pH))), "weft_value_error")
  expect_equal(g2_num(u(7.2, pH)), "pH7.2")                # control: the symbol form is governed
})

test_that("review 2g #10: a project unit written before, with space: false, keeps its space in the name form and a spelled number (4.4.22, ruling c)", {
  yml <- c("units:", "  zzg10d:", "    is: base", "    before: true", "    symbol: \"$\"", "    space: false",
           "    name: dollar")
  g2_cfg(yml)
  expect_equal(g2_num(u(5, zzg10d)), "$5")                  # control: the symbol form
  expect_equal(f2_ws("`r u(5, zzg10d)`{.uname}", yml), f2("dollars~5"))
  expect_equal(f2_ws("`r u(5, zzg10d)`{.word}", yml), f2("dollars~five"))
  expect_equal(g2_nm(u(1, zzg10d)), f2("dollar~1"))
})

# ---- 11: the /100 mL rows ---------------------------------------------------------------------------------------------

test_that("review 2g #11: the symbol CFU/100 mL has a no-break space inside it, so a line cannot break in the unit (4.4.21)", {
  g2_cfg(NULL)
  expect_equal(g2_num(g2_u(150, "CFU/100 mL")), f2("150~CFU/100~mL"))
  expect_equal(g2_num(g2_u(150, "MPN/100 mL")), f2("150~MPN/100~mL"))
})

test_that("review 2g #11: a count per 100 mL in a compound, or per another volume, is not printed as a mangled factor (4.4.21)", {
  g2_cfg(NULL)
  per_day <- g2_num(g2_u(150, "CFU/100 mL") / u(1, d))
  expect_false(grepl("100d", per_day, fixed = TRUE), label = per_day)
  expect_false(grepl("100[a-zA-Z]", per_day), label = per_day)
  for (tok in c("CFU/100 L", "CFU/10 mL", "MPN/100 g")) {
    x <- g2_num(g2_u(150, tok))
    expect_false(grepl("\\(\\d+[a-zA-Z]", x), label = paste(tok, "->", x))
  }
})

test_that("review 2g #11: multiplying a count per 100 mL by a volume never prints 15,000 CFU/100 (4.4.21)", {
  g2_cfg(NULL)
  got <- tryCatch(g2_num(g2_u(150, "CFU/100 mL") * u(100, mL)), error = function(e) "error")
  expect_false(grepl("15,000", got, fixed = TRUE), label = got)
})

# ---- 12 and d: a document row without is: over a project is: row ----------------------------------------------------------

test_that("review 2g #12: a document row that drops a project's is: is a problem naming the document and the field (9.1.7, ruling d)", {
  e <- g2_cfg_err(c("units:", "  zzg12a:", "    is: 1 m"), front = list(units = list(zzg12a = list(name = "zebra"))))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg12a`", "`is`")
  expect_match(f2_msg(e), "document", ignore.case = TRUE)
  expect_false(grepl("_weft.yml: units", f2_msg(e), fixed = TRUE), label = "the project file is not at fault")
  e2 <- g2_cfg_err(c("units:", "  zzg12a:", "    is: 1 m", "    name: zebra"),
                   front = list(units = list(zzg12a = list(plural = "zebrae"))))
  f2_has_class(e2, "weft_config_error")
  expect_match(f2_msg(e2), "document", ignore.case = TRUE)
})

test_that("review 2g #12: control - a document row that restates is: reads and replaces the project's row whole (9.1.7, ruling d)", {
  g2_cfg(c("units:", "  zzg12b:", "    is: 1 m", "    name: zebra"),
         front = list(units = list(zzg12b = list(is = "1 m", name = "okapi"))))
  expect_equal(g2_nm(u(2, zzg12b)), f2("2~okapis"))
})

# ---- 13: a refused or duplicate is: row gets one problem ---------------------------------------------------------------

test_that("review 2g #13: a duplicate is: row gets the one problem, not a second false one (9.1.7)", {
  e <- g2_cfg_err(c("units:", "  zzg13a:", "    is: 1 s", "  zzg13b:", "    is: 1 s"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzg13b`", "gives the same unit as `zzg13a`")
  expect_false(grepl("not a unit the units package can read", f2_msg(e), fixed = TRUE))
})

test_that("review 2g #13: a refused is: (mt, kNTU, Ga) and a unit equal to a default row's get one problem each (9.1.7)", {
  for (def in c("1 mt", "1 kNTU", "1 Ga", "mi/h")) {
    e <- g2_cfg_err(c("units:", "  zzg13c:", paste0("    is: ", def)))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "`zzg13c`")
    expect_false(grepl("not a unit the units package can read", f2_msg(e), fixed = TRUE), label = def)
  }
})

# ---- 14: the forms of is: ---------------------------------------------------------------------------------------------

test_that("review 2g #14: an is: that is not base, a number or a number and a unit is the format problem (9.1.7)", {
  for (bad in c("2 m 3", "3 2 m")) {
    e <- g2_cfg_err(c("units:", "  zzg14x:", paste0("    is: ", bad)))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "`zzg14x`", "`is` must be `base`, a positive number, or a number and a unit", "(rule 9.1.7)")
  }
  # control: the listed forms read
  for (ok in c("base", "0.5", "2 m", "2 mi/h", "m")) expect_null(g2_cfg_err(c("units:", "  zzg14k:", paste0("    is: ", ok))), label = ok)
})

# ---- 15: units_options set before weft's first use --------------------------------------------------------------------

test_that("review 2g #15: auto_convert_names_to_symbols = FALSE does not change what weft stores or prints (4.4.20)", {
  out <- r2g_child(
    'units::units_options(auto_convert_names_to_symbols = FALSE)',
    'kv("DEG", show(fmt_num(u(5, degC))))',
    'kv("CEL", show(fmt_num(u(5, celsius))))',
    'kv("METRE", units::deparse_unit(u(5, metre)))',
    'kv("PRINT", show(fmt_num(u(5, metre))))')
  expect_equal(g2_kv(out, "DEG"), f2("5~\u00b0C"))
  expect_equal(g2_kv(out, "CEL"), f2("5~\u00b0C"))
  expect_equal(g2_kv(out, "METRE"), "m")
  expect_equal(g2_kv(out, "PRINT"), f2("5~m"))
})

# ---- 16: the trap message fits the token ------------------------------------------------------------------------------

test_that("review 2g #16: the trap message for ca names m^2, not the km/h and Gyr advice (4.4.20)", {
  g2_cfg(NULL)
  e <- f2_cond(u(1, ca))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "`ca`", "centiare", "m^2")
  expect_false(grepl("km/h", f2_msg(e), fixed = TRUE))
  # control: kph and Ga keep the advice that fits them
  f2_msg_has(f2_cond(u(1, kph)), "km/h")
  f2_msg_has(f2_cond(u(1, Ga)), "Gyr")
})

test_that("review 2g #16: the message for daa does not give the km/h advice, and says how to get the unit (4.4.20)", {
  g2_cfg(NULL)
  e <- f2_cond(u(1, daa))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "`daa`", "dekaare", "unit_defaults: si")
  expect_false(grepl("km/h", f2_msg(e), fixed = TRUE))
  expect_false(grepl("Gyr", f2_msg(e), fixed = TRUE))
})

test_that("review 2g #16: fmt_unit() on a refused string says fmt_unit(), not u() (4.4.20)", {
  g2_cfg(NULL)
  e <- f2_cond(fmt_unit("kph"))
  f2_has_class(e, "weft_unit_error")
  expect_match(f2_msg(e), "^fmt_unit\\(\\): ")
  expect_match(f2_msg(f2_cond(u(1, kph))), "^u\\(\\): ")     # control
})

# ---- 17 and k: VA and Bd names -----------------------------------------------------------------------------------------

test_that("review 2g #17: VA is named volt-ampere and Bd baud, the plural of baud being baud (4.4.19, ruling k)", {
  g2_cfg(NULL)
  expect_equal(g2_nm(u(2, VA)), f2("2~volt-amperes"))
  expect_equal(g2_nm(u(1, VA)), f2("1~volt-ampere"))
  expect_equal(g2_nm(u(2, Bd)), f2("2~baud"))
  expect_equal(g2_nm(u(1, Bd)), f2("1~baud"))
  expect_equal(g2_nm(u(2, MVA)), f2("2~megavolt-amperes"))
  expect_equal(g2_nm(u(2, W)), f2("2~watts"))               # control
})

# ---- 18: the deparse_unit() line of the contract -----------------------------------------------------------------------

test_that("review 2g #18: under si the token mt is kept in a quotient, which deparse_unit() writes with a negative power (4.4.20)", {
  g2_cfg(R2G_SI)
  expect_equal(units::deparse_unit(g2_u(5, "mt/d")), "mt d-1")
  expect_equal(g2_num(g2_u(5, "mt/d")), f2("5~mt/d"))
})

# ---- a: twins by another route -----------------------------------------------------------------------------------------

test_that("review 2g #a: Ci is a twin of Bq and Hz, and rem of Sv and Gy (4.4.14, ruling a)", {
  g2_cfg(NULL)
  f2_has_class(f2_cond(fmt_num(u(2, Ci), unit = "Hz")), "weft_value_error")
  f2_has_class(f2_cond(fmt_num(u(200, rem), unit = "Gy")), "weft_value_error")
  expect_equal(g2_cv(u(2000, mSv), "Sv"), f2("2~Sv"))      # control: within a member
  expect_equal(g2_cv(u(2, Sv), "J/kg"), f2("2~J/kg"))          # control: to the SI definition
})

test_that("review 2g #a: a project unit defined as a twin is a twin (4.4.14, ruling a)", {
  g2_cfg(c("units:", "  zzga:", "    is: 1 Sv", "    name: zeta dose"))
  f2_has_class(f2_cond(fmt_num(u(2, zzga), unit = "Gy")), "weft_value_error")
})

test_that("review 2g #a: of_n(), about() and a claim that compare twins are the twin value error (4.4.14, ruling a)", {
  g2_cfg(NULL)
  f2_has_class(f2_cond(of_n(u(2, Sv), u(4, Gy), "dose", "doses")), "weft_value_error")
  # about(u(1, Sv) / u(2, Gy)) is not asserted: units cancels the twins before weft sees them (arithmetic is left to units, G2)
  f2_has_class(f2_cond(claim(u(2, Sv), . > u(1, Gy))), "weft_value_error")
  # control: the same unit compares
  expect_no_error(of_n(u(2, Sv), u(4, Sv), "dose", "doses"))
  expect_no_error(claim(u(2, Sv), . > u(1, Sv)))
})

# ---- b: a negative number with a unit before ----------------------------------------------------------------------------

test_that("review 2g #b: a negative number with a unit before prints the unit, the space, then the sign (4.4.22, ruling b)", {
  g2_cfg(NULL)
  expect_equal(g2_num(u(-0.4, pH)), f2(paste0("pH~", R2G_MINUS, "0.4")))
  expect_equal(f2_tx(fmt_range(u(c(-5, 5), pH))), f2(paste0("pH~", R2G_MINUS, "5 to 5")))
  expect_equal(f2_tx(fmt_and(fmt_num(u(c(-5, 5), pH)))), f2(paste0("pH~", R2G_MINUS, "5 and 5")))
})

test_that("review 2g #b: with space: false the unit goes before the sign with no space (4.4.22, ruling b)", {
  g2_cfg(c("units:", "  zzgbd:", "    is: base", "    before: true", "    symbol: \"$\"", "    space: false", "    name: dollar"))
  expect_equal(g2_num(u(-5, zzgbd)), paste0("$", R2G_MINUS, "5"))
  expect_equal(g2_num(u(5, zzgbd)), "$5")                    # control
})

# ---- the zero rule's advice ---------------------------------------------------------------------------------------------

test_that("review 2g zero rule: the warning for a quantity that prints 0.0 names digits, sigfig and the prefixed unit (4.4.13)", {
  g2_cfg(NULL)
  r <- r2g_warn(fmt_num(u(0.001, "m")))
  expect_equal(f2_tx(r$v), f2("0.0~m"))
  expect_length(r$w, 1)
  expect_match(r$w, "printed as 0.0", fixed = TRUE)
  expect_match(r$w, "digits", fixed = TRUE)
  expect_match(r$w, "sigfig", fixed = TRUE)
  expect_match(r$w, "unit\\s*=\\s*\"mm\"")
  r2 <- r2g_warn(fmt_num(u(0.002, "g")))
  expect_match(r2$w, "unit\\s*=\\s*\"mg\"")
})

test_that("review 2g zero rule: for a compound unit the warning names digits and sigfig and no prefixed unit (4.4.13)", {
  g2_cfg(NULL)
  r <- r2g_warn(fmt_num(u(0.001, "mg/L")))
  expect_equal(f2_tx(r$v), f2("0.0~mg/L"))
  expect_length(r$w, 1)
  expect_match(r$w, "digits", fixed = TRUE)
  expect_match(r$w, "sigfig", fixed = TRUE)
  expect_false(grepl("unit\\s*=", r$w))
})
