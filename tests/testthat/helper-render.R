# Render helpers for the package-B tests (the knitr runtime).
#
# render_rmd()  one document through rmarkdown (a fresh R process, or this one)
# render_qmd()  one document through `quarto render --to markdown`
# both()        a case under each engine
# batch_cases() / split_cases()  many cases in one document, split on markers
# canon_md()    pandoc's own normal form of markdown, so an expectation is
#               written as markdown without caring how pandoc re-spells it
#
# Every function writes into a fresh temp directory and returns a list:
#   text     character vector of output lines (YAML header removed, trimmed)
#   md       the same as one string
#   failed   TRUE when the render stopped with an error
#   error    NULL, or list(message, class); class is NA under Quarto
#   message  shortcut for error$message ("" when none)
#   log      messages and warnings seen during the render (and, under Quarto
#            and in a child process, its stderr text)
#   offset   lines the helper added above `lines` (a line k of `lines` is
#            line offset + k of the file)
#   dir, file, input   where it was written
#   knit     weft:::last_knit() at the end of the render, in-process only
# Under Quarto the message is the stderr text and the class is NA.

.weft_t <- new.env()

# TRUE when the tests run against a development copy of the package
weft_is_dev <- function() {
  "weft" %in% loadedNamespaces() && pkgload::is_dev_package("weft")
}

weft_pkg_root <- function() {
  pkgload::pkg_path(normalizePath(testthat::test_path("."), mustWork = FALSE))
}

# The library a Quarto (or any subprocess) should see weft in. For a
# development copy: the package installed once per session into a temp lib.
weft_test_lib <- function() {
  if (!is.null(.weft_t$lib)) return(.weft_t$lib)
  if (!weft_is_dev()) {
    p <- find.package("weft", quiet = TRUE)
    .weft_t$lib <- if (length(p)) dirname(p) else ""
    return(.weft_t$lib)
  }
  lib <- tempfile("weft-lib-")
  dir.create(lib)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-docs", "--no-multiarch", "--no-test-load",
      paste0("--library=", shQuote(lib)), shQuote(weft_pkg_root())),
    stdout = TRUE, stderr = TRUE
  ))
  if (!dir.exists(file.path(lib, "weft"))) {
    stop("could not install the development weft for the Quarto tests:\n",
         paste(out, collapse = "\n"))
  }
  .weft_t$lib <- lib
  lib
}

# ---- the render itself (one body, run in a child process or here) ---------

.weft_core_src <- '
weft_test_core <- function(input, output, format, pre = "") {
  res <- list(failed = FALSE, error = NULL, log = character())
  logv <- character()
  withCallingHandlers(
    tryCatch({
      if (nzchar(pre)) eval(parse(text = pre), globalenv())
      if (identical(format, "knit")) {
        knitr::knit(input, output, quiet = TRUE, envir = new.env())
      } else {
        f <- rmarkdown::md_document(variant = "markdown",
                                    pandoc_args = "--wrap=none")
        f$knitr$opts_chunk$echo <- FALSE
        f$knitr$opts_chunk$comment <- ""
        rmarkdown::render(input, f, output_file = output, quiet = TRUE,
                          envir = new.env())
      }
    }, error = function(e) {
      res$failed <<- TRUE
      res$error <<- list(message = conditionMessage(e), class = class(e))
    }),
    message = function(m) {
      logv <<- c(logv, conditionMessage(m)); invokeRestart("muffleMessage")
    },
    warning = function(w) {
      logv <<- c(logv, paste0("Warning: ", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )
  res$log <- logv
  res
}
'

weft_restore_knitr <- function() {
  knitr::knit_hooks$restore()
  knitr::opts_hooks$restore()
  knitr::opts_knit$restore()
  knitr::opts_chunk$restore()
}

run_rmd_file <- function(input, output, format, in_process, env, pre = "",
                         restore = TRUE) {
  if (in_process) {
    withr::local_envvar(env)
    withr::local_dir(dirname(input))
    if (restore) withr::defer(weft_restore_knitr())
    eval(parse(text = .weft_core_src))
    res <- weft_test_core(basename(input), basename(output), format, pre)
    res$knit <- tryCatch(weft:::last_knit(), error = function(e) NULL)
    return(res)
  }
  resfile <- tempfile(fileext = ".rds")
  # the development copy installed into a temp library, so that the child
  # sees an installed, unattached package and library(weft) works in it
  root <- if (weft_is_dev()) weft_test_lib() else ""
  code <- paste0(
    .weft_core_src, "\n",
    "options(warn = 1)\n",
    "a <- commandArgs(TRUE)\n",
    "if (nzchar(a[1])) {\n",
    "  .libPaths(c(a[1], .libPaths()))\n",
    "}\n",
    "setwd(dirname(a[2]))\n",
    "a[6] <- trimws(a[6])\n",
    "res <- weft_test_core(basename(a[2]), basename(a[3]), a[5], a[6])\n",
    "saveRDS(res, a[4])\n"
  )
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--no-save", "--no-restore", "-e", shQuote(code),
      shQuote(root), shQuote(input), shQuote(output), shQuote(resfile),
      format, shQuote(if (nzchar(pre)) pre else " ")),
    stdout = TRUE, stderr = TRUE,
    env = c(sprintf("%s=%s", names(env), unname(env)))
  ))
  if (file.exists(resfile)) {
    res <- readRDS(resfile)
    res$log <- c(res$log, out)
  } else {
    res <- list(failed = TRUE,
                error = list(message = paste(out, collapse = "\n"),
                             class = NA_character_),
                log = out)
  }
  res
}

