# The weft-check Lua filter, driven directly through Pandoc (2.5.3, 2.9.5,
# 9.4.3). The package is never loaded in these runs and nothing is knit: the
# filter only ever sees Pandoc's AST (9.2.8).
#
# `pandoc --lua-filter` ends with status 1 when the filter calls os.exit(1);
# a Lua error would end with another status, so "fails" is tested as status 1.

fmt_classes <- c(".num", ".pct", ".sci", ".p", ".date", ".no", ".word", ".count",
                 ".ord", ".and", ".or", ".pairs", ".range", ".ul", ".ol", ".dl")

test_that("2.5.3: a span still carrying n, if, sign or cite fails, in any letter case", {
  cases <- list(
    n_key          = "Found [one site | # sites]{n=\"k\"} here.",
    if_key         = "It was [met | not met]{if=\"x > 5\"} here.",
    sign_key       = "It [rose | fell]{sign=\"d\"} here.",
    cite_key       = "A claim [with a source]{cite=\"smith\"} here.",
    N_upper        = "[a | b]{N=\"k\"}",
    If_mixed       = "[a | b]{If=\"x\"}",
    SIGN_upper     = "[a | b]{SIGN=\"x\"}",
    Cite_mixed     = "[a]{Cite=\"x\"}",
    iF_mixed       = "[a | b]{iF=\"x\"}",
    unquoted       = "[a | b]{n=k}",
    with_class     = "[# site | # sites]{.num n=\"k\"}",
    with_passthru  = "[a | b]{.smallcaps n=\"k\"}",
    key_after_pass = "[a | b]{custom-style=\"Key figure\" if=\"x\"}",
    inside_emph    = "*[a | b]{n=\"k\"}*",
    inside_strong  = "**a [b | c]{if=\"x\"}**",
    in_heading     = "# Heading [a | b]{n=\"k\"}",
    in_list        = "- item [a | b]{n=\"k\"}",
    in_quote       = "> quoted [a | b]{n=\"k\"}",
    in_link_text   = "[see [a | b]{n=\"k\"}](https://example.org)",
    in_table_cell  = c("| a |", "|---|", "| [a]{n=\"k\"} |")
  )
  expect_filter_fails(cases)
})

test_that("2.5.3, 1.1.5: a span still carrying a weft text class fails", {
  cases <- list(
    strong      = "A [result]{.strong} here.",
    em          = "A [result]{.em} here.",
    a           = "A [result]{.a} here.",
    cap         = "A [result]{.cap} here.",
    both        = "A [result]{.strong .em} here.",
    with_passthru = "A [result]{.strong .smallcaps} here.",
    in_heading  = "# A [result]{.em}",
    in_list     = "- A [result]{.strong}"
  )
  expect_filter_fails(cases)
})

test_that("2.5.3, 1.2.1: text that still shows an attribute block fails", {
  cases <- list(
    num           = "Depth is 12.5{.num} here.",
    pct           = "Share is 12%{.pct} here.",
    word          = "There were three{.word} sites.",
    with_key      = "Depth is 12.5{.num digits=2} here.",
    key_only      = "Depth is 12.5{digits=2} here.",
    governor_key  = "Depth is x{n=\"k\"} here.",
    in_heading    = "# Depth 12.5{.num} here",
    in_list       = "- Depth 12.5{.num}",
    in_table_cell = c("| a |", "|---|", "| 12.5{.num} |"),
    in_emphasis   = "*12.5{.num}*"
  )
  expect_filter_fails(cases)
})

test_that("2.5.3, 1.2.5: a code span carrying a weft class or key fails", {
  by_class <- setNames(sprintf("Depth `x`{%s} here.", fmt_classes),
                       paste0("class", fmt_classes))
  by_key <- c(
    digits = "Depth `x`{digits=2} here.",
    sigfig = "Depth `x`{sigfig=3} here.",
    sep    = "Depth `x`{sep=\"; \"} here.",
    last   = "Depth `x`{last=\" or \"} here.",
    trunc  = "Depth `x`{trunc=3} here.",
    n      = "Depth `x`{n=\"k\"} here.",
    `if`   = "Depth `x`{if=\"k\"} here.",
    sign   = "Depth `x`{sign=\"k\"} here.",
    cite   = "Depth `x`{cite=\"k\"} here.",
    N_upper = "Depth `x`{N=\"k\"} here.",
    with_other_class = "Depth `x`{.smallcaps .num} here."
  )
  text_class <- c(
    strong = "Depth `x`{.strong} here.",
    em     = "Depth `x`{.em} here."
  )
  expect_filter_fails(c(by_class, by_key, text_class))
})

