# The dictionary object (rules 4.1-4.3, 4.4.7, 9.1.2): `read_dict()`, the
# `weft_dict` class and its methods, `dict_local` from front matter.
# Contract: dev/design-2.md section 2.

DICT_TYPES <- c("number", "quantity", "year", "date", "string", "labels", "breaks")
DICT_FIELDS <- c("value", "type", "definition", "unit", "decision", "why")

# YAML words such as `yes` and `no` stay text (D6)
dict_yaml_handlers <- function() list("bool#yes" = identity, "bool#no" = identity)

dict_abort <- function(message, class = "weft_dict_error") weft_abort(message, class)

#' Read a dictionary file
#'
#' `read_dict()` reads a dictionary file, checks every entry against the
#' schema (see [dict_file]) and returns a `weft_dict`: a named list of the
#' values, in file order. In a knit weft reads `dict.yml` at the project root
#' itself and puts the result in the document as `dict` (rule 4.1.1), so
#' `read_dict()` is for use outside a knit.
#'
#' Units a quantity names that the `units` package does not know are
#' installed with `units::install_unit()` as the file is read, for the whole
#' session (rule 4.4.7); a unit already known is not installed again. They
#' are kept in the attribute `registered` and listed by `print()`.
#'
#' `dict$key` and `dict[["key"]]` match the key exactly: a key not held is a
#' `weft_dict_key_error`, never `NULL` (rule 4.1.2). A dictionary is read-only
#' (rule 4.1.4): assigning to it, and `dict[...]`, are a `weft_dict_error`.
#' `as.list()` gives the plain named list of values.
#'
#' All the problems in a file are collected and raised together as one
#' `weft_dict_error`. A chunk served from knitr's cache that read `dict` is
#' not re-run when `dict.yml` changes.
#'
#' @param path One string naming an existing file.
#' @return A `weft_dict`, with the attributes `file`, `scope` (`"project"` or
#'   `"local"`), `entries` (a data frame of the keys' type, definition, unit,
#'   decision, why and line), `registered` and `local_keys`.
#' @examples
#' f <- tempfile(fileext = ".yml")
#' writeLines(c("min_samples:",
#'              "  value: 5",
#'              "  type: number",
#'              "  definition: Fewest samples a site needs."), f)
#' d <- read_dict(f)
#' d$min_samples
#' @export
read_dict <- function(path = "dict.yml") {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) ||
      !file.exists(path) || dir.exists(path)) {
    dict_abort(sprintf("weft: read_dict() needs one path to an existing file; got %s.",
                       if (is.character(path) && length(path) == 1L && !is.na(path))
                         paste0("`", path, "`") else "something else"))
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  raw <- tryCatch(
    yaml::yaml.load(paste(lines, collapse = "\n"), handlers = dict_yaml_handlers(),
                    eval.expr = FALSE),
    error = function(e) structure(list(), yaml_error = conditionMessage(e)))
  build_dict(raw, path, "project", lines = lines)
}

