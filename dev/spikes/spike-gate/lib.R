## spike-gate/lib.R -- throwaway: scanner wrapper, unit extraction, paragraph matcher, baseline, scoring.
SCRATCH <- "/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad"
source(file.path(SCRATCH, "spike-grammar2/setup.R"))       # stand-in scanner: clag_parse(), clag_attr()
clag$O <- ""; clag$C <- ""

norm_ws <- function(x) trimws(gsub("[[:space:]]+", " ", x))
canon <- function(e) {                                     # parsed expression, deparsed (whitespace/quoting-insensitive)
  p <- tryCatch(parse(text = e, keep.source = FALSE), error = function(err) NULL)
  if (is.null(p) || !length(p)) return(paste0("!", norm_ws(e)))
  paste(vapply(p, function(x) paste(deparse(x), collapse = " "), ""), collapse = "; ")
}

## ---- scan one chunk of text for constructs -> character vector of identities (in order) ----
## strict = TRUE: knitr's own rule, inline R is "`r" + (space or #) -- a newline after `r is NOT inline code.
## strict = FALSE: text was whitespace-normalised first, so "`r<newline>x`" is read as "`r x`".
scan_ids <- function(txt, strict = FALSE) {
  m <- gregexpr(if (strict) "`r[ #][^`]*`" else "`r [^`]*`", txt, perl = TRUE)
  codes <- regmatches(txt, m)[[1]]
  clag$pend <- as.list(sub("^`r[ #]", "", sub("`$", "", codes)))
  if (length(codes)) {
    regmatches(txt, m) <- list(paste0(clag$O, seq_along(codes), clag$C))
  }
  nodes <- clag_parse(txt)$nodes
  out <- character()
  walk <- function(nds) for (nd in nds) {
    if (nd$t == "val" && !is.null(nd$attrs) && (length(nd$attrs$cls) || length(nd$attrs$id))) {
      a <- nd$attrs
      out <<- c(out, if (length(a$id)) paste0("id:", a$id[1])
                     else paste0("v:", canon(clag$pend[[nd$idx]]), "|", paste(sort(a$cls), collapse = " ")))
    } else if (nd$t == "br") {
      a <- nd$attrs
      if (!is.null(a)) { k <- which(a$keys %in% c("n", "if", "sign")); if (length(k)) out <<- c(out, paste0("g:", a$keys[k[1]], "=", canon(a$vals[k[1]]))) }
      walk(nd$kids)
    }
  }
  walk(nodes); out
}

## ---- split a .qmd into paragraph-like units (line based, no Pandoc) ----
extract_units <- function(lines, strict = FALSE) {
  units <- list(); sec <- "<pre>"; n <- length(lines); i <- 1L
  buf <- character(); btype <- "p"; bstart <- 0L
  add <- function(type, txt, line) units[[length(units) + 1L]] <<- list(sec = sec, type = type, text = norm_ws(txt), raw = txt, line = line)
  flush <- function() { if (length(buf)) add(btype, paste(buf, collapse = "\n"), bstart); buf <<- character(); btype <<- "p" }
  start <- function(type, l, ln) { flush(); btype <<- type; buf <<- l; bstart <<- ln }
  if (n && lines[1] == "---") { e <- which(lines[-1] %in% c("---", "..."))[1]; i <- e + 2L }
  while (i <= n) {
    l <- lines[i]
    if (grepl("^\\s*(`{3,}|~{3,})", l)) {                                   # fenced block
      flush()
      fc <- regmatches(l, regexpr("`{3,}|~{3,}", l)); ch <- substr(fc, 1, 1)
      close_rx <- paste0("^\\s*\\", ch, "{", nchar(fc), ",}\\s*$")
      j <- i + 1L; while (j <= n && !grepl(close_rx, lines[j])) j <- j + 1L
      if (grepl("^\\s*(`{3,})\\{", l) && j > i + 1L) {                      # executable chunk: keep the #| option lines as one unit
        body <- lines[(i + 1L):(j - 1L)]; opt <- body[grepl("^\\s*#\\|", body)]
        if (length(opt)) add("chunk", paste(sub("^\\s*#\\|\\s?", "", opt), collapse = "\n"), i)
      }
      i <- j + 1L; next
    }
    if (grepl("^\\s*$", l)) { flush(); i <- i + 1L; next }
    if (grepl("^\\s*:{3,}", l)) { flush(); i <- i + 1L; next }              # div fence
    if (grepl("^\\s*>", l)) { l <- sub("^(\\s*>)+\\s?", "", l); if (grepl("^\\s*$", l)) { flush(); i <- i + 1L; next } }
    if (grepl("^#{1,6}\\s", l)) {
      flush()
      a <- regmatches(l, regexec("\\{[^}]*#(sec-[A-Za-z0-9_-]+)[^}]*\\}\\s*$", l))[[1]]
      if (length(a)) sec <- a[2]
      add("heading", l, i)
    } else if (grepl("^\\s*([-*+]|[0-9]+[.)])\\s+", l)) start("li", l, i)
    else if (grepl("^\\s*\\|.*\\|\\s*$", l)) {
      flush(); if (!grepl("^\\s*\\|[-:| ]+\\|\\s*$", l)) add("tr", l, i)
    } else if (grepl("^\\[\\^[^]]+\\]:", l)) start("fn", l, i)
    else { if (!length(buf)) { bstart <- i; btype <- "p" }; buf <- c(buf, l) }
    i <- i + 1L
  }
  flush()
  for (k in seq_along(units)) units[[k]]$ids <- scan_ids(if (strict) units[[k]]$raw else units[[k]]$text, strict)
  units
}

