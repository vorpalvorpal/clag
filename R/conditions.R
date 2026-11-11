# The condition log (rules 2.8, 7.4.2, 7.4.5, 2.9.1, 7.4.1): conditions
# raised in chunks and by values in prose, the severity list, normalising,
# and replay under the chunk cache.

# Patterns shipped with the severity list (7.4.2): conditions of model fits
# that do not stop the fit.
SHIPPED_SEVERITY <- c(
  "\\(singular\\) fit|isSingular",
  "non-positive[- ]definite Hessian"
)

# Rule 7.4.5, steps 1 to 5, in order.
normalise_condition <- function(text) {
  x <- as.character(text)
  # 1. ANSI styling
  x <- gsub("\033\\[[0-9;?]*[A-Za-z]", "", x)
  # 2. hexadecimal addresses and R's temporary paths
  x <- gsub("0[xX][0-9a-fA-F]+", "<addr>", x)
  x <- gsub("[^[:space:]'\"`<>]*[/\\\\]Rtmp[A-Za-z0-9]+[^[:space:]'\"`<>]*", "<path>", x)
  # 3. every number
  x <- gsub(paste0("(?:(?<=^|[\\s(=,:\\[])[-+])?",
                   "(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?"),
            "<n>", x, perl = TRUE)
  # 4. curly quotes; cli's bullets and rules
  x <- gsub("[\u2018\u2019\u201a\u201b]", "'", x)
  x <- gsub("[\u201c\u201d\u201e\u201f]", "\"", x)
  x <- gsub("\u2022", "*", x, fixed = TRUE)
  x <- gsub("\u2139", "i", x, fixed = TRUE)
  x <- gsub("\u2716", "x", x, fixed = TRUE)
  x <- gsub("\u2714", "v", x, fixed = TRUE)
  x <- gsub("[\u2500\u2501\u2504\u2505\u2508\u2509\u2013\u2014]", "-", x)
  x <- gsub("[\u2502\u2503\u2506\u2507\u250a\u250b]", "|", x)
  x <- gsub("[\u251c\u2514\u2523\u2517]", "+", x)
  x <- gsub("\u2026", "...", x, fixed = TRUE)
  x <- gsub("\u00d7", "x", x, fixed = TRUE)
  x <- gsub("\u26a0", "!", x, fixed = TRUE)
  x <- gsub("\u2192", "->", x, fixed = TRUE)
  # 5. whitespace
  x <- gsub("[[:space:]]+", " ", x)
  trimws(x)
}

severity_patterns <- function(cfg) {
  unique(c(SHIPPED_SEVERITY, as.character(cfg$severity %||% character())))
}

# Record one condition. `source` is the chunk label or `file:line`. A
# condition that matches the severity list is also a failure (7.4.2).
log_condition <- function(s, source, class, text, file = NA_character_,
                          line = NA_integer_, chunk = NA_character_) {
  text <- sub("\n+$", "", as.character(text)[1])
  s$conditions[[length(s$conditions) + 1L]] <- list(
    source = source, class = class, text = text,
    normalised = normalise_condition(text))
  for (pat in severity_patterns(s$config)) {
    hit <- tryCatch(grepl(pat, text, perl = TRUE), error = function(e) FALSE)
    if (isTRUE(hit)) {
      add_failure(s, "condition", file = file, line = line, chunk = chunk,
                  expr = if (!is.na(chunk)) NA_character_ else NA_character_,
                  detail = sprintf("%s: %s", class, sub("\n.*$", "", text)),
                  hint = sprintf("matched the severity pattern %s", pat))
      break
    }
  }
  invisible()
}

# ---- the evaluate hook (2.8.1) ----------------------------------------------

