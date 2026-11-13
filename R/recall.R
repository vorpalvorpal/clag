# recall_check() (design-3 L37-L39, rule 9.5.1): do the lints reproduce what an
# audit recorded, and do they flag too much?

# NFC, emphasis marks and backticks out, curly quotes straight, white space
# collapsed, lower case; `map` gives, for each kept character, the offset in
# `x` of the character it came from.
recall_normalise <- function(x) {
  if (!nzchar(x)) return(list(text = "", map = integer()))
  cl <- stringi::stri_split_boundaries(x, type = "character")[[1L]]
  origin <- cumsum(c(1L, nchar(cl)))[seq_along(cl)]
  cl <- stringi::stri_trans_nfc(cl)
  cl <- gsub("[\u2018\u2019]", "'", cl)
  cl <- gsub("[\u201c\u201d]", "\"", cl)
  cl <- stringi::stri_trans_tolower(cl)
  keep <- !(cl %in% c("*", "_", "`"))
  cl <- cl[keep]
  origin <- origin[keep]
  ws <- grepl("^[[:space:]]+$", cl)
  cl[ws] <- " "
  # collapse runs of white space to the first
  drop <- ws & c(FALSE, ws[-length(ws)])
  cl <- cl[!drop]
  origin <- origin[!drop]
  chars <- strsplit(paste(cl, collapse = ""), "")[[1L]]
  map <- rep(origin, nchar(cl))
  list(text = paste(chars, collapse = ""), map = map, nchars = length(chars))
}

recall_windows <- function(q) {
  L <- nchar(q)
  if (L < 12L) return(character())
  if (L < 40L) return(q)
  st <- seq(1L, L - 39L, by = 20L)
  substring(q, st, st + 39L)
}

