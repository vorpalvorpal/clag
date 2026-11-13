# Code review C: the static lints and the enforcement tools

Scope: `R/lint.R`, `R/lint-source.R`, `R/lint-prose.R`, `R/lint-pandoc.R`,
`R/lint-code.R`, `R/lint-doc.R`, `R/recall.R`, `R/gate.R`, `R/gate-git.R`,
`R/gate-cache.R`, `R/constructs.R`, `R/verify.R`, `R/verify-render.R`,
`R/install.R`, `R/use-hooks.R`, `R/use-ci.R`, `R/use-agent-docs.R`,
`R/use-weft.R`, `R/setup.R`, and `inst/hooks/`, `inst/ci/`, `inst/agent/`,
read in full at `e8c1609`. Every bug and robustness item below was reproduced
with `pkgload::load_all()` in temporary folders and temporary git repositories
(git isolated with `GIT_CONFIG_GLOBAL` and a temporary `HOME`); the scripts are
in the session scratchpad (`rc-c/r1.R` to `r6.R`). Suspicions that did not
reproduce were dropped (for example `recall_check(commit =)` on a subfolder:
`git archive` run there archives only that subtree, which is right). Nothing
from `dev/review-3.md` or `dev/review-4.md` is repeated, and their rulings are
taken as settled (H28, "any version difference warns", included).

Counts, by each item's first kind: 8 bug, 2 robustness, 4 duplication,
2 structure, 2 message, 1 dead code (19 items; five of the bugs are also
duplications, the drift between copies being the cause).

The area has no duplicate function names left (checked across `R/`). Its seams
are of the next kind: the same job done two or three ways, where the copies
have already drifted apart. Most of the bugs below are such drifts.

## Proposals, most worth doing first

### 1. `verify()` lists no removed constructs where the gate demands a trailer; give both one "compare two sides" layer

- Kind: bug, duplication.
- Where: `R/gate.R` `gate_judge_project()` lines 368-438; `R/verify.R`
  `verify_added()` 393-420, `verify_removed()` 423-450, `verify_base_side()`
  368-388.
- What is wrong: the comparison of findings and constructs between a base and
  a new side is written twice. `verify_added()` is a near copy of lines
  369-404 of `gate_judge_project()` (`count_keys`, the excess, instances on
  added lines, else all). `verify_removed()` is a copy of the removal count as
  it was before review 4's design question 1: it does not count claims apart
  from values and spans. Reproduction (`r2.R`, part C): commit `a.qmd` whose
  chunk holds `claim(x, . > 0)`; delete the claim and add `` `r x` `` to the
  prose; stage. `gate()`: `ok = FALSE, n_removed = 1`. `verify(static = TRUE)`:
  `removed` has 0 rows, so the release check says nothing about a removed
  check that the commit gate refuses. `verify_base_side()` also reaches into
  seven gate internals (`gate_state`, `gate_side_entries`, `gate_sizes` with a
  hand-built `list(list(new = s, parents = list()))`, `gate_side_keys`,
  `gate_side_results`, `cache_prune`, `gate_versions`).
- Change: cut two pure functions into `R/gate.R` (or a small `R/compare.R`):
  `findings_excess(new, bases, added_lines)` returning the `excess` table, the
  count added and the instances to list (H16), with `bases` a list of finding
  tables combined by maximum as the gate does for merge parents, and
  `constructs_removed(bases, new)` returning `n` and the rows, claims counted
  apart (G12 as changed). `gate_judge_project()` and `verify_lints()` both call
  them; `verify_added()` and `verify_removed()` go. Add
  `read_side(top, entries, prefix, deeper)` wrapping state, sizes, keys,
  results and prune, so that `verify_base_side()` calls one function.
- Risk: the gate's verdicts. Guarded by `test-gate-judge.R`,
  `test-gate-edits.R`, `test-gate-sides.R`, `test-gate-history.R`,
  `test-verify-static.R`, `test-review-4.R`. Add the reproduction above as a
  test of `verify()`.
- Size: M.

### 2. `lints()` and `verify()` of a parent project read a nested project's documents with the parent's settings

- Kind: bug.
- Where: `R/lint.R` `lint_files_under()` 271-285 and `lints()` 397-400
  (`root` from `find_project_root(full)`, every document under it linted with
  `lint_config(root, ...)` at 309-313); `R/verify.R` `verify_base_side()` 371
  (no `deeper`).
