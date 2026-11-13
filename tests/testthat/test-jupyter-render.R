# Package 6e: `quarto render` of small .qmd files on the jupyter engine, with the Python package and the
# resolver filter (N20 to N31, N53, N70 to N72, N81, N86, N89, N91; messages E10, E15, E34, E55 of
# dev/design-6.md section 7). Written before the code. Made-up values only. Helper: helper-jupyter.R.
# Skipped when quarto or a Python with jupyter_client and ipykernel is absent.
#
# Every render is shared by the tests that read it: the project is rendered once, inside a function that
# also reads what the tests need, and the result is kept for the file. Four renders in all: one project
# (draft mode, so that every document is written), one failing claim, one stopped by an unhandled claim,
# and one project with freeze rendered twice.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - {check} of E15 for an operator check ("> 10"): shown as written or as "_ > 10"; the tests take either;
#  - the freeze project's {file} in E34 is matched as any path ending in the document's name;
#  - the exact HTML Quarto writes around a caption is not pinned, only the resolved text inside it.

squish <- function(x) trimws(gsub("[[:space:]\u00a0]+", " ", x))
unesc_html <- function(x) gsub("&gt;", ">", gsub("&lt;", "<", gsub("&amp;", "&", x, fixed = TRUE), fixed = TRUE), fixed = TRUE)

VALUES_QMD <- c(
  "---",
  "title: 'Depth of `depth`{.num digits=\"1\"} metres'",
  "---",
  "",
  "```{python}",
  "#| include: false",
  "from weft import auto, put",
  "auto()",
  "```",
  "",
  "```{python}",
  "#| echo: false",
  "depth = 3.14159",
  "n_sites = 4",
  "site = 'Alpha'",
  "unused_value = 99",
  "```",
  "",
  "The depth is `depth`{.num digits=\"2\"} metres at `site`{.val}, over `n_sites`{.num} sites.",
  "",
  "```{python}",
  "#| echo: false",
  "put(measured=2.5)",
  "```",
  "",
  "The second reading is `measured`{.num digits=\"2\"} metres.",
  "",
  "```{python}",
  "#| label: tbl-sites",
  "#| echo: false",
  "#| tbl-cap: 'Mean depth is `depth`{.num digits=\"1\"} m over `n_sites`{.num} sites'",
  "from IPython.display import Markdown",
  "Markdown('| a | b |\\n|---|---|\\n| 1 | 2 |')",
  "```",
  "",
  "The end."
)

HIDDEN_QMD <- c(
  "---",
  "title: Hidden",
  "---",
  "",
  "```{python}",
  "#| include: false",
  "from weft import put",
  "put(hid_a=1)",
  "```",
  "",
  "```{python}",
  "#| output: false",
  "put(hid_b=2)",
  "```",
  "",
  "```{python}",
  "#| echo: false",
  "put(shown_c=3)",
  "```",
  "",
  "Uses `hid_a`{.num}.",
  "",
  "Then `hid_b`{.num}.",
  "",
  "Then `shown_c`{.num}."
)

CLAIM_QMD <- c(
  "---",
  "title: Claim",
  "---",
  "",
  "```{python}",
  "#| label: chk",
  "#| error: true",
  "from weft import claim",
  "n = 7",
  "claim(n, '> 10')",
  "```",
  "",
  "Some prose."
)

STOP_QMD <- sub("#| error: true", "#| echo: true", CLAIM_QMD, fixed = TRUE)

FREEZE_QMD <- c(
  "---",
  "title: Freeze",
  "---",
  "",
  "```{python}",
  "#| echo: false",
  "from weft import put",
  "put(depth=3.14159)",
  "```",
  "",
  "The depth is `depth`{.num digits=\"2\"} metres."
)

render_values <- function() {
  if (!is.null(.jup$values)) return(.jup$values)
  dir <- qm_project(list(`values.qmd` = VALUES_QMD, `hidden.qmd` = HIDDEN_QMD))
  res <- qm_render(dir, env = c(WEFT_DRAFT = "1"))
  .jup$values <- list(res = res, values = qm_read(dir, "values.html"), hidden = qm_read(dir, "hidden.html"),
                      files = tree(dir))
}

render_claim <- function() {
  if (!is.null(.jup$claim)) return(.jup$claim)
  dir <- qm_project(list(`claim.qmd` = CLAIM_QMD, `stop.qmd` = STOP_QMD))
  failed <- qm_render(dir, "claim.qmd")
  stopped <- qm_render(dir, "stop.qmd")
  .jup$claim <- list(failed = failed, stopped = stopped)
}

render_freeze <- function() {
  if (!is.null(.jup$freeze)) return(.jup$freeze)
  dir <- qm_project(list(`freeze.qmd` = FREEZE_QMD),
                    project_yml = c("project:", "  type: default", "execute:", "  freeze: auto", "format: html"))
  first <- qm_render(dir, env = c(WEFT_RUN = "run-one"))
  second <- qm_render(dir, env = c(WEFT_RUN = "run-two"))
  .jup$freeze <- list(first = first, second = second, html = qm_read(dir, "freeze.html"))
}

