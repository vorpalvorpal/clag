# The scanner (rules 1.1, 1.2, 1.5.12-1.5.14, 1.9, 2.10.1, 5.3.1): a
# hand-written pass over characters. It finds inline code with its attribute
# block and brackets with theirs, honours nesting and escapes, skips what
# 1.9 leaves alone, and records the construct errors that can be found from
# the source. It runs no R except parse() (5.3.5) and never stops: an error
# goes in the `error` column of its row.

SCAN_SPECIAL <- c("`", "[", "]", "$", "\\", "<")
GOVERNOR_KEYS <- c("n", "if", "sign", "cite", "list")
WEFT_KEYS <- c(GOVERNOR_KEYS, "digits", "sigfig", "unit", "sep", "last", "trunc", "none")
# Named values (rules 1.12.1-1.12.5): the words that are not names, in any language.
NAME_RESERVED <- c("TRUE", "FALSE", "True", "False", "true", "false", "NA", "NULL", "None", "nothing",
                   "missing", "Inf", "NaN")
# The keys that make a code span a named value (N5); a governor key does not.
NAMED_KEYS <- c("digits", "sigfig", "unit", "sep", "last", "trunc", "none")
# The placeholder `#` of an arm template (1.5.8).
ARM_PLACEHOLDER <- "\ue001"

trim_ws <- function(x) gsub("^[ \t\r\n]+|[ \t\r\n]+$", "", x, perl = TRUE)

# ---- setup --------------------------------------------------------------

new_scan <- function(text, file, first_line, config, filter_doc = FALSE) {
  text <- paste(enc2utf8(as.character(text)), collapse = "\n")
  if (length(text) != 1L || is.na(text)) text <- ""
  chars <- if (nzchar(text)) strsplit(text, "")[[1]] else character()
  n <- length(chars)
  S <- new.env(parent = emptyenv())
  S$text <- text
  S$chars <- chars
  S$n <- n
  S$file <- file
  S$first_line <- as.integer(first_line)
  S$reg <- config$formatters %||% list()
  # whether the Lua filter resolves the spans of this text (N14); named values are always its
  S$filter_doc <- isTRUE(filter_doc)
  # index vectors are doubles, so findInterval() does not coerce them on every call
  S$nl <- as.numeric(which(chars == "\n"))
  # the first colon of each fenced-div opening line is special too, so the
  # walk stops there (a `.weft-literal` div is a row, 1.8.9)
  dv <- if (n) gregexpr("(?m)^[ \\t]{0,3}(?:>[ \\t]*)*\\K:{3,}[ \\t]*(?:\\{|[^\\s{}:]+)", text, perl = TRUE)[[1]] else -1L
  S$divs <- as.numeric(dv[dv > 0L])
  S$special <- as.numeric(sort(unique(c(which(chars %in% SCAN_SPECIAL), S$divs))))
  S$dollar <- as.numeric(which(chars == "$"))

  r <- rle(chars == "`")
  ends <- cumsum(r$lengths)
  S$bt_start <- as.numeric((ends - r$lengths + 1L)[r$values])
  S$bt_len <- r$lengths[r$values]

  cend <- if (n) gregexpr("-->", text, fixed = TRUE)[[1]] else -1L
  S$cend <- as.numeric(cend[cend > 0L])

  find_fences(S)
  find_tables(S)

  bl <- if (n) gregexpr("\n[ \t\r]*(?=\n)", text, perl = TRUE)[[1]] else -1L
  bl <- bl[bl > 0L]
  S$plim <- as.numeric(sort(unique(c(bl - 1L, S$f_start - 1L, n))))

  S$rows <- new.env(parent = emptyenv())   # one entry per row: no copying
  S$nrows <- 0L
  S
}

# The `n` lines of `text`, cut in one pass (the last may be empty). `substring()` with a start
# for each line walks a non-ASCII string from its beginning every time, so it is quadratic.
cut_lines <- function(text, n) {
  x <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  length(x) <- n
  x[is.na(x)] <- ""
  x
}

# Fenced blocks (executed chunks and not): the scanner leaves them alone.
find_fences <- function(S) {
  S$f_start <- integer()
  S$f_end <- integer()
  if (S$n == 0L) return(invisible())
  ls <- c(1L, S$nl + 1L)
  le <- c(S$nl - 1L, S$n)
  lines <- cut_lines(S$text, length(ls))
  open_re <- "^[ \t]*((?:>[ \t]*)*)(`{3,}|~{3,})(.*)$"
  m <- regmatches(lines, regexec(open_re, lines, perl = TRUE))
  k <- 1L
  nl <- length(lines)
  starts <- integer()
  ends <- integer()
  while (k <= nl) {
    mm <- m[[k]]
    k0 <- k
    # a backtick fence has no backtick in its info string, except a knitr chunk
    # header (`{r, fig.cap = "... `r x` ..."}`), which knitr reads as one
    if (length(mm) && !(substr(mm[3], 1, 1) == "`" && grepl("`", mm[4], fixed = TRUE) &&
                        !grepl("^[ \t]*\\{.*\\}[ \t\r]*$", mm[4]))) {
      ch <- substr(mm[3], 1, 1)
      len <- nchar(mm[3])
      quoted <- nzchar(mm[2])
      close_re <- paste0("^[ \t]*", if (quoted) "(?:>[ \t]*)+" else "",
                         if (ch == "`") "`" else "~", "{", len, ",}[ \t\r]*$")
      j <- k + 1L
      closed <- FALSE
      while (j <= nl) {
        if (grepl(close_re, lines[j], perl = TRUE)) {
          closed <- TRUE
          break
        }
        # a quoted fence ends with its block quote
        if (quoted && !grepl("^[ \t]*>", lines[j])) break
        j <- j + 1L
      }
      if (closed) {
        end <- le[j]
        k <- j + 1L
      } else if (quoted && j <= nl) {
        end <- le[j - 1L]
        k <- j
      } else {
        end <- S$n
        k <- j + 1L
      }
      starts <- c(starts, ls[k0])
      ends <- c(ends, end)
    } else {
      k <- k + 1L
    }
  }
  S$f_start <- as.numeric(starts)
  S$f_end <- as.numeric(ends)
  invisible()
}

# Lines of pipe tables (1.5.13): the header, the delimiter row and the rows
# up to a blank line.
find_tables <- function(S) {
  nlines <- length(S$nl) + 1L
  S$tbl <- rep(FALSE, nlines)
  if (S$n == 0L) return(invisible())
  ls <- c(1L, S$nl + 1L)
  le <- c(S$nl - 1L, S$n)
  lines <- cut_lines(S$text, length(ls))
  delim <- grepl("\\|", lines) &
    grepl("^[ \t]*\\|?[ \t]*:?-+:?[ \t]*(\\|[ \t]*:?-+:?[ \t]*)*\\|?[ \t\r]*$", lines)
  # the header and the delimiter row must have the same number of cells
  cells <- function(x) {
    x <- sub("^\\|", "", trim_ws(x))
    x <- sub("(?<!\\\\)\\|$", "", x, perl = TRUE)
    sum(gregexpr("(?<!\\\\)\\|", x, perl = TRUE)[[1]] > 0L) + 1L
  }
  for (d in which(delim)) {
    if (d < 2L) next
    if (cells(lines[d - 1L]) != cells(lines[d])) next
    S$tbl[d - 1L] <- TRUE
    j <- d
    while (j <= nlines && nzchar(trim_ws(lines[j]))) {
      S$tbl[j] <- TRUE
      j <- j + 1L
    }
  }
  invisible()
}

# ---- character helpers --------------------------------------------------

line_index <- function(S, pos) findInterval(pos - 1L, S$nl) + 1L

next_special <- function(S, i) {
  idx <- findInterval(i - 1L, S$special) + 1L
  if (idx > length(S$special)) S$n + 1L else S$special[idx]
}

para_limit <- function(S, i) S$plim[findInterval(i - 1L, S$plim) + 1L]

fence_end_at <- function(S, p) {
  fi <- findInterval(p, S$f_start)
  if (fi > 0L && p <= S$f_end[fi]) S$f_end[fi] else NA_integer_
}

comment_end <- function(S, i) {
  if (i + 3L > S$n || !identical(S$chars[i:(i + 3L)], c("<", "!", "-", "-"))) {
    return(NA_integer_)
  }
  k <- findInterval(i + 3L, S$cend) + 1L
  if (k <= length(S$cend)) return(S$cend[k] + 2L)
  # Unclosed: an HTML block at the start of a line runs on; in the middle of
  # a line it is no comment at all (1.9.2).
  j <- i - 1L
  while (j >= 1L && S$chars[j] %in% c(" ", "\t")) j <- j - 1L
  if (j < 1L || S$chars[j] == "\n") S$n else NA_integer_
}

# The end of an autolink `<scheme:target>` or `<name@host>` at `i`, or `NA`.
autolink_end <- function(S, i) {
  seg <- substr(S$text, i, min(S$n, i + 2000L))
  m <- regexpr(paste0(
    "^<(?:[A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>[:space:]]*|",
    "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*)>"), seg, perl = TRUE)
  if (m == -1L) NA_integer_ else i + attr(m, "match.length") - 1L
}

