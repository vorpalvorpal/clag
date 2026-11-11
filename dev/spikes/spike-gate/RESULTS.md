# spike-gate: results

Throwaway spike for the `weft` gate design. Everything is under
`/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-gate/`
(call it `$G` below; paths in this file are relative to it). Nothing outside this directory was modified.

Machine: Apple M2, 8 cores, 8 GB, macOS 26.5.1, R 4.4.3, quarto 1.11.9, Pandoc 3.10 (the one inside Quarto), git 2.50.1.
**The machine was NOT idle.** Other sessions were running R and pwsh; the 1-minute load average was 5 to 11 on 8
cores for most of the timing (it is printed per measurement as `[load1 a->b]` in `out/timing-*.txt`). Treat the
timings as upper bounds with roughly +/-20% scatter (min and max are given where they matter). Two full timing runs exist; where
they differ both are quoted ("run 1" is from my console output, its files were overwritten by run 2, which has the
load figures).

---------------------------------------------------------------------------------------------------

## (i) What I ran and saw

### Part 1. The paragraph matcher

**What was built** (all R, throwaway):

| file | what |
|---|---|
| `lib.R` | scanner wrapper over the stand-in `clag_parse()` (`spike-grammar2/setup.R`, sourced unchanged); line-based unit extraction; LCS alignment; the matcher `match_versions()`; the no-matching baseline; scoring helpers |
| `manuscript.R` | structured test manuscript, renderer, edit helpers |
| `edits.R` | 72 scripted edits, each with a hand-written correct answer |
| `run.R`, `summarise.R`, `make-table.R` | run all edits, tabulate |
| `pandoc-check.R`, `out/pandoc-probes/` | cross-check of my block splitting against Pandoc `commonmark_x+sourcepos` |

**Test manuscript** (`out/manuscript.qmd`, stats in `out/manuscript-stats.txt`): 10 anchored sections (`{#sec-...}`),
71 plain paragraphs (93 units counting headings, list items, table rows, chunks and a footnote definition),
156 constructs (119 values without `#id`, 2 values with `#id`, 35 governed spans: `n`, `if`, `sign`), 114 distinct
identities, 8 identities repeated (`n_sites` 18 times, `n_events` 10 plus its `n=` span 10, `mean(depth)` 3, ...).
Constructs sit in: ordinary paragraphs (144, including a block quote, a div and an inline footnote), a heading (1), list items (3), pipe-table cells (4 incl. a caption line),
an inline footnote and a footnote definition, `#| fig-cap:` chunk options (3), a block quote, and a div. Two identical
adjacent boilerplate paragraphs are included on purpose.

**How the matcher works (as implemented)**
1. Split the file into units (paragraph = blank-line-delimited block; each list item, table row, heading, footnote definition is its own unit; a chunk's `#|` option lines are one unit; block-quote markers are stripped; div fences and non-executable fences are skipped).
2. Section = the unit sequence under a heading that has `{#sec-...}`; sections are matched by anchor.
3. Within a section: LCS over whitespace-normalised paragraph text; identical paragraphs anchor; a gap with exactly one unit on each side is "the same paragraph" (the proposal). Anything else in a gap is unmatched.
4. A matched changed pair: multiset-difference the identities; removed and added identities in the pair are paired as edits (nearest identity string, same kind preferred); leftovers are candidates.
5. Candidates from unmatched paragraphs and pair leftovers are netted file-wide: a candidate removal with a candidate addition of the same identity elsewhere is "moved"; the rest are "removed" / "added".
Identity: `#id` if present, else `v:<deparsed expression>|<sorted classes>`, else `g:<key>=<deparsed key value>`.

**Scoring.** 72 edits. "Correct answer" is written by hand per the rules as stated (count rule, rule 6.2.2). Comparison is on the
multiset of (status, identity[, after-identity]) for `removed`, `added`, `edited`; `moved` and `unchanged` are collapsed
(so "moved" accuracy is not scored separately). A **false removal** = a removal event reported that the
correct answer does not contain. A **missed removal** = a removal in the correct answer that the matcher did not report.
The per-edit log with the missed-removal mechanism is `out/per-edit.txt`; raw rows `out/results.csv`.

**Totals** (`out/summary.txt`; `E16b` is a special case, see below, so the second block excludes it):

| variant | exactly correct | edits with a false removal | false-removal events | edits with a missed removal | missed-removal events | acknowledgements demanded |
|---|---|---|---|---|---|---|
| **proposal** (gap pairs only when 1 unit each side) | 61 / 72 | 8 | 11 | 3 | **34** (3 without E16b) | 75 (74) |
| variant A: equal-size gaps pair positionally | 62 / 72 | 6 | 7 | 4 | 37 (6 without E16b) | 68 (67) |
| proposal + "verify": identical text but different constructs counts as changed | 62 / 72 | 8 | 11 | 2 | 3 | n/a |
| variant B: pair by word-set similarity (gap >= 0.5, then file-wide >= 0.6), + verify | 71 / 72 | 0 | 0 | 1 | 2 | 96 |
| **no paragraph matching** (every falling count is a removal) | n/a | 35 | 41 | 0 | 0 | **139** (107) |
| correct answers | | | | | | 98 (66) |

Excluding E16b (71 edits): proposal 61 correct, 11 false removals in 8 edits, 3 missed removals in 2 edits;
no-matching baseline demands 107 acknowledgements against 66 needed.

**Extra acknowledgements from no matching: +41 over the 72 edits** (107 vs 66 excluding E16b; 139 vs 98 including it; the 41 is the same
because the baseline cannot miss a falling count). They fall on 35 of the 72 edits, i.e. nearly every edit that changes an
expression, an id, a formatter class, or a key value. The proposed matcher cuts that to +11 false removals (30 of the 41
extra acknowledgements avoided) at the price of 3 missed removals (+31 in E16b).
The edit set is weighted towards cases that I expected to be hard; these are counts on 72 scripted edits, not rates in real use.

**Error directions and mechanisms (proposal)**

False removals (11 events, 8 edits), all because the gap is not exactly 1:1, or the paragraph moved sections:
- E21, E27: two adjacent edited paragraphs (gap 2:2). Variant A fixes these.
- E09: insert a paragraph between two edited ones (2 vs 3). E26: split + adjacent edit (2 vs 3). E49: insert directly above an edited paragraph (1 vs 2). E48: edit next to a deleted paragraph (2 vs 1). Not fixed by A.
- E51: rename an anchor and edit in that section: the section no longer pairs by anchor, so its whole content is unmatched.
- E52: move a paragraph to another section and edit it.
This is the "fails towards reporting" direction and by design cheap-ish, but the first four are probably the commonest things an author does to a draft.

**Missed removals (the serious direction).** The matcher produced these; I did not infer any:
1. **E47, E70 (and E69 under variant A): position pairing absorbs a delete+insert.** If an author deletes a paragraph and inserts a different one in the same place between the same unchanged neighbours, the gap is 1:1, so the two are "the same paragraph"; the removed construct is paired with whatever was added and reported as an edit. E47: `n_raw` deleted, unrelated `n_archive` added, reported `edited n_raw -> n_archive`. Nothing is needed from the author. E70 is the same with templated prose (a generated results sentence swapped for the same template with another topic): variant B (similarity) also misses it, because templated sentences share most of their words. Variant A (equal-size gaps) widens the hole: E69 (three paragraphs replaced by three unrelated ones) is correctly handled by the proposal (3:3 does not pair) but missed by A.
2. **E16b: alignment by normalised text ignores constructs that changed without a word changing.** A reflow with plain `strwrap` at width 55 changes 32 constructs: the line breaks land right after `` `r `` (knitr's inline pattern is `` `r `` + space or `#`; a newline is not a space, so the code is no longer inline R), and `# ` and `> ` land at line starts (Pandoc reads a `# ` line as a heading and a `> ` line as a block quote; probes in `out/pandoc-probes.txt`). Every affected paragraph has identical normalised text, so the matcher treats it as unchanged and never compares its constructs: 31 silent removals, one (the span broken by the `# ` heading) caught. The count-only baseline catches all 32. With "verify" (compare identities even when text is identical) the matcher catches all of them. Note the corrected rule is mine, not part of the proposal.

