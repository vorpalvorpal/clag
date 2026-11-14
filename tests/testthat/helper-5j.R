# Helpers for the stage 5J tests (Julia as a guest of knitr, section J of
# dev/design-5.md: 5J-a reading Julia values, 5J-b Julia conditions and
# reads). They sit beside helper-5.R and reuse its msg5() and
# expect_refused5(); nothing here edits other helpers, and nothing here reads
# R/, inst/python/ or inst/julia/.
#
# ---- THE INTERFACE THE TESTS FIX (internal; section J leaves it open) -------
#
# Exported (J2, J8):
#   jl_value(...)         each argument one non-empty string, a step of a path.
#                         Returns the R form (J1, J6) or raises a classed
#                         error. Its subject `{S}` in a message is the call as
#                         R deparses it: jl_value("a", "b").
# Internal, tested because the amendment of 13 Nov makes the typed record the
# reader's product and puts the refusals in one function:
#   weft:::jl_record(name)
#       The Julia-side counterpart of weft:::guest_record() (section J names
#       none, so this name is fixed here). `name` is ONE string, a global of
#       Julia's Main. It returns the typed record of the value, with the same
#       fields as guest_record() of helper-5.R:
#         t    "bool" "int" "float" "string" "date" "list" "missing" "error"
#              (no "decimal": Julia has none)
#         v    bool: TRUE or FALSE; int: the digit string ("9007199254740993",
#              "-7"); float: repr(Float64(x)) ("0.1", "0.10000000149011612");
#              string: the text; date: ISO "2026-11-13"; list: a list of
#              scalar records in order, as read; missing and error: not
#              constrained
#         of   lists only: the kind of the elements after J6's promotion
#              ("int" "float" "bool" "string" "date"), or "missing" for an
#              empty list and for a list whose elements are all missing
#         keys lists only: the field names of a NamedTuple as a character
#              vector; NULL for any other list
#         why  missing only: a single non-empty string
#       jl_record() works from Julia's value with no conversion by JuliaCall.
#       It is tested on values that are not a scalar `missing` in this
#       process (that one is read in a child process, J14). A refusal's text
#       is tested through jl_value(), not through the record: how the record
#       carries Julia's type to weft:::record_value() is the implementer's.
#   weft:::record_value(rec, S)  is 5b's, unchanged.
# Options: options(weft.juliacall = FALSE) is the seam of G4b/J12: weft behaves
#   as if JuliaCall were not installed.
#
# ---- helpers here -----------------------------------------------------------
#   skip_if_no_julia()    skips ONLY when JuliaCall is not installed or cannot
#                         start Julia (the first call starts it, once per
#                         process; later calls cost nothing), or when the
#                         environment variable WEFT_SKIP_JULIA is set (a
#                         switch for a run that should not start Julia)
#   jl_set(...)           runs Julia lines: name = "expr" becomes `name = expr;`
#                         an unnamed string is run as it is, with a `;` added.
#                         Every line ends with `;` so JuliaCall converts no
#                         value back (a scalar `missing` would crash R). The
#                         first call in a process runs `using Dates;`.
#   jl_fixtures()         defines the tests' own struct T_j5_S and module
#                         T_j5_Mod, once per process
#   jl_type(name)         string(typeof(name)) as Julia says it, which is what
#                         J7 means by {type}
#   jlv(...)              a call to jl_value("a", "b") written out literally,
#                         so that its subject is jl_value("a", "b")
#   jm1() ... jm17()      the texts of J7, built from their parts
#   k5j(lines, jl, ...)   one document knitted in this process, with Julia
#                         chunks; see its header
#   k5j_cases(cases, ...) k5j() of tagged one-paragraph cases
#   k5j_fresh(script)     one fresh vanilla Rscript running `script` with the
#                         development weft visible; the script has `.out`, the
#                         path it saves to with saveRDS(), and `knit1()`,
#                         which knits one document and returns its result.
#                         Returns what the script saved (list() when it saved
#                         nothing), with attributes status (the exit status,
#                         0 when it ran to the end), stdout and stderr.
#
# Julia's state is shared by every test in one process: each test uses names
# of its own (t_j5_...), and the missing-name tests use names never set. At
# most one k5j_fresh() call is made in a test file, except where a file says
# otherwise: test-julia-prose.R makes two (one starts no Julia).

.w5j <- new.env()