# The end of an inline raw HTML tag, open or close, at `i`, or `NA`. Raw
# content is never a construct (1.9.1), and that includes its attribute values.
html_tag_end <- function(S, i) {
  seg <- substr(S$text, i, min(S$n, i + 2000L))
  attr_re <- paste0("[A-Za-z_:][-A-Za-z0-9_:.]*(?:[ \\t\\r\\n]*=[ \\t\\r\\n]*",
                    "(?:\"[^\"]*\"|'[^']*'|[^ \\t\\r\\n\"'=<>`]+))?")
  m <- regexpr(paste0(
    "^(?:<[A-Za-z][A-Za-z0-9-]*(?:[ \\t\\r\\n]+", attr_re, ")*[ \\t\\r\\n]*/?>",
    "|</[A-Za-z][A-Za-z0-9-]*[ \\t\\r\\n]*>)"), seg, perl = TRUE)
  if (m == -1L) NA_integer_ else i + attr(m, "match.length") - 1L
}

# A comment, an autolink or a raw HTML tag starting with `<` at `i`: its last
# character, or `NA`.
angle_end <- function(S, i) {
  e <- comment_end(S, i)
  if (!is.na(e)) return(e)
  e <- autolink_end(S, i)
  if (!is.na(e)) return(e)
  html_tag_end(S, i)
}

is_space <- function(ch) ch %in% c(" ", "\t", "\n", "\r")

# A code span opening at `i`: its extent, or not ok when no run of the same
# length closes it in the paragraph.
code_span <- function(S, i) {
  ri <- findInterval(i, S$bt_start)
  open_end <- S$bt_start[ri] + S$bt_len[ri] - 1L
  k <- open_end - i + 1L
  lim <- para_limit(S, i)
  j <- ri + 1L
  nb <- length(S$bt_start)
  while (j <= nb && S$bt_start[j] <= lim) {
    if (S$bt_len[j] == k) {
      return(list(ok = TRUE, open_end = open_end, close_start = S$bt_start[j],
                  close_end = S$bt_start[j] + k - 1L))
    }
    j <- j + 1L
  }
  list(ok = FALSE, open_end = open_end)
}

# Inline math opening at `i`: the position of its closing `$`, or `NA`.
math_end <- function(S, i) {
  ch <- S$chars
  n <- S$n
  lim <- para_limit(S, i)
  dollars <- function(lo, hi) {
    a <- findInterval(lo, S$dollar) + 1L
    b <- findInterval(hi, S$dollar)
    if (a > b) integer() else S$dollar[a:b]
  }
  if (i < n && ch[i + 1L] == "$") {
    js <- dollars(i + 1L, lim - 1L)
    for (j in js) if (ch[j + 1L] == "$") return(j + 1L)
    return(NA_integer_)
  }
  if (i >= n || is_space(ch[i + 1L])) return(NA_integer_)
  for (j in dollars(i, lim)) {
    prev <- ch[j - 1L]
    if (is_space(prev) || prev == "\\") next
    if (j < n && grepl("[0-9]", ch[j + 1L])) next
    return(j)
  }
  NA_integer_
}

# The end of a link target `(...)` opening at `k`, or `NA`.
target_end <- function(S, k) {
  lim <- para_limit(S, k)
  depth <- 0L
  j <- k
  while (j <= lim) {
    c <- S$chars[j]
    if (c == "\\") {
      j <- j + 2L
      next
    }
    if (c == "(") depth <- depth + 1L
    if (c == ")") {
      depth <- depth - 1L
      if (depth == 0L) return(j)
    }
    j <- j + 1L
  }
  NA_integer_
}

# ---- the attribute block ------------------------------------------------

# Parse `{...}` starting at `i` on the one line. A block Pandoc would read
# comes back with ok = TRUE. One that does not parse but holds a weft key
# followed by `=` (1.2.9) comes back with ok = FALSE. Anything else is not a
# block: NULL.
parse_block <- function(S, i) {
  ch <- S$chars
  n <- S$n
  if (i > n || ch[i] != "{") return(NULL)
  lim <- para_limit(S, i)
  blk <- parse_block_strict(ch, i, lim)
  if (!is.null(blk)) {
    blk$start <- i
    # the `|` of a ladder in `unit` may be written `\|` (1.2.3, 1.5.13, 4.4.23): read as `|`; one
    # written bare is noted, for a pipe-table cell
    at <- which(tolower(blk$names) == "unit")
    blk$unit_bare_bar <- any(grepl("(?<!\\\\)\\|", blk$values[at], perl = TRUE))
    blk$values[at] <- gsub("\\|", "|", blk$values[at], fixed = TRUE)
    return(blk)
  }
  close <- i + 1L
  while (close <= lim && ch[close] != "}") close <- close + 1L
  if (close > lim || close == i + 1L) return(NULL)
  raw <- paste(ch[(i + 1L):(close - 1L)], collapse = "")
  gkey <- NA_character_
  for (key in WEFT_KEYS) {
    if (grepl(paste0("(?:^|[[:space:]{,;])", key, "[[:space:]]*="), raw,
              ignore.case = TRUE, perl = TRUE)) {
      gkey <- key
      break
    }
  }
  if (is.na(gkey)) return(NULL)
  list(ok = FALSE, end = close, gkey = gkey, raw = raw)
}

parse_block_strict <- function(ch, i, lim) {
  pos <- i + 1L
  id <- NA_character_
  classes <- character()
  nms <- character()
  vals <- character()
  quotes <- character()
  nid <- 0L
  stops <- c(" ", "\t", "\r", "\n", "}")
  token_end <- function(p) {
    while (p <= lim && !(ch[p] %in% stops)) p <- p + 1L
    p - 1L
  }
  repeat {
    while (pos <= lim && ch[pos] %in% c(" ", "\t", "\r", "\n")) pos <- pos + 1L
    if (pos > lim) return(NULL)
    c <- ch[pos]
    if (c == "}") break
    if (c == "#" || c == ".") {
      e <- token_end(pos)
      if (e <= pos) return(NULL)
      tok <- paste(ch[pos:e], collapse = "")
      if (c == "#") {
        id <- substring(tok, 2L)   # the last id wins (two are an error, 1.7.5)
        nid <- nid + 1L
      } else {
        classes <- c(classes, tok)
      }
      pos <- e + 1L
      next
    }
    ke <- pos
    while (ke <= lim && !(ch[ke] %in% c(" ", "\t", "\r", "\n", "}", "=", "\"", "'", "{"))) ke <- ke + 1L
    if (ke == pos || ke > lim || ch[ke] != "=") return(NULL)
    key <- paste(ch[pos:(ke - 1L)], collapse = "")
    vp <- ke + 1L
    if (vp > lim) return(NULL)
    q <- ch[vp]
    if ((q == "\"" || q == "'") && vp + 1L > lim) return(NULL)
    if (q == "\"" || q == "'") {
      cl <- which(ch[(vp + 1L):lim] == q)[1]
      if (is.na(cl)) return(NULL)
      cl <- vp + cl
      val <- if (cl > vp + 1L) paste(ch[(vp + 1L):(cl - 1L)], collapse = "") else ""
      pos <- cl + 1L
      if (pos <= lim && !(ch[pos] %in% stops)) return(NULL)
      qq <- q
    } else {
      e <- token_end(vp)
      if (e < vp) return(NULL)
      val <- paste(ch[vp:e], collapse = "")
      if (grepl("[\"']", val)) return(NULL)
      pos <- e + 1L
      qq <- ""
    }
    nms <- c(nms, key)
    vals <- c(vals, val)
    quotes <- c(quotes, qq)
  }
  list(ok = TRUE, end = pos, id = id, classes = classes, names = nms,
       values = vals, quotes = quotes, nid = nid)
}

# The end of whatever trails a closing `]`: an attribute block, a link
# target, or nothing (the `]` itself).
after_bracket <- function(S, close) {
  nx <- close + 1L
  if (nx > S$n) return(close)
  if (S$chars[nx] == "{") {
    b <- parse_block(S, nx)
    if (!is.null(b)) return(b$end)
  } else if (S$chars[nx] == "(") {
    t <- target_end(S, nx)
    if (!is.na(t)) return(t)
  }
  close
}

