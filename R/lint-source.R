# The source reader for the static lints (design-3 L9-L12): one document as
# text, rows (the scanner's, with file offsets), a prose mask, regions,
# blocks, executed chunks and metadata. Nothing here runs document code.

# ---- offsets -------------------------------------------------------------------

# The 1-based line of each file offset (NA stays NA).
src_line_of <- function(src, pos) findInterval(pos, src$line_start)

# The 1-based column, in characters, of each file offset.
src_col_of <- function(src, pos) {
  l <- findInterval(pos, src$line_start)
  as.integer(pos - src$line_start[pmax(l, 1L)] + 1)
}

# Pieces of a text by character offset: `substring(text, start, stop)`. For a text with non-ASCII
# characters substring() walks the string from its start for every piece, so a document's worth of
# pieces is quadratic. The cutter splits such a text into characters once and cuts from those.
text_cutter <- function(text) {
  if (nchar(text, "bytes") == nchar(text)) return(function(start, stop) substring(text, start, stop))
  chars <- strsplit(text, "")[[1L]]
  function(start, stop) {
    if (!length(start) || !length(stop)) return(character())
    k <- max(length(start), length(stop))
    start <- pmax(rep_len(start, k), 1L)
    stop <- pmin(rep_len(stop, k), length(chars))
    vapply(seq_len(k), function(i) {
      if (is.na(start[i]) || is.na(stop[i])) NA_character_
      else if (start[i] > stop[i]) ""
      else paste(chars[start[i]:stop[i]], collapse = "")
    }, "")
  }
}

# The same for a source's own text; the cutter is kept on the source, so it goes with it.
src_substr <- function(src, start, stop) {
  if (is.null(src$cache)) return(substring(src$text, start, stop))
  if (is.null(src$cache$cut)) src$cache$cut <- text_cutter(src$text)
  src$cache$cut(start, stop)
}

# Logical vector of length n, TRUE inside any [starts[i], ends[i]].
mark_ranges <- function(n, starts, ends) {
  ok <- !is.na(starts) & !is.na(ends) & ends >= starts
  starts <- pmax(starts[ok], 1)
  ends <- pmin(ends[ok], n)
  if (!length(starts) || n == 0L) return(rep(FALSE, n))
  d <- tabulate(starts, n + 1L) - tabulate(ends + 1L, n + 1L)
  cumsum(d)[seq_len(n)] > 0
}

gmatch <- function(pat, x) {
  m <- gregexpr(pat, x, perl = TRUE)[[1L]]
  if (m[1L] == -1L) return(list(s = integer(), e = integer(), cs = NULL))
  ml <- attr(m, "match.length")
  list(s = as.integer(m), e = as.integer(m) + ml - 1L,
       cs = attr(m, "capture.start"))
}

# The first of `groups` that matched, for each match.
match_type <- function(g, groups) {
  if (!length(g$s)) return(character())
  hit <- g$cs[, groups, drop = FALSE] > 0
  vapply(seq_len(nrow(hit)), function(i) groups[which(hit[i, ])[1L]], "")
}

# ---- regions -------------------------------------------------------------------

new_regions <- function(type = character(), start = integer(), end = integer(),
                        row = NA_integer_, name = NA_character_) {
  n <- length(start)
  if (!n) type <- character()
  data.frame(type = rep_len(type, n), start = as.integer(start), end = as.integer(end),
             row = rep_len(as.integer(row), n), name = rep_len(as.character(name), n),
             inner_start = rep(NA_integer_, n), inner_end = rep(NA_integer_, n),
             attr_start = rep(NA_integer_, n), attr_end = rep(NA_integer_, n),
             stringsAsFactors = FALSE)
}

# Add the parsed classes, keys and id of the attribute text `a` as list columns.
with_attrs <- function(r, a) {
  n <- nrow(r)
  r$classes <- vector("list", n)
  r$keys <- vector("list", n)
  r$id <- vector("list", n)
  if (!n) return(r)
  a0 <- gsub("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'", "\"\"", a, perl = TRUE)
  ex <- function(pat, grp = 0L) lapply(seq_len(n), function(i) {
    if (is.na(a0[i])) return(character())
    m <- gregexpr(pat, a0[i], perl = TRUE)[[1L]]
    if (m[1L] == -1L) return(character())
    st <- if (grp) attr(m, "capture.start")[, grp] else as.integer(m)
    ln <- if (grp) attr(m, "capture.length")[, grp] else attr(m, "match.length")
    substring(a0[i], st, st + ln - 1L)
  })
  r$classes <- ex("(?<![\\w-])\\.[A-Za-z][\\w.-]*")
  r$keys <- ex("(?<![\\w.#-])([A-Za-z][\\w:-]*)\\s*=", 1L)
  r$id <- ex("#([^\\s\"{}]+)", 1L)
  r
}

# ---- the file -------------------------------------------------------------------

lint_rel_path <- function(path, root) {
  p <- normalizePath(path, winslash = "/", mustWork = FALSE)
  r <- normalizePath(root, winslash = "/", mustWork = FALSE)
  enc2utf8(if (startsWith(p, paste0(r, "/"))) substring(p, nchar(r) + 2L) else p)
}

# All the fenced blocks: open and close lines, and the text after the fence.
fence_blocks <- function(lines, inmeta) {
  n <- length(lines)
  empty <- data.frame(open = integer(), close = integer(), info = character(),
                      stringsAsFactors = FALSE)
  cand <- which(!inmeta & grepl("^[ \t>]*(`{3,}|~{3,})", lines))
  if (!length(cand)) return(empty)
  m <- regmatches(lines[cand], regexec("^[ \t>]*(`{3,}|~{3,})(.*)$", lines[cand]))
  fch <- vapply(m, function(x) substr(x[2L], 1L, 1L), "")
  fln <- vapply(m, function(x) nchar(x[2L]), 1L)
  info <- trimws(vapply(m, function(x) x[3L], ""))
  closer <- grepl("^[ \t>]*(`{3,}|~{3,})[ \t\r]*$", lines[cand])
  open <- integer()
  close <- integer()
  inf <- character()
  last <- 0L
  for (i in seq_along(cand)) {
    k <- cand[i]
    if (k <= last) next
    if (fch[i] == "`" && grepl("`", info[i], fixed = TRUE) && !grepl("^\\{.*\\}$", info[i])) next
    j <- which(closer & cand > k & fch == fch[i] & fln >= fln[i])[1L]
    cl <- if (is.na(j)) n else cand[j]
    open <- c(open, k)
    close <- c(close, cl)
    inf <- c(inf, info[i])
    last <- cl
  }
  data.frame(open = open, close = close, info = inf, stringsAsFactors = FALSE)
}

# YAML read for the lints: `!expr` kept as text, nothing evaluated.
yaml_text <- function(x) {
  tryCatch(yaml_read_text(x), error = function(e) NULL)
}

# ---- chunks ---------------------------------------------------------------------

