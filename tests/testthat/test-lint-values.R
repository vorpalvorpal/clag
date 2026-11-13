# Package 3c: literal-value, inert-check, value-constant, value-format.
# Contract: dev/design-3.md L22-L25, K6, R5, 5.6, 3.1.6. Helpers: helper-3.R, helper-3c.R.

# ---- L22 literal-value -----------------------------------------------------------------

LIT_CASES <- list(
  # the design's own table
  list(src = "`r 10`",                                         want = "10"),
  list(src = "`r 2 * 5`",                                      want = "2 * 5"),
  list(src = "`r -3`{.num}",                                   want = "-3"),
  list(src = "`r \"ten\"`",                                    want = "\"ten\""),
  list(src = "`r 1e6`",                                        want = "1e6"),
  list(src = "$p = `r 0.02`$",                                 want = "0.02"),
  list(src = r"---([a site | # sites]{n="3"})---",             want = "3"),
  list(src = "`r pi`",                                         want = character()),
  list(src = "`r c(1, 2)`",                                    want = character()),
  list(src = "`r x`",                                          want = character()),
  list(src = r"---([a site | # sites]{n="#k"})---",            want = character()),
  list(src = "`r x +`",                                        want = character()),   # unparsable
  # every constant kind and every allowed operator
  list(src = "`r 5L`",                                         want = "5L"),
  list(src = "`r TRUE`",                                       want = "TRUE"),
  list(src = "`r NULL`",                                       want = "NULL"),
  list(src = "`r (1 + 2) * 3`",                                want = "(1 + 2) * 3"),
  list(src = "`r 7 %% 2`",                                     want = "7 %% 2"),
  list(src = "`r 7 %/% 2`",                                    want = "7 %/% 2"),
  list(src = "`r 2 ^ 3`",                                      want = "2 ^ 3"),
  list(src = "`r 10 / 4 - 1`",                                 want = "10 / 4 - 1"),
  list(src = "`r 1:3`",                                        want = "1:3"),
  list(src = "`r 1 == 1`",                                     want = "1 == 1"),
  list(src = "`r 1 != 2`",                                     want = "1 != 2"),
  list(src = "`r 1 < 2 | 3 >= 4`",                             want = "1 < 2 | 3 >= 4"),
  list(src = "`r TRUE && FALSE`",                              want = "TRUE && FALSE"),
  list(src = "`r !TRUE`",                                      want = "!TRUE"),
  list(src = "`r 10`{.pct .no}",                               want = "10"),
  # near misses: a symbol, a call, or a name makes it a computation
  list(src = "`r Inf`",                                        want = character()),
  list(src = "`r T`",                                          want = character()),
  list(src = "`r sqrt(4)`",                                    want = character()),
  list(src = "`r x + 1`",                                      want = character()),
  list(src = "`r 1 + x`",                                      want = character()),
  list(src = "`r pi * 2`",                                     want = character()),
  list(src = "`r max(1, 2)`",                                  want = character()),
  list(src = "`r n[1]`",                                       want = character())
)

test_that("3c L22: literal-value, each row of the design's table and its near misses (qmd and Rmd)", {
  expect_c3_cases(LIT_CASES, "literal-value")
})

test_that("3c L22: literal-value reads the Quarto form `{r} 10` as well as `r 10`", {
  expect_c3(c3_para("`{r} 10`"), "literal-value", "10", ext = "qmd")
  expect_c3(c3_para("`{r} x`"), "literal-value", character(), ext = "qmd")
})

test_that("3c L22 K6: literal n, sign and list expressions are literal values; `if` and `.` are not", {
  expect_c3(c3_para(r"---([a site | # sites]{n="3"})---"), "literal-value", "3")
  expect_c3(c3_para(r"---([rose | fell | held]{sign="2 * 5"})---"), "literal-value", "2 * 5")
  expect_c3(c3_para(r"---([a | b]{list="1:3"})---"), "literal-value", "1:3")
  # a back-reference and `.` are not expressions
  expect_c3(c3_para(r"---([a site | # sites]{n="#k"})---"), "literal-value", character())
  expect_c3(c3_para(r"---([a site | # sites]{n="."})---"), "literal-value", character())
  # an `if` condition is not a value (K6 extends 5.6.1 to n, sign, list only)
  expect_c3(c3_para(r"---([a]{if="TRUE"})---"), "literal-value", character())
  expect_c3(c3_para(r"---([a | b]{if="1 > 0"})---"), "literal-value", character())
  # a variable in the expression is a computation
  expect_c3(c3_para(r"---([a site | # sites]{n="k"})---"), "literal-value", character())
  expect_c3(c3_para(r"---([a site | # sites]{n="k + 1"})---"), "literal-value", character())
})

test_that("3c L22: literal-value has tier 1, the rule's spec, context prose and its position", {
  lines <- c3_para("Sites: `r 2 * 5` in all.")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "literal-value", ext = ext)
    expect_findings_shape(x)
    r <- lf_one(x, "literal-value", "2 * 5")
    expect_identical(r$tier, 1L)
    expect_true(r$spec %in% c("5.6.1", "5.6.3"))
    expect_identical(r$context, "prose")
    expect_identical(r$line, 3L)
    expect_identical(r$file, paste0("doc.", ext))
    expect_match(r$message, "\\(rule 5\\.6\\.[13]\\)\\.$")
    # the hint names the three ways out
    expect_false(is.na(r$hint))
    expect_match(r$hint, "weft-literal", fixed = TRUE)
  }
})

test_that("3c L22: line and column of a finding are where its text starts (expression, after `r `)", {
  lines <- c3_para("Ab `r 2 * 5` cd.")
  x <- lint_one(lines, rules = "literal-value")
  # ASSUMPTION (L5: 'where the finding's text starts'): the expression, not the backtick
  expect_identical(lf_pos(x, "literal-value"), c(line = 3L, col = 7L))
  # a value later on a line, and two on one line
  lines <- c3_para("One `r 10` and two `r 20`.")
  x <- lint_one(lines, rules = "literal-value")
  expect_identical(sort(lf_texts(x)), c("10", "20"))
  expect_identical(lf_pos(x, "literal-value", "10"), c(line = 3L, col = 8L))
  expect_identical(lf_pos(x, "literal-value", "20"), c(line = 3L, col = 23L))
  # characters, not bytes, before it
  lines <- c3_para("caf\u00e9 \u2014 `r 10`.")
  x <- lint_one(lines, rules = "literal-value")
  expect_identical(lf_pos(x, "literal-value"), c(line = 3L, col = 11L))
})

test_that("3c L22: literal-value in a caption, front matter, a weft_str() string and chunk code", {
  # caption of a chunk, block scalar (constructs allowed) and a bare value on the same line
  cap <- c(c3_para("Intro."),
           c3_chunk("plot(1)", "#| label: fig-a", "#| fig-cap: |", "#|   Depth `r 10`{.num} m.", "#| fig-alt: Alt."))
  x <- lint_one(cap, rules = "literal-value")
  r <- lf_one(x, "literal-value", "10")
  expect_identical(r$context, "caption")
  expect_identical(r$line, 9L)
  # a bare value in a plain-scalar caption (1.1.8: bare R is allowed there)
  cap2 <- c(c3_para("Intro."), c3_chunk("plot(1)", "#| label: fig-a", "#| fig-cap: Depth of `r 10` m"))
  expect_c3(cap2, "literal-value", "10")
  # the header form
  cap3 <- c(c3_para("Intro."), "```{r, fig.cap=\"Depth of `r 10` m\"}", "plot(1)", "```")
  expect_c3(cap3, "literal-value", "10")
  # front matter block scalar
  fm <- c3_abstract("We kept `r 10`{.num} sites.")
  x <- lint_one(fm, rules = "literal-value")
  r <- lf_one(x, "literal-value", "10")
  expect_identical(r$context, "front-matter")
  expect_identical(r$line, 4L)
  # a weft_str() string
  ws <- c(c3_para("Intro."), c3_chunk("lab <- weft_str(\"over `r 10`{.num} years\")"))
  x <- lint_one(ws, rules = "literal-value")
  r <- lf_one(x, "literal-value", "10")
  expect_identical(r$context, "weft_str")
  expect_identical(r$line, 7L)
  # a constant in ordinary chunk code is not a value row
  cc <- c(c3_para("Intro."), c3_chunk("x <- 10"))
  expect_c3(cc, "literal-value", character())
})

test_that("3c L22: literal-value ignores inline code that is not executed or not R", {
  # fenced non-executed block, indented code, HTML comment
  expect_c3(c("Text.", "", "```", "`r 10`", "```", "", "After."), "literal-value", character())
  expect_c3(c("Text.", "", "    `r 10` in indented code", "", "After."), "literal-value", character())
  expect_c3(c("Text.", "", "<!-- `r 10` -->", "", "After."), "literal-value", character())
  # an inline code span that is not R
  expect_c3(c3_para("The call `10` is code."), "literal-value", character())
  # an eval: false chunk is not executed: no weft_str() reading either
  ws <- c(c3_para("Intro."), c3_chunk("lab <- weft_str(\"over `r 10` years\")", "#| eval: false"))
  expect_c3(ws, "literal-value", character())
  # a python chunk's strings
  py <- c(c3_para("Intro."), c3_chunk("s = 'weft_str(\"`r 10`\")'", engine = "python"))
  expect_c3(py, "literal-value", character())
})

test_that("3c L22 R5: an exempt literal ([x]{.weft-literal why=..}) is not a value row", {
  expect_c3(c3_para(r"---([10]{.weft-literal why="SOP 12"})---"), "literal-value", character())
})

test_that("3c L22: findings come out for every row of a document, sorted by line then column", {
  lines <- c("A `r 10` b `r 20`.", "", "C `r 30`.")
  x <- lint_one(lines, rules = "literal-value")
  expect_identical(lf_texts(x), c("10", "20", "30"))
  expect_identical(lf_lines(x), c(1L, 1L, 3L))
  expect_false(is.unsorted(lf_cols(x)[1:2]))
})

test_that("3c L22: CRLF, a BOM and no final newline leave line and column as in a plain copy", {
  lines <- c("Title line.", "", "Value `r 2 * 5` here.", "", "Tail `r 9`")
  plain <- lint_fixture(list("a.qmd" = lines), rules = "literal-value")
  odd <- lint_fixture(list("a.qmd" = list(lines = lines, eol = "\r\n", bom = TRUE, final_newline = FALSE)),
                      rules = "literal-value")
  expect_identical(lf_texts(odd), lf_texts(plain))
  expect_identical(lf_lines(odd), lf_lines(plain))
  expect_identical(lf_cols(odd), lf_cols(plain))
  expect_gte(nrow(plain), 2L)
})

test_that("3c L22: code that does not parse gives no literal-value (the construct lint reports it)", {
  lines <- c3_para("`r 1 +`{.num} and `r (`")
  x <- lint_one(lines, rules = c("literal-value", "value-constant", "value-format", "inert-check"))
  expect_equal(nrow(x), 0L)
  y <- lint_one(lines, rules = "construct")
  expect_gte(nrow(y), 1L)
})

# ---- L23 inert-check ------------------------------------------------------------------

INERT_CASES <- list(
  list(src = "`r claim(x, TRUE)`",                      want = "TRUE"),
  list(src = "`r claim(x, 1 > 0)`",                     want = "1 > 0"),
  list(src = "`r claim(x, . > 0)`",                     want = character()),
  list(src = "`r claim(x, nrow(d) > 0)`",               want = character()),
  list(src = r"---([a]{if="TRUE"})---",                 want = "TRUE"),
  list(src = r"---([a|b]{if="1 > 0"})---",              want = "1 > 0", ext = "Rmd"),   # K6; a bare .qmd is the filter's (N143)
  list(src = r"---([a]{if="ok"})---",                   want = character()),
  list(src = r"---([a|b]{if="ok > 0"})---",             want = character()),
  list(src = "`r weft::claim(x, TRUE)`",                want = "TRUE"),
  list(src = "`r claim(x, . > 0, TRUE)`",               want = "TRUE"),        # each check on its own
  list(src = "`r claim(x, TRUE, FALSE)`",               want = c("FALSE", "TRUE")),
  list(src = "`r claim(x, . > 0, level = \"warn\")`",   want = character()),   # level is not a check
  list(src = "`r claim(x, TRUE, level = \"warn\")`",    want = "TRUE"),
  list(src = "`r claim(1, . > 0)`",                     want = character()),   # the first argument is not a check
  list(src = "`r claim(x, 5 > 2 & 3 > 1)`",             want = "5 > 2 & 3 > 1"),
  list(src = "`r claim(x, !is.na(.))`",                 want = character()),
  list(src = r"---([a]{if="pi > 3"})---",               want = character()),   # pi is a variable (all.vars)
  list(src = r"---([a]{sign="1 > 0"})---",              want = character())    # only `if` rows (b)
)

test_that("3c L23: inert-check, each row of the design's table and its near misses (qmd and Rmd)", {
  expect_c3_cases(INERT_CASES, "inert-check")
})

test_that("3c L23: inert-check has tier 1, spec 3.1.6, and the position of the check", {
  lines <- c3_para("See `r claim(x, TRUE)` now.")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "inert-check", ext = ext)
    r <- lf_one(x, "inert-check", "TRUE")
    expect_identical(r$tier, 1L)
    expect_identical(r$spec, "3.1.6")
    expect_identical(r$line, 3L)
    expect_identical(r$col, 17L)    # the check as written, after `claim(x, `
    expect_match(r$message, "(rule 3.1.6).", fixed = TRUE)
    expect_identical(r$context, "prose")
  }
  y <- lint_one(c3_para(r"---([a]{if="TRUE"})---"), rules = "inert-check")
  r <- lf_one(y, "inert-check", "TRUE")
  expect_identical(r$col, 9L)       # inside the quotes of the attribute value
})

