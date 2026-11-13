# Package 5d, part one: Python warnings and errors in the condition log (rules
# G25 to G29 of dev/design-5.md; spec 2.12.10, 7.4.1, 7.4.2, 7.4.5).
# Written before the code. Made-up values only.
#
# How the log is read: as the existing condition tests read it. The file
# _weft/ledger/doc.Rmd/doc.conditions.jsonl of a set-up project (a _weft.yml
# with `draft: false`), through helper-2d.R (d2_path(), d2_lines(), d2_entries()),
# and last_knit()$condition_log (columns from, source, class, normalised, text)
# and last_knit()$conditions (stage-1 columns source, class, text, normalised).
#
# Interface fixed by these tests: none beyond the note's. A source is a chunk's
# label for a Python chunk, or an R chunk that calls Python; a prose source is the
# file (and section) as 2.8.2 gives it, "doc.Rmd" above any heading.
#
# Messages carry no digits (7.4.5 would normalise them). Python's warnings
# registry shows a warning once per place, so every chunk begins with the lines of
# py_preface (simplefilter('always')); each test uses words of its own.
# Chunks that must stop the knit give `error=FALSE` as an option, since
# knitr::knit() alone would print the error and go on (rmarkdown::render stops).

line_of <- function(from, source, class, normalised, text = normalised) {
  sprintf("{\"from\":\"%s\",\"source\":\"%s\",\"class\":\"%s\",\"normalised\":\"%s\",\"text\":\"%s\"}",
          from, source, class, normalised, text)
}

# ---- G25: the exact line, in the log and in last_knit() ------------------------------

p3_lines <- c("Intro.", "", pychunk("p3", c(py_preface, "warnings.warn('a python warning')")),
              "After.")

p3_doc <- function() memo5d("p3", function() proj5(p3_lines))

test_that("G25: a warning a Python chunk raises is one line in the condition log, with the fields the note gives", {
  res <- p3_doc()
  expect_false(res$failed, label = res$message)
  expect_true(line_of("chunk", "p3", "warning", "UserWarning: a python warning") %in% cond_lines(res),
              label = paste(cond_lines(res), collapse = "\n"))
})

test_that("G25: the log's header is first and the Python warning is its only entry", {
  res <- p3_doc()
  ln <- cond_lines(res)
  expect_length(ln, 2L)
  expect_match(ln[1], "^\\{\"weft\":\"conditions\",\"version\":1,", perl = TRUE)
})

test_that("G25: last_knit()$condition_log holds the row (from chunk, source p3, class warning)", {
  res <- p3_doc()
  cl <- res$cond
  expect_s3_class(cl, "weft_condition_log")
  expect_identical(nrow(cl), 1L)
  expect_identical(cl$from, "chunk")
  expect_identical(cl$source, "p3")
  expect_identical(cl$class, "warning")
  expect_identical(cl$normalised, "UserWarning: a python warning")
  expect_identical(cl$text, "UserWarning: a python warning")
})

test_that("G25: last_knit()$conditions holds the row too, with its stage-1 columns", {
  res <- p3_doc()
  cond <- res$knit$conditions
  expect_true(any(cond$source == "p3" & cond$class == "warning" &
                    cond$text == "UserWarning: a python warning" &
                    cond$normalised == "UserWarning: a python warning"))
})

test_that("G25: the rendered document is the document of the same knit without weft (2.8.1): the warning still prints where it printed", {
  with <- p3_doc()
  without <- k5(p3_lines, setup = FALSE)
  expect_false(without$failed, label = without$message)
  expect_identical(with$text, without$text)
  expect_true(any(grepl("UserWarning: a python warning", with$text, fixed = TRUE)),
              label = with$md)
})

test_that("G25: the category's name leads the text: a warning of a category of the author's own", {
  res <- proj5(c(pychunk("pcat", c(py_preface,
                                  "class MarsupialWarning(UserWarning):",
                                  "    pass",
                                  "warnings.warn('wombat count low', MarsupialWarning)"))))
  expect_false(res$failed, label = res$message)
  expect_true(line_of("chunk", "pcat", "warning", "MarsupialWarning: wombat count low") %in%
                cond_lines(res))
})

test_that("G25: the same warning raised twice in a chunk is one line (a loop gives the first text), as for R", {
  res <- proj5(pychunk("ploop", c(py_preface, "for i in range(3):",
                                  "    warnings.warn('quokka seen')")))
  expect_false(res$failed, label = res$message)
  e <- Filter(function(e) e$source == "ploop", cond_entries(res))
  expect_length(e, 1L)
  expect_identical(e[[1]]$text, "UserWarning: quokka seen")
})

# ---- G25: other sources ---------------------------------------------------------------

other_doc <- function() memo5d("other", function() {
  proj5(c(
    "```{r rcall}",
    "reticulate::py_run_string(\"import warnings\\nwarnings.simplefilter('always')\\nwarnings.warn('r chunk calls python')\")",
    "```", "",
    "A value `r {reticulate::py_run_string(\"import warnings\\nwarnings.simplefilter('always')\\nwarnings.warn('prose calls python')\"); 3}`{.num} m.", ""))
})

