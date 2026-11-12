# weft's default units (rules 4.4.20-4.4.21, 3.4.10, 9.1.7; dev/design-2g.md).
# This file keeps a unit's token as typed, refuses the readings of the units package that a
# report does not mean, reads the default table `inst/weft-units.yml`, and brings the global
# units database to what the configuration in force wants, and no further.

# ---- state ---------------------------------------------------------------------------------

# `ready`: the database holds what the configuration in force wants. `installed`: each token
# weft installed, with its definition ("base" or the text of `is:`) and whether it redefines a
# reading of the units package. `removed`: each database mapping weft removed to install a
# token (the name `gal`), with the definition to restore it by. `ctx`: the mode, the tokens
# that rows with `is:` define, and those of them that are the default table's.
ud_state <- new.env(parent = emptyenv())
ud_state$ready <- FALSE
ud_state$installed <- list()
ud_state$removed <- list()
ud_state$ctx <- list(mode = "weft", own = character(), dflt = character())
ud_state$default_entries <- NULL

UNIT_TOKEN_RE <- "^[^[:space:][:digit:]*/^().+-][^[:space:]*/^().+-]*$"

# ---- keeping the token (4.4.20) ----------------------------------------------------------------

with_kept_names <- function(expr) {
  old <- units::units_options("auto_convert_names_to_symbols")
  units::units_options(auto_convert_names_to_symbols = FALSE)
  on.exit(units::units_options(auto_convert_names_to_symbols = old))
  expr
}

# The symbol the units package gives a token, when it is the symbol of the token's own row
# with the same prefix (`metre` is `m`); else the token as written (`Sv` is not `Gy`).
unit_own_symbol <- function(tok) {
  if (tok == "1" || grepl("^[0-9.]", tok) || tok %in% ud_state$ctx$own) return(tok)
  hit <- un_cache$sym[[tok]]
  if (!is.null(hit)) return(hit)
  s <- tryCatch(suppressWarnings(attr(units::as_units(tok), "units")$numerator), error = function(e) tok)
  out <- if (length(s) == 1L && !is.na(s) && nzchar(s) && s != tok &&
             identical(tok_resolve_db(tok)$id, tok_resolve_db(s)$id)) s else tok
  un_cache$sym[[tok]] <- out
  out
}

# The units of the text `txt`, each token kept as written (the symbolic_units of units).
unit_symbolic <- function(txt) {
  x <- with_kept_names(units::as_units(txt))
  un <- attr(x, "units")
  un$numerator <- vapply(un$numerator, unit_own_symbol, "", USE.NAMES = FALSE)
  un$denominator <- vapply(un$denominator, unit_own_symbol, "", USE.NAMES = FALSE)
  un
}

# `value` in the unit written `txt`, tokens kept.
u_set <- function(value, txt) units::set_units(value, unit_symbolic(txt), mode = "standard")

# ---- twin units (4.4.14) ------------------------------------------------------------------------

# The units the database defines alike, by the id of their rows.
UNIT_TWINS <- list(
  c(Sv = "sievert", Gy = "gray"),
  c(Bq = "becquerel", Bd = "baud", Hz = "hertz"),
  c(VA = "volt-ampere", W = "watt"))

# The text of the refusal of a conversion from `from` to `to` (symbolic units) between twins,
# without its rule, or NULL.
unit_twin_problem <- function(from, to, to_txt) {
  ids <- function(un) {
    toks <- unique(c(un$numerator, un$denominator))
    toks <- toks[toks != "1"]
    id <- vapply(toks, function(t) {
      r <- tok_resolve(t)
      if (r$known && !is.na(r$row)) ud_db()$id[r$row] else NA_character_
    }, "")
    id[!is.na(id)]
  }
  f <- ids(from)
  t <- ids(to)
  for (g in UNIT_TWINS) {
    ff <- intersect(f, names(g))
    tt <- intersect(t, names(g))
    if (length(ff) && length(tt) && !length(intersect(ff, tt))) {
      return(sprintf(paste0("`%s`: the quantity is in `%s`, and the units package defines the %s and the %s ",
                            "alike; they measure different things, so weft does not convert one to the other"),
                     to_txt, as.character(from), g[[ff[1L]]], g[[tt[1L]]]))
    }
  }
  NULL
}

# ---- refusals (4.4.20) -----------------------------------------------------------------------------

