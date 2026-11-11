# Regression tests for the defects found by the independent review of the
# knitr runtime (dev/review-1a-B.md, findings 1 to 17) and for the rulings
# that change behaviour (dev/design-1a.md, "Rulings on the review of
# package B": A, B, C, E, G). Each test keeps a control that is already
# correct, so that a pass is not vacuous.

RB_PRE <- c(
  "k <- 3; flag <- TRUE; noflag <- FALSE; v <- 7; n <- 1",
  "s <- 'hello'; nm <- 1"
)
RB_FAIL <- "`r claim(k, . > 100)`"

rb_all_text <- function(res) paste(c(res$message, res$log), collapse = "\n")

# ---- 1 ----------------------------------------------------------------------

test_that("review B #1: constructs and bare values see knitr's root.dir (rules 1.3.1, 2.2.3, 2.2.5)", {
  src <- c(
    "Bare: `r basename(getwd())`. Value: `r basename(getwd())`{.foo}.",
    "",
    "Guard: [data is there | no data]{if=\"file.exists('data.csv')\"}.",
    "",
    "Control: [yes | no]{if=\"TRUE\"}."
  )
  res <- render_rmd(
    src, in_process = TRUE, format = "knit",
    code = c(RB_PRE, "knitr::opts_knit$set(root.dir = file.path(getwd(), 'other'))"),
    files = list("other/data.csv" = "a,b")
  )
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Control: yes.", fixed = TRUE)
  expect_match(res$md, "Bare: other.", fixed = TRUE)
  expect_match(res$md, "Value: [other]{.foo}", fixed = TRUE)
  expect_match(res$md, "Guard: data is there.", fixed = TRUE)
})

# ---- 2 and ruling A ---------------------------------------------------------

test_that("review B #2: a vector with no collapse class prints joined with ', ' (rule 1.4.10 as ruled)", {
  src <- c(
    "Num `r c(1.5, 2)`{.num}; word `r c(1,2)`{.word}; pct `r c(.1,.2)`{.pct};",
    "strong `r c('a','b')`{.strong}; foo `r c('a','b')`{.foo}; bare `r c(1.5, 2)`."
  )
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Num 1.5, 2;", fixed = TRUE)
  expect_match(res$md, "word one, two;", fixed = TRUE)
  expect_match(res$md, "pct 10%, 20%;", fixed = TRUE)
  expect_match(res$md, "strong **a, b**;", fixed = TRUE)
  expect_match(res$md, "foo [a, b]{.foo};", fixed = TRUE)   # control
  expect_match(res$md, "bare 1.5, 2.", fixed = TRUE)         # control
})

test_that("review B ruling A: ordinal and combined classes also join with ', '; a collapse class still wins (rule 1.4.10)", {
  src <- c(
    "Ord `r c(1,2)`{.ord}; strongnum `r c(1.5,2)`{.num .strong}; and `r c(1.5,2)`{.num .and}."
  )
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Ord 1st, 2nd;", fixed = TRUE)
  expect_match(res$md, "strongnum **1.5, 2**;", fixed = TRUE)
  expect_match(res$md, "and 1.5 and 2.", fixed = TRUE)       # control
})

# ---- 3 and ruling G ---------------------------------------------------------

test_that("review B #3: an error in bare inline R names its own line, not the last inline in the block (rules 1.1.8, 2.7.1)", {
  src <- c(
    "Intro.", "",
    "Line three `r 1`.", "",
    "Line five `r undefined_thing`.", "",
    "Line seven `r 2`.", "",
    "Line nine `r 3`."
  )
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_true(res$failed)
  txt <- rb_all_text(res)
  expect_match(txt, "undefined_thing", fixed = TRUE)
  expect_match(txt, at_line(res, 5))
  expect_false(grepl(at_line(res, 9), txt))
})

test_that("review B ruling G: an error in a bare value stops the knit as stock does and names the right line (1.1.8 over 2.6.4)", {
  src <- c(
    "Intro [a | b]{if=\"flag\"}.", "",
    "Bad `r undefined_thing` value.", "",
    "After `r k`{.word}."
  )
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_true(res$failed)
  expect_false("weft_failures" %in% res$error$class)
  expect_false("weft_construct_error" %in% res$error$class)
  txt <- rb_all_text(res)
  expect_match(txt, "undefined_thing", fixed = TRUE)
  expect_match(txt, at_line(res, 3))
  # control: the same document without the bad value resolves
  ok <- render_rmd(src[-3], code = RB_PRE, format = "knit", in_process = TRUE)
  expect_false(ok$failed, label = ok$message)
})

