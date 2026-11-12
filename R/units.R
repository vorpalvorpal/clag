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

# Whether converting `from` to `to` (both `units` quantities or symbolic units)
# only inverts the value: udunits counts a reciprocal as convertible (metres to
# 1/m). A conversion between two quotients is allowed (L/(100*km) to km/L).
converts_by_inversion <- function(from, to) {
  fu <- if (inherits(from, "units")) attr(from, "units") else from
  tu <- if (inherits(to, "units")) attr(to, "units") else to
  quotient <- function(un) any(un$numerator != "1") && length(un$denominator) > 0L
  if (quotient(fu) && quotient(tu)) return(FALSE)
  one <- units::set_units(1, fu, mode = "standard")
  a <- tryCatch(as.numeric(units::set_units(one, tu, mode = "standard")), error = function(e) NA_real_)
  b <- tryCatch(as.numeric(units::set_units(one * 2, tu, mode = "standard")), error = function(e) NA_real_)
  isTRUE(b < a)
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
#' `u()` registers no unit of its own. The first time weft parses or converts a unit
#' in a session, and each time a configuration is read, it brings the `units`
#' database to weft's default table (see [unit_defaults()]: `pH`, `mph`, `nmi`,
#' `Ma`, `ka`, `gal`, `NTU`, `PSU`, `CFU`, `MPN`, and names for `ppm` and `ppb`)
#' and the project's `units:` rows (rules 4.4.21, 9.1.7); loading weft changes
#' nothing. A unit the `units` database does not know is a `weft_unit_error`; a
#' project's own unit is registered when the dictionary that names it is read
#' (rule 4.4.7), or with [units::install_unit()]. A unit that does not convert, a
#' `value` that is not numeric and a missing `unit` are a `weft_unit_error` too.
#'
#' A unit is kept as written: `u(2, Sv)` holds `Sv`, not the `Gy` the `units`
#' package substitutes, and weft refuses to convert between units the database
#' defines alike (`Sv` and `Gy`, `Bq` and `Hz`, `VA` and `W`). Under
#' `unit_defaults: weft` (the default in `_weft.yml`) a unit the `units` package
#' reads as a prefix and another unit that a report does not mean (`mt` as a
#' millitonne, `kph` as a kilophot) is a `weft_unit_error` whose message says what
#' it was read as and what to write; under `unit_defaults: si` it is read as the
#' `units` package reads it (rule 4.4.20).
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
  u_make(value, txt)
}

# The `units` value for `value` in the unit written `txt` (what u() makes).
u_make <- function(value, txt) {
  bad <- unit_refusal(txt)
  if (!is.null(bad)) unit_abort(sprintf("u(): %s", bad$text))
  parsed <- unit_parse_problem(txt)
  if (!is.null(parsed)) {
    unit_abort(sprintf(paste0(
      "u(): `%s` is not a unit the units database knows. A project's own unit is ",
      "registered when the dictionary that names it is read (rule 4.4.7), or with ",
      "units::install_unit(). The units package says: %s"), txt, parsed))
  }
  to <- tryCatch(unit_symbolic(txt),
                 error = function(e) unit_abort(sprintf("u(): %s", sub("\n.*$", "", conditionMessage(e)))))
  if (inherits(value, "units")) {
    tw <- unit_twin_problem(attr(value, "units"), to, txt)
    if (!is.null(tw)) unit_abort(sprintf("u(): %s (rule 4.4.14).", tw))
  }
  tryCatch(units::set_units(value, to, mode = "standard"),
           error = function(e) unit_abort(sprintf("u(): %s", sub("\n.*$", "", conditionMessage(e)))))
}

# ---- printing (2b) --------------------------------------------------------

