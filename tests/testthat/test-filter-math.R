# Package P6 of design 9 (dev/design-9.md, phase T2, "named values in math, through the filter": decisions D81
# to D85, rules TL1 to TL8, message E106, and the list under "test-filter-math.R"). Rule 1.4.22 of the design
# reads 1.4.23 (the options of project formatters took 1.4.22). The rule that is built is 2.13.16 of
# dev/PACKAGE-SCOPING.md. Two halves:
#
#   1. the Lua filter, run through plain Pandoc with a hand-written weft-values block (helper-filter.R:
#      filter_md(), filter_cases(), carrier()). The writer is LaTeX, which prints a Math element as \( ... \)
#      (display math as \[ ... \]) and a raw LaTeX element as it is, so the text the filter wrote is what is
#      compared. weft.lua alone is run where a failure is expected to leave a marker in the text (weft-check
#      reports a marker, and its report is not what is under test), both filters where the run must be clean.
#   2. the R scanner's handle_named(): the rows a named value in math or in raw LaTeX gives (the `tex` column
#      of P2), and the errors on them (test-tex-scan.R pinned "no row" for these in P2; see the report).
#
# Tests whose name ends "(control)" pin behaviour that exists today and pass before P6 is built. Every other
# test fails today because the feature is absent (Pandoc keeps the backticks inside the Math text and the
# filter leaves them).
#
# READINGS are marked `# READING:` and listed in the report that came with these tests. ASCII only: non-ASCII
# is written as \u escapes.

MATH_YML <- c("draft: false", "ledger: true")

fm_block <- function(..., run = NULL) {
  carrier(
    depth = fr_float("12.5"), neg = fr_float("-1234567.89"), share = fr_float("0.123"),
    big = fr_float("1234567"), small = fr_float("-0.000123"),
    pv = fr_float("0.03"), p001 = fr_float("0.0001"), p50 = fr_float("0.5"), p995 = fr_float("0.995"),
    p046 = fr_float("0.046"),
    rng = fr_list_float(c("1.23", "3.45")), rneg = fr_list_int(c("-1", "3")), r13 = fr_list_int(c("1", "3")),
    three = fr_int("3"), negthree = fr_int("-3"), zero = fr_int("0"),
    fe = fr_float("1e+23"), fv = fr_float("3.14159"), fneg = fr_float("-1.5"), i42 = fr_int("42"),
    d250 = fr_dec("2.50"), s1 = fr_str("north"), dt = fr_date("2026-11-13"), b1 = fr_bool(TRUE),
    l123 = fr_list_int(c("1", "2", "3")), miss = fr_missing("no rows matched"),
    ...
  )
}

# one paragraph per case through weft.lua and weft-check.lua, LaTeX writer. Returns the filter_cases() result.
fm_cases <- function(cases, draft = FALSE, filters = c("weft.lua", "weft-check.lua"), ...) {
  filter_cases(cases, list(fm_block()), draft = draft, to = "latex", filters = filters, ...)
}

# "A \(TEXT\) z." for a case written "A $SRC$ z."
fm_in <- function(src) paste0("A $", src, "$ z.")
fm_out <- function(text) paste0("A \\(", text, "\\) z.")

# the messages of rule 5.2.6 (TX2) that the filter repeats in identical text; PLACE is "math" or "raw LaTeX"
fm_e95 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it prints words, and a formula holds numbers. ",
  "Move the value out of the %s, or use a number class such as `.num` (rule 5.2.6)."), x, place, place)
fm_e96 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it is markdown emphasis, and %s is TeX. ",
  "Put \\mathbf{} or \\mathit{} around the value in the formula (rule 5.2.6)."), x, place, place)
fm_e97 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it joins items into a phrase or a list. ",
  "Use `.range` for two ends, or move the value out of the %s (rule 5.2.6)."), x, place, place)
fm_e99 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it is not weft's, so weft would put the value in a ",
  "Pandoc span, and %s has none. Drop it, or move the value out of the %s (rule 5.2.6)."), x, place, place, place)

# ---- TL1, TL2, TL4, D81: a named value in math is written as TeX -----------------------------------------------

