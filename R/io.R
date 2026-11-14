# The shared foundations of weft's reading and writing: one reader of source
# text, one reader of YAML, one runner of git, one finder of the project root,
# one lister of a project's documents and one atomic writer. Nothing else in
# `R/` reads a file as text, parses YAML, runs git, walks up to a root, lists a
# project's documents or writes a file into a project or cache by its own
# means (dev/review-code-{a,b,c}.md, the rulings on items a7, b1, b5, b11,
# b12, c3, c7, c9).

# ---- source text ----------------------------------------------------------------------------------

# The bytes of a file, without a leading byte-order mark.
read_source_bytes <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  bytes <- readBin(con, "raw", max(file.size(path), 0, na.rm = TRUE))
  if (length(bytes) >= 3L && identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) bytes <- bytes[-(1:3)]
  bytes
}

# The text of a file as one string: UTF-8, no byte-order mark, and "\n" for
# every line end (CRLF and a lone CR alike). A NUL byte or text that is not
# UTF-8 is a `weft_encoding_error` naming the file. A missing final newline is
# kept as it is (it is only a missing "\n"). `class` is put before
# `weft_encoding_error` on that error, for a caller whose own condition class
# the reader of that file has always had (`weft_dict_error`, `weft_config_error`).
read_source_text <- function(path, class = NULL) {
  bytes <- read_source_bytes(path)
  if (any(bytes == as.raw(0L))) {
    weft_abort(sprintf("%s holds a NUL byte, so it is not text; save the file as UTF-8.", path),
               c(class, "weft_encoding_error"))
  }
  text <- rawToChar(bytes)
  Encoding(text) <- "UTF-8"
  if (!validUTF8(text)) {
    weft_abort(sprintf("%s is not valid UTF-8; save the file as UTF-8.", path),
               c(class, "weft_encoding_error"))
  }
  text <- gsub("\r\n", "\n", text, fixed = TRUE)
  gsub("\r", "\n", text, fixed = TRUE)
}

# The lines of a file, as `read_source_text()` reads it; `character()` for an
# empty file.
read_source_lines <- function(path, class = NULL) split_source_lines(read_source_text(path, class))

# The same text, or NULL for a file that is not text (a NUL byte, or not UTF-8):
# for the lints, which judge such a file invalid and go on.
read_source_text_or_null <- function(path) {
  tryCatch(read_source_text(path), weft_encoding_error = function(e) NULL)
}

split_source_lines <- function(text) {
  if (!nzchar(text)) return(character())
  strsplit(text, "\n", fixed = TRUE)[[1L]]
}

# ---- YAML -----------------------------------------------------------------------------------------

# The one YAML reading of weft. Only `true` and `false` (in any letter case)
# are booleans: `yes`, `no`, `on`, `off`, `y` and `n` stay text, as they are in
# YAML 1.2 and in Quarto; as a mapping key `N` is the text `N`. `!expr` is never
# evaluated, whatever `yaml.eval.expr` says. `handlers` replace the defaults of
# the same name. A parse failure is a `weft_yaml_error` naming `file`.
YAML_HANDLERS <- list(
  "bool#yes" = function(x) if (tolower(x) == "true") TRUE else x,
  "bool#no" = function(x) if (tolower(x) == "false") FALSE else x)

yaml_read_text <- function(text, file = NULL, handlers = NULL) {
  text <- paste(text, collapse = "\n")
  h <- YAML_HANDLERS
  h[names(handlers)] <- handlers
  tryCatch(yaml::yaml.load(text, handlers = h, eval.expr = FALSE),
           error = function(e) {
             msg <- conditionMessage(e)
             weft_abort(if (is.null(file)) msg else sprintf("%s: %s", file, msg), "weft_yaml_error")
           })
}

# The YAML of a file; the file is read as source text (`read_source_text()`).
yaml_read_file <- function(path, handlers = NULL) {
  yaml_read_text(read_source_text(path), file = path, handlers = handlers)
}

# JSON, as plain lists (objects named, arrays unnamed). Not yaml: libyaml refuses the surrogate pair
# json_string() writes for a character outside the BMP.
json_read_text <- function(text, file = NULL) {
  text <- paste(text, collapse = "\n")
  tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE),
           error = function(e) {
             msg <- conditionMessage(e)
             weft_abort(if (is.null(file)) msg else sprintf("%s: %s", file, msg), "weft_json_error")
           })
}

# The JSON of a file; the file is read as source text (`read_source_text()`).
json_read_file <- function(path) json_read_text(read_source_text(path), file = path)

# ---- git ------------------------------------------------------------------------------------------

# where git is: "" when it is not on the PATH
git_path <- function() unname(Sys.which("git"))

