# Review of the test suite (tests/testthat)

Reviewer 4 of 4: the test suite. Reviewed at commit e8c1609 (main has moved on since; nothing below
depends on the later commits). No code, test or fixture was changed. Scratch scripts and their output
are in the session scratchpad under `rc-t/`.

## How this was done

- Every `helper-*.R` and `setup-*.R` file and `tests/testthat.R` were read in full (27 files, 5,021
  lines), and the commit history of `tests/testthat` (120 commits).
- Static scans of every test and helper file with R's parser: bare `expect_error()`, `%in%`
  precedence slips, constant and self-comparing expectations, expectations inside loops, every
  `weft:::` call, every `skip*()` call, top-level names defined twice, helpers never used.
- Sample read in full (two read-only sub-agents, findings spot-checked by me): the 12 largest files
  (test-review-2c, scan, changes, ledger, review-2d, review-4, lint-source, unit-ladder, review-c,
  review-2e2, review-2a, review-3) and 12 chosen at random with Python `random.seed(2026)`;
  `random.sample(rest, 12)` gave test-condition-log, helper-schema, parity, weft-str, perf, review-e,
  use-hooks, collapse, use-setup, failures, use-weft, review-2h.
- Timing: the profiler's folder held only code profiles, no per-file test times. I timed 27 suspect
  files one at a time with `devtools::test(filter = ...)` in a throwaway copy, then measured unit costs
  (one Quarto render, one child-R render, one gate run, one git fixture) on a quieter machine.
  **Caveat:** the per-file run happened while another job ran the full suite and R CMD check; the Mac
  was swapping (6 GB of 7 GB swap in use). Those absolute seconds are inflated, by 3x to over 100x
  for memory-heavy files, so the table below gives both the loaded measurement and an estimate built
  from the quiet unit costs.
- Vacuity was checked by mutation in a throwaway copy (`git archive HEAD`): three deliberate bugs, then
  the tests that name that code were run. Results are quoted in proposals 1 and 2.

## Verdict

Most of the suite is sound. It is careful in ways test suites usually are not: loops over fixture
tables are guarded by a count first (`b_expect_rows()` asserts `length(idx) > 0` before looping),
slow renders are shared through explicit caches, almost every temporary folder is a
`withr::local_tempdir()`, git is fully isolated in the 4a/4b/4c fixtures, and no test writes outside
`tempdir()`. The one `%in%` precedence slip found earlier is fixed; my scan found no other (2 hits, both
correctly bracketed). There are no constant expectations. The problems below are real but local, and
none calls for a rewrite. The biggest wins are cheap: give 33 bare `expect_error()` calls a class
(a broken error path passes today), turn about 30 skips that hide regressions into failures, isolate
git in the older fixtures, and take a few minutes off the run.

## Proposals, ranked

### 1. A broken error path passes 33 bare `expect_error()` calls
- Kind: vacuous. Size: S.
- Where: 33 calls in 18 tests (parser scan, `expect_error(` with no `class` or `regexp`). Main
  clusters: test-review-a.R:188-206 (config validation, a loop of 12 values), test-1f.R:99-102
  (claim levels), test-1f.R:383, test-unit-config.R:71-79 and :225, test-lint-findings.R:251,
  test-phrases.R:87, test-dict.R:58 and :411, test-weft-str.R:59, test-1h.R:222,
  test-unit-ladder-dict.R:240. Also loose patterns that match common words: test-review-e.R:184
  (`nm` is "file" or "span"), test-review-4.R:700 (`newer|kept|keeps|current`).
- What is wrong: any error passes, including "object not found" from a typo in the error path
  itself. Shown by mutation: I changed `validate_config()`'s `bad()` to reference an undefined
  variable (`wht` for `what`), so every config error became an unclassed R error. These still
  passed: review A #18, review A ruling K, review A #19, 1f "a bad thousands_from or serial_comma is
  an error", and all 15 tests of test-config.R. Only one test in the suite noticed (1f "a bad
  thousands_from in _weft.yml fails the render", which reads the message). Likewise, renaming the
  `weft_abort` call for a bad claim `level` to an undefined function left 1f "level must be given by
  name, and any other level is an error" passing.
