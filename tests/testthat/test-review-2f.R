# Regression tests for the review of package 2f (dev/review-2f.md), decided by the
# "Rulings on the review of 2f" at the end of dev/design-2f.md (the rulings win over the
# contract above them and over the review). One or more tests per finding 1-16 and per
# ruling a, b, c, d, f. g, h and i are "Left" and have none. Made-up content only.
# `~` in an expected string is U+00A0 (f2()). Non-ASCII is written as \uXXXX.
if (!exists("f2_ws")) source(testthat::test_path("helper-2f.R"))
if (!exists("render_rmd")) source(testthat::test_path("..", "helper-render.R"))

# `u(<n>, <token>)` for a token held in a string, so a loop can try many tokens
r2_u <- function(n, token) eval(bquote(u(.(n), .(as.name(token)))))
# the text of fmt_num() on u(n, token)
r2_num <- function(n, token) f2_tx(fmt_num(r2_u(n, token)))
# the name fmt_unit() gives under the name form
r2_nm <- function(n, token) f2_tx(fmt_unit(r2_u(n, token), unit_form = "name"))
# a project directory holding `units:` lines, and the config error a read of it raises
r2_units_err <- function(lines, env = parent.frame()) {
  withr::local_envvar(WEFT_DRAFT = NA, .local_envir = env)
  dir <- f2_proj(c("units:", lines), env = env)
  e <- f2_cond(weft:::read_config(dir))
  e
}
# the knit-time value error of a src, in a project with `yml`
r2_two_rules <- function(msg) grepl("\\(rule [0-9.]+\\) \\(rule", msg)

# ---- 1: a symbol and no name is no name, never "s" ---------------------------------------------

test_that("review 2f #1: a database row with a symbol and an empty name has no name, so a name is a value error (4.4.19)", {
  for (tok in c("ppm", "psi", "kt", "cmH2O", "rpm")) {
    e <- f2_cond(f2_tx(fmt_word(r2_u(5, tok))))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, tok)
    e2 <- f2_cond(fmt_unit(r2_u(5, tok), unit_form = "name"))
    f2_has_class(e2, "weft_value_error")
    e3 <- f2_cond(fmt_num(r2_u(1, tok), unit_form = "name"))
    f2_has_class(e3, "weft_value_error")
  }
  f2_has_class(f2_cond(fmt_count(u(3, psi))), "weft_value_error")
  f2_has_class(f2_cond(fmt_no(u(0, kt))), "weft_value_error")
  f2_has_class(f2_err("`r u(5, cmH2O)`{.uname}"), "weft_value_error")
})

test_that("review 2f #1: control - the symbol of such a unit prints as typed, and a unit with a name still has it (4.4.19)", {
  expect_equal(r2_num(5, "ppm"), f2("5~ppm"))
  expect_equal(r2_num(3, "psi"), f2("3~psi"))
  expect_equal(f2_ws("`r u(5, ppm)`{.usym}"), f2("5~ppm"))
  expect_equal(f2_tx(fmt_word(u(5, m))), f2("five~metres"))
})

# ---- 2: # carries the unit on every route, whatever classes the span has --------------------------

test_that("review 2f #2: a back-reference # keeps the quantity when the span has a class of its own (4.4.4, ruling 2)", {
  head_id <- "`r u(5, m)`{#a} "
  expect_match(f2_ws(paste0(head_id, "[# x | # xs]{n=\"#a\" .word}")), f2("five~metres xs$"))
  expect_match(f2_ws(paste0(head_id, "[# x | # xs]{n=\"#a\" digits=2}")), f2("5.00~m xs$"))
  expect_match(f2_ws(paste0(head_id, "[# x | # xs]{n=\"#a\" .uname}")), f2("5~metres xs$"))
  expect_match(f2_ws(paste0(head_id, "[# x | # xs]{n=\"#a\" .nounit}")), "5 xs$")
  expect_match(f2_ws(paste0(head_id, "[# x | # xs]{n=\"#a\" unit=\"cm\"}")), f2("500~cm xs$"))
})

test_that("review 2f #2: a sign span built from a formatter's text keeps the unit under a class of its own (4.4.4, ruling 2)", {
  expect_equal(f2_ws("[up # | down #]{sign=\"fmt_num(u(-3, m))\" .word}"), f2("down three~metres"))
  expect_equal(f2_ws("[up # | down #]{sign=\"fmt_num(u(-3, m))\" .uname}"), f2("down 3~metres"))
})

