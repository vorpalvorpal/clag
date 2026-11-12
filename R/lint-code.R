# The code and construct lints (design-3 L22-L28, L34; package 3c): literal-value,
# inert-check, value-constant, value-format, lone-bar, if-zero, name, tar-name,
# dict-assign, dict-key, tar-cache and above-setup. Every rule reads a document's
# code as text (parse() and getParseData() only); nothing is run.

# ---- attribute blocks -----------------------------------------------------------------

LC_WS <- c(" ", "\t", "\r", "\n")

# The names in an attribute block `blk` (a string that starts with `{`) whose first
# character is at file offset `base`: classes (with the dot), ids and keys, each with
# its file offset and, for a key, the offset and text of its value.
attr_tokens <- function(blk, base) {
  ch <- strsplit(blk, "")[[1L]]
  n <- length(ch)
  nm <- character(); ty <- character(); ps <- numeric(); vs <- numeric(); vl <- character()
  put <- function(a, b, c, d, e) {
    nm <<- c(nm, a); ty <<- c(ty, b); ps <<- c(ps, c); vs <<- c(vs, d); vl <<- c(vl, e)
  }
  stops <- c(LC_WS, "}")
  i <- 2L
  while (i <= n) {
    c <- ch[i]
    if (c %in% LC_WS) { i <- i + 1L; next }
    if (c == "}") break
    if (c == "." || c == "#") {
      e <- i
      while (e < n && !(ch[e + 1L] %in% stops)) e <- e + 1L
      put(paste(ch[i:e], collapse = ""), if (c == ".") "class" else "id", base + i - 1, NA_real_, NA_character_)
      i <- e + 1L
      next
    }
    ke <- i
    while (ke <= n && !(ch[ke] %in% c(stops, "=", "\"", "'", "{"))) ke <- ke + 1L
    if (ke > n || ch[ke] != "=" || ke == i) {
      i <- max(ke, i + 1L)
      next
    }
    key <- paste(ch[i:(ke - 1L)], collapse = "")
    vp <- ke + 1L
    q <- if (vp <= n) ch[vp] else ""
    if (q %in% c("\"", "'")) {
      idx <- if (vp + 1L <= n) which(ch[(vp + 1L):n] == q) else integer()
      cl <- if (length(idx)) vp + idx[1L] else n + 1L
      val <- if (cl > vp + 1L) paste(ch[(vp + 1L):(min(cl, n + 1L) - 1L)], collapse = "") else ""
      put(key, "key", base + i - 1, base + vp, val)
      i <- cl + 1L
    } else {
      e <- vp
      while (e <= n && !(ch[e] %in% stops)) e <- e + 1L
      val <- if (e > vp) paste(ch[vp:(e - 1L)], collapse = "") else ""
      put(key, "key", base + i - 1, base + vp - 1, val)
      i <- e
    }
  }
  data.frame(name = nm, type = ty, pos = ps, vstart = vs, value = vl, stringsAsFactors = FALSE)
}

# ---- parse data as a tree --------------------------------------------------------------

pd_tree <- function(text) {
  ex <- tryCatch(suppressWarnings(parse(text = text, keep.source = TRUE)), error = function(e) NULL)
  if (is.null(ex) || !length(ex)) return(NULL)
  pd <- utils::getParseData(ex, includeText = NA)
  if (is.null(pd) || !nrow(pd)) return(NULL)
  pd <- pd[pd$token != "COMMENT", , drop = FALSE]
  if (!nrow(pd)) return(NULL)
  # a top-level `=` assignment is wrapped in its own kind of node
  pd$token[pd$token %in% c("expr_or_assign_or_help", "equal_assign")] <- "expr"
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (!length(lines)) lines <- ""
  # parse-data columns count characters, as the findings do
  pd <- pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), , drop = FALSE]
  rownames(pd) <- NULL
  n <- nrow(pd)
  ix <- match(pd$parent, pd$id)
  kids <- split(seq_len(n), factor(ix, levels = seq_len(n)))
  list(pd = pd, kids = kids, par = ix, roots = which(is.na(ix) & pd$token == "expr"), lines = lines, n = n)
}

node_text <- function(t, i) {
  d <- t$pd
  l1 <- d$line1[i]; c1 <- d$col1[i]; l2 <- d$line2[i]; c2 <- d$col2[i]
  if (l1 == l2) return(substr(t$lines[l1], c1, c2))
  mid <- if (l2 - l1 > 1L) t$lines[(l1 + 1L):(l2 - 1L)] else character()
  paste(c(substring(t$lines[l1], c1), mid, substr(t$lines[l2], 1L, c2)), collapse = "\n")
}

# i and every node below it, in source order
subtree <- function(t, i) {
  out <- integer()
  todo <- i
  while (length(todo)) {
    j <- todo[1L]
    todo <- todo[-1L]
    out <- c(out, j)
    todo <- c(t$kids[[j]], todo)
  }
  out
}

all_exprs <- function(t) {
  unlist(lapply(t$roots, function(r) subtree(t, r)), use.names = FALSE)
}

# The left side of the pipe (`|>` or `%>%`) that node i is the right side of, or NA.
pipe_lhs <- function(t, i) {
  p <- t$par[i]
  if (is.na(p)) return(NA_integer_)
  pk <- t$kids[[p]]
  m <- match(i, pk)
  if (is.na(m) || m < 3L || length(pk) != 3L) return(NA_integer_)
  tk <- t$pd$token[pk[2L]]
  if (tk == "PIPE" || (tk == "SPECIAL" && identical(t$pd$text[pk[2L]], "%>%"))) pk[1L] else NA_integer_
}

