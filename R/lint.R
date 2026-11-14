# The static lints (design-3): the entry point, the rule table, the findings
# structure and its printing, the lint configuration and the claim-word
# lexicon, and the `construct` lint.
#
# A rule is one row of `lint_rule_table()` (its id, spec, tier and scope) and one entry of
# `lint_rule_funs()` (its function: `(src, ctx)` for a file-scope rule, `(ctx)` for a
# project-scope one). Nothing is found by name; add both to add a rule.

lint_abort <- function(message) weft_abort(message, "weft_lint_error")

# ---- the rule table ------------------------------------------------------------------

# built once per session: findings are made by the thousand, each asking for the table
lint_rule_table <- function() {
  hit <- weft_env$lint_rule_table
  if (is.null(hit)) {
    hit <- lint_rule_table_build()
    weft_env$lint_rule_table <- hit
  }
  hit
}

lint_rule_table_build <- function() {
  r <- function(id, spec, tier, scope, what) {
    data.frame(id = id, spec = spec, tier = as.integer(tier), scope = scope, what = what,
               stringsAsFactors = FALSE)
  }
  do.call(rbind, list(
    r("numeral", "5.2.1", 1, "file", "A number typed in prose, a caption, front matter, a string or math."),
    r("construct", "5.3.1", 1, "file", "An error the scanner finds in a construct."),
    r("read", "5.1.3", 1, "file", "A file that is not UTF-8."),
    r("block-start", "2.10.5", 1, "file", "A line inside a span that starts a block."),
    r("lone-bar", "5.3.3", 2, "file", "A bracket with one `|` and no governor."),
    r("if-zero", "5.3.3", 2, "file", "An `if` condition that compares with 0."),
    r("name", "5.3.3", 2, "file", "A class or key that is not weft's, or is one edit from it."),
    r("inert-check", "3.1.6", 1, "file", "A check or condition with no variable in it."),
    r("long-guard", "3.1.9", 2, "file", "An `if` arm longer than `guard_words`."),
    r("cite-key", "5.4.1", 1, "file", "A key of a cite span not in the bibliography."),
    r("cite-bare", "5.4.2", 1, "file", "A bare cite key not written as a citation in its block."),
    r("citation-key", "5.4.3", 1, "file", "A citation key not in the bibliography."),
    r("claim-word", "5.5.1", 2, "file", "A claim word in a sentence."),
    r("literal-value", "5.6.1", 1, "file", "A value made only of constants."),
    r("value-constant", "5.6.2", 2, "file", "A numeric constant inside a value."),
    r("value-format", "5.6.4", 2, "file", "A value that rounds or formats in code."),
    r("xref", "5.7.1", 1, "project", "A cross-reference to no anchor."),
    r("anchor-twice", "5.7.1", 1, "project", "An anchor defined more than once."),
    r("ref-label", "5.7.1", 1, "file", "A span whose text is a reference-definition label."),
    r("anchor-unused", "5.7.2", 2, "project", "A figure, table or equation anchor nobody refers to."),
    r("xref-code", "5.7.2", 2, "file", "A cross-reference written inside a code span."),
    r("section-anchor", "5.8.1", 1, "file", "A heading with no `{#id}`."),
    r("chunk-label", "5.8.1", 1, "file", "An executed chunk with no label."),
    r("tar-name", "5.8.2", 1, "file", "A target read that the store does not hold."),
    r("dict-assign", "5.8.3", 1, "file", "An assignment to `dict`."),
    r("file-link", "5.8.4", 1, "file", "A link or image to a file that is not there."),
    r("above-setup", "5.8.5", 1, "file", "A construct above the chunk that calls weft_setup()."),
    r("dict-key", "5.8.6", 1, "file", "A `dict$key` read of a key that is not there."),
    r("tar-cache", "5.8.7", 1, "file", "A chunk that reads a target and caches."),
    r("config-place", "5.8.8", 1, "project", "A project setting in a place that is not the project's."),
    r("engine", "5.8.9", 1, "project", "A document with constructs that is not knitr's."),
    r("figure", "5.9.1", 1, "file", "A figure with no label, caption or alt text."),
    r("table-caption", "5.9.1", 1, "file", "A table with no caption."),
    r("guest-inline", "5.11.1", 1, "file", "Inline code in another language, which knitr does not run."),
    r("guest-call", "5.11.2", 1, "file", "A weft function called from Python through `r.`."),
    r("guest-read", "5.11.3", 2, "file", "A value read from Python or Julia that weft does not check."),
    r("ojs-value", "5.11.4", 2, "file", "An Observable value computed in the reader's browser."),
    r("named-unpublished", "5.12.1", 2, "file", "A name used by a named value or filter span that nothing publishes."),
    r("publish-hidden", "5.12.2", 1, "file", "A chunk that publishes values where its output is dropped.")))
}

