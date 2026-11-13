# Package 6d: the gate's counts for named values and for spans the filter resolves (N147 of dev/design-6.md; rule 6.3.1).
# Everything runs in temporary git repositories made by g_scenario() with git isolated. Helpers: helper-6d.R,
# helper-6k.R (cc6k), helper-4a.R (g_scenario, g_gate). Invented content only.
#
# READINGS of the note (see the report):
#  - a count is by kind: `value` for a named value, `span` for a filter span, as the gate's rows say it today for R
#    values and spans; a removal is a drop in the count of a kind in a file, as for every other construct (G12), so
#    renaming a value or moving it inside the file removes nothing;
#  - a `text` of a counted row is not pinned.

gdoc <- function(body, chunks = character()) w6d_doc(c("Intro paragraph.", "", body), chunks)
gpy <- w6d_py("x = 1")

# ---- count_constructs() ---------------------------------------------------------------------------------------------

test_that("N147: a named value is one row of kind value, on its line", {
  x <- cc6k(gdoc("The `depth`{.num} metres.", gpy))
  expect_identical(x$kind, "value")
  expect_identical(x$line, 7L)
})

test_that("N147: two named values on one line are two rows", {
  x <- cc6k(gdoc("The `depth`{.num} and `width`{.pct} metres.", gpy))
  expect_identical(x$kind, c("value", "value"))
})

FILTER_SPAN_SRC <- list(
  n    = r"{We saw [a site | # sites]{n="k"} today.}",
  `if` = r"{The level [rose | fell]{if="up"} again.}",
  sign = r"{The level [rose | fell]{sign="d"} again.}",
  list = r"{[No sites were | # was | # were]{list="flagged"} flagged.}"
)

test_that("N147: a span of a document the filter resolves is one row of kind span", {
  for (k in names(FILTER_SPAN_SRC)) {
    x <- cc6k(gdoc(FILTER_SPAN_SRC[[k]], gpy))
    expect_identical(x$kind, "span", label = k)
    expect_identical(x$line, 7L, label = k)
  }
})

test_that("N147: a named value and a filter span in one document are a value and a span", {
  x <- cc6k(gdoc(c("The `depth`{.num} metres.", "", FILTER_SPAN_SRC$n), gpy))
  expect_identical(sort(x$kind), c("span", "value"))
})

test_that("N147: a hand-written weft-values block and a values file are not counted", {
  blk <- c("````{.weft-values}", "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"3.14159\"}}}", "````")
  expect_identical(nrow(cc6k(gdoc(blk, gpy))), 0L)
  expect_identical(nrow(cc6k(gdoc(c("````{.weft-values file=\"vals.json\"}", "````"), gpy))), 0L)
  # control: the same document with a named value counts one
  expect_identical(nrow(cc6k(gdoc(c(blk, "", "The `depth`{.num} metres."), gpy))), 1L)
})

test_that("N147: in a knitr document a named value is a value beside an R value, and the hooks' span is a span", {
  lines <- c("Intro paragraph.", "", "The `depth`{.num} and `r x`{.num} and [a | b]{if=\"up\"}.")
  x <- cc6k(lines, ext = "Rmd")
  expect_identical(sort(x$kind), c("span", "value", "value"))
})

# ---- the gate: removing a named value or a filter span needs the trailer -----------------------------------------

test_that("N147: deleting a named value is a removal of kind value: the gate fails without the trailer", {
  d <- g_scenario(list("ch1.qmd" = gdoc(c("The `depth`{.num} metres.", "", "Then `width`{.num}."), gpy)),
                  list("ch1.qmd" = gdoc(c("The `depth`{.num} metres.", "", "Then nothing."), gpy)))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$removed$kind, "value")
  expect_true(grepl("ch1\\.qmd$", res$removed$file))
})

