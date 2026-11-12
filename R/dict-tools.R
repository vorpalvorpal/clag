# Dictionary tooling (rules 4.7.1-4.7.4, 9.3.1, 9.5.2): `use_dictionary()`,
# `dict_glossary()`, `dict_vale()`, `dict_seed()`. Contract: dev/design-2c.md.

tool_abort <- function(message) weft_abort(message, "weft_tool_error")

# ---- use_dictionary() ----------------------------------------------------------

#' Set up the project dictionary
#'
#' Writes a starter `dict.yml` and the JSON Schema an editor checks it against.
#' It says what it will write, then writes it: the call is the consent, and it
#' never asks. `suppressMessages()` silences it.
#'
#' It writes, under the project root (see below):
#'
#' * `dict.yml`, only when there is none: a starter that reads as a dictionary
#'   with no keys, with two examples commented out. An existing `dict.yml` is
#'   never changed; when it has no `yaml-language-server` schema line,
#'   `use_dictionary()` prints the line to add.
#' * `_weft/dict.schema.json`, when it is missing or differs from the schema of
#'   this version of weft (it is weft's own file). The folder `_weft/` is
#'   created if needed.
#'
#' The project root is the nearest folder from `path` upward that holds
#' `_weft.yml`, else `_quarto.yml`, else `path` itself; when it is not `path`,
#' `use_dictionary()` says so and writes there.
#'
#' The schema covers what an editor can see of a dictionary file; [read_dict()]
#' checks more (see [dict_file]), and a file the schema accepts can still be
#' refused when it is read.
#'
#' @param path A directory in the project.
#' @return The paths written, relative to the root, invisibly (`character()`
#'   when nothing was written).
#' @examples
#' \dontrun{
#' use_dictionary()
#' }
#' @export
use_dictionary <- function(path = ".") {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    tool_abort(sprintf("use_dictionary(): `path` must be a directory; got %s.",
                       if (is.character(path) && length(path) == 1L && !is.na(path))
                         paste0("`", path, "`") else "`something else`"))
  }
  start <- normalizePath(path, mustWork = TRUE)
  root <- find_project_root(path)
  if (!identical(root, start)) {
    marker <- if (file.exists(file.path(root, "_weft.yml"))) "_weft.yml" else "_quarto.yml"
    message(sprintf("weft: the project root is %s (it holds %s); writing there.", root, marker))
  }
  src <- function(f) {
    p <- system.file("dict", f, package = "weft")
    if (!nzchar(p)) tool_abort(paste0("weft's own file inst/dict/", f, " is missing"))
    p
  }
  same <- function(a, b) {
    identical(readBin(a, "raw", file.size(a)), readBin(b, "raw", file.size(b)))
  }
  dict_to <- file.path(root, "dict.yml")
  schema_to <- file.path(root, "_weft", "dict.schema.json")
  dict_exists <- file.exists(dict_to)
  schema_exists <- file.exists(schema_to)
  schema_current <- schema_exists && same(schema_to, src("dict.schema.json"))
  write_dict <- !dict_exists
  write_schema <- !schema_current
  if (write_dict || write_schema) {
    message("weft will write, under ", root, ":")
    message("  dict.yml  (", if (dict_exists) "exists: left as it is"
            else "new: a starter dictionary, with two examples commented out", ")")
    message("  _weft/dict.schema.json  (", if (!schema_exists)
              "new: the JSON Schema an editor checks dict.yml against"
            else if (schema_current) "exists and is current: left as it is"
            else "exists: replaced by the schema of this version of weft", ")")
    wrote <- character()
    if (write_dict) {
      file.copy(src("dict.yml"), dict_to, overwrite = FALSE)
      wrote <- c(wrote, "dict.yml")
    }
    if (write_schema) {
      dir.create(dirname(schema_to), showWarnings = FALSE, recursive = TRUE)
      file.copy(src("dict.schema.json"), schema_to, overwrite = TRUE)
      wrote <- c(wrote, "_weft/dict.schema.json")
    }
    message("Wrote: ", paste(wrote, collapse = ", "))
  } else {
    wrote <- character()
    message("Nothing to change: dict.yml and its schema are in place.")
  }
  if (dict_exists) {
    txt <- readLines(dict_to, warn = FALSE, encoding = "UTF-8")
    if (!any(grepl("yaml-language-server: $schema=", txt, fixed = TRUE))) {
      message("dict.yml has no schema line; for an editor to check it, add this as its first line:\n",
              "  # yaml-language-server: $schema=_weft/dict.schema.json")
    }
  }
  invisible(wrote)
}