# ---- documents -------------------------------------------------------------

rmd_header <- function(front = NULL, code = NULL, weft_setup = TRUE,
                       engine = c("rmd", "qmd")) {
  engine <- match.arg(engine)
  yaml <- c("---", "title: \"t\"")
  if (engine == "qmd") {
    yaml <- c(yaml, "engine: knitr", "format:", "  markdown:",
              "    wrap: none", "execute:", "  echo: false")
  }
  yaml <- c(yaml, front, "---", "")
  chunk <- c("```{r setup, include=FALSE}",
             if (weft_setup) "weft::weft_setup()", code, "```", "")
  c(yaml, chunk)
}

# Write the files of a test document into a fresh directory
write_doc <- function(lines, setup, code, front, files, name, engine,
                      bom = FALSE, eol = "\n", final_newline = TRUE,
                      dir = NULL) {
  if (is.null(dir)) dir <- tempfile("weft-doc-")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir <- normalizePath(dir)
  lines <- unlist(strsplit(paste(lines, collapse = "\n"), "\n", fixed = TRUE))
  if (!isFALSE(setup) || !is.null(code)) {
    hdr <- rmd_header(front, code, weft_setup = isTRUE(setup), engine = engine)
    lines <- c(hdr, lines)
    offset <- length(hdr)
  } else {
    offset <- 0L
  }
  ext <- if (engine == "rmd") ".Rmd" else ".qmd"
  input <- file.path(dir, paste0(name, ext))
  txt <- paste(lines, collapse = eol)
  if (final_newline) txt <- paste0(txt, eol)
  con <- file(input, "wb")
  if (bom) writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)
  writeBin(charToRaw(enc2utf8(txt)), con)
  close(con)
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  list(dir = dir, input = input, offset = offset, name = paste0(name, ext))
}

tidy_output <- function(path, keep_yaml = FALSE) {
  if (!file.exists(path)) return(character())
  x <- readLines(path, warn = FALSE, encoding = "UTF-8")
  x <- sub("\r$", "", x)
  # drop a leading YAML header (Quarto keeps one)
  if (!keep_yaml && length(x) && x[1] == "---") {
    end <- which(x[-1] == "---")[1]
    if (!is.na(end)) x <- x[-seq_len(end + 1L)]
  }
  while (length(x) && !nzchar(trimws(x[1]))) x <- x[-1]
  while (length(x) && !nzchar(trimws(x[length(x)]))) x <- x[-length(x)]
  x
}

finish <- function(res, text, d) {
  res$text <- text
  res$md <- paste(text, collapse = "\n")
  res$failed <- isTRUE(res$failed)
  res$message <- if (is.null(res$error)) "" else res$error$message
  res$offset <- d$offset
  res$dir <- d$dir
  res$input <- d$input
  res$file <- d$name
  res
}

# format = "md": through rmarkdown and Pandoc (markdown variant, no wrapping).
# format = "knit": plain knitr::knit(), the raw text weft produced.
render_rmd <- function(lines, setup = TRUE, code = NULL, front = NULL,
                       files = NULL, env = NULL, in_process = FALSE,
                       format = c("md", "knit"), name = "doc",
                       bom = FALSE, eol = "\n", final_newline = TRUE,
                       dir = NULL, pre = "", keep_yaml = FALSE,
                       restore = TRUE) {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  format <- match.arg(format)
  d <- write_doc(lines, setup, code, front, files, name, "rmd",
                 bom = bom, eol = eol, final_newline = final_newline,
                 dir = dir)
  out <- file.path(d$dir, paste0(name, ".md"))
  env <- if (is.null(env)) character() else env
  res <- run_rmd_file(d$input, out, format, in_process, env, pre, restore)
  finish(res, tidy_output(out, keep_yaml || format == "knit"), d)
}

skip_if_no_quarto <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(nzchar(Sys.which("quarto")), "quarto is not available")
}

