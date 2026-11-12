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

freeze_backup_dir <- function(root) file.path(root, ".weft", "freeze-backup")

# Put back what a backup holds: for each stem, delete `_freeze/<stem>` and move the folder back; then
# delete the backup. Does nothing when there is no backup.
freeze_restore <- function(root) {
  bk <- freeze_backup_dir(root)
  if (!dir.exists(bk)) return(invisible(TRUE))
  man <- file.path(bk, "manifest")
  stems <- if (file.exists(man)) readLines(man, warn = FALSE) else character()
  ex <- list.dirs(bk, full.names = FALSE, recursive = TRUE)
  ex <- ex[basename(ex) == "execute-results"]
  stems <- unique(c(stems, dirname(ex)))
  stems <- stems[nzchar(stems) & stems != "."]
  ok <- TRUE
  for (s in stems) {
    from <- file.path(bk, s)
    if (!dir.exists(from)) next
    to <- file.path(root, "_freeze", s)
    unlink(to, recursive = TRUE)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    if (!file.rename(from, to)) ok <- FALSE
  }
  if (ok) unlink(bk, recursive = TRUE)
  invisible(ok)
}

# Move the entries of the verified documents out of `_freeze`, with a manifest of the stems.
freeze_backup <- function(root, stems) {
  bk <- freeze_backup_dir(root)
  weft_state_dir(root, "freeze-backup")
  writeLines(stems, file.path(bk, "manifest"))
  for (s in stems) {
    from <- file.path(root, "_freeze", s)
    if (!dir.exists(from)) next
    to <- file.path(bk, s)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    file.rename(from, to)
  }
  invisible()
}

# ---- running a child ----------------------------------------------------------------------------------

verify_run <- function(cmd, args, root, run, log) {
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  st <- suppressWarnings(system2(cmd, shQuote(args), stdout = log, stderr = log,
                                 env = paste0("WEFT_RUN=", run)))
  if (is.null(st)) 0L else as.integer(st)
}

# ---- the render ---------------------------------------------------------------------------------------

# Returns list(status, knit, unexecuted, log, detail)
verify_render <- function(root, docs, files_rel, cfg) {
  run <- verify_run_id()
  log <- tempfile("weft-verify-", fileext = ".log")
  on.exit(unlink(log), add = TRUE)
  quarto_mode <- file.exists(file.path(root, "_quarto.yml")) || file.exists(file.path(root, "_quarto.yaml")) ||
    any(grepl("\\.qmd$", docs))
  status <- 0L
  if (quarto_mode) {
    q <- verify_quarto_path()
    if (is.na(q)) {
      verify_abort(paste0("verify() renders with Quarto and found none. Install Quarto, or set QUARTO_PATH ",
                          "to its path (rule 8.1.1)."))
    }
    has_freeze <- dir.exists(file.path(root, "_freeze")) || dir.exists(freeze_backup_dir(root))
    if (has_freeze) {
      freeze_restore(root)
      if (dir.exists(file.path(root, "_freeze"))) freeze_backup(root, verify_stem(docs))
      on.exit(freeze_restore(root), add = TRUE)
    }
    status <- verify_run(q, c("render", files_rel), root, run, log)
    if (status == 0L) unlink(freeze_backup_dir(root), recursive = TRUE)
  } else {
    rs <- file.path(R.home("bin"), "Rscript")
    all_log <- character()
    one <- tempfile("weft-verify-doc-", fileext = ".log")
    on.exit(unlink(one), add = TRUE)
    for (rel in docs) {
      expr <- sprintf("rmarkdown::render(%s, quiet = TRUE)", deparse(rel))
      s <- verify_run(rs, c("-e", expr), root, run, one)
      if (file.exists(one)) all_log <- c(all_log, readLines(one, warn = FALSE))
      if (s != 0L) status <- s
    }
    writeLines(all_log, log)
  }

  # the stamps (G26)
  stamps <- verify_read_stamps(root, docs, run)
  need <- vapply(docs, function(rel) verify_has_constructs(root, rel), NA)
  unexec <- docs[need & !(docs %in% stamps$current)]
  knit <- stamps$failures

  logl <- character()
  if (status != 0L && !nrow(knit)) {
    lg <- if (file.exists(log)) readLines(log, warn = FALSE, encoding = "UTF-8") else character()
    i <- grep("^weft:", lg)
    logl <- if (length(i)) lg[i[1L]:length(lg)] else utils::tail(lg, 40L)
    logl <- c(sprintf("render exited with status %d", status), logl)
  }
  detail <- if (status != 0L) sprintf("%s exited with status %d", if (quarto_mode) "quarto" else "rmarkdown", status) else
    sprintf("%d document%s rendered", length(docs), if (length(docs) == 1L) "" else "s")
  if (nrow(knit) || length(unexec)) {
    detail <- paste0(detail, sprintf("; %d failure%s, %d not executed", nrow(knit), if (nrow(knit) == 1L) "" else "s",
                                     length(unexec)))
  }
  list(status = status, knit = knit, unexecuted = unexec, log = logl, detail = detail)
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
  for (rel in docs) {
    f <- file.path(root, ".weft", "stamps", paste0(gsub("/", "__", rel, fixed = TRUE), ".json"))
    if (!file.exists(f)) next
    s <- tryCatch(jsonlite::fromJSON(f, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.list(s) || !identical(as.character(s$run %||% ""), run)) next
    current <- c(current, rel)
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
  list(current = current,
       failures = if (length(failures)) do.call(rbind, failures) else failures_frame_empty())
}