## ---- LCS alignment of two character vectors -> matched index pairs ----
lcs_pairs <- function(a, b) {
  na <- length(a); nb <- length(b)
  d <- matrix(0L, na + 1L, nb + 1L)
  for (i in seq_len(na)) for (j in seq_len(nb))
    d[i + 1L, j + 1L] <- if (a[i] == b[j]) d[i, j] + 1L else max(d[i, j + 1L], d[i + 1L, j])
  i <- na; j <- nb; out <- list()
  while (i > 0L && j > 0L) {
    if (a[i] == b[j]) { out[[length(out) + 1L]] <- c(i, j); i <- i - 1L; j <- j - 1L }
    else if (d[i, j + 1L] >= d[i + 1L, j]) i <- i - 1L else j <- j - 1L
  }
  if (!length(out)) return(matrix(0L, 0, 2))
  do.call(rbind, rev(out))
}

## ---- pair removed/added identities inside one changed paragraph pair (nearest string, same kind preferred) ----
kind_of <- function(x) sub("^([a-z]+):(n|if|sign)?.*$", "\\1\\2", x)
pair_ra <- function(R, A) {
  prs <- list()
  if (!length(R) || !length(A)) return(list(pairs = prs, R = R, A = A))
  dm <- adist(R, A) + outer(kind_of(R), kind_of(A), function(x, y) ifelse(x == y, 0, 20))
  rr <- seq_along(R); aa <- seq_along(A)
  while (length(rr) && length(aa)) {
    sub <- dm[rr, aa, drop = FALSE]; k <- which(sub == min(sub), arr.ind = TRUE)[1, ]
    prs[[length(prs) + 1L]] <- c(R[rr[k[1]]], A[aa[k[2]]]); rr <- rr[-k[1]]; aa <- aa[-k[2]]
  }
  list(pairs = prs, R = R[rr], A = A[aa])
}

