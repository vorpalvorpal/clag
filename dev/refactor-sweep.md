# Refactor sweep after stage 6

Read-only review of `main` at a8e7989 (14 Nov). Scope: `R/` (53 files, 28,000
lines), `inst/quarto` (Lua 4,600 lines, two R scripts), `inst/python`,
`inst/julia`, and the 41 `tests/testthat/helper-*.R` files (7,600 lines).
Nothing was changed. Numbers come from the measurements at the end; every
"still applies" was checked with `grep` or by reading the code at that commit.

## In short

The three changes that matter most:

1. **Every git, `verify()` render and `rehearse()` child fails on Windows**
   (proposal A1). Those three places pass `env =` to `system2()`, and on
   Windows R puts `NAME=value` in front of the command line. A Windows user
   could not commit through the gate.
2. **`lints()` spends a fifth of its time in `gregexpr()` on UTF-8 text**
   (proposals C1 and C2). R's `gregexpr(perl = TRUE)` grows with the square of
   the match count on non-ASCII text. One 320,000-character chapter with 58,686
   matches took 12.3 s, against 0.003 s for the same text in ASCII. A
   per-finding data-frame filter (`context_at()`) takes another 12%. Both are
   fixed in one helper each.
3. **The rules kept in two or more languages have no shared test**
   (proposals B1 and B2). This covers the condition grammar, the NAME rule,
   reserved words and "which documents the filter resolves". The sweep found
   two real divergences: R's scanner and Julia accept a name with a trailing
   newline, and the Lua upward searches stop one folder short of ruling 17.

What else this sweep found:

- A real bug, from reading JSON through YAML: a failure whose text holds a
  character outside the BMP is dropped from the report a stopped render prints
  (A2). Several "jsonlite is not an import" comments are now false.
- Engine detection is written six times, and "the first front-matter block"
  eight times (D1).
- Guest drains swallow parse faults, so Python warnings, Julia claims and
  `verify()`'s module list can vanish silently (E1).
- Most structural leftovers from reviews A, B, C and the test review still
  apply. The table is at the end.

Not worth doing, measured:

- The Lua filter adds at most 0.2 s to Pandoc on 900 to 1,800 constructs.
- A knit is quadratic only beyond about 300 paragraphs in one file (K1).

## Decisions for the owner

1. **How processes get their environment on Windows (A1).** The options are
   `withr::with_envvar()`, which moves `withr` from Suggests to Imports, or a
   10-line local helper. **Recommended: `withr`**, the maintained package's
   exported function.
2. **A Windows CI job (A1).** No CI runs on Windows today, and the owner uses
   it. Recommended: a `windows-latest` job with the fast subset, no real
   renders.
3. **Splitting `resolve_markup()` and `apply_formatters()` (leftover A19).**
   The ruling accepted a staged split. Recommended: do stage (1) only, hoisting
   the stateless closures, then stop and judge. The other stages carry high
   risk and buy readability only.
4. **`weft-check.lua` stays self-contained (L1).** It repeats five weftlib
   pieces. Projects set up before stage 6 have `weft-check.lua` without
   `weftlib/` (`FM_FILTER_ARGS_OLD`, `R/setup.R:41`), so it cannot load
   weftlib. Recommended: keep it standalone and guard it with B1's table.

## Work packages

Packages A to G touch disjoint files and can be built in parallel, in
worktrees, in the order given. H runs after them, one item at a time.

Verdicts:

- **DO NOW**: behaviour unchanged and already pinned by tests.
- **TEST FIRST**: behaviour changes, or is not pinned.
- **ASK**: a design or API choice.
- **LEAVE**: not worth doing.

### Package A: processes, JSON and the knit's file metadata

Files: `R/io.R`, `R/verify-render.R`, `R/rehearse.R`, `R/collect.R`,
`R/cite.R`, `R/hooks.R`, `R/ledger.R` (one function), and `DESCRIPTION` if
`withr` moves to Imports.

**A1. `system2(env =)` breaks git, `verify()` and `rehearse()` on Windows.**

- Where:
  - `R/io.R:103-104`: every git call, through `env = "GIT_OPTIONAL_LOCKS=0"`.
  - `R/verify-render.R:163-164`: `WEFT_RUN=` on the Quarto calls.
  - `R/rehearse.R:168-172`: five variables on the child `Rscript`.
- Problem: `?system2` says "On Windows, `env` is only supported for commands
  such as R and make which accept environment variables on their command
  line". Review 4 recorded this as untested and it was never fixed. With
  `git_raw()` as the one git runner since the foundations pass, the gate,
  `changes()`, `verify()` and `recall_check()` all go through it.
- Change:
  - Git: drop `env =` and pass git's own global option `--no-optional-locks`
    (git 2.15 or later) before `-C`.
  - Quarto and Rscript: set the variables in this process around the
    `system2()` call, with `withr::with_envvar()` (owner decision 1).
  - Add a static test that no `system2(` call in `R/` passes `env =`.
- Size: S. About 15 lines in 3 files, plus one test.
- Risk: low. On Unix the behaviour is the same. Nothing in the tests pins
  `GIT_OPTIONAL_LOCKS`. Guards: `test-gate-*`, `test-changes*`, `test-recall`,
  `test-verify-render`, `test-rehearse`.
