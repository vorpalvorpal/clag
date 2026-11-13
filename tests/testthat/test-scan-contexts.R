# Stage 1c: scan_file() over captions, front matter and weft_str() strings
# (2.10.2, 2.10.6, 3.6.2, design-1c "scan_file(path) additions").
# New columns: context ("prose", "caption", "front-matter", "weft_str"),
# chunk, option. `line` is the line in the file.

scan_doc <- function(lines, ext = ".qmd") {
  path <- tempfile("weft-scan-", fileext = ext)
  writeLines(lines, path, useBytes = TRUE)
  withr::defer(unlink(path), parent.frame())
  weft:::scan_file(path)
}

rows_of <- function(x, ctx) x[x$context == ctx, , drop = FALSE]

sc_lines <- c(
  "---",                                                          # 1
  "title: \"t\"",                                                 # 2
  "abstract: |",                                                  # 3
  "  Front [a | b]{if=\"TRUE\"} text `r 1`{.num}",                # 4
  "---",                                                          # 5
  "",                                                             # 6
  "Prose `r 2`{.num} here.",                                      # 7
  "",                                                             # 8
  "```{r fig-one}",                                               # 9
  "#| fig-cap: |",                                                # 10
  "#|   Cap [a site | # sites]{n=\"3\"} end",                     # 11
  "x <- weft_str(\"A `r 5`{.num} string\")",                      # 12
  "y <- weft_str('[x | y]{if=\"TRUE\"}')",                        # 13
  "z <- weft_str(paste0(\"not\", \"literal `r 1`{.num}\"))",      # 14
  "w <- other_fn(\"not weft `r 9`{.num}\")",                      # 15
  "```",                                                          # 16
  "",                                                             # 17
  "```{r}",                                                       # 18
  "#| label: tbl-two",                                            # 19
  "#| tbl-cap: |",                                                # 20
  "#|   Table `r 7`{.num}",                                       # 21
  "```",                                                          # 22
  "",                                                             # 23
  "More prose [one | two]{if=\"FALSE\"}.",                        # 24
  "",                                                             # 25
  "---",                                                          # 26
  "abstract: |",                                                  # 27
  "  Late `r 8`{.num}",                                           # 28
  "---"                                                           # 29
)

test_that("2.10.2 + design-1c: scan_file() has the columns context, chunk and option, and every row has a context", {
  x <- scan_doc(sc_lines)
  expect_true(all(c("context", "chunk", "option", "kind", "line", "file", "expr", "error") %in% names(x)))
  expect_true(all(x$context %in% c("prose", "caption", "front-matter", "weft_str")))
  expect_setequal(unique(x$context), c("prose", "caption", "front-matter", "weft_str"))
})

test_that("2.10.2: prose rows are still found, alongside the others, with file lines", {
  x <- rows_of(scan_doc(sc_lines), "prose")
  expect_setequal(x$line, c(7L, 24L))
  expect_equal(x$kind[order(x$line)], c("value", "if"))
})

test_that("2.10.2 + 1.10.1: constructs in captions carry the chunk label, the option and the file line", {
  x <- rows_of(scan_doc(sc_lines), "caption")
  x <- x[order(x$line), ]
  expect_equal(x$line, c(11L, 21L))
  expect_equal(x$chunk, c("fig-one", "tbl-two"))
  expect_match(x$option[1], "^fig[.-]cap$")
  expect_equal(x$option[2], "tbl-cap")
  expect_equal(x$kind, c("n", "value"))
  expect_true(all(is.na(x$error)))
})

test_that("2.10.6 + 1.10.7: constructs in front matter, first block and late block, carry file lines", {
  x <- rows_of(scan_doc(sc_lines), "front-matter")
  x <- x[order(x$line), ]
  expect_equal(x$line, c(4L, 4L, 28L))
  expect_equal(sort(x$kind[x$line == 4L]), c("if", "value"))
  expect_equal(x$kind[x$line == 28L], "value")
  expect_true(all(is.na(x$error)))
})

