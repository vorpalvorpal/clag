# Regression tests for the review of stage 1c and the Quarto side
# (dev/review-1c.md, findings 1-18; dev/design-1c.md, "Rulings on the review
# of stage 1c and the Quarto side"). Written before the fixes: each test
# describes a defect that was reproduced by rendering, and fails until it is
# fixed. Finding 19 and item A are left out (cosmetic; recorded for a lint).
#
# Quarto project renders cost about 5 s each; they are kept few and shared
# between the tests of one project. Filter findings use the direct-Pandoc
# harness (run_filter()).

rc_chr <- function(x) paste(as.character(unlist(x)), collapse = "\n")

rc_front <- c("---", "title: \"t\"", "engine: knitr", "format: html",
              "execute:", "  echo: false", "---", "")

rc_rmd_front <- c("---", "title: \"t\"", "---", "")

rc_setup <- function(extra = NULL) {
  c("```{r setup, include=FALSE}", "weft::weft_setup()", "n <- 3", extra,
    "```", "")
}

# ---- 1. use_quarto() edits _quarto.yml as text ---------------------------------

test_that("review C #1: use_quarto() keeps a realistic _quarto.yml as text, and the project still renders (9.3.1, design-1a 'The Quarto side')", {
  skip_if_no_quarto()
  skip_on_cran()
  yml <- c(
    "# Project settings for the survey report",
    "project:",
    "  type: default            # not a book",
    "  pre-render: scripts/mine.R",
    "",
    "format:",
    "  html:",
    "    toc: true",
    "    code-fold: &cf false   # anchored",
    "execute:",
    "  echo: *cf",
    "  warning: false",
    "filters:",
    "  - early.lua",
    "  - at: post-render",
    "    path: late.lua"
  )
  lua <- c("function Pandoc(doc) return doc end")
  dir <- tempfile("weft-c1-")
  dir.create(dir)
  dir <- normalizePath(dir)
  withr::defer(unlink(dir, recursive = TRUE))
  put_files(dir, list(
    `_quarto.yml` = yml,
    `early.lua` = lua, `late.lua` = lua,
    `scripts/mine.R` = "writeLines('ran', 'mine-ran.txt')",
    `index.qmd` = c("---", "title: Home", "---", "", "Some text.")
  ))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  new <- readLines(file.path(dir, "_quarto.yml"), warn = FALSE)

  # every original line is still there, except the scalar that had to become
  # a list
  keep <- setdiff(yml, "  pre-render: scripts/mine.R")
  for (l in keep) expect_true(l %in% new, label = paste("line kept:", l))
  expect_true(any(grepl("# Project settings for the survey report", new, fixed = TRUE)))
  expect_true(any(grepl("&cf", new, fixed = TRUE)), label = "the anchor stays an anchor")
  expect_true(any(grepl("*cf", new, fixed = TRUE)), label = "the alias stays an alias")
  # YAML 1.1 booleans are never written
  expect_false(any(grepl(":\\s*(yes|no|on|off)\\b", new)), label = "no yes/no booleans")
  expect_true(any(grepl("toc: true", new, fixed = TRUE)))
  # the weft pieces went in
  expect_true(any(grepl("weft-check", new, fixed = TRUE)))
  expect_true(any(grepl("_weft/pre-render.R", new, fixed = TRUE)))
  expect_true(any(grepl("_weft/post-render.R", new, fixed = TRUE)))
  expect_true(any(grepl("scripts/mine.R", new, fixed = TRUE)), label = "the author's pre-render script is kept")

  # it parses, and the structure is what the author wrote plus weft's entries
  y <- NULL
  expect_no_error(y <- yaml::yaml.load_file(file.path(dir, "_quarto.yml")))
  f <- y$filters
  expect_true("early.lua" %in% unlist(Filter(is.character, f)))
  expect_true("weft-check" %in% unlist(Filter(is.character, f)))
  at <- Filter(is.list, f)
  # design-7 N50 (7d): exactly two mapping items: the author's, then weft-output.lua after it
  expect_length(at, 2L)
  at1 <- if (length(at)) at[[1]] else list()
  expect_identical(at1$at, "post-render")
  expect_identical(at1$path, "late.lua")
  at2 <- if (length(at) > 1L) at[[2]] else list()
  expect_identical(at2$at, "post-render")
  expect_identical(at2$path, "_extensions/weft-check/weft-output.lua")
  pre <- unlist(y$project$`pre-render`)
  expect_true("scripts/mine.R" %in% pre)
  expect_true(any(grepl("pre-render\\.R$", pre)))

  # and a real render succeeds, running both pre-render scripts
  r <- qrender(dir)
  expect_identical(r$status, 0L, info = r$log)
  expect_no_match(r$log, "validation failed", fixed = TRUE)
  expect_true(file.exists(file.path(dir, "mine-ran.txt")))
  expect_true(file.exists(file.path(dir, "index.html")) ||
                file.exists(file.path(dir, "_site", "index.html")))
})

