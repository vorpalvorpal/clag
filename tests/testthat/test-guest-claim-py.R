# Package 6k: claim() from Python, knitr back end (rules N50 to N52, N54, N58, N60 of
# dev/design-6.md; messages E50 to E58 of section 7).
# Written before the code. Made-up values only. Helpers: helper-6k.R, helper-5.R, helper-5c.R.
#
# One Python session serves the file (this process's). Every name a test sets in Python starts
# t_6k_. A document with many chunks is knitted once and read by several tests (memo5d()). Chunk
# options say error = TRUE or error = FALSE explicitly: knitr::knit() alone prints a chunk error and
# goes on, rmarkdown::render() stops.
#
# READINGS of the note (see the report):
#  - "{check}" in a detail is the check's text as written. For an operator check ("> 10") the note
#    does not say whether it is shown as written or as "_ > 10"; the tests take either.
#  - a check that gave no bool: the detail holds "{check} gave a {type}, not True or False"
#    somewhere after the check text; the tests do not pin whether "was false (value ..)" comes first.
#  - when two checks of one call both fail, at least one row is recorded; the tests pin the first.
#  - a claim on a missing or refused value runs the check on the Python object itself (the record
#    is only for the text of {val}); the text of {val} for such a value is not pinned.
#  - in draft mode with error = TRUE a failed claim is printed in the document and the knit goes on.

E50_PY <- "claim() needs at least one check."
E51_PY <- "a check is a string, such as \"> 10\" or \"_ % 2 == 0\"."
E54_PY <- "level is \"fail\" or \"warn\"."

# the N58 expr of a Python claim: claim, (, U+2026, ", ", each check as repr() shows it, ")"
expr6k <- function(...) paste0("claim(…, ", paste(sprintf("'%s'", c(...)), collapse = ", "), ")")

# ---- the module: names, exceptions, the same code under knitr (N3, N60, G19) -----------------------

test_that("N60 + G19: the module offers every name stage 5 pinned, and now claim, put, auto and the three exceptions", {
  py_forms_ready()
  new <- c("claim", "put", "auto", "ClaimFailed", "WeftError", "PublishError")
  has <- reticulate::py_eval(sprintf(
    "[hasattr(__import__('weft'), n) for n in %s]",
    paste0("[", paste0("'", c(g5c_names, new), "'", collapse = ", "), "]")))
  expect_identical(unlist(has), rep(TRUE, length(g5c_names) + length(new)))
  ok <- reticulate::py_eval(sprintf(
    "all(callable(getattr(__import__('weft'), n)) for n in %s)",
    paste0("[", paste0("'", c(g5c_names, new), "'", collapse = ", "), "]")))
  expect_true(ok)
})

test_that("N59 + N60: from weft import claim no longer raises ImportError; claim, put and auto import, and __weft_r__ is True", {
  py_forms_ready()
  r <- py_try("from weft import claim, put, auto, ClaimFailed, WeftError, PublishError")
  expect_true(r$ok, label = r$msg)
  expect_identical(reticulate::py_eval("__import__('weft').__weft_r__ is True"), TRUE)
})

test_that("N60: names weft does not define are still Python's ImportError", {
  py_forms_ready()
  for (n in c("u", "fmt_unit", "lookup", "brk", "glue_vec", "read_dict", "dict_glossary", "dict_vale",
              "dict_seed", "clamp")) {
    r <- py_try(sprintf("from weft import %s", n))
    expect_false(r$ok, label = n)
    expect_identical(r$type, "ImportError", label = n)
  }
})

test_that("N3: the exception classes: ClaimFailed is a WeftError and an AssertionError, PublishError a WeftError and a TypeError", {
  py_forms_ready()
  v <- reticulate::py_eval(paste0(
    "(lambda w: [issubclass(w.WeftError, Exception), issubclass(w.ClaimFailed, w.WeftError), ",
    "issubclass(w.ClaimFailed, AssertionError), issubclass(w.PublishError, w.WeftError), ",
    "issubclass(w.PublishError, TypeError)])(__import__('weft'))"))
  expect_identical(unlist(v), rep(TRUE, 5L))
})

test_that("N60: one classifier: weft_guest's classify is the package's weft._record.classify", {
  py_forms_ready()
  expect_identical(reticulate::py_eval(
    "__import__('sys').modules['weft_guest'].classify is __import__('weft')._record.classify"), TRUE)
})

# ---- N50: the refusals (raised before anything is recorded) ----------------------------------------

