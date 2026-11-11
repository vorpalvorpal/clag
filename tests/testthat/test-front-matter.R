# Stage 1c: constructs in front-matter fields (1.10.7-1.10.9, 1.10.11, 9.2.5).
#
# Whole files are written by the test (the YAML is the subject), so every
# document is passed as complete lines to qmd_html() / rmd_html().

fm_act <- c("knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()")

# the four fields as block scalars, activated from the front matter (9.2.1)
fm_fields <- function(engine = c("rmd", "qmd")) {
  engine <- match.arg(engine)
  c("---",
    "title: |",
    "  Report on [a site | # sites]{n=\"sqrt(9)\"}",
    "subtitle: >",
    "  Mean depth `r 12.5`{.num} m",
    "abstract: |",
    "  Abstract of [many | one]{if=\"sqrt(9) > 1\"} sites",
    "description: >",
    "  Description of [a site | # sites]{n=\"sqrt(9)\"}",
    if (engine == "qmd") c("engine: knitr", "format: html"),
    fm_act, "---", "", "Body text.", "")
}

fm_late_body <- c(
  "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
  "```{r}", "late_k <- 4", "late_d <- 12.5", "```", "",
  "Body text.", "",
  "---",
  "abstract: |",
  "  Late abstract with [a site | # sites]{n=\"late_k\"}, depth `r late_d`{.num} m",
  "title: |",
  "  Late [many | one]{if=\"late_k > 1\"} sites",
  "---", "")

fm_late <- function(engine = c("rmd", "qmd")) {
  engine <- match.arg(engine)
  c("---", "title: \"Plain title\"", "abstract: \"First abstract\"",
    if (engine == "qmd") c("engine: knitr", "format: html"), "---", "", fm_late_body)
}

fm_bare <- function(engine = c("rmd", "qmd"), active = TRUE) {
  engine <- match.arg(engine)
  c("---", "title: \"Report `r 1 + 1`\"",
    if (engine == "qmd") c("engine: knitr", "format: html"),
    if (active) fm_act, "---", "", "Body text.", "")
}

expect_resolved_fields <- function(r, label) {
  expect_false(r$failed, label = paste(label, r$message))
  expect_match(r$text, "Report on 3 sites", fixed = TRUE, label = label)
  expect_match(r$text, "Mean depth 12.5 m", fixed = TRUE, label = label)
  expect_match(r$text, "Abstract of many sites", fixed = TRUE, label = label)
  # stock rmarkdown html_document does not print `description`
  if (!identical(label, "rmarkdown")) expect_match(r$html, "Description of 3 sites", fixed = TRUE, label = label)
  expect_false(grepl("{n=", r$html, fixed = TRUE), label = label)
  expect_false(grepl("{if=", r$html, fixed = TRUE), label = label)
}

# ---- resolution ---------------------------------------------------------------

test_that("1.10.7 + 1.10.8 + 9.2.1 (rmarkdown): title, subtitle, abstract and description as block scalars (| and >) resolve with front-matter activation", {
  r <- rmd_html(fm_fields("rmd"))
  expect_resolved_fields(r, "rmarkdown")
  expect_equal(nrow(r$knit$failures), 0L)
  # control: without the activating line they stay raw (the same text, weft not involved)
  off <- rmd_html(fm_fields("rmd")[-(which(fm_fields("rmd") == "knitr:") + 0:2)])
  expect_false(off$failed, label = off$message)
  expect_true(grepl("a site | # sites", off$text, fixed = TRUE))   # Pandoc keeps the arms as text
  expect_false(grepl("Report on 3 sites", off$text, fixed = TRUE))
})

test_that("1.10.7 + 1.10.8 + 9.2.1 (Quarto): the same four fields resolve", {
  skip_if_no_quarto()
  r <- qmd_html(fm_fields("qmd"))
  expect_resolved_fields(r, "Quarto")
})

test_that("1.10.9 (rmarkdown): a late metadata block sees the chunks' values and wins over the first block", {
  r <- rmd_html(fm_late("rmd"))
  expect_false(r$failed, label = r$message)
  expect_match(r$text, "Late abstract with 4 sites, depth 12.5 m", fixed = TRUE)
  expect_match(r$text, "Late many sites", fixed = TRUE)
  expect_false(grepl("First abstract", r$text, fixed = TRUE))
  expect_false(grepl("Plain title", r$text, fixed = TRUE))
  expect_false(grepl("{n=", r$html, fixed = TRUE))
})

