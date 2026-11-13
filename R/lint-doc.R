# The document and project lints (design-3, package 3d): citations against the
# bibliography, anchors and cross-references, hygiene of documents and the
# project (headings, chunks, file links, where settings live, the engine),
# figures and tables, and the tier-2 listing that `changes()` shows.
#
# Each rule is found by name: `lint_<id with - as _>(src, ctx)` for a file
# scope rule, `lint_<id>(ctx)` for a project scope rule (see `R/lint.R`).
# Nothing here runs document code.

XREF_PREFIXES <- c("fig", "tbl", "lst", "sec", "eq", "thm", "lem", "cor", "prp", "cnj", "def",
                   "exm", "exr", "sol", "rem")
XREF_ID_RE <- paste0("^(?i:", paste(XREF_PREFIXES, collapse = "|"), ")-")
# an anchor id as the document defines it: the first letter of a reference is lowered
xref_id_norm <- function(id) paste0(tolower(substr(id, 1L, 1L)), substring(id, 2L))
# keys that a `config-place` finding looks for in a document's `weft:` (stage 4 adds its switch key)
CONFIG_PLACE_KEYS <- c("draft", "decisions")

# ---- small helpers -----------------------------------------------------------------------

dl_cached <- function(src, key, f) {
  e <- src$cache
  if (is.null(e[[key]])) e[[key]] <- f()
  e[[key]]
}

# a cache for the whole run, kept on the lint context
lint_cache <- function(ctx) {
  if (is.null(ctx$dl)) ctx$dl <- new.env(parent = emptyenv())
  ctx$dl
}

dl_ctx <- function(x) if (x %in% c("prose", "caption", "front-matter", "weft_str", "phrase", "chunk", "project")) x else "prose"

dl_empty <- function() new_findings()

# the folder part of a path relative to the root ("." at the root)
dl_dir <- function(rel) {
  d <- dirname(rel)
  if (identical(d, "")) "." else d
}

# a relative path joined and tidied ("a/../b" gives "b"); NA when it climbs out of the root
dl_join <- function(dir, path) {
  parts <- strsplit(paste0(dir, "/", path), "/", fixed = TRUE)[[1L]]
  out <- character()
  for (p in parts) {
    if (!nzchar(p) || p == ".") next
    if (p == "..") {
      if (!length(out)) return(NA_character_)
      out <- out[-length(out)]
    } else out <- c(out, p)
  }
  paste(out, collapse = "/")
}

# the offsets of a pattern's captures in each string: a list, one element per string,
# of data frames `s` (start of the match), `len`, `c1`, `c2` (capture starts, 0 for none).
dl_matches <- function(pat, x) {
  m <- gregexpr(pat, x, perl = TRUE)
  lapply(seq_along(x), function(i) {
    mi <- m[[i]]
    if (mi[1L] < 0L) return(NULL)
    cs <- attr(mi, "capture.start")
    cl <- attr(mi, "capture.length")
    k <- if (is.null(cs)) 0L else ncol(cs)
    data.frame(s = as.integer(mi), len = attr(mi, "match.length"),
               c1 = if (k >= 1L) as.integer(cs[, 1L]) else 0L, l1 = if (k >= 1L) as.integer(cl[, 1L]) else 0L,
               c2 = if (k >= 2L) as.integer(cs[, 2L]) else 0L, l2 = if (k >= 2L) as.integer(cl[, 2L]) else 0L,
               c3 = if (k >= 3L) as.integer(cs[, 3L]) else 0L, l3 = if (k >= 3L) as.integer(cl[, 3L]) else 0L)
  })
}

dl_trim <- function(x) gsub("^[ \t\n]+|[ \t\n]+$", "", x)

# an attribute text with its quoted strings made blank (same length)
dl_unquote <- function(x) {
  m <- gregexpr("\"[^\"\n]*\"|'[^'\n]*'", x, perl = TRUE)
  regmatches(x, m) <- lapply(regmatches(x, m), function(z) vapply(nchar(z), function(k) strrep(" ", k), ""))
  x
}

is_rmd <- function(src) tolower(src$ext) == "rmd"

# ---- the document, seen from the lints in this file ------------------------------------------

# The text with everything that is not markdown body made blank: metadata, fenced
# blocks, code spans, math, HTML comments and the attribute blocks of weft constructs.
doc_skeleton <- function(src) dl_cached(src, "skeleton", function() {
  text <- src$text
  n <- nchar(text)
  if (n == 0L) return("")
  ls <- src$line_start
  lines <- src$lines
  nl <- length(lines)
  le <- ls + nchar(lines) - 1
  inmeta <- logical(nl)
  for (m in src$meta) inmeta[m$open:m$close] <- TRUE
  fb <- fence_blocks(lines, inmeta)
  nonbody <- inmeta
  for (b in seq_len(nrow(fb))) nonbody[fb$open[b]:fb$close[b]] <- TRUE
  idx <- which(nonbody)
  st <- ls[idx]
  en <- le[idx]
  rg <- src$regions
  k <- rg$type %in% c("code", "math")
  st <- c(st, rg$start[k])
  en <- c(en, rg$end[k])
  k <- rg$type == "code_attr"
  st <- c(st, rg$attr_start[k])
  en <- c(en, rg$attr_end[k])
  rw <- src$rows
  if (nrow(rw)) {
    st <- c(st, ifelse(is.na(rw$fblock), rw$fstart, rw$fblock))
    en <- c(en, rw$fend)
  }
  chars <- strsplit(text, "")[[1L]]
  mk <- mark_ranges(n, st, en)
  chars[mk & chars != "\n"] <- " "
  s <- paste(chars, collapse = "")
  m <- gregexpr("<!--[\\s\\S]*?-->", s, perl = TRUE)
  regmatches(s, m) <- lapply(regmatches(s, m), function(z) gsub("[^\n]", " ", z))
  s
})

# Links and images: the offset where the target starts, the target as written, and the kind.
doc_links <- function(src) dl_cached(src, "links", function() {
  rg <- src$regions
  rg <- rg[rg$type %in% c("link", "image"), , drop = FALSE]
  empty <- data.frame(start = integer(), target = character(), kind = character(), rstart = integer(),
                      rend = integer(), stringsAsFactors = FALSE)
  if (!nrow(rg)) return(empty)
  txt <- src_substr(src, rg$start, rg$end)
  m <- regexpr("(?s)^!?\\[.*\\]\\(\\s*(<[^>]*>|[^\\s)]*)", txt, perl = TRUE)
  ok <- m > 0L
  if (!any(ok)) return(empty)
  cs <- attr(m, "capture.start")[, 1L]
  cl <- attr(m, "capture.length")[, 1L]
  tg <- substring(txt, cs, cs + cl - 1L)
  st <- rg$start + cs - 1L
  bracket <- grepl("^<.*>$", tg)
  tg[bracket] <- substring(tg[bracket], 2L, nchar(tg[bracket]) - 1L)
  st[bracket] <- st[bracket] + 1L
  data.frame(start = st[ok], target = tg[ok], kind = rg$type[ok], rstart = rg$start[ok], rend = rg$end[ok],
             stringsAsFactors = FALSE)
})

