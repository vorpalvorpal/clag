# Stage 1a: the scanner (scan_text, scan_file, mask_text).
# Rule numbers are from PACKAGE-SCOPING.md; the interface is dev/design-1a.md.

sc <- function(x, ...) weft:::scan_text(x, ...)
# classes as written, with any leading dot removed (the design note does not
# say whether the stored class keeps its dot)
cl <- function(r, i = 1) sub("^\\.", "", r$classes[[i]])
# the construct errors found in a text
errs <- function(x) {
  r <- sc(x)
  r$error[!is.na(r$error)]
}

scan_cols <- c(
  "kind", "file", "line", "start", "end", "expr", "classes", "keys", "id",
  "arms", "parent", "arm", "error"
)

# ---- shape -------------------------------------------------------------

test_that("2.10.1: scan_text returns a data frame with the documented columns", {
  r <- sc("Mean was `r x`{.num} m.")
  expect_s3_class(r, "data.frame")
  expect_true(all(scan_cols %in% names(r)))
  expect_type(r$classes, "list")
  expect_type(r$keys, "list")
  expect_type(r$arms, "list")
})

test_that("2.10.1: text with no construct gives zero rows and the columns", {
  r <- sc("Nothing to see here.\n\nSecond paragraph.")
  expect_equal(nrow(r), 0L)
  expect_true(all(scan_cols %in% names(r)))
  expect_equal(nrow(sc("")), 0L)
})

test_that("file defaults to NA and is carried through", {
  expect_true(is.na(sc("`r x`{.num}")$file))
  expect_equal(sc("`r x`{.num}", file = "a.qmd")$file, "a.qmd")
})

# ---- kinds, expr, classes ----------------------------------------------

test_that("1.1.1, 1.1.4, 1.1.8: kinds and expressions", {
  cases <- list(
    list("`r x`", "bare", "x"),
    list("`{r} x`", "bare", "x"),
    list("`r x`{.num}", "value", "x"),
    list("`{r} x`{.num}", "value", "x"),
    list("`r mean(depth) + 1`{.num}", "value", "mean(depth) + 1"),
    list("[a | b]{n=\"k\"}", "n", "k"),
    list("[a | b]{if=\"x > 0\"}", "if", "x > 0"),
    list("[a]{if=\"x\"}", "if", "x"),
    list("[results]{.strong}", "text", NA_character_),
    list("[results]{.em}", "text", NA_character_)
  )
  for (cs in cases) {
    r <- sc(cs[[1]])
    label <- cs[[1]]
    expect_equal(nrow(r), 1L, label = label)
    expect_equal(r$kind, cs[[2]], label = label)
    expect_equal(r$expr, cs[[3]], label = label)
    expect_true(is.na(r$error), label = label)
    expect_true(is.na(r$parent), label = label)
    expect_true(is.na(r$arm), label = label)
  }
})

test_that("1.1.4: the Quarto form and the knitr form scan alike", {
  a <- sc("Is `r x`{.num digits=\"2\"} m.")
  b <- sc("Is `{r} x`{.num digits=\"2\"} m.")
  expect_equal(a$kind, b$kind)
  expect_equal(a$expr, b$expr)
  expect_equal(a$classes, b$classes)
  expect_equal(a$keys, b$keys)
})

