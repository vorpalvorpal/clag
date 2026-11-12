# Regression tests for the review of the stage-2 fixes, units and the dictionary (dev/review-2-fixes.md),
# decided by its "Rulings (orchestrator, 12 November 2026)": findings 1-9 and questions a, b, c, e, f
# (d, g, h are left as built and get no test).
# `~` in an expected string is U+00A0 (f2()). Non-ASCII is written as \uXXXX. Made-up values only.
# The `units` database is session-global: tests that read a configuration restore the default state
# when they end (h2_restore()).
if (!exists("h2_row")) source(Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))[[1]])
h2_need()

R2X_MINUS <- "\u2212"

# an inline construct
r2x_cx <- function(value, attrs) paste0("`r ", value, "`{", attrs, "}")

# the printed text of a call, with an error shown as "ERROR: class: message"
r2x_show <- function(expr) {
  tryCatch(f2_tx(expr), error = function(e) paste0("ERROR: ", class(e)[1], ": ", conditionMessage(e)))
}

# the value of an expression and the warnings it raised
r2x_warn <- function(expr) h2_warns(expr)

# one batched render (knit format, draft mode so a failure is a marker): the cases, markers split
r2x_batch <- function(cases, front = NULL, files = NULL) {
  res <- render_rmd(batch_cases(cases), front = front, files = files, in_process = TRUE,
                    env = c(WEFT_DRAFT = "1"), format = "knit")
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the batch did not render")
  f2_unesc(split_cases(res, length(cases)))
}

# ---- 1: a prefixed token of a row with no symbol never prints FALSE ------------------------------------------------------------

test_that("review 2x #1: a prefixed year typed by name prints by name, never `kFALSE` (4.4.8, ruling 1)", {
  h2_restore()
  expect_equal(r2x_show(fmt_num(u(3, kiloyear))), f2("3~kiloyears"))
  expect_equal(r2x_show(fmt_num(u(3, kiloyears))), f2("3~kiloyears"))
  expect_equal(r2x_show(fmt_num(u(3, megayear))), f2("3~megayears"))
  expect_equal(r2x_show(fmt_num(u(3, gigayear))), f2("3~gigayears"))
  expect_equal(r2x_show(fmt_num(u(1, kiloyear))), f2("1~kiloyear"))
})

test_that("review 2x #1: FALSE is never pasted, through a conversion, a compound, a bare unit or a construct (ruling 1)", {
  h2_restore()
  outs <- c(
    r2x_show(fmt_num(u(3, "m/kiloyear"))),
    r2x_show(fmt_unit("kiloyear")),
    r2x_show(fmt_num(u(3000, year), unit = "year|kiloyear")),
    r2x_show(fmt_num(u(3000, year), unit = "kiloyear")),
    r2x_show(fmt_num(u(3, Myr), unit = "kiloyear")),
    h2_ws(r2x_cx("u(3, megayear)", ".num")))
  for (o in outs) expect_false(grepl("FALSE", o, fixed = TRUE), label = o)
  expect_equal(r2x_show(fmt_num(u(3000, year), unit = "kiloyear")), f2("3~kiloyears"))
  expect_equal(h2_ws(r2x_cx("u(3, megayear)", ".num")), f2("3~megayears"))
  expect_match(r2x_show(fmt_unit("kiloyear")), "kiloyear")
})

test_that("review 2x #1: a prefixed year where only a symbol will do is the no-symbol value error (lang fr, ruling 1)", {
  got <- r2x_batch(c("`r u(3, kiloyear)`{.num}", "`r u(3, kyr)`{.num}"), front = "lang: fr")
  expect_match(got[1], "<<weft:", fixed = TRUE)
  expect_false(grepl("FALSE", got[1], fixed = TRUE))
  expect_equal(got[2], f2("3~kyr"))                         # control: a row with a symbol
})

