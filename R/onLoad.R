#' @importFrom utils installed.packages
.onLoad <- function(libname, pkgname) {
  # Set up default options
  op <- options()
  op.clag <- list(
    clag.enabled = TRUE
  )

  toset <- !(names(op.clag) %in% names(op))
  if (any(toset)) options(op.clag[toset])

  # Set up preprocessing by default
  setup_clag_preprocessing()

  invisible()
}

#' @importFrom utils packageVersion
.onAttach <- function(libname, pkgname) {
  invisible()
}
