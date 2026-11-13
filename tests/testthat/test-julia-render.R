# Package 6h: `quarto render` of small .qmd files on the julia engine, with Weft.jl and the resolver filter
# (N20 to N31, N70 mirrored for Julia, N81, N89; measured 2, 3 and 6; messages E10 of dev/design-6.md
# section 7). Written before the code. Made-up values only. Helper: helper-julia-engine.R. Skipped when
# quarto or julia is absent.
#
# Four renders serve the file, each shared by the tests that read it: a document whose values print
# in prose; one whose cell fails (the render stops); one whose cell fails under `error: true` (it goes on);
# and one whose cells publish where the document cannot see them (draft mode).
#
# READINGS of the note (see the report, "Spec gaps" and "Waits on the filter fix"):
#  - the E10 tests wait on the filter fault of 6c: a name with no value crashes the filter under
#    `quarto render` instead of giving E10 (weft.lua near line 765). They are written per the design;
#  - the first line of a cell error is measured 3's: `ERROR: Julia server returned error after receiving
#    "run" command:`; the cell is located as `<path>/err.qmd:<the cell's first line>`, the line of its
#    fence, as measured; the stack lines Julia and Deno add after it are not pinned;
#  - the exact HTML Quarto writes around the text is not pinned, only the resolved text inside it.

jle_kill_at_file_end()

squish <- function(x) trimws(gsub("[[:space:]\u00a0]+", " ", x))

VALUES_QMD <- c(
  "---",
  "title: 'Depth of `depth`{.num digits=\"1\"} metres'",
  "---",
  "",
  "```{julia}",
  "#| include: false",
  "using Weft",
  "```",
  "",
  "```{julia}",
  "#| echo: false",
  "depth = 3.14159",
  "n_sites = 4",
  "site = \"Alpha\"",
  "unused_value = 99",
  "@put depth n_sites site",
  "```",
  "",
  "The depth is `depth`{.num digits=\"2\"} metres at `site`{.val}, over `n_sites`{.num} sites.",
  "",
  "```{julia}",
  "#| echo: false",
  "Weft.put(measured=2.5)",
  "```",
  "",
  "The second reading is `measured`{.num digits=\"2\"} metres.",
  "",
  "The end."
)

SOFT_QMD <- c(
  "---",
  "title: Soft",
  "---",
  "",
  "```{julia}",
  "#| label: soft",
  "#| error: true",
  "soft_value = undefined_thing + 1",
  "```",
  "",
  "After the error."
)

ERR_QMD <- c(
  "---",
  "title: Err",
  "---",
  "",
  "Some text.",
  "",
  "```{julia}",
  "#| label: bad",
  "x = 1",
  "undefined_thing + x",
  "```",
  "",
  "More text."
)

HIDDEN_QMD <- c(
  "---",
  "title: Hidden",
  "---",
  "",
  "```{julia}",
  "#| include: false",
  "using Weft",
  "Weft.put(hid_a=1)",
  "```",
  "",
  "```{julia}",
  "#| output: false",
  "Weft.put(hid_b=2)",
  "```",
  "",
  "```{julia}",
  "#| echo: false",
  "Weft.put(shown_c=3)",
  "```",
  "",
  "Uses `hid_a`{.num}.",
  "",
  "Then `hid_b`{.num}.",
  "",
  "Then `shown_c`{.num}."
)

render_values <- function() {
  if (!is.null(.jle$values)) return(.jle$values)
  dir <- jle_project(list(`values.qmd` = VALUES_QMD))
  res <- jle_render(dir, "values.qmd")
  .jle$values <- list(res = res, values = jle_read(dir, "values.html"))
}

render_err <- function() {
  if (!is.null(.jle$err)) return(.jle$err)
  dir <- jle_project(list(`err.qmd` = ERR_QMD, `soft.qmd` = SOFT_QMD))
  res <- jle_render(dir, "err.qmd")
  soft <- jle_render(dir, "soft.qmd")
  .jle$err <- list(res = res, html = jle_read(dir, "err.html"), files = tree(dir), soft = soft,
                   soft_html = jle_read(dir, "soft.html"))
}

render_hidden <- function() {
  if (!is.null(.jle$hidden)) return(.jle$hidden)
  dir <- jle_project(list(`hidden.qmd` = HIDDEN_QMD))
  res <- jle_render(dir, "hidden.qmd", env = c(WEFT_DRAFT = "1"))
  .jle$hidden <- list(res = res, html = jle_read(dir, "hidden.html"))
}