Not counted as missed removals, but real blind spots that the *rules* (not the matcher) create; the matcher agrees with the rules on all three:
- **E24**: the same identity removed from one paragraph and added in another in the same file is "moved", so nothing is reported even though a guard on the first sentence is gone. (Also true for a move across sections.)
- **E57**: changing the expression of a construct that has an `#id` (`depth_max` -> `depth_max * 0.5` under `{#dmax}`) changes nothing: identity is the id. Not even an edit is reported.
- **E61**: removed `n_published` and an unrelated `n_budget` added in the same paragraph is an edit by rule 6.2.2. The report shows a pairing, but no check is flagged as removed.

**Per-edit table (72 edits).** Columns: correct answer, matcher result (proposal), error direction, equal-gap variant, +verify variant, acknowledgements the no-matching baseline would demand (correct answer in brackets). `R`=removed, `A`=added, `E[a -> b]`=edited; `|num` suffixes are trimmed; `+N more` means the list was truncated (full lists in `out/per-edit.txt`, `out/results.csv`). "fr" = false removals, "mr" = missed removals. Everything the 72 edits do is in `edits.R`; each edited document is in `out/edits/Exx.qmd` (E16c was merged into E16b).

| id | edit | correct answer | matcher (proposal) | error direction | equal-gap variant | +verify | no-matching acks (truth) |
|---|---|---|---|---|---|---|---|
| E01 | loosen one check's bound (. > 10 -> . > 5) | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)] | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)] | ok | ok | ok | 1 (0) |
| E02 | mean(depth) -> median(depth) | E[mean(depth) -> median(depth)] | E[mean(depth) -> median(depth)] | ok | ok | ok | 1 (0) |
| E03 | computed value -> literal construct `r 812`{.num} | E[mean(rain) -> 812] | E[mean(rain) -> 812] | ok | ok | ok | 1 (0) |
| E04 | computed value -> plain-prose number (construct gone) | R[mean(rain)] | R[mean(rain)] | ok | ok | ok | 1 (1) |
| E05 | delete a construct, reword the sentence around it | R[start_year] | R[start_year] | ok | ok | ok | 1 (1) |
| E06 | delete a whole paragraph (2 constructs) | R[n_old_surveys], R[old_mean] | R[n_old_surveys], R[old_mean] | ok | ok | ok | 2 (2) |
| E07 | delete a whole section (sec-limits) | R[g:if=err_large], R[g:n=drop_zonal], R[g:n=n_events], R[g:sign=trend_aquitard], +8 more | R[g:if=err_large], R[g:n=drop_zonal], R[g:n=n_events], R[g:sign=trend_aquitard], +8 more | ok | ok | ok | 12 (12) |
| E08 | insert a paragraph above the first paragraph of a section | A[n_new_q] | A[n_new_q] | ok | ok | ok | 0 (0) |
| E09 | insert a paragraph between two edited ones (M1 bound, M2 mean->median) | A[n_checkers], E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], E[mean(level) -> median(level)] | A[claim(n_sites, . > 5)], A[median(level)], A[n_checkers], R[claim(n_sites, . > 10)], +1 more | false removal | false (fr 2, mr 0) | false (fr 2, mr 0) | 2 (0) |
| E10 | split a paragraph in two (no construct lost) | - | - | ok | ok | ok | 0 (0) |
| E11 | merge two paragraphs (no construct lost) | - | - | ok | ok | ok | 0 (0) |
| E12 | move a paragraph within its section | - | - | ok | ok | ok | 0 (0) |
| E13 | move a paragraph to another section (unchanged) | - | - | ok | ok | ok | 0 (0) |
| E14 | move a section (sec-limits after sec-concl) | - | - | ok | ok | ok | 0 (0) |
| E15 | rename a section's anchor, nothing else | - | - | ok | ok | ok | 0 (0) |
| E16 | reflow line wraps only (72 -> 55) | - | - | ok | ok | ok | 0 (0) |
| E16b | reflow (55) with plain strwrap: wraps can land '# ' / '> ' at a line start and break right after `r | R[g:n=drop_nodular], R[avg_clay], R[avg_deltaic], R[avg_gneiss], +28 more | R[g:n=drop_nodular] | MISSED removal | MISSED (fr 0, mr 31) | ok | 32 (32) |
| E17 | change only arm text | - | - | ok | ok | ok | 0 (0) |
| E18 | reorder attributes, change quoting, add spaces in braces | - | - | ok | ok | ok | 0 (0) |
| E19 | add an #id to an existing construct | E[mean(depth) -> id:dmean] | E[mean(depth) -> id:dmean] | ok | ok | ok | 1 (0) |
| E20 | remove an #id from a construct | E[id:dmax -> depth_max] | E[id:dmax -> depth_max] | ok | ok | ok | 1 (0) |
| E21 | two adjacent paragraphs both edited (I2, I3) | E[mean(depth) -> median(depth)], E[mean(rain) -> median(rain)] | A[median(depth)], A[median(rain)], R[mean(depth)], R[mean(rain)] | false removal | ok | false (fr 2, mr 0) | 2 (0) |
| E22 | edit in a paragraph that also gets a sentence added | A[n_gauges], E[mean(rain) -> median(rain)] | A[n_gauges], E[mean(rain) -> median(rain)] | ok | ok | ok | 1 (0) |
| E23 | swap two constructs between non-adjacent paragraphs (I1 start_year <-> I4 old_mean) | E[old_mean -> start_year], E[start_year -> old_mean] | E[old_mean -> start_year], E[start_year -> old_mean] | ok | ok | ok | 0 (0) |
| E24 | same identity removed from one paragraph, added in another (same section) | - | - | ok | ok | ok | 0 (0) |
| E25 | COMBINED: bound loosened + delete paragraph + insert above + move section + reflow | A[n_new_q], E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], R[n_old_surveys], R[old_mean] | A[n_new_q], E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], R[n_old_surveys], R[old_mean] | ok | ok | ok | 3 (2) |
| E26 | COMBINED: split M2 + loosen M1 (adjacent) + rename sec-data anchor | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)] | A[claim(n_sites, . > 5)], R[claim(n_sites, . > 10)] | false removal | false (fr 1, mr 0) | false (fr 1, mr 0) | 1 (0) |
| E27 | COMBINED: add id (I2) + adjacent edits R1,R2 + delete sec-app-c + move M3 elsewhere | E[mean(depth) -> id:dmean], E[n_events -> n_valid_events], E[pct_pass\|pct -> pct_ok\|pct], R[g:n=drop_umber], +11 more | A[n_valid_events], A[pct_ok\|pct], E[mean(depth) -> id:dmean], R[g:n=drop_umber], +13 more | false removal | ok | false (fr 2, mr 0) | 15 (12) |
| E28 | change a span's key value (n_sites -> n_valid_sites) | E[g:n=n_sites -> g:n=n_valid_sites] | E[g:n=n_sites -> g:n=n_valid_sites] | ok | ok | ok | 1 (0) |
| E29 | change a span's `if` condition | E[g:if=drift_found -> g:if=drift_found & n_drift > 2] | E[g:if=drift_found -> g:if=drift_found & n_drift > 2] | ok | ok | ok | 1 (0) |
| E30 | delete a governed span (leave plain 'has') | R[g:n=n_programmes] | R[g:n=n_programmes] | ok | ok | ok | 1 (1) |
| E31 | delete a construct from a heading | R[n_sites] | R[n_sites] | ok | ok | ok | 1 (1) |
| E32 | edit a construct in a heading | E[n_sites -> n_valid] | E[n_sites -> n_valid] | ok | ok | ok | 1 (0) |
| E33 | edit a construct in a list item | E[n_loggers -> n_loggers_active] | E[n_loggers -> n_loggers_active] | ok | ok | ok | 1 (0) |
| E34 | delete a list item | R[duration_days] | R[duration_days] | ok | ok | ok | 1 (1) |
| E35 | edit a construct in a table cell | E[depth_a -> depth_a_adj] | E[depth_a -> depth_a_adj] | ok | ok | ok | 1 (0) |
| E36 | delete a table row | R[depth_b], R[n_b] | R[depth_b], R[n_b] | ok | ok | ok | 2 (2) |
| E37 | edit a footnote definition | E[tide_range -> tide_range_m] | E[tide_range -> tide_range_m] | ok | ok | ok | 1 (0) |
| E38 | delete a footnote definition | R[tide_range] | R[tide_range] | ok | ok | ok | 1 (1) |
| E39 | edit a chunk-option caption construct | E[n_regions -> n_zones] | E[n_regions -> n_zones] | ok | ok | ok | 1 (0) |
| E40 | remove a construct from a chunk-option caption | R[n_regions] | R[n_regions] | ok | ok | ok | 1 (1) |
| E41 | delete a whole chunk with a caption | R[n_hydro] | R[n_hydro] | ok | ok | ok | 1 (1) |
| E42 | edit a construct in a block quote | E[n_quoted -> n_quoted_total] | E[n_quoted -> n_quoted_total] | ok | ok | ok | 1 (0) |
| E43 | edit a construct inside a div | E[n_flagged -> n_flagged_total] | E[n_flagged -> n_flagged_total] | ok | ok | ok | 1 (0) |
| E44 | change a formatter class (.pct -> .num) | E[pct_pass\|pct -> pct_pass] | E[pct_pass\|pct -> pct_pass] | ok | ok | ok | 1 (0) |
| E45 | add a formatter class (.pct -> .pct .dec1) | E[n_missing\|pct -> n_missing\|dec1 pct] | E[n_missing\|pct -> n_missing\|dec1 pct] | ok | ok | ok | 1 (0) |
| E46 | edit a construct in an inline footnote | E[mean(drift) -> median(drift)] | E[mean(drift) -> median(drift)] | ok | ok | ok | 1 (0) |
| E47 | ADVERSARIAL: delete a paragraph, insert an unrelated one in its place | A[n_archive], R[n_raw] | E[n_raw -> n_archive] | MISSED removal | MISSED (fr 0, mr 1) | MISSED (fr 0, mr 1) | 1 (1) |
| E48 | edit a paragraph whose neighbour is deleted (R1 edited, R2 deleted) | E[pct_pass\|pct -> pct_ok\|pct], R[g:n=n_events], R[mean(depth)], R[n_events] | A[pct_ok\|pct], R[g:n=n_events], R[mean(depth)], R[n_events], +1 more | false removal | false (fr 1, mr 0) | false (fr 1, mr 0) | 4 (3) |
| E49 | insert a paragraph directly above an edited one (D1) | A[n_prelim], E[n_sources -> n_sources_all] | A[n_prelim], A[n_sources_all], R[n_sources] | false removal | false (fr 1, mr 0) | false (fr 1, mr 0) | 1 (0) |
| E50 | edit a heading's words, anchor and constructs unchanged | - | - | ok | ok | ok | 0 (0) |
| E51 | rename a section's anchor AND loosen a bound in it | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)] | A[claim(n_sites, . > 5)], R[claim(n_sites, . > 10)] | false removal | false (fr 1, mr 0) | false (fr 1, mr 0) | 1 (0) |
| E52 | move a paragraph to another section AND edit it | E[n_cal -> n_cal_pts] | A[n_cal_pts], R[n_cal] | false removal | false (fr 1, mr 0) | false (fr 1, mr 0) | 1 (0) |
| E53 | delete one of two identical adjacent paragraphs | R[digits] | R[digits] | ok | ok | ok | 1 (1) |
| E54 | edit the second of two identical adjacent paragraphs | E[digits -> digits_out] | E[digits -> digits_out] | ok | ok | ok | 1 (0) |
| E55 | edit the first of two identical adjacent paragraphs | E[digits -> digits_out] | E[digits -> digits_out] | ok | ok | ok | 1 (0) |
| E56 | remove one #id'd construct and reword | R[id:dprev] | R[id:dprev] | ok | ok | ok | 1 (1) |
| E57 | change the EXPRESSION of a construct that has an #id | - | - | ok | ok | ok | 0 (0) |
| E58 | rename an #id (dmax -> dmaxx) | E[id:dmax -> id:dmaxx] | E[id:dmax -> id:dmaxx] | ok | ok | ok | 1 (0) |
| E59 | drop one of many occurrences of a repeated identity (n_sites in Li1) | R[n_sites] | R[n_sites] | ok | ok | ok | 1 (1) |
| E60 | reword a paragraph wholesale, keep its constructs | - | - | ok | ok | ok | 0 (0) |
| E61 | delete one construct and add an unrelated one in the same paragraph | E[n_published -> n_budget] | E[n_published -> n_budget] | ok | ok | ok | 1 (0) |
| E62 | delete one construct and edit another in the same paragraph (M2) | E[mean(level) -> median(level)], R[sd(level)] | E[mean(level) -> median(level)], R[sd(level)] | ok | ok | ok | 2 (1) |
| E63 | no change at all | - | - | ok | ok | ok | 0 (0) |
| E64 | front matter only | - | - | ok | ok | ok | 0 (0) |
| E65 | swap two adjacent paragraphs | - | - | ok | ok | ok | 0 (0) |
| E66 | add a sentence without touching constructs | - | - | ok | ok | ok | 0 (0) |
| E67 | COMBINED: edit + delete section + add id, non-adjacent | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], E[mean(depth) -> id:dm2], R[g:n=drop_marl], R[g:n=n_events], +9 more | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], E[mean(depth) -> id:dm2], R[g:n=drop_marl], R[g:n=n_events], +9 more | ok | ok | ok | 13 (11) |
| E68 | COMBINED: bound edit, delete one repeated n_sites paragraph elsewhere, move another paragraph across sections | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], R[n_sites] | E[claim(n_sites, . > 10) -> claim(n_sites, . > 5)], R[n_sites] | ok | ok | ok | 2 (1) |
| E69 | ADVERSARIAL: replace 3 adjacent paragraphs (I2,I3,I4) by 3 new unrelated ones in the same place | A[cost_total], A[n_staff], A[n_strata], R[g:sign=delta_depth], +5 more | A[cost_total], A[n_staff], A[n_strata], R[g:sign=delta_depth], +5 more | ok | MISSED (fr 0, mr 3) | ok | 6 (6) |
| E70 | ADVERSARIAL (templated prose): replace a generated results sentence by the same template with another topic and its own constructs | A[g:n=drop_zeolite], A[drop_zeolite], R[g:n=drop_alluvial], R[drop_alluvial] | E[g:n=drop_alluvial -> g:n=drop_zeolite], E[drop_alluvial -> drop_zeolite] | MISSED removal | MISSED (fr 0, mr 2) | MISSED (fr 0, mr 2) | 2 (2) |
| E71 | two constructs in one paragraph both edited | E[n_old_surveys -> n_old_surveys_v2], E[old_mean -> old_median] | E[n_old_surveys -> n_old_surveys_v2], E[old_mean -> old_median] | ok | ok | ok | 2 (0) |

### Part 1, item 6: what the matcher needs from the text

- **It did not need Pandoc.** The matcher runs on blank-line-delimited blocks plus a handful of line rules (list-item start, `|` table row, heading, `[^n]:` footnote definition, `#|` chunk options, `>` block-quote prefix, `:::` div fences). I checked this against Pandoc (`quarto pandoc -f commonmark_x+sourcepos -t json`, `pandoc-check.R`, `out/pandoc-check.txt`): on the 10-section manuscript, all 74 Para and 3 Plain leaf blocks and all 10 Headers start on exactly one of my unit start lines (0 Pandoc paragraphs missing). The 6 units that are not Pandoc leaf starts are by design: 3 table rows (Pandoc yields one Table; I split per row so a cell edit is a paragraph edit), 1 footnote definition (Pandoc folds it into an inline Note), 2 chunks (Pandoc sees a CodeBlock).
- **Paragraphs in lists, block quotes, divs, table cells.** Each list item is its own unit; a second paragraph in an item (indented after a blank line) is a separate unit, as in Pandoc (probe E). Block-quote lines are stripped of `>` and split at a bare `>` line; div fence lines are skipped and the content is ordinary paragraphs; each pipe-table row is a unit (`|` separators and the `---` row are skipped). A table caption line (`: caption {#tbl-x}`) is an ordinary paragraph unit.
- **A caption in a chunk option.** Pandoc never sees it (the chunk is a CodeBlock), so a text-level rule is needed. I made the unit "the chunk's `#|` option lines joined", positioned among the paragraphs by line order. With a `#| label:` the chunk could instead be matched by label (stronger than position); I did not implement that.
- **Where line-based splitting is wrong or fragile (observed with Pandoc probes in `out/pandoc-probes/`):**
  - Setext headings (`Title` / `=====`, even with `{#sec-x}`) are headings and section anchors in Pandoc; my splitter does not see them, so such a section would silently merge into the previous one.
  - A span with an unescaped `|` inside a pipe-table cell is cut by Pandoc into cells (probe C: `[a site` / `# sites]{...}` end up as separate cells or are dropped); my scanner, reading the row as text, finds a span Pandoc does not have. `\|` inside the table works in Pandoc and in my scanner.
  - A reflowed line that starts with `# ` or `> ` becomes a heading or block quote in Pandoc (probes A and B; it also cuts an inline `` `r ...` `` in half). So "reflow only" is not always meaning-preserving for these constructs, and the matcher has to use the same line rules as Pandoc.
  - The scanner must apply knitr's inline rule exactly: `` `r `` + space (or `#`). When I normalised whitespace before scanning, "`r<newline>x`" counted as a construct and a whole-document scan of the raw text found 4,970 constructs against 5,500 per paragraph on the 2,000-paragraph timing document (this is what exposed E16b).
  - Not exercised: YAML front matter (skipped; a construct in `title:` would never be seen), chunk bodies (code, not scanned), HTML blocks, `{{< include >}}`, nested lists with several paragraphs, multi-file ranges (the matcher is single-file).

