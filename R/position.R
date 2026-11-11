# Positions (rules 2.7.1-2.7.5): the file knitr is reading, the content
# search that finds a block's first line, and the map back through Quarto's
# includes. Only exported knitr functions are used.

# The path of the file knitr is reading, or NULL (`knit(text = )`).
knit_input_path <- function() {
  p <- tryCatch(suppressWarnings(knitr::current_input(dir = TRUE)),
                error = function(e) NULL)
  if (is.null(p) || length(p) != 1L || is.na(p) || !nzchar(p)) return(NULL)
  if (!file.exists(p)) return(NULL)
  normalizePath(p, winslash = "/")
}

# The lines of a file as knitr reads them: UTF-8, no byte-order mark, no
# carriage returns.
read_view_lines <- function(path) {
  bytes <- readBin(path, "raw", file.info(path)$size)
  if (length(bytes) >= 3L && identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) {
    bytes <- bytes[-(1:3)]
  }
  text <- rawToChar(bytes)
  Encoding(text) <- "UTF-8"
  text <- gsub("\r\n", "\n", text, fixed = TRUE)
  text <- gsub("\r", "\n", text, fixed = TRUE)
  if (!nzchar(text)) return(character())
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  lines
}

# Under Quarto knitr reads `<name>.rmarkdown`, a copy of `<name>.qmd` with
# every `{{< include >}}` expanded. Re-expand the source to map a line of the
# copy back to the file and line that wrote it (2.7.4).
expand_includes <- function(path, base, seen = character(), nested = FALSE) {
  lines <- read_view_lines(path)
  rel <- function(p) {
    p <- normalizePath(p, winslash = "/", mustWork = FALSE)
    b <- normalizePath(base, winslash = "/", mustWork = FALSE)
    if (startsWith(p, paste0(b, "/"))) substring(p, nchar(b) + 2L) else basename(p)
  }
  me <- rel(path)
  # the path may be quoted; Quarto resolves it against the main document's
  # directory (`base`), and weft falls back to the including file's
  rx <- paste0("^\\s*\\{\\{<\\s*include\\s+(?:\"([^\"]+)\"|'([^']+)'|([^ >\"']+))\\s*>\\}\\}\\s*$")
  resolve_inc <- function(p) {
    cand <- c(file.path(base, p), file.path(dirname(path), p))
    hit <- cand[file.exists(cand)]
    if (length(hit)) hit[1L] else NA_character_
  }
  files <- character()
  nums <- integer()
  for (k in seq_along(lines)) {
    m <- regmatches(lines[k], regexec(rx, lines[k], perl = TRUE))[[1]]
    inc <- if (length(m) == 4L) resolve_inc(m[m != ""][-1L][1L]) else NA_character_
    if (!is.na(inc) && file.exists(inc) &&
        !(normalizePath(inc, winslash = "/") %in% seen)) {
      sub <- expand_includes(inc, base, c(seen, normalizePath(path, winslash = "/")),
                             nested = TRUE)
      # Quarto splices the file's lines, then a blank line (which is the include
      # line); an include inside an included file leaves two
      pad <- if (nested) 2L else 1L
      files <- c(files, sub$file, rep(me, pad))
      nums <- c(nums, sub$line, rep(k, pad))
    } else {
      files <- c(files, me)
      nums <- c(nums, k)
    }
  }
  list(file = files, line = nums)
}

# ---- normal forms for the content search ----------------------------------------

PH_TOKEN <- "\ue000"

# A line, as the search compares it: trailing blanks off.
rtrim_lines <- function(x) sub("[ \t\r]+$", "", x)

# The file's text with each inline-code span replaced by one token, as knitr
# replaces it by a placeholder, and for each resulting line the line of the
# file it began on.
normalise_file <- function(lines) {
  if (!length(lines)) return(list(norm = character(), orig = integer(), raw = character()))
  text <- paste(lines, collapse = "\n")
  m <- gregexpr(knitr::all_patterns$md$inline.code, text, perl = TRUE)[[1]]
  nlpos <- as.integer(gregexpr("\n", text, fixed = TRUE)[[1]])
  nlpos <- nlpos[nlpos > 0L]
  kept <- rep(TRUE, length(nlpos))
  if (m[1] > 0L) {
    len <- attr(m, "match.length")
    for (k in seq_along(m)) {
      kept[nlpos > m[k] & nlpos < m[k] + len[k]] <- FALSE
    }
    regmatches(text, list(m)) <- list(rep(PH_TOKEN, length(m)))
  }
  norm <- strsplit(text, "\n", fixed = TRUE)[[1]]
  orig <- c(1L, which(kept) + 1L)
  orig <- orig[seq_along(norm)]
  list(norm = rtrim_lines(norm), orig = orig, raw = norm)
}