# Every anchor the document defines: id, offset, and whether it is derived (an `.Rmd` chunk label).
doc_anchors <- function(src) dl_cached(src, "anchors", function() {
  s <- doc_skeleton(src)
  out <- list()
  m <- gregexpr("\\{(?:[^{}\"'\n]|\"[^\"\n]*\"|'[^'\n]*')*\\}", s, perl = TRUE)[[1L]]
  if (m[1L] > 0L) {
    len <- attr(m, "match.length")
    bt <- dl_unquote(substring(s, m, m + len - 1L))
    mi <- gregexpr("(?<=[{ \t])#([^ \t{}]+)", bt, perl = TRUE)
    for (i in seq_along(bt)) {
      if (mi[[i]][1L] < 0L) next
      cs <- attr(mi[[i]], "capture.start")[, 1L]
      cl <- attr(mi[[i]], "capture.length")[, 1L]
      out[[length(out) + 1L]] <- data.frame(id = substring(bt[i], cs, cs + cl - 1L),
                                            start = m[i] + as.integer(mi[[i]]) - 1L, derived = FALSE,
                                            stringsAsFactors = FALSE)
    }
  }
  rg <- src$regions
  xa <- rg[rg$type == "crossref" & startsWith(rg$name, "(\\#"), , drop = FALSE]
  if (nrow(xa)) {
    out[[length(out) + 1L]] <- data.frame(id = sub("^\\(\\\\#(.*)\\)$", "\\1", xa$name), start = xa$start,
                                          derived = FALSE, stringsAsFactors = FALSE)
  }
  ch <- src$chunks
  for (k in seq_len(nrow(ch))) {
    if (!isTRUE(ch$eval[k]) || !isTRUE(ch$explicit[k])) next
    lab <- ch$label[k]
    if (is.na(lab) || !nzchar(lab)) next
    pos <- chunk_label_start(src, k)
    if (is_rmd(src)) {
      out[[length(out) + 1L]] <- data.frame(id = c(lab, paste0("fig:", lab), paste0("tab:", lab)), start = pos,
                                            derived = TRUE, stringsAsFactors = FALSE)
    }
    if (grepl(XREF_ID_RE, lab, perl = TRUE)) {
      out[[length(out) + 1L]] <- data.frame(id = lab, start = pos, derived = FALSE, stringsAsFactors = FALSE)
    }
  }
  if (!length(out)) {
    return(data.frame(id = character(), start = integer(), derived = logical(), stringsAsFactors = FALSE))
  }
  r <- do.call(rbind, out)
  r$start <- as.integer(r$start)
  r
})

# The offset of a chunk's label: its `#| label:` value, else its place in the header.
chunk_label_start <- function(src, k) {
  ch <- src$chunks
  lab <- ch$label[k]
  ls <- src$line_start
  i0 <- ch$open[k] + 1L
  i1 <- min(ch$close[k] - 1L, length(src$lines))
  if (i1 >= i0) {
    idx <- i0:i1
    m <- regexpr("^[ \t]*#\\|[ \t]*label[ \t]*:[ \t]*[\"']?", src$lines[idx], perl = TRUE)
    h <- which(m > 0L)
    if (length(h)) return(as.integer(ls[idx[h[1L]]] + attr(m, "match.length")[h[1L]]))
  }
  hdr <- src$lines[ch$open[k]]
  p <- regexpr(lab, substring(hdr, 4L), fixed = TRUE)
  as.integer(ls[ch$open[k]] + (if (p > 0L) p + 2L else 0L))
}

# The heading ids Pandoc would make (and the explicit ones).
doc_auto_ids <- function(src) dl_cached(src, "autoids", function() {
  a <- heading_anchors(src$lines)$anchor
  if (is.null(a)) character() else a
})

# Every reference the document makes: id, the offset of the finding, kind ("at", "ref", "link",
# "filelink") and, for a `file#id` link, the file part as written.
doc_refs <- function(src) dl_cached(src, "refs", function() {
  rg <- src$regions
  out <- list()
  cr <- rg[rg$type == "crossref", , drop = FALSE]
  if (nrow(cr)) {
    at <- grepl("^-?@", cr$name)
    if (any(at)) {
      out[[length(out) + 1L]] <- data.frame(id = xref_id_norm(sub("^-?@", "", cr$name[at])),
                                            start = cr$start[at] + startsWith(cr$name[at], "-"), kind = "at",
                                            file = NA_character_, stringsAsFactors = FALSE)
    }
    rf <- grepl("^\\\\@ref\\(", cr$name)
    if (any(rf)) {
      out[[length(out) + 1L]] <- data.frame(id = dl_trim(sub("^\\\\@ref\\((.*)\\)$", "\\1", cr$name[rf])),
                                            start = cr$start[rf] + 6L, kind = "ref", file = NA_character_,
                                            stringsAsFactors = FALSE)
    }
  }
  ct <- rg[rg$type == "citation", , drop = FALSE]
  if (nrow(ct)) {
    txt <- src_substr(src, ct$start, ct$end)
    pat <- paste0("(?<![[:alnum:]_])-?(@)((?i:", paste(XREF_PREFIXES, collapse = "|"), ")-", KEY_BODY, ")")
    mm <- dl_matches(pat, txt)
    for (i in seq_along(mm)) {
      d <- mm[[i]]
      if (is.null(d)) next
      out[[length(out) + 1L]] <- data.frame(id = xref_id_norm(substring(txt[i], d$c2, d$c2 + d$l2 - 1L)),
                                            start = ct$start[i] + d$c1 - 1L, kind = "at", file = NA_character_,
                                            stringsAsFactors = FALSE)
    }
  }
  lk <- doc_links(src)
  lk <- lk[lk$kind == "link", , drop = FALSE]
  if (nrow(lk)) {
    h <- regexpr("#", lk$target, fixed = TRUE)
    has <- h > 0L
    if (any(has)) {
      tg <- lk$target[has]
      hh <- as.integer(h[has])
      frag <- substring(tg, hh + 1L)
      file <- substr(tg, 1L, hh - 1L)
      frag <- sub("\\?.*$", "", frag)
      keep <- nzchar(frag) & !grepl("^[A-Za-z][A-Za-z0-9+.-]*:", tg) & !startsWith(tg, "//")
      if (any(keep)) {
        out[[length(out) + 1L]] <- data.frame(
          id = frag[keep], start = lk$start[has][keep] + hh[keep] - 1L,
          kind = ifelse(nzchar(file[keep]), "filelink", "link"), file = ifelse(nzchar(file[keep]), file[keep], NA_character_),
          stringsAsFactors = FALSE)
      }
    }
  }
  if (!length(out)) {
    return(data.frame(id = character(), start = integer(), kind = character(), file = character(),
                      stringsAsFactors = FALSE))
  }
  r <- do.call(rbind, out)
  r$start <- as.integer(r$start)
  r
})

# ---- the project's index of anchors and references (shared by the 5.7 rules) ------------------------

