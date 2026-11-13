# Rehearse a document under several sets of parameters (rules 3.7.2-3.7.4).

# Set by `rehearse()` for the process that knits: weft writes nothing into the
# project (3.7.2).
rehearsing <- function() identical(Sys.getenv("WEFT_REHEARSE"), "1")

#' Knit a document under several cases and see which arms they choose
#'
#' Knits `file` once for each case, each in a fresh R process, and reads back
#' what the knit recorded: the failures, and the arm that each governed span
#' chose. The result says which arms no case reached and which spans no case
#' evaluated, so that a manuscript's wording can be checked for every value
#' its parameters may take (rules 3.7.1 to 3.7.4).
#'
#' Each case is a named list of `params`. The knit has the document's
#' default parameters with the case's values over them; a name that the
#' document does not declare is an error, raised before anything runs. A
#' default written `!r` is evaluated in the child process, in the document's
#' folder, and one that cannot be evaluated stops that case with the error. A
#' case cannot be named after a column of the result (`file`, `line`,
#' `context`, `span`, `key`, `expr`, `arm`, `role`, `text`, `parent_span`,
#' `parent_arm` or `reached`). The knit's working directory is the
#' document's, as in a render, for a `.qmd` too. Draft mode is on, so
#' a case with failures runs to its end; a case whose knit stops is reported
#' in its `error` and the next case runs.
#'
#' Nothing is written to the project. The output and the figures go to a
#' temporary directory that is removed, and the child process runs with the
#' environment variable `WEFT_REHEARSE=1`, which makes weft write no stamp, no
#' collection line, no draft JSON file and no ledger, and use no chunk cache
#' (`cache = FALSE` is forced for every chunk, wherever its cache was set, so
#' no cache directory appears). A chunk of the document that itself writes
#' files is the author's affair.
#'
#' @section Limits:
#' Only `knitr::knit()` runs: not Pandoc and not Quarto, because a rehearsal
#' needs the records and not the output. Because Quarto does not run, a
#' `{{< include >}}` is not expanded and project-level metadata is not read;
#' that includes `execute-dir`, so the working directory is always the
#' document's folder, never the project root.
#' A `.qmd` whose inline code uses the `{r}` form is knitted with a stand-in
#' for Quarto's `.QuartoInlineRender`. A document that reads its data some
#' other way than through its parameters renders the same data in every case
#' (rule 3.7.4).
#'
#' The child process is started in the project root (the nearest folder
#' upward that holds `_weft.yml` or `_quarto.yml`, else the document's folder)
#' and reads that folder's `.Rprofile`, as a render does, so a document that
#' activates weft there can be rehearsed. It is not run with `--vanilla`.
#'
#' Only the spans of the file rehearsed are reported: a span in a document
#' that a chunk includes with `child=` is not listed or reported. A span that
#' a case evaluates more than once (a `weft_str()` in a loop) is reported once,
#' with the last arm it chose. A case value is not checked against the
#' default's type, and `cases` cannot be empty.
#'
#' The child process loads the same weft as this one: when it was loaded by
#' `pkgload` (as `devtools::load_all()` does) from a source directory, the
#' child loads that directory, and otherwise it calls `library(weft)`.
#'
#' @param file The path of a `.qmd` or `.Rmd` document.
#' @param cases A named list. Each element is a named list of the parameters
#'   that case sets (an empty list for the defaults).
#' @return An object of class `weft_rehearsal`, a list:
#'   * `cases`: a named list, one element per case, each a list of `ok` (no
#'     failures and the knit finished), `error` (the message when the knit
#'     itself stopped, else `NA`), `failures` (the data frame of
#'     `last_knit()$failures`), `warnings` (the data frame of
#'     `last_knit()$warnings`; `ok` ignores it) and `chosen` (a data frame of `span`, `file`,
#'     `line`, `key`, `expr`, `arm`, `role` and `text`, one row for each
#'     governed span the case evaluated; `span` matches [arms()]; `arm`,
#'     `role` and `text` are `NA` for a span that was evaluated and chose no
#'     arm);
#'   * `arms`: [arms()] of the file (the same object, with its class and
#'     `errors` attribute) with one logical column for each case (did the
#'     case choose this arm) and `reached` (did any);
#'   * `unreached`: the rows of `arms` that no case reached;
#'   * `unevaluated`: the rows of the spans that no case evaluated at all
#'     (those nested in arms that were never chosen).
#' @seealso [arms()]
#' @export
rehearse <- function(file, cases) {
  if (!is.character(file) || length(file) != 1L || is.na(file) || !file.exists(file)) {
    weft_abort("`file` must be the path of one existing document.", "weft_rehearse_error")
  }
  if (!is.list(cases) || is.null(names(cases)) || any(!nzchar(names(cases))) ||
      anyDuplicated(names(cases)) || !all(vapply(cases, is.list, NA))) {
    weft_abort("`cases` must be a named list of named lists of params.", "weft_rehearse_error")
  }
  taken <- c("file", "line", "context", "span", "key", "expr", "arm", "role", "text",
             "parent_span", "parent_arm", "reached")
  clash <- intersect(names(cases), taken)
  if (length(clash)) {
    weft_abort(sprintf("A case cannot be named `%s`: that is a column of the result.",
                       clash[1L]), "weft_rehearse_error")
  }
  path <- normalizePath(file, winslash = "/", mustWork = TRUE)
  defaults <- rehearse_defaults(path)
  for (nm in names(cases)) {
    given <- names(cases[[nm]])
    if (length(cases[[nm]]) && (is.null(given) || any(!nzchar(given)))) {
      weft_abort(sprintf("The params of case `%s` must be named.", nm), "weft_rehearse_error")
    }
    unknown <- setdiff(given, names(defaults))
    if (length(unknown)) {
      weft_abort(sprintf("Case `%s` sets `%s`, which the document does not declare in `params`.",
                         nm, paste(unknown, collapse = "`, `")), "weft_rehearse_error")
    }
  }
  base <- arms(file)
  res <- lapply(names(cases), function(nm) rehearse_case(path, cases[[nm]], base))
  names(res) <- names(cases)
  ext <- base
  for (nm in names(res)) {
    ch <- res[[nm]]$chosen
    ext[[nm]] <- paste(ext$span, ext$arm) %in% paste(ch$span, ch$arm)
  }
  ext$reached <- if (length(res)) Reduce(`|`, lapply(names(res), function(nm) ext[[nm]])) else
    rep(FALSE, nrow(ext))
  seen <- unlist(lapply(res, function(r) r$chosen$span), use.names = FALSE)
  ever <- ext$span %in% c(ext$span[ext$reached], seen)
  structure(list(cases = res, arms = ext, unreached = ext[!ext$reached, , drop = FALSE],
                 unevaluated = ext[!ever, , drop = FALSE]),
            class = "weft_rehearsal")
}