- Verdict: **DO NOW** for git. **ASK** for the Quarto and Rscript route
  (decision 1), then DO NOW. **ASK** for a Windows CI job (decision 2).

**A2. JSON is read through YAML, and a character outside the BMP drops a failure.**

- Where:
  - `R/collect.R:118`: `collected_failures()` reads `failures.jsonl` with
    `yaml_read_text()`.
  - `R/cite.R:73-76`: a `.json` bibliography is read with YAML first. The
    `requireNamespace("jsonlite")` fallback guards a package that is now in
    Imports.
  - `R/cite.R:111` and `R/hooks.R:383-386`: `QUARTO_EXECUTE_INFO` is read
    with YAML. The comment at `hooks.R:384` says "jsonlite is not" an import.
  - `R/ledger.R:816` reads the same file with `jsonlite`.
- Problem: `json_string()` (`collect.R:5-23`) writes a non-BMP character as a
  surrogate pair, and libyaml refuses that pair. Reproduced:
  `yaml::yaml.load('{"a":"x\ud83d\ude00y"}')` gives "found invalid Unicode
  character escape code"; `jsonlite::fromJSON()` reads it.
  `collected_failures()` catches the error and returns `NULL`, so that
  failure is dropped from the report `claim_fail()` prints when a later
  chapter stops the render (`R/claim.R:249`).

  Review A's "left alone" note ("JSON is read back with yaml: jsonlite is not
  an import") stopped being true when stage 6 added jsonlite to Imports.
- Change:
  - Add one `json_read_text()` and `json_read_file()` to `io.R`
    (`jsonlite::fromJSON(simplifyVector = FALSE)`, a classed error naming the
    file).
  - Use them at the four sites. Drop the stale comment and the
    `requireNamespace` guard.
  - The writers stay as they are (see LEAVE).
- Size: S. About 20 lines in 4 files.
- Risk: low. YAML reads some invalid JSON that `jsonlite` refuses, so a
  `.json` bibliography that only YAML could read would now be "unreadable".
- Verdict: **TEST FIRST**. The test is a failure detail holding an emoji in
  an earlier chapter's collection line, read by `collected_failures()`. Guards:
  `test-collected`, `test-cite`, `test-lint-cite`, `test-phrases`.

**A3. The Quarto metadata lookup is written twice (review A item 13, second half).**

- Where: `R/hooks.R:378-400` (`document_lang()`) and `R/cite.R:108-123`
  (`quarto_metadata()`).
- Problem: both read `QUARTO_EXECUTE_INFO` and fall back to
  `quarto::quarto_inspect()`, which starts a process. A knit can do both.
- Change: build `document_lang()` on `quarto_metadata()`, keeping its
  `config$lang` fallback, and keep the result on the knit state.
- Size: S.
- Risk: low.
- Verdict: **DO NOW**, together with A2. Guards: `test-phrases`,
  `test-unit-names`, `test-cite`.

**A4. Two readers of the run id, with different rules (ruling 17 of stage 6 not met in R).**

- Where: `R/collect.R:156-163` (`run_id(root)`) and `R/values.R:203-220`
  (`values_run(dir)`).
- Problem: the two readers disagree on what they read and in which order:
  - `run_id()` reads `WEFT_RUN` first, then `<root>/.weft/run` only. It is
    used for the stamp and the collection file.
  - `values_run()` walks up from the document's folder through 8 parents,
    and reads `.weft/run` before `WEFT_RUN`. This is what ruling 17 asks of
    every reader.

  They differ when `WEFT_RUN` is set and a stale `.weft/run` is present, so
  the stamp's run and the block's run can disagree.
- Change: make `run_id <- function(root) values_run(root) %||% ""`. This
  touches `collect.R` only.
- Size: S, 5 lines.
- Risk: low; it is an edge case.
- Verdict: **TEST FIRST**. The test sets `WEFT_RUN` with a different
  `.weft/run` present. Guards: `test-stamp-names`, `test-verify-freeze`,
  `test-filter-stamp`.

**A5. The `rmarkdown::render()` frame walk is written twice.**

- Where: `R/collect.R:53-66` (`original_input`) and `R/ledger.R:801-809`
  (`output_file`).
- Problem: two copies of the frame loop. There is still no public route:
  rmarkdown issue #2648 asks for one.
- Change: one `render_frame_value(name)` that returns the value or `NULL`;
  both sites call it.
- Size: S.
- Risk: none. Guards: `test-ledger`, `test-review-2d`.
- Verdict: **DO NOW**.

**A6. `verify_uses_julia()` is a third julia-engine detector, and a broader one.**

- Where: `R/verify-render.R:279-290`.
- Problem: it says yes to any `{julia}` chunk, including a knitr document that
  runs Julia through JuliaCall. `doc_is_julia()` (`R/use.R:183-197`) says yes
  only when no R or Python chunk is present. A knitr document with a Julia
  chunk therefore makes `verify()` run `quarto call engine julia kill`. That
  is harmless but needless, and the note it prints is wrong. The function
  also reads with `readLines()`, not `read_source_lines()`.
- Change: `verify_uses_julia <- function(root, rel)
  doc_is_julia(read_source_lines(file.path(root, rel)))`.
