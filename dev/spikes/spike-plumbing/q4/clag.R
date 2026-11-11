# =============================================================================
# clag stand-in, spike version.  Parsing is the old regex stand-in on purpose.
# Sections: 1 state  2 deferred eval (errors, warnings)  3 collect-and-fail
#           4 hidden-condition capture   5 evaluated-vs-present count (Q5)
# =============================================================================
clag <- new.env()
local({
  clag$pend <- list(); clag$fail <- list(); clag$cond <- list(); clag$evald <- 0L
  clag$draft <- identical(Sys.getenv("CLAG_DRAFT"), "1")
})
O <- "\u0001"; C <- "\u0002"
`%||%` <- function(a, b) if (is.null(a)) b else a
doc_path <- function() knitr::current_input(dir = TRUE)
doc_name <- function() sub("\\.rmarkdown$", ".qmd", basename(knitr::current_input() %||% "?"))  # cosmetic (Quarto)

fmts <- list(num = function(v) list(text = format(round(v)), number = round(v)))
attrs <- function(a) list(
  cls = regmatches(a, gregexpr("(?<=\\.)[A-Za-z][A-Za-z0-9_-]*(?=\\s|$)", a, perl = TRUE))[[1]],
  kv  = { m <- regmatches(a, gregexpr("([a-z]+)=\"([^\"]*)\"", a, perl = TRUE))[[1]]
          setNames(sub("^[a-z]+=\"(.*)\"$", "\\1", m), sub("=.*", "", m)) })

unlink(paste0(sub("\\.[^.]*$", "", knitr::current_input(dir = TRUE)), ".clag-conditions.tsv"))   # fresh log per render

kv1 <- function(a, k) { v <- a$kv[names(a$kv) == k]; if (length(v)) unname(v[[1]]) else NULL }

# ---- 2. line numbers + deferred evaluation ---------------------------------
# INTERNAL: knitr:::knit_concord holds current block index and per-block line counts.
blk_start <- function() { k <- knitr:::knit_concord$get(c("block", "inlines"), drop = FALSE)
  sum(k$inlines[seq_len(k$block - 1)]) + 1L }
line_of <- function(txt, pos) blk_start() + nchar(gsub("[^\n]", "", substr(txt, 1, pos - 1)))

log_cond <- function(kind, where, expr, text) {   # appended at once, so a later fatal error does not lose the log
  clag$cond[[length(clag$cond) + 1]] <- list(kind = kind, where = where, expr = expr, text = trimws(text))
  cat(kind, where, expr, gsub("\n", " / ", trimws(text)), sep = "\t", file = paste0(sub("\\.[^.]*$", "", doc_path()), ".clag-conditions.tsv"), append = TRUE)
  cat("\n", file = paste0(sub("\\.[^.]*$", "", doc_path()), ".clag-conditions.tsv"), append = TRUE) }

# eval `expr`; errors name expression + line; warnings/messages are logged, kept out of the text
eval_deferred <- function(expr, env, line, extra = NULL) {
  where <- sprintf("%s:%s", doc_name(), line)
  withCallingHandlers(
    tryCatch(eval(parse(text = expr), if (is.null(extra)) env else list2env(extra, parent = env)),
      error = function(e) stop(sprintf("clag: cannot evaluate `%s`\n  at %s\n  %s", expr, where, conditionMessage(e)), call. = FALSE)),
    warning = function(w) { log_cond("warning", where, expr, conditionMessage(w)); invokeRestart("muffleWarning") },
    message = function(m) { log_cond("message", where, expr, conditionMessage(m)); invokeRestart("muffleMessage") })
}

# ---- 3. collect-and-fail ---------------------------------------------------
rec_fail <- function(line, expr, value)
  clag$fail[[length(clag$fail) + 1]] <- list(file = doc_name(), line = line, expr = expr, value = format(value))

run <- function(expr, a, what, line) {
  val <- eval_deferred(expr, knitr::knit_global(), line); clag$evald <- clag$evald + 1L
  bad <- NULL
  for (chk in a$kv[names(a$kv) == "claim"])
    if (!isTRUE(eval_deferred(chk, knitr::knit_global(), line, list(. = val)))) { rec_fail(line, chk, val); bad <- chk }
  out <- list(text = format(val)); for (f in a$cls) out <- fmts[[f]](val)
  out$bad <- bad; out
}
knitr::knit_hooks$set(evaluate.inline = function(code, envir) {
  clag$pend[[length(clag$pend) + 1]] <- code; paste0(O, length(clag$pend), C) })
