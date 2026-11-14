# The prose lints (design-3 L19-L21, L36; package 3b): `numeral`, `claim-word`,
# `long-guard` and `label_seed()`. They read `src$prose` (or, with
# `reader = "pandoc"`, its intersection with Pandoc's text, see lint-pandoc.R).

# ---- helpers ------------------------------------------------------------------------

# characters that end a word: white space and the comparison signs (L12, K4)
WORD_RE <- "[^\\s|=<>\u2264\u2265\u2248\u2260\u00a0\u2007\u2009\u202f]+"

# the index of the block that holds each position (the innermost, so an inline
# note wins over the paragraph round it), or NA
src_block_of <- function(src, pos) {
  b <- src$blocks
  out <- rep(NA_integer_, length(pos))
  if (!nrow(b) || !length(pos)) return(out)
  i <- findInterval(pos, b$start)
  ok <- i > 0L & pos <= b$end[pmax(i, 1L)]
  out[ok] <- i[ok]
  miss <- which(!ok)
  if (length(miss)) {
    nf <- which(b$type != "footnote")
    if (length(nf)) {
      j <- findInterval(pos[miss], b$start[nf])
      okj <- j > 0L & pos[miss] <= b$end[nf][pmax(j, 1L)]
      out[miss[okj]] <- nf[j[okj]]
    }
  }
  out
}

# the finding `context` of a block index
block_context <- function(src, blk) {
  type <- ifelse(is.na(blk), NA_character_, src$blocks$type[pmax(blk, 1L)])
  ctx <- c("front-matter" = "front-matter", caption = "caption", weft_str = "weft_str", phrase = "phrase")
  out <- unname(ctx[type])
  out[is.na(out)] <- "prose"
  out
}

# every match of `pat` in `text` that does not run across a line: file offsets of its first and
# last character, and the matched strings. A non-ASCII pattern or text makes one gregexpr() over a
# whole document quadratic (each match is found again from the start), so match line by line.
line_matches <- function(pat, text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  m <- gregexpr(pat, lines, perl = TRUE)
  st <- unlist(m)
  if (is.null(st) || all(st == -1L)) return(list(s = integer(), e = integer(), w = character()))
  len <- unlist(lapply(m, attr, "match.length"))
  off <- cumsum(c(0L, nchar(lines) + 1L))[seq_along(lines)]
  ok <- st > 0L
  s <- as.integer(st + rep.int(off, lengths(m)))[ok]
  list(s = s, e = s + len[ok] - 1L, w = unlist(regmatches(lines, m)))
}

# the words of a prose string: file offsets of each word's first and last character
prose_words <- function(prose) line_matches(WORD_RE, prose)

# where numerals are exempt: inside a cite span, a .weft-literal span or div
numeral_exempt_mask <- function(src) {
  rg <- src$regions
  k <- rg$type %in% c("cite_span", "literal") |
    (rg$type == "div" & !is.na(rg$name) & grepl(".weft-literal", rg$name, fixed = TRUE))
  mark_ranges(nchar(src$text), rg$start[k], rg$end[k])
}

XREF_WORDS <- c(figure = "@fig-", figures = "@fig-", fig = "@fig-", figs = "@fig-",
                table = "@tbl-", tables = "@tbl-", section = "@sec-", sections = "@sec-",
                chapter = "", chapters = "", equation = "@eq-", equations = "@eq-",
                eq = "@eq-", eqs = "@eq-", appendix = "", appendices = "")

strip_punct <- function(x) gsub("^\\p{P}+|\\p{P}+$", "", x, perl = TRUE)

