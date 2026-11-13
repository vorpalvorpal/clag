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
  rlang::warn(msg, class = c("weft_ledger_warning", "weft_warning"))
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

# ---- headings and sections (D10) ---------------------------------------------

# The headings of a text and their anchors. Front matter, code chunks and
# fenced blocks are skipped; the anchor is the heading's `{#id}`, else
# Pandoc's identifier rule on its source text without inline code and
# attribute blocks; a repeated anchor takes -1, -2, ...
heading_anchors <- function(lines) {
  n <- length(lines)
  empty <- data.frame(line = integer(), anchor = character(), stringsAsFactors = FALSE)
  if (!n) return(empty)
  skip <- rep(FALSE, n)
  if (grepl("^---[ \t]*$", lines[1L])) {
    end <- which(grepl("^(---|\\.\\.\\.)[ \t]*$", lines[-1L]))[1L]
    if (!is.na(end)) skip[1L:(end + 1L)] <- TRUE
  }
  fence <- NULL
  in_comment <- FALSE
  for (i in seq_len(n)) {
    if (skip[i]) next
    l <- lines[i]
    if (!is.null(fence)) {
      skip[i] <- TRUE
      if (grepl(fence, l, perl = TRUE)) fence <- NULL
      next
    }
    # an HTML comment is not part of the output (D10)
    if (in_comment) {
      skip[i] <- TRUE
      if (grepl("-->", l, fixed = TRUE)) in_comment <- FALSE
      next
    }
    fm <- regmatches(l, regexec("^[ \t>]*(`{3,}|~{3,})", l))[[1L]]
    if (length(fm)) {
      skip[i] <- TRUE
      fence <- paste0("^[ \t>]*", substr(fm[2L], 1L, 1L), "{", nchar(fm[2L]), ",}[ \t\r]*$")
    } else if (grepl("<!--", gsub("<!--.*?-->", "", l, perl = TRUE), fixed = TRUE)) {
      in_comment <- TRUE
    }
  }
  blank <- function(l) !nzchar(trimws(l))
  heads <- list()
  for (i in seq_len(n)) {
    if (skip[i]) next
    l <- lines[i]
    m <- regmatches(l, regexec("^ {0,3}#{1,6}[ \t]+(.*?)([ \t]+#+)?[ \t]*$", l, perl = TRUE))[[1L]]
    if (length(m)) {
      # Pandoc wants a blank line (or the start of a block) before an ATX heading
      if (i == 1L || blank(lines[i - 1L]) || skip[i - 1L] ||
          grepl("^ {0,3}#{1,6}[ \t]+", lines[i - 1L])) {
        heads[[length(heads) + 1L]] <- list(line = i, text = m[2L])
      }
      next
    }
    if (i < n && !skip[i + 1L] && !blank(l) && grepl("^ {0,3}(=+|-+)[ \t]*$", lines[i + 1L]) &&
        (i == 1L || blank(lines[i - 1L]) || skip[i - 1L]) &&
        !grepl("^ {0,3}(=+|-+)[ \t]*$", l) && !grepl("^[ \t]*[|>]", l)) {
      heads[[length(heads) + 1L]] <- list(line = i, text = trimws(l))
    }
  }
  if (!length(heads)) return(empty)
  used <- character()
  anchors <- character(length(heads))
  for (h in seq_along(heads)) {
    txt <- heads[[h]]$text
    id <- NA_character_
    am <- regmatches(txt, regexec("[ \t]*\\{([^{}]*)\\}[ \t]*$", txt))[[1L]]
    if (length(am)) {
      im <- regmatches(am[2L], regexec("(?:^|[ \t])#([^ \t]+)", am[2L], perl = TRUE))[[1L]]
      if (length(im)) id <- im[2L]
      txt <- sub("[ \t]*\\{[^{}]*\\}[ \t]*$", "", txt)
    }
    base <- if (!is.na(id)) id else pandoc_id(txt)
    a <- base
    k <- 0L
    # an explicit id is kept as written; a generated one steps round the anchors taken
    while (is.na(id) && a %in% used) {
      k <- k + 1L
      a <- paste0(base, "-", k)
    }
    used <- c(used, a)
    anchors[h] <- a
  }
  data.frame(line = vapply(heads, function(h) h$line, 0L), anchor = anchors,
             stringsAsFactors = FALSE)
}

