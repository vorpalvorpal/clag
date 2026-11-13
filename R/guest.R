# Guest languages under knitr: reading Python values (rules 1.11, 2.12, G4 to
# G17a of dev/design-5.md).
#
# A Python value is read by a classifier that runs inside Python
# (inst/python/weft_guest.py), so reticulate's conversion never sees it. The
# classifier returns a typed record; ONE function, record_value(), turns a
# record into an R value and holds the refusals that depend on what R can
# hold (an integer beyond 2^53, a decimal of more than 15 digits).
#
# A record is list(t, v, why, of, keys, type):
#   t     "bool" "int" "float" "decimal" "string" "date" "list" "missing" "error"
#   v     bool: TRUE or FALSE; int: the digit string; float: the shortest text
#         that reads back as the same double; decimal: str() of the Decimal;
#         string: the text; date: ISO; list: a list of scalar records
#   why   missing and error: the reason; for an error the refusal message with
#         the subject written as the literal text {S}
#   of    lists: the kind of the elements after the promotions of G6
#   keys  lists from a mapping: the keys
#   type  Python's type name (guest_record() only; hand-built records omit it)

KIND_NAMES <- c(int = "integer", float = "float", decimal = "decimal",
                bool = "bool", string = "string", date = "date")

# ---- conditions -------------------------------------------------------------------------------------

guest_value_abort <- function(msg) {
  weft_abort(msg, c("weft_guest_value_error", "weft_value_error"))
}

guest_abort <- function(msg) weft_abort(msg, "weft_guest_error")

put_subject <- function(why, S) {
  pos <- regexpr("{S}", why, fixed = TRUE)
  if (pos < 0L) return(why)
  paste0(substr(why, 1L, pos - 1L), S, substring(why, pos + 3L))
}

# ---- the record to an R value ----------------------------------------------------------------------

# Significant digits of a decimal's text, as Decimal.normalize() counts them:
# the digits of the coefficient without leading and trailing zeros.
decimal_digits <- function(txt) {
  m <- sub("^[-+]", "", txt)
  m <- sub("[eE].*$", "", m)
  m <- gsub(".", "", m, fixed = TRUE)
  m <- sub("^0+", "", m)
  m <- sub("0+$", "", m)
  max(nchar(m), 1L)
}

# The R form of an int record: an integer within +-(2^31 - 1), a double up to
# +-2^53, and beyond that a refusal (M1).
int_value <- function(v, S) {
  d <- sub("^-", "", v)
  d <- sub("^0+(?=.)", "", d, perl = TRUE)
  if (nchar(d) > 16L || (nchar(d) == 16L && d > "9007199254740992")) {
    guest_value_abort(sprintf(paste0(
      "%s is the Python int %s, beyond ±2^53, where R cannot hold a whole number exactly. ",
      "Scale it in Python, or bind str() of it and print the text (rule 2.12.5)."), S, v))
  }
  if (nchar(d) < 10L || (nchar(d) == 10L && d <= "2147483647")) as.integer(v) else as.numeric(v)
}

decimal_value <- function(v, S) {
  n <- decimal_digits(v)
  if (n > 15L) {
    guest_value_abort(sprintf(paste0(
      "%s is the Python Decimal %s, with %d significant digits; R holds 15 exactly. ",
      "Round it in Python with quantize() (rule 2.12.5)."), S, v, n))
  }
  as.numeric(v)
}

scalar_value <- function(rec, S) {
  switch(rec[["t"]],
    bool = isTRUE(rec[["v"]]),
    int = int_value(rec[["v"]], S),
    float = as.numeric(rec[["v"]]),
    decimal = decimal_value(rec[["v"]], S),
    string = enc2utf8(rec[["v"]]),
    date = as.Date(rec[["v"]]),
    missing = NA,
    error = guest_value_abort(put_subject(rec[["why"]], S)),
    guest_value_abort(sprintf("%s is a record of the kind \"%s\", which weft cannot read.", S, rec[["t"]])))
}

