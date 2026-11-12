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
# A warned check carries `"level": "warn"` (entry 31).
failure_json <- function(f, file, level = NULL) {
  paste0("{\"source\":\"knit\",",
         if (!is.null(level)) paste0("\"level\":", json_string(level), ","),
         "\"kind\":", json_string(f$kind),
         ",\"file\":", json_string(file),
         ",\"line\":", json_int(f$line),
         ",\"chunk\":", json_string(f$chunk),
         ",\"expr\":", json_string(f$expr),
         ",\"detail\":", json_string(f$detail),
         ",\"hint\":", json_string(f$hint),
         ",\"option\":", json_string(f$option),
         ",\"chunk_line\":", json_int(f$chunk_line), "}")
}

# The project root of the knit in progress and the input's path under it.
state_root <- function(s) {
  if (is.na(s$input_path)) return(NA_character_)
  normalizePath(find_project_root(s$input_path), winslash = "/", mustWork = FALSE)
}

# The file the author named for the knit. rmarkdown knits a copy when the
# name holds a shell character (`a b.Rmd` is knitted as `a-b.Rmd`) and keeps
# the original in its `render()` frame (the frame the output name is read from).
state_input <- function(s) {
  p <- normalizePath(s$input_path, winslash = "/", mustWork = FALSE)
  if (isNamespaceLoaded("rmarkdown")) {
    rf <- get("render", envir = asNamespace("rmarkdown"))
    for (i in rev(seq_len(sys.nframe()))) {
      if (identical(sys.function(i), rf)) {
        oi <- get0("original_input", envir = sys.frame(i), inherits = FALSE)
        if (is.character(oi) && length(oi) == 1L && !is.na(oi) && file.exists(oi)) {
          o <- normalizePath(oi, winslash = "/", mustWork = FALSE)
          if (!identical(o, p) && identical(gsub("[ <>()|\\\\:&;#?*']", "-", basename(o)), basename(p))) p <- o
        }
        break
      }
    }
  }
  p
}

# The source path relative to the root. Quarto knits a temporary copy
# (`doc.rmarkdown`) beside the source; under Quarto the source is the `.qmd`
# of the same name when there is one. Under rmarkdown the input is the
# author's own file.
state_source <- function(s, root) {
  p <- state_input(s)
  if (nzchar(Sys.getenv("QUARTO_EXECUTE_INFO", ""))) {
    q <- sub("\\.rmarkdown$", ".qmd", p, ignore.case = TRUE)
    if (!identical(q, p) && file.exists(q)) p <- q
  }
  pre <- paste0(sub("/+$", "", root), "/")
  enc2utf8(if (startsWith(p, pre)) substring(p, nchar(pre) + 1L) else basename(p))
}

# The collection file in use: WEFT_COLLECT, or the open .weft/failures.jsonl of
# the project render this knit is part of. NA when none. A file left behind by
# a render that stopped is not in use: a knit outside a Quarto render never
# uses it, and inside one it is used only when the run it names (its first
# line) is the one in .weft/run, or, with no .weft/run, when it is under an
# hour old.
collection_path <- function(root) {
  e <- Sys.getenv("WEFT_COLLECT", "")
  if (nzchar(e)) return(e)
  if (is.na(root)) return(NA_character_)
  if (!nzchar(Sys.getenv("QUARTO_EXECUTE_INFO", ""))) return(NA_character_)
  p <- file.path(root, ".weft", "failures.jsonl")
  if (!file.exists(p)) return(NA_character_)
  id <- run_id(root)
  first <- tryCatch(readLines(p, n = 1L, warn = FALSE), error = function(e) character())
  mine <- if (length(first)) sub("^.*\"run\":[ ]*\"([^\"]*)\".*$", "\\1", first[1L]) else ""
  if (!grepl("\"run\"", paste(first, collapse = ""), fixed = TRUE)) mine <- ""
  if (nzchar(id)) {
    if (!identical(mine, id)) return(NA_character_)
  } else {
    age <- difftime(Sys.time(), file.mtime(p), units = "secs")
    if (is.na(age) || age > 3600) return(NA_character_)
  }
  p
}