# Run git in `dir`; every argument is quoted, so no shell reads any of them.
# Always `--no-optional-locks` (git's own option, for it works where system2()'s `env =` does not, on
# Windows) and `-c core.quotepath=false`. Returns
# `list(status, out (raw), err (character))`. When git is not on the PATH it is a
# `weft_git_error` (also a `weft_gate_error`).
git_raw <- function(dir, args, input = NULL) {
  git <- git_path()
  if (!nzchar(git)) {
    weft_abort("git was not found on the PATH, so weft cannot read the repository (rule 6.1.1).",
               c("weft_git_error", "weft_gate_error"))
  }
  out <- tempfile("weft-git-out-")
  err <- tempfile("weft-git-err-")
  on.exit(unlink(c(out, err)), add = TRUE)
  full <- c("--no-optional-locks", "-C", dir, "-c", "core.quotepath=false", args)
  st <- suppressWarnings(system2(git, shQuote(full), stdout = out, stderr = err, input = input))
  st <- if (is.null(st)) 0L else as.integer(st)
  list(status = st,
       out = readBin(out, "raw", max(file.size(out), 0, na.rm = TRUE)),
       err = suppressWarnings(readLines(err, warn = FALSE)))
}

# git must succeed, else a `weft_git_error` (also a `weft_gate_error`) naming the command
git_ok <- function(dir, args, input = NULL) {
  r <- git_raw(dir, args, input)
  if (!identical(r$status, 0L)) {
    weft_abort(paste0("git ", paste(args[seq_len(min(2L, length(args)))], collapse = " "), " failed",
                      if (length(r$err)) paste0(": ", paste(r$err, collapse = " ")) else "", "."),
               c("weft_git_error", "weft_gate_error"))
  }
  r
}

# The lines git printed, or NULL: no git, or git failed.
git_lines <- function(dir, args) {
  r <- tryCatch(git_raw(dir, args), weft_git_error = function(e) NULL)
  if (is.null(r) || !identical(r$status, 0L)) return(NULL)
  raw_lines(r$out)
}

# The NUL-terminated records of a command that lists paths (give it `-z`), or
# NULL: no git, or git failed.
git_records <- function(dir, args) {
  r <- tryCatch(git_raw(dir, args), weft_git_error = function(e) NULL)
  if (is.null(r) || !identical(r$status, 0L)) return(NULL)
  raw_records(r$out)
}

# the lines of git's raw output as UTF-8 text (a CRLF counts as a line end)
raw_lines <- function(x) {
  s <- rawToChar(x)
  Encoding(s) <- "UTF-8"
  if (!nzchar(s)) return(character())
  s <- gsub("\r\n", "\n", s, fixed = TRUE)
  strsplit(sub("\n$", "", s), "\n", fixed = TRUE)[[1L]]
}

# NUL-terminated records of a raw vector, as UTF-8 strings
raw_records <- function(x) {
  if (!length(x)) return(character())
  z <- which(x == as.raw(0L))
  st <- c(1L, z + 1L)
  en <- c(z - 1L, length(x))
  keep <- st <= length(x) & en >= st
  vapply(which(keep), function(i) {
    s <- rawToChar(x[st[i]:en[i]])
    Encoding(s) <- "UTF-8"
    s
  }, "")
}

# ---- the project root -----------------------------------------------------------------------------

# The nearest folder, from `start` upward, that holds any of `markers`, or NA.
find_up <- function(start, markers) {
  d <- start
  repeat {
    if (any(file.exists(file.path(d, markers)))) return(d)
    up <- dirname(d)
    if (identical(up, d)) return(NA_character_)
    d <- up
  }
}

QUARTO_MARKERS <- c("_quarto.yml", "_quarto.yaml")
METADATA_MARKERS <- c("_metadata.yml", "_metadata.yaml")

# `path` relative to `root`: the text after `root/`, or `path` unchanged when it
# is not inside `root`. Both are read as they are written (normalise them first
# if they may differ in spelling); the separator is `/`. A root that already
# ends in a separator (`/`, `C:/`) is not given a second one.
rel_to <- function(path, root) {
  prefix <- if (endsWith(root, "/")) root else paste0(root, "/")
  inside <- startsWith(path, prefix) %in% TRUE
  path[inside] <- substring(path[inside], nchar(prefix) + 1L)
  path
}

# The nearest folder, from the file (or folder) upward, that holds `_weft.yml`;
# failing that one that holds `_quarto.yml` or `_quarto.yaml`; failing that the
# folder itself.
find_project_root <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  start <- if (dir.exists(path)) path else dirname(path)
  for (markers in list("_weft.yml", QUARTO_MARKERS)) {
    r <- find_up(start, markers)
    if (!is.na(r)) return(r)
  }
  start
}

# The Quarto project root at or above `start` (a folder), or NULL.
find_quarto_root <- function(start) {
  r <- find_up(start, QUARTO_MARKERS)
  if (is.na(r)) NULL else r
}

