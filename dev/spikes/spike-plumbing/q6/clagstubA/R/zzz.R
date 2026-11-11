install_hooks <- function() {
  knitr::knit_hooks$set(text = function(x) gsub("CLAGSTUB", "[hooks-active]", x, fixed = TRUE))
  invisible(TRUE)
}
# Record what .onLoad saw (spike diagnostics), then install if a knit is running.
.onLoad <- function(libname, pkgname) {
  inprog <- isTRUE(getOption("knitr.in.progress"))
  log <- Sys.getenv("CLAGSTUB_LOG")
  if (nzchar(log)) cat("onLoad knitr.in.progress=", inprog, " input=", tryCatch(basename(knitr::current_input()), error = function(e) "NULL"), "\n", file = log, append = TRUE, sep = "")
  install_hooks()   # variant A: unconditional
}
something <- function() 1