# ---- 2. !expr captions are left as stock leaves them --------------------------

test_that("review C #2: a caption given as !expr is evaluated as stock does (2.1.7, design-1c 'stock parity')", {
  skip_if_no_quarto()
  skip_on_cran()
  res <- qmd_html(c(
    rc_front, rc_setup(),
    "```{r}",
    "#| label: fig-e",
    "#| fig-cap: !expr paste(\"Built\", n)",
    "#| fig-alt: !expr paste(\"Alt\", n)",
    "plot(1)", "```", "",
    "```{r}",
    "#| label: fig-ok",
    "#| fig-cap: |",
    "#|   Control [a site | # sites]{n=\"n\"}.",
    "plot(2)", "```"
  ))
  expect_false(res$failed, info = res$log)
  # the control: a literal caption with a construct resolves
  expect_true(any(grepl("Control 3 sites.", res$captions, fixed = TRUE)))
  # the defect: !expr is not evaluated
  expect_true(any(grepl("Built 3", res$captions, fixed = TRUE)),
              info = paste(res$captions, collapse = " | "))
  expect_false(any(grepl("paste", res$captions, fixed = TRUE)))
  expect_true("Alt 3" %in% res$alts, info = paste(res$alts, collapse = " | "))
})

# ---- 3. the label scan agrees with knitr (2.5.2, 2.1.5) -----------------------

test_that("review C #3: a comma label or a YAML comment on the label gives no false 'unevaluated' (rmarkdown)", {
  res <- rmd_html(c(
    rc_rmd_front, rc_setup(),
    "```{r, fig5, fig.cap='Comma label [a site | # sites]{n=\"n\"}.'}",   # 10
    "plot(1)", "```", "",
    "```{r, fig6}",
    "#| fig.cap: |",
    "#|   Comma pipe [a site | # sites]{n=\"n\"}.",
    "plot(1)", "```", "",
    "```{r fig7, fig.cap='Plain label [a site | # sites]{n=\"n\"}.'}",
    "plot(1)", "```"
  ))
  expect_false(res$failed, info = res$message)
  expect_no_match(res$message, "unevaluated")
  # the control (a plain label) and the two odd ones resolve
  expect_match(res$text, "Plain label 3 sites.", fixed = TRUE)
  expect_match(res$text, "Comma label 3 sites.", fixed = TRUE)
  expect_match(res$text, "Comma pipe 3 sites.", fixed = TRUE)
})

test_that("review C #3: a YAML comment after the label gives no false 'unevaluated' (Quarto)", {
  skip_if_no_quarto()
  skip_on_cran()
  res <- qmd_html(c(
    rc_front, rc_setup(),
    "```{r}",
    "#| label: fig-a   # the depth figure",
    "#| fig-cap: |",
    "#|   Depth [a site | # sites]{n=\"n\"}.",
    "plot(1)", "```", "",
    "```{r}",
    "#| label: fig-b",
    "#| fig-cap: |",
    "#|   Control [a site | # sites]{n=\"n\"}.",
    "plot(2)", "```"
  ))
  expect_false(res$failed, info = res$log)
  expect_no_match(res$log, "unevaluated")
  expect_true(any(grepl("Control 3 sites.", res$captions, fixed = TRUE)))
  expect_true(any(grepl("Depth 3 sites.", res$captions, fixed = TRUE)))
})

# ---- 4. child documents ---------------------------------------------------------

rc_child_parent <- function(child = "k.Rmd") {
  c(rc_setup(),
    sprintf("```{r child, child='%s'}", child), "```")
}

test_that("review C #4: a caption in an unlabelled chunk of a child document is not 'unevaluated' (2.1.5, 2.5.2)", {
  res <- rmd_html(
    c(rc_rmd_front, rc_child_parent("k.Rmd")),
    files = list(`k.Rmd` = c(
      "K.", "",
      "```{r}",
      "#| fig.cap: |",
      "#|   Kid [a site | # sites]{n=\"n\"}.",
      "plot(2)", "```"
    ))
  )
  expect_false(res$failed, info = res$message)
  expect_no_match(res$message, "unevaluated")
  expect_match(res$text, "Kid 3 sites.", fixed = TRUE)
})

