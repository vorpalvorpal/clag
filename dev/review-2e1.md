# Review of package 2e-1: the `targets` pipeline

Reviewed: the frozen snapshot `snap-2e1` (`R/targets.R`, with `R/hashes.R`, `R/hooks.R`,
`R/state.R`, `R/conditions.R`, `R/ledger.R`). The contract is `dev/design-2e.md` ("What was
measured", 2e-1 P1–P18, T1–T17 and the rulings at its end) and rules 4.6, 7.2.2 and 7.4.1 of
`PACKAGE-SCOPING.md`. Method: the snapshot was installed into a private library. Every
finding below was reproduced by building real tiny pipelines (`targets` 1.12.0, `tarchetypes`
0.14.0, R 4.4.3, Quarto 1.11.9) and running `tar_make()` in its default `callr` process,
twice and then after each edit. Other runs used `tar_make(callr_function = NULL)`. Documents
were rendered with `rmarkdown::render()`, `quarto render` and `tar_quarto()`/`tar_render()`
inside the pipeline. `targets` was hidden by giving a child process a library view that lacks
it. All scratch work is in `scratchpad/rev2e1/`: helpers `h.R` and `h2.R`, probes
`p1.R`–`p17.R`, projects under `p/`.

## Summary

The core mechanism is sound. Appending `dict_<key>` to `t$deps` and keeping `dict` on the
search path gives exact invalidation for every ordinary form of read:

- `$`, `$"k"` and `[["k"]]`
- `|> _$k`
- a function reached through a call, as an argument, recursively or three calls deep
- a function defined in a file loaded by `tar_source()`
- `!!`
- `tar_map()` over strings and over symbols, `tar_combine()`, `pattern = map()`
- `tar_target_raw(deps =)`, `format = "file"`
- `tar_quarto()` with includes and constructs

A changed definition, `decision`, reorder, added or removed key, or a quantity rewritten in
another unit with the same value re-ran no reader. The values a target sees equal what prose
sees, `display:` included.

The ledger header is right and deterministic in the cases the contract lists, and so is the
upstream condition path with its default store. The failures sit at the edges, and most of
them are silent:

- **Report sources that are not scanned:** a knitr `child=` file and a `.md` include. A
  report built from them shows an old number after a value change.
- **Targets the walker cannot see:** a target outside `tar_dict_deps()`, `tar_render_rep()`
  and `tar_quarto_rep()`, `get("dict")`, a helper kept inside a closure, an S3 method. These
  re-run on nothing.
- **Stale upstream edges:** a Quarto render that stops leaves `.weft/run` behind. Every later
  `rmarkdown::render()` then reuses old upstream edges indefinitely, so a severity-list
  warning in a new upstream target does not fail the render.
- **A non-literal `store =`** is recorded under the wrong store with a `null` hash.
- **Field order changes an entry's hash.** Ruling 9 on the review of 2e-2 says it should not,
  so reordering two lines of `dict.yml` makes the third state report the key as changed.
- **The per-key targets cost O(N²).** With 400 keys, any edit of `dict.yml` costs 36 s.

One runtime check would close most of the stale-result class at once (question A): while
`targets::tar_active()` is true, `$` and `[[` on the attached `dict` should refuse a key whose
`dict_<key>` is not in `tar_definition()$deps`.

14 findings: 3 stale result, 3 wrong record, 1 contract mismatch, 1 needless re-run (cost),
6 wording. No crash.

## Findings

### 1. Report sources that are knitr children or `.md` includes are not scanned; the report keeps an old value (stale result)

Contract: rule 4.6.5 and P10 ("included files too").

Reproduction, `tar_render()` (`p11.R`, 11a):

- `report.Rmd`: a set-up chunk calling `weft::weft_setup()`, then `A is `r dict$a`.`, then a
  chunk ```` ```{r, child='kid.Rmd'} ````.
- `kid.Rmd`: `B is `r dict$b`.`
- `_targets.R`:
  `c(weft::tar_dict("dict.yml"), weft::tar_dict_deps(list(tar_render(report, "report.Rmd", output_format = rmarkdown::md_document()))))`.
  Run `tar_make()`.
- Change `b` from 2 to 9 in `dict.yml`, then run `tar_make()`.

Actual: nothing re-runs, and `report.md` still reads "B is 2."

Reproduction, `tar_quarto()` (`p10.R`):

- `report.qmd` includes `{{< include _inc.md >}}`.
- `_inc.md`: `Included b is `r dict$b`.` Quarto expands the include before knitr runs, so this
  inline R is executed.
- Change `b` from 2 to 9.

Actual: nothing re-runs, and `report.html` still says "Included b is 2." The same report
re-rendered for a change to `len` then shows 9, which proves the old value was stale.
`tar_dict_deps()` gives the same empty result for a `.qmd` with a `child=` chunk (`p5.R`).

Expected: `report` depends on `dict_b` and re-renders.

The knit-time header gets this right. It lists `b`, `kid.Rmd` and `_inc.md`, because the
label hook sees the code. So the ledger and the pipeline disagree about what the report
reads.

Cause: in `R/targets.R`, `report_files()` returns only `path` for `tar_render`. For
`tar_quarto` it returns `quarto inspect`'s list, which has no knitr children. Then
`tar_dict_deps()` skips every source not matching `\.(qmd|Rmd|rmd)$`, which drops `.md`.
`report_reads()` does not follow the `child` option of the chunks it reads.

### 2. Targets outside `tar_dict_deps()` and the `*_rep` report targets never re-run on a value change, without a message (stale result)

Contract: rule 4.6.3 ("re-runs exactly the targets that read it"); P10 leaves out
`tar_quarto_rep()` and `tar_render_rep()`.

Reproduction (`p3.R`, 3a):

```r
c(weft::tar_dict("dict.yml"),
  weft::tar_dict_deps(list(tar_target(inside, dict$a))),
  list(tar_target(outside, dict$a * 2)))
```

Change `a` from 1 to 5. Actual: only `inside` re-runs; `tar_read(outside)` is still 2.

Reproduction (`p16.R`):

```r
tar_render_rep(rrep, "r.Rmd", params = data.frame(p = 1:2, output_file = c("a.md", "b.md")),
               output_format = rmarkdown::md_document())
```

This is wrapped in `tar_dict_deps()`, and `r.Rmd` contains `Value `r dict$a`.`. Change `a`
from 1 to 7. Actual: nothing re-runs, and `a.md` still says "Value 1." `tar_quarto_rep()`
likewise gains no `dict_*` dependency (`p15.R`).

Expected: either the read is tracked, or the pipeline stops with a message. P10 documents the
`*_rep` gap, but nothing tells the user at run time. The `outside` case needs only one misplaced
`list()`.

Cause: by design. `tar_dict()` attaches a `dict` that any command can read, and
`tar_dict_deps()` is the only place reads are tracked. A target it never sees, or sees and
cannot parse, has no edge. See question A for a run-time guard. I checked that it is feasible:
inside a wrapped target, `targets::tar_definition()$deps` contains `dict_a`. The probe target
`guarded` in `p11.R` ran `stopifnot("dict_a" %in% targets::tar_definition()$deps)` and passed.

### 3. The walker misses `get("dict")`, a helper held in a closure, and an S3 method reached by dispatch (stale result)

Contract: P9 and rule 4.6.2 ("and the functions it calls").

Reproduction (`p1.R`): each of these targets reads `a`.

| Target | Reads `a` through |
|---|---|
| `t_get` | `get("dict")$a` |
| `t_mget` | `mget("dict", inherits = TRUE)[[1]]$a` |
| `t_clo` | `g_clo()`, where `make_g <- function() { inner <- function() dict$a; function() inner() }; g_clo <- make_g()` |
| `t_s3` | `summary(structure(1, class = "myc"))`, where `summary.myc <- function(object, ...) dict$a` |

Change `a` from 1 to 5.

Actual: none of the four re-runs (`tar_read(t_get)` is still 1). Eleven other forms in the
same pipeline re-ran correctly. `t_eval` (`eval(parse(text = "dict$a"))`) is also missed, but
no static walker can see it.

Expected: these targets re-run, or the run-time guard of question A stops them.

Cause: `reads_walker()` in `R/targets.R`.

- It counts only the symbol `dict`, not the string `"dict"` as an argument to `get()`,
  `get0()`, `mget()` or `exists()`.
- `follow()` looks a name up only in `envir` with `inherits = FALSE`. It never looks into a
  closure's own environment, so `inner` is not found.
- It has no notion of S3 dispatch.

`targets` shares the last two blind spots for function bodies, but for dictionary values this
is weft's promise to keep. Cheap partial fixes:

- Treat a literal `"dict"` anywhere as reading every key.
- When following a closure whose environment is not `envir`, also follow the functions bound
  in that environment.
- For a call to `g()`, also follow any `g.<class>` functions in `envir`.

### 4. The cached upstream edges outlive the render they belong to; a later render misses a severity-list warning (wrong record)

Contract: P16 ("reused while both match and the run id is not empty: once per Quarto project
render"), P15 and rule 7.4.2.

Reproduction (`p13.R`, `p13b.R`):

1. Build a project:
   - `_targets.R`: `list(tar_target(up, 1), tar_target(fit, up + 1))`
   - `_weft.yml`: `draft: false`
   - `weft::use_quarto(".")`
   - `a.qmd` reads `tar_read(fit)`; `b.qmd` runs `stop('chapter b broke')`
2. Run `tar_make()`, then `quarto render`. It fails on `b.qmd`, so the post-render script does
   not run. `.weft/run` and `.weft/targets/network.rds` stay, with the same run id.
3. Fix `b.qmd`. Change `_targets.R` to add
   `tar_target(hess, { warning("non-positive-definite Hessian matrix"); 2 })` and
   `fit = up + hess`. Run `tar_make()`.
4. Run `rmarkdown::render("a.qmd")`.

Actual: the render passes, and the condition log has no `hess` line. The cache from step 2 is
used. Running `quarto render a.qmd` instead writes a new run id and fails correctly ("target
hess: warning: non-positive-definite Hessian matrix"). `p8.R` shows the same with a
hand-written `.weft/run`: the render passes while the file exists and fails once it is
removed. Nothing expires the cache, so it stays wrong until the next successful project
render.

Expected: a knit outside a Quarto render does not trust `.weft/run`. That is already the rule
for the collection file: `collection_path()` checks `QUARTO_EXECUTE_INFO` and the file's age.

Cause: `upstream_targets()` in `R/targets.R` uses `run_id(root)` unconditionally. Question B
suggests a key that is both cheaper and correct.

### 5. A `store =` that is not a literal is recorded under the wrong store, with a `null` hash and no conditions (wrong record)

Contract: P13 (the store of a read) and rule 7.2.2. The 2e-2 third state relies on this field.

Reproduction (`p11.R`, 11d): `chap/nonlit.Rmd` runs
`f <- tar_read(fit, store = file.path("..", "_targets"))` in a set-up project whose store is
at the root. Render it from `chap/`.

Actual header:

```
"targets":{"chap/_targets":{"fit":null}}
```

The condition log holds no lines, although `up` warns. With the literal
`store = "../_targets"` the header is `{"_targets":{"fit":"51cfc97e3e0d005e"}}`.

Expected: the store the chapter really read. If that cannot be known, nothing is recorded and
weft says so. A store that does not exist leads 2e-2's `ledger_state()` to a note rather than
a reason, so this chapter can never be reported as not re-rendered.
`store = here::here("_targets")` is a common way to write this in a book with subfolders.

Cause: `record_target()` in `R/targets.R` keeps `store` only when it is a literal string.
Otherwise it leaves `NA`, which `chapter_reads()` then reads as the default store. Two fixes
would work. Treat a non-literal `store` as unknown and skip the read, with a
`weft_ledger_warning`. Or evaluate the `store` expression in `knitr::knit_global()` at the
document hook, inside `tryCatch()`; the chapter has just run that code.

### 6. An entry's hash depends on the order of its fields and on quoting (wrong record; contract mismatch with the 2e-2 rulings, finding 9)

Contract: P14 as amended in "Rulings on the review of 2e-2", item 9: "names sorted byte by
byte at every level, so reordering an entry's fields changes nothing".

Reproduction (`p8.R`, `p17.R`):

- `weft:::dict_entry_hashes()` of
  `len: {value: 1500, type: quantity, unit: m, definition: ...}` is `5608d7bc5ad2269a`. With
  the `value` and `type` lines swapped it is `24ba2d6899385787`.
- In a rendered project, swapping the `value:` and `type:` lines of `alpha` makes
  `weft:::ledger_state(root, header)` return `stale = TRUE` with the reason
  `dict$alpha changed`.
- `value: "1500"` and `value: 1500` read to the same value, but their hashes differ.

Expected: reordering changes nothing. Quoting a number arguably should change nothing either,
since `read_dict()` accepts both.

Cause: `dict_entry_hashes()` in `R/hashes.R` writes the JSON with names in file order. It
hashes the YAML as written, not the value as read.

### 7. Upstream conditions are dropped, silently, for a read from a store that is not the knit's default (contract mismatch)

Contract: rule 7.4.1 ("and for the targets upstream of those") and P16. This was the
implementer's call, accepted for now and filed for this review.

Reproduction (`p6.R`, `p11.R`, 11d):

- `_targets.R`: `up` warns "up warned", `fit` is `up + 1`.
- `chap/lit.Rmd` reads `tar_read(fit, store = "../_targets")`.

Actual: the condition log has no line for `up` and the render gives no message. A document at
the root that reads `tar_read(fit)` gets the `up` line.

Expected: the upstream conditions. If they cannot be had, P16's `weft_ledger_warning`
("the targets upstream of fit were not read ..."), so the gap is visible.

Cause: `target_conditions()` calls `upstream_targets()` only when the store is the default
one. The pipeline for a store at `<dir>/_targets` is almost always `<dir>/_targets.R`, or is
named by `<dir>/_targets.yaml`. Running `tar_network(script =, store =)` from `<dir>` would
cover the common book layout. Otherwise, emit the warning.

### 8. The `dict_<key>` targets each read the whole dictionary; any edit of `dict.yml` costs O(N²) (needless re-run, cost)

Contract: P4 and T4. Rule 4.6.3 is met (no consumer re-runs), but every `dict_<key>` does.

Reproduction (`p14.R`, `p14c.R`): number entries and one consumer.

| Keys | First make | After a definition-only edit | Make with no edit | One `read_dict()` |
|---|---|---|---|---|
| 150 | 4.8 s | 4.7 s | 0.7 s | |
| 400 | 37.5 s | 35.8 s | | 0.18 s |

Expected: about the cost of one read plus N trivial targets.

Cause: `tar_dict()` makes each `dict_<key>` run `weft::read_dict(dict_file)[["k"]]`. Better:
one target `dict_values` (`weft::read_dict(dict_file)`, plain list), with each `dict_<key>`
running `dict_values[["k"]]`. Consumers still depend only on `dict_<key>`, whose hash is
unchanged when its value is. Unit installation (4.4.7) would then happen once.

### 9. The "upstream not read" warning loses its cause (wording)

Contract: P16 ("... were not read (<message>) ...").

Reproduction (`p7.R`): append `stop('broken script')` to `_targets.R` and render a document
that reads `tar_read(fit)`.

Actual:

```
weft: the targets upstream of fit were not read (Error in tar_network():); the condition log holds the conditions of the targets the document reads (rule 7.4.1).
```

Expected: the message names `broken script`.

Cause: `upstream_targets()` keeps `sub("\n.*$", "", conditionMessage(net))`. The `callr` error
from `targets` puts its cause on a later line. Take the last non-empty line, or the message of
the parent condition (`net$parent`).

### 10. The global-`dict` error blames `_targets.R` for a `dict` in the interactive session (wording)

Contract: P5.

Reproduction (`p4.R`): in an R session, run `dict <- weft::read_dict("dict.yml")` to explore,
then `tar_make(callr_function = NULL)`.

Actual: "`dict` is an object in the pipeline's environment ... Remove `dict <- ...` from
_targets.R". There is no such line; the object is from the session.

The default `callr` make succeeds. A weft knit run in the session, which leaves `dict` in the
global environment, triggers the same message.

Expected: the message says "in the pipeline's environment (the global environment when
`callr_function = NULL`)" and suggests `rm(dict)` as well.

Cause: `refuse_global_dict()` in `R/targets.R`.

### 11. Name clashes are reported by `targets`, not weft (wording)

Contract: P4, and the error convention that "messages end with the rule".

Reproduction (`p3.R`, `p11.R`):

- A user target `tar_target(dict_zz, 42)`, then key `zz` added to `dict.yml`, gives "duplicated
  target names: dict_zz".
- Two calls, `tar_dict("dict.yml")` and `tar_dict("other.yml")`, give "duplicated target names:
  dict_file". The second call has also replaced the attached `dict`.

Expected: a `weft_pipeline_error` that names the clash and the rule. The prefix `dict_` should
be reserved, and there is one dictionary per pipeline.

Cause: `tar_dict()` and `tar_dict_deps()` check neither case. `tar_dict_deps()` sees the user
target `dict_zz` and the keys at the same time, so it can check for a clash.

### 12. `tar_outdated()` lists every reader after a definition-only edit (wording, documentation)

Contract: the help of `tar_dict()` and rule 4.6.3.

Reproduction (`p11.R`, 11a): change only `a`'s definition.

Actual: `tar_outdated()` returns `report dict_a dict_b guarded dict_file`. `tar_make()` then
re-runs no reader. After a change to `b` alone, `tar_outdated()` also lists the readers of `a`
(`p4.R`).

Expected: this is how `targets` treats intermediate targets, so it is not a bug. But the help
promises "a changed definition ... re-runs none", and users check with `tar_outdated()` and
`tar_visnetwork()`. One sentence in `?tar_dict` would prevent a false alarm: "`tar_outdated()`
lists every reader after any edit of `dict.yml`; `tar_make()` re-runs only those whose
entries' values changed."

### 13. "Did you mean" differs between the pipeline and a knit (wording)

Contract: P8 ("under 2a's rule (one key within edit distance 2)"), as amended by the ruling on
the implementer's report.

Reproduction (`p12.R`, `p15.R`): keys `abcd` and `abxy`.

- In the pipeline, `dict$abcx` gives "... Did you mean `abcd`?"
- In a knit (`read_dict()` then `$abcx`), it gives "`dict$abcx`: no such key in ... (rule
  4.1.2)" with no suggestion.

Expected: one rule. See "The implementer's calls".

### 14. `tar_dict()` leaves `weft:dict` attached in the session after an in-process make (wording, documentation)

Reproduction (`p4.R`): after `tar_make(callr_function = NULL)`, `search()` holds `weft:dict`,
and `dict$a` at the console returns the pipeline's value. It is refreshed on the next make.

Expected: as designed (P3), but undocumented. A non-weft script run later in the same session
silently finds this `dict`. The help should say so, and say that `detach("weft:dict")`
removes it.

## The implementer's calls

- **"Did you mean": the nearest key within distance 2, none on a tie.** This is the better rule:
  keys `abcd` and `abxy` with `dict$abcx` get a useful suggestion. 2a's rule ("exactly one key
  within 2") stays silent there (finding 13). I recommend moving `read_dict()`'s key error to
  the same rule, so one typo gets the same help in a chapter and in `_targets.R`. That is a
  change to stage 1, so it should be filed. Do not keep two rules.
- **Upstream conditions only for the default store.** I do not agree that this should stand
  silently. The common book layout (`store = "../_targets"` from a chapter folder) loses every
  upstream warning, with no message (finding 7). The minimum is P16's warning. The better fix
  derives the script from the store's folder.
- **Only `.qmd`, `.Rmd` and `.rmd` sources scanned.** This is too narrow. A `.md` include is
  executed by knitr after Quarto expands it, and a stale report was reproduced (finding 1). Scan
  every text source in `sources`, except binary or obviously non-R types; a `.R` file listed
  by Quarto would also be worth walking. Follow `child=` in both report kinds.
- **Reliance on `t$deps`, `command$expr` and `tarchetypes`' command layout.** The pinned tests
  will notice a rename in the versions on the developer's machine. The end-to-end test (a value
  change re-runs) is what proves that `targets` still builds edges from `t$deps`, and it is
  `skip_on_cran()`. The tests cannot protect a user who upgrades `tarchetypes` after
  installing weft. If `tar_quarto_run`'s layout changes, `report_files()` returns `NULL`, the
  target is walked as a plain command and finds nothing, and the report goes stale silently
  (the mechanism of finding 2). Add a run-time check: a command whose head is any
  `tarchetypes::*_run` that `report_files()` cannot read should be a `weft_pipeline_error`
  ("weft does not know this report target's sources"). That covers `tar_quarto_rep()` and
  `tar_render_rep()` today as well.
- **P13: the source is always in `files`; an entry's file or a child is listed when it
  exists.** Held. `kid.Rmd` and `_inc.md` were listed with correct hashes.
- **7.4.5: the normaliser needs a digit after the decimal point.** Held. "first 5" became
  "first <n>".

## Tried and held

- Invalidation, each verified with `tar_make()` twice and after the edit (`p1.R`, `p2.R`,
  `p14.R`):
  - **Correct re-runs for these read forms:** `dict$"a"`, `dict[["a"]]`, `dict |> _$a`,
    `with(dict, a)`, `local({ d <- dict; d$a })`, `lapply(c("a"), \(k) dict[[k]])`; the last
    three read every key.
  - **Functions followed:** `tar_source()` functions, a three-deep helper chain, a
    self-recursive function, a function passed as an argument, `rlang::expr(!!dict$a)`.
  - **`tarchetypes` targets and options:** `tar_map()` over strings (`dict[[k]]`) and over
    symbols (`dict$k`), `tar_combine()`, `pattern = map()` with its branches,
    `tar_target_raw(deps = "x0")` (its own edge kept), `format = "file"` with a downstream
    reader, `cue = tar_cue("never")` (never re-runs, as asked).
  - **Keys:** `a.b` and `a_b` stay separate.
  - **Edits that re-ran no reader:** a definition change, a reorder, an added key, a removed
    key, a `decision:` added; definition changes of a `breaks` and a `labels` entry, whose
    closures hash stably; 1500 m rewritten as 1.5 km under `display: km`.
  - Mutual recursion makes `targets` itself fail with "igraph::is_dag(graph) is not TRUE". The
    walker terminates on it (`code_reads()`, `p12.R`).
- **Errors** (`p3.R`): a bad `dict.yml` gives the `weft_dict_error` with all problems; an
  empty one gives the unknown-key error. Four unknown keys in three targets give one error
  listing all of them, with a hint only where one key is nearest.
- **Sessions and scripts** (`p4.R`, `p11.R`): `tar_dict()` sourced repeatedly (callr,
  in-process, `tar_manifest()`, `tar_outdated()`) leaves exactly one `weft:dict`. A script
  moved by `tar_config_set(script = "pipe/_targets.R")` with a relative `dict.yml` works and
  invalidates correctly.
- **Values match** (`p10.R`): prose `r dict$len` gives 1.5, `tar_read(t_txt)` gives
  "1.5 [km]" and `tar_read(dict_len)` gives 1.5 km. After a change, all three show 2.5.
- **Report targets** (`p5.R`, `p10.R`): `tar_quarto()` re-renders on a value change and not on
  a definition change. Also correct:
  - constructs `if="x > dict$b"` and `n="dict$c"`
  - a `.qmd` in a subfolder
  - `#| eval: !expr TRUE` and `eval=1 > 0` (both counted)
  - `tar_quarto_raw()`
  - a Quarto project target (`path = "."`)
- **Ledger header** (`p6.R`, `p11.R`, `p12.R`):
  - Every read form below is recorded with `tar_meta()`'s hash: `tar_read(fit)`,
    `tar_load(c(x, y))`, `tar_read_raw("w")`, `targets::tar_read(z)` inside a function,
    inline `targets::tar_read(v)`, `tar_read(other)` in a knitr child.
  - Literal `store = "../_targets"` is recorded under `_targets` relative to the root.
  - The header is byte-identical across two renders and under `LC_COLLATE` `C` and
    `en_US.UTF-8`.
  - Hashes change exactly when the target read changes: an edit to `up` changes `fit`, and an
    edit to an unrelated target changes nothing.
- **Conditions** (`p6.R`, `p7.R`, `p8.R`):
  - A warning in `up` reaches the log with `source` `up`.
  - Its text is carried forward when only a number changes.
  - Branches collapse to `brx`.
  - A severity-list match fails the render with "target hess: warning: non-positive-definite
    Hessian matrix / matched the severity pattern ...".
- **Without `targets`** (`p9.R`, child process with `targets` hidden): reads are recorded with
  `null`, with no conditions and no message.
- **`WEFT_REHEARSE=1`** (`p8.R`): the ledger is not touched.
- **Cost of a render that reads a target** (`p7.R`, `p8.R`):
  - It adds about 0.45 s (0.09 s to 0.53 s) on every render outside a Quarto project render,
    because no run id means no cache. With the cache it is 0.1 s.
  - Rendering runs `_targets.R` once in a `callr` process, as E3 says. A `cat(..., file =
    "side_effect.txt")` in the script ran at render time.
  - Nothing is written outside `_weft/` and `.weft/` except by the user's own script.

## Questions for the author

A. **Should a read of the attached `dict` check its own dependency at run time?** In the
   `$` and `[[` methods of the object `tar_dict()` attaches, when `targets::tar_active()` is
   true, check that `paste0("dict_", key)` is in `targets::tar_definition()$deps`. If it is
   not, raise an error naming the target and key: "add it to `tar_dict_deps()`". A read of
   every key (`names(dict)`, `with()`) can check that every `dict_*` is there. This turns
   findings 2 and 3, and any future layout change in `tarchetypes`, from stale numbers into an
   error on the first make. It costs one lookup per read, and it works in `crew` workers if
   T2's wrapper ever comes. *Recommendation: yes.*

B. **What should key the upstream-edge cache?** The run id is wrong outside a render (finding
   4), and empty in every single-file render (0.45 s and a run of `_targets.R` each time).
   `tar_meta()`'s conditions were written by the last `tar_make()`. Keying the cache on
   `_targets/meta/meta`'s size and modification time, plus the script path, would reuse it
   correctly across renders and refresh it exactly when the store changes. A script edited
   but not yet made gives edges newer than the conditions; that is harmless, and no worse
   than now. *Recommendation: key on the store's meta file, and drop the run id here.*

C. **Should a file a chapter `source()`s be in the header's `files`?** In `p12.R`, a chunk
   runs `source('helpers.R', local = TRUE)` and calls `hf()`. `hf`'s dictionary reads are
   recorded, but `helpers.R` is not in `files`. An edit to it that changes only arithmetic
   leaves the header as it was, so 2e-2 cannot see the chapter as not re-rendered.
   *Recommendation: record literal paths given to `source()` and `sys.source()` in walked
   code, as children are.*

D. **Should weft keep `.weft/` out of git?** It now holds `run`, `failures.jsonl`, `stamps/`
   and `targets/network.rds`. Nothing writes a `.gitignore`, so `git add .` commits them, and
   `network.rds` would then be shared across machines. *Recommendation: `use_quarto()` writes
   `.weft/.gitignore` containing `*`. That needs no edit to the user's own `.gitignore`.*

E. **Should one dictionary per pipeline be stated and enforced?** See finding 11.
   *Recommendation: yes. A second `tar_dict()` call is a `weft_pipeline_error`, and so is a
   user target named `dict_<anything>`.*

F. **Should `tar_dict_deps()` warn on reads it can never see?** Before question A exists, it
   could warn about `eval(parse(...))`, `get("dict")`, and calls of generics with `.<class>`
   methods in `envir` that read `dict`. *Recommendation: no, if A is adopted. A makes these
   errors at run time, with no false alarms.*
