## Test harness for spike-cite. Documents live in docs/, outputs next to them.
setwd("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/docs")
QUARTO <- Sys.which("quarto"); RSCRIPT <- file.path(R.home("bin"), "Rscript")
wr <- function(x, path) writeLines(enc2utf8(paste(x, collapse = "\n")), path, useBytes = TRUE)
SETUP <- c("```{r}", "#| include: false", 'source("../setup.R"); source("../caption.R"); clag_install(); clag_install_captions()',
           "n_sites <- 5; x <- 0.62; slope <- 0.3", "```", "")
hdr <- function(engine, extra = character(), bib = "bibliography: refs.bib") {
  if (engine == "quarto") c("---", "title: t", bib, "format:", "  html: default", "  docx: default", "  typst: default", extra, "---", "")
  else c("---", "title: t", bib, "output:", "  html_document: default", "  word_document: default", extra, "---", "")
}
## write name.qmd / name.Rmd from a body (character vector)
mk <- function(name, body, engines = c("quarto", "rmarkdown"), extra = character(), bib = "bibliography: refs.bib", setup = TRUE) {
  for (e in engines) wr(c(hdr(e, extra, bib), if (setup) SETUP, body), paste0(name, if (e == "quarto") ".qmd" else ".Rmd"))
  invisible(name)
}
## render; returns list(ok, log)
render <- function(name, engine, to) {
  f <- paste0(name, if (engine == "quarto") ".qmd" else ".Rmd")
  ext <- c(html = "html", docx = "docx", typst = "pdf", html_document = "html", word_document = "docx")[[to]]
  tag <- if (engine == "quarto") "q" else "r"
  outf <- paste0(name, "_", tag, "_", to, ".", ext)
  unlink(outf)
  if (engine == "quarto") {
    args <- c("render", shQuote(f), "--to", to, "-o", shQuote(outf), if (to == "typst") c("-M", "keep-typ:true"))
    log <- suppressWarnings(system2(QUARTO, args, stdout = TRUE, stderr = TRUE))
  } else {
    wr(c("args <- commandArgs(TRUE)", "rmarkdown::render(args[1], output_format = args[2], output_file = args[3], quiet = TRUE)"), "render_rmd.R")
    log <- suppressWarnings(system2(RSCRIPT, c("render_rmd.R", shQuote(f), to, shQuote(outf)), stdout = TRUE, stderr = TRUE))
  }
  st <- attr(log, "status") %||% 0L
  writeLines(log, paste0(name, "_", tag, "_", to, ".log"))
  list(ok = st == 0L && file.exists(outf), out = outf, log = paste(log, collapse = "\n"), status = st)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
## all five renderer/format combos
COMBOS <- list(c("quarto", "html"), c("quarto", "docx"), c("quarto", "typst"), c("rmarkdown", "html_document"), c("rmarkdown", "word_document"))
render_all <- function(name, combos = COMBOS) {
  res <- list()
  for (cm in combos) { r <- render(name, cm[1], cm[2]); res[[paste(cm, collapse = "/")]] <- r
    cat(sprintf("  %-28s %s%s\n", paste0(name, " ", cm[1], "/", cm[2]), if (r$ok) "ok" else "FAIL", if (!r$ok) paste0(" | ", substr(gsub("\\s+", " ", paste(grep("clag|rror", strsplit(r$log, "\n")[[1]], value = TRUE), collapse = " ")), 1, 300)) else "")) }
  invisible(res)
}
## ---- text extraction ----
html_txt <- function(f) { d <- xml2::read_html(f, encoding = "UTF-8"); b <- xml2::xml_find_first(d, "//body")
  n <- xml2::xml_find_all(b, ".//text()[not(ancestor::script) and not(ancestor::style)]"); gsub("[[:space:]]+", " ", paste(xml2::xml_text(n), collapse = " ")) }
docx_txt <- function(f) { x <- paste(system2("unzip", c("-p", shQuote(f), "word/document.xml"), stdout = TRUE), collapse = ""); x <- gsub("</w:p>", "\n", x); trimws(gsub("<[^>]+>", "", x)) }
docx_xml <- function(f) paste(system2("unzip", c("-p", shQuote(f), "word/document.xml"), stdout = TRUE), collapse = "")
typ_txt <- function(f) paste(readLines(sub("_q_typst\\.pdf$", ".typ", f), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
