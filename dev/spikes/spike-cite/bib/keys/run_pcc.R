for (f in c("n500_bibtex.bib", "n500_biblatex.bib", "n500.json", "n500_cslyaml.yaml", "n500_cslyaml_delim.yaml")) {
  t <- system.time(r <- tryCatch(suppressWarnings(rmarkdown::pandoc_citeproc_convert(f, "list")), error = function(e) paste("ERROR", conditionMessage(e))))[["elapsed"]]
  cat(sprintf("pandoc_citeproc_convert %-26s n=%s secs=%.2f %s\n", f, if (is.list(r)) length(r) else NA, t, if (!is.list(r)) substr(r[1], 1, 80) else ""))
}
