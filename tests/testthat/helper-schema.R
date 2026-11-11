# A small JSON Schema (draft-07 subset) validator for the 2c tests, and the
# YAML view of a document as an editor sees it. Contract: dev/design-2c.md
# "Test plan", `helper-schema.R`, and C20. It interprets exactly the keywords in
# SCHEMA_KEYWORDS and stops (a test failure) on any other.

SCHEMA_KEYWORDS <- c(
  "$schema", "title", "description", "type", "properties", "required",
  "additionalProperties", "propertyNames", "pattern", "enum", "const",
  "minimum", "maximum", "minItems", "minProperties", "items", "anyOf",
  "allOf", "not", "if", "then", "$ref", "definitions"
)

# the YAML as an editor (YAML 1.2) sees it
schema_view <- function(text) {
  text <- paste(text, collapse = "\n")
  boolish <- function(x) if (tolower(x) %in% c("true", "false")) tolower(x) == "true" else x
  x <- yaml::yaml.load(text, handlers = list(
    seq = function(x) structure(as.list(x), json_array = TRUE),
    "bool#yes" = boolish,
    "bool#no" = boolish,
    int = function(x) as.numeric(x),
    "int#oct" = function(x) x,
    "int#hex" = function(x) x
  ))
  if (is.null(x)) x <- structure(list(), names = character())
  x
}

# the JSON type of a value
jtype <- function(x) {
  if (is.null(x)) return("null")
  if (is.list(x)) return(if (isTRUE(attr(x, "json_array"))) "array" else "object")
  if (length(x) != 1L) stop("jtype(): an atomic vector of length ", length(x), " is not a JSON value")
  if (is.logical(x)) return("boolean")
  if (is.numeric(x)) return(if (is.finite(x) && x == round(x)) "integer" else "number")
  if (is.character(x)) return("string")
  stop("jtype(): cannot type a ", class(x)[1])
}

jtype_is <- function(x, type) {
  t <- jtype(x)
  if (identical(type, "number")) t %in% c("number", "integer") else identical(t, type)
}

# keywords outside SCHEMA_KEYWORDS anywhere in a schema (subschemas found by walking)
schema_unknown_keywords <- function(s) {
  if (!is.list(s)) return(character())
  bad <- setdiff(names(s), SCHEMA_KEYWORDS)
  subs <- c(
    unname(s[["properties"]]), unname(s[["definitions"]]),
    list(s[["items"]], s[["propertyNames"]], s[["not"]], s[["if"]], s[["then"]]),
    unname(s[["anyOf"]]), unname(s[["allOf"]]),
    if (is.list(s[["additionalProperties"]])) list(s[["additionalProperties"]])
  )
  for (z in subs) bad <- c(bad, schema_unknown_keywords(z))
  unique(bad)
}

# the problems of `x` against schema `s` (character(); empty means valid)
schema_check <- function(x, s, root = s, path = "$") {
  if (isTRUE(s)) return(character())
  if (isFALSE(s)) return(paste0(path, ": refused by a false schema"))
  if (!is.list(s)) stop("not a schema: ", format(s))
  unknown <- setdiff(names(s), SCHEMA_KEYWORDS)
  if (length(unknown)) stop("schema keyword not interpreted: ", paste(unknown, collapse = ", "))
  err <- character()
  add <- function(...) err <<- c(err, paste0(path, ": ", ...))
  ok <- function(sub, inst = x, p = path) !length(schema_check(inst, sub, root, p))

  if (!is.null(s[["$ref"]])) {
    m <- regmatches(s[["$ref"]], regexec("^#/definitions/(.+)$", s[["$ref"]]))[[1]]
    if (length(m) != 2L) stop("$ref not interpreted: ", s[["$ref"]])
    target <- root[["definitions"]][[m[2]]]
    if (is.null(target)) stop("$ref to nothing: ", s[["$ref"]])
    err <- c(err, schema_check(x, target, root, path))
  }
  if (!is.null(s[["type"]]) && !jtype_is(x, s[["type"]])) add("not of type ", s[["type"]])
  if (!is.null(s[["pattern"]]) && jtype(x) == "string" &&
      !grepl(s[["pattern"]], x, perl = TRUE)) add("does not match ", s[["pattern"]])
  if (!is.null(s[["enum"]]) &&
      !any(vapply(s[["enum"]], function(e) identical(e, x), logical(1)))) add("not in the enum")
  if (!is.null(s[["const"]]) && !identical(s[["const"]], x)) add("is not the const")
  if (jtype(x) %in% c("number", "integer")) {
    if (!is.null(s[["minimum"]]) && x < s[["minimum"]]) add("below the minimum")
    if (!is.null(s[["maximum"]]) && x > s[["maximum"]]) add("above the maximum")
  }
  if (!is.null(s[["minItems"]]) && jtype(x) == "array" && length(x) < s[["minItems"]]) add("too few items")
  if (!is.null(s[["minProperties"]]) && jtype(x) == "object" && length(x) < s[["minProperties"]]) add("too few properties")
  if (jtype(x) == "object") {
    nms <- names(x)
    for (r in unlist(s[["required"]])) if (!(r %in% nms)) add("missing ", r)
    props <- s[["properties"]]
    for (n in intersect(names(props), nms)) {
      err <- c(err, schema_check(x[[n]], props[[n]], root, paste0(path, ".", n)))
    }
    if (!is.null(s[["additionalProperties"]])) {
      for (n in setdiff(nms, names(props))) {
        err <- c(err, schema_check(x[[n]], s[["additionalProperties"]], root, paste0(path, ".", n)))
      }
    }
    if (!is.null(s[["propertyNames"]])) {
      for (n in nms) {
        if (!ok(s[["propertyNames"]], n, paste0(path, "<", n, ">"))) add("property name ", n, " refused")
      }
    }
  }
  if (!is.null(s[["items"]]) && jtype(x) == "array") {
    for (i in seq_along(x)) err <- c(err, schema_check(x[[i]], s[["items"]], root, paste0(path, "[", i, "]")))
  }
  if (!is.null(s[["anyOf"]]) && !any(vapply(s[["anyOf"]], ok, logical(1)))) add("matches no anyOf")
  if (!is.null(s[["allOf"]])) for (sub in s[["allOf"]]) err <- c(err, schema_check(x, sub, root, path))
  if (!is.null(s[["not"]]) && ok(s[["not"]])) add("matches a not")
  if (!is.null(s[["if"]]) && ok(s[["if"]]) && !is.null(s[["then"]])) {
    err <- c(err, schema_check(x, s[["then"]], root, path))
  }
  err
}

schema_file <- function() {
  p <- system.file("dict", "dict.schema.json", package = "weft")
  if (!nzchar(p)) p <- file.path(weft_pkg_root(), "inst", "dict", "dict.schema.json")
  p
}

schema_load <- function() jsonlite::fromJSON(schema_file(), simplifyVector = FALSE)

# the problems of a YAML text against inst/dict/dict.schema.json
schema_errors <- function(text) schema_check(schema_view(text), schema_load())

# TRUE when the YAML text is valid against the shipped schema
schema_ok <- function(text) !length(schema_errors(text))