# ---- a project's documents ------------------------------------------------------------------------

DOC_EXT_RE <- "\\.(qmd|Rmd|rmd)$"

# Folders that are never a project's own documents, by name: the libraries
# a project vendors, and the folders Quarto writes to or reads from.
DOC_VENDORED_DIRS <- c("renv", "packrat", "node_modules")
DOC_QUARTO_DIRS <- c("_site", "_book", "_freeze", "_extensions")

# Which relative paths (under the project root, with "/") are documents of a
# project for `use`:
#   "lint"    the documents that are read and judged: not in a dot-folder, a
#             vendored folder, a folder Quarto writes to, or a `_` folder
#             (includes, partials); a `_x.qmd` file is one (it is an include,
#             and a rule that cares skips it itself)
#   "anchors" the documents in `_` folders only, which are read for anchors
#   "setup"   the documents that set-up and status act on: as "lint", but no
#             `_` file either
# A file whose name starts with "." is never one.
doc_path_ok <- function(rel, use = c("lint", "anchors", "setup")) {
  use <- match.arg(use)
  parts <- strsplit(rel, "/", fixed = TRUE)
  vapply(parts, function(p) {
    f <- p[length(p)]
    d <- p[-length(p)]
    if (startsWith(f, ".")) return(FALSE)
    hid <- any(startsWith(d, ".") | d %in% DOC_VENDORED_DIRS | d %in% DOC_QUARTO_DIRS)
    us <- any(startsWith(d, "_"))
    switch(use,
           lint = !hid && !us,
           anchors = !hid && us,
           setup = !hid && !us && !startsWith(f, "_"))
  }, NA)
}

# The documents of the project at `root`, as sorted relative paths with "/"
# (`pattern` picks the extension; `.qmd`, `.Rmd` and `.rmd` by default).
project_doc_paths <- function(root, use = c("lint", "anchors", "setup"), pattern = DOC_EXT_RE) {
  use <- match.arg(use)
  # dot-folders and dot-files are never listed, so `.git` and `.quarto` are not walked
  f <- list.files(root, pattern = pattern, recursive = TRUE, include.dirs = FALSE)
  if (!length(f)) return(character())
  f <- f[doc_path_ok(f, use)]
  sort(enc2utf8(f), method = "radix")
}

# ---- writing --------------------------------------------------------------------------------------

# Write `bytes` (raw) to `path` by writing a temporary file in the same folder
# and renaming it over the target, so a reader never sees half a file. Makes the
# folder; keeps the mode of the file it replaces. Stops when it cannot write.
# With `skip_same`, a file that already holds these bytes is left alone (and its
# time kept). Returns whether it wrote.
write_atomic <- function(path, bytes, skip_same = FALSE) {
  d <- dirname(path)
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE)
    if (!dir.exists(d)) stop("cannot create the folder ", d, call. = FALSE)
  }
  exists <- file.exists(path) && !dir.exists(path)
  if (skip_same && exists && identical(readBin(path, "raw", file.size(path)), bytes)) {
    return(invisible(FALSE))
  }
  tmp <- tempfile(paste0(".", basename(path), ".tmp"), tmpdir = d)
  on.exit(unlink(tmp), add = TRUE)
  writeBin(bytes, tmp)
  if (exists) Sys.chmod(tmp, file.mode(path), use_umask = FALSE)
  rename_over(tmp, path)
  invisible(TRUE)
}

# rename `tmp` over `path`; where the rename fails, copy it
rename_over <- function(tmp, path) {
  if (!suppressWarnings(file.rename(tmp, path))) {
    if (!file.copy(tmp, path, overwrite = TRUE)) stop("cannot write ", path, call. = FALSE)
  }
}

# Write lines of text, each followed by `eol`, as UTF-8, atomically. A shell
# script must not get CRLF, so `eol` is explicit.
write_lines_atomic <- function(x, path, eol = "\n", skip_same = FALSE) {
  write_atomic(path, charToRaw(paste0(enc2utf8(x), eol, collapse = "")), skip_same)
}

# Copy a file atomically, as `file.copy()` does: TRUE when it was copied, FALSE
# when it was not (or `overwrite` is FALSE and `to` exists).
copy_atomic <- function(from, to, overwrite = TRUE) {
  if (!overwrite && file.exists(to)) return(FALSE)
  tryCatch({
    write_atomic(to, readBin(from, "raw", file.size(from)))
    Sys.chmod(to, file.mode(from), use_umask = FALSE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
}

# `saveRDS()` to a temporary file in the folder of `path`, then a rename.
write_rds_atomic <- function(object, path, ...) {
  d <- dirname(path)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  tmp <- tempfile(paste0(".", basename(path), ".tmp"), tmpdir = d)
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(object, tmp, ...)
  rename_over(tmp, path)
  invisible(path)
}
