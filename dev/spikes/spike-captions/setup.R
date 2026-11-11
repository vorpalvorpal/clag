## clag stand-in runtime: a small hand-written scanner + the two knitr hooks.
##
## Install from the setup chunk of a document:   source("setup.R"); clag_install()
##
## ENCODING NOTE: the placeholder delimiters are the private-use code points
## U+E000 / U+E001. They are written below as \u escapes so this file is pure
## ASCII, and they only ever live in memory (knitr never writes them to disk).
## All scanning is done on a character vector (strsplit(x, "")), never with
## byte-based regex, so it is safe in a UTF-8 session (R >= 4.2 on Windows).
##
## Pipeline:  evaluate.inline hook  -> parks `r code`, returns O<idx>C
##            text hook             -> clag_text(): parse -> AST, then render AST
##                                     lazily (only chosen arms are evaluated).

clag <- new.env()
clag$O <- ""; clag$C <- ""; clag$pend <- list(); clag$maps <- list()

clag_install <- function() {
  clag$pend <- list()
  if (is.null(clag$stock_eval)) clag$stock_eval <- knitr::knit_hooks$get("evaluate.inline", default = TRUE)
  knitr::knit_hooks$set(
    evaluate.inline = function(code, envir) {
      clag$pend[[length(clag$pend) + 1L]] <- code            # parked, NOT run
      paste0(clag$O, length(clag$pend), clag$C)
    },
    text = function(x) clag_text(x))
  invisible(TRUE)
}

## ---- locating a construct: file + exact line ------------------------------
## knitr keeps the line count of every input block in `knitr:::knit_concord`
## ("inlines") and the index of the current block ("block"). Neither is exported
## (knitr::current_input() IS exported but gives only the file). Block start =
## 1 + lines in all earlier blocks. Under Quarto knitr sees the EXPANDED file
## (x.rmarkdown), so we map expanded lines back to authored file:line by
## re-expanding {{< include >}} lines ourselves (include = its lines + 1 blank).
clag_expand <- function(path, seen = character()) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  out_f <- character(); out_l <- integer()
  rx <- "^\\s*\\{\\{<\\s*include\\s+([^ >]+)\\s*>\\}\\}\\s*$"
  for (k in seq_along(lines)) {
    m <- regmatches(lines[k], regexec(rx, lines[k]))[[1]]
    if (length(m) == 2 && !(m[2] %in% seen)) {
      inc <- file.path(dirname(path), m[2])
      sub <- clag_expand(inc, c(seen, m[2]))
      out_f <- c(out_f, sub$f, basename(path)); out_l <- c(out_l, sub$l, k)  # +1 blank
    } else { out_f <- c(out_f, basename(path)); out_l <- c(out_l, k) }
  }
  list(f = out_f, l = out_l)
}