# A call node: its function's name and package, the node of the name and the arguments
# (node and name). NULL when i is not a call. The right side of a pipe is read as the call it
# makes: the piped value is its first argument.
call_info <- function(t, i) {
  tk <- t$pd$token
  if (tk[i] != "expr") return(NULL)
  k <- t$kids[[i]]
  if (length(k) < 3L || tk[k[1L]] != "expr" || tk[k[2L]] != "'('") return(NULL)
  fk <- t$kids[[k[1L]]]
  fn <- NA_character_
  pkg <- NA_character_
  fpos <- NA_integer_
  if (length(fk) == 1L && tk[fk] == "SYMBOL_FUNCTION_CALL") {
    fn <- t$pd$text[fk]
    fpos <- fk
  } else if (length(fk) == 3L && tk[fk[1L]] == "SYMBOL_PACKAGE" && tk[fk[3L]] == "SYMBOL_FUNCTION_CALL") {
    pkg <- t$pd$text[fk[1L]]
    fn <- t$pd$text[fk[3L]]
    fpos <- fk[3L]
  }
  args <- list()
  lhs <- pipe_lhs(t, i)
  if (!is.na(lhs)) args[[1L]] <- list(node = lhs, name = NA_character_, piped = TRUE)
  nm <- NA_character_
  rest <- k[-(1:2)]
  for (j in seq_along(rest)) {
    r <- rest[j]
    if (tk[r] == "SYMBOL_SUB") {
      nm <- t$pd$text[r]
    } else if (tk[r] == "STR_CONST" && j < length(rest) && tk[rest[j + 1L]] == "EQ_SUB") {
      nm <- gsub("^[\"']|[\"']$", "", node_text(t, r))
    } else if (tk[r] == "expr") {
      args[[length(args) + 1L]] <- list(node = r, name = nm)
      nm <- NA_character_
    } else if (tk[r] == "','") {
      nm <- NA_character_
    }
  }
  list(fn = fn, pkg = pkg, fpos = fpos, args = args)
}

is_fn <- function(ci, fns, pkgs = NULL) {
  !is.null(ci) && !is.na(ci$fn) && ci$fn %in% fns && (is.na(ci$pkg) || ci$pkg %in% pkgs)
}

# the value of a string constant (a node holding one, or the token itself), NA otherwise
str_value <- function(t, i) {
  tk <- t$pd$token
  k <- t$kids[[i]]
  if (tk[i] == "expr" && length(k) == 1L) i <- k
  if (tk[i] != "STR_CONST") return(NA_character_)
  v <- tryCatch(eval(parse(text = node_text(t, i), keep.source = FALSE)[[1L]]), error = function(e) NA_character_)
  if (is.character(v) && length(v) == 1L) v else NA_character_
}

# a numeric constant node: its value (NA when it is not one)
num_value <- function(t, i) {
  k <- t$kids[[i]]
  if (t$pd$token[i] != "expr" || length(k) != 1L || t$pd$token[k] != "NUM_CONST") return(NA_real_)
  v <- tryCatch(eval(parse(text = t$pd$text[k], keep.source = FALSE)[[1L]]), error = function(e) NA)
  if (is.numeric(v) && length(v) == 1L && is.finite(v)) as.numeric(v) else NA_real_
}

LIT_OPS <- c("'+'", "'-'", "'*'", "'/'", "'^'", "EQ", "NE", "LT", "GT", "LE", "GE", "AND", "OR",
             "AND2", "OR2", "':'")

lit_node <- function(t, i) {
  tk <- t$pd$token
  if (tk[i] != "expr") return(FALSE)
  k <- t$kids[[i]]
  if (length(k) == 1L) {
    if (tk[k] %in% c("STR_CONST", "NULL_CONST")) return(TRUE)
    if (tk[k] == "NUM_CONST") return(!(t$pd$text[k] %in% c("Inf", "NaN")))
    return(FALSE)
  }
  if (length(k) == 2L && tk[k[1L]] %in% c("'-'", "'+'", "'!'")) return(lit_node(t, k[2L]))
  if (length(k) == 3L) {
    if (tk[k[1L]] == "'('" && tk[k[3L]] == "')'") return(lit_node(t, k[2L]))
    op <- tk[k[2L]]
    if (op %in% LIT_OPS || (op == "SPECIAL" && t$pd$text[k[2L]] %in% c("%%", "%/%"))) {
      return(lit_node(t, k[1L]) && lit_node(t, k[3L]))
    }
  }
  FALSE
}

tree_literal <- function(t) length(t$roots) == 1L && lit_node(t, t$roots[1L])

has_var <- function(t, i) any(t$pd$token[subtree(t, i)] == "SYMBOL")

# ---- the pieces of code of a document --------------------------------------------------

# The lines of a document that are indented code (L11), where the scanner still finds
# constructs but nothing is run or read as prose.
indented_code_lines <- function(src) {
  if (!is.null(src$cache$icode)) return(src$cache$icode)
  wl <- src$lines
  nl <- length(wl)
  icode <- logical(nl)
  inmeta <- logical(nl)
  for (m in src$meta) inmeta[m$open:m$close] <- TRUE
  fb <- fence_blocks(wl, inmeta)
  nonbody <- inmeta
  for (b in seq_len(nrow(fb))) nonbody[fb$open[b]:fb$close[b]] <- TRUE
  blk <- !grepl("[^ \t]", wl) | nonbody
  indent4 <- grepl("^( {4,}|\t)", wl) & !blk
  if (any(indent4)) {
    marker <- grepl("^[ \t]*([-*+]|[0-9]{1,9}[.)])[ \t]+[^ \t]", wl) & !nonbody
    col0 <- grepl("^[^ \t]", wl) & !nonbody
    inlist <- FALSE
    prevblank <- TRUE
    for (i in seq_len(nl)) {
      if (blk[i]) { prevblank <- TRUE; next }
      if (col0[i] && prevblank) inlist <- FALSE
      if (marker[i]) inlist <- TRUE
      if (indent4[i] && prevblank && !inlist) icode[i] <- TRUE
      else if (indent4[i] && !prevblank && i > 1L && icode[i - 1L]) icode[i] <- TRUE
      prevblank <- FALSE
    }
  }
  src$cache$icode <- icode
  icode
}

# the rows that are not inside indented code
live_rows <- function(src) {
  r <- src$rows
  if (!nrow(r)) return(logical())
  ic <- indented_code_lines(src)
  ln <- src_line_of(src, r$fstart)
  !(!is.na(ln) & ln >= 1L & ic[pmax(ln, 1L)])
}

