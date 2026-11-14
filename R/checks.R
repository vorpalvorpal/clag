# Checks of one value compared (design-7 F9, N120 to N151, new spec 3.10 and 6.3.7).
#
# A *check* is a guard part (a comma part of a one-arm `if`), a check argument of an R `claim()`, or, for
# `checks()` only, a comma part of a two-arm `if` (a branch). `checks_read()` reads the checks of one source
# from the parse trees `code_pieces()` already built; `check_implies()` and `check_covered()` are the
# relation and coverage of N127 to N131; `checks()` reports them grouped by value. The gate's use of the
# same reader and relation is in R/gate.R.

# ---- constants ------------------------------------------------------------------------------------------------

# N150 rule 6: functions whose value changes between two evaluations, or that hide what they read
CHECK_UNSAFE_FNS <- c(
  "sample", "sample.int", "set.seed", "rbeta", "rbinom", "rcauchy", "rchisq", "rexp", "rf", "rgamma", "rgeom",
  "rhyper", "rlnorm", "rlogis", "rmultinom", "rnbinom", "rnorm", "rpois", "rsignrank", "rt", "runif", "rweibull",
  "rwilcox",
  "Sys.time", "Sys.Date", "date", "proc.time", "Sys.getenv", "Sys.getpid", "tempfile", "getwd",
  "readline", "readLines", "scan", "menu", "file.choose",
  "get", "get0", "mget", "exists", "eval", "evalq", "assign", "rm", "source", "library", "require", "attach",
  "options", "Sys.setenv", "setwd", "parent.frame", "sys.call", "sys.function", "environment")

CK_MIRROR <- c("<" = ">", "<=" = ">=", ">" = "<", ">=" = "<=", "==" = "==", "!=" = "!=")
CK_TOKEN_OPS <- c(EQ = "==", NE = "!=", LT = "<", GT = ">", LE = "<=", GE = ">=")
CK_NUM_RE <- "^(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?L?$"

checks_empty <- function() {
  data.frame(file = character(), line = integer(), role = character(), level = character(), value = character(),
             op = character(), other = character(), cond = character(), key = character(), text = character(),
             always = logical(), rebound = logical(), filter = logical(), stringsAsFactors = FALSE)
}

ck_cut <- function(x, n = 60L) ifelse(!is.na(x) & nchar(x) > n, paste0(substr(x, 1L, n - 3L), "..."), x)

# ---- exact decimals (N124, N130) -----------------------------------------------------------------------------------

# a decimal text as sign, digits (no leading or trailing zeros) and exponent: value = digits * 10^exp
ck_dec <- function(s) {
  neg <- startsWith(s, "-")
  if (neg || startsWith(s, "+")) s <- substring(s, 2L)
  m <- regmatches(s, regexec("^([0-9]*)\\.?([0-9]*)(?:[eE]([+-]?[0-9]+))?$", s, perl = TRUE))[[1L]]
  if (length(m) < 4L || !nzchar(paste0(m[2L], m[3L]))) return(list(0L, "", 0))
  ex <- if (nzchar(m[4L])) as.numeric(m[4L]) else 0
  digits <- sub("^0+", "", paste0(m[2L], m[3L]))
  e <- ex - nchar(m[3L])
  if (!nzchar(digits)) return(list(0L, "", 0))
  trimmed <- sub("0+$", "", digits)
  list(if (neg) -1L else 1L, trimmed, e + (nchar(digits) - nchar(trimmed)))
}

# -1, 0 or 1 for two decimal texts: an R twin of num_cmp() in weftlib/cond.lua
dec_cmp <- function(a, b) {
  x <- ck_dec(a)
  y <- ck_dec(b)
  if (x[[1L]] != y[[1L]]) return(if (x[[1L]] < y[[1L]]) -1L else 1L)
  if (x[[1L]] == 0L) return(0L)
  ma <- nchar(x[[2L]]) + x[[3L]]
  mb <- nchar(y[[2L]]) + y[[3L]]
  if (ma != mb) {
    c <- if (ma < mb) -1L else 1L
  } else {
    n <- max(nchar(x[[2L]]), nchar(y[[2L]]))
    pa <- paste0(x[[2L]], strrep("0", n - nchar(x[[2L]])))
    pb <- paste0(y[[2L]], strrep("0", n - nchar(y[[2L]])))
    c <- if (pa == pb) 0L else if (pa < pb) -1L else 1L
  }
  as.integer(c * x[[1L]])
}

# a numeric constant's canonical decimal text (N124): the exact decimal, no `+`, no leading or trailing zeros,
# no exponent, `0` for `-0`; `<mantissa>e<exponent>` when the plain form would have more than 20 digits
ck_canon_num <- function(x) {
  x <- sub("L$", "", x)
  d <- ck_dec(x)
  if (d[[1L]] == 0L) return("0")
  sgn <- if (d[[1L]] < 0L) "-" else ""
  dg <- d[[2L]]
  n <- nchar(dg)
  point <- n + d[[3L]]                 # the value is 0.<dg> * 10^point
  total <- if (point <= 0) n - point else max(n, point)
  if (total > 20) {
    mant <- if (n > 1L) paste0(substr(dg, 1L, 1L), ".", substring(dg, 2L)) else dg
    return(paste0(sgn, mant, "e", format(point - 1, scientific = FALSE, trim = TRUE)))
  }
  body <- if (point <= 0) paste0("0.", strrep("0", -point), dg)
  else if (point >= n) paste0(dg, strrep("0", point - n))
  else paste0(substr(dg, 1L, point), ".", substring(dg, point + 1L))
  paste0(sgn, body)
}

ck_valid_date <- function(v) {
  m <- regmatches(v, regexec("^([0-9]{4})-([0-9]{2})-([0-9]{2})$", v))[[1L]]
  if (length(m) != 4L) return(FALSE)
  y <- as.integer(m[2L]); mo <- as.integer(m[3L]); d <- as.integer(m[4L])
  if (mo < 1L || mo > 12L || d < 1L) return(FALSE)
  dim <- c(31L, 28L, 31L, 30L, 31L, 30L, 31L, 31L, 30L, 31L, 30L, 31L)
  if ((y %% 4L == 0L && y %% 100L != 0L) || y %% 400L == 0L) dim[2L] <- 29L
  d <= dim[mo]
}