test_that("N70, N81: values published by @put and by Weft.put() on the julia engine print in prose and in the title", {
  x <- render_values()
  expect_identical(x$res$status, 0L, label = x$res$log)
  txt <- squish(strip_tags(x$values))
  expect_true(grepl("The depth is 3.14 metres at Alpha, over 4 sites.", txt, fixed = TRUE))
  expect_true(grepl("The second reading is 2.50 metres.", txt, fixed = TRUE))
  expect_true(grepl("<title>Depth of 3.1 metres", x$values, fixed = TRUE), label = "the title")
  expect_true(grepl("Depth of 3.1 metres", txt, fixed = TRUE))
  # only what @put named was published
  expect_false(grepl("unused_value", x$values, fixed = TRUE))
  expect_false(grepl("<<weft:", jle_unesc(x$values), fixed = TRUE))
  # nothing was reported
  expect_false(grepl("weft:", x$res$stderr, fixed = TRUE), label = x$res$stderr)
})

test_that("N31, measured 2: the carrier blocks leave no trace in the output, and no empty output div", {
  x <- render_values()
  expect_identical(x$res$status, 0L, label = "the project rendered")
  expect_true(grepl("The depth is", squish(strip_tags(x$values)), fixed = TRUE), label = "the document was written")
  expect_false(grepl("weft-values", x$values, fixed = TRUE))
  expect_false(grepl("\"weft\":1", x$values, fixed = TRUE))
  expect_false(grepl("\"lang\":\"julia\"", x$values, fixed = TRUE))
  expect_false(grepl("cell-output", x$values, fixed = TRUE))
})

test_that("measured 3: a cell with `error: true` shows its error in a cell-output-error div, and the render goes on", {
  x <- render_err()
  expect_identical(x$soft$status, 0L, label = x$soft$log)
  expect_true(grepl("cell-output-error", x$soft_html, fixed = TRUE))
  expect_true(grepl("UndefVarError", x$soft_html, fixed = TRUE))
  expect_true(grepl("After the error.", x$soft_html, fixed = TRUE))
})

test_that("measured 3: a cell error without `error: true` stops the render, with Quarto's message and the cell's first line", {
  x <- render_err()
  expect_true(x$res$status != 0L)
  log <- gsub("\033\\[[0-9;]*m", "", x$res$log)
  lines <- strsplit(log, "\n")[[1]]
  errs <- grep("ERROR:", lines, fixed = TRUE, value = TRUE)
  expect_identical(errs[1], "ERROR: Julia server returned error after receiving \"run\" command:")
  expect_true(any(grepl("^Failed to run notebook: .*err\\.qmd$", lines)), label = "names the notebook")
  expect_true(any(lines == "EvaluationError: Encountered 1 error during evaluation"))
  fence <- which(ERR_QMD == "#| label: bad") - 1L
  expect_true(any(grepl(sprintf("^@ .*err\\.qmd:%d$", fence), lines)), label = "the cell's first line")
  expect_true(any(lines == "UndefVarError: `undefined_thing` not defined in `Main.Notebook`"))
  # the first of those lines comes before the rest, in the order measured
  pos <- function(p) grep(p, lines, fixed = TRUE)[1]
  expect_true(pos("ERROR: Julia server") < pos("Failed to run notebook") &&
                pos("Failed to run notebook") < pos("EvaluationError") &&
                pos("EvaluationError") < pos("UndefVarError"))
  # no page was written
  expect_identical(x$html, "")
  expect_false("err.html" %in% x$files)
})

test_that("E10, N72's Julia form: a name published only in a cell with include: false or output: false is `no value`, and the hint says so", {
  x <- render_hidden()
  err <- x$res$stderr
  expect_identical(x$res$status, 0L, label = paste("draft mode: the exit is 0;", x$res$log))
  for (nm in c("hid_a", "hid_b")) {
    expect_true(grepl(fm_msg$E10(nm), err, fixed = TRUE), label = paste("E10 for", nm))
    expect_true(grepl(fm_msg$E10_hint(nm), err, fixed = TRUE), label = paste("the hint for", nm))
  }
  expect_false(grepl(fm_msg$E10("shown_c"), err, fixed = TRUE))
  expect_true(any(grepl(rx_failures(2), fm_lines(err))), label = "one report of two failures")
  html <- jle_unesc(x$html)
  l_a <- grep("Uses `hid_a`", HIDDEN_QMD, fixed = TRUE)
  l_b <- grep("Then `hid_b`", HIDDEN_QMD, fixed = TRUE)
  expect_true(grepl(sprintf("<<weft: no value, line %d>>", l_a), html, fixed = TRUE))
  expect_true(grepl(sprintf("<<weft: no value, line %d>>", l_b), html, fixed = TRUE))
  expect_true(grepl("Then 3.", squish(strip_tags(html)), fixed = TRUE), label = "the published name prints")
  expect_true(any(grepl(sprintf("^  hidden\\.qmd:%d  ", l_a), strsplit(err, "\n")[[1]])))
})
