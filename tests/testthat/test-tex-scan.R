# Package P2 of design 9 (dev/design-9.md, "formatters that write TeX inside math"):
# the scanner's notion of where a construct sits (the row column `tex`: "" for prose,
# "math" or "raw"), the messages E95 to E99 (rule 5.2.6, rewritten), and the two lints
# that depend on it (lint-source math regions, TX12 value-format). The render-level
# half is test-tex-render.R. P1 (the formatting) is test-tex-target*.R.
#
# Rule 1.4.22 of the design reads 1.4.23 (the options of project formatters took 1.4.22).
# Where the design is silent a test is marked `# READING:`; the reading is listed in the
# report that came with these tests.
# Tests named "(control)" pin today's behaviour: they pass before the feature exists.
# Non-ASCII characters are written as \u escapes.

tx_sc <- function(x, ...) weft:::scan_text(paste(x, collapse = "\n"), ...)

# scan_file() over lines written to a file with extension `ext`: the extension is how the
# scanner learns whether the document is an .Rmd (knit by rmarkdown) or a .qmd (Quarto)
tx_file <- function(lines, ext = ".Rmd") {
  path <- tempfile("tex-scan-", fileext = ext)
  writeLines(lines, path, useBytes = TRUE)
  withr::defer(unlink(path), parent.frame())
  weft:::scan_file(path)
}

tx_errs <- function(r) r$error[!is.na(r$error)]

# a project configuration as the scanner reads it: `.mine` lists tex in `targets:`, `.plain` does not
TX_CFG <- list(formatters = list(
  .mine  = list(`function` = "my_fmt",  stage = "number", options = character(), targets = c("markdown", "tex")),
  .plain = list(`function` = "my_fmt2", stage = "number", options = character())))

# the messages of rule 5.2.6 (TX2), PLACE being "math" or "raw LaTeX"
e95 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it prints words, and a formula holds numbers. ",
  "Move the value out of the %s, or use a number class such as `.num` (rule 5.2.6)."), x, place, place)
e96 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it is markdown emphasis, and %s is TeX. ",
  "Put \\mathbf{} or \\mathit{} around the value in the formula (rule 5.2.6)."), x, place, place)
e97 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it joins items into a phrase or a list. ",
  "Use `.range` for two ends, or move the value out of the %s (rule 5.2.6)."), x, place, place)
e98 <- function(x, place) sprintf(paste0("The project formatter `%s` cannot be used inside %s: its entry under `formatters:` ",
  "in _weft.yml does not list `tex` in `targets:` (rule 5.2.6)."), x, place)
e99 <- function(x, place) sprintf(paste0("`%s` cannot be used inside %s: it is not weft's, so weft would put the value in a ",
  "Pandoc span, and %s has none. Drop it, or move the value out of the %s (rule 5.2.6)."), x, place, place, place)

# the sources that put a construct in math (place "math") or in raw LaTeX (place "raw LaTeX"):
# a function from the construct's text to a document
TX_IN_MATH <- list(
  inline  = function(c1) paste0("A formula $a = ", c1, "$ here."),
  display = function(c1) paste0("Before.\n\n$$ a = ", c1, " $$\n\nAfter."),
  align   = function(c1) paste0("Before.\n\n\\begin{align}\na &= ", c1, "\n\\end{align}\n\nAfter."))
TX_IN_RAW <- list(
  tabular = function(c1) paste0("Before.\n\n\\begin{tabular}{l}\n", c1, "\n\\end{tabular}\n\nAfter."),
  fence   = function(c1) paste0("Before.\n\n```{=latex}\n\\textbf{", c1, "}\n```\n\nAfter."))

# ---- TX1: the column ---------------------------------------------------------------------------

test_that("TX1: every row has a `tex` column of type character; a text with no construct has it, empty", {
  r <- tx_sc("Mean was `r x`{.num} m.")
  expect_true("tex" %in% names(r))
  expect_type(r$tex, "character")
  r0 <- tx_sc("No constructs here.")
  expect_identical(nrow(r0), 0L)
  expect_true("tex" %in% names(r0))
  expect_type(r0$tex, "character")
  expect_length(r0$tex, 0L)
})

NOMATH <- c(
  "Prose `r x`{.num} and `r y` and [a site | # sites]{n=\"k\"} and [UP | DOWN]{sign=\"d\"}.",
  "",
  "A named `depth`{.num} value, [text]{.strong}, and [x | y]{if=\"flag\"}.",
  "",
  "Price \\$5 and \\$6, a [link](http://x.org/a`r z`) and `a $ b` code.")

