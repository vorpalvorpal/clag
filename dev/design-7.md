# Stage 7: eight features from the trial

Written before any test or code. It is the build contract for the eight
features Robin approved after the trial on a long report ("Yes to each of
your recommendations", `dev/current-state.md`, rulings of 14 Nov), in the
agreed build order: F1 explicit plus sign and `ci()` forms; F2 `.p` digits
and label; F3 (was C) tables in the ledger; F4 (was D) the rendered-output
check; F5 (was A) chunk claims collected; F6 (was B) forward references for
named values; F7 (was E) `decision=` beyond the dictionary; F8 (was G) a
`range` dictionary type. The choices inside them were delegated; each is a
decision in §3 with its alternatives and its reason. Every example is
invented.

A test-writer works from §2 and §5 only and never reads `R/` or `inst/`. An
implementer then works from §2, §4 and the tests. N numbers are this note's
contract; E numbers are exact message texts (§7); rule numbers such as
1.4.21 are the spec numbers proposed in §6.

## What was measured

Quarto 1.11.9 (its Pandoc 3.10), Pandoc 3.8.3 on the `PATH`, R 4.4.3,
knitr and rmarkdown as installed. Scripts under the scratchpad (`e1.*` to
`e5/`), one R process at a time under the lock. Nothing below is assumed.

1. **Unresolved references in the tree.** A `.qmd` citing `@sec-missing`,
   `@fig-missing`, `@tbl-nothere` and `{{< meta nosuch >}}`. A filter
   listed before Quarto's own (where `weft.lua` and `weft-check.lua` run)
   sees each reference still as a `Cite`. A filter run after Quarto's (M2)
   sees `Strong [Str "?@sec-missing"]` and `Strong [Str "?meta:nosuch"]`,
   identically for `html`, `latex`, `docx` and `typst`. Quarto only prints
   "WARNING ... Unable to resolve crossref @sec-missing" and renders.
2. **Where a filter can run after Quarto's.** In an extension's
   `_extension.yml`, a filter written as a mapping (`- path: post.lua`,
   with or without `at: post-render`) did not run at all; only the plain
   string form ran, and it ran before Quarto's crossref even when the
   document's `filters:` listed `quarto` before the extension. A `filters:`
   entry `{path: <file>, at: post-render}` in a document's front matter or
   in `_quarto.yml` ran after crossref in all four formats, from the
   project root and from a subfolder document.
3. **Citations.** At that point a citation is still a `Cite`: citeproc runs
   after every filter. An unknown key gives "[WARNING] Citeproc: citation
   nokey not found" and citeproc's own rendering. No filter can see it as
   unresolved.
4. **Missing values in the tree.** Prose "NA" reaches the filter as
   `Str "NA"`, "NA." as `Str "NA."` (punctuation attached); `` `NA` `` is a
   `Code`; a raw HTML block's text is not a `Str`; a table cell's text is a
   `Str`; in HTML at that point a figure caption's text is `Str` between raw
   `<figcaption>` wrappers.
5. **Empty attribute values.** Pandoc keeps `label=""`:
   `` `pv`{.p label=""} `` reads with the attribute `label` = "".
6. **What knitr hands the evaluate hook.** An `.Rmd` rendered by rmarkdown
   (knitr 1.51, evaluate 1.0.5) with an evaluate hook that logs each output
   element. `knitr::kable()` (pipe markdown), `gt::gt()` (1.3.0),
   `flextable::flextable()` (0.9.10) and `tinytable::tt()` (0.16.0) are each
   one `knit_asis` element; two kables in one chunk are two. Text that
   `cat()` prints in a `results='asis'` chunk is `character`, one element per
   `cat()` call there; two `print(kable(...))` calls in a loop are one
   merged `character` element; a printed data frame is `character`. The
   kable text was identical in `html_document`, `latex_document` and
   `word_document`.
7. **Raw table text is not stable.** Two identical HTML renders: kable and
   asis text identical; gt (a random element id), flextable (random CSS
   class names) and tinytable (random ids) differed every time. LaTeX and
   docx output of all three was identical between two renders.
8. **Visible text is stable.** The same texts with HTML comments, `<style>`
   and `<script>` elements, every tag and raw-format fences removed and
   white space collapsed gave identical digests between renders for every
   table in HTML and in docx; gt, flextable and tinytable gave the same
   text in HTML ("mpg cyl disp 21.0 6 160 ...").
9. **Formatters today.** `fmt_range(units::set_units(c(6.5, 8.5), "mg/L"))`
   prints "6.5–8.5 mg/L" (the unit once); `fmt_range(c(-2, 3))` "−2 to 3";
   `apply_formatters(-8, c(".num", ".a"))` "a −8"; `.p` with `digits`
   raises "`digits` and `sigfig` do not apply to `.p`."

## 1. Scope

| What | Pkg | |
|---|---|---|
| New settings, in R and in the filter's reader | 7s | build, first |
| F1, F2 in R: `.plus`; `ci(plus, pct, short)`; `.p` `digits` and `label`; conformance rows | 7a | build |
| F1, F2 in the filter: the same, against the regenerated tables | 7b | build |
| F3 tables in the ledger, knitr documents | 7c | build |
| F3 tables in the filter path (Python, Julia, markdown documents) | | out, later (D16) |
| F4 the rendered-output check: filter, installers, post-render, `verify()` | 7d | build |
| F5 chunk claims collected, R | 7e | build |
| F5 for Python and Julia `claim()` | | out, later (D22) |
| F6 forward references for named values | 7f | build |
| F6 for inline R (`` `r x` `` above `x`) | | out: a hint points at the named value (N98) |
| F7 `decision=` on literals, `cite` spans and `claim()` | 7g | build |
| F7 on Python and Julia `claim()` | | out, later |
| F8 `range` dictionary type and `in_range()` | 7h | build |
| F9 checks of one value compared: the reader (value expressions as operands, N149 to N151), implication, the gate's lines, `checks()` | 7j | build |
| F9 for Python and Julia checks, reasoning about arithmetic in an expression, two checks combined, `verify(since =)` | | out (N147, D38, D53) |
| Spec, articles and the three documentation items (§6, §7a) | 7i | build, last |
| `pm(plus=)`; `.plus` on `.sci`; a plus-glyph setting | | out (D3, D4) |
| A citation check in the output; parity of numbering between formats; alt text; inventories; typesetting | | out (D13) |
| Register generation from commit trailers (H) | | out: Robin's "no" |

## 2. Contract

### A. F1: an explicit plus sign; `ci()` with percentages and a short form

Syntax:

```
The mean rose by `r d_mean`{.num .plus} mg/L (`r d_pct`{.pct .plus}).
The change ranged `r d_rng`{.range .plus} across sites.
The effect was `r ci(b, b_lo, b_hi, plus = TRUE, short = TRUE)`.
```

prints "rose by +1.2 mg/L (+12%)", "ranged −0.5 to +1.2", "was +2.1 (+1.3
to +2.9)".

- **N1. `.plus`** is a class. It signs each element that the number stage
  prints with `.num` or `.pct`. With no number class it implies `.num`, as
  `digits` does (1.4.7). It is in no at-most-one group, so it goes with any
  one number class, with any collapse class (each element is signed before
  the collapse), and with `.a`, `.cap`, `.strong`, `.em`, a unit class and
  renderer keys.
- **N2. Above zero.** An element whose number as printed (the record's
  number, 1.4.11) is above zero is printed with `+` (U+002B) where the minus
  would stand for a negative: `1.25` prints "+1.3" (default digits 1),
  `1234.5` "+1,234.5", `0.12` under `.pct` "+12%", `u(5, m)` "+5 m".
- **N3. Zero.** An element whose number as printed is 0 has no sign: `0`,
  `-0`, `1e-10` print "0"; `0.04` and `-0.04` print "0.0" and record the
  printed-as-zero warned check exactly as today (2.6.11). `.pct` judges on
  the percentage.
- **N4. Below zero.** Unchanged: the `minus` setting, "−1.3".
- **N5. Placement.** The plus takes the place the minus takes: after a
  `clamp()` relation (`clamp(150, ceiling = 99)` with `.plus` prints
  "> +99"), and after a unit written before its number and its space (rule
  4.4.22).
- **N6. `.range`** with `.plus`: the ends are signed by N2 to N4, and the
  joiner is " to " when either end is printed with a sign (`+` or the
  minus), else the en dash. `c(1.2, 3.4)` prints "+1.2 to +3.4";
  `c(-0.5, 1.2)` "−0.5 to +1.2"; `c(0, 1.2)` "0.0 to +1.2"; `c(1.2, 1.2)`
  "+1.2" (both ends print the same, 1.4.4). Without `.plus`, `.range` is
  unchanged.
- **N7. `.a`** reads a leading `+` as it reads a minus: `` `r 8`{.num .plus .a} ``
  prints "a +8".
- **N8. Construct errors**, found from the source and at render, E1: `.plus`
  with `.sci`, `.p`, `.date`, `.no`, `.word`, `.count`, `.ord`, `.val`, or a
  project formatter of the number stage. E2: `.plus` on a span with `n`,
  `if`, `sign`, `list` or `cite`. On the result of `ci()`, `pm()`, `of_n()`
  or `about()` it is the value error those already raise for a number class
  (1.4.1).
- **N9. Function forms.** `fmt_num()`, `fmt_pct()` and `fmt_range()` gain
  `plus = FALSE`, as their last argument. `plus` must be `TRUE` or `FALSE`
  (E3, `weft_construct_error`).
- **N10. No setting.** A project cannot make `.plus` the default (D2).
- **N11. Record.** The record's number keeps its sign and is unchanged;
  `decimals` and `relation` are unchanged. The ledger records the text with
  its `+`.
- **N12. `ci()`** becomes
  `ci(est, lo, hi, level = NULL, digits = NULL, sigfig = NULL, plus = FALSE, pct = FALSE, short = NULL)`.
  - `plus = TRUE` signs all three numbers by N2 to N4.
  - `pct = TRUE` prints each of the three as `.pct` prints it (the setting
    `pct_proportion` applies; `digits` and `sigfig` act on the percentage;
    the printed-as-zero check judges the percentage). The level text is
    unchanged.
  - `short = TRUE` drops the level text. `short = NULL` takes the setting
    `ci_short` (default `false`).
  - `short` (after the setting) together with a `level` given in the call is
    a value error, E4: the short form would print a level other than the
    reader's default without saying so. The setting `ci_level` with the
    short form is not an error.
  - `plus`, `pct` and `short` must each be `TRUE` or `FALSE` (`short` also
    `NULL`), else E3 with the argument's name.
  - Exact outputs: `ci(2.1, 1.3, 2.9)` "2.1 (95% CI 1.3 to 2.9)" (as now);
    `ci(2.1, 1.3, 2.9, short = TRUE)` "2.1 (1.3 to 2.9)";
    `ci(0.12, 0.08, 0.16, pct = TRUE)` "12% (95% CI 8% to 16%)";
    `ci(-0.4, -1.2, 0.4, plus = TRUE)` "−0.4 (95% CI −1.2 to +0.4)";
    `ci(0.031, 0.012, 0.052, pct = TRUE, plus = TRUE, short = TRUE)`
    "+3.1% (+1.2% to +5.2%)".
  - The checks on `lo`, `hi` and `est` are on the raw numbers, as now.
- **N13. Lua.** The filter implements `.plus` on named values (`.num`,
  `.pct`, `.range`, a list under a collapse class) with N1 to N8 and R's
  texts. `ci()` has no filter side: phrase functions are R only (design-6
  §1), so F1's parity is the three classes.
- **N14. Conformance.** `numbers.tsv` gains rows with `classes` `num plus`
  and `pct plus`; `collapse.tsv` rows `range plus`; `text.tsv` a row
  `num plus a`. Values at least: `1.25`, `-1.25`, `0`, `-0`, `0.04`,
  `-0.04`, `1e-10`, `1234.5`, `0.999` with `digits=2`, and for ranges
  `c(1.2, 3.4)`, `c(-0.5, 1.2)`, `c(0, 1.2)`, `c(1.2, 1.2)`, `c(-3, -1)`.

### B. F2: `.p` with `digits` and a label

```
The trend was weak (`r fit$p`{.p digits="3"}).
After correction it held (`r fit$q`{.p label="q"}).
Effects were small (`r fit$p`{.p label=""}).
```

- **N20. `digits` on `.p`** is a whole number from 1 to 6, else a construct
  error E5. `sigfig` on `.p` is a construct error E6. (On `.date` both stay
  the error of today.)
- **N21. With `digits` d** (the key, else the setting `p_digits`): a value
  below 10^-d prints "p < 0.0…01" with d decimals (relation `<`, number
  10^-d); a value that rounds to 1 at d decimals (1 − 0.5 × 10^-d and above)
  prints "p > 0.9…9" (relation `>`, number 1 − 10^-d); any other value is rounded half away from zero to d decimals
  and printed with exactly d decimals (relation `=`).
  - d = 3: `0` "p < 0.001"; `0.0004` "p < 0.001"; `0.001` "p = 0.001";
    `0.046` "p = 0.046"; `0.12` "p = 0.120"; `0.9994` "p = 0.999";
    `0.9996` "p > 0.999"; `1` "p > 0.999".
  - d = 2: `0.004` "p < 0.01"; `0.046` "p = 0.05"; `0.995` "p > 0.99".
  - d = 4: `0.00004` "p < 0.0001"; `0.05` "p = 0.0500".
  - Settled when 7a was built (14 Nov): the lower bound is judged on the raw
    value and the upper on the rounded one, as the examples have it
    (`0.9994` is above 0.999 and prints "="; `0.0006` prints "<", not
    "p = 0.001"). Both printed statements are true of the value. The
    alternative, rounding first at both ends, would print "p = 0.001" for
    0.0006.
- **N22. Without** `digits` or `p_digits`, 1.4.17 is unchanged.
- **N23. `label`** sets the text before the relation; its default is the
  setting `p_label`, whose default is `p`. `label="q"` prints "q = 0.046"
  and "q < 0.001". `label=""` prints "0.046", "< 0.001" and "> 0.99": with
  no label there is no "=" and no space before the number. The label is
  printed as written, markdown included (`label="*p*"` prints
  "*p* = 0.046").
- **N24.** `label` on a construct without `.p` is a construct error, E7.
  `label` is not a renderer key under design-6 N5: a code span whose only
  attribute is `label` is not a named value and stays code.
