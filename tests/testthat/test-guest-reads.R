# Package 5d, part two: what a Python chunk reads (rules G30 to G32 of
# dev/design-5.md; spec 2.12.11, 2.12.12, 7.2.2, 7.2.4).
# Written before the code. Made-up values only.
#
# How the reads are read, as test-tar-ledger-reads.R reads them: the ledger
# header's `files` (helper-2d.R: d2_header(), d2_path()) and
# last_knit()$reads$files (a named character vector of hashes, the path relative to
# the root as the name), with weft:::file_hash() as the hash. "Not re-rendered" is
# the third state of 2e-2: weft:::ledger_state(dir, header) with a reason
# "<path> changed" (test-changes-state.R uses it the same way).
#
# Python's state is shared by every test in this process: module names are words
# of their own (wombat_...), and a test removes from sys.path and sys.modules what
# its project put there (py_cleanup(), helper-5c.R) straight after the knit, so
# no module is imported from an earlier test's folder. The project's module
# folders are put on sys.path by the document itself, so that the tests do not
# depend on where reticulate puts the working folder.

g30_files <- function(ext) {
  list(
    "wombat_helpers.py" = c("import wombat_inner", "VALUE = wombat_inner.INNER + 1"),
    "wombat_inner.py" = "INNER = 4",
    ".venv/lib/wombat_venv.py" = "V = 1",
    "vendor/site-packages/wombat_sp.py" = "V = 2",
    ".hidden/wombat_hid.py" = "V = 3",
    "venv/lib/wombat_plainvenv.py" = "V = 4",
    "renv/lib/wombat_renv.py" = "V = 5",
    "dist-packages/wombat_dp.py" = "V = 6",
    "sub/wombat_sub.py" = "V = 7")
}

g30_lines <- function(ext) {
  c(pychunk("pimp", c(
      "import sys, os",
      "root = os.getcwd()",
      "for sub in ['', '.venv/lib', 'vendor/site-packages', '.hidden', 'venv/lib', 'renv/lib', 'dist-packages', 'sub']:",
      "    sys.path.insert(0, os.path.join(root, sub))",
      sprintf("sys.path.insert(0, r'%s')", ext),
      "import wombat_helpers, wombat_venv, wombat_sp, wombat_hid, wombat_plainvenv",
      "import wombat_renv, wombat_dp, wombat_sub, wombat_outside, json",
      "t_g5d_ok = wombat_helpers.VALUE"), "include=FALSE"),
    "Text `r 1`.")
}

# one knit; returns the k5() result with the `ext` folder in $ext
g30_run <- function() {
  skip_if_no_python()
  ext <- withr::local_tempdir(.local_envir = parent.frame())
  writeLines("OUT = 1", file.path(ext, "wombat_outside.py"))
  res <- proj5(g30_lines(normalizePath(ext)), files = g30_files(ext))
  py_cleanup(res$dir)
  res$ext <- ext
  res
}

g30_doc <- function() memo5d("g30", function() {
  skip_if_no_python()
  ext <- tempfile("weft-5d-ext-")
  dir.create(ext)
  writeLines("OUT = 1", file.path(ext, "wombat_outside.py"))
  res <- proj5(g30_lines(normalizePath(ext)), files = g30_files(ext))
  py_cleanup(res$dir)
  res$ext <- ext
  res
})

# ---- G30: Python modules in the project are files the chapter read ---------------------------

test_that("G30: a module a Python chunk imports from the project root is in reads$files by its relative path, with its hash", {
  res <- g30_doc()
  expect_false(res$failed, label = res$message)
  f <- res$reads$files
  expect_true("wombat_helpers.py" %in% names(f), label = paste(names(f), collapse = ", "))
  expect_identical(f[["wombat_helpers.py"]],
                   weft:::file_hash(file.path(res$dir, "wombat_helpers.py")))
})

test_that("G30: a helper the project's module imports from the project is there too, and a module in a subfolder by its path with /", {
  res <- g30_doc()
  f <- res$reads$files
  expect_identical(f[["wombat_inner.py"]], weft:::file_hash(file.path(res$dir, "wombat_inner.py")))
  expect_identical(f[["sub/wombat_sub.py"]], weft:::file_hash(file.path(res$dir, "sub", "wombat_sub.py")))
})