test_that("3c L23: claim() in the code of executed R chunks, not of eval: false or non-R chunks", {
  doc <- function(chunk) c(c3_para("Intro."), chunk)
  # executed, option and header forms of eval
  expect_c3(doc(c3_chunk("y <- claim(x, TRUE)")), "inert-check", "TRUE")
  expect_c3(doc(c3_chunk("y <- weft::claim(x, 1 > 0)")), "inert-check", "1 > 0")
  expect_c3(doc(c3_chunk("y <- claim(x, . > 0)")), "inert-check", character())
  expect_c3(doc(c3_chunk("y <- claim(x, TRUE)", "#| eval: true")), "inert-check", "TRUE")
  # eval: false written literally: not read
  expect_c3(doc(c3_chunk("y <- claim(x, TRUE)", "#| eval: false")), "inert-check", character())
  expect_c3(doc(c("```{r, eval=FALSE}", "y <- claim(x, TRUE)", "```")), "inert-check", character())
  # not an R chunk
  expect_c3(doc(c3_chunk("y = claim(x, True)", engine = "python")), "inert-check", character())
  # context and line of a chunk finding
  x <- lint_one(doc(c3_chunk(c("a <- 1", "y <- claim(x, TRUE)"))), rules = "inert-check")
  r <- lf_one(x, "inert-check", "TRUE")
  expect_identical(r$context, "chunk")
  expect_identical(r$line, 8L)
  # a chunk that does not parse is skipped, not an error
  expect_c3(doc(c3_chunk(c("y <- claim(x, TRUE)", "z <- (", "claim(y, TRUE)"))), "inert-check", character())
})

