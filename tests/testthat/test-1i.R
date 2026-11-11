# Stage 1i: a number that prints as zero prints to the default digits and
# records a warned check of kind "printed as zero". Replaces the stage 1g
# fallback (first non-zero decimal). Contract: dev/design-1i.md.
#
# One document holds the cases of the knit tests; each case is on its own
# line, found again by its marker letter.

# the warnings raised by an expression, and its value
i_catch <- function(expr) {
  ws <- list()
  val <- withCallingHandlers(
    expr,
    warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") }
  )
  list(value = val, warnings = ws,
       text = paste(vapply(ws, conditionMessage, ""), collapse = "\n"))
}

I1_LINES <- c(
  "A `r 0.04`{.num} here.",                                                  #  1
  "",
  "B `r 0.0004`{.pct} here.",                                                #  3
  "",
  "C `r c(0.04, 0.03, 5)`{.num .and} here.",                                 #  5
  "",
  "D `r 0.04`{#zid .num} here.",                                             #  7  an id and a class
  "",
  "E `r 0.04`{.num digits=\"1\"} `r 0.04`{.num sigfig=\"1\"} `r 0.0004`{.pct digits=\"1\"} `r 0.0004`{.pct sigfig=\"1\"} here.",  # 9
  "",
  "F `r 0.1 + 0.2 - 0.3`{.num} `r 1e-12`{.pct} `r -1e-12`{.num} here.",      # 11
  "",
  "G `r 0`{.num} `r 0`{.pct} `r 0.06`{.num} `r 3.14`{.num} here.",           # 13 controls
  "",
  "H [up # | down # | flat]{sign=\"0.02\"} and [up # | down # | flat]{sign=\"-0.02\"} here.",  # 15 governors
  "",
  "I `r -0.04`{.num} here."                                                  # 17
)
I1_WARNED <- c(1L, 3L, 5L, 7L, 17L)      # the lines that must record one warned check each

i_knit <- function(lines = I1_LINES, draft = FALSE, files = NULL, front = NULL, ...) {
  render_rmd(lines, code = "k <- 3", in_process = TRUE, files = files, front = front,
             env = if (draft) c(WEFT_DRAFT = "1") else NULL, ...)
}

# the text of the warned row at a line of the document, one string
i_row <- function(res, line) {
  w <- res$knit$warnings
  r <- w[w$line == res$offset + line, , drop = FALSE]
  if (!NROW(r)) return(character())
  paste(unlist(r), collapse = " ")
}

# ---- printing -----------------------------------------------------------------

test_that("1i zero: fmt_num and fmt_pct print a number that would print as zero to the default digits", {
  suppressWarnings({
    expect_equal(b_txt(fmt_num(0.04)), "0.0")
    expect_equal(b_txt(fmt_num(0.0449)), "0.0")
    expect_equal(b_txt(fmt_num(1e-6)), "0.0")
    expect_equal(b_txt(fmt_pct(0.0004)), "0.0%")
    expect_equal(b_txt(fmt_num(c(3, 0.04))), c("3", "0.0"))
  })
})

test_that("1i zero: a negative number that prints as zero has no minus sign", {
  suppressWarnings({
    expect_equal(b_txt(fmt_num(-0.04)), "0.0")
    expect_equal(b_txt(fmt_pct(-0.0004)), "0.0%")
    expect_false(grepl(B_MINUS, b_txt(fmt_num(-0.04)), fixed = TRUE))
    expect_false(grepl("-", b_txt(fmt_num(-0.04)), fixed = TRUE))
  })
})

test_that("1i zero: digits or sigfig given print as asked (no first-non-zero fallback)", {
  expect_equal(b_txt(fmt_num(0.04, digits = 1)), "0.0")
  expect_equal(b_txt(fmt_num(0.04, digits = 2)), "0.04")
  expect_equal(b_txt(fmt_num(0.04, sigfig = 1)), "0.04")
  expect_equal(b_txt(fmt_pct(0.0004, sigfig = 1)), "0.04%")
})

# ---- the warning, outside a knit -------------------------------------------------

test_that("1i zero: outside a knit fmt_num(0.04) returns 0.0 and signals a weft_zero_warning that names the value, what printed, sigfig and digits", {
  r <- i_catch(fmt_num(0.04))
  expect_equal(b_txt(r$value), "0.0")
  expect_length(r$warnings, 1L)
  expect_true(any(vapply(r$warnings, inherits, NA, "weft_zero_warning")))
  expect_match(r$text, "0.04", fixed = TRUE)
  expect_match(r$text, "printed as 0.0", fixed = TRUE)
  expect_match(r$text, "sigfig", fixed = TRUE)
  expect_match(r$text, "digits", fixed = TRUE)
})