test_that("TL4, TX5, D81: each class design 9 allows on a named value, in inline math, writes the TeX of TX5", {
  tbl <- list(
    num = c("`depth`{.num}", "12.5"),
    num_neg_thousands = c("`neg`{.num}", "-1{,}234{,}567.9"),
    num_digits = c("`depth`{.num digits=\"2\"}", "12.50"),
    num_sigfig = c("`neg`{.num sigfig=\"3\"}", "-1{,}230{,}000"),
    num_plus = c("`three`{.num .plus}", "+3"),
    num_plus_neg = c("`negthree`{.num .plus}", "-3"),
    num_plus_zero = c("`zero`{.num .plus}", "0"),
    pct = c("`share`{.pct}", "12.3\\%"),
    pct_plus = c("`share`{.pct .plus}", "+12.3\\%"),
    sci = c("`big`{.sci}", "1.2 \\times 10^{6}"),
    sci_neg = c("`small`{.sci}", "-1.2 \\times 10^{-4}"),
    p_low = c("`p001`{.p}", "p < 0.001"), p_mid = c("`pv`{.p}", "p = 0.030"), p_half = c("`p50`{.p}", "p = 0.50"),
    p_high = c("`p995`{.p}", "p > 0.99"),
    p_label_empty = c("`p50`{.p label=\"\"}", "0.50"), p_label_empty_high = c("`p995`{.p label=\"\"}", "> 0.99"),
    p_label_tex = c("`p046`{.p label=\"\\tilde{p}\"}", "\\tilde{p} = 0.046"),
    range = c("`rng`{.range}", "1.2\\ \\text{to}\\ 3.5"),
    range_neg = c("`rneg`{.range}", "-1\\ \\text{to}\\ 3"),
    range_plus = c("`r13`{.range .plus}", "+1\\ \\text{to}\\ +3"),
    id_and_class = c("`depth`{#d1 .num}", "12.5")
  )
  x <- tbl_cases(tbl, pre = "A $a = ", post = "$ z.")
  x$expected <- vapply(tbl, function(r) paste0("A \\(a = ", r[[2]], "\\) z."), "")
  res <- fm_cases(x$cases)
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
})

# READING: the design's example $p = `p_val`{.p}$ would print "p = p = ...", since `.p` writes its own label
# (TX5); the tests use the value alone in the formula.
test_that("TL4, D81: the design's example, a p value written in math, gives the label and the value", {
  res <- fm_cases(c(a = fm_in("`pv`{.p}")))
  expect_cases(res, c(a = fm_out("p = 0.030")))
})

test_that("TL4: .val prints a number whose text is plain digits as it is, and anything else through tex_text()", {
  tbl <- list(
    float = c("`fv`{.val}", "3.14159"), float_neg = c("`fneg`{.val}", "-1.5"), int = c("`i42`{.val}", "42"),
    decimal_as_written = c("`d250`{.val}", "2.50"),
    exponent = c("`fe`{.val}", "\\text{1e+23}"),
    string = c("`s1`{.val}", "\\text{north}"),
    date = c("`dt`{.val}", "\\text{2026-11-13}"),
    bool = c("`b1`{.val}", "\\text{true}"),
    list_ = c("`l123`{.val}", "\\text{1, 2, 3}")
  )
  # READING: a list, a bool and a date are "anything else": the text of their record (as the markdown route
  # prints it: "1, 2, 3", "true", "2026-11-13") goes through tex_text().
  x <- tbl_cases(tbl)
  x$expected <- vapply(tbl, function(r) fm_out(r[[2]]), "")
  x$cases <- vapply(tbl, function(r) fm_in(r[[1]]), "")
  res <- fm_cases(x$cases)
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
})

test_that("TL1, TL4: a construct written with a run of two backticks is found, and several in one formula are each replaced", {
  res <- fm_cases(c(
    two = "A $a = ``depth``{.num}$ z.",
    several = "A $`depth`{.num} + `neg`{.num} \\times `share`{.pct}$ z.",
    adjacent = "A $`depth`{.num}`three`{.num}$ z.",
    in_frac = "A $\\frac{`depth`{.num}}{`three`{.num}}$ z."))
  expect_identical(res$status, 0L)
  expect_cases(res, c(
    two = fm_out("a = 12.5"),
    several = fm_out("12.5 + -1{,}234{,}567.9 \\times 12.3\\%"),
    adjacent = fm_out("12.53"),
    in_frac = fm_out("\\frac{12.5}{3}")))
})

test_that("TL1, D81: display math, the output of the Math element is the formula with the construct replaced", {
  md <- c(fm_block(), "", "Before.", "", "$$", "a = 1", "+ `depth`{.num}", "$$", "", "After.")
  res <- filter_md(md, to = "latex")
  expect_identical(res$status, 0L)
  expect_match(res$output, "\\[\na = 1\n+ 12.5\n\\]", fixed = TRUE)
  expect_false(grepl("`", res$output, fixed = TRUE))
})

test_that("TL1, D76, D84: a math environment (Pandoc gives a RawInline or RawBlock of format tex) is math: no \\ensuremath", {
  md <- c(fm_block(), "", "\\begin{align}", "a &= `depth`{.num} \\\\", "b &= `share`{.pct}", "\\end{align}")
  res <- filter_md(md, to = "latex")
  expect_identical(res$status, 0L)
  expect_match(res$output, "\\begin{align}\na &= 12.5 \\\\\nb &= 12.3\\%\n\\end{align}", fixed = TRUE)
  expect_false(grepl("ensuremath", res$output, fixed = TRUE))
})

test_that("TL1, TL4, D84: a {=latex} block and a raw inline span write the TeX inside \\ensuremath{}", {
  md <- c(fm_block(), "", "```{=latex}", "\\textbf{`depth`{.num}} and `share`{.pct}", "```", "",
          "Inline ``\\textbf{`neg`{.num}}``{=latex} here.")
  res <- filter_md(md, to = "latex")
  expect_identical(res$status, 0L)
  expect_match(res$output, "\\textbf{\\ensuremath{12.5}} and \\ensuremath{12.3\\%}", fixed = TRUE)
  expect_match(res$output, "Inline \\textbf{\\ensuremath{-1{,}234{,}567.9}} here.", fixed = TRUE)
  expect_false(grepl("`", res$output, fixed = TRUE))
})

