# Package 3b: the `block-start` lint (L18, rules 2.10.5 and Q9; K2; contract: dev/design-3.md).
# The R half runs by default; with reader = "pandoc" the two Pandoc trees are compared as well.
# ASCII only.

bs <- function(lines, ext = "qmd", weft_yml = NULL, ..., env = parent.frame()) {
  lint_one(lines, rules = "block-start", ext = ext, weft_yml = weft_yml, ..., env = env)
}

# a span whose second line is `mid`; the bracket closes on the third line
span3 <- function(mid, attr = "{n=\"k\"}") c("[a site |", mid, paste0("b]", attr))

# ---- the finding ----------------------------------------------------------------------------------

test_that("3b L18: a closed backtick fence inside a span is a tier-1 finding (Q9, review-3 Q1)", {
  lines <- c("Intro words.", "", "[a site |", "```", "code", "```", "b]{n=\"k\"}")
  for (e in c("qmd", "Rmd")) {
    x <- bs(lines, e)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L)
    expect_identical(x$rule, "block-start")
    expect_identical(x$tier, 1L)
    expect_identical(x$spec, "2.10.5")
    expect_identical(x$text, "```")
    expect_identical(x$line, 4L)
    expect_identical(x$col, 1L)
    expect_identical(x$context, "prose")
    expect_match(x$message, "^Line 4 inside a span starts with `")
    expect_match(x$message, "(rule 2.10.5).", fixed = TRUE)
    expect_false(is.na(x$hint))
    expect_match(x$hint, "re-wrap", ignore.case = TRUE)
  }
})

test_that("3b L18: a line that starts with # inside a span is not a finding: Pandoc's markdown keeps the span (review-3 Q1)", {
  for (e in c("qmd", "Rmd")) {
    expect_identical(nrow(bs(c("Intro words.", "", "[a site |", "# sites]{n=\"k\"}"), e)), 0L)
  }
})

test_that("3b L18: the same words on one line give nothing", {
  expect_identical(nrow(bs("[a site | # sites]{n=\"k\"}")), 0L)
  expect_identical(nrow(bs(c("[a site |", "x # sites]{n=\"k\"}"))), 0L)
})

test_that("3b L18: block markers that Pandoc's markdown reader does not cut at give no finding (review-3 Q1)", {
  rows <- c("# sites", "## sites", "###### sites", "####### sites", "#sites", "#", "> quoted", "- item", "-item",
            "+ item", "* item", "1. item", "12) item", "123456789. item", "1234567890. item", "1.item",
            "``` code", "~~~", "::: div", "`` code", "plain words", "a - b", "$$", "| a | b |")
  for (r in rows) {
    for (e in c("qmd", "Rmd")) expect_identical(nrow(bs(span3(r), e)), 0L, info = paste(r, e))
  }
})

test_that("3b L18: indentation does not make a non-cutting marker a finding", {
  for (m in c(" # sites", "  - item", "   # sites", "    # sites")) expect_identical(nrow(bs(span3(m))), 0L, info = m)
})

test_that("3b L18: a fence indented up to three spaces counts, four do not", {
  fence <- function(ind) c("[a site |", paste0(ind, "```"), "code", paste0(ind, "```"), "b]{n=\"k\"}")
  x <- bs(fence("  "))
  expect_identical(x$text, "```")
  expect_identical(x$col, 3L)
  expect_identical(nrow(bs(fence("    "))), 0L)
})

test_that("3b L18: every kind of span row is checked", {
  attrs <- c("{n=\"k\"}", "{if=\"ok\"}", "{sign=\"d\"}", "{list=\"ks\"}", "{cite=\"smith2020\"}",
             "{.strong}", "{.weft-literal why=\"reason\"}")
  for (a in attrs) {
    for (e in c("qmd", "Rmd")) {
      x <- bs(c("[a site |", "```", "code", "```", paste0("b]", a)), e)
      expect_identical(x$text, "```", info = a)
      expect_identical(x$line, 2L, info = a)
    }
  }
})

test_that("3b L18: a bracket with no weft construct is not a span row", {
  expect_identical(nrow(bs(c("[a site |", "```", "code", "```", "b]"))), 0L)
  expect_identical(nrow(bs(c("[a", "# b](u.html)"))), 0L)
  expect_identical(nrow(bs(c("[a site |", "```", "code", "```", "b]{.smallcaps}"))), 0L)
  expect_identical(nrow(bs(c("[a site |", "```", "code", "```", "b]{.x}"))), 0L)
})