# ---- the dictionary an argument names -----------------------------------------------

# `dict` as the tool `fn` takes it: a weft_dict, or (NULL) the project's.
tool_dict <- function(dict, fn, knit = FALSE) {
  if (is.null(dict)) {
    s <- if (knit) active_state() else NULL
    if (!is.null(s)) {
      if (is.null(s$dict)) {
        tool_abort(sprintf("%s(): this document's project has no dict.yml; give `dict`.", fn))
      }
      return(s$dict)
    }
    root <- find_project_root(getwd())
    f <- file.path(root, "dict.yml")
    if (!file.exists(f)) {
      tool_abort(sprintf(paste0("%s(): there is no dict.yml at %s; give `dict`, ",
                                "or create one with use_dictionary()."), fn, root))
    }
    return(read_dict(f))
  }
  if (!inherits(dict, "weft_dict")) {
    tool_abort(sprintf("%s(): `dict` must be a dictionary, as read_dict() returns; got %s.",
                       fn, class(dict)[1L]))
  }
  dict
}

# ---- dict_glossary() -----------------------------------------------------------------

#' The glossary of a dictionary
#'
#' `dict_glossary()` returns the dictionary as a glossary in Pandoc markdown: a
#' definition list, one entry per key. It is a `knit_asis` string, so a chunk
#' prints it as markdown with no `results: asis`:
#'
#' ```r
#' dict_glossary()
#' ```
#'
#' It writes nothing. It is attached in a weft document as `claim()` and `u()`
#' are.
#'
#' An entry is two lines: a heading and `:   <definition>`. The heading is the
#' entry's `term` as written (markdown), else the key in code; then, when
#' `values` is `TRUE` and the entry is a `number`, `quantity`, `year`, `date` or
#' `string`, its value in parentheses: numbers and quantities through
#' [fmt_num()] with the decimals written in the file, dates through
#' [fmt_date()], so the configuration in force (marks, `thousands_from`,
#' `unit_form`, the `units:` table) applies. A `labels` or `breaks` entry shows
#' no value. White space in a definition and in a string value becomes one
#' space; markdown is kept as written. `why` is never shown.
#'
#' @param dict A dictionary, as [read_dict()] returns, or `NULL`. `NULL` in a
#'   knit is the knit's project dictionary; outside a knit it reads `dict.yml`
#'   at the project root. A chapter's `dict_local` is accepted when given.
#' @param values Whether to show the values: `TRUE` or `FALSE`.
#' @param sort Whether to sort the entries by heading, ignoring case (`TRUE`),
#'   or keep the order of the file (`FALSE`).
#' @return A `knit_asis` string holding the markdown; `""` for an empty
#'   dictionary.
#' @examples
#' f <- tempfile(fileext = ".yml")
#' writeLines(c("min_samples:",
#'              "  value: 5",
#'              "  type: number",
#'              "  term: minimum sample size",
#'              "  definition: Fewest samples a site needs."), f)
#' cat(dict_glossary(read_dict(f)))
#' @export
dict_glossary <- function(dict = NULL, values = TRUE, sort = TRUE) {
  d <- tool_dict(dict, "dict_glossary", knit = TRUE)
  for (nm in c("values", "sort")) {
    v <- get(nm)
    if (!is.logical(v) || length(v) != 1L || is.na(v)) {
      tool_abort(sprintf("dict_glossary(): `%s` must be TRUE or FALSE.", nm))
    }
  }
  e <- attr(d, "entries")
  n <- nrow(e)
  if (!n) return(knitr::asis_output(""))
  one_line <- function(x) trimws(gsub("[[:space:]]+", " ", x))
  vals <- unclass(d)
  head_text <- ifelse(is.na(e$term), e$key, e$term)
  heads <- ifelse(is.na(e$term), paste0("`", e$key, "`"), e$term)
  for (i in seq_len(n)) {
    if (values && e$type[i] %in% c("number", "quantity", "year", "date", "string")) {
      heads[i] <- paste0(heads[i], " (", glossary_value(vals[[e$key[i]]], e$type[i], one_line), ")")
    }
  }
  ord <- if (sort) order(tolower(head_text), e$key, method = "radix") else seq_len(n)
  def <- one_line(e$definition)
  body <- paste0(heads[ord], "\n:   ", def[ord])
  knitr::asis_output(paste0("\n", paste(body, collapse = "\n\n"), "\n"))
}

