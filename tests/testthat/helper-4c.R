# Helpers for the package 4c tests (verify(), its freeze sequence, the settings strict, verify_skip and
# weft_version, the version warning). Contract: dev/design-4.md G23-G32, H17-H21, H28.
# Built on helper-4a.R (g_repo, g_write, g_add, g_commit, g_head, g_lines, g_norm_time, g_snapshot,
# g_num_doc, g_bad_doc, g_vals, G_PROSE), helper-3.R (f3_write, lint_proj, F3_BAD_*), helper-4d.R
# (u4_r, u4_env, u4_home, u4_quarto_project is NOT used) and helper-render.R / helper-quarto.R
# (weft_test_lib, skip_if_no_quarto, skip_if_no_pandoc, mk_project, qrender). ASCII only. Invented content.
#
#   v4_env()          isolated environment for the calling test (no WEFT_DRAFT, WEFT_RUN, ...)
#   v4_proj()         a project (git or not, at the top of a folder or in a subfolder `proj/`)
#   v4_verify()       verify() with its report, warnings and error captured
#   v4_fake_quarto()  a stand-in `quarto` found through QUARTO_PATH: logs what it sees, does what it is told
#   v4_q*()           real Quarto and rmarkdown fixtures (slow; shared by the caller)
#
# Nothing here writes outside temporary folders, reads the user's git configuration or the network.

V4_PARTS <- c("lints", "decisions", "render", "ledger")
V4_RESULT_FIELDS <- c("ok", "parts", "errors", "added", "strict", "removed", "tier2", "decisions", "knit",
                      "unexecuted", "stale", "tolerated", "notes", "seconds")
V4_SECTIONS <- c("Construct errors", "Findings added since", "Strict rules", "Target names",
                 "Decision pointers", "Knit-time failures", "Not executed in this render",
                 "Ledger: entries not re-rendered", "Constructs removed since", "Tier-2 findings on added lines",
                 "Tolerated findings")

# The version warning's text (G32), for the version `rec` the project records.
v4_version <- function() as.character(utils::packageVersion("weft"))
v4_version_msg <- function(rec) {
  if (utils::compareVersion(rec, v4_version()) > 0L) {
    # a record newer than the installed weft: the advice is to update weft (review code C, #15)
    return(sprintf(paste0("This project records weft %s in _weft.yml, and weft %s is installed, older than the %s ",
                          "this project records. Update weft, or run weft::use_weft() to take the project back to %s ",
                          "(rule 9.5.4)."), rec, v4_version(), rec, v4_version()))
  }
  sprintf(paste0("This project records weft %s in _weft.yml, and weft %s is installed. ",
                 "Run weft::use_weft() to update the files weft installed and the record (rule 9.5.4)."),
          rec, v4_version())
}

# A version that is not the installed one, whatever that is
v4_other_version <- function() if (identical(v4_version(), "0.0.1")) "0.0.2" else "0.0.1"

# ---- environment --------------------------------------------------------------------------------------

# For the calling test: no draft, no run id, no collection variable, no colour; QUARTO_PATH and the
# project's own R profile left to the caller. `libs = TRUE` puts the library holding the development weft
# first on R_LIBS (needed by any child process that loads weft: real renders, Rscript).
v4_env <- function(libs = FALSE, extra = NULL, env = parent.frame()) {
  vars <- c(WEFT_DRAFT = NA, WEFT_RUN = NA, WEFT_COLLECT = NA, NO_COLOR = "1", QUARTO_PATH = NA)
  if (libs) {
    lib <- weft_test_lib()
    if (nzchar(lib)) vars[["R_LIBS"]] <- paste(c(lib, .libPaths()), collapse = .Platform$path.sep)
  }
  for (n in names(extra)) vars[[n]] <- extra[[n]]
  withr::local_envvar(vars, .local_envir = env)
  invisible(NULL)
}

# ---- projects -----------------------------------------------------------------------------------------

