source("lib.R")
D <- file.path(HERE, "A_scope"); unlink(D, recursive = TRUE); dir.create(D)
ACT <- 'if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }'
PROBE <- "later=`r exists('later')` rp=`r exists('rp')` params=`r exists('params')` p=`r if (exists('params')) params$p else NA` mt=`r nrow(mtcars)`"
chunk <- c("", "```{r}", "later <- 5", "```", "", "BODY later=`r exists('later')` and `r later`{.num}", "")
scen <- function(name, route, extra_title = NULL, engine) {
  d <- file.path(D, paste0(name, "_", engine)); dir.create(d); file.copy("../spike-grammar2/setup.R", d)
  wr(c(ACT, "TRUE"), file.path(d, "act.R"))
  wr("rp <- 1", file.path(d, if (route == "rprofile") ".Rprofile.tmp" else ".Rprofile"))
  if (route == "rprofile") wr(c("rp <- 1", ACT), file.path(d, ".Rprofile")); unlink(file.path(d, ".Rprofile.tmp"))
  fm <- c("---", paste0('title: "', if (is.null(extra_title)) PROBE else extra_title, '"'),
          "params:", "  p: 7")
  if (route == "frontmatter") fm <- c(fm, "knitr:", "  opts_knit:", '    weft: !expr source("act.R")$value')
  fm <- c(fm, "---")
  setup <- if (route == "setupchunk") c("", "```{r}", "#| include: false", 'source("setup.R"); clag_install()', "```") else NULL
  f <- paste0("doc.", if (engine == "quarto") "qmd" else "Rmd")
  wr(c(fm, setup, chunk), file.path(d, f))
  x <- render(d, f, engine, if (engine == "quarto") "html" else "html_document")
  cat("====", name, engine, if (x$ok) "OK" else "FAILED", "\n")
  if (x$ok) { p <- peek(x$out); cat(paste0("  ", names(p), ": ", p[c("doc_title", "body_p")], collapse = "\n"), "\n") }
  else cat(substr(x$log, max(1, nchar(x$log) - 700), nchar(x$log)), "\n")
}
for (e in c("quarto", "rmarkdown")) {
  scen("fm_probe", "frontmatter", engine = e)
  scen("rprofile_probe", "rprofile", engine = e)
  scen("setupchunk_probe", "setupchunk", engine = e)
  scen("fm_later_construct", "frontmatter", "L `r later`{.num}", engine = e)
  scen("fm_params_construct", "frontmatter", "P `r params$p`{.num} S `r nrow(mtcars)`{.num} R `r rp`{.num}", engine = e)
  scen("rprofile_params_construct", "rprofile", "P `r params$p`{.num} S `r nrow(mtcars)`{.num} R `r rp`{.num}", engine = e)
  scen("setupchunk_construct", "setupchunk", "S `r nrow(mtcars)`{.num} [a site | # sites]{n='3'}", engine = e)
  scen("rprofile_construct", "rprofile", "S `r nrow(mtcars)`{.num} [a site | # sites]{n='3'}", engine = e)
}
