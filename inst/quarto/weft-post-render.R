# weft post-render script (rules 2.6.6, 2.9.2, 2.9.4, 2.9.5). Written by
# weft::use_quarto(); run by Quarto after the render, in the project root.
#
# Plain base R: works when weft is not installed. It prints ONE report for
# the whole render, in the layout of rule 2.6.2:
#   * the failures the chapters appended to .weft/failures.jsonl and the
#     filter's findings (a filter line that repeats a knit line, or a
#     failure recorded in a stamp, is dropped);
#   * the failures recorded in the stamp of every document served from
#     freeze, which was not executed in this render (2.9.4);
#   * a freeze notice per such document with constructs: how many checks did
#     not run, and when they last did (2.9.2).
# It removes the collection file and exits non-zero while there are failures
# (not in draft mode, 9.4.3). A freeze notice alone fails nothing.

local({
  root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  coll <- file.path(root, ".weft", "failures.jsonl")
  runf <- file.path(root, ".weft", "run")
  sdir <- file.path(root, ".weft", "stamps")

  rd <- function(f) {
    if (!file.exists(f)) return(character())
    x <- readLines(f, warn = FALSE, encoding = "UTF-8")
    x[nzchar(trimws(x))]
  }

  # ---- a minimal reader for the JSON the weft files hold --------------------
  unescape <- function(v) {
    # one left-to-right pass over the JSON escapes, so `\\n` (a backslash
    # then n) is not read as a newline
    m <- gregexpr("\\\\(u[0-9a-fA-F]{4}|.)", v, perl = TRUE)
    tok <- regmatches(v, m)[[1]]
    if (!length(tok)) return(v)
    rep <- vapply(tok, function(t) {
      ch <- substring(t, 2L)
      if (nchar(ch) == 5L && startsWith(ch, "u")) return(intToUtf8(strtoi(substring(ch, 2L), 16L)))
      switch(ch, n = "\n", r = "", t = "\t", b = "\b", f = "\f", ch)
    }, "", USE.NAMES = FALSE)
    regmatches(v, m) <- list(rep)
    v
  }
  field <- function(l, k) {
    m <- regmatches(l, regexec(sprintf("\"%s\":\\s*(\"((?:[^\"\\\\]|\\\\.)*)\"|[^,}\"]*)", k),
                               l, perl = TRUE))[[1]]
    if (length(m) < 3) return(NA_character_)
    if (startsWith(m[2], "\"")) return(unescape(m[3]))
    v <- trimws(m[2])
    if (identical(v, "null") || !nzchar(v)) NA_character_ else v
  }
  record <- function(l) {
    ln <- suppressWarnings(as.integer(field(l, "line")))
    kind <- field(l, "kind")
    detail <- field(l, "detail")
    if (is.na(detail) && !is.na(field(l, "message"))) {
      # a filter line: what it found, and the text
      detail <- paste0(field(l, "message"), ": ", field(l, "text"))
    }
    list(source = field(l, "source"), kind = ifelse(is.na(kind), "failure", kind),
         file = field(l, "file"), line = ln, chunk = field(l, "chunk"),
         expr = field(l, "expr"), detail = detail, hint = field(l, "hint"),
         option = field(l, "option"), chunk_line = suppressWarnings(as.integer(field(l, "chunk_line"))))
  }
  relpath <- function(f) {
    if (is.na(f)) return(f)
    f <- gsub("\\\\", "/", f)
    pre <- paste0(root, "/")
    if (startsWith(f, pre)) substring(f, nchar(pre) + 1L) else sub("^\\./", "", f)
  }

  # ---- the run ----------------------------------------------------------------
  run <- rd(runf)
  run_id <- if (length(run)) run[1] else ""
  run_files <- if (length(run) > 1L) run[-1] else character()

  recs <- lapply(rd(coll), record)
  for (i in seq_along(recs)) recs[[i]]$file <- relpath(recs[[i]]$file)

  # ---- documents served from freeze ------------------------------------------
  frozen <- list()
  for (sf in list.files(sdir, pattern = "\\.json$", full.names = TRUE)) {
    x <- rd(sf)
    if (!length(x)) next
    all <- paste(x, collapse = "")
    src <- field(all, "source")
    if (is.na(src) || !(src %in% run_files)) next
    if (nzchar(run_id) && identical(field(all, "run"), run_id)) next
    fl <- grep("^\\s*\\{\"source\"", x, value = TRUE)
    chk <- suppressWarnings(as.integer(field(all, "checks")))
    frozen[[src]] <- list(
      checks = if (is.na(chk)) 0L else chk,
      executed = field(all, "executed"),
      failures = lapply(sub(",\\s*$", "", fl), record))
  }

  # ---- one list of failures -------------------------------------------------
  key <- function(r) paste(r$file, r$line, r$kind, sep = "\r")
  fails <- Filter(function(r) !identical(r$source, "filter"), recs)
  for (d in frozen) fails <- c(fails, d$failures)
  seen <- vapply(fails, key, "")
  for (r in recs) {
    if (identical(r$source, "filter") && !(key(r) %in% seen)) {
      fails[[length(fails) + 1L]] <- r
      seen <- c(seen, key(r))
    }
  }

  where <- function(r) {
    f <- if (is.na(r$file)) "<unknown>" else r$file
    if (!is.na(r$line)) sprintf("%s:%d", f, r$line)
    else if (!is.na(r$chunk)) sprintf("%s chunk %s%s%s", f, r$chunk,
                                      if (!is.na(r$chunk_line)) sprintf(" (the chunk at line %d)", r$chunk_line) else "",
                                      if (!is.na(r$option)) paste0(", ", r$option) else "")
    else f
  }
  entry <- function(r, tag = FALSE) {
    head <- sprintf("  %s  %s%s", where(r), if (tag) paste0("[", r$kind, "] ") else "",
                    if (is.na(r$expr)) "" else r$expr)
    det <- if (is.na(r$detail)) character() else strsplit(r$detail, "\n", fixed = TRUE)[[1]]
    det <- if (length(det)) paste0("      ", det) else character()
    hint <- if (!is.na(r$hint) && nzchar(r$hint)) paste0("      ", r$hint) else character()
    c(sub("\\s+$", "", head), det, hint)
  }
  claims <- Filter(function(r) identical(r$kind, "failed claim"), fails)
  other <- Filter(function(r) !identical(r$kind, "failed claim"), fails)
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
  fz <- Filter(function(d) d$checks > 0L, frozen)
  if (length(fz)) {
    out <- c(out, "", "Served from freeze, not executed in this render (their checks did not run):",
             vapply(names(fz), function(n) {
               sprintf("  %s: %d check%s did not run; last run %s", n, fz[[n]]$checks,
                       if (fz[[n]]$checks == 1L) "" else "s",
                       if (is.na(fz[[n]]$executed)) "at an unknown time" else fz[[n]]$executed)
             }, ""))
    if (any(vapply(fz, function(d) length(d$failures) > 0L, NA))) {
      out <- c(out, "A frozen document with recorded failures fails the render until it is executed again.")
    }
  }

  unlink(c(coll, runf))
  if (length(out)) cat(out, sep = "\n", file = stderr())
  if (!length(fails)) return(invisible())

  # draft mode reports and does not fail (9.4.3)
  draft <- tolower(Sys.getenv("WEFT_DRAFT", "")) %in% c("1", "true", "yes", "on")
  if (!draft && file.exists("_weft.yml")) {
    d <- grep("^draft:", readLines("_weft.yml", warn = FALSE), value = TRUE)
    if (length(d)) draft <- tolower(trimws(sub("#.*$", "", sub("^draft:", "", d[length(d)])))) %in% c("true", "yes", "1")
  }
  if (!draft) quit(save = "no", status = 1L)
})