ck_quote <- function(v) if (grepl("'", v, fixed = TRUE)) paste0("\"", v, "\"") else paste0("'", v, "'")

# ---- operands (N122, N149, N150) --------------------------------------------------------------------------------

ck_strip_parens <- function(t, i) {
  tk <- t$pd$token
  repeat {
    k <- t$kids[[i]]
    if (tk[i] == "expr" && length(k) == 3L && tk[k[1L]] == "'('" && tk[k[3L]] == "')'") i <- k[2L] else return(i)
  }
}

# `dict$k`, `dict$"k"`, `dict[["k"]]` (and of dict_local) at node i: c(object, key), else NULL
ck_dict_node <- function(t, i) {
  tk <- t$pd$token
  if (tk[i] != "expr") return(NULL)
  k <- t$kids[[i]]
  if (length(k) < 3L || tk[k[1L]] != "expr") return(NULL)
  bk <- t$kids[[k[1L]]]
  if (length(bk) != 1L || tk[bk] != "SYMBOL" || !(t$pd$text[bk] %in% c("dict", "dict_local"))) return(NULL)
  key <- NA_character_
  if (length(k) == 3L && tk[k[2L]] == "'$'") {
    nd <- k[3L]
    key <- if (tk[nd] == "SYMBOL") t$pd$text[nd] else if (tk[nd] == "STR_CONST") str_value(t, nd) else NA_character_
  } else if (length(k) == 5L && tk[k[2L]] == "LBB" && tk[k[3L]] == "expr") {
    key <- str_value(t, k[3L])
  }
  if (is.na(key)) NULL else c(t$pd$text[bk], key)
}

# the normal form of an expression's source text (N149), memoised in `cx$memo`; NA when it does not parse
ck_normal_form <- function(cx, txt) {
  hit <- cx$memo[[txt]]
  if (!is.null(hit)) return(hit)
  e <- tryCatch(parse(text = txt, keep.source = FALSE), error = function(e) NULL)
  nf <- NA_character_
  if (!is.null(e) && length(e) == 1L) {
    x <- e[[1L]]
    while (is.call(x) && identical(x[[1L]], as.name("("))) x <- x[[2L]]
    nf <- paste(trimws(deparse(x, width.cutoff = 500L)), collapse = " ")
  }
  cx$memo[[txt]] <- nf
  nf
}

# An expression operand (N122, N150): list(kind = "expr", text = normal form, refs) or NULL when it is not usable.
ck_expr_operand <- function(cx, t, i) {
  tk <- t$pd$token
  tx <- t$pd$text
  sub <- subtree(t, i)
  stk <- tk[sub]
  if (any(stk %in% c("LEFT_ASSIGN", "RIGHT_ASSIGN", "EQ_ASSIGN", "FUNCTION", "'\\\\'"))) return(NULL)            # 3
  if (any(stk %in% c("'{'", "IF", "FOR", "WHILE", "REPEAT", "BREAK", "NEXT"))) return(NULL)                  # 4
  sy <- sub[stk == "SYMBOL"]
  if (length(sy)) {
    after <- vapply(sy, function(j) {
      kk <- t$kids[[t$par[j]]]
      m <- match(j, kk)
      !is.na(m) && m > 1L && tk[kk[m - 1L]] %in% c("'$'", "'@'")
    }, NA)
    sy <- sy[!after]
  }
  if (!length(sy)) return(NULL)                                                                                # 1
  names_read <- tx[sy]
  if ("." %in% names_read) return(NULL)                                                                        # 2
  fn <- sub[stk == "SYMBOL_FUNCTION_CALL"]
  fns <- tx[fn]
  if (any(fns %in% CHECK_UNSAFE_FNS)) return(NULL)                                                             # 6
  # 5: every call goes through a plain or pkg:: name
  for (j in sub) {
    if (tk[j] != "expr") next
    k <- t$kids[[j]]
    if (length(k) >= 3L && tk[k[1L]] == "expr" && tk[k[2L]] == "'('") {
      fk <- t$kids[[k[1L]]]
      plain <- length(fk) == 1L && tk[fk] == "SYMBOL_FUNCTION_CALL"
      pkg <- length(fk) == 3L && tk[fk[1L]] == "SYMBOL_PACKAGE" && tk[fk[3L]] == "SYMBOL_FUNCTION_CALL"
      if (!plain && !pkg) return(NULL)
    }
  }
  if (length(cx$local) && any(names_read == "dict")) {                                                        # 7
    for (j in sub) {
      d <- ck_dict_node(t, j)
      if (!is.null(d) && d[[1L]] == "dict" && d[[2L]] %in% cx$local) return(NULL)
    }
  }
  nf <- ck_normal_form(cx, node_text(t, i))
  if (is.na(nf)) return(NULL)
  bare <- fn[vapply(fn, function(j) {
    kk <- t$kids[[t$par[j]]]
    !(length(kk) == 3L && tk[kk[1L]] == "SYMBOL_PACKAGE")
  }, NA)]
  list(kind = "expr", text = nf, refs = unique(c(setdiff(names_read, c("dict", "dict_local")), tx[bare])))
}

