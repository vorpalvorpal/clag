# Helpers for the regression tests of the review of 2d (test-review-2d.R). ASCII only.
if (!exists("d2_run")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])
d2_need()

# rmarkdown::render() of `input` (relative to `dir`, or absolute), keeping the classed conditions it
# raised; `output_file` NULL leaves rmarkdown to name the output
d2r_render_to <- function(dir, input, output_file = NULL, env = NULL) {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  withr::local_envvar(if (is.null(env)) character() else env)
  withr::local_dir(dir)
  withr::defer(weft_restore_knitr())
  f <- rmarkdown::md_document(variant = "markdown", pandoc_args = "--wrap=none")
  f$knitr$opts_chunk$echo <- FALSE
  conds <- list()
  err <- NULL
  withCallingHandlers(
    tryCatch(rmarkdown::render(input, f, output_file = output_file, quiet = TRUE, envir = new.env()),
             error = function(e) err <<- e),
    warning = function(w) { conds[[length(conds) + 1L]] <<- w; invokeRestart("muffleWarning") },
    message = function(m) { conds[[length(conds) + 1L]] <<- m; invokeRestart("muffleMessage") })
  list(error = err, conds = conds, knit = tryCatch(weft:::last_knit(), error = function(e) NULL))
}

# a Quarto document of one format, with the weft setup chunk
d2r_qdoc <- function(body, format = "markdown") {
  c("---", "title: \"t\"", "engine: knitr", paste0("format: ", format), "execute:", "  echo: false", "---", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 1", "```", "", body, "")
}

# a fresh set-up folder holding doc.qmd; returns its normalised path
d2r_qdir <- function(lines, env = parent.frame()) {
  dir <- normalizePath(withr::local_tempdir(.local_envir = env))
  put_files(dir, D2_SETUP)
  writeLines(lines, file.path(dir, "doc.qmd"), useBytes = TRUE)
  dir
}

d2r_new_cond <- function(res) d2_of_class(res, "weft_new_condition")
d2r_ledger_warnings <- function(res) d2_of_class(res, "weft_ledger_warning")

# a document whose chunk `load` warns, with one value (as d2_warn_doc() in test-condition-log.R)
d2r_warn_doc <- function(n = 12) c("```{r load}", sprintf("warning('Removed %s rows')", n), "```", "", "Value `r 1`.")
