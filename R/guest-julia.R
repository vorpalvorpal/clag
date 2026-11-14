# Julia as a guest of knitr: reading Julia values (rules 1.11, 2.12.15 to
# 2.12.21, section J of dev/design-5.md).
#
# A Julia value is read by Julia's own function, WeftGuest.read()
# (inst/julia/WeftGuest.jl), which runs inside Julia and hands R one string: a
# typed record as JSON text. JuliaCall's conversion never sees the value (a
# scalar `missing` ends R when it does). The record is the one of
# guest_record() in R/guest.R, with the Julia type name added to each; ONE
# function there, record_value(), turns it into an R value and holds the
# refusals that depend on what R can hold.

# ---- starting Julia, and registering weft's module -----------------------------------

# JuliaCall is used only when a read, or a Julia chunk, needs it. `options(
# weft.juliacall = FALSE)` makes weft behave as if it were not installed.
jl_available <- function() {
  !isFALSE(getOption("weft.juliacall")) && requireNamespace("JuliaCall", quietly = TRUE)
}

# Is weft's Julia module defined in a Julia running in this R session? Never
# starts Julia and never loads JuliaCall.
julia_running <- function() {
  isTRUE(weft_env$jl_registered) && "JuliaCall" %in% loadedNamespaces()
}

# Start Julia if it is not running and define module `WeftGuest` once per R
# session (J16). `read` is the read as R deparses it, for the messages; `home`
# is the folder of Julia's binaries when the chunk names one. weft never
# installs Julia or a Julia package.
julia_ensure <- function(read, home = NULL) {
  if (!jl_available()) {
    guest_abort(sprintf(paste0(
      "`%s` reads a Julia value, and the R package JuliaCall is not installed. ",
      "Install it with install.packages(\"JuliaCall\") (rule 2.12.6)."), read))
  }
  if (julia_running()) return(invisible(TRUE))
  jl_preload_unwind(home)
  err <- tryCatch({
    JuliaCall::julia_setup(JULIA_HOME = home, installJulia = FALSE, install = FALSE, verbose = FALSE)
    jl_register()
    NULL
  }, error = function(e) e)
  if (!is.null(err)) {
    why <- trimws(strsplit(cli::ansi_strip(conditionMessage(err)), "\n", fixed = TRUE)[[1L]][1L])
    guest_abort(sprintf("`%s` reads a Julia value, and JuliaCall could not start Julia: %s (rule 2.12.6).",
                        read, why))
  }
  invisible(TRUE)
}

# On Linux, load Julia's own libunwind into R before Julia starts, so that Julia
# uses it rather than the system's (dev/open-findings.md, finding 22). R's
# start-up script puts /usr/lib/x86_64-linux-gnu (or the like) on
# LD_LIBRARY_PATH, which the loader searches before libjulia-internal's RUNPATH,
# so where the system has a libunwind.so.8 Julia gets that one, and it
# segfaults R the first time Julia records the backtrace of an exception, even
# one caught at once. JuliaCall 0.17.6 (CRAN) does not guard against it; its
# development version does the same as this (JuliaCall issue 238). `home` is
# the folder of Julia's binaries, as julia_setup() takes it, or NULL. Does
# nothing elsewhere, or once a libjulia is loaded, or when the library cannot
# be found; never fails.
jl_preload_unwind <- function(home = NULL) {
  if (!identical(Sys.info()[["sysname"]], "Linux")) return(invisible(FALSE))
  loaded <- vapply(getLoadedDLLs(), function(d) d[["path"]], "")
  if (any(grepl("libjulia", basename(loaded), fixed = TRUE))) return(invisible(FALSE))
  lib <- tryCatch(jl_unwind_path(home), error = function(e) NULL)
  if (is.null(lib)) return(invisible(FALSE))
  if (lib %in% loaded) return(invisible(TRUE))
  ok <- tryCatch({
    dyn.load(lib, local = FALSE, now = TRUE)
    TRUE
  }, error = function(e) FALSE)
  invisible(ok)
}

# The path of the libunwind that ships with the Julia JuliaCall would start, or
# NULL. The folder of Julia's binaries is `home`, else as JuliaCall looks for
# it: the option or variable JULIA_HOME, else the `julia` on PATH (a symlink is
# followed; a launcher such as juliaup's is asked for Sys.BINDIR).
jl_unwind_path <- function(home = NULL) {
  if (is.null(home)) home <- getOption("JULIA_HOME")
  if (is.null(home) && nzchar(Sys.getenv("JULIA_HOME"))) home <- Sys.getenv("JULIA_HOME")
  exe <- if (!is.null(home)) file.path(home, "julia") else unname(Sys.which("julia"))
  if (!nzchar(exe) || !file.exists(exe)) return(NULL)
  find <- function(bindir) {
    hit <- Sys.glob(file.path(bindir, "..", "lib", "julia", "libunwind.so*"))
    if (length(hit)) normalizePath(hit[1L]) else NULL
  }
  hit <- find(dirname(normalizePath(exe)))
  if (!is.null(hit)) return(hit)
  out <- suppressWarnings(system2(exe, c("--startup-file=no", "-e", shQuote("print(Sys.BINDIR)")),
                                  stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(out, "status")) || !length(out)) return(NULL)
  find(out[length(out)])
}