test_that("review C #4: a failed claim in a child's caption or weft_str() is named in the child's file (2.6.2, 2.7.1)", {
  kid <- c(
    "K.", "",
    "```{r kfig}",                                    # 3
    "#| fig.cap: |",
    "#|   Kid [a site | # sites]{n=\"n\"} `r claim(n, . > 50)`{.num}.",
    "plot(2)", "```", "",
    "```{r kidchunk}",
    "x <- weft::weft_str('S `r claim(n, . > 70)`{.num}')",
    "```"
  )
  res <- render_rmd(c("```{r child, child='kid2.Rmd'}", "```"), code = "n <- 3",
                    files = list(`kid2.Rmd` = kid), name = "parent")
  expect_true(res$failed)
  m <- res$message
  # the control: both failures are reported, by their chunk
  expect_match(m, "kfig")
  expect_match(m, "kidchunk")
  # each is located in the file that holds it, not in the parent
  expect_match(m, "kid2\\.Rmd[^\n]*kfig")
  expect_match(m, "kid2\\.Rmd[^\n]*kidchunk")
  expect_no_match(m, "parent\\.Rmd[^\n]*(kfig|kidchunk)")
})

# ---- 5. a stale collection file (2.4.5, 2.6.5, 2.6.6, 2.9.5; ruling) -----------

rc_stale <- new.env()
rc_stale_proj <- function() {
  if (is.null(rc_stale$dir)) {
    skip_if_no_quarto()
    skip_on_cran()
    ch1 <- c("---", "title: \"One\"", "engine: knitr", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "n <- 3", "```", "",
             "Prose claim `r claim(n, . > 50)`{.num} here.")
    ch2 <- c("---", "title: \"Two\"", "engine: knitr", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "n <- 3", "```", "",
             "```{r}", "claim(n, . > 99)", "```")
    rc_stale$line1 <- file_line(ch1, "claim(n, . > 50)")
    dir <- mk_project(list(
      `_quarto.yml` = c("project:", "  type: default", "format: html"),
      `ch1.qmd` = ch1, `ch2.qmd` = ch2
    ))
    withr::defer(unlink(dir, recursive = TRUE), teardown_env())
    rc_stale$dir <- dir
    rc_stale$r1 <- qrender(dir)
  }
  rc_stale
}

test_that("review C #5: an aborted project render prints the failures of earlier chapters with its own error (2.4.5)", {
  s <- rc_stale_proj()
  expect_false(identical(s$r1$status, 0L))
  # the control: the stopping failure is named
  expect_match(s$r1$log, "ch2\\.qmd")
  # the defect: ch1's failure, collected before it, is printed too
  expect_match(s$r1$log, sprintf("ch1\\.qmd:%d\\b", s$line1), info = s$r1$log)
})

test_that("review C #5: a collection file left by the aborted render is not used by a later plain knit (ruling 'A stale collection file')", {
  s <- rc_stale_proj()
  expect_true(file.exists(file.path(s$dir, ".weft")), label = "the aborted render left its files")
  # a clean document is fine (control)
  ok <- render_rmd(c("Note `r claim(n, . > 1)`{.num}."), code = "n <- 3",
                   dir = s$dir, name = "notes_ok")
  expect_false(ok$failed, info = ok$message)
  # a failing claim fails the knit; it is not parked in the stale file
  bad <- render_rmd(c("Note `r claim(n, . > 50)`{.num}."), code = "n <- 3",
                    dir = s$dir, name = "notes")
  expect_true(bad$failed)
  expect_match(bad$message, "claim", ignore.case = TRUE)
  expect_match(bad$message, at_line(bad, 1))
})

test_that("review C #5: a collection file older than an hour with no run id is ignored (ruling)", {
  dir <- tempfile("weft-c5b-")
  dir.create(file.path(dir, ".weft"), recursive = TRUE)
  dir <- normalizePath(dir)
  withr::defer(unlink(dir, recursive = TRUE))
  writeLines(c("project:", "  type: default"), file.path(dir, "_quarto.yml"))
  f <- file.path(dir, ".weft", "failures.jsonl")
  writeLines("", f)
  Sys.setFileTime(f, Sys.time() - 3 * 3600)
  bad <- render_rmd(c("Note `r claim(n, . > 50)`{.num}."), code = "n <- 3",
                    dir = dir, name = "notes")
  expect_true(bad$failed, label = "the failure was not silently parked in the old file")
  expect_match(bad$message, "claim", ignore.case = TRUE)
})

