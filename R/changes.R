# changes() and the third state (rules 7.2.1, 7.2.3, 7.3, 7.4.4; dev/design-2e.md C1-C14).
# changes() compares the ledgers in the working tree with those at a commit. It
# renders nothing, runs no pipeline and writes nothing (7.3.6); git is only read.

# ---- the third state (C11) ----------------------------------------------------

# A header field as a named character vector; JSON null is NA.
header_map <- function(x) {
  if (!length(x)) return(stats::setNames(character(), character()))
  out <- vapply(x, function(v) {
    if (is.null(v) || length(v) != 1L || is.na(v)) NA_character_ else as.character(v)
  }, "")
  stats::setNames(out, names(x))
}

same_hash <- function(a, b) {
  if (is.na(a) || is.na(b)) return(is.na(a) && is.na(b))
  identical(as.character(a), as.character(b))
}

# Is what a chapter's ledger header recorded still what is there (7.2.1)? Judged
# from the store, the dictionary and the files now; nothing is run.
# Returns list(stale, reasons, notes).
ledger_state <- function(root, header) {
  reasons <- character()
  notes <- character()

  tg <- header$targets
  if (length(tg)) {
    if (!has_targets()) {
      notes <- c(notes, "targets is not installed; the pipeline was not checked")
    } else {
      for (store in names(tg)) {
        sp <- file.path(root, store)
        if (!dir.exists(sp)) {
          notes <- c(notes, sprintf("the store %s does not exist; the pipeline was not checked", store))
          next
        }
        m <- tryCatch(suppressMessages(targets::tar_meta(fields = "data", store = sp)),
                      error = function(e) NULL)
        if (is.null(m) || !file.exists(file.path(sp, "meta", "meta"))) {
          notes <- c(notes, sprintf("the store %s could not be read; the pipeline was not checked", store))
          next
        }
        nm <- as.character(m$name)
        hs <- header_map(tg[[store]])
        for (t in names(hs)) {
          i <- match(t, nm)
          if (is.na(i)) {
            reasons <- c(reasons, sprintf("target `%s` is not in the store", t))
          } else if (!same_hash(hs[[t]], as.character(m$data[i]))) {
            reasons <- c(reasons, sprintf("target `%s` changed", t))
          }
        }
      }
    }
  }

  dh <- header_map(header$dict)
  if (length(dh)) {
    dp <- file.path(root, "dict.yml")
    if (!file.exists(dp)) {
      reasons <- c(reasons, "dict.yml is gone")
    } else {
      now <- tryCatch({
        suppressWarnings(read_dict(dp))
        dict_entry_hashes(dp)
      }, error = function(e) NULL)
      if (is.null(now)) {
        notes <- c(notes, "dict.yml has problems; the dictionary was not checked")
      } else {
        for (k in names(dh)) {
          if (!k %in% names(now)) {
            reasons <- c(reasons, sprintf("dict$%s is gone", k))
          } else if (!same_hash(dh[[k]], now[[k]])) {
            reasons <- c(reasons, sprintf("dict$%s changed", k))
          }
        }
      }
    }
  }

  fh <- header_map(header$files)
  for (p in names(fh)) {
    fp <- file.path(root, p)
    if (!file.exists(fp)) {
      reasons <- c(reasons, sprintf("%s is gone", p))
    } else if (!same_hash(fh[[p]], file_hash(fp))) {
      reasons <- c(reasons, sprintf("%s changed", p))
    }
  }

  list(stale = length(reasons) > 0L, reasons = reasons, notes = notes)
}

# ---- claim words (C9) -----------------------------------------------------------

# The ranking's claim words: stage 3's lexicon (5.5.1) without the number words and
# ordinals that 7.3.4 keeps out of the ranking (K10).
claim_words <- function() {
  setdiff(claim_lexicon(default_config(), "en"),
          c("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
            "twelve", "first", "second", "third"))
}

# The first claim word in a sentence once the entry's own text is removed once, as
# a whole word (so `ten` inside `Often` stays).
sentence_claim <- function(sentence, text) {
  if (is.na(sentence) || !nzchar(sentence)) return(NA_character_)
  if (!is.na(text) && nzchar(text)) {
    esc <- gsub("([][\\\\^$.|?*+(){}])", "\\\\\\1", text)
    sentence <- sub(paste0("(?<![[:alpha:]])", esc, "(?![[:alpha:]])"), "", sentence, perl = TRUE)
  }
  tok <- strsplit(tolower(sentence), "[^[:alpha:]]+")[[1L]]
  hit <- tok[tok %in% claim_words()]
  if (length(hit)) hit[[1L]] else NA_character_
}

# ---- git, read only (C1, C3) -------------------------------------------------------

changes_abort <- function(msg) weft_abort(msg, "weft_changes_error")

# ---- reading the two sides (C3, C4) ---------------------------------------------------

ledger_paths_now <- function(root) {
  d <- file.path(root, "_weft", "ledger")
  if (!dir.exists(d)) return(character())
  f <- list.files(d, pattern = "\\.jsonl$", recursive = TRUE, all.files = TRUE)
  f <- enc2utf8(f)
  f <- f[!grepl("\\.conditions\\.jsonl$", f)]
  if (!length(f)) return(character())
  sort(paste0("_weft/ledger/", f), method = "radix")
}

ledger_paths_then <- function(root, commit) {
  out <- git_records(root, c("ls-tree", "-r", "-z", "--name-only", commit, "--", "_weft/ledger"))
  if (is.null(out)) return(character())
  f <- enc2utf8(out[grepl("\\.jsonl$", out) & !grepl("\\.conditions\\.jsonl$", out)])
  sort(f, method = "radix")
}