# Every piece of R code in a document: the expression of each inline construct and the
# code of each executed R chunk, parsed. `off` is the file offset of the piece's first
# character, `line_off` the file offset of the start of each of its lines.
code_pieces <- function(src) {
  if (!is.null(src$cache$code_pieces)) return(src$cache$code_pieces)
  out <- list()
  rows <- src$rows
  txt <- src$text
  mk <- function(kind, context, text, off, chunk = NA_integer_) {
    nl <- length(strsplit(text, "\n", fixed = TRUE)[[1L]])
    l0 <- findInterval(off, src$line_start)
    lo <- c(off, if (nl > 1L) src$line_start[l0 + seq_len(nl - 1L)])
    list(kind = kind, context = context, text = text, off = off, line_off = lo, chunk = chunk,
         tree = pd_tree(text))
  }
  live <- live_rows(src)
  for (i in seq_len(nrow(rows))) {
    kind <- rows$kind[i]
    s <- rows$fstart[i]
    e <- rows$fend[i]
    if (is.na(s) || is.na(e) || !live[i]) next
    if (kind %in% c("value", "bare")) {
      ctext <- substr(txt, s, e)
      pre <- regexpr("^`+(\\{r\\}|r)[ \t\r\n]*", ctext, perl = TRUE)
      ex <- rows$expr[i]
      if (pre < 0L || is.na(ex) || !nzchar(ex)) next
      off <- s + attr(pre, "match.length")
      if (!identical(substr(txt, off, off + nchar(ex) - 1), ex)) next
      out[[length(out) + 1L]] <- mk(kind, rows$context[i], ex, off)
    } else if (kind %in% c("n", "sign", "list", "if")) {
      fb <- rows$fblock[i]
      if (is.na(fb)) next
      tk <- attr_tokens(substr(txt, fb, e), fb)
      j <- which(tk$type == "key" & tolower(tk$name) == kind)
      if (!length(j)) next
      j <- j[1L]
      val <- tk$value[j]
      lead <- nchar(val) - nchar(sub("^[ \t\r\n]*", "", val, perl = TRUE))
      val <- trim_ws(val)
      if (!nzchar(val)) next
      out[[length(out) + 1L]] <- mk(kind, rows$context[i], val, tk$vstart[j] + lead)
    }
  }
  ch <- src$chunks
  for (c in seq_len(nrow(ch))) {
    if (!identical(tolower(ch$engine[c]), "r") || isFALSE(ch$eval[c])) next
    code <- ch$code[[c]]
    cl <- ch$code_line[c]
    if (!length(code) || is.na(cl)) next
    ln <- cl + seq_along(code) - 1L
    if (max(ln) > length(src$lines) || !identical(src$lines[ln], code)) next
    p <- mk("chunk", "chunk", paste(code, collapse = "\n"), src$line_start[cl], chunk = c)
    p$line_off <- src$line_start[ln]
    out[[length(out) + 1L]] <- p
  }
  src$cache$code_pieces <- out
  out
}

# file offsets of the start and end of node i of a piece
piece_span <- function(p, i) {
  d <- p$tree$pd
  c(p$line_off[d$line1[i]] + d$col1[i] - 1, p$line_off[d$line2[i]] + d$col2[i] - 1)
}

lc_find <- function(src, s, e, rule, text, message, hint = NA_character_, context = "prose") {
  finding_at(src, s, e, rule = rule, text = text, message = message, hint = hint, context = context)
}

# Findings from records (s, e, text, message, hint, context) kept in a list, built in one call:
# a finding costs a data frame each when built one at a time (review 3, finding 10).
lc_find_all <- function(src, rule, recs) {
  if (!length(recs)) return(new_findings())
  g <- function(f) vapply(recs, function(r) r[[f]], "")
  finding_at(src, vapply(recs, function(r) r$s, 1), vapply(recs, function(r) r$e, 1), rule = rule,
             text = g("text"), message = g("message"), hint = g("hint"), context = g("context"))
}

lc_pieces <- function(src, kinds) {
  Filter(function(p) p$kind %in% kinds && !is.null(p$tree), code_pieces(src))
}

# ---- literal-value (L22) -----------------------------------------------------------------

lint_literal_value <- function(src, ctx) {
  out <- list()
  for (p in lc_pieces(src, c("value", "bare", "n", "sign", "list"))) {
    if (p$kind %in% c("n", "sign", "list") && (is_backref(p$text) || identical(trim_ws(p$text), "."))) next
    if (!tree_literal(p$tree)) next
    out[[length(out) + 1L]] <- lc_find(
      src, p$off, p$off + nchar(p$text) - 1, "literal-value", p$text,
      sprintf("`%s` is made only of constants, so it is a number typed in the source (rule 5.6.1).", p$text),
      "Compute it, put it in the dictionary, or write [10]{.weft-literal why=\"...\"}.", p$context)
  }
  bind_findings(out)
}

# ---- inert-check (L23) ---------------------------------------------------------------------

lint_inert_check <- function(src, ctx) {
  recs <- list()
  for (p in code_pieces(src)) {
    t <- p$tree
    if (is.null(t)) next
    if (p$kind == "if" && !has_var(t, t$roots[1L])) {
      recs[[length(recs) + 1L]] <- list(
        s = p$off, e = p$off + nchar(p$text) - 1, text = p$text,
        message = sprintf("The condition `%s` has no variable, so it always takes the same arm (rule 3.1.6).", p$text),
        hint = "Make the condition depend on a value, or write the arm without a guard.", context = p$context)
    }
    for (i in all_exprs(t)) {
      ci <- call_info(t, i)
      if (!is_fn(ci, "claim", "weft")) next
      for (j in seq_along(ci$args)) {
        a <- ci$args[[j]]
        if (j == 1L || identical(a$name, "level")) next
        if (has_var(t, a$node)) next
        sp <- piece_span(p, a$node)
        tx <- node_text(t, a$node)
        recs[[length(recs) + 1L]] <- list(
          s = sp[1L], e = sp[2L], text = tx,
          message = sprintf("The check `%s` has no variable, so it can never fail (rule 3.1.6).", tx),
          hint = "Test the value with `.`, for example `. > 0`.", context = p$context)
      }
    }
  }
  lc_find_all(src, "inert-check", recs)
}

# ---- value-constant and value-format (L24, L25) ---------------------------------------------------

FORMAT_FNS <- c("round", "signif", "format", "formatC", "prettyNum", "sprintf")

# the numeric constants of a value that are not exempt, as the nodes they run from and to
value_constants <- function(p) {
  t <- p$tree
  tk <- t$pd$token
  found <- list()
  walk <- function(i, exempt) {
    if (tk[i] != "expr") return(invisible())
    k <- t$kids[[i]]
    if (length(k) == 1L && tk[k] == "NUM_CONST") {
      v <- num_value(t, i)
      if (!exempt && !is.na(v) && !(v %in% c(0, 1))) found[[length(found) + 1L]] <<- list(from = i, to = i)
      return(invisible())
    }
    if (length(k) == 2L && tk[k[1L]] == "'-'" && length(t$kids[[k[2L]]]) == 1L &&
        tk[t$kids[[k[2L]]]] == "NUM_CONST") {
      v <- num_value(t, k[2L])
      if (!exempt && !is.na(v) && !(v %in% c(0, 1))) found[[length(found) + 1L]] <<- list(from = k[1L], to = k[2L])
      return(invisible())
    }
    ci <- call_info(t, i)
    argex <- integer()
    if (!is.null(ci)) {
      claim <- is_fn(ci, "claim", "weft")
      fmt <- is_fn(ci, FORMAT_FNS, "base")
      for (j in seq_along(ci$args)) {
        a <- ci$args[[j]]
        if ((claim && j >= 2L && !identical(a$name, "level")) || (fmt && j >= 2L)) argex <- c(argex, a$node)
      }
    }
    for (kk in k) if (tk[kk] == "expr") walk(kk, exempt || kk %in% argex)
    invisible()
  }
  for (r in t$roots) walk(r, FALSE)
  found
}

