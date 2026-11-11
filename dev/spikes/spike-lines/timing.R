## Timing: about 4,000 constructs (2,000 paragraphs, each with one `r k`{.num} and one [a|b]{n="n"} span).
## Sourced by run.R. Variants: 1 block / 200 blocks / 2000 blocks. Per method, 3 knit runs, median of the
## time spent inside the hook (accumulated in lines.R) and of the whole knit.
H("5. TIMING (2,000 paragraphs = 4,000 constructs)")
writeLines(c("a <- commandArgs(TRUE)",
             "t <- system.time(knitr::knit(a[1], a[2], quiet = TRUE))[['elapsed']]",
             "Lenv <- get('L', globalenv())",
             "cat(sprintf('%.3f %.3f %.3f %d', t, Lenv$tcs, Lenv$tcl, Lenv$n))"), file.path(OUT, "time_knit.R"))
mk_time_doc <- function(name, every, K = 2000L) {
  L <- c("---", "title: t", "---", "", "```{r}", 'source("lines.R"); lines_install()', "n <- 3", "```", "")
  for (k in seq_len(K)) {
    L <- c(L, sprintf('Paragraph %d: value `r %d`{.num} samples at [a site | # sites]{n="n"} and more prose to make it realistic.', k, k), "")
    if (every > 0L && k %% every == 0L) L <- c(L, "```{r}", "invisible(0)", "```", "")
  }
  p <- file.path(OUT, paste0(name, ".Rmd")); wr(L, p); p
}
docs <- c("1 block" = mk_time_doc("t_1", 0L), "200 blocks" = mk_time_doc("t_200", 10L), "2000 blocks" = mk_time_doc("t_2000", 1L))
meth <- c(none = "", cs = "cs", cl = "cl", `cs+rx` = "cs,rx", kc = "kc", pb = "pb")
res <- list()
for (dn in names(docs)) for (mn in names(meth)) {
  v <- replicate(3, {
    Sys.setenv(LINES_LOG = "", LINES_TAG = "time", LINES_METHODS = meth[[mn]], LINES_STRICT = "1",
               R_PROFILE_USER = if (mn == "pb") file.path(OUT, "pb.Rprofile") else "")
    old <- setwd(OUT)
    o <- system2(RSCRIPT, c("time_knit.R", shQuote(basename(docs[[dn]])), "time.md"), stdout = TRUE, stderr = FALSE)
    setwd(old); Sys.unsetenv("R_PROFILE_USER")
    as.numeric(strsplit(o[length(o)], " ")[[1]][1:3])
  })
  res[[paste(dn, mn)]] <- data.frame(doc = dn, method = mn, knit_s = median(v[1, ]), hook_search_s = median(v[2, ] + v[3, ]))
}
tm <- do.call(rbind, res); rownames(tm) <- NULL
base <- setNames(tm$knit_s[tm$method == "none"], tm$doc[tm$method == "none"])
tm$added_vs_none_s <- round(tm$knit_s - base[tm$doc], 3)
print(tm, row.names = FALSE, digits = 3)
cat("(hook_search_s = time inside cs_find/cl_find as measured in the hook; for pb/kc/none it is 0 by construction)\n")
