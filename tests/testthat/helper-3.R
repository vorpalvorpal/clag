# Helpers for the stage 3 (static lints) tests. Contract: dev/design-3.md.
# Written by the 3a test-writer for the 3a files and for the 3b, 3c and 3d
# test-writers, who read this file. ASCII only: write non-ASCII as \uXXXX.
#
# Everything here uses only the public entry points (lints(), lint_rules())
# and, for the source reader, weft:::read_source() and weft:::lint_config()
# as named by L4 and L9. Reuses f2_proj(), f2_cond(), f2_has_class() and
# f2_msg_has() from helper-2f.R (loaded earlier: helper files load in name order).

# ---- constants ----------------------------------------------------------------

# L5: the columns of a weft_findings, in order, and their types
F3_COLS <- c("file", "line", "col", "end_line", "rule", "tier", "spec",
             "context", "text", "message", "hint", "sentence")
F3_TYPES <- c(file = "character", line = "integer", col = "integer",
              end_line = "integer", rule = "character", tier = "integer",
              spec = "character", context = "character", text = "character",
              message = "character", hint = "character", sentence = "character")

# Three documents' worth of lines, each holding exactly one construct error
# (scanner message in brackets):
#   F3_BAD_TWO   [a site]{n="k" if="x"}      two governors (rule 1.1.5)
#   F3_BAD_LIT   [1]{.weft-literal}          no `why` (rule 1.8.10)
#   F3_BAD_PARSE `r x +`{.num}               does not parse (rule 5.3.5)
F3_BAD_TWO   <- "[a site]{n=\"k\" if=\"x\"}"
F3_BAD_LIT   <- "[1]{.weft-literal}"
F3_BAD_PARSE <- "`r x +`{.num}"

# ---- writing files --------------------------------------------------------------

# Write `lines` (character vector, or one string with \n) to `path` as UTF-8,
# creating folders. eol = "\r\n" for CRLF; bom = TRUE prepends a UTF-8 BOM;
# final_newline = FALSE leaves no line break at the end. `raw` (a raw vector)
# is written as is and the other arguments are then ignored.
f3_write <- function(path, lines, eol = "\n", bom = FALSE, final_newline = TRUE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (is.raw(lines)) {
    writeBin(lines, path)
    return(invisible(path))
  }
  if (length(lines) == 1L) lines <- strsplit(lines, "\n", fixed = TRUE)[[1]]
  txt <- paste(lines, collapse = eol)
  if (final_newline) txt <- paste0(txt, eol)
  bytes <- charToRaw(enc2utf8(txt))
  if (bom) bytes <- c(as.raw(c(0xEF, 0xBB, 0xBF)), bytes)
  writeBin(bytes, path)
  invisible(path)
}

# A temporary project folder holding `files` (a named list: names are paths
# relative to the root, values are character vectors of lines, or a raw vector,
# or a list(lines =, eol =, bom =, final_newline =) passed to f3_write()).
# `weft_yml` (lines, optional) becomes _weft.yml. Returns the root (a
# normalised path); the folder is removed when the calling test ends.
lint_proj <- function(files = list(), weft_yml = NULL, env = parent.frame()) {
  root <- file.path(withr::local_tempdir(.local_envir = env), "proj")
  dir.create(root)
  root <- normalizePath(root)
  if (!is.null(weft_yml)) writeLines(weft_yml, file.path(root, "_weft.yml"))
  for (nm in names(files)) {
    v <- files[[nm]]
    if (is.list(v)) do.call(f3_write, c(list(file.path(root, nm)), v))
    else f3_write(file.path(root, nm), v)
  }
  root
}

# lints() over a fresh project holding `files` (named list as for lint_proj()).
# Defaults are the design's (L-helper note in section 5): rules = NULL,
# tier = 1:2, so tier-2 findings are visible. Extra arguments go to lints().
lint_fixture <- function(files, rules = NULL, tier = 1:2, ..., weft_yml = NULL,
                         env = parent.frame()) {
  root <- lint_proj(files, weft_yml = weft_yml, env = env)
  lints(root, rules = rules, tier = tier, ...)
}

# lints() over one document `text` (a vector of lines, or one string with \n),
# written as doc.qmd (ext = "qmd") or doc.Rmd (ext = "Rmd"). `weft_yml` are the
# lines of _weft.yml. Returns the weft_findings; the file column is "doc.<ext>".
lint_one <- function(text, rules = NULL, ext = "qmd", weft_yml = NULL,
                     tier = 1:2, ..., env = parent.frame()) {
  lint_fixture(stats::setNames(list(text), paste0("doc.", ext)),
               rules = rules, tier = tier, ..., weft_yml = weft_yml, env = env)
}

# Run an expression once under .qmd and once under .Rmd: `f(ext)` is called for
# each and its results returned as a named list.
f3_both <- function(f) list(qmd = f("qmd"), Rmd = f("Rmd"))

# ---- accessors on a weft_findings -------------------------------------------------

lf_lines <- function(x) x$line                 # the lines found
lf_cols  <- function(x) x$col                  # the columns found
lf_texts <- function(x) x$text                 # the `text` of each finding
# the rows of one rule (a weft_findings subset as a plain data frame)
lf_by_rule <- function(x, rule) {
  as.data.frame(unclass(x), stringsAsFactors = FALSE)[x$rule %in% rule, , drop = FALSE]
}
# the one row of `rule` (and of `text`, when given); fails the test if not exactly one
lf_one <- function(x, rule, text = NULL) {
  r <- lf_by_rule(x, rule)
  if (!is.null(text)) r <- r[r$text %in% text, , drop = FALSE]
  testthat::expect_equal(nrow(r), 1L,
    label = sprintf("exactly one finding of rule %s%s", rule,
                    if (is.null(text)) "" else paste0(" with text ", text)))
  r[1, , drop = FALSE]
}
# the line of a finding of `rule` as c(line, col)
lf_pos <- function(x, rule, text = NULL) {
  r <- lf_one(x, rule, text)
  c(line = r$line, col = r$col)
}