# Pandoc's identifier rule on a heading's source text (D10).
pandoc_id <- function(txt) {
  x <- gsub("`r[ \t][^`]*`", "", txt)
  x <- gsub("`", "", x, fixed = TRUE)
  x <- gsub("\\{[^{}]*\\}", "", x)
  # what Pandoc does not keep: link and image targets, footnote references,
  # raw HTML tags, emphasis markers
  x <- gsub("\\]\\([^)]*\\)", "]", x)
  x <- gsub("\\[\\^[^]]*\\]", "", x)
  x <- gsub("</?[A-Za-z][^<>]*>", "", x)
  x <- gsub("(?<![\\p{L}\\p{N}])_+|_+(?![\\p{L}\\p{N}])", "", x, perl = TRUE)
  x <- gsub("[^\\p{L}\\p{N}_.\\s-]", "", x, perl = TRUE)
  x <- trimws(tolower(x))
  x <- gsub("\\s+", "-", x, perl = TRUE)
  x <- sub("^[^\\p{L}]+", "", x, perl = TRUE)
  if (!nzchar(x)) "section" else x
}

anchor_at <- function(F, line) {
  if (is.null(F$anchors)) F$anchors <- heading_anchors(F$lines)
  a <- F$anchors
  i <- which(a$line <= line)
  if (length(i)) a$anchor[max(i)] else ""
}

in_front_matter <- function(F, line) {
  if (is.null(F$meta_blocks)) F$meta_blocks <- metadata_blocks(F$lines)
  mb <- F$meta_blocks
  nrow(mb) > 0L && any(mb$open <= line & line <= mb$close)
}

# ---- expressions (D9) ---------------------------------------------------------

