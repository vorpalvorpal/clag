## helpers for spike-frontmatter. Source from a script in this directory.
HERE <- normalizePath(".")
QUARTO <- Sys.which("quarto"); RSCRIPT <- file.path(R.home("bin"), "Rscript")
in_dir <- function(d, expr) { old <- setwd(d); on.exit(setwd(old)); force(expr) }
wr <- function(x, path) writeLines(x, path, useBytes = TRUE)
## render doc (file name, in dir d) with engine+format; returns list(ok, log, out)
render <- function(d, f, engine, fmt) {
  ext <- c(html = "html", docx = "docx", typst = "pdf", html_document = "html", word_document = "docx")[[fmt]]
  out <- file.path(d, sub("\\.[A-Za-z]+$", paste0(".", ext), f))
  unlink(out)
  log <- suppressWarnings(in_dir(d, {
    if (engine == "quarto") system2(QUARTO, c("render", shQuote(f), "--to", fmt), stdout = TRUE, stderr = TRUE)
    else system2(RSCRIPT, c("-e", shQuote(sprintf('rmarkdown::render("%s", output_format="%s", quiet=TRUE)', f, fmt))), stdout = TRUE, stderr = TRUE)
  }))
  list(ok = file.exists(out) && is.null(attr(log, "status")), log = paste(log, collapse = "\n"), out = out)
}
sq <- function(x) trimws(gsub("[[:space:]]+", " ", x))
## what the output shows in the front-matter positions
peek <- function(out) {
  ext <- tools::file_ext(out)
  if (ext == "html") {
    d <- xml2::read_html(out, encoding = "UTF-8")
    g <- function(xp) sq(paste(xml2::xml_text(xml2::xml_find_all(d, xp)), collapse = " || "))
    hdr <- g("//header[@id='title-block-header'] | //div[@id='header']")
    c(doc_title = g("//head/title"), title_block = hdr,
      raw_h1 = sq(regmatches(paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = " "), regexpr("<h1 class=\"title[^>]*>.{0,120}", paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = " ")))),
      meta_description = paste(xml2::xml_attr(xml2::xml_find_all(d, "//meta[@name='description']"), "content"), collapse = " || "),
      body_p = g("//body//p[contains(text(),'BODY')]"))
  } else if (ext == "docx") {
    td <- tempfile(); dir.create(td); unzip(out, exdir = td)
    d <- xml2::read_xml(file.path(td, "word/document.xml")); xml2::xml_ns_strip(d)
    ps <- xml2::xml_find_all(d, "//w:body/w:p")
    sty <- vapply(ps, function(p) xml2::xml_attr(xml2::xml_find_first(p, "w:pPr/w:pStyle"), "val") %||% "-", "")
    txt <- vapply(ps, function(p) paste(xml2::xml_text(xml2::xml_find_all(p, ".//w:t")), collapse = ""), "")
    core <- tryCatch(paste(readLines(file.path(td, "docProps/core.xml"), warn = FALSE), collapse = ""), error = function(e) "")
    cd <- sq(sub(".*<dc:description>(.*)</dc:description>.*", "\\1", core)); if (identical(cd, sq(core))) cd <- ""
    ct <- sq(sub(".*<dc:title>(.*)</dc:title>.*", "\\1", core)); if (identical(ct, sq(core))) ct <- ""
    c(paras = paste(sprintf("[%s] %s", sty, txt)[nzchar(txt)], collapse = " || "), core_title = ct, core_description = cd)
  } else if (ext == "pdf") {
    typ <- sub("\\.pdf$", ".typ", out)
    t <- suppressWarnings(system2("pdftotext", c("-layout", shQuote(out), "-"), stdout = TRUE, stderr = FALSE))
    c(pdf_text = sq(paste(head(t, 40), collapse = " ")))
  }
}
`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a