# Tokens the units package reads as a prefix and a unit, or as a name, that a report does not
# mean; refused under `weft` unless a row defines them.
UNIT_MISREAD_LIST <- c(
  pH = "a picohenry (`p` + `H`)",
  mph = "a milliphot (`m` + `ph`)",
  nmi = "a nanomile (`n` + `mi`)",
  Ma = "a megaare (`M` + `a`)",
  ka = "a kiloare (`k` + `a`)",
  gal = "the galileo, a unit of acceleration",
  mt = "a millitonne (`m` + `t`), which is 1 kg")

unit_token_refusal <- function(tok, ctx) {
  if (tok %in% ctx$own) return(NULL)
  mk <- function(body) list(body = body, text = paste0(body, " (rule 4.4.20)."))
  si <- " To take that reading, set `unit_defaults: si` in _weft.yml"
  if (identical(ctx$mode, "weft")) {
    if (tok %in% names(UNIT_MISREAD_LIST)) {
      advice <- if (tok == "mt") "Write `t` for a tonne, or `Mt` for a megatonne." else
        sprintf(paste0("weft's default table defines it, and `%s: false` in `units:` removed that row; ",
                       "define it there with `is:` (see unit_defaults())."), tok)
      return(mk(sprintf("`%s` is read by the units package as %s. %s%s", tok, UNIT_MISREAD_LIST[[tok]], advice, si)))
    }
    r <- tok_resolve_db(tok)
    if (r$known && !is.na(r$pre) && identical(r$kind, "symbol") && ud_db()$id[r$row] %in% c("ph", "a")) {
      db <- ud_db()
      p <- db$pf$symbol[r$pre]
      what <- if (db$id[r$row] == "ph") "phot" else "are"
      return(mk(sprintf(paste0("`%s` is read by the units package as a %s%s (`%s` + `%s`). Write the unit you ",
                               "mean (`km/h` for kilometres per hour, `Gyr` for a billion years).%s"),
                        tok, db$pf$name[r$pre], what, p, r$core, si)))
    }
  }
  if (length(ctx$dflt)) {
    db <- ud_db()
    for (j in seq_along(db$pre_tok)) {
      p <- db$pre_tok[j]
      if (db$pre_kind[j] != "symbol" || nchar(tok) <= nchar(p) || !startsWith(tok, p)) next
      rest <- substring(tok, nchar(p) + 1L)
      if (rest %in% ctx$dflt) {
        advice <- if (rest == "mph") "Write the unit you mean (`km/h` for kilometres per hour)" else
          "Write the unit you mean"
        return(mk(sprintf(paste0("`%s` is read as the prefix `%s` (%s) on `%s`, a unit of weft's default table, ",
                                 "and weft refuses a prefix on its own units. %s"),
                          tok, p, db$pf$name[db$pre_idx[j]], rest, advice)))
      }
    }
  }
  NULL
}

# The refusal of a unit text (list(body, text)), or NULL. `ctx` is the configuration's; NULL is
# the one in force.
unit_refusal <- function(txt, ctx = NULL) {
  if (is.null(ctx)) {
    units_ready()
    ctx <- ud_state$ctx
  }
  toks <- unique(unlist(regmatches(txt, gregexpr("[[:alpha:]_]+", txt))))
  for (tok in toks) {
    r <- unit_token_refusal(tok, ctx)
    if (!is.null(r)) return(r)
  }
  NULL
}

# ---- the default table (4.4.21) -------------------------------------------------------------------

unit_defaults_file <- function() system.file("weft-units.yml", package = "weft")

# The rows of the table, in file order, each list(key, is, name, plural, symbol, space, before,
# redefines).
unit_default_rows <- function() {
  if (!is.null(ud_state$rows)) return(ud_state$rows)
  y <- yaml::read_yaml(unit_defaults_file())$units
  rows <- lapply(names(y), function(k) {
    e <- y[[k]]
    is <- if (!is.null(e[["is"]])) as.character(e[["is"]]) else NULL
    list(key = k, is = is, name = e[["name"]], plural = e[["plural"]], symbol = e[["symbol"]],
         space = e[["space"]], before = e[["before"]],
         redefines = !is.null(is) && grepl(UNIT_TOKEN_RE, k) && isTRUE(tok_resolve_db(k)$known))
  })
  names(rows) <- names(y)
  ud_state$rows <- rows
  rows
}

