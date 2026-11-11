## Block-start locator spike. Source from a setup chunk:  source("lines.R"); lines_install()
## Exported knitr API only for the methods under test; knit_concord is read (via :::) ONLY for the comparison log.
##
## evaluate.inline parks each inline expression and returns a placeholder; the text hook
## (a) restores the block's source text, (b) locates it in the input file by
##   "cs": forward fixed-string search over the file as one string, from the end offset of the previous block
##   "cl": forward match over the file as a vector of lines (first-line candidates, then verify)
## and logs both next to the knit_concord answer when LINES_LOG is set.

L <- new.env()
L$O <- ""; L$C <- ""; L$pend <- character(); L$state <- list(); L$files <- list(); L$n <- 0L
L$methods <- c("cs", "cl"); L$strict <- TRUE   # require chunk-boundary agreement around a match

lines_reset <- function() { L$tag <- Sys.getenv("LINES_TAG", ""); L$pend <- character(); L$state <- list(); L$files <- list(); L$n <- 0L }

lines_install <- function(log = Sys.getenv("LINES_LOG", ""), strict = Sys.getenv("LINES_STRICT", "1") == "1",
                          methods = strsplit(Sys.getenv("LINES_METHODS", "cs,cl,rx,kc"), ",")[[1]]) {
  lines_reset(); L$log <- log; L$strict <- strict; L$methods <- methods; L$tcs <- 0; L$tcl <- 0
  knitr::knit_hooks$set(
    evaluate.inline = function(code, envir) {
      L$pend[[length(L$pend) + 1L]] <- code
      paste0(L$O, length(L$pend), L$C)
    },
    text = function(x) lines_text(x))
  invisible(TRUE)
}

## file knitr is reading, resolved to a full path (exported API only)
lines_path <- function() {
  p <- tryCatch(suppressWarnings(knitr::current_input(dir = TRUE)), error = function(e) NULL)
  if (is.null(p) || !length(p) || !file.exists(p)) {
    f <- tryCatch(knitr::current_input(), error = function(e) NULL)
    if (!is.null(f) && file.exists(f)) p <- normalizePath(f, winslash = "/") else return(NULL)
  }
  normalizePath(p, winslash = "/")
}

## file contents as knitr sees them: readLines-style (CRLF/CR stripped), UTF-8, BOM dropped
lines_file <- function(path) {
  e <- L$files[[path]]
  if (!is.null(e)) return(e)
  raw <- readBin(path, "raw", file.size(path))
  txt <- rawToChar(raw); Encoding(txt) <- "UTF-8"
  txt <- sub("^﻿", "", txt)
  ln <- xfun_lines(txt)
  nch <- nchar(ln, "bytes")
  starts <- c(0, cumsum(nch + 1))[seq_along(ln)]      # byte offset (0-based) of each line start
  one <- paste(ln, collapse = "\n")
  e <- L$files[[path]] <- list(lines = ln, starts = starts, nl = nch, str = one, n = length(ln),
            raw = charToRaw(paste0("\n", one, "\n")))
  e
}
xfun_lines <- function(txt) {                          # mirror readLines: \n, \r\n and lone \r end a line
  txt <- gsub("\r\n?", "\n", txt)
  if (!nzchar(txt)) return(character())
  ln <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  if (endsWith(txt, "\n") ) ln else ln                 # strsplit drops the trailing empty piece already
}

lines_restore <- function(x) {                         # placeholders -> original inline source
  m <- gregexpr(paste0(L$O, "[0-9]+", L$C), x)
  regmatches(x, m) <- lapply(regmatches(x, m), function(p)
    vapply(p, function(q) paste0("`r ", L$pend[[as.integer(gsub(paste0("[", L$O, L$C, "]"), "", q))]], "`"), ""))
  x
}

## --- method cs: fixed-string search over one string -----------------------------------------
## hay = "\n" + file + "\n" (line i starts at 1-based byte starts[i] + 2, preceded by "\n");
## needle = "\n" + block + "\n". A hit at r means the block starts at line which(starts == r - 1).
cs_find <- function(e, blk, from_line, strict, pat_b, pat_e) {
  needle <- paste0("\n", blk, "\n")
  nb <- length(strsplit(paste0(blk, "\n."), "\n", fixed = TRUE)[[1]]) - 1L
  base <- if (from_line > e$n) return(NA_integer_) else e$starts[from_line]   # 1-based pos in hay of the "\n" before the line
  base <- base + 1L
  repeat {
    r <- regexpr(needle, rawToChar(e$raw[base:length(e$raw)]), fixed = TRUE, useBytes = TRUE)
    if (r < 0) return(NA_integer_)
    pos <- base + r - 1L                                # 1-based position of the leading "\n" in hay
    ln <- which(e$starts == pos - 1L)
    if (length(ln) == 1L && (!strict || bounds_ok(e, ln, nb, pat_b, pat_e))) return(ln)
    base <- pos + 1L                                    # retry past this hit
    if (base > length(e$raw)) return(NA_integer_)
  }
}

