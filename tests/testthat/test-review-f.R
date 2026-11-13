# Review of stages 1f to 1i (dev/review-1f.md), as ruled in dev/design-1i.md
# ("Rulings on the review of stages 1f to 1i"). Each test is named
# `review F #<finding or question letter>: <what must hold> (<rule>)`.
# Questions A, C, E, G and H were ruled "Left" and have no test here;
# finding 16 is a spec amendment.

rf_catch <- function(expr) {
  ws <- list()
  val <- withCallingHandlers(
    expr,
    warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") }
  )
  list(value = val, warnings = ws,
       zero = Filter(function(w) inherits(w, "weft_zero_warning"), ws),
       text = paste(vapply(ws, conditionMessage, ""), collapse = "\n"))
}

# weft_str() with a few variables in scope
rf_ws <- function(src) {
  fl <- FALSE; tr <- TRUE; v <- c("a", "b"); v3 <- c("a", "b", "c")
  weft::weft_str(src)
}

rf_knit <- function(lines, code = NULL, ...) {
  render_rmd(lines, code = c("v3 <- c('a', 'b', 'c')", code), in_process = TRUE,
             format = "knit", ...)
}

rf_rows <- function(res, line, kind = NULL) {
  w <- res$knit$warnings
  w <- w[w$line == res$offset + line, , drop = FALSE]
  if (!is.null(kind)) w <- w[w$kind == kind, , drop = FALSE]
  w
}

# ---- 1. .range with no number class ------------------------------------------

test_that("review F #1: .range of a small range with no digits or sigfig records one warned check (1i Where; 2.6.11)", {
  x <- c(0.01, 0.04)
  r <- rf_catch(weft::weft_str("`r x`{.range}"))
  expect_identical(r$value, "0.0")
  expect_length(r$zero, 1L)
  expect_length(r$warnings, 1L)
  f <- rf_catch(weft::fmt_range(x))
  expect_equal(as.character(unclass(f$value)), "0.0")
  expect_length(f$zero, 1L)
  # controls: digits or sigfig silence it; a range that prints non-zero is quiet
  expect_no_warning(weft::weft_str("`r x`{.range digits=\"1\"}"))
  expect_no_warning(weft::fmt_range(x, digits = 2))
  expect_no_warning(weft::fmt_range(c(1.5, 2.5)))
  # control: the same vector under .and already warns
  expect_length(rf_catch(weft::weft_str("`r x`{.and}"))$zero, 1L)
})

test_that("review F #1: in a knit, .range of a small range has a warned row (1i; 2.6.11)", {
  res <- rf_knit("A2 `r c(0.01, 0.04)`{.range}.")
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(rf_rows(res, 1L, "printed as zero")), 1L)
})

# ---- 2. a number re-formatted by a class ---------------------------------------

test_that("review F #2: .num on text from fmt_num(digits =) that prints zero is warned about (1i Silencing; ruling 2)", {
  r <- rf_catch(weft::weft_str("`r fmt_num(0.04, digits = 2)`{.num}"))
  expect_identical(r$value, "0.0")
  expect_length(r$zero, 1L)
  r2 <- rf_catch(weft::fmt_num(weft::fmt_num(0.04, digits = 2)))
  expect_equal(as.character(unclass(r2$value)), "0.0")
  expect_length(r2$zero, 1L)
  # controls: digits on the construct silences; the first formatter alone is quiet
  expect_no_warning(weft::weft_str("`r fmt_num(0.04, digits = 2)`{.num digits=\"2\"}"))
  expect_no_warning(weft::fmt_num(0.04, digits = 2))
})

test_that("review F #2: in a knit, the re-formatted number has a warned row (ruling 2)", {
  res <- rf_knit("A4 `r fmt_num(0.04, digits = 2)`{.num}.")
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(rf_rows(res, 1L, "printed as zero")), 1L)
})

# ---- 3. a list class on a list span --------------------------------------------

