# Package 3a: the construct lint (L17: the scanner's errors as findings; rules 5.3.1, 5.3.4, 5.3.5).
# Contract: dev/design-3.md L17, L5, L10, L13. Helpers: helper-3.R.

cons <- function(text, ext = "qmd", ...) lint_one(text, rules = "construct", ext = ext, ...)

# the scanner's own error messages for a text (existing stage 1a code), the expected `message`s
scan_errs <- function(text) {
  r <- weft:::scan_text(paste(text, collapse = "\n"))
  r$error[!is.na(r$error)]
}

# ---- every kind of error, in a paragraph: text, spec, message ---------------------------

# source (alone in a paragraph), text of the finding, spec from "(rule x.y.z)"
CONS_CASES <- list(
  list(src = r"{[a site]{n="k" if="x"}}",              text = r"{[a site]{n="k" if="x"}}", spec = "1.1.5"),
  list(src = "[1]{.weft-literal}",                      text = "[1]{.weft-literal}",        spec = "1.8.10"),
  list(src = "`r x +`{.num}",                           text = "`r x +`{.num}",             spec = "5.3.5"),
  list(src = "`r x +`",                                 text = "`r x +`",                   spec = "5.3.5"),
  list(src = "`r claim(x)`",                            text = "`r claim(x)`",              spec = "3.1.10"),
  list(src = r"{`r x`{.num digits="2" sigfig="3"}}",    text = r"{`r x`{.num digits="2" sigfig="3"}}", spec = "1.4.7"),
  list(src = "`r x`{.num .pct .sci}",                   text = "`r x`{.num .pct .sci}",     spec = "1.4.2"),
  list(src = r"{[a]{if="x" .num}}",                     text = r"{[a]{if="x" .num}}",       spec = "1.5.7"),
  list(src = r"{`r x`{foo="a" foo="b"}}",               text = r"{`r x`{foo="a" foo="b"}}", spec = "1.2.10"),
  list(src = "$p = `r p`{.word}$",                      text = "`r p`{.word}",              spec = "5.2.6"),
  list(src = "`r\nx`",                                  text = "`r\nx`",                    spec = "5.3.4")
)

test_that("3a L17: each kind of construct error is one finding with the scanner's message and spec", {
  for (cs in CONS_CASES) {
    x <- cons(c("Some prose before.", "", cs$src, "", "Some prose after."))
    expect_gte(nrow(x), 1L)
    expect_true(all(x$rule == "construct"), label = cs$src)
    expect_true(all(x$tier == 1L), label = cs$src)
    expect_true(cs$spec %in% x$spec, label = paste("spec", cs$spec, "for", cs$src))
    # the message is the scanner's, verbatim
    expect_true(all(x$message %in% scan_errs(c("Some prose before.", "", cs$src, "", "Some prose after."))),
                label = paste("message of", cs$src))
    expect_true(all(is.na(x$hint)), label = cs$src)
    expect_findings_shape(x)
  }
})

test_that("3a L17: text is the construct as written, spanning its attribute block", {
  x <- cons(c("Prose.", "", "A sentence with [1]{.weft-literal} and more."))
  expect_identical(x$text, "[1]{.weft-literal}")
  x <- cons(c("Mean was `r x +`{.num} m."))
  expect_identical(x$text, "`r x +`{.num}")
})

test_that("3a L17: spec is the first 'rule x.y.z' of the message, so a message with two rules takes the first", {
  # 1.2.10 (written twice) is a message with one rule; the spec is that rule
  x <- cons("`r x`{foo=\"a\" foo=\"b\"}")
  expect_identical(x$spec, "1.2.10")
  # the spec column is always a rule number, never the whole message
  expect_true(all(grepl("^[0-9]+(\\.[0-9]+)+$", x$spec)))
})

test_that("3a L17: text is cut to 80 characters", {
  long <- paste0("[", paste(rep("word", 30), collapse = " "), r"{]{n="k" if="x"}}")
  expect_gt(nchar(long), 80)
  x <- cons(c("Prose.", "", long))
  expect_equal(nrow(x), 1L)
  expect_equal(nchar(x$text), 80L)
  expect_identical(x$text, substr(long, 1, 80))
  # exactly 80 is not cut
  mid <- paste0("[", strrep("a", 80 - nchar(r"{[]{n="k" if="x"}}")), r"{]{n="k" if="x"}}")
  expect_equal(nchar(mid), 80L)
  x2 <- cons(c("Prose.", "", mid))
  expect_identical(x2$text, mid)
})