test_that("1i zero: outside a knit fmt_pct and a negative value warn too, with the class", {
  r <- i_catch(fmt_pct(0.0004))
  expect_equal(b_txt(r$value), "0.0%")
  expect_length(r$warnings, 1L)
  expect_true(any(vapply(r$warnings, inherits, NA, "weft_zero_warning")))
  r2 <- i_catch(fmt_num(-0.04))
  expect_equal(b_txt(r2$value), "0.0")
  expect_length(r2$warnings, 1L)
  expect_true(any(vapply(r2$warnings, inherits, NA, "weft_zero_warning")))
})

test_that("1i zero: weft_str() outside a knit signals the same warning and returns the text", {
  r <- i_catch(weft::weft_str("Dose `r 0.04`{.num} mg"))
  expect_identical(r$value, "Dose 0.0 mg")
  expect_length(r$warnings, 1L)
  expect_true(any(vapply(r$warnings, inherits, NA, "weft_zero_warning")))
  expect_match(r$text, "0.04", fixed = TRUE)
})

test_that("1i zero: outside a knit, digits or sigfig on the call or construct silence it; noise, zero and ordinary values give none", {
  expect_no_warning(fmt_num(0.04, digits = 1))
  expect_no_warning(fmt_num(0.04, sigfig = 1))
  expect_no_warning(fmt_pct(0.0004, digits = 1))
  expect_no_warning(fmt_pct(0.0004, sigfig = 1))
  expect_no_warning(fmt_num(0.1 + 0.2 - 0.3))
  expect_no_warning(fmt_num(1e-12))
  expect_no_warning(fmt_num(-1e-12))
  expect_no_warning(fmt_pct(1e-12))
  expect_no_warning(fmt_num(0))                 # controls
  expect_no_warning(fmt_pct(0))
  expect_no_warning(fmt_num(0.06))
  expect_no_warning(fmt_num(3.14))
  expect_no_warning(weft::weft_str("Dose `r 0.04`{.num digits=\"1\"} mg"))
  expect_no_warning(weft::weft_str("Dose `r 0.04`{.num sigfig=\"1\"} mg"))
  expect_identical(weft::weft_str("Dose `r 0.04`{.num digits=\"1\"} mg"), "Dose 0.0 mg")
})

test_that("1i zero: noise below 1e-9 prints 0 with no warning, outside a knit", {
  r <- i_catch(fmt_num(0.1 + 0.2 - 0.3))
  expect_equal(b_txt(r$value), "0")
  expect_length(r$warnings, 0L)
  r <- i_catch(fmt_pct(-1e-12))
  expect_equal(b_txt(r$value), "0%")
  expect_length(r$warnings, 0L)
})

test_that("1i zero: one warning per call however many elements print as zero", {
  r <- i_catch(fmt_num(c(0.04, 0.03, 5)))
  expect_equal(b_txt(r$value), c("0.0", "0.0", "5"))
  expect_length(r$warnings, 1L)
  expect_true(any(vapply(r$warnings, inherits, NA, "weft_zero_warning")))
  expect_match(r$text, "0.04", fixed = TRUE)     # the first
  expect_match(r$text, "\\b2\\b")                # the count
  # control: no element prints as zero
  expect_length(i_catch(fmt_num(c(3, 5)))$warnings, 0L)
})

# ---- the warning, in a knit -------------------------------------------------------

test_that("1i zero: in a knit the values print 0.0, no marker is left and the render does not fail", {
  res <- i_knit()
  expect_false(res$failed, label = res$message)
  txt <- paste(res$text, collapse = "\n")
  expect_match(txt, "A 0.0 here.", fixed = TRUE)
  expect_match(txt, "B 0.0% here.", fixed = TRUE)
  expect_match(txt, "C 0.0, 0.0 and 5 here.", fixed = TRUE)
  expect_match(txt, "D 0.0 here.", fixed = TRUE)
  expect_match(txt, "I 0.0 here.", fixed = TRUE)
  expect_false(grepl("<<weft", txt, fixed = TRUE))
  expect_false(grepl(B_MINUS, txt, fixed = TRUE))
})