# One ledger on one side: its entries, header, condition log and, when it could not
# be read strictly, the reader's message. `commit` NULL reads the working tree.
read_side <- function(root, path, commit = NULL) {
  cpath <- sub("\\.jsonl$", ".conditions.jsonl", path)
  get <- function(p) {
    if (is.null(commit)) {
      fp <- file.path(root, p)
      if (file.exists(fp)) read_source_lines(fp) else NULL
    } else git_show(root, p, commit)
  }
  lines <- get(path)
  if (is.null(lines)) lines <- character()
  what <- if (is.null(commit)) file.path(root, path) else paste0(substr(commit, 1L, 7L), ":", path)
  note <- NA_character_
  x <- tryCatch(read_ledger(file = what, lines = lines), weft_ledger_error = function(e) {
    note <<- conditionMessage(e)
    read_ledger(file = what, lines = lines, lenient = TRUE)
  })
  header <- attr(x, "header")
  v <- suppressWarnings(as.numeric(header[["version"]]))
  if (length(v) == 1L && !is.na(v) && v > LEDGER_VERSION) {
    x <- x[0L, , drop = FALSE]
    if (is.na(note)) note <- sprintf("%s is version %s; this weft reads up to version %d (rule 7.1.5)",
                                     path, v, LEDGER_VERSION)
  }
  clines <- get(cpath)
  cond <- if (is.null(clines)) condition_df(list()) else
    tryCatch(read_condition_log(file = cpath, lines = clines), weft_ledger_error = function(e)
      read_condition_log(file = cpath, lines = clines, lenient = TRUE))
  parts <- strsplit(sub("^_weft/ledger/", "", path), "/", fixed = TRUE)[[1L]]
  src <- chr1(header[["source"]])
  if (is.na(src)) src <- paste(parts[-length(parts)], collapse = "/")
  out <- chr1(header[["output"]])
  if (is.na(out)) out <- sub("\\.jsonl$", "", parts[length(parts)])
  list(path = path, x = x, header = header, cond = cond, note = note, source = src, output = out)
}

# ---- renamed sources (C5) ----------------------------------------------------------------

rename_share <- function(a, b) {
  if (!nrow(a$x)) return(0)
  kb <- paste(b$x$section, b$x$kind, b$x$expr, b$x$occ, sep = "\001")
  ka <- paste(a$x$section, a$x$kind, a$x$expr, a$x$occ, sep = "\001")
  ib <- b$x$id[!is.na(b$x$id)]
  hit <- ka %in% kb | (!is.na(a$x$id) & a$x$id %in% ib)
  mean(hit)
}

pair_renames <- function(only_then, only_now) {
  pairs <- list()
  used <- character()
  for (a in only_then) {
    own <- function(z) identical(z$output, strip_ext(z$source))
    cand <- Filter(function(b) (identical(b$output, a$output) || (own(a) && own(b))) &&
                     !b$path %in% used, only_now)
    if (!length(cand)) next
    sh <- vapply(cand, function(b) rename_share(a, b), 1)
    ok <- sh >= 0.5
    if (!any(ok)) next
    best <- max(sh[ok])
    w <- which(ok & sh == best)
    if (length(w) != 1L) next
    b <- cand[[w]]
    pairs[[length(pairs) + 1L]] <- list(then = a, now = b)
    used <- c(used, b$path)
  }
  pairs
}

# ---- comparing entries (C7-C10) ---------------------------------------------------------

entry_keys <- function(x) {
  n <- nrow(x)
  if (!n) return(character())
  k <- paste("k", x$file, x$section, x$kind, x$expr, x$occ, sep = "\001")
  has_id <- !is.na(x$id)
  if (any(has_id)) {
    ids <- x$id[has_id]
    k[has_id] <- paste("id", ids, stats::ave(seq_along(ids), ids, FUN = seq_along), sep = "\001")
  }
  k
}

# Keys of both sides as entry_keys() gives them, except that within a (file, section,
# kind, expr) group whose counts differ the occurrences are lined up by their sentences
# (longest common subsequence), the entries between two lined-up ones by order, so that
# deleting one of several identical expressions removes that one (C7, finding 3).
align_keys <- function(tx, nx) {
  kt <- entry_keys(tx)
  kn <- entry_keys(nx)
  if (!length(kt) || !length(kn)) return(list(kt = kt, kn = kn))
  g <- function(x) ifelse(is.na(x$id), paste(x$file, x$section, x$kind, x$expr, sep = "\001"), NA_character_)
  gt <- g(tx)
  gn <- g(nx)
  for (grp in unique(gt[!is.na(gt) & gt %in% gn])) {
    it <- which(gt == grp)
    jn <- which(gn == grp)
    if (length(it) == length(jn)) next
    st <- tx$sentence[it]
    sn <- nx$sentence[jn]
    st[is.na(st)] <- "\002NA"
    sn[is.na(sn)] <- "\003NA"
    nt <- length(it)
    nn <- length(jn)
    L <- matrix(0L, nt + 1L, nn + 1L)
    for (a in seq_len(nt)) for (b in seq_len(nn)) {
      L[a + 1L, b + 1L] <- if (st[a] == sn[b]) L[a, b] + 1L else max(L[a, b + 1L], L[a + 1L, b])
    }
    anchors <- matrix(integer(), 0L, 2L)
    a <- nt
    b <- nn
    while (a > 0L && b > 0L) {
      if (st[a] == sn[b]) {
        anchors <- rbind(c(a, b), anchors)
        a <- a - 1L
        b <- b - 1L
      } else if (L[a, b + 1L] >= L[a + 1L, b]) a <- a - 1L else b <- b - 1L
    }
    bounds_a <- c(0L, anchors[, 1L], nt + 1L)
    bounds_b <- c(0L, anchors[, 2L], nn + 1L)
    for (s in seq_len(length(bounds_a) - 1L)) {
      if (s > 1L) {
        kt[it[bounds_a[s]]] <- kn[jn[bounds_b[s]]] <- paste("m", grp, s, "anchor", sep = "\001")
      }
      ga <-seq_len(bounds_a[s + 1L] - bounds_a[s] - 1L) + bounds_a[s]
      gb <- seq_len(bounds_b[s + 1L] - bounds_b[s] - 1L) + bounds_b[s]
      m <- min(length(ga), length(gb))
      for (q in seq_len(m)) kt[it[ga[q]]] <- kn[jn[gb[q]]] <- paste("m", grp, s, "gap", q, sep = "\001")
      if (length(ga) > m) kt[it[ga[-seq_len(m)]]] <- paste("t", grp, it[ga[-seq_len(m)]], sep = "\001")
      if (length(gb) > m) kn[jn[gb[-seq_len(m)]]] <- paste("n", grp, jn[gb[-seq_len(m)]], sep = "\001")
    }
  }
  list(kt = kt, kn = kn)
}