test_that("review 2f #2: control - without a class of its own the unit is there (4.4.4)", {
  expect_match(f2_ws("`r u(5, m)`{#a .uname} [# x | # xs]{n=\"#a\"}"), f2("5~metres xs$"))
  expect_equal(f2_ws("[# x | # xs]{n=\"u(5, m)\" .word}"), f2("five~metres xs"))
})

# ---- 3: a PDF render builds for ohm, arc minute and arc second ----------------------------------

r2_render_pdf <- function(engine = NULL, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  rmd <- file.path(dir, "doc.Rmd")
  fm <- c("---", "output:", "  pdf_document:", if (!is.null(engine)) paste0("    latex_engine: ", engine), "---")
  writeLines(c(fm, "",
               "```{r, include=FALSE}", "library(weft)", "weft_setup()", "```", "",
               "An ohm `r u(5, ohm)`{.num}, a minute `r u(5, arcmin)`{.num} and a second `r u(5, arc_second)`{.num}.",
               ""), rmd, useBytes = TRUE)
  out <- tryCatch(rmarkdown::render(rmd, quiet = TRUE, envir = new.env()), error = function(e) e)
  list(out = out, pdf = file.path(dir, "doc.pdf"))
}

test_that("review 2f #3: a knit to pdflatex builds for u(5, ohm), an arc minute and an arc second (1.4.18, ruling 3)", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("pdflatex")), "no pdflatex")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  r <- r2_render_pdf()
  expect_false(inherits(r$out, "error"), label = if (inherits(r$out, "error")) conditionMessage(r$out) else "")
  expect_true(file.exists(r$pdf))
})

test_that("review 2f #3: a knit to xelatex builds, and the primes survive into the PDF text (1.4.18, ruling 3)", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("xelatex")), "no xelatex")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  r <- r2_render_pdf("xelatex")
  expect_false(inherits(r$out, "error"), label = if (inherits(r$out, "error")) conditionMessage(r$out) else "")
  expect_true(file.exists(r$pdf))
  if (nzchar(Sys.which("pdftotext")) && file.exists(r$pdf)) {
    txt <- system2("pdftotext", c("-enc", "UTF-8", shQuote(r$pdf), "-"), stdout = TRUE, stderr = FALSE)
    txt <- paste(txt, collapse = "\n")
    expect_true(grepl("′", txt, fixed = TRUE), label = "the prime is in the extracted text")
    expect_true(grepl("″", txt, fixed = TRUE), label = "the double prime is in the extracted text")
    expect_true(grepl("Ω", txt, fixed = TRUE), label = "the ohm sign is in the extracted text")
  }
})

test_that("review 2f #3: control - the unit text itself holds the ohm sign and the primes (4.4.8)", {
  expect_equal(r2_num(5, "ohm"), f2("5~Ω"))
  expect_equal(r2_num(5, "arcmin"), f2("5′"))
  expect_equal(r2_num(5, "arc_second"), f2("5″"))
})

# ---- 4: a collapse over spelled numbers ---------------------------------------------------------------

test_that("review 2f #4: a collapse of spelled numbers puts the name after them under auto, and the name form too (4.4.15, ruling 4)", {
  q <- u(c(3, 5), m)
  expect_equal(f2_tx(fmt_and(fmt_word(q), unit_form = "auto")), f2("three and five~metres"))
  expect_equal(f2_tx(fmt_range(fmt_word(q), unit_form = "auto")), f2("three–five~metres"))
  # control: the form NULL and "name" already do
  expect_equal(f2_tx(fmt_and(fmt_word(q))), f2("three and five~metres"))
  expect_equal(f2_tx(fmt_and(fmt_word(q), unit_form = "name")), f2("three and five~metres"))
})

