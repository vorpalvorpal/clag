# Finding 21 (dev/open-findings.md): inline R inside a markdown code span.
# knitr runs its own regex over the raw text, so `r x` inside a code span is
# evaluated and its value lands in the span. The scanner tokenises the outer
# span first and never sees it. Rules CS1 to CS8 are the owner's ruling.
# CS5: a class block after such inline R is the same construct as outside a
# code span, formatted by the text hook; CS7: the same for a non-chunk fenced
# code block, which knitr also evaluates. Which shapes knitr evaluates was
# established by knitting them (CS_SHAPES, CS_NOT_EVALUATED, CS_FENCES).

cs_sc <- function(x) weft:::scan_text(x)
cs_pos <- function(text, pat) as.integer(regexpr(pat, text, fixed = TRUE))

# ---- the shapes: source, and the inline expressions knitr evaluates in it, in order ---------------------

CS_SHAPES <- list(
  list(id = "single span, text before and after", src = "Fit `lm(y ~ `r x`)` here.", exprs = "x"),
  list(id = "single span, call around it",        src = "Use `f(`r x`)` now.",        exprs = "x"),
  list(id = "double-backtick span",               src = "See ``a `r x` b`` there.",   exprs = "x"),
  list(id = "two expressions in one span",        src = "Try `f(`r a`, `r b`)` now.", exprs = c("a", "b")),
  list(id = "expression at the start of a double span", src = "See `` `r x` b`` there.", exprs = "x"),
  list(id = "expression at the end of a double span",   src = "See ``a `r x` `` there.", exprs = "x"),
  list(id = "r# form",                            src = "Use `f(`r# x`)` now.",      exprs = "x"),
  # knitr's documented "verbatim" form is NOT protected: it evaluates the inner expression
  list(id = "double span holding only the expression", src = "Write `` `r x` `` to show it.", exprs = "x"),
  list(id = "triple span holding only the expression", src = "Write ``` `r x` ``` to show it.", exprs = "x"),
  list(id = "expression with a trailing space",   src = "Use `f(`r x `)` now.",      exprs = "x")
)

# ---- CS1: a row for each ------------------------------------------------------------------------------

test_that("CS1: inline R inside a code span is a row with the expression and its own position", {
  for (cs in CS_SHAPES) {
    r <- cs_sc(cs$src)
    expect_equal(nrow(r), length(cs$exprs), label = cs$id)
    expect_identical(r$expr, cs$exprs, label = cs$id)
    expect_true(all(r$kind == "bare"), label = cs$id)
    expect_true(all(is.na(r$error)), label = cs$id)
    for (k in seq_along(cs$exprs)) {
      # the position is that of the inline expression, `r ...`, itself
      inner <- regmatches(cs$src, gregexpr("`r#? [a-z] ?`", cs$src))[[1]][k]
      st <- cs_pos(cs$src, inner)
      expect_equal(r$start[k], st, label = paste(cs$id, "start", k))
      expect_equal(r$end[k], st + nchar(inner) - 1L, label = paste(cs$id, "end", k))
      expect_equal(r$line[k], 1L, label = paste(cs$id, "line", k))
    }
  }
})

test_that("CS1: the row is of the same kind and fields as the same inline R outside a code span", {
  inside <- cs_sc("Fit `lm(y ~ `r x`)` here.")
  outside <- cs_sc("Fit lm(y ~ `r x`) here.")
  expect_equal(nrow(outside), 1L)
  expect_identical(inside$kind, outside$kind)
  expect_identical(inside$kind, "bare")
  expect_identical(inside$expr, outside$expr)
  expect_identical(inside$classes, outside$classes)
  expect_identical(inside$keys, outside$keys)
  expect_identical(inside$id, outside$id)
  expect_identical(inside$arms, outside$arms)
  expect_identical(inside$parent, outside$parent)
  expect_identical(inside$arm, outside$arm)
  expect_identical(inside$error, outside$error)
  expect_identical(inside$block_start, outside$block_start)
  expect_identical(names(inside), names(outside))
})

test_that("CS1: a line with ordinary inline values and a code span gives rows in order, positions right", {
  src <- "Mean `r m`{.num} from `f(`r x`)` and `r s`."
  r <- cs_sc(src)
  expect_identical(r$expr, c("m", "x", "s"))
  expect_identical(r$kind, c("value", "bare", "bare"))
  expect_equal(r$start, c(cs_pos(src, "`r m`"), cs_pos(src, "`r x`"), cs_pos(src, "`r s`")))
  expect_equal(r$end[2:3], c(cs_pos(src, "`r x`") + 4L, cs_pos(src, "`r s`") + 4L))
  expect_false(is.unsorted(r$start))
  # the same line with the span's backticks taken off: the other rows are unchanged
  ctl <- cs_sc("Mean `r m`{.num} from f(`r x`) and `r s`.")
  expect_identical(ctl$expr, r$expr)
  expect_identical(ctl$kind, r$kind)
})

