# The Pandoc side of the static lints (design-3 L15, L18; package 3b): finding
# a Pandoc 3, the masked read, the prose view that `reader = "pandoc"` gives,
# and the `block-start` lint. With the default reader nothing in this file
# runs a program.

# ---- finding Pandoc (L15) ----------------------------------------------------------

pandoc_cache <- new.env(parent = emptyenv())

pandoc_version_ok <- function(path) {
  v <- tryCatch(suppressWarnings(system2(path, "--version", stdout = TRUE, stderr = FALSE)),
                error = function(e) character())
  if (!length(v)) return(FALSE)
  m <- regmatches(v[[1L]], regexpr("[0-9]+\\.[0-9]+", v[[1L]]))
  length(m) == 1L && as.integer(sub("\\..*$", "", m)) >= 3L
}

# Quarto's own Pandoc: `<bin>/tools/<arch>/pandoc` or `<bin>/tools/pandoc`,
# with the links of the `quarto` on the path resolved.
pandoc_of_quarto <- function() {
  q <- unname(Sys.which("quarto"))
  if (!nzchar(q) && requireNamespace("quarto", quietly = TRUE)) {
    q <- tryCatch(as.character(quarto::quarto_path()), error = function(e) "")
    if (!length(q) || is.na(q[[1L]])) q <- ""
    q <- q[[1L]]
  }
  if (!nzchar(q)) {
    d <- c("/Applications/quarto/bin", "/opt/quarto/bin", "/usr/local/bin",
           file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin"),
           "C:/Program Files/Quarto/bin")
    d <- d[file.exists(file.path(d, c("quarto", "quarto.exe")[(.Platform$OS.type == "windows") + 1L]))]
    if (!length(d)) return(character())
    q <- file.path(d[[1L]], "quarto")
  }
  q <- tryCatch(normalizePath(q, winslash = "/", mustWork = FALSE), error = function(e) q)
  bin <- dirname(q)
  exe <- if (.Platform$OS.type == "windows") "pandoc.exe" else "pandoc"
  c(file.path(bin, "tools", c("aarch64", "arm64", "x86_64"), exe), file.path(bin, "tools", exe))
}

# The path of a Pandoc 3 or later, or "". Looked for in the order of L15 and
# remembered for the session under the values of `weft.pandoc` and `WEFT_PANDOC`.
pandoc_path <- function() {
  opt <- getOption("weft.pandoc")
  opt <- if (is.character(opt) && length(opt) == 1L && !is.na(opt)) opt else ""
  env <- Sys.getenv("WEFT_PANDOC")
  key <- paste(opt, env, sep = "\r")
  hit <- pandoc_cache[[key]]
  if (!is.null(hit) && (!nzchar(hit) || file.exists(hit))) return(hit)
  cands <- list(opt, env, function() pandoc_of_quarto(), function() {
    if (requireNamespace("rmarkdown", quietly = TRUE)) {
      tryCatch(rmarkdown::pandoc_exec(), error = function(e) "")
    } else {
      ""
    }
  }, function() unname(Sys.which("pandoc")))
  found <- ""
  for (cand in cands) {
    paths <- if (is.function(cand)) cand() else cand
    paths <- paths[!is.na(paths) & nzchar(paths)]
    for (p in paths) {
      p <- path.expand(p)
      if (file.exists(p) && !dir.exists(p) && pandoc_version_ok(p)) {
        found <- p
        break
      }
    }
    if (nzchar(found)) break
  }
  pandoc_cache[[key]] <- found
  found
}

# ---- the masked read (L15) ---------------------------------------------------------

# The body with the metadata blocks blanked to spaces (`unmasked`), and the same
# with every construct's code and attribute block replaced by one letter
# (`masked`). Line breaks and every line's length are kept.
pandoc_texts <- function(src) {
  text <- src$text
  n <- nchar(text)
  chars <- strsplit(text, "")[[1L]]
  ls <- src$line_start
  lines <- src$lines
  blank <- logical(n)
  for (m in src$meta) {
    blank <- blank | mark_ranges(n, ls[m$open], ls[m$close] + nchar(lines[m$close]) - 1)
  }
  chars[blank & chars != "\n"] <- " "
  unmasked <- paste(chars, collapse = "")
  r <- src$rows
  fill <- logical(n)
  if (nrow(r)) {
    body <- r$context == "prose"
    isv <- r$kind %in% c("bare", "value")
    from <- ifelse(isv, r$fstart, r$fblock)
    fill <- mark_ranges(n, from[body], r$fend[body])
  }
  chars[fill & chars != "\n"] <- "x"
  list(unmasked = unmasked, masked = paste(chars, collapse = ""))
}