test_that("3a L17: a clean construct gives no finding; a literal with `why` is not an error", {
  ok <- c(
    r"{A [1]{.weft-literal why="SOP 12"} b.}",
    "Mean `r x`{.num} m.",
    r"{[a site | # sites]{n="k"} here}",
    "Plain prose.",
    "`r claim(x, . > 1)`"
  )
  expect_equal(nrow(cons(c("Prose.", "", ok))), 0L)
  expect_findings_shape(cons(ok))
})

test_that("3a L17: one finding per bad construct, each at its own line and column", {
  doc <- c(
    "First line has `r a +`{.num} and more `r b +`{.num}.",
    "",
    "Second [1]{.weft-literal} paragraph."
  )
  x <- cons(doc)
  expect_equal(nrow(x), 3L)
  expect_identical(x$line, c(1L, 1L, 3L))
  expect_identical(x$col, c(f3_pos(doc, "`r a +`")[["col"]], f3_pos(doc, "`r b +`")[["col"]],
                           f3_pos(doc, "[1]{")[["col"]]))
  expect_identical(x$end_line, x$line)
})

test_that("3a L17: ids are among the errors (a back-reference to an unknown id)", {
  doc <- c("A [x]{n=\"k\"} then", "", "[y]{n=\"#zz\"}.")
  x <- cons(doc)
  r <- x[grepl("1.7.10", x$spec, fixed = TRUE), ]
  expect_equal(nrow(r), 1L)
  expect_identical(r$text, "[y]{n=\"#zz\"}")
  expect_identical(r$line, 3L)
})

test_that("3a L17: an unescaped arm separator in a pipe-table cell is a finding in the cell", {
  doc <- c("Intro.", "", "| a | b |", "|---|---|", "| [a | b]{n=\"k\"} | 2 |")
  x <- cons(doc)
  expect_true("1.5.13" %in% x$spec)
  expect_true(all(x$line == 5L))
})

# ---- contexts ------------------------------------------------------------------------

test_that("3a L17: body prose has context 'prose'", {
  x <- cons(c("Some [1]{.weft-literal} text."))
  expect_identical(x$context, "prose")
})

test_that("3a L17: a front-matter block scalar construct has context 'front-matter' at its own line and column", {
  doc <- c("---", "title: T", "abstract: |", "  An abstract with [1]{.weft-literal} in it.", "---", "", "Body.")
  x <- cons(doc)
  expect_equal(nrow(x), 1L)
  expect_identical(x$context, "front-matter")
  expect_identical(x$line, 4L)
  expect_identical(x$col, f3_pos(doc, "[1]{")[["col"]])
  expect_identical(x$text, "[1]{.weft-literal}")
})

test_that("3a L17: a late metadata block's field is read at its own line", {
  doc <- c("---", "title: T", "---", "", "Body.", "", "More body.", "", "---", "abstract: |",
           "  Late [1]{.weft-literal} abstract.", "---", "", "End.")
  x <- cons(doc)
  expect_equal(nrow(x), 1L)
  expect_identical(x$line, 11L)
  expect_identical(x$context, "front-matter")
})

test_that("3a L17: a chunk-option caption construct has context 'caption' at its file line and column", {
  doc <- c("Intro.", "", "```{r}", "#| label: fig-a", "#| fig-cap: |",
           "#|   Depth of [1]{.weft-literal} sites.", "plot(1)", "```", "", "After.")
  x <- cons(doc)
  expect_equal(nrow(x), 1L)
  expect_identical(x$context, "caption")
  expect_identical(x$line, 6L)
  expect_identical(x$col, f3_pos(doc, "[1]{")[["col"]])
  expect_identical(x$text, "[1]{.weft-literal}")
})