lint_value_constant <- function(src, ctx) {
  recs <- list()
  for (p in lc_pieces(src, c("value", "bare"))) {
    if (tree_literal(p$tree)) next
    d <- p$tree$pd
    for (f in value_constants(p)) {
      s <- p$line_off[d$line1[f$from]] + d$col1[f$from] - 1
      e <- p$line_off[d$line2[f$to]] + d$col2[f$to] - 1
      tx <- substr(src$text, s, e)
      recs[[length(recs) + 1L]] <- list(
        s = s, e = e, text = tx,
        message = sprintf("The constant `%s` is typed inside a value (rule 5.6.2).", tx),
        hint = "Put the constant in the dictionary or a named variable.", context = p$context)
    }
  }
  lc_find_all(src, "value-constant", recs)
}

lint_value_format <- function(src, ctx) {
  out <- list()
  for (p in lc_pieces(src, c("value", "bare"))) {
    t <- p$tree
    for (r in t$roots) {
      i <- r
      repeat {
        k <- t$kids[[i]]
        if (length(k) == 3L && t$pd$token[k[1L]] == "'('" && t$pd$token[k[3L]] == "')'") {
          i <- k[2L]
          next
        }
        if (!is.na(pipe_lhs(t, k[3L] %||% NA_integer_))) {   # look through a pipe to the call it ends in
          i <- k[3L]
          next
        }
        ci <- call_info(t, i)
        if (is_fn(ci, "claim", "weft")) {
          if (!length(ci$args)) break
          i <- ci$args[[1L]]$node
          next
        }
        if (is_fn(ci, FORMAT_FNS, "base")) {
          sp <- piece_span(p, ci$fpos)
          out[[length(out) + 1L]] <- lc_find(
            src, sp[1L], sp[2L], "value-format", ci$fn,
            sprintf("The value is formatted in code with `%s()` (rule 5.6.4).", ci$fn),
            "Return the raw number and use a class or `digits=` to format it.", p$context)
        }
        break
      }
    }
  }
  bind_findings(out)
}

# ---- spans: lone-bar, if-zero and name (L26-L28) ---------------------------------------------------

# The end of a code span that opens at `i` of the characters `ch` (the position of its
# last backtick), or NA when it is never closed.
code_span_end <- function(ch, i) {
  n <- length(ch)
  j <- i
  while (j < n && ch[j + 1L] == "`") j <- j + 1L
  run <- j - i + 1L
  k <- j + 1L
  while (k <= n) {
    if (ch[k] == "`") {
      m <- k
      while (m < n && ch[m + 1L] == "`") m <- m + 1L
      if (m - k + 1L == run) return(m)
      k <- m + 1L
    } else k <- k + 1L
  }
  NA_integer_
}

# The `[...]{...}` spans inside the text `txt` (which starts at file offset `base`), at
# every depth: file offsets of `[`, `]` and the attribute block's braces.
find_spans <- function(txt, base) {
  ch <- strsplit(txt, "")[[1L]]
  n <- length(ch)
  stack <- integer()
  res <- list()
  i <- 1L
  while (i <= n) {
    c <- ch[i]
    if (c == "\\") {
      i <- i + 2L
      next
    }
    if (c == "`") {
      ce <- code_span_end(ch, i)
      if (is.na(ce)) {
        while (i < n && ch[i + 1L] == "`") i <- i + 1L
        i <- i + 1L
      } else i <- ce + 1L
      next
    }
    if (c == "[") {
      stack <- c(stack, i)
    } else if (c == "]" && length(stack)) {
      o <- stack[length(stack)]
      stack <- stack[-length(stack)]
      if (i < n && ch[i + 1L] == "{") {
        cb <- which(ch[(i + 2L):n] == "}")
        if (i + 2L <= n && length(cb)) {
          e <- i + 1L + cb[1L]
          res[[length(res) + 1L]] <- c(open = base + o - 1, close = base + i - 1,
                                       astart = base + i, aend = base + e - 1)
          i <- e + 1L
          next
        }
      }
    }
    i <- i + 1L
  }
  if (!length(res)) return(data.frame(open = numeric(), close = numeric(), astart = numeric(), aend = numeric()))
  as.data.frame(do.call(rbind, res))
}

# every span of the document (those the reader found and those nested in them) and every
# code span with an attribute block, each with its tokens
span_items <- function(src) {
  if (!is.null(src$cache$span_items)) return(src$cache$span_items)
  reg <- src$regions
  rows <- src$rows
  items <- list()
  seen <- numeric()
  sp <- reg[reg$type == "span" & !is.na(reg$attr_start), , drop = FALSE]
  add_span <- function(open, close, astart, aend, row) {
    if (open %in% seen) return(invisible())
    seen <<- c(seen, open)
    tk <- attr_tokens(substr(src$text, astart, aend), astart)
    items[[length(items) + 1L]] <<- list(kind = "span", open = open, close = close, astart = astart,
                                         aend = aend, toks = tk, row = row)
  }
  for (i in seq_len(nrow(sp))) {
    row <- if (is.na(sp$row[i])) NA_integer_ else sp$row[i]
    add_span(sp$inner_start[i], sp$inner_end[i], sp$attr_start[i], sp$attr_end[i], row)
  }
  for (i in seq_len(nrow(sp))) {
    nested <- find_spans(substr(src$text, sp$start[i], sp$end[i]), sp$start[i])
    for (j in seq_len(nrow(nested))) {
      add_span(nested$open[j], nested$close[j], nested$astart[j], nested$aend[j], NA_integer_)
    }
  }
  ca <- reg[reg$type == "code_attr" & !is.na(reg$attr_start), , drop = FALSE]
  for (i in seq_len(nrow(ca))) {
    tk <- attr_tokens(substr(src$text, ca$attr_start[i], ca$attr_end[i]), ca$attr_start[i])
    items[[length(items) + 1L]] <- list(kind = "code", open = ca$start[i], close = NA_real_,
                                        astart = ca$attr_start[i], aend = ca$attr_end[i], toks = tk,
                                        row = match(ca$start[i], rows$fstart))
  }
  src$cache$span_items <- items
  items
}

