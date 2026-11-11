## Generate timing documents: doc100/500/2000 (paragraphs), 20 chapters x 300 paragraphs, with a v1 and an edited v2.
set.seed(7)
MS_SKIP <- TRUE; source("manuscript.R")   # for wrap()
words <- c("sample","bore","depth","reading","logger","survey","station","aquifer","recharge","drawdown","trend","season","site","record","channel","gauge","flow","level","series","profile")
mkpara <- function(k, tag) {
  w <- function(m) paste(sample(words, m, TRUE), collapse = " ")
  switch(as.character(k %% 4),
   "0" = sprintf("In %s the %s were summarised: `r mean_%s_%d`{.num} on average, `r n_%s_%d`{.num} in total, and %s.", tag, w(3), tag, k, tag, k, w(6)),
   "1" = sprintf("At `r n_sites`{.num} [a site | # sites]{n=\"n_sites\"} the %s was `r claim(x_%d, . > 10)`{.num} (%s) and %s.", w(2), k, tag, w(7)),
   "2" = sprintf("The %s [rose | fell]{sign=\"delta_%d\"} by `r d_%d`{.pct} between %s and %s, which %s.", w(2), k, k, w(1), w(1), w(5)),
   "3" = sprintf("Values from %s %s were %s; `r n_events`{.num} [event | # events]{n=\"n_events\"} exceeded the limit%s.", tag, w(2), w(6), "[ at `r n_flag`{.num} stations | ]{if=\"flagged\"}"))
}
mkdoc <- function(np, tag, per_sec = 15L, v2 = FALSE) {
  L <- c("---", sprintf("title: \"%s\"", tag), "---", "")
  for (k in seq_len(np)) {
    if ((k - 1L) %% per_sec == 0L) L <- c(L, sprintf("## Section %d of %s {#sec-%s-%d}", (k - 1L) %/% per_sec + 1L, tag, tag, (k - 1L) %/% per_sec + 1L), "")
    p <- mkpara(k, tag)
    if (v2 && k %% 40 == 7L) p <- sub("> 10", "> 5", p, fixed = TRUE)           # loosen a check
    if (v2 && k %% 40 == 21L) next                                                  # delete a paragraph
    L <- c(L, wrap(p, 72), "")
  }
  L
}
dir.create("out/timing/docs", recursive = TRUE, showWarnings = FALSE); dir.create("out/timing/ch1", recursive = TRUE, showWarnings = FALSE); dir.create("out/timing/ch2", recursive = TRUE, showWarnings = FALSE)
for (np in c(100, 500, 2000)) writeLines(mkdoc(np, paste0("d", np)), sprintf("out/timing/docs/doc%d.qmd", np))
for (i in 1:20) { nm <- sprintf("ch%02d", i)
  writeLines(mkdoc(300, nm), sprintf("out/timing/ch1/%s.qmd", nm)); writeLines(mkdoc(300, nm, v2 = TRUE), sprintf("out/timing/ch2/%s.qmd", nm)) }
cat("done\n")
