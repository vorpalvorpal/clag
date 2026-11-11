# Inputs with governed constructs but no fresh stamp this render => their checks did not run (served from freeze)
src <- list.files(pattern = "\\.qmd$"); bad <- character()
for (f in src) {
  txt <- readLines(f, warn = FALSE)
  governed <- any(grepl("`r [^`]*`\\{[^}]*\\}", txt)) || any(grepl("\\]\\{[^}]*(n|if|claim)=", txt))
  if (governed && !file.exists(file.path(".clag-stamps", paste0(f, ".stamp")))) bad <- c(bad, f)
}
if (length(bad)) { cat("clag: checks did NOT run this render (served from freeze?): ", paste(bad, collapse = ", "), "\n", sep = ""); quit(status = 1) }
