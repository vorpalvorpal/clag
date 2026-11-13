# Package 6d: the pre-render script and named values (rule 2.5.4; N150 of dev/design-6.md; message E75). The script
# is plain base R, so it runs with Rscript in a temporary project; no Quarto is needed. Helpers: helper-6d.R,
# helper-3.R (lint_proj). Invented content only; nothing runs outside the temporary folder.
#
# READINGS of the note (see the report):
#  - "fails" is exit status 1 with the file named on stderr; "passes" is exit status 0 and no "holds a weft construct";
#  - the construct is quoted as today's message quotes it, the line the construct is on (the first 60 characters of it),
#    so a line used here is shorter than 60 characters;
#  - the sentence E75 is on stderr, once, whatever the number of files that failed;
#  - cite and text-class spans, and a reserved word as an operand, are not pinned (the note is silent).

pre_run <- function(files, inputs = NULL, env = parent.frame()) {
  script <- system.file("quarto", "weft-pre-render.R", package = "weft")
  if (!expect_precondition(nzchar(script) && file.exists(script), "the package ships its pre-render script")) {
    return(invisible(NULL))
  }
  root <- lint_proj(files, env = env)
  withr::local_envvar(c(QUARTO_PROJECT_INPUT_FILES = if (is.null(inputs)) NA else inputs, WEFT_RUN = NA),
                      .local_envir = env)
  out <- suppressWarnings(withr::with_dir(root, system2(file.path(R.home("bin"), "Rscript"), shQuote(script),
                                                         stdout = TRUE, stderr = TRUE)))
  list(root = root, status = as.integer(attr(out, "status") %||% 0L), log = paste(out, collapse = "\n"))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

QYML <- c("project:", "  type: default", "format: html")
pre_doc <- function(line, front = "title: t") c("---", front, "---", "", line)

expect_stops <- function(res, file = "a.qmd", line = NULL, label = NULL) {
  expect_identical(res$status, 1L, label = label)
  expect_true(grepl(file, res$log, fixed = TRUE), label = paste(label, "names the file"))
  expect_true(grepl("has no `engine: knitr` in its own front matter", res$log, fixed = TRUE),
              label = paste(label, "today's message"))
  expect_true(grepl(W6D_E75, res$log, fixed = TRUE), label = paste(label, "E75"))
  if (!is.null(line)) expect_true(grepl(line, res$log, fixed = TRUE), label = paste(label, "quotes the construct"))
}
expect_passes <- function(res, label = NULL) {
  expect_identical(res$status, 0L, label = label)
  expect_false(grepl("holds a weft construct", res$log, fixed = TRUE), label = paste(label, "no complaint"))
}

# ---- a document that holds an R value fails, with E75 ------------------------------------------------------------------

test_that("N150, E75: a .qmd with an R value and no engine: knitr of its own fails, naming the file, quoting the construct, with E75", {
  for (src in c("The depth is `r x`{.num} here.", "The depth is `R x`{.num} here.", "The depth is `{r} x`{.num} here.")) {
    res <- pre_run(list("_quarto.yml" = QYML, "a.qmd" = pre_doc(src)))
    expect_stops(res, line = src, label = src)
  }
})

test_that("N150, E75: a jupyter-engine document with an R value fails as well", {
  res <- pre_run(list("_quarto.yml" = QYML, "a.qmd" = pre_doc("The depth is `r x`{.num} here.", c("title: t", "engine: jupyter"))))
  expect_stops(res, line = "The depth is `r x`{.num} here.")
})

test_that("N150, E75: engine: knitr in _quarto.yml does not count; in the document's own front matter it passes", {
  q <- c("project:", "  type: default", "engine: knitr")
  expect_stops(pre_run(list("_quarto.yml" = q, "a.qmd" = pre_doc("The depth is `r x`{.num} here."))))
  expect_passes(pre_run(list("_quarto.yml" = q,
                             "a.qmd" = pre_doc("The depth is `r x`{.num} here.", c("title: t", "engine: knitr")))))
})

# ---- a span whose governor does not fit N9 and N12 fails -------------------------------------------------------------------

BAD_GOVERNORS <- c(
  r"{We saw [a site | # sites]{n="3"} today.}",
  r"{We saw [a site | # sites]{n="x + 1"} today.}",
  r"{The level [rose | fell]{if="a && b"} again.}",
  r"{The level [rose | fell]{if="a || b"} again.}",
  r"{The level [rose | fell]{if="len(x) > 2"} again.}",
  r"{The level [rose | fell]{if="3 > 2"} again.}",
  r"{The level [rose | fell]{if="0 < x < 1"} again.}",
  r"{The level [rose | fell]{if="a + 1 > b"} again.}",
  r"{The level [rose | fell]{if="!x"} again.}",
  r"{The level [rose | fell]{if="a,,b"} again.}",
  r"{The level [rose | fell]{if="n > 10, a && b"} again.}",
  r"{The level [rose | fell]{sign="3"} again.}",
  r"{The level [rose | fell]{sign="."} again.}",
  r"{[No sites were | # was | # were]{list="3"} flagged.}",
  r"{[No sites were | # was | # were]{list="#d"} flagged.}"
)

test_that("N150, E75: a span whose governor is not a condition or a name of N9 and N12 fails, quoting it, with E75", {
  for (src in BAD_GOVERNORS) {
    res <- pre_run(list("_quarto.yml" = QYML, "a.qmd" = pre_doc(src)))
    expect_stops(res, line = src, label = src)
  }
})

# ---- a document of named values and grammar spans passes ---------------------------------------------------------------------

GOOD_DOCS <- c(
  "The depth is `depth`{.num} metres.",
  "The site is `site`{.val} and the sites `sites`{.val .and}.",
  "The depth is `n.sites`{.pct} and `_x`{digits=\"2\"}.",
  "Words ` depth `{.num} more.",
  r"{The level [rose | fell]{if="up"} again.}",
  r"{The level [rose | fell]{if="n_gap > 10, n_sites >= 3"} again.}",
  r"{The level [rose | fell]{if="n>10"} again.}",
  r"{The level [rose | fell]{if="s == 'north'"} again.}",
  r"{The level [rose | fell]{if="s == 'a,b'"} again.}",
  r"{The level [rose | fell]{if="x <= -1.5e3"} again.}",
  r"{We saw [a site | # sites]{n="k"} today.}",
  r"{We saw [a site | # sites]{n="."} today.}",
  r"{We saw [a site | # sites]{n="#d"} today.}",
  r"{The level [rose | fell]{sign="d"} again.}",
  r"{The level [rose | fell]{sign="#d"} again.}",
  r"{[No sites were | # was | # were]{list="flagged"} flagged.}",
  "The `depth`{.num} and [a | b]{if=\"up\"} and [c | d]{n=\"k\"}."
)

test_that("N150: a .qmd with only named values and spans that fit the grammar passes the check", {
  for (src in GOOD_DOCS) {
    res <- pre_run(list("_quarto.yml" = QYML, "a.qmd" = pre_doc(src)))
    expect_passes(res, label = src)
  }
})

test_that("N150: the same on a document with python chunks and with no front matter at all", {
  chunk <- c("```{python}", "depth = 1", "```")
  expect_passes(pre_run(list("_quarto.yml" = QYML, "a.qmd" = c("The `depth`{.num} metres.", "", chunk))))
  expect_passes(pre_run(list("_quarto.yml" = QYML,
                             "a.qmd" = pre_doc("The `depth`{.num} metres.", c("title: t", "engine: jupyter")))))
})

test_that("N150: a named value in a code span or fence, or escaped, is no construct either way (control)", {
  expect_passes(pre_run(list("_quarto.yml" = QYML, "a.qmd" = c("```", "`r x`{.num}", "```", "", "Plain."))))
})

# ---- mixed documents ----------------------------------------------------------------------------------------------------------

test_that("N150: an R value beside named values fails; a bad span beside good ones fails", {
  expect_stops(pre_run(list("_quarto.yml" = QYML,
                            "a.qmd" = pre_doc(c("The `depth`{.num} metres.", "", "And `r x`{.num} more.")))))
  expect_stops(pre_run(list("_quarto.yml" = QYML,
                            "a.qmd" = pre_doc(c(r"{The level [rose | fell]{if="up"} again.}", "",
                                                r"{We saw [a site | # sites]{n="3"} today.}")))))
})

test_that("N150, E75: with several documents only the failing ones are named; the good one is not", {
  res <- pre_run(list("_quarto.yml" = QYML,
                      "good.qmd" = pre_doc("The `depth`{.num} metres."),
                      "bad.qmd" = pre_doc("The depth is `r x`{.num} here."),
                      "also-bad.qmd" = pre_doc(r"{We saw [a site | # sites]{n="3"} today.}")))
  expect_identical(res$status, 1L)
  expect_true(grepl("bad.qmd", res$log, fixed = TRUE))
  expect_true(grepl("also-bad.qmd", res$log, fixed = TRUE))
  expect_false(grepl("good.qmd", res$log, fixed = TRUE))
  expect_true(grepl(W6D_E75, res$log, fixed = TRUE))
})

test_that("N150 control: the render stops before it opens the collection file, so .weft/failures.jsonl is not written", {
  res <- pre_run(list("_quarto.yml" = QYML, "a.qmd" = pre_doc("The depth is `r x`{.num} here.")))
  expect_identical(res$status, 1L)
  expect_false(file.exists(file.path(res$root, ".weft", "failures.jsonl")))
})

test_that("N150 control: a project with no construct at all passes and opens the collection file", {
  res <- pre_run(list("_quarto.yml" = QYML, "a.qmd" = pre_doc("Plain words only.")))
  expect_passes(res)
  expect_true(file.exists(file.path(res$root, ".weft", "failures.jsonl")))
})
