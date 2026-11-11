# weft post-render script (rules 2.6.6, 2.9.2, 2.9.4, 2.9.5). Written by
# weft::use_quarto(); run by Quarto after the render, in the project root.
#
# Plain base R: works when weft is not installed. It prints ONE report for
# the whole render, in the layout of rule 2.6.2:
#   * the failures the chapters appended to .weft/failures.jsonl and the
#     filter's findings (a filter line is dropped only when it is a marker
#     that a knit line or a failure recorded in a stamp explains);
#   * the failures recorded in the stamp of every document served from
#     freeze, which was not executed in this render (2.9.4);
#   * a freeze notice per such document with constructs: how many checks did
#     not run, and when they last did (2.9.2).
# Warned checks (level "warn") are listed after the failures and fail nothing.
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
    list(source = field(l, "source"), level = field(l, "level"), kind = ifelse(is.na(kind), "failure", kind),
         text = field(l, "text"),
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

  # the first line of the collection file names the run; only lines that are
  # a failure or a finding are records
  cl <- rd(coll)
  recs <- lapply(cl[grepl("\"source\":", cl, fixed = TRUE)], record)
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

  # a document served from freeze that has no stamp at all (a fresh clone:
  # `_freeze/` is committed, `.weft/stamps/` is not) was never checked on this
  # machine. It is told from one that holds no construct by looking for a
  # construct in its source (2.9.2).
  stamped <- vapply(list.files(sdir, pattern = "\\.json$", full.names = TRUE), function(sf) {
    f <- field(paste(rd(sf), collapse = ""), "source")
    if (is.na(f)) "" else f
  }, "")
  has_construct <- function(f) {
    x <- tryCatch(readLines(file.path(root, f), warn = FALSE, encoding = "UTF-8"),
                  error = function(e) character())
    if (length(x) && grepl("^---\\s*$", x[1])) {
      end <- which(grepl("^(---|\\.\\.\\.)\\s*$", x[-1]))
      if (length(end)) x <- x[-seq_len(end[1] + 1L)]
    }
    any(grepl("\\]\\{([^}]*[[:space:]])?(n|if|sign|cite)[[:space:]]*=", x, ignore.case = TRUE, perl = TRUE) |
          grepl("\\]\\{([^}]*[[:space:]])?\\.(a|cap|strong|em)([[:space:]}]|$)", x, perl = TRUE) |
          grepl("`(r |R |\\{r\\})[^`]*`\\{[^}]*\\}", x, perl = TRUE))
  }
  unchecked <- character()
  for (f in run_files) {
    if (!grepl("\\.qmd$", f, ignore.case = TRUE) || f %in% stamped) next
    stem <- sub("\\.[^.]*$", "", f)
    if (!dir.exists(file.path(root, "_freeze", stem, "execute-results"))) next
    if (has_construct(f)) unchecked <- c(unchecked, f)
  }

  # ---- one list of failures -------------------------------------------------
  # A filter finding has no line (it works on Pandoc's tree). It is keyed by
  # its file, kind and text, so two different findings are never merged, and
  # is dropped only when it is a `<<weft:` marker that a knit record already
  # explains: the same file and kind, and the same line (or, with no line,
  # the same chunk).
  # a warned check (level "warn") is listed after the failures and fails nothing
  warned <- Filter(function(r) identical(r$level, "warn"), recs)
  recs <- Filter(function(r) !identical(r$level, "warn"), recs)
  fails <- Filter(function(r) !identical(r$source, "filter"), recs)
  for (d in frozen) fails <- c(fails, d$failures)
  explained <- function(r) {
    if (is.na(r$detail) || !grepl("<<weft:", r$detail, fixed = TRUE)) return(FALSE)
    if (is.na(r$line) && is.na(r$chunk)) return(FALSE)
    for (k in fails) {
      if (!identical(k$file, r$file) || !identical(k$kind, r$kind)) next
      if (!is.na(r$line)) { if (identical(k$line, r$line)) return(TRUE) }
      else if (identical(k$chunk, r$chunk)) return(TRUE)
    }
    FALSE
  }
  seen <- character()
  for (r in recs) {
    if (!identical(r$source, "filter")) next
    k <- paste(r$file, r$kind, r$text, sep = "\r")
    if (k %in% seen || explained(r)) next
    seen <- c(seen, k)
    fails[[length(fails) + 1L]] <- r
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
  if (length(warned)) {
    out <- c(out, sprintf("weft: %d warned check(s)", length(warned)),
             unlist(lapply(warned, entry)))
  }
  fz <- Filter(function(d) d$checks > 0L, frozen)
  if (length(fz) || length(unchecked)) {
    out <- c(out, "", "Served from freeze, not executed in this render (their checks did not run):",
             vapply(names(fz), function(n) {
               sprintf("  %s: %d construct%s %s not checked; last run %s", n, fz[[n]]$checks,
                       if (fz[[n]]$checks == 1L) "" else "s",
                       if (fz[[n]]$checks == 1L) "was" else "were",
                       if (is.na(fz[[n]]$executed)) "at an unknown time" else fz[[n]]$executed)
             }, ""),
             vapply(unchecked, function(n) {
               sprintf("  %s: never checked on this machine (there is no stamp for it, so its constructs were not checked here)", n)
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
