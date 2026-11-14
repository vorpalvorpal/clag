# verify(): the full check of a project before release (design-4 G23-G29, G32).
#
# Four parts, in order, each switchable off: `lints` (the static lints over the whole
# project, the comparison with a commit), `decisions` (the pointers of dict.yml), `render`
# (R/verify-render.R) and `ledger`. Nothing is written outside the project, git is only read.

verify_abort <- function(message, ...) weft_abort(message, "weft_verify_error", ...)

#' Check a project before release
#'
#' `verify()` is the full check of a project (rule 8.1). It runs the static lints over
#' the whole project, compares their findings with a commit, checks the pointers of
#' `dict.yml`, renders the documents with Quarto (or knits them, under rmarkdown) with the
#' `_freeze` folder backed up and restored whatever happens, reads the stamp each render
#' writes to see that every check ran and passed, checks that no ledger is stale, and prints a
#' report with a verdict. When it fails it signals a `weft_verify_error`, so that
#' `Rscript -e 'weft::verify()'` exits 1.
#'
#' A part is skipped when it is named in `verify_skip` in `_weft.yml` (`lints`,
#' `decisions`, `render`, `ledger`), and the render and ledger parts are skipped by
#' `static = TRUE`. `verify()` does not run in draft mode (rule 8.1.5).
#'
#' @param files `NULL` (every document of the project), or documents to verify (relative to
#'   the project root, or absolute under it). Only these are rendered, stamped, judged for
#'   ledgers and listed; the rules that read across files still read the whole project.
#' @param since `NULL` (the commit `HEAD`, when there is one) or one string naming a commit.
#' @param static `TRUE` to run the static parts only: no render, no ledger.
#' @param path A file or folder inside the project.
#' @return A `weft_verify`, invisibly, when the check passed: a list with `ok`, `parts`
#'   (`part`, `status`, `detail`), `errors`, `added`, `strict`, `names`, `tier2` (each a
#'   `weft_findings`), `removed`, `decisions`, `knit`, `output` (the rendered-output findings: `file`, `format`, `kind`, `level`, `section`, `text`, `excerpt`; each `fail` row is a reason, `warn` rows are listed), `unexecuted`, `unfresh`, `stale`, `tolerated`,
#'   `log`, `notes` and `seconds`. The report is printed to stderr with [message()].
#' @export
verify <- function(files = NULL, since = NULL, static = FALSE, path = ".") {
  t0 <- proc.time()[["elapsed"]]
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    verify_abort("`path` must be one existing file or folder (rule 8.1.1).")
  }
  if (!is.null(files) && (!is.character(files) || !length(files) || anyNA(files) || any(!nzchar(files)))) {
    verify_abort("`files` must be NULL or the paths of documents (rule 8.1.1).")
  }
  if (!is.null(since) && (!is.character(since) || length(since) != 1L || is.na(since) || !nzchar(since))) {
    verify_abort("`since` must be NULL or one string naming a commit (rule 8.1.1).")
  }
  if (!is.logical(static) || length(static) != 1L || is.na(static)) {
    verify_abort("`static` must be TRUE or FALSE (rule 8.1.1).")
  }
  root <- normalizePath(find_project_root(path), winslash = "/", mustWork = FALSE)

  # draft mode first (G24)
  refuse <- function(clause) {
    verify_abort(sprintf(paste0("verify() does not run in draft mode (rule 8.1.5): %s. ",
                                "A draft render fails nothing, so it can verify nothing."), clause))
  }
  if (tolower(Sys.getenv("WEFT_DRAFT")) %in% c("1", "true")) refuse("WEFT_DRAFT is set")
  has_file <- file.exists(file.path(root, "_weft.yml"))
  cfg <- verify_config(root, has_file)
  if (isTRUE(cfg$draft)) {
    refuse(if (has_file) "draft is on in _weft.yml" else "draft is on in the document's weft: front matter")
  }
  verify_version_warning(root)

  # the documents verified
  docs <- lint_files_under(root)
  all_docs <- docs
  files_rel <- NULL
  if (!is.null(files)) {
    absf <- ifelse(grepl("^(/|[A-Za-z]:)", files), files, file.path(root, files))
    nf <- normalizePath(absf, winslash = "/", mustWork = FALSE)
    prob <- !file.exists(absf) | dir.exists(absf) | !startsWith(nf, paste0(root, "/")) |
      !grepl("\\.(qmd|Rmd|rmd)$", files)
    if (any(prob)) {
      verify_abort(paste0("`files` must name existing .qmd or .Rmd documents under the project root; not so: ",
                          paste0("`", files[prob], "`", collapse = ", "), " (rule 8.1.1)."))
    }
    files_rel <- unique(substring(nf, nchar(root) + 2L))
    docs <- files_rel
  }

  skip <- as.character(unlist(cfg$verify_skip))
  why <- function(part) {
    if (part %in% skip) {
      "verify_skip in _weft.yml"
    } else if (part %in% c("render", "ledger") && static) {
      "static = TRUE"
    } else if (part == "ledger" && !isTRUE(cfg$ledger)) {
      "ledger: false in _weft.yml"
    } else {
      NA_character_
    }
  }
  if (is.na(why("render")) && !has_file) {
    verify_abort(sprintf("verify() renders and reads the stamps of a set-up project; %s has no _weft.yml (rule 9.3.2).", root))
  }

  # git: the commit to compare with (G23)
  gi <- verify_git(root)
  since_sha <- NA_character_
  notes <- character()
  if (!is.null(since)) {
    if (is.null(gi)) verify_abort("`since` was given, but the project is not in a git work tree (rule 8.2.2).")
    if (grepl("^-", since)) verify_abort(sprintf("`since` must name a commit; `%s` does not (rule 8.2.2).", since))
    r <- git_raw(gi$top, c("rev-parse", "-q", "--verify", paste0(since, "^{commit}")))
    if (!identical(r$status, 0L)) verify_abort(sprintf("`since` must name a commit; `%s` is not one (rule 8.2.2).", since))
    since_sha <- trimws(raw_lines(r$out)[1L])
  } else if (!is.null(gi)) {
    since_sha <- git_head(gi$top)
  }
  have_base <- !is.na(since_sha)
  if (!have_base) {
    notes <- c(notes, "no commit to compare with: findings are counted, not compared (rule 8.2.2)")
  }

  parts <- data.frame(part = VERIFY_PARTS, status = "skipped", detail = "", stringsAsFactors = FALSE)
  set_part <- function(part, status, detail) {
    parts$status[parts$part == part] <<- status
    parts$detail[parts$part == part] <<- detail
  }
  res <- list(errors = as_weft_findings(empty_plain_findings()), added = as_weft_findings(empty_plain_findings()),
              strict = as_weft_findings(empty_plain_findings()), names = as_weft_findings(empty_plain_findings()),
              removed = construct_empty(), tier2 = as_weft_findings(empty_plain_findings()),
              decisions = verify_empty_decisions(), decision_error = NULL,
              knit = failures_frame_empty(), output = verify_empty_output(), unexecuted = character(),
              unfresh = character(), log = character(),
              stale = verify_empty_stale(), tolerated = data.frame(rule = character(), n = integer(),
                                                                   stringsAsFactors = FALSE))
  reasons <- 0L

  # 1. lints
  if (!is.na(why("lints"))) {
    set_part("lints", "skipped", paste0("skipped: ", why("lints")))
  } else {
    li <- verify_lints(root, files_rel, cfg, gi, since_sha, have_base, docs)
    res[names(li$res)] <- li$res
    notes <- c(notes, li$notes)
    n <- nrow(res$errors) + li$added_n + nrow(res$strict) + nrow(res$names)
    reasons <- reasons + n
    set_part("lints", if (n) "failed" else "ran", li$detail)
  }

  # 2. decisions
  if (!is.na(why("decisions"))) {
    set_part("decisions", "skipped", paste0("skipped: ", why("decisions")))
  } else {
    dp <- verify_document_pointers(root, docs)
    if (!file.exists(file.path(root, "dict.yml")) && !nrow(dp)) {
      set_part("decisions", "skipped", "skipped: no decision pointers")
    } else {
      d <- verify_decisions(root, cfg, dp)
      res$decisions <- d$table
      res$decision_error <- d$error
      n <- sum(d$table$resolved %in% FALSE) + length(d$error)
      reasons <- reasons + n
      set_part("decisions", if (n) "failed" else "ran", d$detail)
    }
  }

  # 3. render
  if (!is.na(why("render"))) {
    set_part("render", "skipped", paste0("skipped: ", why("render")))
  } else if (!length(docs)) {
    set_part("render", "skipped", "skipped: no documents")
  } else {
    rr <- verify_render(root, docs, files_rel, cfg, all_docs)
    notes <- c(notes, rr$notes)
    res$knit <- rr$knit
    res$output <- rr$output
    res$unexecuted <- rr$unexecuted
    res$unfresh <- rr$unfresh
    res$log <- rr$log
    n <- nrow(rr$knit) + sum(rr$output$level == "fail") + length(rr$unexecuted) + length(rr$unfresh) + (rr$status != 0L)
    reasons <- reasons + n
    set_part("render", if (n) "failed" else "ran", rr$detail)
  }

  # 4. ledger
  if (!is.na(why("ledger"))) {
    set_part("ledger", "skipped", paste0("skipped: ", why("ledger")))
    if (identical(why("ledger"), "ledger: false in _weft.yml")) {
      notes <- c(notes, "ledger: false in _weft.yml, so no ledger is kept and none is checked (rule 7.2.3)")
    }
  } else {
    lg <- verify_ledgers(root, docs)
    res$stale <- lg$stale
    notes <- c(notes, lg$notes)
    n <- length(unique(paste(lg$stale$ledger, lg$stale$output)))
    reasons <- reasons + n
    set_part("ledger", if (n) "failed" else "ran", lg$detail)
  }

  out <- c(list(ok = reasons == 0L, parts = parts), res[c("errors", "added", "strict", "names", "removed", "tier2",
                                                          "decisions", "decision_error", "knit", "output", "unexecuted",
                                                          "unfresh", "stale", "tolerated", "log")],
           list(notes = unique(notes), since = if (have_base) since_sha else NA_character_,
                seconds = proc.time()[["elapsed"]] - t0))
  out <- out[c("ok", "parts", "errors", "added", "strict", "names", "removed", "tier2", "decisions", "decision_error",
               "knit", "output", "unexecuted", "unfresh", "stale", "tolerated", "log", "notes", "since", "seconds")]
  class(out) <- "weft_verify"
  message(paste(verify_report_lines(out), collapse = "\n"))
  if (out$ok) return(invisible(out))
  verify_abort(sprintf("verify() failed: %d reason(s); the report is above (rule 8.1.1).", reasons), result = out)
}

