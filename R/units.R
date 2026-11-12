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
#' defines alike (`Sv`, `Gy` and `rem`; `Bq`, `Hz` and `Ci`; `VA` and `W`; and `Hz` or `Bq` and an angle per time such as `rpm`), in `of_n()`, `about()` and a
#' `claim()` comparison as in a conversion; arithmetic is left to `units`. Under
#' `unit_defaults: weft` (the default in `_weft.yml`) a unit the `units` package
#' reads as a prefix and another unit that a report does not mean (`mt` as a
#' millitonne, `kt` as a knot, `kph` as a kilophot) is a `weft_unit_error` whose message says what
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
  u_make(value, txt, "u")
}

# The `units` value for `value` in the unit written `txt` (what u() makes).
u_make <- function(value, txt, fn = "u") {
  bad <- unit_refusal(txt)
  if (!is.null(bad)) unit_abort(sprintf("%s(): %s", fn, bad$text))
  parsed <- unit_parse_problem(txt)
  if (!is.null(parsed)) {
    unit_abort(sprintf(paste0(
      "%s(): `%s` is not a unit the units database knows. A project's own unit is ",
      "registered when the dictionary that names it is read (rule 4.4.7), or with ",
      "units::install_unit(). The units package says: %s"), fn, txt, parsed))
  }
  to <- tryCatch(unit_symbolic(txt),
                 error = function(e) unit_abort(sprintf("%s(): %s", fn, sub("\n.*$", "", conditionMessage(e)))))
  if (inherits(value, "units")) {
    tw <- unit_twin_problem(attr(value, "units"), to, txt)
    if (!is.null(tw)) unit_abort(sprintf("%s(): %s (rule 4.4.14).", fn, tw))
  }
  tryCatch(units::set_units(value, to, mode = "standard"),
           error = function(e) unit_abort(sprintf("%s(): %s", fn, sub("\n.*$", "", conditionMessage(e)))))
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

# ---- the unit ladder (4.4.23) ---------------------------------------------------------------------

LADDER_FIT_LO <- 1
LADDER_FIT_HI <- 1000

# The rungs of a ladder, written as one string of units separated by `|` or as a character
# vector of single units, and the problem with them (a construct error's text) or NULL.
# `rungs` are trimmed; `written` is the ladder as the author wrote it. A string with no `|`
# is one rung (as `unit` is today); it is not checked here, so blank and NA stay 4.4.14's.
ladder_split <- function(unit) {
  written <- paste(as.character(unit), collapse = "|")
  bad <- function(msg) list(rungs = character(), written = written, problem = msg)
  if (length(unit) == 1L && !is.na(unit) && !grepl("|", unit, fixed = TRUE)) {
    return(list(rungs = trimws(unit), written = written, problem = NULL))
  }
  if (length(unit) == 1L && !is.na(unit)) {
    rungs <- trimws(strsplit(paste0(unit, "|"), "|", fixed = TRUE)[[1L]])
  } else {
    if (anyNA(unit) || any(!nzchar(trimws(unit))) || any(grepl("|", unit, fixed = TRUE))) {
      return(bad(sprintf(paste0("`unit = %s`: the ladder is one string with `|` between the units, or a ",
                                "vector of single units, with no blank or missing item (rule 4.4.23)."),
                         written)))
    }
    rungs <- trimws(unit)
  }
  if (any(!nzchar(rungs))) {
    return(bad(sprintf(paste0("`unit = %s`: the ladder has an empty rung; separate units with `|`, ",
                              "such as `unit=\"mm|m|km\"` (rule 4.4.23)."), written)))
  }
  if (anyDuplicated(rungs)) {
    return(bad(sprintf("`unit = %s`: `%s` is on the ladder twice (rule 4.4.23).", written,
                       rungs[duplicated(rungs)][1L])))
  }
  list(rungs = rungs, written = written, problem = NULL)
}

# `x` converted to the unit `rung`, `pre` the start of an error's text (`unit = m`: ...).
# `ladder` is TRUE for a rung of a ladder: its twin error then names the ladder too.
convert_one <- function(x, rung, pre, ladder = FALSE) {
  ref <- unit_refusal(rung)
  if (!is.null(ref)) value_error(paste0(pre, ref$text))
  cannot <- function(e) value_error(paste0(pre, sprintf(
    "the quantity (%s) cannot be converted to it. %s",
    as.character(attr(x, "units")), sub("\n.*$", "", conditionMessage(e)))))
  to <- tryCatch(unit_symbolic(rung), error = cannot)
  tw <- unit_twin_problem(attr(x, "units"), to, rung)
  if (!is.null(tw)) {
    # the twin text opens with the unit; a ladder's `pre` already names the rung
    lead <- sprintf("`%s`: ", rung)
    if (ladder && startsWith(tw, lead)) tw <- substring(tw, nchar(lead) + 1L)
    value_error(paste0(if (ladder) pre else "", tw, " (rule 4.4.14)."))
  }
  out <- tryCatch(units::set_units(x, to, mode = "standard"), error = cannot)
  if (converts_by_inversion(x, out)) {
    value_error(paste0(pre, sprintf(paste0(
      "the quantity (%s) is of another dimension, which units reaches by inverting the ",
      "value. Write the reciprocal in the expression if that is meant (rule 4.4.14)."),
      as.character(attr(x, "units")))))
  }
  out
}

# The rungs, among `rungs`, that are the size of an earlier one (factor 1 within 1e-9), as
# the index of the later rung and the earlier rung's.
ladder_same_size <- function(from, rungs) {
  one <- tryCatch(units::set_units(1, from, mode = "standard"), error = function(e) NULL)
  if (is.null(one)) return(NULL)
  f <- vapply(rungs, function(r) {
    tryCatch(as.numeric(units::set_units(one, unit_symbolic(r), mode = "standard")), error = function(e) NA_real_)
  }, 0)
  for (j in seq_along(rungs)[-1L]) {
    for (i in seq_len(j - 1L)) {
      if (is.finite(f[i]) && is.finite(f[j]) && f[i] != 0 && abs(f[j] / f[i] - 1) < 1e-9) return(c(i, j))
    }
  }
  NULL
}

# The index of the rung a ladder picks (rule 4.4.23). `nums` holds the quantity's numbers in
# each rung. They are tested as the number stage prints them (`.num`, with the use's `digits`,
# `sigfig` and `.range`).
#  1. With a class that spells the number (`.word`, `.count`) only a rung that prints every number
#     whole is eligible, if any is.
#  2. A rung that prints an element that is not zero as zero is passed over when another rung
#     prints none as zero.
#  3. The rung with most elements in the window 1 up to 1,000; ties to the earlier rung.
#  4. With none: by the largest value alone, a rung that prints it at 1,000 or more before one that
#     prints it below 1 (the smallest such number; else the largest below 1); ties to the earlier.
ladder_pick <- function(nums, classes, keys, cfg) {
  fin <- is.finite(nums[[1L]])
  if (!any(fin)) return(1L)
  range <- ".range" %in% classes
  shown <- lapply(nums, function(v) abs(attr(format_numbers(v[fin], ".num", keys, cfg, range = range, quantity = TRUE), "number")))
  ok <- rep(TRUE, length(nums))
  if (any(c(".word", ".count") %in% classes)) {
    whole <- vapply(shown, function(a) all(!is.na(a) & a == round(a)), NA)
    if (any(whole)) ok <- whole
  }
  zeroed <- vapply(seq_along(nums), function(j) sum(shown[[j]] == 0 & abs(nums[[j]][fin]) > 0), 0L)
  if (any(ok & zeroed == 0L) && any(ok & zeroed > 0L)) ok <- ok & zeroed == 0L
  cand <- which(ok)
  fits <- vapply(shown[cand], function(a) sum(a >= LADDER_FIT_LO & a < LADDER_FIT_HI), 0L)
  if (max(fits) > 0L) return(cand[which(fits == max(fits))[1L]])
  big <- which.max(abs(nums[[1L]][fin]))
  a <- vapply(shown[cand], function(s) s[big], 0)
  hi <- a >= LADDER_FIT_HI
  if (any(hi)) return(cand[hi][which.min(a[hi])])
  cand[which.max(a)]
}

# The rung, if any, whose conversion from `x`'s unit has an offset (degC, degF, K among themselves):
# zero in the quantity's unit is not zero in the rung.
ladder_offset <- function(from, rungs) {
  zero <- tryCatch(units::set_units(0, from, mode = "standard"), error = function(e) NULL)
  if (is.null(zero)) return(NULL)
  for (r in rungs) {
    z <- tryCatch(as.numeric(units::set_units(zero, unit_symbolic(r), mode = "standard")), error = function(e) NA_real_)
    if (is.finite(z) && abs(z) > 1e-9) return(r)
  }
  NULL
}

# `x` converted to the unit `unit` for the `unit` key (4.4.14): one unit (a string), or a ladder
# (4.4.23) of which every rung is checked and one is picked by the number as printed. `on_pick`,
# when given, is called with the rung picked, the quantity in it and the rungs.
convert_unit <- function(x, unit, classes = character(), keys = list(), cfg = current_config(),
                         on_pick = NULL, form = NULL) {
  if (!inherits(x, "units")) {
    value_error(sprintf("`unit = %s` needs a quantity (see u()); the value is of class %s.",
                        paste(as.character(unit), collapse = "|"), class(x)[1L]))
  }
  if (!is.character(unit) || length(unit) < 1L ||
      (length(unit) == 1L && (is.na(unit) || !nzchar(trimws(unit))))) {
    value_error(paste0("`unit` must be a string that names a unit, such as \"m\", or a character vector of ",
                       "units, which is a ladder (rule 4.4.23)."))
  }
  lad <- ladder_split(unit)
  if (!is.null(lad$problem)) construct_error(lad$problem)
  rungs <- lad$rungs
  if (length(rungs) == 1L) {
    out <- convert_one(x, rungs, sprintf("`unit = %s`: ", unit))
    if (!is.null(on_pick)) on_pick(rungs, out, rungs)
    return(out)
  }
  if (identical(form, "none")) {
    value_error(sprintf(paste0("`unit = %s` is a ladder, and the unit is not printed (`.nounit`, `unit_form = \"none\"`): ",
                               "the reader could not tell which unit the number is in. Name one unit (rule 4.4.23)."),
                        lad$written))
  }
  outs <- lapply(rungs, function(r) convert_one(x, r, sprintf("`unit = %s`: rung `%s`: ", lad$written, r), TRUE))
  off <- ladder_offset(attr(x, "units"), rungs)
  if (!is.null(off)) {
    value_error(sprintf(paste0("`unit = %s`: rung `%s`: the quantity (%s) and the rung differ by an offset, and a window of ",
                               "1 up to 1,000 means nothing across an offset; name one unit (rule 4.4.23)."),
                        lad$written, off, as.character(attr(x, "units"))))
  }
  same <- ladder_same_size(attr(x, "units"), rungs)
  if (!is.null(same)) {
    value_error(sprintf(paste0("`unit = %s`: `%s` and `%s` are the same size, so `%s` could never be ",
                               "picked; keep one (rule 4.4.23)."),
                        lad$written, rungs[same[1L]], rungs[same[2L]], rungs[same[2L]]))
  }
  i <- ladder_pick(lapply(outs, as.numeric), classes, keys, cfg)
  if (!is.null(on_pick)) on_pick(rungs[i], outs[[i]], rungs)
  outs[[i]]
}

# `b` as bare numbers in the unit of `a`, when both are quantities; an error
# when they do not convert (3.5.7). Anything else passes unchanged.
match_units <- function(a, b, fn) {
  if (inherits(a, "units") && inherits(b, "units")) {
    tw <- unit_twin_problem(attr(b, "units"), attr(a, "units"), as.character(attr(a, "units")))
    if (!is.null(tw)) value_error(paste0(tw, " (rule 4.4.14)."))
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
  if (is.null(ut) && is.null(uf)) {
    out <- unclass_text(x)[i]
    # a unit's symbol keeps its case, and a text keeps the classes it has had, through `[` (4.4.8)
    if (isTRUE(attr(x, "is_symbol")) || !is.null(attr(x, "text_classes"))) {
      out <- structure(out, class = c("weft_text", "character"))
      for (a in c("is_symbol", "text_classes")) attr(out, a) <- attr(x, a)
    }
    return(out)
  }
  num <- attr(x, "number")
  new <- unclass_text(x)[i]
  at <- function(a) if (length(a) == length(x)) a[i] else NULL
  out <- new_weft_text(new, at(num), at(attr(x, "decimals")), at(attr(x, "relation")), at(attr(x, "raw")))
  attr(out, "unit") <- ut
  attr(out, "units") <- attr(x, "units")
  attr(out, "unit_form") <- at(uf)
  attr(out, "unit_suffix") <- at(attr(x, "unit_suffix"))
  attr(out, "unit_before") <- at(attr(x, "unit_before"))
  for (a in c("is_symbol", "text_classes")) attr(out, a) <- attr(x, a)
  out
}

# `c()` of texts of a unit's symbol keeps the symbol's case (4.4.8); any other `c()` gives the plain
# character vector it always did.
#' @export
c.weft_text <- function(...) {
  args <- list(...)
  out <- unlist(lapply(args, function(a) if (inherits(a, "weft_text")) unclass_text(a) else a), use.names = TRUE)
  if (length(args) && all(vapply(args, function(a) inherits(a, "weft_text") && isTRUE(attr(a, "is_symbol")), NA))) {
    out <- structure(as.character(out), class = c("weft_text", "character"), is_symbol = TRUE)
  }
  out
}

# `x` as the plain character vector `[` gave before there was a method.
unclass_text <- function(x) {
  nm <- names(x)
  out <- as.character(unclass(x))
  names(out) <- nm
  out
}
