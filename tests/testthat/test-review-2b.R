# Regression tests for the review of package 2b (dev/review-2b.md), decided by the
# "Rulings on the review of 2b" at the end of dev/design-2.md. Each test is named for
# the finding or question it covers. Made-up content only; `d` is the 2a fixture.

NBSP <- " "
MINUS <- "−"
MDOT <- "·"
rv <- function(x) as.character(unclass(x))[1]            # text of a weft_text, attributes dropped
rnb <- function(x) gsub("\\ ", NBSP, as.character(x), fixed = TRUE)   # undo Pandoc's `\ `
rd <- function() read_dict(a2_fixture())
# the text of a unit, as the record carries it
runit <- function(x) attr(fmt_num(x), "unit")

# ---- 1, f: the unit's text is Pandoc markdown ---------------------------------------------

test_that("review 2b #1/f: an exponent is a Pandoc superscript and a product a middle dot (ruling on 1/f)", {
  expect_equal(rv(fmt_num(u(1, m^2))), paste0("1", NBSP, "m^2^"))
  expect_equal(rv(fmt_num(u(3, m^4))), paste0("3", NBSP, "m^4^"))
  expect_equal(rv(fmt_num(u(9.81, m/s^2))), paste0("9.8", NBSP, "m/s^2^"))
  expect_equal(rv(fmt_num(u(1, kg * m))), paste0("1", NBSP, "kg", MDOT, "m"))
  expect_equal(runit(u(3, m^4)), "m^4^")
  expect_equal(runit(u(1, kg * m)), paste0("kg", MDOT, "m"))
  expect_equal(runit(u(2, "m^-3")), paste0("m^", MINUS, "3^"))
  expect_equal(runit(u(5, "s^-1")), paste0("s^", MINUS, "1^"))
  expect_equal(rv(fmt_num(u(2, "m^-3"))), paste0("2", NBSP, "m^", MINUS, "3^"))
  # control: a plain unit and a degree sign are unchanged
  expect_equal(rv(fmt_num(u(20, degC))), paste0("20", NBSP, "°C"))
})

test_that("review 2b #1/f: no character outside Latin-1, other than U+2212, is in a unit's text (ruling on 1/f)", {
  units_to_try <- list(u(1, m^2), u(3, m^4), u(1, m^3), u(1, kg * m), u(9.81, m/s^2),
                       u(2, "m^-3"), u(5, "s^-1"), u(20, degC), u(5, mg/L), u(12, mm/hr))
  for (x in units_to_try) {
    un <- gsub(MINUS, "", attr(fmt_num(x), "unit"), fixed = TRUE)
    expect_false(is.na(iconv(un, "UTF-8", "latin1")),
                 label = sprintf("unit text `%s` is Latin-1 apart from U+2212", un))
    expect_false(grepl("[⁰-₟⋅]", un), label = sprintf("`%s` has no Unicode superscript or dot operator", un))
  }
})

test_that("review 2b #1/f: a compound unit's text builds through pdflatex (ruling on 1/f)", {
  skip_if_not(nzchar(Sys.which("pdflatex")) || (requireNamespace("tinytex", quietly = TRUE) && tinytex::is_tinytex()),
              "no LaTeX engine")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  txt <- c(rv(fmt_num(u(1, kg * m))), rv(fmt_num(u(3, m^4))), rv(fmt_num(u(2, "m^-3"))), rv(fmt_num(-3)))
  dir <- withr::local_tempdir()
  rmd <- file.path(dir, "doc.Rmd")
  # ruling: the text reaches the document through a knit, so weft can
  # tell LaTeX how to set the minus sign U+2212 under pdflatex
  writeLines(c("---", "output: pdf_document", "---", "",
               "```{r, include=FALSE}", "library(weft)", "weft_setup()", "```", "",
               "`r u(1, 'kg*m')`{.num} and `r u(3, 'm^4')`{.num} and `r u(2, 'm^-3')`{.num} and `r -3`{.num}", ""),
             rmd, useBytes = TRUE)
  out <- tryCatch(rmarkdown::render(rmd, quiet = TRUE, envir = new.env()), error = function(e) e)
  expect_false(inherits(out, "error"), label = if (inherits(out, "error")) conditionMessage(out) else "")
  expect_true(file.exists(file.path(dir, "doc.pdf")))
})