---------------------------------------------------------------------------------------------------

### Part 2. Hook cost (`bench.py` = median of 5 timed runs after 1 untimed warm-up; wall clock; 1-minute load recorded)

Commands are in `run-timing-1.sh` .. `run-timing-4.sh` (`run-all-timing.sh` runs all four plus `time-r.R`); output in `out/timing-1.txt` .. `out/timing-4.txt`, `out/timing-r.txt`, `out/timing-r.csv`, `out/timing.jsonl` (machine-readable, includes the per-step breakdown).
Test documents: `gen-docs.R` -> `out/timing/docs/doc{100,500,2000}.qmd` (about 2.75 constructs per paragraph; 17, 85 and 344 kB) and 20 chapters of 300 paragraphs (`out/timing/ch1` = HEAD, `out/timing/ch2` = edited: a bound loosened every 40th paragraph, one paragraph deleted every 40th). `setup-repo.sh` builds the throwaway git repo in `out/timing/repo`. `hook.R` is the hook body (`Rscript --vanilla hook.R [--pandoc=quarto|direct] [--once] [--compare] [--range] files...`).

**1 and 2. R start-up and packages** (seconds)

| command | run 1 | run 2 (load ~9.5) |
|---|---|---|
| `Rscript -e 'invisible(1)'` | 0.119 | 0.138 |
| `Rscript --vanilla -e 'invisible(1)'` | 0.114 | 0.127 |
| `Rscript --vanilla --default-packages=base -e ...` | 0.049 | 0.046 |
| `--vanilla` + `library(jsonlite)` | 0.147 | 0.139 |
| `--vanilla` + `library(jsonlite); library(yaml)` | 0.134 | 0.137 |
| `--vanilla` + `loadNamespace("yaml")` | 0.127 | 0.121 |
| `--vanilla` + `library(knitr)` | 0.192 | 0.192 |
| `--vanilla` + `loadNamespace("knitr")` | 0.197 | 0.186 |