#' @param x A `weft_verify`.
#' @param ... Not used.
#' @rdname verify
#' @export
print.weft_verify <- function(x, ...) {
  message(paste(verify_report_lines(x), collapse = "\n"))
  invisible(x)
}

# ---- configuration and version --------------------------------------------------------------

# The settings of the project; a lone document with no _weft.yml brings its own `weft:` front matter
# (rule 9.1.4). The session's units are left as they were.
verify_config <- function(root, has_file) {
  front <- list()
  if (!has_file) {
    d <- lint_files_under(root)
    if (length(d) == 1L) front <- doc_front(file.path(root, d))
  }
  # read as YAML only: read_config() installs the unit tables and writes the units cache in the user's
  # cache folder (review 4, #3), and verify() has no use for units
  cfg <- lint_config(root, front)
  validate_verify_config(cfg)
  for (nm in c("draft", "ledger")) {
    v <- cfg[[nm]]
    if (!is.logical(v) || length(v) != 1L || is.na(v)) {
      weft_abort(sprintf("The setting `%s` must be TRUE or FALSE.", nm), "weft_config_error")
    }
  }
  decisions_route(cfg$decisions)
  cfg
}

verify_version_warning <- function(root) {
  rec <- recorded_version(root)
  now <- weft_version_string()
  if (is.na(rec) || identical(rec, now)) return(invisible())
  msg <- if (record_is_newer(rec, now)) {
    sprintf(paste0("This project records weft %s in _weft.yml, and weft %s is installed, older than the %s ",
                   "this project records. Update weft, or run weft::use_weft() to take the project back to %s ",
                   "(rule 9.5.4)."), rec, now, rec, now)
  } else {
    sprintf(paste0("This project records weft %s in _weft.yml, and weft %s is installed. ",
                   "Run weft::use_weft() to update the files weft installed and the record (rule 9.5.4)."),
            rec, now)
  }
  weft_warn(msg, class = c("weft_version_warning", "weft_warning"))
  invisible()
}

