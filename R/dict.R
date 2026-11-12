# The dictionary object (rules 4.1-4.3, 4.4.7, 9.1.2): `read_dict()`, the
# `weft_dict` class and its methods, `dict_local` from front matter.
# Contract: dev/design-2.md section 2.

DICT_TYPES <- c("number", "quantity", "year", "date", "string", "labels", "breaks")
DICT_FIELDS <- c("value", "type", "definition", "unit", "display", "decision", "why",
                 "term", "avoid")

# YAML words such as `yes` and `no` stay text (D6). A whole number is read
# as a decimal, whatever its size (a double), and an octal or hex integer
# stays the text that was written, so that it can be refused (ruling 3, j).
dict_yaml_handlers <- function() {
  list("bool#yes" = identity, "bool#no" = identity,
       "int" = function(x) suppressWarnings(as.numeric(x)),
       "int#oct" = identity, "int#hex" = identity)
}

dict_abort <- function(message, class = "weft_dict_error") weft_abort(message, class)

# The parsed YAML of `lines`; a failure is an empty list with the attribute
# `yaml_error`.
dict_parse <- function(lines) {
  withCallingHandlers(
    tryCatch(
      yaml::yaml.load(paste(lines, collapse = "\n"), handlers = dict_yaml_handlers(),
                      eval.expr = FALSE),
      error = function(e) structure(list(), yaml_error = conditionMessage(e))),
    warning = function(w) {
      if (grepl("Empty character vector used as a list name", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    })
}

DICT_KEY_RX <- paste0(
  "^( *)(\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^']|'')*'|",
  "(?:[^\\s#'\"&*!|>%@{}\\[\\],:-]|-[^\\s])(?:[^:]|:(?=\\S))*?)\\s*:(?=\\s|$)")

# What the file's lines say before YAML reads them (rule 4.2.1, 4.1.3): the
# top-level keys as written, each with its line; the problems that YAML would
# hide (a duplicate field, a merge key, a second document); and the lines
# with those keys renamed so that YAML reads on (the keys are put back from
# `tk`). `first` and `last` bound the lines of the dictionary.
dict_prepare <- function(lines, first = 1L, last = length(lines), docs = TRUE) {
  pre <- list()
  add <- function(line, what, key = NULL) {
    pre[[length(pre) + 1L]] <<- list(line = line, what = what, key = key)
  }
  none <- data.frame(key = character(), line = integer(), plain = logical(),
                     stringsAsFactors = FALSE)
  out <- lines
  if (last < first) return(list(lines = out, tk = none, pre = pre))
  idx <- seq.int(first, last)
  txt <- lines[idx]
  ind <- nchar(sub("^( *).*$", "\\1", txt))
  marker <- grepl("^(---|\\.\\.\\.)(\\s|$)", txt)
  body <- grepl("\\S", txt) & !grepl("^\\s*#", txt) & !marker
  if (docs && any(body)) {
    later <- which(grepl("^---(\\s|$)", txt) & seq_along(txt) > which(body)[1L])
    if (length(later)) {
      add(idx[later[1L]], "the file holds more than one YAML document; write one")
    }
  }
  merge <- which(body & grepl("^\\s*(-\\s+)?<<\\s*:|[{,]\\s*<<\\s*:", txt))
  tk <- none
  if (any(body)) {
    b0 <- which(body)[1L]
    if (!grepl("^ *[{\\[-]", txt[b0])) {
      cand <- which(body & ind == ind[b0])
      m <- regexec(DICT_KEY_RX, txt[cand], perl = TRUE)
      hit <- vapply(m, function(z) z[1L] > 0L, NA)
      cand <- cand[hit]
      m <- m[hit]
      if (length(cand)) {
        parts <- regmatches(txt[cand], m)
        key <- vapply(parts, function(z) z[3L], "")
        q <- substr(key, 1L, 1L)
        plain <- !(q %in% c("\"", "'"))
        key <- ifelse(q %in% c("\"", "'"), substr(key, 2L, nchar(key) - 1L), key)
        key <- ifelse(q == "'", gsub("''", "'", key, fixed = TRUE), key)
        len <- vapply(parts, function(z) nchar(z[1L]), 1L)
        rest <- substring(txt[cand], len + 1L)
        tk <- data.frame(key = key, line = idx[cand], plain = plain, stringsAsFactors = FALSE)
        out[idx[cand]] <- paste0(strrep(" ", ind[cand]), "weft_k", seq_along(cand), ":", rest)
        ends <- c(cand[-1L] - 1L, length(txt))
        for (j in seq_along(cand)) {
          if (!grepl("^\\s*(#.*)?$", rest[j]) || ends[j] <= cand[j]) next
          reg <- seq.int(cand[j] + 1L, ends[j])
          reg <- reg[body[reg]]
          if (!length(reg)) next
          fl <- reg[ind[reg] == ind[reg[1L]]]
          fm <- regexec(DICT_KEY_RX, txt[fl], perl = TRUE)
          ok <- vapply(fm, function(z) z[1L] > 0L, NA)
          fl <- fl[ok]
          fp <- regmatches(txt[fl], fm[ok])
          fk <- vapply(fp, function(z) z[3L], "")
          for (d in which(duplicated(fk))) {
            add(idx[fl[d]], sprintf("`%s` is written twice", fk[d]), key[j])
            out[idx[fl[d]]] <- paste0(strrep(" ", ind[fl[d]]), "weft_dup_", idx[fl[d]], ":",
                                      substring(txt[fl[d]], nchar(fp[[d]][1L]) + 1L))
          }
        }
      }
    }
  }
  for (z in merge) {
    owner <- tk$key[tk$line <= idx[z]]
    add(idx[z], "merge keys are not read (`<<`); write the fields out",
        if (length(owner)) owner[length(owner)] else NULL)
  }
  list(lines = out, tk = tk, pre = pre)
}

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
#' session (rule 4.4.7); a unit already known is not installed again. A read
#' that reports a problem installs no unit. The attribute `registered` holds
#' the units the dictionary needs that `udunits` does not ship, whenever and
#' by whomever they were installed, so two reads of one file give the same
#' `registered`, and `print()` lists them.
#'
#' The units installed stay installed for the rest of the R session, so a
#' unit one project's dictionary declared is known to the next document knitted
#' in the same session, even one that never declared it (it fails in a fresh
#' session). In a knit, `dict` and `dict_local` are removed at the start of
#' every top-level knit and assigned again from that knit's own files: a
#' document with neither sees neither, and an object of the session's own
#' called `dict` is replaced during a knit that has a dictionary and is not
#' restored.
#'
#' `dict$key` and `dict[["key"]]` match the key exactly: a key not held is a
#' `weft_dict_key_error`, never `NULL` (rule 4.1.2). A dictionary is read-only
#' (rule 4.1.4): assigning to it, `names<-` and `dict[...]` are a
#' `weft_dict_error`. `str()`, `summary()`, `lapply()`, `Map()` and `mapply()`
#' work on it as they do on the plain list; `attr<-` and `class<-` cannot be
#' stopped.
#' `as.list()` gives the plain named list of values.
#'
#' All the problems in a file are collected and raised together as one
#' `weft_dict_error`. A chunk served from knitr's cache that read `dict` is
#' not re-run when `dict.yml` changes.
#'
#' @param path One string naming an existing file.
#' @return A `weft_dict`, with the attributes `file`, `scope` (`"project"` or
#'   `"local"`), `entries` (a data frame of the keys' type, definition, unit,
#'   decision, why, line and display), `registered` and `local_keys`.
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
  if (length(lines)) lines[1L] <- sub("^\ufeff", "", lines[1L])
  prep <- dict_prepare(lines)
  build_dict(dict_parse(prep$lines), path, "project", lines = lines, prep = prep)
}

# Validate `raw` (the parsed YAML) and build the object, or stop with every
# problem. `lines` are the file's lines, `first` the first line to search
# for keys (a local dictionary lives inside the front matter), `offset`
# what to add to an index in `lines` to get the line in the file and `prep`
# what dict_prepare() found.
build_dict <- function(raw, file, scope, lines = character(), first = 1L, offset = 0L,
                       prep = NULL) {
  problems <- character()
  at <- integer()
  prob <- function(what, rule, key = NULL, line = NA_integer_) {
    where <- if (is.na(line)) file else paste0(file, ":", line)
    problems <<- c(problems, if (is.null(key)) sprintf("%s: %s (rule %s)", where, what, rule)
                   else sprintf("%s: `%s`: %s (rule %s)", where, key, what, rule))
    at <<- c(at, line)
  }
  for (z in prep$pre) prob(z$what, "4.2.1", z$key, z$line + offset)
  yerr <- attr(raw, "yaml_error")
  if (!is.null(yerr)) {
    dup <- regmatches(yerr, regexec("Duplicate map key: '([^']*)'", yerr))[[1L]]
    if (length(dup) == 2L) {
      # the key's second `key:` line
      hit <- which(startsWith(sub("^[ \t]+", "", lines), paste0(dup[2L], ":")))
      hit <- hit[hit >= first]
      prob("the key is written twice", "4.2.1", dup[2L],
           if (length(hit) >= 2L) hit[2L] + offset else NA_integer_)
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
  tk <- prep$tk
  key_line <- rep(NA_integer_, length(raw))
  if (length(raw) && !is.null(tk) && nrow(tk) == length(raw)) {
    names(raw) <- tk$key
    key_line <- tk$line + offset
  }
  keys <- names(raw) %||% character()
  repeated <- duplicated(keys)
  nulls <- if (length(keys) && !is.null(tk) && nrow(tk) == length(keys)) {
    tk$plain & tk$key %in% c("null", "Null", "NULL")
  } else rep(FALSE, length(keys))
  values <- vector("list", length(raw))
  rows <- vector("list", length(raw))
  registered <- character()
  installed <- character()
  # `avoid` is read once more with `true` and `false` marked and every list
  # kept as a list: YAML reads them as booleans, which weft reads as text
  # elsewhere (4.2.5), and a list of one string as that string
  raw2 <- NULL
  avoid_raw <- function(i) {
    if (scope != "project" || is.null(prep)) return(NULL)
    if (is.null(raw2)) {
      h <- list(seq = function(x) structure(as.list(x), class = "weft_seq"),
                "bool#yes" = mark_bool, "bool#no" = mark_bool)
      raw2 <<- tryCatch(yaml::yaml.load(paste(prep$lines, collapse = "\n"), handlers = h,
                                        eval.expr = FALSE), error = function(e) list())
      if (length(raw2) != length(raw)) raw2 <<- list()
    }
    e2 <- raw2[[i]]
    if (is.list(e2) && "avoid" %in% names(e2)) e2[["avoid"]] else NULL
  }
  canon <- rep(NA_character_, length(raw))
  tprob <- rep(FALSE, length(raw))
  for (i in seq_along(raw)) {
    key <- keys[i]
    line <- key_line[i]
    p <- function(what, rule) prob(what, rule, key, line)
    if (repeated[i]) p("the key is written twice", "4.2.1")
    if (nulls[i]) p("YAML reads an unquoted `null` as null, not as a name; write it in quotes", "4.1.3")
    if (!identical(make.names(key), key) || grepl("^\\.\\.(\\.|[0-9]+)$", key)) {
      p("a key must be a valid R name (letters, digits, `.` and `_`, not starting with a digit, not a reserved word)", "4.1.3")
    } else if (identical(key, "file")) {
      p("`file` is reserved and cannot be a key", "4.1.3")
    }
    e <- raw[[i]]
    if (!is.list(e) || is.null(names(e)) || any(!nzchar(names(e)))) {
      p("the entry must be a mapping with the fields `value`, `type` and `definition`", "4.2.1")
      next
    }
    e <- e[!startsWith(names(e), "weft_dup_")]
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
    disp <- NA_character_
    if (!is.null(e[["display"]])) {
      if (type_ok && type != "quantity") {
        p(sprintf("`display` is only for a quantity, and this is a %s", type), "4.2.7")
      } else if (!str1(e[["display"]])) {
        p("`display` must be a string that is not blank", "4.2.7")
      } else disp <- e[["display"]]
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
    # `term` and `avoid` (rules 4.7.3, 4.7.4)
    trm <- NA_character_
    if (!is.null(e[["term"]])) {
      if (str1(e[["term"]])) trm <- e[["term"]]
      else { p("`term` must be a string that is not blank", "4.7.3"); tprob[i] <- TRUE }
    }
    avd <- character()
    if (!is.null(e[["avoid"]])) {
      a <- avoid_raw(i) %||% e[["avoid"]]
      if (scope != "project") {
        p("`avoid` is for dict.yml; a chapter's own entries write no Vale rules", "4.7.4")
        tprob[i] <- TRUE
      } else {
        avd <- avoid_items(a)
        if (!is.null(avd)) avd <- trimws(avd)
        if (any(!nzchar(avd))) avd <- NULL
      }
      if (is.null(avd)) {
        p("`avoid` must be a string, or a list of strings, none blank", "4.7.4")
        tprob[i] <- TRUE
        avd <- character()
      } else if (scope == "project") {
        if (is.na(trm) && !(type_ok && type == "string")) {
          p("`avoid` needs a `term`: the spelling the avoided ones are replaced by", "4.7.4")
          tprob[i] <- TRUE
        } else {
          cn <- if (!is.na(trm)) trm else e[["value"]]
          if (is.character(cn) && length(cn) == 1L && !is.na(cn)) {
            for (v in unique(avd[avd == cn])) {
              p(sprintf("`avoid` lists `%s`, which is the entry's own spelling", v), "4.7.4")
              tprob[i] <- TRUE
            }
          }
          for (v in unique(avd[duplicated(avd)])) {
            p(sprintf("`avoid` lists `%s` twice", v), "4.7.4")
            tprob[i] <- TRUE
          }
        }
      }
    }
    if (!tprob[i]) {
      canon[i] <- if (!is.na(trm)) trm else
        if (type_ok && type == "string" && is.character(e[["value"]]) && length(e[["value"]]) == 1L)
          e[["value"]] else NA_character_
    }
    if (is.null(e[["value"]]) && !"value" %in% names(e)) p("`value` is missing", "4.2.1")
    else if (is.null(e[["value"]])) p("`value` is empty", "4.2.1")
    if (type_ok && !is.null(e[["value"]])) {
      r <- dict_value(e[["value"]], type, unit)
      if (!is.null(r$error)) p(paste0("`value` ", r$error), "4.2.1")
      else values[i] <- list(r$value)
    }
    if (type_ok && type == "quantity" && !is.na(unit) && length(problems) == n0) {
      reg <- dict_register_unit(unit)
      installed <- c(installed, reg$installed)
      if (!is.null(reg$error)) {
        p(sprintf("`unit` `%s` is not a unit the units package can read: %s", unit, strip_rule(reg$error)), "4.4.7")
      } else {
        registered <- c(registered, reg$needed)
        values[i] <- list(units::set_units(values[[i]], unit, mode = "standard"))
        # the value is read in `unit` and converted to `display` (4.2.7)
        if (!is.na(disp)) {
          dreg <- dict_register_unit(disp)
          installed <- c(installed, dreg$installed)
          if (!is.null(dreg$error)) {
            p(sprintf("`display` `%s` is not a unit the units package can read: %s", disp, strip_rule(dreg$error)), "4.2.7")
          } else {
            registered <- c(registered, dreg$needed)
            conv <- tryCatch(units::set_units(values[[i]], disp, mode = "standard"),
                             error = function(e) NULL)
            if (is.null(conv)) {
              p(sprintf("`display` `%s` is not a unit `unit` (`%s`) converts to", disp, unit), "4.2.7")
            } else if (converts_by_inversion(values[[i]], conv)) {
              p(sprintf(paste0("`display` `%s` is of another dimension than `unit` (`%s`), which units reaches ",
                               "by inverting the value; write the reciprocal in the expression"), disp, unit), "4.2.7")
            } else values[i] <- list(conv)
          }
        }
      }
    }
    str_or_na <- function(x) if (str1(x)) x else NA_character_
    rows[[i]] <- list(key = key, type = if (type_ok) type else NA_character_,
                      definition = str_or_na(e[["definition"]]), unit = unit,
                      display = disp, decision = dec, why = why, line = as.integer(line),
                      term = trm, avoid = avd)
  }
  # the spellings against each other (rule 4.7.4); only entries whose own
  # `term` and `avoid` had no problem take part
  if (scope == "project") {
    ok <- vapply(rows, function(r) !is.null(r), NA) & !tprob
    seen <- list()
    for (i in which(ok)) {
      for (v in rows[[i]]$avoid) {
        earlier <- names(seen)[vapply(seen, function(k) v %in% k, NA)]
        if (length(earlier) && !identical(earlier[1L], keys[i])) {
          prob(sprintf("`avoid` lists `%s`, which `%s` also lists", v, earlier[1L]), "4.7.4",
               keys[i], key_line[i])
          next
        }
        for (j in which(ok & !is.na(canon))) {
          if (identical(v, canon[j]) && j == i) next
          if (word_in(v, canon[j])) {
            prob(sprintf("`avoid` lists `%s`, which is part of the spelling `%s` of `%s`; Vale would flag that spelling",
                         v, canon[j], keys[j]), "4.7.4", keys[i], key_line[i])
            break
          }
        }
      }
      seen[[keys[i]]] <- rows[[i]]$avoid
    }
  }
  if (length(problems)) {
    # a read that reports problems installs no unit (ruling 6)
    for (tok in unique(installed)) try(units::remove_unit(tok, tok), silent = TRUE)
    problems <- problems[order(ifelse(is.na(at), 0L, at))]
    dict_abort(paste0(sprintf("weft: %s: %d problem(s) in the dictionary", file, length(problems)),
                      "\n", paste(problems, collapse = "\n")))
  }
  col <- function(f, type) vapply(rows, function(r) r[[f]], type)
  entries <- data.frame(
    key = col("key", ""), type = col("type", ""), definition = col("definition", ""),
    unit = col("unit", ""), decision = col("decision", ""), why = col("why", ""),
    line = col("line", 1L), display = col("display", ""), term = col("term", ""),
    stringsAsFactors = FALSE)
  entries$avoid <- lapply(rows, function(r) r$avoid)
  rownames(entries) <- NULL
  names(values) <- keys
  structure(values, class = "weft_dict", file = file, scope = scope,
            entries = entries, registered = unique(registered),
            local_keys = character())
}

mark_bool <- function(x) if (tolower(x) %in% c("true", "false")) paste0("\001", x) else x

# The strings of an `avoid` as the second reading gives it, or NULL when it
# is not a string or a non-empty list of strings.
avoid_items <- function(a) {
  one <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && !startsWith(x, "\001")
  if (one(a)) return(a)
  if (is.list(a) && length(a) && (inherits(a, "weft_seq") || is.null(names(a))) &&
      all(vapply(a, one, NA))) {
    return(unlist(a, use.names = FALSE))
  }
  NULL
}

# Whether `v` occurs in `canon` as whole words: not touching a letter, digit
# or underscore on either side.
word_in <- function(v, canon) {
  esc <- gsub("([\\x21-\\x2f\\x3a-\\x40\\x5b-\\x60\\x7b-\\x7e])", "\\\\\\1", v, perl = TRUE)
  grepl(paste0("(?<![[:alnum:]_])", esc, "(?![[:alnum:]_])"), canon, perl = TRUE)
}

NONDECIMAL <- paste0("is a whole number written with a leading zero, or in hex or octal; ",
                     "write it in decimal")

# A whole number that YAML 1.1 would read as octal or hex, or that is a
# string written like one.
nondecimal <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) &&
    grepl("^[+-]?0([0-9]+|[xXoObB][0-9A-Fa-f_]+)$", trimws(x))
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
      if (nondecimal(v)) bad(NONDECIMAL)
      else if (is.null(n)) bad("must be a number, or a string that is a number literal") else list(value = n)
    },
    year = {
      n <- num_literal(v)
      if (nondecimal(v)) bad(NONDECIMAL)
      else if (is.null(n) || n != round(n) || n < 1000 || n > 9999) {
        bad("must be a whole number from 1000 to 9999")
      } else list(value = new_weft_year(as.integer(n)))
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
  last_kind <- NULL
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
      if (nondecimal(b)) return(bad(sprintf("item %d: `%s` %s", k, bnd, NONDECIMAL)))
      if (!(is.numeric(b) && length(b) == 1L && !is.na(b))) b <- num_literal(b)
      if (is.null(b)) return(bad(sprintf("item %d: `%s` must be a number, `.inf` or `-.inf`", k, bnd)))
      if (b < last) return(bad(sprintf("item %d: the bounds must not decrease", k)))
      if (b == last && !(identical(last_kind, "below") && bnd == "at_most")) {
        return(bad(sprintf("item %d: no value can be in this band, as the bound repeats the one before", k)))
      }
      last <- b
      last_kind <- bnd
      fs[[k]] <- eval(call("~", call(if (bnd == "below") "<" else "<=", quote(.), b), ph), baseenv())
    }
  }
  f <- do.call(brk, fs)
  attr(f, "weft_n") <- length(v)
  list(value = f)
}

