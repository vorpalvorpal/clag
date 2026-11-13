# Package 6e: auto() of the Python package in a Jupyter kernel (N45, N71, N72, N73; messages E59 and E60 of
# dev/design-6.md section 7). Written before the code. Made-up values only. Helper: helper-jupyter.R.
# Skipped when quarto or a Python with jupyter_client and ipykernel is absent. One kernel session serves the
# kernel tests of this file.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - auto() with no path and no QUARTO_DOCUMENT_PATH/FILE: the note does not say what {path} of E60 shows,
#    so that case is not tested;
#  - whether the cell that calls auto() is itself followed by a publish is not pinned: the tests never
#    count the blocks of that cell alone;
#  - the knitr half of auto() (the hooks also look in Python's __main__) belongs to package 6b's R side.

DOC_SRC <- c(
  "---",
  "title: Doc",
  "---",
  "",
  "The depth is `depth`{.num}; `K`{.val}, `fn`{.val}, `math`{.val}, `_hid`{.val} and `nothing`{.val}.",
  "",
  "A [rose | fell]{if=\"big_n > 10 && 'zed_str' == label\"}.",
  "We saw [a site | # sites]{n=\"n_gap\"} and [x | y]{IF=\"flag_a\"} and [up | down]{sign=\"delta\"}.",
  "Also [none | # was | # were]{list=\"items_l\"} and `new_one`{.num}.",
  "",
  "{{< include inc.qmd >}}"
)
INC_SRC <- c("The included file names `from_inc`{.val}.")
OTHER_SRC <- c("---", "title: Other", "---", "", "Only `only_other`{.num} here.")

auto_session <- function() {
  if (!is.null(.jup$auto_session)) return(.jup$auto_session)
  .jup$auto_session <- auto_session_run()
}

auto_session_run <- function() {
  docdir <- withr::local_tempdir()
  docdir <- normalizePath(docdir, winslash = "/")
  writeLines(DOC_SRC, file.path(docdir, "doc.qmd"))
  writeLines(INC_SRC, file.path(docdir, "inc.qmd"))
  writeLines(OTHER_SRC, file.path(docdir, "other.qmd"))
  cb <- "len(get_ipython().events.callbacks['post_run_cell'])"
  cells <- list(
    setup = paste("a0 = ", cb, "\nfrom weft import auto\nimport math\nimport os", sep = ""),
    # the default path
    default_path = "print(auto())",
    # names the source names, not modules, functions, classes, _names, reserved words, strings
    first = paste("depth = 3.5", "other_thing = 9", "zed_str = 5", "_hid = 1", "nothing = 2",
                  "def fn(): pass", "class K: pass", "big_n = 12", "from_inc = 'hello'", sep = "\n"),
    same = "depth = 3.5",
    changed = "depth = 4.5\nn_gap = 2",
    same_gap = "n_gap = 2",
    unnamed = "other_thing = 10",
    a_list = "items_l = [1, 2]",
    shows_value = "1 + 1",
    changed_back = "depth = 3.5",
    # one callback after two calls
    count1 = paste0("a1 = ", cb),
    call2 = "p = os.path.join(os.environ['QUARTO_DOCUMENT_PATH'], 'doc.qmd')\nauto(p)",
    call3 = "auto(p)",
    count2 = paste0("a2 = ", cb, "\nprint(a0, a1, a2)"),
    after_calls = "new_one = 1",
    # the memory is emptied by a call
    recall = "auto(p)",
    republish = "depth = 3.5",
    # another document, by the environment and by a path
    env_other = "os.environ['QUARTO_DOCUMENT_FILE'] = 'other.qmd'\nprint(auto())",
    other_depth = "depth = 99",
    other_name = "only_other = 1",
    path_doc = "print(auto(p))",
    path_other = "print(auto(os.path.join(os.environ['QUARTO_DOCUMENT_PATH'], 'other.qmd')))",
    # E60
    unreadable = "from weft import WeftError\nauto('/no/such/folder/doc.qmd')"
  )
  res <- jup_session(cells, env = list(QUARTO_DOCUMENT_PATH = docdir, QUARTO_DOCUMENT_FILE = "doc.qmd"))
  list(res = res, docdir = docdir)
}

names_of <- function(r) lapply(r$blocks, function(b) sort(names(b$values)))

test_that("N71: auto() returns the path used, by default QUARTO_DOCUMENT_PATH joined to QUARTO_DOCUMENT_FILE", {
  s <- auto_session()
  expect_identical(s$res$setup$status, "ok")
  expect_identical(s$res$default_path$status, "ok")
  expect_identical(s$res$default_path$stdout, paste0(s$docdir, "/doc.qmd\n"))
})

