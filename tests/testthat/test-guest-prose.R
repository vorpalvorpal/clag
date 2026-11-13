# Stage 5b: guest reads in prose and in the places weft evaluates (G9 to G17a).
# Documents are knitted in this process (k5(), helper-5.R) with Python chunks
# through knitr's python engine; none of them has library(reticulate). Draft
# mode (WEFT_DRAFT=1) is used where the markers are looked at, since a failing
# render writes no output (9.4.2); the report is looked at in a render that
# fails. Each document uses names of its own (t_g5_...).

PY_MAIN <- c(
  "import datetime, decimal",
  "t_g5_depth = 3.14159",
  "t_g5_n = 12",
  "t_g5_b53 = 2**53 + 1",
  "t_g5_b70 = 2**70",
  "t_g5_cfg = {'depth': 2.5, 'inner': {'depth': 7}}",
  "t_g5_sites = ['a', 'b', 'c']",
  "t_g5_mixed = [1, 'a']",
  "t_g5_none = None",
  "t_g5_s = 'caf\\u00e9'",
  "t_g5_d = datetime.date(2026, 11, 13)",
  "t_g5_slope = 0.5",
  "t_g5_dec16 = decimal.Decimal('1.234567890123456')",
  "def t_g5_f(k):",
  "    return k * 2"
)

PROSE <- c(
  V01 = "`r py$t_g5_depth`{.num} x",
  V02 = "`r py[[\"t_g5_depth\"]]`{.num} x",
  V03 = "`r py$t_g5_cfg$depth`{.num} x",
  V04 = "`r py[[\"t_g5_cfg\"]][[\"depth\"]]`{.num} x",
  V05 = "`r py[[\"t_g5_cfg\"]]$inner$depth`{.num} x",
  V06 = "`r reticulate::py$t_g5_cfg$depth`{.num} x",
  V07 = "`r py_value(\"t_g5_cfg\", \"depth\")`{.num} x",
  V08 = "`r weft::py_value(\"t_g5_depth\")`{.num} x",
  V09 = "`r py$t_g5_b53`{.num} x",
  V10 = "`r py$t_g5_b70`{.num} x",
  V11 = "`r py$t_g5_sites`{.and} x",
  V12 = "`r py$t_g5_mixed`{.and} x",
  V13 = "`r py$t_g5_n > 10` x",
  V14 = "`r claim(py$t_g5_n, . > 10)` x",
  V15 = "`r length(py$t_g5_sites)`{.word} x",
  V16 = "`r py$t_g5_sites[2]` x",
  V17 = "`r py$t_g5_none`{.num} x",
  V18 = "`r py$t_g5_d`{.date} x",
  V19 = "`r as.Date(\"2026-11-13\")`{.date} x",
  V20 = "`r py$t_g5_s` x",
  V21 = "`r py$t_g5_b53 > 0` x",
  V22 = "`r py$t_g5_cfg$zzz`{.num} x",
  V23 = "`r py$t_g5_nosuch_zz`{.num} x",
  V24 = "`r py$t_g5_dec16`{.num} x",
  V25 = "`r py$t_g5_f(2)`{.num} x",
  V26 = "`r py$t_g5_f(2)` x",
  V27 = "`r py_value(\"t_g5_b53\")`{.num} x",
  V28 = "`r py[[\"t_g5_cfg\"]]$zzz`{.num} x"
)

# one knit for the main document (Python start-up and knitting are slow)
prose_main <- function() {
  if (is.null(.w5$prose)) .w5$prose <- k5_cases(PROSE, py = PY_MAIN, draft = TRUE)
  .w5$prose
}

test_that("G9: every guest-read form in a value prints a guarded value", {
  res <- prose_main()
  expect_false(res$failed, label = res$message)
  expect_identical(res$line("V01"), "V01 3.1 x")
  expect_identical(res$line("V02"), "V02 3.1 x")
  expect_identical(res$line("V03"), "V03 2.5 x")
  expect_identical(res$line("V04"), "V04 2.5 x")
  expect_identical(res$line("V05"), "V05 7 x")
  expect_identical(res$line("V06"), "V06 2.5 x")
  expect_identical(res$line("V07"), "V07 2.5 x")
  expect_identical(res$line("V08"), "V08 3.1 x")
})