test_that("TL1, D84: a raw environment that is not a math environment (tabular) is raw TeX: \\ensuremath{}", {
  md <- c(fm_block(), "", "\\begin{tabular}{l}", "`depth`{.num} \\\\", "`p001`{.p}", "\\end{tabular}")
  res <- filter_md(md, to = "latex")
  expect_identical(res$status, 0L)
  expect_match(res$output, "\\begin{tabular}{l}\n\\ensuremath{12.5} \\\\\n\\ensuremath{p < 0.001}\n\\end{tabular}", fixed = TRUE)
})

test_that("TL1: a named value inside a raw element of another format ({=html}) is left alone (control)", {
  md <- c(fm_block(), "", "```{=html}", "<b>`depth`{.num}</b>", "```", "", "Inline ``<i>`depth`{.num}</i>``{=html} here.")
  res <- filter_md(md, to = "html")
  expect_identical(res$status, 0L)
  expect_match(res$output, "<b>`depth`{.num}</b>", fixed = TRUE)
  expect_match(res$output, "<i>`depth`{.num}</i>", fixed = TRUE)
})

test_that("TL1: Math in every kind of container is found (heading, list, quote, table cell, emphasis, link, note)", {
  md <- c(fm_block(), "",
          "# Depth $`depth`{.num}$", "",
          "- item $`neg`{.num}$", "",
          "> quote $`share`{.pct}$", "",
          "| h |", "|---|", "| $`three`{.num}$ |", "",
          "*emph $`big`{.sci}$* and [link $`pv`{.p}$](https://example.org) and note.[^1]", "",
          "[^1]: In the note $`small`{.sci}$.")
  res <- filter_md(md, to = "latex")
  expect_identical(res$status, 0L)
  for (tex in c("12.5", "-1{,}234{,}567.9", "12.3\\%", "3", "1.2 \\times 10^{6}", "p = 0.030", "-1.2 \\times 10^{-4}")) {
    expect_true(grepl(paste0("\\(", tex, "\\)"), res$output, fixed = TRUE), label = tex)
  }
  expect_false(grepl("`", res$output, fixed = TRUE))
})

test_that("TL1, TL4, tex.tsv: named values in math print what the TeX conformance set says, row by row", {
  p <- test_path("_conformance", "tex.tsv")
  skip_if_not(file.exists(p), "tex.tsv is missing")
  ls <- readLines(p, encoding = "UTF-8", warn = FALSE)[-1]
  f <- strsplit(ls, "\t", fixed = TRUE)
  f <- Filter(function(r) length(r) == 5L, f)
  keep <- vapply(f, function(r) {
    toks <- strsplit(r[[3]], " ", fixed = TRUE)[[1]]
    all(grepl("^(target=tex|digits=[0-9]+|sigfig=[0-9]+|label=.*)$", toks))
  }, NA)
  f <- f[keep]
  f <- f[seq(1L, length(f), by = 4L)]
  expect_gt(length(f), 100L)
  names_ <- sprintf("t%d", seq_along(f))
  recs <- stats::setNames(vapply(f, function(r) r[[5]], ""), names_)
  blk <- do.call(carrier, as.list(recs))
  attr_of <- function(keys) {
    toks <- setdiff(strsplit(keys, " ", fixed = TRUE)[[1]], "target=tex")
    vapply(toks, function(t) {
      kv <- strsplit(t, "=", fixed = TRUE)[[1]]
      sprintf("%s=\"%s\"", kv[[1]], paste(kv[-1], collapse = "="))
    }, "")
  }
  cases <- vapply(seq_along(f), function(i) {
    cls <- paste0(".", strsplit(f[[i]][[2]], " ", fixed = TRUE)[[1]], collapse = " ")
    sprintf("A $`%s`{%s}$ z.", names_[[i]], paste(c(cls, attr_of(f[[i]][[3]])), collapse = " "))
  }, "")
  names(cases) <- names_
  res <- filter_cases(cases, list(blk), to = "latex")
  expect_identical(res$status, 0L)
  expected <- stats::setNames(vapply(f, function(r) fm_out(r[[4]]), ""), names_)
  for (nm in names_) expect_identical(unname(res$got[nm]), unname(expected[nm]), label = nm)
})

# ---- TL2: what is not a construct is left byte for byte -------------------------------------------------------

test_that("TL2 (control): a backtick run in math that is ordinary TeX, a \\texttt with braces, an escaped backtick are left as written", {
  srcs <- c(
    quotes = "f = ``a'' + x",
    texttt = "\\texttt{`x`} + y",
    texttt_braced = "\\texttt{`x`}{y}",
    not_a_block = "a `x`{b} c",
    escaped_open = "a \\`x`{.num} c",
    unclosed = "a `depth{.num} c",
    mismatch = "a ``depth`{.num} c",
    other_class = "a `depth`{.python} c",
    id_only = "a `depth`{#d} c",
    block_not_direct = "a `depth` {.num} c",
    no_block = "a `depth` c",
    block_never_closes = "a `depth`{.num c")
  # the same document with and without the filter
  doc <- unname(vapply(srcs, function(s) paste0("A $", s, "$ z.\n"), ""))
  with <- filter_md(doc, to = "latex", env = c(WEFT_DRAFT = "1"))
  without <- filter_md(doc, to = "latex", filters = character())
  expect_identical(with$status, 0L)
  expect_identical(with$output, without$output)
  for (s in srcs) expect_true(grepl(s, with$output, fixed = TRUE), label = s)
})