# Does the project record a weft newer than the installed one? (then use_weft() is a downgrade)
record_is_newer <- function(rec, now = weft_version_string()) {
  !is.na(rec) && !is.na(now) && utils::compareVersion(rec, now) > 0L
}

# ---- git ----------------------------------------------------------------------------------------

# The work tree the project is in: list(top, gitdir, common, prefix), or NULL
verify_git <- function(root) {
  tryCatch({
    w <- git_where(root)
    r <- git_raw(root, c("rev-parse", "--show-prefix"))
    pre <- if (identical(r$status, 0L)) raw_lines(r$out) else character()
    w$prefix <- if (length(pre)) sub("/$", "", pre[1L]) else ""
    w
  }, error = function(e) NULL)
}

# The lines of a document added since a commit: TRUE for every line, or the line numbers.
verify_added_lines <- function(gi, since, rel, in_base) {
  if (!in_base) return(TRUE)
  p <- if (nzchar(gi$prefix)) paste0(gi$prefix, "/", rel) else rel
  r <- git_raw(gi$top, c("diff", "-U0", "--no-color", "--no-ext-diff", since, "--", p))
  if (!identical(r$status, 0L) && !identical(r$status, 1L)) return(TRUE)
  ln <- raw_lines(r$out)
  h <- regmatches(ln, regexec("^@@ -[0-9]+(?:,[0-9]+)? \\+([0-9]+)(?:,([0-9]+))? @@", ln, perl = TRUE))
  h <- Filter(length, h)
  if (!length(h)) return(integer())
  unlist(lapply(h, function(m) {
    c0 <- as.integer(m[2L])
    d <- if (nzchar(m[3L])) as.integer(m[3L]) else 1L
    if (d == 0L) integer() else seq.int(c0, c0 + d - 1L)
  }))
}

