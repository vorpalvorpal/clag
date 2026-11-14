# Stages 1b and 1d: the failures the new pieces collect, with their markers in
# draft mode and their lines in the report (1.5.3, 1.5.11, 1.5.17, 5.3.2,
# 1.3.4, 3.3.5, 2.6.1, 2.6.2, 2.6.8, 2.6.9), and the construct errors the
# scanner finds for them, once as markers in draft mode (2.6.5, 5.3.1, 1.6.8).
#
# One document per case, rendered in this process with knitr::knit(), so the
# output is what weft wrote and last_knit() is available.

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- the rows that fail at knit time ---------------------------------------------------------

mk_value_error <- function(tag, src, rule) {
  b_row(tag, paste0(src, " x"), rule, want = paste0(tag, " <<weft: value error, line @L@>> x"))
}
mk_no_value <- function(tag, src, rule) {
  b_row(tag, paste0(src, " x"), rule, want = paste0(tag, " <<weft: no value, line @L@>> x"))
}

FAIL_ROWS <- list(
  b_row("S01", "[RISE | FALL]{sign=\"zero_chg\"} x", "1.5.3 + 2.6.8: a two-arm sign at zero is a failed claim",
        rx = "^S01 .*<<weft: failed claim, line @L@>>"),
  b_row("S02", "[RISE | FALL]{sign=\"0.02\" digits=\"1\"} x",
        "1.5.3 + 1.5.10: a two-arm sign that prints 0.0 is a failed claim",
        rx = "^S02 .*<<weft: failed claim, line @L@>>"),
  mk_value_error("S03", "[UP | DOWN]{sign=\"clamp(0.05, 1)\"}", "1.5.17 + 5.3.2: a sign governor that prints as a bound"),
  mk_value_error("S04", "[a | b]{sign=\"c(1, 2)\"}", "5.3.2 + 1.5.1: a sign governor that is a vector"),
  mk_value_error("S05", "[a | b]{sign=\"'up'\"}", "5.3.2 + 1.5.1: a sign governor that is a string"),
  mk_no_value("S06", "[a | b]{sign=\"NA_real_\"}", "1.3.4: NA in a sign governor"),
  mk_value_error("S07", "`r c(1, 2, 3)`{.range}", "5.3.2: .range on a value of length 3"),
  mk_value_error("S08", "`r 1`{.range}", "5.3.2: .range on a value of length 1"),
  mk_no_value("S09", "`r c(1, NA)`{.range}", "1.3.4: NA reaching .range"),
  mk_value_error("S10", "[# a | # b]{n=\"c(1, 2)\"}", "1.5.11: a vector n with no .range"),
  mk_value_error("S11", "[apple]{.a}", "1.4.5 + 5.3.2: .a on a text span that is not a number"),
  mk_value_error("S12", "`r 'apple'`{.a}", "1.4.5 + 5.3.2: .a on a value that is not a number"),
  mk_value_error("S13", "`r 1.5`{.p}", "5.3.2 + design: .p above 1"),
  mk_value_error("S14", "`r -0.1`{.p}", "5.3.2 + design: .p below 0"),
  mk_no_value("S15", "`r NA_real_`{.p}", "1.3.4: NA under .p"),
  mk_value_error("S16", "`r '2024-06-03'`{.date}", "design: .date on a string"),
  mk_no_value("S17", "`r as.Date(NA)`{.date}", "1.3.4: NA under .date"),
  mk_value_error("S18", "`r of_n(5, 3, 'site', 'sites')`{.cap}", "design: of_n() with k > n"),
  mk_value_error("S19", "`r of_n(1, 0, 'site', 'sites')`{.cap}", "design: of_n() with n = 0"),
  mk_no_value("S20", "`r of_n(NA_real_, 3, 'site', 'sites')`{.cap}", "1.3.4 + 3.5.1: NA reaching of_n()"),
  mk_value_error("S21", "`r about(0.9)`{.cap}", "design: about() further than the tolerance"),
  mk_value_error("S22", "`r tier_lab('zz')`{.cap}", "3.3.2: an unknown key to a lookup() function"),
  mk_no_value("S23", "`r tier_lab(NA_character_)`{.cap}", "3.3.5: NA to a lookup() function"),
  mk_value_error("S24", "`r only_neg(5)`{.cap}", "design: a value no brk() formula takes"),
  mk_no_value("S25", "`r trend(NA_real_)`{.cap}", "3.3.5: NA to a brk() function with a TRUE ~ default"),
  mk_value_error("S26", "`r clamp(0.5, 1)`{.word}", "1.4.12: clamp() then a wording class on a bound"),
  mk_no_value("S27", "`r ci(NA_real_, 1, 2)`{.cap}", "1.3.4 + 3.5.1: NA reaching ci()"),
  mk_no_value("S28", "`r pm(2.1, NA_real_)`{.cap}", "1.3.4 + 3.5.1: NA reaching pm()"),
  mk_value_error("S29", "`r c(1, 2)`{.pairs}", "design: an unnamed vector to .pairs"),
  # controls: the legal sibling of several of the rows above, no marker
  b_row("C01", "`r clamp(5, 1)`{.word} x", "control (S26): clamp() inside its bounds, then .word",
        want = "C01 five x", collected = FALSE),
  b_row("C02", "`r about(0.49)`{.cap} x", "control (S21): about() within tolerance",
        want = "C02 Nearly half x", collected = FALSE),
  b_row("C03", "[UP | DOWN]{sign=\"d3\"} x", "control (S01): a two-arm sign at 3",
        want = "C03 UP x", collected = FALSE),
  b_row("C04", "`r c(1, 2)`{.range} x", "control (S07): .range on length 2",
        want = paste0("C04 1", B_EN, "2 x"), collected = FALSE),
  b_row("C05", "`r tier_lab('hi')`{.cap} x", "control (S22): a known key", want = "C05 High x", collected = FALSE),
  b_row("C06", "`r trend(1)`{.cap} x", "control (S25): a value brk() takes", want = "C06 Steady x", collected = FALSE),
  b_row("C07", "[apple]{.strong} x", "control (S11): a text span that is not a number, with a class that does not care",
        want = "C07 **apple** x", collected = FALSE),
  b_row("C08", "`r 0.03`{.p} x", "control (S13): .p inside 0 to 1", want = "C08 p = 0.030 x", collected = FALSE)
)
FAIL_COLLECTED <- Filter(function(r) isTRUE(r$collected), FAIL_ROWS)