`--vanilla` makes no measurable difference (0.11-0.14 s either way). jsonlite and yaml add 0 to about 30 ms (inside the scatter). knitr adds about 55-75 ms. The surprise: about 60-70 ms of the 0.11 s start-up is R attaching its default packages (`--default-packages=base` is 0.046 s). My code needs `utils::adist` and `stats::setNames`, so I tested `--default-packages=base,methods,utils,stats` on the whole hook: 0.70 s against 0.74 s (S1, load ~5), so only about 40 ms end to end.

**3. Pandoc `commonmark_x+sourcepos -t json`, and reading the JSON into R**

| paragraphs | `quarto pandoc` run 1 / 2 | direct binary run 1 / 2 | direct, no sourcepos run 1 / 2 | JSON size with / without sourcepos | `jsonlite::fromJSON(simplifyVector=FALSE)` with / without | parsed R object (with) |
|---|---|---|---|---|---|---|
| 100 | 0.248 / 0.222 | 0.084 / 0.072 | 0.072 / 0.071 | 0.55 / 0.09 MB | 0.012 / 0.003 s | 9 MB |
| 500 | 0.398 / 0.368 | 0.224 / 0.215 | 0.156 / 0.135 | 2.79 / 0.46 MB | 0.075 / 0.012 s | 46 MB |
| 2,000 | 0.876 / 0.828 | 0.642 / 0.889 (min 0.755) | 0.411 / 0.472 | 11.33 / 1.85 MB | 0.314 / 0.070 s | 184 MB |