test_that("CS1: rows on later lines carry their line", {
  r <- cs_sc("First line.\n\nSecond `f(`r x`)` line.\nThird `g(`r y`)`.")
  expect_identical(r$expr, c("x", "y"))
  expect_equal(r$line, c(3L, 4L))
})

test_that("CS1: a code span in a heading, a list item and a table cell", {
  h <- cs_sc("## Model `lm(y ~ `r x`)`\n\nBody.")
  expect_identical(h$expr, "x")
  expect_equal(h$line, 1L)
  li <- cs_sc("- fit `f(`r x`)` ok\n- plain `g(1)` item")
  expect_identical(li$expr, "x")
  expect_equal(li$line, 1L)
  tab <- "| a | b |\n|---|---|\n| `f(`r x`)` | `g(`r y`)` |\n"
  tb <- cs_sc(tab)
  expect_identical(tb$expr, c("x", "y"))
  expect_equal(tb$line, c(3L, 3L))
  expect_equal(tb$start, c(cs_pos(tab, "`r x`"), cs_pos(tab, "`r y`")))
})

test_that("CS1: a document file (.Rmd, and .qmd on the knitr engine) scans it with the prose context", {
  for (ext in c("Rmd", "qmd")) {
    p <- withr::local_tempfile(fileext = paste0(".", ext))
    writeLines(c("---", "title: t", if (ext == "qmd") "engine: knitr", "---", "", "Fit `f(`r x`)` here."), p)
    r <- weft:::scan_file(p)
    expect_identical(r$expr, "x", label = ext)
    expect_identical(r$context, "prose", label = ext)
    expect_identical(r$kind, "bare", label = ext)
  }
})

# ---- CS2: pairing follows knitr -----------------------------------------------------------------------
# Shapes knitr does NOT evaluate give no row. (Established by knitting them.)

CS_NOT_EVALUATED <- list(
  list(id = "no space after r", src = "See `lm(y ~ `rx`)` here."),
  list(id = "r then a line break", src = "See `f(`r\nx`)` here."),
  list(id = "r then a tab", src = "See `f(`r\tx`)` here."),
  list(id = "capital R", src = "See `f(`R x`)` here."),
  list(id = "bare r", src = "See `f(`r`)` here.")
)

test_that("CS2: a shape knitr leaves alone is not a row", {
  for (cs in CS_NOT_EVALUATED) expect_equal(nrow(cs_sc(cs$src)), 0L, label = cs$id)
})

test_that("CS2: knitr evaluates an expression that does not parse (and fails the knit): it is a row with the 5.3.5 error", {
  # knitr's pattern takes `r x)` as the inline code, so the knit stops on a parse error
  r <- cs_sc("A `f(`r x)` here.")
  expect_equal(nrow(r), 1L)
  expect_identical(r$expr, "x)")
  expect_identical(r$kind, "bare")
  expect_match(r$error, "5.3.5", fixed = TRUE)
})

test_that("CS2: knitr's pattern is a single backtick pair, so the first `r ... ` after an opening backtick wins", {
  # `a `r x` b`: knitr takes `r x` whatever the markdown span pairing is
  r <- cs_sc("`a `r x` b` and `c `r y` d`")
  expect_identical(r$expr, c("x", "y"))
})

# ---- CS3: the gate counts it like any other value -----------------------------------------------------

test_that("CS3: count_constructs() counts it as a value", {
  x <- weft:::count_constructs(read_src("Fit `f(`r x`)` here.", ext = "Rmd"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$kind, "value")
  expect_match(x$text, "`r x`", fixed = TRUE)
  expect_identical(x$line, 1L)
})

test_that("CS3: deleting such a value is a removal", {
  d <- g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f(`r x`)` here.")),
                  list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f()` here.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$removed$kind, "value")
})

test_that("CS3: adding such a value removes nothing and adds one to the count", {
  d <- g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f()` here.")),
                  list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f(`r x`)` here.")))
  res <- g_gate(d)
  expect_identical(max(0, res$n_removed), 0)
  expect_true(res$ok)
  expect_identical(nrow(weft:::count_constructs(read_src("Fit `f()` here.", ext = "Rmd"))), 0L)
  expect_identical(nrow(weft:::count_constructs(read_src("Fit `f(`r x`)` here.", ext = "Rmd"))), 1L)
})