# A project holding `files` (named list, lines). `git`: a repository with a baseline commit of everything
# (g_repo); otherwise a plain folder. `sub`: the project is the folder `proj/` of the repository or of a
# parent folder, so that there is something outside it to snapshot. `weft_yml`: lines of `_weft.yml`
# (NULL: none). `quarto_yml`: lines of `_quarto.yml` (NULL: none). Returns list(top, root, git).
v4_proj <- function(files = list(), git = FALSE, sub = FALSE, weft_yml = "draft: false",
                    quarto_yml = NULL, env = parent.frame()) {
  prefix <- if (sub) "proj/" else ""
  if (length(files)) names(files) <- paste0(prefix, names(files))
  if (!is.null(quarto_yml)) files[[paste0(prefix, "_quarto.yml")]] <- quarto_yml
  if (sub) files[["README.md"]] <- c("Outside the project.")
  if (git) {
    wf <- if (is.null(weft_yml)) character() else if (sub) "proj" else "."
    top <- g_repo(files, weft = wf, weft_yml = weft_yml %||% "draft: false", env = env)
  } else {
    top <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
    for (nm in names(files)) f3_write(file.path(top, nm), files[[nm]])
    if (!is.null(weft_yml)) f3_write(file.path(top, prefix, "_weft.yml"), weft_yml)
  }
  root <- if (sub) file.path(top, "proj") else top
  list(top = top, root = root, git = git)
}

# the ledger header line of a hand-written ledger (2d D3), `dict` a named list key -> 16 hex digits
v4_ledger_header <- function(source, output = sub("\\.[A-Za-z]+$", "", basename(source)),
                             dict = list(lim = "0000000000000000")) {
  d <- paste(sprintf("\"%s\":\"%s\"", names(dict), unlist(dict)), collapse = ",")
  sprintf("{\"weft\":\"ledger\",\"version\":1,\"source\":\"%s\",\"output\":\"%s\",\"dict\":{%s},\"files\":{},\"targets\":{}}",
          source, output, d)
}
V4_DICT_LIM <- c("lim: {value: 5, type: number, definition: \"The limit.\"}")

# ---- running verify() ---------------------------------------------------------------------------------