- What is wrong: ruling 7 of review 4 makes a document belong to the innermost
  project. The gate does this (`gate_side_entries(..., deeper)`); `lints()` and
  `verify()` do not. Reproduction (`r5.R`): `_weft.yml` with
  `label_words: [Site]` at the top, `sub/_weft.yml` without; commit; add
  `Site 3 was wet.` to `sub/x.qmd`. `lints(top)`: 0 numeral findings in
  `sub/x.qmd`; `lints("sub")`: 1. `gate()`: refused, 1 finding added.
  `verify(static = TRUE, path = top)`: passed, 0 added. An author who runs the
  lints or `verify()` at the top is told the commit is clean, and the hook
  refuses it.
- Change: give `lint_files_under()` the gate's rule: leave out the subtree of
  any folder below `root` that holds `_weft.yml` (one `list.files(root,
  "^_weft\\.yml$", recursive = TRUE)` and a prefix filter, the same as
  `gate_side_entries()` 116). `verify_base_side()` passes the same `deeper`
  prefixes. The project-scope rules then also stop crossing into the nested
  project, which matches the gate.
- Risk: what `lints(top)` reports in a repository with nested projects (an R
  package with fixture projects under `tests/` stops linting them from the
  top, which is what design question 6 wanted). Guarded by `test-lint-findings.R`,
  `test-lint-xref.R`, `test-gate-sides.R`, `test-verify-static.R`; add the
  reproduction.
- Size: S.

### 3. One git runner and one added-lines reader; `changes()` drops documents whose names git quotes

- Kind: bug, duplication.
- Where: git is run four ways: `gate_g()`/`gate_g_ok()` (`R/gate-git.R` 13-38,
  status checked, raw output), `changes_git()` and `changes_git_z()`
  (`R/changes.R` 123-167, `NULL` on any failure), and a bare `system2()` in
  `recall_check()` (`R/recall.R` 80-81). Unified-diff hunks are parsed three
  times: `git_added_lines()` (`R/gate-git.R` 195-208), `verify_added_lines()`
  (`R/verify.R` 255-269), `changes_added_lines()` (`R/lint-doc.R` 1041-1073).