render_qmd <- function(lines, setup = TRUE, code = NULL, front = NULL,
                       files = NULL, env = NULL, name = "doc",
                       bom = FALSE, eol = "\n", final_newline = TRUE,
                       dir = NULL, keep_yaml = FALSE) {
  skip_if_no_quarto()
  d <- write_doc(lines, setup, code, front, files, name, "qmd",
                 bom = bom, eol = eol, final_newline = final_newline,
                 dir = dir)
  out <- file.path(d$dir, paste0(name, ".md"))
  lib <- weft_test_lib()
  env <- c(NO_COLOR = "1", env)
  if (nzchar(lib)) env <- c(R_LIBS = paste(c(lib, .libPaths()), collapse = .Platform$path.sep), env)
  old <- setwd(d$dir)
  on.exit(setwd(old), add = TRUE)
  log <- suppressWarnings(system2(
    Sys.which("quarto"),
    c("render", shQuote(basename(d$input)), "--to", "markdown"),
    stdout = TRUE, stderr = TRUE,
    env = sprintf("%s=%s", names(env), unname(env))
  ))
  status <- attr(log, "status")
  failed <- !is.null(status) && status != 0
  res <- list(failed = failed, log = log, error = NULL)
  if (failed) {
    res$error <- list(message = paste(log, collapse = "\n"),
                      class = NA_character_)
  }
  finish(res, tidy_output(out, keep_yaml), d)
}

# Run one case under each engine. `expect` is either a string (the whole
# output, compared after canon_md()) or a function(res, engine) that makes
# its own expectations. Quarto is skipped when it is missing.
both <- function(lines, expect, ..., engines = c("rmd", "qmd")) {
  for (engine in engines) {
    res <- if (engine == "rmd") render_rmd(lines, ...) else render_qmd(lines, ...)
    if (is.function(expect)) {
      expect(res, engine)
    } else {
      testthat::expect_false(res$failed, label = paste(engine, "render failed"))
      testthat::expect_equal(canon_md(res$md), canon_md(expect),
                             label = paste("output under", engine))
    }
  }
  invisible(NULL)
}

# ---- batches ---------------------------------------------------------------

# cases: a character vector, one source per case (may hold "\n"). Returns the
# body lines; each case is followed by a marker paragraph.
case_marker <- function(i) sprintf("WEFTCASEMARK%03d", i)

# attr "starts": the line (in the returned body) of each case's first line
batch_cases <- function(cases) {
  out <- character()
  starts <- integer(length(cases))
  for (i in seq_along(cases)) {
    out <- c(out, case_marker(i), "")
    starts[i] <- length(out) + 1L
    out <- c(out, strsplit(cases[[i]], "\n", fixed = TRUE)[[1]], "")
  }
  out <- c(out, case_marker(length(cases) + 1L))
  attr(out, "starts") <- starts
  out
}

# Split rendered text on the markers; element i is the output of case i, as
# one string (blank edges trimmed).
split_cases <- function(res, n) {
  text <- res$text
  at <- vapply(seq_len(n + 1L), function(i) {
    w <- which(trimws(text) == case_marker(i))
    if (length(w)) w[1] else NA_integer_
  }, integer(1))
  out <- vector("list", n)
  for (i in seq_len(n)) {
    if (is.na(at[i]) || is.na(at[i + 1L])) { out[[i]] <- NA_character_; next }
    seg <- text[seq_len(at[i + 1L] - 1L)[-seq_len(at[i])]]
    seg <- sub("[ \t]+$", "", seg)
    while (length(seg) && !nzchar(seg[1])) seg <- seg[-1]
    while (length(seg) && !nzchar(seg[length(seg)])) seg <- seg[-length(seg)]
    out[[i]] <- paste(seg, collapse = "\n")
  }
  out
}

# Pandoc's normal form of markdown (one call for a whole vector).
canon_md <- function(x) {
  x <- as.character(x)
  if (!length(x)) return(x)
  sep <- "\n\nWEFTCANONSEP\n\n"
  doc <- paste(x, collapse = sep)
  pandoc <- rmarkdown::pandoc_exec()
  out <- suppressWarnings(system2(
    pandoc, c("-f", "markdown", "-t", "markdown", "--wrap=none"),
    input = doc, stdout = TRUE, stderr = TRUE
  ))
  out <- paste(out, collapse = "\n")
  parts <- strsplit(out, "\n+WEFTCANONSEP\n+")[[1]]
  if (length(parts) < length(x)) parts <- c(parts, rep("", length(x) - length(parts)))
  parts <- sub("^\n+", "", parts[seq_along(x)])
  sub("\\s+$", "", parts)
}

# Pandoc escapes `<` and `>` in the visible markers; take the backslashes off.
unesc <- function(x) gsub("\\\\(?=[<>])", "", x, perl = TRUE)

# a `file:line` regexp for a document written by the helper; k is the line in
# the lines the test passed in
at_line <- function(res, k, file = NULL) {
  file <- if (is.null(file)) res$file else file
  sprintf("%s:%d\\b", gsub(".", "\\.", file, fixed = TRUE), res$offset + k)
}

# The conditions for the test of one case through knitr in this process
# (the scanner and the render agree on a source file)