# One operand (N122), the kinds tried in their order: list(kind, text, refs), or NULL when it is none of them.
# `dot` is what a whole-operand `.` stands for (N123), or NULL.
ck_operand <- function(cx, t, i, dot = NULL) {
  i <- ck_strip_parens(t, i)
  tk <- t$pd$token
  tx <- t$pd$text
  if (tk[i] != "expr") return(NULL)
  k <- t$kids[[i]]
  if (length(k) == 1L && tk[k] == "SYMBOL") {
    nm <- tx[k]
    if (identical(nm, ".")) return(dot)
    return(list(kind = "name", text = nm, refs = if (nm %in% c("dict", "dict_local")) character() else nm))
  }
  d <- ck_dict_node(t, i)
  if (!is.null(d)) {
    if (d[[1L]] == "dict" && d[[2L]] %in% cx$local) return(NULL)
    return(list(kind = "dict", text = paste0(d[[1L]], "$", d[[2L]]), refs = character()))
  }
  neg <- FALSE
  j <- i
  if (length(k) == 2L && tk[k[1L]] == "'-'") {
    j <- k[2L]
    neg <- TRUE
  }
  kj <- t$kids[[j]]
  if (tk[j] == "expr" && length(kj) == 1L && tk[kj] == "NUM_CONST") {
    s <- tx[kj]
    if (s %in% c("TRUE", "FALSE") && !neg) return(list(kind = "bool", text = s, refs = character()))
    if (grepl(CK_NUM_RE, s, perl = TRUE)) {
      return(list(kind = "number", text = ck_canon_num(paste0(if (neg) "-" else "", s)), refs = character()))
    }
    return(NULL)
  }
  if (length(k) == 1L && tk[k] == "STR_CONST") {
    v <- str_value(t, i)
    if (is.na(v)) return(NULL)
    return(list(kind = if (ck_valid_date(v)) "date" else "string", text = ck_quote(v), refs = character()))
  }
  ci <- call_info(t, i)
  if (!is.null(ci) && identical(ci$fn, "u") && is.na(ci$pkg) && length(ci$args) == 2L && is.na(pipe_lhs(t, i)) &&
      all(is.na(vapply(ci$args, function(a) a$name, "")))) {
    n1 <- ck_operand(cx, t, ci$args[[1L]]$node)
    a2 <- ck_strip_parens(t, ci$args[[2L]]$node)
    k2 <- t$kids[[a2]]
    unit <- NA_character_
    if (length(k2) == 1L && tk[k2] == "SYMBOL") unit <- tx[k2]
    else if (length(k2) == 1L && tk[k2] == "STR_CONST") unit <- str_value(t, a2)
    if (!is.null(n1) && identical(n1$kind, "number") && !is.na(unit) && nzchar(gsub("[ \t\r\n]", "", unit))) {
      unit <- gsub("[ \t\r\n]", "", unit)
      return(list(kind = paste("quantity", unit), text = sprintf("u(%s, %s)", n1$text, unit), refs = character()))
    }
  }
  ck_expr_operand(cx, t, i)
}

ck_is_literal <- function(o) !(o$kind %in% c("name", "dict", "expr"))

# Two operands and an operator as one check (N121, N124): list(value, op, other, two, refs), or NULL.
ck_pair <- function(a, b, op) {
  la <- ck_is_literal(a)
  lb <- ck_is_literal(b)
  if (la && lb) return(NULL)
  lit <- if (la) a else if (lb) b else NULL
  if (!is.null(lit) && op %in% c("<", "<=", ">", ">=") && lit$kind %in% c("string", "bool")) return(NULL)
  if (!la && !lb && identical(a$kind, b$kind) && identical(a$text, b$text)) return(NULL)
  refs <- unique(c(a$refs, b$refs))
  if (la) return(list(value = b$text, op = CK_MIRROR[[op]], other = a$text, two = FALSE, refs = refs))
  list(value = a$text, op = op, other = b$text, two = !lb, refs = refs)
}

# A check node as a pair (N121): a comparison, or a bool check. NULL when not readable.
ck_read_check <- function(cx, t, node, dot = NULL) {
  i <- ck_strip_parens(t, node)
  tk <- t$pd$token
  if (tk[i] != "expr") return(NULL)
  k <- t$kids[[i]]
  if (length(k) == 3L && tk[k[2L]] %in% names(CK_TOKEN_OPS)) {
    a <- ck_operand(cx, t, k[1L], dot)
    b <- ck_operand(cx, t, k[3L], dot)
    if (is.null(a) || is.null(b)) return(NULL)
    return(ck_pair(a, b, CK_TOKEN_OPS[[tk[k[2L]]]]))
  }
  bool <- function(nd, val) {
    o <- ck_operand(cx, t, nd, dot)
    if (is.null(o) || !identical(o$kind, "name")) return(NULL)
    list(value = o$text, op = "is", other = val, two = FALSE, refs = o$refs)
  }
  if (length(k) == 1L && tk[k] == "SYMBOL") return(bool(i, "TRUE"))
  if (length(k) == 2L && tk[k[1L]] == "'!'") return(bool(k[2L], "FALSE"))
  NULL
}

# the name a claim call's result is assigned to (N123 rule 3), or NA
ck_assigned_name <- function(t, i) {
  tk <- t$pd$token
  repeat {
    p <- t$par[i]
    if (is.na(p)) return(NA_character_)
    if (!is.na(pipe_lhs(t, i))) i <- p else break
  }
  p <- t$par[i]
  k <- t$kids[[p]]
  if (tk[p] != "expr" || length(k) != 3L) return(NA_character_)
  target <- if (tk[k[2L]] %in% c("LEFT_ASSIGN", "EQ_ASSIGN") && k[3L] == i) k[1L]
  else if (tk[k[2L]] == "RIGHT_ASSIGN" && k[1L] == i) k[3L] else NA_integer_
  if (is.na(target)) return(NA_character_)
  kt <- t$kids[[target]]
  if (tk[target] == "expr" && length(kt) == 1L && tk[kt] == "SYMBOL") t$pd$text[kt] else NA_character_
}

# TRUE when the node is inside a function definition
ck_in_function <- function(t, i) {
  tk <- t$pd$token
  p <- t$par[i]
  while (!is.na(p)) {
    k <- t$kids[[p]]
    if (length(k) && tk[k[1L]] %in% c("FUNCTION", "'\\\\'")) return(TRUE)
    p <- t$par[p]
  }
  FALSE
}