- What is wrong: `changes_added_lines()` lists changed and untracked files with
  `diff --name-only` and `ls-files --others` without `-z`. With
  `core.quotepath=false` git still C-quotes a name holding `"`, `\`, a tab or
  a newline, so `intersect(docs, ...)` loses it. Reproduction (`r2.R`, part D):
  `plain.qmd` and `say "hi".qmd`, both committed, both given the sentence
  `The result is significant and robust.`; `changes_tier2()` lists the
  `claim-word` finding of `plain.qmd` only; git printed
  `"\"say \\\"hi\\\".qmd\""`. Also, `changes_git()` turns a failed `git diff`
  into `NULL`, which `changes_added_lines()` reads as "nothing changed", and a
  failed `cat-file -e` into "the file is new"; and the known
  `tryCatch(..., error = function(e) NULL)` at `R/lint-doc.R` 1085 reports any
  R fault inside it as "git could not give the added lines".
- Change: move `gate_g`, `gate_g_ok`, `raw_lines`, `raw_records` from
  `R/gate-git.R` into an `R/git.R` as `git_run()` / `git_run_ok()` (names
  aside, the code stays). Re-implement `changes_git()` and `changes_git_z()`
  as thin calls to it, and use it in `recall_check()`. Add one
  `git_diff_added(top, args)` that runs `diff -U0 --no-color --no-ext-diff`
  and parses the hunks; the three callers pass their own arguments.
  `changes_added_lines()` lists names with `-z`, and lets a git failure raise
  `weft_gate_error`; `changes_tier2()` catches that class only, so an R fault
  surfaces.
- Risk: `changes()` output. Guarded by `test-changes.R`,
  `test-changes-findings.R`, `test-trial-2i-changes.R`, `test-gate-trailer.R`,
  `test-verify-static.R`. On Windows the shared runner inherits review 4's
  note on `system2(env =)`; fixing that once is a further gain.
- Size: M.

### 4. `!expr` in `_weft.yml` runs when `yaml.eval.expr` is on, or under yaml before 2.3.0

- Kind: robustness.
- Where: `R/lint.R` `lint_config()` 223 and 229; `R/use-weft.R` `status()`
  305; `R/gate-git.R` `store_dirs()` 187 (a committed `_targets.yaml` blob, in
  the hook). Outside this area: `R/config.R` 103, 122, 137, `R/decisions.R`
  98, `R/hashes.R` 34.
- What is wrong: these calls leave `eval.expr` to yaml's default, which is
  `getOption("yaml.eval.expr", FALSE)` in yaml 2.3.12 and was `TRUE` before
  2.3.0 (yaml's NEWS); `DESCRIPTION` sets no version floor. Reproduction
  (`r4.R`): `_weft.yml` holding
  `guard_words: !expr "file.create('<path>'); 12L"`; under
  `options(yaml.eval.expr = TRUE)` both `lints()` and `status()` create the
  file. `lints()` and `gate()` read text from any branch an author checks out,
  and review 4 noted (as sound) only that 2.3.12 refuses it.
- Change: pass `eval.expr = FALSE` in every `read_yaml()`/`yaml.load()` that
  reads project or committed text (the other reads in this area already do),
  and add `yaml (>= 2.3.0)` to `DESCRIPTION`.
- Risk: none for valid settings; a project that relied on `!expr` in
  `_weft.yml` (none is documented) would see the text. `test-lint-config.R`,
  `test-config.R`, `test-status.R`.
- Size: S.

### 5. `config-place` keeps its own list and misses `verify_skip`

- Kind: bug.
- Where: `R/lint-doc.R` 15-16 (`CONFIG_PLACE_KEYS <- c("draft", "decisions")`,
  comment "stage 4 adds its switch key"), used at 780.
- What is wrong: design-4 G4(c) puts the project-only names in one
  `project_only_settings()` (`R/config.R` 168), which returns `draft`,
  `decisions`, `verify_skip`. Reproduction (`r1.R`, part A): with `_weft.yml`
  present, a document front matter `weft: { verify_skip: [render], draft: true }`
  gives one `config-place` finding, for `draft`; `verify_skip` is not flagged.
- Change: delete `CONFIG_PLACE_KEYS` and its comment; use
  `project_only_settings()` at line 780.
- Risk: one more tier-1 finding where the setting sits in the wrong place.
  `test-lint-hygiene-doc.R`, `test-lint-config.R`.
- Size: S.

### 6. Indented code is found three ways; the copy in `block-start` reads list markers inside chunks

- Kind: bug, duplication.
- Where: `R/lint-source.R` `mask_prose()` 529-559 (computes it, keeps it
  private); `R/lint-code.R` `indented_code_lines()` 212-240 (a line-for-line
  copy, the workaround the build left); `R/lint-pandoc.R` `block_start_r()`
  284-301 (a third version with `cummax`, which does not exclude fenced and
  metadata lines from `marker` and `col0`). The closed-fence test is also
  written twice in that file (266-268 and 335-336).
- What is wrong: the copies have drifted. Reproduction (`r3.R`, part J): an R
  chunk whose code holds the line `- 1`, a blank line, then
  `` `r x` sheep `` indented four spaces. `indented_code_lines()` marks the
  line as code (so the code rules skip the construct), but `block_start_r()`
  thinks the list opened by `- 1` inside the chunk is still open and gives no
  finding; without the `- 1` line it gives the finding.
- Change: have `mask_prose()` return its `icode` vector and `read_source()`
  store it as `src$icode`; `indented_code_lines()` returns `src$icode` and the
  loop goes; `block_start_r()` (b) tests `src$icode[ln]` and the line before
  it instead of rebuilding list state. Add `fence_closed(lines, fb)` beside
  `fence_blocks()` for the two closed-fence tests. The nested-span rescan in
  `span_items()` (`R/lint-code.R` 560-565) is the same kind of workaround; it
  can stay until the reader exposes nested spans, but say so in its comment.
- Risk: `block-start` and the code rules on indented material.
  `test-lint-block-start.R`, `test-lint-source.R`, `test-lint-values.R`,
  `test-review-3.R`.
- Size: S.

### 7. Project metadata files are found four ways; `tar-cache` ignores `_quarto.yaml`

- Kind: bug, duplication.
- Where: `R/lint-doc.R` `file_cache()` 888-905 (`_metadata.yml` and
  `_quarto.yml` only), `doc_bib()` 372-396 (both spellings, its own folder
  walk), `lint_config_place()` 755 (both); `R/lint-source.R` `read_source()`
  928-935 (`_quarto` only, read once per document with `readLines`).
- What is wrong: reproduction (`r1.R`, part H): a chunk reading
  `targets::tar_read(thing)` in a project whose `_quarto.yml` sets
  `execute: cache: true` gives one `tar-cache` finding; the same project with
  the file named `_quarto.yaml`, which Quarto reads, gives none.
- Change: one `project_meta_files(root, rel)` in `R/lint-doc.R` returning the
  existing `_metadata.yml|yaml` files from the document's folder up to the
  root, then `_quarto.yml|yaml`, in precedence order, and one cached YAML
  reader (`dl_yaml_file()` already caches on the context). `file_cache()`,
  `doc_bib()` and the `lang` lookup in `read_source()` use them.
- Risk: `tar-cache` and citation keys in projects using `.yaml`.
  `test-lint-hygiene-code.R`, `test-lint-cite.R`, `test-lint-claims.R`.
- Size: S.

### 8. Rules are found by function name, and the name space already collides

- Kind: structure.
- Where: `R/lint.R` `lint_rule_fun()` 80-85; header comment 5-9.
- What is wrong: `lint_<id>` lookup means every internal helper whose name
  starts `lint_` is a potential rule. The rule `read` already collides with
  the reader `lint_read()`, hence the special case at line 82. Twelve other
  helpers share the prefix (`lint_abort`, `lint_cache`, `lint_config`,
  `lint_files_under`, `lint_open`, `lint_prose_view`, `lint_rel_path`,
  `lint_rule_fun`, `lint_rule_table`, `lint_rule_table_build`, `lint_rules`,
  `lint_sentences`; checked in `r3.R`, part R). A future rule id `config`,
  `cache` or `open` would call a helper with the wrong arguments and fail at
  run time, or not at all. Today every id has its function and none is
  registered twice.
- Change: put the function in the table: a `fun` list built in
  `lint_rule_table_build()` (`fun = list(numeral = lint_numeral, ...)`, `read`
  mapped to `NULL`), or name rule functions `rule_<id>`. `lint_rule_fun()`
  becomes a lookup; the special case and the "a rule with no function is
  skipped" sentence go. Keep a test that every id has a function.
- Risk: low. `test-lint-findings.R`, `test-lint-config.R`.
- Size: S.

### 9. Five lists of "the project's documents" with four rules

- Kind: duplication.
- Where: `R/lint.R` `lint_files_under()` 271-285; `R/gate-git.R`
  `is_doc_path()` 169-177; `R/use-weft.R` `doc_files()` 410-417;
  `R/setup.R` `setup_plan()` 160-167; `R/lint-doc.R` `lint_config_place()`
  757-761.
- What is wrong: they disagree. `r1.R`, part F, over one folder:

  | file                 | lints | gate | status | use_setup |
  |----------------------|-------|------|--------|-----------|
  | `a.qmd`              | yes   | yes  | yes    | yes       |
  | `_inc.qmd`           | yes   | yes  | no     | no        |
  | `sub/_part.qmd`      | yes   | yes  | no     | no        |
  | `node_modules/x.qmd` | yes   | yes  | no     | no        |
  | `packrat/y.qmd`      | yes   | yes  | no     | no        |

  So a document under `packrat/` or `node_modules/` is linted and gated
  (including the `engine` rule) but never set up, and `status()` judges
  activation on a different set from the one the lints use. Some of this is
  intended (a `_` file is an include, and `lint_engine()` skips it by its own
  test at 837), but nothing states the rule in one place.
- Change: one `project_doc_paths(rel, for = c("lint", "setup"))` in
  `R/lint.R` that classifies relative paths: one skip list of folders
  (`.`-folders, `renv`, `packrat`, `node_modules`, Quarto's output folders),
  `_` folders read for anchors only (ruling 2 of review 3), and `_` files
  excluded from set-up. `lint_files_under()` lists files and calls it;
  `is_doc_path()` calls it on index paths; `doc_files()` and `setup_plan()`
  call it with `"setup"`. Decide with the owner whether `packrat` and
  `node_modules` are skipped everywhere (likely) and whether a top-level
  `_x.qmd` is linted (it is today).
- Risk: changes which files are linted and set up. `test-lint-findings.R`,
  `test-lint-xref.R`, `test-gate-sides.R`, `test-use-setup.R`,
  `test-status.R`.
- Size: M.

### 10. `status()` says a document lacks `engine: knitr` that `use_setup()` sees, so the next step never clears

- Kind: bug, duplication.
- Where: `R/use-weft.R` `use_doc_front()` 420-425 and `qmd_lacks_engine()`
  427-437 (text regex on front-matter lines); `R/setup.R` `fm_plan_doc()`
  338-347 (the parsed names). Front matter is also read by `doc_front()`
  (`R/lint.R` 288-300) and by `read_source()` (`R/lint-source.R` 920-925)
  through `metadata_blocks()`.
- What is wrong: reproduction (`r6.R`): a Quarto project with the `.Rprofile`
  route and `a.qmd` whose front matter has `"engine": knitr`. `use_setup()`
  plans no write; `status()` reports activation `missing`, "no `engine: knitr`
  in a.qmd", and its `next` says to run `use_setup()`, which changes nothing.
  The rule "not another engine's chunks alone" is written in both files.
- Change: one `qmd_needs_engine(fm_names, body)` in `R/setup.R` holding the
  rule; `fm_plan_doc()` calls it with `names(y)`, and `qmd_lacks_engine()`
  parses the front matter with `fm_parse()` (inside `tryCatch`) and calls it.
  `use_doc_front()` can then use the same split as `fm_plan_doc()`.
- Risk: `test-status.R`, `test-use-setup.R`, `test-front-matter.R`.
- Size: S.

### 11. `lints()` silently accepts a `formatters` setting that the render rejects

- Kind: robustness.
- Where: `R/lint.R` `lint_config()` 243:
  `tryCatch(check_formatters(cfg$formatters), error = function(e) cfg$formatters)`.
- What is wrong: reproduction (`r3.R`, part L): `_weft.yml` with
  `formatters: { mm: 5 }`. `lints(tier = 1:2)` returns 0 findings and no note;
  `read_config()` stops with "The formatter name `mm` must be a class name
  with a leading dot." Every other invalid setting makes `lint_config()` raise
  `weft_config_error`, which the gate reports as "did not read" (G18).
- Change: let the error through as `weft_config_error` (wrap it with
  `weft_abort(..., "weft_config_error")`), as for the other settings. If the
  lints must survive it, add a `ctx` note instead; either is better than
  silence.
- Risk: the gate starts refusing commits whose `formatters` are malformed,
  which is G18's behaviour for every other setting. `test-lint-config.R`,
  `test-gate-judge.R`.
- Size: S.

### 12. `label_seed(paths)` reads its settings from the working folder's project

- Kind: bug.
- Where: `R/lint-prose.R` `label_seed()` 328 (`find_project_root(getwd())`),
  then 351-352.
- What is wrong: with `paths` given, the root, and so `_weft.yml` and its
  `label_words`, come from the working folder, not from the documents.
  Reproduction (`r1.R`, part G): project B's `_weft.yml` has
  `label_words: [Site]`; `label_seed("<B>/a.qmd")` run from an unrelated
  folder lists `Site`, run from inside B does not. `lint_rel_path()` returns
  an absolute path when the file is outside the root, which hides the slip.
- Change: with `paths` given, take the root of each path with
  `find_project_root(path)` and read it with `lint_open(root, rel)`; with
  `paths = NULL` keep `getwd()`.
- Risk: `test-label-seed.R`.
- Size: S.

### 13. Split `lints()` and give the gate one call for both scopes

- Kind: structure.
- Where: `R/lint.R` `lints()` 356-459 (104 lines: argument checks, rule
  selection, root and report set, the file loop, the project loop); the
  project-scope filter at 451-452; `R/gate.R` `gate_side_results()` 281-284
  (two `lints()` calls because `lints(files =)` filters project-scope
  findings to the report set).
- What is wrong: the filter expression
  `res$file %in% report | (is.null(files_rel) & dir.exists(full) & (identical(full, root) | startsWith(...)))`
  is hard to check by eye, and the gate pays a second context build and a
  second rule selection to get round it.
- Change: keep `lints()` as the exported checker of arguments, and move the
  run into `lint_run(root, report, sel, project = c("report", "all"))`,
  which returns findings and notes. `lints()` computes `report` once (with a
  named helper for the folder or file case) and calls it with `"report"`;
  `gate_side_results()` calls it once with the file rules on `miss` and the
  project rules with `"all"`. The `exists("pandoc_path", ...)` guard at 391
  goes (see 18).
- Risk: every lint path. `test-lint-findings.R`, `test-lint-config.R`,
  `test-gate-*.R`, `test-review-3.R`.
- Size: M.

### 14. `use_setup()` has its own write loop and place check

- Kind: duplication.
- Where: `R/setup.R` `use_setup()` 89-119 and `check_place()` 181-189;
  `R/install.R` `place_check()` 121-137, `plan_item()` 142-146,
  `write_items()` 163-181, `finish_install()` 184-191.
- What is wrong: the two write paths do the same job with different shapes
  (`writes` with `rel`/`purpose`/`copy_from` versus items with
  `label`/`text`/`mode`), and `check_place()` does not check for a file in a
  parent folder's place as `place_check()` does. `use_weft()` has to treat the
  setup step differently from the others for it (`R/use-weft.R` 42-60), and
  review 4's partial-write message fix had to be made in both.
- Change: have `setup_plan()` build `plan_item()`s (add `copy_from` to
  `plan_item()` and let `write_items()` copy when it is set), use
  `place_check()`, and end `use_setup()` with `announce_items()`,
  `write_items()` and `finish_install()`. `use_weft()` then runs the setup
  items like the others.
- Risk: message text of `use_setup()`. `test-use-setup.R`,
  `test-use-setup-rmd.R`, `test-use-weft.R`, `test-version-record.R`.
- Size: M.

### 15. The version warning gives the wrong advice when the project records a newer weft; the tests' "older" version is newer

- Kind: message.
- Where: `R/verify.R` `verify_version_warning()` 231-239; `R/use-weft.R`
  `status()` 316-318 and `version_line_update()` 210-220; `R/install.R`
  `file_status()` 114; tests `helper-4b.R` 231 and 374, `helper-4c.R` 33,
  `test-status.R` 88, `test-use-setup.R` 265, `test-use-weft.R` 144.
- What is wrong: H28 rules that any difference warns, and the code does that
  (`file_status()` and `whole_state()` call a file from 9.9.9 `outdated` and
  `replace`; reproduced in `r1.R`, part B). But the text always says "Run
  weft::use_weft() to update the files weft installed and the record", and
  `use_weft()` then lowers the record and rewrites the hook and workflow to
  the older templates without saying it is a downgrade. A collaborator on an
  older weft will flip the project back and forth with one on a newer. The
  tests forge the "older template" as `0.0.1`, which is newer than
  `0.0.0.9001`, so no test covers the older case they describe.
- Change: keep the warning (H28) and choose the advice with
  `utils::compareVersion()`: when the record is newer, say "weft X is
  installed, older than the X' this project records: update weft, or run
  use_weft() to take the project back to X". Have `use_weft()`'s plan line say
  "(downgrade)" in that case. Change the forged version in the helpers to one
  that is older (for example `0.0.0.1`) and add one test with a newer one.
- Risk: message text only. `test-status.R`, `test-version-record.R`,
  `test-use-weft.R`, `test-use-agent-docs.R`, `test-use-hooks.R`.
- Size: S.

### 16. Stale texts after the two patch rounds

- Kind: message.
- Where and what:
  - `R/lint-pandoc.R` 280 and 356: the `block-start` hint says "escape it (for
    example `\\#`)". Since ruling 1 of review 3, `#` no longer cuts a span;
    the markers are a setext line, a definition `:` and a closed backtick
    fence (reproduced: the hint follows a `:` finding). Say "escape the
    first character (for example `\\:` or `\\-`)".
  - `inst/agent/SKILL.md` "Draft mode": "the commit gate passes nothing in
    it". Rule 9.4.3 (design-4 line 46, G-text line 206): the hook ignores
    draft mode. Say "the commit gate ignores it and judges every commit as
    usual".
  - `R/lint.R` 5-9 and 80: "How a later package adds a rule (3b, 3c, 3d)",
    "a rule with no function is skipped", "or NULL when it is not built yet":
    every rule is built (see 8).
  - `R/lint-doc.R` 15 ("stage 4 adds its switch key"): goes with 5.
  - `R/lint-doc.R` 1053-1056: `dict-key` notes "dict.yml could not be read"
    for a `dict.yml` that holds only a comment (reproduced, `r3.R` part K:
    `yaml` returns `NULL` for a valid empty file). Treat a `NULL` from a
    successful parse as an empty dictionary and note only on a parse error.
