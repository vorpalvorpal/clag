# Regression tests for the review of stages 1b and 1d (dev/review-1b.md),
# as ruled in dev/design-1b.md ("Rulings on the review of stages 1b and 1d").
# Written test-first: each test fails on the code as reviewed and holds the
# rule or ruling it checks in its description. Findings 21, 26 and 27, the
# brk() character-value ruling, and items A, E, F, K and L are not here.
#
# Function forms and weft:::scan_text() where the finding allows; documents are
# knitted in this process (format = "knit"), so the output is what weft wrote
# and last_knit() is there to read. Helpers: helper-render.R, helper-1b.R.

d_sc <- function(x) weft:::scan_text(x)

# an error of weft's own (a class starting "weft_"), not a plain simpleError
d_weft_error <- function(expr, class = NULL, label = deparse(substitute(expr))) {
  e <- tryCatch({ force(expr); NULL }, error = function(e) e)
  testthat::expect_false(is.null(e), label = paste("an error is raised:", label))
  if (is.null(e)) return(invisible(NULL))
  testthat::expect_true(any(grepl("^weft_", class(e))),
                        label = paste("a weft_* class, not", class(e)[1], ":", label))
  if (!is.null(class)) {
    testthat::expect_true(inherits(e, class), label = paste("class", class, ":", label))
  }
  invisible(e)
}

d_mark <- function(tag, kind) paste0("^", tag, " .*<<weft: ", kind, ", line @L@>>")

# ---- 1: clamp() prints its bound as written (3.5.1) -------------------------------------------

test_that("review D #1: clamp() prints a small bound as written, not as < 0.0 (3.5.1)", {
  x <- clamp(0.005, floor = 0.01)
  expect_equal(b_txt(x), "< 0.01")
  r <- b_rec(x)
  expect_equal(r$relation, "<")
  expect_equal(r$number, 0.01)
  expect_match(b_txt(clamp(-0.004, floor = -0.001)), "^< .*0\\.001$")
  expect_match(b_txt(fmt_range(clamp(c(0.001, 5), floor = 0.01))), "0\\.01")
  # controls
  expect_equal(b_txt(clamp(150, 1, 99)), "> 99")
  expect_equal(b_txt(clamp(0.5, 1)), "< 1")
  expect_equal(b_txt(clamp(5, 1, 99)), "5")
})

# ---- 2: a number class after clamp() formats the bound, keeps the relation ------------------

test_that("review D #2: a number-stage class after clamp() formats the bound and keeps the relation (3.5.4, ruling)", {
  a <- fmt_pct(clamp(0.005, floor = 0.01))
  expect_equal(b_txt(a), "< 1%")
  expect_equal(b_rec(a)$relation, "<")
  b <- fmt_pct(clamp(0.5, ceiling = 0.4))
  expect_equal(b_txt(b), "> 40%")
  expect_equal(b_rec(b)$relation, ">")
  n <- fmt_num(clamp(0.005, floor = 0.01))
  expect_equal(b_rec(n)$relation, "<")
  expect_match(b_txt(n), "^<")
  expect_equal(b_rec(fmt_sci(clamp(0.005, floor = 0.01)))$relation, "<")
  # control: inside the bounds the class prints the value
  expect_equal(b_txt(fmt_pct(clamp(0.5, 0.1, 0.9))), "50%")
  expect_equal(b_rec(fmt_pct(clamp(0.5, 0.1, 0.9)))$relation, "=")
})

# ---- 3: a formatter on a phrase is a value error (1.4.1, 1.4.12, ruling) --------------------------

