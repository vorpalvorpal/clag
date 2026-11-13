# Package 5c, part one: activation (rules G18 and G23, G24 of dev/design-5.md).
# weft_setup() loads no Python and no reticulate; it hooks Python's start; the
# module `weft` is registered once, never over another module of that name.
# Written before the code. Made-up values only.
#
# Fresh processes: nothing here may share a process with another test, because
# the rules are about what a process has or has not loaded. Each scenario is one
# short Rscript run through r5_fresh() (helper-5.R), printing `key=value` lines
# that kv5() (helper-5c.R) reads back.
#
# Interface fixed by these tests (the note leaves it open): none beyond the
# note's own names. `weft::py_value()` (G8) is used only as "a first guest read".

# ---- G18: weft_setup() loads nothing, and hooks Python's start --------------------

g18_start_script <- c(
  "weft::weft_setup()",
  "cat('LOADED1=', 'reticulate' %in% loadedNamespaces(), '\\n', sep = '')",
  "weft::weft_setup()",
  "cat('HOOKS=', length(getHook('reticulate.onPyInit')), '\\n', sep = '')",
  "cat('LOADED2=', 'reticulate' %in% loadedNamespaces(), '\\n', sep = '')",
  "library(reticulate)",
  "py_run_string('import sys\\nt_pre = (\\'weft\\' in sys.modules)')",
  "py_run_string('from weft import fmt_num; s = fmt_num(3.14159)')",
  "cat('S=', py$s, '\\n', sep = '')",
  "py_run_string(paste(",
  "  'import sys, warnings, __main__',",
  "  't_flags = [sys.modules[\\'weft\\'].__weft_r__ is True,',",
  "  '           \\'weft_guest\\' in sys.modules,',",
  "  '           \\'weft_guest\\' not in dir(__main__),',",
  "  '           warnings.showwarning is not warnings._showwarning_orig]',",
  "  sep = '\\n'))",
  "cat('PRE=', py$t_pre, '\\n', sep = '')",
  "cat('FLAGS=', paste(unlist(py$t_flags), collapse = ','), '\\n', sep = '')"
)

g18_start <- function() {
  skip_if_no_python()
  .w5c$start <- .w5c$start %||% kv5(r5_fresh(g18_start_script))
  .w5c$start
}
.w5c <- new.env()
`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("G18: weft_setup() in a fresh process loads no reticulate, whether it is called once or twice", {
  r <- g18_start()
  expect_identical(r[["LOADED1"]], "FALSE")
  expect_identical(r[["LOADED2"]], "FALSE")
})

test_that("G18: calling weft_setup() twice adds one hook to reticulate.onPyInit, not two", {
  r <- g18_start()
  expect_identical(r[["HOOKS"]], "1")
})

test_that("G18: when Python starts the hook has registered weft's module before any import of it", {
  r <- g18_start()
  # `weft` was in sys.modules at the first line of Python, before `from weft import`
  expect_identical(r[["PRE"]], "TRUE")
})

test_that("G18: library(reticulate), then 'from weft import fmt_num' in Python gives \"3.1\"", {
  r <- g18_start()
  expect_identical(r[["S"]], "3.1")
})

test_that("G18, G16, G25: the hook registers the module (__weft_r__), the helper module weft_guest (not in __main__) and the warning recorder", {
  r <- g18_start()
  # __weft_r__ is True; weft_guest in sys.modules; weft_guest not a name in __main__;
  # warnings.showwarning is no longer Python's own
  expect_identical(r[["FLAGS"]], "TRUE,TRUE,TRUE,TRUE")
})

test_that("G18: with reticulate loaded but Python not yet started, weft_setup() adds the hook and the module appears when Python starts", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    "cat('RUNNING=', py_available(), '\\n', sep = '')",
    "weft::weft_setup()",
    "cat('HOOKS=', length(getHook('reticulate.onPyInit')), '\\n', sep = '')",
    "cat('STILL=', py_available(), '\\n', sep = '')",
    "py_run_string('from weft import fmt_num; s = fmt_num(3.14159)')",
    "cat('S=', py$s, '\\n', sep = '')")))
  expect_identical(out[["RUNNING"]], "FALSE")
  expect_identical(out[["HOOKS"]], "1")
  expect_identical(out[["STILL"]], "FALSE")   # weft_setup() does not start Python
  expect_identical(out[["S"]], "3.1")
})

test_that("G18: with Python already running, weft_setup() registers the module at once", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    "py_run_string('t_started = 1')",
    "cat('RUNNING=', py_available(), '\\n', sep = '')",
    "weft::weft_setup()",
    "py_run_string('from weft import fmt_num; s = fmt_num(3.14159)')",
    "cat('S=', py$s, '\\n', sep = '')")))
  expect_identical(out[["RUNNING"]], "TRUE")
  expect_identical(out[["S"]], "3.1")
})

test_that("G18: the first guest read registers the module when weft_setup() was never called", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    "py_run_string('import sys\\nt_has_before = (\\'weft\\' in sys.modules)')",
    "r <- try(weft::py_value('t_g5c_never_set'), silent = TRUE)",
    "py_run_string('t_has_after = (\\'weft\\' in sys.modules)')",
    "cat('BEFORE=', py$t_has_before, '\\n', sep = '')",
    "cat('AFTER=', py$t_has_after, '\\n', sep = '')")))
  expect_identical(out[["BEFORE"]], "FALSE")
  expect_identical(out[["AFTER"]], "TRUE")
})

test_that("G18: the first Python chunk of a knit registers the module, so 'from weft import' works in it", {
  skip_if_no_python()
  res <- k5_fresh(c(
    "```{python gs1, echo=FALSE, results='asis'}",
    "from weft import fmt_num, plural",
    "print(fmt_num(3.14159) + ' and ' + plural(3, '# site', '# sites'))",
    "```"))
  expect_false(res$failed, label = res$message)
  expect_match(paste(res$text, collapse = "\n"), "3.1 and 3 sites", fixed = TRUE)
})

