# Package 3d: figures and tables (L35: figure, table-caption; rules 5.9.1 to 5.9.3). Contract: dev/design-3.md
# L35 and the table after it. Helpers: helper-3.R, helper-3d.R.

fx <- function(lines, ext = "qmd", rules = c("figure", "table-caption")) {
  f3d_run(stats::setNames(list(lines), paste0("a.", ext)), rules)
}
# the part named in a finding's message
part <- function(x) {
  vapply(x$message, function(m) {
    if (grepl("alt text", m, ignore.case = TRUE)) "alt"
    else if (grepl("caption", m, ignore.case = TRUE)) "caption"
    else if (grepl("label", m, ignore.case = TRUE)) "label"
    else "?"
  }, "", USE.NAMES = FALSE)
}
chunk <- function(..., code = "plot(1)", header = "{r}") c(paste0("```", header), c(...), code, "```")

# ---- figure: chunks ----------------------------------------------------------------------------------

test_that("3d L35 figure: a chunk fig-d with fig-cap and no fig-alt is one finding about alt text", {
  x <- fx(chunk("#| label: fig-d", "#| fig-cap: \"Depth\""))
  expect_findings_shape(x)
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "figure")
  expect_identical(x$text, "fig-d")
  expect_identical(x$tier, 1L)
  expect_identical(x$spec, "5.9.1")
  expect_identical(part(x), "alt")
  expect_match(x$message, "\\(rule 5\\.9\\.1\\)\\.$")
})

test_that("3d L35 figure: a .qmd chunk depth with a caption and alt text but no fig- label is one finding about the label", {
  x <- fx(chunk("#| label: depth", "#| fig-cap: \"Depth\"", "#| fig-alt: \"A plot\""))
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "depth")
  expect_identical(part(x), "label")
})

test_that("3d L35 figure: a complete figure chunk is none, under fig-alt and fig.alt, in .qmd", {
  expect_none(fx(chunk("#| label: fig-d", "#| fig-cap: \"Depth\"", "#| fig-alt: \"A plot\"")))
  expect_none(fx(chunk("#| label: fig-d", "#| fig-cap: \"Depth\"", "#| fig.alt: \"A plot\"")))
  expect_none(fx(chunk("#| label: fig-d", "#| fig.cap: \"Depth\"", "#| fig-alt: \"A plot\"")))
  expect_none(fx(chunk("#| fig-cap: |", "#|   Depth", "#| fig-alt: |", "#|   A plot", "#| label: fig-d")))
  expect_none(fx(chunk(header = "{r fig-d, fig.cap=\"Depth\", fig.alt=\"A plot\"}")))
})

test_that("3d L35 figure: one finding per missing part", {
  # labelled fig-, nothing else: caption and alt text
  x <- fx(chunk("#| label: fig-d"))
  expect_identical(nrow(x), 2L)
  expect_identical(sort(part(x)), c("alt", "caption"))
  expect_true(all(x$text == "fig-d"))
  # a caption only, no label: label and alt text
  x <- fx(chunk("#| fig-cap: \"Depth\""))
  expect_identical(nrow(x), 2L)
  expect_identical(sort(part(x)), c("alt", "label"))
})

test_that("3d L35 figure: a chunk that plots with neither label nor caption is not seen", {
  expect_none(fx(chunk()))
  expect_none(fx(chunk("#| echo: false")))
  expect_none(fx(chunk("#| fig-alt: \"A plot\"")))
})

test_that("3d L35 figure: under .Rmd the label need not start fig-, and fig.cap makes a figure", {
  expect_none(fx(chunk(header = "{r depth, fig.cap=\"Depth\", fig.alt=\"A plot\"}"), ext = "Rmd"))
  x <- fx(chunk(header = "{r depth, fig.cap=\"Depth\"}"), ext = "Rmd")
  expect_identical(nrow(x), 1L)
  expect_identical(part(x), "alt")
  x <- fx(chunk(header = "{r, fig.cap=\"Depth\", fig.alt=\"A plot\"}"), ext = "Rmd")
  expect_identical(nrow(x), 0L, label = "an Rmd chunk with a caption and alt text, no label, is not a figure finding (chunk-label's)")
})

test_that("3d L35 figure: the position of a chunk finding is inside the chunk", {
  lines <- c("Words.", "", chunk("#| label: fig-d", "#| fig-cap: \"Depth\""))
  x <- fx(lines)
  expect_gte(x$line, 3L)
  expect_lte(x$line, 4L + 1L)
})

# ---- figure: images ----------------------------------------------------------------------------------

IMAGE_CASES <- list(
  list("![Depth](d.png)",                                  "label"),
  list("![Depth](d.png){#fig-d}",                          character()),
  list("![](d.png)",                                       "alt"),
  list("![](d.png){fig-alt=\"A chart\"}",                  character()),
  list("![Depth](d.png){fig-alt=\"A chart\"}",             "label"),
  list("![Depth](d.png){#fig-d fig-alt=\"A chart\"}",      character())
)

test_that("3d L35 figure: an image alone in its paragraph", {
  for (cs in IMAGE_CASES) {
    x <- fx(c("Words before.", "", cs[[1]], "", "Words after."), rules = "figure")
    expect_identical(sort(part(x)), cs[[2]], label = cs[[1]])
    if (nrow(x)) {
      expect_true(all(x$line == 3L), label = cs[[1]])
      expect_true(all(x$text == "d.png"), label = cs[[1]])
      expect_true(all(x$tier == 1L))
    }
  }
})

