# Review of package 2e-2 — `changes()` and the third state

Reviewed: the frozen snapshot `snap-2e2` (`R/changes.R`, `R/hashes.R`, with `R/ledger.R`),
against `dev/design-2e.md` (2e-2, C1–C14, T18–T32, the rulings) and rules 7.2 and 7.3 of
`PACKAGE-SCOPING.md`. Method: real knits of small `.Rmd` documents in temporary git
repositories (genuine 2d ledgers), then edits, renders, commits and `changes()`, plus
hand-written ledgers (the tests' `e2x_*` helpers) for edge cases. The 2e-1 header fields
were written by hand with `weft:::file_hash()` / `weft:::dict_entry_hashes()`, and a real
two-target `targets` 1.12.0 pipeline was used for the store. All scratch work is in
`scratchpad/rev2e2/` (scripts `t1.R`–`t12.R`, helpers `h.R`).

## Summary

Most of the core works. Keying, `null` against `""`, arm-only changes, failed constructs,
unit ladders, the C8 reasons and their order, dictionary thresholds when `dict.yml` itself
changed, the third state for files, dictionary entries and `targets` stores, every git
revision form, subfolder roots, worktrees, submodules, shallow clones and CRLF all behaved
as the contract says. The call also writes nothing: the whole tree, `.git` included, and
`git status` were identical before and after, and only `rev-parse`, `ls-tree` and `show`
were spawned. Two defects stand out. First, a **renamed source is never paired in the
ordinary case**, so a value that changed in a renamed chapter is not reported. C5 pairs only
ledgers with equal output names, a single-output document's output name follows its file
name, and the old ledger is left in the working tree (G21), so it is never offered for
pairing at all. Second, a **non-ASCII source or output name crashes `changes()`**, because
the radix sort refuses the native-encoded paths from `list.files()` and `git ls-tree`.
Behind those come the occurrence drift that 7.1.6 accepts, which prints the wrong sentence as
removed, and three smaller blind spots that silently hide a ledger: dot-folders, quoted git
paths, and an exact tenfold change missed by floating point. 14 findings: 5 missed or false
change, 1 crash, 3 wrong ranking, 2 contract mismatch, 3 wording; none writes anything.

## Findings

### 1. A renamed source is not paired, so its changed values are not reported — missed change

Reproduction (real knits, `t5.R`, `t11.R`): `a.Rmd` with `## S`, `Total \`r k\` here.`,
`Mean \`r m\` there.`, `k <- 3; m <- 2.5`. Knit, commit. `git mv a.Rmd b.Rmd`, set
`k <- 30`, knit `b.Rmd`. The working tree now holds `_weft/ledger/a.Rmd/a.jsonl` (left, as
2d G21 says) and `_weft/ledger/b.Rmd/b.jsonl`.

Actual:
```
weft changes since HEAD (86807f6): 1 ledger compared; 0 changed, 2 added, 0 removed; 0 new conditions

Ledgers
  a.Rmd (a): source gone; delete _weft/ledger/a.Rmd/
  b.Rmd (b): new, 2 entries
```
Deleting the old ledger folder first gives `a.Rmd (a): deleted, 2 entries` /
`b.Rmd (b): new, 2 entries`, still unpaired. Even with equal output names (hand ledgers,
`output = "out"`) the pair is missed while the old ledger is still in the working tree (V1).

Expected: `b.Rmd (b): renamed from a.Rmd`, and `~ b.Rmd#s bare k [order of magnitude]`
with 3 → 30 (C5, T20, 7.3.4). As built, the change from 3 to 30 appears nowhere: the new
chapter is a count, by T21.

Likely cause: `R/changes.R`, `changes()` and `pair_renames()`. (a) Pairing considers only
`only_then`/`only_now`. A ledger that exists on both sides but whose source is gone (the
normal state after a rename, G21) is `compared` and never offered as A. (b) C5 requires
`identical(b$output, a$output)`, and a single-output document's output is its base name,
so `a` ≠ `b`. The C5 wording is itself the trap. Suggest treating a ledger whose source is
gone as a rename candidate, and accepting a pair when the outputs are equal *or* each output
is its own source's base name. The C5 contract text needs the same change.

### 2. A non-ASCII source or output name makes `changes()` fail — crash

Reproduction (`t8b.R`, `x2`): `put(d, "données.qmd", list(en(text = "1")))`, commit,
change the text, then `changes(path = d)`. The same happens with an ASCII source and output
`résumé`, and with the ledger present only at the commit, which is the then-side path.

Actual: `Error in order(x, ..., method = "radix"): Character encoding must be UTF-8, Latin-1
or bytes` (call stack `ledger_paths_now -> sort`; the then side fails the same way in
`ledger_paths_then`). This happens in an en_AU.UTF-8 session.

Expected: a normal report (C3). Any author with an accented chapter name cannot use
`changes()` at all.

Likely cause: `R/changes.R`, `ledger_paths_now()` (line 142) and `ledger_paths_then()`
(line 150). `list.files()` and `system2()` return strings marked `"unknown"`, and
`sort(method = "radix")` rejects non-ASCII strings in that encoding. Fix: `enc2utf8()` (or
`Encoding<- "UTF-8"` for git's output) before sorting. A non-ASCII root folder is fine,
because the paths are relative.

### 3. Deleting one of several identical expressions shows the wrong sentence as removed, or a chain of false changes — misreport

Reproduction A (real knit, `t2.R` "A"): `## Results` / `All \`r k\` samples passed.` /
`Another \`r k\` here.` / `And \`r k\` again.`, `k <- 3`. Knit, commit, delete the first
sentence, knit.

Actual:
```
Removed
  - doc.Rmd#results  bare  k
      And 3 again.
```
Expected: the removed entry is `All 3 samples passed.`. "And 3 again." is still in the
document.

Reproduction B (`t2.R` "B"): three `k` values with `k <- k + 1` chunks between them (3, 4,
5). Delete the first. Actual: two changes, `Early 3 samples.` → `Mid 4 samples.` and
`Mid 4 samples.` → `Late 5 samples.`, plus `Removed: Late 5 samples.` Expected: one
removed entry, `Early 3 samples.`.

Rule 7.1.6 accepts B ("compared with its predecessor's entry … cannot hide a change"), but
the report is still misleading, and A prints a sentence that was not removed. The
information to align the occurrences is in both ledgers (`sentence`).

Likely cause: `R/changes.R`, `compare_entries()`, which keys strictly on `occ` (`entry_keys()`).
Suggest: within a (`file`, `section`, `kind`, `expr`) group whose counts differ, align the
occurrences by sentence (longest common subsequence) before falling back to `occ`. This
needs an amendment to C7.

### 4. A ledger under a dot-folder is invisible in the working tree and reported deleted — missed change

Reproduction (`x1`): a ledger for `.drafts/a.qmd` with text `1`, commit, then text `2`.
Actual: `0 ledgers compared; 0 changed, 0 added, 1 removed` and `.drafts/a.qmd (a):
deleted, 1 entry`. Expected: one changed entry (C3: "every `*.jsonl` under
`_weft/ledger/`").
Likely cause: `ledger_paths_now()` calls `list.files(recursive = TRUE)` without
`all.files = TRUE`, which skips hidden folders and files. The same applies to an output name
that starts with `.`.

### 5. A source name containing `"` or `\` is never found at the commit — missed change

Reproduction (`t10.R` U3): `put(d, "say \"hi\".qmd", ...)`, commit, then
`changes()` with nothing changed. Actual: `0 ledgers compared; … 1 added` and
`say "hi".qmd (say "hi"): new, 1 entry`, on every run. Expected: `weft: no changes … 1
ledger compared.`
Likely cause: `ledger_paths_then()`. `git ls-tree` C-quotes such paths even with
`core.quotepath=false`, so the line ends in `.jsonl"`, fails the `\\.jsonl$` filter and is
dropped. Use `-z`, or unquote. This is rare, but it is silent.

### 6. An exact tenfold change misses "order of magnitude" about one time in ten — wrong ranking

Reproduction (`t4.R` h3): before `raw 0.07`, after `raw 0.7` (both as the ledger stores
them, six significant figures). Actual: `structural ""`. Expected: `order of magnitude`
(C8.6, `abs(log10(abs(a / b))) >= 1`; T23 "a factor of ten"). `0.06 → 0.6` and `0.7 → 7`
are flagged, while `0.07 → 0.7`, `0.021 → 0.21` and `0.029 → 0.29` are not, because
`log10(0.7/0.07)` is `0.99999999999999989`. Over the 9,990 values 0.001…9.99, 986
tenfold-up pairs and 275 tenfold-down pairs are missed.
Likely cause: `structural_reasons()`, line 298. Compare with a tolerance (`>= 1 - 1e-9`).

### 7. A dictionary threshold in another unit misses a real crossing — wrong ranking

Reproduction (`t10.R` U4): `dict.yml` `lim: {value: 1, unit: km, type: quantity}`. An entry
with `dict ["dict$lim"]` goes from `1.2 km` (raw 1200, as a real `u(x, m)` with a ladder
stores it; see `t2.R` C, where `1.5 km` has raw 1500) to `0.8 km` (raw 800). Actual: no
`crosses dict$lim`, because 1200 and 800 are both above 1. Expected: the value crossed the
limit.
Likely cause: `dict_numbers()` and `structural_reasons()` compare the raw value, in the
value's own unit, with the threshold in the entry's unit. T24 records the cost as "can cross
falsely". It can also miss a crossing, and here it does. The ledger does not store the raw
value's unit, so the fix is either to store it (2d) or to say so in T24 and C8.

### 8. The claim word can be the entry's own text, when that text first occurs inside another word — wrong ranking

Reproduction (`t4.R` h7, h12): text `ten`, sentence `Often ten sites.` → `claim_word`
`ten`. Text `one`, sentence `None but one site.` → `one`. Expected: `NA` (C9: the entry's
own text is removed so that it is not its own claim word).
Likely cause: `sentence_claim()` uses `sub(text, "", sentence, fixed = TRUE)`, which removes
the first *substring* match ("Of|ten", "N|one"), not the value. Remove a whole-word match
(`(?<![[:alpha:]])text(?![[:alpha:]])`), or remove the token from the token list.

### 9. Reordering the fields of a dictionary entry marks every chapter that reads it as not re-rendered — false change (follows P14)

Reproduction (`t6b.R`): a header `dict {"lim": <hash>}` from
`lim: {value: 0.85, type: number, definition: …}`, then rewrite the entry as
`lim: {type: number, value: 0.85, definition: …}`. Actual: stale, `dict$lim changed`.
Expected: not stale, since nothing a document prints changed (7.2.1 "something it depends
on changed"). Rewording the definition, `0.850`, and block style instead of flow style all
held.
Likely cause: `R/hashes.R`, `dict_entry_hashes()`, which hashes the JSON "with names in file
order", as P14 says. Under stage 4, `verify()` would fail tier 1 on a cosmetic edit. 2e-1
is not built yet, so sorting names (recursively) now costs nothing. P14 needs the same
change.

### 10. `(not re-rendered)` is printed only on changed rows — contract mismatch

Reproduction (`t12.R` W2): a stale ledger (header `files` with a wrong hash) with one
changed, one added and one removed entry. Actual: only the `~` line carries
`(not re-rendered)`; the `+` and `-` lines do not, although `$entries$stale` is `TRUE` on all
three. Expected (C14 location format; C12 "every entry of a stale ledger … listed entries
carry `stale = TRUE`"): the mark on every listed entry of a stale ledger.
Likely cause: `print.weft_changes()`, line 636, `&& r$change == "changed"`.

### 11. A store that exists but cannot be read makes every target "not in the store" — contract mismatch

Reproduction (`t7.R`): a real `targets` pipeline, a header with `fit` and `obs` hashes, then
delete `_targets/meta/meta`. Actual: stale, with three reasons ``target `fit` is not in the
store`` and the like. Expected: by T30's reasoning (an unknown state is a note, not stale)
a note `the store _targets could not be read; the pipeline was not checked`.
Likely cause: `ledger_state()`. `tar_meta()` errors, `m` is `NULL`, and every name falls
through to "not in the store". A missing directory, a changed target, and a target made after
a script change were all reported correctly.

### 12. "Not re-rendered" and "New conditions" lines omit the output — wording

Reproduction (`t6.R` "two outputs"): `a.qmd` rendered to `site-a` and `site-b`, both
stale, each with a condition. Actual:
```
Not re-rendered
  a.qmd: 1 entry; a.qmd changed
  a.qmd: 2 entries; a.qmd changed

New conditions
  ! a.qmd  chunk fit  warning: Other warning.
  ! a.qmd  chunk fit  warning: Model failed to converge.
```
Expected: the reader can tell which output each line is about, as `entry_location()` and
the "Ledgers" lines (`a.qmd (site-a)`) already do. C14's example shows no output because it
has one output per source. Add ` (<output>)` when the output is not the base name.

### 13. A ledger at `since` that is in a newer format prints every current entry one by one — wording

Reproduction (`t10.R` U2): commit a ledger whose header says `"version":2`, then write the
same entries as version 1. Actual: the ledger is `unreadable`, with a note naming the
version (right, C4). Every entry is also listed under "Added" with its sentence, so a book
compared against a commit from a newer weft lists every value it has. Expected: as T21
argues for a new ledger, a count rather than every line. The same applies to an `unreadable`
ledger that exists on one side only, because `in_whole` keys on the statuses
`new`/`deleted` only.

### 14. `files = "./a.qmd"` is rejected — wording

Reproduction (`t8.R` G1): `changes(path = d, files = "./ch 1/donnees.qmd")` gives
`` `files`: no ledger on either side for `./ch 1/donnees.qmd` ``, while `"ch 1/donnees.qmd"`
works. Expected: a path relative to the root, written either way, is accepted. Strip a
leading `./`, or normalise against the root.

## The implementer's calls

- `[claim word "x"]` only on changed rows with no structural reason: **agree**. It matches
  the example, and a structural reason already outranks it.
- `claim_word` filled for every row where a word is found: **agree**. It is cheap, and
  stage 3 will want it on added rows.
- "n ledgers compared" counts `compared` and `renamed`: **agree**.
- A compared ledger carrying a note is not "nothing": **agree**. A note such as "targets is
  not installed" must not hide behind "no changes".
- Third-state notes appended to the ledger's row in `ledgers`: **agree**. They print under
  "Ledgers", where they are seen.
- `failed` kept as the hidden attribute `failed_after`: **agree**, with a caveat. Any
  subsetting drops it and the print falls back to `(failed: ?)`, which is safe. A visible
  `failed_after` column would be sturdier if C13 can take it.
- Structural rows ordered by first reason, then `rel` descending, then ledger path, then key:
  **agree**. It is consistent with the rest of C9 (checked in `t10.R` U5).
- An unreadable ledger read leniently and compared on what it yields: **agree** for C4, with
  one note. A conflicted file keeps the first of each duplicated key ("ours"), so the other
  branch's value is silently dropped (`t10.R` U1). The `unreadable` note is the safeguard,
  and it names the line.
- Rename pairing only between ledgers with equal output names, each used once: **disagree in
  effect**. It follows C5 literally, but C5 never fires for a single-output document, and the
  old ledger is never a candidate while it is still on disk. See finding 1.

## Tried and held

- Keys and changes: a paragraph inserted above (no row); a value moved to another section
  (removed plus added, 7.1.8); an `{#id}` entry moved to another section (no row); `null`
  against `""` (changed); the same text with a different arm, for `if` with two identical
  arms (`arm true -> false`) and for kind `value`; a raw-only change (no row); failed
  after (`arm always -> none`, `after: (failed: failed claim)`) and failed before
  (`arm none -> always`); `1500 m` against `1490 m`, both printing `1.5 km` (no row);
  `950 m` → `1.2 km` (changed, raw in metres, no false magnitude); a literal `é` against
  `é` in the JSON (no change); a CRLF working-tree ledger (no change).
- C8: `-2 → 3` sign flip; `-2 → 0` crosses 0 only; `0 → 0` with new text (no reason);
  `9.9 → 10.1` and `0.99 → 1.01` (none); `1.1 → 11` and `5 → 0.5` (order of magnitude);
  raw `null` on one side (no reason, ranked last); `-0.5 → -2` (none); the order of
  multiple reasons (`sign flip, crosses 1.0`); dictionary thresholds with `dict.yml` changed
  between the commits (`if` arm and `crosses dict$limit` from a sentence neighbour, real
  knit); a `year` threshold; claim words "ball" (no), "Most" capitalised at sentence start
  (yes), "all-time" (yes, "all").
- Git: a project in a subfolder of the repository, with spaces and a non-ASCII character in
  the folder path; `since` as `HEAD`, `HEAD~2`, a tag, a branch, a 10-character hash and
  `HEAD@{1}` (all right); `nosuch`, `HEAD~9`, `HEAD:dict.yml`, `v1^{tree}` and `--all` (all
  `weft_changes_error`); no commit with `HEAD` (everything new, "(no commit yet)") and with
  `main` (error); a detached HEAD; a shallow clone (`HEAD` works; `HEAD~1` "is not a
  commit"); a linked worktree; a project that is a submodule; `_weft/` git-ignored
  (everything is always `new`, see question C); `PATH` cleared (`git is not on the path`);
  outside a work tree (error); `path` naming a file; `since` of length 2 (error);
  staged-but-uncommitted ledgers (the working tree is read, as C3 says).
- Writes nothing: 50 ledgers. A snapshot of every file, `.git` included (size and mtime),
  and `git status --porcelain` were identical before and after. A logging `git` wrapper saw
  only `rev-parse` (2), `ls-tree` (1) and `show` (101: ledger, condition log and `dict.yml`).
  The only write is a temporary copy of the committed `dict.yml` in R's session `tempdir()`
  (`dict_numbers()`), outside the project.
- Third state: the source edited; a child file edited and then restored; a definition-only
  change (not stale); the value changed; the key removed; `dict.yml` deleted (`dict.yml is
  gone`, once); broken YAML and a problem in another key (note, not stale); a CRLF checkout
  of the source (not stale); `null` hashes (`changed` / `is gone`); headers without 2e
  fields (not stale, no note); a real `targets` store: fresh, script edited but not made
  (not stale, T31), made (`fit` and `obs` changed), store moved away (note), and a `null`
  target absent from the store.
- The printed report and the object: no changes (exact one-liner); one change; 1,000 changes
  across 50 ledgers (3,057 lines, sections in C14 order); a whole new chapter (count only);
  the print is deterministic (two prints identical) and the object identical on two calls;
  the column classes of all five tables are the same empty and non-empty. Nothing depends on
  the console width (lines are not wrapped; long sentences print as stored).
- Speed: 50 ledgers × 200 entries, 1,000 changed, take 1.7 s (warm) to 5.6 s (first call),
  with 104 `git` processes, two per ledger at the commit. Most of the time is in
  `read_side()`/`read_ledger()`. This is acceptable now; see question G.

## Questions for the author

A. **A renamed heading turns every value in the section into removed plus added**, so a sign
   flip there is not ranked (`t10.R` U7: `## Results` → `## Results for 2024` with
   `v` going -3 → 3 gives only `+`/`-` lines). This is 7.1.4 working as written.
   *Recommendation:* a second pass like C5's. When a section anchor exists only then and
   another only now, pair the removed and added entries with equal (`file`, `kind`, `expr`,
   `occ`), and report them as changed, with "(section renamed from #results)".

B. **Touching 0 or 1.0 counts as crossing.** `1 → 1.2` is `crosses 1.0`, and a count going
   `1 → 2` gets `crosses 1.0` beside its arm reason, because `sign(0) != sign(0.2)`.
   *Recommendation:* make "crosses 1.0" strict (`(b - 1) * (a - 1) < 0`), and leave
   "crosses 0" as defined, since 0 is its own case.

C. **`_weft/` git-ignored** makes every ledger permanently `new`, with no hint.
   *Recommendation:* one note under "Ledgers" when `git check-ignore -q` matches the ledger
   folder. It is read-only, so C2's list of commands would gain one.

D. **An orphan ledger (source gone) is also stale** (`a.qmd is gone`) once 2e-1 writes
   `files` (`t12.R` W1), so it is listed twice and will fail `verify()` at tier 1 until the
   folder is deleted. *Recommendation:* keep the `source gone` note only and skip the third
   state for that ledger. If failing `verify()` is wanted, say so in C11.

E. **Claim words are English only**, so a German or French chapter gets no claim-word ranking
   (`Alle 3 stiegen` gives no claim word). *Recommendation:* document this in C9 until stage 3,
   or skip the claim tier when the project's `lang` is not English, so that the ranking does not
   pretend.

F. **The claim-word list includes very common words** (`no`, `one`, `first`, `more`, `less`,
   `above`, `below`), so most sentences carry one and the tier separates little.
   *Recommendation:* leave it for stage 3's lexicon, but note in T26 that the interim list is
   broad.

G. **One `git show` per ledger and per condition log**, even when the log does not exist.
   *Recommendation:* if books pass about 100 chapters, read all the blobs through one
   `git cat-file --batch` process. Nothing is needed now.
