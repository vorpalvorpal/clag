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
  clag$pend <- list(); clag$bibkeys <- NULL; clag$fails <- list(); clag$ids <- list(); clag$lang <- NULL; clag$collecting <- FALSE
  clag$here <- NULL; clag$formatters <- clag$formatters %||% list()
  if (is.null(clag$stock_eval)) clag$stock_eval <- knitr::knit_hooks$get("evaluate.inline", default = TRUE)
  knitr::knit_hooks$set(
    evaluate.inline = function(code, envir) {
      clag$pend[[length(clag$pend) + 1L]] <- code            # parked, NOT run
      paste0(clag$O, length(clag$pend), clag$C)
    },
    text = function(x) clag_text(x),
    document = function(x) { clag_report(); x })
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
clag_attr_err <- function(msg, pos) stop(structure(class = c("clag_attr_err", "error", "condition"), list(message = msg, call = NULL, pos = pos)))
clag_attr <- function(ch, i) {                        # ch[i] == "{"; returns list(a, end)
  ## SPIKE CHANGE: values are double-quoted or unquoted ONLY. A `"` or `\` inside a value, or a single-quoted value,
  ## is an error (raised as a clag_attr_err carrying the position; clag_text adds file:line).
  n <- length(ch); j <- i + 1L
  cls <- character(); id <- character(); keys <- character(); vals <- character(); ks <- integer(); ke <- integer()
  repeat {
    while (j <= n && ch[j] %in% c(" ", "\t", "\n")) j <- j + 1L
    if (j > n) return(NULL)
    if (ch[j] == "}") return(list(a = list(cls = cls, id = id, keys = keys, vals = vals, ks = ks, ke = ke), end = j))
    if (ch[j] %in% c(".", "#")) {
      k <- j + 1L; s <- k
      while (k <= n && grepl("[A-Za-z0-9_:-]", ch[k])) k <- k + 1L
      if (k == s) return(NULL)
      w <- paste(ch[s:(k - 1L)], collapse = "")
      if (ch[j] == ".") cls <- c(cls, w) else id <- c(id, w)
      j <- k
    } else if (grepl("[A-Za-z_]", ch[j])) {
      k0 <- j; k <- j
      while (k <= n && grepl("[A-Za-z0-9_:.-]", ch[k])) k <- k + 1L
      key <- paste(ch[j:(k - 1L)], collapse = "")
      if (k > n || ch[k] != "=") return(NULL)
      k <- k + 1L
      if (k > n) return(NULL)
      if (ch[k] == "'") clag_attr_err(paste0("attribute ", key, ": single-quoted values are not allowed; use double quotes"), k)
      if (ch[k] == "\"") {
        k <- k + 1L; buf <- character()
        repeat {
          if (k > n) return(NULL)
          if (ch[k] == "\\") clag_attr_err(paste0("attribute ", key, ": a backslash inside a value is not allowed"), k)
          if (ch[k] == "\"") break
          buf <- c(buf, ch[k]); k <- k + 1L
        }
        k <- k + 1L; val <- paste(buf, collapse = "")
      } else {
        s <- k
        while (k <= n && !(ch[k] %in% c(" ", "\t", "\n", "}"))) {
          if (ch[k] %in% c("\"", "\\")) clag_attr_err(paste0("attribute ", key, ": a `", ch[k], "` inside an unquoted value is not allowed"), k)
          k <- k + 1L }
        val <- paste(ch[s:(k - 1L)], collapse = "")
      }
      keys <- c(keys, key); vals <- c(vals, val); ks <- c(ks, k0); ke <- c(ke, k - 1L); j <- k
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
    litf <- function(a, b) {                          # NON-EXECUTED fence: values inside evaluate as stock knitr, nothing else changes
      flush(a - 1L); nodes[[length(nodes) + 1L]] <<- list(t = "fence", s = slice(a, b), pos = a)
      run <<- b + 1L; st$i <- b + 1L
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
        if (!is.na(fe)) litf(i, fe) else { te <- tick_end(i); if (!is.na(te)) lit(i, te) else { k <- i; while (k <= n && ch[k] == "`") k <- k + 1L; st$i <- k } }
      } else if (c0 == "~") {
        fe <- fence_end(i); if (!is.na(fe)) litf(i, fe) else st$i <- i + 1L
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
          else {                                        # SPIKE: `]{` that is not a well-formed attribute block but looks like one
            e <- nl[nl >= j]; e <- if (length(e)) e[1] - 1L else n; look <- slice(j, e)
            if (grepl("^\\{[^}]*[A-Za-z_][A-Za-z0-9_.:-]*=", look)) clag_attr_err("malformed attribute block after ']' (a double quote inside a value ends it early?)", j)
          }
        }
        nodes[[length(nodes) + 1L]] <- list(t = "br", kids = inner$nodes, attrs = a, pos = i,
                                            src = slice(i, tail_end), phrase = unpark(slice(i + 1L, close - 1L)),
                                            tail = slice(close, tail_end), tail_off = close)
        run <- tail_end + 1L; st$i <- tail_end + 1L
      } else if (c0 == "]" && depth > 0L) {
        flush(i - 1L); st$i <- i; return(list(nodes = nodes, closed = TRUE))
      } else st$i <- i + 1L
    }
  }
  list(nodes = parse_seq(0L)$nodes, nl = nl)
}


## ---- vocabulary --------------------------------------------------------------
clag_fmts  <- c("num", "pct", "sci", "word", "count", "ord", "no", "p", "range", "date", "and", "or", "pairs", "ul", "ol", "dl",
                "dec1")                     # dec1 is a stand-in extra (one decimal) so decimals-shown cases can be written
