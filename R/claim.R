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
  checks <- as.list(substitute(list(...)))[-1L]
  if (length(checks) == 0L) {
    weft_abort(paste0(
      "`claim(x)` has no check (rule 3.1.10); write the check as a second ",
      "argument, for example `claim(x, . > 0)`."), "weft_claim_no_check")
  }
  value <- x
  env <- new.env(parent = parent.frame())
  assign(".", value, envir = env)
  failed <- character()
  for (ck in checks) {
    res <- eval(ck, env)
    ok <- is.logical(res) && length(res) == 1L && !is.na(res) && res
    if (!ok) failed <- c(failed, paste(deparse(ck, width.cutoff = 500L), collapse = " "))
  }
  if (length(failed)) {
    claim_fail(list(
      checks = failed,
      value = claim_value_text(value)
    ))
  }
  value
}

claim_value_text <- function(value) {
  s <- paste(deparse(value, width.cutoff = 500L), collapse = " ")
  if (nchar(s) > 80L) s <- paste0(substr(s, 1L, 77L), "...")
  s
}

# The one place a failed claim goes. Outside a knit it stops; a later stage
# switches it to collect the record during a knit (rule 2.4).
claim_fail <- function(record) {
  lines <- sprintf("  check `%s` failed (value: %s)", record$checks, record$value)
  weft_abort(
    paste(c(sprintf("weft: %d failed claim%s", length(record$checks),
                    if (length(record$checks) == 1L) "" else "s"), lines),
          collapse = "\n"),
    "weft_claim_failed"
  )
}