# N126: FALSE when the node is under an R `if`, `else`, `for`, `while` or `repeat`
ck_runs_always <- function(t, i) {
  tk <- t$pd$token
  p <- t$par[i]
  while (!is.na(p)) {
    k <- t$kids[[p]]
    if (length(k) && tk[k[1L]] %in% c("IF", "FOR", "WHILE", "REPEAT")) return(FALSE)
    p <- t$par[p]
  }
  TRUE
}

# ---- rebinding (N125) -------------------------------------------------------------------------------------------

# the names a tree assigns, each as many times as it is bound (a `for` counts two), outside function bodies
ck_assigned_in <- function(t) {
  tk <- t$pd$token
  out <- character()
  walk <- function(i) {
    if (tk[i] != "expr") return(invisible())
    k <- t$kids[[i]]
    if (length(k) && tk[k[1L]] %in% c("FUNCTION", "'\\\\'")) return(invisible())
    if (length(k) >= 3L && tk[k[1L]] == "FOR") {
      fc <- t$kids[[k[2L]]]
      sy <- fc[tk[fc] == "SYMBOL"]
      if (length(sy)) out <<- c(out, rep(t$pd$text[sy[1L]], 2L))
      for (kk in fc) if (tk[kk] == "expr") walk(kk)
    } else if (length(k) >= 3L) {
      s <- NA_character_
      if (length(k) == 3L && tk[k[2L]] %in% c("LEFT_ASSIGN", "EQ_ASSIGN")) s <- lead_symbol(t, k[1L])
      else if (length(k) == 3L && tk[k[2L]] == "RIGHT_ASSIGN") s <- lead_symbol(t, k[3L])
      if (!is.na(s)) out <<- c(out, s)
      ci <- call_info(t, i)
      if (!is.null(ci) && is_fn(ci, "assign", "base") && length(ci$args)) {
        v <- str_value(t, ci$args[[1L]]$node)
        if (!is.na(v)) out <<- c(out, v)
      }
    }
    for (kk in k) if (tk[kk] == "expr") walk(kk)
    invisible()
  }
  for (r in t$roots) walk(r)
  out
}

# the names a Python or Julia chunk binds: a line that begins with the name and `=` or an augmented
# assignment counts one, a `for NAME in` counts two
ck_assigned_guest <- function(code) {
  ls <- unlist(strsplit(paste(code, collapse = "\n"), "\n", fixed = TRUE), use.names = FALSE)
  out <- character()
  m <- regmatches(ls, regexec("^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*(?:=(?!=)|[-+*/]=)", ls, perl = TRUE))
  for (x in m) if (length(x) == 2L) out <- c(out, x[2L])
  f <- regmatches(ls, regexec("^[ \t]*for[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+in\\b", ls, perl = TRUE))
  for (x in f) if (length(x) == 2L) out <- c(out, rep(x[2L], 2L))
  out
}

# ---- the reader (N120 to N126) -------------------------------------------------------------------------------------

# the row of `src$rows` an inline piece belongs to: the innermost of its kind whose text holds the piece
ck_row_of <- function(rows, p) {
  hit <- which(rows$kind == p$kind & rows$fstart <= p$off & rows$fend >= p$off)
  if (!length(hit)) return(NA_integer_)
  hit[which.max(rows$fstart[hit])]
}

# N126 for a construct: FALSE when it sits in an arm of a span with more than one arm
ck_row_always <- function(rows, i) {
  if (is.na(i)) return(TRUE)
  k <- rows$parent[i]
  while (!is.na(k) && k > 0L) {
    if (length(rows$arms[[k]]) > 1L) return(FALSE)
    k <- rows$parent[k]
  }
  TRUE
}

