# Package 6e: claim() of the Python package in a Jupyter kernel (N53) and with no back end (N54), rules N50,
# N51, N58 and N73; messages E55 and E56 of dev/design-6.md section 7. Written before the code. Made-up
# values only. Helper: helper-jupyter.R. Skipped when quarto or a Python with jupyter_client and ipykernel
# is absent. One kernel session serves the kernel tests of this file.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - {check} for an operator check ("> 10"): the note does not say whether it is shown as written or as
#    "_ > 10"; the tests take either, in the check's `text` and in E55 (as test-guest-claim-py.R does);
#  - whether a claim whose checks all pass displays anything, and what the block holds when several
#    checks of one call fail, are not pinned;
#  - the `ok` of a check that raised while it ran is not pinned (N23 allows false and null), only that it
#    is not true;
#  - the text of E55 with a `why` (a check that raised) is not pinned.

EXPR_GT10 <- "claim(\u2026, '> 10')"
CHECK_GT10 <- "(_ )?> 10"

claim_session <- function() {
  if (!is.null(.jup$claim_session)) return(.jup$claim_session)
  .jup$claim_session <- jup_session(list(
    # 1
    "from weft import claim, ClaimFailed\nn = 7",
    # 2: a failed claim: the block, then the exception
    "claim(n, '> 10')",
    # 3: the kernel goes on
    "print(n)",
    # 4: a warned check: the block, no exception, the value returned
    "claim(n, '> 10', level='warn')",
    # 5: a check that raises while it runs
    "claim(n, 'undefined_name > 1')",
    # 6, 7: the record of the value checked
    "claim(2.5, '> 10')",
    "claim('abc', \"== 'xyz'\")",
    # 8: caught in the cell: the block was displayed before the raise
    "try:\n    claim(n, '> 10')\nexcept ClaimFailed as e:\n    print('caught', isinstance(e, AssertionError))",
    # 9: an expression check
    "claim(n, '_ % 2 == 0')"
  ))
  .jup$claim_session
}

test_that("N53: a failed claim displays one block, with no values and one check, then raises ClaimFailed (E55)", {
  r <- claim_session()
  expect_identical(r[[1]]$status, "ok")
  x <- r[[2]]
  expect_identical(x$status, "error")
  expect_identical(x$ename, "ClaimFailed")
  expect_match(x$evalue, sprintf("^weft: a claim failed: %s was false \\(value 7\\)\\.$", CHECK_GT10))
  # the block comes first, then the error
  expect_identical(x$kinds, c("block", "error"))
  expect_length(x$blocks, 1L)
  expect_match(x$block_text, '^\\{"weft":1,"lang":"python","run":null,"at":[0-9]+,', perl = TRUE)
  expect_match(x$block_text, '"values":{}', fixed = TRUE)
  b <- x$blocks[[1]]
  expect_identical(as.integer(b$weft), 1L)
  expect_identical(b$lang, "python")
  expect_length(b$values, 0L)
  expect_length(b$checks, 1L)
  ch <- b$checks[[1]]
  expect_match(ch$text, sprintf("^%s$", CHECK_GT10))
  expect_false(isTRUE(ch$ok))
  expect_identical(ch$ok, FALSE)
  expect_true(is.null(ch$level) || identical(ch$level, "fail"))
  expect_null(ch$why)
  expect_identical(ch$expr, EXPR_GT10)
  expect_identical(list(ch$value$t, ch$value$v), list("int", "7"))
  # the kernel goes on after the error
  expect_identical(r[[3]]$stdout, "7\n")
})

test_that("N53: a warned check displays the same block with level warn, raises nothing and returns the value", {
  x <- claim_session()[[4]]
  expect_identical(x$status, "ok")
  expect_identical(x$result, "7")
  expect_identical(x$kinds, c("block", "execute_result"))
  ch <- x$blocks[[1]]$checks[[1]]
  expect_identical(ch$level, "warn")
  expect_identical(ch$ok, FALSE)
  expect_identical(ch$expr, EXPR_GT10)
  expect_identical(list(ch$value$t, ch$value$v), list("int", "7"))
  expect_length(x$blocks[[1]]$values, 0L)
})

