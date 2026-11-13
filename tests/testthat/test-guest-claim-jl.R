# Package 6k: @claim from Julia, knitr back end (rules N55, N56, N58, N60 of dev/design-6.md;
# messages E50, E53, E55 to E57 of section 7). Risk R6: `using Weft` must load under JuliaCall from
# the package folder that R puts on LOAD_PATH; if it does not, these tests fail first, which is the
# stop the note asks for.
# Written before the code. Made-up values only. Helpers: helper-6k.R, helper-5j.R, helper-5.R.
#
# One Julia session serves the file. Every global a test sets in Julia starts t_6k_. Forms that do not
# stop a knit are read through level=:warn (drained into last_knit()$warnings); a failing claim stops
# the knit (a Julia error stops it even under error = TRUE, J18), so each of those is a knit of its
# own.
#
# READINGS of the note (see the report):
#  - the check's text for `@claim x > 10` is "x > 10"; for `@claim m (_ > 0.5)` it is "_ > 0.5"
#    (string() of the expression as Julia prints it, parentheses gone).
#  - the `expr` of a claim with several checks or a level is not pinned beyond starting with
#    "@claim " and the macro's first argument; `@claim n > 10` alone is pinned exactly.
#  - the text of E53 for Julia is "{check} gave a {type}, not true or false"; the tests do not pin
#    whether "was false (value ..)" comes first.
#  - a knit stopped by @claim carries E55 in its error message and the row in last_knit()$failures.

JL_PRE <- c("using Weft", "using Statistics", "t_6k_n = 3;", "t_6k_d = [1.0, 2.0];", "t_6k_v = [1, 2, 3];")

jl_doc_w <- function() {
  memo5d("6k-jl-w", function() {
    lines <- c(
      jc6k("jw1", "@claim t_6k_n > 10 level=:warn;", opts = NULL),
      jc6k("jw2", "@claim mean(t_6k_d) (_ > 0.5) (_ < 1) level=:warn;", opts = NULL),
      jc6k("jw3", "@claim t_6k_n (_ + 1) level=:warn;", opts = NULL),
      jc6k("jw4", "@claim t_6k_n (_ > missing) level=:warn;", opts = NULL),
      jc6k("jw5", "@claim t_6k_v (_ .> 1) level=:warn;", opts = NULL),
      jc6k("jw6", "@claim t_6k_n (sqrt(_ - 10) > 0) level=:warn;", opts = NULL),
      jc6k("jw7", "@claim t_6k_n > 10 level=:warn;", "@claim t_6k_n < 1 level=:warn;", opts = NULL),
      jc6k("jw8",
           "t_6k_r1 = @claim t_6k_n > 1;",
           "t_6k_r2 = @claim mean(t_6k_d) (_ > 0.5) (_ < 9);",
           "t_6k_r3 = @claim t_6k_n >= 3;",
           "t_6k_r4 = @claim t_6k_n <= 3;",
           "t_6k_r5 = @claim t_6k_n == 3;",
           "t_6k_r6 = @claim t_6k_n != 4;",
           "t_6k_r7 = @claim t_6k_n < 4;",
           "t_6k_r8 = @claim t_6k_d (length(_) == 2) (_[1] < _[2]) level=:warn;",
           opts = NULL),
      jc6k("jw9", "t_6k_z = 1;", opts = NULL))
    k5j(lines, jl = JL_PRE)
  })
}

# a knit whose last chunk fails: `code` is the claim; chunk `jf` is the failing one, `jnever` follows it
jl_stop <- function(code, opts) {
  k5j(c(jc6k("jf", code, opts = opts), jc6k("jnever", "t_6k_never = 1;", opts = NULL)), jl = JL_PRE)
}

# ---- N60, R6: using Weft loads under knitr with no author set-up -----------------------------------

