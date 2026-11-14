# Stage 1f: a check that warns, a number that prints as zero, house style
# (thousands_from, serial_comma), the new .p format, and last_knit()
# exported. Contract: dev/design-1f.md (entries 31, 33, 34, 35, 37).
#
# Renders are slow, so the markup rows of each topic are batched into one
# document and read back by case. Quarto is used for a few central cases only.

PRE_1F <- c(
  "k <- 3; z <- 0; flag <- TRUE",
  "sites <- c('A', 'B', 'C'); pair <- c('A', 'B'); many <- letters[1:7]",
  "four <- letters[1:4]; means <- c(A = 1.2, B = 3.4, C = 5.6)"
)

# warnings raised by an expression, and its value
f1_catch <- function(expr) {
  ws <- list()
  val <- withCallingHandlers(
    expr,
    warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") }
  )
  list(value = val, warnings = ws,
       text = paste(vapply(ws, conditionMessage, ""), collapse = "\n"))
}

# a batch of one-paragraph cases through one engine; returns the output of each
f1_cases <- function(cases, engine = "rmd", ...) {
  res <- if (engine == "rmd") {
    render_rmd(batch_cases(cases), code = PRE_1F, ...)
  } else {
    render_qmd(batch_cases(cases), code = PRE_1F, ...)
  }
  if (res$failed) stop("the batch did not render: ", substr(res$message, 1, 400), call. = FALSE)
  list(res = res, got = unlist(split_cases(res, length(cases))))
}

# ---- the cases shared by the style tests ------------------------------------------

P_CASES <- c(
  "`r 0.046`{.p}", "`r 0.004`{.p}", "`r 0.05`{.p}", "`r 0.1`{.p}", "`r 0.2`{.p}",
  "`r 0.0999`{.p}", "`r 0.0004`{.p}", "`r 0.995`{.p}", "`r c(0.046, 0.2)`{.p .and}"
)
P_WANT <- c("p = 0.046", "p = 0.004", "p = 0.050", "p = 0.10", "p = 0.20",
            "p = 0.10", "p < 0.001", "p > 0.99", "p = 0.046 and p = 0.20")

STYLE_CASES <- c(
  "`r 999`{.num}", "`r 1000`{.num}", "`r 1234.5`{.num}", "`r -4321`{.num}", "`r 10`{.pct}",
  "`r sites`{.and}", "`r sites`{.or}", "`r pair`{.and}", "`r means`{.pairs}",
  "`r many`{.and trunc=\"3\"}", "`r many`{.and trunc=\"2\"}", "`r many`{.and trunc=\"1\"}",
  "`r four`{.and trunc=\"3\"}", "`r sites`{.and last=\" plus \"}", "`r pair`{.or}"
)

# ---- 1. claim(level = "warn"), outside a knit ---------------------------------------

test_that("1f claim level: outside a knit a failed warned check is a weft_claim_warning and the value comes back", {
  r <- f1_catch(claim(4217, . > 10000, level = "warn"))
  expect_identical(r$value, 4217)
  expect_length(r$warnings, 1L)
  expect_s3_class(r$warnings[[1]], "weft_claim_warning")
  expect_match(r$text, ". > 10000", fixed = TRUE)
  expect_match(r$text, "4217", fixed = TRUE)
  # control: level = "fail" still stops, with the old class
  expect_error(claim(4217, . > 10000, level = "fail"), class = "weft_claim_failed")
  expect_error(claim(4217, . > 10000), class = "weft_claim_failed")
})

test_that("1f claim level: a warned check that passes is silent and returns the value", {
  expect_no_warning(r <- claim(5, . > 1, . < 10, level = "warn"))
  expect_identical(r, 5)
})

test_that("1f claim level: with several checks, each one that is not TRUE is warned about", {
  r <- f1_catch(claim(5, . > 10, . < 100, . < 0, level = "warn"))
  expect_identical(r$value, 5)
  expect_gte(length(r$warnings), 1L)
  expect_true(all(vapply(r$warnings, inherits, NA, "weft_claim_warning")))
  expect_match(r$text, ". > 10", fixed = TRUE)
  expect_match(r$text, ". < 0", fixed = TRUE)
  expect_false(grepl(". < 100", r$text, fixed = TRUE))
})

