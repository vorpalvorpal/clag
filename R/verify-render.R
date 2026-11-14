# verify(): the render part (design-4 G25, G26, G30).
#
# The documents are rendered with Quarto (the `_freeze` entries of the verified documents moved
# into `.weft/freeze-backup/` for the length of the render and put back unless it exits 0), or
# knitted one by one with rmarkdown. The stamps each knit writes under `.weft/stamps/` are read for
# the run id verify() made.

# The quarto to run: QUARTO_PATH, the quarto package's, the PATH's. NA when there is none.
verify_quarto_path <- function() {
  ok <- function(p) is.character(p) && length(p) == 1L && !is.na(p) && nzchar(p) && file.exists(p)
  e <- Sys.getenv("QUARTO_PATH", "")
  if (ok(e)) return(e)
  if (requireNamespace("quarto", quietly = TRUE)) {
    q <- tryCatch(quarto::quarto_path(), error = function(e) NULL)
    if (ok(q)) return(q)
  }
  w <- unname(Sys.which("quarto"))
  if (ok(w)) w else NA_character_
}

verify_run_id <- function() sprintf("verify-%s-%d", format(Sys.time(), "%Y%m%d%H%M%S"), Sys.getpid())

# The stem of a document: its path from the root, the extension dropped.
verify_stem <- function(rel) sub("\\.[^./]*$", "", rel)

# ---- the freeze folder (G25 steps 1, 2, 4) -----------------------------------------------------------
#
# A document's entries are the files under `_freeze/<stem>/` other than a folder that holds another
# document's own stem (`chapters/c` when `chapters/c.qmd` is a document): backing up, restoring and
# deleting touch those and nothing else (review 4, #1, #2).

freeze_backup_dir <- function(root) file.path(root, ".weft", "freeze-backup")

# The entries (names directly under `base/<stem>`) that belong to the document `stem`.
freeze_items <- function(base, stem, all_stems) {
  d <- file.path(base, stem)
  if (!dir.exists(d)) return(character())
  nm <- list.files(d, all.files = TRUE, no.. = TRUE)
  other <- setdiff(all_stems, stem)
  keep <- vapply(nm, function(x) {
    if (!dir.exists(file.path(d, x))) return(TRUE)
    p <- paste0(stem, "/", x)
    !any(other == p | startsWith(other, paste0(p, "/")))
  }, NA)
  unname(nm[keep])
}

# Move a file or folder with one rename, and say whether it worked. No copy and delete as a fallback: a
# folder that cannot be removed would be emptied and left behind (the backup sits in the project, so a
# rename between drives does not arise).
freeze_move <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(to)) return(FALSE)
  isTRUE(suppressWarnings(file.rename(from, to)))
}

# The manifest of a backup: the run id (NA in older ones), the stems, and the entries listed per stem.
freeze_manifest <- function(bk) {
  rd <- function(f) if (file.exists(f)) readLines(f, warn = FALSE) else character()
  lines <- rd(file.path(bk, "manifest"))
  run <- sub("^run: ", "", lines[startsWith(lines, "run: ")])
  # `items`: one line `<stem>TAB<entry>` for each entry the run meant to move, written before it moved any
  it <- strsplit(rd(file.path(bk, "items")), "\t", fixed = TRUE)
  items <- list()
  for (x in it) if (length(x) == 2L) items[[x[1L]]] <- c(items[[x[1L]]], x[2L])
  stems <- lines[!startsWith(lines, "run: ") & nzchar(lines)]
  list(run = if (length(run)) run[1L] else NA_character_, stems = stems, items = items)
}

# Remove a folder that holds nothing (the stem folder a backup emptied).
freeze_rmdir_empty <- function(d) {
  if (dir.exists(d) && !length(list.files(d, all.files = TRUE, no.. = TRUE))) unlink(d, recursive = TRUE)
  invisible()
}