# The `]` matching the `[` at `i`, or `NA`.
find_close <- function(S, i) {
  lim <- para_limit(S, i)
  depth <- 1L
  j <- i + 1L
  while (j <= lim) {
    p <- next_special(S, j)
    if (p > lim) return(NA_integer_)
    c <- S$chars[p]
    if (c == "\\") {
      j <- p + 2L
    } else if (c == "`") {
      cs <- code_span(S, p)
      if (!cs$ok) {
        j <- cs$open_end + 1L
      } else {
        j <- cs$close_end + 1L
        b <- parse_block(S, j)
        if (!is.null(b)) j <- b$end + 1L
      }
    } else if (c == "$") {
      m <- math_end(S, p)
      j <- if (is.na(m)) p + 1L else m + 1L
    } else if (c == "<") {
      ce <- angle_end(S, p)
      j <- if (is.na(ce)) p + 1L else ce + 1L
    } else if (c == "[") {
      depth <- depth + 1L
      j <- p + 1L
    } else if (c == ":") {
      j <- p + 1L
    } else {
      depth <- depth - 1L
      if (depth == 0L) return(p)
      j <- after_bracket(S, p) + 1L
    }
  }
  NA_integer_
}

# The end of a protected atom starting at `i` (code span with its block,
# math, a bracket followed by a block or a link target), or `NA`.
atom_end <- function(S, i) {
  c <- S$chars[i]
  if (c == "`") {
    cs <- code_span(S, i)
    if (!cs$ok) return(NA_integer_)
    b <- parse_block(S, cs$close_end + 1L)
    return(if (is.null(b)) cs$close_end else b$end)
  }
  if (c == "$") return(math_end(S, i))
  if (c == "[") {
    cl <- find_close(S, i)
    if (is.na(cl)) return(NA_integer_)
    e <- after_bracket(S, cl)
    return(if (e > cl) e else NA_integer_)
  }
  NA_integer_
}

# ---- arms (1.5.12, 1.5.14) ----------------------------------------------

# Split the body `b1:b2` of a span. Returns the resolved arms, the position
# of each separator, and whether a separator was written unescaped.
split_arms <- function(S, b1, b2) {
  ch <- S$chars
  tp <- character()   # token type: "t", "s", "h"
  tv <- character()   # token text
  tpos <- integer()
  tesc <- logical()
  push <- function(type, val, pos, esc = FALSE) {
    tp <<- c(tp, type)
    tv <<- c(tv, val)
    tpos <<- c(tpos, pos)
    tesc <<- c(tesc, esc)
  }
  i <- b1
  while (i <= b2) {
    c <- ch[i]
    if (c == "\\") {
      nx <- if (i < b2) ch[i + 1L] else ""
      if (nx == "|") {
        push("s", "|", i, TRUE)   # at the backslash
      } else if (nx == "#") {
        push("h", "#", i + 1L)   # the backslash goes first, then `#` is read (1.5.12)
      } else {
        push("t", paste0(c, nx), i)
      }
      i <- i + 2L
      next
    }
    if (c %in% c("`", "$", "[", "<")) {
      e <- if (c == "<") angle_end(S, i) else atom_end(S, i)
      if (!is.na(e) && e <= b2) {
        push("t", paste(ch[i:e], collapse = ""), i)
        i <- e + 1L
        next
      }
    }
    if (c == "|") push("s", "|", i) else if (c == "#") push("h", "#", i) else push("t", c, i)
    i <- i + 1L
  }
  assemble_arms(tp, tv, tpos, tesc)
}

# Join the tokens of an arm body into arms: a run of `|` tokens gives pairs
# of literal bars and, when odd, one separator; a run of `#` tokens gives
# pairs of literal hashes and, when odd, one placeholder (1.5.12).
assemble_arms <- function(tp, tv, tpos, tesc) {
  arms <- ""
  tmpl <- ""     # the same arms with `#` as the placeholder, `##` as a literal `#`
  seps <- integer()
  unesc <- FALSE
  k <- 1L
  nt <- length(tp)
  while (k <= nt) {
    ty <- tp[k]
    if (ty == "t") {
      arms[length(arms)] <- paste0(arms[length(arms)], tv[k])
      tmpl[length(tmpl)] <- paste0(tmpl[length(tmpl)], tv[k])
      k <- k + 1L
      next
    }
    j <- k
    while (j < nt && tp[j + 1L] == ty) j <- j + 1L
    len <- j - k + 1L
    if (ty == "s") {
      if (any(!tesc[k:j])) unesc <- TRUE
      lit <- len %/% 2L
      arms[length(arms)] <- paste0(arms[length(arms)], strrep("|", lit))
      tmpl[length(tmpl)] <- paste0(tmpl[length(tmpl)], strrep("|", lit))
      if (len %% 2L == 1L) {
        arms <- c(arms, "")
        tmpl <- c(tmpl, "")
        seps <- c(seps, tpos[j])
      }
    } else {
      arms[length(arms)] <- paste0(arms[length(arms)], strrep("#", (len + 1L) %/% 2L))
      tmpl[length(tmpl)] <- paste0(tmpl[length(tmpl)], strrep("#", len %/% 2L),
                                   if (len %% 2L == 1L) ARM_PLACEHOLDER else "")
    }
    k <- j + 1L
  }
  list(arms = trim_ws(arms), templates = trim_ws(tmpl), seps = seps,
       unescaped = unesc)
}


# The template of one arm given as a range `a:b` of the scanned text, with
# the `items` (data frame of `start`, `end`: constructs and inline code whose
# output is filled in later) replaced by sentinels `SENT_OPEN k SENT_CLOSE`.
# Escapes, `||` and `##` are read as in split_arms (1.5.12); atoms (code,
# math, link targets) stay verbatim (1.5.14); an atom that holds an item is
# walked through verbatim up to the item.
SENT_OPEN <- "\ue002"
SENT_CLOSE <- "\ue003"
arm_template_range <- function(S, a, b, items) {
  ch <- S$chars
  istart <- items$start
  iend <- items$end
  tp <- character()
  tv <- character()
  tpos <- integer()
  tesc <- logical()
  push <- function(type, val, pos, esc = FALSE) {
    tp <<- c(tp, type)
    tv <<- c(tv, val)
    tpos <<- c(tpos, pos)
    tesc <<- c(tesc, esc)
  }
  is_item <- function(i) if (length(istart)) match(i, istart) else NA_integer_
  i <- a
  verbatim_to <- 0L
  while (i <= b) {
    k <- is_item(i)
    if (!is.na(k)) {
      push("t", paste0(SENT_OPEN, k, SENT_CLOSE), i)
      i <- iend[k] + 1L
      next
    }
    c <- ch[i]
    if (i <= verbatim_to) {
      push("t", c, i)
      i <- i + 1L
      next
    }
    if (c == "\\") {
      nx <- if (i < b && is.na(is_item(i + 1L))) ch[i + 1L] else ""
      if (nx == "|") {
        push("s", "|", i, TRUE)   # at the backslash
      } else if (nx == "#") {
        push("h", "#", i + 1L)
      } else {
        push("t", paste0(c, nx), i)
      }
      i <- i + 1L + nzchar(nx)
      next
    }
    if (c %in% c("`", "$", "[", "<")) {
      e <- if (c == "<") angle_end(S, i) else atom_end(S, i)
      if (!is.na(e) && e <= b) {
        if (length(istart) && any(istart >= i & istart <= e)) {
          verbatim_to <- e
          push("t", c, i)
        } else {
          push("t", paste(ch[i:e], collapse = ""), i)
          i <- e
        }
        i <- i + 1L
        next
      }
    }
    if (c == "|") push("s", "|", i) else if (c == "#") push("h", "#", i) else push("t", c, i)
    i <- i + 1L
  }
  asm <- assemble_arms(tp, tv, tpos, tesc)
  paste(asm$templates, collapse = "|")
}

# ---- expressions (5.3.5, 3.1.10) ----------------------------------------

claim_without_check <- function(expr) {
  if (!is.call(expr)) return(FALSE)
  fn <- expr[[1L]]
  is_claim <- identical(fn, quote(claim)) ||
    (is.call(fn) && length(fn) == 3L && identical(fn[[1L]], quote(`::`)) &&
       identical(fn[[3L]], quote(claim)))
  l <- as.list(expr)
  # an empty argument, as in `claim(x, )`, is no check (3.1.10)
  empty <- vapply(seq_along(l), function(k) identical(l[[k]], quote(expr = )), NA)
  if (is_claim && sum(!empty[-1L]) < 2L) return(TRUE)
  for (k in seq_along(l)) {
    if (!empty[k] && is.call(l[[k]]) && claim_without_check(l[[k]])) return(TRUE)
  }
  FALSE
}

# An error message for an inline expression, or `character()` when it is
# fine. `as_list` reads `if` conditions as an argument list (1.5.4).
expr_errors <- function(text, what, as_list = FALSE) {
  if (!nzchar(trim_ws(text))) return(sprintf("%s is empty (rule 5.3.5).", what))
  src <- if (as_list) paste0("list(", text, ")") else text
  ex <- tryCatch(parse(text = src, keep.source = FALSE), error = function(e) e)
  if (inherits(ex, "error")) {
    msg <- strsplit(conditionMessage(ex), "\n", fixed = TRUE)[[1]][1]
    return(sprintf("%s does not parse as R (rule 5.3.5): %s", what, msg))
  }
  for (e in as.list(ex)) {
    if (claim_without_check(e)) {
      return(sprintf("%s has a claim() with no check (rule 3.1.10).", what))
    }
  }
  character()
}