test_that("TX1 (control): a document with no math scans as it does today, column for column", {
  r <- tx_sc(NOMATH)
  today <- c("kind", "file", "line", "start", "end", "expr", "classes", "keys", "id", "arms",
             "arm_templates", "sep_pos", "parent", "arm", "error", "block_start", "resolver")
  expect_identical(setdiff(names(r), "tex"), today)
  expect_identical(r$kind, c("value", "bare", "n", "sign", "named", "text", "if", "bare"))
  expect_identical(r$line, c(1L, 1L, 1L, 1L, 3L, 3L, 3L, 5L))
  expect_true(all(is.na(r$error)))
})

test_that("TX1: a document with no math has an empty `tex` on every row", {
  r <- tx_sc(NOMATH)
  expect_identical(r$tex, rep("", nrow(r)))
})

test_that("TX1: inline `$...$` math: a construct in it has tex 'math'; the same construct outside does not", {
  r <- tx_sc("Before `r a`{.num} then $x = `r b`{.num}$ then `r c`{.num} after.")
  expect_identical(r$expr, c("a", "b", "c"))
  expect_identical(r$tex, c("", "math", ""))
})

test_that("TX1: a bare value in math has tex 'math' and no error", {
  r <- tx_sc("Here $x = `r b`$ is.")
  expect_identical(r$kind, "bare")
  expect_identical(r$tex, "math")
  expect_true(is.na(r$error))
})

test_that("TX1: display `$$...$$` math, on one line and over several lines", {
  r <- tx_sc(c("Before `r a`{.num}", "", "$$ x = `r b`{.num} $$", "", "$$", "y = `r c`{.num}", "$$", "", "After `r d`{.num}"))
  expect_identical(r$expr, c("a", "b", "c", "d"))
  expect_identical(r$tex, c("", "math", "math", ""))
})

test_that("TX1: two formulas in one paragraph, with a value between them in prose", {
  r <- tx_sc("$a = `r a`{.num}$ then `r b`{.num} then $c = `r c`{.num}$")
  expect_identical(r$tex, c("math", "", "math"))
})

# boundaries: text the scanner must NOT read as math (rows exactly as today, then tex empty)
TX_NOT_MATH <- list(
  list(why = "an escaped dollar sign is not a math opener",
       src = "Costs \\$5 and `r v`{.num} and \\$6.", kinds = "value"),
  list(why = "currency: '$5 and $6' is not math (a closing dollar followed by a digit)",
       src = "Costs $5 and $6 and `r v`{.num} here.", kinds = "value"),
  list(why = "a dollar sign inside code spans is not a math delimiter",
       src = "Use `$x` and `r v`{.num} and `y$` here.", kinds = "value"),
  list(why = "a dollar sign inside a fenced block is not a math delimiter",
       src = c("```", "$x", "```", "", "Then `r v`{.num} here.", "", "```", "y$", "```"), kinds = "value"),
  list(why = "unclosed math: the value after a lone opener is prose",
       src = "Cost $x = `r v`{.num} and no closing sign.", kinds = "value"),
  list(why = "math does not run across a blank line",
       src = c("Open $a = 1", "", "`r v`{.num} and close b$"), kinds = "value"),
  list(why = "a dollar with a space after it does not open math",
       src = "A $ `r v`{.num} $ spaced pair.", kinds = "value"),
  list(why = "a backslash-escaped closing dollar does not close math",
       src = "Open $a `r v`{.num} b\\$ never closed.", kinds = "value"))

test_that("TX1 (control): text that is not math scans as it does today", {
  for (cs in TX_NOT_MATH) {
    r <- tx_sc(cs$src)
    expect_identical(r$kind, cs$kinds, label = cs$why)
    expect_true(all(is.na(r$error)), label = cs$why)
  }
})

test_that("TX1: the boundaries of `$` math leave the construct's tex empty", {
  for (cs in TX_NOT_MATH) {
    r <- tx_sc(cs$src)
    expect_identical(r$tex, rep("", length(cs$kinds)), label = cs$why)
  }
})

# the math environments of TX1
TX_ENVS <- c("equation", "align", "alignat", "gather", "multline", "flalign", "eqnarray",
             "equation*", "align*", "alignat*", "gather*", "multline*", "flalign*", "eqnarray*",
             "math", "displaymath", "aligned", "alignedat", "gathered", "split", "cases", "array",
             "matrix", "pmatrix", "bmatrix", "Bmatrix", "vmatrix", "Vmatrix", "smallmatrix", "subarray", "CD")

