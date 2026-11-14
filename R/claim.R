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
#' @param decision `NULL` (the default), one string that is not blank, or one
#'   whole number from 1: the decision the check rests on. It must be given by
#'   name. A failure's message ends with `; decision <value>`, and `verify()`
#'   checks that the pointer resolves (rule 1.8.12). Anything else is an error
#'   of class `weft_claim_decision`.
#' @return `x`, unchanged.
#' @examples
#' claim(5, . > 1)
#' claim(c(3, 4), sum(.) == 7, all(. > 0))
#' @export
claim <- function(x, ..., level = c("fail", "warn"), decision = NULL) {
  frames <- sys.calls()
  decision <- claim_decision(decision)
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
  res <- claim_run_checks(checks, value, parent.frame())
  bad <- which(!res$ok)
  errs <- res$errs[bad]
  lens <- res$lens[bad]
  hints <- res$hints[bad]
  if (length(bad)) {
    claim_fail(list(
      checks = written_checks(frames, checks, weft_env$inline$expr)[bad],
      value = claim_value_text(value),
      errors = errs,
      lens = lens,
      hints = hints,
      decision = decision
    ), level)
  }
  value
}

# The decision of a claim() as text, or NULL when there is none; anything that is not one string that
# is not blank, or one whole number from 1, is E52 (N103).
claim_decision <- function(d) {
  if (is.null(d)) return(NULL)
  if (is.character(d) && length(d) == 1L && !is.na(d) && nzchar(trimws(d))) return(d)
  if (is.numeric(d) && length(d) == 1L && !is.na(d) && is.finite(d) && d >= 1 && d == round(d) &&
      is.null(dim(d))) {
    return(format(d, scientific = FALSE, trim = TRUE))
  }
  weft_abort("`decision` of claim() must be one string that is not blank, or a whole number from 1.",
             "weft_claim_decision")
}

# Run each check of a `claim()` on `value`, in a child of `penv` where `.` is the
# value. Returns, for every check, whether it passed (`ok`), the message of the
# error it raised (`errs`), the length of a result that was not a single value
# (`lens`) and a hint (`hints`); the last three are NA where they do not apply.
# `weft_put()` runs the checks of a claim it captures by this same function.
claim_run_checks <- function(checks, value, penv) {
  env <- new.env(parent = penv)
  assign(".", value, envir = env)
  # a comparison of two quantities in twin units (Sv and Gy) is a value error, not a failed check (4.4.14)
  for (op in c(">", "<", ">=", "<=", "==", "!=")) assign(op, twin_safe_compare(op), envir = env)
  n <- length(checks)
  ok <- rep(TRUE, n)
  errs <- rep(NA_character_, n)
  lens <- rep(NA_integer_, n)
  hints <- rep(NA_character_, n)
  for (k in seq_len(n)) {
    res <- tryCatch(eval(checks[[k]], env), error = function(e) e)
    if (inherits(res, "weft_unit_twin")) stop(res)
    if (inherits(res, "error")) {
      # a check that raises an error is a failed check (2.6.1)
      ok[k] <- FALSE
      errs[k] <- conditionMessage(res)
      if (grepl("both operands of the expression should be \"units\" objects",
                conditionMessage(res), fixed = TRUE)) {
        hints[k] <- "state the check's unit, as in . < u(0.45, ug) (rule 4.4.5)"
      }
      next
    }
    if (!(is.logical(res) && length(res) == 1L && !is.na(res) && res)) {
      ok[k] <- FALSE
      # a check that returns a vector is not a single TRUE (3.1.3): say how
      # many values it returned
      if (length(res) != 1L) lens[k] <- length(res)
    }
  }
  list(ok = ok, errs = errs, lens = lens, hints = hints)
}

