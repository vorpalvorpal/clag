# Configuration (rules 9.1, 1.4.8, 9.4.1): defaults, `_weft.yml`, the
# front-matter `weft:` key, the project root, formatter registration.

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- errors -------------------------------------------------------------

weft_abort <- function(message, class, ...) {
  rlang::abort(message, class = c(class, "weft_error"), call = NULL, ...)
}

# The one way to warn: the specific class, then `weft_warning`, so a caller can catch every weft
# warning by one class (as `weft_error` does for errors).
weft_warn <- function(msg, class, ...) {
  rlang::warn(msg, class = unique(c(class, "weft_warning")), ...)
}

# ---- state --------------------------------------------------------------

# Per-session state. `config` is set by the knit initialiser of a later
# package; outside a knit the defaults apply.
weft_env <- new.env(parent = emptyenv())

# Outside a knit the defaults apply, and the `units:` table of the last
# configuration read (rule 9.1.7).
current_config <- function() {
  units_ready()
  weft_env$config %||% {
    cfg <- default_config()
    cfg$units <- weft_env$units %||% list()
    cfg$units_default <- weft_env$units_default %||% ud_state$default_entries %||% list()
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
    bare_missing = TRUE,
    minus = "\u2212",
    governor_class = ".num",
    pct_proportion = TRUE,
    count_threshold = 10,
    word_limit = 100,
    draft = FALSE,
    ledger = TRUE,
    date_format = "%-d %B %Y",
    ci_level = 0.95,
    ci_short = FALSE,
    p_digits = NULL,
    p_label = "p",
    output_refs = "fail",
    output_missing = "warn",
    output_markup = "fail",
    chunk_claims = "stop",
    about_tolerance = 0.05,
    sentence_start_fail = FALSE,
    bibliography = character(),
    formatters = list(),
    severity = character(),
    unit_form = "auto",
    unit_defaults = "weft",
    decisions = "github",
    units = list(),
    label_words = list(),
    numeral_years = FALSE,
    claim_words = list(add = list(), drop = list(), idioms = list()),
    claim_quantifiers = "number",
    claim_cap = 20,
    guard_words = 25,
    expected_names = list(),
    anchor_calls = list(),
    strict = character(),
    verify_skip = character(),
    weft_version = NULL
  )
}

formatter_stages <- function() c("number", "wording", "collapse", "text")

# ---- reading ------------------------------------------------------------

# `dir` is the project root. `front` is the document's `weft:` front-matter
# key, already parsed to a list. `doc` names the document, for a problem in its
# `units:` table.
read_config <- function(dir, front = list(), doc = NULL) {
  # a read that fails leaves the session at the default units (4.4.21)
  ok <- FALSE
  on.exit(if (!ok) units_reset(), add = TRUE)
  cfg <- read_config_(dir, front, doc)
  ok <- TRUE
  cfg
}

# `_weft.yml` read once: its settings as the one YAML reader gives them, and
# `raw`, the same text with a one-item list kept a list (so `ledger: [true]` can
# be told from `ledger: true`). A file that cannot be read or is not a mapping is
# a `weft_config_error` naming it; one that is not UTF-8 is a `weft_encoding_error`.
read_weft_yml <- function(file) {
  fail <- function(e) {
    if (inherits(e, "weft_encoding_error")) stop(e)
    weft_abort(paste0("Cannot read ", file, ": ", conditionMessage(e)), "weft_config_error")
  }
  text <- tryCatch(read_source_text(file, "weft_config_error"), error = fail)
  proj <- tryCatch(yaml_read_text(text), error = fail) %||% list()
  if (!is.list(proj) || (length(proj) && is.null(names(proj)))) {
    weft_abort(paste0(file, " must be a mapping of settings."), "weft_config_error")
  }
  raw <- tryCatch(yaml_read_text(text, handlers = list(seq = function(x) x)), error = function(e) NULL)
  list(proj = proj, raw = raw)
}