expr_key <- function(code) {
  code <- trimws(as.character(code)[1L])
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

# ---- the sentence (D12) --------------------------------------------------------

# The sentence around the printed text out[a:b] of a rendered block. A failure
# marker is written without its line number, so a line inserted above it
# changes nothing.
ledger_sentence <- function(out, a, b, whole = FALSE, front = FALSE) {
  gsub("(<<weft: [^,>]+), line [0-9?]+>>", "\\1>>", ledger_sentence_at(out, a, b, whole, front))
}

# Block markers at the start of a line: a heading's `#`, a list marker, a block
# quote's `>`, a footnote definition's `[^1]:`.
sentence_marker_re <- paste0(
  "(?m)^[ \\t]*(?:(?:>[ \\t]*)|(?:(?:#{1,6}|[-*+]|[0-9]+[.)]|\\([A-Za-z]{1,2}\\)|\\([0-9]{1,2}\\)",
  "|\\[\\^[^\\]\\s]+\\]:)[ \\t]+))+")

# Replace every match of `pattern` in `x` by `fill`, one character for each
# character matched, so that the length of `x` does not change. The fill "A"
# makes a word, "Aaa...": ICU does not end a sentence after an all-capital word.
mask_fill <- function(x, pattern, fill) {
  m <- gregexpr(pattern, x, perl = TRUE)[[1L]]
  if (m[1L] < 0L) return(x)
  ml <- attr(m, "match.length")
  ch <- strsplit(x, "", fixed = TRUE)[[1L]]
  for (k in which(ml > 0L)) {
    ch[m[k]:(m[k] + ml[k] - 1L)] <- if (fill == "A") c("A", rep("a", ml[k] - 1L)) else fill
  }
  paste(ch, collapse = "")
}

# The top-level inline footnotes `^[...]` of `x`: a data frame of the position
# of the `^` and of the closing `]`.
inline_footnotes <- function(x) {
  st <- gregexpr("^[", x, fixed = TRUE)[[1L]]
  if (st[1L] < 0L) return(NULL)
  ch <- strsplit(x, "", fixed = TRUE)[[1L]]
  n <- length(ch)
  from <- integer()
  to <- integer()
  last <- 0L
  for (s0 in st) {
    if (s0 <= last) next
    depth <- 0L
    j <- s0 + 1L
    while (j <= n) {
      if (ch[j] == "[") depth <- depth + 1L
      else if (ch[j] == "]") {
        depth <- depth - 1L
        if (depth == 0L) break
      }
      j <- j + 1L
    }
    if (j <= n) {
      from <- c(from, s0)
      to <- c(to, j)
      last <- j
    }
  }
  if (length(from)) data.frame(from = from, to = to) else NULL
}

# A copy of the block `x` of exactly the same number of characters, in which
# what is not prose is replaced so that its punctuation cannot end a sentence
# (D12, decision 57): inline code, math, link and image targets, raw HTML,
# attribute blocks, shortcodes, citations, cross-references and inline
# footnotes become letters; emphasis markers and footnote references become
# closing brackets, so that a boundary falls after them; block markers and line
# ends become spaces. `keep` is the position of the construct's text: when it
# lies inside an inline footnote, the footnote's text is the block, and the
# result carries its extent as the attribute "window".
mask_nonprose <- function(x, keep = NULL) {
  n <- nchar(x)
  y <- mask_fill(x, sentence_marker_re, " ")
  y <- mask_fill(y, "(?m)^[ \\t]*:{3,}.*$", " ")
  y <- mask_fill(y, "\\{\\{<.*?>\\}\\}", "A")
  y <- mask_fill(y, "(?<=[\\])`])\\{[^{}\\n]*\\}", "A")
  y <- mask_fill(y, "(?s)(`+)(?!`).*?(?<!`)\\1(?!`)", "A")
  y <- mask_fill(y, "(?<![\\\\$])\\$(?![\\s$])[^$\\n]+?(?<![\\s\\\\])\\$(?![0-9])", "A")
  y <- mask_fill(y, "(?s)\\\\\\(.*?\\\\\\)", "A")
  y <- mask_fill(y, "(?<!<)</?[A-Za-z][^<>]*>", "A")
  y <- mask_fill(y, "\\[\\^[^\\]\\s]+\\]", ")")
  y <- mask_fill(y, "\\[[^\\[\\]]*(?<![[:alnum:]])-?@[[:alnum:]_][^\\[\\]]*\\]", "A")
  y <- mask_fill(y, "(?<![[:alnum:]_])-?@[[:alnum:]_](?:[[:alnum:]_:.#$%&+?<>~/-]*[[:alnum:]_])?", "A")
  y <- mask_fill(y, "\\\\@ref\\([^)]*\\)", "A")
  y <- mask_fill(y, "(?<=\\])(?:\\([^)\\n]*\\)|\\[[^\\]\\n]*\\])", "A")
  window <- NULL
  fn <- inline_footnotes(y)
  if (!is.null(fn)) {
    for (i in seq_len(nrow(fn))) {
      f <- fn$from[i]
      t <- fn$to[i]
      ch <- strsplit(y, "", fixed = TRUE)[[1L]]
      if (!is.null(keep) && keep[1L] > f && keep[2L] < t) {
        ch[c(f, f + 1L, t)] <- " "
        window <- c(f + 2L, t - 1L)
      } else {
        ch[f:t] <- ")"
      }
      y <- paste(ch, collapse = "")
    }
  }
  y <- mask_fill(y, "\\*+", ")")
  y <- mask_fill(y, "~~", ")")
  y <- mask_fill(y, "(?<![[:alnum:]])_+(?=[^\\s_])|(?<=[^\\s_])_+(?![[:alnum:]])", ")")
  y <- mask_fill(y, "[\\n\\t\\r]", " ")
  stopifnot(nchar(y) == n)
  attr(y, "window") <- window
  y
}

sentence_abbr_any <- "(?<![[:alnum:].])(?i:e\\.g|i\\.e|cf|ca|viz|vs|et al)\\.$"
sentence_abbr_en <- paste0("(?<![[:alnum:].])(?:Dr|St|No|Nos|Vol)\\.$|",
                           "(?<![[:alnum:].])(?i:approx|est|incl|excl)\\.$")

# The positions at which a sentence of the masked block `m` starts, after the
# first: ICU's boundaries (the locale is the document's `lang`), less those
# dropped by weft's rules (D12, decision 57).
sentence_starts_of <- function(m, lang) {
  l <- if (is.null(lang) || is.na(lang) || !nzchar(lang)) "en" else gsub("-", "_", lang)
  loc <- tryCatch(
    suppressWarnings(stringi::stri_locate_all_boundaries(m, type = "sentence", locale = paste0(l, "@ss=standard"))[[1L]]),
    error = function(e)
      stringi::stri_locate_all_boundaries(m, type = "sentence", locale = "en@ss=standard")[[1L]])
  p <- loc[, 1L]
  p <- p[p > 1L & !is.na(p)]
  if (!length(p)) return(integer())
  ch <- strsplit(m, "", fixed = TRUE)[[1L]]
  depth <- cumsum((ch == "[") - (ch == "]"))
  closes <- which(ch == "]")
  english <- lang_is_english(lang)
  keep <- vapply(p, function(q) {
    prev <- sub("[[:space:])]+$", "", substr(m, 1L, q - 1L))
    nxt <- sub("^[[:space:]]+", "", substr(m, q, nchar(m)))
    if (grepl("^[[:lower:][:digit:]]", nxt)) return(FALSE)
    if (depth[q - 1L] > 0L && length(closes) && max(closes) >= q) return(FALSE)
    if (grepl("(?<![[:alpha:]])[[:upper:]]\\.$", prev, perl = TRUE)) return(FALSE)
    if (grepl(sentence_abbr_any, prev, perl = TRUE)) return(FALSE)
    if (english && grepl(sentence_abbr_en, prev, perl = TRUE)) return(FALSE)
    TRUE
  }, NA)
  p[keep]
}

# The window and the sentence cuts of a paragraph `para` under the language `lang`:
# list(win, cuts). Masking the paragraph and asking ICU for its boundaries is the cost of
# a sentence, and every entry in a paragraph asks for the same answer, so it is kept, keyed
# on the paragraph's own text and the language (a changed paragraph is a different key).
# The position `keep` matters only to a paragraph with an inline footnote `^[`; such a
# paragraph is not kept. The store is emptied when it grows large.
sentence_cache <- new.env(parent = emptyenv())

sentence_cuts <- function(para, keep, lang) {
  # an environment key is a name, limited to 10000 bytes: a long paragraph is not kept
  cacheable <- !grepl("^[", para, fixed = TRUE) && nchar(para, "bytes") < 4000L
  if (cacheable) {
    key <- paste(lang, para, sep = "\r\001")
    hit <- sentence_cache[[key]]
    if (!is.null(hit)) return(hit)
  }
  m <- mask_nonprose(para, keep)
  win <- attr(m, "window") %||% c(1L, nchar(para))
  cuts <- sentence_starts_of(m, lang)
  mk <- gregexpr(sentence_marker_re, para, perl = TRUE)[[1L]]
  if (mk[1L] > 0L) {
    ml <- attr(mk, "match.length")
    own <- !grepl("^[ \t>]*$", substring(para, mk, mk + ml - 1L))
    cuts <- c(cuts, (mk + ml)[own | mk == 1L])
  }
  fence <- gregexpr("(?m)^[ \t]*:{3,}.*$", para, perl = TRUE)[[1L]]
  if (fence[1L] > 0L) cuts <- c(cuts, fence + attr(fence, "match.length"))
  out <- list(win = win, cuts = cuts)
  if (cacheable) {
    if (length(sentence_cache) >= 5000L) rm(list = ls(sentence_cache, all.names = TRUE), envir = sentence_cache)
    sentence_cache[[key]] <- out
  }
  out
}

# The paragraph breaks (a newline, blank space, a newline) of the block `out`: the
# position after each break, scanning left to right, and the start of every break.
# A block's entries all ask about the same text, so the last answer is kept.
paragraph_cache <- new.env(parent = emptyenv())

paragraph_breaks <- function(out) {
  if (identical(paragraph_cache$out, out)) return(paragraph_cache$breaks)
  m <- gregexpr("\n[ \t]*\n", out)[[1L]]
  ends <- if (m[1L] > 0L) m + attr(m, "match.length") else integer()
  starts <- gregexpr("(?=\n[ \t]*\n)", out, perl = TRUE)[[1L]]
  breaks <- list(ends = ends, starts = starts[starts > 0L])
  paragraph_cache$out <- out
  paragraph_cache$breaks <- breaks
  breaks
}

ledger_sentence_at <- function(out, a, b, whole = FALSE, front = FALSE) {
  n <- nchar(out)
  if (is.na(a) || is.na(b)) return(collapse_ws(out))
  if (b < a - 1L) b <- a - 1L
  ps <- 1L
  pe <- n
  if (front) {
    lines <- strsplit(out, "\n", fixed = TRUE)[[1L]]
    ends <- cumsum(nchar(lines) + 1L)
    li <- which(ends >= a)[1L]
    if (is.na(li)) li <- length(lines)
    lo <- li
    hi <- li
    while (lo > 1L && grepl("^[ \t]+\\S", lines[lo - 1L])) lo <- lo - 1L
    while (hi < length(lines) && grepl("^[ \t]+\\S", lines[hi + 1L])) hi <- hi + 1L
    return(sentence_cut(collapse_ws(paste(lines[lo:hi], collapse = " "))))
  }
  if (whole) return(sentence_cut_around(out, a, b, 1L, n))
  pb <- paragraph_breaks(out)
  # the paragraph starts after the last break that ends before `a` and stops
  # before the first break that starts after `b`
  if (any(pb$ends <= a)) ps <- max(pb$ends[pb$ends <= a])
  later <- pb$starts[pb$starts > b]
  if (length(later)) pe <- min(later) - 1L
  ps <- max(ps, 1L)
  para <- substr(out, ps, pe)
  a2 <- a - ps + 1L
  b2 <- b - ps + 1L
  ls <- 1L
  nl <- gregexpr("\n", substr(para, 1L, a2 - 1L), fixed = TRUE)[[1L]]
  if (nl[1L] > 0L) ls <- max(nl) + 1L
  nxt <- regexpr("\n", substr(para, b2 + 1L, nchar(para)), fixed = TRUE)
  le <- if (nxt > 0L) b2 + nxt - 1L else nchar(para)
  line <- substr(para, ls, le)
  if (grepl("^[ \t]*\\|", line)) {
    ca <- ls
    pp <- gregexpr("|", substr(para, ls, a2 - 1L), fixed = TRUE)[[1L]]
    if (pp[1L] > 0L) ca <- ls + max(pp)
    cb <- le
    pn <- regexpr("|", substr(para, b2 + 1L, le), fixed = TRUE)
    if (pn > 0L) cb <- b2 + pn - 1L
    return(sentence_cut_around(para, a2, b2, ca, cb))
  }
  if (grepl("^[ \t]{0,3}#{1,6}[ \t]", line)) {
    hs <- ls + attr(regexpr("^[ \t]{0,3}#{1,6}[ \t]+", line), "match.length")
    return(sentence_cut_around(para, a2, b2, hs, le))
  }
  # the sentence: between the cuts that ICU, less weft's rules, leaves (D12)
  cb <- sentence_cuts(para, c(a2, b2), current_lang())
  win <- cb$win
  cuts <- cb$cuts
  st <- max(c(win[1L], cuts[cuts <= a2 & cuts >= win[1L]]))
  after <- cuts[cuts > b2 & cuts <= win[2L]]
  en <- if (length(after)) min(after) - 1L else win[2L]
  # the cut sits after the next block's marker: the sentence stops before it
  nlp <- gregexpr("\n", substr(para, 1L, en), fixed = TRUE)[[1L]]
  if (nlp[1L] > 0L && max(nlp) > b2) {
    tl <- substr(para, max(nlp) + 1L, en)
    mm <- regexpr(sentence_marker_re, tl, perl = TRUE)
    if (mm[1L] == 1L && attr(mm, "match.length") == nchar(tl)) en <- max(nlp) - 1L
  }
  sentence_cut_around(para, a2, b2, st, en)
}

# Cut a sentence longer than 400 characters to 200 either side of the printed
# text, at word boundaries, each cut marked with an ellipsis.
sentence_cut_around <- function(txt, a, b, st, en) {
  pre <- collapse_ws_keep(substr(txt, st, a - 1L))
  md <- collapse_ws_keep(substr(txt, a, b))
  post <- collapse_ws_keep(substr(txt, b + 1L, en))
  full <- trimws(paste0(pre, md, post))
  full <- gsub("[ \t\r\n]+", " ", full)
  if (nchar(full) <= 400L) return(full)
  pre <- sub("^ +", "", pre)
  post <- sub(" +$", "", post)
  dots <- "\u2026"
  if (nchar(pre) > 200L) {
    n <- nchar(pre)
    tl <- substr(pre, n - 199L, n)
    if (substr(pre, n - 200L, n - 200L) != " ") {
      tl <- if (grepl(" ", tl, fixed = TRUE)) sub("^[^ ]* ", "", tl) else ""
    }
    pre <- paste0(dots, tl)
  }
  if (nchar(post) > 200L) {
    hd <- substr(post, 1L, 200L)
    if (substr(post, 201L, 201L) != " ") {
      hd <- if (grepl(" ", hd, fixed = TRUE)) sub(" [^ ]*$", "", hd) else ""
    }
    post <- paste0(hd, dots)
  }
  gsub("[ \t\r\n]+", " ", trimws(paste0(pre, md, post)))
}

collapse_ws_keep <- function(x) gsub("[ \t\r\n]+", " ", x)

sentence_cut <- function(x) {
  if (nchar(x) <= 400L) x else paste0(substr(x, 1L, 399L), "\u2026")
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
  if (!quarto && isNamespaceLoaded("rmarkdown")) {
    rf <- get("render", envir = asNamespace("rmarkdown"))
    for (i in rev(seq_len(sys.nframe()))) {
      if (identical(sys.function(i), rf)) {
        of <- get0("output_file", envir = sys.frame(i), inherits = FALSE)
        if (is.character(of) && length(of) == 1L && !is.na(of) && nzchar(of)) return(strip_ext(of))
        break
      }
    }
  }
  src <- strip_ext(if (is.na(s$input_path)) "document" else {
    root <- ledger_root(s)
    state_source(s, root)
  })
  if (quarto) {
    x <- tryCatch(jsonlite::fromJSON(info, simplifyVector = FALSE), error = function(e) NULL)
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