test_that("CS3: a code span with no inline R stays outside the count (control)", {
  d <- g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f(x)` here.")),
                  list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit here.")))
  res <- g_gate(d)
  expect_identical(max(0, res$n_removed), 0)
  expect_true(res$ok)
})

# ---- CS4: the lints that read inline R values see it --------------------------------------------------

test_that("CS4: value-constant fires inside a code span as it does outside", {
  out <- lint_one("Fit lm(y ~ `r x * 100`) here.", rules = "value-constant", ext = "Rmd")
  ins <- lint_one("Fit `lm(y ~ `r x * 100`)` here.", rules = "value-constant", ext = "Rmd")
  expect_identical(lf_texts(out), "100")
  expect_identical(lf_texts(ins), "100")
  expect_identical(ins$message, out$message)
  expect_identical(ins$line, out$line)
})

test_that("CS4: literal-value fires inside a code span as it does outside", {
  out <- lint_one("Fit lm(y ~ `r 10`) here.", rules = "literal-value", ext = "Rmd")
  ins <- lint_one("Fit `lm(y ~ `r 10`)` here.", rules = "literal-value", ext = "Rmd")
  expect_identical(lf_texts(out), "10")
  expect_identical(lf_texts(ins), "10")
  expect_identical(ins$message, out$message)
})

test_that("CS4: the finding sits at the inline expression, not at the code span", {
  src <- "Fit `lm(y ~ `r x * 100`)` here."
  ins <- lint_one(src, rules = "value-constant", ext = "Rmd")
  expect_equal(ins$col, cs_pos(src, "100"))
})

test_that("CS4: a code span with no inline R gives no finding (control)", {
  x <- lint_one("Fit `lm(y ~ x * 100)` here.", rules = c("value-constant", "literal-value"), ext = "Rmd")
  expect_identical(nrow(x), 0L)
})

# ---- CS5: a class block after it is the same construct as outside a code span --------------------------

# the columns of a scan row that do not depend on where the text sits
CS_POSITIONLESS <- c("kind", "file", "line", "classes", "keys", "id", "arms", "arm_templates",
                     "parent", "arm", "error", "resolver")

cs_expect_same_row <- function(inside, outside, label, skip = character()) {
  expect_equal(nrow(outside), 1L, label = paste(label, "outside rows"))
  expect_equal(nrow(inside), 1L, label = paste(label, "inside rows"))
  if (nrow(inside) != 1L || nrow(outside) != 1L) return(invisible())
  expect_identical(names(inside), names(outside), label = paste(label, "columns"))
  for (col in setdiff(intersect(CS_POSITIONLESS, names(outside)), skip))
    expect_identical(inside[[col]], outside[[col]], label = paste(label, col))
  expect_identical(inside$expr, outside$expr, label = paste(label, "expr"))
}

CS5_BLOCKS <- c("{.num}", "{.num digits=2}", "{.pct}", "{.sci}")

test_that("CS5: inline R with a class block inside a code span is a row of the same kind and fields as outside", {
  for (blk in CS5_BLOCKS) {
    outside <- cs_sc(paste0("Fit lm(y ~ `r x`", blk, ") here."))
    inside <- cs_sc(paste0("Fit `lm(y ~ `r x`", blk, ")` here."))
    cs_expect_same_row(inside, outside, blk)
    expect_identical(inside$kind, "value", label = blk)
    expect_true(all(is.na(inside$error)), label = blk)
  }
  # a double-backtick outer span
  outside <- cs_sc("See a `r x`{.num} b there.")
  inside <- cs_sc("See ``a `r x`{.num} b`` there.")
  cs_expect_same_row(inside, outside, "double span")
  expect_identical(inside$kind, "value")
})

test_that("CS5: the row's range runs from the inline code to the end of its class block", {
  for (src in c("Fit `lm(y ~ `r x`{.num})` here.", "Fit `lm(y ~ `r x`{.num digits=2})` here.",
                "See ``a `r x`{.num} b`` there.")) {
    r <- cs_sc(src)
    expect_equal(nrow(r), 1L, label = src)
    expect_equal(r$start, cs_pos(src, "`r x`"), label = src)
    expect_equal(r$block_start, cs_pos(src, "{"), label = src)
    expect_equal(r$end, cs_pos(src, "}"), label = src)
  }
})

test_that("CS5: a static error that applies outside a code span applies inside it, on that row", {
  outside <- cs_sc("Fit lm(y ~ `r x`{.num digits=1 sigfig=2}) here.")
  inside <- cs_sc("Fit `lm(y ~ `r x`{.num digits=1 sigfig=2})` here.")
  expect_match(outside$error, "1.4.7", fixed = TRUE)
  expect_equal(nrow(inside), 1L)
  expect_identical(inside$error, outside$error)
  expect_match(inside$error, "1.4.7", fixed = TRUE)
  expect_identical(inside$kind, outside$kind)
})

test_that("CS5: the construct lint reports that error inside a code span as it does outside", {
  out <- lint_one(c("Prose.", "", "Fit lm(y ~ `r x`{.num digits=1 sigfig=2}) here."), rules = "construct", ext = "Rmd")
  ins <- lint_one(c("Prose.", "", "Fit `lm(y ~ `r x`{.num digits=1 sigfig=2})` here."), rules = "construct", ext = "Rmd")
  expect_identical(nrow(out), 1L)
  expect_identical(nrow(ins), 1L)
  expect_identical(ins$message, out$message)
  expect_identical(ins$spec, out$spec)
  expect_identical(ins$line, 3L)
})

test_that("CS5: a valid classed value inside a code span gives no construct finding (control)", {
  x <- lint_one(c("Prose.", "", "Fit `lm(y ~ `r x`{.num})` here."), rules = "construct", ext = "Rmd")
  expect_identical(nrow(x), 0L)
})

# one knit with the value outside a code span and the same value inside one; the formatted value is
# read from the outside case, so the test does not hard-code weft's formatting
cs_value_knit <- function(blk, body_in, body_dbl = NULL) {
  lines <- c(paste0("OUT |`r x`", blk, "|"),
             paste0("INS ", body_in),
             if (!is.null(body_dbl)) paste0("DBL ", body_dbl))
  res <- d2_render(lines, code = "x <- 12.4567", format = "knit")
  tagged <- function(tag) {
    h <- grep(paste0("^", tag, " "), res$text, value = TRUE)
    expect_length(h, 1L)
    sub(paste0("^", tag, " "), "", h)
  }
  list(out = sub("^\\|(.*)\\|$", "\\1", tagged("OUT")), ins = tagged("INS"),
       dbl = if (is.null(body_dbl)) NULL else tagged("DBL"), res = res)
}

test_that("CS5: a knit renders the formatted value, no braces, inside the code span (.num)", {
  k <- cs_value_knit("{.num}", "Fit `lm(y ~ `r x`{.num})` here.", "See ``a `r x`{.num} b`` there.")
  expect_true(nzchar(k$out))
  expect_false(grepl("[{}]|`r", k$out))
  expect_identical(k$ins, paste0("Fit `lm(y ~ ", k$out, ")` here."))
  expect_identical(k$dbl, paste0("See ``a ", k$out, " b`` there."))
})