clag_texts <- c("cap", "a", "strong", "em")
clag_wkeys <- c("n", "if", "sign", "sep", "last", "trunc", "cite")
clag_words <- c("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve")
clag$digits <- 0L
MARK <- "[CLAIM FAILED]"
all_fmts <- function() c(clag_fmts, names(clag$formatters))
clag_register <- function(name, fn) { clag$formatters[[name]] <- fn; invisible(name) }  # fn(x) -> list(text, num, dec, rel)

near1 <- function(a, b) {                       # within one edit (insert/delete/substitute/adjacent swap)
  if (a == b) return(FALSE)
  if (drop(utils::adist(a, b)) <= 1) return(TRUE)
  ca <- strsplit(a, "")[[1]]; cb <- strsplit(b, "")[[1]]
  if (length(ca) == length(cb)) { d <- which(ca != cb)
    if (length(d) == 2L && d[2] == d[1] + 1L && ca[d[1]] == cb[d[2]] && ca[d[2]] == cb[d[1]]) return(TRUE) }
  FALSE
}
## a typo guard only for names of 3+ letters: one edit from ".no" or ".a" would catch half the alphabet
near_name <- function(cl) {
  cand <- c(all_fmts(), clag_texts); cand <- cand[nchar(cand) >= 3L]
  cand[vapply(cand, near1, NA, b = cl)]
}

## ---- claim() -----------------------------------------------------------------
clag$fails <- list(); clag$collecting <- FALSE; clag$here <- NULL; clag$ids <- list(); clag$formatters <- list()
clag_collect <- function(expr, detail) {
  h <- clag$here
  clag$fails[[length(clag$fails) + 1L]] <- list(where = if (!is.null(h)) h$loc(h$pos) else "<unknown>",
                                                what = if (!is.null(h)) h$what else "", expr = expr, detail = detail)
  invisible(NULL)
}
shortv <- function(x) { s <- paste(format(x), collapse = ", "); if (nchar(s) > 60) paste0(substr(s, 1, 57), "...") else s }
claim <- function(x, ...) {
  exprs <- as.list(substitute(list(...)))[-1]
  env <- parent.frame()
  for (e in exprs) {
    ee <- paste(deparse(e, width.cutoff = 500L), collapse = " ")
    r <- tryCatch(eval(e, list(. = x), env), error = function(err) structure(conditionMessage(err), class = "claim_err"))
    if (!(is.logical(r) && length(r) == 1L && !is.na(r) && r)) {
      detail <- if (inherits(r, "claim_err")) paste0("error in check: ", r)
                else if (is.logical(r) && length(r) == 1L && !is.na(r)) paste0(ee, " was FALSE (value ", shortv(x), ")")
                else paste0(ee, " did not give a single TRUE (gave ", shortv(r), "; value ", shortv(x), ")")
      if (isTRUE(clag$collecting)) clag_collect(ee, detail) else stop("claim failed: ", detail, call. = FALSE)
    }
  }
  x
}
clag_report <- function() {
  f <- clag$fails; if (!length(f)) return(invisible())
  clag$fails <- list()
  msg <- paste0("clag: ", length(f), " claim", if (length(f) != 1L) "s", " failed\n",
                paste0("  ", vapply(f, `[[`, "", "where"), "  ", vapply(f, `[[`, "", "what"), "\n      ",
                       vapply(f, `[[`, "", "detail"), collapse = "\n"),
                "\nRead each sentence. If FALSE is right, rewrite the sentence. Do not loosen a claim to clear this.")
  if (isTRUE(getOption("clag.draft"))) message(msg) else stop(msg, call. = FALSE)
}

