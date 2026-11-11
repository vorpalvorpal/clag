## Other exported routes: what does the text hook (and the rest of the public surface) actually expose?
H("6. OTHER ROUTES (exported / public surface)")
dump_doc <- c("---", "title: routes", "---", "", "```{r}",
  "knitr::knit_hooks$set(text = function(x) {",
  "  cat('\\n--- inside text hook ---\\n')",
  "  cat('formals(text hook):', paste(names(formals(knitr::knit_hooks$get('text'))), collapse = ','), '\\n')",
  "  cat('opts_current:', paste(names(knitr::opts_current$get()), collapse = ','), '\\n')",
  "  cat('opts_current label/params:', knitr::opts_current$get('label'), '\\n')",
  "  ok <- c('child', 'concordance', 'out.format', 'progress', 'root.dir', 'output.dir', 'tangle', 'parent', 'header')",
  "  cat('opts_knit:', paste(ok, vapply(ok, function(k) paste(format(knitr::opts_knit$get(k)), collapse = ' '), ''), sep = '=', collapse = ' | '), '\\n')",
  "  cat('current_input():', knitr::current_input(), ' dir=TRUE:', suppressWarnings(knitr::current_input(dir = TRUE)), '\\n')",
  "  fn <- vapply(sys.calls(), function(cl) paste(deparse(cl[[1]])[1], collapse = ''), '')",
  "  cat('call stack (outer->inner):', paste(fn, collapse = ' > '), '\\n')",
  "  k <- which(fn == 'process_file')",
  "  if (length(k)) { fr <- sys.frame(k[1]); cat('process_file frame vars:', paste(ls(fr), collapse = ','), ' i =', get('i', fr), '\\n')",
  "    g <- get('groups', fr); cat('  names(groups[[i]]):', paste(names(g[[get('i', fr)]]), collapse = ','), '| names of a chunk group:', paste(names(g[[which(vapply(g, function(z) inherits(z, 'block'), NA))[1]]]), collapse = ','), '\\n') }",
  "  x })",
  "knitr::knit_hooks$set(document = function(x) { cat('\\n--- document hook: last 120 chars of output ---\\n'); cat(substring(x, max(1, nchar(x) - 120)), '\\n'); x })",
  "knitr::opts_knit$set(concordance = TRUE)",
  "```", "", "Para `r 1+1`.", "", "```{r lbl}", "a <- knitr::knit_code$get('lbl')",
  "cat('knit_code attrs:', paste(names(attributes(a)), collapse = ','), '| chunk_opts:', paste(names(attr(a, 'chunk_opts')), collapse = ','), '\\n')",
  "```", "", "Tail.", "")
wr(dump_doc, file.path(OUT, "x_routes.Rmd"))
old <- setwd(OUT)
o <- system2(RSCRIPT, c("-e", shQuote("knitr::knit('x_routes.Rmd', 'x_routes.md', quiet = TRUE)")), stdout = TRUE, stderr = TRUE)
setwd(old)
cat(o[!grepl("^\\s*$", o)][1:min(length(o), 40)], sep = "\n")
cat("\n--- tail of x_routes.md (public concordance output, written AFTER the run) ---\n")
cat(tail(readLines(file.path(OUT, "x_routes.md")), 3), sep = "\n")
cat("\nknitr.* options read by knitr relevant to positions: knitr.progress.linenums, knitr.progress.fun, knitr.progress.output, knitr.progress.simple (see method pb)\n")