knitr::knit_hooks$set(text = function(x) {
  txt <- paste(x, collapse = "\n")
  # bracketed prose governed by an attribute: [a | b]{n="expr"} / {if="expr"} / {claim="expr"}
  rs <- "\\[([^\\[\\]]*)\\]\\{([^}]*\\b(?:n|if|claim)=\"[^}]*)\\}"
  while (grepl(rs, txt, perl = TRUE)) {
    pos <- regexpr(rs, txt, perl = TRUE); line <- line_of(txt, pos)
    m <- regmatches(txt, regexec(rs, txt, perl = TRUE))[[1]]; a <- attrs(m[3])
    arms <- trimws(strsplit(m[2], "|", fixed = TRUE)[[1]]); rep <- m[2]; bad <- NULL
    if (!is.null(kv1(a, "if"))) {
      ok <- isTRUE(eval_deferred(kv1(a, "if"), knitr::knit_global(), line)); clag$evald <- clag$evald + 1L
      rep <- if (ok) arms[1] else if (length(arms) > 1) arms[2] else "" }
    if (!is.null(kv1(a, "n"))) {
      r <- run(kv1(a, "n"), a, m[1], line)
      arm <- arms[if (identical(r$text, "1")) 1 else min(2, length(arms))]; rep <- gsub("#", r$text, arm, fixed = TRUE)
      if (!is.null(r$bad)) bad <- r$bad
    } else for (chk in a$kv[names(a$kv) == "claim"]) {
      clag$evald <- clag$evald + 1L
      if (!isTRUE(eval_deferred(chk, knitr::knit_global(), line))) { rec_fail(line, chk, NA); bad <- chk } }
    if (!is.null(bad)) rep <- sprintf("%s [\u26a0 claim failed: %s]{.clag-failed}", rep, bad)
    txt <- sub(m[1], rep, txt, fixed = TRUE)
  }
  rv <- paste0(O, "([0-9]+)", C, "(?:\\{([^}]*)\\})?")
  while (grepl(rv, txt, perl = TRUE)) {
    pos <- regexpr(rv, txt, perl = TRUE)
    m <- regmatches(txt, regexec(rv, txt, perl = TRUE))[[1]]; code <- clag$pend[[as.integer(m[2])]]
    r <- run(code, attrs(m[3]), code, line_of(txt, pos))
    rep <- if (is.null(r$bad)) r$text else sprintf("%s [⚠ claim failed: %s]{.clag-failed}", r$text, r$bad)
    txt <- sub(m[1], rep, txt, fixed = TRUE)
  }
  txt })

finish <- function() {
  base <- sub("\\.[^.]*$", "", doc_path())
  f <- clag$fail
  if (!length(f)) return(invisible())
  lines <- sprintf("  %s:%s  %s  (value %s)", vapply(f, `[[`, "", "file"), vapply(f, function(z) as.character(z$line), ""),
                   vapply(f, `[[`, "", "expr"), vapply(f, `[[`, "", "value"))
  if (clag$draft) {
    p <- paste0(base, ".clag.json"); writeLines(jsonlite::toJSON(f, auto_unbox = TRUE, pretty = TRUE), p)
    message("clag draft mode: ", length(f), " failure(s) logged to ", p)
  } else stop("clag: ", length(f), " claim(s) failed:\n", paste(lines, collapse = "\n"), call. = FALSE)
}
knitr::knit_hooks$set(document = function(x) { finish(); x })

# ---- 4. hidden-condition capture -----------------------------------------------
# DOCUMENTED hook: knit_hooks$get("evaluate") is what knitr's R engine calls to run a chunk.
# Wrap it: always ask evaluate() to keep warnings/messages, log every condition with the source
# expression that raised it, then drop them again if the author had them hidden (FALSE).  knitr merges
# adjacent source blocks AFTER this point, so the output is identical to a stock `warning: false` render.
local({
  old <- knitr::knit_hooks$get("evaluate")
  knitr::knit_hooks$set(evaluate = function(code, ..., keep_warning = TRUE, keep_message = TRUE) {
    res <- old(code, ..., keep_warning = if (isFALSE(keep_warning)) TRUE else keep_warning,
                          keep_message = if (isFALSE(keep_message)) TRUE else keep_message)
    label <- knitr::opts_current$get("label"); src <- ""; drop <- rep(FALSE, length(res))
    for (i in seq_along(res)) { r <- res[[i]]
      if (evaluate::is.source(r)) src <- paste(r$src, collapse = " ")
      kind <- if (evaluate::is.warning(r)) "warning" else if (evaluate::is.message(r)) "message" else
              if (evaluate::is.error(r)) "error" else next
      log_cond(kind, paste0("chunk ", label), trimws(src), conditionMessage(r))
      if ((kind == "warning" && isFALSE(keep_warning)) || (kind == "message" && isFALSE(keep_message))) drop[i] <- TRUE }
    res[!drop] })
})
