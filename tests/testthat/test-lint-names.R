# Package 3c: lone-bar, if-zero, name (5.3.3). Contract: dev/design-3.md L26, L27, L28, K7, Q8.
# Section 21's "Names" and "Text spans". Helpers: helper-3.R, helper-3c.R.

# ---- L26 lone-bar -----------------------------------------------------------------------

BAR_CASES <- list(
  list(src = r"---([a site | # sites]{count="k"})---",       want = "a site | # sites"),
  list(src = "[a | b]{.smallcaps}",                          want = "a | b"),
  list(src = "[a | b]",                                      want = character()),
  list(src = "[a \\| b]{.x}",                                want = character()),
  list(src = "[a|b|c]{.x}",                                  want = character()),
  list(src = r"---([a | b]{n="k"})---",                      want = character()),
  # the other governor and marker keys, and a key in any case
  list(src = r"---([a | b]{if="k"})---",                     want = character()),
  list(src = r"---([a | b | c]{sign="k"})---",               want = character()),
  list(src = r"---([a | b]{list="k"})---",                   want = character()),
  list(src = r"---([a | b]{cite="smith2020"})---",           want = character()),
  list(src = r"---([a | b]{N="k"})---",                      want = character()),
  list(src = r"---([a | b]{If="k"})---",                     want = character()),
  list(src = r"---([a | b]{.x n="k"})---",                   want = character()),
  # no governor or marker key: a class, a renderer key, an unknown key
  list(src = "[a | b]{.x}",                                  want = "a | b"),
  list(src = "[a | b]{.num}",                                want = "a | b"),
  list(src = r"---([a | b]{digits="2"})---",                 want = "a | b"),
  list(src = r"---([a | b]{custom-style="Key"})---",         want = "a | b"),
  # exactly one bar that is not escaped
  list(src = "[a \\| b | c]{.x}",                            want = "a \\| b | c"),
  list(src = "[a | b \\| c]{.x}",                            want = "a | b \\| c"),
  list(src = "[a \\| b \\| c]{.x}",                          want = character()),
  list(src = "[a || b]{.x}",                                 want = character()),
  # a bar inside a nested code span or bracket does not count
  list(src = "[a `x | y` b]{.x}",                            want = character()),
  list(src = "[a `x | y` b | c]{.x}",                        want = "a `x | y` b | c"),
  list(src = "[a [b | c]{.y} d]{.x}",                        want = "b | c"),
  list(src = "[a [b]{.y} | c]{.x}",                          want = "a [b]{.y} | c"),
  # no attribute block, or a link or image: not a span
  list(src = "[a | b](u.html)",                              want = character()),
  list(src = "![a | b](m.png)",                              want = character()),
  # a pipe-table row is not a span site
  list(src = c("| Site | Note |", "|---|---|", "| [a | b]{.x} | c |"), want = character())
)

test_that("3c L26: lone-bar, each row of the design's table and its near misses (qmd and Rmd)", {
  for (cs in BAR_CASES) {
    src <- if (length(cs$src) > 1L) cs$src else c3_para(cs$src)
    expect_c3(src, "lone-bar", cs$want, label = paste(cs$src, collapse = " / "))
  }
})

test_that("3c L26: lone-bar has tier 2, spec 5.3.3, a position at the bracket text, and its context", {
  lines <- c3_para("Ab [a site | # sites]{.x} cd.")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "lone-bar", ext = ext)
    r <- lf_one(x, "lone-bar")
    expect_identical(r$tier, 2L)
    expect_identical(r$spec, "5.3.3")
    expect_identical(r$text, "a site | # sites")
    expect_identical(r$line, 3L)
    expect_identical(r$col, 5L)
    expect_identical(r$context, "prose")
    expect_match(r$message, "(rule 5.3.3).", fixed = TRUE)
  }
  x <- lint_one(c3_abstract("A [a | b]{.x} here."), rules = "lone-bar")
  expect_identical(lf_one(x, "lone-bar")$context, "front-matter")
  expect_identical(lf_one(x, "lone-bar")$line, 4L)
})

test_that("3c L26: lone-bar is not raised for a span inside code, a comment or a fence", {
  expect_c3(c3_para("`[a | b]{.x}`"), "lone-bar", character())
  expect_c3(c3_para("<!-- [a | b]{.x} -->"), "lone-bar", character())
  expect_c3(c("T.", "", "```", "[a | b]{.x}", "```", "", "A."), "lone-bar", character())
  expect_c3(c(c3_para("T."), c3_chunk("s <- '[a | b]{.x}'")), "lone-bar", character())
})