# The names of the document's params. Nothing is evaluated here: a default
# written `!r` runs in the child, in the document's folder.
rehearse_defaults <- function(path) {
  lines <- read_source_lines(path)
  ps <- tryCatch(knitr::knit_params(lines, evaluate = FALSE), error = function(e) {
    weft_abort(sprintf("The `params` of %s cannot be read: %s", basename(path),
                       conditionMessage(e)), "weft_rehearse_error")
  })
  vals <- lapply(ps, function(p) p$value)
  names(vals) <- vapply(ps, function(p) p$name, "")
  vals
}

# How the child process is to load weft: the source directory when this weft
# was loaded by pkgload, else the installed package.
rehearse_loader <- function() {
  dev <- requireNamespace("pkgload", quietly = TRUE) && pkgload::is_dev_package("weft")
  if (dev) {
    root <- getNamespaceInfo("weft", "path")
    sprintf("pkgload::load_all(%s, quiet = TRUE, export_all = FALSE)", deparse(root))
  } else {
    "library(weft)"
  }
}

rehearse_case <- function(path, set, base) {
  work <- tempfile("weft-rehearse-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE, force = TRUE), add = TRUE)
  out <- file.path(work, "out")
  dir.create(out)
  args <- file.path(work, "args.rds")
  result <- file.path(work, "result.rds")
  log <- file.path(work, "log.txt")
  saveRDS(list(input = basename(path), dir = dirname(path), out = out, set = set,
               qmd = grepl("\\.qmd$", path, ignore.case = TRUE),
               root = find_project_root(path), result = result), args)
  code <- sprintf("%s; weft:::rehearse_child(%s)", rehearse_loader(), deparse(args))
  # started in the project root, which is where a render reads `.Rprofile`
  old <- setwd(find_project_root(path))
  on.exit(setwd(old), add = TRUE)
  # the variables are set in this process: system2()'s `env =` is ignored on Windows for Rscript
  status <- withr::with_envvar(
    c(WEFT_REHEARSE = "1", WEFT_DRAFT = "1", WEFT_COLLECT = "", QUARTO_EXECUTE_INFO = "",
      R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)),
    suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                             stdout = log, stderr = log)))
  raw <- if (file.exists(result)) tryCatch(readRDS(result), error = function(e) NULL) else NULL
  if (is.null(raw)) {
    tail <- if (file.exists(log)) utils::tail(readLines(log, warn = FALSE), 5L) else character()
    raw <- list(error = paste(c(sprintf("The R process for the case failed (status %s).",
                                       as.character(status)), tail), collapse = "\n"),
                failures = failures_frame_empty(), warnings = failures_frame_empty(),
                constructs = NULL)
  }
  chosen <- rehearse_chosen(raw$constructs, base)
  failures <- raw$failures
  error <- if (is.null(raw$error)) NA_character_ else as.character(raw$error)[1L]
  list(ok = is.na(error) && nrow(failures) == 0L, error = error,
       failures = failures, warnings = raw$warnings %||% failures_frame_empty(),
       chosen = chosen)
}

