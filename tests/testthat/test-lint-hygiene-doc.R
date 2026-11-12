# Package 3d: hygiene of documents and the project (L34: section-anchor, chunk-label, file-link,
# config-place, engine; rules 5.8 numbers 1, 4, 8, 9). Contract: dev/design-3.md L34 and the table after L35.
# Helpers: helper-3.R, helper-3d.R.

hy <- function(files, rules, ...) f3d_run(files, rules, ...)

# ---- section-anchor ---------------------------------------------------------------------------------

test_that("3d L34 section-anchor: a heading with no {#id} is a finding with the heading's text, in .qmd and .Rmd", {
  lines <- c("# Title {#sec-t}", "", "Words.", "", "## Results", "", "Words.", "", "### Detail {.unnumbered}")
  both <- f3_both(function(ext) hy(stats::setNames(list(lines), paste0("a.", ext)), "section-anchor"))
  for (x in both) {
    expect_findings_shape(x)
    expect_texts(x, "section-anchor", c("Results", "Detail"))
    expect_true(all(x$tier == 1L))
    expect_at(x, "section-anchor", "Results", line = 5L, col = c(1L, 4L))
    expect_at(x, "section-anchor", "Detail", line = 9L, col = c(1L, 5L))
  }
})

test_that("3d L34 section-anchor: headings that have an id, in any position of the attribute block, are not listed", {
  lines <- c("# A {#sec-a}", "", "## B {#sec-b .unnumbered}", "", "### C {.unnumbered #sec-c}", "",
             "#### D {#sec-d}", "", "# E {#intro}")
  expect_none(hy(list("a.qmd" = lines), "section-anchor"))
})

test_that("3d L34 section-anchor: [x](#results) to a heading with no id gives section-anchor and nothing else", {
  lines <- c("# Results", "", "See [x](#results).")
  x <- hy(list("a.qmd" = lines), c("section-anchor", "xref", "anchor-twice", "file-link"))
  expect_identical(x$rule, "section-anchor")
  expect_identical(x$text, "Results")
})

test_that("3d L34 section-anchor: a setext heading is a heading; a rule after a blank line is not", {
  lines <- c("Results", "-------", "", "Words.", "", "Methods", "=======", "", "Words.", "", "---", "", "More words.")
  x <- hy(list("a.qmd" = lines), "section-anchor")
  expect_texts(x, "section-anchor", c("Results", "Methods"))
  expect_at(x, "section-anchor", "Results", line = 1L, col = 1L)
  expect_at(x, "section-anchor", "Methods", line = 6L, col = 1L)
  # a setext heading with an id
  expect_none(hy(list("a.qmd" = c("Results {#sec-r}", "-------", "", "Words.")), "section-anchor"))
})

test_that("3d L34 section-anchor: a # line in a chunk, a fence or a comment is no heading, and #hashtag is not one", {
  lines <- c("# T {#sec-t}", "", "```{r}", "# a comment in code", "x <- 1", "```", "", "```", "# in a fence", "```", "",
             "<!--", "# in a comment", "-->", "", "#hashtag and ####### seven.", "")
  expect_none(hy(list("a.qmd" = lines), "section-anchor"))
})

test_that("3d L34 section-anchor: front matter's --- is no setext heading", {
  expect_none(hy(list("a.qmd" = c("---", "title: T", "---", "", "# H {#sec-h}")), "section-anchor"))
})

test_that("3d L34 section-anchor: closing #s are not part of the text", {
  x <- hy(list("a.qmd" = c("## Results ##", "", "Words.")), "section-anchor")
  expect_texts(x, "section-anchor", "Results")
})

test_that("3d L34 section-anchor: a .md file is never linted", {
  x <- hy(list("a.qmd" = "# A {#sec-a}\n", "notes.md" = c("# No id", "", "Words.")), "section-anchor")
  expect_none(x)
})

# ---- chunk-label ------------------------------------------------------------------------------------

