# Package 6e: use_quarto() and status() for a project with a jupyter-engine document (N74; messages E61 and
# E62 of dev/design-6.md section 7). Written before the code. No kernel, no Quarto and no Python are
# needed: use_quarto() and status() only read the project and write files; the "Python Quarto would use" is
# a stand-in shell script. Every project is a temporary folder.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - the name of the new `status()` row is not given, so it is found as the one part a project with a
#    jupyter-engine document has that a project with only knitr documents has not;
#  - what the row's `detail` says is not pinned;
#  - E62 and the julia-engine row ("not checked") belong to package 6h and are not tested here;
#  - a QUARTO_PYTHON that names a file that does not exist is not tested (the note does not say).

PY_CHUNK <- c("```{python}", "x = 1", "```")
R_CHUNK <- c("```{r}", "x <- 1", "```")

jdoc <- function(front = "title: Home", chunk = PY_CHUNK) c("---", front, "---", "", "Some text.", "", chunk)

jproj <- function(files) {
  dir <- tempfile("weft-uqj-")
  dir.create(dir)
  dir <- normalizePath(dir, winslash = "/")
  writeLines(c("project:", "  type: default", "format: html"), file.path(dir, "_quarto.yml"))
  for (f in names(files)) {
    dir.create(dirname(file.path(dir, f)), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], file.path(dir, f))
  }
  dir
}

