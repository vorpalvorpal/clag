#' @title About pluralization in clag
#' @description Functions to handle pluralization in clag templates
#' @name pluralization
NULL

#' Helper function to determine quantity from an object
#'
#' @param object Object to extract quantity from
#' @return Numeric quantity
#' @noRd
make_quantity <- function(object) {
  val <- if (is.numeric(object)) {
    if (length(object) == 1 && is.finite(object))
      as.integer(object)
    else
      object
  } else {
    length(object)
  }
  return(val)
}

#' Process a pluralization directive with a given quantity
#'
#' @param qty Quantity
#' @param code Pluralization directive
#' @return Processed plural text
#' @noRd
process_plural <- function(qty, code) {
  parts <- strsplit(str_tail(code), "/", fixed = TRUE)[[1]]
  if (last_character(code) == "/") parts <- c(parts, "")

  if (length(parts) == 1) {
    if (is.finite(qty) & qty == 1) "" else parts[1]
  } else if (length(parts) == 2) {
    if (is.finite(qty) & qty == 1)
      parts[1]
    else
      parts[2]
  } else if (length(parts) == 3) {
    if (is.finite(qty) & qty == 0) {
      parts[1]
    } else if (is.finite(qty) & qty == 1) {
      parts[2]
    } else {
      parts[3]
    }
  } else {
    cli::cli_abort(c(
      "Invalid pluralization directive: `{code}`",
      "i" = "Pluralization directives support at most 3 options",
      "i" = "Format options: {.code {?s}} (suffix), {.code {?singular/plural}}, or {.code {?zero/one/many}}",
      "x" = "Found {length(parts)} options in {.code {code}}",
      ">" = "Use one of the standard formats: {.code {?s}}, {.code {?is/are}}, or {.code {?no/one/many}}"
    ))
  }
}

#' Post-process pluralization markers in a string
#'
#' @param str String with pluralization markers
#' @param values Environment with pluralization state
#' @return Processed string
#' @noRd
post_process_plurals <- function(str, values) {
  if (!values$postprocess) return(str)

  if (values$num_subst == 0) {
    cli::cli_abort(c(
      "Cannot pluralize without a quantity",
      "i" = "Each pluralization directive {?s} needs an associated quantity expression {n}",
      "x" = "There was no quantity expression found for the {?} directive",
      ">" = "Use {.code clag(\"Found {{n}} file{{?s}}\")} with a defined variable {.var n}"
    ))
  }

  # For compatibility with cli::pluralize, enforce a single quantity
  if (values$num_subst > 1) {
    cli::cli_abort(c(
      "Multiple pluralisations linked to a single quantity",
      "i" = "Each quantity should determine pluralisation of exactly one string",
      "x" = "Found {values$num_subst} strings relying on a single quantity",
      ">" = "Use the {.fn qty} function to explictly set the quantity of a string without the quantity appearing in the output. eg:",
      ">" = "{.code clag(\"There {{qty(2)}}{{?is/are}} {{2}} {{?box/boxes}} and {{1}} {{?bag/bags}}\")}"
    ))
  }

  # Use the quantity
  qty <- make_quantity(values$qty)

  for (i in seq_along(values$pmarkers)) {
    mark <- values$pmarkers[i]
    str <- sub(names(mark), process_plural(qty, mark[[1]]), str)
  }

  str
}

#' Format numeric zero as "no"
#'
#' @param expr Expression that evaluates to numeric
#' @return The value with special formatting for zero
#' @export
#' @examples
#' nfile <- 0
#' clag("Found {no(nfile)} file{?s}.")
#' # "Found no files."
#'
#' nfile <- 1
#' clag("Found {no(nfile)} file{?s}.")
#' # "Found 1 file."
no <- function(expr) {
  if (is.numeric(expr) && length(expr) == 1 && expr == 0) {
    return("no")
  } else {
    return(expr)
  }
}

#' Set quantity for pluralization without displaying it
#'
#' @param expr Expression that sets the quantity
#' @return Empty string
#' @export
#' @examples
#' nupd <- 3
#' ntotal <- 10
#' clag("{nupd}/{ntotal} {qty(nupd)} file{?s} {?needs/need} updates")
#' # "3/10 files need updates"
qty <- function(expr) {
  # This will be processed by the transformer
  # but won't display anything
  structure(expr, class = "qty_marker")
}

#' @export
as.character.qty_marker <- function(x, ...) {
  ""
}