# ---- 4 ----------------------------------------------------------------------

test_that("review B #4: a child knitted twice reports each failure at its own line of the child (rules 2.7.1, 2.7.2, 2.1.5)", {
  child <- c(
    "Intro line one.", "",
    "Claim on line three: `r claim(v, . > 100)`{.num}.", "",
    "Line five `r v`{.num}."
  )
  src <- c(
    "```{r kids, results='asis', echo=FALSE}",
    "for (i in 1:2) { v <- i; cat(knitr::knit_child('child2.Rmd', quiet = TRUE)) }",
    "```"
  )
  res <- render_rmd(src, code = RB_PRE, files = list("child2.Rmd" = child),
                    in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_equal(nrow(f), 2L)
  expect_equal(f$line[1], 3L)                    # control: the first knit
  expect_equal(f$line, c(3L, 3L))                # the second knit too
  expect_false(grepl("child2\\.Rmd:7", res$message))
  expect_match(res$message, "child2\\.Rmd:3\\b")
})

# ---- 5 ----------------------------------------------------------------------

test_that("review B #5: failures in knit_child(text = ) are placed relative to the block and located by the chunk (rules 2.7.3, 2.6.2)", {
  src <- c(
    "```{r kidtext, results='asis', echo=FALSE}",
    "for (i in 1:2) cat(knitr::knit_child(text = c('', '', '', 'Value `r claim(i, . > 5)`{.num}.'), quiet = TRUE))",
    "```"
  )
  res <- render_rmd(src, code = RB_PRE, in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_equal(nrow(f), 2L)                      # control: both are collected
  expect_equal(f$line, c(4L, 4L))                # control: relative to the text
  # a bare "doc.Rmd:4" reads as a line of the parent, so the chunk is named
  expect_equal(f$chunk, c("kidtext", "kidtext"))
  expect_match(res$message, "kidtext", fixed = TRUE)
})

# ---- 6 and 7 (Quarto) -------------------------------------------------------

test_that("review B #6: a nested include in a subdirectory keeps every later position right (rule 2.7.4)", {
  skip_if_no_quarto()
  files <- list(
    "parts/a.qmd" = c("Part A line 1.", "",
                      paste("Part A line 3", RB_FAIL), "",
                      "{{< include parts/deep/b.qmd >}}", "",
                      paste("Part A line 7", RB_FAIL)),
    "parts/deep/b.qmd" = c(paste("Deep B line 1", RB_FAIL))
  )
  main <- c(
    paste("Main 1", RB_FAIL), "",
    "{{< include parts/a.qmd >}}", "",
    paste("Main 5", RB_FAIL), "",
    "{{< include parts/a.qmd >}}", "",
    paste("Main 9", RB_FAIL)
  )
  res <- render_qmd(main, code = RB_PRE, files = files)
  expect_true(res$failed)
  m <- res$message
  expect_match(m, at_line(res, 1))                        # control
  expect_match(m, "parts/a\\.qmd:3\\b")                   # control
  expect_match(m, "parts/deep/b\\.qmd:1\\b")
  expect_match(m, "parts/a\\.qmd:7\\b")
  expect_match(m, at_line(res, 5))
  expect_match(m, at_line(res, 9))
  # no position past the end of the main file
  lines <- as.integer(regmatches(m, gregexpr("(?<=doc\\.qmd:)[0-9]+", m, perl = TRUE))[[1]])
  expect_true(all(lines %in% (res$offset + c(1L, 5L, 9L))), label = paste(lines, collapse = ","))
  expect_false(grepl("parts/a\\.qmd:5\\b", m))
})

test_that("review B #7: an include whose path is quoted is mapped like an unquoted one (rule 2.7.4)", {
  skip_if_no_quarto()
  files <- list(
    "inc.qmd" = c("Plain include.", "", paste("Plain include line 3", RB_FAIL)),
    "_p.qmd"  = c("Quoted include.", "", paste("Quoted include line 3", RB_FAIL))
  )
  main <- c(
    "{{< include inc.qmd >}}", "",
    "{{< include \"_p.qmd\" >}}", "",
    paste("Main 5", RB_FAIL)
  )
  res <- render_qmd(main, code = RB_PRE, files = files)
  expect_true(res$failed)
  expect_match(res$message, "inc\\.qmd:3\\b")               # control
  expect_match(res$message, "_p\\.qmd:3\\b")
  expect_match(res$message, at_line(res, 5))
  expect_false(grepl(at_line(res, 3), res$message), label = "nothing at the include's own line")
})

# ---- 8 and ruling C ---------------------------------------------------------

test_that("review B #8: knitr::knit_exit() does not make the render fail with 'hooks were not installed' (rule 2.5.2)", {
  src <- c(
    "Before `r v`{.num} and [a | b]{if=\"flag\"}.", "",
    "```{r}", "knitr::knit_exit()", "```", "",
    "After exit `r v`{.num} and [a | b]{if=\"flag\"}."
  )
  res <- render_rmd(src, code = RB_PRE, in_process = TRUE)
  expect_false(grepl("hooks were not installed", res$message, fixed = TRUE))
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Before 7 and a.", fixed = TRUE)    # control: above the exit
})

test_that("review B ruling C: constructs below knit_exit() are outside the end-of-document check; failures above it still count (rule 2.5.2)", {
  src <- c(
    paste("Above", RB_FAIL, "here."), "",
    "```{r}", "knitr::knit_exit()", "```", "",
    "Below `r v`{.num} and [a | b]{if=\"flag\"}."
  )
  res <- render_rmd(src, code = RB_PRE, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  f <- res$knit$failures
  expect_equal(f$line, res$offset + 1L)                    # only the claim above
  expect_false("unevaluated" %in% f$kind)
  expect_false(grepl("never evaluated", res$message, fixed = TRUE))
})

# ---- 9 ----------------------------------------------------------------------

test_that("review B #9: a failed claim in an error=TRUE chunk prints only its own message, in the document and the condition log (rules 2.4.4, 2.4.5, 7.4.3)", {
  src <- c(
    paste("Earlier", RB_FAIL, "failure."), "",
    "```{r err, error=TRUE}", "claim(v, . > 100)", "```", "",
    "After `r k`{.word}."
  )
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE,
                    env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)            # draft: nothing fails
  expect_match(res$md, ". > 100", fixed = TRUE)            # control: the claim's own text
  expect_false(grepl("claims? failed|weft: [0-9]+ failures?", res$md))
  expect_false(grepl("doc\\.Rmd:[0-9]+", res$md), label = "no earlier failure's path in the output")
  cd <- res$knit$conditions
  e <- cd[cd$source == "err" & cd$class == "error", ]
  expect_gte(nrow(e), 1L)
  expect_match(e$text[1], ". > 100", fixed = TRUE)
  expect_false(any(grepl("claims? failed|doc\\.Rmd:[0-9]+", e$text)))
})

# ---- 10 and 11 --------------------------------------------------------------

test_that("review B #10: under lang: fr an English-only class in an unchosen arm is a construct error too (rules 1.6.8, 1.6.4)", {
  ok <- render_rmd("Unchosen: [`r k`{.word} | rien]{if=\"FALSE\"} and [`r c('a','b')`{.and} | rien]{if=\"FALSE\"}.",
                   code = RB_PRE, front = "lang: en", in_process = TRUE)
  expect_false(ok$failed, label = ok$message)               # control: English
  expect_match(ok$md, "Unchosen: rien and rien.", fixed = TRUE)
  for (src in c("Unchosen: [`r k`{.word} | rien]{if=\"FALSE\"}.",
                "Unchosen: [`r c('a','b')`{.and} | rien]{if=\"FALSE\"}.")) {
    res <- render_rmd(src, code = RB_PRE, front = "lang: fr", in_process = TRUE)
    expect_true(res$failed, label = src)
    expect_true("weft_construct_error" %in% res$error$class, label = src)
    expect_match(res$message, at_line(res, 1))
  }
})

test_that("review B #11: Quarto reads a project-level lang (rules 2.1.6, 1.6.5)", {
  skip_if_no_quarto()
  doc <- c("---", "title: t", "engine: knitr", "format:", "  markdown:", "    wrap: none",
           "execute:", "  echo: false", "---", "",
           "```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3", "```", "",
           "Mots `r k`{.word}.")
  run <- function(lang) {
    dir <- mk_project(list(
      "_quarto.yml" = c("project:", "  type: default", paste("lang:", lang)),
      "doc.qmd" = doc), use = FALSE)
    r <- qrender(dir, c("doc.qmd", "--to", "markdown"))
    out <- file.path(dir, "doc.md")
    r$out <- if (file.exists(out)) paste(readLines(out, warn = FALSE), collapse = "\n") else ""
    r
  }
  en <- run("en")
  expect_identical(en$status, 0L, label = en$log)           # control
  expect_match(en$out, "Mots three.", fixed = TRUE)
  fr <- run("fr")
  expect_false(identical(fr$status, 0L), label = "fr project: English .word is a construct error")
  expect_false(grepl("three", fr$out, fixed = TRUE))
})

# ---- 12 ---------------------------------------------------------------------

test_that("review B #12: a construct in a front-matter field is a 'not built yet' construct error, however weft is activated (design: scope)", {
  abstract <- c("abstract: |", "  We found [one | many]{if=\"FALSE\"} and `r 3`{.num} sites.")
  # activated by a setup chunk
  a <- render_rmd("Body `r 3`{.num}.", front = abstract, code = RB_PRE, in_process = TRUE)
  expect_true(a$failed)
  expect_true("weft_construct_error" %in% a$error$class)
  expect_match(a$message, "not built yet", ignore.case = TRUE)
  # activated through the front matter, no setup chunk
  b <- render_rmd(c("---", "title: T", abstract,
                    "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()",
                    "output:", "  md_document:", "    variant: markdown", "---", "",
                    "Body `r 3`{.num}."),
                  setup = FALSE, in_process = TRUE)
  expect_true(b$failed)
  expect_true("weft_construct_error" %in% b$error$class)
  # control: the same document with a plain abstract renders
  c0 <- render_rmd("Body `r 3`{.num}.", front = c("abstract: |", "  We found sites."),
                   code = RB_PRE, in_process = TRUE)
  expect_false(c0$failed, label = c0$message)
})

# ---- 13 ---------------------------------------------------------------------

test_that("review B #13: n=\".\" is legal inside an if span that sits inside an n span (rule 1.7.2)", {
  src <- c(
    "[# x, [and it [is | are]{n=\".\"} fine | no]{if=\"TRUE\"} | # xs [is | are]{n=\".\"}]{n=\"n\"}",
    "",
    "[# sample[ | s]{n=\".\"} [was | were]{n=\".\"} taken]{n=\"n\"}"
  )
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_false(grepl("<<weft", res$md, fixed = TRUE))
  expect_match(res$md, "and it is fine", fixed = TRUE)
  expect_match(res$md, "1 sample was taken", fixed = TRUE)  # control
})

# ---- 14 ---------------------------------------------------------------------

test_that("review B #14: a project text-stage formatter acts on an if span's chosen arm (rule 1.5.7, 1.4.8)", {
  res <- render_rmd(
    "Up: `r s`{.up} and [shout | no]{if=\"TRUE\" .up}.",
    code = RB_PRE, format = "knit", in_process = TRUE,
    files = list("_weft.yml" = c("formatters:", "  .up:", "    function: base::toupper",
                                 "    stage: text"))
  )
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Up: HELLO", fixed = TRUE)          # control
  expect_match(res$md, "and SHOUT.", fixed = TRUE)
})

# ---- 15 ---------------------------------------------------------------------

test_that("review B #15: a cached chunk whose label has a space is replayed, so its severity condition still fails the render (rules 2.9.1, 7.4.1, 7.4.2)", {
  dir <- withr::local_tempdir()
  doc <- c("```{r model fit, cache=TRUE}",
           "cat('ran\\n', file = 'ran.txt', append = TRUE)",
           "message(\"boundary (singular) fit: see help('isSingular')\")",
           "```", "", "Text `r k`.")
  r1 <- render_rmd(doc, code = RB_PRE, dir = dir)
  expect_true(r1$failed)                                    # control: first render
  r2 <- render_rmd(doc, code = RB_PRE, dir = dir)
  expect_equal(length(readLines(file.path(dir, "ran.txt"))), 1L,
               label = "the second render was served from the cache")
  expect_true(r2$failed)
  expect_match(r2$message, "singular", fixed = TRUE)
})

# ---- 16 ---------------------------------------------------------------------

test_that("review B #16: span-like text in a raw HTML attribute is not a construct (rule 1.9.1)", {
  src <- c("Raw: <span title=\"[a]{if='FALSE'}\">t</span>.", "",
           "Control: [yes | no]{if=\"flag\"}.")
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "<span title=\"[a]{if='FALSE'}\">t</span>", fixed = TRUE)
  expect_match(res$md, "Control: yes.", fixed = TRUE)
  draft <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE,
                      env = c(WEFT_DRAFT = "1"))
  expect_false(grepl("<<weft", draft$md, fixed = TRUE))
})