dict_keys_of <- function(d) {
  d <- as.character(unlist(d))
  d <- d[grepl("^dict\\$.+", d)]
  sub("^dict\\$", "", d)
}

# keys read by every entry of a (file, section, sentence) group
sentence_groups <- function(x) {
  if (!nrow(x)) return(list())
  g <- ifelse(is.na(x$sentence) | !nzchar(x$sentence), NA_character_,
              paste(x$file, x$section, x$sentence, sep = "\001"))
  ok <- !is.na(g)
  if (!any(ok)) return(list())
  lapply(split(x$dict[ok], g[ok]), function(l) unique(dict_keys_of(l)))
}

# key -> number for the dictionary entries that are numbers, quantities or years
dict_numbers <- function(lines = NULL, file = NULL) {
  tmp <- NULL
  if (is.null(file)) {
    if (is.null(lines)) return(NULL)
    tmp <- tempfile(fileext = ".yml")
    on.exit(unlink(tmp), add = TRUE)
    con <- file(tmp, "wb")
    writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
    close(con)
    file <- tmp
  } else if (!file.exists(file)) return(NULL)
  d <- tryCatch(suppressWarnings(read_dict(file)), error = function(e) NULL)
  if (is.null(d)) return(NULL)
  ty <- attr(d, "entries")$type
  nm <- names(d)
  out <- stats::setNames(rep(NA_real_, length(nm)), nm)
  un <- rep(NA_character_, length(nm))
  for (i in seq_along(nm)) {
    if (!is.na(ty[i]) && ty[i] %in% c("number", "quantity", "year")) {
      out[i] <- tryCatch(suppressWarnings(as.numeric(d[[nm[i]]]))[1L], error = function(e) NA_real_)
      if (inherits(d[[nm[i]]], "units")) {
        un[i] <- tryCatch(units::deparse_unit(d[[nm[i]]])[1L], error = function(e) NA_character_)
      }
    }
  }
  attr(out, "unit") <- un
  out
}

# `x` in unit `from` as a number in unit `to`; NA when either has no unit (unless both
# have none) or the two do not convert.
raw_in_unit <- function(x, from, to) {
  if (is.na(from) && is.na(to)) return(x)
  if (is.na(from) || is.na(to)) return(NA_real_)
  tryCatch(as.numeric(units::set_units(units::set_units(x, from, mode = "standard"), to, mode = "standard")),
           error = function(e) NA_real_)
}

sgn <- function(x) as.numeric(sign(x))

# the structural reasons (C8) of one changed entry, in C8's order, with the place
# of each in that order
structural_reasons <- function(kind, arm_b, arm_a, b, a, keys, tb, ta, ub = NA_character_, ua = NA_character_) {
  r <- character()
  place <- integer()
  add <- function(txt, i) { r <<- c(r, txt); place <<- c(place, i) }
  differs <- !(identical(arm_b, arm_a) || (is.na(arm_b) && is.na(arm_a)))
  if (!is.na(kind) && kind %in% c("n", "if", "sign", "list") && differs) {
    add(sprintf("arm %s -> %s", if (is.na(arm_b)) "none" else arm_b,
                if (is.na(arm_a)) "none" else arm_a), 1L)
  }
  if (is.finite(b) && is.finite(a)) {
    if (b != 0 && a != 0 && sgn(b) != sgn(a)) add("sign flip", 2L)
    if ((b == 0) != (a == 0)) add("crosses 0", 3L)
    if (is.na(ub) && is.na(ua) && (b - 1) * (a - 1) < 0) add("crosses 1.0", 4L)
    thr <- function(t, k) {
      if (is.null(t)) return(list(v = NA_real_, u = NA_character_))
      v <- unname(t[k])
      u <- attr(t, "unit")
      list(v = v, u = if (is.null(u) || is.na(v)) NA_character_ else unname(u[match(k, names(t))]))
    }
    for (k in sort(unique(keys), method = "radix")) {
      pb <- thr(tb, k)
      pa <- thr(ta, k)
      if (length(pb$v) != 1L || length(pa$v) != 1L || is.na(pb$v) || is.na(pa$v)) next
      cb <- raw_in_unit(b, ub, pb$u)
      ca <- raw_in_unit(a, ua, pa$u)
      if (!is.na(cb) && !is.na(ca) && sgn(cb - pb$v) != sgn(ca - pa$v)) add(sprintf("crosses dict$%s", k), 5L)
    }
    if (b != 0 && a != 0 && abs(log10(abs(a / b))) >= 1 - 1e-9) add("order of magnitude", 6L)
  }
  list(reasons = r, place = if (length(place)) min(place) else NA_integer_)
}