test_that("review 2f #4: a collapse of spelled numbers under symbol is a value error (U4, ruling 4)", {
  q <- u(c(3, 5), m)
  f2_has_class(f2_cond(fmt_and(fmt_word(q), unit_form = "symbol")), "weft_value_error")
  f2_has_class(f2_cond(fmt_range(fmt_word(q), unit_form = "symbol")), "weft_value_error")
  f2_has_class(f2_cond(fmt_and(fmt_no(u(c(0, 0), m)), unit_form = "symbol")), "weft_value_error")
  # control: digits under symbol, and the class form where .usym implies .num
  expect_equal(f2_tx(fmt_and(q, unit_form = "symbol")), f2("3 and 5~m"))
  expect_equal(f2_ws("`r fmt_word(u(c(3, 5), m))`{.and .usym}"), f2("3 and 5~m"))
})

# ---- 5: a plural-only entry for a prefixed unit, as a factor ---------------------------------------------

test_that("review 2f #5: a plural-only entry for a prefixed unit does not get the prefix again as a factor (4.4.16)", {
  yml <- c("units:", "  km: {plural: klicks}", "  ug: {plural: mikes}")
  expect_equal(f2_ws("`r u(5, km/h)`{.uname}", yml), f2("5~klicks per hour"))
  expect_equal(f2_ws("`r u(5, ug/L)`{.uname}", yml), f2("5~mikes per litre"))
  # control: the whole-unit path, and the singular
  expect_equal(f2_ws("`r u(5, km)`{.uname}", yml), f2("5~klicks"))
  expect_equal(f2_ws("`r u(1, km/h)`{.uname}", yml), f2("1~kilometre per hour"))
})

# ---- 6: a unit class on .range keeps the decimals --------------------------------------------------------

test_that("review 2f #6: a unit class on .range changes the unit only, not the decimals (1.4.4, 1.4.7)", {
  en <- "–"
  f2_rows(c("`r u(c(1, 1.25), m)`{.range .uname}", "`r u(c(1, 1.25), m)`{.range .usym}",
            "`r u(c(1, 1.25), m)`{.range .nounit}", "`r u(c(1, 1.25), m)`{.range .num}"),
          c(paste0("1.0", en, "1.3~metres"), paste0("1.0", en, "1.3~m"), paste0("1.0", en, "1.3"),
            paste0("1.0", en, "1.3~m")))
  expect_equal(f2_ws("[# x | # xs]{n=\"u(c(1, 1.25), m)\" .range .uname}"), f2(paste0("1.0", en, "1.3~metres xs")))
  # the argument and the class agree
  expect_equal(f2_tx(fmt_range(u(c(1, 1.25), m), unit_form = "name")), f2(paste0("1.0", en, "1.3~metres")))
})

test_that("review 2f #6: control - .range alone keeps both ends to the same decimals (1.4.4)", {
  expect_equal(f2_ws("`r u(c(1, 1.25), m)`{.range}"), f2("1.0–1.3~m"))
})

# ---- 7: .cap never changes a symbol ----------------------------------------------------------------------

# the text is the symbol unchanged, or the call is refused with a weft error
r2_symbol_kept <- function(expr, want) {
  got <- tryCatch(f2_tx(expr), error = function(e) e)
  if (inherits(got, "error")) {
    expect_true(inherits(got, "weft_error"), label = paste("a refusal is a weft error:", conditionMessage(got)))
  } else {
    expect_equal(got, want)
  }
}

test_that("review 2f #7: .cap leaves a unit symbol alone, as a prefix's case is its meaning (4.4.16)", {
  r2_symbol_kept(fmt_cap(fmt_unit(u(1, mL))), "mL")
  r2_symbol_kept(fmt_cap(fmt_unit(u(1, mg/L))), "mg/L")
  r2_symbol_kept(fmt_cap(fmt_unit(u(1, ms))), "ms")
  r2_symbol_kept(fmt_cap(fmt_unit(u(2, mm))), "mm")
  got <- tryCatch(f2_ws("# Volume (`r fmt_unit(u(1, mL))`{.cap})"), error = function(e) NULL)
  if (!is.null(got)) expect_equal(got, "# Volume (mL)")
})

test_that("review 2f #7: control - .cap capitalises a name, and a plain word (4.4.16)", {
  expect_equal(f2_tx(fmt_cap(fmt_unit(u(1, mL), unit_form = "name"))), "Millilitre")
  expect_equal(f2_tx(fmt_cap("metre")), "Metre")
})

# ---- 8: which name a unit gets ----------------------------------------------------------------------------