- Size: S.
- Risk: low.
- Verdict: **TEST FIRST**. The test is a knitr `.qmd` with a `{julia}` chunk:
  no kill, no note. Guards: `test-julia-render`, `test-verify-render`.

### Package B: one guard for the rules written in several languages

Files: new `tests/testthat/_conformance/grammar.tsv`, new
`tests/testthat/test-conformance-grammar.R`, `R/scan.R` (`is_weft_name()`
only), `R/values.R` (`values_name_ok()` only),
`inst/julia/Weft/src/Weft.jl:113-114`, `inst/quarto/weft.lua`,
`inst/quarto/weftlib/config.lua`, `inst/quarto/weft-check.lua`.

**B1. A shared table for the condition grammar and the NAME rule.**

- Where: the condition grammar is kept in three places:
  - `inst/quarto/weftlib/cond.lua:99-129` (`parse_part`), with its message
    texts in `weft.lua:1368-1376`;
  - `R/scan.R:945-963` (`COND_RE`, `cond_part_error()`);
  - `inst/quarto/weft-pre-render.R:120-147` (`is_name`, `cond_ok`, inside
    `local()`).

  The NAME rule and its reserved words are kept seven times:
  - `R/scan.R:12,913-916` and `R/values.R:21-29`, written separately;
  - `inst/quarto/weftlib/cond.lua:19-29` and `inst/quarto/weft-check.lua:124-130`;
  - `inst/python/weft/_backend.py:31-52` and `inst/julia/Weft/src/Weft.jl:109-114`;
  - the pre-render script.

  The case lists that exist each run against one implementation:
  `E3_BAD`/`E4_BAD` in `test-lint-named.R:142,169` and `PP_BAD` in
  `test-parity-static.R:31`.
- Problem: there is no test that the copies agree, and two already disagree:
  - **A name with a trailing newline.** PCRE's `$` matches before a final
    newline. `R/scan.R:914`, the pre-render script and `Weft.jl:114` use `$`,
    so they accept `"x\n"`. `values.R:27` uses `\z` and Python uses `\Z`, so
    they refuse it. Checked: `grepl("^[A-Za-z_][A-Za-z0-9_.]{0,63}$", "x\n",
    perl = TRUE)` is TRUE in R, and Julia's `occursin(...)` is true. Julia's
    `put("x\n" => 1)` publishes a name the filter can never match.
  - **Lua trims newlines inside an operand.** It trims `[ \t\r\n]` inside an
    operand (`cond.lua:63`), where R's `COND_RE` allows only `[ \t]` around
    the operator. So `if="x\n< 3"` parses in Lua and is E3 in R.
- Change:
  - Add `_conformance/grammar.tsv`, with columns `kind` (`cond`, `name`),
    `text` (escaped `%0A`, `%20`, as `f6_unesc()` reads them), `verdict`
    (`ok`, `E3`, `E4`) and `message`. Seed it from `E3_BAD`, `E4_BAD`,
    `PP_BAD`, the reserved words, the 64-character limit and the cases above.
  - Run it in `test-conformance-grammar.R` against each implementation:
    - R: `filter_governor_errors("if", .)`, `is_weft_name()` and
      `values_name_ok()`.
    - Lua: `cond.parse` and `cond.is_name`, in one `pandoc lua` process
      through `lua_run()`. Compare the message texts too, once the E3/E4
      texts move from `weft.lua` into `cond.lua` as `cond.message(err)`.
    - The pre-render script: one `Rscript` run on a temporary project with
      one `.qmd` per `cond` row. The script lists every failing file, so one
      process covers all rows, ok against not-ok.
    - Python and Julia `is_name`, when available, as the guest tests skip
      today.
  - Fix what the table finds:
    - In R, `is_weft_name(x)` becomes `length(x) == 1L &&
      isTRUE(values_name_ok(x))`, and one reserved list goes.
    - In Julia, use `\z`.
    - In Lua, trim only `[ \t]` around the operator, or take the newline into
      R's rule. That is a choice; pick R's, which is the spec's ("spaces").
- Size: M. A 60-row table, about 120 lines of test, about 15 lines of code in
  4 files.
- Risk: low. The table is new. The two fixes refuse input that no real
  document holds.
- Verdict: **TEST FIRST**. The table is the test.

**B2. Which documents the filter resolves: two copies, neither tested against the other.**

- Where: `R/scan-contexts.R:755-783` (`filter_resolves()`) and
  `inst/quarto/weft.lua:2255-2297` (`source_is_knitr()`, a local function).
- Problem: R's scanner and the Lua filter must give the same answer, or a
  construct is claimed by both or by neither. Today they agree line by line,
  but nothing checks it.
- Change: move `source_is_knitr()` into `weftlib/config.lua` as
  `M.source_is_knitr`, and add `kind = doc` rows to the B1 table (front
  matter and chunk-header lines, and the owner). Run both sides in the same
  processes as B1.
- Size: S.
- Risk: low; it is a move. Guards: `test-filter-direct`, `test-scan-named`.
- Verdict: **DO NOW** for the move, **TEST FIRST** for the rows.

**B3. The Lua upward searches stop one folder short of ruling 17.**

- Where: `weft.lua:367-383` (`dir_up_find`, 9 folders), `weft-check.lua:277-289`
  (8) and `weftlib/config.lua:364-375` (8).