test_that("N50 E50: no check is a TypeError with the text of E50", {
  py_forms_ready()
  r <- py_try("from weft import claim\nclaim(5)")
  expect_false(r$ok)
  expect_identical(r$type, "TypeError")
  expect_identical(r$msg, E50_PY)
})

test_that("N50 E51: a check that is not a str (a lambda, a number, a bytes) is a TypeError with the text of E51", {
  py_forms_ready()
  for (code in c("claim(5, lambda v: v > 3)", "claim(5, 4)", "claim(5, '> 3', 4)", "claim(5, b'> 3')")) {
    r <- py_try(paste0("from weft import claim\n", code))
    expect_false(r$ok, label = code)
    expect_identical(r$type, "TypeError", label = code)
    expect_identical(r$msg, E51_PY, label = code)
  }
})

test_that("N50 E54: a level other than \"fail\" or \"warn\" is a ValueError with the text of E54", {
  py_forms_ready()
  for (lv in c("'error'", "'WARN'", "''", "None", "True")) {
    r <- py_try(sprintf("from weft import claim\nclaim(5, '> 3', level=%s)", lv))
    expect_false(r$ok, label = lv)
    expect_identical(r$type, "ValueError", label = lv)
    expect_identical(r$msg, E54_PY, label = lv)
  }
})

# ---- N50, N51, N52, N58: failures, in one document -------------------------------------------------

py_doc_a <- function() {
  memo5d("6k-py-a", function() {
    lines <- c(
      pc6k("pa1", "t_6k_n1 = 3", "claim(t_6k_n1, '> 10')"),
      pc6k("pa2", "t_6k_n2 = 7", "claim(t_6k_n2, '_ % 2 == 0')"),
      pc6k("pa3", "t_6k_thr = 100", "t_6k_n3 = 3", "claim(t_6k_n3, '_ > t_6k_thr')"),
      pc6k("pa4", "t_6k_n4 = 12", "claim(t_6k_n4, '> 10', '< 5')"),
      pc6k("pa5", "claim(5, '_ + 1')"),
      pc6k("pa6", "claim(5, '[]')"),
      pc6k("pa7", "claim(5, 'None')"),
      pc6k("pa8", "claim(5, '_ / 0 > 1')"),
      pc6k("pa9", "def t_6k_f():", "    limit = 100", "    return claim(3, '_ > limit')", "t_6k_f()"),
      pc6k("pa10", "claim(None, '> 10')"),
      pc6k("pa11", "t_6k_mixed = [1, 'a']", "claim(t_6k_mixed, 'len(_) == 3')"),
      pc6k("pa12", "claim(7, '> 10', '< 5')"),
      pc6k("pw1", "t_6k_w = claim(3, '> 10', level='warn')"),
      pc6k("pw2", "t_6k_w2 = claim(3, '> 10', '< 5', level='warn')"),
      pc6k("pp1",
           "t_6k_p1 = claim(12, '> 10')",
           "t_6k_o = [1, 2, 3]",
           "t_6k_p2 = claim(t_6k_o, 'len(_) == 3')",
           "t_6k_p3 = claim(7, '>= 7', '<= 7', '== 7', '!= 8', '< 8', '> 6')",
           "t_6k_p4 = claim(7, '  > 6')",
           "t_6k_p5 = claim(7, '_ % 2 == 1')",
           "t_6k_p6 = claim('abc', \"== 'abc'\")",
           "t_6k_p7 = claim(2, 'not _ > 11', '_ in (1, 2)')",
           "t_6k_p8 = claim(t_6k_mixed, 'len(_) == 2')",
           opts = "error=FALSE"),
      pc6k("pz", "t_6k_after = 1", opts = "error=FALSE"))
    k5(lines, py = c("from weft import claim"))
  })
}

test_that("the failing document knits to its end under error = TRUE and then fails once with weft's failure report", {
  res <- py_doc_a()
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class, label = paste(res$class, collapse = ","))
  expect_identical(reticulate::py_eval("t_6k_after"), 1L)      # the chunks after the failures ran
})

test_that("N52: each failing chunk has a failed claim row located by its label; passing and warned chunks have none", {
  res <- py_doc_a()
  f <- res$failures
  expect_true(all(f$kind == "failed claim"))
  expect_setequal(unique(f$chunk), paste0("pa", 1:12))
  expect_equal(nrow(rows6k(f, c("pw1", "pw2", "pp1", "pz"))), 0L)
})

test_that("N52 N58: a failed operator check: expr is claim(<U+2026>, '> 10'), detail says the check was false and the value", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa1")
  expect_equal(nrow(r), 1L)
  expect_identical(as.character(r$expr), expr6k("> 10"))
  expect_match(det6k(r), "^(_ )?> 10 was false \\(value 3\\)$")
})

