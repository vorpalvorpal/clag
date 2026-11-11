# Configuration (rules 9.1, 1.4.8, 9.4.1): defaults, `_weft.yml`, the
# front-matter `weft:` key, the project root, formatter registration.

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- errors -------------------------------------------------------------

weft_abort <- function(message, class, ...) {
  rlang::abort(message, class = c(class, "weft_error"), call = NULL, ...)
}

# ---- state --------------------------------------------------------------

# Per-session state. `config` is set by the knit initialiser of a later
# package; outside a knit the defaults apply.
weft_env <- new.env(parent = emptyenv())

# Outside a knit the defaults apply, and the `units:` table of the last
# configuration read (rule 9.1.7).
current_config <- function() {
  weft_env$config %||% {
    cfg <- default_config()
    cfg$units <- weft_env$units %||% list()
    cfg
  }
}

# ---- defaults -----------------------------------------------------------

default_config <- function() {
  list(
    digits = 1,
    decimal_mark = ".",
    big_mark = ",",
    thousands_from = 1000,
    serial_comma = FALSE,
    minus = "\u2212",
    governor_class = ".num",
    pct_proportion = TRUE,
    count_threshold = 10,
    word_limit = 100,
    draft = FALSE,
    date_format = "%-d %B %Y",
    ci_level = 0.95,
    about_tolerance = 0.05,
    sentence_start_fail = FALSE,
    bibliography = character(),
    formatters = list(),
    severity = character(),
    unit_form = "auto",
    units = list()
  )
}

formatter_stages <- function() c("number", "wording", "collapse", "text")

# ---- reading ------------------------------------------------------------

# `dir` is the project root. `front` is the document's `weft:` front-matter
# key, already parsed to a list. `doc` names the document, for a problem in its
# `units:` table.
read_config <- function(dir, front = list(), doc = NULL) {
  front <- front %||% list()
  if (!is.list(front) || (length(front) && (is.null(names(front)) ||
                                            any(!nzchar(names(front)))))) {
    weft_abort("The `weft:` front-matter key must be a mapping of settings.",
               "weft_config_error")
  }
  # `dict_local` is read from the front matter by read_dict_local() (4.3, 9.1.2)
  front$dict_local <- NULL
  warn_unknown(front, "a document's `weft:` front matter")
  file <- file.path(dir, "_weft.yml")
  has_file <- file.exists(file)
  proj <- list()
  if (has_file) {
    proj <- tryCatch(
      yaml::read_yaml(file),
      error = function(e) {
        weft_abort(paste0("Cannot read ", file, ": ", conditionMessage(e)),
                   "weft_config_error")
      }
    ) %||% list()
    if (!is.list(proj) || (length(proj) && is.null(names(proj)))) {
      weft_abort(paste0(file, " must be a mapping of settings."),
                 "weft_config_error")
    }
  }
  if (has_file && "dict_local" %in% names(proj)) {
    weft_abort(paste0(
      "`dict_local` is written in a document's front matter, not in _weft.yml ",
      "(rules 4.3.4, 9.1.2)."), "weft_config_error")
  }
  if (has_file) warn_unknown(proj, "_weft.yml")
  if (has_file && "draft" %in% names(front)) {
    weft_abort(paste0(
      "`draft` is a project setting: set it in _weft.yml, not in a ",
      "document's `weft:` front matter (rule 9.1.4)."
    ), "weft_config_error")
  }
  # the `units:` tables are checked and merged apart (9.1.7)
  proj_units <- proj$units
  front_units <- front$units
  proj$units <- NULL
  front$units <- NULL
  cfg <- merge_config(default_config(), proj)
  cfg <- merge_config(cfg, front)
  cfg$formatters <- check_formatters(cfg$formatters)
  cfg <- validate_config(cfg)
  if ("unit_form" %in% names(front)) {
    cfg$unit_form_set <- "the document's `weft:` front matter"
  } else if ("unit_form" %in% names(proj)) {
    cfg$unit_form_set <- "_weft.yml"
  }
  cfg$units <- read_units_tables(list(
    list(tbl = proj_units, where = if (has_file) file else "_weft.yml"),
    list(tbl = front_units, where = doc %||% "the document's `weft:` front matter")))
  weft_env$units <- cfg$units
  if (tolower(Sys.getenv("WEFT_DRAFT")) %in% c("1", "true")) cfg$draft <- TRUE
  cfg
}

# An unknown setting is kept, with a warning that names it (a misspelt
# setting would otherwise do nothing).
warn_unknown <- function(over, where) {
  unk <- setdiff(names(over), names(default_config()))
  for (k in unk) {
    rlang::warn(sprintf("Unknown weft setting `%s` in %s; it is ignored.", k, where),
                class = "weft_config_warning")
  }
  invisible()
}