# ---- blocks: errors and fields ------------------------------------------

BIND_HINT <- "Bind the expression to a name in a chunk and use the name."

# Shared checks on the attribute block of a weft construct.
block_errors <- function(S, blk, kind) {
  e <- character()
  if (!blk$ok) {
    raw <- blk$raw %||% ""
    quoting <- grepl("\\", raw, fixed = TRUE)
    cause <- if (quoting) {
      "a `\"` or a `\\` inside a value ends it early"
    } else if (grepl("[[:space:]]=|=[[:space:]]", raw)) {
      "spaces around `=` are not allowed"
    } else if (grepl("=[[:space:]]*$", raw)) {
      "a key has no value"
    } else if (grepl("(^|[[:space:]])[#.]([[:space:]]|$)", raw)) {
      "a `#` or `.` has nothing after it"
    } else {
      "a `\"` or a `\\` inside a value ends it early"
    }
    quoted <- quoting || startsWith(cause, "a `\"` or a")
    return(paste0("The attribute block does not parse: ", cause,
                  " (rules 1.2.3, 1.2.9)", if (quoted) paste0(". ", BIND_HINT) else "."))
  }
  if (any(blk$quotes == "'")) {
    e <- c(e, paste0("A single-quoted value in an attribute block (rule 1.2.3). ",
                     BIND_HINT))
  }
  if (any(grepl("\\", blk$values, fixed = TRUE))) {
    e <- c(e, paste0("A `\\` inside a value (rule 1.2.3). ", BIND_HINT))
  }
  # a ladder in `unit` (4.4.23): an empty or a repeated rung; in a pipe-table cell its `|` is `\|`
  for (uv in blk$values[tolower(blk$names) == "unit"]) {
    if (grepl("|", uv, fixed = TRUE)) {
      pr <- ladder_split(uv)$problem
      if (!is.null(pr)) e <- c(e, pr)
    }
  }
  if (isTRUE(blk$unit_bare_bar) && !is.null(blk$start) && isTRUE(S$tbl[line_index(S, blk$start)])) {
    e <- c(e, paste0("An unescaped `|` in the `unit` of a construct in a pipe-table cell (rule 1.5.13); ",
                     "write `\\|`."))
  }
  lc <- lower_keys(blk$names)
  if (any(duplicated(lc))) {
    e <- c(e, sprintf("The key `%s` is written twice in one block (rule 1.2.10).",
                      lc[duplicated(lc)][1]))
  }
  # a `claim` or `level` key on a named value, or on a span the filter resolves, states a check the
  # filter would never run (the filter says the same)
  if (kind == "named" || (isTRUE(S$filter_doc) && kind %in% c("n", "if", "sign", "list", "cite"))) {
    ck <- intersect(c("claim", "level"), lc)
    if (length(ck)) {
      e <- c(e, filter_check_key_error(ck[1L], if (kind == "named") "a named value" else "a span"))
    }
  }
  gov <- lc[lc %in% GOVERNOR_KEYS]
  if (kind %in% c("value", "bare") && length(gov)) {
    e <- c(e, sprintf("The key `%s` on a value is an error (rule 1.3.3).", gov[1]))
  } else if (kind == "named" && length(gov)) {
    e <- c(e, sprintf("A named value takes no `%s`: a governor key belongs on a span (rule 1.3.3).", gov[1]))
  } else if (length(unique(gov)) > 1L) {
    e <- c(e, sprintf("More than one of n, if, sign, cite and list in one block: %s (rule 1.1.5).",
                      paste(gov, collapse = ", ")))
  }
  cls <- unique(blk$classes)
  if ((blk$nid %||% 0L) > 1L) {
    e <- c(e, "Two ids in one block; an element has one id (rule 1.7.5).")
  }
  if (any(cls %in% LIST_CLASSES)) {
    reg_text <- names(S$reg)[vapply(S$reg, function(r) identical(r[["stage"]], "text"), NA)]
    tx <- c(intersect(cls, c(TEXT_CLASSES, reg_text)), intersect(lc, "trunc"))
    if (length(tx)) {
      e <- c(e, sprintf(paste0("`%s` makes a block, so a text class or `trunc` (`%s`) cannot ",
                               "go with it (rule 1.4.6)."),
                        intersect(cls, LIST_CLASSES)[1L], tx[1L]))
    }
  }
  if (kind %in% c("n", "sign", "list") && "level" %in% lc && !isTRUE(S$filter_doc)) {
    e <- c(e, sprintf("A `%s` span has no `level`; only `claim()` takes a level.", kind))
  }
  if (kind == "list" && any(cls %in% LIST_CLASSES)) {
    e <- c(e, sprintf(paste0("`%s` makes a block, and the `#` of a `list` span is inline; ",
                             "a block class cannot go on a `list` span (rule 1.5.19)."),
                      intersect(cls, LIST_CLASSES)[1L]))
  }
  if (!is.na(blk$id)) {
    if (kind == "text") {
      e <- c(e, "An `#id` on a text span is an error (rule 1.1.9).")
    } else if (kind == "cite") {
      e <- c(e, "An `#id` on a cite span is an error (rule 1.7.5).")
    }
  }
  grp <- class_group(cls, S$reg)
  if (kind == "named") {
    # `.val` is in the number stage's at-most-one group (N8), and takes no wording class
    grp[cls == ".val"] <- "number"
    if (".val" %in% cls) {
      reg_wording <- names(S$reg)[vapply(S$reg, function(r) identical(r[["stage"]], "wording"), NA)]
      wc <- intersect(cls, c(WORDING_CLASSES, reg_wording))
      if (length(wc)) {
        e <- c(e, sprintf("`.val` prints a value as it is and cannot take `.%s` (rule 1.12.2).",
                          sub("^[.]", "", wc[1L])))
      }
    }
  }
  for (g in unique(grp[!is.na(grp)])) {
    if (sum(grp == g, na.rm = TRUE) > 1L) {
      e <- c(e, if (g == "unit") {
        sprintf("Two unit classes in one block: %s (rule 1.4.2).", paste(cls[which(grp == g)], collapse = " "))
      } else {
        sprintf("Two classes from one group in one block: %s (rule 1.4.2).",
                paste(cls[which(grp == g)], collapse = " "))
      })
    }
  }
  # a spelled number takes the unit's name, so `.usym` cannot go with the
  # classes that spell one (1.4.19)
  spelling <- c(intersect(cls, c(".no", ".word", ".count")),
                intersect(cls, names(S$reg))[vapply(intersect(cls, names(S$reg)), function(k) {
                  identical(S$reg[[k]][["stage"]], "wording")
                }, NA)])
  if (".usym" %in% cls && length(spelling)) {
    e <- c(e, sprintf("The unit class `.usym` with `%s` is an error: a spelled number takes the unit's name (rule 1.4.19).",
                      spelling[1L]))
  }
  if (any(cls %in% UNIT_CLASSES) && kind %in% c("if", "cite")) {
    e <- c(e, sprintf("A unit class on %s is an error (rule 1.4.19): %s.",
                      if (kind == "if") "an `if` span" else "a `cite` span",
                      paste(intersect(cls, UNIT_CLASSES), collapse = " ")))
  }
  if (all(c("digits", "sigfig") %in% lc)) {
    e <- c(e, "`digits` with `sigfig` is an error (rule 1.4.7).")
  }
  if (kind == "if") {
    if ("level" %in% lc) {
      e <- c(e, "A guard (`if` with one arm) has no `level`; only `claim()` takes a level.")
    }
    fm <- intersect(cls, formatter_classes(S$reg))
    # a text-stage class acts on the chosen arm's final text (1.5.7, 1.4.8)
    is_text <- vapply(fm, function(k) identical((S$reg[[k]] %||% list())[["stage"]], "text"), NA)
    fm <- fm[!is_text & !(fm %in% c(".em", ".strong", UNIT_CLASSES))]
    ky <- intersect(lc, RENDERER_KEYS)
    if (length(fm) || length(ky)) {
      e <- c(e, sprintf("A formatter on an `if` span is an error (rule 1.5.7): %s.",
                        paste(c(fm, ky), collapse = " ")))
    }
  }
  if (length(intersect(cls, c(".p", ".date"))) && any(c("digits", "sigfig") %in% lc)) {
    e <- c(e, sprintf("`digits` and `sigfig` do not apply to `%s` (rule 1.4.7).",
                      intersect(cls, c(".p", ".date"))[1L]))
  }
  if (kind == "sign" && !S$filter_doc && length(blk$values[lc == "sign"]) &&
      identical(trim_ws(blk$values[lc == "sign"][1L]), ".")) {
    e <- c(e, "There is no `sign=\".\"` (rule 1.7.2); only `n=\".\"` inherits.")
  }
  if (kind == "list" && !S$filter_doc && length(blk$values[lc == "list"]) &&
      identical(trim_ws(blk$values[lc == "list"][1L]), ".")) {
    e <- c(e, "There is no `list=\".\"`; only `n=\".\"` inherits (stage 1h).")
  }
  if (kind == "list" && !is.na(blk$id)) {
    e <- c(e, "An `#id` on a `list` span is an error (stage 1h).")
  }
  if ("none" %in% lc) {
    nv <- blk$values[lc == "none"][1L]
    if (!kind %in% c("value", "named")) {
      e <- c(e, "The key `none` belongs on a value with a collapse class (stage 1h).")
    } else if (!any(cls %in% c(COLLAPSE_CLASSES, names(S$reg)[vapply(
        S$reg, function(r) identical(r[["stage"]], "collapse"), NA)]))) {
      e <- c(e, "The key `none` needs a collapse class (`.and`, `.or`, `.pairs`, `.ul`, `.ol`, `.dl`) on the value (stage 1h).")
    } else if (".range" %in% cls) {
      e <- c(e, "The key `none` does not apply to `.range`: a range has two ends (stage 1h).")
    } else if (!nzchar(trim_ws(nv))) {
      e <- c(e, "The key `none` is empty; give the text to print for an empty value (stage 1h).")
    }
  }
  if (kind == "cite") {
    fm <- intersect(cls, formatter_classes(S$reg))
    is_text <- vapply(fm, function(k) identical((S$reg[[k]] %||% list())[["stage"]], "text"), NA)
    fm <- fm[!is_text & !(fm %in% UNIT_CLASSES)]
    if (length(fm)) {
      e <- c(e, sprintf("A formatter class on a cite span is an error (rule 1.8.7): %s.",
                        paste(fm, collapse = " ")))
    }
    ky <- intersect(lc, RENDERER_KEYS)
    if (length(ky)) {
      e <- c(e, sprintf("A renderer key on a cite span is an error (rule 1.8.7): %s.",
                        paste(ky, collapse = " ")))
    }
    cv <- blk$values[lc == "cite"]
    if (length(cv)) e <- c(e, cite_errors(cv[1L]))
  }
  if (kind == "literal") {
    why <- blk$values[blk$names == "why"]
    if (!length(why) || !nzchar(trim_ws(why[1L]))) {
      e <- c(e, paste0("A `.weft-literal` with no `why` is an error (rule 1.8.10); write ",
                       "`why=\"...\"` to say where the literal comes from."))
    }
  }
  e
}

