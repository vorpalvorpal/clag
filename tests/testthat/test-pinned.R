# Pinned internals (§21 "Pinned internals"). Each test pins STOCK behaviour of
# an installed tool that weft depends on, with no weft code involved, so an
# upgrade that changes the behaviour fails here and not silently in a render.
# Observed on: Quarto 1.11.9, knitr 1.51, rmarkdown 2.31, Pandoc 3.8.

# ---- knitr: the `evaluate` hook --------------------------------------------

test_that("§21 pinned: knitr's evaluate hook is function(...) calling evaluate::evaluate, and knitr passes code first, then named arguments", {
  out <- r_fresh(c(
    "library(knitr)",
    "h <- knit_hooks$get('evaluate')",
    "cat('formals=', paste(names(formals(h)), collapse = ','), '\\n', sep = '')",
    "cat('body=', paste(deparse(body(h)), collapse = ' '), '\\n', sep = '')",
    "old <- h",
    "seen <- NULL",
    "knit_hooks$set(evaluate = function(...) {",
    "  a <- list(...)",
    "  seen <<- list(names = names(a), first = a[[1]])",
    "  old(...)",
    "})",
    "invisible(knit(text = c('```{r}', '1 + 1', '```'), quiet = TRUE, envir = new.env()))",
    "cat('names=', paste(seen$names, collapse = ','), '\\n', sep = '')",
    "cat('first=', paste(seen$first, collapse = '|'), '\\n', sep = '')"
  ))
  val <- function(key) sub(paste0("^", key, "="), "", grep(paste0("^", key, "="), out, value = TRUE))
  expect_identical(val("formals"), "...")
  expect_match(val("body"), "evaluate::evaluate(...)", fixed = TRUE)
  # observed: the first argument (unnamed) is the code; the rest are named
  nm <- strsplit(val("names"), ",", fixed = TRUE)[[1]]
  expect_identical(nm[1], "")
  expect_true(all(c("envir", "new_device", "keep_warning", "keep_message",
                    "stop_on_error", "output_handler") %in% nm))
  expect_identical(val("first"), "1 + 1")
})

test_that("§21 pinned: knitr's evaluate.inline hook is function(code, envir)", {
  out <- r_fresh(c("library(knitr)",
                   "cat(paste(names(formals(knit_hooks$get('evaluate.inline'))), collapse = ','), '\\n')"))
  expect_identical(trimws(out[1]), "code,envir")
})

# ---- knitr: eval.after -----------------------------------------------------

test_that("§21 pinned: knitr evaluates the options named in opts_knit$eval.after after the chunk, and the others before it", {
  out <- r_fresh(c(
    "library(knitr)",
    "res <- new.env()",
    "cat('default=', paste(opts_knit$get('eval.after'), collapse = ','), '\\n', sep = '')",
    "knit_hooks$set(chunk = function(x, options) {",
    "  res$cap_at_chunk <- options$fig.cap; res$my_at_chunk <- options$myopt; x })",
    "opts_hooks$set(fig.cap = function(options) {",
    "  res$cap_class_at_hook <- class(options$fig.cap)[1]; options })",
    "src <- c(\"```{r, fig.cap = paste('n is', n), myopt = n * 2}\", 'n <- 3', '```')",
    # 1. a custom option that is not listed is evaluated before the chunk: n is not there yet
    "r <- try(knit(text = src, quiet = TRUE, envir = new.env()), silent = TRUE)",
    "cat('unlisted_failed=', inherits(r, 'try-error'), '\\n', sep = '')",
    "cat('unlisted_msg=', if (inherits(r, 'try-error')) conditionMessage(attr(r, 'condition')) else '', '\\n', sep = '')",
    # 2. listing it makes it work like fig.cap
    "opts_knit$set(eval.after = c('fig.cap', 'myopt'))",
    "r <- try(knit(text = src, quiet = TRUE, envir = new.env()), silent = TRUE)",
    "cat('listed_failed=', inherits(r, 'try-error'), '\\n', sep = '')",
    "cat('cap_class_at_hook=', res$cap_class_at_hook, '\\n', sep = '')",
    "cat('cap_at_chunk=', res$cap_at_chunk, '\\n', sep = '')",
    "cat('my_at_chunk=', res$my_at_chunk, '\\n', sep = '')"
  ))
  val <- function(key) sub(paste0("^", key, "="), "", grep(paste0("^", key, "="), out, value = TRUE))
  expect_match(val("default"), "fig.cap", fixed = TRUE)
  # an option not listed is evaluated before the chunk code ran
  expect_identical(val("unlisted_failed"), "TRUE")
  expect_match(val("unlisted_msg"), "'n' not found|object 'n'")
  # a listed option is evaluated after it: the chunk code's `n` is visible
  expect_identical(val("listed_failed"), "FALSE")
  expect_identical(val("cap_at_chunk"), "n is 3")
  expect_identical(val("my_at_chunk"), "6")
  # and before the chunk it is still unevaluated source (a call), as option hooks see it
  expect_identical(val("cap_class_at_hook"), "call")
})

