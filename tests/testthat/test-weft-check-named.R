# Package 6c: the changes to weft-check.lua (dev/design-6.md N94, N93, E35). The existing weft-check tests
# (test-filter-direct.R and the rest) are not touched; these cover only what 6c changes:
#   (a) weft-check unwraps span.weft-marker and does not report the marker text inside it;
#   (b) a code span that is a named value, left in the tree, gets E35 in place of "a code span carries
#       the weft class";
#   (c) everything else is as today.
# Runs weft-check.lua alone where the point is what it does on a tree weft.lua never saw, and both
# filters where the point is what it does after weft.lua. While inst/quarto/weft.lua does not exist the
# tests that run it fail on that; the weft-check-only runs need no weft.lua.

only_check <- "weft-check.lua"

test_that("N94b, E35: a named value left in the tree says the resolver filter is not installed", {
  cases <- list(
    num = "Depth `depth`{.num} m.", pct = "Share `share`{.pct}.", val = "Site `site`{.val}.",
    key_only = "Places `n`{digits=\"2\"}.", dotted = "Count `n.sites`{.num}.", with_id = "Depth `depth`{#d .num} m.")
  for (nm in names(cases)) {
    res <- filter_md(cases[[nm]], filters = only_check)
    expect_identical(res$status, 1L, label = paste("status for", nm))
    expect_true(grepl(fm_msg$E35, res$stderr, fixed = TRUE), label = paste("E35 for", nm))
    expect_false(grepl("a code span carries the weft", res$stderr, fixed = TRUE), label = paste("old text for", nm))
  }
})

test_that("N94b: E35 is the finding's message, in the layout of the other findings", {
  res <- filter_md("Depth `depth`{.num} m.", filters = only_check)
  expect_match(res$stderr, "weft-check: 1 leftover weft construct", fixed = TRUE)
  expect_match(res$stderr, paste0("  - ", fm_msg$E35), fixed = TRUE)
})

test_that("N94c: a code span whose text is not a name keeps the message of today", {
  for (txt in c("x + 1", "cfg.depth[1]", "{python} x")) {
    res <- filter_md(sprintf("Depth `%s`{.num} m.", txt), filters = only_check)
    expect_identical(res$status, 1L, label = txt)
    expect_true(grepl("a code span carries the weft class `.num`", res$stderr, fixed = TRUE), label = txt)
    expect_false(grepl(fm_msg$E35, res$stderr, fixed = TRUE), label = txt)
  }
})

test_that("N94c: a code span of R code keeps its messages, not E35", {
  res <- filter_md("Depth `r x`{.num} m.", filters = only_check)
  expect_identical(res$status, 1L)
  expect_true(grepl("a code span carries the weft class `.num`", res$stderr, fixed = TRUE))
  expect_false(grepl(fm_msg$E35, res$stderr, fixed = TRUE))
  res2 <- filter_md("Depth `r x`{#d} m.", filters = only_check)
  expect_identical(res2$status, 1L)
  expect_true(grepl("a code span with an attribute block holds R code that was not run", res2$stderr, fixed = TRUE))
  expect_false(grepl(fm_msg$E35, res2$stderr, fixed = TRUE))
})

test_that("N94a: a span of class weft-marker is unwrapped, and its marker text is not reported", {
  md <- "Depth [<<weft: no value, line 3>>]{.weft-marker} m."
  res <- filter_md(md, filters = only_check)
  expect_identical(res$status, 0L)
  expect_false(grepl("weft-check", res$stderr, fixed = TRUE))
  expect_false(grepl("weft-marker", res$output, fixed = TRUE))
  expect_match(res$output, "<p>Depth &lt;&lt;weft: no value, line 3&gt;&gt; m.</p>", fixed = TRUE)
})

test_that("N94a: a marker typed as plain text is still reported, as today", {
  res <- filter_md("Depth <<weft: no value, line 3>> m.", filters = only_check)
  expect_identical(res$status, 1L)
  expect_true(grepl("weft-check", res$stderr, fixed = TRUE))
  expect_true(grepl("<<weft:", res$stderr, fixed = TRUE))
})

test_that("N86, N94a: the markers weft.lua makes do not trip weft-check in draft mode, and leave no span in the output", {
  md <- c(carrier(depth = fr_with(fr_int("7"), fr_check("> 10"))), "",
          "Depth `depth`{.num} m.", "", "Gone `miss`{.num} here.")
  res <- filter_md(md, env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  expect_false(grepl("weft-check", res$stderr, fixed = TRUE))
  expect_false(grepl("weft-marker", res$output, fixed = TRUE))
  expect_match(res$output, "Depth 7&lt;&lt;weft: failed claim, line 5&gt;&gt; m.", fixed = TRUE)
  expect_match(res$output, "Gone &lt;&lt;weft: no value, line 7&gt;&gt; here.", fixed = TRUE)
})

test_that("N94a: a marker typed by hand beside weft.lua's own is still the only thing weft-check reports", {
  md <- c(carrier(depth = fr_int("7")), "", "Depth `depth`{.val}.", "", "Typed <<weft: failed claim, line 9>> here.")
  res <- filter_md(md)
  expect_identical(res$status, 1L)
  expect_true(grepl("weft-check", res$stderr, fixed = TRUE))
})

test_that("N93: the filter changes nothing else: a document with no named value comes out as Pandoc alone writes it", {
  md <- c("# A heading with `code` and [a span]{.foo}", "",
          "Text with `x`{.python}, a [link](https://example.org), *emphasis*, [small]{.smallcaps} and",
          "`y`{#anchor}.", "",
          "| a | b |", "|---|---|", "| 1 | 2 |", "",
          "::: {.note}", "A div with `z`.", ":::")
  with_filters <- filter_md(md)
  baseline <- filter_md(md, filters = character())
  expect_identical(baseline$status, 0L)
  expect_identical(with_filters$status, 0L)
  expect_identical(with_filters$output, baseline$output)
  expect_false(grepl("weft", with_filters$stderr, fixed = TRUE))
})
