# Package 2b: printing quantities (a `units` value through the formatters).
# Contract: dev/design-2.md section 3 (with its expected-output table), D23-D30,
# section 7, section 9, K1 and K8. Rules 1.4.9, 3.4.4, 4.4.2, 4.4.3, 4.4.4,
# 4.4.8, 4.4.9, 4.4.10.
#
# Function forms first (fmt_*(), glue_vec(), plural(), the phrase functions),
# then one batched .Rmd render for the construct forms and the span, and one
# both() case. Made-up content only; the dictionary is the 2a fixture.

NB  <- " "     # the no-break space that joins a number and its unit
SUP2 <- "^2^"   # a Pandoc superscript two (ruling on 1/f replaces D23)
DOT <- "\u00b7"  # the middle dot that writes a product (ruling on 1/f)
MIN <- "−"     # minus sign
ENDASH <- "–"
TIMES2 <- "×"

pd <- function() read_dict(a2_fixture())
tx <- function(x) as.character(unclass(x))        # text of a weft_text, attributes dropped
# undo Pandoc's `\ `, and the `--` its markdown writer gives for an en dash
nbsp <- function(x) gsub("([0-9])--", "\\1\u2013", gsub("\\ ", NB, x, fixed = TRUE))

# ---- the unit's text (D23, 4.4.8) ------------------------------------------------------

test_that("2b unit text: a plain unit follows the number after a no-break space (4.4.8, R3)", {
  d <- pd()
  expect_equal(tx(fmt_num(d$core_len * 100)), paste0("50", NB, "m"))
  expect_equal(tx(fmt_num(u(35, m))), paste0("35", NB, "m"))
  expect_equal(tx(fmt_num(u(20, degC))), paste0("20", NB, "°C"))
  expect_equal(tx(fmt_num(u(5, mg/L))), paste0("5", NB, "mg/L"))
})

test_that("2b unit text: an exponent is written as a Pandoc superscript (D23, ruling on 1/f)", {
  d <- pd()
  expect_equal(tx(fmt_num(d$core_len * d$reach_len)), paste0("1", NB, "m", SUP2))
  expect_equal(tx(fmt_num(u(9.81, m/s^2))), paste0("9.8", NB, "m/s", SUP2))
  expect_equal(tx(fmt_num(u(1, m^3))), paste0("1", NB, "m^3^"))
})

test_that("2b unit text: a product is written with the middle dot (D23, ruling on 1/f)", {
  expect_equal(tx(fmt_num(u(1, kg * m))), paste0("1", NB, "kg", DOT, "m"))
})

test_that("2b unit text: a quotient, a registered unit and a project unit are written as units writes them (D23)", {
  d <- pd()
  expect_equal(tx(fmt_num(u(5, sites) / u(2, ha))), paste0("2.5", NB, "sites/ha"))
  expect_equal(tx(fmt_num(d$salinity_res * 2, digits = 2)), paste0("0.02", NB, "PSU"))
  expect_equal(tx(fmt_num(u(12, mm/hr))), paste0("12", NB, "mm/h"))
})

test_that("2b unit text: a value with no unit left prints the number alone (D30, 4.4.8)", {
  d <- pd()
  expect_equal(tx(fmt_num(d$core_len / d$reach_len, digits = 2)), "0.25")
  expect_equal(tx(fmt_num(u(6, m) / u(3, m))), "2")
  expect_null(attr(fmt_num(d$core_len / d$reach_len), "unit"))
})

test_that("2b control: a plain number formats as before", {
  expect_equal(tx(fmt_num(3.14159)), "3.1")
  expect_equal(tx(fmt_num(1234)), "1,234")
  expect_null(attr(fmt_num(3.14159), "unit"))
})

# ---- the number stage (stage i) -----------------------------------------------------

test_that("2b stage i: digits and sigfig act on the number, the unit follows", {
  expect_equal(tx(fmt_num(u(3.14159, m), digits = 2)), paste0("3.14", NB, "m"))
  expect_equal(tx(fmt_num(u(0.012345, kg), sigfig = 2)), paste0("0.012", NB, "kg"))
  expect_equal(tx(fmt_num(u(1234.5, m))), paste0("1,234.5", NB, "m"))
})