test_that("review D #3: a number or wording class on of_n(), about(), ci() or pm() is a value error (function form)", {
  d_weft_error(fmt_word(of_n(3, 7, "site", "sites")), "weft_value_error")
  d_weft_error(fmt_num(of_n(3, 7, "site", "sites")), "weft_value_error")
  d_weft_error(fmt_pct(of_n(3, 7, "site", "sites")), "weft_value_error")
  d_weft_error(fmt_no(of_n(0, 7, "site", "sites")), "weft_value_error")
  d_weft_error(fmt_num(ci(2.1, 1.3, 2.9)), "weft_value_error")
  d_weft_error(fmt_word(pm(2.1, 0.3)), "weft_value_error")   # already so: control
  d_weft_error(fmt_num(about(0.49)), "weft_value_error")      # already so: control
  # controls: text classes act on a phrase as on any text
  expect_equal(b_txt(fmt_strong(of_n(3, 7, "site", "sites"))), "**3 of the 7 sites**")
  expect_equal(b_txt(fmt_cap(about(0.49))), "Nearly half")
})

P3_ROWS <- list(
  b_row("P01", "`r of_n(3, 7, 'site', 'sites')`{.word} y", "1.4.1: .word on of_n()",
        rx = d_mark("P01", "value error")),
  b_row("P02", "`r of_n(3, 7, 'site', 'sites')`{.num} y", "1.4.1: .num on of_n()",
        rx = d_mark("P02", "value error")),
  b_row("P03", "`r of_n(3, 7, 'site', 'sites')`{.pct} y", "1.4.1: .pct on of_n()",
        rx = d_mark("P03", "value error")),
  b_row("P04", "`r of_n(0, 7, 'site', 'sites')`{.no} y", "1.4.1: .no on of_n()",
        rx = d_mark("P04", "value error")),
  b_row("P05", "`r ci(2.1, 1.3, 2.9)`{.num} y", "1.4.1: .num on ci()",
        rx = d_mark("P05", "value error")),
  b_row("P06", "`r pm(2.1, 0.3)`{.word} y", "control: .word on pm() is already a value error",
        rx = d_mark("P06", "value error")),
  b_row("C01", "`r of_n(3, 7, 'site', 'sites')`{.strong} y", "control: a text class on of_n()",
        want = "C01 **3 of the 7 sites** y"),
  b_row("C02", "`r ci(2.1, 1.3, 2.9)`{.strong} y", "control: a text class on ci()",
        want = "C02 **2.1 (95% CI 1.3 to 2.9)** y"),
  # 1.4.5 / ruling: .a takes a negative number and an emphasised number
  b_row("A01", "`r -8`{.a} y", "ruling: .a accepts a negative number",
        want = paste0("A01 a ", B_MINUS, "8 y")),
  b_row("A02", "[**8**]{.a .cap} y", "1.4.5 + design: .a .cap on an emphasised number",
        rx = "^A02 \\**An .*8.* y$")
)