clag_locator <- function(nl) {                       # nl = positions of "\n" in the block
  kc <- tryCatch(get("knit_concord", asNamespace("knitr")), error = function(e) NULL)
  inl <- if (!is.null(kc)) kc$get("inlines"); blk <- if (!is.null(kc)) kc$get("block")
  start <- if (length(inl) && length(blk)) 1L + sum(utils::head(inl, blk - 1L)) else NA_integer_
  file <- tryCatch(knitr::current_input(), error = function(e) NULL) %||% "<unknown>"
  src <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NULL, warning = function(w) NULL)
  map <- NULL
  ## Under Quarto knitr's input is the intermediate "<name>.rmarkdown" (an expanded copy of <name>.qmd).
  if (!is.null(src) && grepl("\\.rmarkdown$", src)) {
    src <- sub("\\.rmarkdown$", ".qmd", src); file <- basename(src)
    if (isTRUE(getOption("clag.map_includes", TRUE)) && file.exists(src)) {
      map <- clag$maps[[src]]
      if (is.null(map)) map <- clag$maps[[src]] <- clag_expand(src)
    }
  }
  function(pos) {
    if (is.na(start)) return(paste0(file, ":?"))
    ln <- start + sum(nl < pos)                                  # line in what knitr sees
    if (!is.null(map) && ln <= length(map$l)) return(paste0(map$f[ln], ":", map$l[ln]))
    paste0(file, ":", ln)
  }
}
`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- attribute blocks ------------------------------------------------------
## {.a .b key="v" #id}. Returns NULL if the text is not a well-formed block
## (then the "{" is ordinary prose). Values: "..." or '...', \" unescaped.
clag_attr <- function(ch, i) {                        # ch[i] == "{"; returns list(a, end)
  n <- length(ch); j <- i + 1L
  cls <- character(); id <- character(); keys <- character(); vals <- character()
  repeat {
    while (j <= n && ch[j] %in% c(" ", "\t", "\n")) j <- j + 1L
    if (j > n) return(NULL)
    if (ch[j] == "}") return(list(a = list(cls = cls, id = id, keys = keys, vals = vals), end = j))
    if (ch[j] %in% c(".", "#")) {
      k <- j + 1L; s <- k
      while (k <= n && grepl("[A-Za-z0-9_:-]", ch[k])) k <- k + 1L
      if (k == s) return(NULL)
      w <- paste(ch[s:(k - 1L)], collapse = "")
      if (ch[j] == ".") cls <- c(cls, w) else id <- c(id, w)
      j <- k
    } else if (grepl("[A-Za-z_]", ch[j])) {
      k <- j
      while (k <= n && grepl("[A-Za-z0-9_:.-]", ch[k])) k <- k + 1L
      key <- paste(ch[j:(k - 1L)], collapse = "")
      if (k > n || ch[k] != "=") return(NULL)
      k <- k + 1L
      if (k > n) return(NULL)
      if (ch[k] %in% c("\"", "'")) {
        q <- ch[k]; k <- k + 1L; buf <- character()
        repeat {
          if (k > n) return(NULL)
          if (ch[k] == "\\" && k < n && ch[k + 1L] == q) { buf <- c(buf, q); k <- k + 2L; next }
          if (ch[k] == q) break
          buf <- c(buf, ch[k]); k <- k + 1L
        }
        k <- k + 1L; val <- paste(buf, collapse = "")
      } else {
        s <- k
        while (k <= n && !(ch[k] %in% c(" ", "\t", "\n", "}"))) k <- k + 1L
        val <- paste(ch[s:(k - 1L)], collapse = "")
      }
      keys <- c(keys, key); vals <- c(vals, val); j <- k
    } else return(NULL)
  }
}

## ---- the scanner -----------------------------------------------------------
clag_parse <- function(txt) {
  ch <- strsplit(txt, "")[[1]]; n <- length(ch)
  O <- clag$O; C <- clag$C
  st <- new.env(); st$i <- 1L
  specials <- c("\\", "`", "[", "]", "$", "|", "#", "~", "<", O)
  sp <- which(ch %in% specials)
  nl <- which(ch == "\n")
  nxt <- function(i) { j <- findInterval(i - 1L, sp) + 1L; if (j > length(sp)) n + 1L else sp[j] }
  slice <- function(a, b) if (b >= a) paste(ch[a:b], collapse = "") else ""
  line_start <- function(i) {                          # <=3 spaces then position i
    k <- i - 1L; sp_n <- 0L
    while (k >= 1L && ch[k] == " ") { k <- k - 1L; sp_n <- sp_n + 1L }
    (k < 1L || ch[k] == "\n") && sp_n <= 3L
  }
  unpark <- function(s) {                              # placeholders -> original source text
    m <- gregexpr(paste0(O, "[0-9]+", C), s)
    regmatches(s, m) <- lapply(regmatches(s, m), function(p)
      vapply(p, function(q) paste0("`r ", clag$pend[[as.integer(gsub(paste0("[", O, C, "]"), "", q))]], "`"), ""))
    s
  }
  fence_end <- function(i) {                           # fenced code block starting at i? -> last index or NA
    if (!line_start(i) || !(ch[i] %in% c("`", "~"))) return(NA_integer_)
    k <- i; while (k <= n && ch[k] == ch[i]) k <- k + 1L
    len <- k - i; if (len < 3L) return(NA_integer_)
    e <- nl[nl >= k]; e <- if (length(e)) e[1] else n + 1L
    if (ch[i] == "`" && any(ch[k:max(k, e - 1L)] == "`") && e > k) return(NA_integer_)
    close_rx <- paste0("^ {0,3}\\", ch[i], "{", len, ",}\\s*$")
    s <- e + 1L
    while (s <= n) {
      e2 <- nl[nl >= s]; e2 <- if (length(e2)) e2[1] else n + 1L
      if (grepl(close_rx, slice(s, e2 - 1L))) return(min(e2, n))
      s <- e2 + 1L
    }
    n
  }
  tick_end <- function(i) {                            # code span starting at i? -> last index or NA
    k <- i; while (k <= n && ch[k] == "`") k <- k + 1L
    len <- k - i; j <- k
    while (TRUE) {
      b <- which(ch[j:n] == "`"); if (!length(b)) return(NA_integer_)
      s <- j + b[1] - 1L; e <- s; while (e <= n && ch[e] == "`") e <- e + 1L
      if (e - s == len) return(e - 1L)
      j <- e; if (j > n) return(NA_integer_)
    }
  }
  math_end <- function(i) {                            # $..$ or $$..$$ starting at i? -> last index or NA
    if (i < n && ch[i + 1L] == "$") {
      j <- i + 2L
      while (j < n) { if (ch[j] == "\\") j <- j + 2L else if (ch[j] == "$" && ch[j + 1L] == "$") return(j + 1L) else j <- j + 1L }
      return(NA_integer_)
    }
    if (i >= n || ch[i + 1L] %in% c(" ", "\t", "\n")) return(NA_integer_)
    j <- i + 1L
    while (j <= n) {
      if (ch[j] == "\\") { j <- j + 2L; next }
      if (ch[j] == "$") {
        if (!(ch[j - 1L] %in% c(" ", "\t", "\n")) && !(j < n && grepl("[0-9]", ch[j + 1L]))) return(j)
        return(NA_integer_)
      }
      j <- j + 1L
    }
    NA_integer_
  }
  is_bar <- function(i) i <= n && (ch[i] == "|" || (ch[i] == "\\" && i < n && ch[i + 1L] == "|"))
  is_hash <- function(i) i <= n && (ch[i] == "#" || (ch[i] == "\\" && i < n && ch[i + 1L] == "#"))
  tok_len <- function(i) if (ch[i] == "\\") 2L else 1L

  parse_seq <- function(depth) {
    nodes <- list(); run <- st$i
    flush <- function(upto) {
      if (upto >= run) nodes[[length(nodes) + 1L]] <<- list(t = "text", s = slice(run, upto))
    }
    lit <- function(a, b) {                           # literal region a..b (placeholders restored)
      flush(a - 1L); nodes[[length(nodes) + 1L]] <<- list(t = "text", s = unpark(slice(a, b)))
      run <<- b + 1L; st$i <- b + 1L
    }
    repeat {
      i <- nxt(st$i)
      if (i > n) { flush(n); st$i <- n + 1L; return(list(nodes = nodes, closed = FALSE)) }
      c0 <- ch[i]
      if (c0 == "\\") {
        if (depth > 0L && i < n && ch[i + 1L] %in% c("|", "#")) {
          kind <- if (ch[i + 1L] == "|") "bar" else "hash"; chk <- if (kind == "bar") is_bar else is_hash
          flush(i - 1L); l1 <- 2L; j <- i + 2L
          if (chk(j)) { l2 <- tok_len(j); nodes[[length(nodes) + 1L]] <- list(t = paste0("lit", kind), s = slice(i, j + l2 - 1L), pos = i); j <- j + l2 }
          else nodes[[length(nodes) + 1L]] <- list(t = kind, s = slice(i, i + 1L), pos = i)
          run <- j; st$i <- j
        } else st$i <- i + 2L
      } else if (c0 %in% c("|", "#") && depth > 0L) {
        kind <- if (c0 == "|") "bar" else "hash"; chk <- if (kind == "bar") is_bar else is_hash
        flush(i - 1L); j <- i + 1L
        if (chk(j)) { l2 <- tok_len(j); nodes[[length(nodes) + 1L]] <- list(t = paste0("lit", kind), s = slice(i, j + l2 - 1L), pos = i); j <- j + l2 }
        else nodes[[length(nodes) + 1L]] <- list(t = kind, s = c0, pos = i)
        run <- j; st$i <- j
      } else if (c0 == O) {
        flush(i - 1L); j <- i + 1L; while (j <= n && ch[j] != C) j <- j + 1L
        idx <- as.integer(slice(i + 1L, j - 1L)); j <- j + 1L
        a <- NULL
        if (j <= n && ch[j] == "{") { r <- clag_attr(ch, j); if (!is.null(r)) { a <- r$a; j <- r$end + 1L } }
        nodes[[length(nodes) + 1L]] <- list(t = "val", idx = idx, attrs = a, pos = i)
        run <- j; st$i <- j
      } else if (c0 == "`") {
        fe <- fence_end(i)
        if (!is.na(fe)) lit(i, fe) else { te <- tick_end(i); if (!is.na(te)) lit(i, te) else { k <- i; while (k <= n && ch[k] == "`") k <- k + 1L; st$i <- k } }
      } else if (c0 == "~") {
        fe <- fence_end(i); if (!is.na(fe)) lit(i, fe) else st$i <- i + 1L
      } else if (c0 == "$") {
        me <- math_end(i); if (!is.na(me)) lit(i, me) else st$i <- i + (if (i < n && ch[i + 1L] == "$") 2L else 1L)
      } else if (c0 == "<") {
        if (slice(i, i + 3L) == "<!--") {
          e <- i + 4L; while (e + 2L <= n && slice(e, e + 2L) != "-->") e <- e + 1L
          if (e + 2L <= n) lit(i, e + 2L) else st$i <- i + 1L
        } else st$i <- i + 1L
      } else if (c0 == "[") {
        flush(i - 1L); st$i <- i + 1L
        inner <- parse_seq(depth + 1L)
        if (!inner$closed) {                          # unmatched "[": literal, keep what was parsed
          nodes[[length(nodes) + 1L]] <- list(t = "text", s = "[")
          nodes <- c(nodes, inner$nodes); return(list(nodes = nodes, closed = FALSE))
        }
        close <- st$i; j <- close + 1L; a <- NULL; tail_end <- close
        if (j <= n && ch[j] == "(") {                  # link / image target: balanced parens
          d <- 0L; k <- j
          while (k <= n) { if (ch[k] == "\\") k <- k + 1L else if (ch[k] == "(") d <- d + 1L else if (ch[k] == ")") { d <- d - 1L; if (d == 0L) break }; k <- k + 1L }
          if (k <= n) tail_end <- k
        } else if (j <= n && ch[j] == "{") {
          r <- clag_attr(ch, j); if (!is.null(r)) { a <- r$a; tail_end <- r$end }
        }
        nodes[[length(nodes) + 1L]] <- list(t = "br", kids = inner$nodes, attrs = a, pos = i,
                                            src = slice(i, tail_end), phrase = unpark(slice(i + 1L, close - 1L)),
                                            tail = slice(close, tail_end))
        run <- tail_end + 1L; st$i <- tail_end + 1L
      } else if (c0 == "]" && depth > 0L) {
        flush(i - 1L); st$i <- i; return(list(nodes = nodes, closed = TRUE))
      } else st$i <- i + 1L
    }
  }
  list(nodes = parse_seq(0L)$nodes, nl = nl)
}

