# Helpers for the stage 7e tests (dev/design-7.md, F5: chunk claims collected):
# test-chunk-claims.R. Nothing here edits another helper. Made-up content only.

# knitr::knit() defaults to error = TRUE; rmarkdown (and Quarto) default to FALSE, as a real render does
CC7_PRE <- c("knitr::opts_chunk$set(error = FALSE)", "k <- 3; shift_n <- 7; low_n <- 2")

# a document body from chunks written as c(label, code lines...) pairs is clumsy; callers
# write the lines. cc7_chunk() builds one R chunk.
cc7_chunk <- function(label, ..., opts = "") {
  c(sprintf("```{r %s%s}", label, if (nzchar(opts)) paste0(", ", opts) else ""), c(...), "```", "")
}

# knit one document in process. `setting` is the value of chunk_claims written in _weft.yml
# (NULL writes none); `yml` adds further lines; the result is d2_run()'s list.
cc7_run <- function(lines, setting = "collect", yml = character(), draft = FALSE, may_fail = TRUE, ...) {
  y <- c(if (draft) "draft: true" else "draft: false", if (!is.null(setting)) paste0("chunk_claims: ", setting), yml)
  d2_run(lines, files = list("_weft.yml" = y), code = CC7_PRE, may_fail = may_fail, ...)
}

# the text of a file the knit wrote beside the document, or NULL when it is not there
cc7_seen <- function(res, name) {
  p <- file.path(res$dir, name)
  if (file.exists(p)) readLines(p, warn = FALSE) else NULL
}

# the failures of a run (data frame, possibly empty)
cc7_fail <- function(res) {
  f <- res$knit$failures
  if (is.null(f)) data.frame(kind = character(), chunk = character(), detail = character()) else f
}

# the message of the run's error, "" when none
cc7_msg <- function(res) if (is.null(res$error)) "" else conditionMessage(res$error)