project_index <- function(ctx) {
  cache <- lint_cache(ctx)
  if (!is.null(cache$index)) return(cache$index)
  files <- sort(unique(c(ctx$files, ctx$md_files, ctx$include_files)), method = "radix")
  A <- list()
  R <- list()
  auto <- list()
  srcs <- list()
  for (f in files) {
    src <- tryCatch(ctx$source(f), error = function(e) NULL)
    if (is.null(src) || isTRUE(src$invalid)) {
      ctx$note(sprintf("%s could not be read, so its anchors and references were not used (rule 5.7.1).", f))
      next
    }
    srcs[[f]] <- src
    a <- doc_anchors(src)
    if (nrow(a)) {
      a$file <- f
      a$line <- src_line_of(src, a$start)
      A[[length(A) + 1L]] <- a
    }
    r <- doc_refs(src)
    if (nrow(r)) {
      r$ref_file <- f
      R[[length(R) + 1L]] <- r
    }
    auto[[f]] <- doc_auto_ids(src)
  }
  anchors <- if (length(A)) do.call(rbind, A) else
    data.frame(id = character(), start = integer(), derived = logical(), file = character(), line = integer(),
               stringsAsFactors = FALSE)
  refs <- if (length(R)) do.call(rbind, R) else
    data.frame(id = character(), start = integer(), kind = character(), file = character(), ref_file = character(),
               stringsAsFactors = FALSE)
  if (nrow(anchors)) anchors <- anchors[order(anchors$file, anchors$start, method = "radix"), , drop = FALSE]
  idx <- list(anchors = anchors, refs = refs, auto = auto, srcs = srcs, files = files)
  cache$index <- idx
  idx
}

# ---- bibliography (L32) ---------------------------------------------------------------------------------

dl_yaml_file <- function(ctx, path) {
  cache <- lint_cache(ctx)
  key <- paste0("yaml:", path)
  if (is.null(cache[[key]])) {
    y <- tryCatch(yaml_text(read_source_text(path)),
                  error = function(e) NULL)
    cache[[key]] <- if (is.list(y)) y else list()
  }
  cache[[key]]
}

dl_bib_keys <- function(ctx, path) {
  cache <- lint_cache(ctx)
  key <- paste0("bibkeys:", path)
  if (is.null(cache[[key]])) cache[[key]] <- read_bib_keys(path)
  cache[[key]]
}

# The keys of a document's bibliography and the bibliography files its own front matter names
# that do not exist.
doc_bib <- function(src, ctx) {
  cache <- lint_cache(ctx)
  key <- paste0("bib:", src$file)
  if (!is.null(cache[[key]])) return(cache[[key]])
  root <- ctx$root
  dir_rel <- dl_dir(src$file)
  keys <- character()
  missing <- character()
  resolve <- function(p, base) {
    if (grepl("^(/|~|[A-Za-z]:[/\\\\])", p)) return(path.expand(p))
    if (base %in% c(".", "")) file.path(root, p) else file.path(root, base, p)
  }
  add_files <- function(files, base, own) {
    for (f in files[!is.na(files) & nzchar(files)]) {
      path <- resolve(f, base)
      if (file.exists(path)) {
        keys <<- c(keys, dl_bib_keys(ctx, path))
      } else if (own) {
        missing <<- c(missing, f)
      } else {
        ctx$note(sprintf("The bibliography file %s named for %s was not found (rule 5.4.4).", f, src$file))
      }
    }
  }
  for (m in src$meta) {
    mb <- metadata_bibliography(m$yaml)
    add_files(mb$files, dir_rel, TRUE)
    keys <- c(keys, mb$keys)
  }
  for (nm in QUARTO_MARKERS) {
    p <- file.path(root, nm)
    if (!file.exists(p)) next
    mb <- metadata_bibliography(dl_yaml_file(ctx, p))
    add_files(mb$files, ".", FALSE)
    keys <- c(keys, mb$keys)
    break
  }
  ds <- character()
  d <- dir_rel
  repeat {
    ds <- c(ds, d)
    if (d %in% c(".", "")) break
    d <- dirname(d)
  }
  for (d in ds) {
    for (nm in METADATA_MARKERS) {
      p <- if (d == ".") file.path(root, nm) else file.path(root, d, nm)
      if (!file.exists(p)) next
      mb <- metadata_bibliography(dl_yaml_file(ctx, p))
      add_files(mb$files, d, FALSE)
      keys <- c(keys, mb$keys)
      break
    }
  }
  add_files(as.character(unlist(src$cfg$bibliography)), ".", FALSE)
  res <- list(keys = unique(as.character(keys)), missing = unique(missing))
  cache[[key]] <- res
  res
}

# The rows of the `cite` kind: offsets, value and context.
doc_cite_rows <- function(src) {
  rw <- src$rows
  empty <- data.frame(start = integer(), end = integer(), value = character(), context = character(),
                      stringsAsFactors = FALSE)
  if (!nrow(rw)) return(empty)
  k <- which(rw$kind == "cite")
  if (!length(k)) return(empty)
  val <- rw$expr[k]
  for (i in which(is.na(val))) {
    at <- if (is.na(rw$fblock[k[i]])) "" else src_substr(src, rw$fblock[k[i]], rw$fend[k[i]])
    m <- regmatches(at, regexec("cite[ \t]*=[ \t]*(?:\"([^\"]*)\"|'([^']*)')", at, perl = TRUE))[[1L]]
    val[i] <- if (length(m)) paste0(m[2L], m[3L]) else ""
  }
  data.frame(start = as.integer(rw$fstart[k]), end = as.integer(rw$fend[k]), value = val,
             context = rw$context[k], stringsAsFactors = FALSE)
}

# Citation keys written in the document (from the citation regions): key, offset of the `@`, offset
# of the region.
doc_citations <- function(src) dl_cached(src, "citations", function() {
  rg <- src$regions[src$regions$type == "citation", , drop = FALSE]
  empty <- data.frame(key = character(), at = integer(), stringsAsFactors = FALSE)
  if (!nrow(rg)) return(empty)
  txt <- src_substr(src, rg$start, rg$end)
  pat <- paste0("(?<![[:alnum:]_])-?(@)(?:\\{([^}\n]*)\\}|(", CITE_KEY_RE, "))")
  mm <- dl_matches(pat, txt)
  out <- list()
  for (i in seq_along(mm)) {
    d <- mm[[i]]
    if (is.null(d)) next
    key <- ifelse(d$c2 > 0L & d$l2 > 0L, substring(txt[i], d$c2, d$c2 + d$l2 - 1L),
                  substring(txt[i], d$c3, d$c3 + d$l3 - 1L))
    out[[length(out) + 1L]] <- data.frame(key = key, at = rg$start[i] + d$c1 - 1L, stringsAsFactors = FALSE)
  }
  if (!length(out)) return(empty)
  r <- do.call(rbind, out)
  r$at <- as.integer(r$at)
  r
})

# The innermost block (smallest) holding an offset: its index in src$blocks, or NA.
doc_inner_block <- function(src, pos) {
  b <- src$blocks
  vapply(pos, function(p) {
    h <- which(b$start <= p & b$end >= p)
    if (!length(h)) NA_integer_ else h[which.min(b$end[h] - b$start[h])]
  }, 1L)
}

