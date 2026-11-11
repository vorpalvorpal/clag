# Resolving a block of prose (rules 2.2, 1.2.6, 1.5, 2.6.8). The `text` hook
# hands each block here. The parked inline code is put back, the block is
# scanned with scan_block(), and the constructs are resolved from the scan in
# textual order; a governed span chooses its arm first and evaluates only what
# that arm holds (1.5.16).

owned_keys <- function() c(GOVERNOR_KEYS, RENDERER_KEYS, "why")

owned_classes <- function(cfg) {
  c(formatter_classes(cfg$formatters), TEXT_CLASSES, ".weft-literal")
}

# Under rmarkdown and under Quarto alike, `{r} x` reaches knitr as
# `r .QuartoInlineRender(x)`; a construct wants the expression as written.
unwrap_quarto <- function(expr) {
  sub("^\\.QuartoInlineRender\\((.*)\\)$", "\\1", expr)
}

# Put the parked code back in place of each placeholder. Returns the text and
# the position of each restored span.
restore_parked <- function(x, parked) {
  m <- gregexpr("\ue000[0-9]+\ue002", x, perl = TRUE)[[1]]
  none <- data.frame(start = integer(), end = integer(), idx = integer())
  if (m[1L] < 0L) return(list(text = x, spans = none))
  len <- attr(m, "match.length")
  starts <- as.integer(m)
  idx <- as.integer(substring(x, starts + 1L, starts + len - 2L))
  pieces <- character()
  sp_start <- integer()
  sp_end <- integer()
  cur <- 1L
  pos <- 1L
  for (k in seq_along(starts)) {
    lit <- substr(x, cur, starts[k] - 1L)
    src <- paste0("`r ", parked[[idx[k]]]$code, "`")
    pieces <- c(pieces, lit, src)
    pos <- pos + nchar(lit)
    sp_start <- c(sp_start, pos)
    sp_end <- c(sp_end, pos + nchar(src) - 1L)
    pos <- pos + nchar(src)
    cur <- starts[k] + len[k]
  }
  pieces <- c(pieces, substr(x, cur, nchar(x)))
  list(text = paste(pieces, collapse = ""),
       spans = data.frame(start = sp_start, end = sp_end, idx = idx))
}

# The conditions of an `if` value, as written: `a > 1, b` is two conditions.
split_args <- function(expr) {
  src <- paste0("list(", expr, ")")
  p <- parse(text = src, keep.source = TRUE)
  exprs <- as.list(p[[1L]])[-1L]
  pd <- utils::getParseData(p)
  top <- pd$id[pd$parent == 0L & pd$token == "expr"][1L]
  kids <- pd[pd$parent == top & pd$token == "expr", , drop = FALSE]
  kids <- kids[order(kids$line1, kids$col1), , drop = FALSE]
  texts <- if (nrow(kids) > 1L) {
    vapply(kids$id[-1L], function(i) paste(utils::getParseText(pd, i), collapse = " "), "")
  } else character()
  if (length(texts) != length(exprs)) {
    texts <- vapply(exprs, function(e) paste(deparse(e, width.cutoff = 500L), collapse = " "), "")
  }
  list(exprs = exprs, texts = texts)
}

fill_template <- function(tmpl, hash, outs, gov = logical(length(outs))) {
  m <- gregexpr("\ue001|\ue002[0-9]+\ue003", tmpl, perl = TRUE)[[1L]]
  if (m[1L] < 0L) return(tmpl)
  tok <- regmatches(tmpl, list(m))[[1L]]
  lit <- regmatches(tmpl, list(m), invert = TRUE)[[1L]]
  idx <- vapply(tok, function(t) {
    if (identical(t, "\ue001")) NA_integer_ else as.integer(substring(t, 2L, nchar(t) - 1L))
  }, 0L, USE.NAMES = FALSE)
  rep <- ifelse(is.na(idx), hash, unlist(outs)[idx])
  join_pieces(lit, rep, !is.na(idx) & gov[idx])
}

# `gaps` (one more than `outs`) are the text between the printed pieces. A
# governed span that printed nothing takes one adjacent space with it
# (1.5.12): the space before it when a space, the end of the text or one of
# `. , ; : ! ? ) ]`, a closing quotation mark (U+201D, U+2019) or an em dash follows; at the start of a block, the space after it. A
# space is one space or one line break.
join_pieces <- function(gaps, outs, gov) {
  n <- length(outs)
  acc <- ""
  for (i in seq_len(n)) {
    acc <- paste0(acc, gaps[i])
    o <- outs[i]
    if (!gov[i] || nzchar(o)) {
      acc <- paste0(acc, o)
      next
    }
    rest <- gaps[i + 1L]
    nxt <- if (nzchar(rest)) rest else if (i < n) outs[i + 1L] else ""
    post <- if (!nzchar(nxt) || (i == n && grepl("^[ \t]*$", rest)) ||
                grepl("^[ \t]*\n[ \t]*\n", rest)) {
      "end"
    } else if (grepl("^[ \n]", nxt)) {
      "space"
    } else if (grepl("^[].,;:!?)\u201d\u2019\u2014]", nxt)) {
      "punct"
    } else "other"
    start <- grepl("^\\s*$", acc) || grepl("\n[ \t]*\n[ \t]*$", acc) ||
      grepl("(^|\n)[ \t]*((#{1,6}|[-*+]|[0-9]+[.)]|>|:)[ \t]+)+$", acc)
    if (start) {
      if (post == "space" && nzchar(rest)) gaps[i + 1L] <- substring(rest, 2L)
    } else if (post != "other" && grepl("[ \n]$", acc)) {
      acc <- substr(acc, 1L, nchar(acc) - 1L)
    }
  }
  paste0(acc, gaps[n + 1L])
}

# What stock knitr prints for an inline value (rule 1.3.1).
stock_print <- function(v) {
  res <- knitr::knit_print(v, inline = TRUE, options = knitr::opts_chunk$get())
  finish_stock(res, "the value")
}

finish_stock <- function(res, what) {
  if (inherits(res, c("knit_asis", "knit_asis_url"))) res <- knitr::sew(res, inline = TRUE)
  tryCatch(as.character(res), error = function(e) {
    stop("The inline value cannot be coerced to character: ", what, call. = FALSE)
  })
  if (length(res)) paste(knitr::knit_hooks$get("inline")(res), collapse = "") else ""
}

