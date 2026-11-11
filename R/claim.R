# claim() (rules 3.1, 2.4): a check written in the expression.

#' Check a value in place
#'
#' `claim(x, <check>, ...)` returns `x` visibly and unchanged, so a value can
#' be guarded inside a larger expression: `trend(claim(foo, . > 0))`
#' (rule 3.1.1). In a check, `.` stands for `x` (rule 3.1.2); other names
#' are looked up in the caller. Each check is a separate argument and is
#' reported separately (rule 3.1.3). Checks are captured unevaluated, and a
#' failure quotes the check as written (rule 3.1.4).
#'
#' A check passes only when it evaluates to a single `TRUE`.
#'
#' Outside a knit a failed check stops with an error of class
#' `weft_claim_failed`. `claim(x)` with no check stops with class
#' `weft_claim_no_check` (rule 3.1.10).
#'
#' With `level = "warn"` a check that is not `TRUE` is a warning, not a
#' failure. In a knit the value prints as if the check had passed, no marker
#' is left and the render does not fail; the check is recorded in
#' `last_knit()$warnings`, and the warnings are printed to stderr at the end
#' of the knit. Outside a knit it is a `warning()` of class
#' `weft_claim_warning`, and `x` is returned. A check that itself raises an
#' error is a failed check at the level given.
#'
#' @param x Any value.
#' @param ... One or more checks, as expressions in `.` and the caller's
#'   variables.
#' @param level `"fail"` (the default) or `"warn"`. It must be given by name.
#' @return `x`, unchanged.
#' @examples
#' claim(5, . > 1)
#' claim(c(3, 4), sum(.) == 7, all(. > 0))
#' @export
claim <- function(x, ..., level = c("fail", "warn")) {
  frames <- sys.calls()
  if (!(is.character(level) && length(level) %in% c(1L, 2L) &&
        (length(level) == 2L && identical(level, c("fail", "warn")) ||
         length(level) == 1L && !is.na(level) && level %in% c("fail", "warn")))) {
    weft_abort("`level` must be \"fail\" or \"warn\".", "weft_claim_level")
  }
  level <- level[1L]
  checks <- as.list(substitute(list(...)))[-1L]
  # an empty argument, as in `claim(x, )`, is no check (3.1.10)
  empty <- vapply(seq_along(checks),
                  function(k) identical(checks[[k]], quote(expr = )), NA)
  checks <- checks[!empty]
  # a bare "warn" or "fail" is a level written without its name (3.1.11)
  for (ck in checks) {
    if (is.character(ck) && length(ck) == 1L && ck %in% c("warn", "fail")) {
      weft_abort(sprintf(paste0("`%s` is a check, not a level: `level` must be written by ",
                                "name, `level = \"%s\"` (rule 3.1.11)."), ck, ck),
                 "weft_claim_level")
    }
  }
  if (length(checks) == 0L) {
    weft_abort(paste0(
      "`claim(x)` has no check (rule 3.1.10); write the check as a second ",
      "argument, for example `claim(x, . > 0)`."), "weft_claim_no_check")
  }
  value <- x
  env <- new.env(parent = parent.frame())
  assign(".", value, envir = env)
  bad <- integer()
  errs <- character()
  lens <- integer()
  for (k in seq_along(checks)) {
    res <- tryCatch(eval(checks[[k]], env), error = function(e) e)
    if (inherits(res, "error")) {
      # a check that raises an error is a failed check (2.6.1)
      bad <- c(bad, k)
      errs <- c(errs, conditionMessage(res))
      lens <- c(lens, NA_integer_)
      next
    }
    ok <- is.logical(res) && length(res) == 1L && !is.na(res) && res
    if (!ok) {
      bad <- c(bad, k)
      errs <- c(errs, NA_character_)
      # a check that returns a vector is not a single TRUE (3.1.3): say how
      # many values it returned
      lens <- c(lens, if (length(res) != 1L) length(res) else NA_integer_)
    }
  }
  if (length(bad)) {
    claim_fail(list(
      checks = written_checks(frames, checks, weft_env$inline$expr)[bad],
      value = claim_value_text(value),
      errors = errs,
      lens = lens
    ), level)
  }
  value
}

# The text of each check. The check as written when the source is kept
# (3.1.4: the srcref of the statement that holds the call, on this frame or
# an enclosing one), else its deparse.
written_checks <- function(frames, checks, inline_src = NULL) {
  dp <- function(e) paste(deparse(e, width.cutoff = 500L), collapse = " ")
  out <- vapply(checks, dp, "")
  done <- rep(FALSE, length(out))
  # in inline R the document's text is the source (3.1.4)
  srcs <- c(if (!is.null(inline_src)) list(inline_src),
            lapply(rev(frames), function(fr) attr(fr, "srcref")))
  for (sr in srcs) {
    if (is.null(sr)) next
    found <- tryCatch(claim_args_as_written(sr, dp), error = function(e) list())
    for (k in which(!done)) {
      for (f in found) {
        if (identical(f[2], out[k])) {
          out[k] <- f[1]
          done[k] <- TRUE
          break
        }
      }
    }
    if (all(done)) break
  }
  out
}

# Every argument of every `claim()` call in a statement's source: the text as
# written and its deparse, for matching.
claim_args_as_written <- function(sr, dp) {
  src <- paste(as.character(sr), collapse = "\n")
  pd <- utils::getParseData(parse(text = src, keep.source = TRUE))
  fn <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == "claim", ]
  found <- list()
  for (id in fn$id) {
    callexpr <- pd$parent[pd$id == pd$parent[pd$id == id]]
    kids <- pd[pd$parent == callexpr & pd$token == "expr", ]
    for (kid in kids$id[-1L]) {
      txt <- utils::getParseText(pd, kid)
      written <- gsub("[ \t]*\r?\n[ \t]*", " ", paste(txt, collapse = " "))
      found[[length(found) + 1L]] <- c(
        written, dp(parse(text = written, keep.source = FALSE)[[1L]]))
    }
  }
  found
}