## ---- the matcher. gap = "one" (the proposal: a gap pairs only when exactly 1 changed unit each side)
##      or "equal" (variant: gaps of equal size k pair positionally).  Returns list(events, pairs, unmatched_b, unmatched_a)
match_versions <- function(lb, la, gap = "one", strict = TRUE, verify = FALSE) {
  ub <- extract_units(lb, strict); ua <- extract_units(la, strict)
  sb <- vapply(ub, `[[`, "", "sec"); sa <- vapply(ua, `[[`, "", "sec")
  ev <- list(); pairs <- list(); unb <- integer(); una <- integer()
  cand_r <- list(); cand_a <- list()                       # candidates for netting: list(id, unit)
  push_ev <- function(status, id, after = "", ub_i = NA, ua_i = NA)
    ev[[length(ev) + 1L]] <<- list(status = status, id = id, after = after, ub = ub_i, ua = ua_i)
  handle_pair <- function(i, j) {                           # changed paragraph pair
    bi <- ub[[i]]$ids; ai <- ua[[j]]$ids
    cb <- table(bi); ca <- table(ai); R <- character(); A <- character()
    for (id in union(names(cb), names(ca))) {
      nb <- if (id %in% names(cb)) cb[[id]] else 0L; na <- if (id %in% names(ca)) ca[[id]] else 0L
      k <- min(nb, na)
      for (z in seq_len(k)) push_ev("unchanged", id, "", i, j)
      if (nb > k) R <- c(R, rep(id, nb - k)); if (na > k) A <- c(A, rep(id, na - k))
    }
    pr <- pair_ra(R, A)
    for (p in pr$pairs) push_ev("edited", p[1], p[2], i, j)
    for (id in pr$R) cand_r[[length(cand_r) + 1L]] <<- list(id = id, u = i)
    for (id in pr$A) cand_a[[length(cand_a) + 1L]] <<- list(id = id, u = j)
    pairs[[length(pairs) + 1L]] <<- c(i, j)
  }
  unmatched <- function(is, js) {
    for (i in is) { unb <<- c(unb, i); for (id in ub[[i]]$ids) cand_r[[length(cand_r) + 1L]] <<- list(id = id, u = i) }
    for (j in js) { una <<- c(una, j); for (id in ua[[j]]$ids) cand_a[[length(cand_a) + 1L]] <<- list(id = id, u = j) }
  }
  pend_b <- integer(); pend_a <- integer()
  jacc <- function(x, y) { a <- unique(strsplit(x, " ", fixed = TRUE)[[1]]); b <- unique(strsplit(y, " ", fixed = TRUE)[[1]]); length(intersect(a, b)) / length(union(a, b)) }
  pair_sim <- function(is, js, thr) {                      # greedy pairing by word-set Jaccard; returns the unpaired indices
    if (!length(is) || !length(js)) return(list(is = is, js = js))
    sm <- outer(is, js, Vectorize(function(i, j) jacc(ub[[i]]$text, ua[[j]]$text)))
    while (length(is) && length(js)) {
      k <- which(sm == max(sm), arr.ind = TRUE)[1, ]
      if (sm[k[1], k[2]] < thr) break
      handle_pair(is[k[1]], js[k[2]]); sm[k[1], ] <- -1; sm[, k[2]] <- -1; is[k[1]] <- NA; js[k[2]] <- NA
      if (all(is.na(is)) || all(is.na(js))) break
    }
    list(is = is[!is.na(is)], js = js[!is.na(js)])
  }
  for (s in union(unique(sb), unique(sa))) {
    ib <- which(sb == s); ia <- which(sa == s)
    if (!length(ib) || !length(ia)) { pend_b <- c(pend_b, ib); pend_a <- c(pend_a, ia); next }
    tb <- vapply(ub[ib], `[[`, "", "text"); ta <- vapply(ua[ia], `[[`, "", "text")
    m <- lcs_pairs(tb, ta)
    keep <- rep(TRUE, nrow(m))
    for (r in seq_len(nrow(m))) {
      i <- ib[m[r, 1]]; j <- ia[m[r, 2]]
      if (verify && !identical(sort(ub[[i]]$ids), sort(ua[[j]]$ids))) { handle_pair(i, j); keep[r] <- FALSE }   # same words, different constructs
      else for (id in ub[[i]]$ids) push_ev("unchanged", id, "", i, j)
    }
    mb <- c(0L, m[, 1], length(ib) + 1L); ma <- c(0L, m[, 2], length(ia) + 1L)
    for (g in seq_len(length(mb) - 1L)) {
      gb <- if (mb[g] + 1L <= mb[g + 1L] - 1L) (mb[g] + 1L):(mb[g + 1L] - 1L) else integer()
      ga <- if (ma[g] + 1L <= ma[g + 1L] - 1L) (ma[g] + 1L):(ma[g + 1L] - 1L) else integer()
      if (gap != "sim" && length(gb) == 1L && length(ga) == 1L) handle_pair(ib[gb], ia[ga])
      else if (gap == "equal" && length(gb) == length(ga) && length(gb) > 1L) for (k in seq_along(gb)) handle_pair(ib[gb[k]], ia[ga[k]])
      else if (gap == "sim" && length(gb) && length(ga)) { r <- pair_sim(ib[gb], ia[ga], 0.5); pend_b <- c(pend_b, r$is); pend_a <- c(pend_a, r$js) }
      else { pend_b <- c(pend_b, ib[gb]); pend_a <- c(pend_a, ia[ga]) }
    }
  }
  if (gap == "sim") { r <- pair_sim(pend_b, pend_a, 0.6); pend_b <- r$is; pend_a <- r$js }   # across sections / renamed anchors
  unmatched(pend_b, pend_a)
  ## netting: a candidate removal is a move if the same identity is a candidate addition elsewhere
  used_a <- rep(FALSE, length(cand_a))
  for (c in cand_r) {
    k <- which(!used_a & vapply(cand_a, function(x) x$id == c$id, NA))[1]
    if (!is.na(k)) { used_a[k] <- TRUE; push_ev("moved", c$id, "", c$u, cand_a[[k]]$u) } else push_ev("removed", c$id, "", c$u, NA)
  }
  for (k in which(!used_a)) push_ev("added", cand_a[[k]]$id, "", NA, cand_a[[k]]$u)
  list(events = ev, pairs = pairs, unmatched_b = unb, unmatched_a = una, ub = ub, ua = ua)
}

## ---- the no-matching baseline: every identity whose file-wide count falls is a removal ----
baseline_removals <- function(lb, la, strict = TRUE) {
  b <- unlist(lapply(extract_units(lb, strict), `[[`, "ids")); a <- unlist(lapply(extract_units(la, strict), `[[`, "ids"))
  cb <- table(factor(b, levels = union(b, a))); ca <- table(factor(a, levels = union(b, a)))
  d <- setNames(pmax(0L, as.integer(cb) - as.integer(ca)), names(cb)); rep(names(d), d)
}

## ---- scoring helpers ----
evkey <- function(status, id, after = "") paste(status, id, after, sep = " >> ")
ev_keys <- function(ev, drop = c("unchanged", "moved")) {
  ev <- Filter(function(e) !(e$status %in% drop), ev)
  vapply(ev, function(e) if (e$status == "edited") evkey("edited", e$id, e$after) else evkey(e$status, e$id), "")
}
ms_diff <- function(x, y) { out <- character(); tx <- table(x); ty <- table(y)       # multiset x minus y
  for (k in names(tx)) { d <- tx[[k]] - if (k %in% names(ty)) ty[[k]] else 0L; if (d > 0) out <- c(out, rep(k, d)) }; out }
