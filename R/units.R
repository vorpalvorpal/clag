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