test_that("N50, N53: a check that raises is a failed check whose why is `Type: message`", {
  x <- claim_session()[[5]]
  expect_identical(x$status, "error")
  expect_identical(x$ename, "ClaimFailed")
  expect_length(x$blocks, 1L)
  ch <- x$blocks[[1]]$checks[[1]]
  expect_false(isTRUE(ch$ok))
  expect_match(ch$why, "^NameError: ")
  expect_identical(ch$expr, "claim(\u2026, 'undefined_name > 1')")
})

test_that("N53, N58: the value is the record of x, and each check is shown as repr() shows it", {
  r <- claim_session()
  ch <- r[[6]]$blocks[[1]]$checks[[1]]
  expect_identical(list(ch$value$t, ch$value$v), list("float", "2.5"))
  expect_identical(ch$expr, EXPR_GT10)
  expect_match(r[[6]]$evalue, sprintf("^weft: a claim failed: %s was false \\(value 2\\.5\\)\\.$", CHECK_GT10))
  ch <- r[[7]]$blocks[[1]]$checks[[1]]
  expect_identical(list(ch$value$t, ch$value$v), list("string", "abc"))
  expect_identical(ch$expr, "claim(\u2026, \"== 'xyz'\")")
  ch <- r[[9]]$blocks[[1]]$checks[[1]]
  expect_identical(ch$text, "_ % 2 == 0")
  expect_identical(ch$expr, "claim(\u2026, '_ % 2 == 0')")
})

test_that("N53: the block is displayed before the raise, so a caught ClaimFailed still leaves it", {
  x <- claim_session()[[8]]
  expect_identical(x$status, "ok")
  expect_identical(x$stdout, "caught True\n")
  expect_length(x$blocks, 1L)
  expect_identical(x$blocks[[1]]$checks[[1]]$expr, EXPR_GT10)
})

# ---- no back end (N54) and an IPython with no kernel (N73): controls too ----------------------------------

test_that("N54, N73: with no back end a failed claim raises at once and displays and prints nothing", {
  code <- paste("from weft import claim, ClaimFailed",
                "try:",
                "    claim(7, '> 10')",
                "except ClaimFailed as e:",
                "    print('E:' + str(e))",
                sep = "\n")
  x <- py_plain(code)
  expect_identical(x$status, 0L, label = x$stderr)
  expect_match(x$stdout, sprintf("^E:weft: a claim failed: %s was false \\(value 7\\)\\.$", CHECK_GT10))
  expect_false(grepl("weft-values", x$stdout, fixed = TRUE))
  y <- py_plain(paste("from IPython.core.interactiveshell import InteractiveShell",
                      "ip = InteractiveShell.instance()",
                      "ip.run_cell('from weft import claim, ClaimFailed\\ntry:\\n    claim(7, \"> 10\")\\nexcept ClaimFailed as e:\\n    print(\"E:\" + str(e))')",
                      sep = "\n"))
  expect_identical(y$status, 0L, label = y$stderr)
  expect_match(y$stdout, sprintf("^E:weft: a claim failed: %s was false \\(value 7\\)\\.$", CHECK_GT10))
})

test_that("N54: with no back end a warned check calls warnings.warn(E55, UserWarning) and returns the value", {
  code <- paste("import warnings",
                "from weft import claim",
                "with warnings.catch_warnings(record=True) as w:",
                "    warnings.simplefilter('always')",
                "    r = claim(7, '> 10', level='warn')",
                "print(r, len(w), w[0].category.__name__, str(w[0].message))",
                sep = "\n")
  x <- py_plain(code)
  expect_identical(x$status, 0L, label = x$stderr)
  expect_match(x$stdout, sprintf("^7 1 UserWarning weft: a claim failed: %s was false \\(value 7\\)\\.$", CHECK_GT10))
})

test_that("control (N50, N51): a claim that passes returns the value and shows nothing", {
  x <- py_plain("from weft import claim\nprint(claim(7, '> 1', '_ % 2 == 1'))")
  expect_identical(x$stdout, "7")
})