# Validate `raw` (the parsed YAML) and build the object, or stop with every
# problem. `lines` are the file's lines, `first` the first line to search
# for keys (a local dictionary lives inside the front matter) and `offset`
# what to add to an index in `lines` to get the line in the file.
build_dict <- function(raw, file, scope, lines = character(), first = 1L, offset = 0L) {
  problems <- character()
  prob <- function(what, rule, key = NULL, line = NA_integer_) {
    where <- if (is.na(line)) file else paste0(file, ":", line)
    problems <<- c(problems, if (is.null(key)) sprintf("%s: %s (rule %s)", where, what, rule)
                   else sprintf("%s: `%s`: %s (rule %s)", where, key, what, rule))
  }
  yerr <- attr(raw, "yaml_error")
  if (!is.null(yerr)) {
    dup <- regmatches(yerr, regexec("Duplicate map key: '([^']*)'", yerr))[[1L]]
    if (length(dup) == 2L) {
      # the key's second `key:` line
      at <- which(startsWith(sub("^[ \t]+", "", lines), paste0(dup[2L], ":")))
      at <- at[at >= first]
      prob("the key is written twice", "4.2.1", dup[2L],
           if (length(at) >= 2L) at[2L] + offset else NA_integer_)
    } else {
      prob(paste0("cannot read the YAML: ", sub("\n.*$", "", yerr)), "4.2.1")
    }
    raw <- list()
  } else if (is.null(raw)) {
    raw <- list()
  } else if (!is.list(raw) || (length(raw) && (is.null(names(raw)) || any(!nzchar(names(raw)))))) {
    prob("the top level must be a mapping from key to entry", "4.2.1")
    raw <- list()
  }
  keys <- names(raw) %||% character()
  locate <- function(i) {
    k <- keys[i]
    idx <- which(startsWith(sub("^[ \t]+", "", lines), paste0(k, ":")))
    idx <- idx[idx >= first]
    n <- sum(keys[seq_len(i)] == k)
    if (length(idx) >= n) idx[n] + offset else NA_integer_
  }
  values <- vector("list", length(raw))
  rows <- list()
  registered <- character()
  for (i in seq_along(raw)) {
    key <- keys[i]
    line <- locate(i)
    p <- function(what, rule) prob(what, rule, key, line)
    if (anyDuplicated(keys[seq_len(i)]) && keys[i] %in% keys[seq_len(i - 1L)]) {
      p("the key is written twice", "4.2.1")
    }
    if (!identical(make.names(key), key)) {
      p("a key must be a valid R name (letters, digits, `.` and `_`, not starting with a digit, not a reserved word)", "4.1.3")
    } else if (identical(key, "file")) {
      p("`file` is reserved and cannot be a key", "4.1.3")
    }
    e <- raw[[i]]
    if (!is.list(e) || is.null(names(e)) || any(!nzchar(names(e)))) {
      p("the entry must be a mapping with the fields `value`, `type` and `definition`", "4.2.1")
      next
    }
    n0 <- length(problems)
    unk <- setdiff(names(e), DICT_FIELDS)
    for (f in unk) {
      p(sprintf("unknown field `%s`; the fields are %s", f, paste(DICT_FIELDS, collapse = ", ")), "4.2.1")
    }
    str1 <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
    type <- e[["type"]]
    type_ok <- FALSE
    if (is.null(type)) {
      p("`type` is missing", "4.2.1")
    } else if (!(is.character(type) && length(type) == 1L && type %in% DICT_TYPES)) {
      p(sprintf("`type` `%s` is not one of %s",
                paste(format(unlist(type)), collapse = " "), paste(DICT_TYPES, collapse = ", ")), "4.2.1")
    } else type_ok <- TRUE
    if (is.null(e[["definition"]])) {
      p("`definition` is missing", "4.2.1")
    } else if (!str1(e[["definition"]])) p("`definition` must be a string that is not blank", "4.2.1")
    unit <- NA_character_
    if (type_ok && type == "quantity") {
      if (is.null(e[["unit"]])) p("`unit` is missing; a quantity needs one", "4.2.1")
      else if (!str1(e[["unit"]])) p("`unit` must be a string that is not blank", "4.2.1")
      else unit <- e[["unit"]]
    } else if (!is.null(e[["unit"]]) && type_ok) {
      p(sprintf("`unit` is only for a quantity, and this is a %s", type), "4.2.1")
    }
    dec <- NA_character_
    if (!is.null(e[["decision"]])) {
      d <- e[["decision"]]
      if (is.numeric(d) && length(d) == 1L && !is.na(d) && d >= 1 && d == round(d)) {
        dec <- as.character(as.integer(d))
      } else if (str1(d)) {
        dec <- d
      } else p("`decision` must be a whole number from 1, or a string that is not blank", "4.2.1")
    }
    why <- NA_character_
    if (scope == "project") {
      if (!is.null(e[["why"]])) p("`why` is for a chapter's own entries; it is not allowed in dict.yml", "4.3.3")
    } else if (is.null(e[["why"]])) {
      p("`why` is missing; a local entry says why it is local", "4.3.3")
    } else if (!str1(e[["why"]])) {
      p("`why` must be a string that is not blank", "4.3.3")
    } else why <- e[["why"]]
    if (is.null(e[["value"]]) && !"value" %in% names(e)) p("`value` is missing", "4.2.1")
    else if (is.null(e[["value"]])) p("`value` is empty", "4.2.1")
    if (type_ok && !is.null(e[["value"]])) {
      r <- dict_value(e[["value"]], type, unit)
      if (!is.null(r$error)) p(paste0("`value` ", r$error), "4.2.1")
      else values[i] <- list(r$value)
    }
    if (type_ok && type == "quantity" && !is.na(unit) && length(problems) == n0) {
      reg <- dict_register_unit(unit)
      if (!is.null(reg$error)) {
        p(sprintf("`unit` `%s` is not a unit the units package can read: %s", unit, reg$error), "4.4.7")
      } else {
        registered <- c(registered, reg$installed)
        values[i] <- list(units::set_units(values[[i]], unit, mode = "standard"))
      }
    }
    rows[[i]] <- data.frame(
      key = key, type = if (type_ok) type else NA_character_,
      definition = if (str1(e[["definition"]])) e[["definition"]] else NA_character_,
      unit = unit, decision = dec, why = why, line = as.integer(line),
      stringsAsFactors = FALSE)
  }
  if (length(problems)) {
    dict_abort(paste0(sprintf("weft: %s: %d problem(s) in the dictionary", file, length(problems)),
                      "\n", paste0("  ", problems, collapse = "\n")))
  }
  entries <- if (length(rows)) do.call(rbind, rows) else
    data.frame(key = character(), type = character(), definition = character(),
               unit = character(), decision = character(), why = character(),
               line = integer(), stringsAsFactors = FALSE)
  rownames(entries) <- NULL
  names(values) <- keys
  structure(values, class = "weft_dict", file = file, scope = scope,
            entries = entries, registered = unique(registered),
            local_keys = character())
}