test_that("review 2x #1: in the dictionary a kiloyear display or unit prints by name, never kFALSE (ruling 1)", {
  h2_restore()
  d <- read_dict(f2_dict_file(c(
    "k: {value: 2000, type: quantity, unit: year, display: kiloyear, definition: \"A span.\"}",
    "age: {value: 3, type: quantity, unit: kiloyear, definition: \"An age.\"}")))
  g <- as.character(dict_glossary(d))
  expect_false(grepl("FALSE", g, fixed = TRUE), label = g)
  expect_true(grepl(f2("2~kiloyears"), g, fixed = TRUE), label = g)
  expect_true(grepl(f2("3~kiloyears"), g, fixed = TRUE), label = g)
})

test_that("review 2x #1: control - a prefixed year by symbol, and the name forms, print as before (4.4.8)", {
  h2_restore()
  expect_equal(r2x_show(fmt_num(u(3, kyr))), f2("3~kyr"))
  expect_equal(r2x_show(fmt_word(u(3, kiloyear))), f2("three~kiloyears"))
  expect_equal(r2x_show(fmt_num(u(3, year))), f2("3~years"))
})

# ---- 2: the glossary's blank line survives a real knit ---------------------------------------------------------------------------

R2X_DICT <- c("start: {value: 2.5, type: quantity, unit: km, definition: \"Start distance.\"}",
              "stop: {value: 4, type: quantity, unit: km, definition: \"Stop distance.\"}")

r2x_glossary_md <- function(lines) {
  res <- render_rmd(lines, files = list(dict.yml = R2X_DICT), format = "md", in_process = TRUE,
                    env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the document did not render")
  res$text
}

test_that("review 2x #2: the paragraph after the glossary chunk is its own paragraph, through knit and Pandoc (4.7.1, ruling 2)", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  txt <- r2x_glossary_md(c("```{r}", "dict_glossary()", "```", "After the glossary."))
  i <- grep("^After the glossary\\.", txt)
  expect_false(any(grepl("distance\\.\\s+After", txt)), label = paste(txt, collapse = " | "))
  expect_length(i, 1)
  skip_if(length(i) != 1)
  expect_true(i > 1 && !nzchar(trimws(txt[i - 1])), label = paste(txt, collapse = " | "))   # a blank line before it
  expect_true(any(grepl("Stop distance.", txt, fixed = TRUE)))
})

test_that("review 2x #2: the same with echo = FALSE, and with text before the chunk (ruling 2)", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  txt <- r2x_glossary_md(c("Before the glossary.", "```{r echo=FALSE}", "dict_glossary()", "```", "After the glossary."))
  j <- grep("^Before the glossary\\.", txt)
  i <- grep("^After the glossary\\.", txt)
  expect_false(any(grepl("distance\\.\\s+After", txt)), label = paste(txt, collapse = " | "))
  expect_length(i, 1); expect_length(j, 1)
  skip_if(length(i) != 1 || length(j) != 1)
  expect_true(!nzchar(trimws(txt[i - 1])), label = paste(txt, collapse = " | "))
})

test_that("review 2x #2: in HTML the paragraph after the glossary is a <p>, not part of the last <dd> (ruling 2)", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  d <- write_doc(c("```{r}", "dict_glossary()", "```", "After the glossary."), TRUE, NULL, NULL,
                 list(dict.yml = R2X_DICT), "doc", "rmd")
  out <- file.path(d$dir, "doc.html")
  res <- tryCatch({
    withr::with_envvar(c(WEFT_DRAFT = "1"), withr::with_dir(d$dir,
      rmarkdown::render(d$input, rmarkdown::html_fragment(), output_file = out, quiet = TRUE, envir = new.env())))
    NULL
  }, error = function(e) e)
  skip_if(!is.null(res), "the render failed")
  html <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl("<p>After the glossary.</p>", html, fixed = TRUE), label = html)
  expect_false(grepl("Stop distance\\.\\s*After", html))
})

# ---- 3: .cap never changes a unit's symbol, on any route ------------------------------------------------------------------------

