# Stage 8, G1 (dev/design-8.md GN2a, GN3, GN7, GN8, GN10 to GN12): `chunk_claims: collect` for a Python
# claim() and a Julia @claim under the knitr back end. R decides and collects: a failing guest claim is
# recorded under its chunk's label, returns its value and raises nothing; the render fails at the end
# with every failure listed, or (in draft mode) only reports. A later error becomes E31 when a guest claim
# was collected before it.
# Helpers: k5 (helper-5.R), pc6k and jc6k (helper-6k.R), k5j (helper-5j.R). Python cases need reticulate and
# Python (k5 skips); Julia cases need JuliaCall and Julia (k5j skips, and WEFT_SKIP_JULIA skips them).
# Names a document sets in Python or Julia start t_8p_ or t_8j_ (the sessions are shared by the file).
# Made-up values only. ASCII only.
#
# READINGS of the design (see the report):
#  - a document that ends with collected failures fails with class weft_failures (as the R cases of
#    test-chunk-claims.R), its message listing each failure with the chunk's label;
#  - the value a collected claim returns is seen through what the chunk prints afterwards;
#  - the E31 text is the one of design-7 (E31), with "claim" or "claims" by the count.

# The E31 sentence for a count of n, with white space collapsed as msg5() collapses the message.
gn_e31 <- function(n) {
  x <- paste0("weft: the knit stopped on an error after ", n, " failed claim", if (n == 1L) "" else "s",
              " in chunk code. ",
              "The claims are listed first: the error may follow from a value that failed its claim.")
  trimws(gsub("[[:space:]]+", " ", x))
}

GN_COLLECT <- c("draft: false", "chunk_claims: collect")
GN_STOP <- c("draft: false", "chunk_claims: stop")
GN_PYPRE <- "from weft import claim"
GN_JLPRE <- c("using Weft", "t_8j_n = 3;")

gn_py <- function(lines, yml = GN_COLLECT, ...) k5(lines, py = GN_PYPRE, weft_yml = yml, ...)
gn_jl <- function(lines, yml = GN_COLLECT, ...) k5j(lines, jl = GN_JLPRE, weft_yml = yml, ...)

# res$message has its white space collapsed (msg5()), so it has no first line: it STARTS with the sentence.
expect_e31 <- function(res, n) {
  expect_true(startsWith(res$message, gn_e31(n)), label = substr(res$message, 1L, 200L))
}

# a marker file in dir that a chunk writes: its content is read back after the knit
gn_read <- function(dir, name) {
  f <- file.path(dir, name)
  if (file.exists(f)) paste(readLines(f, warn = FALSE), collapse = "\n") else NA_character_
}

# ---- Python ----------------------------------------------------------------------------------------------

test_that("GN3, GN2a: two failing Python claims in two chunks are collected; the knit reaches the end and the value is returned", {
  td <- normalizePath(withr::local_tempdir(), winslash = "/")
  wr <- function(name, v) sprintf("open('%s/%s', 'w').write(str(%s))", td, name, v)
  res <- gn_py(c(pc6k("pa", "t_8p_a = claim(3, '> 10') + 1", wr("a.txt", "t_8p_a"), opts = "error=FALSE"),
                 pc6k("pb", "t_8p_b = claim(2, '> 10') + 1", wr("b.txt", "t_8p_b"), opts = "error=FALSE"),
                 pc6k("pc", wr("end.txt", "'reached'"), opts = "error=FALSE")))
  expect_true(res$failed)
  expect_s3_class(res$error, "weft_failures")
  # a knit that ends with collected failures aborts before knitr writes its output, so the chunks' work
  # is read from marker files
  expect_identical(gn_read(td, "a.txt"), "4")
  expect_identical(gn_read(td, "b.txt"), "3")
  expect_identical(gn_read(td, "end.txt"), "reached")
  f <- res$failures
  expect_identical(nrow(f), 2L)
  expect_identical(as.character(f$kind), c("failed claim", "failed claim"))
  expect_identical(as.character(f$chunk), c("pa", "pb"))
  expect_match(det6k(f)[1], "> 10 was false (value 3)", fixed = TRUE)
  expect_match(det6k(f)[2], "> 10 was false (value 2)", fixed = TRUE)
  expect_match(res$message, "weft: 2 claims failed", fixed = TRUE)
  a <- regexpr("pa", res$message, fixed = TRUE)[1]
  b <- regexpr("pb", res$message, fixed = TRUE)[1]
  expect_true(a > 0 && b > a)
})

