# --- clag stand-in: collect-and-fail -----------------------------------------
clag <- new.env()
clag$pend <- list(); clag$fail <- list(); clag$warn <- list(); clag$evald <- 0L
clag$draft <- identical(Sys.getenv("CLAG_DRAFT"), "1")
O <- "\u0001"; C <- "\u0002"
fmts <- list(num = function(v) list(text = format(round(v)), number = round(v)))
attrs <- function(a) list(
  cls = regmatches(a, gregexpr("(?<=\\.)[A-Za-z][A-Za-z0-9_-]*(?=\\s|$)", a, perl = TRUE))[[1]],
  kv  = { m <- regmatches(a, gregexpr("([a-z]+)=\"([^\"]*)\"", a, perl = TRUE))[[1]]
          setNames(sub("^[a-z]+=\"(.*)\"$", "\\1", m), sub("=.*", "", m)) })
rec_fail <- function(line, expr, value, what)
  clag$fail[[length(clag$fail) + 1]] <- list(file = basename(knitr::current_input() %||% "?"), line = line,
                                            expr = expr, value = format(value), what = what)
`%||%` <- function(a, b) if (is.null(a)) b else a
run <- function(expr, a, what, line) {
  val <- eval(parse(text = expr), knitr::knit_global())
  bad <- NULL
  for (chk in a$kv[names(a$kv) == "claim"])
    if (!isTRUE(eval(parse(text = chk), list(. = val), knitr::knit_global()))) {
      rec_fail(line, chk, val, what); bad <- chk }
  out <- list(text = format(val)); for (f in a$cls) out <- fmts[[f]](val)
  out$bad <- bad; out
}
# INTERNAL: knitr:::knit_concord holds the current block index and per-block line counts
blk_start <- function() { k <- knitr:::knit_concord$get(c("block", "inlines"), drop = FALSE)
  sum(k$inlines[seq_len(k$block - 1)]) + 1L }
line_of <- function(txt, pos) blk_start() + nchar(gsub("[^\n]", "", substr(txt, 1, pos - 1)))
knitr::knit_hooks$set(evaluate.inline = function(code, envir) {
  clag$pend[[length(clag$pend) + 1]] <- code; paste0(O, length(clag$pend), C) })
knitr::knit_hooks$set(text = function(x) {
  txt <- paste(x, collapse = "\n")
  rv <- paste0(O, "([0-9]+)", C, "(?:\\{([^}]*)\\})?")
  while (grepl(rv, txt, perl = TRUE)) {
    pos <- regexpr(rv, txt, perl = TRUE)
    m <- regmatches(txt, regexec(rv, txt, perl = TRUE))[[1]]; code <- clag$pend[[as.integer(m[2])]]
    r <- run(code, attrs(m[3]), paste0("`r ", code, "`"), line_of(txt, pos))
    rep <- if (is.null(r$bad)) r$text else sprintf("%s [⚠ claim failed: %s]{.clag-failed}", r$text, r$bad)
    txt <- sub(m[1], rep, txt, fixed = TRUE)
  }
  txt })
report_failures <- function() {
  f <- clag$fail
  if (!length(f)) return(invisible())
  msg <- paste0("clag: ", length(f), " claim(s) failed:\n", paste0(sprintf("  %s:%s  %s  (value %s)", 
         vapply(f, `[[`, "", "file"), vapply(f, function(z) as.character(z$line), ""), vapply(f, `[[`, "", "expr"), vapply(f, `[[`, "", "value")), collapse = "\n"))
  if (clag$draft) {
    p <- sub("\\.[^.]*$", ".clag.json", knitr::current_input(dir = TRUE))
    writeLines(jsonlite::toJSON(f, auto_unbox = TRUE, pretty = TRUE), p)
    message("clag draft mode: ", length(f), " failure(s) logged to ", p)
  } else stop(msg, call. = FALSE)
}
knitr::knit_hooks$set(document = function(x) { report_failures(); x })
# --- project (book) mode: defer to post-render so every chapter runs ---------
knitr::knit_hooks$set(document = function(x) {
  f <- clag$fail
  if (length(f) && file.exists(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), ".clag-collect")) && !clag$draft) {
    cat(sprintf("%s\t%s\t%s\t%s\n", vapply(f, `[[`, "", "file"), vapply(f, function(z) as.character(z$line), ""),
        vapply(f, `[[`, "", "expr"), vapply(f, `[[`, "", "value")),
        file = file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "clag-failures.tsv"), append = TRUE)
  } else report_failures()
  x })
