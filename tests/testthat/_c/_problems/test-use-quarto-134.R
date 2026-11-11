# Extracted from test-use-quarto.R:134

# prequel ----------------------------------------------------------------------
project_yml <- function(extra = NULL) {
  c("project:", "  type: default", extra, "format: html")
}
use_quarto_says <- function(dir, first_message_hook = NULL) {
  txt <- character()
  out <- utils::capture.output(
    withCallingHandlers(
      weft::use_quarto(dir),
      message = function(m) {
        if (!is.null(first_message_hook) && !length(txt)) first_message_hook()
        txt <<- c(txt, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
  )
  paste(c(txt, out), collapse = "\n")
}
written_files <- c(
  "_extensions/weft-check/_extension.yml",
  "_extensions/weft-check/weft-check.lua",
  "_weft/pre-render.R",
  "_weft/post-render.R",
  "_weft.yml"
)
fresh_project <- function(yml = project_yml()) {
  dir <- tempfile("weft-uq-")
  dir.create(dir)
  dir <- normalizePath(dir)
  writeLines(yml, file.path(dir, "_quarto.yml"))
  writeLines(c("---", "title: Home", "---", "", "Some text."), file.path(dir, "index.qmd"))
  dir
}
as_chr <- function(x) as.character(unlist(x))

# test -------------------------------------------------------------------------
dir <- fresh_project(project_yml(c("  pre-render: tools/mine.sh")))
suppressMessages(utils::capture.output(weft::use_quarto(dir)))
