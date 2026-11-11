# Package B: collected failures, markers, the report, claim() in chunk code,
# draft mode, the end-of-document check and last_knit()$failures.
#
# Where a render fails, knitr writes no output, so the markers (2.6.8) can be
# looked at only in draft mode, where nothing fails (9.4.2). The report is
# looked at in the error message of a failing render.

PRE_F <- c(
  "k <- 3; z <- 0; flag <- TRUE; noflag <- FALSE; shift_n <- 7",
  "sites <- c('A', 'B', 'C')"
)

# A body is built from rows; each row is one paragraph. file_lines() gives the
# line of each row's first line in the body (the helper's offset is added by
# the caller).
body_of <- function(rows) {
  lines <- character(); at <- integer(length(rows))
  for (i in seq_along(rows)) {
    at[i] <- length(lines) + 1L
    lines <- c(lines, strsplit(rows[[i]], "\n", fixed = TRUE)[[1]], "")
  }
  list(lines = lines, at = at)
}

row <- function(src, want, rule, collected = TRUE) {
  list(src = src, want = want, rule = rule, collected = collected)
}

# Each row: the failing paragraph and the exact output line (after the marker
# of 2.6.8). "@L@" stands for the file line of the paragraph.
MARKER_ROWS <- list(
  row("Q01 `r claim(k, . > 100)` after.", "Q01 3<<weft: failed claim, line @L@>> after.", "2.6.8: a failed check, marker directly after the printed text"),
  row("Q02 `r claim(k, . > 100)`{.word} after.", "Q02 three<<weft: failed claim, line @L@>> after.", "2.6.8: the printed text is the formatted value"),
  row("Q03 [All]{if=\"noflag\"} models.", "Q03 All<<weft: failed claim, line @L@>> models.", "1.5.5 + 2.6.8: a failed guard, marker after its phrase"),
  row("Q05 Mean `r NA_real_`{.num} m.", "Q05 Mean <<weft: no value, line @L@>> m.", "1.3.4: NA under .num, marker in place, no fallback text"),
  row("Q06 `r NaN`{.num} x", "Q06 <<weft: no value, line @L@>> x", "1.3.4: NaN"),
  row("Q07 `r Inf`{.num} x", "Q07 <<weft: no value, line @L@>> x", "1.3.4: Inf"),
  row("Q08 `r -Inf`{.pct} x", "Q08 <<weft: no value, line @L@>> x", "1.3.4: -Inf under .pct"),
  row("Q09 `r numeric(0)`{.word} x", "Q09 <<weft: no value, line @L@>> x", "1.3.4: a value of length zero under .word"),
  row("Q10 `r NA_real_`{.sci} x", "Q10 <<weft: no value, line @L@>> x", "1.3.4: NA under .sci"),
  row("Q11 `r NA_real_`{.ord} x", "Q11 <<weft: no value, line @L@>> x", "1.3.4: NA under .ord"),
  row("Q12 `r NA_real_`{.count} x", "Q12 <<weft: no value, line @L@>> x", "1.3.4: NA under .count"),
  row("Q13 `r NA_real_`{.no} x", "Q13 <<weft: no value, line @L@>> x", "1.3.4: NA under .no"),
  row("Q14 `r c(1, NA)`{.num .and} x", "Q14 <<weft: no value, line @L@>> x", "1.3.4: one NA element reaching a formatter"),
  row("Q15 [a | b]{n=\"NA_real_\"} x", "Q15 <<weft: no value, line @L@>> x", "1.5.11 + 1.3.4: NA in an n governor"),
  row("Q16 [a | b]{n=\"numeric(0)\"} x", "Q16 <<weft: no value, line @L@>> x", "1.3.4: a length-zero n governor"),
  row("Q17 `r undefined_thing`{.num} x", "Q17 <<weft: no value, line @L@>> x", "2.6.4 + 2.6.8: an unknown object"),
  row("Q18 `r stop('bad')`{.num} x", "Q18 <<weft: no value, line @L@>> x", "2.6.4 + 2.6.8: a call that raises an error"),
  row("Q19 [a | b]{if=\"undefined_cond\"} x", "Q19 <<weft: no value, line @L@>> x", "2.6.4: an if governor that cannot be evaluated"),
  row("Q20 `r 1.5`{.word} x", "Q20 <<weft: value error, line @L@>> x", "1.4.12 + 5.3.2 + 2.6.8: .word of a decimal"),
  row("Q21 `r -2`{.count} x", "Q21 <<weft: value error, line @L@>> x", "1.4.12: .count of a negative"),
  row("Q22 `r 2.5`{.ord} x", "Q22 <<weft: value error, line @L@>> x", "1.4.12: .ord of a decimal"),
  row("Q23 [a | b]{n=\"sites\"} x", "Q23 <<weft: value error, line @L@>> x", "1.5.11: n is a vector"),
  row("Q24 [a | b]{n=\"'a'\"} x", "Q24 <<weft: value error, line @L@>> x", "1.5.11: n is a string"),
  row("Q25 `r NA_real_` x", "Q25 NA x", "1.3.4: a bare NA prints as stock, no marker, no failure", collected = FALSE)
)
N_COLLECTED <- sum(vapply(MARKER_ROWS, function(r) r$collected, NA))