- Problem: ruling 17 says "the document's folder and 8 parents" for the run.
  `weft-check.lua`'s collection-file check reads `.weft/run` through its
  8-folder search, so at the ninth folder `weft.lua` and `weft-check.lua` see
  different runs. R's `find_project_root()` has no limit.
- Change: 9 in both places, with one row in the B1 table of a project at
  depth 8.
- Size: S, 2 lines.
- Risk: none.
- Verdict: **TEST FIRST** (the row).

### Package C: `lints()` speed and its error paths

Files: `R/lint-source.R`, `R/lint-code.R`, `R/lint-doc.R`, `R/lint.R`,
`R/lint-named.R`.

**C1. `gmatch()` on a whole UTF-8 document is quadratic in the match count.**

- Where:
  - `R/lint-source.R:52-58` (`gmatch()`), called 12 times per document by
    `mask_prose()` (`lint-source.R:550-697`);
  - `R/scan.R:41,51,57` (`new_scan()`), left to package H because B
    touches `scan.R`.
- Problem: measured on 4 documents of 3,000 lines (tiers 1 and 2, 54.7 s
  profiled). `gregexpr` has 12.0 s of self time (22%), of which `gmatch <
  mask_prose` is 7.8 s and `new_scan` 1.0 s.

  The cause is R itself. With `perl = TRUE` on a non-ASCII UTF-8 string, R
  converts each match's byte offset to a character offset from the start of
  the string. One 320,000-character file:

  | pattern      | matches | UTF-8   | same text in ASCII | `useBytes = TRUE` |
  |--------------|--------:|--------:|-------------------:|------------------:|
  | `[A-Za-z]+`  |  58,686 | 12.34 s |            0.003 s |           0.004 s |
  | a span block |   2,852 |  0.61 s |            0.001 s |           0.000 s |

  Every real manuscript has non-ASCII characters.
- Change: in `gmatch()`, when `nchar(x, "bytes") > nchar(x)`, match with
  `useBytes = TRUE` and map the byte offsets to character offsets through
  one cumulative map per text. The map is built once from `utf8ToInt()` and
  kept on the source as `text_cutter()` is. This is valid for a pattern
  whose meaning does not depend on character units: ASCII literals, negated
  ASCII classes, `[[:punct:]]` and `\s` (which are ASCII-only without UCP
  anyway). It is not valid for `.` under a count, `\p{..}`, or a class that
  holds non-ASCII characters. Audit the 12 patterns, and leave any of those
  kinds on the old path.
- Size: S to M. About 30 lines in `lint-source.R`, plus the audit.
- Risk: medium. The offsets must be exact.
- Verdict: **TEST FIRST**. An equivalence test runs the old and new
  `gmatch()` on every pattern of `mask_prose()`, over the syntax fixtures and
  a generated non-ASCII document, and expects identical `s`, `e` and `cs`.
  `test-lint-scale.R` then shows the gain. Expected: about 9 s of 55 s on
  this input.

**C2. `context_at()` filters the whole region table for every finding.**

- Where: `R/lint-code.R:579-585`, called at `:634` and `:738`.
- Problem: measured 6.7 s total (12%). `[.data.frame < context_at` has 322
  samples, plus 184 samples of `%in%` inside it. It is O(findings x regions)
  per document.
- Change: keep the rows of the three types it asks about once per source, in
  `src$cache`, and test only those.
- Size: S, 5 lines.
- Risk: none.
- Verdict: **DO NOW**. Guards: `test-lint-values`, `test-lint-claims`,
  `test-lint-scale`.

**C3. Project-scope rules report an R fault as "could not be read".**

- Where:
  - `R/lint-doc.R:288`, `:765` and `:828`: `tryCatch(ctx$source(f), error =
    function(e) NULL)`.
  - `R/lint.R:332`: `doc_front()`.
  - `R/lint-named.R:79,89`.
- Problem: `read_source()` already turns an unreadable file into `invalid =
  TRUE` (`lint-source.R:918-922`). What these handlers catch is something
  else:
  - `weft_config_error` from a bad `weft:` block, which gets the wrong note;
  - any bug in the reader, which becomes a note about the file.

  Review C ruled the same pattern out of `changes_tier2()`.
- Change: catch `weft_config_error` (and `weft_yaml_error` where YAML is read)
  with a note that says so, and let anything else raise. `doc_front()` drops
  its outer `tryCatch`, because `read_source_text_or_null()` already handles
  encoding.
- Size: S, about 12 lines.
- Risk: a hidden fault may surface, which is the point.
- Verdict: **TEST FIRST**. The test is a document whose `weft:` block is
  invalid, seen by a project rule: the note names the setting. Guards:
  `test-lint-xref`, `test-lint-config`.

**C4. `code_pieces()` classifies an error by its message text.**

- Where: `R/lint-code.R:292`: `two_literals = grepl("compares two literals",
  rows$error[i], fixed = TRUE)`.
- Problem: rewording E4 in `scan.R:958` would silently double-report.
- Change: decide from the value with `COND_RE` (`scan.R:946`, read and not
  changed): every part a comparison whose operands are both literals.