## ---- printed-number records and formatters ---------------------------------------------
stock1 <- function(res) {                          # what stock knitr prints for one inline value
  if (inherits(res, c("knit_asis", "knit_asis_url"))) res <- knitr::sew(res, inline = TRUE)
  invisible(tryCatch(as.character(res), error = function(e) stop("The inline value cannot be coerced to character")))
  if (length(res)) paste(knitr::knit_hooks$get("inline")(res), collapse = "") else ""
}
base_text <- function(val) {
  if (is.character(val)) return(unname(val))
  if (is.null(val)) return(character())
  vapply(seq_along(val), function(k) stock1(val[k]), "")
}
parse_printed <- function(t) {
  t <- trimws(t)
  if (!grepl("^[-−+]?[0-9][0-9,]*(\\.[0-9]+)?$", t)) return(list(num = NA_real_, dec = FALSE))
  list(num = as.numeric(gsub(",", "", sub("−", "-", t))), dec = grepl(".", t, fixed = TRUE))
}
init_state <- function(val) {
  txt <- base_text(val); n <- length(txt)
  num <- rep(NA_real_, n); dec <- rep(FALSE, n)
  if (is.numeric(val)) for (k in seq_len(n)) { p <- parse_printed(txt[k]); num[k] <- p$num; dec[k] <- p$dec }
  list(v = val, txt = txt, num = num, dec = dec, rel = rep("=", n), nms = names(val), coll = "")
}
fmt_num <- function(x, d) format(round(x, d), nsmall = d, trim = TRUE, scientific = FALSE, big.mark = "")
ordinal <- function(k) {
  s <- ifelse(k %% 100L %in% 11:13, "th", c("th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th")[k %% 10L + 1L])
  paste0(k, s)
}
run_chain <- function(val, fm, a, fail) {
  S <- init_state(val)
  need_num <- function(f) if (!is.numeric(S$v)) fail(paste0("class .", f, " needs a number, got ", class(S$v)[1]))
  digits <- function(f, d, scale = 1, suffix = "") {
    need_num(f); x <- scale * S$v; S$txt <<- paste0(fmt_num(x, d), suffix)
    S$num <<- round(x, d); S$dec <<- rep(d > 0L, length(x)); S$rel <<- rep("=", length(x))
  }
  for (f in fm) {
    if (!is.null(clag$formatters[[f]])) {
      rs <- lapply(seq_along(S$v), function(k) clag$formatters[[f]](S$v[[k]]))
      S$txt <- vapply(rs, `[[`, "", "text"); S$num <- vapply(rs, function(r) as.numeric(r$num %||% NA), 0)
      S$dec <- vapply(rs, function(r) isTRUE(r$dec), NA); S$rel <- vapply(rs, function(r) r$rel %||% "=", "")
      next
    }
    switch(f,
      num = digits(f, clag$digits), dec1 = digits(f, 1L), pct = digits(f, clag$digits, 100, "%"),
      sci = { need_num(f); S$txt <- formatC(S$v, format = "e", digits = 2); S$num <- S$v; S$dec <- rep(TRUE, length(S$v)) },
      word = { idx <- suppressWarnings(as.integer(S$txt)); k <- grepl("^[0-9]+$", S$txt) & !is.na(idx) & idx <= 12L
               S$txt[k] <- clag_words[idx[k] + 1L] },
      count = { idx <- suppressWarnings(as.integer(S$txt)); k <- grepl("^[0-9]+$", S$txt) & !is.na(idx) & idx <= 9L
                S$txt[k] <- clag_words[idx[k] + 1L] },
      ord = { idx <- suppressWarnings(as.integer(S$txt)); k <- grepl("^[0-9]+$", S$txt) & !is.na(idx); S$txt[k] <- ordinal(idx[k]) },
      no = S$txt[S$txt == "0"] <- "no",
      p = { need_num(f)
            lt <- S$v < 0.001; S$txt <- ifelse(lt, "p < 0.001", paste0("p = ", formatC(S$v, format = "f", digits = 3)))
            S$num <- ifelse(lt, 0.001, round(S$v, 3)); S$dec <- rep(TRUE, length(S$v)); S$rel <- ifelse(lt, "<", "=") },
      date = { if (!inherits(S$v, "Date")) fail("class .date needs a Date")
               S$txt <- sub("^0", "", format(S$v, "%d %B %Y")); S$num <- rep(NA_real_, length(S$v)) },
      range = { if (!is.numeric(S$v) || length(S$v) != 2L) fail("class .range needs a length-2 number")
                tx <- S$txt
                if (tx[1] == tx[2]) { S$txt <- tx[1]; S$num <- S$num[1]; S$dec <- S$dec[1]; S$rel <- S$rel[1] }
                else { neg <- any(S$num < 0, na.rm = TRUE) || any(grepl("^[-−]", tx)); m <- sub("^-", "−", tx)
                       S$txt <- if (neg) paste(m[1], "to", m[2]) else paste0(m[1], "–", m[2])
                       S$num <- NA_real_; S$dec <- FALSE; S$rel <- "=" }
                S$nms <- NULL },
      and = , or = , pairs = , ul = , ol = , dl = S$coll <- f,
      NULL)
  }
  sep <- get1(a, "sep"); last <- get1(a, "last"); tr <- get1(a, "trunc"); txt <- S$txt; block <- FALSE
  if (identical(S$coll, "pairs")) {
    if (is.null(S$nms)) fail("class .pairs needs a named vector")
    txt <- paste0(S$nms, " (", txt, ")")
  }
  if (S$coll %in% c("and", "or", "pairs")) {
    conj <- last %||% (if (identical(S$coll, "or")) " or " else " and "); s <- sep %||% ", "; m <- length(txt)
    if (!is.null(tr) && m > as.integer(tr)) { r <- m - as.integer(tr)
      txt <- paste0(paste(txt[seq_len(as.integer(tr))], collapse = s), conj, r, " other", if (r > 1L) "s") }
    else txt <- if (m <= 1L) txt else if (m == 2L) paste0(txt[1], conj, txt[2]) else paste0(paste(txt[-m], collapse = s), conj, txt[m])
  } else if (S$coll %in% c("ul", "ol")) {
    txt <- paste0("\n\n", paste0(if (S$coll == "ul") "- " else paste0(seq_along(txt), ". "), txt, collapse = "\n"), "\n\n"); block <- TRUE
  } else if (identical(S$coll, "dl")) {
    nm <- S$nms %||% rep("", length(txt)); txt <- paste0("\n\n", paste0(nm, "\n:   ", txt, collapse = "\n\n"), "\n\n"); block <- TRUE
  } else if (length(txt) > 1L || !is.null(sep)) txt <- paste(txt, collapse = sep %||% ", ")
  one <- length(S$txt) == 1L
  list(text = paste(txt, collapse = ""), num = if (one) S$num[1] else NA_real_, dec = if (one) S$dec[1] else FALSE,
       rel = if (one) S$rel[1] else "=", block = block)
}