# The checks of a source: one row per check, sorted by line then column. `cond` and `key` are NA when the
# check is not readable; `filter` is TRUE for a guard of a document the Lua filter resolves. The attribute
# `rebound_names` holds the names assigned in more than one place.
checks_read <- function(src) {
  if (isTRUE(src$invalid) || is.null(src$rows)) {
    out <- checks_empty()
    attr(out, "rebound_names") <- character()
    return(out)
  }
  rows <- src$rows
  w <- if (is.list(src$front)) src$front$weft else NULL
  local <- if (is.list(w) && is.list(w$dict_local)) names(w$dict_local) else character()
  cx <- new.env(parent = emptyenv())
  cx$memo <- new.env(parent = emptyenv())
  cx$local <- local %||% character()
  pieces <- code_pieces(src)
  recs <- list()
  add <- function(off, role, level, text, always, filter, p) {
    recs[[length(recs) + 1L]] <<- list(off = as.numeric(off), line = findInterval(off, src$line_start), role = role,
                                       level = level, text = text, always = always, filter = filter, p = p)
  }
  assigned <- character()
  for (p in pieces) {
    t <- p$tree
    if (!is.null(t) && p$kind %in% c("value", "bare", "chunk")) assigned <- c(assigned, ck_assigned_in(t))
    row <- if (p$kind == "chunk") NA_integer_ else ck_row_of(rows, p)
    row_always <- ck_row_always(rows, row)
    # guards, and the branches of a two-arm `if`
    if (identical(p$kind, "if") && !is.na(row)) {
      role <- if (length(rows$arms[[row]]) > 1L) "branch" else "guard"
      level <- if (role == "branch") NA_character_ else "fail"
      filter <- identical(rows$resolver[row], "filter")
      if (filter) {
        raw <- cond_parts(p$text)
        pos <- 0
        for (r in raw) {
          part <- trim_ws(r)
          start <- pos + (nchar(r) - nchar(sub("^[ \t\r\n]+", "", r)))
          pos <- pos + nchar(r) + 1
          if (!nzchar(part)) next
          add(p$off + start, role, level, gate_ws(part), row_always, TRUE, ck_filter_part(cx, part))
        }
      } else {
        parts <- NULL
        if (!is.null(t) && length(t$roots) == 1L) {
          parts <- list(list(node = t$roots[1L], tree = t, p = p))
        } else if (is.null(t)) {
          wrapped <- paste0("list(", p$text, ")")
          t2 <- pd_tree(wrapped)
          if (!is.null(t2) && length(t2$roots) == 1L) {
            ci <- call_info(t2, t2$roots[1L])
            if (!is.null(ci) && identical(ci$fn, "list")) {
              p2 <- p
              p2$tree <- t2
              p2$line_off[1L] <- p$off - 5
              parts <- lapply(Filter(function(a) !isTRUE(a$piped), ci$args), function(a) list(node = a$node, tree = t2, p = p2))
            }
          }
        }
        if (is.null(parts)) {
          add(p$off, role, level, gate_ws(p$text), row_always, FALSE, NULL)
        } else {
          for (pt in parts) {
            sp <- piece_span(pt$p, pt$node)
            add(sp[1L], role, level, gate_ws(node_text(pt$tree, pt$node)), row_always, FALSE,
                ck_read_check(cx, pt$tree, pt$node))
          }
        }
      }
    }
    # claims
    if (is.null(t)) next
    for (i in all_exprs(t)) {
      ci <- call_info(t, i)
      if (!is_fn(ci, "claim", "weft") || !length(ci$args)) next
      level <- "fail"
      lv <- which(vapply(ci$args, function(a) identical(a$name, "level"), NA))
      if (length(lv)) {
        v <- str_value(t, ci$args[[lv[1L]]]$node)
        level <- if (identical(v, "warn")) "warn" else if (identical(v, "fail")) "fail" else "unknown"
      }
      always <- row_always && ck_runs_always(t, i)
      infn <- ck_in_function(t, i)
      text <- gate_ws(node_text(t, i))
      vop <- if (infn) NULL else ck_operand(cx, t, ci$args[[1L]]$node)
      dot <- NULL
      if (!is.null(vop) && vop$kind %in% c("name", "dict")) {
        dot <- vop
      } else if (!infn) {
        an <- ck_assigned_name(t, i)
        dot <- if (!is.na(an)) list(kind = "name", text = an, refs = an) else if (!is.null(vop) && vop$kind == "expr") vop else NULL
      }
      for (j in seq_along(ci$args)) {
        a <- ci$args[[j]]
        if (j == 1L || identical(a$name, "level") || identical(a$name, "decision")) next
        sp <- piece_span(p, a$node)
        add(sp[1L], "claim", level, text, always, FALSE, if (infn) NULL else ck_read_check(cx, t, a$node, dot))
        recs[[length(recs)]]$line <- findInterval(piece_span(p, i)[1L], src$line_start)
      }
    }
  }
  # Python and Julia claims: found by pattern, never readable (N121)
  ch <- src$chunks
  if (!is.null(ch) && nrow(ch)) {
    for (j in seq_len(nrow(ch))) {
      eng <- tolower(ch$engine[j])
      if (!eng %in% c("python", "julia") || isTRUE(isFALSE(ch$eval[j]))) next
      assigned <- c(assigned, ck_assigned_guest(ch$code[[j]]))
      cc <- claim_calls(ch$code[[j]], eng)
      for (q in seq_len(nrow(cc))) {
        ln <- as.integer(ch$code_line[j] + cc$line[q] - 1L)
        add(src$line_start[ln], "claim", "unknown", cc$text[q], TRUE, FALSE, NULL)
      }
    }
  }
  if (!length(recs)) {
    out <- checks_empty()
    attr(out, "rebound_names") <- character()
    return(out)
  }
  ord <- order(vapply(recs, function(r) r$line, 1L), vapply(recs, function(r) r$off, 1), seq_along(recs))
  recs <- recs[ord]
  # the display orientation of two value operands: the first check on the pair in the document (N124)
  disp <- new.env(parent = emptyenv())
  n <- length(recs)
  value <- op <- other <- cond <- key <- rep(NA_character_, n)
  refs <- vector("list", n)
  for (q in seq_len(n)) {
    p <- recs[[q]]$p
    if (is.null(p)) next
    refs[[q]] <- p$refs
    if (p$op == "is") {
      value[q] <- p$value; op[q] <- "is"; other[q] <- p$other
      cond[q] <- if (p$other == "TRUE") p$value else paste0("!", p$value)
      key[q] <- cond[q]
    } else if (!p$two) {
      value[q] <- p$value; op[q] <- p$op; other[q] <- p$other
      cond[q] <- key[q] <- paste(p$value, p$op, p$other)
    } else {
      lo_first <- identical(sort(c(p$value, p$other), method = "radix"), c(p$value, p$other))
      pk <- if (lo_first) paste(p$value, p$other, sep = "\001") else paste(p$other, p$value, sep = "\001")
      if (is.null(disp[[pk]])) disp[[pk]] <- c(p$value, p$other)
      d <- disp[[pk]]
      same <- identical(d, c(p$value, p$other))
      value[q] <- d[1L]; other[q] <- d[2L]
      op[q] <- if (same) p$op else CK_MIRROR[[p$op]]
      cond[q] <- paste(value[q], op[q], other[q])
      lo <- if (lo_first) p$value else p$other
      hi <- if (lo_first) p$other else p$value
      kop <- if (lo_first) p$op else CK_MIRROR[[p$op]]
      key[q] <- paste(lo, kop, hi)
    }
  }
  counts <- count_keys(assigned)
  rebound_names <- sort(names(counts)[counts > 1L], method = "radix")
  rebound <- vapply(refs, function(r) length(r) > 0L && any(r %in% rebound_names), NA)
  out <- data.frame(
    file = rep(as.character(src$file), n), line = vapply(recs, function(r) r$line, 1L), role = vapply(recs, function(r) r$role, ""),
    level = vapply(recs, function(r) r$level, ""), value = value, op = op, other = other, cond = cond, key = key,
    text = vapply(recs, function(r) r$text, ""), always = vapply(recs, function(r) r$always, NA), rebound = rebound,
    filter = vapply(recs, function(r) r$filter, NA), stringsAsFactors = FALSE)
  out$line <- as.integer(out$line)
  rownames(out) <- NULL
  attr(out, "rebound_names") <- rebound_names
  out
}