test_that("N50 N58: a check that is not an operator form is an expression in _, and is shown as written", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa2")
  expect_equal(nrow(r), 1L)
  expect_identical(as.character(r$expr), expr6k("_ % 2 == 0"))
  expect_identical(det6k(r), "_ % 2 == 0 was false (value 7)")
})

test_that("N50: the check sees a global of the caller (threshold = 100), and a local of the calling function", {
  res <- py_doc_a()
  r3 <- rows6k(res$failures, "pa3")
  expect_equal(nrow(r3), 1L)
  expect_identical(det6k(r3), "_ > t_6k_thr was false (value 3)")
  r9 <- rows6k(res$failures, "pa9")
  expect_equal(nrow(r9), 1L)
  expect_identical(det6k(r9), "_ > limit was false (value 3)")
})

test_that("N50 N58: several checks: only the failing one is a row; expr lists every check, joined by a comma and a space", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa4")
  expect_equal(nrow(r), 1L)
  expect_identical(as.character(r$expr), expr6k("> 10", "< 5"))
  expect_match(det6k(r), "^(_ )?< 5 was false \\(value 12\\)$")
})

test_that("N50: two failing checks in one call: at least the first is recorded, with its own text", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa12")
  expect_gte(nrow(r), 1L)
  expect_lte(nrow(r), 2L)
  expect_match(det6k(r)[[1]], "^(_ )?> 10 was false \\(value 7\\)$")
  expect_identical(as.character(r$expr)[[1]], expr6k("> 10", "< 5"))
})

test_that("N50 E53 N58: a check whose result is not a bool (0-like int, a list, None) is a failed check, with no truthiness", {
  res <- py_doc_a()
  cases <- c(pa5 = "int", pa6 = "list", pa7 = "NoneType")
  src <- c(pa5 = "_ + 1", pa6 = "[]", pa7 = "None")
  for (lb in names(cases)) {
    r <- rows6k(res$failures, lb)
    expect_equal(nrow(r), 1L, label = lb)
    d <- det6k(r)
    expect_match(d, sprintf("gave a %s, not True or False", cases[[lb]]), fixed = TRUE, label = lb)
    expect_true(startsWith(d, src[[lb]]), label = paste(lb, "starts with its check"))
    expect_identical(as.character(r$expr), expr6k(src[[lb]]), label = lb)
  }
})

test_that("N50 N58: an exception raised while evaluating a check is a failed check whose why is Type: message", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa8")
  expect_equal(nrow(r), 1L)
  d <- det6k(r)
  expect_true(startsWith(d, "_ / 0 > 1 "))
  expect_match(d, "; ZeroDivisionError: ", fixed = TRUE)
})

test_that("a claim on a missing value (None) is a failed check carrying the TypeError the comparison raised", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa10")
  expect_equal(nrow(r), 1L)
  expect_match(det6k(r), "TypeError: ", fixed = TRUE)
  expect_match(det6k(r), "^(_ )?> 10 ")
})

test_that("a claim on a value weft would refuse (a list of two kinds) runs the check on the Python object itself", {
  res <- py_doc_a()
  r <- rows6k(res$failures, "pa11")
  expect_equal(nrow(r), 1L)
  expect_true(startsWith(det6k(r), "len(_) == 3 was false (value "))
  # the passing check on the same object returned it, and nothing was recorded for chunk pp1
  expect_identical(reticulate::py_eval("t_6k_p8 is t_6k_mixed"), TRUE)
})

# ---- N50: what a passing claim returns -------------------------------------------------------------

test_that("N50: a passing claim returns x itself (the same object), whatever the number and forms of checks", {
  py_doc_a()
  expect_identical(reticulate::py_eval("t_6k_p1"), 12L)
  expect_identical(reticulate::py_eval("t_6k_p2 is t_6k_o"), TRUE)
  expect_identical(reticulate::py_eval("t_6k_p3"), 7L)
  expect_identical(reticulate::py_eval("t_6k_p4"), 7L)
  expect_identical(reticulate::py_eval("t_6k_p5"), 7L)
  expect_identical(reticulate::py_eval("t_6k_p6"), "abc")
  expect_identical(reticulate::py_eval("t_6k_p7"), 2L)
})

test_that("N50: a leading space before the operator is allowed, and the value may be used on", {
  py_doc_a()
  expect_identical(reticulate::py_eval("t_6k_p4 + 1"), 8L)
})

# ---- N51, N52: a warned check ----------------------------------------------------------------------

