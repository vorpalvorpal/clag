# Where the time goes in `lints()` and `gate()` on a long report

Measured 14 Nov 2026 on weft `main` at 647c3dc, which includes the `gmatch()` speed fix. Input: a 21-document book, 2.4 MB of
source in total (largest document 240 KB, 3,960 lines, 44 chunks of which 6 have caption options), most documents holding
some non-ASCII characters. Machine: a laptop shared with other jobs. Profiles: `Rprof(interval = 0.01, line.profiling = TRUE)`
on `pkgload::load_all()`. No file under `R/`, `inst/` or `tests/` was changed; the patched figures below come from a
function swapped in at run time.

## Current timings (CPU seconds, two runs)

| call | run 1 | run 2 |
| --- | --- | --- |
| `lints(files = <one document>)` | 36.5 | 39.0 |
| `lints()` on all documents | 42.6 | 48.5 |
| `label_seed()` | 31.8 | 35.5 |
| `lints(files = one, rules = "numeral")` | 0.5 | |
| `lints(rules = "xref")` | 33 | |
| `gate()`, cold cache, one staged edit | 53.8 | |
| `gate()`, warm | 0.3 | |

The trial's figures (36 s, 43 s, 32 s, 45 s) still hold: the `gmatch()` fix did not touch this. Spread between runs is about
10 percent, so differences smaller than that are noise.

## Why one file costs almost as much as the book

`lints(files = )` only narrows what is reported. Tier 1 contains project-scope rules (`xref`, `anchor-twice`, `config-place`,
`engine`). Each calls `project_index()` (R/lint-doc.R:289), which calls `ctx$source()` for every document, and that is
`read_source()` (R/lint-source.R:~990-1100): a full scan of the document. In the one-file profile, `project_index` is 94
percent of the time (30.5 of 32.5 s profiled); the reporting of the one file is under 2 s. With only file-scope rules
(`rules = "numeral"`) the index is never built and the call takes 0.5 s, so the project index is already skipped when no
project rule is selected. `label_seed()` (R/lint-prose.R:330) has no rules at all: it is `lint_open()` on every document, so
its 32 s is purely the read.

Cross-references genuinely need every document's anchors, so the work is needed for tier 1 as it stands. What is not needed
is doing it again on every call.

## Caches that exist

- `ctx$source` and `lint_cache(ctx)` (R/lint.R:369, R/lint-doc.R:25): per-call only, lost when `lints()` returns.
- The gate cache (R/gate-cache.R, `<git common dir>/weft/cache`): layers `src` (the whole `weft_source` object), `file`
  (findings per document) and `proj`, keyed by git blob and configuration hashes. It reaches the lints through
  `weft_env$lint_reader` (R/gate.R:197, set at R/gate.R:280). That is why a warm `gate()` is 0.3 s. `lints()` never sets
  `lint_reader`, so it gets nothing from it. A cold `gate()` is one full read of every document (53.8 s: 45 s in `lints()`,
  32 s of that in `read_source`).

## Hot spots, ranked

Percentages are of the one-file `lints()` profile (32.5 s profiled).

1. **Blank-line search in `new_scan()`, R/scan.R:55.** `gregexpr("\n[ \t\r]*(?=\n)", text, perl = TRUE)`: 14.0 s self, 43
   percent (about 50 percent of `label_seed`, 35 percent of the cold gate). Why: on a non-ASCII string, R's `gregexpr` with
   `perl = TRUE` converts each match offset to a character index by walking the string, so cost is matches times length.
   It is reached from `scan_chunk_captions` (R/scan-contexts.R:538): for every chunk with caption options the whole document
   is rebuilt with every other line blanked and scanned, so each of those texts has one match per line (about 3,960) and is
   240 KB. Per call: 1.3 s on a masked document that contains any non-ASCII character, 0.1 s when it is pure ASCII, which
   is why the test documents (ASCII) never show it. Fix: take the blank lines from the line cut that `find_fences()` already
   makes, instead of a regex, i.e. `L <- cut_lines(text, length(S$nl) + 1L); k <- which(grepl("^[ \t\r]*$", L)); k <- k[k >= 2L & k <= length(S$nl)]; bl <- S$nl[k - 1L]`
   (the old `bl` values are the offsets of the newline that ends the line before each blank, non-overlapping, so this is the
   same set), or `useBytes = TRUE` with the existing byte-to-character map. Risk: low; the output feeds only `S$plim`.
   Checked: `scan_document()` output `identical()` for all 21 documents, and `lints()` one-file and whole-book findings
   `identical()`. Guards: tests/testthat/test-scan.R, test-scan-contexts.R, test-lint-scale.R and test-lint-perf.R cover
   the scan but none uses non-ASCII text with many blank lines, so add one test (a masked non-ASCII document of a few
   thousand lines must scan in under a second). Expected: one-file 36.5 to about 19.4 s CPU (21.9 in the second run),
   whole book 42.6 to 25.7 (33.4), `label_seed` 31.8 to 15.4 (17.3), cold gate 53.8 to 29.5 s.
2. **Rescanning the whole document per caption chunk, R/scan-contexts.R:538 with `mask_lines` R/scan-contexts.R:121.** After
   fix 1 this is still 3.5 s (20 percent of the remainder, 1 s in `mask_lines`). Smallest change: scan only the lines of the
   chunk's caption regions and shift offsets, or batch every chunk's regions into one masked text. Risk: medium (offset
   arithmetic at R/scan-contexts.R:545-560; guarded by test-scan-contexts.R). Expected: about 3 s more.
3. **`mask_prose()` called from `read_source` (R/lint-source.R:1046): 4.8 s, 27 percent after fix 1.** Of it, `cur()`
   (`paste(chars, collapse = "")`, R/lint-source.R:560) is 1.65 s, `blank()` (line 59) 0.9 s. Repeated string rebuilds of a
   240 KB text; cache `work` between uses. Risk: medium; guarded by the lint tests. Expected: about 2 s more.
4. **`doc_auto_ids` / `heading_anchors` (R/ledger.R:227-265): 1.8 s** (a per-line `regmatches(regexec())` loop; vectorise)
   and **`bibtex_keys` (R/cite.R:9-28): 0.8 s** (a per-character loop). Low risk, about 2 s more together.
5. **Cross-call cache of read sources, in the session and on disk.** Make `lints()` use `weft_env$lint_reader` with a
   session environment keyed by path, size, mtime and the merged configuration (or the content hash, as the gate does).
   A second `lints()` call on the same book would skip all 14 to 18 s of reading and fall to about 2 s. It is the only
   change that helps a repeated call, but staleness (edits within one mtime tick, configuration changes, `_weft.yml`
   edits) is a correctness risk; hash content to be safe. Guards: test-gate-cache.R and test-gate-perf.R for the keying;
   a new test for invalidation would be needed. Judge it as optional until fix 1 has been seen to be enough.

## Expected totals

After fix 1 alone: one file about 20 s, whole book about 26 s, cold gate about 30 s. After fixes 1 to 4: roughly 10 to 12 s
for one file, whole book similar (the read is the whole cost either way). After 5, repeat calls in a session about 2 s.
What remains after 1 to 4 is inherent to a character-by-character scanner in R, about 0.5 s per document.
Fix 1 is clear and low risk; 4 is low risk; 2, 3 and 5 are not worth doing before fix 1 is measured by the owner.