num_literal <- function(x) {
  if (is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)) return(as.numeric(x))
  if (is.character(x) && length(x) == 1L &&
      grepl("^[+-]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][+-]?[0-9]+)?$", trimws(x))) {
    return(as.numeric(x))
  }
  NULL
}

# The R value of an entry's `value` by its type: list(value) or list(error).
dict_value <- function(v, type, unit) {
  bad <- function(msg) list(error = msg)
  switch(type,
    number = , quantity = {
      n <- num_literal(v)
      if (is.null(n)) bad("must be a number, or a string that is a number literal") else list(value = n)
    },
    year = {
      n <- num_literal(v)
      if (is.null(n) || n != round(n) || n < 1000 || n > 9999) {
        bad("must be a whole number from 1000 to 9999")
      } else list(value = structure(as.integer(n), weft_type = "year"))
    },
    date = {
      d <- if (is.character(v) && length(v) == 1L && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", v))
        as.Date(v, format = "%Y-%m-%d", optional = TRUE) else NA
      if (is.na(d) || !identical(format(d), v)) bad("must be a date written YYYY-MM-DD") else list(value = d)
    },
    string = {
      if (!is.character(v) || length(v) != 1L || is.na(v)) {
        bad("must be a string (quote a number that is meant as text)")
      } else list(value = v)
    },
    labels = {
      if (!is.list(v) || !length(v) || is.null(names(v)) || any(!nzchar(names(v))) ||
          !all(vapply(v, function(x) is.character(x) && length(x) == 1L && !is.na(x), NA))) {
        bad("must be a non-empty mapping from label to phrase, every phrase a string")
      } else {
        f <- lookup(unlist(v))
        attr(f, "weft_n") <- length(v)
        list(value = f)
      }
    },
    breaks = dict_breaks(v))
}

dict_breaks <- function(v) {
  bad <- function(msg) list(error = msg)
  if (!is.list(v) || !length(v) || !is.null(names(v)) ||
      !all(vapply(v, function(x) is.list(x) && !is.null(names(x)), NA))) {
    return(bad("must be a non-empty list of items, each with a `phrase` and at most one of `below` and `at_most`"))
  }
  fs <- list()
  last <- -Inf
  for (k in seq_along(v)) {
    it <- v[[k]]
    unk <- setdiff(names(it), c("phrase", "below", "at_most"))
    if (length(unk)) return(bad(sprintf("item %d has the unknown field `%s`; an item has `phrase`, `below` and `at_most`", k, unk[1L])))
    ph <- it$phrase
    if (!is.character(ph) || length(ph) != 1L || is.na(ph)) return(bad(sprintf("item %d needs a `phrase` that is a string", k)))
    if (all(c("below", "at_most") %in% names(it))) return(bad(sprintf("item %d has both `below` and `at_most`", k)))
    bnd <- if ("below" %in% names(it)) "below" else if ("at_most" %in% names(it)) "at_most" else NULL
    if (is.null(bnd)) {
      if (k < length(v)) return(bad(sprintf("item %d has no bound but is not the last", k)))
      fs[[k]] <- eval(call("~", TRUE, ph), baseenv())
    } else {
      b <- it[[bnd]]
      if (!is.numeric(b) || length(b) != 1L || is.na(b)) return(bad(sprintf("item %d: `%s` must be a number, `.inf` or `-.inf`", k, bnd)))
      if (b < last) return(bad(sprintf("item %d: the bounds must not decrease", k)))
      last <- b
      fs[[k]] <- eval(call("~", call(if (bnd == "below") "<" else "<=", quote(.), b), ph), baseenv())
    }
  }
  f <- do.call(brk, fs)
  attr(f, "weft_n") <- length(v)
  list(value = f)
}

# Install each token of `unit` that the units database does not know
# (4.4.7); then `unit` must parse. list(installed) or list(error).
dict_register_unit <- function(unit) {
  known <- function(tok) tryCatch({ units::as_units(tok); TRUE }, error = function(e) FALSE)
  toks <- unique(unlist(regmatches(unit, gregexpr("[^[:space:][:digit:]*/^().+-]+", unit))))
  installed <- character()
  for (tok in toks) {
    if (known(tok)) next
    r <- tryCatch({ units::install_unit(tok); NULL }, error = function(e) conditionMessage(e))
    if (!is.null(r)) return(list(error = r))
    installed <- c(installed, tok)
  }
  r <- tryCatch({ units::as_units(unit); NULL }, error = function(e) conditionMessage(e))
  if (!is.null(r)) return(list(error = sub("\n.*$", "", r)))
  list(installed = installed)
}

# ---- dict_local (4.3) ------------------------------------------------------

# The document's front-matter `weft: dict_local:` as a local `weft_dict`, or
# NULL when it has none. The front matter is parsed again here so that `yes`
# and `no` stay text.
read_dict_local <- function(path) {
  fl <- front_matter_lines(path)
  if (is.null(fl)) return(NULL)
  y <- tryCatch(yaml::yaml.load(paste(fl, collapse = "\n"), handlers = dict_yaml_handlers(),
                                eval.expr = FALSE), error = function(e) NULL)
  raw <- if (is.list(y) && is.list(y$weft)) y$weft$dict_local else NULL
  if (is.null(raw)) return(NULL)
  at <- which(grepl("^\\s*dict_local\\s*:", fl))[1L]
  build_dict(raw, path, "local", lines = fl, first = if (is.na(at)) 1L else at + 1L,
             offset = 1L)
}

# Assign `dict` and `dict_local` into the knit's environment and the state
# (2.1.5).
init_dicts <- function(s, root, path) {
  proj <- NULL
  f <- file.path(root, "dict.yml")
  if (file.exists(f)) proj <- read_dict(f)
  loc <- if (!is.null(path)) read_dict_local(path) else NULL
  if (is.null(proj) && is.null(loc)) return(invisible())
  if (is.null(loc)) loc <- build_dict(list(), path %||% f, "local")
  if (!is.null(proj)) attr(proj, "local_keys") <- names(loc)
  attr(loc, "project_keys") <- names(proj)
  env <- knitr::knit_global()
  if (!is.null(proj)) assign("dict", proj, envir = env)
  assign("dict_local", loc, envir = env)
  s$dict <- proj
  s$dict_local <- loc
  invisible()
}

# ---- methods ----------------------------------------------------------------

dict_name <- function(x) if (identical(attr(x, "scope"), "local")) "dict_local" else "dict"

dict_key <- function(x, k) {
  keys <- names(x)
  acc <- dict_name(x)
  if (!is.character(k) || length(k) != 1L || is.na(k)) {
    dict_abort(sprintf("`%s[[i]]`: the key must be one string (rule 4.1.2).", acc),
               "weft_dict_key_error")
  }
  if (identical(acc, "dict") && k %in% attr(x, "local_keys")) {
    dict_abort(sprintf("`dict$%s`: this chapter defines a local `%s`; read it as `dict_local$%s` (rule 4.3.2).",
                       k, k, k), "weft_dict_ambiguous")
  }
  if (k %in% keys) return(unclass(x)[[match(k, keys)]])
  if (identical(acc, "dict_local")) {
    msg <- sprintf("`dict_local$%s`: this chapter defines no local `%s` (rule 4.3.2).", k, k)
    if (k %in% attr(x, "project_keys")) {
      msg <- paste0(msg, sprintf(" The project's entry is `dict$%s`.", k))
    }
    dict_abort(msg, "weft_dict_key_error")
  }
  msg <- sprintf("`dict$%s`: no such key in %s (rule 4.1.2).", k, attr(x, "file"))
  if (length(keys)) {
    near <- keys[as.vector(utils::adist(k, keys)) <= 2]
    if (length(near) == 1L) msg <- paste0(msg, sprintf(" Did you mean `%s`?", near))
  }
  dict_abort(msg, "weft_dict_key_error")
}

#' Methods for a dictionary
#'
#' A `weft_dict` is read-only, and read by exact key (see [read_dict()]).
#'
#' @param x A `weft_dict`.
#' @param name,i A key.
#' @param value Not used: a dictionary cannot be assigned to.
#' @param ... Not used.
#' @return `$` and `[[` return the value; `print()` returns `x` invisibly;
#'   `as.list()` returns a plain named list of the values.
#' @name weft_dict
#' @rdname weft_dict
#' @export
`$.weft_dict` <- function(x, name) dict_key(x, name)

#' @rdname weft_dict
#' @export
`[[.weft_dict` <- function(x, i, ...) dict_key(x, i)

#' @rdname weft_dict
#' @export
`[.weft_dict` <- function(x, ...) {
  dict_abort("weft: `dict[...]` is not allowed: use dict$key or dict[[\"key\"]] (rule 4.1.2).")
}

dict_readonly <- function() {
  dict_abort("weft: the dictionary is read-only; change dict.yml (rule 4.1.4).")
}

#' @rdname weft_dict
#' @export
`$<-.weft_dict` <- function(x, name, value) dict_readonly()

#' @rdname weft_dict
#' @export
`[[<-.weft_dict` <- function(x, i, value) dict_readonly()

#' @rdname weft_dict
#' @export
`[<-.weft_dict` <- function(x, i, value) dict_readonly()

#' @rdname weft_dict
#' @export
as.list.weft_dict <- function(x, ...) {
  l <- unclass(x)
  attributes(l) <- list(names = names(l))
  l
}

dict_short <- function(x, key, type, unit) {
  v <- unclass(x)[[key]]
  switch(type,
    quantity = paste(format(as.numeric(units::drop_units(v))), unit),
    year = format(as.integer(v)),
    date = format(v),
    labels = sprintf("%d labels", attr(v, "weft_n") %||% NA_integer_),
    breaks = sprintf("%d bands", attr(v, "weft_n") %||% NA_integer_),
    string = v,
    format(v))
}

#' @rdname weft_dict
#' @export
print.weft_dict <- function(x, ...) {
  e <- attr(x, "entries")
  cat(sprintf("<weft_dict> %s: %d keys\n", attr(x, "file"), length(x)))
  for (i in seq_len(nrow(e))) {
    cat(sprintf("  %s  %s  %s\n", e$key[i], e$type[i],
                dict_short(x, e$key[i], e$type[i], e$unit[i])))
  }
  reg <- attr(x, "registered")
  if (length(reg)) cat("Units registered: ", paste(reg, collapse = ", "), "\n", sep = "")
  invisible(x)
}

#' The dictionary file
#'
#' The project dictionary is `dict.yml` at the project root: a YAML mapping
#' from key to entry. An empty file, or one holding only comments, is a
#' dictionary with no keys. A chapter's own entries are written in its front
#' matter under `weft:` / `dict_local:`, in the same form with a `why` (see
#' below); `dict_local` is not allowed in `_weft.yml`.
#'
#' Each entry has these fields; any other is an error, and so is a mistake in
#' any of them. All the problems in a file are reported together.
#'
#' * `value` (required): by `type`, see below.
#' * `type` (required): one of `number`, `quantity`, `year`, `date`,
#'   `string`, `labels`, `breaks`.
#' * `definition` (required): a string that is not blank; it is the text the
#'   glossary shows.
#' * `unit`: a string, for a `quantity` only.
#' * `decision`: a whole number from 1, or a string that is not blank; it is
#'   not resolved when the file is read.
#' * `why`: a string that is not blank, for a `dict_local` entry only, where
#'   it is required.
#'
#' A key is a valid R name (`make.names(key) == key`) and is not `file`.
#'
#' | `type` | `value` | read as |
#' |:--|:--|:--|
#' | `number` | a number, or a string that is a number literal | a double |
#' | `quantity` | as `number`, with `unit` | a `units` value |
#' | `year` | a whole number from 1000 to 9999 | an integer with the attribute `weft_type = "year"`, printed with no thousands mark |
#' | `date` | a string `YYYY-MM-DD` | a `Date` |
#' | `string` | a string (quote a number) | a character string |
#' | `labels` | a non-empty mapping of label to phrase | a [lookup()] function |
#' | `breaks` | a non-empty list of items | a [brk()] function |
#'
#' A `breaks` item is a mapping with a `phrase` and at most one of `below`
#' (the value is less than the bound) or `at_most` (less than or equal to
#' it); the bound is a number, `.inf` or `-.inf`. Only the last item may have
#' no bound, and then it takes every value left. Bounds may not decrease.
#'
#' YAML is read so that `yes`, `no`, `on`, `off`, `true` and `false` stay as
#' text. A duplicate key is an error.
#'
#' ```yaml
#' core_len:
#'   value: 0.5
#'   type: quantity
#'   unit: m
#'   definition: "Length of each sediment core."
#' trend_word:
#'   value:
#'     - {below: 0.95, phrase: "a fall in"}
#'     - {at_most: 1.05, phrase: "steady"}
#'     - {phrase: "a rise in"}
#'   type: breaks
#'   definition: "Wording for the ratio of this year's mean to last year's."
#' ```
#'
#' @seealso [read_dict()]
#' @name dict_file
NULL