test_that("G30: the header's files holds the same entries and hashes (7.2.2)", {
  res <- g30_doc()
  h <- hdr_files(res)
  expect_true(all(c("doc.Rmd", "wombat_helpers.py", "wombat_inner.py") %in% names(h)))
  expect_identical(h[["wombat_helpers.py"]], unname(res$reads$files[["wombat_helpers.py"]]))
  expect_match(h[["wombat_helpers.py"]], "^[0-9a-f]{16}$")
  expect_identical(unlist(h), res$reads$files[names(unlist(h))])
})

test_that("G30: modules outside the project root (the standard library, a folder beside it) are not recorded", {
  res <- g30_doc()
  nm <- names(res$reads$files)
  expect_false("wombat_outside.py" %in% nm)
  expect_false(any(grepl("json", nm, fixed = TRUE)))
  expect_false(any(grepl("^(/|[A-Za-z]:)", nm)))   # relative paths only
})

test_that("G30: modules under .venv, venv, renv, site-packages, dist-packages or a folder starting with a dot are not recorded", {
  res <- g30_doc()
  nm <- names(res$reads$files)
  for (m in c("wombat_venv.py", "wombat_plainvenv.py", "wombat_renv.py", "wombat_sp.py",
              "wombat_dp.py", "wombat_hid.py")) {
    expect_false(any(basename(nm) == m), label = m)
  }
})

test_that("G30: the files read are the source, the project's modules, and nothing else", {
  res <- g30_doc()
  expect_identical(sort(names(res$reads$files)),
                   c("doc.Rmd", "sub/wombat_sub.py", "wombat_helpers.py", "wombat_inner.py"))
})

test_that("G30 + 7.2.4: editing a module afterwards makes the chapter's entries 'not re-rendered' (a stale ledger, reason '<path> changed')", {
  res <- g30_run()
  expect_false(res$failed, label = res$message)
  hdr <- attr(weft:::read_ledger(lines = d2_lines(d2_path(res$dir))), "header")
  st0 <- weft:::ledger_state(res$dir, hdr)
  expect_false(st0$stale)
  writeLines("INNER = 5", file.path(res$dir, "wombat_inner.py"))
  st <- weft:::ledger_state(res$dir, hdr)
  expect_true(st$stale)
  expect_true("wombat_inner.py changed" %in% st$reasons, label = paste(st$reasons, collapse = "; "))
})

test_that("G30: a knit in which Python never started records no module and does not start Python (fresh process)", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "d <- tempfile('weft-5d-'); dir.create(d); setwd(d)",
    "writeLines('draft: false', '_weft.yml')",
    "writeLines('VALUE = 3', 'wombat_none.py')",
    "writeLines(c('---', 'title: t', '---', '', '```{r setup, include=FALSE}',",
    "             'weft::weft_setup()', 'library(reticulate)', '```', '', 'Text `r 1`.'), 'doc.Rmd')",
    "knitr::knit('doc.Rmd', 'doc.md', quiet = TRUE)",
    "k <- weft:::last_knit()",
    "cat('FILES=', paste(sort(names(k$reads$files)), collapse = ','), '\\n', sep = '')",
    "cat('PYRUN=', reticulate::py_available(), '\\n', sep = '')")))
  expect_identical(out$FILES, "doc.Rmd")
  expect_identical(out$PYRUN, "FALSE")
})

test_that("G30: a knit with no Python chunk and no reticulate leaves reticulate unloaded (fresh process)", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "d <- tempfile('weft-5d-'); dir.create(d); setwd(d)",
    "writeLines('draft: false', '_weft.yml')",
    "writeLines('VALUE = 3', 'wombat_none.py')",
    "writeLines(c('---', 'title: t', '---', '', '```{r setup, include=FALSE}',",
    "             'weft::weft_setup()', '```', '', 'Text `r 1`.'), 'doc.Rmd')",
    "knitr::knit('doc.Rmd', 'doc.md', quiet = TRUE)",
    "k <- weft:::last_knit()",
    "cat('FILES=', paste(sort(names(k$reads$files)), collapse = ','), '\\n', sep = '')",
    "cat('LOADED=', 'reticulate' %in% loadedNamespaces(), '\\n', sep = '')")))
  expect_identical(out$FILES, "doc.Rmd")
  expect_identical(out$LOADED, "FALSE")
})