(`read_json` gave the same times as `fromJSON`.) Sourcepos makes the JSON 6x larger and its parsing 4-6x slower; Pandoc itself is 15-55% slower with it. The R reading dominates the JSON cost, not the file I/O. Peak memory of the parsed object is large (184 MB for 2,000 paragraphs).

**4. `git show :<file>`** (files staged): 1 file 0.014 s; 5 files (5 processes) 0.051-0.057 s; 20 files (20 processes) 0.213-0.222 s (about 11 ms per process). `git cat-file --batch` for all 20 in one process: 0.018 s.

**5. The stand-in scanner** (in-process, median of 5; 3 for the 2,000 case; `time-r.R`), seconds

| paragraphs | whole document as one string (`scan_ids`) | per paragraph unit (`extract_units`, what the matcher uses) |
|---|---|---|
| 100 | 0.025 | 0.050 |
| 500 | 0.14-0.19 | 0.25-0.28 |
| 2,000 | 1.05-1.24 | 1.05-1.50 |

Both find 5,500 constructs in the 2,000-paragraph document (once the strict knitr rule is used). About 0.5-0.7 ms per paragraph in this benchmark (in the hook it measured 1 ms per paragraph on a 300-paragraph chapter under higher load), roughly linear for the per-unit scan; the whole-document scan is superlinear. It is R-level character-vector code, the slowest in-R step. Sourcing `lib.R` plus the stand-in (`load_code` in `hook.R`) is 14-25 ms.