test_that("N51 N52: level=\"warn\" returns x, raises nothing, and joins last_knit()$warnings with the same expr and detail", {
  res <- py_doc_a()
  expect_identical(reticulate::py_eval("t_6k_w"), 3L)
  w <- rows6k(res$knit$warnings, "pw1")
  expect_equal(nrow(w), 1L)
  expect_identical(as.character(w$expr), expr6k("> 10"))
  expect_match(det6k(w), "^(_ )?> 10 was false \\(value 3\\)$")
  expect_equal(nrow(rows6k(res$failures, "pw1")), 0L)
})

test_that("N51: two warned checks in one call: the failing one only is a warned row", {
  res <- py_doc_a()
  expect_identical(reticulate::py_eval("t_6k_w2"), 3L)
  w <- rows6k(res$knit$warnings, "pw2")
  expect_equal(nrow(w), 1L)
  expect_match(det6k(w), "^(_ )?> 10 was false \\(value 3\\)$")
})

# ---- N52: a failed claim stops the knit (O2), unless the chunk says error = TRUE ---------------------

test_that("N51 N52: a failed claim in a chunk with error = FALSE stops the knit with ClaimFailed and its message E55, and is recorded first", {
  res <- k5(c(pc6k("stopper", "claim(3, '> 10')", opts = "error=FALSE"),
              pc6k("never", "t_6k_never = 1", opts = "error=FALSE")),
            py = "from weft import claim")
  expect_true(res$failed)
  expect_match(res$message, "a claim failed: (_ )?> 10 was false \\(value 3\\)")
  expect_match(res$message, "ClaimFailed", fixed = TRUE)
  expect_identical(reticulate::py_eval("'t_6k_never' in globals()"), FALSE)   # the chunk after never ran
  r <- rows6k(res$failures, "stopper")                                         # recorded, then raised
  expect_equal(nrow(r), 1L)
  expect_identical(as.character(r$kind), "failed claim")
  expect_identical(as.character(r$expr), expr6k("> 10"))
})

test_that("N52: with error = TRUE the chunk goes on and the knit fails at its end with the claim in the report, located by the chunk label", {
  res <- k5(c(pc6k("goes-on", "claim(3, '> 10')", "t_6k_same_chunk = 1", opts = "error=TRUE"),
              pc6k("later", "t_6k_later = 1", opts = "error=FALSE")),
            py = "from weft import claim")
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  expect_match(res$message, "> 10", fixed = TRUE)
  expect_match(res$message, "goes-on", fixed = TRUE)
  expect_identical(reticulate::py_eval("t_6k_later"), 1L)
  expect_equal(nrow(rows6k(res$failures, "goes-on")), 1L)
})

test_that("N52: in draft mode with error = TRUE the failed claim is printed in the document and the knit goes on", {
  res <- k5(c(pc6k("drafty", "claim(3, '> 10')", opts = "error=TRUE"), "", "AFTER-6K", ""),
            py = "from weft import claim", draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "AFTER-6K", fixed = TRUE)
  expect_match(res$md, "a claim failed", fixed = TRUE)
})

test_that("N52: a failed claim caught by try/except in Python is still recorded, and the render fails at its end", {
  res <- k5(pc6k("caught", "try:", "    claim(3, '> 10')", "except AssertionError:", "    t_6k_caught = 1",
                 opts = "error=FALSE"),
            py = "from weft import claim")
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  expect_identical(reticulate::py_eval("t_6k_caught"), 1L)
  expect_equal(nrow(rows6k(res$failures, "caught")), 1L)
})

# ---- numpy: numpy.bool_ is a bool, an array is not (N50) -------------------------------------------

test_that("N50: a numpy.bool_ result passes; a numpy array result is a failed check (E53)", {
  skip_if_no_py_module("numpy")
  res <- k5(c(pc6k("np1", "import numpy as t_6k_np", "t_6k_npr = claim(5, '_ > t_6k_np.int64(3)')",
                   opts = "error=FALSE"),
              pc6k("np2", "claim(5, 't_6k_np.array([True, True])')", opts = "error=TRUE")),
            py = "from weft import claim")
  expect_identical(reticulate::py_eval("t_6k_npr"), 5L)
  expect_equal(nrow(rows6k(res$failures, "np1")), 0L)
  r <- rows6k(res$failures, "np2")
  expect_equal(nrow(r), 1L)
  expect_match(det6k(r), "gave a (numpy\\.)?ndarray, not True or False")
})

# ---- N54: no back end -----------------------------------------------------------------------------