tx_env <- function(name, body) paste0("\\begin{", name, "}\n", body, "\n\\end{", name, "}")

test_that("TX1: each math environment, starred or not, is math (tex 'math') and its end is where the construct stops", {
  for (nm in TX_ENVS) {
    r <- tx_sc(c("Before `r a`{.num}", "", tx_env(nm, "x &= `r b`{.num} \\\\ y &= `r c`"), "", "After `r d`{.num}"))
    expect_identical(r$expr, c("a", "b", "c", "d"), label = nm)
    expect_identical(r$tex, c("", "math", "math", ""), label = nm)
    expect_true(all(is.na(r$error)), label = nm)
  }
})

test_that("TX1 (control): a construct beside a math environment is a row as it is today", {
  # the environment itself changes nothing outside it: the two prose rows are found today
  r <- tx_sc(c("Before `r a`{.num}", "", "\\begin{align}", "x = 1", "\\end{align}", "", "After `r d`{.num}"))
  expect_identical(r$expr, c("a", "d"))
  expect_true(all(is.na(r$error)))
})

test_that("TX1: an environment on one line, and inside a paragraph of prose", {
  r <- tx_sc("Say \\begin{equation} a = `r b`{.num} \\end{equation} and `r c`{.num} then.")
  expect_identical(r$expr, c("b", "c"))
  expect_identical(r$tex, c("math", ""))
})

test_that("TX1: the end of an environment is the matching `\\end`, counting nesting of the same name", {
  src <- c("\\begin{align*}", "a &= `r a`{.num}", "\\begin{align*}", "b &= `r b`{.num}", "\\end{align*}",
           "c &= `r c`{.num}", "\\end{align*}", "", "after `r d`{.num}")
  r <- tx_sc(src)
  expect_identical(r$expr, c("a", "b", "c", "d"))
  # c sits after the inner \end{align*} and is still inside the outer one
  expect_identical(r$tex, c("math", "math", "math", ""))
})

test_that("TX1: an environment of another name inside a math environment is part of it", {
  r <- tx_sc(c("\\begin{equation}", "\\begin{aligned}", "a &= `r a`{.num}", "\\end{aligned}",
               "b = `r b`{.num}", "\\end{equation}", "", "after `r d`{.num}"))
  expect_identical(r$tex, c("math", "math", ""))
})

test_that("TX1: two environments of one name in a row are two regions; prose between them is prose", {
  r <- tx_sc(c("\\begin{align}", "a = `r a`{.num}", "\\end{align}", "between `r b`{.num}", "",
               "\\begin{align}", "c = `r c`{.num}", "\\end{align}"))
  expect_identical(r$expr, c("a", "b", "c"))
  expect_identical(r$tex, c("math", "", "math"))
})

test_that("TX1: a `$` inside a math environment does not open another region and does not end this one", {
  r <- tx_sc(c("\\begin{align}", "a &= \\text{cost $} `r a`{.num}", "b &= `r b`{.num}", "\\end{align}", "", "after `r d`{.num}"))
  expect_identical(r$expr, c("a", "b", "d"))
  expect_identical(r$tex, c("math", "math", ""))
})

test_that("TX1 (reading): an environment with no matching \\end is not a region; its constructs are prose", {
  # READING: the design says the end is "the matching \end"; with none there is no region
  # (as an unclosed `$` is not math). The same for an \end of another name.
  r <- tx_sc(c("\\begin{align}", "a = `r a`{.num}", "", "more `r b`{.num}"))
  expect_identical(r$tex, c("", ""))
  r <- tx_sc(c("\\begin{align}", "a = `r a`{.num}", "\\end{equation}"))
  expect_identical(r$tex, "")
})

test_that("TX1: a math environment named inside a code span or a fenced block is not a region", {
  r <- tx_sc(c("Write `\\begin{align}` then `r a`{.num} and `\\end{align}`."))
  expect_identical(r$tex, "")
  r <- tx_sc(c("```", "\\begin{align}", "```", "", "`r a`{.num}", "", "```", "\\end{align}", "```"))
  expect_identical(r$tex, "")
})

test_that("TX1: any other environment in prose is raw LaTeX (tex 'raw')", {
  for (nm in c("tabular", "itemize", "figure", "center", "minipage")) {
    r <- tx_sc(c("Before `r a`{.num}", "", tx_env(nm, "cell `r b`{.num}"), "", "After `r d`{.num}"))
    expect_identical(r$expr, c("a", "b", "d"), label = nm)
    expect_identical(r$tex, c("", "raw", ""), label = nm)
  }
})

