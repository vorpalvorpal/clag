# Package 6c: the carrier as the filter reads it (dev/design-6.md N20 to N31, N25, N26, N28, N81).
# The blocks are written by hand (schema 1, N20 to N23); no R publishing code is called. Everything runs
# through plain Pandoc with weft.lua then weft-check.lua (helper-filter.R). While inst/quarto/weft.lua
# does not exist every test fails on that.

draft1 <- c(WEFT_DRAFT = "1")

test_that("N20, N31: a block adds its names, a use below it prints, and the block leaves no trace", {
  md <- c(carrier(depth = fr_float("3.14159")), "", "Depth `depth`{.val} m.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Depth 3.14159 m.</p>")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N20: other classes and attributes on the block are ignored", {
  md <- c(carrier(depth = fr_int("7"), attrs = '{#blk .weft-values .extra data-x="y"}'), "",
          "Depth `depth`{.val}.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Depth 7.</p>")
})

test_that("N21: unknown members and the optional members lang, run, at, cell are ignored", {
  members <- paste0('"lang":"python","run":"20261113T101500-123-000042","at":1794822900,',
                    '"cell":"c1","future":{"x":[1,2,3]}')
  md <- c(carrier(depth = fr_int("7"), members = members), "", "Depth `depth`{.val}.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Depth 7.</p>")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N6: a dot is an ordinary character in a name and never a path", {
  md <- c(carrier(n.sites = fr_int("5"), site = fr_int("1"), depth = fr_int("2")), "",
          "Sites `n.sites`{.val}.", "", "Path `site.depth`{.val}.")
  res <- filter_md(md, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  paras <- strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]]
  expect_identical(paras, c("Sites 5.", "Path <<weft: no value, line 7>>."))
  expect_match(res$stderr, fm_msg$E10("site.depth"), fixed = TRUE)
})

test_that("N25, E10: a name used above every block that publishes it is no value; below it prints", {
  md <- c("Above `depth`{.val} m.", "", carrier(depth = fr_int("7")), "", "Below `depth`{.val} m.")
  res <- filter_md(md, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  paras <- strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]]
  expect_identical(paras, c("Above <<weft: no value, line 1>> m.", "Below 7 m."))
  expect_match(res$stderr, fm_msg$E10("depth"), fixed = TRUE)
  expect_match(res$stderr, fm_msg$E10_hint("depth"), fixed = TRUE)
  expect_match(fm_headings(res$stderr), rx_failures(1), all = FALSE)
  e <- fm_entry(res$stderr, "^  doc\\.md:1  ")
  expect_true(e$found)
  expect_identical(e$head, "  doc.md:1  [no value] `depth`{.val}")
  expect_identical(e$detail[[1]], fm_msg$E10("depth"))
  # without draft mode the same document fails the render
  res2 <- filter_md(md, to = "plain")
  expect_identical(res2$status, 1L)
})

test_that("N26: a later block that publishes a name replaces it for the constructs below", {
  md <- c(carrier(depth = fr_int("1")), "", "One `depth`{.val}.", "",
          carrier(depth = fr_int("2"), other = fr_int("9")), "", "Two `depth`{.val} `other`{.val}.")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]], c("One 1.", "Two 2 9."))
})

test_that("N81, N26: the title and a table caption see each name's last published value", {
  md <- c("---", 'title: "T `depth`{.val}"', "---", "",
          carrier(depth = fr_int("1")), "", "Body one `depth`{.val}.", "",
          carrier(depth = fr_int("2")), "", "Body two `depth`{.val}.", "",
          "| a |", "|---|", "| 1 |", "", ": Cap `depth`{.val}")
  res <- filter_md(md, to = "plain", args = "-s")
  expect_identical(res$status, 0L)
  expect_match(res$output, "T 2", fixed = TRUE)
  expect_match(res$output, "Cap 2", fixed = TRUE)
  expect_match(res$output, "Body one 1.", fixed = TRUE)
  expect_match(res$output, "Body two 2.", fixed = TRUE)
  expect_false(grepl("T 1|Cap 1", res$output))
})

test_that("N24: a block in a div, in a list item and in a block quote adds its names", {
  md <- c("::: {.note}", carrier(in_div = fr_int("1")), ":::", "",
          "- item", "", paste0("  ", carrier(in_item = fr_int("2"))), "",
          paste0("> ", carrier(in_quote = fr_int("3"))), "",
          "Values `in_div`{.val} `in_item`{.val} `in_quote`{.val}.")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  paras <- strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]]
  expect_identical(utils::tail(paras, 1L), "Values 1 2 3.")
  expect_false(grepl("weft-values|\"weft\"", res$output))
})

test_that("N24: a fenced block with another class holding the same JSON is code and adds nothing", {
  json <- carrier_json(depth = fr_int("7"))
  md <- c("```json", json, "```", "", "Depth `depth`{.val}.")
  res <- filter_md(md, env = draft1)
  expect_identical(res$status, 0L)
  expect_match(res$output, '<pre class="sourceCode json">', fixed = TRUE)
  expect_match(strip_tags(res$output), "Depth &lt;&lt;weft: no value, line 5&gt;&gt;.", fixed = TRUE)
})

