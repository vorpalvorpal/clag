# The commit gate's reading of git (design-4 G3, G5-G8, G13, G16, G17).
#
# Every call is read-only plumbing, run as `git -C <dir> -c core.quotepath=false`:
# rev-parse, ls-files, ls-tree, cat-file, diff, interpret-trailers. Nothing here
# changes the repository, and the only temporary files are removed on exit.

gate_abort <- function(message) weft_abort(message, "weft_gate_error")

GATE_CONTENT_RE <- "\\.(qmd|Rmd|rmd|md|yml|yaml|json|bib|bibtex)$"
GATE_MAX_BYTES <- 5 * 1024 * 1024

# ---- the repository ---------------------------------------------------------------------------------

# top, git directory and common git directory of the work tree `path` is in
git_where <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    gate_abort("`path` must be one folder inside a git work tree (rule 6.1.1).")
  }
  r <- git_raw(path, c("rev-parse", "--path-format=absolute", "--show-toplevel", "--absolute-git-dir",
                       "--git-common-dir"))
  if (!identical(r$status, 0L)) {
    gate_abort(paste0(path, " is not inside a git work tree, so there is no commit to gate (rule 6.1.1)."))
  }
  v <- raw_lines(r$out)
  if (length(v) < 3L) gate_abort(paste0(path, " is not inside a git work tree (rule 6.1.1)."))
  list(top = v[1L], gitdir = v[2L], common = v[3L])
}

# the commit HEAD names, or NA when it is unborn
git_head <- function(top) {
  r <- git_raw(top, c("rev-parse", "-q", "--verify", "HEAD^{commit}"))
  if (!identical(r$status, 0L)) return(NA_character_)
  trimws(raw_lines(r$out)[1L])
}

# the heads being merged, from MERGE_HEAD (one per line), else none
git_merge_heads <- function(gitdir) {
  f <- file.path(gitdir, "MERGE_HEAD")
  if (!file.exists(f)) return(character())
  h <- trimws(read_source_lines(f))
  h[nzchar(h)]
}

# ---- sides (G5) -------------------------------------------------------------------------------------

gate_empty_entries <- function() {
  data.frame(path = character(), mode = character(), blob = character(), stringsAsFactors = FALSE)
}

split_meta <- function(rec) {
  tab <- regexpr("\t", rec, fixed = TRUE)
  list(meta = substr(rec, 1L, tab - 1L), path = substring(rec, tab + 1L))
}

# the tracked paths of a commit, with modes and blob ids (all of the repository)
git_entries_commit <- function(top, commit) {
  r <- git_ok(top, c("ls-tree", "-r", "-z", "--full-tree", commit))
  rec <- raw_records(r$out)
  if (!length(rec)) return(gate_empty_entries())
  s <- split_meta(rec)
  parts <- strsplit(s$meta, " ", fixed = TRUE)
  data.frame(path = s$path, mode = vapply(parts, `[`, "", 1L), blob = vapply(parts, `[`, "", 3L),
             stringsAsFactors = FALSE)
}

# the tracked paths of the index (stage 0), the inherited GIT_INDEX_FILE deciding which
git_entries_index <- function(top) {
  r <- git_ok(top, c("ls-files", "-s", "-z"))
  rec <- raw_records(r$out)
  if (!length(rec)) return(gate_empty_entries())
  s <- split_meta(rec)
  parts <- strsplit(s$meta, " ", fixed = TRUE)
  stage <- vapply(parts, `[`, "", 3L)
  out <- data.frame(path = s$path, mode = vapply(parts, `[`, "", 1L), blob = vapply(parts, `[`, "", 2L),
                    stringsAsFactors = FALSE)
  out[stage == "0", , drop = FALSE]
}

# sizes of blobs (named by id); NA for one git does not have
git_sizes <- function(top, blobs) {
  blobs <- unique(blobs)
  if (!length(blobs)) return(stats::setNames(integer(), character()))
  r <- git_ok(top, c("cat-file", "--batch-check"), input = blobs)
  ln <- raw_lines(r$out)
  p <- strsplit(ln, " ", fixed = TRUE)
  ids <- vapply(p, `[`, "", 1L)
  sz <- suppressWarnings(as.numeric(vapply(p, function(x) if (length(x) >= 3L) x[3L] else NA_character_, "")))
  stats::setNames(sz, ids)
}