# A child process that may start Julia (`quarto render` of a project on the julia engine) inherits R's
# LD_LIBRARY_PATH, so a plain `julia` there loads the system libunwind too and segfaults the same way
# (finding 22). The variables to set for such a child: on Linux, LD_LIBRARY_PATH without the system's
# own library folders (/usr/lib/<triplet>, /lib, /usr/lib64 and the like), which the loader searches
# anyway, after the RUNPATH of Julia's libraries; elsewhere, or when there is nothing to take out,
# none (a named character vector for withr::with_envvar()).
julia_child_env <- function(x = Sys.getenv("LD_LIBRARY_PATH")) {
  if (!identical(Sys.info()[["sysname"]], "Linux") || !nzchar(x)) return(character())
  parts <- strsplit(x, ":", fixed = TRUE)[[1L]]
  sys <- grepl("^(/usr)?/lib(64|32)?(/[A-Za-z0-9_]+-linux-[A-Za-z0-9_]+)?/*$", parts)
  if (!any(sys)) return(character())
  c(LD_LIBRARY_PATH = paste(parts[nzchar(parts) & !sys], collapse = ":"))
}

# Define `WeftGuest` unless a Julia of this process has it already.
jl_register <- function() {
  have <- isTRUE(JuliaCall::julia_eval("isdefined(Main, :WeftGuest)"))
  if (!have) {
    JuliaCall::julia_source(system.file("julia", "WeftGuest.jl", package = "weft"))
  }
  # the logger and the include record, once per Julia (J3, J4)
  JuliaCall::julia_call("WeftGuest.install")
  # `using Weft` loads the package that ships with weft, with nothing to install (N60)
  JuliaCall::julia_call("WeftGuest.add_load_path", system.file("julia", package = "weft"))
  weft_env$jl_registered <- TRUE
  invisible()
}

# Called on the first chunk of a knit whose engine is `julia` (J16): start Julia
# as the engine would, and register. A failure is the engine's to report.
julia_chunk_start <- function(options) {
  if (isFALSE(options$eval) || !jl_available()) return(invisible())
  if (!julia_running()) {
    home <- options[["engine.path"]]
    if (is.list(home)) home <- home[["julia"]]
    if (!is.character(home)) home <- NULL
    tryCatch(julia_ensure("a Julia chunk", home), error = function(e) NULL)
  }
  if (julia_running()) {
    # Weft records claims for R from here (N56), and a chunk that stops on one
    # still hands them over
    julia_mark_knitr()
    julia_wrap_engine()
  }
  invisible()
}

# Tell Julia's Weft that a knit is running, and whether claims are collected
# in it (R decides, GN2a, GN3): called before each Julia chunk.
julia_mark_knitr <- function() {
  collect <- tryCatch(claim_collects_in_chunk(), error = function(e) FALSE)
  tryCatch(JuliaCall::julia_call("WeftGuest.mark_knitr", isTRUE(collect)), error = function(e) NULL)
  invisible()
}

# Wrap the knitr engine that runs Julia chunks, once: when a chunk stops with an
# error (a failed @claim under stop throws, J18), the claims it noted are added to
# the knit's failures before the error goes on (N56). The error then goes on as
# E31 when claims were collected in this knit (GN8b), else as itself. The claims
# are drained first, so that the count includes this chunk's own.
julia_wrap_engine <- function() {
  cur <- knitr::knit_engines$get("julia")
  if (!is.function(cur) || isTRUE(attr(cur, "weft"))) return(invisible())
  new <- function(options) {
    tryCatch(cur(options), error = function(e) {
      s <- active_state()
      if (is.null(s)) stop(e)
      guest_drain_guard(julia_take_claims(s, options$label))
      stop(wrap_collected_error(s, e))
    })
  }
  attr(new, "weft") <- TRUE
  knitr::knit_engines$set(julia = new)
  invisible()
}