# ---- G18: the message when `py` is used before any Python chunk ---------------------

test_that("G18, G7: prose reading a Python name before any Python chunk is a collected no value with M13's exact text; weft needs no library(reticulate)", {
  skip_if_no_python()
  res <- k5_fresh(c("Depth `r py$t_g5c_never_set`{.num} m."))
  expect_true(res$failed)
  msg <- msg5(res$message)
  expect_true(grepl(m13("py$t_g5c_never_set", "t_g5c_never_set"), msg, fixed = TRUE),
              label = msg)
  expect_false(grepl("object 'py' not found", msg, fixed = TRUE))
})

test_that("G18: py_value() before any Python chunk raises weft_guest_error with M13's exact text", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "e <- tryCatch(weft::py_value('t_g5c_never_set'), error = function(e) e)",
    "cat('CLASS=', paste(class(e), collapse = ','), '\\n', sep = '')",
    "cat('MSG=', trimws(gsub('[[:space:]]+', ' ', conditionMessage(e))), '\\n', sep = '')")))
  expect_match(out[["CLASS"]], "weft_guest_error", fixed = TRUE)
  expect_identical(out[["MSG"]], m13("py_value(\"t_g5c_never_set\")", "t_g5c_never_set"))
})

# ---- G23: a module named `weft` that is not weft's ---------------------------------

g23_dummy <- paste0(
  "py_run_string(paste('import sys, types',",
  "  'd = types.ModuleType(\\'weft\\')', 'd.marker = 1',",
  "  'sys.modules[\\'weft\\'] = d', sep = '\\n'))")

g23_report <- c(
  "cat('NWARN=', length(w), '\\n', sep = '')",
  "if (length(w)) {",
  "  cat('CLASS=', paste(class(w[[1]]), collapse = ','), '\\n', sep = '')",
  "  cat('MSG=', trimws(gsub('[[:space:]]+', ' ', conditionMessage(w[[1]]))), '\\n', sep = '')",
  "}",
  "py_run_string(paste('t_same = sys.modules[\\'weft\\'] is d',",
  "  't_marker = getattr(d, \\'marker\\', None) == 1',",
  "  't_has_fmt = hasattr(d, \\'fmt_num\\')', sep = '\\n'))",
  "cat('KEPT=', py$t_same, ',', py$t_marker, ',', py$t_has_fmt, '\\n', sep = '')")

