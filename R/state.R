# Per-knit state, failure records, markers and the report (rules 2.1.5,
# 2.4, 2.6). The state lives in `weft_env$state`; it is created at the first
# hook call of a top-level knit and kept after the knit, so `last_knit()` can
# be read once the knit has ended or failed.

new_state <- function() {
  s <- new.env(parent = emptyenv())
  s$finished <- FALSE
  s$config <- default_config()
  s$input_path <- NA_character_
  s$input_name <- NA_character_
  s$front <- list()
  s$lang <- ""
  s$parked <- list()
  s$constructs <- list()
  s$failures <- list()
  s$conditions <- list()
  s$files <- list()
  s$pending_cache <- NULL
  s$ids <- list()
  s$stack <- list()
  s$eager_ok <- TRUE
  s$exited <- FALSE
  s
}

# The state of the knit in progress, or NULL (no knit, or hooks never ran).
active_state <- function() {
  s <- weft_env$state
  if (is.null(s) || isTRUE(s$finished)) NULL else s
}

# ---- failures -------------------------------------------------------------

FAILURE_KINDS <- c("failed claim", "no value", "value error", "construct error",
                   "unevaluated", "condition")

add_failure <- function(s, kind, file = NA_character_, line = NA_integer_,
                        chunk = NA_character_, expr = NA_character_,
                        detail = "", hint = NA_character_, option = NA_character_) {
  option <- as.character(option)[1L]
  if (length(option) && !is.na(option)) detail <- paste0(option, ": ", detail)
  chunk_line <- unlabelled_chunk_line(s, chunk)
  s$failures[[length(s$failures) + 1L]] <- list(
    kind = kind, file = as.character(file), line = as.integer(line),
    chunk = as.character(chunk), expr = as.character(expr),
    detail = as.character(detail), hint = as.character(hint),
    option = option, chunk_line = chunk_line)
  invisible(length(s$failures))
}

failures_frame <- function(s) {
  fl <- s$failures
  col <- function(f, type) {
    if (!length(fl)) return(type[0])
    vapply(fl, function(x) x[[f]][1], type)
  }
  data.frame(
    kind = col("kind", ""), file = col("file", ""), line = col("line", 0L),
    chunk = col("chunk", ""), expr = col("expr", ""), detail = col("detail", ""),
    hint = col("hint", ""), option = col("option", ""),
    chunk_line = col("chunk_line", 0L), stringsAsFactors = FALSE
  )
}

# A chunk with no label is named by knitr's `unnamed-chunk-N`, which the
# author never wrote; the line it starts on says where it is (2.6.2).
unlabelled_chunk_line <- function(s, chunk) {
  chunk <- as.character(chunk)[1L]
  if (is.na(chunk) || !grepl("^unnamed-chunk-[0-9]+$", chunk)) return(NA_integer_)
  F <- tryCatch(current_file_state(s), error = function(e) NULL)
  if (is.null(F) || is.null(F$chunk_lines)) return(NA_integer_)
  v <- F$chunk_lines[chunk]
  if (is.na(v)) return(NA_integer_)
  map_lines(F, v)$line
}

# Where a string (a caption, a weft_str() argument) is, for a message.
str_where <- function(chunk, option = NA_character_) {
  if (is.null(chunk) || is.na(chunk)) return("a weft_str() string")
  sprintf("chunk %s%s", chunk,
          if (is.null(option) || is.na(option)) "" else paste0(", ", option))
}

# The marker a failure leaves in the text (2.6.8). Plain ASCII.
marker <- function(kind, line = NA_integer_, chunk = NA_character_) {
  where <- if (!is.na(line)) sprintf("line %d", as.integer(line)) else
    if (!is.na(chunk)) sprintf("chunk %s", chunk) else "line ?"
  sprintf("<<weft: %s, %s>>", kind, where)
}

failure_where <- function(f) {
  if (!is.na(f$line) && !is.na(f$chunk) && identical(f$file, "<text>")) {
    sprintf("chunk %s, text line %d", f$chunk, f$line)
  } else if (!is.na(f$line)) {
    sprintf("%s:%d", if (is.na(f$file)) "<text>" else f$file, f$line)
  } else if (!is.na(f$chunk)) {
    sprintf("%schunk %s%s%s", if (is.na(f$file)) "" else paste0(f$file, " "), f$chunk,
            if (!is.null(f$chunk_line) && !is.na(f$chunk_line)) {
              sprintf(" (the chunk at line %d)", f$chunk_line)
            } else "",
            if (!is.null(f$option) && !is.na(f$option)) paste0(", ", f$option) else "")
  } else {
    if (is.na(f$file)) "<unknown>" else f$file
  }
}

# The report (2.6.2, 2.6.7): claims under their heading line, every other
# kind under another.
format_report <- function(fr) {
  if (!nrow(fr)) return("")
  entry <- function(i, tag = FALSE) {
    f <- fr[i, ]
    head <- sprintf("  %s  %s%s", failure_where(f),
                    if (tag) paste0("[", f$kind, "] ") else "",
                    if (is.na(f$expr) || !nzchar(f$expr)) "" else f$expr)
    det <- strsplit(f$detail, "\n", fixed = TRUE)[[1]]
    det <- if (length(det) && any(nzchar(det))) paste0("      ", det) else character()
    hint <- if (!is.na(f$hint) && nzchar(f$hint)) paste0("      ", f$hint) else character()
    c(sub("\\s+$", "", head), det, hint)
  }
  claims <- which(fr$kind == "failed claim")
  other <- which(fr$kind != "failed claim")
  out <- character()
  if (length(claims)) {
    out <- c(out, sprintf("weft: %d claim%s failed", length(claims),
                          if (length(claims) == 1L) "" else "s"),
             unlist(lapply(claims, entry)),
             "Read each sentence. If FALSE is right, rewrite the sentence.",
             "Do not loosen a claim to clear this.")
  }
  if (length(other)) {
    out <- c(out, sprintf("weft: %d failure%s", length(other),
                          if (length(other) == 1L) "" else "s"),
             unlist(lapply(other, entry, tag = TRUE)))
  }
  paste(out, collapse = "\n")
}

# ---- last_knit() ----------------------------------------------------------

# The records of the most recent top-level knit in this R session.
last_knit <- function() {
  s <- weft_env$state
  if (is.null(s)) return(NULL)
  cons <- s$constructs
  cons <- if (length(cons)) do.call(rbind, cons) else NULL
  fr <- failures_frame(s)
  conds <- s$conditions
  conds <- if (length(conds)) {
    data.frame(
      source = vapply(conds, `[[`, "", "source"),
      class = vapply(conds, `[[`, "", "class"),
      text = vapply(conds, `[[`, "", "text"),
      normalised = vapply(conds, `[[`, "", "normalised"),
      stringsAsFactors = FALSE)
  } else {
    data.frame(source = character(), class = character(), text = character(),
               normalised = character(), stringsAsFactors = FALSE)
  }
  list(constructs = cons, failures = fr, conditions = conds, config = s$config)
}