# knitr evaluates inline code in `root.dir` when one is set (1.3.1, 2.2.3);
# weft evaluates later, from the `text` hook, so it goes there itself.
in_knit_dir <- function(expr) {
  root <- knitr::opts_knit$get("root.dir")
  if (is.character(root) && length(root) == 1L && !is.na(root) && nzchar(root) &&
      dir.exists(root)) {
    old <- setwd(root)
    on.exit(setwd(old), add = TRUE)
  }
  expr
}

# Evaluate one piece of inline code with the claim context set, the
# conditions it raises logged and kept out of the document (2.6.4, 2.8).
run_inline <- function(s, file, line, label, expr, run, chunk = NA_character_,
                       option = NA_character_, live = TRUE) {
  old <- weft_env$inline
  weft_env$inline <- list(file = file, line = line, label = label, expr = expr,
                          failed = FALSE, chunk = chunk, option = option)
  on.exit(weft_env$inline <- old, add = TRUE)
  if (!live) {
    # outside a knit (strict): nothing is collected and no condition is hidden
    out <- tryCatch(list(ok = TRUE, value = in_knit_dir(run())),
                    error = function(e) list(ok = FALSE, error = e))
    out$claim_failed <- FALSE
    return(out)
  }
  src <- sprintf("%s:%d", file, line)
  out <- withCallingHandlers(
    tryCatch(
      list(ok = TRUE, value = in_knit_dir(run())),
      error = function(e) list(ok = FALSE, error = e)),
    warning = function(w) {
      log_condition(s, src, "warning", conditionMessage(w), file = file, line = line)
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      log_condition(s, src, "message", conditionMessage(m), file = file, line = line)
      invokeRestart("muffleMessage")
    })
  out$claim_failed <- isTRUE(weft_env$inline$failed)
  out
}

stock_bare_text <- function(code, envir) {
  ev <- weft_env$stock_eval %||% knitr::knit_hooks$get("evaluate.inline", default = TRUE)
  finish_stock(ev(code, envir), code)
}

check_governor <- function(v, what = "An `n` governor") {
  hint <- "write `length(x)` to count the elements of a vector (rule 1.5.11)"
  if (length(v) == 0L) return(list(kind = "no value", detail = paste0(what, " has length zero.")))
  if (inherits(v, "weft_text")) {
    if (length(v) != 1L) return(list(kind = "value error", detail = paste0(what, " must be a single number; ", hint)))
    if (is.na(attr(v, "number"))) return(list(kind = "no value", detail = paste0(what, " has no number.")))
    return(NULL)
  }
  if (length(v) != 1L || is.list(v)) {
    return(list(kind = "value error", detail = paste0(what, " must be a single number, not a vector; ", hint)))
  }
  if (is.numeric(v)) {
    if (!is.finite(v)) return(list(kind = "no value", detail = paste0(what, " is missing (NA, NaN or Inf).")))
    return(NULL)
  }
  if (is.na(v)) return(list(kind = "no value", detail = paste0(what, " is missing (NA).")))
  list(kind = "value error", detail = paste0(what, " must be a number, not a ", class(v)[1L], "; ", hint))
}

# ---- one block ------------------------------------------------------------------

resolve_text <- function(x) {
  s <- ensure_knit()
  # the next block's inline code starts a new run of values evaluated early
  on.exit(s$eager_ok <- TRUE, add = TRUE)
  settle_pending(s)
  x <- enc2utf8(paste(as.character(x), collapse = "\n"))
  if (!grepl("\ue000", x, fixed = TRUE) && !grepl("[", x, fixed = TRUE) &&
      !grepl("]{", x, fixed = TRUE)) return(x)
  resolve_markup(s, x, block = locate_block(s, x))
}