test_that("3c L23: claim() in a governor expression", {
  expect_c3(c3_para(r"---([a site | # sites]{n="claim(k, TRUE)"})---"), "inert-check", "TRUE")
  expect_c3(c3_para(r"---([a | b]{if="claim(k, TRUE)"})---"), "inert-check", "TRUE")
  expect_c3(c3_para(r"---([a | b]{if="claim(k, . > 2)"})---"), "inert-check", character())
})

# ---- L24 value-constant -----------------------------------------------------------------

CONST_CASES <- list(
  list(src = "`r x * 100`",                  want = "100"),
  list(src = "`r x[2]`",                      want = "2"),
  list(src = "`r n - 1`",                     want = character()),
  list(src = "`r claim(n, . > 10)`",          want = character()),
  list(src = "`r round(x, 2)`",               want = character()),
  # 0 and 1 in any form are exempt
  list(src = "`r x + 0`",                     want = character()),
  list(src = "`r x * 1L`",                    want = character()),
  list(src = "`r x * 1.0`",                   want = character()),
  list(src = "`r x + 0L`",                    want = character()),
  list(src = "`r x + 0.0`",                   want = character()),
  # any other form is listed, as written
  list(src = "`r x * 1e3`",                   want = "1e3"),
  list(src = "`r x * 5L`",                    want = "5L"),
  list(src = "`r x * 0.5`",                   want = "0.5"),
  list(src = "`r x / 2.50`",                  want = "2.50"),
  list(src = "`r x ^ 2`",                     want = "2"),
  list(src = "`r x * -5`",                    want = "-5"),          # with its unary minus
  list(src = "`r d$a[3]`",                    want = "3"),
  list(src = "`r x[[4]]`",                    want = "4"),
  list(src = "`r mean(x) * 100 + 5`",         want = c("100", "5")),
  list(src = "`r x * 100`{.pct}",             want = "100"),
  list(src = "`r paste('a', x)`",             want = character()),   # a string is not a numeric constant
  # claim(): the checks are exempt, the first argument is not
  list(src = "`r claim(x * 100, . > 10)`",    want = "100"),
  list(src = "`r claim(x, . > 10, . < 20)`",  want = character()),
  # the later arguments of a call L25 names are exempt (named too), the first is not
  list(src = "`r round(x * 100, 2)`",         want = "100"),
  list(src = "`r round(x, digits = 2)`",      want = character()),
  list(src = "`r format(x, nsmall = 2)`",     want = character()),
  list(src = "`r signif(x, 3)`",              want = character()),
  list(src = "`r sprintf('%d', 7L)`",         want = character()),
  list(src = "`r round(2.5)`",                want = "2.5"),
  # a literal value is reported by literal-value only
  list(src = "`r 2 * 5`",                     want = character()),
  list(src = "`r 100`",                       want = character()),
  # other governors' expressions are not value rows
  list(src = r"---([a site | # sites]{n="k * 100"})---", want = character()),
  list(src = r"---([a]{if="x > 10"})---",     want = character())
)

