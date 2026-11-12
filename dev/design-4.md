# Stage 4 — the commit gate, `verify()` and the installers

Written before any test or code. It is the build contract for stage 4 of
`PACKAGE-SCOPING.md` §22 (§6, §8, 9.1.2–9.1.4, 9.2, 9.3, 9.4.3, 9.5.3, 9.5.4) and
for the item held back from 1c (`.Rprofile` activation and `use_setup()`). It
builds on stages 1–3 as they will be on `main`: `lints()`, `lint_rules()`,
`read_source()` and `lint_config()` of `dev/design-3.md` (L2–L9), the stamps
and collection file (`R/collect.R`), `use_quarto()` and its YAML text editor
(`R/use.R`), `ledger_state()` and the read-only git helpers (`R/changes.R`,
`R/ledger.R`), `check_decisions()` (`R/decisions.R`), `use_dictionary()`.
Robin delegated the choices; each is a decision in §3 with its alternatives.
Every example is invented.

## What was measured

git 2.50.1, R 4.4.3, macOS, a scratch repository, `GIT_CONFIG_GLOBAL=/dev/null`.

1. `commit-msg` gets the message file as `$1` (`.git/COMMIT_EDITMSG`;
   `.git/MERGE_MSG` for a merge), runs at the work tree's top, and inherits
   `GIT_INDEX_FILE` (`.git/index.lock` under `git commit -a`).
2. `--amend` runs it with nothing to tell it from a commit. `git merge` runs
   it with `MERGE_HEAD` present. `git cherry-pick` and `git rebase` do not
   run it (Q17).