#' The static lints
#'
#' `lint_rules()` lists every rule `lints()` knows, in order: its `id`, the
#' `spec` rule number, its `tier` (1 blocks, 2 is listed over added material),
#' its `scope` (`"file"` or `"project"`) and what it finds.
#'
#' @return A data frame with `id`, `spec`, `tier`, `scope` and `what`.
#' @export
lint_rules <- function() {
  r <- lint_rule_table()
  rownames(r) <- NULL
  r
}

# The function of each rule, in one explicit table: nothing is found by name. File-scope rules take
# (src, ctx), project-scope rules (ctx). `read` has none: the reader reports a file that is not UTF-8.
lint_rule_funs <- function() {
  list(
    `numeral` = lint_numeral,
    `construct` = lint_construct,
    read = NULL,
    `block-start` = lint_block_start,
    `lone-bar` = lint_lone_bar,
    `if-zero` = lint_if_zero,
    `name` = lint_name,
    `inert-check` = lint_inert_check,
    `long-guard` = lint_long_guard,
    `cite-key` = lint_cite_key,
    `cite-bare` = lint_cite_bare,
    `citation-key` = lint_citation_key,
    `claim-word` = lint_claim_word,
    `literal-value` = lint_literal_value,
    `value-constant` = lint_value_constant,
    `value-format` = lint_value_format,
    `xref` = lint_xref,
    `anchor-twice` = lint_anchor_twice,
    `ref-label` = lint_ref_label,
    `anchor-unused` = lint_anchor_unused,
    `xref-code` = lint_xref_code,
    `section-anchor` = lint_section_anchor,
    `chunk-label` = lint_chunk_label,
    `tar-name` = lint_tar_name,
    `dict-assign` = lint_dict_assign,
    `file-link` = lint_file_link,
    `above-setup` = lint_above_setup,
    `dict-key` = lint_dict_key,
    `tar-cache` = lint_tar_cache,
    `config-place` = lint_config_place,
    `engine` = lint_engine,
    `figure` = lint_figure,
    `table-caption` = lint_table_caption,
    `guest-inline` = lint_guest_inline,
    `guest-call` = lint_guest_call,
    `guest-read` = lint_guest_read,
    `ojs-value` = lint_ojs_value,
    `named-unpublished` = lint_named_unpublished,
    `publish-hidden` = lint_publish_hidden
  )
}

lint_rule_fun <- function(id) lint_rule_funs()[[id]]

# ---- findings --------------------------------------------------------------------------

# The columns of a weft_findings, in order (L5).
FINDING_COLS <- c("file", "line", "col", "end_line", "rule", "tier", "spec", "context", "text",
                  "message", "hint", "sentence")

# Build a weft_findings. `tier` and `spec` default to the rule table's. Every
# argument is recycled to the longest.
new_findings <- function(file = character(), line = integer(), col = 1L, end_line = line,
                         rule = character(), tier = NULL, spec = NULL, context = "prose",
                         text = "", message = "", hint = NA_character_,
                         sentence = NA_character_, notes = character()) {
  n <- max(length(file), length(line), length(rule), length(text), length(message))
  if (!length(file) || n == 0L) {
    n <- 0L
  }
  rec <- function(x, f) if (n == 0L) f(NULL) else rep_len(x, n)
  tab <- lint_rule_table()
  rl <- rec(rule, as.character)
  m <- match(rl, tab$id)
  out <- data.frame(
    file = rec(file, as.character), line = rec(as.integer(line), as.integer),
    col = rec(as.integer(col), as.integer), end_line = rec(as.integer(end_line), as.integer),
    rule = rl,
    tier = if (is.null(tier)) as.integer(tab$tier[m]) else rec(as.integer(tier), as.integer),
    spec = if (is.null(spec)) tab$spec[m] else rec(as.character(spec), as.character),
    context = rec(context, as.character), text = rec(text, as.character),
    message = rec(message, as.character), hint = rec(hint, as.character),
    sentence = rec(sentence, as.character), stringsAsFactors = FALSE)
  structure(out, class = c("weft_findings", "data.frame"), notes = as.character(notes))
}

