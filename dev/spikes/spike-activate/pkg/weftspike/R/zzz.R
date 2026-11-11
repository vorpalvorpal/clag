.onLoad <- function(libname, pkgname) {
  e <- new.env()
  sys.source(system.file("setup.R", package = pkgname), envir = e)
  assign("clag_env", e, topenv())  # placeholder
  e$clag_install()
  options(weftspike.loaded = TRUE)
}
## activate(): load the namespace (hooks installed by .onLoad); re-install to be sure
activate <- function(value = "") {
  getNamespace("weftspike")  # triggers .onLoad
  e <- get("clag_env", envir = asNamespace("weftspike"))
  e$clag_install()
  value
}
html_document <- function(...) {
  e <- get("clag_env", envir = asNamespace("weftspike"))
  rmarkdown::html_document(...) -> base
  rmarkdown::output_format(knitr = rmarkdown::knitr_options(
    knit_hooks = list(text = function(x) e$clag_text(x))), pandoc = NULL, base_format = base)
}