# A message without its closing "(rule N)", for one that adds its own.
strip_rule <- function(x) sub(" \\(rule [0-9.]+\\)$", "", x)

# The names the units database ships with: symbols, names and their
# aliases, and the prefixes.
ud_cache <- new.env(parent = emptyenv())

ud_shipped <- function(tok) {
  if (is.null(ud_cache$names)) {
    v <- NULL
    utils::capture.output(v <- suppressMessages(units::valid_udunits()))
    pf <- NULL
    utils::capture.output(pf <- suppressMessages(units::valid_udunits_prefixes()))
    cells <- unlist(v[c("symbol", "symbol_aliases", "name_singular", "name_singular_aliases",
                        "name_plural", "name_plural_aliases")], use.names = FALSE)
    ud_cache$names <- unique(trimws(unlist(strsplit(cells[nzchar(cells)], "[, ]+"))))
    ud_cache$prefixes <- unique(c(pf$symbol, pf$name))
  }
  if (tok %in% ud_cache$names) return(TRUE)
  for (pre in ud_cache$prefixes) {
    if (nzchar(pre) && startsWith(tok, pre) && substring(tok, nchar(pre) + 1L) %in% ud_cache$names) {
      return(TRUE)
    }
  }
  FALSE
}

# Install each token of `unit` that the units database does not know
# (4.4.7); then `unit` must parse. list(installed, needed) or list(error,
# installed): `installed` are the tokens this call installed, `needed` those
# `udunits` does not ship, whoever installed them (ruling 6, 7, e).
dict_register_unit <- function(unit) {
  bad <- unit_misread(unit)
  if (!is.null(bad)) return(list(error = bad, installed = character()))
  toks <- unique(unlist(regmatches(unit, gregexpr("[^[:space:][:digit:]*/^().+-]+", unit))))
  needed <- toks[!vapply(toks, ud_shipped, NA)]
  installed <- character()
  for (tok in needed) {
    if (is.null(unit_parse_problem(tok))) next
    r <- tryCatch({ units::install_unit(tok); NULL }, error = function(e) conditionMessage(e))
    if (!is.null(r)) return(list(error = r, installed = installed))
    installed <- c(installed, tok)
  }
  r <- unit_parse_problem(unit)
  if (!is.null(r)) return(list(error = r, installed = installed))
  list(installed = installed, needed = needed)
}

