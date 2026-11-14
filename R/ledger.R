# The ledger and the condition log (rules 7.1, 7.4; dev/design-2d.md D1-D30).
# One JSON-lines file per source and output holds an entry for each construct
# the knit evaluated; a second holds one line per distinct condition. Both are
# committed, so their bytes are fixed: weft writes them itself (D3, G14).
# Nothing here is exported (D29).

LEDGER_VERSION <- 1L
LEDGER_KINDS <- c("value", "bare", "n", "if", "sign", "list", "cite")
LEDGER_COLS <- c("file", "section", "kind", "expr", "occ", "id", "context", "text",
                 "arm", "rel", "raw", "unit", "failed", "dict", "sentence")
CONDITION_COLS <- c("from", "source", "class", "normalised", "text")
# the invisible characters D3 writes as escapes
JSON_INVISIBLE <- c(0x0085L, 0x00a0L, 0x00adL, 0x061cL, 0x2000L:0x200fL, 0x2028L:0x202eL, 0x202fL,
                    0x205fL, 0x2060L, 0x2066L:0x2069L, 0xfeffL)

ledger_warn <- function(msg) {
  weft_warn(msg, class = c("weft_ledger_warning", "weft_warning"))
}

# ---- the writer (D3) --------------------------------------------------------

json_esc_cp <- function(cp) {
  switch(as.character(cp),
         `34` = "\\\"", `92` = "\\\\", `10` = "\\n", `9` = "\\t", `13` = "\\r",
         sprintf("\\u%04x", cp))
}

# A JSON string: UTF-8 as itself, with the characters D3 names escaped.
json_str <- function(x) {
  x <- enc2utf8(as.character(x)[1L])
  if (!validUTF8(x)) x <- iconv(x, "UTF-8", "UTF-8", sub = "\ufffd")
  cps <- utf8ToInt(x)
  if (!length(cps)) return("\"\"")
  ch <- intToUtf8(cps, multiple = TRUE)
  hit <- cps < 32L | cps == 34L | cps == 92L | cps %in% JSON_INVISIBLE
  if (any(hit)) ch[hit] <- vapply(cps[hit], json_esc_cp, "")
  paste0("\"", paste(ch, collapse = ""), "\"")
}

json_nul <- function(x, f) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) "null" else f(x[[1L]])
}

# D11: six significant figures, as formatC(digits = 6, format = "g") prints.
json_num <- function(x) {
  x <- as.numeric(x)
  if (x == 0) return("0")
  trimws(formatC(x, digits = 6L, format = "g"))
}

# Any value, for the extra header fields 2e adds.
json_value <- function(x) {
  if (is.null(x)) return("null")
  if (is.list(x)) {
    if (!is.null(names(x))) {
      # an object: names sorted byte by byte, `{}` when empty
      if (!length(x)) return("{}")
      x <- x[order(names(x), method = "radix")]
      return(paste0("{", paste(paste0(vapply(names(x), json_str, ""), ":", vapply(x, json_value, "")),
                               collapse = ","), "}"))
    }
    return(paste0("[", paste(vapply(x, json_value, ""), collapse = ","), "]"))
  }
  one <- function(v) {
    if (is.na(v)) "null" else if (is.logical(v)) tolower(as.character(v)) else
      if (is.numeric(v)) json_num(v) else json_str(v)
  }
  if (length(x) == 1L) one(x) else paste0("[", paste(vapply(x, one, ""), collapse = ","), "]")
}

ledger_header_line <- function(kind, source, output, extra = NULL) {
  base <- sprintf("{\"weft\":%s,\"version\":%d,\"source\":%s,\"output\":%s", json_str(kind),
                  LEDGER_VERSION, json_str(source), json_str(output))
  if (length(extra)) {
    extra <- extra[order(names(extra), method = "radix")]
    base <- paste0(base, ",", paste(paste0(vapply(names(extra), json_str, ""), ":", vapply(extra, json_value, "")),
                                    collapse = ","))
  }
  paste0(base, "}")
}