# needs the guest read of 5b (py$a$b), so it fails there first when 5b is absent
read_doc <- function() memo5d("read", function() {
  proj5(c(
    pychunk("pdef", c(py_preface,
      "class T5dObj:",
      "    @property",
      "    def depth(self):",
      "        warnings.warn('prose property warning')",
      "        return 3.5",
      "t_g5d_obj = T5dObj()"), "include=FALSE"),
    "A read `r py$t_g5d_obj$depth`{.num} m.", ""))
})

test_that("G25: a warning from Python code an R chunk calls (reticulate::py_run_string) is that R chunk's, from chunk", {
  res <- other_doc()
  expect_false(res$failed, label = res$message)
  expect_true(line_of("chunk", "rcall", "warning", "UserWarning: r chunk calls python") %in%
                cond_lines(res), label = paste(cond_lines(res), collapse = "\n"))
})

test_that("G25: a warning raised while prose calls Python is from prose, sourced by file as 2.8.2 says", {
  res <- other_doc()
  expect_true(line_of("prose", "doc.Rmd", "warning", "UserWarning: prose calls python") %in%
                cond_lines(res), label = paste(cond_lines(res), collapse = "\n"))
})

test_that("G25: a warning raised during a guest read in prose (an attribute step) is from prose", {
  res <- read_doc()
  expect_false(res$failed, label = res$message)
  expect_true(line_of("prose", "doc.Rmd", "warning", "UserWarning: prose property warning") %in%
                cond_lines(res), label = paste(cond_lines(res), collapse = "\n"))
})

test_that("G25: each Python warning is logged once, not once for the chunk and again for the prose after it", {
  res <- other_doc()
  txt <- vapply(cond_entries(res), `[[`, "", "text")
  expect_identical(sort(txt), sort(unique(txt)))
  expect_length(txt, 2L)
})

# ---- G26: severity -----------------------------------------------------------------------------

test_that("G26: a Python warning matching a severity pattern of _weft.yml fails the render at the end, with the note's detail and hint", {
  res <- k5(
    c(pychunk("pfit", c(py_preface,
                        "class ConvergenceWarning(UserWarning):",
                        "    pass",
                        "warnings.warn('fit did not converge', ConvergenceWarning)")),
      "After."),
    weft_yml = c("draft: false", "severity:", "  - \"ConvergenceWarning\""))
  expect_true(res$failed)
  f <- res$failures
  hit <- f[f$kind == "condition", , drop = FALSE]
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$chunk, "pfit")
  expect_identical(hit$detail, "warning: ConvergenceWarning: fit did not converge")
  expect_identical(hit$hint, "matched the severity pattern ConvergenceWarning")
})

test_that("G26: the same warning with no matching pattern fails nothing and is only logged", {
  res <- proj5(pychunk("pfit2", c(py_preface,
                                  "class ConvergenceWarning(UserWarning):",
                                  "    pass",
                                  "warnings.warn('fit did not converge', ConvergenceWarning)")))
  expect_false(res$failed, label = res$message)
  expect_true(line_of("chunk", "pfit2", "warning", "ConvergenceWarning: fit did not converge") %in%
                cond_lines(res))
})

test_that("G26: the shipped patterns apply to a Python warning's text as to an R one's", {
  res <- k5(pychunk("psing", c(py_preface, "warnings.warn(\"boundary (singular) fit: see help('isSingular')\")")),
            weft_yml = "draft: false")
  expect_true(res$failed)
  expect_true(any(grepl("singular", res$failures$detail, fixed = TRUE)))
})

# ---- G27: errors under error: true ------------------------------------------------------------

err_doc <- function() memo5d("err", function() {
  proj5(c(pychunk("perr", c("raise ValueError('boom of the wombat')"), "error=TRUE"),
          pychunk("pnext", c("t_g5d_after = 1")),
          "After."))
})

test_that("G27: a Python exception in a chunk with error: true is logged, class error, text ExceptionType: message, source the chunk's label", {
  res <- err_doc()
  expect_false(res$failed, label = res$message)
  expect_true(line_of("chunk", "perr", "error", "ValueError: boom of the wombat") %in% cond_lines(res),
              label = paste(cond_lines(res), collapse = "\n"))
})

test_that("G27: the error is in last_knit()$condition_log and $conditions; the knit goes on to the next chunk and the end", {
  res <- err_doc()
  cl <- res$cond
  expect_true(any(cl$source == "perr" & cl$class == "error" &
                    cl$text == "ValueError: boom of the wombat"))
  expect_true(any(res$knit$conditions$source == "perr" & res$knit$conditions$class == "error"))
  expect_true("After." %in% res$text)
})