test_that("TX1: a math environment inside a raw one is raw, and nesting of the raw name is counted", {
  r <- tx_sc(c("\\begin{figure}", "\\begin{align}", "a = `r a`{.num}", "\\end{align}",
               "\\begin{figure}", "b `r b`{.num}", "\\end{figure}", "c `r c`{.num}", "\\end{figure}", "", "d `r d`{.num}"))
  expect_identical(r$expr, c("a", "b", "c", "d"))
  # READING: the outer region decides the whole span, so a math environment inside raw LaTeX is raw
  expect_identical(r$tex, c("raw", "raw", "raw", ""))
})

test_that("TX1: the body of a fence whose info string is {=latex} or {=tex} is raw", {
  for (info in c("{=latex}", "{=tex}")) {
    r <- tx_sc(c("Before `r a`{.num}", "", paste0("```", info), "\\textbf{`r b`{.num}}", "```", "", "After `r d`{.num}"))
    expect_identical(r$expr, c("a", "b", "d"), label = info)
    expect_identical(r$tex, c("", "raw", ""), label = info)
    expect_true(all(is.na(r$error)), label = info)
  }
})

test_that("TX1 (control): the fences that are not raw TeX read their inline R as they do today", {
  for (info in c("{=typst}", "{=html}", "latex", "")) {
    r <- tx_sc(c("Before.", "", paste0("```", info), "see `r b`{.num} here", "```", "", "After."))
    expect_identical(r$expr, "b", label = info)
    expect_true(all(is.na(r$error)), label = info)
  }
})

test_that("TX1: fences that are not {=latex} or {=tex} (typst, html, a latex code block, a plain fence) are prose", {
  for (info in c("{=typst}", "{=html}", "latex", "")) {
    r <- tx_sc(c("Before.", "", paste0("```", info), "see `r b`{.num} here", "```", "", "After."))
    expect_identical(r$tex, "", label = info)
  }
})

test_that("TX1: a code span followed by {=latex} or {=tex} is raw", {
  for (info in c("{=latex}", "{=tex}")) {
    r <- tx_sc(paste0("Before `r a`{.num} and ``\\textbf{`r b`{.num}}``", info, " and `r d`{.num}."))
    expect_identical(r$expr, c("a", "b", "d"), label = info)
    expect_identical(r$tex, c("", "raw", ""), label = info)
  }
})

test_that("TX1 (control): a code span followed by {=typst} is read as it is today", {
  r <- tx_sc("Before ``\\textbf{`r b`{.num}}``{=typst} and `r d`{.num}.")
  expect_identical(r$expr, c("b", "d"))
  expect_true(all(is.na(r$error)))
})

test_that("TX1: a code span followed by {=typst} is prose", {
  r <- tx_sc("Before ``\\textbf{`r b`{.num}}``{=typst} and `r d`{.num}.")
  expect_identical(r$tex, c("", ""))
})

# ---- TX1: \( \) and \[ \] ----------------------------------------------------------------------

TX_PAREN <- c("Before `r a`{.num}, \\(c = `r b`{.num}\\) and `r d`{.num}.", "",
              "\\[", "e = `r f`{.num}", "\\]", "", "After `r g`{.num}")

test_that("TX1 (control): \\( and \\[ in a file give the rows they give today", {
  for (ext in c(".Rmd", ".qmd")) {
    r <- tx_file(TX_PAREN, ext)
    expect_identical(r$expr, c("a", "b", "d", "f", "g"), label = ext)
    expect_true(all(is.na(r$error)), label = ext)
  }
})

test_that("TX1: in an .Rmd, `\\(...\\)` and `\\[...\\]` are math", {
  r <- tx_file(TX_PAREN, ".Rmd")
  expect_identical(r$expr, c("a", "b", "d", "f", "g"))
  expect_identical(r$tex, c("", "math", "", "math", ""))
})

test_that("TX1: in a .qmd, `\\(...\\)` and `\\[...\\]` are escaped brackets, not math", {
  r <- tx_file(TX_PAREN, ".qmd")
  expect_identical(r$tex, rep("", 5L))
})

test_that("TX1: math environments and `$` math are the same in an .Rmd and a .qmd", {
  src <- c("Before `r a`{.num} $x = `r b`{.num}$", "", tx_env("align", "y = `r c`{.num}"), "", "After `r d`{.num}")
  for (ext in c(".Rmd", ".qmd")) {
    r <- tx_file(src, ext)
    expect_identical(r$tex, c("", "math", "math", ""), label = ext)
  }
})