lint_cite_key <- function(src, ctx) {
  rows <- doc_cite_rows(src)
  if (!nrow(rows)) return(dl_empty())
  known <- doc_bib(src, ctx)$keys
  out <- list()
  for (i in seq_len(nrow(rows))) {
    keys <- cite_keys(rows$value[i])
    keys <- keys[nzchar(keys)]
    bad <- unique(keys[!keys %in% known])
    if (!length(bad)) next
    rt <- src_substr(src, rows$start[i], rows$end[i])
    pos <- vapply(bad, function(k) {
      p <- regexpr(k, rt, fixed = TRUE)
      as.integer(rows$start[i] + (if (p > 0L) p - 1L else 0L))
    }, 1L, USE.NAMES = FALSE)
    out[[length(out) + 1L]] <- finding_at(
      src, pos, pos + nchar(bad) - 1L, "cite-key", bad,
      sprintf("The key `%s` of this cite span is not in the bibliography (rule 5.4.1).", bad),
      "Add the entry to the bibliography, or correct the key.", context = dl_ctx(rows$context[i]))
  }
  bind_findings(out)
}

lint_cite_bare <- function(src, ctx) {
  rows <- doc_cite_rows(src)
  if (!nrow(rows)) return(dl_empty())
  cit <- doc_citations(src)
  blk <- doc_inner_block(src, rows$start)
  b <- src$blocks
  out <- list()
  for (i in seq_len(nrow(rows))) {
    if (grepl("@", rows$value[i], fixed = TRUE)) next
    keys <- unique(cite_keys(rows$value[i]))
    keys <- keys[nzchar(keys)]
    written <- character()
    if (!is.na(blk[i])) {
      written <- cit$key[cit$at >= b$start[blk[i]] & cit$at <= b$end[blk[i]]]
    }
    bad <- keys[!keys %in% written]
    if (!length(bad)) next
    rt <- src_substr(src, rows$start[i], rows$end[i])
    pos <- vapply(bad, function(k) {
      p <- regexpr(k, rt, fixed = TRUE)
      as.integer(rows$start[i] + (if (p > 0L) p - 1L else 0L))
    }, 1L, USE.NAMES = FALSE)
    out[[length(out) + 1L]] <- finding_at(
      src, pos, pos + nchar(bad) - 1L, "cite-bare", bad,
      sprintf("The key `%s` is cited by a span but not written as a citation in the same block (rule 5.4.2).", bad),
      sprintf("Write @%s in the same paragraph, list item, table cell, note or caption.", bad),
      context = dl_ctx(rows$context[i]))
  }
  bind_findings(out)
}

lint_citation_key <- function(src, ctx) {
  bib <- doc_bib(src, ctx)
  out <- list()
  for (f in bib$missing) {
    pos <- NA_integer_
    for (m in src$meta) {
      idx <- m$open:m$close
      h <- which(grepl(f, src$lines[idx], fixed = TRUE))
      if (length(h)) {
        ln <- idx[h[1L]]
        pos <- src$line_start[ln] + regexpr(f, src$lines[ln], fixed = TRUE) - 1L
        break
      }
    }
    if (is.na(pos)) pos <- src$line_start[1L]
    out[[length(out) + 1L]] <- finding_at(
      src, pos, pos + nchar(f) - 1L, "citation-key", f,
      sprintf("The bibliography file `%s` named here was not found (rule 5.4.4).", f),
      "Correct the path, which is read from this document's folder.", context = "front-matter", spec = "5.4.4")
  }
  cit <- doc_citations(src)
  if (nrow(cit)) {
    cit <- cit[!grepl(XREF_ID_RE, cit$key, perl = TRUE) & !cit$key %in% bib$keys, , drop = FALSE]
    if (nrow(cit)) {
      out[[length(out) + 1L]] <- finding_at(
        src, cit$at, cit$at, "citation-key", cit$key,
        sprintf("The citation key `%s` is not in the bibliography (rule 5.4.3).", cit$key),
        "Add the entry to the bibliography, or correct the key.")
    }
  }
  bind_findings(out)
}

# ---- anchors and references (L33) ---------------------------------------------------------------------

lint_xref <- function(ctx) {
  idx <- project_index(ctx)
  refs <- idx$refs
  if (!nrow(refs)) return(dl_empty())
  refs <- refs[refs$ref_file %in% ctx$files, , drop = FALSE]
  if (!nrow(refs)) return(dl_empty())
  anchor_ids <- unique(idx$anchors$id)
  auto_ids <- unique(unlist(idx$auto, use.names = FALSE))
  docs <- names(idx$srcs)
  bad <- logical(nrow(refs))
  for (i in seq_len(nrow(refs))) {
    k <- refs$kind[i]
    id <- refs$id[i]
    bad[i] <- switch(k,
      at = !id %in% anchor_ids,
      ref = !id %in% c(anchor_ids, auto_ids),
      link = !id %in% c(anchor_ids, auto_ids),
      filelink = {
        f <- refs$file[i]
        if (grepl("^[A-Za-z][A-Za-z0-9+.-]*:|^//", f)) {
          FALSE
        } else {
          rel <- if (startsWith(f, "/")) dl_join("", substring(f, 2L)) else dl_join(dl_dir(refs$ref_file[i]), f)
          if (is.na(rel) || !rel %in% docs) FALSE else {
            a <- idx$anchors
            !id %in% c(a$id[a$file == rel], idx$auto[[rel]])
          }
        }
      }, FALSE)
  }
  refs <- refs[bad, , drop = FALSE]
  if (!nrow(refs)) return(dl_empty())
  out <- lapply(unique(refs$ref_file), function(f) {
    r <- refs[refs$ref_file == f, , drop = FALSE]
    src <- idx$srcs[[f]]
    finding_at(src, r$start, r$start, "xref", r$id,
               sprintf("The reference `%s` names no anchor in the project (rule 5.7.1).", r$id),
               "Define the anchor, or correct the reference.")
  })
  bind_findings(out)
}

lint_anchor_twice <- function(ctx) {
  idx <- project_index(ctx)
  a <- idx$anchors
  a <- a[!a$derived, , drop = FALSE]
  if (!nrow(a)) return(dl_empty())
  a <- a[order(a$file, a$start, method = "radix"), , drop = FALSE]
  first <- !duplicated(a$id)
  later <- a[!first, , drop = FALSE]
  if (!nrow(later)) return(dl_empty())
  firsts <- a[match(later$id, a$id), , drop = FALSE]
  out <- lapply(seq_len(nrow(later)), function(i) {
    f <- later$file[i]
    src <- idx$srcs[[f]]
    finding_at(src, later$start[i], later$start[i], "anchor-twice", later$id[i],
               sprintf("The anchor `%s` is already defined in %s at line %d (rule 5.7.1).", later$id[i],
                       firsts$file[i], firsts$line[i]),
               "Give one of them another id.",
               context = if (f %in% ctx$files) "prose" else "project")
  })
  bind_findings(out)
}