test_that("N70, N71, N81: values published by put() and by auto() print in prose, in the caption and in the title", {
  x <- render_values()
  expect_identical(x$res$status, 0L, label = x$res$log)
  txt <- squish(strip_tags(x$values))
  expect_true(grepl("The depth is 3.14 metres at Alpha, over 4 sites.", txt, fixed = TRUE))
  expect_true(grepl("The second reading is 2.50 metres.", txt, fixed = TRUE))
  expect_true(grepl("Mean depth is 3.1 m over 4 sites", txt, fixed = TRUE), label = "the table caption")
  expect_true(grepl("<title>Depth of 3.1 metres", x$values, fixed = TRUE), label = "the title")
  expect_true(grepl("Depth of 3.1 metres", txt, fixed = TRUE))
  expect_false(grepl("unused_value", x$values, fixed = TRUE))
  expect_false(grepl("<<weft:", unesc_html(x$values), fixed = TRUE))
})

test_that("N31: the carrier blocks leave no trace in the output", {
  x <- render_values()
  expect_identical(x$res$status, 0L, label = "the project rendered")
  expect_true(grepl("The depth is", squish(strip_tags(x$values)), fixed = TRUE), label = "the document was written")
  expect_false(grepl("weft-values", x$values, fixed = TRUE))
  expect_false(grepl("\"weft\":1", x$values, fixed = TRUE))
  expect_false(grepl("\"lang\":\"python\"", x$values, fixed = TRUE))
})

test_that("E10, N72: a name published only in a cell with include: false or output: false is `no value`, and the hint says so", {
  x <- render_values()
  err <- x$res$log
  expect_identical(x$res$status, 0L, label = "draft mode: the exit is 0")
  for (nm in c("hid_a", "hid_b")) {
    expect_true(grepl(fm_msg$E10(nm), err, fixed = TRUE), label = paste("E10 for", nm))
    expect_true(grepl(fm_msg$E10_hint(nm), err, fixed = TRUE), label = paste("the hint for", nm))
  }
  expect_false(grepl(fm_msg$E10("shown_c"), err, fixed = TRUE))
  expect_true(any(grepl(rx_failures(2), fm_lines(x$res$stderr))), label = "one report of two failures")
  # the marker takes the place of each construct, with the line of the construct in the source
  html <- unesc_html(x$hidden)
  l_a <- grep("Uses `hid_a`", HIDDEN_QMD, fixed = TRUE)
  l_b <- grep("Then `hid_b`", HIDDEN_QMD, fixed = TRUE)
  expect_true(grepl(sprintf("<<weft: no value, line %d>>", l_a), html, fixed = TRUE))
  expect_true(grepl(sprintf("<<weft: no value, line %d>>", l_b), html, fixed = TRUE))
  expect_true(grepl("Then 3.", squish(strip_tags(html)), fixed = TRUE), label = "the published name prints")
  # the report's entries name the document and the line
  expect_true(any(grepl(sprintf("^  hidden\\.qmd:%d  ", l_a), strsplit(err, "\n")[[1]])))
})

test_that("N53, N25b, N86, E15: a failed claim under `error: true` is reported with the cell's label, never twice as two claims, and the render exits 1", {
  x <- render_claim()$failed
  expect_identical(x$status, 1L)
  lines <- strsplit(x$stderr, "\n")[[1]]
  # one claim failed: every report heading says so (stderr holds the report of the filter and, today, a
  # second one of the post-render script; the entry is the same in each)
  heads <- grep("^weft: ", lines, value = TRUE)
  expect_true(length(heads) >= 1L)
  expect_true(all(grepl(rx_claims(1), heads)))
  entries <- grep("chunk chk", lines, value = TRUE)
  expect_true(length(entries) >= 1L)
  expect_length(unique(entries), 1L)
  e <- fm_entry(x$stderr, "^  claim\\.qmd chunk chk  ")
  expect_true(e$found)
  expect_true(grepl("claim(\u2026, '> 10')", e$head, fixed = TRUE))
  expect_length(e$detail, 1L)
  expect_match(e$detail, "^(_ )?> 10 was false \\(value 7\\)$")
  expect_true(any(grepl("Do not loosen a claim to clear this.", lines, fixed = TRUE)))
})

test_that("N53, E55: without `error: true` the render stops with Quarto's traceback, whose last line is E55", {
  x <- render_claim()$stopped
  expect_true(x$status != 0L)
  log <- gsub("\033\\[[0-9;]*m", "", x$log)
  expect_match(log, "ClaimFailed: weft: a claim failed: (_ )?> 10 was false \\(value 7\\)\\.")
  # the filter never ran, so it reports nothing
  expect_false(grepl("(^|\n)weft: [0-9]+ claim", x$stderr))
})

test_that("N91, E34: a project with freeze: auto rendered twice gives the stale-run notice on the second render only, once", {
  x <- render_freeze()
  expect_identical(x$first$status, 0L, label = x$first$log)
  expect_identical(x$second$status, 0L, label = x$second$log)
  expect_false(grepl("were published by run", x$first$log, fixed = TRUE))
  pat <- paste0("weft: the values in (.*)freeze\\.qmd were published by run run-one, not this run \\(run-two\\): ",
                "served from freeze or a cache, or by a kernel kept from an earlier render\\. ",
                "Their checks did not run now \\(rule 2\\.13\\.8\\)\\.")
  expect_length(gregexpr(pat, x$second$stderr)[[1]][gregexpr(pat, x$second$stderr)[[1]] > 0], 1L)
  expect_match(x$second$stderr, pat)
  # it fails nothing: the frozen values still print
  expect_true(grepl("The depth is 3.14 metres.", squish(strip_tags(x$html)), fixed = TRUE))
})