# Pandoc's citation key grammar: a letter, digit or underscore, then letters,
# digits, underscores and internal punctuation (`:.#$%&-+?<>~/`) that is
# followed by a letter, digit or underscore.
CITE_KEY_RE <- "[\\p{L}\\p{N}_](?:[\\p{L}\\p{N}_]|[:.#$%&+?<>~/-](?=[\\p{L}\\p{N}_]))*"

# The keys of a `cite` value (1.8.1, 1.8.4, 1.8.6): with an `@` anywhere it is
# the citation form and each `@key` is a key; otherwise it is bare keys
# separated by `;`.
cite_keys <- function(value) {
  if (grepl("@", value, fixed = TRUE)) {
    m <- gregexpr(paste0("@(?:\\{([^}]*)\\}|(", CITE_KEY_RE, "))"), value, perl = TRUE)[[1L]]
    if (m[1L] < 0L) return(character())
    s <- regmatches(value, list(m))[[1L]]
    sub("^@\\{?([^}]*)\\}?$", "\\1", s)
  } else {
    trim_ws(strsplit(value, ";", fixed = TRUE)[[1L]])
  }
}

cite_errors <- function(value) {
  if (grepl("@", value, fixed = TRUE)) {
    # each `@` must open a key
    at <- gregexpr("@", value, fixed = TRUE)[[1L]]
    ok <- gregexpr(paste0("@(?:\\{[^}]+\\}|", CITE_KEY_RE, ")"), value, perl = TRUE)[[1L]]
    if (length(at) != sum(ok > 0L)) {
      return(paste0("A `@` in a cite value must open a key that follows Pandoc's key ",
                    "grammar (rule 1.8.5): letters, digits and `_`, with internal ",
                    "punctuation."))
    }
    return(character())
  }
  parts <- strsplit(value, ";", fixed = TRUE)[[1L]]
  if (!length(parts) || endsWith(value, ";")) parts <- c(parts, "")
  bad <- !grepl(paste0("^", CITE_KEY_RE, "$"), trim_ws(parts), perl = TRUE)
  if (any(bad)) {
    return(sprintf(paste0("A cite value with no `@` is keys only, separated by `;`, each ",
                          "following Pandoc's key grammar (rules 1.8.4, 1.8.5); `%s` is not a key."),
                   trim_ws(parts)[bad][1L]))
  }
  character()
}

# A back-reference: the whole value of `n` or `sign` is `#` and an id (1.7.6).
is_backref <- function(expr) grepl("^#[^[:space:]]+$", trim_ws(expr))

lower_keys <- function(nms) ifelse(tolower(nms) %in% WEFT_KEYS, tolower(nms), nms)

# ---- named values and the filter's grammar (N5-N13) -----------------------------------------

# A NAME (N6): ASCII, a letter or `_` and then letters, digits, `_` or `.`, at most 64 characters, not
# ending in a dot, and not one of the reserved words.
is_weft_name <- function(x) {
  length(x) == 1L && !is.na(x) && grepl("^[A-Za-z_][A-Za-z0-9_.]{0,63}$", x, perl = TRUE) &&
    !grepl(".", substring(x, nchar(x)), fixed = TRUE) && !(x %in% NAME_RESERVED)
}

# The construct error of a `claim` or `level` key on a named value or a span the filter resolves (S1);
# the text is the filter's (weft.lua, check_key_error).
filter_check_key_error <- function(key, what) {
  sprintf(paste0("`%s` is not a key the filter reads on %s, so the check would never run. State it with a ",
                 "guard span around the value, [`x`{.num}]{if=\"x < 50\"}, or with claim() in code (rule 5.3.3)."),
          key, what)
}

# The parts of a condition (N10): split at every comma that is not inside a 'string literal'; an empty
# part is kept.
cond_parts <- function(x) {
  ch <- strsplit(x, "")[[1L]]
  parts <- character()
  cur <- character()
  inq <- FALSE
  for (c in ch) {
    if (c == "'") inq <- !inq
    if (c == "," && !inq) {
      parts <- c(parts, paste(cur, collapse = ""))
      cur <- character()
    } else {
      cur <- c(cur, c)
    }
  }
  c(parts, paste(cur, collapse = ""))
}

COND_OPERAND <- "(?:'[^'\\\\]*'|-?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|[A-Za-z_][A-Za-z0-9_.]*)"
COND_RE <- paste0("^(", COND_OPERAND, ")[ \t]*(<=|>=|==|!=|<|>)[ \t]*(", COND_OPERAND, ")$")

# The error of one part of a condition (N9, N11; E3, E4), or `character()`.
cond_part_error <- function(part) {
  if (is_weft_name(part)) return(character())
  # `!NAME`: the negation of one bool name; `!` before anything else is not in the grammar
  if (startsWith(part, "!") && is_weft_name(substring(part, 2L))) return(character())
  m <- regmatches(part, regexec(COND_RE, part, perl = TRUE))[[1L]]
  if (length(m)) {
    ops <- m[c(2L, 4L)]
    lit <- grepl("^['0-9-]", ops)
    if (all(lit)) {
      return(sprintf("`%s` compares two literals and has no name, so it is always the same (rule 1.12.4).", part))
    }
    if (all(lit | vapply(ops, is_weft_name, NA))) return(character())
  }
  sprintf(paste0("`%s` is not a name or one comparison of names, numbers and 'strings'; bind the condition ",
                 "to a name in code (rule 1.12.4)."), part)
}

# The grammar errors of a span's governor in a document the filter resolves (N9-N12; E3-E5).
filter_governor_errors <- function(kind, expr, check_space = TRUE) {
  v <- trim_ws(expr)
  bad <- function(extra) {
    sprintf("`%s` is not a name for `%s`; it takes a name%s (rule 1.12.6).", v, kind, extra)
  }
  # Pandoc does not read an attribute value that starts with a space, so the span would print as text
  if (check_space && grepl("^[ \t\r\n]", expr)) {
    return(sprintf(paste0("The value of `%s` starts with a space, which Pandoc does not read as an ",
                          "attribute, so the span would print as it is; remove the space (rule 1.12.6)."), kind))
  }
  switch(kind,
    `if` = unlist(lapply(trim_ws(cond_parts(v)), cond_part_error), use.names = FALSE) %||% character(),
    n = if (is_weft_name(v) || identical(v, ".") || is_backref(v)) character() else bad(", `.` or `#id`"),
    sign = if (is_weft_name(v) || is_backref(v)) character() else bad(" or `#id`"),
    list = if (is_weft_name(v)) character() else bad(""),
    character())
}

# The classes that make a code span with an attribute block a named value (N5).
named_classes <- function(reg) c(formatter_classes(reg), TEXT_CLASSES, ".val")

# ---- rows ---------------------------------------------------------------

