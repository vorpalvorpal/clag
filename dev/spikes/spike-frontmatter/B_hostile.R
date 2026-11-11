source("lib.R")
D <- file.path(HERE, "B_hostile"); unlink(D, recursive = TRUE); dir.create(D); file.copy("../spike-grammar2/setup.R", D)
wr(c('if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }', 'TRUE'), file.path(D, "act.R"))
CH <- c("", "```{r}", "n_sites <- 3", "depth <- 12.345", "```", "", "BODY", "")
for (e in c("quarto", "rmarkdown")) for (v in c("backtick_first_plain", "bracket_first_plain")) {
  late <- c("---", if (v == "backtick_first_plain") "abstract: `r depth`{.num} m mean depth" else "abstract: [a site | # sites]{n='n_sites'} sampled", "---", "")
  ext <- if (e == "quarto") "qmd" else "Rmd"; f <- sprintf("late_%s_%s.%s", v, e, ext)
  wr(c("---", 'title: "T"', "knitr:", "  opts_knit:", '    weft: !expr source("act.R")$value', "---", CH, late), file.path(D, f))
  x <- render(D, f, e, if (e == "quarto") "html" else "html_document")
  if (x$ok) cat(f, "OK", peek(x$out)[["title_block"]], "\n") else cat(f, "FAILED:", substr(paste(unique(trimws(grep("rror|expected|cannot", sub("\x1b\\[[0-9;]*m", "", strsplit(x$log, "\n")[[1]]), value = TRUE))), collapse = " / "), 1, 250), "\n")
}