# Findings for the offsets [start, end] of a source (the helper a rule uses).
finding_at <- function(src, start, end = start, rule, text, message, hint = NA_character_,
                       context = "prose", spec = NULL, tier = NULL, sentence = NA_character_) {
  new_findings(file = src$file, line = src_line_of(src, start), col = src_col_of(src, start),
               end_line = src_line_of(src, end), rule = rule, tier = tier, spec = spec,
               context = context, text = text, message = message, hint = hint,
               sentence = sentence)
}

bind_findings <- function(parts, notes = character()) {
  parts <- Filter(function(p) !is.null(p) && nrow(p) > 0L, parts)
  if (!length(parts)) return(new_findings(notes = notes))
  # column by column: `rbind` of thousands of small frames is the slow part
  cols <- lapply(FINDING_COLS, function(cn) unlist(lapply(parts, function(p) unclass(p)[[cn]]), use.names = FALSE))
  names(cols) <- FINDING_COLS
  out <- as.data.frame(cols, stringsAsFactors = FALSE, optional = TRUE)
  structure(out, class = c("weft_findings", "data.frame"), notes = as.character(notes))
}

# Findings (or the plain frame of them) by file, line, column and rule, with the row names reset.
sort_findings <- function(x) {
  x <- x[order(enc2utf8(x$file), x$line, x$col, x$rule, method = "radix"), , drop = FALSE]
  rownames(x) <- NULL
  x
}

finish_findings <- function(x, notes, n_files) {
  if (nrow(x)) {
    x <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
    x <- x[!duplicated(x[, c("file", "line", "col", "rule", "text", "message")]), , drop = FALSE]
    x <- sort_findings(x)
    x <- structure(x, class = c("weft_findings", "data.frame"))
  }
  attr(x, "notes") <- unique(as.character(notes))
  attr(x, "n_files") <- as.integer(n_files)
  x
}

ascii_escape <- function(x) {
  vapply(x, function(s) {
    if (is.na(s) || !grepl("[^\\x01-\\x7F]", s, perl = TRUE)) return(s)
    ch <- strsplit(s, "")[[1L]]
    cp <- utf8ToInt(s)
    bad <- cp > 127L
    ch[bad] <- ifelse(cp[bad] > 65535L, sprintf("\\U%08x", cp[bad]), sprintf("\\u%04x", cp[bad]))
    paste(ch, collapse = "")
  }, "", USE.NAMES = FALSE)
}

#' @param x A `weft_findings`.
#' @param max The most findings printed.
#' @param ... Not used.
#' @rdname lints
#' @export
print.weft_findings <- function(x, max = 200, ...) {
  n <- nrow(x)
  nf <- attr(x, "n_files")
  plural <- function(k, w) paste0(k, " ", w, if (k == 1L) "" else "s")
  if (n == 0L) {
    if (is.null(nf)) nf <- 0L
    cat(sprintf("weft lints: no findings in %s.\n", plural(nf, "file")))
  } else {
    files <- unique(x$file)
    cat(sprintf("weft lints: %s in %s (%d tier 1, %d tier 2)\n", plural(n, "finding"),
                plural(length(files), "file"), sum(x$tier == 1L), sum(x$tier == 2L)))
    shown <- utils::head(seq_len(n), max)
    f <- as.data.frame(unclass(x), stringsAsFactors = FALSE)[shown, , drop = FALSE]
    for (file in unique(f$file)) {
      d <- f[f$file == file, , drop = FALSE]
      pos <- paste0(d$line, ":", d$col)
      wp <- max(nchar(pos))
      wr <- max(nchar(d$rule))
      cat("\n", ascii_escape(file), "\n", sep = "")
      pad <- strrep(" ", 2L + wp + 2L + wr + 2L)
      for (i in seq_len(nrow(d))) {
        msg <- d$message[i]
        more <- NULL
        mm <- regmatches(msg, regexec("^(.*\\(rule [0-9.]+\\))[;.,][ ]+(.+)$", msg))[[1L]]
        if (length(mm)) {
          msg <- paste0(mm[2L], ".")
          more <- mm[3L]
        }
        cat(ascii_escape(sprintf("  %-*s  %-*s  %s", wp, pos[i], wr, d$rule[i], msg)), "\n", sep = "")
        if (!is.null(more)) cat(pad, ascii_escape(more), "\n", sep = "")
        if (!is.null(d$hint) && !is.na(d$hint[i])) cat(pad, ascii_escape(d$hint[i]), "\n", sep = "")
        if (!is.null(d$sentence) && !is.na(d$sentence[i])) cat(pad, ascii_escape(paste0("\"", d$sentence[i], "\"")), "\n", sep = "")
      }
    }
    if (n > length(shown)) {
      cat(sprintf("... and %d more finding%s.\n", n - length(shown), if (n - length(shown) == 1L) "" else "s"))
    }
  }
  notes <- attr(x, "notes")
  if (length(notes)) {
    cat("\nNotes:\n")
    for (m in notes) cat("  ", ascii_escape(m), "\n", sep = "")
  }
  invisible(x)
}

