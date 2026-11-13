# Package 6h: the julia engine and plain Julia for the tests of Weft.jl (dev/design-6.md, section 5,
# "Real Jupyter and Julia"). ASCII only.
#
# skip_if_no_julia_engine() skips ONLY when `quarto` or `julia` is absent. The first `quarto render` on
# the julia engine may install QuartoNotebookRunner under ~/.julia (allowed, it can take minutes). The
# tests make the package under test visible to Julia by LOAD_PATH: the helper sets JULIA_LOAD_PATH to
# the package's inst/julia folder with a trailing separator, which keeps Julia's default load path.
#
# MEASURED, not in the design (see the report, "Spec gaps"): the notebook worker that
# QuartoNotebookRunner starts does NOT inherit JULIA_LOAD_PATH (it sets "@:@stdlib"). What does reach it
# is the project's `julia:` key: `julia: {env: ["JULIA_LOAD_PATH=..."]}` in _quarto.yml. So the projects
# below carry that key as well, and `using Weft` in a cell finds inst/julia.
#
# HELPERS
#   skip_if_no_julia_engine()   the skip above.
#   jle_lib()                    the folder that holds the package `Weft` (inst/julia of the tree under test).
#   jle_load_path()              the JULIA_LOAD_PATH value: jle_lib() and a trailing separator.
#   jle_kill()                   `quarto call engine julia kill` (the server outlives renders, measured 5).
#   jle_kill_at_file_end()       call at the top of a test file: kills the server when the file is done.
#   jle_cases(codes)             runs each Julia snippet in a module of its own, in ONE plain `julia`
#                               process, with no Quarto: returns, per snippet, out (its stdout), etype (the
#                               name of the exception that ended it, or ""), emsg (showerror of it), and
#                               blocks (the parsed weft-values blocks printed to its stdout, in order).
#   jle_project(files, filter)   a temporary Quarto project on the julia engine; with filter = TRUE it is set
#                               up by weft::use_quarto() (the resolver filter), else it is left bare, so the
#                               carrier blocks stay in the output.
#   jle_render(dir, args, env)   `quarto render` in it: list(status, stdout, stderr, log).
#   jle_read(dir, rel)           the text of an output file of a render, or "".
#   jle_html_blocks(html)        the weft-values blocks that a bare render left in the HTML, by cell label.
#   jle_msg                      messages of section 7 used by 6h (E41, E42, E55, E62).

.jle <- new.env()

skip_if_no_julia_engine <- function() {
  testthat::skip_if(!nzchar(Sys.which("quarto")), "quarto is not available")
  testthat::skip_if(!nzchar(Sys.which("julia")), "julia is not available")
}

jle_lib <- function() normalizePath(system.file("julia", package = "weft"), winslash = "/", mustWork = FALSE)

jle_load_path <- function() paste0(jle_lib(), .Platform$path.sep)

jle_kill <- function() {
  if (nzchar(Sys.which("quarto"))) {
    suppressWarnings(try(system2(Sys.which("quarto"), c("call", "engine", "julia", "kill"),
                                 stdout = FALSE, stderr = FALSE), silent = TRUE))
  }
  invisible(NULL)
}

# `quarto call engine julia kill` when the file's tests are done (design section 5)
jle_kill_at_file_end <- function() {
  env <- tryCatch(testthat::teardown_env(), error = function(e) NULL)
  if (!is.null(env)) withr::defer(jle_kill(), envir = env)
  invisible(NULL)
}

# ---- messages of section 7 ---------------------------------------------------------------------------

jle_msg <- list(
  E41 = function(name) sprintf("`%s` is not a name weft can publish: ASCII letters, digits, _ and ., starting with a letter or _ (rule 1.12.1).", name),
  E42 = function(name, n) sprintf("`%s` is a list of %d elements; weft publishes at most 10000 (rule 2.13.1).", name, n),
  E55 = function(check, val) sprintf("weft: a claim failed: %s was false (value %s).", check, val),
  E62 = "Install the Julia package: using Pkg; Pkg.add(url = \"https://github.com/vorpalvorpal/weft\", subdir = \"inst/julia/Weft\")"
)

