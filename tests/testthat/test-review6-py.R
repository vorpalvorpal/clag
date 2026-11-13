# Package 6R, the Python side: failing tests for open findings 12 and 13 of dev/open-findings.md (stage 6)
# and their rulings in dev/review-stage6.md ("Suspected" paragraph: "Python and Julia `put` under knitr are
# wired to R's waiting names (open findings 12 and 17), which also settles what Quarto's knitr does with a
# printed block"; "`auto()` publishes automatically only names the source uses, as R; a too-long list
# raises in `auto()` as in `put()`"). Labels: "open-6 #N". Helpers: helper-6b.R, helper-5.R, helper-5c.R,
# helper-jupyter.R. Python through reticulate (skip_if_no_python) or a Jupyter kernel (skip_if_no_jupyter).
# ASCII only.
#
# READINGS where the rulings leave exact text open (behaviour is asserted, never invented wording):
#  - the `lang` of a block the hooks write for records Python handed over is not pinned;
#  - where the E42 of `auto()` shows is not ruled: IPython prints an exception of a post_run_cell callback
#    and sends it as the cell's error output, so the text is looked for in the cell's stdout, error value
#    and traceback together; the tests pin that it appears and that no error record is published.

py_knit <- function(lines, ...) {
  res <- k5(lines, ...)
  res$blocks <- b6_blocks(res$text)
  res
}

# ---- open-6 #12: put() in a Python chunk of a knitr document hands its records to R's waiting names -----------

test_that("open-6 #12: put() in a Python chunk of a knitr document: the next prose block's carrier holds the names, and nothing is printed", {
  res <- py_knit(c(
    pychunk("p1", c("from weft import put", "put(n_sites=12, site='north')"), "echo=FALSE"),
    "Uses `n_sites`{.num} at `site`{.val}."
  ))
  expect_false(res$failed, label = res$message)
  # today: the block is printed into the chunk's output ("## ````{.weft-values}..."), which is no carrier
  expect_length(res$blocks, 1L)
  expect_identical(sum(grepl("weft-values", res$text, fixed = TRUE)), 1L)
  if (length(res$blocks) != 1L) return(invisible())
  b <- res$blocks[[1]]
  expect_identical(b$fence >= 4L, TRUE)
  expect_setequal(names(b$block$values), c("n_sites", "site"))
  expect_identical(b6_core(b$block$values$n_sites), b6_e_int("12"))
  expect_identical(b6_core(b$block$values$site), b6_e_str("north"))
  prose <- b6_line(res$text, "Uses `n_sites`")
  expect_false(is.na(prose))
  expect_true(b$close < prose)
  # the construct is left for the filter, as written
  expect_true(any(grepl("`n_sites`{.num}", res$text, fixed = TRUE)))
})