test_that("TX1 (reading): an unclosed \\( in an .Rmd is not a region", {
  # READING: as for an unclosed `$`: the region needs its closer, within the paragraph
  r <- tx_file(c("Open \\(a = `r a`{.num} and no closer.", "", "later `r b`{.num} \\)"), ".Rmd")
  expect_identical(r$tex, c("", ""))
})

# ---- TX1: HTML comments, brackets, named values -------------------------------------------------

test_that("TX1 (reading): inline R in an HTML comment is read as prose, even when math signs are in the comment", {
  # READING: the comment is passed over (rule 1.1.10: only knitr's inline R is read in it), so nothing in it is math
  r <- tx_sc("<!-- $a = `r v`{.num}$ -->")
  expect_identical(r$kind, "value")
  expect_identical(r$tex, "")
  expect_true(is.na(r$error))
  r <- tx_sc(c("<!--", "\\begin{align}", "a = `r v`{.num}", "\\end{align}", "-->"))
  expect_identical(r$tex, "")
})

test_that("TX1 (control): a bracket in `$` math is not a span", {
  r <- tx_sc("Here $[a | b]{if=\"x\"} + [c]{.strong}$ is.")
  expect_identical(nrow(r), 0L)
})

test_that("TX1: a bracket in a math environment, a raw environment or a {=latex} fence is not a span", {
  for (src in list(tx_env("align", "[a | b]{if=\"x\"} + [c]{.strong} + [one | # many]{n=\"k\"}"),
                   tx_env("tabular", "[a | b]{if=\"x\"} + [c]{.strong}"),
                   c("```{=latex}", "[a | b]{if=\"x\"} + [c]{.strong}", "```"))) {
    expect_identical(nrow(tx_sc(src)), 0L, label = paste(src, collapse = " / "))
  }
})

test_that("TX1 (T2): a named value in `$` math gives a named row with tex math, beside the one in prose", {
  r <- tx_sc("Here $x = `depth`{.num}$ and `depth`{.num}.")
  expect_identical(r$kind, c("named", "named"))
  expect_identical(r$line, c(1L, 1L))
  expect_identical(r$tex, c("math", ""))
})

test_that("TX1 (T2): a named value in math, in a math environment, in raw LaTeX or in a {=latex} fence gives a named row with tex set", {
  # T2 (named values in math) adds these rows
  srcs <- list("Here $x = `depth`{.num}$ only." = "math",
               "$$ x = `depth`{.num} $$" = "math")
  for (nm in names(srcs)) {
    r <- tx_sc(nm)
    expect_identical(r$kind, "named", label = nm)
    expect_identical(r$tex, srcs[[nm]], label = nm)
  }
  for (src in list(tx_env("align", "x &= `depth`{.num}"))) {
    r <- tx_sc(src)
    expect_identical(r$kind, "named")
    expect_identical(r$tex, "math")
  }
  for (src in list(tx_env("tabular", "`depth`{.num}"),
                   c("```{=latex}", "\\textbf{`depth`{.num}}", "```"))) {
    r <- tx_sc(src)
    expect_identical(r$kind, "named", label = paste(src, collapse = " / "))
    expect_identical(r$tex, "raw", label = paste(src, collapse = " / "))
  }
})

test_that("TX1: a named value outside math beside a formula is still a row, with tex empty", {
  r <- tx_sc("Here $x = `depth`{.num}$ and `depth`{.num}.")
  expect_identical(r$kind, c("named", "named"))
  expect_identical(r$tex[[2]], "")
})

# ---- TX2: classes that work -----------------------------------------------------------------------

TX_OK <- c("`r v`{.num}", "`r v`{.pct}", "`r v`{.sci}", "`r v`{.p}", "`r v`{.num .plus}", "`r v`{.pct .plus}",
           "`r v`{.range}", "`r v`{.range .plus}", "`r v`{.uname}", "`r v`{.usym}", "`r v`{.nounit}",
           "`r v`{#depth1 .num}", "`r v`{.num digits=\"2\"}", "`r v`{.num sigfig=\"3\"}",
           "`r v`{.num unit=\"mg/L\"}", "`r v`{.p label=\"q\"}", "`r v`{.num why=\"given\"}",
           "`r v`{.mine}", "`r v`")

test_that("TX2: the classes and keys that have a TeX form are no error in math or in raw LaTeX", {
  for (c1 in TX_OK) for (mk in c(TX_IN_MATH, TX_IN_RAW)) {
    r <- tx_sc(mk(c1), config = TX_CFG)
    expect_identical(nrow(r), 1L, label = c1)
    expect_true(is.na(r$error), label = c1)
  }
})