# ---- 6. frozen, no stamp; ruling B (the freeze notice counts constructs) --------

rc_fz <- new.env()
rc_fz_proj <- function() {
  if (is.null(rc_fz$dir)) {
    skip_if_no_quarto()
    skip_on_cran()
    a <- c("---", "title: \"A\"", "engine: knitr", "---", "",
           "```{r setup, include=FALSE}", "weft::weft_setup()", "depth <- 12.5", "```", "",
           "Depth `r depth`{.num}, [one site | # sites]{n=1} and [met | not met]{if=\"depth > 5\"}.")
    dir <- mk_project(list(
      `_quarto.yml` = c("project:", "  type: default", "format: html",
                        "execute:", "  freeze: auto"),
      `a.qmd` = a
    ))
    withr::defer(unlink(dir, recursive = TRUE), teardown_env())
    rc_fz$dir <- dir
    rc_fz$r1 <- qrender(dir)       # executes, writes the stamp
    rc_fz$r2 <- qrender(dir)       # served from freeze, stamp present
    unlink(file.path(dir, ".weft"), recursive = TRUE)
    rc_fz$r3 <- qrender(dir)       # served from freeze, no stamp (a fresh clone)
  }
  rc_fz
}

test_that("review C #6: a frozen document with no stamp is reported as never checked on this machine (2.9.2, ruling)", {
  z <- rc_fz_proj()
  # the controls: the first render executes and says nothing of the kind
  expect_identical(z$r1$status, 0L, info = z$r1$log)
  expect_match(z$r1$log, "processing file", fixed = TRUE)
  expect_no_match(z$r1$log, "never checked")
  expect_no_match(z$r2$log, "never checked")
  # the render with no stamp is served from freeze, does not fail, and says so
  expect_no_match(z$r3$log, "processing file", fixed = TRUE)
  expect_identical(z$r3$status, 0L, info = z$r3$log)
  expect_match(z$r3$log, "never checked on this machine", fixed = TRUE)
  expect_match(z$r3$log, "a\\.qmd")
})

test_that("review C ruling B: the freeze notice counts constructs and says 'N constructs were not checked' (2.9.2)", {
  z <- rc_fz_proj()
  expect_no_match(z$r2$log, "processing file", fixed = TRUE)
  expect_identical(z$r2$status, 0L, info = z$r2$log)
  expect_match(z$r2$log, "freez|frozen", ignore.case = TRUE)   # control
  expect_match(z$r2$log, "\\b3 constructs were not checked", info = z$r2$log)
})

# ---- 7 and ruling C. The filter and code blocks ---------------------------------

rc_marker <- "## [1] \"S 3<<weft: failed claim, chunk s1>>\""

test_that("review C #7: the filter fails on a <<weft: marker in chunk output, a code block with no language or a cell-output class (2.5.3, 2.9.5)", {
  cases <- list(
    classless      = c("Before.", "", "```", rc_marker, "```", "", "After."),
    cell_output    = c("Before.", "", "``` {.cell-output .cell-output-stdout}", rc_marker, "```", "", "After."),
    in_output_div  = c("Before.", "", "::: {.cell-output .cell-output-stdout}", "```", rc_marker, "```", ":::", "", "After.")
  )
  expect_filter_fails(cases)
  # the control: the same marker in a paragraph already fails
  expect_filter_fails(list(paragraph = "Before <<weft: failed claim, chunk s1>> after."))
  # and a code block with no marker passes
  expect_filter_passes(list(clean = c("```", "## [1] \"S 3\"", "```")))
})

test_that("review C ruling C: a marker in a fenced block that carries a language class is not chunk output and passes (2.9.5, 1.9.2)", {
  cases <- list(
    markdown = c("Shown on purpose:", "", "```markdown", "Depth 3<<weft: failed claim, line 4>>", "```"),
    r_class  = c("Shown:", "", "``` {.r}", "x <- '<<weft: no value, line 2>>'", "```"),
    text     = c("Shown:", "", "```text", "<<weft: failed claim, chunk a>>", "```")
  )
  expect_filter_passes(cases)
  # the control: outside any code block the marker still fails
  expect_filter_fails(list(paragraph = "Shown <<weft: no value, line 2>> here."))
})