# Match the spans a knit evaluated to the spans of arms(file). A span is known
# by where it is: a prose or front-matter span by its line, key, expression
# and its place among the like spans of that line; a caption by its chunk and
# option, and a literal `weft_str()` string by its chunk, in the same way. Where
# a string is evaluated more than once, the evaluations go to the like spans in
# order, and the last choice of a span stands.
rehearse_chosen <- function(cons, base) {
  empty <- data.frame(span = integer(), file = character(), line = integer(),
                      key = character(), expr = character(), arm = integer(),
                      role = character(), text = character(), stringsAsFactors = FALSE)
  if (is.null(cons) || !nrow(cons) || !nrow(base)) return(empty)
  cons <- cons[(cons$evaluated | !is.na(cons$chosen)) &
                 (!is.na(cons$line) | cons$context != "prose") &
                 cons$kind %in% names(ARM_ROLES), , drop = FALSE]
  cons <- cons[is.na(cons$file) | basename(cons$file) %in% basename(base$file), , drop = FALSE]
  if (!nrow(cons)) return(empty)
  first <- base[!duplicated(base$span), , drop = FALSE]
  meta <- attr(base, "chunks")
  norm <- function(x) gsub("-", ".", as.character(x), fixed = TRUE)
  place <- function(context, line, chunk, option, kind, expr, ord) {
    paste(ifelse(context %in% c("prose", "front-matter"), "prose", context),
          ifelse(context %in% c("prose", "front-matter"), line, ""),
          ifelse(context == "caption", paste(chunk, norm(option)),
                 ifelse(context == "weft_str", chunk, "")),
          kind, expr, ord, sep = "\r")
  }
  m <- match(first$span, meta$span)
  skey <- place(first$context, first$line, meta$chunk[m], meta$option[m], first$key,
                first$expr, meta$ord[m])
  ckey <- place(cons$context, cons$line, cons$chunk, cons$option, cons$kind, cons$expr,
                cons$ord)
  seen <- list()
  span <- rep(NA_integer_, nrow(cons))
  for (i in seq_len(nrow(cons))) {
    n <- (seen[[ckey[i]]] %||% 0L) + 1L
    seen[[ckey[i]]] <- n
    hit <- first$span[skey == ckey[i]]
    if (length(hit)) span[i] <- hit[min(n, length(hit))]
  }
  keep <- !is.na(span)
  rows <- data.frame(span = span[keep], arm = as.integer(cons$chosen[keep]))
  rows <- rows[!duplicated(rows$span, fromLast = TRUE), , drop = FALSE]
  # an arm the span does not have is no choice
  ok <- is.na(rows$arm) | paste(rows$span, rows$arm) %in% paste(base$span, base$arm)
  rows <- rows[ok, , drop = FALSE]
  m <- match(paste(rows$span, rows$arm), paste(base$span, base$arm))
  f <- match(rows$span, first$span)
  out <- data.frame(span = rows$span, file = first$file[f], line = first$line[f],
                    key = first$key[f], expr = first$expr[f], arm = rows$arm,
                    role = ifelse(is.na(m), NA_character_, base$role[m]),
                    text = ifelse(is.na(m), NA_character_, base$text[m]),
                    stringsAsFactors = FALSE)
  out <- out[order(out$span), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# The body of the child process: knit the document and write what the knit
# recorded. Run with WEFT_REHEARSE=1 and WEFT_DRAFT=1 in the environment.
rehearse_child <- function(args_path) {
  a <- readRDS(args_path)
  setwd(a$dir)
  knitr::opts_knit$set(base.dir = a$out)
  # a rehearsal uses no chunk cache, wherever a chunk's cache was set: the
  # hook runs for every chunk, whether or not weft is active yet (3.7.2)
  knitr::opts_chunk$set(cache = FALSE)
  knitr::opts_hooks$set(label = function(options) {
    options$cache <- FALSE
    options
  })
  # knitr reads and evaluates relative to the document, a `.qmd`'s copy too
  knitr::opts_knit$set(root.dir = a$dir)
  envir <- new.env(parent = globalenv())
  # a stand-in for the function Quarto wraps `{r} x` in
  envir$.QuartoInlineRender <- function(x) x
  input <- a$input
  if (a$qmd) {
    # Quarto rewrites `{r} x` to `r .QuartoInlineRender(x)` in a copy named
    # `<name>.rmarkdown` and has knitr read that, weft mapping it back to the
    # `.qmd`. The copy and the settings files it needs are staged in the
    # temporary directory, never in the project.
    stage <- file.path(a$out, "stage")
    dir.create(stage)
    for (f in c("_weft.yml", "_quarto.yml", "_quarto.yaml")) {
      if (file.exists(file.path(a$root, f))) file.copy(file.path(a$root, f), stage)
    }
    file.copy(a$input, file.path(stage, a$input))
    text <- read_source_text(a$input)
    text <- gsub("(?<!`)`\\{r\\}[ \t]+([^`\n]+)`(?!`)", "`r .QuartoInlineRender(\\1)`", text, perl = TRUE)
    # and Quarto's `fig-cap` reaches knitr as `fig.cap`
    text <- gsub("(^|\n)([ \t]*#\\|[ \t]*)fig-(cap|alt|scap|subcap)([ \t]*:)", "\\1\\2fig.\\3\\4",
                 text, perl = TRUE)
    input <- file.path(stage, sub("\\.qmd$", ".rmarkdown", a$input, ignore.case = TRUE))
    writeLines(text, input, useBytes = TRUE)
  }
  err <- tryCatch({
    # the defaults of `params` are evaluated here, in the document's folder
    ps <- knitr::knit_params(read_source_lines(a$input))
    params <- lapply(ps, function(p) p$value)
    names(params) <- vapply(ps, function(p) p$name, "")
    for (p in names(a$set)) params[p] <- list(a$set[[p]])
    envir$params <- params
    knitr::knit(input, output = file.path(a$out, "out.md"), envir = envir, quiet = TRUE)
    NULL
  }, error = function(e) conditionMessage(e))
  k <- last_knit()
  cons <- NULL
  if (!is.null(k) && !is.null(k$constructs)) {
    cn <- k$constructs
    cons <- data.frame(file = as.character(cn$file), line = as.integer(cn$line),
                       kind = as.character(cn$kind), expr = as.character(cn$expr),
                       context = as.character(cn$context), chunk = as.character(cn$chunk),
                       option = as.character(cn$option), chosen = as.integer(cn$chosen),
                       evaluated = as.logical(cn$evaluated), ord = as.integer(cn$ord),
                       stringsAsFactors = FALSE)
  }
  saveRDS(list(error = err, failures = if (is.null(k)) failures_frame_empty() else k$failures,
               warnings = if (is.null(k)) failures_frame_empty() else k$warnings,
               constructs = cons), a$result)
  invisible()
}

# ---- printing ---------------------------------------------------------------

#' @export
print.weft_rehearsal <- function(x, ...) {
  ar <- x$arms
  shown <- display_files(ar$file)
  where <- function(rows) sprintf("%s:%d  %s=\"%s\"", shown[match(rows$span, ar$span)],
                                  rows$line, rows$key, rows$expr)
  for (nm in names(x$cases)) {
    cs <- x$cases[[nm]]
    cat(sprintf("case %s: %s\n", nm, if (cs$ok) "ok" else "not ok"))
    if (!is.na(cs$error)) cat("  the knit stopped: ", gsub("\n", "\n    ", cs$error), "\n", sep = "")
    if (nrow(cs$failures)) cat(gsub("(^|\n)", "\\1  ", format_report(cs$failures)), "\n", sep = "")
    if (nrow(cs$chosen)) {
      cat("  arms chosen:\n")
      ch <- cs$chosen
      cat(ifelse(is.na(ch$arm), sprintf("    %s  chose no arm", where(ch)),
                 sprintf("    %s  arm %s (%s)  %s", where(ch), ch$arm, ch$role,
                         elide_attrs(ch$text))), sep = "\n")
    } else {
      cat("  no span chose an arm\n")
    }
  }
  cat("\n")
  if (nrow(x$unreached)) {
    cat(sprintf("%d arm%s that no case reached:\n", nrow(x$unreached),
                if (nrow(x$unreached) == 1L) "" else "s"))
    cat(sprintf("  %s  arm %d (%s)  %s", where(x$unreached), x$unreached$arm,
                x$unreached$role, elide_attrs(x$unreached$text)), sep = "\n")
  } else {
    cat("Every arm was reached by some case.\n")
  }
  if (nrow(x$unevaluated)) {
    u <- x$unevaluated[!duplicated(x$unevaluated$span), , drop = FALSE]
    cat(sprintf("%d span%s that no case evaluated:\n", nrow(u), if (nrow(u) == 1L) "" else "s"))
    cat(paste0("  ", where(u)), sep = "\n")
  } else {
    cat("Every span was evaluated by some case.\n")
  }
  invisible(x)
}
