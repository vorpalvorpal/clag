# Extracted from test-quarto-render.R:83

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
dir <- mk_project(list(
    `_quarto.yml` = c("project:", "  type: default", "format: html"),
    `leftover.qmd` = qmd("Leftover",
                         "Depth is `r depth`{.num} here and [one site | # sites]{n=\"k\"} too.",
                         engine = FALSE),
    `clean.qmd` = qmd("Clean", "Nothing special, a [link](https://example.org).", engine = FALSE)
  ))
y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
y$project$`pre-render` <- NULL
y$project$`post-render` <- NULL
yaml::write_yaml(y, file.path(dir, "_quarto.yml"))
unlink(file.path(dir, "_weft"), recursive = TRUE)
expect_true("weft-check" %in% as_chr(y$filters), label = "the filter is still named")