- Change: add `class = "weft_config_error"` (or the specific class the code raises; every weft error
  carries `weft_error`) to each of the 33 calls. Where the error comes from the `units` package
  (`u(1, zzdb)`, `units::as_units()`), use a `regexp` on the unit name instead. No production change.
- Risk: very low; a call that fails after the change has found an unclassed error, which is itself
  worth fixing in `R/`.

### 2. About 30 skips turn a regression into a skip
- Kind: vacuous. Size: S.
- Where:
  - `skip_if(is.null(key))` x6 (test-decision-63.R:27-85, test-perf.R:18). `ud_tables_key()` calls the
    `units` package's private `default_units_xml()` inside `tryCatch(..., error = NULL)`. Shown by
    mutation: with `ud_tables_key()` returning NULL (the disk cache silently off, which is what a
    change inside `units` would do), test-decision-63 gave 5 skips and 0 failures, and test-perf
    1 skip. The disk cache can stop working and the suite stays green.
  - `put_or_skip()` (test-review-2e2.R:87-95, 14 uses) skips on any error or warning from the fixture
    writer, not only on a file system that refuses the name.
  - Skips with no failing expectation beside them: test-unit-ladder.R:682, :701, :718, :728;
    test-review-2h.R:287, :296; test-review-2d.R:299 (typst), :690, :701 (child R locale tests that
    skip if the child dies early).
  - "Not built yet" guards left from test-first scaffolding, which now skip on a rename:
    test-changes-state.R:23, test-review-closing.R:360, test-lint-pandoc.R:9-10,
    test-verify-config.R:328, `v4_need()` (helper-4c.R:165-177) and `r4_need_engine()`
    (test-review-4.R:299), `e1_no_targets()` guessing among four internal names (helper-2e1.R:146).