test_that("N71, N45: after each cell auto() publishes, in one block, the names the source names that the cell changed", {
  r <- auto_session()$res
  # cell 3: depth (code span), big_n (an if value), from_inc (the include); not other_thing (not named),
  # zed_str (only inside single quotes), _hid, nothing (reserved), fn, K, math (function, class, module)
  expect_identical(names_of(r$first), list(c("big_n", "depth", "from_inc")))
  v <- r$first$blocks[[1]]$values
  expect_identical(list(v$depth$t, v$depth$v), list("float", "3.5"))
  expect_identical(list(v$big_n$t, v$big_n$v), list("int", "12"))
  expect_identical(list(v$from_inc$t, v$from_inc$v), list("string", "hello"))
  expect_identical(r$first$blocks[[1]]$lang, "python")
  expect_identical(as.integer(r$first$blocks[[1]]$weft), 1L)
})

test_that("N71: only on change", {
  r <- auto_session()$res
  expect_length(r$same$blocks, 0L)                      # the same value again
  expect_identical(names_of(r$changed), list(c("depth", "n_gap")))
  expect_identical(r$changed$blocks[[1]]$values$depth$v, "4.5")
  expect_length(r$same_gap$blocks, 0L)                      # n_gap again
  expect_length(r$unnamed$blocks, 0L)                      # a name the source does not name
  expect_identical(names_of(r$a_list), list("items_l"))
  expect_identical(r$a_list$blocks[[1]]$values$items_l$t, "list")
  expect_length(r$shows_value$blocks, 0L)
  expect_identical(r$shows_value$result, "2")
  expect_identical(names_of(r$changed_back), list("depth"))    # back to 3.5: differs from the last published
  expect_identical(r$changed_back$blocks[[1]]$values$depth$v, "3.5")
})

test_that("N71: one post_run_cell callback after two calls (a second call replaces, never adds)", {
  r <- auto_session()$res
  counts <- as.integer(strsplit(trimws(r$count2$stdout), " ")[[1]])
  expect_length(counts, 3L)
  expect_identical(counts[2], counts[1] + 1L)
  expect_identical(counts[3], counts[2])
  expect_identical(names_of(r$after_calls), list("new_one"))
})

test_that("N71: a call empties the memory of what was published", {
  r <- auto_session()$res
  # depth is 3.5, as last published; after a new call it is published again, in the call's own cell or the next
  blocks <- c(r$recall$blocks, r$republish$blocks)
  expect_length(blocks, 1L)
  expect_true("depth" %in% names(blocks[[1]]$values))
})

test_that("N71, N72: the path is re-read from the environment at each call, and an explicit path is used as given", {
  s <- auto_session()
  r <- s$res
  expect_identical(r$env_other$stdout, paste0(s$docdir, "/other.qmd\n"))
  expect_length(r$other_depth$blocks, 0L)                     # depth is not named by other.qmd
  expect_identical(names_of(r$other_name), list("only_other"))
  expect_identical(r$path_doc$stdout, paste0(s$docdir, "/doc.qmd\n"))
  expect_identical(r$path_other$stdout, paste0(s$docdir, "/other.qmd\n"))
})

test_that("N71, E60: a document auto() cannot read raises WeftError at once", {
  r <- auto_session()$res
  expect_identical(r$unreadable$status, "error")
  expect_identical(r$unreadable$ename, "WeftError")
  expect_identical(r$unreadable$evalue, e_msg$E60("/no/such/folder/doc.qmd"))
})

# ---- no back end, and controls ------------------------------------------------------------------------

test_that("N71, E59: auto() with no back end raises WeftError", {
  code <- paste("from weft import auto, WeftError",
                "try:",
                "    auto()",
                "except WeftError as e:",
                "    print(str(e))",
                sep = "\n")
  x <- py_plain(code)
  expect_identical(x$status, 0L, label = x$stderr)
  expect_identical(x$stdout, e_msg$E59)
  # an IPython shell with no kernel is no back end either (N73)
  y <- py_plain(paste("from IPython.core.interactiveshell import InteractiveShell",
                      "ip = InteractiveShell.instance()",
                      "ip.run_cell('from weft import auto, WeftError\\ntry:\\n    auto()\\nexcept WeftError as e:\\n    print(str(e))')",
                      sep = "\n"))
  expect_identical(y$status, 0L, label = y$stderr)
  expect_identical(y$stdout, e_msg$E59)
})

test_that("control (N3): WeftError is an Exception and auto is a function of the package", {
  x <- py_plain("import weft; print(callable(weft.auto), issubclass(weft.WeftError, Exception))")
  expect_identical(x$stdout, "True True")
})