test_that("1.10.9 (Quarto): a late metadata block sees the chunks' values and wins over the first block", {
  skip_if_no_quarto()
  r <- qmd_html(fm_late("qmd"))
  expect_false(r$failed, label = r$message)
  expect_match(r$text, "Late abstract with 4 sites, depth 12.5 m", fixed = TRUE)
  expect_match(r$text, "Late many sites", fixed = TRUE)
  expect_false(grepl("First abstract", r$text, fixed = TRUE))
  expect_false(grepl("{n=", r$html, fixed = TRUE))
})

test_that("1.10.7 + 1.1.8 (both): bare inline R in a quoted title is not a construct; it prints as stock prints it, with weft on or off", {
  on <- rmd_html(fm_bare("rmd", TRUE))
  off <- rmd_html(fm_bare("rmd", FALSE))
  expect_false(on$failed, label = on$message)
  expect_false(off$failed, label = off$message)
  title_of <- function(r) sub(".*<title>(.*?)</title>.*", "\\1", gsub("\n", " ", r$html), perl = TRUE)
  expect_identical(title_of(on), title_of(off))
  expect_true(nzchar(title_of(on)))
  skip_if_no_quarto()
  qon <- qmd_html(fm_bare("qmd", TRUE))
  qoff <- qmd_html(fm_bare("qmd", FALSE))
  expect_false(qon$failed, label = qon$message)
  expect_false(qoff$failed, label = qoff$message)
  expect_identical(title_of(qon), title_of(qoff))
})

# ---- construct errors ---------------------------------------------------------

test_that("1.10.7 (rmarkdown): a construct in a single-quoted title is a construct error naming its YAML line; a block scalar is the legal form", {
  lines <- c("---", "title: 'Report [a | b]{if=\"TRUE\"}'", fm_act, "---", "", "Body.", "")
  r <- rmd_html(lines)
  expect_true(r$failed)
  expect_true("weft_construct_error" %in% r$error$class)
  expect_match(r$message, at_line(r, file_line(lines, "title:")))
  expect_match(r$message, "block scalar", ignore.case = TRUE)
  # control: same text as a block scalar
  ok <- c("---", "title: |", "  Report [a | b]{if=\"TRUE\"}", fm_act, "---", "", "Body.", "")
  r <- rmd_html(ok)
  expect_false(r$failed, label = r$message)
  expect_match(r$text, "Report a", fixed = TRUE)
})

test_that("1.10.7 (Quarto): a construct in a plain scalar abstract is a construct error naming its YAML line", {
  skip_if_no_quarto()
  lines <- c("---", "title: \"t\"", "abstract: Many [a | # sites]{n=3} here", "engine: knitr", "format: html",
             fm_act, "---", "", "Body.", "")
  r <- qmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, at_line(r, file_line(lines, "abstract:")))
  expect_match(r$message, "block scalar", ignore.case = TRUE)
})

book_yml <- c("project:", "  type: book", "book:", "  title: \"B\"", "  chapters:", "    - index.qmd", "format: html")
site_yml <- c("project:", "  type: website", "website:", "  title: \"W\"", "format: html")
default_yml <- c("project:", "  type: default", "format: html")
fm_chapter <- function(title = "title: |\n  Chapter [many | one]{if=\"sqrt(9) > 1\"}", extra = NULL) {
  c("---", strsplit(title, "\n", fixed = TRUE)[[1]], extra, "engine: knitr", fm_act, "---", "", "Body text.", "")
}