test_that("3d L34 chunk-label: an executed chunk with no label is a finding at its opening line; with a label it is not", {
  unlabelled <- list(
    c("```{r}", "x <- 1", "```"),
    c("```{r, echo=FALSE}", "x <- 1", "```"),
    c("```{r}", "#| echo: false", "x <- 1", "```"),
    c("```{r}", "# label: a", "x <- 1", "```"),
    c("```{r, fig.cap=\"Depth\"}", "x <- 1", "```")
  )
  for (ch in unlabelled) {
    lines <- c("Words.", "", ch)
    both <- f3_both(function(ext) hy(stats::setNames(list(lines), paste0("a.", ext)), "chunk-label"))
    for (x in both) {
      expect_identical(nrow(x), 1L, label = paste(ch, collapse = " / "))
      expect_identical(x$line, 3L)
      expect_identical(x$tier, 1L)
      expect_match(x$text, "x <- 1", fixed = TRUE)
      expect_match(x$text, "\\br\\b")
    }
  }
  labelled <- list(
    c("```{r a}", "x <- 1", "```"),
    c("```{r, label=\"a\"}", "x <- 1", "```"),
    c("```{r a, echo=FALSE}", "x <- 1", "```"),
    c("```{r}", "#| label: a", "x <- 1", "```"),
    c("```{r setup, include=FALSE}", "x <- 1", "```")
  )
  for (ch in labelled) {
    both <- f3_both(function(ext) hy(stats::setNames(list(c("Words.", "", ch)), paste0("a.", ext)), "chunk-label"))
    for (x in both) expect_none(x)
  }
})

test_that("3d L34 chunk-label: a chunk of any engine; text names the engine and the first code line", {
  lines <- c("```{python}", "import os", "```", "", "```{bash}", "ls", "```", "", "```{python}", "#| label: py", "import sys", "```")
  x <- hy(list("a.qmd" = lines), "chunk-label")
  expect_identical(nrow(x), 2L)
  expect_identical(sort(x$line), c(1L, 5L))
  expect_match(x$text[x$line == 1L], "python", fixed = TRUE)
  expect_match(x$text[x$line == 1L], "import os", fixed = TRUE)
  expect_match(x$text[x$line == 5L], "bash", fixed = TRUE)
  expect_match(x$text[x$line == 5L], "ls", fixed = TRUE)
})

test_that("3d L34 chunk-label: a fenced block that is not a chunk is not listed", {
  lines <- c("```r", "x <- 1", "```", "", "```", "plain", "```", "", "```{=html}", "<p>x</p>", "```", "", "~~~", "y", "~~~")
  expect_none(hy(list("a.qmd" = lines), "chunk-label"))
})

# ---- file-link --------------------------------------------------------------------------------------

test_that("3d L34 file-link: a link or image target with no scheme that names no file is a finding", {
  files <- list("a.qmd" = c("See [d](data/x.csv) and [p](pics/a.png) and ![alt words](pics/b.png).",
                            "",
                            "And [ok](here.txt) and ![fine](pics/c.png)."),
                "here.txt" = "x", "pics/c.png" = "x")
  x <- hy(files, "file-link")
  expect_findings_shape(x)
  expect_texts(x, "file-link", c("data/x.csv", "pics/a.png", "pics/b.png"))
  expect_true(all(x$tier == 1L))
  expect_true(all(x$line == 1L))
  lines <- files[["a.qmd"]]
  expect_at(x, "file-link", "data/x.csv", line = 1L, col = f3d_col(lines, "data/x.csv") + (-1:0))
})

test_that("3d L34 file-link: a present file, a file at the root named from a subfolder document, URLs, anchors and empty targets are not findings", {
  files <- list("ch/a.qmd" = c("See [x](/img/a.png), [y](../data/x.csv), [z](https://x.org/q), [m](mailto:a@x.org),",
                               "[f](ftp://x.org/f), [t](tel:123), [p](//cdn.x.org/a.js), [h](#sec-h), [e]().", "",
                               "# H {#sec-h}"),
                "img/a.png" = "x", "data/x.csv" = "x")
  expect_none(hy(files, "file-link"))
  # from the document's folder, data/x.csv is not found
  x <- hy(list("ch/a.qmd" = "See [y](data/x.csv).\n", "data/x.csv" = "x"), "file-link")
  expect_texts(x, "file-link", "data/x.csv")
  expect_identical(x$file, "ch/a.qmd")
})

