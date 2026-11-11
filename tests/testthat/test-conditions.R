# Package B: the condition hook (2.8), the severity list (7.4.2), normalising
# (7.4.5) and the knitr chunk cache (2.9.1, 7.4.1).

PRE_C <- c(
  "k <- 3; flag <- TRUE",
  "noisy <- function() { warning('pw 7'); message('pm'); 5 }",
  "singular <- function() { message(\"boundary (singular) fit: see help('isSingular')\"); 1 }"
)

# ---- 2.8.1: the rendered document is identical to a stock render -------------------

options_doc <- c(
  "```{r both-shown}",
  "warning('w-shown'); message('m-shown'); print('p')",
  "```",
  "",
  "```{r no-warn}",
  "#| warning: false",
  "warning(paste0('w-', 'hidden')); message('m-shown2'); 1",
  "```",
  "",
  "```{r no-msg}",
  "#| message: false",
  "warning('w3-shown'); message(paste0('m-', 'hidden')); 2",
  "```",
  "",
  "```{r neither}",
  "#| warning: false",
  "#| message: false",
  "warning(paste0('w-', 'hidden4')); message(paste0('m-', 'hidden4')); 3",
  "```",
  "",
  "```{r err-shown, error=TRUE}",
  "stop('e-shown')",
  "```",
  "",
  "```{r err-hidden}",
  "#| error: true",
  "#| warning: false",
  "warning(paste0('w-', 'hidden5')); stop('e5-shown')",
  "```",
  "",
  "After the chunks `r k`."
)

test_that("2.8.1: with warning/message shown or hidden, the output is identical to a stock render (rmarkdown, both outputs)", {
  for (fmt in c("md", "knit")) {
    with <- render_rmd(options_doc, code = PRE_C, format = fmt)
    without <- render_rmd(options_doc, setup = "stock", code = PRE_C, format = fmt)
    expect_false(without$failed, label = without$message)
    expect_false(with$failed, label = with$message)
    expect_identical(with$text, without$text, label = paste("format", fmt))
    # the options were in force, so the comparison has something to bite on
    expect_match(without$md, "w-shown", fixed = TRUE)
    expect_match(without$md, "m-shown2", fixed = TRUE)
    expect_false(grepl("w-hidden", without$md, fixed = TRUE))
    expect_false(grepl("m-hidden", without$md, fixed = TRUE))
    expect_match(without$md, "e-shown", fixed = TRUE)
    expect_match(without$md, "e5-shown", fixed = TRUE)
  }
})

test_that("2.8.1: the same under Quarto", {
  skip_if_no_quarto()
  with <- render_qmd(options_doc, code = PRE_C)
  without <- render_qmd(options_doc, setup = "stock", code = PRE_C)
  expect_false(without$failed, label = without$message)
  expect_false(with$failed, label = with$message)
  expect_identical(with$text, without$text)
  expect_false(grepl("w-hidden", without$md, fixed = TRUE))
})