test_that("1f claim level: a check that is not a single TRUE is warned about like a failed one", {
  for (chk in list(quote(NA), quote(c(TRUE, TRUE)), quote(logical(0)), quote(1))) {
    cl <- as.call(list(quote(claim), 5, chk, level = "warn"))
    r <- f1_catch(eval(cl))
    expect_identical(r$value, 5, label = deparse(chk))
    expect_length(r$warnings, 1L)
    expect_s3_class(r$warnings[[1]], "weft_claim_warning")
  }
})

test_that("1f claim level: a check that itself errors is a failure at the level given", {
  r <- f1_catch(claim(5, stop("boom"), level = "warn"))
  expect_identical(r$value, 5)
  expect_length(r$warnings, 1L)
  expect_s3_class(r$warnings[[1]], "weft_claim_warning")
  expect_error(claim(5, stop("boom"), level = "fail"), class = "weft_claim_failed")
})

test_that("1f claim level: level must be given by name, and any other level is an error", {
  # a bare "warn" is refused with a message that says to write `level = ` (review F #15)
  expect_error(claim(5, . > 1, "warn"), class = "weft_claim_level")
  expect_error(claim(5, . > 1, level = "info"), class = "weft_claim_level")
  expect_error(claim(5, . > 1, level = "WARN"), class = "weft_claim_level")
  expect_error(claim(5, . > 1, level = 1), class = "weft_claim_level")
  expect_error(claim(5, . > 1, level = NA_character_), class = "weft_claim_level")
  # control: both legal levels
  expect_identical(claim(5, . > 1, level = "fail"), 5)
  expect_identical(claim(5, . > 1, level = "warn"), 5)
})

test_that("1f claim level: weft_str() outside a knit warns on a warned check and returns the text", {
  r <- f1_catch(weft::weft_str("Depth `r claim(12, . > 500, level = 'warn')`{.num} m"))
  expect_identical(r$value, "Depth 12 m")
  expect_length(r$warnings, 1L)
  expect_s3_class(r$warnings[[1]], "weft_claim_warning")
  expect_identical(weft::weft_str("Depth `r claim(12, . > 5, level = 'warn')`{.num} m"), "Depth 12 m")
})

test_that("1f claim level: a guard (if with one arm) has no level", {
  b_expect_scan_error("Sites [rose]{if=\"flag\" level=\"warn\"}.",
                      "Sites [rose]{if=\"flag\"}.")
})

# ---- 1. claim(level = "warn"), in a knit ----------------------------------------------

W1_LINES <- c(
  "Prose `r claim(k, . > 700, level = \"warn\")`{.num} here.",
  "",
  "```{r fig, echo=FALSE, fig.cap='Caption `r claim(k, . > 701, level = \"warn\")`{.num} here'}",
  "plot(1)",
  "```",
  "",
  "```{r chunkcode, echo=FALSE}",
  "v <- claim(k, . > 702, level = \"warn\")",
  "s <- weft::weft_str(\"Str `r claim(k, . > 703, level = 'warn')`{.num} done.\")",
  "```",
  "",
  "Chunk value `r v`; `r s`",
  "",
  "Control `r claim(k, . > 0, level = \"warn\")`{.num} passes.",
  "",
  "Guard [rises | falls]{if=\"flag\"} fine."
)

