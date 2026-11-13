# weft on a long report: the trial

A trial of weft (HEAD e76f84d, installed into a private library) on copies of one long
computational report, following the survey in `hw-comparison.md`. The project was read only;
all work was on copies under `dev/trials/hw2/` (not committed). This note names no data
values, people, places or manuscript text.

## What was run

- **Small chapter** (about 1,250 lines, 150 inline values, 8 `stopifnot` guards, 19 reads of a
  `targets` store through a wrapper, one question list with pinned numbers). Converted by hand to
  about 100 constructs: 82 formatted values, 9 spans, 2 `claim()`, 4 `ci()`, 1 `about()`, 10
  dictionary reads, 1 named value. Rendered with weft active and compared with stock.
- **Synthesis chapter** (about 2,570 lines, 27 guards, 43 store reads). It could not be
  knitted (below), so a cut-down document holds the reads that go through the store and four
  converted paragraphs. Value-to-word rules became a `breaks` dictionary entry.
- **Throwaway git repository** around both: commit gate through the installed hook, `changes()`,
  `verify(files=)`, `status()`, `rehearse()`.
- **Static pass** over copies of all 21 sources (index, 19 chapters, appendix): `lints()` by
  rule, `label_seed()`, `dict_seed()`, `use_setup()`, `verify(static = TRUE)`, `gate()` timings.

**Could not be done.** Neither chapter knits from sources plus the store. Both read derived-data
files outside the store, which the trial may not copy. The small chapter needed a one-line shim
(the same table is also a store target). The synthesis chapter reads several such files, hence
the cut-down document. The chapter that writes into the project's derived-data folder was not
touched. A "not re-rendered" report could not be provoked, because that needs a changed store.

## What worked

- Unconverted chapter under weft: text identical to stock (0-line diff), +1.2 s on 8.9 s.
- Converted chapter: text differs from stock only as intended (true minus sign, small counts as
  words, the percentage rule reproduced by `.pct digits="0"` / `sigfig="2"`, a spelled fraction
  from `about()`, a lost explicit plus). +2.1 to +3.8 s.
- `ci()` refused nothing here but checks the estimate against its interval; `if` guards and
  `sign` spans replaced direction words and their `stopifnot`s; all prose failures arrive in one
  report quoting each sentence.
- A `breaks` entry replaces a gloss rule copied into three files; one edited phrase shows in
  `changes()` as the one sentence it changed.
- The store wrapper with `store = <global>` (even a dotted name) is recorded and resolved.
- Condition log catches every warning and message under `warning: false`; a project
  `severity:` pattern for model convergence fails the render as documented.
- Commit gate: first commit of an adopted project passes by design; a new typed number is refused
  with line and rule in about 1.2 s; a clean commit with its ledger passes in about 1.1 s.
- Both ways of making question-list text computable (a `weft_str()` over the asis text, or a
  named value) give identical text. `weft_str()` in a table-helper caption works.
- Ledger: 163 entries, 75 KB for the small chapter, with 18 logged conditions.

## Friction

1. **Reads weft cannot see.** `dl_attach(store = <parameter>)` and a name-computing helper
   (`read_shared`) are recorded under the default store resolved against the document folder, with
   no hash. The biggest dependencies (whole data layer, shared artefacts) are exactly the ones
   missed, and every ledger prints "the store ... does not exist; the pipeline was not checked".
   Files `source()`d through `here::here()` are also absent from the ledger header.
2. **Explicit plus sign.** Hit four times in the small chapter. `ci()` drops it; the workaround is
   a two-arm `sign` span with the sign typed in each arm (works, three arms needed to cover zero).
   `ci()` also cannot print percentages, so percent intervals stay as separate values.
3. **Lint cost.** One-file `lints(files=)` takes 36 s because project-scope rules re-read all
   sources; the gate is cached (5.6 s warm) but its first run is about 45 s.
4. The targets-reading, data-reading chapter setups cannot be knitted without the data, so a
   weft trial of a whole chapter needs the owner's data or a shim.
5. `.p` has no `digits`; with `digits=` it is a (clear) construct error.

## Bugs (each with a generic reproduction)

- **verify tier-2 flood** (`R/verify.R`, tier-2 filter `if (is.null(base)) TRUE`): in a repository
  whose baseline commit does not hold `_weft.yml`, `verify(static = TRUE)` says "nothing counts as
  added" yet lists every tier-2 finding (4,300 lines on 21 files). Reproduce: commit documents,
  leave `_weft.yml` uncommitted, run `verify(static = TRUE)`.
- **Unresolved store** (`R/targets.R`, reader/wrapper store handling and default-store
  resolution): a function `read(name, store = here::here("_targets"))` that calls
  `tar_read_raw(name, store = store)` is "unresolved" although its default is evaluable.
- **`source()` through `here::here()`** is not tracked as a file input (`R/targets.R` ledger header).
- `print()` of a lint table with its `hint` column dropped fails with "argument is of length zero".

