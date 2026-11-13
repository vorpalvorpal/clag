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
  if (!knit_in_progress() && utils::packageVersion("knitr") < "1.51") {
    # `before.knit` and `after.knit` are run by knitr 1.51 and later: before
    # that, activating outside a knit would silently do nothing (2.1.7)
    weft_abort(sprintf(paste0(
      "weft_setup() called outside a knit needs knitr 1.51 or later, and this R ",
      "session has knitr %s (library %s). Update knitr, or call weft_setup() ",
      "from a setup chunk."), utils::packageVersion("knitr"),
      dirname(find.package("knitr"))), "weft_knitr_too_old")
  }
  attach_functions()
  install_boundary_hooks()
  if (knit_in_progress()) {
    install_hooks()
    s <- ensure_knit()
    # the label hook was not installed when this chunk started: its code is walked
    # for reads like any other chunk's (2e-1, I15)
    opts <- tryCatch(knitr::opts_current$get(), error = function(e) NULL)
    if (is.list(opts) && !is.null(opts$code) && !rehearsing() && !is_child_knit()) {
      note_chunk_code(s, opts)
    }
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
  nms <- inline_function_names()
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
        if (!is.null(old) && !isTRUE(old$finished) && knit_nested()) {
          # a render started inside a chunk is its own top-level knit; the outer
          # knit's state is kept, and comes back when the inner one ends
          weft_env$outer <- c(list(list(state = old, config = weft_env$config, units = weft_env$units,
                                        units_default = weft_env$units_default,
                                        inline = weft_env$inline)), weft_env$outer)
          weft_env$state <- NULL
        } else {
          weft_env$outer <- NULL
          if (!is.null(old)) old$finished <- TRUE
        }
      }
      s <- ensure_knit()
      push_knit(s)
      if (is.function(prev)) prev(...)
    }
  })
  wrap_hook("after.knit", function(prev) {
    function(...) {
      on.exit(if (is.function(prev)) prev(...), add = TRUE)
      if (!is_child_knit()) finish_knit() else pop_knit()
    }
  })
  invisible()
}

# Under LaTeX output weft tells pdflatex how to set the characters it prints
# that LaTeX does not set: the minus sign U+2212 (negative numbers and a unit's
# negative power), the ohm sign, the prime and double prime (arc minute and
# second), the micro sign and the degree sign. xelatex and lualatex set the
# minus already; where their default font lacks the primes they are taken from
# Latin Modern Math. Each dependency is added once per knit.
add_latex_minus <- function() {
  if (!isTRUE(tryCatch(knitr::is_latex_output(), error = function(e) FALSE))) return(invisible())
  decl <- function(code, text) sprintf("\\DeclareUnicodeCharacter{%s}{%s}", code, text)
  pdftex <- paste0(
    "\\ifPDFTeX",
    decl("2212", "\\ensuremath{-}"),
    decl("03A9", "\\ensuremath{\\Omega}"),
    decl("2126", "\\ensuremath{\\Omega}"),
    decl("2032", "\\ensuremath{{}^{\\prime}}"),
    decl("2033", "\\ensuremath{{}^{\\prime\\prime}}"),
    decl("00B5", "\\textmu"),
    decl("00B0", "\\textdegree"),
    "\\fi")
  # the primes by their glyph in Latin Modern Math, for an engine whose text font has none
  prime <- function(ch, code) {
    sprintf("\\newunicodechar{%s}{%s}", ch, sprintf("{\\weftprimefont\\char\"%s}", code))
  }
  xetex <- paste0(
    "\\ifPDFTeX\\else",
    "\\IfFontExistsTF{latinmodern-math.otf}{",
    "\\newfontfamily\\weftprimefont{latinmodern-math.otf}",
    # unicode-math claims these characters at the start of the document
    "\\AtBeginDocument{", prime("\u2032", "2032"), prime("\u2033", "2033"), "}",
    "}{}\\fi")
  add_dep <- function(name, line) {
    have <- knitr::knit_meta("latex_dependency", clean = FALSE)
    if (any(vapply(have, function(d) identical(d$extra_lines, line), NA))) return(invisible())
    knitr::knit_meta_add(list(structure(
      list(name = name, options = NULL, extra_lines = line), class = "latex_dependency")))
  }
  add_dep("iftex", pdftex)
  add_dep("newunicodechar", xetex)
  invisible()
}