# where a file offset sits: prose, front matter, a caption or a weft_str() string
context_at <- function(src, pos) {
  reg <- src$regions
  m <- c(yaml_field = "front-matter", caption = "caption", weft_str = "weft_str")
  r <- reg[reg$type %in% names(m) & reg$start <= pos & reg$end >= pos, , drop = FALSE]
  if (!nrow(r)) return("prose")
  unname(m[r$type[1L]])
}

# the number of `|` in bracket text that are not escaped and not inside a code span,
# a nested bracket or a nested attribute block
bar_count <- function(txt) {
  ch <- strsplit(txt, "")[[1L]]
  n <- length(ch)
  depth <- 0L
  brace <- 0L
  bars <- 0L
  i <- 1L
  while (i <= n) {
    c <- ch[i]
    if (c == "\\") {
      i <- i + 2L
      next
    }
    if (c == "`") {
      ce <- code_span_end(ch, i)
      if (is.na(ce)) {
        while (i < n && ch[i + 1L] == "`") i <- i + 1L
        i <- i + 1L
      } else i <- ce + 1L
      next
    }
    if (c == "[") depth <- depth + 1L
    else if (c == "]") depth <- max(0L, depth - 1L)
    else if (c == "{") brace <- brace + 1L
    else if (c == "}") brace <- max(0L, brace - 1L)
    else if (c == "|" && depth == 0L && brace == 0L) bars <- bars + 1L
    i <- i + 1L
  }
  bars
}

lint_lone_bar <- function(src, ctx) {
  out <- list()
  tb <- src$regions[src$regions$type == "table", , drop = FALSE]
  for (it in span_items(src)) {
    if (it$kind != "span") next
    if (nrow(tb) && any(tb$start <= it$open & tb$end >= it$open)) next
    keys <- tolower(it$toks$name[it$toks$type == "key"])
    if (any(keys %in% c(GOVERNOR_KEYS))) next
    if (it$close - it$open < 2) next
    inner <- substr(src$text, it$open + 1, it$close - 1)
    if (bar_count(inner) != 1L) next
    out[[length(out) + 1L]] <- lc_find(
      src, it$open + 1, it$close - 1, "lone-bar", inner,
      sprintf("The bracket `[%s]` holds one `|` and has no governor, so it is not read as arms (rule 5.3.3).", inner),
      "Add a governor (`n`, `if`, `sign`, `list`) or escape the bar as `\\|`.", context_at(src, it$open + 1))
  }
  bind_findings(out)
}

lint_if_zero <- function(src, ctx) {
  out <- list()
  for (p in lc_pieces(src, "if")) {
    t <- p$tree
    tk <- t$pd$token
    is_zero <- function(i) {
      k <- t$kids[[i]]
      if (length(k) == 2L && tk[k[1L]] %in% c("'-'", "'+'")) return(is_zero(k[2L]))
      identical(num_value(t, i), 0)
    }
    hit <- FALSE
    for (i in all_exprs(t)) {
      k <- t$kids[[i]]
      if (length(k) == 3L && tk[k[2L]] %in% c("EQ", "NE", "LT", "GT", "LE", "GE") &&
          tk[k[1L]] == "expr" && tk[k[3L]] == "expr" && (is_zero(k[1L]) || is_zero(k[3L]))) {
        hit <- TRUE
        break
      }
    }
    if (!hit) next
    out[[length(out) + 1L]] <- lc_find(
      src, p$off, p$off + nchar(p$text) - 1, "if-zero", p$text,
      sprintf("The condition `%s` compares with 0, which is a threshold typed in the source (rule 5.3.3).", p$text),
      "Compare with a named value from the dictionary.", p$context)
  }
  bind_findings(out)
}

# optimal string alignment distance (a transposition of neighbours is one edit)
osa_dist <- function(a, b) {
  x <- strsplit(a, "")[[1L]]
  y <- strsplit(b, "")[[1L]]
  nx <- length(x)
  ny <- length(y)
  d <- matrix(0L, nx + 1L, ny + 1L)
  d[, 1L] <- 0:nx
  d[1L, ] <- 0:ny
  for (i in seq_len(nx)) {
    for (j in seq_len(ny)) {
      cost <- if (x[i] == y[j]) 0L else 1L
      v <- min(d[i, j + 1L] + 1L, d[i + 1L, j] + 1L, d[i, j] + cost)
      if (i > 1L && j > 1L && x[i] == y[j - 1L] && x[i - 1L] == y[j]) v <- min(v, d[i - 1L, j - 1L] + 1L)
      d[i + 1L, j + 1L] <- v
    }
  }
  d[nx + 1L, ny + 1L]
}

