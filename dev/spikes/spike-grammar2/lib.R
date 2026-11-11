## Shared helpers for run.R and extras.R. No absolute paths, no shell tricks:
## external programs are run with system2() and file arguments (no -e quoting).
root_dir <- function() {
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  d <- if (length(a)) dirname(sub("^--file=", "", a[1])) else "."
  normalizePath(d, winslash = "/")
}
ROOT <- root_dir()
OUT <- file.path(ROOT, "out")
dir.create(OUT, showWarnings = FALSE)
file.copy(file.path(ROOT, "setup.R"), file.path(OUT, "setup.R"), overwrite = TRUE)

wr <- function(x, path) { con <- file(path, "wb"); on.exit(close(con)); writeBin(charToRaw(enc2utf8(paste0(paste(x, collapse = "\n"), "\n"))), con) }
in_dir <- function(d, expr) { old <- setwd(d); on.exit(setwd(old)); force(expr) }
QUARTO <- Sys.which("quarto")
RSCRIPT <- file.path(R.home("bin"), "Rscript")
writeLines(c("args <- commandArgs(TRUE)",
             "rmarkdown::render(args[1], output_format = args[2], quiet = TRUE)"), file.path(OUT, "render_rmd.R"))

## render <doc> (a path in OUT) with an engine; returns list(ok, log, html, secs)
render_doc <- function(doc, engine, to = "html") {
  t0 <- Sys.time(); f <- basename(doc)
  log <- suppressWarnings(in_dir(dirname(doc), {
    if (engine == "quarto") system2(QUARTO, c("render", shQuote(f), "--to", to), stdout = TRUE, stderr = TRUE)
    else system2(RSCRIPT, c("render_rmd.R", shQuote(f), if (to == "html") "html_document" else to), stdout = TRUE, stderr = TRUE)
  }))
  st <- attr(log, "status") %||% 0L
  ext <- c(html = "html", docx = "docx", typst = "pdf")[[to]]
  out <- sub("\\.[A-Za-z]+$", paste0(".", ext), doc)
  list(ok = st == 0L && file.exists(out), log = paste(log, collapse = "\n"), out = out,
       secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

## plain text of an HTML file, body text nodes joined (block boundaries are
## whitespace nodes in Pandoc's HTML), whitespace collapsed.
html_text <- function(path) {
  d <- xml2::read_html(path, encoding = "UTF-8")
  nodes <- xml2::xml_find_all(d, "//body//text()[not(ancestor::script) and not(ancestor::style) and not(ancestor::noscript)]")
  norm(paste(xml2::xml_text(nodes), collapse = ""))
}
norm <- function(x) trimws(gsub("[[:space:] ]+", " ", gsub("[↩︎]", "", x)))
segments <- function(txt) {             # split on ZZB<id>ZZE markers
  m <- gregexpr("ZZB[a-z0-9_]+ZZE", txt)[[1]]
  if (m[1] == -1) return(list())
  starts <- as.integer(m); lens <- attr(m, "match.length")
  ids <- substring(txt, starts + 3L, starts + lens - 4L)
  ends <- c(starts[-1] - 1L, nchar(txt))
  setNames(lapply(seq_along(ids), function(k) norm(substring(txt, starts[k] + lens[k], ends[k]))), ids)
}

HEADER_CHUNK <- c("```{r}", "#| include: false", 'source("setup.R"); clag_install()',
                  'lg <- function(tag, v = "") { LOG <<- c(LOG, tag); v }', "LOG <- character()", "```", "")
doc_header <- function(engine, lang = NULL) {
  lg <- if (!is.null(lang)) paste0("lang: ", lang)
  if (engine == "quarto") c("---", "format: html", lg, "---", "")
  else c("---", "output: html_document", lg, "---", "")
}
## one case -> lines; returns list(lines, md_start offset within these lines)
case_lines <- function(cs) {
  L <- c(paste0("ZZB", cs$id, "ZZE"), "")
  if (nzchar(cs$setup)) L <- c(L, "```{r}", "#| include: false", cs$setup, "```", "")
  start <- length(L) + 1L
  L <- c(L, strsplit(cs$md, "\n", fixed = TRUE)[[1]], "")
  if (!is.null(cs$pre)) L <- c(L, strsplit(cs$pre, "\n", fixed = TRUE)[[1]], "")
  if (!is.null(cs$after)) L <- c(L, "```{r}", "#| echo: false", "#| results: asis", cs$after, "```", "")
  list(lines = L, start = start)
}
build_doc <- function(name, cs_list, engine) {
  ext <- if (engine == "quarto") ".qmd" else ".Rmd"
  hdr <- c(doc_header(engine, if (length(cs_list) == 1L) cs_list[[1]]$lang), HEADER_CHUNK); L <- hdr; starts <- integer()
  for (cs in cs_list) { cl <- case_lines(cs); starts[cs$id] <- length(L) + cl$start; L <- c(L, cl$lines) }
  path <- file.path(OUT, paste0(name, ext)); wr(L, path)
  list(path = path, starts = starts, name = basename(path))
}