## ---- text classes, pass-through -------------------------------------------------------------
add_article <- function(t) {
  if (!nzchar(t)) return(t)
  core <- sub("^[*_\\[(\"']+", "", t)
  d <- sub("^([0-9][0-9,]*).*$", "\\1", core); an <- FALSE
  if (grepl("^[0-9]", core)) { d <- gsub(",", "", d)
    an <- substr(d, 1, 1) == "8" || (substr(d, 1, 2) %in% c("11", "18") && nchar(d) %% 3L == 2L)
  } else {
    w <- tolower(sub("^([A-Za-z]+).*$", "\\1", core))
    an <- (grepl("^[aeiou]", w) && !grepl("^(uni|use|usu|eu|one|once|ubi)", w)) || grepl("^(hour|honest|honou?r|heir)", w)
  }
  paste0(if (an) "an " else "a ", t)
}
attr_string <- function(a, cls, keys) {
  kv <- vapply(keys, function(k) paste0(k, "=\"", gsub("\"", "\\\\\"", a$vals[a$keys == k][1]), "\""), "")
  paste(c(if (length(a$id)) paste0("#", a$id), if (length(cls)) paste0(".", cls), kv), collapse = " ")
}
finish_text <- function(text, a, block = FALSE) {
  if (block || !nzchar(text)) return(text)
  cls <- a$cls
  if ("a" %in% cls) text <- add_article(text)
  if ("cap" %in% cls) text <- sub("^([*_\\[(\"']*)([[:alpha:]])", "\\1\\U\\2", text, perl = TRUE)
  if ("strong" %in% cls) text <- paste0("**", text, "**")
  if ("em" %in% cls) text <- paste0("*", text, "*")
  pc <- setdiff(cls, c(all_fmts(), clag_texts)); pk <- setdiff(a$keys, clag_wkeys)
  if (length(pc) || length(pk) || length(a$id)) text <- paste0("[", text, "]{", attr_string(a, pc, pk), "}")
  text
}

## ---- rendering the AST (lazy) ----------------------------------------------
clag_text <- function(x) {
  txt <- enc2utf8(paste(x, collapse = "\n"))
  if (!grepl(clag$O, txt, fixed = TRUE) && !grepl("[", txt, fixed = TRUE) && !grepl(":::", txt, fixed = TRUE)) return(txt)  # nothing to do
  clag$collecting <- TRUE; on.exit(clag$collecting <- FALSE)
  wrap <- function(expr, t) { loc0 <- clag_locator(which(strsplit(t, "")[[1]] == "\n"))
    tryCatch(expr, clag_attr_err = function(e) stop("clag: ", loc0(e$pos), ": ", conditionMessage(e), call. = FALSE)) }
  txt <- wrap(strip_why_divs(txt), txt)                  # SPIKE: marked-literal divs
  p <- wrap(clag_parse(txt), txt)
  ctx <- list(in_arm = FALSE, gov = NULL, loc = clag_locator(p$nl), scope = clag_scoper(txt))
  render_nodes(p$nodes, ctx)
}

## ---- SPIKE: marked literals (construct 2) --------------------------------------
## Block form: the OPENING fence line `::: {.weft-literal why="..."}` is rewritten without `why`. Done line by line on the
## text block, so it does not matter where the closing fence is (another text block, nested div, list, block quote).
strip_why_divs <- function(txt) {
  if (!grepl("why", txt, fixed = TRUE)) return(txt)
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]; infence <- FALSE; fence <- ""
  lst <- cumsum(c(1L, nchar(lines, "chars") + 1L))
  for (k in seq_along(lines)) {
    ln <- lines[k]
    if (grepl("^\\s*(>\\s*)*(```+|~~~+)", ln)) {                 # skip non-executed code fences
      f <- sub("^\\s*(>\\s*)*((```+|~~~+)).*$", "\\2", ln)
      if (!infence) { infence <- TRUE; fence <- substr(f, 1, 1) } else if (substr(f, 1, 1) == fence) infence <- FALSE
      next
    }
    if (infence) next
    m <- regexec("^(\\s*(?:>\\s*)*:{3,}\\s*)(\\{.*)$", ln, perl = TRUE)[[1]]
    if (m[1] == -1L) next
    pre <- substr(ln, m[2], m[2] + attr(m, "match.length")[2] - 1L)
    rest <- substr(ln, m[3], nchar(ln))
    ch <- strsplit(rest, "")[[1]]
    r <- tryCatch(clag_attr(ch, 1L), clag_attr_err = function(e) { e$pos <- lst[k] + (m[3] - 1L) + e$pos - 1L; stop(e) })
    if (is.null(r) || !("why" %in% r$a$keys) || !("weft-literal" %in% r$a$cls)) next
    if (length(ch) > r$end && any(ch[(r$end + 1L):length(ch)] != " ")) next   # trailing junk: not a div fence
    lines[k] <- paste0(pre, cut_key(ch, r$a, "why"))
  }
  paste(lines, collapse = "\n")
}
## remove `key="..."` (and one adjacent space) from the attribute block text ch (ch[1] == "{")
cut_key <- function(ch, a, key, shift = 0L) {
  w <- which(a$keys == key); drop <- integer()
  for (k in w) { s0 <- a$ks[k] - shift; e0 <- a$ke[k] - shift
    while (s0 > 1L && ch[s0 - 1L] %in% c(" ", "\t")) s0 <- s0 - 1L; drop <- c(drop, s0:e0) }
  out <- paste(ch[-drop], collapse = "")
  sub("^\\{\\s+", "{", out)
}