chunk_table <- function(lines, chs) {
  n <- length(lines)
  cols <- function(f, type) vapply(chs, f, type)
  eval_of <- function(ch) {
    v <- NULL
    for (o in ch$optblk) if (o$name == "eval") v <- static_option_value(o$value, expr = o$form == "expr")
    h <- ch$hdr$opts$eval
    if (is.null(v) && !is.null(h)) v <- static_option_value(h$text, expr = TRUE)
    !(!is.null(v) && falsy(v))
  }
  cache_of <- function(ch) {
    v <- NULL
    for (o in ch$optblk) if (o$name == "cache") v <- static_option_value(o$value, expr = o$form == "expr")
    h <- ch$hdr$opts$cache
    if (is.null(v) && !is.null(h)) v <- static_option_value(h$text, expr = TRUE)
    if (is.null(v)) return(NA)
    if (falsy(v)) FALSE else if (is.logical(v) || is.character(v) && tolower(v) %in% c("true", "yes")) isTRUE(truthy(v)) || NA else NA
  }
  explicit_of <- function(ch) {
    (!is.na(ch$hdr$label) && nzchar(ch$hdr$label)) || any(vapply(ch$optblk, function(o) o$name == "label", NA))
  }
  options_of <- function(ch) {
    o <- lapply(ch$hdr$opts, function(x) x$text)
    for (b in ch$optblk) o[[b$name]] <- b$value
    o
  }
  code_of <- function(ch) {
    from <- ch$oi$code_first
    to <- min(ch$close, n + 1L) - 1L
    if (!ch$closed) to <- n
    if (to >= from) lines[from:to] else character()
  }
  codes <- lapply(chs, code_of)
  data.frame(
    open = cols(function(ch) as.integer(ch$open), 0L),
    close = cols(function(ch) as.integer(min(ch$close, n)), 0L),
    engine = cols(function(ch) ch$engine, ""),
    label = cols(function(ch) ch$label, ""),
    explicit = cols(explicit_of, NA),
    eval = cols(eval_of, NA),
    cache = cols(cache_of, NA),
    options = I(lapply(chs, options_of)),
    code = I(codes),
    code_first = vapply(codes, function(x) if (length(x)) x[1L] else NA_character_, ""),
    code_line = cols(function(ch) as.integer(ch$oi$code_first), 0L),
    stringsAsFactors = FALSE)[, c("open", "close", "engine", "label", "explicit", "eval",
                                  "cache", "options", "code", "code_first", "code_line")]
}

# ---- string constants in chunk code -----------------------------------------------

# The string literals of R code that are inside calls to `fns` (all of them,
# less those that are names), or inside the first argument of `weft_str()`. A
# data frame: file offset of the contents' first character, the contents as typed,
# the token text, the file line of the string and the call.
chunk_literals <- function(code, first_line, ls, which = c("weft_str", "phrase")) {
  which <- match.arg(which)
  out <- data.frame(start = numeric(), raw = character(), token = character(),
                    line = integer(), stringsAsFactors = FALSE)
  fns <- if (which == "weft_str") "weft_str" else c("lookup", "brk")
  if (!length(code) || !any(vapply(fns, function(f) any(grepl(f, code, fixed = TRUE)), NA))) return(out)
  p <- tryCatch(parse(text = paste(code, collapse = "\n"), keep.source = TRUE), error = function(e) NULL)
  if (is.null(p)) return(out)
  pd <- utils::getParseData(p)
  if (is.null(pd)) return(out)
  fn <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% fns, , drop = FALSE]
  if (!nrow(fn)) return(out)
  par <- stats::setNames(pd$parent, pd$id)
  root_ids <- integer()
  for (id in fn$id) {
    fexpr <- pd$parent[pd$id == id]
    call_id <- pd$parent[pd$id == fexpr]
    if (!length(call_id) || call_id == 0L) next
    if (which == "weft_str") {
      kids <- pd[pd$parent == call_id, , drop = FALSE]
      kids <- kids[order(kids$line1, kids$col1), , drop = FALSE]
      pos <- which(kids$token == "'('")[1L]
      if (is.na(pos)) next
      after <- kids[seq_len(nrow(kids)) > pos, , drop = FALSE]
      ex <- which(after$token == "expr")[1L]
      if (is.na(ex)) next
      root_ids <- c(root_ids, after$id[ex])
    } else {
      root_ids <- c(root_ids, call_id)
    }
  }
  if (!length(root_ids)) return(out)
  sc <- pd[pd$token == "STR_CONST", , drop = FALSE]
  if (!nrow(sc)) return(out)
  inside <- vapply(sc$id, function(i) {
    cur <- par[[as.character(i)]]
    while (!is.na(cur) && cur != 0L) {
      if (cur %in% root_ids) return(TRUE)
      cur <- par[[as.character(cur)]]
    }
    FALSE
  }, NA)
  sc <- sc[inside, , drop = FALSE]
  if (!nrow(sc)) return(out)
  # a string that is a name (`"a" = ...`) is not one of the phrases
  nxt <- vapply(seq_len(nrow(sc)), function(k) {
    sib <- pd[pd$parent == sc$parent[k] & (pd$line1 > sc$line2[k] | (pd$line1 == sc$line2[k] & pd$col1 > sc$col2[k])), , drop = FALSE]
    if (!nrow(sib)) return(FALSE)
    sib <- sib[order(sib$line1, sib$col1), , drop = FALSE]
    sib$token[1L] %in% c("EQ_SUB", "EQ_ASSIGN")
  }, NA)
  sc <- sc[!nxt, , drop = FALSE]
  sc <- sc[grepl("^[\"'].*[\"']$", sc$text) & !grepl("^\\[[0-9]+ chars", sc$text), , drop = FALSE]
  sc <- sc[order(sc$line1, sc$col1), , drop = FALSE]
  if (!nrow(sc)) return(out)
  line <- first_line + sc$line1 - 1L
  cc <- vapply(seq_len(nrow(sc)), function(k) {
    parse_col_chars(code[sc$line1[k]], sc$col1[k])
  }, 1L)
  data.frame(start = ls[line] + cc, raw = substr(sc$text, 2L, nchar(sc$text) - 1L),
             token = sc$text, line = as.integer(line), stringsAsFactors = FALSE)
}

# Rows for the strings given to lookup() and brk() (context "phrase").
phrase_rows <- function(lit, chunk_label, file, config) {
  parts <- list()
  for (k in seq_len(nrow(lit))) {
    val <- tryCatch(eval(parse(text = lit$token[k], keep.source = FALSE)[[1L]]), error = function(e) NULL)
    if (!is.character(val) || length(val) != 1L || is.na(val)) next
    r <- scan_rows(val, file = file, first_line = lit$line[k], config = config)
    if (!nrow(r)) next
    off <- lit_offsets(lit$raw[k], lit$start[k])
    if (length(off) != nchar(val)) off <- rep(NA_real_, nchar(val))
    r$fstart <- map_offsets(r$start, off)
    r$fend <- map_offsets(r$end, off)
    r$fblock <- map_offsets(r$block_start, off)
    r$context <- "phrase"
    r$chunk <- chunk_label
    r$option <- NA_character_
    parts[[length(parts) + 1L]] <- r
  }
  bind_scan_rows(parts)
}