3. The message file keeps `#` lines (a template, the editor's status block);
   `git interpret-trailers --parse` skips them and keeps keys' case.
4. `Rscript --no-init-file -e '<expr>' a/b.txt` gives `commandArgs(TRUE) ==
   "a/b.txt"`. R starts in 0.11 s; with weft's Imports loaded, 0.35 s.

## 1. Scope

Default is build. "Pkg" is the work package of §4.

| Rule | What | Pkg | |
|---|---|---|---|
| 6.1.1–6.1.4, 6.1.6–6.1.8 | the `commit-msg` hook, staged versions against `HEAD`, trailers, static only, the cache, one timed report, `--no-verify` | 4a, 4b | build |
| 6.1.5 | record R's path | 4b | build; Pandoc's path: drop (H10) |
| 6.2.1–6.2.7 | what stops a commit; counting by rule and text; cross-file rules; tolerance; tier 2 not judged | 4a | build |
| 6.3.1–6.3.6 | construct count, `Weft-Removed: N`, the report | 4a | build |
| 8.1–8.3 | `verify()`: steps, totals, strict, parts off, draft refusal, `files`, `since`, `static`, the freeze sequence, rmarkdown | 4c | build |
| 8.4.1 | `use_ci()` | 4b | build (GitHub Actions only) |
| 2.9.3, 7.2.3, 4.5.2 | verify fails on a frozen document, on stale ledger entries, on unresolved pointers | 4c | build |
| 9.1.2, 9.1.4 | keys `strict`, `verify_skip`, `weft_version`; `verify_skip` project-only | 4c | build (G31) |
| 9.2.1 row 2, 9.2.7, 9.2.8 | `.Rprofile` route, `use_setup()`, the filter under rmarkdown | 4d | build; command-line tests only (G37) |
| 9.3.1 | `use_weft()`, `use_setup()`, `use_hooks()`, `use_ci()`, `use_agent_docs()` | 4b, 4d | build |
| 9.3.3 | hook template, CI template, the Claude skill in `inst/` | 4b | build |
| 9.4.3 | the hook ignores draft mode; `verify()` refuses it | 4a, 4c | build |
| 9.5.3, 9.5.4 | `status()`; version record and warning | 4b, 4c, 4d | build |
| §21 "real manuscript history" (Q18) | edits from a real history added to the fixture | — | defer: needs the git-ignored trial copies; run as a trial after 4a, counts only in the build log |
| CI other than GitHub Actions | | — | defer: 8.4.1 names GitHub as the default; no second service asked for |
| Render buttons, interactive chunks, Windows, real `renv` | | — | cannot be tested here (build prompt "Limits"); stays in §19 |

## 2. Contract

### Exports, errors, dependencies

- **G1.** New exports: `gate()` (4a); `verify()` (4c); `use_setup()` (4d);
  `use_hooks()`, `use_ci()`, `use_agent_docs()`, `use_weft()`, `status()`
  (4b). No new Imports or Suggests: git, Quarto and Rscript are programs found
  at run time; hashes are `cli::hash_md5()`; `rmarkdown` and `quarto` stay
  Suggests. Nothing here calls `read_config()` (it installs units and may
  write the units cache): settings are read by `lint_config()` or by
  `yaml::read_yaml()` of `_weft.yml`.
- **G2. Errors.** `weft_gate_error` (gate: no git, not a work tree, a git
  command failing); `weft_verify_error` (draft refusal, bad arguments, and the
  failure signal of G27); `weft_tool_error` for the installers, as
  `use_dictionary()`; `weft_config_error` (G31); warning
  `weft_version_warning` (G32). All carry `weft_error`/`weft_warning`.
- **G3. Writes.** Every writer here writes inside the project root, except
  (a) the hook, the hook's script copy and the cache, inside the
  repository's git directory (6.1.6), (b) `use_ci()`'s workflow, at the
  repository's top (H23), and (c) temporary folders under `tempdir()`,
  removed before the function returns. git is always called as
  `git -C <dir> -c core.quotepath=false ...`, with `-z` where paths are
  listed, and only these subcommands: `rev-parse`, `ls-files`, `ls-tree`,
  `cat-file --batch`, `diff`, `interpret-trailers`, `config --get`,
  `remote get-url`. None writes to the repository. No network, except
  `check_decisions()`'s GitHub route inside `verify()`.

### Requests to stage 3 (before 3a is built)

- **G4.** Three small additions to stage 3's files, made by stage 3, not 4:
  (a) `lints()` gets each file's `weft_source` through `lint_read(path, root,
  cfg)`, `(weft_env$lint_reader %||% read_source)(path, root, cfg)` — the
  gate's cache sets `weft_env$lint_reader` for the length of one call (H1);
  (b) with `files` given, file-scope rules run on those files only (findings
  as L2 says); project-scope rules run on every file; (c) the project-only
  setting names that `config-place` and `read_config()` check live in one
  internal `project_only_settings()` in `R/config.R`, returning
  `c("draft", "decisions", "verify_skip")`. A rule whose `lint_rules()$scope`
  is `"file"` must give findings that depend only on its file, the project's
  non-document files and the set of paths in the project. Without (a), 4a
  builds with the cache layer `src` off and the timing test G15 is recorded,
  not passed.

### Sides

- **G5. A side** is one version of a project: a commit (`HEAD`, a parent,
  `since`), the index, or the working tree (verify only). For a commit or the
  index the gate lists the tracked paths under the project root with their
  blob ids: `git ls-tree -r -z --full-tree <commit> -- <prefix>` or
  `git ls-files -s -z -- <prefix>` (stage 0 only; the inherited
  `GIT_INDEX_FILE` decides which index). Symbolic links (mode 120000) and
  submodules (160000) are listed as paths with no content.
- **G6. Materialising.** A side is written to a temporary folder holding the
  project subtree: **content** (from one `git cat-file --batch` call, bytes
  as stored) for every tracked file whose name ends `.qmd .Rmd .rmd .md .yml
  .yaml .json .bib .bibtex` or is `.Rprofile`, up to 5 MB each; an **empty
  placeholder** for every other tracked path, so link targets exist as in a
  clone (H34); nothing under the targets store (`_targets/`, or `_targets.yaml`'s
  `main: store:`). A larger content file gets a placeholder and a note. The
  untracked and ignored files of the work tree are never seen. `lints()` runs
  on that folder with `tier = 1`; its root is the temporary project root.
- **G7. Projects.** A project is a folder holding `_weft.yml` on either side
  (any depth in the repository). The gate judges each project on its own; a
  repository with none passes with the note `no weft project (no _weft.yml)`.
  Files outside every project are not read.
- **G8. Documents and changes.** A side's documents are L3's file set. A
  document is *changed* when its path is on one side only or its blob differs.
  A *project file* is any other content file of G6; when any differs between
  the sides (or the list of paths differs), the cache layer `file` misses for
  every document (G14).

### Judging (6.2, 6.3)

Let *base* be `HEAD` (gate) or `since` (verify), and *new* the index (gate)
or the working tree (verify). Findings are `lints(tier = 1)` minus rule
`tar-name` (H5). Construct-error rules are `construct`, `block-start`, `read`.

- **G9. Construct errors** (6.2.1.1): every finding of those rules on the new
  side in a changed document (gate) or a verified document (verify) fails,
  whether or not base held it.
- **G10. Findings added** (6.2.2–6.2.4): over the whole project, for each key
  (`rule`, `text` with white space collapsed), `excess = n_new - n_base`.
  Any key with `excess > 0` fails. Unchanged documents give the same findings
  on both sides and cancel, so this is 6.2.3's sum over the commit; a finding
  in an unchanged chapter caused by the commit (an anchor removed) counts
  (6.2.4), and so does one caused by a changed project file (a label word
  dropped from `_weft.yml`; H3). The report lists, for each such key, the new
  side's instances in changed documents on lines added since base (G16); when
  none is on an added line, every new-side instance of the key.
- **G11. Constructs** (6.3.1): `count_constructs(src)` returns one row per
  construct, `file, line, kind, text`: the scanner rows of kind `value`,
  `bare`, `n`, `if`, `sign`, `list`, `cite`, `text` in every context
  (`kind` reported as `value` or `span`), and each `claim()` or
  `weft::claim()` call (`kind` `claim`) found by `getParseData()` in the code
  of every R chunk, any `eval` (H32), and in every value and governor
  expression. `text` is the construct as written (`substr(text, fstart,
  fend)`; for a call, its source text), white space collapsed. A value whose
  expression holds `claim()` gives two rows. `.weft-literal` and link rows do
  not count.
- **G12. Removed** (6.3.2–6.3.4): `N = total_base - total_new` over the
  project. When `N > 0` the message must carry `Weft-Removed: N` (G13); else
  any trailer is ignored (6.3.5). The listing: for each text held `b` times
  on base and `n < b` times on new, the last `b - n` of its base instances in
  file and line order, each with its base file and line, all sorted by file
  then line (6.3.4: longer than N when the commit also adds).
- **G13. The trailer.** `git interpret-trailers --parse <message file>`;
  the key matched without regard to case; with several, the last counts; the
  value must be a whole number in digits (`3`, ` 3 `), anything else counts
  as a wrong number. No message file (`gate()` called by hand) is a message
  with no trailer.
- **G14. The cache** (6.1.6): `<git common dir>/weft/cache/`, files
  `<layer>-<key>.rds`, three layers, keys `cli::hash_md5()` of `|`-joined
  fields, all known from the listing (G5) without reading a file:
  - `src` (via G4a): weft version, R version, document path relative to the
    project root, its blob id, the blobs of `_weft.yml` and `_quarto.yml`
    (or `""`): the inputs of `lint_config()` and of `lang` → the
    `weft_source`. The reader maps the temporary path back to its blob.
  - `file`: the `src` key and the side's project fingerprint (sorted
    `path blob` lines of every project file of G8, and the hash of the sorted
    path list) → the document's file-scope findings and its construct rows.
  - `proj`: weft version and the side's full fingerprint (every content
    blob, the path list) → the project-scope findings.
  On a side, `lints(files = <documents missing from file>, rules = <tier-1
  file-scope rules>)` and, when `proj` misses, `lints(rules = <tier-1
  project-scope rules>)`; a side whose entries all hit is not materialised.
  Writes go to a temporary name in the folder, then `file.rename()`. An entry
  that will not read is a miss, and is deleted. A hit touches the file's
  time. After a run with more than 1,000 entries the oldest are deleted down
  to 800. A folder that cannot be written means no cache, and a note.
  `options(weft.gate_cache = FALSE)` turns it off (tests).
- **G15. Time.** The report's last line is the elapsed time. Budget: a
  commit changing one 300-line chapter of a ten-chapter project, cache warm,
  ≤ 1.5 s end to end through `git commit` on the development Mac; the test
  allows 3 s and is `skip_on_cran()` and skipped on CI.
- **G16. Added lines.** `git diff -U0 --no-color --no-ext-diff <base blob>
  <new blob>`; hunks `+c,d` give lines `c` to `c+d-1` (no `d` is 1). A
  document with no base blob: every line.
- **G17. History cases.**
  - *Unborn `HEAD`* (`rev-parse -q --verify HEAD^{commit}` fails): findings
    are not compared and nothing is removed; construct errors still fail; note
    `first commit: findings are not compared, so this commit is the starting point (rule 6.2.5)` (H6).
  - *Detached `HEAD`*: nothing special.
  - *Merge* (`MERGE_HEAD` in the git directory; one line per merged head):
    the parents are `HEAD` and each merged head. `excess = n_new - max over
    parents`; `N = min over parents of total - total_new`; the listing compares
    with the parent of lowest total (H7).
  - *Amend*: compared with `HEAD`, the commit being replaced, so only the
    amendment is judged; an earlier trailer that no longer matches fails
    (6.3.2) and the report says what to write (H8).
  - *Cherry-pick, rebase*: git does not run the hook (measured 2); CI's
    `verify(since = )` is the check.
- **G18.** A side whose `lints()` stops (a `weft_config_error` from its
  `_weft.yml`): on the new side the commit fails with that message; on base,
  findings are not compared for that project, with a note naming the file.
  Draft mode is ignored (9.4.3): neither `draft` nor `WEFT_DRAFT` changes
  anything.

### `gate()` and its report

- **G19.** `gate(message = NULL, path = ".")`. `path`: a folder inside a git
  work tree. `message`: `NULL` or the path of a file holding the commit
  message. Compares the index with `HEAD` (G5–G18) for every project of the
  repository. Prints the report (G20) with `message()` and returns
  invisibly a `weft_gate`: a list `ok` (lgl), `errors` and `added`
  (`weft_findings`), `excess` (data frame `project, rule, text, base, new`),
  `removed` (data frame `project, file, line, kind, text`, base side),
  `n_removed`, `trailer` (integer or `NA`), `changed` (paths relative to the
  repository top), `notes`, `seconds`. `print()` prints the report. Paths in
  the report are relative to the repository top.
- **G20. The report**, written to stderr, sections in this order, each
  present only when it has something; then the time line, always:

  ```
  commit-msg: 1 construct error
    book/chapters/results.qmd
         12  construct  `r x`{.nmu}: unknown class `.nmu` (rule 5.3.1).

  commit-msg: 2 findings added that HEAD did not hold
    book/chapters/results.qmd
         14  numeral  "45%" is a number typed in prose (rule 5.2.1).
                      Write it as a value, put it in the dictionary, or mark it [45%]{.weft-literal why="..."}.
    book/chapters/discussion.qmd
         30  xref  @sec-limits names no anchor in the project (rule 5.7.1).

  commit-msg: 3 weft constructs removed, and the message does not say so

    book/chapters/14-percentile-bands.qmd, as in HEAD
        412  `r band_cut$lower`
        413  `r band_cut$upper`
        431  claim(shift$n_down, . >= 10)

    If the removal is intended, add this line at the end of the commit
    message, after a blank line:

        Weft-Removed: 3

    or commit with: git commit --trailer "Weft-Removed: 3"

  commit-msg: 0.8 s
  ```

  Finding lines are `sprintf("    %5d  %s  %s", line, rule, message)` with
  the hint on the next line under the message; construct text longer than 70
  characters is cut to 67 and `...`. With a wrong number the header is
  `commit-msg: 3 weft constructs removed, and the message says Weft-Removed: 2`
  and the advice reads `Change that line to:`. A passing run prints only
  `commit-msg: weft passed (2 changed files, 0.8 s)`. Notes come before the
  time line as `commit-msg: note: <text>`. Seconds have one decimal.

### The hook and `use_hooks()`

- **G21. The script** ships as `inst/hooks/commit-msg`, POSIX `sh` (Git for
  Windows runs hooks with its own `sh`), ASCII, with four placeholders filled
  by `use_hooks()`; single quotes in a value are written `'\''`:

  ```sh
  #!/bin/sh
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
  exec "$weft_rscript" --no-init-file -e '
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
  quit(save = "no", status = st)' "$1"
  ```

  `@LIBS@` is the installing session's `.libPaths()` joined by
  `.Platform$path.sep`; `--no-init-file` keeps the project's `.Rprofile`
  (renv, `weft_setup()`) out of the hook (H31). R or weft missing fails the
  commit with the message (H11). `--no-verify` skips the hook, and git records
  nothing of it.
- **G22. `use_hooks(path = ".", remove = FALSE, overwrite = FALSE, rscript =
  NULL, lib = NULL)`.** The project root is `find_project_root(path)`; it must
  hold `_weft.yml` (else `weft_tool_error`: "use_hooks() guards a weft
  project, a folder holding _weft.yml; <root> has none. Run use_weft() first
  (rule 6.1.1)."), be inside a git work tree, and git must be on the path.
  `rscript` defaults to `file.path(R.home("bin"), "Rscript")` (`Rscript.exe`
  on Windows); `lib` to `.libPaths()`; weft must be found in `lib` by
  `find.package(lib.loc = lib)`, else `weft_tool_error` naming the libraries
  (under `pkgload` it is not, so tests pass `lib`). The hooks folder is
  `git rev-parse --git-path hooks`.
  - No `commit-msg` there, and `core.hooksPath` unset: writes it, mode 755.
  - Ours (a `weft-file: use_hooks` line), body unedited: rewritten when its
    text would differ (`replace`), else `keep`. Ours and edited: left, unless
    `overwrite = TRUE`.
  - Another tool's hook, or `core.hooksPath` set (a hook manager): left alone.
    The script goes to `<git common dir>/weft/commit-msg` and the call prints
    `Add this line to the commit-msg hook your setup runs:` and
    `  sh "$(git rev-parse --git-common-dir)/weft/commit-msg" "$1"`; when
    `.pre-commit-config.yaml` exists, also a `repo: local` entry with
    `entry: sh .git/weft/commit-msg`, `language: system`,
    `stages: [commit-msg]`.
  - Messages as G41; returns the paths written, invisibly.
  - `remove = TRUE`: deletes the hook when it is ours (edited or not), and
    `<git common dir>/weft/` (script copy and cache); a foreign hook is left
    and the call says to remove the weft line from it.

### `verify()`

- **G23. `verify(files = NULL, since = NULL, static = FALSE, path = ".")`.**
  Root `find_project_root(path)`. `files` as `lints()`; `since` `NULL` (=
  `HEAD` when the project is in a work tree with a commit) or one string
  naming a commit; `static` `TRUE`/`FALSE`. Bad arguments, `since` not a
  commit, and `since` given without git are `weft_verify_error`.
- **G24. Before anything:** draft mode (`draft: true` in `_weft.yml`, or
  `WEFT_DRAFT` in `1`, `true`): `weft_verify_error` "verify() does not run in
  draft mode (rule 8.1.5): draft is on in _weft.yml. A draft render fails
  nothing, so it can verify nothing." (the clause reads `WEFT_DRAFT is set`
  for the variable). Then the version check (G32). Then the parts, in order,
  each skipped when named in `verify_skip` (G31) or by `static`:
  1. `lints`: `lints(root, files, tier = 1:2)` on the working tree, and the
     comparison G9–G12 with `since` materialised (cache used when the git
     directory is writable). Fails on construct errors; on findings added; on
     every instance of a rule in `strict`; on `tar-name` findings, judged here
     whatever the base held (H5). Lists, failing nothing: the removed
     constructs (8.2.2), tier-2 findings on lines added since `since` (G16;
     every line when there is no `since`), and the totals (G26). Without git,
     or with no commit, there is no comparison: note
     `no commit to compare with: findings are counted, not compared (rule 8.2.2)`.
  2. `decisions`: with `dict.yml` at the root, `check_decisions(read_dict(...),
     root = root)` (resolver from `_weft.yml`, or from the single document's
     `weft: decisions:` when there is no `_weft.yml`). `resolved == FALSE`
     fails; `NA` is listed as could not check. A `dict.yml` that will not read
     fails, with its message.
  3. `render` (G25–G26). Needs a set-up project ("verify() renders and reads
     the stamps of a set-up project; <root> has no _weft.yml (rule 9.3.2)").
  4. `ledger`: `ledger_state(root, header)` of each verified document's
     ledgers; every stale ledger fails (7.2.3) with its reasons; skipped with
     a note under `ledger: false`.
- **G25. The render, Quarto** (`_quarto.yml` at the root, or `.qmd` files):
  quarto from `QUARTO_PATH`, `quarto::quarto_path()`, `Sys.which("quarto")`.
  The run id is `verify-<YYYYmmddHHMMSS>-<pid>`, passed as `WEFT_RUN` (G30).
  With `_freeze/` present:
  1. if `.weft/freeze-backup/` exists, restore it: for each folder in it,
     delete `_freeze/<stem>` and move the folder back; delete the backup;
  2. write `.weft/freeze-backup/manifest` (one stem per line: the path of each
     verified document relative to the root, extension dropped), then move
     each `_freeze/<stem>` that exists into the backup with `file.rename()`;
  3. run `quarto render` (no `files`) or `quarto render <files>` in the root,
     output to a log file in `tempdir()`;
  4. exit 0: delete the backup; otherwise, or on an R interrupt (`on.exit`),
     restore it as in 1.
  A killed run is restored by the next one's step 1 (Q3). No lock: two
  `verify()` at once in one project are not supported.
  **rmarkdown** (no `_quarto.yml`, `.Rmd` files): each verified `.Rmd` once,
  `Rscript -e "rmarkdown::render('<file>', quiet = TRUE)"` with the working
  directory at the root, so the project's `.Rprofile` is read (decision 27).
- **G26. Knit-time results** (8.1.1.4, 2.9.3): from `.weft/stamps/` for each
  verified document: failures of a stamp whose `run` is this run's id fail.
  A verified document that holds a construct (G11 count > 0) and has no
  stamp from this run fails: "not executed in this render: served from
  freeze, or knit without weft active". A non-zero exit with no stamp
  failure fails with the log's lines from the first `weft:` line on (else
  its last 40 lines).
- **G27. Result.** A `weft_verify`: list `ok`, `parts` (data frame `part,
  status` (`ran`, `skipped`, `failed`), `detail`), `errors`, `added`,
  `strict` (`weft_findings`), `removed`, `tier2`, `decisions`, `knit`
  (failures), `unexecuted`, `stale`, `tolerated` (data frame `rule, n`),
  `notes`, `seconds`. It prints its report to stderr, then: passed → returns
  it invisibly; failed → signals `weft_verify_error` "verify() failed: <n>
  reason(s); the report is above (rule 8.1.1)." with the object in
  `$result`, so `Rscript -e 'weft::verify()'` exits 1.
- **G28. The report.** First line `weft verify: passed` or `weft verify:
  failed`; then one line per part, `sprintf("  %-10s %s", part, detail)`,
  where a skipped part reads `skipped: <why>` (`static = TRUE`, `verify_skip
  in _weft.yml`, `no dict.yml`, `ledger: false in _weft.yml`); then sections
  `Construct errors`, `Findings added since <since short>`, `Strict rules`,
  `Target names` (G24.1), `Decision pointers`, `Knit-time failures`,
  `Not executed in this render`, `Ledger: entries not re-rendered`,
  `Constructs removed since <since short> (reported, not judged; rule 8.2.2)`,
  `Tier-2 findings on added lines`, each as G20's lines; then
  `Tolerated findings (rule 8.1.2); make a rule strict in _weft.yml when its count is 0:`
  and `sprintf("  %-15s %d remain", rule, n)` for each tier-1 rule with
  instances (construct-error rules excluded); then `weft verify: 12.3 s`.
- **G29.** `verify(files = )`: renders, stamps, ledgers and listings for the
  named documents only; cross-file rules still read the whole project
  (8.2.1); the freeze backup holds only their entries.
- **G30. Run id.** `R/collect.R`'s `run_id()` returns `Sys.getenv("WEFT_RUN")`
  when set, else reads `.weft/run`; `inst/quarto/weft-pre-render.R` uses
  `WEFT_RUN` as its id when set. With an older installed copy the stamps
  still carry `WEFT_RUN` (the knit reads the variable first), so `verify()`
  reads them right; that copy's post-render report then lists the documents as
  served from freeze, and `status()` shows the script `outdated`.

### Configuration and version

- **G31.** Added to `default_config()` and validated (`weft_config_error`,
  messages as 9.1.6 does):

  ```yaml
  strict: []          # 8.1.3: tier-1 rule ids whose every instance fails verify()
  verify_skip: []     # 8.1.4: parts of verify() switched off: lints, decisions, render, ledger
  weft_version: null  # 9.5.4: the weft version that set the project up
  ```

  `strict`: ids from `lint_rules()$id` of tier 1 ("`<id>` is not a weft rule;
  did you mean `<x>`?"; a tier-2 id: "`claim-word` is tier 2 and blocks
  nothing, so it cannot be strict (rule 8.1.3)."). `verify_skip`: a subset of
  the four, project-only (9.1.4, via `project_only_settings()`). `weft_version`:
  one string.
- **G32. Version.** `recorded_version(root)` (4d) reads `weft_version` from
  `_weft.yml` as text (`NA` when absent). `verify()` warns when it is not `NA`
  and differs from `packageVersion("weft")`: "This project records weft 0.1.0
  in _weft.yml, and weft 0.2.0 is installed. Run weft::use_weft() to update
  the files weft installed and the record (rule 9.5.4)." Absent: no warning;
  `status()` says it is not recorded. `use_setup()` writes the line when it
  creates `_weft.yml` and appends it to one without it; `use_weft()` also
  updates an existing line in place. `use_quarto()` is unchanged.

### `use_ci()`, `use_agent_docs()`

- **G33. `use_ci(path = ".", overwrite = FALSE)`** writes
  `.github/workflows/weft.yml` at the repository's top (H23), from
  `inst/ci/weft.yml` with `@PATH@` the project root relative to the top
  (`.` when they are one), `@VERSION@` and `@HASH@`:

  ```yaml
  # weft-file: use_ci @VERSION@ @HASH@
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
          run: |
            since=$(git merge-base "$BASE_SHA" HEAD)
            Rscript --no-init-file -e "weft::verify(static = TRUE, since = '$since', path = '@PATH@')"
  ```

  Not in a work tree: `weft_tool_error`. The file policy is G40's; messages G41.
- **G34. `use_agent_docs(path = ".", overwrite = FALSE)`** writes under the
  project root: `.claude/skills/weft/SKILL.md` (whole file, from
  `inst/agent/SKILL.md`; the `weft-file` marker is its last line, an HTML
  comment), and a block in `AGENTS.md` (created when absent) between
  `<!-- weft:start use_agent_docs @VERSION@ @HASH@ -->` and
  `<!-- weft:end -->`, appended after the file's last line with one blank
  line before it. It prints: "Claude Code reads CLAUDE.md: add the line
  @AGENTS.md to it, or move the block there." when `CLAUDE.md` exists and
  holds no `@AGENTS.md`. The block (`inst/agent/AGENTS.md`):

  ```markdown
  ## weft

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

  The weft skill (`.claude/skills/weft/`) has the detail.
  ```

  The skill's front matter: `name: weft`; `description:` "Use when editing a
  document of a project that uses the weft R package (inline `r` values,
  spans with n=, if=, sign=, list=, cite=, claim() checks, _weft.yml), or when
  a render, a lint or a commit fails with a weft report." Its body: the four
  rules of 9.3.3 as in the block, then: reading a failed-claim report (the
  sentence, the check, the value: say which is wrong, do not decide); the
  trailer, with `git commit --trailer "Weft-Removed: N"`; findings added at
  commit and how each is fixed (a value, the dictionary, `.weft-literal` with
  a real `why`); `dict_local` (4.3.1–4.3.5 in one line each); draft mode
  passes nothing and `verify()` refuses it; `weft::lints()` before a commit and
  `weft::verify()` before handing back. ASCII; under 80 lines.

### `use_setup()` and `.Rprofile` activation (the held 1c item)

- **G35. `use_setup(path = ".", route = c("auto", "rprofile",
  "front-matter"))`.** `path`: a folder or one `.qmd`/`.Rmd`/`.rmd`. A folder
  with `_quarto.yml` (found upwards, as `use_quarto()`) is a **Quarto
  project**; `auto` is `rprofile` there and `front-matter` otherwise. A
  folder without one: every `.Rmd`/`.qmd` of L3's set is a single document.
  It writes:
  - `_weft.yml` when absent (`# weft settings for this project. Every key has a default;`
    / `# add only what you change.` / `weft_version: <v>`), or the
    `weft_version` line appended to one that lacks it;
  - route `rprofile`: the `.Rprofile` at the project root (G36);
  - route `front-matter`: in each document's front matter
    `knitr:` / `  opts_knit:` / `    weft: !expr weft::weft_setup()`;
  - `engine: knitr` (top level of the front matter) in each `.qmd` that lacks
    an `engine:` and a `jupyter:` key and does not hold executable chunks of
    another engine without an R chunk (H29), skipping files and folders whose
    names start with `_` or `.` (includes, 9.2.8 rationale); a `.qmd` with no
    front matter gets `---` / `engine: knitr` / `---` as its first lines;
  - under rmarkdown (single `.Rmd`): `weft-check.lua` copied beside it (kept
    when identical, replaced when it differs: weft's own file, as
    `use_quarto()`), and under each format of `output:` the items
    `"--lua-filter"`, `"weft-check.lua"` appended to `pandoc_args`; no
    `output:` → `output:` / `  html_document:` / `    pandoc_args: ["--lua-filter", "weft-check.lua"]`;
    a scalar `output: pdf_document` becomes that mapping for that format.
  Front matter is edited as text with `R/use.R`'s helpers and checked by
  re-parsing, as `use_quarto()`: when an edit cannot be made safely (flow
  style, an anchor, an existing `weft:` under `opts_knit` with another value)
  the call writes nothing at all and prints the lines to add by hand
  (`weft_tool_error`). Second run: "Nothing to change". Messages G41.