bounds_ok <- function(e, ln, nb, pat_b, pat_e) {
  before_ok <- ln == 1L || is.null(pat_e) || grepl(pat_e, e$lines[ln - 1L], perl = TRUE)
  last <- ln + nb - 1L
  after_ok <- last >= e$n || is.null(pat_b) || grepl(pat_b, e$lines[last + 1L], perl = TRUE)
  before_ok && after_ok
}

## --- fallback rx: regex search; each parked inline becomes "`r[ #][^`]+`" (tolerates `r#`, trailing blanks) ----
rx_find <- function(e, xph, from_line, strict, pat_b, pat_e) {
  if (from_line > e$n) return(NA_integer_)
  parts <- regmatches(xph, gregexpr(paste0(L$O, "[0-9]+", L$C), xph), invert = TRUE)[[1]]
  q <- vapply(parts, function(p) if (nzchar(p)) paste0("\\Q", gsub("\\E", "\\E\\\\E\\Q", p, fixed = TRUE), "\\E") else "", "")
  pat <- paste0("\n", paste(q, collapse = "`r[ #][^`]+`"), "\n")
  base <- e$starts[from_line] + 1L
  repeat {
    sub <- rawToChar(e$raw[base:length(e$raw)])
    r <- regexpr(pat, sub, perl = TRUE, useBytes = TRUE)
    if (r < 0) return(NA_integer_)
    pos <- base + r - 1L
    ln <- which(e$starts == pos - 1L)
    mlen <- attr(r, "match.length")
    nb <- sum(e$raw[pos:(pos + mlen - 1L)] == as.raw(10L)) - 1L          # newlines in match minus the two delimiters + 1
    if (length(ln) == 1L && (!strict || bounds_ok(e, ln, nb, pat_b, pat_e))) return(list(ln = ln, nb = nb))
    base <- pos + 1L
    if (base > length(e$raw)) return(NA_integer_)
  }
}

## --- method cl: line-vector forward search -----------------------------------------------------
cl_find <- function(e, blk, from_line, strict, pat_b, pat_e) {
  bl <- strsplit(paste0(blk, "\n."), "\n", fixed = TRUE)[[1]]; bl <- bl[-length(bl)]   # keep trailing empties
  nb <- length(bl)
  if (!nb) bl <- ""; nb <- length(bl)
  cand <- which(e$lines == bl[1])
  cand <- cand[cand >= from_line]
  for (c0 in cand) {
    if (c0 + nb - 1L > e$n) next
    if (nb > 1L && !identical(e$lines[c0 + seq_len(nb - 1L)], bl[-1])) next
    if (!strict || bounds_ok(e, c0, nb, pat_b, pat_e)) return(c0)
  }
  NA_integer_
}

## method fr (NOT exported API): the base-R call stack holds knitr's own process_file frame, whose local `text`
## is the input lines. sys.calls()/sys.frame() are ordinary R, but the variable name is a knitr internal.
fr_env <- function() {
  fn <- vapply(sys.calls(), function(cl) paste(deparse(cl[[1]])[1], collapse = ""), "")
  k <- which(fn %in% c("process_file", "knitr:::process_file"))
  if (!length(k)) return(NULL)
  sys.frame(max(k))
}

