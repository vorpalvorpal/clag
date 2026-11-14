# Helpers for the 4b tests (the installers: the commit-msg hook, use_hooks(), use_ci(),
# use_agent_docs(), use_weft(), status()). Contract: dev/design-4.md G21, G22, G33, G34, G38-G41.
# Built on helper-4a.R (git_env(), g_repo(), g_git(), g_ok_git(), g_apply(), g_add(), g_head(),
# G_PROSE, g_bad_doc(), g_num_doc(), g_vals()) and helper-4d.R (u4_dir(), u4_rel(), u4_read(),
# u4_version()). Nothing here edits those. ASCII only.
#
# The expected texts below are copies of the design's templates (G21, G33, G34), written out here so
# that the tests do not read inst/.
#
#   h4_env()            isolated environment for the calling test (no profile, empty user libraries)
#   h4_lib()            the library vector to hand to use_hooks(lib =)
#   h4_repo()           a temporary git repository, optionally with an origin
#   h4_say()            what an installer says (messages and printed output) and its value
#   h4_hook_expected()  the hook script as use_hooks() must write it
#   h4_ci_expected()    the workflow as use_ci() must write it
#   h4_block_lines()    the AGENTS.md block as use_agent_docs() must write it
#   h4_forge()          an older-template copy of a weft whole file (valid marker and hash)
#   h4_marker()         parse the weft-file marker of a file's lines
#   h4_snap()           a snapshot of a folder (path -> md5)
#   h4_commit()         git commit with output and status

# ---- environment -----------------------------------------------------------------------------

# no project profile, empty user and site libraries, a temporary cache folder
h4_env <- function(env = parent.frame()) {
  empty <- withr::local_tempdir(.local_envir = env)
  cache <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(
    R_LIBS_USER = empty, R_LIBS_SITE = empty, R_PROFILE_USER = NA, R_PROFILE = NA,
    R_ENVIRON_USER = NA, WEFT_DRAFT = NA, WEFT_COLLECT = NA, WEFT_RUN = NA, NO_COLOR = "1",
    R_USER_CACHE_DIR = cache, .local_envir = env)
  invisible(cache)
}

# the library path the hook records: the working tree's installed copy, then the session's libraries
h4_lib <- function() {
  l <- weft_test_lib()
  unique(c(if (nzchar(l)) l, .libPaths()))
}

h4_libs_string <- function(lib = h4_lib()) paste(lib, collapse = .Platform$path.sep)
h4_rscript <- function() file.path(R.home("bin"), "Rscript")

# the PATH for a child that has git but no Rscript, or NULL when that cannot be arranged here
h4_path_without_rscript <- function() {
  git <- Sys.which("git")
  if (!nzchar(git)) return(NULL)
  p <- unique(c(dirname(git), "/usr/bin", "/bin"))
  path <- paste(p[dir.exists(p)], collapse = ":")
  found <- withr::with_envvar(c(PATH = path), Sys.which("Rscript"))
  if (nzchar(found)) NULL else path
}

# ---- repositories ----------------------------------------------------------------------------

# A repository (helper-4a's g_repo()) with the isolated R environment, and an `origin` remote when
# given. `weft`: the folders that hold an _weft.yml (character() for none).
h4_repo <- function(files = list(), weft = ".", origin = NULL, env = parent.frame()) {
  dir <- g_repo(files, weft = weft, env = env)
  h4_env(env)
  if (!is.null(origin)) g_ok_git(dir, "remote", "add", "origin", origin)
  dir
}

# A repository made inside a folder named `name` (it may hold a space and a quote). `files` as g_repo().
h4_repo_named <- function(name, files = list(), env = parent.frame()) {
  skip_if_no_git()
  git_env(env)
  h4_env(env)
  base <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  dir <- file.path(base, name)
  dir.create(dir)
  g_ok_git(dir, "init", "-q", "-b", "main")
  g_ok_git(dir, "config", "user.name", "Test Writer")
  g_ok_git(dir, "config", "user.email", "writer@example.invalid")
  g_ok_git(dir, "config", "commit.gpgsign", "false")
  if (is.null(files[["_weft.yml"]])) files[["_weft.yml"]] <- "draft: false"
  for (nm in names(files)) f3_write(file.path(dir, nm), files[[nm]])
  g_add(dir)
  g_commit(dir, "baseline")
  dir
}

