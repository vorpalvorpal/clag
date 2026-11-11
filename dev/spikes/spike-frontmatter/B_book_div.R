source("lib.R")
## ---- book chapter with a late abstract block
D <- file.path(HERE, "B_book"); unlink(D, recursive = TRUE); dir.create(D)
file.copy("../spike-grammar2/setup.R", D)
ACTL <- 'if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }'
wr(c(ACTL, "TRUE"), file.path(D, "act.R"))
wr(c("project:", "  type: book", "book:", "  title: BookT", "  chapters:", "    - index.qmd", "    - ch2.qmd", "format:", "  html: default", "  docx: default"), file.path(D, "_quarto.yml"))
ACTFM <- c("knitr:", "  opts_knit:", '    weft: !expr source("act.R")$value')
CH <- c("", "```{r}", "n_sites <- 3", "depth <- 12.345", "```", "", "BODY text here, n=`r n_sites`{.num}.", "")
LATE <- c("---", 'abstract: |', '  LATEABS We sampled [a site | # sites]{n="n_sites"}, mean depth `r depth`{.num} m.', "---", "")
wr(c("---", 'title: "Intro"', "---", "", "Intro body."), file.path(D, "index.qmd"))
wr(c("---", 'title: "Ch two"', ACTFM, "---", "", "# Ch two", CH, LATE), file.path(D, "ch2.qmd"))
log <- system2(QUARTO, c("render", shQuote(D)), stdout = TRUE, stderr = TRUE); writeLines(log, file.path(D, "render.log"))
cat("book render status:", attr(log, "status") %||% 0, "\n"); cat(grep("warn|error", sub("\x1b\\[[0-9;]*m", "", log), TRUE, value = TRUE), sep = "\n")
h <- readLines(file.path(D, "_book/ch2.html"), warn = FALSE); i <- grep("LATEABS", h); cat("html ch2 LATEABS lines:", i, "\n"); cat(h[i], sep = "\n")
cat("any '#sites' literal or 'r depth' left:", any(grepl("r depth|# sites", h)), "\n")
x <- file.path(D, "_book"); print(list.files(x, recursive = FALSE))
## ---- body div alternatives
D2 <- file.path(HERE, "B_div"); unlink(D2, recursive = TRUE); dir.create(D2); file.copy("../spike-grammar2/setup.R", D2)
wr(c(ACTL, "TRUE"), file.path(D2, "act.R"))
body <- c("", "```{r}", "n_sites <- 3", "```", "", "BODY before.", "",
  "::: {.abstract}", 'DIVABS_class We sampled [a site | # sites]{n="n_sites"}.', ":::", "",
  "::: {#abstract}", 'DIVABS_id We sampled [a site | # sites]{n="n_sites"}.', ":::", "",
  '::: {custom-style="Abstract"}', 'DIVABS_custom We sampled [a site | # sites]{n="n_sites"}.', ":::", "")
runs <- list(c("quarto","html"), c("quarto","docx"), c("quarto","typst"), c("rmarkdown","html_document"), c("rmarkdown","word_document"))
for (r in runs) {
  ext <- if (r[1] == "quarto") "qmd" else "Rmd"; f <- sprintf("div_%s_%s.%s", r[1], r[2], ext)
  wr(c("---", 'title: "Top title"', ACTFM, "---", body), file.path(D2, f))
  x <- render(D2, f, r[1], r[2]); cat("====", f, if (x$ok) "OK" else "FAILED", "\n")
  if (x$ok) { if (grepl("html$", x$out)) { h <- readLines(x$out, warn = FALSE); cat(h[grep("DIVABS|BODY before", h)], sep = "\n"); cat("  abstract-title present:", any(grepl("block-title\">Abstract|class=\"abstract\">Abstract", h)), "\n") } else print(peek(x$out)) } else cat(substr(x$log, nchar(x$log) - 400, nchar(x$log)))
}