fail_draft <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    b <- b_body(FAIL_ROWS)
    res <- render_rmd(b$lines, code = PRE_B, env = c(WEFT_DRAFT = "1"),
                      format = "knit", in_process = TRUE)
    res$b <- b
    cache <<- res
    res
  }
})

test_that("2.6.8 + 9.4.2: every collected failure of the new pieces leaves its marker in draft mode, controls none", {
  res <- fail_draft()
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  b_check_lines(res, res$b, FAIL_ROWS, "rmarkdown")
  txt <- unesc(res$text)
  expect_equal(sum(grepl("<<weft:", txt, fixed = TRUE)), length(FAIL_COLLECTED))
})

test_that("1.5.3 + 2.6.8: a sign span with no arm for its value prints no fallback text", {
  res <- fail_draft()
  b_need(res)
  txt <- unesc(res$text)
  for (tag in c("S01", "S02")) {
    line <- grep(paste0("^", tag, " "), txt, value = TRUE)
    expect_false(grepl("RISE|FALL", line), label = tag)
  }
})

test_that("1.5.17: a sign governor that prints as a bound prints no arm", {
  res <- fail_draft()
  b_need(res)
  line <- grep("^S03 ", unesc(res$text), value = TRUE)
  expect_false(grepl("UP|DOWN", line))
})

test_that("2.6.9 + 21: every one is in last_knit()$failures with the right kind and line", {
  res <- fail_draft()
  b_need(res)
  f <- res$knit$failures
  expect_equal(nrow(f), length(FAIL_COLLECTED))
  lines <- res$offset + res$b$at[match(vapply(FAIL_COLLECTED, function(r) r$tag, ""),
                                       vapply(FAIL_ROWS, function(r) r$tag, ""))]
  expect_setequal(f$line, lines)
  want_kind <- vapply(FAIL_COLLECTED, function(r) {
    if (grepl("failed claim", r$rx %||% "")) "failed claim"
    else if (grepl("no value", r$want %||% "")) "no value"
    else "value error"
  }, "")
  for (i in seq_along(FAIL_COLLECTED)) {
    expect_equal(f$kind[f$line == lines[i]], want_kind[i], label = FAIL_COLLECTED[[i]]$tag)
  }
  expect_true(all(c("failed claim", "no value", "value error") %in% f$kind))
})