# ---- configuration (L4, L8a) ---------------------------------------------------------------

# The settings of one document: `_weft.yml` under the front matter's `weft:`,
# read as YAML only (no units are installed).
lint_config <- function(root, front = list()) {
  cfg <- default_config()
  file <- file.path(root, "_weft.yml")
  proj <- list()
  raw <- NULL
  if (file.exists(file)) {
    ws <- read_weft_yml(file)
    proj <- ws$proj
    raw <- ws$raw
    check_raw_scalars(raw)
  }
  w <- if (is.list(front)) front$weft else NULL
  if (!is.list(w)) w <- list()
  for (nm in c("units", "dict_local")) {
    proj[[nm]] <- NULL
    w[[nm]] <- NULL
  }
  if (length(w) && (is.null(names(w)) || any(!nzchar(names(w))))) {
    weft_abort("The `weft:` front-matter key must be a mapping of settings.", "weft_config_error")
  }
  cfg <- merge_config(cfg, proj)
  cfg <- merge_config(cfg, w)
  cfg$formatters <- check_formatters(cfg$formatters)
  validate_lint_config(cfg, raw)
  cfg
}

lexicon_cache <- new.env(parent = emptyenv())

# The claim words for a document language (L8a).
claim_lexicon <- function(cfg = default_config(), lang = NA_character_) {
  shipped <- character()
  english <- is.null(lang) || length(lang) != 1L || is.na(lang) || !nzchar(lang) ||
    grepl("^(en|eng)([-_]|$)", lang, ignore.case = TRUE)
  if (english) {
    if (is.null(lexicon_cache$words)) {
      p <- system.file("weft-claim-words.yml", package = "weft")
      y <- yaml_read_file(p)
      lexicon_cache$words <- tolower(unlist(y, use.names = FALSE))
    }
    shipped <- lexicon_cache$words
  }
  cw <- cfg$claim_words
  add <- as.character(unlist(cw$add))
  drop <- as.character(unlist(cw$drop))
  setdiff(unique(c(shipped, add)), drop)
}

# ---- the project's documents --------------------------------------------------------------------

# The documents the lints read: `underscore = TRUE` gives only the documents in
# `_` folders (includes, partials), which are read for anchors but not linted.
lint_files_under <- function(root, ext = DOC_EXT_RE, underscore = FALSE) {
  project_doc_paths(root, if (underscore) "anchors" else "lint", ext)
}

# The folder whose `_weft.yml` governs a document: the innermost one from the
# document's folder up to `root`, as in the gate (review 4, #7); `root` when
# none lies below it.
settings_root <- function(root, rel) {
  d <- dirname(rel)
  while (!identical(d, ".") && nzchar(d)) {
    if (file.exists(file.path(root, d, "_weft.yml"))) return(file.path(root, d))
    d <- dirname(d)
  }
  root
}

# The front matter of a file, read cheaply (for its `weft:` settings).
doc_front <- function(path) {
  text <- read_source_text_or_null(path)
  if (is.null(text) || !nzchar(text)) return(list())
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  mb <- metadata_blocks(lines)
  front <- list()
  for (b in seq_len(nrow(mb))) {
    if (mb$close[b] - mb$open[b] < 2L) next
    y <- yaml_text(paste(lines[(mb$open[b] + 1L):(mb$close[b] - 1L)], collapse = "\n"))
    if (is.list(y) && !is.null(names(y))) front[names(y)] <- y
  }
  front
}

# Each file's source comes through here, so a cache can stand in (stage 4's
# `weft_env$lint_reader`).
lint_read <- function(path, root, cfg) {
  (weft_env$lint_reader %||% read_source)(path, root, cfg)
}

# One document, read with its own settings.
lint_open <- function(root, rel) {
  path <- file.path(root, rel)
  cfg <- lint_config(settings_root(root, rel), doc_front(path))
  lint_read(path, root, cfg)
}