marker_doc <- function(extra = NULL) {
  rows <- c(lapply(MARKER_ROWS, function(r) r$src), extra)
  b <- body_of(rows)
  b$truth <- c(vapply(MARKER_ROWS, function(r) r$want, ""), rep(NA_character_, length(extra)))
  b
}

check_marker_lines <- function(res, b, engine, extra_rows = NULL) {
  txt <- unesc(res$text)
  all_rows <- c(MARKER_ROWS, extra_rows)
  for (i in seq_along(all_rows)) {
    line <- res$offset + b$at[i]
    want <- sub("@L@", as.character(line), all_rows[[i]]$want, fixed = TRUE)
    tag <- substr(all_rows[[i]]$src, 1, 3)
    got <- grep(paste0("^", tag, " "), txt, value = TRUE)
    expect_equal(got, want, label = paste(engine, all_rows[[i]]$rule))
  }
}

# ---- markers (draft mode) -----------------------------------------------------

test_that("2.6.8 + 9.4.2 + 9.4.1: markers have the exact text and place, WEFT_DRAFT=1 (rmarkdown)", {
  b <- marker_doc(list("Q26 [a | b | c]{if=\"flag\"} x"))
  res <- render_rmd(b$lines, code = PRE_F, env = c(WEFT_DRAFT = "1"), format = "knit")
  expect_false(res$failed, label = res$message)
  check_marker_lines(res, b, "rmarkdown",
                     list(row("Q26 [a | b | c]{if=\"flag\"} x", "Q26 <<weft: construct error, line @L@>> x", "2.6.8: a construct error in draft mode")))
  # 9.4.2: the failures are listed in the knit log
  expect_true(any(grepl("weft: [0-9]+ claims? failed", res$log)), label = "report in the knit log")
  # 2.6.8: every marker can be found by searching for <<weft:
  expect_equal(sum(grepl("<<weft:", res$text, fixed = TRUE)), N_COLLECTED + 1L)
})

test_that("2.6.8 + 9.4.3: the same markers under Quarto, nothing fails (draft)", {
  skip_if_no_quarto()
  b <- marker_doc()
  res <- render_qmd(b$lines, code = PRE_F, env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  check_marker_lines(res, b, "quarto")
})

test_that("9.4.1: draft: true in the document's front matter (no _weft.yml) is draft mode", {
  res <- render_rmd(c("Intro.", "", "Value `r claim(k, . > 100)` here."), code = PRE_F,
                    front = c("weft:", "  draft: true"), format = "knit")
  expect_false(res$failed, label = res$message)
  expect_match(res$md, sprintf("Value 3<<weft: failed claim, line %d>> here.", res$offset + 3L), fixed = TRUE)
})

test_that("9.4.1 + 9.1.4: draft: true in _weft.yml is draft mode", {
  res <- render_rmd(c("Intro.", "", "Value `r claim(k, . > 100)` here."), code = PRE_F,
                    files = list("_weft.yml" = "draft: true"), format = "knit")
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "<<weft: failed claim, line", fixed = TRUE)
})

test_that("9.4.1: without draft mode the same document fails", {
  res <- render_rmd(c("Intro.", "", "Value `r claim(k, . > 100)` here."), code = PRE_F)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
})

test_that("9.1.4: draft in a front matter, where _weft.yml exists, is an error", {
  res <- render_rmd("Text.", code = PRE_F, files = list("_weft.yml" = "digits: 1"),
                    front = c("weft:", "  draft: true"))
  expect_true(res$failed)
  expect_match(res$message, "draft", ignore.case = TRUE)
})

# ---- the report and last_knit()$failures ---------------------------------------

