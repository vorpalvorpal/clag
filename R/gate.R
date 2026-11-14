# The commit gate (design-4 G5-G20): `gate()` compares the index with HEAD for every
# weft project of a repository. It reads git only (see R/gate-git.R), keeps a cache
# under the git common directory (R/gate-cache.R) and judges, per project:
#   * construct errors on the new side of every changed document (G9);
#   * findings added, by rule and text, over the whole project (G10);
#   * weft constructs removed, against a `Weft-Removed: N` trailer (G12, G13).

GATE_CONSTRUCT_RULES <- c("construct", "block-start", "read")

#' The commit gate
#'
#' `gate()` is what the `commit-msg` hook runs. It compares the index (what the
#' commit will hold) with `HEAD` for every project of the repository, a project
#' being a folder that holds `_weft.yml`, and fails the commit on a construct
#' error in a changed document, on a tier-1 finding that `HEAD` did not hold, and
#' on weft constructs removed when the message does not say so with a
#' `Weft-Removed: N` trailer (rules 6.1 to 6.3). It reads git only and changes
#' nothing in the repository; its cache lives under the git directory.
#'
#' @param message `NULL`, or the path of a file holding the commit message. With
#'   none, the message has no trailer.
#' @param path A folder inside a git work tree. The whole repository is judged.
#' @return A `weft_gate`, invisibly: a list with `ok`, `errors` and `added` (a
#'   `weft_findings` each), `excess` (a data frame of `project`, `rule`, `text`,
#'   `base`, `new`), `removed` (`project`, `file`, `line`, `kind`, `text`, from
#'   `HEAD`), `n_removed`, `trailer`, `changed`, `notes`, `seconds` and `checks` (the checks of one value
#'   that are gone since `HEAD`, each with what still checks it: information only, rule 6.3.7; columns
#'   `project`, `file`, `line`, `cond`, `level`, `verdict`, `by`, `by_line` and `remains`). The
#'   report is printed to stderr with [message()].
#' @export
gate <- function(message = NULL, path = ".") {
  t0 <- proc.time()[["elapsed"]]
  w <- git_where(path)
  g <- gate_state(w)
  top <- w$top
  head <- git_head(top)
  new_ent <- git_entries_index(top)
  base_ent <- list()
  if (is.na(head)) {
    g$notes <- c(g$notes, "first commit: findings are not compared, so this commit is the starting point (rule 6.2.5)")
  } else {
    heads <- unique(c(head, git_merge_heads(w$gitdir)))
    base_ent <- lapply(heads, function(h) git_entries_commit(top, h))
  }
  # the projects: a folder holding _weft.yml on either side (G7)
  sides <- c(list(new_ent), base_ent)
  pre <- unlist(lapply(sides, function(e) {
    f <- e$path[basename(e$path) == "_weft.yml" & e$mode %in% c("100644", "100755")]
    ifelse(dirname(f) == ".", "", dirname(f))
  }))
  prefixes <- sort(unique(as.character(pre)), method = "radix")
  if (!length(prefixes)) g$notes <- c(g$notes, "no weft project (no _weft.yml)")
  # a document belongs to the innermost project that holds it (review 4, #7)
  pj <- lapply(prefixes, function(p) {
    deeper <- prefixes[if (nzchar(p)) startsWith(prefixes, paste0(p, "/")) else nzchar(prefixes)]
    list(prefix = p, display = if (nzchar(p)) p else ".",
         new = gate_side_entries(g, new_ent, p, deeper),
         parents = lapply(base_ent, function(e) gate_side_entries(g, e, p, deeper)))
  })
  gate_sizes(g, pj)
  ids <- gate_rule_ids()
  vers <- gate_versions()
  for (i in seq_along(pj)) {
    pj[[i]]$new <- gate_side_keys(g, pj[[i]]$new, vers)
    pj[[i]]$parents <- lapply(pj[[i]]$parents, function(s) gate_side_keys(g, s, vers))
  }
  parts <- lapply(pj, function(p) {
    base_res <- lapply(p$parents, function(s) gate_side_results(g, s, p, ids))
    new_res <- gate_side_results(g, p$new, p, ids)
    gate_judge_project(g, p, new_res, base_res)
  })
  tr <- git_trailer(top, message)
  res <- gate_assemble(g, parts, tr)
  cache_prune(g$cache)
  res$notes <- unique(c(g$notes, g$cache$notes))
  res$seconds <- proc.time()[["elapsed"]] - t0
  class(res) <- "weft_gate"
  message(paste(gate_report_lines(res), collapse = "\n"))
  invisible(res)
}

#' @param x A `weft_gate`.
#' @param ... Not used.
#' @rdname gate
#' @export
print.weft_gate <- function(x, ...) {
  message(paste(gate_report_lines(x), collapse = "\n"))
  invisible(x)
}

gate_state <- function(w) {
  g <- new.env(parent = emptyenv())
  g$top <- w$top
  g$cache <- gate_cache_new(w$common)
  g$notes <- character()
  g$added <- new.env(parent = emptyenv())
  g
}

gate_rule_ids <- function() {
  rt <- lint_rules()
  t1 <- rt[rt$tier == 1L & rt$id != "tar-name", , drop = FALSE]
  list(file = t1$id[t1$scope == "file"], project = t1$id[t1$scope == "project"])
}

