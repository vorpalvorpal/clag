# Package B: stock parity (section 21 "Stock parity", 2.1.7, 1.9.2, 1.3.1) and
# activation (9.2.1, 9.2.5, 9.2.6, 2.1.3, section 21 "Activation").
#
# Parity is always against the same engine without the hooks: the same
# document, the same renderer, one run with weft::weft_setup() in the setup
# chunk and one without. The outputs must be byte-identical.

PRE_X <- "k <- 3; x <- 1.2; flag <- TRUE"

# A document with no attribute block anywhere (apart from the ones inside the
# fence and the comment, where weft changes nothing: 1.9.2).
parity_body <- c(
  "Bare values: `r k` and `r x` and `r NA_real_` and `r \"a*b_c\"` and `r TRUE` and `r NULL`",
  "and `r 1/3` and `r 1e6` and `r 123456789` and `r pi` and `r as.Date('2020-01-02')`",
  "and `r factor('lvl')` and `r c(1, 2, 3)` and `r 1e-5` and `r 1L` and `r '<b>html</b>'`",
  "and `r character(0)` and `r 'two  spaces'` and `r -0.5`.",
  "",
  "Quarto's form: `{r} k` and `{r} NA_real_` and `{r} \"a*b_c\"` and `{r} x`.",
  "",
  "```{r}",
  "print(1:3)",
  "warning('careful')",
  "message('note')",
  "```",
  "",
  "```text",
  "fence `r k` and `r x`{.num} and [a | b]{if=\"flag\"}",
  "```",
  "",
  "<!-- comment `r k` and `r x`{.num} -->",
  "",
  "Plain [span]{.smallcaps} and [link](http://x.org) and [a | b] text and a citation [@smith2020].",
  "",
  "| a | b |",
  "|---|---|",
  "| `r k` | `r x` |",
  "",
  "## Heading `r k`",
  "",
  "- item `r k`",
  "",
  "> quote `r x`"
)

parity_doc <- function(engine, activate) {
  yaml <- c("---", "title: \"Mean `r 1+1` and `{r} 3`\"")
  if (engine == "qmd") yaml <- c(yaml, "engine: knitr", "format:", "  markdown:", "    wrap: none")
  yaml <- c(yaml, "---", "")
  chunk <- c("```{r setup, include=FALSE}", if (activate) "weft::weft_setup()", PRE_X, "```", "")
  c(yaml, chunk, parity_body)
}

test_that("21 Stock parity + 1.3.1 + 1.9.2: no attribute blocks, byte-identical with and without the hooks (rmarkdown)", {
  with <- render_rmd(parity_doc("rmd", TRUE), setup = FALSE, keep_yaml = TRUE)
  without <- render_rmd(parity_doc("rmd", FALSE), setup = FALSE, keep_yaml = TRUE)
  expect_false(without$failed, label = without$message)
  expect_false(with$failed, label = with$message)
  expect_identical(with$text, without$text)
  # the stock behaviours the document leans on, so the comparison is not vacuous
  expect_true(any(grepl("`{r} k`", without$md, fixed = TRUE)), label = "stock rmarkdown leaves {r} alone")
  expect_true(any(grepl("fence 3 and 1.2{.num}", without$md, fixed = TRUE)), label = "stock evaluates r in a fence")
  expect_true(any(grepl("comment 3 and 1.2{.num}", without$md, fixed = TRUE)), label = "stock evaluates r in a comment")
})

test_that("21 Stock parity + 2.1.7: plain knitr::knit() output is the same with the hooks installed (setup chunk)", {
  with <- render_rmd(parity_doc("rmd", TRUE), setup = FALSE, format = "knit")
  without <- render_rmd(parity_doc("rmd", FALSE), setup = FALSE, format = "knit")
  expect_false(without$failed, label = without$message)
  expect_false(with$failed, label = with$message)
  expect_identical(with$text, without$text)
})

test_that("2.1.7 + 21: plain knitr::knit() output is the same with the hooks installed before the knit", {
  doc <- parity_doc("rmd", FALSE)
  with <- render_rmd(doc, setup = FALSE, format = "knit", pre = "weft::weft_setup()")
  without <- render_rmd(doc, setup = FALSE, format = "knit")
  expect_false(with$failed, label = with$message)
  expect_identical(with$text, without$text)
})

test_that("21 Stock parity + 1.3.1: under Quarto, bare `{r} x` and `r x` print as stock Quarto prints them", {
  skip_if_no_quarto()
  with <- render_qmd(parity_doc("qmd", TRUE), setup = FALSE, keep_yaml = TRUE)
  without <- render_qmd(parity_doc("qmd", FALSE), setup = FALSE, keep_yaml = TRUE)
  expect_false(without$failed, label = without$message)
  expect_false(with$failed, label = with$message)
  expect_identical(with$text, without$text)
  expect_true(any(grepl("a\\*b_c", without$md, fixed = TRUE)), label = "stock Quarto escapes the output of {r}")
})

test_that("1.3.1 + 1.3.4: a bare NA prints as stock knitr prints it, beside a formatted missing value in draft mode", {
  src <- c("Mean `r NA_real_` m.", "", "Other `r NA_real_`{.num} m.")
  res <- render_rmd(src, code = PRE_X, env = c(WEFT_DRAFT = "1"), format = "knit")
  expect_false(res$failed, label = res$message)
  expect_true(any(res$text == "Mean NA m."))
  expect_true(any(grepl("^Other <<weft: no value, line [0-9]+>> m\\.$", res$text)))
})

# ---- 2.1.3 / 9.2.6: attaching the package installs nothing --------------------

stock_text <- "Value 3{.num} and [a | b]{if=\"flag\"}."

