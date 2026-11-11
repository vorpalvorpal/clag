# Extracted from test-use-quarto.R:117

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
yml <- c(
    "project:",
    "  type: book",
    "  output-dir: out",
    "  pre-render: tools/mine.sh",
    "  post-render:",
    "    - tools/after-1.sh",
    "    - tools/after-2.sh",
    "filters:",
    "  - other.lua",
    "book:",
    "  title: \"Mine\"",
    "  chapters:",
    "    - index.qmd",
    "format:",
    "  html:",
    "    toc: true",
    "execute:",
    "  freeze: auto"
  )
dir <- fresh_project(yml)
suppressMessages(utils::capture.output(weft::use_quarto(dir)))