test_that("review 2x #3: .cap after a text class keeps the unit symbol (1.4.20, ruling 3)", {
  h2_restore()
  expect_equal(r2x_show(fmt_cap(fmt_strong(fmt_unit(u(1, mL))))), "**mL**")
  expect_equal(r2x_show(fmt_cap(fmt_em(fmt_unit(u(1, mg/L))))), "*mg/L*")
  expect_equal(h2_ws(r2x_cx("fmt_strong(fmt_unit(u(1, mL)))", ".cap")), "**mL**")
})

test_that("review 2x #3: .cap after `[`, `rev()` and `c()` keeps the unit symbol (ruling 3)", {
  h2_restore()
  expect_equal(r2x_show(fmt_cap(fmt_unit(u(1, mL))[1])), "mL")
  expect_equal(r2x_show(fmt_cap(rev(fmt_unit(u(1, mL))))), "mL")
  expect_equal(r2x_show(fmt_cap(c(fmt_unit(u(1, mL))))), "mL")
  expect_equal(r2x_show(fmt_cap(fmt_unit(u(3, kg))[1])), "kg")
})

test_that("review 2x #3: control - the direct call and a construct class list keep the symbol; ordinary text is capitalised (1.4.20)", {
  h2_restore()
  expect_equal(r2x_show(fmt_cap(fmt_unit(u(1, mL)))), "mL")
  expect_equal(h2_ws(r2x_cx("fmt_unit(u(1, mL))", ".strong .cap")), "**mL**")
  expect_equal(r2x_show(fmt_cap("abc")), "Abc")
})

# ---- 4: a text class on a quantity's text keeps the unit inside the markup ------------------------------------------------------

test_that("review 2x #4: text classes nest outside-in and the unit stays inside (4.4.8, ruling 3/4)", {
  h2_restore()
  expect_equal(r2x_show(fmt_em(fmt_strong(fmt_num(u(3, m))))), f2("***3~m***"))
  expect_equal(r2x_show(fmt_strong(fmt_em(fmt_num(u(3, m))))), f2("***3~m***"))
  expect_equal(r2x_show(fmt_em(fmt_strong(fmt_num(u(7, pH))))),
               paste0("*", r2x_show(fmt_strong(fmt_num(u(7, pH)))), "*"))
  expect_false(grepl("*pH~**7***", r2x_show(fmt_em(fmt_strong(fmt_num(u(7, pH))))), fixed = TRUE))
})

test_that("review 2x #4: the same class twice is applied once (ruling 3/4)", {
  h2_restore()
  expect_equal(r2x_show(fmt_strong(fmt_strong(fmt_num(u(3, m))))), f2("**3~m**"))
  expect_equal(r2x_show(fmt_em(fmt_em(fmt_num(u(3, m))))), f2("*3~m*"))
  expect_equal(r2x_show(fmt_strong(fmt_strong(fmt_word(u(3, m))))), f2("**three~metres**"))
})

test_that("review 2x #4: .cap after a text class keeps the unit inside the markup (ruling 3/4)", {
  h2_restore()
  expect_equal(r2x_show(fmt_cap(fmt_strong(fmt_num(u(3, m))))), f2("**3~m**"))
  expect_equal(r2x_show(fmt_cap(fmt_strong(fmt_word(u(3, m))))), f2("**Three~metres**"))
  expect_equal(r2x_show(fmt_cap(fmt_em(fmt_word(u(3, m))))), f2("*Three~metres*"))
})

test_that("review 2x #4: a text class on a formatter's text inside a construct keeps the unit inside (4.4.8, ruling 3/4)", {
  h2_restore()
  expect_equal(h2_ws(r2x_cx("fmt_strong(fmt_num(u(3, m)))", ".em")), f2("***3~m***"))
  expect_equal(h2_ws(r2x_cx("fmt_strong(fmt_num(u(3, m)))", ".strong")), f2("**3~m**"))
  expect_equal(h2_ws('[# was | # were]{n="fmt_strong(fmt_num(u(3, m)))" .em}'), f2("***3~m** were*"))   # control
})