test_that("2.6.1 + 2.6.2 + 2.6.3 + 2.4.1: a failed check does not stop the knit; one report lists every failure", {
  src <- c(
    "Intro.",
    "",
    "The shift was `r claim(shift_n, . >= 10)` sites.",
    "",
    "[All 10 models rise]{if=\"noflag\"} in the study.",
    "",
    "Last line `r k`{.word}."
  )
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  msg <- res$message
  expect_match(msg, "weft: 2 claims failed", fixed = TRUE)
  expect_match(msg, at_line(res, 3))
  expect_match(msg, at_line(res, 5))
  expect_match(msg, ". >= 10 was FALSE", fixed = TRUE)
  expect_match(msg, "(value 7)", fixed = TRUE)
  expect_match(msg, "noflag was FALSE", fixed = TRUE)
  expect_match(msg, "All 10 models rise", fixed = TRUE)          # 2.6.3 reported by its phrase
  expect_match(msg, "optional text is written", fixed = TRUE)     # 2.6.3 the hint
  expect_match(msg, "[phrase | ]{if=", fixed = TRUE)
  # 2.6.1 the knit carried on: the construct after both failures was evaluated
  k <- res$knit
  expect_equal(nrow(k$failures), 2L)
  expect_setequal(k$failures$kind, "failed claim")
  expect_setequal(k$failures$line, res$offset + c(3L, 5L))
  expect_true(all(grepl("doc\\.Rmd$", k$failures$file)))
  last <- k$constructs[k$constructs$line == res$offset + 7L & k$constructs$kind == "value", ]
  expect_equal(nrow(last), 1L)
  expect_true(last$evaluated)
})

test_that("3.1.3 + 1.5.5: each check, and each failing guard condition, is reported separately", {
  src <- c(
    "A `r claim(k, . > 100, . < 0)` b.",
    "",
    "[All]{if=\"noflag, k > 100\"} sites."
  )
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_equal(nrow(res$knit$failures), 4L)
  expect_match(res$message, ". > 100 was FALSE", fixed = TRUE)
  expect_match(res$message, ". < 0 was FALSE", fixed = TRUE)
  expect_match(res$message, "noflag was FALSE", fixed = TRUE)
  expect_match(res$message, "k > 100 was FALSE", fixed = TRUE)
})

test_that("2.6.9 + 21 Collected failures: every kind is collected, the render runs to the end and reports each", {
  b <- body_of(lapply(MARKER_ROWS[c(1, 3, 4, 17, 18, 19, 22)], function(r) r$src))
  src <- c(b$lines, "Final `r k`{.word} line.")
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  f <- res$knit$failures
  expect_equal(nrow(f), 7L)
  expect_setequal(f$line, res$offset + b$at)
  expect_true(all(c("failed claim", "no value", "value error") %in% f$kind))
  for (l in res$offset + b$at) expect_match(res$message, sprintf("doc\\.Rmd:%d\\b", l))
  # 2.6.7: kinds are told apart, each under its own heading line
  expect_gte(sum(grepl("^weft: [0-9]+ ", strsplit(res$message, "\n")[[1]])), 2L)
  expect_match(res$message, "weft: [0-9]+ claims? failed")
  expect_match(res$message, "weft: [0-9]+ failures?")
  # the construct after the failures was evaluated
  fin <- res$knit$constructs[res$knit$constructs$line == res$offset + length(b$lines) + 1L, ]
  expect_true(all(fin$evaluated))
  # 1.5.11: the message to an author says to write length(x)
  expect_true(any(grepl("length(", f$detail, fixed = TRUE)) || grepl("length(", res$message, fixed = TRUE))
})

