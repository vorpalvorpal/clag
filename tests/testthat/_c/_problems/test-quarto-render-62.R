# Extracted from test-quarto-render.R:62

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
files <- pre_files()
files$bad.qmd <- qmd("Bad", "Depth is `r depth`{.num} here. And [one site | # sites]{n=\"k\"}.",
                       engine = TRUE, setup = c("weft::weft_setup()", vals))
dir <- mk_project(files)
r <- qrender(dir)
expect_identical(r$status, 0L, info = r$log)
expect_true(file.exists(file.path(dir, "plain.html")), label = "plain.qmd (no constructs) rendered")
bad <- html_of(dir, "bad")
expect_false(is.na(bad))
expect_no_match(bad, "{.num}", fixed = TRUE)
expect_false(has_marker(bad))
expect_match(bad, "12.5", fixed = TRUE)