# ---- the lints part (G24.1) -------------------------------------------------------------------------

verify_empty_decisions <- function() {
  data.frame(file = character(), line = integer(), key = character(), decision = character(),
             resolved = logical(), detail = character(), stringsAsFactors = FALSE)
}

verify_empty_stale <- function() {
  data.frame(ledger = character(), output = character(), reason = character(), stringsAsFactors = FALSE)
}

verify_lints <- function(root, files_rel, cfg, gi, since_sha, have_base, docs) {
  notes <- character()
  all <- lints(root, tier = 1:2)
  notes <- c(notes, attr(all, "notes"))
  df <- plain_findings(all)
  tab <- lint_rule_table()
  scope <- tab$scope[match(df$rule, tab$id)]
  if (!is.null(files_rel)) df <- df[scope != "file" | df$file %in% files_rel, , drop = FALSE]
  tier1 <- df[df$tier == 1L, , drop = FALSE]
  tier2 <- df[df$tier == 2L, , drop = FALSE]
  err <- tier1$rule %in% GATE_CONSTRUCT_RULES
  tar <- tier1$rule == "tar-name"
  errors <- tier1[err, , drop = FALSE]
  names_f <- tier1[tar, , drop = FALSE]
  rest <- tier1[!err & !tar, , drop = FALSE]
  st <- as.character(unlist(cfg$strict))
  is_strict <- rest$rule %in% st
  strict <- rest[is_strict, , drop = FALSE]
  tol <- rest[!is_strict, , drop = FALSE]

  tolerated <- data.frame(rule = character(), n = integer(), stringsAsFactors = FALSE)
  if (nrow(rest)) {
    tb <- table(rest$rule[!is_strict])
    if (length(tb)) {
      nm <- sort(names(tb), method = "radix")
      tolerated <- data.frame(rule = nm, n = as.integer(tb[nm]), stringsAsFactors = FALSE)
    }
  }

  added <- empty_plain_findings()
  added_n <- 0L
  removed <- construct_empty()
  base <- NULL
  # the constructs the commit held and the work tree no longer does (8.2.2): listed, not judged
  removed_of <- function(base) {
    rows <- lapply(docs, function(rel) {
      tryCatch({
        src <- lint_open(root, rel)
        if (isTRUE(src$invalid)) construct_empty() else working_constructs(src)
      }, error = function(e) construct_empty())
    })
    constructs_removed(list(base$constructs), bind_plain(rows, construct_empty()))$rows
  }
  if (have_base && !is.null(gi)) {
    if (file.exists(file.path(root, "_weft.yml")) && !verify_weft_at(gi, since_sha)) {
      # the project did not exist at `since`: that commit is the baseline (design question 5)
      notes <- c(notes, sprintf(paste0("_weft.yml is not in %s: that commit is the baseline for this project, ",
                                       "so nothing counts as added (rule 8.2.2)"), substr(since_sha, 1L, 7L)))
    } else {
      base <- verify_base_side(gi, since_sha, files_rel)
    }
    if (!is.null(base) && !is.null(base$error)) {
      notes <- c(notes, sprintf("_weft.yml did not read at %s (%s); findings are not compared",
                                substr(since_sha, 1L, 7L), gsub("\n", " ", base$error)))
      if (!is.null(base$constructs)) removed <- removed_of(base)
      base <- NULL
    }
  }
  if (!is.null(base)) {
    bf <- base$findings[!(base$findings$rule %in% GATE_CONSTRUCT_RULES), , drop = FALSE]
    fe <- findings_excess(tol, list(bf), function(rel) verify_added_lines(gi, since_sha, rel, rel %in% base$docs))
    added <- fe$added
    added_n <- fe$n
    removed <- removed_of(base)
  }
  if (have_base && !is.null(gi) && is.null(base)) {
    # no baseline holding _weft.yml: there is no "added" to judge against, and listing every finding as
    # added would bury the report (as changes() and the gate, this case judges nothing)
    tier2 <- tier2[0L, , drop = FALSE]
    notes <- c(notes, "tier 2 was not judged: no baseline commit holds _weft.yml, so no line counts as added")
  }
  if (nrow(tier2)) {
    add_for <- list()
    for (f in unique(tier2$file)) {
      add_for[[f]] <- if (is.null(base)) TRUE else
        verify_added_lines(gi, since_sha, f, f %in% base$docs)
    }
    keep <- vapply(seq_len(nrow(tier2)), function(i) {
      a <- add_for[[tier2$file[i]]]
      isTRUE(a) || any(a >= tier2$line[i] & a <= tier2$end_line[i])
    }, NA)
    tier2 <- tier2[keep, , drop = FALSE]
  }
  nlist <- list(errors = errors, added = added, strict = strict, names = names_f, tier2 = tier2)
  r <- lapply(nlist, as_weft_findings)
  r$removed <- removed
  r$tolerated <- tolerated
  detail <- sprintf("%d construct error%s, %d added, %d tolerated", nrow(errors), if (nrow(errors) == 1L) "" else "s",
                    added_n + nrow(strict) + nrow(names_f), sum(tolerated$n))
  if (!nrow(errors) && !added_n && !nrow(strict) && !nrow(names_f)) {
    detail <- sprintf("%d tolerated finding%s", sum(tolerated$n), if (sum(tolerated$n) == 1L) "" else "s")
  }
  list(res = r, notes = notes, detail = detail, added_n = added_n)
}