add_row <- function(S, kind, start, end, bstart, expr, classes, keys, id, arms,
                    seps, parent, error, templates = NULL) {
  S$nrows <- S$nrows + 1L
  assign(as.character(S$nrows), list(
    kind = kind, start = start, end = end, bstart = bstart, expr = expr,
    classes = classes, keys = keys, id = id, arms = arms, seps = seps,
    templates = templates, parent = parent, error = if (length(error)) paste(error, collapse = "\n") else NA_character_
  ), envir = S$rows)
  S$nrows
}

get_row <- function(S, k) get(as.character(k), envir = S$rows, inherits = FALSE)

named_chr <- function(values, names) {
  stats::setNames(as.character(values), as.character(names))
}

# The nearest enclosing span that is a governor or marker, for `n="."`. An
# `if` span does not hide the governor around it (1.7.2).
enclosing_governor <- function(S, parent) {
  while (!is.na(parent)) {
    r <- get_row(S, parent)
    if (r$kind %in% c("n", "sign", "cite", "list")) return(r$kind)
    parent <- r$parent
  }
  NA_character_
}

# ---- the walk -----------------------------------------------------------

scan_seq <- function(S, from, to, parent) {
  i <- from
  while (i <= to) {
    p <- next_special(S, i)
    if (p > to) break
    fe <- fence_end_at(S, p)
    if (!is.na(fe)) {
      i <- fe + 1L
      next
    }
    c <- S$chars[p]
    i <- switch(
      c,
      "\\" = p + 2L,
      "<" = {
        ce <- angle_end(S, p)
        if (is.na(ce)) p + 1L else ce + 1L
      },
      "`" = handle_code(S, p, parent, FALSE),
      "$" = {
        m <- math_end(S, p)
        if (is.na(m)) p + 1L else scan_math(S, p, m, parent)
      },
      "[" = handle_bracket(S, p, parent),
      "]" = handle_stray_close(S, p, parent),
      ":" = handle_div(S, p, parent),
      p + 1L
    )
  }
  invisible()
}

# A fenced-div opening line at `p`. A `.weft-literal` div is a row whose range
# is the opening line (1.8.9); any other div is Pandoc's and left alone.
handle_div <- function(S, p, parent) {
  nl <- S$nl[findInterval(p, S$nl) + 1L]
  line_end <- if (is.na(nl)) S$n else nl - 1L
  while (line_end > p && S$chars[line_end] %in% c("\r", " ", "\t")) line_end <- line_end - 1L
  # after the colons: Pandoc's `{...}` form, or the bare class `weft-literal`;
  # colons may trail either (`::: {.weft-literal} :::`)
  q <- p
  while (q <= line_end && S$chars[q] == ":") q <- q + 1L
  while (q <= line_end && S$chars[q] %in% c(" ", "\t")) q <- q + 1L
  if (q > line_end) return(line_end + 1L)
  trailing <- function(from) {
    !nzchar(gsub("[: \t]", "", if (from <= line_end) substr(S$text, from, line_end) else ""))
  }
  if (S$chars[q] == "{") {
    blk <- parse_block(S, q)
    if (is.null(blk) || !blk$ok || !(".weft-literal" %in% blk$classes) || blk$end > line_end ||
        !trailing(blk$end + 1L)) {
      return(line_end + 1L)
    }
    lc <- lower_keys(blk$names)
    keep <- !lc %in% GOVERNOR_KEYS
    add_row(S, "literal", p, blk$end, q, NA_character_, blk$classes,
            named_chr(blk$values[keep], lc[keep]), blk$id, NULL, integer(), parent,
            block_errors(S, blk, "literal"))
    return(line_end + 1L)
  }
  e <- q
  while (e <= line_end && !(S$chars[e] %in% c(" ", "\t", ":"))) e <- e + 1L
  if (!identical(substr(S$text, q, e - 1L), "weft-literal") || !trailing(e)) {
    return(line_end + 1L)
  }
  blk <- list(ok = TRUE, names = character(), values = character(), quotes = character(),
              classes = ".weft-literal", id = NA_character_, nid = 0L)
  add_row(S, "literal", p, e - 1L, q, NA_character_, ".weft-literal",
          named_chr(character(), character()), NA_character_, NULL, integer(), parent,
          block_errors(S, blk, "literal"))
  line_end + 1L
}

# A `]` that no `[` opened, followed by an attribute block that holds a weft
# key: a span split by a blank line (a span ends with its paragraph), which
# would otherwise print its block raw.
handle_stray_close <- function(S, p, parent) {
  blk <- parse_block(S, p + 1L)
  if (is.null(blk)) return(p + 1L)
  keys <- if (blk$ok) lower_keys(blk$names) else blk$gkey
  hit <- intersect(keys, WEFT_KEYS)
  if (!length(hit)) return(p + 1L)
  gov <- intersect(hit, GOVERNOR_KEYS)
  kind <- if (length(gov)) gov[1L] else "text"
  add_row(S, kind, p, blk$end, p + 1L, NA_character_, character(),
          named_chr(character(), character()), NA_character_, NULL, integer(),
          parent, paste0(
            "The span is split by a blank line: this `]{...}` has no opening `[` in its ",
            "paragraph, and a span cannot hold a blank line (rule 1.1.5). Keep the whole ",
            "span in one paragraph."))
  blk$end + 1L
}

# Inline R inside math is read (5.2.6); nothing else in math is a construct.
scan_math <- function(S, p, m, parent) {
  i <- p + 1L
  while (i < m) {
    q <- next_special(S, i)
    if (q >= m) break
    if (S$chars[q] == "`") {
      i <- handle_code(S, q, parent, TRUE)
    } else {
      i <- q + 1L
    }
  }
  m + 1L
}

# Inline R in a link target is evaluated by knitr, so it is read (1.1.8).
scan_target <- function(S, from, to, parent) {
  i <- from
  while (i <= to) {
    p <- next_special(S, i)
    if (p > to) break
    if (S$chars[p] == "\\") {
      i <- p + 2L
    } else if (S$chars[p] == "`") {
      cs <- code_span(S, p)
      if (!cs$ok || cs$close_end > to + 1L) {
        i <- cs$open_end + 1L
      } else {
        i <- handle_code(S, p, parent, FALSE, TRUE)
      }
    } else {
      i <- p + 1L
    }
  }
  invisible()
}

# Whether the text from `a` to `b` is the whole of its paragraph (1.4.6): what
# stands before and after it in the paragraph is blank, or a div fence.
alone_in_paragraph <- function(S, a, b) {
  k <- findInterval(a - 1L, S$plim)
  from <- if (k == 0L) 1L else S$plim[k] + 1L
  to <- para_limit(S, b)
  blank <- function(x) {
    x <- gsub("(^|\n)[ \t]*:{3,}[^\n]*", "", x)
    !nzchar(trim_ws(x))
  }
  before <- if (a > from) substr(S$text, from, a - 1L) else ""
  after <- if (to > b) substr(S$text, b + 1L, to) else ""
  blank(before) && blank(after)
}

# The container a block value at `p` sits in, from what stands before it on its
# line: a pipe-table cell, a block quote, a list item, or an indented block.
# `NA` at the top level.
block_container <- function(S, p) {
  li <- line_index(S, p)
  if (isTRUE(S$tbl[li])) return("a table cell")
  from <- if (li == 1L) 1L else S$nl[li - 1L] + 1L
  pre <- if (p > from) substr(S$text, from, p - 1L) else ""
  if (grepl("^[ \t]*>", pre)) return("a block quote")
  if (grepl("^[ \t]*([-*+]|[0-9]+[.)])[ \t]+$", pre)) return("a list item")
  if (grepl("^( {2,}|\t)", pre) && !nzchar(trim_ws(pre))) return("an indented block (a list item)")
  NA_character_
}

# A code span that is not inline R: a named value when its text is followed by an attribute block that holds
# a weft class or a renderer key (N5). Its text must then be a NAME (N7). `R x` is an R value, not a name.
handle_named <- function(S, p, cs, content, parent, skip) {
  after <- cs$close_end + 1L
  if (skip || grepl("^R[ \t\r\n]", content)) return(after)
  blk <- parse_block(S, after)
  if (is.null(blk)) return(after)
  if (blk$ok) {
    lc <- lower_keys(blk$names)
    weft <- any(blk$classes %in% named_classes(S$reg)) || any(lc %in% NAMED_KEYS)
  } else {
    weft <- blk$gkey %in% NAMED_KEYS
  }
  if (!weft) return(after)
  name <- trim_ws(content)
  errs <- character()
  if (!is_weft_name(name)) {
    errs <- c(errs, sprintf(paste0("`%s` is not a name, so it cannot carry a weft class: a named value holds ",
                                   "one name. Bind the value to a name in code (rule 1.12.3)."), name))
  }
  errs <- c(errs, block_errors(S, blk, "named"))
  classes <- character()
  keys <- named_chr(character(), character())
  id <- NA_character_
  if (blk$ok) {
    keep <- !lc %in% GOVERNOR_KEYS
    keys <- named_chr(blk$values[keep], lc[keep])
    classes <- blk$classes
    id <- blk$id
    if (any(classes %in% LIST_CLASSES)) {
      lcls <- intersect(classes, LIST_CLASSES)[1L]
      box <- block_container(S, p)
      if (!is.na(box)) {
        errs <- c(errs, sprintf(paste0(
          "`%s` makes a block, and a block cannot be put in %s reliably (rule 1.4.6); ",
          "put it in a paragraph of its own at the top level."), lcls, box))
      } else if (!alone_in_paragraph(S, p, blk$end)) {
        errs <- c(errs, sprintf(paste0(
          "`%s` makes a block, so the value must be alone in its paragraph (rule 1.4.6); ",
          "put it in a paragraph of its own."), lcls))
      }
    }
  }
  add_row(S, "named", p, blk$end, after, name, classes, keys, id, NULL, integer(), parent, errs)
  blk$end + 1L
}

