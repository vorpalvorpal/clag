source("lib.R")
D <- file.path(HERE, "A_forms"); unlink(D, recursive = TRUE); dir.create(D)
file.copy("../spike-grammar2/setup.R", D)
wr(c('if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }', 'TRUE'), file.path(D, "act.R"))
body <- c("", "```{r}", "n_sites <- 3", "```", "", "BODY `r nrow(mtcars)`{.num} and [a site | # sites]{n=\"n_sites\"}.", "")
C <- 'We sampled [a site | # sites]{n="3"}, mean `r nrow(mtcars)`{.num} m.'
H <- 'HZ `r intToUtf8(c(34,32,58,32,35,49,39))` end'
fld <- c("title", "subtitle", "abstract", "description")
mk <- function(form, act = TRUE) {
  L <- "---"
  for (f in fld) L <- c(L, switch(form,
    block  = c(paste0(f, ": |"), paste0("  ", toupper(f), " ", C)),
    folded = c(paste0(f, ": >"), paste0("  ", toupper(f), " ", C)),
    dq     = paste0(f, ': "', toupper(f), ' ', gsub('"', '\\\\"', C), '"'),
    dq2    = paste0(f, ': "', toupper(f), ' ', gsub('"', "'", C), '"'),
    preq_dq = paste0(f, ': "', toupper(f), ' `r "a"` x"'),
    preq_sq = paste0(f, ": '", toupper(f), " `r 'a'` x'"),
    haz_block  = c(paste0(f, ": |"), paste0("  ", toupper(f), " ", H)),
    haz_folded = c(paste0(f, ": >"), paste0("  ", toupper(f), " ", H)),
    haz_dq     = paste0(f, ': "', toupper(f), ' ', H, '"'),
    haz_sq     = paste0(f, ": '", toupper(f), " ", H, "'"),
    haz_plain  = paste0(f, ": ", toupper(f), " ", H),
    sq     = paste0(f, ": '", toupper(f), " ", C, "'"),
    plain  = paste0(f, ": ", toupper(f), " ", C)))
  if (act) L <- c(L, "knitr:", "  opts_knit:", '    weft: !expr source("act.R")$value')
  c(L, "---", body)
}

runs <- list(c("quarto","html"), c("quarto","docx"), c("quarto","typst"), c("rmarkdown","html_document"), c("rmarkdown","word_document"))
res <- list()
for (form in c("block","folded","dq","dq2","sq","plain","block_noact","haz_block","haz_folded","haz_dq","haz_sq","haz_plain","preq_dq","preq_sq")) {
  act <- !grepl("noact", form); fm <- sub("_noact", "", form)
  for (r in runs) {
    ext <- if (r[1] == "quarto") "qmd" else "Rmd"
    f <- sprintf("%s_%s_%s.%s", form, r[1], r[2], ext)
    wr(mk(fm, act), file.path(D, f))
    x <- render(D, f, r[1], r[2])
    cat("====", f, if (x$ok) "OK" else "FAILED", "\n")
    if (!x$ok) cat(substr(x$log, max(1, nchar(x$log) - 500), nchar(x$log)), "\n")
    else { p <- peek(x$out); cat(paste0("  ", names(p), ": ", p, collapse = "\n"), "\n") }
    if (x$ok && grepl("warn", x$log, TRUE)) cat("  LOG WARN:", grep("warn", strsplit(x$log, "\n")[[1]], TRUE, value = TRUE), "\n")
  }
}
