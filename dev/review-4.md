# Review of stage 4 (commit def127c)

Independent review of the gate, the installers, `verify()` and `use_setup()`.
Every finding below was reproduced in temporary repositories under the
session scratchpad, with weft installed from this commit into a scratch
library, git isolated (`GIT_CONFIG_GLOBAL` an empty file, `HOME` a temporary
folder) and Quarto 1.11.9, git 2.50.1, R 4.4 on macOS. Nothing was run
against this repository. Suspicions that did not reproduce were dropped.

Counts: 3 high, 8 medium, 6 low.

## High

### 1. `verify(files = )` deletes the frozen results of a document it did not verify

- Severity: high (data loss).
- Where: `R/verify-render.R`, `freeze_backup()`, `verify_render()`.
- Reproduction: a Quarto project with `execute: freeze: auto`, documents
  `chapters.qmd` and `chapters/c.qmd`, both with an R chunk, set up with
  `use_weft()`. `quarto render` once: `_freeze/chapters/execute-results` and
  `_freeze/chapters/c/execute-results` exist. Then
  `weft::verify(files = "chapters.qmd")`.
- What happened: the verdict is `passed`, and `_freeze/chapters/c/` is gone.
  Quarto keeps a document's freeze at `_freeze/<stem>/`, so the stem
  `chapters` is the parent folder of the stem `chapters/c`. `freeze_backup()`
  moves the whole `_freeze/chapters` folder, the child's entry with it, and the
  successful render deletes the backup. `chapters/c.qmd` was never rendered, so
  nothing writes its entry back.