lint_ref_label <- function(src, ctx) {
  rw <- src$rows
  rg <- src$regions
  rd <- rg[rg$type == "refdef", , drop = FALSE]
  if (!nrow(rw) || !nrow(rd)) return(dl_empty())
  fold <- function(x) gsub("[ \t\n]+", " ", dl_trim(tolower(x)))
  rt <- src_substr(src, rd$start, rd$end)
  lab <- fold(sub("^[ \t]*\\[(.*?)\\]:.*$", "\\1", rt, perl = TRUE))
  k <- which(rw$kind %in% c("n", "if", "sign", "list", "cite", "text", "literal"))
  if (!length(k)) return(dl_empty())
  sp <- rg[rg$type == "span", , drop = FALSE]
  m <- match(rw$fstart[k], sp$start)
  k <- k[!is.na(m)]
  m <- m[!is.na(m)]
  if (!length(k)) return(dl_empty())
  br <- src_substr(src, sp$start[m] + 1L, sp$inner_end[m] - 1L)
  hit <- fold(br) %in% lab
  if (!any(hit)) return(dl_empty())
  s <- sp$start[m][hit]
  finding_at(src, s, sp$end[m][hit], "ref-label", br[hit],
             sprintf("The text of this span, `%s`, is also a reference-definition label in this document, so Pandoc reads it as a link (rule 5.7.1).", br[hit]),
             "Change the text of the span or the label.")
}

lint_anchor_unused <- function(ctx) {
  idx <- project_index(ctx)
  a <- idx$anchors
  a <- a[!a$derived & a$file %in% ctx$files & grepl("^(?:fig|tbl|eq)-|^(?:fig|tab|eq):", a$id, perl = TRUE), , drop = FALSE]
  if (!nrow(a)) return(dl_empty())
  a <- a[!a$id %in% idx$refs$id, , drop = FALSE]
  if (!nrow(a)) return(dl_empty())
  out <- lapply(seq_len(nrow(a)), function(i) {
    finding_at(idx$srcs[[a$file[i]]], a$start[i], a$start[i], "anchor-unused", a$id[i],
               sprintf("The anchor `%s` is never referred to in the project (rule 5.7.2).", a$id[i]),
               "Refer to it, or remove it.")
  })
  bind_findings(out)
}

lint_xref_code <- function(src, ctx) {
  rg <- src$regions[src$regions$type == "code", , drop = FALSE]
  if (!nrow(rg)) return(dl_empty())
  txt <- src_substr(src, rg$start, rg$end)
  inner <- dl_trim(gsub("^`+|`+$", "", txt))
  ok <- grepl(paste0("^-?@(?i:", paste(XREF_PREFIXES, collapse = "|"), ")-", KEY_BODY, "$"), inner, perl = TRUE)
  if (!any(ok)) return(dl_empty())
  tk <- regexpr("@", txt[ok], fixed = TRUE)
  s <- rg$start[ok] + as.integer(tk) - 1L
  txt_ref <- sub("^-", "", inner[ok])
  finding_at(src, s, rg$end[ok], "xref-code", txt_ref,
             sprintf("`%s` is written inside a code span, so it prints as literal text and is no cross-reference (rule 5.7.2).", txt_ref),
             "Remove the backticks.")
}

# ---- hygiene (L34) -------------------------------------------------------------------------------------

lint_section_anchor <- function(src, ctx) {
  b <- src$blocks[src$blocks$type == "heading", , drop = FALSE]
  if (!nrow(b)) return(dl_empty())
  out <- list()
  # a heading inside a callout or a tabset div is a title or a tab, not a section (review 3, question 4)
  dv <- src$divs
  if (!is.null(dv) && nrow(dv)) {
    dv <- dv[grepl("(?<![A-Za-z0-9-])callout(?:-[a-z]+)?(?![A-Za-z0-9])|panel-tabset", src$lines[dv$open], perl = TRUE), , drop = FALSE]
  }
  for (i in seq_len(nrow(b))) {
    if (!is.null(dv) && nrow(dv) && any(dv$open < b$line[i] & dv$close > b$line[i])) next
    t <- src_substr(src, b$start[i], b$end[i])
    off <- 0L
    atx <- regexpr("^ {0,3}#{1,6}[ \t]+", t, perl = TRUE)
    if (atx > 0L) {
      off <- attr(atx, "match.length")
      t <- substring(t, off + 1L)
      t <- sub("[ \t]+#+[ \t]*$", "", t, perl = TRUE)
    } else {
      lead <- nchar(t) - nchar(sub("^[ \t]+", "", t))
      off <- lead
      t <- substring(t, lead + 1L)
    }
    t <- sub("[ \t\n]+$", "", t)
    am <- regexpr("\\{[^{}]*\\}[ \t]*$", t, perl = TRUE)
    if (am > 0L) {
      attr_txt <- substring(t, am)
      if (grepl("(^\\{|[ \t])#[^ \t{}]", dl_unquote(attr_txt), perl = TRUE)) next
      t <- sub("[ \t]+$", "", substr(t, 1L, am - 1L))
    }
    t <- gsub("[ \t]*\n[ \t]*", " ", t)
    if (!nzchar(t)) next
    pos <- b$start[i] + off
    out[[length(out) + 1L]] <- finding_at(
      src, pos, b$end[i], "section-anchor", t,
      sprintf("The heading `%s` has no `{#id}` (rule 5.8.1).", t),
      "Give it an id, for example `{#sec-name}`.")
  }
  bind_findings(out)
}

lint_chunk_label <- function(src, ctx) {
  ch <- src$chunks
  if (!nrow(ch)) return(dl_empty())
  k <- which(!ch$explicit & !isFALSE_vec(ch$eval) & nzchar(ch$engine))
  if (!length(k)) return(dl_empty())
  first <- vapply(k, function(i) {
    cd <- ch$code[[i]]
    cd <- cd[!grepl("^[ \t]*(#.*)?$", cd)]
    if (length(cd)) dl_trim(cd[1L]) else if (length(ch$code[[i]])) dl_trim(ch$code[[i]][1L]) else ""
  }, "")
  txt <- dl_trim(paste(ch$engine[k], first))
  pos <- src$line_start[ch$open[k]]
  finding_at(src, pos, pos, "chunk-label", txt,
             sprintf("The %s chunk `%s` has no label (rule 5.8.1).", ch$engine[k], first),
             "Give the chunk a label, as `#| label: name`.", context = "chunk")
}

isFALSE_vec <- function(x) !is.na(x) & !x

lint_file_link <- function(src, ctx) {
  lk <- doc_links(src)
  if (!nrow(lk)) return(dl_empty())
  tg <- lk$target
  skip <- !nzchar(tg) | startsWith(tg, "#") | startsWith(tg, "//") | grepl("^[A-Za-z][A-Za-z0-9+.-]*:", tg)
  lk <- lk[!skip, , drop = FALSE]
  if (!nrow(lk)) return(dl_empty())
  path <- sub("[?#].*$", "", lk$target)
  lk <- lk[nzchar(path), , drop = FALSE]
  path <- path[nzchar(path)]
  if (!nrow(lk)) return(dl_empty())
  dec <- vapply(path, function(p) tryCatch(utils::URLdecode(p), error = function(e) p), "", USE.NAMES = FALSE)
  base <- dl_dir(src$file)
  full <- ifelse(startsWith(dec, "/"), file.path(ctx$root, sub("^/+", "", dec)),
                 if (base == ".") file.path(ctx$root, dec) else file.path(ctx$root, base, dec))
  gone <- !file.exists(full)
  # a link to a rendered page passes when its source document is beside it (review 3, question 3)
  html <- gone & grepl("\\.html?$", full, ignore.case = TRUE)
  if (any(html)) {
    stem <- sub("\\.html?$", "", full[html], ignore.case = TRUE)
    gone[html] <- !vapply(stem, function(z) any(file.exists(paste0(z, c(".qmd", ".Rmd", ".rmd", ".md")))), NA)
  }
  if (!any(gone)) return(dl_empty())
  finding_at(src, lk$start[gone], lk$start[gone] + nchar(lk$target[gone]) - 1L, "file-link", path[gone],
             sprintf("The link target `%s` names no file (rule 5.8.4).", path[gone]),
             "Correct the path, which is read from this document's folder.")
}