ledger_entry_line <- function(e) {
  paste0("{\"file\":", json_str(e$file),
         ",\"section\":", json_str(e$section),
         ",\"kind\":", json_str(e$kind),
         ",\"expr\":", json_str(e$expr),
         ",\"occ\":", as.integer(e$occ),
         ",\"id\":", json_nul(e$id, json_str),
         ",\"context\":", json_str(e$context),
         ",\"text\":", json_nul(e$text, json_str),
         ",\"arm\":", json_nul(e$arm, json_str),
         ",\"rel\":", json_nul(e$rel, json_str),
         ",\"raw\":", json_nul(e$raw, json_num),
         ",\"unit\":", json_nul(if (is.null(e$raw) || is.na(e$raw)) NULL else e$unit, json_str),
         ",\"failed\":", json_nul(e$failed, json_str),
         ",\"dict\":[", paste(vapply(as.character(e$dict), json_str, ""), collapse = ","), "]",
         ",\"sentence\":", json_str(e$sentence), "}")
}

condition_line <- function(r) {
  paste0("{\"from\":", json_str(r$from), ",\"source\":", json_str(r$source),
         ",\"class\":", json_str(r$class), ",\"normalised\":", json_str(r$normalised),
         ",\"text\":", json_str(r$text), "}")
}

# ---- the readers (D27) ------------------------------------------------------

chr1 <- function(x) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) NA_character_ else as.character(x[[1L]])
}

ledger_df <- function(es, header = list()) {
  gc <- function(f) vapply(es, function(e) chr1(e[[f]]), "")
  df <- data.frame(file = gc("file"), section = gc("section"), kind = gc("kind"),
                   expr = gc("expr"),
                   occ = vapply(es, function(e) if (is.null(e[["occ"]])) NA_integer_ else
                     as.integer(e[["occ"]]), 1L),
                   id = gc("id"), context = gc("context"), text = gc("text"), arm = gc("arm"),
                   rel = gc("rel"),
                   raw = vapply(es, function(e) if (is.null(e[["raw"]]) || is.na(e[["raw"]])) NA_real_ else
                     as.numeric(e[["raw"]]), 1),
                   unit = gc("unit"),
                   failed = gc("failed"), dict = I(vector("list", length(es))),
                   sentence = gc("sentence"), stringsAsFactors = FALSE)
  df$dict <- lapply(es, function(e) as.character(unlist(e[["dict"]])))
  class(df) <- c("weft_ledger", "data.frame")
  attr(df, "header") <- header
  df
}

condition_df <- function(rs, header = list()) {
  gc <- function(f) vapply(rs, function(e) chr1(e[[f]]), "")
  df <- data.frame(from = gc("from"), source = gc("source"), class = gc("class"),
                   normalised = gc("normalised"), text = gc("text"), stringsAsFactors = FALSE)
  class(df) <- c("weft_condition_log", "data.frame")
  attr(df, "header") <- header
  df
}

