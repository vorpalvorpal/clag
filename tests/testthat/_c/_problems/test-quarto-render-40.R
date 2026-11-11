# Extracted from test-quarto-render.R:40

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

# test -------------------------------------------------------------------------
skip_if_no_quarto()
dir <- mk_project(pre_files())
r <- qrender(dir)
expect_false(identical(r$status, 0L))
expect_match(r$log, "bad.qmd", fixed = TRUE)