test_that("review F #3: a .ul, .ol or .dl class on a list span is a construct error (1.5.19; ruling 3)", {
  for (cls in c(".ul", ".ol", ".dl")) {
    e <- tryCatch(rf_ws(sprintf("Sites: [none | # | #]{%s list=\"c(x = 'a', y = 'b')\"} end.", cls)),
                  error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
  }
  # control: a collapse class that is inline still works
  expect_identical(rf_ws("Sites: [none | # | #]{.and list=\"v3\"} end."), "Sites: a, b and c end.")
})

# ---- 4. clamp() under .range ---------------------------------------------------

test_that("review F #4: a clamp() bound beside a small number is not a value error under .range (ruling 4)", {
  out <- NULL
  expect_no_error(
    out <- suppressWarnings(weft::weft_str("R `r clamp(c(0.001, 0.02), floor = 0.01)`{.num .range}."))
  )
  expect_match(paste(out, collapse = ""), "< 0.01", fixed = TRUE)
  # control: with digits it already works
  expect_match(weft::weft_str("R `r clamp(c(0.001, 0.02), floor = 0.01)`{.num .range digits=\"2\"}."),
               "< 0.01", fixed = TRUE)
})

# ---- 5. ci() and pm() -----------------------------------------------------------

test_that("review F #5: ci() and pm() record one warned check per call when a number prints as zero (ruling 1, 5, K)", {
  r <- rf_catch(weft::ci(0.01, 0.002, 0.03))
  expect_length(r$zero, 1L)
  expect_length(r$warnings, 1L)
  p <- rf_catch(weft::pm(0.01, 0.002))
  expect_length(p$zero, 1L)
  expect_length(p$warnings, 1L)
  p2 <- rf_catch(weft::pm(1234.5, 0.04))
  expect_length(p2$zero, 1L)
  # silencing and controls
  expect_no_warning(weft::ci(0.01, 0.002, 0.03, digits = 3))
  expect_no_warning(weft::pm(0.01, 0.002, digits = 3))
  expect_no_warning(weft::ci(1.5, 1.2, 1.9))
  expect_no_warning(weft::pm(12.5, 1.5))
})

test_that("review F #5: in a knit, ci() and pm() have one warned row each (ruling 1, 5)", {
  res <- rf_knit(c("A5 `r ci(0.01, 0.002, 0.03)`.", "", "A6 `r pm(0.01, 0.002)`."))
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(rf_rows(res, 1L, "printed as zero")), 1L)
  expect_equal(nrow(rf_rows(res, 3L, "printed as zero")), 1L)
})

# ---- 6. the warnings report when the knit stops --------------------------------

test_that("review F #6: warned checks are reported on stderr when the knit stops on a plain chunk error (2.6.10; ruling 6)", {
  res <- render_rmd(c("W `r claim(3, . > 5, level = 'warn')` and `r 0.04`{.num}.", "",
                      "```{r boom}", "stop('plain error')", "```"))
  expect_true(res$failed)
  expect_match(res$message, "plain error", fixed = TRUE)
  expect_match(paste(res$log, collapse = "\n"), "weft: 2 warned check\\(s\\)")
})

test_that("review F #6: warned checks are reported on stderr when a bare value errors (2.6.10; ruling 6)", {
  res <- render_rmd(c("W `r claim(3, . > 5, level = 'warn')` and `r 0.04`{.num}.", "",
                      "Then `r stop('bare')`."))
  expect_true(res$failed)
  expect_match(paste(res$log, collapse = "\n"), "weft: 2 warned check\\(s\\)")
})

# ---- 7. none in a function form ------------------------------------------------

test_that("review F #7: none in a function form must be one non-empty string that is not only spaces (3.4.5; ruling 7)", {
  for (f in list(weft::fmt_and, weft::fmt_or)) {
    expect_error(f(character(0), none = ""), class = "weft_construct_error")
    expect_error(f(character(0), none = "  "), class = "weft_construct_error")
    expect_error(f(character(0), none = NA), class = "weft_construct_error")
    expect_error(f(character(0), none = NA_character_), class = "weft_construct_error")
    expect_error(f(character(0), none = c("a", "b")), class = "weft_construct_error")
    expect_error(f(character(0), none = 5), class = "weft_construct_error")
    # control: a good none and the default
    expect_equal(as.character(unclass(f(character(0), none = "nobody"))), "nobody")
  }
})

# ---- 8. the pre-render script and a list span ----------------------------------

test_that("review F #8: a .qmd with a list span and no engine: knitr fails the pre-render check (2.5.4, 9.2.8; 1h)", {
  skip_if_no_quarto()
  mk <- function(body) {
    list(`_quarto.yml` = c("project:", "  type: default", "format: html"),
         `b.qmd` = c("---", "title: \"b\"", "---", "", body))
  }
  # control: an n span with no engine is stopped
  d0 <- mk_project(mk("[one site | # sites]{n=\"3\"} flagged."))
  withr::defer(unlink(d0, recursive = TRUE))
  r0 <- qrender(d0)
  expect_false(identical(r0$status, 0L))
  expect_match(r0$log, "has no `?engine: knitr", perl = TRUE)
  # a list span is stopped the same way, by the pre-render script (6d: list="flagged" is a name, which the
  # filter resolves and the script lets through, so the span here has a governor outside the grammar)
  d <- mk_project(mk("[No sites were | # was | # were]{list=\"3\"} flagged."))
  withr::defer(unlink(d, recursive = TRUE))
  r <- qrender(d)
  expect_false(identical(r$status, 0L))
  expect_match(r$log, "b.qmd", fixed = TRUE)
  expect_match(r$log, "has no `?engine: knitr", perl = TRUE)
  expect_no_match(r$log, "processing file")
})