test_that("2.1.3 + 9.2.6: library(weft) alone installs nothing; the attribute blocks stay visible (rmarkdown)", {
  src <- c("---", "title: t", "---", "",
           "```{r setup, include=FALSE}", "library(weft)", PRE_X, "```", "",
           "Value `r k`{.num} and [a | b]{if=\"flag\"}.")
  res <- render_rmd(src, setup = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), canon_md(stock_text))
})

test_that("2.1.3: loading the namespace and using its functions installs nothing", {
  src <- c("---", "title: t", "---", "",
           "```{r setup, include=FALSE}", "requireNamespace('weft', quietly = TRUE)",
           PRE_X, "y <- weft::claim(k, . > 0)", "f <- weft::fmt_num(1.2)", "```", "",
           "Value `r k`{.num} and [a | b]{if=\"flag\"}.")
  res <- render_rmd(src, setup = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), canon_md(stock_text))
})

test_that("2.1.3 + 9.2.6 under Quarto: library(weft) alone installs nothing", {
  skip_if_no_quarto()
  src <- c("---", "title: t", "engine: knitr", "format:", "  markdown:", "    wrap: none", "---", "",
           "```{r setup, include=FALSE}", "library(weft)", PRE_X, "```", "",
           "Value `r k`{.num} and [a | b]{if=\"flag\"}.")
  res <- render_qmd(src, setup = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), canon_md(stock_text))
})

# ---- activation (9.2.1) ---------------------------------------------------------

test_that("9.2.1: activation from the document's front matter (rmarkdown), no setup chunk call", {
  src <- c("---", "title: t", "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()", "---", "",
           "```{r data, include=FALSE}", PRE_X, "```", "",
           "Value `r k`{.word} and [a | b]{if=\"flag\"}.")
  res <- render_rmd(src, setup = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), "Value three and a.")
})

test_that("9.2.1 + 9.2.8: activation from the front matter under Quarto (engine: knitr in the document)", {
  skip_if_no_quarto()
  src <- c("---", "title: t", "engine: knitr", "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()",
           "format:", "  markdown:", "    wrap: none", "---", "",
           "```{r data, include=FALSE}", PRE_X, "```", "",
           "Value `r k`{.word} and [a | b]{if=\"flag\"}.")
  res <- render_qmd(src, setup = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), "Value three and a.")
})

test_that("9.2.1: activation from a setup chunk, under both engines", {
  both("Value `r k`{.word} and [a | b]{if=\"flag\"}.", "Value three and a.", code = PRE_X)
})

test_that("2.1.3: weft_setup() called before the knit starts installs the hooks too", {
  src <- c("---", "title: t", "---", "", "```{r d, include=FALSE}", PRE_X, "```", "",
           "Value `r k`{.word}.")
  res <- render_rmd(src, setup = FALSE, pre = "weft::weft_setup()")
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), "Value three.")
})

test_that("21 Activation: a loop of rmarkdown::render() calls resolves every document, not only the first", {
  skip_if_not(rmarkdown::pandoc_available())
  withr::defer(weft_restore_knitr())
  words <- c("one", "two", "three", "four")
  for (i in seq_along(words)) {
    d <- write_doc(c(sprintf("Doc %d has `r %d`{.word} and [a | b]{if=\"flag\"}.", i, i)),
                   TRUE, PRE_X, NULL, NULL, paste0("loop", i), "rmd")
    res <- run_rmd_file(d$input, file.path(d$dir, paste0("loop", i, ".md")), "md", TRUE,
                        character(), restore = FALSE)
    expect_false(res$failed, label = paste("document", i, res$error$message))
    out <- tidy_output(file.path(d$dir, paste0("loop", i, ".md")))
    expect_equal(canon_md(paste(out, collapse = "\n")),
                 sprintf("Doc %d has %s and a.", i, words[i]), label = paste("document", i))
  }
})

test_that("21 Activation: the same loop with the setup chunk calling weft_setup() in each, after a failing document", {
  skip_if_not(rmarkdown::pandoc_available())
  withr::defer(weft_restore_knitr())
  d1 <- write_doc("A `r claim(k, . > 100)` b.", TRUE, PRE_X, NULL, NULL, "l1", "rmd")
  d2 <- write_doc("A `r k`{.word} b.", TRUE, PRE_X, NULL, NULL, "l2", "rmd")
  r1 <- run_rmd_file(d1$input, file.path(d1$dir, "l1.md"), "md", TRUE, character(), restore = FALSE)
  expect_true(r1$failed)
  r2 <- run_rmd_file(d2$input, file.path(d2$dir, "l2.md"), "md", TRUE, character(), restore = FALSE)
  expect_false(r2$failed, label = r2$error$message)
  expect_equal(canon_md(paste(tidy_output(file.path(d2$dir, "l2.md")), collapse = "\n")), "A three b.")
})

# ---- 2.1.2: each weft hook wraps the hook installed before it -----------------------

test_that("2.1.2: the hooks installed before weft_setup() still run (text and document hooks)", {
  pre <- paste0(
    "old <- knitr::knit_hooks$get('text'); ",
    "knitr::knit_hooks$set(",
    "text = function(x, ...) sub('PRIORWORD', 'prior-saw-it', if (is.null(old)) x else old(x, ...)), ",
    "document = function(x) c(x, 'PRIOR-DOC-HOOK'))"
  )
  src <- c("Text PRIORWORD here and `r k`{.word}.", "", "```{r}", "1", "```")
  res <- render_rmd(src, code = PRE_X, pre = pre)
  expect_false(res$failed, label = res$message)
  expect_equal(res$text[1], "Text prior-saw-it here and three.")      # weft resolved it and the earlier hook ran
  expect_equal(res$text[length(res$text)], "PRIOR-DOC-HOOK")
})
