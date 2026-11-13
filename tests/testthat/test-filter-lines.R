# Package 6c: lines (dev/design-6.md N89; rule 2.13.6). The filter finds each construct's line by
# searching the source text: a named value by `NAME`{ and a span by KEY="VALUE", each the next occurrence
# after the previous one of the same needle, in tree order, chosen arm or not; fenced code blocks and HTML
# comments are blanked (the lines starting `#|` stay); included files keep their own file and line.
# A construct whose needle is not found has no line. The failures here are "no value" (a name nobody
# published), in draft mode so that the markers show in the output. While inst/quarto/weft.lua does not
# exist every test fails on that.

draft1 <- c(WEFT_DRAFT = "1")
NV <- "<<weft: no value, line {L}>>"
lines_block <- function() carrier(a = fr_bool(TRUE), f = fr_bool(FALSE))

test_that("N89: repeated identical constructs get their own lines, two on one line share it", {
  cases <- c(r1 = "One `m`{.num}.", r2 = "Two `m`{.num}.", r3 = "Three `m`{.num} and `m`{.num}.",
             r4 = "Four `m`{.num}.")
  res <- filter_cases(cases, list(lines_block()), draft = TRUE)
  expect_cases(res, c(r1 = paste0("One ", NV, "."), r2 = paste0("Two ", NV, "."),
                      r3 = paste0("Three ", NV, " and ", NV, "."), r4 = paste0("Four ", NV, ".")))
  expect_true(all(diff(res$line) > 0))
})

test_that("N89: a construct in an arm not chosen still takes its occurrence in the source", {
  cases <- c(unchosen = "A [`m`{.num} | y]{if=\"f\"}.", after = "B `m`{.num}.",
             chosen = "C [`m`{.num} | y]{if=\"a\"}.")
  res <- filter_cases(cases, list(lines_block()), draft = TRUE)
  expect_cases(res, c(unchosen = "A y.", after = paste0("B ", NV, "."), chosen = paste0("C ", NV, ".")))
})

test_that("N89: a span is found by its key and value, identical spans one after the other", {
  s <- "[x | y]{if=\"nothere > 1\"}"
  cases <- c(sp1 = paste0("A ", s, "."), sp2 = paste0("B ", s, "."), sp3 = paste0("C ", s, "."))
  res <- filter_cases(cases, list(lines_block()), draft = TRUE)
  expect_cases(res, c(sp1 = paste0("A ", NV, "."), sp2 = paste0("B ", NV, "."), sp3 = paste0("C ", NV, ".")))
})

test_that("N89: a construct inside a fenced code block is not matched, nor one in an HTML comment", {
  md <- c(lines_block(), "",
          "```r", "x <- \"`m`{.num}\"", "```", "",
          "<!-- a comment holding `m`{.num}", "and again `m`{.num} -->", "",
          "Real `m`{.num}.")
  res <- filter_md(md, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  want <- sprintf("Real <<weft: no value, line %d>>.", length(md))
  expect_true(grepl(want, res$output, fixed = TRUE))
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", length(md)))
  expect_true(e$found)
})

test_that("N89: a title from the front matter is found on its line in the source", {
  md <- c("---", "title: \"Depth `q`{.num}\"", "---", "", "Body.")
  res <- filter_md(md, to = "html", args = "-s", env = draft1)
  expect_identical(res$status, 0L)
  expect_true(grepl("Depth &lt;&lt;weft: no value, line 2&gt;&gt;", strip_tags(res$output), fixed = TRUE))
})

test_that("N89: a table caption is found on its line in the source", {
  md <- c("| a |", "|---|", "| 1 |", "", ": Cap `q`{.num}")
  res <- filter_md(md, to = "html", env = draft1)
  expect_identical(res$status, 0L)
  expect_true(grepl("Cap &lt;&lt;weft: no value, line 5&gt;&gt;", strip_tags(res$output), fixed = TRUE))
})

test_that("N89: a `#|` line inside a fenced block is searched; the other lines of the block are blanked", {
  md <- c("```r", "#| tbl-cap: \"Depth `q`{.num}\"", "x <- 1 # `rr`{.num}", "```", "", "Body.")
  # the title and subtitle come from a metadata file, so they are not in the source at all
  meta <- c("title: \"Depth `q`{.num}\"", "subtitle: \"Sub `rr`{.num}\"")
  res <- filter_md(md, files = list(meta.yaml = meta), to = "html", env = draft1,
                   args = c("-s", "--metadata-file=meta.yaml"))
  expect_identical(res$status, 0L)
  txt <- strip_tags(res$output)
  expect_true(grepl("Depth &lt;&lt;weft: no value, line 2&gt;&gt;", txt, fixed = TRUE))
  expect_true(grepl("Sub &lt;&lt;weft: no value&gt;&gt;", txt, fixed = TRUE))
  expect_false(grepl("Sub &lt;&lt;weft: no value, line", txt, fixed = TRUE))
})

test_that("N89: a construct found nowhere in the source has no line: its marker and entry name the file only", {
  res <- filter_cases(c(printed = "Printed ``m``{.num} here."), list(lines_block()), draft = TRUE)
  expect_cases(res, c(printed = "Printed <<weft: no value>> here."))
  e <- fm_entry(res$stderr, "^  doc\\.md  ")
  expect_true(e$found)
  expect_identical(e$head, "  doc.md  [no value] `m`{.num}")
})

test_that("N89: an included file's constructs are located in the included file, by its own line", {
  inc <- c("Included `m`{.num}.", "", "Again `m`{.num}.")
  md <- c("First `m`{.num}.", "", "{{< include inc.md >}}")
  res <- filter_md(md, files = list(inc.md = inc), to = "plain", env = draft1, extra_inputs = "inc.md")
  expect_identical(res$status, 0L)
  expect_true(grepl("First <<weft: no value, line 1>>.", res$output, fixed = TRUE))
  expect_true(grepl("Included <<weft: no value, line 1>>.", res$output, fixed = TRUE))
  expect_true(grepl("Again <<weft: no value, line 3>>.", res$output, fixed = TRUE))
  expect_true(fm_entry(res$stderr, "^  doc\\.md:1  ")$found)
  expect_true(fm_entry(res$stderr, "^  (\\./)?inc\\.md:1  ")$found)
  expect_true(fm_entry(res$stderr, "^  (\\./)?inc\\.md:3  ")$found)
})