test_that("2b stage i: .sci puts the unit after the power (table)", {
  # the control fixes the spacing of the stock form; the quantity adds NB + unit
  stock <- tx(fmt_sci(1200))
  expect_equal(stock, paste0("1.2 ", TIMES2, " 10^3^"))
  expect_equal(tx(fmt_sci(u(1200, m))), paste0(stock, NB, "m"))
})

test_that("2b stage i: a missing quantity is the no-value failure, as for a number (4.4.2)", {
  expect_error(fmt_num(u(NA_real_, m)), class = "weft_no_value")
})

# ---- the record (K1, 4.4.4) -------------------------------------------------------------

test_that("2b record: number and raw hold the number without its unit; the unit is its own attribute (K1, D29)", {
  d <- pd()
  x <- fmt_num(d$core_len * 100)
  expect_s3_class(x, "weft_text")
  expect_equal(tx(x), paste0("50", NB, "m"))
  expect_equal(attr(x, "number"), 50)
  expect_false(inherits(attr(x, "number"), "units"))
  expect_equal(as.numeric(attr(x, "raw")), 50)
  expect_false(inherits(attr(x, "raw"), "units"))
  expect_equal(attr(x, "unit"), "m")
  expect_equal(attr(x, "relation"), "=")
})

test_that("2b record: the unit attribute is the unit's text, with superscripts; absent for a plain number (D23)", {
  d <- pd()
  expect_equal(attr(fmt_num(d$core_len * d$reach_len), "unit"), paste0("m", SUP2))
  expect_equal(attr(fmt_num(u(1, kg * m)), "unit"), paste0("kg", DOT, "m"))
  expect_null(attr(fmt_num(2), "unit"))
})

test_that("2b record: a rounded quantity records the number as printed (1.4.11)", {
  x <- fmt_num(u(3.14159, m), digits = 2)
  expect_equal(attr(x, "number"), 3.14)
  expect_equal(attr(x, "unit"), "m")
})

# ---- chained calls print the unit once (D29) --------------------------------------------

test_that("2b chain: a number-stage formatter given a quantity's weft_text formats raw afresh and adds the unit once (D29)", {
  x <- fmt_num(u(3.14159, m))
  y <- fmt_num(x, digits = 2)
  expect_equal(tx(y), paste0("3.14", NB, "m"))
  expect_equal(tx(fmt_num(fmt_num(u(50, m)))), paste0("50", NB, "m"))
  expect_equal(tx(fmt_sci(fmt_num(u(1200, m)))), paste0(tx(fmt_sci(1200)), NB, "m"))
})

test_that("2b chain: a collapse given the weft_text places the unit once (D29)", {
  expect_equal(tx(fmt_and(fmt_num(u(c(3, 5, 7), m)))), paste0("3, 5 and 7", NB, "m"))
  expect_equal(tx(fmt_or(fmt_num(u(c(3, 5, 7), m)))), paste0("3, 5 or 7", NB, "m"))
})

test_that("2b chain: wording and text classes keep the record's unit rules (stage ii, stage iv)", {
  expect_equal(tx(fmt_word(fmt_num(u(3, m)))), paste0("three", NB, "metres"))
  expect_equal(tx(fmt_a(fmt_num(u(8, m)))), paste0("an 8", NB, "m"))
  expect_match(tx(fmt_strong(fmt_num(u(3, m)))),
               paste0("^(\\*\\*|__)3", NB, "m(\\*\\*|__)$"))
})

# ---- wording classes (stage ii) --------------------------------------------------------

