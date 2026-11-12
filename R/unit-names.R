# Unit names, symbols and settings (rules 4.4.15-4.4.19, 9.1.7; dev/design-2f.md).
# A unit prints as its symbol or as its name. This file resolves a unit's tokens
# against the `units:` table, the shipped table and the units database, and builds
# the symbol text, the name and the space before a unit.

# ---- language ------------------------------------------------------------

lang_is_english <- function(lang) {
  l <- tolower(sub("[-_].*$", "", lang %||% ""))
  !nzchar(l) || l == "en"
}

lang_is_us <- function(lang) grepl("^en[-_]us$", lang %||% "", ignore.case = TRUE)

# The language of the knit in progress, or "" (English) outside one.
current_lang <- function() {
  s <- active_state()
  if (is.null(s)) "" else (s$lang %||% "")
}

md_escape <- function(s) gsub("([\\_~`^]|\\[|\\])", "\\\\\\1", s, perl = TRUE)

# The English plural of a name, by its last letters (4.4.16).
english_plural <- function(s) {
  if (grepl("(s|x|z|ch|sh)$", s)) paste0(s, "es")
  else if (grepl("[^aeiou]y$", s)) paste0(substr(s, 1L, nchar(s) - 1L), "ies")
  else paste0(s, "s")
}

# The plural of a name a project wrote: the English rule on its last word, or, for
# a quotient ("quark per charm"), on the words before " per ".
plural_of_name <- function(nm) {
  at <- regexpr(" per ", nm, fixed = TRUE)
  if (at > 0L) paste0(english_plural(substr(nm, 1L, at - 1L)), substring(nm, at)) else english_plural(nm)
}

# ---- the shipped table (4.4.17) ---------------------------------------------

# Keyed by the id of a units-database row (its symbol, else its singular name).
# `us` is the en-US spelling; `plural` "same" is the name itself; `symbol` FALSE
# is no symbol; `space` FALSE is no space before the symbol.
SHIPPED_UNITS <- list(
  m = list(name = "metre", us = "meter"),
  L = list(name = "litre", us = "liter"),
  t = list(name = "tonne", us = "metric ton"),
  hectare = list(name = "hectare", symbol = "ha"),
  yr = list(name = "year", symbol = FALSE),
  bar = list(name = "bar", symbol = "bar"),
  ft = list(name = "foot", plural = "feet"),
  `in` = list(name = "inch"),
  mi = list(name = "mile"),
  lb = list(name = "pound"),
  `'` = list(space = FALSE),
  `"` = list(space = FALSE),
  `%` = list(name = "per cent", us = "percent", plural = "same", space = FALSE),
  Hz = list(plural = "same"),
  lx = list(plural = "same"),
  S = list(plural = "same"),
  international_knot = list(name = "knot"),
  cal = list(name = "calorie"),
  hp = list(name = "horsepower", plural = "same"),
  short_ton = list(name = "ton"),
  US_liquid_gallon = list(name = "gallon"),
  IT_Btu = list(name = "Btu"),
  mm_Hg = list(symbol = "mmHg", name = "millimetre of mercury", us = "millimeter of mercury",
               plural = "millimetres of mercury", plural_us = "millimeters of mercury")
)

SHIPPED_UNITS[["\u00b0"]] <- list(name = "degree", space = FALSE)
SHIPPED_UNITS[["\u00b0F"]] <- list(name = "degree Fahrenheit", plural = "degrees Fahrenheit")
SHIPPED_UNITS[["\u00b0C"]] <- list(name = "degree Celsius", plural = "degrees Celsius")

# Tokens the database would read another way (`ha` is hecto-are), read as symbols
# of the row with that id.
SHIPPED_TOKENS <- c(ha = "hectare", degC = "\u00b0C")

# Two rows of the database for one unit: the compatibility sign for degree Celsius.
UD_TWINS <- c("\u2103" = "\u00b0C")

# ---- the units database, indexed ----------------------------------------------

un_cache <- new.env(parent = emptyenv())

split_cells <- function(x) {
  x <- trimws(unlist(strsplit(x, ",", fixed = TRUE), use.names = FALSE))
  x[nzchar(x)]
}