- Risk: text only, plus the empty-dictionary case. `test-lint-block-start.R`,
  `test-use-agent-docs.R` (the skill's hash changes), `test-lint-hygiene-code.R`.
- Size: S.

### 17. Dead code and unused arguments

- Kind: dead code. Each checked with grep across `R/`, `inst/`, `tests/`.
- Where:
  - `R/lint.R` 391: `if (exists("pandoc_path", mode = "function"))`, a guard
    from the parallel build; the function always exists.
  - `R/lint-source.R` 274 and 971: `source_pieces(..., cfg_file, ...)` is
    never read, and is passed `NULL`.
  - `R/lint-source.R` 572: `sp` is computed and never used; 473 and 758
    return `numeric_ok` and `notes = list()`, which no caller reads.
  - `R/recall.R` 7: `recall_normalise(with_map = TRUE)` is never read; 113:
    `order_docs` is never used.
  - `R/verify.R` 337: `keep <- vapply(..., function(i) NA, NA)` is
    overwritten at 343.
  - `R/lint-doc.R` 34 `dl_empty()` (an alias of `new_findings()`, 23 uses) and
    720 `isFALSE_vec()` (one use, `ch$eval %in% FALSE` says it).
  - `R/lint-code.R` 316-318 `lc_find()` is `finding_at()` with arguments
    renamed; `lc_find_all()` (322-327) is the batched form review 3's #10
    asked for, used by two rules of twelve.
- Change: delete them; call `finding_at()` and `new_findings()` directly.
- Risk: none beyond a typo. Whole suite.
- Size: S.

### 18. Small helpers written several times

- Kind: duplication.
- Where and what:
  - "The innermost block or sentence holding an offset": `src_block_of()`
    (`R/lint-prose.R` 12-29), `doc_inner_block()` (`R/lint-doc.R` 445-451),
    `innermost_sentence()` (`R/lint-prose.R` 191-198), each with its own idea
    of "innermost".
  - Regex captures as offsets: `gmatch()` (`R/lint-source.R` 26-32),
    `dl_matches()` (`R/lint-doc.R` 58-71), `pandoc_caps()`
    (`R/lint-pandoc.R` 118-128).
  - Trimming: `trim_ws()`, `dl_trim()`, `gate_ws()`, `trimws()`.
  - A path relative to the root: `lint_rel_path()`, `rel_label()`, `rel()` in
    `setup_plan()`, and `substring(nf, nchar(root) + 2L)` in `lints()`,
    `verify()` and `verify_render_list()`; and the `files =` validation, copied
    between `lints()` 403-413 and `verify()` 67-78 (they differ: only
    `verify()` refuses a folder).
  - The stamp file of a document: `freeze_stamp_run()`
    (`R/verify-render.R` 77-87) and `verify_read_stamps()` (277-298).
- Change: keep one of each (`src_block_of()` as the innermost-block helper,
  `gmatch()`, `trim_ws()`, `lint_rel_path()`, a `resolve_doc_args(files,
  root, abort)` used by both entry points, a `stamp_path(root, rel)`), and
  replace the others. Do these as each file is touched for another reason;
  none is urgent on its own.
- Risk: small, spread. `test-lint-*.R`, `test-verify-*.R`.
- Size: M (in total).

### 19. Two shapes of a findings table and eight wrappers between them

- Kind: duplication.
- Where: `R/lint.R` `new_findings()`, `bind_findings()`, `finish_findings()`;
  `R/gate.R` `plain_findings()`, `empty_plain_findings()`, `bind_plain()`,
  `as_weft_findings()`; `R/lint-code.R` `lc_find*()`; `R/lint-doc.R`
  `dl_empty()`.
- What is wrong: the gate caches plain data frames and turns them back into
  `weft_findings` with its own sort (`as_weft_findings()`, which also drops
  the `n_files` attribute `finish_findings()` sets), so a sort or column change
  must be made in two places.
- Change: make `as_weft_findings()` call `finish_findings()` (same key, same
  attributes), and `bind_plain()` call `bind_findings()` on plain frames. Keep
  the plain form only as the cache's storage.
- Risk: the gate's report order. `test-gate-judge.R`, `test-lint-findings.R`.
- Size: S.

## Left alone on purpose

- Speed. `bind_findings()` per finding, the two passes of `chunk_literals()`
  per chunk (`read_source()` 951-955 and `source_pieces()` 413-416), and the
  character-by-character scanners in `R/lint-code.R` are cost questions for the
  profile, not this review.
- `pandoc_json()` reads with `commonmark_x` while ruling 1 of review 3 is about
  Pandoc's `markdown` reader. The ruling narrowed the R half of
  `block-start`; whether `reader = "pandoc"` should switch reader is a design
  question, not a seam.
- `gate_added_lines()` uses the first merge parent for the "instances on added
  lines" listing. It only chooses which instances to print (H16), and the
  counts use every parent.
- `verify_git()` turns any git failure into "no commit to compare with". That
  is H19 (count only, noted).
- `verify_has_constructs()` swallowing errors: `verify_lints()` has already
  read every document with the same reader, so a fault there stops `verify()`
  first; the handler is unreachable in practice.
- The two marker schemes (`weft-file:` lines in whole files, the
  `weft:start` block in `AGENTS.md`). They hash different spans for a reason
  and are short; merging them buys little.
- `use_quarto()` files carry no marker: ruling 4 of review 4.
- `gate_g()` making two temporary files per call: cleaned on exit, and the
  raw output is needed for `-z`.
- `recall_check(commit =)` on a subfolder: reproduced as correct.
- `recorded_version()` with a byte-order mark before `weft_version:`: R's
  `readLines(encoding = "UTF-8")` handled it in the reproduction.

## Cross-area notes

- `R/config.R` 103, 122, 137, `R/decisions.R` 98 and `R/hashes.R` 34 read
  YAML without `eval.expr = FALSE` (see 4); the `DESCRIPTION` floor for yaml
  belongs to whoever owns it.
- `R/changes.R` `changes_git()` and `changes_git_z()` would become calls to
  the shared runner of 3.
- Stamp files are named `gsub("/", "__", rel)` (`R/verify-render.R` 80 and
  281, and the writer in the rendering core): `a/b.qmd` and `a__b.qmd` share
  a stamp. Not reproduced here; worth a look by the rendering-core reviewer.
- `find_project_root()` (`R/config.R` 331) falls back to `_quarto.yml` and
  then the folder itself, while the gate's projects are the `_weft.yml`
  folders only (G7). Item 2 aligns the lints with the gate inside a project;
  the config reviewer may want one stated rule for "a project".
- `tests/testthat/helper-4b.R` and `helper-4c.R` forge an "older" version
  that is newer (see 15).

## Rulings (orchestrator, 13 Nov, under delegation)

All nineteen proposals are accepted. Order and readings:

- Items 1 to 7, 10 to 12 and 15 change behaviour and get failing
  tests first (`test-review-code-c.R`), written from the
  reproductions above.
- 1, 13: one layer that compares the findings and the construct
  counts of two sides, used by `gate()` and `verify()`; `verify()`
  stops reaching into the gate's internals, and counts as the gate
  does (claims apart).
- 2: a document belongs to the innermost project in `lints()` and
  `verify()` as it does in the gate.
- 3, 7, 9, 18: one git runner (always `-z` where names are listed),
  one reader of added lines, one lookup of project metadata files
  (`_quarto.yml` and `_quarto.yaml`), one lister of a project's
  documents. Shared with reviews a and b; built first by the
  foundations pass.
- 4: closed by the shared YAML reader (review b items 1 and 2).
- 8: rules are held in one explicit table of id and function; nothing
  is found by name.
- 15: the advice says what is true for a project that records a
  newer weft; the tests' "older" fixture version is made older.
