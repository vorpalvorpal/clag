source("lib.R")
D <- file.path(HERE, "B_late"); unlink(D, recursive = TRUE); dir.create(D)
file.copy("../spike-grammar2/setup.R", D)
wr(c('if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }', 'TRUE'), file.path(D, "act.R"))
ACTFM <- c("knitr:", "  opts_knit:", '    weft: !expr source("act.R")$value')
CH <- c("", "```{r}", "n_sites <- 3", "depth <- 12.345", "```", "", "BODY text here, n=`r n_sites`{.num}.", "")
LATE <- c("---", 'abstract: |', '  LATEABS We sampled [a site | # sites]{n="n_sites"}, mean depth `r depth`{.num} m.', "---", "")
LATE_T <- c("---", 'title: "LATETITLE `r depth`{.num} m at [a site | # sites]{n=\'n_sites\'}"', "---", "")
variants <- list(
  late_abstract  = list(top = 'title: "Top title"', late = LATE),
  late_title     = list(top = NULL, late = LATE_T),
  both_abstract  = list(top = c('title: "Top title"', 'abstract: "EARLYABS top-level"'), late = LATE),
  both_title     = list(top = 'title: "TOPTITLE top"', late = LATE_T),
  late_dots      = list(top = 'title: "Top title"', late = sub("^---$", "...", LATE, perl = TRUE)[c(1:3)] |> (\(x) c("---", x[2:3], "...", ""))())
)
runs <- list(c("quarto","html"), c("quarto","docx"), c("quarto","typst"), c("rmarkdown","html_document"), c("rmarkdown","word_document"))
for (v in names(variants)) for (r in runs) {
  ext <- if (r[1] == "quarto") "qmd" else "Rmd"; f <- sprintf("%s_%s_%s.%s", v, r[1], r[2], ext)
  wr(c("---", variants[[v]]$top, ACTFM, "---", CH, variants[[v]]$late), file.path(D, f))
  x <- render(D, f, r[1], r[2])
  cat("====", f, if (x$ok) "OK" else "FAILED", "\n")
  if (!x$ok) cat(substr(x$log, max(1, nchar(x$log) - 500), nchar(x$log)), "\n") else { p <- peek(x$out); cat(paste0("  ", names(p), ": ", p, collapse = "\n"), "\n")
    w <- grep("warn|unexpected|YAML|metadata", strsplit(x$log, "\n")[[1]], TRUE, value = TRUE); if (length(w)) cat("  LOG:", w, sep = "\n   ") }
}
