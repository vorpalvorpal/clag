# Helpers for the stage 5b tests (reading Python values, rules G4 to G17a of
# dev/design-5.md). They sit beside helper-render.R and use render_rmd(),
# weft_restore_knitr(), weft_test_lib() and skip_if_no_quarto(); nothing here
# edits them, and nothing here reads R/ or inst/python/.
#
# ---- THE INTERFACE THE TESTS FIX (internal; the note leaves it open) --------
#
# Exported (G4, G8):
#   py_value(...)         each argument one non-empty string, a step of a path.
#                         Returns the R form (G5, G6) or raises a classed error.
#                         Its subject `{S}` in a message is the call as R
#                         deparses it: py_value("a", "b").
# Internal, tested because the amendment makes the typed record the reader's
# product and puts the refusals in one function:
#   weft:::guest_record(obj)
#       obj is an UNCONVERTED Python object (reticulate::py_eval(.., convert =
#       FALSE), or py_get_attr() on import_main(convert = FALSE)). Returns a
#       list with
#         t    one of "bool" "int" "float" "decimal" "string" "date" "list"
#              "missing" "error"
#         v    bool: TRUE or FALSE; int: the digit string ("-9007199254740993");
#              float: Python's shortest round-trip text ("0.1"); decimal: str()
#              of the Decimal as written ("0.150"); string: the text (UTF-8);
#              date: ISO "2026-11-13"; list: a list of scalar records, in
#              order, as read (an int stays an int; no promotion here);
#              missing, error: not constrained
#         of   lists only: the kind of the elements after the promotions of G6
#              ("int" "float" "decimal" "bool" "string" "date"), or "missing"
#              for an empty list and for a list whose elements are all missing
#         keys lists only: the keys of a mapping as a character vector; NULL
#              for any other list
#         why  missing and error only: a single non-empty string. For an error
#              it is the refusal message of M3 to M9 with the subject written
#              as the literal text {S}.
#       guest_record() never raises for a refused value: it returns t = "error".
#       It does NOT refuse a too-big int (t = "int" with the digit string) or a
#       Decimal of more than 15 digits (t = "decimal"): those refusals (M1, M2)
#       live in record_value().
#   weft:::record_value(rec, S)
#       turns a record into its R form (G5, G6, 2.12.5) or raises the refusal as
#       weft_guest_value_error. S is the subject text, backticks included, put
#       where the messages say {S}: "`py_value(\"x\")`". It accepts a record
#       built by hand (the tests build some), so it must work from the record
#       alone and never touch Python.
#
# ---- helpers here -----------------------------------------------------------
#   skip_if_no_python()      skips ONLY when reticulate is not installed or no
#                            Python can be started
#   skip_if_no_py_module(m)  skips ONLY when module m does not import
#   py_set(...)              runs Python lines: name = "expr" becomes `name =
#                            expr`; an unnamed string is run as it is
#   py_obj(name)             the unconverted Python object of a name in main
#   py_type_name(name)       type(x).__module__ + "." + __qualname__ with a
#                            leading "builtins." removed, as G7 defines {type}
#   pyv(...)                 a call to py_value("a", "b") written out literally,
#                            so that its subject is py_value("a", "b")
#   msg5(e)                  a condition's message with ANSI removed and runs of
#                            white space made one space
#   expect_refused5(expr, msg, class)  a classed error whose message is `msg`
#   m1() ... m16()           the texts of G7, built from their parts
#   k5(lines, py, ...)       one document knitted in this process (Python state
#                            is shared by the process); see its header
#   k5_cases(cases, ...)     k5() of tagged one-paragraph cases
#   k5_fresh(lines, ...)     the same document knitted in a fresh R process
#   r5_fresh(code, env)      R code in a fresh vanilla process that sees the
#                            development weft
#
# Python's state is shared by every test in one process: every test uses names
# of its own (t_g5_...), and the missing-name tests use names never set.

# ---- skips -------------------------------------------------------------------

.w5 <- new.env()

skip_if_no_reticulate <- function() {
  testthat::skip_if_not_installed("reticulate")
}