# Bring the `units:` table and `unit_defaults` of the project at `root` into force, as a read of its
# configuration does, but reading only those two settings, so an unrelated bad setting does not stop a
# dictionary read. A no-op when it has no _weft.yml, or when that project's table is already in force (in a knit it is).
project_units <- function(root) {
  root <- ud_norm_root(root)
  if (isTRUE(ud_state$ready) && identical(ud_state$root, root)) return(invisible())
  file <- file.path(root, "_weft.yml")
  # no configuration file: nothing to bring into force, and the session's table stays
  if (!file.exists(file)) return(invisible())
  has_file <- TRUE
  # a file that cannot be read is the business of read_config(), which names it; here it is left alone
  proj <- tryCatch(read_weft_yml(file)$proj, weft_config_error = function(e) NULL,
                   weft_encoding_error = function(e) NULL)
  if (is.null(proj)) return(invisible())
  mode <- proj$unit_defaults %||% default_config()$unit_defaults
  if (!(is.character(mode) && length(mode) == 1L && mode %in% c("weft", "si"))) {
    weft_abort(sprintf("`unit_defaults` must be `weft` or `si`; got `%s` (rule 9.1.6).",
                       paste(format(unlist(mode)), collapse = ", ")), "weft_config_error")
  }
  ok <- FALSE
  on.exit(if (!ok) units_reset(), add = TRUE)
  ur <- read_units_tables(list(list(tbl = proj$units, where = if (has_file) file else "_weft.yml"),
                               list(tbl = NULL, where = "")), mode, root = root)
  weft_env$units <- ur$units
  weft_env$units_default <- ur$default
  ok <- TRUE
  invisible()
}

read_config_ <- function(dir, front, doc) {
  # a read that fails leaves no `units:` table from an earlier one in use
  weft_env$units <- NULL
  weft_env$units_default <- NULL
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
  raw <- NULL
  if (has_file) {
    ws <- read_weft_yml(file)
    proj <- ws$proj
    raw <- ws$raw
  }
  if (has_file && "dict_local" %in% names(proj)) {
    weft_abort(paste0(
      "`dict_local` is written in a document's front matter, not in _weft.yml ",
      "(rules 4.3.4, 9.1.2)."), "weft_config_error")
  }
  if (has_file) warn_unknown(proj, "_weft.yml")
  # the draft setting is `true` or `false` and nothing else, in _weft.yml and in
  # the variable alike; the Lua filter and the post-render script read it the
  # same way (9.4.3, review A 4)
  if (has_file && "draft" %in% names(proj) &&
      !(is.logical(proj$draft) && length(proj$draft) == 1L && !is.na(proj$draft))) {
    weft_abort(sprintf("The setting `draft` in _weft.yml must be true or false; got `%s`.",
                       paste(as.character(unlist(proj$draft)), collapse = ", ")),
               "weft_config_error")
  }
  # `ledger: [true]` reads as TRUE; a list is not a logical (I10)
  if (has_file && "ledger" %in% names(proj)) {
    if (is.list(raw) && is.list(raw$ledger)) {
      weft_abort("The setting `ledger` must be TRUE or FALSE.", "weft_config_error")
    }
  }
  if (has_file) {
    for (nm in intersect(project_only_settings(), names(default_config()))) {
      if (nm %in% names(front)) {
        weft_abort(sprintf(paste0(
          "`%s` is a project setting: set it in _weft.yml, not in a ",
          "document's `weft:` front matter (rule 9.1.4)."), nm), "weft_config_error")
      }
    }
  }
  if (has_file) check_raw_scalars(raw)
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
  ur <- read_units_tables(list(
    list(tbl = proj_units, where = if (has_file) file else "_weft.yml"),
    list(tbl = front_units, where = doc %||% "the document's `weft:` front matter")),
    cfg$unit_defaults, root = dir)
  cfg$units <- ur$units
  cfg$units_default <- ur$default
  weft_env$units <- cfg$units
  weft_env$units_default <- cfg$units_default
  env_draft <- trimws(Sys.getenv("WEFT_DRAFT"))
  if (nzchar(env_draft)) {
    # `1` is kept as the long-standing spelling of true for the variable (the
    # test suite and CI set it); `yes`, `on` and the rest are errors
    if (!tolower(env_draft) %in% c("true", "false", "1")) {
      weft_abort(sprintf("The environment variable WEFT_DRAFT must be true or false; got `%s`.", env_draft),
                 "weft_config_error")
    }
    if (tolower(env_draft) %in% c("true", "1")) cfg$draft <- TRUE
  }
  cfg
}