**6. End to end** (wall clock of the whole `Rscript --vanilla hook.R ...`; "steps" are medians from inside the script, `out/timing-3.txt`)

Staged-only means: `git show :f` for each changed file, scan, Pandoc `+sourcepos` JSON, read the JSON. "+ HEAD + match" also reads `HEAD:f`, scans both, runs the matcher and Pandoc on both versions. All with the direct Pandoc binary unless stated; the machine was loaded (run 2 load 5-11).

| scenario | run 1 | run 2 | step breakdown, run 2 (R start-up and exit is the remainder, about 0.12 s) |
|---|---|---|---|
| **1 file, 300 paragraphs**, staged only, `quarto pandoc` | 0.864 | 1.729 (min 1.36) | scan 0.41, pandoc 0.82, read_json 0.12, git 0.04 |
| 1 file, staged only, direct pandoc | **0.760** | 0.982 (0.74 at load 5, `out/timing-4.txt`) | git 0.02, scan 0.37, pandoc 0.22, read_json 0.10 |
| 1 file, + HEAD + match, direct | 1.435 | 1.742 | git 0.05, scan+match 0.92, pandoc 0.43, read_json 0.12 |
| **5 changed files**, staged only, `quarto pandoc`, 1 process per file | 3.111 | 4.269 | scan 1.24, pandoc 2.37, read_json 0.31 |
| 5 files, direct, 1 process per file | **2.264** | 2.949 | git 0.11, scan 1.20, pandoc 1.11, read_json 0.30 |
| 5 files, direct, 1 process for all | 2.059 | 3.076 | scan 1.29, pandoc 0.90, read_json 0.50 |
| 5 files, + HEAD + match, direct, 1 process per version | 5.134 | 8.870 | scan+match 5.18, pandoc 2.26, read_json 1.21 |
| **book: 20 chapters x 300 paragraphs**, range `HEAD~1..HEAD`, new version only, `quarto pandoc`, 1 per file | 10.78 | 21.25 | scan 5.28, pandoc 12.16, read_json 2.58 |
| book, new version only, direct, 1 per file | 9.66 | 12.26 | git 0.48, scan 4.88, pandoc 4.92, read_json 1.81 |
| book, new version only, direct, 1 process for all | 11.68 | 8.83 | scan 3.85, pandoc 2.82, read_json 1.81 |
| book, both versions + match (CI range check), direct, 1 process per version | 28.73 | 28.53 | git 0.80, scan+match 15.61, pandoc 6.70, read_json 5.64 |