# ---- 8. weft_str() in a cached chunk -------------------------------------------

test_that("review C #8: a failure in weft_str() inside a cached chunk does not pass on the second render (2.9.1, 2.6.8)", {
  d <- tempfile("weft-c8-")
  lines <- c("x <- weft::weft_str('C `r claim(n, . > 9)`{.num}')", "cat(x)")
  body <- c("```{r cached, cache=TRUE}", lines, "```")
  r1 <- render_rmd(body, code = "n <- 3", dir = d, name = "doc")
  withr::defer(unlink(d, recursive = TRUE))
  expect_true(r1$failed, label = "the first render fails (control)")
  r2 <- render_rmd(body, code = "n <- 3", dir = d, name = "doc")
  expect_true(r2$failed, label = "the second render, with the chunk cached, fails again")
})

# ---- 9. a caption set with opts_chunk$set() on a cached chunk ------------------

rc_global_cap <- c(
  "```{r setup}",
  "weft::weft_setup()",
  "n <- 3",
  "knitr::opts_chunk$set(fig.cap = 'Global [a site | # sites]{n=\"n\"}')",
  "```", "",
  "```{r a}", "plot(1)", "```", ""
)

test_that("review C #9: a construct in a global caption on a cached chunk is a construct error with the div remedy (2.3.5, ruling F)", {
  ctrl <- rmd_html(c(rc_rmd_front, rc_global_cap))
  expect_false(ctrl$failed, info = ctrl$message)
  expect_match(ctrl$text, "Global 3 sites", fixed = TRUE)
  bad <- rmd_html(c(rc_rmd_front, rc_global_cap, "```{r b, cache=TRUE}", "plot(2)", "```"))
  expect_true(bad$failed)
  expect_match(bad$message, "cach", ignore.case = TRUE)
  expect_match(bad$message, "div", ignore.case = TRUE)
  expect_match(bad$message, "\\bb\\b")
})

# ---- 10. a computed caption is data (2.2.4) ---------------------------------------

rc_cap_doc <- c(
  rc_rmd_front,
  "```{r setup, include=FALSE}",
  "weft::weft_setup()",
  "n <- 3",
  "cap <- 'Var [a site | # sites]{n=\"n\"}'",
  "```", "",
  "```{r h, fig.cap=paste0('Computed [a site | # sites]{n=', '\"n\"', '}')}",
  "plot(1)", "```", "",
  "```{r v, fig.cap = cap}",
  "plot(1)", "```", "",
  "```{r lit, fig.cap='Literal [a site | # sites]{n=\"n\"}'}",
  "plot(1)", "```"
)

test_that("review C #10: a caption computed by R code is printed as it is and never evaluated as markup (2.2.4)", {
  res <- rmd_html(rc_cap_doc)
  # the control: a literal caption is resolved
  expect_match(res$text, "Literal 3 sites", fixed = TRUE)
  # computed ones are not: the text of the span is printed, with its pipe
  expect_no_match(res$text, "Computed 3 sites", fixed = TRUE)
  expect_no_match(res$text, "Var 3 sites", fixed = TRUE)
  expect_match(res$text, "Computed a site | # sites", fixed = TRUE)
  expect_match(res$text, "Var a site | # sites", fixed = TRUE)
})

test_that("review C ruling 'computed captions': a computed caption goes through weft_str() when it holds markup", {
  res <- rmd_html(c(
    rc_rmd_front,
    "```{r setup, include=FALSE}",
    "weft::weft_setup()",
    "n <- 3",
    "cap <- 'Via weft_str [a site | # sites]{n=\"n\"}'",
    "```", "",
    "```{r w, fig.cap = weft::weft_str(cap)}",
    "plot(1)", "```"
  ))
  expect_false(res$failed, info = res$message)
  expect_match(res$text, "Via weft_str 3 sites", fixed = TRUE)
})

# ---- 11. caption static errors (2.3.5) --------------------------------------------

rc_cache_cap <- function(opt_lines, chunk_opts = NULL, setup_extra = NULL) {
  list(
    setup = rc_setup(setup_extra),
    chunk = c("```{r}", "#| label: fig-c", opt_lines,
              "#| fig-cap: |", "#|   Cap [a site | # sites]{n=\"n\"}.", "plot(1)", "```")
  )
}

expect_cache_error <- function(res) {
  expect_true(res$failed)
  expect_no_match(res$message, "unevaluated")
  expect_match(res$message, "fig-c")
  expect_match(res$message, "div", ignore.case = TRUE)
}