# The text of a `units` value's unit (4.4.8), as Pandoc markdown, for a plural
# number under the configuration in force (see unit_symbol_text()). `NULL` when
# no unit is left (a ratio) or `x` is not a quantity.
unit_text <- function(x) {
  if (!inherits(x, "units")) return(NULL)
  unit_symbol_text(attr(x, "units"), TRUE, current_config(), current_lang())
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
  if ((inherits(x, "units") && unit_present(attr(x, "units"))) ||
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
  ref <- unit_refusal(unit)
  if (!is.null(ref)) value_error(sprintf("`unit = %s`: %s", unit, ref$text))
  cannot <- function(e) value_error(sprintf(
    "`unit = %s`: the quantity (%s) cannot be converted to it. %s", unit,
    as.character(attr(x, "units")), sub("\n.*$", "", conditionMessage(e))))
  to <- tryCatch(unit_symbolic(unit), error = cannot)
  tw <- unit_twin_problem(attr(x, "units"), to, unit)
  if (!is.null(tw)) value_error(paste0(tw, " (rule 4.4.14)."))
  out <- tryCatch(units::set_units(x, to, mode = "standard"), error = cannot)
  if (converts_by_inversion(x, out)) {
    value_error(sprintf(paste0(
      "`unit = %s`: the quantity (%s) is of another dimension, which units reaches by inverting the ",
      "value. Write the reciprocal in the expression if that is meant (rule 4.4.14)."),
      unit, as.character(attr(x, "units"))))
  }
  out
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
# no-break space (or first character) of its suffix `suf`, or 0. The unit may be
# inside a text class's markup (`**3 m**`), so only what follows it must be marks.
# A unit written before its number (`before`, 4.4.22) is the first match, and only marks
# may come before it.
unit_at <- function(tx, suf, before = FALSE) {
  suf <- rep_len(suf, length(tx))
  before <- rep_len(before, length(tx))
  vapply(seq_along(tx), function(i) {
    if (!nzchar(suf[i])) return(0L)
    m <- gregexpr(suf[i], tx[i], fixed = TRUE)[[1L]]
    if (m[1L] < 0L) return(0L)
    if (isTRUE(before[i])) {
      pos <- as.integer(m[1L])
      return(if (grepl("[[:alnum:]]", substr(tx[i], 1L, pos - 1L))) 0L else pos)
    }
    pos <- as.integer(m[length(m)])
    if (grepl("[[:alnum:]]", substring(tx[i], pos + nchar(suf[i])))) 0L else pos
  }, 0L)
}

# A weft_text with the unit taken off the elements that carry it; its record
# is kept and the unit attributes go.
strip_unit <- function(x) {
  suf <- attr(x, "unit_suffix")
  tx <- as.character(x)
  if (!is.null(suf)) {
    suf <- rep_len(suf, length(tx))
    pos <- unit_at(tx, suf, attr(x, "unit_before") %||% FALSE)
    hit <- pos > 0L
    tx[hit] <- paste0(substr(tx[hit], 1L, pos[hit] - 1L), substring(tx[hit], pos[hit] + nchar(suf[hit])))
  }
  x[] <- tx
  for (a in c("unit", "units", "unit_form", "unit_suffix", "unit_before")) attr(x, a) <- NULL
  x
}

# Subsetting a weft_text that carries a unit keeps the unit (3.4.7), and the
# record with it.
#' @export
`[.weft_text` <- function(x, i) {
  uf <- attr(x, "unit_form")
  ut <- attr(x, "unit")
  if (is.null(ut) && is.null(uf)) return(unclass_text(x)[i])
  num <- attr(x, "number")
  new <- unclass_text(x)[i]
  at <- function(a) if (length(a) == length(x)) a[i] else NULL
  out <- new_weft_text(new, at(num), at(attr(x, "decimals")), at(attr(x, "relation")), at(attr(x, "raw")))
  attr(out, "unit") <- ut
  attr(out, "units") <- attr(x, "units")
  attr(out, "unit_form") <- at(uf)
  attr(out, "unit_suffix") <- at(attr(x, "unit_suffix"))
  attr(out, "unit_before") <- at(attr(x, "unit_before"))
  out
}

# `x` as the plain character vector `[` gave before there was a method.
unclass_text <- function(x) {
  nm <- names(x)
  out <- as.character(unclass(x))
  names(out) <- nm
  out
}