# ---- one side of one project (G5-G8) --------------------------------------------------------------------

# The tracked paths of one project on one side, classified. `rel` is the path under the project root;
# the subtree of any project in `deeper` (prefixes of projects inside this one) is left out.
gate_side_entries <- function(g, ent, prefix, deeper = character()) {
  if (nzchar(prefix)) {
    e <- ent[startsWith(ent$path, paste0(prefix, "/")), , drop = FALSE]
    e$rel <- substring(e$path, nchar(prefix) + 2L)
  } else {
    e <- ent
    e$rel <- e$path
  }
  for (d in deeper) e <- e[!startsWith(e$path, paste0(d, "/")), , drop = FALSE]
  stores <- store_dirs(g$top, e)
  in_store <- rep(FALSE, nrow(e))
  for (s in stores) in_store <- in_store | e$rel == s | startsWith(e$rel, paste0(s, "/"))
  e <- e[!in_store, , drop = FALSE]
  rownames(e) <- NULL
  e$content <- e$mode %in% c("100644", "100755") & is_content_path(e$rel)
  list(entries = e, prefix = prefix)
}

# content files over 5 MB become placeholders, with a note (G6)
gate_sizes <- function(g, pj) {
  sides <- unlist(lapply(pj, function(p) c(list(p$new), p$parents)), recursive = FALSE)
  blobs <- unlist(lapply(sides, function(s) s$entries$blob[s$entries$content]))
  sz <- git_sizes(g$top, blobs)
  g$sizes <- sz
  big <- character()
  for (p in pj) {
    for (s in c(list(p$new), p$parents)) {
      e <- s$entries
      b <- e$content & !is.na(sz[e$blob]) & sz[e$blob] > GATE_MAX_BYTES
      if (any(b)) big <- c(big, if (nzchar(s$prefix)) paste0(s$prefix, "/", e$rel[b]) else e$rel[b])
    }
  }
  big <- unique(big)
  if (length(big)) {
    g$notes <- c(g$notes, sprintf("%s is over 5 MB and is read as an empty file", big))
  }
  invisible()
}

# The cache keys of a side (G14), all known from the listing.
gate_side_keys <- function(g, s, vers) {
  e <- s$entries
  sz <- g$sizes[e$blob]
  big <- e$content & !is.na(sz) & sz > GATE_MAX_BYTES
  e$ok <- e$content & !big
  e$doc <- e$ok & is_doc_path(e$rel)
  cfgb <- function(name) {
    i <- match(name, e$rel)
    if (is.na(i)) "" else e$blob[i]
  }
  cfg <- paste(cfgb("_weft.yml"), cfgb("_quarto.yml"), cfgb("_quarto.yaml"), sep = "|")
  docs <- e[e$doc, , drop = FALSE]
  docs <- docs[order(enc2utf8(docs$rel), method = "radix"), , drop = FALSE]
  pf <- e[e$content & !e$doc, , drop = FALSE]
  pf <- pf[order(enc2utf8(pf$rel), method = "radix"), , drop = FALSE]
  allc <- e[e$content, , drop = FALSE]
  allc <- allc[order(enc2utf8(allc$rel), method = "radix"), , drop = FALSE]
  pathhash <- cli::hash_md5(paste(sort(enc2utf8(e$rel), method = "radix"), collapse = "\n"))
  fp <- cli::hash_md5(paste(paste(pf$rel, pf$blob), collapse = "\n"))
  full <- cli::hash_md5(paste(paste(allc$rel, allc$blob), collapse = "\n"))
  src_key <- if (nrow(docs)) gate_key("src", vers, docs$rel, docs$blob, cfg) else character()
  docs$src_key <- src_key
  docs$file_key <- if (nrow(docs)) gate_key("file", src_key, fp, pathhash) else character()
  s$entries <- e
  s$docs <- docs
  s$proj_key <- gate_key("proj", vers, full, pathhash)
  s
}

# ---- reading a side, through the cache ----------------------------------------------------------------------

plain_findings <- function(x) {
  out <- lapply(FINDING_COLS, function(cn) x[[cn]])
  names(out) <- FINDING_COLS
  as.data.frame(out, stringsAsFactors = FALSE)
}

empty_plain_findings <- function() plain_findings(new_findings())