test_that("3a L17: a weft_str() string construct has context 'weft_str' at its file position", {
  doc <- c("Intro.", "", "```{r}", "x <- weft_str(\"over [1]{.weft-literal} years\")", "```")
  x <- cons(doc)
  expect_equal(nrow(x), 1L)
  expect_identical(x$context, "weft_str")
  expect_identical(x$line, 4L)
  expect_identical(x$col, f3_pos(doc, "[1]{")[["col"]])
  expect_identical(x$text, "[1]{.weft-literal}")
})

test_that("3a L17: a lookup()/brk() phrase construct has context 'phrase' at its file position", {
  doc <- c("```{r}", "p <- brk(v, c(2, 5), c(\"few\", \"[1]{.weft-literal} some\", \"many\"))", "```")
  x <- cons(doc)
  expect_equal(nrow(x), 1L)
  expect_identical(x$context, "phrase")
  expect_identical(x$line, 2L)
  expect_identical(x$col, f3_pos(doc, "[1]{")[["col"]])
})

test_that("3a L17: constructs inside fenced code, an eval: false chunk's strings and indented code are not read", {
  doc <- c("Prose.", "", "```", F3_BAD_LIT, "```", "", "```{r}", "#| eval: false",
           "x <- weft_str(\"[1]{.weft-literal}\")", "```", "", "~~~", F3_BAD_TWO, "~~~")
  expect_equal(nrow(cons(doc)), 0L)
})

test_that("3a L17: a construct in a code span or an HTML comment is not a finding", {
  doc <- c("Prose `[1]{.weft-literal}` and <!-- [1]{.weft-literal} --> done.")
  expect_equal(nrow(cons(doc)), 0L)
})

# ---- .Rmd and .qmd, line endings, non-ASCII -------------------------------------------------

test_that("3a L17: every context gives the same findings under .qmd and .Rmd", {
  doc <- c("---", "title: T", "abstract: |", "  Abs [1]{.weft-literal} x.", "---", "",
           "Prose [1]{.weft-literal}.", "",
           "```{r}", "#| fig-cap: |", "#|   Cap [1]{.weft-literal}.", "x <- weft_str(\"w [1]{.weft-literal}\")", "```")
  r <- f3_both(function(ext) {
    x <- cons(doc, ext = ext)
    x[, setdiff(names(x), "file")]
  })
  expect_equal(nrow(r$qmd), 4L)
  expect_identical(unclass(r$qmd), unclass(r$Rmd))
  expect_setequal(r$qmd$context, c("front-matter", "prose", "caption", "weft_str"))
})

test_that("3a L5/L17: col counts characters, so non-ASCII text before a finding shifts it by characters not bytes", {
  line <- "Caf\u00e9 \u2014 na\u00efve \u00e9t\u00e9 [1]{.weft-literal} end."
  x <- cons(c("Prose.", "", line))
  expect_equal(x$line, 3L)
  expect_equal(x$col, nchar("Caf\u00e9 \u2014 na\u00efve \u00e9t\u00e9 ") + 1L)
  expect_identical(x$text, "[1]{.weft-literal}")
})

test_that("3a L5/L17: a supplementary-plane character (emoji) counts as one character", {
  line <- "\U0001F600 [1]{.weft-literal}"
  x <- cons(line)
  expect_equal(x$col, 3L)
})

test_that("3a L5/L17: non-ASCII before a finding in a caption and in front matter", {
  doc <- c("---", "title: \"T\"", "abstract: |", "  \u00e9\u00e9\u00e9 [1]{.weft-literal}", "---", "",
           "```{r}", "#| fig-cap: |", "#|   \u00e9\u00e9 [1]{.weft-literal}", "```")
  x <- cons(doc)
  expect_equal(nrow(x), 2L)
  expect_identical(x$line, c(4L, 9L))
  expect_identical(x$col, c(7L, 9L))
})

# \u00a721's position stress document: repeated and blank blocks, a block equal to a line of the
# chunk above, CRLF, no final newline, BOM; findings at the same line and column as in a plain copy.
stress_doc <- c(
  "---", "title: \"Stress\"", "abstract: |", "  Same text [1]{.weft-literal} here.", "---", "",
  "Same text [1]{.weft-literal} here.", "", "", "",
  "Same text [1]{.weft-literal} here.", "",
  "```{r}", "#| fig-cap: |", "#|   Same text [1]{.weft-literal} here.",
  "Same text [1]{.weft-literal} here.", "x <- 1", "```", "",
  "Same text [1]{.weft-literal} here.", "",
  "x <- 1", "",
  "Caf\u00e9 Same text [1]{.weft-literal} here."
)