ENTRY_COLS <- c("ledger", "output", "file", "section", "kind", "expr", "occ", "id", "change", "structural",
                "claim_word", "rank", "stale", "text_before", "text_after", "arm_before", "arm_after",
                "raw_before", "raw_after", "sentence_before", "sentence_after")

empty_entries <- function() {
  df <- data.frame(ledger = character(), output = character(), file = character(), section = character(),
                   kind = character(), expr = character(), occ = integer(), id = character(),
                   change = character(), structural = character(), claim_word = character(),
                   rank = integer(), stale = logical(), text_before = character(), text_after = character(),
                   arm_before = character(), arm_after = character(), raw_before = numeric(),
                   raw_after = numeric(), sentence_before = character(), sentence_after = character(),
                   stringsAsFactors = FALSE)
  attr(df, "failed_after") <- character()
  attr(df, "section_from") <- character()
  df
}

# Rows for one ledger pair. `tx` and `nx` are the entries then and now (either may
# have no rows); `ctx` carries what the reasons need.
compare_entries <- function(tx, nx, ledger, output, stale, tb, ta) {
  ak <- align_keys(tx, nx)
  kt <- ak$kt
  kn <- ak$kn
  ch <- function(a, b) (is.na(a) != is.na(b)) | (!is.na(a) & !is.na(b) & a != b)
  both <- intersect(kn, kt)
  it <- match(both, kt)
  jn <- match(both, kn)
  jn_a <- which(!kn %in% kt)
  it_r <- which(!kt %in% kn)
  # a section renamed: the anchor exists only then (or only now) in a file; the removed and
  # added entries with equal kind, expression and occurrence are the same entry (question A)
  from_sec <- rep(NA_character_, length(it))
  if (length(jn_a) && length(it_r)) {
    fs_t <- paste(tx$file, tx$section, sep = "\001")
    fs_n <- paste(nx$file, nx$section, sep = "\001")
    old <- it_r[!fs_t[it_r] %in% fs_n]
    new <- jn_a[!fs_n[jn_a] %in% fs_t]
    psi <- integer()
    pj <- integer()
    for (r in old) {
      m <- new[!new %in% pj & nx$file[new] == tx$file[r] & nx$kind[new] == tx$kind[r] &
                 nx$expr[new] == tx$expr[r] & nx$occ[new] == tx$occ[r]]
      if (length(m)) {
        psi <- c(psi, r)
        pj <- c(pj, m[[1L]])
      }
    }
    if (length(psi)) {
      it <- c(it, psi)
      jn <- c(jn, pj)
      from_sec <- c(from_sec, tx$section[psi])
      it_r <- setdiff(it_r, psi)
      jn_a <- setdiff(jn_a, pj)
    }
  }
  diff <- if (length(it)) ch(tx$text[it], nx$text[jn]) | ch(tx$arm[it], nx$arm[jn]) else logical()
  it_c <- it[diff]
  jn_c <- jn[diff]
  from_sec <- c(from_sec[diff], rep(NA_character_, length(jn_a) + length(it_r)))
  I <- c(it_c, rep(NA_integer_, length(jn_a)), it_r)
  J <- c(jn_c, jn_a, rep(NA_integer_, length(it_r)))
  change <- c(rep("changed", length(it_c)), rep("added", length(jn_a)), rep("removed", length(it_r)))
  n <- length(I)
  if (!n) return(NULL)
  pick <- function(x, i, col) x[[col]][i]
  side <- function(col) ifelse(is.na(J), pick(tx, I, col), pick(nx, J, col))
  gtx <- sentence_groups(tx)
  gnx <- sentence_groups(nx)
  structural <- character(n)
  place <- rep(NA_integer_, n)
  claim <- rep(NA_character_, n)
  relv <- rep(NA_real_, n)
  kinds <- side("kind")
  for (r in seq_len(n)) {
    i <- I[r]
    j <- J[r]
    b <- if (is.na(i)) NA_real_ else tx$raw[i]
    a <- if (is.na(j)) NA_real_ else nx$raw[j]
    sb <- if (is.na(i)) NA_character_ else tx$sentence[i]
    sa <- if (is.na(j)) NA_character_ else nx$sentence[j]
    cw <- c(if (!is.na(i)) sentence_claim(sb, tx$text[i]), if (!is.na(j)) sentence_claim(sa, nx$text[j]))
    cw <- cw[!is.na(cw)]
    if (length(cw)) claim[r] <- cw[[1L]]
    if (change[r] != "changed") next
    keys <- c(dict_keys_of(tx$dict[[i]]), dict_keys_of(nx$dict[[j]]))
    if (!is.na(sb) && nzchar(sb)) keys <- c(keys, gtx[[paste(tx$file[i], tx$section[i], sb, sep = "\001")]])
    if (!is.na(sa) && nzchar(sa)) keys <- c(keys, gnx[[paste(nx$file[j], nx$section[j], sa, sep = "\001")]])
    sr <- structural_reasons(kinds[r], tx$arm[i], nx$arm[j], b, a, keys, tb, ta,
                             if (is.null(tx$unit)) NA_character_ else tx$unit[i],
                             if (is.null(nx$unit)) NA_character_ else nx$unit[j])
    structural[r] <- paste(sr$reasons, collapse = ", ")
    place[r] <- sr$place
    relv[r] <- if (is.finite(a) && is.finite(b)) {
      if (b == 0) (if (a == 0) 0 else Inf) else abs(a - b) / abs(b)
    } else NA_real_
  }
  key <- ifelse(is.na(J), kt[ifelse(is.na(I), 1L, I)], kn[ifelse(is.na(J), 1L, J)])
  rows <- data.frame(
    ledger = ledger, output = output, file = side("file"), section = side("section"), kind = kinds,
    expr = side("expr"), occ = as.integer(side("occ")), id = side("id"), change = change,
    structural = structural, claim_word = claim, rank = NA_integer_, stale = stale,
    text_before = pick(tx, I, "text"), text_after = pick(nx, J, "text"),
    arm_before = pick(tx, I, "arm"), arm_after = pick(nx, J, "arm"),
    raw_before = as.numeric(pick(tx, I, "raw")), raw_after = as.numeric(pick(nx, J, "raw")),
    sentence_before = pick(tx, I, "sentence"), sentence_after = pick(nx, J, "sentence"),
    stringsAsFactors = FALSE)
  rows$.key <- key
  rows$.place <- place
  rows$.rel <- relv
  rows$.failed <- pick(nx, J, "failed")
  rows$.from_sec <- from_sec
  rows
}