test_that("2b stage ii: an element turned into a word takes the unit's name (2f, 4.4.2); one in digits takes the symbol", {
  # 2f: a wording class needs a name, judged on the class: sites has none without a units: entry
  expect_error(fmt_count(u(3, sites)), class = "weft_value_error")
  expect_error(fmt_count(u(12, sites)), class = "weft_value_error")
  expect_equal(tx(fmt_count(u(12, m))), paste0("12", NB, "m"))
  expect_equal(tx(fmt_word(u(3, m))), paste0("three", NB, "metres"))
  expect_equal(tx(fmt_no(u(0, m))), paste0("no", NB, "metres"))
  expect_equal(tx(fmt_no(u(2, m))), paste0("2", NB, "m"))   # control: .no leaves a non-zero value
  expect_equal(tx(fmt_ord(u(3, m))), paste0("3rd", NB, "m"))
  expect_equal(tx(fmt_word(u(120, m))), paste0("120", NB, "m"))   # at or above word_limit: digits
  expect_equal(tx(fmt_a(u(8, m))), paste0("an 8", NB, "m"))
})

test_that("2b control: wording classes on plain numbers are unchanged", {
  expect_equal(tx(fmt_count(3)), "three")
  expect_equal(tx(fmt_count(12)), "12")
  expect_equal(tx(fmt_no(0)), "no")
  expect_equal(tx(fmt_a(8)), "an 8")
})

# ---- collapse classes (stage iii, D24, D25) ----------------------------------------------

test_that("2b stage iii: .and, .or and .range put the unit once, after the last number (D24)", {
  expect_equal(tx(fmt_and(u(c(3, 5, 7), m))), paste0("3, 5 and 7", NB, "m"))
  expect_equal(tx(fmt_or(u(c(3, 5, 7), m))), paste0("3, 5 or 7", NB, "m"))
  expect_equal(tx(fmt_range(u(c(3, 5), m))), paste0("3", ENDASH, "5", NB, "m"))
  expect_equal(tx(fmt_range(u(c(-3, 5), m))), paste0(MIN, "3 to 5", NB, "m"))
  expect_equal(tx(fmt_and(u(c(3, 5), m))), paste0("3 and 5", NB, "m"))
})

test_that("2b stage iii: glue_vec() on a quantity puts the unit once, after the last number", {
  expect_equal(tx(glue_vec(u(c(3, 5, 7), m))), paste0("3, 5 and 7", NB, "m"))
  expect_equal(tx(glue_vec(u(c(3, 5), m), last = " or ")), paste0("3 or 5", NB, "m"))
})

test_that("2b stage iii: with trunc the unit follows the last number printed, before 'and N others' (D24)", {
  expect_equal(tx(fmt_and(u(c(3, 5, 7, 9), m), trunc = 2)),
               paste0("3, 5", NB, "m and 2 others"))
})

test_that("2b stage iii: when the last element is a word the unit after it is its name (2f, D24 replaced)", {
  # 5 prints as a word under .word, 20 stays in digits: only the last element decides
  expect_equal(tx(fmt_and(fmt_word(u(c(200, 5), m)))), paste0("200 and five", NB, "metres"))
  expect_equal(tx(glue_vec(fmt_word(u(c(5, 200), m)))), paste0("five and 200", NB, "m"))
})

test_that("2b stage iii: .pairs puts the unit on every value, in its parentheses", {
  expect_equal(tx(fmt_pairs(u(c(a = 3, b = 5), m))),
               paste0("a (3", NB, "m) and b (5", NB, "m)"))
})

test_that("2b stage iii: .ul and .ol put the unit on every element", {
  expect_equal(tx(fmt_ul(u(c(3, 5), m))), paste0("\n- 3", NB, "m\n- 5", NB, "m\n"))
  expect_match(tx(fmt_ol(u(c(3, 5), m))), paste0("1\\. 3", NB, "m"))
  expect_match(tx(fmt_ol(u(c(3, 5), m))), paste0("2\\. 5", NB, "m"))
})

test_that("2b stage iii: a vector that no collapse class joins prints the unit on every element (D25)", {
  x <- fmt_num(u(c(3, 5), m))
  expect_equal(unname(tx(x)), paste0(c("3", "5"), NB, "m"))
})

test_that("2b control: collapse classes on plain numbers are unchanged", {
  expect_equal(tx(fmt_and(c(3, 5, 7))), "3, 5 and 7")
  expect_equal(tx(fmt_range(c(3, 5))), paste0("3", ENDASH, "5"))
  expect_equal(tx(fmt_and(c(3, 5, 7, 9), trunc = 2)), "3, 5 and 2 others")
})