# Does the commit hold the project's `_weft.yml`?
verify_weft_at <- function(gi, since_sha) {
  p <- if (nzchar(gi$prefix)) paste0(gi$prefix, "/_weft.yml") else "_weft.yml"
  identical(git_raw(gi$top, c("cat-file", "-e", paste0(since_sha, ":", p)))$status, 0L)
}

# What the commit held: its tier-1 findings and constructs, through the gate's reader and cache.
verify_base_side <- function(gi, since_sha, files_rel) {
  g <- gate_state(gi)
  ent <- git_entries_commit(gi$top, since_sha)
  s <- gate_side_entries(g, ent, gi$prefix)
  p <- list(prefix = gi$prefix, display = if (nzchar(gi$prefix)) gi$prefix else ".")
  gate_sizes(g, list(list(new = s, parents = list())))
  s <- gate_side_keys(g, s, gate_versions())
  r <- gate_side_results(g, s, p, gate_rule_ids())
  cache_prune(g$cache)
  r$docs <- s$docs$rel
  r$notes <- unique(c(g$notes, g$cache$notes))
  tab <- lint_rule_table()
  if (!is.null(files_rel)) {
    if (!is.null(r$constructs)) r$constructs <- r$constructs[r$constructs$file %in% files_rel, , drop = FALSE]
    if (is.null(r$error)) {
      sc <- tab$scope[match(r$findings$rule, tab$id)]
      r$findings <- r$findings[sc != "file" | r$findings$file %in% files_rel, , drop = FALSE]
    }
  }
  r
}