- Design: G29 "the freeze backup holds only their entries"; G25.4.
- Direction: move only `<stem>/execute-results` (and the stem's own files),
  never a folder that holds another document's stem.

### 2. A failed render with nested stems destroys both documents' frozen results instead of restoring them

- Severity: high (data loss on the path whose whole purpose is to restore).
- Where: `R/verify-render.R`, `freeze_backup()` (ignores `file.rename()`'s
  result), `freeze_restore()`.
- Reproduction: the project of finding 1 after a fresh `quarto render`; a
  stand-in Quarto that prints and exits 1 (`QUARTO_PATH=<script>`); then
  `weft::verify(files = c("chapters/c.qmd", "chapters.qmd"))`. The same happens
  with the real Quarto (see finding 4, which makes that render fail).
- What happened: the backup moves `_freeze/chapters/c` first, then
  `file.rename("_freeze/chapters", backup/chapters)` fails with "Directory not
  empty" (a warning; the result is not checked). The render fails, and
  `freeze_restore()` puts `chapters/c` back, then for the stem `chapters`
  deletes `_freeze/chapters` (which now holds the restored child and the
  parent's own results that never moved) and renames the near-empty backup
  folder into its place. Afterwards `_freeze/chapters/` is an empty folder:
  both `execute-results/html.json` files are lost.
- Design: G25 step 4 "otherwise ... restore it as in 1"; Q3.
- Direction: check every `file.rename()`; back up and restore per
  `execute-results` folder; in restore never delete a target that the backup
  does not hold.

### 3. `verify()` writes into the user's R cache folder

- Severity: high under this review's scale (a write outside the project); the
  content is weft's udunits table cache, already written elsewhere by
  decision 63, so the harm is small and the fix is local.
- Where: `R/verify.R`, `verify_config()` calls `read_config()`.
- Reproduction: `R_USER_CACHE_DIR=$(mktemp -d)`, a project with `_weft.yml`,
  `Rscript -e 'weft::verify(static = TRUE)'`. Afterwards
  `$R_USER_CACHE_DIR/R/weft/udunits-<hash>.rds` exists. `lints()` on the same
  project writes nothing there.
- What happened: `read_config()` installs the unit tables and saves the
  udunits cache. It also leaves the units it installed registered in the units
  package for the rest of the session (only `weft_env$units` is put back).
- Design: G1 "Nothing here calls `read_config()` (it installs units and may
  write the units cache)"; G3.
- Direction: read `strict`, `verify_skip`, `draft`, `ledger` and `decisions`
  through `lint_config()` plus `validate_verify_config()`.

## Medium

### 4. `verify(files = )` with two or more documents always fails under Quarto

- Severity: medium (wrong verdict: fails when all is well).
- Where: `R/verify-render.R`, `verify_render()`, `verify_run(q, c("render", files_rel), ...)`.
- Reproduction: the project of finding 1,
  `weft::verify(files = c("chapters/c.qmd", "chapters.qmd"))`.
- What happened: `quarto render a.qmd b.qmd` renders `a.qmd` and passes
  `b.qmd` to Pandoc as an argument: "chapters.qmd: withBinaryFile: does not
  exist ... ERROR: Pandoc conversion failed". The render part fails, every
  file counts as not executed. (With the files in the other order the freeze
  loss of finding 2 follows.)
- Design: G29; reading 7 for 4c ("Quarto gets `render`, or `render` and the
  files as passed") pins the call only against a stand-in Quarto.
- Direction: one `quarto render <file>` per document, or a render list.

### 5. A folder of `.qmd` files without `_quarto.yml` can never pass `verify()`

- Severity: medium (every such project fails; the report claims the documents
  were rendered).
- Where: `R/verify-render.R`, `verify_render()`.
- Reproduction: a folder with `_weft.yml`, `a.qmd` and `b.qmd`, each with
  front-matter activation, an R chunk and `` `r x` ``; `weft::verify()`.
- What happened: `quarto render` with no input in a folder that is not a
  Quarto project exits 0 and renders nothing (checked by hand: no output
  files). The report says `render     2 documents rendered; 0 failures, 2 not
  executed` and fails both documents as "served from freeze, or knit without
  weft active". The lone-document case (H19's daily report) is the same.
- Design: G25 names `quarto render` "(no files)" for "`.qmd` files" without a
  `_quarto.yml`; G26 expects each verified document to be stamped. The two
  cannot both hold.
- Direction: without `_quarto.yml`, render each document by name; say
  "rendered" only for documents that were.

### 6. A document outside a book's (or website's) render list fails `verify()`

- Severity: medium (false failure on a common layout).
- Where: `R/verify.R` (`docs <- lint_files_under(root)`), `R/verify-render.R`
  (`unexec`).
- Reproduction: `_quarto.yml` with `project: type: book` and
  `chapters: [index.qmd]`; `index.qmd` and `notes.qmd`, each with an R chunk
  and a value; `use_weft()`; `weft::verify()`.
- What happened: Quarto renders only `index.qmd`; `notes.qmd` holds a
  construct and has no stamp, so the render part fails with
  `notes.qmd: not executed in this render`, while the detail says "2
  documents rendered".
- Design: G26 (every verified document with a construct needs a stamp); the
  design does not consider Quarto's render list.
- Direction: verify the documents Quarto renders (or note the others as not
  rendered by the project, failing nothing).

### 7. Nested projects count every finding and every removed construct twice

- Severity: medium (wrong count; the commit needs `Weft-Removed: 2N` and the
  report lists each item twice).
- Where: `R/gate.R`, `gate()` / `gate_side_entries()` (a project's entries
  include those of any project below it).
- Reproduction: a repository with `_weft.yml` at the top and `sub/_weft.yml`;
  `sub/x.qmd` holds `` `r x` ``; commit; replace it with `45%`; `git commit`.
- What happened: "2 findings added" listing the same `sub/x.qmd` line 5 twice,
  and "2 weft constructs removed ... Weft-Removed: 2", listing `` `r x` ``
  twice, for one finding and one removal.
- Design: G7 "The gate judges each project on its own"; G12.
- Direction: leave out of a project the subtree of any deeper `_weft.yml`.

### 8. Renaming a `.qmd` that lacks `engine: knitr` is refused as a finding added

- Severity: medium (common false refusal on a pure rename).
- Where: `R/gate.R`, `gate_judge_project()` keys findings by rule and text;
  the `engine` rule (`R/lint-doc.R`) sets `text = f`, the file's path.
- Reproduction: `_weft.yml`; `a.qmd` with front matter `title: A` and
  `[a site | # sites]{n="k"}`; commit; hook installed; `git mv a.qmd b.qmd`;
  `git commit`.
- What happened: `1 finding added that HEAD did not hold ... b.qmd  1  engine
  b.qmd holds weft constructs but is not marked engine: knitr`. The same key
  existed at HEAD under the name `a.qmd`.
- Design: G10 counts by rule and text; §21 and the 4a tests say a file renamed
  passes.
- Direction: give the `engine` finding a path-free text (or key it by blob).

### 9. The gate cache serves old verdicts after weft is reinstalled at the same version

- Severity: medium (stale verdicts; the CI template and installs from GitHub
  stay at 0.0.0.9000 across many commits).
- Where: `R/gate-cache.R`, `gate_versions()` (package version and R version
  only); used by every key in `gate_side_keys()`.
- Reproduction: two builds of this commit, the second with the `numeral`
  message text changed, installed to two libraries (both 0.0.0.9000). Stage
  `45%` in a repository; `gate()` with the first library; then `gate()` with
  the second.
- What happened: the second run prints the first build's message ("is a
  number typed in prose"); after deleting `.git/weft/` it prints the new one.
  A rule fixed or tightened in a reinstall is not applied to any blob already
  cached.
- Design: G14 (weft version in the keys) and H13 "versions invalidate".
- Direction: key on something that changes with the code, such as the md5 of
  the installed package's `R/weft.rdb` or `Packaged`/`RemoteSha` from
  `DESCRIPTION`.

### 10. `use_weft()` leaves a half-installed project and says "Nothing was written"

- Severity: medium (misleading report and partial state).
- Where: `R/use-weft.R`, `use_weft()`; `R/install.R`, `write_items()`.
- Reproduction: a git repository holding a Quarto project, `chmod 555
  .git/hooks`, `weft::use_weft()`.
- What happened: the plan is printed, then `_weft.yml`, `.Rprofile`, the
  document edit, `_quarto.yml`, the extension and scripts, `dict.yml` and the
  schema are written; the hook write fails with "weft could not write
  .../.git/hooks/commit-msg. Nothing was written." `AGENTS.md` and the skill
  are not written. The `weft_version` line already records the new version.
- Design: G38 "when any step cannot be done safely ... it writes nothing";
  G41 "a file is never reported written that was not" (here the reverse:
  ten files reported as not written).
- Direction: check that every target folder is writable while planning, and
  have `use_weft()` report what earlier steps wrote when a later one fails.

### 11. A hook that has lost its execute bit is reported as installed and never repaired

- Severity: medium (the gate silently stops running; `status()` says ok).
- Where: `R/install.R`, `whole_state()` / `file_status()`;
  `R/use-weft.R`, `status_hook()`.
- Reproduction: install the hook, `chmod 644 .git/hooks/commit-msg`, run
  `weft::use_hooks()` and `weft::status()`, then commit a rename that the
  gate refuses (finding 8).
- What happened: `use_hooks()` prints "Nothing to change"; `status()` prints
  `hooks  ok`; git prints "hint: The '.git/hooks/commit-msg' hook was ignored
  because it's not set as executable" and the commit is made.
- Design: G22 (mode 755); G39 (`status()` reports the hook's state).
- Direction: treat a non-executable hook as `replace` (or `chmod` on `keep`)
  and report it in `status()`.

## Low

### 12. `verify()` counts listed instances, not findings added

- Where: `R/verify.R`, `verify_lints()` detail and `reasons`.
- Reproduction: a committed `a.qmd` line `We saw `r x` and 45% today.`; edit
  it to `We saw 45% and 45% today.`; `weft::verify(static = TRUE)`.
- What happened: `0 construct errors, 2 added`, and both instances listed;
  one finding was added (base 1, new 2). The gate's header uses
  `excess$new - excess$base` and would say 1.
- Design: G10 (excess per key), H16 (which instances are listed).
- Direction: count the excess, list the instances.

### 13. The CI template puts the project path into shell and R strings unquoted

- Where: `R/use-ci.R`, `ci_plan()`; `inst/ci/weft.yml`.
- Reproduction: by reading the filled template: `@PATH@` is substituted raw
  into `Rscript ... -e "weft::verify(..., path = '@PATH@')"`. A project folder
  named `it's` gives an R syntax error in CI; one holding `$(...)` or a
  backquote is expanded by the shell inside the double quotes.
- Design: G33.
- Direction: pass the path through an `env:` entry and read it with
  `Sys.getenv()`.

### 14. A project `.Renviron` overrides the libraries the hook records

- Where: `inst/hooks/commit-msg` (runs `Rscript --no-init-file`, not
  `--no-environ`).
- Reproduction: in a folder holding `.Renviron` with `R_LIBS=/nonexistent`,
  `R_LIBS=/tmp/abc Rscript --no-init-file -e 'cat(Sys.getenv("R_LIBS"))'`
  prints `/nonexistent`. The hook runs at the work tree's top, so a project
  `.Renviron` that sets `R_LIBS` replaces `@LIBS@`.
- Design: G21, H31 (record `.libPaths()` so the hook finds weft).
- Direction: add `--no-environ`, or set `R_LIBS` inside the `-e` expression
  with `.libPaths()`.

### 15. `status()` says activation is ok when R will not read the project `.Rprofile`

- Where: `R/use-weft.R`, `status_activation()`.
- Reproduction: with `R_PROFILE_USER` set (seen here by accident with it set
  to an empty string) a `quarto render` of a set-up project writes no stamps,
  and `verify()` fails every document as not executed; `status()` reports
  `activation  ok  route found (the .Rprofile)`.
- Design: G36, reading 7 for 4d.
- Direction: in `status()`, mark the route `off` (or warn) when
  `R_PROFILE_USER` is set.

### 16. The installers rewrite CRLF files as LF

- Where: `R/setup.R`, `use_setup()`; `R/use-agent-docs.R`; any line edit
  through `readLines()` and `writeLines()`.
- Reproduction: `AGENTS.md`, `.Rprofile` and `_weft.yml` with CRLF endings;
  `use_agent_docs()` and `use_setup()`. Afterwards none holds a CR: every line
  of the author's text shows as changed.
- Design: G40 "Files weft edits by line ... only gain lines"; G34 "the rest of
  the file is never touched".
- Direction: keep the file's line ending when appending.

### 17. The pre-commit snippet names `.git/weft/commit-msg`

- Where: `R/use-hooks.R`, `hooks_plan()`.
- What happened: in a linked worktree `.git` is a file, so
  `entry: sh .git/weft/commit-msg` does not exist there; the plain-hook line
  printed just above uses `$(git rev-parse --git-common-dir)` and is right.
- Design: G22.
- Direction: use the same `git rev-parse --git-common-dir` form in the entry.

## Looked at and found sound

- The gate judges the index: `git commit <path>` with another file's bad
  change staged passes; `git commit -a` and a commit from a subfolder judge
  the right content; a linked worktree runs the hook and shares the cache.
- CRLF conversion and an added BOM on a document with values, spans and a
  `claim()` add and remove nothing.
- File names with a newline, quotes and `$` are listed, materialised and
  reported correctly.
- Adopting weft in a repository whose documents already hold findings:
  `use_weft()` then `git commit` of everything passes.
- `!expr` in `_weft.yml` is not evaluated by the gate or `lints()` (yaml
  2.3.12 refuses it), so committed text does not run in the hook.
- Hook quoting of the `Rscript` and library paths, `--no-init-file`, and the
  missing-R message; `$1` is passed as an argument, never evaluated.
- `verify()` under rmarkdown, including a document in a subfolder (stamp
  `sub__b.Rmd.json` found), and in a project that is a subfolder of the
  repository (prefix, added lines, removed constructs).
- `verify()` with `files = NULL`: radix order puts `x.qmd` before `x/y.qmd`,
  so the backup and restore of nested stems happen in a safe order.
- `use_setup()` on a `.qmd` with a UTF-8 BOM edits the front matter
  correctly.
- `AGENTS.md` block handling (start without end left alone, also under
  `overwrite`); foreign hooks and `core.hooksPath` left alone.

## Windows (not tested)

- `system2(..., env = )` is documented as not supported on Windows except
  for programs that take `NAME=value` on their command line: every gate git
  call (`GIT_OPTIONAL_LOCKS=0`) and verify's Quarto call (`WEFT_RUN`) would
  fail, blocking every commit.
- Tracked names that Windows cannot hold (`:`, `?`, `"`, a trailing dot or
  space) make `gate_materialise()` fail; two names differing only in case
  collide (also on macOS's default file system).
- `file.rename()` of `_freeze` entries fails when a file is open or the
  backup is on another drive; the failure is not checked (finding 2).
- The hook relies on Git for Windows' `sh` and `command -v Rscript`; the
  recorded `Rscript.exe` path and `;`-joined `R_LIBS` were not exercised.
- `~/.Rprofile` in the new project `.Rprofile` is R's `HOME`, usually
  Documents, which matches R's own lookup but not a user's expectation.

## Design questions

- G12 counts constructs net: deleting a `claim()` and adding any value in the
  same commit needs no trailer. Rule 6.3 is about checks removed; a removed
  check can hide behind an added value.
- H8 (amend): an amend that removes one more construct after a commit that
  removed two is told to write `Weft-Removed: 1`, so the final commit, which
  removes three from its parent, carries a trailer of 1.
- G25 step 1 restores a killed run's backup over whatever `_freeze` holds
  now. After a later plain `quarto render`, the stale entries replace fresh
  ones; with `files =` naming other documents they stay replaced.
- G35/`use_quarto()`: the filter, the extension and `_weft/pre-render.R` and
  `post-render.R` carry no `weft-file` marker and are replaced whenever they
  differ, so an author's edit to them is lost silently, unlike G40 files.
- G23: `since` defaults to `HEAD` whenever the repository has a commit, so a
  project that was never committed (a new folder in an existing repository)
  fails `verify()` on every tolerated finding as "added".
- G7 makes every folder holding `_weft.yml` at any depth a project, which in
  an R package repository includes test fixtures that hold findings on
  purpose; together with finding 7 a fixture under a project is counted
  twice.
- G18: when `_weft.yml` does not read at `HEAD`, the code also skips the
  removal count, so such a commit can remove constructs without a trailer.
  The design speaks only of findings.

## Rulings (orchestrator, 13 Nov, under delegation)

Findings 1 to 17 are accepted and fixed as the review directs, with
these readings:

- 1, 2: the backup, the restore and the delete touch only the entries
  of the documents being verified. For a stem `s` that is everything
  under `_freeze/s/` except a folder that is another document's own
  stem (`s/x` where `s/x.qmd` or `.Rmd` is a document). Every move is
  checked; a move that fails stops `verify()` before the render with a
  `weft_verify_error` and puts back what was already moved. The
  restore never deletes what the backup does not hold.
- 3: `gate()`, `verify()`, `status()` and the installers read the
  configuration without writing the units cache. They may read it.
- 4: several `files` are rendered one `quarto render <file>` at a time.
- 5: with no `_quarto.yml`, each document is rendered by name. The
  report counts the documents that were rendered.
- 6: `verify()` takes the render list from `quarto inspect`. A
  document outside it is linted, is not expected to have run, and is
  named in a report line "not in the render list".
- 7: a document belongs to the innermost project that holds it, for
  findings and for the construct count.
- 8: the gate follows a rename (`git diff -M`): findings of the old
  path are compared with those of the new one, and a finding whose
  text is the file's own name (`engine`) is keyed without the name.
- 9: the cache key carries the version and the identity of the
  installed code: the md5 of the installed `R/weft.rdb`, or under
  `load_all()` the newest modification time of the source files.
- 10: `use_weft()` undoes a failed run: files it created are removed
  and files it changed are put back from copies it took. The message
  says what was undone, and never "Nothing was written" unless that is
  true.
- 11: a hook that is not executable is `outdated` in `status()` with
  the detail "not executable", and `use_hooks()` repairs the mode.
- 16: an installer that rewrites an existing file keeps its line
  endings.

Design questions:

1. G12 is changed: claims are counted apart. N is the sum over
   projects of the positive part of claims removed less claims added,
   plus the positive part of values and spans removed less values and
   spans added. A deleted `claim()` no longer hides behind an added
   value; a value turned into a span still removes nothing.
2. H8 (amend) stands: the hook cannot tell an amend from a commit, and
   the reading fixed for 4b judges against the amended HEAD. Recorded
   in `dev/open-findings.md`.
3. G25 step 1 is changed: the manifest records the run id of the
   run that took the backup. A backup left by a killed run is restored
   for a stem unless the document's stamp carries another run id, that
   is, a later complete render made the current entry; then the entry
   is kept, that stem's backup is discarded, and a note says so. File
   times cannot decide it, because the killed run's own half-written
   files are newer than its manifest.
4. The files `use_quarto()` installs carry no marker and are replaced
   when they differ. Left as built (stage 1); recorded in
   `dev/open-findings.md`.
5. G23 is changed: when the project's `_weft.yml` does not exist at
   `since`, nothing counts as added (the first commit is the baseline,
   as F6 has it for the gate), and the report says so.
6. G7 stands (every folder with `_weft.yml` is a project). With
   finding 7 fixed a fixture is counted once. Recorded in
   `dev/open-findings.md`.
7. G18 is narrowed: when `_weft.yml` does not read at HEAD the
   findings comparison is skipped, and the removal count still runs.