# ---- skips -------------------------------------------------------------------

# Julia is skipped wherever WEFT_SKIP_JULIA is set. One helper, used by both Julia skips.
skip_if_julia_disabled <- function() {
  testthat::skip_if(nzchar(Sys.getenv("WEFT_SKIP_JULIA")),
                    "WEFT_SKIP_JULIA is set")
}

skip_if_no_julia <- function() {
  skip_if_julia_disabled()
  testthat::skip_if_not_installed("JuliaCall")
  if (is.null(.w5j$started)) {
    .w5j$started <- tryCatch({
      # as weft does before it starts Julia: Julia's own libunwind, on Linux (finding 22)
      weft:::jl_preload_unwind()
      JuliaCall::julia_setup(installJulia = FALSE, install = FALSE,
                             verbose = FALSE)
      TRUE
    }, error = function(e) strsplit(conditionMessage(e), "\n", fixed = TRUE)[[1]][1])
  }
  if (!isTRUE(.w5j$started)) {
    testthat::skip(paste0("JuliaCall could not start Julia: ", .w5j$started))
  }
  invisible(TRUE)
}

# ---- Julia from R --------------------------------------------------------------

jl_set <- function(...) {
  skip_if_no_julia()
  x <- c(...)
  nm <- names(x)
  if (is.null(nm)) nm <- rep("", length(x))
  lines <- ifelse(nzchar(nm), paste0(nm, " = ", x), x)
  lines <- ifelse(endsWith(trimws(lines), ";"), lines, paste0(lines, ";"))
  if (!isTRUE(.w5j$dates)) {
    JuliaCall::julia_command("using Dates;")
    .w5j$dates <- TRUE
  }
  for (l in lines) JuliaCall::julia_command(l)
  invisible(NULL)
}

jl_fixtures <- function() {
  skip_if_no_julia()
  if (!isTRUE(.w5j$fixtures)) {
    jl_set(
      "struct T_j5_S\n  depth::Float64\n  cfg::Dict{String, Int64}\nend",
      "module T_j5_Mod\n  depth = 4.5\nend")
    .w5j$fixtures <- TRUE
  }
  invisible(NULL)
}

jl_type <- function(name) {
  JuliaCall::julia_eval(sprintf("string(typeof(%s))", name))
}

jlv <- function(...) {
  call <- as.call(c(list(as.name("jl_value")), list(...)))
  eval(call, parent.frame())
}

# ---- the texts of J7 (S is the subject, backticks included) ---------------------

pmj <- "±"

jm1 <- function(S, type, digits) {
  sprintf(paste0("%s is the Julia %s %s, beyond ", pmj, "2^53, where R cannot hold a whole number exactly. ",
                 "Scale it in Julia, or bind string() of it and print the text (rule 2.12.5)."), S, type, digits)
}
jm2 <- function(S, type) {
  sprintf(paste0("%s is a Julia %s, which R cannot hold exactly. ",
                 "Convert it in Julia with Float64(), and round it there if it should print as written (rule 1.11.2)."),
          S, type)
}
jm3 <- function(S, type, kinds) {
  sprintf(paste0("%s is a Julia %s whose elements are of more than one kind (%s); ",
                 "weft reads a list whose elements are all of one kind (rule 1.11.4)."), S, type, kinds)
}
jm4 <- function(S, type, inner) {
  sprintf("%s is a Julia %s that holds a %s; weft reads a flat list (rule 1.11.4).", S, type, inner)
}
jm5 <- function(S, type) {
  sprintf(paste0("%s is a Julia %s, which holds a date and a time; weft reads a date. ",
                 "Convert it in Julia, in the time zone you mean, with Dates.Date() (rule 1.11.6)."), S, type)
}
jm6 <- function(S, type) {
  sprintf(paste0("%s is a Julia %s, which weft does not read as a value. ",
                 "Bind a Bool, an integer, a float, a String, a Date, or a vector of one of these (rule 1.11.1)."),
          S, type)
}
jm7 <- function(S, type) {
  sprintf("%s is a Julia %s, which has no order. Bind a NamedTuple, or a sorted vector, in a Julia chunk (rule 1.11.4).",
          S, type)
}
jm9 <- function(S, d) {
  sprintf("%s is a Julia array of %d dimensions; weft reads a flat list (rule 1.11.4).", S, d)
}
# read is the read as R deparses it, WITHOUT backticks
jm10 <- function(read, type) {
  sprintf("`%s` is a Julia %s; an `if` condition must be a Bool (rule 1.11.8).", read, type)
}
jm11n <- function(read, type) {
  sprintf("`%s` is a Julia %s; an `n` governor must be a number (rule 1.11.9).", read, type)
}
jm11s <- function(read, type) {
  sprintf("`%s` is a Julia %s; a `sign` governor must be a number (rule 1.11.9).", read, type)
}
jm12 <- function(read, type) {
  sprintf("`%s` is a Julia %s; a `list` span needs a list (rule 1.11.10).", read, type)
}
jm13 <- function(read, name) {
  sprintf(paste0("`%s`: Julia's Main module has no name `%s`. ",
                 "Run the Julia chunk that sets it before this point (rule 2.12.6)."), read, name)
}
jm14 <- function(read, prefix, name) {
  sprintf("`%s`: the Julia value `%s` has no field or key `%s` (rule 2.12.6).", read, prefix, name)
}
jm15 <- function(read) {
  sprintf(paste0("`%s` reads a Julia value, and the R package JuliaCall is not installed. ",
                 "Install it with install.packages(\"JuliaCall\") (rule 2.12.6)."), read)
}
jm16 <- function(read, reason = "Julia is not found.") {
  sprintf("`%s` reads a Julia value, and JuliaCall could not start Julia: %s (rule 2.12.6).", read, reason)
}
jm17 <- function(S, type) {
  sprintf("%s is a Julia %s that is not valid UTF-8 text (rule 1.11.5).", S, type)
}
m_args_j <- "jl_value() takes names as strings: jl_value(\"n\")."