# ---- the decisions part (G24.2) ---------------------------------------------------------------------

# The decision pointers of the documents verified (N104): the scanner's rows on a `.weft-literal` and a
# `cite`, and each `claim()` with a literal `decision`.
verify_document_pointers <- function(root, docs) {
  rows <- lapply(docs, function(rel) {
    tryCatch(decision_pointer_rows(lint_open(root, rel)), error = function(e) NULL)
  })
  rows <- rows[!vapply(rows, is.null, NA)]
  if (!length(rows)) return(decision_pointer_rows(list(invalid = TRUE)))
  do.call(rbind, rows)
}

verify_decisions <- function(root, cfg, doc_pointers = verify_document_pointers(root, character())) {
  f <- file.path(root, "dict.yml")
  tb <- verify_empty_decisions()[, c("file", "line", "key", "decision")]
  if (file.exists(f)) {
    dict <- tryCatch(read_dict(f), error = function(e) e)
    if (inherits(dict, "error")) {
      return(list(table = verify_empty_decisions(), error = conditionMessage(dict),
                  detail = "dict.yml does not read"))
    }
    e <- attr(dict, "entries")
    has <- !is.na(e$decision)
    tb <- data.frame(file = rep(as.character(attr(dict, "file")), sum(has)), line = as.integer(e$line[has]),
                     key = e$key[has], decision = e$decision[has], stringsAsFactors = FALSE)
  }
  tb <- rbind(tb, doc_pointers[, c("file", "line", "key", "decision")])
  tb$resolved <- rep(NA, nrow(tb))
  tb$detail <- rep("", nrow(tb))
  if (nrow(tb)) {
    tb <- tryCatch({
      route <- decisions_route(cfg$decisions)
      decisions_resolve(tb, route, root)
    }, error = function(e) e)
    if (inherits(tb, "error")) {
      return(list(table = verify_empty_decisions(), error = conditionMessage(tb),
                  detail = "the pointers were not checked"))
    }
  }
  tb <- as.data.frame(tb, stringsAsFactors = FALSE)
  bad <- sum(tb$resolved %in% FALSE)
  na <- sum(is.na(tb$resolved))
  detail <- sprintf("%d pointer%s", nrow(tb), if (nrow(tb) == 1L) "" else "s")
  if (bad) detail <- paste0(detail, sprintf(", %d do not resolve", bad))
  if (na) detail <- paste0(detail, sprintf(", %d could not check", na))
  list(table = tb, error = NULL, detail = detail)
}

# ---- the ledger part (G24.4) ------------------------------------------------------------------------

verify_ledgers <- function(root, docs) {
  stale <- verify_empty_stale()
  notes <- character()
  rows <- list()
  nl <- 0L
  for (p in ledger_paths_now(root)) {
    src <- sub("^_weft/ledger/", "", dirname(p))
    if (!src %in% docs) next
    nl <- nl + 1L
    h <- tryCatch(attr(read_ledger(file.path(root, p), lenient = TRUE), "header"), error = function(e) NULL)
    if (is.null(h)) {
      notes <- c(notes, sprintf("%s did not read; its state was not checked", p))
      next
    }
    st <- ledger_state(root, h)
    notes <- c(notes, st$notes)
    if (st$stale) {
      rows[[length(rows) + 1L]] <- data.frame(ledger = src, output = sub("\\.jsonl$", "", basename(p)),
                                              reason = st$reasons, stringsAsFactors = FALSE)
    }
  }
  if (length(rows)) stale <- do.call(rbind, rows)
  nst <- length(unique(paste(stale$ledger, stale$output)))
  list(stale = stale, notes = notes,
       detail = if (nst) sprintf("%d of %d ledger%s stale", nst, nl, if (nl == 1L) "" else "s")
       else sprintf("%d ledger%s checked", nl, if (nl == 1L) "" else "s"))
}

# ---- the report (G28) ---------------------------------------------------------------------------------

