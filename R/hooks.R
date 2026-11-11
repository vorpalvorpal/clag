# Activation and the knitr hooks (rules 2.1, 2.2.1, 2.5.2, 2.8, 9.2).
#
# Installing leaves a plain `knitr::knit()` producing the output it produces
# without the hooks (2.1.7, Q16). The cause of the loss in Q16: `knit()` calls
# `render_markdown()` (knitr's markdown output hooks) only when the twelve
# default hooks are still the defaults when the knit starts. Replacing the
# `text`, `evaluate`, `evaluate.inline` or `document` hook before the knit
# starts therefore leaves a plain `knit()` with none of the markdown hooks:
# no fenced code blocks. weft avoids it by not touching those hooks outside a
# knit. `weft_setup()` called outside a knit installs only a `before.knit` and
# an `after.knit` hook, which are not among the twelve; `before.knit` runs
# after knitr has chosen its output hooks, and installs the weft hooks then,
# over whatever is there. Called inside a knit, it installs them at once.

#' Activate weft for a document
#'
#' Installs the knitr hooks that resolve weft's constructs in prose, log the
#' conditions chunks raise, and check, at the end of the document, that
#' everything was evaluated (rules 2.1, 9.2). Call it from a setup chunk, from
#' the document's front matter (`knitr: opts_knit: weft: !expr
#' weft::weft_setup()`) or from a project's `.Rprofile`. Attaching the package
#' installs nothing (rule 2.1.3).
#'
#' Each hook wraps the hook installed before it and calls it (rule 2.1.2).
#' Installing is idempotent, and works whether or not a knit is in progress; a
#' call made while a knit is running changes none of that knit's state.
#'
#' @return `TRUE`, invisibly.
#' @examples
#' \dontrun{
#' weft::weft_setup()
#' }
#' @export
weft_setup <- function() {
  attach_functions()
  install_boundary_hooks()
  if (knit_in_progress()) {
    install_hooks()
    ensure_knit()
  }
  invisible(TRUE)
}

# Inline R in prose calls `claim()`, `plural()` and the `fmt_*()` functions by
# name, so they must be findable without `library(weft)`: weft_setup() puts
# them on the search path last, where anything the author defines, or any
# attached package, comes first.
attach_functions <- function() {
  if ("package:weft" %in% search() || "weft:functions" %in% search()) {
    return(invisible())
  }
  ns <- asNamespace("weft")
  nms <- c("claim", "plural", "glue_vec",
           grep("^fmt_", getNamespaceExports(ns), value = TRUE))
  env <- list2env(mget(nms, envir = ns), parent = emptyenv())
  get("attach", envir = baseenv())(env, name = "weft:functions",
                                   pos = length(search()), warn.conflicts = FALSE)
  invisible()
}

knit_in_progress <- function() {
  isTRUE(getOption("knitr.in.progress"))
}

is_child_knit <- function() isTRUE(knitr::opts_knit$get("child"))

is_weft_hook <- function(f) isTRUE(attr(f, "weft"))

# Set a hook to `make(previous)` unless it is already weft's.
wrap_hook <- function(name, make) {
  cur <- knitr::knit_hooks$get(name, default = FALSE)
  if (is_weft_hook(cur)) return(invisible(FALSE))
  new <- make(cur)
  attr(new, "weft") <- TRUE
  knitr::knit_hooks$set(stats::setNames(list(new), name))
  invisible(TRUE)
}

# before.knit and after.knit are not among knitr's twelve default hooks, so
# setting them leaves `knit()` to choose its markdown output hooks (2.1.7).
install_boundary_hooks <- function() {
  wrap_hook("before.knit", function(prev) {
    function(...) {
      install_hooks()
      if (!is_child_knit()) {
        old <- weft_env$state
        if (!is.null(old)) old$finished <- TRUE
      }
      ensure_knit()
      if (is.function(prev)) prev(...)
    }
  })
  wrap_hook("after.knit", function(prev) {
    function(...) {
      on.exit(if (is.function(prev)) prev(...), add = TRUE)
      if (!is_child_knit()) finish_knit()
    }
  })
  invisible()
}

