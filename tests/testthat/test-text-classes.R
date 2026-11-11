# Stage 1b: the text classes .cap and .a (1.4.1 stage iv, 1.4.5, 5.3.2) and the
# sentence-start report (5.10.1). Markup rows: helper-1b.R, batch B, groups
# "cap" and "a"; the configuration document of helper-1b.R for the report.

sc <- function(x, ...) weft:::scan_text(x, ...)

# ---- .cap ------------------------------------------------------------------------

test_that("1.4.3 + design: fmt_cap() capitalises the first letter", {
  x <- fmt_cap("abc def")
  expect_s3_class(x, "weft_text")
  expect_equal(b_txt(x), "Abc def")
  expect_equal(b_txt(fmt_cap("Abc")), "Abc")
  expect_equal(b_txt(fmt_cap("élan")), "Élan")
  expect_equal(b_txt(fmt_cap("")), "")
})

test_that("design: fmt_cap() skips leading markdown emphasis marks", {
  expect_equal(b_txt(fmt_cap("*abc* def")), "*Abc* def")
  expect_equal(b_txt(fmt_cap("**abc** def")), "**Abc** def")
  expect_equal(b_txt(fmt_cap(fmt_strong("abc"))), "**Abc**")
  expect_equal(b_txt(fmt_strong(fmt_cap("abc"))), "**Abc**")
  expect_equal(b_txt(fmt_cap(fmt_em("abc"))), "*Abc*")
})

test_that("1.4.1: fmt_cap() passes the printed record through", {
  x <- fmt_cap(fmt_word(12))
  expect_equal(b_txt(x), "Twelve")
  expect_equal(attr(x, "number"), 12)
  expect_equal(attr(x, "relation"), "=")
  y <- fmt_cap(fmt_no(0))
  expect_equal(attr(y, "number"), 0)
})

test_that("1.3.4: a missing value reaching .cap is a weft_no_value error", {
  expect_error(fmt_cap(NA_character_), class = "weft_no_value")
  expect_error(fmt_cap(character(0)), class = "weft_no_value")
})

# ---- .a ------------------------------------------------------------------------

test_that("design: fmt_a() puts 'an' before a number that opens with a vowel sound (digits)", {
  an <- c(8, 11, 18, 80, 85, 89, 800, 899, 8000, 11000, 18000)
  for (v in an) {
    got <- b_txt(fmt_a(fmt_num(v)))
    expect_match(got, "^an ", label = paste("fmt_a(fmt_num(", v, "))"))
  }
  a <- c(0, 1, 2, 3, 7, 12, 70, 100, 111, 1000, 12000)
  for (v in a) {
    got <- b_txt(fmt_a(fmt_num(v)))
    expect_match(got, "^a ", label = paste("fmt_a(fmt_num(", v, "))"))
  }
  expect_equal(b_txt(fmt_a(fmt_num(8))), "an 8")
  expect_equal(b_txt(fmt_a(fmt_num(12))), "a 12")
  expect_equal(b_txt(fmt_a(fmt_num(11000))), "an 11,000")
  expect_equal(b_txt(fmt_a(fmt_num(18000))), "an 18,000")
  expect_equal(b_txt(fmt_a(fmt_num(1))), "a 1")
})

test_that("design: fmt_a() by the sound of the number word", {
  expect_equal(b_txt(fmt_a(fmt_word(8))), "an eight")
  expect_equal(b_txt(fmt_a(fmt_word(11))), "an eleven")
  expect_equal(b_txt(fmt_a(fmt_word(18))), "an eighteen")
  expect_equal(b_txt(fmt_a(fmt_word(80))), "an eighty")
  expect_equal(b_txt(fmt_a(fmt_word(1))), "a one")
  expect_equal(b_txt(fmt_a(fmt_word(12))), "a twelve")
})

test_that("design: fmt_a() after a decimal, a percentage and an ordinal", {
  expect_equal(b_txt(fmt_a(fmt_num(8.5))), "an 8.5")
  expect_equal(b_txt(fmt_a(fmt_num(1.5))), "a 1.5")
  expect_equal(b_txt(fmt_a(fmt_pct(0.08))), "an 8%")
  expect_equal(b_txt(fmt_a(fmt_pct(0.12))), "a 12%")
  expect_equal(b_txt(fmt_a(fmt_ord(8))), "an 8th")
  expect_equal(b_txt(fmt_a(fmt_ord(3))), "a 3rd")
})

test_that("1.4.3: fmt_a() on text that opens with a number, the spec's example", {
  expect_equal(b_txt(fmt_a("11-year")), "an 11-year")
  expect_equal(b_txt(fmt_a("12-year")), "a 12-year")
  expect_equal(b_txt(fmt_a("eleven-year")), "an eleven-year")
  expect_equal(b_txt(fmt_a("twelve-year")), "a twelve-year")
  expect_equal(b_txt(fmt_a("eight-week")), "an eight-week")
})

test_that("1.4.1: .a then .cap then .strong; the article is lower case until .cap", {
  expect_equal(b_txt(fmt_cap(fmt_a(fmt_num(8)))), "An 8")
  expect_equal(b_txt(fmt_cap(fmt_a(fmt_word(11)))), "An eleven")
  expect_equal(b_txt(fmt_strong(fmt_a(fmt_num(8)))), "**an 8**")
  expect_equal(b_txt(fmt_strong(fmt_cap(fmt_a(fmt_num(8))))), "**An 8**")
})

