# Package P3 of design 9: the TeX forms through a real render (dev/design-9.md, section 4, "test-tex-render.R"
# of P3; rule 1.4.22 of the design reads 1.4.23). test-tex-render.R reads what knitr writes; here the
# document goes on through Quarto (HTML with MathJax and with KaTeX, PDF) and through rmarkdown, and what is
# read is the text each stage hands on and the TeX that the output holds. Nothing is asserted about how a
# browser or a TeX engine sets the formula, only that the TeX that weft wrote arrives as written: not
# escaped, not altered by Pandoc, and (in PDF) accepted by the engine.
# Slow: a Quarto render is some seconds, and the weft under test is installed once per session.
# Skips: no Quarto, no Pandoc, no TeX engine for the PDF.

TQ_VARS <- paste(
  "v <- 0.123; n <- -1234567.89; x <- 1234567; pv <- 0.03; rg <- c(1.23, 3.45)",
  "u5 <- weft::u(5, 'mg/L')", sep = "; ")

# the constructs the render has to carry: `$`, `$$`, an `align` environment, a {=latex} fence
TQ_BODY <- c(
  "Inline $a = `r v`{.pct}$ and $b = `r n`{.num}$ and $c = `r x`{.sci}$ and $d = `r u5`{.num}$.",
  "",
  "$$ `r pv`{.p} $$",
  "",
  "\\begin{align}",
  "a &= `r n`{.num} \\\\",
  "b &= `r rg`{.range}",
  "\\end{align}",
  "",
  "```{=latex}",
  "\\textbf{`r v`{.pct}}",
  "```",
  "")

tq_qmd <- function(formats) {
  c("---", "title: \"TeX\"", "engine: knitr", "format:", formats, "---", "",
    "```{r}", "#| include: false", "weft::weft_setup()", TQ_VARS, "```", "", TQ_BODY)
}

tq_dir <- function(lines, name = "doc.qmd") {
  dir <- normalizePath(tempfile("tq-"), mustWork = FALSE)
  dir.create(dir)
  dir <- normalizePath(dir)
  writeLines(lines, file.path(dir, name), useBytes = TRUE)
  dir
}

tq_skip_no_render <- function() {
  skip_if_no_quarto()
  skip_if_no_pandoc()
}

