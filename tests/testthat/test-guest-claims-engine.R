# Stage 8, G1 (dev/design-8.md GN2b, GN2c, GN3, GN4, GN9, GN10): a failing guest claim under
# `chunk_claims: collect` on the jupyter engine and on the julia engine, with no render. The guest package
# reads the setting itself from _weft.yml and the document's front matter, at the failed claim.
#   * Jupyter: a real kernel (jup_session) with QUARTO_DOCUMENT_PATH and QUARTO_DOCUMENT_FILE pointing at a
#     temporary project; the cells' results are read as helper-jupyter.R gives them.
#   * Julia: a process with a fake engine (a module Main.QuartoNotebookWorker, which is what kind() looks
#     for); the claim runs by include_string(), as the engine runs a cell, with the document's path as its
#     file; what the claim displays is caught on a TextDisplay, and what it prints goes to stdout.
# Skips: skip_if_no_jupyter(), skip_if_julia_disabled() (and jle_cases()'s own skip_if_no_julia_engine()).
# Made-up values only. ASCII only (the ellipsis of a claim's expr is written as backslash-u-2026).
#
# READINGS of the design (see the report):
#  - the E94 lines are the elements of the traceback the kernel sends: element 1 is E94, then one element
#    per claim ("  <expr>: <detail>"), then "The error that stopped the cell:", then IPython's own
#    traceback (the text of E94 for 1 and for 2 claims is written out below);
#  - a claim is kept with the run id of run_id() (the first line of .weft/run found upward from
#    QUARTO_DOCUMENT_PATH), and E94 lists the claims whose run id is the current one;
#  - when a custom exception handler is already installed (custom_exceptions is not empty), weft leaves it.

E94_1 <- paste0("weft: this cell raised an error after 1 failed claim collected in this run. ",
                "The claims are listed first: the error may follow from a value that failed its claim.")
E94_2 <- paste0("weft: this cell raised an error after 2 failed claims collected in this run. ",
                "The claims are listed first: the error may follow from a value that failed its claim.")
EXPR_GT10E <- "claim(\u2026, '> 10')"
EXPR_LT3E <- "claim(\u2026, '< 3')"

ce_nocol <- function(x) gsub("\033\\[[0-9;]*m", "", x)

# a temporary project: _weft.yml (lines or NULL), doc.qmd (the whole text, or "Text."), .weft/run (or none)
ce_project <- function(yml = NULL, front = NULL, run = NULL, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir <- normalizePath(dir, winslash = "/")
  if (!is.null(yml)) writeLines(yml, file.path(dir, "_weft.yml"))
  writeLines(front %||% "Text.", file.path(dir, "doc.qmd"))
  if (!is.null(run)) {
    dir.create(file.path(dir, ".weft"))
    writeLines(run, file.path(dir, ".weft", "run"))
  }
  dir
}

ce_env <- function(dir) list(QUARTO_DOCUMENT_PATH = dir, QUARTO_DOCUMENT_FILE = "doc.qmd")

FRONT_COLLECT <- c("---", "title: t", "weft:", "  chunk_claims: collect", "---", "", "Text.")
FRONT_STOP <- c("---", "title: t", "weft:", "  chunk_claims: stop", "---", "", "Text.")

# ---- Jupyter ---------------------------------------------------------------------------------------------

test_that("GN2b, GN3: under collect (from _weft.yml) a failed Python claim in a Quarto kernel displays its block, raises nothing, returns the value, and the next statement runs", {
  dir <- ce_project("chunk_claims: collect")
  r <- jup_session(list("from weft import claim\nn = 7",
                        "r = claim(n, '> 10')\nprint('next', r)\nr"), env = ce_env(dir))
  x <- r[[2]]
  expect_identical(x$status, "ok", label = paste(x$ename, x$evalue))
  expect_identical(x$result, "7")
  expect_identical(x$stdout, "next 7\n")
  expect_length(x$blocks, 1L)
  b <- x$blocks[[1]]
  expect_length(b$values, 0L)
  expect_length(b$checks, 1L)
  ch <- b$checks[[1]]
  expect_identical(ch$ok, FALSE)
  expect_identical(ch$level, "fail")
  expect_identical(ch$expr, EXPR_GT10E)
  expect_identical(list(ch$value$t, ch$value$v), list("int", "7"))
})