test_that("3c L24: value-constant, each row of the design's table and its near misses (qmd and Rmd)", {
  expect_c3_cases(CONST_CASES, "value-constant")
})

test_that("3c L24: value-constant has tier 2, a spec, and the constant's own position", {
  lines <- c3_para("Total `r x * 100` here.")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "value-constant", ext = ext)
    r <- lf_one(x, "value-constant", "100")
    expect_identical(r$tier, 2L)
    expect_true(r$spec %in% c("5.6.2", "5.6.3"))
    expect_identical(r$line, 3L)
    expect_identical(r$col, 14L)
    expect_identical(r$context, "prose")
  }
  # two on one line
  x <- lint_one(c3_para("`r x * 100 + 5`"), rules = "value-constant")
  expect_identical(lf_texts(x), c("100", "5"))
  expect_identical(lf_lines(x), c(3L, 3L))
  expect_true(lf_cols(x)[1] < lf_cols(x)[2])
})

test_that("3c L24: value-constant in math, captions, front matter and weft_str() strings", {
  expect_c3(c3_para("$s = `r x * 100`$"), "value-constant", "100")
  cap <- c(c3_para("Intro."), c3_chunk("plot(1)", "#| label: fig-a", "#| fig-cap: Depth `r x * 1e3` m"))
  x <- lint_one(cap, rules = "value-constant")
  r <- lf_one(x, "value-constant", "1e3")
  expect_identical(r$context, "caption")
  fm <- c3_abstract("A share of `r x * 100`{.pct}.")
  x <- lint_one(fm, rules = "value-constant")
  expect_identical(lf_one(x, "value-constant", "100")$context, "front-matter")
  ws <- c(c3_para("Intro."), c3_chunk("lab <- weft_str(\"over `r x * 100`{.num} years\")"))
  x <- lint_one(ws, rules = "value-constant")
  expect_identical(lf_one(x, "value-constant", "100")$context, "weft_str")
  # not in ordinary chunk code, an eval: false chunk's strings, or an unparsable chunk
  expect_c3(c(c3_para("Intro."), c3_chunk("y <- x * 100")), "value-constant", character())
  expect_c3(c(c3_para("Intro."),
              c3_chunk("lab <- weft_str(\"`r x * 100`\")", "#| eval: false")), "value-constant", character())
})

