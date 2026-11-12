# Regression tests for the review of package 2d (dev/review-2d.md), against the rulings at the end of
# dev/design-2d.md. Findings 1 to 11 and questions A to J. Written before the fixes: the tests that
# assert the ruled behaviour fail until then; the "control" tests pass today. Made-up values only.
# ASCII only: non-ASCII is written as \uXXXX.
if (!exists("d2_run")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])
d2_need()

# ---- #1: a render started inside a chunk -------------------------------------------------------

d2r_nested <- function(inner_setup) d2_memo(paste0("nested-", inner_setup), function() {
  inner <- c(if (inner_setup) c("```{r isetup, include=FALSE}", "weft::weft_setup()", "```", ""), "Inner `r 2+2`.")
  doc <- c("## Out", "", "```{r ow}", "warning('outer warn before')", "```", "", "Before `r k0`.", "",
           "```{r nest, include=FALSE}",
           "rmarkdown::render('inner.Rmd', rmarkdown::md_document(), quiet = TRUE, envir = new.env())",
           "```", "", "Outer `r k1`.")
  d2_run(doc, code = "k0 <- 10; k1 <- 11", files = list("inner.Rmd" = inner), format = "md")
})

test_that("review 2d #1: a nested rmarkdown::render() leaves the outer ledger complete (inner with its own setup)", {
  res <- d2r_nested(TRUE)
  e <- d2_ledger(res)
  expect_length(d2_pick(e, expr = "k0"), 1L)
  expect_length(d2_pick(e, expr = "k1"), 1L)
  expect_identical(d2_one(e, expr = "k0")$text, "10")
})

test_that("review 2d #1: a nested render leaves the outer condition log complete", {
  res <- d2r_nested(TRUE)
  expect_length(d2_pick(d2_conds(res), source = "ow", class = "warning"), 1L)
})

test_that("review 2d #1: the same when the inner document never calls weft_setup()", {
  res <- d2r_nested(FALSE)
  e <- d2_ledger(res)
  expect_length(d2_pick(e, expr = "k0"), 1L)
  expect_length(d2_pick(e, expr = "k1"), 1L)
  expect_length(d2_pick(d2_conds(res), source = "ow", class = "warning"), 1L)
})

test_that("review 2d #1: the inner render is its own top-level knit and writes its own files", {
  res <- d2r_nested(TRUE)
  p <- d2_path(res$dir, source = "inner.Rmd", output = "inner")
  expect_true(file.exists(p))
  expect_length(d2_pick(d2_entries(p), expr = "2 + 2"), 1L)
  # and the outer entries are not in the inner's file
  expect_length(d2_pick(d2_entries(p), expr = "k1"), 0L)
})

test_that("review 2d #1 control: with no nested render the outer ledger has both entries and the warning", {
  doc <- c("```{r ow}", "warning('outer warn before')", "```", "", "Before `r k0`.", "", "Outer `r k1`.")
  res <- d2_run(doc, code = "k0 <- 10; k1 <- 11", format = "md")
  expect_length(d2_pick(d2_ledger(res), expr = "k0"), 1L)
  expect_length(d2_pick(d2_ledger(res), expr = "k1"), 1L)
  expect_length(d2_pick(d2_conds(res), source = "ow"), 1L)
})

# ---- #2: doc.Rmd beside doc.qmd --------------------------------------------------------------------

test_that("review 2d #2: rendering doc.Rmd beside doc.qmd files the ledger under doc.Rmd", {
  res <- d2_run("Rmd version `r k`.", code = "k <- 1", files = list("doc.qmd" = "Qmd version `r 2`."))
  p <- d2_path(res$dir, source = "doc.Rmd")
  expect_true(file.exists(p))
  expect_identical(d2_header(p)$source, "doc.Rmd")
  expect_identical(d2_one(d2_entries(p), expr = "k")$file, "doc.Rmd")
  expect_true(file.exists(d2_path(res$dir, source = "doc.Rmd", conditions = TRUE)))
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger", "doc.qmd")))
})

test_that("review 2d #2: the same through rmarkdown::render(), and for another file name", {
  res <- d2_run("Rmd version `r k`.", code = "k <- 1", files = list("doc.qmd" = "Qmd version `r 2`."), format = "md")
  expect_true(file.exists(d2_path(res$dir, source = "doc.Rmd")))
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger", "doc.qmd")))
  res2 <- d2_run("Rmd version `r k`.", code = "k <- 1", name = "rep", files = list("rep.qmd" = "Qmd `r 2`."))
  expect_true(file.exists(d2_path(res2$dir, source = "rep.Rmd", output = "rep")))
  expect_false(dir.exists(file.path(res2$dir, "_weft", "ledger", "rep.qmd")))
})

test_that("review 2d #2 control: an .Rmd with no .qmd beside it is filed under itself", {
  res <- d2_run("Rmd version `r k`.", code = "k <- 1")
  expect_identical(d2_header(d2_path(res$dir, source = "doc.Rmd"))$source, "doc.Rmd")
})

test_that("review 2d #2 control: under Quarto the .qmd, not the .rmarkdown copy, names the source", {
  skip_if_no_quarto()
  dir <- d2r_qdir(d2r_qdoc("Value `r k` here."))
  r <- qrender(dir, "doc.qmd")
  expect_identical(r$status, 0L, label = r$log)
  expect_identical(d2_header(d2_path(dir, source = "doc.qmd"))$source, "doc.qmd")
  expect_false(dir.exists(file.path(dir, "_weft", "ledger", "doc.rmarkdown")))
})

# ---- #3: symbolic links ----------------------------------------------------------------------------