test_that("TX2: the same constructs in math carry tex 'math'; in raw LaTeX tex 'raw'", {
  for (c1 in TX_OK) {
    for (mk in TX_IN_MATH) expect_identical(tx_sc(mk(c1), config = TX_CFG)$tex, "math", label = c1)
    for (mk in TX_IN_RAW) expect_identical(tx_sc(mk(c1), config = TX_CFG)$tex, "raw", label = c1)
  }
})

test_that("TX2: an id defined in math is kept on its row", {
  r <- tx_sc("Here $a = `r v`{#depth1 .num}$ and later [a site | # sites]{n=\"#depth1\"}.")
  expect_identical(r$id[1], "depth1")
  expect_true(all(is.na(r$error)))
})

# a class block with a word, emphasis, list or foreign class is an error: one message per class or key
TX_BAD <- list(
  list(src = "`r v`{.word}",  want = function(p) e95(".word", p)),
  list(src = "`r v`{.count}", want = function(p) e95(".count", p)),
  list(src = "`r v`{.ord}",   want = function(p) e95(".ord", p)),
  list(src = "`r v`{.no}",    want = function(p) e95(".no", p)),
  list(src = "`r v`{.date}",  want = function(p) e95(".date", p)),
  list(src = "`r v`{.a}",     want = function(p) e95(".a", p)),
  list(src = "`r v`{.cap}",   want = function(p) e95(".cap", p)),
  list(src = "`r v`{.val}",   want = function(p) e95(".val", p)),
  list(src = "`r v`{.em}",     want = function(p) e96(".em", p)),
  list(src = "`r v`{.strong}", want = function(p) e96(".strong", p)),
  list(src = "`r v`{.and}",   want = function(p) e97(".and", p)),
  list(src = "`r v`{.or}",    want = function(p) e97(".or", p)),
  list(src = "`r v`{.pairs}", want = function(p) e97(".pairs", p)),
  list(src = "`r v`{.ul}",    want = function(p) e97(".ul", p)),
  list(src = "`r v`{.ol}",    want = function(p) e97(".ol", p)),
  list(src = "`r v`{.dl}",    want = function(p) e97(".dl", p)),
  list(src = "`r v`{sep=\"; \"}",     want = function(p) e97("sep", p)),
  list(src = "`r v`{last=\" or \"}",  want = function(p) e97("last", p)),
  list(src = "`r v`{trunc=\"3\"}",    want = function(p) e97("trunc", p)),
  list(src = "`r v`{.and none=\"x\"}", want = function(p) c(e97(".and", p), e97("none", p))),
  list(src = "`r v`{.plain}", want = function(p) e98(".plain", p)),
  list(src = "`r v`{.foo}",   want = function(p) e99(".foo", p)),
  list(src = "`r v`{foo=\"a\"}", want = function(p) e99("foo", p)))

tx_check_bad <- function(maker, place) {
  for (cs in TX_BAD) {
    r <- tx_sc(maker(cs$src), config = TX_CFG)
    expect_identical(nrow(r), 1L, label = cs$src)
    if (grepl("\\{\\.(ul|ol|dl)\\}", cs$src)) {
      # READING: a list block that is not alone in its paragraph may also carry the block error of rule 1.4.6;
      # E97 must be there, first
      got <- strsplit(r$error, "\n", fixed = TRUE)[[1L]]
      expect_identical(got[1L], cs$want(place), label = cs$src)
    } else {
      expect_identical(r$error, paste(cs$want(place), collapse = "\n"), label = cs$src)
    }
  }
}

test_that("TX2, E95 to E99: each message and its exact text, in inline math", {
  tx_check_bad(TX_IN_MATH$inline, "math")
})

test_that("TX2, E95 to E99: each message and its exact text, in display math", {
  tx_check_bad(TX_IN_MATH$display, "math")
})

test_that("TX2, E95 to E99: each message and its exact text, in a math environment", {
  tx_check_bad(TX_IN_MATH$align, "math")
})

test_that("TX2, E95 to E99: PLACE is `raw LaTeX` in a raw environment", {
  tx_check_bad(TX_IN_RAW$tabular, "raw LaTeX")
})

test_that("TX2, E95 to E99: PLACE is `raw LaTeX` in a {=latex} fence and in a {=tex} fence", {
  tx_check_bad(TX_IN_RAW$fence, "raw LaTeX")
  tx_check_bad(function(c1) paste0("Before.\n\n```{=tex}\n", c1, "\n```\n"), "raw LaTeX")
})

