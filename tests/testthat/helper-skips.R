# Skips and preconditions. A test skips only when the thing it needs is absent from the machine
# (a program such as git, Quarto or Pandoc, an optional package, Python, Julia, a file system that
# refuses a name). When the package itself fails to deliver what a test builds on (a function it
# should define, a fixture that should render, a cache file it should write), that is a failure of
# the package, so the precondition is an expectation and not a skip.

# Records an expectation that `ok` is TRUE and returns whether it was, so that a test can stop
# after a failed precondition without piling error messages on top of it:
#   if (!expect_precondition(!is.null(key), "ud_tables_key() gives a key")) return(invisible())
expect_precondition <- function(ok, label) {
  ok <- isTRUE(ok)
  testthat::expect_true(ok, label = label)
  ok
}

# The precondition "weft defines `name`" (an internal or an exported function).
expect_built <- function(name) {
  expect_precondition(exists(name, envir = asNamespace("weft"), inherits = FALSE),
                      sprintf("weft defines %s()", name))
}

# The precondition "a render or knit of a fixture succeeded", for a result `res` with `failed` and
# `message` as the render helpers give them.
expect_rendered <- function(res) {
  expect_precondition(!isTRUE(res$failed),
                      paste("the fixture rendered:", paste(res$message, collapse = " ")))
}

# The one reason a ledger or fixture writer may skip: the file system refuses the name (a message
# from the operating system). Anything else is rethrown, so it fails the test.
fs_refusal_re <- paste0("cannot open|cannot create|cannot change|Invalid argument|Illegal byte|",
                        "File name too long|Illegal|invalid .*(file|path|name)|Permission denied")
skip_if_fs_refuses <- function(expr) {
  refuse <- function(cnd) {
    if (grepl(fs_refusal_re, conditionMessage(cnd), ignore.case = TRUE))
      testthat::skip(paste("this file system refuses the name:", conditionMessage(cnd)))
  }
  withCallingHandlers(expr, error = refuse, warning = refuse)
}