test_that("1.1.7: an attribute block must touch the closing backtick or bracket", {
  r <- sc("`r x` {.num}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "bare")
  expect_equal(substr("`r x` {.num}", r$start, r$end), "`r x`")
  expect_equal(nrow(sc("[a | b] {n=\"k\"}")), 0L)
  expect_equal(nrow(sc("[results] {.strong}")), 0L)
})

test_that("1.2.1, 1.2.4: block order does not matter; quoted or unquoted", {
  forms <- c(
    "`r x`{.num digits=\"2\"}",
    "`r x`{digits=\"2\" .num}",
    "`r x`{.num digits=2}",
    "`r x`{digits=2 .num}"
  )
  for (f in forms) {
    r <- sc(f)
    expect_equal(r$kind, "value", label = f)
    expect_equal(cl(r), "num", label = f)
    expect_equal(unname(r$keys[[1]]["digits"]), "2", label = f)
    expect_true(is.na(r$error), label = f)
  }
})

test_that("1.2.1, 1.2.4: classes keep their written order", {
  expect_equal(cl(sc("`r k`{.word .strong .no}")), c("word", "strong", "no"))
  expect_equal(cl(sc("`r k`{.no .word}")), c("no", "word"))
})

test_that("1.2.10: weft keys are lower-cased in any letter case; others are not", {
  r <- sc("`r x`{.num DIGITS=\"2\"}")
  expect_equal(names(r$keys[[1]]), "digits")
  r <- sc("`r x`{.num Digits=2 Custom-Style=\"Key figure\"}")
  expect_true(all(c("digits", "Custom-Style") %in% names(r$keys[[1]])))
  expect_equal(unname(r$keys[[1]]["Custom-Style"]), "Key figure")
  expect_true(is.na(r$error))
})

test_that("1.2.10: a governor key in any case is that governor", {
  r <- sc("[a | b]{If=\"x > 0\"}")
  expect_equal(r$kind, "if")
  expect_equal(r$expr, "x > 0")
  r <- sc("[a | b]{N=\"k\"}")
  expect_equal(r$kind, "n")
  expect_equal(r$expr, "k")
  expect_equal(sc("[a | b]{IF=\"x\"}")$kind, "if")
})

test_that("1.2.10: class names are matched exactly (.Num is not .num)", {
  r <- sc("`r x`{.Num}")
  expect_equal(nrow(r), 1L)
  expect_equal(cl(r), "Num")
  expect_true(is.na(r$error))
  # a bracket with only .Num is an ordinary span, as [1234]{.num} is
  expect_equal(nrow(sc("[abc]{.Num}")), 0L)
})

test_that("1.2.6, 1.2.7: unknown classes and keys pass through and are not errors", {
  r <- sc("`r x`{.num .smallcaps custom-style=\"Key figure\"}")
  expect_true(is.na(r$error))
  expect_true("smallcaps" %in% cl(r))
  expect_equal(unname(r$keys[[1]]["custom-style"]), "Key figure")
  r <- sc("`r x`{.nmu trunk=\"3\"}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "value")
  expect_true(is.na(r$error))
  r <- sc("[a | b]{n=\"k\" .smallcaps data-x=\"y\"}")
  expect_equal(r$kind, "n")
  expect_true(is.na(r$error))
  expect_true("smallcaps" %in% cl(r))
})

test_that("1.2.2: single quotes inside a double-quoted value are R strings", {
  r <- sc("[a | b]{if=\"tier == 'sev'\"}")
  expect_equal(r$kind, "if")
  expect_equal(r$expr, "tier == 'sev'")
  expect_true(is.na(r$error))
})

test_that("1.5.4: an if takes a comma-separated list read as an argument list", {
  r <- sc("[a | b]{if=\"n_gap > 10, n_sites >= 3\"}")
  expect_equal(r$kind, "if")
  expect_true(is.na(r$error))
})

test_that("1.5.6, 3.1.1: claim() with a check inside a governor is fine", {
  r <- sc("[# metre | # metres]{.num n=\"claim(depth, . > 0.5)\"}")
  expect_equal(r$kind, "n")
  expect_equal(r$expr, "claim(depth, . > 0.5)")
  expect_true(is.na(r$error))
  expect_equal(r$arms[[1]], c("# metre", "# metres"))
})

test_that("1.2.1: an #id is recorded in any position", {
  for (f in c("`r x`{#d .num}", "`r x`{.num #d}")) {
    r <- sc(f)
    expect_equal(r$id, "d", label = f)
    expect_equal(cl(r), "num", label = f)
  }
  expect_true(is.na(sc("`r x`{.num}")$id))
})

# ---- arms --------------------------------------------------------------

test_that("1.5.1: arms are split on | and trimmed", {
  cases <- list(
    list("[a person | # people]{n=\"n\"}", c("a person", "# people")),
    list("[no people | a person | # people]{n=\"n\"}",
         c("no people", "a person", "# people")),
    list("[never | once | twice | # times]{n=\"k\"}",
         c("never", "once", "twice", "# times")),
    list("[  a  |  b  ]{if=\"x\"}", c("a", "b")),
    list("[The target was met | not met]{if=\"x >= target\"}",
         c("The target was met", "not met")),
    list("[# people]{n=\"n\"}", "# people"),
    list("[Council will need to add more sites]{if=\"n_gap > 10\"}",
         "Council will need to add more sites"),
    list("[, apart from the estuary sites | ]{if=\"n_missing > 0\"}",
         c(", apart from the estuary sites", "")),
    list("[ | s]{n=\"n\"}", c("", "s")),
    list("[s | | s]{n=\"k\"}", c("s", "", "s"))
  )
  for (cs in cases) {
    r <- sc(cs[[1]])
    expect_equal(nrow(r), 1L, label = cs[[1]])
    expect_equal(r$arms[[1]], cs[[2]], label = cs[[1]])
    expect_true(is.na(r$error), label = cs[[1]])
  }
})

test_that("1.5.12: the spec's escape examples", {
  cases <- list(
    list("[a||b | c]{if=\"x > 0\"}", c("a|b", "c")),
    list("[a\\|\\|b \\| c]{if=\"x > 0\"}", c("a|b", "c")),
    list("[a||| c]{if=\"x > 0\"}", c("a|", "c")),
    list("site[s | | s]{n=\"k\"}", c("s", "", "s"))
  )
  for (cs in cases) {
    r <- sc(cs[[1]])
    expect_equal(nrow(r), 1L, label = cs[[1]])
    expect_equal(r$arms[[1]], cs[[2]], label = cs[[1]])
    expect_true(is.na(r$error), label = cs[[1]])
  }
})

test_that("1.5.12: a doubled ## is a literal #", {
  r <- sc("[item ## | other]{if=\"x\"}")
  expect_equal(r$arms[[1]], c("item #", "other"))
})

test_that("1.5.12: a space between separators makes an empty arm", {
  r <- sc("[a | | b | c]{n=\"k\"}")
  expect_equal(r$arms[[1]], c("a", "", "b", "c"))
})

test_that("1.5.14: | and # inside math, code, link targets and raw are not separators", {
  cases <- list(
    list("[a $x|y$ | b]{if=\"z\"}", c("a $x|y$", "b")),
    list("[a `x|y` | b]{if=\"z\"}", c("a `x|y`", "b")),
    list("[a `#` | b]{if=\"z\"}", c("a `#`", "b")),
    list("[see [link](http://a.b/c#d|e) | b]{if=\"z\"}",
         c("see [link](http://a.b/c#d|e)", "b")),
    list("[a `x|y`{=html} | b]{if=\"z\"}", c("a `x|y`{=html}", "b"))
  )
  for (cs in cases) {
    r <- sc(cs[[1]])
    expect_equal(nrow(r), 1L, label = cs[[1]])
    expect_equal(r$arms[[1]], cs[[2]], label = cs[[1]])
    expect_true(is.na(r$error), label = cs[[1]])
  }
})

test_that("1.1.9: a text span has no arms; | and # in it are ordinary", {
  r <- sc("[a | b # c]{.strong}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "text")
  expect_true(is.na(r$error))
})

test_that("1.5.13: in a pipe-table cell an escaped \\| is the separator", {
  tbl <- paste(
    "| name | n |", "|------|---|",
    "| [x \\| y]{n=\"k\"} | 1 |", sep = "\n"
  )
  r <- sc(tbl)
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "n")
  expect_equal(r$arms[[1]], c("x", "y"))
  expect_true(is.na(r$error))
})

# ---- nesting -----------------------------------------------------------

test_that("1.5.15: nested constructs record parent and arm; parent comes first", {
  r <- sc("[a | b `r x`{.num} c]{if=\"z\"}")
  expect_equal(nrow(r), 2L)
  expect_equal(r$kind, c("if", "value"))
  expect_true(is.na(r$parent[1]))
  expect_equal(r$parent[2], 1L)
  expect_equal(r$arm[2], 2L)

  r <- sc("[x `r y`{.num} | w]{if=\"a\"}")
  expect_equal(r$parent[2], 1L)
  expect_equal(r$arm[2], 1L)
})

test_that("1.5.15: a span inside an arm does not split the outer arms", {
  r <- sc("[x [y | z]{if=\"b\"} | w]{if=\"a\"}")
  expect_equal(nrow(r), 2L)
  expect_equal(length(r$arms[[1]]), 2L)
  expect_equal(r$arms[[1]][2], "w")
  expect_equal(r$kind, c("if", "if"))
  expect_equal(r$parent[2], 1L)
  expect_equal(r$arm[2], 1L)
  expect_equal(r$expr, c("a", "b"))
})

test_that("1.5.15: three levels of nesting", {
  r <- sc("[p [q [r1 | r2]{if=\"c\"} | s]{if=\"b\"} | t]{if=\"a\"}")
  expect_equal(nrow(r), 3L)
  expect_equal(r$expr, c("a", "b", "c"))
  expect_equal(r$parent, c(NA, 1L, 2L))
})

test_that("1.5.15: a value inside a text span has the span as parent", {
  r <- sc("[see `r x`{.num}]{.strong}")
  expect_equal(r$kind, c("text", "value"))
  expect_equal(r$parent[2], 1L)
})

test_that("3.1.8: a bare value inside a one-arm if is nested; one outside is not", {
  r <- sc("[All `r nrow(mod)` models rise]{if=\"all(mod$rising)\"}")
  expect_equal(r$kind, c("if", "bare"))
  expect_equal(r$parent[2], 1L)
  expect_equal(r$arm[2], 1L)
  r <- sc("[All]{if=\"all(mod$rising)\"} `r nrow(mod)` models rise.")
  expect_equal(r$kind, c("if", "bare"))
  expect_true(is.na(r$parent[2]))
  expect_equal(r$expr[1], "all(mod$rising)")
})

test_that("1.1.2: a $ inside an attribute value is R, not math", {
  r <- sc("[a | b]{if=\"x$a > 0\"} and [c | d]{if=\"y$b > 0\"}")
  expect_equal(nrow(r), 2L)
  expect_equal(r$expr, c("x$a > 0", "y$b > 0"))
  expect_true(all(is.na(r$error)))
  expect_equal(r$arms[[2]], c("c", "d"))
})

test_that("1.7.2: n=\".\" is legal inside an n span and inherits it", {
  r <- sc("[# sample[ | s]{n=\".\"} [was | were]{n=\".\"} taken]{n=\"n\"}")
  expect_equal(nrow(r), 3L)
  expect_equal(r$kind, c("n", "n", "n"))
  expect_equal(r$expr, c("n", ".", "."))
  expect_equal(r$parent, c(NA, 1L, 1L))
  expect_equal(r$arm[2:3], c(1L, 1L))
  expect_equal(r$arms[[2]], c("", "s"))
  expect_equal(r$arms[[3]], c("was", "were"))
  expect_true(all(is.na(r$error)))
})

# ---- lines and offsets -------------------------------------------------

test_that("2.10.1: start and end cover the whole construct, block included", {
  constructs <- c(
    "`r x`", "`{r} x`", "`r x`{.num}", "`{r} x`{.num digits=\"2\"}",
    "[a | b]{n=\"k\"}", "[a]{if=\"x\"}", "[results]{.strong}",
    "[# metre | # metres]{.num n=\"claim(depth, . > 0.5)\"}"
  )
  for (cn in constructs) {
    txt <- paste0("Before ", cn, " after.")
    r <- sc(txt)
    expect_equal(nrow(r), 1L, label = cn)
    expect_equal(substr(txt, r$start, r$end), cn, label = cn)
  }
})

test_that("2.10.1: two constructs on one line are in textual order", {
  txt <- "A `r x`{.num} then [a | b]{if=\"y\"} then `r z`."
  r <- sc(txt)
  expect_equal(r$kind, c("value", "if", "bare"))
  expect_true(all(diff(r$start) > 0))
  expect_equal(r$line, c(1L, 1L, 1L))
})

test_that("2.10.1: line is the line of the construct's first character", {
  txt <- "one\ntwo `r x`{.num}\n\nfour [a |\nb]{if=\"y\"} five\n`r z`"
  r <- sc(txt)
  expect_equal(r$line, c(2L, 4L, 6L))
  expect_equal(r$kind, c("value", "if", "bare"))
})

test_that("2.10.1: first_line shifts every line", {
  txt <- "one\ntwo `r x`{.num}\n\nfour [a |\nb]{if=\"y\"} five"
  r <- sc(txt, first_line = 10L)
  expect_equal(r$line, c(11L, 13L))
})

test_that("2.10.1: a multi-line bracket gives offsets spanning the break", {
  txt <- "Intro [first part |\nsecond part]{if=\"x\"} end."
  r <- sc(txt)
  expect_equal(nrow(r), 1L)
  expect_equal(r$line, 1L)
  expect_equal(substr(txt, r$start, r$end),
               "[first part |\nsecond part]{if=\"x\"}")
  expect_equal(r$arms[[1]], c("first part", "second part"))
})

# ---- what 1.9 leaves alone ---------------------------------------------

test_that("1.9.1: ordinary spans, links, citations, footnotes are not constructs", {
  leave <- c(
    "[text]{.smallcaps}",
    "[text]{custom-style=\"Key\"}",
    "[a link](http://example.org)",
    "[a link](http://example.org){target=\"_blank\"}",
    "[@smith2020]",
    "[@a; @b, p. 3]",
    "text[^1] and\n\n[^1]: A note.",
    "[1234]{.num}",
    "[1234]{.num digits=\"2\"}",
    "[x]{.pct}",
    "[a | b]",
    "[abc]{iff=\"x > 0\"}",
    "[abc]{trunk=\"3\"}",
    "![alt](fig.png){width=50%}",
    "`code`",
    "`x <- 1`{.r}",
    "`{python} x`",
    "$a | b$",
    "a [] b"
  )
  for (s in leave) {
    expect_equal(nrow(sc(s)), 0L, label = s)
  }
})

test_that("1.1.9: [1234]{.num} is not a construct and has no error", {
  expect_equal(nrow(sc("The value [1234]{.num} stays.")), 0L)
})

test_that("1.1.10, 1.9.1: inline R in a fenced block that is not a chunk is read; a bracketed span there is not", {
  rows <- list(
    list(f = "```\n`r x`{.num}\n```", kind = "value", expr = "x"),
    list(f = "```python\nx = `r x`{.num}\n```", kind = "value", expr = "x"),
    list(f = "```text\n`r x`\n```", kind = "bare", expr = "x"),
    list(f = "~~~{r}\n`r x`\n~~~", kind = "bare", expr = "x")
  )
  for (w in rows) {
    r <- sc(paste0("Before\n\n", w$f, "\n\nAfter"))
    expect_equal(nrow(r), 1L, label = w$f)
    expect_equal(r$kind, w$kind, label = w$f)
    expect_equal(r$expr, w$expr, label = w$f)
    expect_equal(r$line, 4L, label = w$f)
  }
  # a bracketed span (a multi-code construct) in a fence is not read
  none <- c(
    "~~~\n[a | b]{if=\"x\"}\n~~~",
    "````markdown\n```\n[a | b]{n=\"k\"}\n```\n````"
  )
  for (f in none) {
    expect_equal(nrow(sc(paste0("Before\n\n", f, "\n\nAfter"))), 0L, label = f)
  }
  # a real chunk is still never scanned
  for (f in c("```{r}\n`r x`{.num}\n```", "```{python}\nx = `r x`\n```")) {
    expect_equal(nrow(sc(paste0("Before\n\n", f, "\n\nAfter"))), 0L, label = f)
  }
})

test_that("1.1.10: the prose after a fence is still scanned, with its line, after the fence's own row", {
  r <- sc("```\n`r x`{.num}\n```\nthen `r y`{.num}")
  expect_equal(nrow(r), 2L)
  expect_equal(r$expr, c("x", "y"))
  expect_equal(r$line, c(2L, 4L))
  r <- sc("```{r}\n`r x`{.num}\n```\nthen `r y`{.num}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$expr, "y")
  expect_equal(r$line, 4L)
})

test_that("1.1.10: inline R in an HTML comment is read", {
  r <- sc("<!-- `r x`{.num} -->")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "value")
  expect_equal(r$expr, "x")
  r <- sc("<!--\n`r y`\n-->")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "bare")
  expect_equal(r$line, 2L)
  r <- sc("<!-- `r x` -->\n`r y`{.num}")
  expect_equal(nrow(r), 2L)
  expect_equal(r$expr, c("x", "y"))
  expect_equal(r$line, c(1L, 2L))
})

test_that("2.10.1: inline R inside math is read", {
  r <- sc("Let $a = `r x`$ hold.")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "bare")
  expect_equal(r$expr, "x")
})

