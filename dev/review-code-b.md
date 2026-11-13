# Code review B: units, dictionary, targets, ledger, configuration

Reviewer B, 2026-11-13. Scope: `R/units.R`, `R/unit-names.R`, `R/unit-defaults.R`,
`R/dict.R`, `R/dict-tools.R`, `R/targets.R`, `R/ledger.R`, `R/config.R`,
`R/changes.R`, `R/use.R`, and `inst/weft-units.yml`, `inst/dict/`. Every bug and
robustness item below was reproduced with a small script in a temporary folder
(`load_all()`, a fresh `R_USER_CACHE_DIR`); what did not reproduce was dropped.

Overall: the area is careful and well guarded. The units state machine
(`ud_sync()`, `read_units_tables()`) is intricate but consistent, `on.exit` cleanup is
right where it is used, the ledger writer is atomic and byte-stable, and the disk cache
of the units tables is keyed and written safely. The real problems are at the edges:
how YAML is read, which project a unit belongs to when nothing has read the
configuration yet, and a handful of helpers written two to five times.

## Proposals, most worth doing first

### 1. `_weft.yml` is read as YAML 1.1, so `N`, `no`, `on`, `off` turn into booleans
- Kind: bug (with duplication)
- Where: `R/config.R` `read_config_()` 102-139 (three `yaml::read_yaml()` calls on the
  same file), `check_raw_scalars()` 401-417; `R/lint.R` `lint_config()` 221-231;
  `R/decisions.R` 98; `R/use-weft.R` 305.
- What is wrong: the dictionary reader keeps YAML 1.1 booleans as text
  (`dict_yaml_handlers()`), but `_weft.yml` is read with the default handlers. Reproduced:
  - `units: {N: {name: newton-force}}` gives a `units:` row keyed `FALSE`: the read
    succeeds, the newton row is silently lost, and a unit named `FALSE` is registered.
  - `claim_words: {drop: [no, all]}` fails with "must be a mapping with `add` and `drop`,
    each a list of words", which is exactly what the user wrote.
  - `label_words: [on, off]` fails with "must be a list of words without spaces".
  - `severity: [no]` is accepted as the pattern `"FALSE"`.
  - `date_format: %d %B %Y` gives the raw scanner text with the path printed twice and
    no hint that the value needs quotes.
  Quarto reads YAML 1.2, where `no`, `on`, `N` are strings, so the two disagree.