# Every word of `prose` that starts with a digit (L19): the data frame has the
# word's index in `words`, the numeral's offsets and text, and whether the cite
# or literal mask or the years setting exempts it.
numeral_scan <- function(src, prose, cfg) {
  W <- prose_words(prose)
  nw <- length(W$w)
  empty <- list(words = W, num = data.frame(k = integer(), start = integer(), end = integer(),
                                           text = character(), exempt = logical(),
                                           stringsAsFactors = FALSE))
  if (!nw) return(empty)
  fp <- as.integer(regexpr("[\\p{L}\\p{Nd}]", W$w, perl = TRUE))
  first <- substring(W$w, fp, fp)
  k <- which(fp > 0L & grepl("^\\p{Nd}$", first, perl = TRUE))
  if (!length(k)) return(empty)
  w <- W$w[k]
  f <- fp[k]
  before <- substring(w, f - 1L, f - 1L)
  f0 <- ifelse(f > 1L & before %in% c("-", "\u2212", "+", "\u00b1"), f - 1L, f)
  lastm <- as.integer(regexpr("[\\p{L}\\p{Nd}%\u2030\u00b0][^\\p{L}\\p{Nd}%\u2030\u00b0]*$", w, perl = TRUE))
  txt <- substring(w, f0, lastm)
  st <- W$s[k] + f0 - 1L
  en <- W$s[k] + lastm - 1L
  ex <- numeral_exempt_mask(src)[st]
  if (isTRUE(cfg$numeral_years)) ex <- ex | grepl("^[12][0-9]{3}(?:[-\u2013](?:[0-9]{2}|[12][0-9]{3}))?(?:s|[\u0027\u2019]s)?$", txt, perl = TRUE)
  list(words = W, num = data.frame(k = k, start = st, end = en, text = txt, exempt = ex,
                                   stringsAsFactors = FALSE))
}

# ---- numeral (L19) ---------------------------------------------------------------------

numeral_prose <- function(src, prose, cfg) {
  sc <- numeral_scan(src, prose, cfg)
  nm <- sc$num
  if (!nrow(nm)) return(new_findings())
  W <- sc$words
  nm <- nm[!nm$exempt, , drop = FALSE]
  if (!nrow(nm)) return(new_findings())
  # the previous word, when it is in the same block
  hasprev <- nm$k > 1L
  pk <- pmax(nm$k - 1L, 1L)
  b_this <- src_block_of(src, nm$start)
  b_prev <- src_block_of(src, W$s[pk])
  same <- hasprev & !is.na(b_this) & !is.na(b_prev) & b_this == b_prev
  prev <- ifelse(same, strip_punct(W$w[pk]), NA_character_)
  labels <- as.character(unlist(cfg$label_words))
  islabel <- !is.na(prev) & prev %in% labels
  keep <- !islabel
  nm <- nm[keep, , drop = FALSE]
  prev <- prev[keep]
  b_this <- b_this[keep]
  if (!nrow(nm)) return(new_findings())
  low <- tolower(prev)
  isx <- !is.na(low) & low %in% names(XREF_WORDS)
  pref <- ifelse(isx, unname(XREF_WORDS[low]), NA_character_)
  msg <- ifelse(
    isx,
    sprintf("\"%s\" after \"%s\" is a typed cross-reference number; use %s (rule 5.2.4).", nm$text, prev,
            ifelse(nzchar(pref) & !is.na(pref), paste0(pref, "<label>"), "a cross-reference")),
    sprintf("\"%s\" is a number typed in prose (rule 5.2.1).", nm$text))
  hint <- ifelse(
    isx,
    ifelse(nzchar(pref) & !is.na(pref),
           sprintf("Write %s<label> and give the target that label.", pref),
           "Write a cross-reference to the target and give it a label."),
    sprintf("Write it as a value, put it in the dictionary, or mark it [%s]{.weft-literal why=\"...\"}.", nm$text))
  finding_at(src, nm$start, nm$end, "numeral", nm$text, msg, hint = hint,
             context = block_context(src, b_this), spec = ifelse(isx, "5.2.4", "5.2.1"))
}