# a set-up project `proj` and a folder `outside` that is not in it, under one temporary folder
d2r_link_case <- function(case, relative = FALSE, env = parent.frame()) {
  base <- normalizePath(withr::local_tempdir(.local_envir = env))
  dir <- file.path(base, "proj"); out <- file.path(base, "outside")
  dir.create(dir); dir.create(out)
  wf <- function(from, to) {   # `to` is the link, `from` its target
    target <- if (relative) file.path(paste(rep("..", length(strsplit(sub(paste0("^", dir, "/"), "", to), "/")[[1]])), collapse = "/"), "outside") else from
    expect_true(file.symlink(target, to))
  }
  switch(case,
    ledger = { dir.create(file.path(dir, "_weft")); wf(out, file.path(dir, "_weft", "ledger")); link <- "ledger" },
    weft = { wf(out, file.path(dir, "_weft")); link <- "_weft" },
    folder = { dir.create(file.path(dir, "_weft", "ledger"), recursive = TRUE)
               wf(out, file.path(dir, "_weft", "ledger", "doc.Rmd")); link <- "doc.Rmd" },
    file = { dir.create(file.path(dir, "_weft", "ledger", "doc.Rmd"), recursive = TRUE)
             writeLines("keep", file.path(out, "target.jsonl"))
             expect_true(file.symlink(file.path(out, "target.jsonl"), file.path(dir, "_weft", "ledger", "doc.Rmd", "doc.jsonl")))
             link <- "doc.jsonl" })
  list(dir = dir, out = out, link = link)
}

d2r_expect_refused <- function(case, relative = FALSE) {
  skip_on_os("windows")
  lc <- d2r_link_case(case, relative)
  res <- d2_run(d2r_warn_doc(12), dir = lc$dir)
  got <- list.files(lc$out, recursive = TRUE, all.files = TRUE)
  if (case == "file") expect_identical(got, "target.jsonl") else expect_length(got, 0L)
  if (case == "file") expect_identical(readLines(file.path(lc$out, "target.jsonl")), "keep")
  w <- d2r_ledger_warnings(res)
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), lc$link, fixed = TRUE)
  # neither file is written in the project either
  if (case == "file") {
    expect_false(file.exists(d2_path(lc$dir, conditions = TRUE)))
    expect_true(nzchar(Sys.readlink(d2_path(lc$dir))))
  } else {
    expect_false(file.exists(d2_path(lc$dir)))
    expect_false(file.exists(d2_path(lc$dir, conditions = TRUE)))
  }
}

test_that("review 2d #3: a symlinked _weft/ledger is not written through, and one warning names the link", {
  d2r_expect_refused("ledger")
})
test_that("review 2d #3: a symlinked _weft is not written through", {
  d2r_expect_refused("weft")
})
test_that("review 2d #3: a symlinked source folder under _weft/ledger is not written through", {
  d2r_expect_refused("folder")
})
test_that("review 2d #3: a symlinked ledger file is not replaced, neither file is written", {
  d2r_expect_refused("file")
})
test_that("review 2d #3: a link with a relative target is refused too", {
  d2r_expect_refused("ledger", relative = TRUE)
})
test_that("review 2d #3 control: with no link both files are written and nothing outside is touched", {
  skip_on_os("windows")
  base <- normalizePath(withr::local_tempdir())
  dir <- file.path(base, "proj"); dir.create(dir); dir.create(file.path(base, "outside"))
  res <- d2_run(d2r_warn_doc(12), dir = dir)
  expect_true(file.exists(d2_path(dir)))
  expect_true(file.exists(d2_path(dir, conditions = TRUE)))
  expect_length(list.files(file.path(base, "outside"), recursive = TRUE), 0L)
  expect_length(d2r_ledger_warnings(res), 0L)
})

# ---- #4: non-ASCII in the source's path -----------------------------------------------------------

d2r_non_ascii <- function(name, sub = NULL) {
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the session is not UTF-8")
  dir <- normalizePath(withr::local_tempdir(.local_envir = parent.frame()))
  if (!is.null(sub)) {
    ok <- tryCatch(dir.create(file.path(dir, sub), recursive = TRUE), warning = function(w) FALSE)
    skip_if_not(isTRUE(ok) && dir.exists(file.path(dir, sub)), "the file system cannot hold the folder name")
  }
  nm <- if (is.null(sub)) name else file.path(sub, name)
  res <- tryCatch(d2_run("A `r k`.", code = "k <- 1", dir = dir, name = nm),
                  error = function(e) skip("the file system cannot hold the file name"))
  list(dir = dir, res = res, src = paste0(nm, ".Rmd"))
}

test_that("review 2d #4: a non-ASCII folder under the root still writes both files, with the UTF-8 path", {
  z <- d2r_non_ascii("doc", "rapports-é")
  expect_length(d2r_ledger_warnings(z$res), 0L)
  p <- d2_path(z$dir, source = z$src, output = "doc")
  expect_true(file.exists(p))
  expect_true(file.exists(d2_path(z$dir, source = z$src, output = "doc", conditions = TRUE)))
  expect_identical(d2_header(p)$source, "rapports-é/doc.Rmd")
  expect_identical(d2_one(d2_entries(p), expr = "k")$file, "rapports-é/doc.Rmd")
})

test_that("review 2d #4: a non-ASCII file name at the root, and in a folder, write both files", {
  a <- d2r_non_ascii("Résumé")
  expect_length(d2r_ledger_warnings(a$res), 0L)
  pa <- d2_path(a$dir, source = a$src, output = "Résumé")
  expect_true(file.exists(pa))
  expect_identical(d2_one(d2_entries(pa), expr = "k")$file, "Résumé.Rmd")
  b <- d2r_non_ascii("Résumé", "x")
  expect_true(file.exists(d2_path(b$dir, source = b$src, output = "Résumé")))
  expect_true(file.exists(d2_path(b$dir, source = b$src, output = "Résumé", conditions = TRUE)))
})