test_that("N147: with Weft-Removed: 1 the removal of a named value passes", {
  d <- g_scenario(list("ch1.qmd" = gdoc("The `depth`{.num} metres.", gpy)),
                  list("ch1.qmd" = gdoc("The metres.", gpy)))
  res <- g_gate(d, c("Drop a value", "", "Weft-Removed: 1"))
  expect_true(res$ok)
  expect_identical(res$trailer, 1L)
  expect_identical(res$n_removed, 1L)
})

test_that("N147: deleting a filter span is a removal of kind span", {
  for (k in names(FILTER_SPAN_SRC)) {
    d <- g_scenario(list("ch1.qmd" = gdoc(FILTER_SPAN_SRC[[k]], gpy)),
                    list("ch1.qmd" = gdoc("Plain words.", gpy)))
    res <- g_gate(d)
    expect_false(res$ok, label = k)
    expect_identical(res$n_removed, 1L, label = k)
    expect_identical(res$removed$kind, "span", label = k)
  }
})

test_that("N147: removing one of two named values on a line removes one", {
  d <- g_scenario(list("ch1.qmd" = gdoc("The `depth`{.num} and `width`{.num}.", gpy)),
                  list("ch1.qmd" = gdoc("The `depth`{.num} and width.", gpy)))
  expect_identical(g_gate(d)$n_removed, 1L)
})

test_that("N147: adding a named value or a filter span, renaming a value, or moving one in the file removes nothing", {
  d1 <- g_scenario(list("ch1.qmd" = gdoc("Plain words.", gpy)),
                   list("ch1.qmd" = gdoc(c("The `depth`{.num} metres.", "", FILTER_SPAN_SRC$n), gpy)))
  r1 <- g_gate(d1)
  expect_identical(r1$n_removed, 0L)
  expect_true(r1$ok)
  d2 <- g_scenario(list("ch1.qmd" = gdoc("The `depth`{.num} metres.", gpy)),
                   list("ch1.qmd" = gdoc("The `width`{.num} metres.", gpy)))
  expect_identical(g_gate(d2)$n_removed, 0L)
  d3 <- g_scenario(list("ch1.qmd" = gdoc(c("The `depth`{.num} metres.", "", "Later words."), gpy)),
                   list("ch1.qmd" = gdoc(c("Earlier words.", "", "The `depth`{.num} metres."), gpy)))
  expect_identical(g_gate(d3)$n_removed, 0L)
})

test_that("N147: changing the class of a named value, or its digits, removes nothing", {
  d <- g_scenario(list("ch1.qmd" = gdoc("The `depth`{.num} metres.", gpy)),
                  list("ch1.qmd" = gdoc("The `depth`{.num digits=\"2\"} metres.", gpy)))
  expect_identical(g_gate(d)$n_removed, 0L)
})

test_that("N147: removing a hand-written weft-values block, or a values-file block, removes nothing", {
  blk <- c("````{.weft-values}", "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"3.14159\"}}}", "````")
  d <- g_scenario(list("ch1.qmd" = gdoc(c("The `depth`{.num} metres.", "", blk), gpy)),
                  list("ch1.qmd" = gdoc(c("The `depth`{.num} metres."), gpy)))
  res <- g_gate(d)
  expect_identical(res$n_removed, 0L)
  expect_true(res$ok)
  vf <- c("````{.weft-values file=\"vals.json\"}", "````")
  d2 <- g_scenario(list("ch1.qmd" = gdoc(c("The `depth`{.num} metres.", "", vf), gpy), "vals.json" = "{}"),
                   list("ch1.qmd" = gdoc(c("The `depth`{.num} metres."), gpy), "vals.json" = NULL))
  expect_identical(g_gate(d2)$n_removed, 0L)
})

test_that("N147: a named value in a knitr document counts as a value there too, and its removal needs the trailer", {
  before <- c("Intro paragraph.", "", "The `depth`{.num} metres.", "", "```{r}", "weft_put(depth = 1)", "```", G_ENGINE)
  after <- c("Intro paragraph.", "", "The metres.", "", "```{r}", "weft_put(depth = 1)", "```", G_ENGINE)
  d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$removed$kind, "value")
})