bind_plain <- function(parts, empty) {
  parts <- Filter(function(p) !is.null(p) && nrow(p) > 0L, parts)
  if (!length(parts)) return(empty)
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

# The reader `lints()` uses for the length of one call: a source comes from memory or the `src` layer when
# its key is known, and each source read is kept in `captured` for the construct count.
gate_reader <- function(g, s, captured) {
  keys <- stats::setNames(s$docs$src_key, s$docs$rel)
  function(path, root, cfg) {
    rel <- lint_rel_path(path, root)
    key <- unname(keys[rel])
    src <- NULL
    if (!is.na(key)) {
      src <- g$cache$mem[[key]]
      if (is.null(src)) {
        src <- cache_get(g$cache, "src", key)
        if (!is.null(src) && !inherits(src, "weft_source")) src <- NULL
        if (!is.null(src)) g$cache$mem[[key]] <- src
      }
    }
    if (is.null(src)) {
      src <- read_source(path, root, cfg)
      if (!is.na(key)) {
        g$cache$mem[[key]] <- src
        cache_put(g$cache, "src", key, src)
      }
    }
    src$path <- path
    if (!isTRUE(src$invalid)) src$cache <- new.env(parent = emptyenv())
    captured[[rel]] <- src
    src
  }
}

gate_materialise <- function(g, e, root) {
  dirs <- unique(dirname(e$rel))
  dirs <- dirs[dirs != "."]
  for (d in dirs[order(nchar(dirs))]) dir.create(file.path(root, d), recursive = TRUE, showWarnings = FALSE)
  ok <- e$ok
  blobs <- git_blobs(g$top, e$blob[ok])
  for (i in which(ok)) {
    b <- blobs[[e$blob[i]]]
    writeBin(if (is.null(b)) raw() else b, file.path(root, e$rel[i]))
  }
  rest <- file.path(root, e$rel[!ok])
  if (length(rest)) file.create(rest)
  invisible()
}

# The working constructs and the checks of documents read with the default settings, or NULL when one cannot
# be read.
gate_fallback_constructs <- function(rels, root) {
  rows <- lapply(rels, function(rel) {
    tryCatch({
      src <- read_source(file.path(root, rel), root, default_config())
      list(constructs = if (isTRUE(src$invalid)) construct_empty() else working_constructs(src),
           checks = gate_file_checks(src, rel))
    }, error = function(e) NULL)
  })
  if (any(vapply(rows, is.null, NA))) return(NULL)
  names(rows) <- rels
  list(constructs = bind_plain(lapply(rows, `[[`, "constructs"), construct_empty()),
       checks = gate_bind_checks(lapply(rows, `[[`, "checks")))
}

# The checks of one document (F9, N132), with its path as the file, for the file's cache entry.
gate_file_checks <- function(src, rel) {
  r <- if (is.null(src)) checks_empty() else checks_read(src)
  rn <- attr(r, "rebound_names")
  if (nrow(r)) r$file <- rep(rel, nrow(r))
  attr(r, "rebound_names") <- rn %||% character()
  r
}

# The checks of several documents (a list named by path) as one table; the attribute `rebound` holds each
# document's rebound names.
gate_bind_checks <- function(per) {
  rn <- lapply(per, function(d) attr(d, "rebound_names") %||% character())
  parts <- Filter(function(d) !is.null(d) && nrow(d) > 0L, unname(per))
  out <- if (length(parts)) do.call(rbind, parts) else checks_empty()
  rownames(out) <- NULL
  attr(out, "rebound") <- rn
  out
}

# What one side holds: findings (file and project scope, tier 1, no tar-name), construct rows, or an error
# (with the constructs read apart, when they could be).
gate_side_results <- function(g, s, p, ids) {
  docs <- s$docs
  per <- list()
  miss <- character()
  for (i in seq_len(nrow(docs))) {
    ent <- cache_get(g$cache, "file", docs$file_key[i])
    if (is.list(ent) && all(c("findings", "constructs", "checks") %in% names(ent))) {
      per[[docs$rel[i]]] <- ent
      cache_touch(g$cache, "src", docs$src_key[i])
    } else {
      miss <- c(miss, docs$rel[i])
    }
  }
  have_proj <- length(ids$project) > 0L
  pf <- if (have_proj) cache_get(g$cache, "proj", s$proj_key) else empty_plain_findings()
  need_proj <- have_proj && is.null(pf)
  if (length(miss) || need_proj) {
    tmp <- tempfile("weft-gate-")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    root <- file.path(tmp, "p")
    dir.create(root)
    gate_materialise(g, s$entries, root)
    captured <- new.env(parent = emptyenv())
    old <- weft_env$lint_reader
    on.exit(weft_env$lint_reader <- old, add = TRUE)
    weft_env$lint_reader <- gate_reader(g, s, captured)
    out <- tryCatch({
      ff <- if (length(miss)) lints(root, files = miss, rules = ids$file, tier = 1) else NULL
      pr <- if (need_proj) lints(root, rules = ids$project, tier = 1) else NULL
      list(file = ff, proj = pr)
    }, weft_config_error = function(e) e)
    if (inherits(out, "error")) {
      msg <- conditionMessage(out)
      shown <- if (nzchar(p$prefix)) file.path(g$top, p$prefix) else g$top
      for (r in unique(c(root, normalizePath(root, winslash = "/", mustWork = FALSE)))) {
        msg <- gsub(r, shown, msg, fixed = TRUE)
      }
      # the configuration does not read, so the findings are unknown; the constructs are still counted, read
      # with the default settings, for the removal count (review 4, design question 7)
      fb <- gate_fallback_constructs(docs$rel, root)
      return(list(error = msg, constructs = fb$constructs, checks = fb$checks))
    }
    if (length(miss)) {
      ff <- plain_findings(out$file)
      by <- split(seq_len(nrow(ff)), factor(ff$file, levels = miss))
      for (rel in miss) {
        src <- captured[[rel]]
        ent <- list(findings = ff[by[[rel]], , drop = FALSE],
                    constructs = if (is.null(src)) construct_empty() else working_constructs(src),
                    checks = gate_file_checks(src, rel))
        rownames(ent$findings) <- NULL
        per[[rel]] <- ent
        k <- docs$file_key[match(rel, docs$rel)]
        cache_put(g$cache, "file", k, ent)
      }
    }
    if (need_proj) {
      pf <- plain_findings(out$proj)
      cache_put(g$cache, "proj", s$proj_key, pf)
    }
  }
  list(error = NULL,
       findings = bind_plain(c(unname(lapply(per, `[[`, "findings")), list(pf)), empty_plain_findings()),
       constructs = bind_plain(unname(lapply(per, `[[`, "constructs")), construct_empty()),
       checks = gate_bind_checks(lapply(per, `[[`, "checks")))
}

# ---- judging one project (G9, G10, G12, G17, G18) ------------------------------------------------------------

count_keys <- function(k) {
  if (!length(k)) return(stats::setNames(integer(), character()))
  t <- table(k)
  stats::setNames(as.integer(t), names(t))
}

gate_judge_project <- function(g, p, new_res, base_res) {
  prefix <- p$prefix
  top_path <- function(rel) if (nzchar(prefix)) paste0(prefix, "/", rel) else rel
  out <- list(errors = empty_plain_findings(), excess = NULL, added = empty_plain_findings(),
              removed = NULL, n = 0L, changed = character())
  # changed documents (G8); against every parent under a merge
  nd <- p$new$docs
  pdocs <- lapply(p$parents, function(s) s$docs)
  rels <- sort(unique(c(nd$rel, unlist(lapply(pdocs, function(d) d$rel)))), method = "radix")
  nb <- nd$blob[match(rels, nd$rel)]
  if (length(pdocs)) {
    differs <- lapply(pdocs, function(d) {
      pb <- d$blob[match(rels, d$rel)]
      is.na(nb) != is.na(pb) | (!is.na(nb) & !is.na(pb) & nb != pb)
    })
    chg <- Reduce(`&`, differs)
  } else {
    chg <- !is.na(nb)
  }
  changed <- rels[chg]
  out$changed <- vapply(changed, top_path, "", USE.NAMES = FALSE)
  if (!is.null(new_res$error)) {
    f <- new_findings(file = top_path("_weft.yml"), line = 1L, rule = "construct", context = "project",
                      text = "_weft.yml", message = new_res$error)
    out$errors <- plain_findings(f)
    return(out)
  }
  nf <- new_res$findings
  is_err <- nf$rule %in% GATE_CONSTRUCT_RULES
  e <- nf[is_err & nf$file %in% changed, , drop = FALSE]
  if (nrow(e)) {
    e$file <- vapply(e$file, top_path, "", USE.NAMES = FALSE)
    out$errors <- e
  }
  if (!length(p$parents)) return(out)
  bad <- Filter(function(b) !is.null(b$error), base_res)
  if (length(bad)) {
    f <- top_path("_weft.yml")
    g$notes <- c(g$notes, sprintf("%s did not read at HEAD (%s); findings are not compared for %s", f,
                                  gsub("\n", " ", bad[[1L]]$error), p$display))
  }
  # findings added (G10); skipped when a base did not read, the removal count still runs (G18)
  if (!length(bad)) {
    fe <- findings_excess(nf[!is_err, , drop = FALSE],
                          lapply(base_res, function(b) b$findings[!(b$findings$rule %in% GATE_CONSTRUCT_RULES), , drop = FALSE]),
                          function(rel) if (rel %in% changed) gate_added_lines(g, p, rel) else FALSE)
    if (!is.null(fe$excess)) {
      out$excess <- cbind(project = p$display, fe$excess, stringsAsFactors = FALSE)
      a <- fe$added
      a$file <- vapply(a$file, top_path, "", USE.NAMES = FALSE)
      out$added <- a
    }
  }
  # checks gone (F9, N132 to N139): information only
  out$checks <- gate_judge_checks(g, p, new_res, base_res)
  # constructs removed (G12, as changed by review 4, design question 1): claims are counted apart from
  # values and spans, so that a deleted claim() does not hide behind an added value
  if (any(vapply(base_res, function(b) is.null(b$constructs), NA))) return(out)
  cr <- constructs_removed(lapply(base_res, `[[`, "constructs"), new_res$constructs)
  out$n <- cr$n
  r <- cr$rows
  if (nrow(r)) {
    out$removed <- data.frame(project = rep(p$display, nrow(r)), file = vapply(r$file, top_path, "", USE.NAMES = FALSE),
                              line = as.integer(r$line), kind = r$kind, text = r$text, stringsAsFactors = FALSE)
  }
  out
}

# The findings of the new side that the base sides did not hold (G10), counted by rule and text so that moving a
# finding between files adds nothing. `new` and each of `bases` are tables of findings without construct errors;
# a key's base count is the largest over the bases (the merge parents). `added_lines(rel)` gives the lines added in
# a document (TRUE: all of them, FALSE: none). Where a key has instances on added lines only those are listed,
# else all of them (H16). Returns `excess` (rule, text, base, new; NULL when none), `n` (the count added) and
# `added` (the instances). The one comparison, used by gate() and verify().
findings_excess <- function(new, bases, added_lines) {
  none <- list(excess = NULL, n = 0L, added = new[0L, , drop = FALSE])
  if (!nrow(new)) return(none)
  nk <- gate_finding_keys(new)
  cn <- count_keys(nk)
  bn <- stats::setNames(integer(), character())
  for (bf in bases) {
    bc <- count_keys(gate_finding_keys(bf))
    ks <- union(names(bn), names(bc))
    bn <- stats::setNames(pmax(ifelse(is.na(bn[ks]), 0L, bn[ks]), ifelse(is.na(bc[ks]), 0L, bc[ks])), ks)
  }
  base_n <- ifelse(is.na(bn[names(cn)]), 0L, unname(bn[names(cn)]))
  ex <- names(cn)[cn - base_n > 0L]
  if (!length(ex)) return(none)
  exb <- base_n[match(ex, names(cn))]
  excess <- data.frame(rule = sub("\001.*$", "", ex),
                       text = sub("^\002file$", "(the file's own name)", sub("^[^\001]*\001", "", ex)),
                       base = as.integer(exb), new = as.integer(cn[ex]), stringsAsFactors = FALSE)
  inst <- new[nk %in% ex, , drop = FALSE]
  ik <- nk[nk %in% ex]
  on_added <- rep(FALSE, nrow(inst))
  for (rel in unique(inst$file)) {
    add <- added_lines(rel)
    rows <- which(inst$file == rel)
    on_added[rows] <- vapply(rows, function(r) {
      isTRUE(add) || any(add >= inst$line[r] & add <= inst$end_line[r])
    }, NA)
  }
  sel <- logical(nrow(inst))
  for (k in ex) {
    r <- which(ik == k)
    sel[r] <- if (any(on_added[r])) on_added[r] else TRUE
  }
  list(excess = excess, n = as.integer(sum((cn - base_n)[cn - base_n > 0L])), added = inst[sel, , drop = FALSE])
}

# The constructs the base sides held that the new side does not (G12, as changed by review 4, design question
# 1). `bases` is a list of construct tables, one per parent under a merge; the count is against the one with the
# fewest. Claims are counted apart from values and spans, so that a deleted claim() does not hide behind an
# added value. Returns the count `n` and the `rows` of the base with no match in `new`. The one comparison,
# used by gate() and verify().
constructs_removed <- function(bases, new) {
  groups <- list(function(k) k == "claim", function(k) k != "claim")
  n <- 0L
  rem <- list()
  for (is_grp in groups) {
    bs <- lapply(bases, function(b) b[is_grp(b$kind), , drop = FALSE])
    nw <- new[is_grp(new$kind), , drop = FALSE]
    totals <- vapply(bs, nrow, 1L)
    n_p <- min(totals) - nrow(nw)
    if (n_p <= 0L) next
    n <- n + as.integer(n_p)
    b <- bs[[which.min(totals)]]
    tb <- count_keys(b$text)
    tn <- count_keys(nw$text)
    rows <- integer()
    for (t in names(tb)) {
      have <- if (t %in% names(tn)) tn[[t]] else 0L
      take <- tb[[t]] - have
      if (take > 0L) {
        i <- which(b$text == t)
        i <- i[order(enc2utf8(b$file[i]), b$line[i], method = "radix")]
        rows <- c(rows, utils::tail(i, take))
      }
    }
    rem[[length(rem) + 1L]] <- b[rows, , drop = FALSE]
  }
  r <- bind_plain(rem, construct_empty())
  if (nrow(r)) {
    r <- r[order(enc2utf8(r$file), r$line, method = "radix"), , drop = FALSE]
    rownames(r) <- NULL
  }
  list(n = n, rows = r)
}

# The key of a finding for the count (G10): its rule and text. A finding whose text is the file's own name
# (the `engine` rule) is keyed without the name, so that a renamed file holds the same finding (review 4, #8).
gate_finding_keys <- function(df) {
  txt <- ifelse(!is.na(df$text) & df$text == df$file, "\002file", gate_ws(df$text))
  paste(df$rule, txt, sep = "\001")
}

# the diff of a document between two blobs (G16, N134), cached per blob pair: the lines added, with the
# attribute `deleted`
gate_diff_lines <- function(g, pb, nb) {
  k <- paste(pb, nb)
  if (is.null(g$added[[k]])) g$added[[k]] <- git_added_lines(g$top, pb, nb)
  g$added[[k]]
}

# the lines of a document added since HEAD (G16)
gate_added_lines <- function(g, p, rel) {
  nb <- p$new$docs$blob[match(rel, p$new$docs$rel)]
  d <- p$parents[[1L]]$docs
  pb <- d$blob[match(rel, d$rel)]
  gate_diff_lines(g, pb, nb)
}

# ---- checks gone (F9: N133 to N140) ---------------------------------------------------------------------------

gate_checks_empty <- function() {
  out <- data.frame(project = character(), file = character(), line = integer(), cond = character(),
                    level = character(), verdict = character(), by = character(), by_line = integer(),
                    remains = character(), stringsAsFactors = FALSE)
  attr(out, "text") <- character()
  out
}

# the key a check is counted by (N133): its `key`, or for a check that is not readable its text and level
gate_check_keys <- function(d) {
  ifelse(is.na(d$key), paste0("\001", gate_ws(d$text), "\002", d$level), d$key)
}

# what the other operand of a check is, for E83 and E85
gate_other_desc <- function(b) {
  k <- ck_kind(b$other, b$op)
  switch(sub(" .*$", "", k), value = ck_cut(b$other), number = "a number", date = "a date", string = "a string",
         bool = "TRUE or FALSE", quantity = paste("a quantity in", sub("^quantity ", "", k)), k)
}

# the first name of a check's text that the document rebinds (N125)
gate_first_rebound <- function(text, names) {
  tok <- regmatches(text, gregexpr("(?<![A-Za-z0-9._$@:])[A-Za-z.][A-Za-z0-9._]*", text, perl = TRUE))[[1L]]
  hit <- tok[tok %in% names]
  if (length(hit)) hit[[1L]] else if (length(names)) names[[1L]] else ""
}

# E83's list (N136): the checks on the pair that run always, none implied by another, at most three
gate_remains_text <- function(pair) {
  cand <- pair[pair$always %in% TRUE, , drop = FALSE]
  if (!nrow(cand)) return(NA_character_)
  first <- !duplicated(cand$key)
  g <- cand[first, , drop = FALSE]
  cnt <- vapply(g$key, function(k) sum(cand$key == k), 1L)
  keep <- vapply(seq_len(nrow(g)), function(i) {
    !any(vapply(seq_len(nrow(g))[-i], function(j) check_implies(g[j, , drop = FALSE], g[i, , drop = FALSE]), NA))
  }, NA)
  g <- g[keep, , drop = FALSE]
  cnt <- cnt[keep]
  if (!nrow(g)) return(NA_character_)
  items <- sprintf("`%s` (%s)", g$cond, ifelse(cnt == 1L, sprintf("line %d", g$line), sprintf("%d places", cnt)))
  paste0(paste(items[seq_len(min(3L, length(items)))], collapse = ", "),
         if (length(items) > 3L) sprintf(", and %d more", length(items) - 3L) else "")
}

# The verdict on one gone check `b` (N135): `d` the checks of its document on the new side (no branches),
# `exists` whether the document is on the new side, `rebound` its rebound names, `file` its path as shown.
gate_check_verdict <- function(b, d, exists, rebound, file) {
  res <- function(verdict, text, by = NA_character_, by_line = NA_integer_, remains = NA_character_) {
    list(verdict = verdict, text = text, by = by, by_line = by_line, remains = remains)
  }
  if (!exists) return(res("deleted", NA_character_))
  readable <- !is.na(b$cond)
  if (readable) {
    bid <- ck_pair_ids(b$value, b$op, b$other)
    pair <- d[ck_pair_ids(d$value, d$op, d$other) %in% bid, , drop = FALSE]
    pair <- pair[!is.na(pair$cond), , drop = FALSE]
    if (nrow(pair) && any(pair$rebound %in% TRUE)) {
      nm <- gate_first_rebound(b$cond, rebound)
      return(res("rebound", sprintf(paste0("not judged: `%s` is assigned in more than one place in %s, ",
                                           "so no other check is taken to cover this one"), nm, file)))
    }
  }
  cov <- ck_cover_rows(b, d)
  if (length(cov)) {
    shown <- function(i) if (is.na(d$cond[i])) d$text[i] else d$cond[i]
    same <- if (readable) cov[d$key[cov] == b$key] else cov
    if (length(same)) {
      o <- length(same) - 1L
      return(res("same", sprintf("covered: the same check remains, at line %d%s", d$line[same[1L]],
                                 if (o > 0L) sprintf(" and %d other place%s", o, if (o == 1L) "" else "s") else ""),
                 by = shown(same[1L]), by_line = d$line[same[1L]]))
    }
    return(res("implied", sprintf("covered: `%s` at line %d implies it", shown(cov[1L]), d$line[cov[1L]]),
               by = shown(cov[1L]), by_line = d$line[cov[1L]]))
  }
  if (!readable) return(res("unread", "not read: weft compares only comparisons whose sides are names, dictionary reads, value expressions or literals (rule 3.10)"))
  filt <- "filter" %in% names(b) && isTRUE(b$filter)
  imp <- which(d$always %in% TRUE & !(d$rebound %in% TRUE) & !is.na(d$cond) &
                 vapply(seq_len(nrow(d)), function(i) check_implies(d[i, , drop = FALSE], b, filter = filt), NA))
  if (length(imp)) {
    return(res("warned", sprintf("looser: only a warned check implies it, `%s` at line %d, and a warned check fails nothing",
                                 d$cond[imp[1L]], d$line[imp[1L]])))
  }
  if (nrow(pair)) {
    rem <- gate_remains_text(pair)
    return(res("looser", sprintf("looser: nothing that remains implies it; remaining on %s against %s: %s", ck_cut(b$value),
                                 gate_other_desc(b), rem), remains = rem))
  }
  res("none", sprintf("looser: no check of %s against %s remains in %s", ck_cut(b$value), gate_other_desc(b), file))
}

# The checks gone in one project and what still checks each (N133 to N136); information only (N139).
gate_judge_checks <- function(g, p, new_res, base_res) {
  nw <- new_res$checks
  bases <- lapply(base_res, `[[`, "checks")
  if (is.null(nw) || !length(bases) || any(vapply(bases, is.null, NA))) return(gate_checks_empty())
  strip <- function(d) {
    d <- d[d$role != "branch", , drop = FALSE]
    d$gk <- gate_check_keys(d)
    d
  }
  nw <- strip(nw)
  bs <- lapply(bases, strip)
  cn <- count_keys(nw$gk)
  cts <- lapply(bs, function(b) count_keys(b$gk))
  keys <- Reduce(intersect, lapply(cts, names))
  if (!length(keys)) return(gate_checks_empty())
  rows <- list()
  new_rels <- p$new$docs$rel
  top_path <- function(rel) if (nzchar(p$prefix)) paste0(p$prefix, "/", rel) else rel
  for (k in keys) {
    counts <- vapply(cts, function(ct) as.integer(ct[[k]]), 1L)
    have <- if (k %in% names(cn)) cn[[k]] else 0L
    k_gone <- min(counts) - have
    if (k_gone <= 0L) next
    pi <- which.min(counts)
    b <- bs[[pi]]
    i <- which(b$gk == k)
    i <- i[order(enc2utf8(b$file[i]), b$line[i], method = "radix")]
    pdocs <- p$parents[[pi]]$docs
    on_del <- vapply(i, function(r) {
      rel <- b$file[r]
      nb <- p$new$docs$blob[match(rel, new_rels)]
      pb <- pdocs$blob[match(rel, pdocs$rel)]
      if (is.na(nb)) return(TRUE)
      if (identical(nb, pb)) return(FALSE)
      del <- attr(gate_diff_lines(g, pb, nb), "deleted")
      isTRUE(del) || b$line[r] %in% del
    }, NA)
    pick <- utils::tail(i[on_del], k_gone)
    if (length(pick) < k_gone) pick <- c(pick, utils::tail(i[!(i %in% pick)], k_gone - length(pick)))
    for (r in pick) rows[[length(rows) + 1L]] <- list(pi = pi, row = b[r, , drop = FALSE])
  }
  if (!length(rows)) return(gate_checks_empty())
  out <- vector("list", length(rows))
  for (q in seq_along(rows)) {
    b <- rows[[q]]$row
    rel <- b$file
    ex <- rel %in% new_rels
    d <- nw[nw$file == rel, , drop = FALSE]
    v <- gate_check_verdict(b, d, ex, as.character(attr(new_res$checks, "rebound")[[rel]]), top_path(rel))
    out[[q]] <- list(file = top_path(rel), line = b$line, cond = ck_cut(if (is.na(b$cond)) gate_ws(b$text) else b$cond, 70L),
                     level = b$level, v = v)
  }
  df <- data.frame(project = rep(p$display, length(out)), file = vapply(out, `[[`, "", "file"),
                   line = as.integer(vapply(out, `[[`, 1L, "line")), cond = vapply(out, `[[`, "", "cond"),
                   level = vapply(out, `[[`, "", "level"), verdict = vapply(out, function(o) o$v$verdict, ""),
                   by = vapply(out, function(o) o$v$by, ""), by_line = as.integer(vapply(out, function(o) o$v$by_line, 1L)),
                   remains = vapply(out, function(o) o$v$remains, ""), stringsAsFactors = FALSE)
  txt <- vapply(out, function(o) o$v$text, "")
  gone <- df$verdict == "deleted"
  for (f in unique(df$file[gone])) {
    n <- sum(gone & df$file == f)
    txt[gone & df$file == f] <- sprintf("the document is gone, and its %d check%s with it", n, if (n == 1L) "" else "s")
  }
  o <- order(enc2utf8(df$file), df$line, method = "radix")
  df <- df[o, , drop = FALSE]
  rownames(df) <- NULL
  attr(df, "text") <- txt[o]
  df
}

# ---- the result and its report (G19, G20) -----------------------------------------------------------------------

as_weft_findings <- function(df) {
  if (!nrow(df)) return(new_findings())
  df <- df[order(enc2utf8(df$file), df$line, df$col, df$rule, method = "radix"), FINDING_COLS, drop = FALSE]
  rownames(df) <- NULL
  structure(df, class = c("weft_findings", "data.frame"), notes = character())
}

gate_assemble <- function(g, parts, tr) {
  pick <- function(nm, empty) {
    x <- Filter(Negate(is.null), lapply(parts, `[[`, nm))
    x <- Filter(function(d) nrow(d) > 0L, x)
    if (!length(x)) return(empty)
    do.call(rbind, x)
  }
  errors <- pick("errors", empty_plain_findings())
  added <- pick("added", empty_plain_findings())
  excess <- pick("excess", data.frame(project = character(), rule = character(), text = character(),
                                      base = integer(), new = integer(), stringsAsFactors = FALSE))
  removed <- pick("removed", data.frame(project = character(), file = character(), line = integer(),
                                        kind = character(), text = character(), stringsAsFactors = FALSE))
  if (nrow(excess)) {
    excess <- excess[order(excess$project, excess$rule, excess$text, method = "radix"), , drop = FALSE]
    rownames(excess) <- NULL
  }
  if (nrow(removed)) {
    removed <- removed[order(removed$project, enc2utf8(removed$file), removed$line, method = "radix"), , drop = FALSE]
    rownames(removed) <- NULL
  }
  cks <- Filter(function(d) !is.null(d) && nrow(d) > 0L, lapply(parts, `[[`, "checks"))
  checks <- gate_checks_empty()
  if (length(cks)) {
    txt <- unlist(lapply(cks, function(d) attr(d, "text")), use.names = FALSE)
    checks <- do.call(rbind, cks)
    o <- order(checks$project, enc2utf8(checks$file), checks$line, method = "radix")
    checks <- checks[o, , drop = FALSE]
    rownames(checks) <- NULL
    attr(checks, "text") <- txt[o]
  }
  n <- sum(vapply(parts, function(p) as.integer(p$n), 1L))
  n <- as.integer(n)
  trailer <- tr$number
  ok <- !nrow(errors) && !nrow(excess) && (n == 0L || isTRUE(trailer == n))
  changed <- as.character(unique(unlist(lapply(parts, `[[`, "changed"))))
  res <- list(ok = ok, errors = as_weft_findings(errors), added = as_weft_findings(added), excess = excess,
              removed = removed, n_removed = n, trailer = trailer,
              changed = sort(changed, method = "radix"),
              notes = character(), seconds = 0, checks = checks)
  attr(res, "trailer_value") <- tr$value
  res
}

gate_finding_lines <- function(df) {
  out <- character()
  df <- as.data.frame(unclass(df), stringsAsFactors = FALSE)
  df <- df[order(enc2utf8(df$file), df$line, method = "radix"), , drop = FALSE]
  for (f in unique(df$file)) {
    out <- c(out, paste0("  ", f))
    d <- df[df$file == f, , drop = FALSE]
    for (i in seq_len(nrow(d))) {
      head <- sprintf("    %5d  %s  ", d$line[i], d$rule[i])
      out <- c(out, paste0(head, d$message[i]))
      if (!is.na(d$hint[i])) out <- c(out, paste0(strrep(" ", nchar(head)), d$hint[i]))
    }
  }
  out
}

gate_report_lines <- function(x) {
  plural <- function(k, w, ws = paste0(w, "s")) paste(k, if (k == 1L) w else ws)
  secs <- sprintf("%.1f", x$seconds)
  lines <- character()
  ne <- nrow(x$errors)
  if (ne) {
    lines <- c(lines, sprintf("commit-msg: %s", plural(ne, "construct error")), gate_finding_lines(x$errors), "")
  }
  if (nrow(x$added)) {
    n <- sum(x$excess$new - x$excess$base)
    lines <- c(lines, sprintf("commit-msg: %s that HEAD did not hold", paste(n, if (n == 1L) "finding added" else "findings added")),
               gate_finding_lines(x$added), "")
  }
  tv <- attr(x, "trailer_value")
  if (x$n_removed > 0L && !isTRUE(x$trailer == x$n_removed)) {
    n <- x$n_removed
    says <- if (is.null(tv) || is.na(tv)) "does not say so" else paste0("says Weft-Removed: ", tv)
    lines <- c(lines, sprintf("commit-msg: %s removed, and the message %s",
                              plural(n, "weft construct"), says), "")
    r <- x$removed
    for (f in unique(r$file)) {
      d <- r[r$file == f, , drop = FALSE]
      txt <- ifelse(nchar(d$text) > 70L, paste0(substr(d$text, 1L, 67L), "..."), d$text)
      lines <- c(lines, paste0("  ", f, ", as in HEAD"), sprintf("    %5d  %s", d$line, txt), "")
    }
    lines <- c(lines,
               if (is.null(tv) || is.na(tv)) {
                 c("  If the removal is intended, add this line at the end of the commit",
                   "  message, after a blank line:")
               } else {
                 "  Change that line to:"
               },
               "", sprintf("      Weft-Removed: %d", n), "",
               sprintf("  or commit with: git commit --trailer \"Weft-Removed: %d\"", n), "")
  }
  ck <- x$checks
  if (!is.null(ck) && nrow(ck) && !x$ok) lines <- c(lines, gate_check_block(ck))
  notes <- if (length(x$notes)) paste0("commit-msg: note: ", x$notes) else character()
  if (x$ok) {
    k <- length(x$changed)
    return(c(notes, gate_check_notes(ck), sprintf("commit-msg: weft passed (%s, %s s)", plural(k, "changed file"), secs)))
  }
  c(lines, notes, sprintf("commit-msg: %s s", secs))
}

# The block of checks gone (E80, N137): per file, each gone check and what covers it.
gate_check_block <- function(ck) {
  txt <- attr(ck, "text")
  n <- nrow(ck)
  out <- sprintf("commit-msg: %s gone since HEAD (information: what still checks each; rule 6.3.7)",
                 if (n == 1L) "1 check" else paste(n, "checks"))
  for (f in unique(ck$file)) {
    i <- which(ck$file == f)
    out <- c(out, paste0("  ", f, ", as in HEAD"))
    if (all(ck$verdict[i] == "deleted")) {
      out <- c(out, paste0("    ", txt[i[1L]]), "")
      next
    }
    for (j in i) out <- c(out, sprintf("    %5d  %s", ck$line[j], ck$cond[j]), paste0(strrep(" ", 11L), txt[j]))
    out <- c(out, "")
  }
  out
}

# What a passing run says of checks gone with nothing to cover them (E89, E90, N138).
gate_check_notes <- function(ck) {
  if (is.null(ck) || !nrow(ck)) return(character())
  i <- which(ck$verdict %in% c("rebound", "warned", "looser", "none"))
  if (!length(i)) return(character())
  first <- i[seq_len(min(5L, length(i)))]
  out <- sprintf("commit-msg: note: %s:%d in HEAD, `%s`, is gone and nothing that remains covers it (rule 6.3.7)",
                 ck$file[first], ck$line[first], ck$cond[first])
  rest <- length(i) - length(first)
  if (rest > 0L) {
    out <- c(out, sprintf("commit-msg: note: and %d more check%s gone with nothing that remains covering %s; gate() lists them in `checks`",
                          rest, if (rest == 1L) "" else "s", if (rest == 1L) "it" else "them"))
  }
  out
}