new_lint_ctx <- function(root, files, md_files, report, tier, rules, reader) {
  ctx <- new.env(parent = emptyenv())
  ctx$root <- root
  ctx$files <- files
  ctx$md_files <- md_files
  ctx$report <- report
  ctx$tier <- tier
  ctx$rules <- rules
  ctx$reader <- reader
  ctx$notes <- character()
  ctx$include_files <- lint_files_under(root, underscore = TRUE)
  cache <- new.env(parent = emptyenv())
  ctx$source <- function(rel) {
    if (is.null(cache[[rel]])) cache[[rel]] <- lint_open(root, rel)
    cache[[rel]]
  }
  ctx$note <- function(msg) ctx$notes <- c(ctx$notes, msg)
  ctx$path <- function(rel) file.path(root, rel)
  class(ctx) <- "weft_lint_ctx"
  ctx
}

#' Lint a project's documents without running them
#'
#' Reads `.qmd` and `.Rmd` documents as text and returns the typed numbers,
#' construct errors and other problems the rules of [lint_rules()] find.
#' Nothing in a document is run.
#'
#' @param path One existing file or folder. The project root is found from it.
#' @param files `NULL`, or documents (relative to the root or absolute under it)
#'   to report on. File-scope rules run on these only; project-scope rules
#'   still read every document.
#' @param rules `NULL` (every rule of the tiers asked for), or ids from
#'   [lint_rules()].
#' @param tier A subset of `1:2`. The default is tier 1.
#' @param reader `"weft"` (the default) or `"pandoc"`.
#' @return A `weft_findings` data frame sorted by file, line, column and rule,
#'   with columns `file`, `line`, `col`, `end_line`, `rule`, `tier`, `spec`,
#'   `context`, `text`, `message`, `hint` and `sentence`, and the attribute
#'   `notes`.
#' @export
lints <- function(path = ".", files = NULL, rules = NULL, tier = 1, reader = c("weft", "pandoc")) {
  tier_given <- !missing(tier)
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    lint_abort("`path` must be one existing file or folder (rule 5.1.1).")
  }
  if (identical(reader, c("weft", "pandoc"))) reader <- "weft"
  if (!is.character(reader) || length(reader) != 1L || !reader %in% c("weft", "pandoc")) {
    lint_abort("`reader` must be \"weft\" or \"pandoc\" (rule 2.10.3).")
  }
  if (!is.numeric(tier) || !length(tier) || anyNA(tier) || !all(tier %in% 1:2)) {
    lint_abort("`tier` must be 1, 2 or both (rule 5.1.2).")
  }
  tab <- lint_rule_table()
  if (!is.null(rules)) {
    if (!is.character(rules) || anyNA(rules)) lint_abort("`rules` must be rule ids from `lint_rules()$id`.")
    bad <- setdiff(rules, tab$id)
    if (length(bad)) {
      lint_abort(paste0("Unknown rule", if (length(bad) > 1L) "s" else "", ": ",
                        paste0("`", bad, "`", vapply(bad, function(b) {
                          d <- did_you_mean(b, tab$id)
                          if (nzchar(d)) paste0(";", d) else ""
                        }, ""), collapse = "; "),
                        " (rule 5.1.1)."))
    }
  }
  # a rule named in `rules` runs whatever its tier when `tier` is not given (review 3, finding 9)
  skipped <- character()
  if (!is.null(rules)) {
    if (!tier_given) {
      tier <- sort(unique(tab$tier[tab$id %in% rules]))
    } else {
      skipped <- rules[!rules %in% tab$id[tab$tier %in% tier]]
    }
  }
  if (reader == "pandoc") {
    pp <- pandoc_path()
    if (!nzchar(pp)) {
      lint_abort(paste0("lints(reader = \"pandoc\") needs Pandoc; none was found. ",
                        "Set the option `weft.pandoc` to its path (rule 2.10.3)."))
    }
  }
  full <- normalizePath(path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(find_project_root(full), winslash = "/", mustWork = FALSE)
  all_files <- lint_files_under(root)
  # files to report on
  files_rel <- NULL
  if (!is.null(files)) {
    if (!is.character(files) || anyNA(files)) lint_abort("`files` must be paths to .qmd or .Rmd documents.")
    absf <- ifelse(grepl("^(/|[A-Za-z]:)", files), files, file.path(root, files))
    nf <- normalizePath(absf, winslash = "/", mustWork = FALSE)
    prob <- !file.exists(absf) | !startsWith(nf, paste0(root, "/")) | !grepl("\\.(qmd|Rmd|rmd)$", files)
    if (any(prob)) {
      lint_abort(paste0("`files` must name existing .qmd or .Rmd documents under the project root; not so: ",
                        paste0("`", files[prob], "`", collapse = ", "), " (rule 5.1.1)."))
    }
    files_rel <- rel_to(nf, root)
  }
  report <- lint_report_under(all_files, full, root)
  if (!is.null(files_rel)) report <- intersect(report, files_rel)
  sel <- tab[tab$tier %in% tier & (is.null(rules) | tab$id %in% rules), , drop = FALSE]
  notes <- if (length(skipped)) {
    sprintf("Not run, because its tier is not in `tier`: %s (rule 5.1.2).",
            paste0("`", skipped, "`", collapse = ", "))
  } else {
    character()
  }
  pre <- paste0(rel_to(full, root), "/")
  keep_project <- function(f) {
    f %in% report | (is.null(files_rel) & dir.exists(full) & (identical(full, root) | startsWith(f, pre)))
  }
  lint_run(root, all_files, report, sel, tier, rules, reader, notes = notes, keep_project = keep_project)
}