## ---- value formatting ------------------------------------------------------
clag_known <- c("num", "no", "word", "pct", "dec1", "or", "ul", "strong", "em")
clag_words <- c("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve")

stock1 <- function(res) {                          # what stock knitr prints for one inline value
  if (inherits(res, c("knit_asis", "knit_asis_url"))) res <- knitr::sew(res, inline = TRUE)
  invisible(tryCatch(as.character(res), error = function(e) stop("The inline value cannot be coerced to character")))
  if (length(res)) paste(knitr::knit_hooks$get("inline")(res), collapse = "") else ""
}
base_text <- function(val) {
  if (is.character(val)) return(val)
  if (is.null(val)) return(character())
  vapply(seq_along(val), function(k) stock1(val[k]), "")
}
fmt_value <- function(val, classes, sep, fail) {
  bad <- setdiff(classes, clag_known)
  if (length(bad)) fail(paste0("unknown class .", bad[1], " (known: ", paste0(".", clag_known, collapse = " "), ")"))
  need_num <- function(f) if (!is.numeric(val)) fail(paste0("class .", f, " needs a number, got ", class(val)[1]))
  txt <- NULL; coll <- NULL; styles <- character()
  for (f in classes) switch(f,
    num  = { need_num(f); txt <- format(round(val), trim = TRUE, scientific = FALSE) },
    dec1 = { need_num(f); txt <- formatC(val, format = "f", digits = 1) },
    pct  = { need_num(f); txt <- paste0(format(round(100 * val), trim = TRUE, scientific = FALSE), "%") },
    no   = { txt <- txt %||% base_text(val); txt[txt == "0"] <- "no" },
    word = { txt <- txt %||% base_text(val); k <- grepl("^[0-9]+$", txt) & suppressWarnings(as.integer(txt)) <= 12
             txt[k] <- clag_words[as.integer(txt[k]) + 1L] },
    or = coll <- "or", ul = coll <- "ul", strong = styles <- c(styles, f), em = styles <- c(styles, f))
  txt <- txt %||% base_text(val)
  block <- FALSE
  if (identical(coll, "ul")) { txt <- paste0("\n\n", paste0("- ", txt, collapse = "\n"), "\n\n"); block <- TRUE }
  else if (identical(coll, "or")) {
    s <- sep %||% ", "; m <- length(txt)
    txt <- if (m <= 1L) txt else if (m == 2L) paste(txt, collapse = " or ") else paste0(paste(txt[-m], collapse = s), " or ", txt[m])
  } else if (length(txt) > 1L || !is.null(sep)) txt <- paste(txt, collapse = sep %||% ", ")
  sel <- paste(txt, collapse = "")
  shown <- sel
  for (s in styles) shown <- paste0("[", shown, "]{.", s, "}")
  list(raw = val, sel = sel, shown = shown, block = block)
}