test_that("N60 R6: `using Weft` in a Julia chunk of a weft knit loads the package that ships with weft, with no author set-up", {
  res <- jl_doc_w()
  expect_false(res$failed, label = res$message)
  expect_identical(JuliaCall::julia_eval("isdefined(Main, :Weft)"), TRUE)
  mine <- normalizePath(system.file("julia", package = "weft"), mustWork = FALSE)
  where <- normalizePath(JuliaCall::julia_eval("dirname(dirname(pathof(Weft)))"), mustWork = FALSE)
  expect_true(startsWith(where, mine), label = paste(where, "is under", mine))
})

test_that("N60: weft puts its julia folder on LOAD_PATH once, at the end, however many knits ran", {
  jl_doc_w()
  jl_doc_w()                                   # a second knit in this process
  mine <- normalizePath(system.file("julia", package = "weft"), mustWork = FALSE)
  lp <- JuliaCall::julia_eval("String[string(p) for p in LOAD_PATH]")
  lp <- vapply(lp, normalizePath, "", mustWork = FALSE, USE.NAMES = FALSE)
  expect_identical(sum(lp == mine), 1L)
  expect_identical(lp[[length(lp)]], mine)
})

test_that("N3: Weft.ClaimFailed and Weft.PublishError are Julia exceptions", {
  jl_doc_w()
  expect_identical(JuliaCall::julia_eval("Weft.ClaimFailed <: Exception"), TRUE)
  expect_identical(JuliaCall::julia_eval("Weft.PublishError <: Exception"), TRUE)
})

# ---- N55: what a passing @claim returns ------------------------------------------------------------

test_that("N55: a passing @claim returns the value of its first operand, whatever the form", {
  res <- jl_doc_w()
  expect_false(res$failed, label = res$message)
  expect_identical(JuliaCall::julia_eval("t_6k_r1"), 3L)
  expect_identical(JuliaCall::julia_eval("t_6k_r2"), 1.5)
  for (nm in paste0("t_6k_r", 3:7)) expect_identical(JuliaCall::julia_eval(nm), 3L, label = nm)
  expect_identical(JuliaCall::julia_eval("t_6k_r8 === t_6k_d"), TRUE)
})

test_that("N55: passing claims record nothing: no failure row and no warned row in chunk jw8", {
  res <- jl_doc_w()
  expect_equal(nrow(rows6k(res$failures, "jw8")), 0L)
  expect_equal(nrow(rows6k(res$knit$warnings, "jw8")), 0L)
  expect_equal(nrow(res$failures), 0L)
})

# ---- N55, N58, N56: the forms, read as warned checks drained after the chunk -------------------------

test_that("N55 N58 N56: `@claim x > 10 level=:warn` is drained after its chunk as one warned row: expr `@claim t_6k_n > 10`..., detail `n > 10 was false (value 3)`", {
  res <- jl_doc_w()
  w <- rows6k(res$knit$warnings, "jw1")
  expect_equal(nrow(w), 1L)
  expect_identical(det6k(w), "t_6k_n > 10 was false (value 3)")
  expect_true(startsWith(as.character(w$expr), "@claim t_6k_n > 10"))
})

test_that("N55 N58: a macro with no level and one comparison, drained as a failure, has the exact expr `@claim t_6k_n > 10` (see the stop tests)", {
  res <- jl_stop("@claim t_6k_n > 10", NULL)
  r <- rows6k(res$failures, "jf")
  expect_equal(nrow(r), 1L)
  expect_identical(as.character(r$expr), "@claim t_6k_n > 10")
  expect_identical(det6k(r), "t_6k_n > 10 was false (value 3)")
})

test_that("N55: `@claim expr check...` binds _ to the value of expr: the check text is the expression as Julia prints it, the value is expr's", {
  res <- jl_doc_w()
  w <- rows6k(res$knit$warnings, "jw2")
  expect_equal(nrow(w), 1L)                           # `_ > 0.5` passed, `_ < 1` failed
  expect_identical(det6k(w), "_ < 1 was false (value 1.5)")
  expect_true(startsWith(as.character(w$expr), "@claim mean(t_6k_d)"))
})