ud_db <- function() {
  if (!is.null(un_cache$db)) return(un_cache$db)
  v <- NULL
  utils::capture.output(v <- suppressMessages(units::valid_udunits()))
  pf <- NULL
  utils::capture.output(pf <- suppressMessages(units::valid_udunits_prefixes()))
  n <- nrow(v)
  id <- ifelse(nzchar(v$symbol), v$symbol, v$name_singular)
  # a twin row is the unit of the row it names
  twin <- match(UD_TWINS[v$symbol], v$symbol)
  canon <- seq_len(n)
  canon[!is.na(twin)] <- twin[!is.na(twin)]
  sym <- new.env(parent = emptyenv())
  nam <- new.env(parent = emptyenv())
  put <- function(env, key, i) {
    if (nzchar(key) && !exists(key, envir = env, inherits = FALSE)) assign(key, canon[i], envir = env)
  }
  for (i in seq_len(n)) {
    for (k in c(v$symbol[i], split_cells(v$symbol_aliases[i]))) put(sym, k, i)
    sing <- c(v$name_singular[i], split_cells(v$name_singular_aliases[i]))
    for (k in c(sing, split_cells(c(v$name_plural[i], v$name_plural_aliases[i])),
                vapply(sing[nzchar(sing)], english_plural, ""))) put(nam, k, i)
  }
  psym <- list()
  pnam <- list()
  for (j in seq_len(nrow(pf))) {
    for (k in c(pf$symbol[j], split_cells(pf$symbol_aliases[j]))) psym[[k]] <- j
    pnam[[pf$name[j]]] <- j
  }
  pre_tok <- c(names(psym), names(pnam))
  pre_kind <- c(rep("symbol", length(psym)), rep("name", length(pnam)))
  pre_idx <- c(unlist(psym), unlist(pnam))
  ord <- order(-nchar(pre_tok))
  un_cache$db <- list(
    v = v, id = id[canon], canon = canon, sym = sym, nam = nam, pf = pf,
    pre_tok = pre_tok[ord], pre_kind = pre_kind[ord], pre_idx = unname(pre_idx[ord]))
  un_cache$db
}

# A token without a prefix: list(row, kind) or NULL.
ud_core <- function(tok, db) {
  if (tok %in% names(SHIPPED_TOKENS)) {
    return(list(row = match(SHIPPED_TOKENS[[tok]], db$id), kind = "symbol"))
  }
  i <- get0(tok, envir = db$sym, inherits = FALSE)
  if (!is.null(i)) return(list(row = i, kind = "symbol"))
  i <- get0(tok, envir = db$nam, inherits = FALSE)
  if (!is.null(i)) return(list(row = i, kind = "name"))
  NULL
}

# How weft reads one token (4.4.17): a token a row with `is:` defines in the configuration in
# force is a unit of its own, never split into a prefix; any other as the database reads it.
tok_resolve <- function(tok) {
  if (tok %in% ud_state$ctx$own) {
    return(list(known = FALSE, id = tok, row = NA_integer_, pre = NA_integer_, core = tok, kind = "own"))
  }
  tok_resolve_db(tok)
}

# How the units database reads one token (4.4.16 steps 2 to 5): list(known, id, row, pre, kind).
# `id` is the same for two tokens that are one unit.
tok_resolve_db <- function(tok) {
  hit <- un_cache$res[[tok]]
  if (!is.null(hit)) return(hit)
  db <- ud_db()
  out <- NULL
  core <- ud_core(tok, db)
  if (!is.null(core)) {
    out <- list(known = TRUE, id = db$id[core$row], row = core$row, pre = NA_integer_, kind = core$kind,
                core = tok)
  } else {
    for (j in seq_along(db$pre_tok)) {
      p <- db$pre_tok[j]
      if (nchar(tok) <= nchar(p) || !startsWith(tok, p)) next
      rest <- substring(tok, nchar(p) + 1L)
      c2 <- ud_core(rest, db)
      # a prefix symbol before a unit the shipped table gives that symbol (`mbar`)
      shipped_sym <- !is.null(c2) && c2$kind == "name" && identical(SHIPPED_UNITS[[db$id[c2$row]]]$symbol, rest)
      if (!is.null(c2) && (c2$kind == db$pre_kind[j] || (db$pre_kind[j] == "symbol" && shipped_sym))) {
        pj <- db$pre_idx[j]
        out <- list(known = TRUE, id = paste0(db$pf$symbol[pj], "|", db$id[c2$row]), row = c2$row,
                    pre = pj, kind = c2$kind, core = rest)
        break
      }
    }
  }
  if (is.null(out)) {
    out <- list(known = FALSE, id = paste0("?", tok), row = NA_integer_, pre = NA_integer_, core = tok,
                kind = if (grepl("^[0-9.]+$", tok)) "number" else "unknown")
  }
  un_cache$res[[tok]] <- out
  out
}