test_that("review 2d #4 control: a non-ASCII heading and an ASCII source work", {
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the session is not UTF-8")
  res <- d2_run(c("## Zürich", "", "A `r k`."), code = "k <- 1")
  expect_length(d2r_ledger_warnings(res), 0L)
  expect_identical(d2_one(d2_ledger(res), expr = "k")$section, "zürich")
})

# ---- #5: a condition-log line with null or missing text -------------------------------------------

d2r_bad_text <- function(variant) {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  d2_run(d2r_warn_doc(12), dir = dir)
  p <- d2_path(dir, conditions = TRUE)
  ln <- d2_lines(p)
  head <- "{\"from\":\"chunk\",\"source\":\"load\",\"class\":\"warning\",\"normalised\":\"Removed <n> rows\""
  bad <- switch(variant,
    null = paste0(head, ",\"text\":null}"),
    missing = paste0(head, "}"),
    wrongtype = paste0(head, ",\"text\":5}"))
  writeLines(c(ln[1], bad), p, useBytes = TRUE)
  res <- d2_run(c(d2r_warn_doc(12), "", "More `r 2`."), dir = dir)
  list(dir = dir, res = res)
}

for (v in c("null", "missing")) local({
  v <- v
  test_that(paste0("review 2d #5: a log line whose text is ", v, " does not stop either file being written"), {
    z <- d2r_bad_text(v)
    expect_length(d2r_ledger_warnings(z$res), 0L)
    expect_length(d2_pick(d2_ledger(z$res), expr = "2"), 1L)      # the ledger was rewritten
    cl <- d2_conds(z$res)
    load <- d2_pick(cl, source = "load", class = "warning")
    expect_length(load, 1L)
    expect_identical(load[[1]]$text, "Removed 12 rows")           # this knit's text
  })
})

test_that("review 2d #5: a bad line is skipped, so a later good line of the same key keeps its edited text", {
  dir <- withr::local_tempdir()
  d2_run(d2r_warn_doc(12), dir = dir)
  p <- d2_path(dir, conditions = TRUE)
  head <- "{\"from\":\"chunk\",\"source\":\"load\",\"class\":\"warning\",\"normalised\":\"Removed <n> rows\""
  writeLines(c(d2_lines(p)[1], paste0(head, ",\"text\":null}"), paste0(head, ",\"text\":\"Removed 12 rows (edited)\"}")),
             p, useBytes = TRUE)
  res <- d2_run(c(d2r_warn_doc(12), "", "More `r 2`."), dir = dir)
  expect_length(d2r_ledger_warnings(res), 0L)
  expect_identical(d2_one(d2_conds(res), source = "load")$text, "Removed 12 rows (edited)")
})

test_that("review 2d #5 control: a good line's hand-edited text is still carried forward", {
  dir <- withr::local_tempdir()
  d2_run(d2r_warn_doc(12), dir = dir)
  p <- d2_path(dir, conditions = TRUE)
  writeLines(sub("Removed 12 rows\"}", "Removed 12 rows (edited)\"}", d2_lines(p), fixed = TRUE), p, useBytes = TRUE)
  res <- d2_run(d2r_warn_doc(12), dir = dir)
  expect_identical(d2_one(d2_conds(res), source = "load")$text, "Removed 12 rows (edited)")
})

# ---- #6: integer64 --------------------------------------------------------------------------------

test_that("review 2d #6: ledger_raw() of an integer64 is its value when a double holds it exactly", {
  skip_if_not_installed("bit64")
  expect_equal(weft:::ledger_raw(bit64::as.integer64("5")), 5)
  expect_equal(weft:::ledger_raw(bit64::as.integer64("-3")), -3)
  expect_equal(weft:::ledger_raw(bit64::as.integer64("5000000000")), 5e9)
  r <- weft:::ledger_raw(bit64::as.integer64("9007199254740993"))     # 2^53 + 1: no double holds it
  expect_true(is.null(r) || (length(r) == 1L && is.na(r)))
})

test_that("review 2d #6: an integer64 in prose has raw 5e+09 in the ledger, and null when no double holds it", {
  skip_if_not_installed("bit64")
  res <- d2_render(c("Big int `r b` here and `r big` there."),
                   code = "b <- bit64::as.integer64('5000000000'); big <- bit64::as.integer64('9007199254740993')")
  e <- d2_ledger(res)
  expect_identical(d2_one(e, expr = "b")$text, "5000000000")
  expect_equal(d2_one(e, expr = "b")$raw, 5e9)
  expect_null(d2_one(e, expr = "big")$raw)
  expect_true(any(grepl("\"raw\":5e+09,", d2_lines(d2_path(res$dir)), fixed = TRUE)))
})

test_that("review 2d #6 control: a double and an integer keep their raw", {
  expect_equal(weft:::ledger_raw(5), 5)
  expect_equal(weft:::ledger_raw(5L), 5)
})

# ---- #7: gfm and typst under Quarto -----------------------------------------------------------------

test_that("review 2d #7: `format: gfm` without -o names the ledger after the source and raises no -o warning", {
  skip_if_no_quarto()
  dir <- d2r_qdir(d2r_qdoc("Value `r k` here.", "gfm"))
  r <- qrender(dir, "doc.qmd")
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(d2_path(dir, source = "doc.qmd")))
  expect_false(grepl("WEFT_OUTPUT", r$log, fixed = TRUE))
  expect_false(grepl("not visible to weft", r$log, fixed = TRUE))
})

test_that("review 2d #7: `format: typst` without -o is quiet as well", {
  skip_if_no_quarto()
  dir <- d2r_qdir(d2r_qdoc("Value `r k` here.", "typst"))
  r <- qrender(dir, "doc.qmd")
  skip_if(r$status != 0L, "this Quarto cannot render typst here")
  expect_true(file.exists(d2_path(dir, source = "doc.qmd")))
  expect_false(grepl("WEFT_OUTPUT", r$log, fixed = TRUE))
  expect_false(grepl("not visible to weft", r$log, fixed = TRUE))
})