test_that("1.10.11 (Quarto): in a book or a website a construct in title is a construct error, in either metadata block; abstract is fine; a default project is fine", {
  skip_if_no_quarto()
  # a book, first block
  ch <- fm_chapter()
  dir <- mk_project(list(`_quarto.yml` = book_yml, `index.qmd` = ch), use = FALSE)
  r <- qrender(dir)
  expect_false(identical(r$status, 0L))
  expect_match(r$log, "title")
  expect_match(r$log, sprintf("index\\.qmd:%d\\b", file_line(ch, "Chapter [many")))
  # a website, late block
  late <- c("---", "title: \"Plain\"", "engine: knitr", fm_act, "---", "", "Body.", "",
            "---", "title: |", "  Late [many | one]{if=\"sqrt(9) > 1\"}", "---", "")
  dir <- mk_project(list(`_quarto.yml` = site_yml, `index.qmd` = late), use = FALSE)
  r <- qrender(dir)
  expect_false(identical(r$status, 0L))
  expect_match(r$log, sprintf("index\\.qmd:%d\\b", file_line(late, "Late [many")))
  # controls: the same construct in abstract, in a book
  ab <- fm_chapter("title: \"Chapter\"", c("abstract: |", "  Abstract of [many | one]{if=\"sqrt(9) > 1\"} sites"))
  dir <- mk_project(list(`_quarto.yml` = book_yml, `index.qmd` = ab), use = FALSE)
  r <- qrender(dir)
  expect_identical(r$status, 0L, label = r$log)
  # and in title, in a default project
  dir <- mk_project(list(`_quarto.yml` = default_yml, `index.qmd` = fm_chapter()), use = FALSE)
  r <- qrender(dir)
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(file.path(dir, "index.html")))
  out <- read_html_file(file.path(dir, "index.html"))
  expect_match(html_text(out), "Chapter many", fixed = TRUE)
})

# ---- failures, and activation that is too late -------------------------------

fm_claim <- function(engine = c("rmd", "qmd")) {
  engine <- match.arg(engine)
  c("---", "title: \"t\"", "abstract: |", "  Count `r claim(3, . > 100)`{.num} sites",
    if (engine == "qmd") c("engine: knitr", "format: html"), fm_act, "---", "", "Body.", "")
}

test_that("2.6.2 + 2.7.1 + 1.10.7 (rmarkdown): a failed claim in the abstract is reported at its YAML line, and marked there in draft mode", {
  lines <- fm_claim("rmd")
  at <- file_line(lines, "claim(3")
  r <- rmd_html(lines)
  expect_true(r$failed)
  expect_true("weft_failures" %in% r$error$class)
  expect_match(r$message, at_line(r, at))
  expect_match(r$message, ". > 100 was FALSE", fixed = TRUE)
  expect_equal(r$knit$failures$line, at)
  d <- rmd_html(lines, env = c(WEFT_DRAFT = "1"))
  expect_false(d$failed, label = d$message)
  expect_match(d$text, sprintf("Count 3<<weft: failed claim, line %d>> sites", at), fixed = TRUE)
})

test_that("2.6.2 + 2.7.1 + 1.10.7 (Quarto): a failed claim in the abstract is reported at its YAML line", {
  skip_if_no_quarto()
  lines <- fm_claim("qmd")
  at <- file_line(lines, "claim(3")
  r <- qmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, at_line(r, at))
  d <- qmd_html(lines, env = c(WEFT_DRAFT = "1"))
  expect_false(d$failed, label = d$message)
  expect_match(d$text, sprintf("Count 3<<weft: failed claim, line %d>> sites", at), fixed = TRUE)
})

test_that("9.2.5 + 2.5.2 (rmarkdown): with setup-chunk activation the first block is not processed; the end-of-document check reports the construct at its line", {
  lines <- c("---", "title: \"t\"", "abstract: |", "  Abstract of [many | one]{if=\"TRUE\"} sites", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "", "Body.", "")
  r <- rmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, at_line(r, file_line(lines, "Abstract of")))
  expect_true("unevaluated" %in% r$knit$failures$kind)
  expect_equal(r$knit$failures$line[r$knit$failures$kind == "unevaluated"], file_line(lines, "Abstract of"))
  # control: the front-matter route resolves the same abstract (see the first test)
  expect_false(rmd_html(fm_fields("rmd"))$failed)
})

test_that("9.2.5 (Quarto): with setup-chunk activation a construct in the abstract is reported, not printed raw", {
  skip_if_no_quarto()
  lines <- c("---", "title: \"t\"", "abstract: |", "  Abstract of [many | one]{if=\"TRUE\"} sites",
             "engine: knitr", "format: html", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "", "Body.", "")
  r <- qmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, at_line(r, file_line(lines, "Abstract of")))
})