test_that("GN3: a Python claim that passes, under collect, records nothing and the knit succeeds", {
  res <- gn_py(pc6k("pok", "print('seen', claim(3, '> 1'))", opts = "error=FALSE"))
  expect_false(res$failed, label = res$message)
  expect_identical(nrow(res$failures), 0L)
  expect_match(res$md, "seen 3", fixed = TRUE)
})

test_that("control GN3: under stop a failing Python claim stops the knit with E55 and the next chunk does not run", {
  res <- gn_py(c(pc6k("pstop", "claim(3, '> 10')", opts = "error=FALSE"),
                 pc6k("pnever", "t_8p_never = 1", opts = "error=FALSE")), yml = GN_STOP)
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_failures"))
  expect_match(res$message, "a claim failed: (_ )?> 10 was false \\(value 3\\)")
  expect_match(res$message, "ClaimFailed", fixed = TRUE)
  expect_identical(reticulate::py_eval("'t_8p_never' in globals()"), FALSE)
})

test_that("control GN10: level warn is never collected and never stops", {
  res <- gn_py(c(pc6k("pw", "print('v', claim(3, '> 10', level='warn'))", opts = "error=FALSE"),
                 pc6k("pt", "print('tail')", opts = "error=FALSE")))
  expect_false(res$failed, label = res$message)
  expect_identical(nrow(res$failures), 0L)
  expect_identical(nrow(rows6k(res$knit$warnings, "pw")), 1L)
  expect_match(res$md, "v 3", fixed = TRUE)
})

test_that("GN11: a failing Python claim in a chunk with error: true raises nothing: no traceback, the rest of the chunk runs, the render fails at the end", {
  td <- normalizePath(withr::local_tempdir(), winslash = "/")
  wr <- function(name, v) sprintf("open('%s/%s', 'w').write(str(%s))", td, name, v)
  res <- gn_py(c(pc6k("pe", "v = claim(3, '> 10')", wr("after.txt", "v"), opts = "error=TRUE"),
                 pc6k("pt", wr("tail.txt", "'tail'"), opts = "error=FALSE")))
  expect_true(res$failed)
  expect_s3_class(res$error, "weft_failures")
  expect_false(grepl("ClaimFailed", res$message, fixed = TRUE))
  expect_identical(gn_read(td, "after.txt"), "3")
  expect_identical(gn_read(td, "tail.txt"), "tail")
  expect_identical(as.character(res$failures$chunk), "pe")
})

test_that("GN10: eval = FALSE runs nothing and records nothing", {
  res <- gn_py(c(pc6k("pn", "claim(3, '> 10')", opts = "eval=FALSE"),
                 pc6k("pt", "print('tail')", opts = "error=FALSE")))
  expect_false(res$failed, label = res$message)
  expect_identical(nrow(res$failures), 0L)
  expect_match(res$md, "tail", fixed = TRUE)
})