test_that("3c L26: two spans on a line and on separate lines are each found, in order", {
  lines <- c("A [a | b]{.x} and [c | d]{.y}.", "", "B [e | f]{.z}.")
  x <- lint_one(lines, rules = "lone-bar")
  expect_identical(lf_texts(x), c("a | b", "c | d", "e | f"))
  expect_identical(lf_lines(x), c(1L, 1L, 3L))
})

# ---- L27 if-zero ------------------------------------------------------------------------

ZERO_CASES <- list(
  list(src = r"---([up | down]{if="d > 0"})---",             want = "d > 0"),
  list(src = r"---([a]{if="n == 0 & ok"})---",               want = "n == 0 & ok"),
  list(src = r"---([a]{if="d > 0.5"})---",                   want = character()),
  list(src = r"---([a]{if="0 < d"})---",                     want = "0 < d"),       # either argument
  list(src = r"---([a]{if="d >= 0L"})---",                   want = "d >= 0L"),
  list(src = r"---([a]{if="d != 0.0"})---",                  want = "d != 0.0"),
  list(src = r"---([a]{if="d <= 0"})---",                    want = "d <= 0"),
  list(src = r"---([a]{if="d < -0"})---",                    want = "d < -0"),
  list(src = r"---([a]{if="d>0"})---",                       want = "d>0"),
  list(src = r"---([a]{if="isTRUE(d > 0)"})---",             want = "isTRUE(d > 0)"),
  list(src = r"---([a]{if="d > 0 & e > 0"})---",             want = "d > 0 & e > 0"), # one finding per row
  list(src = r"---([a]{if="d > 10"})---",                    want = character()),
  list(src = r"---([a]{if="d > x0"})---",                    want = character()),
  list(src = r"---([a]{if="d > 1"})---",                     want = character()),
  list(src = r"---([a]{if="d > 'a'"})---",                   want = character()),
  list(src = r"---([a]{if="ok"})---",                        want = character()),
  list(src = r"---([a]{if="d == e"})---",                    want = character()),
  list(src = r"---([a]{if="d + 0 > e"})---",                 want = character()),  # 0 is not an argument of the comparison
  # only an `if` row: the other governors, and a value, are not
  list(src = r"---([a | b | c]{sign="d > 0"})---",           want = character()),
  list(src = r"---([a | b]{n="d > 0"})---",                  want = character()),
  list(src = "`r d > 0`",                                    want = character())
)

test_that("3c L27: if-zero, each row of the design's table and its near misses (qmd and Rmd)", {
  expect_c3_cases(ZERO_CASES, "if-zero")
})

test_that("3c L27: if-zero has tier 2, spec 5.3.3, and the position of the condition", {
  lines <- c3_para(r"---(Ab [up | down]{if="d > 0"} cd.)---")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "if-zero", ext = ext)
    r <- lf_one(x, "if-zero", "d > 0")
    expect_identical(r$tier, 2L)
    expect_identical(r$spec, "5.3.3")
    expect_identical(r$line, 3L)
    expect_identical(r$col, 20L)
    expect_identical(r$context, "prose")
    expect_match(r$message, "(rule 5.3.3).", fixed = TRUE)
  }
})

test_that("3c L27: if-zero, in a caption, front matter and a weft_str() string", {
  cap <- c(c3_para("Intro."),
           c3_chunk("plot(1)", "#| label: fig-a", "#| fig-cap: |", r"---(#|   Value [a|b]{if="d > 0"} here.)---"))
  x <- lint_one(cap, rules = "if-zero")
  expect_identical(lf_one(x, "if-zero", "d > 0")$context, "caption")
  x <- lint_one(c3_abstract(r"---(Value [a|b]{if="d > 0"} here.)---"), rules = "if-zero")
  expect_identical(lf_one(x, "if-zero", "d > 0")$context, "front-matter")
})

# ---- L28 name ---------------------------------------------------------------------------

WEFT_KEYS_GOV <- c("n", "if", "sign", "list", "cite")
WEFT_KEYS_REND <- c("digits", "sigfig", "unit", "sep", "last", "trunc", "none")
WEFT_CLASSES <- c("num", "pct", "sci", "p", "date", "no", "word", "count", "ord", "and", "or",
                  "pairs", "range", "ul", "ol", "dl", "uname", "usym", "nounit", "a", "cap",
                  "strong", "em", "weft-literal")
PANDOC_CLASSES <- c("smallcaps", "underline", "mark")

