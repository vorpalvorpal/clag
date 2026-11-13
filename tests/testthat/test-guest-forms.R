# Package 5c, part two: function forms from Python (rules G19 to G22 of
# dev/design-5.md): the module `weft` that a Python chunk imports, its exact
# names, that it gives the text the R function gives, that its arguments are
# read by G5 and G6 and never converted, and weft_str() from Python.
# Written before the code. Made-up values only.
#
# One Python session serves the whole file (the shared one of this process). The
# module is registered by py_forms_ready() (weft_setup() with Python running,
# G18). Python-side failures are caught in Python (py_try()) and read in R.
#
# Interface fixed by these tests: none beyond the note's own names. The
# exception TYPE a refused argument raises is not pinned (the note says "a Python
# exception whose message contains ..."); only its message is.

# ---- G19: the names the module holds ----------------------------------------------------

test_that("G19: the module holds exactly the 26 formatter and phrase names, plus __weft_r__ = True", {
  py_forms_ready()
  own <- reticulate::py_eval(paste0(
    "sorted(n for n in vars(__import__('weft')) ",
    "if not (n.startswith('__') and n.endswith('__')))"))
  expect_identical(sort(own), sort(g5c_names))
  expect_identical(reticulate::py_eval("__import__('weft').__weft_r__ is True"), TRUE)
})

test_that("G19: every name in the module is callable", {
  py_forms_ready()
  ok <- reticulate::py_eval(sprintf(
    "all(callable(getattr(__import__('weft'), n)) for n in %s)",
    paste0("[", paste0("'", g5c_names, "'", collapse = ", "), "]")))
  expect_true(ok)
})

test_that("G19: claim, u, fmt_unit, lookup, brk, glue_vec and the dictionary functions are not there: each import is Python's ImportError", {
  py_forms_ready()
  for (n in c("claim", "u", "fmt_unit", "lookup", "brk", "glue_vec", "read_dict",
              "dict_glossary", "dict_vale", "dict_seed", "clamp")) {
    r <- py_try(sprintf("from weft import %s", n))
    expect_false(r$ok, label = n)
    expect_identical(r$type, "ImportError", label = n)
  }
})

# ---- G20: the same text as the R function -----------------------------------------------

# python expression, then the R call that takes the R forms (G5, G6) of the same arguments
g20 <- list(
  list("fmt_num(3.14159)", "fmt_num(3.14159)"),
  list("fmt_num(3.14159, digits=3)", "fmt_num(3.14159, digits = 3)"),
  list("fmt_num(2**40)", "fmt_num(2^40)"),
  list("fmt_num(2**31)", "fmt_num(2^31)"),
  list("fmt_num(2**53)", "fmt_num(2^53)"),
  list("fmt_num([1.5, 2.25])", "fmt_num(c(1.5, 2.25))"),
  list("fmt_num(3.14159, sigfig=2)", "fmt_num(3.14159, sigfig = 2)"),
  list("fmt_pct(0.12)", "fmt_pct(0.12)"),
  list("fmt_sci(12345.678)", "fmt_sci(12345.678)"),
  list("fmt_p(0.0456)", "fmt_p(0.0456)"),
  list("fmt_date(datetime.date(2026, 11, 13))", "fmt_date(as.Date('2026-11-13'))"),
  list("fmt_no(3)", "fmt_no(3L)"),
  list("fmt_word(3)", "fmt_word(3L)"),
  list("fmt_count(3)", "fmt_count(3L)"),
  list("fmt_ord(3)", "fmt_ord(3L)"),
  list("fmt_and(['a', 'b', 'c'])", "fmt_and(c('a', 'b', 'c'))"),
  list("fmt_and(['a', 'b', 'c'], sep='; ')", "fmt_and(c('a', 'b', 'c'), sep = '; ')"),
  list("fmt_and(x=['a', 'b', 'c'], last=' or ')", "fmt_and(x = c('a', 'b', 'c'), last = ' or ')"),
  list("fmt_or(['a', 'b', 'c'])", "fmt_or(c('a', 'b', 'c'))"),
  list("fmt_pairs({'A': 1.2, 'B': 3.4})", "fmt_pairs(c(A = 1.2, B = 3.4))"),
  list("fmt_range([1, 5])", "fmt_range(c(1L, 5L))"),
  list("fmt_ul(['a', 'b'])", "fmt_ul(c('a', 'b'))"),
  list("fmt_ol(['a', 'b'])", "fmt_ol(c('a', 'b'))"),
  list("fmt_dl({'a': 'x', 'b': 'y'})", "fmt_dl(c(a = 'x', b = 'y'))"),
  list("fmt_a(8)", "fmt_a(8L)"),
  list("fmt_cap('apple pie')", "fmt_cap('apple pie')"),
  list("fmt_strong('x')", "fmt_strong('x')"),
  list("fmt_em('x')", "fmt_em('x')"),
  list("plural(3, '# site', '# sites')", "plural(3L, '# site', '# sites')"),
  list("plural(1, '# site', '# sites')", "plural(1L, '# site', '# sites')"),
  list("plural(0, 'never', 'once', 'twice', '# times')", "plural(0L, 'never', 'once', 'twice', '# times')"),
  list("ci(1.2, 0.8, 1.6)", "ci(1.2, 0.8, 1.6)"),
  list("ci(1.2, lo=0.8, hi=1.6, digits=1)", "ci(1.2, lo = 0.8, hi = 1.6, digits = 1)"),
  list("pm(1.234, 0.056)", "pm(1.234, 0.056)"),
  list("pm(1.234, se=0.056, digits=2)", "pm(1.234, se = 0.056, digits = 2)"),
  list("about(0.52)", "about(0.52)"),
  list("about(0.52, to=0.5)", "about(0.52, to = 0.5)"),
  list("of_n(3, 7, 'site', 'sites')", "of_n(3L, 7L, 'site', 'sites')")
)

