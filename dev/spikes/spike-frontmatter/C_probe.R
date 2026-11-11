source("lib.R")
CD <- file.path(HERE, "C", "cases"); unlink(CD, recursive = TRUE); dir.create(CD, recursive = TRUE)
WEFT <- c("weft:", "  digits: 2", "  dict_local:", "    sites:", "      value: 4", '      why: "x"')
KEYS <- function(lang = "de", bib = "refs.bib") c(WEFT, paste0("bibliography: ", bib), paste0("lang: ", lang))
BODY <- c("", "```{r}", 'source("probe.R"); probe("chunk")', "```", "", "BODY.", "")
setup_dir <- function(d) { dir.create(d, recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(HERE, "C", "probe.R"), d); wr(c('source("probe.R")', 'probe_hook_install()'), file.path(d, ".Rprofile"))
  wr("@book{k, title={T}, author={A}, year={2000}}", file.path(d, "refs.bib")) }
run <- function(case, docdir, docname, engine, is_project = FALSE) {
  fmt <- if (engine == "quarto") "html" else "html_document"
  out <- file.path(CD, case, paste0("probe_out_", engine)); dir.create(out, showWarnings = FALSE)
  Sys.setenv(PROBE_OUT = out)
  if (engine == "quarto" && is_project) { log <- suppressWarnings(in_dir(file.path(CD, case), system2(QUARTO, c("render", shQuote(file.path(docdir, docname)), "--to", "html"), stdout = TRUE, stderr = TRUE))); ok <- is.null(attr(log, "status")) }
  else { x <- render(file.path(CD, case, docdir), docname, engine, fmt); log <- x$log; ok <- x$ok }
  writeLines(sub("\x1b\\[[0-9;]*m", "", paste(log, collapse = "\n")), file.path(out, "render.log"))
  cat("====", case, engine, if (ok) "OK" else "FAILED", "probes:", paste(list.files(out, "^probe_"), collapse = ","), "\n")
  Sys.unsetenv("PROBE_OUT")
}
doc <- function(path, fm) wr(c("---", fm, "---", BODY), path)
## c1: doc-level keys (both engines)
d <- file.path(CD, "c1_doc"); setup_dir(d); doc(file.path(d, "q.qmd"), c("format: html", KEYS("fr"))); doc(file.path(d, "r.Rmd"), c("output: html_document", KEYS("fr")))
run("c1_doc", ".", "q.qmd", "quarto"); run("c1_doc", ".", "r.Rmd", "rmarkdown")
## c2: project-level _quarto.yml only (doc has no keys)
d <- file.path(CD, "c2_project"); setup_dir(d); wr(c("project:", "  type: default", KEYS("de")), file.path(d, "_quarto.yml"))
doc(file.path(d, "q.qmd"), "format: html"); doc(file.path(d, "r.Rmd"), "output: html_document")
run("c2_project", ".", "q.qmd", "quarto", TRUE); run("c2_project", ".", "r.Rmd", "rmarkdown")
## c3: _metadata.yml in sub/, project root has _quarto.yml without the keys
d <- file.path(CD, "c3_metadata"); setup_dir(d); setup_dir(file.path(d, "sub")); wr(c("project:", "  type: default"), file.path(d, "_quarto.yml")); wr(KEYS("it"), file.path(d, "sub", "_metadata.yml"))
doc(file.path(d, "sub", "q.qmd"), "format: html"); doc(file.path(d, "sub", "r.Rmd"), "output: html_document")
run("c3_metadata", "sub", "q.qmd", "quarto", TRUE); run("c3_metadata", "sub", "r.Rmd", "rmarkdown")
## c3b: _metadata.yml with NO _quarto.yml anywhere
d <- file.path(CD, "c3b_metadata_noproject"); setup_dir(d); wr(KEYS("it"), file.path(d, "_metadata.yml")); doc(file.path(d, "q.qmd"), "format: html")
run("c3b_metadata_noproject", ".", "q.qmd", "quarto")
## c4: book
d <- file.path(CD, "c4_book"); setup_dir(d); wr(c("project:", "  type: book", "book:", "  title: BookT", "  chapters:", "    - index.qmd", "    - ch2.qmd", "format:", "  html: default", KEYS("es")), file.path(d, "_quarto.yml"))
doc(file.path(d, "index.qmd"), 'title: "Intro"'); doc(file.path(d, "ch2.qmd"), 'title: "Ch2"')
run("c4_book", ".", "ch2.qmd", "quarto", TRUE)
## c5: conflict doc vs project
d <- file.path(CD, "c5_conflict"); setup_dir(d); wr(c("project:", "  type: default", KEYS("de", "refs.bib")), file.path(d, "_quarto.yml"))
doc(file.path(d, "q.qmd"), c("format: html", "lang: fr", "weft:", "  digits: 9")); run("c5_conflict", ".", "q.qmd", "quarto", TRUE)
## c6: project-level keys placed under format: html: (a different place)
d <- file.path(CD, "c6_project_format"); setup_dir(d); wr(c("project:", "  type: default", "format:", "  html:", "    lang: de", "    bibliography: refs.bib"), file.path(d, "_quarto.yml"))
doc(file.path(d, "q.qmd"), "format: html"); run("c6_project_format", ".", "q.qmd", "quarto", TRUE)

## c7: relative bibliography paths: root _quarto.yml says refs.bib (root), sub/_metadata.yml says sub.bib, doc in sub/
d <- file.path(CD, "c7_relpaths"); setup_dir(d); setup_dir(file.path(d, "sub")); wr("@book{k2, title={T}, author={A}, year={2000}}", file.path(d, "sub", "sub.bib"))
wr(c("project:", "  type: default", "bibliography: refs.bib"), file.path(d, "_quarto.yml")); wr("bibliography: sub.bib", file.path(d, "sub", "_metadata.yml"))
doc(file.path(d, "sub", "q.qmd"), "format: html"); doc(file.path(d, "sub", "q2.qmd"), c("format: html", "bibliography: refs.bib"))
run("c7_relpaths", "sub", "q.qmd", "quarto", TRUE)
## c8: root-only bibliography, doc in sub/ (no _metadata.yml)
d <- file.path(CD, "c8_relpaths_root"); setup_dir(d); setup_dir(file.path(d, "sub")); wr(c("project:", "  type: default", "bibliography: refs.bib"), file.path(d, "_quarto.yml"))
doc(file.path(d, "sub", "q.qmd"), "format: html"); run("c8_relpaths_root", "sub", "q.qmd", "quarto", TRUE)