test_that("21 + 2.6.1: without draft mode the same document runs to the end and fails once, with every failure reported", {
  b <- b_body(FAIL_ROWS)
  res <- render_rmd(c(b$lines, "Final `r k`{.word} line."), code = PRE_B, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  f <- res$knit$failures
  expect_equal(nrow(f), length(FAIL_COLLECTED))
  # each failure is located by its own line in the report
  for (r in FAIL_COLLECTED) {
    k <- match(r$tag, vapply(FAIL_ROWS, function(r) r$tag, ""))
    expect_match(res$message, at_line(res, b$at[k]), label = r$tag)
  }
  # the controls are not in the report
  for (tag in c("C01", "C02", "C03", "C04", "C05", "C06", "C07", "C08")) {
    k <- match(tag, vapply(FAIL_ROWS, function(r) r$tag, ""))
    expect_false(grepl(at_line(res, b$at[k]), res$message), label = tag)
  }
  # 2.6.7: the kinds are told apart
  expect_match(res$message, "weft: [0-9]+ claims? failed")
  expect_match(res$message, "weft: [0-9]+ failures?")
  # 2.6.1: the construct after every failure was evaluated
  fin <- res$knit$constructs[res$knit$constructs$line == res$offset + length(b$lines) + 1L, ]
  expect_true(nrow(fin) >= 1L && all(fin$evaluated))
})

test_that("1.5.11: the report for a vector n says to write length(x)", {
  src <- c("See [# a | # b]{n=\"sites\"} here.")
  res <- render_rmd(src, code = PRE_B, in_process = TRUE)
  expect_true(res$failed)
  expect_match(paste(res$message, paste(res$knit$failures$detail, collapse = " ")), "length(", fixed = TRUE)
})

# ---- construct errors, as markers in draft mode ------------------------------------------------

mk_cerr <- function(tag, src, rule) {
  b_row(tag, paste0(src, " x"), rule, rx = paste0("^", tag, " .*<<weft: construct error, line @L@>>"))
}

CERR_ROWS <- list(
  mk_cerr("E01", "`r k`{#zdup .num} and `r k`{#zdup .num}.", "1.7.5: a duplicate id"),
  mk_cerr("E02", "[# a | # b]{n=\"#zunknown\"}.", "1.7.10: a back-reference to an unknown id"),
  mk_cerr("E03", "[# a | # b]{n=\"#zlater\"}.", "1.7.10: a back-reference to an id defined further down"),
  b_row("E03d", "defined later `r k`{#zlater .num} x.", "control (E03): the later definition itself is legal",
        want = "E03d defined later 3 x.", collected = FALSE),
  mk_cerr("E04", "[a | b]{n=\".\"}.", "1.7.2: n=\".\" outside an n or sign span"),
  mk_cerr("E05", "[a]{sign=\"d3\"}.", "1.5.2: a sign span with one arm"),
  mk_cerr("E06", "[a | b]{sign=\".\"}.", "1.7.2: there is no sign=\".\""),
  mk_cerr("E07", "Items `r sites`{.ul} here.", "1.4.6: a list class on a value not alone in its paragraph"),
  mk_cerr("E08", "[0.45]{.weft-literal}.", "1.8.10: a .weft-literal span with no why"),
  mk_cerr("E09", "[a]{cite=\"see smith2020\"}.", "1.8.4: a bare-form cite that is not keys only"),
  mk_cerr("E10", "[a]{.num cite=\"@smith2020\"}.", "1.8.7: a formatter class on a cite span"),
  mk_cerr("E11", "`r 0.03`{.p sigfig=\"2\"}.", "design: sigfig with .p"),
  mk_cerr("E12", "[a]{#ztx .strong}.", "1.1.9: an id on a text span"),
  mk_cerr("E13", "[a]{#zcx cite=\"@smith2020\"}.", "1.7.5: an id on a cite span"),
  mk_cerr("E14", "`r 0.03`{.num .p}.", "1.4.2: .num and .p"),
  mk_cerr("E15", "`r c(1, 2)`{.range .and}.", "1.4.2: .range and .and"),
  mk_cerr("E16", "[a | b | c | d]{sign=\"d3\"}.", "1.5.2: a sign span with four arms"),
  # controls beside them: legal siblings, no marker
  b_row("C01", "[a | b]{sign=\"d3\"} and `r k`{#zok .num} [x | y]{n=\"#zok\"} x.", "control: a legal sign span and a legal back-reference",
        want = "C01 a and 3 y x.", collected = FALSE),
  b_row("C02", "[0.45]{.weft-literal why=\"w\"} x.", "control (E08): a literal with a why", want = "C02 [0.45]{.weft-literal} x.", collected = FALSE)
)
CERR_ERRORS <- Filter(function(r) isTRUE(r$collected), CERR_ROWS)

test_that("2.6.5 + 9.4.3 + 5.3.1: construct errors found for the new pieces are markers on their lines in draft mode", {
  b <- b_body(CERR_ROWS)
  res <- render_rmd(b$lines, code = PRE_B, env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  b_check_lines(res, b, CERR_ROWS, "rmarkdown")
  txt <- unesc(res$text)
  expect_equal(sum(grepl("<<weft: construct error", txt, fixed = TRUE)), length(CERR_ERRORS))
  expect_equal(sum(grepl("<<weft:", txt, fixed = TRUE)), length(CERR_ERRORS))
  expect_false(any(grepl("not built yet", paste(res$knit$failures$detail, collapse = " "))))
})

test_that("2.6.5: a construct error of the new pieces stops a non-draft render at once, class weft_construct_error", {
  for (src in c("A [a | b | c | d]{sign=\"d3\"} here.", "A [# a | # b]{n=\"#zunknown\"} here.")) {
    res <- render_rmd(c("Intro.", "", src, "", "End."), code = PRE_B)
    expect_true(res$failed, label = src)
    expect_true("weft_construct_error" %in% res$error$class, label = src)
    expect_match(res$message, at_line(res, 3), label = src)
    expect_false(grepl("not built yet", res$message), label = src)
  }
})

# ---- 1.6.8: word-printing names under a language weft does not ship ------------------------------------

mk_lang <- function(tag, src, rule) {
  b_row(tag, paste0(src, " y"), rule, rx = paste0("^", tag, " .*<<weft: construct error, line @L@>>"))
}

LANG_ROWS <- list(
  mk_lang("L01", "`r k`{.a}", "1.6.8: .a"),
  mk_lang("L02", "`r sites`{.and}", "1.6.8: .and"),
  mk_lang("L03", "`r sites`{.or}", "1.6.8: .or"),
  mk_lang("L04", "`r means`{.pairs}", "1.6.8: .pairs"),
  mk_lang("L05", "`r c(1, 2)`{.range}", "1.6.8: .range"),
  mk_lang("L06", "`r many`{.num trunc=\"2\"}", "1.6.8: trunc"),
  mk_lang("L07", "`r of_n(1, 2, 'a', 'b')`{.strong}", "1.6.8: of_n() in a value with an attribute block"),
  mk_lang("L08", "`r about(0.5)`{.strong}", "1.6.8: about() in a value with an attribute block"),
  mk_lang("L09", "`r ci(1, 0, 2)`{.strong}", "1.6.8: ci() in a value with an attribute block"),
  # controls: names that print no words
  b_row("N01", "`r x`{.num} y", "control: .num prints no words", want = "N01 1.2 y", collected = FALSE),
  b_row("N02", "[abc]{.strong} y", "control: .strong prints no words", want = "N02 **abc** y", collected = FALSE),
  b_row("N03", "`r 0.12`{.pct} y", "control: .pct prints no words", want = "N03 12% y", collected = FALSE),
  b_row("N04", "[abc]{.cap} y", "control: .cap prints no words", want = "N04 Abc y", collected = FALSE),
  b_row("N05", "`r pm(2.1, 0.3)`{.strong} y", "control: pm() prints a sign, no word",
        want = "N05 **2.1 ± 0.3** y", collected = FALSE),
  b_row("N06", "`r 0.03`{.p} y", "control: .p prints no word the rule lists", want = "N06 p = 0.030 y", collected = FALSE)
)
LANG_ERRORS <- Filter(function(r) isTRUE(r$collected), LANG_ROWS)

test_that("1.6.8 + 5.3.1: under lang: de the word-printing names are construct errors, the others are not (draft markers)", {
  b <- b_body(LANG_ROWS)
  res <- render_rmd(b$lines, code = PRE_B, front = "lang: de", env = c(WEFT_DRAFT = "1"),
                    format = "knit", in_process = TRUE)
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  b_check_lines(res, b, LANG_ROWS, "rmarkdown")
  expect_equal(sum(grepl("<<weft:", unesc(res$text), fixed = TRUE)), length(LANG_ERRORS))
})

test_that("1.6.8: under lang: en-AU the same names are fine (English is matched on its primary subtag)", {
  res <- render_rmd(c("A `r sites`{.and} and `r k`{.a} and `r about(0.5)`{.cap}."), code = PRE_B,
                    front = "lang: en-AU", format = "knit")
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_match(res$md, "A A, B and C and a 3 and Half.", fixed = TRUE)
})
