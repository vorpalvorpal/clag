# Counting a document's weft constructs, for the commit gate (design-4 G11, G12).
#
# `count_constructs(src)` gives one row per construct: the scanner's value and
# span rows (every context) and each `claim()` call found in the code of an R
# chunk or in a value or governor expression. `.weft-literal` and link rows do
# not count. `kind` is `value` (scanner kinds value and bare), `span` (n, if,
# sign, list, cite, text) or `claim`.

construct_empty <- function() {
  data.frame(file = character(), line = integer(), kind = character(), text = character(),
             stringsAsFactors = FALSE)
}

gate_ws <- function(x) gsub("[ \t\r\n]+", " ", trimws(x))

# The `claim()` and `weft::claim()` calls in R code: a data frame of the call's
# first line (1-based, within `code`) and its source text. For `engine` python
# or julia, the token patterns of N59 (no parser): each match on a line whose
# first non-blank character is not `#`.
claim_calls <- function(code, engine = "r") {
  none <- data.frame(line = integer(), text = character(), stringsAsFactors = FALSE)
  if (engine %in% c("python", "julia")) return(guest_claim_calls(code, engine))
  if (!length(code) || !any(grepl("claim", code, fixed = TRUE))) return(none)
  code <- paste(code, collapse = "\n")
  pd <- tryCatch(utils::getParseData(parse(text = code, keep.source = TRUE)), error = function(e) NULL)
  if (is.null(pd)) {
    # unparsable code: take the text from each `claim(` to the end of its line
    ls <- strsplit(code, "\n", fixed = TRUE)[[1L]]
    hit <- which(grepl("(^|[^A-Za-z0-9_.])(weft::)?claim\\s*\\(", ls))
    if (!length(hit)) return(none)
    txt <- sub("^.*?((weft::)?claim\\s*\\(.*)$", "\\1", ls[hit], perl = TRUE)
    return(data.frame(line = hit, text = gate_ws(txt), stringsAsFactors = FALSE))
  }
  sfc <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == "claim", , drop = FALSE]
  if (!nrow(sfc)) return(none)
  keep <- vapply(seq_len(nrow(sfc)), function(i) {
    sib <- pd[pd$parent == sfc$parent[i] & pd$token == "SYMBOL_PACKAGE", , drop = FALSE]
    !nrow(sib) || all(sib$text == "weft")
  }, NA)
  sfc <- sfc[keep, , drop = FALSE]
  if (!nrow(sfc)) return(none)
  call_id <- pd$parent[match(sfc$parent, pd$id)]
  call <- pd[match(call_id, pd$id), , drop = FALSE]
  txt <- vapply(call$id, function(id) {
    tryCatch(paste(utils::getParseText(pd, id), collapse = "\n"), error = function(e) "claim(...)")
  }, "")
  data.frame(line = as.integer(call$line1), text = gate_ws(txt), stringsAsFactors = FALSE)
}

guest_claim_calls <- function(code, engine) {
  none <- data.frame(line = integer(), text = character(), stringsAsFactors = FALSE)
  if (!length(code)) return(none)
  ls <- unlist(strsplit(paste(code, collapse = "\n"), "\n", fixed = TRUE), use.names = FALSE)
  re <- if (identical(engine, "python")) "(?<![A-Za-z0-9_.])(weft\\.)?claim\\(" else
    "(?<![A-Za-z0-9_])(Weft\\.)?@claim\\b"
  line <- integer()
  text <- character()
  for (i in which(!grepl("^[ \t]*#", ls))) {
    m <- gregexpr(re, ls[i], perl = TRUE)[[1L]]
    if (m[1L] < 0L) next
    for (p in m) {
      if (identical(engine, "python") && grepl("(^|[^A-Za-z0-9_.])def[ \t]+$", substr(ls[i], 1L, p - 1L))) next
      line <- c(line, i)
      text <- c(text, gate_ws(substring(ls[i], p)))
    }
  }
  if (!length(line)) return(none)
  data.frame(line = line, text = text, stringsAsFactors = FALSE)
}

# every construct of a source, with `bad` set on a row the scanner reports an error on
construct_rows <- function(src) {
  if (isTRUE(src$invalid)) return(cbind(construct_empty(), bad = logical()))
  parts <- list()
  r <- src$rows
  if (!is.null(r) && nrow(r)) {
    kinds <- c(value = "value", bare = "value", n = "span", `if` = "span", sign = "span",
               list = "span", cite = "span", text = "span")
    k <- unname(kinds[r$kind])
    ok <- !is.na(k)
    if (any(ok)) {
      i <- which(ok)
      parts[[length(parts) + 1L]] <- data.frame(
        file = rep(src$file, length(i)), line = as.integer(r$line[i]), kind = k[i],
        text = gate_ws(substring(src$text, r$fstart[i], r$fend[i])), bad = !is.na(r$error[i]),
        stringsAsFactors = FALSE)
    }
    # a claim() inside a value or governor expression
    e <- which(ok & !is.na(r$expr) & grepl("claim", r$expr, fixed = TRUE))
    for (i in e) {
      cc <- claim_calls(r$expr[i])
      if (nrow(cc)) {
        parts[[length(parts) + 1L]] <- data.frame(
          file = rep(src$file, nrow(cc)), line = rep(as.integer(r$line[i]), nrow(cc)),
          kind = "claim", text = cc$text, bad = !is.na(r$error[i]), stringsAsFactors = FALSE)
      }
    }
  }
  ch <- src$chunks
  if (!is.null(ch) && nrow(ch)) {
    for (j in seq_len(nrow(ch))) {
      eng <- tolower(ch$engine[j])
      if (!eng %in% c("r", "python", "julia")) next
      # a guest chunk counts only when it runs; an R chunk counts under eval: false (G35, N59)
      if (!identical(eng, "r") && isTRUE(isFALSE(ch$eval[j]))) next
      cc <- claim_calls(ch$code[[j]], eng)
      if (nrow(cc)) {
        parts[[length(parts) + 1L]] <- data.frame(
          file = rep(src$file, nrow(cc)), line = as.integer(ch$code_line[j] + cc$line - 1L),
          kind = "claim", text = cc$text, bad = FALSE, stringsAsFactors = FALSE)
      }
    }
  }
  if (!length(parts)) return(cbind(construct_empty(), bad = logical()))
  out <- do.call(rbind, parts)
  out <- out[order(out$line, seq_len(nrow(out))), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# One row per construct (G11): `file, line, kind, text`. The attribute `errored` says which rows the
# scanner reports an error on.
count_constructs <- function(src) {
  x <- construct_rows(src)
  out <- x[, c("file", "line", "kind", "text"), drop = FALSE]
  attr(out, "errored") <- x$bad
  out
}

# The constructs the gate counts (G12): a construct with an error is not a working one, and the error
# fails the commit by itself (G9), so removing it, or breaking one so that knitr leaves it as literal
# code (rule 5.3.4), is a removal only through the totals of working constructs.
working_constructs <- function(src) {
  x <- construct_rows(src)
  out <- x[!x$bad, c("file", "line", "kind", "text"), drop = FALSE]
  rownames(out) <- NULL
  out
}