# ---- L25 value-format -----------------------------------------------------------------

FMT_CASES <- list(
  list(src = "`r round(x, 2)`",                  want = "round"),
  list(src = "`r signif(x, 3)`",                  want = "signif"),
  list(src = "`r format(x, nsmall = 2)`",         want = "format"),
  list(src = "`r formatC(x, digits = 2)`",        want = "formatC"),
  list(src = "`r prettyNum(x, big.mark = ',')`",  want = "prettyNum"),
  list(src = "`r sprintf('%.1f', x)`",            want = "sprintf"),
  list(src = "`r (round(x))`",                    want = "round"),            # parentheses removed
  list(src = "`r ((sprintf('%d', n)))`",          want = "sprintf"),
  list(src = "`r claim(round(x, 1), . > 0)`",     want = "round"),            # claim() looked through
  list(src = "`r weft::claim(format(x), . > 0)`", want = "format"),
  list(src = "`r base::round(x, 2)`",             want = "round"),            # base:: removed
  list(src = "`r claim(base::signif(x), . > 0)`", want = "signif"),
  list(src = "`r round(x, 2)`{.num}",             want = "round"),
  list(src = "`r mean(round(x))`",                want = character()),        # outermost is mean
  list(src = "`r round(x) + 1`",                  want = character()),        # outermost is `+`
  list(src = "`r rounded(x)`",                    want = character()),
  list(src = "`r round`",                         want = character()),        # a symbol, not a call
  list(src = "`r x`",                             want = character()),
  list(src = "`r paste(round(x))`",               want = character())
)