# Setting by setting: a later setting replaces an earlier one, except that
# project formatters are merged by class name and the severity lists add up.
merge_config <- function(base, over) {
  for (nm in names(over)) {
    v <- over[[nm]]
    if (nm == "formatters") {
      if (!is.null(v) && (!is.list(v) ||
                          (length(v) && (is.null(names(v)) || any(!nzchar(names(v))))))) {
        weft_abort(paste0("`formatters` must be a mapping from class name to ",
                          "a function (rule 1.4.8)."), "weft_config_error")
      }
      base$formatters <- utils::modifyList(base$formatters %||% list(),
                                           as.list(v %||% list()))
    } else if (nm == "severity") {
      base$severity <- unique(c(base$severity, as.character(unlist(v))))
    } else if (is.null(v)) {
      next
    } else {
      base[[nm]] <- v
    }
  }
  base
}

validate_config <- function(cfg) {
  bad <- function(nm, what) {
    weft_abort(sprintf("The setting `%s` must be %s.", nm, what),
               "weft_config_error")
  }
  str <- function(nm) {
    v <- cfg[[nm]]
    if (!is.character(v) || length(v) != 1L || is.na(v)) bad(nm, "a single string")
  }
  lgl <- function(nm) {
    v <- cfg[[nm]]
    if (!is.logical(v) || length(v) != 1L || is.na(v)) bad(nm, "TRUE or FALSE")
  }
  whole <- function(nm) {
    v <- cfg[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 0 ||
        v != round(v)) {
      bad(nm, "a whole number, not negative")
    }
  }
  whole("digits"); whole("count_threshold"); whole("word_limit")
  whole("thousands_from")
  str("decimal_mark"); str("big_mark"); str("minus"); str("governor_class")
  lgl("pct_proportion"); lgl("draft"); lgl("sentence_start_fail"); lgl("serial_comma")
  str("date_format")
  uf <- cfg$unit_form
  if (!is.character(uf) || length(uf) != 1L || is.na(uf) || !uf %in% c("auto", "symbol", "name")) {
    weft_abort(sprintf(paste0("The setting `unit_form` must be one of auto, symbol or name; got %s ",
                              "(rule 9.1.6)."),
                       if (is.character(uf) && length(uf) == 1L && !is.na(uf)) paste0("`", uf, "`") else "something else"),
               "weft_config_error")
  }
  prop <- function(nm, open = TRUE) {
    v <- cfg[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 0 ||
        (open && v >= 1) || v > 1) bad(nm, "a proportion between 0 and 1")
  }
  prop("ci_level"); prop("about_tolerance", open = FALSE)
  cfg$bibliography <- as.character(unlist(cfg$bibliography))
  if (nzchar(cfg$decimal_mark) && identical(cfg$decimal_mark, cfg$big_mark)) {
    weft_abort("`decimal_mark` and `big_mark` must differ.", "weft_config_error")
  }
  reg <- cfg$formatters %||% list()
  proj_ok <- names(reg)[vapply(reg, function(r) (r[["stage"]] %||% "number") %in%
                                 c("number", "wording"), NA)]
  ok <- c(NUMBER_CLASSES, ".no", WORDING_CLASSES, proj_ok)
  if (!cfg$governor_class %in% ok) {
    bad("governor_class", paste0("a number- or wording-stage class (one of ",
                                 paste(ok, collapse = ", "), ")"))
  }
  invisible(cfg)
}

# ---- formatter registration (1.4.8) -------------------------------------

# Returns the registrations with the stage filled in; stops on a name that
# shadows a shipped class, an unknown stage, or a missing function.
check_formatters <- function(fm) {
  fm <- fm %||% list()
  if (!length(fm)) return(list())
  if (!is.list(fm) || is.null(names(fm)) || any(!nzchar(names(fm)))) {
    weft_abort("`formatters` must be a mapping from class name to a function.",
               "weft_config_error")
  }
  for (nm in names(fm)) {
    if (!grepl("^\\.[A-Za-z][A-Za-z0-9_-]*$", nm)) {
      weft_abort(sprintf(
        "The formatter name `%s` must be a class name with a leading dot.", nm),
        "weft_config_error")
    }
    if (nm %in% shipped_classes()) {
      weft_abort(sprintf(
        "The project formatter `%s` shadows the shipped class `%s` (rule 1.4.8); choose another name.",
        nm, nm), "weft_config_error")
    }
    spec <- fm[[nm]]
    fun <- if (is.list(spec)) spec[["function"]] else NULL
    if (!is.character(fun) || length(fun) != 1L || is.na(fun) || !nzchar(fun)) {
      weft_abort(sprintf("The formatter `%s` needs a `function:` (as pkg::fun).", nm),
                 "weft_config_error")
    }
    stage <- spec[["stage"]] %||% "number"
    if (!is.character(stage) || length(stage) != 1L ||
        !stage %in% formatter_stages()) {
      weft_abort(sprintf(
        "The formatter `%s` has the unknown stage `%s`; the stages are %s.",
        nm, paste(format(stage), collapse = " "),
        paste(formatter_stages(), collapse = ", ")), "weft_config_error")
    }
    fm[[nm]][["stage"]] <- stage
  }
  fm
}