# One comma part of a filter condition (N121, 1.12.4): a pair, or NULL
ck_filter_part <- function(cx, part) {
  if (length(cond_part_error(part))) return(NULL)
  operand <- function(s) {
    if (startsWith(s, "'")) {
      v <- substr(s, 2L, nchar(s) - 1L)
      return(list(kind = if (ck_valid_date(v)) "date" else "string", text = ck_quote(v), refs = character()))
    }
    if (grepl("^-?[0-9]", s)) return(list(kind = "number", text = ck_canon_num(s), refs = character()))
    list(kind = "name", text = s, refs = s)
  }
  if (is_weft_name(part)) return(list(value = part, op = "is", other = "TRUE", two = FALSE, refs = part))
  if (startsWith(part, "!")) {
    nm <- substring(part, 2L)
    return(list(value = nm, op = "is", other = "FALSE", two = FALSE, refs = nm))
  }
  m <- regmatches(part, regexec(COND_RE, part, perl = TRUE))[[1L]]
  if (!length(m)) return(NULL)
  ck_pair(operand(m[2L]), operand(m[4L]), m[3L])
}

# ---- the relation (N127 to N131) ------------------------------------------------------------------------------------

# the kind of the `other` text of a row: number, date, string, bool, `quantity <unit>`, or value
ck_kind <- function(other, op = "") {
  if (identical(op, "is")) return("bool")
  if (is.na(other)) return(NA_character_)
  if (grepl("^-?[0-9]+(\\.[0-9]+)?(e-?[0-9]+)?$", other)) return("number")
  if (other %in% c("TRUE", "FALSE")) return("bool")
  m <- regmatches(other, regexec("^u\\(-?[0-9][0-9.e-]*, ([^,()]+)\\)$", other))[[1L]]
  if (length(m) == 2L) return(paste("quantity", m[2L]))
  if (grepl("^['\"]", other)) {
    return(if (grepl("^'[0-9]{4}-[0-9]{2}-[0-9]{2}'$", other) && ck_valid_date(substr(other, 2L, nchar(other) - 1L))) "date" else "string")
  }
  "value"
}

# the id of a row's pair (N127): the value operand with the kind of what it is compared with, or both operands
ck_pair_ids <- function(value, op, other) {
  vapply(seq_along(value), function(i) {
    if (is.na(value[i])) return(NA_character_)
    k <- ck_kind(other[i], op[i])
    if (identical(k, "value")) {
      lo <- sort(c(value[i], other[i]), method = "radix")
      paste(lo[1L], lo[2L], "pair", sep = "\001")
    } else {
      paste(value[i], k, sep = "\001")
    }
  }, "")
}

CK_NAMES <- list("<" = c("<", "<=", "!="), "<=" = "<=", ">" = c(">", ">=", "!="), ">=" = ">=", "==" = "==", "!=" = "!=")
CK_CELLS <- rbind(
  "<"  = c("le", "le", "F",  "F",  "F",  "le"),
  "<=" = c("lt", "le", "F",  "F",  "F",  "lt"),
  ">"  = c("F",  "F",  "ge", "ge", "F",  "ge"),
  ">=" = c("F",  "F",  "gt", "ge", "F",  "gt"),
  "==" = c("lt", "le", "gt", "ge", "eq", "ne"),
  "!=" = c("F",  "F",  "F",  "F",  "F",  "eq"))
colnames(CK_CELLS) <- c("<", "<=", ">", ">=", "==", "!=")

# the number inside a literal text, by kind
ck_lit_num <- function(x, kind) {
  if (startsWith(kind, "quantity")) sub("^u\\((.*), [^,]*\\)$", "\\1", x) else x
}

# Does check `a` imply check `b`? One-row data frames with `value`, `op` and `other` (N127 to N130). `filter` is
# TRUE when `b` is checked by the Lua filter, which compares exact decimals.
check_implies <- function(a, b, filter = FALSE) {
  if (identical(a$value, b$value) && identical(a$op, b$op) && identical(a$other, b$other)) return(TRUE)
  ka <- ck_kind(a$other, a$op)
  kb <- ck_kind(b$other, b$op)
  if (identical(ka, "value") || identical(kb, "value")) {
    if (!identical(ka, kb)) return(FALSE)
    if (identical(a$value, b$value) && identical(a$other, b$other)) {
      bop <- b$op
    } else if (identical(a$value, b$other) && identical(a$other, b$value)) {
      bop <- CK_MIRROR[[b$op]]
    } else {
      return(FALSE)
    }
    return(bop %in% CK_NAMES[[a$op]])
  }
  if (!identical(a$value, b$value) || !identical(ka, kb)) return(FALSE)
  if (identical(b$op, "is")) return(identical(a$op, "is") && identical(a$other, b$other))
  aop <- if (identical(a$op, "is")) "==" else a$op
  bop <- b$op
  if (ka %in% c("string", "bool")) {
    same <- identical(a$other, b$other)
    return(switch(paste(aop, bop),
                  "== ==" = same, "== !=" = !same, "!= !=" = same, FALSE))
  }
  cell <- CK_CELLS[aop, bop]
  if (identical(cell, "F")) return(FALSE)
  if (identical(ka, "date")) {
    da <- as.integer(gsub("[^0-9]", "", a$other))
    db <- as.integer(gsub("[^0-9]", "", b$other))
    s <- if (da < db) -1L else if (da > db) 1L else 0L
    strict_double <- FALSE
  } else {
    na <- ck_lit_num(a$other, ka)
    nb <- ck_lit_num(b$other, kb)
    s <- dec_cmp(na, nb)
    strict_double <- !isTRUE(filter)
  }
  ok <- switch(cell, lt = s < 0L, le = s <= 0L, gt = s > 0L, ge = s >= 0L, eq = s == 0L, ne = s != 0L, FALSE)
  if (ok && strict_double && cell %in% c("lt", "gt", "ne")) {
    xa <- as.numeric(na)
    xb <- as.numeric(nb)
    ok <- switch(cell, lt = xa < xb, gt = xa > xb, ne = xa != xb)
  }
  isTRUE(ok)
}

