# Shared machinery of the installers use_hooks(), use_ci(), use_agent_docs() and
# use_weft() (design-4 G40, G41): the `weft-file` marker and its hash, the state
# of a whole file weft writes, the checks made before anything is written, and
# the messages. Contract: dev/design-4.md.

# ---- reading and writing text -------------------------------------------------

inst_file <- function(...) {
  p <- system.file(..., package = "weft")
  if (!nzchar(p)) {
    tool_abort(paste0("weft's own file inst/", paste(c(...), collapse = "/"), " is missing."))
  }
  p
}


# The line ending an existing text file uses: "\r\n" when most of its lines end so, else "\n" (also for a
# file that is not there). An installer that rewrites a file the author wrote keeps it (review 4, #16).
file_eol <- function(path) {
  n <- suppressWarnings(file.size(path))
  if (is.na(n) || n == 0 || dir.exists(path)) return("\n")
  r <- readBin(path, "raw", n)
  lf <- which(r == as.raw(10L))
  if (!length(lf)) return("\n")
  crlf <- sum(lf > 1L & r[pmax(lf - 1L, 1L)] == as.raw(13L))
  if (crlf * 2L > length(lf)) "\r\n" else "\n"
}

# replace every occurrence of `key` in `x` by `value`, with no regular-expression
# or back-reference reading of either
subst_fixed <- function(x, key, value) {
  vapply(x, function(s) {
    out <- ""
    repeat {
      m <- regexpr(key, s, fixed = TRUE)
      if (m < 0L) break
      out <- paste0(out, substr(s, 1L, m - 1L), value)
      s <- substr(s, m + nchar(key), nchar(s))
    }
    paste0(out, s)
  }, "", USE.NAMES = FALSE)
}

sh_quote <- function(x) gsub("'", "'\\\\''", x)

rel_label <- function(path, root) {
  pre <- paste0(root, "/")
  ifelse(startsWith(path, pre), substring(path, nchar(pre) + 1L), path)
}

# ---- the weft-file marker (G40) ------------------------------------------------

# The marker line of whole file `lines` written by `fn`: list(idx, version, hash,
# valid), or NULL. `valid`: the hash is the md5 of the other lines joined by "\n".
marker_parse <- function(lines, fn) {
  re <- sprintf("weft-file: %s ([^ ]+) ([0-9a-f]{32})", fn)
  i <- grep(re, lines)
  if (!length(i)) return(NULL)
  i <- i[1L]
  m <- regmatches(lines[i], regexec(re, lines[i]))[[1L]]
  list(idx = i, version = m[2L], hash = m[3L],
       valid = identical(m[3L], cli::hash_md5(paste(lines[-i], collapse = "\n"))))
}

# A template with its placeholders filled. `subs` is a named character vector
# ("@PATH@" = ".", ...); the line holding @HASH@ is the marker, and gets the
# version and the hash of all the other lines.
fill_whole <- function(template, subs = character()) {
  x <- template
  for (k in names(subs)) x <- subst_fixed(x, k, subs[[k]])
  i <- grep("@HASH@", x, fixed = TRUE)[1L]
  h <- cli::hash_md5(paste(x[-i], collapse = "\n"))
  x[i] <- subst_fixed(subst_fixed(x[i], "@VERSION@", weft_version_string()), "@HASH@", h)
  x
}

# ---- the state of a file (G40) -------------------------------------------------

EDITED_TEXT <- "edited since weft wrote it; left as it is (use overwrite = TRUE to replace it)"
FOREIGN_TEXT <- "not written by weft (no weft-file line); left as it is"

# the state of the whole file at `path` against the lines `new` weft would write:
# new, keep, replace, edited, foreign
whole_state <- function(path, new, fn, exec = FALSE) {
  if (!file.exists(path)) return("new")
  old <- read_source_lines(path)
  m <- marker_parse(old, fn)
  if (is.null(m)) return("foreign")
  if (!m$valid) return("edited")
  # a script that has lost its execute bit is rewritten, which sets the mode again (review 4, #11)
  if (identical(old, new) && !(exec && !is_executable(path))) "keep" else "replace"
}

# can the file be run? (always TRUE on Windows, which has no execute bit)
is_executable <- function(path) {
  .Platform$OS.type == "windows" || file.access(path, 1L) == 0L
}

# the state of a file against the installed version, for status():
# missing, foreign, edited, outdated, ok
file_status <- function(path, fn) {
  if (!file.exists(path)) return("missing")
  m <- marker_parse(read_source_lines(path), fn)
  if (is.null(m)) return("foreign")
  if (!m$valid) return("edited")
  if (!identical(m$version, weft_version_string())) "outdated" else "ok"
}

# ---- refusals before anything is written (G41) ------------------------------------