#' The default units weft registers
#'
#' `unit_defaults()` returns weft's default table of units (rule 4.4.21), the rows
#' of `inst/weft-units.yml`, in file order. It registers nothing: the table is
#' registered the first time weft parses or converts a unit in a session, and again
#' as each configuration is read (see [u()]).
#'
#' A row is written as a row of `units:` in `_weft.yml` is, and may be copied
#' there. A row **redefines** (`redefines` is `TRUE`) when it has `is` and the
#' units package already reads its unit, alone or as a prefix and another unit:
#' `pH` as a picohenry, `mph` as a milliphot, `gal` as the galileo. Redefining rows
#' apply under `unit_defaults: weft` (the default) and are skipped under `si`; the
#' other rows apply in both.
#'
#' @return A data frame with one row per default unit and the columns `unit`, `is`
#'   (`"base"`, or the definition as the table writes it), `name`, `plural`,
#'   `symbol` (character, `NA` where the row has none), `space` (logical, `NA`
#'   where the row does not say), `before` (logical, `FALSE` where the row does not
#'   say) and `redefines` (logical). The attribute `file` is the path of the YAML
#'   file.
#' @examples
#' unit_defaults()
#' @export
unit_defaults <- function() {
  rows <- unit_default_rows()
  chr <- function(f) vapply(rows, function(r) if (is.null(r[[f]])) NA_character_ else as.character(r[[f]]), "")
  out <- data.frame(
    unit = names(rows), is = unname(chr("is")), name = unname(chr("name")), plural = unname(chr("plural")),
    symbol = unname(chr("symbol")),
    space = unname(vapply(rows, function(r) if (is.null(r$space)) NA else isTRUE(r$space), NA)),
    before = unname(vapply(rows, function(r) isTRUE(r$before), NA)),
    redefines = unname(vapply(rows, function(r) isTRUE(r$redefines), NA)),
    stringsAsFactors = FALSE)
  attr(out, "file") <- unit_defaults_file()
  out
}

# ---- the units database (4.4.21) --------------------------------------------------------------------

ud_conflict <- function(tok, def, default) {
  unit_abort(sprintf(paste0(
    "`%s` was installed in this session, not by weft, as a unit that is not `%s`, which %s defines it as. ",
    "Remove it with units::remove_unit(\"%s\"), or set `unit_defaults: si` (rule 4.4.21)."),
    tok, def, if (default) "weft's default table" else "`units:`", tok))
}

# Whether the units package still reads `tok` as its own database does (a prefix and a unit, or
# a row of its own), and nobody has installed it otherwise.
ud_is_pristine <- function(tok) {
  r <- tok_resolve_db(tok)
  if (!r$known) return(FALSE)
  db <- ud_db()
  def <- db$v$def[r$row]
  tgt <- if (nzchar(def)) def else db$id[r$row]
  val <- if (is.na(r$pre)) 1 else as.numeric(db$pf$value[r$pre])
  f <- tryCatch(as.numeric(units::ud_convert(1, tok, tgt)), error = function(e) NA_real_)
  isTRUE(abs(f - val) <= 1e-9 * abs(val))
}

ud_uninstall <- function(tok) {
  try(units::remove_unit(symbol = tok), silent = TRUE)
  ud_state$installed[[tok]] <- NULL
}

ud_restore_removed <- function(tok) {
  rec <- ud_state$removed[[tok]]
  try(if (identical(rec$kind, "name")) units::install_unit(name = tok, def = rec$def)
      else units::install_unit(tok, rec$def), silent = TRUE)
  ud_state$removed[[tok]] <- NULL
}

# Install one token. NULL when it is in the database as the row says (installed now, or by
# someone else as the row reads); list(error) when the units package refuses the definition.
ud_install_one <- function(tok, def, redef, default) {
  removed <- FALSE
  if (is.null(unit_parse_problem(tok))) {
    if (!(redef && ud_is_pristine(tok))) {
      if (identical(def, "base")) return(NULL)
      f <- tryCatch(as.numeric(units::ud_convert(1, tok, def)), error = function(e) NA_real_)
      if (isTRUE(abs(f - 1) <= 1e-9)) return(NULL)
      ud_conflict(tok, def, default)
    }
    r <- tok_resolve_db(tok)
    if (is.na(r$pre) && is.null(ud_state$removed[[tok]])) {
      db <- ud_db()
      d <- db$v$def[r$row]
      if (identical(r$kind, "name")) units::remove_unit(name = tok) else units::remove_unit(symbol = tok)
      ud_state$removed[[tok]] <- list(kind = r$kind, def = if (nzchar(d)) d else db$id[r$row])
      removed <- TRUE
    }
  }
  err <- tryCatch({
    if (identical(def, "base")) units::install_unit(tok) else units::install_unit(tok, def)
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err)) {
    if (removed) ud_restore_removed(tok)
    return(list(error = sub("\n.*$", "", err)))
  }
  ud_state$installed[[tok]] <- list(def = def, redef = redef)
  NULL
}