# ---- the units: table ------------------------------------------------------------

unit_factors <- function(un) {
  grp <- function(v) {
    v <- v[v != "1"]
    lapply(unique(v), function(x) list(tok = x, pow = sum(v == x)))
  }
  list(num = grp(un$numerator), den = grp(un$denominator))
}

unit_present <- function(un) {
  f <- unit_factors(un)
  length(f$num) > 0L || length(f$den) > 0L
}

# Whether every factor of a unit cancels (`m/m`): it holds no unit.
unit_cancels <- function(un) {
  f <- unit_factors(un)
  pow <- function(l, t) sum(vapply(l, function(g) if (g$tok == t) g$pow else 0L, 1L))
  all(vapply(unique(c(vapply(f$num, function(g) g$tok, ""), vapply(f$den, function(g) g$tok, ""))),
             function(t) pow(f$num, t) == pow(f$den, t), NA))
}

# One id for a whole unit: two units are the same when this is.
unit_whole_id <- function(un) {
  ids <- function(v) sort(vapply(v[v != "1"], function(t) tok_resolve(t)$id, ""))
  paste0(paste(ids(un$numerator), collapse = "*"), "/", paste(ids(un$denominator), collapse = "*"))
}

unit_key_parse <- function(key) unit_symbolic(key)

# The entry of the `units:` table for the unit with this id, or an empty list.
unit_proj <- function(cfg, id) unit_entry(cfg, id)

# The unit as a key would write it, for a message.
unit_key_text <- function(un) {
  f <- unit_factors(un)
  one <- function(g) if (g$pow > 1L) paste0(g$tok, "^", g$pow) else g$tok
  num <- paste(vapply(f$num, one, ""), collapse = "*")
  den <- vapply(f$den, one, "")
  if (!length(den)) return(num)
  # a number goes before its unit with a space, as it is written: `CFU/100 mL`
  den_txt <- if (any(grepl("^[0-9.]+$", vapply(f$den, function(g) g$tok, "")))) paste(den, collapse = " ")
             else if (length(den) > 1L) paste0("(", paste(den, collapse = "*"), ")") else den
  paste0(if (nzchar(num)) num else "1", "/", den_txt)
}

yaml_key <- function(k) if (grepl("[^A-Za-z0-9_]", k)) paste0("\"", k, "\"") else k

# ---- names -------------------------------------------------------------------------

# One plain word: letters only. A database name with an underscore or a space is
# technical ("international_knot") and is never printed (4.4.17).
plain_word <- function(x) length(x) == 1L && !is.na(x) && grepl("^[[:alpha:]]+$", x)

# The name the author typed for a row of the database, singular and plural, or
# NULL when what they typed is not a plain name of the unit (4.4.17 step 3).
typed_name <- function(core, row, db) {
  # what the author wrote, an underscore for a space ("light_year"): words only
  words <- function(x) gsub("_", " ", x, fixed = TRUE)
  ok <- function(x) length(x) == 1L && grepl("^[[:alpha:]]+(_[[:alpha:]]+)*$", x)
  if (!ok(core)) return(NULL)
  v <- db$v
  sing <- split_cells(c(v$name_singular[row], v$name_singular_aliases[row]))
  plur <- split_cells(c(v$name_plural[row], v$name_plural_aliases[row]))
  if (core %in% sing) {
    pl <- plur[vapply(plur, function(p) ok(p) && startsWith(p, core), NA)]
    return(list(sg = words(core), pl = if (length(pl)) words(pl[1L]) else english_plural(words(core))))
  }
  sg <- sing[vapply(sing, function(x) ok(x) && english_plural(x) == core, NA)]
  if (!length(sg)) sg <- sing[vapply(sing, ok, NA)]
  if (!length(sg)) return(NULL)
  list(sg = words(sg[1L]), pl = words(core))
}