test_that("G20: each function of the module returns what the R function of that name returns on the R forms of the same arguments", {
  py_forms_ready()
  for (case in g20) {
    py <- py_val(case[[1]])
    r <- plain5(eval(parse(text = case[[2]]), envir = asNamespace("weft")))
    expect_identical(py, r, label = case[[1]])
  }
})

test_that("G20: the literal strings the note gives (what R prints today)", {
  py_forms_ready()
  expect_identical(py_val("fmt_num(3.14159)"), "3.1")
  expect_identical(py_val("fmt_num(3.14159, digits=3)"), "3.142")
  expect_identical(py_val("fmt_num(2**40)"), "1,099,511,627,776")
  expect_identical(py_val("fmt_num([1.5, 2.25])"), c("1.5", "2.3"))
  expect_identical(py_val("fmt_pct(0.12)"), "12%")
  expect_identical(py_val("fmt_p(0.0456)"), "p = 0.046")
  expect_identical(py_val("fmt_word(3)"), "three")
  expect_identical(py_val("fmt_ord(3)"), "3rd")
  expect_identical(py_val("fmt_and(['a', 'b', 'c'])"), "a, b and c")
  expect_identical(py_val("plural(3, '# site', '# sites')"), "3 sites")
  expect_identical(py_val("plural(1, '# site', '# sites')"), "1 site")
})

test_that("G20: one R string is a Python str; several are a Python list of str", {
  py_forms_ready()
  expect_identical(py_val("type(fmt_num(3.14159)).__name__"), "str")
  expect_identical(py_val("type(fmt_num([1.5, 2.25])).__name__"), "list")
  expect_identical(py_val("all(type(s).__name__ == 'str' for s in fmt_num([1.5, 2.25]))"), TRUE)
  expect_identical(py_val("len(fmt_num([1.5, 2.25, 3.75]))"), 3L)
})

# ---- G21: arguments are read, not converted ----------------------------------------------

test_that("G21: fmt_num(2**53 + 1) raises an exception whose message is M1 for 'Argument 1 of fmt_num()', and never returns \"1\"", {
  py_forms_ready()
  r <- py_try("t_g5c_out = fmt_num(2**53 + 1)")
  expect_false(r$ok)
  expect_true(grepl(m1("Argument 1 of fmt_num()", "9007199254740993"), r$msg, fixed = TRUE),
              label = r$msg)
  expect_false(isTRUE(py_val("globals().get('t_g5c_out') == '1'")))
})

test_that("G21: a keyword argument is read too: M1 for 'Argument `digits` of fmt_num()'", {
  py_forms_ready()
  r <- py_try("fmt_num(1.5, digits=2**53 + 1)")
  expect_false(r$ok)
  expect_true(grepl(m1("Argument `digits` of fmt_num()", "9007199254740993"), r$msg, fixed = TRUE),
              label = r$msg)
})

test_that("G21: the integers 2**53 and -2**53 are read, exactly; one past each is refused", {
  py_forms_ready()
  expect_identical(py_val("fmt_num(2**53)"), plain5(weft::fmt_num(2^53)))
  expect_true(py_try("fmt_num(2**53)")$ok)
  expect_false(py_try("fmt_num(-2**53 - 1)")$ok)
})

test_that("G21: fmt_and([1, 'a']) raises M3 (kinds integer, string)", {
  py_forms_ready()
  r <- py_try("fmt_and([1, 'a'])")
  expect_false(r$ok)
  expect_true(grepl(m3("Argument 1 of fmt_and()", "list", "integer, string"), r$msg, fixed = TRUE),
              label = r$msg)
})