test_that("TL2, TL4: a backtick candidate with a weft class whose text is not a name is a construct error, as in prose", {
  # READING: the snippet passes code_candidate() (a weft class), so it is a construct; as in prose, a text that
  # is not a name is E1 (rule 1.12.3), written as a construct-error marker in the string.
  res <- fm_cases(c(a = "A $x = `a b`{.num}$ z."), draft = TRUE)
  expect_cases(res, c(a = fm_out("x = \\text{<<weft: construct error, line {L}>>}")))
  expect_true(grepl(fm_msg$E1("a b"), res$stderr, fixed = TRUE))
})

test_that("TL2, TL4: the text around a construct, other backticks included, is untouched", {
  res <- fm_cases(c(a = "A $``q'' + `depth`{.num} + \\texttt{`z`}$ z."))
  expect_cases(res, c(a = fm_out("``q'' + 12.5 + \\texttt{`z`}")))
})

test_that("TL2, D81 (control): math with no backticks at all is untouched: the AST is identical with and without the filter", {
  md <- c(fm_block(), "", "Prose $a + b = c$ and `depth`.", "", "$$\\frac{a}{b}$$", "",
          "\\begin{align}", "a &= b", "\\end{align}", "", "```{=latex}", "\\textbf{x}", "```", "",
          "Inline ``\\emph{x}``{=latex} and $\\texttt{x}$ end.")
  with <- filter_md(md[-(1:4)], to = "native")
  without <- filter_md(md[-(1:4)], to = "native", filters = character())
  expect_identical(with$status, 0L)
  expect_identical(with$output, without$output)
  with2 <- filter_md(md[-(1:4)], to = "native", filters = "weft.lua")
  expect_identical(with2$output, without$output)
})

# ---- the same value outside math (two-sided) -------------------------------------------------------------------

test_that("TL4 (control): the same named values outside math print as markdown, as today", {
  # the prose forms are what the markdown route prints today: minus U+2212, a comma for thousands
  res <- fm_cases(c(a = "A `neg`{.num} z.", b = "A `share`{.pct} z."))
  expect_identical(res$status, 0L)
  expect_cases(res, c(a = "A \u22121,234,567.9 z.", b = "A 12.3\\% z."))
})

test_that("TL4: one document with the same value in prose and in math: markdown in the prose, TeX in the math", {
  res <- fm_cases(c(a = "A `neg`{.num} and $x = `neg`{.num}$ z.", b = "A `share`{.pct} and $`share`{.pct}$ z."))
  expect_identical(res$status, 0L)
  expect_cases(res, c(a = "A \u22121,234,567.9 and \\(x = -1{,}234{,}567.9\\) z.",
                      b = "A 12.3\\% and \\(12.3\\%\\) z."))
})

# ---- TL3: the checks, E95 to E99, and unit= --------------------------------------------------------------------

test_that("TL3, E95: a class that prints words, in math, is a construct error with the scanner's text and a marker in the string", {
  cases <- c(word = fm_in("`three`{.word}"), count = fm_in("`three`{.count}"), ord = fm_in("`three`{.ord}"),
             no = fm_in("`three`{.no}"), date = fm_in("`dt`{.date}"), a = fm_in("`three`{.a}"), cap = fm_in("`three`{.cap}"))
  res <- fm_cases(cases, draft = TRUE)
  expect_identical(res$status, 0L)
  want <- stats::setNames(rep(fm_out("\\text{<<weft: construct error, line {L}>>}"), length(cases)), names(cases))
  expect_cases(res, want)
  for (cl in c("word", "count", "ord", "no", "date", "a", "cap")) {
    expect_true(grepl(fm_e95(paste0(".", cl), "math"), res$stderr, fixed = TRUE), label = cl)
  }
})

