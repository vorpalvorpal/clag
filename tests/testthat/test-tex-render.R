# Package P2 of design 9, the knit half (dev/design-9.md TX1, TX3 "the resolver passes target = tex",
# TX9, TX10, TX11, weft_str()). Each document is knitted in this process with knitr::knit()
# (no Pandoc, no Quarto), through the helpers render_rmd() (helper-render.R) and d2_render()
# (helper-2d.R), so what is read is the text weft wrote and the ledger it kept.
# P1 supplies the TeX forms themselves (test-tex-target*.R); here only where they are used.
# Tests named "(control)" pin today's output and pass before the feature exists.
# Rule 1.4.22 of the design reads 1.4.23.

d2_need()

TX_VARS <- paste(
  "v <- 0.123; n <- -1234567.89; x <- 1234567; pv <- 0.03; rg <- c(1.23, 3.45)",
  "u5 <- weft::u(5, 'mg/L'); va <- 0.123; vb <- 0.123; vc <- 0.123; vd <- 0.123",
  sep = "; ")

tx_knit <- function(lines, draft = FALSE, ...) {
  render_rmd(lines, code = TX_VARS, format = "knit", in_process = TRUE,
             env = c(WEFT_DRAFT = if (draft) "1" else NA_character_, WEFT_COLLECT = NA_character_), ...)
}

tx_md <- function(res) unesc(res$md)

# ---- TX1 and TX3: constructs in math are formatted for TeX ----------------------------------------

TX_DOC <- c(
  "$a = `r v`{.pct}$ end.",
  "",
  "$a = `r n`{.num}$ and $b = `r x`{.sci}$ end.",
  "",
  "$$ `r pv`{.p} $$",
  "",
  "\\(c = `r rg`{.range}\\) and \\[d = `r v`{.pct .plus}\\]",
  "",
  "\\begin{align}",
  "a &= `r n`{.num} \\\\",
  "b &= `r x`{.sci}",
  "\\end{align}",
  "",
  "\\begin{tabular}{l}",
  "`r v`{.pct}",
  "\\end{tabular}",
  "",
  "```{=latex}",
  "\\textbf{`r v`{.pct}}",
  "```",
  "",
  "")

# the constructs that are not in math or raw LaTeX: the same knit as today
TX_CTRL_DOC <- c(
  "```{=typst}",
  "`r v`{.pct}",
  "```",
  "",
  "Prose `r v`{.pct} and `r n`{.num} and `r x`{.sci} here.",
  "",
  "Bare $e = `r v`$ and $f = `r fmt_pct(v)`$ here.",
  "")

tx_ctrl <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- tx_knit(TX_CTRL_DOC)
    cache
  }
})

tx_doc <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- tx_knit(TX_DOC)
    cache
  }
})

tx_has <- function(res, what) expect_true(grepl(what, tx_md(res), fixed = TRUE), label = what)

test_that("TX3: the knit of a document with constructs in math finishes", {
  res <- tx_doc()
  expect_false(res$failed, label = res$message)
})

test_that("TX1, TX3: inline math gets the TeX form: a percentage is written with `\\%`", {
  tx_has(tx_doc(), "$a = 12.3\\%$ end.")
})

test_that("TX1, TX3: inline math gets the TeX form: `{,}` marks and a minus sign, and `\\times 10^{}`", {
  tx_has(tx_doc(), "$a = -1{,}234{,}567.9$ and $b = 1.2 \\times 10^{6}$ end.")
})

test_that("TX1, TX3: display math gets the TeX form (a p value)", {
  tx_has(tx_doc(), "$$ p = 0.030 $$")
})

test_that("TX1, TX3: in an .Rmd the \\(...\\) and \\[...\\] forms are math and get the TeX form", {
  tx_has(tx_doc(), "\\(c = 1.2\\ \\text{to}\\ 3.5\\)")
  tx_has(tx_doc(), "\\[d = +12.3\\%\\]")
})

test_that("TX1, TX3: a math environment gets the TeX form, line by line", {
  tx_has(tx_doc(), "a &= -1{,}234{,}567.9 \\\\")
  tx_has(tx_doc(), "b &= 1.2 \\times 10^{6}\n\\end{align}")
})

test_that("TX3: a construct in raw LaTeX is formatted for TeX and wrapped in \\ensuremath{}", {
  tx_has(tx_doc(), "\\begin{tabular}{l}\n\\ensuremath{12.3\\%}\n\\end{tabular}")
})