# L5: the shape of a weft_findings
expect_findings_shape <- function(x) {
  testthat::expect_s3_class(x, "weft_findings")
  testthat::expect_s3_class(x, "data.frame")
  testthat::expect_identical(names(x), F3_COLS)
  for (nm in F3_COLS) {
    testthat::expect_identical(typeof(x[[nm]]), unname(if (F3_TYPES[[nm]] == "integer") "integer" else "character"),
                               label = paste("type of column", nm))
  }
  testthat::expect_type(attr(x, "notes"), "character")
}

# ---- positions ---------------------------------------------------------------------

# the 1-based (line, col) of the first occurrence of `frag` in the vector of
# lines `lines`; cols count characters
f3_pos <- function(lines, frag) {
  for (i in seq_along(lines)) {
    p <- regexpr(frag, lines[[i]], fixed = TRUE)
    if (p > 0L) return(c(line = i, col = as.integer(p)))
  }
  stop("fragment not found: ", frag)
}

# ---- documents ---------------------------------------------------------------------

# front matter lines: f3_fm("title: T", "lang: en")
f3_fm <- function(...) c("---", c(...), "---", "")

# a knitr chunk's lines. `opts` are #| lines (written as given). engine "r".
f3_chunk <- function(code, opts = NULL, header = "{r}") {
  c(paste0("```", header), opts, code, "```")
}

# ---- the source reader (L9), through weft:::read_source() ---------------------------

# Write `text` to a document in a fresh project and read it with
# weft:::read_source(path, root, cfg), the arguments of L9, where cfg comes from
# weft:::lint_config(root, front) (L4). ASSUMPTIONS (design silent): `path` is
# absolute, and `front` is the parsed front matter list (an empty list here).
# Extra arguments go to f3_write() (eol, bom, final_newline).
read_src <- function(text, ext = "qmd", weft_yml = NULL, files = list(), ..., env = parent.frame()) {
  root <- lint_proj(files, weft_yml = weft_yml, env = env)
  path <- file.path(root, paste0("doc.", ext))
  f3_write(path, text, ...)
  cfg <- weft:::lint_config(root, list())
  weft:::read_source(path, root, cfg)
}

# the merged front matter of a source (L9: `front`; accepted also under `meta`)
src_front <- function(src) if (!is.null(src$front)) src$front else src$meta$front

# the prose string of a source split into lines (line breaks stay, L9)
src_prose_lines <- function(src) strsplit(src$prose, "\n", fixed = TRUE)[[1]]

# the text and prose of the first occurrence of `frag` in src$text
src_frag <- function(src, frag, from = 1L) {
  p <- regexpr(frag, substr(src$text, from, nchar(src$text)), fixed = TRUE)
  if (p < 0L) stop("fragment not in source text: ", frag)
  s <- as.integer(p) + from - 1L
  e <- s + nchar(frag) - 1L
  list(start = s, end = e, text = substr(src$text, s, e), prose = substr(src$prose, s, e))
}

# TRUE when every character of the fragment is blank in prose (line breaks stay)
src_is_blank <- function(src, frag, from = 1L) {
  !grepl("[^ \n]", src_frag(src, frag, from)$prose)
}

# TRUE when the fragment is prose as typed
src_is_kept <- function(src, frag, from = 1L) {
  identical(src_frag(src, frag, from)$prose, frag)
}

# rows of src$regions of a type
src_regions <- function(src, type) {
  r <- src$regions
  r[r$type == type, , drop = FALSE]
}

# Assert about the prose of `lines` under each extension in `ext`: every fragment in
# `blank` is entirely blanked (spaces; line breaks stay), every fragment in `kept` is
# prose exactly as typed (first occurrence of each; use unique tokens). Also checks
# L9's invariants: prose is as long as text and has its line breaks in the same places.
expect_prose <- function(lines, blank = character(), kept = character(),
                         ext = c("qmd", "Rmd"), files = list()) {
  for (e in ext) {
    src <- read_src(lines, ext = e, files = files)
    testthat::expect_identical(nchar(src$prose), nchar(src$text), label = paste(e, "prose length"))
    testthat::expect_identical(gsub("[^\n]", "", src$prose), gsub("[^\n]", "", src$text),
                               label = paste(e, "line breaks"))
    for (b in blank) {
      testthat::expect_true(src_is_blank(src, b), label = sprintf("[%s] blank: %s", e, b))
    }
    for (k in kept) {
      testthat::expect_true(src_is_kept(src, k), label = sprintf("[%s] kept: %s", e, k))
    }
  }
}

# Assert whole prose lines (trailing blanks ignored): `want` is a named character
# vector whose names are line numbers, e.g. c("3" = "   Heading").
expect_prose_lines <- function(lines, want, ext = c("qmd", "Rmd")) {
  for (e in ext) {
    src <- read_src(lines, ext = e)
    pl <- sub("[ ]+$", "", src_prose_lines(src))
    for (i in names(want)) {
      testthat::expect_identical(pl[[as.integer(i)]], sub("[ ]+$", "", want[[i]]),
                                 label = sprintf("[%s] prose of line %s (%s)", e, i, lines[[as.integer(i)]]))
    }
  }
}