# ---- c: an inverse unit ---------------------------------------------------------------------

test_that("review 2b #c: a unit with no numerator prints a negative power; one with a numerator keeps the quotient (ruling c)", {
  expect_equal(rv(fmt_num(u(2, "m^-3"))), paste0("2", NBSP, "m^", MINUS, "3^"))
  expect_equal(rv(fmt_num(u(5, "s^-1"))), paste0("5", NBSP, "s^", MINUS, "1^"))
  expect_false(grepl("1/", rv(fmt_num(u(2, "m^-3"))), fixed = TRUE))
  # control: a quotient with a numerator
  expect_equal(rv(fmt_num(u(5, mg/L))), paste0("5", NBSP, "mg/L"))
})

# ---- 2, 3, 4, a: # prints what the governor prints as a value, unit included (reversed ruling) ----

M <- paste0(NBSP, "m")      # a no-break space and the unit
ws <- function(x) rnb(weft_str(x))
once <- function(x, unit = M) lengths(regmatches(x, gregexpr(unit, x, fixed = TRUE)))

test_that("review 2b #a: # carries the unit when the governor is a quantity (4.4.4 reversed, 4.4.2)", {
  expect_equal(ws("[# metre | # metres]{n=\"u(5, m)\"}"), paste0("5", M, " metres"))
  expect_equal(as.character(plural(u(3, m), "# metre", "# metres")), paste0("3", M, " metres"))
  expect_equal(as.character(plural(u(1, m), "# metre", "# metres")), paste0("1", M, " metre"))  # arm from the number
  expect_equal(once(ws("[# metre | # metres]{n=\"u(5, m)\"}")), 1L)
  # control: a plain number has no unit
  expect_equal(ws("[# metre | # metres]{n=\"5\"}"), "5 metres")
})

test_that("review 2b #2: # carries the unit when the n governor is a formatter's text for a quantity (4.4.4 reversed)", {
  expect_equal(ws("[# metre | # metres]{n=\"fmt_num(u(5, m))\"}"), paste0("5", M, " metres"))
  expect_equal(once(ws("[# metre | # metres]{n=\"fmt_num(u(5, m))\"}")), 1L)
  expect_equal(ws("[# metre | # metres]{n=\"fmt_num(5)\"}"), "5 metres")   # control
})

test_that("review 2b #2: # carries the unit, once, when the governor is an id of a quantity's text (4.4.4 reversed)", {
  got <- ws("`r fmt_num(u(3, m))`{#k1} then [# a | # b]{n=\"#k1\"}")
  expect_equal(got, paste0("3", M, " then 3", M, " b"))
})

test_that("review 2b #2: # carries the unit, once, under n=\".\" (4.4.4 reversed)", {
  expect_equal(ws("[outer [# a | # b]{n=\".\"}]{n=\"fmt_num(u(3, m))\"}"), paste0("outer 3", M, " b"))
})

test_that("review 2b #2: a sign span prints # with the unit (4.4.4 reversed)", {
  expect_equal(ws("[up by # | down by # | flat]{sign=\"fmt_num(u(-0.3, m))\"}"), paste0("down by 0.3", M))
  expect_equal(ws("[up by # | down by # | flat]{sign=\"u(-0.3, m)\"}"), paste0("down by 0.3", M))
  expect_equal(ws("[up by # | down by # | flat]{sign=\"-0.3\"}"), "down by 0.3")   # control
})

test_that("review 2b #2: a wording class that turns # into a word leaves the unit off (4.4.2)", {
  expect_equal(ws("[# long]{n=\"u(3, m)\" .count}"), "three long")
  expect_equal(ws("[# long]{n=\"u(12, m)\" .count}"), paste0("12", M, " long"))   # digits keep it
})

test_that("review 2b #3: plural() keeps a unit with regex characters, once and intact (4.4.4 reversed)", {
  d <- rd()
  got <- as.character(plural(fmt_num(d$coliform_limit), "# count", "# counts"))
  expect_equal(got, paste0("150", NBSP, "CFU/(100mL) counts"))
  expect_equal(as.character(plural(fmt_num(u(5, m)), "# a", "# b")), paste0("5", M, " b"))   # control
})