# The settings that belong to the project, not to a document (rule 9.1.4); the
# `config-place` lint and read_config() both read this list.
project_only_settings <- function() c("draft", "decisions", "verify_skip")

# An unknown setting is kept, with a warning that names it (a misspelt
# setting would otherwise do nothing).
warn_unknown <- function(over, where) {
  unk <- setdiff(names(over), names(default_config()))
  for (k in unk) {
    weft_warn(sprintf("Unknown weft setting `%s` in %s; it is ignored.", k, where),
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
      old <- base$formatters %||% list()
      v <- as.list(v %||% list())
      # a later registration replaces `options` as a whole (rule 1.4.22)
      for (cl in intersect(names(v), names(old))) {
        if (is.list(v[[cl]]) && "options" %in% names(v[[cl]])) old[[cl]][["options"]] <- NULL
      }
      base$formatters <- utils::modifyList(old, v)
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
  lgl("pct_proportion"); lgl("draft"); lgl("ledger"); lgl("sentence_start_fail"); lgl("serial_comma")
  lgl("bare_missing")
  str("date_format")
  uf <- cfg$unit_form
  if (!is.character(uf) || length(uf) != 1L || is.na(uf) || !uf %in% c("auto", "symbol", "name")) {
    weft_abort(sprintf(paste0("The setting `unit_form` must be one of auto, symbol or name; got %s ",
                              "(rule 9.1.6)."),
                       if (is.character(uf) && length(uf) == 1L && !is.na(uf)) paste0("`", uf, "`") else "something else"),
               "weft_config_error")
  }
  ud <- cfg$unit_defaults
  if (!is.character(ud) || length(ud) != 1L || is.na(ud) || !ud %in% c("weft", "si")) {
    weft_abort(sprintf("`unit_defaults` must be `weft` or `si`; got `%s` (rule 9.1.6).",
                       paste(as.character(unlist(ud)), collapse = ", ")),
               "weft_config_error")
  }
  decisions_route(cfg$decisions)
  validate_lint_config(cfg)
  validate_verify_config(cfg)
  prop <- function(nm, open = TRUE) {
    v <- cfg[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 0 ||
        (open && v >= 1) || v > 1) bad(nm, "a proportion between 0 and 1")
  }
  prop("ci_level"); prop("about_tolerance", open = FALSE)
  lgl("ci_short")
  pd <- cfg$p_digits
  if (!is.null(pd) && (!is.numeric(pd) || length(pd) != 1L || !is.finite(pd) ||
                       pd < 1 || pd > 6 || pd != round(pd))) {
    weft_abort("The setting `p_digits` must be a whole number from 1 to 6, or null.",
               "weft_config_error")
  }
  if (!is.character(cfg$p_label) || length(cfg$p_label) != 1L || is.na(cfg$p_label)) {
    weft_abort("The setting `p_label` must be a single string.", "weft_config_error")
  }
  for (nm in c("output_refs", "output_missing", "output_markup")) {
    v <- cfg[[nm]]
    if (!is.character(v) || length(v) != 1L || is.na(v) || !v %in% c("fail", "warn", "off")) {
      weft_abort(sprintf("The setting `%s` must be fail, warn or off.", nm), "weft_config_error")
    }
  }
  cc <- cfg$chunk_claims
  if (!is.character(cc) || length(cc) != 1L || is.na(cc) || !cc %in% c("stop", "collect")) {
    weft_abort("The setting `chunk_claims` must be stop or collect.", "weft_config_error")
  }
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
    for (k in setdiff(names(spec), c("function", "stage", "options"))) {
      weft_warn(sprintf("Unknown key `%s` in the formatter `%s`; it is ignored (rule 1.4.8).", k, nm),
                class = "weft_config_warning")
    }
    fm[[nm]][["options"]] <- check_options(spec[["options"]], nm, stage)
  }
  fm
}

# The options a project formatter declares (rule 1.4.22), as a named character
# vector, name to type, in declaration order; `character()` for none. `raw` is a
# sequence of names or a mapping from name to type.
check_options <- function(raw, nm, stage) {
  if (length(raw) == 0L) return(character())
  if (is.character(raw) && !is.null(names(raw))) raw <- as.list(raw)   # already checked
  m1 <- function() weft_abort(sprintf(paste0(
    "The `options` of the formatter `%s` must be a list of option names or a mapping ",
    "from option name to type (rule 1.4.22)."), nm), "weft_config_error")
  is_str <- function(v) is.character(v) && length(v) == 1L && !is.na(v)
  if (is.list(raw) && !is.null(names(raw))) {
    onames <- names(raw)
    if (any(!nzchar(onames))) m1()
    types <- vapply(raw, function(v) {
      if (is.null(v)) return(NA_character_)
      if (!is_str(v)) m1()
      v
    }, "", USE.NAMES = FALSE)
  } else {
    vals <- as.list(raw)
    if (!all(vapply(vals, is_str, NA))) m1()
    onames <- unlist(vals, use.names = FALSE)
    types <- rep(NA_character_, length(onames))
  }
  out <- character()
  for (i in seq_along(onames)) {
    o <- onames[i]
    if (!grepl("^[a-z][a-z0-9_]*$", o)) {
      weft_abort(sprintf(paste0(
        "The option name `%s` of the formatter `%s` must start with a lower-case letter and have ",
        "only lower-case letters, digits and `_` (rule 1.4.22)."), o, nm), "weft_config_error")
    }
    if (o %in% names(out)) {
      weft_abort(sprintf("The option `%s` is declared twice for the formatter `%s` (rule 1.4.22).",
                         o, nm), "weft_config_error")
    }
    if (o %in% OPTION_RESERVED) {
      weft_abort(sprintf(paste0(
        "The formatter `%s` cannot declare `%s` as an option: weft reads that key itself ",
        "(rule 1.4.22)."), nm, o), "weft_config_error")
    }
    owner <- unname(WEFT_KEY_OWNER[o])
    ty <- types[i]
    if (!is.na(owner) && owner != stage) {
      weft_abort(sprintf(paste0(
        "The formatter `%s` cannot declare `%s` as an option: `%s` belongs to weft's %s stage, ",
        "and `%s` is a %s-stage formatter (rule 1.4.22)."), nm, o, o, owner, nm, stage),
        "weft_config_error")
    }
    if (is.na(ty)) {
      ty <- if (is.na(owner)) "string" else unname(WEFT_KEY_TYPE[o])
    } else if (!ty %in% OPTION_TYPES) {
      weft_abort(sprintf(paste0(
        "The option `%s` of the formatter `%s` has the unknown type `%s`; the types are number, ",
        "integer, string and logical (rule 1.4.22)."), o, nm, ty), "weft_config_error")
    } else if (!is.na(owner) && ty != WEFT_KEY_TYPE[o]) {
      weft_abort(sprintf(paste0(
        "The option `%s` of the formatter `%s` is weft's key, of type %s, and cannot be declared ",
        "as %s (rule 1.4.22)."), o, nm, WEFT_KEY_TYPE[o], ty), "weft_config_error")
    }
    out[o] <- ty
  }
  out
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

# A project "has been set up" (9.3.2) when its root holds `_weft.yml`.
is_set_up <- function(root) file.exists(file.path(root, "_weft.yml"))

# ---- the lint settings (rules 5.2.4, 5.5.4, 5.3.3, 3.1.9) ----------------------

# Checks the keys of design-3 L8. `raw` (optional) is the same settings read
# with sequences kept as lists, so that `[true]` is not taken for TRUE.
validate_lint_config <- function(cfg, raw = NULL) {
  bad <- function(nm, what, rule = NULL) {
    weft_abort(sprintf("The setting `%s` must be %s%s.", nm, what,
                       if (is.null(rule)) "" else paste0(" (rule ", rule, ")")),
               "weft_config_error")
  }
  words <- function(v) {
    if (is.null(v) || (is.list(v) && !length(v))) return(character())
    if (is.list(v) && !is.null(names(v))) return(NULL)
    u <- if (is.list(v)) {
      if (any(!vapply(v, function(e) is.character(e) && length(e) == 1L, NA))) return(NULL)
      unlist(v, use.names = FALSE)
    } else v
    if (!is.character(u) || anyNA(u) || any(!nzchar(u)) || any(grepl("[[:space:]]", u))) return(NULL)
    u
  }
  if (is.null(words(cfg$label_words))) bad("label_words", "a list of words without spaces", "5.2.4")
  nu <- cfg$numeral_years
  if (!is.logical(nu) || length(nu) != 1L || is.na(nu) || is.list(raw[["numeral_years"]])) {
    bad("numeral_years", "TRUE or FALSE", "5.2.4")
  }
  cw <- cfg$claim_words
  cw_msg <- paste0("a mapping with `add` and `drop`, each a list of words, and an optional `idioms`, ",
                   "a list of phrases")
  phrases <- function(v) {
    if (is.null(v) || (is.list(v) && !length(v))) return(TRUE)
    if (is.list(v) && !is.null(names(v))) return(FALSE)
    u <- if (is.list(v)) {
      if (any(!vapply(v, function(e) is.character(e) && length(e) == 1L, NA))) return(FALSE)
      unlist(v, use.names = FALSE)
    } else v
    is.character(u) && !anyNA(u) && all(nzchar(trimws(u)))
  }
  if (!is.list(cw) || (length(cw) && is.null(names(cw))) || !all(names(cw) %in% c("add", "drop", "idioms")) ||
      is.null(words(cw$add)) || is.null(words(cw$drop)) || !phrases(cw$idioms)) {
    bad("claim_words", cw_msg, "5.5.4")
  }
  cq <- cfg$claim_quantifiers
  if (!is.character(cq) || length(cq) != 1L || is.na(cq) || !cq %in% c("number", "any", "none") ||
      is.list(raw[["claim_quantifiers"]])) {
    bad("claim_quantifiers", "one of `number`, `any` or `none`", "5.5.5")
  }
  for (nm in c("claim_cap", "guard_words")) {
    v <- cfg[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 1 || v != round(v) ||
        is.list(raw[[nm]])) {
      bad(nm, "a whole number from 1", if (nm == "claim_cap") "5.5.3" else "3.1.9")
    }
  }
  en <- cfg$expected_names
  ok <- is.null(en) || (is.list(en) && !length(en)) || (is.null(names(en)) && {
    u <- if (is.list(en)) {
      if (any(!vapply(en, function(e) is.character(e) && length(e) == 1L, NA))) NULL else unlist(en, use.names = FALSE)
    } else en
    is.character(u) && !anyNA(u) && all(grepl("^\\.?[^[:space:].]+$", u))
  })
  if (!ok) bad("expected_names", "a list of names, each `.class` or `key`", "5.3.3")
  check_anchor_calls(cfg$anchor_calls)
  invisible(cfg)
}

# `anchor_calls`: a list of entries, each naming a helper function `fun` (a string) and the
# argument `arg` of it that holds an anchor id (a name, or a whole position from 1), with an
# optional string `prefix`. Returns the entries as lists of fun, arg and prefix; stops on a fault,
# naming the setting, so that a misspelt entry does not quietly define nothing.
check_anchor_calls <- function(v) {
  bad <- function(what) {
    weft_abort(sprintf("The setting `anchor_calls` must be a list of entries, each with a `fun` (a string), an `arg` (a name or a position from 1) and an optional string `prefix`; %s.", what),
               "weft_config_error")
  }
  if (is.null(v) || (is.list(v) && !length(v))) return(list())
  if (!is.list(v) || !is.null(names(v))) bad("it is not a list of entries")
  str1 <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  lapply(seq_along(v), function(i) {
    e <- v[[i]]
    if (!is.list(e) || is.null(names(e))) bad(sprintf("entry %d is not a mapping", i))
    if (!str1(e$fun)) bad(sprintf("entry %d has no `fun` string", i))
    a <- e$arg
    if (!(str1(a) || (is.numeric(a) && length(a) == 1L && is.finite(a) && a >= 1 && a == round(a)))) {
      bad(sprintf("entry %d has no `arg` name or position", i))
    }
    pre <- e$prefix %||% ""
    if (!(is.character(pre) && length(pre) == 1L && !is.na(pre))) bad(sprintf("entry %d has a `prefix` that is not a string", i))
    list(fun = e$fun, arg = a, prefix = pre)
  })
}

# A scalar setting written as a one-item list (`[true]`) is not a scalar.
check_raw_scalars <- function(raw) {
  if (!is.list(raw)) return(invisible())
  what <- c(numeral_years = "TRUE or FALSE", claim_cap = "a whole number from 1",
            guard_words = "a whole number from 1", weft_version = "a single string")
  for (nm in names(what)) {
    if (is.list(raw[[nm]])) {
      weft_abort(sprintf("The setting `%s` must be %s.", nm, what[[nm]]), "weft_config_error")
    }
  }
  # a list of words has no list inside it (`strict: [[numeral]]`)
  for (nm in c("strict", "verify_skip")) {
    if (is.list(raw[[nm]]) && any(vapply(raw[[nm]], is.list, NA))) {
      weft_abort(sprintf("The setting `%s` must be a list of words, not a nested list.", nm), "weft_config_error")
    }
  }
  invisible()
}

# ---- the verify settings (rules 8.1.3, 8.1.4, 9.5.4; design-4 G31) -------------------

VERIFY_PARTS <- c("lints", "decisions", "render", "ledger")

# `strict`, `verify_skip` and `weft_version`.
validate_verify_config <- function(cfg) {
  bad <- function(nm, what) {
    weft_abort(sprintf("The setting `%s` must be %s.", nm, what), "weft_config_error")
  }
  words <- function(nm) {
    v <- cfg[[nm]]
    if (is.null(v) || (is.list(v) && !length(v))) return(character())
    u <- if (is.list(v)) {
      if (!is.null(names(v)) ||
          any(!vapply(v, function(e) is.character(e) && length(e) == 1L, NA))) return(NULL)
      unlist(v, use.names = FALSE)
    } else v
    if (!is.character(u) || anyNA(u) || any(!nzchar(u))) return(NULL)
    u
  }
  st <- words("strict")
  if (is.null(st)) bad("strict", "a list of tier-1 rule ids")
  tab <- lint_rule_table()
  for (id in st) {
    i <- match(id, tab$id)
    if (is.na(i)) {
      hint <- did_you_mean(id, tab$id[tab$tier == 1L])
      weft_abort(sprintf("`%s` is not a weft rule;%s", id,
                         if (nzchar(hint)) sub("^ Did you mean", " did you mean", hint)
                         else " see lint_rules()$id for the ids (rule 8.1.3)."),
                 "weft_config_error")
    }
    if (tab$tier[i] != 1L) {
      weft_abort(sprintf("`%s` is tier 2 and blocks nothing, so it cannot be strict (rule 8.1.3).", id),
                 "weft_config_error")
    }
  }
  vs <- words("verify_skip")
  if (is.null(vs)) bad("verify_skip", "a list of parts of verify(): lints, decisions, render, ledger")
  unk <- setdiff(vs, VERIFY_PARTS)
  if (length(unk)) {
    weft_abort(sprintf("`verify_skip` names %s, which %s not a part of verify(); the parts are %s (rule 8.1.4).",
                       paste0("`", unk, "`", collapse = ", "), if (length(unk) == 1L) "is" else "are",
                       paste(VERIFY_PARTS, collapse = ", ")), "weft_config_error")
  }
  wv <- cfg$weft_version
  if (!is.null(wv) && (is.list(wv) || length(wv) != 1L || is.na(wv) ||
                       !(is.character(wv) || is.numeric(wv)))) {
    bad("weft_version", "a single string")
  }
  invisible(cfg)
}