# ---- changes() ---------------------------------------------------------------------------------

#' What changed in the ledgers since a commit
#'
#' Compares the ledgers of a set-up project in the working tree with those at a
#' git commit, and lists the entries that changed, were added or were removed,
#' the conditions that are new, and the ledgers that are stale (rule 7.3, 7.2.1).
#'
#' An entry is changed when its text or its arm differs; a different raw value
#' alone is not a change. Changed entries are ranked: those with a structural
#' reason (an arm change, a sign flip, a crossing of 0, 1.0 or a dictionary
#' value, a change of an order of magnitude) first, then those beside a claim
#' word, then by relative change. A ledger is stale when what its header
#' recorded (targets in the store, dictionary entries, source files) differs
#' now, so its entries were not re-rendered.
#'
#' `changes()` renders nothing, runs no pipeline and writes nothing. It reads git
#' only. Because it runs no pipeline it does not see a store that is behind its
#' code. `findings` lists the tier-2 lints of [lints()] over the lines added since
#' the commit, with the columns `file`, `line`, `rule` and `message`; a file with
#' more `claim-word` findings than its `claim_cap` gets one row that counts them. Ledgers are
#' paired by path; a source that was renamed is paired with the old one when at
#' least half of its entries match and the two output names are equal or each is
#' its own source's base name; a ledger whose source is gone counts as the old
#' one even while it is still in the working tree. Where one expression occurs
#' several times in a section and the counts differ, the occurrences are lined
#' up by their sentences, so a deleted one is reported as removed. Entries of a
#' section whose heading was renamed are paired and marked `(section renamed
#' from #old)`. A threshold from the dictionary that is a quantity is compared
#' in its own unit, using the `unit` the ledger records beside `raw`; an entry
#' from an older ledger, or a plain number, gives no such crossing. A note under
#' "Ledgers" says so when git ignores `_weft/ledger/` (`git check-ignore -q`, the
#' only git command added to `rev-parse`, `ls-tree` and `show`).
#'
#' The claim words are English only, so a chapter in another language gets no
#' claim-word ranking, and the interim list is broad (it holds common words such
#' as `no`, `all` and `more`, but not the number words `one` to `twelve`,
#' `first`, `second` or `third`); stage 3's lexicon replaces it. A crossing of
#' 1.0 is a reason only where the entry has no unit on either side (a ratio or a
#' count).
#'
#' `print(x, brief = TRUE)` prints the header line, the structural changes, the
#' ledgers not re-rendered and the new conditions, and nothing else.
#'
#' @param since One string naming a commit (anything `git rev-parse` accepts).
#'   `"HEAD"` in a repository with no commit compares with nothing, so every
#'   ledger is new.
#' @param path A folder inside the project; the root is found as elsewhere in
#'   weft and must hold `_weft.yml`.
#' @param files `NULL`, or source paths relative to the root; only their ledgers
#'   are compared.
#' @return A `weft_changes`, a list of the tables `entries`, `conditions`,
#'   `stale`, `ledgers` and `findings`, with the attributes `since`, `commit`
#'   (the full hash, or `NA`) and `root`. It prints as plain text.
#' @export
changes <- function(since = "HEAD", path = ".", files = NULL) {
  if (!is.character(since) || length(since) != 1L || is.na(since) || !nzchar(since)) {
    changes_abort("`since` must be one string naming a commit (rule 7.3.1).")
  }
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    changes_abort("`path` must be one folder inside the project (rule 7.3.1).")
  }
  if (!is.null(files) && (!is.character(files) || anyNA(files))) {
    changes_abort("`files` must be NULL or source paths relative to the project root (rule 7.3.1).")
  }
  if (!is.null(files)) files <- sub("^(\\./)+", "", files)
  root <- normalizePath(find_project_root(path), winslash = "/", mustWork = FALSE)
  if (!is_set_up(root)) {
    changes_abort(sprintf("changes() reads the ledgers of a set-up project; %s has no _weft.yml (rule 9.3.2).",
                          root))
  }
  if (!nzchar(git_path())) {
    changes_abort("changes() needs git: git is not on the path (rule 7.3.1).")
  }
  if (!identical(git_lines(root, c("rev-parse", "--is-inside-work-tree")), "true")) {
    changes_abort(sprintf("changes() needs git: %s is not inside a git work tree (rule 7.3.1).", root))
  }
  rv <- git_lines(root, c("rev-parse", "--verify", "-q", paste0(since, "^{commit}")))
  commit <- NA_character_
  if (!is.null(rv) && length(rv)) {
    commit <- rv[[1L]]
  } else {
    head_ok <- !is.null(git_lines(root, c("rev-parse", "--verify", "-q", "HEAD")))
    if (!(identical(since, "HEAD") && !head_ok)) {
      changes_abort(sprintf("`since`: %s is not a commit (rule 7.3.1).", since))
    }
  }
  have_commit <- !is.na(commit)

  now_p <- ledger_paths_now(root)
  then_p <- if (have_commit) ledger_paths_then(root, commit) else character()
  nows <- stats::setNames(lapply(now_p, function(p) read_side(root, p)), now_p)
  thens <- stats::setNames(lapply(then_p, function(p) read_side(root, p, commit)), then_p)

  both_p <- intersect(now_p, then_p)
  only_now <- nows[setdiff(now_p, then_p)]
  only_then <- thens[setdiff(then_p, now_p)]
  # a ledger on both sides whose source is gone is a rename candidate too (C5)
  orphan_p <- both_p[!vapply(both_p, function(p) file.exists(file.path(root, thens[[p]]$source)), NA)]
  pairs <- pair_renames(unname(c(only_then, thens[orphan_p])), unname(only_now))
  paired_now <- vapply(pairs, function(z) z$now$path, "")
  paired_then <- vapply(pairs, function(z) z$then$path, "")
  recs <- list()
  for (p in setdiff(both_p, paired_then)) recs[[length(recs) + 1L]] <- list(then = thens[[p]], now = nows[[p]])
  recs <- c(recs, pairs)
  for (b in only_now[!names(only_now) %in% paired_now]) recs[[length(recs) + 1L]] <- list(then = NULL, now = b)
  for (a in only_then[!names(only_then) %in% paired_then]) recs[[length(recs) + 1L]] <- list(then = a, now = NULL)

  if (!is.null(files)) {
    srcs <- lapply(recs, function(z) c(z$now$source, z$then$source))
    missing <- files[!vapply(files, function(f) any(vapply(srcs, function(s) f %in% s, NA)), NA)]
    if (length(missing)) {
      changes_abort(sprintf("`files`: no ledger on either side for %s (rule 7.3.1).",
                            paste0("`", missing, "`", collapse = ", ")))
    }
    keep <- vapply(srcs, function(s) any(s %in% files), NA)
    recs <- recs[keep]
  }

  tb <- NULL
  if (have_commit) tb <- dict_numbers(lines = git_show(root, "dict.yml", commit))
  ta <- dict_numbers(file = file.path(root, "dict.yml"))

  ent <- list()
  cond <- list()
  stale <- list()
  led <- list()
  whole <- character()
  for (z in recs) {
    a <- z$then
    b <- z$now
    renamed <- !is.null(a) && !is.null(b) && !identical(a$path, b$path)
    status <- if (is.null(a)) "new" else if (is.null(b)) "deleted" else
      if (renamed) "renamed" else "compared"
    if ((!is.null(a) && !is.na(a$note)) || (!is.null(b) && !is.na(b$note))) status <- "unreadable"
    src <- if (is.null(b)) a$source else b$source
    out <- if (is.null(b)) a$output else b$output
    from <- if (renamed) a$source else NA_character_
    tx <- if (is.null(a)) ledger_df(list()) else a$x
    nx <- if (is.null(b)) ledger_df(list()) else b$x
    if (!is.null(a) && !is.null(b) && !identical(a$source, b$source)) {
      tx$file[tx$file == a$source] <- b$source
    }
    # a ledger whose source is gone keeps that note only (question D)
    st <- if (is.null(b) || !file.exists(file.path(root, src)))
      list(stale = FALSE, reasons = character(), notes = character()) else ledger_state(root, b$header)
    rows <- compare_entries(tx, nx, src, out, st$stale, tb, ta)
    if (!is.null(rows)) ent[[length(ent) + 1L]] <- rows
    if (st$stale) {
      stale[[length(stale) + 1L]] <- data.frame(ledger = src, output = out, entries = nrow(nx),
                                                reason = st$reasons, stringsAsFactors = FALSE)
    }
    if (!is.null(b)) {
      old <- if (is.null(a)) NULL else a$cond
      nk <- paste(b$cond$from, b$cond$source, b$cond$class, b$cond$normalised, sep = "\001")
      ok <- if (is.null(old)) rep(TRUE, nrow(b$cond)) else
        !nk %in% paste(old$from, old$source, old$class, old$normalised, sep = "\001")
      if (any(ok)) {
        cond[[length(cond) + 1L]] <- data.frame(ledger = src, output = out, from = b$cond$from[ok],
                                                source = b$cond$source[ok], class = b$cond$class[ok],
                                                text = b$cond$text[ok], stringsAsFactors = FALSE)
      }
    }
    notes <- c(if (!is.null(b) && !is.na(b$note)) b$note else if (!is.null(a) && !is.na(a$note)) a$note,
               if (!is.null(b) && !file.exists(file.path(root, src)))
                 sprintf("source gone; delete %s/", dirname(b$path)),
               st$notes)
    # a ledger that is new, deleted, or unreadable on one side lists a count, not every entry
    if (status %in% c("new", "deleted") ||
        (status == "unreadable" && (is.null(a) || is.null(b) || !nrow(tx) || !nrow(nx)))) {
      whole <- c(whole, paste(src, out))
    }
    led[[length(led) + 1L]] <- data.frame(
      ledger = src, output = out, path = if (is.null(b)) a$path else b$path, status = status, from = from,
      note = if (length(notes)) paste(notes, collapse = "; ") else NA_character_,
      n = if (status == "deleted") nrow(tx) else nrow(nx), stringsAsFactors = FALSE)
  }

  entries <- if (length(ent)) do.call(rbind, ent) else NULL
  if (is.null(entries)) {
    entries <- empty_entries()
  } else {
    entries <- order_entries(entries)
  }
  ledgers <- if (length(led)) do.call(rbind, led) else
    data.frame(ledger = character(), output = character(), path = character(), status = character(),
               from = character(), note = character(), n = integer(), stringsAsFactors = FALSE)
  ledgers <- ledgers[order(ledgers$ledger, ledgers$output, method = "radix"), , drop = FALSE]
  n_entries <- stats::setNames(ledgers$n, paste(ledgers$ledger, ledgers$output, sep = "\001"))
  ledgers$n <- NULL
  rownames(ledgers) <- NULL
  conditions <- if (length(cond)) do.call(rbind, cond) else
    data.frame(ledger = character(), output = character(), from = character(), source = character(),
               class = character(), text = character(), stringsAsFactors = FALSE)
  conditions <- conditions[order(conditions$ledger, conditions$output, method = "radix"), , drop = FALSE]
  rownames(conditions) <- NULL
  stale_df <- if (length(stale)) do.call(rbind, stale) else
    data.frame(ledger = character(), output = character(), entries = integer(), reason = character(),
               stringsAsFactors = FALSE)
  stale_df <- stale_df[order(stale_df$ledger, stale_df$output, method = "radix"), , drop = FALSE]
  rownames(stale_df) <- NULL
  t2 <- changes_tier2(root, commit, files)
  findings <- t2$table
  res <- list(entries = entries, conditions = conditions, stale = stale_df, ledgers = ledgers,
              findings = findings)
  attr(res, "since") <- since
  attr(res, "commit") <- commit
  attr(res, "root") <- root
  attr(res, "n_entries") <- n_entries
  attr(res, "whole") <- whole
  # `git check-ignore -q` (read only): ledgers that git ignores are never at a commit
  probe <- if (length(now_p)) now_p[[1L]] else "_weft/ledger/"
  ignored <- !is.null(git_lines(root, c("check-ignore", "-q", probe)))
  attr(res, "notes") <- c(if (ignored)
    "_weft/ledger/ is ignored by git, so no ledger can be found at a commit and all are new", t2$notes)
  class(res) <- "weft_changes"
  res
}