# The objects on the lines of a file. Strict: the first line is the header
# `kind` names, its version is not above 1, and every line is a JSON object.
# Lenient (D18): lines that are not objects are skipped, a missing header is
# accepted, and the header is returned as it stands (the caller judges its
# version).
parse_jsonl <- function(lines, kind, lenient = FALSE, what = "the file") {
  header <- list()
  objs <- list()
  seen <- 0L
  for (i in seq_along(lines)) {
    l <- lines[i]
    if (!nzchar(trimws(l))) next
    obj <- tryCatch(jsonlite::fromJSON(l, simplifyVector = FALSE), error = function(e) NULL)
    ok <- is.list(obj) && (length(obj) == 0L || !is.null(names(obj)))
    if (!ok) {
      if (lenient) next
      weft_abort(sprintf("weft: line %d of %s is not a JSON object (rule 7.1.5).", i, what),
                 "weft_ledger_error")
    }
    seen <- seen + 1L
    if (seen == 1L) {
      if (!is.null(obj[["weft"]])) {
        if (!identical(obj[["weft"]], kind) && !lenient) {
          weft_abort(sprintf("weft: line %d of %s is a `%s` header, not a `%s` one (rule 7.1.5).",
                             i, what, obj[["weft"]], kind), "weft_ledger_error")
        }
        v <- suppressWarnings(as.numeric(obj[["version"]]))
        if (!lenient && length(v) == 1L && !is.na(v) && v > LEDGER_VERSION) {
          weft_abort(sprintf("weft: %s is version %s, and this weft reads up to version %d (rule 7.1.5).",
                             what, v, LEDGER_VERSION), "weft_ledger_error")
        }
        header <- obj
        next
      }
      if (!lenient) {
        weft_abort(sprintf("weft: line %d of %s is not a `%s` header (rule 7.1.5).", i, what, kind),
                   "weft_ledger_error")
      }
    }
    if (!lenient && !is.null(obj[["weft"]])) next
    objs[[length(objs) + 1L]] <- obj
  }
  if (!lenient && seen == 0L) {
    weft_abort(sprintf("weft: %s is empty; a `%s` file starts with its header (rule 7.1.5).", what, kind),
               "weft_ledger_error")
  }
  list(header = header, objs = objs)
}

read_ledger <- function(file = NULL, lines = NULL, lenient = FALSE) {
  what <- if (!is.null(file)) file else "the ledger"
  if (is.null(lines)) lines <- read_source_lines(file)
  p <- parse_jsonl(lines, "ledger", lenient, what)
  ledger_df(p$objs, p$header)
}

read_condition_log <- function(file = NULL, lines = NULL, lenient = FALSE) {
  what <- if (!is.null(file)) file else "the condition log"
  if (is.null(lines)) lines <- read_source_lines(file)
  p <- parse_jsonl(lines, "conditions", lenient, what)
  condition_df(p$objs, p$header)
}

ledger_paths <- function(root, source, output) {
  d <- paste("_weft", "ledger", source, sep = "/")
  c(ledger = paste0(d, "/", output, ".jsonl"),
    conditions = paste0(d, "/", output, ".conditions.jsonl"))
}

# ---- git (D19) --------------------------------------------------------------

git_in_work_tree <- function(root) {
  identical(git_lines(root, c("rev-parse", "--is-inside-work-tree")), "true")
}

# The lines of `path` (relative to `root`) at `rev`, or NULL: no git, no work
# tree, or not in the revision.
git_show <- function(root, path, rev = "HEAD") {
  git_lines(root, c("show", paste0(rev, ":./", path)))
}

# ---- expressions (D9) ---------------------------------------------------------

# The ledger key of an expression (D9). A named value's key is its NAME as written (N149), so it is not
# parsed; a filter span's is its governor value with runs of spaces made one, unparsed (`unparsed`).
expr_key <- function(code, unparsed = FALSE) {
  code <- trimws(as.character(code)[1L])
  if (unparsed) return(gsub("[ \t\r\n]+", " ", code))
  if (is_backref(code) || identical(code, ".")) return(code)
  e <- tryCatch(parse(text = code, keep.source = FALSE), error = function(err) NULL)
  if (is.null(e)) return(gsub("[ \t\r\n]+", " ", code))
  paste(vapply(e, function(x) paste(trimws(deparse(x, width.cutoff = 500L)), collapse = " "), ""),
        collapse = "; ")
}

collapse_ws <- function(x) trimws(gsub("[ \t\r\n]+", " ", x))