handle_code <- function(S, p, parent, in_math, in_target = FALSE) {
  cs <- code_span(S, p)
  if (!cs$ok) return(cs$open_end + 1L)
  cstart <- cs$open_end + 1L
  cend <- cs$close_start - 1L
  content <- if (cend >= cstart) paste(S$chars[cstart:cend], collapse = "") else ""
  # What knitr evaluates: `r ` or `r#` straight after the backtick, with no
  # padding stripped (1.1.8); `{r} ` is the Quarto form.
  mm <- regmatches(content, regexec("^(r|\\{r\\})([ #\t\r\n])", content))[[1]]
  if (!length(mm)) return(handle_named(S, p, cs, content, parent, in_math || in_target))
  if (!(mm[3] %in% c("\r", "\n") ||
        (mm[2] == "r" && mm[3] %in% c(" ", "#")) ||
        (mm[2] != "r" && mm[3] %in% c(" ", "\t")))) {
    return(cs$close_end + 1L)
  }
  expr <- trim_ws(substring(content, nchar(mm[1]) + 1L))
  newline <- mm[3] %in% c("\r", "\n")
  after <- cs$close_end + 1L
  blk <- parse_block(S, after)
  errs <- character()
  if (newline) {
    errs <- c(errs, paste0(
      "A code span that opens with `r` and a line break is left by knitr as ",
      "literal code (rule 5.3.4); write `r ` and the expression on one line."))
  } else {
    errs <- c(errs, expr_errors(expr, "The inline expression"))
  }
  classes <- character()
  keys <- named_chr(character(), character())
  id <- NA_character_
  if (is.null(blk)) {
    kind <- "bare"
    end <- cs$close_end
    bstart <- NA_integer_
  } else {
    kind <- "value"
    end <- blk$end
    bstart <- after
    errs <- c(errs, block_errors(S, blk, "value"))
    if (in_math) errs <- c(errs, "An attribute block inside math is an error (rule 5.2.6).")
    if (in_target) {
      errs <- c(errs, paste0("An attribute block on inline R in a link target is ",
                             "an error; bind the value to a name or move it out of the link."))
    }
    if (blk$ok) {
      lc <- lower_keys(blk$names)
      classes <- blk$classes
      keep <- !lc %in% GOVERNOR_KEYS
      keys <- named_chr(blk$values[keep], lc[keep])
      id <- blk$id
      if (any(classes %in% LIST_CLASSES)) {
        lcls <- intersect(classes, LIST_CLASSES)[1L]
        box <- block_container(S, p)
        if (!is.na(box)) {
          errs <- c(errs, sprintf(paste0(
            "`%s` makes a block, and a block cannot be put in %s reliably (rule 1.4.6); ",
            "put it in a paragraph of its own at the top level."), lcls, box))
        } else if (!alone_in_paragraph(S, p, end)) {
          errs <- c(errs, sprintf(paste0(
            "`%s` makes a block, so the value must be alone in its paragraph (rule 1.4.6); ",
            "put it in a paragraph of its own."), lcls))
        }
      }
    }
  }
  add_row(S, kind, p, end, bstart, expr, classes, keys, id, NULL, integer(),
          parent, errs)
  end + 1L
}

handle_bracket <- function(S, p, parent) {
  close <- find_close(S, p)
  if (is.na(close)) return(p + 1L)
  nx <- close + 1L
  inner <- function(par) if (close > p + 1L) scan_seq(S, p + 1L, close - 1L, par)
  if (nx <= S$n && S$chars[nx] == "(") {
    inner(parent)
    t <- target_end(S, nx)
    if (is.na(t)) return(close + 1L)
    scan_target(S, nx + 1L, t - 1L, parent)
    # a weft key on a link is an error (1.9.1)
    lb <- parse_block(S, t + 1L)
    if (!is.null(lb) && (!lb$ok || any(lower_keys(lb$names) %in% WEFT_KEYS))) {
      add_row(S, "link", p, lb$end, t + 1L, NA_character_, character(),
              named_chr(character(), character()), NA_character_, NULL, integer(),
              parent, paste0(
                "A weft key on a link is an error (rule 1.9.1); put the link ",
                "inside a span, `[[text](url)]{...}`."))
      return(lb$end + 1L)
    }
    return(t + 1L)
  }
  blk <- parse_block(S, nx)
  if (is.null(blk)) {
    inner(parent)
    return(close + 1L)
  }
  if (blk$ok) {
    lc <- lower_keys(blk$names)
    gov <- which(lc %in% GOVERNOR_KEYS)
    kind <- if (length(gov)) {
      lc[gov[1]]
    } else if (any(blk$classes %in% c(".a", ".cap", ".strong", ".em")) || "none" %in% lc) {
      "text"
    } else if (".weft-literal" %in% blk$classes) {
      "literal"
    } else {
      NA_character_
    }
  } else {
    kind <- if (blk$gkey %in% GOVERNOR_KEYS) blk$gkey else "text"
  }
  if (is.na(kind)) {
    inner(parent)
    return(blk$end + 1L)
  }

  errs <- block_errors(S, blk, kind)
  expr <- NA_character_
  classes <- character()
  keys <- named_chr(character(), character())
  id <- NA_character_
  if (blk$ok) {
    lc <- lower_keys(blk$names)
    gov <- which(lc %in% GOVERNOR_KEYS)
    if (length(gov)) expr <- blk$values[gov[1]]
    keep <- !lc %in% GOVERNOR_KEYS
    keys <- named_chr(blk$values[keep], lc[keep])
    classes <- blk$classes
    id <- blk$id
  }
  arms <- NULL
  templates <- NULL
  seps <- integer()
  if (kind %in% c("n", "if", "sign", "list")) {
    sp <- split_arms(S, p + 1L, close - 1L)
    arms <- sp$arms
    templates <- sp$templates
    seps <- sp$seps
    allowed <- list(n = 1:4, `if` = 1:2, sign = 2:3, list = 2:4)[[kind]]
    if (!length(arms) %in% allowed) {
      errs <- c(errs, sprintf(
        "A `%s` span takes %s arms; this has %d (rules 1.5.2, 1.6.4).", kind,
        paste(range(allowed), collapse = " to "), length(arms)))
    }
    if (kind == "list" && length(arms) >= 3L && grepl(ARM_PLACEHOLDER, templates[1L], fixed = TRUE)) {
      errs <- c(errs, "A `#` in the zero arm of a `list` span has nothing to print: the list is empty there (stage 1h).")
    }
    if (sp$unescaped && isTRUE(S$tbl[line_index(S, p)])) {
      errs <- c(errs, paste0(
        "An unescaped arm separator in a pipe-table cell (rule 1.5.13); write `\\|`."))
    }
    if (blk$ok && !is.na(expr) && S$filter_doc) {
      # a document the filter resolves: the governor is judged by N9-N12, never by R's parser (N141)
      # (a single-quoted value is already an error, so it is not also reported for its space)
      errs <- c(errs, filter_governor_errors(kind, expr, !any(grepl("single-quoted", errs, fixed = TRUE))))
    } else if (blk$ok && !is.na(expr)) {
      if (kind %in% c("n", "sign") && is_backref(expr)) {
        # a back-reference is an id, not R (1.7.6, 5.3.5)
      } else if (kind %in% c("n", "sign") && startsWith(trim_ws(expr), "#")) {
        errs <- c(errs, sprintf(paste0(
          "The value of `%s` starts with `#`, so it must be exactly a back-reference, `#id` ",
          "(rule 1.7.6); a `#` would make R read the rest as a comment."), kind))
      } else if (kind == "n" && identical(trim_ws(expr), ".")) {
        if (!enclosing_governor(S, parent) %in% c("n", "sign", "list")) {
          errs <- c(errs, "`n=\".\"` outside an `n`, `sign` or `list` span (rule 1.7.2).")
        }
      } else {
        errs <- c(errs, expr_errors(expr, sprintf("The value of `%s`", kind),
                                    as_list = kind == "if"))
      }
    }
  }
  idx <- add_row(S, kind, p, blk$end, nx, expr, classes, keys, id, arms, seps,
                 parent, errs, templates)
  inner(idx)
  blk$end + 1L
}