test_that("review 2x #4: control - one text class, and two classes in one construct (4.4.8)", {
  h2_restore()
  expect_equal(r2x_show(fmt_strong(fmt_num(u(3, m)))), f2("**3~m**"))
  expect_equal(h2_ws(r2x_cx("u(3, m)", ".strong .em")), f2("***3~m***"))
  expect_equal(h2_ws(r2x_cx("u(3, m)", ".strong")), f2("**3~m**"))
})

# ---- 5: every rung of a ladder is checked on the classes, before the pick --------------------------------------------------------

R2X_ZZL <- c("units:", "  zzl:", "    is: 1 L")

test_that("review 2x #5: a rung with no name under .uname/.word/.count is a value error for every value (4.4.19, 4.4.23, ruling 5)", {
  h2_restore()
  for (cls in c(".uname", ".word", ".count")) {
    for (v in c("u(500, mL)", "u(3000, mL)", "u(3, mL)")) {
      e <- f2_err(r2x_cx(v, paste0(cls, ' unit="mL|zzl"')), R2X_ZZL)
      f2_has_class(e, "weft_value_error")
      f2_msg_has(e, "zzl")
    }
  }
})

test_that("review 2x #5: `unit_form: symbol` with a spelled number and a rung with no symbol is an error for every value (ruling 5)", {
  h2_restore()
  for (v in c("u(5, year)", "u(3000, year)", "u(40, year)")) {
    e <- f2_err(r2x_cx(v, '.word unit="yr|kyr"'), "unit_form: symbol")
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, ".word")
  }
})

test_that("review 2x #5: the `lang` rule is checked on every rung, so a value never changes the verdict (ruling 5)", {
  got <- r2x_batch(c("`r u(5, year)`{unit=\"yr|kyr\"}", "`r u(3000, year)`{unit=\"yr|kyr\"}",
                     "`r u(5, m)`{unit=\"m|km\"}"), front = "lang: fr")
  expect_match(got[1], "<<weft:", fixed = TRUE)
  expect_match(got[2], "<<weft:", fixed = TRUE)
  expect_false(grepl("<<weft:", got[3], fixed = TRUE), label = got[3])   # control: every rung has a symbol
})

test_that("review 2x #5: a rung of a unit with no name and no symbol is an error for every value (ruling 5)", {
  h2_restore()
  yml <- c("units:", "  zzsites:", "    is: base", "    name: site", "    symbol: false")
  for (v in c("u(5, zzsites)", "u(3000, zzsites)")) {
    e <- f2_err(r2x_cx(v, '.word unit="zzsites|kzzsites"'), yml)
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, "kzzsites")
  }
})

test_that("review 2x #5: control - a ladder whose rungs all have names and symbols prints, whichever rung is picked", {
  h2_restore()
  expect_equal(h2_ws(r2x_cx("u(500, mL)", '.uname unit="mL|L"')), f2("500~millilitres"))
  expect_equal(h2_ws(r2x_cx("u(3000, mL)", '.uname unit="mL|L"')), f2("3~litres"))
  expect_equal(h2_ws(r2x_cx("u(5, year)", '.word unit="year"')), f2("five~years"))
})

# ---- 6: a unit with no numerator prints with negative powers however it was typed ------------------------------------------------

test_that("review 2x #6: `1/m^3` and `1/s` print with negative powers (4.4.8, ruling 6)", {
  h2_restore()
  expect_equal(r2x_show(fmt_num(u(2, "1/m^3"))), f2(paste0("2~m^", R2X_MINUS, "3^")))
  expect_equal(r2x_show(fmt_num(u(2, "1/s"))), f2(paste0("2~s^", R2X_MINUS, "1^")))
  expect_equal(r2x_show(fmt_unit("1/s")), paste0("s^", R2X_MINUS, "1^"))
  expect_equal(r2x_show(fmt_num(u(2, Hz), unit = "1/s")), f2(paste0("2~s^", R2X_MINUS, "1^")))
})

test_that("review 2x #6: a converted-to compound with no numerator prints no `1/` (ruling 6)", {
  h2_restore()
  got <- r2x_show(fmt_num(u(2000, "Bq/L"), unit = "1/s/L"))
  expect_false(grepl("1/", got, fixed = TRUE), label = got)
  expect_true(grepl(R2X_MINUS, got, fixed = TRUE), label = got)
  expect_true(grepl("^2,000", got))
})