# The dictionary entries an expression names (D8): `dict$key` and
# `dict_local$key`, `dict[["key"]]` written the same way, unique and sorted.
dict_refs <- function(code) {
  e <- tryCatch(parse(text = code, keep.source = FALSE), error = function(err) NULL)
  if (is.null(e)) {
    e <- tryCatch(parse(text = paste0("list(", code, ")"), keep.source = FALSE),
                  error = function(err) NULL)
  }
  if (is.null(e)) return(character())
  out <- character()
  walk <- function(x) {
    if (!is.call(x)) return(invisible())
    f <- x[[1L]]
    if (is.symbol(f) && as.character(f) %in% c("$", "[[") && length(x) >= 3L &&
        is.symbol(x[[2L]]) && as.character(x[[2L]]) %in% c("dict", "dict_local")) {
      key <- x[[3L]]
      key <- if (is.symbol(key)) as.character(key) else if (is.character(key)) key else NULL
      if (!is.null(key) && length(key) == 1L) {
        out <<- c(out, paste0(as.character(x[[2L]]), "$", key))
      }
    }
    for (a in as.list(x)) if (!missing(a)) walk(a)
  }
  for (x in e) walk(x)
  sort(unique(out), method = "radix")
}

# D11: the raw number of a value, rounded to six significant figures, or NA.
ledger_raw <- function(v) {
  if (inherits(v, "weft_text")) {
    v <- attr(v, "raw")
    if (!(is.numeric(v) && length(v) == 1L)) return(NA_real_)
  }
  if (is.null(v) || is.logical(v) || !is.numeric(v) || length(v) != 1L) return(NA_real_)
  if (inherits(v, "integer64")) {
    # a double holds it exactly, or there is no raw
    x <- tryCatch(as.double(v), error = function(e) NA_real_)
    if (length(x) != 1L || !is.finite(x) || !identical(as.character(v), sprintf("%.0f", x))) return(NA_real_)
  } else {
    x <- tryCatch(as.numeric(unclass(v)), error = function(e) NA_real_)
  }
  if (length(x) != 1L || !is.finite(x)) return(NA_real_)
  if (x == 0) return(0)
  as.numeric(formatC(x, digits = 6L, format = "g"))
}

# D8 (amended): the unit the raw number is in, as units::deparse_unit() writes it,
# or NA for a plain number.
ledger_unit <- function(v) {
  un <- if (inherits(v, c("units", "weft_text"))) attr(v, "units") else NULL
  if (is.null(un)) return(NA_character_)
  tryCatch({
    q <- if (inherits(v, "units")) v else units::set_units(1, un, mode = "standard")
    u <- units::deparse_unit(q)
    if (length(u) == 1L && !is.na(u) && nzchar(u) && u != "1") u else NA_character_
  }, error = function(e) NA_character_)
}

# The relation of a printed record (D8), or NA.
ledger_rel <- function(rec) {
  if (!inherits(rec, "weft_text") || length(rec) != 1L) return(NA_character_)
  r <- attr(rec, "relation")[1L]
  if (is.character(r) && !is.na(r) && r %in% c("=", "<", ">")) r else NA_character_
}

# The role of arm `i` of a governed span of `kind` with `narms` arms (D8).
ledger_arm <- function(kind, narms, i) {
  if (is.na(i)) return(NA_character_)
  roles <- arm_roles(kind, narms)
  if (!is.null(roles) && i <= length(roles)) roles[i] else as.character(i)
}

# ---- where a construct is (D1, D10) --------------------------------------------

ledger_root <- function(s) {
  if (is.null(s$ledger_root)) s$ledger_root <- state_root(s)
  s$ledger_root
}

# The state of the file that holds the text knitted by a child from a string:
# the nearest file on the stack.
ledger_base_state <- function(s) {
  for (k in rev(seq_along(s$stack))) {
    st <- s$stack[[k]]
    if (!isTRUE(st$text) && !is.null(st$path)) {
      F <- s$files[[st$path]]
      if (!is.null(F)) return(F)
    }
  }
  if (!is.na(s$input_path)) s$files[[s$input_path]] else NULL
}

