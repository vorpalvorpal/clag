# Package 6d: the scanner's rows for named values and the `resolver` column (rules N5, N6, N14, N140 of
# dev/design-6.md). The scanner is read through weft:::scan_file(), which knows the document's engine.
# Helpers: helper-6d.R, helper-3.R (lint_proj). Invented content only.
#
# READINGS of the note (see the report): a `.qmd` is a knitr document when it has `engine: knitr`, or an
# executed {r} chunk and no `engine:` or `jupyter:` key (N14, as dl_knitr_doc() reads it today); an `.Rmd`
# always is; every other document is one the filter resolves.

named_rows <- function(x) x[x$kind %in% "named", , drop = FALSE]

# ---- the resolver column exists, on every row ------------------------------------------------------------

test_that("N140: scan_file() rows have a `resolver` column holding filter or hooks", {
  x <- w6d_scan(w6d_doc("A `depth`{.num} and [a | b]{if=\"ok\"} here."))
  expect_true("resolver" %in% names(x))
  expect_true(all(x$resolver %in% c("filter", "hooks")))
  y <- w6d_scan(c("A `r depth`{.num} here."), name = "b.Rmd")
  expect_true("resolver" %in% names(y))
  expect_identical(y$resolver, "hooks")
})

# ---- N5: what is a named value -----------------------------------------------------------------------------

N5_FORMS <- list(
  list(src = "`depth`{.num}",                 label = "a formatter class"),
  list(src = "`depth`{.pct}",                 label = "another formatter class"),
  list(src = "`depth`{.word}",                label = "a wording class"),
  list(src = "`sites`{.and}",                 label = "a collapse class"),
  list(src = "`depth`{.strong}",              label = "a text class"),
  list(src = "`site`{.val}",                  label = ".val"),
  list(src = "`n`{digits=\"2\"}",             label = "the key digits"),
  list(src = "`n`{sigfig=\"3\"}",             label = "the key sigfig"),
  list(src = "`sites`{.val .and}",            label = ".val with a collapse class"),
  list(src = "`depth`{#d .num}",              label = "an id with a class")
)

test_that("N5, N140: a code span with a NAME and a weft class or renderer key is one row of kind named, expr the NAME", {
  for (cs in N5_FORMS) {
    x <- named_rows(w6d_scan(w6d_doc(c("Intro.", "", paste("Words", cs$src, "more.")))))
    expect_identical(nrow(x), 1L, label = cs$label)
    expect_identical(x$expr, sub("^`([^`]+)`.*$", "\\1", cs$src), label = cs$label)
    expect_identical(x$resolver, "filter", label = cs$label)
    expect_identical(x$line, 7L, label = cs$label)
    expect_true(is.na(x$error), label = cs$label)
  }
})

N5_NOT <- list(
  list(src = "`depth`{.python}",   label = "a class that is not weft's"),
  list(src = "`depth`{#d}",        label = "an id alone"),
  list(src = "`depth`",            label = "no attribute block"),
  list(src = "`depth` {.num}",     label = "a space before the block (1.1.7)"),
  list(src = "`x + 1`{.python}",   label = "a non-name with a class that is not weft's"),
  list(src = "`x + 1`{#d}",        label = "a non-name with an id alone")
)

test_that("N5: with no weft class or key, or not touching the backtick, the span stays code: no named row", {
  for (cs in N5_NOT) {
    x <- w6d_scan(w6d_doc(c("Intro.", "", paste("Words", cs$src, "more."))))
    expect_identical(nrow(named_rows(x)), 0L, label = cs$label)
  }
  # control: the same sentence with a weft class is a named row
  expect_identical(nrow(named_rows(w6d_scan(w6d_doc("Words `depth`{.num} more.")))), 1L)
})

test_that("N5: Pandoc's trimming of one space inside the backticks applies: ` depth `{.num} is the name depth", {
  x <- named_rows(w6d_scan(w6d_doc("Words ` depth `{.num} more.")))
  expect_identical(nrow(x), 1L)
  expect_identical(x$expr, "depth")
  expect_true(is.na(x$error))
})

test_that("N6: names with dots, a leading underscore, digits and 64 characters are names", {
  long <- paste0("a", strrep("b", 63))
  for (nm in c("n.sites", "_x", "a1", "A", "x_1.y", long)) {
    x <- named_rows(w6d_scan(w6d_doc(paste0("Words `", nm, "`{.num} more."))))
    expect_identical(nrow(x), 1L, label = nm)
    expect_identical(x$expr, nm, label = nm)
    expect_true(is.na(x$error), label = nm)
  }
})

test_that("N140: several named values give several rows, in document order, each with its line", {
  lines <- w6d_doc(c("A `a`{.num} and `b`{.pct}.", "", "Then `c`{.val}."))
  x <- named_rows(w6d_scan(lines))
  expect_identical(x$expr, c("a", "b", "c"))
  expect_identical(x$line, c(5L, 5L, 7L))
})

# ---- N140: spans in a document the filter resolves keep their kind -------------------------------------------

FILTER_SPANS <- list(
  n    = r"{We saw [a site | # sites]{n="k"}.}",
  `if` = r"{The level [rose | fell]{if="up"}.}",
  sign = r"{The level [rose | fell]{sign="d"}.}",
  list = r"{[No sites were | # was | # were]{list="flagged"} flagged.}",
  cite = r"{A depth [of 10 m]{cite="smith2020"}.}",
  text = "A [word]{.strong} here."
)

