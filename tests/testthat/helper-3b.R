# Helpers for the 3b tests (the prose lints). Contract: dev/design-3.md.
# Built on helper-3.R. ASCII only: write non-ASCII as \uXXXX in ordinary strings.

# ---- numerals -------------------------------------------------------------------------

# the (line, col) of each fragment in `want`, found one after the other (each search
# starts after the end of the previous hit) in the lines joined by "\n". Returns a
# list(line =, col =) of integer vectors. A fragment that is not found stops the test.
n3_positions <- function(lines, want) {
  flat <- paste(lines, collapse = "\n")
  from <- 1L
  ln <- integer(); cl <- integer()
  for (w in want) {
    p <- regexpr(w, substr(flat, from, nchar(flat)), fixed = TRUE)
    if (p < 0L) stop("fragment not found after offset ", from, ": ", w)
    abs <- from + as.integer(p) - 1L
    before <- substr(flat, 1L, abs - 1L)
    nl <- gregexpr("\n", before, fixed = TRUE)[[1]]
    nl <- if (nl[[1]] < 0L) integer() else as.integer(nl)
    ln <- c(ln, length(nl) + 1L)
    cl <- c(cl, abs - (if (length(nl)) max(nl) else 0L))
    from <- abs + nchar(w)
  }
  list(line = ln, col = cl)
}

# Lint `lines` for `rules` under each extension and assert that the `text` of the
# findings is `want`, in order. With pos = TRUE the line and column of each finding
# are those of its text found in the source in sequence (n3_positions()). `ctx`, when
# given, is the `context` every finding must have.
expect_numerals <- function(lines, want, ext = c("qmd", "Rmd"), weft_yml = NULL,
                            ctx = NULL, pos = TRUE, rules = "numeral",
                            env = parent.frame()) {
  lab <- paste(lines, collapse = " / ")
  for (e in ext) {
    x <- lint_one(lines, rules = rules, ext = e, weft_yml = weft_yml, env = env)
    info <- sprintf("[%s] %s", e, lab)
    testthat::expect_identical(x$text, want, info = info)
    if (length(want) && identical(x$text, want)) {
      if (pos) {
        p <- n3_positions(lines, want)
        testthat::expect_identical(x$line, p$line, info = paste("line:", info))
        testthat::expect_identical(x$col, p$col, info = paste("col:", info))
      }
      if (!is.null(ctx)) {
        testthat::expect_true(all(x$context == ctx), info = paste("context:", info))
      }
    }
  }
  invisible(NULL)
}

# a long filler paragraph of `n` lines with no digit in it
n3_filler <- function(n) rep("Plain filler text here.", n)

# ---- Pandoc ----------------------------------------------------------------------------

# A Pandoc 3 for the tests, found without weft: option, environment, Quarto's own,
# the path. "" when none.
n3_find_pandoc <- function() {
  cands <- c(getOption("weft.pandoc"), Sys.getenv("WEFT_PANDOC"),
             "/Applications/quarto/bin/tools/aarch64/pandoc",
             "/Applications/quarto/bin/tools/pandoc",
             unname(Sys.which("pandoc")))
  for (p in cands) {
    if (is.null(p) || is.na(p) || !nzchar(p) || !file.exists(p)) next
    v <- tryCatch(system2(p, "--version", stdout = TRUE, stderr = FALSE),
                  error = function(e) character())
    m <- regmatches(v[[1]], regexpr("[0-9]+\\.[0-9]+", v[[1]]))
    if (length(m) && as.numeric(m) >= 3) return(p)
  }
  ""
}

# skip the test unless a Pandoc 3 is reachable and weft's own pandoc_path() sees one
n3_skip_no_pandoc <- function() {
  testthat::skip_if(!nzchar(n3_find_pandoc()), "no Pandoc 3 found")
  has_fn <- exists("pandoc_path", envir = asNamespace("weft"), inherits = FALSE)
  if (has_fn) testthat::skip_if(!nzchar(weft:::pandoc_path()), "pandoc_path() finds no Pandoc")
}

# Make a stub `pandoc` in a fresh folder that logs its calls and runs the real one.
# Returns list(path =, dir =). The log folder holds: `calls` (one line of arguments per
# non-version call), `versions` (one line per --version call), `in-<n>` (a copy of the
# input of call n, whether given as a file argument or on standard input).
# `version_line` replaces the real --version output when given.
n3_stub_pandoc <- function(real = n3_find_pandoc(), version_line = NULL, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  path <- file.path(dir, "pandoc")
  ver <- if (is.null(version_line)) {
    "exec \"$real\" \"$@\""
  } else {
    sprintf("echo '%s'; exit 0", version_line)
  }
  writeLines(c(
    "#!/bin/sh",
    sprintf("dir='%s'", dir),
    sprintf("real='%s'", real),
    "case \"$1\" in --version|-v)",
    "  echo v >> \"$dir/versions\"",
    paste0("  ", ver),
    "  ;;",
    "esac",
    "n=$(ls \"$dir\"/in-* 2>/dev/null | wc -l | tr -d ' ')",
    "n=$((n+1))",
    "echo \"$*\" >> \"$dir/calls\"",
    "found=0",
    "for a in \"$@\"; do if [ -f \"$a\" ]; then cp \"$a\" \"$dir/in-$n\"; found=1; fi; done",
    "if [ $found = 0 ]; then cat > \"$dir/in-$n\"; exec \"$real\" \"$@\" < \"$dir/in-$n\"; fi",
    "exec \"$real\" \"$@\""
  ), path)
  Sys.chmod(path, "755")
  list(path = path, dir = dir)
}