# A file name as the knit knows it, as a path relative to the root with `/`.
ledger_file <- function(s, F, name) {
  key <- paste(F$path, name, sep = "\r")
  if (is.null(s$file_rel)) s$file_rel <- new.env(parent = emptyenv())
  hit <- s$file_rel[[key]]
  if (!is.null(hit)) return(hit)
  root <- ledger_root(s)
  full <- normalizePath(file.path(dirname(F$path), name), winslash = "/", mustWork = FALSE)
  # the author's own file, where rmarkdown knitted a copy (D1)
  if (identical(F$path, s$input_path) && identical(name, F$name) && !grepl("\\.rmarkdown$", F$path)) {
    full <- state_input(s)
  }
  pre <- if (is.na(root)) "" else paste0(sub("/+$", "", root), "/")
  out <- enc2utf8(if (nzchar(pre) && startsWith(full, pre)) substring(full, nchar(pre) + 1L) else name)
  assign(key, out, envir = s$file_rel)
  out
}

# The file and section of a place: a line of the text knitr read, or, where
# there is none (a caption, a string, text knitted by a child), the line the
# chunk starts on.
ledger_where <- function(s, F = NULL, name = NA_character_, view_line = NA_integer_,
                         chunk = NA_character_) {
  Fx <- F
  if (is.null(Fx)) Fx <- tryCatch(current_file_state(s), error = function(e) NULL)
  if (is.null(Fx)) Fx <- ledger_base_state(s)
  if (is.null(Fx)) {
    return(list(file = as.character(s$input_name %||% ""), section = "", front = FALSE))
  }
  use_line <- !is.null(F) && !is.na(view_line)
  file <- ledger_file(s, Fx, if (!is.null(F) && !is.na(name)) name else Fx$name)
  line <- if (use_line) view_line else {
    if (is.character(chunk) && length(chunk) == 1L && !is.na(chunk) && !is.null(Fx$chunk_lines)) {
      unname(Fx$chunk_lines[source_chunk_label(Fx, chunk)])
    } else NA_integer_
  }
  front <- use_line && in_front_matter(Fx, line)
  section <- if (is.na(line) || front) "" else anchor_at(Fx, line)
  list(file = file, section = section, front = front)
}

# The source of a condition from prose or from an unlabelled chunk (D15).
where_label <- function(w) if (nzchar(w$section)) paste0(w$file, "#", w$section) else w$file

chunk_log_source <- function(s, label) {
  if (is.na(label) || !nzchar(label)) label <- NA_character_
  if (!is.na(label) && !grepl("^unnamed-chunk-[0-9]+$", label)) return(label)
  where_label(ledger_where(s, NULL, NA_character_, NA_integer_, label))
}

# ---- the output name (D2) ------------------------------------------------------

strip_ext <- function(x) sub("\\.[^.]*$", "", basename(x))

ledger_output_name <- function(s, warn = FALSE) {
  e <- Sys.getenv("WEFT_OUTPUT", "")
  if (nzchar(e)) return(strip_ext(e))
  info <- Sys.getenv("QUARTO_EXECUTE_INFO", "")
  quarto <- nzchar(info) && file.exists(info)
  # Quarto's knitr engine runs inside an rmarkdown::render() of its own, whose
  # output_file is not the document's, so under Quarto the execute info comes
  # first (D2 lists the render frame first for a plain rmarkdown render)
  if (!quarto) {
    of <- render_frame_value("output_file")
    if (is.character(of) && length(of) == 1L && !is.na(of) && nzchar(of)) return(strip_ext(of))
  }
  src <- strip_ext(if (is.na(s$input_path)) "document" else {
    root <- ledger_root(s)
    state_source(s, root)
  })
  if (quarto) {
    x <- tryCatch(json_read_file(info), error = function(e) NULL)
    of <- x$format$pandoc[["output-file"]]
    if (is.character(of) && length(of) == 1L && nzchar(of)) return(strip_ext(of))
    # Quarto gives no output-file for gfm and typst: the output is named after the source
    to <- unlist(c(x$format$identifier[["base-format"]], x$format$identifier[["target-format"]]))
    quiet <- any(grepl("^(gfm|typst)([-+]|$)", as.character(to)))
    if (warn && !quiet) {
      ledger_warn(sprintf(paste0(
        "weft: this render's output file is not visible to weft, so its ledger is named after the ",
        "source (%s) and renders to other outputs will overwrite it; set WEFT_OUTPUT to name the ",
        "ledger (its folder and extension are dropped) (rule 7.1.3)."), src))
    }
  }
  src
}