test_that("review C #11: eval: !expr FALSE or cache: !expr TRUE with a caption construct is a static error naming the chunk and the div remedy (2.3.5)", {
  for (opt in c("#| eval: !expr FALSE", "#| cache: !expr TRUE")) {
    p <- rc_cache_cap(opt)
    res <- render_rmd(c(p$chunk), code = "n <- 3")
    expect_cache_error(res)
  }
  # the controls: legal neighbours render
  for (opt in c("#| cache: false", "#| eval: true")) {
    p <- rc_cache_cap(opt)
    ok <- render_rmd(c(p$chunk), code = "n <- 3")
    expect_false(ok$failed, info = paste(opt, ok$message))
    expect_match(ok$md, "Cap 3 sites.", fixed = TRUE)
  }
})

test_that("review C #11: document-level cache: true under knitr: opts_chunk: with a caption construct is a static error (Quarto, 2.3.5)", {
  skip_if_no_quarto()
  skip_on_cran()
  front <- c("---", "title: \"t\"", "engine: knitr", "format: html",
             "knitr:", "  opts_chunk:", "    cache: true", "---", "")
  res <- qmd_html(c(front, rc_setup(),
                    "```{r}", "#| label: fig-c", "#| fig-cap: |",
                    "#|   Cap [a site | # sites]{n=\"n\"}.", "plot(1)", "```"))
  expect_true(res$failed)
  expect_no_match(res$message, "unevaluated")
  expect_match(res$message, "fig-c")
  expect_match(res$message, "div", ignore.case = TRUE)
})

test_that("review C ruling F: a caption construct on a chunk cached by knitr::opts_chunk$set(cache = TRUE) is a construct error with the div remedy (2.3.5)", {
  res <- render_rmd(
    c("```{r}", "#| label: fig-c", "#| fig-cap: |",
      "#|   Cap [a site | # sites]{n=\"n\"}.", "plot(1)", "```"),
    code = c("n <- 3", "knitr::opts_chunk$set(cache = TRUE)")
  )
  expect_cache_error(res)
})

# ---- 12. weft_str() from inline R in prose ----------------------------------------

test_that("review C #12: a failure in weft_str() called from inline R in prose is located by its line, not by a chunk (2.6.2, 2.7.1, 3.6.3)", {
  body <- c(
    "Control `r claim(n, . > 7)`{.num}.",                       # 1
    "",
    "Inline fail: `r weft::weft_str(s9)`.",                     # 3
    "",
    "```{r}", "plot(1)", "```"
  )
  res <- render_rmd(body, code = c("n <- 3", "s9 <- 'IF `r claim(n, . > 9)`{.num}'"))
  expect_true(res$failed)
  m <- res$message
  expect_match(m, at_line(res, 1))                  # the control, by line
  expect_match(m, at_line(res, 3))                  # the call in prose, by line
  expect_no_match(m, "unnamed-chunk-[0-9]+")
})

# ---- 13 and ruling D. the book report keeps filter findings -----------------------

rc_rep <- new.env()
rc_report_proj <- function() {
  if (is.null(rc_rep$dir)) {
    skip_if_no_quarto()
    skip_on_cran()
    raw <- c("---", "title: \"Raw\"", "engine: knitr", "---", "",
             # governors outside the filter's grammar (N9, N12): the filter leaves them for weft-check.lua
             # as leftovers; a plain `x` or `k` is resolved by the filter now (N14, N92)
             "First [a | b]{if=\"x && y\"} one.", "",
             "Second [c | d]{n=\"k + 1\"} two.", "",
             "Third 12.5{.num} three.")
    act <- c("---", "title: \"Act\"", "engine: knitr", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "depth <- 12.5", "```", "",
             "Depth `r claim(depth, . > 100)`{.num} here.")
    rc_rep$actline <- file_line(act, "claim(depth")
    dir <- mk_project(list(
      `_quarto.yml` = c("project:", "  type: default", "format: html"),
      `raw.qmd` = raw, `act.qmd` = act
    ))
    withr::defer(unlink(dir, recursive = TRUE), teardown_env())
    rc_rep$dir <- dir
    rc_rep$r <- qrender(dir)
  }
  rc_rep
}

# the post-render script's output: everything after the script is named
rc_post <- function(log) {
  sub("(?s)^.*Running script '_weft/post-render\\.R'", "", log, perl = TRUE)
}