Run 1 and run 2 disagree by up to 2x on the same command, which is the load. The least contended numbers (run 1 and the load-5 repeat) are the best estimate for an idle machine; the loaded ones are what a developer with other work running might see.

**7. One Pandoc per file or one for all; quarto wrapper or the binary**

- The binary is at `<quarto dir>/bin/tools/aarch64/pandoc` (`/Applications/quarto/bin/tools/aarch64/pandoc`; `/usr/local/bin/quarto` is a symlink to `/Applications/quarto/bin/quarto`, itself a shell script; `quarto --paths` prints the `bin` and `share` directories, from which the path follows). I found it by hand and called it directly. I did not write automatic discovery.
- Launcher cost: `quarto pandoc --version` 0.172-0.184 s; the binary 0.032-0.033 s. So **the wrapper adds about 0.15 s per call**.
- Pure Pandoc timings (no R), run 1 / run 2 (`out/timing-4.txt`; run 1 is from console output): 20 files with `quarto pandoc`, 20 processes: 5.64 / 5.96 s; 20 files, binary, 20 processes: 2.73 / 2.84 s; 20 files, one `quarto pandoc` process: 1.83 / 1.87 s; 20 files, binary, one process: 2.19 / 1.81 s; 5 files, binary, 5 processes: 0.69 / 0.67 s; 5 files, 1 process: 0.46 / 0.44 s; 20 files, 20 processes 4 at a time (`xargs -P4`): 1.08 / 0.99 s. One 300-paragraph file with the binary: 0.20 / 0.14 s (0.11 / 0.084 s without sourcepos).
- So one process for all files beats one per file by about 1.3-1.5x on Pandoc alone and four parallel processes beat that, but **end to end the difference vanished or reversed** in the book run (run 1: 9.66 s per file vs 11.68 s once; run 2: 12.26 vs 8.83): one big JSON for 20 files is 34 MB of sourcepos JSON, `fromJSON` time grows superlinearly (read_json 2.6 s vs 1.3 s in run 1), and scatter is large. Not resolved at this noise level. I did not check that multi-file sourcepos output carries file names in `data-pos`.

---------------------------------------------------------------------------------------------------

### Recommendation: time budget and the dominant step

- What the straightforward hook cost on this (loaded) machine, whole-file scanning, direct Pandoc binary, staged version only: **about 0.75-1.0 s for one changed 300-paragraph file; about 2.0-3.0 s for five; 9-12 s for a 20-chapter book** (CI). Reading the HEAD version too and running the matcher roughly doubles it: 1.4-1.7 s, 5-9 s, about 28 s for the book. Through `quarto pandoc` add about 0.15 s per Pandoc process.
- **Dominant step with the direct binary: the R scanner (`extract_units`/`scan_ids`), about 38-40% of wall time (one file 0.29-0.37 s; book 3.9-4.9 s), then Pandoc (22% on one file, 40% on the book), then reading the sourcepos JSON (10-15%).** Through `quarto pandoc` Pandoc dominates (57% on the book). With the matcher the scan-and-match step is 50-55%. `git show` is 1-2% and R start-up is a fixed 0.11-0.14 s (0.05 s if default packages are trimmed, but only about 40 ms end to end). This ranking is for an R-level scanner; a faster scanner would make Pandoc dominant, which I did not test.
- Budget I would set for the hook on an ordinary commit (1-2 files touched): **about 1 s typical, 2 s ceiling.** That is met only for one or two files of this size with the binary called directly. Five touched 300-paragraph files already cost 2-3 s staged-only and 5-9 s with matching. To hold 2 s regardless of how many files are touched the work has to scale with the diff, not the file: scan and Pandoc only the paragraphs whose text differs from HEAD (a line diff of the two versions first). I did not implement or measure that, so the saving is not known; the only arithmetic available is that one 300-paragraph file cost 0.29-0.37 s to scan and 0.26-0.30 s for Pandoc plus JSON read.
- Two cheap, measured wins: call the Pandoc binary (saves about 0.15 s per process, about 3 s on a 20-file per-file run); do not use `+sourcepos` unless the positions are used (6x smaller JSON, 4-6x faster read, Pandoc 15-55% faster). The matcher in this spike needed no Pandoc output at all.
- The CI book check is not constrained by the hook budget; about 10 s for the new version, about 30 s with matching on this loaded machine.

---------------------------------------------------------------------------------------------------