# ---- the entries of a knit -------------------------------------------------------

# The entries recorded by the knit, with their occurrence numbers, in key order (D13).
ledger_entries <- function(s) {
  es <- Filter(Negate(is.null), s$ledger)
  if (!length(es)) return(list())
  g <- function(f) enc2utf8(vapply(es, function(e) as.character(e[[f]]), ""))
  key <- paste(g("file"), g("section"), g("kind"), g("expr"), sep = "\r")
  occ <- as.integer(stats::ave(seq_along(key), key, FUN = seq_along))
  for (i in seq_along(es)) es[[i]]$occ <- occ[i]
  ord <- order(g("file"), g("section"), g("kind"), g("expr"), occ, method = "radix")
  es[ord]
}

cap_text <- function(x) {
  if (nchar(x) > 1000L) paste0(substr(x, 1L, 999L), "\u2026") else x
}

# The lines of the condition log (D15, D16): one per distinct key, the text
# carried forward from `prior`, sorted.
condition_rows <- function(s, prior = NULL) {
  rows <- list()
  for (cnd in s$conditions) {
    if (isTRUE(cnd$severe)) next
    rows[[length(rows) + 1L]] <- list(
      from = cnd$from %||% "chunk", source = cnd$lsource %||% cnd$source, class = cnd$class,
      normalised = cap_text(cnd$normalised),
      text = cap_text(sub("\n+$", "", gsub("\033\\[[0-9;?]*[A-Za-z]", "", cnd$text))))
  }
  extra <- s$condition_rows
  if (is.data.frame(extra)) extra <- lapply(seq_len(nrow(extra)), function(i) as.list(extra[i, ]))
  for (r in extra) {
    rows[[length(rows) + 1L]] <- list(from = as.character(r$from %||% "target"),
                                      source = as.character(r$source), class = as.character(r$class),
                                      normalised = cap_text(as.character(r$normalised)),
                                      text = cap_text(as.character(r$text)))
  }
  if (!length(rows)) return(list())
  g <- function(f) enc2utf8(vapply(rows, function(r) as.character(r[[f]]), ""))
  key <- paste(g("from"), g("source"), g("class"), g("normalised"), sep = "\r")
  keep <- !duplicated(key)
  rows <- rows[keep]
  key <- key[keep]
  # a line with no usable text supplies none (D18)
  if (!is.null(prior) && nrow(prior)) prior <- prior[!is.na(prior$text), , drop = FALSE]
  if (!is.null(prior) && nrow(prior)) {
    pk <- paste(prior$from, prior$source, prior$class, prior$normalised, sep = "\r")
    pk_first <- !duplicated(pk)
    for (i in seq_along(rows)) {
      j <- match(key[i], pk[pk_first])
      if (!is.na(j)) rows[[i]]$text <- prior$text[pk_first][j]
    }
  }
  g <- function(f) enc2utf8(vapply(rows, function(r) as.character(r[[f]]), ""))
  rows[order(g("from"), g("source"), g("class"), g("normalised"), method = "radix")]
}

# ---- writing (D6, D26) -------------------------------------------------------------