test_that("G9: the read is taken whole; R then does what it does with the R form", {
  res <- prose_main()
  expect_identical(res$line("V11"), "V11 a, b and c x")
  expect_identical(res$line("V13"), "V13 TRUE x")
  expect_identical(res$line("V14"), "V14 12 x")
  expect_identical(res$line("V15"), "V15 three x")
  expect_identical(res$line("V16"), "V16 b x")
})

test_that("G9: a date read prints as the same R Date does", {
  res <- prose_main()
  v18 <- sub("^V18 ", "", res$line("V18"))
  v19 <- sub("^V19 ", "", res$line("V19"))
  expect_identical(v18, v19)
  expect_false(grepl("<<weft", v18, fixed = TRUE))
})

test_that("G9 + 1.11.5: a string with non-ASCII text is read and printed as it is", {
  res <- prose_main()
  expect_identical(res$line("V20"), "V20 caf\u00e9 x")
})

test_that("G9 + G12: {.num} on 2**53 + 1 is a collected value error with the exact detail, never 1", {
  res <- prose_main()
  expect_identical(res$line("V09"), paste("V09", res$marker("V09", "value error"), "x"))
  f <- res$fail("V09")
  expect_equal(nrow(f), 1L)
  expect_identical(f$kind, "value error")
  expect_identical(msg5(f$detail), m1("`py$t_g5_b53`", "9007199254740993"))
  expect_false(any(grepl("^V09 1\\b", res$text)))
  expect_identical(res$line("V10"), paste("V10", res$marker("V10", "value error"), "x"))
  expect_identical(msg5(res$fail("V10")$detail), m1("`py$t_g5_b70`", "1180591620717411303424"))
})

test_that("G12: every refusal in a construct is a collected value error with its message", {
  res <- prose_main()
  expect_identical(res$line("V12"), paste("V12", res$marker("V12", "value error"), "x"))
  expect_identical(msg5(res$fail("V12")$detail), m3("`py$t_g5_mixed`", "list", "integer, string"))
  expect_identical(res$line("V24"), paste("V24", res$marker("V24", "value error"), "x"))
  expect_identical(msg5(res$fail("V24")$detail), m2("`py$t_g5_dec16`", "1.234567890123456", 16L))
  expect_identical(res$line("V27"), paste("V27", res$marker("V27", "value error"), "x"))
  expect_identical(msg5(res$fail("V27")$detail), m1("`py_value(\"t_g5_b53\")`", "9007199254740993"))
})

test_that("G9 + G12: a refusal inside a larger expression is the whole read refused", {
  res <- prose_main()
  expect_identical(res$line("V21"), paste("V21", res$marker("V21", "value error"), "x"))
  expect_identical(msg5(res$fail("V21")$detail), m1("`py$t_g5_b53`", "9007199254740993"))
})

test_that("G12: a missing guest value (None) in a formatter is \"no value\" (1.3.4)", {
  res <- prose_main()
  expect_identical(res$line("V17"), paste("V17", res$marker("V17", "no value"), "x"))
  expect_identical(res$fail("V17")$kind, "no value")
})

test_that("G12 + M13/M14: a read that cannot be done is a collected \"no value\" with `error evaluating`", {
  res <- prose_main()
  expect_identical(res$line("V22"), paste("V22", res$marker("V22", "no value"), "x"))
  f <- res$fail("V22")
  expect_identical(f$kind, "no value")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(m14("py$t_g5_cfg$zzz", "py$t_g5_cfg", "zzz"), msg5(f$detail), fixed = TRUE))
  expect_identical(res$line("V23"), paste("V23", res$marker("V23", "no value"), "x"))
  f <- res$fail("V23")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(m13("py$t_g5_nosuch_zz", "t_g5_nosuch_zz"), msg5(f$detail), fixed = TRUE))
  f <- res$fail("V28")
  expect_true(grepl(m14("py[[\"t_g5_cfg\"]]$zzz", "py[[\"t_g5_cfg\"]]", "zzz"), msg5(f$detail), fixed = TRUE))
})

test_that("G9: no library(reticulate) is needed, and none is attached", {
  res <- k5_cases(PROSE[c("V01", "V09")], py = PY_MAIN, draft = TRUE)
  expect_false(res$searched)
})

# ---- G10: where py is not Python ---------------------------------------------------