test_that("review D #3, #16: the same in a document (draft markers), and .a on an emphasised or negative number", {
  b <- b_body(P3_ROWS)
  res <- render_rmd(b$lines, code = PRE_B, env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  b_need(res)
  b_check_lines(res, b, P3_ROWS, "rmarkdown")
})

# ---- 4, 5: a list value inside a container is a construct error that says so (ruling) -------------

test_that("review D #4: a list formatter in an indented block of a list item is a construct error", {
  for (cls in c(".ol", ".ul", ".dl")) {
    bad <- sprintf("1. First\n\n    `r v`{%s}\n\n2. Second", cls)
    b_expect_scan_error(bad, sprintf("1. First\n\n`r v`{%s}\n\n2. Second", cls), label = cls)
  }
})

test_that("review D #5: a list value alone in a list item, block quote or table cell is a construct error that names the container", {
  items <- c(item = "- `r v`{.ul}", quote = "> `r v`{.ul}",
             table = "| a |\n|---|\n| `r v`{.ul} |\n")
  for (nm in names(items)) {
    e <- b_expect_scan_error(items[[nm]], label = nm)
    expect_match(paste(e, collapse = " "), "list item|block quote|table|cell|container", ignore.case = TRUE,
                 label = paste("the message names the container:", nm))
  }
  # control: alone in a paragraph of its own, at the top level
  expect_identical(b_errs("Sites:\n\n`r v`{.ul}\n\nThen."), character())
})

# ---- 6 + ruling I: text classes and trunc on a list formatter ------------------------------------

test_that("review D #6 + ruling I: a text class or trunc together with .ul, .ol or .dl is a construct error", {
  for (bad in c("`r v`{.ol .strong}", "`r v`{.ul trunc=\"2\"}", "`r v`{.ul .cap}", "`r v`{.ul .a}",
                "`r v`{.dl .em}", "`r v`{.ol .cap}")) {
    b_expect_scan_error(bad, label = bad)
  }
  # controls: a list alone, a number class with a list, a text class on a plain value
  expect_identical(b_errs("`r v`{.ul}"), character())
  expect_identical(b_errs("`r v`{.num .ul}"), character())
  expect_identical(b_errs("`r v`{.strong}"), character())
})

# ---- 7: ids across a knitr child document (1.7.5, 1.7.10, ruling) ---------------------------------

test_that("review D #7: a parent reference to an id defined in a child is not an error (ids over the document as knitted)", {
  res <- render_rmd(
    c("Para.", "", "```{r, child=\"child2.Rmd\"}", "```", "", "After child [#]{n=\"#cid\"}."),
    code = PRE_B, format = "knit", in_process = TRUE,
    files = list("child2.Rmd" = "Child defines `r k`{#cid} here."))
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_match(res$md, "After child 3", fixed = TRUE)
})

test_that("review D #7: a child's reference to an id defined earlier in the parent is not an error", {
  res <- render_rmd(
    c("Parent defines `r k`{#pid} here.", "", "```{r, child=\"child3.Rmd\"}", "```"),
    code = PRE_B, format = "knit", in_process = TRUE,
    files = list("child3.Rmd" = "Child refers [#]{n=\"#pid\"}."))
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_match(res$md, "Child refers 3", fixed = TRUE)
})

test_that("review D #7: an id defined in both parent and child is a duplicate construct error", {
  res <- render_rmd(
    c("Para `r k`{#cid}.", "", "```{r, child=\"child4.Rmd\"}", "```"),
    code = PRE_B, format = "knit", in_process = TRUE,
    files = list("child4.Rmd" = "Child defines `r k`{#cid} here."))
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "cid")
  # control: distinct ids across the child do not fail
  ok <- render_rmd(
    c("Para `r k`{#pid}.", "", "```{r, child=\"child5.Rmd\"}", "```"),
    code = PRE_B, format = "knit", in_process = TRUE,
    files = list("child5.Rmd" = "Child defines `r k`{#cid} here."))
  expect_false(ok$failed, label = substr(ok$message, 1, 300))
})

# ---- 8: ids in captions share the document's id space (1.7.5, 1.7.10) ----------------------------

test_that("review D #8: a caption reference to a prose id, and a prose reference to a caption id, are not errors", {
  src <- c("Prose `r k`{#a}.", "",
           "```{r c1, fig.cap=\"Cap [#]{n=\\\"#a\\\"} and `r k`{#b}\"}", "plot(1)", "```", "",
           "Then [#]{n=\"#b\"}.")
  res <- render_rmd(src, code = PRE_B, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = substr(res$message, 1, 400))
  expect_match(res$md, "Cap 3 and 3", fixed = TRUE)
  expect_match(res$md, "Then 3", fixed = TRUE)
})

test_that("review D #8: an id in a caption that repeats a prose id is a duplicate construct error", {
  src <- c("Prose `r k`{#x}.", "",
           "```{r c1, fig.cap=\"Cap `r k`{#x}\"}", "plot(1)", "```")
  res <- render_rmd(src, code = PRE_B, format = "knit", in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "#?x\\b")
  # control: the same prose twice is already reported (the second use)
  dup <- render_rmd(c("Prose `r k`{#x}.", "", "Again `r k`{#x}."), code = PRE_B, format = "knit", in_process = TRUE)
  expect_true(dup$failed)
})

# ---- 9: a reference to an id whose value failed (ruling) -------------------------------------------

