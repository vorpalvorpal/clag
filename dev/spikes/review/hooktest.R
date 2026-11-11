library(knitr)
for (i in 1:2) {
  out <- knit("hookdoc.Rmd", output = sprintf("hookdoc%d.md", i), quiet = TRUE)
  cat("knit", i, ":", grep("Value", readLines(out), value = TRUE), "\n")
  cat("  text hook after knit", i, "is default:", is.null(knit_hooks$get("text")) || identical(deparse(knit_hooks$get("text")), deparse(knitr:::.default.hooks$text)), "\n")
}
cat("knitr", as.character(packageVersion("knitr")), "\n")