pandoc_json <- function(text, pandoc) {
  f <- tempfile(fileext = ".md")
  on.exit(unlink(f), add = TRUE)
  writeBin(charToRaw(enc2utf8(text)), f)
  out <- tryCatch(
    suppressWarnings(system2(pandoc, c("-f", "commonmark_x+sourcepos", "-t", "json", shQuote(f)),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) NULL)
  if (is.null(out) || !is.null(attr(out, "status")) || !length(out)) return(NULL)
  j <- paste(out, collapse = "")
  Encoding(j) <- "UTF-8"
  j
}

# every match of `pat` in `x`, as a matrix of the captured integers
pandoc_caps <- function(pat, x) {
  m <- gregexpr(pat, x, perl = TRUE)[[1L]]
  if (m[[1L]] == -1L) return(NULL)
  cs <- attr(m, "capture.start")
  cl <- attr(m, "capture.length")
  out <- vapply(seq_len(ncol(cs)), function(k) {
    as.integer(substring(x, cs[, k], cs[, k] + cl[, k] - 1L))
  }, integer(nrow(cs)))
  if (!is.matrix(out)) out <- matrix(out, nrow = nrow(cs))
  out
}

# The character column of a Pandoc column (tabs expand to stops of four) on each of `line`.
pandoc_char_col <- function(lines, line, col) {
  vapply(seq_along(line), function(k) {
    ln <- lines[line[k]]
    if (!grepl("\t", ln, fixed = TRUE)) return(as.integer(col[k]))
    ch <- strsplit(ln, "")[[1L]]
    w <- integer(length(ch))
    v <- 0L
    for (i in seq_along(ch)) {
      w[i] <- if (ch[i] == "\t") 4L - (v %% 4L) else 1L
      v <- v + w[i]
    }
    h <- which(cumsum(w) >= col[k])[1L]
    if (is.na(h)) as.integer(col[k] - sum(w) + length(ch)) else as.integer(h)
  }, 1L)
}

# From Pandoc's JSON: the file offsets the `Str` nodes cover (a logical vector of
# length `n`), and the blocks as `line`, `type`.
pandoc_parse <- function(json, src) {
  n <- nchar(src$text)
  ls <- src$line_start
  nl <- length(ls)
  pos <- "\"data-pos\",\"[^\"]*@([0-9]+):([0-9]+)-([0-9]+):([0-9]+)\"\\]"
  s <- pandoc_caps(paste0("\\{\"t\":\"Span\",\"c\":\\[\\[\"\",\\[\\],\\[\\[\"wrapper\",\"1\"\\],\\[", pos,
                          "\\]\\],\\[\\{\"t\":\"Str\""), json)
  str <- logical(n)
  if (!is.null(s)) {
    ok <- s[, 1L] <= nl & s[, 3L] <= nl
    s <- s[ok, , drop = FALSE]
    # data-pos columns expand a tab to the next stop of four: back to character columns
    c1 <- pandoc_char_col(src$lines, s[, 1L], s[, 2L])
    c2 <- pandoc_char_col(src$lines, s[, 3L], s[, 4L] - 1L)
    st <- ls[s[, 1L]] + c1 - 1
    en <- ls[s[, 3L]] + c2 - 1
    str <- mark_ranges(n, st, en)
  }
  types <- "Para|Plain|CodeBlock|RawBlock|BlockQuote|BulletList|OrderedList|DefinitionList|HorizontalRule|LineBlock"
  b1 <- pandoc_caps(paste0("\\{\"t\":\"Div\",\"c\":\\[\\[\"\",\\[\\],\\[\\[\"wrapper\",\"1\"\\],\\[\"data-pos\",\"[^\"]*@([0-9]+):[0-9]+-[0-9]+:[0-9]+\"\\]\\]\\],\\[\\{\"t\":\"(?:",
                           types, ")\""), json)
  t1 <- regmatches(json, gregexpr(paste0("\\{\"t\":\"Div\",\"c\":\\[\\[\"\",\\[\\],\\[\\[\"wrapper\",\"1\"\\],\\[\"data-pos\",\"[^\"]*@[0-9]+:[0-9]+-[0-9]+:[0-9]+\"\\]\\]\\],\\[\\{\"t\":\"(?:",
                                         types, ")\""), json, perl = TRUE))[[1L]]
  t1 <- sub("^.*\\{\"t\":\"([A-Za-z]+)\"$", "\\1", t1)
  hd <- pandoc_caps("\\{\"t\":\"Header\",\"c\":\\[[0-9],\\[\"[^\"]*\",\\[[^\\]]*\\],\\[\\[\"data-pos\",\"[^\"]*@([0-9]+):", json)
  tb <- pandoc_caps("\\{\"t\":\"Table\",\"c\":\\[\\[\"\",\\[\\],\\[\\[\"data-pos\",\"[^\"]*@([0-9]+):", json)
  line <- c(if (!is.null(b1)) b1[, 1L], if (!is.null(hd)) hd[, 1L], if (!is.null(tb)) tb[, 1L])
  type <- c(if (!is.null(b1)) t1, rep("Header", if (!is.null(hd)) nrow(hd) else 0L),
            rep("Table", if (!is.null(tb)) nrow(tb) else 0L))
  list(str = str, blocks = unique(data.frame(line = as.integer(line), type = type, stringsAsFactors = FALSE)))
}

# Pandoc's reading of a document, masked or not (cached on the source; the
# unmasked read is skipped when masking changed nothing). NULL when Pandoc
# cannot be run, with a note.
pandoc_read <- function(src, ctx, masked = TRUE) {
  key <- if (masked) "pandoc_masked" else "pandoc_unmasked"
  hit <- src$cache[[key]]
  if (!is.null(hit)) return(if (isFALSE(hit)) NULL else hit)
  fail <- function(why) {
    if (!is.null(ctx)) ctx$note(sprintf("%s: Pandoc could not be read (%s); the R reader alone was used (rule 2.10.3).", src$file, why))
    src$cache[[key]] <- FALSE
    NULL
  }
  pandoc <- pandoc_path()
  if (!nzchar(pandoc)) return(fail("no Pandoc 3 found"))
  tx <- pandoc_texts(src)
  if (!masked && identical(tx$masked, tx$unmasked)) {
    res <- pandoc_read(src, ctx, TRUE)
    src$cache[[key]] <- if (is.null(res)) FALSE else res
    return(res)
  }
  json <- pandoc_json(if (masked) tx$masked else tx$unmasked, pandoc)
  if (is.null(json)) return(fail("it gave no output"))
  res <- tryCatch(pandoc_parse(json, src), error = function(e) NULL)
  if (is.null(res)) return(fail("its output was not understood"))
  src$cache[[key]] <- res
  res
}

# The prose of a source as the lints should read it: the R reader's, and with
# `reader = "pandoc"` only the characters Pandoc also reads as text. The pieces
# beside the body (L10) are judged by the R reader alone.
lint_prose_view <- function(src, ctx) {
  if (is.null(ctx) || !identical(ctx$reader, "pandoc") || !nzchar(src$text)) return(src$prose)
  hit <- src$cache$prose_pandoc
  if (!is.null(hit)) return(hit)
  pr <- src$prose
  pd <- pandoc_read(src, ctx, TRUE)
  # with this reader both trees are read for a file (L15), whichever rule asks
  if (!is.null(pd)) pandoc_read(src, ctx, FALSE)
  if (!is.null(pd)) {
    n <- nchar(pr)
    rg <- src$regions
    piece <- rg$type %in% c("yaml_field", "caption", "weft_str", "phrase")
    keep <- pd$str | mark_ranges(n, rg$start[piece], rg$end[piece])
    chars <- strsplit(pr, "")[[1L]]
    chars[!keep & chars != "\n"] <- " "
    pr <- paste(chars, collapse = "")
  }
  src$cache$prose_pandoc <- pr
  pr
}

# ---- block-start (L18) ---------------------------------------------------------------

# What Pandoc's `markdown` reader cuts a paragraph at (checked with Pandoc as Quarto ships it,
# review 3, question 1): a setext underline (a line of `-` or `=` alone) and a definition line
# (`:` then spaces then text), and a closed backtick fence (a fence with no closer is no cut).
# `#`, `>`, list markers, `:::`, `~~~`, `$$` and table lines do not cut it.
BLOCK_MARKER <- "^( {0,3})(-+(?=[ \t]*$)|=+(?=[ \t]*$)|:(?=[ \t]+\\S)|`{3,})"

block_marker_kind <- function(m) {
  ifelse(grepl("^[-=]", m), "a setext underline",
  ifelse(m == ":", "a definition", "the start of a code block"))
}

block_start_r <- function(src) {
  r <- src$rows
  if (!nrow(r)) return(block_start_fence(src))
  parts <- list()
  # (a) a line inside a span that starts a block
  span <- r$kind %in% c("n", "if", "sign", "list", "cite", "text", "literal") & r$context == "prose" &
    !is.na(r$fblock) & src_substr(src, r$fstart, r$fstart) == "["
  i <- which(span)
  if (length(i)) {
    l1 <- src_line_of(src, r$fstart[i])
    l2 <- src_line_of(src, r$fblock[i] - 1)
    k <- which(l2 > l1)
    if (length(k)) {
      lines <- unlist(lapply(k, function(j) seq.int(l1[j] + 1L, l2[j])))
      lines <- sort(unique(lines))
      m <- regexpr(BLOCK_MARKER, src$lines[lines], perl = TRUE)
      ok <- m > 0L
      # a backtick fence cuts the paragraph only when it is closed
      fence <- ok & grepl("^ {0,3}`{3,}", src$lines[lines])
      if (any(fence)) {
        fb <- fence_blocks(src$lines, rep(FALSE, length(src$lines)))
        closed <- fb$open[fb$close > fb$open & grepl("^ {0,3}`{3,}[ \t\r]*$", src$lines[fb$close])]
        ok[fence & !(lines %in% closed)] <- FALSE
      }
      if (any(ok)) {
        cs <- attr(m, "capture.start")[ok, , drop = FALSE]
        cl <- attr(m, "capture.length")[ok, , drop = FALSE]
        ln <- lines[ok]
        mk <- substring(src$lines[ln], cs[, 2L], cs[, 2L] + cl[, 2L] - 1L)
        pos <- src$line_start[ln] + cs[, 2L] - 1L
        parts[[length(parts) + 1L]] <- finding_at(
          src, pos, pos + nchar(mk) - 1L, "block-start", mk,
          sprintf("Line %d inside a span starts with `%s`, which Pandoc reads as %s, so the span is cut in two (rule 2.10.5).",
                  ln, mk, block_marker_kind(mk)),
          hint = "Re-wrap the span so that no line starts with it, or escape it (for example `\\#`).")
      }
    }
  }
  # (b) a construct that starts a line indented four or more, after a blank line, outside a list
  c1 <- which(is.na(r$parent) & r$context == "prose")
  if (length(c1)) {
    ln <- src_line_of(src, r$fstart[c1])
    lead <- substring(src$lines[ln], 1L, r$fstart[c1] - src$line_start[ln])
    cand <- ln > 1L & grepl("^( {4,}|\t)[ \t]*$", lead)
    if (any(cand)) {
      lines <- src$lines
      blank <- !grepl("[^ \t]", lines)
      nl <- length(lines)
      idx <- seq_len(nl)
      prevblank <- c(TRUE, blank[-nl])
      col0 <- grepl("^[^ \t]", lines)
      marker <- grepl("^[ \t]*([-*+]|[0-9]{1,9}[.)])[ \t]+[^ \t]", lines)
      last_reset <- cummax(ifelse(col0 & prevblank, idx, 0L))
      last_set <- cummax(ifelse(marker, idx, 0L))
      inlist <- last_set > 0L & last_set >= last_reset
      cand <- cand & blank[pmax(ln - 1L, 1L)] & !inlist[ln]
      j <- c1[cand]
      if (length(j)) {
        txt <- src_substr(src, r$fstart[j], pmin(r$fend[j], r$fstart[j] + 79L))
        parts[[length(parts) + 1L]] <- finding_at(
          src, r$fstart[j], r$fend[j], "block-start", txt,
          sprintf("Line %d starts a construct indented four spaces or more after a blank line, which Pandoc reads as code, so it is not a construct (rule 2.10.5).",
                  src_line_of(src, r$fstart[j])),
          hint = "Remove the indentation.")
      }
    }
  }
  parts[[length(parts) + 1L]] <- block_start_fence(src)
  bind_findings(parts)
}

# A code fence that interrupts a paragraph holding an open `[` and whose block
# holds the `]{...}` that closes it. The scanner reads such a fence as code, so
# the construct is not a row; the finding is made from the lines.
block_start_fence <- function(src) {
  lines <- src$lines
  nl <- length(lines)
  if (!nl || !any(grepl("^ {0,3}`{3,}", lines))) return(new_findings())
  inmeta <- logical(nl)
  for (m in src$meta) inmeta[m$open:m$close] <- TRUE
  fb <- fence_blocks(lines, inmeta)
  fb <- fb[fb$open > 1L, , drop = FALSE]
  if (!nrow(fb)) return(new_findings())
  blank <- !grepl("[^ \t]", lines)
  out <- list()
  for (i in seq_len(nrow(fb))) {
    o <- fb$open[[i]]
    cl <- fb$close[[i]]
    # only a backtick fence that is closed cuts a paragraph
    if (blank[o - 1L] || !grepl("^ {0,3}`{3,}", lines[o]) || cl <= o ||
        !grepl("^ {0,3}`{3,}[ \t\r]*$", lines[cl])) next
    top <- o - 1L
    while (top > 1L && !blank[top - 1L]) top <- top - 1L
    para <- paste(lines[top:(o - 1L)], collapse = "\n")
    opens <- lengths(regmatches(para, gregexpr("(?<!\\\\)\\[", para, perl = TRUE)))
    closes <- lengths(regmatches(para, gregexpr("(?<!\\\\)\\]", para, perl = TRUE)))
    if (opens <= closes) next
    last <- cl
    while (last < nl && !blank[last + 1L]) last <- last + 1L
    inside <- paste(lines[o:last], collapse = "\n")
    ab <- regmatches(inside, gregexpr("\\]\\{[^{}\n]*\\}", inside, perl = TRUE))[[1L]]
    cls <- unlist(regmatches(ab, gregexpr("\\.[A-Za-z][A-Za-z0-9_-]*", ab, perl = TRUE)))
    weft_cls <- c(shipped_classes(), names(src$cfg$formatters %||% list()))
    if (!any(grepl("(?:n|if|sign|list|cite)[ \t]*=", ab, perl = TRUE)) && !any(cls %in% weft_cls)) next
    mk <- regmatches(lines[o], regexpr("`{3,}", lines[o]))
    pos <- src$line_start[o] + as.integer(regexpr("`{3,}", lines[o])) - 1L
    out[[length(out) + 1L]] <- finding_at(
      src, pos, pos + nchar(mk) - 1L, "block-start", mk,
      sprintf("Line %d inside a span starts with `%s`, which Pandoc reads as %s, so the span is cut in two (rule 2.10.5).",
              o, mk, block_marker_kind(mk)),
      hint = "Re-wrap the span so that no line starts with it, or escape it (for example `\\#`).")
  }
  bind_findings(out)
}

block_start_pandoc <- function(src, ctx) {
  mk <- pandoc_read(src, ctx, TRUE)
  if (is.null(mk)) return(new_findings())
  um <- pandoc_read(src, ctx, FALSE)
  if (is.null(um)) return(new_findings())
  a <- paste(mk$blocks$line, mk$blocks$type)
  b <- paste(um$blocks$line, um$blocks$type)
  only_m <- !(a %in% b)
  only_u <- !(b %in% a)
  d <- rbind(
    if (any(only_m)) data.frame(line = mk$blocks$line[only_m], type = mk$blocks$type[only_m],
                                side = "with the constructs masked", stringsAsFactors = FALSE),
    if (any(only_u)) data.frame(line = um$blocks$line[only_u], type = um$blocks$type[only_u],
                                side = "as written", stringsAsFactors = FALSE))
  if (is.null(d) || !nrow(d)) return(new_findings())
  d <- d[d$line >= 1L & d$line <= length(src$lines), , drop = FALSE]
  if (!nrow(d)) return(new_findings())
  pos <- src$line_start[d$line]
  finding_at(src, pos, pos, "block-start", d$type,
             sprintf("Line %d starts a %s %s that is not there the other way, so a construct is cut across blocks (rule 2.10.5).",
                     d$line, d$type, d$side),
             hint = "Re-wrap the construct so that no line of it starts a block, or escape the marker.")
}

lint_block_start <- function(src, ctx) {
  parts <- list(block_start_r(src))
  if (identical(ctx$reader, "pandoc")) parts[[2L]] <- block_start_pandoc(src, ctx)
  bind_findings(parts)
}
