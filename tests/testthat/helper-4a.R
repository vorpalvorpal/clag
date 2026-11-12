# Helpers for the package 4a tests (the commit gate, gate()). Contract: dev/design-4.md G1-G20, H1-H16.
# Built on helper-3.R (f3_write, lint_proj, lf_*, read_src, F3_BAD_*) and helper-3d.R (F3D_CLAIMS).
# Names follow section 4 of the design ("Test helpers"): git_env(), g_repo(), g_write(), g_add(),
# g_commit(), g_gate(), skip_if_no_git(). ASCII only: write non-ASCII as \uXXXX. Invented content only.
#
# Nothing here reads the user's git configuration or the network, and nothing touches any repository
# but the temporary ones it makes (GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM are empty temporary files,
# HOME is a temporary folder, the identity is invented, signing is off).

skip_if_no_git <- function() {
  testthat::skip_if(!nzchar(Sys.which("git")), "git is not on the PATH")
}

# Isolate git for the calling test: no user or system configuration, an invented identity and fixed dates,
# no inherited repository variables. `env` is the frame the settings last until.
git_env <- function(env = parent.frame()) {
  empty_g <- withr::local_tempfile(.local_envir = env, lines = character())
  empty_s <- withr::local_tempfile(.local_envir = env, lines = character())
  home <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(
    GIT_CONFIG_GLOBAL = empty_g, GIT_CONFIG_SYSTEM = empty_s, GIT_CONFIG_NOSYSTEM = "1", HOME = home,
    XDG_CONFIG_HOME = file.path(home, "xdg"),
    GIT_AUTHOR_NAME = "Test Writer", GIT_AUTHOR_EMAIL = "writer@example.invalid",
    GIT_COMMITTER_NAME = "Test Writer", GIT_COMMITTER_EMAIL = "writer@example.invalid",
    GIT_AUTHOR_DATE = "2026-01-02T03:04:05+0000", GIT_COMMITTER_DATE = "2026-01-02T03:04:05+0000",
    GIT_DIR = NA, GIT_WORK_TREE = NA, GIT_INDEX_FILE = NA, GIT_COMMON_DIR = NA, GIT_PREFIX = NA,
    GIT_EDITOR = "true", GIT_TERMINAL_PROMPT = "0",
    .local_envir = env)
  invisible(NULL)
}

