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

current_config <- function() weft_env$config %||% default_config()

# ---- defaults -----------------------------------------------------------

default_config <- function() {
  list(
    digits = 1,
    decimal_mark = ".",
    big_mark = ",",
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
    severity = character()
  )
}

formatter_stages <- function() c("number", "wording", "collapse", "text")

# ---- reading ------------------------------------------------------------

# `dir` is the project root. `front` is the document's `weft:` front-matter
# key, already parsed to a list.
read_config <- function(dir, front = list()) {
  front <- front %||% list()
  if (!is.list(front) || (length(front) && (is.null(names(front)) ||
                                            any(!nzchar(names(front)))))) {
    weft_abort("The `weft:` front-matter key must be a mapping of settings.",
               "weft_config_error")
  }
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
  if (has_file) warn_unknown(proj, "_weft.yml")
  if (has_file && "draft" %in% names(front)) {
    weft_abort(paste0(
      "`draft` is a project setting: set it in _weft.yml, not in a ",
      "document's `weft:` front matter (rule 9.1.4)."
    ), "weft_config_error")
  }
  cfg <- merge_config(default_config(), proj)
  cfg <- merge_config(cfg, front)
  cfg$formatters <- check_formatters(cfg$formatters)
  cfg <- validate_config(cfg)
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
  str("decimal_mark"); str("big_mark"); str("minus"); str("governor_class")
  lgl("pct_proportion"); lgl("draft"); lgl("sentence_start_fail")
  str("date_format")
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
