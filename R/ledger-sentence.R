# The sentence around a construct and the heading anchors of a document: moved out of ledger.R, unchanged.

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