test_that("review 2f #8: a unit typed as a name prints the name typed, never the database's technical name (4.4.17, ruling 8)", {
  expect_equal(r2_num(5, "knot"), f2("5~knots"))
  expect_equal(r2_num(1, "knot"), f2("1~knot"))
  expect_equal(r2_num(5, "byte"), f2("5~bytes"))
  expect_equal(r2_num(5, "revolution"), f2("5~revolutions"))
  expect_equal(r2_nm(5, "knot"), "knots")
  expect_equal(r2_nm(5, "byte"), "bytes")
  expect_equal(r2_nm(5, "revolution"), "revolutions")
})

test_that("review 2f #8: the common words the review lists print no technical word, in either form (4.4.17, ruling 8)", {
  bad <- c(cup = "liquid", quart = "liquid", gallon = "liquid", ton = "short", byte = "octet",
           kilobyte = "octet", megabyte = "octet", revolution = "circle", cycle = "circle",
           Btu = "IT", torr = "_", knot = "international")
  for (tok in names(bad)) {
    expect_false(grepl(bad[[tok]], r2_num(5, tok), fixed = TRUE), label = paste(tok, "default:", r2_num(5, tok)))
    expect_false(grepl(bad[[tok]], r2_nm(5, tok), fixed = TRUE), label = paste(tok, "name:", r2_nm(5, tok)))
  }
  expect_true(grepl("kilobytes", r2_num(5, "kilobyte"), fixed = TRUE))
  expect_true(grepl("cycles", r2_num(5, "cycle"), fixed = TRUE))
  expect_true(grepl("gallons", r2_num(5, "gallon"), fixed = TRUE))
})

test_that("review 2f #8: the names that showed database artefacts read as a person writes them (4.4.17, ruling 8)", {
  # kilocalorie, not kiloIT calorie
  w <- f2_tx(fmt_word(u(1, kcal)))
  expect_false(grepl("IT", w, fixed = TRUE), label = w)
  expect_true(grepl("calorie", w, fixed = TRUE), label = w)
  # degrees Fahrenheit: singular and plural agree, capital F
  one <- r2_nm(1, "degF"); many <- r2_nm(5, "degF")
  expect_true(grepl("^degree ", one), label = one)
  expect_true(grepl("^degrees ", many), label = many)
  expect_true(grepl("Fahrenheit", one, fixed = TRUE), label = one)
  expect_true(grepl("Fahrenheit", many, fixed = TRUE), label = many)
  # horsepower, with no "shaft"
  hp <- r2_nm(5, "hp")
  expect_true(grepl("horsepower", hp, fixed = TRUE), label = hp)
  expect_false(grepl("shaft", hp, fixed = TRUE), label = hp)
})

test_that("review 2f #8: control - a unit typed as a name that has a symbol still prints the symbol, and a project name wins (U11)", {
  expect_equal(r2_num(5, "metre"), f2("5~m"))
  expect_equal(r2_num(5, "degF"), f2("5~°F"))
  expect_equal(f2_ws("`r u(5, knot)`{.uname}", c("units:", "  knot: {name: kn, plural: kns}")), f2("5~kns"))
})

# ---- 9, e: a unit that units reads as another is refused ----------------------------------------------------

test_that("review 2f #9/e: u() refuses a unit that units reads as a different unit, saying what it was read as (4.4.17, ruling 9/e)", {
  for (tok in c("Sv", "Bq", "Mg", "Bd", "VA", "mt", "ut")) {
    e <- f2_cond(r2_u(5, tok))
    expect_false(is.null(e), label = paste(tok, "is refused"))
    if (!is.null(e)) {
      expect_true(inherits(e, "weft_unit_error"), label = paste(tok, "class"))
      expect_true(grepl(tok, conditionMessage(e), fixed = TRUE), label = conditionMessage(e))
    }
  }
  e <- f2_cond(u(5, Sv))
  if (!is.null(e)) expect_true(grepl("Gy", conditionMessage(e), fixed = TRUE), label = conditionMessage(e))
})

test_that("review 2f #9/e: read_dict() has a problem for such a unit (ruling 9/e)", {
  e <- f2_cond(read_dict(f2_dict_file("dose: {value: 3, type: quantity, unit: Sv, definition: \"A dose.\"}")))
  f2_has_class(e, "weft_dict_error")
  f2_msg_has(e, "Sv")
})