# Bring the database to the tokens `W` (each list(tok, def, redef, default)) in file order: undo
# what is no longer wanted or has changed, install the rest. A named list of the definitions the
# units package refused. Base registrations are not undone, unless they redefine a reading.
ud_sync <- function(W) {
  toks <- vapply(W, function(w) w$tok, "")
  defs <- vapply(W, function(w) w$def, "")
  inst <- ud_state$installed
  for (tok in rev(names(inst))) {
    i <- match(tok, toks)
    rec <- inst[[tok]]
    if (!is.na(i) && identical(defs[i], rec$def)) next
    if (is.na(i) && identical(rec$def, "base") && !isTRUE(rec$redef)) next
    ud_uninstall(tok)
  }
  for (tok in names(ud_state$removed)) {
    if (!(tok %in% toks) && is.null(ud_state$installed[[tok]])) ud_restore_removed(tok)
  }
  problems <- list()
  for (w in W) {
    rec <- ud_state$installed[[w$tok]]
    if (!is.null(rec) && identical(rec$def, w$def)) next
    # udunits reads a trailing digit as an exponent, so a token that ends in one cannot be used in
    # a definition, and once installed cannot be removed again
    if (!isTRUE(w$default) && grepl("[0-9]$", w$tok)) {
      pp <- if (identical(w$def, "base")) NULL else unit_parse_problem(w$def)
      problems[[w$tok]] <- if (!is.null(pp)) sprintf("`is` `%s` is not a unit the units package can read: %s", w$def, pp)
        else paste0("`is` cannot define a token that ends in a digit: the units package reads the digit as an ",
                    "exponent (`m2` is `m^2`), so it cannot be used in a definition or removed again")
      next
    }
    r <- ud_install_one(w$tok, w$def, w$redef, w$default)
    if (!is.null(r)) {
      problems[[w$tok]] <- sprintf("`is` `%s` is not a unit the units package can read: %s", w$def, r$error)
    }
  }
  problems
}

# Unloading weft (4.4.21): what it installed goes, but the base registrations that redefine
# nothing, and the names it removed come back.
ud_unload <- function() {
  for (tok in rev(names(ud_state$installed))) {
    rec <- ud_state$installed[[tok]]
    if (!identical(rec$def, "base") || isTRUE(rec$redef)) ud_uninstall(tok)
  }
  for (tok in names(ud_state$removed)) ud_restore_removed(tok)
  ud_state$ready <- FALSE
  invisible()
}

# Make the database what the configuration in force wants, before the first use in a session.
units_ready <- function() {
  if (isTRUE(ud_state$ready) || isTRUE(ud_state$busy)) return(invisible())
  r <- read_units_tables(units_tabs_empty(), "weft")
  ud_state$default_entries <- r$default
  invisible()
}

units_tabs_empty <- function() list(list(tbl = NULL, where = ""), list(tbl = NULL, where = ""))

# A failed read leaves the session at `weft` with the default rows only.
units_reset <- function() {
  if (isTRUE(ud_state$resetting)) return(invisible())
  ud_state$resetting <- TRUE
  on.exit(ud_state$resetting <- FALSE)
  ud_state$ready <- FALSE
  ud_state$ctx <- list(mode = "weft", own = character(), dflt = character())
  weft_env$units <- NULL
  weft_env$units_default <- NULL
  try(units_ready(), silent = TRUE)
  invisible()
}

# ---- the `units:` tables (9.1.7) ------------------------------------------------------------------------

UNITS_FIELDS <- c("name", "plural", "symbol", "space", "is", "before")
UNIT_ENTRY_FIELDS <- c("name", "plural", "symbol", "space", "before")