# The failures the chapters rendered so far have appended to the collection
# file, as a data frame in the layout of failures_frame().
collected_failures <- function(root) {
  p <- collection_path(root)
  empty <- failures_frame_empty()
  if (is.na(p) || !file.exists(p)) return(empty)
  x <- tryCatch(readLines(p, warn = FALSE, encoding = "UTF-8"), error = function(e) character())
  rows <- lapply(x[grepl("\"source\":\"knit\"", x, fixed = TRUE)], function(l) {
    y <- tryCatch(yaml::yaml.load(l, eval.expr = FALSE), error = function(e) NULL)
    if (!is.list(y)) return(NULL)
    # a warned check is not a failure
    if (identical(y$level, "warn")) return(NULL)
    data.frame(kind = as.character(y$kind %||% ""), file = as.character(y$file %||% NA_character_),
               line = suppressWarnings(as.integer(y$line %||% NA_integer_)),
               chunk = as.character(y$chunk %||% NA_character_),
               expr = as.character(y$expr %||% NA_character_),
               detail = as.character(y$detail %||% ""),
               hint = as.character(y$hint %||% NA_character_),
               option = as.character(y$option %||% NA_character_),
               chunk_line = suppressWarnings(as.integer(y$chunk_line %||% NA_integer_)),
               stringsAsFactors = FALSE)
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(empty)
  do.call(rbind, rows)
}

failures_frame_empty <- function() {
  data.frame(kind = character(), file = character(), line = integer(),
             chunk = character(), expr = character(), detail = character(),
             hint = character(), option = character(), chunk_line = integer(),
             stringsAsFactors = FALSE)
}

# Make a folder under `.weft/` and, with it, `.weft/.gitignore` holding `*`, so
# that what weft keeps there is not committed by accident.
weft_state_dir <- function(root, ...) {
  d <- file.path(root, ".weft")
  dir.create(file.path(d, ...), showWarnings = FALSE, recursive = TRUE)
  g <- file.path(d, ".gitignore")
  if (!file.exists(g)) writeLines("*", g)
  invisible(file.path(d, ...))
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
  # a rehearsal writes nothing into the project (3.7.2)
  if (rehearsing()) return(invisible(FALSE))
  root <- state_root(s)
  if (is.na(root) || !is_set_up(root)) return(invisible(FALSE))
  src <- state_source(s, root)
  rel <- function(f) if (!is.na(f) && f %in% c(s$input_name, basename(src))) src else f
  lines <- vapply(seq_len(nrow(fr)), function(i) {
    f <- as.list(fr[i, ])
    failure_json(f, rel(f$file))
  }, "")
  wr <- failures_frame(s, "warnings")
  wlines <- vapply(seq_len(nrow(wr)), function(i) {
    f <- as.list(wr[i, ])
    failure_json(f, rel(f$file), level = "warn")
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
    dir <- weft_state_dir(root, "stamps")
    writeLines(stamp, file.path(dir, paste0(gsub("/", "__", src, fixed = TRUE), ".json")),
               useBytes = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  write_draft_failures(s, src, c(lines, wlines))
  coll <- collection_path(root)
  if (is.na(coll)) return(invisible(FALSE))
  if (length(c(lines, wlines))) cat(c(lines, wlines), file = coll, sep = "\n", append = TRUE)
  invisible(TRUE)
}

# In draft mode, in a project that has been set up, the failures are also
# written beside the document as `<name>.weft-failures.json`, an array in the
# collection-line schema (9.4.2). A render with no failures removes a stale
# file; a render that stops on its failures leaves it alone.
write_draft_failures <- function(s, src, lines) {
  dir <- dirname(normalizePath(s$input_path, winslash = "/", mustWork = FALSE))
  name <- paste0(sub("\\.[^.]*$", "", basename(src)), ".weft-failures.json")
  path <- file.path(dir, name)
  if (!length(lines)) {
    if (file.exists(path)) unlink(path)
    return(invisible())
  }
  if (!isTRUE(s$config$draft)) return(invisible())
  tryCatch(
    writeLines(c("[", paste0("  ", lines, c(rep(",", length(lines) - 1L), "")), "]"),
               path, useBytes = TRUE),
    error = function(e) NULL, warning = function(w) NULL)
  invisible()
}
