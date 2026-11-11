## Independent truth (my own chunk scanner) + log comparison. No knitr internals.
PAT <- knitr::all_patterns$md
truth_blocks <- function(lines) {        # text blocks = maximal runs of non-chunk lines; returns data.frame(start, end, install)
  inch <- FALSE; end_rx <- NA; typ <- character(length(lines))
  for (i in seq_along(lines)) {
    ln <- lines[i]
    if (!inch) {
      if (grepl(PAT$chunk.begin, ln, perl = TRUE)) {
        inch <- TRUE; end_rx <- sub("(^[\t >]*```+).*", "^\\1\\\\s*$", ln); typ[i] <- "chunk"
      } else typ[i] <- "text"
    } else {
      typ[i] <- "chunk"
      if (grepl(end_rx, ln, perl = TRUE)) inch <- FALSE
    }
  }
  r <- rle(typ); e <- cumsum(r$lengths); s <- e - r$lengths + 1L
  data.frame(start = s[r$values == "text"], end = e[r$values == "text"], stringsAsFactors = FALSE)
}
read_input_lines <- function(p) {
  raw <- readBin(p, "raw", file.size(p)); txt <- rawToChar(raw); Encoding(txt) <- "UTF-8"
  txt <- sub("^﻿", "", txt); txt <- gsub("\r\n?", "\n", txt)
  if (!nzchar(txt)) character() else strsplit(txt, "\n", fixed = TRUE)[[1]]
}
read_log <- function(f) {
  if (!file.exists(f)) return(NULL)
  x <- readLines(f, encoding = "UTF-8", warn = FALSE)
  p <- strsplit(x, "\t", fixed = TRUE)
  d <- do.call(rbind, lapply(p, function(v) { length(v) <- 13; v }))
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  names(d) <- c("tag", "file", "n", "kc", "cs", "cl", "pb", "rx", "lb", "fr", "mode", "nchar", "first")
  for (k in c("n", "kc", "cs", "cl", "pb", "rx", "lb", "fr", "nchar")) d[[k]] <- suppressWarnings(as.integer(d[[k]]))
  d
}
## align calls of one (tag,file) top-level document to truth blocks; returns data.frame with truth added
align <- function(d, inputs_dir) {
  out <- list()
  for (key in unique(paste(d$tag, d$file, sep = "__"))) {
    sub <- d[paste(d$tag, d$file, sep = "__") == key & d$mode == "top", ]
    f <- file.path(inputs_dir, key); if (!file.exists(f) || !nrow(sub)) next
    L <- read_input_lines(f); tb <- truth_blocks(L)
    inst <- grep("lines_install\\(", L)[1]
    k0 <- if (is.na(inst)) 0L else sum(tb$start < inst)
    idx <- k0 + seq_len(nrow(sub))
    ok <- idx <= nrow(tb)
    sub$truth <- NA_integer_; sub$truth[ok] <- tb$start[idx[ok]]
    sub$tlen <- NA_integer_; sub$tlen[ok] <- vapply(idx[ok], function(i) nchar(paste(L[tb$start[i]:tb$end[i]], collapse = "\n")), 1L)
    out[[key]] <- sub
  }
  if (length(out)) do.call(rbind, out) else NULL
}
SUM <- list()
summarise <- function(a, label = "", show = TRUE, record = TRUE) {
  n <- nrow(a)
  if (!n) { cat(sprintf("%-30s no hook calls\n", label)); return(invisible(a)) }
  best <- ifelse(is.na(a$cs), a$rx, a$cs)
  ag <- function(v) sum(!is.na(v) & v == a$truth)
  usepb <- any(!is.na(a$pb)); usefr <- any(!is.na(a$fr))
  cat(sprintf("%-30s n %4d | ==truth: kc %4d cs %4d cl %4d cs+rx %4d%s | cs==kc %4d cl==kc %4d | cs NA %d rx saved %d | len-misaligned %d\n",
              label, n, ag(a$kc), ag(a$cs), ag(a$cl), ag(best), paste0(if (usepb) sprintf(" pb %4d", ag(a$pb)) else "", if (usefr) sprintf(" fr %4d", ag(a$fr)) else ""),
              sum(!is.na(a$cs) & a$cs == a$kc), sum(!is.na(a$cl) & a$cl == a$kc), sum(is.na(a$cs)), sum(is.na(a$cs) & !is.na(a$rx) & a$rx == a$truth),
              sum(a$nchar != a$tlen, na.rm = TRUE)))
  bad <- a[is.na(a$cs) | a$cs != a$truth | is.na(a$cl) | a$cl != a$truth | is.na(a$kc) | a$kc != a$truth | (usepb & (is.na(a$pb) | a$pb != a$truth)), ]
  if (show && nrow(bad)) { cat("   rows where some method != truth (first 12):\n"); print(head(bad[, c("n", "truth", "kc", "cs", "cl", "pb", "rx", "lb", "fr", "nchar", "tlen", "first")], 12), row.names = FALSE) }
  if (record) SUM[[length(SUM) + 1L]] <<- cbind(label = label, a[, c("n", "truth", "kc", "cs", "cl", "pb", "rx", "lb", "fr")])
  invisible(a)
}