test_that("3b L18: only the lines after the one with [ up to the one with ] are checked", {
  fence <- c("```", "code", "```")
  # the [ line itself
  expect_identical(nrow(bs(c("``` [a |", "b]{n=\"k\"}"))), 0L)
  # a fence after the ] line
  expect_identical(nrow(bs(c("[a |", "b]{n=\"k\"}", fence))), 0L)
  # the fence inside counts
  expect_identical(bs(c("[a |", fence, "b]{n=\"k\"}"))$line, 2L)
})

test_that("3b L18: several fences and several spans give one finding each", {
  f <- c("```", "x", "```")
  x <- bs(c("[a |", f, "b]{n=\"k\"}", "", "[d |", f, "e]{if=\"ok\"}"))
  expect_identical(x$text, c("```", "```"))
  # lines: 1 "[a |", 2-4 fence, 5 "b]{..}", 6 blank, 7 "[d |", 8-10 fence, 11 "e]{..}"
  expect_identical(x$line, c(2L, 8L))
})

test_that("3b L18: a marker inside a fenced block is not a finding", {
  expect_identical(nrow(bs(c("```text", "[a |", "# b]{n=\"k\"}", "```"))), 0L)
})

# ---- indented constructs -------------------------------------------------------------------------

test_that("3b L18: a construct that starts a line indented four spaces after a blank line is listed", {
  doc <- c("Intro words.", "", "    [3 sites]{n=\"k\"} here")
  for (e in c("qmd", "Rmd")) {
    x <- bs(doc, e)
    expect_identical(nrow(x), 1L)
    expect_identical(x$line, 3L)
    expect_identical(x$rule, "block-start")
    expect_identical(x$tier, 1L)
  }
})

test_that("3b L18: an indented construct in a list item, or without a blank line, is not listed", {
  expect_identical(nrow(bs(c("- item", "", "    [3 sites]{n=\"k\"} here"))), 0L)
  expect_identical(nrow(bs(c("Intro words.", "    [3 sites]{n=\"k\"} here"))), 0L)
  expect_identical(nrow(bs(c("Intro words.", "", "   [3 sites]{n=\"k\"} here"))), 0L)
})

# ---- the Pandoc comparison (K2) -------------------------------------------------------------------

test_that("3b L18/K2: a cut by a closed fence is found with reader = 'pandoc' too", {
  n3_skip_no_pandoc()
  x <- bs(c("Intro words.", "", "[a site |", "```", "code", "```", "b]{n=\"k\"}"), reader = "pandoc")
  expect_true("block-start" %in% x$rule)
  expect_true(4L %in% x$line)
})

test_that("3b L18/K2: a block that differs between the masked and unmasked trees is listed only by reader = 'pandoc'", {
  n3_skip_no_pandoc()
  doc <- c("Some `r max(a,", "# comment", "b)`{.num} text.")
  expect_identical(nrow(bs(doc)), 0L)
  expect_identical(nrow(bs(doc, reader = "weft")), 0L)
  for (e in c("qmd", "Rmd")) {
    x <- bs(doc, e, reader = "pandoc")
    expect_true(nrow(x) >= 1L)
    expect_true(2L %in% x$line)
    expect_true(all(x$rule == "block-start"))
    expect_true(all(x$tier == 1L))
  }
})

test_that("3b L18/K2: where masking changes no block, reader = 'pandoc' adds no finding", {
  n3_skip_no_pandoc()
  doc <- c("---", "title: T", "---", "", "Intro words.", "", "[3 sites]{if=\"n > 2\"} remain wet.", "",
           "[a site | # sites]{n=\"k\"} too.", "", "Some `r x`{.num} text.", "", "- item", "- [x]{.strong}")
  for (e in c("qmd", "Rmd")) {
    expect_identical(nrow(bs(doc, e, reader = "pandoc")), 0L)
    expect_identical(nrow(bs(doc, e, reader = "weft")), 0L)
  }
})

test_that("3b L18/K2: with reader = 'pandoc' every finding of the R reader is still there", {
  n3_skip_no_pandoc()
  doc <- c("[a site |", "```", "x", "```", "b]{n=\"k\"}", "", "[b |", "```", "y", "```", "c]{if=\"ok\"}", "",
           "Intro.", "", "    [3 sites]{n=\"k\"} here")
  w <- bs(doc, reader = "weft")
  p <- bs(doc, reader = "pandoc")
  key <- function(z) paste(z$line, z$col, z$text)
  expect_true(nrow(w) >= 3L)
  expect_true(all(key(w) %in% key(p)))
})