test_that("review 2d #7 control: `quarto render -o other.html` still warns and uses the source's name", {
  skip_if_no_quarto()
  dir <- d2r_qdir(d2r_qdoc("Value `r k` here.", "html"))
  r <- qrender(dir, c("doc.qmd", "--to", "html", "-o", "other.html"))
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(d2_path(dir, source = "doc.qmd")))
  expect_match(r$log, "WEFT_OUTPUT", fixed = TRUE)
})

# ---- #8: lines Pandoc does not read as headings ---------------------------------------------------------

test_that("review 2d #8: heading_anchors() skips a heading inside an HTML comment", {
  a <- weft:::heading_anchors(c("## Other {#methods}", "", "M2 text.", "", "<!--", "## Hidden", "-->", "", "After comment."))
  expect_identical(a$anchor, "methods")
  expect_identical(as.integer(a$line), 1L)
})

test_that("review 2d #8: a comment that opens on the line before the heading, and one on a single line", {
  a <- weft:::heading_anchors(c("<!-- note", "## Hidden -->", "", "## Real", "", "<!-- one line -->", "", "## Next"))
  expect_identical(a$anchor, c("real", "next"))
})

test_that("review 2d #8: a heading after the comment closes counts again", {
  a <- weft:::heading_anchors(c("<!--", "## Hidden", "-->", "", "## Visible"))
  expect_identical(a$anchor, "visible")
})

test_that("review 2d #8: an ATX line with no blank line before it, after a paragraph line, is not a heading", {
  expect_identical(nrow(weft:::heading_anchors(c("Para line", "## Not a heading", "", "NH text."))), 0L)
  a <- weft:::heading_anchors(c("## Real", "", "Para line", "## Not a heading", "", "## Also real"))
  expect_identical(a$anchor, c("real", "also-real"))
})

test_that("review 2d #8 control: a heading at the start of the text, and after a blank line, is a heading", {
  expect_identical(weft:::heading_anchors(c("## First", "", "Text.", "", "## Second"))$anchor, c("first", "second"))
})

test_that("review 2d #8: entries are filed under the nearest real heading", {
  doc <- c("Intro `r x0`.", "", "## Other {#methods}", "", "M2 `r x1`.", "", "<!--", "## Hidden", "-->", "",
           "After comment `r x2`.", "", "Para line", "## Not a heading", "", "NH `r x3`.")
  res <- d2_render(doc, code = "x0 <- 0; x1 <- 1; x2 <- 2; x3 <- 3")
  e <- d2_ledger(res)
  expect_identical(d2_one(e, expr = "x0")$section, "")
  expect_identical(d2_one(e, expr = "x1")$section, "methods")
  expect_identical(d2_one(e, expr = "x2")$section, "methods")
  expect_identical(d2_one(e, expr = "x3")$section, "methods")
})

# ---- #9: an explicit {#id} is kept as written ---------------------------------------------------------

test_that("review 2d #9: an explicit {#id} that repeats an earlier anchor is kept, not given -1", {
  expect_identical(weft:::heading_anchors(c("## Methods", "", "## Other {#methods}"))$anchor, c("methods", "methods"))
})

test_that("review 2d #9: an id repeated twice, and two headings with the same explicit id, stay as written", {
  expect_identical(weft:::heading_anchors(c("## A {#x}", "", "## B {#x}", "", "## C {#x}"))$anchor, c("x", "x", "x"))
  expect_identical(weft:::heading_anchors(c("## Methods", "", "## Methods", "", "## Other {#methods-1}"))$anchor,
                   c("methods", "methods-1", "methods-1"))
})

test_that("review 2d #9: a generated anchor after an explicit one of the same name still takes a suffix", {
  expect_identical(weft:::heading_anchors(c("## Other {#methods}", "", "## Methods"))$anchor, c("methods", "methods-1"))
})

test_that("review 2d #9: adding an unrelated heading above does not re-key a section pinned with an id", {
  res <- d2_render(c("## Methods", "", "A `r x0`.", "", "## Other {#methods}", "", "B `r x1`."), code = "x0 <- 0; x1 <- 1")
  e <- d2_ledger(res)
  expect_identical(d2_one(e, expr = "x0")$section, "methods")
  expect_identical(d2_one(e, expr = "x1")$section, "methods")
})

test_that("review 2d #9 control: repeated generated headings take -1, -2 in order", {
  expect_identical(weft:::heading_anchors(c("## Methods", "", "## Methods", "", "## Methods"))$anchor,
                   c("methods", "methods-1", "methods-2"))
})

# ---- #10: a ledger folder without write permission ---------------------------------------------------------

d2r_no_perm <- function(path) {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root ignores directory permissions")
  Sys.chmod(path, "555")
  probe <- file.path(path, "probe")
  ok <- suppressWarnings(file.create(probe))
  if (ok) { unlink(probe); Sys.chmod(path, "755"); skip("the folder is writable despite chmod 555") }
}

test_that("review 2d #10: an unwritable ledger folder gives one weft_ledger_warning with the reason, and no other warning", {
  dir <- withr::local_tempdir()
  d2_run(d2r_warn_doc(12), dir = dir)
  d <- dirname(d2_path(dir))
  withr::defer(Sys.chmod(d, "755"))
  d2r_no_perm(d)
  res <- d2_run(c(d2r_warn_doc(12), "", "More `r 2`."), dir = dir)
  expect_false(res$failed)
  w <- d2r_ledger_warnings(res)
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), "doc.jsonl", fixed = TRUE)
  expect_match(conditionMessage(w[[1]]), "denied", ignore.case = TRUE)
  msgs <- d2_msgs(Filter(function(c) inherits(c, "warning"), res$conds))
  expect_false(any(grepl("cannot open file", msgs, fixed = TRUE)))
  expect_false(any(grepl(".tmp", msgs, fixed = TRUE)))
  expect_length(Filter(function(c) inherits(c, "warning") && !inherits(c, "weft_ledger_warning"), res$conds), 0L)
})