## ---- SPIKE: "the paragraph" for the bare-key check -------------------------------
## A unit starts at: a blank line (ends the previous one), an ATX heading, a list marker, a `[^id]:` footnote definition,
## a pipe-table row, a `:::` fence line. Block-quote `>` prefixes are ignored. A `^[...]` inline note is a scope of its own.
unit_start_rx <- "^\\s{0,}(>\\s*)*(#{1,6}\\s|[-*+]\\s|[0-9]+[.)]\\s|\\[\\^[^]]+\\]:|\\||:{3,})"
drop_notes <- function(seg) {
  ch <- strsplit(seg, "")[[1]]; keep <- rep(TRUE, length(ch)); i <- 1L
  while (i < length(ch)) {
    if (ch[i] == "\\") { i <- i + 2L; next }
    if (ch[i] == "^" && ch[i + 1L] == "[") { d <- 0L; j <- i + 1L
      while (j <= length(ch)) { if (ch[j] == "\\") j <- j + 1L else if (ch[j] == "[") d <- d + 1L else if (ch[j] == "]") { d <- d - 1L; if (d == 0L) break }; j <- j + 1L }
      keep[i:min(j, length(ch))] <- FALSE; i <- j }
    i <- i + 1L
  }
  paste(ch[keep], collapse = "")
}
clag_scoper <- function(txt) {
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  if (!length(lines)) return(function(pos) txt)
  len <- nchar(lines, "chars"); st <- cumsum(c(1L, len + 1L))[seq_along(lines)]      # char index of each line start
  blank <- !nzchar(trimws(lines)); unit <- integer(length(lines)); u <- 0L; prev_blank <- TRUE; prev_head <- FALSE
  for (k in seq_along(lines)) {
    if (blank[k]) { prev_blank <- TRUE; prev_head <- FALSE; unit[k] <- NA_integer_; next }
    if (prev_blank || prev_head || grepl(unit_start_rx, lines[k], perl = TRUE)) u <- u + 1L
    unit[k] <- u; prev_blank <- FALSE; prev_head <- grepl("^\\s*(>\\s*)*#{1,6}\\s", lines[k])      # a heading is one line
  }
  function(pos) {
    k <- findInterval(pos, st); u <- unit[k]
    if (is.na(u)) return("")
    idx <- which(unit == u); a <- st[min(idx)]; b <- st[max(idx)] + len[max(idx)] - 1L
    seg <- substr(txt, a, b)
    ## innermost enclosing ^[ ... ] inline note?
    ch <- strsplit(seg, "")[[1]]; off <- pos - a + 1L; stack <- integer(); isnote <- logical()
    i <- 1L
    while (i < off && i <= length(ch)) {
      if (ch[i] == "\\") i <- i + 1L
      else if (ch[i] == "[") { stack <- c(stack, i); isnote <- c(isnote, i > 1L && ch[i - 1L] == "^") }
      else if (ch[i] == "]" && length(stack)) { stack <- stack[-length(stack)]; isnote <- isnote[-length(isnote)] }
      i <- i + 1L
    }
    if (any(isnote)) {
      o <- stack[max(which(isnote))]; d <- 0L; e <- length(ch)
      for (i in o:length(ch)) { if (ch[i] == "[") d <- d + 1L else if (ch[i] == "]") { d <- d - 1L; if (d == 0L) { e <- i; break } } }
      return(paste(ch[o:e], collapse = ""))
    }
    drop_notes(seg)                       # the span is outside any note: note text is not part of this paragraph
  }
}

## ---- SPIKE: bibliography discovery + keys ------------------------------------------
## Quarto: QUARTO_EXECUTE_INFO (a JSON file) holds the MERGED metadata (project + front matter), bibliography paths
## already relative to the document. rmarkdown::metadata holds the front matter only (works under both renderers).
bib_sources <- function() {
  ei <- Sys.getenv("QUARTO_EXECUTE_INFO"); doc <- NULL; files <- character(); refs <- character(); via <- ""
  if (nzchar(ei) && file.exists(ei)) {
    j <- jsonlite::read_json(ei); m <- j$format$metadata; doc <- dirname(j[["document-path"]]); via <- "QUARTO_EXECUTE_INFO"
    files <- unlist(m$bibliography); refs <- vapply(m$references %||% list(), function(r) as.character(r$id), "")
  } else {
    m <- tryCatch(rmarkdown::metadata, error = function(e) list())
    inp <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NULL, warning = function(w) NULL)
    doc <- if (!is.null(inp)) dirname(inp) else getwd(); via <- "rmarkdown::metadata"
    files <- unlist(m$bibliography); refs <- vapply(m$references %||% list(), function(r) as.character(r$id), "")
  }
  list(files = if (length(files)) normalizePath(file.path(doc, files), mustWork = FALSE) else character(), refs = refs, via = via)
}
bib_keys_file <- function(path) {
  if (!file.exists(path)) stop("clag: bibliography file not found: ", path, call. = FALSE)
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("bib", "bibtex")) {
    x <- readLines(path, warn = FALSE, encoding = "UTF-8")
    m <- Filter(length, regmatches(x, regexec("^\\s*@([A-Za-z]+)\\s*[{(]\\s*([^,[:space:]]+)\\s*,", x)))
    m <- Filter(function(z) !tolower(z[2]) %in% c("comment", "string", "preamble"), m); vapply(m, `[`, "", 3)
  } else if (ext == "json") vapply(jsonlite::fromJSON(path, simplifyVector = FALSE), function(x) as.character(x$id), "")
  else if (ext %in% c("yaml", "yml")) { y <- yaml::read_yaml(path); r <- if (is.list(y) && !is.null(y$references)) y$references else y
    vapply(r, function(x) as.character(x$id), "") }
  else stop("clag: cannot read keys from a '.", ext, "' bibliography (", path, ")", call. = FALSE)
}
clag_bib_keys <- function() {
  if (is.null(clag$bibkeys)) {
    src <- bib_sources(); k <- src$refs
    for (f in src$files) k <- c(k, bib_keys_file(f))
    clag$bibkeys <- list(keys = unique(k), nfiles = length(src$files), via = src$via)
  }
  clag$bibkeys
}

