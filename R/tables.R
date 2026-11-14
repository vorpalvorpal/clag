# Tables in the ledger (design-7 section 2.C, N30 to N40): what a reader sees
# as a table, or as text a chunk printed straight into the document, gets one
# ledger entry holding a digest of its visible text.

# N33: the visible text of a piece of markup or markdown, normalised.
table_visible_text <- function(x) {
  x <- paste(as.character(x), collapse = "\n")
  x <- enc2utf8(x)
  x <- gsub("\r\n|\r", "\n", x)
  x <- gsub("(?s)<!--.*?-->", "", x, perl = TRUE)
  x <- gsub("(?is)<(style|script)\\b[^>]*>.*?</\\1\\s*>", "", x, perl = TRUE)
  x <- gsub("<[A-Za-z/!][^>]*>", "", x, perl = TRUE)
  x <- gsub("(?m)^[ \t]*`{3,}[ \t]*(\\{=[^}\n]*\\})?[ \t]*$", "", x, perl = TRUE)
  x <- gsub("[[:space:]]+", " ", x)
  trimws(x)
}

# N32: the digest of a normalised text.
table_digest <- function(txt) {
  cli::hash_raw_xxhash64(charToRaw(enc2utf8(txt)))
}

# N32: the caption: `tbl-cap`, else `tab.cap`, when one string; else the
# first 80 characters of the text.
table_caption <- function(opts, txt) {
  for (nm in c("tbl-cap", "tab.cap")) {
    v <- opts[[nm]]
    if (is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)) return(v)
  }
  if (nchar(txt) > 80L) paste0(substr(txt, 1L, 80L), "...") else txt
}

# N30: the ledger entries of the output elements of one chunk, appended to the
# knit's ledger. `res` is what evaluate gave.
record_chunk_tables <- function(s, label, opts, res) {
  if (isFALSE(opts$include) || isFALSE(opts$eval)) return(invisible())
  results <- opts$results
  if (is.character(results) && identical(results[1L], "hide")) return(invisible())
  asis <- is.character(results) && identical(results[1L], "asis")
  unnamed <- paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1",
                              knitr::opts_knit$get("unnamed.chunk.label") %||% "unnamed-chunk"),
                    "-[0-9]+$")
  generated <- is.na(label) || !nzchar(label) || grepl(unnamed, label)
  wh <- NULL
  for (el in res) {
    if (inherits(el, c("source", "condition", "recordedplot", "knit_image_paths")) ||
        !is.character(el)) next
    if (!inherits(el, "knit_asis") && !asis) next
    txt <- table_visible_text(el)
    if (!nzchar(txt)) next
    if (is.null(wh)) wh <- ledger_where(s, NULL, NA_character_, NA_integer_, label)
    s$ledger[[length(s$ledger) + 1L]] <- list(
      file = wh$file, section = wh$section, kind = "table",
      expr = if (generated) "" else label, id = if (generated) NULL else label,
      context = "chunk", text = table_digest(txt), arm = NULL, rel = NULL, raw = NULL,
      unit = NULL, failed = NULL, dict = character(),
      sentence = table_caption(opts, txt))
  }
  invisible()
}