test_that("review D #9: a back-reference to an id whose value failed is a collected no-value failure naming the id, not a construct error", {
  src <- c("A `r nosuch`{#q} here.", "", "Then [#]{n=\"#q\"}.", "",
           "Control `r k`{#okid} and [#]{n=\"#okid\"}.")
  res <- render_rmd(src, code = PRE_B, format = "knit", in_process = TRUE)
  expect_true(res$failed)
  expect_false("weft_construct_error" %in% res$error$class)
  expect_true("weft_failures" %in% res$error$class)
  f <- res$knit$failures
  at_ref <- f[f$line == res$offset + 3L, ]
  expect_gte(nrow(at_ref), 1L)
  expect_true("no value" %in% at_ref$kind)
  expect_match(paste(at_ref$detail, at_ref$expr, collapse = " "), "q")
  # the control's line is not among the failures
  expect_false(any(f$line == res$offset + 5L))
})

# ---- 10, 11, 24: the bibliography check (1.8.5, 5.4.4, 5.4.5) -------------------------------------------

D_BIB <- c(
  "@comment{This mentions @article{commented2020, title={x}} inside a comment}",
  "@article{smith2020,",
  "  title = {Smith with an embedded @misc{fieldkey2020, x} in a field},",
  "  author = {Smith, Anna}, journal = {J}, year = {2020}}",
  "@misc{ké2021, title = {Unicode}, author = {U, A}, year = {2021}}"
)
D_BIB_ROWS <- list(
  b_row("K01", "[x]{cite=\"@commented2020\"} end.", "1.8.5: a key inside a @comment block is not a key",
        rx = "^K01 x.*<<weft: unknown key, line @L@>>"),
  b_row("K02", "[x]{cite=\"@fieldkey2020\"} end.", "1.8.5: a key inside a field value is not a key",
        rx = "^K02 x.*<<weft: unknown key, line @L@>>"),
  b_row("K03", "[x]{cite=\"@smith2020\"} end.", "control: a real key", want = "K03 x [@smith2020] end."),
  b_row("K04", "[x]{cite=\"@ké2021\"} end.", "1.8.6: a non-ASCII key, citation form",
        want = "K04 x [@ké2021] end."),
  b_row("K05", "[x]{cite=\"ké2021\"} end.", "1.8.4: a non-ASCII key, bare form", want = "K05 x end.")
)