## ---- rendering the AST (lazy) ----------------------------------------------
clag_text <- function(x) {
  txt <- enc2utf8(paste(x, collapse = "\n"))
  if (!grepl(clag$O, txt, fixed = TRUE) && !grepl("[", txt, fixed = TRUE)) return(txt)  # nothing to do
  p <- clag_parse(txt)
  ctx <- list(in_arm = FALSE, gov = NULL, loc = if (!is.null(clag$where)) { w <- clag$where; function(pos) w } else clag_locator(p$nl))
  render_nodes(p$nodes, ctx)
}

fail_at <- function(ctx, pos, ...) stop("clag: ", ctx$loc(pos), ": ", ..., call. = FALSE)
env_eval <- function(code, ctx, pos, extra = NULL) {
  tryCatch(eval(parse(text = code), extra, knitr::knit_global()),
           error = function(e) fail_at(ctx, pos, "error evaluating `", code, "`: ", conditionMessage(e)))
}
run_claims <- function(strs, val, ctx, pos, what, have_val = TRUE) {
  for (s in strs) {
    exprs <- tryCatch(as.list(parse(text = paste0("list(", s, ")"))[[1]])[-1],
                      error = function(e) fail_at(ctx, pos, "cannot parse claim \"", s, "\" on ", what, ": ", conditionMessage(e)))
    for (e in exprs) {
      r <- tryCatch(eval(e, if (have_val) list(. = val), knitr::knit_global()),
                    error = function(err) fail_at(ctx, pos, "error in claim ", deparse1(e), " on ", what, ": ", conditionMessage(err)))
      if (!isTRUE(r)) fail_at(ctx, pos, "claim failed: ", deparse1(e), " on ", what,
                              if (have_val) paste0(" (. = ", paste(format(val), collapse = ", "), ")"))
    }
  }
}
get_all <- function(a, key) if (is.null(a)) character() else a$vals[a$keys == key]