# The text of an `is:` value, list(text) or list(bad).
units_is_text <- function(v) {
  bad <- list(bad = TRUE)
  num <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0
  if (is.numeric(v) && length(v) == 1L) {
    return(if (num(v)) list(text = format(v, digits = 15, scientific = FALSE, trim = TRUE)) else bad)
  }
  if (!is.character(v) || length(v) != 1L || is.na(v)) return(bad)
  s <- gsub("[[:space:]]+", " ", trimws(v))
  if (!nzchar(s) || grepl("^[-+]", s)) return(bad)
  if (identical(s, "base")) return(list(text = s))
  if (grepl("^[0-9.]+([eE][-+]?[0-9]+)?$", s)) {
    x <- suppressWarnings(as.numeric(s))
    return(if (num(x)) list(text = s) else bad)
  }
  list(text = s)
}

# One `units:` table checked as far as its rows go, list(problems, rows, falses). A row is
# list(key, <its fields>); `is` is its text. A key with `is:` is one token.
units_table_rows <- function(tbl, where) {
  problems <- character()
  prob <- function(key, what) {
    problems <<- c(problems, if (is.null(key)) sprintf("%s: units: %s (rule 9.1.7)", where, what)
                   else sprintf("%s: units: `%s`: %s (rule 9.1.7)", where, key, what))
  }
  out <- list(problems = character(), rows = list(), falses = character())
  if (is.null(tbl)) return(out)
  if (!is.list(tbl) || (length(tbl) && (is.null(names(tbl)) || any(!nzchar(names(tbl)))))) {
    prob(NULL, paste0("must be a mapping from a unit to its `name`, `plural`, `symbol` and `space`, ",
                      "as `units:` in _weft.yml is written"))
    out$problems <- problems
    return(out)
  }
  str1 <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
  dkeys <- names(unit_default_rows())
  keys <- names(tbl)
  for (i in seq_along(tbl)) {
    key <- keys[i]
    e <- tbl[[i]]
    if (identical(e, FALSE)) {
      out$falses <- c(out$falses, key)
      next
    }
    n0 <- length(problems)
    if (is.null(e) || (is.list(e) && !length(e))) {
      prob(key, "is empty; give it a `name`, `plural`, `symbol` or `space`")
    } else if (!is.list(e) || is.null(names(e)) || any(!nzchar(names(e)))) {
      prob(key, "must be a mapping with the fields name, plural, symbol, space, is and before")
    } else {
      for (f in setdiff(names(e), UNITS_FIELDS)) {
        prob(key, sprintf("unknown field `%s`; the fields are %s", f, paste(UNITS_FIELDS, collapse = ", ")))
      }
      for (f in c("name", "plural")) {
        if (!is.null(e[[f]]) && !str1(e[[f]])) prob(key, sprintf("`%s` must be a string that is not empty", f))
      }
      if (!is.null(e[["symbol"]]) && !(str1(e[["symbol"]]) || identical(e[["symbol"]], FALSE))) {
        prob(key, "`symbol` must be a string that is not empty, or false")
      }
      if (!is.null(e[["space"]]) && !(is.logical(e[["space"]]) && length(e[["space"]]) == 1L && !is.na(e[["space"]]))) {
        prob(key, "`space` must be true or false")
      }
      if (!is.null(e[["before"]]) && !(is.logical(e[["before"]]) && length(e[["before"]]) == 1L && !is.na(e[["before"]]))) {
        prob(key, "`before` must be true or false")
      }
      if ("is" %in% names(e)) {
        it <- units_is_text(e[["is"]])
        if (!is.null(it$bad)) {
          prob(key, "`is` must be `base`, a positive number, or a number and a unit, such as `1 mi/h`")
        } else e[["is"]] <- it$text
        if (!grepl(UNIT_TOKEN_RE, key)) {
          prob(key, "`is` defines one unit, so the key must be one token, with no space and none of * / ^ ( ) . + -")
        } else {
          r <- tok_resolve_db(key)
          if (r$known && is.na(r$pre) && !(key %in% c(names(UNIT_MISREAD_LIST), dkeys))) {
            prob(key, sprintf("`is` cannot redefine `%s`, a unit of the units database; choose another key", key))
          }
        }
      }
    }
    if (length(problems) == n0) {
      out$rows[[key]] <- c(list(key = key), e[intersect(names(e), UNITS_FIELDS)])
    }
  }
  out$problems <- problems
  out
}