# The name of one token, singular and plural, or NULL when it has none (4.4.16,
# 4.4.17): the project's entry, the shipped table, what the author typed when it
# is a name of the unit, the database's name when it is one plain word.
tok_name <- function(tok, cfg, us) {
  r <- tok_resolve(tok)
  E <- unit_proj(cfg, paste0(r$id, "/"))
  nm <- E$name
  pl <- E$plural
  given <- !is.null(pl)
  if (is.null(nm) && r$known && !is.na(r$row)) {
    db <- ud_db()
    S <- SHIPPED_UNITS[[db$id[r$row]]] %||% list()
    sg <- NULL
    dpl <- NULL
    if (!is.null(S$name)) {
      sg <- if (us && !is.null(S$us)) S$us else S$name
    } else {
      tn <- if (identical(r$kind, "name")) typed_name(r$core, r$row, db)
      if (!is.null(tn)) {
        sg <- tn$sg
        dpl <- tn$pl
      } else if (plain_word(db$v$name_singular[r$row])) {
        sg <- db$v$name_singular[r$row]
        if (plain_word(db$v$name_plural[r$row])) dpl <- db$v$name_plural[r$row]
      }
    }
    if (is.null(sg)) return(NULL)
    if (is.null(pl)) {
      pl <- if (identical(S$plural, "same")) sg
            else if (us && !is.null(S$plural_us)) S$plural_us
            else if (!is.null(S$plural)) S$plural
            else dpl %||% english_plural(sg)
    }
    if (!is.na(r$pre)) {
      p <- db$pf$name[r$pre]
      if (!us && p == "deka") p <- "deca"
      sg <- paste0(p, sg)
      if (!given) pl <- paste0(p, pl)
    }
    nm <- sg
  }
  if (is.null(nm)) return(NULL)
  list(sg = nm, pl = pl %||% plural_of_name(nm))
}

no_name_error <- function(un, why, key, shown = as.character(un)) {
  value_error(sprintf(paste0(
    "The unit `%s` has no name to print: %s. Add its name to _weft.yml under `units:`, for example\n\n",
    "  units:\n    %s:\n      name: <the unit's name, in the singular>\n\n",
    "or print the symbol with `.usym`, or the number alone with `.nounit` (rules 4.4.15, 4.4.19)."),
    shown, why, yaml_key(key)))
}

is_length_unit <- function(tok) {
  tryCatch(isTRUE(units::ud_are_convertible(tok, "m")), error = function(e) FALSE)
}