test_that("G21: a nested list, a set and a type weft does not read are refused with their messages, naming the argument", {
  py_forms_ready()
  r4 <- py_try("fmt_and([[1]])")
  expect_true(grepl(m4("Argument 1 of fmt_and()", "list", "list"), r4$msg, fixed = TRUE), label = r4$msg)
  r7 <- py_try("fmt_and({'a', 'b'})")
  expect_true(grepl(m7("Argument 1 of fmt_and()", "set"), r7$msg, fixed = TRUE), label = r7$msg)
  r6 <- py_try("fmt_num(1+2j)")
  expect_true(grepl(m6("Argument 1 of fmt_num()", "complex"), r6$msg, fixed = TRUE), label = r6$msg)
})

test_that("G21: an R error the function raises of its own reaches Python as an exception whose message contains the R message", {
  py_forms_ready()
  rmsg <- msg5(tryCatch(weft::plural(c(1L, 2L), "# a", "# b"), error = function(e) e))
  expect_match(rmsg, "length(x)", fixed = TRUE)   # the R message the test relies on
  r <- py_try("plural([1, 2], '# a', '# b')")
  expect_false(r$ok)
  expect_true(grepl(rmsg, r$msg, fixed = TRUE), label = r$msg)
})

test_that("G21: in a Python chunk with no error: true the exception stops the knit", {
  res <- k5(
    c("```{python gf1, error=FALSE}",
      "from weft import fmt_num",
      "t_g5c_unused = fmt_num(2**53 + 1)",
      "```", "", "After."))
  expect_true(res$failed)
  expect_true(grepl("beyond", res$message, fixed = TRUE), label = res$message)
  expect_false(grepl("^After\\.", paste(res$text, collapse = "\n")))
})

test_that("G20 in a knit: a Python chunk with results asis prints the same text as the R function, by the first Python chunk's registration", {
  res <- k5(
    c("```{python gf2, echo=FALSE, results='asis'}",
      "from weft import fmt_num, plural, fmt_and, fmt_pct",
      "print(fmt_num(3.14159, digits=3) + ' | ' + plural(3, '# site', '# sites') +",
      "      ' | ' + fmt_and(['a', 'b', 'c']) + ' | ' + fmt_pct(0.12))",
      "```"))
  expect_false(res$failed, label = res$message)
  expect_true(any(res$text == "3.142 | 3 sites | a, b and c | 12%"), label = res$md)
})

# ---- G22: weft_str from Python -----------------------------------------------------------

test_that("G22: in a Python chunk with results asis, weft_str() resolves markup whose expression reads a Python name", {
  res <- k5(
    c("```{python p2, echo=FALSE, results='asis'}",
      "from weft import weft_str",
      "print(weft_str('Depth [rose | fell]{if=\"py$t_g5c_slope > 0\"}.'))",
      "```"),
    py = "t_g5c_slope = 0.4")
  expect_false(res$failed, label = res$message)
  expect_true("Depth rose." %in% res$text, label = res$md)
  expect_false(grepl("<<weft", res$md, fixed = TRUE))
})

test_that("G22: the other arm is chosen when the Python value says so", {
  res <- k5(
    c("```{python p2b, echo=FALSE, results='asis'}",
      "from weft import weft_str",
      "print(weft_str('Depth [rose | fell]{if=\"py$t_g5c_slope2 > 0\"}.'))",
      "```"),
    py = "t_g5c_slope2 = -0.4")
  expect_false(res$failed, label = res$message)
  expect_true("Depth fell." %in% res$text, label = res$md)
})

test_that("G22: a failed check inside it is collected, marked with the Python chunk's label, and fails the render once at the end", {
  res <- k5(
    c("```{python p2, echo=FALSE, results='asis'}",
      "from weft import weft_str",
      "print(weft_str('Check `r claim(py$t_g5c_n, . > 100)`.'))",
      "```", "", "After."),
    py = "t_g5c_n = 3")
  expect_true(res$failed)
  expect_true(grepl("<<weft: failed claim, chunk p2>>", res$md, fixed = TRUE), label = res$md)
  expect_true("After." %in% res$text)           # the knit went on to the end
  f <- res$failures
  expect_identical(sum(f$chunk == "p2", na.rm = TRUE), 1L)
  expect_identical(nrow(f), 1L)
})

test_that("G22: outside a knit a failed check raises at once", {
  py_forms_ready()
  r <- py_try("weft_str('Check `r claim(1, . > 100)`.')")
  expect_false(r$ok)
  expect_gt(nchar(r$msg), 0L)
})

test_that("G22: outside a knit a markup string with a passing guest read gives its text", {
  py_forms_ready()
  py_set(t_g5c_slope3 = "0.4")
  expect_identical(py_val("weft_str('Depth [rose | fell]{if=\"py$t_g5c_slope3 > 0\"}.')"),
                   "Depth rose.")
})