test_that("review C #13: the book report keeps every leftover finding of a document, as separate entries (2.6.2, trial bug 8)", {
  r <- rc_report_proj()
  expect_false(identical(r$r$status, 0L))
  post <- rc_post(r$r$log)
  # the control: the failed claim of act.qmd is reported, at its line
  expect_match(post, sprintf("act\\.qmd:%d\\b", r$actline))
  # raw.qmd has three different leftovers from weft-check.lua, and weft-output.lua lists
  # the `12.5{.num}` one again (design-7 N59: both are listed): four entries
  expect_identical(n_matches("\\[leftover", post), 4L, info = post)
  expect_match(post, "if=", fixed = TRUE)
  expect_match(post, "n=", fixed = TRUE)
  expect_match(post, "12.5{.num}", fixed = TRUE)
})

test_that("review C ruling D: a filter finding for a <<weft: marker that a knit record explains is not reported twice (same file, kind, line)", {
  r <- rc_report_proj()
  post <- rc_post(r$r$log)
  # the failed claim in act.qmd is one entry (the filter saw its marker too)
  expect_identical(n_matches("act\\.qmd", post), 1L, info = post)
  expect_no_match(post, "<<weft:", fixed = TRUE)
  expect_no_match(post, "the marker", fixed = TRUE)
  # filter findings of different texts are never merged: the three of raw.qmd, plus the
  # output filter's double listing of `12.5{.num}` (design-7 N59)
  expect_identical(n_matches("raw\\.qmd", post), 4L, info = post)
})

# ---- 14. a rule followed by text is not a metadata block ---------------------------

test_that("review C #14: a --- rule followed directly by text is not a metadata block; its constructs resolve (2.5.2, 2.10.2)", {
  res <- render_rmd(
    c("Before the rule [yes | no]{if=\"x\"}.", "",              # 1 (control)
      "---",
      "Between the rules, [yes | no]{if=\"x\"} and `r 1+1`.", "",
      "---", "", "After."),
    code = "x <- TRUE", format = "knit"
  )
  expect_false(res$failed, info = res$message)
  expect_match(res$md, "Before the rule yes.", fixed = TRUE)
  expect_no_match(res$md, "]{if", fixed = TRUE)
  expect_match(res$md, "Between the rules, yes and 2.", fixed = TRUE)
})

# ---- 15. the pre-render check ignores code spans and escapes -----------------------

test_that("review C #15: the pre-render check does not take construct-like text in code spans or escapes for a construct (2.5.4, 1.9)", {
  skip_if_no_quarto()
  skip_on_cran()
  dir <- mk_project(list(
    `_quarto.yml` = c("project:", "  type: default", "format: html"),
    `legit.qmd` = c(
      "---", "title: Legit", "---", "",
      "Something like `]{n=1}` is an attribute block.", "",
      "Double backticks: `` `r x`{.num} `` in a span.", "",
      "Escaped \\[a | b\\]{if=\"x\"}?"
    )
  ))
  withr::defer(unlink(dir, recursive = TRUE))
  r <- qrender(dir, "legit.qmd")
  expect_identical(r$status, 0L, info = r$log)
  expect_no_match(r$log, "holds a weft construct")
  # the control: a real construct in a plain .qmd is still refused, by file
  writeLines(c("---", "title: Bad", "---", "", "Found [one site | # sites]{n=1}."),
             file.path(dir, "bad.qmd"))
  b <- qrender(dir, "bad.qmd")
  expect_false(identical(b$status, 0L))
  expect_match(b$log, "bad\\.qmd")
})

# ---- 16. braces in ordinary prose and metadata -------------------------------------

test_that("review C #16: braces after a space in prose or metadata are not an attribute block (2.5.3, 1.1.7)", {
  cases <- list(
    prose = c("Text with {braces}, {n=3}, a set {if=1} and JSON {\"n\": 1}."),
    meta  = c("---", "title: T",
              "abstract: \"Uses [x]{.smallcaps} and {n=3} text.\"",
              "---", "", "Body.")
  )
  expect_filter_passes(cases)
  # the controls: a block touching the text before it still fails
  expect_filter_fails(list(touching = "Depth is 12.5{.num} here.",
                           key       = "Depth is x{n=\"k\"} here."))
})

# ---- 17. weft_str() outside a knit ---------------------------------------------------