glossary_value <- function(v, type, one_line) {
  if (type == "string") return(one_line(v))
  if (type == "date") return(as.character(fmt_date(v)))
  num <- if (type == "quantity") as.numeric(units::drop_units(v)) else as.numeric(v)
  txt <- format(num, digits = 15, scientific = FALSE, trim = TRUE)
  dec <- if (grepl(".", txt, fixed = TRUE)) nchar(sub("^[^.]*[.]", "", txt)) else 0L
  as.character(fmt_num(v, digits = dec))
}

# ---- dict_vale() -----------------------------------------------------------------------

VALE_MARK <- "# Generated by weft::dict_vale()"

#' A Vale rule from the dictionary's `avoid` fields
#'
#' `dict_vale()` writes one [Vale](https://vale.sh) `substitution` rule that
#' replaces each spelling an entry lists under `avoid` by the entry's canonical
#' spelling: its `term`, or, for a `string` entry with no `term`, its value. It
#' says what it will write before it writes.
#'
#' The rule matches each spelling as written (`ignorecase: false`): list a case
#' variant as a spelling of its own. Spellings are keys of a regular expression
#' in Vale, so their metacharacters are escaped; longer spellings come first.
#'
#' It replaces only a file it wrote (the first line says so) and stops with an
#' error on any other. When the dictionary has no `avoid` left, a file it wrote
#' is removed. It never writes `.vale.ini`: when that file does not list the
#' style in `BasedOnStyles`, it says what the file needs.
#'
#' @param dict A dictionary, as [read_dict()] returns, or `NULL` to read
#'   `dict.yml` at the project root. A dictionary with problems raises its
#'   error and nothing is written.
#' @param path The rule file, relative to the project root: `<styles>/<Style>/<Rule>.yml`.
#' @param level The rule's level: `"suggestion"`, `"warning"` or `"error"`.
#' @return The path written or removed, invisibly; `character()` when nothing
#'   was changed.
#' @export
dict_vale <- function(dict = NULL, path = "styles/Weft/Terms.yml", level = "warning") {
  if (!is.character(level) || length(level) != 1L || is.na(level) ||
      !level %in% c("suggestion", "warning", "error")) {
    tool_abort("dict_vale(): `level` must be one of suggestion, warning or error.")
  }
  bad_path <- function() {
    tool_abort(sprintf(paste0("dict_vale(): `path` must name a rule file inside a style folder, ",
                              "as styles/Weft/Terms.yml; got `%s`."),
                       if (is.character(path) && length(path) == 1L && !is.na(path)) path
                       else "something else"))
  }
  if (!is.character(path) || length(path) != 1L || is.na(path)) bad_path()
  parts <- strsplit(path, "[/\\\\]")[[1L]]
  parts <- parts[nzchar(parts)]
  if (!grepl("\\.yml$", path) || length(parts) < 3L) bad_path()
  d <- tool_dict(dict, "dict_vale")
  root <- find_project_root(getwd())
  absolute <- grepl("^(/|~|[A-Za-z]:[/\\\\])", path)
  abs <- normalizePath(if (absolute) path else file.path(root, path), mustWork = FALSE)
  dfile <- basename(attr(d, "file"))
  swap <- vale_swaps(d)
  generated <- function() {
    file.exists(abs) && length(l <- readLines(abs, n = 1L, warn = FALSE)) && startsWith(l, VALE_MARK)
  }
  if (!nrow(swap)) {
    if (generated()) {
      message(sprintf("weft will remove %s: %s has no avoid: spellings now.", abs, dfile))
      unlink(abs)
      message("Removed: ", abs)
      return(invisible(abs))
    }
    message(sprintf("%s has no avoid: spellings, so there is no rule to write.", dfile))
    return(invisible(character()))
  }
  if (file.exists(abs) && !generated()) {
    tool_abort(sprintf(paste0("dict_vale(): %s exists and was not written by dict_vale(); ",
                              "nothing was written. Move it, or give another `path`."), abs))
  }
  quote1 <- function(x) paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
  text <- c(
    paste0(VALE_MARK, " from ", dfile, ". Do not edit: change the"),
    "# `avoid:` fields in dict.yml and run weft::dict_vale() again.",
    "extends: substitution",
    "message: \"Use '%s' instead of '%s' (the project dictionary's spelling).\"",
    paste0("level: ", level),
    "ignorecase: false",
    "swap:",
    paste0("  ", quote1(vale_escape(swap$spelling)), ": ", quote1(swap$canon)))
  bytes <- charToRaw(enc2utf8(paste0(paste(text, collapse = "\n"), "\n")))
  if (file.exists(abs) && identical(readBin(abs, "raw", file.size(abs)), bytes)) {
    message(sprintf("Nothing to change: %s is up to date.", abs))
    out <- character()
  } else {
    message(sprintf("weft will write %s: a Vale substitution rule with %d avoided spelling(s) from %s.",
                    abs, nrow(swap), dfile))
    dir.create(dirname(abs), showWarnings = FALSE, recursive = TRUE)
    writeBin(bytes, abs)
    message("Wrote: ", abs)
    out <- abs
  }
  style <- basename(dirname(abs))
  styles <- dirname(dirname(if (absolute) path else path))
  if (absolute && startsWith(styles, paste0(root, "/"))) styles <- substring(styles, nchar(root) + 2L)
  ini <- file.path(root, ".vale.ini")
  listed <- file.exists(ini) && any(grepl(
    paste0("^\\s*BasedOnStyles\\s*=.*\\b", gsub("([^A-Za-z0-9 ])", "\\\\\\1", style), "\\b"),
    readLines(ini, warn = FALSE, encoding = "UTF-8"), perl = TRUE))
  if (!listed) {
    message(sprintf(paste0("Vale uses this rule when .vale.ini, at %s, sets StylesPath = %s and ",
                           "lists %s in BasedOnStyles."), root, styles, style))
  }
  invisible(out)
}