# ---- the pieces beside the body (L10) ------------------------------------------------

# Returns a data frame: kind (front, caption, weft_str, phrase), name, start, end
# (file offsets of the characters that are prose), form ("scalar"/"block").
source_pieces <- function(lines, ls, chunks, chs, cfg_file, front_ff) {
  n <- length(lines)
  le <- ls + nchar(lines) - 1
  P <- list()
  gid <- 0L
  add <- function(kind, name, start, end, by_row = FALSE, grp = NULL) {
    ok <- !is.na(start) & !is.na(end) & end >= start
    if (any(ok)) {
      k <- sum(ok)
      g <- if (by_row) gid + seq_len(k) else if (!is.null(grp)) grp else gid + 1L
      if (is.null(grp)) gid <<- gid + (if (by_row) k else 1L)
      P[[length(P) + 1L]] <<- data.frame(kind = kind, name = name, start = start[ok],
                                         end = end[ok], grp = rep_len(g, k),
                                         stringsAsFactors = FALSE)
    }
  }
  # strip wrapping quotes of a one-line scalar: returns the ranges to keep
  value_range <- function(l, from_col) {
    txt <- substring(lines[l], from_col)
    lead <- nchar(txt) - nchar(sub("^[ \t]+", "", txt))
    body <- sub("[ \t]+$", "", sub("^[ \t]+", "", txt))
    s <- ls[l] + from_col - 1 + lead
    e <- s + nchar(body) - 1
    if (nchar(body) >= 2L && grepl("^([\"']).*\\1$", body)) {
      s <- s + 1
      e <- e - 1
    }
    c(s, e)
  }
  # front matter
  ff <- front_ff
  for (i in seq_len(nrow(ff))) {
    if (!(ff$field[i] %in% FM_FIELDS)) next
    if (ff$form[i] == "block") {
      if (ff$first[i] <= ff$last[i]) {
        r <- ff$first[i]:ff$last[i]
        add("front", ff$field[i], ls[r], le[r])
      }
    } else {
      k <- ff$key[i]
      col <- regexpr(":", lines[k], fixed = TRUE) + 1L
      v <- value_range(k, col)
      g0 <- gid + 1L
      add("front", ff$field[i], v[1L], v[2L])
      if (ff$last[i] > k) {
        r <- (k + 1L):ff$last[i]
        add("front", ff$field[i], ls[r], le[r], grp = g0)
      }
    }
  }
  # captions, in executed R chunks
  for (ch in chs) {
    if (!identical(tolower(ch$engine), "r")) next
    after_bar <- function(l) {
      m <- regexpr("^[ \t]*#\\|", lines[l])
      ls[l] + attr(m, "match.length")
    }
    for (o in ch$optblk) {
      if (!(o$name %in% setdiff(CAPTION_OPTIONS, "tab.cap")) || o$form == "expr") next
      if (o$form == "block") {
        if (o$first <= o$last) {
          r <- o$first:o$last
          add("caption", o$name, vapply(r, after_bar, 1), le[r])
        }
      } else if (o$form == "list") {
        for (it in o$items) {
          if (it$form == "block") {
            if (it$first <= it$last) {
              r <- it$first:it$last
              add("caption", o$name, vapply(r, after_bar, 1), le[r])
            }
          } else {
            l <- it$start
            m <- regexpr("^[ \t]*#\\|[ ]?[ \t]*-", lines[l])
            v <- value_range(l, attr(m, "match.length") + 1L)
            g0 <- gid + 1L
            add("caption", o$name, v[1L], v[2L])
            if (it$last > l) {
              r <- (l + 1L):it$last
              add("caption", o$name, vapply(r, after_bar, 1), le[r], grp = g0)
            }
          }
        }
      } else {
        l <- o$key
        m <- regexpr("^[ \t]*#\\|[ ]?[A-Za-z0-9_.-]+[ \t]*:", lines[l])
        v <- value_range(l, attr(m, "match.length") + 1L)
        g0 <- gid + 1L
        add("caption", o$name, v[1L], v[2L])
        if (o$last > l) {
          r <- (l + 1L):o$last
          add("caption", o$name, vapply(r, after_bar, 1), le[r], grp = g0)
        }
      }
    }
    # header literals
    for (nm in names(ch$hdr$opts)) {
      if (!(nm %in% setdiff(CAPTION_OPTIONS, "tab.cap"))) next
      if (is.null(ch$hdr$opts[[nm]]$literal)) {
        ex <- tryCatch(parse(text = ch$hdr$opts[[nm]]$text, keep.source = FALSE)[[1L]],
                       error = function(e) NULL)
        okc <- is.call(ex) && identical(ex[[1L]], as.name("c")) && length(ex) > 1L &&
          all(vapply(as.list(ex)[-1L], is.character, NA))
        if (!isTRUE(okc)) next
      }
      qs <- "\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'"
      nmp <- paste0("(?<![A-Za-z0-9_.])", gsub(".", "\\.", nm, fixed = TRUE), "[ \t]*=[ \t]*")
      hl <- lines[ch$open]
      mm <- regexpr(paste0(nmp, "c[ \t]*\\("), hl, perl = TRUE)
      if (mm > 0L) {
        st <- mm + attr(mm, "match.length")
        rest <- substring(hl, st)
        sm <- gregexpr(qs, rest, perl = TRUE)[[1L]]
        # stop at the closing paren that is outside any string
        for (k in seq_along(sm)) {
          if (sm[k] < 0L) break
          pre <- substr(rest, 1L, sm[k] - 1L)
          if (grepl(")", gsub(qs, "", pre, perl = TRUE), fixed = TRUE)) break
          b <- st + sm[k] - 1L
          e <- b + attr(sm, "match.length")[k] - 1L
          if (e - b >= 2L) add("caption", nm, ls[ch$open] + b, ls[ch$open] + e - 2L)
        }
        next
      }
      mm <- regexpr(paste0(nmp, "(?:\"((?:[^\"\\\\]|\\\\.)*)\"|'((?:[^'\\\\]|\\\\.)*)')"), hl, perl = TRUE)
      if (mm > 0L) {
        cs <- attr(mm, "capture.start")
        cl <- attr(mm, "capture.length")
        g <- if (cs[1L] > 0L) 1L else 2L
        add("caption", nm, ls[ch$open] + cs[g] - 1, ls[ch$open] + cs[g] + cl[g] - 2)
      }
    }
  }
  # strings
  if (nrow(chunks)) {
    for (k in seq_len(nrow(chunks))) {
      if (!identical(tolower(chunks$engine[k]), "r") || isFALSE(chunks$eval[k])) next
      code <- chunks$code[[k]]
      if (!length(code)) next
      for (w in c("weft_str", "phrase")) {
        lit <- chunk_literals(code, chunks$code_line[k], ls, w)
        if (nrow(lit)) add(w, NA_character_, lit$start, lit$start + nchar(lit$raw) - 1, by_row = TRUE)
      }
    }
  }
  if (!length(P)) {
    return(data.frame(kind = character(), name = character(), start = numeric(), end = numeric(),
                      grp = integer(), stringsAsFactors = FALSE))
  }
  do.call(rbind, P)
}

