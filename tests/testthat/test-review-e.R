# Regression tests for the review of stage 1e (dev/review-1e.md), as ruled in
# design-1e.md ("Rulings on the review of stage 1e"). Each test names the
# finding it covers. Every fixture is written to a temporary folder.

# a one-case-at-a-time document builder: front matter, weft setup, then body
re_doc <- function(body, params = NULL, setup = TRUE) {
  c("---", "title: \"t\"",
    if (length(params)) c("params:", paste0("  ", params)),
    "---", "",
    if (setup) c("```{r setup, include=FALSE}", "weft::weft_setup()", "```", ""),
    body, "")
}

# ---- finding 1: a chunk cached before weft_setup() ----------------------------

test_that("review E #1: a chunk cached before weft_setup() is not cached, so a later case does not see an earlier case's data (3.7.2, no chunk cache)", {
  lines <- c(
    "---", "title: \"t\"", "params:", "  k: 1", "---", "",
    "```{r data, cache=TRUE, include=FALSE}", "n <- params$k", "```", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
    "Found [one site | # sites]{n=\"n\"}.", "")
  path <- e1_write(lines, "c.Rmd")
  r <- e1_with_libs(rehearse(path, list(one = list(k = 1), five = list(k = 5))))
  # control: the first case chose arm 1
  expect_equal(r$cases$one$chosen$arm, 1L)
  expect_equal(r$cases$five$chosen$arm, 2L)
  expect_equal(e1_snapshot(dirname(path)), "c.Rmd")
})

# ---- finding 2: the same span twice on one line --------------------------------

test_that("review E #2: when a line holds the same span twice, the choice is credited to the span that made it (3.7.3)", {
  lines <- re_doc(c(
    "```{r data, include=FALSE}", "n <- params$count", "flag <- params$flag", "```", "",
    "Dup [A [x | y]{if=\"flag\"} | B [x | y]{if=\"flag\"}]{if=\"n > 1\"}."),
    params = c("count: 1", "flag: false"))
  p <- e1_write(lines, "dup.Rmd")
  a <- arms(p)
  inner <- sort(unique(a$span[a$expr == "flag"]))
  expect_length(inner, 2L)
  outer <- unique(a$span[a$expr == "n > 1"])
  r <- e1_with_libs(rehearse(p, list(one = list(count = 1, flag = FALSE))))
  ch <- r$cases$one$chosen
  # control: the outer span chose arm 2 (B)
  expect_equal(ch$arm[ch$span == outer], 2L)
  # the inner span in B (the second) chose arm 2; the one in A did not run
  expect_equal(ch$arm[ch$span == inner[2]], 2L)
  expect_false(inner[1] %in% ch$span)
  expect_true(inner[1] %in% r$unevaluated$span)
  expect_false(inner[2] %in% r$unevaluated$span)
})

# ---- finding 3: a caption in a chunk that does not run -------------------------

test_that("review E #3: a caption span in a chunk that does not run is not credited, and the one that ran is (3.7.3)", {
  lines <- re_doc(c(
    "```{r data, include=FALSE}", "d <- params$d", "```", "",
    "```{r c1, eval=params$show, echo=FALSE, fig.cap='Cap [one | many]{n=\"d\"}'}",
    "plot(1)", "```", "",
    "```{r c2, echo=FALSE, fig.cap='Cap [one | many]{n=\"d\"}'}",
    "plot(2)", "```"),
    params = c("show: true", "d: 1"))
  p <- e1_write(lines, "z.Rmd")
  l1 <- e1_line(lines, "{r c1,")
  l2 <- e1_line(lines, "{r c2,")
  r <- e1_with_libs(rehearse(p, list(hide = list(d = 3, show = FALSE))))
  ch <- r$cases$hide$chosen
  expect_true(l2 %in% ch$line)
  expect_equal(ch$arm[ch$line == l2], 2L)
  expect_false(l1 %in% ch$line)
  expect_true(l1 %in% r$unevaluated$line)
  expect_false(l2 %in% r$unevaluated$line)
})

# ---- finding 4: front-matter spans ---------------------------------------------

test_that("review E #4: a front-matter span is matched, so each case chooses one of its arms (3.7.1, 3.7.3)", {
  lines <- c(
    "---", "title: \"t\"",
    "abstract: |",
    "  Abstract [one | many]{n=\"params$a\"}.",
    "params:", "  a: 2",
    "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()",
    "---", "", "Body.", "")
  p <- e1_write(lines, "fm.Rmd")
  expect_equal(unique(arms(p)$context), "front-matter")  # control
  r <- e1_with_libs(rehearse(p, list(two = list(), one = list(a = 1))))
  expect_equal(r$cases$two$chosen$arm, 2L)
  expect_equal(r$cases$one$chosen$arm, 1L)
  expect_equal(nrow(r$unreached), 0L)
  expect_equal(nrow(r$unevaluated), 0L)
})