test_that("review 2d #10: an unwritable _weft/ledger, for a source with no folder yet, gives the same single warning", {
  dir <- withr::local_tempdir()
  d2_run(d2r_warn_doc(12), dir = dir)
  d <- file.path(dir, "_weft", "ledger")
  withr::defer(Sys.chmod(d, "755"))
  d2r_no_perm(d)
  res <- d2_run(d2r_warn_doc(12), dir = dir, name = "other")
  expect_false(res$failed)
  w <- d2r_ledger_warnings(res)
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), "denied", ignore.case = TRUE)
  expect_length(Filter(function(c) inherits(c, "warning") && !inherits(c, "weft_ledger_warning"), res$conds), 0L)
})

test_that("review 2d #10 control: a file where the folder should be gives one weft_ledger_warning and the render goes on", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "_weft", "ledger"), recursive = TRUE)
  writeLines("x", file.path(dir, "_weft", "ledger", "doc.Rmd"))
  res <- d2_run(d2r_warn_doc(12), dir = dir)
  expect_false(res$failed)
  expect_length(d2r_ledger_warnings(res), 1L)
})

# ---- #11: a source whose file name has a space -----------------------------------------------------------------

d2r_spaced <- function(name, sub, output_file = NULL, absolute = FALSE) {
  dir <- normalizePath(withr::local_tempdir(.local_envir = parent.frame()))
  dir.create(file.path(dir, sub))
  d <- write_doc("Value `r k`.", TRUE, "k <- 1", NULL, D2_SETUP, file.path(sub, name), "rmd", dir = dir)
  input <- if (absolute) d$input else d$name
  res <- d2r_render_to(dir, input, output_file)
  list(dir = dir, res = res, src = paste0(sub, "/", name, ".Rmd"))
}

test_that("review 2d #11: a source with a space is filed under its own name, rendered from the project root", {
  z <- d2r_spaced("a b", "my reports")
  expect_null(z$res$error)
  p <- d2_path(z$dir, source = "my reports/a b.Rmd", output = "a-b")
  expect_true(file.exists(p))
  expect_identical(d2_header(p)$source, "my reports/a b.Rmd")
  expect_identical(d2_one(d2_entries(p), expr = "k")$file, "my reports/a b.Rmd")
  expect_false(dir.exists(file.path(z$dir, "_weft", "ledger", "my reports", "a-b.Rmd")))
})

test_that("review 2d #11: the same when the input is named by an absolute path", {
  z <- d2r_spaced("a b", "my reports", absolute = TRUE)
  expect_null(z$res$error)
  p <- d2_path(z$dir, source = "my reports/a b.Rmd", output = "a-b")
  expect_true(file.exists(p))
  expect_identical(d2_header(p)$source, "my reports/a b.Rmd")
  expect_false(file.exists(d2_path(z$dir, source = "a-b.Rmd", output = "a-b")))
})

test_that("review 2d #11: another shell character in the name (an apostrophe) is mapped back too", {
  z <- d2r_spaced("d'x", "x", output_file = "dx.md")
  expect_null(z$res$error)
  p <- d2_path(z$dir, source = "x/d'x.Rmd", output = "dx")
  expect_true(file.exists(p))
  expect_identical(d2_header(p)$source, "x/d'x.Rmd")
})

test_that("review 2d #11 control: a source with no unusual character is filed under its own name", {
  z <- d2r_spaced("ab", "my reports")
  p <- d2_path(z$dir, source = "my reports/ab.Rmd", output = "ab")
  expect_true(file.exists(p))
  expect_identical(d2_header(p)$source, "my reports/ab.Rmd")
})

# ---- A: anchors that are Pandoc's ---------------------------------------------------------------------------

test_that("review 2d A: link and image targets, footnote references, raw HTML and emphasis markers are dropped from an anchor", {
  anchor <- function(h) weft:::heading_anchors(h)$anchor
  expect_identical(anchor("## See [the site](http://example.org/a)"), "see-the-site")
  expect_identical(anchor("## The _real_ data"), "the-real-data")
  expect_identical(anchor("## Some **strong** and *em* text"), "some-strong-and-em-text")
  expect_identical(anchor("## Map ![alt text](img.png) here"), "map-alt-text-here")
  expect_identical(anchor("## Results[^1] here"), "results-here")
  expect_identical(anchor("## A <span class=\"x\">bold</span> word"), "a-bold-word")
})

test_that("review 2d A: a link in a repeated heading still takes the -1 suffix of the cleaned anchor", {
  expect_identical(weft:::heading_anchors(c("## See [the site](http://a.example/x)", "", "## See the site"))$anchor,
                   c("see-the-site", "see-the-site-1"))
})

test_that("review 2d A control: a plain heading and an intraword underscore keep Pandoc's identifier", {
  expect_identical(weft:::heading_anchors("## Water quality")$anchor, "water-quality")
  expect_identical(weft:::heading_anchors("## the_real_data")$anchor, "the_real_data")
})

# ---- B: abbreviations do not end sentences ----------------------------------------------------------------------

