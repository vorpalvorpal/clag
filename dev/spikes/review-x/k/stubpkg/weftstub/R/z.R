noop <- function() NULL
.onAttach <- function(libname, pkgname) {
  old <- knitr::knit_hooks$get("text")
  knitr::knit_hooks$set(text = function(x) old(gsub("[a site | # sites]{n=\"n\"}", "RESOLVED-BY-HOOK", x, fixed = TRUE)))
}