skip_if_no_python <- function() {
  testthat::skip_if_not_installed("reticulate")
  started <- tryCatch(reticulate::py_available(), error = function(e) FALSE)
  if (!started) {
    Sys.setenv(RETICULATE_USE_MANAGED_VENV = "no")
    if (!nzchar(Sys.getenv("RETICULATE_PYTHON")) && nzchar(Sys.which("python3"))) {
      Sys.setenv(RETICULATE_PYTHON = unname(Sys.which("python3")))
    }
  }
  ok <- tryCatch(isTRUE(reticulate::py_available(initialize = TRUE)),
                 error = function(e) FALSE)
  if (!ok) testthat::skip("reticulate found no Python")
  if (is.null(.w5$boot)) {
    reticulate::py_run_string(
      "import datetime, decimal, fractions, math, sys, types, collections")
    .w5$boot <- TRUE
  }
  invisible(TRUE)
}

skip_if_no_py_module <- function(m) {
  skip_if_no_python()
  testthat::skip_if_not(reticulate::py_module_available(m),
                        paste0("Python has no module ", m))
}

# ---- Python from R -----------------------------------------------------------

py_set <- function(...) {
  x <- c(...)
  nm <- names(x)
  if (is.null(nm)) nm <- rep("", length(x))
  lines <- ifelse(nzchar(nm), paste0(nm, " = ", x), x)
  reticulate::py_run_string(paste(lines, collapse = "\n"))
  invisible(NULL)
}

py_obj <- function(name) {
  reticulate::py_get_attr(reticulate::import_main(convert = FALSE), name)
}

py_type_name <- function(name) {
  reticulate::py_eval(
    paste0("(lambda t: (t.__module__ + '.' + t.__qualname__)",
           ".removeprefix('builtins.'))(type(", name, "))"))
}

pyv <- function(...) {
  call <- as.call(c(list(as.name("py_value")), list(...)))
  eval(call, parent.frame())
}

# ---- conditions --------------------------------------------------------------

msg5 <- function(e) {
  m <- if (inherits(e, "condition")) conditionMessage(e) else as.character(e)
  m <- cli::ansi_strip(m)
  trimws(gsub("[[:space:]]+", " ", m))
}

# `expr` raises `class` (also weft_error), and its message is exactly `msg`
expect_refused5 <- function(expr, msg, class = "weft_guest_value_error") {
  e <- testthat::expect_error(expr, class = class)
  testthat::expect_s3_class(e, "weft_error")
  testthat::expect_identical(msg5(e), msg)
  invisible(e)
}

# ---- the texts of G7 (S is the subject, backticks included) -------------------

pm5 <- "±"

m1 <- function(S, digits) {
  sprintf(paste0("%s is the Python int %s, beyond ", pm5, "2^53, where R cannot hold a whole number exactly. ",
                 "Scale it in Python, or bind str() of it and print the text (rule 2.12.5)."), S, digits)
}
m2 <- function(S, d, n) {
  sprintf(paste0("%s is the Python Decimal %s, with %d significant digits; R holds 15 exactly. ",
                 "Round it in Python with quantize() (rule 2.12.5)."), S, d, n)
}
m3 <- function(S, type, kinds) {
  sprintf(paste0("%s is a Python %s whose elements are of more than one kind (%s); ",
                 "weft reads a list whose elements are all of one kind (rule 1.11.4)."), S, type, kinds)
}
m4 <- function(S, type, inner) {
  sprintf("%s is a Python %s that holds a %s; weft reads a flat list (rule 1.11.4).", S, type, inner)
}
m5 <- function(S, type) {
  sprintf(paste0("%s is a Python %s, which holds a date and a time; weft reads a date. ",
                 "Convert it in Python, in the time zone you mean, with .date() (rule 1.11.6)."), S, type)
}
m6 <- function(S, type) {
  sprintf(paste0("%s is a Python %s, which weft does not read as a value. ",
                 "Bind a bool, int, float, Decimal, str, date, or a list of one of these (rule 1.11.1)."), S, type)
}
m7 <- function(S, type) {
  sprintf("%s is a Python %s, which has no order. Bind sorted() of it in a Python chunk (rule 1.11.4).", S, type)
}
m8 <- function(S, type) {
  sprintf("%s is a Python %s whose keys are not all str (rule 1.11.4).", S, type)
}
m9 <- function(S, d) {
  sprintf("%s is a numpy array of %d dimensions; weft reads a flat list (rule 1.11.4).", S, d)
}
# read is the read as R deparses it, WITHOUT backticks
m10 <- function(read, type) {
  sprintf("`%s` is a Python %s; an `if` condition must be a bool (rule 1.11.8).", read, type)
}
m11n <- function(read, type) {
  sprintf("`%s` is a Python %s; an `n` governor must be a number (rule 1.11.9).", read, type)
}
m11s <- function(read, type) {
  sprintf("`%s` is a Python %s; a `sign` governor must be a number (rule 1.11.9).", read, type)
}
m12 <- function(read, type) {
  sprintf("`%s` is a Python %s; a `list` span needs a list (rule 1.11.10).", read, type)
}
m13 <- function(read, name) {
  sprintf(paste0("`%s`: Python's main module has no name `%s`. ",
                 "Run the Python chunk that sets it before this point (rule 2.12.6)."), read, name)
}
m14 <- function(read, prefix, name) {
  sprintf("`%s`: the Python value `%s` has no attribute or key `%s` (rule 2.12.6).", read, prefix, name)
}
m15 <- function(read) {
  sprintf(paste0("`%s` reads a Python value, and the R package reticulate is not installed. ",
                 "Install it with install.packages(\"reticulate\") (rule 2.12.6)."), read)
}
m16_start <- function(read) {
  sprintf("`%s` reads a Python value, and reticulate could not start Python: ", read)
}
m_args <- "py_value() takes names as strings: py_value(\"n\")."