test_that("control GN3: under stop (from _weft.yml) the same claim displays its block and raises ClaimFailed", {
  dir <- ce_project("chunk_claims: stop")
  r <- jup_session(list("from weft import claim, ClaimFailed\nn = 7", "claim(n, '> 10')", "print('next')"),
                   env = ce_env(dir))
  expect_identical(r[[2]]$status, "error")
  expect_identical(r[[2]]$ename, "ClaimFailed")
  expect_length(r[[2]]$blocks, 1L)
  expect_identical(r[[3]]$stdout, "next\n")
})

test_that("GN2b, GN10: with the setting on but no Quarto variables (an interactive kernel) a failed claim raises", {
  dir <- ce_project("chunk_claims: collect")
  r <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 10')"), cwd = dir)
  expect_identical(r[[2]]$status, "error")
  expect_identical(r[[2]]$ename, "ClaimFailed")
})

test_that("GN4: the document's own front matter overrides _weft.yml, both ways", {
  d1 <- ce_project("chunk_claims: stop", FRONT_COLLECT)
  r1 <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 10')"), env = ce_env(d1))
  expect_identical(r1[[2]]$status, "ok", label = paste(r1[[2]]$ename, r1[[2]]$evalue))
  expect_identical(r1[[2]]$result, "7")
  expect_identical(r1[[2]]$blocks[[1]]$checks[[1]]$ok, FALSE)
  d2 <- ce_project("chunk_claims: collect", FRONT_STOP)
  r2 <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 10')"), env = ce_env(d2))
  expect_identical(r2[[2]]$status, "error")
  expect_identical(r2[[2]]$ename, "ClaimFailed")
})

test_that("GN10: level warn under collect is displayed and returned, as under stop (control)", {
  dir <- ce_project("chunk_claims: collect")
  r <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 10', level='warn')"), env = ce_env(dir))
  expect_identical(r[[2]]$status, "ok")
  expect_identical(r[[2]]$blocks[[1]]$checks[[1]]$level, "warn")
})

test_that("GN9, E94: a cell that raises after collected claims has a traceback that starts with E94, lists each claim, then says `The error that stopped the cell:`, then IPython's own traceback", {
  dir <- ce_project("chunk_claims: collect")
  r <- jup_session(list("from weft import claim\nn = 7",
                        "claim(n, '> 10')",
                        "1/0",
                        "claim(n, '< 3')",
                        "1/0",
                        "get_ipython().custom_exceptions"), env = ce_env(dir))
  expect_identical(r[[2]]$status, "ok")
  x <- r[[3]]
  expect_identical(x$status, "error")
  expect_identical(x$ename, "ZeroDivisionError")
  tb <- ce_nocol(x$traceback)
  expect_identical(tb[1], E94_1)
  expect_match(tb[2], paste0("^  ", gsub("([.()])", "\\\\\\1", EXPR_GT10E), ": (_ )?> 10 was false \\(value 7\\)$"))
  expect_identical(tb[3], "The error that stopped the cell:")
  expect_true(any(grepl("ZeroDivisionError", tb[-(1:3)], fixed = TRUE)), label = "IPython's traceback follows")
  # a second claim: the plural, and both claims in the order collected
  expect_identical(r[[4]]$status, "ok")
  tb2 <- ce_nocol(r[[5]]$traceback)
  expect_identical(tb2[1], E94_2)
  expect_match(tb2[2], "> 10 was false (value 7)", fixed = TRUE)
  expect_match(tb2[3], "< 3 was false (value 7)", fixed = TRUE)
  expect_identical(tb2[4], "The error that stopped the cell:")
  # the handler was installed once, when the first claim was collected
  expect_match(r[[6]]$result, "Exception", fixed = TRUE)
})

test_that("control GN9: with no claim collected an error's traceback is IPython's own, and no handler is installed", {
  dir <- ce_project("chunk_claims: collect")
  r <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 1')", "1/0",
                        "get_ipython().custom_exceptions"), env = ce_env(dir))
  tb <- ce_nocol(r[[3]]$traceback)
  expect_identical(r[[3]]$ename, "ZeroDivisionError")
  expect_false(any(grepl("weft:", tb, fixed = TRUE)))
  expect_false(any(grepl("The error that stopped the cell", tb, fixed = TRUE)))
  expect_match(r[[4]]$result, "^\\(\\)$")
})

