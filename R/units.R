# Quantities (rules 4.4.6): `u()`.

unit_abort <- function(message) weft_abort(message, "weft_unit_error")

#' A number with a unit
#'
#' `u(value, unit)` makes a `units` value. The unit is taken as written and
#' never evaluated as R: `u(35, m)`, `u(5, mg/L)`, `u(1, m^2)`; or it is a
#' string, `u(150, "CFU/100 mL")`. `value` is a numeric vector, or a `units`
#' value, which is converted: `u(dict$core_len, cm)`.
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
  ex <- substitute(unit)
  txt <- if (is.character(ex) && length(ex) == 1L && !is.na(ex)) ex else
    paste(deparse(ex, width.cutoff = 500L), collapse = " ")
  if (!nzchar(trimws(txt))) unit_abort("u(): the unit is blank; write u(35, m).")
  if (!(inherits(value, "units") || (is.numeric(value) && !is.object(value)))) {
    unit_abort(sprintf("u(): the value must be a number or a units value, not a %s.",
                       class(value)[1L]))
  }
  parsed <- tryCatch({ units::as_units(txt); NULL },
                     error = function(e) sub("\n.*$", "", conditionMessage(e)))
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

SUPER_DIGITS <- c("\u2070", "\u00b9", "\u00b2", "\u00b3", "\u2074", "\u2075",
                  "\u2076", "\u2077", "\u2078", "\u2079")

# The text of a `units` value's unit (4.4.8): `units`' own form, exponents in
# superscript characters, `*` as the dot operator. `NULL` when no unit is left
# (a ratio) or `x` is not a quantity.
unit_text <- function(x) {
  if (!inherits(x, "units")) return(NULL)
  un <- attr(x, "units")
  if (!length(un$numerator) && !length(un$denominator)) return(NULL)
  s <- as.character(un, neg_power = FALSE)
  if (!nzchar(s) || identical(s, "1")) return(NULL)
  sup <- function(e) {
    ch <- strsplit(e, "")[[1L]]
    paste0(vapply(ch, function(k) if (k == "-") "\u207b" else SUPER_DIGITS[as.integer(k) + 1L], ""),
           collapse = "")
  }
  m <- gregexpr("\\^-?[0-9]+", s)
  regmatches(s, m) <- lapply(regmatches(s, m), function(p) vapply(substring(p, 2L), sup, ""))
  gsub("*", "\u22c5", s, fixed = TRUE)
}

# The number of a quantity, without its unit; other values pass unchanged.
bare_number <- function(x) {
  if (!inherits(x, "units")) return(x)
  nm <- names(x)
  out <- as.numeric(units::drop_units(x))
  names(out) <- nm
  out
}

# The phrase functions that cannot place a unit (D28).
no_unit <- function(x, fn) {
  if (inherits(x, "units") && !is.null(unit_text(x))) {
    value_error(sprintf(paste0("`%s()` does not take a quantity with a unit; pass the ",
                               "numbers, or format the parts with fmt_num()."), fn))
  }
  bare_number(x)
}

UNIT_SEP <- "\u00a0"

# A weft_text with the unit taken off the elements that end with it; its
# record is kept.
strip_unit <- function(x, ut) {
  suf <- paste0(UNIT_SEP, ut)
  tx <- as.character(x)
  hit <- endsWith(tx, suf)
  tx[hit] <- substr(tx[hit], 1L, nchar(tx[hit]) - nchar(suf))
  x[] <- tx
  attr(x, "unit") <- NULL
  x
}