test_that("TX3: a construct in a {=latex} fence is formatted for TeX and wrapped in \\ensuremath{}", {
  tx_has(tx_doc(), "```{=latex}\n\\textbf{\\ensuremath{12.3\\%}}\n```")
})

test_that("TX1 (control): a {=typst} fence keeps rule 1.1.10 and prints markdown", {
  tx_has(tx_ctrl(), "```{=typst}\n12.3%\n```")
})

test_that("TX1 (control): the same values in prose print exactly as they do today", {
  res <- tx_ctrl()
  expect_false(res$failed, label = res$message)
  expect_match(tx_md(res), "Prose 12.3% and \u22121,234,567.9 and 1.2 \u00d7 10^6^ here.", fixed = TRUE)
})

test_that("TX11 (control), 1.1.8: a bare value in math prints as stock prints it, and so does a bare fmt_*() (D75)", {
  tx_has(tx_ctrl(), "Bare $e = 0.123$ and $f = 12.3%$ here.")
})

# ---- TX9: markers --------------------------------------------------------------------------------

tx_line_of <- function(res, k) res$offset + k

test_that("TX9: a failure inside math is a marker wrapped in \\text{} in draft mode", {
  res <- tx_knit(c("$a = `r NA_real_`{.num}$ end.", "", "$$ b = `r NA_real_`{.pct} $$", ""), draft = TRUE)
  md <- tx_md(res)
  expect_match(md, sprintf("$a = \\text{<<weft: no value, line %d>>}$ end.", tx_line_of(res, 1L)), fixed = TRUE)
  expect_match(md, sprintf("$$ b = \\text{<<weft: no value, line %d>>} $$", tx_line_of(res, 3L)), fixed = TRUE)
})

test_that("TX9 (control): the same failure in prose is the marker as it is today", {
  res <- tx_knit(c("Prose `r NA_real_`{.num} end.", ""), draft = TRUE)
  expect_match(tx_md(res), sprintf("Prose <<weft: no value, line %d>> end.", tx_line_of(res, 1L)), fixed = TRUE)
})

test_that("TX3, TX9: in raw LaTeX the whole output, a marker included, is wrapped in \\ensuremath{}", {
  res <- tx_knit(c("\\begin{tabular}{l}", "`r NA_real_`{.num}", "\\end{tabular}", ""), draft = TRUE)
  expect_match(tx_md(res), sprintf("\\ensuremath{\\text{<<weft: no value, line %d>>}}", tx_line_of(res, 2L)), fixed = TRUE)
})

test_that("TX9: the failure in math is collected as it is today, with the line of the construct", {
  res <- tx_knit(c("Some words.", "", "$a = `r NA_real_`{.num}$ end.", ""), draft = TRUE)
  f <- res$knit$failures
  expect_identical(nrow(f), 1L)
  expect_identical(f$kind, "no value")
  expect_identical(f$line, tx_line_of(res, 3L))
})

test_that("TX9 (reading): a construct error in math is a marker wrapped in \\text{} too (draft mode)", {
  # READING: "under TeX every marker is written \text{<<weft: KIND, line N>>}", a construct error's included
  res <- tx_knit(c("$a = `r v`{.word}$ end.", ""), draft = TRUE)
  expect_match(tx_md(res), sprintf("$a = \\text{<<weft: construct error, line %d>>}$ end.", tx_line_of(res, 1L)), fixed = TRUE)
})

test_that("TX2, E95: a class with no TeX form in math stops a non-draft knit, class weft_construct_error, with the message", {
  res <- tx_knit(c("$a = `r v`{.word}$ end.", ""))
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message,
               "`.word` cannot be used inside math: it prints words, and a formula holds numbers.", fixed = TRUE)
  expect_match(res$message, "(rule 5.2.6)", fixed = TRUE)
})

test_that("TX2, E96 and E97: the construct errors of emphasis and lists in a math environment, class weft_construct_error", {
  res <- tx_knit(c("\\begin{align}", "a &= `r v`{.strong}", "\\end{align}", ""))
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "`.strong` cannot be used inside math: it is markdown emphasis, and math is TeX.", fixed = TRUE)
  res <- tx_knit(c("\\begin{tabular}{l}", "`r v`{.and}", "\\end{tabular}", ""))
  expect_true(res$failed)
  expect_match(res$message, "`.and` cannot be used inside raw LaTeX: it joins items into a phrase or a list.", fixed = TRUE)
})

# ---- TX10: the ledger --------------------------------------------------------------------------

TX_LEDGER_CTRL <- c("Prose `r vc`{.pct} here.", "")