## Lint noise on the whole book (copy, recipe settings applied)

| rule | findings | sample of 10 | false-positive pattern |
|---|---|---|---|
| `numeral` | 1,614 | 10 true by rule | none; 27% are typed "chapter N" references, 15% percentages, most of the rest stipulated thresholds and design values; a few are quoted standards needing `cite` |
| `xref` | 267 | 0 true | all 267 are `@tbl-` ids made by the table helper's `id=` argument; 0 findings for sections or figures |
| `claim-word` | 2,719 (one per sentence) | 2 true | idioms ("either way", "each", "nothing else"), compounds ("whole-record"), instructions and rhetoric |
| `value-constant` | 520 | 3 true | indices and selectors (`x[2, 3]`, a grid size, a column number); about half sit inside brackets |
| `value-format` | 223 | 10 true by rule | `round()` of counts and date `format()` are harmless; `sprintf()` skips the zero rule |
| `section-anchor` | 144 | 10 true | true, low value until the ledger needs stable keys |
| `anchor-unused` | 35 | 10 true | figures never referenced (maybe by design) |
| `chunk-label` | 11 | 10 true | one pattern: the unlabelled asis chunk |
| `figure` | 2 | probably true | options placed after comment lines in the chunk (Quarto reads them only at the top; unverified) |

`dict_seed()` found 4 label vectors, none of the typed constants the survey named.

## Timings (wall, 8 GB laptop)

| step | time |
|---|---|
| install from source | 9.5 s |
| `use_weft()`, `use_setup()` on 21 files | 1.0 s, 0.2 s |
| small chapter: stock / unconverted under weft / converted | 8.9 s / 10.1 s / 11.0-12.7 s |
| `lints()` tier 1 / tier 1+2, whole book | 42.9 s / 44.9 s |
| `label_seed()` / `dict_seed()` | 31.9 s / 0.8 s |
| `verify(static = TRUE)` | 44.6 s |
| `verify(files = one chapter)`, incl. its render | 18.6 s |
| `gate()` cold / warm big chapter / small chapter / nothing staged | 46 s / 5.6 s / 3.5 s / 0.1 s |
| `changes()` | 3.3 s |
| `rehearse()`, one case | 3.3 s |

## Verdicts on the survey's candidate improvements

- **1 bare `NA` / `NaN` / `Inf` warned check: confirmed, more pressing.** Bare `NA` prints "NA"
  and a bare `Inf` prints nothing at all (stock Quarto does the same); weft reports neither. Bare
  values are already in the ledger (70 of 163 entries).
- **2 `xref` learns helper-made anchors: confirmed, most pressing.** 100% of the rule's findings.
- **3 explicit plus and a short `ci()`: confirmed.** Hit repeatedly; add percent output too.
- **4 `.p` digits and label: partly hit.** The error is clear; the chapter had no p-values, so
  the house-style need was not shown.
- **5 convergence severity: confirmed as a documentation gap only.** The mechanism works. Five of 184
  store targets carry convergence warnings, none in the read sets tried, so the store-condition
  route was not exercised.
- **6 freeze with changed inputs: not hit.**
- **7 adoption recipe: confirmed, and larger than listed.** It must also cover the wrapper
  patterns weft can and cannot resolve, `.Rprofile` versus front-matter activation, and the lint
  settings that cut `numeral` from 2,174 to 1,614.
- **A claims in chunks: confirmed, moderate.** The first failing chunk claim stops the chunk. Of
  about 20 guards examined, about half were wording guards that moved into prose; the rest are
  structural tripwires that stay.
- **B forward references: not hit** in these chapters; one binding chunk added before the prose
  sufficed, so no definition moved. Index chapter untested.
- **C tables in the ledger: confirmed.** The ledger saw none of the six tables.
- **D rendered-output layer: confirmed.** A literal "?@sec-..." from an unresolved reference
  rendered without any weft report (Quarto only warns in its log).
- **E decision pointers: not hit.** **F typed-but-checked text: confirmed**, document the two
  routes. **G range type: mildly hit** ("a-b" pairs built from two dictionary numbers).
- Missed by the survey: the unrecorded reads above; chapters needing derived data outside the
  store; `lints(files=)` is not cheaper than the whole project.

## Further improvements, by value to a real project

1. `xref` anchor-helper setting (win 2).
2. Resolve reader stores from the formal default; track `here::here()` sources; let a project
   declare name-computing readers (so the not-re-rendered check covers the data layer).
3. Bare missing-value check and an unresolved-reference check in `weft-check`.
4. Explicit plus, percent and a short form for `ci()`.
5. Fix the tier-2 flood when the baseline predates `_weft.yml`.
6. A cached or file-scoped `lints(files=)` and a faster `label_seed()`.
7. Table digests in the ledger; a documented adoption recipe.
8. Quieter `claim-word` (skip idioms and compounds, or default it off).