# The R value of a record (G5, G6, 2.12.5), or the refusal, as
# weft_guest_value_error. `S` is the subject, backticks included.
record_value <- function(rec, S) {
  t <- rec[["t"]]
  if (!identical(t, "list")) return(scalar_value(rec, S))
  els <- rec[["v"]]
  of <- rec[["of"]]
  vals <- lapply(els, function(el) scalar_value(el, S))
  n <- length(vals)
  out <- if (n == 0L || identical(of, "missing")) {
    rep(NA, n)
  } else {
    switch(of,
      bool = vapply(vals, function(x) if (is.logical(x)) x else NA, NA),
      int = {
        x <- unlist(vals, use.names = FALSE)
        if (is.null(x)) rep(NA_integer_, n) else x
      },
      float = , decimal = vapply(vals, function(x) as.numeric(x), 0),
      string = vapply(vals, function(x) if (is.character(x)) x else NA_character_, ""),
      date = as.Date(vapply(vals, function(x) if (inherits(x, "Date")) as.numeric(x) else NA_real_, 0),
                     origin = "1970-01-01"),
      guest_value_abort(sprintf("%s is a list of \"%s\", which weft cannot read.", S, of)))
  }
  if (identical(of, "int") && n > 0L) {
    # integers all within +-(2^31 - 1) are an integer vector, else a double one
    out <- if (is.integer(out)) out else as.numeric(out)
  }
  keys <- rec[["keys"]]
  if (length(keys)) names(out) <- keys
  out
}

# ---- the reader ---------------------------------------------------------------------------------------------------

# Reticulate is used only when a read needs it. `options(weft.reticulate =
# FALSE)` makes weft behave as if it were not installed (G4b).
guest_python <- function(read) {
  if (isFALSE(getOption("weft.reticulate")) || !requireNamespace("reticulate", quietly = TRUE)) {
    guest_abort(sprintf(paste0(
      "`%s` reads a Python value, and the R package reticulate is not installed. ",
      "Install it with install.packages(\"reticulate\") (rule 2.12.6)."), read))
  }
  up <- tryCatch(reticulate::py_available(initialize = FALSE), error = function(e) FALSE)
  if (!isTRUE(up)) {
    # weft never lets reticulate make a managed environment on its behalf
    if (!nzchar(Sys.getenv("RETICULATE_USE_MANAGED_VENV"))) {
      Sys.setenv(RETICULATE_USE_MANAGED_VENV = "no")
      on.exit(Sys.unsetenv("RETICULATE_USE_MANAGED_VENV"), add = TRUE)
    }
    ok <- tryCatch(reticulate::py_available(initialize = TRUE), error = function(e) e)
    if (inherits(ok, "error") || !isTRUE(ok)) {
      why <- if (inherits(ok, "error")) conditionMessage(ok) else "no Python was found"
      why <- trimws(strsplit(cli::ansi_strip(why), "\n", fixed = TRUE)[[1L]][1L])
      why <- sub("\\.$", "", why)
      guest_abort(sprintf("`%s` reads a Python value, and reticulate could not start Python: %s (rule 2.12.6).",
                          read, why))
    }
  }
  invisible(TRUE)
}

# The module of weft's Python helpers, `weft_guest`, put in sys.modules and in
# no namespace of the author's: it is not a name in __main__ (G16).
guest_module <- function(read) {
  guest_python(read)
  m <- weft_env$guest_mod
  if (!is.null(m) && !reticulate::py_is_null_xptr(m)) return(m)
  m <- tryCatch({
    sys <- reticulate::import("sys", convert = FALSE)
    have <- tryCatch(reticulate::py_get_item(sys$modules, "weft_guest"), error = function(e) NULL)
    if (is.null(have) || !reticulate::py_has_attr(have, "classify_json")) {
      path <- system.file("python", "weft_guest.py", package = "weft")
      iu <- reticulate::import("importlib.util", convert = FALSE)
      spec <- iu$spec_from_file_location("weft_guest", path)
      have <- iu$module_from_spec(spec)
      reticulate::py_set_item(sys$modules, "weft_guest", have)
      spec$loader$exec_module(have)
    }
    have
  }, error = function(e) e)
  if (inherits(m, "error")) {
    guest_abort(sprintf("`%s` reads a Python value, and reticulate could not start Python: %s (rule 2.12.6).",
                        read, trimws(strsplit(conditionMessage(m), "\n", fixed = TRUE)[[1L]][1L])))
  }
  weft_env$guest_mod <- m
  m
}

