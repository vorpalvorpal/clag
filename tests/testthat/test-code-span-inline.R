# Finding 21 (dev/open-findings.md): inline R inside a markdown code span.
# knitr runs its own regex over the raw text, so `r x` inside a code span is
# evaluated and its value lands in the span. The scanner tokenises the outer
# span first and never sees it. Rules CS1 to CS6 are the owner's ruling;
# rule 1.1.12 is the new rule for a class block after such inline R (CS5).
# Which shapes knitr evaluates was established by knitting them (CS_SHAPES,
# CS_NOT_EVALUATED).

cs_sc <- function(x) weft:::scan_text(x)
cs_pos <- function(text, pat) as.integer(regexpr(pat, text, fixed = TRUE))
cs_msg <- paste0("inline R inside a code span cannot take a class: the result lands in the code span ",
                 "and the braces stay as text. Move the value out of the code span (rule 1.1.12).")

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

# ---- CS5: a class block after it cannot take effect ---------------------------------------------------

test_that("CS5: a class block after inline R inside a code span is an error with the exact message", {
  for (src in c("Fit `lm(y ~ `r x`{.num})` here.", "See ``a `r x`{.num} b`` there.",
                "Fit `lm(y ~ `r x`{digits=\"2\"})` here.")) {
    r <- cs_sc(src)
    expect_equal(nrow(r), 1L, label = src)
    expect_identical(r$expr, "x", label = src)
    expect_identical(r$error, cs_msg, label = src)
    expect_equal(r$start, cs_pos(src, "`r x`"), label = src)
  }
})

test_that("CS5: no such error for unclassed inline R in a code span, nor for a classed value outside one (controls)", {
  expect_false(any(!is.na(cs_sc("Fit `lm(y ~ `r x`)` here.")$error)))
  r <- cs_sc("Fit lm(y ~ `r x`{.num}) here.")
  expect_equal(nrow(r), 1L)
  expect_true(is.na(r$error))
})

test_that("CS5: the construct lint reports it, as the scanner words it, with spec 1.1.12", {
  x <- lint_one(c("Prose.", "", "Fit `lm(y ~ `r x`{.num})` here."), rules = "construct", ext = "Rmd")
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "construct")
  expect_identical(x$message, cs_msg)
  expect_identical(x$spec, "1.1.12")
  expect_identical(x$line, 3L)
})

test_that("CS5: the gate fails on it", {
  d <- g_scenario(list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f()` here.")),
                  list("ch1.qmd" = c(G_ENGINE[-1], "", "Fit `f(`r x`{.num})` here.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("construct" %in% res$errors$rule)
  expect_true(cs_msg %in% res$errors$message)
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