m17_text <- "A Python module named `weft` is already loaded, so weft's function forms are not registered (rule 2.12.8)."

test_that("G23: weft_setup() with another module named weft loaded warns once with M17 (class weft_guest_warning), however often it is called", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    g23_dummy,
    "w <- list()",
    "withCallingHandlers({",
    "  weft::weft_setup()",
    "  weft::weft_setup()",
    "  try(weft::py_value('t_g5c_never_set'), silent = TRUE)",
    "}, warning = function(c) { w[[length(w) + 1L]] <<- c; invokeRestart('muffleWarning') })",
    g23_report)))
  expect_identical(out[["NWARN"]], "1")
  expect_match(out[["CLASS"]], "weft_guest_warning", fixed = TRUE)
  expect_identical(out[["MSG"]], m17_text)
})

test_that("G23: the other module is kept: not replaced, no function forms put into it", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    g23_dummy,
    "w <- list()",
    "withCallingHandlers(weft::weft_setup(),",
    "  warning = function(c) { w[[length(w) + 1L]] <<- c; invokeRestart('muffleWarning') })",
    g23_report)))
  expect_identical(out[["KEPT"]], "TRUE,TRUE,FALSE")
})

test_that("G23: the first guest read finds the other module too: one warning per R session, not one per read", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    g23_dummy,
    "w <- list()",
    "withCallingHandlers({",
    "  try(weft::py_value('t_g5c_never_set'), silent = TRUE)",
    "  try(weft::py_value('t_g5c_never_set'), silent = TRUE)",
    "  try(weft::py_value('t_g5c_never_set'), silent = TRUE)",
    "}, warning = function(c) { w[[length(w) + 1L]] <<- c; invokeRestart('muffleWarning') })",
    g23_report)))
  expect_identical(out[["NWARN"]], "1")
  expect_match(out[["CLASS"]], "weft_guest_warning", fixed = TRUE)
  expect_identical(out[["MSG"]], m17_text)
  expect_identical(out[["KEPT"]], "TRUE,TRUE,FALSE")
})

test_that("G23: a module named weft that carries __weft_r__ is weft's own and raises no warning when weft_setup() runs again", {
  skip_if_no_python()
  out <- kv5(r5_fresh(c(
    "weft::weft_setup()",
    "library(reticulate)",
    "py_run_string('import sys')",   # Python starts here, the hook registers the module
    "w <- list()",
    "withCallingHandlers({",
    "  weft::weft_setup()",
    "  weft::weft_setup()",
    "}, warning = function(c) { w[[length(w) + 1L]] <<- c; invokeRestart('muffleWarning') })",
    "cat('NWARN=', length(w), '\\n', sep = '')")))
  expect_identical(out[["NWARN"]], "0")
})

# ---- G24: python.reticulate = FALSE is not supported ---------------------------------

test_that("G24: with python.reticulate = FALSE each chunk is a separate Python process, so a guest read of its name is M13 (pinned)", {
  skip_if_no_python()
  py3 <- unname(Sys.which("python3"))
  skip_if(!nzchar(py3), "no python3 on the PATH for knitr's own Python engine")
  res <- k5_cases(
    c(G24 = "Depth `r py$t_g5c_ext_only`{.num} m."),
    before = c(sprintf("```{python gx1, python.reticulate=FALSE, engine.path='%s'}", py3),
               "t_g5c_ext_only = 3.5",
               "```", ""), draft = TRUE)
  expect_false(is.null(res$failures))
  f <- res$fail("G24")
  expect_identical(nrow(f), 1L)
  expect_true(grepl(m13("py$t_g5c_ext_only", "t_g5c_ext_only"), msg5(f$detail), fixed = TRUE),
              label = f$detail)
  expect_true(grepl(res$marker("G24", "no value"), res$md, fixed = TRUE))
})