# A record out of the classifier's JSON, in the shape the helper fixes.
norm_record <- function(x) {
  t <- x[["t"]]
  r <- list(t = t)
  r$v <- switch(t,
    list = lapply(x[["v"]], norm_record),
    bool = isTRUE(x[["v"]]),
    missing = NA_character_,
    error = NA_character_,
    x[["v"]])
  if (t %in% c("missing", "error")) r$why <- x[["why"]]
  if (identical(t, "list")) {
    r$of <- x[["of"]]
    r["keys"] <- list(if (is.null(x[["keys"]])) NULL else as.character(unlist(x[["keys"]])))
  }
  r$type <- x[["type"]]
  r
}

guest_json <- function(txt) {
  jsonlite::fromJSON(enc2utf8(txt), simplifyVector = FALSE)
}

# The record of an unconverted Python object. Never raises for a refused value.
guest_record <- function(obj) {
  mod <- guest_module("guest_record")
  norm_record(guest_json(reticulate::py_to_r(mod$classify_json(obj))))
}

# The record of the value at a path from Python's main module, or the
# refusal that it cannot be reached (M13, M14, M15, M16).
guest_fetch <- function(steps, read, prefixes) {
  mod <- guest_module(read)
  res <- tryCatch(guest_json(reticulate::py_to_r(mod$read(as.list(steps)))), error = function(e) e)
  if (inherits(res, "error")) {
    guest_abort(sprintf("`%s`: Python could not be asked for the value: %s (rule 2.12.6).",
                        read, trimws(strsplit(conditionMessage(res), "\n", fixed = TRUE)[[1L]][1L])))
  }
  if (identical(res[["t"]], "absent")) {
    at <- res[["at"]]
    if (at == 0L) {
      guest_abort(sprintf(paste0("`%s`: Python's main module has no name `%s`. ",
                                 "Run the Python chunk that sets it before this point (rule 2.12.6)."),
                          read, steps[1L]))
    }
    guest_abort(sprintf("`%s`: the Python value `%s` has no attribute or key `%s` (rule 2.12.6).",
                        read, prefixes[at], steps[at + 1L]))
  }
  norm_record(res)
}

# Read the path `steps` and return its R form. `read` is the read as R
# deparses it, and `prefixes[j]` the read of the first j steps. A governor
# that is exactly one read has it noted (`track`), so that the kind read can be
# judged before the R form is (G13).
guest_read <- function(steps, read, prefixes, track = FALSE) {
  rec <- guest_fetch(steps, read, prefixes)
  if (isTRUE(track)) {
    weft_env$guest_last <- list(kind = rec[["t"]], type = rec[["type"]], read = read)
  }
  record_value(rec, paste0("`", read, "`"))
}