test_that("CS5: a knit applies the options of the class block inside the code span (.num digits=2)", {
  k <- cs_value_knit("{.num digits=2}", "Fit `lm(y ~ `r x`{.num digits=2})` here.",
                     "See ``a `r x`{.num digits=2} b`` there.")
  expect_true(nzchar(k$out))
  expect_false(grepl("[{}]|`r", k$out))
  expect_identical(k$ins, paste0("Fit `lm(y ~ ", k$out, ")` here."))
  expect_identical(k$dbl, paste0("See ``a ", k$out, " b`` there."))
})

test_that("CS5: a knit renders .pct and .sci inside a code span as it does outside", {
  for (cls in c(".pct", ".sci")) {
    blk <- paste0("{", cls, "}")
    k <- cs_value_knit(blk, paste0("Fit `lm(y ~ `r x`", blk, ")` here."))
    expect_true(nzchar(k$out), label = cls)
    expect_false(grepl("[{}]|`r", k$out), label = cls)
    expect_identical(k$ins, paste0("Fit `lm(y ~ ", k$out, ")` here."), label = cls)
  }
})

test_that("CS5: the gate counts classed inline R inside a code span as a value, adding and removing", {
  x <- weft:::count_constructs(read_src("Fit `f(`r x`{.num})` here.", ext = "Rmd"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$kind, "value")
  expect_identical(x$line, 1L)
  rm <- g_gate(g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f(`r x`{.num})` here.")),
                          list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f()` here."))))
  expect_false(rm$ok)
  expect_identical(rm$n_removed, 1L)
  expect_identical(rm$removed$kind, "value")
  add <- g_gate(g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f()` here.")),
                           list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f(`r x`{.num})` here."))))
  expect_identical(max(0, add$n_removed), 0)
  expect_true(add$ok)
})

test_that("CS5: unclassed inline R in a code span is still bare (control)", {
  r <- cs_sc("Fit `lm(y ~ `r x`)` here.")
  expect_identical(r$kind, "bare")
  expect_true(is.na(r$error))
})

# ---- CS6: unchanged -----------------------------------------------------------------------------------

test_that("CS6: a code span with no inline R gives no row", {
  for (src in c("Use `f(x)` here.", "Use ``a b`` here.", "Use `r` alone.", "Use `rx` here.",
                "## H `code`\n\n- `item`\n")) {
    expect_equal(nrow(cs_sc(src)), 0L, label = src)
  }
})

test_that("CS6: inline R outside code spans is as before", {
  r <- cs_sc("A `r a` b `r b`{.num} c `r c`{.pct digits=\"1\"}.")
  expect_identical(r$expr, c("a", "b", "c"))
  expect_identical(r$kind, c("bare", "value", "value"))
  r2 <- cs_sc("Plain `r x` and [a | b]{n=\"k\"} and `depth`{.num}.")
  expect_identical(r2$kind, c("bare", "n", "named"))
})

test_that("CS6: a chunk's fenced code gives no row; prose after it is read as before", {
  r <- cs_sc("Text.\n\n```{r}\nx <- 1\n```\n\nAfter `r y`.")
  expect_identical(r$expr, "y")
})

# ---- CS7: inline R in a non-chunk fenced code block ---------------------------------------------------
# knitr evaluates `r x` in a fenced block with no {r} header, whatever the fence (CS_FENCES, established by
# knitting each). It does not in a chunk, nor in the displayed output of a chunk.

CS_FENCES <- list(
  list(id = "backtick fence",          src = c("Before.", "", "```", "a `r x` b", "```", "", "After.")),
  list(id = "tilde fence",             src = c("Before.", "", "~~~", "a `r x` b", "~~~", "", "After.")),
  list(id = "info string",             src = c("Before.", "", "```text", "a `r x` b", "```", "", "After.")),
  # knitr does not treat a tilde fence as a chunk, even with {r}: it evaluates the inline R there
  list(id = "tilde fence with {r}",    src = c("Before.", "", "~~~{r}", "a `r x` b", "~~~", "", "After.")),
  list(id = "tilde with info string",  src = c("Before.", "", "~~~python", "a `r x` b", "~~~", "", "After.")),
  list(id = "attribute block",         src = c("Before.", "", "``` {.text}", "a `r x` b", "```", "", "After.")),
  list(id = "four-backtick fence",     src = c("Before.", "", "````", "a `r x` b", "````", "", "After.")),
  list(id = "in a list item",          src = c("- item", "", "  ```", "  a `r x` b", "  ```", "", "After.")),
  list(id = "in a block quote",        src = c("> ```", "> a `r x` b", "> ```", "", "After.")),
  # the doubled-brace form that shows chunk syntax: knitr does not treat it as a chunk and evaluates the body
  list(id = "doubled-brace header",    src = c("Before.", "", "```{{r}}", "a `r x` b", "```", "", "After.")),
  list(id = "doubled-brace, code body", src = c("Before.", "", "```{{r}}", "y <- `r x`", "```", "", "After."))
)

test_that("CS7: inline R in a non-chunk fenced block is a bare row at its own position", {
  for (cs in CS_FENCES) {
    text <- paste(cs$src, collapse = "\n")
    r <- cs_sc(text)
    expect_equal(nrow(r), 1L, label = cs$id)
    expect_identical(r$expr, "x", label = cs$id)
    expect_identical(r$kind, "bare", label = cs$id)
    expect_true(all(is.na(r$error)), label = cs$id)
    expect_equal(r$start, cs_pos(text, "`r x`"), label = cs$id)
    expect_equal(r$end, cs_pos(text, "`r x`") + 4L, label = cs$id)
    expect_equal(r$line, grep("`r x`", cs$src, fixed = TRUE), label = cs$id)
  }
})

test_that("CS7: the row is of the same kind and fields as the same inline R in ordinary prose", {
  inside <- cs_sc("Before.\n\n```text\na `r x` b\n```\n")
  outside <- cs_sc("Before.\n\na `r x` b\n")
  # the line necessarily differs from the unfenced control, so it is not compared; it is asserted below
  cs_expect_same_row(inside, outside, "fence", skip = "line")
  expect_identical(inside$kind, "bare")
  expect_identical(inside$line, 4L)
  expect_identical(outside$line, 3L)
})

test_that("CS7: two inline R expressions in one fenced block are two rows, with their lines", {
  r <- cs_sc("```\nfirst `r a`\nsecond `r b` and `r c`\n```\n\nAfter `r d`.")
  expect_identical(r$expr, c("a", "b", "c", "d"))
  expect_equal(r$line, c(2L, 3L, 3L, 6L))
  expect_true(all(r$kind == "bare"))
})

test_that("CS7: rows in a fence and in a code span in the same document keep file order", {
  r <- cs_sc("Use `f(`r a`)` here.\n\n```text\nb `r b`\n```\n\nAnd `g(`r c`)`.")
  expect_identical(r$expr, c("a", "b", "c"))
  expect_false(is.unsorted(r$start))
})

test_that("CS7: a classed value in a fenced block is a value row, as outside a fence", {
  for (blk in c("{.num}", "{.num digits=2}", "{.pct}", "{.sci}")) {
    inside <- cs_sc(paste0("```text\nFit `r x`", blk, " here\n```\n"))
    outside <- cs_sc(paste0("Fit `r x`", blk, " here\n"))
    cs_expect_same_row(inside, outside, blk, skip = "line")
    expect_identical(inside$kind, "value", label = blk)
    expect_identical(inside$line, 2L, label = blk)
    expect_identical(outside$line, 1L, label = blk)
  }
})

test_that("CS7: a static error applies in a fenced block as outside", {
  inside <- cs_sc("```text\nFit `r x`{.num digits=1 sigfig=2} here\n```\n")
  expect_equal(nrow(inside), 1L)
  expect_match(inside$error, "1.4.7", fixed = TRUE)
})

test_that("CS7: an indented code block still gives a row, as before (control)", {
  r <- cs_sc("Para.\n\n    a `r x` b\n")
  expect_identical(r$expr, "x")
  expect_identical(r$kind, "bare")
})

test_that("CS7: a chunk's code is never scanned for inline R (control)", {
  for (src in c("```{r}\nz <- 1\n# a `r x` b\n```\n", "```{r, echo=FALSE}\n# a `r x` b\n```\n",
                "```{python}\n# a `r x` b\n```\n", "``` {r}\n# a `r x` b\n```\n")) {
    expect_equal(nrow(cs_sc(src)), 0L, label = src)
  }
  # and the prose after it is still read
  expect_identical(cs_sc("```{r}\n# `r x`\n```\n\nAfter `r y`.\n")$expr, "y")
})

test_that("CS7: a fence after a chunk is read, and the chunk before it is not", {
  r <- cs_sc("```{r}\n# `r p`\n```\n\n```text\n`r q`\n```\n")
  expect_identical(r$expr, "q")
})

test_that("CS7: the gate counts inline R in a fenced block as a value, adding and removing", {
  doc <- c("Fit.", "", "```text", "a `r x` b", "```")
  x <- weft:::count_constructs(read_src(doc, ext = "Rmd"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$kind, "value")
  expect_identical(x$line, 4L)
  none <- weft:::count_constructs(read_src(c("Fit.", "", "```text", "a b", "```"), ext = "Rmd"))
  expect_identical(nrow(none), 0L)
  rm <- g_gate(g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", doc)),
                          list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit.", "", "```text", "a b", "```"))))
  expect_false(rm$ok)
  expect_identical(rm$n_removed, 1L)
  expect_identical(rm$removed$kind, "value")
  add <- g_gate(g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit.", "", "```text", "a b", "```")),
                           list("ch1.qmd" = c(G_ENGINE[-1], "", doc))))
  expect_identical(max(0, add$n_removed), 0)
  expect_true(add$ok)
})

test_that("CS7: a fenced block with no inline R stays outside the count (control)", {
  x <- weft:::count_constructs(read_src(c("```text", "a `b` c", "```"), ext = "Rmd"))
  expect_identical(nrow(x), 0L)
})

test_that("CS7: value-constant fires inside a fenced block as it does outside", {
  out <- lint_one("Fit `r x * 100` here.", rules = "value-constant", ext = "Rmd")
  ins <- lint_one(c("Fit.", "", "```text", "a `r x * 100` b", "```"), rules = "value-constant", ext = "Rmd")
  expect_identical(lf_texts(ins), lf_texts(out))
  expect_identical(ins$message, out$message)
})

test_that("CS7: a knit evaluates inline R in each fence shape (what knitr does), bare value", {
  for (cs in CS_FENCES) {
    res <- d2_render(cs$src, code = "x <- 7771", format = "knit")
    expect_true(any(grepl("a 7771 b|y <- 7771", res$text)), label = cs$id)
    expect_false(any(grepl("`r x`", res$text, fixed = TRUE)), label = cs$id)
  }
})

test_that("CS7: a knit renders a classed value in a fenced block as it does in prose, with no braces", {
  for (blk in c("{.num}", "{.num digits=2}", "{.pct}")) {
    lines <- c(paste0("OUT |`r x`", blk, "|"), "", "```text", paste0("FENCE `r x`", blk, " end"), "```",
               "", "~~~", paste0("TILDE `r x`", blk, " end"), "~~~",
               "", "- item", "", "  ```", paste0("  LIST `r x`", blk, " end"), "  ```")
    res <- d2_render(lines, code = "x <- 12.4567", format = "knit")
    v <- sub("^OUT \\|(.*)\\|$", "\\1", grep("^OUT ", res$text, value = TRUE))
    expect_length(v, 1L)
    expect_false(grepl("[{}]|`r", v), label = blk)
    expect_true(paste0("FENCE ", v, " end") %in% res$text, label = paste(blk, "backtick"))
    expect_true(paste0("TILDE ", v, " end") %in% res$text, label = paste(blk, "tilde"))
    expect_true(paste0("  LIST ", v, " end") %in% res$text, label = paste(blk, "list"))
  }
})

test_that("CS7: a knit leaves a chunk's code and its displayed output alone (control)", {
  lines <- c("```{r}", "# comment `r x` here", "cat('```text\\nout `r 5` out\\n```\\n')", "```")
  res <- d2_render(lines, code = "x <- 7771", format = "knit")
  expect_true(any(grepl("# comment `r x` here", res$text, fixed = TRUE)))
  expect_true(any(grepl("out `r 5` out", res$text, fixed = TRUE)))
  expect_false(any(grepl("7771", res$text, fixed = TRUE)))
})

# ---- CS8: inline R inside an HTML comment ---------------------------------------------------------------
# Owner's ruling: wherever knitr's inline pattern evaluates `r x`, weft reads it as in prose. Stock knitr
# evaluates it inside an HTML comment, single-line and multi-line, closed or not. Rule 1.9.2 is withdrawn
# for comments (rule 1.1.10 now). Bracketed spans in comments are out of scope and not tested.

test_that("CS8: bare inline R in a single-line comment is a row of the same kind and fields as in prose", {
  inside <- cs_sc("Before.\n\n<!-- c `r x` d -->\n")
  outside <- cs_sc("Before.\n\nc `r x` d\n")
  cs_expect_same_row(inside, outside, "comment", skip = "line")
  expect_identical(inside$kind, "bare")
  expect_identical(inside$expr, "x")
  expect_identical(inside$line, 3L)
  src <- "<!-- c `r x` d -->"
  r <- cs_sc(src)
  expect_equal(r$start, cs_pos(src, "`r x`"))
  expect_equal(r$end, cs_pos(src, "`r x`") + 4L)
})

test_that("CS8: inline R in a multi-line comment is a row, with its own line", {
  text <- "Before.\n\n<!--\nfirst line\nsecond `r x` line\n-->\n\nAfter `r y`."
  r <- cs_sc(text)
  expect_identical(r$expr, c("x", "y"))
  expect_identical(r$kind, c("bare", "bare"))
  expect_equal(r$line, c(5L, 8L))
  expect_equal(r$start[1], cs_pos(text, "`r x`"))
})

test_that("CS8: two inline R expressions in one comment are two rows", {
  src <- "<!-- `r a` and `r b` -->"
  r <- cs_sc(src)
  expect_identical(r$expr, c("a", "b"))
  expect_equal(r$start, c(cs_pos(src, "`r a`"), cs_pos(src, "`r b`")))
  expect_true(all(r$kind == "bare"))
  r2 <- cs_sc("<!-- `r a` and `r b`{.num} -->")
  expect_identical(r2$kind, c("bare", "value"))
})

test_that("CS8: a classed value in a comment is a value row, as outside a comment", {
  for (blk in c("{.num}", "{.num digits=2}", "{.pct}", "{.sci}")) {
    inside <- cs_sc(paste0("<!-- Fit `r x`", blk, " here -->\n"))
    outside <- cs_sc(paste0("Fit `r x`", blk, " here\n"))
    cs_expect_same_row(inside, outside, blk)
    expect_identical(inside$kind, "value", label = blk)
    multi <- cs_sc(paste0("<!--\nFit `r x`", blk, " here\n-->\n"))
    cs_expect_same_row(multi, outside, paste(blk, "multi-line"), skip = "line")
    expect_identical(multi$line, 2L, label = blk)
  }
})

test_that("CS8: a static error applies in a comment as outside", {
  inside <- cs_sc("<!-- Fit `r x`{.num digits=1 sigfig=2} here -->\n")
  expect_equal(nrow(inside), 1L)
  expect_match(inside$error, "1.4.7", fixed = TRUE)
  outside <- cs_sc("Fit `r x`{.num digits=1 sigfig=2} here\n")
  expect_identical(inside$error, outside$error)
})

test_that("CS8: a comment with no inline R gives no row (control)", {
  for (src in c("<!-- a `b` c -->", "<!-- plain note -->", "<!--\nmulti\nline\n-->", "<!-- `rx` and `r` -->")) {
    expect_equal(nrow(cs_sc(src)), 0L, label = src)
  }
})

test_that("CS8: prose after a comment is still read, with its line (control)", {
  r <- cs_sc("<!-- `r x` -->\n`r y`{.num}")
  expect_identical(r$expr, c("x", "y"))
  expect_equal(r$line, c(1L, 2L))
})

test_that("CS8: a comment inside a chunk's code is not scanned (control)", {
  expect_equal(nrow(cs_sc("```{r}\n# <!-- `r x` -->\ncat('<!-- `r y` -->')\n```\n")), 0L)
  expect_identical(cs_sc("```{r}\n# <!-- `r x` -->\n```\n\nAfter `r z`.\n")$expr, "z")
})

test_that("CS8: a comment in a non-chunk fence is read as the fence's text is (CS7)", {
  r <- cs_sc("```text\n<!-- `r x` -->\n```\n")
  expect_identical(r$expr, "x")
})

test_that("CS8: a comment with `-->` right after the value gives a row, and the text after it is read", {
  src <- "<!-- `r x`--> after `r y`"
  r <- cs_sc(src)
  expect_identical(r$expr, c("x", "y"))
  expect_equal(r$end[1], cs_pos(src, "`r x`") + 4L)
  r2 <- cs_sc("<!-- `r x`{.num}--> after")
  expect_identical(r2$kind, "value")
  expect_identical(r2$expr, "x")
})

test_that("CS8: an unclosed comment gives a row exactly where knitr evaluates, which is anywhere after it", {
  # mid-line
  r <- cs_sc("a <!-- unclosed `r x`{.num}")
  expect_identical(r$expr, "x")
  expect_identical(r$kind, "value")
  # at the start of a line, the same line and the lines after it (a line-start unclosed comment used to swallow them)
  r <- cs_sc("<!-- unclosed `r x`{.num}")
  expect_identical(r$expr, "x")
  expect_identical(r$kind, "value")
  r <- cs_sc("<!-- unclosed\n`r x`{.num}\nmore `r y`")
  expect_identical(r$expr, c("x", "y"))
  expect_equal(r$line, c(2L, 3L))
})

test_that("CS8: the gate counts inline R in a comment as a value, adding and removing", {
  doc <- c("Fit.", "", "<!-- a `r x` b -->")
  x <- weft:::count_constructs(read_src(doc, ext = "Rmd"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$kind, "value")
  expect_identical(x$line, 3L)
  none <- weft:::count_constructs(read_src(c("Fit.", "", "<!-- a b -->"), ext = "Rmd"))
  expect_identical(nrow(none), 0L)
  rm <- g_gate(g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", doc)),
                          list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit.", "", "<!-- a b -->"))))
  expect_false(rm$ok)
  expect_identical(rm$n_removed, 1L)
  expect_identical(rm$removed$kind, "value")
  add <- g_gate(g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit.", "", "<!-- a b -->")),
                           list("ch1.qmd" = c(G_ENGINE[-1], "", doc))))
  expect_identical(max(0, add$n_removed), 0)
  expect_true(add$ok)
})

test_that("CS8: value-constant and literal-value fire inside a comment as they do outside", {
  out <- lint_one("Fit `r x * 100` here.", rules = "value-constant", ext = "Rmd")
  ins <- lint_one(c("Fit.", "", "<!-- a `r x * 100` b -->"), rules = "value-constant", ext = "Rmd")
  expect_identical(lf_texts(ins), lf_texts(out))
  expect_identical(ins$message, out$message)
  lit <- lint_one(c("Fit.", "", "<!-- a `r 10` b -->"), rules = "literal-value", ext = "Rmd")
  expect_identical(lf_texts(lit), "10")
})

test_that("CS8 (control): things that already ignore comments still do", {
  # prose lints do not read the words in a comment, and a comment is not scanned for names or decision ids
  expect_identical(lint_one(c("Text.", "", "12 sites"), rules = "numeral", ext = "Rmd")$text, "12")  # the lint is live
  expect_equal(nrow(lint_one(c("Text.", "", "<!-- 12 sites -->"), rules = "numeral", ext = "Rmd")), 0L)
  expect_equal(nrow(lint_one(c("Text.", "", "<!-- 12 sites `r x` -->"), rules = "numeral", ext = "Rmd")), 0L)
  expect_equal(nrow(lint_one(c("Text.", "", "<!-- `x`{.nmu} -->"), rules = "name", ext = "Rmd")), 0L)
  # a weft-file marker is a comment and is not an inline R row
  expect_equal(nrow(cs_sc("<!-- weft-file: use_agent_docs 1.0 0123456789abcdef0123456789abcdef -->")), 0L)
  expect_equal(nrow(cs_sc("<!-- weft:start use_agent_docs 1.0 0123456789abcdef0123456789abcdef -->\nbody\n<!-- weft:end -->")), 0L)
})

test_that("CS8: a knit evaluates inline R in a comment, single-line and multi-line, as stock knitr does", {
  lines <- c("OUT `r x` end", "", "<!-- one `r x` end -->", "", "<!--", "multi `r x` end", "-->")
  res <- d2_render(lines, code = "x <- 7771", format = "knit")
  expect_true("<!-- one 7771 end -->" %in% res$text)
  expect_true("multi 7771 end" %in% res$text)
  expect_false(any(grepl("`r x`", res$text, fixed = TRUE)))
})

test_that("CS8: a knit renders a classed value in a comment as it does in prose, with no braces", {
  for (blk in c("{.num}", "{.num digits=2}", "{.pct}")) {
    lines <- c(paste0("OUT |`r x`", blk, "|"), "", paste0("<!-- COM `r x`", blk, " end -->"), "",
               "<!--", paste0("MULTI `r x`", blk, " end"), "-->")
    res <- d2_render(lines, code = "x <- 12.4567", format = "knit")
    v <- sub("^OUT \\|(.*)\\|$", "\\1", grep("^OUT ", res$text, value = TRUE))
    expect_length(v, 1L)
    expect_false(grepl("[{}]|`r", v), label = blk)
    expect_true(paste0("<!-- COM ", v, " end -->") %in% res$text, label = paste(blk, "single"))
    expect_true(paste0("MULTI ", v, " end") %in% res$text, label = paste(blk, "multi"))
  }
})