# ---- the prose mask ------------------------------------------------------------------

NB <- "(?:(?!\\n[ \\t]*\\n)[\\s\\S])"

P2_PATTERN <- paste0(
  "(?m)",
  "(?<com><!--[\\s\\S]*?-->)",
  "|(?<scr><(?:script|style)\\b[\\s\\S]*?</(?:script|style)>)",
  "|(?<cod>(?<![\\\\`])(?<tk>`+)(?!`)", NB, "+?(?<!`)\\k<tk>(?!`))",
  "|(?<md>\\$\\$", NB, "+?\\$\\$)",
  "|(?<m1>(?<![\\\\$])\\$(?![\\s$])[^$\\n]+?(?<![\\s\\\\])\\$(?![0-9]))",
  "|(?<m3>\\\\\\(", NB, "*?\\\\\\))",
  "|(?<m4>\\\\\\[", NB, "*?\\\\\\])",
  "|(?<ref>^ {0,3}\\[(?!\\^)[^\\]\\n]+\\]:[ \\t]+\\S.*$)",
  "|(?<sc>\\{\\{<[\\s\\S]*?>\\}\\})",
  "|(?<ent>&(?:#[0-9]+|#[xX][0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]*);)",
  "|(?<tag></?[A-Za-z][^<>]*>)",
  "|(?<url>(?<![A-Za-z0-9@])(?:https?://|ftp://|www\\.)[^\\s<>]*[^\\s<>.,;:!?)\\]'\"*_])",
  "|(?<doi>(?<![0-9A-Za-z.])10\\.[0-9]{4,9}/[^\\s<>]*[^\\s<>.,;:!?)\\]'\"])",
  "|(?<eml>[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,})")
P2_TYPES <- c("com", "scr", "cod", "md", "m1", "m3", "m4", "ref", "sc", "ent", "tag", "url", "doi", "eml")

# a Quarto cross-reference type in any letter case: `@Fig-map` prints as a capitalised "Figure 1"
XREF_PREFIX <- "(?i:fig|tbl|lst|sec|eq|thm|lem|cor|prp|cnj|def|exm|exr|sol|rem)"
KEY_BODY <- "[[:alnum:]_:.#$%&+?<>~/-]*[[:alnum:]_]"

P3_PATTERN <- paste0(
  "(?<cb>\\[[^\\[\\]]*(?<![[:alnum:]])-?@[[:alnum:]_][^\\[\\]]*\\](?!\\{))",
  "|(?<xr2>\\\\@ref\\([^)\\n]*\\))",
  "|(?<xa>\\(\\\\#(?:fig|tab|eq):[^)\\n]*\\))",
  "|(?<cbr>(?<![[:alnum:]_])-?@\\{[^}\\n]*\\})",
  "|(?<xr>(?<![[:alnum:]_])-?@", XREF_PREFIX, "-", KEY_BODY, ")",
  "|(?<ct>(?<![[:alnum:]_])-?@[[:alnum:]_](?:", KEY_BODY, ")?(?:[ \\t]*\\[[^\\[\\]\\n]*\\](?![(\\[{]))?)")

LINK_PATTERN <- paste0(
  "(?<![\\\\])(?<img>!)?\\[(?:(?!\\n[ \\t]*\\n)[^\\[\\]]|\\[[^\\[\\]]*\\])*\\]",
  "(?:\\((?:[^()\\n]|\\([^()\\n]*\\))*\\)|\\[[^\\]\\n]*\\])")

SPAN_PATTERN <- paste0("(?<![\\\\])\\[(?:(?!\\n[ \\t]*\\n)[^\\[\\]]|\\[[^\\[\\]]*\\])*\\]\\{[^{}\\n]*\\}")