lint_name <- function(src, ctx) {
  cfg <- src$cfg
  reg <- cfg$formatters %||% list()
  weft_classes <- unique(c(shipped_classes(), names(reg)))
  fmt_classes <- formatter_classes(reg)
  weft_keys <- c(GOVERNOR_KEYS, RENDERER_KEYS, "why")
  pandoc_classes <- c(".smallcaps", ".underline", ".mark")
  expected <- as.character(unlist(cfg$expected_names))
  class_bodies <- sub("^\\.", "", weft_classes)
  known_class <- function(nm) nm %in% c(weft_classes, pandoc_classes, expected)
  known_key <- function(nm) tolower(nm) %in% c(weft_keys, "custom-style") || nm %in% expected
  # the nearest weft name when the name is one edit from it (K7), else NA
  nearest <- function(nm, is_class) {
    body <- if (is_class) sub("^\\.", "", nm) else nm
    cands <- if (is_class) class_bodies else c(weft_keys, class_bodies)
    shown <- if (is_class) weft_classes else c(weft_keys, weft_classes)
    case <- which(tolower(body) == tolower(cands) & body != cands)
    if (is_class && length(case)) return(shown[case[1L]])
    if (nchar(body) < 3L) return(NA_character_)
    d <- vapply(cands, function(z) osa_dist(body, z), 1L, USE.NAMES = FALSE)
    # a key spelt as a class (`count`) is no edit from the class
    ok <- if (is_class) d == 1L else d <= 1L
    if (any(ok)) return(shown[which(ok)[1L]])
    NA_character_
  }
  out <- list()
  for (it in span_items(src)) {
    tk <- it$toks
    tk <- tk[tk$type %in% c("class", "key"), , drop = FALSE]
    if (!nrow(tk)) next
    keys_l <- tolower(tk$name[tk$type == "key"])
    gov <- any(keys_l %in% GOVERNOR_KEYS)
    classes <- tk$name[tk$type == "class"]
    construct <- !is.na(it$row) || (it$kind == "span" && (gov || any(classes %in% weft_classes)))
    cx <- context_at(src, it$open)
    for (j in seq_len(nrow(tk))) {
      nm <- tk$name[j]
      is_class <- tk$type[j] == "class"
      known <- if (is_class) known_class(nm) else known_key(nm)
      pos <- tk$pos[j]
      end <- pos + nchar(nm) - 1
      if (!known) {
        near <- nearest(nm, is_class)
        # on a code span a class is "one edit" from weft's only when a governor or key is there too:
        # `{.cpp}` is a highlighting language, not a typo (review 3, finding 12)
        if (is_class && identical(it$kind, "code") && !any(tk$type == "key") && !is.na(near)) next
        if (!construct && is.na(near)) next
        msg <- if (!is.na(near)) {
          sprintf("`%s` is not a name weft knows; it is one edit from `%s` (rule 5.3.3).", nm, near)
        } else {
          sprintf("`%s` is not a name weft knows on a construct (rule 5.3.3).", nm)
        }
        out[[length(out) + 1L]] <- lc_find(src, pos, end, "name", nm, msg,
          "Check the spelling, or list the name under `expected_names` in _weft.yml.", cx)
      } else if (it$kind == "span" && !gov &&
                 ((is_class && nm %in% fmt_classes) || (!is_class && tolower(nm) %in% RENDERER_KEYS))) {
        out[[length(out) + 1L]] <- lc_find(src, pos, end, "name", nm,
          sprintf("`%s` formats a value, but the bracket has no governor key, so it formats nothing (rule 5.3.3).", nm),
          "Put it on inline code (`r x`{.num}) or add a governor key such as `n`.", cx)
      }
    }
  }
  bind_findings(out)
}

# ---- target reads: tar-name and tar-cache (L34) -----------------------------------------------------------

TAR_FNS <- c("tar_read", "tar_load", "tar_read_raw", "tar_load_raw")

# the names a target-read argument gives: nodes and values. `raw` reads take strings only.
node_names <- function(t, i, raw) {
  tk <- t$pd$token
  sv <- str_value(t, i)
  if (!is.na(sv)) return(list(list(node = i, value = sv, str = TRUE)))
  k <- t$kids[[i]]
  if (!raw && tk[i] == "expr" && length(k) == 1L && tk[k] == "SYMBOL") {
    return(list(list(node = i, value = t$pd$text[k], str = FALSE)))
  }
  ci <- call_info(t, i)
  if (is_fn(ci, "c", "base")) {
    got <- lapply(ci$args, function(a) node_names(t, a$node, raw))
    return(unlist(got, recursive = FALSE))
  }
  list()
}

# the target reads of a piece: name, file span, the literal store (NA for the default)
# and whether the store is known
target_reads <- function(p) {
  t <- p$tree
  out <- list()
  for (i in all_exprs(t)) {
    ci <- call_info(t, i)
    if (!is_fn(ci, TAR_FNS, "targets") || !length(ci$args)) next
    raw <- grepl("_raw$", ci$fn)
    nms <- vapply(ci$args, function(a) if (is.na(a$name)) "" else a$name, "")
    pick <- which(nms %in% c("name", "names"))
    if (!length(pick)) pick <- which(nms == "")
    if (!length(pick)) next
    store <- NA_character_
    store_ok <- TRUE
    si <- which(nms == "store")
    if (length(si)) {
      sv <- str_value(t, ci$args[[si[1L]]]$node)
      if (is.na(sv)) store_ok <- FALSE else store <- sv
    }
    for (nm in node_names(t, ci$args[[pick[1L]]]$node, raw)) {
      sp <- piece_span(p, nm$node)
      if (nm$str) sp <- c(sp[1L] + 1, sp[2L] - 1)
      out[[length(out) + 1L]] <- list(name = nm$value, start = sp[1L], end = sp[2L], store = store,
                                      store_ok = store_ok, context = p$context, chunk = p$chunk)
    }
  }
  out
}

tar_default_store <- function(ctx) {
  f <- file.path(ctx$root, "_targets.yaml")
  y <- if (file.exists(f)) tryCatch(yaml::read_yaml(f, eval.expr = FALSE), error = function(e) NULL) else NULL
  s <- if (is.list(y) && is.list(y$main)) y$main$store else NULL
  if (is.character(s) && length(s) == 1L && !is.na(s) && nzchar(s)) s else "_targets"
}

# the names in a targets store, or NULL with a note when there is no store to read
tar_store_names <- function(ctx, store) {
  cache <- ctx$tar_names
  if (is.null(cache)) {
    cache <- new.env(parent = emptyenv())
    ctx$tar_names <- cache
  }
  if (!is.null(cache[[store]])) return(if (identical(cache[[store]], NA)) NULL else cache[[store]])
  path <- if (grepl("^(/|[A-Za-z]:)", store)) store else file.path(ctx$root, store)
  res <- NA
  if (!file.exists(file.path(path, "meta", "meta"))) {
    ctx$note(sprintf("tar-name: no targets store at `%s`, so target names were not checked (rule 5.8.2).", store))
  } else if (!requireNamespace("targets", quietly = TRUE)) {
    ctx$note("tar-name: the targets package is not installed, so target names were not checked (rule 5.8.2).")
  } else {
    nm <- tryCatch(as.character(targets::tar_meta(store = path, fields = "type")$name), error = function(e) NULL)
    if (is.null(nm)) {
      ctx$note(sprintf("tar-name: the targets store at `%s` could not be read, so target names were not checked (rule 5.8.2).", store))
    } else res <- nm
  }
  cache[[store]] <- res
  if (identical(res, NA)) NULL else res
}

lint_tar_name <- function(src, ctx) {
  reads <- unlist(lapply(lc_pieces(src, c("value", "bare", "n", "sign", "list", "if", "chunk")), target_reads),
                  recursive = FALSE)
  if (!length(reads)) return(new_findings())
  out <- list()
  for (r in reads) {
    if (!r$store_ok) next
    store <- if (is.na(r$store)) tar_default_store(ctx) else r$store
    have <- tar_store_names(ctx, store)
    if (is.null(have) || r$name %in% have) next
    out[[length(out) + 1L]] <- lc_find(
      src, r$start, r$end, "tar-name", r$name,
      sprintf("The target `%s` is not in the targets store `%s` (rule 5.8.2).", r$name, store),
      "Check the name, or build the target with tar_make().", r$context)
  }
  bind_findings(out)
}