test_that("G27: the document is the document of the same knit without weft: the traceback shows as it did", {
  with <- err_doc()
  lines <- c(pychunk("perr", c("raise ValueError('boom of the wombat')"), "error=TRUE"),
             pychunk("pnext", c("t_g5d_after = 1")),
             "After.")
  without <- k5(lines, setup = FALSE)
  expect_false(without$failed, label = without$message)
  expect_identical(with$text, without$text)
  expect_true(any(grepl("boom of the wombat", with$text, fixed = TRUE)))
})

test_that("G27: a later chunk's own error is logged under its own label, and the first is not logged again", {
  res <- proj5(c(pychunk("pe1", "raise ValueError('first of the pair')", "error=TRUE"),
                 pychunk("pe2", "raise KeyError('second of the pair')", "error=TRUE")))
  expect_false(res$failed, label = res$message)
  e <- Filter(function(e) e$class == "error", cond_entries(res))
  expect_length(e, 2L)
  got <- vapply(e, function(e) paste(e$source, e$text, sep = "|"), "")
  expect_true("pe1|ValueError: first of the pair" %in% got, label = paste(got, collapse = "\n"))
  expect_true(any(startsWith(got, "pe2|KeyError: ")), label = paste(got, collapse = "\n"))
})

test_that("G27: without error: true the knit stops, as stock does", {
  res <- k5(c(pychunk("pstop", "raise ValueError('boom of the stopped wombat')", "error=FALSE"),
              "After."),
            weft_yml = "draft: false")
  expect_true(res$failed)
  expect_true(grepl("boom of the stopped wombat", res$message, fixed = TRUE), label = res$message)
})

test_that("G27: an error is logged for the chunk that raised it only, not again for the chunk after it", {
  res <- proj5(c(pychunk("pe3", "raise ValueError('only once')", "error=TRUE"),
                 pychunk("pe4", "t_g5d_fine = 1")))
  e <- Filter(function(e) e$class == "error", cond_entries(res))
  expect_identical(vapply(e, `[[`, "", "source"), "pe3")
})

# ---- G28: the cache ---------------------------------------------------------------------------

test_that("G28: a Python chunk with cache: true served from knitr's cache replays its conditions: rendering twice gives the same log", {
  skip_if_no_python()
  dir <- withr::local_tempdir()
  doc <- c(pychunk("pcache",
                   c(py_preface, "warnings.warn('cached wombat warning')",
                     "open('t_g5d_ran.txt', 'a').write('ran\\n')"),
                   "cache=TRUE"),
           "After.")
  files <- list("_weft.yml" = "draft: false")
  r1 <- render_rmd(doc, dir = dir, files = files, in_process = TRUE)
  expect_false(r1$failed, label = r1$message)
  log1 <- d2_lines(d2_path(r1$dir, conditions = TRUE))
  expect_true(line_of("chunk", "pcache", "warning", "UserWarning: cached wombat warning") %in% log1)
  r2 <- render_rmd(doc, dir = dir, files = files, in_process = TRUE)
  expect_false(r2$failed, label = r2$message)
  expect_identical(length(readLines(file.path(dir, "t_g5d_ran.txt"))), 1L)   # served from the cache
  expect_identical(d2_lines(d2_path(r2$dir, conditions = TRUE)), log1)
  expect_true(any(r2$knit$conditions$source == "pcache" & grepl("cached wombat warning", r2$knit$conditions$text)),
              label = "replayed in last_knit()$conditions")
})

# ---- G29: what is not logged -----------------------------------------------------------------

test_that("G29: stderr, the logging module and a warning a filter hides add no line; a real warning beside them is the only one", {
  res <- proj5(c(
    pychunk("pstderr", c("import sys", "print('stderr wombat text', file=sys.stderr)")),
    pychunk("plogging", c("import logging", "logging.warning('logging wombat text')")),
    pychunk("phidden", c(py_preface,
                         "with warnings.catch_warnings():",
                         "    warnings.simplefilter('ignore')",
                         "    warnings.warn('hidden wombat warning')")),
    pychunk("pcontrol", c(py_preface, "warnings.warn('control line wombat')"))))
  expect_false(res$failed, label = res$message)
  ln <- cond_lines(res)
  expect_false(any(grepl("stderr wombat", ln, fixed = TRUE)))
  expect_false(any(grepl("logging wombat", ln, fixed = TRUE)))
  expect_false(any(grepl("hidden wombat", ln, fixed = TRUE)))
  expect_true(line_of("chunk", "pcontrol", "warning", "UserWarning: control line wombat") %in% ln)
  expect_identical(nrow(res$cond), 1L)
})

test_that("G29: a print to sys.stderr alone adds no line, and the log is the header alone", {
  res <- proj5(pychunk("pstderr2", c("import sys", "print('only stderr wombat', file=sys.stderr)")))
  expect_false(res$failed, label = res$message)
  expect_length(cond_lines(res), 1L)
  expect_identical(nrow(res$cond), 0L)
})