test_that("N140: in a jupyter document each span keeps its kind and has resolver filter", {
  for (k in names(FILTER_SPANS)) {
    x <- w6d_scan(w6d_doc(c("Intro.", "", FILTER_SPANS[[k]])))
    x <- x[x$kind == k, , drop = FALSE]
    expect_identical(nrow(x), 1L, label = k)
    expect_identical(x$resolver, "filter", label = k)
  }
})

test_that("N140: a document with no chunk and no engine key, or with a python chunk, is a filter document", {
  for (lines in list(c(FILTER_SPANS$n), c(FILTER_SPANS$n, "", w6d_py("x = 1")),
                     c("---", "jupyter: python3", "---", "", FILTER_SPANS$n),
                     c(FILTER_SPANS$n, "", w6d_jl("x = 1")),
                     c(FILTER_SPANS$n, "", w6d_r("x <- 1", "eval: false")))) {
    x <- w6d_scan(lines)
    expect_identical(x$resolver[x$kind == "n"], "filter", label = paste(lines, collapse = " | "))
  }
})

KNITR_DOCS <- list(
  `an Rmd`                  = list(name = "a.Rmd", front = NULL, chunks = character()),
  `engine: knitr`           = list(name = "a.qmd", front = "engine: knitr", chunks = character()),
  `an executed r chunk`     = list(name = "a.qmd", front = NULL, chunks = w6d_r("x <- 1")),
  `engine: knitr with py`   = list(name = "a.qmd", front = "engine: knitr", chunks = w6d_py("x = 1"))
)
KNITR_BODY <- c("A `r depth`{.num} and `r x` here.", "",
                r"{We saw [a site | # sites]{n="k"}.}", "",
                r"{The level [rose | fell]{if="up"}.}", "",
                r"{The level [rose | fell]{sign="d"}.}", "",
                r"{[No sites were | # was | # were]{list="flagged"} flagged.}", "",
                r"{A depth [of 10 m]{cite="smith2020"}.}", "",
                "A [word]{.strong} here.", "",
                "The `depth`{.num} again.")

test_that("N140: in a knitr document every row has resolver hooks except the named values, which have filter", {
  for (nm in names(KNITR_DOCS)) {
    d <- KNITR_DOCS[[nm]]
    lines <- if (is.null(d$front)) c(KNITR_BODY, "", d$chunks) else w6d_doc(KNITR_BODY, d$chunks, d$front)
    x <- w6d_scan(lines, name = d$name)
    nr <- x$kind == "named"
    expect_identical(sum(nr), 1L, label = nm)
    expect_identical(x$resolver[nr], "filter", label = nm)
    expect_identical(sort(unique(x$kind[!nr])), sort(c("value", "bare", "n", "if", "sign", "list", "cite", "text")),
                     label = nm)
    expect_true(all(x$resolver[!nr] == "hooks"), label = nm)
  }
})

test_that("N140: a named value inside an arm of a span the hooks resolve is a filter row; the span stays the hooks'", {
  lines <- c(r"{The depth is [`depth`{.num} deep | shallow]{if="ok"}.}")
  x <- w6d_scan(lines, name = "a.Rmd")
  expect_identical(x$resolver[x$kind == "named"], "filter")
  expect_identical(x$resolver[x$kind == "if"], "hooks")
})

# ---- contexts: front matter and captions on filter documents (amended 1.10.1, 1.10.7, 2.3.5) -----------------

test_that("N140: a named value in a plain title: field of a filter document is a named row with no 1.10.7 error", {
  lines <- w6d_doc("Words.", front = c("engine: jupyter", "title: \"Depth `depth`{.num} metres\""))
  x <- named_rows(w6d_scan(lines))
  expect_identical(nrow(x), 1L)
  expect_identical(x$context, "front-matter")
  expect_identical(x$option, "title")
  expect_identical(x$expr, "depth")
  expect_identical(x$resolver, "filter")
  expect_true(is.na(x$error))
})

test_that("N140: a named value in a plain fig-cap: of a python chunk is a named row of that caption with no error", {
  lines <- w6d_doc("Words.", w6d_py("x = 1", c("label: fig-a", "fig-cap: \"A cap at `depth`{.num} metres\"")))
  x <- named_rows(w6d_scan(lines))
  expect_identical(nrow(x), 1L)
  expect_identical(x$context, "caption")
  expect_identical(x$chunk, "fig-a")
  expect_identical(x$option, "fig-cap")
  expect_identical(x$expr, "depth")
  expect_true(is.na(x$error))
})

test_that("N140: the same on a cached or eval: false R chunk in a knitr document, where the hooks refuse a caption", {
  lines <- c("Words.", "", w6d_r("x <- 1", c("label: tbl-b", "eval: false", "tbl-cap: \"B at `depth`{.num}\"")))
  x <- named_rows(w6d_scan(lines, name = "a.Rmd"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$context, "caption")
  expect_identical(x$resolver, "filter")
  expect_true(is.na(x$error))
})

test_that("N140 control: an R value in a plain title: still carries the block-scalar error (rule 1.10.7)", {
  lines <- w6d_doc("Words.", front = c("engine: knitr", "title: \"Depth `r d`{.num} metres\""))
  x <- w6d_scan(lines)
  expect_identical(nrow(x), 1L)
  expect_match(x$error, "must be in a YAML block scalar", fixed = TRUE)
})

# ---- arms() takes the column -------------------------------------------------------------------------------

test_that("N140 control: arms() lists a span of a jupyter document, its key and expression", {
  root <- lint_proj(list("a.qmd" = w6d_doc(c("Intro.", "", r"{We saw [a site | # sites]{n="k"} today.}"))))
  x <- weft::arms(file.path(root, "a.qmd"))
  expect_identical(nrow(x), 2L)
  expect_identical(unique(x$key), "n")
  expect_identical(unique(x$expr), "k")
})