test_that("1i zero: .num, .pct and the default class with an attribute block each record one warned check, in $warnings and not in $failures", {
  res <- i_knit()
  expect_false(res$failed, label = res$message)
  k <- res$knit
  expect_s3_class(k$warnings, "data.frame")
  expect_identical(names(k$warnings), names(k$failures))
  expect_equal(nrow(k$warnings), length(I1_WARNED))
  expect_equal(sort(unique(k$warnings$line)), sort(res$offset + I1_WARNED))
  expect_true(all(k$warnings$kind == "printed as zero"))
  expect_equal(sum(k$failures$kind == "printed as zero"), 0L)
  expect_equal(nrow(k$failures), 0L)
})

test_that("1i zero: the message names the value, what printed, sigfig and digits", {
  res <- i_knit()
  expect_false(res$failed, label = res$message)
  a <- i_row(res, 1L)
  expect_match(a, "0.04", fixed = TRUE)
  expect_match(a, "printed as 0.0", fixed = TRUE)
  expect_match(a, "sigfig", fixed = TRUE)
  expect_match(a, "digits", fixed = TRUE)
  b <- i_row(res, 3L)                                   # .pct: the percentage and what printed
  expect_match(b, "0.0004|0.04", perl = TRUE)
  expect_match(b, "printed as 0.0%", fixed = TRUE)
  d <- i_row(res, 7L)                                   # default class
  expect_match(d, "0.04", fixed = TRUE)
  expect_match(d, "printed as 0.0", fixed = TRUE)
  i <- i_row(res, 17L)                                  # negative: prints without a minus
  expect_match(i, "-0.04|−0.04", perl = TRUE)
  expect_match(i, "printed as 0.0", fixed = TRUE)
})

test_that("1i zero: one warning per construct however many elements print as zero; the message gives the first and the count", {
  res <- i_knit()
  expect_false(res$failed, label = res$message)
  expect_equal(sum(res$knit$warnings$line == res$offset + 5L), 1L)
  cc <- i_row(res, 5L)
  expect_match(cc, "0.04", fixed = TRUE)
  expect_match(cc, "\\b2\\b")
})

test_that("1i zero: digits or sigfig on the construct silence it, and so do noise, exact zero, ordinary values and governors (controls)", {
  res <- i_knit()
  expect_false(res$failed, label = res$message)
  txt <- paste(res$text, collapse = "\n")
  expect_match(txt, "E 0.0 0.04 0.0% 0.04% here.", fixed = TRUE)
  expect_match(txt, "F 0 0% 0 here.", fixed = TRUE)
  expect_match(txt, "G 0 0% 0.1 3.1 here.", fixed = TRUE)
  expect_match(txt, "H flat and flat here.", fixed = TRUE)
  for (line in c(9L, 11L, 13L, 15L)) expect_equal(sum(res$knit$warnings$line == res$offset + line), 0L, label = paste("line", line))
})

test_that("1i zero: a sign governor that prints 0.0 takes the zero arm and records nothing; # in the arm is exempt", {
  res <- i_knit(c("[up # | down # | flat]{sign=\"0.02\"} and [up # | down # | flat]{sign=\"-0.02\"} and [up # | down # | flat]{sign=\"0.02\" digits=\"2\"}."))
  expect_false(res$failed, label = res$message)
  expect_match(paste(res$text, collapse = "\n"), "flat and flat and up 0.02.", fixed = TRUE)
  expect_equal(nrow(res$knit$warnings), 0L)
  expect_equal(nrow(res$knit$failures), 0L)
})

test_that("1i zero: a project default digits in _weft.yml does not silence it", {
  res <- i_knit(c("Z `r 0.04`{.num} and `r 0.04`{.num digits=\"1\"} and `r 3.14`{.num}."),
                files = list("_weft.yml" = "digits: 1"))
  expect_false(res$failed, label = res$message)
  expect_match(paste(res$text, collapse = "\n"), "Z 0.0 and 0.0 and 3.1.", fixed = TRUE)
  expect_equal(nrow(res$knit$warnings), 1L)             # the one without digits on the construct
  expect_true(all(res$knit$warnings$kind == "printed as zero"))
})

test_that("1i zero: a project default digits in front matter does not silence it either", {
  res <- i_knit(c("Z `r 0.04`{.num}."), front = c("weft:", "  digits: 1"))
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(res$knit$warnings), 1L)
})

