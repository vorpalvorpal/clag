# Helpers for the package-C tests (the Quarto side and the backstops).
# They sit beside helper-render.R and use its weft_test_lib() and
# skip_if_no_quarto(); nothing here edits it.
#
#   weft_filter_path()   the shipped Lua filter (stops when it is missing)
#   run_filter()         one markdown string through `pandoc --lua-filter`
#   r_fresh()            a snippet of R in a fresh, vanilla R process
#   mk_project()         a temp Quarto project, optionally set up by use_quarto()
#   qrender()            `quarto render` in a directory, with weft installed
#   render_rmd_filtered() an .Rmd through rmarkdown with the filter named

weft_filter_path <- function() {
  p <- system.file("quarto", "weft-check.lua", package = "weft")
  if (!nzchar(p)) {
    stop("inst/quarto/weft-check.lua is not shipped with weft", call. = FALSE)
  }
  p
}

skip_if_no_pandoc <- function() {
  testthat::skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
}

# Run `md` through Pandoc with the filter. Returns
#   status  the exit status (0 when it ran to the end)
#   log     what Pandoc and the filter wrote to stdout/stderr
#   text    the plain-text output ("" when none was written)
# WEFT_DRAFT and WEFT_COLLECT are unset unless `env` sets them. `files`
# (named list of character) are written into the working directory first,
# e.g. a _weft.yml.
run_filter <- function(md, env = NULL, filter = weft_filter_path(),
                       files = NULL, dir = NULL, name = "in.md") {
  skip_if_no_pandoc()
  if (is.null(dir)) dir <- tempfile("weft-pd-")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  dir <- normalizePath(dir)
  for (f in names(files)) writeLines(files[[f]], file.path(dir, f), useBytes = TRUE)
  con <- file(file.path(dir, name), "wb")
  writeBin(charToRaw(enc2utf8(paste0(paste(md, collapse = "\n"), "\n"))), con)
  close(con)
  vars <- c(WEFT_DRAFT = NA, WEFT_COLLECT = NA)
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  withr::local_dir(dir)
  log <- suppressWarnings(system2(
    rmarkdown::pandoc_exec(),
    c("--lua-filter", shQuote(filter), "-f", "markdown", "-t", "plain",
      "-o", "out.txt", shQuote(name)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(log, "status")
  status <- if (is.null(status)) 0L else status
  out <- file.path(dir, "out.txt")
  text <- if (file.exists(out)) {
    paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  } else ""
  list(status = status, log = paste(log, collapse = "\n"), text = text, dir = dir)
}

# A case table: a named character vector of markdown sources. Every one must
# stop the filter with exit status 1 (a Lua error would give another status).
expect_filter_fails <- function(cases, env = NULL) {
  for (nm in names(cases)) {
    r <- run_filter(cases[[nm]], env = env)
    testthat::expect_identical(r$status, 1L, label = paste("exit status for", nm))
  }
}

# Every one must pass (status 0), and the plain-text output must contain
# `keep` (a fixed string) when the case table gives one in attr "keep".
expect_filter_passes <- function(cases, keep = NULL) {
  for (nm in names(cases)) {
    r <- run_filter(cases[[nm]])
    testthat::expect_identical(r$status, 0L, label = paste("exit status for", nm))
    if (!is.null(keep) && !is.na(keep[[nm]])) {
      testthat::expect_true(grepl(tolower(keep[[nm]]), tolower(r$text), fixed = TRUE),
                            label = paste("output of", nm, "still has its text"))
    }
  }
}

# ---- a fresh R process ------------------------------------------------------

# Runs `code` (a character vector of lines) with `Rscript --vanilla` in a
# scratch directory and returns its stdout as lines. stderr is returned in
# attr "stderr" when it is not empty.
r_fresh <- function(code, dir = NULL) {
  if (is.null(dir)) dir <- tempfile("weft-r-")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  script <- file.path(dir, "script.R")
  writeLines(code, script)
  withr::local_dir(dir)
  err <- tempfile()
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                  c("--vanilla", shQuote(script)),
                                  stdout = TRUE, stderr = err))
  e <- readLines(err, warn = FALSE)
  if (length(e)) attr(out, "stderr") <- e
  out
}

# ---- Quarto projects --------------------------------------------------------

quarto_env <- function(extra = NULL) {
  lib <- weft_test_lib()
  env <- c(NO_COLOR = "1", WEFT_DRAFT = NA, WEFT_COLLECT = NA)
  if (nzchar(lib)) env <- c(env, R_LIBS = lib)
  for (n in names(extra)) env[[n]] <- extra[[n]]
  env
}

# Write a project into a fresh directory. `files` is a named list of
# character vectors (lines), keyed by relative path. With `use = TRUE` the
# project is then set up by use_quarto() (its messages are dropped).
mk_project <- function(files, use = TRUE, dir = NULL) {
  if (is.null(dir)) dir <- tempfile("weft-proj-")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  dir <- normalizePath(dir)
  put_files(dir, files)
  if (use) suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  dir
}

put_files <- function(dir, files) {
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  invisible(dir)
}

# `quarto render <args>` in `dir`. Returns list(status, log).
qrender <- function(dir, args = character(), env = NULL) {
  skip_if_no_quarto()
  withr::local_envvar(quarto_env(env))
  withr::local_dir(dir)
  log <- suppressWarnings(system2(Sys.which("quarto"), c("render", args),
                                  stdout = TRUE, stderr = TRUE))
  status <- attr(log, "status")
  list(status = if (is.null(status)) 0L else status,
       log = paste(log, collapse = "\n"))
}

# a regexp for the number of times a pattern occurs in a string
n_matches <- function(pattern, x) {
  m <- gregexpr(pattern, x, perl = TRUE)[[1]]
  if (identical(m[1], -1L)) 0L else length(m)
}

# list a directory tree: relative file paths, dot-files included
tree <- function(dir) {
  sort(list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = FALSE,
                  no.. = TRUE))
}