# project files a `weft:` key must not sit in, and the keys of a document's `weft:` that belong in
# `_weft.yml`
lint_config_place <- function(ctx) {
  root <- ctx$root
  out <- list()
  yfiles <- project_doc_paths(root, "lint", "^(_quarto|_metadata)\\.ya?ml$")
  for (f in yfiles) {
    lines <- tryCatch(read_source_lines(file.path(root, f)), error = function(e) character())
    h <- which(grepl("^weft[ \t]*:", lines))
    if (!length(h)) next
    out[[length(out) + 1L]] <- new_findings(
      file = f, line = h, col = 1L, end_line = h, rule = "config-place", context = "project", text = "weft",
      message = sprintf("The `weft:` key is in %s; project settings belong in _weft.yml (rule 5.8.8).", basename(f)),
      hint = "Move the settings to _weft.yml, or to a document's own front matter.")
  }
  if (file.exists(file.path(root, "_weft.yml"))) {
    for (f in ctx$report) {
      src <- tryCatch(ctx$source(f), error = function(e) NULL)
      if (is.null(src) || isTRUE(src$invalid)) next
      for (m in src$meta) {
        w <- m$yaml$weft
        if (!is.list(w) || is.null(names(w))) next
        keys <- intersect(names(w), CONFIG_PLACE_KEYS)
        for (key in keys) {
          idx <- m$open:m$close
          ln <- NA_integer_
          h <- which(grepl(paste0("^[ \t]+", key, "[ \t]*:"), src$lines[idx]))
          if (length(h)) {
            ln <- idx[h[1L]]
            pos <- src$line_start[ln] + regexpr(key, src$lines[ln], fixed = TRUE) - 1L
          } else {
            h <- which(grepl(paste0("^weft[ \t]*:.*\\b", key, "\\b"), src$lines[idx], perl = TRUE))
            ln <- if (length(h)) idx[h[1L]] else m$open
            pos <- src$line_start[ln] + max(0L, regexpr(key, src$lines[ln], fixed = TRUE) - 1L)
          }
          out[[length(out) + 1L]] <- finding_at(
            src, pos, pos + nchar(key) - 1L, "config-place", key,
            sprintf("The setting `%s` is in this document's `weft:` key, but the project has an _weft.yml, which is where it belongs (rule 5.8.8).", key),
            "Move it to _weft.yml.", context = "front-matter")
        }
      }
    }
  }
  bind_findings(out)
}

# Files that other documents include or take as a child, as project-relative paths.
project_included <- function(ctx) {
  cache <- lint_cache(ctx)
  if (!is.null(cache$included)) return(cache$included)
  inc <- character()
  for (f in ctx$files) {
    txt <- tryCatch(read_source_text_or_null(ctx$path(f)), error = function(e) NULL)
    if (is.null(txt) || !nzchar(txt)) next
    dir <- dl_dir(f)
    paths <- character()
    m <- gregexpr("\\{\\{<[ \t]*include[ \t]+([^ \t>]+)[ \t]*>\\}\\}", txt, perl = TRUE)
    paths <- c(paths, regmatches(txt, m)[[1L]])
    paths <- sub("^\\{\\{<[ \t]*include[ \t]+([^ \t>]+)[ \t]*>\\}\\}$", "\\1", paths, perl = TRUE)
    ch <- regmatches(txt, gregexpr("child[ \t]*=[ \t]*(?:c\\([^)]*\\)|\"[^\"]*\"|'[^']*')", txt, perl = TRUE))[[1L]]
    ch2 <- regmatches(txt, gregexpr("#\\|[ \t]*child[ \t]*:[^\n]*", txt, perl = TRUE))[[1L]]
    q <- regmatches(c(ch, ch2), gregexpr("[^\"'\\s,()=:|#\\[\\]]+\\.(?:qmd|Rmd|rmd|md)", c(ch, ch2), perl = TRUE))
    paths <- c(paths, unlist(q))
    paths <- gsub("^[\"']|[\"']$", "", paths)
    for (p in paths) {
      rel <- if (startsWith(p, "/")) dl_join("", substring(p, 2L)) else dl_join(dir, p)
      if (!is.na(rel) && !identical(rel, f)) inc <- c(inc, rel)
    }
  }
  inc <- unique(inc)
  cache$included <- inc
  inc
}

lint_engine <- function(ctx) {
  out <- list()
  inc <- NULL
  for (f in ctx$report) {
    if (tolower(sub("^.*\\.", "", f)) != "qmd") next
    if (startsWith(basename(f), "_")) next
    src <- tryCatch(ctx$source(f), error = function(e) NULL)
    if (is.null(src) || isTRUE(src$invalid)) next
    rw <- src$rows
    if (!nrow(rw) || !any(!rw$kind %in% c("bare", "link", "literal"))) next
    eng <- src$front$engine
    if (is.character(eng) && length(eng) == 1L && identical(tolower(eng), "knitr")) next
    if (is.null(inc)) inc <- project_included(ctx)
    if (f %in% inc) next
    out[[length(out) + 1L]] <- new_findings(
      file = f, line = 1L, col = 1L, end_line = 1L, rule = "engine", context = "project", text = f,
      message = sprintf("%s holds weft constructs but is not marked `engine: knitr` and no document includes it (rule 5.8.9).", f),
      hint = "Add `engine: knitr` to its front matter.")
  }
  bind_findings(out)
}

# ---- figures and tables (L35) ----------------------------------------------------------------------------

dl_has_option <- function(opts, keys) {
  for (k in keys) {
    v <- opts[[k]]
    # a block scalar (`|`, `>`) carries its text on the lines below
    if (!is.null(v) && length(v) && any(grepl("^[|>][+-]?$", dl_trim(v)))) return(TRUE)
    if (!is.null(v) && length(v) && any(nzchar(dl_trim(gsub("[\"']", "", paste(v, collapse = " ")))))) return(TRUE)
    if (!is.null(v) && length(v) && any(grepl("!expr|^[A-Za-z_.]+\\(", paste(v, collapse = " ")))) return(TRUE)
  }
  FALSE
}

# the attribute block straight after an offset (as a string, "" when none)
dl_attr_after <- function(src, pos) {
  t <- src_substr(src, pos + 1L, pos + 400L)
  m <- regmatches(t, regexpr("^\\{[^{}\n]*\\}", t, perl = TRUE))
  if (length(m)) m else ""
}