numeral_math <- function(src) {
  rg <- src$regions
  mi <- which(rg$type == "math")
  if (!length(mi)) return(new_findings())
  ex <- numeral_exempt_mask(src)
  mi <- mi[!ex[rg$start[mi]]]
  if (!length(mi)) return(new_findings())
  pos <- list()
  txt <- list()
  for (i in mi) {
    s <- rg$start[i]
    t <- src_substr(src, s, rg$end[i])
    # inline R and code spans are masked
    m <- gregexpr("(`+)[^`]*\\1", t, perl = TRUE)
    regmatches(t, m) <- lapply(regmatches(t, m), function(x) strrep(" ", nchar(x)))
    # exponents and subscripts, with their brace groups
    for (pat in c("[\\^_]\\{(?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*\\}",
                  "(?<=[\\^_])[0-9]+(?:\\.[0-9]+)?")) {
      m <- gregexpr(pat, t, perl = TRUE)
      regmatches(t, m) <- lapply(regmatches(t, m), function(x) strrep(" ", nchar(x)))
    }
    g <- gregexpr("[0-9]+(?:\\.[0-9]+)?", t, perl = TRUE)[[1L]]
    if (g[[1L]] == -1L) next
    ml <- attr(g, "match.length")
    pos[[length(pos) + 1L]] <- data.frame(start = s + as.integer(g) - 1L, len = ml)
    txt[[length(txt) + 1L]] <- substring(t, g, g + ml - 1L)
  }
  if (!length(pos)) return(new_findings())
  p <- do.call(rbind, pos)
  tx <- unlist(txt)
  blk <- src_block_of(src, p$start)
  finding_at(src, p$start, p$start + p$len - 1L, "numeral", tx,
             sprintf("\"%s\" is a number typed in math (rule 5.2.6).", tx),
             hint = "Write it as a value, put it in the dictionary, or wrap the formula in a [...]{.weft-literal why=\"...\"} span.",
             context = block_context(src, blk), spec = "5.2.6")
}

lint_numeral <- function(src, ctx) {
  prose <- lint_prose_view(src, ctx)
  bind_findings(list(numeral_prose(src, prose, src$cfg), numeral_math(src)))
}

# ---- claim-word (L20) ------------------------------------------------------------------

# sentences over the prose view, cached on the source
lint_sentences <- function(src, ctx, prose) {
  key <- if (identical(ctx$reader, "pandoc")) "sentences_pandoc" else "sentences"
  hit <- src$cache[[key]]
  if (!is.null(hit)) return(hit)
  s2 <- src
  s2$prose <- prose
  res <- source_sentences(s2)
  src$cache[[key]] <- res
  res
}

# the sentence of the table that holds each position, the innermost when sentences nest (a sentence
# in an inline note sits inside the sentence of its paragraph); NA when none holds it
innermost_sentence <- function(ps, sent) {
  vapply(ps, function(p) {
    h <- which(sent$start <= p & sent$end >= p)
    if (!length(h)) return(NA_integer_)
    h <- h[sent$start[h] == max(sent$start[h])]
    h[which.min(sent$end[h])]
  }, 1L)
}

# Which of the positions `ps` (word starts) lie inside a match of `pattern` in `text`.
inside_matches <- function(text, pattern, ps) {
  g <- gregexpr(pattern, text, perl = TRUE)[[1L]]
  if (g[[1L]] == -1L) return(rep(FALSE, length(ps)))
  e <- as.integer(g) + attr(g, "match.length") - 1L
  k <- findInterval(ps, as.integer(g))
  k > 0L & ps <= e[pmax(k, 1L)]
}

# the regex that finds any of the idioms: any run of white space is one space, the phrase starts and
# ends at a word boundary, case is ignored (rule 5.5.1)
idiom_regex <- function(idioms) {
  if (!length(idioms)) return(NULL)
  idioms <- idioms[order(-nchar(idioms))]
  esc <- vapply(strsplit(idioms, "[[:space:]]+"), function(w) {
    paste(gsub("([][\\\\^$.|?*+(){}-])", "\\\\\\1", w), collapse = "[[:space:]]+")
  }, "")
  paste0("(?i)(?<![\\p{L}\\p{N}])(?:", paste(esc, collapse = "|"), ")(?![\\p{L}\\p{N}])")
}