test_that("review 2x #6: the no-name advice no longer suggests writing `1/m^3` (ruling 6)", {
  h2_restore()
  e <- f2_cond(fmt_num(u(3, "m^-3"), unit_form = "name"))
  f2_has_class(e, "weft_value_error")
  expect_false(grepl("1/m^3", f2_msg(e), fixed = TRUE), label = f2_msg(e))
  f2_msg_has(e, "m^-3")
})

test_that("review 2x #6: control - a negative power typed as such, a quotient with a numerator, and the name form (4.4.8, 4.4.18)", {
  h2_restore()
  expect_equal(r2x_show(fmt_num(u(2, "m^-3"))), f2(paste0("2~m^", R2X_MINUS, "3^")))
  expect_equal(r2x_show(fmt_unit("s-1")), paste0("s^", R2X_MINUS, "1^"))
  expect_equal(r2x_show(fmt_num(u(5, mg/L))), f2("5~mg/L"))
  expect_equal(r2x_show(fmt_num(u(2, "1/m^3"), unit_form = "name")), f2("2~per cubic metre"))
})

# ---- 7: unit= acts on a formatter's text that carries a quantity ----------------------------------------------------------------

test_that("review 2x #7: `unit=` on a span governed by a formatter's text converts it (4.4.4, ruling 7)", {
  h2_restore()
  expect_equal(h2_ws('[# x | # xs]{n="fmt_num(u(1500, m))" unit="km"}'), f2("1.5~km xs"))
  expect_equal(h2_ws('[# x | # xs]{n="fmt_num(u(1500, m))" unit="m|km"}'), f2("1.5~km xs"))
  expect_equal(h2_ws('[# x | # xs]{n="fmt_num(u(1500, m))" unit="m|km" .uname}'), f2("1.5~kilometres xs"))
  expect_equal(h2_ws('[up # | down #]{sign="fmt_num(u(-3, m))" unit="cm"}'), "down 300~cm" |> f2())
})

test_that("review 2x #7: `unit=` on a list span and on an inline formatter's text (4.4.4, ruling 7)", {
  h2_restore()
  e <- f2_cond(h2_ws('[none | # was | # were]{list="fmt_num(u(c(1500, 2500), m))" unit="km"}'))
  expect_null(e, label = f2_msg(e))
  got <- h2_ws('[none | # was | # were]{list="fmt_num(u(c(1500, 2500), m))" unit="km"}')
  expect_match(got, "km")
  expect_match(got, "were$")
  expect_equal(h2_ws(r2x_cx("fmt_num(u(1500, m))", 'unit="m|km"')), f2("1.5~km"))
  expect_equal(h2_ws(r2x_cx("fmt_num(u(1500, m))", 'unit="km"')), f2("1.5~km"))
})

test_that("review 2x #7: a formatter's text given to a formatter with `unit=` converts it (4.4.4, ruling 7)", {
  h2_restore()
  expect_equal(r2x_show(fmt_num(fmt_num(u(1500, m)), unit = "km")), f2("1.5~km"))
  expect_equal(r2x_show(fmt_num(fmt_num(u(1500, m)), unit = "m|km")), f2("1.5~km"))
})

test_that("review 2x #7: control - `unit=` through a back-reference, and a formatter's text with .word and .nounit (4.4.4)", {
  h2_restore()
  expect_equal(h2_ws('`r u(1500, m)`{#b .nounit} [# x | # xs]{n="#b" unit="km"}'), f2("1,500 1.5~km xs"))
  expect_equal(h2_ws('[# x | # xs]{n="fmt_num(u(5, m))" .word}'), f2("five~metres xs"))
  expect_equal(h2_ws('[# x | # xs]{n="fmt_num(u(5, m))" .nounit}'), "5 xs")
})

test_that("review 2x #7: control - `unit=` on text that carries no quantity is still an error (4.4.4)", {
  h2_restore()
  expect_false(is.null(f2_cond(fmt_num(fmt_strong("abc"), unit = "km"))))
})