#' Check how well the lints reproduce recorded findings
#'
#' Locates each recorded finding in a source folder by its quoted text (or by
#' file and line), lints the folder, and reports per rule how many located
#' findings the rule reproduces and how much of the source it flags.
#'
#' @param findings A data frame with `id`, and `quote` or both `file` and
#'   `line`; optionally `file` (several paths split on `;`, `,` or white space)
#'   and `rule` (ids split on `;`; `NA` is every rule; `""` no rule).
#' @param source A folder of documents.
#' @param rules `NULL` (every rule) or rule ids.
#' @param commit `NULL`, or a git commit whose archive of `source` is linted.
#' @param window Half-width, in lines, used when a finding has no quote.
#' @param nearly The share of sentences at or above which a rule "flags nearly
#'   everything".
#' @return A `weft_recall` data frame, one row per rule and a last row `any`,
#'   with the attributes `matches` and `unlocated`.
#' @export
recall_check <- function(findings, source, rules = NULL, commit = NULL, window = 2L, nearly = 0.8) {
  if (!is.data.frame(findings) || !"id" %in% names(findings)) {
    tool_abort("recall_check(): `findings` needs an `id` column.")
  }
  has_q <- "quote" %in% names(findings)
  has_fl <- all(c("file", "line") %in% names(findings))
  if (!has_q && !has_fl) {
    tool_abort("recall_check(): `findings` needs a `quote` column, or `file` and `line` columns.")
  }
  if ("line" %in% names(findings)) {
    ln <- findings$line
    ok <- is.numeric(ln) || all(is.na(ln))
    if (ok) ok <- all(is.na(ln) | (is.finite(ln) & ln == round(ln)))
    if (!ok) tool_abort("recall_check(): `line` must be whole numbers.")
  }
  if (!is.character(source) || length(source) != 1L || is.na(source) || !dir.exists(source)) {
    tool_abort("recall_check(): `source` must be a folder.")
  }
  if (!is.null(commit)) {
    if (!nzchar(git_path())) tool_abort("recall_check(): `commit` needs git, which was not found.")
    tmp <- tempfile("recall-")
    tarf <- tempfile("recall-", fileext = ".tar")
    on.exit(unlink(c(tmp, tarf), recursive = TRUE), add = TRUE)
    dir.create(tmp)
    ar <- git_raw(normalizePath(source), c("archive", "--format=tar", commit))
    if (!identical(ar$status, 0L)) {
      tool_abort(sprintf("recall_check(): git could not archive `%s` of %s.", commit, source))
    }
    writeBin(ar$out, tarf)
    utils::untar(tarf, exdir = tmp)
    source <- tmp
  }
  found <- lints(source, rules = rules, tier = 1:2)
  root <- normalizePath(find_project_root(normalizePath(source)), winslash = "/")
  docs <- lint_files_under(root)
  srcs <- lapply(docs, function(d) lint_open(root, d))
  names(srcs) <- docs
  srcs <- Filter(function(s) !isTRUE(s$invalid), srcs)
  sent <- lapply(srcs, source_sentences)
  norm <- lapply(srcs, function(s) recall_normalise(s$prose))
  total_sent <- sum(vapply(sent, nrow, 1L))
  rule_ids <- if (is.null(rules)) lint_rules()$id else rules
  n <- nrow(findings)
  fid <- as.character(findings$id)
  fq <- if (has_q) as.character(findings$quote) else rep(NA_character_, n)
  ffile <- if ("file" %in% names(findings)) as.character(findings$file) else rep(NA_character_, n)
  fline <- if ("line" %in% names(findings)) as.integer(findings$line) else rep(NA_integer_, n)
  frule <- if ("rule" %in% names(findings)) as.character(findings$rule) else rep(NA_character_, n)
  # units: list of data frames (file, first sentence index, last)
  unit <- vector("list", n)
  mfile <- rep(NA_character_, n)
  mline <- rep(NA_integer_, n)
  for (i in seq_len(n)) {
    named <- if (is.na(ffile[i])) character() else
      trimws(strsplit(ffile[i], "[;,[:space:]]+")[[1L]])
    named <- named[nzchar(named)]
    named <- intersect(named, names(srcs))
    if (!is.na(fq[i]) && nzchar(trimws(fq[i]))) {
      q <- recall_normalise(fq[i])$text
      w <- recall_windows(q)
      if (!length(w)) next
      for (cand in list(named, setdiff(names(srcs), named))) {
        for (d in cand) {
          nm <- norm[[d]]
          hm <- do.call(rbind, lapply(w, function(x) {
            m <- gregexpr(x, nm$text, fixed = TRUE)[[1L]]
            if (m[1L] == -1L) return(NULL)
            cbind(as.integer(m), as.integer(m) + nchar(x) - 1L)
          }))
          if (is.null(hm)) next
          ps <- nm$map[hm[, 1L]]
          pe <- nm$map[hm[, 2L]]
          s <- sent[[d]]
          idx <- unique(unlist(lapply(seq_len(nrow(hm)), function(k) which(s$start <= pe[k] & s$end >= ps[k]))))
          if (!length(idx)) next
          unit[[i]] <- data.frame(file = d, idx = idx, stringsAsFactors = FALSE)
          mfile[i] <- d
          mline[i] <- src_line_of(srcs[[d]], min(ps))
          break
        }
        if (!is.null(unit[[i]])) break
      }
    } else if (!is.na(ffile[i]) && !is.na(fline[i])) {
      for (d in named) {
        s <- sent[[d]]
        idx <- which(s$line <= fline[i] + window & s$end_line >= fline[i] - window)
        if (length(idx)) {
          unit[[i]] <- data.frame(file = d, idx = idx, stringsAsFactors = FALSE)
          mfile[i] <- d
          mline[i] <- fline[i]
          break
        }
      }
    }
  }
  located <- !vapply(unit, is.null, NA)
  # which sentences hold a finding of which rule
  fpos <- if (nrow(found)) mapply(function(f, l, c) srcs[[f]]$line_start[l] + c - 1L, found$file, found$line, found$col) else numeric()
  fsent <- rep(NA_integer_, nrow(found))
  for (k in seq_len(nrow(found))) {
    s <- sent[[found$file[k]]]
    if (is.null(s)) next
    j <- which(s$start <= fpos[k] & s$end >= fpos[k])[1L]
    fsent[k] <- j
  }
  held <- function(rule) {
    sel <- if (is.null(rule)) rep(TRUE, nrow(found)) else found$rule == rule
    unique(paste(found$file[sel & !is.na(fsent)], fsent[sel & !is.na(fsent)]))
  }
  # a flag outside every sentence (a chunk header or option, a caption) is credited by its lines: the
  # lines of the finding, widened to the whole chunk when it sits in a chunk (review 3, S1)
  cov_lo <- cov_hi <- integer()
  cov_file <- cov_rule <- character()
  for (k in which(is.na(fsent))) {
    sr <- srcs[[found$file[k]]]
    lo <- found$line[k]
    hi <- found$end_line[k]
    ch <- sr$chunks
    if (!is.null(ch) && nrow(ch)) {
      at <- which(ch$open <= lo & ch$close >= lo)
      if (length(at)) {
        lo <- ch$open[at[1L]]
        hi <- max(hi, ch$close[at[1L]])
      }
    }
    cov_lo <- c(cov_lo, lo)
    cov_hi <- c(cov_hi, hi)
    cov_file <- c(cov_file, found$file[k])
    cov_rule <- c(cov_rule, found$rule[k])
  }
  reproduced_by <- function(i, rule) {
    u <- unit[[i]]
    if (is.null(u)) return(FALSE)
    if (any(paste(u$file, u$idx) %in% held(rule))) return(TRUE)
    if (!length(cov_lo)) return(FALSE)
    s <- sent[[u$file[1L]]]
    lo <- min(s$line[u$idx])
    hi <- max(s$end_line[u$idx])
    any(cov_file == u$file[1L] & (is.null(rule) | cov_rule %in% rule) & cov_lo <= hi & cov_hi >= lo)
  }
  rules_of <- lapply(frule, function(r) if (is.na(r)) NA_character_ else {
    v <- trimws(strsplit(r, ";", fixed = TRUE)[[1L]])
    v[nzchar(v)]
  })
  row_for <- function(rule) {
    ins <- vapply(rules_of, function(v) if (is.null(rule)) TRUE else anyNA(v) || rule %in% v, NA)
    if (!is.null(rule)) ins <- ins & !vapply(rules_of, function(v) length(v) == 0L, NA)
    loc <- ins & located
    rep_n <- sum(vapply(which(loc), function(i) reproduced_by(i, rule), NA))
    fl <- if (is.null(rule)) nrow(found) else sum(found$rule == rule)
    fs <- length(held(rule))
    tr <- if (is.null(rule)) NA_integer_ else lint_rule_table()$tier[match(rule, lint_rule_table()$id)]
    share <- if (total_sent) fs / total_sent else 0
    v <- character()
    if (sum(loc) >= 3L && rep_n == 0L) v <- c(v, "reproduces none")
    if (total_sent && share >= nearly) v <- c(v, "flags nearly everything")
    data.frame(rule = if (is.null(rule)) "any" else rule, tier = as.integer(tr), in_scope = sum(ins),
               located = sum(loc), reproduced = rep_n,
               recall = if (sum(loc)) rep_n / sum(loc) else NA_real_, flagged = fl,
               sentences = total_sent, flagged_sentences = fs, share = share,
               verdict = if (length(v)) paste(v, collapse = "; ") else "ok", stringsAsFactors = FALSE)
  }
  tab <- do.call(rbind, c(lapply(rule_ids, row_for), list(row_for(NULL))))
  rownames(tab) <- NULL
  attr(tab, "matches") <- data.frame(id = fid, located = located, file = mfile, line = mline,
                                     rules = frule, stringsAsFactors = FALSE)
  attr(tab, "unlocated") <- data.frame(id = fid[!located], stringsAsFactors = FALSE)
  class(tab) <- c("weft_recall", "data.frame")
  tab
}

#' @param x A `weft_recall`.
#' @param ... Passed on.
#' @rdname recall_check
#' @export
print.weft_recall <- function(x, ...) {
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(d, "matches") <- NULL
  attr(d, "unlocated") <- NULL
  print(d, row.names = FALSE)
  bad <- x$verdict != "ok"
  if (any(bad)) {
    cat("\n")
    for (i in which(bad)) cat(x$rule[i], ": ", x$verdict[i], "\n", sep = "")
  }
  un <- attr(x, "unlocated")
  if (!is.null(un) && nrow(un)) cat("\nUnlocated: ", paste(un$id, collapse = ", "), "\n", sep = "")
  invisible(x)
}