test_that("3c L25: value-format, each function, each wrapper and its near misses (qmd and Rmd)", {
  expect_c3_cases(FMT_CASES, "value-format")
})

test_that("3c L25: value-format has tier 2, spec 5.6.4, a hint, and the function name's position", {
  lines <- c3_para("Ab `r round(x, 2)` cd.")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "value-format", ext = ext)
    r <- lf_one(x, "value-format", "round")
    expect_identical(r$tier, 2L)
    expect_identical(r$spec, "5.6.4")
    expect_identical(r$line, 3L)
    expect_identical(r$col, 7L)
    expect_false(is.na(r$hint))
    expect_match(r$message, "(rule 5.6.4).", fixed = TRUE)
  }
  x <- lint_one(c3_para("`r claim(base::signif(x), . > 0)`"), rules = "value-format")
  expect_identical(lf_texts(x), "signif")
})

test_that("3c L25: value-format in a caption, front matter and a weft_str() string; not in chunk code", {
  cap <- c(c3_para("Intro."), c3_chunk("plot(1)", "#| label: fig-a", "#| fig-cap: Depth `r round(x, 1)` m"))
  expect_c3(cap, "value-format", "round")
  expect_c3(c3_abstract("About `r format(x)`{.num} sites."), "value-format", "format")
  ws <- c(c3_para("Intro."), c3_chunk("lab <- weft_str(\"over `r sprintf('%d', n)` years\")"))
  expect_c3(ws, "value-format", "sprintf")
  expect_c3(c(c3_para("Intro."), c3_chunk("y <- round(x, 2)")), "value-format", character())
  expect_c3(c(c3_para("Intro."), c3_chunk("lab <- weft_str(\"`r round(x)`\")", "#| eval: false")),
            "value-format", character())
})

test_that("3c L25 K6: a value with round() and a constant gives both lints, each at its own place", {
  x <- lint_one(c3_para("`r round(x * 100, 2)`"), rules = c("value-format", "value-constant", "literal-value"))
  expect_identical(sort(paste(x$rule, x$text)), c("value-constant 100", "value-format round"))
})

# ---- tiers: what tier = 1 and tier = 2 return --------------------------------------------------

test_that("3c: tier 1 returns the 3c tier-1 rules only, tier 2 the tier-2 rules only", {
  lines <- c3_para("`r 10` and `r x * 100` and `r round(x)` and `r claim(x, TRUE)`.")
  t1 <- lint_one(lines, tier = 1L)
  t2 <- lint_one(lines, tier = 2L)
  expect_true(all(t1$tier == 1L))
  expect_true(all(t2$tier == 2L))
  expect_true("literal-value" %in% t1$rule)
  expect_true("inert-check" %in% t1$rule)
  expect_false(any(c("value-constant", "value-format") %in% t1$rule))
  expect_true(all(c("value-constant", "value-format") %in% t2$rule))
  expect_false(any(c("literal-value", "inert-check") %in% t2$rule))
  # the default of lints() is tier 1
  root <- lint_proj(list("a.qmd" = lines))
  expect_false(any(lints(root)$rule %in% c("value-constant", "value-format")))
})

test_that("3c L6: lint_rules() lists each 3c lint of this file at the design's tier", {
  lr <- lint_rules()
  for (id in c("literal-value", "inert-check", "value-constant", "value-format")) {
    expect_true(id %in% lr$id, label = id)
    expect_identical(lr$tier[lr$id == id], unname(R3C_TIER[[id]]), label = paste("tier of", id))
  }
})

test_that("3c L22-L25: the spec of a finding equals lint_rules()'s spec for the rule, or the design's pair", {
  lr <- lint_rules()
  x <- lint_one(c3_para("`r 10`, `r x * 100`, `r round(x)`, `r claim(x, TRUE)`"))
  for (id in c("literal-value", "value-constant", "value-format", "inert-check")) {
    sp <- unique(x$spec[x$rule == id])
    expect_length(sp, 1L)
    expect_true(sp %in% c(lr$spec[lr$id == id], strsplit(lr$spec[lr$id == id], "[, ]+")[[1]]),
                label = paste("spec of", id))
  }
})