test_that("N55 E53: a check that gives an Int, missing or a BitVector is a failed check (no truthiness)", {
  res <- jl_doc_w()
  cases <- list(jw3 = c("_ + 1", "Int64"), jw4 = c("_ > missing", "Missing"), jw5 = c("_ .> 1", "BitVector"))
  for (lb in names(cases)) {
    w <- rows6k(res$knit$warnings, lb)
    expect_equal(nrow(w), 1L, label = lb)
    d <- det6k(w)
    expect_true(startsWith(d, cases[[lb]][[1]]), label = paste(lb, "starts with its check"))
    expect_match(d, sprintf("gave a %s, not true or false", cases[[lb]][[2]]), fixed = TRUE, label = lb)
  }
})

test_that("N55: an exception raised while evaluating a check is a failed check whose why is Type: message", {
  res <- jl_doc_w()
  w <- rows6k(res$knit$warnings, "jw6")
  expect_equal(nrow(w), 1L)
  d <- det6k(w)
  expect_true(startsWith(d, "sqrt(_ - 10) > 0 "))
  expect_match(d, "; DomainError: ", fixed = TRUE)
})

test_that("N56: outcomes are drained at the end of the chunk that made them: two claims, two rows, both at that chunk; none carried to the next", {
  res <- jl_doc_w()
  w <- rows6k(res$knit$warnings, "jw7")
  expect_equal(nrow(w), 2L)
  expect_setequal(det6k(w), c("t_6k_n > 10 was false (value 3)", "t_6k_n < 1 was false (value 3)"))
  expect_equal(nrow(rows6k(res$knit$warnings, "jw9")), 0L)
  claims <- res$knit$warnings[startsWith(as.character(res$knit$warnings$expr), "@claim"), , drop = FALSE]
  expect_equal(nrow(claims), 8L)                       # jw1 to jw6 one each, jw7 two
  expect_setequal(unique(claims$chunk), paste0("jw", 1:7))
})

test_that("N56: warned claims do not fail the knit and are not failures", {
  res <- jl_doc_w()
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(res$failures), 0L)
})

# ---- N55, N56: a failing claim stops the knit ----------------------------------------------------------

test_that("N56: a failing @claim is drained as a failed claim at its chunk, then throws: the knit stops with E55 and the chunk after never runs", {
  res <- jl_stop("@claim t_6k_n > 10", NULL)
  expect_true(res$failed)
  expect_match(res$message, "a claim failed: t_6k_n > 10 was false \\(value 3\\)")
  r <- rows6k(res$failures, "jf")
  expect_equal(nrow(r), 1L)
  expect_identical(as.character(r$kind), "failed claim")
  expect_identical(JuliaCall::julia_eval("isdefined(Main, :t_6k_never)"), FALSE)
})

test_that("N56: a Julia error stops the knit even under error = TRUE (J18); the drained failure and the error are both reported", {
  res <- jl_stop("@claim t_6k_n > 10", "error=TRUE")
  expect_true(res$failed)
  expect_match(res$message, "a claim failed: t_6k_n > 10 was false \\(value 3\\)")
  expect_equal(nrow(rows6k(res$failures, "jf")), 1L)
  expect_identical(JuliaCall::julia_eval("isdefined(Main, :t_6k_never)"), FALSE)
})

test_that("N56: the failed claim of a chunk after a passing chunk is located by its own label", {
  res <- k5j(c(jc6k("jok", "@claim t_6k_n > 1;", opts = NULL),
               jc6k("jbad", "@claim t_6k_n > 10;", opts = NULL)), jl = JL_PRE)
  expect_true(res$failed)
  expect_identical(unique(as.character(res$failures$chunk)), "jbad")
})

# ---- N55 E50: nothing to check ------------------------------------------------------------------------

test_that("N55 E50: `@claim x` with nothing to check is a macro expansion error with the text of E50", {
  res <- jl_stop("@claim t_6k_n", NULL)
  expect_true(res$failed)
  expect_match(res$message, "@claim needs at least one check.", fixed = TRUE)
  expect_identical(JuliaCall::julia_eval("isdefined(Main, :t_6k_never)"), FALSE)
})
