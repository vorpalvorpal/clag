# Package 2e — the pipeline and `changes()`

Written before any test or code. It fills in the outline of 2e in
`dev/design-2.md` §4 and builds on the contract of 2d (`dev/design-2d.md`, D1
to D30), not on its code, which is being written as this note is. Robin
delegated the choices on 12 November 2026; each is in the decision table with
its alternatives. Every example value below is invented.

2e is split in two, built one after the other:

- **2e-1, the pipeline**: `tar_dict()`, `tar_dict_deps()`, the scan of a
  rendered report (4.6.5), what a chapter reads and its hashes in the ledger
  header (7.2.2), and the conditions `tar_meta()` holds (7.4.1, fourth
  source). Needs `targets`; no git.
- **2e-2, `changes()`**: the comparison with a commit (7.3), the third state
  (7.2.1), and the internal state check `verify()` will use (7.2.3). Needs
  git; `targets` only to check a store. Its tests run on hand-written ledger
  files, so it can be built and tested before 2e-1 is finished, but it reads
  the header fields 2e-1 defines.

## What was measured

`targets` 1.12.0, `tarchetypes` 0.14.0, R 4.4.3, knitr 1.51, Quarto 1.11.9,
git 2.50.1, cli 3.6.6. All in temporary folders; scripts not kept.

1. **A global `dict` leaks through functions.** In `_targets.R`, a global
   object `dict` is an edge into every target whose command names it and into
   every function that names it (`tar_network()`: `dict → f`, `dict → t_cmd`).
   Changing only an attribute of `dict` (its definitions) re-ran the target
   `f()`, even when that target was built with `tar_target_raw(deps = c("f",
   "dict_a"))`: outdatedness passes through the function `f`.
2. **The spike behind §18's row did not measure what it claims.** In targets
   1.12.0 a target object is an environment whose automatic dependencies are in
   `t$deps`; `t$command` has `expr`, `hash`, `library`, `packages`, `string`
   and no `deps`. `dev/spikes/spike-tardict` wrote `t$deps <-
   union(t$command$deps, <dict keys>)`, so it started from `NULL` and dropped
   every automatic dependency. Re-running its design B: `tar_network()` has no
   edge `era_label → t_fn_era`, so an edit to the function itself would re-run
   nothing. Its result "a changed definition re-runs no consumer" came from
   dropping `dict` along with everything else.
3. **`tar_target_raw(deps = )`** replaces the automatic dependencies; a name
   that is not in the pipeline is ignored without a message.
4. **An object on the search path is not tracked.** With the dictionary
   attached as `dict` in an environment `weft:dict` (not in `envir`) and
   `dict_<key>` appended to `t$deps`: a changed value re-ran exactly its
   readers, through a command, through a function and in a `map()` pattern;
   a changed definition and a new key re-ran no reader; a changed function
   body re-ran its target; the values read were the new ones. The same holds
   for a `tar_quarto()` target with appended dependencies (re-rendered on a
   value change, not on a definition change).
