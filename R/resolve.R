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

fill_template <- function(tmpl, hash, outs) {
  m <- gregexpr("\ue001|\ue002[0-9]+\ue003", tmpl, perl = TRUE)[[1L]]
  if (m[1L] < 0L) return(tmpl)
  tok <- regmatches(tmpl, list(m))[[1L]]
  lit <- regmatches(tmpl, list(m), invert = TRUE)[[1L]]
  rep <- vapply(tok, function(t) {
    if (identical(t, "\ue001")) hash else outs[[as.integer(substring(t, 2L, nchar(t) - 1L))]]
  }, "", USE.NAMES = FALSE)
  paste0(c(rbind(lit[-length(lit)], rep), lit[length(lit)]), collapse = "")
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
run_inline <- function(s, file, line, label, expr, run, chunk = NA_character_) {
  old <- weft_env$inline
  weft_env$inline <- list(file = file, line = line, label = label, expr = expr,
                          failed = FALSE, chunk = chunk)
  on.exit(weft_env$inline <- old, add = TRUE)
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
  if (!grepl("\ue000", x, fixed = TRUE) && !grepl("[", x, fixed = TRUE)) return(x)
  cfg <- s$config
  loc <- locate_block(s, x)
  F <- loc$F
  restored <- restore_parked(x, s$parked)
  text <- restored$text
  spans <- restored$spans
  sb <- scan_block(blank_front_matter(text), file = NA_character_,
                   first_line = loc$start, config = cfg)
  S <- sb$S
  R <- sb$rows
  nr <- nrow(R)
  R$line_view <- R$line
  if (nr) {
    ml <- map_lines(F, R$line_view)
    R$file <- ml$file
    R$line <- ml$line
  }
  R$evaluated <- rep(FALSE, nr)
  R$chosen <- rep(NA_integer_, nr)
  nlpos <- which(strsplit(text, "")[[1L]] == "\n")
  span_line <- function(start) {
    lv <- loc$start + sum(nlpos < start)
    map_lines(F, lv)
  }
  draft <- isTRUE(cfg$draft)
  # text knitted by a child has no file: its lines are relative to the text,
  # and the chunk that knitted it says where (2.7.3)
  chunk_label <- if (is.null(F) && is_child_knit()) {
    lab <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
    if (is.character(lab) && length(lab) == 1L) lab else NA_character_
  } else NA_character_
  owned <- owned_classes(cfg)
  gov <- NULL

  on.exit({
    if (nr) {
      s$constructs[[length(s$constructs) + 1L]] <- R
      if (!is.null(F)) {
        top <- is.na(R$parent) & !(R$kind %in% c("bare", "link"))
        F$recorded <- c(F$recorded, paste(R$kind[top], R$line_view[top]))
      }
    }
  }, add = TRUE)

  # construct errors found from the source stop the render at once (2.6.5),
  # except in draft mode, where each becomes a marker where it would print
  if (!draft && nr && any(!is.na(R$error))) {
    k <- which(!is.na(R$error))[1L]
    R$evaluated[k] <- TRUE
    weft_abort(sprintf("weft: %s:%d: %s", R$file[k], R$line[k], R$error[k]),
               c("weft_construct_error", "weft_located"))
  }

  loc_str <- function(k) sprintf("%s:%d", R$file[k], R$line[k])

  construct_fail <- function(k, msg) {
    if (!draft) {
      weft_abort(sprintf("weft: %s: %s", loc_str(k), msg),
                 c("weft_construct_error", "weft_located"))
    }
    add_failure(s, "construct error", file = R$file[k], line = R$line[k],
                expr = source_label(k), detail = msg, chunk = chunk_label)
    marker("construct error", R$line[k])
  }

  source_label <- function(k) {
    t <- substr(text, R$start[k], R$end[k])
    t <- gsub("[ \t\r\n]+", " ", t)
    if (nchar(t) > 70L) t <- paste0(substr(t, 1L, 67L), "...")
    t
  }

  record_fail <- function(k, kind, label, detail, hint = NA_character_) {
    add_failure(s, kind, file = R$file[k], line = R$line[k], expr = label,
                detail = detail, hint = hint, chunk = chunk_label)
    marker(kind, R$line[k])
  }

  # a condition raised by the expression, or an error it raised (2.6.4, 2.6.9)
  fail_from_error <- function(k, e, label) {
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

  eval_expr <- function(k, expr, label, envir = knitr::knit_global(), stock = FALSE,
                        line_info = NULL) {
    file <- if (is.null(line_info)) R$file[k] else line_info$file
    line <- if (is.null(line_info)) R$line[k] else line_info$line
    run_inline(s, file, line, label, expr, function() {
      if (stock) stock_bare_text(expr, envir) else
        eval(parse(text = expr, keep.source = FALSE), envir)
    }, chunk = chunk_label)
  }

  non_english <- function() {
    l <- tolower(sub("[-_].*$", "", s$lang %||% ""))
    nzchar(l) && l != "en"
  }
  lang_check <- function(k, classes, keys, n_arms = 1L) {
    if (!non_english()) return(NULL)
    if (R$kind[k] == "n" && n_arms > 1L) {
      return(sprintf(paste0("An `n` span with more than one arm needs the plural rules of `%s`, ",
                            "which weft does not ship; English rules are never applied to another ",
                            "language (rules 1.6.5, 1.6.7)."), s$lang))
    }
    eng <- c(".no", WORDING_CLASSES, ".and", ".or", ".pairs", ".range", ".a")
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
    tcl <- own[own %in% c(".em", ".strong") |
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
    if (claim_failed) text <- paste0(text, marker("failed claim", R$line[k]))
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

  render_plain <- function(a, b, items) {
    out <- character()
    cur <- a
    prev <- ""
    for (it in items) {
      o <- render_item(it)
      # two emphasis constructs side by side would read as `*a**b*`; an empty
      # comment keeps the delimiters apart (1.4.3)
      if (it$start == cur && endsWith(prev, "*") && startsWith(o, "*")) {
        o <- paste0("<!-- -->", o)
      }
      out <- c(out, substr(text, cur, it$start - 1L), o)
      prev <- o
      cur <- it$end + 1L
    }
    paste(c(out, substr(text, cur, b)), collapse = "")
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
    fill_template(tmpl, hash, as.list(outs))
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
    if (ev$claim_failed) paste0(ev$value, marker("failed claim", li$line)) else ev$value
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
    has_fmt <- any(!is.na(class_group(cc$own, reg))) || ".no" %in% cc$own ||
      any(c("digits", "sigfig") %in% names(cc$keys))
    res <- tryCatch({
      if (has_fmt) {
        paste(as.character(apply_formatters(v, cc$own, as.list(cc$keys), cfg, join = ", ")), collapse = "")
      } else {
        apply_text_classes(stock_print(v), cc$own)
      }
    }, error = function(e) e)
    if (inherits(res, "error")) return(fail_from_error(k, res, label))
    finish(k, res, cc, ev$claim_failed, text_classes = FALSE)
  }

  render_n <- function(k) {
    cc <- split_classes(k)
    arms <- R$arms[[k]]
    narms <- length(arms)
    msg <- lang_check(k, cc$own, cc$keys, narms)
    if (!is.null(msg)) return(construct_fail(k, msg))
    expr <- R$expr[k]
    label <- sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", arms[1L]))
    inherit <- identical(trim_ws(expr), ".")
    if (inherit) {
      if (is.null(gov)) return(construct_fail(k, "`n=\".\"` outside an `n` or `sign` span (rule 1.7.2)."))
      v <- gov
      claim_failed <- FALSE
    } else {
      ev <- eval_expr(k, expr, label)
      if (!ev$ok) return(fail_from_error(k, ev$error, label))
      v <- ev$value
      claim_failed <- ev$claim_failed
    }
    chk <- check_governor(v)
    if (!is.null(chk)) return(record_fail(k, chk$kind, label, chk$detail))
    own_fmt <- any(!is.na(class_group(cc$own, cfg$formatters))) || ".no" %in% cc$own ||
      any(c("digits", "sigfig") %in% names(cc$keys))
    rec <- if (inherit && !own_fmt) v else tryCatch(
      apply_formatters(v, cc$own, as.list(cc$keys), cfg, governor = TRUE),
      error = function(e) e)
    if (inherits(rec, "error")) return(fail_from_error(k, rec, label))
    i <- choose_arm_n(rec, narms)
    R$chosen[k] <<- i
    out <- render_arm(k, i, as.character(rec)[1L], record = rec)
    finish(k, out, cc, claim_failed)
  }

  render_if <- function(k) {
    cc <- split_classes(k)
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
      for (i in which(!truth)) {
        guard_ids <- c(guard_ids, add_failure(
          s, "failed claim", file = R$file[k], line = R$line[k], expr = label,
          detail = sprintf("%s was FALSE", parts$texts[i]),
          hint = "optional text is written [phrase | ]{if=\"\u2026\"}",
          chunk = chunk_label))
        claim_failed <- TRUE
      }
      i <- 1L
    } else {
      i <- if (all(truth)) 1L else 2L
    }
    R$chosen[k] <<- i
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
    a <- R$start[k] + 1L
    b <- R$block_start[k] - 2L
    out <- render_plain(a, b, range_items(a, b, which(R$parent == k)))
    finish(k, out, cc, FALSE)
  }

  render_verbatim <- function(k) {
    a <- R$start[k]
    b <- R$end[k]
    render_plain(a, b, range_items(a, b, which(R$parent == k)))
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
    # inline R knitr did not park (the `{r}` form under rmarkdown) is not
    # evaluated: it stays as it is, as stock leaves it (1.3.1)
    if (R$kind[k] %in% c("bare", "value") && is.na(match(R$start[k], spans$start))) {
      return(substr(text, R$start[k], R$end[k]))
    }
    tryCatch(
      switch(R$kind[k],
             bare = render_bare(k),
             value = render_value(k),
             n = render_n(k),
             `if` = render_if(k),
             text = render_text(k),
             literal = render_verbatim(k),
             construct_fail(k, sprintf("The `%s` construct is not built yet.", R$kind[k]))),
      weft_construct_error = function(e) {
        if (inherits(e, "weft_located")) stop(e)
        construct_fail(k, conditionMessage(e))
      })
  }

  # an English-only class under another `lang` is found from the source, so a
  # construct in an unchosen arm is an error too and the render does not depend
  # on the data (1.6.8, 1.6.4)
  if (nr && non_english()) {
    for (k in which(R$kind %in% c("value", "n") & is.na(R$error))) {
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
  out <- render_plain(1L, nchar(text), top)
  if (nr && draft && non_english()) {
    for (k in which(R$kind %in% c("value", "n") & !R$evaluated & is.na(R$error))) {
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