test_that("control GN9: a claim that raised (stop) leaves a later error's traceback untouched", {
  dir <- ce_project("chunk_claims: stop")
  r <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 10')", "1/0"), env = ce_env(dir))
  expect_false(any(grepl("weft:", ce_nocol(r[[3]]$traceback), fixed = TRUE)))
})

test_that("GN9: a custom exception handler that is already installed is left alone", {
  dir <- ce_project("chunk_claims: collect")
  r <- jup_session(list(
    paste("from weft import claim",
          "n = 7",
          "def mine(self, etype, value, tb, tb_offset=None):",
          "    return ['USER HANDLER']",
          "get_ipython().set_custom_exc((ZeroDivisionError,), mine)", sep = "\n"),
    "claim(n, '> 10')", "1/0"), env = ce_env(dir))
  expect_identical(r[[2]]$status, "ok")
  expect_identical(ce_nocol(r[[3]]$traceback), "USER HANDLER")
})

test_that("GN9: a claim collected under another run id is not listed", {
  dir <- ce_project("chunk_claims: collect", run = "run-one")
  r <- jup_session(list("from weft import claim\nn = 7", "claim(n, '> 10')",
                        list(code = "1/0", before = list(list(op = "write", path = file.path(dir, ".weft", "run"),
                                                               text = "run-two\n")))),
                   env = ce_env(dir))
  expect_identical(r[[2]]$status, "ok")
  expect_identical(r[[3]]$ename, "ZeroDivisionError")
  expect_false(any(grepl("weft:", ce_nocol(r[[3]]$traceback), fixed = TRUE)))
})

# ---- Julia, with a fake engine ------------------------------------------------------------------------------

# Each case runs the claim source SRC (as a cell) with the document path DOC in a fresh module, with the
# engine faked unless `engine` is FALSE. The output is split at a marker: what the cell printed to stdout
# first, then what it displayed (caught on a TextDisplay).
jl_case <- function(doc, src, engine = TRUE, setup = NULL, env = NULL) {
  q <- function(x) paste0("\"", gsub("([\"\\\\$])", "\\\\\\1", x), "\"")
  c("using Weft",
    if (engine) "isdefined(Main, :QuartoNotebookWorker) || Core.eval(Main, :(module QuartoNotebookWorker end))",
    "n = 7",
    setup,
    env,
    "buf = IOBuffer()",
    "pushdisplay(TextDisplay(buf))",
    "res = try",
    sprintf("    Base.include_string(@__MODULE__, %s, %s)", q(src), q(doc)),
    "catch e",
    "    while e isa LoadError; e = e.error; end",
    "    string(\"THREW \", nameof(typeof(e)))",
    "end",
    "popdisplay()",
    "println(\"RESULT=\", res)",
    "println(\"@@DISPLAY@@\")",
    "print(String(take!(buf)))")
}

jl_split <- function(r) {
  out <- r$out
  i <- regexpr("@@DISPLAY@@\n", out, fixed = TRUE)
  list(stdout = if (i > 0) substr(out, 1L, i - 1L) else out,
       display = if (i > 0) substring(out, i + attr(i, "match.length")) else "")
}

jl_run <- function(cases) {
  skip_if_julia_disabled()
  res <- jle_cases(vapply(cases, paste, "", collapse = "\n"))
  lapply(res, function(r) c(r, jl_split(r)))
}

JL_SRC <- "r = @claim n > 10\nprintln(\"after\")\nr"

test_that("GN2c, GN3: on the julia engine, under collect, a failed claim displays its block (no tilde fence on stdout), throws nothing, returns the value, and the cell goes on", {
  d <- ce_project("chunk_claims: collect")
  x <- jl_run(list(jl_case(file.path(d, "doc.qmd"), JL_SRC)))[[1]]
  expect_identical(x$emsg, "")
  expect_match(x$stdout, "after", fixed = TRUE)
  expect_match(x$stdout, "RESULT=7", fixed = TRUE)
  expect_false(grepl("~~~~", x$stdout, fixed = TRUE), label = "nothing is printed as a carrier")
  expect_false(grepl("THREW", x$stdout, fixed = TRUE))
  expect_length(x$blocks, 1L)
  b <- x$blocks[[1]]
  expect_identical(b$lang, "julia")
  expect_length(b$values, 0L)
  ch <- b$checks[[1]]
  expect_identical(ch$ok, FALSE)
  expect_identical(ch$level, "fail")
  expect_identical(ch$text, "n > 10")
  expect_true(startsWith(ch$expr, "@claim n > 10"), label = ch$expr)
  expect_identical(list(ch$value$t, ch$value$v), list("int", "7"))
  expect_identical(as.integer(ch$line), 1L)
})