## ---- SPIKE: cite spans ---------------------------------------------------------------
cite_key_rx <- "[A-Za-z0-9_](?:[A-Za-z0-9_]|[:.#$%&+?<>~/-](?=[A-Za-z0-9_]))*"
cite_keys_in <- function(v) {                                  # keys written as @key or @{key} in a citation-form value
  m <- gregexpr(paste0("(?<![A-Za-z0-9_])@(\\{[^}]+\\}|", cite_key_rx, ")"), v, perl = TRUE)
  k <- regmatches(v, m)[[1]]; sub("^@\\{?([^}]*)\\}?$", "\\1", k)
}
cited_in <- function(scope, key) {                             # does the paragraph cite `key` (Pandoc syntax) ?
  scope <- gsub("`[^`]*`", " ", scope)                         # code spans do not cite
  k <- gsub("([][{}()+*.?\\\\^$|])", "\\\\\\1", key)
  grepl(paste0("(?<![A-Za-z0-9_])@(", k, "|\\{", k, "\\})(?![A-Za-z0-9_]|[:.#$%&+?<>~/-][A-Za-z0-9_])"), scope, perl = TRUE)
}
render_cite <- function(nd, ctx) {
  a <- nd$attrs; pos <- nd$pos; what <- paste0("[", nd$phrase, "]{cite=...}")
  other <- intersect(a$keys, c("n", "if", "sign"))
  if (length(other)) fail_at(ctx, pos, "a cite span has no arms and cannot carry ", other[1], ", in ", what)
  val <- get1(a, "cite")
  if (!nzchar(trimws(val))) fail_at(ctx, pos, "cite is empty, in ", what)
  prose <- render_nodes(nd$kids, list(in_arm = FALSE, gov = NULL, loc = ctx$loc, scope = ctx$scope))   # | and # stay literal
  bib <- clag_bib_keys()
  if (grepl("@", val, fixed = TRUE)) {                          # citation form
    keys <- cite_keys_in(val)
    if (!length(keys)) fail_at(ctx, pos, "cite value contains @ but no citation key could be read from '", val, "', in ", what)
    unk <- setdiff(keys, bib$keys)
    if (length(unk)) fail_at(ctx, pos, "unknown citation key", if (length(unk) > 1L) "s", " ", paste(unk, collapse = ", "), " (not in the bibliography: ", bib$nfiles, " file(s) via ", bib$via, "), in ", what)
    return(paste0(prose, " [", val, "]"))
  }
  keys <- trimws(strsplit(val, ";", fixed = TRUE)[[1]])         # bare form
  if (grepl(";\\s*$", val) || any(!nzchar(keys)) || any(!grepl(paste0("^", cite_key_rx, "$"), keys, perl = TRUE)))
    fail_at(ctx, pos, "cite='", val, "' is not a list of bare keys separated by ';' (write @ to emit a citation), in ", what)
  unk <- setdiff(keys, bib$keys)
  if (length(unk)) fail_at(ctx, pos, "unknown citation key", if (length(unk) > 1L) "s", " ", paste(unk, collapse = ", "), " (not in the bibliography: ", bib$nfiles, " file(s) via ", bib$via, "), in ", what)
  scope <- ctx$scope(pos)
  miss <- keys[!vapply(keys, cited_in, NA, scope = scope)]
  if (length(miss)) fail_at(ctx, pos, "the paragraph holding ", what, " does not cite ", paste0("@", miss, collapse = ", "), "; cite it in the same paragraph")
  prose
}

fail_at <- function(ctx, pos, ...) stop("clag: ", ctx$loc(pos), ": ", ..., call. = FALSE)
get1 <- function(a, key) { v <- if (is.null(a)) character() else a$vals[a$keys == key]; if (length(v)) v[1] }
ev <- function(code, ctx, pos, what) {            # R errors are collected like failed claims
  clag$here <- list(loc = ctx$loc, pos = pos, what = what)
  tryCatch(list(ok = TRUE, v = eval(parse(text = code), NULL, knitr::knit_global())),
           error = function(e) { clag_collect(code, paste0("error evaluating `", code, "`: ", conditionMessage(e))); list(ok = FALSE) })
}
stock_value <- function(code, ctx, pos, what) {
  clag$here <- list(loc = ctx$loc, pos = pos, what = what); n0 <- length(clag$fails)
  r <- tryCatch(stock1(clag$stock_eval(code, knitr::knit_global())),
                error = function(e) { clag_collect(code, paste0("error evaluating `", code, "`: ", conditionMessage(e))); NULL })
  if (is.null(r)) MARK else if (length(clag$fails) > n0) paste0(r, MARK) else r
}
check_attrs <- function(a, ctx, pos, what) {
  for (cl in setdiff(a$cls, c(all_fmts(), clag_texts))) { h <- near_name(cl)
    if (length(h)) fail_at(ctx, pos, "unknown class .", cl, ", one edit from .", h[1], " (a typo?), in ", what) }
}
reg_id <- function(a, entry, ctx, pos) for (id in a$id) {
  if (!is.null(clag$ids[[id]])) fail_at(ctx, pos, "id #", id, " is already defined (at ", clag$ids[[id]]$loc, ")")
  entry$loc <- ctx$loc(pos); clag$ids[[id]] <- entry
}
clag_lang <- function() {
  if (is.null(clag$lang)) {
    f <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NULL, warning = function(w) NULL)
    l <- tryCatch(rmarkdown::yaml_front_matter(f)$lang, error = function(e) NULL)
    clag$lang <- if (is.character(l) && length(l) == 1L) l else ""
  }
  clag$lang
}