d2r_sentences <- function() d2_memo("sentences", function() {
  doc <- c(
    "Intro sentence. For example, e.g. `r x1` sites were dry.", "",
    "Intro sentence. Mr. Wombat had `r x2`.", "",
    "Intro sentence. Dr. Wombat and Mrs. Koala saw `r x3`.", "",
    "Intro sentence. See Fig. 3 for `r x4`.", "",
    "Intro sentence. The cost was approx. `r x5` dollars vs. last year.", "",
    "Intro sentence. Samples (i.e. `r x6` of them) were kept.", "",
    "Intro sentence. Work by Koala et al. found `r x7` cases.", "",
    "It ended. so `r x8` more.", "",
    "Done. Then `r x9` ends.", "",
    "Is it? Yes, `r x10` is!")
  d2_render(doc, code = paste0("x", 1:10, " <- ", 1:10, collapse = "; "))
})

test_that("review 2d B: an abbreviation (e.g, i.e, Mr, Dr, Mrs, Fig, approx, vs, et al) does not end a sentence", {
  e <- d2_ledger(d2r_sentences())
  s <- function(x) d2_one(e, expr = x)$sentence
  expect_identical(s("x1"), "For example, e.g. 1 sites were dry.")
  expect_identical(s("x2"), "Mr. Wombat had 2.")
  expect_identical(s("x3"), "Dr. Wombat and Mrs. Koala saw 3.")
  expect_identical(s("x4"), "See Fig. 3 for 4.")
  expect_identical(s("x5"), "The cost was approx. 5 dollars vs. last year.")
  expect_identical(s("x6"), "Samples (i.e. 6 of them) were kept.")
  expect_identical(s("x7"), "Work by Koala et al. found 7 cases.")
})

test_that("review 2d B: a full stop followed by white space and a lower-case letter or a digit is no boundary", {
  e <- d2_ledger(d2r_sentences())
  expect_identical(d2_one(e, expr = "x8")$sentence, "It ended. so 8 more.")
  e2 <- d2_ledger(d2_render("It ended. 5 more `r x1` came.", code = "x1 <- 1"))
  expect_identical(d2_one(e2, expr = "x1")$sentence, "It ended. 5 more 1 came.")
})

test_that("review 2d B control: an ordinary full stop, `?` and `!` still end a sentence", {
  e <- d2_ledger(d2r_sentences())
  expect_identical(d2_one(e, expr = "x9")$sentence, "Then 9 ends.")
  expect_identical(d2_one(e, expr = "x10")$sentence, "Yes, 10 is!")
})

# ---- C: failure markers in the sentence ----------------------------------------------------------------------------

d2r_failed_doc <- c("Check `r claim(k, . > 100)` now and `r k2` too.")

test_that("review 2d C: a failure marker in `sentence` is written without its line number", {
  res <- d2_render(d2r_failed_doc, code = "k <- 3; k2 <- 4", env = c(WEFT_DRAFT = "1"))
  e <- d2_ledger(res)
  expect_true(length(e) >= 2L)
  f <- Filter(function(z) identical(z$failed, "failed claim"), e)
  expect_length(f, 1L)
  expect_match(f[[1]]$sentence, "<<weft: failed claim>>", fixed = TRUE)
  expect_match(d2_one(e, expr = "k2")$sentence, "<<weft: failed claim>>", fixed = TRUE)
  for (z in e) expect_false(grepl("<<weft:[^>]*line [0-9]", z$sentence), label = z$sentence)
})

test_that("review 2d C: inserting a line above a failed construct does not change the ledger", {
  dir <- withr::local_tempdir()
  one <- d2_render(d2r_failed_doc, code = "k <- 3; k2 <- 4", env = c(WEFT_DRAFT = "1"), dir = dir)
  e1 <- d2_lines(d2_path(dir))[-1]
  cb1 <- d2_bytes(d2_path(dir, conditions = TRUE))
  two <- d2_render(c("Padding line.", "", "Another padding line.", "", d2r_failed_doc), code = "k <- 3; k2 <- 4",
                   env = c(WEFT_DRAFT = "1"), dir = dir)
  # the header's files hash rightly changes with the source: compare everything after it
  expect_identical(d2_lines(d2_path(dir))[-1], e1)
  expect_identical(d2_bytes(d2_path(dir, conditions = TRUE)), cb1)
})

test_that("review 2d C control: a failed claim in draft mode still has failed set and text null", {
  res <- d2_render(d2r_failed_doc, code = "k <- 3; k2 <- 4", env = c(WEFT_DRAFT = "1"))
  f <- Filter(function(z) identical(z$failed, "failed claim"), d2_ledger(res))
  expect_length(f, 1L)
  expect_null(f[[1]]$text)
})

# ---- D: invisible and bidirectional characters ---------------------------------------------------------------------------

test_that("review 2d D: U+0085, U+061C, U+202A-202E and U+2066-2069 are written as lower-case escapes", {
  cps <- c(0x85, 0x61c, 0x200e, 0x202a:0x202e, 0x2066:0x2069)
  doc <- unlist(lapply(seq_along(cps), function(i) c(sprintf("Code `r intToUtf8(%d)` end.", cps[i]), "")))
  res <- d2_render(doc)
  txt <- paste(d2_lines(d2_path(res$dir))[-1], collapse = "\n")
  for (cp in cps) {
    expect_true(grepl(sprintf("\\u%04x", cp), txt, fixed = TRUE), label = sprintf("U+%04X is escaped", cp))
    expect_false(grepl(intToUtf8(cp), txt, fixed = TRUE), label = sprintf("U+%04X is not written raw", cp))
  }
})

test_that("review 2d D: the escaped line parses back to the character", {
  res <- d2_render("Code `r intToUtf8(0x202e)` end.")
  e <- d2_one(d2_ledger(res), kind = "bare")
  expect_identical(e$text, intToUtf8(0x202e))
})