test_that("1.1.8: bare inline R is a row of kind bare, not a construct error", {
  r <- sc("Depth `r depth` m and `{r} other`.")
  expect_equal(r$kind, c("bare", "bare"))
  expect_equal(r$expr, c("depth", "other"))
  expect_true(all(is.na(r$error)))
})

# ---- construct errors (5.3.1) ------------------------------------------

test_that("5.3.1: valid constructs carry no error (controls)", {
  ok <- c(
    "`r x`{.num}", "`r x`{.num digits=\"2\"}", "`r x`{.num sigfig=3}",
    "`r k`{.no .word}", "`r k`{.word .strong}", "`r k`{.count}",
    "`r k`{.ord}", "`r s`{.and sep=\"; \"}", "`r s`{.or last=\" or else \"}",
    "[a | b]{n=\"k\"}", "[a | b | c]{n=\"k\"}", "[a | b | c | d]{n=\"k\"}",
    "[a]{n=\"k\"}", "[a | b]{if=\"x\"}", "[a]{if=\"x\"}",
    "[a | b]{if=\"x\" .strong}", "[a | b]{n=\"k\" .num digits=\"1\"}",
    "[a]{.strong}", "[a]{.em}",
    "`r trend(claim(foo, . > 0))`",
    "`r x`{.pct digits=1}"
  )
  for (s in ok) {
    expect_equal(errs(s), character(0), label = s)
  }
})