# The lines of a block as knitr hands it to the `text` hook, in the same form.
block_lines <- function(x) {
  x <- gsub("\ue000[0-9]+\ue002", PH_TOKEN, x)
  if (!nzchar(x)) return(character())
  rtrim_lines(strsplit(x, "\n", fixed = TRUE)[[1]])
}

# ---- per-file state ----------------------------------------------------------

new_file_state <- function(path, config) {
  F <- new.env(parent = emptyenv())
  F$path <- path
  quarto <- grepl("\\.rmarkdown$", path)
  src <- sub("\\.rmarkdown$", ".qmd", path)
  F$lines <- read_view_lines(path)
  nf <- normalise_file(F$lines)
  F$norm <- nf$norm
  F$orig <- nf$orig
  F$cursor <- 1L
  F$park_ptr <- 1L
  F$inline_code <- NULL
  F$map <- NULL
  if (quarto && file.exists(src)) {
    F$name <- basename(src)
    F$map <- tryCatch(expand_includes(src, dirname(src)), error = function(e) NULL)
  } else {
    F$name <- basename(path)
  }
  F$recorded <- character()
  # what the scanner finds in the whole file, for the end-of-document check
  F$expected <- NULL
  txt <- paste(F$lines, collapse = "\n")
  exp <- tryCatch(scan_text(blank_front_matter(txt), config = config),
                  error = function(e) NULL)
  F$unparseable <- character()
  F$unparse_rows <- NULL
  if (!is.null(exp) && nrow(exp)) {
    # inline code that does not parse: knitr stops on it before any hook runs
    bad <- which(exp$kind %in% c("bare", "value") &
                   grepl("does not parse", exp$error, fixed = TRUE))
    if (length(bad)) {
      blank <- blank_front_matter(txt)
      cend <- ifelse(exp$kind[bad] == "bare", exp$end[bad], exp$block_start[bad] - 1L)
      F$unparseable <- unique(substring(blank, exp$start[bad], cend))
      F$unparse_rows <- data.frame(line = exp$line[bad], error = exp$error[bad],
                                   stringsAsFactors = FALSE)
    }
    ic <- exp$kind %in% c("bare", "value")
    F$inline_code <- unwrap_quarto(trim_ws(exp$expr[ic]))
    F$inline_kind <- exp$kind[ic]
    F$inline_parent <- exp$parent[ic]
    F$inline_line <- exp$line[ic]
    F$inline_error <- exp$error[ic]
    exp <- exp[!(exp$kind %in% c("bare", "link")) & is.na(exp$parent), , drop = FALSE]
    F$expected <- data.frame(kind = exp$kind, line = exp$line,
                             context = rep("prose", nrow(exp)), stringsAsFactors = FALSE)
  }
  # the front-matter fields, the caption options and the weft_str() strings
  # (2.10.2): their constructs are expected too; the ones the scanner finds
  # an error in are the knit's to report when it starts
  F$captions <- NULL
  F$static <- NULL
  ch <- tryCatch(labelled_chunks(F$lines), error = function(e) list())
  F$chunk_lines <- stats::setNames(vapply(ch, function(x) as.integer(x$open), 0L),
                                   vapply(ch, function(x) x$label, ""))
  extra <- tryCatch(scan_extra_rows(F$lines, file = NA_character_, config = config,
                                    project = project_type(path)),
                    error = function(e) NULL)
  if (!is.null(extra) && nrow(extra)) {
    top <- is.na(extra$parent) & !(extra$kind %in% c("bare", "link"))
    ok <- top & is.na(extra$error) & extra$context != "weft_str"
    prev <- F$expected %||% data.frame(kind = character(), line = integer(),
                                       context = character(), stringsAsFactors = FALSE)
    F$expected <- rbind(prev, data.frame(kind = extra$kind[ok], line = extra$line[ok],
                                         context = extra$context[ok],
                                         stringsAsFactors = FALSE))
    cap <- ok & extra$context == "caption"
    F$captions <- data.frame(kind = extra$kind[cap], line = extra$line[cap],
                             chunk = extra$chunk[cap], option = extra$option[cap],
                             stringsAsFactors = FALSE)
    bad <- !is.na(extra$error) & extra$context %in% c("front-matter", "caption") & top
    F$static <- data.frame(kind = extra$kind[bad], line = extra$line[bad],
                           error = extra$error[bad], context = extra$context[bad],
                           chunk = extra$chunk[bad], option = extra$option[bad],
                           stringsAsFactors = FALSE)
  }
  F
}