dl_fig_divs <- function(src, prefix) {
  d <- src$divs
  if (is.null(d) || !nrow(d)) return(data.frame(open = integer(), close = integer(), id = character(), stringsAsFactors = FALSE))
  id <- vapply(d$id, function(a) {
    m <- regmatches(a, regexec(paste0("(?:^|[{ \t])#(", prefix, "-[^ \t{}\"']+)"), a, perl = TRUE))[[1L]]
    if (length(m)) m[2L] else NA_character_
  }, "", USE.NAMES = FALSE)
  d <- d[!is.na(id), , drop = FALSE]
  d$id <- id[!is.na(id)]
  d
}

lint_figure <- function(src, ctx) {
  out <- list()
  add <- function(pos, text, part, msg_text, hint) {
    out[[length(out) + 1L]] <<- finding_at(src, pos, pos, "figure", text, msg_text, hint,
                                           context = if (part == "chunk") "chunk" else "prose")
  }
  ls <- src$line_start
  # chunks
  ch <- src$chunks
  for (k in seq_len(nrow(ch))) {
    if (!isTRUE(ch$eval[k])) next
    opts <- ch$options[[k]]
    lab <- if (isTRUE(ch$explicit[k])) ch$label[k] else NA_character_
    has_cap <- dl_has_option(opts, c("fig-cap", "fig.cap"))
    is_fig <- (!is.na(lab) && startsWith(lab, "fig-")) || has_cap
    if (!is_fig) next
    nm <- if (!is.na(lab)) lab else {
      cd <- ch$code[[k]]
      if (length(cd)) dl_trim(cd[1L]) else ch$engine[k]
    }
    pos <- ls[ch$open[k]]
    ref <- sprintf("The figure `%s`", nm)
    if (!is_rmd(src) && (is.na(lab) || !startsWith(lab, "fig-"))) {
      add(pos, nm, "chunk", sprintf("%s has no label starting `fig-` (rule 5.9.1).", ref),
          "Label the chunk `fig-name`.")
    }
    if (!has_cap) {
      add(pos, nm, "chunk", sprintf("%s has no caption (rule 5.9.1).", ref), "Add a `fig-cap` option.")
    }
    if (!dl_has_option(opts, c("fig-alt", "fig.alt"))) {
      add(pos, nm, "chunk", sprintf("%s has no alt text (rule 5.9.1).", ref), "Add a `fig-alt` option.")
    }
  }
  # divs
  fd <- dl_fig_divs(src, "fig")
  rg <- src$regions
  im <- rg[rg$type == "image", , drop = FALSE]
  lk <- doc_links(src)
  in_div <- rep(FALSE, nrow(im))
  imline <- if (nrow(im)) src_line_of(src, im$start) else integer()
  for (i in seq_len(nrow(fd))) {
    inside <- which(imline > fd$open[i] & imline < fd$close[i])
    in_div[inside] <- TRUE
    pos <- ls[fd$open[i]]
    blk <- src$blocks
    cb <- blk[blk$type == "caption" & blk$line > fd$open[i] & blk$end_line < fd$close[i], , drop = FALSE]
    has_cap <- FALSE
    for (j in seq_len(nrow(cb))) {
      t <- src_substr(src, cb$start[j], cb$end[j])
      t <- gsub("!\\[.*?\\]\\([^)]*\\)(\\{[^{}]*\\})?", "", t, perl = TRUE)
      if (nzchar(dl_trim(t))) has_cap <- TRUE
    }
    chin <- which(ch$open > fd$open[i] & ch$close < fd$close[i])
    if (!has_cap && length(chin) && any(vapply(chin, function(k) dl_has_option(ch$options[[k]], c("fig-cap", "fig.cap")), NA))) has_cap <- TRUE
    ref <- sprintf("The figure `%s`", fd$id[i])
    if (!has_cap) add(pos, fd$id[i], "div", sprintf("%s has no caption (rule 5.9.1).", ref), "Add the caption as the div's last paragraph.")
    alt_ok <- NA
    if (length(inside)) {
      alt_ok <- FALSE
      for (j in inside) {
        br <- sub("(?s)^!\\[(.*)\\]\\(.*$", "\\1", src_substr(src, im$start[j], im$end[j]), perl = TRUE)
        at <- dl_attr_after(src, im$end[j])
        if (nzchar(dl_trim(br)) || grepl("fig-alt[ \t]*=[ \t]*[\"'][^\"']", at)) alt_ok <- TRUE
      }
    }
    if (length(chin)) {
      calt <- any(vapply(chin, function(k) dl_has_option(ch$options[[k]], c("fig-alt", "fig.alt")), NA))
      alt_ok <- if (is.na(alt_ok)) calt else (alt_ok || calt)
    }
    if (isFALSE(alt_ok)) add(pos, fd$id[i], "div", sprintf("%s has no alt text (rule 5.9.1).", ref), "Give the image bracket text or a `fig-alt` attribute.")
  }
  # images alone in their paragraph
  if (nrow(im)) {
    blk <- src$blocks
    paras <- blk[blk$type == "para", , drop = FALSE]
    for (j in seq_len(nrow(im))) {
      if (in_div[j]) next
      p <- which(paras$start <= im$start[j] & paras$end >= im$end[j])
      if (!length(p)) next
      p <- p[1L]
      before <- src_substr(src, paras$start[p], im$start[j] - 1L)
      after <- src_substr(src, im$end[j] + 1L, paras$end[p])
      at <- dl_attr_after(src, im$end[j])
      if (nzchar(at)) after <- substring(after, nchar(at) + 1L)
      if (nzchar(dl_trim(before)) || nzchar(dl_trim(after))) next
      br <- sub("(?s)^!\\[(.*)\\]\\(.*$", "\\1", src_substr(src, im$start[j], im$end[j]), perl = TRUE)
      tg <- lk$target[lk$rstart == im$start[j]]
      tg <- if (length(tg)) tg[1L] else ""
      atq <- dl_unquote(at)
      has_id <- grepl("(^\\{|[ \t])#fig-[^ \t{}]", atq, perl = TRUE)
      has_alt <- grepl("fig-alt[ \t]*=[ \t]*[\"'][^\"']", at)
      empty_br <- !nzchar(dl_trim(br))
      pos <- im$start[j]
      ref <- sprintf("The figure `%s`", tg)
      if (empty_br) {
        if (!has_alt) add(pos, tg, "image", sprintf("%s has no alt text (rule 5.9.1).", ref), "Give the image bracket text or a `fig-alt` attribute.")
      } else if (!has_id) {
        add(pos, tg, "image", sprintf("%s has no label starting `fig-` (rule 5.9.1).", ref), "Add `{#fig-name}` after the image.")
      }
    }
  }
  bind_findings(out)
}