install_hooks <- function() {
  add_latex_minus()
  wrap_hook("evaluate.inline", function(prev) {
    weft_env$stock_eval <- if (is.function(prev)) prev else
      knitr::knit_hooks$get("evaluate.inline", default = TRUE)
    function(code, envir = knitr::knit_global()) {
      s <- ensure_knit()
      park_inline(s, code, envir)
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
  install_caption_hooks()
  invisible()
}

# ---- parking inline code ------------------------------------------------------

# knitr hands each piece of inline code to the `evaluate.inline` hook as it
# parses the block, and sets the position it will name in an error from that
# piece. weft evaluates later, from the `text` hook, so an error in a bare
# value would name the block's last inline code. A bare value that no construct
# in its block precedes is therefore evaluated at once: that keeps textual
# order, and the error is stock's, at stock's line (1.1.8, 2.7.1).
park_inline <- function(s, code, envir) {
  idx <- length(s$parked) + 1L
  s$parked[[idx]] <- list(code = code, envir = envir)
  if (grepl("knit_exit", code, fixed = TRUE)) s$exited <- TRUE
  row <- eager_row(s, code)
  early <- isTRUE(s$eager_ok) && !is.null(row)
  if (!early) {
    s$eager_ok <- FALSE
  } else {
    li <- early_line(s)
    label <- sprintf("`r %s`", code)
    er <- s$early_row
    wh <- function() ledger_where(s, er$F, li$file, er$line)
    r <- run_inline(s, li$file, li$line, label, code,
                    function() stock_bare_text(code, envir), where = wh)
    if (r$ok || inherits(r$error, c("weft_no_value", "weft_value_error"))) {
      s$parked[[idx]]$result <- r
    } else {
      stop(r$error)
    }
  }
  paste0("\ue000", idx, "\ue002")
}

# The top-level bare value in the file's scan that this piece of code is, or
# NULL. Pieces are matched to the scan in file order.
eager_row <- function(s, code) {
  s$early_row <- NULL
  F <- current_file_state(s)
  if (is.null(F) || is.null(F$inline_code)) return(NULL)
  n <- length(F$inline_code)
  ptr <- F$park_ptr
  if (ptr > n) return(NULL)
  j <- match(unwrap_quarto(trim_ws(code)), F$inline_code[ptr:n])
  if (is.na(j)) return(NULL)
  j <- ptr + j - 1L
  F$park_ptr <- j + 1L
  if (F$inline_kind[j] != "bare" || !is.na(F$inline_parent[j]) ||
      !is.na(F$inline_error[j])) return(NULL)
  s$early_row <- list(F = F, line = F$inline_line[j])
  s$early_row
}

early_line <- function(s) {
  er <- s$early_row
  ml <- map_lines(er$F, er$line)
  list(file = ml$file, line = ml$line)
}

# ---- nested knits -----------------------------------------------------------------

# A child knitted from text names the same input as its parent, and has no
# lines of its own; a child knitted from a file is a fresh pass over that
# file, so its search starts again at the top.
push_knit <- function(s) {
  path <- knit_input_path()
  if (!is_child_knit()) {
    s$stack <- list(list(path = path, text = FALSE))
    return(invisible())
  }
  top <- if (length(s$stack)) s$stack[[length(s$stack)]]$path else
    if (is.na(s$input_path)) NULL else s$input_path
  is_text <- is.null(path) || identical(path, top)
  if (!is_text) {
    # local entries belong to the document that is knitted (4.3.1)
    fm <- read_front_matter(path)
    if (is.list(fm$weft) && !is.null(fm$weft$dict_local)) {
      weft_abort(sprintf(paste0("weft: %s: a child document cannot have its own `dict_local`; ",
                                "local entries belong to the document that is knitted (rule 4.3.1)."),
                         path), "weft_dict_error")
    }
    F <- s$files[[path]]
    if (!is.null(F)) reset_file_state(F)
  }
  s$stack[[length(s$stack) + 1L]] <- list(path = path, text = is_text)
  invisible()
}

pop_knit <- function() {
  s <- weft_env$state
  if (!is.null(s) && length(s$stack)) s$stack[[length(s$stack)]] <- NULL
  invisible()
}

# The chunk's options are read before it runs; weft notes a chunk that may be
# served from knitr's cache (2.9.1).
install_option_hook <- function() {
  cur <- knitr::opts_hooks$get("label")
  if (is_weft_hook(cur)) return(invisible())
  new <- function(options) {
    s <- ensure_knit()
    # late: after Quarto has set its own `chunk` hook (2.1.4)
    install_chunk_wrapper()
    # a rehearsal uses no chunk cache (3.7.2)
    if (rehearsing()) options$cache <- FALSE
    note_chunk_label(s, options$label)
    note_chunk_code(s, options)
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

# The lines of the document's own front matter (9.1.1, 2.1.6): the YAML
# between the first `---` line and its close, or NULL.
front_matter_lines <- function(path) {
  if (is.null(path)) return(NULL)
  lines <- tryCatch(read_view_lines(path), error = function(e) character())
  if (!length(lines) || !grepl("^---[ \t]*$", lines[1L])) return(NULL)
  end <- which(grepl("^(---|\\.\\.\\.)[ \t]*$", lines[-1L]))[1L]
  if (is.na(end) || end < 2L) return(NULL)
  lines[2L:end]
}

read_front_matter <- function(path) {
  fl <- front_matter_lines(path)
  if (is.null(fl)) return(list())
  y <- tryCatch(yaml_read_text(fl), error = function(e) list())
  if (is.list(y)) y else list()
}

# Constructs the scanner finds in the front matter and in caption options
# that cannot be resolved are construct errors, found when the knit is
# initialised (1.10.3, 1.10.4, 1.10.7, 1.10.11, 2.3.5): the knit stops at the
# first, or, in draft mode, records them all.
check_static <- function(s, F, draft) {
  if (is.null(F) || is.null(F$static) || !nrow(F$static)) return(invisible())
  rows <- F$static
  ml <- map_lines(F, rows$line)
  for (k in seq_len(nrow(rows))) {
    msg <- rows$error[k]
    where <- if (rows$context[k] == "caption") rows$chunk[k] else NA_character_
    if (!draft) {
      weft_abort(sprintf("weft: %s:%d: %s", ml$file[k], ml$line[k], msg),
                 c("weft_construct_error", "weft_located"))
    }
    add_failure(s, "construct error", file = ml$file[k], line = ml$line[k],
                expr = sprintf("a `%s` construct", rows$kind[k]), detail = msg,
                chunk = where)
  }
  invisible()
}

# The document's `lang` (2.1.6): its own front matter, else Quarto's merged
# metadata, which holds a project-level `lang`: the file named by
# QUARTO_EXECUTE_INFO, else quarto::quarto_inspect() when it is installed.
document_lang <- function(front, path) {
  one <- function(x) if (is.character(x) && length(x) == 1L && !is.na(x)) x else NULL
  l <- one(front$lang)
  if (!is.null(l)) return(l)
  info <- Sys.getenv("QUARTO_EXECUTE_INFO", "")
  if (nzchar(info) && file.exists(info)) {
    # JSON is read as YAML flow style: yaml is an import, jsonlite is not
    x <- tryCatch(yaml_read_file(info), error = function(e) NULL)
    l <- one(x$format$metadata$lang)
    if (!is.null(l)) return(l)
    if (!is.null(x)) return("")
  }
  if (!is.null(path) && requireNamespace("quarto", quietly = TRUE)) {
    qmd <- sub("\\.rmarkdown$", ".qmd", path)
    if (file.exists(qmd) && grepl("\\.qmd$", qmd)) {
      x <- tryCatch(quarto::quarto_inspect(qmd), error = function(e) NULL)
      l <- one(x$formats[[1L]]$metadata$lang) %||% one(x$config$lang)
      if (!is.null(l)) return(l)
    }
  }
  ""
}

init_knit <- function() {
  path <- knit_input_path()
  front <- read_front_matter(path)
  root <- if (!is.null(path)) find_project_root(path) else getwd()
  cfg <- read_config(root, front$weft, doc = path)
  s <- new_state()
  s$config <- cfg
  s$input_path <- path %||% NA_character_
  s$front <- front
  s$lang <- document_lang(front, path)
  # a unit's name is English words (1.6.8)
  if (identical(cfg$unit_form, "name") && !lang_is_english(s$lang)) {
    weft_abort(sprintf(paste0("The setting `unit_form: name` (set in %s) prints English words, and the ",
                              "document's `lang` is `%s` (rule 1.6.8); use `auto` or `symbol`."),
                       cfg$unit_form_set %||% "the configuration", s$lang),
               "weft_config_error")
  }
  # a dictionary problem stops the knit, in draft mode too (D15)
  init_dicts(s, root, path)
  weft_env$config <- cfg
  weft_env$state <- s
  if (!is.null(path)) {
    F <- current_file_state(s)
    check_static(s, F, isTRUE(cfg$draft))
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
  # a knit that stopped before the end of the document reports the warned
  # checks it had collected (2.6.10)
  if (!is.null(s) && !isTRUE(s$warnings_reported)) {
    wr <- failures_frame(s, "warnings")
    if (nrow(wr)) message(format_warnings(wr))
    s$warnings_reported <- TRUE
  }
  if (!is.null(s)) s$finished <- TRUE
  weft_env$config <- NULL
  weft_env$inline <- NULL
  if (length(weft_env$outer)) {
    o <- weft_env$outer[[1L]]
    weft_env$outer <- weft_env$outer[-1L]
    weft_env$state <- o$state
    weft_env$config <- o$config
    weft_env$units <- o$units
    weft_env$units_default <- o$units_default
    weft_env$inline <- o$inline
  }
  invisible()
}

# TRUE when this top-level knit runs inside another knit (a render started from a chunk).
knit_nested <- function() {
  n <- 0L
  for (i in seq_len(sys.nframe())) {
    if (identical(sys.function(i), knitr::knit)) n <- n + 1L
  }
  n >= 2L
}

# ---- the end of the document (2.5.2, 2.6) ------------------------------------------

unevaluated_detail <- function(context) {
  switch(context,
    `front-matter` = paste0("It was never evaluated: the hooks were not installed when knitr ",
                            "read the front matter (rules 9.2.5, 2.5.2); activate weft from ",
                            "the front matter: `knitr: opts_knit: weft: !expr weft::weft_setup()` ",
                            "(rule 9.2.1)."),
    caption = paste0("It was never evaluated: the caption's chunk did not run, or the hooks ",
                     "were not installed when it did (rule 2.5.2)."),
    paste0("It was never evaluated: the hooks were not installed when ",
           "knitr reached it (rule 2.5.2); call weft_setup() above it."))
}

finish_document <- function() {
  s <- active_state()
  if (is.null(s)) return(invisible())
  settle_pending(s)
  # what the chapter read, before the failures are counted (7.2.2, 7.4.1)
  tryCatch(chapter_reads(s), error = function(e) {
    ledger_warn(sprintf("weft: what the chapter reads could not be recorded: %s (rule 7.2.2).",
                        conditionMessage(e)))
  })
  for (F in s$files) {
    if (is.null(F$expected) || !nrow(F$expected)) next
    want <- paste(F$expected$kind, F$expected$line)
    have <- F$recorded
    # knit_exit() ends the document: what is below the point where the knit
    # stopped is not part of the check (2.5.2)
    below <- rep(FALSE, length(want))
    if (isTRUE(s$exited) && F$cursor <= length(F$orig)) {
      below <- F$expected$line >= F$orig[F$cursor]
    }
    for (k in seq_along(want)) {
      if (below[k]) next
      i <- match(want[k], have)
      if (!is.na(i)) {
        have <- have[-i]
        next
      }
      ml <- map_lines(F, F$expected$line[k])
      add_failure(s, "unevaluated", file = ml$file, line = ml$line,
                  expr = sprintf("a `%s` construct", F$expected$kind[k]),
                  detail = unevaluated_detail(F$expected$context[k]))
    }
  }
  fr <- failures_frame(s)
  # the stamp, and in a book the held failures (2.6.6, 2.9.2, 2.9.4)
  collected <- record_knit(s, fr)
  # the ledger and the condition log follow the output (7.1.3, D20): a knit
  # that stops on its failures writes neither
  stops <- nrow(fr) > 0L && !collected && !isTRUE(s$config$draft)
  tryCatch(ledger_finish(s, write = !stops), error = function(e) {
    ledger_warn(sprintf("weft: the ledger could not be built: %s (rule 7.1.3).", conditionMessage(e)))
  })
  # the warned checks go to stderr at the end of the knit, whether or not it
  # also fails (entry 31); a collection file carries them to the post-render
  # report instead
  wr <- failures_frame(s, "warnings")
  if (nrow(wr) && !collected) message(format_warnings(wr))
  s$warnings_reported <- TRUE
  if (!nrow(fr)) return(invisible())
  # a collection file is open: the post-render script reports and fails
  if (collected) return(invisible())
  report <- format_report(fr)
  if (isTRUE(s$config$draft)) {
    message(report)
    return(invisible())
  }
  weft_abort(report, "weft_failures")
}