test_that("1.4.11: fmt_a() passes the printed record through", {
  x <- fmt_a(fmt_num(8))
  expect_s3_class(x, "weft_text")
  expect_equal(attr(x, "number"), 8)
  expect_equal(attr(x, "relation"), "=")
})

test_that("1.4.5 + 5.3.2: .a on text that is not a number or a number word is a value error", {
  expect_error(fmt_a("apple"), class = "weft_value_error")
  expect_error(fmt_a("year"), class = "weft_value_error")
  expect_error(fmt_a("a 12-year"), class = "weft_value_error")
})

test_that("1.3.4: a missing value reaching .a is a weft_no_value error", {
  expect_error(fmt_a(NA_character_), class = "weft_no_value")
  expect_error(fmt_a(character(0)), class = "weft_no_value")
})

# ---- the scanner -----------------------------------------------------------------

test_that("1.1.5 + 1.1.9: [..]{.cap} and [..]{.a} are text spans; .a .cap .strong together are legal", {
  for (cls in c(".cap", ".a", ".a .cap", ".a .cap .strong", ".cap .em")) {
    r <- sc(sprintf("See [11-year]{%s} here.", cls))
    expect_equal(r$kind, "text", label = cls)
    expect_identical(r$error, NA_character_, label = cls)
  }
})

test_that("1.4.1: .a and .cap are text classes on a value too, in any order", {
  r <- sc("`r k`{.word .a .cap} and `r k`{.cap .a .word}")
  expect_identical(r$error, c(NA_character_, NA_character_))
})

test_that("1.1.9: an #id on a .cap or .a span is a construct error", {
  b_expect_scan_error("[a]{#zt .cap}", "[a]{.cap}")
  b_expect_scan_error("[11-year]{#zt .a}")
})

# ---- rendered, both engines -------------------------------------------------------

test_that("1.4.1 + 1.4.5: .cap and .a render as the rules say (rmarkdown)", {
  b_expect_rows("B", c("cap", "a"), "rmd")
})

test_that("1.4.1 + 1.4.5: .cap and .a render the same under Quarto", {
  b_expect_rows("B", c("cap", "a"), "qmd")
})

# ---- the sentence-start report -----------------------------------------------------

sent_lines <- function(res) {
  n_cfg <- length(CFG_ROWS)
  res$offset + res$b$at[n_cfg + seq_along(SENT_ROWS)]
}

test_that("5.10.1: the default knit does not fail on a sentence start; the document renders", {
  res <- b_cfg()
  expect_false(res$failed, label = substr(res$message, 1, 300))
})

test_that("5.10.1: last_knit()$sentence_starts is a data frame of file, line, expr, text", {
  res <- b_cfg()
  b_need(res)
  ss <- res$knit$sentence_starts
  expect_s3_class(ss, "data.frame")
  expect_true(all(c("file", "line", "expr", "text") %in% names(ss)))
  expect_true(all(grepl("doc\\.Rmd$", ss$file)))
})

test_that("5.10.1: exactly the values and spans that open a sentence with a digit or a lower-case letter are listed", {
  res <- b_cfg()
  b_need(res)
  ss <- res$knit$sentence_starts
  lines <- sent_lines(res)
  listed <- vapply(SENT_ROWS, function(r) r$listed, NA)
  expect_setequal(ss$line, lines[listed])
  expect_equal(nrow(ss), sum(listed))
  for (i in which(listed)) {
    got <- ss[ss$line == lines[i], ]
    expect_equal(nrow(got), 1L, label = SENT_ROWS[[i]]$rule)
    expect_equal(got$text, SENT_ROWS[[i]]$text, label = SENT_ROWS[[i]]$rule)
    if (!is.null(SENT_ROWS[[i]]$expr)) {
      expect_equal(got$expr, SENT_ROWS[[i]]$expr, label = SENT_ROWS[[i]]$rule)
    }
  }
  for (i in which(!listed)) {
    expect_false(lines[i] %in% ss$line, label = SENT_ROWS[[i]]$rule)
  }
})

test_that("5.10.1: with sentence_start_fail unset a sentence start is not a failure", {
  res <- b_cfg()
  b_need(res)
  expect_false("sentence start" %in% res$knit$failures$kind)
  expect_equal(nrow(res$knit$failures), 0L)
})

test_that("5.10.1 + design: sentence_start_fail: true makes each sentence start a collected failure", {
  src <- c(
    "`r k`{.num} sites failed.",
    "",
    "There were `r k`{.num} sites.",
    "",
    "Done. `r k`{.word} sites failed."
  )
  res <- render_rmd(src, code = PRE_B, in_process = TRUE,
                    files = list("_weft.yml" = "sentence_start_fail: true"))
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  f <- res$knit$failures
  expect_equal(nrow(f), 2L)
  expect_setequal(f$kind, "sentence start")
  expect_setequal(f$line, res$offset + c(1L, 5L))
  expect_match(res$message, at_line(res, 1))
  expect_match(res$message, at_line(res, 5))
  expect_false(grepl(at_line(res, 3), res$message))
  # the list is still kept
  expect_equal(nrow(res$knit$sentence_starts), 2L)
})

test_that("5.10.1: the sentence-start failure is not raised in draft mode (the render goes on)", {
  res <- render_rmd(c("`r k`{.num} sites failed."), code = PRE_B, in_process = TRUE,
                    files = list("_weft.yml" = c("sentence_start_fail: true", "draft: true")))
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_equal(nrow(res$knit$failures), 1L)
  expect_equal(res$knit$failures$kind, "sentence start")
})