# The avoided spellings with the spelling each is replaced by, longest first.
vale_swaps <- function(d) {
  e <- attr(d, "entries")
  sp <- character()
  cn <- character()
  for (i in seq_len(nrow(e))) {
    a <- e$avoid[[i]]
    if (!length(a)) next
    canon <- if (!is.na(e$term[i])) e$term[i] else unclass(d)[[e$key[i]]]
    sp <- c(sp, a)
    cn <- c(cn, rep(canon, length(a)))
  }
  o <- order(-nchar(sp), sp, method = "radix")
  data.frame(spelling = sp[o], canon = cn[o], stringsAsFactors = FALSE)
}

vale_escape <- function(x) gsub("([\\\\.+*?()|\\[\\]{}^$])", "\\\\\\1", x, perl = TRUE)

# ---- dict_seed() -------------------------------------------------------------------------

#' Find constants a project defines in more than one document
#'
#' `dict_seed()` lists names that two or more documents each assign a literal
#' value, as candidates for `dict.yml`. It parses the code and never runs it,
#' and it writes nothing.
#'
#' With `paths = NULL` it reads every `.qmd`, `.Rmd` and `.rmd` file under the
#' project root, except in folders whose name starts with `_` or `.` or is
#' `renv`. Given `paths` it reads those files, which may be `.R` files too; a
#' `.R` file is read only when named. In a document it reads each `r` chunk
#' except one with `eval = FALSE` in its header or `#| eval: false`.
#'
#' A name counts when a top-level expression of a piece (not inside `{`, `if`,
#' `function` or any other call) is `name <- literal`, `name = literal` or
#' `literal -> name`, a literal being a number, a string, `-` or `+` of a
#' number, or `c()` of numbers or of strings with every argument named or none.
#' Logicals, `NA`, `NULL`, dates, `<<-` and `assign()` do not count.
#'
#' Limits: a constant written by a computation, or inside a function or a
#' block, is not seen; inline R is not read; a name reused for unrelated things
#' in two documents is listed, and the author decides.
#'
#' @param paths `NULL`, or a character vector of files.
#' @param min_files The least number of files that must assign a name, from 1.
#' @return A data frame with a row per name: `name`, `value` (its text, `NA`
#'   when the values differ), `differs`, `n` (files), `files` and `where` (every
#'   assignment as `<file>:<line>: <value>`). The attribute `skipped` is a data
#'   frame (`file`, `line`, `message`) of pieces of code that did not parse.
#' @export
dict_seed <- function(paths = NULL, min_files = 2) {
  if (!is.numeric(min_files) || length(min_files) != 1L || !is.finite(min_files) ||
      min_files < 1 || min_files != round(min_files)) {
    tool_abort("dict_seed(): `min_files` must be a whole number from 1.")
  }
  empty <- function() {
    r <- data.frame(name = character(), value = character(), differs = logical(),
                    n = integer(), files = character(), where = character(),
                    stringsAsFactors = FALSE)
    attr(r, "skipped") <- seed_skipped()
    r
  }
  base <- ""
  if (is.null(paths)) {
    root <- find_project_root(getwd())
    found <- list.files(root, pattern = "\\.(qmd|Rmd|rmd)$", recursive = TRUE)
    skip <- vapply(strsplit(dirname(found), "/", fixed = TRUE), function(p) {
      p <- p[p != "."]
      any(startsWith(p, "_") | startsWith(p, ".") | p == "renv")
    }, NA)
    found <- sort(found[!skip], method = "radix")
    if (!length(found)) {
      message(sprintf("dict_seed(): no .qmd or .Rmd files under %s.", root))
      return(empty())
    }
    paths <- found
    base <- root
  } else {
    if (!is.character(paths) || anyNA(paths)) tool_abort("dict_seed(): `paths` must be file names.")
    gone <- paths[!file.exists(paths) | dir.exists(paths)]
    if (length(gone)) {
      tool_abort(sprintf("dict_seed(): no such file: %s.", paste(gone, collapse = ", ")))
    }
    odd <- paths[!grepl("\\.(qmd|Rmd|rmd|R|r)$", paths)]
    if (length(odd)) {
      tool_abort(sprintf("dict_seed(): %s is not a .qmd, .Rmd or .R file.", odd[1L]))
    }
  }
  hits <- list()
  skipped <- seed_skipped()
  for (f in paths) {
    full <- if (nzchar(base)) file.path(base, f) else f
    lines <- readLines(full, warn = FALSE, encoding = "UTF-8")
    pieces <- if (grepl("\\.[Rr]$", f)) list(list(code = lines, open = 0L)) else seed_chunks(lines)
    for (pc in pieces) {
      ex <- tryCatch(parse(text = pc$code, keep.source = TRUE),
                     error = function(e) e)
      if (inherits(ex, "error")) {
        skipped <- rbind(skipped, data.frame(
          file = f, line = if (pc$open > 0L) as.integer(pc$open) else 1L,
          message = sub("\n.*$", "", conditionMessage(ex)), stringsAsFactors = FALSE))
        next
      }
      refs <- attr(ex, "srcref")
      for (k in seq_along(ex)) {
        a <- seed_assignment(ex[[k]])
        if (is.null(a)) next
        ln <- as.integer(refs[[k]][1L]) + pc$open
        hits[[length(hits) + 1L]] <- list(name = a$name, value = a$value, file = f, line = ln)
      }
    }
  }
  if (nrow(skipped)) {
    message(sprintf(paste0("dict_seed(): %d piece(s) of code could not be parsed and were skipped; ",
                           "see attr(<result>, \"skipped\")."), nrow(skipped)))
  }
  if (!length(hits)) {
    r <- empty()
    attr(r, "skipped") <- skipped
    return(r)
  }
  nm <- vapply(hits, function(h) h$name, "")
  rows <- lapply(unique(nm), function(name) {
    hs <- hits[nm == name]
    fl <- vapply(hs, function(h) h$file, "")
    ln <- vapply(hs, function(h) h$line, 1L)
    ord <- order(match(fl, paths), ln)
    hs <- hs[ord]
    fl <- fl[ord]
    txt <- vapply(hs, function(h) seed_text(h$value), "")
    same <- all(vapply(hs, function(h) identical(h$value, hs[[1L]]$value), NA))
    list(name = name, value = if (same) txt[1L] else NA_character_, differs = !same,
         n = length(unique(fl)), files = paste(unique(fl), collapse = ", "),
         where = paste(sprintf("%s:%d: %s", fl, vapply(hs, function(h) h$line, 1L), txt),
                       collapse = "; "))
  })
  col <- function(f, type) vapply(rows, function(r) r[[f]], type)
  r <- data.frame(name = col("name", ""), value = col("value", ""), differs = col("differs", NA),
                  n = col("n", 1L), files = col("files", ""), where = col("where", ""),
                  stringsAsFactors = FALSE)
  r <- r[r$n >= min_files, , drop = FALSE]
  r <- r[order(-r$n, r$name, method = "radix"), , drop = FALSE]
  rownames(r) <- NULL
  attr(r, "skipped") <- skipped
  r
}