test_that("GN3: two failed claims in one cell are two displayed blocks, and each returns the value of its first operand", {
  d <- ce_project("chunk_claims: collect")
  src <- "a = @claim n (_ > 10)\nb = @claim n (_ > 20)\nprintln(\"a=\", a, \" b=\", b)"
  x <- jl_run(list(jl_case(file.path(d, "doc.qmd"), src)))[[1]]
  expect_identical(x$emsg, "")
  expect_match(x$stdout, "a=7 b=7", fixed = TRUE)
  expect_length(x$blocks, 2L)
})

test_that("control GN3: under stop (from _weft.yml, or with no setting) the claim PRINTS its block with a tilde fence and throws ClaimFailed, and displays nothing", {
  d1 <- ce_project("chunk_claims: stop")
  d2 <- ce_project(NULL)
  x <- jl_run(list(jl_case(file.path(d1, "doc.qmd"), JL_SRC), jl_case(file.path(d2, "doc.qmd"), JL_SRC)))
  for (i in 1:2) {
    expect_match(x[[i]]$stdout, "~~~~{.weft-values}", fixed = TRUE, label = i)
    expect_match(x[[i]]$stdout, "THREW ClaimFailed", fixed = TRUE, label = i)
    expect_false(grepl("after", x[[i]]$stdout, fixed = TRUE), label = i)
    expect_length(x[[i]]$blocks, 0L)
  }
})

test_that("GN4: the document's front matter overrides _weft.yml, both ways", {
  d1 <- ce_project("chunk_claims: stop", FRONT_COLLECT)
  d2 <- ce_project("chunk_claims: collect", FRONT_STOP)
  x <- jl_run(list(jl_case(file.path(d1, "doc.qmd"), JL_SRC), jl_case(file.path(d2, "doc.qmd"), JL_SRC)))
  expect_match(x[[1]]$stdout, "RESULT=7", fixed = TRUE)
  expect_length(x[[1]]$blocks, 1L)
  expect_match(x[[2]]$stdout, "THREW ClaimFailed", fixed = TRUE)
  expect_length(x[[2]]$blocks, 0L)
})

test_that("GN4: a relative file name is made absolute against QUARTO_DOCUMENT_PATH; a file that is not .qmd or .md reads _weft.yml from QUARTO_DOCUMENT_PATH", {
  d1 <- ce_project("chunk_claims: stop", FRONT_COLLECT)
  d2 <- ce_project("chunk_claims: collect")
  setenv <- function(d) sprintf("ENV[\"QUARTO_DOCUMENT_PATH\"] = %s", paste0("\"", d, "\""))
  x <- jl_run(list(
    jl_case("doc.qmd", JL_SRC, env = setenv(d1)),
    jl_case("script.jl", JL_SRC, env = setenv(d2))))
  expect_match(x[[1]]$stdout, "RESULT=7", fixed = TRUE)
  expect_length(x[[1]]$blocks, 1L)
  expect_match(x[[2]]$stdout, "RESULT=7", fixed = TRUE)
  expect_length(x[[2]]$blocks, 1L)
})

test_that("control GN10: a claim at level :warn is displayed and returned on the julia engine, under either setting", {
  d <- ce_project("chunk_claims: collect")
  x <- jl_run(list(jl_case(file.path(d, "doc.qmd"), "r = @claim n > 10 level=:warn\nr")))[[1]]
  expect_match(x$stdout, "RESULT=7", fixed = TRUE)
  expect_length(x$blocks, 1L)
  expect_identical(x$blocks[[1]]$checks[[1]]$level, "warn")
})

test_that("GN2d, GN10: plain Julia (no engine) never collects: the claim throws ClaimFailed whatever the setting", {
  d <- ce_project("chunk_claims: collect", FRONT_COLLECT)
  x <- jl_run(list(jl_case(file.path(d, "doc.qmd"), JL_SRC, engine = FALSE)))[[1]]
  expect_match(x$stdout, "THREW ClaimFailed", fixed = TRUE)
  expect_false(grepl("after", x$stdout, fixed = TRUE))
  expect_length(x$blocks, 0L)
})