# ---- rmarkdown with the filter ---------------------------------------------

# Writes doc.Rmd (front matter naming the filter beside it as
# 9.2.7 / 2.5.3 describe) and renders it in a fresh R process.
# Returns list(failed, log, dir, output).
render_rmd_filtered <- function(body, name = "doc") {
  skip_if_no_pandoc()
  dir <- normalizePath(tempfile("weft-rmd-"), mustWork = FALSE)
  dir.create(dir)
  dir <- normalizePath(dir)
  file.copy(weft_filter_path(), file.path(dir, "weft-check.lua"))
  yaml <- c("---", "title: \"t\"", "output:", "  md_document:",
            "    variant: markdown",
            "    pandoc_args: [\"--lua-filter\", \"weft-check.lua\"]",
            "---", "")
  writeLines(c(yaml, body), file.path(dir, paste0(name, ".Rmd")))
  vars <- c(WEFT_DRAFT = NA, WEFT_COLLECT = NA)
  lib <- weft_test_lib()
  if (nzchar(lib)) vars[["R_LIBS"]] <- lib
  withr::local_envvar(vars)
  withr::local_dir(dir)
  log <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--no-save", "--no-restore", "-e",
      shQuote(sprintf("rmarkdown::render('%s.Rmd', quiet = TRUE)", name))),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(log, "status")
  out <- file.path(dir, paste0(name, ".md"))
  list(failed = !is.null(status) && status != 0,
       log = paste(log, collapse = "\n"), dir = dir,
       output = if (file.exists(out)) {
         paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
       } else "")
}

# the document bodies the backstop tests share ------------------------------

# One document per kind of in-scope construct (stage 1a). Each defines its
# variables in an ordinary chunk and never activates weft.
kind_bodies <- function(setup = "") {
  chunk <- c("```{r setup, include=FALSE}", setup, "depth <- 12.5", "k <- 1", "```", "")
  list(
    value = c(chunk, "Depth is `r depth`{.num} here."),
    n     = c(chunk, "Found [one site | # sites]{n=\"k\"} here."),
    `if`  = c(chunk, "It was [met | not met]{if=\"depth > 5\"} here."),
    text  = c(chunk, "A [result]{.strong} and a [note]{.em} here."),
    capital_R = c(chunk, "Depth is `R depth`{.num} here.")
  )
}

as_chr <- function(x) as.character(unlist(x))
