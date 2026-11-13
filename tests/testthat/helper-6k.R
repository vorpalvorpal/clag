# Helpers for the package 6k tests (claim() from Python and Julia, knitr back end, rules N50 to
# N52, N55, N56, N58 to N60 of dev/design-6.md). They sit beside helper-5.R, helper-5c.R,
# helper-5j.R and helper-4a.R and reuse their k5(), k5j(), pychunk(), py_try(), py_forms_ready(),
# r5_fresh(), kv5(), memo5d(), msg5(), g_scenario(), g_gate(), c3_chunk() and read_src(). Nothing here
# reads R/, inst/ or python/.
#
# ---- THE INTERFACE THE TESTS FIX (the note leaves it open) -----------------------------------
#
# A failed or warned guest claim is one row of last_knit()$failures (level fail) or
# last_knit()$warnings (level warn), with the columns of last_knit(): kind "failed claim" for a failure,
# `chunk` the chunk label, `expr` the N58 text and `detail` the N58 detail. Nothing else of a row is
# pinned (not `line`, not `kind` of a warned row).
#
# ---- helpers here -----------------------------------------------------------------------------
#   re6k(x)                 x as a regular expression that matches it literally
#   rows6k(df, label)       the rows of a failures or warnings data frame at one chunk label
#   det6k(df)               the details of those rows, as plain strings
#   pc6k(label, ..., opts)  a Python chunk (lines): chunk options default to error=TRUE
#   jc6k(label, ..., opts)  a Julia chunk (lines)
#   py_exe6k()              the Python executable reticulate uses (skips when there is none)
#   py_lib6k()              the folder that holds the package `weft` (inst/python)
#   cc6k(lines, ext)        weft:::count_constructs() of a document
#   claims6k(code, engine)  the rows of kind "claim" a chunk of that engine yields
#   g6k_lint(lines, ext)    the findings of the guest-call rule on a document

.w6k <- new.env()

re6k <- function(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)

rows6k <- function(df, label) {
  if (is.null(df)) return(NULL)
  df[df$chunk %in% label, , drop = FALSE]
}

det6k <- function(df) vapply(df$detail, msg5, "", USE.NAMES = FALSE)

pc6k <- function(label, ..., opts = "error=TRUE") pychunk(label, c(...), opts)

jc6k <- function(label, ..., opts = "error=TRUE") {
  c(paste0("```{julia ", label, if (length(opts)) paste0(", ", opts), "}"), c(...), "```", "")
}

py_exe6k <- function() {
  skip_if_no_python()
  reticulate::py_exe()
}

py_lib6k <- function() normalizePath(system.file("python", package = "weft"), mustWork = FALSE)

# ---- the gate and the lints ------------------------------------------------------------------

cc6k <- function(lines, ext = "qmd") weft:::count_constructs(read_src(lines, ext = ext))

claims6k <- function(code, engine) {
  x <- cc6k(c("Intro.", "", c3_chunk(code, engine = engine)))
  x[x$kind == "claim", , drop = FALSE]
}

g6k_lint <- function(lines, ext = "Rmd", env = parent.frame()) {
  lint_one(lines, rules = "guest-call", ext = ext, tier = 1:2, env = env)
}
