# The year class (rule 4.2.1, dev/design-2.md ruling 2, c): `weft_year` is an
# integer underneath. It stays a year through `c()`, `[`, `rev()`, `sort()`,
# `unique()`, `min()`, `max()`, `range()`, `seq()` and `year + n`; any other
# arithmetic gives a plain number. Every number class prints it with no
# thousands mark.

new_weft_year <- function(x) {
  x <- unclass(x)
  if (is.double(x) && all(is.na(x) | (is.finite(x) & x == round(x) & abs(x) < .Machine$integer.max))) {
    storage.mode(x) <- "integer"
  }
  if (!is.integer(x)) return(x)
  class(x) <- "weft_year"
  x
}

plain_year <- function(x) if (inherits(x, "weft_year")) unclass(x) else x

#' A year in a dictionary
#'
#' A `year` entry of a dictionary is a `weft_year`: an integer with a class, so
#' that it keeps its place through `c()`, `[`, `[[`, `rev()`, `sort()`,
#' `unique()`, `min()`, `max()`, `range()` and `seq()`, and `year + n` and
#' `year - n` are years. `year - year` and every other arithmetic give a plain
#' number, and a comparison works as it does on integers. `as.integer()`,
#' `as.numeric()`, `format()` and `print()` show the bare integer. Every number
#' and wording class (`.num`, `.ord`, `.and`, `.range` and the rest) prints a
#' year with no thousands mark.
#'
#' When the vctrs package is loaded, a year combined with an integer or a
#' double gives a plain integer or double, and a year with a year gives a year.
#'
#' @param x,e1,e2,from A `weft_year`, or a value to combine with
#'   one.
#' @param ... Further arguments, passed on.
#' @param na.rm Whether to drop missing values.
#' @param incomparables Not used.
#' @param decreasing Whether to sort downwards.
#' @return A `weft_year`, or a plain number where the text says so.
#' @name weft_year
#' @rdname weft_year
#' @export
c.weft_year <- function(...) {
  r <- do.call(c, lapply(list(...), plain_year))
  new_weft_year(r)
}

#' @rdname weft_year
#' @export
`[.weft_year` <- function(x, ...) new_weft_year(unclass(x)[...])

#' @rdname weft_year
#' @export
`[[.weft_year` <- function(x, ...) new_weft_year(unclass(x)[[...]])

#' @rdname weft_year
#' @export
rev.weft_year <- function(x) x[rev(seq_along(x))]

#' @rdname weft_year
#' @export
sort.weft_year <- function(x, decreasing = FALSE, ...) new_weft_year(sort(unclass(x), decreasing = decreasing, ...))

#' @rdname weft_year
#' @export
unique.weft_year <- function(x, incomparables = FALSE, ...) new_weft_year(unique(unclass(x), ...))

#' @rdname weft_year
#' @export
seq.weft_year <- function(from, ...) {
  args <- lapply(c(list(from = from), list(...)), plain_year)
  new_weft_year(do.call(seq, args))
}

#' @rdname weft_year
#' @export
Summary.weft_year <- function(..., na.rm = FALSE) {
  r <- do.call(.Generic, c(lapply(list(...), plain_year), list(na.rm = na.rm)))
  if (.Generic %in% c("min", "max", "range")) new_weft_year(r) else r
}

#' @rdname weft_year
#' @export
Ops.weft_year <- function(e1, e2) {
  if (missing(e2)) return(get(.Generic)(plain_year(e1)))
  r <- get(.Generic)(plain_year(e1), plain_year(e2))
  y1 <- inherits(e1, "weft_year")
  y2 <- inherits(e2, "weft_year")
  plain_n <- function(z) is.numeric(z) && !is.object(z)
  if ((.Generic == "+" && ((y1 && plain_n(e2)) || (y2 && plain_n(e1)))) ||
      (.Generic == "-" && y1 && plain_n(e2))) {
    return(new_weft_year(r))
  }
  r
}

#' @rdname weft_year
#' @export
Math.weft_year <- function(x, ...) get(.Generic)(unclass(x), ...)

#' @rdname weft_year
#' @export
format.weft_year <- function(x, ...) format(unclass(x), ...)

#' @rdname weft_year
#' @export
print.weft_year <- function(x, ...) {
  print(unclass(x), ...)
  invisible(x)
}

# ---- vctrs (registered when vctrs is loaded; no dependency on it) ----------

vec_ptype2_weft_year_year <- function(x, y, ...) new_weft_year(integer())
vec_ptype2_weft_year_int <- function(x, y, ...) integer()
vec_ptype2_weft_year_dbl <- function(x, y, ...) double()
vec_cast_weft_year_year <- function(x, to, ...) x
vec_cast_int_weft_year <- function(x, to, ...) unclass(x)
vec_cast_dbl_weft_year <- function(x, to, ...) as.double(unclass(x))
vec_cast_weft_year_int <- function(x, to, ...) new_weft_year(x)

register_year_vctrs <- function() {
  s3_register("vctrs::vec_ptype2", "weft_year.weft_year", vec_ptype2_weft_year_year)
  s3_register("vctrs::vec_ptype2", "weft_year.integer", vec_ptype2_weft_year_int)
  s3_register("vctrs::vec_ptype2", "integer.weft_year", vec_ptype2_weft_year_int)
  s3_register("vctrs::vec_ptype2", "weft_year.double", vec_ptype2_weft_year_dbl)
  s3_register("vctrs::vec_ptype2", "double.weft_year", vec_ptype2_weft_year_dbl)
  s3_register("vctrs::vec_cast", "weft_year.weft_year", vec_cast_weft_year_year)
  s3_register("vctrs::vec_cast", "integer.weft_year", vec_cast_int_weft_year)
  s3_register("vctrs::vec_cast", "double.weft_year", vec_cast_dbl_weft_year)
  s3_register("vctrs::vec_cast", "weft_year.integer", vec_cast_weft_year_int)
  invisible()
}

# Delayed S3 registration (the `s3_register()` pattern of the r-lib packages):
# `generic` is "pkg::name"; the method is registered at once if `pkg` is
# loaded, and when it is loaded later otherwise.
s3_register <- function(generic, class, method) {
  pieces <- strsplit(generic, "::", fixed = TRUE)[[1L]]
  package <- pieces[[1L]]
  generic <- pieces[[2L]]
  register <- function(...) {
    ns <- asNamespace(package)
    registerS3method(generic, class, method, envir = ns)
  }
  if (isNamespaceLoaded(package)) register()
  setHook(packageEvent(package, "onLoad"), function(...) register())
  invisible()
}

.onLoad <- function(libname, pkgname) {
  register_year_vctrs()
}

# Unloading weft takes out of the units database what weft installed, and puts back the
# readings it replaced (rule 4.4.21).
.onUnload <- function(libpath) {
  try(ud_unload(), silent = TRUE)
}