# Run verify(path = dir, ...) and keep everything it does. Returns
#   value     what it returned (NULL when it raised)
#   err       the condition it raised, or NULL
#   res       the weft_verify object: the value, or the `result` of the error
#   report    the lines it printed (messages), time normalised ("weft verify: T s")
#   warnings  the warnings raised (each a condition)
#   output    what it printed to stdout
v4_verify <- function(dir, ...) {
  out <- character()
  warns <- list()
  err <- NULL
  stdout <- utils::capture.output(
    value <- withCallingHandlers(
      tryCatch(verify(path = dir, ...), error = function(e) {
        err <<- e
        NULL
      }),
      message = function(m) {
        out <<- c(out, conditionMessage(m))
        invokeRestart("muffleMessage")
      },
      warning = function(w) {
        warns[[length(warns) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }))
  res <- if (is.null(err)) value else err$result
  list(value = value, err = err, res = res, report = g_norm_time(g_lines(out)),
       warnings = warns, output = stdout)
}

# what print() shows of a verify result, as lines
v4_print_lines <- function(res) {
  out <- character()
  txt <- utils::capture.output(
    withCallingHandlers(print(res), message = function(m) {
      out <<- c(out, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  g_norm_time(c(txt, g_lines(out)))
}

# a plain data frame of a weft_findings
v4_df <- function(x) as.data.frame(unclass(x), stringsAsFactors = FALSE)

# the status of one part of a verify result
v4_status <- function(res, part) res$parts$status[res$parts$part == part]
v4_detail <- function(res, part) res$parts$detail[res$parts$part == part]

# the line of the report that starts a part
v4_part_line <- function(report, part) grep(sprintf("^  %s\\s", part), report, value = TRUE)

# does the report hold a section heading starting `h`?
v4_has_section <- function(report, h) any(startsWith(report, h))

# the lines of a section: from its heading to the next heading or the time line
v4_section <- function(report, h) {
  i <- which(startsWith(report, h))
  if (!length(i)) return(character())
  heads <- which(Reduce(`|`, lapply(V4_SECTIONS, function(s) startsWith(report, s))) |
                   grepl("^weft verify: ", report))
  nxt <- heads[heads > i[1]]
  end <- if (length(nxt)) nxt[1] - 1L else length(report)
  report[i[1]:end]
}

# a tiny repository's commit sha, and its short form
v4_short <- function(sha) substr(sha, 1L, 7L)

# a project dir with a ledger of `source` planted whose header's dict hash cannot match V4_DICT_LIM
v4_plant_stale_ledger <- function(root, source = "a.qmd") {
  stem <- sub("\\.[A-Za-z]+$", "", source)
  f3_write(file.path(root, "_weft", "ledger", source, paste0(basename(stem), ".jsonl")),
           v4_ledger_header(source))
  f3_write(file.path(root, "dict.yml"), V4_DICT_LIM)
  invisible(root)
}

# ---- documents ----------------------------------------------------------------------------------------

# a document that holds a construct (a value) and nothing the static lints object to
V4_CONSTRUCT_DOC <- c("Intro paragraph.", "", "The reading is `r depth`{.num} metres.",
                      "", "---", "engine: knitr", "---")
# a document with no weft construct at all
V4_PLAIN_DOC <- c("Intro paragraph.", "", "Nothing computed here.")
# a tier-2 claim word in a sentence with a value (3b L20): one finding, rule claim-word
V4_CLAIM_WORD <- "All `r n` sites rose."

# ---- a stand-in quarto --------------------------------------------------------------------------------

# JSON of a stamp (what the pre-render and post-render scripts keep under .weft/stamps/), one failure per
# row of `failures` (each a list(kind, file, line, expr, detail)) or none. `run`: "this" writes the id of
# the run (the shell variable WEFT_RUN), otherwise the text given.
v4_stamp_json <- function(source, run = "this", failures = list(), checks = 1L) {
  esc <- function(x) gsub("`", "\\`", x, fixed = TRUE)   # the heredoc is not quoted: protect backticks
  fl <- vapply(failures, function(f) {
    sprintf("{\"source\":\"knit\",\"kind\":\"%s\",\"file\":\"%s\",\"line\":%d,\"chunk\":null,\"expr\":\"%s\",\"detail\":\"%s\",\"hint\":null,\"option\":null,\"chunk_line\":null}",
            f$kind, f$file, f$line, esc(f$expr), esc(f$detail))
  }, "")
  sprintf("{\"source\":\"%s\",\"run\":\"%s\",\"executed\":\"2026-11-13 08:19:24\",\"checks\":%d,\"failures\":[%s]}",
          source, if (identical(run, "this")) "$WEFT_RUN" else run, checks, paste(fl, collapse = ","))
}

# shell lines that write a stamp for `source`
v4_sh_stamp <- function(source, ...) {
  c("mkdir -p .weft/stamps",
    sprintf("cat > '.weft/stamps/%s.json' <<STAMP_EOF", source),
    v4_stamp_json(source, ...),
    "STAMP_EOF")
}

# shell lines that write a freeze entry (Quarto writes _freeze/<stem>/execute-results/html.json)
v4_sh_freeze <- function(stem, text = "NEW") {
  c(sprintf("mkdir -p '_freeze/%s/execute-results'", stem),
    sprintf("echo '%s' > '_freeze/%s/execute-results/html.json'", text, stem))
}

# A fake `quarto`, a shell script in a folder outside every project, found through QUARTO_PATH. It writes
# into `log` (a folder): `calls` (one line per call), `args` (one argument per line, the last call), `cwd`,
# `run` (the value of WEFT_RUN), and, when `observe` names freeze stems, `seen` (`<stem> present|absent` as
# the call saw `_freeze`), `manifest` (the backup's manifest, as the call saw it) and `backup` (the folders
# in .weft/freeze-backup, ls). `body` (lines of sh) runs after that; `status` is the exit status. Returns
# list(path, log). POSIX only.
#
# `quarto inspect ...` is answered, not logged in `calls` or `args` (it is appended to `inspects`, one line
# per call) and always exits 0: it prints the JSON of a project's render list, `files.input`, as absolute
# paths. `inspect` (relative paths) is the list it names; NULL: every .qmd, .Rmd and .rmd under the working
# directory whose path holds no component starting with `_` or `.`. Every other call is also appended to
# `renders`, one line each (`render a.qmd`).
v4_fake_quarto <- function(body = character(), status = 0L, observe = character(), out = character(),
                           inspect = NULL, env = parent.frame()) {
  skip_on_os("windows")
  log <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  bin <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  script <- c(
    "#!/bin/sh",
    sprintf("LOG='%s'", log),
    "if [ \"$1\" = inspect ]; then",
    "  echo \"$*\" >> \"$LOG/inspects\"",
    if (is.null(inspect)) {
      "  LIST=$(find . -type f \\( -name '*.qmd' -o -name '*.Rmd' -o -name '*.rmd' \\) | sed 's|^\\./||' | grep -v '^[_.]' | grep -v '/[_.]' | sort)"
    } else {
      sprintf("  LIST='%s'", paste(inspect, collapse = " "))
    },
    "  here=$(pwd -P)",
    "  printf '{\"dir\":\"%s\",\"engines\":[\"knitr\"],\"config\":{},\"files\":{\"input\":[' \"$here\"",
    "  sep=''",
    "  for f in $LIST; do printf '%s\"%s/%s\"' \"$sep\" \"$here\" \"$f\"; sep=','; done",
    "  printf '],\"resources\":[],\"config\":[]}}\\n'",
    "  exit 0",
    "fi",
    "echo \"$*\" >> \"$LOG/renders\"",
    "echo call >> \"$LOG/calls\"",
    "pwd > \"$LOG/cwd\"",
    "for a in \"$@\"; do echo \"$a\"; done > \"$LOG/args\"",
    "echo \"${WEFT_RUN}\" > \"$LOG/run\"",
    if (length(observe)) c(
      sprintf("for s in %s; do if [ -e \"_freeze/$s\" ]; then echo \"$s present\"; else echo \"$s absent\"; fi; done > \"$LOG/seen\"",
              paste(sprintf("'%s'", observe), collapse = " ")),
      "if [ -e .weft/freeze-backup/manifest ]; then cat .weft/freeze-backup/manifest > \"$LOG/manifest\"; fi",
      "if [ -d .weft/freeze-backup ]; then (cd .weft/freeze-backup && find . -type f | sort) > \"$LOG/backup\"; fi"),
    body,
    sprintf("echo '%s'", out),
    sprintf("exit %d", as.integer(status)))
  path <- file.path(bin, "quarto")
  writeLines(script[nzchar(script)], path)
  Sys.chmod(path, "755")
  withr::local_envvar(QUARTO_PATH = path, .local_envir = env)
  list(path = path, log = log)
}

v4_log <- function(fq, name) {
  f <- file.path(fq$log, name)
  if (file.exists(f)) readLines(f, warn = FALSE) else character()
}

# ---- freeze -------------------------------------------------------------------------------------------

# a snapshot of `_freeze` (relative file -> md5), empty when there is none
v4_freeze_snap <- function(root) g_snapshot(file.path(root, "_freeze"))

# plant freeze entries by hand: stems -> text
v4_plant_freeze <- function(root, stems = c("a", "b"), text = "OLD") {
  for (s in stems) {
    f3_write(file.path(root, "_freeze", s, "execute-results", "html.json"), sprintf("%s %s", text, s))
  }
  invisible(root)
}

v4_backup_dir <- function(root) file.path(root, ".weft", "freeze-backup")

# a snapshot of everything under `top` except the project `root` and the git directory
v4_outside_snap <- function(top, root) {
  f <- list.files(top, recursive = TRUE, all.files = TRUE, include.dirs = FALSE, no.. = TRUE)
  rootrel <- sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", top), "/?"), "", root)
  f <- f[!startsWith(f, paste0(rootrel, "/")) & !grepl("^\\.git(/|$)", f)]
  stats::setNames(unname(tools::md5sum(file.path(top, sort(f)))), sort(f))
}

# ---- real Quarto and rmarkdown fixtures ---------------------------------------------------------------

# A knitr document for the real renders: a setup chunk that activates weft and appends a line to
# `ran-<name>.txt` each time the document is executed (so a test counts executions), then a claim, a
# value, and `extra` lines.
v4_qdoc <- function(name, claim = "claim(depth, . > 5)", extra = NULL, ext = "qmd") {
  front <- if (ext == "qmd") {
    c("---", sprintf("title: \"%s\"", name), "engine: knitr", "---")
  } else {
    c("---", sprintf("title: \"%s\"", name), "output:", "  md_document:", "    variant: markdown", "---")
  }
  c(front, "",
    "```{r setup, include=FALSE}",
    "weft::weft_setup()",
    "depth <- 12.5",
    sprintf("cat(\"ran\\n\", file = \"ran-%s.txt\", append = TRUE)", name),
    "```", "",
    sprintf("Depth is `r %s` here.", claim), "",
    "Also `r depth`{.num}.", extra)
}

# how many times a document of the real fixtures was executed
v4_ran <- function(root, name) {
  f <- file.path(root, sprintf("ran-%s.txt", name))
  if (file.exists(f)) length(readLines(f, warn = FALSE)) else 0L
}

V4_QUARTO_YML <- c("project:", "  type: default", "format: html", "execute:", "  freeze: auto")

# A set-up Quarto project of `docs` (named list name -> lines, written as <name>.qmd) in `<parent>/proj`,
# the Quarto side installed by use_quarto(). Returns list(top, root).
v4_qproject <- function(docs, parent = tempfile("weft-4c-"), freeze = TRUE) {
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  parent <- normalizePath(parent, winslash = "/")
  files <- stats::setNames(docs, paste0(names(docs), ".qmd"))
  yml <- if (freeze) V4_QUARTO_YML else V4_QUARTO_YML[1:3]
  # the render order is given (docs order): without `render:` Quarto takes the files in the folder's order,
  # which differs between macOS and Linux
  if (length(docs) > 1L) yml <- append(yml, c("  render:", paste0("    - ", names(files))), after = 2L)
  files[["_quarto.yml"]] <- yml
  root <- mk_project(files, dir = file.path(parent, "proj"))
  f3_write(file.path(parent, "README.md"), "Outside the project.")
  list(top = parent, root = root)
}

# the stamp of a document under .weft/stamps (parsed), or NULL
v4_stamp <- function(root, file) {
  p <- file.path(root, ".weft", "stamps", paste0(file, ".json"))
  if (file.exists(p)) jsonlite::fromJSON(p, simplifyVector = FALSE) else NULL
}

# a set-up folder of rmarkdown documents (no _quarto.yml): `docs` named list file name -> lines
v4_rproject <- function(docs, parent = tempfile("weft-4c-")) {
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  parent <- normalizePath(parent, winslash = "/")
  root <- file.path(parent, "proj")
  dir.create(root)
  root <- normalizePath(root, winslash = "/")
  f3_write(file.path(root, "_weft.yml"), "draft: false")
  for (nm in names(docs)) f3_write(file.path(root, nm), docs[[nm]])
  f3_write(file.path(parent, "README.md"), "Outside the project.")
  list(top = parent, root = root)
}

# the pattern of a run id verify() makes (G25): verify-<YYYYmmddHHMMSS>-<pid>
V4_RUN_RE <- "^verify-[0-9]{14}-[0-9]+$"

# a dict.yml's lines: one entry per decision pointer in `...` (a, b, c, ...)
DICT_PTR <- function(...) {
  ptr <- c(...)
  vapply(seq_along(ptr), function(i) {
    sprintf("%s: {value: 1, type: number, definition: \"The %s.\", decision: \"%s\"}", letters[i], letters[i], ptr[i])
  }, "")
}

# ---- shared real renders ------------------------------------------------------------------------------
# Real Quarto renders are slow: each fixture runs once per test session, and the tests of its files read
# what it kept. Each function skips (without caching) when Quarto is not found.

v4_cache <- new.env()

# the line of the first line of `lines` that holds `frag`
v4_line_of <- function(lines, frag) grep(frag, lines, fixed = TRUE)[1]

# FIXTURE 1: a project of two clean documents a and b, rendered once by quarto itself (freezing them, the
# run id "run-first" given in WEFT_RUN), then verified. Keeps: q, first (the render), freeze_before (snapshot
# of _freeze before verify), r (v4_verify()), ran (executions of a and b after verify), outside (the files
# outside the project, before and after), stamps.
v4_real_pass <- function() {
  if (is.null(v4_cache$pass)) {
    skip_if_no_quarto()
    v4_env(libs = TRUE)
    q <- v4_qproject(list(a = v4_qdoc("a"), b = v4_qdoc("b")))
    withr::defer(unlink(q$top, recursive = TRUE), teardown_env())
    first <- qrender(q$root, env = c(WEFT_RUN = "run-first"))
    fx <- list(q = q, first = first, freeze_before = v4_freeze_snap(q$root),
               ran_before = c(a = v4_ran(q$root, "a"), b = v4_ran(q$root, "b")),
               stamps_before = list(a = v4_stamp(q$root, "a.qmd"), b = v4_stamp(q$root, "b.qmd")),
               outside_before = v4_outside_snap(q$top, q$root), pid = Sys.getpid())
    fx$r <- v4_verify(q$root)
    fx$ran <- c(a = v4_ran(q$root, "a"), b = v4_ran(q$root, "b"))
    fx$stamps <- list(a = v4_stamp(q$root, "a.qmd"), b = v4_stamp(q$root, "b.qmd"))
    fx$freeze_after <- v4_freeze_snap(q$root)
    fx$outside_after <- v4_outside_snap(q$top, q$root)
    v4_cache$pass <- fx
  }
  v4_cache$pass
}

# the failing document of fixture 2: a failing claim, a warned check and a missing value, one line each
V4_BAD_EXTRA <- c("", "Warned `r claim(depth, . > 100, level = \"warn\")` here.", "", "Missing `r NA_real_`{.num} here.")
v4_bad_doc <- function() v4_qdoc("b", claim = "claim(depth, . > 100)", extra = V4_BAD_EXTRA)

# FIXTURE 2: a (clean) and b (failing claim, warned check, missing value). Rendered once by quarto (which
# exits non-zero but writes both freeze entries), then verified: verify() fails. Keeps q, first, freeze_before,
# stamps_first, ran_before, r, ran, freeze_after, lines (of b.qmd).
v4_real_fail <- function() {
  if (is.null(v4_cache$fail)) {
    skip_if_no_quarto()
    v4_env(libs = TRUE)
    bad <- v4_bad_doc()
    q <- v4_qproject(list(a = v4_qdoc("a"), b = bad))
    withr::defer(unlink(q$top, recursive = TRUE), teardown_env())
    first <- qrender(q$root)
    fx <- list(q = q, first = first, bad = bad, freeze_before = v4_freeze_snap(q$root),
               ran_before = c(a = v4_ran(q$root, "a"), b = v4_ran(q$root, "b")),
               outside_before = v4_outside_snap(q$top, q$root))
    fx$r <- v4_verify(q$root)
    fx$ran <- c(a = v4_ran(q$root, "a"), b = v4_ran(q$root, "b"))
    fx$freeze_after <- v4_freeze_snap(q$root)
    fx$backup_exists <- dir.exists(v4_backup_dir(q$root))
    fx$stamps <- list(a = v4_stamp(q$root, "a.qmd"), b = v4_stamp(q$root, "b.qmd"))
    fx$outside_after <- v4_outside_snap(q$top, q$root)
    v4_cache$fail <- fx
  }
  v4_cache$fail
}

# FIXTURE 3: fixture 2's project after an interrupted run by hand: both freeze entries moved into
# .weft/freeze-backup with a manifest, a half-written entry left in _freeze/a. verify() runs again.
# Keeps r, freeze_after, backup_exists, ran, ran_before (as fixture 2's `ran`).
v4_real_interrupted <- function() {
  if (is.null(v4_cache$interrupted)) {
    fx2 <- v4_real_fail()
    v4_env(libs = TRUE)
    root <- fx2$q$root
    bk <- v4_backup_dir(root)
    dir.create(bk, recursive = TRUE)
    writeLines(c("a", "b"), file.path(bk, "manifest"))
    for (s in c("a", "b")) file.rename(file.path(root, "_freeze", s), file.path(bk, s))
    f3_write(file.path(root, "_freeze", "a", "partial.txt"), "half a render")
    fx <- list(q = fx2$q, freeze_before = fx2$freeze_after, ran_before = fx2$ran)
    fx$r <- v4_verify(root)
    fx$ran <- c(a = v4_ran(root, "a"), b = v4_ran(root, "b"))
    fx$freeze_after <- v4_freeze_snap(root)
    fx$backup_exists <- dir.exists(bk)
    v4_cache$interrupted <- fx
  }
  v4_cache$interrupted
}

# FIXTURE 4: the same project once more, verify(files = "a.qmd"): the failing b is not named.
v4_real_files <- function() {
  if (is.null(v4_cache$files)) {
    fx3 <- v4_real_interrupted()
    v4_env(libs = TRUE)
    root <- fx3$q$root
    fx <- list(q = fx3$q, freeze_before = v4_freeze_snap(root),
               ran_before = c(a = v4_ran(root, "a"), b = v4_ran(root, "b")))
    fx$r <- v4_verify(root, files = "a.qmd")
    fx$ran <- c(a = v4_ran(root, "a"), b = v4_ran(root, "b"))
    fx$freeze_after <- v4_freeze_snap(root)
    fx$backup_exists <- dir.exists(v4_backup_dir(root))
    v4_cache$files <- fx
  }
  v4_cache$files
}

# the entries of a snapshot under one stem ("a" -> every file below a/)
v4_snap_of <- function(snap, stem) snap[startsWith(names(snap), paste0(stem, "/"))]