# Wraps the previous `evaluate` hook: the chunk is evaluated with every
# warning and message kept, so each can be logged; knitr itself then removes
# what the author's `warning:` and `message:` settings say to remove, so the
# rendered document is the stock one.
make_evaluate_hook <- function(prev) {
  function(code, envir, ...) {
    s <- ensure_knit()
    args <- list(...)
    opts <- knitr::opts_current$get()
    label <- opts$label %||% NA_character_
    settle_pending(s, label)
    if (!is.null(s$pending_cache) && identical(s$pending_cache$label, label)) {
      s$pending_cache$evaluated <- TRUE
    }
    if (any(grepl("knit_exit", code, fixed = TRUE))) s$exited <- TRUE
    kw <- args$keep_warning
    km <- args$keep_message
    if (!is.null(kw) && !is.na(kw)) args$keep_warning <- TRUE
    if (!is.null(km) && !is.na(km)) args$keep_message <- TRUE
    mine <- list()
    note <- function(class, cond) {
      mine[[length(mine) + 1L]] <<- list(class = class, text = conditionMessage(cond))
    }
    res <- tryCatch(
      do.call(prev, c(list(code, envir), args)),
      error = function(e) {
        note("error", e)
        record_chunk_conditions(s, label, mine, opts)
        stop(e)
      }
    )
    for (el in res) {
      if (inherits(el, "condition")) {
        cl <- if (inherits(el, "error")) "error" else
          if (inherits(el, "warning")) "warning" else
            if (inherits(el, "message")) "message" else NA_character_
        if (!is.na(cl)) note(cl, el)
      }
    }
    record_chunk_conditions(s, label, mine, opts)
    # what the author's settings say to hide is hidden, as evaluate() would
    # have hidden it (2.8.1)
    drop <- function(el) {
      (isFALSE(kw) && inherits(el, "warning")) || (isFALSE(km) && inherits(el, "message"))
    }
    if (isFALSE(kw) || isFALSE(km)) res <- Filter(Negate(drop), res)
    res
  }
}

record_chunk_conditions <- function(s, label, mine, opts) {
  file <- s$input_name
  for (m in mine) {
    log_condition(s, label, m$class, m$text, file = file, chunk = label)
  }
  hash <- opts$hash
  cache <- opts$cache
  cache_on <- (is.logical(cache) && isTRUE(cache)) || (is.numeric(cache) && cache > 0)
  if (cache_on && !is.null(hash) && nzchar(hash)) {
    f <- paste0(hash, ".weft.rds")
    tryCatch({
      dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
      saveRDS(mine, f)
    }, error = function(e) NULL, warning = function(w) NULL)
  }
  invisible()
}

# ---- replay under the chunk cache (2.9.1, 7.4.1) ------------------------------

# knitr calls no hook for a chunk it serves from the cache. weft notes each
# cached chunk when its options are read, and when the next block begins and
# the evaluate hook has not run for it, replays the conditions stored under
# the cache hash when the chunk was computed.
note_cached_chunk <- function(s, options) {
  settle_pending(s)
  cache <- options$cache
  on <- (is.logical(cache) && isTRUE(cache)) || (is.numeric(cache) && cache > 0)
  if (!on || isFALSE(options$eval)) {
    s$pending_cache <- NULL
    return(invisible())
  }
  s$pending_cache <- list(label = options$label, path = options$cache.path,
                          evaluated = FALSE)
  invisible()
}

settle_pending <- function(s, upto_label = NULL) {
  p <- s$pending_cache
  if (is.null(p)) return(invisible())
  if (!is.null(upto_label) && identical(p$label, upto_label)) return(invisible())
  s$pending_cache <- NULL
  if (isTRUE(p$evaluated)) return(invisible())
  replay_cached(s, p)
  invisible()
}

replay_cached <- function(s, p) {
  base <- unique(c(knitr::opts_knit$get("root.dir"),
                   if (!is.na(s$input_path)) dirname(s$input_path), getwd()))
  # knitr names the cache files with the label as written, spaces and all
  esc <- function(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
  labels <- unique(c(p$label, gsub("[^[:alnum:]_.-]", "_", p$label)))
  for (b in base) {
    dir <- file.path(b, dirname(paste0(p$path %||% "cache/", "x")))
    if (!dir.exists(dir)) next
    fs <- list.files(dir, pattern = paste0("^(", paste(esc(labels), collapse = "|"),
                                           ")_[0-9a-f]{32}\\.weft\\.rds$"),
                     full.names = TRUE)
    fs <- fs[file.exists(sub("\\.weft\\.rds$", ".rdx", fs)) |
               file.exists(sub("\\.weft\\.rds$", ".RData", fs))]
    if (!length(fs)) next
    f <- fs[order(file.mtime(fs), decreasing = TRUE)][1]
    mine <- tryCatch(readRDS(f), error = function(e) NULL)
    for (m in mine) {
      log_condition(s, p$label, m$class, m$text, file = s$input_name, chunk = p$label)
    }
    return(invisible())
  }
  invisible()
}
