# Package 3b: the `block-start` lint (L18, rules 2.10.5 and Q9; K2; contract: dev/design-3.md).
# The R half runs by default; with reader = "pandoc" the two Pandoc trees are compared as well.
# ASCII only.

bs <- function(lines, ext = "qmd", weft_yml = NULL, ..., env = parent.frame()) {
  lint_one(lines, rules = "block-start", ext = ext, weft_yml = weft_yml, ..., env = env)
}

# a span whose second line is `mid`; the bracket closes on the third line
span3 <- function(mid, attr = "{n=\"k\"}") c("[a site |", mid, paste0("b]", attr))

# ---- the finding ----------------------------------------------------------------------------------

test_that("3b L18: a line inside a span that starts with # is a tier-1 finding (Q9)", {
  lines <- c("Intro words.", "", "[a site |", "# sites]{n=\"k\"}")
  for (e in c("qmd", "Rmd")) {
    x <- bs(lines, e)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L)
    expect_identical(x$rule, "block-start")
    expect_identical(x$tier, 1L)
    expect_identical(x$spec, "2.10.5")
    expect_identical(x$text, "#")
    expect_identical(x$line, 4L)
    expect_identical(x$col, 1L)
    expect_identical(x$context, "prose")
    expect_identical(x$message,
      paste0("Line 4 inside a span starts with `#`, which Pandoc reads as a heading, so the span ",
             "is cut in two (rule 2.10.5)."))
    expect_false(is.na(x$hint))
    expect_match(x$hint, "re-wrap", ignore.case = TRUE)
  }
})

test_that("3b L18: the same words on one line give nothing", {
  expect_identical(nrow(bs("[a site | # sites]{n=\"k\"}")), 0L)
  expect_identical(nrow(bs(c("[a site |", "x # sites]{n=\"k\"}"))), 0L)
})

test_that("3b L18: block markers, and what is not one", {
  rows <- list(
    list("# sites", "#"), list("## sites", "##"), list("###### sites", "######"),
    list("####### sites", NULL), list("#sites", NULL), list("#", "#"),
    list("> quoted", ">"), list("- item", "-"), list("-item", NULL), list("+ item", "+"),
    list("* item", "*"), list("1. item", "1."), list("12) item", "12)"),
    list("123456789. item", "123456789."), list("1234567890. item", NULL), list("1.item", NULL),
    list("``` code", "```"), list("~~~", "~~~"), list("::: div", ":::"), list("`` code", NULL),
    list("plain words", NULL), list("a - b", NULL))
  for (r in rows) {
    for (e in c("qmd", "Rmd")) {
      x <- bs(span3(r[[1]]), e)
      if (is.null(r[[2]])) {
        expect_identical(nrow(x), 0L, info = r[[1]])
      } else {
        expect_identical(x$text, r[[2]], info = r[[1]])
        expect_identical(x$line, 2L, info = r[[1]])
        expect_identical(x$col, 1L, info = r[[1]])
      }
    }
  }
})

test_that("3b L18: up to three spaces of indentation count, four do not", {
  expect_identical(bs(span3(" # sites"))$col, 2L)
  expect_identical(bs(span3("  - item"))$col, 3L)
  x <- bs(span3("   # sites"))
  expect_identical(x$text, "#")
  expect_identical(x$col, 4L)
  expect_identical(nrow(bs(span3("    # sites"))), 0L)
})

test_that("3b L18: every kind of span row is checked", {
  attrs <- c("{n=\"k\"}", "{if=\"ok\"}", "{sign=\"d\"}", "{list=\"ks\"}", "{cite=\"smith2020\"}",
             "{.strong}", "{.weft-literal why=\"reason\"}")
  for (a in attrs) {
    for (e in c("qmd", "Rmd")) {
      x <- bs(span3("# sites", a), e)
      expect_identical(x$text, "#", info = a)
      expect_identical(x$line, 2L, info = a)
    }
  }
})

test_that("3b L18: a bracket with no weft construct is not a span row", {
  expect_identical(nrow(bs(span3("# sites", ""))), 0L)
  expect_identical(nrow(bs(c("[a", "# b](u.html)"))), 0L)
  expect_identical(nrow(bs(span3("# sites", "{.smallcaps}"))), 0L)
  expect_identical(nrow(bs(span3("# sites", "{.x}"))), 0L)
})

test_that("3b L18: only the lines after the one with [ up to the one with ] are checked", {
  # the [ line itself
  expect_identical(nrow(bs(c("# [a |", "b]{n=\"k\"}"))), 0L)
  # a line after the ] line
  expect_identical(nrow(bs(c("[a |", "b]{n=\"k\"}", "# Heading"))), 0L)
  # the ] line counts
  expect_identical(bs(c("[a |", "# b]{n=\"k\"}"))$line, 2L)
})

test_that("3b L18: several markers and several spans give one finding each", {
  x <- bs(c("[a |", "# b", "- c]{n=\"k\"}", "", "[d |", "> e]{if=\"ok\"}"))
  expect_identical(x$text, c("#", "-", ">"))
  expect_identical(x$line, c(2L, 3L, 6L))
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

test_that("3b L18/K2: Q9 is found with reader = 'pandoc' too", {
  n3_skip_no_pandoc()
  x <- bs(c("Intro words.", "", "[a site |", "# sites]{n=\"k\"}"), reader = "pandoc")
  expect_true("block-start" %in% x$rule)
  expect_true(4L %in% x$line)
  w <- bs(c("Intro words.", "", "[a site |", "- sites]{n=\"k\"}"), reader = "pandoc")
  expect_true(4L %in% w$line)
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
  doc <- c("[a site |", "# sites]{n=\"k\"}", "", "[b |", "- c]{if=\"ok\"}", "", "Intro.", "",
           "    [3 sites]{n=\"k\"} here")
  w <- bs(doc, reader = "weft")
  p <- bs(doc, reader = "pandoc")
  key <- function(z) paste(z$line, z$col, z$text)
  expect_true(nrow(w) >= 3L)
  expect_true(all(key(w) %in% key(p)))
})