test_that("review C #17: weft_str() outside a knit stops with weft_no_value for an object that does not exist (2.6.4, 2.6.8, design-1c)", {
  # the control: a failed check stops with its class
  n <- 3
  expect_error(weft::weft_str("A `r claim(n, . > 50)`{.num}"), class = "weft_claim_failed")
  e <- tryCatch(weft::weft_str("E `r nope_not_here`{.num}"), error = function(e) e)
  expect_true(inherits(e, "weft_no_value"), label = paste("class:", paste(class(e), collapse = "/")))
})

# ---- 18. block-quoted chunks ---------------------------------------------------------

test_that("review C #18: scan_file() sees a chunk written inside a block quote, as knitr runs it (2.10.2, 3.6.2)", {
  mk <- function(q) {
    body <- c("```{r}",
              "#| label: fig-q",
              "#| fig-cap: |",
              "#|   Q [a site | # sites]{n=\"3\"} end",
              "x <- weft_str(\"Q [l]{.strong}\")",
              "plot(1)", "```")
    c("---", "title: t", "engine: knitr", "---", "", paste0(q, body))
  }
  scan <- function(lines) {
    p <- tempfile("weft-scan-", fileext = ".qmd")
    writeLines(lines, p)
    withr::defer(unlink(p), parent.frame())
    weft:::scan_file(p)
  }
  plain <- scan(mk(""))
  quoted <- scan(mk("> "))
  # the control: unquoted rows exist, at their lines
  expect_identical(plain$line[plain$context == "caption"], 9L)
  expect_identical(plain$line[plain$context == "weft_str"], 10L)
  # the defect: the quoted chunk gives the same rows, at the same lines
  expect_identical(quoted$line[quoted$context == "caption"], 9L)
  expect_identical(quoted$line[quoted$context == "weft_str"], 10L)
  expect_identical(quoted$chunk[quoted$context == "caption"], "fig-q")
})

# ---- ruling E: bare inline R in a weft_str() string is evaluated (pin) ----------------

test_that("review C ruling E: bare inline R in a weft_str() string is evaluated, as the help page says (pin of current behaviour)", {
  expect_identical(weft::weft_str("Two is `r 1 + 1`."), "Two is 2.")
  expect_identical(weft::weft_str("Both `r 1 + 1` and [a | b]{if=\"TRUE\"}."), "Both 2 and a.")
})

# ---- ruling G: use_quarto() from a subdirectory ----------------------------------------

test_that("review C ruling G: use_quarto(path) walks up to the directory that holds _quarto.yml and says which it took", {
  dir <- tempfile("weft-g-")
  dir.create(file.path(dir, "sub", "deeper"), recursive = TRUE)
  dir <- normalizePath(dir)
  withr::defer(unlink(dir, recursive = TRUE))
  writeLines(c("project:", "  type: default", "format: html"), file.path(dir, "_quarto.yml"))
  sub <- file.path(dir, "sub", "deeper")
  said <- character()
  err <- NULL
  out <- utils::capture.output(withCallingHandlers(
    tryCatch(weft::use_quarto(sub), error = function(e) err <<- conditionMessage(e)),
    message = function(m) { said <<- c(said, conditionMessage(m)); invokeRestart("muffleMessage") }
  ))
  expect_null(err)
  said <- paste(c(said, out), collapse = "\n")
  # the files are in the project root, not in the subdirectory
  expect_true(file.exists(file.path(dir, "_weft", "pre-render.R")))
  expect_true(file.exists(file.path(dir, "_extensions", "weft-check", "weft-check.lua")))
  expect_false(dir.exists(file.path(sub, "_weft")))
  expect_false(file.exists(file.path(sub, "_quarto.yml")))
  expect_true(any(grepl("weft-check", readLines(file.path(dir, "_quarto.yml")), fixed = TRUE)))
  # and it says which directory it took
  expect_match(said, basename(dir), fixed = TRUE)
  expect_no_match(said, "Create the project first", fixed = TRUE)
})

# ---- bare inline R in a caption is left as stock leaves it -------------------------------

test_that("review C ruling 'bare inline R in a caption': stays literal text, only constructs are resolved (1.1.8)", {
  res <- rmd_html(c(
    rc_rmd_front, rc_setup(),
    "```{r}",
    "#| fig.cap: |",
    "#|   Cap `r n` and [a site | # sites]{n=\"n\"}.",
    "plot(1)", "```"
  ))
  expect_false(res$failed, info = res$message)
  expect_match(res$text, "and 3 sites.", fixed = TRUE)         # the construct resolved
  expect_match(res$text, "Cap r n and", fixed = TRUE)           # the bare inline R did not
  expect_no_match(res$text, "Cap 3 and", fixed = TRUE)
})