# ---- results ------------------------------------------------------------

finish_scan <- function(S) {
  nr <- S$nrows
  rows <- lapply(seq_len(nr), function(k) get_row(S, k))
  col <- function(f, type) {
    if (nr == 0L) return(type[0])
    vapply(rows, f, FUN.VALUE = type)
  }
  starts <- col(function(r) as.integer(r$start), 0L)
  parent <- col(function(r) as.integer(r$parent), 0L)
  arm <- rep(NA_integer_, nr)
  for (k in seq_len(nr)) {
    pk <- parent[k]
    if (!is.na(pk) && !is.null(rows[[pk]]$arms)) {
      arm[k] <- 1L + sum(rows[[pk]]$seps < starts[k])
    }
  }
  lines <- if (nr) line_index(S, starts) + S$first_line - 1L else integer()
  out <- list(
    kind = col(function(r) r$kind, ""),
    file = rep(as.character(S$file), nr),
    line = as.integer(lines),
    start = starts,
    end = col(function(r) as.integer(r$end), 0L),
    expr = col(function(r) as.character(r$expr), ""),
    classes = lapply(rows, function(r) r$classes),
    keys = lapply(rows, function(r) r$keys),
    id = col(function(r) as.character(r$id), ""),
    arms = lapply(rows, function(r) r$arms),
    arm_templates = lapply(rows, function(r) r$templates),
    sep_pos = lapply(rows, function(r) r$seps),
    parent = parent,
    arm = arm,
    error = col(function(r) as.character(r$error), ""),
    block_start = col(function(r) as.integer(r$bstart), 0L)
  )
  # who resolves the row (N140): a named value is the filter's; an R value is the hooks'; a span is the
  # filter's in a document it resolves, else the hooks'
  out$resolver <- if (nr == 0L) character() else {
    ifelse(out$kind == "named" | (S$filter_doc & !(out$kind %in% c("value", "bare"))), "filter", "hooks")
  }
  if (nr == 0L) {
    out$classes <- list()
    out$keys <- list()
    out$arms <- list()
    out$arm_templates <- list()
    out$sep_pos <- list()
  }
  structure(out, class = "data.frame", row.names = seq_len(nr))
}

# ---- ids (1.7.5, 1.7.10, 1.7.11) ----------------------------------------

# The errors about ids across the rows of one document: a duplicate id, and a
# back-reference to an id that is unknown, defined later, or defined inside an
# arm the reference is not in. Returns a character vector, `NA` where there is
# none. Ids belong to a whole document, so a scan of one block of prose does
# not run this (the knit hands the document's errors to its blocks).
check_ids <- function(rows, lenient = FALSE, known = character()) {
  nr <- nrow(rows)
  err <- rep(NA_character_, nr)
  if (!nr) return(err)
  add <- function(k, msg) err[k] <<- if (is.na(err[k])) msg else paste(err[k], msg, sep = "\n")
  is_def <- !is.na(rows$id) & rows$kind %in% c("value", "n", "if", "sign", "named")
  resolver <- if (is.null(rows$resolver)) rep("hooks", nr) else rows$resolver
  def <- which(is_def)
  chain <- function(k) {
    out <- character()
    cur <- k
    repeat {
      p <- rows$parent[cur]
      if (is.na(p)) break
      if (rows$kind[p] %in% c("n", "if", "sign", "list")) out <- c(out, paste(p, rows$arm[cur]))
      cur <- p
    }
    out
  }
  first <- list()
  for (k in def) {
    id <- rows$id[k]
    if (is.null(first[[id]])) {
      first[[id]] <- k
    } else {
      add(k, sprintf("The id `%s` is defined twice; an id is unique within a document (rule 1.7.5).", id))
    }
  }
  refs <- which(rows$kind %in% c("n", "sign") & !is.na(rows$expr) &
                  vapply(rows$expr, function(e) !is.na(e) && is_backref(e), NA))
  for (k in refs) {
    id <- sub("^#", "", trim_ws(rows$expr[k]))
    d <- first[[id]]
    if (is.null(d)) {
      # a child document or a caption may define it: the knit decides
      if (lenient || id %in% known) next
      add(k, sprintf("The id `#%s` is not defined in this document (rule 1.7.10).", id))
    } else if (resolver[k] == "hooks" && rows$kind[d] == "named") {
      add(k, sprintf(paste0("`#%s` names an id on a named value, which the hooks cannot read; refer to an id ",
                            "of the same form (rule 1.12.10)."), id))
    } else if (resolver[k] == "filter" && resolver[d] == "hooks") {
      add(k, sprintf(paste0("`#%s` names an id on an R value, which the filter cannot read; refer to an id ",
                            "of the same form (rule 1.12.10)."), id))
    } else if (rows$kind[d] == "if") {
      add(k, sprintf("The id `#%s` is on an `if` span, which has no printed number to refer to (rule 1.7.5).", id))
    } else if (!(rows$end[d] < rows$start[k])) {
      add(k, sprintf("The id `#%s` is defined further down, not before this span (rule 1.7.10).", id))
    } else if (!all(chain(d) %in% chain(k))) {
      add(k, sprintf(paste0("The id `#%s` is defined inside an arm that this span is not in; ",
                            "an id in an arm can be referred to only from inside the same arm ",
                            "(rule 1.7.11)."), id))
    }
  }
  err
}

# ---- entry points -------------------------------------------------------

# Scan one string of markdown. `config` is optional; it only supplies the
# project's registered formatter classes (1.4.8).
scan_text <- function(text, file = NA_character_, first_line = 1L, config = NULL,
                      lenient = FALSE, known = character(), filter_doc = FALSE) {
  rows <- scan_block(text, file, first_line, config, filter_doc)$rows
  with_id_errors(rows, lenient, known)
}

# The rows of a place that is not the document's own prose (a caption, a
# front-matter field, a `weft_str()` string): its ids are checked by the knit,
# over the document as knitted (1.7.10), not here.
scan_rows <- function(text, file = NA_character_, first_line = 1L, config = NULL, filter_doc = FALSE) {
  scan_block(text, file, first_line, config, filter_doc)$rows
}

# The rows of a whole document with the errors about its ids added; the rows
# that gained one are listed in the attribute `id_rows`.
with_id_errors <- function(rows, lenient = FALSE, known = character()) {
  ie <- check_ids(rows, lenient, known)
  hit <- !is.na(ie)
  if (any(hit)) {
    rows$error[hit] <- ifelse(is.na(rows$error[hit]), ie[hit], paste(rows$error[hit], ie[hit], sep = "\n"))
  }
  attr(rows, "id_rows") <- which(hit)
  attr(rows, "id_msgs") <- ie[hit]
  rows
}

# The same, keeping the scan state `S`, which the knitr resolver uses to read
# an arm over the same text (arm_template_range()).
scan_block <- function(text, file = NA_character_, first_line = 1L, config = NULL, filter_doc = FALSE) {
  S <- new_scan(text, file, first_line, config, filter_doc)
  if (S$n > 0L) scan_seq(S, 1L, S$n, NA_integer_)
  list(S = S, rows = finish_scan(S))
}

# Read a `.qmd` or `.Rmd` and scan it: the prose, the captions in chunk
# options, the front-matter fields and the literal strings given to
# weft_str() (2.10.2). BOM, CRLF and a missing final newline are accepted;
# fenced blocks that are not captions' chunks are skipped. `context` says
# which place a row is in.
scan_file <- function(path, config = NULL) {
  lines <- read_source_lines(path)
  scan_document(lines, file = path, config = config, project = project_type(path))
}

# Replace each YAML metadata block with spaces, keeping every line break so
# that offsets and lines stay those of the file.
blank_front_matter <- function(text) {
  if (!nzchar(text)) return(text)
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  mb <- metadata_blocks(lines)
  for (b in seq_len(nrow(mb))) {
    r <- mb$open[b]:mb$close[b]
    lines[r] <- gsub("[^\n]", " ", lines[r])
  }
  paste0(paste(lines, collapse = "\n"), if (endsWith(text, "\n")) "\n" else "")
}

# Mask every construct's code and attribute block (rule 2.10.5): one letter,
# repeated, never spaces; line breaks stay.
mask_text <- function(text) {
  r <- scan_text(text)
  if (nrow(r) == 0L) return(text)
  chars <- strsplit(text, "")[[1]]
  fill <- function(a, b) {
    idx <- a:b
    idx <- idx[chars[idx] != "\n" & chars[idx] != "\r"]
    chars[idx] <<- "x"
  }
  for (k in seq_len(nrow(r))) {
    if (r$kind[k] %in% c("bare", "value", "named")) {
      fill(r$start[k], r$end[k])
    } else if (!is.na(r$block_start[k])) {
      fill(r$block_start[k], r$end[k])
    }
  }
  paste(chars, collapse = "")
}