# The documents of `all_files` that `path` (a folder or a file, normalised, inside `root`) covers.
lint_report_under <- function(all_files, full, root) {
  if (!dir.exists(full)) return(intersect(all_files, rel_to(full, root)))
  if (identical(full, root)) return(all_files)
  pre <- paste0(rel_to(full, root), "/")
  all_files[startsWith(all_files, pre)]
}

# Run the rules of `sel` (rows of the rule table) over a project: each file-scope rule on the documents of
# `file_report`, each project-scope rule once, keeping the findings whose file `keep_project` accepts (all of
# them when it is NULL). Every document of `report` is opened. Returns the findings, with the notes.
lint_run <- function(root, all_files, report, sel, tier, rules, reader, notes = character(),
                     file_report = report, keep_project = NULL) {
  md_files <- lint_files_under(root, "\\.md$")
  ctx <- new_lint_ctx(root, all_files, md_files, report, tier, rules, reader)
  for (m in notes) ctx$note(m)
  parts <- list()
  for (rel in report) {
    src <- ctx$source(rel)
    if (!rel %in% file_report) next
    if (isTRUE(src$invalid)) {
      if ("read" %in% sel$id) {
        parts[[length(parts) + 1L]] <- new_findings(
          file = rel, line = 1L, col = 1L, rule = "read", context = "project", text = rel,
          message = sprintf("%s is not valid UTF-8; save the file as UTF-8 (rule 5.1.3).", rel),
          hint = "Save the file as UTF-8.")
      }
      next
    }
    for (i in which(sel$scope == "file")) {
      fn <- lint_rule_fun(sel$id[i])
      if (is.null(fn)) next
      parts[[length(parts) + 1L]] <- fn(src, ctx)
    }
  }
  for (i in which(sel$scope == "project")) {
    fn <- lint_rule_fun(sel$id[i])
    if (is.null(fn)) next
    res <- fn(ctx)
    if (!is.null(res) && nrow(res)) {
      if (!is.null(keep_project)) res <- res[keep_project(res$file), , drop = FALSE]
      parts[[length(parts) + 1L]] <- res
    }
  }
  out <- bind_findings(parts)
  if (nrow(out)) out <- out[out$tier %in% tier, , drop = FALSE]
  finish_findings(out, ctx$notes, length(report))
}

# ---- construct (L17) --------------------------------------------------------------------------------

lint_construct <- function(src, ctx) {
  r <- src$rows
  e <- which(!is.na(r$error))
  if (!length(e)) return(new_findings())
  parts <- lapply(e, function(i) {
    msgs <- strsplit(r$error[i], "\n", fixed = TRUE)[[1L]]
    msgs <- msgs[nzchar(msgs)]
    spec <- vapply(msgs, function(m) {
      mm <- regmatches(m, regexpr("rules? [0-9]+(\\.[0-9]+)+", m))
      if (length(mm)) sub("^rules? ", "", mm) else "5.3.1"
    }, "", USE.NAMES = FALSE)
    s <- r$fstart[i]
    en <- r$fend[i]
    txt <- src_substr(src, s, en)
    if (nchar(txt) > 80L) txt <- substr(txt, 1L, 80L)
    new_findings(file = src$file, line = src_line_of(src, s), col = src_col_of(src, s),
                 end_line = src_line_of(src, en), rule = "construct", spec = spec,
                 context = r$context[i], text = txt, message = msgs)
  })
  bind_findings(parts)
}