# ---- 9. .no -----------------------------------------------------------------------

test_that("review F #9: .no replaces a printed zero and the warned check is still recorded (ruling 9; 2.6.11 amended)", {
  r <- rf_catch(weft::fmt_no(0.04))
  expect_equal(as.character(unclass(r$value)), "no")
  expect_length(r$zero, 1L)
  r2 <- rf_catch(weft::weft_str("`r 0.04`{.no}"))
  expect_identical(r2$value, "no")
  expect_length(r2$zero, 1L)
})

# ---- 10, J. # of a list span ----------------------------------------------------

test_that("review F #10: the # of a list span records the warned check; # of an n or sign span does not (ruling 10, J)", {
  r <- rf_catch(weft::weft_str("A7 [none | # | #]{.num list=\"c(0.04, 1.2)\"}."))
  expect_identical(r$value, "A7 0.0 and 1.2.")
  expect_length(r$zero, 1L)
  # controls: the exemption stays for n and sign
  expect_no_warning(weft::weft_str("[# unit | # units]{n=\"0.04\"}"))
  expect_no_warning(weft::weft_str("[up # | down # | flat]{sign=\"0.04\"}"))
})

# ---- 11. none with .range --------------------------------------------------------

test_that("review F #11: none with .range is a construct error, a range has two ends (1.4.14; ruling 11)", {
  expect_error(rf_ws("`r character(0)`{.range none=\"x\"}"), class = "weft_construct_error")
  expect_error(rf_ws("`r c(1, 2)`{.range none=\"x\"}"), class = "weft_construct_error")
  # control: .and with none is fine
  expect_identical(rf_ws("`r character(0)`{.and none=\"x\"}"), "x")
})

# ---- 12. post-render tag ----------------------------------------------------------

test_that("review F #12: the Quarto post-render report tags a printed-as-zero row (ruling accepted in 1i)", {
  skip_if_no_quarto()
  skip_on_cran()
  d <- mk_project(list(
    `_quarto.yml` = c("project:", "  type: default", "format: html"),
    `a.qmd` = c("---", "title: \"a\"", "engine: knitr", "---", "",
                "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
                "Rate `r 0.04`.", "", "Dose `r 0.04`{.num} here.")))
  withr::defer(unlink(d, recursive = TRUE))
  r <- qrender(d)
  expect_identical(r$status, 0L, info = r$log)
  ls <- strsplit(r$log, "\n", fixed = TRUE)[[1]]
  # the post-render report lists the project's warned checks, "file:line  [tag] expr"
  rows <- grep("a\\.qmd:[0-9]+ ", ls, value = TRUE)
  rows <- grep("0\\.04", rows, value = TRUE)
  expect_gte(length(rows), 1L)
  expect_true(all(grepl("[printed as zero]", rows, fixed = TRUE)), info = paste(rows, collapse = "\n"))
})

# ---- 13. the label of a record inside a governed span -----------------------------

test_that("review F #13: a record made inside a governed span is labelled by the governor expression (ruling 13)", {
  res <- rf_knit(c(
    "[No sites were | # was | # were]{list=\"claim(v3, length(.) > 5, level = 'warn')\"} flagged.",
    "",
    "[none | # | #]{.num list=\"c(0.04, 1.2)\"}."))
  expect_false(res$failed, label = res$message)
  a <- rf_rows(res, 1L)
  expect_equal(nrow(a), 1L)
  expect_match(a$expr, "claim(v3", fixed = TRUE)
  expect_false(grepl("No sites were", a$expr, fixed = TRUE))
  b <- rf_rows(res, 3L)
  expect_equal(nrow(b), 1L)
  expect_match(b$expr, "c(0.04, 1.2)", fixed = TRUE)
  expect_false(identical(b$expr, "none"))
})

# ---- 14. last_knit() help ---------------------------------------------------------

test_that("review F #14: the help of last_knit() says warnings also holds the printed-as-zero rows (1i)", {
  rd <- test_path("..", "..", "man", "last_knit.Rd")
  skip_if_not(file.exists(rd), "man/last_knit.Rd is not in this tree")
  txt <- paste(readLines(rd, warn = FALSE), collapse = " ")
  expect_match(txt, "printed as zero", fixed = TRUE)
})

# ---- 15. a positional level -------------------------------------------------------

test_that("review F #15: a check that is the bare string \"warn\" or \"fail\" is an error that says to write level = (3.1.11; ruling 15)", {
  e <- tryCatch(weft::claim(5, . > 10, "warn"), error = function(e) e)
  expect_s3_class(e, "error")
  expect_match(conditionMessage(e), "level =", fixed = TRUE)
  e2 <- tryCatch(weft::claim(5, . > 1, "fail"), error = function(e) e)
  expect_s3_class(e2, "error")
  expect_match(conditionMessage(e2), "level =", fixed = TRUE)
  # control: the named form works
  expect_identical(suppressWarnings(weft::claim(5, . > 10, level = "warn")), 5)
})