test_that("GN12: in draft mode the collected Python failures are reported and the knit does not fail", {
  res <- gn_py(c(pc6k("pa", "claim(3, '> 10')", "print('after a')", opts = "error=FALSE"),
                 pc6k("pb", "claim(2, '> 10')", opts = "error=FALSE")),
               yml = "chunk_claims: collect", draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(as.character(res$failures$chunk), c("pa", "pb"))
  expect_match(res$md, "after a", fixed = TRUE)
})

test_that("GN8a, GN7, E31: a collected Python claim, then a ValueError in a later Python chunk, is weft_claims_collected with the error as parent and a count of 1", {
  res <- gn_py(c(pc6k("pa", "claim(3, '> 10')", opts = "error=FALSE"),
                 pc6k("pboom", "raise ValueError('boom')", opts = "error=FALSE"),
                 "End."))
  expect_true(res$failed)
  e <- res$error
  expect_s3_class(e, "weft_claims_collected")
  expect_s3_class(e, "weft_error")
  expect_s3_class(e$parent, "error")
  expect_match(conditionMessage(e$parent), "boom", fixed = TRUE)
  expect_e31(res, 1L)
  expect_match(res$message, "The error that stopped the knit:", fixed = TRUE)
  expect_match(res$message, "pa", fixed = TRUE)
  expect_match(res$message, "boom", fixed = TRUE)
})

test_that("GN7, E31: two collected Python claims are counted in the plural", {
  res <- gn_py(c(pc6k("pa", "claim(3, '> 10')", opts = "error=FALSE"),
                 pc6k("pb", "claim(2, '> 10')", opts = "error=FALSE"),
                 pc6k("pboom", "raise ValueError('boom')", opts = "error=FALSE")))
  expect_s3_class(res$error, "weft_claims_collected")
  expect_e31(res, 2L)
})

test_that("GN8c, GN7: a collected Python claim, then an R stop(), is E31 with a count that includes the guest claim", {
  res <- gn_py(c(pc6k("pa", "claim(3, '> 10')", opts = "error=FALSE"),
                 cc7_chunk("rboom", "stop('boom')", opts = "error = FALSE"),
                 "End."))
  expect_true(res$failed)
  expect_s3_class(res$error, "weft_claims_collected")
  expect_e31(res, 1L)
  expect_match(conditionMessage(res$error$parent), "boom", fixed = TRUE)
})

test_that("control GN8a: the same ValueError with no collected claim keeps its class and message", {
  res <- gn_py(c(pc6k("pok", "claim(3, '> 1')", opts = "error=FALSE"),
                 pc6k("pboom", "raise ValueError('boom')", opts = "error=FALSE")))
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_claims_collected"))
  expect_false(inherits(res$error, "weft_failures"))
  expect_match(res$message, "boom", fixed = TRUE)
  expect_false(grepl("The error that stopped the knit", res$message, fixed = TRUE))
})

test_that("control GN8a: under stop a ValueError after a claim that passed is not wrapped either", {
  res <- gn_py(c(pc6k("pboom", "raise ValueError('boom')", opts = "error=FALSE")), yml = GN_STOP)
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_claims_collected"))
})

# ---- Julia -----------------------------------------------------------------------------------------------

test_that("GN3, GN2a: two failing Julia claims in two chunks are collected; the knit reaches the end, the rows are drained under their labels and the value is returned", {
  res <- gn_jl(c(jc6k("ja", "t_8j_a = (@claim t_8j_n > 10) + 1", opts = "error=FALSE"),
                 jc6k("jb", "t_8j_b = (@claim t_8j_n > 20) + 1", opts = "error=FALSE"),
                 jc6k("jc", "t_8j_end = 1", opts = "error=FALSE")))
  expect_true(res$failed)
  expect_s3_class(res$error, "weft_failures")
  expect_identical(JuliaCall::julia_eval("t_8j_a"), 4L)
  expect_identical(JuliaCall::julia_eval("t_8j_b"), 4L)
  expect_identical(JuliaCall::julia_eval("t_8j_end"), 1L)
  f <- res$failures
  expect_identical(nrow(f), 2L)
  expect_identical(as.character(f$kind), c("failed claim", "failed claim"))
  expect_identical(as.character(f$chunk), c("ja", "jb"))
  expect_identical(det6k(f), c("t_8j_n > 10 was false (value 3)", "t_8j_n > 20 was false (value 3)"))
  expect_match(res$message, "weft: 2 claims failed", fixed = TRUE)
  a <- regexpr("ja", res$message, fixed = TRUE)[1]
  b <- regexpr("jb", res$message, fixed = TRUE)[1]
  expect_true(a > 0 && b > a)
})

test_that("control GN3: under stop a failing Julia claim stops the knit with E55 and the next chunk does not run", {
  res <- gn_jl(c(jc6k("jstop", "@claim t_8j_n > 10", opts = "error=FALSE"),
                 jc6k("jnever", "t_8j_never = 1", opts = "error=FALSE")), yml = GN_STOP)
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_failures"))
  expect_match(res$message, "a claim failed: t_8j_n > 10 was false \\(value 3\\)")
  expect_identical(JuliaCall::julia_eval("isdefined(Main, :t_8j_never)"), FALSE)
})

test_that("control GN10: a Julia claim at level :warn is never collected and never stops", {
  res <- gn_jl(c(jc6k("jw", "@claim t_8j_n > 10 level=:warn", opts = "error=FALSE"),
                 jc6k("jt", "t_8j_tail = 1", opts = "error=FALSE")))
  expect_false(res$failed, label = res$message)
  expect_identical(nrow(res$failures), 0L)
  expect_identical(nrow(rows6k(res$knit$warnings, "jw")), 1L)
})

test_that("GN11: a failing Julia claim in a chunk with error: true raises nothing, the rest of the chunk runs, the render fails at the end", {
  res <- gn_jl(c(jc6k("je", "@claim t_8j_n > 10", "t_8j_after_e = 7", opts = "error=TRUE"),
                 jc6k("jt", "t_8j_tail_e = 1", opts = "error=FALSE")))
  expect_true(res$failed)
  expect_s3_class(res$error, "weft_failures")
  expect_identical(JuliaCall::julia_eval("t_8j_after_e"), 7L)
  expect_identical(JuliaCall::julia_eval("t_8j_tail_e"), 1L)
  expect_identical(as.character(res$failures$chunk), "je")
})

test_that("GN10: a Julia chunk with eval = FALSE records nothing", {
  res <- gn_jl(c(jc6k("jn", "@claim t_8j_n > 10", opts = "eval=FALSE"),
                 jc6k("jt", "t_8j_tail_n = 1", opts = "error=FALSE")))
  expect_false(res$failed, label = res$message)
  expect_identical(nrow(res$failures), 0L)
})

test_that("GN12: in draft mode the collected Julia failures are reported and the knit does not fail", {
  res <- gn_jl(c(jc6k("ja", "@claim t_8j_n > 10", opts = "error=FALSE"),
                 jc6k("jb", "t_8j_draft_end = 1", opts = "error=FALSE")),
               yml = "chunk_claims: collect", draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(as.character(res$failures$chunk), "ja")
  expect_identical(JuliaCall::julia_eval("t_8j_draft_end"), 1L)
})

test_that("GN8b, GN7, E31: a collected Julia claim, then error() in a later Julia chunk, is weft_claims_collected with the error as parent and a count of 1", {
  res <- gn_jl(c(jc6k("ja", "@claim t_8j_n > 10", opts = "error=FALSE"),
                 jc6k("jboom", "error(\"boom\")", opts = "error=FALSE"),
                 "End."))
  expect_true(res$failed)
  e <- res$error
  expect_s3_class(e, "weft_claims_collected")
  expect_s3_class(e, "weft_error")
  expect_s3_class(e$parent, "error")
  expect_match(conditionMessage(e$parent), "boom", fixed = TRUE)
  expect_e31(res, 1L)
  expect_match(res$message, "ja", fixed = TRUE)
})

test_that("GN8b: a claim collected and an error() in the same Julia chunk: the chunk's claims are drained first, so the count is 1 and the claim is listed", {
  res <- gn_jl(c(jc6k("jsame", "@claim t_8j_n > 10", "error(\"boom\")", opts = "error=FALSE")))
  expect_true(res$failed)
  expect_s3_class(res$error, "weft_claims_collected")
  expect_e31(res, 1L)
  expect_match(res$message, "jsame", fixed = TRUE)
  expect_match(res$message, "t_8j_n > 10 was false (value 3)", fixed = TRUE)
  expect_identical(nrow(res$failures), 1L)
})

test_that("control GN8b: the same error() with no collected claim keeps its class and message", {
  res <- gn_jl(c(jc6k("jok", "@claim t_8j_n > 1", opts = "error=FALSE"),
                 jc6k("jboom", "error(\"boom\")", opts = "error=FALSE")))
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_claims_collected"))
  expect_false(inherits(res$error, "weft_failures"))
  expect_match(res$message, "boom", fixed = TRUE)
  expect_false(grepl("The error that stopped the knit", res$message, fixed = TRUE))
})