# ---- 8: a prefix joins only a one-word name ------------------------------------------------------------------------------------

test_that("review 2x #8: under en-US a prefixed tonne takes the default name, not `megametric ton` (4.4.16, ruling 8)", {
  got <- r2x_batch(c("`r u(1, Mt)`{.word}", "`r u(3, Mt)`{.uname}", "`r u(2, t)`{.uname}", "`r u(2, kg)`{.uname}"),
                   front = "lang: en-US")
  expect_equal(got[1], f2("one~megatonne"))
  expect_equal(got[2], f2("3~megatonnes"))
  expect_false(any(grepl("megametric", got, fixed = TRUE)))
  expect_equal(got[3], f2("2~metric tons"))          # control: the unprefixed en-US name
  expect_equal(got[4], f2("2~kilograms"))            # control: a one-word name takes its prefix
})

test_that("review 2x #8: control - with no lang the prefixed tonne is a megatonne (4.4.16)", {
  h2_restore()
  expect_equal(h2_ws(r2x_cx("u(1, Mt)", ".word")), f2("one~megatonne"))
})

# ---- 9: advice that can be followed ---------------------------------------------------------------------------------------------

test_that("review 2x #9: a project unit defined as `1 degree` is not told to write `2 1 degree` (ruling 9)", {
  h2_restore()
  for (def in c("1 degree")) {
    e <- g2_cfg_err(c("units:", "  hdg:", paste0("    is: ", def)))
    expect_false(is.null(e), label = def)
    expect_false(grepl("2 1 degree", f2_msg(e), fixed = TRUE), label = f2_msg(e))
    f2_msg_has(e, "hdg", def)
  }
})

test_that("review 2x #9: a `display:` that is not a well-formed ladder is not quoted back as a ladder (ruling 9)", {
  h2_restore()
  for (case in list(list("\"m||km\"", "unit=\"m||km\""), list("\"|\"", "unit=\"|\""), list("[m, m]", "unit=\"m|m\""))) {
    e <- f2_cond(read_dict(h2_dict(case[[1]], value = 800)))
    f2_has_class(e, "weft_dict_error")
    f2_msg_has(e, "`x`", "display")
    expect_false(grepl(case[[2]], f2_msg(e), fixed = TRUE), label = f2_msg(e))
  }
})

test_that("review 2x #9: control - a well-formed display ladder is quoted back as a `unit` ladder (2h #2)", {
  h2_restore()
  e <- f2_cond(read_dict(h2_dict("\"m|km\"", value = 800)))
  f2_has_class(e, "weft_dict_error")
  f2_msg_has(e, "`unit` key", "m|km")
})

# ---- a: a frequency or activity unit and an angle per time do not convert --------------------------------------------------------

test_that("review 2x a: Hz, kHz and Bq to rpm, rad/s and degree/s are value errors (4.4.14, ruling a)", {
  h2_restore()
  for (case in list(list(u(2000, Hz), "rpm"), list(u(2, kHz), "rpm"), list(u(2, Bq), "rpm"),
                    list(u(2, Hz), "rad/s"), list(u(2, Hz), "degree/s"), list(u(2, kBq), "rpm"))) {
    e <- f2_cond(fmt_num(case[[1]], unit = case[[2]]))
    f2_has_class(e, "weft_value_error")
  }
  f2_has_class(f2_cond(fmt_num(u(60, rpm), unit = "Hz")), "weft_value_error")
})

test_that("review 2x a: a dictionary entry displaying a frequency in rpm is a read_dict() problem (ruling a)", {
  h2_restore()
  for (line in c("spin: {value: 2, type: quantity, unit: Hz, display: rpm, definition: \"A rate.\"}",
                 "spin: {value: 2, type: quantity, unit: Bq, display: rpm, definition: \"A rate.\"}")) {
    e <- f2_cond(read_dict(f2_dict_file(line)))
    f2_has_class(e, "weft_dict_error")
    f2_msg_has(e, "`spin`")
  }
})

