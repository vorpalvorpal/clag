# Extracted from test-quarto-render.R:129

# prequel ----------------------------------------------------------------------
qmd <- function(title, body, engine = TRUE, setup = NULL) {
  c("---", sprintf("title: \"%s\"", title), if (engine) "engine: knitr", "---", "",
    if (!is.null(setup)) c("```{r setup, include=FALSE}", setup, "```", ""),
    body)
}
html_of <- function(dir, name) {
  f <- file.path(dir, paste0(name, ".html"))
  if (!file.exists(f)) return(NA_character_)
  paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
has_marker <- function(html) grepl("weft: (failed claim|no value|value error|construct error)", html)
vals <- c("depth <- 12.5", "k <- 1")
pre_files <- function() {
  list(
    `_quarto.yml` = c("project:", "  type: default", "engine: knitr", "format: html"),
    `bad.qmd` = qmd("Bad", "Depth is `r depth`{.num} here.", engine = FALSE,
                    setup = c("weft::weft_setup()", vals)),
    `plain.qmd` = qmd("Plain", c("Nothing special: `code`, a [link](https://example.org),",
                                 "and [a span]{.smallcaps}."), engine = FALSE)
  )
}
pq_files <- function() {
  kinds_body <- c(
    "Value `r depth`{.num} here.", "",
    "Count [one site | # sites]{n=\"k\"} here.", "",
    "Cond [met | not met]{if=\"depth > 5\"} here.", "",
    "Text [result]{.strong} and [note]{.em} here.")
  list(
    `_quarto.yml` = c("project:", "  type: default", "format: html"),
    # never activated: a setup chunk with no weft_setup()
    `allkinds.qmd` = qmd("All kinds", kinds_body, setup = vals),
    # a value written with a capital R
    `capr.qmd` = qmd("Capital R", "Value `R depth`{.num} here.", setup = vals),
    # library(weft) attaches the package and activates nothing (9.2.6)
    `libonly.qmd` = qmd("Library only", "Value `r depth`{.num} here.",
                        setup = c("library(weft)", vals)),
    # the control: the same constructs, activated
    `ok.qmd` = qmd("Activated", kinds_body, setup = c("weft::weft_setup()", vals))
  )
}
pq_env <- new.env()
pq <- function() {
  if (is.null(pq_env$dir)) {
    pq_env$dir <- mk_project(pq_files())
    withr::defer(unlink(pq_env$dir, recursive = TRUE), teardown_env())
  }
  pq_env$dir
}

# test -------------------------------------------------------------------------
skip_if_no_quarto()
dir <- pq()
r <- qrender(dir, "ok.qmd")
expect_identical(r$status, 0L, info = r$log)
