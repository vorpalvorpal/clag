#' Set up clag preprocessing for R Markdown and Quarto documents
#'
#' @description
#' This function registers clag_knit as the document processor.
#' It should be called in .onLoad to ensure clag is properly initialized.
#'
#' @param enabled Whether to enable clag preprocessing (default: TRUE)
#' @export
setup_clag_preprocessing <- function(enabled = TRUE) {
  if (!enabled) {
    # Disable the preprocessing
    options(clag.enabled = FALSE)
    return(invisible())
  }

  # Enable the preprocessing
  options(clag.enabled = TRUE)

  # Register knit engines if needed
  if (requireNamespace("knitr", quietly = TRUE)) {
    # Register clagmd engine
    knitr::knit_engines$set(clagmd = function(options) {
      # Process the content with clag
      out <- clag(options$code, .envir = knitr::knit_global())

      # Return processed content
      knitr::asis_output(out)
    })
  }

  # message("clag preprocessing enabled")
}

#' Check if the document has clag processing enabled via YAML header
#'
#' @param yaml_data YAML metadata as a list
#' @return Logical indicating whether clag is enabled
#' @noRd
is_clag_enabled <- function(yaml_data) {
  # Check for knit: clag::clag_knit or knit: clag::clag_render
  if (!is.null(yaml_data$knit)) {
    knit_func <- yaml_data$knit
    if (grepl("clag::clag_", knit_func)) {
      return(TRUE)
    }
  }

  # Check for params.clag.enabled
  if (!is.null(yaml_data$params) && !is.null(yaml_data$params$clag.enabled)) {
    return(isTRUE(yaml_data$params$clag.enabled))
  }

  # Default to the global option
  return(getOption("clag.enabled", FALSE))
}