test_that("1.1.5, 5.3.1: more than one governor key in one block is an error", {
  bad <- c(
    "[a | b]{n=\"k\" if=\"x\"}",
    "[a | b]{if=\"x\" n=\"k\"}",
    "[a | b]{N=\"k\" if=\"x\"}",
    "[a | b]{n=\"k\" If=\"x\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.3.3, 5.3.1: a governor key on a value is an error", {
  bad <- c(
    "`r x`{n=\"k\"}", "`r x`{if=\"y\"}", "`{r} x`{.num n=\"k\"}",
    "`r x`{If=\"y\"}", "`r x`{N=\"k\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.2.3, 5.3.1: a single-quoted value is an error that says to bind a name", {
  bad <- c(
    "`r x`{.num digits='2'}",
    "[a | b]{if='x > 0'}",
    "[a | b]{n='k'}"
  )
  for (s in bad) {
    e <- errs(s)
    expect_gte(length(e), 1L, label = s)
    expect_match(e[1], "name|bind", ignore.case = TRUE, label = s)
  }
})

test_that("1.2.3, 5.3.1: a backslash inside a value is an error", {
  bad <- c(
    "[a | b]{if=\"grepl('\\\\d', x)\"}",
    "[a | b]{if=\"x\\y\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.2.9: a \" inside a double-quoted value is the same error", {
  bad <- c(
    "[a | b]{if=\"x == \"a\"\"}",
    "[a | b]{IF=\"x == \"a\"\"}",
    "[a | b]{n=\"length(\"a\")\"}",
    "`r x`{.num if=\"x == \"a\"\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.2.9: braces with no weft key are not that error", {
  expect_equal(errs("`r x`{foo=\"a \"b\"\"}"), character(0))
  expect_equal(errs("[a]{foo=\"a \"b\"\"}"), character(0))
})

test_that("1.2.10, 5.3.1: a key written twice, in any letter case, is an error", {
  bad <- c(
    "[a | b]{if=\"x\" if=\"y\"}",
    "[a | b]{If=\"x\" if=\"y\"}",
    "[a | b]{n=\"k\" N=\"j\"}",
    "`r x`{digits=\"1\" Digits=\"2\"}",
    "`r x`{.num digits=1 digits=2}",
    "`r x`{.and sep=\",\" SEP=\";\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.1.9, 5.3.1: an #id on a text span is an error", {
  for (s in c("[a]{.strong #foo}", "[a]{#foo .em}")) {
    expect_gte(length(errs(s)), 1L, label = s)
  }
})

test_that("5.3.5: an expression that does not parse is an error", {
  bad <- c(
    "`r 1 +`{.num}",
    "`r 1 +`",
    "`{r} f(`",
    "[a | b]{if=\"x >\"}",
    "[a | b]{n=\"((\"}",
    "`r x y`{.num}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("3.1.10, 5.3.1: claim() with no check is an error from the source", {
  bad <- c(
    "`r claim(x)`",
    "`r claim(x)`{.num}",
    "`r trend(claim(foo))`",
    "[a | b]{if=\"claim(x)\"}",
    "[# a | # b]{n=\"claim(depth)\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
  expect_equal(errs("`r claim(x, . > 1)`"), character(0))
  expect_equal(errs("`r claim(x, . > 1, . < 9)`{.num}"), character(0))
})

test_that("1.4.2, 5.3.1: two classes from one at-most-one group are an error", {
  bad <- c(
    "`r x`{.num .pct}", "`r x`{.num .sci}", "`r x`{.pct .sci}",
    "`r x`{.word .count}", "`r x`{.word .ord}", "`r x`{.count .ord}",
    "`r x`{.and .or}", "`r x`{.or .and}",
    "[# a | # b]{n=\"k\" .num .pct}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
  # classes from different groups are fine
  ok <- c("`r x`{.num .word}", "`r x`{.pct .no}", "`r x`{.no .word .and}",
          "`r x`{.num .no .count .or}")
  for (s in ok) expect_equal(errs(s), character(0), label = s)
})

test_that("1.4.7, 5.3.1: digits together with sigfig is an error", {
  bad <- c(
    "`r x`{.num digits=1 sigfig=2}",
    "`r x`{sigfig=2 digits=\"1\"}",
    "[# a | # b]{n=\"k\" digits=1 sigfig=2}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.5.2, 1.6.4, 5.3.1: a wrong arm count for the key is an error", {
  bad <- c(
    "[a | b | c | d | e]{n=\"k\"}",
    "[a | b | c]{if=\"x\"}",
    "[a | b | c | d]{if=\"x\"}",
    "[a | b | c | d | e | f]{n=\"k\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("1.5.7, 5.3.1: a formatter on an if span is an error", {
  bad <- c(
    "[a | b]{if=\"x\" .num}",
    "[a]{if=\"x\" .pct}",
    "[a | b]{.word if=\"x\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
  # a text class on an if span acts on the chosen arm: allowed
  expect_equal(errs("[a | b]{if=\"x\" .strong}"), character(0))
})

test_that("1.5.13, 5.3.1: an unescaped arm separator in a pipe-table cell is an error", {
  tbl <- paste("| name | n |", "|------|---|",
               "| [x | y]{n=\"k\"} | 1 |", sep = "\n")
  expect_gte(length(errs(tbl)), 1L)
  tbl2 <- paste("| name | n |", "|------|---|",
                "| 1 | [x | y]{if=\"z\"} |", sep = "\n")
  expect_gte(length(errs(tbl2)), 1L)
})

test_that("1.7.2, 5.3.1: n=\".\" outside an n span is an error", {
  bad <- c(
    "[a | b]{n=\".\"}",
    "[a [b | c]{n=\".\"} | d]{if=\"x\"}",
    "`r x`{.num n=\".\"}"
  )
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("5.3.4: r followed by a line break is an error, with or without a block", {
  bad <- c("`r\nx`", "`r\nx`{.num}", "Text `r\n x + 1` more.")
  for (s in bad) expect_gte(length(errs(s)), 1L, label = s)
})

test_that("5.3.1: an error row carries the line of its construct", {
  r <- sc("fine\n\nbad `r 1 +`{.num}\n")
  bad <- r[!is.na(r$error), ]
  expect_equal(nrow(bad), 1L)
  expect_equal(bad$line, 3L)
})

# ---- "not built yet" ---------------------------------------------------

# ---- scan_file ---------------------------------------------------------

write_bytes <- function(text, path, bom = FALSE, crlf = FALSE) {
  if (crlf) text <- gsub("\n", "\r\n", text, fixed = TRUE)
  b <- charToRaw(enc2utf8(text))
  if (bom) b <- c(as.raw(c(0xEF, 0xBB, 0xBF)), b)
  writeBin(b, path)
  path
}

test_that("2.10.2: scan_file reads a file and reports file-relative lines", {
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes("# Title\n\nDepth was `r x`{.num} m.\n\n[a | b]{if=\"y\"}\n", p)
  r <- weft:::scan_file(p)
  expect_equal(r$kind, c("value", "if"))
  expect_equal(r$line, c(3L, 5L))
  expect_true(all(r$file == p))
})

test_that("design note: scan_file accepts a BOM", {
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes("`r x`{.num} first.\nsecond `r y`\n", p, bom = TRUE)
  r <- weft:::scan_file(p)
  expect_equal(r$expr, c("x", "y"))
  expect_equal(r$line, c(1L, 2L))
  expect_equal(r$kind, c("value", "bare"))
})

test_that("design note: scan_file accepts CRLF line ends", {
  p <- withr::local_tempfile(fileext = ".Rmd")
  write_bytes("one\ntwo `r x`{.num}\n\n[a |\nb]{if=\"y\"}\nlast `r z`\n", p,
              crlf = TRUE)
  r <- weft:::scan_file(p)
  expect_equal(r$kind, c("value", "if", "bare"))
  expect_equal(r$line, c(2L, 4L, 6L))
  expect_equal(r$arms[[2]], c("a", "b"))
  expect_equal(r$expr, c("x", "y", "z"))
})

test_that("design note: scan_file accepts no final newline", {
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes("line one\nend `r x`{.num}", p)
  r <- weft:::scan_file(p)
  expect_equal(nrow(r), 1L)
  expect_equal(r$line, 2L)
  expect_equal(r$expr, "x")
})

test_that("design note: scan_file skips YAML and chunks, keeping file line numbers", {
  doc <- paste(
    "---",                                  # 1
    "title: \"Shown `r x`{.num}\"",         # 2
    "weft:",                                # 3
    "  digits: 2",                          # 4
    "---",                                  # 5
    "",                                     # 6
    "```{r setup}",                         # 7
    "weft::weft_setup()",                   # 8
    "# `r in_chunk`{.num}",                 # 9
    "```",                                  # 10
    "",                                     # 11
    "Prose `r a`{.num}.",                   # 12
    "",                                     # 13
    "```{r, echo=FALSE}",                   # 14
    "y <- 1",                               # 15
    "```",                                  # 16
    "",                                     # 17
    "```{python}",                          # 18
    "z = `r in_python`",                    # 19
    "```",                                  # 20
    "",                                     # 21
    "```text",                              # 22
    "[a | b]{if=\"ignored\"}",              # 23
    "```",                                  # 24
    "",                                     # 25
    "More [a | b]{n=\"k\"}.",               # 26
    sep = "\n"
  )
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes(doc, p)
  r <- weft:::scan_file(p)
  r <- r[r$context == "prose", ]            # front-matter rows are stage 1c's
  expect_equal(r$expr, c("a", "k"))
  expect_equal(r$line, c(12L, 26L))
  expect_equal(r$kind, c("value", "n"))
})

test_that("design note: a --- later in the body is not YAML", {
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes("Intro `r a`\n\n---\n\nAfter `r b`\n", p)
  r <- weft:::scan_file(p)
  expect_equal(r$expr, c("a", "b"))
  expect_equal(r$line, c(1L, 5L))
})

test_that("design note: scan_file with no construct returns the columns, zero rows", {
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes("no constructs here\n", p)
  r <- weft:::scan_file(p)
  expect_equal(nrow(r), 0L)
  expect_true(all(scan_cols %in% names(r)))
})

test_that("2.10.2: scan_file and scan_text find the same constructs in prose", {
  prose <- "A `r x`{.num} b [c | d]{if=\"y > 0\"} e `r z`.\nSecond [# f | # g]{n=\"k\"}."
  p <- withr::local_tempfile(fileext = ".qmd")
  write_bytes(prose, p)
  a <- weft:::scan_file(p)
  b <- sc(prose)
  for (col in c("kind", "line", "start", "end", "expr", "parent", "arm", "error")) {
    expect_equal(a[[col]], b[[col]], label = col)
  }
  expect_equal(a$arms, b$arms)
  expect_equal(a$classes, b$classes)
})

# ---- mask_text ---------------------------------------------------------

mask <- function(x) weft:::mask_text(x)

test_that("2.10.5: mask_text keeps the length and every line break", {
  texts <- c(
    "Plain prose, nothing to mask.",
    "Mean depth was `r depth`{.num} m.",
    "[a | b]{n=\"k\"} and [c]{if=\"x > 0\"}.",
    "A [first |\nsecond]{if=\"long_condition_name\"} end.\n\nNext `r z`.\n",
    "[results]{.strong} and `r bare_value`.",
    "| a | b |\n|---|---|\n| [x \\| y]{n=\"k\"} | `r q`{.num} |"
  )
  nl <- function(s) as.integer(gregexpr("\n", s, fixed = TRUE)[[1]])
  for (t in texts) {
    m <- mask(t)
    expect_equal(nchar(m), nchar(t), label = t)
    expect_equal(nl(m), nl(t), label = t)
  }
})

test_that("2.10.5: text with no construct is returned unchanged", {
  t <- "Just words, [a link](http://x.org) and `code` and $m$.\n\nMore."
  expect_identical(mask(t), t)
  expect_identical(mask(""), "")
})

test_that("2.10.5: a value's code and attribute block are masked, prose is not", {
  t <- "Mean depth was `r mean_depth + 1`{.num digits=\"2\"} m deep."
  m <- mask(t)
  r <- sc(t)
  expect_false(grepl("mean_depth", m, fixed = TRUE))
  expect_false(grepl(".num", m, fixed = TRUE))
  expect_false(grepl("digits", m, fixed = TRUE))
  expect_equal(substr(m, 1, r$start - 1), substr(t, 1, r$start - 1))
  expect_equal(substr(m, r$end + 1, nchar(m)), substr(t, r$end + 1, nchar(t)))
})

test_that("2.10.5: the block and the expression are one repeated letter, never spaces", {
  t <- "Depth `r mean_depth + 1`{.num digits=\"2\"} m."
  m <- mask(t)
  blk <- regmatches(t, regexpr("\\{[^}]*\\}", t))
  s <- regexpr("{", t, fixed = TRUE)[[1]]
  chars <- strsplit(substr(m, s, s + nchar(blk) - 1), "")[[1]]
  expect_length(unique(chars), 1L)
  expect_match(chars[1], "^[A-Za-z]$")
  e <- regexpr("mean_depth + 1", t, fixed = TRUE)[[1]]
  echars <- strsplit(substr(m, e, e + nchar("mean_depth + 1") - 1), "")[[1]]
  expect_length(unique(echars), 1L)
  expect_match(echars[1], "^[A-Za-z]$")
})

test_that("2.10.5: a span's attribute block is masked; the neighbouring prose is not", {
  t <- "Sampling was [complete | partial]{if=\"n_missing == 0\"} overall."
  m <- mask(t)
  expect_false(grepl("n_missing", m, fixed = TRUE))
  expect_false(grepl("if=", m, fixed = TRUE))
  expect_true(startsWith(m, "Sampling was "))
  expect_true(endsWith(m, " overall."))
  s <- regexpr("{", t, fixed = TRUE)[[1]]
  blk <- strsplit(substr(m, s, nchar(t) - nchar(" overall.")), "")[[1]]
  expect_length(unique(blk), 1L)
  expect_match(blk[1], "^[A-Za-z]$")
})

test_that("2.10.5: a text span's attribute block is masked", {
  m <- mask("See [results]{.strong} here.")
  expect_false(grepl("strong", m, fixed = TRUE))
  expect_true(startsWith(m, "See "))
  expect_true(endsWith(m, " here."))
})

test_that("2.10.5: masking a multi-line construct leaves the line break in place", {
  t <- "A [first part |\nsecond part]{if=\"cond_one, cond_two\"} end."
  m <- mask(t)
  expect_equal(nchar(m), nchar(t))
  expect_equal(regexpr("\n", m, fixed = TRUE)[[1]], regexpr("\n", t, fixed = TRUE)[[1]])
  expect_false(grepl("cond_one", m, fixed = TRUE))
})

test_that("2.10.5: prose between constructs is untouched", {
  t <- "First `r a_value`{.num} middle words [x | y]{n=\"kk\"} last words."
  m <- mask(t)
  expect_true(grepl("middle words", m, fixed = TRUE))
  expect_true(startsWith(m, "First "))
  expect_true(endsWith(m, "last words."))
  expect_false(grepl("a_value", m, fixed = TRUE))
  expect_false(grepl("kk", m, fixed = TRUE))
})