# ---- finding 5: literal weft_str() spans ---------------------------------------

test_that("review E #5: a literal weft_str() span is matched, so each case chooses one of its arms (3.7.1, 3.7.3)", {
  lines <- re_doc(c(
    "```{r lit, results='asis', echo=FALSE}",
    "v <- params$v",
    "cat(weft_str(\"Lit [yes | no]{if=\\\"v\\\"}\"), \"\\n\")",
    "```"), params = "v: true")
  p <- e1_write(lines, "s.Rmd")
  expect_equal(unique(arms(p)$context), "weft_str")  # control
  r <- e1_with_libs(rehearse(p, list(t = list(v = TRUE), f = list(v = FALSE))))
  expect_equal(r$cases$t$chosen$arm, 1L)
  expect_equal(r$cases$f$chosen$arm, 2L)
  expect_equal(nrow(r$unreached), 0L)
  expect_equal(nrow(r$unevaluated), 0L)
})

# ---- finding 6: .qmd working directory -----------------------------------------

test_that("review E #6: a .qmd is knitted in the document's folder, so relative reads and child= work (contract: working directory is the document's)", {
  lines <- c(
    "---", "title: \"t\"", "engine: knitr", "---", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()",
    "here <- file.exists('data.csv')", "```", "",
    "Data [present | absent]{if=\"here\"}.", "",
    "```{r kid, child='part.Rmd'}", "```", "")
  p <- e1_write(lines, "w.qmd", files = list(
    "data.csv" = "a,b", "part.Rmd" = "Child text.",
    "_quarto.yml" = "project:\n  type: default", "_weft.yml" = "ci_level: 0.9"))
  r <- e1_with_libs(rehearse(p, list(x = list())))
  expect_true(is.na(r$cases$x$error), label = r$cases$x$error)
  expect_equal(r$cases$x$chosen$arm, 1L)
})

# ---- finding 7: !r defaults ----------------------------------------------------

test_that("review E #7: !r param defaults are evaluated in the document's folder, not the caller's session (3.7.4, before anything runs)", {
  lines <- c(
    "---", "title: \"t\"", "params:", "  v: !r readLines('v.txt')",
    "  side: !r file.create('SIDE.txt')", "---", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
    "V [one | many]{n=\"length(params$v)\"}.", "")
  p <- e1_write(lines, "pr.Rmd", files = list("v.txt" = c("a", "b", "c")))
  elsewhere <- normalizePath(tempfile("weft-1e-elsewhere-"), mustWork = FALSE)
  dir.create(elsewhere)
  # an unknown name is an error, and no !r expression ran in the caller's folder
  withr::with_dir(elsewhere, {
    expect_error(e1_with_libs(rehearse(p, list(x = list(nosuch = 1)))), "nosuch")
  })
  expect_false(file.exists(file.path(elsewhere, "SIDE.txt")))
  # the defaults are read in the document's folder: three lines -> arm 2
  r <- withr::with_dir(elsewhere, e1_with_libs(rehearse(p, list(x = list()))))
  expect_true(is.na(r$cases$x$error), label = r$cases$x$error)
  expect_equal(r$cases$x$chosen$arm, 2L)
  expect_false(file.exists(file.path(elsewhere, "SIDE.txt")))
})

# ---- finding 8 and ruling c: a span that evaluated but chose no arm -------------

test_that("review E #8/c: a span that was evaluated and chose no arm is in chosen with arm NA and is not unevaluated (3.7.3)", {
  lines <- re_doc(c(
    "```{r data, include=FALSE}", "d <- params$d", "```", "",
    "Change [rose | fell]{sign=\"d\"}.", "",
    "Cond [x | y]{if=\"nosuch > 1\"}.", "",
    "Fine [a | b]{if=\"TRUE\"}."), params = "d: 0")
  p <- e1_write(lines, "o.Rmd")
  r <- e1_with_libs(rehearse(p, list(off = list())))
  ch <- r$cases$off$chosen
  a <- r$arms
  sg <- unique(a$span[a$key == "sign"])
  cd <- unique(a$span[a$expr == "nosuch > 1"])
  fine <- unique(a$span[a$expr == "TRUE"])
  # control: the ordinary span chose arm 1
  expect_equal(ch$arm[ch$span == fine], 1L)
  for (s in c(sg, cd)) {
    expect_true(s %in% ch$span)
    expect_true(is.na(ch$arm[ch$span == s]))
    expect_true(is.na(ch$role[ch$span == s]))
    expect_false(s %in% r$unevaluated$span)
  }
})

