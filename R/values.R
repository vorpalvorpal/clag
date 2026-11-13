# Values by name: the carrier and publishing from R (dev/design-6.md, section 2B
# and 2C, N20 to N23 and N40 to N48).
#
# `weft_put()` publishes R values under names as a `weft-values` block (schema
# 1): the filter, or any reader of the block, then prints them in prose. The
# record of an R value is the record of rule 1.11 seen from the R side: the
# kinds are R/guest.R's (`t` is one of bool, int, float, decimal, string, date,
# list, missing, error; a list holds scalar records, `of` is the kind of its
# elements, `keys` its names). The writer here makes the JSON text of a record
# directly, so the key order is fixed: `t`, then `v`, then `of`, `keys`, `why`,
# `checks`.
#
# In a knit with the hooks the names do not go to the output at once: they wait
# in the knit's state (`s$waiting`), and the `text` hook writes them as one block
# before the next block of prose, together with every name the document's source
# names (N45) whose binding is new or has changed (N43). The `document` hook
# writes whatever is left at the end.

# ---- names (N6) ---------------------------------------------------------------------------------------

VALUES_RESERVED <- c("TRUE", "FALSE", "True", "False", "true", "false", "NA", "NULL",
                     "None", "nothing", "missing", "Inf", "NaN")

# TRUE for each element of `x` that is a NAME (N6).
values_name_ok <- function(x) {
  x <- as.character(x)
  ok <- !is.na(x) & grepl("^[A-Za-z_][A-Za-z0-9_.]{0,63}\\z", x, perl = TRUE) &
    !endsWith(x, ".") & !(x %in% VALUES_RESERVED)
  ok
}

values_abort <- function(msg) weft_abort(msg, "weft_values_error")

# ---- the JSON text -------------------------------------------------------------------------------------------

# JSON string literals (with their quotes) for a character vector.
values_str <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  if (any(grepl("[\\x01-\\x1f]", x, perl = TRUE))) {
    for (code in setdiff(1:31, c(9L, 10L, 13L))) {
      x <- gsub(rawToChar(as.raw(code)), sprintf("\\u%04x", code), x, fixed = TRUE)
    }
  }
  paste0("\"", x, "\"")
}

# The shortest text, of %.15g, %.16g and %.17g, that reads back as the same
# double (N47). `x` is finite.
float_text <- function(x) {
  out <- sprintf("%.15g", x)
  for (d in c(16L, 17L)) {
    redo <- !(as.numeric(out) == x)
    if (!any(redo)) break
    out[redo] <- sprintf(paste0("%.", d, "g"), x[redo])
  }
  out
}

# ---- the record of an R value (N47) ---------------------------------------------------------------

E44_TAIL <- paste0("is a units quantity; named values carry no units. Publish the number in ",
                   "the unit you mean (rule 2.13.3).")

# A refused value: the text after the subject, and the kind of refusal.
values_refusal <- function(code, tail) {
  list(code = code, tail = tail,
       json = paste0("{\"t\":\"error\",\"why\":", values_str(paste("{S}", tail)), "}"))
}