# ---- dict_local (4.3) ------------------------------------------------------

# The document's front-matter `weft: dict_local:` as a local `weft_dict`, or
# NULL when it has none. The front matter is parsed again here so that `yes`
# and `no` stay text.
read_dict_local <- function(path) {
  fl <- front_matter_lines(path)
  if (is.null(fl)) return(NULL)
  at <- which(grepl("^\\s*dict_local\\s*:", fl))[1L]
  # the lines of the dictionary: those after `dict_local:` that are indented
  # more than it
  first <- if (is.na(at)) 1L else at + 1L
  last <- length(fl)
  if (!is.na(at) && first <= last) {
    base <- nchar(sub("^( *).*$", "\\1", fl[at]))
    ind <- nchar(sub("^( *).*$", "\\1", fl))
    out <- which(seq_along(fl) >= first & grepl("\\S", fl) & !grepl("^\\s*#", fl) & ind <= base)
    if (length(out)) last <- out[1L] - 1L
  }
  prep <- dict_prepare(fl, first, last, docs = FALSE)
  y <- dict_parse(prep$lines)
  raw <- if (is.list(y) && is.list(y$weft)) y$weft$dict_local else NULL
  if (is.null(raw)) return(NULL)
  build_dict(raw, path, "local", lines = fl, first = first, offset = 1L, prep = prep)
}