test_that("TX2, E95 to E99: PLACE is `raw LaTeX` after a code span followed by {=latex}", {
  r <- tx_sc("Text ``\\textbf{`r v`{.word}}``{=latex} more", config = TX_CFG)
  expect_identical(r$error, e95(".word", "raw LaTeX"))
})

test_that("TX2, E95 to E99: in an .Rmd the \\(...\\) form is math, so the same errors say `math`", {
  r <- tx_file(c("Here \\(a = `r v`{.word}\\) and \\[b = `r w`{.em}\\].", ""), ".Rmd")
  expect_identical(r$error, c(e95(".word", "math"), e96(".em", "math")))
})

test_that("TX2: there is one message per offending class or key, in the order written", {
  r <- tx_sc("Here $a = `r v`{.word .strong .and}$ is.")
  expect_identical(r$error, paste(e95(".word", "math"), e96(".strong", "math"), e97(".and", "math"), sep = "\n"))
  r <- tx_sc("Here $a = `r v`{.strong .word}$ is.")
  expect_identical(r$error, paste(e96(".strong", "math"), e95(".word", "math"), sep = "\n"))
  # classes first, then keys, as written
  r <- tx_sc("Here $a = `r v`{.foo .word sep=\"; \" bar=\"1\"}$ is.")
  expect_identical(r$error, paste(e99(".foo", "math"), e95(".word", "math"), e97("sep", "math"), e99("bar", "math"), sep = "\n"))
})

test_that("TX2: a bad class in math is an error beside the good ones, which are not", {
  r <- tx_sc("Here $a = `r v`{.num .word}$ is.")
  expect_true(any(grepl(e95(".word", "math"), r$error, fixed = TRUE)))
  expect_false(any(grepl(".num` cannot", r$error, fixed = TRUE)))
})

test_that("TX2 (control): the same classes and keys outside math are no error", {
  for (cs in TX_BAD) {
    if (grepl(".plain", cs$src, fixed = TRUE)) next
    r <- tx_sc(paste0("Intro.\n\n", cs$src, "\n\nOutro."), config = TX_CFG)
    expect_identical(nrow(r), 1L, label = cs$src)
    expect_true(is.na(r$error), label = cs$src)
  }
})

test_that("TX2: the old message of rule 5.2.6 is gone, for a value with a good class and a bad one alike", {
  for (src in c("Here $a = `r v`{.num}$ is.", "Here $a = `r v`{.word}$ is.")) {
    r <- tx_sc(src)
    expect_false(any(grepl("A class block cannot be used inside math", r$error, fixed = TRUE)), label = src)
  }
  expect_true(is.na(tx_sc("Here $a = `r v`{.num}$ is.")$error))
})

test_that("TX2 (control): the other construct errors still apply in math (two classes of one group)", {
  r <- tx_sc("Here $a = `r v`{.num .p}$ is.")
  expect_match(r$error, "Two classes from one group in one block: .num .p (rule 1.4.2).", fixed = TRUE)
})

test_that("TX2: an E95 to E99 row keeps its tex column", {
  expect_identical(tx_sc("Here $a = `r v`{.word}$ is.")$tex, "math")
  expect_identical(tx_sc(TX_IN_RAW$tabular("`r v`{.word}"))$tex, "raw")
})

# ---- TX12: the construct lint, lint-source regions and value-format -------------------------------

tx_cons <- function(text, ext = "qmd", ...) lint_one(text, rules = "construct", ext = ext, ...)

test_that("TX12, 5.3.1: the construct lint reports E95 to E99 in math, spec 5.2.6, with the scanner's text", {
  for (e in c("qmd", "Rmd")) {
    x <- tx_cons(c("Some prose before.", "", "$p = `r p`{.word}$", "", "Some prose after."), ext = e)
    expect_identical(nrow(x), 1L, label = e)
    expect_identical(x$rule, "construct")
    expect_identical(x$spec, "5.2.6")
    expect_identical(x$message, e95(".word", "math"))
    expect_identical(x$text, "`r p`{.word}")
    expect_identical(x$tier, 1L)
  }
})

test_that("TX12: the construct lint reports a raw-LaTeX construct with PLACE `raw LaTeX`", {
  x <- tx_cons(c("Some prose before.", "", "\\begin{tabular}{l}", "`r p`{.em}", "\\end{tabular}", "", "After."))
  expect_identical(x$message, e96(".em", "raw LaTeX"))
  expect_identical(x$spec, "5.2.6")
  expect_identical(x$line, 4L)
})