test_that("review D #10: keys inside @comment blocks and field values are not in the bibliography", {
  b <- b_body(D_BIB_ROWS)
  res <- render_rmd(b$lines, code = PRE_B, front = "bibliography: refs.bib", files = list("refs.bib" = D_BIB),
                    env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  b_need(res)
  b_check_lines(res, b, D_BIB_ROWS[1:3], "rmarkdown")
})

test_that("review D #11: a non-ASCII key resolves, in the citation form and in the bare form", {
  b <- b_body(D_BIB_ROWS)
  res <- render_rmd(b$lines, code = PRE_B, front = "bibliography: refs.bib", files = list("refs.bib" = D_BIB),
                    env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  b_need(res)
  b_check_lines(res, b, D_BIB_ROWS[4:5], "rmarkdown")
  # the bare form is no construct error from the source either
  expect_identical(b_errs("[x]{cite=\"ké2021\"}"), character())
  expect_identical(b_errs("[x]{cite=\"@ké2021\"}"), character())
})

test_that("review D #24: a bibliography file that does not exist is named in the report (_weft.yml and front matter)", {
  src <- c("See [x]{cite=\"@smith2020\"} end.")
  a <- render_rmd(src, code = PRE_B, files = list("_weft.yml" = "bibliography: nofile.bib"),
                  env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  b_need(a)
  expect_match(paste(c(a$knit$failures$detail, a$log), collapse = " "), "nofile.bib", fixed = TRUE)
  b <- render_rmd(src, code = PRE_B, front = "bibliography: gone.bib",
                  env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  b_need(b)
  expect_match(paste(c(b$knit$failures$detail, b$log), collapse = " "), "gone.bib", fixed = TRUE)
})

# ---- 12, 13, 14: .weft-literal divs and ids (1.1.6, 1.8.9 to 1.8.11) -----------------------------------

test_that("review D #12: a .weft-literal div inside a block quote is seen (no why is a construct error)", {
  b_expect_scan_error("> ::: {.weft-literal}\n> Quote.\n> :::",
                      "> ::: {.weft-literal why=\"w\"}\n> Quote.\n> :::")
  r <- d_sc("> ::: {.weft-literal why=\"w\"}\n> Quote.\n> :::")
  expect_equal(sum(r$kind == "literal"), 1L)
})

test_that("review D #13: a .weft-literal div in Pandoc's bare-class or trailing-colon form is seen", {
  b_expect_scan_error("::: weft-literal\nText.\n:::")
  b_expect_scan_error("::: {.weft-literal} ::::\nText.\n::::")
  r <- d_sc("::: {.weft-literal why=\"a\"} ::::\nText.\n::::")
  expect_equal(sum(r$kind == "literal"), 1L)
  # control: the braces form with a why is clean
  expect_identical(b_errs("::: {.weft-literal why=\"a\"}\nText.\n:::"), character())
})

D_LIT_CASES <- c(
  "> ::: {.weft-literal why=\"in quote\"}\n> Quote div `r k`{.word}.\n> :::",
  "::: {#did .weft-literal why=\"with id\"}\nDiv text.\n:::",
  "[y]{.weft-literal why=\"ok\" .smallcaps #lid} tail",
  "::: {.weft-literal why=\"a\"} ::::\nTrailing colons.\n::::",
  "::: {.weft-literal why=\"ctl\"}\nControl div.\n:::"
)

d_literal_out <- function() {
  res <- render_rmd(batch_cases(D_LIT_CASES), code = PRE_B, format = "knit", in_process = TRUE)
  b_need(res)
  unlist(split_cases(res, length(D_LIT_CASES)))
}

test_that("review D #12: the why is removed from a literal div inside a block quote (1.8.11)", {
  out <- d_literal_out()
  expect_false(grepl("why=", out[1], fixed = TRUE))
  expect_match(out[1], "weft-literal")
  # controls: the plain div and the trailing-colon div lose their why
  expect_false(grepl("why=", out[5], fixed = TRUE))
  expect_match(out[5], "::: {.weft-literal}", fixed = TRUE)
})

test_that("review D #13: the why is removed from a literal div with trailing colons (1.8.11)", {
  out <- d_literal_out()
  expect_false(grepl("why=", out[4], fixed = TRUE))
  expect_match(out[4], "weft-literal")
})

test_that("review D #14: a literal div or span keeps its #id (1.1.6: the runtime removes the why and nothing else)", {
  out <- d_literal_out()
  expect_match(out[2], "#did", fixed = TRUE)
  expect_false(grepl("why=", out[2], fixed = TRUE))
  expect_match(out[3], "#lid", fixed = TRUE)
  expect_false(grepl("why=", out[3], fixed = TRUE))
  expect_match(out[3], ".smallcaps", fixed = TRUE)
})

# ---- 15, ruling B: .a and .date under a language weft does not ship (1.6.8) ------------------------

LANG_D_ROWS <- list(
  b_row("A01", "[3 sites]{.a} y", "1.6.8: .a on a text span", rx = d_mark("A01", "construct error")),
  b_row("A02", "[x]{.a cite=\"@a\"} y", "1.6.8: .a on a cite span", rx = d_mark("A02", "construct error")),
  b_row("A03", "[x]{.a if=\"flag\"} y", "1.6.8: .a on an if span", rx = d_mark("A03", "construct error")),
  b_row("D01", "`r d1date`{.date} y", "ruling B: .date under a language weft does not ship",
        rx = d_mark("D01", "construct error")),
  b_row("D02", "[x | y]{.date n=\"k\"} y", "ruling B: .date on a span", rx = d_mark("D02", "construct error")),
  b_row("A04", "`r k`{.a} y", "control: .a on a value is already a construct error",
        rx = d_mark("A04", "construct error")),
  b_row("N01", "[3 sites]{.strong} y", "control: .strong prints no words", want = "N01 **3 sites** y"),
  b_row("N02", "`r d1date`{.strong} y", "control: no date class", rx = "^N02 [^<]* y$")
)

test_that("review D #15 + ruling B: under lang: fr, .a on a text, cite or if span and .date are construct errors", {
  b <- b_body(LANG_D_ROWS)
  res <- render_rmd(b$lines, code = PRE_B, front = "lang: fr", env = c(WEFT_DRAFT = "1"),
                    format = "knit", in_process = TRUE)
  b_need(res)
  b_check_lines(res, b, LANG_D_ROWS, "rmarkdown")
})

# ---- 16: .a on a negative number (1.4.5, ruling) ----------------------------------------------------------

test_that("review D #16: .a accepts a negative number and an emphasised number", {
  expect_equal(b_txt(fmt_a(-5)), paste0("a ", B_MINUS, "5"))
  expect_equal(b_txt(fmt_a(-8)), paste0("a ", B_MINUS, "8"))
  expect_match(b_txt(fmt_a(fmt_strong(8))), "^\\**an \\**8")
  # controls
  expect_equal(b_txt(fmt_a(8)), "an 8")
  expect_equal(b_txt(fmt_a(5)), "a 5")
  d_weft_error(fmt_a("apple"), "weft_value_error")
})

# ---- 17 + ruling D: .cap skips leading marks, punctuation, quotes, brackets --------------------------------

test_that("review D #17: .cap capitalises past _, ~~, a link's [, quotation marks and brackets (ruling D)", {
  expect_equal(b_txt(fmt_cap("_hi_")), "_Hi_")
  expect_equal(b_txt(fmt_cap("[link](u)")), "[Link](u)")
  expect_equal(b_txt(fmt_cap("~~del~~")), "~~Del~~")
  expect_equal(b_txt(fmt_cap("\"quoted\"")), "\"Quoted\"")
  expect_equal(b_txt(fmt_cap("(bracket)")), "(Bracket)")
  expect_equal(b_txt(fmt_cap("**_mixed_** x")), "**_Mixed_** x")
  # controls
  expect_equal(b_txt(fmt_cap("*abc* def")), "*Abc* def")
  expect_equal(b_txt(fmt_cap("**abc** def")), "**Abc** def")
  expect_equal(b_txt(fmt_cap("Already")), "Already")
  expect_equal(b_txt(fmt_cap("élan")), "Élan")
})

# ---- 18 + ruling .range: both ends share the decimals, then collapse -------------------------------------------

test_that("review D #18: .range prints both ends to the same decimals, then collapses if they print the same (1.4.4)", {
  expect_equal(b_txt(fmt_range(c(1, 1.04))), "1.0")
  expect_equal(b_txt(fmt_range(c(3, 3.02))), "3.0")
  expect_equal(b_txt(fmt_range(c(1, 1.5))), paste0("1.0", B_EN, "1.5"))
  # controls
  expect_equal(b_txt(fmt_range(c(3, 5))), paste0("3", B_EN, "5"))
  expect_equal(b_txt(fmt_range(c(1.5, 2.5))), paste0("1.5", B_EN, "2.5"))
  expect_equal(b_txt(fmt_range(c(3, 3))), "3")
})

test_that("review D #18: as an n governor the collapsed range is read as printed", {
  src <- "[# site | # sites]{.range n=\"c(1, 1.04)\"} and [# site | # sites]{.range n=\"c(1, 1)\"}"
  res <- render_rmd(src, code = PRE_B, format = "knit", in_process = TRUE)
  b_need(res)
  # 1.0 prints with a decimal, so the plural; the control (1, 1) prints 1, so the singular
  expect_match(res$md, "(^|\\s)1\\.0 sites and 1 site")
})

# ---- 19, 20: sentence starts (5.10.1, 2.6.2) ---------------------------------------------------------------------

SS_ROWS <- list(
  list(src = "End. [three]{.strong} strong text span.", line = 1L, rule = "a text span"),
  list(src = "End. [`r k`]{.cap} capped span.", line = 1L, rule = "a value in a text span prints 3"),
  list(src = "End. [`r k`]{.weft-literal why=\"x\"} literal.", line = 1L, rule = "a value inside a literal"),
  list(src = "End. [x]{cite=\"@a\"} cited.", line = 1L, rule = "a cite span"),
  list(src = "**Bold.** `r k` after bold sentence.", line = 1L, rule = "a sentence ends inside emphasis"),
  list(src = "Term\n:   `r k` definition", line = 2L, rule = "the start of a definition block"),
  # controls: listed already, and not listed
  list(src = "Done. `r k`{.num} sites failed.", line = 1L, rule = "control: after '. '"),
  list(src = "There were `r k`{.num} sites.", line = NA_integer_, rule = "control: mid-sentence"),
  list(src = "End. [`r w`]{.cap} capped span.", line = NA_integer_, rule = "control: .cap prints X")
)

d_ss <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    b <- b_body(SS_ROWS)
    res <- render_rmd(b$lines, code = c(PRE_B, "w <- 'x'"), front = "bibliography: refs.bib",
                      files = list("_weft.yml" = "sentence_start_fail: true",
                                   "refs.bib" = "@misc{a, title = {A}, author = {A, B}, year = {2020}}"),
                      env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
    res$b <- b
    cache <<- res
    res
  }
})

test_that("review D #19: sentence starts nested in text, literal and cite spans, after a bold sentence and in a definition are listed", {
  res <- d_ss()
  b_need(res)
  listed <- res$knit$failures$line[res$knit$failures$kind == "sentence start"]
  for (i in seq_along(SS_ROWS)) {
    r <- SS_ROWS[[i]]
    line <- res$offset + res$b$at[i] + (if (is.na(r$line)) 0L else r$line - 1L)
    if (is.na(r$line)) {
      expect_false(any(listed %in% (res$offset + res$b$at[i] + 0:1)), label = r$rule)
    } else {
      expect_true(line %in% listed, label = r$rule)
    }
  }
})

test_that("review D #20: a sentence-start failure leaves a marker in the output in draft mode (2.6.2)", {
  res <- d_ss()
  b_need(res)
  txt <- unesc(res$text)
  # the control, which is already listed, carries a marker
  line_of <- function(pat) grep(pat, txt, value = TRUE)
  expect_match(line_of("^Done\\. ")[1], "<<weft:")
  expect_false(grepl("<<weft:", line_of("^There were")[1], fixed = TRUE))
})

test_that("review D #20: an if span's sentence start is reported by its phrase, not by its condition", {
  res <- render_rmd("[`r k` items | none]{if=\"TRUE\"} zzif.", code = PRE_B,
                    files = list("_weft.yml" = "sentence_start_fail: true"),
                    env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
  b_need(res)
  f <- res$knit$failures[res$knit$failures$kind == "sentence start", ]
  expect_gte(nrow(f), 1L)
  expect_false(any(trimws(f$expr) == "TRUE"))
})

# ---- 22: brk() and lookup() inputs ------------------------------------------------------------------------------------

test_that("review D #22: a duplicate key in lookup(), and a phrase that is not one string, are errors", {
  d_weft_error(lookup(c(a = "x", a = "y"))("a"))
  d_weft_error(lookup(list(a = "x", b = 2))("b"))
  d_weft_error(brk(. < 1 ~ 2)(0))
  d_weft_error(brk(. < 1 ~ c("a", "b"))(0))
  # controls
  expect_equal(b_txt(lookup(c(a = "x", b = "y"))("a")), "x")
  expect_equal(b_txt(brk(. < 10 ~ "small", TRUE ~ "big")(9)), "small")
  expect_equal(b_txt(brk(. < 10 ~ "small", TRUE ~ "big")(11)), "big")
})

# ---- 23, ruling M, ruling G: ids and back-references from the source ------------------------------------------------

test_that("review D #23: a governor that starts with # but is not exactly a back-reference is a construct error (1.7.6, 5.3.5)", {
  b_expect_scan_error("`r k`{#d} then [one | # many]{n=\"#d + 1\"}",
                      "`r k`{#d} then [one | # many]{n=\"#d\"}")
  b_expect_scan_error("`r k`{#d} then [one | # many]{sign=\"#d + 1\"}")
})

test_that("review D ruling M: a back-reference to the id of an if span is a construct error from the source", {
  b_expect_scan_error("[yes | no]{if=\"k > 1\" #i}\n\nThen [a | b]{n=\"#i\"}.",
                      "[yes | no]{n=\"k\" #i}\n\nThen [a | b]{n=\"#i\"}.")
})

test_that("review D ruling G: two ids in one block are a construct error", {
  b_expect_scan_error("`r 2`{#e #f}", "`r 2`{#e}")
  b_expect_scan_error("[a | b]{n=\"k\" #e #f}", "[a | b]{n=\"k\" #e}")
})

# ---- 25: the phrase functions and clamp() (1.3.4, 3.4.2, 3.5) ---------------------------------------------------------

test_that("review D #25: clamp(NA) is a missing value as clamp(NA_real_) is", {
  d_weft_error(clamp(NA_real_, 1), "weft_no_value")   # control
  d_weft_error(clamp(NA, 1), "weft_no_value")
})

test_that("review D #25: clamp() with floor above ceiling, and of_n() with no plural, are weft errors", {
  d_weft_error(clamp(5, floor = 10, ceiling = 1), "weft_value_error")
  d_weft_error(of_n(2, 3, "site"), "weft_value_error")
  expect_equal(b_txt(of_n(2, 3, "site", "sites")), "2 of the 3 sites")   # control
})

test_that("review D #25: of_n() takes a weft_text as k (3.4.2)", {
  x <- of_n(fmt_num(3), 7, "site", "sites")
  expect_equal(b_txt(x), "3 of the 7 sites")
})

# ---- ruling C: reversed ranges and nonsense ci() and pm() -----------------------------------------------------------------

test_that("review D ruling C: a reversed .range, ci() with lo > hi or est outside, and pm() with a negative se are value errors", {
  d_weft_error(fmt_range(c(5, 3)), "weft_value_error")
  d_weft_error(ci(2, 3, 1), "weft_value_error")
  d_weft_error(ci(5, 1, 3), "weft_value_error")
  d_weft_error(ci(0, 1, 3), "weft_value_error")
  d_weft_error(pm(2.1, -0.3), "weft_value_error")
  # controls
  expect_equal(b_txt(ci(2.1, 1.3, 2.9)), "2.1 (95% CI 1.3 to 2.9)")
  expect_equal(b_txt(pm(2.1, 0.3)), "2.1 ± 0.3")
  expect_equal(b_txt(fmt_range(c(3, 5))), paste0("3", B_EN, "5"))
})

# ---- ruling J: renderer keys on a cite span -----------------------------------------------------------------------------------

test_that("review D ruling J: digits or trunc on a cite span is a construct error", {
  b_expect_scan_error("[x]{cite=\"@smith2020\" digits=\"2\"}", "[x]{cite=\"@smith2020\" .strong}")
  b_expect_scan_error("[x]{cite=\"@smith2020\" trunc=\"2\"}")
  b_expect_scan_error("[x]{cite=\"smith2020\" digits=\"2\"}")
})

# ---- ruling H: .p thresholds are applied after rounding ------------------------------------------------------------------------

test_that("review D ruling H: .p applies its thresholds to the rounded number", {
  # the lower threshold is judged on the value itself: 0.0009 is below 0.001
  expect_equal(b_txt(fmt_p(0.0009)), "p < 0.001")
  # controls
  expect_equal(b_txt(fmt_p(0.0004)), "p < 0.001")
  expect_equal(b_txt(fmt_p(0.001)), "p = 0.001")
  expect_match(b_txt(fmt_p(0.0095)), "^p = 0\\.010?$")
  expect_equal(b_txt(fmt_p(0.9991)), "p > 0.99")
  expect_equal(b_txt(fmt_p(0.03)), "p = 0.03")
})