tq_read <- function(dir, name) {
  p <- file.path(dir, name)
  expect_true(file.exists(p), label = paste(name, "was written"))
  if (!file.exists(p)) return("")
  paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# the TeX held by the `math` spans of an HTML page, in order, with HTML's entities undone
tq_math <- function(html) {
  m <- regmatches(html, gregexpr('(?s)<span class="math (?:inline|display)">.*?</span>', html, perl = TRUE))[[1L]]
  m <- sub('(?s)^<span class="math (?:inline|display)">(.*)</span>$', "\\1", m, perl = TRUE)
  m <- gsub("&lt;", "<", m, fixed = TRUE)
  m <- gsub("&gt;", ">", m, fixed = TRUE)
  gsub("&amp;", "&", m, fixed = TRUE)
}

# the TeX each construct comes to, as weft writes it (the same for every renderer)
TQ_TEX <- c(
  inline_pct = "\\(a = 12.3\\%\\)",
  inline_num = "\\(b = -1{,}234{,}567.9\\)",
  inline_sci = "\\(c = 1.2 \\times 10^{6}\\)",
  inline_unit = "\\(d = 5\\,\\text{mg/L}\\)",
  display_p = "\\[ p = 0.030 \\]")
TQ_ALIGN <- c("a &= -1{,}234{,}567.9 \\\\", "b &= 1.2\\ \\text{to}\\ 3.5")

# ---- Quarto to HTML, with MathJax (the default) and with KaTeX ---------------------------------------------

tq_html <- local({
  cache <- list()
  function(method = "mathjax") {
    if (!is.null(cache[[method]])) return(cache[[method]])
    tq_skip_no_render()
    dir <- tq_dir(tq_qmd(c("  html:", "    keep-md: true", paste0("    html-math-method: ", method))))
    r <- qrender(dir, c("doc.qmd", "--to", "html"))
    cache[[method]] <<- c(r, list(dir = dir))
    cache[[method]]
  }
})

test_that("TQ1: Quarto renders the document with constructs in math to HTML", {
  r <- tq_html()
  expect_identical(r$status, 0L, label = r$log)
  expect_false(grepl("<<weft:", r$log, fixed = TRUE))
  expect_false(grepl("Could not convert TeX", r$log, fixed = TRUE))
})

test_that("TQ1: the markdown that Quarto hands to Pandoc holds the TeX forms, intact and unescaped", {
  r <- tq_html()
  md <- tq_read(r$dir, "doc.html.md")
  expect_match(md, "Inline $a = 12.3\\%$ and $b = -1{,}234{,}567.9$ and $c = 1.2 \\times 10^{6}$", fixed = TRUE)
  expect_match(md, "$d = 5\\,\\text{mg/L}$", fixed = TRUE)
  expect_match(md, "$$ p = 0.030 $$", fixed = TRUE)
  expect_match(md, "\\begin{align}\na &= -1{,}234{,}567.9 \\\\\nb &= 1.2\\ \\text{to}\\ 3.5\n\\end{align}", fixed = TRUE)
  expect_match(md, "```{=latex}\n\\textbf{\\ensuremath{12.3\\%}}\n```", fixed = TRUE)
  expect_false(grepl("{.pct}", md, fixed = TRUE))
})

test_that("TQ1: MathJax's HTML holds the TeX source of each formula as weft wrote it", {
  r <- tq_html()
  html <- tq_read(r$dir, "doc.html")
  expect_match(html, "mathjax", ignore.case = TRUE)
  m <- tq_math(html)
  for (k in c("inline_pct", "inline_num", "inline_sci", "inline_unit", "display_p")) {
    expect_true(TQ_TEX[[k]] %in% m, label = paste("a math span holds", TQ_TEX[[k]]))
  }
  align <- m[grepl("\\begin{align}", m, fixed = TRUE)]
  expect_length(align, 1L)
  for (ln in TQ_ALIGN) expect_true(grepl(ln, align, fixed = TRUE), label = paste("the align holds", ln))
})

test_that("TQ1: a {=latex} fence is not in the HTML, and the render does not fail over it", {
  html <- tq_read(tq_html()$dir, "doc.html")
  expect_false(grepl("ensuremath", html, fixed = TRUE))
})

test_that("TQ1: with KaTeX the page names KaTeX and holds the same TeX in the same spans", {
  r <- tq_html("katex")
  expect_identical(r$status, 0L, label = r$log)
  html <- tq_read(r$dir, "doc.html")
  expect_match(html, "katex", ignore.case = TRUE)
  # the span holds the TeX with or without the \( \) or \[ \] round it, whichever Pandoc writes for KaTeX
  m <- tq_math(html)
  for (k in c("inline_pct", "inline_num", "inline_sci", "inline_unit", "display_p")) {
    tex <- TQ_TEX[[k]]
    bare <- substr(tex, 3L, nchar(tex) - 2L)
    expect_true(bare %in% m || tex %in% m, label = paste("a math span holds", bare))
  }
  expect_true(any(grepl("\\text{to}", m, fixed = TRUE)))
})

# ---- Quarto to PDF ------------------------------------------------------------------------------------------

test_that("TQ2: Quarto compiles the TeX forms to PDF, and the .tex holds them as written", {
  tq_skip_no_render()
  skip_if_not(any(nzchar(Sys.which(c("pdflatex", "xelatex", "lualatex")))), "no TeX engine is installed")
  dir <- tq_dir(tq_qmd(c("  pdf:", "    keep-tex: true")))
  r <- qrender(dir, c("doc.qmd", "--to", "pdf"))
  if (!identical(r$status, 0L) && grepl("LaTeX Error: File|not found|Unable to find TinyTeX|No TeX", r$log)) {
    skip(paste("the TeX installation cannot build the document:", substr(r$log, 1, 300)))
  }
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(file.path(dir, "doc.pdf")))
  tx <- tq_read(dir, "doc.tex")
  for (k in c("inline_pct", "inline_num", "inline_sci", "inline_unit", "display_p")) {
    expect_true(grepl(TQ_TEX[[k]], tx, fixed = TRUE), label = paste("the .tex holds", TQ_TEX[[k]]))
  }
  expect_true(grepl(paste(c("\\begin{align}", TQ_ALIGN, "\\end{align}"), collapse = "\n"), tx, fixed = TRUE))
  expect_true(grepl("\\textbf{\\ensuremath{12.3\\%}}", tx, fixed = TRUE))
})