# The function behind a registered formatter, from "pkg::fun" or a bare name.
resolve_formatter <- function(spec) {
  f <- spec[["function"]]
  fn <- tryCatch({
    if (grepl("::", f, fixed = TRUE)) {
      parts <- strsplit(f, ":::?")[[1]]
      get(parts[2], envir = asNamespace(parts[1]), mode = "function")
    } else {
      get(f, envir = globalenv(), mode = "function")
    }
  }, error = function(e) NULL)
  if (is.null(fn)) {
    weft_abort(sprintf("Cannot find the formatter function `%s`.", f),
               "weft_config_error")
  }
  fn
}

# ---- the project root ---------------------------------------------------

# The nearest directory, from the input file upward, that holds `_weft.yml`;
# failing that one that holds `_quarto.yml`; failing that the file's own
# directory.
find_project_root <- function(path) {
  path <- normalizePath(path, mustWork = FALSE)
  start <- if (dir.exists(path)) path else dirname(path)
  walk <- function(marker) {
    d <- start
    repeat {
      if (file.exists(file.path(d, marker))) return(d)
      up <- dirname(d)
      if (identical(up, d)) return(NA_character_)
      d <- up
    }
  }
  for (marker in c("_weft.yml", "_quarto.yml")) {
    r <- walk(marker)
    if (!is.na(r)) return(r)
  }
  start
}

# A project "has been set up" (9.3.2) when its root holds `_weft.yml`.
is_set_up <- function(root) file.exists(file.path(root, "_weft.yml"))

# ---- the `units:` table (9.1.7) ---------------------------------------------

UNITS_FIELDS <- c("name", "plural", "symbol", "space")

# One `units:` table: list(problems, entries, installed). Each key's tokens the
# units database does not know are registered, as a dictionary's unit is (4.4.7).
check_units_table <- function(tbl, where) {
  problems <- character()
  prob <- function(key, what) {
    problems <<- c(problems, if (is.null(key)) sprintf("%s: units: %s (rule 9.1.7)", where, what)
                   else sprintf("%s: units: `%s`: %s (rule 9.1.7)", where, key, what))
  }
  out <- list(problems = character(), entries = list(), installed = character())
  if (is.null(tbl)) return(out)
  if (!is.list(tbl) || (length(tbl) && (is.null(names(tbl)) || any(!nzchar(names(tbl)))))) {
    prob(NULL, paste0("must be a mapping from a unit to its `name`, `plural`, `symbol` and `space`, ",
                      "as `units:` in _weft.yml is written"))
    out$problems <- problems
    return(out)
  }
  str1 <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
  keys <- names(tbl)
  entries <- list()
  for (i in seq_along(tbl)) {
    key <- keys[i]
    e <- tbl[[i]]
    n0 <- length(problems)
    un <- NULL
    reg <- dict_register_unit(key)
    out$installed <- c(out$installed, reg$installed)
    if (!is.null(reg$error)) {
      prob(key, sprintf("is not a unit the units package can read: %s", reg$error))
    } else {
      un <- tryCatch(unit_key_parse(key), error = function(e) NULL)
      if (is.null(un)) prob(key, "is not a unit the units package can read")
    }
    if (is.null(e) || (is.list(e) && !length(e))) {
      prob(key, "is empty; give it a `name`, `plural`, `symbol` or `space`")
    } else if (!is.list(e) || is.null(names(e)) || any(!nzchar(names(e)))) {
      prob(key, "must be a mapping with the fields name, plural, symbol and space")
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
    }
    if (!is.null(un) && length(problems) == n0) {
      ent <- c(list(key = key, id = unit_whole_id(un)),
               e[intersect(names(e), UNITS_FIELDS)])
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
      un <- unit_key_parse(ent$key)
      named <- tryCatch({ unit_name_text(un, TRUE, tmp, ""); TRUE }, error = function(e) FALSE)
      if (!named) prob(ent$key, "`symbol: false` prints the unit's name, and it has none; give it a `name`")
    }
  }
  out$problems <- problems
  out$entries <- stats::setNames(entries, vapply(entries, function(x) x$key, ""))
  out
}

# The checked, merged `units:` table of the project and the document (the
# document's entry for a unit replaces the project's whole), or one
# weft_config_error that holds every problem; a read with a problem registers
# nothing (9.1.7).
read_units_tables <- function(tabs) {
  installed <- character()
  blocks <- character()
  parts <- list()
  for (t in tabs) {
    r <- check_units_table(t$tbl, t$where)
    installed <- c(installed, r$installed)
    if (length(r$problems)) {
      blocks <- c(blocks, sprintf("weft: %s: %d problem(s) in `units:`\n%s", t$where, length(r$problems),
                                  paste0("  ", r$problems, collapse = "\n")))
    }
    parts[[length(parts) + 1L]] <- r$entries
  }
  if (length(blocks)) {
    for (tok in unique(installed)) try(units::remove_unit(tok, tok), silent = TRUE)
    weft_abort(paste(blocks, collapse = "\n"), "weft_config_error")
  }
  proj <- parts[[1L]]
  doc <- parts[[2L]]
  keep <- !vapply(proj, function(x) any(vapply(doc, function(d) identical(d$id, x$id), NA)), NA)
  c(proj[keep], doc)
}
