# Helpers for the 2e-2 tests (changes() and the third state). Contract: dev/design-2e.md C1-C14,
# with the file formats of dev/design-2d.md D3-D16. Fixtures are hand-written ledger files, not renders.
# Non-ASCII is written as \uXXXX; the ledger file stores U+00A0 as the six characters "\\u00a0".
# Made-up content only. Names start e2x_ so as not to meet the 2e-1 helpers (helper-2e.R).

# ---- JSON by hand, in D3's form ------------------------------------------------------------

e2x_esc <- function(s) {
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub("\"", "\\\"", s, fixed = TRUE)
  s <- gsub("\n", "\\n", s, fixed = TRUE)
  s <- gsub("\t", "\\t", s, fixed = TRUE)
  gsub(" ", "\\u00a0", s, fixed = TRUE)
}
e2x_str <- function(s) if (is.null(s) || length(s) == 0L || is.na(s)) "null" else paste0("\"", e2x_esc(s), "\"")
e2x_num <- function(x) if (is.null(x) || length(x) == 0L || is.na(x)) "null" else if (x == 0) "0" else trimws(formatC(x, digits = 6, format = "g"))
e2x_arr <- function(x) paste0("[", paste(vapply(x, e2x_str, ""), collapse = ","), "]")

# an entry as a list of D8's fields, defaults as the design's helper has them; `file` is filled in by
# e2x_put_ledger() when left NULL; a null `text` is NA
e2x_entry <- function(expr = "x", text = "1", section = "", kind = "value", occ = 1L, id = NA_character_,
                      context = "prose", arm = NA_character_, rel = NA_character_, raw = NA_real_,
                      failed = NA_character_, dict = character(), sentence = NULL, file = NULL, unit = NULL) {
  e <- list(file = file, section = section, kind = kind, expr = expr, occ = occ, id = id, context = context,
       text = text, arm = arm, rel = rel, raw = raw, failed = failed, dict = dict,
       sentence = if (is.null(sentence)) (if (is.na(text)) "" else text) else sentence)
  # `unit` (2d D8 as amended by the review of 2e-2): NULL leaves the field out, as an old ledger has
  # it; NA writes null; a string writes the unit raw is in
  if (!is.null(unit)) e$unit <- unit
  e
}

e2x_entry_line <- function(e) {
  paste0("{\"file\":", e2x_str(e$file), ",\"section\":", e2x_str(e$section), ",\"kind\":", e2x_str(e$kind),
         ",\"expr\":", e2x_str(e$expr), ",\"occ\":", as.integer(e$occ), ",\"id\":", e2x_str(e$id),
         ",\"context\":", e2x_str(e$context), ",\"text\":", e2x_str(e$text), ",\"arm\":", e2x_str(e$arm),
         ",\"rel\":", e2x_str(e$rel), ",\"raw\":", e2x_num(e$raw),
         if ("unit" %in% names(e)) paste0(",\"unit\":", e2x_str(e$unit)),
         ",\"failed\":", e2x_str(e$failed),
         ",\"dict\":", e2x_arr(e$dict), ",\"sentence\":", e2x_str(e$sentence), "}")
}

# a nested header field: NULL -> not written; a named character vector -> {"k":"v"}; a named list of
# those (targets) -> {"store":{"name":"hash"}}; names sorted; values NA -> null
e2x_obj <- function(x) {
  if (!length(x)) return("{}")
  x <- x[order(names(x), method = "radix")]
  parts <- vapply(names(x), function(n) {
    v <- x[[n]]
    paste0(e2x_str(n), ":", if (is.list(v) || !is.null(names(v))) e2x_obj(v) else e2x_str(v))
  }, "")
  paste0("{", paste(parts, collapse = ","), "}")
}

e2x_header_line <- function(source, output, kind = "ledger", dict = NULL, files = NULL, targets = NULL) {
  extra <- c(if (!is.null(dict)) paste0(",\"dict\":", e2x_obj(dict)),
             if (!is.null(files)) paste0(",\"files\":", e2x_obj(files)),
             if (!is.null(targets)) paste0(",\"targets\":", e2x_obj(targets)))
  paste0("{\"weft\":\"", kind, "\",\"version\":1,\"source\":", e2x_str(source), ",\"output\":", e2x_str(output),
         paste(extra, collapse = ""), "}")
}

e2x_ledger_lines <- function(source, output, entries, ...) {
  entries <- lapply(entries, function(e) { if (is.null(e$file)) e$file <- source; e })
  c(e2x_header_line(source, output, "ledger", ...), vapply(entries, e2x_entry_line, ""))
}

# a condition-log line (D15)
e2x_cond <- function(source = "fit", text = "Model failed to converge.", from = "chunk", class = "warning",
                     normalised = text) {
  list(from = from, source = source, class = class, normalised = normalised, text = text)
}
e2x_cond_line <- function(k) {
  paste0("{\"from\":", e2x_str(k$from), ",\"source\":", e2x_str(k$source), ",\"class\":", e2x_str(k$class),
         ",\"normalised\":", e2x_str(k$normalised), ",\"text\":", e2x_str(k$text), "}")
}
e2x_cond_lines <- function(source, output, conds) {
  c(e2x_header_line(source, output, "conditions"), vapply(conds, e2x_cond_line, ""))
}