# Write `lines` to `path` unless the file already holds those bytes. Returns
# NULL, or the reason it failed.
write_whole_file <- function(path, lines) {
  bytes <- charToRaw(paste0(paste(enc2utf8(lines), collapse = "\n"), "\n"))
  # a warning from the file system is the reason, not a second condition (D26)
  reason <- NULL
  tryCatch(withCallingHandlers({
    write_atomic(path, bytes, skip_same = TRUE)
    NULL
  }, warning = function(w) {
    reason <<- sub("^cannot create dir '[^']*', reason '(.*)'$", "\\1",
                   sub("^cannot open file '[^']*': ", "", conditionMessage(w)))
    invokeRestart("muffleWarning")
  }), error = function(e) {
    m <- conditionMessage(e)
    if (is.null(reason)) m else if (grepl("^cannot create the folder", m)) paste0(m, ": ", reason) else reason
  })
}

# The first of the folders and files the writer would touch that is a symbolic
# link (D6), as its path, or NULL. `rel` are paths under `root`.
ledger_link_in <- function(root, rel) {
  for (r in rel) {
    parts <- strsplit(r, "/", fixed = TRUE)[[1L]]
    for (k in seq_along(parts)) {
      p <- file.path(root, paste(parts[seq_len(k)], collapse = "/"))
      lk <- suppressWarnings(Sys.readlink(p))
      if (!is.na(lk) && nzchar(lk)) return(p)
    }
  }
  NULL
}

# The prior condition log, read for D16, or NULL (absent, or a later version).
condition_prior <- function(path) {
  if (!file.exists(path) || dir.exists(path)) return(NULL)
  p <- tryCatch(read_condition_log(path, lenient = TRUE), error = function(e) NULL)
  if (is.null(p)) return(NULL)
  v <- suppressWarnings(as.numeric(attr(p, "header")$version))
  if (length(v) == 1L && !is.na(v) && v > LEDGER_VERSION) {
    ledger_warn(sprintf(paste0("weft: %s is version %s, newer than this weft reads; it is rewritten ",
                               "as version %d (rule 7.4.3)."), path, v, LEDGER_VERSION))
    return(NULL)
  }
  p
}

ledger_prior_version_check <- function(path) {
  if (!file.exists(path) || dir.exists(path)) return(invisible())
  l <- tryCatch(readLines(path, n = 1L, warn = FALSE), error = function(e) character())
  if (!length(l)) return(invisible())
  h <- tryCatch(jsonlite::fromJSON(l[1L], simplifyVector = FALSE), error = function(e) NULL)
  v <- suppressWarnings(as.numeric(h$version))
  if (length(v) == 1L && !is.na(v) && v > LEDGER_VERSION) {
    ledger_warn(sprintf(paste0("weft: %s is version %s, newer than this weft reads; it is rewritten ",
                               "as version %d (rule 7.1.3)."), path, v, LEDGER_VERSION))
  }
  invisible()
}

# The report of new conditions (D19).
report_new_conditions <- function(rows, cmp, label) {
  if (is.null(cmp)) return(invisible())
  ck <- if (nrow(cmp)) paste(cmp$from, cmp$source, cmp$class, cmp$normalised, sep = "\r") else character()
  new <- Filter(function(r) !(paste(r$from, r$source, r$class, r$normalised, sep = "\r") %in% ck), rows)
  if (!length(new)) return(invisible())
  head <- sprintf("weft: %d new condition%s since %s (rule 7.4.4)", length(new),
                  if (length(new) == 1L) "" else "s", label)
  rlang::inform(paste(c(head, vapply(new, function(r) sprintf("  %s  %s: %s", r$source, r$class, r$text), "")),
                      collapse = "\n"), class = "weft_new_condition")
  invisible()
}