# The rows of `new` that cover the gone check `b` (N131): each alone has B's key or implies B, runs always, has
# a level that can cover (fail, or B is warned) and is not rebound. A check that is not readable is covered
# only by one with the same text.
ck_cover_rows <- function(b, new) {
  if (!nrow(new)) return(integer())
  can <- which(new$always %in% TRUE & !(new$rebound %in% TRUE) & (new$level %in% "fail" | b$level %in% "warn"))
  if (!length(can)) return(integer())
  if (is.na(b$cond)) {
    return(can[is.na(new$cond[can]) & gate_ws(new$text[can]) == gate_ws(b$text)])
  }
  can <- can[!is.na(new$cond[can]) & (new$value[can] %in% c(b$value, b$other) | new$other[can] %in% c(b$value, b$other))]
  filt <- "filter" %in% names(b) && isTRUE(b$filter)
  can[vapply(can, function(i) check_implies(new[i, , drop = FALSE], b, filter = filt), NA)]
}

# Is the gone check `b` covered by the rows `new` of its document on the new side (N131)?
check_covered <- function(b, new) length(ck_cover_rows(b, new)) > 0L

# ---- checks() (N141 to N146) ---------------------------------------------------------------------------------------

#' Checks of one value, compared
#'
#' `checks()` lists every check a project's documents make on a value and groups them by value, so that a
#' value checked in several places with conditions that differ a little (`x > 5` here, `x >= 5` there) shows.
#' A check is a guard (each comma part of a one-arm `if`), a check argument of a [claim()], or, here only, a
#' comma part of a two-arm `if`, which chooses wording and fails nothing (a `branch`). Only checks weft can read
#' are compared: a comparison whose sides are names, dictionary reads, expressions such as `max(turbidity)` and
#' literals, or a bool name; the rest are listed under `not read`. Nothing in a document is run.
#'
#' A value is *flagged* when two of its checks compare it with the same other operand under operators that
#' differ only in strictness (`operators`), or with different literals in one direction (`literals`). The
#' report hints at checks made in `repeats` places or more with the same condition: check once, where the
#' value is made.
#'
#' @param path One existing file or folder. The project root is found from it.
#' @param files `NULL`, or documents (relative to the root or absolute under it) to report on.
#' @param repeats A whole number from 2: how many places make a hint.
#' @return A `weft_checks` data frame, one row per check, with columns `file`, `line`, `role`, `level`,
#'   `value`, `op`, `other`, `cond` (`NA` when the check is not readable), `text`, `always`, `rebound`, `flag`
#'   and `repeated`, and the attribute `notes`. Printing it shows the report.
#' @examples
#' dir <- file.path(tempdir(), "checks-example")
#' dir.create(dir, showWarnings = FALSE)
#' writeLines(c("The site [exceeded]{if=\"flow > limit\"} the limit.", "",
#'              "In March it [reached]{if=\"flow >= limit\"} the limit."), file.path(dir, "report.Rmd"))
#' checks(dir)
#' @export
checks <- function(path = ".", files = NULL, repeats = 3L) {
  if (!is.numeric(repeats) || length(repeats) != 1L || is.na(repeats) || !is.finite(repeats) ||
      repeats != round(repeats) || repeats < 2) {
    lint_abort("`repeats` must be a whole number from 2.")
  }
  repeats <- as.integer(repeats)
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    lint_abort("`path` must be one existing file or folder (rule 5.1.1).")
  }
  full <- normalizePath(path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(find_project_root(full), winslash = "/", mustWork = FALSE)
  all_files <- lint_files_under(root)
  files_rel <- NULL
  if (!is.null(files)) {
    if (!is.character(files) || anyNA(files)) lint_abort("`files` must be paths to .qmd or .Rmd documents.")
    absf <- ifelse(grepl("^(/|[A-Za-z]:)", files), files, file.path(root, files))
    nf <- normalizePath(absf, winslash = "/", mustWork = FALSE)
    prob <- !file.exists(absf) | !startsWith(nf, paste0(root, "/")) | !grepl("\\.(qmd|Rmd|rmd)$", files)
    if (any(prob)) {
      lint_abort(paste0("`files` must name existing .qmd or .Rmd documents under the project root; not so: ",
                        paste0("`", files[prob], "`", collapse = ", "), " (rule 5.1.1)."))
    }
    files_rel <- substring(nf, nchar(root) + 2L)
  }
  report <- all_files
  if (!dir.exists(full)) {
    report <- intersect(report, substring(full, nchar(root) + 2L))
  } else if (!identical(full, root)) {
    pre <- paste0(substring(full, nchar(root) + 2L), "/")
    report <- report[startsWith(report, pre)]
  }
  if (!is.null(files_rel)) report <- intersect(report, files_rel)
  report <- sort(report, method = "radix")
  notes <- character()
  parts <- list()
  n_docs <- 0L
  for (rel in report) {
    src <- lint_open(root, rel)
    if (isTRUE(src$invalid)) {
      notes <- c(notes, sprintf("%s is not valid UTF-8, so its checks were not read (rule 5.1.3).", rel))
      next
    }
    n_docs <- n_docs + 1L
    r <- checks_read(src)
    if (nrow(r)) {
      r$file <- rep(rel, nrow(r))
      parts[[length(parts) + 1L]] <- r
    }
  }
  x <- if (length(parts)) do.call(rbind, lapply(parts, function(p) p[, names(checks_empty()), drop = FALSE])) else checks_empty()
  rownames(x) <- NULL
  x <- ck_flags(x)
  x <- x[, c("file", "line", "role", "level", "value", "op", "other", "cond", "text", "always", "rebound", "flag", "repeated")]
  structure(x, class = c("weft_checks", "data.frame"), notes = notes, documents = n_docs, repeats = repeats)
}