# ---- B. the characters an empty arm takes its space before -------------------------

test_that("review F #B: an empty arm takes the space before ] and the closing quotes U+201D and U+2019 and the em dash (1g; ruling B)", {
  expect_identical(rf_ws("fell [sharply | ]{if=\"fl\"}—then"), "fell—then")
  expect_identical(rf_ws("fell [sharply | ]{if=\"fl\"}” he said"), "fell” he said")
  expect_identical(rf_ws("a [x | ]{if=\"fl\"}’s"), "a’s")
  expect_identical(rf_ws("fell [sharply | ]{if=\"fl\"}]"), "fell]")
  expect_identical(rf_ws("[fell [sharply | ]{if=\"fl\"}](u)"), "[fell](u)")
  # controls: the older characters, and the span printing
  expect_identical(rf_ws("fell [sharply | ]{if=\"fl\"}."), "fell.")
  expect_identical(rf_ws("fell [sharply | ]{if=\"fl\"})"), "fell)")
  expect_identical(rf_ws("fell [sharply | ]{if=\"tr\"}—then"), "fell sharply—then")
})

test_that("review F #B: a straight quote is not in the list, the space stays (ruling B)", {
  expect_identical(rf_ws("a [x | ]{if=\"fl\"}\"q"), "a \"q")
  expect_identical(rf_ws("a [x | ]{if=\"fl\"}'s"), "a 's")
})

# ---- D. level on any span ----------------------------------------------------------

test_that("review F #D: a level key on an n, sign or list span is a construct error (ruling D)", {
  expect_error(rf_ws("[none | # | #]{list=\"v3\" level=\"warn\"}"), class = "weft_construct_error")
  expect_error(rf_ws("[# unit | # units]{n=\"2\" level=\"warn\"}"), class = "weft_construct_error")
  expect_error(rf_ws("[up | down | flat]{sign=\"2\" level=\"warn\"}"), class = "weft_construct_error")
  # controls: the same spans without the key; and the if span's ruling
  expect_identical(rf_ws("[none | # | #]{list=\"v3\"}"), "a, b and c")
  expect_error(rf_ws("[met | not met]{if=\"tr\" level=\"warn\"}"), class = "weft_construct_error")
})

# ---- F. serial_comma with sep -------------------------------------------------------

test_that("review F #F: with serial_comma on and a sep key, the separator before the last joiner is the sep (1.4.17; ruling F)", {
  cfg <- function(src) {
    res <- rf_knit(c(src), front = c("weft:", "  serial_comma: true"),
                   code = "v3 <- c('a', 'b', 'c')")
    expect_false(res$failed, label = res$message)
    res$text
  }
  txt <- paste(cfg("S `r v3`{.and sep=\"; \"} E."), collapse = "\n")
  expect_match(txt, "S a; b; and c E.", fixed = TRUE)
})

# ---- I. a matrix as a list governor ---------------------------------------------------

test_that("review F #I: a matrix or array as a list governor is a no value failure, as a data frame is (ruling I)", {
  expect_error(rf_ws("[none | # | #]{list=\"matrix(1:4, 2)\"}"), class = "weft_no_value")
  expect_error(rf_ws("[none | # | #]{list=\"array(1:8, c(2, 2, 2))\"}"), class = "weft_no_value")
  # controls
  expect_error(rf_ws("[none | # | #]{list=\"data.frame(a = 1)\"}"), class = "weft_no_value")
  expect_identical(rf_ws("[none | # | #]{list=\"1:4\"}"), "1, 2, 3 and 4")
})

# ---- K. where the zero rule reaches ------------------------------------------------------

test_that("review F #K: the zero rule reaches .pairs, and not about(), of_n() or .sci (ruling 1, 5, K)", {
  p <- rf_catch(weft::weft_str("`r c(a = 0.04, b = 0.03)`{.pairs}"))
  expect_length(p$zero, 1L)                                  # one per construct
  expect_no_warning(weft::weft_str("`r 0.04`{.sci}"))
  expect_no_warning(weft::about(0.52))
  expect_no_warning(weft::of_n(3, 10, "site", "sites"))
})

test_that("review F #K: one warned check per call even when several numbers of a ci() or .range print as zero (ruling K)", {
  expect_length(rf_catch(weft::ci(0.01, 0.002, 0.03))$zero, 1L)   # three numbers print as zero
  expect_length(rf_catch(weft::fmt_range(c(0.01, 0.04)))$zero, 1L)  # two do
})