seed_skipped <- function() {
  data.frame(file = character(), line = integer(), message = character(), stringsAsFactors = FALSE)
}

# The R chunks of a document that are evaluated: list(code, open).
seed_chunks <- function(lines) {
  lines <- dequote_chunks(lines)
  out <- list()
  for (ch in find_chunks(lines)) {
    if (!tolower(ch$engine) == "r") next
    if (grepl("\\beval\\s*=\\s*(FALSE|F)\\b", ch$header, perl = TRUE)) next
    from <- ch$open + 1L
    to <- min(ch$close, length(lines) + 1L) - 1L
    if (!ch$closed) to <- length(lines)
    code <- if (to >= from) lines[from:to] else character()
    if (any(grepl("^\\s*#\\|\\s*eval:\\s*(false|no)\\s*$", code, ignore.case = TRUE))) next
    out[[length(out) + 1L]] <- list(code = code, open = ch$open)
  }
  out
}

# list(name, value) when `e` assigns a literal to a symbol, else NULL.
seed_assignment <- function(e) {
  if (!is.call(e) || length(e) != 3L || !is.symbol(e[[1L]]) ||
      !as.character(e[[1L]]) %in% c("<-", "=") || !is.symbol(e[[2L]])) {
    return(NULL)
  }
  v <- seed_literal(e[[3L]])
  if (is.null(v)) return(NULL)
  list(name = as.character(e[[2L]]), value = v)
}

