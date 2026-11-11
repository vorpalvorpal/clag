unlink(".clag-collect")
if (file.exists("clag-failures.tsv")) {
  l <- readLines("clag-failures.tsv")
  cat("\nclag: ", length(l), " claim(s) failed across the project:\n", paste0("  ", sub("\\.rmarkdown", ".qmd", gsub("\t", "  ", l)), collapse = "\n"), "\n", sep = "")
  quit(status = 1)
}