test_that("review 2b #3: plural() keeps the unit inside a text class's markup, once (4.4.4 reversed)", {
  got <- as.character(plural(fmt_strong(u(2, m)), "# x", "# xs"))
  expect_true(got %in% c(paste0("**2", M, "** xs"), paste0("__2", M, "__ xs")), label = got)
  expect_equal(as.character(plural(u(2, m), "# x", "# xs")), paste0("2", M, " xs"))
})

test_that("review 2b #4/a: # of a list span over quantities is the collapsed list with the unit once, with or without a class (4.4.3)", {
  w <- function(cls) ws(sprintf("[# was | # were]{list=\"u(c(3,5), m)\"%s}", cls))
  expect_equal(w(""), paste0("3 and 5", M, " were"))
  expect_equal(w(" .num"), paste0("3 and 5", M, " were"))     # control: today's .num result
  expect_equal(w(" .num .or"), paste0("3 or 5", M, " were"))
  expect_equal(w(" .and"), paste0("3 and 5", M, " were"))
  expect_equal(w(" .range"), paste0("3–5", M, " were"))
  expect_equal(once(w("")), 1L)
})

test_that("review 2b #4/a: a list span over sites with .count puts the unit once after the last number (4.4.3)", {
  expect_equal(ws("[# was | # were]{list=\"u(c(3,12), sites)\" .count}"),
               paste0("three and 12", NBSP, "sites were"))
})

test_that("review 2b #4/a: a list span over plain numbers is unchanged (control)", {
  expect_equal(ws("[# was | # were]{list=\"c(3,5)\" .num}"), "3 and 5 were")
})

# ---- unit: a display unit ---------------------------------------------------------------------------

test_that("review 2b #unit: unit= converts a quantity before it prints, on a value construct and on fmt_num()", {
  expect_equal(ws("`r u(150, \"cm\")`{.num unit=\"m\"}"), paste0("1.5", M))
  expect_equal(rv(fmt_num(u(150, "cm"), unit = "m")), paste0("1.5", M))
  expect_equal(rv(fmt_num(u(1, "g/L"), unit = "mg/L")), paste0("1,000", NBSP, "mg/L"))
  expect_equal(attr(fmt_num(u(150, "cm"), unit = "m"), "unit"), "m")
  expect_equal(attr(fmt_num(u(150, "cm"), unit = "m"), "number"), 1.5)
  expect_equal(rv(fmt_num(u(150, "cm"))), paste0("150", NBSP, "cm"))   # control: no unit=
})

test_that("review 2b #unit: unit= on a governed span converts before the arm is chosen and # prints", {
  expect_equal(ws("[# is | # are]{n=\"u(100, cm)\" unit=\"m\"}"), paste0("1", M, " is"))
  expect_equal(ws("[# is | # are]{n=\"u(250, cm)\" unit=\"m\"}"), paste0("2.5", M, " are"))
  expect_equal(ws("[# is | # are]{n=\"u(100, cm)\"}"), paste0("100", NBSP, "cm are"))   # control
})

test_that("review 2b #unit: a unit that cannot be converted to, or unit= on a plain number, is a weft_value_error", {
  expect_weft_cond(a2_err(fmt_num(u(5, m), unit = "s")), "weft_value_error", "unit = s")
  expect_weft_cond(a2_err(fmt_num(5, unit = "m")), "weft_value_error", "unit = m on a plain number")
  expect_weft_cond(a2_err(weft_str("`r u(5, m)`{.num unit=\"s\"}")), "weft_value_error", "construct unit=s")
  expect_weft_cond(a2_err(weft_str("`r 5`{.num unit=\"m\"}")), "weft_value_error", "construct plain number")
  expect_no_error(fmt_num(u(5, m), unit = "cm"))   # control
})

# ---- 5: a list of quantities, a mixed_units vector -----------------------------------------------------

