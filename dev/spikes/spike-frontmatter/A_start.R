source("lib.R")
D <- file.path(HERE, "A_start"); unlink(D, recursive = TRUE); dir.create(D); file.copy("../spike-grammar2/setup.R", D)
wr(c('if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }', 'TRUE'), file.path(D, "act.R"))
starts <- list(bracket = "[a site | # sites]{n='3'} sampled", backtick = "`r nrow(mtcars)`{.num} sites sampled")
for (s in names(starts)) for (form in c("plain", "dq", "sq", "block", "folded")) for (e in c("quarto", "rmarkdown")) {
  v <- starts[[s]]; if (form == "sq") v <- gsub("'", "''", v)
  line <- switch(form, plain = paste0("title: ", v), dq = paste0('title: "', v, '"'), sq = paste0("title: '", v, "'"), block = c("title: |", paste0("  ", v)), folded = c("title: >", paste0("  ", v)))
  ext <- if (e == "quarto") "qmd" else "Rmd"; f <- sprintf("%s_%s_%s.%s", s, form, e, ext)
  wr(c("---", line, "knitr:", "  opts_knit:", '    weft: !expr source("act.R")$value', "---", "", "BODY"), file.path(D, f))
  x <- render(D, f, e, if (e == "quarto") "html" else "html_document")
  if (x$ok) { p <- peek(x$out); cat(sprintf("%-34s OK     title=%s\n", f, p[["doc_title"]])) }
  else { l <- sub("\x1b\\[[0-9;]*m", "", strsplit(x$log, "\n")[[1]]); l <- l[grepl("rror|cannot|expected|did not find|Scanner|Parser", l)]; cat(sprintf("%-34s FAILED %s\n", f, substr(paste(unique(trimws(l)), collapse = " / "), 1, 200))) }
}