test_that("21 Collected failures + 2.6.2: all 23 failing rows are collected, each located by its own line", {
  b <- marker_doc()
  res <- render_rmd(b$lines, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_equal(nrow(f), N_COLLECTED)
  want_lines <- res$offset + b$at[vapply(MARKER_ROWS, function(r) r$collected, NA)]
  expect_setequal(f$line, want_lines)
  expect_false(any(f$line == res$offset + b$at[length(MARKER_ROWS)]), label = "a bare NA is not a failure")
})

test_that("2.6.4: an expression that cannot be evaluated is reported naming the expression and its line", {
  res <- render_rmd(c("Intro.", "", "Mean `r undefined_thing`{.num} here."), code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_match(res$message, at_line(res, 3))
  expect_match(res$message, "undefined_thing", fixed = TRUE)
  expect_true("weft_failures" %in% res$error$class)
})

test_that("2.6.5: a construct error stops at once, with class weft_construct_error, even after a collected failure", {
  res <- render_rmd(c("A `r claim(k, . > 100)` b.", "", "See [a | b | c]{if=\"flag\"} here.", "", "End."),
                    code = PRE_F)
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, at_line(res, 3))
})

test_that("2.6.7: an ordinary knit error is not reported as a weft failure", {
  res <- render_rmd(c("```{r}", "stop('ordinary trouble')", "```", "", "Text `r k`{.word}."), code = PRE_F)
  expect_true(res$failed)
  expect_match(res$message, "ordinary trouble", fixed = TRUE)
  expect_false("weft_failures" %in% res$error$class)
  expect_false(grepl("claims? failed", res$message))
})

test_that("2.6.2 under Quarto: the render fails once with the report, naming file:line", {
  skip_if_no_quarto()
  src <- c("Intro.", "", "The shift was `r claim(shift_n, . >= 10)` sites.", "",
           "[All 10 models rise]{if=\"noflag\"} in the study.")
  res <- render_qmd(src, code = PRE_F)
  expect_true(res$failed)
  expect_match(res$message, "weft: 2 claims failed", fixed = TRUE)
  expect_match(res$message, at_line(res, 3))
  expect_match(res$message, at_line(res, 5))
  expect_match(res$message, "was FALSE", fixed = TRUE)
  expect_match(res$message, "optional text is written", fixed = TRUE)
})

# ---- claim() in chunk code (2.4.2, 2.4.4, 2.4.5) -------------------------------

test_that("2.4.2: a failed check in chunk code stops the chunk and the knit", {
  src <- c("```{r bad-chunk}", "claim(k, . > 100)", "```", "", "Text `r k`{.word}.")
  res <- render_rmd(src, code = PRE_F)
  expect_true(res$failed)
  expect_match(res$message, ". > 100", fixed = TRUE)
})

test_that("2.4.4: with error: true the knit carries on, the render still fails with the check in the report", {
  src <- c("```{r bad-chunk, error=TRUE}", "claim(k, . > 100)", "```", "", "After `r k`{.word}.")
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, ". > 100", fixed = TRUE)
  expect_match(res$message, "bad-chunk", fixed = TRUE)          # 2.6.2: located by its chunk label
  last <- res$knit$constructs[res$knit$constructs$kind == "value", ]
  expect_true(all(last$evaluated), label = "the prose after the chunk was evaluated")
  expect_true("bad-chunk" %in% res$knit$failures$chunk)
})

test_that("2.4.4: a failed check caught by try() is recorded; the render fails", {
  src <- c("```{r try-chunk}", "r <- try(claim(k, . > 100), silent = TRUE)", "```", "", "After `r k`{.word}.")
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, ". > 100", fixed = TRUE)
  expect_match(res$message, "try-chunk", fixed = TRUE)
})

test_that("2.4.4: a failed check caught by tryCatch() is recorded; the render fails", {
  src <- c("```{r catch-chunk}", "r <- tryCatch(claim(k, . > 100), error = function(e) 'caught')", "```", "", "After `r k`{.word}.")
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, "catch-chunk", fixed = TRUE)
})

test_that("2.4.4: a passing check in chunk code fails nothing", {
  src <- c("```{r ok-chunk}", "y <- claim(k, . > 0)", "```", "", "After `r k`{.word}.")
  res <- render_rmd(src, code = PRE_F)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), "After three.")
})

test_that("2.4.5: a failed check that stops the knit prints every failure collected before it", {
  src <- c("Early `r claim(k, . > 100)` failure.", "", "```{r stop-chunk}", "claim(z, . > 5)", "```", "", "End.")
  res <- render_rmd(src, code = PRE_F)
  expect_true(res$failed)
  expect_match(res$message, ". > 5", fixed = TRUE)                # its own error
  expect_match(res$message, at_line(res, 1))                      # the failure collected before it
  expect_match(res$message, ". > 100", fixed = TRUE)
})

test_that("2.4.2 + 2.5.1: with the hooks never installed, a failed claim in inline R stops the knit", {
  src <- c("---", "title: t", "---", "", "```{r setup, include=FALSE}", "library(weft)", "k <- 3", "```", "",
           "Value `r claim(k, . > 100)`{.num}.")
  res <- render_rmd(src, setup = FALSE)
  expect_true(res$failed)
  expect_true("weft_claim_failed" %in% res$error$class)
  expect_match(res$message, ". > 100", fixed = TRUE)
})

test_that("2.5.1: with the hooks never installed and claim() not found, the knit stops", {
  src <- c("---", "title: t", "---", "", "```{r setup, include=FALSE}", "k <- 3", "```", "",
           "Value `r claim(k, . > 1)`{.num}.")
  res <- render_rmd(src, setup = FALSE)
  expect_true(res$failed)
  expect_match(res$message, "claim", fixed = TRUE)
})

