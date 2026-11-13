# Helpers for the stage 5c and 5d tests (function forms from Python, the
# Python warning recorder, Python modules in the ledger's reads: rules G18 to
# G32 of dev/design-5.md). They sit beside helper-5.R and reuse its
# skip_if_no_python(), py_set(), k5(), k5_fresh(), r5_fresh() and msg5(); nothing
# here edits helper-5.R, and nothing here reads R/ or inst/python/.
#
# ---- THE INTERFACE THE TESTS FIX (internal; the note leaves it open) --------
#
# Only things the note names are used:
#   weft::weft_setup(), weft::weft_str(), the Python module `weft` (G19),
#   last_knit()$conditions / $condition_log / $failures / $reads,
#   the condition log file _weft/ledger/<source>/<output>.conditions.jsonl and
#   the ledger header's `files` (helper-2d.R: d2_path(), d2_lines(), d2_header()).
# Two internals, both already used by the tests of stage 2e, are used for the
# "changed module makes the entry stale" case (G30):
#   weft:::read_ledger(lines = <ledger file lines>)   (header in attr "header")
#   weft:::ledger_state(dir, header)  -> list(stale, reasons, notes); a reason
#                                        is "<path> changed" (2e-2 C11)
#   weft:::file_hash(path)            the hash recorded in the header
#
# ---- helpers here -----------------------------------------------------------
#   plain5(x)               a weft_text or character vector as a bare character vector
#   py_forms_ready()        weft's Python module registered in THIS process
#                           (weft_setup() with Python running: G18), and its
#                           names imported into Python's main module
#   py_try(code)            runs one line of Python in main inside try/except and
#                           returns list(ok, type, msg), the message with white
#                           space made one space
#   py_val(expr)            the converted value of a Python expression (strings
#                           and lists of strings only: no weft read involved)
#   g5c_names               the 26 names of G19
#   py_cleanup(dir)         removes from sys.path and sys.modules what a test's
#                           project folder put there
#   py_preface              Python lines that make every warning show each time
#   proj5(lines, ...)       k5() in a set-up project (a _weft.yml with
#                           `draft: false`), for the tests that read the ledger
#   cond_lines(res)         the lines of the condition log file of a k5() result
#   hdr_files(res)          the `files` of the ledger header of a k5() result
#   cond_entries(res)       the condition log's entries (header dropped) as lists
#   pychunk(label, code, opts)  a Python chunk as lines
#   kv5(out)                `key=value` lines a fresh-process script printed, as a list
#   memo5d(key, f)          f() once per process

# ---- small ---------------------------------------------------------------------

plain5 <- function(x) {
  x <- unclass(x)
  attributes(x) <- NULL
  x
}

g5c_names <- c("fmt_num", "fmt_pct", "fmt_sci", "fmt_p", "fmt_date", "fmt_no",
               "fmt_word", "fmt_count", "fmt_ord", "fmt_and", "fmt_or",
               "fmt_pairs", "fmt_range", "fmt_ul", "fmt_ol", "fmt_dl", "fmt_a",
               "fmt_cap", "fmt_strong", "fmt_em", "plural", "ci", "pm", "about",
               "of_n", "weft_str")

# every warning shows each time, whatever an earlier knit in this process showed
py_preface <- c("import warnings", "warnings.simplefilter('always')")

# ---- Python in this process ----------------------------------------------------

py_forms_ready <- function() {
  skip_if_no_python()
  # G18: with Python running, weft_setup() registers the module at once
  weft::weft_setup()
  withr::defer(weft_restore_knitr(), envir = parent.frame())
  reticulate::py_run_string(paste0(
    "from weft import ", paste(g5c_names, collapse = ", "), "\n",
    "import datetime"))
  invisible(TRUE)
}

py_try <- function(code) {
  reticulate::py_run_string(paste0(
    "t_g5c_ok, t_g5c_type, t_g5c_msg = True, '', ''\n",
    "try:\n    ", gsub("\n", "\n    ", code), "\n",
    "except BaseException as e:\n",
    "    t_g5c_ok, t_g5c_type, t_g5c_msg = False, type(e).__name__, str(e)\n"))
  m <- reticulate::py_eval("t_g5c_msg")
  list(ok = reticulate::py_eval("t_g5c_ok"),
       type = reticulate::py_eval("t_g5c_type"),
       msg = trimws(gsub("[[:space:]]+", " ", m)))
}

py_val <- function(expr) reticulate::py_eval(expr)

# what a test's project folder left in Python: sys.path entries inside it and the
# modules loaded from it
py_cleanup <- function(dir) {
  d <- normalizePath(dir, mustWork = FALSE)
  reticulate::py_run_string(sprintf(paste0(
    "import sys as t_g5c_sys, os as t_g5c_os\n",
    "t_g5c_d = %s\n",
    "t_g5c_sys.path[:] = [p for p in t_g5c_sys.path if not "
    , "t_g5c_os.path.realpath(p).startswith(t_g5c_os.path.realpath(t_g5c_d))]\n",
    "for t_g5c_n in [n for n, m in list(t_g5c_sys.modules.items()) if "
    , "(getattr(m, '__file__', None) or '').startswith(t_g5c_os.path.realpath(t_g5c_d))]:\n",
    "    del t_g5c_sys.modules[t_g5c_n]\n"),
    encodeString(d, quote = "'")))
  invisible(NULL)
}

# ---- documents knitted in this process, in a set-up project ----------------------

proj5 <- function(lines, py = NULL, files = list(), weft_yml = "draft: false", ...) {
  k5(lines, py = py, files = files, weft_yml = weft_yml, ...)
}

cond_lines <- function(res) d2_lines(d2_path(res$dir, conditions = TRUE))

hdr_files <- function(res) d2_header(d2_path(res$dir))$files

# the condition log's entries (header dropped) as lists
cond_entries <- function(res) d2_entries(d2_path(res$dir, conditions = TRUE))

# a Python chunk, as lines
pychunk <- function(label, code, opts = NULL) {
  c(paste0("```{python ", label, if (length(opts)) paste0(", ", opts), "}"),
    code, "```", "")
}

# ---- fresh processes -----------------------------------------------------------

# the lines `key=value` a fresh-process script prints, as a named list of strings
kv5 <- function(out) {
  out <- grep("^[A-Za-z_0-9]+=", out, value = TRUE)
  setNames(as.list(sub("^[^=]*=", "", out)), sub("=.*$", "", out))
}

# compute once per R process; the value is whatever `f` returns (a skip or an error
# is not cached)
.w5d <- new.env()
memo5d <- function(key, f) {
  if (is.null(.w5d[[key]])) .w5d[[key]] <- f()
  .w5d[[key]]
}