# A repository inside a parent folder, so a test can look at the parent: list(parent, dir).
h4_repo_in_parent <- function(files = list(), env = parent.frame(), ...) {
  skip_if_no_git()
  git_env(env)
  h4_env(env)
  parent <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  dir <- file.path(parent, "proj")
  dir.create(dir)
  g_ok_git(dir, "init", "-q", "-b", "main")
  g_ok_git(dir, "config", "user.name", "Test Writer")
  g_ok_git(dir, "config", "user.email", "writer@example.invalid")
  g_ok_git(dir, "config", "commit.gpgsign", "false")
  if (is.null(files[["_weft.yml"]])) files[["_weft.yml"]] <- "draft: false"
  for (nm in names(files)) f3_write(file.path(dir, nm), files[[nm]])
  g_add(dir)
  g_commit(dir, "baseline")
  list(parent = parent, dir = dir)
}

h4_git_path <- function(dir, what) {
  p <- trimws(g_ok_git(dir, "rev-parse", "--git-path", what))
  if (!grepl("^(/|[A-Za-z]:)", p)) p <- file.path(dir, p)
  normalizePath(p, winslash = "/", mustWork = FALSE)
}
h4_common_dir <- function(dir) {
  p <- trimws(g_ok_git(dir, "rev-parse", "--git-common-dir"))
  if (!grepl("^(/|[A-Za-z]:)", p)) p <- file.path(dir, p)
  normalizePath(p, winslash = "/", mustWork = FALSE)
}
h4_hook_path <- function(dir) file.path(dir, ".git", "hooks", "commit-msg")

# ---- calling the installers --------------------------------------------------------------------

# Evaluate `expr`, collecting what it says: messages and printed output. `first` runs at the first
# message (to look at the disk before anything is written). Errors are not caught.
h4_say <- function(expr, first = NULL) {
  withr::local_options(cli.width = 500, cli.num_colors = 1)
  txt <- character()
  seen <- FALSE
  val <- NULL
  out <- utils::capture.output(
    withCallingHandlers({ val <- expr },
      message = function(m) {
        if (!seen && !is.null(first)) first()
        seen <<- TRUE
        txt <<- c(txt, conditionMessage(m))
        invokeRestart("muffleMessage")
      }))
  all <- cli::ansi_strip(h4_join(paste(txt, collapse = ""), paste(out, collapse = "\n")))
  list(value = val, text = all, lines = strsplit(all, "\n", fixed = TRUE)[[1]])
}

# messages text then output text, one line break between when neither ends with one
h4_join <- function(msg_txt, out_txt) {
  paste0(msg_txt, if (nzchar(msg_txt) && nzchar(out_txt) && !endsWith(msg_txt, "\n")) "\n", out_txt)
}

# quiet calls, returning the value
h4_hooks <- function(dir, ..., lib = h4_lib()) {
  suppressMessages(utils::capture.output(res <- weft::use_hooks(dir, ..., lib = lib)))
  res
}
h4_ci <- function(dir, ...) {
  suppressMessages(utils::capture.output(res <- weft::use_ci(dir, ...)))
  res
}
h4_agent <- function(dir, ...) {
  suppressMessages(utils::capture.output(res <- weft::use_agent_docs(dir, ...)))
  res
}
# use_weft() with the test library first on .libPaths(), so that its use_hooks() finds weft
h4_weft <- function(dir, env = parent.frame()) {
  withr::local_libpaths(h4_lib(), action = "prefix", .local_envir = env)
  suppressMessages(utils::capture.output(res <- weft::use_weft(dir)))
  res
}
h4_status <- function(dir) {
  suppressMessages(utils::capture.output(res <- weft::status(dir)))
  res
}
h4_state <- function(st, part) st$state[st$part == part]
h4_detail <- function(st, part) st$detail[st$part == part]