lint_claim_word <- function(src, ctx) {
  lex <- claim_lexicon(src$cfg, src$lang)
  mode <- src$cfg$claim_quantifiers %||% "number"
  qwords <- claim_quantifier_words(src$cfg, src$lang)
  if (identical(mode, "none")) lex <- setdiff(lex, qwords)
  if (!length(lex) || !nzchar(src$prose)) return(new_findings())
  prose <- lint_prose_view(src, ctx)
  sent <- lint_sentences(src, ctx, prose)
  if (!nrow(sent)) return(new_findings())
  lw <- line_matches("\\p{L}+", prose)
  if (!length(lw$s)) return(new_findings())
  ps <- lw$s
  orig <- lw$w
  run <- tolower(orig)
  hit <- run %in% lex
  if (!any(hit)) return(new_findings())
  ps <- ps[hit]
  orig <- orig[hit]
  run <- run[hit]
  keep <- function(ok) {
    ps <<- ps[ok]
    orig <<- orig[ok]
    run <<- run[ok]
  }
  r <- src$rows
  if (nrow(r)) {
    g <- r$kind %in% c("if", "sign")
    guarded <- mark_ranges(nchar(src$text), r$fstart[g], r$fend[g])
    keep(!guarded[ps])
  }
  if (!length(ps)) return(new_findings())
  sid <- innermost_sentence(ps, sent)
  keep(!is.na(sid))
  sid <- sid[!is.na(sid)]
  btype <- src$blocks$type[sent$block[sid]]
  ok <- !(btype %in% "phrase")
  keep(ok)
  sid <- sid[ok]
  if (!length(ps)) return(new_findings())
  # CW2: a word inside an idiom is no hit
  rx <- idiom_regex(claim_idioms(src$cfg, src$lang))
  if (!is.null(rx)) {
    ok <- !inside_matches(prose, rx, ps)
    keep(ok)
    sid <- sid[ok]
  }
  # CW4: a hyphen directly before or after the word; U+2010 and U+2011 are hyphens too
  if (length(ps)) {
    hy <- "[-\u2010\u2011]"
    before <- grepl(hy, substring(prose, ps - 1L, ps - 1L)) & ps > 1L
    after <- grepl(hy, substring(prose, ps + nchar(run), ps + nchar(run)))
    ok <- !(before | after)
    keep(ok)
    sid <- sid[ok]
  }
  # CW5: a capital that is not the first word of its sentence is a proper name
  if (length(ps)) {
    cap <- grepl("^\\p{Lu}", orig, perl = TRUE)
    firstrun <- lw$s[pmin(findInterval(sent$start[sid] - 1L, lw$s) + 1L, length(lw$s))]
    ok <- !(cap & ps != firstrun)
    keep(ok)
    sid <- sid[ok]
  }
  # CW6: a quantifier counts only in a sentence with a value or a typed digit (`number`); a word
  # the project added counts in any sentence
  vs <- sort(r$fstart[r$kind %in% c("value", "bare", "named", "n", "sign", "list")])
  in_sent <- function(pos, i) (findInterval(sent$end[i], pos) - findInterval(sent$start[i] - 1L, pos)) > 0L
  if (length(ps) && identical(mode, "number")) {
    dg <- gregexpr("[0-9]", prose)[[1L]]
    dg <- if (dg[[1L]] == -1L) integer() else as.integer(dg)
    ok <- !(run %in% qwords) | in_sent(vs, sid) | in_sent(dg, sid)
    keep(ok)
    sid <- sid[ok]
  }
  if (!length(ps)) return(new_findings())
  groups <- split(seq_along(ps), sid)
  first <- vapply(groups, function(ix) ps[ix[[1L]]], 1L)
  words <- lapply(groups, function(ix) unique(run[ix]))
  si <- as.integer(names(groups))
  hasval <- in_sent(vs, si)
  quoted <- vapply(words, function(w) paste0("\"", w, "\"", collapse = ", "), "")
  plural <- lengths(words) > 1L
  msg <- sprintf("Claim word%s %s in a sentence with %s (rule 5.5.1).", ifelse(plural, "s", ""), quoted,
                 ifelse(hasval,
                        "a value; check that the value still bears it out, or guard the word with an `if` span",
                        "no value: if it states a result, compute it"))
  # the design's punctuation: "; check" and ": if" sit inside the one sentence; a blockquote's
  # markers are not part of it (CW9)
  sentence <- src_substr(src, sent$start[si], sent$end[si])
  sentence <- gsub("(?m)^[ \t]*(?:>[ ]?)+", "", sentence, perl = TRUE)
  sentence <- gsub("[[:space:]]+", " ", trimws(sentence))
  f <- finding_at(src, first, sent$end[si], "claim-word", vapply(words, paste, "", collapse = ", "), msg,
                  context = block_context(src, sent$block[si]), sentence = sentence)
  f$end_line <- as.integer(sent$end_line[si])
  f
}