test_that("2.5.3, 5.3.4: a code span with an attribute block and r-code text fails", {
  cases <- list(
    r_space_class   = "Depth `r depth`{.smallcaps} here.",
    r_space_key     = "Depth `r depth`{custom=\"x\"} here.",
    R_space_class   = "Depth `R depth`{.num} here.",
    R_space_other   = "Depth `R depth`{.smallcaps} here.",
    brace_r_class   = "Depth `{r} depth`{.num} here.",
    brace_r_other   = "Depth `{r} depth`{.smallcaps} here.",
    brace_r_nospace = "Depth `{r}depth`{.num} here."
  )
  expect_filter_fails(cases)
})

test_that("2.5.3, 5.3.4: any code span whose text begins `r ` fails, with no attribute block", {
  cases <- list(
    bare_r       = "Depth `r depth` here.",
    bare_r_call  = "Depth `r round(depth, 1)` here.",
    in_heading   = "# Depth `r depth`",
    in_list      = "- Depth `r depth`",
    in_table     = c("| a |", "|---|", "| `r depth` |")
  )
  expect_filter_fails(cases)
})

test_that("2.5.3: any leftover placeholder (private-use) character fails", {
  u <- function(...) intToUtf8(c(...))
  cases <- list(
    one         = paste0("Depth ", u(0xE001), " here."),
    run         = paste0("Depth ", u(0xE000, 0xE001, 0xE002), " here."),
    at_start    = paste0(u(0xE001), " Depth here."),
    in_heading  = paste0("# Depth ", u(0xE001)),
    in_list     = paste0("- Depth ", u(0xE001)),
    in_emphasis = paste0("*Depth ", u(0xE001), "*"),
    in_link     = paste0("[Depth ", u(0xE001), "](https://example.org)"),
    in_cell     = c("| a |", "|---|", paste0("| ", u(0xE001), " |"))
  )
  expect_filter_fails(cases)
})

test_that("2.5.3, 2.9.5, 2.6.8: the marker text <<weft: fails, wherever it is", {
  cases <- list(
    failed_claim = "Depth 12.5<<weft: failed claim, line 4>> here.",
    no_value     = "Depth <<weft: no value, line 4>> here.",
    value_error  = "Depth <<weft: value error, line 4>> here.",
    construct    = "Depth <<weft: construct error, line 4>> here.",
    chunk_marker = "Depth <<weft: failed claim, chunk fig-depth>> here.",
    bare         = "<<weft:",
    in_heading   = "# Depth <<weft: no value, line 4>>",
    in_list      = "- Depth <<weft: no value, line 4>>",
    in_quote     = "> Depth <<weft: no value, line 4>>",
    in_emphasis  = "*Depth <<weft: no value, line 4>>*",
    in_strong    = "**Depth <<weft: no value, line 4>>**",
    in_link_text = "[Depth <<weft: no value, line 4>>](https://example.org)",
    in_table     = c("| a |", "|---|", "| <<weft: no value, line 4>> |"),
    in_span      = "[Depth <<weft: no value, line 4>>]{.smallcaps}"
  )
  expect_filter_fails(cases)
})

test_that("2.5.3: the filter covers captions (figure and table)", {
  cases <- list(
    fig_span      = "![A depth of [a | b]{n=\"k\"}](img.png)",
    fig_text_span = "![A depth of [a]{.strong}](img.png)",
    fig_attr_text = "![A depth of 12.5{.num}](img.png)",
    fig_marker    = "![A depth of 12.5<<weft: failed claim, line 4>>](img.png)",
    fig_placeholder = paste0("![A depth of ", intToUtf8(0xE001), "](img.png)"),
    fig_code      = "![A depth of `x`{.num}](img.png)",
    tbl_span      = c("| a |", "|---|", "| 1 |", "", ": A depth of [a | b]{n=\"k\"}"),
    tbl_text_span = c("| a |", "|---|", "| 1 |", "", ": A depth of [a]{.em}"),
    tbl_attr_text = c("| a |", "|---|", "| 1 |", "", ": A depth of 12.5{.num} here"),
    tbl_marker    = c("| a |", "|---|", "| 1 |", "", ": A depth of <<weft: no value, line 4>>"),
    tbl_r_code    = c("| a |", "|---|", "| 1 |", "", ": A depth of `r depth`")
  )
  expect_filter_fails(cases)
})