# Rank the changed rows (C9) and put them first, then added, then removed.
order_entries <- function(e) {
  ch <- e$change == "changed"
  struct <- ch & nzchar(e$structural)
  place <- ifelse(struct, e$.place, 0L)
  claim <- ifelse(ch & !struct & !is.na(e$claim_word), 0L, 1L)
  rel <- e$.rel
  rel[is.na(rel)] <- -Inf
  grp <- ifelse(ch, ifelse(struct, 0L, 1L), ifelse(e$change == "added", 2L, 3L))
  o <- order(grp, place, claim, -rel, e$ledger, e$output, e$.key, method = "radix")
  e <- e[o, , drop = FALSE]
  ch <- e$change == "changed"
  e$rank[ch] <- seq_len(sum(ch))
  failed <- e$.failed
  from_sec <- e$.from_sec
  e$.from_sec <- NULL
  e$.key <- NULL
  e$.place <- NULL
  e$.rel <- NULL
  e$.failed <- NULL
  e <- e[, ENTRY_COLS]
  rownames(e) <- NULL
  attr(e, "failed_after") <- failed
  attr(e, "section_from") <- from_sec
  e
}

# ---- print (C14) ---------------------------------------------------------------------------------

chg_plural <- function(n, one, many = paste0(one, "s")) sprintf("%d %s", n, if (n == 1L) one else many)