test_that("TX12: the construct lint has a finding for each of E95 to E99 and none for a class with a TeX form", {
  for (cs in TX_BAD) {
    x <- tx_cons(c("Some prose before.", "", paste0("$p = ", cs$src, "$"), "", "After."))
    expect_true(all(x$rule == "construct"), label = cs$src)
    expect_true(all(x$spec == "5.2.6") && nrow(x) >= 1L, label = cs$src)
  }
  x <- tx_cons(c("Some prose before.", "", "$p = `r p`{.p}$", "", "Some prose after."))
  expect_identical(nrow(x), 0L)
})

test_that("TX12 (control): the construct lint says nothing of a class block outside math", {
  x <- tx_cons(c("Some prose before.", "", "The value `r p`{.word} is.", "", "Some prose after."))
  expect_identical(nrow(x), 0L)
})

test_that("TX12: lint-source reads a math environment as a math region, so a typed numeral is 'in math'", {
  src <- c("Some words here.", "", "\\begin{align}", "y &= 3 + x", "\\end{align}")
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(src, rules = "numeral", ext = e)
    expect_identical(x$text, "3", label = e)
    expect_identical(x$message, "\"3\" is a number typed in math (rule 5.2.6).", label = e)
    expect_identical(x$spec, "5.2.6", label = e)
  }
})

test_that("TX12: the exponent and subscript exemption applies inside a math environment (rule 5.2.6)", {
  expect_numerals(c("Some words here.", "", "\\begin{equation}", "x^2 + \\beta_{12} + y_3", "\\end{equation}"), character())
  expect_numerals(c("Some words here.", "", "\\begin{align*}", "10^{-3} &= z", "\\end{align*}"), "10")
})

test_that("TX12 (control): a numeral typed in `$` math is a math numeral today", {
  expect_numerals("The level is $p = 0.02$ here.", "0.02", ctx = "prose")
})

FMT_MATH_MSG <- function(fn) sprintf("The value in math is formatted with `%s()`, which writes markdown (rule 5.6.4).", fn)

test_that("TX12, 5.6.4: value-format flags a bare weft fmt_*() value in math, with its message and hint", {
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(c3_para("The level $p = `r fmt_num(x)`$ here."), rules = "value-format", ext = e)
    expect_identical(nrow(x), 1L, label = e)
    expect_identical(x$text, "fmt_num")
    expect_identical(x$tier, 2L)
    expect_identical(x$spec, "5.6.4")
    expect_identical(x$message, FMT_MATH_MSG("fmt_num"))
    expect_match(x$hint, "Give it a class block,", fixed = TRUE)
    expect_match(x$hint, "`r x`{.num}", fixed = TRUE)
    expect_match(x$hint, "which writes TeX in math.", fixed = TRUE)
  }
})

test_that("TX12: value-format covers display math, a math environment, and every fmt_*() of weft", {
  expect_c3(c3_para("$$ q = `r fmt_pct(x)` $$"), "value-format", "fmt_pct")
  expect_c3(c3_para("\\begin{align}", "q &= `r weft::fmt_sci(x)`", "\\end{align}"), "value-format", "fmt_sci")
  expect_c3(c3_para("$a = `r fmt_p(x)`$"), "value-format", "fmt_p")
  expect_c3(c3_para("$a = `r fmt_range(x)`$"), "value-format", "fmt_range")
  expect_c3(c3_para("$a = `r fmt_num(x, target = \"markdown\")`$"), "value-format", "fmt_num")
})

test_that("TX12: value-format also reads a bare value in raw LaTeX", {
  x <- lint_one(c3_para("```{=latex}", "\\textbf{`r fmt_num(x)`}", "```"), rules = "value-format")
  expect_identical(nrow(x), 1L)
  expect_identical(x$spec, "5.6.4")
})

test_that("TX12 (control): value-format does not flag fmt_*() with target = \"tex\", nor a call that is not outermost", {
  expect_c3(c3_para("$a = `r fmt_num(x, target = \"tex\")`$"), "value-format", character())
  expect_c3(c3_para("$a = `r mean(fmt_num(x))`$"), "value-format", character())
  expect_c3(c3_para("$a = `r x`$"), "value-format", character())
})

test_that("TX12 (control): value-format on a fmt_*() value outside math is not a finding today", {
  expect_c3(c3_para("The level `r fmt_num(x)` here."), "value-format", character())
  expect_c3(c3_para("The level `r round(x, 2)` here."), "value-format", "round")
})
