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
#' @param x Any value.
#' @param ... One or more checks, as expressions in `.` and the caller's
#'   variables.
#' @return `x`, unchanged.
#' @examples
#' claim(5, . > 1)
#' claim(c(3, 4), sum(.) == 7, all(. > 0))
#' @export
claim <- function(x, ...) {
  frames <- sys.calls()
  checks <- as.list(substitute(list(...)))[-1L]
  # an empty argument, as in `claim(x, )`, is no check (3.1.10)
  empty <- vapply(seq_along(checks),
                  function(k) identical(checks[[k]], quote(expr = )), NA)
  checks <- checks[!empty]
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
  for (k in seq_along(checks)) {
    res <- tryCatch(eval(checks[[k]], env), error = function(e) e)
    if (inherits(res, "error")) {
      # a check that raises an error is a failed check (2.6.1)
      bad <- c(bad, k)
      errs <- c(errs, conditionMessage(res))
      next
    }
    ok <- is.logical(res) && length(res) == 1L && !is.na(res) && res
    if (!ok) {
      bad <- c(bad, k)
      errs <- c(errs, NA_character_)
    }
  }
  if (length(bad)) {
    claim_fail(list(
      checks = written_checks(frames, checks)[bad],
      value = claim_value_text(value),
      errors = errs
    ))
  }
  value
}

# The text of each check. The check as written when the source is kept
# (3.1.4: the srcref of the statement that holds the call, on this frame or
# an enclosing one), else its deparse.
written_checks <- function(frames, checks) {
  dp <- function(e) paste(deparse(e, width.cutoff = 500L), collapse = " ")
  out <- vapply(checks, dp, "")
  done <- rep(FALSE, length(out))
  for (fr in rev(frames)) {
    sr <- attr(fr, "srcref")
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
  s <- paste(deparse(value, width.cutoff = 500L), collapse = " ")
  if (nchar(s) > 80L) s <- paste0(substr(s, 1L, 77L), "...")
  s
}

# The one place a failed claim goes. Outside a knit it stops; a later stage
# switches it to collect the record during a knit (rule 2.4).
claim_fail <- function(record) {
  errs <- record$errors %||% rep(NA_character_, length(record$checks))
  lines <- ifelse(
    is.na(errs),
    sprintf("  check `%s` failed (value: %s)", record$checks, record$value),
    sprintf("  check `%s` raised an error: %s (value: %s)", record$checks,
            errs, record$value)
  )
  weft_abort(
    paste(c(sprintf("weft: %d failed claim%s", length(record$checks),
                    if (length(record$checks) == 1L) "" else "s"), lines),
          collapse = "\n"),
    "weft_claim_failed"
  )
}