# one-edit mutants of a name that are not weft or Pandoc names and keep 3 characters or more
c3_mutants <- function(nm) {
  chars <- strsplit(nm, "")[[1]]
  n <- length(chars)
  swapped <- if (n >= 2L) paste(c(chars[2], chars[1], chars[-(1:2)]), collapse = "") else nm
  out <- c(swapped,
           paste0(substr(nm, 1, n - 1L), "z"),
           substr(nm, 2, n))
  known <- tolower(c(WEFT_KEYS_GOV, WEFT_KEYS_REND, WEFT_CLASSES, PANDOC_CLASSES, "why", "custom-style"))
  out <- unique(out[nchar(out) >= 3L & !(tolower(out) %in% known) & out != nm])
  out
}

test_that("3c L28: every weft name as written is never listed, including two names one edit apart (Q8)", {
  cls <- WEFT_CLASSES
  lines <- c(
    paste0("`r x`{.", cls, "}"),                                   # every class on a value
    "[a | b]{n=\"k\"}", "[a | b]{if=\"x\"}", "[a | b | c]{sign=\"x\"}", "[a | b]{list=\"x\"}", "[a]{cite=\"smith2020\"}",
    paste0("`r x`{.num ", WEFT_KEYS_REND, "=\"2\"}"),              # every renderer key
    "[1]{.weft-literal why=\"SOP 12\"}",
    "`r x`{.num .smallcaps}", "`r x`{.num .underline}", "`r x`{.num .mark}",
    "`r x`{.num custom-style=\"Key figure\"}", "[a]{.smallcaps}", "[a]{.underline}", "[a]{.mark}",
    "[a]{custom-style=\"Key\"}", "[a]{#sec-a}", "[a]{.strong}", "[a]{.cap}", "[a]{.em}", "[a]{.a}")
  # one paragraph per line, so each is its own block
  doc <- unlist(lapply(lines, function(l) c(l, "")), use.names = FALSE)
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "name", ext = e)
    # [a]{.num}-style (b) findings are not among these lines: only the `.num` on a value etc.
    expect_identical(x$text, character(), label = paste0("[", e, "] names listed: ", paste(x$text, collapse = " ")))
  }
})

test_that("3c L28 (c): every weft name changed by one edit, where the result is not a weft name, is listed", {
  cls <- unlist(lapply(setdiff(WEFT_CLASSES, c("p", "no", "or", "ul", "ol", "dl", "a", "em", "pct")), identity))
  mut_cls <- unique(unlist(lapply(cls, c3_mutants)))
  keys <- c("sign", "list", "cite", WEFT_KEYS_REND)
  mut_keys <- unique(unlist(lapply(keys, c3_mutants)))
  expect_gt(length(mut_cls), 10L)
  expect_gt(length(mut_keys), 10L)
  # a code span with an attribute block is no construct: only (c) can list it
  doc <- unlist(lapply(c(paste0("`x`{.", mut_cls, "}"), paste0("`x`{", mut_keys, "=\"v\"}")),
                      function(l) c(l, "")), use.names = FALSE)
  want <- c(paste0(".", mut_cls), mut_keys)
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "name", ext = e)
    expect_identical(sort(x$text), sort(want), label = paste0("[", e, "] mutants listed"))
    # each is listed with a weft name in the message
    all_names <- Filter(function(z) nchar(z) >= 3L, c(WEFT_KEYS_GOV, WEFT_KEYS_REND, WEFT_CLASSES))
    has_nearest <- vapply(x$message, function(m) any(vapply(all_names, function(nm) grepl(nm, m, fixed = TRUE), NA)), NA)
    expect_true(all(has_nearest), label = paste0("[", e, "] nearest weft name named"))
    expect_true(all(x$tier == 2L)); expect_true(all(x$spec == "5.3.3"))
  }
})