# The name of a unit (4.4.18): the `units:` entry for the whole unit, else its
# factors'. A value error when it has none.
unit_name_text <- function(un, plural, cfg, lang) {
  us <- lang_is_us(lang)
  W <- unit_proj(cfg, unit_whole_id(un))
  if (!is.null(W$name)) return(if (plural) (W$plural %||% plural_of_name(W$name)) else W$name)
  f <- unit_factors(un)
  whole <- unit_key_text(un)
  part <- function(g, pl) {
    if (identical(tok_resolve(g$tok)$kind, "number")) {
      no_name_error(un, sprintf("it holds a number (`%s`)", g$tok), whole)
    }
    tn <- tok_name(g$tok, cfg, us)
    if (is.null(tn)) {
      no_name_error(un, sprintf("`%s` is not a unit weft knows a name for", g$tok), g$tok)
    }
    base <- if (pl) tn$pl else tn$sg
    if (g$pow == 1L) return(base)
    if (!g$pow %in% 2:3) {
      no_name_error(un, sprintf("a power of %d has no name (only 1, 2 and 3 do)", g$pow), whole)
    }
    if (is_length_unit(g$tok)) paste(c("square", "cubic")[g$pow - 1L], base)
    else paste(base, c("squared", "cubed")[g$pow - 1L])
  }
  if (!length(un$numerator) && length(f$den)) {
    neg <- paste(vapply(f$den, function(g) paste0(g$tok, "^-", g$pow), ""), collapse = "*")
    no_name_error(un, sprintf(paste0("it is written with a negative power, which has no name (write it as a ",
                                     "quotient, `%s`, for example `u(3, \"%s\")`)"), whole, whole),
                  whole, shown = neg)
  }
  # a number among the factors: the whole unit needs an entry, keyed as written
  nums <- c(f$num, f$den)
  nums <- nums[vapply(nums, function(g) identical(tok_resolve(g$tok)$kind, "number"), NA)]
  if (length(nums)) no_name_error(un, sprintf("it holds a number (`%s`)", nums[[1L]]$tok), whole, shown = whole)
  nn <- length(f$num)
  num <- vapply(seq_len(nn), function(i) part(f$num[[i]], plural && i == nn), "")
  den <- vapply(f$den, part, "", pl = FALSE)
  txt <- paste(num, collapse = " ")
  if (length(den)) txt <- paste0(if (nzchar(txt)) paste0(txt, " per ") else "per ", paste(den, collapse = " "))
  if (plural && !is.null(W$plural)) txt <- W$plural
  txt
}

# ---- symbols -------------------------------------------------------------------------

symbol_needs_name <- function(un, lang) {
  if (!lang_is_english(lang)) {
    value_error(sprintf(paste0(
      "The unit `%s` has no symbol, so it prints its name, and the document's `lang` is `%s`: ",
      "a name is English words. Give it a symbol with `symbol:` in `units:` in _weft.yml (rule 1.6.8)."),
      as.character(un), lang))
  }
}

# The symbol of one token: list(text, raw) or list(name = TRUE).
tok_symbol <- function(tok, cfg) {
  r <- tok_resolve(tok)
  E <- unit_proj(cfg, paste0(r$id, "/"))
  if (is.character(E$symbol)) return(list(text = E$symbol, raw = TRUE))
  if (identical(E$symbol, FALSE)) return(list(name = TRUE))
  if (!r$known) return(list(text = tok))
  db <- ud_db()
  S <- SHIPPED_UNITS[[db$id[r$row]]] %||% list()
  # a unit with no symbol prints its name, but a prefix makes the abbreviation one (`Myr`)
  if (identical(S$symbol, FALSE) && is.na(r$pre)) return(list(name = TRUE))
  if (r$kind == "symbol") return(list(text = tok))
  sym <- S$symbol %||% db$v$symbol[r$row]
  if (!nzchar(sym)) return(list(name = TRUE))
  list(text = paste0(if (!is.na(r$pre)) db$pf$symbol[r$pre] else "", sym))
}

# The text of a unit's symbol as Pandoc markdown (4.4.8): an exponent is a
# superscript, a product the middle dot, a unit with no numerator is written
# with negative powers. A factor with no symbol prints its name, in the plural
# when it ends the numerator and `plural` is TRUE. NULL when no unit is left.
unit_symbol_text <- function(un, plural, cfg, lang) {
  if (!unit_present(un)) return(NULL)
  W <- unit_proj(cfg, unit_whole_id(un))
  if (is.character(W$symbol)) return(W$symbol)
  if (identical(W$symbol, FALSE)) {
    symbol_needs_name(un, lang)
    return(unit_name_text(un, plural, cfg, lang))
  }
  f <- unit_factors(un)
  toks <- unique(c(un$numerator, un$denominator))
  # a number stays as it is: the units package joins it to the next factor with no sign
  toks <- toks[toks != "1" & !grepl("^[0-9]", toks)]
  ph <- stats::setNames(vapply(seq_along(toks), function(i) intToUtf8(0xE100L + i), ""), toks)
  last_num <- if (length(f$num)) f$num[[length(f$num)]]$tok else NA_character_
  un2 <- un
  swap <- function(v) as.character(ifelse(v %in% names(ph), ph[v], v))
  un2$numerator <- swap(un$numerator)
  un2$denominator <- swap(un$denominator)
  s <- as.character(un2, neg_power = !length(un$numerator))
  s <- md_escape(s)
  s <- gsub("\\\\\\^(-?)([0-9]+)", "^\\1\\2^", s, perl = TRUE)
  s <- gsub("\\^-", "^\u2212", s, perl = TRUE)
  s <- gsub("*", "\u00b7", s, fixed = TRUE)
  us <- lang_is_us(lang)
  for (tok in toks) {
    sy <- tok_symbol(tok, cfg)
    txt <- if (isTRUE(sy$name)) {
      symbol_needs_name(un, lang)
      tn <- tok_name(tok, cfg, us)
      if (is.null(tn)) {
        no_name_error(un, sprintf("`%s` has no symbol and no name", tok), tok)
      }
      if (plural && identical(tok, last_num)) tn$pl else tn$sg
    } else if (isTRUE(sy$raw)) sy$text else md_escape(sy$text)
    s <- gsub(ph[[tok]], txt, s, fixed = TRUE)
  }
  s
}