# ---- plain Julia, no Quarto --------------------------------------------------------------------------

jle_driver_source <- c(
  "dir = ARGS[1]",
  "n = parse(Int, ARGS[2])",
  "for i in 1:n",
  "    src = read(joinpath(dir, \"case-$i.jl\"), String)",
  "    m = Module(Symbol(\"Case\", i))",
  "    etype = \"\"",
  "    emsg = \"\"",
  "    open(joinpath(dir, \"case-$i.out\"), \"w\") do io",
  "        redirect_stdout(io) do",
  "            try",
  "                Base.include_string(m, src, \"case-$i.jl\")",
  "            catch e",
  "                while e isa LoadError",
  "                    e = e.error",
  "                end",
  "                etype = string(nameof(typeof(e)))",
  "                emsg = sprint(showerror, e)",
  "            end",
  "            flush(stdout)",
  "        end",
  "    end",
  "    write(joinpath(dir, \"case-$i.etype\"), etype)",
  "    write(joinpath(dir, \"case-$i.emsg\"), emsg)",
  "end"
)

jle_block_re <- "````\\{\\.weft-values\\}\n([^\n]*)\n````"

jle_parse_blocks <- function(text) {
  m <- regmatches(text, gregexpr(jle_block_re, text, perl = TRUE))[[1]]
  texts <- sub(jle_block_re, "\\1", m, perl = TRUE)
  list(texts = texts, blocks = lapply(texts, function(t) jsonlite::fromJSON(t, simplifyVector = FALSE)))
}

# codes: a character vector, one Julia snippet per element. Each runs in a fresh module, after the
# environment variables that the writers read (WEFT_RUN, the Quarto document variables) are cleared.
jle_cases <- function(codes, env = character()) {
  skip_if_no_julia_engine()
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  dir <- normalizePath(dir, winslash = "/")
  for (i in seq_along(codes)) writeLines(codes[[i]], file.path(dir, sprintf("case-%d.jl", i)), useBytes = TRUE)
  drv <- file.path(dir, "driver.jl")
  writeLines(jle_driver_source, drv)
  vars <- c(JULIA_LOAD_PATH = jle_load_path(), WEFT_RUN = NA, QUARTO_DOCUMENT_PATH = NA,
            QUARTO_DOCUMENT_FILE = NA, WEFT_DRAFT = NA, WEFT_COLLECT = NA)
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  errf <- file.path(dir, "stderr.txt")
  st <- suppressWarnings(system2(Sys.which("julia"),
                                 c("--startup-file=no", shQuote(drv), shQuote(dir), length(codes)),
                                 stdout = FALSE, stderr = errf))
  last <- file.path(dir, sprintf("case-%d.emsg", length(codes)))
  testthat::expect(file.exists(last),
                   paste("the julia driver ran:", paste(utils::tail(readLines(errf, warn = FALSE), 8), collapse = " / ")))
  lapply(seq_along(codes), function(i) {
    rd <- function(ext) {
      p <- file.path(dir, sprintf("case-%d.%s", i, ext))
      if (file.exists(p)) paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n") else NA_character_
    }
    out <- if (file.exists(file.path(dir, sprintf("case-%d.out", i)))) {
      paste(readChar(file.path(dir, sprintf("case-%d.out", i)), 1e7, useBytes = TRUE), collapse = "")
    } else NA_character_
    Encoding(out) <- "UTF-8"
    pb <- if (is.na(out)) list(texts = character(), blocks = list()) else jle_parse_blocks(out)
    list(out = out, etype = rd("etype"), emsg = rd("emsg"), block_text = pb$texts, blocks = pb$blocks,
         stderr = paste(readLines(errf, warn = FALSE), collapse = "\n"))
  })
}

# ---- Quarto projects on the julia engine -------------------------------------------------------------