# ---- the end-of-document check (2.5.2, 9.2.5) ---------------------------------

test_that("2.5.2 + 9.2.5: a construct above the setup chunk is never evaluated; the render fails naming its line", {
  src <- c("---", "title: t", "---", "", "Above [a | b]{if=\"flag\"} the setup.", "",
           "```{r setup, include=FALSE}", "weft::weft_setup()", "flag <- TRUE", "```", "",
           "Below [a | b]{if=\"flag\"}.")
  res <- render_rmd(src, setup = FALSE, in_process = TRUE)
  expect_true(res$failed)
  expect_match(res$message, "doc\\.Rmd:5\\b")
  expect_false(grepl("doc\\.Rmd:12\\b", res$message), label = "the evaluated construct below is not named")
  f <- res$knit$failures
  expect_true("unevaluated" %in% f$kind)
  expect_equal(f$line[f$kind == "unevaluated"], 5L)
})

test_that("2.5.2: constructs in an arm that is not chosen need no evaluation", {
  src <- "[A | B `r k`{.num} and [c]{.strong}]{if=\"flag\"}"
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), "A")
  expect_equal(nrow(res$knit$failures), 0L)
})

# ---- last_knit() -------------------------------------------------------------

test_that("design: last_knit() records, evaluated and chosen, parent and arm", {
  src <- c(
    "[A `r k`{.num} | B `r z`{.num}]{if=\"flag\"}",
    "",
    "[# site | # sites]{n=\"k\"}",
    "",
    "[# site | # sites]{n=\"1\"}",
    "",
    "[met | not met]{if=\"noflag\"}"
  )
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  cs <- res$knit$constructs
  expect_true(all(c("evaluated", "chosen", "kind", "line", "parent", "arm") %in% names(cs)))
  at <- function(l, kind) cs[cs$line == res$offset + l & cs$kind == kind, , drop = FALSE]
  expect_equal(at(1, "if")$chosen, 1L)
  expect_equal(at(3, "n")$chosen, 2L)
  expect_equal(at(5, "n")$chosen, 1L)
  expect_equal(at(7, "if")$chosen, 2L)
  inner <- cs[cs$line == res$offset + 1L & cs$kind == "value", ]
  expect_equal(nrow(inner), 2L)
  expect_equal(inner$evaluated[order(inner$arm)], c(TRUE, FALSE))
  expect_equal(nrow(res$knit$failures), 0L)
  expect_true(is.list(res$knit$config))
})

test_that("2.1.5: the records are emptied for each top-level knit", {
  skip_if_not(rmarkdown::pandoc_available())
  bad <- write_doc(c("A `r claim(k, . > 100)` b."), TRUE, PRE_F, NULL, NULL, "bad", "rmd")
  good <- write_doc(c("A `r k`{.word} b."), TRUE, PRE_F, NULL, NULL, "good", "rmd")
  withr::defer(weft_restore_knitr())
  r1 <- run_rmd_file(bad$input, file.path(bad$dir, "bad.md"), "md", TRUE, character(), restore = FALSE)
  expect_true(r1$failed)
  expect_equal(nrow(r1$knit$failures), 1L)
  r2 <- run_rmd_file(good$input, file.path(good$dir, "good.md"), "md", TRUE, character(), restore = FALSE)
  expect_false(r2$failed, label = r2$error$message)
  expect_equal(nrow(r2$knit$failures), 0L)
})

test_that("2.1.3 + 2.1.5: calling weft_setup() again mid-knit changes none of the knit's state", {
  src <- c("A `r claim(k, . > 100)` b.", "", "```{r again}", "weft::weft_setup()", "```", "", "C `r k`{.word} d.")
  res <- render_rmd(src, code = PRE_F, in_process = TRUE)
  expect_true(res$failed)                     # the failure above the call is still there
  expect_match(res$message, at_line(res, 1))
  expect_equal(nrow(res$knit$failures), 1L)
  last <- res$knit$constructs[res$knit$constructs$line == res$offset + 7L & res$knit$constructs$kind == "value", ]
  expect_true(last$evaluated)
})

test_that("2.1.3: installing is idempotent", {
  src <- c("Value `r k`{.word} and [a | b]{if=\"flag\"}.")
  once <- render_rmd(src, code = c(PRE_F), format = "knit")
  twice_code <- c("weft::weft_setup()", PRE_F)
  twice <- render_rmd(src, code = twice_code, format = "knit")
  expect_false(once$failed)
  expect_equal(twice$text, once$text)
  expect_equal(once$text[length(once$text)], "Value three and a.")
})