# The comparison `op`, which refuses two quantities in units the units package defines alike.
twin_safe_compare <- function(op) {
  f <- get(op, envir = baseenv(), mode = "function")
  function(e1, e2) {
    if (inherits(e1, "units") && inherits(e2, "units")) {
      tw <- unit_twin_problem(attr(e2, "units"), attr(e1, "units"), as.character(attr(e1, "units")))
      if (!is.null(tw)) {
        rlang::abort(paste0(tw, " (rule 4.4.14)."), class = c("weft_unit_twin", "weft_value_error", "weft_error"),
                     call = NULL)
      }
    }
    f(e1, e2)
  }
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
  s <- if (inherits(value, c("Date", "POSIXt", "factor", "difftime", "units"))) {
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
  hints <- record$hints %||% rep(NA_character_, length(record$checks))
  detail <- ifelse(
    !is.na(errs),
    sprintf("%s raised an error: %s (value %s)", record$checks, errs, record$value),
    ifelse(
      !is.na(lens),
      sprintf("%s returned %d values, not a single TRUE (value %s); write all(%s) to require every element",
              record$checks, lens, record$value, record$checks),
      sprintf("%s was FALSE (value %s)", record$checks, record$value)))
  # N103: the decision ends the detail
  dec <- if (is.null(record$decision)) "" else paste0("; decision ", record$decision)
  detail <- paste0(detail, dec)
  s <- active_state()
  inl <- weft_env$inline
  if (identical(level, "warn")) return(claim_warn(record, detail, s, inl, errs, lens, hints))
  if (!is.null(s) && !is.null(inl)) {
    for (k in seq_along(detail)) {
      add_failure(s, "failed claim", file = inl$file, line = inl$line,
                  expr = inl$label, detail = detail[k], hint = hints[k], chunk = inl$chunk %||% NA_character_,
                  option = inl$option %||% NA_character_)
    }
    inl$failed <- TRUE
    weft_env$inline <- inl
    return(invisible(NULL))
  }
  if (!is.null(s) && claim_collects_in_chunk()) {
    label <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    for (k in seq_along(detail)) {
      add_failure(s, "failed claim", file = current_file_name(s),
                  chunk = if (is.null(label)) NA_character_ else label,
                  detail = detail[k], hint = hints[k], expr = NA_character_)
    }
    s$claims_collected <- (s$claims_collected %||% 0L) + length(detail)
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
  lines <- ifelse(is.na(hints), paste0(lines, dec), paste0(lines, dec, "\n    ", hints))
  msg <- paste(c(sprintf("weft: %d failed claim%s", length(record$checks),
                         if (length(record$checks) == 1L) "" else "s"), lines),
               collapse = "\n")
  if (!is.null(s)) {
    label <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    for (k in seq_along(detail)) {
      add_failure(s, "failed claim", file = current_file_name(s),
                  chunk = if (is.null(label)) NA_character_ else label,
                  detail = detail[k], hint = hints[k],
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

# Whether a failed claim in chunk code is recorded and the knit goes on (N70, N71, N72):
# the setting is `collect`, and no `targets` target is running. A worker process has no
# knit state, so it never gets here.
claim_collects_in_chunk <- function() {
  if (!identical(current_config()$chunk_claims, "collect")) return(FALSE)
  if (requireNamespace("targets", quietly = TRUE) &&
      isTRUE(tryCatch(targets::tar_active(), error = function(e) FALSE))) return(FALSE)
  TRUE
}

# The error a knit is about to stop on, as a `weft_claims_collected` condition when claims were
# collected in chunk code in this knit (N74, E31); else the error itself.
wrap_collected_error <- function(s, e) {
  n <- s$claims_collected %||% 0L
  if (n < 1L) return(e)
  fr <- failures_frame(s)
  root <- state_root(s)
  if (!is.na(root)) fr <- rbind(collected_failures(root), fr)
  msg <- paste(c(
    sprintf(paste0("weft: the knit stopped on an error after %d failed claim%s in chunk code. ",
                   "The claims are listed first: the error may follow from a value that failed its claim."),
            n, if (n == 1L) "" else "s"),
    format_report(fr),
    "The error that stopped the knit:",
    paste0("  ", conditionMessage(e))), collapse = "\n")
  tryCatch(weft_abort(msg, "weft_claims_collected", parent = e), error = function(w) w)
}

# A warned check (entry 31): in a knit it is recorded and nothing else
# happens; outside a knit it is a warning of class `weft_claim_warning`.
claim_warn <- function(record, detail, s, inl, errs, lens, hints = rep(NA_character_, length(detail))) {
  if (!is.null(s)) {
    for (k in seq_along(detail)) warn_here(s, inl, "failed claim", detail[k], hints[k])
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
  dec <- if (is.null(record$decision)) "" else paste0("; decision ", record$decision)
  lines <- ifelse(is.na(hints), paste0(lines, dec), paste0(lines, dec, "\n    ", hints))
  for (l in lines) weft_warn(paste0("weft: ", l), class = "weft_claim_warning")
  invisible(NULL)
}

# Record a warned check where the code that raised it is: the inline code
# being run, else the chunk (entry 31).
warn_here <- function(s, inl, kind, detail, hint = NA_character_) {
  if (!is.null(inl)) {
    add_warning(s, kind, file = inl$file, line = inl$line,
                expr = inl$label, detail = detail, hint = hint, chunk = inl$chunk %||% NA_character_,
                option = inl$option %||% NA_character_)
  } else {
    label <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    add_warning(s, kind, file = current_file_name(s),
                chunk = if (is.null(label)) NA_character_ else label, detail = detail,
                hint = hint, expr = NA_character_)
  }
}

# A number that printed as zero (stage 1i), from `fmt_num()`, `fmt_pct()` and
# the like: a warned check in a knit, a `weft_zero_warning` outside one.
note_zero <- function(msg) {
  s <- active_state()
  if (!is.null(s)) return(invisible(warn_here(s, weft_env$inline, "printed as zero", msg)))
  weft_warn(paste0("weft: ", msg), class = "weft_zero_warning")
  invisible(NULL)
}