- Size: S.
- Risk: none.
- Verdict: **DO NOW**. Guard: `test-lint-named` ("N143").

**C5. Review C item 17, rest, as these files are open.**

- Remove `dl_empty()` (`lint-doc.R:32`), `isFALSE_vec()` (`:718`) and
  `lc_find()` (`lint-code.R:317`).
- Remove the unused `cfg_file` argument of `source_pieces()`
  (`lint-source.R:290`) and the unread `numeric_ok`/`notes` returns
  (`:489`).
- Remove `parse_col_chars()` (`scan-contexts.R:435`, the identity), which
  also has a caller at `lint-source.R:259`. The other caller is in
  `scan-contexts.R` (package D), so do it there in step.
- **DO NOW**.

### Package D: one reading of a document's front block and engine

Files: `R/use.R`, `R/use-weft.R`, `R/scan-contexts.R`.

**D1. Engine and front-block detection are written over and over.**

- Where:
  - "The first metadata block's lines" is cut out by hand in eight places:
    `R/hooks.R:337-344`, `R/use-weft.R:434-439`, `R/ledger.R:232-235`,
    `R/verify-render.R:282-286`, `R/use.R:155-158` and `:185-188`,
    `R/scan-contexts.R:758-760`, and the pre-render script. The patterns
    differ: `^---[ \t]*$`, `^---\\s*$` and `^---[ \t\r]*$`.
  - "Which engine runs this `.qmd`" is decided in six places:
    `doc_is_jupyter()` and `doc_is_julia()` (`R/use.R:151-197`, 45 lines,
    near copies), `verify_uses_julia()` (A6), `dl_knitr_doc()`
    (`R/lint-doc.R:925-933`), `qmd_needs_engine()` (`R/setup.R:312-323`) and
    `filter_resolves()`.
- Problem: they answer two questions, and the line-reading is copied each
  time:
  1. which engine Quarto picks;
  2. whether weft's hooks knit the document.

  The two `use.R` functions already differ in letter case: `{Python}` is not
  a Python chunk to one, while `{Julia}` is a Julia chunk to the other.
- Change:
  - Add `front_block(lines)` (the lines between the first `---` and its
    close, or `character()`) beside `metadata_blocks()` in
    `scan-contexts.R`.
  - Add `quarto_engine(lines)`, which returns `"knitr"`, `"jupyter"`,
    `"julia"` or `"markdown"` by Quarto's rule. `doc_is_jupyter()` and
    `doc_is_julia()` become one-line wrappers, so callers are unchanged.
  - `use_doc_front()` and `filter_resolves()` use `front_block()`. Packages
    A and H switch `hooks.R`, `ledger.R` and `verify-render.R` to it when
    they next touch those files.
  - `dl_knitr_doc()` works on the parsed source and stays.
  - The pre-render script stays separate (plain base R).
- Size: M. About 60 lines removed across 3 files.
- Risk: low. The case difference is the only behaviour change.
- Verdict: **DO NOW**, with one test for `{Python}`. Guards:
  `test-use-quarto-julia`, `test-use-quarto-jupyter`, `test-status`,
  `test-use-setup-guest`, `test-scan-named`.

### Package E: guest drains

Files: `R/guest.R`, `R/guest-julia.R`.

**E1. Six drains swallow both a failed call and a malformed reply.**

- Where:
  - `R/guest.R:216-220` (Python warnings) and `:240-245` (project modules);
  - `R/guest-julia.R:102-111` (claims), `:114-125` (puts), `:235-241` (log
    records) and `:247-256` (included files).
- Problem: each drain does
  `tryCatch(call, error = NULL)` and then
  `tryCatch(guest_json(txt), error = function(e) list())`. A JSON fault in
  weft's own Python or Julia emitter makes warned claims, published names or
  `verify()`'s G30 module list vanish with no word.
- Change: one `guest_drain_json(call)`:
  - keep "the guest is not running" as an empty result, as `julia_running()`
    and `guest_running()` already guard;
  - make a reply that does not parse a `weft_guest_error` naming the drain,
    recorded as a knit failure.
- Size: S. About 30 lines become about 15.
- Risk: low.
- Verdict: **TEST FIRST**. The test mocks `guest_json` input with
  `local_mocked_bindings()`. Guards: `test-guest-conditions`,
  `test-julia-conditions`, `test-jl-put`, `test-verify-named`.

### Package F: test helpers

Files: `tests/testthat/helper-*.R`, and the test files that call the helpers
renamed or deleted.

The test review's items 3, 9, 10, 11, 12 and 15 all still apply (see
Leftovers). Stage 6 added more of the same.

**F1. Stage 6 render and filter helpers are copies.**

- Where:
  - `qm_render()` (`helper-jupyter.R:222-242`) and `jle_render()`
    (`helper-julia-engine.R:167-186`) share 15 identical lines.
  - `qm_read()` and `jle_read()` are identical.
  - `py_lib_6e()` (`helper-jupyter.R:48`) and `py_lib6k()` (`helper-6k.R:48`)
    are identical.
  - The record builders are written twice: `fr_*` (`helper-filter.R:108-115`)
    and `rec_*` (`helper-lua.R:190-192`).
  - `weft_filter_path()` stops when the file is missing; `filter_path()`
    falls back silently.
  - `%||%` is defined again at `helper-julia-engine.R:234` and
    `test-pre-render-named.R:26`.
