.libPaths(c("lib", .libPaths()))
for (s in c("A", "B", "C")) {
  f <- rmarkdown::render("t4.Rmd", params = list(site = s), output_file = paste0("t4_", s, ".html"), quiet = TRUE)
  cat(s, ":", grep("responded", readLines(f), value = TRUE), "\n")
}