- **N25. Settings** `p_digits` (a whole number from 1 to 6, or `null`, the
  default, for the rule of 1.4.17) and `p_label` (one string, which may be
  empty; default `p`). A wrong value is a `weft_config_error`, E8 and E9. A
  key on the construct wins over the setting.
- **N26.** `fmt_p(x, digits = NULL, label = NULL)`.
- **N27. Record.** Number and relation as N21; the label does not enter the
  record. The `.p` value-range error (outside 0 to 1) is unchanged.
- **N28. Lua.** `.p` takes `digits` and `label` on a named value, and the
  filter reads `p_digits` (int) and `p_label` (string, empty allowed).
  `p.tsv` gains rows: `digits` 1 to 4 at each threshold, at a tie and at
  `1 - 10^-d` exactly; `label=q`; `label=` (empty); `cfg.p_digits=3`;
  `cfg.p_label=q`; a key beating a setting.

### C. F3: tables in the ledger

What a reader sees as a table, or as text a chunk printed straight into the
document, gets one ledger entry holding a digest of its visible text, so
`changes()` reports "table `tbl-sites` changed" without listing cells.

- **N30. What is recorded.** In a top-level knit with the ledger on, for
  each executed R chunk whose output reaches the document (not
  `include: false`, not `results: "hide"`), one entry per output element
  (M6) that is
  - a `knit_asis` value: `knitr::kable()` in markdown, gt, flextable,
    tinytable, kableExtra, `knitr::asis_output()`, a data frame under
    Quarto's `df-print` that prints one; or
  - printed text in a chunk with `results: "asis"`, one entry per element as
    evaluate gives it.
  Not recorded: printed output that knitr shows as verbatim (`print(df)`
  without `asis`), figures, conditions, output of non-R chunks, and an
  element whose normalised text (N33) is empty.
- **N31. Key** (7.1.4): `kind` is `table`; `expr` is the chunk's label as
  written, or `""` for an unlabelled chunk (a label knitr generated:
  `<unnamed.chunk.label>-<digits>`); `id` is the label of a labelled chunk
  (knitr labels are unique in a document), `null` otherwise; `occ` is the
  element's place among the chunk's recorded elements by the existing
  occurrence rule, so the second table of chunk `tbl-two` has `occ` 2;
  `file` and `section` are the chunk's.
- **N32. Fields.** `text` is the digest: `cli::hash_raw_xxhash64()` (XXH3,
  16 lower-case hex, the ledger header's hash) of the UTF-8 bytes of the
  normalised text. `context` is `"chunk"`. `sentence` is the chunk's table
  caption (`tbl-cap`, else `tab.cap`) when it is one string, else the first
  80 characters of the normalised text, then "..." when cut. `arm`, `rel`,
  `raw`, `unit` and `failed` are `null`; `dict` is `[]`.
- **N33. Normalised text** (M8), in this order: line ends made `\n`; HTML
  comments removed; `<style>` and `<script>` elements removed with their
  content, any letter case; every tag removed, a tag being `<` then a
  letter, `/` or `!`, up to the next `>` (so "x < 5 and y > 3" in a cell is
  kept); raw-attribute fence lines (a fence of three or more backticks, with
  or without `{=format}`) removed; runs of white space made one space; ends
  trimmed. Nothing else: no entity decoding, no rounding. A change of style,
  class name or element id is therefore not a change; a change of any
  visible character is.
- **N34. Size.** One line per table, about 250 bytes plus the caption.
- **N35. `changes()`.** A table entry has changed when its `text` differs
  (7.1.7); it has no structural reasons, and it is listed after the ranked
  value changes, in file order, as E70 with its caption under it. Added and
  removed tables are one line per ledger each, E71 and E72, naming at most
  ten labels then "and N others". `print(x, brief = TRUE)` shows none of
  them. The first render after this package lists every table as added,
  once.
- **N36. Cache and freeze.** The entries are recorded in the evaluate hook,
  so they are among the rows saved with a cached chunk and replayed when it
  is served from the cache (design-2 D22). A document served from freeze is
  not knitted and keeps its ledger (7.2.4), as for every entry.
- **N37.** A chunk with `error: true` that meets an error records every
  element that reached the document: knitr goes on after the error, so that
  is the elements before it and those after it (settled when 7c was built;
  the first wording had only those before). Draft mode records as usual.
- **N38. Schema.** `LEDGER_VERSION` stays 1: `table` is a new value of
  `kind`, and every field is one a v1 reader knows. Ledgers written before
  this package read unchanged.
- **N39. Gate, lints, `verify()`:** unchanged. A table is not a construct, is
  not counted (6.3.1) and its removal needs no trailer.
- **N40. Not covered:** Python and Julia documents (D16), tables printed by a
  Python chunk under knitr, tables inside a figure.

### D. F4: the rendered-output check

The three checks run on the document's final tree, after Quarto's own
filters, so that one filter covers every output format (M1). No output file
is read.

- **N50. The filter.** `weft-output.lua`, shipped beside `weft-check.lua`
  in `_extensions/weft-check/`. It reads `_weft.yml` and the document's
  `weft:` through `weftlib/config.lua` (it is not self-contained, unlike
  `weft-check.lua`; D12). Installed:
  - by `use_quarto()`, as this `_quarto.yml` entry, after `weft-check`
    (M2: an extension cannot place it there itself):
    ```yaml
    filters:
      - weft-check
      - path: _extensions/weft-check/weft-output.lua
        at: post-render
    ```
    An existing project gets it when `use_quarto()` is run again, and
    `status()` reports the entry as missing until then;
  - by `use_setup()` under rmarkdown, as the last `--lua-filter` in
    `pandoc_args`;
  - in plain Pandoc, by hand, as the last filter.
- **N51. Settings**, each `fail`, `warn` or `off`: `output_refs` (default
  `fail`), `output_missing` (default `warn`), `output_markup` (default
  `fail`). Any other value: E20, a `weft_config_error` in R; in the filter
  E33 of design-6 (the default is used).
- **N52. Unresolved references** (kind `unresolved reference`). Under Quarto
  only: a `Strong` whose whole text is `?@` followed by an id, or `?meta:` or
  `?var:` followed by a key (M1). Detail E21 or E22.
- **N53. Missing values** (kind `missing value in output`). A `Str` whose
  text, after removing leading `( [ " ' “ ‘` and trailing
  `. , ; : ! ? ) ] % " ' ” ’`, is exactly one of `NA`, `NaN`, `nan`, `Inf`,
  `-Inf`, `−Inf` (U+2212), `inf`, `-inf`. Only in prose: paragraphs, plain
  blocks, headings, list items, block quotes, definition lists, line blocks,
  footnotes, and figure and table captions. Not in table cells, `Code`,
  `CodeBlock`, `Math`, raw inline or block content, link targets, or
  anything inside a span or div with the class `weft-literal` (whose `why`
  is gone by then, its class kept: 1.8.11). Detail E23. "Na", "N/A", "NULL",
  "None" and "missing" are not matched.
- **N54. Leftover markup** (kind `leftover markup`). In prose and in table
  cells: a `Str` that begins `:::` (a fence Pandoc did not read); text that
  shows an attribute block touching the text before it, `{#` or `{.` then a
  letter after a character that is not a space or `{` or `]` (the pattern
  of `weft-check.lua`, with `#` added); and under Quarto, `\@ref(` (bookdown
  syntax Quarto never resolves). Detail E24.
- **N55. A finding** is `{source: "output", kind, level, file, format,
  section, text, excerpt}`: `level` is the check's setting (`fail` or
  `warn`); `section` the identifier of the last heading above, or `""`;
  `text` the token or reference as printed; `excerpt` the stringified block
  that holds it, white space collapsed, cut to 80 characters with "..."
  around the token. One finding per distinct (kind, text, section).
- **N56. Reporting.**
  - With the collection file open (2.6.6; a Quarto project render), each
    finding is one JSON line in it and the filter does not exit. The
    post-render script lists `fail` findings among the failures, tagged by
    kind, and `warn` findings among the warned checks. Findings with the
    same file, kind and text from several formats are one entry, with the
    formats joined: `  ch2.qmd #methods (html, latex)  [unresolved
    reference] ?@sec-missing`, then the excerpt on the next line, indented
    six spaces.
  - With no collection file, the filter writes the same entries to stderr
    under E25, and exits 1 when there is a `fail` finding, except in draft
    mode (9.4.3), where it only reports.
- **N57. `verify()`.** Its render part sets `WEFT_OUTPUT_LOG` to a
  temporary file; the filter appends each finding to it as a JSON line as
  well. The result gains `output`, a data frame with the columns `file`,
  `format`, `kind`, `level`, `section`, `text` and `excerpt`. Each `fail`
  row is a reason and fails the render part; `warn` rows are listed and
  fail nothing. `verify_skip: [render]` skips both, as now.
- **N58. Not checked, and said so in the article:** what a writer or a later
  program adds (bookdown's `\@ref()` resolution under rmarkdown, LaTeX's
  "??", Typst's own references), citations (M3; the `cite-key` lint covers
  them), raw content, and anything in a table cell for N53.
- **N59. Overlap.** `bare_missing` (1.3.5) warns at knit time about a bare
  value that prints `NA`, naming its expression; N53 warns about the same
  text in the output, naming its sentence. Both are listed; there is no
  deduplication. `weft-check.lua` already fails on a weft attribute block
  before Quarto's filters; N54 may list the same text again.

### E. F5: chunk claims collected

```yaml
# _weft.yml
chunk_claims: collect
```

```r
n_up <- claim(sum(trend$up), . >= 10)      # recorded, and the chunk goes on
share <- claim(n_up / n_sites, . > 0.5)    # recorded too
```

- **N70. The setting** `chunk_claims`: `stop` (default) or `collect`, in
  `_weft.yml` or a document's `weft:`. Anything else is E30, a
  `weft_config_error`.
- **N71. Under `collect`**, a `claim()` check that is not `TRUE`, at level
  `"fail"`, evaluated during a knit outside inline R, is recorded as a
  failed claim (kind `failed claim`, the chunk's label, the detail of 2.6.2:
  ". >= 10 was FALSE (value 7)") and `claim()` returns `x`, visibly. The
  knit goes on. This covers chunk code, functions it calls, files it
  `source()`s, and chunk options knitr evaluates. Inline R is collected
  already (2.4.1).
- **N72. Still stops**, under `collect` as under `stop`: a claim outside a
  knit (2.4.2); a claim in a running `targets` target, judged by
  `targets::tar_active()` when `targets` is installed (a pipeline run from
  a chunk with `callr_function = NULL` would otherwise store a value that
  failed its claim); a claim in another process (a `callr`, `future` or
  `mirai` worker has no knit; its error reaches the chunk as an ordinary
  error); a Python or Julia `claim()` (N78).
- **N73. The end.** The render fails at the end with every failure listed,
  in the order collected, in the layout of 2.6.2 (chunk claims located by
  chunk label), as any collected failure does; draft mode reports and does
  not fail (9.4.3).