test_that("2.5.3: clean documents pass (controls for every kind above)", {
  cases <- list(
    plain          = "Depth is 12.5 here, a plain paragraph.",
    smallcaps_span = "A [result]{.smallcaps} here.",
    pass_through   = "A [result]{.smallcaps custom-style=\"Key figure\"} here.",
    custom_class   = "A [result]{.mine} here.",
    custom_key     = "A [result]{lang=\"fr\"} here.",
    span_id        = "A [result]{#sp .smallcaps} here.",
    # 1.1.9: a formatter class on a bracket with no governor key is not weft's
    num_on_span    = "A [1234]{.num} here.",
    nonr_code      = "Use `x <- 1` and `rate` and `rx` and `r` here.",
    code_other_cls = "Use `x`{.smallcaps} and `y`{#cid .mine} here.",
    # only a code span with an attribute block is tested for `R ` and `{r}`
    bare_R_code    = "Write `R depth` here.",
    bare_brace_r   = "Write `{r} depth` here.",
    link           = "A [link](https://example.org) here.",
    link_attr      = "A [link](https://example.org){.external} here.",
    braces_in_text = "The set {1, 2, 3} and {a, b} here.",
    unicode        = "Minus −1.2 × 10^3^ and café and 1,234.5 here.",
    weft_word      = "The weft package, and weft: a word, here.",
    heading        = "# A heading\n\nand a paragraph",
    table          = c("| a | b |", "|---|---|", "| 1 | 2 |", "", ": A clean caption"),
    figure         = "![A clean caption](img.png)",
    bold_italic    = "**bold** and *italic* and ~~gone~~ here."
  )
  keep <- c(plain = "Depth is 12.5", smallcaps_span = "result", pass_through = "result",
            custom_class = "result", custom_key = "result", span_id = "result",
            num_on_span = "1234", nonr_code = "x <- 1", code_other_cls = "x",
            bare_R_code = "R depth", bare_brace_r = "{r} depth", link = "link",
            link_attr = "link", braces_in_text = "{1, 2, 3}",
            unicode = "café", weft_word = "weft package", heading = "A heading",
            table = "A clean caption", figure = "A clean caption",
            bold_italic = "bold")
  keep <- keep[names(cases)]
  expect_filter_passes(cases, keep)
})

test_that("2.5.3, 1.9: a fenced code block that shows weft syntax is not a code span", {
  cases <- list(
    fenced_attr  = c("```", "Depth `r depth`{.num} and [a | b]{n=\"k\"}", "```"),
    fenced_class = c("``` markdown", "[result]{.strong} 12.5{.num} `r x`", "```")
  )
  expect_filter_passes(cases, keep = c(fenced_attr = "depth", fenced_class = "result"))
})

test_that("2.5.3: a clean case beside each failing one gives the same exit status across kinds", {
  # a failing and a passing document differ in exit status only because of
  # the leftover, not because of anything else in the document
  base <- "A [clean]{.smallcaps} sentence, and `code`, and a [link](https://example.org)."
  pass <- run_filter(base)
  expect_identical(pass$status, 0L)
  for (leftover in c("[a | b]{n=\"k\"}", "12.5{.num}", "`r x`", "<<weft: no value, line 2>>",
                     "[x]{.strong}")) {
    fail <- run_filter(paste(base, leftover))
    expect_identical(fail$status, 1L, label = paste("status with", leftover))
  }
})

test_that("2.5.3: a failing run tells the author something on stderr", {
  r <- run_filter("Depth is 12.5{.num} here.")
  expect_identical(r$status, 1L)
  expect_true(nzchar(trimws(r$log)))
  expect_match(r$log, "weft", ignore.case = TRUE)
})