lint_table_caption <- function(src, ctx) {
  out <- list()
  ls <- src$line_start
  lines <- src$lines
  nl <- length(lines)
  add <- function(pos, text, ref) {
    out[[length(out) + 1L]] <<- finding_at(
      src, pos, pos, "table-caption", text, sprintf("The table `%s` has no caption (rule 5.9.1).", ref),
      "Add a caption line `: Caption {#tbl-name}` after the table.", spec = "5.9.1")
  }
  td <- dl_fig_divs(src, "tbl")
  ch <- src$chunks
  blk <- src$blocks
  # divs
  for (i in seq_len(nrow(td))) {
    cb <- blk[blk$type == "caption" & blk$line > td$open[i] & blk$end_line < td$close[i], , drop = FALSE]
    has_cap <- nrow(cb) > 0L
    chin <- which(ch$open > td$open[i] & ch$close < td$close[i])
    if (!has_cap && length(chin)) has_cap <- any(vapply(chin, function(k) dl_has_option(ch$options[[k]], c("tbl-cap", "tbl.cap")), NA))
    if (!has_cap) add(ls[td$open[i]], td$id[i], td$id[i])
  }
  # pipe and grid tables
  tb <- src$regions[src$regions$type == "table", , drop = FALSE]
  for (i in seq_len(nrow(tb))) {
    l0 <- src_line_of(src, tb$start[i])
    l1 <- src_line_of(src, tb$end[i])
    if (nrow(td) && any(td$open < l0 & td$close > l1)) next
    isblank <- function(l) !nzchar(dl_trim(lines[l]))
    cap_re <- "^[ \t]{0,3}(?::|[Tt]able:)[ \t]+\\S"
    has_cap <- FALSE
    j <- l1 + 1L
    while (j <= nl && isblank(j)) j <- j + 1L
    if (j <= nl && j - l1 <= 2L && grepl(cap_re, lines[j], perl = TRUE)) has_cap <- TRUE
    j <- l0 - 1L
    while (j >= 1L && isblank(j)) j <- j - 1L
    if (!has_cap && j >= 1L && l0 - j <= 2L && grepl(cap_re, lines[j], perl = TRUE)) has_cap <- TRUE
    if (!has_cap) add(tb$start[i], dl_trim(lines[l0]), dl_trim(lines[l0]))
  }
  # chunks labelled tbl-
  if (!is_rmd(src)) {
    for (k in seq_len(nrow(ch))) {
      if (!isTRUE(ch$eval[k]) || !isTRUE(ch$explicit[k]) || !startsWith(ch$label[k], "tbl-")) next
      if (!dl_has_option(ch$options[[k]], c("tbl-cap", "tbl.cap"))) add(ls[ch$open[k]], ch$label[k], ch$label[k])
    }
  }
  bind_findings(out)
}

# ---- tier-2 findings for changes() (L40, L41) --------------------------------------------------------------

# Lines added since `commit` in each document: a named list of integer vectors (file -> lines).
changes_added_lines <- function(root, commit, docs) {
  have <- !is.na(commit)
  changed <- docs
  untracked_all <- character()
  if (have) {
    d <- raw_records(git_ok(root, c("diff", "--name-only", "-z", "--relative", commit, "--"))$out)
    u <- raw_records(git_ok(root, c("ls-files", "--others", "--exclude-standard", "-z"))$out)
    changed <- intersect(docs, unique(c(d, u)))
    untracked_all <- u
  }
  res <- list()
  for (f in changed) {
    n <- length(strsplit(read_source_text_or_null(file.path(root, f)) %||% "", "\n", fixed = TRUE)[[1L]])
    whole <- !have || f %in% untracked_all ||
      !identical(git_raw(root, c("cat-file", "-e", paste0(commit, ":./", f)))$status, 0L)
    if (whole) {
      res[[f]] <- seq_len(n)
      next
    }
    dd <- raw_lines(git_ok(root, c("diff", "-U0", "--no-color", "--no-ext-diff", commit, "--", f))$out)
    h <- regmatches(dd, regexec("^@@ -[0-9]+(?:,[0-9]+)? \\+([0-9]+)(?:,([0-9]+))? @@", dd, perl = TRUE))
    h <- Filter(length, h)
    add <- integer()
    for (z in h) {
      c0 <- as.integer(z[2L])
      d0 <- if (nzchar(z[3L])) as.integer(z[3L]) else 1L
      if (d0 > 0L) add <- c(add, c0:(c0 + d0 - 1L))
    }
    res[[f]] <- add
  }
  res
}

# The tier-2 findings over added material, as the four-column table `changes()` keeps, and notes.
changes_tier2 <- function(root, commit, files = NULL) {
  empty <- data.frame(file = character(), line = integer(), rule = character(), message = character(),
                      stringsAsFactors = FALSE)
  docs <- tryCatch(lint_files_under(root), error = function(e) e)
  if (inherits(docs, "error")) {
    return(list(table = empty, notes = paste0("tier-2 findings were not listed: ", conditionMessage(docs))))
  }
  if (!is.null(files)) docs <- intersect(docs, files)
  if (!length(docs)) return(list(table = empty, notes = character()))
  added <- tryCatch(changes_added_lines(root, commit, docs), weft_gate_error = function(e) NULL)
  if (is.null(added)) return(list(table = empty, notes = "tier-2 findings were not listed: git could not give the added lines"))
  added <- added[vapply(added, length, 1L) > 0L]
  if (!length(added)) return(list(table = empty, notes = character()))
  f <- tryCatch(lints(root, files = names(added), tier = 2), error = function(e) e)
  if (inherits(f, "error")) {
    return(list(table = empty, notes = paste0("tier-2 findings were not listed: ", conditionMessage(f))))
  }
  notes <- character()
  if (!nrow(f)) return(list(table = empty, notes = notes))
  f <- as.data.frame(unclass(f), stringsAsFactors = FALSE)
  keep <- vapply(seq_len(nrow(f)), function(i) {
    a <- added[[f$file[i]]]
    !is.null(a) && any(a >= f$line[i] & a <= f$end_line[i])
  }, NA)
  f <- f[keep, , drop = FALSE]
  if (!nrow(f)) return(list(table = empty, notes = notes))
  f$message <- ifelse(f$rule == "claim-word" & !is.na(f$sentence),
                      ifelse(endsWith(f$message, paste0("\"", f$sentence, "\"")), f$message,
                             paste0(f$message, " \"", f$sentence, "\"")), f$message)
  rows <- list()
  for (file in unique(f$file)) {
    d <- f[f$file == file, , drop = FALSE]
    cw <- d$rule == "claim-word"
    cap <- tryCatch(lint_config(root, doc_front(file.path(root, file)))$claim_cap, error = function(e) 20L)
    if (is.null(cap) || !is.numeric(cap)) cap <- 20L
    if (sum(cw) > cap) {
      first <- d[cw, , drop = FALSE]
      first <- first[order(first$line), , drop = FALSE][1L, ]
      d <- rbind(d[!cw, , drop = FALSE],
                 data.frame(file = file, line = first$line, col = first$col, end_line = first$end_line, rule = "claim-word",
                            tier = 2L, spec = "5.5.3", context = "prose", text = "",
                            message = sprintf("%d added sentences hold claim words; more than the cap of %d, so they are counted, not listed (rule 5.5.3).",
                                              sum(cw), as.integer(cap)),
                            hint = NA_character_, sentence = NA_character_, stringsAsFactors = FALSE)[, names(d)])
    }
    rows[[length(rows) + 1L]] <- d
  }
  r <- do.call(rbind, rows)
  r <- r[order(r$file, r$line, r$rule, method = "radix"), c("file", "line", "rule", "message"), drop = FALSE]
  r$line <- as.integer(r$line)
  rownames(r) <- NULL
  list(table = r, notes = notes)
}