# what print() of an object shows, messages and output together, as lines
h4_print_lines <- function(x) {
  out <- character()
  txt <- utils::capture.output(
    withCallingHandlers(print(x), message = function(m) {
      out <<- c(out, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  all <- cli::ansi_strip(h4_join(paste(out, collapse = ""), paste(txt, collapse = "\n")))
  strsplit(sub("\n+$", "", all), "\n", fixed = TRUE)[[1]]
}

# ---- git commit with its output ------------------------------------------------------------------

# `git commit -q <args> -m <msg>` (stdout and stderr together); list(status, out, head_before, head_after)
h4_commit <- function(dir, msg = "change", args = character(), msg_args = c("-m", msg)) {
  before <- tryCatch(g_head(dir), error = function(e) NA_character_)
  out <- g_git(dir, "commit", "-q", args, msg_args)
  after <- tryCatch(g_head(dir), error = function(e) NA_character_)
  list(status = attr(out, "status"), out = paste(out, collapse = "\n"),
       moved = !identical(before, after))
}

# stdout and stderr of `git commit` kept apart
h4_commit_split <- function(dir, msg = "change", args = character()) {
  so <- tempfile("h4-so-"); se <- tempfile("h4-se-")
  on.exit(unlink(c(so, se)), add = TRUE)
  st <- suppressWarnings(system2("git", shQuote(c("-C", dir, "commit", "-q", args, "-m", msg)),
                                 stdout = so, stderr = se))
  list(status = st, stdout = paste(readLines(so, warn = FALSE), collapse = "\n"),
       stderr = paste(readLines(se, warn = FALSE), collapse = "\n"))
}

# ---- markers (G40) -------------------------------------------------------------------------------

# the weft-file marker of `lines`: list(idx, fn, version, hash), or NULL
h4_marker <- function(lines) {
  i <- grep("weft-file: ", lines, fixed = TRUE)
  if (!length(i)) return(NULL)
  i <- i[1]
  m <- regmatches(lines[i], regexec("weft-file: (\\S+) (\\S+) ([0-9a-f]{32})", lines[i]))[[1]]
  if (length(m) != 4L) return(NULL)
  list(idx = i, fn = m[2], version = m[3], hash = m[4])
}

# the md5 a marker must carry: of the other lines joined by "\n" (G40)
h4_hash_of <- function(lines, idx) cli::hash_md5(paste(lines[-idx], collapse = "\n"))

# is the marker of a whole file valid (present, and its hash that of the other lines)?
h4_marker_valid <- function(lines) {
  m <- h4_marker(lines)
  !is.null(m) && identical(m$hash, h4_hash_of(lines, m$idx))
}

# Fill the marker of a whole-file template: `lines` holds @VERSION@ and @HASH@ on the marker line.
h4_fill_marker <- function(lines, version = u4_version()) {
  i <- grep("@HASH@", lines, fixed = TRUE)[1]
  h <- cli::hash_md5(paste(lines[-i], collapse = "\n"))
  lines[i] <- sub("@HASH@", h, sub("@VERSION@", version, lines[i], fixed = TRUE), fixed = TRUE)
  lines
}

# An older copy of a whole file weft wrote (the default version must stay older than the installed one, review-code-c #15): `edit` changes the other lines, the marker gets `version`
# and a hash that matches the new text (so the file reads as weft's, unedited, from an older template).
h4_forge <- function(lines, edit, version = "0.0.0.1") {
  i <- h4_marker(lines)$idx
  body <- edit(lines[-i])
  mk <- lines[i]
  head <- sub("(weft-file: \\S+) \\S+ [0-9a-f]{32}.*$", "\\1", mk)
  tail <- sub("^.*weft-file: \\S+ \\S+ [0-9a-f]{32}", "", mk)
  new_mk <- paste0(head, " ", version, " ", cli::hash_md5(paste(body, collapse = "\n")), tail)
  append(body, new_mk, after = i - 1L)
}

# ---- the hook (G21) ----------------------------------------------------------------------------------

H4_HOOK_TEMPLATE <- r"---(#!/bin/sh
# weft-file: use_hooks @VERSION@ @HASH@
# The weft commit gate (rules 6.1 to 6.3), written by weft::use_hooks().
# Remove it with weft::use_hooks(remove = TRUE). Skip it for one commit
# with: git commit --no-verify
weft_rscript='@RSCRIPT@'
weft_libs='@LIBS@'
if [ ! -f "$weft_rscript" ]; then
  weft_found=$(command -v Rscript 2>/dev/null)
  if [ -z "$weft_found" ]; then
    echo "commit-msg: weft cannot find R: $weft_rscript is gone and Rscript is not on the PATH." >&2
    echo "  Run weft::use_hooks() again, or skip the check once with git commit --no-verify." >&2
    exit 1
  fi
  weft_rscript=$weft_found
fi
R_LIBS=$weft_libs
export R_LIBS
exec "$weft_rscript" --no-init-file --no-environ -e '
if (!requireNamespace("weft", quietly = TRUE)) {
  message("commit-msg: weft is not installed for the R at ", R.home(), ".")
  message("  Run weft::use_hooks() again, or skip the check once with git commit --no-verify.")
  quit(save = "no", status = 1L)
}
st <- tryCatch(if (isTRUE(weft::gate(commandArgs(TRUE)[1L])$ok)) 0L else 1L,
  error = function(e) {
    message("commit-msg: weft stopped with an error: ", conditionMessage(e))
    message("  Skip the check once with git commit --no-verify, and report the error.")
    1L
  })
quit(save = "no", status = st)' "$1")---"

h4_sh_quote <- function(x) gsub("'", "'\\\\''", x)

# the hook as use_hooks(rscript =, lib =) must write it (lines)
h4_hook_expected <- function(rscript = h4_rscript(), lib = h4_lib(), version = u4_version()) {
  x <- strsplit(H4_HOOK_TEMPLATE, "\n", fixed = TRUE)[[1]]
  x <- sub("@RSCRIPT@", h4_sh_quote(rscript), x, fixed = TRUE)
  x <- sub("@LIBS@", h4_sh_quote(h4_libs_string(lib)), x, fixed = TRUE)
  h4_fill_marker(x, version)
}

# a hook written by someone else (no weft-file line)
H4_FOREIGN_HOOK <- c("#!/bin/sh", "# my own commit-msg hook", "echo \"checked $1\" >&2", "exit 0")

# a hook as pre-commit would generate it
H4_PRECOMMIT_HOOK <- c("#!/usr/bin/env bash", "# File generated by pre-commit: https://pre-commit.com",
                       "# ID: 138fd403232d2ddd5efb44317e38bf03", "exec pre-commit hook-impl \"$@\"")

# ---- the workflow (G33) ------------------------------------------------------------------------------

H4_CI_TEMPLATE <- r"---(# weft-file: use_ci @VERSION@ @HASH@
# Written by weft::use_ci() (rule 8.4.1): weft::verify(static = TRUE) on each pull request.
name: weft
on:
  pull_request:
permissions:
  contents: read
  issues: read
  pull-requests: read
jobs:
  verify:
    runs-on: ubuntu-latest
    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          packages: github::vorpalvorpal/weft
      - name: weft static checks
        env:
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          WEFT_PROJECT: '@PATH@'
        run: |
          since=$(git merge-base "$BASE_SHA" HEAD)
          Rscript --no-init-file -e "weft::verify(static = TRUE, since = '$since', path = Sys.getenv('WEFT_PROJECT'))")---"

# the workflow as use_ci() must write it; `path` is the project root relative to the repository top
h4_ci_expected <- function(path = ".", version = u4_version()) {
  x <- strsplit(H4_CI_TEMPLATE, "\n", fixed = TRUE)[[1]]
  x <- sub("@PATH@", gsub("'", "''", path, fixed = TRUE), x, fixed = TRUE)
  h4_fill_marker(x, version)
}

# ---- the agent documents (G34) -------------------------------------------------------------------------

H4_AGENTS_TEMPLATE <- r"---(## weft

This project uses the weft R package: numbers in the prose are computed
(`` `r x` ``), wording that depends on them is chosen by spans
(`[a site | # sites]{n="k"}`), and `claim()` checks what the prose says.

- A failed claim is a finding to report to the author, not an error to clear.
- Do not change or remove a check (`claim()`, a guard, a bound) to make a
  render or a commit pass, unless the author asks for exactly that.
- When a commit removes weft constructs on purpose, add the line the
  commit-msg hook prints, `Weft-Removed: N`, with its number. Do not use
  `--no-verify` to get past the hook.
- Values that hold for one chapter only go in that document's front matter
  under `weft: dict_local:`, each with a `why:`; read them as
  `dict_local$key`, never `dict$key`.

The weft skill is in the project's skills folders (`.agents/skills/weft/`,
`.claude/skills/weft/`) and has the detail; `weft::agent_docs()` prints it.)---"

H4_AGENTS_INNER <- strsplit(H4_AGENTS_TEMPLATE, "\n", fixed = TRUE)[[1]]
H4_BLOCK_END <- "<!-- weft:end -->"

# The block as use_agent_docs() must write it. The hash is over the block's lines other than the start
# line (the inner lines and the end line); the tests accept the inner lines alone as well (see
# h4_block_parse()).
h4_block_lines <- function(inner = H4_AGENTS_INNER, version = u4_version()) {
  hash <- cli::hash_md5(paste(c(inner, H4_BLOCK_END), collapse = "\n"))
  c(sprintf("<!-- weft:start use_agent_docs %s %s -->", version, hash), inner, H4_BLOCK_END)
}

# an older block: other text in it, the version and hash matching
h4_block_old <- function() {
  inner <- sub("never `dict$key`", "never `dict$key` (old wording)", H4_AGENTS_INNER, fixed = TRUE)
  h4_block_lines(inner, version = "0.0.0.1")
}

# Find the block in `lines`: list(start, end, version, hash, inner, hash_ok) or NULL.
h4_block_parse <- function(lines) {
  s <- grep("^<!-- weft:start use_agent_docs ", lines)
  e <- grep("^<!-- weft:end -->$", lines)
  if (length(s) != 1L || length(e) != 1L || e < s) return(NULL)
  m <- regmatches(lines[s], regexec("^<!-- weft:start use_agent_docs (\\S+) ([0-9a-f]{32}) -->$", lines[s]))[[1]]
  if (length(m) != 3L) return(NULL)
  inner <- lines[seq_len(e - s - 1L) + s]
  ok <- m[3] %in% c(cli::hash_md5(paste(c(inner, lines[e]), collapse = "\n")),
                    cli::hash_md5(paste(inner, collapse = "\n")))
  list(start = s, end = e, version = m[2], hash = m[3], inner = inner, hash_ok = ok)
}

# drop blank lines at both ends
h4_trim_blank <- function(x) {
  nz <- which(nzchar(trimws(x)))
  if (!length(nz)) character() else x[min(nz):max(nz)]
}

H4_SKILL_DESCRIPTION <- paste0(
  "Use when editing a document of a project that uses the weft R package (inline `r` values, ",
  "spans with n=, if=, sign=, list=, cite=, claim() checks, _weft.yml), or when a render, a lint ",
  "or a commit fails with a weft report.")

# ---- snapshots ------------------------------------------------------------------------------------------

# path -> md5 ("<dir>" for a folder) of everything under `dir`; `skip` is a regular expression of
# relative paths to leave out
h4_snap <- function(dir, skip = NULL) {
  f <- sort(list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = TRUE, no.. = TRUE))
  if (!is.null(skip)) f <- f[!grepl(skip, f)]
  full <- file.path(dir, f)
  isd <- dir.exists(full)
  h <- rep("<dir>", length(f))
  if (any(!isd)) h[!isd] <- unname(tools::md5sum(full[!isd]))
  stats::setNames(h, f)
}
# a repository's snapshot with the git index left out (git may refresh it when it reads)
h4_snap_repo <- function(dir) h4_snap(dir, skip = "^\\.git/(index|index\\.lock)$")

# the repository's parent without the repository itself
h4_snap_parent <- function(parent, keep_out = "proj") {
  s <- h4_snap(parent)
  s[!(names(s) == keep_out | startsWith(names(s), paste0(keep_out, "/")))]
}

# a snapshot of what an installer may not touch: the HOME folder, the cache folder, the repository's
# parent (outside the repository)
h4_outside_snap <- function(parent) {
  list(home = h4_snap(Sys.getenv("HOME")), cache = h4_snap(Sys.getenv("R_USER_CACHE_DIR")),
       parent = h4_snap_parent(parent))
}