#' Read a Python value
#'
#' `py_value()` reads a value that a Python chunk made, in R code, and checks
#' it as weft checks every value that reaches prose (rules 1.11 and 2.12.4).
#' Each argument is one string, a step of a path: `py_value("n")` reads the
#' name `n` in Python's main module; `py_value("cfg", "depth")` reads `cfg`,
#' then its key `depth` when `cfg` is a mapping, else its attribute `depth`.
#'
#' The value is read from its Python type, never from reticulate's conversion,
#' which turns a whole number beyond 2^31 into `NA` or a wrong number. A bool,
#' an integer, a float, a `decimal.Decimal`, a string, a `datetime.date` and a
#' list of one of these (a list, a tuple, a mapping with string keys, a
#' one-dimensional numpy array or a pandas Series) are read. An integer
#' beyond 2^53, a `Decimal` of more than 15 significant digits, a `datetime`,
#' a set and anything else are refused with a `weft_guest_value_error` that
#' says what to do. `None`, NaN and infinities are `NA`.
#'
#' In prose, in the expressions weft evaluates, `py$n` and `py[["n"]]` are
#' read the same way, with no `library(reticulate)`. Use `py_value()` in the
#' code of an R chunk.
#'
#' @param ... One or more non-empty strings: the name in Python's main module,
#'   then the keys or attributes below it.
#' @return The R form of the value: a logical, integer or double, a character
#'   string, a `Date`, or an atomic vector of one of these for a list, named
#'   when it was a mapping. A missing value is `NA`.
#' @examples
#' if (requireNamespace("reticulate", quietly = TRUE) &&
#'     isTRUE(tryCatch(reticulate::py_available(initialize = TRUE),
#'                     error = function(e) FALSE))) {
#'   reticulate::py_run_string("depth = 3.14159")
#'   py_value("depth")
#' }
#' @export
py_value <- function(...) {
  call <- sys.call()
  args <- list(...)
  ok <- length(args) > 0L && all(vapply(args, function(a) {
    is.character(a) && length(a) == 1L && !is.na(a) && nzchar(a)
  }, NA))
  if (!ok) weft_abort("py_value() takes names as strings: py_value(\"n\").", "weft_guest_arg_error")
  steps <- vapply(args, function(a) a, "")
  fn <- if (is.call(call) && (is.symbol(call[[1L]]) || is.call(call[[1L]]))) call[[1L]] else as.name("py_value")
  # the subject is the call with its arguments as evaluated: py_value(nm) with
  # nm = "n" reads as py_value("n")
  read <- deparse_read(as.call(c(list(fn), as.list(steps))))
  prefixes <- vapply(seq_along(steps), function(j) deparse_read(as.call(c(list(fn), as.list(steps[seq_len(j)])))), "")
  guest_read(steps, read, prefixes, track = FALSE)
}

deparse_read <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")

# ---- guest reads in expressions weft evaluates (G9, G10) --------------------------------------------------

# `py` or `reticulate::py`: "bare" for the first, "ns" for the second.
guest_root <- function(x) {
  if (is.symbol(x) && identical(as.character(x), "py")) return("bare")
  if (is.call(x) && length(x) == 3L && identical(x[[1L]], as.name("::")) &&
      identical(x[[2L]], as.name("reticulate")) && identical(x[[3L]], as.name("py"))) return("ns")
  NULL
}

literal_name <- function(s) {
  if (is.symbol(s)) return(as.character(s))
  if (is.character(s) && length(s) == 1L && !is.na(s) && nzchar(s)) return(s)
  NULL
}

# A chain of `$name` and `[["name"]]` steps from `py`: its root, its steps and
# the node of its first j steps, for each j.
guest_chain <- function(node) {
  if (!is.call(node) || length(node) != 3L) return(NULL)
  op <- node[[1L]]
  step <- if (identical(op, as.name("$"))) {
    literal_name(node[[3L]])
  } else if (identical(op, as.name("[["))) {
    s <- node[[3L]]
    if (is.character(s)) literal_name(s)
  }
  if (is.null(step)) return(NULL)
  r <- guest_root(node[[2L]])
  if (!is.null(r)) return(list(root = r, steps = step, nodes = list(node)))
  ic <- guest_chain(node[[2L]])
  if (is.null(ic)) return(NULL)
  list(root = ic$root, steps = c(ic$steps, step), nodes = c(ic$nodes, list(node)))
}

# `py_value("a", "b")` or `weft::py_value(...)` with every argument a literal
# string: its steps.
guest_py_value_call <- function(node) {
  if (!is.call(node)) return(NULL)
  f <- node[[1L]]
  is_pv <- identical(f, as.name("py_value")) ||
    (is.call(f) && length(f) == 3L && identical(f[[1L]], as.name("::")) &&
       identical(f[[2L]], as.name("weft")) && identical(f[[3L]], as.name("py_value")))
  if (!is_pv || length(node) < 2L || !is.null(names(node)) && any(nzchar(names(node)[-1L]))) return(NULL)
  args <- as.list(node)[-1L]
  ok <- all(vapply(args, function(a) is.character(a) && length(a) == 1L && !is.na(a) && nzchar(a), NA))
  if (!ok) return(NULL)
  list(root = "call", steps = vapply(args, function(a) a, ""),
       nodes = lapply(seq_along(args), function(j) as.call(c(list(f), args[seq_len(j)]))))
}