test_that("2.8.1: every condition a chunk raises is logged with its chunk label, hidden ones too", {
  res <- render_rmd(options_doc, code = PRE_C, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  cond <- res$knit$conditions
  expect_true(all(c("source", "class", "text", "normalised") %in% names(cond)))
  has <- function(source, class, pattern) {
    any(cond$source == source & cond$class == class & grepl(pattern, cond$text, fixed = TRUE))
  }
  expect_true(has("both-shown", "warning", "w-shown"))
  expect_true(has("both-shown", "message", "m-shown"))
  expect_true(has("no-warn", "warning", "w-hidden"))       # hidden from the output, still logged
  expect_true(has("no-msg", "message", "m-hidden"))
  expect_true(has("neither", "warning", "w-hidden4"))
  expect_true(has("neither", "message", "m-hidden4"))
  expect_true(has("err-shown", "error", "e-shown"))
  expect_true(has("err-hidden", "error", "e5-shown"))
  expect_true(has("err-hidden", "warning", "w-hidden5"))
})

test_that("7.4.6 + 7.4.5: the log keeps the text as seen and the normalised form beside it", {
  res <- render_rmd(c("```{r n}", "warning('Removed 5 rows at 0x7ffee4b8c3a0')", "```"), code = PRE_C, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  cond <- res$knit$conditions
  r <- cond[cond$source == "n" & cond$class == "warning", ]
  expect_equal(nrow(r), 1L)
  expect_match(r$text, "Removed 5 rows", fixed = TRUE)
  expect_equal(r$normalised, "Removed <n> rows at <addr>")
  expect_equal(r$normalised, weft:::normalise_condition(r$text))
})

# ---- 2.8.2: conditions raised by values in prose ----------------------------------------

test_that("2.8.2: a condition raised by a value in prose is logged with its line and never appears in the document", {
  src <- c("Intro.", "", "Value `r noisy()`{.num} here.", "", "Bare `r noisy()` here.")
  res <- render_rmd(src, code = PRE_C, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), canon_md("Intro.\n\nValue 5 here.\n\nBare 5 here."))
  expect_false(grepl("pw|pm", res$md))
  cond <- res$knit$conditions
  for (l in c(3L, 5L)) {
    src_rx <- sprintf("doc\\.Rmd:%d$", res$offset + l)
    rows <- cond[grepl(src_rx, cond$source), ]
    expect_true(any(rows$class == "warning" & grepl("pw 7", rows$text, fixed = TRUE)), label = paste("warning at line", l))
    expect_true(any(rows$class == "message" & grepl("pm", rows$text, fixed = TRUE)), label = paste("message at line", l))
  }
})

test_that("2.8.2: the bare value's document is the stock document", {
  src <- c("Intro.", "", "Bare `r noisy()` here.")
  with <- render_rmd(src, code = PRE_C)
  without <- render_rmd(src, setup = "stock", code = PRE_C)
  expect_identical(with$text, without$text)
  expect_equal(without$text[length(without$text)], "Bare 5 here.")
})

# ---- 7.4.2: the severity list -----------------------------------------------------------

singular_msg <- "boundary (singular) fit: see help('isSingular')"
tmb_warn <- "Model convergence problem; non-positive-definite Hessian matrix. See vignette('troubleshooting')"

test_that("7.4.2: lme4's singular-fit message (a message, in a chunk) fails the render", {
  src <- c("```{r fit-chunk}", sprintf("message(\"%s\")", singular_msg), "```", "", "Text `r k`.")
  res <- render_rmd(src, code = PRE_C, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, "singular", fixed = TRUE)
  expect_match(res$message, "fit-chunk", fixed = TRUE)
  expect_true("condition" %in% res$knit$failures$kind)
  expect_true(any(res$knit$failures$chunk == "fit-chunk"))
})

test_that("7.4.2: glmmTMB's non-positive-definite Hessian (a warning) fails the render", {
  src <- c("```{r tmb-chunk}", sprintf("warning(\"%s\")", tmb_warn), "```", "", "Text `r k`.")
  res <- render_rmd(src, code = PRE_C)
  expect_true(res$failed)
  expect_match(res$message, "non-positive-definite", fixed = TRUE)
  expect_match(res$message, "tmb-chunk", fixed = TRUE)
})

test_that("7.4.2 + 2.8.1: a message: false chunk still fails on a severity pattern (it is matched where it is logged)", {
  src <- c("```{r quiet-fit}", "#| message: false", sprintf("message(\"%s\")", singular_msg), "```")
  res <- render_rmd(src, code = PRE_C)
  expect_true(res$failed)
  expect_match(res$message, "singular", fixed = TRUE)
})

test_that("7.4.2: a severity pattern matches in prose too, naming the line", {
  src <- c("Intro.", "", "Fit `r singular()`{.num} here.")
  res <- render_rmd(src, code = PRE_C)
  expect_true(res$failed)
  expect_match(res$message, "singular", fixed = TRUE)
  expect_match(res$message, at_line(res, 3))
})

test_that("7.4.3 + 7.4.4: any other condition is recorded and fails nothing", {
  src <- c("```{r other}", "warning('Removed 5 rows containing missing values')", "message('just a note')", "```", "", "Text `r k`{.word}.")
  res <- render_rmd(src, code = PRE_C, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_equal(canon_md(res$md), "Text three.")
  expect_true(any(res$knit$conditions$source == "other" & res$knit$conditions$class == "warning"))
})

test_that("7.4.2 + 9.1.5: a configured pattern is added to the shipped ones", {
  src <- c("```{r custom}", "message('custom boom happened')", "```")
  res <- render_rmd(src, code = PRE_C, files = list("_weft.yml" = c("severity:", "  - \"custom boom\"")))
  expect_true(res$failed)
  expect_match(res$message, "custom boom", fixed = TRUE)
  # the same document without the setting passes
  res0 <- render_rmd(src, code = PRE_C)
  expect_false(res0$failed, label = res0$message)
  # and the shipped patterns are still there
  src2 <- c("```{r fit2}", sprintf("message(\"%s\")", singular_msg), "```")
  res2 <- render_rmd(src2, code = PRE_C, files = list("_weft.yml" = c("severity:", "  - \"custom boom\"")))
  expect_true(res2$failed)
})

# ---- 7.4.5: normalising ----------------------------------------------------------------

nc <- function(x) weft:::normalise_condition(x)

test_that("7.4.5 step 1: ANSI styling is removed", {
  expect_equal(nc("\u001b[31mred\u001b[39m text"), "red text")
  expect_equal(nc("\u001b[1m\u001b[34mbold blue\u001b[39m\u001b[22m"), "bold blue")
})

test_that("7.4.5 step 2: hexadecimal addresses and R's temporary paths become placeholders", {
  expect_equal(nc("object at 0x7ffee4b8c3a0 failed"), "object at <addr> failed")
  expect_equal(nc("<environment: 0x600003d1c000>"), "<environment: <addr>>")
  tmp <- tempfile("fit", fileext = ".csv")
  out <- nc(paste("cannot open", tmp, "for reading"))
  expect_match(out, "<path>", fixed = TRUE)
  expect_false(grepl("Rtmp", out, fixed = TRUE))
  expect_false(grepl(basename(dirname(tmp)), out, fixed = TRUE))
})

test_that("7.4.5 step 3: every number becomes a placeholder, with sign, decimals and exponent", {
  expect_equal(nc("Removed 5 rows"), "Removed <n> rows")
  expect_equal(nc("x = -3.5e+10"), "x = <n>")
  expect_equal(nc("a 42 b 1.5 c 0.003"), "a <n> b <n> c <n>")
  expect_equal(nc("p = 1e-05"), "p = <n>")
})

test_that("7.4.7: messages that differ only in a number match", {
  expect_equal(nc("Removed 5 rows"), nc("Removed 5000 rows"))
})

test_that("7.4.5 step 4: curly quotes become straight, cli's bullets and rules become ASCII", {
  expect_equal(nc("‘a’ and “b”"), "'a' and \"b\"")
  out <- nc("• item ℹ info ✖ cross ✔ tick ─── rule")
  expect_false(grepl("[^\\x01-\\x7F]", out, perl = TRUE))
  expect_match(out, "item", fixed = TRUE)
  expect_match(out, "rule", fixed = TRUE)
})

test_that("7.4.5 step 5: every run of whitespace, line breaks included, is one space", {
  expect_equal(nc("a \n\t b   c"), "a b c")
  expect_equal(nc("line one\nline two"), "line one line two")
})

test_that("7.4.5: the steps run in order", {
  # ANSI codes hold digits: step 1 must precede step 3
  expect_equal(nc("\u001b[31m5\u001b[39m rows"), "<n> rows")
  # an address holds digits: step 2 must precede step 3
  expect_equal(nc("at 0x7ffee4b8c3a0"), "at <addr>")
  # step 5 sees what the replacements left
  expect_equal(nc("Removed  5\nrows"), "Removed <n> rows")
  # quotes inside a message with a number
  expect_equal(nc("‘x’ has 3 levels"), "'x' has <n> levels")
})

test_that("7.4.5: plain text is unchanged, and normalising twice changes nothing more", {
  expect_equal(nc("a plain message"), "a plain message")
  x <- "\u001b[31m‘a’ at 0x7ffee4b8c3a0 removed 5   rows\u001b[39m"
  expect_equal(nc(nc(x)), nc(x))
})

# ---- 2.9.1: the knitr chunk cache -----------------------------------------------------

cache_doc <- function(extra = NULL) c(
  "```{r make, cache=TRUE}",
  "cat('ran\\n', file = 'ran.txt', append = TRUE)",
  "cached_val <- 3",
  "```",
  "",
  "Count `r cached_val`{.word} here.",
  extra
)

ran_count <- function(dir) {
  f <- file.path(dir, "ran.txt")
  if (file.exists(f)) length(readLines(f)) else 0L
}

test_that("2.9.1: under the chunk cache the prose hooks still run on every render", {
  dir <- withr::local_tempdir()
  r1 <- render_rmd(cache_doc(), code = PRE_C, dir = dir)
  expect_false(r1$failed, label = r1$message)
  expect_equal(canon_md(r1$md), "Count three here.")
  r2 <- render_rmd(cache_doc(), code = PRE_C, dir = dir)
  expect_false(r2$failed, label = r2$message)
  expect_equal(canon_md(r2$md), "Count three here.")
  expect_equal(ran_count(dir), 1L)           # the second render was served from the cache
})

test_that("2.9.1: the prose hooks check the cached values on every render (a failed claim fails both)", {
  dir <- withr::local_tempdir()
  doc <- cache_doc(c("", "Check `r claim(cached_val, . > 100)`."))
  r1 <- render_rmd(doc, code = PRE_C, dir = dir)
  expect_true(r1$failed)
  expect_match(r1$message, at_line(r1, 8))
  r2 <- render_rmd(doc, code = PRE_C, dir = dir)
  expect_true(r2$failed)
  expect_match(r2$message, at_line(r2, 8))
  expect_match(r2$message, ". > 100", fixed = TRUE)
  expect_equal(ran_count(dir), 1L)
})

test_that("2.9.1 + 7.4.1: the conditions of a cached chunk are replayed when it is served from the cache", {
  dir <- withr::local_tempdir()
  doc <- c("```{r warn-cached, cache=TRUE}",
           "cat('ran\\n', file = 'ran.txt', append = TRUE)",
           "warning('cached warning text')",
           "```", "", "Text `r k`.")
  r1 <- render_rmd(doc, code = PRE_C, dir = dir, in_process = TRUE)
  expect_false(r1$failed, label = r1$message)
  expect_true(any(r1$knit$conditions$source == "warn-cached" & grepl("cached warning text", r1$knit$conditions$text, fixed = TRUE)))
  r2 <- render_rmd(doc, code = PRE_C, dir = dir, in_process = TRUE)
  expect_false(r2$failed, label = r2$message)
  expect_equal(ran_count(dir), 1L)
  expect_true(any(r2$knit$conditions$source == "warn-cached" & grepl("cached warning text", r2$knit$conditions$text, fixed = TRUE)),
              label = "replayed from the cache")
})

test_that("2.9.1 + 7.4.2: a severity condition in a cached chunk still fails the render when it is served from the cache", {
  dir <- withr::local_tempdir()
  doc <- c("```{r fit-cached, cache=TRUE}",
           "cat('ran\\n', file = 'ran.txt', append = TRUE)",
           sprintf("message(\"%s\")", singular_msg),
           "```", "", "Text `r k`.")
  r1 <- render_rmd(doc, code = PRE_C, dir = dir)
  expect_true(r1$failed)
  r2 <- render_rmd(doc, code = PRE_C, dir = dir)
  expect_true(r2$failed)
  expect_match(r2$message, "singular", fixed = TRUE)
  expect_equal(ran_count(dir), 1L)
})