- Change: fold these into the `helper-0-common.R` of test-review item 11,
  using one-line aliases at first.
- Verdict: **DO NOW**.

**F2. Dead helpers.**

- Where: the test review's list still holds: `cl_read_targets`, `d2_df`,
  `e1_make_store`, `expect_has`, `h2_knit`, `h4_edit_line`, `h4_lines`,
  `i2_msgs`, `lf_rules`. Add `block_texts_of` (`helper-jupyter.R:179`) and
  `jle_line_of` (`helper-julia-engine.R:226`). Each occurs only at its
  definition.
- Verdict: **DO NOW**.

**F3. Calls to internals grew from 334 to 540 `weft:::` calls.**

- Change: the test review's item 13 wrappers (`t_read_config()` and
  `t_scan()`) are still worth doing.
- Verdict: **DO NOW**, with F1.

### Package G: dead code and one way to warn

Files: `R/units.R`, `R/unit-names.R`, `R/changes.R`, `R/targets.R`,
`R/recall.R`, `R/decisions.R`, `R/arms.R`, `R/verify.R`, `R/config.R`,
`R/claim.R`, `R/unit-defaults.R`, `R/dict.R`, and one line of `R/resolve.R`.

**G1. Warnings carry `weft_warning` only some of the time.**

- Where:
  - `weft_abort()` (`R/config.R:8-10`) always adds `weft_error`.
  - Warnings carry `weft_warning` at `ledger.R:17`, `resolve.R:390`,
    `verify.R:245` and `guest.R:356`.
  - They do not at `claim.R:272` (`weft_claim_warning`), `claim.R:296` and
    `resolve.R:377` (`weft_zero_warning`), `config.R:229`
    (`weft_config_warning`) and `unit-defaults.R:818` (`weft_unit_warning`).
- Problem: a caller cannot catch every weft warning by one class. The house
  rule is clear for errors (86 calls through `weft_abort()`, no `cli` or base
  `stop()` for user errors). Warnings have no helper.
- Change: add `weft_warn(msg, class)` beside `weft_abort()` and use it at the
  nine sites.
- Size: S.
- Risk: none; it only adds a class.
- Verdict: **DO NOW**.

**G2. Dead code, verified with `grep` over `R/`, `inst/` and `tests/`.**

- `unit_text()` (`R/units.R:128-131`) is new since the reviews and has no
  callers.
- Still present from review B item 17: `unit_key_parse()`
  (`unit-names.R:275`), the `unit_proj()` alias (`:286`, 4 callers),
  `empty_ledger_x()` (`changes.R:701`) and `as_obj()` (`targets.R:962`).
- Still present from review A item 17: `if (is.null(r)) NULL else r`
  (`arms.R:15`) and `resolved[num & is.na(resolved) | num & !resolved]`
  (`decisions.R:127`).
- Still present from review C item 17: `recall_normalise(with_map)` and
  `order_docs` (`recall.R:7`, `:112`), and the overwritten `keep`
  (`verify.R:361`).
- Change: delete all of these.
- Verdict: **DO NOW**.

**G3. Gather the `units` internals (review B item 15).**

- Where: `units:::R_ut_get_symbol` and `units:::R_ut_parse`
  (`unit-defaults.R:410`), and `default_units_xml` through `asNamespace`
  (`unit-names.R:148`).
- Problem: the first still turns a missing internal into `""`, which silently
  turns off the early refusal it exists for.
- Change: as review B proposed: `get0()` wrappers in one section, with a
  comment naming units #447/#448, and a test that fails when the internals
  vanish.
- Verdict: **DO NOW**.

**G4. `ud_shipped()` against `tok_resolve_db()` (review B item 16).**

- Where: `dict.R:660-680`.
- Verdict: **TEST FIRST**, as review B proposed.

### Package H: structural leftovers, in sequence after A to G

These are the accepted, unbuilt items, each still valid. One at a time,
whole suite after each. Order:

1. A11, A12, A15 and A16: `scan.R`, `format.R`, `resolve.R`.
2. A13 (first half) and A14: `resolve.R`, `phrases.R`, `arms.R`, `claim.R`.
3. C1 rest, `new_scan()`'s `gregexpr`: `scan.R:41-57`, the same way as C1.
4. C6 and C7: the `icode` vector and `project_meta_files()`.
5. C13 and C19: `lint_run()`, one findings shape: `lint.R`, `gate.R`.
6. C3: one added-lines reader: `gate-git.R`, `verify.R`, `lint-doc.R`.
7. C14: `use_setup()` on `plan_item()`: `setup.R`, `install.R`, `use-weft.R`.
8. B14: move the sentence finder and anchors out of `ledger.R`, after A.
9. A18: one fence finder.
10. B13: split `build_dict()`.
11. A19, stage 1 only (owner decision 3).

Path relativising (review C item 18) is now written 14 times, for example
`lint.R:455-495`, `verify.R:76`, `verify-render.R:184`, `decisions.R:266`,
`gate.R:111`, `position.R:25`, `install.R:46-49` and `lint-source.R:104-108`.
Several of these compute `substring(x, nchar(root) + 2L)`, which drops a
character when the root is `/` or `C:/`. Fold them into one `rel_to(path,
root)` file by file as H touches them.