## (ii) What I did not run

- Real `git commit` with `.git/hooks/pre-commit` installed; the hook body was run directly from a shell in the throwaway repo's directory.
- Any measurement on the Windows laptop or on an idle machine. All timings are one Apple M2 at load 5-11 of 8.
- The "prose tokens between constructs" step: I gave Pandoc the whole file text and only measured Pandoc and reading its JSON, not replacing constructs with placeholders or tokenising the result.
- Sourcepos output with several input files (file names in `data-pos`); whether Pandoc's position data could replace my line-based units.
- Diff-limited scanning (only changed paragraphs); a compiled or regex scanner instead of the R one.
- Cross-file matching (a construct removed in one chapter and added in another within a commit range). The matcher is single-file, so that netting is not tested.
- Matching a section by anything other than its anchor (heading text, content overlap) when the anchor is renamed, beyond variant B's file-wide similarity pass.
- Documents with YAML-header constructs, constructs inside code chunk bodies, includes, setext headings, HTML blocks.
- The similarity thresholds (0.5 / 0.6) were fixed before running and not tuned, but the edit set was written by me, after variant A had shown its failure, and variant B's 71 / 72 is on that same set; it is not an out-of-sample result.
- Real authors' edits: no frequency of any edit type is claimed.

## (iii) Surprising, and ways the proposed matcher can miss a real removal

1. **Delete a paragraph and write a different one in its place and the gate reports an edit (E47, E70).** Position is all the proposed pairing uses, so a 1:1 gap is always "the same paragraph", whatever is in it. Nothing is needed from the author. Similarity pairing does not close it for templated prose (E70). The only observed clean separation is a gap rule that refuses 1:1 pairs with low similarity (variant B on E47 and E69), which fails when the replacement shares the template.
2. **"Identical paragraphs anchor the alignment" is unsafe if identical means identical words (E16b).** Constructs can disappear without a word changing (a newline after `` `r ``, a `# ` or `> ` at a line start after a reflow), and then the matcher never looks at the paragraph's constructs. 31 constructs vanished silently in my reflow test. Fix measured: compare identities of identical-text pairs.
3. **Reflow is not meaning-preserving for these constructs.** The test "reflow line wraps only" has two answers: with a wrapper that avoids those spots it changes nothing (E16, correct); with a plain `strwrap` it changes 32 constructs.
4. **The proposal's 1:1 gap rule gives false removals on common authoring patterns**: two adjacent edited paragraphs, insertion next to an edit, deletion next to an edit, a section anchor renamed together with an edit, a paragraph moved and edited. 8 of 72 edits. The equal-size-gap fix for the first of these opens a missed-removal path (E69).
5. **The rules, not the matcher, hide three things** (E24, E57, E61 above): a same-identity removal+add in one file, an expression changed under an `#id`, and an unrelated construct swapped in within one paragraph.
6. **R's default packages are over half of `Rscript` start-up** (0.046 s with `--default-packages=base`, 0.11 s without), but trimming them saved only about 40 ms of the 0.74 s hook.
7. **`quarto pandoc` is a 0.15 s wrapper**: 20 per-file calls cost 5.6-6.0 s through it, 2.7-2.8 s through the binary.
8. **The hook's cost is per file, not per change.** Everything scales with file size (one 300-paragraph file: 0.29-0.37 s scanning, 0.26-0.30 s Pandoc plus JSON), so a one-line change to a 300-paragraph chapter costs the same as rewriting it.
9. Not a surprise but worth saying: the two timing runs differ by up to 2x because the machine was shared; any budget should be re-measured on an idle machine before being committed to.

## Files

- Matcher and tests: `lib.R`, `manuscript.R`, `edits.R`, `run.R`, `summarise.R`, `make-table.R`
- Matcher results: `out/results.csv`, `out/per-edit.txt` (expected vs actual and missed-removal mechanism per edit), `out/summary.txt`, `out/edit-table.md`, `out/run.txt`, `out/manuscript.qmd`, `out/manuscript-stats.txt`, `out/edits/*.qmd` (every edited version)
- Pandoc cross-checks: `pandoc-check.R`, `out/pandoc-check.txt`, `out/pandoc-probes/*.md` and `out/pandoc-probes.txt`
- Timing: `bench.py`, `gen-docs.R`, `setup-repo.sh`, `hook.R`, `time-r.R`, `run-timing-1.sh` .. `run-timing-4.sh`, `run-all-timing.sh`, `out/timing-1.txt` .. `out/timing-4.txt`, `out/timing-r.txt`, `out/timing-r.csv`, `out/timing.jsonl`, `out/timing/` (documents, JSON, repo)

## Exact commands

```
cd $G
Rscript gen-docs.R && ./setup-repo.sh                      # documents and repo
Rscript run.R > out/run.txt; Rscript summarise.R > out/summary.txt; Rscript make-table.R
Rscript pandoc-check.R out/manuscript.qmd
./run-all-timing.sh                                         # 1-3, 4, 5, 6, 7 (also: ./run-timing-1.sh etc. singly)
# e.g. the 1-file end-to-end case, as bench.py runs it:
cd out/timing/repo && Rscript --vanilla $G/hook.R --pandoc=direct ch/ch01.qmd
# Pandoc:
quarto pandoc -f commonmark_x+sourcepos -t json -o out.json doc.qmd
/Applications/quarto/bin/tools/aarch64/pandoc -f commonmark_x+sourcepos -t json -o out.json doc.qmd
```