# the prose mask and the regions that come with it
mask_prose <- function(S) {
  text <- S$text
  n <- nchar(text)
  nl <- length(S$lines)
  empty_regs <- new_regions()
  empty_regs <- with_attrs(empty_regs, character())
  if (n == 0L) return(list(prose = "", regions = empty_regs, numeric_ok = integer(), notes = list()))
  chars <- strsplit(text, "")[[1L]]
  at <- text_cutter(text)
  ls <- S$line_start
  lc <- rep.int(seq_len(nl), nchar(S$lines) + 1L)[seq_len(n)]
  # which lines are not body
  nonbody <- S$inmeta | S$infence
  keepv <- !nonbody[lc]
  pc <- S$pieces
  if (nrow(pc)) keepv <- keepv | mark_ranges(n, pc$start, pc$end)
  chars[!keepv & chars != "\n"] <- " "
  regs <- list()
  addreg <- function(type, s, e, name = NA_character_, row = NA_integer_) {
    if (length(s)) regs[[length(regs) + 1L]] <<- new_regions(type, s, e, row, name)
  }
  blank <- function(s, e) {
    if (!length(s)) return(invisible())
    m <- mark_ranges(n, s, e) & chars != "\n"
    chars[m] <<- " "
    invisible()
  }
  cur <- function() paste(chars, collapse = "")
  line_texts <- function(w) cut_lines(w, nl)
  work <- cur()

  # divs (whole fence lines)
  wl <- line_texts(work)
  divl <- which(grepl("^[ \t]*:{3,}", wl) & !nonbody)
  if (length(divl)) {
    blank(ls[divl], ls[divl] + nchar(S$lines[divl]) - 1L)
    # regions: from the opening line to the matching close
    dd <- S$lines[divl]
    cnt <- nchar(sub("^[ \t]*(:+).*$", "\\1", dd))
    closes <- grepl("^[ \t]*:{3,}[ \t]*$", dd)
    stack <- integer()
    ds <- integer(); de <- integer(); dn <- character(); did <- character()
    for (i in seq_along(divl)) {
      if (!closes[i] || !length(stack)) {
        stack <- c(stack, i)
      } else {
        j <- stack[length(stack)]
        stack <- stack[-length(stack)]
        ds <- c(ds, divl[j]); de <- c(de, divl[i])
        did <- c(did, sub("^[^{]*", "", dd[j]))
      }
    }
    for (j in stack) {
      ds <- c(ds, divl[j]); de <- c(de, nl); did <- c(did, sub("^[^{]*", "", dd[j]))
    }
    if (length(ds)) {
      r <- new_regions("div", ls[ds], ls[de] + nchar(S$lines[de]) - 1L, name = did)
      regs[[length(regs) + 1L]] <- r
      S$divs <- data.frame(open = ds, close = de, id = did, stringsAsFactors = FALSE)
    }
    work <- cur()
  }

  # indented code
  wl <- S$lines
  blk <- !grepl("[^ \t]", wl) | nonbody
  # a line that continues an HTML comment is the comment's, whatever its indentation (review 3, S3)
  gc <- gmatch("<!--[\\s\\S]*?-->", work)
  if (length(gc$s)) {
    for (q in seq_along(gc$s)) {
      lc <- findInterval(c(gc$s[q], gc$e[q]), ls)
      if (lc[2L] > lc[1L]) blk[(lc[1L] + 1L):lc[2L]] <- TRUE
    }
  }
  indent4 <- grepl("^( {4,}|\t)", wl) & !blk
  marker <- grepl("^[ \t]*([-*+]|[0-9]{1,9}[.)])[ \t]+[^ \t]", wl) & !nonbody
  col0 <- grepl("^[^ \t]", wl) & !nonbody
  if (any(indent4)) {
    inlist <- FALSE
    prevblank <- TRUE
    icode <- logical(nl)
    for (i in seq_len(nl)) {
      if (blk[i]) { prevblank <- TRUE; next }
      if (col0[i] && prevblank) inlist <- FALSE
      if (marker[i]) inlist <- TRUE
      if (indent4[i] && prevblank && !inlist) icode[i] <- TRUE
      else if (indent4[i] && !prevblank && i > 1L && icode[i - 1L]) icode[i] <- TRUE
      prevblank <- FALSE
    }
    # blank lines between two indented-code lines keep the block going
    il <- which(icode)
    if (length(il)) blank(ls[il], ls[il] + nchar(S$lines[il]) - 1L)
    work <- cur()
  }

  # opaque inline constructs
  g <- gmatch(P2_PATTERN, work)
  if (length(g$s)) {
    ty <- match_type(g, P2_TYPES)
    cod <- ty == "cod"
    md <- ty %in% c("md", "m1", "m3", "m4")
    s <- g$s; e <- g$e
    blank(s, e)
    code_attr <- list()
    if (any(cod | ty == "md")) {
      idx <- which(cod | ty == "md")
      sp <- if (any(ty[idx] == "md")) "^[ \t]*\\{[^{}\\n]*\\}" else "^\\{[^{}\\n]*\\}"
      for (kk in c("cod", "md")) {
        ii <- which(ty == kk)
        if (!length(ii)) next
        pat <- if (kk == "md") "^[ \t]*\\{[^{}\\n]*\\}" else "^\\{[^{}\\n]*\\}"
        sub_txt <- at(e[ii] + 1L, e[ii] + 300L)
        m <- regexpr(pat, sub_txt, perl = TRUE)
        has <- which(m > 0L)
        if (length(has)) {
          p1 <- regexpr("{", sub_txt[has], fixed = TRUE)
          as <- e[ii][has] + as.integer(p1)
          ae <- e[ii][has] + attr(m, "match.length")[has]
          blank(as, ae)
          if (kk == "cod") {
            r <- new_regions("code_attr", s[ii][has], ae)
            r$attr_start <- as; r$attr_end <- ae
            r <- with_attrs(r, at(as, ae))
            code_attr[[length(code_attr) + 1L]] <- r
          }
        }
      }
    }
    addreg("code", s[cod], e[cod])
    addreg("math", s[md], e[md])
    addreg("refdef", s[ty == "ref"], e[ty == "ref"])
    for (r in code_attr) regs[[length(regs) + 1L]] <- r
    work <- cur()
  }

  # spans, found where code and math are gone
  gs <- gmatch(SPAN_PATTERN, work)
  span_reg <- NULL
  if (length(gs$s)) {
    # the last "]{" opens the attribute block
    ap <- vapply(text_cutter(work)(gs$s, gs$e), function(x) {
      m <- gregexpr("]{", x, fixed = TRUE)[[1L]]
      as.integer(m[length(m)])
    }, 1L)
    as <- gs$s + ap
    r <- new_regions("span", gs$s, gs$e)
    r$inner_start <- gs$s
    r$inner_end <- as - 1L
    r$attr_start <- as
    r$attr_end <- gs$e
    r <- with_attrs(r, at(as, gs$e))
    span_reg <- r
  }

  # weft rows: code and attribute blocks
  rw <- S$rows
  if (nrow(rw)) {
    isv <- rw$kind %in% c("bare", "value")
    blank(ifelse(isv, rw$fstart, rw$fblock), rw$fend)
  }

  # citations and cross-references
  g <- gmatch(P3_PATTERN, work)
  if (length(g$s)) {
    ty <- match_type(g, c("cb", "xr2", "xa", "cbr", "xr", "ct"))
    blank(g$s, g$e)
    isx <- ty %in% c("xr2", "xa", "xr")
    addreg("crossref", g$s[isx], g$e[isx], name = at(g$s, g$e)[isx])
    addreg("citation", g$s[!isx], g$e[!isx], name = at(g$s, g$e)[!isx])
    work <- cur()
  }

  # footnote markers and inline notes
  g <- gmatch("\\[\\^[^\\]\\s]+\\]:?", work)
  if (length(g$s)) {
    blank(g$s, g$e)
    addreg("footnote", g$s, g$e, name = at(g$s, g$e))
    work <- cur()
  }
  inl <- inline_footnotes(work)
  if (!is.null(inl)) {
    blank(c(inl$from, inl$from + 1L, inl$to), c(inl$from, inl$from + 1L, inl$to))
    addreg("footnote", inl$from, inl$to, name = "inline")
    S$inline_notes <- inl
    work <- cur()
  }

  # links and images (regions), then their targets
  gl <- gmatch(LINK_PATTERN, work)
  if (length(gl$s)) {
    isimg <- gl$cs[, "img"] > 0
    addreg("image", gl$s[isimg], gl$e[isimg])
    addreg("link", gl$s[!isimg], gl$e[!isimg])
  }
  # attribute blocks straight after a bracket
  g <- gmatch("(?<=\\])\\{[^{}\\n]*\\}", work)
  blank(g$s, g$e)
  work <- cur()
  g <- gmatch("(?<=\\])(?:\\((?:[^()\\n]|\\([^()\\n]*\\))*\\)|\\[[^\\]\\n]*\\])", work)
  if (length(g$s)) {
    blank(g$s, g$e)
    sub_txt <- at(g$e + 1L, g$e + 300L)
    m <- regexpr("^\\{[^{}\\n]*\\}", sub_txt, perl = TRUE)
    has <- which(m > 0L)
    if (length(has)) blank(g$e[has] + 1L, g$e[has] + attr(m, "match.length")[has])
    work <- cur()
  }
  g <- gmatch("\\{[ \\t]*[#.][^{}\\n]*\\}", work)
  blank(g$s, g$e)
  work <- cur()

  # raw TeX and escapes
  g <- gmatch("\\\\[A-Za-z]+\\*?(?:\\[[^\\]\\n]*\\]|\\{(?:[^{}\\n]|\\{[^{}\\n]*\\})*\\})*", work)
  blank(g$s, g$e)
  g <- gmatch("\\\\(?=[[:punct:]])", cur())
  blank(g$s, g$e)
  work <- cur()

  # line-start markers
  wl <- line_texts(work)
  wb <- !grepl("[^ \t]", wl)
  hit <- function(pat, x = wl) {
    m <- regexpr(pat, x, perl = TRUE)
    ok <- m > 0L
    list(l = which(ok), len = attr(m, "match.length")[ok], s = as.integer(m)[ok])
  }
  blank_hit <- function(h) {
    if (length(h$l)) blank(ls[h$l] + h$s - 1L, ls[h$l] + h$s + h$len - 2L)
  }
  whole <- function(idx) if (length(idx)) blank(ls[idx], ls[idx] + nchar(S$lines[idx]) - 1L)
  prev_nb <- c(FALSE, !wb[-nl])
  tdelim <- which(grepl("\\|", wl) & grepl("^[ \t]*\\|?[ \t]*:?-+:?[ \t]*(\\|[ \t]*:?-+:?[ \t]*)*\\|?[ \t]*$", wl))
  grid <- which(grepl("^[ \t]*\\+[-=:+]+\\+[ \t]*$", wl))
  rule <- which(grepl("^ {0,3}(?:(?:\\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$", wl, perl = TRUE))
  # a setext underline sits under a one-line paragraph; under two lines or more Pandoc reads the
  # dashes as the end of the paragraph (review 3, finding 11)
  under <- grepl("^ {0,3}(?:=+|-+)[ \t]*$", wl) & prev_nb
  prev2_nb <- c(FALSE, FALSE, !wb)[seq_len(nl)]
  setx <- which(under & !prev2_nb)
  rule <- setdiff(rule, which(under & prev2_nb))
  S$structural <- sort(unique(c(tdelim, grid, rule, setx)))
  S$tdelim <- tdelim
  S$setext <- setx
  whole(S$structural)
  work <- cur()
  wl <- line_texts(work)
  wb <- !grepl("[^ \t]", wl)
  blank_hit(hit("^(?:[ \t]{0,3}>[ \t]?)+"))
  wl <- line_texts(cur())
  h <- hit("^[ \t]{0,3}#{1,6}(?:[ \t]+|$)")
  blank_hit(h)
  atxl <- h$l
  S$atx <- atxl
  wl <- line_texts(cur())
  hh <- hit("[ \t]+#+[ \t]*$", wl[atxl])
  # (closing #s of a heading: the hits are relative to atxl)
  if (length(hh$l)) {
    ll <- atxl[hh$l]
    blank(ls[ll] + hh$s - 1L, ls[ll] + hh$s + hh$len - 2L)
  }
  wl <- line_texts(cur())
  bullet <- hit("^[ \t]*[-*+][ \t]+(?:\\[[ xX]\\][ \t]+)?")
  blank_hit(bullet)
  wl <- line_texts(cur())
  wb <- !grepl("[^ \t]", wl)
  numc <- hit("^[ \t]*(?:[0-9]{1,9}[.)]|\\((?:[0-9]{1,2}|@[A-Za-z0-9_-]*)\\))[ \t]+")
  acc <- integer()
  if (length(numc$l)) {
    isitem <- logical(nl)
    isitem[bullet$l] <- TRUE
    ishead <- logical(nl)
    ishead[atxl] <- TRUE
    ok <- logical(length(numc$l))
    for (i in seq_along(numc$l)) {
      l <- numc$l[i]
      ok[i] <- !ishead[l] && (l == 1L || wb[l - 1L] || isitem[l - 1L] || ishead[l - 1L] || nonbody[l - 1L])
      if (ok[i]) isitem[l] <- TRUE
    }
    acc <- numc$l[ok]
    blank_hit(list(l = numc$l[ok], s = numc$s[ok], len = numc$len[ok]))
  }
  S$num_items <- acc
  S$bullets <- bullet$l
  wl <- line_texts(cur())
  blank_hit(hit("^[ \t]{0,3}[:~](?=[ \t])"))

  prose <- cur()
  regions <- do.call(rbind, c(list(empty_regs), lapply(regs, function(r) {
    if (!"classes" %in% names(r)) r <- with_attrs(r, rep(NA_character_, nrow(r)))
    r
  })))
  if (!is.null(span_reg)) regions <- rbind(regions, span_reg)
  list(prose = prose, regions = regions, notes = list())
}