# ---- text classes (stage iv) -------------------------------------------------------------

test_that("2b stage iv: a text class acts on the text with its unit", {
  expect_match(tx(fmt_strong(u(3, m))), paste0("^(\\*\\*|__)3", NB, "m(\\*\\*|__)$"))
  expect_match(tx(fmt_em(u(3, m))), paste0("^(\\*|_)3", NB, "m(\\*|_)$"))
})

# ---- .pct, .p, .date (D27, K8) ---------------------------------------------------------------

test_that("2b pct: a ratio is a plain number to .pct and prints 25% with no space (K8, D27)", {
  d <- pd()
  expect_equal(tx(fmt_pct(d$core_len / d$reach_len)), "25%")
  expect_equal(tx(fmt_pct(u(6, m) / u(3, m))), "200%")
})

test_that("2b pct: .pct, .p and .date on a quantity with a unit left are a weft_value_error naming the class and the unit (D27)", {
  e <- a2_err(fmt_pct(u(3, m)))
  expect_weft_cond(e, "weft_value_error", ".pct")
  expect_match(conditionMessage(e), "`.pct`", fixed = TRUE)
  expect_match(conditionMessage(e), "cannot format a quantity in m", fixed = TRUE)
  expect_match(conditionMessage(e), "4.4.8", fixed = TRUE)

  e <- a2_err(fmt_p(u(0.03, m)))
  expect_weft_cond(e, "weft_value_error", ".p")
  expect_match(conditionMessage(e), "quantity in m", fixed = TRUE)

  e <- a2_err(fmt_date(u(3, m)))
  expect_weft_cond(e, "weft_value_error", ".date")
  expect_match(conditionMessage(e), "quantity in m", fixed = TRUE)
})

test_that("2b pct: .p on a ratio is a number (D27)", {
  d <- pd()
  expect_no_error(fmt_p(d$core_len / d$reach_len))
  expect_false(grepl("m", tx(fmt_p(d$core_len / d$reach_len)), fixed = TRUE))
})

# ---- governors and bare values (4.4.4, 4.4.9, 4.4.10) --------------------------------------

test_that("2b governor: a quantity as the n governor contributes its number, and # carries its unit (4.4.4 reversed)", {
  d <- pd()
  expect_equal(as.character(plural(u(1, m), "# metre", "# metres")), paste0("1", NB, "m metre"))
  expect_equal(as.character(plural(u(3, m), "# metre", "# metres")), paste0("3", NB, "m metres"))
  expect_equal(as.character(plural(d$core_len, "# metre", "# metres")), paste0("0.5", NB, "m metres"))
})

test_that("2b bare: a bare value prints as stock does, the number alone (4.4.10)", {
  d <- pd()
  expect_equal(as.character(as.numeric(d$core_len)), "0.5")
})

# ---- phrase functions (D28) --------------------------------------------------------------------

test_that("2b phrases: of_n() and about() take the number of a quantity and print no unit (D28, 4.4.2)", {
  expect_equal(tx(of_n(u(3, m), u(7, m), "site", "sites")), "3 of the 7 sites")
  expect_equal(tx(of_n(u(7, m), u(7, m), "site", "sites")), "all 7 sites")
  expect_equal(attr(of_n(u(3, m), 7, "site", "sites"), "number"), 3)
  expect_equal(tx(about(u(0.5, m))), "half")
  expect_equal(tx(about(u(0.52, m))), "just over half")
})

test_that("2b phrases: ci(), pm() and clamp() error on a quantity with a unit (D28)", {
  e <- a2_err(ci(u(0.5, m), 0.3, 0.7))
  expect_weft_cond(e, "weft_value_error", "ci()")
  expect_match(conditionMessage(e), "`ci()` does not take a quantity with a unit", fixed = TRUE)

  e <- a2_err(pm(u(0.5, m), 0.1))
  expect_weft_cond(e, "weft_value_error", "pm()")
  expect_match(conditionMessage(e), "`pm()` does not take a quantity with a unit", fixed = TRUE)

  e <- a2_err(clamp(u(0.5, m), 1))
  expect_weft_cond(e, "weft_value_error", "clamp()")
  expect_match(conditionMessage(e), "`clamp()` does not take a quantity with a unit", fixed = TRUE)
})