install_hooks <- function() {
  wrap_hook("evaluate.inline", function(prev) {
    weft_env$stock_eval <- if (is.function(prev)) prev else
      knitr::knit_hooks$get("evaluate.inline", default = TRUE)
    function(code, envir = knitr::knit_global()) {
      s <- ensure_knit()
      s$parked[[length(s$parked) + 1L]] <- list(code = code, envir = envir)
      paste0("\ue000", length(s$parked), "\ue002")
    }
  })
  wrap_hook("text", function(prev) {
    function(x, ...) {
      y <- resolve_text(x)
      if (is.function(prev)) prev(y, ...) else y
    }
  })
  wrap_hook("evaluate", function(prev) {
    make_evaluate_hook(if (is.function(prev)) prev else
      knitr::knit_hooks$get("evaluate", default = TRUE))
  })
  wrap_hook("document", function(prev) {
    function(x, ...) {
      if (is.function(prev)) x <- prev(x, ...)
      if (!is_child_knit()) finish_document()
      x
    }
  })
  install_option_hook()
  invisible()
}

# The chunk's options are read before it runs; weft notes a chunk that may be
# served from knitr's cache (2.9.1).
install_option_hook <- function() {
  cur <- knitr::opts_hooks$get("label")
  if (is_weft_hook(cur)) return(invisible())
  new <- function(options) {
    s <- ensure_knit()
    note_cached_chunk(s, options)
    if (is.function(cur)) cur(options) else options
  }
  attr(new, "weft") <- TRUE
  knitr::opts_hooks$set(label = new)
  invisible()
}

# ---- per-knit initialisation (2.1.5) ------------------------------------------------

ensure_knit <- function() {
  s <- active_state()
  if (is.null(s)) s <- init_knit()
  s
}

# The document's own front matter (9.1.1, 2.1.6).
read_front_matter <- function(path) {
  if (is.null(path)) return(list())
  lines <- tryCatch(read_view_lines(path), error = function(e) character())
  if (!length(lines) || !grepl("^---[ \t]*$", lines[1L])) return(list())
  end <- which(grepl("^(---|\\.\\.\\.)[ \t]*$", lines[-1L]))[1L]
  if (is.na(end) || end < 2L) return(list())
  txt <- paste(lines[2L:end], collapse = "\n")
  y <- tryCatch(yaml::yaml.load(txt, eval.expr = FALSE), error = function(e) list())
  if (is.list(y)) y else list()
}

init_knit <- function() {
  path <- knit_input_path()
  front <- read_front_matter(path)
  root <- if (!is.null(path)) find_project_root(path) else getwd()
  cfg <- read_config(root, front$weft)
  s <- new_state()
  s$config <- cfg
  s$input_path <- path %||% NA_character_
  s$front <- front
  lang <- front$lang
  s$lang <- if (is.character(lang) && length(lang) == 1L && !is.na(lang)) lang else ""
  weft_env$config <- cfg
  weft_env$state <- s
  if (!is.null(path)) {
    F <- current_file_state(s)
    s$input_name <- if (is.null(F)) basename(path) else F$name
    if (!is.null(F) && length(F$unparseable)) {
      # knitr parses inline code before any hook runs and stops on code that
      # does not parse, with no position. weft reports it first (5.3.5)
      if (!isTRUE(cfg$draft)) {
        ml <- map_lines(F, F$unparse_rows$line[1L])
        weft_abort(sprintf("weft: %s:%d: %s", ml$file, ml$line, F$unparse_rows$error[1L]),
                   c("weft_construct_error", "weft_located"))
      }
      protect_inline_patterns(F)
    }
  }
  s
}

finish_knit <- function() {
  s <- weft_env$state
  if (!is.null(s)) s$finished <- TRUE
  weft_env$config <- NULL
  weft_env$inline <- NULL
  invisible()
}

# ---- the end of the document (2.5.2, 2.6) ------------------------------------------

finish_document <- function() {
  s <- active_state()
  if (is.null(s)) return(invisible())
  settle_pending(s)
  for (F in s$files) {
    if (is.null(F$expected) || !nrow(F$expected)) next
    want <- paste(F$expected$kind, F$expected$line)
    have <- F$recorded
    for (k in seq_along(want)) {
      i <- match(want[k], have)
      if (!is.na(i)) {
        have <- have[-i]
        next
      }
      ml <- map_lines(F, F$expected$line[k])
      add_failure(s, "unevaluated", file = ml$file, line = ml$line,
                  expr = sprintf("a `%s` construct", F$expected$kind[k]),
                  detail = paste0("It was never evaluated: the hooks were not installed when ",
                                  "knitr reached it (rule 2.5.2); call weft_setup() above it."))
    }
  }
  fr <- failures_frame(s)
  if (!nrow(fr)) return(invisible())
  report <- format_report(fr)
  if (isTRUE(s$config$draft)) {
    message(report)
    return(invisible())
  }
  weft_abort(report, "weft_failures")
}