# Is `py`, looked up from `envir`, not found, or Python's main module (G10)?
py_is_guest <- function(envir) {
  x <- get0("py", envir = envir, inherits = TRUE)
  if (is.null(x)) return(TRUE)
  if (!inherits(x, "python.builtin.module")) return(FALSE)
  isTRUE(tryCatch(identical(reticulate::py_to_r(reticulate::py_get_attr(x, "__name__")), "__main__"),
                  error = function(e) FALSE))
}

guest_call <- function(ch, track) {
  full <- ch$nodes[[length(ch$nodes)]]
  prefixes <- vapply(ch$nodes, deparse_read, "")
  as.call(list(quote(weft:::guest_read), ch$steps, deparse_read(full), prefixes, track))
}

# The expressions of `code`, with each guest read replaced by a read of the
# classifier (G9). `code` with no guest read is evaluated exactly as parsed.
guest_prepare <- function(code, envir) {
  ex <- parse(text = code, keep.source = FALSE)
  if (!grepl("py", code, fixed = TRUE)) return(ex)
  py_guest <- NULL
  is_guest <- function() {
    if (is.null(py_guest)) py_guest <<- py_is_guest(envir)
    py_guest
  }
  read_of <- function(node) {
    ch <- guest_chain(node)
    if (!is.null(ch)) return(if (identical(ch$root, "ns") || is_guest()) ch)
    guest_py_value_call(node)
  }
  # the node a governor is judged by: the whole expression, or the first
  # argument of a claim()
  tracked <- NULL
  if (length(ex) == 1L) {
    top <- ex[[1L]]
    if (!is.null(read_of(top))) {
      tracked <- top
    } else if (is.call(top) && length(top) >= 2L &&
               (identical(top[[1L]], as.name("claim")) ||
                  (is.call(top[[1L]]) && length(top[[1L]]) == 3L && identical(top[[1L]][[1L]], as.name("::")) &&
                     identical(top[[1L]][[3L]], as.name("claim")))) &&
               !is.null(read_of(top[[2L]]))) {
      tracked <- top[[2L]]
    }
  }
  fix_root <- function(x) {
    if (is.symbol(x)) quote(reticulate::py) else {
      x[[2L]] <- fix_root(x[[2L]])
      x
    }
  }
  walk <- function(node) {
    if (!is.call(node)) return(node)
    ch <- read_of(node)
    if (!is.null(ch)) return(guest_call(ch, identical(node, tracked)))
    fn <- node[[1L]]
    fch <- guest_chain(fn)
    if (!is.null(fch)) {
      # a call whose function is a read is reticulate's (G10)
      if (identical(fch$root, "bare") && is_guest()) node[[1L]] <- fix_root(fn)
    } else if (is.call(fn)) {
      new <- walk(fn)
      if (!identical(new, fn)) node[[1L]] <- new
    }
    for (i in seq_along(node)[-1L]) {
      if (identical(node[[i]], quote(expr = ))) next
      old <- node[[i]]
      new <- walk(old)
      if (!identical(new, old)) node[[i]] <- new
    }
    node
  }
  out <- lapply(seq_along(ex), function(i) walk(ex[[i]]))
  as.expression(out)
}

# Evaluate the code of an expression weft evaluates, its guest reads read as
# G9 says.
guest_eval <- function(code, envir) eval(guest_prepare(code, envir), envir)

# ---- governors (G13) -------------------------------------------------------------------------------------------

# The message when the kind read does not suit the governor `key`, or NULL.
# A missing value is "no value", not a refusal here (1.3.4).
guest_governor_problem <- function(g, key) {
  if (is.null(g) || identical(g$kind, "missing") || identical(g$kind, "error")) return(NULL)
  type <- g$type %||% "value"
  switch(key,
    `if` = if (!identical(g$kind, "bool")) {
      sprintf("`%s` is a Python %s; an `if` condition must be a bool (rule 1.11.8).", g$read, type)
    },
    n = , sign = if (!(g$kind %in% c("int", "float", "decimal"))) {
      sprintf("`%s` is a Python %s; %s governor must be a number (rule 1.11.9).", g$read, type,
              if (key == "n") "an `n`" else "a `sign`")
    },
    list = if (!identical(g$kind, "list")) {
      sprintf("`%s` is a Python %s; a `list` span needs a list (rule 1.11.10).", g$read, type)
    })
}