test_that("2b phrases: the message tells the writer what to pass instead (D28)", {
  e <- a2_err(ci(u(0.5, m), 0.3, 0.7))
  expect_false(is.null(e), label = "ci() raised an error")
  expect_match(conditionMessage(e %||% simpleError("")), "fmt_num()", fixed = TRUE)
})

test_that("2b control: ci(), pm() and clamp() on plain numbers, and on a ratio, are unchanged (D28)", {
  d <- pd()
  expect_equal(tx(ci(0.5, 0.3, 0.7)), "0.5 (95% CI 0.3 to 0.7)")
  expect_no_error(ci(d$core_len / d$reach_len, 0.1, 0.4))
  expect_no_error(pm(d$core_len / d$reach_len, 0.1))
  expect_no_error(clamp(d$core_len / d$reach_len, 1))
})

# ---- one batched render: construct forms and the span ---------------------------------------

DICT_2B <- a2_fixture_lines()

BATCH_2B <- c(
  "`r dict$core_len * 100`{.num}",                                         #  1 50 m
  "`r dict$core_len / dict$reach_len`{.num digits=\"2\"}",                  #  2 0.25
  "`r dict$core_len / dict$reach_len`{.pct}",                              #  3 25%
  "`r dict$core_len * dict$reach_len`{.num}",                              #  4 1 m2
  "`r dict$core_len + dict$sample_mass`{.num}",                            #  5 no value (units: cannot convert)
  "`r dict$salinity_res * 2`{.num digits=\"2\"}",                          #  6 0.02 PSU
  "`r u(5, sites) / u(2, ha)`{.num}",                                      #  7 2.5 sites/ha
  "`r u(9.81, m/s^2)`{.num}",                                              #  8 9.8 m/s2
  "`r u(1, kg*m)`{.num}",                                                  #  9 1 kg.m
  "`r u(20, degC)`{.num}",                                                 # 10 20 degC
  "`r u(1200, m)`{.sci}",                                                  # 11 1.2 x 10^3^ m
  "`r u(c(3, 5), m)`{.range}",                                             # 12 3-5 m
  "`r u(c(-3, 5), m)`{.range}",                                            # 13 -3 to 5 m
  "`r u(c(3, 5, 7), m)`{.and} / `r u(c(3, 5, 7), m)`{.or}",                # 14
  "`r u(c(3, 5, 7, 9), m)`{.and trunc=\"2\"}",                             # 15
  "`r u(c(a = 3, b = 5), m)`{.pairs}",                                     # 16
  "`r u(c(3, 5), m)`{.num}",                                               # 17 each element
  "`r u(3, m)`{.count} / `r u(12, m)`{.count}",                          # 18
  "`r u(3, m)`{.word}",                                                    # 19 three
  "`r u(0, m)`{.no}",                                                      # 20 no
  "`r u(8, m)`{.a} / `r u(3, m)`{.strong}",                                # 21
  "`r u(3, m)`{.pct}",                                                     # 22 value error
  "[# metre | # metres]{n=\"dict$core_len\"}",                             # 23 0.5 metres
  "`r dict$core_len`",                                                     # 24 bare: 0.5
  "`r dict$core_len`{#q2b .num} and [# metre | # metres]{n=\"#q2b\"}",     # 25 record of a governor
  "[up # | down # | flat]{sign=\"dict$core_len\"}",                        # 26 up 0.5
  "[# metre | # metres]{n=\"u(1, m)\"}",                                   # 27 1 metre
  "`r u(6, m) / u(3, m)`{.num}"                                            # 28 2 (ratio, no unit)
)