# Assign `dict` and `dict_local` into the knit's environment and the state
# (2.1.5). What an earlier knit assigned is removed first, so that a document
# with neither sees neither (ruling 1).
init_dicts <- function(s, root, path) {
  env <- knitr::knit_global()
  for (nm in c("dict", "dict_local")) {
    if (exists(nm, envir = env, inherits = FALSE) &&
        inherits(get(nm, envir = env, inherits = FALSE), "weft_dict")) {
      rm(list = nm, envir = env)
    }
  }
  proj <- NULL
  f <- file.path(root, "dict.yml")
  if (file.exists(f)) proj <- read_dict(f)
  loc <- if (!is.null(path)) read_dict_local(path) else NULL
  if (is.null(proj) && is.null(loc)) return(invisible())
  if (is.null(loc)) loc <- build_dict(list(), path %||% f, "local")
  if (!is.null(proj)) attr(proj, "local_keys") <- names(loc)
  attr(loc, "project_keys") <- names(proj)
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
`[[.weft_dict` <- function(x, i, ...) {
  # base R's own walks over a list (str(), summary(), mapply()) index by
  # position; a call from a function in base or utils is let through
  if (is.numeric(i) && length(i) == 1L && !is.na(i) && dict_base_caller()) {
    return(unclass(x)[[i]])
  }
  dict_key(x, i)
}

dict_base_caller <- function() {
  f <- tryCatch(sys.function(sys.parent(2L)), error = function(e) NULL)
  is.function(f) && !is.null(environment(f)) &&
    environmentName(topenv(environment(f))) %in% c("base", "utils")
}

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
`names<-.weft_dict` <- function(x, value) {
  dict_abort("weft: the dictionary is read-only; its keys cannot be renamed (rule 4.1.4).")
}

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
    string = if (nchar(v) > 40L) paste0(substr(v, 1L, 37L), "...") else v,
    format(v))
}