test_that("N28: each malformed block is one construct error located at its cell, adds no names, and a later use is no value", {
  cells <- list(
    bad_json   = list(text = "not json at all", why = "not JSON"),
    bad_array  = list(text = "[1,2]", why = "not a JSON object"),
    bad_weft   = list(text = '{"weft":2,"values":{}}', why = "`weft` is not 1"),
    bad_wstr   = list(text = '{"weft":"1","values":{}}', why = "`weft` is not 1"),
    bad_novals = list(text = '{"weft":1}', why = "no `values` object"),
    bad_valarr = list(text = '{"weft":1,"values":[]}', why = "no `values` object"),
    bad_key    = list(text = carrier_json(ok = fr_int("1"), `1bad` = fr_int("2")),
                      why = "`1bad` in `values` is not a name"),
    bad_space  = list(text = carrier_json(`a b` = fr_int("2")), why = "`a b` in `values` is not a name"),
    bad_word   = list(text = carrier_json(`TRUE` = fr_int("2")), why = "`TRUE` in `values` is not a name")
  )
  blocks <- lapply(names(cells), function(id) {
    c(sprintf("::: {#cell-%s .cell}", id), carrier_raw(cells[[id]]$text), ":::")
  })
  d <- fm_doc(c(use = "Use `ok`{.val}."), blocks)
  res <- filter_md(d$md, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), sprintf("Use <<weft: no value, line %d>>.", d$line[["use"]]))
  expect_match(fm_headings(res$stderr), rx_failures(length(cells) + 1L), all = FALSE)
  for (id in names(cells)) {
    e <- fm_entry(res$stderr, sprintf("^  doc\\.md chunk %s( |$)", id))
    expect_true(e$found, label = paste("an entry for", id))
    expect_match(e$head, "\\[construct error\\]", label = paste("tag of", id))
    expect_identical(e$detail[[1]], fm_msg$E12(cells[[id]]$why), label = paste("detail of", id))
  }
})

test_that("N29, E13: a block of 5000001 bytes is malformed and adds no names; 5000000 bytes reads", {
  mk <- function(total) {
    head <- '{"weft":1,"values":{"d":{"t":"int","v":"7"}},"pad":"'
    tail <- '"}'
    pad <- total - nchar(head, "bytes") - nchar(tail, "bytes")
    paste0(head, strrep("a", pad), tail)
  }
  big <- mk(5000001L)
  expect_identical(nchar(big, "bytes"), 5000001L)
  ok <- mk(5000000L)
  expect_identical(nchar(ok, "bytes"), 5000000L)
  doc <- function(text) c("::: {#cell-big .cell}", carrier_raw(text), ":::", "", "Use `d`{.val}.")
  res <- filter_md(doc(big), to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  expect_match(res$stderr, fm_msg$E13(5000001), fixed = TRUE)
  expect_match(res$output, "Use <<weft: no value, line 7>>.", fixed = TRUE)
  res2 <- filter_md(doc(ok), to = "plain")
  expect_identical(res2$status, 0L)
  expect_identical(trimws(res2$output), "Use 7.")
})

test_that("N21, pinned: a duplicate key decodes to its first value and is not detected", {
  json <- '{"weft":1,"values":{"d":{"t":"int","v":"1"},"d":{"t":"int","v":"2"}}}'
  res <- filter_md(c(carrier_raw(json), "", "Use `d`{.val}."), to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "Use 1.")
})

test_that("N31: blocks, and cell divs left empty, are removed from the output", {
  md <- c("::: {.cell}", "",
          "::::: {.cell-output .cell-output-display}", carrier(a = fr_int("1")), ":::::", "",
          ":::", "",
          "::: {.cell}", "",
          "::::: {.cell-output .cell-output-stdout}", carrier(b = fr_int("2")), ":::::", "",
          "::::: {.cell-output}", carrier(c = fr_int("3")), ":::::", "",
          ":::", "",
          "Kept `a`{.val} `b`{.val} `c`{.val}.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Kept 1 2 3.</p>")
})

test_that("N31: a cell that still holds content stays, with the content; an output div with content stays", {
  md <- c("::: {.cell}", "", "Text stays.", "",
          "::::: {.cell-output .cell-output-stdout}", carrier(a = fr_int("1")), ":::::", "",
          "::::: {.cell-output}", "", "Output stays.", "", ":::::", "",
          ":::")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_match(res$output, '<div class="cell">', fixed = TRUE)
  expect_match(res$output, "<p>Text stays.</p>", fixed = TRUE)
  expect_match(res$output, '<div class="cell-output">', fixed = TRUE)
  expect_match(res$output, "<p>Output stays.</p>", fixed = TRUE)
  expect_false(grepl("cell-output-stdout", res$output, fixed = TRUE))
  expect_false(grepl("weft-values", res$output, fixed = TRUE))
})