# The entries (key, id and the fields that print) of the rows `rows` of one table, with the
# problems of each key. Keys without `is` register the tokens the database lacks (4.4.7).
units_entries <- function(rows, where, installed) {
  problems <- character()
  prob <- function(key, what) {
    problems <<- c(problems, sprintf("%s: units: `%s`: %s (rule 9.1.7)", where, key, what))
  }
  entries <- list()
  for (row in rows) {
    key <- row$key
    n0 <- length(problems)
    un <- NULL
    if (is.null(row$is)) {
      reg <- dict_register_unit(key)
      installed$tok <- c(installed$tok, reg$installed)
      if (!is.null(reg$refusal)) {
        prob(key, reg$refusal)
      } else if (!is.null(reg$error)) {
        prob(key, sprintf("is not a unit the units package can read: %s", strip_rule(reg$error)))
      }
    }
    if (length(problems) == n0) {
      if (grepl("^[0-9.]+$", trimws(key))) {
        prob(key, "is a number, not a unit")
      } else {
        un <- tryCatch(unit_symbolic(key), error = function(e) NULL, warning = function(w) NULL)
        if (is.null(un)) prob(key, "is not a unit the units package can read")
        else if (!unit_present(un) || unit_cancels(un)) {
          prob(key, "holds no unit")
          un <- NULL
        }
      }
    }
    if (!is.null(un) && length(problems) == n0) {
      ent <- c(list(key = key, id = unit_whole_id(un)), row[intersect(names(row), UNIT_ENTRY_FIELDS)])
      dup <- vapply(entries, function(x) identical(x$id, ent$id), NA)
      if (any(dup)) {
        prob(key, sprintf("is the same unit as `%s`; give it one entry", entries[[which(dup)[1L]]]$key))
      } else entries[[length(entries) + 1L]] <- ent
    }
  }
  # `symbol: false` prints the name, so the unit must have one
  tmp <- list(units = entries)
  for (ent in entries) {
    if (identical(ent$symbol, FALSE) && is.null(ent$name)) {
      un <- unit_symbolic(ent$key)
      named <- tryCatch({ unit_name_text(un, TRUE, tmp, ""); TRUE }, error = function(e) FALSE)
      if (!named) prob(ent$key, "`symbol: false` prints the unit's name, and it has none; give it a `name`")
    }
  }
  list(problems = problems, entries = entries)
}

