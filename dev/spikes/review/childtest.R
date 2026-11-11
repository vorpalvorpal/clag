library(knitr)
log <- character()
knit_hooks$set(
  text = function(x) { log <<- c(log, sprintf("text hook: input=%s child_mode=%s", basename(current_input()), knitr:::child_mode())); x },
  document = function(x) { log <<- c(log, sprintf("document hook: input=%s child_mode=%s", basename(current_input()), knitr:::child_mode())); x }
)
invisible(knit("parent.Rmd", output = "parent.md", quiet = TRUE))
writeLines(log)