# ---- 17 ---------------------------------------------------------------------

test_that("review B #17: adjacent emphasis constructs still read as emphasis (rules 1.4.3)", {
  skip_if_not(rmarkdown::pandoc_available())
  src <- c("Single: [lone]{.em}.", "",
           "Adjacent: [rose]{.em}[sharply]{.em} and [a]{.em}[b]{.strong} and `r n`{.num .em}`r n`{.num .em}.")
  res <- render_rmd(src, code = RB_PRE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  html <- suppressWarnings(system2(
    rmarkdown::pandoc_exec(), c("-f", "markdown", "-t", "html"),
    input = res$text, stdout = TRUE, stderr = TRUE))
  html <- gsub("<!--.*?-->", "", paste(html, collapse = "\n"))
  expect_match(html, "<em>lone</em>", fixed = TRUE)         # control
  expect_match(html, "<em>rose</em>\\s*<em>sharply</em>")
  expect_match(html, "<em>a</em>\\s*<strong>b</strong>")
  expect_match(html, "<em>1</em>\\s*<em>1</em>")
  expect_false(grepl("*", html, fixed = TRUE), label = "no literal asterisks")
})

# ---- ruling B ---------------------------------------------------------------

test_that("review B ruling B: a failed guard is reported by its phrase as printed, markdown and all (rules 2.6.2, 2.6.3)", {
  src <- c(
    "[Plain phrase here]{if=\"noflag\"} and",
    "",
    "[All `r k`{.word} models **rise**]{if=\"noflag\"}."
  )
  res <- render_rmd(src, code = RB_PRE, in_process = TRUE)
  expect_true(res$failed)
  expect_match(res$message, "Plain phrase here", fixed = TRUE)           # control
  expect_match(res$message, "All three models **rise**", fixed = TRUE)
  expect_false(grepl("`r k`", res$message, fixed = TRUE))
})

# ---- ruling E ---------------------------------------------------------------

test_that("review B ruling E: draft mode in a set-up project writes <doc>.weft-failures.json; a clean render removes it; no project, no file (rule 9.4.2)", {
  dir <- withr::local_tempdir()
  bad <- c("Intro.", "", paste("Value", RB_FAIL, "here."))
  proj <- list("_weft.yml" = "digits: 3")
  r1 <- render_rmd(bad, code = RB_PRE, format = "knit", in_process = TRUE, dir = dir,
                   files = proj, env = c(WEFT_DRAFT = "1"))
  expect_false(r1$failed, label = r1$message)
  json <- file.path(r1$dir, "doc.weft-failures.json")
  expect_true(file.exists(json))
  if (file.exists(json)) {
    x <- jsonlite::fromJSON(json, simplifyVector = FALSE)
    expect_length(x, 1L)
    expect_true(all(c("source", "kind", "file", "line", "chunk", "expr", "detail") %in% names(x[[1]])))
    expect_equal(x[[1]]$kind, "failed claim")
    expect_equal(x[[1]]$line, r1$offset + 3L)
    expect_match(x[[1]]$file, "doc.Rmd", fixed = TRUE)
  }
  # a later render with no failures removes the stale file
  r2 <- render_rmd(c("Intro.", "", "Value `r k`{.word}."), code = RB_PRE, format = "knit",
                   in_process = TRUE, dir = dir, files = proj, env = c(WEFT_DRAFT = "1"))
  expect_false(r2$failed, label = r2$message)
  expect_false(file.exists(json))
  # outside a set-up project (no _weft.yml) nothing is written
  r3 <- render_rmd(bad, code = RB_PRE, format = "knit", in_process = TRUE,
                   env = c(WEFT_DRAFT = "1"))
  expect_false(r3$failed, label = r3$message)
  expect_false(file.exists(file.path(r3$dir, "doc.weft-failures.json")))
})