# a cache setting as TRUE, FALSE or NA
cache_flag <- function(v) {
  if (is.logical(v) && length(v) == 1L) return(v)
  if (is.character(v) && length(v) == 1L) {
    if (tolower(v) %in% c("true", "yes")) return(TRUE)
    if (tolower(v) %in% c("false", "no")) return(FALSE)
  }
  NA
}

# the `cache` a YAML mapping sets: `execute: cache:`, else `knitr: opts_chunk: cache:`
yaml_cache <- function(y) {
  if (!is.list(y)) return(NA)
  v <- if (is.list(y$execute)) y$execute$cache else NULL
  f <- cache_flag(v)
  if (!is.na(f)) return(f)
  v <- if (is.list(y$knitr) && is.list(y$knitr$opts_chunk)) y$knitr$opts_chunk$cache else NULL
  cache_flag(v)
}

# the cache a project file sets for a document: `_metadata.yml` of its folder and the
# folders above it, then `_quarto.yml`
file_cache <- function(src, ctx) {
  d <- dirname(src$file)
  dirs <- character()
  repeat {
    dirs <- c(dirs, d)
    if (d %in% c(".", "")) break
    d <- dirname(d)
  }
  files <- c(file.path(ctx$root, ifelse(dirs == ".", "", dirs), "_metadata.yml"), file.path(ctx$root, "_quarto.yml"))
  files <- gsub("//+", "/", files)
  for (f in files) {
    if (!file.exists(f)) next
    y <- tryCatch(yaml::read_yaml(f, eval.expr = FALSE), error = function(e) NULL)
    v <- yaml_cache(y)
    if (!is.na(v)) return(v)
  }
  NA
}

# each earlier `knitr::opts_chunk$set(cache = <literal>)` of a chunk piece, as TRUE, FALSE
# or NA (not literal); NULL when the chunk sets none
chunk_cache_set <- function(p) {
  t <- p$tree
  tk <- t$pd$token
  res <- NULL
  for (i in all_exprs(t)) {
    ci <- call_info(t, i)
    if (is.null(ci)) next
    fk <- t$kids[[t$kids[[i]][1L]]]
    if (length(fk) != 3L || tk[fk[2L]] != "'$'" || t$pd$text[fk[3L]] != "set") next
    if (!(node_text(t, fk[1L]) %in% c("opts_chunk", "knitr::opts_chunk"))) next
    for (a in ci$args) {
      if (!identical(a$name, "cache")) next
      tx <- node_text(t, a$node)
      res <- if (tx %in% c("TRUE", "FALSE")) identical(tx, "TRUE") else NA
    }
  }
  res
}

lint_tar_cache <- function(src, ctx) {
  ch <- src$chunks
  pcs <- Filter(function(p) p$kind == "chunk" && !is.null(p$tree), code_pieces(src))
  if (!length(pcs)) return(new_findings())
  by_chunk <- list()
  for (p in pcs) by_chunk[[as.character(p$chunk)]] <- p
  doc_v <- yaml_cache(src$front)
  file_v <- NULL
  state <- NA
  out <- list()
  for (c in seq_len(nrow(ch))) {
    p <- by_chunk[[as.character(c)]]
    if (is.null(p)) next
    reads <- target_reads(p)
    if (length(reads)) {
      on <- ch$cache[c]
      if (is.na(on)) on <- state
      if (is.na(on)) on <- doc_v
      if (is.na(on)) {
        if (is.null(file_v)) file_v <- file_cache(src, ctx)
        on <- file_v
      }
      if (isTRUE(on)) {
        for (r in reads) {
          out[[length(out) + 1L]] <- lc_find(
            src, r$start, r$end, "tar-cache", r$name,
            sprintf("The chunk reads the target `%s` and has its cache on, so a rebuilt target is not picked up (rule 5.8.7).", r$name),
            "Turn the cache off for the chunk (`#| cache: false`); targets caches the value itself.", "chunk")
        }
      }
    }
    st <- chunk_cache_set(p)
    if (!is.null(st)) state <- st
  }
  bind_findings(out)
}

# ---- dict-assign and dict-key (L34) -----------------------------------------------------------------------

# the leftmost symbol of an assignment target, NA when there is none
lead_symbol <- function(t, i) {
  tk <- t$pd$token
  if (tk[i] != "expr") return(NA_character_)
  k <- t$kids[[i]]
  if (length(k) == 1L) {
    if (tk[k] == "SYMBOL") return(t$pd$text[k])
    if (tk[k] == "STR_CONST") return(str_value(t, i))
    return(NA_character_)
  }
  ci <- call_info(t, i)
  if (!is.null(ci)) {
    if (!length(ci$args)) return(NA_character_)
    return(lead_symbol(t, ci$args[[1L]]$node))
  }
  if (length(k) >= 3L && tk[k[1L]] == "expr" && tk[k[2L]] %in% c("'$'", "'@'", "'['", "LBB")) {
    return(lead_symbol(t, k[1L]))
  }
  NA_character_
}

lint_dict_assign <- function(src, ctx) {
  out <- list()
  for (p in lc_pieces(src, "chunk")) {
    t <- p$tree
    tk <- t$pd$token
    for (i in all_exprs(t)) {
      k <- t$kids[[i]]
      if (tk[i] == "expr" && length(k) == 3L && tk[k[2L]] %in% c("LEFT_ASSIGN", "EQ_ASSIGN", "RIGHT_ASSIGN")) {
        target <- if (tk[k[2L]] == "RIGHT_ASSIGN") k[3L] else k[1L]
        if (!identical(lead_symbol(t, target), "dict")) next
        sp <- piece_span(p, target)
        tx <- node_text(t, target)
        out[[length(out) + 1L]] <- lc_find(
          src, sp[1L], sp[2L], "dict-assign", tx,
          sprintf("`%s` assigns to `dict`, which a document only reads (rule 5.8.3).", tx),
          "Put the value in dict.yml, or in the document's `weft: dict_local:`.", "chunk")
        next
      }
      ci <- call_info(t, i)
      if (is_fn(ci, "assign", "base") && length(ci$args) && identical(str_value(t, ci$args[[1L]]$node), "dict")) {
        sp <- piece_span(p, ci$args[[1L]]$node)
        out[[length(out) + 1L]] <- lc_find(
          src, sp[1L] + 1, sp[2L] - 1, "dict-assign", "dict",
          "`assign(\"dict\", ...)` assigns to `dict`, which a document only reads (rule 5.8.3).",
          "Put the value in dict.yml, or in the document's `weft: dict_local:`.", "chunk")
      }
    }
  }
  bind_findings(out)
}