# the number of non-version calls a stub logged, and its captured inputs (character
# vector, each the whole file)
n3_stub_calls <- function(stub) {
  f <- file.path(stub$dir, "calls")
  if (file.exists(f)) length(readLines(f)) else 0L
}
n3_stub_versions <- function(stub) {
  f <- file.path(stub$dir, "versions")
  if (file.exists(f)) length(readLines(f)) else 0L
}
n3_stub_inputs <- function(stub) {
  fs <- list.files(stub$dir, pattern = "^in-[0-9]+$", full.names = TRUE)
  fs <- fs[order(as.integer(sub("^in-", "", basename(fs))))]
  vapply(fs, function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
         character(1), USE.NAMES = FALSE)
}

# Pandoc's `data-pos` ranges of the Str nodes of `text` (a file in commonmark_x+sourcepos),
# as a data frame of file offsets: start, end (inclusive, in characters). Uses jsonlite.
n3_str_ranges <- function(text, pandoc = n3_find_pandoc()) {
  f <- withr::local_tempfile(fileext = ".md")
  writeBin(charToRaw(enc2utf8(text)), f)
  json <- system2(pandoc, c("-f", "commonmark_x+sourcepos", "-t", "json", shQuote(f)),
                  stdout = TRUE)
  tree <- jsonlite::fromJSON(paste(json, collapse = "\n"), simplifyVector = FALSE)
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  line_start <- cumsum(c(1L, nchar(lines) + 1L))
  out <- list()
  walk <- function(x) {
    if (!is.list(x)) return(invisible())
    if (!is.null(x$t) && identical(x$t, "Span")) {
      inner <- x$c[[2]]
      if (length(inner) == 1L && identical(inner[[1]]$t, "Str")) {
        pos <- NULL
        for (kv in x$c[[1]][[3]]) if (identical(kv[[1]], "data-pos")) pos <- kv[[2]]
        if (!is.null(pos)) {
          m <- regmatches(pos, regexec("@([0-9]+):([0-9]+)-([0-9]+):([0-9]+)$", pos))[[1]]
          v <- as.integer(m[-1])
          s <- line_start[[v[[1]]]] + v[[2]] - 1L
          e <- line_start[[v[[3]]]] + v[[4]] - 2L
          out[[length(out) + 1L]] <<- c(s, e)
        }
      }
    }
    for (el in x) walk(el)
  }
  walk(tree$blocks)
  m <- do.call(rbind, out)
  data.frame(start = m[, 1], end = m[, 2])
}

# ---- label_seed() ----------------------------------------------------------------------

# a fresh project folder holding `files`, made the working folder (label_seed() and
# dict_seed() read the project at the working folder); returns the folder
ls_proj <- function(files, weft_yml = NULL, env = parent.frame()) {
  root <- lint_proj(files, weft_yml = weft_yml, env = env)
  withr::local_dir(root, .local_envir = env)
  root
}

# every file under `dir` with its modification time and size, to show nothing changed
n3_tree <- function(dir) {
  fs <- list.files(dir, recursive = TRUE, all.files = TRUE, full.names = TRUE, include.dirs = TRUE)
  info <- file.info(fs)
  data.frame(path = substring(fs, nchar(dir) + 2L), size = info$size,
             mtime = as.numeric(info$mtime), stringsAsFactors = FALSE)
}

# The block types of Pandoc's tree for `text` (commonmark_x+sourcepos), in document
# order, as a character vector: Para, Header, CodeBlock, RawBlock, BlockQuote, BulletList,
# OrderedList, ... (the wrapper Divs that +sourcepos adds are skipped).
n3_block_types <- function(text, pandoc = n3_find_pandoc()) {
  f <- withr::local_tempfile(fileext = ".md")
  writeBin(charToRaw(enc2utf8(text)), f)
  json <- system2(pandoc, c("-f", "commonmark_x+sourcepos", "-t", "json", shQuote(f)),
                  stdout = TRUE)
  tree <- jsonlite::fromJSON(paste(json, collapse = "\n"), simplifyVector = FALSE)
  block_t <- c("Para", "Plain", "Header", "CodeBlock", "RawBlock", "BlockQuote", "BulletList",
               "OrderedList", "DefinitionList", "HorizontalRule", "Table", "LineBlock")
  out <- character()
  walk <- function(x) {
    if (!is.list(x)) return(invisible())
    if (!is.null(x$t) && is.character(x$t) && x$t %in% block_t) out <<- c(out, x$t)
    for (el in x) walk(el)
  }
  walk(tree$blocks)
  out
}