# the bytes of blobs, from one `cat-file --batch` (a named list of raw vectors)
git_blobs <- function(top, blobs) {
  blobs <- unique(blobs)
  if (!length(blobs)) return(list())
  r <- git_ok(top, c("cat-file", "--batch"), input = blobs)
  x <- r$out
  n <- length(x)
  out <- list()
  pos <- 1L
  nl <- as.raw(10L)
  while (pos <= n) {
    stop_at <- min(n, pos + 200L)
    k <- which(x[pos:stop_at] == nl)[1L]
    if (is.na(k)) break
    hdr <- rawToChar(x[pos:(pos + k - 2L)])
    pos <- pos + k
    h <- strsplit(hdr, " ", fixed = TRUE)[[1L]]
    if (length(h) >= 3L && h[2L] == "blob") {
      size <- as.integer(h[3L])
      out[[h[1L]]] <- if (size > 0L) x[pos:(pos + size - 1L)] else raw()
      pos <- pos + size + 1L
    }
  }
  out
}

# ---- classifying a project's side (G6-G8) -------------------------------------------------------------

# a document of L3's file set, by its path relative to the project root
is_doc_path <- function(rel) grepl(DOC_EXT_RE, rel) & doc_path_ok(rel, "lint")

is_content_path <- function(rel) grepl(GATE_CONTENT_RE, rel) | basename(rel) == ".Rprofile"

# The folders of a project's targets store: `_targets`, or `_targets.yaml`'s `main: store:`.
store_dirs <- function(top, ent) {
  s <- "_targets"
  i <- match("_targets.yaml", ent$rel)
  if (!is.na(i) && ent$mode[i] %in% c("100644", "100755")) {
    b <- git_blobs(top, ent$blob[i])[[ent$blob[i]]]
    y <- if (length(b)) tryCatch(yaml_read_text(rawToChar(b)), error = function(e) NULL) else NULL
    v <- tryCatch(y$main$store, error = function(e) NULL)
    if (is.character(v) && length(v) == 1L && nzchar(v)) s <- c(s, sub("/+$", "", sub("^\\./", "", v)))
  }
  unique(s)
}

# Added lines of a document (G16): the lines `base` -> `new` added, or TRUE for every line. The attribute
# `deleted` holds the lines of the `-` side the diff deleted or changed (F9, N134), or TRUE when the diff
# could not say.
git_added_lines <- function(top, base_blob, new_blob) {
  if (is.na(base_blob) || !nzchar(base_blob)) return(TRUE)
  r <- git_raw(top, c("diff", "-U0", "--no-color", "--no-ext-diff", base_blob, new_blob))
  if (!identical(r$status, 0L) && !identical(r$status, 1L)) return(structure(TRUE, deleted = TRUE))
  h <- diff_hunk_lines(raw_lines(r$out))
  structure(h$added, deleted = h$deleted)
}

# The line numbers a `-U0` unified diff (its lines) adds, on the `+` side, and deletes or changes, on the `-`
# side: list(added, deleted), both integer.
diff_hunk_lines <- function(ln) {
  h <- regmatches(ln, regexec("^@@ -([0-9]+)(?:,([0-9]+))? \\+([0-9]+)(?:,([0-9]+))? @@", ln, perl = TRUE))
  h <- Filter(length, h)
  span <- function(first, count) {
    c0 <- as.integer(first)
    d <- if (nzchar(count)) as.integer(count) else 1L
    if (d == 0L) integer() else seq.int(c0, c0 + d - 1L)
  }
  added <- unlist(lapply(h, function(m) span(m[4L], m[5L])))
  deleted <- unlist(lapply(h, function(m) span(m[2L], m[3L])))
  list(added = if (is.null(added)) integer() else added, deleted = if (is.null(deleted)) integer() else deleted)
}

# ---- trailers (G13) -----------------------------------------------------------------------------------

# The last `Weft-Removed` trailer of a message file: list(present, value, number).
git_trailer <- function(top, message) {
  none <- list(present = FALSE, value = NA_character_, number = NA_integer_)
  if (is.null(message)) return(none)
  if (!is.character(message) || length(message) != 1L || is.na(message) || !file.exists(message)) {
    gate_abort("`message` must be NULL or the path of a commit message file (rule 6.1.2).")
  }
  r <- git_ok(top, c("interpret-trailers", "--parse", normalizePath(message, winslash = "/")))
  ln <- raw_lines(r$out)
  m <- regmatches(ln, regexec("^[Ww][Ee][Ff][Tt]-[Rr][Ee][Mm][Oo][Vv][Ee][Dd][ \t]*:[ \t]*(.*)$", ln))
  m <- Filter(length, m)
  if (!length(m)) return(none)
  v <- trimws(m[[length(m)]][2L])
  num <- if (grepl("^[0-9]+$", v)) suppressWarnings(as.integer(v)) else NA_integer_
  list(present = TRUE, value = v, number = num)
}