test_that("3d L34 file-link: ? and # parts are dropped, %20 is decoded, a title is not part of the target", {
  files <- list("a.qmd" = c("[a](data/x.csv?v=2) [b](b.qmd#sec-b) [c](my%20file.pdf) [d](a.png \"A title\")",
                            "", "[e](gone.csv?v=2) [f](gone%20too.pdf)"),
                "data/x.csv" = "x", "b.qmd" = "# B {#sec-b}\n", "my file.pdf" = "x", "a.png" = "x")
  x <- hy(files, "file-link")
  expect_identical(length(x$text), 2L)
  expect_true(all(x$line == 3L))
  expect_true(any(grepl("gone.csv", x$text, fixed = TRUE)))
  expect_true(any(grepl("gone", x$text[!grepl("gone.csv", x$text, fixed = TRUE)], fixed = TRUE)))
})

test_that("3d L34 file-link: [x](b.qmd#sec-b) with no b.qmd is file-link and no xref", {
  x <- hy(list("a.qmd" = "See [x](b.qmd#sec-b).\n"), c("file-link", "xref"))
  expect_identical(x$rule, "file-link")
  expect_identical(x$text, "b.qmd")
})

test_that("3d L34 file-link: links in code, fences and comments are not links", {
  lines <- c("A `[x](gone.csv)` here.", "", "```", "[y](gone2.csv)", "```", "", "<!-- [z](gone3.csv) -->")
  expect_none(hy(list("a.qmd" = lines), "file-link"))
})

test_that("3d L34 file-link: under .Rmd, and the line of the link in a later paragraph", {
  lines <- c("Words.", "", "More words and [d](gone.csv).")
  x <- hy(list("a.Rmd" = lines), "file-link")
  expect_at(x, "file-link", "gone.csv", line = 3L)
})

# ---- config-place -----------------------------------------------------------------------------------

test_that("3d L34 config-place: a weft: key in _quarto.yml or a _metadata.yml is a finding in context project", {
  files <- list("_quarto.yml" = c("project:", "  type: book", "weft:", "  draft: false"),
                "ch/_metadata.yml" = c("title: x", "weft:", "  label_words: [Site]"),
                "a.qmd" = "Words.\n", "ch/b.qmd" = "Words.\n")
  x <- hy(files, "config-place")
  expect_findings_shape(x)
  expect_identical(nrow(x), 2L)
  expect_true(all(x$text == "weft"))
  expect_true(all(x$context == "project"))
  expect_true(all(x$tier == 1L))
  expect_at(x, "config-place", "weft", line = 3L, file = "_quarto.yml")
  expect_at(x, "config-place", "weft", line = 2L, file = "ch/_metadata.yml")
})

test_that("3d L34 config-place: a _quarto.yml with no weft: key is none; the project files are not read when files is given", {
  expect_none(hy(list("_quarto.yml" = c("project:", "  type: book"), "a.qmd" = "Words.\n"), "config-place"))
  files <- list("_quarto.yml" = c("project:", "  type: book", "weft:", "  draft: false"), "a.qmd" = "Words.\n")
  root <- lint_proj(files)
  expect_identical(nrow(lints(root, rules = "config-place", tier = 1:2)), 1L)
  expect_none(lints(root, files = "a.qmd", rules = "config-place", tier = 1:2))
})

test_that("3d L34 config-place: draft or decisions under a document's weft: where _weft.yml exists", {
  for (key in c("draft", "decisions")) {
    lines <- c("---", "title: T", "weft:", paste0("  ", key, ": true"), "---", "", "Words.")
    both <- f3_both(function(ext) hy(stats::setNames(list(lines), paste0("a.", ext)), "config-place", weft_yml = "draft: false"))
    for (x in both) {
      expect_identical(nrow(x), 1L, label = key)
      expect_identical(x$text, key)
      expect_identical(x$tier, 1L)
      expect_at(x, "config-place", key, line = 4L)
    }
    # no _weft.yml: nothing to place it in
    expect_none(hy(list("a.qmd" = lines), "config-place"))
  }
})