# ---- long-guard (L21) -------------------------------------------------------------------

lint_long_guard <- function(src, ctx) {
  r <- src$rows
  limit <- src$cfg$guard_words
  if (!nrow(r) || is.null(limit)) return(new_findings())
  i <- which(r$kind == "if" & !is.na(r$fblock) & r$fblock - 2L >= r$fstart + 1L)
  if (!length(i)) return(new_findings())
  prose <- lint_prose_view(src, ctx)
  nv <- which(r$kind %in% c("value", "bare", "named"))
  vs <- r$fstart[nv]
  count <- function(x) {
    lengths(regmatches(x, gregexpr("[^[:space:]]*[\\p{L}\\p{Nd}][^[:space:]]*", x, perl = TRUE)))
  }
  longest <- vapply(i, function(j) {
    s <- r$fstart[j] + 1L
    e <- r$fblock[j] - 2L
    sp <- r$sep_pos[[j]]
    sp <- sp[!is.na(sp) & sp >= s & sp <= e]
    if (!length(sp) && r$context[j] != "prose") {
      pp <- gregexpr("|", substr(prose, s, e), fixed = TRUE)[[1L]]
      sp <- if (pp[[1L]] > 0L) s + as.integer(pp) - 1L else integer()
    }
    a <- c(s, sp + 1L)
    b <- c(sp - 1L, e)
    ok <- b >= a
    a <- a[ok]
    b <- b[ok]
    if (!length(a)) return(0L)
    w <- count(substring(prose, a, b))
    nested <- vapply(seq_along(a), function(q) sum(vs >= a[q] & vs <= b[q]), 1L)
    max(w + nested)
  }, 1L)
  big <- longest > limit
  if (!any(big)) return(new_findings())
  j <- i[big]
  ctxs <- ifelse(r$context[j] %in% c("prose", "caption", "weft_str", "phrase"), r$context[j],
                 ifelse(grepl("^front", r$context[j]), "front-matter", "prose"))
  finding_at(src, r$fstart[j], r$fend[j], "long-guard", ifelse(is.na(r$expr[j]), "", r$expr[j]),
             sprintf(paste0("A guarded bracket of %d words: one condition guards all of it; guard only the ",
                            "words it decides, and nest what is computed (rule 3.1.9)."), longest[big]),
             hint = "Guard only the words the condition decides, and nest what is computed.",
             context = ctxs)
}

# ---- label_seed() (L36) -----------------------------------------------------------------

LABEL_STOP <- c("In", "On", "At", "By", "For", "From", "To", "Of", "The", "An", "And", "Or", "But",
                "With", "Since", "Until", "After", "Before", "About", "Around", "Over", "Under",
                "Between", "During", "Than", "Only", "All", "Some", "Each", "Every", "Nearly",
                "Approximately")