- **N74. A later error.** When the knit is about to stop on an error (in a
  chunk without `error: true`, or a bare inline value's error, 2.6.4) and at
  least one claim was recorded under N71 in this knit, weft raises instead a
  condition of class `weft_claims_collected` (and `weft_error`) whose parent
  is the original error, with the message E31: the collected failures
  first, then the error. Without such a claim nothing changes, and the
  error keeps its class.
- **N75. Unchanged:** `level = "warn"` (never collected, never stops);
  `error: true` (the error prints in the document, the knit goes on, the
  render fails at the end); a claim inside `try()` (nothing is raised, the
  failure is recorded).
- **N76. `rehearse()`** knits each case with the project's setting; a case
  lists its chunk claims as it lists any failure, and a case that stops
  under N74 is reported with E31's text.
- **N77. The gate** is unchanged: `claim()` calls are counted as today, and
  changing the setting removes nothing.
- **N78. Python and Julia.** Under knitr their `claim()` keeps stopping the
  chunk whatever the setting (later package, D22). The article says so.
- **N79. `last_knit()`** holds the failures as for any collected failure.

### F. F6: forward references for named values

```
In summary, `n_sites`{.count} sites were sampled.     <- above the chunk

```{r}
n_sites <- nrow(sites)
```
```

- **N90. Fallback.** In a document the filter resolves (every engine, knitr
  documents included), a named value, or a name in an `if`, `n`, `sign` or
  `list` value, used above every publication of the name (1.12.7) takes the
  value the document publishes below, when the name takes one value (N91).
- **N91. One value.** The records published under the name in the document
  (every `weft-values` block and values file the filter reads, wherever it
  stands) are equal when compared without their `checks` member: the same
  members with the same values, a float's `v` compared as text. So: one
  publication; several identical publications (a loop of `weft_put()`
  calls with one value, a values file and a block that agree); a `missing`
  record counts as a value.
- **N92. The record used** is the last publication, with its `checks`,
  which run at the use as any record's do (design-6 N25a).
- **N93. Several values** is a collected failure of kind `no value` (the
  render fails at the end, 2.6.2), detail E40 and hint E41. It is an error,
  not a warning (D23).
- **N94. No publication at all**: a `no value` failure as today, its detail
  now E42; the hint is unchanged.
- **N95. Unchanged:** a use below a publication takes the latest publication
  above it; captions and front-matter fields take the last value (design-6
  D8), with no several-values failure.
- **N96. Ledger and stamp.** The entry is a named value's entry, its text the
  fallback's; no field is added. The stamp counts its checks as usual.
- **N97. Knitr.** Nothing changes in the hooks: they publish each name the
  source uses as a named value when it is bound, at each prose block and at
  the end of the document (design-6 N43; `values_append()`), so the filter
  finds the value in the closing block. The filter must be installed, as
  for any named value.
- **N98. Inline R** is not covered: `` `r n_sites` `` above the chunk is
  evaluated where it stands. When such an expression is a single name and
  fails with "object not found", the failure's hint becomes E43.
- **N99. No setting.** A use above every publication is a failure today, so
  no document that renders today changes.

### G. F7: `decision=` on literals, `cite` spans and claims

```
filtered through [0.45 µm]{.weft-literal why="method" decision="12"} membranes
reached [10 m]{cite="@smith2020" decision="31"} in the upper catchment
`r claim(n_sites, . >= 10, decision = 31)` sites
```

- **N100.** `decision` is a key on a `.weft-literal` span or div and on a
  `cite` span. Its value must not be blank: E50, a construct error found
  from the source and at render. A `.weft-literal` still needs its `why`
  (1.8.10).
- **N101.** `decision` on any other construct (a value, a named value, an
  `n`, `if`, `sign` or `list` span, a text span) is a construct error, E51.
  A bracket with no weft key or class is an ordinary Pandoc span and is left
  alone (1.9.1).
- **N102.** `decision` is removed from the output, as `why` is (1.8.11), by
  the hooks and by the filter.
- **N103. `claim(x, ..., level = c("fail", "warn"), decision = NULL)`**,
  given by name: one string that is not blank, or one whole number from 1;
  else E52, class `weft_claim_decision` (and `weft_error`), raised before the
  checks run, in any context. A failure's detail ends "; decision <value>"
  (". >= 10 was FALSE (value 7); decision 31"), in a knit and in the
  error outside one.
- **N104. `verify()`'s decisions part** checks, with the configured
  resolver (4.5.3) and each distinct pointer once, the pointers of
  `dict.yml` and of the documents it verifies: every `decision` on a
  `.weft-literal` or `cite` in the source (the scanner's rows), and every
  `claim()` call in R chunk or inline code whose `decision` argument is a
  literal string or number. A computed argument is not checked statically.
  Each document pointer is a row: `file` the document, `line` the
  construct's line, `key` one of `.weft-literal`, `cite="<value>"` or
  `claim()`. The part runs when there is any pointer; with none it is
  skipped, "skipped: no decision pointers".
- **N105. Ledger:** unchanged. A pointer prints nothing and is not recorded;
  the `cite` entry's expression is its `cite` value, so adding a pointer
  changes no key.
- **N106. Filter:** accepts `decision` on `.weft-literal` and `cite`,
  removes it, and gives E51 on its other constructs. Comments are never
  scanned for ids.
- **N107.** Python and Julia `claim()`: no `decision` yet.

### H. F8: a `range` dictionary type

```yaml
do_band:
  value: [6.5, 8.5]
  type: range
  unit: mg/L
  definition: "Acceptable dissolved oxygen."
```

```
The acceptable band is `r dict$do_band`{.range}, and the mean was
[within | outside]{if="in_range(do_mean, dict$do_band)"} it.
```

- **N110. The entry.** `type: range`; `value` a sequence of two finite
  numbers, lower then upper, lower strictly below upper. `unit` is optional,
  and `display` is allowed only with `unit` (4.2.7). Problems (4.2.6), each
  with the file, line and rule 4.2.1: "must be a sequence of two numbers,
  lower then upper"; "the lower bound must be below the upper bound"; "a
  bound must be finite; a limit on one side is a `number` or `quantity`
  entry"; a non-decimal number (the existing text).
- **N111. Read as** a numeric vector of length 2 named `lower` and
  `upper`, or a `units` vector of that shape when `unit` is given (in
  `display` when given). `dict$do_band[["lower"]]` reads one bound.
  `.range` prints it by 1.4.4, the unit once: "6.5–8.5 mg/L" (M9).
- **N112. `in_range(x, range)`**, exported: `TRUE` where
  `range[1] <= x <= range[2]`, element by element, `NA` where `x` is `NA`.
  A quantity `x` is converted to the range's unit; units that do not
  convert, a number against a quantity range or the reverse, a `range`
  that is not two numbers in order: `weft_value_error`, E60 and E61. It is
  R: the filter has no dictionary.
- **N113. `changes()`.** Both bounds of a `range` entry named in an entry's
  expression or sentence are thresholds for "crosses a dictionary
  threshold" (7.3.4).
- **N114.** The glossary prints the range as `.range` does; `tar_dict()`
  passes the vector; `print()` of a dictionary shows "range 6.5 to 8.5
  mg/L".
- **N115. Lints:** none new; `dict-key` covers reads as today.

### I. F9: checks of one value compared

Approved after stage 7's first design ("Yes, sounds good", `dev/current-state.md`,
"More rulings (14 Nov)"): a value checked in several places with differing
conditions, where deleting the strictest check loosens the document without
anyone seeing it. Three parts: the gate says, for each check that is gone,
whether a check that remains implies it; a report function groups checks by
value; the claims article recommends checking once where the value is made
(7i). Only checks the static tools can read are reasoned about. A value
expression such as `max(turb)` is read as an operand (ruled 14 Nov, §9 q4;
N149 to N151, D50 to D54).

```
The site [exceeded the trigger]{if="turb_max > trigger"} on most days.   line 12, and 8 more like it
In March it [reached the trigger]{if="turb_max >= trigger"}.             line 64
```

```r
n_up <- claim(sum(trend$up), . >= 10)    # reads as n_up >= 10
claim(n_sites, . > 5, level = "warn")    # n_sites > 5, warned
x |> claim(. < u(50, NTU))               # x < u(50, NTU)
claim(max(turb), . < u(50, NTU))         # max(turb) < u(50, NTU)
claim(diffs, all(. > 0))                 # not read: the check is a call
```

Deleting line 64 loses nothing: `turb_max > trigger` implies
`turb_max >= trigger`. Deleting one of the nine `>` sentences while line 64
stays loses nothing either (eight identical checks remain). In the mirror
document (nine `>=`, the one `>` at line 64), deleting the `>` sentence
leaves the document looser, and the gate says so:

```
commit-msg: 1 check gone since HEAD (information: what still checks each; rule 6.3.7)
  report.qmd, as in HEAD
       64  turb_max > trigger
           looser: nothing that remains implies it; remaining on turb_max against trigger: `turb_max >= trigger` (9 places)

```

The same mirror document, with three claims `claim(n_up, . >= 10)` on
`n_up` (a name assigned once), one on `max(turb)` and one claim that is not
read, before the deletion:

```r
checks()
#> weft checks: 15 checks of 3 values in 1 document; 1 value flagged
#>
#> report.qmd
#>   n_up
#>     n_up >= 10              3  lines 8, 44, 90
#>       checked in 3 places with the same condition: check it once where the value is made
#>   turb_max  [operators]
#>     turb_max >= trigger     9  lines 12, 20, 31, 40, 52, 70, 88, 97, 105
#>       checked in 9 places with the same condition: check it once where the value is made
#>     turb_max > trigger      1  line 64
#>   max(turb)
#>     max(turb) < u(50, NTU)  1  line 120
#>   not read
#>     claim(diffs, all(. > 0))  1  line 126
#>
```

**Reading a check** (shared by the gate and `checks()`; new spec 3.10)

- **N120. What is a check.**
  - each comma part of a one-arm `if` (a guard, 1.5.5): role `guard`,
    level `fail`. In a document the hooks resolve the parts are R's argument
    list (1.5.4); in a document the filter resolves they are the parts of
    1.12.4;
  - each check argument of an R `claim()` call: every argument after the
    value that is not named `level` or `decision` (3.1.3, N103); role
    `claim`. Its level is `fail` when `level` is absent, `warn` when it is the
    string `"warn"`, and `unknown` when it is computed. Claims are found
    where the gate finds them (6.3.1): in executed R chunks, inline values and
    governor expressions;
  - for `checks()` only, each comma part of a two-arm `if`: role `branch`,
    no level. A branch chooses wording and fails nothing (1.5.3), so the gate
    never counts it.

  Not checks: the governors of `n`, `sign` and `list`; `brk()` formulas;
  a record's `checks` in a values block (design-6 N25a); anything in an
  `eval: false` R chunk or in indented code (they never run, L11). A
  Python or Julia `claim()` (found by pattern, 6.3.1) is a check that is
  never readable (N121), with its text as the gate keeps it.
- **N121. Readable.** A check is readable when, after removing parentheses
  that enclose the whole of it, it is
  - `A OP B`, `OP` one of `< <= > >= == !=`, each side an operand of N122,
    at least one side a value operand (`name`, `dict` or `expr`), the two
    sides not the same operand (the same kind and the same text in normal
    form); or
  - a name, or `!` directly before a name (a bool check). An expression is
    never a bool check: `all(x)`, `is.na(x)`, `!any(x)` and `claim(all(x), .)`
    are not readable (D54).

  In a document the filter resolves, every guard part that is not a
  construct error has one of these forms; its grammar has no calls, so a
  guard there is read exactly as before (a part such as `max(x) > 5` is a
  construct error, 1.12.4, and its row is not readable). In R code anything
  else is not readable: `&&`, `||` or `%in%` at the top of the check, a call
  as the whole check (`all(. > 0)`, `is.na(x)`), arithmetic or indexing as
  the whole check with no comparison at its top. A call, arithmetic or
  indexing on one side of a comparison is an operand of kind `expr` (N122):
  `max(x) > 5`, `x[1] > 5` and `x < 2 * lim` are readable. In both, an ordering operator (`<`,
  `<=`, `>`, `>=`) against a `string` or `bool` literal is not readable (the
  filter raises a value error on it at render unless the other side is a
  date, which nothing static knows), nor is a comparison of two literals
  (already `inert-check` or E4 of design-6).
- **N122. Operands**, each with a kind:
  - `name`: an R symbol in R code (`T` and `F` are names), a NAME (1.12.4) in
    a filter condition;
  - `dict`: `dict$k`, `dict$"k"`, `dict[["k"]]` and the same of `dict_local`
    (the forms the `dict-key` lint reads), written `dict$k` or
    `dict_local$k`. A `dict$k` in a document that defines a local `k` is not
    readable: `dict-key` already calls it ambiguous;
  - `number`: in R a numeric constant in decimal form, with an optional `L`
    and an optional unary minus before it (`5`, `5.0`, `.5`, `1e3`, `-2L`),
    not hex, `Inf`, `NaN`, `NA` or complex; in a filter condition the literal
    of 1.12.4;
  - `date`: a string literal that is a valid `YYYY-MM-DD` date (the test of
    `cond.lua`'s `valid_date`);
  - `string`: any other string literal (`"a"` or `'a'` in R, `'a'` in a
    filter condition);
  - `bool`: `TRUE` or `FALSE` in R (the filter's grammar has no bool
    literal);
  - `quantity`: `u(<number>, <unit>)` in R with a number literal of this list
    and a unit written as a symbol or a string; its kind carries the unit as
    written, white space removed (`quantity NTU`);
  - `expr` (R only): any other R expression, when it is usable (N150); its
    identity is its normal form (N149). `max(turbidity)`, `x[1]`,
    `2 * lim`, `nrow(subset(d, flow > 2))`. A singleton is read like any
    other: an expression that occurs once in the document is a group of one
    (D51).

  The kinds are tried in the order listed, so `u(50, NTU)` is a quantity
  and `-2L` a number, never an `expr`. An operand that is none of them is not
  an operand, and its check is not readable (`x > Inf`, `x > NULL`). A
  *value operand* is one of kind `name`, `dict` or `expr`; where N124 and
  N127 to N131 say "name" they mean any value operand.
- **N149. An expression's normal form.** The operand node's source text
  (`node_text()`), parsed alone with `parse(text = , keep.source = FALSE)`;
  calls to `(` that enclose the whole expression removed; then
  `deparse(e, width.cutoff = 500L)`, each line trimmed and the lines joined
  by one space. So these are one expression, `max(turbidity)`:
  `max( turbidity )`, `(max(turbidity))`, the call written over two lines
  with a comment, and `turbidity |> max()` (R's parser rewrites the native
  pipe, and its `_` placeholder, before anything is deparsed). Deparsing also
  writes every string in double quotes (`f('a')` is `f("a")`) and a number as
  R prints it (`f(5.0)` is `f(5)`, `f(1e3)` is `f(1000)`; `5L` stays `5L`).
  Not normalised: parentheses inside (`max((x))` is not `max(x)`), a package
  prefix (`base::max(x)` is not `max(x)`), the order of arguments
  (`max(a, b)` is not `max(b, a)`), named and positional arguments
  (`round(x, 1)` is not `round(x, digits = 1)`), `%>%` against nesting
  (`x %>% max()` is not `max(x)`), `T` against `TRUE`, `dict$"k"` against
  `dict$k` inside the expression, and arithmetic (`2 * lim` is not
  `lim * 2`, nor `lim + lim`). Two texts with one normal form are one
  operand; nothing else is. Each distinct source text is parsed once per
  read of a document (memoised); this parse of one operand is the only
  parse the reader adds to `code_pieces()`'s.
- **N150. A usable expression.** Over the operand's subtree in the parse
  data, its *names read* are its `SYMBOL` tokens other than the one after
  `$` or `@`; its *functions called* are its `SYMBOL_FUNCTION_CALL` tokens,
  with the package when written `pkg::f` or `pkg:::f`. It is usable unless
  1. it reads no name (`1/3`, `2 * 25`, `Inf`, `0x10`, `c(1, 2)`,
     `runif(1)`): `x > 1/3` is not readable; write the literal;
  2. a name read is `.` (a placeholder of `%>%`, or a claim's `.` inside an
     operand: `claim(x, mean(.) > 3)`, `x %>% max(.)`);
  3. it holds an assignment or a definition: a `LEFT_ASSIGN`,
     `RIGHT_ASSIGN` or `EQ_ASSIGN` token (`<-`, `<<-`, `->`, `->>`, `=`
     outside an argument list, `:=`), or a `FUNCTION` or `'\\'` token
     (`function`, `\(`);
  4. it holds `{`, `if`, `for`, `while`, `repeat`, `break` or `next`;
  5. it calls a function through anything but a plain or `pkg::` name
     (`obj$size()`, `f()()`, `fs[[1]](x)`): such a call may be a method
     with effects, and `call_info()` gives it no `fn`;
  6. it calls, with or without a package prefix, a function of the
     constant `CHECK_UNSAFE_FNS` in `R/checks.R`, which is exactly:
     - random draws: `sample`, `sample.int`, `set.seed`, `rbeta`, `rbinom`,
       `rcauchy`, `rchisq`, `rexp`, `rf`, `rgamma`, `rgeom`, `rhyper`,
       `rlnorm`, `rlogis`, `rmultinom`, `rnbinom`, `rnorm`, `rpois`,
       `rsignrank`, `rt`, `runif`, `rweibull`, `rwilcox`;
     - the clock and the session: `Sys.time`, `Sys.Date`, `date`,
       `proc.time`, `Sys.getenv`, `Sys.getpid`, `tempfile`, `getwd`;
     - input: `readline`, `readLines`, `scan`, `menu`, `file.choose`;
     - reads the parse data cannot see, and effects: `get`, `get0`, `mget`,
       `exists`, `eval`, `evalq`, `assign`, `rm`, `source`, `library`,
       `require`, `attach`, `options`, `Sys.setenv`, `setwd`,
       `parent.frame`, `sys.call`, `sys.function`, `environment`;
  7. it holds a dictionary read `dict$k` of a key `k` the document also
     defines locally (N122's ambiguity, applied inside).

  An expression that is not usable is not an operand, so its check is not
  readable and is grouped by text, as before. A function the document
  defines is not looked into (§8, flag 8). Rebinding does not make an
  expression unusable: it is *rebound* (N125) as a name is, and is then
  never covered nor covers (N131), which is the owner's condition.
- **N151. Where an expression is read.** As either side of `A OP B` in a
  guard of a document the hooks resolve, and in a check argument of an R
  `claim()`, including as the claim's value bound to `.` (N123, rule 4).
  Nowhere in a document the filter resolves (N121). Arithmetic on either
  side is in, as an operand compared by its normal form only:
  `x < 2 * lim` is the pair `x`, `2 * lim`; it implies `x <= 2 * lim` by
  N128, and nothing about `x < lim` or `x < 3 * lim` (no arithmetic is
  reasoned about, N147).
- **N123. The claim's `.`** stands for its value (3.1.2), and is bound to:
  1. the value expression when it is a name or a dictionary read:
     `claim(foo, . > bar)` reads `foo > bar`;
  2. else the piped value when the claim is the right side of `|>` or
     `%>%` and that value is a name or a dictionary read:
     `foo |> claim(. > 0)` reads `foo > 0`;
  3. else the name the result is assigned to, when the claim call (or the
     pipe that ends in it) is the whole right side of `<-`, `=` or `<<-`, or
     the whole left side of `->`: `n_up <- claim(sum(trend$up), . >= 10)`
     reads `n_up >= 10` (`claim()` returns its value unchanged, 3.1.1);
  4. else the value expression, or the piped value when the claim is the
     right side of a pipe, when it is a usable `expr` (N150), in its normal
     form (N149): `claim(max(turbidity), . < u(50, NTU))` and
     `turbidity |> max() |> claim(. < u(50, NTU))` both read
     `max(turbidity) < u(50, NTU)`.

  The assigned name comes before the expression, so
  `n <- claim(max(turbidity), . < 5)` reads `n < 5` (D42), and is a check
  of another value than a bare `claim(max(turbidity), . < 5)` elsewhere.
  `.` is bound only where it is a whole operand; a `.` inside an operand
  makes that operand unusable (N150). Otherwise a check that holds `.` is
  not readable (`claim(5, . > 3)` is two literals; `claim(runif(1), . < 1)`
  has an unusable value). A check without `.` is
  read as written: `claim(x, y > 3)` reads `y > 3`. A claim anywhere inside a
  function definition (`function(v) ...`, `\(v) ...`) is not readable: its
  names are the function's.
- **N124. Normal form.** A readable check is `value op other`:
  - a bool check keeps its own form: `x` has `op` `is` and `other` `TRUE`,
    `!x` has `op` `is` and `other` `FALSE`, and `cond` is `x` or `!x` as
    written. It is not `x == TRUE`: in R, `x == TRUE` passes on the number
    1 and the bare `x` does not (a check passes only on a single logical
    `TRUE`, 3.1.3);
  - a value operand against a literal: the value operand on the left,
    the operator mirrored when the sides swap (`<` and `>`, `<=` and `>=`;
    `==` and `!=` unchanged): `5 < x` is `x > 5`, `50 > max(t)` is
    `max(t) < 50`;
  - two value operands: the check's *key* orders them by their text (byte
    order; an expression by its normal form), mirroring the operator; the
    *display* keeps the orientation of the
    check on that pair that comes first in the document (line, then
    column), and every check on the pair is shown in it (`x < 2 * lim` is
    keyed `2 * lim > x`, `"2"` sorting before `"x"`, and shown as written);
  - an expression is written in its normal form (N149), with no other
    change: the literals inside it are as `deparse()` writes them, not as
    the next item writes a literal operand;
  - a literal is written canonically: a number as its exact decimal with no
    `+`, no leading zeros, no trailing zeros after the point, no exponent and
    `0` for `-0` (`5.0` is `5`, `1e3` is `1000`, `.50` is `0.5`, `-2L` is
    `-2`), and in the form `<mantissa>e<exponent>` (the mantissa written the
    same way, one digit before the point) when the plain form would have
    more than 20 digits (`1e-25`); a string or date in single quotes, in
    double quotes when it holds `'`; `TRUE`, `FALSE`; a quantity as
    `u(<number>, <unit>)` with the number canonical (`u(50, NTU)`);
  - `cond` is `value`, `op` and `other` joined by single spaces.
- **N125. Rebound names.** In a document, a name is *rebound* when it is
  assigned in more than one place, counting:
  - in executed R code (inline values and executed R chunks, outside
    function bodies), each `<-`, `=`, `<<-` or `->` whose target's first
    symbol is the name (`x <-`, `x[i] <-`, `x$a <-`, `names(x) <-`), each
    `assign("x", ...)` with a string constant, and each `for (x in ...)`,
    which counts two (a loop rebinds);
  - in executed Python and Julia chunks, each line that begins, after
    blanks, with the name and then `=` (not `==`) or an augmented `+=`,
    `-=`, `*=`, `/=`, and each `for x in`, which counts two.

  Not counted: `weft_put()`, a `weft-values` block, a values file, a
  `source()`d script, `list2env()`, `<<-` inside a function. A dictionary
  read is never rebound. An `expr` operand is *rebound* when one of its
  names read (N150) is, or one of its functions called that has no package
  prefix is, each counted by the rules above (a function the document
  defines twice, `f <- function(...)` in two places, is rebound;
  `base::max` never is; `dict` and `dict_local` never are). A check is
  *rebound* when a name among its operands is, or an `expr` among them is.
  E87 then names the first rebound name in the check's text.
- **N126. Runs always.** A check *runs always* unless its construct sits in an
  arm of a span with more than one arm (`n`, `if`, `sign`, `list`), or the
  claim sits under an R `if`, `else`, `for`, `while` or `repeat`. A check
  that does not run always can be gone (N133) but covers nothing (N131).

**Implication**

- **N127. Which checks relate.** A check A *implies* a check B when every
  value that passes A passes B. weft decides it only between two readable
  checks on the same *pair*: the same two value operands (`name`, `dict` or
  `expr`, N122) in either orientation, or the same value operand against
  literals of the same kind (for `quantity`, the same unit). Two
  expressions are the same operand only when their normal forms are equal
  (N149): `max(t) < 5` and `max(t, na.rm = TRUE) < 5` are on two pairs, and
  neither implies the other. Between any other two checks the only
  implication is identity (the same key).
- **N128. Two names.** With A and B oriented the same way, A implies B in
  exactly these 10 cells (✓):

  | A \ B | `<` | `<=` | `>` | `>=` | `==` | `!=` |
  |---|---|---|---|---|---|---|
  | `<` | ✓ | ✓ | | | | ✓ |
  | `<=` | | ✓ | | | | |
  | `>` | | | ✓ | ✓ | | ✓ |
  | `>=` | | | | ✓ | | |
  | `==` | | | | | ✓ | |
  | `!=` | | | | | | ✓ |

  An ordering check that passes shows the two values are of a kind that
  orders, so it implies `!=` and its non-strict twin. `==` implies no
  ordering: two equal strings in the filter, or two equal factors in R, pass
  `==` and fail `<=` (a value error, an `NA`). `<=` does not imply `==` nor
  `<`; `>=` and `!=` together would give `>`, but no two checks are combined
  (N131).
- **N129. A name against literals** of kind `number`, `date` or `quantity`.
  A is `x opA a`, B is `x opB b`; B is implied exactly when the cell holds
  for the literals compared by N130 (— never):

  | A \ B | `x < b` | `x <= b` | `x > b` | `x >= b` | `x == b` | `x != b` |
  |---|---|---|---|---|---|---|
  | `x < a` | a ≤ b | a ≤ b | — | — | — | a ≤ b |
  | `x <= a` | a < b | a ≤ b | — | — | — | a < b |
  | `x > a` | — | — | a ≥ b | a ≥ b | — | a ≥ b |
  | `x >= a` | — | — | a > b | a ≥ b | — | a > b |
  | `x == a` | a < b | a ≤ b | a > b | a ≥ b | a = b | a ≠ b |
  | `x != a` | — | — | — | — | — | a = b |

  Against `string` and `bool` literals only the `==` and `!=` cells apply
  (an ordering against them is not readable, N121). A bool check `x`
  implies `x`, `x == TRUE` and `x != FALSE`; `!x` implies `!x`,
  `x == FALSE` and `x != TRUE`; nothing else implies either.

  The reasoning is over the reals, not the integers: `x > 4` does not imply
  `x >= 5`. In the filter a passing comparison with a number literal shows
  the value is a number (1.12.5). In R it is assumed: R compares a character
  or factor value with a number as text, where `"10" > "9"` is `FALSE`, so
  for such a value the table can be wrong; nothing static knows a value's
  class (N147). So `x > 5`
  implies `x > 3`, `x >= 5` implies `x > 4` and `x > 4.999` but not `x > 5`,
  `x == 5` implies `x >= 5.0` and `x != 3`, `x < 0` implies `x != 0`,
  `x != 0` implies only `x != 0`, `d >= '2024-02-01'` implies
  `d > '2024-01-31'`, `x < u(50, NTU)` implies `x <= u(60, NTU)` and
  nothing about `x < u(0.06, kNTU)`.
- **N130. Comparing two literals.** Numbers (and the numbers of two
  quantities) compare as exact decimals, by an R twin of `num_cmp()` in
  `weftlib/cond.lua` (`dec_cmp()`, giving the same result on every pair of
  the shared list in §5); no double decides. Where a cell needs a strict
  relation (a < b, a > b, a ≠ b) and B is checked by R (a claim, or a guard
  of a document the hooks resolve), the two literals must also differ when
  R reads each as a double (`as.numeric()` of the canonical text): R
  compares doubles, so `x >= 0.1000000000000000001` does not imply `x > 0.1`.
  A cell that needs a ≤ b, a ≥ b or a = b holds under both readings, because
  rounding to a double keeps order. Dates compare by their text (fixed width,
  so text order is calendar order). Strings and bools are equal or not,
  exactly.
- **N131. Covered.** A check B, gone from document D (N133), is *covered*
  when the new side of D holds one check A such that
  - A has B's key, or A implies B (N127 to N130);
  - A runs always (N126);
  - A's level is `fail`, or B's level is `warn` (a warned check fails
    nothing, so it covers only a warned one; a level `unknown` counts as
    `warn` when it covers and as `fail` when it is gone); and
  - B is not rebound in D on the new side (N125: neither its names nor
    the names and functions its expressions read).

  One check must do it alone: two checks are never combined (`x >= 5` and
  `x != 5` do not cover `x > 5`) and implications are not chained (`x > y`
  and `y > 5` do not cover `x > 5`). A check B that is not readable is
  covered only by a check with its key: the same text, white space
  collapsed, in D.

**The gate** (new spec 6.3.7)

- **N132. Reading.** On each side the gate reads the checks of every
  document with the reader of N120 to N126 and N149 to N151, from the same
  source it counts
  constructs on (`gate_reader()`, the parse trees `code_pieces()` already
  built for `inert-check`), and keeps them in the per-file cache entry beside
  `findings` and `constructs` (6.1.6). An entry without `checks` is a miss.
  When a side's `_weft.yml` does not read, the checks are read with the
  default settings, as the constructs are (6.2.8).
- **N133. Gone.** A check's *key* is its `cond` in key orientation (N124),
  or for a check that is not readable its text with white space collapsed,
  together with its level. Per project, a key is *gone* k times when the new
  side holds k fewer checks with it than the parent holding fewest (6.2.8).
  The count runs over the whole project, as the construct and finding counts
  do (6.2.3), so a check moved to another document, a guard rewritten as a
  claim with the same condition, or an edited sentence around an unchanged
  guard is not gone; a removal and an identical addition elsewhere net out,
  the limit of 6.3.6. A changed bound is a gone key: `x >= 5` edited to
  `x > 3` makes `x >= 5` gone.
- **N134. Which rows.** For a key gone k times, the rows listed are taken
  from that parent: first its rows on lines the commit deleted or changed (the
  `-` side of the `git diff -U0` hunks the gate already reads for added lines,
  G16), the last k of them in file and line order; when fewer than k are on
  such lines, the rest are the last of the others, as 6.3.4 picks.
- **N135. Verdict.** Each gone row gets the first that applies:
  1. `deleted`: its document is not on the new side (deleted or renamed).
     Its rows print as one line, E86;
  2. `rebound`: B is readable, the new side of D holds a check on B's pair,
     and B is rebound there (N125; for an expression, a name or function it
     reads): E87;
  3. `same`: covered (N131) by a check with B's key: E81;
  4. `implied`: covered by a check with another key: E82;
  5. `warned`: a check of D on the new side implies B and runs always, but
     every such check is warned or of level `unknown` while B is not: E84;
  6. `looser`: D still holds checks on B's pair, and none covers it: E83;
  7. `none`: D holds no check on B's pair: E85;
  8. `unread`: B is not readable and not `same`: E88.
- **N136. What is named.** E81 names the first check with B's key in D by line
  and the count of the others. E82 names, of the covering checks, the first in
  line order, and its line. E83 lists the checks on B's pair that run always,
  at any level, keeping only those that no other of them implies; each as
  `` `cond` `` and then " (line L)" for one place or " (N places)"; at most
  three, in order of first line, then ", and %d more". E87 to E85 name the
  file as the project path shows it.
- **N137. The report.** When the gate prints its full report (the commit
  fails, for any reason) and a key is gone, block E80 follows the block of
  constructs removed (or the findings block, when there is none) and comes
  before the notes and the time line: per file, in path order, the line
  `  <file>, as in HEAD`, then each gone row in line order as
  `sprintf("    %5d  %s", line, shown)`, `shown` being `cond` or the text,
  either cut at 70 characters as 6.3.4 cuts it (a `cond` holding a long
  expression is cut too), then its verdict on the next line,
  indented 11 spaces (under `shown`); a blank line after each file. A
  deleted document's heading is followed by E86 alone, indented four
  spaces.
- **N138. A passing run.** Before its one line, a passing run prints E89 for
  each gone row whose verdict is `rebound`, `warned`, `looser` or `none`, in
  file and line order, at most five, then E90 for the rest. `same`,
  `implied`, `deleted` and `unread` print nothing on a pass.
- **N139. Information only.** No verdict changes `ok`, N, or the trailer
  wanted (6.3.2). A construct removed counts as before even when its checks
  are all `same` (D36).
- **N140. The result.** A `weft_gate` gains `checks`: a data frame with the
  columns `project`, `file`, `line` (in the parent), `cond` (`shown` of
  N137), `level`, `verdict`, `by` (the covering check's `cond`, NA unless
  `same` or `implied`), `by_line` (its line on the new side, else NA) and
  `remains` (E83's list, else NA), sorted by project, file and line. It has
  no rows on a first commit.

**The report function** (new spec 3.10)

- **N141. `checks(path = ".", files = NULL, repeats = 3L)`**, exported.
  `path` and `files` are read as `lints()` reads them, with its errors
  (5.1.1). `repeats` is a whole number from 2, else E91, a `weft_lint_error`.
  Each document of the report set is read through `lint_open()`, the reader
  `lints()` uses, and its checks by N120 to N126 and N149 to N151 from the
  same parse trees (`code_pieces()`); nothing is run. The gate's cache does not apply: it is
  keyed on index and commit blobs, and `checks()` reads the work tree. A
  document that is not valid UTF-8 is skipped with a note.
- **N142. The value.** A data frame of class `weft_checks`, one row per
  check of N120 (all three roles), sorted by file, line and column, with
  the columns `file`, `line` (integers from 1), `role` (`guard`, `claim`,
  `branch`), `level` (`fail`, `warn`, `unknown`; NA for a branch),
  `value`, `op`, `other` (an expression in its normal form, N149), `cond`
  (N124 display orientation; NA when not readable), `text` (as written, white space collapsed), `always` (N126),
  `rebound` (N125), `flag` and `repeated`; the attribute `notes`.
- **N143. Flags.** A *group* is the readable rows with one `file` and one
  `value`. Every row of a group carries the group's `flag`: `""`, or
  `operators`, `literals`, or both joined by `"; "`:
  - `operators`: two rows of the group with the same `other` whose
    operators differ within one direction, `<` with `<=` or `>` with `>=`;
  - `literals`: two rows whose `other` are literals of one kind (and one
    unit), different by N130, with operators in one direction (`<` or `<=`;
    `>` or `>=`), or both `==`, or both `is` (`x` beside `!x`).

  Not flagged: a lower and an upper bound (`x > 0`, `x < 10`); several
  `!=`; `x == 5` beside `x >= 5`; one value against two different names.
  Branches and warned checks take part. A row that is not readable has
  `flag` `""`.
- **N144. Repeated.** `repeated` is, for a `guard` or `claim` row, the count of
  `guard` and `claim` rows of its file with its `cond` and its level; NA for
  a branch and for a row that is not readable.
- **N145. Printing.** E92, a blank line, then per file in path order: the
  file's path; per value in order of first line, two spaces, the value, and
  `  [<flag>]` when flagged, and `  (assigned in more than one place)` when
  its rows are rebound (for a value that is an expression,
  `  (reads a name assigned in more than one place)`); a value that is an
  expression with no other check in the file is a group of one, printed
  like any other (`max(turb)` in §2I); per distinct (`cond`, kind) in order of first line,
  kind being `check` (fail-level guards and claims), `warn` (warned or
  unknown), or `branch`, the line
  `sprintf("    %-*s  %*d  %s%s", w, cond, wn, n, where, tag)`: `w` the
  widest `cond` and `wn` the widest count in the file (the `not read` lines
  use the widest text among them); `where` "line L" or
  "lines L1, L2, ...", at most ten lines then ", and %d more"; `tag` ""
  for `check`, "  (warn)" or "  (branch)". Under a `check` line with `n` at
  least `repeats`, E93 indented six spaces. Then, when the file has checks
  that are not readable, `  not read` and one line per distinct text, cut at
  60 characters, in the same layout. A value heading and a `cond` longer
  than 60 characters (a long expression) are cut the same way, and `w` is
  taken after cutting. A blank line after each file. With no
  checks: E92's second form only. In E92 the checks are the rows, the values
  the groups (a value in two documents counts twice) and the flagged values
  the groups with a flag.
- **N146. Cost.** One read and one parse per document, as `lints()`; the
  reader adds a walk of the parse trees `inert-check` already walks, and one
  `parse()` and `deparse()` per distinct expression text (N149), memoised for
  the read. In the gate the rows are cached per blob with the rest of the
  file's entry, so a warm run parses no expression.

**Edges, limits and effects**

- **N147. Out of scope:** any claim about an R expression other than N121's
  forms (the approved scope: other checks are grouped by text); arithmetic
  and any meaning of an expression beyond its normal form (`x < 2 * lim`
  says nothing about `x < lim`; `max(t)` is not related to `max(t, u)`; the
  forms N149 does not normalise are different operands); an expression as a
  bool check, or with `.` inside it (D54); what a function the document
  defines reads, or whether it draws random numbers (§8, flag 8);
  combining or chaining checks (D38); the class of an R value (a
  character or factor value compared with numbers, N129); coverage across
  documents, the same
  name in two documents being two values under knitr and published per
  document by the filter (2.13.10; D40); quantities in different units;
  Python and Julia checks; `verify(since =)`, which keeps listing constructs
  only (8.2.2); the filter, which does not change.
- **N148. Effects.** The construct count and the trailer are unchanged
  (6.3); `inert-check` is unchanged; F5's `chunk_claims` does not change how a
  claim reads; F7's `decision` argument is not a check (N120). The cache's
  file entry gains `checks`, so the first gate run after 7j reads every
  document again, as any reinstall does (6.1.6). The existing pass-line test
  is unaffected (no check is gone in it); `test-gate-sides.R` pins the names
  of a `weft_gate` and gains `checks` (§5).

## 3. Decisions

| # | Point | Alternatives | Chosen | Why |
|---|---|---|---|---|
| D1 | Spelling of the plus | key `plus="true"`; key `sign="+"`; class `.signed`; class `.plus` | `.plus` (N1) | a flag is a class in weft (`.no`, `.cap`); `sign` is the governor key and cannot be reused; "plus" says what prints |
| D2 | A project setting for the plus | `plus: true` making every number signed; none | none (N10) | a sign belongs to a difference, not to a document: a global setting would print "+12 sites" |
| D3 | Glyph | a `plus` setting like `minus`; ASCII `+` | ASCII `+` | no house style in view asks for another; it is right in every format |
| D4 | Scope of `.plus` | also `.sci`, `pm()`, `#` of governors | `.num`, `.pct`, `.range`, collapse, `ci()` | what the trial hit; `pm()` and `.sci` can follow by the same rule if asked |
| D5 | Zero | "+0.0"; "±0.0"; no sign | no sign (N3) | matches the minus rule (a number that rounds to zero has no minus, 1.4.13) |
| D6 | `ci()` short form | `form = "short"`; `label = FALSE`; a new function; `short = TRUE` plus the setting `ci_short` | `short` and `ci_short` (N12) | one argument with an obvious meaning; a house style sets it once |
| D7 | `ci(pct = TRUE)` layout | "12% (95% CI 8 to 16%)"; "%" on every number | every number (N12) | that is what `.pct` prints, so there is no special case, and no number is read as a proportion |
| D8 | `short` with an explicit `level` | drop the level silently; error | error E4 | a 90% interval printed without its level reads as 95% |
| D9 | `.p` digits thresholds | keep "< 0.001" whatever d; scale with d | scale (N21) | "p = 0.000" must never print, and "p < 0.001" beside "p = 0.05" (d=2) mixes precisions |
| D10 | `.p` label key | `stat=`; `prefix=`; `label=` with `p_label` | `label` (N23) | reads as what it is; empty means no label, which Pandoc keeps (M5) |
| D11 | Where the output check runs | read the HTML, `.tex` and `.docx` files in the post-render script; a filter on the final tree | the filter (N50) | one reader for every format, measured (M1); reading LaTeX and docx reliably is a parser per format |
| D12 | Its own file or inside `weft-check.lua` | one file run twice | `weft-output.lua` | it must run after Quarto and `weft-check` before; `weft-check` stays self-contained (refactor-sweep ruling) |
| D13 | Citations in the check | include | out | invisible to any filter (M3); the `cite-key` lint covers keys |
| D14 | Severity | all fail; all warn | refs and markup fail, missing warns (N51) | no unresolved reference or broken fence is ever right; "NA" is sometimes an abbreviation, and `bare_missing` warns for the same text |
| D15 | A deliberate "NA" | a dictionary term list; a setting of allowed words; `.weft-literal` | `.weft-literal` (N53) | marks the one occurrence, as the numeral lint does; the filter cannot read `dict.yml` |
| D16 | F3 in the filter path | Pandoc `Table` digests in Lua now; later | later | Jupyter's HTML tables reach Pandoc as raw HTML or as tables depending on Quarto's HTML table processing, which runs at a stage not measured here; the knitr path is where the trial's tables were |
| D17 | Chunk claims setting scope | `_weft.yml` only; per chunk option; project and document | project and document (N70) | as every setting; a chunk option would make one document's claims behave two ways |
| D18 | What a collected claim returns | `NA`; an error value; `x` | `x` (N71) | the code runs as if the check passed, which is what `level = "warn"` does; the failure still fails the render |
| D19 | A later error | let it stop with its own message; wrap it | wrap, with the original as parent (N74) | the project's worst trap was a failure hidden by the next one; the claims are the likely cause and come first |
| D20 | Wrap every error after any collected failure | yes | only after an N71 claim | an ordinary error keeps its class in every document that does not opt in |
| D21 | Targets | collect there too | stop (N72) | a target that returns a value that failed its claim is stored and served as good |
| D22 | Guest claims under `collect` | now | later | needs the setting passed into two back ends and a value-returning path in each |
| D23 | Forward name with several values | warning, print the last; error | error (N93) | a warning would print a value the sentence may not mean, which is the defect weft exists to stop |
| D24 | "One value" | the same block; equal JSON text; equal records without checks | equal records without checks (N91) | equal values published twice (R auto plus `weft_put()`) must count as one; checks may differ by where they were attached |
| D25 | Forward references opt-in | a setting | none (N99) | it turns today's failures into values and changes nothing that renders now |
| D26 | Inline R forward references | a placeholder resolved by the `document` hook | not covered; hint E43 | the expression's value does not exist at its point; deferring R evaluation would change `claim()` and condition timing for every value; the named value already defers |
| D27 | Decision pointers in the ledger | record them | not recorded (N105) | a pointer prints nothing; recording it would churn the ledger |
| D28 | `range` YAML form | `{lower, upper}`; two items | two items `[lo, hi]` (N110) | the shape `.range` takes; the reader names them |
| D29 | Range test function | `within()`; `between()`; `%within%`; `in_range()` | `in_range()` | the first three are base R, dplyr and lubridate names |

| D30 | What counts as a table | every output; `knit_asis` only; `knit_asis` and asis text | `knit_asis` and asis text (N30) | that is what reaches the reader as table or prose; verbatim printing is code output |
| D31 | Granularity | per chunk; per cell; per output element | per element, chunk label and occurrence (N31) | says which of two tables changed; cells multiply churn, which the owner declined (option iii) |
| D32 | What is hashed | the raw text; the data behind it; the visible text | visible text (N33) | raw gt, flextable and tinytable HTML changes on every render (M7); a `knit_asis` object holds no data; visible text is stable (M8) and a style change is not a change of numbers |
| D33 | Identity | position in the file; knitr's label; the label as an id | label as id, `""` and occurrence when unlabelled (N31) | labels are unique in a document; generated labels shift when a chunk is added |
| D34 | Ledger version | bump to 2 | keep 1 (N38) | the change is one new value of an existing field; nothing is released yet |

| D35 | What the gate compares for F9 | the construct rows it lists today; a check-by-check diff of each document; check keys counted over the project, coverage judged in the document | keys over the project, coverage per document (N133, N131) | the construct rows know no condition (a guard's text is the whole span with its prose) and are listed only when a total fell; a per-document diff would report every moved check; the project count matches 6.2.3 and 6.3.6 |
| D36 | Does F9 change the verdict or the trailer | subtract checks covered by an identical one from N; fail on a looser removal; information only | information only (N139) | the trailer counts constructs, and deleting a sentence removes its prose whatever its guard; a failure would need the static reasoning to be complete, which it is not (N147) |
| D37 | Can a warned check cover a removed fail-level one | yes, with a note; no | no; a verdict of its own, `warned` (N131, E84) | a warned check fails nothing (3.1.11), so what the document guaranteed is gone; saying which warned check remains tells the writer what to promote |
| D38 | Combine two remaining checks | interval reasoning over all checks of a pair; one check alone | one alone (N131) | a table a test writer can pin (N128, N129) and a verdict the reader can check by eye; the cost of "no" is a `looser` that a reader can see is not, which is the safe side |
| D39 | Integers or reals | integers when the value looks whole; reals | reals (N129) | nothing static knows a value is whole; `x > 4` read as `x >= 5` would cover a check that fails on 4.5 |
| D40 | Scope of "remaining" | the project; the values that reach the name; the document | the document (N131, N147) | the same name in two knitr documents is two values, and the filter publishes per document (2.13.10); a dictionary read is one value, but a check of `x` against `dict$k` is about `x` |
| D41 | A name assigned twice | positions within the document; ignore; no coverage | no coverage, verdict `rebound` (N125, N135) | the lines of a check in `HEAD` and of one in the commit are in two revisions, so positions do not compare without a diff of meaning; the syntactic count is cheap and errs to "not covered" |
| D42 | What `.` stands for | the value expression only; also the piped value; also the assigned name | all three, in that order (N123); since D50, a usable value expression fourth (N123, rule 4) | `n <- claim(expr, . >= 10)` is exactly "check it where it is made", which the article recommends (7i); a reader that could not read it would list the recommended form as not read; the name comes before the expression so that the recommended form groups under the name used in the prose |
| D43 | Two-arm `if` conditions | ignore; count as checks; report only | `checks()` only, role `branch` (N120) | a branch fails nothing, so removing it loosens nothing; but `[above]` at `x > lim` beside `[above]` at `x >= lim` is the same sloppiness the owner described, at the boundary |
| D44 | The function's name and arguments | `check_report()`; `claims()`; `checks()`; `root =` | `checks(path, files, repeats)` (N141) | a plural noun as `lints()` and `changes()`; it reports guards too, so not `claims()`; `path` and `files` as `lints()` takes them; the name is free in the namespace |
| D45 | Quantity literals | not read; read in one unit; convert units | one unit (N122) | `. < u(50, NTU)` is weft's own idiom (the gate article's example); same-unit comparison needs no units data, conversion would |
| D46 | What a passing run prints | nothing; every gone check; the looser ones as notes | the looser ones, at most five (N138) | a changed bound passes with no trailer (6.3.3) and is the likeliest silent loosening; covered ones need no word |
| D47 | Which gone row is listed | the last, as 6.3.4; those on deleted lines first | deleted lines first (N134) | of nine identical checks the one shown should be the one the commit touched; the gate already runs the diff (G16) |
| D48 | Literal comparison | exact decimals; doubles; exact decimals, and doubles too for a strict relation in R | the last (N130) | the filter compares decimals (1.12.5) and R compares doubles; requiring both for a strict cell keeps every implication true under either evaluator, and never matters below 16 significant digits |
| D49 | When two conditions are flagged | any two conditions differ; same direction only | same direction (N143) | `x > 0` with `x < 10` is a range, written on purpose; a flag on every range would bury the `>`/`>=` case |
| D50 | A value expression as an operand (§9 q4; ruled by the owner, 14 Nov: "should the check comparison also group a repeated expression - yes") | out, grouped by text; read only a claim's value; read as either side of a comparison in a claim or a hooks guard | either side, in claims and in guards of documents the hooks resolve; not in the filter, whose grammar has no calls (N122, N151) | `claim(max(turbidity), . < u(50, NTU))` is weft's own idiom (flag 7); one rule for both sides keeps N124 and N127 to N129 as they are, with "name" read as any value operand; a guard and a claim on one expression must compare, as a guard and a claim on one name do |
| D51 | An expression that occurs once | not read until its text recurs in the document; read, a group of one | a group of one (N122) | readability must be a property of the check alone: if it hung on a count, deleting one of two copies would change the key of the copy that remains, and the gate would report a gone key that is not gone; a group of one compares nothing, so reading it claims nothing |
| D52 | An expression's identity | the text with white space collapsed; the parse data's tokens joined; `deparse()` of the parsed operand | `deparse()`, outer parentheses removed (N149) | white space, line breaks, comments, quote marks and the native pipe stop mattering, in a few lines; normalising argument order, prefixes or arithmetic would need knowledge of each function, and an unnormalised form errs to "two values", the safe side; the extra parse is of one short text, once per distinct text |
| D53 | When an expression is usable, and arithmetic | the owner's wording only (recurs, no symbol rebound); a list of safe functions; a rule and a list of unsafe ones; arithmetic out | a rule and the list `CHECK_UNSAFE_FNS` (N150); rebinding as for a name (N125); arithmetic in, by identity only (N151) | a safe list would leave most of R unread; the rule catches what the parse data shows (assignment, definitions, blocks, method calls, a `.`), the list the common calls whose value changes between two evaluations or hides what it reads; rebound expressions stay readable but never cover or are covered (N131, N135), which is the owner's condition with the machinery names already have; `x < 2 * lim` read by identity is sound, and refusing it would need a second rule |
| D54 | An expression as a bool check, and `.` inside an operand | read both; read neither | neither (N121, N150) | `all(x)` as a bool check implies only itself, which the text key already gives; `mean(.) > 3` would need `.` substituted into an expression, and the case is rare beside `m <- mean(x)`, which reads |

## 4. Work packages

Each package is one implementer session; its test-writer works from §2 and
§5. NAMESPACE and `man/` are regenerated with roxygen after each merge.

| Pkg | Creates | Edits | Tests |
|---|---|---|---|
| **7s** settings (N12 `ci_short`, N25, N51, N70) | | `R/config.R` (defaults, validation, E8, E9, E20, E30), `inst/quarto/weftlib/config.lua` (`p_digits`, `p_label`, `output_refs`, `output_missing`, `output_markup`) | `test-config-7.R`, `test-filter-config-7.R` |
| **7a** F1, F2 in R | | `R/format.R` (`.plus` in `print_one()`, `format_numbers()`, `collapse_range()`, `vowel_sound()`; `print_p()` with d and label; shipped classes; E1, E2, E5 to E7), `R/phrases.R` (`ci()`), `R/scan.R` (`.plus`, `label` errors from the source), `R/conformance.R` (rows of N14, N28); the `.tsv` files regenerated | `test-plus.R`, `test-ci-forms.R`, `test-p-digits.R` |
| **7b** F1, F2 in the filter | | `inst/quarto/weftlib/num.lua` (`plus`; `format_p(record, config, keys)`), `weftlib/words.lua` (`collapse_range` sign, `vowel_sound` plus), `inst/quarto/weft.lua` (class `.plus`, key `label`, E1, E2, E5 to E7), `inst/quarto/weft-check.lua` (`plus` among the classes) | `test-lua-plus.R`, `test-lua-p.R` (and the existing conformance tests, which now carry the new rows) |
| **7c** F3 | `R/tables.R` | `R/conditions.R` (the evaluate hook digests tables), `R/ledger.R` (`table` kind), `R/changes.R` (compare and print) | `test-ledger-tables.R`, `test-changes-tables.R` |
| **7d** F4 | `inst/quarto/weft-output.lua` | `R/use.R` (copy the file; the `_quarto.yml` mapping entry), `R/setup.R` and `R/use-weft.R` (`pandoc_args`; `status()` row), `inst/quarto/weft-post-render.R` (`output` lines, format grouping), `R/verify-render.R` and `R/verify.R` (`WEFT_OUTPUT_LOG`, `output`) | `test-output-check.R`, `test-output-quarto.R`, `test-use-quarto-output.R`, `test-verify-output.R` |
| **7e** F5 | | `R/claim.R` (N71, N72), `R/conditions.R` (N74 in the evaluate hook), `R/hooks.R` (N74 on a bare value's error) | `test-chunk-claims.R` |
| **7h** F8 | | `R/dict.R` (type, reader, problems, print), `R/dict-tools.R` (glossary), `R/phrases.R` (`in_range()`), `R/changes.R` (`dict_numbers()` bounds) | `test-dict-range.R` |
| **7f** F6 | | `inst/quarto/weft.lua` (pre-pass over the blocks; fallback; E40 to E42), `R/resolve.R` (hint E43) | `test-filter-forward.R`, `test-forward-knit.R` |
| **7g** F7 | | `R/scan.R` (E50, E51), `R/resolve.R` (strip `decision`), `R/claim.R` (N103), `R/constructs.R` (pointer rows from claims), `R/decisions.R` and `R/verify.R` (document pointers), `inst/quarto/weft.lua` (N106) | `test-decision-pointers.R`, `test-filter-decision.R` |
| **7i** spec and articles (§6, §7a) | | `dev/PACKAGE-SCOPING.md`, vignettes | none |
| **7j** F9 | `R/checks.R` (the reader of N120 to N126 over `src$rows` and `code_pieces()`; expression operands, N149 to N151, with `CHECK_UNSAFE_FNS` and the memoised normal form; `dec_cmp()`; the relation of N127 to N130; coverage, N131; `checks()` and `print.weft_checks()`; E91 to E93) | `R/gate.R` (`checks` in the file cache entry and in `gate_fallback_constructs()`'s fallback; gone keys and verdicts in `gate_judge_project()`; `checks` in `gate_assemble()`; the block of N137 and the notes of N138 in `gate_report_lines()`; E80 to E90), `R/gate-git.R` (`git_added_lines()` also returns the deleted lines of the `-` side) | `test-checks-read.R`, `test-checks-imply.R`, `test-checks-report.R`, `test-gate-checks.R`; one line of `test-gate-sides.R` |

Sizes, in lines of code without tests: 7s 80; 7a 250; 7b 200; 7c 250; 7d
400; 7e 120; 7h 200; 7f 120; 7g 250.
7j (F9) 690: reader 340 (of which expression operands 90: normal form 25,
usability and the list 45, `.` binding and rebinding 20), relation and
coverage 120, gate 130, `checks()` and print 100.

**Order and parallel groups.**

1. **7s** alone, first: every later package reads a setting.
2. In parallel: **7a**, **7c**, **7d**. Their file sets do not meet (7a:
   format, phrases, scan, conformance; 7c: conditions, ledger, changes, a
   new file; 7d: a new filter, use, setup, post-render, verify).
3. In parallel: **7b** (after 7a: it needs the regenerated tables), **7e**
   (after 7c: both edit `R/conditions.R`), **7h** (after 7a for
   `R/phrases.R`, after 7c for `R/changes.R`). Their files do not meet.
4. **7f** after 7b (`weft.lua`).
5. **7g** after 7f, 7e, 7d and 7a (`weft.lua`, `R/claim.R`, `R/verify.R`,
   `R/scan.R`; and `R/resolve.R` after 7f).
6. **7i** last.

**7j** (F9, approved after this order was set) edits files no other
package edits (`R/gate.R`, `R/gate-git.R`, a new `R/checks.R`) and only
reads `R/scan.R` (`COND_RE`, `cond_parts()`), `R/lint-code.R`
(`code_pieces()`, `pd_tree()`, `node_text()`, `subtree()`, `pipe_lhs()`,
`call_info()`, `dict_reads()`) and
`R/constructs.R` (`claim_calls()`); it reads no setting. It must follow
7a, which edits `R/scan.R`, whose functions it calls. It runs beside 7g in
step 5: 7g edits `R/scan.R` and `R/constructs.R` only by adding errors and
pointer rows, and N120 skips a `decision` argument by its name whether or
not 7g has landed. 7i follows it.

This keeps the agreed order (plus sign, C, D, A, then the rest): 7a and 7b
are F1 and F2, 7c is C, 7d is D, 7e is A.

**What would stop a package.**

- 7a: a regenerated conformance row other than the new ones changes. Stop
  and report: `.plus` must not touch an unsigned construct.
- 7c: under Quarto's knitr engine the evaluate hook does not see
  `knit_asis` values as M6 found under rmarkdown, or a gt table's visible
  text differs between two Quarto renders. Stop and report the texts.
- 7d: `at: post-render` in `_quarto.yml` does not run the filter for a book
  project's chapters, or runs it once per book instead of per chapter.
  Stop and measure before writing the installer.
- 7e: knitr calls the evaluate hook so that a condition raised in its error
  branch is not the one the render reports (Quarto's knitr wrapper prints
  its own text). Stop and measure the text Quarto shows.
- 7f: a document's `weft-values` blocks cannot all be found before the main
  pass (a block knitr writes inside a list item, a caption, a cell div):
  the pre-pass must find every block the main pass reads.
- 7j: `test-gate-perf.R`'s ratio fails once checks are read, or the parity
  cases of `test-gate-cache.R` give different `checks` from a cold and a warm
  cache. Stop and report the timings or the rows: the reader must take its
  parse trees from `code_pieces()`, not parse a piece again; the only parse
  it adds is of one expression operand's text, once per distinct text
  (N149). Also stop and report if the source text of a native pipe's left
  side (`pipe_lhs()`, `node_text()`) does not parse alone, or if
  `deparse()` gives two texts for one expression within one session
  (a non-ASCII string, a long call broken over lines): N149's identity
  rests on both.

## 5. Tests

Helpers: the existing `helper-lua.R` and `helper-filter.R` (`filter_md()`,
which gains an argument `post = TRUE` that appends
`--lua-filter <inst>/quarto/weft-output.lua` last), `helper-5.R`, the knit
helpers of `test-trial-fixes.R` (`d2_run()`), and a skip
`skip_if_no_quarto()` for the Quarto renders of 7d. Each file below names
the N rules it pins; every message is pinned by its E text with `%s`
filled.

- `test-config-7.R` (7s): each new setting's default; each wrong value gives
  its E text and class `weft_config_error`; a document's `weft:` overrides
  `_weft.yml`; `p_label: ""` is accepted.
- `test-filter-config-7.R` (7s): the Lua reader reads `p_digits: 3`,
  `p_label: ""`, `p_label: "q"`, `output_missing: off`; a wrong value is E33
  once and the default is used.
- `test-plus.R` (7a): N1 to N9, N11, N14 by `fmt_num()`, `fmt_pct()`,
  `fmt_range()` and by knitting `.Rmd` lines: every example of N2 to N7
  exactly; the warned check of N3 still recorded once; E1 for each class of
  N8, E2 for each governor key, the value error on `ci()` text; E3 for
  `plus = "yes"`; a document with no `.plus` knits byte-identical to before
  (one fixture, pinned output); `.plus` alone implies `.num`.
- `test-ci-forms.R` (7a): the five outputs of N12; `ci_short: true` with
  `short = NULL`; `short = FALSE` beating `ci_short: true`; E4 for
  `ci(1, 0, 2, level = 0.9, short = TRUE)` and under `ci_short: true`; no
  E4 with `ci_level: 0.9` and short; `pct = TRUE` with `pct_proportion:
  false`; the printed-as-zero check judged on the percentage
  (`ci(0.0004, 0.0001, 0.0009, pct = TRUE)` warns once).
- `test-p-digits.R` (7a): every example of N21 to N23; E5 for `digits="0"`,
  `"7"`, `"1.5"`; E6; E7 on `.num`; `p_digits` and `p_label` from settings,
  and a key winning; `fmt_p(x, digits = 3, label = "q")`.
- `test-lua-plus.R`, `test-lua-p.R` (7b): the same examples on named values
  through `filter_md()`, texts equal to R's; E1, E2, E5 to E7 with R's text;
  every row of the regenerated `numbers.tsv`, `collapse.tsv`, `text.tsv` and
  `p.tsv` (the existing conformance tests read them).
- `test-ledger-tables.R`, `test-changes-tables.R` (7c): N30 to N40 on knit
  fixtures: a kable chunk, a chunk with two kables (`occ` 1 and 2), an
  asis chunk with two `cat()` calls, an unlabelled chunk (`expr` `""`, `id`
  null), a `print(df)` chunk (nothing), `include: false` and
  `results: "hide"` (nothing), `cat("\n")` (nothing); one ledger line pinned
  byte for byte; N33 on fixed strings (each step, "x < 5 and y > 3" kept);
  gt, flextable and tinytable each rendered twice to HTML give equal digests
  (skip when not installed); one changed cell changes the digest, a changed
  `gt::tab_options()` style does not; a cached chunk served from the cache
  replays its table rows; `ledger: false` writes none; `changes()` printing
  E70 with the caption, E71 and E72 (eleven added tables give ten labels
  then " and 1 other"; twelve give " and 2 others"), nothing under
  `brief = TRUE`; the rest of an existing ledger fixture unchanged.
- `test-output-check.R` (7d, plain Pandoc through `filter_md(post = TRUE)`,
  with no Quarto so N52 does not apply): N53 for each token, with each kind
  of attached punctuation, in each prose container of N53, and not in each
  excluded place (a table cell, code, a raw block, a `.weft-literal` span and
  div, "Na", "N/A"); N54 for each pattern and not for `]{.x}` or "{ .x"; N55's
  record exactly (section, excerpt cut); N56 without a collection file (E25,
  exit 1 for `fail`, exit 0 with only `warn`, exit 0 in draft mode); each
  setting at `off`, `warn` and `fail`; `WEFT_OUTPUT_LOG` receives one JSON
  line per finding.
- `test-output-quarto.R` (7d, Quarto): a project set up by `use_quarto()`,
  one document with `@sec-missing`, `{{< meta nosuch >}}` and "NA":
  rendered to `html` and to `latex`, the post-render report holds one
  `[unresolved reference] ?@sec-missing` entry with "(html, latex)", one for
  `?meta:nosuch`, one warned `NA`, and the render exits 1; with
  `output_refs: warn` it exits 0. A Jupyter-free markdown engine document is
  enough (no R in the render).
- `test-use-quarto-output.R` (7d): `use_quarto()` on a new project, on a
  project with `filters: [weft-check]` (the entry added after it), run twice
  (no second entry); the mapping entry as N50 writes it, byte for byte;
  `status()` naming the missing entry; `use_setup()` under rmarkdown putting
  `weft-output.lua` last in `pandoc_args`.
- `test-verify-output.R` (7d): `verify()` on a project with one unresolved
  reference: `output` has one `fail` row, the render part failed; with only a
  warned `NA`, `ok` is `TRUE` and the row is listed.
- `test-chunk-claims.R` (7e): N70 to N79: under `collect` two failing chunk
  claims and a passing one: the knit reaches the end, `last_knit()` holds two
  failures with the chunk labels, the render fails once with both in E-order;
  `claim()` returned its value (a later chunk prints it); under `stop` the
  first stops as today; outside a knit it stops; a function defined in a
  chunk and called later; a `source()`d file; `level = "warn"` unchanged;
  `try(claim(...))`; a chunk with `error: true`; N74: a claim then an
  `stop("boom")` in a later chunk gives class `weft_claims_collected`, E31's
  first line, the claim before "boom" in the message, and the parent's
  message "boom"; the same `stop()` with no collected claim keeps its class;
  N72 with `targets` mocked (`tar_active()` returning `TRUE`) stops;
  `rehearse()` with two cases lists the claims per case.
- `test-dict-range.R` (7h): N110's problems each with its text and the
  entry's line; the reader's value with and without `unit` and `display`;
  `.range` output; `in_range()` on numbers, quantities, `NA`, unit mismatch
  (E60), a bad range (E61); `changes()` reporting "crosses a dictionary
  threshold" at each bound; `print()` of the dictionary.
- `test-filter-forward.R` (7f, plain Pandoc, blocks written by hand): N90 to
  N96: a name used above its only block; above two equal blocks; above a
  block and a values file that agree; above two blocks that differ (E40 with
  2, E41, render fails); above none (E42); a governor (`if="n > 3"`) above
  its block; a record with a failing check run at the forward use; a use
  below a publication taking the value above it, not the last; a caption
  unchanged; a `missing` record forward gives today's missing failure; the
  ledger entry's text.
- `test-forward-knit.R` (7f): an `.Rmd` with `` `n_sites`{.count} `` above
  the chunk that assigns it, rendered with the filter: prints the value;
  `` `r n_sites` `` above the chunk gives the "no value" failure with E43 as
  its hint; `` `r n_sites + 1` `` does not get E43.
- `test-decision-pointers.R` (7g): N100 to N105: E50, E51 from the source and
  at knit; `decision` gone from the output of a literal and a cite span (the
  `why` too); `claim(..., decision = 31)` failing in prose and outside a knit
  with "; decision 31"; E52 for `""`, `0`, `c(1, 2)`, `TRUE`; `verify()` rows
  for a literal, a cite span and a claim (glob resolver over a temporary
  `decisions/` folder: one resolves, one does not, verify fails); the part
  skipped with "skipped: no decision pointers"; a ledger byte-identical with
  and without a pointer.
- `test-filter-decision.R` (7g): N106 on named-value documents.
- `test-checks-read.R` (7j, `read_src()` of `helper-3.R`, nothing knitted):
  N120 to N126, each by the row's `role`, `level`, `value`, `op`, `other`,
  `cond`, `always`, `rebound`: a guard `if="x > 5, y != 'a'"` in a hooks
  document and in a filter document (two readable rows each, the same);
  `if="y <= 'a'"` in both (one row, not readable); a branch `[a | b]{if="x > 5"}`; `claim(foo, . > bar)`,
  `foo |> claim(. > 0)`, `n_up <- claim(sum(z), . >= 10)`,
  `claim(sum(z), . >= 10) -> n_up`, `claim(sum(z), . >= 10)` (reads
  `sum(z) >= 10`),
  `claim(x, y > 3)`, `claim(x, . > 0, level = "warn", decision = 31)` (one
  row, `warn`), `claim(x, . > 0, level = lv)` (`unknown`),
  `function(v) claim(v, . > 0)` (not readable); `5 < x` as `x > 5`; `x >= 5.0`,
  `x > 1e3`, `x > .50`, `x > -2L`, `x > -0`, `x > 1e-25` with the canonical
  literals of N124; `"a"` and `'a'` alike, `"it's"` in double quotes; a date
  literal and a non-date string; `TRUE == x` as `x == TRUE`; `x` and `!x`
  in their own form (`op` `is`), in a guard and as `claim(x, .)`;
  `x < u(50, NTU)`; `dict$k`, `dict[["k"]]` and `dict$"k"` all `dict$k`, and
  `dict$k` in a document with a local `k` not readable; two names keyed in
  byte order and shown in the first occurrence's orientation; not readable:
  `all(x)`, `x > 5 && y`, `x %in% s`, `x > Inf`, `x > 0x10`, `x > NULL`,
  `x > 1/3`, `'a' < x`, `x > x`, `max(x) > max( x )`; a claim in an `eval: false` chunk and in indented code
  (no row); a Python `claim(` (one row, not readable); `always` FALSE for a
  guard in an arm of a two-arm span and for a claim under `if (ok)` and in a
  `for` body; `rebound` for `x <- 1` and `x <- 2`, for `x$a <- 2` after
  `x <- 1`, for one `for (x in s)`, for two Python `x = ` lines, and not for
  one assignment with a `weft_put()` beside it, nor for `x == 1` lines in
  Python. Expression operands (N122, N123 rule 4, N149 to N151):
  `claim(max(turbidity), . < u(50, NTU))` reads `max(turbidity)`, `<`,
  `u(50, NTU)`; so do `turbidity |> max() |> claim(. < u(50, NTU))`,
  `claim(max( turbidity ), ...)`, `claim((max(turbidity)), ...)` and the
  call over two lines with a comment between them; `claim(f(x, 'a'), . > 0)`
  has `value` `f(x, "a")`, `claim(f(x, 5.0), . > 0)` `f(x, 5)` and
  `claim(f(x, 1e3), . > 0)` `f(x, 1000)`; `claim(f('a'), . > 0)` reads no
  name and is not usable (N150 rule 1); each of `max((t))`,
  `base::max(t)`, `round(t, 1)`, `round(t, digits = 1)`,
  `t %>% max()` and `max(t, na.rm = TRUE)` a value of its own;
  `n <- claim(max(t), . < 5)` reads `n < 5`; a single expression check in a
  document gives one readable row; a hooks guard `if="max(t) < 50"` reads as
  the claim does, and the same guard in a filter document gives one row,
  not readable; `x[1] > 5`, `x + 1 > 5` and `-x < 0` readable with `value`
  `x[1]`, `x + 1`, `-x`; `x < 2 * lim` keyed `2 * lim > x` and shown
  `x < 2 * lim`; `50 > max(t)` as `max(t) < 50`; `max(a) > min(b)` (two
  expressions); not readable, one case for each item of N150:
  `1/3 < x` and `claim(rnorm(1), . < 0.5)` (no name read),
  `claim(runif(n), . < 0.5)`, `claim(base::sample(s, 1), . > 0)`,
  `Sys.time() - t0 > 5`, `claim(readLines(f)[1], . == 'y')`, `get(nm) > 5`,
  `claim(x, mean(.) > 3)`, `x %>% max(.) %>% claim(. < 5)`,
  `claim((y <- f(x)), . > 0)`, `claim(sapply(s, \(v) v + 1), . > 0)`,
  `claim({ f(x) }, . > 0)`, `claim(obj$size(), . > 0)`,
  `max(dict$k) > 5` in a document with a local `k`; `claim(all(x), .)`
  and `claim(max(x), !.)` (an expression is not a bool check);
  `rebound` TRUE for `max(turbidity) < 5` when `turbidity` is assigned twice,
  when `turbidity[3] <- NA` follows one assignment, and when `f` is defined
  twice for `f(t) < 5`; FALSE for `base::max(t) < 5` beside `max <- 1` and
  `max <- 2`, and for `max(dict$k) < 5`.
- `test-checks-imply.R` (7j, the internal relation, no files): all 36 cells
  of N128 (10 true); all 36 cells of N129 for each of a < b, a = b and a > b (108
  cases), on numbers, and the same 108 on dates and on quantities of one
  unit; quantities in two units never; strings and bools in their four
  cells; the bool checks `x` and `!x` against each of the six bool forms; every example of N129's last paragraph; the strict-cell double guard
  (`x >= 0.1000000000000000001` against `x > 0.1` in a claim: no, though exactly
  a > b, because as doubles the two are equal; in a filter guard, which
  compares decimal texts: yes); `dec_cmp()` equal to `cond.lua`'s `num_cmp()` (through
  `helper-lua.R`) on a shared list of at least 30 pairs (signs, zeros, `-0`,
  exponents, trailing zeros, 25 digits); N131: identity, one implying
  check, a warned one covering only a warned one, an `unknown` level both
  ways, a check that does not run always covering nothing, `x >= 5` with
  `x != 5` not covering `x > 5`, `x > y` with `y > 5` not covering `x > 5`.
  Expression operands (N127, N151): `max(t) < lim` implies `max(t) <= lim`
  and `max(t) != lim`; `max(t) < u(50, NTU)` implies `max(t) <= u(60, NTU)`;
  `x < 2 * lim` implies `x <= 2 * lim` and nothing about `x < lim`,
  `x < 3 * lim` or `x < lim * 2`; `max(t) < 5` and `max(t, na.rm = TRUE) < 5`
  unrelated both ways; a rebound `max(t) < 5` covering nothing (N131).
- `test-checks-report.R` (7j): `checks()` on a project of two documents:
  the columns and types of N142 and the sort; each flag of N143 and each "not
  flagged" case; `repeated` and E93 at `repeats = 3` with three identical
  checks and not with two, and at `repeats = 2`; branch rows flagged and never
  counted in `repeated`; the print of N145 pinned byte for byte for one
  document (two values, one flagged, a hint, a `(warn)` line, a `(branch)`
  line, a `not read` block, a value with eleven lines); E91 for `repeats = 1`,
  `2.5`, `"3"`; `files` errors with `lints()`'s texts; a project with no checks
  prints E92's second form. The print of §2I byte for byte (its `max(turb)`
  group of one and its `not read` line). Expressions: three
  `claim(max(turbidity), . < u(50, NTU))` and one
  `claim(max( turbidity ), . <= u(50, NTU))` form one group `max(turbidity)`
  flagged `operators`, and `repeated` 3 with E93; `max(t)` and
  `base::max(t)` two groups; a rebound expression's heading with
  `  (reads a name assigned in more than one place)`; an expression of 80
  characters cut at 60 in its heading and in its line, `w` measured after
  cutting.
- `test-gate-checks.R` (7j, git through `g_scenario()` and `g_gate()` of
  `helper-4a.R`): the owner's case, nine `foo > bar` guards and one
  `foo >= bar`, deleting the `>=` sentence: verdict `implied`, E82; the
  mirror, deleting the `>`: `looser`, E83 with "`foo >= bar` (9 places)";
  deleting one of ten identical guards: `same`, E81 with "and 8 other
  places"; `none` (E85), `warned` (E84), `rebound` (E87), `unread` (E88), an
  unreadable check whose text remains elsewhere in the document (`same`); a
  deleted document (one E86 line); a guard moved to another document, a guard
  rewritten as a claim with its condition, and the prose around a guard
  edited: nothing gone; a bound edited from `x >= 5` to `x > 3` with no
  construct removed: the commit passes with one E89 note; to `x > 7`: passes
  with no note; six looser checks on a pass: five E89 and E90; the row on the
  deleted line listed among identical ones (N134); `ok`, `n_removed` and the
  trailer wanted identical to a run without F9 on every edit of
  `_gate/edits.R` (N139); `res$checks` columns of N140, empty on a first
  commit; a second run served from the cache gives identical `checks`.
  Expressions (N149 to N151), each in a document of
  `claim(max(turbidity), ...)` inline values: deleting one of three
  identical claims: `same`, E81; deleting the `< u(40, NTU)` claim while
  `< u(50, NTU)` claims remain: `looser`, E83 naming
  `` `max(turbidity) < u(50, NTU)` `` among what remains; deleting a `<= u(50, NTU)`
  claim while a `< u(50, NTU)` claim remains: `implied`, E82; respacing
  `max( turbidity )` or rewriting it as `turbidity |> max()`: nothing gone;
  rewriting it as `base::max(turbidity)`: gone, `none` when no other check
  on `max(turbidity)` remains (the safe side, N149); `turbidity` assigned in
  two chunks: `rebound`, E87 naming `turbidity`; a deleted
  `claim(runif(n), . < 0.5)`: `unread`, E88 with its new text.
  `test-gate-sides.R`'s set of `weft_gate` names gains `checks` (the one
  existing test 7j changes, by its test writer).

## 6. Spec changes (for 7i)

- **1.4.1** stage table: `.plus` in stage i, not in a group. **1.4.3** row
  for `.plus`. **New 1.4.21** N1 to N8 and N10. **1.4.4** N6's joiner.
  **1.4.5** N7. **1.4.17** N20 to N25. **1.4.7** `label` (`.p` only).
- **3.4** `fmt_num()`, `fmt_pct()`, `fmt_range()` `plus`; `fmt_p()`
  `digits`, `label`. **3.5.3** `ci()` N12.
- **7.1.1, 7.1.4, 7.3.3, 7.3.9** tables (§2C).
- **2.5.3** a new item: the output filter, pointing to **new 2.5.5**, N50 to
  N59. **2.6.6** findings from the output filter in the collection file.
  **8.3** `output` in `verify()`.
- **2.4.1, 2.4.2, 2.4.4, 2.4.5** N70 to N79 (the exception to "stops at
  once", and N74's report). **3.1** `decision` argument (N103).
- **1.12.7** N90 to N95 replace "A name used above any publication of it is a
  'no value' failure".
- **1.8.10, 1.8.11, new 1.8.12** N100 to N102, N106. **4.5** pointers beyond
  the dictionary (N104). **5.3** E50, E51 among construct errors.
- **4.2.1** the `range` row and the `unit`/`display` rule; **new 4.2.8**
  N110 to N114; **3.3** `in_range()`; **7.3.4** N113.
- **9.1.2, 9.1.5** `ci_short`, `p_digits`, `p_label`, `output_refs`,
  `output_missing`, `output_markup`, `chunk_claims`.
- **11** layer L13 (rendered output) now has a counterpart: 2.5.5.
- **New 3.10** "Checks compared": N120 to N131 (what a check is, readable
  forms, operands, `.`, the normal form, rebound names, runs always, the two
  tables, comparing literals, covered), N149 to N151 (value expressions as
  operands, with the list of unsafe calls) and `checks()`, N141 to N146. **3.1**
  a pointer to 3.10, and the recommendation to check a value once where it is
  made. **New 6.3.7** N132 to N140, with the example of §2I and E80 to E90.
  **6.3.3** a changed bound still costs nothing, and prints a note when it
  loosens (N138). **6.1.6** the file entry holds the check rows. **6.1.7** a
  passing run may print notes before its line (N138; the first-commit and
  configuration notes already do).

### 7a. Documentation only (no design)

| Item | Target |
|---|---|
| F: typed-but-checked text through `weft_str()` (asis text made computed) and through a named value with `weft_put()`; both measured identical in the trial | `vignettes/named-values.Rmd`, a section "Text a chunk prints"; spec 3.6 cross-reference |
| Severity recipe for model-convergence messages: `severity:` patterns for lme4's "failed to converge" and "Model failed to converge with max\|grad\|", and glmmTMB's "false convergence" and "non-positive-definite Hessian" | the conditions article (7.4), as a recipe; defaults unchanged |
| Adoption recipe for an existing statistics report: the settings (`serial_comma`, `count_threshold: 11`, `numeral_years`, `label_words`, `anchor_calls`, `p_digits`, `p_label`, `ci_short`, `chunk_claims: collect`), a project formatter for a percentage rule, `severity`, mapping helpers to classes, reader wrappers weft can and cannot resolve, `.Rprofile` versus front-matter activation, `@AGENTS.md` in `CLAUDE.md` | a new article `vignettes/adopting.Rmd` |
| H: no register generation from commit trailers | spec §16, one line |
| F9: check a value once, where it is made (`n_up <- claim(sum(trend$up), . >= 10)`), and use the name after; a guard or claim repeated through the prose drifts; `checks()` finds values checked with differing conditions; what the gate's check lines mean, and that they decide nothing | the claims article (`vignettes/wording.Rmd`, section "Checks: `claim()`"); the gate article (`vignettes/gate.Rmd`, "Removing constructs") |

## 7. Messages

- **E1** "`.plus` cannot go with `%s`: it signs a number that `.num` or `.pct` prints (rule 1.4.21)."
- **E2** "`.plus` does not apply to a span with `%s=` (rule 1.4.21)."
- **E3** "`%s` must be TRUE or FALSE." (for `short`: "TRUE, FALSE or NULL")
- **E4** "ci(): the short form prints no level, and `level = %s` was given; give `short = FALSE` to print it, or drop `level` (rule 3.5.3)."
- **E5** "`digits` on `.p` must be a whole number from 1 to 6 (got `%s`) (rule 1.4.17)."
- **E6** "`sigfig` does not apply to `.p`; use `digits` (rule 1.4.17)."
- **E7** "`label` applies to `.p` only (rule 1.4.17)."
- **E8** "The setting `p_digits` must be a whole number from 1 to 6, or null."
- **E9** "The setting `p_label` must be a single string."
- **E20** "The setting `%s` must be fail, warn or off."
- **E21** "Quarto could not resolve the reference `@%s`, and printed \"?@%s\" (rule 2.5.5)."
- **E22** "the shortcode value `%s` was not found, and printed \"?%s\" (rule 2.5.5)."
- **E23** "\"%s\" in the rendered prose: a value printed as missing. Mark a deliberate one [%s]{.weft-literal why=\"...\"} (rule 2.5.5)."
- **E24** "\"%s\" in the rendered text: markup that Pandoc did not read (rule 2.5.5)."
- **E25** "weft: %d problem%s in the rendered output of %s (%s)" (file, format)
- **E30** "The setting `chunk_claims` must be stop or collect."
- **E31** "weft: the knit stopped on an error after %d failed claim%s in chunk code. The claims are listed first: the error may follow from a value that failed its claim." then a new line, the report of 2.6.2, a new line, "The error that stopped the knit:", a new line, two spaces and the error's message.
- **E40** "`%s` is used above its first publication, and the document publishes %d different values for it below; a use above every publication needs a name that takes one value (rule 1.12.7)."
- **E41** "Move the sentence below the value it means, or publish that value under a name of its own."
- **E42** "no value is published under the name `%s` in this document (rule 1.12.7)."
- **E43** "If `%s` is computed further down, write it as a named value, `%s`{.num}, which takes its value from below (rule 1.12.7)."
- **E50** "`decision` must not be blank (rule 1.8.12)."
- **E51** "`decision` goes on a `.weft-literal` span or div, a `cite` span or a `claim()`, not on %s (rule 1.8.12)." (%s: "a value", "a named value", "an `n` span", ..., "a text span")
- **E52** "`decision` of claim() must be one string that is not blank, or a whole number from 1."
- **E60** "in_range(): `x` in %s cannot be compared with a range in %s (rule 4.2.8)." (a plain number is "no unit")
- **E61** "in_range(): `range` must be two numbers, the lower first (rule 4.2.8)."

- **E70** "table `%s`%s changed" (the label, or "(unlabelled)"; then " #%d" when `occ` is above 1)
- **E71** "%s: %d table%s added: %s" (the ledger; labels joined by ", ", at most ten, then " and %d other%s")
- **E72** "%s: %d table%s removed: %s" (as E71)

- **E80** "commit-msg: %s gone since HEAD (information: what still checks each; rule 6.3.7)" (%s: "1 check" or "%d checks")
- **E81** "covered: the same check remains, at line %d%s" (%s: "" or " and %d other place%s")
- **E82** "covered: `%s` at line %d implies it"
- **E83** "looser: nothing that remains implies it; remaining on %s against %s: %s" (the value, an expression cut at 60 characters as N145 cuts it; the other operand, or "a number", "a date", "a string", "TRUE or FALSE", "a quantity in %s"; the list of N136)
- **E84** "looser: only a warned check implies it, `%s` at line %d, and a warned check fails nothing"
- **E85** "looser: no check of %s against %s remains in %s" (as E83; the file)
- **E86** "the document is gone, and its %d check%s with it"
- **E87** "not judged: `%s` is assigned in more than one place in %s, so no other check is taken to cover this one" (the first rebound name in the check's text, N125; for an expression, a name or function it reads)
- **E88** "not read: weft compares only comparisons whose sides are names, dictionary reads, value expressions or literals (rule 3.10)"
- **E89** "commit-msg: note: %s:%d in HEAD, `%s`, is gone and nothing that remains covers it (rule 6.3.7)" (file, line, `shown`)
- **E90** "commit-msg: note: and %d more check%s gone with nothing that remains covering %s; gate() lists them in `checks`" ("it" or "them")
- **E91** "`repeats` must be a whole number from 2."
- **E92** "weft checks: %d check%s of %d value%s in %d document%s; %d value%s flagged"; with no checks, "weft checks: no checks in %d document%s"
- **E93** "checked in %d places with the same condition: check it once where the value is made"

## 8. Flags: where the approved recommendation needed more, or less

1. **F4 cannot be an extension filter alone (M2).** Quarto 1.11.9 ignores an
   extension filter written with `at:`, and runs extension filters before
   its crossref. The check therefore needs a `filters:` entry in
   `_quarto.yml` with a path into `_extensions/`, written by `use_quarto()`
   as a YAML mapping item (its editor now writes only scalars), and every
   existing project must run `use_quarto()` again. Citations cannot be
   checked at all from a filter (M3), and bookdown references cannot be
   checked under rmarkdown. The three checks are otherwise cheap and
   format-independent.
2. **F6 is smaller than it sounded under knitr.** Named values are resolved by
   the filter in every document; the R hooks already publish final values at
   the end (N97). The change is a pre-pass in `weft.lua`. Inline R
   (`` `r x` ``) above its definition stays unsupported (D26): the
   recommendation's "the hooks already publish at the end" is true only for
   named values. Risk: under `rmarkdown::render()` in an interactive session
   with a stale `x` in the global environment, the hooks publish the stale
   value at the first prose block, so the use is not "above every
   publication" and prints the stale value. This exists today for every
   named value; F6 makes it likelier to meet. Out of scope; noted in the
   article.
3. **F1's "Lua parity for `ci()`"** does not arise: `ci()` has no filter
   side.
4. **F5** needed two exclusions the recommendation did not name: running
   `targets` targets (D21) and guest languages (D22).
5. **F3: hashing a table's output, as recommended, is unsound as it
   stands.** gt, flextable and tinytable write random ids into their HTML
   on every render (M7), so every such table would show as changed on every
   render. The fix is the visible-text digest (N33), measured stable (M8);
   it costs a normalisation step, not a parser. Also, the first render after
   the package lists every table as added, once.
6. **F9: the gate today cannot tell which check was removed.** It counts
   constructs, not checks: per project it compares two totals and, only when
   a total fell, lists the `HEAD` construct rows (file, line, kind, text)
   whose white-space-collapsed text occurs fewer times in the commit. A
   guard's text is its whole span, prose included, so the gate holds no
   condition; a claim's text is the call, and a piped claim's text lacks its
   value (`claim(. > 0)`). An edited sentence around an unchanged guard is
   listed as removed whenever any total fell; a changed bound changes no
   total and is never listed (6.3.3); and of nine identical checks the row
   listed is the last, not the one deleted. F9 therefore cannot hang its lines
   on the construct rows. It reads checks of its own on both sides (N132),
   kept in the gate's cache; counts check keys over the project (N133); and
   takes the rows to list from the diff the gate already runs (N134). That
   makes 7j about 690 lines with value expressions (D50), the largest package of the stage. The rows
   listed stay approximate when identical checks sit on lines the commit did
   not touch; the verdicts do not depend on which row is listed.
7. **F9: what stays unreadable once value expressions are read** (D50,
   ruled 14 Nov). The gate article's example,
   `` `r claim(max(turbidity), . < u(50, NTU))` ``, now reads, and so does
   any comparison with a call, arithmetic or indexing on a side. Still not
   read, and grouped by text: a check that is itself a call (`all(. > 0)`,
   `is.na(.)`, `in_range(., r)`), `&&`, `||` and `%in%` at its top, an
   expression as a bool check (D54), a `.` inside an operand
   (`mean(.) > 3`), a value expression that reads no name, and an expression
   that assigns, defines a function, holds a block or a loop, calls a
   method, or calls a function of `CHECK_UNSAFE_FNS` (N150). Read, but
   compared only by identity: two spellings N149 does not normalise
   (`base::max(t)` and `max(t)`, `t %>% max()` and `max(t)`, argument order)
   are two values, and arithmetic is not reasoned about (`x < 2 * lim` says
   nothing about `x < lim`). A rewrite of an expression the normal form does
   not cover therefore shows in the gate as a gone check (`none` or
   `looser`), the safe side. The article's advice (check once, bind a name)
   remains the way to have every check on a value grouped under one name:
   `n <- claim(max(turbidity), ...)` is the value `n`, not `max(turbidity)`
   (N123), so a bare `claim(max(turbidity), ...)` elsewhere is another group.
8. **F9: a name assigned twice in a document is never covered** (D41). The
   count is syntactic and misses `assign()` with a computed name, a loop
   over `list2env()`, a value published only by `weft_put()`; a document
   that rebinds that way can see a check reported as covered by a check on
   another value. This is the cost of judging a document statically. Value
   expressions (D50) widen it: an expression is judged by the names it shows,
   so a function the document defines that reads a rebound name or draws
   random numbers (`f <- function(v) v + runif(1)`, then `f(x) < 0.5` in two
   places),
   a value changed in place without an assignment (`data.table`'s `set()`,
   an environment or R6 object), or a data file read twice that changes
   between the two reads, can make two checks of `f(x)` look like checks of
   one value. The verdicts decide nothing (D36), so the cost is a wrong
   `same` or `implied` line, not a wrong commit.

## 9. Open questions for the owner

1. F4's default for `output_missing`: `warn` (chosen, D14) or `fail`.
2. F5 for Python and Julia `claim()`: in a later stage, or not at all.
3. F3 in the filter path (Jupyter and Julia tables): wanted, and when.
4. F9: read a value expression other than a name as an operand, when the
   same expression text recurs in one document and no symbol in it is
   rebound (`claim(max(turbidity), . < u(50, NTU))` in three sentences would
   then group and compare). It goes beyond "plain comparisons of names and
   literals", so it is out until you say so. (Answered, 14 Nov: yes, "should
   the check comparison also group a repeated expression - yes". Built as
   N122's `expr` and N149 to N151, D50 to D54; a single occurrence is read
   too, D51.)
5. F9: the default of `repeats`, the count at which `checks()` suggests
   checking once at the source: 3 (chosen) or another.