# ---- blocks ----------------------------------------------------------------------------

build_blocks <- function(S) {
  lines <- S$lines
  nl <- length(lines)
  ls <- S$line_start
  le <- ls + nchar(lines) - 1
  text <- S$text
  n <- nchar(text)
  nonbody <- S$inmeta | S$infence
  dl <- sub("^(?:[ \t]{0,3}>[ \t]?)+", "", lines, perl = TRUE)
  blank <- nonbody | !grepl("[^ \t]", lines)
  lt <- ifelse(blank, "blank", "text")
  prev_blank <- c(TRUE, blank[-nl])
  set <- function(idx, v) if (length(idx)) lt[idx] <<- v
  set(which(!blank & grepl("^ {0,3}:[ \t]+\\S", dl) & prev_blank & !grepl("^[ \t]*:{3,}", dl)), "tcap")
  set(which(!blank & grepl("^ {0,3}\\[\\^[^\\]\\s]+\\]:", dl, perl = TRUE)), "fndef")
  set(c(S$bullets, S$num_items), "item")
  set(S$atx, "heading")
  # tables
  tbl <- list()
  cell_lines <- integer()
  for (d in S$tdelim) {
    if (d < 2L || blank[d - 1L]) next
    j <- d + 1L
    while (j <= nl && !blank[j]) j <- j + 1L
    rows <- c(d - 1L, if (j > d + 1L) (d + 1L):(j - 1L))
    cell_lines <- c(cell_lines, rows)
    tbl[[length(tbl) + 1L]] <- c(d - 1L, j - 1L)
  }
  gridb <- which(grepl("^[ \t]*\\+[-=:+]+\\+[ \t]*$", lines) & !nonbody)
  if (length(gridb)) {
    # a grid table runs from a border line to the first blank line after
    k <- 1L
    while (k <= length(gridb)) {
      a <- gridb[k]
      j <- a
      while (j <= nl && !blank[j]) j <- j + 1L
      cell_lines <- c(cell_lines, which(seq_len(nl) >= a & seq_len(nl) < j & grepl("^[ \t]*\\|", lines)))
      tbl[[length(tbl) + 1L]] <- c(a, j - 1L)
      k <- k + sum(gridb < j)
    }
  }
  set(cell_lines, "cell")
  set(S$structural, "struct")
  set(which(!blank & grepl("^[ \t]*:{3,}", lines)), "div")
  prevlt <- c("blank", lt[-nl])
  newblk <- lt %in% c("heading", "item", "fndef", "tcap") |
    (lt == "text" & prevlt %in% c("blank", "heading", "struct", "div", "cell"))
  inblk <- lt %in% c("text", "heading", "item", "fndef", "tcap")
  id <- ifelse(inblk, cumsum(newblk), NA_integer_)
  B <- NULL
  if (any(inblk)) {
    first <- tapply(which(inblk), id[inblk], min)
    last <- tapply(which(inblk), id[inblk], max)
    ft <- lt[first]
    type <- c(text = "para", heading = "heading", item = "item", fndef = "footnote",
              tcap = "caption")[ft]
    B <- data.frame(type = unname(type), start = ls[first], end = le[last],
                    line = as.integer(first), end_line = as.integer(last),
                    stringsAsFactors = FALSE)
    for (u in S$setext) {
      k <- which(B$end_line == u - 1L & B$type == "para")
      if (length(k)) B$type[k] <- "heading"
    }
    if (!is.null(S$divs) && nrow(S$divs)) {
      for (i in seq_len(nrow(S$divs))) {
        if (!grepl("#(fig|tbl)-", S$divs$id[i])) next
        k <- which(B$type == "para" & B$line > S$divs$open[i] & B$end_line < S$divs$close[i])
        if (length(k)) B$type[k[length(k)]] <- "caption"
      }
    }
  }
  # cells
  C <- NULL
  if (length(cell_lines)) {
    rw <- S$rows
    protect <- mark_ranges(n, c(rw$fstart, S$regions$start[S$regions$type %in% c("code", "math", "span", "code_attr")]),
                           c(rw$fend, S$regions$end[S$regions$type %in% c("code", "math", "span", "code_attr")]))
    pm <- gregexpr("(?<!\\\\)\\|", text, perl = TRUE)[[1L]]
    pm <- as.integer(pm[pm > 0L])
    pm <- pm[!protect[pm]]
    cl <- sort(unique(cell_lines))
    segs <- list()
    for (l in cl) {
      ps <- pm[pm >= ls[l] & pm <= le[l]]
      a <- c(ls[l], ps + 1L)
      b <- c(ps - 1L, le[l])
      keep <- b >= a
      a <- a[keep]; b <- b[keep]
      if (!length(a)) next
      t <- substring(text, a, b)
      lead <- nchar(t) - nchar(sub("^[ \t]+", "", t))
      trail <- nchar(t) - nchar(sub("[ \t]+$", "", t))
      ok <- lead < nchar(t)
      segs[[length(segs) + 1L]] <- data.frame(type = "cell", start = (a + lead)[ok], end = (b - trail)[ok],
                                              line = l, end_line = l, stringsAsFactors = FALSE)
    }
    if (length(segs)) C <- do.call(rbind, segs)
  }
  # pieces
  Pb <- NULL
  pc <- S$pieces
  if (nrow(pc)) {
    pc$line <- findInterval(pc$start, ls)
    pc <- pc[order(pc$grp, pc$start), , drop = FALSE]
    seg <- cumsum(c(TRUE, pc$grp[-1L] != pc$grp[-nrow(pc)] | pc$line[-1L] - pc$line[-nrow(pc)] > 1L))
    Pb <- do.call(rbind, lapply(split(seq_len(nrow(pc)), seg), function(ix) {
      k <- pc$kind[ix[1L]]
      data.frame(type = c(front = "front-matter", caption = "caption", weft_str = "weft_str",
                          phrase = "phrase")[[k]],
                 start = min(pc$start[ix]), end = max(pc$end[ix]),
                 line = min(pc$line[ix]), end_line = findInterval(max(pc$end[ix]), ls),
                 stringsAsFactors = FALSE)
    }))
  }
  Fn <- NULL
  if (!is.null(S$inline_notes)) {
    inl <- S$inline_notes
    Fn <- data.frame(type = "footnote", start = inl$from + 2L, end = inl$to - 1L,
                     line = findInterval(inl$from, ls), end_line = findInterval(inl$to, ls),
                     stringsAsFactors = FALSE)
    Fn <- Fn[Fn$end >= Fn$start, , drop = FALSE]
  }
  all <- do.call(rbind, Filter(Negate(is.null), list(B, C, Pb, Fn)))
  if (is.null(all)) all <- data.frame(type = character(), start = numeric(), end = numeric(),
                                      line = integer(), end_line = integer(), stringsAsFactors = FALSE)
  all <- all[order(all$start, all$end), , drop = FALSE]
  all$start <- as.integer(all$start); all$end <- as.integer(all$end)
  all$line <- as.integer(all$line); all$end_line <- as.integer(all$end_line)
  rownames(all) <- NULL
  tb <- if (length(tbl)) do.call(rbind, tbl) else matrix(integer(), 0, 2)
  list(blocks = all, tables = tb)
}