test_that("1i zero: noise below 1e-9 (0.1 + 0.2 - 0.3) prints 0 and is never warned about", {
  res <- i_knit(c("N `r 0.1 + 0.2 - 0.3`{.num} and `r 1e-12`{.pct} and `r 0.3 - 0.26`{.num}."))
  expect_false(res$failed, label = res$message)
  expect_match(paste(res$text, collapse = "\n"), "N 0 and 0% and 0.0.", fixed = TRUE)
  expect_equal(nrow(res$knit$warnings), 1L)             # only 0.3 - 0.26, which is not noise
})

test_that("1i zero: a weft_str() call in chunk code records the warning in the knit", {
  res <- i_knit(c("```{r chunkcode, echo=FALSE}",
                  "s <- weft::weft_str(\"Dose `r 0.04`{.num} mg\")",
                  "```",
                  "",
                  "Got `r s`."))
  expect_false(res$failed, label = res$message)
  expect_match(paste(res$text, collapse = "\n"), "Got Dose 0.0 mg.", fixed = TRUE)
  expect_equal(nrow(res$knit$warnings), 1L)
  expect_equal(res$knit$warnings$kind, "printed as zero")
})

# ---- the reports ------------------------------------------------------------------

test_that("1i zero: the warnings are printed to stderr under 'weft: N warned check(s)', and the render succeeds", {
  res <- render_rmd(I1_LINES, code = "k <- 3")          # a child process: stderr is in the log
  expect_false(res$failed, label = res$message)
  log <- paste(res$log, collapse = "\n")
  expect_match(log, sprintf("weft: %d warned check\\(s\\)", length(I1_WARNED)))
  expect_match(log, "printed as zero", fixed = TRUE)
  expect_match(log, at_line(res, 1))
  expect_match(res$md, "A 0.0 here.", fixed = TRUE)
})

test_that("1i zero: in draft mode it is no marker, the render succeeds and the draft JSON carries each with level warn", {
  res <- i_knit(draft = TRUE, format = "knit", files = list("_weft.yml" = "digits: 1"))
  expect_false(res$failed, label = res$message)
  txt <- paste(res$text, collapse = "\n")
  expect_false(grepl("<<weft", txt, fixed = TRUE))
  expect_match(txt, "A 0.0 here.", fixed = TRUE)
  expect_equal(nrow(res$knit$failures), 0L)
  expect_equal(nrow(res$knit$warnings), length(I1_WARNED))
  json <- file.path(res$dir, "doc.weft-failures.json")
  expect_true(file.exists(json))
  if (file.exists(json)) {
    x <- jsonlite::fromJSON(json, simplifyVector = FALSE)
    lv <- vapply(x, function(e) if (is.null(e$level)) NA_character_ else as.character(e$level), "")
    ln <- vapply(x, function(e) as.integer(e$line), 1L)
    expect_equal(sort(ln[lv %in% "warn"]), sort(res$offset + I1_WARNED))
    expect_equal(sum(!(lv %in% "warn")), 0L)
  }
})

# ---- rehearse() -------------------------------------------------------------------

test_that("1i zero: rehearse() gives a case that prints a number as zero a row in warnings, and ok ignores it", {
  lines <- c("---", "title: \"t\"", "params:", "  count: 2", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
             "Rate `r params$count / 100`{.num} here.", "")
  path <- e1_write(lines, "doc.Rmd")
  r <- e1_with_libs(rehearse(path, list(a = list(count = 2), b = list(count = 50))))
  expect_true(is.data.frame(r$cases$a$warnings))
  expect_equal(nrow(r$cases$a$warnings), 1L)
  expect_equal(r$cases$a$warnings$kind, "printed as zero")
  expect_identical(names(r$cases$a$warnings), names(r$cases$a$failures))
  expect_equal(nrow(r$cases$b$warnings), 0L)            # control: 0.5 prints 0.5
  expect_true(r$cases$a$ok)
  expect_true(r$cases$b$ok)
  expect_equal(nrow(r$cases$a$failures), 0L)
})

# ---- Quarto -----------------------------------------------------------------------

test_that("1i zero: under Quarto it prints 0.0, warns on stderr, and digits silences it", {
  skip_if_no_quarto()
  body <- batch_cases(c("`r 0.04`{.num}", "`r 0.04`{.num digits=\"1\"}", "`r 0.0004`{.pct}"))
  res <- render_qmd(body)
  expect_false(res$failed, label = res$message)
  expect_equal(unlist(split_cases(res, 3)), c("0.0", "0.0", "0.0%"))
  log <- paste(res$log, collapse = "\n")
  expect_match(log, "weft: 2 warned check\\(s\\)")
  expect_match(log, "printed as zero", fixed = TRUE)
})
