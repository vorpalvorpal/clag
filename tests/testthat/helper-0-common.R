# Definitions shared by more than one helper file. testthat sources helpers alphabetically, and
# "helper-0-common.R" sorts before every other helper, so these exist when the others are read.

`%||%` <- function(a, b) if (is.null(a)) b else a

# the Python library folder that ships with weft
py_lib_6e <- function() normalizePath(system.file("python", package = "weft"), mustWork = FALSE)

# the text of an output file of a render, or ""
qm_read <- function(dir, rel) {
  p <- file.path(dir, rel)
  if (!file.exists(p)) return("")
  paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# `quarto render <args>` in dir with the variables `vars` set, then `env` over them. Returns
# list(status, stdout, stderr, log). The helper that calls it sets up `vars` (and its own scratch).
quarto_render_env <- function(dir, args, vars, env) {
  lib <- weft_test_lib()
  if (nzchar(lib)) vars[["R_LIBS"]] <- paste(c(lib, .libPaths()), collapse = .Platform$path.sep)
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  withr::local_dir(dir)
  errf <- tempfile("q-err-")
  on.exit(unlink(errf), add = TRUE)
  out <- suppressWarnings(system2(Sys.which("quarto"), c("render", args), stdout = TRUE, stderr = errf))
  st <- attr(out, "status")
  err <- paste(readLines(errf, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  list(status = if (is.null(st)) 0L else as.integer(st), stdout = paste(out, collapse = "\n"), stderr = err,
       log = paste(c(out, err), collapse = "\n"))
}

# the scalar records of N22, written as compact JSON the way a writer would
fr_int <- function(digits) sprintf('{"t":"int","v":"%s"}', digits)
fr_float <- function(text) sprintf('{"t":"float","v":"%s"}', text)
fr_dec <- function(text) sprintf('{"t":"decimal","v":"%s"}', text)
