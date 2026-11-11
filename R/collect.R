# The collection file and the freeze stamps (rules 2.6.6, 2.9.2, 2.9.4, 2.9.5,
# 9.3.2). Nothing here is written outside a project that has been set up.

# A JSON string, ASCII only (so no encoding trouble in a plain-base-R reader).
json_string <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return("null")
  x <- enc2utf8(as.character(x))
  cps <- utf8ToInt(x)
  out <- vapply(cps, function(cp) {
    if (cp == 34L) "\\\""
    else if (cp == 92L) "\\\\"
    else if (cp == 10L) "\\n"
    else if (cp == 13L) "\\r"
    else if (cp == 9L) "\\t"
    else if (cp < 32L || cp > 126L) {
      if (cp > 0xFFFFL) {
        v <- cp - 0x10000L
        sprintf("\\u%04x\\u%04x", 0xD800L + (v %/% 1024L), 0xDC00L + (v %% 1024L))
      } else sprintf("\\u%04x", cp)
    } else intToUtf8(cp)
  }, "")
  paste0("\"", paste(out, collapse = ""), "\"")
}

json_int <- function(x) if (is.null(x) || length(x) != 1L || is.na(x)) "null" else as.character(as.integer(x))

# One failure as a collection line (design-1a, "The Quarto side").
failure_json <- function(f, file) {
  paste0("{\"source\":\"knit\",\"kind\":", json_string(f$kind),
         ",\"file\":", json_string(file),
         ",\"line\":", json_int(f$line),
         ",\"chunk\":", json_string(f$chunk),
         ",\"expr\":", json_string(f$expr),
         ",\"detail\":", json_string(f$detail),
         ",\"hint\":", json_string(f$hint), "}")
}

# The project root of the knit in progress and the input's path under it.
state_root <- function(s) {
  if (is.na(s$input_path)) return(NA_character_)
  normalizePath(find_project_root(s$input_path), winslash = "/", mustWork = FALSE)
}

# The source path relative to the root. Quarto knits a temporary copy
# (`doc.rmarkdown`, `doc.knit.md`...) beside the source; the source is the
# `.qmd` of the same name when there is one.
state_source <- function(s, root) {
  p <- normalizePath(s$input_path, winslash = "/", mustWork = FALSE)
  q <- sub("\\.(rmarkdown|rmd)$", ".qmd", p, ignore.case = TRUE)
  if (!identical(q, p) && file.exists(q)) p <- q
  pre <- paste0(sub("/+$", "", root), "/")
  if (startsWith(p, pre)) substring(p, nchar(pre) + 1L) else basename(p)
}

# The collection file in use: WEFT_COLLECT, or an open .weft/failures.jsonl
# in the project root. NA when none.
collection_path <- function(root) {
  e <- Sys.getenv("WEFT_COLLECT", "")
  if (nzchar(e)) return(e)
  if (is.na(root)) return(NA_character_)
  p <- file.path(root, ".weft", "failures.jsonl")
  if (file.exists(p)) p else NA_character_
}

# The run id the pre-render script wrote (first line of .weft/run), or "".
run_id <- function(root) {
  p <- file.path(root, ".weft", "run")
  if (!file.exists(p)) return("")
  x <- tryCatch(readLines(p, n = 1L, warn = FALSE), error = function(e) "")
  if (length(x)) x[1L] else ""
}

# How many checks the knit evaluated: the top-level constructs.
count_checks <- function(s) {
  sum(vapply(s$constructs, function(R) {
    sum(is.na(R$parent) & !(R$kind %in% c("bare", "link")))
  }, 0))
}

# Write the stamp (2.9.2, 2.9.4) and, when a collection file is open, append
# the failures to it. Returns TRUE when the failures were collected.
record_knit <- function(s, fr) {
  root <- state_root(s)
  if (is.na(root) || !is_set_up(root)) return(invisible(FALSE))
  src <- state_source(s, root)
  rel <- function(f) if (!is.na(f) && f %in% c(s$input_name, basename(src))) src else f
  lines <- vapply(seq_len(nrow(fr)), function(i) {
    f <- as.list(fr[i, ])
    failure_json(f, rel(f$file))
  }, "")
  stamp <- c(
    "{",
    paste0("  \"source\": ", json_string(src), ","),
    paste0("  \"run\": ", json_string(run_id(root)), ","),
    paste0("  \"executed\": ", json_string(format(Sys.time(), "%Y-%m-%d %H:%M:%S")), ","),
    paste0("  \"checks\": ", json_int(count_checks(s)), ","),
    paste0("  \"failures\": [", if (length(lines)) "" else "]"),
    if (length(lines)) c(paste0("    ", lines, c(rep(",", length(lines) - 1L), "")), "  ]"),
    "}")
  ok <- tryCatch({
    dir <- file.path(root, ".weft", "stamps")
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    writeLines(stamp, file.path(dir, paste0(gsub("/", "__", src, fixed = TRUE), ".json")),
               useBytes = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  coll <- collection_path(root)
  if (is.na(coll)) return(invisible(FALSE))
  if (length(lines)) cat(lines, file = coll, sep = "\n", append = TRUE)
  invisible(TRUE)
}