test_that("review 2x a: control - frequency to frequency and rpm itself print or convert (4.4.14)", {
  h2_restore()
  expect_equal(r2x_show(fmt_num(u(2000, Hz), unit = "kHz")), f2("2~kHz"))
  expect_equal(r2x_show(fmt_num(u(5, rpm))), f2("5~rpm"))
  expect_equal(r2x_show(fmt_num(u(60, rpm), unit = "rpm")), f2("60~rpm"))
  expect_false(is.null(f2_cond(fmt_num(u(2, Hz), unit = "m"))))
})

# ---- b: kt is a knot, refused like mt -------------------------------------------------------------------------------------------

test_that("review 2x b: u(3, kt) is a unit error naming kt, advising `kn` for the knot (4.4.17, ruling b)", {
  h2_restore()
  e <- f2_cond(u(3, kt))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "kt", "kn")
  expect_true(inherits(f2_cond(u(5, "kt/h")), "weft_unit_error"))
})

test_that("review 2x b: a dictionary unit `kt` is a read_dict() problem (ruling b)", {
  h2_restore()
  e <- f2_cond(read_dict(f2_dict_file("wt: {value: 3, type: quantity, unit: kt, definition: \"A mass.\"}")))
  expect_false(is.null(e))
  f2_msg_has(e, "kt")
})

test_that("review 2x b: control - mt is refused with advice, and t is fine (4.4.17)", {
  h2_restore()
  e <- f2_cond(u(3, mt))
  f2_has_class(e, "weft_unit_error")
  f2_msg_has(e, "mt", "millitonne")
  expect_equal(r2x_show(fmt_num(u(3, t))), f2("3~t"))
})

# ---- c: the 1e-9 snap does not apply to a quantity ------------------------------------------------------------------------------

test_that("review 2x c: a small quantity prints as zero with the zero-rule warning, not silently (4.4.13, ruling c)", {
  h2_restore()
  for (x in list(u(5e-10, g), u(5e-10, "mol/L"), u(-5e-10, g))) {
    r <- r2x_warn(fmt_num(x))
    expect_true(length(r$w) >= 1, label = "a warning")
    if (length(r$w)) expect_match(r$w[1], "digits|sigfig")
    expect_match(f2_tx(r$v), "^[\\-\u2212]?0(\\.0+)?[ \u00a0]")
  }
})

test_that("review 2x c: every value of a vector with a small quantity is judged by the ordinary rule (4.4.13, ruling c)", {
  h2_restore()
  expect_true(length(r2x_warn(fmt_num(u(c(5e-10, 2e-9), "mol/L")))$w) >= 1)
  expect_true(length(r2x_warn(fmt_range(u(c(0, 5e-10), g)))$w) >= 1)
})

test_that("review 2x c: control - an exact zero quantity, a plain number's noise, and sigfig on a small quantity are unchanged (1.4.13)", {
  h2_restore()
  expect_no_warning(fmt_num(u(0, g)))
  expect_equal(r2x_show(fmt_num(u(0, g))), f2("0~g"))
  expect_no_warning(fmt_num(5e-10))
  expect_equal(r2x_show(fmt_num(5e-10)), "0")
  expect_no_warning(fmt_num(u(5e-10, g), sigfig = 2))
  expect_equal(r2x_show(fmt_num(u(5e-10, g), sigfig = 2)), f2("0.00000000050~g"))
})

# ---- e: a glossary value that would print as zero is printed in the entry's own unit ---------------------------------------------

test_that("review 2x e: a glossary entry whose display unit prints zero is printed in its own unit, with no warning (4.7.1, ruling e)", {
  h2_restore()
  d <- read_dict(f2_dict_file(c(
    "dose: {value: 2, type: quantity, unit: mSv, display: Sv, definition: \"A dose.\"}",
    "small: {value: 3, type: quantity, unit: mg, display: kg, definition: \"A mass.\"}")))
  r <- r2x_warn(as.character(dict_glossary(d)))
  expect_length(r$w, 0)
  expect_true(grepl(f2("`dose` (2~mSv)"), r$v, fixed = TRUE), label = r$v)
  expect_true(grepl(f2("`small` (3~mg)"), r$v, fixed = TRUE), label = r$v)
  expect_false(grepl("0.0", r$v, fixed = TRUE))
})