# Whether a unit prints its name in the symbol form because it has no symbol (9.1.7).
unit_prints_name <- function(un, cfg) {
  W <- unit_proj(cfg, unit_whole_id(un))
  if (identical(W$symbol, FALSE)) return(TRUE)
  if (is.character(W$symbol)) return(FALSE)
  toks <- unique(c(un$numerator, un$denominator))
  toks <- toks[toks != "1" & !grepl("^[0-9]", toks)]
  length(toks) > 0L && all(vapply(toks, function(t) isTRUE(tok_symbol(t, cfg)$name), NA))
}

# Whether a unit is printed before its number (4.4.22): the token alone, power 1, whose row says
# `before: true`.
unit_before <- function(un, cfg) {
  f <- unit_factors(un)
  length(f$num) == 1L && !length(f$den) && f$num[[1L]]$pow == 1L &&
    isTRUE(unit_proj(cfg, unit_whole_id(un))$before)
}

# Whether a no-break space goes before the unit's symbol (4.4.8, U13). `space:`
# governs a symbol only: a name always has its space (ruling 11).
unit_space <- function(un, cfg) {
  if (unit_prints_name(un, cfg)) return(TRUE)
  W <- unit_proj(cfg, unit_whole_id(un))
  if (!is.null(W$space)) return(W$space)
  f <- unit_factors(un)
  if (length(f$num) == 1L && !length(f$den) && f$num[[1L]]$pow == 1L) {
    r <- tok_resolve(f$num[[1L]]$tok)
    if (r$known && is.na(r$pre) && identical(SHIPPED_UNITS[[ud_db()$id[r$row]]]$space, FALSE)) return(FALSE)
  }
  TRUE
}

# ---- the form of a unit in the text ----------------------------------------------------

UNIT_CLASSES <- c(".uname", ".usym", ".nounit")
UNIT_FORMS <- c("auto", "name", "symbol", "none")

unit_class_form <- function(classes) {
  unname(c(.uname = "name", .usym = "symbol", .nounit = "none")[intersect(classes, UNIT_CLASSES)][1L])
}

# A `unit_form` argument: NULL, or one of auto, name, symbol (and none where it
# is allowed). A construct error otherwise (3.4.8).
check_unit_form <- function(unit_form, fn = NULL, no_symbol = FALSE, none = TRUE) {
  if (is.null(unit_form)) return(invisible(NULL))
  allowed <- if (none) UNIT_FORMS else setdiff(UNIT_FORMS, "none")
  if (!is.character(unit_form) || length(unit_form) != 1L || is.na(unit_form) || !unit_form %in% allowed) {
    construct_error(sprintf("%s`unit_form` must be one of %s; got %s.",
                            if (!is.null(fn)) paste0(fn, "(): ") else "",
                            paste0("\"", allowed, "\"", collapse = ", "),
                            if (is.character(unit_form) && length(unit_form) == 1L) paste0("\"", unit_form, "\"") else "something else"))
  }
  if (no_symbol && unit_form == "symbol") {
    construct_error(sprintf(paste0("%s(): `unit_form = \"symbol\"` cannot go with a class that prints a number as a ",
                                   "word: a spelled number takes the unit's name (rule 4.4.15)."), fn))
  }
  invisible(unit_form)
}