render_nodes <- function(nodes, ctx) {
  out <- character(length(nodes))
  for (k in seq_along(nodes)) {
    nd <- nodes[[k]]
    out[k] <- switch(nd$t,
      text = nd$s,
      bar = nd$s,
      litbar = if (ctx$in_arm) "|" else nd$s,
      hash = if (ctx$in_arm) (if (is.null(ctx$gov)) "#" else ctx$gov$shown) else nd$s,
      lithash = if (ctx$in_arm) "#" else nd$s,
      val = render_value(nd, ctx),
      br = render_br(nd, ctx))
  }
  paste(out, collapse = "")
}

render_value <- function(nd, ctx) {
  code <- clag$pend[[nd$idx]]; a <- nd$attrs
  what <- paste0("`r ", code, "`")
  if (is.null(a) || (!length(a$cls) && !length(a$keys))) {                 # bare: exactly stock knitr
    return(stock1(tryCatch(clag$stock_eval(code, knitr::knit_global()),       # knitr's own default: withVisible + knit_print
                           error = function(e) fail_at(ctx, nd$pos, "error evaluating `", code, "`: ", conditionMessage(e)))))
  }
  bad_keys <- setdiff(a$keys, c("claim", "sep"))
  if (length(bad_keys)) fail_at(ctx, nd$pos, "unknown attribute ", bad_keys[1], " on ", what)
  bad <- setdiff(a$cls, clag_known)
  if (length(bad)) fail_at(ctx, nd$pos, "unknown class .", bad[1], " on ", what)
  val <- env_eval(code, ctx, nd$pos)
  run_claims(get_all(a, "claim"), val, ctx, nd$pos, what)                  # claims see the RAW value
  sep <- get_all(a, "sep"); sep <- if (length(sep)) sep[1]
  r <- fmt_value(val, a$cls, sep, function(m) fail_at(ctx, nd$pos, m, " on ", what))
  r$shown
}