test_that("N54: in plain Python (no IPython, no R) a failed check raises at once and a warned one calls warnings.warn", {
  py <- py_exe6k()
  script <- withr::local_tempfile(fileext = ".py")
  writeLines(c(
    "import sys, warnings",
    sprintf("sys.path.insert(0, %s)", encodeString(py_lib6k(), quote = "'")),
    "from weft import claim, ClaimFailed, WeftError",
    "print('PASS=' + repr(claim(11, '> 10')))",
    "try:",
    "    claim(3, '> 10')",
    "    print('RAISED=no')",
    "except ClaimFailed as e:",
    "    print('RAISED=ClaimFailed')",
    "    print('ASSERT=' + str(isinstance(e, AssertionError)))",
    "    print('WEFTERR=' + str(isinstance(e, WeftError)))",
    "    print('MSG=' + str(e))",
    "with warnings.catch_warnings(record=True) as w:",
    "    warnings.simplefilter('always')",
    "    r = claim(3, '> 10', level='warn')",
    "print('WARNRET=' + repr(r))",
    "print('NW=' + str(len(w)))",
    "print('WCAT=' + (w[0].category.__name__ if w else ''))",
    "print('WMSG=' + (str(w[0].message) if w else ''))",
    "try:",
    "    claim(3, lambda v: v > 1)",
    "except TypeError as e:",
    "    print('E51=' + str(e))"), script)
  out <- suppressWarnings(system2(py, c("-I", shQuote(script)), stdout = TRUE, stderr = TRUE))
  kv <- kv5(out)
  expect_identical(kv$PASS, "11", label = paste(out, collapse = " | "))
  expect_identical(kv$RAISED, "ClaimFailed")
  expect_identical(kv$ASSERT, "True")
  expect_identical(kv$WEFTERR, "True")
  e55 <- "^weft: a claim failed: (_ )?> 10 was false \\(value 3\\)\\.$"
  expect_match(kv$MSG, e55)
  expect_identical(kv$WARNRET, "3")
  expect_identical(kv$NW, "1")
  expect_identical(kv$WCAT, "UserWarning")
  expect_match(kv$WMSG, e55)
  expect_identical(kv$E51, E51_PY)
})

# ---- N60: a pip-style weft already imported ---------------------------------------------------------

test_that("N60: a weft package imported before R registers (as pip would install it) is used, not refused, and gets R's forms", {
  skip_if_no_python()
  lib <- py_lib6k()
  # the package's own python folder is part of weft (N60): its absence is the package failing, not a skip
  if (!expect_precondition(dir.exists(file.path(lib, "weft")), "inst/python/weft exists")) return(invisible())
  out <- kv5(r5_fresh(c(
    "library(reticulate)",
    sprintf("py_run_string(paste('import sys', 'sys.path.insert(0, \"%s\")', 'import weft as t_w',", lib),
    "  't_id = id(t_w)', 't_pkg = bool(getattr(t_w, \\'__weft_package__\\', False))', sep = '\\n'))",
    "w <- list()",
    "withCallingHandlers(weft::weft_setup(),",
    "  warning = function(c) { w[[length(w) + 1L]] <<- c; invokeRestart('muffleWarning') })",
    "py_run_string(paste('import sys', 'import weft as t_w2',",
    "  'from weft import fmt_num, claim',",
    "  't_same = (t_w2 is t_w)', 't_r = (getattr(t_w2, \\'__weft_r__\\', False) is True)',",
    "  't_fmt = fmt_num(3.14159)', 't_ok = claim(11, \\'> 10\\')',",
    "  't_cls = (sys.modules[\\'weft_guest\\'].classify is t_w2._record.classify)', sep = '\\n'))",
    "cat('PKG=', py$t_pkg, '\\n', sep = '')",
    "cat('NWARN=', length(w), '\\n', sep = '')",
    "cat('SAME=', py$t_same, '\\n', sep = '')",
    "cat('R=', py$t_r, '\\n', sep = '')",
    "cat('FMT=', py$t_fmt, '\\n', sep = '')",
    "cat('OK=', py$t_ok, '\\n', sep = '')",
    "cat('CLS=', py$t_cls, '\\n', sep = '')")))
  expect_identical(out[["PKG"]], "TRUE")
  expect_identical(out[["NWARN"]], "0")
  expect_identical(out[["SAME"]], "TRUE")
  expect_identical(out[["R"]], "TRUE")
  expect_identical(out[["FMT"]], "3.1")
  expect_identical(out[["OK"]], "11")
  expect_identical(out[["CLS"]], "TRUE")
})