test_that("3a L5/L17: findings sit at the same line and column in a plain copy and with CRLF, BOM, no final newline", {
  for (ext in c("qmd", "Rmd")) {
    plain <- lint_fixture(setNames(list(list(lines = stress_doc)), paste0("d.", ext)), rules = "construct")
    expect_equal(nrow(plain), 6L)
    variants <- list(
      crlf = list(lines = stress_doc, eol = "\r\n"),
      bom = list(lines = stress_doc, bom = TRUE),
      nofinal = list(lines = stress_doc, final_newline = FALSE),
      all = list(lines = stress_doc, eol = "\r\n", bom = TRUE, final_newline = FALSE),
      crlf_nofinal = list(lines = stress_doc, eol = "\r\n", final_newline = FALSE)
    )
    for (nm in names(variants)) {
      v <- lint_fixture(setNames(list(variants[[nm]]), paste0("d.", ext)), rules = "construct")
      expect_identical(v$line, plain$line, label = paste(ext, nm, "lines"))
      expect_identical(v$col, plain$col, label = paste(ext, nm, "cols"))
      expect_identical(v$context, plain$context, label = paste(ext, nm, "context"))
      expect_identical(v$text, plain$text, label = paste(ext, nm, "text"))
      expect_identical(v$end_line, plain$end_line, label = paste(ext, nm, "end_line"))
    }
  }
})

test_that("3a L5/L17: the plain copy's findings are where the text says they are", {
  x <- lint_one(stress_doc, rules = "construct")
  expect_identical(
    x$line,
    c(4L, 7L, 11L, 15L, 20L, 24L)  # line 16 is chunk code, not prose
  )
  # each at the construct's column in its own line
  for (i in seq_len(nrow(x))) {
    line <- stress_doc[[x$line[[i]]]]
    expect_identical(substr(line, x$col[[i]], x$col[[i]] + nchar(x$text[[i]]) - 1L), x$text[[i]])
  }
})

test_that("3a L5: a BOM does not shift the column of a finding on line 1", {
  x <- lint_fixture(list("a.qmd" = list(lines = "[1]{.weft-literal} first", bom = TRUE)), rules = "construct")
  expect_identical(x$line, 1L)
  expect_identical(x$col, 1L)
})

test_that("3a L5: CR LF is made LF, so a finding's column on a CRLF line is unaffected", {
  x <- lint_fixture(list("a.qmd" = list(lines = c("Ab", "cd [1]{.weft-literal}", "ef"), eol = "\r\n")))
  expect_identical(x$line, 2L)
  expect_identical(x$col, 4L)
})

test_that("3a L17: a file that does not exist at lints() is refused, not read as empty", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT))
  e <- f2_cond(lints(root, files = "gone.qmd"))
  f2_has_class(e, "weft_lint_error")
})

test_that("3a L17: an empty document and a document of blank lines have no findings", {
  expect_equal(nrow(cons(character(0))), 0L)
  expect_equal(nrow(cons(c("", "", ""))), 0L)
})

test_that("3a L13: a .weft-literal with no why is a construct finding; with why it is not", {
  x <- cons(c(r"{A [10 m]{.weft-literal} b}"))
  expect_equal(x$spec, "1.8.10")
  y <- cons(c(r"{A [10 m]{.weft-literal why="SOP 12"} b}"))
  expect_equal(nrow(y), 0L)
  # a literal div with no why
  z <- cons(c("::: {.weft-literal}", "Text 5.", ":::"))
  expect_true(any(z$spec == "1.8.10"))
  w <- cons(c("::: {.weft-literal why=\"definition\"}", "Text 5.", ":::"))
  expect_equal(nrow(w), 0L)
})

test_that("3a L13: there is no inline ignore comment (K5)", {
  x <- cons(c("<!-- weft-ignore -->", F3_BAD_LIT))
  expect_equal(nrow(x), 1L)
})