NAME_CASES <- list(
  # section 21 and the design's table
  list(src = "[1234]{.num}",                              want = ".num"),
  list(src = "`r x`{.Num}",                               want = ".Num"),
  list(src = r"---([add more]{iff="n > 10"})---",         want = "iff"),
  list(src = "[a]{.nmu}",                                 want = ".nmu"),
  list(src = "`x`{.nmu}",                                 want = ".nmu"),
  list(src = r"---(`x`{trunk="x"})---",                   want = "trunk"),
  list(src = r"---([a site | # sites]{count="k"})---",    want = "count"),
  list(src = "`r x`{.num .smallcaps}",                    want = character()),
  list(src = r"---([a | b]{If="x"})---",                  want = character()),
  list(src = "`x`{.r}",                                   want = character()),
  list(src = "`x`{.python}",                              want = character()),
  # (a) on a construct, a name that is none of the known ones
  list(src = r"---([a | b]{n="k" .zebra})---",            want = ".zebra"),
  list(src = "`r x`{.num .zebra}",                        want = ".zebra"),
  list(src = r"---(`r x`{.num zeta="1"})---",             want = "zeta"),
  list(src = "[a]{.strong .zebra}",                       want = ".zebra"),
  list(src = "`r x`{.zebra}",                             want = ".zebra"),
  # but not on a non-construct, far from any weft name
  list(src = "[a]{.zebra}",                               want = character()),
  list(src = "`x`{.zebra}",                               want = character()),
  list(src = "`x`{.numeric}",                             want = character()),
  list(src = "`x`{.highlight}",                           want = character()),
  # (b) a formatter class or renderer key on a bracket with no governor or marker key
  list(src = r"---([x]{digits="2"})---",                  want = "digits"),
  list(src = "[x]{.pct .smallcaps}",                      want = ".pct"),
  list(src = "[x]{.num .pct}",                            want = c(".num", ".pct")),
  list(src = "[x]{.strong .num}",                         want = ".num"),
  list(src = r"---([x]{.mark unit="m"})---",              want = "unit"),
  list(src = r"---([x]{n="k" .num})---",                  want = character()),   # a governor: the class formats the arm
  # (c) near misses, as classes and as keys
  list(src = "`x`{.nums}",                                want = ".nums"),
  list(src = "`x`{.Strong}",                              want = ".Strong"),
  list(src = "`x`{.NUM}",                                 want = ".NUM"),
  list(src = "`x`{.P}",                                   want = ".P"),         # case-only matches at any length
  list(src = "`x`{.A}",                                   want = ".A"),
  list(src = r"---(`x`{lst="a"})---",                     want = "lst"),
  list(src = r"---(`x`{unitt="a"})---",                   want = "unitt"),
  list(src = r"---(`x`{If="a"})---",                      want = character()),  # case-only key is the key
  list(src = r"---(`x`{DIGITS="2"})---",                  want = character()),
  list(src = "[a]{#sec-a}",                               want = character()),
  list(src = "[1]{.weft-literal why=\"SOP 12\"}",         want = character())
)

test_that("3c L28: name, each row of the design's table, section 21 and near misses (qmd and Rmd)", {
  expect_c3_cases(NAME_CASES, "name")
})

test_that("3c L28 K7: names of fewer than three characters are not compared by edit distance", {
  for (src in c("`x`{.nu}", "`x`{.ni}", "`x`{.q}", "`x`{.nm}", "[a]{.nu}", "[a]{.ro}", r"---(`x`{i="a"})---",
                r"---(`x`{sig="a"})---" )) {
    # "sig" has three characters (one edit from `sign`) and is the one that is listed
    want <- if (grepl("sig=", src, fixed = TRUE)) "sig" else character()
    expect_c3(c3_para(src), "name", want, label = src)
  }
})

test_that("3c L28: the message gives the nearest weft name", {
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(c3_para("`r x`{.Num}"), rules = "name", ext = e)
    r <- lf_one(x, "name", ".Num")
    expect_true(grepl(".num", sub(".Num", "", r$message, fixed = TRUE), fixed = TRUE))
    x <- lint_one(c3_para(r"---([add more]{iff="n > 10"})---"), rules = "name", ext = e)
    r <- lf_one(x, "name", "iff")
    expect_true(grepl("\\bif\\b", r$message))
    x <- lint_one(c3_para("[a]{.nmu}"), rules = "name", ext = e)
    r <- lf_one(x, "name", ".nmu")
    expect_true(grepl(".num", r$message, fixed = TRUE))
    x <- lint_one(c3_para(r"---(`x`{trunk="x"})---"), rules = "name", ext = e)
    expect_true(grepl("trunc", lf_one(x, "name", "trunk")$message, fixed = TRUE))
  }
})

test_that("3c L28: name has tier 2, spec 5.3.3, and the position of the name (with its dot for a class)", {
  x <- lint_one(c3_para("Ab `x`{.nmu} cd."), rules = "name")
  r <- lf_one(x, "name", ".nmu")
  expect_identical(r$tier, 2L)
  expect_identical(r$spec, "5.3.3")
  expect_identical(c(r$line, r$col), c(3L, 8L))
  expect_identical(r$context, "prose")
  expect_match(r$message, "(rule 5.3.3).", fixed = TRUE)
  x <- lint_one(c3_para(r"---(Ab [add more]{iff="n > 10"} cd.)---"), rules = "name")
  expect_identical(c(lf_one(x, "name", "iff")$line, lf_one(x, "name", "iff")$col), c(3L, 15L))
  # characters, not bytes
  x <- lint_one(c3_para("caf\u00e9 `x`{.nmu}"), rules = "name")
  expect_identical(lf_one(x, "name", ".nmu")$col, 10L)
})