verify_report_lines <- function(x) {
  short <- if (is.na(x$since)) "" else substr(x$since, 1L, 7L)
  lines <- sprintf("weft verify: %s", if (x$ok) "passed" else "failed")
  lines <- c(lines, sprintf("  %-10s %s", x$parts$part, x$parts$detail))
  if (length(x$notes)) lines <- c(lines, paste0("note: ", x$notes))
  sec <- function(head, body) if (length(body)) lines <<- c(lines, "", head, body)
  fl <- function(df) if (nrow(df)) gate_finding_lines(df) else character()
  sec("Construct errors", fl(x$errors))
  sec(sprintf("Findings added since %s", short), fl(x$added))
  sec("Strict rules", fl(x$strict))
  sec("Target names", fl(x$names))
  dec <- character()
  d <- x$decisions
  for (i in which(d$resolved %in% FALSE)) {
    dec <- c(dec, sprintf("  %s:%d  `%s` -> %s: does not resolve (%s)", basename(d$file[i]), d$line[i], d$key[i],
                          d$decision[i], d$detail[i]))
  }
  for (i in which(is.na(d$resolved))) {
    dec <- c(dec, sprintf("  %s:%d  `%s` -> %s: could not check (%s)", basename(d$file[i]), d$line[i], d$key[i],
                          d$decision[i], d$detail[i]))
  }
  if (length(x$decision_error)) dec <- c(dec, paste0("  ", gsub("\n", " ", x$decision_error)))
  sec("Decision pointers", dec)
  k <- x$knit
  kl <- character()
  for (f in unique(k$file)) {
    kl <- c(kl, paste0("  ", f))
    d <- k[k$file == f, , drop = FALSE]
    d <- d[order(d$line, method = "radix"), , drop = FALSE]
    for (i in seq_len(nrow(d))) {
      head <- sprintf("    %5s  %s  ", if (is.na(d$line[i])) "" else as.character(d$line[i]), d$kind[i])
      kl <- c(kl, paste0(head, d$detail[i]))
      if (!is.na(d$expr[i]) && nzchar(d$expr[i])) kl <- c(kl, paste0(strrep(" ", nchar(head)), d$expr[i]))
    }
  }
  sec("Knit-time failures", kl)
  o <- x$output
  ol <- character()
  for (lv in c("fail", "warn")) {
    d <- o[o$level == lv, , drop = FALSE]
    for (i in seq_len(nrow(d))) {
      ol <- c(ol, sprintf("  %s%s (%s)  [%s] %s%s", d$file[i], if (nzchar(d$section[i])) paste0(" #", d$section[i]) else "",
                          d$format[i], d$kind[i], d$text[i], if (lv == "warn") "  (warned)" else ""),
              paste0("      ", d$excerpt[i]))
    }
  }
  sec("Rendered-output findings", ol)
  sec("Not executed in this render",
      c(if (length(x$unexecuted)) sprintf("  %s: not executed in this render: served from freeze, or knit without weft active",
                                          x$unexecuted),
        if (length(x$unfresh)) sprintf("  %s: its values were not computed in this run (rule 2.13.8).", x$unfresh)))
  sec("Render log", if (length(x$log)) paste0("  ", x$log) else character())
  st <- x$stale
  sl <- character()
  for (f in unique(st$ledger)) {
    sl <- c(sl, paste0("  ", f), paste0("    ", st$reason[st$ledger == f]))
  }
  sec("Ledger: entries not re-rendered", sl)
  rm <- x$removed
  rl <- character()
  for (f in unique(rm$file)) {
    d <- rm[rm$file == f, , drop = FALSE]
    txt <- ifelse(nchar(d$text) > 70L, paste0(substr(d$text, 1L, 67L), "..."), d$text)
    rl <- c(rl, paste0("  ", f, ", as in ", short), sprintf("    %5d  %s", d$line, txt))
  }
  sec(sprintf("Constructs removed since %s (reported, not judged; rule 8.2.2)", short), rl)
  sec("Tier-2 findings on added lines", fl(x$tier2))
  if (nrow(x$tolerated)) {
    lines <- c(lines, "",
               "Tolerated findings (rule 8.1.2); make a rule strict in _weft.yml when its count is 0:",
               sprintf("  %-15s %d remain", x$tolerated$rule, x$tolerated$n))
  }
  c(lines, sprintf("weft verify: %.1f s", x$seconds))
}