# ---- reading a document ------------------------------------------------------------------------

read_source <- function(path, root, cfg) {
  rel <- lint_rel_path(path, root)
  ext <- sub("^.*\\.", "", basename(path))
  text <- read_source_text_or_null(path)
  if (is.null(text)) {
    return(structure(list(file = rel, path = path, ext = ext, invalid = TRUE, cfg = cfg, text = "",
                          lines = character(), line_start = numeric()), class = "weft_source"))
  }
  lines <- if (nzchar(text)) strsplit(text, "\n", fixed = TRUE)[[1L]] else character()
  nl <- length(lines)
  ls <- line_starts(lines)
  n <- nchar(text)
  mb <- metadata_blocks(lines)
  inmeta <- logical(nl)
  for (b in seq_len(nrow(mb))) inmeta[mb$open[b]:mb$close[b]] <- TRUE
  fb <- fence_blocks(lines, inmeta)
  infence <- logical(nl)
  for (b in seq_len(nrow(fb))) infence[fb$open[b]:fb$close[b]] <- TRUE
  chs <- labelled_chunks(dequote_chunks(lines))
  chunks <- chunk_table(lines, chs)
  ff <- front_fields(lines)
  # metadata
  meta <- lapply(seq_len(nrow(mb)), function(b) {
    y <- if (mb$close[b] - mb$open[b] >= 2L) yaml_text(paste(lines[(mb$open[b] + 1L):(mb$close[b] - 1L)], collapse = "\n")) else list()
    list(open = mb$open[b], close = mb$close[b], yaml = if (is.list(y)) y else list())
  })
  front <- list()
  for (m in meta) if (length(m$yaml) && !is.null(names(m$yaml))) front[names(m$yaml)] <- m$yaml
  lang <- NA_character_
  if (is.character(front$lang) && length(front$lang) == 1L) lang <- front$lang
  if (is.na(lang)) {
    qp <- file.path(root, QUARTO_MARKERS)
    qp <- qp[file.exists(qp)]
    if (length(qp)) {
      y <- yaml_text(read_source_text_or_null(qp[1L]) %||% "")
      if (is.list(y) && is.character(y$lang) && length(y$lang) == 1L) lang <- y$lang
    }
  }
  # rows
  rows <- scan_document(lines, file = rel, config = cfg, project = project_type(path))
  if (nrow(rows)) {
    ci <- findInterval(rows$line, chunks$open)
    inchunk <- ci > 0L & rows$line <= chunks$close[pmax(ci, 1L)]
    eng_r <- ifelse(inchunk, tolower(chunks$engine[pmax(ci, 1L)]) == "r", TRUE)
    ev <- ifelse(inchunk, chunks$eval[pmax(ci, 1L)], TRUE)
    # a caption construct on another engine's chunk is kept when it carries its error (2.3.5, rule 5.11)
    drop <- (rows$context == "weft_str" & (!eng_r | !ev)) |
      (rows$context == "caption" & !eng_r & is.na(rows$error))
    if (any(drop)) {
      newidx <- cumsum(!drop)
      rows <- rows[!drop, , drop = FALSE]
      rows$parent <- ifelse(is.na(rows$parent), NA_integer_, newidx[rows$parent])
    }
  }
  phr <- list()
  for (k in seq_len(nrow(chunks))) {
    if (!identical(tolower(chunks$engine[k]), "r") || isFALSE(chunks$eval[k])) next
    lit <- chunk_literals(chunks$code[[k]], chunks$code_line[k], ls, "phrase")
    if (nrow(lit)) phr[[length(phr) + 1L]] <- phrase_rows(lit, chunks$label[k], rel, cfg)
  }
  if (length(phr)) {
    rows <- bind_scan_rows(c(list(rows), phr))
    ord <- order(rows$fstart, seq_len(nrow(rows)), na.last = TRUE)
    rows$parent <- match(rows$parent, ord)
    rows <- rows[ord, , drop = FALSE]
    rownames(rows) <- NULL
  }
  if (nrow(rows)) {
    bad <- is.na(rows$fstart)
    if (any(bad)) {
      rows$fstart[bad] <- ls[pmin(rows$line[bad], nl)]
      rows$fend[bad] <- rows$fstart[bad]
      rows$fblock[bad] <- NA_real_
    }
  }
  pieces <- source_pieces(lines, ls, chunks, chs, NULL, ff)
  S <- new.env(parent = emptyenv())
  S$text <- text; S$lines <- lines; S$line_start <- ls
  S$inmeta <- inmeta; S$infence <- infence; S$pieces <- pieces; S$rows <- rows
  S$divs <- NULL; S$inline_notes <- NULL
  mp <- mask_prose(S)
  regions <- mp$regions
  # regions from the rows, chunks, fields and pieces
  add <- function(r) if (nrow(r)) regions <<- rbind(regions, with_attrs(r, rep(NA_character_, nrow(r))))
  if (nrow(rows)) {
    kmap <- c(value = "value", bare = "bare", n = "n", `if` = "if", sign = "sign", list = "list",
              cite = "cite_span", literal = "literal", text = "text_span")
    ty <- unname(kmap[rows$kind])
    ok <- !is.na(ty)
    r <- new_regions(ty[ok], rows$fstart[ok], rows$fend[ok], row = which(ok), name = rows$expr[ok])
    add(r)
    # a row's index on the span it sits in
    sp <- which(regions$type == "span")
    if (length(sp)) regions$row[sp] <- match(regions$start[sp], rows$fstart)
  }
  if (nrow(chunks)) {
    add(new_regions("chunk", ls[chunks$open], ls[chunks$close] + nchar(lines[chunks$close]) - 1L, name = chunks$label))
  }
  if (nrow(pieces)) {
    for (k in c("front", "caption", "weft_str", "phrase")) {
      pk <- pieces[pieces$kind == k, , drop = FALSE]
      if (!nrow(pk)) next
      g <- split(seq_len(nrow(pk)), pk$grp)
      st <- vapply(g, function(ix) min(pk$start[ix]), 1)
      en <- vapply(g, function(ix) max(pk$end[ix]), 1)
      nm <- vapply(g, function(ix) pk$name[ix[1L]], "")
      add(new_regions(c(front = "yaml_field", caption = "caption", weft_str = "weft_str", phrase = "phrase")[[k]], st, en, name = nm))
    }
  }
  # text spans: a span with a formatter class and no weft row
  fmt <- c(shipped_classes(), names(cfg$formatters %||% list()))
  sp <- which(regions$type == "span")
  if (length(sp)) {
    isf <- vapply(sp, function(i) any(regions$classes[[i]] %in% fmt) && is.na(regions$row[i]), NA)
    has_text <- regions$start[regions$type == "text_span"]
    isf <- isf & !(regions$start[sp] %in% has_text)
    if (any(isf)) {
      r <- regions[sp[isf], , drop = FALSE]
      r$type <- "text_span"
      regions <- rbind(regions, r)
    }
  }
  S$prose <- mp$prose
  S$regions <- regions
  bb <- build_blocks(S)
  hd <- bb$blocks[bb$blocks$type == "heading", , drop = FALSE]
  if (nrow(hd)) regions <- rbind(regions, with_attrs(new_regions("heading", hd$start, hd$end), rep(NA_character_, nrow(hd))))
  if (nrow(bb$tables)) {
    regions <- rbind(regions, with_attrs(new_regions("table", ls[bb$tables[, 1L]], le_of(lines, ls, bb$tables[, 2L])),
                                         rep(NA_character_, nrow(bb$tables))))
  }
  regions <- regions[order(regions$start, regions$end), , drop = FALSE]
  rownames(regions) <- NULL
  structure(list(
    file = rel, path = path, ext = ext, invalid = FALSE, cfg = cfg, text = text, lines = lines,
    line_start = ls, lang = lang, rows = rows, prose = mp$prose, regions = regions,
    blocks = bb$blocks, chunks = chunks, meta = meta, front = front, divs = S$divs,
    cache = new.env(parent = emptyenv())), class = "weft_source")
}