### LEAVE

- **Lua filter speed.** Measured: 900 constructs and 300 values in 0.52 s,
  against 0.51 s for Pandoc alone. At 1,800 constructs the filter adds
  0.1 to 0.2 s. Not a bottleneck.
- **K1: knit superlinearity.** At 600 paragraphs (1,200 constructs) the knit
  takes 5.7 s; at 1,200 paragraphs it takes 16.8 s, 2.9 times as long. The
  quadratic parts are:
  - `join_pieces()` (`resolve.R:83-121`), whose `acc <- paste0(acc, ...)`
    and whole-`acc` `grepl()`s take 2.0 s (14%);
  - `range_items()` (`resolve.R:539-552`), which scans every span per
    construct: 1.3 s (9%);
  - `substr()` on the whole block in `render_plain()`: 0.5 s.

  At 100 to 300 paragraphs they are under 10%, and a realistic chapter knits
  in about 1 s. Revisit only if a long book is knitted as one file. The fix
  is S: accumulate pieces in a vector, test only the tail, and sort the spans
  once with `findInterval()`.
- **`pd_tree()` per inline expression** (`lint-code.R:61-80`): 7.1 s (13%) of
  the lint profile, of which 1.9 s is `getwd()` inside `srcfilecopy()`.
  Batching the parses changes how a parse error is isolated, which is a real
  redesign for about 10%. Revisit after C1 and C2, if `lints()` is still too
  slow on a real project.
- **The JSON writers**: R has `json_string()`, `json_str()` and
  `values_str()`; Lua has four `json_str` copies. Each writes a byte format
  that is pinned by ledgers, stamps, records and a plain-base-R reader.
  `jsonlite::toJSON()` would change the bytes. In Lua, `stamp.lua:16-39` and
  `report.lua:61-84` are identical; merging them needs a module loader for
  weftlib siblings, more plumbing than 25 lines are worth.
- **L1: `weft-check.lua`'s copies** of `is_name`, the draft read, the
  collection-file check, `json_str` and `find_upward`. They are deliberate
  (decision 4); B1 and B3 guard them.
- **Record classification in R, Python and Julia** (`values.R`, `_record.py`,
  `record.jl`). Each follows its own language's types, so the duplication is
  inherent. A shared "wire" table (float text, exact ints, string escapes) run
  in all three would catch the stage-6 #13 kind of drift. Add it to B1's
  table later if a fourth language comes; not now.
- **The other frame walks**: `knit_nested()` (`hooks.R:465-471`),
  `script_frame()` (`targets.R:406-416`) and `dict_base_caller()`
  (`dict.R:821-825`). There is no public route, and review B already ruled on
  them. Every use of another package's internals: `units:::` x2 and
  `asNamespace("units")` (G3); the `rmarkdown::render()` frame x2 (A5);
  `knitr::knit` frames; `targets` `tar_callr_inner_try`. All other `:::` and
  `asNamespace()` uses are weft's own namespace.
- **`mask_text()`** (`scan.R:1583`) is called only by `test-scan.R`, while
  the lints mask with `mask_prose()`. It is rule 2.10.5's reference; keep it
  as a test seam. The same holds for `jl_record()` and
  `values_source_names()`.
- **`message()` for installer output, and module prefixes** (`dl_`, `lc_`,
  `g_`): consistent enough; renaming is churn.
- **`project_type()`** re-reads `_quarto.yml` once per document
  (`scan-contexts.R:138-155`). It does not appear in either profile.

## Leftovers from the earlier reviews

| Item | State at a8e7989 | Where it goes |
|---|---|---|
| A11 class and key checks twice | Applies: texts differ, `scan.R:771,792` and `format.R:668,673` | H1 |
| A12 stage filter, `TEXT_CLASSES` literal | Applies: `resolve.R:514,972` | H1 |
| A13 English test, metadata lookup | Applies: `check_english`, `non_english`, two copies of the plural-rules message | A3, H2 |
| A14 claim lines drifted | Applies: `claim_warn()` still lacks the `all()` advice | H2 |
| A15 `.range` and unit affix twice | Applies: `format.R:934-960` | H1 |
| A16 two arm tokenisers | Applies: `scan.R:469`, `:561` | H1 |
| A17 small dead code | Applies, all six | C5, G2 |
| A18 five fence finders | Applies: `find_fences`, `fence_blocks`, `metadata_blocks`, `find_chunks`, `front_matter_lines` | D1 (front block), H9 |
| A19 split the two long functions | Applies: 1,044 and 559 lines | H11 (decision 3) |
| B13 `build_dict()` | Applies: 337 lines | H10 |
| B14 `ledger.R` scope | Applies | H8 |
| B15 units internals | Applies, unguarded | G3 |
| B16 two units indexes | Applies | G4 |
| B17 dead code | Applies | G2 |
| C3 one added-lines reader | Applies: three parsers | H6 |
| C6 indented code three ways | Bug fixed; the copies remain (`lint-code.R:212`) | H4 |
| C7 metadata files four ways | Bug fixed (both spellings); the walk is still written three times | H4 |
| C13 `lints()` split, one gate call | Applies: `gate.R:282-283` calls `lints()` twice | H5 |
| C14 `use_setup()` write loop | Applies: `setup.R:174` `check_place()` | H7 |
| C17 dead code, rest | Applies | C5, G2 |
| C19 two findings shapes | Applies | H5 |
| T3 git under the user's config | Applies: `e2x_project()` and the others have no `git_env()` | F |
| T4 gate-edits one repository | Applies | F, after A1 |
| T5 renders in process by default | Applies: `in_process = FALSE` is still the default | F |
| T6 batch Quarto renders | Applies; stage 6 added two more render helpers (F1) | F |
| T9 helper shims into globalenv | Applies: helper-1b, 2d, 2g, 2h, 2i | F |
| T10 session state left behind | Applies | F |
| T11 eight helper families | Applies, plus F1 | F |
| T12 inline git skips | Applies: 156 | F |
| T13 internals from tests | Applies; grew to 540 | F3 |
| T14 gaps | Mostly applies: `dict_unmark()` is still tested in one file only | F |
| T15 dead helpers | Applies, plus two | F2 |
| T16 repeated renders | Applies | F, with T5 |
| T17 feature map | Applies | F |