# a source's name, with the output when it is not the source's base name
ledger_label <- function(ledger, output) {
  ifelse(output == vapply(ledger, strip_ext, "", USE.NAMES = FALSE), ledger, paste0(ledger, " (", output, ")"))
}

entry_location <- function(r) {
  loc <- r$file
  if (!is.na(r$section) && nzchar(r$section)) loc <- paste0(loc, "#", r$section)
  if (!identical(r$output, strip_ext(r$ledger))) loc <- paste0(loc, " (", r$output, ")")
  loc
}

#' @param x A `weft_changes`.
#' @param brief If `TRUE`, print only the header line, the structural changes,
#'   the ledgers not re-rendered and the new conditions.
#' @param ... Unused.
#' @rdname changes
#' @export
print.weft_changes <- function(x, brief = FALSE, ...) {
  commit <- attr(x, "commit")
  since <- attr(x, "since")
  short <- if (is.na(commit)) "no commit yet" else substr(commit, 1L, 7L)
  e <- x$entries
  l <- x$ledgers
  n_cmp <- sum(l$status %in% c("compared", "renamed"))
  nothing <- !nrow(e) && !nrow(x$conditions) && !nrow(x$stale) && all(l$status == "compared") && all(is.na(l$note)) &&
    !length(attr(x, "notes")) && !nrow(x$findings)
  if (nothing) {
    cat(sprintf("weft: no changes since %s (%s); %s compared.\n", since, short,
                chg_plural(n_cmp, "ledger")), sep = "")
    return(invisible(x))
  }
  out <- sprintf("weft changes since %s (%s): %s compared; %d changed, %d added, %d removed; %s",
                 since, short, chg_plural(n_cmp, "ledger"), sum(e$change == "changed"),
                 sum(e$change == "added"), sum(e$change == "removed"),
                 chg_plural(nrow(x$conditions), "new condition"))
  failed <- attr(e, "failed_after")
  if (is.null(failed)) failed <- rep(NA_character_, nrow(e))
  whole <- attr(x, "whole")
  if (is.null(whole)) whole <- paste(l$ledger[l$status %in% c("new", "deleted")], l$output[l$status %in% c("new", "deleted")])
  sec_from <- attr(e, "section_from")
  if (is.null(sec_from)) sec_from <- rep(NA_character_, nrow(e))
  in_whole <- paste(e$ledger, e$output) %in% whole
  say <- function(s, t) if (!is.na(t) && !nzchar(t)) "(prints nothing)" else if (!is.na(s) && nzchar(s)) s else if (!is.na(t)) t else ""
  entry_lines <- function(idx, marker) {
    unlist(lapply(idx, function(i) {
      r <- e[i, ]
      head <- paste0("  ", marker, " ", entry_location(r), "  ", r$kind, "  ", r$expr)
      if (!is.na(r$id)) head <- paste0(head, " {#", r$id, "}")
      br <- if (nzchar(r$structural)) r$structural else if (!is.na(r$claim_word) && r$change == "changed")
        sprintf("claim word \"%s\"", r$claim_word) else ""
      if (nzchar(br)) head <- paste0(head, "  [", br, "]")
      if (!is.na(sec_from[i])) head <- paste0(head, " (section renamed from #", sec_from[i], ")")
      if (isTRUE(r$stale)) head <- paste0(head, " (not re-rendered)")
      if (r$change == "changed") {
        after <- if (is.na(r$text_after)) sprintf("(failed: %s)", if (is.na(failed[i])) "?" else failed[i]) else
          say(r$sentence_after, r$text_after)
        c(head, paste0("      before: ", say(r$sentence_before, r$text_before)), paste0("      after:  ", after))
      } else {
        c(head, paste0("      ", if (r$change == "added") say(r$sentence_after, r$text_after) else
          say(r$sentence_before, r$text_before)))
      }
    }), use.names = FALSE)
  }
  sect <- function(title, lines) if (length(lines)) c("", title, lines) else character()
  if (nrow(x$stale)) {
    sk <- unique(x$stale[c("ledger", "output")])
    lines <- vapply(seq_len(nrow(sk)), function(i) {
      s <- x$stale[x$stale$ledger == sk$ledger[i] & x$stale$output == sk$output[i], ]
      sprintf("  %s: %s; %s", ledger_label(sk$ledger[i], sk$output[i]), chg_plural(s$entries[1L], "entry", "entries"),
              paste(s$reason, collapse = "; "))
    }, "")
    out <- c(out, sect("Not re-rendered", lines))
  }
  struct <- which(e$change == "changed" & nzchar(e$structural))
  other <- which(e$change == "changed" & !nzchar(e$structural))
  out <- c(out, sect("Structural changes", entry_lines(struct, "~")),
           if (!brief) c(sect("Other changes, ranked", entry_lines(other, "~")),
           sect("Added", entry_lines(which(e$change == "added" & !in_whole), "+")),
           sect("Removed", entry_lines(which(e$change == "removed" & !in_whole), "-"))))
  if (nrow(x$conditions)) {
    cd <- x$conditions
    out <- c(out, sect("New conditions",
                       sprintf("  ! %s  %s %s  %s: %s", ledger_label(cd$ledger, cd$output), cd$from, cd$source, cd$class, cd$text)))
  }
  if (brief) {
    cat(paste0(out, "\n"), sep = "")
    return(invisible(x))
  }
  if (nrow(x$findings)) {
    fd <- x$findings
    out <- c(out, sect("Tier-2 findings", sprintf("  ? %s:%d  %s  %s", fd$file, fd$line, fd$rule, fd$message)))
  }
  show <- l$status != "compared" | !is.na(l$note)
  gnotes <- attr(x, "notes")
  if (any(show) || length(gnotes)) {
    ln <- l[show, , drop = FALSE]
    n_e <- attr(x, "n_entries")
    lines <- vapply(seq_len(nrow(ln)), function(i) {
      n <- n_e[[paste(ln$ledger[i], ln$output[i], sep = "\001")]]
      base <- switch(ln$status[i],
                     new = paste0("new, ", chg_plural(n, "entry", "entries")),
                     deleted = paste0("deleted, ", chg_plural(n, "entry", "entries")),
                     renamed = paste0("renamed from ", ln$from[i]),
                     unreadable = paste0("unreadable", if (n > 0L) paste0(", ", chg_plural(n, "entry", "entries")) else ""),
                     NA_character_)
      txt <- paste(c(base[!is.na(base)], if (!is.na(ln$note[i])) ln$note[i]), collapse = "; ")
      sprintf("  %s (%s): %s", ln$ledger[i], ln$output[i], txt)
    }, "")
    out <- c(out, sect("Ledgers", c(lines, if (length(gnotes)) paste0("  ", gnotes))))
  }
  cat(paste0(out, "\n"), sep = "")
  invisible(x)
}