test_that("review 2d D control: other non-ASCII characters are still written as themselves", {
  res <- d2_render("Code `r intToUtf8(0x00b5)` and `r intToUtf8(0x2212)` end.")
  txt <- paste(d2_lines(d2_path(res$dir))[-1], collapse = "\n")
  expect_true(grepl("µ", txt, fixed = TRUE))
  expect_true(grepl("−", txt, fixed = TRUE))
})

# ---- E: a log that git does not hold ------------------------------------------------------------------------------------

d2r_extra_doc <- c(d2r_warn_doc(12), "", "```{r extra}", "warning('Fresh problem')", "```")

test_that("review 2d E: in a repository with no commit the comparison is with the last render, and the message says so", {
  skip_if(Sys.which("git") == "")
  dir <- withr::local_tempdir()
  d2_git_init(dir)
  r1 <- d2_run(d2r_warn_doc(12), dir = dir)
  expect_length(d2r_new_cond(r1), 0L)               # no earlier render to compare with
  r2 <- d2_run(d2r_warn_doc(12), dir = dir)
  expect_length(d2r_new_cond(r2), 0L)
  r3 <- d2_run(d2r_extra_doc, dir = dir)
  m <- d2r_new_cond(r3)
  expect_length(m, 1L)
  txt <- conditionMessage(m[[1]])
  expect_match(txt, "since the last render", fixed = TRUE)
  expect_false(grepl("since HEAD", txt, fixed = TRUE))
  expect_match(txt, "Fresh problem", fixed = TRUE)
  expect_false(grepl("Removed 12", txt, fixed = TRUE))
})

test_that("review 2d E: when _weft/ledger is ignored by git the comparison is with the last render", {
  skip_if(Sys.which("git") == "")
  dir <- withr::local_tempdir()
  d2_git_init(dir)
  writeLines("_weft/ledger/", file.path(dir, ".gitignore"))
  d2_run(d2r_warn_doc(12), dir = dir)
  d2_git_commit(dir)                                 # HEAD exists, but holds no log
  r1 <- d2_run(d2r_warn_doc(12), dir = dir)
  expect_length(d2r_new_cond(r1), 0L)
  r2 <- d2_run(d2r_extra_doc, dir = dir)
  m <- d2r_new_cond(r2)
  expect_length(m, 1L)
  expect_match(conditionMessage(m[[1]]), "since the last render", fixed = TRUE)
  expect_match(conditionMessage(m[[1]]), "Fresh problem", fixed = TRUE)
  expect_false(grepl("Removed 12", conditionMessage(m[[1]]), fixed = TRUE))
})

test_that("review 2d E control: a log that a commit holds is still compared with HEAD", {
  skip_if(Sys.which("git") == "")
  dir <- withr::local_tempdir()
  d2_git_init(dir)
  d2_run(d2r_warn_doc(12), dir = dir)
  d2_git_commit(dir)
  m <- d2r_new_cond(d2_run(d2r_extra_doc, dir = dir))
  expect_length(m, 1L)
  expect_match(conditionMessage(m[[1]]), "since HEAD", fixed = TRUE)
})

# ---- F: a non-UTF-8 session ---------------------------------------------------------------------------------------------------

d2r_child <- function(dir, locale) {
  lib <- weft_test_lib()
  script <- c(
    if (nzchar(lib)) sprintf(".libPaths(c(%s, .libPaths()))", deparse(lib)),
    sprintf("setwd(%s)", deparse(dir)),
    "cat('UTF8:', isTRUE(l10n_info()[['UTF-8']]), '\\n')",
    "withCallingHandlers(",
    "  knitr::knit('doc.Rmd', 'doc.md', quiet = TRUE, envir = new.env()),",
    "  warning = function(w) {",
    "    cat('WARN:', paste(class(w), collapse = ' '), '|', gsub('\\n', ' ', conditionMessage(w)), '\\n')",
    "    invokeRestart('muffleWarning') })",
    "cat('LEDGER:', file.exists('_weft/ledger/doc.Rmd/doc.jsonl'), '\\n')",
    "cat('LOG:', file.exists('_weft/ledger/doc.Rmd/doc.conditions.jsonl'), '\\n')")
  withr::local_envvar(c(LC_ALL = locale, LANG = locale))
  r_fresh(script, dir = file.path(dir, "child-scratch"))
}

test_that("review 2d F: under LC_ALL=C nothing is written and one weft_ledger_warning names the locale", {
  skip_on_os("windows")
  skip_on_cran()
  dir <- normalizePath(withr::local_tempdir())
  write_doc("Value `r k`.", TRUE, "k <- 1", NULL, D2_SETUP, "doc", "rmd", dir = dir)
  out <- d2r_child(dir, "C")
  expect_true(any(grepl("UTF8: FALSE", out, fixed = TRUE)), label = paste(out, collapse = "\n"))
  expect_true(any(grepl("LEDGER: FALSE", out, fixed = TRUE)), label = paste(out, collapse = "\n"))
  expect_true(any(grepl("LOG: FALSE", out, fixed = TRUE)))
  w <- grep("^WARN:.*weft_ledger_warning", out, value = TRUE)
  expect_length(w, 1L)
  expect_match(w, "locale|UTF-8", ignore.case = TRUE)
})

test_that("review 2d F: the same under LC_ALL=POSIX", {
  skip_on_os("windows")
  skip_on_cran()
  dir <- normalizePath(withr::local_tempdir())
  write_doc("Value `r k`.", TRUE, "k <- 1", NULL, D2_SETUP, "doc", "rmd", dir = dir)
  out <- d2r_child(dir, "POSIX")
  skip_if(!any(grepl("UTF8: FALSE", out, fixed = TRUE)), "POSIX is a UTF-8 locale here")
  expect_true(any(grepl("LEDGER: FALSE", out, fixed = TRUE)))
  expect_length(grep("^WARN:.*weft_ledger_warning", out), 1L)
})