# The file and line, as the author wrote them, of lines of the copy knitr read.
map_lines <- function(F, view_lines) {
  if (is.null(F)) {
    return(data.frame(file = rep("<text>", length(view_lines)),
                      line = as.integer(view_lines), stringsAsFactors = FALSE))
  }
  if (is.null(F$map)) {
    return(data.frame(file = rep(F$name, length(view_lines)),
                      line = as.integer(view_lines), stringsAsFactors = FALSE))
  }
  ok <- view_lines >= 1L & view_lines <= length(F$map$line)
  data.frame(
    file = ifelse(ok, F$map$file[pmin(pmax(view_lines, 1L), length(F$map$file))], F$name),
    line = as.integer(ifelse(ok, F$map$line[pmin(pmax(view_lines, 1L), length(F$map$line))], view_lines)),
    stringsAsFactors = FALSE)
}

# ---- the content search (2.7.2, 2.7.3) ------------------------------------------

is_chunk_begin <- function(x) grepl(knitr::all_patterns$md$chunk.begin, x, perl = TRUE)
is_chunk_end <- function(x) grepl(knitr::all_patterns$md$chunk.end, x, perl = TRUE)

# The first line (in the copy knitr read) of the block `B` (its normalised
# lines), searching forward from the end of the previous block and requiring a
# chunk boundary on each side. Returns list(line, found).
find_block <- function(F, B) {
  n <- length(B)
  N <- length(F$norm)
  cursor <- F$cursor
  if (n == 0L || N == 0L) {
    return(list(line = F$orig[min(cursor, max(N, 1L))] %||% 1L, found = FALSE, j = NA_integer_))
  }
  cand <- which(F$norm == B[1L])
  cand <- cand[cand >= cursor]
  loose <- NA_integer_
  for (j in cand) {
    last <- j + n - 1L
    if (last > N) next
    if (n > 1L && !all(F$norm[j + seq_len(n - 1L)] == B[-1L])) next
    before_ok <- j == 1L || is_chunk_end(F$norm[j - 1L])
    after_ok <- last == N || is_chunk_begin(F$norm[last + 1L]) ||
      (!nzchar(F$norm[last + 1L]) && last + 1L < N && is_chunk_begin(F$norm[last + 2L]))
    if (before_ok && after_ok) return(list(line = F$orig[j], found = TRUE, j = j))
    if (is.na(loose)) loose <- j
  }
  if (!is.na(loose)) return(list(line = F$orig[loose], found = TRUE, j = loose))
  list(line = F$orig[min(cursor, N)], found = FALSE, j = NA_integer_)
}

# Where a block of the current file starts. Moves the cursor past the block.
locate_block <- function(s, x) {
  F <- current_file_state(s)
  if (is.null(F)) return(list(F = NULL, start = 1L, found = FALSE))
  B <- block_lines(x)
  r <- find_block(F, B)
  if (r$found) F$cursor <- r$j + length(B)
  list(F = F, start = r$line, found = r$found)
}

# A file knitted a second time (a child in a loop) is searched from its top.
reset_file_state <- function(F) {
  F$cursor <- 1L
  F$park_ptr <- 1L
  invisible()
}

# The state of the file knitr is reading now (a child has its own). Text
# knitted by a child has none.
current_file_state <- function(s) {
  if (length(s$stack) && isTRUE(s$stack[[length(s$stack)]]$text)) return(NULL)
  p <- knit_input_path()
  if (is.null(p)) return(NULL)
  F <- s$files[[p]]
  if (is.null(F)) {
    F <- tryCatch(new_file_state(p, s$config), error = function(e) NULL)
    if (is.null(F)) return(NULL)
    s$files[[p]] <- F
  }
  F
}

# knitr parses inline code before it calls any hook, and stops on code that
# does not parse, with no position. Such code is a construct error of weft's
# (5.3.5), reported by the resolver with file and line; so knitr is told not
# to treat it as inline code, and the text reaches the `text` hook as written.
protect_inline_patterns <- function(F) {
  if (is.null(F) || !length(F$unparseable)) return(invisible())
  old <- knitr::knit_patterns$get("inline.code")
  if (is.null(old) || startsWith(old, "(?#weft)")) return(invisible())
  lit <- gsub("([\\\\.|()\\[\\]{}^$*+?#-])", "\\\\\\1", F$unparseable, perl = TRUE)
  knitr::knit_patterns$set(inline.code = paste0("(?#weft)(?!", paste(lit, collapse = "|"), ")", old))
  invisible()
}