# The JSON of each element of an atomic vector `x` as a scalar record, and its
# kind. `x` is a logical, integer, double, character, factor, Date or integer64
# vector without names.
values_scalars <- function(x) {
  n <- length(x)
  miss <- function(why) paste0("{\"t\":\"missing\",\"why\":", values_str(why), "}")
  js <- character(n)
  kind <- rep(NA_character_, n)
  put <- function(i, k, json) {
    js[i] <<- json
    kind[i] <<- k
  }
  if (inherits(x, "integer64")) {
    s <- as.character(x)
    na <- is.na(s)
    put(na, "missing", miss("NA"))
    put(!na, "int", paste0("{\"t\":\"int\",\"v\":", values_str(s[!na]), "}"))
  } else if (is.factor(x)) {
    s <- as.character(x)
    na <- is.na(s)
    put(na, "missing", miss("NA"))
    put(!na, "string", paste0("{\"t\":\"string\",\"v\":", values_str(s[!na]), "}"))
  } else if (inherits(x, "Date")) {
    u <- unclass(x)
    attributes(u) <- NULL
    bad <- !is.finite(u)
    why <- ifelse(is.nan(u), "NaN", ifelse(is.na(u), "NA", ifelse(u > 0, "Inf", "-Inf")))
    put(bad, "missing", vapply(why[bad], miss, "", USE.NAMES = FALSE))
    ok <- !bad
    put(ok, "date", paste0("{\"t\":\"date\",\"v\":", values_str(format(x[ok], "%Y-%m-%d")), "}"))
  } else if (is.logical(x)) {
    na <- is.na(x)
    put(na, "missing", miss("NA"))
    put(!na, "bool", ifelse(x[!na], "{\"t\":\"bool\",\"v\":true}", "{\"t\":\"bool\",\"v\":false}"))
  } else if (is.integer(x)) {
    na <- is.na(x)
    put(na, "missing", miss("NA"))
    put(!na, "int", paste0("{\"t\":\"int\",\"v\":\"", sprintf("%d", x[!na]), "\"}"))
  } else if (is.double(x)) {
    bad <- !is.finite(x)
    why <- ifelse(is.nan(x), "NaN", ifelse(is.na(x), "NA", ifelse(x > 0, "Inf", "-Inf")))
    put(bad, "missing", vapply(why[bad], miss, "", USE.NAMES = FALSE))
    ok <- !bad
    put(ok, "float", paste0("{\"t\":\"float\",\"v\":\"", float_text(x[ok]), "\"}"))
  } else {
    na <- is.na(x)
    put(na, "missing", miss("NA"))
    put(!na, "string", paste0("{\"t\":\"string\",\"v\":", values_str(x[!na]), "}"))
  }
  list(json = js, kind = kind)
}

# The record of an R value, as list(json, code, tail). `code` is NULL for a
# record, and "E42", "E44" or "E45" for a refused value (its `json` is then an
# error record, and `tail` the message after the subject).
values_record <- function(x) {
  if (is.null(x)) {
    return(list(json = "{\"t\":\"missing\",\"why\":\"NULL\"}", code = NULL))
  }
  if (inherits(x, "units")) return(values_refusal("E44", E44_TAIL))
  plain <- inherits(x, c("integer64", "factor", "Date")) ||
    (!is.object(x) && is.atomic(x) && is.null(dim(x)))
  if (!plain) {
    return(values_refusal("E45", sprintf(paste0(
      "is an R %s, which weft does not publish. Publish a bool, number, string, ",
      "Date, or a vector of one of these (rule 1.11.1)."), class(x)[1L])))
  }
  n <- length(x)
  if (n > 10000L) {
    return(values_refusal("E42", sprintf(
      "is a list of %d elements; weft publishes at most 10000 (rule 2.13.1).", n)))
  }
  nm <- names(x)
  if (!inherits(x, "integer64")) names(x) <- NULL
  sc <- values_scalars(x)
  if (n == 1L) return(list(json = sc$json, code = NULL))
  kinds <- unique(sc$kind[sc$kind != "missing"])
  of <- if (length(kinds)) kinds[1L] else if (n == 0L) values_empty_kind(x) else "missing"
  keys <- if (is.null(nm)) "null" else
    paste0("[", paste(values_str(ifelse(is.na(nm), "NA", nm)), collapse = ","), "]")
  list(json = paste0("{\"t\":\"list\",\"v\":[", paste(sc$json, collapse = ","),
                     "],\"of\":", values_str(of), ",\"keys\":", keys, "}"),
       code = NULL)
}

# The element kind of a vector of length zero, from its type.
values_empty_kind <- function(x) {
  if (inherits(x, "integer64") || is.integer(x)) "int"
  else if (inherits(x, "Date")) "date"
  else if (is.factor(x) || is.character(x)) "string"
  else if (is.double(x)) "float"
  else "bool"
}

# A check object (N23) for each check of a captured `claim()`.
values_check_json <- function(text, run, level) {
  why <- ifelse(!is.na(run$errs), values_str(run$errs),
                ifelse(!is.na(run$lens), values_str(sprintf("returned %d values, not a single TRUE", run$lens)),
                       "null"))
  paste0("{\"text\":", values_str(text), ",\"ok\":", ifelse(run$ok, "true", "false"),
         ",\"level\":", values_str(level), ",\"why\":", why, "}")
}