test_that("review 2d F control: in a UTF-8 session the child writes both files and raises no ledger warning", {
  skip_on_os("windows")
  skip_on_cran()
  dir <- normalizePath(withr::local_tempdir())
  write_doc("Value `r k`.", TRUE, "k <- 1", NULL, D2_SETUP, "doc", "rmd", dir = dir)
  out <- d2r_child(dir, "en_US.UTF-8")
  skip_if(!any(grepl("UTF8: TRUE", out, fixed = TRUE)), "en_US.UTF-8 is not available here")
  expect_true(any(grepl("LEDGER: TRUE", out, fixed = TRUE)))
  expect_true(any(grepl("LOG: TRUE", out, fixed = TRUE)))
  expect_length(grep("weft_ledger_warning", out), 0L)
})

# ---- G: WEFT_OUTPUT loses its extension and folder --------------------------------------------------------------------------------

test_that("review 2d G: WEFT_OUTPUT=other.html names the ledger other, as output_file = 'other.html' does", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1", env = c(WEFT_OUTPUT = "other.html"))
  expect_true(file.exists(d2_path(res$dir, output = "other")))
  expect_false(file.exists(d2_path(res$dir, output = "other.html")))
  expect_identical(res$knit$output, "other")
  expect_identical(d2_header(d2_path(res$dir, output = "other"))$output, "other")
})

test_that("review 2d G: another extension, and a folder in WEFT_OUTPUT, are dropped", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1", env = c(WEFT_OUTPUT = "other.md"))
  expect_true(file.exists(d2_path(res$dir, output = "other")))
  res2 <- d2_render(c("Value `r k`."), code = "k <- 1", env = c(WEFT_OUTPUT = "out/other.html"))
  expect_true(file.exists(d2_path(res2$dir, output = "other")))
  expect_identical(res2$knit$output, "other")
})

test_that("review 2d G: the two routes to one output give one ledger name", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- withr::local_tempdir()
  d2_render(c("Value `r k`."), code = "k <- 1", dir = dir, env = c(WEFT_OUTPUT = "other.html"))
  files1 <- list.files(file.path(dir, "_weft", "ledger", "doc.Rmd"))
  r <- d2r_render_to(dir, "doc.Rmd", "other.html")
  files2 <- list.files(file.path(dir, "_weft", "ledger", "doc.Rmd"))
  expect_true(all(c("other.jsonl", "other.conditions.jsonl") %in% files1))
  expect_false(any(grepl("other\\.html", c(files1, files2))))
})

test_that("review 2d G under Quarto: WEFT_OUTPUT=other.html with -o other.html writes other.jsonl", {
  skip_if_no_quarto()
  dir <- d2r_qdir(d2r_qdoc("Value `r k` here.", "html"))
  r <- qrender(dir, c("doc.qmd", "--to", "html", "-o", "other.html"), env = c(WEFT_OUTPUT = "other.html"))
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(d2_path(dir, source = "doc.qmd", output = "other")))
  expect_false(file.exists(d2_path(dir, source = "doc.qmd", output = "other.html")))
})

test_that("review 2d G control: WEFT_OUTPUT with no extension names the ledger as it is", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1", env = c(WEFT_OUTPUT = "other"))
  expect_true(file.exists(d2_path(res$dir, output = "other")))
})

# ---- H: output names ending .conditions ---------------------------------------------------------------------------------------------

d2r_expect_conditions_refused <- function(res, dir) {
  expect_length(list.files(file.path(dir, "_weft"), recursive = TRUE, all.files = TRUE), 0L)
  w <- d2r_ledger_warnings(res)
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), "conditions", fixed = TRUE)
}

test_that("review 2d H: WEFT_OUTPUT=doc.conditions.md (output name doc.conditions) writes nothing and warns once", {
  res <- d2_run("Value `r k`.", code = "k <- 1", env = c(WEFT_OUTPUT = "doc.conditions.md"))
  d2r_expect_conditions_refused(res, res$dir)
})

test_that("review 2d H: an output file doc.conditions.md under rmarkdown::render() is refused the same way", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- normalizePath(withr::local_tempdir())
  write_doc("Value `r k`.", TRUE, "k <- 1", NULL, D2_SETUP, "doc", "rmd", dir = dir)
  r <- d2r_render_to(dir, "doc.Rmd", "doc.conditions.md")
  expect_null(r$error)
  d2r_expect_conditions_refused(r, dir)
})

test_that("review 2d H control: an output named doc (and its log doc.conditions.jsonl) is not refused", {
  res <- d2_run("Value `r k`.", code = "k <- 1")
  expect_length(d2r_ledger_warnings(res), 0L)
  expect_true(file.exists(d2_path(res$dir)))
  expect_true(file.exists(d2_path(res$dir, conditions = TRUE)))
})

# ---- I: footnote sentences -----------------------------------------------------------------------------------------------------------

test_that("review 2d I: a footnote's definition marker is not part of its sentence", {
  doc <- c("Text here.[^1] More text.[^note]", "", "[^1]: A note with `r x1` in it.", "", "[^note]: Another `r x2` one.")
  res <- d2_render(doc, code = "x1 <- 7; x2 <- 8")
  e <- d2_ledger(res)
  expect_identical(d2_one(e, expr = "x1")$sentence, "A note with 7 in it.")
  expect_identical(d2_one(e, expr = "x2")$sentence, "Another 8 one.")
})

test_that("review 2d I control: an ordinary paragraph's sentence is unchanged", {
  res <- d2_render("A plain note with `r x1` in it.", code = "x1 <- 7")
  expect_identical(d2_one(d2_ledger(res), expr = "x1")$sentence, "A plain note with 7 in it.")
})

# ---- J: D22 and cached captions -------------------------------------------------------------------------------------------------------------

