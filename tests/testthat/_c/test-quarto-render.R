# The Quarto side through real renders: the pre-render check (2.5.4, 9.2.8),
# the filter alone (2.5.3), the backstops with the hooks missing (§21
# "Backstops") and draft mode (9.4.3). Single-file and small-project renders
# only; the book renders are in test-book.R.

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

# a marker in HTML (Quarto escapes < and >)
has_marker <- function(html) grepl("weft: (failed claim|no value|value error|construct error)", html)

vals <- c("depth <- 12.5", "k <- 1")

# ---- the pre-render check (2.5.4, 9.2.8) ----------------------------------

pre_files <- function() {
  list(
    `_quarto.yml` = c("project:", "  type: default", "engine: knitr", "format: html"),
    `bad.qmd` = qmd("Bad", "Depth is `r depth`{.num} here.", engine = FALSE,
                    setup = c("weft::weft_setup()", vals)),
    `plain.qmd` = qmd("Plain", c("Nothing special: `code`, a [link](https://example.org),",
                                 "and [a span]{.smallcaps}."), engine = FALSE)
  )
}

test_that("2.5.4, 9.2.8: a .qmd with a construct and no engine: knitr of its own fails the render, naming the file, before anything renders", {
  skip_if_no_quarto()
  dir <- mk_project(pre_files())
  r <- qrender(dir)
  expect_false(identical(r$status, 0L))
  expect_match(r$log, "bad.qmd", fixed = TRUE)
  # `engine: knitr` in _quarto.yml (the project) does not count: that is the setup here
  expect_match(readLines(file.path(dir, "_quarto.yml")), "engine: knitr", fixed = TRUE, all = FALSE)
  # nothing rendered: no output, no knit
  expect_identical(list.files(dir, pattern = "\\.html$", recursive = TRUE), character())
  expect_no_match(r$log, "processing file")
})

test_that("2.5.4, 9.2.8: with engine: knitr in the .qmd's own front matter it passes; a .qmd with no constructs passes either way", {
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
  # with the hooks on, nothing is left over
  expect_no_match(bad, "{.num}", fixed = TRUE)
  expect_false(has_marker(bad))
  expect_match(bad, "12.5", fixed = TRUE)
  expect_match(bad, "one site", fixed = TRUE)
})

# ---- the filter alone, with no pre-render script (2.5.3, §21 "Backstops") ----

test_that("2.5.3, 2.5.4: with the pre-render script absent the filter fails a .qmd that holds constructs and no engine", {
  skip_if_no_quarto()
  dir <- mk_project(list(
    `_quarto.yml` = c("project:", "  type: default", "format: html"),
    `leftover.qmd` = qmd("Leftover",
                         "Depth is `r depth`{.num} here and [one site | # sites]{n=\"k\"} too.",
                         engine = FALSE),
    `clean.qmd` = qmd("Clean", "Nothing special, a [link](https://example.org).", engine = FALSE)
  ))
  # take the scripts away: the filter is all that is left
  y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  y$project$`pre-render` <- NULL
  y$project$`post-render` <- NULL
  yaml::write_yaml(y, file.path(dir, "_quarto.yml"))
  unlink(file.path(dir, "_weft"), recursive = TRUE)
  expect_true("weft-check" %in% as_chr(y$filters), label = "the filter is still named")

  bad <- qrender(dir, "leftover.qmd")
  expect_false(identical(bad$status, 0L))
  expect_false(file.exists(file.path(dir, "leftover.html")), label = "no output after the filter failed")

  good <- qrender(dir, "clean.qmd")
  expect_identical(good$status, 0L, info = good$log)
  expect_true(file.exists(file.path(dir, "clean.html")))
})

# ---- backstops with the hooks missing, under Quarto ------------------------

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

test_that("§21 Backstops (control): the activated document renders clean in a set-up project", {
  skip_if_no_quarto()
  dir <- pq()
  r <- qrender(dir, "ok.qmd")
  expect_identical(r$status, 0L, info = r$log)
  html <- html_of(dir, "ok")
  expect_no_match(html, "{.num}", fixed = TRUE)
  expect_false(has_marker(html))
  expect_match(html, "12.5", fixed = TRUE)
  expect_match(html, "one site", fixed = TRUE)
  expect_match(html, "<strong>result</strong>", fixed = TRUE)
})

test_that("§21 Backstops, 2.5.3: a document with each kind of construct, never activated, fails under Quarto", {
  skip_if_no_quarto()
  dir <- pq()
  r <- qrender(dir, "allkinds.qmd")
  expect_false(identical(r$status, 0L), info = r$log)
})

test_that("§21 Backstops, 2.5.3: a value written with a capital R fails under Quarto", {
  skip_if_no_quarto()
  dir <- pq()
  r <- qrender(dir, "capr.qmd")
  expect_false(identical(r$status, 0L), info = r$log)
})

test_that("§21 Activation, 9.2.6: a setup chunk that only calls library(weft) is caught by the filter", {
  skip_if_no_quarto()
  dir <- pq()
  r <- qrender(dir, "libonly.qmd")
  expect_false(identical(r$status, 0L), info = r$log)
})

test_that("9.4.3: in draft mode the same document renders, and the filter reports instead of failing", {
  skip_if_no_quarto()
  dir <- pq()
  # (the failing render of the same document is the test above)
  writeLines("draft: true", file.path(dir, "_weft.yml"))
  withr::defer(writeLines("# weft settings", file.path(dir, "_weft.yml")))
  r <- qrender(dir, "allkinds.qmd")
  expect_identical(r$status, 0L, info = r$log)
  expect_false(is.na(html_of(dir, "allkinds")), label = "the document was written")
  # and the environment variable does the same, with no _weft.yml setting
  writeLines("# weft settings", file.path(dir, "_weft.yml"))
  r2 <- qrender(dir, "allkinds.qmd", env = c(WEFT_DRAFT = "1"))
  expect_identical(r2$status, 0L, info = r2$log)
})