- **G36. The `.Rprofile`.** Absent: written as

  ```r
  # weft: activates weft in every knit of this project (weft::use_setup(), rule 9.2.1).
  # R reads this file instead of your ~/.Rprofile; the next line keeps yours.
  if (file.exists("~/.Rprofile")) source("~/.Rprofile")
  if (requireNamespace("weft", quietly = TRUE)) weft::weft_setup()
  ```

  Present without an uncommented line holding `weft::weft_setup()`: the first
  and last lines above are appended after its last line (after renv's
  `source("renv/activate.R")`, so weft is found in renv's library). Present
  with one: kept.
- **G37. What is tested from the command line, and what is not.** Tested in
  temporary projects, with `HOME`, `R_PROFILE_USER` unset and `R_LIBS` set to
  the test library: a fresh `Rscript` started in the project has
  `"weft:functions"` on `search()` after the `.Rprofile`; `quarto render`
  of a project whose documents (root and a subfolder) are activated only by
  the `.Rprofile` resolves their constructs; `Rscript -e
  "rmarkdown::render('doc.Rmd')"` started in the project root resolves a
  document activated only by the `.Rprofile` (works, though 9.2.3 does not
  offer it) and one activated by its front matter; the filter line fails a
  render of an `.Rmd` with constructs when weft is not in the library; an
  `.Rprofile` that sources a stub `renv/activate.R` first still activates.
  **Not tested** (they stay in §19 and Q2): the Render and Knit buttons of
  RStudio and Positron (RStudio's Knit starts R in the document's folder,
  which may not hold the `.Rprofile`), chunks run interactively and the
  inline preview, a real `renv` library, Windows.

### `use_weft()`, `status()`, the installer policy

- **G38. `use_weft(path = ".")`.** Plans every step first, prints the
  summary, then writes; when any step cannot be done safely (an `_quarto.yml`
  or front matter it cannot edit, a link or folder in a file's place) it
  writes nothing and stops with that step's message. Order: `use_setup()`,
  `use_quarto()` (Quarto project only), `use_dictionary()`, `use_hooks()` (in
  a git work tree; else skipped: "not a git repository"), `use_ci()` (when
  `git remote get-url origin` is on github.com; else skipped: "origin is not
  on GitHub"), `use_agent_docs()`; then the `weft_version` line is set to the
  installed version. It never asks, interactive or not (the call is the
  consent, P10). Summary: `weft will set up <root>:` then one line per step,
  `sprintf("  %-15s %s", fn, what)` (`what` = the files and their state, or
  `skipped: <why>`). Returns the paths written, invisibly.
- **G39. `status(path = ".")`** writes nothing, runs no R process and no
  network. Returns a `weft_status`: a data frame `part, state, detail`, with
  attribute `next`; `state` one of `ok`, `missing`, `outdated`, `edited`,
  `off`, `n/a`. Parts and their checks: `setup` (`_weft.yml`; recorded
  version against installed), `activation` (route found; `.qmd` files
  lacking `engine: knitr`, first three named), `quarto` (extension and scripts
  against the shipped files by md5; `_quarto.yml` entries), `dictionary`
  (`dict.yml`; schema current), `hooks` (ours, foreign, or none; version;
  recorded `Rscript` exists), `ci`, `agent docs` (by G40), `draft` (`off` is
  `ok`), `verify_skip`, `strict`. Printed as

  ```
  weft status: /tmp/x/book
    setup        ok        _weft.yml records weft 0.1.0 (installed: 0.1.0)
    activation   missing   no .Rprofile line and no front-matter route
    ...
  Next: run weft::use_setup() to activate weft in the documents.
  ```

  `next`: the first part, in G38's order, that is `missing` or `outdated`
  (`Next: run weft::<fn>() to <purpose>.`); none → `Nothing to install. Run
  weft::verify() to check the project.`
- **G40. Whole files weft writes** (the hook script, the workflow, the skill)
  carry a line `weft-file: <fn> <version> <hash>` (in a comment), where the
  hash is `cli::hash_md5()` of the file's other lines joined by `\n`. A
  block weft writes in an author's file carries the same fields on its start
  line. State: absent → `new`; marker present and hash matches → weft's,
  unedited (`keep` when identical to what would be written, else `replace`);
  hash mismatch → `edited`: left alone, with "edited since weft wrote it; left
  as it is (use overwrite = TRUE to replace it)", unless `overwrite = TRUE`.
  No marker → another author's file: never replaced (the hook: G22). Files
  weft edits by line (`.Rprofile`, front matter, `_weft.yml`) only gain lines,
  except the `weft_version:` line, which is weft's and `use_weft()` updates.
- **G41. Messages** follow `use_quarto()`: `weft will write, under <root>:`,
  one line per file `sprintf("  %s  (%s: %s)", file, state, purpose)`, then
  `Wrote: a, b` or `Nothing to change: <what> is already set up.` Silent
  under `suppressMessages()`. A link in a file's place, a folder in its place,
  a write that fails: `weft_tool_error` naming the path, before anything is
  written where that can be known; a file is never reported written that was
  not.

## 3. Where the spec is wrong or silent

Smallest undoable change first. "Reverse" names the place to change.

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| H1 | `lints()` reads files from a path; the cache needs to serve a document's source by blob | lint whole trees each commit; cache whole-side results only; a reader hook in 3a | the hook (G4a), plus side-level layers | a 20-chapter book is ~10 s per tree without it; one line in 3a | G14 layer `src` off |
| H2 | 6.1.3's `git show :<file>` per file | `show` per file; `checkout-index` with a temporary index; `cat-file --batch` | `cat-file --batch` into a temporary tree | one process; the same bytes; no index file written | G6 |
| H3 | 6.2.3 sums "over the files in the commit"; 6.2.4 reads across files | changed files only; the whole project | the whole project, both sides | unchanged files cancel, so it is 6.2.3 where 6.2.3 applies; it also catches a `_weft.yml` or `dict.yml` change that adds findings | count over changed documents only |
| H4 | 6.2.1's "construct error" as rule ids; "staged file" | `construct` only; plus `block-start`, `read` | all three, in changed documents | a span cut by a re-wrap (Q9) and an unreadable file are never right; "staged" read as "changed by the commit" | the id list |
| H5 | 6.2.2 names hygiene, which includes `tar-name`; the store is a build product, not in the commit | judge it against the work tree's store; drop it | not in the gate; in `verify()` judged absolutely | 6.1.4 static; a fresh clone has no store | add `_targets` to G6 |
| H6 | an unborn `HEAD` makes every finding "added" | compare with empty; first commit as baseline | baseline, construct errors still fail | adoption in a new repository would otherwise fail on everything the documents held (6.2.5) | G17 |
| H7 | merges are untested and unspecified | first parent only; every parent | every parent: max for findings, min for the total | judges what the merge itself did; each side was gated on its own branch | first parent |
| H8 | amend cannot be detected in `commit-msg` (measured 2) | a `prepare-commit-msg` hook to flag it; as the spec | as the spec | `prepare-commit-msg` cannot tell `--amend` from `-c HEAD`; the report says the number to write | — |
| H9 | Q17: cherry-pick and rebase | more hooks (`post-rewrite`); none | none | measured: git runs no `commit-msg`; CI's `verify(since = )` covers branches | add `post-rewrite` that reports |
| H10 | 6.1.5 records Pandoc's path | record it; not | not | K1: the lints call no Pandoc by default, and the gate must not depend on which Pandoc is installed | G21 |
| H11 | R or weft missing when the hook runs | pass (fail open); fail with the remedy | fail, naming `use_hooks()` and `--no-verify` (for Robin) | an accident should not pass silently; the remedy is one command | G21 template |
| H12 | an existing hook or a hook manager | overwrite; chain; leave and print the line | leave, write the script beside the cache, print the line | never touch another tool's file | G22 |
| H13 | 6.1.6 gives the key only | blob only; blob plus what the result depends on | G14's three layers | a source depends on settings and `lang`; findings on project files and paths; versions invalidate | G14 |
| H14 | no function runs the gate by hand | internal only; exported `gate()` | exported (name for Robin) | the hook calls a stable name; tests call it in process; an author or agent can check before committing | rename |
| H15 | several or malformed trailers | first; last; error | last; non-digits a wrong number | `interpret-trailers` keeps order; an amended message usually ends with the newest | G13 |
| H16 | which instances of an added key to show | all; on added lines | added lines, else all | "45%" may occur 30 times and one is new | G10 |
| H17 | `verify()`'s exit status | return `ok`; error | error with the result attached | `Rscript` and CI exit 1 without a wrapper | G27 |
| H18 | 8.1.1 "every lint at every tier" against 5.1.5 | tier 2 everywhere; on added lines | added lines | 5.1.2: tier 2 is for added material | G24 |
| H19 | `verify()` with no git or no commit | error; count only | count only, noted; explicit `since` without git is an error | the daily-report use (§10) often has no repository | G23 |
| H20 | `verify()` must know which stamps its render wrote | time stamps; parse the log; a run id in the environment | `WEFT_RUN`, honoured by `run_id()` and the pre-render script | exact; two small edits to stage 1 files | G30 |
| H21 | open finding: an unstamped frozen document cannot fail `verify()` | — | it fails when it holds a construct (2.9.3) | closes the finding | G26 |
| H22 | 8.3.1's backup place and kill recovery | `_freeze.bak`; `.weft/freeze-backup/` with a manifest | the latter | `.weft/` is ignored by git (9.3.2); the manifest makes step 1 exact | G25 |
| H23 | a workflow must sit at the repository's top, outside a project in a subfolder | refuse and print it; write at the top, saying so | write at the top (for Robin) | GitHub reads nowhere else; the hook already writes in the repository's git directory | print instead |
| H24 | 9.3.1 "never overwrite" for files weft wrote | always replace; never; a hash marker | hash marker (G40) | tells an edited file from an old template without a second record | G40 |
| H25 | where agent conventions go | `CLAUDE.md`; `AGENTS.md`; skill only | `AGENTS.md` block plus the skill (for Robin) | `AGENTS.md` is read by several agents; the line `@AGENTS.md` brings it into Claude Code | `file =` argument |
| H26 | `use_weft()` in a non-interactive session | ask when interactive; never ask | never, plan first, all or nothing | a prompt in a script is a hang; as `use_dictionary()` | G38 |
| H27 | key names for 9.1.2's new rows | `strict`/`verify_skip`/`weft_version`; `strict_rules`/`off`/`version` | the first (for Robin) | each names what it governs in the file | rename before release |
| H28 | 9.5.4 "mismatch" | newer only; any difference; absent | any difference warns; absent is silent | a downgrade breaks installed scripts too; an unrecorded project is not wrong | G32 |
| H29 | 9.2.8 adds `engine: knitr` to every rendered `.qmd`, which would break a Jupyter document | every one; R documents only | every one without `engine:`/`jupyter:` and not another engine's only | a plain page costs a knit; a Python page would break | G35 |
| H30 | a new project `.Rprofile` hides `~/.Rprofile` | say so only; source it | source it, saying why in the file (for Robin) | R reads one profile; silently losing the user's is a surprise | G36 |
| H31 | the hook's R must find weft in renv without running the project `.Rprofile` | run the `.Rprofile`; record `.libPaths()` | record, run with `--no-init-file` | renv activation is slow and prints; the profile's `weft_setup()` is not wanted in a hook | G21 |
| H32 | 6.3.1 "anywhere in the file" | executed chunks; every R chunk | every R chunk, any `eval` | setting `eval: false` on a check is not a removal, but a deleted chunk is | G11 |
| H33 | which projects a repository's hook judges | the root `use_hooks()` was run in; every folder with `_weft.yml` | every such folder, either side | survives moves; one hook per repository | G7 |
| H34 | link targets, and size, in a materialised side | the work tree's files; tracked files | tracked files as placeholders; content only for G6's extensions up to 5 MB | what a clone and CI see; no symlinks (Windows); a data file is never read as text | G6 |
| H35 | 9.3.1 lists `dict_vale()` under "everything below" `use_weft()` | call it; not | not | it needs `avoid` entries; it is a tool, not set-up | — |
| H36 | verify renders `.Rmd` | in session; fresh `Rscript` in the root | fresh process | the knit must not see verify's session; as `rehearse()` | G25 |
| H37 | `use_quarto()` creates an `_weft.yml` without a version | edit it; leave | leave; `use_setup()`/`use_weft()` add the line | its existing test pins the file; absence is silent (H28) | add the line in `R/use.R` |

**Contradictions and gaps found:** 6.1.5 and 9.3.1 (Pandoc's path) against
K1; 6.2.3 against 6.2.4 (H3); 6.2.1 "staged file" (H4); 6.2.2's hygiene
including `tar-name` against 6.1.4 (H5); 8.1.1 "every tier" against 5.1.5
(H18); 9.2.8 against Jupyter documents (H29); 9.3.1's `use_weft()` row
against `dict_vale()` (H35); §19 lists amend, merge, rebase and cherry-pick
as unrun — measured above; open finding "for `verify()` in stage 5" on a
front-matter `decisions` (G24.2 reads it for a single document); the
constraint that nothing is written outside the project against a workflow
that must sit at the repository top (H23).

**Spec edits after the build:** each H row into the rule it names; new
6.2.8 for G17; 9.1.2/9.1.5 gain G31's keys; 9.5.3, 9.5.4 take G39, G32; §19
and Q17 take measurement 2; Q11 takes G15's result.

## For Robin

Built as chosen until answered.

- **F1 — The hook fails the commit when R or weft cannot be found (H11)**,
  printing `use_hooks()` and `--no-verify`. Alternative: pass with a warning.
  Reverse: two `exit 1` lines in `inst/hooks/commit-msg`.
- **F2 — Names an author types (H14, H27):** `gate()`; the keys `strict`,
  `verify_skip`, `weft_version`; the trailer stays `Weft-Removed`. Reverse:
  renames before release.
- **F3 — `use_ci()` writes at the repository's top (H23)** even when the
  project is a subfolder, and installs weft from `github::vorpalvorpal/weft`
  until it is on CRAN. Alternative: print the file. Reverse: G33.
- **F4 — Agent conventions go in `AGENTS.md` plus a Claude skill (H25).**
  Alternative: `CLAUDE.md`. Reverse: a `file` argument.
- **F5 — A new project `.Rprofile` sources `~/.Rprofile` (H30).** Reverse:
  drop the line from G36.
- **F6 — The first commit of a repository is the baseline (H6)**: its
  findings are not compared. Reverse: G17.

## 4. Work packages

4a and 4d first, in parallel worktrees (no shared file). Then 4b and 4c in
parallel. NAMESPACE and `man/` are regenerated with roxygen after each merge,
never merged by hand. Stage 3 must be on `main` with G4 before 4a starts; no
package edits `R/lint*.R` or `R/recall.R` (a need there goes to the
orchestrator).

| Pkg | Creates | Edits | Tests |
|---|---|---|---|
| **4a** the gate | `R/gate.R` (`gate()`, judging G9–G13, G17, G18, report G20, `print.weft_gate`), `R/gate-git.R` (git runner with `-z` reading, sides G5–G8, materialising, `diff_added()`, trailers, merge parents), `R/gate-cache.R` (G14), `R/constructs.R` (`count_constructs()`) | — | `helper-4a.R`, `test-gate-sides.R`, `test-gate-judge.R`, `test-gate-constructs.R`, `test-gate-trailer.R`, `test-gate-history.R`, `test-gate-cache.R`, `test-gate-edits.R` with `_gate/` (the 72 edits), `test-gate-perf.R` |
| **4d** activation | `R/setup.R` (`use_setup()`, front-matter editing, `.Rprofile`, `recorded_version()`, the version line writer) | — (reuses `R/use.R`'s helpers without changing them) | `helper-4d.R`, `test-use-setup.R`, `test-use-setup-rmd.R`, `test-activation-cli.R`, `test-version-record.R` |
| **4c** `verify()` | `R/verify.R` (G23, G24, G27, G28, G29, G32's warning), `R/verify-render.R` (G25, G26) | `R/config.R` (G31, `project_only_settings()` entry if not there), `R/collect.R` (`run_id()`, G30), `inst/quarto/weft-pre-render.R` (G30) | `helper-4c.R`, `test-verify-static.R`, `test-verify-config.R`, `test-verify-freeze.R`, `test-verify-render.R`, `test-verify-rmd.R` |
| **4b** installers | `R/install.R` (G40, G41), `R/use-hooks.R` (G22), `R/use-ci.R` (G33), `R/use-agent-docs.R` (G34), `R/use-weft.R` (`use_weft()`, `status()`), `inst/hooks/commit-msg`, `inst/ci/weft.yml`, `inst/agent/SKILL.md`, `inst/agent/AGENTS.md` | — | `helper-4b.R`, `test-use-hooks.R`, `test-hook-commit.R`, `test-use-ci.R`, `test-use-agent-docs.R`, `test-use-weft.R`, `test-status.R` |

4b needs 4a (`gate()` for the end-to-end hook tests) and 4d (`use_setup()`,
`recorded_version()`); 4c needs 4a (the comparison) and stage 3. 4b's
`status()` reads `strict` and `verify_skip` from `_weft.yml` as YAML, so it
does not wait for 4c.

**Test helpers** (`helper-4a.R`, loaded for every later file): `git_env()`
sets, by `withr::local_envvar()`, `GIT_CONFIG_GLOBAL` (an empty temporary
file), `GIT_CONFIG_NOSYSTEM=1`, `HOME` (a temporary folder), the author and
committer names, e-mails and dates; `g_repo(files)` makes a repository
(`git init -b main`, `commit.gpgsign false`, `_weft.yml` unless given);
`g_write()`, `g_add()`, `g_commit()`, `g_gate(dir, msg = NULL)`,
`skip_if_no_git()`. No test reads the user's git configuration or the
network. Hook and render tests use `weft_test_lib()`.

## 5. Tests

Every example in §2 is a case. Fixtures are written by the tests. Skips:
`skip_if_no_git()`, Quarto and Pandoc as `helper-quarto.R`, `rmarkdown` by
`skip_if_not_installed()`, timings and end-to-end renders `skip_on_cran()`.

- **4a.** `test-gate-sides.R` (G5–G8): the staged text judged when the work
  tree differs (edit, stage, edit again); `git commit -a`'s temporary index; a
  project in a subfolder, two projects; no `_weft.yml`; an untracked `.qmd`
  never read; a non-ASCII path; a symbolic link and a 6 MB `.json`
  (placeholders, note); a link to a tracked image passes, to an untracked one
  is a finding; nothing under `_targets/`, no `tar-name`.
  `test-gate-judge.R` (§21 "The gate"): a construct error fails whether or
  not `HEAD` held it, not in an unchanged file; a finding in `HEAD` passes;
  the same added fails, listed at its added line; moved to another file
  passes; removing an anchor an unchanged chapter cites fails, listed there
  (6.2.4); a label word dropped from `_weft.yml` fails (H3); tier 2 not
  judged; `WEFT_DRAFT=1` and `draft: true` change nothing; G18 both ways;
  G20's report exactly, the pass line, notes, the time line.
  `test-gate-constructs.R`: G11 per kind and context (caption, front matter,
  `weft_str()`, `claim()` in an `eval: false` chunk, a value holding
  `claim()` counted twice, `.weft-literal` not); §21's no-trailer passes: a
  value turned into a span, a variable renamed in forty expressions, a bound
  changed, a paragraph moved between files, a file renamed; a re-wrap that
  breaks after `` `r `` removes constructs.
  `test-gate-trailer.R`: no trailer and a wrong count fail, the right count
  passes, through `-m` and `-F` messages with comment lines and a status
  block; 6.3.4's listing with `HEAD` lines, longer than N when the commit
  also adds; `weft-removed: 3`, `Weft-Removed:3`, two trailers, `three`,
  `-1`; a trailer on a commit removing nothing ignored; a new and a deleted
  file against an empty version.
  `test-gate-history.R` (G17): unborn `HEAD`; detached `HEAD`; a merge whose
  other parent added a finding passes, one whose resolution adds one fails,
  one whose other branch removed constructs needs no trailer; an amend judges
  the amendment only; `git cherry-pick` runs no hook (pinned).
  `test-gate-cache.R`: parity of cache on, off and cold over
  `test-gate-judge.R`'s cases; `HEAD` not materialised on the second commit;
  a corrupt entry; another weft version; a changed `_weft.yml` misses
  `file`; pruning 1,001 to 800; an unwritable folder; nothing written outside
  the git directory and `tempdir()`.
  `test-gate-edits.R`: the 72 edits of `dev/spikes/spike-gate/edits.R`,
  ported with their generator into `tests/testthat/_gate/`, re-answered for
  the single total (`N = max(0, removed - added)` from each hand answer;
  E16b by the scanner's count), through `count_constructs()`.
  `test-gate-perf.R`: G15.
- **4d.** `test-use-setup.R`: `.Rprofile` new, appended after a renv line,
  kept; `engine: knitr` added, kept, skipped (`engine: jupyter`, Python only,
  `_include.qmd`), a `.qmd` with no front matter; `route = "front-matter"` in
  a project; `_weft.yml` new and appended; a second run; every message; a
  link in a file's place. `test-use-setup-rmd.R`: no `output:`, a scalar, a
  mapping, two formats, block `pandoc_args`, flow `pandoc_args` (nothing
  written, lines printed); a folder of two `.Rmd`; the filter copy kept and
  replaced. `test-activation-cli.R`: G37's tested list, each in a fresh
  process. `test-version-record.R`: absent, quoted, unquoted.
- **4c.** `test-verify-static.R` (§21 "`verify()`"): `static = TRUE` renders
  nothing; `since` fails on a finding added and reports a removal with no
  trailer without failing; a tolerated finding fails nothing until its rule
  is `strict`; the totals lines; `tar-name` absolute; tier 2 on added lines;
  no git, no commit, `since` without git; `files`; pointers by the glob route
  (could not check fails nothing); the version warning; `Rscript -e
  "weft::verify(static = TRUE)"` exits 1 and 0. `test-verify-config.R`: G31
  defaults, refusals, `verify_skip` in front matter beside `_weft.yml`,
  skipped parts reported. `test-verify-freeze.R`: a render that succeeds
  (backup gone), fails (entries restored), is killed (a backup left by hand;
  a child `Rscript` killed once the backup exists), then restored first (Q3);
  `verify(files = )` in a frozen project passes when the named files pass.
  `test-verify-render.R`: a failed claim from the stamp; a document with a
  construct and no stamp from this run fails, one without does not; a stale
  ledger fails; draft refused before anything runs. `test-verify-rmd.R`:
  each `.Rmd` once, its stamp found by `WEFT_RUN`.
- **4b.** `test-use-hooks.R`: G22's cases (fresh, second run, a changed
  `rscript`, an edited hook and `overwrite`, a foreign hook and
  `core.hooksPath` with the printed line, the pre-commit snippet, remove, a
  linked worktree, no git, no `_weft.yml`, weft not in `lib`); the script
  equals the filled template, mode 755. `test-hook-commit.R` (real `git
  commit`): a failing commit stops with the report on stderr and status 1; the
  trailer passes it; `--no-verify` skips; G21's two missing-R messages; a
  path with a space and a quote. `test-use-ci.R`: the workflow exactly (top
  and subfolder), second run, edited, `overwrite`, no git.
  `test-use-agent-docs.R`: new `AGENTS.md`, appended and edited blocks,
  outside text untouched, the `CLAUDE.md` advice, the skill's front matter.
  `test-use-weft.R`: order and summary; skips without git and with a
  non-GitHub origin; nothing written when `_quarto.yml` cannot be edited; the
  version line; never prompts under `rlang_interactive = TRUE`.
  `test-status.R`: each part's states, `next` per missing step, nothing
  written.

## Readings fixed when the 4d tests were written

1. `use_setup()` returns, invisibly, the paths it wrote (a character
   vector, empty on a run that changes nothing).
2. Appended to an existing `.Rprofile`: the comment line and the
   activation line. The line that sources `~/.Rprofile` is written only
   into a new file.
3. `route = "front-matter"` is allowed on a project that already has the
   `.Rprofile` lines; a document is still set up once.
4. A folder inside a Quarto project writes the `.Rprofile` at the project
   root. A path that does not exist, or a file that is not a document,
   is a `weft_tool_error`.
5. An edit that cannot be made safely (flow-style `knitr:` or
   `pandoc_args`, a YAML anchor, a different `weft:` under `opts_knit`)
   is a `weft_tool_error` that prints the lines to add by hand, and
   nothing is written.
6. `recorded_version()` is internal; it gives `NA` for an absent,
   commented-out, `null` or empty value, and keeps the spelling written.
   `use_setup()` leaves an existing `weft_version` line alone.
7. A test's child process must leave `R_PROFILE_USER` unset: R reads the
   project `.Rprofile` only then.

## Readings fixed when the 4a tests were written

1. No git, not a work tree, and git failing are each a
   `weft_gate_error`, as G2 says.
2. Tier 2 is not judged by the gate: it is in neither `added`, `excess`
   nor the report.
3. `count_constructs()` gives `kind` as `value`, `span` or `claim`.
4. Under a merge, `excess$base` is the largest count over the parents.
5. `n_removed` is an integer; `trailer` an integer, or `NA` for none or
   a value that is not digits. The trailer is read as git reads
   trailers: any letter case, with or without a space after the colon,
   after a subject paragraph; a comment line is not one.
6. Headers are singular for one ("1 weft construct removed",
   "1 finding added that HEAD did not hold"). The pass line counts
   changed documents.
7. An amended commit whose removals come to zero ignores an old trailer.
8. The cache is pruned to 800 entries, oldest by modification time
   first. A cache that cannot be written gives a note and the gate runs
   without it.
9. The hook calls `weft::gate(<message file>)`: `message` is the first
   argument and `path` the second.

Owed: `test-gate-edits.R`, the ported edits and their generator (section
5), to be written once stage 3's rules exist.

## Readings fixed when the 4b tests were written

1. Markers: the hook's is line 2, the CI workflow's is line 1, the
   skill's is the last line (`<!-- weft-file: use_agent_docs V H -->`).
   The hash is the md5 of the other lines joined by a newline.
2. The `AGENTS.md` block's hash covers the inner lines and the end line
   (G40 read literally). A new `AGENTS.md` is exactly the block; an
   appended block follows one blank line.
3. A foreign hook, workflow or `SKILL.md` is left alone with no error,
   under `overwrite = TRUE` too. For a foreign hook the value returned
   is the path of the script copy, `<common dir>/weft/commit-msg`. A
   hook manager means a foreign hook or any `core.hooksPath`.
4. A second project running `use_ci()` over our unedited workflow with
   a different path replaces it.
5. A folder or a link where a file should go is a `weft_tool_error`.
6. `status()` states the design did not give: `draft: true` and a
   non-empty `verify_skip` are `off`; `strict` set is `ok` with the ids
   in the detail; an older template or a recorded Rscript that has gone
   is `outdated`; an edited file is `edited` and never makes a next
   step; `quarto` is `n/a` outside a Quarto project; `hooks` and `ci`
   are `missing` or `n/a` without git; an unrecorded version says "not
   recorded". Lines print as `sprintf("  %-12s %-9s %s", ...)`.
7. `use_weft()` has no `lib` argument. Its `use_quarto` line is absent
   or starts `skipped` outside a Quarto project.
8. An amended commit is judged against the amended HEAD. A merge passes
   when only the other parent added a finding and fails when the
   conflict resolution adds one.

Not covered: the hook's "weft stopped with an error" message; `use_ci()`
and `use_agent_docs()` without `_weft.yml`; Windows.

## Readings fixed when the 4c tests were written

1. `weft_version: null` and an absent key are both "no record", with no
   warning. `strict` and `weft_version` are not project-only.
2. A skipped part's detail is the text after its name: `skipped: static
   = TRUE`, `skipped: no dict.yml`, `skipped: verify_skip in _weft.yml`,
   `skipped: ledger: false in _weft.yml`.
3. A report section appears only when it has content. A clean report is
   the verdict line, four part lines and the time line.
4. A finding line is `sprintf("    %5d  %s  %s", line, rule, message)`
   under the file name, which is indented two spaces and relative to
   the project root. The heading is `Findings added since <7 hex>`.
5. Removed constructs have the columns `file`, `line`, `kind`, `text`.
6. The freeze manifest lists the stem of every verified document, with
   or without a `_freeze` entry, nested stems as `chapters/c`.
7. `QUARTO_PATH` is looked up first. Quarto gets `render`, or `render`
   and the files as passed.
8. The run id's pid is that of the verifying process.
9. A warned check fails nothing. The stale ledger reason comes from
   `ledger_state()`.
10. `since` takes a sha, a branch name, `HEAD~1` or `HEAD`; with no
    commit in the repository it is a `weft_verify_error`.
11. Front-matter `verify_skip` works in a lone document.
12. `print()` of a result repeats the report.

Not covered: restoring `_freeze` after an R-level error mid-render (only
a non-zero exit and a killed process are tested); the stamp file name of
a nested document; whether `verify()` stops after a failing part.