test_that("review 2b #5: a list of quantities and a mixed_units vector are a weft_value_error (4.4.5, 1.4.9)", {
  mu <- units::mixed_units(c(1, 2), c("m", "s"))
  expect_weft_cond(a2_err(fmt_and(list(u(3, m), u(4, s)))), "weft_value_error", "fmt_and(list)")
  expect_weft_cond(a2_err(fmt_and(mu)), "weft_value_error", "fmt_and(mixed_units)")
  expect_weft_cond(a2_err(weft_str("`r list(u(3,m), u(4,s))`{.and}")), "weft_value_error", "list construct")
  expect_weft_cond(a2_err(weft_str("`r units::mixed_units(c(1, 2), c('m', 's'))`{.and}")), "weft_value_error", "mixed construct")
  # control: a list of plain numbers
  expect_equal(rv(fmt_and(list(3, 4))), "3 and 4")
})

# ---- 6: ci(), pm(), clamp() ----------------------------------------------------------------------------

test_that("review 2b #6: ci(), pm() and clamp() given a formatter's text with a unit are a weft_value_error (D28)", {
  e <- a2_err(ci(fmt_num(u(2, m)), 1, 3))
  expect_weft_cond(e, "weft_value_error", "ci()")
  expect_match(conditionMessage(e), "does not take a quantity with a unit", fixed = TRUE)
  e <- a2_err(pm(fmt_num(u(2.1, m)), 0.3))
  expect_weft_cond(e, "weft_value_error", "pm()")
  expect_match(conditionMessage(e), "does not take a quantity with a unit", fixed = TRUE)
  e <- a2_err(clamp(fmt_num(u(150, m)), 1))
  expect_weft_cond(e, "weft_value_error", "clamp()")
  expect_match(conditionMessage(e), "does not take a quantity with a unit", fixed = TRUE)
  # control: the text of a plain number
  expect_equal(rv(ci(fmt_num(2), 1, 3)), "2 (95% CI 1 to 3)")
})

# ---- 7, e: of_n(), about() ---------------------------------------------------------------------------------

test_that("review 2b #7/e: of_n() converts the second quantity to the first's unit (ruling 7)", {
  expect_equal(rv(of_n(u(3, m), u(700, cm), "site", "sites")), "3 of the 7 sites")
  expect_equal(rv(of_n(u(300, cm), u(7, m), "site", "sites")), "300 of the 700 sites")
  # control: the same unit
  expect_equal(rv(of_n(u(3, m), u(7, m), "site", "sites")), "3 of the 7 sites")
})

test_that("review 2b #7/e: of_n() and about() on quantities that do not convert are a weft_value_error (ruling 7)", {
  expect_weft_cond(a2_err(of_n(u(3, m), u(7, kg), "site", "sites")), "weft_value_error", "of_n()")
  e <- a2_err(about(u(49, cm), to = u(0.5, kg)))
  expect_weft_cond(e, "weft_value_error", "about()")
  # the error is about the units, not the stock "further than the tolerance"
  expect_false(grepl("further than the tolerance", conditionMessage(e), fixed = TRUE))
})

# ---- 8: glue_vec() ---------------------------------------------------------------------------------------------

test_that("review 2b #8: glue_vec() prints a quantity's number as it prints a plain number (ruling 8)", {
  expect_equal(rv(glue_vec(u(c(1.234, 2), m))), paste0("1.234 and 2", NBSP, "m"))
  expect_equal(rv(glue_vec(c(1.234, 2))), "1.234 and 2")                     # control
  expect_equal(rv(glue_vec(u(c(0.25, 2), m) / u(1, m))), "0.25 and 2")       # control: a ratio
})

test_that("review 2b #8: glue_vec() of a small quantity neither rounds to zero nor warns (ruling 8)", {
  expect_no_warning(got <- glue_vec(u(c(0.04, 2), m)))
  expect_equal(rv(got), paste0("0.04 and 2", NBSP, "m"))
})

# ---- 9: a collapse over a text class's text -----------------------------------------------------------------------