render_nodes <- function(nodes, ctx) {
  out <- character(length(nodes))
  for (k in seq_along(nodes)) {
    nd <- nodes[[k]]
    out[k] <- switch(nd$t,
      text = nd$s,
      bar = nd$s,
      litbar = if (ctx$in_arm) "|" else nd$s,
      hash = if (ctx$in_arm) (if (is.null(ctx$gov)) "#" else ctx$gov$text) else nd$s,
      lithash = if (ctx$in_arm) "#" else nd$s,
      fence = render_fence(nd, ctx),
      val = render_value(nd, ctx),
      br = render_br(nd, ctx))
  }
  paste(out, collapse = "")
}

render_fence <- function(nd, ctx) {              # stock knitr behaviour: evaluate, print as stock, nothing else
  s <- nd$s; m <- gregexpr(paste0(clag$O, "[0-9]+", clag$C), s)[[1]]
  if (m[1] == -1L) return(s)
  st <- as.integer(m); ln <- attr(m, "match.length"); out <- character(); prev <- 1L
  for (k in seq_along(st)) {
    q <- substr(s, st[k], st[k] + ln[k] - 1L); code <- clag$pend[[as.integer(gsub(paste0("[", clag$O, clag$C, "]"), "", q))]]
    out <- c(out, substr(s, prev, st[k] - 1L), stock_value(code, ctx, nd$pos + st[k] - 1L, paste0("`r ", code, "`")))
    prev <- st[k] + ln[k]
  }
  paste(c(out, substr(s, prev, nchar(s))), collapse = "")
}

render_value <- function(nd, ctx) {
  code <- clag$pend[[nd$idx]]; a <- nd$attrs; what <- paste0("`r ", code, "`")
  if (is.null(a) || (!length(a$cls) && !length(a$keys) && !length(a$id))) return(stock_value(code, ctx, nd$pos, what))
  check_attrs(a, ctx, nd$pos, what)
  bad <- intersect(a$keys, c("n", "if", "sign"))
  if (length(bad)) fail_at(ctx, nd$pos, "the key ", bad[1], " governs bracketed prose, e.g. [a | b]{", bad[1], "=\"...\"}; it does not go on a value: ", what)
  n0 <- length(clag$fails)
  r <- ev(code, ctx, nd$pos, what); if (!r$ok) return(MARK)
  val <- r$v
  fm <- intersect(a$cls, all_fmts()); fm <- a$cls[a$cls %in% fm]
  S <- run_chain(val, fm, a, function(m) fail_at(ctx, nd$pos, m, " on ", what))
  reg_id(a, list(raw = val, fm = fm), ctx, nd$pos)
  out <- finish_text(S$text, a, S$block)
  if (length(clag$fails) > n0) paste0(out, MARK) else out
}

## the number (or flag) a governor works from: an expression, "." (the enclosing n span) or "#id" (an earlier construct)
get_gov <- function(a, kind, ctx, pos, what) {
  expr <- get1(a, kind); fm_own <- a$cls[a$cls %in% all_fmts()]
  fail <- function(m) fail_at(ctx, pos, m, " on ", what)
  idm <- regmatches(expr, regexec("^\\s*#([A-Za-z][A-Za-z0-9_:.-]*)\\s*$", expr))[[1]]
  if (length(idm) == 2L) {
    e <- clag$ids[[idm[2]]]
    if (is.null(e)) fail(paste0("unknown id #", idm[2], " (no earlier construct carries it; it may be defined later in the document)"))
    raw <- e$raw; fm <- if (length(fm_own)) fm_own else e$fm; shown <- paste0("#", idm[2])
  } else if (trimws(expr) == ".") {
    if (kind != "n" || is.null(ctx$gov) || ctx$gov$kind != "n") fail("n=\".\" has no enclosing n span to inherit from")
    raw <- ctx$gov$raw; fm <- if (length(fm_own)) fm_own else ctx$gov$fm; shown <- "."
  } else {
    r <- ev(expr, ctx, pos, what); if (!r$ok) return(NULL); raw <- r$v; fm <- fm_own; shown <- expr
  }
  rng <- "range" %in% fm && kind == "n"
  if (!is.numeric(raw) || anyNA(raw) || !(length(raw) == 1L || (rng && length(raw) == 2L)))
    fail(paste0(kind, " must evaluate to a single number, but `", shown, "` gave ",
                if (length(raw) != 1L) paste0("length ", length(raw), "; to count a vector write length(", shown, ")") else paste(class(raw), collapse = "/")))
  list(raw = raw, fm = fm)
}

