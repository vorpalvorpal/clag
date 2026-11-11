# Quantities (rules 4.4.6): `u()`.

unit_abort <- function(message) weft_abort(message, "weft_unit_error")

# Why `txt` is not a unit the units package can read, or NULL. A string it
# cannot parse is a problem, not the warning and the symbolic unit that
# units::as_units() gives (4.4.7).
unit_parse_problem <- function(txt) {
  if (grepl("\\^[ ]*[(]?[ ]*[+-]?[0-9]*[.][0-9]|\\^[ ]*[(][^)]*/", txt)) {
    return(sprintf("a power that is not a whole number (%s) is not supported (rule 4.4.6)", txt))
  }
  warned <- NULL
  r <- withCallingHandlers(
    tryCatch({ units::as_units(txt); NULL },
             error = function(e) sub("\n.*$", "", conditionMessage(e))),
    warning = function(w) {
      warned <<- sub("\n.*$", "", conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  r %||% warned
}

#' A number with a unit
#'
#' `u(value, unit)` makes a `units` value. The unit is taken as written and
#' never evaluated as R: `u(35, m)`, `u(5, mg/L)`, `u(1, m^2)`; or it is a
#' string, `u(150, "CFU/100 mL")`. `value` is a numeric vector, or a `units`
#' value, which is converted: `u(dict$core_len, cm)`.
#'
#' A unit held in a variable cannot be given to `u()`, which takes it as
#' written; `do.call(u, list(3, "m"))` does that, and so does
#' `units::set_units(x, un, mode = "standard")`. `u()` makes a quantity, and
#' weft cannot stop base R's `%in%`, `match()`, `cut()` and `findInterval()`
#' from comparing one with a bare number, as they work on the bare numbers
#' (rule 4.4.5 is kept by `claim()` and the comparison operators only).
#'
#' `u()` does not register units. A unit the `units` database does not know is
#' a `weft_unit_error`; a project's own unit is registered when the
#' dictionary that names it is read (rule 4.4.7), or with
#' [units::install_unit()]. A unit that does not convert, a `value` that is
#' not numeric and a missing `unit` are a `weft_unit_error` too.
#'
#' @param value A numeric vector or a `units` value.
#' @param unit A unit expression, written as it is, or a string.
#' @return A `units` value.
#' @importFrom units set_units
#' @examples
#' u(35, m)
#' u(5, mg/L)
#' @export
u <- function(value, unit) {
  if (missing(unit)) unit_abort("u(): the unit is missing; write u(35, m).")
  if (missing(value)) unit_abort("u(): the value is missing; write u(35, m).")
  ex <- substitute(unit)
  txt <- if (is.character(ex) && length(ex) == 1L && !is.na(ex)) ex else
    paste(deparse(ex, width.cutoff = 500L), collapse = " ")
  if (!nzchar(trimws(txt))) unit_abort("u(): the unit is blank; write u(35, m).")
  if (!(inherits(value, "units") || (is.numeric(value) && !is.object(value)))) {
    unit_abort(sprintf("u(): the value must be a number or a units value, not a %s.",
                       class(value)[1L]))
  }
  parsed <- unit_parse_problem(txt)
  if (!is.null(parsed)) {
    unit_abort(sprintf(paste0(
      "u(): `%s` is not a unit the units database knows. A project's own unit is ",
      "registered when the dictionary that names it is read (rule 4.4.7), or with ",
      "units::install_unit(). The units package says: %s"), txt, parsed))
  }
  tryCatch(units::set_units(value, txt, mode = "standard"),
           error = function(e) unit_abort(sprintf("u(): %s", sub("\n.*$", "", conditionMessage(e)))))
}

# ---- printing (2b) --------------------------------------------------------

# The text of a `units` value's unit (4.4.8), as Pandoc markdown: an exponent
# is a superscript (`m^2^`, `m^\u22123^`), a product is the middle dot, a unit
# with no numerator is written with negative powers, and the characters
# markdown reads are escaped. `NULL` when no unit is left (a ratio) or `x` is
# not a quantity.
unit_text <- function(x) {
  if (!inherits(x, "units")) return(NULL)
  un <- attr(x, "units")
  if (!length(un$numerator) && !length(un$denominator)) return(NULL)
  s <- as.character(un, neg_power = !length(un$numerator))
  if (!nzchar(s) || identical(s, "1")) return(NULL)
  # escape what markdown reads; the exponent marks are written back
  s <- gsub("([\\_~`^]|\\[|\\])", "\\\\\\1", s, perl = TRUE)
  s <- gsub("\\\\\\^(-?)([0-9]+)", "^\\1\\2^", s, perl = TRUE)
  s <- gsub("\\^-", "^\u2212", s, perl = TRUE)
  gsub("*", "\u00b7", s, fixed = TRUE)
}

# The number of a quantity, without its unit; other values pass unchanged.
bare_number <- function(x) {
  if (!inherits(x, "units")) return(x)
  nm <- names(x)
  out <- as.numeric(units::drop_units(x))
  names(out) <- nm
  out
}

# The phrase functions that cannot place a unit (D28). A formatter's text that
# carries a unit is a quantity to them (3.5.7).
no_unit <- function(x, fn) {
  if ((inherits(x, "units") && !is.null(unit_text(x))) ||
      (inherits(x, "weft_text") && !is.null(attr(x, "unit")))) {
    value_error(sprintf(paste0("`%s()` does not take a quantity with a unit; pass the ",
                               "numbers, or format the parts with fmt_num()."), fn))
  }
  bare_number(x)
}

# One unit for one vector: a list of quantities and a `mixed_units` vector are
# a value error (4.4.12).
check_one_unit <- function(x) {
  if (inherits(x, "mixed_units") ||
      (is.list(x) && !is.object(x) && any(vapply(x, inherits, NA, "units")))) {
    value_error(paste0("A list of quantities, or a vector of mixed units, cannot be printed: ",
                       "weft prints one unit for one vector (rule 4.4.12)."))
  }
  invisible(x)
}

# `x` converted to the unit `unit` (a string), for the `unit` key (4.4.14).
convert_unit <- function(x, unit) {
  if (!inherits(x, "units")) {
    value_error(sprintf("`unit = %s` needs a quantity (see u()); the value is of class %s.",
                        as.character(unit)[1L], class(x)[1L]))
  }
  if (!is.character(unit) || length(unit) != 1L || is.na(unit) || !nzchar(trimws(unit))) {
    value_error("`unit` must be one string that names a unit, such as \"m\" (rule 4.4.14).")
  }
  tryCatch(units::set_units(x, unit, mode = "standard"),
           error = function(e) value_error(sprintf(
             "`unit = %s`: the quantity (%s) cannot be converted to it. %s", unit,
             as.character(attr(x, "units")), sub("\n.*$", "", conditionMessage(e)))))
}

# `b` as bare numbers in the unit of `a`, when both are quantities; an error
# when they do not convert (3.5.7). Anything else passes unchanged.
match_units <- function(a, b, fn) {
  if (inherits(a, "units") && inherits(b, "units")) {
    b <- tryCatch(units::set_units(b, attr(a, "units"), mode = "standard"),
                  error = function(e) value_error(sprintf(
                    "%s(): the two quantities are in units that do not convert to each other (%s and %s).",
                    fn, as.character(attr(a, "units")), as.character(attr(b, "units")))))
  }
  b
}

UNIT_SEP <- "\u00a0"

# Where the unit is in each element of a weft_text: the position of the
# no-break space before it, or 0. The unit may be inside a text class's markup
# (`**3 m**`), so only what follows it must be marks.
unit_at <- function(tx, ut) {
  suf <- paste0(UNIT_SEP, ut)
  pos <- as.integer(regexpr(suf, tx, fixed = TRUE))
  rest <- substring(tx, ifelse(pos > 0L, pos + nchar(suf), 1L))
  ifelse(pos > 0L & !grepl("[[:alnum:]]", rest), pos, 0L)
}

# A weft_text with the unit taken off the elements that carry it; its record
# is kept.
strip_unit <- function(x, ut) {
  suf <- paste0(UNIT_SEP, ut)
  tx <- as.character(x)
  pos <- unit_at(tx, ut)
  hit <- pos > 0L
  tx[hit] <- paste0(substr(tx[hit], 1L, pos[hit] - 1L), substring(tx[hit], pos[hit] + nchar(suf)))
  x[] <- tx
  attr(x, "unit") <- NULL
  x
}

# Subsetting a weft_text that carries a unit keeps the unit (3.4.7), and the
# record with it.
#' @export
`[.weft_text` <- function(x, i) {
  ut <- attr(x, "unit")
  if (is.null(ut)) return(unclass_text(x)[i])
  num <- attr(x, "number")
  new <- unclass_text(x)[i]
  at <- function(a) if (length(a) == length(x)) a[i] else NULL
  out <- new_weft_text(new, at(num), at(attr(x, "decimals")), at(attr(x, "relation")), at(attr(x, "raw")))
  attr(out, "unit") <- ut
  out
}

# `x` as the plain character vector `[` gave before there was a method.
unclass_text <- function(x) {
  nm <- names(x)
  out <- as.character(unclass(x))
  names(out) <- nm
  out
}