test_that("TL3, E96, E97, E99: emphasis, a phrase or list class, a key that joins items, and a class that is not weft's", {
  cases <- c(em = fm_in("`depth`{.em}"), strong = fm_in("`depth`{.strong}"), and = fm_in("`l123`{.and}"),
             or = fm_in("`l123`{.or}"), ul = fm_in("`l123`{.ul}"), sep = fm_in("`l123`{.num sep=\"-\"}"),
             py = fm_in("`depth`{.num .python}"), keyx = fm_in("`depth`{.num colour=\"red\"}"))
  res <- fm_cases(cases, draft = TRUE)
  want <- stats::setNames(rep(fm_out("\\text{<<weft: construct error, line {L}>>}"), length(cases)), names(cases))
  expect_cases(res, want)
  expect_true(grepl(fm_e96(".em", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e96(".strong", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e97(".and", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e97(".or", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e97(".ul", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e97("sep", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e99(".python", "math"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e99("colour", "math"), res$stderr, fixed = TRUE))
})

test_that("TL3: in raw LaTeX the place is `raw LaTeX`, and the marker is inside \\ensuremath{}", {
  md <- c(fm_block(), "", "```{=latex}", "\\textbf{`three`{.word}} \\emph{`depth`{.em}} `l123`{.and}", "```")
  res <- filter_md(md, to = "latex", env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  expect_true(grepl(fm_e95(".word", "raw LaTeX"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e96(".em", "raw LaTeX"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_e97(".and", "raw LaTeX"), res$stderr, fixed = TRUE))
  expect_match(res$output, "\\textbf{\\ensuremath{\\text{<<weft: construct error, line 6>>}}}", fixed = TRUE)
})

test_that("TL3: .val is allowed in math, and a key the scanner allows (why, label, digits, sigfig) is no error", {
  res <- fm_cases(c(a = fm_in("`fv`{.val}"), b = fm_in("`depth`{.num why=\"given\"}"),
                    c = fm_in("`depth`{.num sigfig=\"3\"}")))
  expect_identical(res$status, 0L)
  expect_false(grepl("cannot be used inside", res$stderr, fixed = TRUE))
  expect_cases(res, c(a = fm_out("3.14159"), b = fm_out("12.5"), c = fm_out("12.5")))
})

test_that("TL4, 2.13.3: unit= (and the unit classes) on a named value in math are the value error they are outside math", {
  cases <- c(unit = fm_in("`depth`{.num unit=\"m\"}"), uname = fm_in("`depth`{.num .uname}"),
             usym = fm_in("`depth`{.num .usym}"), nounit = fm_in("`depth`{.num .nounit}"))
  res <- fm_cases(cases, draft = TRUE)
  # READING: the unit classes, which TX2 lets through the scanner, are refused by the filter as they are in
  # prose (E20, "for good" in design 6): a value error marker, not a construct error.
  want <- stats::setNames(rep(fm_out("\\text{<<weft: value error, line {L}>>}"), length(cases)), names(cases))
  expect_cases(res, want)
  expect_true(grepl(fm_msg$E20_key("unit"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E20_class("uname"), res$stderr, fixed = TRUE))
})

test_that("TL3, 1.4.3: a class that needs a number, on a string, is a value error marker in math (E17)", {
  res <- fm_cases(c(a = fm_in("`s1`{.num}")), draft = TRUE)
  expect_cases(res, c(a = fm_out("\\text{<<weft: value error, line {L}>>}")))
  expect_true(grepl(fm_msg$E17("num", "number", "s1", "string"), res$stderr, fixed = TRUE))
})

# ---- TL4, D83: failures are markers inside the string ---------------------------------------------------------

test_that("D83, TX9: an unknown name gives \\text{<<weft: no value, line N>>} inside the formula, which is not split", {
  res <- fm_cases(c(a = fm_in("\\frac{`gone`{.num}}{`three`{.num}}")), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(a = fm_out("\\frac{\\text{<<weft: no value, line {L}>>}}{3}")))
  expect_true(grepl(fm_msg$E10("gone"), res$stderr, fixed = TRUE))
})

test_that("D83, TX9: a missing record is the marker too, and the other construct in the same formula still resolves", {
  res <- fm_cases(c(a = fm_in("`miss`{.num} + `depth`{.num}")), draft = TRUE)
  expect_cases(res, c(a = fm_out("\\text{<<weft: no value, line {L}>>} + 12.5")))
  expect_true(grepl(fm_msg$E11("miss", "no rows matched"), res$stderr, fixed = TRUE))
})

test_that("D83: in raw LaTeX the marker is inside \\ensuremath{} too", {
  md <- c(fm_block(), "", "```{=latex}", "\\textbf{`gone`{.num}}", "```")
  res <- filter_md(md, to = "latex", env = c(WEFT_DRAFT = "1"), filters = "weft.lua")
  expect_match(res$output, "\\textbf{\\ensuremath{\\text{<<weft: no value, line 6>>}}}", fixed = TRUE)
})

test_that("D82, TL5: the failure is collected with the line of the candidate, also in display math over several lines", {
  md <- c(fm_block(), "", "Prose $`gone`{.num}$ here.", "", "$$", "a = 1", "+ `gone2`{.num}", "$$")
  res <- filter_md(md, to = "latex", collect = TRUE, filters = "weft.lua")
  expect_identical(res$status, 0L)
  recs <- lapply(res$collected, jsonlite::fromJSON)
  expect_length(recs, 2L)
  by_expr <- vapply(recs, function(r) paste(r$kind, r$line), "")
  # READING: the line is that of the candidate itself (D82's `weft-at="i:l"` is one entry per candidate), so
  # for display math over several lines it is the line holding the backticks.
  expect_setequal(by_expr, c("no value 5", "no value 9"))
  expect_true(all(vapply(recs, function(r) identical(r$source, "resolve"), NA)))
  expect_true(any(vapply(recs, function(r) grepl(fm_msg$E10("gone2"), r$detail, fixed = TRUE), NA)))
})

test_that("D83: a failure in math in a document that is not a draft fails the run and reports the line, as in prose", {
  md <- c(fm_block(), "", "Prose.", "", "A $`gone`{.num}$ z.")
  res <- filter_md(md, to = "latex", filters = "weft.lua")
  expect_identical(res$status, 1L)
  expect_match(fm_headings(res$stderr), rx_failures(1), all = FALSE)
  expect_match(res$stderr, "doc\\.md:7  \\[no value\\]")
})

test_that("TL4, 1.12.7: a forward reference, the formula above the block that publishes the name, takes the value", {
  md <- c("Above $x = `late`{.num}$ and `late`{.num}.", "", carrier(late = fr_float("7.5")), "",
          "Below $y = `late`{.num}$.")
  res <- filter_md(md, to = "latex")
  expect_identical(res$status, 0L)
  expect_match(res$output, "Above \\(x = 7.5\\) and 7.5.", fixed = TRUE)
  expect_match(res$output, "Below \\(y = 7.5\\).", fixed = TRUE)
})

test_that("TL5, 1.12.7: above two blocks that differ, a name in math is no value, as in prose", {
  md <- c("Above $x = `late`{.num}$.", "", carrier(late = fr_float("7.5")), "", "Mid.", "", carrier(late = fr_float("8.5")))
  res <- filter_md(md, to = "latex", env = c(WEFT_DRAFT = "1"))
  expect_match(res$output, "Above \\(x = \\text{<<weft: no value, line 1>>}\\).", fixed = TRUE)
})

# ---- TL5: the ledger and the stamp ----------------------------------------------------------------------------

test_that("TL5, TX10: a named value in math has a ledger entry: kind value, the name, context math, printed the TeX", {
  md <- c(fm_block(run = NULL), "", "## Data", "",
          "Prose `neg`{.num} and $x = `neg`{.num}$ and `depth`{.num}.", "",
          "$$ y = `share`{.pct} $$")
  res <- filter_md(md, weft_yml = MATH_YML, env = c(WEFT_RUN = "R1"), to = "latex")
  expect_identical(res$status, 0L)
  es <- g6_entries(res)
  expect_setequal(g6_keys(es), c("value|neg|1", "value|neg|2", "value|depth|1", "value|share|1"))
  prose <- g6_pick(es, "value", "neg", 1)
  expect_identical(prose$context, "prose")
  expect_identical(prose$text, "\u22121,234,567.9")
  inmath <- g6_pick(es, "value", "neg", 2)
  expect_identical(inmath$context, "math")
  expect_identical(inmath$text, "-1{,}234{,}567.9")
  expect_identical(inmath$writer, "filter")
  expect_identical(inmath$file, "doc.md")
  expect_identical(inmath$section, "data")
  disp <- g6_pick(es, "value", "share", 1)
  expect_identical(disp$context, "math")
  expect_identical(disp$text, "12.3\\%")
})

test_that("TL5, TX10: in raw LaTeX the context is tex and the text holds the \\ensuremath{} wrapper", {
  md <- c(fm_block(), "", "```{=latex}", "\\textbf{`depth`{.num}}", "```")
  res <- filter_md(md, weft_yml = MATH_YML, env = c(WEFT_RUN = "R1"), to = "latex")
  es <- g6_entries(res)
  e <- g6_pick(es, "value", "depth", 1)
  expect_identical(e$context, "tex")
  # READING: TX10 says the text is "exactly what weft wrote, wrapper included"; TL5 says `printed` the TeX.
  # The wrapper is taken to be part of it.
  expect_identical(e$text, "\\ensuremath{12.5}")
})

test_that("TL5: a failure in math is recorded as a failed entry, as in prose", {
  md <- c(fm_block(), "", "A $`gone`{.num}$ z.")
  res <- filter_md(md, weft_yml = MATH_YML, env = c(WEFT_RUN = "R1", WEFT_DRAFT = "1"), to = "latex")
  es <- g6_entries(res)
  e <- g6_pick(es, "value", "gone", 1)
  expect_identical(e$context, "math")
  expect_null(e$text)
})

test_that("TL5: the stamp counts a name used in math in its `named` total", {
  md <- c(g6_block(depth = fr_float("12.5"), n = fr_int("4"), run = "R1", at = 1794822900L), "",
          "Depth `depth`{.num} m and `n`{.num} sites and $x = `depth`{.num}$.")
  res <- filter_md(md, weft_yml = "serial_comma: true", env = c(WEFT_RUN = "R1"), to = "latex")
  expect_identical(res$status, 0L)
  # READING: `named` is the count of named values resolved (2 for the prose pair in test-filter-stamp.R), so a
  # use in math is one more.
  expect_identical(g6_stamp(res)$named, 3L)
})

# ---- TL6: weft-check.lua, E106 ---------------------------------------------------------------------------------

E106_TEXT <- "math holds a named value the filter did not resolve"

test_that("TL6, E106: weft-check alone, a named value left in Math is a leftover code finding with the E106 text and the excerpt", {
  res <- filter_md("A $x = `depth`{.num}$ z.", filters = "weft-check.lua", to = "latex")
  expect_identical(res$status, 1L)
  expect_match(res$stderr, "weft-check: 1 leftover weft construct", fixed = TRUE)
  expect_true(grepl(E106_TEXT, res$stderr, fixed = TRUE))
  expect_match(res$stderr, "`depth`\\{\\.num\\}")
  # not the prose message E35
  expect_false(grepl(fm_msg$E35, res$stderr, fixed = TRUE))
})

test_that("TL6, E106: display math, a math environment, a raw inline and a raw block with a named value are each reported", {
  srcs <- list(
    display = "$$ x = `depth`{.num} $$",
    env = c("\\begin{align}", "a &= `depth`{.num}", "\\end{align}"),
    block = c("```{=latex}", "\\textbf{`depth`{.num}}", "```"),
    inline = "Inline ``\\textbf{`depth`{.num}}``{=latex} here.",
    tabular = c("\\begin{tabular}{l}", "`depth`{.num}", "\\end{tabular}"),
    val = "$x = `depth`{.val}$",
    key_only = "$x = `depth`{digits=\"2\"}$")
  for (nm in names(srcs)) {
    res <- filter_md(srcs[[nm]], filters = "weft-check.lua", to = "latex")
    expect_identical(res$status, 1L, label = nm)
    # READING: the detail is the same text for raw TeX as for math (TL6 gives one text for "a Math or raw-TeX text")
    expect_true(grepl(E106_TEXT, res$stderr, fixed = TRUE), label = nm)
  }
})

test_that("TL6, E106: with WEFT_DRAFT the finding is reported and the run does not fail", {
  res <- filter_md("A $x = `depth`{.num}$ z.", filters = "weft-check.lua", to = "latex", env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  expect_true(grepl(E106_TEXT, res$stderr, fixed = TRUE))
})

test_that("TL6: math with text that is not a named value is no finding (control)", {
  for (src in c("A $f = ``a'' + x$ z.", "A $\\texttt{`x`}$ z.", "A $`x`{.python}$ z.", "A $`x`{#d}$ z.",
                "A $`x`$ z.", "A $a + b$ z.")) {
    res <- filter_md(src, filters = "weft-check.lua", to = "latex")
    expect_identical(res$status, 0L, label = src)
    expect_false(grepl("weft-check", res$stderr, fixed = TRUE), label = src)
  }
})

test_that("TL6: after weft.lua the named values in math are gone, so weft-check is silent and the run succeeds", {
  res <- fm_cases(c(a = fm_in("`depth`{.num} + `share`{.pct}")))
  expect_identical(res$status, 0L)
  expect_false(grepl("weft-check", res$stderr, fixed = TRUE))
  expect_cases(res, c(a = fm_out("12.5 + 12.3\\%")))
})

# ---- the scanner (R): handle_named() in math and raw LaTeX ----------------------------------------------------

mt_sc <- function(x, ...) weft:::scan_text(paste(x, collapse = "\n"), ...)
mt_env <- function(name, body) paste0("\\begin{", name, "}\n", body, "\n\\end{", name, "}")
MT_CFG <- list(formatters = list(
  .mine  = list(`function` = "my_fmt",  stage = "number", options = character(), targets = c("markdown", "tex")),
  .plain = list(`function` = "my_fmt2", stage = "number", options = character())))

test_that("TL3, handle_named: a named value in `$` math, `$$` math or a math environment is a named row with tex `math`", {
  srcs <- list(inline = "Here $x = `depth`{.num}$ only.", display = "$$ x = `depth`{.num} $$",
               align = mt_env("align", "x &= `depth`{.num}"), eq = mt_env("equation*", "x = `depth`{.pct}"))
  for (nm in names(srcs)) {
    r <- mt_sc(srcs[[nm]])
    expect_identical(r$kind, "named", label = nm)
    expect_identical(r$expr, "depth", label = nm)
    expect_identical(r$tex, "math", label = nm)
    expect_true(is.na(r$error), label = nm)
  }
})

test_that("TL3, handle_named: in raw LaTeX (an other environment, a {=latex} fence, a raw span) the named row has tex `raw`", {
  srcs <- list(tabular = mt_env("tabular", "`depth`{.num}"),
               fence = c("```{=latex}", "\\textbf{`depth`{.num}}", "```"),
               tex_fence = c("```{=tex}", "\\textbf{`depth`{.num}}", "```"),
               span = "A ``\\textbf{`depth`{.num}}``{=latex} here.")
  for (nm in names(srcs)) {
    r <- mt_sc(srcs[[nm]])
    named <- r[r$kind == "named", , drop = FALSE]
    expect_identical(nrow(named), 1L, label = nm)
    expect_identical(named$tex, "raw", label = nm)
  }
})

test_that("TL3, handle_named: the row has the line, the classes and the keys of the construct", {
  r <- mt_sc(c("Line one.", "", "Here $x = `depth`{.num .plus digits=\"2\"}$ and", "$$ y = `p`{.p} $$"))
  r <- r[r$kind == "named", , drop = FALSE]
  expect_identical(r$expr, c("depth", "p"))
  expect_identical(r$line, c(3L, 4L))
  expect_identical(r$tex, c("math", "math"))
  expect_identical(r$classes[1], list(c(".num", ".plus")))
  expect_identical(unname(r$keys[1]), list(c(digits = "2")))
})

test_that("TL3, handle_named: several named values in one formula are several rows, in order; one beside the formula keeps tex empty", {
  r <- mt_sc("A `a`{.num} and $`b`{.num} + `c`{.pct}$ and `d`{.num}.")
  expect_identical(r$expr, c("a", "b", "c", "d"))
  expect_identical(r$tex, c("", "math", "math", ""))
})

test_that("TL3, E95: a class with no TeX form on a named value in math is the scanner's error, text identical to the filter's", {
  for (cl in c(".word", ".count", ".ord", ".no", ".date", ".a", ".cap")) {
    r <- mt_sc(sprintf("Here $x = `depth`{%s}$ only.", cl))
    expect_identical(r$error, fm_e95(cl, "math"), label = cl)
  }
  r <- mt_sc(mt_env("tabular", "`depth`{.word}"))
  expect_identical(r$error[r$kind == "named"], fm_e95(".word", "raw LaTeX"))
})

test_that("TL3, E96, E97, E99, E98: emphasis, a phrase class, a foreign class, a project formatter that lacks tex", {
  r <- mt_sc("Here $`d`{.strong}$ and $`d`{.em}$.")
  expect_identical(r$error, c(fm_e96(".strong", "math"), fm_e96(".em", "math")))
  r <- mt_sc("Here $`d`{.and}$ and $`d`{.num sep=\"-\"}$.")
  expect_identical(r$error, c(fm_e97(".and", "math"), fm_e97("sep", "math")))
  r <- mt_sc("Here $`d`{.num .python}$.")
  expect_identical(r$error, fm_e99(".python", "math"))
  r <- mt_sc("Here $`d`{.plain}$ and $`d`{.mine}$.", config = MT_CFG)
  e98 <- sprintf(paste0("The project formatter `%s` cannot be used inside %s: its entry under `formatters:` ",
                        "in _weft.yml does not list `tex` in `targets:` (rule 5.2.6)."), ".plain", "math")
  # READING: a registered project class is E98 when its entry lacks tex in targets (as for inline R); the scanner
  # (not the filter) is the one that reads the registry, so only the scanner is tested for E98.
  expect_identical(r$error[1], e98)
  expect_true(is.na(r$error[2]))
})

test_that("TL3: .val is allowed on a named value in math, and the keys of TX2 are no error", {
  for (src in c("$`d`{.val}$", "$`d`{.num digits=\"2\" why=\"given\"}$", "$`d`{.num sigfig=\"3\"}$", "$`d`{.p label=\"q\"}$", "$`d`{.num unit=\"m\"}$",
                "$`d`{#id1 .num .plus}$", "$`d`{.range}$", "$`d`{.sci}$")) {
    r <- mt_sc(paste("Here", src, "only."))
    expect_true(is.na(r$error), label = src)
    expect_identical(r$tex, "math", label = src)
  }
})

test_that("TL3, 1.12.3: the other checks of a named value apply in math: a text that is not a name is E1", {
  r <- mt_sc("Here $x = `a b`{.num}$ only.")
  expect_identical(r$error, fm_msg$E1("a b"))
  expect_identical(r$tex, "math")
})

test_that("TL3: a candidate that is not a construct in math gives no row (control)", {
  for (src in c("$f = ``a'' + x$", "$\\texttt{`x`}$", "$`x`{.python}$ ", "$`x`$", "$`x`{#d}$")) {
    r <- mt_sc(paste("Here", src, "only."))
    expect_identical(nrow(r[r$kind == "named", , drop = FALSE]), 0L, label = src)
  }
})

test_that("TL3: a {=typst} fence keeps today's behaviour: no named row (control)", {
  r <- mt_sc(c("```{=typst}", "#x `depth`{.num}", "```"))
  expect_identical(nrow(r), 0L)
})

test_that("TL3, resolver: a named value in math in an .Rmd is a row the filter resolves (the hooks leave its source, N14)", {
  path <- tempfile("mt-", fileext = ".Rmd")
  writeLines(c("Here $x = `depth`{.num}$ only."), path)
  withr::defer(unlink(path))
  r <- weft:::scan_file(path)
  r <- r[r$kind == "named", , drop = FALSE]
  expect_identical(nrow(r), 1L)
  expect_identical(r$tex, "math")
  expect_identical(r$resolver, "filter")
})

test_that("TL3: the construct lint reports the E95 text for a named value in math, at its line", {
  x <- w6d_find(w6d_doc(c("Intro.", "", "Words $x = `depth`{.word}$ more.")), "construct")
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, fm_e95(".word", "math"))
  expect_identical(x$line, 7L)
})

test_that("TL3: named-unpublished sees a name used only in math (2.13.11), and a chunk that publishes it silences it", {
  body <- "The depth is $x = `depth`{.num}$ metres."
  x <- w6d_find(w6d_doc(body), "named-unpublished", tier = 1:2)
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 5L)
  expect_identical(x$message, W6D_E70("depth"))
  expect_identical(nrow(w6d_find(w6d_doc(body, w6d_py("depth = 12")), "named-unpublished", tier = 1:2)), 0L)
  # raw LaTeX as well
  y <- w6d_find(w6d_doc(c("```{=latex}", "\\textbf{`depth`{.num}}", "```")), "named-unpublished", tier = 1:2)
  expect_identical(nrow(y), 1L)
})