# Wrap knitr's Python engine once, as julia_wrap_engine() does: an error that
# comes out of it (a chunk without `error: true`) goes on as E31 when claims
# were collected in this knit before it (GN8a), else as itself.
python_wrap_engine <- function() {
  cur <- knitr::knit_engines$get("python")
  if (!is.function(cur) || isTRUE(attr(cur, "weft"))) return(invisible())
  new <- function(options) {
    tryCatch(cur(options), error = function(e) {
      s <- active_state()
      if (is.null(s)) stop(e)
      stop(wrap_collected_error(s, e))
    })
  }
  attr(new, "weft") <- TRUE
  knitr::knit_engines$set(python = new)
  invisible()
}

# The failed and warned claims Julia's Weft noted since the last call, added to
# the knit's failures and warned checks at chunk `label`. Starts no Julia.
julia_take_claims <- function(s, label) {
  if (!julia_running()) return(invisible())
  for (r in guest_drain_json(JuliaCall::julia_call("WeftGuest.drain_claims"), "the Julia claims drain")) {
    guest_claim_record(s, as.character(r[[1L]]), as.character(r[[2L]]), as.character(r[[3L]]), label)
  }
  invisible()
}

# The records Julia's put() and @put handed over since the last call (N70), joined to the knit's waiting
# names as weft_put()'s are. Starts no Julia.
julia_take_puts <- function(s) {
  if (!julia_running()) return(invisible())
  pairs <- guest_drain_json(JuliaCall::julia_call("WeftGuest.drain_puts"), "the Julia puts drain")
  if (!length(pairs)) return(invisible())
  jsons <- lapply(pairs, function(p) as.character(p[[2L]]))
  names(jsons) <- vapply(pairs, function(p) as.character(p[[1L]]), "")
  values_wait_json(s, jsons)
  invisible()
}

# ---- the record -----------------------------------------------------------------------

# The record of the value at a path from Julia's Main, or the refusal that it
# cannot be reached (JM13, JM14, JM15, JM16).
jl_fetch <- function(steps, read, prefixes) {
  julia_ensure(read)
  res <- tryCatch(guest_json(JuliaCall::julia_call("WeftGuest.read", as.list(steps))),
                  error = function(e) e)
  if (inherits(res, "error")) {
    guest_abort(sprintf("`%s`: Julia could not be asked for the value: %s (rule 2.12.6).",
                        read, trimws(strsplit(conditionMessage(res), "\n", fixed = TRUE)[[1L]][1L])))
  }
  if (identical(res[["t"]], "absent")) {
    at <- res[["at"]]
    if (at == 0L) {
      guest_abort(sprintf(paste0("`%s`: Julia's Main module has no name `%s`. ",
                                 "Run the Julia chunk that sets it before this point (rule 2.12.6)."),
                          read, steps[1L]))
    }
    guest_abort(sprintf("`%s`: the Julia value `%s` has no field or key `%s` (rule 2.12.6).",
                        read, prefixes[at], steps[at + 1L]))
  }
  norm_record(res)
}

# Read the path `steps` and return its R form. `fn` is the function as the
# author wrote it (`jl_value` or `weft::jl_value`), for the subject of a
# message. A read that is exactly a governor's expression has its kind noted
# (`track`), so that it can be judged before the R form is (J11).
jl_read <- function(steps, fn, track = FALSE) {
  ok <- length(steps) > 0L && all(vapply(steps, function(a) {
    is.character(a) && length(a) == 1L && !is.na(a) && nzchar(a)
  }, NA))
  if (!ok) weft_abort("jl_value() takes names as strings: jl_value(\"n\").", "weft_guest_arg_error")
  steps <- vapply(steps, function(a) a, "")
  mk <- function(st) deparse_read(as.call(c(list(fn), as.list(st))))
  read <- mk(steps)
  prefixes <- vapply(seq_along(steps), function(j) mk(steps[seq_len(j)]), "")
  rec <- jl_fetch(steps, read, prefixes)
  if (isTRUE(track)) {
    weft_env$guest_last <- list(kind = rec[["t"]], type = rec[["type"]], read = read, lang = "julia")
  }
  record_value(rec, paste0("`", read, "`"), lang = "julia")
}

# The function as the author wrote the call: `jl_value` or `weft::jl_value`.
jl_fn <- function(call) {
  f <- call[[1L]]
  if (identical(f, as.name("jl_value"))) return(f)
  if (is.call(f) && length(f) == 3L && as.character(f[[1L]]) %in% c("::", ":::") && is.symbol(f[[3L]]) &&
      identical(as.character(f[[3L]]), "jl_value")) return(f)
  as.name("jl_value")
}