# The value of a literal (a number, a string, -/+ of a number, c() of those),
# folded on the parse tree, or NULL.
seed_literal <- function(e) {
  num <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  if (num(e)) return(as.numeric(e))
  if (is.character(e) && length(e) == 1L && !is.na(e)) return(e)
  if (!is.call(e) || !is.symbol(e[[1L]])) return(NULL)
  fn <- as.character(e[[1L]])
  if (fn %in% c("-", "+") && length(e) == 2L && num(e[[2L]])) {
    return(if (fn == "-") -as.numeric(e[[2L]]) else as.numeric(e[[2L]]))
  }
  if (fn == "c" && length(e) >= 2L) {
    args <- as.list(e)[-1L]
    nms <- names(args)
    if (!is.null(nms) && any(!nzchar(nms)) && any(nzchar(nms))) return(NULL)
    vals <- lapply(args, function(a) if (is.call(a) && identical(a[[1L]], quote(c))) NULL else seed_literal(a))
    if (any(vapply(vals, is.null, NA))) return(NULL)
    kinds <- vapply(vals, function(v) is.numeric(v), NA)
    if (!(all(kinds) || !any(kinds))) return(NULL)
    out <- unlist(vals, use.names = FALSE)
    if (!is.null(nms) && all(nzchar(nms))) names(out) <- nms
    return(out)
  }
  NULL
}

seed_text <- function(v) paste(deparse(v, width.cutoff = 500L), collapse = " ")