test_that("review 2x e: control - a glossary entry whose display unit prints a non-zero value is printed in the display unit (4.7.1)", {
  h2_restore()
  d <- read_dict(f2_dict_file("dose: {value: 2000, type: quantity, unit: mSv, display: Sv, definition: \"A dose.\"}"))
  r <- r2x_warn(as.character(dict_glossary(d)))
  expect_length(r$w, 0)
  expect_true(grepl(f2("`dose` (2~Sv)"), r$v, fixed = TRUE), label = r$v)
})

# ---- f: .sci with a ladder of more than one rung is a value error ---------------------------------------------------------------

test_that("review 2x f: .sci with a ladder of more than one rung is a value error, on every route (ruling f)", {
  h2_restore()
  for (v in c("u(1500, m)", "u(400, m)")) {
    e <- f2_err(r2x_cx(v, '.sci unit="m|km"'))
    f2_has_class(e, "weft_value_error")
    f2_msg_has(e, ".sci")
  }
  f2_has_class(f2_cond(fmt_sci(u(1500, m), unit = "m|km")), "weft_value_error")
  f2_has_class(f2_cond(fmt_sci(u(1500, m), unit = c("m", "km"))), "weft_value_error")
})

test_that("review 2x f: control - .sci with one unit, or a ladder of one rung, prints (ruling f)", {
  h2_restore()
  expect_equal(r2x_show(fmt_sci(u(1500, m), unit = "km")), f2("1.5 \u00d7 10^0^~km"))
  expect_equal(r2x_show(fmt_sci(u(1500, m), unit = "km ")), f2("1.5 \u00d7 10^0^~km"))
  expect_equal(r2x_show(fmt_sci(u(1200, m))), f2("1.2 \u00d7 10^3^~m"))
})

# ---- 10: a refused project unit with a non-ASCII base symbol leaves the database as it was (4.4.21) ---------------------------

test_that("review 2x #10: a refused `is:` of exactly a non-ASCII-symbol unit leaves the units database unchanged (4.4.21)", {
  h2_restore()
  cases <- list(list(def = "1 degree", name = "degree", sym = "°", key = "zzxdeg"),
                list(def = "1 ohm", name = "ohm", sym = "Ω", key = "zzxohm"),
                list(def = "1 arcminute", name = "arcminute", sym = "′", key = "zzxarc"))
  for (cs in cases) {
    snap <- function() c(num = r2x_show(fmt_num(g2_u(5, cs$name))),
                         word = r2x_show(fmt_num(g2_u(5, cs$name), unit_form = "name")),
                         sym = r2x_show(fmt_num(g2_u(2, cs$sym))))
    before <- snap()
    expect_false(grepl("ERROR", before[["num"]]), label = paste(cs$name, before[["num"]]))
    e <- g2_cfg_err(c("units:", paste0("  ", cs$key, ":"), paste0("    is: ", cs$def)))
    expect_false(is.null(e), label = paste(cs$def, "is refused"))
    expect_identical(snap(), before, label = paste("after the refused", cs$def))
    expect_true(Encoding(snap()[["num"]]) != "bytes", label = "not raw bytes")
    expect_true(inherits(f2_cond(g2_u(2, cs$key)), "weft_unit_error"), label = paste(cs$key, "is not a unit"))
  }
})

test_that("review 2x #10: control - a project unit with an ASCII definition is accepted and the base units still print (4.4.21)", {
  h2_restore()
  before <- r2x_show(fmt_num(g2_u(5, "degree")))
  expect_null(g2_cfg_err(c("units:", "  zzxlong:", "    is: 1000 m")))
  expect_equal(r2x_show(fmt_num(u(2, zzxlong), unit = "m")), f2("2,000~m"))
  expect_identical(r2x_show(fmt_num(g2_u(5, "degree"))), before)
})