le_of <- function(lines, ls, i) ls[i] + nchar(lines[i]) - 1

# ---- sentences (L12) -----------------------------------------------------------------------------

source_sentences <- function(src) {
  out <- list()
  b <- src$blocks
  lang <- if (is.na(src$lang)) "" else src$lang
  prose_at <- text_cutter(src$prose)
  for (i in seq_len(nrow(b))) {
    t <- src_substr(src, b$start[i], b$end[i])
    pr <- prose_at(b$start[i], b$end[i])
    if (!grepl("[^ \n]", pr)) next
    nc <- nchar(t)
    cuts <- sentence_cuts(t, NULL, lang)$cuts
    cuts <- sort(unique(cuts[cuts > 1L & cuts <= nc]))
    st <- c(1L, cuts)
    en <- c(cuts - 1L, nc)
    seg <- substring(t, st, en)
    lead <- nchar(seg) - nchar(sub("^[ \t\n]+", "", seg))
    trail <- nchar(seg) - nchar(sub("[ \t\n]+$", "", seg))
    st2 <- st + lead
    en2 <- en - trail
    pseg <- substring(pr, st2, en2)
    ok <- en2 >= st2 & grepl("[^ \n]", pseg)
    if (!any(ok)) next
    a <- b$start[i] + st2[ok] - 1L
    e <- b$start[i] + en2[ok] - 1L
    out[[length(out) + 1L]] <- data.frame(start = a, end = e, line = src_line_of(src, a),
                                          end_line = src_line_of(src, e), block = i)
  }
  if (!length(out)) {
    return(data.frame(start = integer(), end = integer(), line = integer(), end_line = integer(),
                      block = integer()))
  }
  r <- do.call(rbind, out)
  # in document order: a note's sentences are emitted after the paragraph's but start inside it
  r <- r[order(r$start, -r$end), , drop = FALSE]
  rownames(r) <- NULL
  r
}