# the messages use_quarto() sends (one string per message), and the printed output
says <- function(dir) {
  msgs <- character()
  out <- utils::capture.output(withCallingHandlers(
    weft::use_quarto(dir),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  c(msgs, out)
}
has_msg <- function(x, text) any(grepl(text, x, fixed = TRUE))
n_msg <- function(x, text) sum(grepl(text, x, fixed = TRUE))

test_that("N74: use_quarto() prints E61 for a project with a jupyter-engine document, whichever way the engine is chosen", {
  variants <- list(
    chunk = jdoc(),
    jupyter_key = jdoc("title: Home\njupyter: python3", chunk = character()),
    engine_key = jdoc("title: Home\nengine: jupyter")
  )
  for (nm in names(variants)) {
    dir <- jproj(list(`index.qmd` = variants[[nm]]))
    s <- says(dir)
    expect_identical(n_msg(s, e_msg$E61), 1L, label = nm)
    expect_false(has_msg(s, e_msg$E62), label = nm)
  }
})

test_that("N74: use_quarto() prints E61 on every run, and for a document in a folder of the project", {
  dir <- jproj(list(`index.qmd` = jdoc("title: Home", chunk = character()), `sub/page.qmd` = jdoc()))
  expect_identical(n_msg(says(dir), e_msg$E61), 1L)
  expect_identical(n_msg(says(dir), e_msg$E61), 1L)
})

test_that("N74: no E61 for a project with no jupyter-engine document", {
  projects <- list(
    knitr = list(`index.qmd` = jdoc(chunk = R_CHUNK)),
    plain = list(`index.qmd` = jdoc(chunk = character())),
    python_on_knitr = list(`index.qmd` = jdoc("title: Home\nengine: knitr")),
    none = list(`notes.md` = "Some text.")
  )
  for (nm in names(projects)) {
    expect_false(has_msg(says(jproj(projects[[nm]])), e_msg$E61), label = nm)
  }
})

test_that("N74: use_quarto() installs the extension and scripts whatever the engine, and no Python package", {
  jup <- jproj(list(`index.qmd` = jdoc()))
  knit <- jproj(list(`index.qmd` = jdoc(chunk = R_CHUNK)))
  before_j <- tree(jup)
  before_k <- tree(knit)
  suppressMessages(utils::capture.output(weft::use_quarto(jup)))
  suppressMessages(utils::capture.output(weft::use_quarto(knit)))
  added_j <- setdiff(tree(jup), before_j)
  added_k <- setdiff(tree(knit), before_k)
  expect_identical(added_j, added_k)
  expect_true(all(c("_extensions/weft-check/weft.lua", "_extensions/weft-check/weft-check.lua",
                    "_extensions/weft-check/_extension.yml", "_weft/pre-render.R", "_weft/post-render.R") %in% added_j))
  # nothing of Python is written into the project
  expect_false(any(grepl("[.]py$|requirements|pyproject|venv", added_j)))
})

# ---- status() ----------------------------------------------------------------------------------------

# A stand-in for "the Python Quarto would use": a shell script that records its arguments, one per line,
# in `argsfile`, and exits with `code`.
py_stub <- function(dir, name = "python-stub", code = 0L) {
  p <- file.path(dir, name)
  argsfile <- paste0(p, ".args")
  writeLines(c("#!/bin/sh", sprintf("printf '%%s\\n' \"$@\" > '%s'", argsfile), sprintf("exit %d", code)), p)
  Sys.chmod(p, "0755")
  list(path = p, args = argsfile)
}

status_parts <- function(dir) weft::status(dir)$part

new_row <- function(jup_dir, base_dir) {
  extra <- setdiff(status_parts(jup_dir), status_parts(base_dir))
  expect_length(extra, 1L)
  weft::status(jup_dir)[weft::status(jup_dir)$part == extra, , drop = FALSE]
}

setup_status_projects <- function() {
  jup <- qproject_status(list(`index.qmd` = jdoc()))
  base <- qproject_status(list(`index.qmd` = jdoc(chunk = R_CHUNK)))
  list(jup = jup, base = base)
}
qproject_status <- function(files) {
  dir <- jproj(files)
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  dir
}

test_that("N74: status() gains one row for a project with a jupyter-engine document, and none otherwise", {
  skip_on_os("windows")
  stubs <- withr::local_tempdir()
  p <- setup_status_projects()
  ok <- py_stub(stubs)
  withr::local_envvar(QUARTO_PYTHON = ok$path)
  extra <- setdiff(status_parts(p$jup), status_parts(p$base))
  expect_length(extra, 1L)
  expect_identical(length(status_parts(p$jup)), length(status_parts(p$base)) + 1L)
  # a project with only knitr or plain documents has none
  plain <- qproject_status(list(`index.qmd` = jdoc(chunk = character())))
  expect_identical(status_parts(plain), status_parts(p$base))
})

test_that("N74: the row is `ok` when `<python> -I -c \"import weft\"` succeeds in QUARTO_PYTHON, and that is the command run", {
  skip_on_os("windows")
  stubs <- withr::local_tempdir()
  p <- setup_status_projects()
  ok <- py_stub(stubs)
  withr::local_envvar(QUARTO_PYTHON = ok$path)
  row <- new_row(p$jup, p$base)
  expect_identical(row$state, "ok")
  expect_true(file.exists(ok$args))
  expect_identical(readLines(ok$args), c("-I", "-c", "import weft"))
})

test_that("N74: the row is `missing` when the import fails", {
  skip_on_os("windows")
  stubs <- withr::local_tempdir()
  p <- setup_status_projects()
  bad <- py_stub(stubs, "python-bad", code = 1L)
  withr::local_envvar(QUARTO_PYTHON = bad$path)
  row <- new_row(p$jup, p$base)
  expect_identical(row$state, "missing")
  expect_identical(readLines(bad$args), c("-I", "-c", "import weft"))
})

test_that("N74: QUARTO_PYTHON is tried first, then python3 on the PATH; with neither the row is `not checked`", {
  skip_on_os("windows")
  stubs <- withr::local_tempdir()
  p <- setup_status_projects()
  # python3 on the PATH, no QUARTO_PYTHON
  bin <- file.path(stubs, "bin")
  dir.create(bin)
  py3 <- py_stub(bin, "python3")
  withr::local_envvar(QUARTO_PYTHON = NA, PATH = paste(bin, Sys.getenv("PATH"), sep = .Platform$path.sep))
  expect_identical(new_row(p$jup, p$base)$state, "ok")
  expect_identical(readLines(py3$args), c("-I", "-c", "import weft"))
  # QUARTO_PYTHON wins over python3 (one probe only: the failing one decides)
  bad <- py_stub(stubs, "python-bad", code = 1L)
  withr::local_envvar(QUARTO_PYTHON = bad$path)
  expect_identical(new_row(p$jup, p$base)$state, "missing")
  # no Python at all
  empty <- file.path(stubs, "empty")
  dir.create(empty)
  withr::local_envvar(QUARTO_PYTHON = NA, PATH = empty)
  expect_identical(new_row(p$jup, p$base)$state, "not checked")
})

test_that("control (rule 9.3.1): status() on a project set up by use_quarto() has its existing rows", {
  p <- setup_status_projects()
  expect_true(all(c("setup", "activation", "quarto", "dictionary", "hooks", "ci") %in% status_parts(p$base)))
  expect_identical(weft::status(p$base)$state[weft::status(p$base)$part == "quarto"], "ok")
})