# files: a named list of lines. With filter = TRUE the project is set up by weft::use_quarto() (its
# messages dropped). The project's _quarto.yml names the engine and the julia worker's environment.
jle_project <- function(files, filter = TRUE) {
  # the project lives until the file is done: the julia server keeps the folder of the first render as its
  # working folder (a deleted one makes later renders fail with "startpath must be non-empty")
  dir <- withr::local_tempdir(.local_envir = tryCatch(testthat::teardown_env(), error = function(e) parent.frame()))
  dir <- normalizePath(dir, winslash = "/")
  writeLines(c("project:", "  type: default",
               "engine: julia",
               "julia:",
               sprintf("  env: [\"JULIA_LOAD_PATH=%s\"]", jle_load_path()),
               "format: html"), file.path(dir, "_quarto.yml"))
  put_files(dir, files)
  if (filter) suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  dir
}

# `quarto render <args>` in dir, with the package under test and a private Jupyter-free environment. The
# run id is unset unless `env` gives WEFT_RUN. Returns list(status, stdout, stderr, log). The first render
# of a file starts from a fresh server.
jle_render <- function(dir, args = character(), env = character()) {
  skip_if_no_julia_engine()
  if (!isTRUE(.jle$killed)) {
    jle_kill()
    .jle$killed <- TRUE
  }
  vars <- c(NO_COLOR = "1", WEFT_DRAFT = NA, WEFT_COLLECT = NA, WEFT_RUN = NA, JULIA_LOAD_PATH = jle_load_path())
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

jle_read <- function(dir, rel) {
  p <- file.path(dir, rel)
  if (!file.exists(p)) return("")
  paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

jle_unesc <- function(x) {
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  gsub("&amp;", "&", x, fixed = TRUE)
}

# The cells of a julia-engine HTML page by label. Measured: a labelled cell is a div.cell whose id is the label, or
# `cell-` and the label when it has exactly one output (as N89 says); the `cell-` is removed here.
jle_cells <- function(html) {
  starts <- gregexpr("<div id=\"[^\"]+\" class=\"cell[ \"]", html)[[1]]
  if (identical(starts[1], -1L)) return(list())
  ids <- sub("^cell-", "", sub("^<div id=\"([^\"]+)\".*$", "\\1", regmatches(html, gregexpr("<div id=\"[^\"]+\" class=\"cell[ \"]", html))[[1]]))
  ends <- c(starts[-1] - 1L, nchar(html))
  stats::setNames(substring(html, starts, ends), ids)
}

# The weft-values blocks Pandoc made of the carrier in a render with no filter, in document order: a
# list of parsed JSON objects, and (as `text`) the raw JSON text.
jle_html_blocks <- function(html) {
  m <- regmatches(html, gregexpr("(?s)<pre class=\"weft-values\"><code>(.*?)</code></pre>", html, perl = TRUE))[[1]]
  texts <- jle_unesc(sub("(?s)^<pre class=\"weft-values\"><code>(.*?)</code></pre>$", "\\1", m, perl = TRUE))
  list(texts = texts, blocks = lapply(texts, function(t) jsonlite::fromJSON(t, simplifyVector = FALSE)))
}

# the text of the stdout output of cells of a bare render, in order
jle_stdout_of <- function(html) {
  m <- regmatches(html, gregexpr("(?s)<div class=\"cell-output cell-output-stdout\">\n<pre><code>(.*?)</code></pre>", html, perl = TRUE))[[1]]
  jle_unesc(sub("(?s)^.*?<pre><code>(.*?)</code></pre>$", "\\1", m, perl = TRUE))
}

# the 1-based line of the first line of `lines` that starts with / equals / contains `x`
jle_line_of <- function(lines, x) grep(x, lines, fixed = TRUE)[1]

# the i-th parsed block of a result that has `blocks`, or an empty list when there is none (so that an
# expectation on it fails cleanly instead of erroring)
blk <- function(x, i) if (length(x$blocks) >= i) x$blocks[[i]] else list()

# names() that is character(0) for NULL
nms <- function(x) names(x) %||% character()
`%||%` <- function(a, b) if (is.null(a)) b else a