#' @rdname weft_dict
#' @export
print.weft_dict <- function(x, ...) {
  e <- attr(x, "entries")
  cat(sprintf("<weft_dict> %s: %d %s\n", attr(x, "file"), length(x),
              if (length(x) == 1L) "key" else "keys"))
  for (i in seq_len(nrow(e))) {
    shown <- if (is.na(e$display[i])) e$unit[i] else e$display[i]
    cat(sprintf("  %s  %s  %s\n", e$key[i], e$type[i],
                dict_short(x, e$key[i], e$type[i], shown)))
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
#' * `display`: a string, for a `quantity` only (rule 4.2.7): the unit to show
#'   the value in. The value is read in `unit` and converted to `display` when
#'   the file is read, so `dict$key` is already in `display`, and arithmetic,
#'   checks, `#` and `units::drop_units()` see it. A `display` that does not
#'   parse, or that `unit` does not convert to, is a problem; `unit =` at the use
#'   converts back. The `entries` column `display` is `NA` where absent.
#' * `decision`: a whole number from 1, or a string that is not blank; it is
#'   not resolved when the file is read.
#' * `why`: a string that is not blank, for a `dict_local` entry only, where
#'   it is required.
#' * `term`: a string that is not blank, on any type: the words a reader knows
#'   the entry by. [dict_glossary()] heads the entry with it and [dict_vale()]
#'   keeps it as the entry's spelling (rule 4.7.3).
#' * `avoid`: one string, or a non-empty list of strings, none blank, in
#'   `dict.yml` only (rule 4.7.4). They are spellings [dict_vale()] replaces by
#'   the entry's canonical spelling: its `term`, or, for a `string` entry with
#'   no `term`, its value; any other entry needs a `term`. A spelling that is
#'   the entry's own, is listed twice, is listed by another entry, or is found
#'   as whole words inside any entry's canonical spelling is a problem. The
#'   `entries` columns `term` and `avoid` hold `NA` and `character(0)` where
#'   absent.
#'
#' A key is a valid R name (`make.names(key) == key`) that is not reserved
#' (`..1` and `...` are refused) and is not `file`. A whole number written
#' with a leading zero, or in hex or octal (`010`, `0x1F`, `0o17`), is an
#' error: write it in decimal. A merge key (`<<`) is an error, and so is a
#' file of more than one YAML document; anchors and aliases without a merge
#' key are allowed. A whole number too large for an integer is a number (a
#' double), but under `year` is still an error. In a document's front matter,
#' `dict_local` keys that YAML reads as booleans (`yes`, `on`, `true`) should
#' be quoted if two of one truth value are used in one map, since knitr and
#' Quarto read the front matter before weft does.
#'
#' | `type` | `value` | read as |
#' |:--|:--|:--|
#' | `number` | a number, or a string that is a number literal | a double |
#' | `quantity` | as `number`, with `unit` | a `units` value |
#' | `year` | a whole number from 1000 to 9999 | a [weft_year][weft_year]: an integer, printed with no thousands mark |
#' | `date` | a string `YYYY-MM-DD` | a `Date` |
#' | `string` | a string (quote a number) | a character string |
#' | `labels` | a non-empty mapping of label to phrase | a [lookup()] function |
#' | `breaks` | a non-empty list of items | a [brk()] function |
#'
#' A `breaks` item is a mapping with a `phrase` and at most one of `below`
#' (the value is less than the bound) or `at_most` (less than or equal to
#' it); the bound is a number, `.inf` or `-.inf`. Only the last item may have
#' no bound, and then it takes every value left. Bounds may not decrease, and
#' a bound may not repeat the one before it so that no value is left for its
#' band (`at_most: 1` then `below: 1`, or equal bounds of one kind). A bound
#' may be a number written in a string, as `number` may.
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
#' @seealso [read_dict()], [weft_year]
#' @name dict_file
NULL