render_br <- function(nd, ctx) {
  a <- nd$attrs
  gov_keys <- intersect(a$keys, c("n", "if", "claim"))
  if (is.null(a) || !length(gov_keys)) {                                   # ordinary bracket: flat, children still live
    return(paste0("[", render_nodes(nd$kids, ctx), clag_expand_tail(nd$tail, ctx)))
  }
  pos <- nd$pos; what <- paste0("[", nd$phrase, "]")
  has_n <- "n" %in% a$keys; has_if <- "if" %in% a$keys
  if (has_n && has_if) fail_at(ctx, pos, "only one of n and if may govern ", what)
  arms <- list(); cur <- list()                                           # split on bar nodes of THIS bracket only
  for (k in nd$kids) if (k$t == "bar") { arms[[length(arms) + 1L]] <- cur; cur <- list() } else cur[[length(cur) + 1L]] <- k
  arms[[length(arms) + 1L]] <- cur
  m <- length(arms)
  if (has_n && m > 3L) fail_at(ctx, pos, "n takes at most 3 arms, found ", m, " in ", what)
  if (has_if && m != 2L) fail_at(ctx, pos, "if needs exactly 2 arms (true | false), found ", m, " in ", what)
  if (!has_n && !has_if && m > 1L) fail_at(ctx, pos, "claim alone takes 1 arm (the guarded phrase), found ", m, " in ", what)
  bad <- setdiff(a$cls, clag_known)
  if (length(bad)) fail_at(ctx, pos, "unknown class .", bad[1], " on ", what)
  claims <- get_all(a, "claim"); gov <- ctx$gov; idx <- 1L
  if (has_n) {
    expr <- get_all(a, "n")[1]
    raw <- if (trimws(expr) == ".") {
      if (is.null(ctx$gov)) fail_at(ctx, pos, "n=\".\" has no enclosing span to inherit from, in ", what)
      ctx$gov$raw
    } else env_eval(expr, ctx, pos)
    if (!is.numeric(raw) || length(raw) != 1L || is.na(raw))
      fail_at(ctx, pos, "n must evaluate to a single number, but `", expr, "` gave ",
              if (length(raw) != 1L) paste0("length ", length(raw), "; to count a vector write length(", expr, ")") else paste(class(raw), collapse = "/"),
              " in ", what)
    run_claims(claims, raw, ctx, pos, what)
    sep <- get_all(a, "sep")
    gov <- if (trimws(expr) == "." && !length(a$cls)) ctx$gov                # plain inherit: same printed text
           else fmt_value(raw, a$cls, if (length(sep)) sep[1], function(msg) fail_at(ctx, pos, msg, " on ", what))
    s <- gov$sel
    idx <- if (m == 1L) 1L else if (m == 2L) { if (s %in% c("1", "one")) 1L else 2L }
           else { if (s %in% c("0", "no", "zero")) 1L else if (s %in% c("1", "one")) 2L else 3L }
  } else if (has_if) {
    cond <- env_eval(get_all(a, "if")[1], ctx, pos)
    if (!is.logical(cond) || length(cond) != 1L || is.na(cond))
      fail_at(ctx, pos, "if must evaluate to a single TRUE or FALSE in ", what)
    run_claims(claims, cond, ctx, pos, what)
    idx <- if (cond) 1L else 2L
  } else run_claims(claims, NULL, ctx, pos, what, have_val = FALSE)        # phrase guard
  ctx2 <- list(in_arm = TRUE, gov = gov, loc = ctx$loc)
  trimws(render_nodes(arms[[idx]], ctx2))                                  # ONLY the chosen arm is rendered
}

clag_expand_tail <- function(tail, ctx) {                                  # values inside "](url)" are bare-evaluated
  if (!grepl(clag$O, tail, fixed = TRUE)) return(tail)
  m <- gregexpr(paste0(clag$O, "[0-9]+", clag$C), tail)
  regmatches(tail, m) <- lapply(regmatches(tail, m), function(p) vapply(p, function(q) {
    code <- clag$pend[[as.integer(gsub(paste0("[", clag$O, clag$C, "]"), "", q))]]
    stock1(clag$stock_eval(code, knitr::knit_global())) }, ""))
  tail
}
