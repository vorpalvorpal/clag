source("clag.R")  # for clag_compile
knitr::knit_engines$set(clag = function(options) {
  txt <- clag_compile(options$code)
  out <- knitr::knit_child(text = txt, quiet = TRUE)
  options$echo <- FALSE; options$results <- "asis"
  knitr::engine_output(options, code = options$code, out = paste(out, collapse = "\n"))
})