# ---- a project ------------------------------------------------------------------------------

e2x_write <- function(path, lines) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
  invisible(path)
}

e2x_git <- function(dir, ...) system2("git", c("-C", shQuote(dir), ...), stdout = TRUE, stderr = TRUE)

# a temporary project folder holding `_weft.yml`; a git repository (local identity only) when `git`;
# removed when the calling test ends
e2x_project <- function(git = TRUE, set_up = TRUE, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir <- normalizePath(dir, winslash = "/")
  if (set_up) e2x_write(file.path(dir, "_weft.yml"), "draft: false")
  if (git) {
    e2x_git(dir, "init", "-q")
    e2x_git(dir, "config", "user.name", "Test Writer")
    e2x_git(dir, "config", "user.email", "test@example.invalid")
    e2x_git(dir, "config", "commit.gpgsign", "false")
  }
  dir
}

e2x_commit <- function(dir, msg = "snapshot") {
  e2x_git(dir, "add", ".")
  e2x_git(dir, "commit", "-q", "--allow-empty", "-m", shQuote(msg))
  invisible(dir)
}

e2x_head <- function(dir) trimws(e2x_git(dir, "rev-parse", "HEAD"))

# write a ledger (and its condition log when `conds` is given) for `source`, and the source file
# itself unless `write_source` is FALSE; `entries` are e2x_entry() lists; `...` are header fields
e2x_put_ledger <- function(dir, source, entries = list(), output = sub("\\.[A-Za-z]+$", "", basename(source)),
                           conds = NULL, write_source = TRUE, ...) {
  base <- file.path(dir, "_weft", "ledger", source)
  e2x_write(file.path(base, paste0(output, ".jsonl")), e2x_ledger_lines(source, output, entries, ...))
  if (!is.null(conds)) {
    e2x_write(file.path(base, paste0(output, ".conditions.jsonl")), e2x_cond_lines(source, output, conds))
  }
  if (write_source && !file.exists(file.path(dir, source))) {
    e2x_write(file.path(dir, source), c("# a document", paste("source of", source)))
  }
  invisible(file.path(base, paste0(output, ".jsonl")))
}

# a project with one ledger for "a.qmd": `before` committed, then `after` written to the working tree;
# `dict_before`/`dict_after` are lines of dict.yml (NULL: none); returns the folder
e2x_scenario <- function(before, after, dict_before = NULL, dict_after = dict_before,
                         conds_before = NULL, conds_after = conds_before, source = "a.qmd",
                         env = parent.frame()) {
  dir <- e2x_project(env = env)
  if (!is.null(dict_before)) e2x_write(file.path(dir, "dict.yml"), dict_before)
  e2x_put_ledger(dir, source, before, conds = conds_before)
  e2x_commit(dir)
  if (!is.null(dict_after)) e2x_write(file.path(dir, "dict.yml"), dict_after)
  e2x_put_ledger(dir, source, after, conds = conds_after)
  dir
}

# the entries table of a one-pair scenario
e2x_rows <- function(before, after, ...) {
  dir <- e2x_scenario(list(before), list(after), ...)
  weft::changes(path = dir)$entries
}

e2x_print <- function(x) capture.output(print(x))

# the snapshot of a folder: relative paths (not .git), sizes, modification times
e2x_snapshot <- function(dir) {
  f <- sort(list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = FALSE))
  f <- f[!grepl("^\\.git/", f)]
  info <- file.info(file.path(dir, f))
  data.frame(path = f, size = info$size, mtime = as.numeric(info$mtime), stringsAsFactors = FALSE)
}

# ---- hashes (P14), computed here so the fixtures do not depend on 2e-1 --------------------------

e2x_file_hash <- function(path) {
  b <- readBin(path, "raw", file.size(path))
  b <- b[!(b == as.raw(13L) & c(b[-1L], as.raw(0L)) == as.raw(10L))]
  cli::hash_raw_xxhash64(b)
}

E2X_DOC_FIELDS <- c("definition", "decision", "why", "term", "avoid")
e2x_dict_hashes <- function(path) {
  y <- yaml::read_yaml(path)
  srt <- function(x) if (is.list(x) && !is.null(names(x))) lapply(x[order(names(x), method = "radix")], srt) else x
  vapply(y, function(e) {
    e <- srt(e[setdiff(names(e), E2X_DOC_FIELDS)])
    cli::hash_raw_xxhash64(charToRaw(enc2utf8(as.character(jsonlite::toJSON(e, auto_unbox = TRUE, digits = NA)))))
  }, "")
}

# a header as the reader gives it (the `header` attribute), from header fields
e2x_header <- function(source = "doc.qmd", output = "doc", ...) {
  attr(weft:::read_ledger(lines = e2x_ledger_lines(source, output, list(), ...)), "header")
}

E2X_DICT <- c("a: {value: 1, type: number, definition: \"The first.\"}",
              "b: {value: 2, type: number, definition: \"The second.\"}")

# a project holding doc.qmd and dict.yml for ledger_state() tests; no git needed
e2x_state_project <- function(env = parent.frame()) {
  dir <- e2x_project(git = FALSE, env = env)
  e2x_write(file.path(dir, "doc.qmd"), c("# A document", "", "Some words."))
  e2x_write(file.path(dir, "dict.yml"), E2X_DICT)
  dir
}