test_that("3d L34 config-place: other weft: keys in a document's front matter are fine; the flow form {draft: true} is found", {
  lines <- c("---", "weft:", "  label_words: [Site]", "---", "", "Words.")
  expect_none(hy(list("a.qmd" = lines), "config-place", weft_yml = "draft: false"))
  flow <- c("---", "weft: {draft: true}", "---", "", "Words.")
  x <- hy(list("a.qmd" = flow), "config-place", weft_yml = "draft: false")
  expect_texts(x, "config-place", "draft")
})

# ---- engine -----------------------------------------------------------------------------------------

test_that("3d L34 engine: a .qmd with a construct and no engine: knitr is a finding at line 1", {
  lines <- c("# A {#sec-a}", "", r"{Words [a site]{if="ok"} more.}")
  x <- hy(list("a.qmd" = lines), "engine")
  expect_findings_shape(x)
  expect_identical(nrow(x), 1L)
  expect_identical(x$file, "a.qmd")
  expect_identical(x$line, 1L)
  expect_identical(x$tier, 1L)
})

test_that("3d L34 engine: with engine: knitr in its own front matter, or named with a leading underscore, or in .Rmd, it is none", {
  body <- c(r"{Words [a site]{if="ok"} more.}")
  expect_none(hy(list("a.qmd" = f3d_doc(body, "engine: knitr")), "engine"))
  expect_none(hy(list("_a.qmd" = body), "engine"))
  expect_none(hy(list("a.Rmd" = body), "engine"))
  # engine: knitr in the project file is not the document's own metadata block
  x <- hy(list("_quarto.yml" = c("project:", "  type: default", "engine: knitr"), "a.qmd" = body), "engine")
  expect_identical(nrow(x), 1L)
  # a different engine
  x <- hy(list("a.qmd" = f3d_doc(body, "engine: jupyter")), "engine")
  expect_identical(nrow(x), 1L)
})

test_that("3d L34 engine: bare values, links and literals alone do not need it; every other construct does", {
  none <- list("Words `r x` more.", "A [link](a.html) here.", "A [10]{.weft-literal why=\"SOP\"} here.")
  for (b in none) expect_none(hy(list("a.qmd" = b), "engine"))
  needs <- list("A `r x`{.num} here.", r"{A [a site | sites]{n="k"} here.}", r"{A [x]{sign="y"} here.}",
                r"{A [x]{list="y"} here.}", r"{A [x]{cite="smith2020"} here.}")
  for (b in needs) expect_identical(nrow(hy(list("a.qmd" = b), "engine")), 1L, label = b)
})

test_that("3d L34 engine: a document that another includes, or has as a child, is not alone, so none", {
  body <- r"{Words [a site]{if="ok"} more.}"
  files <- list("a.qmd" = body, "index.qmd" = c("# Home {#sec-h}", "", "{{< include a.qmd >}}"))
  # index itself holds no construct, so nothing is listed at all
  expect_none(hy(files, "engine"))
  # a child chunk, header and option forms
  files <- list("a.qmd" = body, "index.qmd" = c("```{r, child=\"a.qmd\"}", "```"))
  expect_none(hy(files, "engine"))
  files <- list("a.qmd" = body, "index.qmd" = c("```{r}", "#| child: a.qmd", "```"))
  expect_none(hy(files, "engine"))
  # an include path relative to the including file, from a subfolder
  files <- list("ch/a.qmd" = body, "ch/index.qmd" = "{{< include a.qmd >}}\n")
  expect_none(hy(files, "engine"))
  # not included: still listed
  files <- list("ch/a.qmd" = body, "ch/index.qmd" = "Words.\n")
  expect_identical(hy(files, "engine")$file, "ch/a.qmd")
})

test_that("3d L34 engine: findings follow the files limit", {
  body <- r"{Words [a site]{if="ok"} more.}"
  root <- lint_proj(list("a.qmd" = body, "b.qmd" = body))
  expect_identical(lints(root, files = "a.qmd", rules = "engine", tier = 1:2)$file, "a.qmd")
})

# ---- the file set -----------------------------------------------------------------------------------

test_that("3d L3: documents under a folder that starts with _ or . or is renv are not read, so give no finding", {
  files <- list("a.qmd" = "# A {#sec-a}\n", "_extras/b.qmd" = "# B\n", ".hidden/c.qmd" = "# C\n", "renv/d.qmd" = "# D\n")
  x <- hy(files, "section-anchor")
  expect_none(x)
})