test_that("review 2f #9/e: control - the unit it was read as is itself fine (4.4.17)", {
  expect_equal(r2_num(5, "Gy"), f2("5~Gy"))
  expect_equal(r2_num(5, "Hz"), f2("5~Hz"))
  expect_equal(r2_num(5, "t"), f2("5~t"))
})

# ---- 10: mbar, kbar and Mbar have a name -----------------------------------------------------------------

test_that("review 2f #10: a prefix symbol before bar gives a name, as millibar does (4.4.17 step 4)", {
  expect_equal(r2_nm(5, "mbar"), "millibars")
  expect_equal(r2_nm(1, "mbar"), "millibar")
  expect_equal(r2_nm(5, "kbar"), "kilobars")
  expect_equal(r2_nm(5, "Mbar"), "megabars")
  expect_equal(r2_num(5, "mbar"), f2("5~mbar"))
})

test_that("review 2f #10: control - millibar and bar already have a name (4.4.17)", {
  expect_equal(r2_nm(5, "millibar"), "millibars")
  expect_equal(r2_nm(5, "bar"), "bars")
})

# ---- 11: space: false governs a symbol only ---------------------------------------------------------------

test_that("review 2f #11: space false on a unit with no symbol leaves its name its space (4.4.8, ruling 11)", {
  yml <- c("units:", "  zzqs:", "    name: site", "    symbol: false", "    space: false",
           "  yr:", "    space: false")
  expect_equal(f2_ws("`r u(5, zzqs)`{.num}", yml), f2("5~sites"))
  expect_equal(f2_ws("`r u(5, zzqs)`{.uname}", yml), f2("5~sites"))
  expect_equal(f2_ws("`r u(5, year)`{.num}", yml), f2("5~years"))
  expect_equal(f2_tx(fmt_num(u(5, year))), f2("5~years"))
})

test_that("review 2f #11: control - space false still takes the space off a symbol (R3, U13)", {
  yml <- c("units:", "  zzqt:", "    name: quark", "    symbol: zq", "    space: false")
  expect_equal(f2_ws("`r u(3, zzqt)`{.num}", yml), "3zq")
  expect_equal(f2_ws("`r u(3, zzqt)`{.uname}", yml), f2("3~quarks"))
})

# ---- 12: fmt_unit() ----------------------------------------------------------------------------------------

test_that("review 2f #12: fmt_unit() of a formatter's text gives its unit or says to pass the quantity, not 'not a unit' (3.4.9)", {
  for (x in list(fmt_num(u(5, m)), fmt_word(u(1, m)))) {
    got <- tryCatch(f2_tx(fmt_unit(x)), error = function(e) e)
    if (inherits(got, "error")) {
      expect_false(grepl("is not a unit", conditionMessage(got), fixed = TRUE), label = conditionMessage(got))
      expect_true(grepl("quantity", conditionMessage(got), fixed = TRUE), label = conditionMessage(got))
    } else {
      expect_true(got %in% c("m", "metre"), label = got)
    }
  }
})

test_that("review 2f #12: fmt_unit() on a string applies unit, or refuses; it does not drop it silently (3.4.9)", {
  got <- tryCatch(f2_tx(fmt_unit("m", unit = "cm")), error = function(e) e)
  if (inherits(got, "error")) expect_true(inherits(got, "weft_error")) else expect_equal(got, "cm")
})

test_that("review 2f #12: fmt_unit() of a blank string words the error as u() does (3.4.9)", {
  e <- f2_cond(fmt_unit(""))
  expect_false(is.null(e))
  f2_msg_has(e, "blank")
  # control: the quantity branch applies unit
  expect_equal(f2_tx(fmt_unit(u(5, m), unit = "cm")), "cm")
  expect_equal(f2_tx(fmt_unit(u(5, m))), "m")
})

# ---- 13: the no-name advice for CFU/100 mL -----------------------------------------------------------------------

test_that("review 2f #13: the no-name error for CFU/100 mL names the whole unit as the author wrote it (4.4.19)", {
  f2_register()
  e <- f2_cond(f2_tx(fmt_word(u(5, "CFU/100 mL"))))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "CFU/100 mL", "100")
})