- Change: add one reader, `read_weft_yml(root)`, that reads the file once as text
  (see 6), parses it with `bool#yes`/`bool#no` handlers that mark the scalar (as
  `mark_bool()` does) and `eval.expr = FALSE`, then unmarks: mapping keys and the items
  of the word-list settings (`label_words`, `claim_words`, `expected_names`, `strict`,
  `verify_skip`, `severity`) stay text; every other marked `true`/`false`/`yes`/`no`/
  `on`/`off` becomes a logical, so `serial_comma: yes` keeps working. Return both the
  simplified settings and the sequence-kept `raw` from that one parse, fold the `ledger:
  [true]` check (lines 121-126) into `check_raw_scalars()`, and use the reader in all
  four places. On a parse error, say "cannot read _weft.yml (line L): ... ; a value that
  starts with `%`, `@`, `` ` ``, `[` or `{` needs quotes".
- Risk: a project that relied on `on`/`off` inside a word list meaning a boolean (none
  should). Guards: `test-config.R`, `test-lint-config.R`, `test-unit-config.R`,
  `test-unit-defaults-config.R`, `test-verify-config.R`, `test-decisions.R`,
  `test-review-2g.R`. Add a test for `N:` and `drop: [no]`.
- Size: M.

### 2. The dictionary's hashes use another YAML reading, so a key `n` is always stale
- Kind: bug
- Where: `R/hashes.R` `dict_entry_hashes()` 33-41 (outside the four areas, but its only
  callers are here: `R/targets.R` `chapter_reads()` 824 and `R/changes.R`
  `ledger_state()` 65-68).
- What is wrong: `read_dict()` reads keys and values with `dict_prepare()` and
  `dict_parse()`; the hashes come from `yaml::read_yaml(path)` with default handlers.
  Reproduced with a dictionary holding the keys `n` and `word`: `read_dict()` names them
  `n` and `word`, `dict_entry_hashes()` names them `FALSE` and `word`. A chapter that
  reads `dict$n` records `NA`, and `ledger_state()` then reports `"dict$n is gone"`, so
  `changes()` lists that chapter as "not re-rendered" on every run. Keys `y`, `n`, `yes`,
  `no`, `on`, `off` are all affected, and `n` is a likely key (a sample size). Also,
  changing `value: yes` to `value: true` on a string entry changes what prints but not
  the hash, so the change is missed.
- Change: build the hashes from the same parse `read_dict()` uses: read the lines,
  `prep <- dict_prepare(lines)`, `raw <- dict_parse(prep$lines)`, name `raw` by
  `prep$tk$key` when the counts match, then hash each entry as now. Better still, have
  `build_dict()` compute them and keep them as an attribute, and let `dict_entry_hashes()`
  return `attr(read_dict(path), "hashes")`, so there is one reading.
- Risk: hashes of entries holding `yes`/`no` text change once, so existing ledgers show
  those entries as changed after the upgrade (say so in NEWS). Guards:
  `test-changes-state.R`, `test-tar-ledger-reads.R`, `test-review-2e2.R`.
- Size: S.

### 3. A dictionary read outside a knit ignores the project's `units:` table, and registers its units under the wrong root
- Kind: bug
- Where: `R/dict.R` `read_dict()` 163-174, `dict_register_unit()` 673-690, the
  `ud_dict_registered()` call at 499; `R/unit-defaults.R` `ud_cur_root()` 486-488,
  `ud_dict_registered()` 491-496, `read_units_tables()` 684; callers outside a knit:
  `tar_dict()` and the `dict_values` target (`R/targets.R` 443, 462), `tool_dict()`
  (`R/dict-tools.R` 173-179), `ledger_state()` and `dict_numbers()` (`R/changes.R` 66,
  341), `R/verify.R` 456.
- What is wrong, two reproductions:
  - `_weft.yml` has `units: {zzhaul: {is: 1000 t}}` and `dict.yml` a quantity in
    `zzhaul`. Outside a knit (which is how `tar_dict()` and the pipeline read it),
    `read_dict()` installs `zzhaul` as a new base unit: `set_units(dict$haul, "t")` fails
    with "cannot convert zzhaul into t". A later `read_config()` in the same session
    (for example a `tar_render()` report in the pipeline's process) then fails with
    "`zzhaul` is read by the units package as a unit that is already installed", and
    keeps failing for the rest of the session.
  - The tokens a dictionary installs are recorded against `find_project_root(getwd())`,
    not the dictionary's own project. Reading project A's `dict.yml` while the working
    directory is in project B records A's token under B; reading A's configuration
    again then removes it, and A's quantities are in a unit the database no longer
    knows.
- Change: give `read_units_tables()` a `root` argument and pass `dir` from
  `read_config()`; drop `ud_cur_root()`. Record `ud_state$root`, the root whose `units:`
  table is in force. In `read_dict(path)`, compute `root <- find_project_root(path)` and,
  when `ud_state$root` differs, bring that project's `units:` table and
  `unit_defaults` into force (a small `project_units(root)` factored out of
  `read_config_()` that reads only those two settings, so an unrelated bad setting does
  not stop a dictionary read); pass `root` to `ud_dict_registered()`. In a knit the
  configuration is already read for that root, so this is a no-op. Fix the `read_dict()`
  help (lines 122-128 say "for the whole session", the next paragraph says otherwise).
- Risk: a dictionary read now fails when the project's `units:` table has a problem,
  which is the honest outcome. Guards: `test-decision-63.R`, `test-review-closing.R`
  (#12), `test-unit-config.R`, `test-tar-dict.R`, `test-dict.R`, `test-dict-display.R`,
  `test-changes-state.R`. Add both reproductions as tests.
- Size: M.

### 4. weft's own advice for `kt` fails, and the reason it gives is wrong
- Kind: message
- Where: `R/unit-defaults.R` `unit_token_refusal()` 146-147, `ud_reading_text()`
  268-298.
- What is wrong: refusing `kt`, weft says "define a unit of your own for the kilotonne in
  `units:` (for example `ktonne: {is: 1000 t}`)". That row fails in a fresh session:
  "`ktonne` is read by the units package as a unit that is already installed". Nothing
  installed it; udunits reads `ktonne` as the prefix symbol `k` on the unit name
  `tonne`, a mix `tok_resolve_db()` does not recognise, so `ud_reading_text()` falls to
  its last branch. Same for `kton` and `ktonnes`. `ktn` and `zzkt` install.
- Change: in `ud_reading_text()`, before the "already installed" fallback, try each
  symbol prefix against `ud_core()` of the rest in either kind and say "is read by the
  units package as the prefix `k` (kilo) on `tonne`". Change the advice to a key that
  installs (`ktn: {is: 1000 t}`), and add a test that installs every key a weft message
  recommends (this one and `zzgrade: {name: grade}`).
- Risk: message text only. Guards: `test-unit-defaults.R`,
  `test-unit-defaults-config.R`.
- Size: S.

### 5. `find_project_root()` ignores `_quarto.yaml`; five functions walk up for a marker
- Kind: bug (with duplication)
- Where: `R/config.R` `find_project_root()` 331-348; `R/targets.R` `quarto_root()`
  689-698; `R/use.R` `use_quarto()` 39-51; `R/setup.R` `find_quarto_root()` 129-137;
  `R/unit-defaults.R` `ud_cur_root()` 486-488.
- What is wrong: reproduced with a book whose config is `_quarto.yaml` and no
  `_weft.yml`: `find_project_root("sub")` returns `sub`, while `quarto_root()` returns
  the book's root. So `dict.yml`, `_weft.yml` and the ledger are looked for in the
  chapter's folder. Every other place in the package accepts both names (`use.R`,
  `setup.R`, `lint-doc.R` 372, `scan-contexts.R` 144, `verify-render.R` 193,
  `gate.R` 158). Two of the walkers are `quarto_root()` and `find_quarto_root()`, near
  identical names with different results on failure (start folder versus `NULL`): the
  kind of pair that once broke the package.
- Change: one helper, `find_up(start, markers)`, returning the first folder holding any
  marker or `NA`; `find_project_root()` uses it with `"_weft.yml"` then
  `c("_quarto.yml", "_quarto.yaml")`; `quarto_root()`, `find_quarto_root()` and the loop
  in `use_quarto()` become one call each, keeping their own fallback. Normalise with
  `winslash = "/"` in one place.
- Risk: projects with `_quarto.yaml` get a different root (the right one). Guards:
  `test-use-quarto.R`, `test-use-setup.R`, `test-book.R`, `test-status.R`,
  `test-tar-dict-quarto.R`, `test-verify-config.R`.
- Size: S.

### 6. A file that is not UTF-8 gives a bare error, or is silently cut short
- Kind: robustness
- Where: `R/dict.R` `read_dict()` 170-171; `R/config.R` 103 (`yaml::read_yaml`);
  `R/hashes.R` 34; `R/ledger.R` `read_lines_utf8()` 108-110 (used by seven files);
  `R/unit-defaults.R` 206.
- What is wrong: reproduced. A `dict.yml` holding a Latin-1 `é` stops `read_dict()`
  with `simpleError: input string 2 is invalid` (not a `weft_dict_error`, no file, no
  line). A Latin-1 `_weft.yml` is truncated at the bad byte by `read_yaml()`'s connection,
  and the user sees "found unexpected end of stream" about a quoted scalar. The BOM is
  stripped in `read_dict()` only; `dict_seed()` silently reads non-UTF-8 as Latin-1. Four
  policies for one job.
- Change: one `read_text_utf8(path, what, class)` that reads the bytes, drops a leading
  BOM, splits lines on `\r?\n`, and when `validUTF8()` fails raises the given condition
  class naming `path:line` of the first bad line ("is not UTF-8; save it as UTF-8").
  Use it in `read_dict()`, the reader of item 1, `dict_entry_hashes()`,
  `read_lines_utf8()`'s callers, and parse YAML from its text with `yaml.load()`.
  `dict_seed()` may keep its Latin-1 fallback, which its help documents.
- Risk: low. Guards: `test-dict.R`, `test-config.R`, `test-ledger.R`,
  `test-dict-seed.R`.
- Size: S.

### 7. `use_quarto()` reports a file it failed to write as written
- Kind: bug
- Where: `R/use.R` `use_quarto()` 35-36, 46, 63, 74, 96-105.
- What is wrong: reproduced with a read-only `_extensions/weft-check/`: `file.copy()`
  returns `FALSE` with a base warning, the return value is ignored, and the result and
  the "Wrote:" message list `_extensions/weft-check/weft-check.lua`, which does not
  exist. The function's errors are plain `stop()`, with no `weft_tool_error` class, and
  it writes through a symbolic link, where `use_dictionary()` (same area, same job)
  checks every target for a link and every write for success.
- Change: check each `file.copy()` and `dir.create()`; on failure stop with
  `tool_abort()` naming the file and listing what was written so far (copy the
  `failed()` helper of `use_dictionary()`, or better move it and the link check to one
  shared place used by both). Raise the three `stop()` calls through `tool_abort()`.
- Risk: low. Guard: `test-use-quarto.R`.
- Size: S.

### 8. An unusual top-level key silently becomes `weft_k1`
- Kind: robustness
- Where: `R/dict.R` `build_dict()` 211-216, `dict_prepare()` 66-84.
- What is wrong: `dict_prepare()` renames each top-level key it recognises to
  `weft_kN` and `build_dict()` restores the names only when the counts match. A key the
  regular expression does not recognise but YAML does (reproduced with `!!str yes:` and
  with the explicit `? a` form) makes the counts differ, so the dictionary is returned
  with a key literally named `weft_k1`, and no problem is reported.
- Change: when `nrow(tk) != length(raw)` and any name starts with `weft_k`, add the
  problem "a top-level key is written in a form weft does not read (a tag, or `? `);
  write it as `key:`" and stop as for any other problem.
- Risk: none for ordinary files. Guards: `test-dict.R`, `test-review-2a.R`.
- Size: S.

### 9. The second-`tar_dict()` check depends on a targets internal and has no test
- Kind: robustness
- Where: `R/targets.R` `script_frame()` 397-404, `tar_dict()` 445-451.
- What is wrong: `targets::tar_callr_inner_try` is exported but internal; if a targets
  release renames it, `targets::` errors and every `tar_dict()` call fails, not only the
  check. Reproduced: with the frame check switched off, targets itself already refuses two
  `tar_dict()` results in one pipeline ("duplicated target names: dict_file,
  dict_values, ..."). The weft check adds value only when the first result is assigned
  and dropped (`a <- tar_dict(...)`), which also reproduces. No test exercises the check.
- Change: look the function up with
  `get0("tar_callr_inner_try", envir = asNamespace("targets"), inherits = FALSE)` and
  return `NULL` when it is absent, so the check degrades to targets' own duplicate-name
  error. There is no public API that identifies one evaluation of `_targets.R`
  (`tar_active()` does not, and a marker in `tar_option_get("envir")` would survive into
  the next `tar_make(callr_function = NULL)`), so the frame walk is the right tool; it
  just must not be fatal. Add a test with `tar_manifest(callr_function = NULL)` in a
  temporary folder for both shapes.
- Risk: none. Guards: `test-tar-dict.R`.
- Size: S.

### 10. A units cache file of the wrong shape breaks every unit until it is deleted
- Kind: robustness
- Where: `R/unit-names.R` `ud_tables()` 106-112.
- What is wrong: the disk copy is accepted when its key matches and `v` and `pf` are
  data frames. Reproduced: a cache file with the right key and other columns makes
  `ud_db()` and every `u()` fail with "non-character argument", in this session and
  every later one, with nothing pointing at the cache. It takes a weft change that alters
  what is stored without bumping `weft = 1L` in the key, so it is a development hazard
  more than a user one, but the cost of the guard is one line.
- Change: accept the copy only when `v` has the character columns `ud_db()` reads
  (`symbol`, `symbol_aliases`, `name_singular`, `name_singular_aliases`, `name_plural`,
  `name_plural_aliases`, `def`) and `pf` has `symbol`, `symbol_aliases`, `name`,
  `value`; otherwise treat it as absent (it is then rewritten).
- Risk: none. Guards: `test-perf.R`, `test-decision-63.R`.
- Size: S.

### 11. The git runner is written three times
- Kind: duplication
- Where: `R/ledger.R` `git_run()` 215-224; `R/changes.R` `changes_git()` 123-132 (the
  same body, line for line), `changes_git_z()` 150-168; `R/gate-git.R` `gate_g()` 13-28;
  `R/recall.R` 74-81 (inline).
- What is wrong: `git_run()` and `changes_git()` are identical; `changes_git_z()` and
  `gate_g()` both run git into a temporary file and read raw bytes. They differ in small
  ways that matter: only the gate sets `GIT_OPTIONAL_LOCKS=0` and `core.quotepath=false`
  on every call, and `lint-doc.R` 1046-1060 borrows `changes_git()` from `changes.R`.
- Change: a `git.R` with `git_raw(dir, args)` (temporary file, status, raw output; the
  body of `gate_g()` without the abort) and `git_lines(dir, args)` built on it, both
  always passing `-c core.quotepath=false` and `GIT_OPTIONAL_LOCKS=0`. `git_show()`,
  `changes_git()`, `changes_git_z()` and `gate_g()` become thin callers; the gate keeps
  its own abort.
- Risk: moderate, because the gate is on the commit path. Guards: `test-changes.R`,
  `test-changes-findings.R`, `test-condition-log.R`, `test-gate-*.R`, `test-recall.R`.
- Size: M.

### 12. Files are written five different ways; two are not atomic
- Kind: duplication
- Where: `R/ledger.R` `write_whole_file()` 892-919 (temporary file and rename, skips
  equal bytes); `R/unit-names.R` 121-129 (temporary file and rename);
  `R/targets.R` `upstream_targets()` 1001-1004 (`saveRDS()` straight onto
  `.weft/targets/network.rds`); `R/dict-tools.R` `dict_vale()` 428-441 (compares bytes,
  then `writeBin()` straight onto the rule file); `use_dictionary()` 124-131 and
  `use_quarto()` 102 (`file.copy()`).
- What is wrong: `dict_vale()` re-implements the compare-then-write of
  `write_whole_file()` without its atomic rename or its error text. `network.rds` is
  written in place, and `tar_quarto()` reports rendered by parallel workers can write it
  at once; a torn file is caught by `readRDS()` and rebuilt, so the cost is a rebuild, but
  the safe pattern is already in the package twice.
- Change: move `write_whole_file()` to a shared file and use it in `dict_vale()`; add
  `save_rds_atomic(obj, path)` (temporary file in the same folder, `saveRDS`, rename,
  unlink on failure) and use it in `ud_tables()` and `upstream_targets()`.
- Risk: low. Guards: `test-dict-vale.R`, `test-ledger.R`, `test-tar-ledger-reads.R`,
  `test-perf.R`.
- Size: S.

### 13. `build_dict()` is 330 lines and parses the file three times
- Kind: structure
- Where: `R/dict.R` `build_dict()` 181-512; `avoid_raw()` 230-241 and `written()`
  245-257 inside it.
- What is wrong: one function checks the top level, every field of every entry, the
  `term`/`avoid` spellings across entries, unit registration and display conversion, and
  builds the result. `avoid_raw()` and `written()` each re-parse `prep$lines` with their
  own handlers and each re-implement "parse, dig out `weft: dict_local:` for a local
  file, check the length matches"; `avoid_raw()` skips the local case and `written()`
  handles it. With item 2 that is four readings of one file.
- Change: extract `dict_reparse(prep, scope, handlers)` used by both closures; extract
  `check_entry(e, key, line, scope, ...)` returning `list(value, row, decimals,
  installed, registered, problems)` (lines 262-465), and `check_spellings(rows, keys,
  key_line, canon, tprob)` (lines 468-490). `build_dict()` keeps the loop, the problem
  collection and the result. Do not try to merge the three parses into one: the
  handlers want different things, and a merged parse would be harder to read.
- Risk: moderate; the problem order and texts must not change. Guards: `test-dict.R`,
  `test-dict-terms.R`, `test-dict-display.R`, `test-dict-knit.R`,
  `test-unit-ladder-dict.R`, `test-review-2a.R`, `test-review-2c.R` and the `_dict`
  snapshots.
- Size: L.

### 14. `ledger.R` carries the sentence finder, heading anchors and general file reading
- Kind: structure
- Where: `R/ledger.R` 239-354 (`heading_anchors()`, `pandoc_id()`, `anchor_at()`,
  `in_front_matter()`), 511-786 (the sentence finder), 108-110 (`read_lines_utf8()`),
  215-237 (git), 790 (`strip_ext()`).
- What is wrong: half of the 1,048 lines are not about the ledger. The sentence finder is
  called from `resolve.R`, `heading_anchors()` from `lint-doc.R`, and
  `read_lines_utf8()` from `install.R` and four `use-*.R` files, all reaching into the
  ledger file for general tools.
- Change: move the headings and the sentence code, unchanged, to `R/sentence.R`;
  `read_lines_utf8()` to the reader of item 6; the git helpers to item 11's `git.R`.
  No logic changes. Before moving, grep that no name is defined in the target file.
- Risk: low (moves only). Guards: `test-ledger-sentence.R`, `test-ledger.R`,
  `test-ids.R`, `test-lint-xref.R`.
- Size: M.

### 15. Gather the two `units` internals in one guarded place
- Kind: structure
- Where: `R/unit-defaults.R` `ud_install_one()` 395-396 (`units:::R_ut_get_symbol`,
  `units:::R_ut_parse`); `R/unit-names.R` `ud_tables_key()` 140
  (`get("default_units_xml", envir = asNamespace("units"))`).
- What is wrong: nothing to remove (the workaround for r-quantities/units#448 stays
  until a release carries PR #447), but the two internal calls sit inside long functions,
  and the first is not guarded against the internals going away: its `tryCatch` turns a
  missing function into `""`, which silently disables the early refusal it exists for.
- Change: one small section, `ud_internal_symbol(def)` and `ud_units_xml_path()`, each
  using `get0(name, envir = asNamespace("units"), inherits = FALSE)`, with a comment
  naming #447/#448 and the condition for deleting it (a `units` release that carries the
  fix, then `packageVersion("units") >= ...` skips the early path). `ud_install_one()`
  calls the wrapper. A test that fails when the internals vanish makes the dependency
  visible.
- Risk: none. Guards: `test-unit-defaults.R`, `test-unit-defaults-config.R`,
  `test-perf.R`.
- Size: S.

### 16. Two indexes of the same units tables, read two ways
- Kind: duplication
- Where: `R/dict.R` `ud_shipped()` and `ud_cache` 648-667, used once at 679;
  `R/unit-names.R` `ud_db()`, `tok_resolve_db()` 152-244 with `un_cache`.
- What is wrong: both answer "does udunits ship this token". `ud_shipped()` splits
  names on spaces as well as commas and accepts a prefix name on a symbol, so it can say
  yes where `tok_resolve_db()` says no (found: `astronomical_unit_BIPM_2006`, which then
  fails to parse with a long repeated message). Two caches to keep in step.
- Change: replace the body with `isTRUE(tok_resolve_db(tok)$known)` and drop
  `ud_cache`; keep the `sub("[0-9]+$", "", t)` exponent case at the call site.
- Risk: the `registered` attribute could change for odd tokens. Guards: `test-dict.R`,
  `test-unit-names.R`, `test-trial-2i-units.R`.
- Size: S.

### 17. Dead code, needless aliases and stale comments
- Kind: dead code
- Where and what (each verified with grep across `R/`, `inst/`, `tests/`):
  - `R/unit-names.R` 275 `unit_key_parse()`: never called. Delete.
  - `R/unit-names.R` 278 `unit_proj()`: an alias of `unit_entry()` with seven callers in
    the same file. Call `unit_entry()`.
  - `R/changes.R` 737-740 `empty_ledger_x()` and `R/targets.R` 902 `as_obj()`: one-line
    wrappers of `ledger_df(list())` and `as.list()`.
  - `R/unit-defaults.R` 470-473: two comment blocks for one function; the first
    describes the old behaviour. Keep the second.
  - `R/config.R` 14-15: "set by the knit initialiser of a later package" is build
    history. Say what sets it (`hooks.R`).
  - `R/dict.R` 908-909: the paragraph on one-item lists sits between two bullets of the
    field list and splits it in the rendered help; move it after the list.
- Risk: none. Guards: the whole suite.
- Size: S.

## Left alone on purpose

- The `units:::` workaround itself (item 15 only isolates it).
- `ud_sync()` and `read_units_tables()`: long and stateful, but each branch is a case
  the tests pin, and `on.exit`/`back()` cleanup is correct. Splitting them now would
  risk more than it gains; revisit only if item 3 is done.
- `tar_dict_deps()` edits target objects in place (`t$deps`, `t$command$expr`,
  `t$settings$name`). That is reliance on targets internals, but there is no public way
  to add a dependency to a target someone else built (tarchetypes reports). A CI job on
  the targets development version would catch a break.
- `ledger_output_name()` walks the frames for `rmarkdown::render()`'s `output_file`:
  no public API exposes it, and `WEFT_OUTPUT` is the escape hatch.
- `upstream_targets()` keys its edge cache on the store's `meta/meta` and the script path,
  not the script's content. An edit to `_targets.R` without a run can reuse old edges, but
  a run changes `meta/meta`; low value.
- `reads_walker()` (340 lines) is one closure, but its parts share state on purpose and
  read in order. `dict_prepare()`'s key regular expression is intricate, but it is the
  only way to report duplicate fields and merge keys that YAML hides (item 8 covers its
  one silent failure).
- The front matter's `weft:` settings cannot be checked for one-item lists or YAML 1.1
  booleans: rmarkdown and Quarto parse it before weft sees it.
- No speed proposals, by instruction.

## Cross-area notes

- `R/hashes.R` (`dict_entry_hashes()`) belongs to no reviewer's area; its bug is item 2.
- `R/lint.R` `lint_config()` 217-245 duplicates `read_config_()`'s reading of
  `_weft.yml`; `R/decisions.R` 98 and `R/use-weft.R` 305 read it with default YAML too
  (item 1).
- `R/gate-git.R` `gate_g()` and `R/recall.R` 74-81 are the other git runners (item 11).
- `R/setup.R` `find_quarto_root()` versus `R/targets.R` `quarto_root()`: near-identical
  names, different results (item 5).
- Link checks are written four times: `R/setup.R` `is_link()` 124, a local `is_link()` in
  `use_dictionary()`, the loop in `dict_vale()` 377-384, `ledger_link_in()` in
  `R/ledger.R` 923-933. One `is_link()` would do.
- `write_lines_lf()` (used by `use.R`, `setup.R`, `install.R`, `use-weft.R`) is yet
  another writer next to item 12's.
- `R/hooks.R` `front_matter_lines()` feeds `read_dict_local()`; it should use item 6's
  reader so a non-UTF-8 front matter fails the same way.

## Rulings (orchestrator, 13 Nov, under delegation)

All seventeen proposals are accepted. Order and readings:

- Items 1 to 10 change behaviour and get failing tests first
  (`test-review-code-b.R`), written from the reproductions above.
- 1, 2: one YAML reader for every file weft reads as its own
  (`_weft.yml`, `dict.yml`, a document's `weft:` block, the shipped
  tables). Only `true` and `false` (any letter case) are booleans;
  `y`, `n`, `yes`, `no`, `on`, `off` are text. `!expr` is never
  evaluated, whatever the session's options and whatever the version
  of yaml (review c item 4); DESCRIPTION asks for the yaml version
  that makes this certain. A file that does not parse, is not UTF-8
  or holds a NUL byte is a classed error naming the file.
- 3: a dictionary read outside a knit reads its own project's
  configuration first, and its units belong to that project's root.
- 5, 11, 12: one finder of the project root (it knows `_quarto.yaml`),
  one git runner, one atomic file writer, shared with reviews a and c
  and built first by the foundations pass.
- 9: the frame walk fails softly and gets a test.
- 15: the two `units:::` calls move into one guarded function; the
  workaround itself stays until `units` releases the fix.
- Added after reading `tarchetypes` 0.14.0 (its hooks build a pilot
  target with `targets::tar_target_raw()` and copy `pilot$command` and
  `pilot$deps` onto the target): `tar_dict_deps()` and
  `unmark_command()` do the same, so the whole command object and the
  dependencies are rebuilt together, instead of writing
  `t$command$expr` and `t$deps` piecemeal. First check whether today's
  partial edit shows a fault (a target that does not re-run when its
  wrapped command or a dictionary entry changes) and pin it with a
  test if it does. No request to `targets` is needed: its own
  extension package edits targets this way.
- Revised on Robin's word ("can we just use the tarchetypes functions
  rather than copying them?"): do not copy the pilot code. Use the
  exported `tarchetypes::tar_hook_outer()` for the `dict_unmark()`
  wrap and `tarchetypes::tar_hook_before()` (a hook that names the
  `dict_<key>` targets read, `set_deps = TRUE`) for the dependencies,
  wherever they give what today's code gives; the `tar_dict` tests are
  the guard. Targets whose command is not one expression are filtered
  out first, as the hooks refuse them. For report targets
  (`tar_quarto()`, `tar_render()` and their `_rep` forms), whose
  dependencies are set from the report's source and not from the
  command's code, test whether a hook can add a dependency without
  losing the others; if not, keep one direct `t$deps` union there, in
  one small function with a comment saying why. Never call an
  unexported function of `tarchetypes`. `tarchetypes` stays in
  Suggests, with a clear error from `tar_dict_deps()` when it is
  missing.

## State after the first fixer (13 Nov)

Done: 3, 4, 7, 8, 9, 10; 1, 2, 5, 6, 11, 12 by the foundations pass.
All tests of `test-review-code-b.R` pass. Left for the structure
pass: 13 to 17.

`tar_dict_deps()` now attaches dependencies with the exported
`tarchetypes::tar_hook_before_raw()` (the dictionary targets, with
`set_deps = TRUE`) and `tarchetypes::tar_hook_outer_raw()`
(`weft::dict_unmark(.x)`, with `set_deps = FALSE`, so a target that
reads no key keeps its dependencies). The copies' command and
dependencies are put back on the caller's target, which is still
changed in place. Measured in a temp pipeline: a hook on a
`tar_render()` target keeps its source-file dependencies, so the
report-target exception was not needed. One direct union remains, for
a target whose command is more than one expression, which the hooks
refuse. `unmark_command()` is gone.

Kept, against the letter of 3: when a dictionary's project has no
readable `_weft.yml`, the session's units state is left alone. Three
existing tests need it; a project with no `_weft.yml` has no units
table to prefer.