# A folder or a link where a file should go, or a file where a folder should be,
# on the way from `root` to `path`: a weft_tool_error naming the path.
place_check <- function(path, root = NULL) {
  if (is_link(path)) {
    tool_abort(sprintf(paste0("%s is a symbolic link, and weft does not write through links. ",
                              "Nothing was written."), path))
  }
  if (dir.exists(path)) {
    tool_abort(sprintf("%s is a folder, and weft needs a file there. Nothing was written.", path))
  }
  p <- dirname(path)
  while (!identical(p, dirname(p)) && (is.null(root) || startsWith(p, paste0(root, "/")))) {
    if (file.exists(p) && !dir.exists(p)) {
      tool_abort(sprintf("%s is a file, and weft needs a folder there. Nothing was written.", p))
    }
    p <- dirname(p)
  }
  invisible(TRUE)
}

# ---- plan items, messages and writing -----------------------------------------------

# one planned file: `new` (the lines to write) is NULL when nothing is written
plan_item <- function(path, root, state, purpose, new = NULL, mode = NULL, eol = "\n") {
  text <- switch(state, edited = EDITED_TEXT, foreign = FOREIGN_TEXT, purpose)
  list(path = path, label = rel_label(path, root), state = state, text = text,
       new = new, mode = mode, eol = eol)
}

# the item for a whole file: writes when new or replace, or when edited and
# `overwrite`; leaves it when edited, foreign or kept
whole_item <- function(path, root, new, fn, purpose, overwrite = FALSE, exec = FALSE) {
  state <- whole_state(path, new, fn, exec)
  if (state == "edited" && overwrite) state <- "replace"
  plan_item(path, root, state, purpose,
            new = if (state %in% c("new", "replace")) new else NULL)
}

announce_items <- function(root, items, verb = "write") {
  message("weft will ", verb, ", under ", root, ":")
  for (w in items) message(sprintf("  %s  (%s: %s)", w$label, w$state, w$text))
}

# write the planned files; returns the items written
write_items <- function(items) {
  done <- list()
  for (w in items) {
    if (is.null(w$new)) next
    dir.create(dirname(w$path), showWarnings = FALSE, recursive = TRUE)
    ok <- tryCatch({ write_lines_atomic(w$new, w$path, w$eol %||% "\n"); TRUE },
                   error = function(e) FALSE, warning = function(e) FALSE)
    if (!ok || !file.exists(w$path)) {
      tool_abort(sprintf("weft could not write %s. %s", w$path,
                         if (length(done)) paste0("Written before it failed: ",
                                                  paste(vapply(done, `[[`, "", "label"),
                                                        collapse = ", "), ".")
                         else "Nothing was written."))
    }
    if (!is.null(w$mode)) Sys.chmod(w$path, w$mode, use_umask = FALSE)
    done[[length(done) + 1L]] <- w
  }
  done
}

# the closing message; returns the paths written, invisibly
finish_install <- function(done, what) {
  if (length(done)) {
    message("Wrote: ", paste(vapply(done, `[[`, "", "label"), collapse = ", "))
  } else {
    message("Nothing to change: ", what, " is already set up.")
  }
  invisible(vapply(done, `[[`, "", "path"))
}

# ---- git (reads only, G3) -------------------------------------------------------------

# list(ok, reason, top): is `root` inside a git work tree
git_state <- function(root) {
  if (!nzchar(git_path())) {
    return(list(ok = FALSE, reason = "git was not found on the PATH"))
  }
  r <- git_raw(root, c("rev-parse", "--is-inside-work-tree"))
  if (!identical(r$status, 0L) || !identical(trimws(paste(raw_lines(r$out), collapse = "")), "true")) {
    return(list(ok = FALSE, reason = "not a git repository"))
  }
  t <- git_raw(root, c("rev-parse", "--show-toplevel"))
  top <- trimws(paste(raw_lines(t$out), collapse = ""))
  list(ok = TRUE, reason = NA_character_, top = normalizePath(top, winslash = "/", mustWork = FALSE))
}

# a folder git reports relative to `root`, made absolute
git_dir_of <- function(root, args) {
  r <- git_ok(root, args)
  p <- trimws(paste(raw_lines(r$out), collapse = ""))
  if (!grepl("^(/|[A-Za-z]:)", p)) p <- file.path(root, p)
  normalizePath(p, winslash = "/", mustWork = FALSE)
}

git_hooks_path_set <- function(root) {
  r <- git_raw(root, c("config", "--get", "core.hooksPath"))
  identical(r$status, 0L) && nzchar(trimws(paste(raw_lines(r$out), collapse = "")))
}

# the URL of `origin`, or NA
git_origin <- function(root) {
  r <- git_raw(root, c("remote", "get-url", "origin"))
  if (!identical(r$status, 0L)) return(NA_character_)
  trimws(paste(raw_lines(r$out), collapse = ""))
}

origin_on_github <- function(url) {
  !is.na(url) && grepl("github\\.com[:/]", url)
}

install_root <- function(path, fn) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    tool_abort(sprintf("%s(): `path` must be a directory; got %s.", fn,
                       if (is.character(path) && length(path) == 1L && !is.na(path))
                         paste0("`", path, "`") else "`something else`"))
  }
  normalizePath(find_project_root(path), winslash = "/", mustWork = TRUE)
}