lines_text <- function(x) {
  blk <- lines_restore(enc2utf8(paste(x, collapse = "\n")))
  L$n <- L$n + 1L
  path <- lines_path()
  res <- list(rx = NA_integer_, lb = NA_integer_, cs = NA_integer_, cl = NA_integer_, kc = NA_integer_, path = path %||% NA_character_)
  if (!is.null(path)) {
    e <- lines_file(path)
    st <- L$state[[path]] %||% 1L
    pb <- tryCatch(knitr::knit_patterns$get("chunk.begin"), error = function(e) NULL)
    pe <- tryCatch(knitr::knit_patterns$get("chunk.end"), error = function(e) NULL)
    t1 <- proc.time()[[3]]
    if ("cs" %in% L$methods) res$cs <- cs_find(e, blk, st, L$strict, pb, pe)
    t2 <- proc.time()[[3]]
    if ("cl" %in% L$methods) res$cl <- cl_find(e, blk, st, L$strict, pb, pe)
    t3 <- proc.time()[[3]]
    L$tcs <- (L$tcs %||% 0) + (t2 - t1); L$tcl <- (L$tcl %||% 0) + (t3 - t2)
    nbk <- length(strsplit(paste0(blk, "\n."), "\n", fixed = TRUE)[[1]]) - 1L
    nxt <- if (!is.na(res$cl)) res$cl else res$cs
    res$lb <- st                                           # lower bound: the previous block's end + 1
    if (!is.na(nxt)) L$state[[path]] <- nxt + nbk          # next search starts after this block
    else if ("rx" %in% L$methods && grepl(L$O, paste(x, collapse = "\n"), fixed = TRUE)) {
      r <- rx_find(e, enc2utf8(paste(x, collapse = "\n")), st, L$strict, pb, pe)
      if (is.list(r)) { res$rx <- r$ln; L$state[[path]] <- r$ln + r$nb }
    }
  }
  kc <- if (!"kc" %in% L$methods) NA_integer_ else tryCatch({ k <- get("knit_concord", asNamespace("knitr")); i <- k$get("inlines"); b <- k$get("block")
                   if (length(i) && length(b)) 1L + sum(utils::head(i, b - 1L)) else NA_integer_ }, error = function(e) NA_integer_)
  res$kc <- kc
  res$fr <- NA_integer_
  if ("fr" %in% L$methods) {
    fe <- fr_env()
    if (!is.null(fe) && exists("text", fe, inherits = FALSE)) {
      ln <- get("text", fe); key <- paste0("fr:", format(fe)); st2 <- L$state[[key]] %||% 1L
      e2 <- list(lines = ln, n = length(ln))
      pb2 <- tryCatch(knitr::knit_patterns$get("chunk.begin"), error = function(e) NULL)
      pe2 <- tryCatch(knitr::knit_patterns$get("chunk.end"), error = function(e) NULL)
      res$fr <- cl_find(e2, blk, st2, L$strict, pb2, pe2)
      nb2 <- length(strsplit(paste0(blk, "\n."), "\n", fixed = TRUE)[[1]]) - 1L
      if (!is.na(res$fr)) L$state[[key]] <- res$fr + nb2
    }
  }
  res$pb <- if (!"pb" %in% L$methods) NA_integer_ else pb_start()
  if (nzchar(L$log %||% "")) {
    if (!is.na(res$path)) { d <- file.path(dirname(L$log), "inputs"); dir.create(d, showWarnings = FALSE)
      f <- file.path(d, paste0(L$tag, "__", basename(res$path))); if (!file.exists(f)) file.copy(res$path, f) }
    first <- gsub("[\t\n\r]", " ", substr(blk, 1, 40))
    cat(sprintf("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\n", L$tag, basename(res$path %||% "NA"), L$n,
                res$kc, res$cs, res$cl, res$pb, res$rx, res$lb, res$fr, if (knitr::opts_knit$get("child") %||% FALSE) "child" else "top", nchar(blk), first),
        file = L$log, append = TRUE)
  }
  gsub(paste0("[", L$O, L$C, "]"), "", blk)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

## method pb: public options only. options(knitr.progress.linenums = TRUE, knitr.progress.simple = TRUE,
## knitr.progress.output = <file>) must be set BEFORE knit starts (the progress bar is built at the top of
## process_file) and knit must not be quiet. knitr's default txt_pb then writes "i/total [label @ file:a-b]"
## to that file at the start of every block; cat(file = <path>) truncates, so the file holds the current block.
pb_start <- function() {
  f <- getOption("knitr.progress.output", "")
  if (!is.character(f) || !nzchar(f) || !file.exists(f)) return(NA_integer_)
  x <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
  x <- x[nzchar(x)]; if (!length(x)) return(NA_integer_)
  m <- regmatches(x[length(x)], regexec(":([0-9]+)-([0-9]+)\\]?\\s*$", x[length(x)]))[[1]]
  if (length(m) == 3L) as.integer(m[2]) else NA_integer_
}