# ---- documents knitted in this process ----------------------------------------
#
# k5(lines, py = NULL, files = list(), weft_yml = NULL, draft = FALSE,
#    env = NULL, setup = TRUE, need_python = TRUE)
#   lines     the body of doc.Rmd (after the set-up chunk and the Python chunk)
#   py        Python code lines, put in a first `python` chunk with
#             include=FALSE (so it prints nothing)
#   files     more files for the project: a named list of character vectors
#   weft_yml  lines of a _weft.yml, or NULL
#   draft     WEFT_DRAFT=1: nothing fails, markers show in the output (9.4.2)
#   need_python  FALSE for a document that never needs a running Python (the
#             seam of G4b): then only a missing reticulate skips
# Returns list(
#   text, md     the knit output (markdown, not run through Pandoc)
#   failed       TRUE when knitr::knit() stopped with an error
#   error        NULL or the condition; message / class of it below
#   message      msg5() of the error ("" when none); class: its classes
#   knit         weft:::last_knit() after the knit
#   failures     last_knit()$failures (zero rows when none)
#   cond         last_knit()$condition_log
#   reads        last_knit()$reads (the ledger header's reads)
#   offset       lines above `lines` in the file (line k of `lines` is
#                line offset + k)
#   dir, input   where it was written
#   log          messages and warnings seen during the knit
#   searched     "package:reticulate" %in% search() at the end of the knit
# )
k5 <- function(lines, py = NULL, files = list(), weft_yml = NULL,
               draft = FALSE, env = NULL, setup = TRUE, need_python = TRUE) {
  if (need_python) skip_if_no_python() else skip_if_no_reticulate()
  dir <- tempfile("weft-5-")
  dir.create(dir)
  dir <- normalizePath(dir)
  hdr <- c("---", "title: \"t\"", "---", "",
           "```{r setup, include=FALSE}",
           if (setup) "weft::weft_setup()", "```", "")
  pyc <- if (!is.null(py)) c("```{python, include=FALSE}", py, "```", "")
  body <- unlist(strsplit(paste(lines, collapse = "\n"), "\n", fixed = TRUE))
  doc <- c(hdr, pyc, body)
  input <- file.path(dir, "doc.Rmd")
  con <- file(input, "wb")
  writeBin(charToRaw(enc2utf8(paste0(paste(doc, collapse = "\n"), "\n"))), con)
  close(con)
  if (!is.null(weft_yml)) writeLines(weft_yml, file.path(dir, "_weft.yml"))
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  vars <- c(RETICULATE_USE_MANAGED_VENV = "no",
            WEFT_DRAFT = if (draft) "1" else NA_character_)
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  withr::local_dir(dir)
  withr::defer(weft_restore_knitr())
  logv <- character()
  err <- NULL
  withCallingHandlers(
    tryCatch(
      knitr::knit("doc.Rmd", "doc.md", quiet = TRUE,
                  envir = new.env(parent = globalenv())),
      error = function(e) err <<- e
    ),
    message = function(m) {
      logv <<- c(logv, conditionMessage(m)); invokeRestart("muffleMessage")
    },
    warning = function(w) {
      logv <<- c(logv, paste0("Warning: ", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )
  searched <- "package:reticulate" %in% search()
  kn <- tryCatch(weft:::last_knit(), error = function(e) NULL)
  out <- file.path(dir, "doc.md")
  text <- if (file.exists(out)) {
    x <- readLines(out, warn = FALSE, encoding = "UTF-8")
    x <- sub("[ \t]+$", "", x)
    while (length(x) && !nzchar(trimws(x[length(x)]))) x <- x[-length(x)]
    x
  } else character()
  list(text = text, md = paste(text, collapse = "\n"),
       failed = !is.null(err), error = err,
       message = if (is.null(err)) "" else msg5(err),
       class = if (is.null(err)) character() else class(err),
       knit = kn,
       failures = if (is.null(kn)) NULL else kn$failures,
       cond = if (is.null(kn)) NULL else kn$condition_log,
       reads = if (is.null(kn)) NULL else kn$reads,
       offset = length(hdr) + length(pyc),
       dir = dir, input = input, log = logv, searched = searched)
}

# k5() of tagged cases: `cases` is a named character vector; each element is
# one paragraph, written as "<name> <source>"; `before` is lines (a chunk, say)
# put ahead of the cases. Adds to the result:
#   at       the file line of each case's first line (named by tag)
#   line(t)  the output line that starts with the tag
#   fail(t)  the rows of `failures` at that case's line
k5_cases <- function(cases, before = NULL, ...) {
  body <- before
  rel <- integer(length(cases))
  for (i in seq_along(cases)) {
    rel[i] <- length(body) + 1L
    body <- c(body, paste(names(cases)[i], cases[[i]]), "")
  }
  res <- k5(body, ...)
  at <- res$offset + rel
  names(at) <- names(cases)
  res$at <- at
  res$line <- function(tag) {
    hit <- grep(paste0("^", tag, " "), res$text, value = TRUE)
    if (length(hit)) hit[1] else NA_character_
  }
  res$fail <- function(tag) {
    f <- res$failures
    if (is.null(f)) return(NULL)
    f[f$line == at[[tag]], , drop = FALSE]
  }
  res$marker <- function(tag, kind) {
    sprintf("<<weft: %s, line %d>>", kind, at[[tag]])
  }
  res
}

# ---- documents knitted in a fresh process ---------------------------------------
#
# A fresh Rscript knits doc.Rmd (render_rmd(in_process = FALSE)) with the
# development weft installed into a temp library. No Python is needed by the
# caller: the child starts its own (or fails to, for M16). Returns render_rmd()'s
# list (text, failed, message, log, ...). `env` names RETICULATE_PYTHON and so on.
k5_fresh <- function(lines, env = NULL, draft = FALSE) {
  skip_if_no_reticulate()
  vars <- c(RETICULATE_USE_MANAGED_VENV = "no")
  py <- Sys.getenv("RETICULATE_PYTHON")
  if (!nzchar(py) && nzchar(Sys.which("python3"))) py <- unname(Sys.which("python3"))
  if (nzchar(py)) vars[["RETICULATE_PYTHON"]] <- py
  if (draft) vars[["WEFT_DRAFT"]] <- "1"
  for (n in names(env)) vars[[n]] <- env[[n]]
  render_rmd(lines, in_process = FALSE, format = "knit", env = vars)
}

# R code in a fresh vanilla process, seeing the development weft. Returns
# stdout lines (stderr in attr "stderr").
r5_fresh <- function(code, env = NULL) {
  dir <- tempfile("weft-r5-")
  dir.create(dir)
  script <- file.path(dir, "script.R")
  writeLines(code, script)
  lib <- weft_test_lib()
  vars <- c(R_LIBS = paste(c(if (nzchar(lib)) lib, .libPaths()), collapse = .Platform$path.sep),
            RETICULATE_USE_MANAGED_VENV = "no")
  py <- Sys.getenv("RETICULATE_PYTHON")
  if (!nzchar(py) && nzchar(Sys.which("python3"))) py <- unname(Sys.which("python3"))
  if (nzchar(py)) vars[["RETICULATE_PYTHON"]] <- py
  for (n in names(env)) vars[[n]] <- env[[n]]
  errf <- tempfile()
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)),
    stdout = TRUE, stderr = errf,
    env = sprintf("%s=%s", names(vars), unname(vars))
  ))
  e <- readLines(errf, warn = FALSE)
  if (length(e)) attr(out, "stderr") <- e
  out
}