# ---- fmt_unit() ----------------------------------------------------------------------------

#' Print a unit alone
#'
#' `fmt_unit()` prints the unit of a quantity, or of a string read as [u()]
#' reads a unit, with no number: for a heading or a table column. It is a
#' `weft_text` of length one with no printed record and no unit attributes, so
#' [fmt_cap()] works on it.
#'
#' `"auto"` and `"symbol"` print the symbol text ("mg/L"; a unit with no symbol
#' prints its name); `"name"` prints the name ("milligrams per litre"). The name
#' is plural unless `x` has length one and its number prints "1" (a string takes
#' the plural). A unit with no name is a `weft_value_error`; add one under
#' `units:` in `_weft.yml`. A name there that is written with markdown needs its
#' own `plural:`, as the English plural is added to the end of the markup
#' (`*site*` would print `*site*s`). `.cap` leaves a symbol as it is, since its
#' case is its meaning, and capitalises a name. `unit` converts `x` first, a
#' string as well as a quantity; the unit of a formatter's text is not read, so
#' pass the quantity.
#'
#' @param x A quantity of any length (a missing value is allowed: no number
#'   prints), or one string naming a unit.
#' @param unit_form `NULL` (the setting `unit_form`, else `"auto"`), `"auto"`,
#'   `"symbol"` or `"name"`. `"none"` is a `weft_construct_error`.
#' @param unit A unit to convert `x` to first, as a string.
#' @return A `weft_text` of length one.
#' @examples
#' fmt_unit(u(5, mg/L))
#' fmt_unit(u(5, mg/L), unit_form = "name")
#' @export
fmt_unit <- function(x, unit_form = NULL, unit = NULL) {
  check_unit_form(unit_form, "fmt_unit", none = FALSE)
  cfg <- current_config()
  lang <- current_lang()
  plural <- TRUE
  if (inherits(x, "weft_text") && !is.null(attr(x, "units"))) {
    value_error(paste0("fmt_unit() needs the quantity, not the text a formatter made of it: pass the ",
                       "quantity itself (see u()), or a string that names a unit (rule 3.4.9)."))
  }
  if (is.character(x)) {
    if (length(x) != 1L || is.na(x)) {
      value_error("fmt_unit() takes one string that names a unit, or a quantity.")
    }
    if (!nzchar(trimws(x))) unit_abort("fmt_unit(): the unit is blank; write fmt_unit(\"m\").")
    x <- u_make(1, x)
    if (!is.null(unit)) x <- convert_unit(x, unit)
  } else if (!inherits(x, "units")) {
    value_error(sprintf("fmt_unit() needs a quantity (see u()) or a string that names a unit; the value is of class %s.",
                        class(x)[1L]))
  } else {
    if (!is.null(unit)) x <- convert_unit(x, unit)
    if (length(x) == 1L && is.finite(as.numeric(x))) {
      p <- print_one(as.numeric(x), NULL, NULL, cfg)
      plural <- !(p$number == 1 && !p$decimals)
    }
  }
  un <- attr(x, "units")
  if (!unit_present(un)) value_error("fmt_unit() needs a quantity with a unit; this one has no unit left (rule 3.4.9).")
  form <- unit_form %||% cfg$unit_form %||% "auto"
  if (form == "name") {
    if (!lang_is_english(lang)) {
      construct_error(sprintf("`unit_form = \"name\"` prints English words, and the document's `lang` is `%s` (rule 1.6.8).", lang))
    }
    txt <- unit_name_text(un, plural, cfg, lang)
  } else {
    txt <- unit_symbol_text(un, plural, cfg, lang)
  }
  out <- structure(txt, class = c("weft_text", "character"))
  # a symbol's case is its meaning: `.cap` leaves it alone (4.4.16)
  if (form != "name" && !unit_prints_name(un, cfg)) attr(out, "is_symbol") <- TRUE
  out
}