#' Read a Julia value
#'
#' `jl_value()` reads a value that a Julia chunk made, in prose or in R code,
#' and checks it as weft checks every value that reaches prose (rules 1.11 and
#' 2.12.15). Each argument is one string, a step of a path: `jl_value("n")`
#' reads the global `n` of Julia's `Main`; `jl_value("cfg", "depth")` reads
#' `cfg`, then its key `depth` when `cfg` is a dictionary (a `String` key, else
#' the `Symbol` key), else its field `depth`. Only the last value is read.
#'
#' The value is read inside Julia from its type, never by JuliaCall's
#' conversion, which stops on a whole number beyond 2^31, hands a `UInt8` over
#' as a raw vector and ends R on a `missing`. A `Bool`, an integer, a float
#' (`Float16`, `Float32` and `Float64`, widened exactly), a string, a `Char`, a
#' `Symbol`, a `Dates.Date` and a vector or tuple of one of these (a
#' `NamedTuple` with names) are read. An integer beyond 2^53, a `Rational`, an
#' `Irrational`, a `BigFloat`, a `DateTime`, a dictionary, a set, a matrix and
#' anything else are refused with a `weft_guest_value_error` that says what to
#' do. `missing`, `nothing`, NaN and infinities are `NA`.
#'
#' In an attribute value the argument takes single quotes:
#' `{if="jl_value('ok')"}`. When Julia is not running, `jl_value()` starts it
#' with `JuliaCall::julia_setup()` and defines weft's one module, `WeftGuest`,
#' in Julia's `Main`. weft never installs Julia or a Julia package.
#'
#' @param ... One or more non-empty strings: the name in Julia's `Main`, then
#'   the keys or fields below it.
#' @return The R form of the value: a logical, integer or double, a character
#'   string, a `Date`, or an atomic vector of one of these for a list, named
#'   for a `NamedTuple`. A missing value is `NA`.
#' @examples
#' \dontrun{
#' # needs Julia, which takes a few seconds to start
#' JuliaCall::julia_setup()
#' JuliaCall::julia_command("depth = 3.14159;")
#' jl_value("depth")
#' }
#' @export
jl_value <- function(...) {
  jl_read(list(...), jl_fn(sys.call()), track = FALSE)
}

# The same, rewritten in place of a governor's one read (J11): `fn` is the
# function as written.
jl_value_tracked <- function(fn, ...) jl_read(list(...), fn, track = TRUE)

# The typed record of the global `name` of Main (internal; the tests read it).
jl_record <- function(name) {
  read <- deparse_read(call("jl_value", name))
  jl_fetch(name, read, read)
}

# ---- what Julia logged (J3) and what it included (J4) -----------------------------------

# The @warn and @error records Julia's logging received since the last call, each
# as list(class, text), and the note of them cleared. Starts no Julia.
julia_drain <- function() {
  if (!julia_running()) return(list())
  recs <- guest_drain_json(JuliaCall::julia_call("WeftGuest.drain"), "the Julia log drain")
  lapply(recs, function(r) list(class = as.character(r[[1L]]), text = as.character(r[[2L]])))
}

# The files Julia's include() loaded in this R session since weft registered,
# that lie in the project (J4), by path relative to `root`, with `/`. A file
# under a folder named site-packages, dist-packages, .venv, venv, renv, or one
# starting with a dot, is not one. Starts no Julia.
julia_project_files <- function(root) {
  if (!julia_running()) return(character())
  paths <- as.character(unlist(guest_drain_json(JuliaCall::julia_call("WeftGuest.included"),
                                                "the Julia included-files drain")))
  root <- norm_path(root)
  out <- character()
  for (p in paths) {
    rel <- rel_path(root, norm_path(p))
    if (is_abs_path(rel) || startsWith(rel, "..")) next
    parts <- strsplit(rel, "/", fixed = TRUE)[[1L]]
    dirs <- parts[-length(parts)]
    if (any(dirs %in% c("site-packages", "dist-packages", ".venv", "venv", "renv") | startsWith(dirs, "."))) next
    out <- c(out, rel)
  }
  unique(out)
}

# ---- jl_value() in expressions weft evaluates (J11) ---------------------------------

# `jl_value(...)` or `weft::jl_value(...)`: the function as written, or NULL.
jl_value_fn <- function(node) {
  if (!is.call(node)) return(NULL)
  f <- node[[1L]]
  if (identical(f, as.name("jl_value"))) return(f)
  if (is.call(f) && length(f) == 3L && as.character(f[[1L]]) %in% c("::", ":::") &&
      identical(f[[2L]], as.name("weft")) && identical(f[[3L]], as.name("jl_value"))) return(f)
  NULL
}

jl_tracked_call <- function(node) {
  as.call(c(list(quote(weft:::jl_value_tracked), call("quote", node[[1L]])), as.list(node)[-1L]))
}