# the `flag` of each row (N143) and its `repeated` (N144)
ck_flags <- function(x) {
  n <- nrow(x)
  x$flag <- rep("", n)
  x$repeated <- rep(NA_integer_, n)
  if (!n) return(x)
  rd <- which(!is.na(x$cond))
  if (length(rd)) {
    grp <- paste(x$file[rd], x$value[rd], sep = "\001")
    for (g in unique(grp)) {
      i <- rd[grp == g]
      combos <- unique(data.frame(op = x$op[i], other = x$other[i], stringsAsFactors = FALSE))
      m <- nrow(combos)
      flag_op <- FALSE
      flag_lit <- FALSE
      if (m > 1L) {
        kinds <- vapply(seq_len(m), function(j) ck_kind(combos$other[j], combos$op[j]), "")
        dir <- function(o) switch(o, "<" = , "<=" = "lt", ">" = , ">=" = "gt", "==" = "eq", is = "is", "none")
        for (a in seq_len(m - 1L)) for (b in (a + 1L):m) {
          oa <- combos$op[a]; ob <- combos$op[b]
          if (identical(combos$other[a], combos$other[b])) {
            if (!identical(oa, ob) && oa %in% c("<", "<=", ">", ">=") && identical(dir(oa), dir(ob))) flag_op <- TRUE
          } else if (identical(kinds[a], kinds[b]) && !identical(kinds[a], "value") && identical(dir(oa), dir(ob)) &&
                     dir(oa) != "none") {
            diff <- switch(sub(" .*$", "", kinds[a]),
                           number = , quantity = dec_cmp(ck_lit_num(combos$other[a], kinds[a]), ck_lit_num(combos$other[b], kinds[b])) != 0L,
                           TRUE)
            if (diff) flag_lit <- TRUE
          }
        }
      }
      fl <- paste(c(if (flag_op) "operators", if (flag_lit) "literals"), collapse = "; ")
      x$flag[i] <- fl
    }
    ok <- which(x$role != "branch" & !is.na(x$cond))
    k <- paste(x$file[ok], x$cond[ok], x$level[ok], sep = "\001")
    cnt <- table(k)
    x$repeated[ok] <- as.integer(cnt[k])
  }
  x
}

#' @param x A `weft_checks`.
#' @param ... Not used.
#' @rdname checks
#' @export
print.weft_checks <- function(x, ...) {
  cat(checks_print_lines(x), sep = "\n")
  invisible(x)
}

checks_print_lines <- function(x) {
  plural <- function(k, w) paste(k, if (k == 1L) w else paste0(w, "s"))
  nd <- attr(x, "documents") %||% length(unique(x$file))
  repeats <- attr(x, "repeats") %||% 3L
  if (!nrow(x)) return(sprintf("weft checks: no checks in %s", plural(nd, "document")))
  rd <- !is.na(x$cond)
  gk <- paste(x$file, x$value, sep = "\001")
  groups <- unique(gk[rd])
  flagged <- sum(vapply(groups, function(g) any(x$flag[rd & gk == g] != ""), NA))
  out <- c(sprintf("weft checks: %s of %s in %s; %s flagged", plural(nrow(x), "check"), plural(length(groups), "value"),
                   plural(nd, "document"), plural(flagged, "value")), "")
  lines_of <- function(l) {
    s <- if (length(l) > 10L) paste0(paste(l[1:10], collapse = ", "), ", and ", length(l) - 10L, " more") else paste(l, collapse = ", ")
    paste0(if (length(l) == 1L) "line " else "lines ", s)
  }
  for (f in unique(x$file)) {
    d <- x[x$file == f, , drop = FALSE]
    d$kind <- ifelse(d$role == "branch", "branch", ifelse(d$level == "fail", "check", "warn"))
    r <- !is.na(d$cond)
    shown <- ck_cut(d$cond)
    nr <- d[!r, , drop = FALSE]
    # the entries of each line, over the readable rows and the rows not read
    ent <- paste(shown, d$kind, sep = "\001")
    cnt <- table(ent[r])
    wn <- max(c(as.integer(cnt), if (nrow(nr)) as.integer(table(gate_ws(nr$text))) else 0L))
    w <- if (any(r)) max(nchar(shown[r])) else 0L
    out <- c(out, f)
    for (v in unique(d$value[r])) {
      i <- which(r & d$value == v)
      head <- paste0("  ", ck_cut(v))
      fl <- d$flag[i[1L]]
      if (nzchar(fl)) head <- paste0(head, "  [", fl, "]")
      if (any(d$rebound[i])) {
        is_expr <- !grepl("^[A-Za-z.][A-Za-z0-9._]*$|^dict(_local)?\\$", v)
        head <- paste0(head, if (is_expr) "  (reads a name assigned in more than one place)" else "  (assigned in more than one place)")
      }
      out <- c(out, head)
      for (e in unique(ent[i])) {
        j <- i[ent[i] == e]
        kind <- d$kind[j[1L]]
        out <- c(out, sprintf("    %-*s  %*d  %s%s", w, shown[j[1L]], nchar(as.character(wn)), length(j), lines_of(d$line[j]),
                              switch(kind, check = "", warn = "  (warn)", branch = "  (branch)")))
        if (kind == "check" && length(j) >= repeats) {
          out <- c(out, sprintf("      checked in %d places with the same condition: check it once where the value is made", length(j)))
        }
      }
    }
    if (nrow(nr)) {
      txt <- gate_ws(nr$text)
      cut <- ck_cut(txt)
      wu <- max(nchar(cut))
      out <- c(out, "  not read")
      for (tx in unique(txt)) {
        j <- which(txt == tx)
        out <- c(out, sprintf("    %-*s  %*d  %s", wu, cut[j[1L]], nchar(as.character(wn)), length(j), lines_of(nr$line[j])))
      }
    }
    out <- c(out, "")
  }
  out
}