TX_LEDGER_DOC <- c(
  "A formula $a = `r va`{.pct}$ here.",
  "",
  "\\begin{tabular}{l}",
  "`r vb`{.pct}",
  "\\end{tabular}",
  "",
  "```{r fig, fig.cap='Ratio $a = `r vd`{.pct}$ overall.'}",
  "plot(1)",
  "```",
  "")

tx_ledger <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- d2_render(TX_LEDGER_DOC, code = TX_VARS)
    cache
  }
})

test_that("TX10 (control): a value in prose has context 'prose' and the markdown text, as it does today", {
  e <- d2_one(d2_ledger(d2_render(TX_LEDGER_CTRL, code = TX_VARS)), kind = "value", expr = "vc")
  expect_identical(e$context, "prose")
  expect_identical(e$text, "12.3%")
})

test_that("TX10: a value in math has context 'math' and text exactly the TeX weft wrote", {
  e <- d2_one(d2_ledger(tx_ledger()), kind = "value", expr = "va")
  expect_identical(e$context, "math")
  expect_identical(e$text, "12.3\\%")
})

test_that("TX10: a value in raw LaTeX has context 'tex' and text with the \\ensuremath{} wrapper", {
  e <- d2_one(d2_ledger(tx_ledger()), kind = "value", expr = "vb")
  expect_identical(e$context, "tex")
  expect_identical(e$text, "\\ensuremath{12.3\\%}")
})

test_that("TX10: the key of an entry is unchanged (file, section, kind and expr), and the section is kept", {
  es <- d2_ledger(tx_ledger())
  a <- d2_one(es, kind = "value", expr = "va")
  b <- d2_one(es, kind = "value", expr = "vb")
  expect_identical(a$kind, "value")
  expect_identical(a$expr, "va")
  expect_identical(a$section, b$section)
  expect_identical(names(a), names(b))
})

test_that("TX10 (reading): a caption keeps its context 'caption'; a value in math in it is written as TeX", {
  # READING: "captions, front matter and weft_str keep their context": the construct in the caption
  # is math (the scanner says so), so its text is TeX while its context stays "caption"
  e <- d2_one(d2_ledger(tx_ledger()), kind = "value", expr = "vd")
  expect_identical(e$context, "caption")
  expect_identical(e$text, "12.3\\%")
})

# ---- TX11: sentence starts and typed units --------------------------------------------------------

test_that("TX11: a value in math is never a sentence start; a value in prose after a full stop still is", {
  res <- tx_knit(c("Intro.", "", "$a = 1. `r v`{.num}$ more.", "", "Second. `r v`{.num} after.", ""))
  expect_false(res$failed, label = res$message)
  ss <- res$knit$sentence_starts
  expect_identical(nrow(ss), 1L)
  expect_identical(ss$line, tx_line_of(res, 5L))
})

test_that("TX11: a value in a math environment, a raw environment or a {=latex} fence is no sentence start", {
  res <- tx_knit(c("Intro.", "",
                   "\\begin{align}", "a = 1.", "`r v`{.num}", "\\end{align}", "",
                   "\\begin{tabular}{l}", "x.", "`r v`{.num}", "\\end{tabular}", "",
                   "```{=latex}", "y.", "`r v`{.num}", "```", ""))
  expect_false(res$failed, label = res$message)
  expect_identical(nrow(res$knit$sentence_starts), 0L)
})

test_that("TX11 (control): a unit typed after a value in prose is noted (rule 4.4.10)", {
  res <- tx_knit(c("Prose `r u5`{.num} mg/L here.", ""))
  w <- res$knit$warnings
  expect_identical(sum(w$kind == "unit warning"), 1L)
})

test_that("TX11: a unit typed after a value in math is not checked (typed_after() does not run)", {
  res <- tx_knit(c("\\begin{align}", "a = `r u5`{.num} mg/L", "\\end{align}", ""))
  expect_false(res$failed, label = res$message)
  w <- res$knit$warnings
  expect_identical(sum(w$kind == "unit warning"), 0L)
})

# ---- weft_str() ----------------------------------------------------------------------------------

test_that("weft_str: math inside the string already gets the TeX form", {
  v <- 0.123
  expect_identical(as.character(weft::weft_str("$a = `r v`{.pct}$")), "$a = 12.3\\%$")
})

test_that("weft_str (control): the same value outside math prints markdown", {
  v <- 0.123
  expect_identical(as.character(weft::weft_str("a = `r v`{.pct}")), "a = 12.3%")
})