test_that("open-6 #12: a chunk with include=FALSE publishes too, two chunks' names share one block", {
  res <- py_knit(c(
    pychunk("p1", c("from weft import put", "put(a=1)"), "include=FALSE"),
    pychunk("p2", c("put(b=2)"), "include=FALSE"),
    "Uses `a`{.num} and `b`{.num}."
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 1L)
  expect_identical(sum(grepl("weft-values", res$text, fixed = TRUE)), 1L)
  if (length(res$blocks) != 1L) return(invisible())
  v <- res$blocks[[1]]$block$values
  expect_setequal(names(v), c("a", "b"))
  expect_identical(b6_core(v$a), b6_e_int("1"))
  expect_identical(b6_core(v$b), b6_e_int("2"))
})

test_that("open-6 #12: a put() with no prose after it publishes at the end of the document", {
  res <- py_knit(c(
    "Uses `tail_name`{.num}.", "",
    pychunk("last", c("from weft import put", "put(tail_name=5)"), "include=FALSE")
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 1L)
  if (length(res$blocks) != 1L) return(invisible())
  expect_identical(b6_core(res$blocks[[1]]$block$values$tail_name), b6_e_int("5"))
  expect_true(res$blocks[[1]]$open > b6_line(res$text, "Uses `tail_name`"))
})

test_that("open-6 #12 control: in a chunk with results='asis' put() writes the block at once, so text printed after it sees the names (N42, N70)", {
  res <- py_knit(c(
    pychunk("p1", c("from weft import put", "put(n_sites=12)", "print('after the block')"),
            "echo=FALSE, results='asis'"),
    "Prose."
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 1L)
  if (length(res$blocks) != 1L) return(invisible())
  expect_identical(b6_core(res$blocks[[1]]$block$values$n_sites), b6_e_int("12"))
  expect_true(res$blocks[[1]]$close < b6_line(res$text, "after the block"))
})

test_that("open-6 #12 control: put() refuses a bad name in a knit as it always did", {
  res <- py_knit(c(
    pychunk("p1", c("from weft import put, PublishError", "try:", "    put({'bad name': 1})",
                    "except PublishError as e:", "    print('refused')"), "echo=FALSE"),
    "Prose."
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 0L)
  expect_true(any(grepl("refused", res$text, fixed = TRUE)))
})

# ---- open-6 #12: auto() under knitr publishes the names the source uses -----------------------------------------

test_that("open-6 #12: auto() under knitr: the names the source uses, bound in Python's __main__, are published before the prose that uses them", {
  res <- py_knit(c(
    pychunk("a1", c("from weft import auto", "auto()"), "include=FALSE"),
    pychunk("a2", c("n_sites = 12", "other_thing = 5"), "include=FALSE"),
    "Uses `n_sites`{.num} here."
  ))
  expect_false(res$failed, label = res$message)
  # today R registers nothing for auto(): the hooks never look in Python's __main__
  expect_length(res$blocks, 1L)
  if (length(res$blocks) != 1L) return(invisible())
  v <- res$blocks[[1]]$block$values
  expect_identical(names(v), "n_sites")
  expect_identical(b6_core(v$n_sites), b6_e_int("12"))
  expect_true(res$blocks[[1]]$close < b6_line(res$text, "Uses `n_sites`"))
})

test_that("open-6 #12 control: without auto() a Python name is not published under knitr", {
  res <- py_knit(c(
    pychunk("a2", c("n_sites = 12"), "include=FALSE"),
    "Uses `n_sites`{.num} here."
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 0L)
})

# ---- open-6 #13: auto() in a Jupyter kernel: the gate (N43) and the size of a list (E42) -------------------------

GATE_DOC <- c("---", "title: Gate", "---", "", "A [rose | fell]{if=\"ok\"} here.")
NAMED_DOC <- c("---", "title: Named", "---", "", "The `depth`{.num} and a [rose | fell]{if=\"flag\"} here.")
PLAIN_DOC <- c("---", "title: Plain", "---", "", "Plain words only.")
BIG_DOC <- c("---", "title: Big", "---", "", "Uses `col`{.val}.")

auto6_session <- function() {
  if (!is.null(.jup$auto6)) return(.jup$auto6)
  .jup$auto6 <- auto6_run()
}

auto6_run <- function() {
  docdir <- normalizePath(withr::local_tempdir(), winslash = "/")
  docs <- list(gate = GATE_DOC, named = NAMED_DOC, plain = PLAIN_DOC, big = BIG_DOC)
  for (nm in names(docs)) writeLines(docs[[nm]], file.path(docdir, paste0(nm, ".qmd")))
  p <- function(nm) sprintf("auto(%s)", deparse(file.path(docdir, paste0(nm, ".qmd"))))
  cells <- list(
    setup = "from weft import auto",
    gate_auto = p("gate"),
    gate_set = "ok = True",
    named_auto = p("named"),
    named_set = "depth = 3.5\nflag = True",
    plain_auto = p("plain"),
    plain_set = "zz = 1",
    big_auto = p("big"),
    big_small = "col = list(range(100))",
    big_set = "col = list(range(10001))"
  )
  list(res = jup_session(cells, env = list(QUARTO_DOCUMENT_PATH = docdir, QUARTO_DOCUMENT_FILE = "gate.qmd")),
       docdir = docdir)
}

test_that("open-6 #13: auto() publishes nothing when the source holds no named span, whatever governor names it holds (N43's gate)", {
  r <- auto6_session()$res
  expect_identical(r$gate_auto$status, "ok")
  # today: the name `ok` of the governor is published
  expect_length(r$gate_set$blocks, 0L)
  expect_identical(r$gate_set$status, "ok")
})

test_that("open-6 #13 control: with a named span in the source, the names the source uses are published, a governor's too; names it does not use are not", {
  r <- auto6_session()$res
  expect_identical(r$named_auto$status, "ok")
  expect_length(r$named_set$blocks, 1L)
  expect_identical(sort(names(r$named_set$blocks[[1]]$values)), c("depth", "flag"))
  expect_length(r$plain_set$blocks, 0L)
})

test_that("open-6 #13 control: a list of 100 is published as a list", {
  r <- auto6_session()$res
  expect_length(r$big_small$blocks, 1L)
  rec <- r$big_small$blocks[[1]]$values$col
  expect_identical(rec$t, "list")
  expect_length(rec$v, 100L)
})

test_that("open-6 #13: a list of more than 10000 elements raises E42 from auto(), as from put(), and no error record is published", {
  r <- auto6_session()$res$big_set
  # today: an error record `{"t":"error","why":"{S} is a list of 10001 elements..."}` is published
  pubs <- lapply(r$blocks, function(b) b$values$col)
  expect_false(any(vapply(pubs, function(x) !is.null(x), NA)))
  seen <- paste(c(r$stdout, r$evalue, r$traceback), collapse = "\n")
  expect_true(grepl(e_msg$E42("col", 10001L), seen, fixed = TRUE), label = seen)
})