# ---- finding 9: case names that collide with columns ---------------------------

test_that("review E #9: a case named after a column of the result is an error before anything runs (3.7.3)", {
  path <- e1_write(E1_STOP_LINES, "stop.Rmd")
  dir <- dirname(path)
  for (nm in c("file", "span", "reached")) {
    cases <- list(a = list(boom = FALSE), list(boom = FALSE))
    names(cases)[2] <- nm
    expect_error(e1_with_libs(rehearse(path, cases)), class = "weft_rehearse_error",
                 regexp = paste0("cannot be named `", nm, "`"), fixed = TRUE, label = nm)
    # nothing ran: the setup chunk writes ran.txt whenever the document is knitted
    expect_false(file.exists(file.path(dir, "ran.txt")), label = nm)
  }
  # control: a name that is not a column knits the document
  e1_with_libs(rehearse(path, list(a = list(boom = FALSE))))
  expect_true(file.exists(file.path(dir, "ran.txt")))
})

# ---- finding 10: the project .Rprofile -----------------------------------------

test_that("review E #10: the child reads the project's .Rprofile, as a render does (3.7.2, 9.2.1)", {
  lines <- c(
    "---", "title: \"t\"", "---", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()",
    "k <- getOption('e1.profile', 1)", "```", "",
    "Profile [one | many]{n=\"k\"}.", "")
  p <- e1_write(lines, "prof.Rmd", files = list(
    "_weft.yml" = "ci_level: 0.9", ".Rprofile" = "options(e1.profile = 5)"))
  r <- e1_with_libs(rehearse(p, list(x = list())))
  expect_true(is.na(r$cases$x$error), label = r$cases$x$error)
  expect_equal(r$cases$x$chosen$arm, 2L)
})

# ---- finding 11: non-English lang ----------------------------------------------

test_that("review E #11: under a language weft does not ship, a two-arm or four-arm n is a construct error with no rows (1.6.4, 1.6.5)", {
  lines <- c("---", "lang: pl", "---", "",
             "[a | b]{n=\"k\"} and [a | b | c | d]{n=\"k\"}.", "",
             "Fine [x | y]{if=\"g\"}.", "")
  x <- arms(e1_write(lines, "pl.Rmd"))
  err <- attr(x, "errors")
  expect_gte(NROW(err), 2L)
  expect_false("n" %in% x$key)
  # control: the language-free span is still listed
  expect_true("g" %in% x$expr)
})

# ---- findings 12 and f: multi-line arms, and r$arms is arms(file) --------------

test_that("review E #12/f: newlines in an arm are collapsed in the print methods; r$arms keeps the weft_arms class, the errors attribute and the file values", {
  lines <- re_doc(c(
    "Multi [one", "line | many", "lines]{n=\"params$n\"} end.", "",
    "Bad [a | b | c | d | e]{n=\"params$n\"}."), params = "n: 1")
  p <- e1_write(lines, "m.Rmd")
  a_out <- capture.output(print(arms(p)))
  expect_false(any(grepl("^line", a_out)))
  expect_true(any(grepl("one line", a_out, fixed = TRUE)))  # control
  r <- withr::with_dir(dirname(p), e1_with_libs(rehearse("m.Rmd", list(x = list()))))
  r_out <- capture.output(print(r))
  expect_false(any(grepl("^line", r_out)))
  expect_true(any(grepl("one line", r_out, fixed = TRUE)))
  # f: the same object apart from the added columns
  base <- withr::with_dir(dirname(p), arms("m.Rmd"))
  expect_s3_class(r$arms, "weft_arms")
  expect_gte(NROW(attr(base, "errors")), 1L)  # control: there is an error
  expect_equal(attr(r$arms, "errors"), attr(base, "errors"))
  expect_identical(r$arms$file, base$file)
})

# ---- finding 13: duplicate basenames in the errors section ---------------------

test_that("review E #13: with duplicate basenames the errors section names files as the tree does (3.7.1)", {
  d <- tempfile("weft-1e-dup-"); dir.create(d)
  bad <- c("Fine [ok | no]{if=\"g\"}.", "", "Bad [a | b | c | d | e]{n=\"k\"}.", "")
  x <- e1_write(bad, "doc.Rmd", file.path(d, "x"))
  y <- e1_write(bad[1:2], "doc.Rmd", file.path(d, "y"))
  out <- capture.output(print(arms(c(x, y))))
  expect_true(any(grepl("x/doc\\.Rmd", out)))  # control: the tree names the folder
  err_line <- grep("doc\\.Rmd:3", out, value = TRUE)
  expect_gte(length(err_line), 1L)
  expect_true(all(grepl("x/doc\\.Rmd:3", err_line)))
})