test_that("review 2b #9: a collapse given a text class's text puts the unit once (3.4.4, stage iii)", {
  once <- function(x) lengths(regmatches(x, gregexpr(paste0(NBSP, "m"), x, fixed = TRUE)))
  q <- u(c(3, 5, 7), m)
  expect_equal(once(rv(fmt_and(fmt_strong(q)))), 1L)
  expect_equal(once(rv(fmt_and(fmt_em(q)))), 1L)
  expect_equal(once(rv(fmt_range(fmt_strong(u(c(3, 5), m))))), 1L)
  expect_false(grepl(paste0("3", NBSP, "m"), rv(fmt_and(fmt_strong(q))), fixed = TRUE))
  # control: the number-stage chain already puts the unit once
  expect_equal(rv(fmt_and(fmt_num(q))), paste0("3, 5 and 7", NBSP, "m"))
})

# ---- 10: subsetting ---------------------------------------------------------------------------------------------------

test_that("review 2b #10: subsetting a quantity's weft_text keeps its unit (ruling 10)", {
  f <- fmt_num(u(c(3, 5, 7), m))
  expect_equal(attr(f[2:3], "unit"), "m")
  expect_equal(rv(fmt_and(f[2:3])), paste0("5 and 7", NBSP, "m"))
  expect_equal(rv(fmt_range(f[1:2])), paste0("3–5", NBSP, "m"))
  expect_equal(rv(fmt_and(rev(f))), paste0("7, 5 and 3", NBSP, "m"))
  # control: the whole vector
  expect_equal(rv(fmt_and(f)), paste0("3, 5 and 7", NBSP, "m"))
})

# ---- 11: glue_vec() with NA or length zero ------------------------------------------------------------------------------

test_that("review 2b #11: glue_vec() of a quantity with NA or of length zero names the collapse, as for a plain vector", {
  for (x in list(u(c(3, NA), m), u(numeric(0), m))) {
    e <- a2_err(glue_vec(x))
    expect_weft_cond(e, "weft_no_value", "glue_vec(quantity)")
    expect_match(conditionMessage(e), "A collapse", fixed = TRUE)
  }
  # control: the plain vector
  expect_match(conditionMessage(a2_err(glue_vec(c(3, NA)))), "A collapse", fixed = TRUE)
})

# ---- 12, g: a unit's text is escaped ---------------------------------------------------------------------------------------

test_that("review 2b #12/g: a unit with an underscore is escaped so markdown does not read it as italic (ruling 12)", {
  try(units::install_unit("_ab_"), silent = TRUE)
  withr::defer(try(units::remove_unit("_ab_"), silent = TRUE))
  x <- fmt_num(u(5, "_ab_"))
  expect_true(grepl("\\_ab\\_", rv(x), fixed = TRUE), label = rv(x))
  expect_equal(attr(x, "unit"), "\\_ab\\_")
  # the superscript marks weft writes stay unescaped
  expect_equal(runit(u(5, "_ab_") * u(2, "_ab_")), "\\_ab\\_^2^")
  # control: a plain unit gains no backslash
  expect_false(grepl("\\", rv(fmt_num(u(5, m))), fixed = TRUE))
})

# ---- i: a unit with a power that is not whole ------------------------------------------------------------------------------

test_that("review 2b #i: u() refuses a power that is not a whole number (ruling i)", {
  expect_weft_cond(a2_err(u(1, "m^0.5")), "weft_unit_error", "u(m^0.5)")
  expect_no_error(u(1, "m^2"))   # control
})

test_that("review 2b #i: a dictionary entry with a power that is not whole is a problem (ruling i)", {
  p <- a2_file(c("a:", "  value: 1", "  type: quantity", "  unit: m^0.5", "  definition: \"A made-up thing.\""))
  expect_weft_cond(a2_err(read_dict(p)), "weft_dict_error", "read_dict(m^0.5)")
  p2 <- a2_file(c("a:", "  value: 1", "  type: quantity", "  unit: m^2", "  definition: \"A made-up thing.\""))
  expect_no_error(read_dict(p2))   # control
})

test_that("review 2b #unit: a back-reference prints the display unit its value printed in (4.4.14)", {
  got <- ws("`r u(150, 'cm')`{#k9 .num unit=\"m\"} then [# a | # b]{n=\"#k9\"}")
  expect_equal(got, paste0("1.5", M, " then 1.5", M, " b"))
})