# The checked, merged `units:` table of the default rows, the project and the document (the
# default row under the project's or the document's, field by field; the document's row for a unit
# replaces the project's whole), with the database brought to it. `tabs` are the project's and the
# document's list(tbl, where); `mode` is `weft` or `si`. One weft_config_error holds every problem;
# a read with a problem leaves the session at the default rows (9.1.7, 4.4.21).
read_units_tables <- function(tabs, mode) {
  ud_state$busy <- TRUE
  on.exit(ud_state$busy <- FALSE)
  dflt <- unit_default_rows()
  tb <- lapply(tabs, function(t) units_table_rows(t$tbl, t$where))
  wheres <- vapply(tabs, function(t) t$where, "")
  probs <- list(tb[[1L]]$problems, tb[[2L]]$problems)
  add <- function(t, what) probs[[t]] <<- c(probs[[t]], what)
  prob <- function(t, key, what) add(t, sprintf("%s: units: `%s`: %s (rule 9.1.7)", wheres[t], key, what))
  # a `false` row removes a default row
  for (t in 1:2) {
    for (k in tb[[t]]$falses) {
      if (!k %in% names(dflt)) {
        prob(t, k, sprintf("`false` removes a row of weft's default table, and it has no row `%s`", k))
      }
    }
  }
  top <- function(k) {
    for (t in 2:1) {
      if (k %in% tb[[t]]$falses) return(list(false = TRUE, t = t))
      if (!is.null(tb[[t]]$rows[[k]])) return(list(false = FALSE, t = t, row = tb[[t]]$rows[[k]]))
    }
    NULL
  }
  keys <- unique(c(names(dflt), names(tb[[1L]]$rows), tb[[1L]]$falses, names(tb[[2L]]$rows), tb[[2L]]$falses))
  W <- list()
  drop_default <- character()
  dflt_own <- character()
  for (k in keys) {
    d <- dflt[[k]]
    if (!is.null(d) && mode == "si" && isTRUE(d$redefines)) d <- NULL
    tp <- top(k)
    if (!is.null(tp) && tp$false) {
      drop_default <- c(drop_default, k)
      next
    }
    is <- tp$row$is %||% d$is
    if (is.null(is)) next
    if (!is.null(d) && !is.null(d$is)) dflt_own <- c(dflt_own, k)
    W[[length(W) + 1L]] <- list(tok = k, def = is, redef = isTRUE(tok_resolve_db(k)$known),
                                default = is.null(tp$row$is), t = if (is.null(tp$row$is)) 0L else tp$t)
  }
  ctx <- list(mode = mode, own = vapply(W, function(w) w$tok, ""), dflt = dflt_own)
  # the rows that `is:` writes: one unit one row, and a unit weft can read
  seen <- list()
  keep <- rep(TRUE, length(W))
  for (i in seq_along(W)) {
    w <- W[[i]]
    if (!identical(w$def, "base")) {
      prev <- seen[[w$def]]
      if (!is.null(prev)) {
        if (w$t > 0L) {
          prob(w$t, w$tok, sprintf("`is` gives the same unit as `%s`%s; give it one row", prev$tok,
                                   if (prev$t == 0L) " (weft's default table)" else ""))
          keep[i] <- FALSE
        }
        next
      }
      seen[[w$def]] <- w
    }
    if (w$t > 0L && !identical(w$def, "base")) {
      ref <- unit_refusal(w$def, ctx)
      if (!is.null(ref)) {
        prob(w$t, w$tok, sprintf("`is` `%s`: %s", w$def, ref$body))
        keep[i] <- FALSE
      }
    }

  }
  Wk <- W[keep]
  ud_state$ctx <- ctx
  ud_state$ready <- FALSE
  fail <- function(extra = NULL) {
    inst <- unique(extra)
    for (tok in inst) try(units::remove_unit(tok, tok), silent = TRUE)
    ud_state$ctx <- list(mode = "weft", own = character(), dflt = character())
    blocks <- character()
    for (t in 1:2) {
      if (length(probs[[t]])) {
        blocks <- c(blocks, sprintf("weft: %s: %d problem(s) in `units:`\n%s", wheres[t], length(probs[[t]]),
                                    paste0("  ", probs[[t]], collapse = "\n")))
      }
    }
    units_reset()
    weft_abort(paste(blocks, collapse = "\n"), "weft_config_error")
  }
  synced <- tryCatch(ud_sync(Wk), error = function(e) { units_reset(); stop(e) })
  for (tok in names(synced)) {
    w <- Wk[[match(tok, vapply(Wk, function(x) x$tok, ""))]]
    if (w$t == 0L) {
      units_reset()
      unit_abort(sprintf("weft's default table: `%s`: %s", tok, synced[[tok]]))
    }
    prob(w$t, tok, synced[[tok]])
    tb[[w$t]]$rows[[tok]] <- NULL
  }
  # the entries
  installed <- new.env(parent = emptyenv())
  installed$tok <- character()
  def_rows <- Filter(function(d) !(mode == "si" && isTRUE(d$redefines)) && !(d$key %in% drop_default), unname(dflt))
  # a default row's `is` in the project's row does not matter here: its key is the same
  e_def <- units_entries(def_rows, "weft's default table", installed)
  if (length(e_def$problems)) {
    units_reset()
    unit_abort(paste(e_def$problems, collapse = "\n"))
  }
  e_t <- lapply(1:2, function(t) units_entries(tb[[t]]$rows, wheres[t], installed))
  for (t in 1:2) probs[[t]] <- c(probs[[t]], e_t[[t]]$problems)
  if (length(probs[[1L]]) || length(probs[[2L]])) fail(installed$tok)
  # a document's entry for a unit replaces the project's
  proj <- e_t[[1L]]$entries
  doc <- e_t[[2L]]$entries
  pk <- !vapply(proj, function(x) any(vapply(doc, function(d) identical(d$id, x$id), NA)), NA)
  over <- c(proj[pk], doc)
  ud_state$ready <- TRUE
  list(units = stats::setNames(over, vapply(over, function(e) e$key, "")),
       default = stats::setNames(e_def$entries, vapply(e_def$entries, function(e) e$key, "")))
}

# The entry of a unit: the default row's, with the project's or the document's fields over it.
unit_entry <- function(cfg, id) {
  E <- list()
  for (e in cfg$units) if (identical(e$id, id)) { E <- e; break }
  D <- list()
  for (e in cfg$units_default) if (identical(e$id, id)) { D <- e; break }
  for (f in names(E)) D[[f]] <- E[[f]]
  D
}