- Change: for the key and the guards, replace the skip with an expectation (`expect_false(is.null(key))`,
  `expect_true(exists(...))`) and then `return()` if it failed. Narrow `put_or_skip()` to the one
  condition it means (catch the error, skip only when the message is the file system's). For the
  `skip_if(res$failed)` group, add `expect_false(res$failed)` first, as the sibling tests at
  test-unit-ladder.R:669 already do. Delete `v4_need()` and the exists() guards outright: every
  rule and function they wait for is built.
- Risk: low. A failure that appears after the change is a regression the skip was hiding.

### 3. About 190 tests run git with the developer's global configuration
- Kind: isolation. Size: S.
- Where: `e2x_project()` and everything built on it (`e2x_scenario`, `e2x_rows`, `f3d_scenario`,
  `i2_big_project`: about 175 calls in 9 files, mostly test-changes, test-review-2e2,
  test-trial-2i-changes, test-changes-findings), `c2_git_repo()` (5), `d2_git_init()` (6).
- What is wrong: only the 4a fixtures (`g_repo()` through `git_env()`) blank `GIT_CONFIG_GLOBAL`,
  `GIT_CONFIG_SYSTEM` and `HOME`. The older builders run `git init` and `git commit` under the user's
  global config, so a global `core.hooksPath`, `init.templateDir` (template hooks), `core.autocrlf`
  or `commit.template` on another machine or CI reaches the tests. `e2x_git()` also discards the exit
  status, so a commit refused by a global hook goes unnoticed and the test runs on an empty history.
  (This Mac has none of those settings, so the suite passes here.)
- Change: call `git_env(env)` at the top of `e2x_project()`, `c2_git_repo()` and `d2_git_init()`,
  and make `e2x_git()` stop on a non-zero status as `g_ok_git()` does. Better still, build them on
  `g_repo()` (see proposal 11).
- Risk: low. `git_env()` fixes author dates; check that no changes() test compares commit times
  (none found).

### 4. test-gate-edits.R rebuilds the same baseline 73 times
- Kind: speed. Size: M.
- Where: test-gate-edits.R:38-85, the new file (not in the 15 to 25 minute figure).
- What is wrong: each of the 73 tests makes a fresh repository (`g_scenario()`, 1.3 s measured: init,
  three config calls, add, commit, temp files), commits the identical 282-line baseline, and runs the
  gate cold (2.5 s), then usually warm again with a trailer (1.8 s). Quiet estimate 5 to 6 s per test,
  6 to 7 minutes for the file; measured 1,634 s under load. The HEAD side of the gate is the same in
  every test, and the gate cache (G14) lives in `.git`, so a new repository throws it away each time.
- Change: build one repository per file (baseline committed once, in a `local()` at file level with
  `withr::defer(..., teardown_env())`). Per edit: write the after text, stage, gate, then
  `git checkout HEAD -- . && git reset -q`. The baseline's cache entries are then hits. Keep the
  count_constructs() half (0.12 s per edit) for all 73 edits always.
- Recoverable: about 3 minutes (the repository build and most of the HEAD lint per edit).
- Risk: medium-low. An edit that leaves an untracked file would leak into the next; reset with
  `git clean -fdq` as well.

### 5. 172 rmarkdown renders start a child R by default
- Kind: speed. Size: M.
- Where: helper-render.R:225-240. `render_rmd(in_process = FALSE)` is the default, so each call
  installs nothing but starts `Rscript`, loads rmarkdown and weft, and renders. 172 call sites do not
  pass `in_process = TRUE` (90 do). Largest users: test-conditions (16), test-syntax-fixtures (14),
  test-failures (14), test-activation-cli (13), test-parity (12), test-review-c (11), test-review-d (11).
- Measured: 2.4 s for a child render against 0.9 s in process, so about 1.5 s of overhead each.
- Change: flip the default to `in_process = TRUE` and pass `in_process = FALSE` explicitly in the
  files that need a fresh session (activation-cli, parity, and any test about `.Rprofile`, the hook
  chain or what a new session sees). The in-process path already restores knitr's hooks and options.
- Recoverable: about 3 to 4 minutes.
- Risk: medium. A test that passes only because the child started clean will now see leaked state;
  run the suite twice in one session to flush those out. Expect a handful to need the explicit flag.

### 6. About 108 real Quarto renders, one process each
- Kind: speed. Size: M.
- Where: call sites of `render_qmd`, `qrender`, `qmd_html`, `u4_qrender` and `both()`. Largest:
  test-front-matter (13), test-captions (12), test-review-c (11), test-quarto-render (10),
  test-ledger-quarto (6), test-review-2d (5), test-parity (5), test-activation-cli (5).
- What is wrong: one Quarto render of a one-paragraph document costs about 4 s, almost all of it
  Quarto and knitr starting. helper-1b.R already shows the cure: `b_batch()` puts dozens of cases in
  one document and renders once. Most Quarto tests do not batch.
- Change: in test-front-matter and test-captions, render the cases of each file as one Quarto project
  of several documents in one `quarto render` call (cached in a file-level environment, as
  `v4_real_pass()` does), and read each document's output. Separately, offer a fast local mode:
  `skip_if(nzchar(Sys.getenv("WEFT_TEST_FAST")))` on the real-Quarto tests and the gate-edits loop,
  with CI always running the full set.
- Recoverable: about 1.5 minutes from batching the two largest files; the fast mode removes Quarto
  time (estimate 7 minutes) from local runs only.
- Risk: low for the fast mode; medium for batching (one failing document can hide another's output,
  so check each document's own error).

### 7. Wall-clock bounds make the suite flaky on a loaded machine
- Kind: brittle. Size: S.
- Where: test-lint-perf.R:42, :50, :56 (`< 1 s`, `< 6 s`, `< 1 s`), test-gate-perf.R:24-26 (`< 3 s`),
  test-review-3.R:295 (`< 5 s`), test-review-a.R:304-305 (a time ratio). Only `skip_on_cran()`.
- What is wrong: in my loaded run, 3 of the 4 lint-perf tests and the gate-perf test failed (the
  300-line chapter took 370 s with the machine swapping). In a later run under moderate load the
300-line bound still failed (2.5 s against 1 s). They pass on a quiet machine. A CI runner or
  a laptop running two jobs gets red builds that say nothing about the code.
- Change: run them only when asked (`skip_if_not(identical(Sys.getenv("WEFT_PERF"), "true"))`) and
  run them in a dedicated CI step, or compare against a measured baseline in the same session (time a
  fixed reference workload and assert a ratio) instead of absolute seconds.
- Risk: none to correctness; the performance contract (L16, G15) is still checked where it runs.

### 8. Tests whose fixture does not reach what the title names
- Kind: vacuous. Size: S.
- Where (each checked by reading the code):
  - test-review-2d.R:368-373 "adding an unrelated heading above does not re-key a section pinned with
    an id": one render, no heading is added anywhere.
  - test-lint-source.R:760-763 "sentences follow the document's lang": asserts only `nrow >= 1`; no
    lang is set. test-lint-source.R:660-664 "a chunk with no code has code_first NA or empty": never
    reads `code_first`.
  - test-changes.R:172-181 "null and the empty string differ": checks `text_after` is NA but never
    that `text_before` is "".
  - test-perf.R:41-44 "a paragraph's sentence cuts are kept": passes with no cache at all; only line
    49 touches the cache.
  - Weak matches: test-changes.R:608, test-ledger.R:702 and test-condition-log.R:264
    `expect_match(note, "3", fixed = TRUE)` match any "3" in a note that holds a temporary path.
  - Hedged either-way branches: test-review-2c.R:295-301 and :707-712 (`if (!is.null(r$err))`, both
    arms pass), :593-609 (`expect_false(isTRUE(...))` also passes on NA).
- Change: make each fixture do what its title says (add the heading; set `lang`; assert
  `code_first`; check both sides), anchor the "3" matches (`"\\b3 "` or the exact note), and pick one
  behaviour for the hedged tests or delete them.
- Risk: low; a fix may expose a real bug, which is the point.

### 9. Helper shims source helper files into the global environment
- Kind: isolation / structure. Size: S.
- Where: `d2_need()` (helper-2d.R:6-15), `g2_need()` (helper-2g.R), `h2_need()` (helper-2h.R and again
  in helper-2i.R), the `if (!exists(...)) source(...)` lines in helper-2e1.R:3, helper-2i.R:6,
  helper-closing.R:2-3, helper-review-2d.R:2, and test files test-decision-63.R:3,
  test-unit-ladder.R:4, test-ledger.R:4, test-condition-log.R:3, test-review-2d.R:5.
- What is wrong: they date from when tests were parked in `_2a/`, `_1e/` and similar folders.
  testthat loads every helper before any test, so the guards are dead, but three of them fire at load
  time (helper-render.R sorts after helper-2d/2g/2h) and `source(..., local = globalenv())` copies
  `render_rmd`, `tree`, `put_files`, `weft_test_lib` and a second `.weft_t` into the user's global
  environment. Confirmed: after a `devtools::test()` run those five names are in `globalenv()`. The
  shims also make the helpers fail to load outside the package root (`test_path()` errors).
- Change: delete the shims and the guard lines (about 40 lines). The empty `_1e/`, `_2a/` and
  `_snaps/` folders in the working tree can go too (git does not track them).
- Risk: very low; helper load order is alphabetical and every helper only calls the others at test
  time.

### 10. Session state left behind: the units database and an attached `targets`
- Kind: isolation. Size: S.
- Where: test-review-2a.R:326 `units::install_unit("rvquxc")` is never removed, so :294 and :296
  (`expect_error(units::as_units("rvquxa"))`, same family) fail on a second run in one session; the
  file's header admits it. test-review-2e2.R:448 and `e1_make(plain = TRUE)` (helper-2e1.R) evaluate a
  `_targets.R` holding `library(targets)` in the global environment, which attaches targets for the
  rest of the run. test-perf.R:49 leaves entries in the package's `sentence_cache`.
- Change: wrap the unit install in `withr::defer(units::remove_unit("rvquxc"))` (the 2h and closing
  helpers already have `cl_units_clean()` for this); in `e1_make()` and the 2e2 test, `defer` a
  `detach("package:targets")` when it was not attached before; clear the cache entries the perf test
  added.
- Risk: very low.

### 11. Eight families of helpers are written several times under different names
- Kind: duplication. Size: M.
- Where (all in helper files unless noted):
  - error capture `tryCatch({expr; NULL}, error = function(e) e)`: `a2_err`, `c2_err`, `e1_err`, `f2_cond`.
  - "error has class X and weft_error": `expect_weft_cond`, `c2_expect_cond`, `f2_has_class`.
  - "message holds these fixed strings": `expect_has`, `c2_expect_msg`, `f2_msg_has` (plus `c2_msg`/`f2_msg`).
  - folder snapshots: `tree`, `c2_tree`, `e1_snapshot` (names); `e2x_snapshot`, `n3_tree` (size and
    mtime); `g_snapshot`, `h4_snap`, `u4_md5`, `v4_outside_snap` (md5).
  - print and capture: `g_print_lines` and `v4_print_lines` (identical), `h4_print_lines`; plain
    `capture.output(print(x))` as `e2x_print`, `i2_print`, `f3d_print`.
  - git repositories: `c2_git_repo`, `d2_git_init`/`d2_git_commit`, `e2x_project`/`e2x_commit`,
    `g_repo`/`g_commit`, and two near-copies of `g_repo`'s body in `h4_repo_named` and
    `h4_repo_in_parent`.
  - temporary projects that write files: `put_files`, `e1_put`, `c2_proj`, `f2_proj`, `lint_proj`,
    `u4_dir`, `mk_project`, `e1_tmp`, `d2r_qdir`, plus `e1_write`, `e2x_write`, `f3_write`, `g_write`.
  - child R and Quarto: `r_fresh`, `g2_child`, `u4_r`, `render_rmd_filtered`, `u4_render_rmd`;
    `qrender` and `u4_qrender` differ only in their environment.
  - smaller: `u4_version` = `v4_version`; `g_df` = `v4_df`; `%||%` defined in helper-4c.R and
    test-collected.R; `skip_if_no_git` in helper-4a.R and test-changes-findings.R.
- Change: add one `helper-common.R` (loaded first by name, e.g. `helper-0-common.R`) with one of each:
  `catch_error()`, `expect_weft_error(e, class, msg = )`, `snap_dir(dir, what = c("names", "md5",
  "mtime"), skip = )`, `print_lines()`, `git_repo()` (the `g_repo()` body), `write_files()`,
  `run_rscript()`, `quarto_render()`. Turn the old names into one-line aliases so no test changes in
  the first commit; migrate files as they are next touched. Do not chase the per-package prefixes
  (`b_`, `c2_`, `g_`, ...) away; they are useful.
- Risk: low if the aliases keep behaviour; the snapshot variants differ deliberately (md5 vs mtime vs
  dirs included), so keep `what =` explicit.

### 12. 155 inline git skips instead of the helper
- Kind: structure. Size: S.
- Where: `skip_if(Sys.which("git") == "")` 155 times (53 in test-review-2e2.R alone, every test of
  test-changes.R), plus four with a message; `skip_if_no_git()` exists in helper-4a.R.
- Change: replace with `skip_if_no_git()` by search and replace, or drop them where the fixture
  (`e2x_project()`, after proposal 3 `git_env()`) already calls it once.
- Risk: none.

### 13. 45 internal functions are called from 61 test files
- Kind: brittle. Size: S to M.
- Where: 334 `weft:::` calls (table below). Most are fine: the design names these functions as
  internal contracts (L4, L9, D3). Three are worth wrapping because they are many and are the likely
  first refactor targets: `read_config` (58 calls, 14 files), `check_decisions` (40 calls, 2 files),
  `scan_text`/`scan_file` (35 calls, 19 files). Also `last_knit` is exported but called as
  `weft:::last_knit` in 6 files.
- Change: give each of the three a one-line test helper (`t_read_config()`, `t_scan()`) so a change of
  signature is one edit, not 58. Use `weft::last_knit()`. The mocks of internals
  (`has_curl`, `ud_tables_key`, `git_path`, `read_source`, `requireNamespace`) are fine and few (9).
- Risk: none.

### 14. Gaps: functions and error paths with no direct test
- Kind: gap. Size: S.
- Where:
  - `dict_unmark()` (exported, R/targets.R:612) has no direct test; it is exercised only inside
    `tar_make()` pipelines. A unit test of nested lists, data frames and classed objects is quick.
  - Argument errors of `arms()` (`weft_arms_error`: a missing file, a non-character `file`) and of
    `rehearse()` (`weft_rehearse_error`: a non-existent file, `cases` not a named list of named
    lists): only the name clash and unknown param paths are tested, and by message, not class.
  - Never raised by any test: `weft_config_warning` (R/config.R:176), `weft_knitr_too_old`
    (R/hooks.R:42; needs a mocked `packageVersion`).
  - Thin: `status()` (2 files), `use_ci()` (2), `fmt_dl()` (2), `brk()` (direct calls in 1 file, the
    rest through renders).
  - Windows is untested by design (many fixtures are POSIX shell scripts).
- Change: about 10 small tests, no renders.
- Risk: none.

### 15. Dead helpers and dead local code
- Kind: duplication. Size: S.
- Where: helpers never used anywhere: `expect_has` (2a), `d2_df` (2d), `e1_make_store` (2e1),
  `G2_ENDASH`, `G2_DEG` (2g), `H2_MINUS`, `H2_EN`, `h2_knit` (2h), `i2_msgs` (2i), `lf_rules` (3),
  `h4_edit_line`, `h4_lines` (4b), `cl_read_targets` (closing). In test files: `rc_chr` and the unused
  arguments of `rc_cache_cap()` (test-review-c.R:11, :438), `sc()` (test-collapse.R:5), `r3_rows`
  (test-review-3.R:7), the `wrongtype` variant (test-review-2d.R:215). Empty section headers with no
  tests: test-review-2d.R:795 ("J"), test-scan.R:653. Same function twice: `cx`
  (test-unit-ladder.R:9) and `r2h_cx` (test-review-2h.R), `d2_warn_doc` (test-condition-log.R:13) and
  `d2r_warn_doc` (helper-review-2d.R:42), `make_pipeline` (test-changes-state.R:157) and
  `make_pipeline2` (test-review-2e2.R:445), `expect_refused` (test-use-setup.R:372 and
  test-review-2d.R), `expect_verify_failed` (three files).
- Change: delete the dead ones; move each duplicated pair into the helper of its package.
- Risk: none (verified with grep: each listed helper name occurs only at its definition).

### 16. Repeated identical renders inside a file
- Kind: speed. Size: S.
- Where: test-parity.R:67 and :76 render the same `parity_doc("rmd", FALSE)` (child R each);
  test-failures.R:82 and :202 build and render the same 24-row marker document; test-weft-str.R:147
  renders `str_bad` twice; test-ledger.R:621-640 duplicates test-condition-log.R:172-186 (chunk-cache
  double render).
- Change: memoise each in a file-level cache as the files already do elsewhere (`d2_memo()`).
- Recoverable: under 20 s in total; worth doing only alongside proposal 5.
- Risk: none.

### 17. A map from feature to test files
- Kind: structure. Size: S.
- What is wrong: the files are named by work package and review round (test-review-2a ... review-4,
  review-a ... review-f, trial-2i-*, decision-63), so the tests of one feature are spread over many
  files: the ledger is in test-ledger, review-2d, condition-log, trial-2i-ledger, tar-ledger-reads,
  review-2e1 and review-closing; the units ladder in unit-ladder, unit-ladder-dict,
  unit-ladder-source and review-2h. A maintainer changing `changes()` cannot easily find every test
  of it.
- Change: do not move tests. Add a short comment block at the top of each primary feature file
  (test-ledger.R, test-changes.R, test-gate-judge.R, ...) listing the review-round files that also
  test that feature. Merge a review file into its feature file only when both are being edited anyway.
- Risk: none.

## Internals the tests reach into

From a parse of every test and helper file (`weft:::name`); 45 functions, 334 calls, 61 files.

| Function | Test files | Calls |
|---|---:|---:|
| scan_text | 16 | 18 |
| read_config | 14 | 58 |
| last_knit (exported) | 6 | 7 |
| scan_file | 5 | 17 |
| read_ledger | 4 | 15 |
| default_config | 4 | 8 |
| dict_entry_hashes | 3 | 18 |
| file_hash | 3 | 11 |
| pandoc_path | 3 | 7 |
| recorded_version | 3 | 6 |
| check_decisions | 2 | 40 |
| heading_anchors | 2 | 16 |
| ud_tables | 2 | 14 |
| parse_github_remote | 2 | 11 |
| ledger_state | 2 | 8 |
| read_condition_log | 2 | 7 |
| ud_tables_file | 2 | 7 |
| ud_tables_key | 2 | 6 (and mocked once) |
| un_cache | 2 | 4 |
| lint_config | 2 | 3 |
| count_constructs | 2 | 2 |
| read_source | 2 | 2 (and wrapped by a mock in helper-4a.R) |
| 23 others (ledger_raw, expr_key, git_show, pandoc_id, ledger_sentence, run_id, sentence_cuts, claim_lexicon, decisions_route, need_targets, normalise_condition, apply_formatters, claim_words, code_reads, github_fetch, has_curl, inline_function_names, ledger_paths, mask_text, project_only_settings, report_reads, sentence_cache, source_sentences) | 1 each | 1 to 6 each |

Mocked with `local_mocked_bindings()`: `has_curl`, `ud_tables_key`, `git_path`, `read_source`,
`requireNamespace`, one of `has_targets`/`targets_installed`/... found by name (helper-2e1.R:146).
Looked up by name with `exists()`: `units_reset`, `pandoc_path`, `file_hash`, `dict_entry_hashes`.
No test calls an internal without `:::` (load_all is not relied on).

## The 15 slowest files

"Loaded" is the measured time of `devtools::test(filter = )` for the file alone, while the machine
was swapping; it overstates every file, memory-heavy ones most. "Quiet estimate" is built from unit
costs measured afterwards on a quieter machine: Quarto render 4 s (plus 11.5 s once per session to
install weft into a temp library), child-R rmarkdown render 2.4 s, in-process render 0.9 s, 4a git
fixture 1.3 s, gate run 2.5 s cold and 1.8 s warm, first weft_str of a session 1.4 s. Files not on my
suspect list were not timed and may belong here.

| File | Loaded (s) | Quiet estimate (s) | Main cause |
|---|---:|---:|---|
| test-gate-edits.R | 1634 | 360-420 | 73 fresh git repos, 1-2 cold gate runs each over a 282-line manuscript (proposal 4) |
| test-unit-defaults.R | 1542 | 39 (measured) | 105 tests; units database rebuilt by config reads; 9 child R sessions with `load_all` |
| test-lint-perf.R | 868 | 20 (measured) | four timed lints of 300- and 1,800-line chapters (proposal 7) |
| test-verify-freeze.R | 493 | 60-90 | real Quarto renders through verify(), kill and restore sequences, sleeps |
| test-lint-hygiene-code.R | 376 | 60-90 | 11 real `targets` stores built by `tar_make()` in callr (`c3_store()`) |
| test-1f.R | 328 | 50-70 | a Quarto project render, rehearse() child sessions, 9 child renders |
| test-review-4.R | 239 | 60-80 | about 47 git fixtures, 5 child R, real commits through the hook (Rscript per commit) |
| test-gate-perf.R | 146 | 13 (measured) | a ten-chapter project gated warm (timed) |
| test-verify-render.R | 98 | 50-70 | 10 real Quarto renders through verify() |
| test-review-c.R | 90 | 60-80 | 11 Quarto renders, about 20 rmarkdown renders (many child R), 13 pandoc filter runs |
| test-captions.R | 87 | 50-60 | 12 Quarto renders to HTML |
| test-rehearse.R | 84 | 40-60 | rehearse() starts a child R per case |
| test-perf.R | 83 | 5-10 | units database built and read back from disk |
| test-review-2e1.R | 70 | 40-60 | `tar_make()` per test (`e1_plain_dir()`, `e1_try_make()` in callr) |
| test-parity.R | 68 | 50-60 | about 17 child-R renders and 6 Quarto renders (proposals 5, 16) |

Three files were re-run alone once the load had eased ("measured" above). test-unit-defaults.R then
took 39 s with no failures; its 6 failures in the loaded run came from the load, not from test order.
test-lint-perf.R took 20 s and still failed its 1 s bound (2.5 s), which is proposal 7 in action.
Only test-gate-edits.R, the Quarto files and the child-process files carry enough real work to matter.

Total recoverable, cleanly: about 3 minutes from proposal 4, 3 to 4 from proposal 5, 1.5 from
batching Quarto in two files (proposal 6), so 7 to 9 minutes of a run that, with test-gate-edits.R
added, is probably 20 to 30 minutes on a quiet machine. The fast local mode in proposal 6 would take a
further 7 or so minutes off local runs only.

## Left alone on purpose

- Exact report lines (`"commit-msg: 3 weft constructs removed, ..." %in% rep`, the printed lines of
  changes()). They pin user-facing wording, but the spec defines that wording, and almost all of them
  check one line at a time rather than the whole report. Only test-changes.R:135 and
  test-review-2e2.R:173 compare a whole printed output, and both are one-line outputs.
- The many `expect_true(grepl(...))` (about 2,900 `expect_true`/`expect_false` in all). They give
  poorer failure messages than `expect_match()`, but they test what they say. Converting them is
  style.
- The per-package helper prefixes and helper files. Merging `helper-3*.R` or `helper-4*.R` into fewer
  files would churn without gain; proposal 11 only adds a common layer.
- The shared render caches (`.b_cache`, `d2_memo()`, `e1_memo()`, `v4_cache`). They create order
  coupling inside a file, but each is lazy (the first test that needs it builds it), so no test
  depends on another having run.
- `helper-options.R` sets `keep.source`, `R_TESTS` and `R_PROFILE_USER` for the whole session without
  restoring them. That is deliberate (child processes need it) and it only affects the test session.
- Self-comparisons in test-dict.R:112, test-unit-ladder.R:616 and test-changes-state.R:9 are labelled
  determinism controls; cheap and harmless.
- Converting tests to snapshots, renaming titles, or reorganising files by feature.
- Windows: untested by design.

## Rulings (orchestrator, 13 Nov, under delegation)

All seventeen proposals are accepted. Order and readings:

- First the tests that cannot fail (1, 2, 8): every bare
  `expect_error()` gets the class it should see; a skip that hides a
  regression becomes a failure unless the thing skipped for is truly
  absent (a missing program or package); a test does what its title
  says. Each test changed this way is run against the code, and a
  test that now fails is a finding to report, never something to
  bend.
- Isolation next (3 and its like): every test that runs git does so
  under an isolated configuration (`GIT_CONFIG_GLOBAL`,
  `GIT_CONFIG_SYSTEM`, `HOME` where needed), through one shared helper.
- Speed, only where it is real (4, 5, 6): the gate edits share one
  repository per file; rmarkdown renders run in process unless the
  test is about a fresh process; Quarto renders are shared where
  several tests read the same output. Nothing is covered less. A fast
  local mode that skips real Quarto renders is opt-in through an
  environment variable; the default and CI run everything.
- Wall-clock bounds (7) become ratios against a baseline measured in
  the same test, or generous bounds that are skipped under
  `R CMD check`, so load does not fail them.
- Duplicated fixture builders and helper files (the duplication and
  structure items) are merged last, after the refactor of `R/`, so the
  two do not collide.