test_that("3.6.2 + 2.10.2: a literal string passed to weft_str() in chunk code is scanned: context weft_str, chunk, line", {
  x <- rows_of(scan_doc(sc_lines), "weft_str")
  x <- x[order(x$line), ]
  expect_equal(x$line, c(12L, 13L))
  expect_equal(x$chunk, c("fig-one", "fig-one"))
  expect_equal(x$kind, c("value", "if"))
  # a call whose argument is not a literal contributes nothing (line 14), nor does another function's string (line 15)
  expect_false(any(c(14L, 15L) %in% x$line))
  expect_false(any(c(14L, 15L) %in% scan_doc(sc_lines)$line))
})

test_that("1.10.1 (rmarkdown): a caption written in the chunk header is scanned, as option fig.cap, at the header's line", {
  lines <- c("---", "title: t", "---", "",
             "```{r hdr, echo=FALSE, fig.cap='Hdr [a | b]{if=\"TRUE\"} x'}", "plot(1)", "```", "",
             "```{r plain, echo=FALSE, fig.cap='No construct here'}", "plot(1)", "```")
  x <- rows_of(scan_doc(lines, ".Rmd"), "caption")
  expect_equal(nrow(x), 1L)
  expect_equal(x$line, 5L)
  expect_equal(x$chunk, "hdr")
  expect_equal(x$option, "fig.cap")
  expect_true(is.na(x$error))
})

test_that("1.10.7 + 1.10.3 + 1.10.4 + 2.3.5: the static errors are on the rows, found from the source; their legal neighbours have none", {
  head <- c("---", "title: \"t\"", "engine: knitr", "---", "")
  front <- function(field) scan_doc(c("---", "engine: knitr", field, "---", "", "Body."))
  # front matter: quoted and plain scalars are errors, block scalars are not (1.10.7)
  for (f in c("title: \"Report [a | # sites]{n=3}\"", "title: 'Report [a | b]{if=\"TRUE\"}'",
              "abstract: Report [a | # sites]{n=3} here")) {
    x <- rows_of(front(f), "front-matter")
    expect_equal(nrow(x), 1L, info = f)
    expect_false(is.na(x$error), info = f)
  }
  x <- rows_of(front(c("abstract: >", "  Report [a | # sites]{n=3} here")), "front-matter")
  expect_true(is.na(x$error))
  # a bare value in a quoted field is no construct (1.1.8), so it is no error
  x <- front("title: \"Report `r 1 + 1`\"")
  expect_false(any(!is.na(x$error[x$context == "front-matter"])))
  # captions
  cap <- function(chunk_head, opt, extra = NULL, doc_head = head) {
    rows_of(scan_doc(c(doc_head, "```{r}", chunk_head, opt, "plot(1)", "```", "", extra)), "caption")
  }
  blk <- c("#| fig-cap: |", "#|   Depth [a | b]{if=\"TRUE\"}")
  expect_true(all(is.na(cap("#| label: fig-a", blk)$error)))                                       # control
  x <- cap("#| label: fig-a", "#| fig-cap: 'Depth [a | b]{if=\"TRUE\"}'")                         # 1.10.3
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  x <- cap("#| label: tbl-a", c("#| tab.cap: |", "#|   Table [a | b]{if=\"TRUE\"}"))              # 1.10.4
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  x <- cap("#| label: fig-a", c("#| fig-cap: Panels", "#| fig-subcap: !expr c('One [a | b]{if=\"TRUE\"}', 'Two')"))
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  x <- cap(c("#| label: fig-a", "#| cache: true"), blk)                                           # 2.3.5
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  x <- cap(c("#| label: fig-a", "#| eval: false"), blk)
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  x <- cap("#| label: fig-a", blk,
           doc_head = c("---", "title: \"t\"", "engine: knitr", "execute:", "  cache: true", "---", ""))
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  # a non-R engine
  x <- rows_of(scan_doc(c(head, "```{bash}", blk, "echo hi", "```")), "caption")
  expect_equal(nrow(x), 1L); expect_false(is.na(x$error))
  # a plain caption in each of those chunks has no construct, so no row and no error
  x <- rows_of(scan_doc(c(head, "```{r}", "#| label: fig-a", "#| cache: true", "#| fig-cap: Depth three", "plot(1)", "```")), "caption")
  expect_equal(nrow(x), 0L)
})

test_that("2.10.2: scan_text() is unchanged", {
  x <- weft:::scan_text("Prose `r 2`{.num} here.")
  expect_equal(nrow(x), 1L)
  expect_equal(x$kind, "value")
  expect_equal(x$line, 1L)
})