5. **Dictionary values hash stably.** `serialize()` of `read_dict()` values
   (HEAD's 2a, via `pkgload::load_all()` of a `git archive` copy) gave the same
   bytes in two R processes, and after changing two definitions and the file's
   path; `labels` and `breaks` closures included.
6. **`tar_meta()`**: `warnings` is one string per target, several warnings
   joined by `". "`, a newline inside a warning turned into a space; messages
   are not stored. A branch has `type` `branch` and `parent` the pattern's
   name. `tar_meta(names = "absent")` is an error (a `vctrs` subscript error),
   so a reader takes every row and filters. One call took 6 ms.
7. **`tar_network(targets_only = TRUE, outdated = FALSE)`** took 1.06 s in its
   default `callr` process the first time, 0.46 s the next, 0.04 s in
   process. Inside the knit of a `tar_quarto()` target, during `tar_make()`,
   it took 1.34 s and worked; `tar_meta()` was readable there; the working
   folder was the pipeline's root and `tar_config_get("store")` was
   `_targets`.
8. **What `tarchetypes` scans.** `tar_knitr_deps()` finds `tar_read()` and
   `tar_load()` (with `c()`) in chunk code, inline R, inline R in front
   matter, inside a function defined in a chunk, and with `store = `; it skips
   a chunk with `eval: false`; it ignores `tar_read_raw("x")` with a warning.
   `tar_quarto_files()` runs `quarto inspect` (0.58 s) and lists an included
   file among the sources. A `tar_quarto()` target's command is
   `tarchetypes::tar_quarto_run(args = list(...), deps = list(<targets>),
   sources = c("_part.qmd", "report.qmd"), output = ..., input = ...)`.
9. **knitr's `label` option hook** (weft installs one, `R/hooks.R`) sees
   `options$code` and `options$eval` for every chunk: cached ones on a cached
   re-run, and a child's chunks; the chunk that calls a child has `code`
   `NULL` and the `child` option.
10. **git from a project in a subfolder of a repository**: `git -C <root>
    ls-tree -r --name-only <rev> -- _weft/ledger` lists paths relative to the
    root; `git -C <root> show <rev>:./<path>` exits 128 for a path not in
    `<rev>`; `git rev-parse --verify -q <rev>^{commit}` exits 1 for a bad
    revision and for `HEAD` before the first commit.
11. `cli::hash_raw_xxhash64()` gives 16 lower-case hex characters
    (`78af5f94892f3950` for the bytes of `abc`), the same form as `targets`'
    `data` hashes, and does not treat a carriage return specially.

## Scope

| Rules | Package | What |
|---|---|---|
| 4.6.1–4.6.4, 4.6.6 | 2e-1 | `tar_dict()`, `tar_dict_deps()`, the walker, unknown keys |
| 4.6.5 | 2e-1 | the source files of a `tar_quarto()` or `tar_render()` target scanned the same way |
| 7.2.2 | 2e-1 | what a chapter reads (targets, dictionary entries, its own files) with their hashes, in the ledger header |
| 7.4.1 (fourth source), 7.4.2 | 2e-1 | warnings and errors from `tar_meta()` for the targets read and upstream; the severity list applied to them |
| 7.2.1, 7.2.3 (the check only) | 2e-2 | the third state, from the header against the store, the dictionary and the files now |
| 7.3.1–7.3.7, 7.4.4 (in `changes()`) | 2e-2 | `changes()`: comparison, structural changes, ranking, added and removed, new conditions, ledgers renamed, new, deleted or without a source |

**Left out.** `verify()`'s report and failure on entries not re-rendered
(7.2.3, stage 4; 2e-2 supplies the check). Tier-2 findings (7.3.5): the
object has an empty table for them; stage 3 fills it. Parallel workers and
functions in a package namespace (Q5): designed for, not run (P8). Whether the
store itself is out of date (`tar_outdated()`): it needs the pipeline script
run, and `changes()` runs nothing (T31). `tar_quarto_rep()` and
`tar_render_rep()`: not recognised (P6).

## 2e-1 — the pipeline

### Exports and dependencies

- **P1.** New exports `tar_dict()` and `tar_dict_deps()`. `targets (>=
  1.12.0)` joins Suggests; `tarchetypes` joins Suggests for the tests only
  (weft calls none of its functions). Both exports first call an internal
  `need_targets()`, which calls `rlang::check_installed("targets", reason =
  "to define a pipeline")`; tests mock it.

### `tar_dict(path = "dict.yml")` (4.6.1)

- **P2.** `path`: one string naming an existing file, else
  `weft_pipeline_error`. The dictionary is read with `read_dict(path)`; its
  `weft_dict_error` is raised as it is, so a bad dictionary stops the
  pipeline's definition.
- **P3.** P5's check runs. Then the dictionary is attached to the search path
  as the object `dict` in an environment named `weft:dict`, at position 2; an
  environment of that name already attached is detached first. This is how
  commands and functions in the pipeline find `dict` (T2).
- **P4.** Returns a plain list of target objects:
  1. `dict_file`: `targets::tar_target_raw("dict_file", <path as given>,
     format = "file")`.
  2. For each key, in file order, `dict_<key>`: `tar_target_raw("dict_<key>",
     quote(weft::read_dict(dict_file)[["<key>"]]))`. No other option is set,
     so `tar_option_set()` governs them.

  An empty dictionary returns `dict_file` alone. A changed definition, a new
  key or a reordered file re-runs `dict_file` and every `dict_<key>`, whose
  values hash as before, so no reader re-runs (4.6.3; measured 4, 5).

### `tar_dict_deps(targets, path = "dict.yml")` (4.6.2–4.6.6)

- **P5. A global `dict` is refused.** When `exists("dict", envir =
  targets::tar_option_get("envir"), inherits = FALSE)`, both functions raise
  `weft_pipeline_error`: `` `dict` is an object in the pipeline's
  environment, so targets tracks it and every target that reads it re-runs
  when any entry changes, its definition included. Remove `dict <- ...` from
  _targets.R: tar_dict() provides `dict` (rule 4.6.3).``
- **P6. Arguments.** `targets`: a target object, or a list of target objects
  and lists, nested to any depth; anything else is `weft_pipeline_error`.
  `path` as P2; the keys are `names(read_dict(path))`.
- **P7. What it does.** For each target, the keys it reads are found by the
  walker (P9) over its command, and for a report target over its sources
  (P10). They are appended to its dependencies: `t$deps <- union(t$deps,
  paste0("dict_", sort(keys)))`. A target that reads no key is left alone, and
  so is a target whose name is `dict_file` or `dict_<key>`. Returns `targets`
  in the same structure; the objects are changed in place (they are
  environments).
- **P8. Unknown keys (4.6.4).** Every key named but not held, over every
  target, is collected; then one `weft_pipeline_error`: `weft: <path>: N
  unknown key(s) read by the pipeline`, one line each: `` `<target>` reads
  `dict$<key>`, which <path> does not hold (rule 4.6.4).``, plus `` Did you
  mean `<k>`?`` under 2a's rule (one key within edit distance 2). For a report
  target the line also names the file: `` `report` (report.qmd) reads ...``.
- **P8a. Workers (Q5).** A `crew` worker does not have `weft:dict`, so a
  function that reads `dict` fails there with "object 'dict' not found". Not
  run, not handled; documented in the help of `tar_dict()`. The way to handle
  it later is in T2.

### The walker

- **P9.** Internal `code_reads(code, envir, keys)`. `code` is a call, an
  expression vector, or a character vector of R code (parsed with
  `keep.source = FALSE`; code that does not parse is skipped). Returns a list:
  `keys` (character, sorted, unique), `all` (logical), `unknown` (character),
  `targets` (data frame `name`, `store`; `store` `NA` when not given).
  - `dict$k`, `dict$"k"`, `dict[["k"]]` and `dict[['k']]` name key `k`.
  - `dict[[<anything but one string>]]`, `dict[...]`, and the symbol `dict`
    anywhere else (an argument, `names(dict)`, `with(dict, ...)`) set `all`;
    then `keys` is every key (4.6.6).
  - A named key not in `keys` goes to `unknown`, `all` or not.
  - A symbol that names a closure in `envir` (`inherits = FALSE`), as a call
    or as an argument, is followed once: its formals and body are walked.
    `pkg::f`, `pkg:::f`, functions on the search path and primitives are not
    followed.
  - Everything is walked: formulas, `function()` literals, the insides of
    `quote()`. A local variable named `dict` is taken for the dictionary.
    `dict_local` is not read.
  - **Targets read** (used at knit time, P12): `tar_read(x)`, `tar_load(x)`,
    `tar_load(c(x, y))`, the same with `targets::`, and `tar_read_raw("x")`,
    `tar_load_raw("x")`, `tar_load_raw(c("x", "y"))` with literal strings. A
    `store = "<literal>"` argument is kept. Names that are not literal
    (variables, `starts_with()`) are not recorded.

### Report targets (4.6.5)

- **P10.** A target whose command is one call to
  `tarchetypes::tar_quarto_run` (from `tar_quarto()`) or
  `tarchetypes::tar_render_run` (from `tar_render()`) is a report target. Its
  files are the literal `sources` argument of the first, or the `path`
  argument of the second, relative to the working folder. Each file is read
  (UTF-8) and every piece of R code in it is walked with P9 (functions
  followed in the pipeline's `envir`): the code of every chunk whose `eval` is
  not written as false (`eval=FALSE`, `#| eval: false`), inline R in prose and
  front matter, and the R code of every construct (a value's code, the keys
  `n`, `if`, `sign`, `list`), as the stage-1 scanner and `dict_seed()`'s chunk
  reader find them. A file that does not exist is a `weft_pipeline_error`.
  Other commands, `tar_quarto_rep()` and `tar_render_rep()` among them, are
  walked as commands.
- **P11. Pinned internals.** A test asserts that a target object has `deps`
  (character), `command$expr` (an expression) and `settings$name`, and that a
  `tar_quarto()` target's command has a `sources` argument; it fails loudly
  when `targets` or `tarchetypes` changes them (T3).

### What a chapter reads (7.2.2)

Computed in a top-level knit of a set-up project, not in a rehearsal, at the
start of the `document` hook, before the failure report is decided (2d's
D20), because P15's failures must be in it.

- **P12. Code walked.** The code of every chunk the `label` option hook sees
  (children's and cached chunks included) whose `eval` is not
  `identical(FALSE)`, and the `expr` of every 2d entry. Walked with P9, keys
  from the project dictionary (none when there is no `dict.yml`), functions
  followed in `knitr::knit_global()` as it is at that moment. Unknown keys are
  ignored here.
- **P13. The three header fields.** 2e sets 2d's `s$ledger_header` (D27) to
  `list(dict = , files = , targets = )`, always all three, each a JSON object
  (`{}` when empty), names sorted byte by byte:
  - `dict`: key → hash (P14) for each key read (every key when `all`).
  - `files`: path → hash for the source, every distinct `file` of the entries,
    and every `child` path the `label` hook saw; paths relative to the root,
    with `/`.
  - `targets`: store → (name → hash). A read's store is its literal `store`
    (relative to the knit's working folder), else
    `targets::tar_config_get("store")` there, else `_targets` when `targets`
    is not installed; written relative to the root, with `/`. The hash is the
    `data` field of the row of that name in `tar_meta(store = )` (a pattern's
    own row); `null` when `targets` is not installed, the store does not exist
    or the row is absent.

  2d's writer is extended to write a nested object (strings and nulls,
  names sorted). Example:

  ```
  {"weft":"ledger","version":1,"source":"reports/survey.qmd","output":"survey","dict":{"limit":"3f2a9c0d1e4b5a68"},"files":{"reports/survey.qmd":"9b1c2d3e4f5a6b7c"},"targets":{"_targets":{"fit":"51cfc97e3e0d005e","obs":"a38168847350f2a6"}}}
  ```

- **P14. Hashes.** All are `cli::hash_raw_xxhash64()` of bytes, 16 hex
  characters. A file: its bytes with every CR LF made LF (a file that cannot
  be read: `null`). A dictionary entry: the UTF-8 bytes of the canonical JSON
  of the entry's YAML mapping as 2a's handlers read it, without `definition`,
  `decision`, `why`, `term` and `avoid`, written by `jsonlite::toJSON(x,
  auto_unbox = TRUE, digits = NA)` with names in file order. Internal
  `file_hash(path)` and `dict_entry_hashes(path)` (a named character vector),
  for 2e-2 and the tests.

### Conditions from `tar_meta()` (7.4.1, 7.4.2)

- **P15. Lines.** When the chapter reads at least one target and the store
  exists: the set is the targets read and every target upstream of them
  (P16). Each row of `tar_meta(store = , fields = c("type", "data",
  "warnings", "error", "parent"))` whose name, or whose `parent`, is in the
  set gives a condition for each of `warnings` (class `warning`) and `error`
  (class `error`) that is not `NA`: `from` `target`; `source` the target's
  name, or for a branch its pattern's name; `text` the field as `targets`
  stored it. Each is first matched against the severity list (stage 1's
  patterns and the configured ones): a match is a failure of kind
  `condition`, detail `target <name>: <class>: <first line of text>`, hint
  as stage 1's, and is not a log line (D17). The rest are appended to
  `s$condition_rows` (D27); 2d normalises, merges, carries text forward and
  sorts. They are not added to `last_knit()$conditions`.
- **P16. Upstream.** `targets::tar_network(targets_only = TRUE, outdated =
  FALSE, script = , store = )` in its default `callr` process; `script` is
  `tar_config_get("script")` in the knit's working folder. Upstream is every
  ancestor along the edges. The edges are kept in `.weft/targets/network.rds`
  with the run id (the first line of `.weft/run`, written by the
  `pre-render` script) and the script's path, and reused while both match
  and the run id is not empty: once per Quarto project render. When it fails
  (no script, the script errors) the knit raises one `weft_ledger_warning`:
  `weft: the targets upstream of fit, obs were not read (<message>); the
  condition log holds the conditions of the targets the document reads
  (rule 7.4.1).` and carries on with the targets read.

### Where it does not run

- **P17.** Nothing of P12–P16 runs in a rehearsal, in a child knit (its reads
  go to the parent through P12), or when the project is not set up; then the
  header has no 2e fields. `targets` not installed: the reads are recorded
  with `null` hashes and no condition is read, without a message.
- **P18.** `last_knit()` gains `reads`: `list(dict =, files =, targets =)`
  as in the header (named character vectors; `targets` a named list of them),
  `NULL` when P12 did not run.

### Renames and the other edge cases

- A renamed source writes a new ledger folder; the old one is left (2d G21)
  and 2e-2 pairs them (C5).
- A key renamed in `dict.yml` but not in the pipeline is P8's error at
  definition.
- A store deleted after a render: the header keeps the hashes; 2e-2 reports
  the state as unknown (C9).

## 2e-2 — `changes()` and the third state

### The call

- **C1.** `changes(since = "HEAD", path = ".", files = NULL)`, exported, with
  `print.weft_changes()`. Returns a `weft_changes` object visibly.
  - `path`: a folder inside the project; the root is found as 1a finds it. A
    root without `_weft.yml` is a `weft_changes_error`: `` changes() reads
    the ledgers of a set-up project; <root> has no _weft.yml (rule 9.3.2).``
  - `since`: one string. git must be on the path (internal `git_path()`,
    mockable) and the root inside a work tree, else `weft_changes_error`
    (`changes() needs git: ...`, `... is not inside a git work tree`).
    `since` is resolved with `git rev-parse --verify -q <since>^{commit}`;
    failure is `` `since`: <since> is not a commit (rule 7.3.1).`` — except
    `since = "HEAD"` in a repository with no commit, which compares with
    nothing: every ledger is new, `commit` is `NA`.
  - `files`: `NULL`, or source paths relative to the root; only their ledgers
    are compared. A path with a ledger on neither side is a
    `weft_changes_error`.
- **C2.** It renders nothing, runs no pipeline, writes nothing and calls git
  only to read (`rev-parse`, `ls-tree`, `show`) (7.3.6).

### Which files

- **C3. The two sides.** Now: every `*.jsonl` under `<root>/_weft/ledger/`
  (the working tree). Then: `git -C <root> ls-tree -r --name-only <commit> --
  _weft/ledger`, each read by `git -C <root> show <commit>:./<path>`. A ledger
  is `<dir>/<output>.jsonl`; its condition log is `<dir>/<output>.conditions.jsonl`
  beside it. The pair is matched by path.
- **C4. Reading.** `read_ledger()` and `read_condition_log()` (D27), strict.
  On `weft_ledger_error` the file is read leniently; its status is
  `unreadable` and its note the error's message (a merge conflict: render it
  again, 7.1.5). A version above 1 reads as no entries, status `unreadable`.
- **C5. Renamed sources.** A ledger present only then (A) and one present
  only now (B), with the same output name, are paired when at least half of
  A's entries match an entry of B on (`section`, `kind`, `expr`, `occ`), or
  on `id` for entries with one, `file` ignored; the B with the largest share
  wins, and a tie pairs nothing. In a pair, A's entries whose `file` is A's
  source take B's source before keying. Status `renamed`, `from` A's source.
- **C6. Statuses.** `compared`, `new` (only now), `deleted` (only then),
  `renamed`, `unreadable`; plus the note `source gone` when the ledger exists
  now and its source does not (2d G21).

### Entries

- **C7. Key and change.** Keys as D13: an entry with an id by (`id`, its
  occurrence among entries with that id); else (`file`, `section`, `kind`,
  `expr`, `occ`). **Changed** when `text` or `arm` differ, `null` and `""`
  differing (D14, 7.1.7). A different `raw` alone is not a change. A key only
  now is **added**, only then **removed** (7.1.8: a changed expression is one
  of each).
- **C8. Structural reasons** of a changed entry (7.3.4), in this order, `b`
  the raw value then and `a` now, each one finite number or skipped:
  1. `arm`: the kind is `n`, `if`, `sign` or `list` and `arm` differs; shown
     `arm one -> other` (`none` for `null`).
  2. `sign flip`: `b` and `a` non-zero with opposite signs.
  3. `crosses 0`: exactly one of `b`, `a` is zero.
  4. `crosses 1.0`: `sign(b - 1) != sign(a - 1)`.
  5. `crosses dict$k`: for each key `k` of type `number`, `quantity` or `year`
     in the `dict` field of this entry or of any entry with the same `file`,
     `section` and `sentence`, on either side: with `tb` its value in
     `dict.yml` then (`git show <commit>:./dict.yml`, read with
     `read_dict()`) and `ta` its value now, `sign(b - tb) != sign(a - ta)`. A
     quantity is compared by its number in its own unit. A side whose
     `dict.yml` is absent or has problems gives no threshold.
  6. `order of magnitude`: `b` and `a` non-zero and `abs(log10(abs(a /
     b))) >= 1`.
- **C9. Claim words and rank.** A claim word is one of the list below, matched
  as a whole word, ignoring case, in `sentence_before` or `sentence_after`
  after the entry's own `text` is removed once from that sentence (so a value
  printed as "three" is not its own claim word). The list is internal
  (`claim_words()`), to be replaced by stage 3's (5.5.1):

  > one two three four five six seven eight nine ten eleven twelve twenty
  > hundred thousand million billion half twice double doubled triple
  > tripled halved quarter; all every each none no nothing only most
  > majority minority few fewer several many both neither either any; largest
  > smallest highest lowest greatest least maximum minimum peak record first
  > last best worst; rose rise rises risen rising fell fall falls fallen
  > falling increase increased increases increasing decrease decreased
  > decreases decreasing declined grew dropped higher lower more less greater
  > smaller larger above below exceeded exceeds steady stable unchanged

  Changed entries are ranked: those with a structural reason first, ordered by
  the first reason's place in C8, then by `rel`; then the rest, those with a
  claim word first, then by `rel` descending (`NA` last); ties by ledger path
  then key. `rel` is `abs(a - b) / abs(b)` (`Inf` when `b` is 0, `NA` when
  either raw is null).
- **C10. Conditions.** A line of the condition log now whose (`from`,
  `source`, `class`, `normalised`) is not in the log then is new (7.4.4). A
  `deleted` ledger contributes none; a `new` one, all of its lines.

### The third state (7.2.1)

- **C11.** Internal `ledger_state(root, header)` returns `list(stale =
  <logical>, reasons = <character>, notes = <character>)`. Reasons, in this
  order:
  - `` target `<name>` changed `` (the `data` hash in `tar_meta(store = )` now
    differs from the header's, `null` included), `` target `<name>` is not in
    the store ``;
  - `dict$<key> changed`, `` dict$<key> is gone ``, `dict.yml is gone`;
  - `<path> changed`, `<path> is gone` (P14's file hash).

  `stale` is `TRUE` when there is any reason. Notes, which do not make it
  stale: `targets is not installed; the pipeline was not checked`, `the store
  <store> does not exist; the pipeline was not checked`, `dict.yml has
  problems; the dictionary was not checked`. A header without 2e's fields
  (written before 2e) is not stale and has no note. A chapter served from
  Quarto's freeze keeps its old ledger, so its header shows what changed
  since; the stamp of 2.9.2 is not read (T8).
- **C12.** Every entry of a stale ledger, listed or not, is not re-rendered;
  listed entries carry `stale = TRUE`. `verify()` (stage 4) will call
  `ledger_state()`.

### The object

- **C13.** A `weft_changes` is a list with class `"weft_changes"`:

| Element | Columns or content |
|---|---|
| `entries` | one row per changed, added or removed entry, in the printed order: `ledger` (source path), `output`, `file`, `section`, `kind`, `expr`, `occ`, `id`, `change` (`changed`, `added`, `removed`), `structural` (reasons joined by `", "`, `""` when none), `claim_word` (the first found, `NA`), `rank` (integer, changed rows only), `stale`, `text_before`, `text_after`, `arm_before`, `arm_after`, `raw_before`, `raw_after`, `sentence_before`, `sentence_after` (`NA` for a side that has no entry) |
| `conditions` | new conditions: `ledger`, `output`, `from`, `source`, `class`, `text` |
| `stale` | one row per reason: `ledger`, `output`, `entries` (count), `reason` |
| `ledgers` | one row per ledger on either side: `ledger`, `output`, `path`, `status`, `from`, `note` |
| `findings` | tier-2 findings: `file`, `line`, `rule`, `message`; zero rows until stage 3 |

  Attributes `since` (as given), `commit` (full hash, or `NA`), `root`.

### The printed layout

- **C14.** Plain text by `cat()`, no colour. Line 1, when there is anything:
  `weft changes since <since> (<7-character commit>): <n> ledgers compared; <c>
  changed, <a> added, <r> removed; <k> new condition(s)`. When there is
  nothing (no entry rows, conditions, stale reasons or ledgers other than
  `compared`): `weft: no changes since <since> (<commit>); <n> ledgers
  compared.` "ledger" and "condition" are singular for 1. With no commit:
  `(no commit yet)` in place of the hash. Then
  these sections, each only when it has rows, in this order, each entry
  under its marker:

```
weft changes since HEAD (3f9c2a1): 2 ledgers compared; 3 changed, 1 added, 1 removed; 1 new condition

Not re-rendered
  reports/survey.qmd: 9 entries; target `fit` changed; dict$limit changed

Structural changes
  ~ reports/survey.qmd#quality  if  ratio < dict$limit  [arm true -> none] (not re-rendered)
      before: The mean ratio was 0.98, below the limit.
      after:  The mean ratio was 1.04.
  ~ reports/survey.qmd#quality  value  ratio {#ratio}  [crosses 1.0, crosses dict$limit] (not re-rendered)
      before: The mean ratio was 0.98, below the limit.
      after:  The mean ratio was 1.04.

Other changes, ranked
  ~ reports/water.qmd (site-a)  bare  n_sites  [claim word "all"]
      before: All 14 sites were visited.
      after:  All 15 sites were visited.

Added
  + reports/water.qmd#flow (site-a)  value  max(flow)
      Peak flow was 12 ML/d.

Removed
  - reports/water.qmd#flow (site-a)  value  median(flow)
      The median was 2.9 ML/d.

New conditions
  ! reports/survey.qmd  target fit  warning: Model failed to converge with max|grad| = 0.0021.

Ledgers
  reports/flow.qmd (flow): new, 12 entries
  reports/sites-2023.qmd (sites-2023): source gone; delete _weft/ledger/reports/sites-2023.qmd/
  reports/water.qmd (site-a): renamed from reports/rivers.qmd
```

  - The location is `<file>`, plus `#<section>` when the section is not `""`,
    plus ` (<output>)` when the output differs from the ledger source's base
    name without extension. Then two spaces, the kind, two spaces, `expr`,
    ` {#id}` when there is one, the reasons in brackets, ` (not
    re-rendered)` when stale.
  - A changed entry whose `text` is `null` prints `after:  (failed: <failed>)`.
  - A ledger that is `new` or `deleted` is listed under "Ledgers" with its
    count of entries; its entries are in `$entries` but not printed one by
    one. A `deleted` ledger prints `deleted, <n> entries`; `unreadable` prints
    its note.
  - Sentences print as stored (U+00A0 as itself).
  - Under "Ledgers" each line is `<ledger> (<output>): <status>`, for every
    ledger whose status is not `compared` or that has a note.

## Errors, warnings and messages

All errors carry `weft_error`. Messages end with the rule.

| Class | Kind | When |
|---|---|---|
| `weft_pipeline_error` | error | `path` not a file (P2); a global `dict` (P5); `targets` not targets (P6); unknown keys (P8); a report source missing (P10) |
| `weft_dict_error` | error | the dictionary has problems, from `read_dict()` (P2) |
| `weft_ledger_warning` | warning | the upstream targets could not be read (P16) |
| `weft_changes_error` | error | not set up, no git, not a work tree, `since` not a commit, `files` naming no ledger (C1) |
| `rlang_error` | error | `targets` not installed (P1) |

## Touches

2e-1: new `R/targets.R` (`tar_dict()`, `tar_dict_deps()`, `code_reads()`,
the report scan, the reads, hashes, target conditions). `R/ledger.R`: the
header writer takes nested objects; `s$ledger_header`, `s$condition_rows`
filled before the failure report. `R/hooks.R`: the `label` hook keeps each
chunk's code, `eval` and `child`; the `document` hook calls 2e first.
`R/state.R`: `last_knit()$reads`. `R/conditions.R`: the severity match as a
function both sources call. `DESCRIPTION`: Suggests `targets (>= 1.12.0)`,
`tarchetypes`. 2e-2: new `R/changes.R`. Nothing a document shows changes.

## Decisions

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| T1 | one package or two | one 2e; 2e-1 pipeline and 2e-2 `changes()` | two | different machinery (`targets` against git); 2e-2 is testable on hand-written ledgers; each half reviewable | merge the notes |
| T2 | where `dict` lives in a pipeline | a global, as the spec's example; a global holding values only; an attached environment `weft:dict`; each command wrapped to bind `dict` from its `dict_<key>` values | attached by `tar_dict()` | measured 1, 4: a global is tracked and leaks through functions (values only would still re-run every function reader on any value); attached, exact. Cost: `crew` workers do not see it (P8a) | wrap commands as `weft::tar_dict_eval(dict_k, <command>)`, which attaches in the worker |
| T3 | adding dependencies to a target | `t$deps` (internal); rebuild with `tar_target_raw(deps = )` from `t$settings` (internal too); rewrite unevaluated `tar_target()` calls (public, literal calls only) | append to `t$deps`, pinned by a test | one field; works for every target type, `tarchetypes` ones included; the rewrite misses `tar_quarto()`, `tar_map()` and lists held in variables | `tar_dict_deps()` |
| T4 | the per-key command | `weft::read_dict(dict_file)[["k"]]`; a new exported reader; the raw YAML value | `read_dict()[["k"]]` | no new export; `tar_read(dict_k)` gives the value prose sees; the value's hash ignores definitions and path (measured 5) | one `substitute()` |
| T5 | unknown keys | the first; all | all, one error | as `read_dict()` (D5 of design-2) | stop at the first |
| T6 | 4.6.5 | a wrapper `tar_dict_quarto()`; recognise report targets in `tar_dict_deps()`; document only | recognise `tar_quarto()` and `tar_render()` | one call covers the whole list; a forgotten wrapper fails silently. Cost: reads `tarchetypes`' command layout, pinned | drop P10, add a wrapper |
| T7 | what the header records | targets read; plus upstream; plus dictionary entries and source files | targets read, dictionary entries, files | a chapter can print only what the targets it reads hold, so their hashes suffice; entries and files cover a chapter not re-rendered after its source or `dict.yml` changed (7.2.1 "something it depends on") | drop fields (additive) |
| T8 | served from freeze | the stamp of 2.9.2; the hashes | hashes | stamps are in `.weft/` and not committed, so another machine or CI cannot see them; a frozen chapter keeps its old header, so a change shows | read stamps in C11 |
| T9 | hash | `tools::md5sum()`; `rlang::hash()`; `cli` xxhash64 | `cli::hash_raw_xxhash64()` on bytes, CR LF made LF | `rlang::hash()` is promised only within one R version; xxhash64 is `targets`' own form; `cli` is in Imports; CR LF so a Windows checkout agrees | `file_hash()` |
| T10 | an entry's hash | serialised value; canonical JSON of the entry without documentation fields | JSON | committed: must agree across R versions; a definition, a decision, `term` and `avoid` print nothing in prose | `dict_entry_hashes()` |
| T11 | finding reads at knit time | scan the source file; record calls as they run; walk the code knitr ran | walk the `label` hook's code and the entries' expressions | children and cached chunks included; same answer cached or not; no hook on `targets` | P12 |
| T12 | stores | one; per read | per read, nested under the store | `store = "../_targets"` is common in subfolders | flatten |
| T13 | upstream for conditions | none; `tar_network()` every knit; cached per project render | cached per run id | 7.4.1 asks for upstream; measured 0.5–1.3 s per call; a book pays once | read targets only |
| T14 | several warnings of one target | split on `". "`; one line | one line | `". "` also occurs inside a warning; carry-forward keeps the line stable | split |
| T15 | a branch's condition | branch name; pattern name | pattern | branch names carry hashes that change | P15 |
| T16 | severity list on target conditions | no; yes | yes | §15 relies on a fit's warning reaching it from a target | P15 |
| T17 | target conditions outside a set-up project | read; not | not | the log exists only when set up; saves the `callr` call | P17 |
| T18 | `changes()` without git | the files on disk; an error | error | the working tree is the "after"; there is no "before" without history | C1 |
| T19 | no commit yet | error; compare with nothing | compare with nothing for `HEAD` | a new project's first `changes()` should work | C1 |
| T20 | a renamed source | removed and added; git's rename detection; pairing by content | pairing by content | git sees a rename only once staged; pairing works on the working tree | C5 |
| T21 | a whole ledger new or deleted | every entry printed; a count | a count, rows kept in `$entries` | a new chapter would bury the real changes | C14 |
| T22 | print grouping | per chapter; global sections | global sections | 7.3.4: structural changes first, across the book | C14 |
| T23 | order of magnitude | floor of `log10` differs; a factor of 10 | factor of 10 | 9.9 to 10.1 is not a change of magnitude | C8 |
| T24 | dictionary thresholds | keys in the entry's expression; plus those of its sentence; every numeric key | expression and sentence, each side's `dict.yml` | the threshold is often printed or tested beside the value (an `if` on `dict$limit`); a moved threshold counts. Cost: a quantity in another unit can cross falsely; a heuristic for ranking only | C8 |
| T25 | "next to a claim word" | within N words; the same sentence | same sentence, own text removed | 5.5.1's unit; the ledger stores the sentence | C9 |
| T26 | the lexicon before stage 3 | wait; an internal list | internal list, replaced by stage 3's | 7.3.4 needs it now | `claim_words()` |
| T27 | rank of the rest | key order; claim word then size of change | claim word, then relative change | a big change beside "all" is read first | C9 |
| T28 | the return value | a data frame; a classed list | a list of tables | entries, conditions, state and ledgers have different shapes | C13 |
| T29 | tier-2 findings | omit; empty table | empty table with its columns | stage 3 fills it without changing the shape | C13 |
| T30 | store absent or `targets` missing | stale; unknown | unknown, with a note | a fresh clone has no store; calling every chapter stale would be noise | C11 |
| T31 | a store behind its code | `tar_outdated()`; not checked | not checked | it runs the pipeline script (seconds, side effects); 7.3.6 runs nothing | add a reason from `tar_outdated()` |
| T32 | ledgers whose source is gone | delete; list | list with the folder to delete | `changes()` writes nothing (7.3.6) | — |

## For Robin

Built as chosen until answered.

- **E1 — `dict` in a pipeline comes from `tar_dict()`, not a global (T2).**
  The spec's `dict <- weft::read_dict("dict.yml")` in `_targets.R` makes every
  reader re-run on any dictionary edit (measured), so it becomes an error.
  Cost: parallel `crew` workers cannot see `dict` until commands are wrapped.
- **E2 — The ledger header records the chapter's source files and dictionary
  entries as well as its targets (T7).** So any edit to a chapter changes its
  ledger's first line at the next render, and two branches that both edit a
  chapter conflict on that line (resolved by rendering, 7.1.5). Alternative:
  targets only, and an edited but unrendered chapter is not flagged.
- **E3 — Upstream conditions run the pipeline script at render time (T13).**
  About a second, once per project render. Alternative: only the targets the
  chapter reads.
- **E4 — Internals of `targets` and `tarchetypes` (T3, T6).** Pinned by
  tests; an upgrade that renames them fails the tests, not users silently.
- **E5 — `changes()` prints structural changes for the whole project first
  (T22)**, not chapter by chapter.

## Tests

Helpers in `helper-2e.R`. Every pipeline is tiny (two keys, at most five
targets). Tests that need `targets` call `skip_if_not_installed("targets")`;
`tarchetypes` and Quarto likewise; git tests `skip_if(!nzchar(Sys.which("git")))`.
`tar_make()` runs in its default `callr` process with `callr_arguments =
list(libpath = c(weft_test_lib(), .libPaths()))`, so the test session never
has `weft:dict` attached. Tests that run `tar_make()` are `skip_on_cran()`.

### 2e-1

**`helper-2e.R`**: `e1_project(files)` writes a set-up project into a temp
folder (`_weft.yml`, `dict.yml`, `_targets.R`, documents); `e1_make(dir)`
runs `tar_make()` there and returns the names in `tar_progress()` with
progress `completed`, without those starting `dict_`; `e1_dict(a = 1, b = 2,
def_a = "First.")` writes a two-key `dict.yml` (`number` entries).

**`test-tar-dict-walk.R`** (needs `targets`; no `tar_make()`)

- `code_reads()` on calls: `dict$a` → `a`; `dict[["b"]]` → `b`; `dict$"a"` →
  `a`; `dict[[k]]` and `f(dict)` and `names(dict)` → `all`, every key;
  `dict$zz` → `unknown` `zz`; a function `g <- function() dict$b` in an
  environment, called and passed as an argument (`lapply(1, g)`), → `b`; a
  recursive function terminates; `stats::median(dict$a)` → `a`; `pkg::fun`
  not followed; `quote(dict$a)` → `a`; code as a string; code that does not
  parse → nothing.
- Targets: `tar_read(fit)`, `targets::tar_read(fit)`, `tar_load(c(a, b))`,
  `tar_read_raw("x")`, `tar_read(y, store = "../_targets")` (store kept);
  `tar_read_raw(nm)` and `tar_load(starts_with("x"))` record nothing.
- `tar_dict()` on a two-key file in a temp folder (with `withr::defer()`
  detaching `weft:dict`): returns three targets named `dict_file`, `dict_a`,
  `dict_b`; `dict_file`'s format is `file`; `"weft:dict" %in% search()` and
  `get("dict", "weft:dict")$a` is 1; a second call leaves one `weft:dict`.
  Empty `dict.yml`: one target. Bad `dict.yml`: `weft_dict_error`. Missing
  path: `weft_pipeline_error`.
- `tar_dict_deps()`: `t$deps` of `tar_target(t1, dict$a + 1)` gains `dict_a`
  and keeps its other names; a target reading nothing is unchanged; a nested
  list keeps its shape; a number is `weft_pipeline_error`; two unknown keys in
  two targets give one error naming both targets and keys, with "Did you mean
  `a`" for `dict$aa`; `dict` assigned in `globalenv()` (deferred removal)
  gives the P5 error from both functions.
- Pinned: P11's fields on a `tar_target()` object.
- `need_targets()` mocked to fail: both exports raise its error.

**`test-tar-dict.R`** (needs `targets`; runs `tar_make()`)

`_targets.R`: `library(targets)`; `f <- function() dict$a + 10`; targets
`t_a` (`dict$a + 1`), `t_fn` (`f()`), `t_b` (`dict$b * 2`), `t_none` (`1`),
`br` (`1:3`), `t_pat` (`br * dict$b`, `pattern = map(br)`), all in
`weft::tar_dict_deps(list(...))` after `weft::tar_dict("dict.yml")`.

- First make runs all; a second runs none.
- `a` 1 → 5: exactly `t_a`, `t_fn`; `tar_read(t_fn)` is 15.
- `a`'s definition changed: none. `b` changed: `t_b`, `t_pat` (and branches).
  A third key added: none. Keys reordered: none.
- `f`'s body changed (`+ 20`): `t_fn` only.
- `tar_read(dict_a)` equals `read_dict()$a`.
- A `_targets.R` that also holds `dict <- weft::read_dict("dict.yml")`: the
  make fails with the P5 message.
- A `_targets.R` reading `dict$zz`: `tar_manifest()` fails with P8's message
  before any target runs.

**`test-tar-dict-quarto.R`** (needs `targets`, `tarchetypes`, Quarto)

- Pinned: a `tar_quarto()` target's command has `sources`.
- `report.qmd` reads `` `r dict$a` `` in prose and `dict[["b"]]` in a chunk
  with `eval: false`, and includes `_part.qmd` reading `dict$b` in a chunk;
  `tar_dict_deps(list(tar_quarto(report, "report.qmd")))` gives `report` the
  dependencies `dict_a` and `dict_b` (from `_part.qmd`; not from the
  `eval: false` chunk alone — a second fixture without `_part.qmd` gives
  `dict_a` only). A source that does not exist: `weft_pipeline_error`.
- End to end (`skip_on_cran()`): after a first make, changing `a` re-renders
  `report`; changing `a`'s definition does not.

**`test-ledger-reads.R`** (renders with `d2_render()`; the targets cases need
`targets` and build a plain pipeline, with no weft calls in `_targets.R`, by
`e1_make()` first)

- Dictionary reads: inline `` `r dict$a` ``, a chunk reading `dict[["b"]]`,
  and a chunk defining `h <- function() dict$c` then calling it: header
  `dict` has `a`, `b`, `c` with the hashes `weft:::dict_entry_hashes()`
  gives; a chunk with `eval=FALSE` reading `dict$d` adds nothing; `names(dict)`
  in a chunk records every key. The header's key order is fixed (`dict`,
  `files`, `targets` after the four of D4) and names inside are sorted.
- Hashes: changing `a`'s definition and re-rendering leaves the ledger file
  byte-identical; changing its value changes `dict.a` in the header.
  `file_hash()` of a file with CR LF line ends equals that of the same file
  with LF.
- Files: `files` holds `doc.Rmd` and a child `part.Rmd` (via `child=`) with
  their `file_hash()`; a cached render (`cache=TRUE` chunk reading `dict$a`)
  writes the same header as the first.
- Targets: a pipeline `up` (warns "upstream warned 3 times"), `fit` (`up +
  1`, warns twice: "first 5", "second"), `other` (no warning, not read); the
  document reads `tar_read(fit)` in a chunk and `` `r targets::tar_read(fit)` ``
  inline. Header `targets` is `{"_targets":{"fit":"<data hash>"}}`, the hash
  equal to `tar_meta()`'s. Condition log lines: `{"from":"target","source":"fit","class":"warning","normalised":"first <n>. second","text":"first 5. second"}`
  and the `up` line; none for `other`. `last_knit()$reads$targets` matches.
- A pattern `brx` whose branches each warn "branch warned": one line, source
  `brx`.
- An upstream target with `error = "continue"` that errored: a line of class
  `error`.
- A target warning "non-positive-definite Hessian matrix": the render fails
  (not draft) with a failure whose detail starts `target fit: warning:`; in
  draft mode the failure is listed and the log has no line for it.
- No script: rename `_targets.R` after the make; the render warns
  `weft_ledger_warning` naming `fit`, and the log holds `fit`'s line but not
  `up`'s.
- Cache: with `.weft/run` holding `run-1`, two renders leave
  `.weft/targets/network.rds`; after adding an edge to `_targets.R`, a render
  with the same run id still uses the old edges, and one with `run-2` the new.
- Not set up; `WEFT_REHEARSE=1`: no 2e header fields, no target lines,
  `last_knit()$reads` `NULL` (not set up) and nothing under `.weft/targets`.
- `targets` reported absent (the internal check mocked): a document that
  defines `g <- function() tar_read(fit)` and never calls it records `fit`
  with `null`, no target lines and no warning.

### 2e-2

**`helper-2e.R`** (continued): `e2_repo()` makes a temp folder with
`_weft.yml`, runs `git init` and sets a local user; `e2_ledger(dir, source,
output, entries, header = list())` writes `_weft/ledger/<source>/<output>.jsonl`
in D3's form from a list of entries (fields of D8, missing ones filled with
defaults: `occ` 1, `id` null, `context` prose, `arm`/`rel`/`raw`/`failed`
null, `dict` `[]`, `sentence` the text); `e2_conditions(...)` likewise;
`e2_commit(dir)` adds everything and commits. The source files named are
written too (any content), unless a test removes them.

**`test-changes.R`** (git)

- Errors: no `_weft.yml`; `git_path()` mocked to `""`; a folder outside any
  repository; `since = "nosuch"`; `files = "absent.qmd"` — each
  `weft_changes_error`.
- No commit yet: a ledger with two entries; `changes()` has both rows
  `added`, `ledgers$status` `new`, `attr(, "commit")` `NA`; the print has
  "(no commit yet)" and "new, 2 entries".
- Unchanged after commit: zero rows; print is exactly `weft: no changes since
  HEAD (<7 chars>); 1 ledger compared.`
- Text changed (`0.82` → `0.91`): one row `changed`, both texts and
  sentences, `structural` `""`, `rank` 1.
- `raw` changed, text the same: no row.
- Structural, one row each: `n` arm `one` → `other` (`arm one -> other`);
  raw −2 → 3 (`sign flip`); 0 → 4 (`crosses 0`); 0.98 → 1.04 (`crosses 1.0`);
  3 → 45 (`order of magnitude`), 9.9 → 10.1 (none); an entry with `dict`
  `["dict$limit"]`, raw 0.8 → 0.9, `dict.yml` `limit` 0.85 committed and now
  (`crosses dict$limit`); the same raw unchanged at 0.8 with `limit` moved
  0.85 → 0.75 and text changed (`crosses dict$limit`); a threshold taken from
  another entry in the same sentence.
- Ranking: three changed rows — one structural, one with "rose" in its
  sentence (+2%), one without a claim word (+50%): order structural, "rose",
  other; an entry whose own text is "three" has no claim word unless
  another word is present.
- Added and removed: a changed `expr` gives one `removed` and one `added`;
  an entry with an id moved to another section and unchanged text gives no
  row.
- Conditions: a new line is listed; a line whose text differs only in a
  number (same `normalised`) is not; a removed line is not listed.
- Ledgers: a source renamed `a.qmd` → `b.qmd` with its ledger folder (all
  entries alike): `renamed`, `from` `a.qmd`, and only real changes listed; a
  new chapter: `new`, entries not printed; a deleted ledger: `deleted`; a
  ledger whose source file was removed: note `source gone` and the folder to
  delete; a working-tree ledger with `<<<<<<<` lines: `unreadable`, note
  names the line.
- `since` an older commit (two commits back) compares with that commit.
- `files = "a.qmd"` limits rows to that ledger.
- Writes nothing: the project's file list, sizes and modification times, and
  `git status --porcelain`, are the same before and after.
- Print: sections appear in C14's order; markers `~`, `+`, `-`, `!`; the
  location format with `#section`, `(output)` only when it differs, `{#id}`;
  `(not re-rendered)` on rows of a stale ledger (header `files` with a wrong
  hash for the source).

**`test-changes-state.R`**

- `ledger_state()` on a header with `files` hashed from the file now: not
  stale; after editing the file: reason `doc.qmd changed`; after deleting it:
  `doc.qmd is gone`.
- `dict` hashes from `dict_entry_hashes()`: a value change gives `dict$a
  changed`; a definition change gives nothing; a removed key `dict$a is gone`;
  `dict.yml` with a problem: a note, not stale.
- A header without `dict`, `files`, `targets`: not stale, no notes.
- Targets (needs `targets`): a plain pipeline made; header with `fit`'s
  hash: not stale; after a change and a make: `` target `fit` changed ``; a
  name not in the store: `` target `x` is not in the store ``; the store
  deleted: note, not stale; `requireNamespace` mocked absent: note.
- `changes()` lists a stale ledger under "Not re-rendered" with its count
  and reasons, also when no entry differs from `HEAD`.

**End to end** (in `test-changes.R`, git and render): render `doc.Rmd` (2d +
2e-1), commit, change a value in the setup chunk, render, `changes()` lists
the entry with the right before and after sentences; edit a sentence without
rendering: the ledger is under "Not re-rendered" with `doc.Rmd changed`.

## Where the spec is silent, wrong or contradicts the build

Each with the smallest change to `PACKAGE-SCOPING.md`.

1. **4.6's example and 4.6.3 contradict** (measured 1): the line `dict <-
   weft::read_dict("dict.yml")` makes `dict` a tracked global, so a changed
   definition, or any value, re-runs every target whose function reads it.
   Remove the line; add **4.6.7**: "`tar_dict()` attaches the dictionary as
   `dict` on the search path. A `dict` object in the pipeline's environment is
   an error, because `targets` would track it."
2. **§18, the row on `tar_dict()`** rests on a spike that dropped every
   automatic dependency (measured 2). Replace "targets 1.12.0" with "targets
   1.12.0, re-measured for 2e with the dictionary on the search path" and add
   that a changed function re-runs its target.
3. **4.6.5** names `tar_quarto()` only. Add: "and `tar_render()`. Its source
   files, includes among them, are scanned: chunk code, inline R and construct
   keys. `tar_quarto_rep()` is not."
4. **7.2.2** says which targets a chapter reads, not how state is judged.
   Replace with: "The ledger's header records, with a hash of each, the
   targets the chapter reads, the dictionary entries its code reads and its
   source files. An entry is not re-rendered when any of them differs now.
   A chapter served from freeze keeps its old header." The stamp of 2.9.2 is
   then not part of 7.2.1.
5. **7.4.1, fourth source.** Add: "`tar_meta()` joins a target's warnings into
   one text, which is one line; a branch's condition is logged under its
   pattern. Finding the targets upstream runs the pipeline script once per
   project render." And to **7.4.2**: "A warning held by `tar_meta()` is
   matched too", which §15 assumes.
6. **7.3.4** does not define its six changes. Add C8's definitions (sign flip,
   crossing 0, crossing 1.0, crossing a dictionary value named by the
   expression or its sentence, a factor of ten) and "next to a claim word" as
   "in the same sentence".
7. **7.3.1** is silent without git and before the first commit. Add: "Without
   git it is an error. Before the first commit, everything is new. A ledger
   whose source was renamed is compared with the old one."
8. **7.3.5, tier-2 findings**, cannot be listed before stage 3. Add "(from
   stage 3)".
9. **7.3.6** "writes nothing": add "and runs no pipeline, so a store behind
   its code is not seen; `tar_outdated()` shows it."
10. **§20 Q5** gains: "`crew` workers do not see the dictionary `tar_dict()`
    attaches."
11. **`dev/design-2.md` §4, 2e** says the header records upstream targets and
    the third state reads the freeze stamp, and §8 that `tarchetypes` is
    needed only if wrapped. Point to this note: upstream is for conditions
    only (T7, T13), freeze is judged by hashes (T8), and `tarchetypes` is a
    test dependency.
12. **4.1.3** (`file` reserved): unchanged; the reason is `dict_file` (D19).

## Rulings on the 2e-2 test-writer's report

- **C8**: a change can have several structural reasons; they are joined
  in the order C8 lists them (`sign flip, crosses 1.0`).
- **C11**: whether `targets` is installed is asked with
  `requireNamespace("targets", quietly = TRUE)`, which the tests mock.
  With no `dict.yml` the reason is `dict.yml is gone`, once, not one
  line per key.
- **C6, C14**: the entries of a new ledger are `added` and of a deleted
  one `removed`; a deleted ledger prints its count, not its lines. The
  line formats the tests take from the example stand.
- **C4**: the note for an unreadable ledger carries the reader's
  message, with its line number.
- The helper's hashes are checked against 2e-1's `file_hash()` and
  `dict_entry_hashes()` by a test that skips until 2e-1 is built.

## Rulings on the 2e-1 test-writer's report

- **P17**: the internal check is `has_targets()`, which calls
  `requireNamespace("targets", quietly = TRUE)`; every part of 2e asks
  through it.
- **P9, "followed once"**: each function is walked once (a visited
  set), so a chain of helpers is followed to its end and recursion
  terminates.
- **P14**: `file_hash()` gives `NA_character_` for a file that cannot
  be read, written `null`; a hash that is `null` in the header is
  `NA_character_` in `last_knit()$reads`.
- **P13**: the three fields go in the ledger's header only; the
  condition log's header is unchanged.
- **P15**: the error-line test uses `error = "null"`; the design's
  `"continue"` leaves the reader unable to run.
- **2d tests that compare the whole header line** are amended when
  2e-1 is built: a set-up render's header always carries `dict`,
  `files` and `targets` after the four fixed fields.

## Rulings on the review of 2e-2 (`dev/review-2e2.md`)

Findings 1 to 14 are accepted, with these particulars:

- **1 (C5 amended).** A ledger whose source is gone is a rename
  candidate along with one that exists only at `since`. A pair is
  accepted when its content matches as C5 says and either the two
  output names are equal or each output name is its own source's base
  name. A paired ledger is compared entry by entry, with `file` mapped
  from the old source to the new.
- **2, 4, 5.** Every `*.jsonl` under `_weft/ledger/` is found on both
  sides whatever its name: non-ASCII, in a dot-folder, or holding `"`
  or `\` (git is asked with `-z`).
- **3 (C7 amended).** Within a group of entries with the same file,
  section, kind and expression whose counts differ between the sides,
  the occurrences are lined up by their sentences (longest common
  subsequence) before falling back to `occ`; so deleting one of three
  identical expressions reports that one as removed.
- **6.** The order-of-magnitude test has a tolerance (`>= 1 - 1e-9`).
- **7 (2d D8 amended).** The ledger entry gains a field `unit` after
  `raw`: the unit `raw` is in, as `units::deparse_unit()` writes it,
  `null` for a plain number (additive; the version stays 1). A
  dictionary threshold that is a quantity is converted to that unit
  before the comparison; when either side has no unit or they do not
  convert, there is no crossing reason for that key.
- **8.** The entry's own text is removed from its sentence as a whole
  word before the claim words are looked for.
- **9 (P14 amended).** An entry's hash is of its JSON with names sorted
  byte by byte at every level, so reordering an entry's fields changes
  nothing.
- **10.** Every listed entry of a stale ledger carries
  `(not re-rendered)`.
- **11.** A store that exists but cannot be read is a note (`the store
  <store> could not be read; the pipeline was not checked`), not
  stale.
- **12.** The "Not re-rendered" and "New conditions" lines name the
  output when it is not the source's base name.
- **13.** A ledger that is unreadable on one side prints a count, as a
  new or deleted one does.
- **14.** `files` accepts a leading `./`.

Questions:

- **A.** When a section anchor exists only at `since` and another only
  now in the same file, removed and added entries with equal kind,
  expression and occurrence are paired and reported as changed, marked
  `(section renamed from #<old>)`.
- **B.** "crosses 1.0" is strict: the value was on one side of 1 and is
  on the other. Starting or ending at exactly 1 is not a crossing.
  "crosses 0" is as defined.
- **C.** When `_weft/ledger/` is ignored by git, one note under
  "Ledgers" says so (`git check-ignore -q`, read-only, joins C2's
  list).
- **D.** A ledger whose source is gone keeps that note only; the third
  state is not computed for it.
- **E, F.** Stated in C9 and T26: the interim claim words are English
  only and the list is broad; stage 3's lexicon replaces it.
- **G.** Nothing now.

The implementer's calls on the layout stand, as the reviewer agrees.