# `rec` with a `checks` member added.
values_with_checks <- function(rec, checks) {
  if (!length(checks)) return(rec)
  rec$json <- paste0(substr(rec$json, 1L, nchar(rec$json) - 1L), ",\"checks\":[",
                     paste(checks, collapse = ","), "]}")
  rec
}

# ---- run and time (N48) ---------------------------------------------------------------------------------

# The run id: the first line of `.weft/run`, found walking up from `dir` (at
# most 8 levels above it), else WEFT_RUN when set and not empty, else NULL.
# Read at each publish, never kept.
values_run <- function(dir = values_dir()) {
  d <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  for (i in 0:8) {
    f <- file.path(d, ".weft", "run")
    if (file.exists(f) && !dir.exists(f)) {
      line <- tryCatch(readLines(f, n = 1L, warn = FALSE, encoding = "UTF-8"),
                       error = function(e) character())
      line <- sub("\r$", "", line)
      if (length(line) && nzchar(trimws(line))) return(enc2utf8(line))
    }
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  e <- Sys.getenv("WEFT_RUN", "")
  if (nzchar(e)) enc2utf8(e) else NULL
}

# The document's folder: the knit's input, else the working directory.
values_dir <- function() {
  p <- if (knit_in_progress()) knit_input_path() else NULL
  if (is.null(p)) getwd() else dirname(p)
}

values_now <- function() sprintf("%.0f", floor(as.numeric(Sys.time())))

# ---- the block (N20, N21) --------------------------------------------------------------------------------

# The JSON object text of a block. `records` is a named list of record JSON texts.
values_json <- function(records, cell = NULL, run = values_run()) {
  vals <- if (length(records)) {
    paste0(values_str(names(records)), ":", unlist(records, use.names = FALSE), collapse = ",")
  } else ""
  paste0("{\"weft\":1,\"lang\":\"r\",\"run\":", if (is.null(run)) "null" else values_str(run),
         ",\"at\":", values_now(), ",\"values\":{", vals, "}",
         if (!is.null(cell) && nzchar(cell)) paste0(",\"cell\":", values_str(cell)), "}")
}

# The fenced block: four backticks, so that a backtick fence inside a string
# cannot close it, and the JSON on one line.
values_fenced <- function(json) paste0("````{.weft-values}\n", json, "\n````\n")

# ---- what a call publishes (N40, N41) -------------------------------------------------------------

# TRUE for an expression that is a call of claim() or weft::claim().
is_claim_call <- function(e) {
  is.call(e) && (identical(e[[1L]], quote(claim)) || identical(e[[1L]], quote(weft::claim)))
}

# The parts of a `claim()` call that `weft_put()` captures, or NULL when the
# call is to be evaluated as it stands (so that claim() itself refuses it).
values_claim_parts <- function(e, env) {
  mc <- tryCatch(match.call(claim, e, expand.dots = FALSE), error = function(err) NULL)
  if (is.null(mc) || is.null(mc$x)) return(NULL)
  checks <- as.list(mc[["..."]])
  empty <- vapply(checks, function(ck) identical(ck, quote(expr = )), NA)
  checks <- checks[!empty]
  if (!length(checks)) return(NULL)
  bare <- vapply(checks, function(ck) is.character(ck) && length(ck) == 1L &&
                   ck %in% c("warn", "fail"), NA)
  if (any(bare)) return(NULL)
  level <- "fail"
  if (!is.null(mc$level)) {
    lv <- tryCatch(eval(mc$level, env), error = function(err) NULL)
    if (!(is.character(lv) && length(lv) == 1L && !is.na(lv) && lv %in% c("fail", "warn"))) return(NULL)
    level <- lv
  }
  list(x = mc$x, checks = checks, level = level)
}

# The records a call publishes: a named list of list(json, code, tail). `exprs`
# are the arguments as written, `get(i)` the value of the i-th (forced only
# when it is not a claim), `env` the caller's frame. Raises weft_values_error
# for E40, E41, E43 and for a value that is refused with E42 or E44; E45 is a
# record.
values_collect <- function(exprs, get, env, frames) {
  n <- length(exprs)
  if (!n) return(list())
  given <- names(exprs)
  if (is.null(given)) given <- rep("", n)
  nm <- character(n)
  for (i in seq_len(n)) {
    if (nzchar(given[i])) {
      nm[i] <- given[i]
    } else if (is.symbol(exprs[[i]])) {
      nm[i] <- as.character(exprs[[i]])
    } else {
      values_abort("weft_put() takes named arguments or names: weft_put(n = nrow(d)) or weft_put(n) (rule 3.8).")
    }
    if (!values_name_ok(nm[i])) {
      values_abort(sprintf(paste0("`%s` is not a name weft can publish: ASCII letters, digits, _ and ., ",
                                  "starting with a letter or _ (rule 1.12.1)."), nm[i]))
    }
  }
  dup <- nm[duplicated(nm)]
  if (length(dup)) {
    values_abort(sprintf("`%s` is given twice in one weft_put() call.", dup[1L]))
  }
  out <- vector("list", n)
  names(out) <- nm
  for (i in seq_len(n)) {
    parts <- if (is_claim_call(exprs[[i]])) values_claim_parts(exprs[[i]], env) else NULL
    if (is.null(parts)) {
      rec <- values_record(get(i))
    } else {
      value <- eval(parts$x, env)
      run <- claim_run_checks(parts$checks, value, env)
      text <- written_checks(frames, parts$checks, weft_env$inline$expr)
      rec <- values_with_checks(values_record(value), values_check_json(text, run, parts$level))
    }
    if (!is.null(rec$code) && rec$code %in% c("E42", "E44")) {
      values_abort(sprintf("`%s` %s", nm[i], rec$tail))
    }
    out[[i]] <- rec
  }
  out
}

# ---- exports --------------------------------------------------------------------------------------------------

#' Publish values by name
#'
#' `weft_put()` publishes R values under names, so that prose can refer to
#' them by name: a code span holding the name, with a formatter class,
#' `` `depth`{.num} ``. The values travel in a `weft-values` block, which the
#' resolver filter reads (rules 2.13, 3.8). In an R document the hooks publish
#' a name that the source mentions and the knit has bound, so `weft_put()` is
#' needed only for text a chunk prints with `results = "asis"`, for a claim that
#' travels with its value, and from a chunk that has no value of its own to
#' show.
#'
#' Each argument publishes one name: `weft_put(depth = mean(d$depth))`, or
#' `weft_put(depth, n_sites)` for variables of the same names. A name is ASCII
#' letters, digits, `_` and `.`, starting with a letter or `_`, at most 64
#' characters. An argument that is a call of [claim()] is captured: its checks
#' are run and recorded with the value, nothing is stopped, and each check counts
#' where the name is used.
#'
#' A bool, a whole or decimal number, a string, a factor, a `Date`, an
#' `integer64` or an atomic vector of these (up to 10000 elements) is published
#' with its kind. `NA`, `NaN`, `Inf` and `NULL` are published as missing. A value
#' with units is refused, and any other object (a data frame, a list, a
#' `POSIXct`, a function) is published as an error that is reported where the name
#' is used.
#'
#' In a knit with the hooks the block is written before the next block of prose,
#' or at once in a chunk with `results = "asis"`. Outside a knit nothing is stored:
#' the text of the block is returned.
#'
#' @param ... Named values, or names of variables. An argument may be a call of
#'   [claim()].
#' @return Inside a knit, `NULL`, invisibly. Outside one, the text of the block, of
#'   class `weft_values`, which prints as the text.
#' @examples
#' depth <- c(1.5, 2.5, 6)
#' weft_put(depth_mean = mean(depth), n = length(depth))
#' weft_put(depth_mean = claim(mean(depth), . > 1, . < 10))
#' @seealso [weft_values_write()]
#' @export
weft_put <- function(...) {
  frames <- sys.calls()
  env <- parent.frame()
  self <- environment()
  exprs <- as.list(substitute(list(...)))[-1L]
  get <- function(i) eval(call("...elt", i), self)
  recs <- values_collect(exprs, get, env, frames)
  s <- if (knit_in_progress()) active_state() else NULL
  if (is.null(s)) {
    block <- values_json(lapply(recs, `[[`, "json"))
    return(structure(values_fenced(block), class = "weft_values"))
  }
  values_wait(s, recs)
  invisible(NULL)
}

#' @export
print.weft_values <- function(x, ...) {
  cat(unclass(x), sep = "")
  invisible(x)
}

#' Write a values file
#'
#' `weft_values_write()` writes the values it is given to a JSON file in the
#' form of a `weft-values` block (schema 1), for a document to read with a
#' `weft-values` block that names the file. It works outside a knit, and in a
#' `targets` pipeline. The arguments are those of [weft_put()]: named values, or
#' names of variables, and calls of [claim()].
#'
#' The file is written atomically, as UTF-8 with `\\n` line ends. Nothing is
#' written when an argument is refused, and the old file stays.
#'
#' @param path The file to write. A relative path is relative to the working
#'   directory.
#' @param ... Named values, as for [weft_put()].
#' @return `path`, invisibly.
#' @examples
#' f <- tempfile(fileext = ".json")
#' weft_values_write(f, n = 12L, site = "north")
#' cat(readLines(f), sep = "\n")
#' @seealso [weft_put()]
#' @export
weft_values_write <- function(path, ...) {
  frames <- sys.calls()
  env <- parent.frame()
  self <- environment()
  exprs <- as.list(substitute(list(...)))[-1L]
  get <- function(i) eval(call("...elt", i), self)
  recs <- values_collect(exprs, get, env, frames)
  json <- values_json(lapply(recs, `[[`, "json"), run = values_run(getwd()))
  write_lines_atomic(json, path)
  invisible(path)
}

# ---- the names a source names (N45) ---------------------------------------------------------------

# Every name token of a governor value: single-quoted strings are removed first.
values_governor_names <- function(x) {
  x <- gsub("'[^']*'", " ", x)
  unlist(regmatches(x, gregexpr("(?<![A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_.]*", x, perl = TRUE)),
         use.names = FALSE)
}

# The names the text of one file names, not those of its includes: those of rule 1
# (`code`: the code spans of a named value) and those of rule 2 (`gov`: the
# governor values).
values_text_names <- function(txt) {
  code <- character()
  gov <- character()
  if (grepl("`{", txt, fixed = TRUE)) {
    m <- regmatches(txt, gregexpr("`[A-Za-z_][A-Za-z0-9_.]{0,63}`\\{", txt, perl = TRUE))[[1L]]
    code <- substr(m, 2L, nchar(m) - 2L)
  }
  if (grepl("=\"", txt, fixed = TRUE)) {
    m <- regmatches(txt, gregexpr("(?<![A-Za-z0-9_.-])(?i:n|if|sign|list)=\"[^\"]*\"", txt,
                                  perl = TRUE))[[1L]]
    if (length(m)) gov <- values_governor_names(sub("^[A-Za-z]+=\"(.*)\"$", "\\1", m))
  }
  list(code = code, gov = gov)
}

# What a document names (N45): `path` and, recursively, the files its
# `{{< include >}}` shortcodes name, relative to the file that names them (at
# most 8 deep). A file that cannot be read names nothing. Returns the names (no
# repeats, no reserved word, nothing that is not a NAME) and `named`: whether any
# code span of rule 1 names one, that is, whether the document holds a named value.
values_source_scan <- function(path) {
  seen <- character()
  walk <- function(p, depth) {
    none <- list(code = character(), gov = character())
    p <- normalizePath(p, winslash = "/", mustWork = FALSE)
    if (p %in% seen || !file.exists(p) || dir.exists(p)) return(none)
    seen <<- c(seen, p)
    txt <- read_source_text_or_null(p)
    if (is.null(txt)) return(none)
    out <- values_text_names(txt)
    if (depth < 8L && grepl("{{<", txt, fixed = TRUE)) {
      m <- regmatches(txt, gregexpr("\\{\\{<\\s*include\\s+[^>\\s]+\\s*>\\}\\}", txt, perl = TRUE))[[1L]]
      for (inc in sub("^\\{\\{<\\s*include\\s+([^>\\s]+)\\s*>\\}\\}$", "\\1", m, perl = TRUE)) {
        inc <- gsub("^[\"']|[\"']$", "", inc)
        inner <- walk(file.path(dirname(p), inc), depth + 1L)
        out$code <- c(out$code, inner$code)
        out$gov <- c(out$gov, inner$gov)
      }
    }
    out
  }
  found <- walk(path, 0L)
  code <- unique(found$code)
  code <- code[values_name_ok(code)]
  nm <- unique(c(code, found$gov))
  list(names = nm[values_name_ok(nm)], named = length(code) > 0L)
}

# The names a source names (N45), without repeats.
values_source_names <- function(path) values_source_scan(path)$names

# ---- publishing in a knit (N42, N43) --------------------------------------------------------------

values_unbound <- structure(list(), class = "weft_unbound")

# The names the knit's source names, for the files seen so far. A top-level knit
# reads its input once; a child knitted from a file adds its own.
values_names <- function(s) {
  path <- if (is_child_knit()) knit_input_path() else
    if (is.na(s$input_path)) NULL else s$input_path
  if (!is.null(path) && !(path %in% s$names_paths)) {
    s$names_paths <- c(s$names_paths, path)
    # a document with no named value publishes nothing by itself: its governors are R's
    # and it must knit as it did before named values (N43)
    sc <- values_source_scan(path)
    if (sc$named) s$names <- union(s$names, sc$names)
  }
  s$names
}

# The names put by weft_put() wait for the next block of prose.
values_wait <- function(s, recs) {
  label <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
  cell <- if (is.character(label) && length(label) == 1L) label else NULL
  if (identical(tryCatch(knitr::opts_current$get("results"), error = function(e) NULL), "asis")) {
    # the text the chunk prints after the call sees the names
    values_note_put(s, names(recs))
    cat("\n", values_fenced(values_json(lapply(recs, `[[`, "json"), cell = cell, run = values_run())),
        "\n", sep = "")
    return(invisible())
  }
  for (nm in names(recs)) s$waiting[[nm]] <- recs[[nm]]$json
  s$waiting_cell <- cell %||% s$waiting_cell
  invisible()
}

# A name published by put is not published again by the hooks until its binding
# changes: the record of the binding as it stands is taken as the last auto one.
values_note_put <- function(s, nms) {
  src <- intersect(nms, values_names(s))
  if (!length(src)) return(invisible())
  env <- knitr::knit_global()
  for (nm in src) {
    v <- get0(nm, envir = env, inherits = FALSE, ifnotfound = values_unbound)
    if (!identical(v, values_unbound)) {
      s$auto[[nm]] <- list(value = v, json = values_record(v)$json)
    }
  }
  invisible()
}

# The text of the block to write now: the waiting names and the names the source
# names that are bound and new or changed; NULL when there is none.
values_pending <- function(s) {
  nms <- values_names(s)
  if (!length(nms) && !length(s$waiting)) return(NULL)
  env <- knitr::knit_global()
  fresh <- list()
  for (nm in nms) {
    v <- get0(nm, envir = env, inherits = FALSE, ifnotfound = values_unbound)
    if (identical(v, values_unbound)) next
    last <- s$auto[[nm]]
    # a binding that is the same object as when last read has the same record
    if (!is.null(last) && identical(v, last$value)) next
    json <- values_record(v)$json
    s$auto[[nm]] <- list(value = v, json = json)
    if (is.null(last) || !identical(json, last$json)) fresh[[nm]] <- json
  }
  put <- s$waiting
  if (!length(fresh) && !length(put)) return(NULL)
  # a name that put published wins over the auto value in the same block
  values_note_put(s, names(put))
  recs <- c(fresh[setdiff(names(fresh), names(put))], put)
  cell <- if (length(put)) s$waiting_cell else NULL
  s$waiting <- list()
  s$waiting_cell <- NULL
  values_fenced(values_json(recs, cell = cell))
}

# The `text` hook's block for the prose `x`, or NULL. Pieces of white space are not
# prose, so they wait.
values_pending_for <- function(s, x) {
  if (!nzchar(trimws(paste(as.character(x), collapse = "")))) return(NULL)
  values_pending(s)
}

# The `document` hook: what is left, at the end.
values_append <- function(s, x) {
  blk <- values_pending(s)
  if (is.null(blk) || !length(x)) return(x)
  n <- length(x)
  last <- x[n]
  x[n] <- paste0(last, if (nzchar(last) && !endsWith(last, "\n")) "\n", "\n", blk)
  x
}