# ---- Quarto: one render shared by the next three tests ----------------------

pin_env <- new.env()

pin_rprofile <- c(
  "local({",
  "  pin <- new.env()",
  "  assign('.weft_pin', pin, globalenv())",
  "  knitr::opts_hooks$set(foo = function(options) {",
  "    pin$hook_at_options <- knitr::knit_hooks$get('chunk')",
  "    options",
  "  })",
  "})"
)

pin_qmd <- c(
  "---", "title: \"pin\"", "engine: knitr", "keep-md: true",
  "format:", "  markdown:", "    wrap: none", "---", "",
  "```{r}", "#| include: false", "#| foo: 1",
  "log <- function(...) cat(..., '\\n', file = 'pin.txt', append = TRUE, sep = '')",
  "h <- knitr::knit_hooks$get('chunk')",
  "log('chunk1_same_as_options_time=', identical(h, .weft_pin$hook_at_options))",
  "log('chunk1_not_knitr_default=', !identical(h, knitr:::.default.hooks$chunk))",
  "old <- knitr::knit_hooks$get('evaluate.inline')",
  "knitr::knit_hooks$set(evaluate.inline = function(code, envir) {",
  "  log('inline=', code)",
  "  old(code, envir)",
  "})",
  "knitr::opts_hooks$set(`tbl-cap` = function(options) {",
  "  options['tbl-cap'] <- list(NULL)",
  "  options",
  "})",
  "x <- 3",
  "log('wrapper_class=', class(.QuartoInlineRender)[1])",
  "log('wrapper_null=', .QuartoInlineRender(NULL))",
  "log('wrapper_star=', .QuartoInlineRender('a*b'))",
  "```", "",
  "```{r}", "#| include: false",
  "log('chunk2_same_as_options_time=', identical(knitr::knit_hooks$get('chunk'), .weft_pin$hook_at_options))",
  "```", "",
  "Value `{r} x` and `r x`.", "",
  "```{r}", "#| label: tbl-a", "#| tbl-cap: \"Original\"",
  "knitr::kable(data.frame(a = 1))", "```", "",
  "```{r}", "#| label: tbl-z", "knitr::kable(data.frame(a = 1))", "```"
)

pin_quarto <- function() {
  if (is.null(pin_env$dir)) {
    skip_if_no_quarto()
    dir <- mk_project(list(`.Rprofile` = pin_rprofile, `pin.qmd` = pin_qmd), use = FALSE)
    withr::defer(unlink(dir, recursive = TRUE), teardown_env())
    pin_env$dir <- dir
    pin_env$r <- qrender(dir, c("pin.qmd", "--to", "markdown"))
    f <- file.path(dir, "pin.txt")
    pin_env$txt <- if (file.exists(f)) readLines(f, warn = FALSE) else character()
    k <- file.path(dir, "pin.markdown.md")
    pin_env$kept <- if (file.exists(k)) readLines(k, warn = FALSE) else character()
  }
  pin_env
}

test_that("§21 pinned: Quarto hands `{r} x` to knitr as a call to .QuartoInlineRender, and `r x` as the bare expression", {
  p <- pin_quarto()
  expect_identical(p$r$status, 0L, info = p$r$log)
  inline <- sub("^inline=", "", grep("^inline=", p$txt, value = TRUE))
  # one call per inline expression, in document order
  expect_identical(inline, c(".QuartoInlineRender(x)", "x"))
  # the wrapper is a function in the global environment that escapes Markdown
  # characters in strings and prints NULL as "NULL"
  expect_true("wrapper_class=function" %in% p$txt)
  expect_true("wrapper_null=NULL" %in% p$txt)
  expect_true("wrapper_star=a\\*b" %in% p$txt)
})