B2B_WANT <- c(
  paste0("50", NB, "m"),
  "0.25",
  "25%",
  paste0("1", NB, "m", SUP2),
  NA,
  paste0("0.02", NB, "PSU"),
  paste0("2.5", NB, "sites/ha"),
  paste0("9.8", NB, "m/s", SUP2),
  paste0("1", NB, "kg", DOT, "m"),
  paste0("20", NB, "°C"),
  paste0("1.2 ", TIMES2, " 10^3^", NB, "m"),
  paste0("3", ENDASH, "5", NB, "m"),
  paste0(MIN, "3 to 5", NB, "m"),
  paste0("3, 5 and 7", NB, "m / 3, 5 or 7", NB, "m"),
  paste0("3, 5", NB, "m and 2 others"),
  paste0("a (3", NB, "m) and b (5", NB, "m)"),
  paste0("3", NB, "m, 5", NB, "m"),
  paste0("three", NB, "metres / 12", NB, "m"),
  paste0("three", NB, "metres"),
  paste0("no", NB, "metres"),
  paste0("an 8", NB, "m / **3", NB, "m**"),
  NA,
  paste0("0.5", NB, "m metres"),
  "0.5",
  paste0("0.5", NB, "m and 0.5", NB, "m metres"),
  paste0("up 0.5", NB, "m"),
  paste0("1", NB, "m metre"),
  "2"
)

b2b_render <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(batch_cases(BATCH_2B), files = list("dict.yml" = DICT_2B),
                           in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

b2b_got <- function() {
  res <- b2b_render()
  nbsp(unesc(split_cases(res, length(BATCH_2B))))
}

b2b_failures_text <- function() {
  f <- b2b_render()$knit$failures
  if (!NROW(f)) return(character())
  vapply(seq_len(NROW(f)), function(i) paste(unlist(f[i, ]), collapse = " "), "")
}

test_that("2b render: the batch renders (a failure is collected in draft mode)", {
  res <- b2b_render()
  expect_false(res$failed, label = res$message)
})

test_that("2b render: every construct form of the table prints as the contract says", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  got <- b2b_got()
  for (i in seq_along(B2B_WANT)) {
    if (is.na(B2B_WANT[i])) next
    expect_equal(got[i], B2B_WANT[i], label = sprintf("case %d: %s", i, BATCH_2B[i]))
  }
})

test_that("2b render: x + a mass is the 'no value' failure quoting units' message (table)", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  expect_true(any(grepl("cannot convert kg into m", b2b_failures_text(), fixed = TRUE)))
})

test_that("2b render: .pct on a quantity with a unit is a value error naming .pct and m (D27)", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  ft <- b2b_failures_text()
  hit <- ft[grepl("cannot format a quantity in m", ft, fixed = TRUE)]
  expect_gte(length(hit), 1L)
  expect_true(any(grepl(".pct", hit, fixed = TRUE)))
})

test_that("2b render: no failure other than the two the batch asks for", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  expect_equal(length(b2b_failures_text()), 2L)
})

test_that("2b render: a span with an n or sign governor that is a quantity prints # with its unit (4.4.4 reversed, table)", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  got <- b2b_got()
  expect_equal(got[23], paste0("0.5", NB, "m metres"))
  expect_equal(got[27], paste0("1", NB, "m metre"))
  expect_equal(got[26], paste0("up 0.5", NB, "m"))
})

test_that("2b render: the record behind an id holds no unit, so a governor on the id prints the unit from the value (4.4.4 reversed, K1)", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  expect_equal(b2b_got()[25], paste0("0.5", NB, "m and 0.5", NB, "m metres"))
})

test_that("2b render: a bare value prints as stock knitr prints it (4.4.10)", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  expect_equal(b2b_got()[24], "0.5")
})

test_that("2b render: a ratio of two quantities prints as a plain number (D30)", {
  res <- b2b_render()
  skip_if(res$failed, "the batch did not render")
  expect_equal(b2b_got()[28], "2")
})

# ---- Quarto --------------------------------------------------------------------------------------------

test_that("2b quarto: a quantity prints with its unit under Quarto and rmarkdown alike", {
  lines <- c("Core `r dict$core_len * 100`{.num} and `r u(c(3, 5), m)`{.range} end.")
  both(lines, function(res, engine) {
    expect_false(res$failed, label = paste(engine, res$message))
    expect_match(nbsp(res$md),
                 paste0("Core 50", NB, "m and 3", ENDASH, "5", NB, "m end."),
                 fixed = TRUE, label = engine)
  }, files = list("dict.yml" = DICT_2B))
})
