# weft_str() (rules 1.10.10, 3.6, 2.4.1, 2.6.8) and the strings it shares its
# machinery with: a caption is resolved by the same function (2.3).

#' Resolve markup in a string
#'
#' `weft_str()` resolves weft's constructs in a character vector from R code:
#' the text of a `results = "asis"` chunk, the `caption` of `knitr::kable()`,
#' the labels of a plot (rule 1.10.10). Each element is resolved as a block of
#' prose and the result is returned as markdown text, in the same length.
#' Constructs are evaluated in the caller's environment.
#'
#' During a knit with weft active a failed check, a missing value or a value
#' error is collected as it is in prose (rules 2.4.1, 3.6.3) and marked in the
#' text with the chunk that holds the call (rule 2.6.8). Outside a knit, and
#' in a knit where `weft_setup()` was not called, the first failure stops at
#' once, with the class of the failure (`weft_claim_failed`, `weft_no_value`,
#' `weft_value_error`, `weft_construct_error`). A `_weft.yml` with an error is a
#' `weft_config_error` outside a knit as in one.
#'
#' Block-only constructs do not apply; each element is read as inline markup.
#' Bare inline R in a string is evaluated as knitr evaluates it (rule 1.1.8).
#'
#' @param x A character vector of markup.
#' @return A character vector of the same length: markdown text.
#' @examples
#' n_sites <- 3
#' weft_str("Found [a site | # sites]{n=\"n_sites\"}.")
#' @export
weft_str <- function(x) {
  env <- parent.frame()
  if (is.factor(x)) x <- as.character(x)
  if (!is.character(x)) {
    weft_abort("`weft_str()` takes a character vector of markup.", "weft_construct_error")
  }
  s <- string_state()
  strict <- !isTRUE(s$live)
  # called from inline R in prose, the string is prose where it is called
  # from: it is located by that line, not by the chunk knitr last ran (3.6.3)
  inl <- weft_env$inline
  in_prose <- !strict && !is.null(inl) && !is.na(inl$line %||% NA_integer_) &&
    is.na(inl$chunk %||% NA_character_)
  chunk <- if (in_prose) NA_character_ else current_chunk_label()
  where <- if (in_prose) list(file = inl$file, line = inl$line) else list()
  # with no weft_setup() the functions inline code calls are not on the search
  # path; they are made visible to the strings, and to nothing else
  if (strict) env <- with_weft_functions(env)
  out <- vapply(unname(x), function(el) {
    if (is.na(el)) return(NA_character_)
    resolve_string(s, el, list(chunk = chunk, option = NA_character_, envir = env,
                               strict = strict, context = "weft_str",
                               file = where$file, line = where$line))
  }, "", USE.NAMES = FALSE)
  out
}

current_chunk_label <- function() {
  if (!knit_in_progress()) return(NA_character_)
  lab <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
  if (is.character(lab) && length(lab) == 1L && !is.na(lab)) lab else NA_character_
}

# The state a string is resolved against: the knit's, or, with none, a
# throwaway one that holds the default configuration.
string_state <- function() {
  s <- if (knit_in_progress() && is_weft_hook(knitr::knit_hooks$get("text", default = FALSE))) {
    active_state()
  }
  if (!is.null(s)) {
    s$live <- TRUE
    return(s)
  }
  s <- new_state()
  s$live <- FALSE
  cfg <- weft_env$config
  # a configuration with an error is an error here as in a knit (9.1)
  if (is.null(cfg)) cfg <- read_config(getwd(), list())
  s$config <- cfg
  s
}

# Park the inline code of a string exactly as the `evaluate.inline` hook parks
# the code of a block of prose, so one resolver reads both. Returns the text
# with a placeholder for each piece of code.
park_string <- function(s, x, envir, bare = TRUE) {
  pat <- knitr::all_patterns$md$inline.code
  m <- gregexpr(pat, x, perl = TRUE)[[1L]]
  if (m[1L] < 0L) return(x)
  if (!bare) {
    len <- attr(m, "match.length")
    after <- substring(x, m + len, m + len)
    keep <- after == "{"
    if (!any(keep)) return(x)
    m <- structure(m[keep], match.length = len[keep])
  }
  hits <- regmatches(x, list(m))[[1L]]
  codes <- sub(pat, "\\3", hits, perl = TRUE)
  ph <- character(length(codes))
  for (i in seq_along(codes)) {
    idx <- length(s$parked) + 1L
    s$parked[[idx]] <- list(code = codes[i], envir = envir)
    ph[i] <- paste0("\ue000", idx, "\ue002")
  }
  regmatches(x, list(m)) <- list(ph)
  x
}

# Resolve one string. `ctx`: chunk, option, envir, strict, context.
resolve_string <- function(s, x, ctx) {
  x <- enc2utf8(x)
  # bare inline R in a caption stays literal text, as stock leaves it (1.1.8);
  # inline code that carries an attribute block is a construct and is run
  x <- park_string(s, x, ctx$envir, bare = !identical(ctx$context, "caption"))
  if (!grepl("\ue000", x, fixed = TRUE) && !grepl("[", x, fixed = TRUE) &&
      !grepl("]{", x, fixed = TRUE)) return(x)
  resolve_markup(s, x, block = NULL, ctx = ctx)
}

# The functions inline code calls by name (`claim()`, `plural()`, `fmt_*()`).
inline_function_names <- function() {
  c("claim", "plural", "glue_vec", "u", "dict_glossary",
    grep("^fmt_", getNamespaceExports(asNamespace("weft")), value = TRUE))
}

# `envir`, or a child of it that holds the inline functions `envir` cannot see.
with_weft_functions <- function(envir) {
  nms <- inline_function_names()
  miss <- nms[!vapply(nms, exists, NA, envir = envir, mode = "function", inherits = TRUE)]
  if (!length(miss)) return(envir)
  e <- new.env(parent = envir)
  for (m in miss) assign(m, get(m, envir = asNamespace("weft")), envir = e)
  e
}