test_that("§21 pinned: Quarto forwards a NULL tbl-cap as the attribute tbl-cap='{}' on the cell div, and nothing when there is none", {
  p <- pin_quarto()
  expect_gt(length(p$kept), 0L)
  a <- grep("#tbl-a", p$kept, fixed = TRUE, value = TRUE)
  z <- grep("#tbl-z", p$kept, fixed = TRUE, value = TRUE)
  expect_length(a, 1L)
  expect_length(z, 1L)
  expect_match(a, "tbl-cap='{}'", fixed = TRUE)
  expect_no_match(z, "tbl-cap", fixed = TRUE)
})

test_that("§21 pinned: under Quarto the format has set its chunk hook before the first chunk's option hooks run, and it does not change after the first chunk", {
  # observed: knit_hooks$chunk is already the format's (not knitr's default)
  # when the first chunk's option hooks run (so weft_setup() in the first
  # chunk can wrap it), is the same function in the first chunk's code, and
  # is still that same function in the second chunk.
  p <- pin_quarto()
  expect_true("chunk1_same_as_options_time=TRUE" %in% p$txt)
  expect_true("chunk1_not_knitr_default=TRUE" %in% p$txt)
  expect_true("chunk2_same_as_options_time=TRUE" %in% p$txt)
})

test_that("§21 pinned: under rmarkdown the same holds for the output format's chunk hook", {
  skip_if_no_pandoc()
  dir <- tempfile("weft-pin-rmd-"); dir.create(dir)
  dir <- normalizePath(dir)
  writeLines(pin_rprofile, file.path(dir, ".Rprofile"))
  writeLines(c("---", "title: t", "output:", "  md_document:", "    variant: markdown", "---", "",
               "```{r, include=FALSE, foo=1}",
               "log <- function(...) cat(..., '\\n', file = 'pin.txt', append = TRUE, sep = '')",
               "h <- knitr::knit_hooks$get('chunk')",
               "log('chunk1_same_as_options_time=', identical(h, .weft_pin$hook_at_options))",
               "log('chunk1_not_knitr_default=', !identical(h, knitr:::.default.hooks$chunk))",
               "```", "",
               "```{r, include=FALSE}",
               "log('chunk2_same_as_options_time=', identical(knitr::knit_hooks$get('chunk'), .weft_pin$hook_at_options))",
               "```"),
             file.path(dir, "doc.Rmd"))
  withr::local_dir(dir)
  suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                           c("--no-save", "-e", shQuote("rmarkdown::render('doc.Rmd', quiet = TRUE)")),
                           stdout = TRUE, stderr = TRUE))
  txt <- if (file.exists("pin.txt")) readLines("pin.txt") else character()
  expect_true("chunk1_same_as_options_time=TRUE" %in% txt)
  expect_true("chunk1_not_knitr_default=TRUE" %in% txt)
  expect_true("chunk2_same_as_options_time=TRUE" %in% txt)
})

# ---- Lua: os.exit(1) fails a Quarto render ---------------------------------

test_that("§21 pinned: a Lua filter calling os.exit(1) fails a Quarto render, with its stderr text in the log; a filter that does not exit renders", {
  skip_if_no_quarto()
  dir <- mk_project(list(
    `_quarto.yml` = c("project:", "  type: default", "format: html"),
    `fail.lua` = c("function Pandoc(doc)", "  io.stderr:write('WEFT-PIN-EXIT\\n')", "  os.exit(1)", "end"),
    `ok.lua` = c("function Pandoc(doc)", "  io.stderr:write('WEFT-PIN-PASS\\n')", "  return doc", "end"),
    `bad.qmd` = c("---", "title: bad", "filters:", "  - fail.lua", "---", "", "text"),
    `good.qmd` = c("---", "title: good", "filters:", "  - ok.lua", "---", "", "text")
  ), use = FALSE)
  withr::defer(unlink(dir, recursive = TRUE))
  bad <- qrender(dir, "bad.qmd")
  expect_identical(bad$status, 1L)
  expect_match(bad$log, "WEFT-PIN-EXIT", fixed = TRUE)
  expect_false(file.exists(file.path(dir, "bad.html")))
  good <- qrender(dir, "good.qmd")
  expect_identical(good$status, 0L, info = good$log)
  expect_true(file.exists(file.path(dir, "good.html")))
})