test_that("review 2f #13: control - a unit whose only problem is one factor names that factor (4.4.19)", {
  f2_register()
  e <- f2_cond(f2_tx(fmt_word(u(5, "CFU/L"))))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "CFU")
})

# ---- 14: the negative-power message --------------------------------------------------------------------------------

test_that("review 2f #14: the negative-power message quotes the spelling the author wrote and the quotient to write (4.4.19)", {
  e <- f2_cond(fmt_num(u(3, "s^-2"), unit_form = "name"))
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, "s^-2", "1/s^2")
})

test_that("review 2f #14: control - the quotient spelling has a name (4.4.18)", {
  expect_equal(f2_ws("`r u(3, \"1/s^2\")`{.uname}"), f2("3~per second squared"))
})

# ---- 15: the unit_form: symbol error --------------------------------------------------------------------------------

test_that("review 2f #15: the symbol error for .no quotes what .no would print, not 'three m' (4.4.15)", {
  e <- f2_err("`r u(0, m)`{.no}", "unit_form: symbol")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, ".no", "symbol")
  expect_false(grepl("three m", f2_msg(e), fixed = TRUE), label = f2_msg(e))
})

test_that("review 2f #15: a unit with no symbol does not raise the symbol error under unit_form symbol (9.1.7, ruling c)", {
  yml <- c("unit_form: symbol", "units:", "  zzus:", "    name: site", "    symbol: false")
  expect_null(f2_err("`r u(5, zzus)`{.word}", yml))
  expect_equal(f2_ws("`r u(5, year)`{.word}", "unit_form: symbol"), f2("five~years"))
})

test_that("review 2f #15: control - a unit with a symbol still gets the error that names .word (4.4.15)", {
  e <- f2_err("`r u(3, m)`{.word}", "unit_form: symbol")
  f2_has_class(e, "weft_value_error")
  f2_msg_has(e, ".word", ".uname", ".nounit")
})

# ---- 16: units: keys that are no unit; one rule per message ------------------------------------------------

test_that("review 2f #16: a units: key that holds no unit is a problem (9.1.7)", {
  for (key in c("\"1\"", "\"m/m\"")) {
    e <- r2_units_err(c(paste0("  ", key, ":"), "    name: thing"))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "(rule 9.1.7)")
  }
})

test_that("review 2f #16: a units: key that is a number is a problem (9.1.7)", {
  e <- r2_units_err(c("  \"100\":", "    name: hundred"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "100", "(rule 9.1.7)")
})

test_that("review 2f #16: a message cites one rule, not two in a row (9.1.7, 4.2.7)", {
  e <- r2_units_err(c("  \"m^0.5\":", "    name: root metre"))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`m^0.5`", "(rule 9.1.7)")
  expect_false(r2_two_rules(f2_msg(e)), label = f2_msg(e))
  e2 <- f2_cond(read_dict(f2_dict_file(
    "area: {value: 3, type: quantity, unit: m, display: \"m^0.5\", definition: \"An area.\"}")))
  f2_has_class(e2, "weft_dict_error")
  expect_false(r2_two_rules(f2_msg(e2)), label = f2_msg(e2))
})

test_that("review 2f #16: control - a key that is a unit reads without a problem (9.1.7)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  expect_no_error(weft:::read_config(f2_proj(c("units:", "  zzvk:", "    name: quark", "    symbol: zq"))))
})

# ---- a: .ord on a quantity -----------------------------------------------------------------------------------------------

test_that("review 2f #a: .ord on a quantity with a unit is a value error, a rank has no unit (ruling a)", {
  f2_has_class(f2_cond(fmt_ord(u(3, m))), "weft_value_error")
  f2_has_class(f2_cond(fmt_ord(u(3, m), unit_form = "name")), "weft_value_error")
  f2_has_class(f2_cond(fmt_ord(u(1, m), unit_form = "name")), "weft_value_error")
  f2_has_class(f2_err("`r u(3, m)`{.ord}"), "weft_value_error")
  f2_msg_has(f2_err("`r u(3, m)`{.ord}"), ".ord")
})

test_that("review 2f #a: control - .ord on a number is as before (1.4.2)", {
  expect_equal(f2_tx(fmt_ord(3)), "3rd")
  expect_equal(f2_ws("`r 21`{.ord}"), "21st")
})