test_that("3c L28: the same name on two lines is two findings; a repeat on one line at one place is one", {
  x <- lint_one(c("A `x`{.nmu}.", "", "B `x`{.nmu}."), rules = "name")
  expect_identical(lf_lines(x), c(1L, 3L))
  expect_identical(lf_texts(x), c(".nmu", ".nmu"))
})

test_that("3c L28: names in front matter and caption pieces are read", {
  x <- lint_one(c3_abstract(r"---(A [add more]{iff="n > 10"} thing.)---"), rules = "name")
  r <- lf_one(x, "name", "iff")
  expect_identical(r$context, "front-matter")
  expect_identical(r$line, 4L)
  cap <- c(c3_para("Intro."), c3_chunk("plot(1)", "#| label: fig-a", "#| fig-cap: |", "#|   Depth `x`{.nmu}."))
  x <- lint_one(cap, rules = "name")
  expect_identical(lf_one(x, "name", ".nmu")$context, "caption")
})

test_that("3c L28: names in code, comments and fences are not read", {
  expect_c3(c3_para("`` `x`{.nmu} ``"), "name", character())
  expect_c3(c3_para("<!-- `x`{.nmu} -->"), "name", character())
  expect_c3(c("T.", "", "```", "`x`{.nmu}", "```", "", "A."), "name", character())
  expect_c3(c(c3_para("T."), c3_chunk("s <- '`x`{.nmu}'")), "name", character())
})

test_that("3c L28 expected_names: a name the project expects is not listed (project and document level)", {
  # the project file
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(c3_para("`r x`{.zebra zeta=\"1\"} and `x`{.nmu}"), rules = "name", ext = e,
                  weft_yml = c("expected_names: ['.zebra', zeta, '.nmu']"))
    expect_identical(x$text, character(), label = e)
  }
  # without it they are listed
  x <- lint_one(c3_para("`r x`{.zebra zeta=\"1\"} and `x`{.nmu}"), rules = "name")
  expect_setequal(x$text, c(".zebra", "zeta", ".nmu"))
  # a document's front matter
  doc <- c("---", "title: T", "weft:", "  expected_names: ['.zebra']", "---", "", "A `r x`{.zebra} b `r y`{.other}.")
  x <- lint_one(doc, rules = "name")
  expect_identical(x$text, ".other")
  # a class and a key of the same spelling are different names: `.zebra` does not expect `zebra`
  x <- lint_one(c3_para("`r x`{zebra=\"1\"}"), rules = "name", weft_yml = "expected_names: ['.zebra']")
  expect_identical(x$text, "zebra")
})

test_that("3c L28: names are read on every construct kind (value, governed and marker spans)", {
  doc <- c3_para(r"---(`r x`{.zebra1} [a | b]{if="x" .zebra2} [a | b]{n="k" .zebra3})---",
                 r"---([a | b | c]{sign="k" .zebra4} [a | b]{list="k" .zebra5} [a]{cite="smith2020" .zebra6})---")
  x <- lint_one(doc, rules = "name")
  expect_setequal(x$text, paste0(".zebra", 1:6))
})

test_that("3c L28 and L26 on CRLF with a BOM and no final newline give the positions of a plain copy", {
  lines <- c("Head.", "", "A `x`{.nmu} [a | b]{.y}", "", "Tail [c]{iff=\"x\"}")
  plain <- lint_fixture(list("a.qmd" = lines), rules = c("name", "lone-bar"))
  odd <- lint_fixture(list("a.qmd" = list(lines = lines, eol = "\r\n", bom = TRUE, final_newline = FALSE)),
                      rules = c("name", "lone-bar"))
  expect_gte(nrow(plain), 3L)
  expect_identical(odd$text, plain$text)
  expect_identical(odd$line, plain$line)
  expect_identical(odd$col, plain$col)
})

test_that("3c L6: lint_rules() lists lone-bar, if-zero and name at tier 2", {
  lr <- lint_rules()
  for (id in c("lone-bar", "if-zero", "name")) {
    expect_true(id %in% lr$id, label = id)
    expect_identical(lr$tier[lr$id == id], 2L, label = paste("tier of", id))
    expect_identical(lr$spec[lr$id == id], "5.3.3")
  }
})