test_that("2.5.3, 9.2.8: it fails the same whether or not the file was ever knit", {
  # the document is plain markdown; no weft code has run and no weft package
  # is loaded in the child Pandoc process
  expect_identical(run_filter("Depth is `r depth`{.num} here.")$status, 1L)
  expect_identical(run_filter("Depth is 12.5 here.")$status, 0L)
})

# ---- draft mode (9.4.1, 9.4.3) ---------------------------------------------

draft_cases <- list(
  span   = "Found [one site | # sites]{n=\"k\"} here.",
  attr   = "Depth is 12.5{.num} here.",
  marker = "Depth 12.5<<weft: failed claim, line 4>> here.",
  code   = "Depth `r depth` here.",
  placeholder = paste0("Depth ", intToUtf8(0xE001), " here.")
)

test_that("9.4.3: with WEFT_DRAFT=1 the filter reports and does not fail", {
  for (nm in names(draft_cases)) {
    off <- run_filter(draft_cases[[nm]])
    expect_identical(off$status, 1L, label = paste("without draft,", nm))
    on <- run_filter(draft_cases[[nm]], env = c(WEFT_DRAFT = "1"))
    expect_identical(on$status, 0L, label = paste("with WEFT_DRAFT=1,", nm))
    expect_true(nzchar(trimws(on$log)), label = paste("it reports,", nm))
    expect_match(on$log, "weft", ignore.case = TRUE)
    expect_true(nzchar(on$text), label = paste("the document is still written,", nm))
  }
})

test_that("9.4.1, 9.4.3: draft: true in _weft.yml has the same effect", {
  for (nm in names(draft_cases)) {
    on <- run_filter(draft_cases[[nm]], files = list(`_weft.yml` = "draft: true"))
    expect_identical(on$status, 0L, label = paste("_weft.yml draft: true,", nm))
    expect_true(nzchar(trimws(on$log)), label = paste("it reports,", nm))
    off <- run_filter(draft_cases[[nm]], files = list(`_weft.yml` = "draft: false"))
    expect_identical(off$status, 1L, label = paste("_weft.yml draft: false,", nm))
  }
})

test_that("9.4.3: draft mode still passes a clean document, quietly", {
  on <- run_filter("A clean paragraph.", env = c(WEFT_DRAFT = "1"))
  expect_identical(on$status, 0L)
  expect_match(on$text, "A clean paragraph.", fixed = TRUE)
})

# ---- the collection file (2.9.5, 2.6.6) ------------------------------------

test_that("2.9.5: with WEFT_COLLECT set the filter appends to the file and does not exit", {
  dir <- tempfile("weft-collect-"); dir.create(dir)
  coll <- file.path(dir, "failures.jsonl")
  first <- "{\"kind\":\"failed claim\",\"file\":\"a.qmd\",\"line\":3}"
  writeLines(first, coll)
  for (nm in names(draft_cases)) {
    r <- run_filter(draft_cases[[nm]], env = c(WEFT_COLLECT = coll))
    expect_identical(r$status, 0L, label = paste("collecting,", nm))
  }
  lines <- readLines(coll, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  expect_identical(lines[1], first)
  expect_gte(length(lines), 1L + length(draft_cases))
  for (l in lines) {
    expect_true(!inherits(try(jsonlite::fromJSON(l), silent = TRUE), "try-error"),
                label = paste("a JSON line:", l))
  }
})

test_that("2.9.5: a clean document adds nothing to the collection file", {
  dir <- tempfile("weft-collect-"); dir.create(dir)
  coll <- file.path(dir, "failures.jsonl")
  file.create(coll)
  r <- run_filter("A clean [paragraph]{.smallcaps} with `code`.", env = c(WEFT_COLLECT = coll))
  expect_identical(r$status, 0L)
  expect_identical(length(readLines(coll, warn = FALSE)), 0L)
})

test_that("2.9.5: the document is still written while collecting", {
  dir <- tempfile("weft-collect-"); dir.create(dir)
  coll <- file.path(dir, "failures.jsonl")
  file.create(coll)
  r <- run_filter("Depth 12.5<<weft: failed claim, line 4>> here.", env = c(WEFT_COLLECT = coll))
  expect_identical(r$status, 0L)
  expect_match(r$text, "Depth 12.5", fixed = TRUE)
})