# The run id of a document's stamp, or NA when there is no stamp.
freeze_stamp_run <- function(root, stem) {
  dir <- file.path(root, ".weft", "stamps")
  if (!dir.exists(dir)) return(NA_character_)
  f <- stamp_file_name(paste0(stem, c(".qmd", ".Rmd", ".rmd")))
  f <- f[file.exists(file.path(dir, f))]
  if (!length(f)) return(NA_character_)
  s <- tryCatch(jsonlite::fromJSON(file.path(dir, f[1L]), simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(s) || is.null(s$run)) return(NA_character_)
  as.character(s$run)
}

# Put back what a backup holds, stem by stem, then delete the backup. `check_stamps`: a backup left by a
# killed run is not put back over the entry of a later complete render (the stem's stamp carries another run
# id than the manifest's, design question 3); the stem's backup is discarded and a note says so. Within a
# stem only its own entries are deleted, and an entry that the manifest lists but the backup does not hold (a
# run killed in the middle of the backup) is left where it is. Returns list(ok, notes); does nothing when
# there is no backup.
freeze_restore <- function(root, all_stems, check_stamps = FALSE) {
  bk <- freeze_backup_dir(root)
  notes <- character()
  if (!dir.exists(bk)) return(list(ok = TRUE, notes = notes))
  m <- freeze_manifest(bk)
  ex <- list.dirs(bk, full.names = FALSE, recursive = TRUE)
  ex <- ex[basename(ex) == "execute-results"]
  stems <- unique(c(m$stems, dirname(ex)))
  stems <- stems[nzchar(stems) & stems != "."]
  ok <- TRUE
  for (s in stems) {
    if (!dir.exists(file.path(bk, s))) next
    if (check_stamps && !is.na(m$run)) {
      r <- freeze_stamp_run(root, s)
      if (!is.na(r) && !identical(r, m$run)) {
        unlink(file.path(bk, s), recursive = TRUE)
        notes <- c(notes, sprintf(paste0("%s: the backup of a killed run was discarded: the document's stamp is of a ",
                                         "newer run, so its current frozen entry is kept"), s))
        next
      }
    }
    held <- freeze_items(bk, s, all_stems)
    cur <- freeze_items(file.path(root, "_freeze"), s, all_stems)
    listed <- m$items[[s]]
    unmoved <- if (is.null(listed)) character() else setdiff(listed, held)
    for (x in setdiff(cur, unmoved)) unlink(file.path(root, "_freeze", s, x), recursive = TRUE)
    for (x in held) {
      if (!freeze_move(file.path(bk, s, x), file.path(root, "_freeze", s, x))) ok <- FALSE
    }
  }
  if (ok) unlink(bk, recursive = TRUE)
  list(ok = ok, notes = notes)
}

# Move the entries of the verified documents out of `_freeze`, with a manifest of the run, the stems and the
# entries. Every move is checked: one that fails puts back what was moved and stops verify().
freeze_backup <- function(root, stems, all_stems, run) {
  bk <- freeze_backup_dir(root)
  weft_state_dir(root, "freeze-backup")
  plan <- lapply(stems, function(s) freeze_items(file.path(root, "_freeze"), s, all_stems))
  names(plan) <- stems
  write_lines_atomic(c(paste0("run: ", run), stems), file.path(bk, "manifest"))
  write_lines_atomic(unlist(lapply(stems, function(s) if (length(plan[[s]])) paste0(s, "\t", plan[[s]]))),
                     file.path(bk, "items"))
  done <- list()
  for (s in stems) {
    for (x in plan[[s]]) {
      from <- file.path(root, "_freeze", s, x)
      to <- file.path(bk, s, x)
      if (freeze_move(from, to)) {
        done[[length(done) + 1L]] <- c(from, to)
      } else {
        for (d in rev(done)) freeze_move(d[2L], d[1L])
        unlink(bk, recursive = TRUE)
        verify_abort(sprintf(paste0("verify() could not move %s out of the way before the render (is the folder ",
                                    "writable?); the _freeze entries were put back and nothing was rendered (rule 8.1.3)."),
                             file.path("_freeze", s, x)))
      }
    }
    freeze_rmdir_empty(file.path(root, "_freeze", s))
  }
  invisible()
}

# ---- running a child ----------------------------------------------------------------------------------

verify_run <- function(cmd, args, root, run, log, output_log = NULL) {
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  # Every reader takes `.weft/run` before WEFT_RUN (stage 6 ruling 17, D22), so the run is written there
  # too: a project with no pre-render script (an R Markdown one) may hold a file left by an earlier
  # render, and its knits would stamp that run. A file verify() made is removed again.
  f <- file.path(root, ".weft", "run")
  had <- file.exists(f)
  weft_state_dir(root)
  old_run <- if (had) tryCatch(readLines(f, warn = FALSE), error = function(e) character()) else character()
  write_lines_atomic(c(run, old_run[-1L]), f)
  if (!had) on.exit(unlink(f), add = TRUE)
  # set here, not through system2()'s `env =`, which Windows ignores for most commands
  ev <- c(WEFT_RUN = run)
  if (!is.null(output_log)) ev[["WEFT_OUTPUT_LOG"]] <- output_log
  st <- withr::with_envvar(ev,
                           suppressWarnings(system2(cmd, shQuote(args), stdout = log, stderr = log)))
  if (is.null(st)) 0L else as.integer(st)
}

# ---- the render ---------------------------------------------------------------------------------------

# The documents `quarto inspect` says the project renders (paths relative to the root), or NULL when it
# cannot be asked (design question 6 of review 4: the render list decides what is expected to have run).
verify_render_list <- function(q, root) {
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  out <- tryCatch(suppressWarnings(system2(q, shQuote("inspect"), stdout = TRUE, stderr = FALSE)),
                  error = function(e) NULL)
  if (is.null(out) || !is.null(attr(out, "status"))) return(NULL)
  js <- tryCatch(jsonlite::fromJSON(paste(out, collapse = "\n"), simplifyVector = FALSE), error = function(e) NULL)
  inp <- js$files$input
  if (!is.list(js) || is.null(inp)) return(NULL)
  inp <- vapply(inp, function(x) as.character(x)[1L], "")
  nf <- normalizePath(inp, winslash = "/", mustWork = FALSE)
  nf <- nf[startsWith(nf, paste0(root, "/"))]
  substring(nf, nchar(root) + 2L)
}

# Returns list(status, knit, unexecuted, log, detail, notes)
verify_render <- function(root, docs, files_rel, cfg, all_docs = docs) {
  run <- verify_run_id()
  log <- tempfile("weft-verify-", fileext = ".log")
  on.exit(unlink(log), add = TRUE)
  has_proj <- any(file.exists(file.path(root, QUARTO_MARKERS)))
  quarto_mode <- has_proj || any(grepl("\\.qmd$", docs))
  status <- 0L
  notes <- character()
  rendered <- docs
  one <- tempfile("weft-verify-doc-", fileext = ".log")
  on.exit(unlink(one), add = TRUE)
  all_log <- character()
  # N57: the rendered-output filter appends each finding to this file as a JSON line
  olog <- tempfile("weft-verify-output-", fileext = ".jsonl")
  on.exit(unlink(olog), add = TRUE)
  if (quarto_mode) {
    q <- verify_quarto_path()
    if (is.na(q)) {
      verify_abort(paste0("verify() renders with Quarto and found none. Install Quarto, or set QUARTO_PATH ",
                          "to its path (rule 8.1.1)."))
    }
    # a project is rendered whole (with the files, one `render <file>` at a time); without `_quarto.yml`
    # each document is rendered by name, for `quarto render` with no input renders nothing there
    calls <- if (has_proj && is.null(files_rel)) list(character()) else as.list(docs)
    if (has_proj && is.null(files_rel)) {
      lst <- verify_render_list(q, root)
      if (!is.null(lst)) {
        rendered <- docs[docs %in% lst]
        out <- docs[!(docs %in% lst)]
        if (length(out)) {
          notes <- sprintf("%s: not in the render list of the project, so not rendered and not expected to have run", out)
        }
      }
    }
    all_stems <- verify_stem(all_docs)
    has_freeze <- dir.exists(file.path(root, "_freeze")) || dir.exists(freeze_backup_dir(root))
    if (has_freeze) {
      rs <- freeze_restore(root, all_stems, check_stamps = TRUE)
      notes <- c(notes, rs$notes)
      if (dir.exists(file.path(root, "_freeze"))) freeze_backup(root, verify_stem(rendered), all_stems, run)
      on.exit(freeze_restore(root, all_stems), add = TRUE)
    }
    # N122: a kept kernel would serve the values of an earlier render. `.weft/run` holds this run's id before
    # the render (the pre-render script writes the same id), `--execute-daemon-restart` restarts the daemon,
    # and a julia server is ended first (measured 5).
    write_lines_atomic(run, file.path(weft_state_dir(root), "run"))
    julia <- rendered[vapply(rendered, function(rel) verify_uses_julia(root, rel), NA)]
    if (length(julia)) {
      verify_run(q, c("call", "engine", "julia", "kill"), root, run, one)
      notes <- c(notes, sprintf(paste0("%s: on the julia engine, so `quarto call engine julia kill` ended the julia ",
                                       "server before the render, to keep its values from an earlier render (rule 8.1.3)"),
                                julia))
    }
    for (cl in calls) {
      s <- verify_run(q, c("render", cl, "--execute-daemon-restart"), root, run, one, olog)
      if (file.exists(one)) all_log <- c(all_log, readLines(one, warn = FALSE))
      if (s != 0L) status <- s
    }
    writeLines(all_log, log)
    if (status == 0L) unlink(freeze_backup_dir(root), recursive = TRUE)
  } else {
    rs <- file.path(R.home("bin"), "Rscript")
    for (rel in docs) {
      expr <- sprintf("rmarkdown::render(%s, quiet = TRUE)", deparse(rel))
      s <- verify_run(rs, c("-e", expr), root, run, one, olog)
      if (file.exists(one)) all_log <- c(all_log, readLines(one, warn = FALSE))
      if (s != 0L) status <- s
    }
    writeLines(all_log, log)
  }

  # the stamps (G26)
  stamps <- verify_read_stamps(root, rendered, run)
  need <- vapply(rendered, function(rel) verify_has_constructs(root, rel), NA)
  unexec <- rendered[need & !(rendered %in% stamps$current)]
  knit <- stamps$failures

  logl <- character()
  if (status != 0L && !nrow(knit)) {
    lg <- if (file.exists(log)) readLines(log, warn = FALSE, encoding = "UTF-8") else character()
    i <- grep("^weft:", lg)
    logl <- if (length(i)) lg[i[1L]:length(lg)] else utils::tail(lg, 40L)
    logl <- c(sprintf("render exited with status %d", status), logl)
  }
  detail <- if (status != 0L) sprintf("%s exited with status %d", if (quarto_mode) "quarto" else "rmarkdown", status) else
    sprintf("%d document%s rendered", length(rendered), if (length(rendered) == 1L) "" else "s")
  if (nrow(knit) || length(unexec)) {
    detail <- paste0(detail, sprintf("; %d failure%s, %d not executed", nrow(knit), if (nrow(knit) == 1L) "" else "s",
                                     length(unexec)))
  }
  list(status = status, knit = knit, unexecuted = unexec, unfresh = stamps$unfresh, log = logl, detail = detail,
       notes = notes, output = verify_read_output(olog))
}

# ---- the rendered-output findings (N57) -----------------------------------------------------------------

VERIFY_OUTPUT_COLS <- c("file", "format", "kind", "level", "section", "text", "excerpt")

verify_empty_output <- function() {
  x <- lapply(VERIFY_OUTPUT_COLS, function(i) character())
  names(x) <- VERIFY_OUTPUT_COLS
  as.data.frame(x, stringsAsFactors = FALSE)
}

# The findings the output filter appended to `path`, one row per JSON line of source "output".
verify_read_output <- function(path) {
  out <- verify_empty_output()
  if (!file.exists(path)) return(out)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  rows <- list()
  for (l in lines[nzchar(trimws(lines))]) {
    r <- tryCatch(jsonlite::fromJSON(l, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.list(r) || !identical(r$source, "output")) next
    ch <- function(k) if (is.null(r[[k]]) || is.na(r[[k]])) "" else as.character(r[[k]])
    rows[[length(rows) + 1L]] <- data.frame(file = ch("file"), format = ch("format"), kind = ch("kind"),
                                           level = ch("level"), section = ch("section"), text = ch("text"),
                                           excerpt = ch("excerpt"), stringsAsFactors = FALSE)
  }
  if (length(rows)) out <- do.call(rbind, rows)
  out
}

# Does a document use the julia engine: `engine: julia` in its front matter, or a julia chunk?
verify_uses_julia <- function(root, rel) {
  x <- tryCatch(read_source_lines(file.path(root, rel)), error = function(e) character())
  doc_is_julia(x)
}

# does the document hold a weft construct (G11, count > 0)?
verify_has_constructs <- function(root, rel) {
  tryCatch({
    src <- lint_open(root, rel)
    !isTRUE(src$invalid) && nrow(count_constructs(src)) > 0L
  }, error = function(e) FALSE)
}

# The failures of the stamps this run wrote, and the documents they cover.
verify_read_stamps <- function(root, docs, run) {
  failures <- list()
  current <- character()
  unfresh <- character()
  for (rel in docs) {
    f <- file.path(root, ".weft", "stamps", stamp_file_name(rel))
    if (!file.exists(f)) next
    s <- tryCatch(jsonlite::fromJSON(f, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.list(s) || !identical(as.character(s$run %||% ""), run)) next
    current <- c(current, rel)
    # N120: the stamp says the values were not computed in this run
    if (identical(s$fresh, FALSE)) unfresh <- c(unfresh, rel)
    for (y in s$failures) {
      if (identical(y$level, "warn")) next
      ch <- function(k) if (is.null(y[[k]]) || is.na(y[[k]])) NA_character_ else as.character(y[[k]])
      it <- function(k) if (is.null(y[[k]]) || is.na(y[[k]])) NA_integer_ else suppressWarnings(as.integer(y[[k]]))
      failures[[length(failures) + 1L]] <- data.frame(
        kind = ch("kind"), file = if (is.na(ch("file"))) rel else ch("file"), line = it("line"),
        chunk = ch("chunk"), expr = ch("expr"), detail = ch("detail"), hint = ch("hint"),
        option = ch("option"), chunk_line = it("chunk_line"), stringsAsFactors = FALSE)
    }
  }
  list(current = current, unfresh = unfresh,
       failures = if (length(failures)) do.call(rbind, failures) else failures_frame_empty())
}