# ---- documents knitted in this process ------------------------------------------
#
# k5j(lines, jl = NULL, files = list(), weft_yml = NULL, draft = FALSE,
#     env = NULL, setup = TRUE, dir = NULL)
#   lines     the body of doc.Rmd (after the set-up chunk and the Julia chunk)
#   jl        Julia code lines, put in a first `julia` chunk with include=FALSE
#             (so it prints nothing); end each line with `;`
#   files     more files for the project: a named list of character vectors
#   weft_yml  lines of a _weft.yml, or NULL (then the project is not set up
#             and no ledger or condition log file is written)
#   draft     WEFT_DRAFT=1: nothing fails, markers show in the output (9.4.2)
#   setup     FALSE leaves the `weft::weft_setup()` line out (a knit without
#             weft)
# The set-up chunk sets knitr's chunk option error = FALSE, as
# rmarkdown::render() does: knitr::knit() alone prints a chunk error and goes
# on, which is not what a render does.
#   dir       an existing project folder to knit in again (the cache test)
#   `@DIR@` in `lines`, `jl` and `files` is replaced by the project folder.
# Returns list(
#   text, md     the knit output (markdown, not run through Pandoc)
#   failed       TRUE when knitr::knit() stopped with an error
#   error        NULL or the condition; message / class of it below
#   message      msg5() of the error ("" when none); class: its classes
#   knit         weft:::last_knit() after the knit
#   failures     last_knit()$failures (zero rows when none)
#   conditions   last_knit()$conditions
#   cond         last_knit()$condition_log
#   reads        last_knit()$reads (the ledger header's reads)
#   offset       lines above `lines` in the file (line k of `lines` is
#                line offset + k)
#   dir, input   where it was written
#   log          messages and warnings seen during the knit
#   searched     "package:JuliaCall" %in% search() at the end of the knit
# )
k5j <- function(lines, jl = NULL, files = list(), weft_yml = NULL,
                draft = FALSE, env = NULL, setup = TRUE, dir = NULL) {
  skip_if_no_julia()
  if (is.null(dir)) {
    dir <- tempfile("weft-5j-")
    dir.create(dir)
  }
  dir <- normalizePath(dir)
  sub_dir <- function(x) gsub("@DIR@", dir, x, fixed = TRUE)
  hdr <- c("---", "title: \"t\"", "---", "",
           "```{r setup, include=FALSE}",
           "knitr::opts_chunk$set(error = FALSE)",
           if (setup) "weft::weft_setup()", "```", "")
  jlc <- if (!is.null(jl)) c("```{julia, include=FALSE}", sub_dir(jl), "```", "")
  body <- unlist(strsplit(paste(sub_dir(lines), collapse = "\n"), "\n", fixed = TRUE))
  doc <- c(hdr, jlc, body)
  input <- file.path(dir, "doc.Rmd")
  con <- file(input, "wb")
  writeBin(charToRaw(enc2utf8(paste0(paste(doc, collapse = "\n"), "\n"))), con)
  close(con)
  if (!is.null(weft_yml)) writeLines(weft_yml, file.path(dir, "_weft.yml"))
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(sub_dir(files[[f]]), p, useBytes = TRUE)
  }
  vars <- c(WEFT_DRAFT = if (draft) "1" else NA_character_)
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  withr::local_dir(dir)
  withr::defer(weft_restore_knitr())
  logv <- character()
  err <- NULL
  withCallingHandlers(
    tryCatch(
      knitr::knit("doc.Rmd", "doc.md", quiet = TRUE,
                  envir = new.env(parent = globalenv())),
      error = function(e) err <<- e
    ),
    message = function(m) {
      logv <<- c(logv, conditionMessage(m)); invokeRestart("muffleMessage")
    },
    warning = function(w) {
      logv <<- c(logv, paste0("Warning: ", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )
  searched <- "package:JuliaCall" %in% search()
  kn <- tryCatch(weft:::last_knit(), error = function(e) NULL)
  out <- file.path(dir, "doc.md")
  text <- if (file.exists(out)) {
    x <- readLines(out, warn = FALSE, encoding = "UTF-8")
    x <- sub("[ \t]+$", "", x)
    while (length(x) && !nzchar(trimws(x[length(x)]))) x <- x[-length(x)]
    x
  } else character()
  list(text = text, md = paste(text, collapse = "\n"),
       failed = !is.null(err), error = err,
       message = if (is.null(err)) "" else msg5(err),
       class = if (is.null(err)) character() else class(err),
       knit = kn,
       failures = if (is.null(kn)) NULL else kn$failures,
       conditions = if (is.null(kn)) NULL else kn$conditions,
       cond = if (is.null(kn)) NULL else kn$condition_log,
       reads = if (is.null(kn)) NULL else kn$reads,
       offset = length(hdr) + length(jlc),
       dir = dir, input = input, log = logv, searched = searched)
}

# k5j() of tagged cases: `cases` is a named character vector; each element is
# one paragraph, written as "<name> <source>"; `before` is lines (a chunk, say)
# put ahead of the cases. Adds to the result:
#   at       the file line of each case's first line (named by tag)
#   line(t)  the output line that starts with the tag
#   fail(t)  the rows of `failures` at that case's line
#   marker(t, kind)  "<<weft: kind, line N>>" for that case
k5j_cases <- function(cases, before = NULL, ...) {
  body <- before
  rel <- integer(length(cases))
  for (i in seq_along(cases)) {
    rel[i] <- length(body) + 1L
    body <- c(body, paste(names(cases)[i], cases[[i]]), "")
  }
  res <- k5j(body, ...)
  at <- res$offset + rel
  names(at) <- names(cases)
  res$at <- at
  res$line <- function(tag) {
    hit <- grep(paste0("^", tag, " "), res$text, value = TRUE)
    if (length(hit)) hit[1] else NA_character_
  }
  res$fail <- function(tag) {
    f <- res$failures
    if (is.null(f)) return(NULL)
    f[f$line == at[[tag]], , drop = FALSE]
  }
  res$marker <- function(tag, kind) {
    sprintf("<<weft: %s, line %d>>", kind, at[[tag]])
  }
  res
}

# the output line is `<tag> <what> x`
expect_prints_j <- function(res, tag, what) {
  testthat::expect_identical(res$line(tag), paste(tag, what, "x"))
  testthat::expect_equal(nrow(res$fail(tag)), 0L, label = paste(tag, "has no failure"))
}

# a collected failure: the marker, the kind and each exact message
expect_collected_j <- function(res, tag, kind, details) {
  testthat::expect_identical(res$line(tag), paste(tag, res$marker(tag, kind), "x"), label = tag)
  f <- res$fail(tag)
  testthat::expect_equal(nrow(f), length(details), label = paste(tag, "failures"))
  testthat::expect_true(all(f$kind == kind), label = paste(tag, "kind"))
  testthat::expect_setequal(vapply(f$detail, msg5, ""), details)
}

# a missing value reaching a formatter or a governor: "no value" by 1.3.4, and
# not a read that failed (whose detail starts "error evaluating")
expect_no_value_j <- function(res, tag) {
  testthat::expect_identical(res$line(tag), paste(tag, res$marker(tag, "no value"), "x"), label = tag)
  f <- res$fail(tag)
  testthat::expect_equal(nrow(f), 1L, label = paste(tag, "failures"))
  testthat::expect_identical(f$kind, "no value")
  testthat::expect_false(any(grepl("^error evaluating", vapply(f$detail, msg5, ""))),
                         label = paste(tag, "is a failed read"))
}

# ---- one document, knitted in a child process ----------------------------------
#
# knit1() is the body a child script uses: it writes doc.Rmd (the set-up chunk
# first, then `lines`) and files, knits it in a project folder of its own, and
# returns list(text, failed, message, failures, reads, cond, dir). draft = TRUE
# is WEFT_DRAFT=1. It is written as a function here and put into the script
# with deparse(), so it must only use base R, knitr and weft.
k5j_knit1 <- function(lines, files = list(), weft_yml = NULL, draft = FALSE) {
  dir <- tempfile("weft-5j-child-")
  dir.create(dir)
  dir <- normalizePath(dir)
  doc <- c("---", "title: \"t\"", "---", "", "```{r setup, include=FALSE}",
           "knitr::opts_chunk$set(error = FALSE)",
           "weft::weft_setup()", "```", "", lines)
  writeLines(doc, file.path(dir, "doc.Rmd"), useBytes = TRUE)
  if (!is.null(weft_yml)) writeLines(weft_yml, file.path(dir, "_weft.yml"))
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  old <- setwd(dir)
  on.exit({
    setwd(old)
    knitr::knit_hooks$restore()
    knitr::opts_hooks$restore()
    knitr::opts_knit$restore()
    knitr::opts_chunk$restore()
  })
  if (draft) Sys.setenv(WEFT_DRAFT = "1") else Sys.unsetenv("WEFT_DRAFT")
  err <- NULL
  tryCatch(knitr::knit("doc.Rmd", "doc.md", quiet = TRUE,
                       envir = new.env(parent = globalenv())),
           error = function(e) err <<- e)
  text <- if (file.exists("doc.md")) {
    readLines("doc.md", warn = FALSE, encoding = "UTF-8")
  } else character()
  kn <- tryCatch(weft:::last_knit(), error = function(e) NULL)
  list(text = text, failed = !is.null(err),
       message = if (is.null(err)) "" else conditionMessage(err),
       failures = if (is.null(kn)) NULL else kn$failures,
       reads = if (is.null(kn)) NULL else kn$reads,
       cond = if (is.null(kn)) NULL else kn$condition_log,
       dir = dir)
}

k5j_fresh <- function(script, env = NULL) {
  testthat::skip_if_not_installed("JuliaCall")
  dir <- tempfile("weft-5j-fresh-")
  dir.create(dir)
  out <- file.path(dir, "saved.rds")
  file_script <- file.path(dir, "script.R")
  # some scripts start Julia with JuliaCall::julia_setup(), not through weft, so
  # Julia's own libunwind is loaded first, as weft does (finding 22); this
  # loads neither JuliaCall nor Julia
  writeLines(c(
    sprintf(".out <- %s", deparse(out)),
    "try(weft:::jl_preload_unwind(), silent = TRUE)",
    paste("knit1 <-", paste(deparse(k5j_knit1), collapse = "\n")),
    script), file_script)
  lib <- weft_test_lib()
  vars <- c(R_LIBS = paste(c(if (nzchar(lib)) lib, .libPaths()), collapse = .Platform$path.sep),
            R_USER_CACHE_DIR = file.path(dir, "cache"))
  for (n in names(env)) vars[[n]] <- env[[n]]
  errf <- file.path(dir, "stderr.txt")
  stdout <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(file_script)),
    stdout = TRUE, stderr = errf,
    env = sprintf("%s=%s", names(vars), unname(vars))))
  status <- attr(stdout, "status")
  saved <- if (file.exists(out)) readRDS(out) else list()
  structure(saved,
            status = if (is.null(status)) 0L else status,
            stdout = as.character(stdout),
            stderr = if (file.exists(errf)) readLines(errf, warn = FALSE) else character())
}