# Resolve one piece of markup. `block` is the located block of prose the
# `text` hook hands over (its inline code is parked as placeholders). With no
# `block` the markup is a string (a caption, or the argument of weft_str()):
# `ctx` names its chunk and option, the environment its code is evaluated in,
# and whether a failure stops at once (`strict`, outside a knit, 3.6.3) or is
# collected (2.4.1).
resolve_markup <- function(s, x, block = NULL, ctx = NULL) {
  cfg <- s$config
  is_str <- is.null(block)
  strict <- is_str && isTRUE(ctx$strict)
  loc <- if (is_str) list(F = NULL, start = 1L) else block
  F <- loc$F
  restored <- restore_parked(x, s$parked)
  text <- restored$text
  spans <- restored$spans
  sb <- scan_block(if (is_str) text else mask_front_matter(text), file = NA_character_,
                   first_line = loc$start, config = cfg)
  S <- sb$S
  R <- sb$rows
  nr <- nrow(R)
  R$line_view <- R$line
  if (nr && !is_str) {
    ml <- map_lines(F, R$line_view)
    R$file <- ml$file
    R$line <- ml$line
  } else if (nr) {
    R$file <- rep(as.character(ctx$file %||% current_file_name(s)), nr)
    R$line <- rep(as.integer(ctx$line %||% NA_integer_), nr)
    R$line_view <- rep(NA_integer_, nr)
  }
  # the errors about ids belong to the whole document (1.7.10)
  if (nr && !is_str && !is.null(F) && !is.null(F$id_errors) && nrow(F$id_errors)) {
    m <- match(row_keys(R$line_view, R$kind), F$id_errors$key)
    hit <- !is.na(m)
    if (any(hit)) {
      R$error[hit] <- ifelse(is.na(R$error[hit]), F$id_errors$error[m[hit]],
                             paste(R$error[hit], F$id_errors$error[m[hit]], sep = "\n"))
    }
  }
  R$context <- rep(if (is_str) (ctx$context %||% "weft_str") else "prose", nr)
  R$chunk <- rep(if (is_str) as.character(ctx$chunk %||% NA_character_) else NA_character_, nr)
  R$option <- rep(if (is_str) as.character(ctx$option %||% NA_character_) else NA_character_, nr)
  R$evaluated <- rep(FALSE, nr)
  R$chosen <- rep(NA_integer_, nr)
  env0 <- if (is_str) (ctx$envir %||% knitr::knit_global()) else knitr::knit_global()
  nlpos <- which(strsplit(text, "")[[1L]] == "\n")
  span_line <- function(start) {
    if (is_str) return(data.frame(file = as.character(ctx$file %||% current_file_name(s)),
                                  line = as.integer(ctx$line %||% NA_integer_),
                                  stringsAsFactors = FALSE))
    lv <- loc$start + sum(nlpos < start)
    map_lines(F, lv)
  }
  draft <- isTRUE(cfg$draft)
  # text knitted by a child has no file: its lines are relative to the text,
  # and the chunk that knitted it says where (2.7.3)
  chunk_label <- if (is_str) as.character(ctx$chunk %||% NA_character_) else if (is.null(F) && is_child_knit()) {
    lab <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    if (is.character(lab) && length(lab) == 1L) lab else NA_character_
  } else NA_character_
  owned <- owned_classes(cfg)
  gov <- NULL

  on.exit({
    if (nr) {
      # the place of a span among the spans of its line (or of its string) that
      # read alike, so a rehearsal can tell them apart (3.7.3)
      grp <- paste(R$context, R$line, R$chunk, gsub("-", ".", R$option, fixed = TRUE),
                   R$kind, R$expr, sep = "\r")
      R$ord <- as.integer(stats::ave(seq_len(nr), grp, FUN = seq_along))
      s$constructs[[length(s$constructs) + 1L]] <- R
      if (!is.null(F)) {
        top <- is.na(R$parent) & !(R$kind %in% c("bare", "link"))
        F$recorded <- c(F$recorded, paste(R$kind[top], R$line_view[top]))
      }
    }
  }, add = TRUE)

  loc_str <- function(k) {
    if (!is_str) return(sprintf("%s:%d", R$file[k], R$line[k]))
    if (!is.null(ctx$line) && !is.na(ctx$line)) return(sprintf("%s:%d", R$file[k], R$line[k]))
    str_where(ctx$chunk, ctx$option)
  }

  # construct errors found from the source stop the render at once (2.6.5),
  # except in draft mode, where each becomes a marker where it would print
  if ((!draft || strict) && nr && any(!is.na(R$error))) {
    k <- which(!is.na(R$error))[1L]
    R$evaluated[k] <- TRUE
    weft_abort(sprintf("weft: %s: %s", loc_str(k), R$error[k]),
               c("weft_construct_error", "weft_located"))
  }

  construct_fail <- function(k, msg) {
    if (!draft || strict) {
      weft_abort(sprintf("weft: %s: %s", loc_str(k), msg),
                 c("weft_construct_error", "weft_located"))
    }
    add_failure(s, "construct error", file = R$file[k], line = R$line[k],
                expr = source_label(k), detail = msg, chunk = chunk_label,
                option = ctx$option)
    marker("construct error", R$line[k], chunk_label)
  }

  # a number that printed as zero (stage 1i): a warned check at the construct,
  # a warning outside a knit
  zero_note <- function(k, label) {
    function(msg) {
      if (strict) {
        rlang::warn(paste0("weft: ", msg), class = "weft_zero_warning")
      } else {
        add_warning(s, "printed as zero", file = R$file[k], line = R$line[k], expr = label,
                    detail = msg, chunk = chunk_label,
                    option = if (is_str) ctx$option else NA_character_)
      }
      invisible(NULL)
    }
  }

  # the label of a record made inside a governed span: its governor expression
  gov_label <- function(k) trim_ws(gsub("[ \t\r\n]+", " ", R$expr[k]))

  source_label <- function(k) {
    t <- substr(text, R$start[k], R$end[k])
    t <- gsub("[ \t\r\n]+", " ", t)
    if (nchar(t) > 70L) t <- paste0(substr(t, 1L, 67L), "...")
    t
  }

  record_fail <- function(k, kind, label, detail, hint = NA_character_) {
    if (strict) {
      weft_abort(sprintf("weft: %s: %s", loc_str(k), detail),
                 switch(kind, `failed claim` = "weft_claim_failed",
                        `no value` = "weft_no_value", "weft_value_error"))
    }
    add_failure(s, kind, file = R$file[k], line = R$line[k], expr = label,
                detail = detail, hint = hint, chunk = chunk_label,
                option = if (is_str) ctx$option else NA_character_)
    marker(kind, R$line[k], chunk_label)
  }

  # a condition raised by the expression, or an error it raised (2.6.4, 2.6.9)
  fail_from_error <- function(k, e, label) {
    if (strict && !inherits(e, "weft_construct_error")) {
      if (inherits(e, c("weft_claim_failed", "weft_no_value", "weft_value_error"))) stop(e)
      # an expression that cannot be evaluated is a missing value (2.6.4, 2.6.8)
      return(record_fail(k, "no value", label,
                         sprintf("error evaluating %s: %s", label, conditionMessage(e))))
    }
    if (inherits(e, "weft_construct_error")) return(construct_fail(k, conditionMessage(e)))
    if (inherits(e, "weft_no_value")) {
      return(record_fail(k, "no value", label, conditionMessage(e)))
    }
    if (inherits(e, "weft_value_error")) {
      return(record_fail(k, "value error", label, conditionMessage(e)))
    }
    record_fail(k, "no value", label,
                sprintf("error evaluating %s: %s", label, conditionMessage(e)))
  }

  eval_expr <- function(k, expr, label, envir = env0, stock = FALSE,
                        line_info = NULL) {
    file <- if (is.null(line_info)) R$file[k] else line_info$file
    line <- if (is.null(line_info)) R$line[k] else line_info$line
    run_inline(s, file, line, label, expr, function() {
      if (stock) stock_bare_text(expr, envir) else
        eval(parse(text = expr, keep.source = FALSE), envir)
    }, chunk = chunk_label, option = if (is_str) ctx$option else NA_character_,
    live = !strict)
  }

  non_english <- function() {
    l <- tolower(sub("[-_].*$", "", s$lang %||% ""))
    nzchar(l) && l != "en"
  }
  lang_check <- function(k, classes, keys, n_arms = 1L) {
    if (!non_english()) return(NULL)
    expr <- R$expr[k]
    ph <- if (R$kind[k] %in% c("value", "n", "sign", "list") && !is.na(expr)) {
      regmatches(expr, regexpr("\\b(of_n|about|ci)[ \t]*\\(", expr, perl = TRUE))
    } else character()
    if (length(ph)) {
      return(sprintf(paste0("`%s()` prints English words, and the document's `lang` is `%s` ",
                            "(rule 1.6.8)."), sub("[ \t]*\\($", "", ph), s$lang))
    }
    if (R$kind[k] %in% c("n", "list") && n_arms > 1L) {
      return(sprintf(paste0("A `%s` span with more than one arm needs the plural rules of `%s`, ",
                            "which weft does not ship; English rules are never applied to another ",
                            "language (rules 1.6.5, 1.6.7)."), R$kind[k], s$lang))
    }
    eng <- c(".no", WORDING_CLASSES, ".and", ".or", ".pairs", ".range", ".a", ".date", ".uname")
    bad <- intersect(classes, eng)
    if (length(bad) || "trunc" %in% names(keys)) {
      return(sprintf(paste0("The class `%s` prints English words, and the document's `lang` is ",
                            "`%s` (rule 1.6.8)."), c(bad, "trunc")[1L], s$lang))
    }
    NULL
  }

  split_classes <- function(k) {
    cl <- R$classes[[k]]
    ky <- R$keys[[k]]
    list(own = intersect(cl, owned),
         pass = setdiff(cl, owned),
         keys = ky,
         pass_keys = ky[!(names(ky) %in% owned_keys())])
  }

  apply_text_classes <- function(text, own) {
    reg <- cfg$formatters
    tcl <- own[own %in% c(".a", ".cap", ".em", ".strong") |
                 vapply(own, function(c) identical((reg[[c]] %||% list())[["stage"]], "text"), NA)]
    if (!length(tcl) || !nzchar(text)) return(text)
    as.character(apply_formatters(text, tcl, list(), cfg))
  }

  passthrough <- function(text, cl, ky) {
    if (!nzchar(text)) return(text)
    items <- c(cl, if (length(ky)) sprintf("%s=\"%s\"", names(ky), unname(ky)))
    if (!length(items)) return(text)
    sprintf("[%s]{%s}", text, paste(items, collapse = " "))
  }

  finish <- function(k, text, cc, claim_failed, text_classes = TRUE) {
    if (text_classes) text <- apply_text_classes(text, cc$own)
    text <- passthrough(text, cc$pass, cc$pass_keys)
    if (claim_failed) text <- paste0(text, marker("failed claim", R$line[k], chunk_label))
    text
  }

  # ---- items of a range ------------------------------------------------------

  range_items <- function(a, b, kid_ids) {
    items <- lapply(kid_ids, function(k) list(type = "row", k = k, start = R$start[k], end = R$end[k]))
    if (nrow(spans)) {
      for (i in seq_len(nrow(spans))) {
        st <- spans$start[i]
        if (st < a || st > b || st %in% R$start) next
        if (any(vapply(items, function(it) st >= it$start && st <= it$end, NA))) next
        items[[length(items) + 1L]] <- list(type = "span", idx = spans$idx[i],
                                           start = st, end = spans$end[i])
      }
    }
    if (length(items)) items <- items[order(vapply(items, function(it) it$start, 0L))]
    items
  }

  # Sentence starts (5.10.1): a value or span of the prose whose printed text
  # opens a sentence with a digit or a lower-case letter.
  starts_sentence <- function(st) {
    pre <- substr(text, 1L, st - 1L)
    if (!nzchar(trim_ws(pre))) return(TRUE)
    # after the end of a sentence
    if (grepl("[.?!][]\"')*_~]*[ \t\n]+$", pre)) return(TRUE)
    # a new paragraph
    if (grepl("\n[ \t]*\n[ \t]*$", pre)) return(TRUE)
    # after a heading or list marker
    last <- sub("^.*\n", "", pre)
    grepl("^[ \t]*((#{1,6}|[-*+]|[0-9]+[.)]|>|:)[ \t]+)+$", last)
  }
  note_sentence <- function(it, out) {
    if (is_str || !nzchar(out)) return("")
    body <- sub("^[*_\\[]+", "", out)
    if (!grepl("^[0-9[:lower:]]", body)) return("")
    if (!starts_sentence(it$start)) return("")
    if (it$type == "span") {
      li <- span_line(it$start)
      expr <- s$parked[[it$idx]]$code
      file <- li$file
      line <- li$line
    } else {
      expr <- R$expr[it$k]
      if (R$kind[it$k] == "if") {
        expr <- sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", trim_ws(out)))
      } else if (R$kind[it$k] %in% c("text", "cite", "literal")) {
        expr <- source_label(it$k)
      }
      file <- R$file[it$k]
      line <- R$line[it$k]
    }
    s$sentence_starts[[length(s$sentence_starts) + 1L]] <- list(
      file = as.character(file), line = as.integer(line),
      expr = as.character(expr), text = out)
    if (isTRUE(cfg$sentence_start_fail)) {
      add_failure(s, "sentence start", file = file, line = line, expr = as.character(expr),
                  detail = sprintf("a printed \"%s\" opens a sentence; write .cap (with .count or .word for a number) (rule 5.10.1)", out),
                  chunk = chunk_label)
      return(marker("sentence start", line, chunk_label))
    }
    ""
  }

  # `n`, `if` and `sign` spans: when one prints nothing, one adjacent space
  # goes with it (1.5.12, stage 1g)
  governed <- function(it) it$type == "row" && R$kind[it$k] %in% c("n", "if", "sign", "list")

  render_plain <- function(a, b, items, top = FALSE) {
    outs <- character()
    prev <- ""
    for (it in items) {
      o <- render_item(it)
      if (top && (it$type == "span" ||
                  R$kind[it$k] %in% c("bare", "value", "n", "if", "sign", "list", "text", "cite", "literal"))) {
        o <- paste0(o, note_sentence(it, o))
      }
      outs <- c(outs, o)
    }
    gaps <- character(length(items) + 1L)
    cur <- a
    for (i in seq_along(items)) {
      it <- items[[i]]
      gaps[i] <- substr(text, cur, it$start - 1L)
      # two emphasis constructs side by side would read as `*a**b*`; an empty
      # comment keeps the delimiters apart (1.4.3)
      if (i > 1L && it$start == cur && endsWith(outs[i - 1L], "*") && startsWith(outs[i], "*")) {
        outs[i] <- paste0("<!-- -->", outs[i])
      }
      cur <- it$end + 1L
    }
    gaps[length(items) + 1L] <- substr(text, cur, b)
    join_pieces(gaps, outs, vapply(items, governed, NA))
  }

  arm_range <- function(k, i) {
    body_a <- R$start[k] + 1L
    body_b <- R$block_start[k] - 2L
    seps <- R$sep_pos[[k]]
    n <- length(R$arms[[k]])
    # a separator written `\|` starts at its backslash
    past <- function(p) p + if (identical(S$chars[p], "\\")) 2L else 1L
    list(a = if (i == 1L) body_a else past(seps[i - 1L]),
         b = if (i == n) body_b else seps[i] - 1L)
  }

  render_arm <- function(k, i, hash, record = NULL) {
    r <- arm_range(k, i)
    items <- range_items(r$a, r$b, which(R$parent == k & R$arm %in% i))
    old <- gov
    if (!is.null(record)) gov <<- record
    on.exit(gov <<- old, add = TRUE)
    outs <- vapply(items, render_item, "")
    idf <- data.frame(start = vapply(items, function(it) it$start, 0L),
                      end = vapply(items, function(it) it$end, 0L))
    tmpl <- arm_template_range(S, r$a, r$b, idf)
    fill_template(tmpl, hash, as.list(outs), vapply(items, governed, NA))
  }

  # ---- the constructs ----------------------------------------------------------

  render_bare <- function(k, idx = NULL, line_info = NULL, start = NULL) {
    st <- if (is.null(start)) R$start[k] else start
    if (is.null(idx)) idx <- spans$idx[match(st, spans$start)]
    p <- s$parked[[idx]]
    label <- sprintf("`r %s`", p$code)
    # a bare value ahead of every construct in its block was evaluated when
    # knitr parked it, so that an error there names its own line (1.1.8)
    ev <- p$result %||% eval_expr(k, p$code, label, p$envir, stock = TRUE,
                                  line_info = line_info)
    if (!is.null(p$result)) s$parked[[idx]]$result <- NULL
    li <- if (is.null(line_info)) list(file = R$file[k], line = R$line[k]) else line_info
    if (!ev$ok) {
      e <- ev$error
      if (inherits(e, c("weft_no_value", "weft_value_error")) && !is.na(k)) {
        return(fail_from_error(k, e, label))
      }
      stop(e)
    }
    if (ev$claim_failed) paste0(ev$value, marker("failed claim", li$line, chunk_label)) else ev$value
  }

  render_value <- function(k) {
    cc <- split_classes(k)
    expr <- unwrap_quarto(R$expr[k])
    msg <- lang_check(k, cc$own, cc$keys)
    if (!is.null(msg)) return(construct_fail(k, msg))
    idx <- spans$idx[match(R$start[k], spans$start)]
    label <- sprintf("`r %s`", expr)
    ev <- eval_expr(k, expr, label, s$parked[[idx]]$envir)
    if (!ev$ok) return(fail_from_error(k, ev$error, label))
    v <- ev$value
    reg <- cfg$formatters
    # `.a` applies to numbers and number words only (1.4.5): a number it
    # meets is printed as `.num` prints it
    has_fmt <- any(!is.na(class_group(cc$own, reg))) || ".no" %in% cc$own ||
      ".a" %in% cc$own || any(c("digits", "sigfig", "unit", "trunc") %in% names(cc$keys)) ||
      (length(cc$own) > 0L && inherits(v, "units"))   # a text class acts on a quantity with its unit (4.4.2)
    own <- cc$own
    res <- tryCatch({
      if (has_fmt) {
        paste(as.character(apply_formatters(v, own, as.list(cc$keys), cfg, join = ", ",
                                            on_zero = zero_note(k, label))), collapse = "")
      } else {
        apply_text_classes(stock_print(v), cc$own)
      }
    }, error = function(e) e)
    if (inherits(res, "error")) return(fail_from_error(k, res, label))
    register_id(k, v, cc)
    finish(k, res, cc, ev$claim_failed, text_classes = FALSE)
  }

  # ---- ids and back-references (1.7) ---------------------------------------

  # The printed record of a governor value under the default class (1.5.18),
  # or the value's own record when it is one.
  governor_record <- function(v, cc) {
    if (inherits(v, "weft_text")) {
      return(if (length(v) == 1L) v else NULL)
    }
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v)) return(NULL)
    tryCatch(apply_formatters(v, cc$own, as.list(cc$keys), cfg, governor = TRUE),
             error = function(e) NULL)
  }

  raw_of <- function(v) {
    if (inherits(v, "weft_text")) {
      r <- attr(v, "raw")
      return(if (is.numeric(r) && length(r) == 1L) r else NA_real_)
    }
    if (is.numeric(v) && length(v) == 1L) as.numeric(v) else NA_real_
  }

  register_id <- function(k, v, cc, rec = NULL) {
    id <- R$id[k]
    if (is.na(id) || !nzchar(id)) return(invisible())
    if (is.null(rec)) rec <- governor_record(v, cc)
    s$ids[[id]] <- list(rec = rec, raw = raw_of(v), loc = id_loc(k))
    invisible()
  }

  # where an id was defined, so the same construct met again is not a second
  # definition, while another one is (1.7.5, over the document as knitted)
  id_loc <- function(k) paste(R$file[k], R$line[k], R$context[k], R$start[k])

  has_id <- function(k) {
    R$kind[k] %in% c("value", "n", "if", "sign", "list") && !is.na(R$id[k]) && nzchar(R$id[k])
  }

  # Where a back-reference gets its value (1.7.6 to 1.7.8): the printed record
  # of the occurrence, or, when the span has a formatter of its own, the raw
  # value formatted afresh. Returns a list with `stop` (a marker) or `v`.
  backref_value <- function(k, expr, label, own_fmt) {
    id <- sub("^#", "", trim_ws(expr))
    ent <- s$ids[[id]]
    if (is.null(ent)) {
      return(list(stop = construct_fail(k, sprintf(
        "The id `#%s` is not defined before this span, or its arm was not chosen (rule 1.7.10).", id))))
    }
    if (isTRUE(ent$failed)) {
      return(list(stop = record_fail(k, "no value", label, sprintf(
        "The id `#%s` was defined by a value that failed, so it has no value (rule 1.7.10).", id))))
    }
    if (own_fmt) {
      if (is.na(ent$raw)) {
        return(list(stop = record_fail(k, "value error", label, sprintf(
          "The id `#%s` has no number to format afresh (rule 1.7.8).", id))))
      }
      return(list(v = ent$raw, claim_failed = FALSE))
    }
    if (is.null(ent$rec)) {
      return(list(stop = record_fail(k, "value error", label, sprintf(
        "The id `#%s` has no printed number (rule 1.7.8).", id))))
    }
    list(v = ent$rec, claim_failed = FALSE)
  }

  has_own_format <- function(cc) {
    any(!is.na(class_group(cc$own, cfg$formatters))) || ".no" %in% cc$own ||
      any(c("digits", "sigfig", "unit") %in% names(cc$keys))
  }

  # The governor of an `n` or `sign` span: a value to read the number from.
  # Returns a list with `stop` (a marker, when it failed) or `v`.
  get_governor <- function(k, label, cc) {
    expr <- R$expr[k]
    own_fmt <- has_own_format(cc)
    if (R$kind[k] == "n" && identical(trim_ws(expr), ".")) {
      if (is.null(gov)) {
        return(list(stop = construct_fail(k, "`n=\".\"` outside an `n` or `sign` span (rule 1.7.2).")))
      }
      return(list(v = gov, claim_failed = FALSE, inherit = TRUE))
    }
    if (is_backref(expr)) return(backref_value(k, expr, label, own_fmt))
    ev <- eval_expr(k, expr, gov_label(k))
    if (!ev$ok) return(list(stop = fail_from_error(k, ev$error, label)))
    list(v = ev$value, claim_failed = ev$claim_failed)
  }

  render_n <- function(k) {
    cc <- split_classes(k)
    arms <- R$arms[[k]]
    narms <- length(arms)
    msg <- lang_check(k, cc$own, cc$keys, narms)
    if (!is.null(msg)) return(construct_fail(k, msg))
    label <- sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", arms[1L]))
    g <- get_governor(k, label, cc)
    if (!is.null(g$stop)) return(g$stop)
    v <- g$v
    claim_failed <- g$claim_failed
    own_fmt <- has_own_format(cc)
    # a range of two ends is one governor (1.5.11)
    if (!(".range" %in% cc$own)) {
      chk <- check_governor(v)
      if (!is.null(chk)) return(record_fail(k, chk$kind, label, chk$detail))
    }
    rec <- if (inherits(v, "weft_text") && !own_fmt && !(".range" %in% cc$own)) v else tryCatch(
      apply_formatters(v, cc$own, as.list(cc$keys), cfg, governor = TRUE),
      error = function(e) e)
    if (inherits(rec, "error")) return(fail_from_error(k, rec, label))
    register_id(k, v, cc, rec)
    i <- choose_arm_n(rec, narms)
    R$chosen[k] <<- i
    out <- render_arm(k, i, as.character(rec)[1L], record = rec)
    finish(k, out, cc, claim_failed)
  }

  # The magnitude of a printed change, without its sign (1.5.8): the record
  # of the number as printed, or of its absolute value when the span
  # formats the raw value.
  render_sign <- function(k) {
    cc <- split_classes(k)
    arms <- R$arms[[k]]
    narms <- length(arms)
    msg <- lang_check(k, cc$own, cc$keys, narms)
    if (!is.null(msg)) return(construct_fail(k, msg))
    label <- sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", arms[1L]))
    g <- get_governor(k, label, cc)
    if (!is.null(g$stop)) return(g$stop)
    v <- g$v
    claim_failed <- g$claim_failed
    chk <- check_governor(v)
    if (!is.null(chk)) return(record_fail(k, chk$kind, label, chk$detail))
    own_fmt <- has_own_format(cc)
    rec <- if (inherits(v, "weft_text") && !own_fmt) {
      v
    } else {
      # the sign is judged on the number as printed; wording classes and the
      # magnitude are read from the absolute value
      judge <- setdiff(cc$own, c(".no", WORDING_CLASSES))
      tryCatch(apply_formatters(v, judge, as.list(cc$keys), cfg, governor = TRUE),
               error = function(e) e)
    }
    if (inherits(rec, "error")) return(fail_from_error(k, rec, label))
    num <- attr(rec, "number")[1L]
    if (!identical(attr(rec, "relation")[1L], "=")) {
      return(record_fail(k, "value error", label, sprintf(
        "A `sign` governor that prints as a bound (\"%s\") has no magnitude to print (rule 1.5.17); write that case with `if`.",
        as.character(rec)[1L])))
    }
    if (is.na(num)) {
      return(record_fail(k, "value error", label, "A `sign` governor needs a number, and this has none."))
    }
    i <- if (num > 0) 1L else if (num < 0) 2L else 3L
    if (i == 3L && narms == 2L) {
      return(record_fail(k, "failed claim", label, sprintf(
        "the value printed as \"%s\", which is zero, and a two-arm `sign` has no arm for zero (rule 1.5.3)",
        as.character(rec)[1L]), hint = "add a third arm for zero"))
    }
    mag <- if (inherits(v, "weft_text") && !own_fmt) {
      txt <- as.character(rec)[1L]
      if (num < 0 && startsWith(txt, cfg$minus)) txt <- substring(txt, nchar(cfg$minus) + 1L)
      new_weft_text(txt, abs(num), attr(rec, "decimals")[1L], "=", abs(raw_of(v)))
    } else {
      tryCatch(apply_formatters(abs(if (inherits(v, "weft_text")) raw_of(v) else v),
                                cc$own, as.list(cc$keys), cfg, governor = TRUE),
               error = function(e) e)
    }
    if (inherits(mag, "error")) return(fail_from_error(k, mag, label))
    register_id(k, v, cc, rec)
    R$chosen[k] <<- i
    out <- render_arm(k, i, as.character(mag)[1L], record = mag)
    finish(k, out, cc, claim_failed)
  }

  # A `list` span (stage 1h): the governor is an atomic vector, the arm is
  # chosen by its length as `n` chooses by a count, and `#` is the vector
  # collapsed as `.and` collapses it.
  render_list <- function(k) {
    cc <- split_classes(k)
    arms <- R$arms[[k]]
    narms <- length(arms)
    msg <- lang_check(k, cc$own, cc$keys, narms)
    if (!is.null(msg)) return(construct_fail(k, msg))
    label <- sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", arms[1L]))
    ev <- eval_expr(k, R$expr[k], gov_label(k))
    if (!ev$ok) return(fail_from_error(k, ev$error, label))
    v <- ev$value
    claim_failed <- ev$claim_failed
    if (is.null(v) || !is.atomic(v) || !is.null(dim(v))) {
      return(record_fail(k, "no value", label, paste0(
        "A `list` governor must be an atomic vector (NULL, an R list, a data frame, a matrix and an array are not); ",
        "NULL is not an empty list.")))
    }
    if (anyNA(v)) {
      return(record_fail(k, "no value", label, "A `list` governor has a missing element (NA)."))
    }
    len <- length(v)
    if (len == 0L && narms == 2L) {
      return(record_fail(k, "failed claim", label, paste0(
        "the list is empty, and a two-arm `list` span has no arm for the empty case (rule 1.5.3); ",
        "add a first arm for the empty case"), hint = "add a first arm for the empty case"))
    }
    hash <- ""
    if (len > 0L) {
      reg <- cfg$formatters
      is_text <- cc$own %in% c(".a", ".cap", ".em", ".strong") |
        vapply(cc$own, function(c) identical((reg[[c]] %||% list())[["stage"]], "text"), NA)
      fcl <- cc$own[!is_text]
      if (!length(intersect(fcl, c(COLLAPSE_CLASSES, names(reg)[vapply(
          reg, function(r) identical(r[["stage"]], "collapse"), NA)])))) fcl <- c(fcl, ".and")
      # a number vector with no number or wording class prints each element as
      # a bare value prints
      if (is.numeric(v) && !inherits(v, "units") && !has_own_format(cc)) {
        v <- stats::setNames(vapply(v, stock_print, ""), names(v))
      }
      out <- tryCatch(
        paste(as.character(apply_formatters(v, fcl, as.list(cc$keys), cfg, join = ", ",
                                            on_zero = zero_note(k, gov_label(k)))), collapse = ""),
        error = function(e) e)
      if (inherits(out, "error")) return(fail_from_error(k, out, label))
      hash <- out
    }
    rec <- new_weft_text(as.character(len), len, FALSE, "=", len)
    i <- choose_arm_n(rec, narms)
    R$chosen[k] <<- i
    out <- render_arm(k, i, hash, record = rec)
    finish(k, out, cc, claim_failed)
  }

  render_if <- function(k) {
    cc <- split_classes(k)
    msg <- lang_check(k, cc$own, cc$keys)
    if (!is.null(msg)) return(construct_fail(k, msg))
    arms <- R$arms[[k]]
    narms <- length(arms)
    expr <- R$expr[k]
    label <- sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", arms[1L]))
    parts <- tryCatch(split_args(expr), error = function(e) NULL)
    if (is.null(parts)) return(construct_fail(k, "The condition list does not parse (rule 5.3.5)."))
    truth <- logical(length(parts$exprs))
    claim_failed <- FALSE
    for (i in seq_along(parts$exprs)) {
      ev <- eval_expr(k, parts$texts[i], label)
      if (!ev$ok) return(fail_from_error(k, ev$error, label))
      claim_failed <- claim_failed || ev$claim_failed
      v <- ev$value
      if (length(v) == 0L || (length(v) == 1L && is.na(v))) {
        return(record_fail(k, "no value", label,
                           sprintf("The condition `%s` is missing (NA or length zero).", parts$texts[i])))
      }
      if (!is.logical(v) || length(v) != 1L) {
        return(record_fail(k, "value error", label,
                           sprintf("The condition `%s` must be a single TRUE or FALSE.", parts$texts[i])))
      }
      truth[i] <- v
    }
    guard_ids <- integer()
    if (narms == 1L) {
      if (strict && any(!truth)) {
        weft_abort(sprintf("weft: %s: %s was FALSE", loc_str(k), parts$texts[which(!truth)[1L]]),
                   "weft_claim_failed")
      }
      for (i in which(!truth)) {
        guard_ids <- c(guard_ids, add_failure(
          s, "failed claim", file = R$file[k], line = R$line[k], expr = label,
          detail = sprintf("%s was FALSE", parts$texts[i]),
          hint = "optional text is written [phrase | ]{if=\"\u2026\"}",
          chunk = chunk_label, option = if (is_str) ctx$option else NA_character_))
        claim_failed <- TRUE
      }
      i <- 1L
    } else {
      i <- if (all(truth)) 1L else 2L
    }
    R$chosen[k] <<- i
    register_id(k, NA_real_, cc)
    out <- render_arm(k, i, "#")
    res <- finish(k, out, cc, claim_failed)
    # a failed guard is reported by its phrase as printed (2.6.2, 2.6.3)
    if (length(guard_ids)) {
      phrase <- gsub("[ \t\r\n]+", " ", trim_ws(apply_text_classes(out, cc$own)))
      for (g in guard_ids) s$failures[[g]]$expr <- sprintf("\"%s\"", phrase)
    }
    res
  }

  render_text <- function(k) {
    cc <- split_classes(k)
    msg <- lang_check(k, cc$own, cc$keys)
    if (!is.null(msg)) return(construct_fail(k, msg))
    a <- R$start[k] + 1L
    b <- R$block_start[k] - 2L
    out <- render_plain(a, b, range_items(a, b, which(R$parent == k)))
    finish(k, out, cc, FALSE)
  }

  # `.weft-literal` (1.8.9 to 1.8.11): the `why` is removed from the output;
  # the class, the other classes and the other keys stay. A span's prose is
  # resolved as any prose is; a div is its opening line, the body being
  # prose of its own.
  render_literal <- function(k) {
    cl <- R$classes[[k]]
    ky <- R$keys[[k]]
    ky <- ky[names(ky) != "why"]
    items <- c(if (!is.na(R$id[k]) && nzchar(R$id[k])) paste0("#", R$id[k]), cl,
               if (length(ky)) sprintf("%s=\"%s\"", names(ky), unname(ky)))
    blk <- sprintf("{%s}", paste(items, collapse = " "))
    if (startsWith(substr(text, R$start[k], R$start[k]), ":")) {
      return(paste0(substr(text, R$start[k], R$block_start[k] - 1L), blk))
    }
    a <- R$start[k] + 1L
    b <- R$block_start[k] - 2L
    inner <- if (b >= a) render_plain(a, b, range_items(a, b, which(R$parent == k))) else ""
    paste0("[", inner, "]", blk)
  }

  # A `cite` span (1.8): its prose, and in the citation form the value in
  # brackets after it; each key must be in the bibliography (1.8.5).
  render_cite <- function(k) {
    cc <- split_classes(k)
    msg <- lang_check(k, cc$own, cc$keys)
    if (!is.null(msg)) return(construct_fail(k, msg))
    a <- R$start[k] + 1L
    b <- R$block_start[k] - 2L
    prose <- if (b >= a) render_plain(a, b, range_items(a, b, which(R$parent == k))) else ""
    value <- R$expr[k]
    out <- finish(k, prose, cc, FALSE)
    if (grepl("@", value, fixed = TRUE)) out <- paste0(out, " [", value, "]")
    keys <- cite_keys(value)
    known <- bibliography_keys(s)
    gone <- if (length(s$bib_missing)) {
      sprintf("; the bibliography file `%s` was not found", paste(s$bib_missing, collapse = "`, `"))
    } else ""
    unknown <- unique(keys[!(keys %in% known)])
    if (length(unknown)) {
      if (strict) {
        weft_abort(sprintf("weft: %s: the citation key `%s` is not in the bibliography%s.",
                           loc_str(k), unknown[1L], gone), "weft_value_error")
      }
      for (u in unknown) {
        add_failure(s, "unknown citation key", file = R$file[k], line = R$line[k],
                    expr = sprintf("cite=\"%s\"", value),
                    detail = sprintf("the key `%s` is not in the bibliography (rule 1.8.5)%s", u, gone),
                    chunk = chunk_label, option = if (is_str) ctx$option else NA_character_)
      }
      out <- paste0(out, marker("unknown key", R$line[k], chunk_label))
    }
    out
  }

  render_item <- function(it) {
    if (it$type == "span") {
      li <- span_line(it$start)
      return(render_bare(NA_integer_, idx = it$idx, line_info = list(file = li$file, line = li$line),
                         start = it$start))
    }
    k <- it$k
    R$evaluated[k] <<- TRUE
    if (!is.na(R$error[k])) return(construct_fail(k, R$error[k]))
    # an id met a second time at another place, over the document as knitted:
    # a parent and its children, prose and captions (1.7.5)
    if (has_id(k)) {
      prev <- s$ids[[R$id[k]]]
      if (!is.null(prev) && !identical(prev$loc, id_loc(k))) {
        return(construct_fail(k, sprintf(
          "The id `%s` is defined twice; an id is unique within a document (rule 1.7.5).", R$id[k])))
      }
    }
    # inline R knitr did not park (the `{r}` form under rmarkdown) is not
    # evaluated: it stays as it is, as stock leaves it (1.3.1)
    if (R$kind[k] %in% c("bare", "value") && is.na(match(R$start[k], spans$start))) {
      return(substr(text, R$start[k], R$end[k]))
    }
    out <- tryCatch(
      switch(R$kind[k],
             bare = render_bare(k),
             value = render_value(k),
             n = render_n(k),
             `if` = render_if(k),
             sign = render_sign(k),
             list = render_list(k),
             text = render_text(k),
             cite = render_cite(k),
             literal = render_literal(k),
             construct_fail(k, sprintf("The `%s` construct is not built yet.", R$kind[k]))),
      weft_construct_error = function(e) {
        if (inherits(e, "weft_located")) stop(e)
        construct_fail(k, conditionMessage(e))
      },
      weft_value_error = function(e) {
        if (strict) stop(e)
        record_fail(k, "value error", source_label(k), conditionMessage(e))
      },
      weft_no_value = function(e) {
        if (strict) stop(e)
        record_fail(k, "no value", source_label(k), conditionMessage(e))
      })
    # a value that failed still defined its id: a reference to it follows
    # from that failure (1.7.10)
    if (has_id(k) && is.null(s$ids[[R$id[k]]])) {
      s$ids[[R$id[k]]] <- list(rec = NULL, raw = NA_real_, failed = TRUE, loc = id_loc(k))
    }
    out
  }

  # an English-only class under another `lang` is found from the source, so a
  # construct in an unchosen arm is an error too and the render does not depend
  # on the data (1.6.8, 1.6.4)
  if (nr && non_english()) {
    for (k in which(R$kind %in% c("value", "n", "sign", "list", "text", "cite", "if") & is.na(R$error))) {
      cc <- split_classes(k)
      msg <- lang_check(k, cc$own, cc$keys, length(R$arms[[k]]))
      if (is.null(msg)) next
      if (!draft) {
        weft_abort(sprintf("weft: %s: %s", loc_str(k), msg),
                   c("weft_construct_error", "weft_located"))
      }
    }
  }

  top <- range_items(1L, nchar(text), which(is.na(R$parent)))
  out <- render_plain(1L, nchar(text), top, top = TRUE)
  if (nr && draft && non_english()) {
    for (k in which(R$kind %in% c("value", "n", "sign", "list", "text", "cite", "if") & !R$evaluated & is.na(R$error))) {
      cc <- split_classes(k)
      msg <- lang_check(k, cc$own, cc$keys, length(R$arms[[k]]))
      if (!is.null(msg)) {
        add_failure(s, "construct error", file = R$file[k], line = R$line[k],
                    expr = source_label(k), detail = msg, chunk = chunk_label)
      }
    }
  }
  out
}