claim_value_text <- function(value) {
  # a date or a factor is shown as format() prints it, not as structure(...)
  s <- if (inherits(value, c("Date", "POSIXt", "factor", "difftime"))) {
    paste(format(value), collapse = ", ")
  } else {
    paste(deparse(value, width.cutoff = 500L), collapse = " ")
  }
  if (nchar(s) > 80L) s <- paste0(substr(s, 1L, 77L), "...")
  s
}

# The one place a failed claim goes (rule 2.4). In inline R during a knit it
# is collected and `claim()` returns its value (2.4.1). In chunk code during a
# knit it is recorded and then stops, with every failure collected so far in
# its message (2.4.4, 2.4.5). Everywhere else it stops at once (2.4.2).
claim_fail <- function(record, level = "fail") {
  errs <- record$errors %||% rep(NA_character_, length(record$checks))
  lens <- record$lens %||% rep(NA_integer_, length(record$checks))
  detail <- ifelse(
    !is.na(errs),
    sprintf("%s raised an error: %s (value %s)", record$checks, errs, record$value),
    ifelse(
      !is.na(lens),
      sprintf("%s returned %d values, not a single TRUE (value %s); write all(%s) to require every element",
              record$checks, lens, record$value, record$checks),
      sprintf("%s was FALSE (value %s)", record$checks, record$value)))
  s <- active_state()
  inl <- weft_env$inline
  if (identical(level, "warn")) return(claim_warn(record, detail, s, inl, errs, lens))
  if (!is.null(s) && !is.null(inl)) {
    for (d in detail) {
      add_failure(s, "failed claim", file = inl$file, line = inl$line,
                  expr = inl$label, detail = d, chunk = inl$chunk %||% NA_character_,
                  option = inl$option %||% NA_character_)
    }
    inl$failed <- TRUE
    weft_env$inline <- inl
    return(invisible(NULL))
  }
  lines <- ifelse(
    !is.na(errs),
    sprintf("  check `%s` raised an error: %s (value: %s)", record$checks,
            errs, record$value),
    ifelse(
      !is.na(lens),
      sprintf("  check `%s` returned %d values, not a single TRUE (value: %s); write all(%s) to require every element",
              record$checks, lens, record$value, record$checks),
      sprintf("  check `%s` failed (value: %s)", record$checks, record$value)))
  msg <- paste(c(sprintf("weft: %d failed claim%s", length(record$checks),
                         if (length(record$checks) == 1L) "" else "s"), lines),
               collapse = "\n")
  if (!is.null(s)) {
    label <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    for (d in detail) {
      add_failure(s, "failed claim", file = current_file_name(s),
                  chunk = if (is.null(label)) NA_character_ else label, detail = d,
                  expr = NA_character_)
    }
    # the collected report rides on a check that stops the knit; in a chunk
    # with `error=TRUE` the knit carries on, and the message is the claim's own
    # (2.4.4, 2.4.5)
    carries_on <- isTRUE(tryCatch(knitr::opts_current$get("error"), error = function(e) NULL))
    if (!carries_on) {
      # what the earlier chapters of a project render collected goes with it:
      # the render stops here and no later script reports it (2.4.5)
      fr <- failures_frame(s)
      root <- state_root(s)
      if (!is.na(root)) fr <- rbind(collected_failures(root), fr)
      msg <- paste0(msg, "\n", format_report(fr))
    }
  }
  weft_abort(msg, "weft_claim_failed")
}

# A warned check (entry 31): in a knit it is recorded and nothing else
# happens; outside a knit it is a warning of class `weft_claim_warning`.
claim_warn <- function(record, detail, s, inl, errs, lens) {
  if (!is.null(s)) {
    for (d in detail) warn_here(s, inl, "failed claim", d)
    return(invisible(NULL))
  }
  lines <- ifelse(
    !is.na(errs),
    sprintf("check `%s` raised an error: %s (value: %s)", record$checks, errs, record$value),
    ifelse(
      !is.na(lens),
      sprintf("check `%s` returned %d values, not a single TRUE (value: %s)",
              record$checks, lens, record$value),
      sprintf("check `%s` failed (value: %s)", record$checks, record$value)))
  for (l in lines) rlang::warn(paste0("weft: ", l), class = "weft_claim_warning")
  invisible(NULL)
}

# Record a warned check where the code that raised it is: the inline code
# being run, else the chunk (entry 31).
warn_here <- function(s, inl, kind, detail) {
  if (!is.null(inl)) {
    add_warning(s, kind, file = inl$file, line = inl$line,
                expr = inl$label, detail = detail, chunk = inl$chunk %||% NA_character_,
                option = inl$option %||% NA_character_)
  } else {
    label <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    add_warning(s, kind, file = current_file_name(s),
                chunk = if (is.null(label)) NA_character_ else label, detail = detail,
                expr = NA_character_)
  }
}

# A number that printed as zero (stage 1i), from `fmt_num()`, `fmt_pct()` and
# the like: a warned check in a knit, a `weft_zero_warning` outside one.
note_zero <- function(msg) {
  s <- active_state()
  if (!is.null(s)) return(invisible(warn_here(s, weft_env$inline, "printed as zero", msg)))
  rlang::warn(paste0("weft: ", msg), class = "weft_zero_warning")
  invisible(NULL)
}