# the reads of `dict$k`, `dict$"k"`, `dict[["k"]]` (and the same of `dict_local`) in a piece
dict_reads <- function(p) {
  t <- p$tree
  tk <- t$pd$token
  out <- list()
  for (i in all_exprs(t)) {
    if (tk[i] != "expr") next
    k <- t$kids[[i]]
    if (length(k) < 3L || tk[k[1L]] != "expr") next
    bk <- t$kids[[k[1L]]]
    if (length(bk) != 1L || tk[bk] != "SYMBOL" || !(t$pd$text[bk] %in% c("dict", "dict_local"))) next
    obj <- t$pd$text[bk]
    key <- NA_character_
    node <- NA_integer_
    if (length(k) == 3L && tk[k[2L]] == "'$'") {
      node <- k[3L]
      key <- if (tk[node] == "SYMBOL") t$pd$text[node] else if (tk[node] == "STR_CONST") str_value(t, node) else NA_character_
    } else if (length(k) == 5L && tk[k[2L]] == "LBB" && tk[k[3L]] == "expr") {
      node <- k[3L]
      key <- str_value(t, node)
    }
    if (is.na(key)) next
    sp <- piece_span(p, node)
    out[[length(out) + 1L]] <- list(obj = obj, key = key, start = sp[1L], end = sp[2L], context = p$context)
  }
  out
}

dict_file_keys <- function(ctx) {
  if (!is.null(ctx$dict_keys)) return(ctx$dict_keys)
  f <- file.path(ctx$root, "dict.yml")
  res <- list(exists = file.exists(f), ok = TRUE, keys = character())
  if (res$exists) {
    y <- tryCatch(yaml::read_yaml(f, eval.expr = FALSE), error = function(e) NULL)
    if (is.null(y) && length(readLines(f, warn = FALSE, n = 1L))) {
      res$ok <- FALSE
      ctx$note("dict-key: dict.yml could not be read, so dictionary keys were not checked (rule 5.8.6).")
    } else if (is.list(y)) {
      res$keys <- names(y) %||% character()
    }
  }
  ctx$dict_keys <- res
  res
}

lint_dict_key <- function(src, ctx) {
  reads <- unlist(lapply(lc_pieces(src, c("value", "bare", "n", "sign", "list", "if", "chunk")), dict_reads),
                  recursive = FALSE)
  if (!length(reads)) return(new_findings())
  w <- if (is.list(src$front)) src$front$weft else NULL
  local <- if (is.list(w) && is.list(w$dict_local)) names(w$dict_local) else character()
  local <- local %||% character()
  dk <- dict_file_keys(ctx)
  out <- list()
  for (r in reads) {
    msg <- NULL
    hint <- NA_character_
    if (r$obj == "dict_local") {
      if (r$key %in% local) next
      msg <- sprintf("`dict_local$%s`: this document defines no local `%s` (rule 5.8.6).", r$key, r$key)
      hint <- "Define it under `weft: dict_local:` in the front matter, or read it as `dict$key`."
    } else if (r$key %in% local) {
      msg <- sprintf("`dict$%s` is ambiguous: this document defines a local `%s` (rule 5.8.6).", r$key, r$key)
      hint <- sprintf("Read it as `dict_local$%s`.", r$key)
    } else if (!dk$ok) {
      next
    } else if (!dk$exists) {
      msg <- sprintf("`dict$%s` is read, but the project has no dict.yml (rule 5.8.6).", r$key)
      hint <- "Add dict.yml at the project root, or define the key under `weft: dict_local:`."
    } else if (!(r$key %in% dk$keys)) {
      sug <- did_you_mean(r$key, dk$keys)
      msg <- sprintf("`dict$%s` is not a key of dict.yml%s (rule 5.8.6).", r$key, if (nzchar(sug)) paste0(".", sug) else "")
      hint <- "Add the key to dict.yml, or correct the name."
    }
    if (is.null(msg)) next
    out[[length(out) + 1L]] <- lc_find(src, r$start, r$end, "dict-key", r$key, msg, hint, r$context)
  }
  bind_findings(out)
}

# ---- above-setup (L34) ---------------------------------------------------------------------------------------

lint_above_setup <- function(src, ctx) {
  ch <- src$chunks
  if (!nrow(ch)) return(new_findings())
  calls <- vapply(seq_len(nrow(ch)), function(c) {
    if (!identical(tolower(ch$engine[c]), "r") || isFALSE(ch$eval[c])) return(FALSE)
    code <- sub("#.*$", "", ch$code[[c]])
    any(grepl("(^|[^A-Za-z0-9_.])weft_setup[ \t]*\\(", code, perl = TRUE))
  }, NA)
  if (!any(calls)) return(new_findings())
  fm <- if (is.list(src$front)) src$front$knitr else NULL
  if (is.list(fm) && is.list(fm$opts_knit) && !is.null(fm$opts_knit$weft)) return(new_findings())
  rp <- file.path(ctx$root, ".Rprofile")
  if (file.exists(rp)) {
    txt <- tryCatch(paste(readLines(rp, warn = FALSE), collapse = "\n"), error = function(e) "")
    if (grepl("weft_setup[ \t]*\\(", txt)) return(new_findings())
  }
  open <- ch$open[which(calls)[1L]]
  r <- src$rows
  keep <- which(!(r$kind %in% c("bare", "link")) & !is.na(r$fstart) & src_line_of(src, r$fstart) < open &
                  live_rows(src))
  out <- list()
  for (i in keep) {
    tx <- substr(src$text, r$fstart[i], r$fend[i])
    if (nchar(tx) > 80L) tx <- substr(tx, 1L, 80L)
    out[[length(out) + 1L]] <- lc_find(
      src, r$fstart[i], r$fend[i], "above-setup", tx,
      sprintf("A construct sits above the chunk that calls weft_setup() (line %d), so it is read before weft is set up (rule 5.8.5).", open),
      "Move weft_setup() above it, or set it in the front matter (`knitr: opts_knit: weft:`) or .Rprofile.",
      r$context[i])
  }
  bind_findings(out)
}