#' Propose label words from the prose
#'
#' Reads the project's `.qmd` and `.Rmd` documents and counts each capitalised
#' word that is followed, in the same block, by a typed number ("Site 3",
#' "Stage 2"). Such words are candidates for the `label_words` setting, which
#' exempts the number after them from the `numeral` lint. Cross-reference words
#' (`Figure`, `Table`, ...), common function words and words already in
#' `label_words` are left out. Nothing is written.
#'
#' @param paths `NULL` (every document of the project the working folder is in,
#'   by the rules of [dict_seed()]), or document paths.
#' @param min_count The fewest times a word must occur to be listed.
#' @return A data frame with `word`, `n` (how many times), `files` (in how many
#'   files) and `where` (up to three places as `<file>:<line>: <word> <numeral>`),
#'   sorted by `n` and then `word`.
#' @export
label_seed <- function(paths = NULL, min_count = 2) {
  if (!is.numeric(min_count) || length(min_count) != 1L || !is.finite(min_count) ||
      min_count < 1 || min_count != round(min_count)) {
    tool_abort("label_seed(): `min_count` must be a whole number from 1.")
  }
  cols <- function() data.frame(word = character(), n = integer(), files = integer(),
                                where = character(), stringsAsFactors = FALSE)
  root <- normalizePath(find_project_root(getwd()), winslash = "/", mustWork = FALSE)
  if (is.null(paths)) {
    items <- lapply(lint_files_under(root), function(f) list(root = root, rel = f))
  } else {
    if (!is.character(paths) || anyNA(paths)) tool_abort("label_seed(): `paths` must be file names.")
    gone <- paths[!file.exists(paths)]
    if (length(gone)) {
      tool_abort(sprintf("label_seed(): no such file: %s.", paste(gone, collapse = ", ")))
    }
    dirs <- paths[dir.exists(paths)]
    if (length(dirs)) {
      tool_abort(sprintf("label_seed(): %s is a folder; give files, or `paths = NULL` for the project.",
                         paste0("`", dirs, "`", collapse = ", ")))
    }
    odd <- paths[!grepl("\\.(qmd|Rmd|rmd)$", paths)]
    if (length(odd)) {
      tool_abort(sprintf("label_seed(): %s is not a .qmd or .Rmd file.", odd[[1L]]))
    }
    full <- normalizePath(paths, winslash = "/", mustWork = TRUE)
    # each document is read with the settings of its own project, not the working folder's
    roots <- vapply(full, function(p) normalizePath(find_project_root(p), winslash = "/", mustWork = FALSE), "",
                    USE.NAMES = FALSE)
    rels <- mapply(lint_rel_path, full, roots, USE.NAMES = FALSE)
    o <- order(rels, roots, method = "radix")
    keep <- !duplicated(paste(roots, rels, sep = "\n")[o])
    items <- Map(function(r, f) list(root = r, rel = f), roots[o][keep], rels[o][keep])
  }
  hits <- list()
  for (it in items) {
    src <- lint_open(it$root, it$rel)
    if (isTRUE(src$invalid)) next
    h <- label_hits(src)
    if (nrow(h)) hits[[length(hits) + 1L]] <- h
  }
  if (!length(hits)) return(cols())
  h <- do.call(rbind, hits)
  n <- table(h$word)
  words <- names(n)
  out <- data.frame(word = words, n = as.integer(n), stringsAsFactors = FALSE)
  out$files <- vapply(words, function(w) length(unique(h$file[h$word == w])), 1L, USE.NAMES = FALSE)
  out$where <- vapply(words, function(w) {
    x <- h[h$word == w, , drop = FALSE]
    x <- utils::head(x, 3L)
    paste0(x$file, ":", x$line, ": ", x$word, " ", x$numeral, collapse = "; ")
  }, "", USE.NAMES = FALSE)
  out <- out[out$n >= min_count, , drop = FALSE]
  out <- out[order(-out$n, out$word, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  if (!nrow(out)) return(cols())
  out
}

# the capitalised words of one source that are followed by a numeral in their block
label_hits <- function(src) {
  none <- data.frame(word = character(), file = character(), line = integer(), numeral = character(),
                     stringsAsFactors = FALSE)
  sc <- numeral_scan(src, src$prose, src$cfg)
  nm <- sc$num
  if (!nrow(nm)) return(none)
  W <- sc$words
  nm <- nm[!nm$exempt & nm$k > 1L, , drop = FALSE]
  if (!nrow(nm)) return(none)
  pk <- nm$k - 1L
  w <- W$w[pk]
  x <- gsub("^[^\\p{L}\\p{Nd}]+", "", w, perl = TRUE)
  x <- sub("[^\\p{L}\\p{Nd}.]+$", "", x, perl = TRUE)
  x <- sub("\\.$", "", x)
  labels <- as.character(unlist(src$cfg$label_words))
  ok <- grepl("^\\p{Lu}\\p{L}+$", x, perl = TRUE) & !(x %in% LABEL_STOP) & !(x %in% labels) &
    !(tolower(x) %in% names(XREF_WORDS))
  b1 <- src_block_of(src, nm$start)
  b0 <- src_block_of(src, W$s[pk])
  ok <- ok & !is.na(b1) & !is.na(b0) & b1 == b0
  if (!any(ok)) return(none)
  data.frame(word = x[ok], file = src$file, line = src_line_of(src, nm$start[ok]),
             numeral = nm$text[ok], stringsAsFactors = FALSE)
}