test_that("G10: an R object named py is not a guest read", {
  res <- k5_cases(c(G1 = "`r py$x`{.num} x", G2 = "`r py[[\"x\"]]`{.num} x"),
                  before = c("```{r}", "py <- list(x = 3)", "```", ""),
                  py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(res$line("G1"), "G1 3 x")
  expect_identical(res$line("G2"), "G2 3 x")
  expect_equal(nrow(res$failures), 0L)
})

test_that("G10: a py bound to Python's main module is still a guest read", {
  res <- k5_cases(c(G3 = "`r py$t_g5_b53`{.num} x", G4 = "`r py$t_g5_depth`{.num} x"),
                  before = c("```{r}", "py <- reticulate::import_main()", "```", ""),
                  py = PY_MAIN, draft = TRUE)
  expect_identical(res$line("G3"), paste("G3", res$marker("G3", "value error"), "x"))
  expect_identical(res$line("G4"), "G4 3.1 x")
})

test_that("G10: py$f(2), a call whose function is a read, is left to reticulate", {
  res <- k5_cases(PROSE[c("V25", "V26")], py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(res$line("V25"), "V25 4 x")
  expect_identical(res$line("V26"), "V26 4 x")
  expect_equal(nrow(res$failures), 0L)
})

# ---- G11: bare values ---------------------------------------------------------------

test_that("G11: a bare guest read prints as stock knitr prints it; None prints NA", {
  res <- k5_cases(c(B1 = "`r py$t_g5_n` x", B2 = "`r py$t_g5_b53` x",
                    B3 = "`r py$t_g5_none` x", B4 = "`r py$t_g5_depth` x"),
                  py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(res$line("B1"), "B1 12 x")
  expect_identical(res$line("B3"), "B3 NA x")
  expect_identical(res$line("B4"), "B4 3.14159 x")
})

test_that("G11: a bare 2**53 + 1 is a collected value error with the marker", {
  res <- k5_cases(c(B2 = "`r py$t_g5_b53` x"), py = PY_MAIN, draft = TRUE)
  expect_identical(res$line("B2"), paste("B2", res$marker("B2", "value error"), "x"))
  f <- res$fail("B2")
  expect_identical(f$kind, "value error")
  expect_identical(msg5(f$detail), m1("`py$t_g5_b53`", "9007199254740993"))
})

test_that("G11: a bare read of a name that is not defined stops the knit with M13", {
  res <- k5_cases(c(B5 = "`r py$t_g5_nosuch_zz` x"), py = PY_MAIN)
  expect_true(res$failed)
  expect_true(grepl(m13("py$t_g5_nosuch_zz", "t_g5_nosuch_zz"), res$message, fixed = TRUE))
})

# ---- the report: one report, the render fails ---------------------------------------

test_that("G12 + 2.6.2: a value error fails the render once, with one report that names the line and the message", {
  res <- k5_cases(c(F1 = "`r py$t_g5_b53`{.num} x", F2 = "Fine `r py$t_g5_n`{.num} x"), py = PY_MAIN)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  expect_equal(nrow(res$failures), 1L)
  expect_identical(res$failures$kind, "value error")
  expect_equal(res$failures$line, unname(res$at["F1"]))
  expect_match(res$message, sprintf("doc\\.Rmd:%d\\b", res$at[["F1"]]))
  expect_true(grepl("is the Python int 9007199254740993", res$message, fixed = TRUE))
  expect_length(regmatches(res$message, gregexpr("weft: [0-9]+ failures?", res$message))[[1]], 1L)
  expect_false(grepl("weft: 2 ", res$message, fixed = TRUE))
})

# ---- G14: Python is not there ----------------------------------------------------------

test_that("G14 seam: without reticulate a value is a collected \"no value\" with M15", {
  withr::local_options(weft.reticulate = FALSE)
  res <- k5_cases(c(N1 = "`r py$t_g5_x`{.num} x"), draft = TRUE, need_python = FALSE)
  expect_identical(res$line("N1"), paste("N1", res$marker("N1", "no value"), "x"))
  f <- res$fail("N1")
  expect_identical(f$kind, "no value")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(m15("py$t_g5_x"), msg5(f$detail), fixed = TRUE))
})

test_that("G14 seam: without reticulate a bare read stops the knit with M15", {
  withr::local_options(weft.reticulate = FALSE)
  res <- k5_cases(c(N2 = "`r py$t_g5_x` x"), need_python = FALSE)
  expect_true(res$failed)
  expect_true(grepl(m15("py$t_g5_x"), res$message, fixed = TRUE))
})

test_that("G14: when reticulate cannot start Python a value is a collected \"no value\" with M16 (fresh process)", {
  env <- c(RETICULATE_PYTHON = "/nonexistent/weft-no-python")
  res <- k5_fresh(c("N3 `r py$t_g5_x`{.num} x"), env = env, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "N3 <<weft: no value, line [0-9]+>> x")
  res <- k5_fresh(c("N3 `r py$t_g5_x`{.num} x"), env = env)
  expect_true(res$failed)
  expect_true(grepl(m16_start("py$t_g5_x"), msg5(res$message), fixed = TRUE))
})

test_that("G14: when reticulate cannot start Python a bare read stops the knit with M16 (fresh process)", {
  env <- c(RETICULATE_PYTHON = "/nonexistent/weft-no-python")
  res <- k5_fresh(c("N4 `r py$t_g5_x` x"), env = env)
  expect_true(res$failed)
  expect_true(grepl(m16_start("py$t_g5_x"), msg5(res$message), fixed = TRUE))
})

# ---- G15: R-only documents ------------------------------------------------------------

test_that("G15: a document with no Python chunk and no guest read never loads reticulate (fresh process)", {
  res <- render_rmd(
    c("R-only `r 3.14159`{.num} m and `r 2 + 3` bare.", "",
      "```{r, echo=FALSE, results='asis'}",
      "cat(\"RETLOADED:\", \"reticulate\" %in% loadedNamespaces(), \"\\n\")",
      "```"),
    in_process = FALSE, format = "knit")
  expect_false(res$failed, label = res$message)
  expect_true("R-only 3.1 m and 5 bare." %in% trimws(res$text))
  expect_true("RETLOADED: FALSE" %in% trimws(res$text))
})

# ---- G16: Python's state is left alone ---------------------------------------------------

test_that("G16: after a refused read of 2**70 in prose the next Python chunk runs and the knit reaches its end", {
  lines <- c(
    "First `r py$t_g5_b70`{.num} x", "",
    "```{python, include=FALSE}",
    "t_g5_after = 1 + 1",
    "```", "",
    "AFTER `r py$t_g5_after` x", "",
    "END of the document", "")
  res <- k5(lines, py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true("AFTER 2 x" %in% res$text)
  expect_true("END of the document" %in% res$text)
  expect_equal(nrow(res$failures), 1L)
  expect_identical(res$failures$kind, "value error")
  expect_identical(reticulate::py_eval("1 + 1"), 2L)
  expect_false(reticulate::py_eval("'weft_guest' in globals()"))
  res2 <- k5(lines, py = PY_MAIN)
  expect_true(res2$failed)
  expect_true("weft_failures" %in% res2$class)
  expect_equal(nrow(res2$failures), 1L)
  expect_false(grepl("OverflowError", res2$message, fixed = TRUE))
})

# ---- py_value() in R chunk code ------------------------------------------------------------

test_that("G4 + G8: py_value() is on the search path in a knit and reads in R chunk code", {
  res <- k5_cases(
    c(R1 = "`r r_n`{.num} x", R2 = "`r r_cfg`{.num} x"),
    before = c("```{r}", "r_n <- py_value(\"t_g5_n\")", "r_cfg <- weft::py_value(\"t_g5_cfg\", \"depth\")", "```", ""),
    py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(res$line("R1"), "R1 12 x")
  expect_identical(res$line("R2"), "R2 2.5 x")
})

test_that("G8: py_value() of 2**53 + 1 in R chunk code stops the chunk with the message", {
  res <- k5(c("```{r}", "x <- py_value(\"t_g5_b53\")", "```", "", "After."), py = PY_MAIN)
  # knitr::knit() alone keeps going after a chunk error and prints it (rmarkdown::render() would stop), so
  # the message is looked for in the failure message or in the chunk's printed error, white space squashed
  seen <- gsub("\\s+", " ", gsub("\n## ?", " ", paste(c(res$message, res$text), collapse = "\n")))
  expect_true(grepl(m1("`py_value(\"t_g5_b53\")`", "9007199254740993"), seen, fixed = TRUE))
  expect_false(any(grepl("After 1", res$text, fixed = TRUE)))
})

# ---- G17a: other weft-evaluated places -------------------------------------------------------

test_that("G17a: a caption construct on an R chunk reads Python values by G9", {
  lines <- c(
    "```{r, echo=FALSE, fig.cap=\"Depth `r py$t_g5_depth`{.num} m.\"}",
    "plot(1)",
    "```", "",
    "```{r, echo=FALSE, fig.cap=\"Big `r py$t_g5_b53`{.num} m.\"}",
    "plot(2)",
    "```", "")
  res <- k5(lines, py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true(any(grepl("Depth 3.1 m.", res$text, fixed = TRUE)))
  expect_false(any(grepl("Big 1 m.", res$text, fixed = TRUE)))
  f <- res$failures
  expect_true(any(f$kind == "value error"))
  expect_true(any(vapply(f$detail, function(d) # a failure in a chunk option names the option first ("fig.cap: ..."), as every such failure does
    identical(sub("^fig\\.cap: ", "", msg5(d)), m1("`py$t_g5_b53`", "9007199254740993")), NA)))
})

test_that("G17a: weft_str() in an R chunk reads Python values by G9 and collects its failures", {
  lines <- c(
    "```{r, echo=FALSE, results='asis'}",
    "cat(\"WSR:\", weft::weft_str(\"[rose | fell]{if=\\\"py$t_g5_slope > 0\\\"}\"), \"\\n\")",
    "cat(\"WSD:\", weft::weft_str(\"`r py$t_g5_depth`{.num} m\"), \"\\n\")",
    "cat(\"WSB:\", weft::weft_str(\"`r py$t_g5_b53`{.num} m\"), \"\\n\")",
    "```", "")
  res <- k5(lines, py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true("WSR: rose" %in% res$text)
  expect_true("WSD: 3.1 m" %in% res$text)
  expect_false(any(grepl("^WSB: 1 m", res$text)))
  expect_true(any(vapply(res$failures$detail,
                         function(d) # a failure in a chunk option names the option first ("fig.cap: ..."), as every such failure does
    identical(sub("^fig\\.cap: ", "", msg5(d)), m1("`py$t_g5_b53`", "9007199254740993")), NA)))
})

test_that("G17a: outside a knit weft_str() stops at once with the value error", {
  skip_if_no_python()
  py_set(t_g5_ws1 = "2**53 + 1", t_g5_ws2 = "3.14159")
  expect_refused5(weft_str("`r py$t_g5_ws1`{.num}"), m1("`py$t_g5_ws1`", "9007199254740993"))
  expect_identical(as.character(weft_str("`r py$t_g5_ws2`{.num} m")), "3.1 m")
})

test_that("G17a: x <- py$b53 in R chunk code is reticulate's conversion, pinned as the documented limit", {
  lines <- c(
    "```{r, echo=FALSE, results='asis'}",
    "x <- reticulate::py$t_g5_b53",
    "cat(\"LIMIT:\", x, \"\\n\")",
    "```", "")
  res <- k5(lines, py = PY_MAIN, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true("LIMIT: 1" %in% res$text)
})

# ---- G17: Quarto -------------------------------------------------------------------------------

test_that("G17: under Quarto with engine: knitr a guest read is guarded the same way", {
  skip_if_no_quarto()
  skip_if_no_python()
  py <- reticulate::py_config()$python
  env <- c(RETICULATE_PYTHON = py, RETICULATE_USE_MANAGED_VENV = "no")
  pyc <- c("```{python}", "#| include: false", "t_g5_depth = 3.14159", "t_g5_b53 = 2**53 + 1", "```", "")
  bad <- render_qmd(c(pyc, "Big `{r} py$t_g5_b53`{.num} m."), env = env)
  expect_true(bad$failed)
  expect_true(grepl("9007199254740993", bad$message, fixed = TRUE))
  expect_true(grepl("beyond", bad$message, fixed = TRUE))
  good <- render_qmd(c(pyc, "Depth `{r} py$t_g5_depth`{.num} m."), env = env)
  expect_false(good$failed, label = substr(good$message, 1, 300))
  expect_true(any(grepl("Depth 3.1 m.", good$text, fixed = TRUE)))
})