test_that("1f claim level: in a knit a warned check prints as if passed, leaves no marker, and does not fail the render", {
  res <- render_rmd(W1_LINES, code = PRE_1F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  txt <- paste(res$text, collapse = "\n")
  expect_match(txt, "Prose 3 here.", fixed = TRUE)
  expect_match(txt, "Caption 3 here", fixed = TRUE)
  expect_match(txt, "Chunk value 3; Str 3 done.", fixed = TRUE)
  expect_match(txt, "Control 3 passes.", fixed = TRUE)
  expect_false(grepl("<<weft", txt, fixed = TRUE))
})

test_that("1f claim level: warned checks of prose, a caption, chunk code and weft_str() are in last_knit()$warnings, not in $failures", {
  res <- render_rmd(W1_LINES, code = PRE_1F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  k <- res$knit
  expect_s3_class(k$warnings, "data.frame")
  expect_s3_class(k$failures, "data.frame")
  expect_identical(names(k$warnings), names(k$failures))
  expect_equal(nrow(k$warnings), 4L)
  expect_equal(nrow(k$failures), 0L)
  everything <- paste(unlist(k$warnings), collapse = " ")
  for (n in 700:703) expect_match(everything, sprintf(". > %d", n), fixed = TRUE)
  expect_true((res$offset + 1L) %in% k$warnings$line)   # the prose one, by its line
})

test_that("1f claim level: last_knit()$warnings has zero rows, with the failures' columns, when nothing warned", {
  res <- render_rmd(c("Clean `r claim(k, . > 0, level = \"warn\")`{.num} text."),
                    code = PRE_1F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_s3_class(res$knit$warnings, "data.frame")
  expect_equal(nrow(res$knit$warnings), 0L)
  expect_identical(names(res$knit$warnings), names(res$knit$failures))
})

W2_LINES <- c(
  "Warned `r claim(k, . > 777, level = \"warn\")`{.num} here.",
  "",
  "Failed `r claim(k, . > 888)`{.num} here."
)

test_that("1f claim level: the warnings are printed to stderr under 'weft: N warned check(s)' even when the render fails; the error lists failures only", {
  res <- render_rmd(W2_LINES, code = PRE_1F)          # a child process: stderr is in the log
  expect_true(res$failed)
  log <- paste(res$log, collapse = "\n")
  expect_match(log, "weft: 1 warned check\\(s\\)")
  expect_match(log, at_line(res, 1))
  expect_match(log, ". > 777 was FALSE", fixed = TRUE)
  expect_match(res$message, ". > 888", fixed = TRUE)
  expect_match(res$message, at_line(res, 3))
  expect_false(grepl("> 777", res$message, fixed = TRUE))
  expect_false(grepl("warned", res$message, fixed = TRUE))
})

test_that("1f claim level: a render that only warns also prints the warnings to stderr, and succeeds", {
  res <- render_rmd(c("Only `r claim(k, . > 779, level = \"warn\")`{.num} warned."), code = PRE_1F)
  expect_false(res$failed, label = res$message)
  log <- paste(res$log, collapse = "\n")
  expect_match(log, "weft: 1 warned check\\(s\\)")
  expect_match(log, ". > 779 was FALSE", fixed = TRUE)
  expect_match(res$md, "Only 3 warned.", fixed = TRUE)
})

test_that("1f claim level: in draft mode a warned check is no marker and the draft JSON carries it with level warn", {
  res <- render_rmd(W2_LINES, code = PRE_1F, format = "knit", in_process = TRUE,
                    files = list("_weft.yml" = "digits: 3"), env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  warned <- grep("^Warned ", res$text, value = TRUE)
  failed <- grep("^Failed ", res$text, value = TRUE)
  expect_equal(warned, "Warned 3 here.")
  expect_match(failed, "<<weft: failed claim", fixed = TRUE)   # control: a failure still marks
  expect_equal(nrow(res$knit$warnings), 1L)
  expect_equal(nrow(res$knit$failures), 1L)
  json <- file.path(res$dir, "doc.weft-failures.json")
  expect_true(file.exists(json))
  if (file.exists(json)) {
    x <- jsonlite::fromJSON(json, simplifyVector = FALSE)
    lv <- vapply(x, function(e) if (is.null(e$level)) NA_character_ else as.character(e$level), "")
    ln <- vapply(x, function(e) as.integer(e$line), 1L)
    expect_equal(lv[ln == res$offset + 1L], "warn")
    expect_false(identical(lv[ln == res$offset + 3L], "warn"))
  }
})

test_that("1f claim level: a warned check that errors is a warning in a knit", {
  res <- render_rmd(c("Err `r claim(k, stop('boom'), level = \"warn\")`{.num} text."),
                    code = PRE_1F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(res$knit$warnings), 1L)
  expect_equal(nrow(res$knit$failures), 0L)
  expect_match(res$md, "Err 3 text.", fixed = TRUE)
})

test_that("1f claim level: rehearse() gives each case a warnings data frame and ok ignores it", {
  lines <- c(E1_WRITE_LINES, "Count `r claim(n, . > 5, level = \"warn\")`{.num}.", "")
  path <- e1_write(lines, "doc.Rmd")
  r <- e1_with_libs(rehearse(path, list(a = list(count = 9), b = list(count = 1))))
  expect_true(is.data.frame(r$cases$a$warnings))
  expect_true(is.data.frame(r$cases$b$warnings))
  expect_equal(nrow(r$cases$a$warnings), 0L)            # control: the check passes
  expect_equal(nrow(r$cases$b$warnings), 1L)
  expect_identical(names(r$cases$b$warnings), names(r$cases$b$failures))
  expect_true(r$cases$a$ok)
  expect_true(r$cases$b$ok)
  expect_equal(nrow(r$cases$b$failures), 0L)
})

test_that("1f claim level: Quarto, a warned check prints as passed and the render succeeds; the warning is on stderr", {
  skip_if_no_quarto()
  body <- batch_cases(c("`r claim(k, . > 790, level = \"warn\")`{.num}"))
  res <- render_qmd(body, code = PRE_1F)
  expect_false(res$failed, label = res$message)
  expect_equal(unlist(split_cases(res, 1)), "3")
  expect_match(paste(res$log, collapse = "\n"), "weft: 1 warned check\\(s\\)")
})

test_that("1f claim level: a Quarto project lists warned checks after the failures, writes level warn to the collection file, and does not fail on warnings alone", {
  skip_if_no_quarto()
  skip_on_cran()
  mk <- function(title, body) c("---", sprintf("title: \"%s\"", title), "engine: knitr", "---", "",
                                "```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3", "```", "", body)
  yml <- c("project:", "  type: default", "format: html")
  # warnings only: the project renders
  d1 <- mk_project(list(`_quarto.yml` = yml,
                        `w.qmd` = mk("W", "Only `r claim(k, . > 795, level = \"warn\")`{.num} warned.")))
  withr::defer(unlink(d1, recursive = TRUE))
  r1 <- qrender(d1)
  expect_identical(r1$status, 0L, info = r1$log)
  expect_match(r1$log, "warned check\\(s\\)")
  expect_match(r1$log, ". > 795", fixed = TRUE)
  # a failing chapter (a failed check; a small number no longer fails, 1g) beside a warned one
  # the order is given: without `render:` Quarto takes the files in the folder's order, which differs by platform
  yml2 <- append(yml, c("  render:", "    - a.qmd", "    - b.qmd"), after = 2L)
  d2 <- mk_project(list(`_quarto.yml` = yml2,
                        `a.qmd` = mk("A", "Warn `r claim(k, . > 796, level = \"warn\")`{.num} here."),
                        `b.qmd` = mk("B", "Fail `r claim(k, . > 797)`{.num} here.")))
  withr::defer(unlink(d2, recursive = TRUE))
  r2 <- qrender(d2)
  expect_false(identical(r2$status, 0L))
  expect_match(r2$log, ". > 797", fixed = TRUE)           # the failure is reported
  expect_match(r2$log, ". > 796", fixed = TRUE)           # and the warning too
  expect_lt(regexpr(". > 797", r2$log, fixed = TRUE)[1], regexpr(". > 796", r2$log, fixed = TRUE)[1])
  f <- file.path(d2, ".weft", "failures.jsonl")
  if (file.exists(f)) {
    ls <- readLines(f, warn = FALSE)
    ls <- ls[nzchar(trimws(ls))]
    x <- lapply(ls, jsonlite::fromJSON, simplifyVector = FALSE)
    lv <- vapply(x, function(e) if (is.null(e$level)) NA_character_ else as.character(e$level), "")
    expect_true("warn" %in% lv)
    expect_gte(length(lv), 2L)
  }
})

# ---- 2. a number that prints as zero --------------------------------------------------

test_that("1f zero (amended by 1i): .num and .pct of a non-zero number that would print as zero print to the default digits, with no value error", {
  suppressWarnings({   # 1i: each of these also warns (see test-1i.R)
    expect_equal(b_txt(fmt_num(0.04)), "0.0")
    expect_equal(b_txt(fmt_num(-0.04)), "0.0")
    expect_equal(b_txt(fmt_num(1e-6)), "0.0")
    expect_equal(b_txt(fmt_num(c(3, 0.04))), c("3", "0.0"))
    expect_equal(b_txt(fmt_pct(0.0004)), "0.0%")
    expect_equal(b_txt(fmt_pct(-0.0004)), "0.0%")
  })
})

test_that("1f zero: with digits or sigfig given it prints as asked; exact zero and ordinary values print as before", {
  expect_equal(b_txt(fmt_num(0.04, digits = 1)), "0.0")
  expect_equal(b_txt(fmt_num(0.04, digits = 0)), "0")
  expect_equal(b_txt(fmt_num(0.04, sigfig = 1)), "0.04")
  expect_equal(b_txt(fmt_pct(0.0004, digits = 1)), "0.0%")
  expect_equal(b_txt(fmt_pct(0.0004, sigfig = 1)), "0.04%")
  expect_equal(b_txt(fmt_num(0)), "0")
  expect_equal(b_txt(fmt_pct(0)), "0%")
  expect_equal(b_txt(fmt_num(0.06)), "0.1")
  expect_equal(b_txt(fmt_num(0.04, digits = 2)), "0.04")
  expect_equal(b_txt(fmt_pct(0.004)), "0.4%")
  expect_equal(b_txt(fmt_pct(0.0123)), "1.2%")
})

Z_ROWS <- list(
  b_row("Z01", "`r 0.04`{.num}", "1f zero (1i): default digits print 0.0 and warn", want = "Z01 0.0", collected = FALSE),
  b_row("Z02", "`r 0.0004`{.pct}", "1f zero (1i): .pct", want = "Z02 0.0%", collected = FALSE),
  b_row("Z03", "`r 0.04`{.num digits=\"1\"}", "1f zero: digits on the construct", want = "Z03 0.0", collected = FALSE),
  b_row("Z04", "`r 0.04`{.num sigfig=\"1\"}", "1f zero: sigfig on the construct", want = "Z04 0.04", collected = FALSE),
  b_row("Z05", "`r 0.0004`{.pct digits=\"1\"}", "1f zero: .pct digits", want = "Z05 0.0%", collected = FALSE),
  b_row("Z06", "`r 0.0004`{.pct sigfig=\"1\"}", "1f zero: .pct sigfig", want = "Z06 0.04%", collected = FALSE),
  b_row("Z07", "`r 0`{.num} and `r 0`{.pct}", "1f zero: exact zero", want = "Z07 0 and 0%", collected = FALSE),
  b_row("Z08", "`r 0.06`{.num} and `r 0.004`{.pct}", "control", want = "Z08 0.1 and 0.4%", collected = FALSE),
  b_row("Z09", "`r -0.04`{.num}", "1f zero (1i): negative, no minus sign", want = "Z09 0.0", collected = FALSE)
)

test_that("1f zero (amended by 1i): in a knit no failure is collected (the 0.0 rows warn, see test-1i.R); a project default digits in _weft.yml does not count as given", {
  b <- b_body(Z_ROWS)
  res <- render_rmd(b$lines, code = PRE_1F, in_process = TRUE, env = c(WEFT_DRAFT = "1"),
                    files = list("_weft.yml" = "digits: 1"))
  b_need(res)
  b_check_lines(res, b, Z_ROWS, "rmd")
  f <- res$knit$failures
  expect_equal(sum(f$kind == "value error"), 0L)
  expect_equal(NROW(f), 0L)
})

test_that("1f zero (amended by 1i): a project default digits in front matter does not count as given either", {
  res <- render_rmd(c("Z `r 0.04`{.num} and `r 0.04`{.num digits=\"1\"}."), code = PRE_1F,
                    in_process = TRUE, front = c("weft:", "  digits: 1"))
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Z 0.0 and 0.0.", fixed = TRUE)
})

test_that("1f zero (amended by 1i): without draft mode a small number renders, as 0.0; with digits given it prints 0.0", {
  r1 <- render_rmd(c("Z `r 0.04`{.num} here."), code = PRE_1F, in_process = TRUE)
  expect_false(r1$failed, label = r1$message)
  expect_match(r1$md, "Z 0.0 here.", fixed = TRUE)
  ok <- render_rmd(c("Z `r 0.04`{.num digits=\"1\"} here."), code = PRE_1F)
  expect_false(ok$failed, label = ok$message)
  expect_match(ok$md, "Z 0.0 here.", fixed = TRUE)
})

# ---- 3. house style -------------------------------------------------------------------------

test_that("1f style: thousands_from defaults to 1000 and serial_comma to false in the configuration", {
  d <- withr::local_tempdir()
  withr::local_envvar(WEFT_DRAFT = NA)
  x <- weft:::read_config(d, front = list())
  expect_equal(x$thousands_from, 1000)
  expect_false(x$serial_comma)
})

test_that("1f style: thousands_from and serial_comma are read from _weft.yml and front matter, front matter winning", {
  withr::local_envvar(WEFT_DRAFT = NA)
  d <- withr::local_tempdir()
  writeLines(c("thousands_from: 10000", "serial_comma: true"), file.path(d, "_weft.yml"))
  expect_no_warning(x <- weft:::read_config(d, front = list()))   # a known setting, not "unknown"
  expect_equal(x$thousands_from, 10000)
  expect_true(x$serial_comma)
  expect_no_warning(y <- weft:::read_config(d, front = list(thousands_from = 500, serial_comma = FALSE)))
  expect_equal(y$thousands_from, 500)
  expect_false(y$serial_comma)
})

test_that("1f style: a bad thousands_from or serial_comma is an error, in _weft.yml and in front matter", {
  withr::local_envvar(WEFT_DRAFT = NA)
  bad_yml <- list(
    "thousands_from: abc", "thousands_from: 1.5", "thousands_from: -1000",
    "thousands_from: [1, 2]", "serial_comma: maybe", "serial_comma: 2"
  )
  for (l in bad_yml) {
    d <- withr::local_tempdir()
    writeLines(l, file.path(d, "_weft.yml"))
    expect_error(weft:::read_config(d, front = list()), class = "weft_config_error", label = l)
  }
  d <- withr::local_tempdir()
  expect_error(weft:::read_config(d, front = list(thousands_from = "abc")), class = "weft_config_error")
  expect_error(weft:::read_config(d, front = list(thousands_from = 2.5)), class = "weft_config_error")
  expect_error(weft:::read_config(d, front = list(serial_comma = "maybe")), class = "weft_config_error")
  # control: a good value in the same place is accepted
  expect_no_warning(z <- weft:::read_config(d, front = list(thousands_from = 5000)))
  expect_equal(z$thousands_from, 5000)
})

test_that("1f style: by default the thousands mark starts at 1000", {
  expect_equal(b_txt(fmt_num(999)), "999")
  expect_equal(b_txt(fmt_num(999.5)), "999.5")
  expect_equal(b_txt(fmt_num(1000)), "1,000")
  expect_equal(b_txt(fmt_num(1234.5)), "1,234.5")
  expect_equal(b_txt(fmt_num(-1000)), paste0(B_MINUS, "1,000"))
  expect_equal(b_txt(fmt_num(-999)), paste0(B_MINUS, "999"))
  expect_equal(b_txt(fmt_num(12345.678)), "12,345.7")
  expect_equal(b_txt(fmt_pct(10)), "1,000%")
  expect_equal(b_txt(fmt_pct(9.99)), "999%")
})

test_that("1f style: by default there is no serial comma (direct calls)", {
  expect_equal(b_txt(fmt_and(c("a", "b", "c"))), "a, b and c")
  expect_equal(b_txt(fmt_or(c("a", "b", "c"))), "a, b or c")
  expect_equal(b_txt(fmt_and(c("a", "b"))), "a and b")
  expect_equal(b_txt(fmt_pairs(c(A = 1, B = 2, C = 3))), "A (1), B (2) and C (3)")
  expect_equal(b_txt(fmt_and(letters[1:7], trunc = 3)), "a, b, c and 4 others")
})

test_that("1f style: default render: thousands from 1000, no serial comma, the new .p (rmarkdown)", {
  b <- f1_cases(c(STYLE_CASES, P_CASES))
  want <- c(
    "999", "1,000", "1,234.5", paste0(B_MINUS, "4,321"), "1,000%",
    "A, B and C", "A, B or C", "A and B", "A (1.2), B (3.4) and C (5.6)",
    "a, b, c and 4 others", "a, b and 5 others", "a and 6 others",
    "a, b, c and 1 other", "A, B plus C", "A or B",
    P_WANT
  )
  expect_equal(unesc(b$got), want)
})

test_that("1f style: _weft.yml thousands_from: 10000 gives the old behaviour, serial_comma: true adds the comma (rmarkdown)", {
  cfg <- list("_weft.yml" = c("thousands_from: 10000", "serial_comma: true"))
  cases <- c(STYLE_CASES, "`r 9999`{.num}", "`r 10000`{.num}")
  b <- f1_cases(cases, files = cfg)
  want <- c(
    "999", "1000", "1234.5", paste0(B_MINUS, "4321"), "1000%",
    "A, B, and C", "A, B, or C", "A and B", "A (1.2), B (3.4), and C (5.6)",
    "a, b, c, and 4 others", "a, b, and 5 others", "a and 6 others",
    "a, b, c, and 1 other", "A, B plus C", "A or B",
    "9999", "10,000"
  )
  expect_equal(b$got, want)
})

test_that("1f style: front matter overrides _weft.yml for thousands_from and serial_comma (rmarkdown)", {
  cfg <- list("_weft.yml" = c("thousands_from: 10000", "serial_comma: false"))
  b <- f1_cases(c("`r 12345`{.num}", "`r 123456`{.num}", "`r sites`{.and}", "`r sites`{.or}", "`r pair`{.and}"),
                files = cfg, front = c("weft:", "  thousands_from: 100000", "  serial_comma: true"))
  expect_equal(b$got, c("12345", "123,456", "A, B, and C", "A, B, or C", "A and B"))
})

test_that("1f style: a last key on the construct wins over serial_comma, and serial_comma: false leaves lists alone", {
  b <- f1_cases(c("`r sites`{.and last=\" plus \"}", "`r sites`{.or last=\" or else \"}", "`r sites`{.and}"),
                files = list("_weft.yml" = "serial_comma: true"))
  expect_equal(b$got, c("A, B plus C", "A, B or else C", "A, B, and C"))
  c2 <- f1_cases(c("`r sites`{.and}", "`r sites`{.and last=\", and \"}"),
                 files = list("_weft.yml" = "serial_comma: false"))
  expect_equal(c2$got, c("A, B and C", "A, B, and C"))
})

test_that("1f style: a bad thousands_from in _weft.yml fails the render", {
  res <- render_rmd("Value `r 5000`{.num}.", files = list("_weft.yml" = "thousands_from: lots"))
  expect_true(res$failed)
  expect_match(res$message, "thousands_from", fixed = TRUE)
  ok <- render_rmd("Value `r 5000`{.num}.", files = list("_weft.yml" = "thousands_from: 10000"))
  expect_false(ok$failed, label = ok$message)
  expect_match(ok$md, "Value 5000.", fixed = TRUE)
})

# ---- 4. .p ------------------------------------------------------------------------------------------

test_that("1f p: below 0.001 it is 'p < 0.001'; from 0.001 to below 0.1 three decimals", {
  cases <- c("0.0004" = "p < 0.001", "0.0009" = "p < 0.001", "0" = "p < 0.001",
             "0.001" = "p = 0.001", "0.004" = "p = 0.004", "0.01" = "p = 0.010",
             "0.0464" = "p = 0.046", "0.05" = "p = 0.050", "0.03" = "p = 0.030",
             "0.099" = "p = 0.099", "0.0994" = "p = 0.099")
  for (nm in names(cases)) {
    x <- fmt_p(as.numeric(nm))
    expect_s3_class(x, "weft_text")
    expect_equal(b_txt(x), cases[[nm]], label = paste("fmt_p(", nm, ")"))
  }
})

test_that("1f p: from 0.1 two decimals; above 0.99 'p > 0.99'", {
  cases <- c("0.1" = "p = 0.10", "0.2" = "p = 0.20", "0.5" = "p = 0.50",
             "0.1234" = "p = 0.12", "0.99" = "p = 0.99",
             "0.995" = "p > 0.99", "0.9991" = "p > 0.99", "1" = "p > 0.99")
  for (nm in names(cases)) {
    expect_equal(b_txt(fmt_p(as.numeric(nm))), cases[[nm]], label = paste("fmt_p(", nm, ")"))
  }
})

test_that("1f p: the rounding is to three decimals first, so 0.0999 is 'p = 0.10' and not 'p = 0.100'", {
  expect_equal(b_txt(fmt_p(0.0999)), "p = 0.10")
  expect_equal(b_txt(fmt_p(0.09949)), "p = 0.099")   # control: rounds to 0.099, still below 0.1
})

test_that("1f p: fmt_p() is element-wise with the new format", {
  expect_equal(b_txt(fmt_p(c(0.046, 0.0004, 0.2, 0.004))),
               c("p = 0.046", "p < 0.001", "p = 0.20", "p = 0.004"))
})

test_that("1f p: the record's number is the number printed", {
  a <- b_rec(fmt_p(0.0464))
  expect_equal(a$number, 0.046)
  expect_equal(a$relation, "=")
  expect_true(a$decimals)
  expect_equal(b_rec(fmt_p(0.0999))$number, 0.1)
  expect_equal(b_rec(fmt_p(0.1234))$number, 0.12)
  lo <- b_rec(fmt_p(0.0004))
  expect_equal(lo$number, 0.001)
  expect_equal(lo$relation, "<")
  hi <- b_rec(fmt_p(0.995))
  expect_equal(hi$number, 0.99)
  expect_equal(hi$relation, ">")
  expect_equal(b_rec(fmt_p(0.2))$number, 0.2)     # control, unchanged
})

test_that("1f p: a text class after .p keeps the new format", {
  expect_equal(b_txt(fmt_strong(fmt_p(0.046))), "**p = 0.046**")
  expect_equal(b_txt(fmt_cap(fmt_p(0.046))), "P = 0.046")
})

test_that("1f p: .p renders in the new format under Quarto too", {
  skip_if_no_quarto()
  cases <- c(P_CASES, STYLE_CASES[c(2, 6)])
  b <- f1_cases(cases, engine = "qmd", files = list("_weft.yml" = "serial_comma: true"))
  expect_equal(unesc(b$got), c(P_WANT, "1,000", "A, B, and C"))
})

# ---- 5. last_knit() ---------------------------------------------------------------------------------

test_that("1f last_knit: it is exported", {
  expect_true("last_knit" %in% getNamespaceExports("weft"))
  expect_true(is.function(weft::last_knit))
})

test_that("1f last_knit: it has a help page that lists its elements", {
  skip_if_not(weft_is_dev(), "the man pages are read from the source tree")
  rd <- file.path(weft_pkg_root(), "man", "last_knit.Rd")
  expect_true(file.exists(rd))
  if (file.exists(rd)) {
    txt <- paste(readLines(rd, warn = FALSE), collapse = "\n")
    for (el in c("failures", "warnings", "constructs", "sentence_starts")) {
      expect_match(txt, el, fixed = TRUE, label = paste("the help page mentions", el))
    }
  }
})

test_that("1f last_knit: before any knit it returns NULL", {
  lib <- weft_test_lib()
  code <- paste0(
    "if (nzchar(commandArgs(TRUE)[1])) .libPaths(c(commandArgs(TRUE)[1], .libPaths()));",
    "x <- tryCatch(weft::last_knit(), error = function(e) 'ERROR');",
    "cat('RESULT=', if (is.null(x)) 'NULL' else if (identical(x, 'ERROR')) 'ERROR' else 'OTHER', '\\n', sep = '')"
  )
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                  c("--no-save", "--no-restore", "-e", shQuote(code), shQuote(lib)),
                                  stdout = TRUE, stderr = TRUE))
  expect_true(any(out == "RESULT=NULL"), info = paste(out, collapse = "\n"))
})

test_that("1f last_knit: after a knit the exported function returns the records, with the elements the help page lists", {
  res <- render_rmd(c("A `r k`{.num} and [one | many]{if=\"flag\"}."), code = PRE_1F, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  k <- tryCatch(weft::last_knit(), error = function(e) NULL)
  expect_false(is.null(k))
  expect_true(all(c("failures", "warnings", "constructs", "sentence_starts") %in% names(k)))
  expect_s3_class(k$failures, "data.frame")
  expect_s3_class(k$warnings, "data.frame")
  expect_s3_class(k$constructs, "data.frame")
})