# ---- b: the misreadings are refused -----------------------------------------------------------------------------------------

test_that("review 2f #b: u() refuses the tokens units misreads, naming the token (ruling b)", {
  for (tok in c("mph", "pH", "nmi", "Ma", "ka", "gal")) {
    e <- f2_cond(r2_u(5, tok))
    expect_false(is.null(e), label = paste(tok, "is refused"))
    if (!is.null(e)) {
      expect_true(inherits(e, "weft_unit_error"), label = paste(tok, "class"))
      expect_true(grepl(tok, conditionMessage(e), fixed = TRUE), label = conditionMessage(e))
    }
  }
})

test_that("review 2f #b: control - the intended spellings and ordinary prefixed units are accepted (ruling b)", {
  expect_equal(f2_tx(fmt_num(u(60, mi/h))), f2("60~mi/h"))
  expect_equal(r2_num(5, "mm"), f2("5~mm"))
  expect_equal(r2_num(5, "mL"), f2("5~mL"))
  expect_equal(r2_num(5, "kPa"), f2("5~kPa"))
})

# ---- c: unit_form: symbol and a unit with no symbol ------------------------------------------------------------------------

test_that("review 2f #c: under unit_form symbol a unit with no symbol prints its name with a spelled number (ruling c)", {
  expect_equal(f2_ws("`r u(10, year)`{.word}", "unit_form: symbol"), f2("ten~years"))
  expect_equal(f2_ws("`r u(1, year)`{.word}", "unit_form: symbol"), f2("one~year"))
  yml <- c("unit_form: symbol", "units:", "  zzuc:", "    name: site", "    symbol: false")
  expect_equal(f2_ws("`r u(5, zzuc)`{.word}", yml), f2("five~sites"))
  expect_equal(f2_ws("`r u(3, zzuc)`{.count}", yml), f2("three~sites"))
})

test_that("review 2f #c: control - a unit with a symbol is still the error, and digits print the name (U4)", {
  f2_has_class(f2_err("`r u(5, m)`{.word}", "unit_form: symbol"), "weft_value_error")
  expect_equal(f2_ws("`r u(10, year)`{.num}", "unit_form: symbol"), f2("10~years"))
})

# ---- d: display: and unit = that invert a value ----------------------------------------------------------------------------------

test_that("review 2f #d: unit = a unit of another dimension that units reaches by inversion is a value error (ruling d)", {
  f2_has_class(f2_cond(fmt_num(u(4, m), unit = "1/m")), "weft_value_error")
  f2_has_class(f2_err("`r u(4, m)`{.num unit=\"1/m\"}"), "weft_value_error")
})

test_that("review 2f #d: display: of such a unit is a dictionary problem (ruling d)", {
  e <- f2_cond(read_dict(f2_dict_file(
    "rec: {value: 3, type: quantity, unit: m, display: \"1/m\", definition: \"A length.\"}")))
  f2_has_class(e, "weft_dict_error")
  f2_msg_has(e, "1/m")
})

test_that("review 2f #d: control - a convertible unit and the L/(100*km) to km/L display are fine (ruling d)", {
  expect_equal(f2_tx(fmt_num(u(4, m), unit = "cm")), f2("400~cm"))
  d <- read_dict(f2_dict_file(
    "fuel: {value: 8, type: quantity, unit: \"L/(100*km)\", display: \"km/L\", definition: \"Use.\"}"))
  expect_equal(as.numeric(d$fuel), 12.5)
})

# ---- f: a failed read clears the units: table kept for use outside a knit ----------------------------------------------------------

test_that("review 2f #f: a failed read of the configuration clears the units: table used outside a knit (ruling f)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  withr::defer(weft:::read_config(f2_proj()))
  weft:::read_config(f2_proj(c("units:", "  zzfa:", "    name: aaa")))
  expect_equal(r2_nm(2, "zzfa"), "aaas")                       # control: project A's table is in use
  bad <- f2_proj(c("units:", "  zzfb: [oops"))
  expect_false(is.null(f2_cond(weft:::read_config(bad))))
  e <- f2_cond(r2_nm(2, "zzfa"))
  f2_has_class(e, "weft_value_error")                          # nothing from A leaks into B's console work
})