## Measurements

Setup:

- weft at a8e7989 was installed into a temporary library with `R CMD INSTALL
  --no-docs --no-test-load`. The working tree had documentation-only edits.
- One R process at a time. `R_USER_CACHE_DIR` pointed at a fresh temporary
  folder.
- Scratch files lived in `mktemp -d` folders under `/tmp`.

**M1: `lints()`.**

- Input: 4 documents of 3,000 lines each, made by `scale_doc()` from
  `test-lint-scale.R`. That is non-ASCII prose with 3 constructs per
  paragraph, about 4,300 constructs per document.
- Times:

  | run                  | time   | findings |
  |----------------------|-------:|---------:|
  | tier 1, cold         | 34.1 s |    6,212 |
  | tier 1, warm         | 34.9 s |          |
  | tiers 1 and 2, under `Rprof` at 10 ms | 62.2 s | 11,920 |

- Top self time, of 54.7 s profiled: `gregexpr` 12.0 s, `%in%` 4.1 s,
  `[.data.frame` 3.9 s, `paste` 2.6 s, `getwd` 1.9 s.
- By caller:

  | caller                                 | time   |
  |----------------------------------------|-------:|
  | `gmatch < mask_prose`                  | 7.8 s  |
  | `context_at` (total)                   | 6.7 s  |
  | `pd_tree` from `code_pieces` (total)   | 7.1 s  |
  | `count` in `lint_long_guard`           | 1.8 s  |
  | `new_scan`                             | 1.0 s  |
  | `getwd < srcfilecopy < parse`          | 1.9 s  |

  The cause of `count`'s time is not established: it runs on short strings
  and is probably per-call overhead.

**M1b: `gregexpr` alone.**

- Input: one of the 3,000-line documents, 319,969 characters, read as UTF-8,
  then the same text transliterated to ASCII.
- Results: see the table in C1. The other three patterns tested
  (`\{[ \t]*[#.][^{}\n]*\}` with 1,498 matches, an HTML comment, and an
  escaped punctuation mark) gave 0.31 s, 0.000 s and 0.000 s on UTF-8.

**M2: a knit.**

- Input: `scale_doc()` from `test-knit-scale.R` with one non-ASCII word, 2
  constructs per paragraph, through `knitr::knit()`. Each process first
  warmed up on a 20-paragraph knit (3.0 s, then 2.2 s).
- Times:

  | paragraphs | time    |
  |-----------:|--------:|
  |        100 |  1.26 s |
  |        300 |  2.42 s |
  |        600 |  5.73 s |
  |      1,200 | 16.8 s  |

- Under `Rprof` at 5 ms, at 1,200 paragraphs (13.9 s profiled):

  | caller                                | time   | share |
  |---------------------------------------|-------:|------:|
  | `paste0 < join_pieces`                | 2.0 s  |   14% |
  | `range_items` (total)                 | 1.3 s  |    9% |
  | `ledger_sentence_at` (total)          | 2.1 s  |   15% |
  | `substr < render_plain`               | 0.5 s  |       |
  | knitr's own `parse_inline`            | 0.3 s  |       |
  | `getwd < srcfilecopy` in `split_args` | 0.3 s  |       |

- At 600 paragraphs, `join_pieces` was 10% and `range_items` 4.5%.

**M3: the filter.**

- Input: Quarto's Pandoc 3.10 binary, run directly, writing HTML with
  `WEFT_DRAFT=1`. One `weft-values` block of 300 values (100 float, 100 int,
  100 bool) and 3 constructs per paragraph: a named `.num` value, an `n=`
  span and an `if=` span.
- Times, two runs each:

  | input                                | Pandoc alone | with `weft.lua` and `weft-check.lua` |
  |--------------------------------------|-------------:|-------------------------------------:|
  | 300 paragraphs, 900 constructs, 56 KB |       0.51 s |                               0.52 s |
  | 600 paragraphs, 1,800 constructs     | 0.80 / 1.00 s |                        1.02 / 1.13 s |

- The output was checked to hold resolved values ("4 sites", "4.3 m").

All synthetic inputs above were invented, and no project data was read.