test_that("3d L35 figure: an image inside a sentence is not a figure", {
  expect_none(fx(c("A logo ![Depth](d.png) in a sentence.", "", "And another ![](e.png) here.")))
})

test_that("3d L35 figure: an image with empty bracket text and no fig-alt has no alt text, and only that", {
  x <- fx(c("![](d.png)"))
  expect_identical(nrow(x), 1L)
  expect_identical(part(x), "alt")
})

# ---- figure: divs ------------------------------------------------------------------------------------

test_that("3d L35 figure: a #fig- div takes its caption from its last paragraph and its alt text from its image", {
  ok <- c("::: {#fig-d}", "![Alt words](d.png)", "", "The caption words.", ":::")
  expect_none(fx(ok))
  # its image has no alt text
  bad <- c("::: {#fig-d}", "![](d.png)", "", "The caption words.", ":::")
  x <- fx(bad)
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "fig-d")
  expect_identical(part(x), "alt")
  # alt text given as an attribute on the image
  ok2 <- c("::: {#fig-d}", "![](d.png){fig-alt=\"A chart\"}", "", "The caption words.", ":::")
  expect_none(fx(ok2))
})

# ---- the table of the design -----------------------------------------------------------------------

test_that("3d L35 figure: the design's rows, in one project", {
  files <- list(
    "a.qmd" = c(chunk("#| label: fig-d", "#| fig-cap: \"Depth\""), "", chunk("#| label: depth", "#| fig-cap: \"D\"", "#| fig-alt: \"A\"")),
    "b.qmd" = c("![Depth](d.png)", "", "![Depth](e.png){#fig-e}", "", "![](f.png)"))
  x <- f3d_run(files, "figure")
  expect_identical(nrow(x), 4L)
  expect_identical(sort(paste(x$file, part(x))), sort(c("a.qmd alt", "a.qmd label", "b.qmd label", "b.qmd alt")))
})

# ---- table-caption -----------------------------------------------------------------------------------

test_that("3d L35 table-caption: a pipe table with no caption is a finding; with ': Sites {#tbl-s}' it is not", {
  tbl <- c("| a | b |", "|---|--:|", "| 1 | 2 |")
  both <- f3_both(function(ext) fx(c("Words.", "", tbl), ext = ext, rules = "table-caption"))
  for (x in both) {
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L)
    expect_identical(x$rule, "table-caption")
    expect_identical(x$tier, 1L)
    expect_identical(x$spec, "5.9.1")
    expect_identical(x$line, 3L)
    expect_match(x$message, "caption", ignore.case = TRUE)
  }
  both <- f3_both(function(ext) fx(c("Words.", "", tbl, "", ": Sites {#tbl-s}"), ext = ext, rules = "table-caption"))
  for (x in both) expect_none(x)
  # a caption with no id is still a caption
  expect_none(fx(c(tbl, "", ": Sites"), rules = "table-caption"))
})

test_that("3d L35 table-caption: a caption line above the table or below, a grid table, and two tables", {
  grid <- c("+---+---+", "| a | b |", "+===+===+", "| 1 | 2 |", "+---+---+")
  x <- fx(c("Words.", "", grid), rules = "table-caption")
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 3L)
  expect_none(fx(c(grid, "", ": Sites"), rules = "table-caption"))
  tbl <- c("| a | b |", "|---|---|", "| 1 | 2 |")
  x <- fx(c(tbl, "", "Words.", "", tbl, "", ": Second {#tbl-s}"), rules = "table-caption")
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 1L)
})

test_that("3d L35 table-caption: a #tbl- div's caption serves the table inside it", {
  ok <- c("::: {#tbl-s}", "| a | b |", "|---|---|", "| 1 | 2 |", "", "Sites sampled.", ":::")
  expect_none(fx(ok, rules = "table-caption"))
})

test_that("3d L35 table-caption: a .qmd chunk labelled tbl- needs tbl-cap", {
  x <- fx(chunk("#| label: tbl-s", code = "knitr::kable(x)"), rules = "table-caption")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "tbl-s")
  expect_none(fx(chunk("#| label: tbl-s", "#| tbl-cap: \"Sites\"", code = "knitr::kable(x)"), rules = "table-caption"))
  expect_none(fx(chunk("#| label: tbl-s", "#| tbl-cap: |", "#|   Sites", code = "knitr::kable(x)"), rules = "table-caption"))
})

test_that("3d L35 table-caption: a table in a code block is not a table", {
  lines <- c("```", "| a | b |", "|---|---|", "| 1 | 2 |", "```")
  expect_none(fx(lines, rules = "table-caption"))
})

test_that("3d L35: a figure and a table in one document each get their own rule", {
  lines <- c("| a |", "|---|", "| 1 |", "", "![Depth](d.png)")
  x <- fx(lines)
  expect_setequal(x$rule, c("table-caption", "figure"))
})

test_that("3d L35: the files limit applies to figure and table findings", {
  files <- list("a.qmd" = c("| a |", "|---|", "| 1 |"), "b.qmd" = c("| a |", "|---|", "| 1 |"))
  root <- lint_proj(files)
  x <- lints(root, files = "b.qmd", rules = "table-caption", tier = 1:2)
  expect_identical(x$file, "b.qmd")
})