# ---- rmarkdown: `\(...\)` and `\[...\]` are math in an .Rmd ---------------------------------------------------

tq_rmd <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    skip_if_no_pandoc()
    body <- c("---", "title: \"TeX\"", "output: html_document", "---", "",
              "```{r setup, include=FALSE}", "weft::weft_setup()", TQ_VARS, "```", "",
              "Paren \\(c = `r rg`{.range}\\) and bracket \\[d = `r v`{.pct .plus}\\] and dollar $e = `r v`{.pct}$.",
              "", "\\begin{align}", "a &= `r n`{.num}", "\\end{align}", "")
    dir <- normalizePath(tempfile("tq-rmd-"), mustWork = FALSE)
    dir.create(dir)
    dir <- normalizePath(dir)
    writeLines(body, file.path(dir, "doc.Rmd"), useBytes = TRUE)
    lib <- weft_test_lib()
    vars <- c(WEFT_DRAFT = NA, WEFT_COLLECT = NA)
    if (nzchar(lib)) vars[["R_LIBS"]] <- paste(c(lib, .libPaths()), collapse = .Platform$path.sep)
    withr::local_envvar(vars)
    withr::local_dir(dir)
    log <- suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      c("--no-save", "--no-restore", "-e",
        shQuote("rmarkdown::render('doc.Rmd', clean = FALSE, quiet = TRUE)")),
      stdout = TRUE, stderr = TRUE))
    status <- attr(log, "status")
    cache <<- list(status = if (is.null(status)) 0L else status, log = paste(log, collapse = "\n"), dir = dir)
    cache
  }
})

test_that("TQ3: rmarkdown renders an .Rmd with constructs in \\(...\\), \\[...\\], $ and align", {
  r <- tq_rmd()
  expect_identical(r$status, 0L, label = r$log)
  expect_false(grepl("<<weft:", r$log, fixed = TRUE))
})

test_that("TQ3: the text knitr hands to Pandoc holds the TeX forms, in the brackets of the .Rmd too", {
  md <- tq_read(tq_rmd()$dir, "doc.knit.md")
  expect_match(md, "\\(c = 1.2\\ \\text{to}\\ 3.5\\)", fixed = TRUE)
  expect_match(md, "\\[d = +12.3\\%\\]", fixed = TRUE)
  expect_match(md, "$e = 12.3\\%$", fixed = TRUE)
  expect_match(md, "\\begin{align}\na &= -1{,}234{,}567.9\n\\end{align}", fixed = TRUE)
})

test_that("TQ3: the HTML holds the same TeX in its math spans", {
  html <- tq_read(tq_rmd()$dir, "doc.html")
  m <- tq_math(html)
  expect_true("\\(c = 1.2\\ \\text{to}\\ 3.5\\)" %in% m)
  expect_true("\\[d = +12.3\\%\\]" %in% m)
  expect_true("\\(e = 12.3\\%\\)" %in% m)
  expect_true(any(grepl("a &= -1{,}234{,}567.9", m, fixed = TRUE)))
})