# ---- G31: literal source_python() and py_run_file() paths ------------------------------------

test_that("G31: a literal path given to source_python() or py_run_file(), with or without reticulate::, in R chunk code is a file the chapter read", {
  skip_if_no_python()
  withr::defer(if ("package:reticulate" %in% search()) detach("package:reticulate"))
  res <- proj5(
    c("```{r srcs}",
      "reticulate::source_python(\"wombat_tools.py\")",
      "reticulate::py_run_file('wombat_run.py')",
      "library(reticulate)",
      "source_python(\"wombat_tools_bare.py\")",
      "py_run_file(\"wombat_run_bare.py\")",
      "```", "", "Text `r 1`."),
    files = list("wombat_tools.py" = "WOMBAT_A = 1",
                 "wombat_run.py" = "WOMBAT_B = 2",
                 "wombat_tools_bare.py" = "WOMBAT_C = 3",
                 "wombat_run_bare.py" = "WOMBAT_D = 4"))
  expect_false(res$failed, label = res$message)
  f <- res$reads$files
  for (p in c("wombat_tools.py", "wombat_run.py", "wombat_tools_bare.py", "wombat_run_bare.py")) {
    expect_true(p %in% names(f), label = p)
    expect_identical(f[[p]], weft:::file_hash(file.path(res$dir, p)), label = p)
    expect_true(p %in% names(hdr_files(res)), label = paste("header", p))
  }
})

test_that("G31: a sourced file edited afterwards makes the entries not re-rendered", {
  skip_if_no_python()
  res <- proj5(
    c("```{r srcs2}", "reticulate::source_python(\"wombat_tools_edit.py\")", "```", "", "Text `r 1`."),
    files = list("wombat_tools_edit.py" = "WOMBAT_E = 1"))
  expect_false(res$failed, label = res$message)
  hdr <- attr(weft:::read_ledger(lines = d2_lines(d2_path(res$dir))), "header")
  expect_false(weft:::ledger_state(res$dir, hdr)$stale)
  writeLines("WOMBAT_E = 2", file.path(res$dir, "wombat_tools_edit.py"))
  st <- weft:::ledger_state(res$dir, hdr)
  expect_true(st$stale)
  expect_true("wombat_tools_edit.py changed" %in% st$reasons)
})

# ---- G32: the reads walker reads R chunks only ------------------------------------------------

test_that("G32: a Python chunk 'v = dict[\"depth\"]' adds no dictionary entry depth; an R chunk's dict$other does (the walker is on)", {
  res <- proj5(
    c(pychunk("pdict", c("v = dict[\"depth\"]")),
      "```{r rdict}", "o <- dict$other", "```", "", "Text `r 1`."),
    files = list("dict.yml" = e1_dict_lines(list(depth = 3, other = 4))))
  expect_false(res$failed, label = res$message)
  expect_identical(names(res$reads$dict), "other")
  expect_false("depth" %in% names(hdr_files(res)))
  expect_identical(names(d2_header(d2_path(res$dir))$dict), "other")
})

test_that("G32: a Python chunk 'x = tar_read(\"fit\")' adds no target fit", {
  res <- proj5(
    c(pychunk("ptar", c("def tar_read(name):", "    return name", "x = tar_read(\"fit\")")),
      "Text `r 1`."))
  expect_false(res$failed, label = res$message)
  expect_identical(length(res$reads$targets), 0L)
  expect_false("fit" %in% unlist(lapply(res$reads$targets, names)))
  expect_identical(length(d2_header(d2_path(res$dir))$targets), 0L)
})

test_that("G32: a Python chunk that names a file in code adds no file to the header", {
  res <- proj5(
    c(pychunk("pfile", c("src = 'wombat_not_read.py'", "exec_name = \"source('wombat_not_read.py')\"")),
      "Text `r 1`."),
    files = list("wombat_not_read.py" = "X = 1"))
  expect_false(res$failed, label = res$message)
  expect_identical(sort(names(res$reads$files)), "doc.Rmd")
})