render_br <- function(nd, ctx) {
  a <- nd$attrs
  if (!is.null(a) && "cite" %in% a$keys) return(render_cite(nd, ctx))      # SPIKE
  gk <- intersect(a$keys, c("n", "if", "sign"))
  if (is.null(a) || !length(gk)) {                                         # ordinary bracket: flat, children still live
    tail <- nd$tail
    if (!is.null(a) && "why" %in% a$keys && "weft-literal" %in% a$cls) {   # SPIKE: marked literal span: drop why
      tch <- strsplit(tail, "")[[1]]; b <- which(tch == "{")[1]            # attrs begin at the first "{" of the tail
      tail <- paste0(paste(tch[seq_len(b - 1L)], collapse = ""), cut_key(tch[b:length(tch)], a, "why", shift = nd$tail_off + b - 2L))
    }
    return(paste0("[", render_nodes(nd$kids, ctx), clag_expand_tail(tail, ctx)))
  }
  pos <- nd$pos; what <- paste0("[", nd$phrase, "]")
  check_attrs(a, ctx, pos, what)
  if (length(unique(gk)) > 1L) fail_at(ctx, pos, "a span carries exactly one of n, if and sign, found ", paste(gk, collapse = " and "), " in ", what)
  kind <- gk[1]
  arms <- list(); cur <- list()                                           # split on bar nodes of THIS bracket only
  for (k in nd$kids) if (k$t == "bar") { arms[[length(arms) + 1L]] <- cur; cur <- list() } else cur[[length(cur) + 1L]] <- k
  arms[[length(arms) + 1L]] <- cur
  m <- length(arms)
  if (kind == "n" && m > 4L) fail_at(ctx, pos, "n takes at most 4 arms (zero | one | two | other), found ", m, " in ", what)
  if (kind == "if" && m > 2L) fail_at(ctx, pos, "if takes 1 arm (a guard) or 2 (true | false), found ", m, " in ", what)
  if (kind == "sign" && !m %in% 2:3) fail_at(ctx, pos, "sign takes 2 arms (positive | negative) or 3 (+ zero), found ", m, " in ", what)
  if (kind == "if" && any(a$cls %in% all_fmts())) fail_at(ctx, pos, "a formatter class has no value to act on in an if span, in ", what)
  if (kind == "n" && m >= 2L && nzchar(lg <- clag_lang()) && !grepl("^en($|[-_])", lg, ignore.case = TRUE))
    fail_at(ctx, pos, "plural rules for language '", lg, "' are not shipped; an n span with 2 or more arms needs English, in ", what)
  n0 <- length(clag$fails); gov <- ctx$gov; idx <- NA_integer_
  if (kind %in% c("n", "sign")) {
    g <- get_gov(a, kind, ctx, pos, what)
    if (is.null(g)) return(MARK)
    chk <- function(v) run_chain(v, g$fm, a, function(msg) fail_at(ctx, pos, msg, " on ", what))
    S <- chk(g$raw)
    if (kind == "n") {
      gov <- list(raw = g$raw, fm = g$fm, kind = "n", text = S$text)
      is_k <- function(k) !is.na(S$num) && S$num == k && !S$dec && S$rel == "="
      idx <- if (m == 1L) 1L else if (m == 2L) { if (is_k(1)) 1L else 2L }
             else if (m == 3L) { if (is_k(0)) 1L else if (is_k(1)) 2L else 3L }
             else { if (is_k(0)) 1L else if (is_k(1)) 2L else if (is_k(2)) 3L else 4L }
    } else {
      gov <- list(raw = g$raw, fm = g$fm, kind = "sign", text = chk(abs(g$raw))$text)
      sg <- sign(if (!is.na(S$num)) S$num else g$raw)
      idx <- if (sg > 0) 1L else if (sg < 0) 2L else if (m == 3L) 3L else NA_integer_
      if (is.na(idx)) { clag$here <- list(loc = ctx$loc, pos = pos, what = what)
        clag_collect("sign", paste0("the value prints as zero (", S$text, ") and the span has no zero arm")) }
    }
    reg_id(a, list(raw = g$raw, fm = g$fm), ctx, pos)
  } else {
    code <- get1(a, "if")
    ex <- tryCatch(as.list(parse(text = paste0("list(", code, ")"))[[1]])[-1],
                   error = function(e) fail_at(ctx, pos, "cannot parse the if conditions `", code, "`: ", conditionMessage(e)))
    if (!length(ex)) fail_at(ctx, pos, "if needs at least one condition, in ", what)
    clag$here <- list(loc = ctx$loc, pos = pos, what = what); ok <- logical()
    for (e in ex) {
      es <- paste(deparse(e, width.cutoff = 500L), collapse = " ")
      r <- tryCatch(list(ok = TRUE, v = eval(e, NULL, knitr::knit_global())),
                    error = function(err) { clag_collect(es, paste0("error evaluating `", es, "`: ", conditionMessage(err))); list(ok = FALSE) })
      if (!r$ok) return(MARK)
      if (!is.logical(r$v) || length(r$v) != 1L || is.na(r$v)) fail_at(ctx, pos, "each if condition must be a single TRUE or FALSE, but `", es, "` gave ", shortv(r$v), " in ", what)
      if (!r$v && m == 1L) clag_collect(es, paste0(es, " was FALSE"))
      ok <- c(ok, r$v)
    }
    reg_id(a, list(raw = all(ok), fm = character()), ctx, pos)
    idx <- if (m == 1L) 1L else if (all(ok)) 1L else 2L
  }
  mk <- if (length(clag$fails) > n0) MARK else ""
  if (is.na(idx)) return(mk)
  ctx2 <- list(in_arm = TRUE, gov = gov, loc = ctx$loc, scope = ctx$scope)
  paste0(finish_text(trimws(render_nodes(arms[[idx]], ctx2)), a), mk)      # ONLY the chosen arm is rendered
}

clag_expand_tail <- function(tail, ctx) {                                  # values inside "](url)" are bare-evaluated
  if (!grepl(clag$O, tail, fixed = TRUE)) return(tail)
  m <- gregexpr(paste0(clag$O, "[0-9]+", clag$C), tail)
  regmatches(tail, m) <- lapply(regmatches(tail, m), function(p) vapply(p, function(q) {
    code <- clag$pend[[as.integer(gsub(paste0("[", clag$O, clag$C, "]"), "", q))]]
    stock1(clag$stock_eval(code, knitr::knit_global())) }, ""))
  tail
}