# Called by the `document` hook of a top-level knit (D20). `write` is FALSE
# for a knit that stops on its failures: its output is not written either.
ledger_finish <- function(s, write = TRUE) {
  es <- ledger_entries(s)
  root <- ledger_root(s)
  set_up <- !is.na(root) && is_set_up(root) && !rehearsing()
  do_write <- write && set_up && !isFALSE(s$config$ledger)
  s$output <- ledger_output_name(s, warn = do_write)
  hdr <- s$ledger_header
  prior <- NULL
  paths <- NULL
  source <- if (!is.na(root)) state_source(s, root) else as.character(s$input_name)
  if (set_up) {
    paths <- ledger_paths(root, source, gsub("[/\\\\]", "_", s$output))
    if (do_write) {
      ledger_prior_version_check(file.path(root, paths[["ledger"]]))
      prior <- condition_prior(file.path(root, paths[["conditions"]]))
    }
  }
  rows <- condition_rows(s, prior)
  s$ledger_df <- ledger_df(es, list())
  attr(s$ledger_df, "header") <- NULL
  s$condition_log <- condition_df(rows)
  attr(s$condition_log, "header") <- NULL
  s$written <- c(ledger = NA_character_, conditions = NA_character_)
  if (!do_write) return(invisible())
  lpath <- file.path(root, paths[["ledger"]])
  cpath <- file.path(root, paths[["conditions"]])
  # nothing is written where the locale would change the keys (F), where the
  # log's name would be the ledger's (H), or through a symbolic link (D6)
  refuse <- if (!isTRUE(l10n_info()[["UTF-8"]])) {
    sprintf(paste0("weft: not writing the ledger: this session's locale (%s) is not UTF-8, and keys under ",
                   "non-ASCII text would differ from a UTF-8 render's; run R in a UTF-8 locale (rule 7.1.3)."),
            Sys.getlocale("LC_CTYPE"))
  } else if (grepl("\\.conditions$", s$output)) {
    sprintf(paste0("weft: not writing the ledger: the output name `%s` ends in `.conditions`, which would ",
                   "be the name of another output's condition log; rename the output (rule 7.1.3)."), s$output)
  } else {
    ln <- ledger_link_in(root, paths)
    if (!is.null(ln)) sprintf("weft: not writing the ledger: %s is a symbolic link (rule 7.1.3).", ln)
  }
  if (!is.null(refuse)) {
    ledger_warn(refuse)
    return(invisible())
  }
  lines <- c(ledger_header_line("ledger", source, s$output, hdr), vapply(es, ledger_entry_line, ""))
  clines <- c(ledger_header_line("conditions", source, s$output), vapply(rows, condition_line, ""))
  bad <- list(ledger = write_whole_file(lpath, lines), conditions = write_whole_file(cpath, clines))
  failed <- !vapply(bad, is.null, NA)
  if (any(failed)) {
    ledger_warn(sprintf("weft: could not write %s: %s (rule 7.1.3).",
                        paste(c(lpath, cpath)[failed], collapse = ", "),
                        paste(unique(unlist(bad[failed])), collapse = "; ")))
  }
  s$written <- c(ledger = if (failed[["ledger"]]) NA_character_ else paths[["ledger"]],
                 conditions = if (failed[["conditions"]]) NA_character_ else paths[["conditions"]])
  # new conditions, against HEAD when git can say, else the last render (D19)
  cmp <- NULL
  label <- NULL
  if (nzchar(git_path()) && git_in_work_tree(root)) {
    gl <- git_show(root, paths[["conditions"]])
    if (!is.null(gl)) {
      cmp <- tryCatch(read_condition_log(lines = gl, lenient = TRUE), error = function(e) condition_df(list()))
      label <- "HEAD"
    }
  }
  # a log no commit holds (ignored, or no commit yet) is compared with the last render (E)
  if (is.null(cmp) && !is.null(prior)) {
    cmp <- prior
    label <- "the last render"
  }
  report_new_conditions(rows, cmp, label)
  invisible()
}