# Run git in `dir`; returns the output lines with the exit status as attribute "status".
g_git <- function(dir, ...) {
  args <- c("-C", dir, "-c", "core.quotepath=false", c(...))
  out <- suppressWarnings(system2("git", shQuote(args), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status")
  structure(as.character(out), status = if (is.null(st)) 0L else st)
}
g_ok_git <- function(dir, ...) {
  out <- g_git(dir, ...)
  if (!identical(attr(out, "status"), 0L)) {
    stop("git failed: ", paste(c(...), collapse = " "), "\n", paste(out, collapse = "\n"))
  }
  invisible(out)
}

# Write `lines` (or a raw vector) to `path` under `dir`, creating folders.
g_write <- function(dir, path, lines) {
  f3_write(file.path(dir, path), lines)
  invisible(file.path(dir, path))
}

# Stage `...` (paths under dir; none: everything).
g_add <- function(dir, ...) {
  p <- c(...)
  if (!length(p)) g_ok_git(dir, "add", "--all", "--", ".") else g_ok_git(dir, "add", "--all", "--", p)
}

# Commit what is staged (no hook is installed here unless the test installs one). Returns the status.
g_commit <- function(dir, msg = "commit", args = character()) {
  out <- g_git(dir, "commit", "-q", "--allow-empty", args, "-m", msg)
  invisible(attr(out, "status"))
}

g_head <- function(dir) trimws(g_ok_git(dir, "rev-parse", "HEAD"))

# A temporary git repository. `files`: named list path -> lines (or a raw vector), paths relative to the top.
# `weft`: folders (relative to the top, "." the top) that get an `_weft.yml` holding `weft_yml`, unless `files`
# names it. `commit`: make a first commit of everything (the baseline); FALSE leaves the files written
# and nothing staged, HEAD unborn. Returns the top (normalised). Removed when the calling test ends.
g_repo <- function(files = list(), weft = ".", weft_yml = "draft: false", commit = TRUE,
                   env = parent.frame()) {
  skip_if_no_git()
  git_env(env)
  dir <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  g_ok_git(dir, "init", "-q", "-b", "main")
  g_ok_git(dir, "config", "user.name", "Test Writer")
  g_ok_git(dir, "config", "user.email", "writer@example.invalid")
  g_ok_git(dir, "config", "commit.gpgsign", "false")
  for (w in weft) {
    p <- if (identical(w, ".")) "_weft.yml" else file.path(w, "_weft.yml")
    if (is.null(files[[p]])) files[[p]] <- weft_yml
  }
  for (nm in names(files)) f3_write(file.path(dir, nm), files[[nm]])
  if (commit) {
    g_add(dir)
    g_commit(dir, "baseline")
  }
  dir
}

# A repository whose baseline is `before` (committed), then `after` applied to the work tree and staged:
# a path with a character vector is written, a path with NULL is deleted. `stage = FALSE` leaves the
# changes in the work tree only. Extra arguments go to g_repo().
g_scenario <- function(before, after = list(), stage = TRUE, ..., env = parent.frame()) {
  dir <- g_repo(before, ..., env = env)
  g_apply(dir, after)
  if (stage) g_add(dir)
  dir
}
g_apply <- function(dir, after) {
  for (nm in names(after)) {
    v <- after[[nm]]
    if (is.null(v)) unlink(file.path(dir, nm)) else f3_write(file.path(dir, nm), v)
  }
  invisible(dir)
}

# a commit-message file holding `lines`
g_msg <- function(lines, env = parent.frame()) {
  p <- withr::local_tempfile(.local_envir = env, fileext = ".msg")
  writeLines(lines, p)
  p
}

# Real message files as git hands them to commit-msg: install a throwaway hook that copies "$1" and
# fails, run `git commit <args>` (GIT_EDITOR=true), return the copy. The commit does not happen.
g_capture_msg <- function(dir, args, env = parent.frame()) {
  hooks <- file.path(dir, ".git", "hooks")
  dir.create(hooks, showWarnings = FALSE)
  hook <- file.path(hooks, "commit-msg")
  writeLines(c("#!/bin/sh", "cp \"$1\" \"$1.captured\"", "exit 1"), hook)
  Sys.chmod(hook, "755")
  on.exit(unlink(hook), add = TRUE)
  g_git(dir, "commit", "-q", "--allow-empty", args)
  out <- file.path(dir, ".git", "COMMIT_EDITMSG.captured")
  if (!file.exists(out)) stop("the throwaway commit-msg hook did not run")
  keep <- withr::local_tempfile(.local_envir = env, fileext = ".msg")
  file.copy(out, keep)
  unlink(out)
  keep
}

# ---- running the gate -------------------------------------------------------------------------------

# Strip the time out of a report: "0.8 s" -> "T s".
g_norm_time <- function(lines) sub("[0-9]+\\.[0-9] s\\b", "T s", lines)

# Run gate(msg, path = dir), capturing what it prints (messages) as lines in attribute "report".
# `msg`: NULL, a path of an existing message file, or lines of text written to a file.
# Errors are not caught.
g_gate <- function(dir, msg = NULL, ..., env = parent.frame()) {
  mpath <- NULL
  if (!is.null(msg)) mpath <- if (length(msg) == 1L && file.exists(msg)) msg else g_msg(msg, env)
  out <- character()
  res <- withCallingHandlers(
    gate(mpath, path = dir, ...),
    message = function(m) {
      out <<- c(out, conditionMessage(m))
      invokeRestart("muffleMessage")
    })
  attr(res, "report") <- g_lines(out)
  res
}
g_lines <- function(out) {
  txt <- cli::ansi_strip(paste(out, collapse = ""))
  if (!nzchar(txt)) return(character())
  strsplit(sub("\n$", "", txt), "\n", fixed = TRUE)[[1]]
}
# the report lines of a result from g_gate(), time normalised
g_report <- function(res) g_norm_time(attr(res, "report"))

# what print() shows: messages and output together, as lines, time normalised
g_print_lines <- function(res) {
  out <- character()
  txt <- utils::capture.output(
    withCallingHandlers(print(res), message = function(m) {
      out <<- c(out, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  g_norm_time(c(txt, g_lines(out)))
}

# a plain data frame of a weft_findings
g_df <- function(x) as.data.frame(unclass(x), stringsAsFactors = FALSE)

# the comparable content of a gate result: everything but the time, the report without its time line
g_sig <- function(res) {
  rep <- g_report(res)
  list(ok = res$ok, errors = g_df(res$errors)[, c("file", "line", "rule", "text")],
       added = g_df(res$added)[, c("file", "line", "rule", "text")],
       excess = res$excess, removed = res$removed, n_removed = res$n_removed,
       trailer = res$trailer, changed = sort(res$changed),
       report = rep[!grepl("^commit-msg: T s$", rep)])
}

# a snapshot of a folder's files (name -> md5), the .git folder left out
g_snapshot <- function(dir) {
  f <- list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = FALSE, no.. = TRUE)
  f <- sort(f[!grepl("^\\.git(/|$)", f)])
  stats::setNames(unname(tools::md5sum(file.path(dir, f))), f)
}
# the git directory's snapshot, weft's own folder and the index left out; the index as `ls-files -s`
g_git_snapshot <- function(dir) {
  f <- list.files(file.path(dir, ".git"), recursive = TRUE, all.files = TRUE, include.dirs = FALSE, no.. = TRUE)
  f <- sort(f[!grepl("^weft(/|$)", f) & f != "index"])
  list(files = stats::setNames(unname(tools::md5sum(file.path(dir, ".git", f))), f),
       index = unname(g_ok_git(dir, "ls-files", "-s")))
}

# ---- the cache (G14) ---------------------------------------------------------------------------------

g_cache_dir <- function(dir) {
  common <- trimws(g_ok_git(dir, "rev-parse", "--git-common-dir"))
  if (!grepl("^(/|[A-Za-z]:)", common)) common <- file.path(dir, common)
  file.path(normalizePath(common, winslash = "/"), "weft", "cache")
}
g_cache_files <- function(dir) {
  d <- g_cache_dir(dir)
  if (dir.exists(d)) list.files(d, full.names = TRUE) else character()
}

# How many times weft:::read_source() ran while `expr` was evaluated (G4a: lints() reads each file
# through read_source() unless the gate's cache supplies the source).
g_count_reads <- function(expr) {
  n <- 0L
  orig <- weft:::read_source
  testthat::local_mocked_bindings(
    read_source = function(...) {
      n <<- n + 1L
      orig(...)
    },
    .package = "weft")
  force(expr)
  n
}

# ---- fixtures -----------------------------------------------------------------------------------------

G_PROSE <- c("The river runs past the town.", "", "Children swim there in summer.")

# paragraphs, each a sentence holding a typed numeral: "Flow rose by 45% in March." -> numeral "45%"
g_num_doc <- function(pcts = "45%", lead = "Intro paragraph.") {
  c(lead, unlist(lapply(pcts, function(p) c("", sprintf("Flow rose by %s in March.", p)))))
}
# a document whose line 3 holds one construct error (rule construct; F3_BAD_TWO)
g_bad_doc <- function(lead = "Intro paragraph.") c(lead, "", paste("A", F3_BAD_TWO, "here."))

# a document of values, one per paragraph (paragraph i is on line 2 * i - 1): `vars` are R object names
g_vals <- function(vars) {
  out <- character()
  for (i in seq_along(vars)) {
    out <- c(out, if (i > 1L) "", sprintf("The reading is `r %s`{.num} metres.", vars[[i]]))
  }
  out
}

# ---- cases shared by the judge and cache tests ----------------------------------------------------------
# Each: name, ok (expected), msg (message lines or NULL), build = function(env) -> repository top
# (a baseline commit, the commit's changes staged).
g_cases <- function() {
  vals3 <- g_vals(c("rain_mean", "n_sites", "depth_max"))
  list(
    list(name = "clean edit", ok = TRUE, build = function(env) g_scenario(
      list("ch1.qmd" = G_PROSE), list("ch1.qmd" = c(G_PROSE, "", "One more sentence.")), env = env)),
    list(name = "new construct error", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_bad_doc()), env = env)),
    list(name = "construct error in HEAD, same file edited", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = g_bad_doc()), list("ch1.qmd" = c(g_bad_doc(), "", "Edited.")), env = env)),
    list(name = "construct error in HEAD, other file edited", ok = TRUE, build = function(env) g_scenario(
      list("ch1.qmd" = g_bad_doc(), "ch2.qmd" = G_PROSE),
      list("ch2.qmd" = c(G_PROSE, "", "Edited.")), env = env)),
    list(name = "finding already in HEAD", ok = TRUE, build = function(env) g_scenario(
      list("ch1.qmd" = g_num_doc("45%")), list("ch1.qmd" = c(g_num_doc("45%"), "", "Edited.")), env = env)),
    list(name = "new finding", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")), env = env)),
    list(name = "same text twice, once before", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = g_num_doc("45%")), list("ch1.qmd" = g_num_doc(c("45%", "45%"))), env = env)),
    list(name = "finding removed", ok = TRUE, build = function(env) g_scenario(
      list("ch1.qmd" = g_num_doc(c("45%", "37%"))), list("ch1.qmd" = g_num_doc("45%")), env = env)),
    list(name = "finding moved to another file", ok = TRUE, build = function(env) g_scenario(
      list("ch1.qmd" = g_num_doc("45%"), "ch2.qmd" = G_PROSE),
      list("ch1.qmd" = G_PROSE, "ch2.qmd" = g_num_doc("45%")), env = env)),
    list(name = "anchor removed that an unchanged chapter cites", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = c("## Limits {#sec-limits}", "", "Text."), "ch2.qmd" = "See @sec-limits for more."),
      list("ch1.qmd" = c("## Limits {#sec-bounds}", "", "Text.")), env = env)),
    list(name = "label word dropped from _weft.yml", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = "Samples came from Station 7.", "_weft.yml" = c("draft: false", "label_words: [Station]")),
      list("_weft.yml" = "draft: false"), env = env)),
    list(name = "constructs removed, no trailer", ok = FALSE, build = function(env) g_scenario(
      list("ch1.qmd" = g_vals(c("rain_mean", "n_sites", "depth_max"))),
      list("ch1.qmd" = vals3[1:3]), env = env)),
    list(name = "constructs removed, right trailer", ok = TRUE, msg = c("Drop a paragraph", "", "Weft-Removed: 1"),
         build = function(env) g_scenario(
           list("ch1.qmd" = g_vals(c("rain_mean", "n_sites", "depth_max"))),
           list("ch1.qmd" = vals3[1:3]), env = env))
  )
}
