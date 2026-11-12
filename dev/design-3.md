# Stage 3 — static lints

Written before any test or code. It is the build contract for stage 3 of
`PACKAGE-SCOPING.md` §22 (§5, 3.1.6, 3.1.9, 9.5.1, 9.5.5, 7.3.5). It builds
on stages 1 and 2 as they are on `main`, and reuses their code: the scanner
(`scan_document()`, `scan_file()`, `mask_text()`), the places beside prose
(`metadata_blocks()`, `front_fields()`, `labelled_chunks()`,
`scan_chunk_strings()`), `mask_nonprose()` and `sentence_starts_of()`,
`heading_anchors()` and `pandoc_id()`, `cite_keys()`, `read_bib_keys()`,
`seed_chunks()`, `did_you_mean()`, `find_project_root()`, `project_type()`.
Robin delegated the choices; each is a decision below with its alternatives.
Every example is invented.

## What was measured

R 4.4.3, knitr 1.51, Pandoc 3.10 (Quarto 1.11.9's, `tools/aarch64/pandoc`) and
3.8.3 (Homebrew). On the trial chapter (`dev/trials/chapter`, 1,765 lines):

1. `scan_file()`: 0.11 s for its first 320 lines, 1.4 s for all of it (warm).
   `mask_nonprose()` over 320 lines: 0.025 s.
2. `pandoc -f commonmark_x+sourcepos -t json` on 320 masked lines: 0.04 s warm,
   0.6 s on a cold first run. The whole chapter gives 1.9 MB of JSON (every
   word wrapped in a `Span` with `data-pos`); `jsonlite` parses it in 0.1 s.
3. No R code in the package calls Pandoc today; the Lua filter runs inside
   renders only.
4. The audit of `dev/trials/stage0/` records findings as a title and, for about
   half, a verbatim quote of the claim, located by file or section. Line numbers
   are not reliable. About two in five were raised from the rendered PDF, which
   no static lint reaches. The source-level classes that matter most are typed
   numbers (in prose and alt text), wording that contradicts a value, broken
   cross-references, citations, and missing captions or figure labels.

## 1. Scope

Default is build. "Pkg" is the work package of §5.

| Rule | Lint | Tier | Pkg | |
|---|---|---|---|---|
| 5.1.1–5.1.6 | the entry point, tiers, inputs, phrases, added-material scope | | 3a | build |
| 2.10.2–2.10.6 | the source reader (prose mask, regions, blocks); the masked Pandoc read | | 3a, 3b | build, Pandoc on request (K1) |
| 5.2.1–5.2.6 | `numeral`: prose, captions, front matter, strings, phrases, math | 1 | 3b | build |
| 9.5.5 | `label_seed()` | | 3b | build |
| 5.3.1, 5.3.4, 5.3.5 | `construct`: the scanner's errors as findings | 1 | 3a | build |
| 2.10.5, Q9 | `block-start`: a line inside a span that starts a block | 1 | 3b | build (K2) |
| 5.3.2 | value-dependent errors | — | — | built at knit time (stage 1); not a lint |
| 5.3.3 | `lone-bar`, `if-zero`, `name` | 2 | 3c | build |
| 3.1.6 | `inert-check` | 1 | 3c | build |
| 3.1.9 | `long-guard` | 2 | 3b | build |
| 5.4.1–5.4.6 | `cite-key`, `cite-bare`, `citation-key` | 1 | 3d | build |
| 5.5.1–5.5.4 | `claim-word`, the shipped lexicon | 2 | 3b (lexicon 3a) | build |
| 5.6.1, 5.6.3 | `literal-value` | 1 | 3c | build |
| 5.6.2, 5.6.4 | `value-constant`, `value-format` | 2 | 3c | build |
| 5.7.1 | `xref`, `anchor-twice`, `ref-label` | 1 | 3d | build |
| 5.7.2 | `anchor-unused` | 2 | 3d | build |
| 5.8 rules 1–9 | `section-anchor`, `chunk-label`, `tar-name`, `dict-assign`, `file-link`, `above-setup`, `dict-key`, `tar-cache`, `config-place`, `engine` | 1 | 3c, 3d | build |
| 5.9.1–5.9.3 | `figure`, `table-caption` | 1 | 3d | build |
| 5.10.1 | sentence starts | 2 | — | built at knit time (stage 1); not static |
| 7.3.5 | tier-2 findings in `changes()` | | 3d | build |
| 9.5.1 | `recall_check()` | | 3a | build |
| 6.x, 8.x | judged against `HEAD`, the hook, `verify()` | | — | defer: stage 4 |
| (open finding) | constructs in strings that skip `weft_str()` (`kable(caption=)`) | 2 | — | defer: not in §5; a new lint for Robin |

## 2. Contract

### Exports and dependencies

- **L1.** New exports: `lints()`, `lint_rules()`, `recall_check()` (3a) and
  `label_seed()` (3b). No new Imports or Suggests: Pandoc is a program, found
  at run time (L15); `targets` (Suggests) is used only when installed (L34).
  Nothing a lint does runs document code, `_targets.R`, or anything but
  `parse()` on R code and `pandoc`, `git` as named here.

### `lints()`

- **L2.** `lints(path = ".", files = NULL, rules = NULL, tier = 1, reader =
  c("weft", "pandoc"))`. Returns a `weft_findings` (L5), sorted by `file`,
  `line`, `col`, `rule`.
  - `path`: one string, an existing file or folder. The root is
    `find_project_root(path)`; a project need not be set up (`_weft.yml`
    absent means the defaults).
  - `files`: `NULL`, or paths relative to the root or absolute under it, each
    an existing `.qmd`, `.Rmd` or `.rmd`. Findings are reported only for them
    (and, when `NULL`, for the project files of `config-place`, L34).
  - `rules`: `NULL` (every rule of the tiers asked for) or ids from
    `lint_rules()$id`; `tier`: a subset of `1:2`. Default `1`: tier 2 is
    listed over added material by `changes()` (5.1.5), and over a whole file
    only when asked for.
  - `reader`: L15.
- **L3. The file set.** Every `.qmd`, `.Rmd` and `.rmd` under the root, outside
  folders whose name starts with `_` or `.` or is `renv` (as `dict_seed()`),
  is read, whatever `files` says, because ids, anchors, includes and child
  documents are project-wide (5.7.1, 6.2.4). `.md` files there are read for
  anchors only, never linted.
- **L4. Configuration per document.** Each document's settings are
  `_weft.yml` merged with its front matter's `weft:` key (the nearest wins,
  setting by setting), read by an internal `lint_config(root, front)` that
  parses YAML only: it does not call `read_config()`, so it installs no units
  and a bad `units:` table does not stop a lint.

### Findings

- **L5.** A `weft_findings` is a data frame with exactly these columns, in
  this order (an empty one has them too):

  | column | type | holds |
  |---|---|---|
  | `file` | chr | path relative to the root, `/` separators |
  | `line`, `col` | int | where the finding's `text` starts; `col` counts characters from 1, after a BOM is removed and CR LF made LF |
  | `end_line` | int | the last line it covers (a sentence, a chunk); `line` otherwise |
  | `rule` | chr | the stable id (L6) |
  | `tier` | int | 1 or 2 |
  | `spec` | chr | the rule number, `"5.2.1"` |
  | `context` | chr | `prose`, `caption`, `front-matter`, `weft_str`, `phrase`, `chunk`, `project` |
  | `text` | chr | what is counted by the gate (6.2.3): the numeral, the expression, the key, the anchor, the name |
  | `message` | chr | one or two sentences, ending `(rule x.y.z).` |
  | `hint` | chr | the fix, imperative; `NA` when there is none |
  | `sentence` | chr | the sentence, whitespace collapsed, for `claim-word`; `NA` otherwise |

  Attribute `notes`: character, things not checked and why (no store, no
  Pandoc, a file read for anchors only that failed to parse). Duplicates (all
  of `file, line, col, rule, text` equal) are dropped.
- **L6. `lint_rules()`** returns a data frame `id, spec, tier, scope
  ("file" or "project"), what` with one row per rule of §1, in the order of §1.
  The ids are those in §1's table. Each lint is an internal function
  `lint_<id with - as _>(src, ctx)` (scope file) or `(ctx)` (scope project)
  returning a `weft_findings`; `lints()` finds them by name from the registry
  in `R/lint.R`, and skips a rule whose function is not yet built.
- **L7. Printing.** `print(x, max = 200)`:

  ```
  weft lints: 3 findings in 1 file (2 tier 1, 1 tier 2)

  chapters/results.qmd
    12:5    numeral      "45%" is a number typed in prose (rule 5.2.1).
                         Write it as a value, put it in the dictionary, or mark it [45%]{.weft-literal why="..."}.
    40:1    claim-word   Claim word "all" in a sentence with a value (rule 5.5.1).
                         "All `r n` sites rose."
  ```

  None: `weft lints: no findings in 4 files.` Past `max` rows: `... and N
  more findings.` Notes follow under `Notes:`. ASCII in the source; non-ASCII
  in messages is written with `\u` escapes.

### Configuration

- **L8.** New keys in `_weft.yml` and under a document's `weft:`, added to
  `default_config()` (so a knit does not warn about them) and checked by a
  `validate_lint_config()` that `validate_config()` also calls:

  ```yaml
  label_words: []         # 5.2.4: words after which a numeral is exempt, as typed ("Site")
  numeral_years: false    # 5.2.4: true exempts a four-digit year, 1000 to 2999
  claim_words: {add: [], drop: []}   # 5.5.4: words added to and dropped from the lexicon
  claim_cap: 20           # 5.5.3: claim-word sentences listed per file in changes()
  guard_words: 25         # 3.1.9: words in an `if` arm before it is listed
  expected_names: []      # 5.3.3: classes (".foo") and keys ("foo") the project expects
  ```

  A wrong value is a `weft_config_error`: "The setting `label_words` must be a
  list of words without spaces (rule 5.2.4)." and likewise ("TRUE or FALSE",
  "a mapping with `add` and `drop`, each a list of words", "a whole number
  from 1", "a list of names, each `.class` or `key`").
- **L8a. The lexicon** ships as `inst/weft-claim-words.yml`, a mapping of four
  lists, `number`, `quantifier`, `extremum`, `direction`, lower case: every
  word of the interim `claim_words()` (`R/changes.R`), `zero`, `one` to
  `twelve`, `first` to `third`, and `always never whole entire single sole
  solely fewest top exceed exceeding surpassed decline declines declining grow
  grows growing drop drops dropping reduced significant significantly`.
  Internal `claim_lexicon(cfg, lang)`: the shipped words
  when `lang` is missing or starts `en` (any case), else none; then
  `union(add)`, then `setdiff(drop)`.

### The source reader (3a)

- **L9.** Internal `read_source(path, root, cfg)` returns a `weft_source`
  list. `text` is the file with a BOM removed and CR LF made LF; a file that is
  not UTF-8 gives the finding `read` (tier 1, "5.1.3") and no other.
  - `file`, `lines`, `line_start` (offset of each line), `lang` (front matter
    `lang`, else `_quarto.yml`'s, else `NA`), `ext`.
  - `rows`: `scan_document()`'s rows with three columns added, `fstart`,
    `fend`, `fblock`: file offsets of the construct and its attribute block.
    For a caption or a `weft_str()` row the scanner's positions are mapped
    through the piece's offsets (L10), so `substr(text, fstart, fend)` is the
    construct as written, in every context.
  - `prose`: a string as long as `text`, in which every character that is not
    prose (L11) is a space; line breaks stay.
  - `regions`: data frame `type, start, end, row, name` (offsets), for
    `math`, `code`, `value`, `bare`, `cite_span`, `literal`, `if`, `sign`,
    `n`, `list`, `text_span`, `span` (any `[...]{...}`, weft or not, with
    `inner_start`, `inner_end`, `attr_start`, `attr_end`, and the parsed
    `classes`, `keys`, `id` as list columns), `code_attr` (inline code with an
    attribute block), `citation`, `crossref`, `link`, `image`, `heading`,
    `table`, `footnote`, `div`, `chunk`, `yaml_field` (`name` = the field),
    `caption` (`name` = the option), `weft_str`, `phrase`, `refdef`.
  - `blocks`: data frame `type, start, end, line, end_line`: the innermost
    block for 5.4.2 and for sentences. Types `para`, `heading`, `item` (a list
    item), `cell` (a pipe-table cell), `footnote` (an inline note or a
    definition's paragraph), `caption` (a chunk-option caption, a table's `:`
    line, the last paragraph of a `#fig-`/`#tbl-` div), `front-matter`,
    `weft_str`, `phrase`. A paragraph ends at a blank line, a fence, a div line,
    a heading or a list marker that starts a block.
  - `chunks`: data frame of executed chunks: `open`, `close`, `engine`,
    `label`, `explicit` (lgl), `eval` (`FALSE` only when written literally
    false), `cache` (`TRUE`/`FALSE`/`NA` as written), `options` (list), `code`
    (list), `code_first`.
  - `meta`: each metadata block parsed by `yaml` (`!expr` kept as text), with
    its open and close lines; `front` is them merged, the later winning.
- **L10. Pieces beside the body (5.1.3, 5.1.6).** Their characters are prose,
  in place, so positions are file positions:
  - the values of `title`, `subtitle`, `abstract`, `description` in every
    metadata block: a block scalar's lines, or the scalar after `key:` on its
    line (quotes are punctuation); other fields are not read;
  - in executed R chunks, the values of `fig-cap`, `fig.cap`, `fig-alt`,
    `fig.alt`, `fig-scap`, `fig.scap`, `fig-subcap` (list items included),
    `fig.subcap`, `tbl-cap`: on `#|` lines the text after `key:` or the block
    scalar's lines after `#|` and indentation; in the header, a literal string's
    contents; never an `!expr` or a non-literal;
  - in R chunks whose `eval` is not written false, the contents of the literal
    strings given to `weft_str()` (as `scan_chunk_strings()` finds them) and,
    for 5.1.6, of every string constant inside a `lookup()` or `brk()` call
    that is not a name (`c(hi = "high")`: `"high"` only), found by
    `getParseData()`; the text between the quotes is used as typed.
- **L11. What is prose in the body.** Not prose (blanked):

  | Source | Notes |
  |---|---|
  | metadata blocks, but for L10 | |
  | fenced blocks (```` ``` ````, `~~~`, raw `{=html}`), executed or not | but for L10 |
  | indented code: lines indented 4+ after a blank line, not inside a list item | a list item lasts until a non-blank line at indentation 0 that follows a blank line |
  | HTML comments; `<script>`, `<style>` elements; HTML tags (the text between tags is prose) | |
  | math `$..$`, `$$..$$`, `\(..\)`, `\[..\]`, by the scanner's rules | region `math`, read by `numeral` only (L19) |
  | code spans, inline R included | |
  | every attribute block: after `]`, a code span, a link, an image, `$$`, at the end of a heading; div fence lines | |
  | link and image targets `(...)`, `[text][label]`'s label, reference definitions `[x]: url` (whole line), autolinks `<...>`, bare URLs (`https?://`, `ftp://`, `www.`), DOIs `10.NNNN/...`, e-mail addresses | link text and image alt text are prose |
  | shortcodes `{{< ... >}}`; HTML entities `&...;` | |
  | citations by pattern (the regexes of `mask_nonprose()`): `[...@key...]`, `@key`, `-@key`, `@{key}`, and a `[...]` right after an in-text `@key` (its locator); cross-references `@fig-x` (L33), `\@ref(...)`, `(\#fig:x)` | regions `citation`, `crossref` |
  | footnote markers `[^x]`, a definition's `[^x]:`, the `^[` and `]` of an inline note | the note's text is prose |
  | line-start markers: `>`, ATX `#`s and closing `#`s, setext underlines, rules, bullets, task boxes, `:`/`~` of definitions, `(@)`; a numeric list marker (`1.`, `2)`, `(3)`) only on a line that starts a block or follows a list item line | so `2020. The` inside a paragraph stays prose |
  | pipe-table delimiter rows, grid borders | cells are prose; a table's `:` caption line is a `caption` block |
  | raw TeX: `\command`, a `*`, and the brace and bracket groups after it; the backslash of an escape (`\$`, `\#`) | the escaped character is prose |
  | each construct's code and attribute block (from `rows`) | a span's bracket text is prose; `[`, `]`, `|` and `#` stay as characters |

- **L12. Words, sentences.** A **word** is a maximal run of characters of
  `prose` that are not white space (space, tab, line break, U+00A0, U+2007,
  U+2009, U+202F) and not one of `= < > ≤ ≥ ≈ ≠` (K4). Sentences are cut per
  block as the ledger cuts them: `mask_nonprose()` on the block's text, then
  `sentence_starts_of()` with the document's `lang`. Internal
  `source_sentences(src)` returns `start, end, line, end_line, block` for every
  block of L9; `recall_check()` and `claim-word` use it.

### Exemptions

- **L13.** The only marks in the source: a `.weft-literal` span or div (with
  its `why`) and a `cite` span exempt numerals inside them (5.2.1, 5.2.5);
  every other lint reads them. A `.weft-literal` with no `why` is a `construct`
  finding (1.8.10). The configuration exempts by `label_words`,
  `numeral_years` and `expected_names`. There is no inline ignore comment and
  no switch that turns a rule off (K5, R4): what a document held at adoption is
  tolerated by `HEAD` (stage 4), and tier 2 blocks nothing.
- **L14. Errors.** `weft_lint_error` (new; with `weft_error`): `path` not one
  existing path; a `files` entry missing, outside the root or of another
  extension (all named in one error); an unknown rule id ("Did you mean ...?"
  by `did_you_mean()`); `tier` not in `1:2`; `reader = "pandoc"` with no
  Pandoc found ("lints(reader = \"pandoc\") needs Pandoc; none was found. Set
  the option `weft.pandoc` to its path (rule 2.10.3)."). `weft_config_error`
  from L8. `recall_check()` and `label_seed()` raise `weft_tool_error`, as
  `dict_seed()` does.

### Pandoc (3b)

- **L15.** `reader = "weft"` (the default) calls no Pandoc (K1, R1). Internal
  `pandoc_path()` looks, in order, at `getOption("weft.pandoc")`,
  `Sys.getenv("WEFT_PANDOC")`, Quarto's own (`quarto` on the path, links
  resolved, then `<bin>/tools/<arch>/pandoc` or `<bin>/tools/pandoc`),
  `rmarkdown::pandoc_exec()` when `rmarkdown` is installed, `Sys.which("pandoc")`;
  it needs version 3.0 or later and caches the answer for the session.
  **The masked Pandoc read**: the body, with front matter blanked to spaces and
  every construct's code and attribute block masked by `mask_text()` (one
  letter, line breaks kept: 2.10.5), is written to a temporary file and read
  by `pandoc -f commonmark_x+sourcepos -t json`. Pandoc's prose is the set of
  characters inside the `data-pos` ranges of `Str` nodes, not inside `Code`,
  `Math`, `RawInline`, `RawBlock` or `CodeBlock`. With `reader = "pandoc"`:
  (a) a body character is prose only when both the R reader and Pandoc say so
  (the pieces of L10 are judged by the R reader alone); (b) the unmasked body
  is read too, and every block whose type or start line differs between the two
  trees is a `block-start` finding at that line (2.10.5). `lints()` calls
  Pandoc at most twice per file.
- **L16. Performance.** With `reader = "weft"`, `lints()` over a 300-line
  chapter (40 constructs, 2 chunks with captions, an abstract), all rules of
  both tiers, takes under 0.5 s on the second call in a session; 1,800 lines
  under 3 s. Every pass is vectorised over the whole text or over lines; no
  loop over characters except the scanner's. The tests allow twice these.

### The lints

Each finding below has `context` from where it sits; messages are given in
short and end with the rule as in L5. A table row is source → findings
(`text`); "—" is none.

- **L17 `construct` (5.3.1, 5.3.4, 5.3.5; 3a).** One finding per line of each
  row's `error` (rows of every context, ids included). `spec` is the first
  `rule[s] x.y.z` in the message, else `5.3.1`; `text` is the construct as
  written, cut to 80 characters; `message` is the scanner's; `hint` `NA`.
- **L18 `block-start` (2.10.5, Q9; 3b).** For a span row (`n`, `if`, `sign`,
  `list`, `cite`, `text`, `literal`), every line after the one holding `[`, up
  to the one holding `]`, that starts, after at most three spaces, with a
  block marker: one to six `#` then a space or the line end; `>`; `-`, `+` or
  `*` then a space; up to nine digits, `.` or `)`, then a space; three or more
  backticks, tildes or colons. Also any construct that starts a line indented
  4+ after a blank line outside a list. `text` = the marker; "Line 14 inside a span
  starts with `#`, which Pandoc reads as a heading, so the span is cut in two
  (rule 2.10.5)." Hint: re-wrap, or escape it (`\#`). `[a site |\n# sites]{n="k"}`
  → `#`; `[a site | # sites]{n="k"}` → —.
- **L19 `numeral` (5.2; 3b).** For each word (L12) whose first letter or digit
  (`\p{L}`, `\p{Nd}`) is a digit. `text`: from that digit (or the one
  `-`, `−`, `+`, `±` right before it) to the last letter, digit, `%`, `‰`, `°`
  of the word. Exempt: inside a `cite_span` or `literal` region; the previous
  word in the same block equal to a label word, both with leading and trailing
  punctuation (`\p{P}`) removed (case as typed: `(Site 3)`, `Site: 3`); a
  four-digit year under `numeral_years`.
  When that previous word is, ignoring case, `figure(s)`, `fig(s)`,
  `table(s)`, `section(s)`, `chapter(s)`, `equation(s)`, `eq(s)`,
  `appendix`/`appendices` and not a label word, the message says to use a
  cross-reference (`@fig-`, `@tbl-`, `@sec-`, `@eq-`; 5.2.4). **Math** (5.2.6):
  in each `math` region outside `literal`/`cite_span`, each run
  `[0-9]+(\.[0-9]+)?` not right after `^` or `_` and not inside the braces that
  follow one; inline R there is masked. Messages: `"45%" is a number typed in
  prose (rule 5.2.1).` / `"3" after "Figure" is a typed cross-reference
  number; use @fig-<label> (rule 5.2.4).` / `"0.02" is a number typed in math
  (rule 5.2.6).`

  | Source | Findings |
  |---|---|
  | `We sampled 12 sites, 45% of them (n=12) in 3–5 m of water.` | `12`, `45%`, `12`, `3–5` |
  | `an 11-year record; the 3rd survey; the 1990s; −0.5; p<0.05; 10^6^` | `11-year`, `3rd`, `1990s`, `−0.5`, `0.05`, `10^6` |
  | `CO2`, `PM2.5`, `x2`, `COVID-19`, `No.5` | — |
  | `## 2. Methods {#sec-m}` / `## Results for 2020 {#sec-r}` | `2` / `2020` (— with `numeral_years: true`) |
  | `| Site A | 3.4 |` in a table body; `|---|---:|` | `3.4`; — |
  | `on 12 March 2020`; `at 10:30`; `R 4.4.3` | `12`, `2020`; `10:30`; `4.4.3` |
  | `Figure 3`, `fig. 3`, `[Table 2](#tbl-a)` | `3`, `3`, `2`, each with the cross-reference message |
  | `Site 3 and 4` with `label_words: [Site]` | `4` |
  | `https://x.org/2020/a`, `<https://x.org/1>`, `doi 10.1000/xyz`, `a@b2.org` | — |
  | `` `r n` sites``, `` `x[3]` ``, `<!-- 12 -->`, `&#8212;`, `\vspace{2em}` | — |
  | `<span>12</span>`, `“12”`, `\$5` | `12`, `12`, `5` |
  | `[@smith2020, p. 4]`, `@smith2020 [p. 4]`, `@fig-3d` | — |
  | `[^1]` / `^[In 2019 only.]` | — / `2019` |
  | `1. First` after a blank line / `...and in\n2020. The` | — / `2020` |
  | `![Map of 4 sites](m.png)` | `4` |
  | `[3 sites]{if="n > 2"}`, `[a site | # sites]{n="k"}`, `[x]{.smallcaps}` | `3`, —, — |
  | `[10 m]{cite="smith2020"}`, `[0.45 µm]{.weft-literal why="SOP 12"}`, a `.weft-literal` div | — |
  | `$p = 0.02$`, `$p = `r p`$`, `$x^2 + \beta_{12}$`, `$10^{-3}$`, `$\frac{1}{n}$` | `0.02`, —, —, `10`, `1` |
  | front matter line 2 `title: "Survey 2020"`; a late block's `abstract: |` with `4 sites` at line 88 | `2020` at 2; `4` at 88 |
  | `date: 2020-01-03`, `params: {n: 5}` | — |
  | `#| fig-cap: "Depth at 3 sites"`; `#| fig-alt: Scatter of 75 points`; `{r, fig.cap="In 2019"}` | `3`; `75`; `2019` |
  | `weft_str("over 5 years: `r x`{.num}")`; `brk(. > 2 ~ "more than 2 sites")`; `lookup(c(a = "top 10"))` | `5`; `2` (the string only); `10` |
  | inside a fenced or `eval: false` chunk; indented code | — |

- **L20 `claim-word` (5.5; 3b).** Reads prose, captions, front matter and
  `weft_str()` strings, not phrases (5.1.6). For each sentence (L12), the
  lexicon words (L8a) among its lower-cased letter runs `\p{L}+`, leaving out
  those inside an `if` or `sign` span (5.5.2; an `n` span does not guard). One
  finding per sentence with any: `line`/`col` at the first word, `end_line`
  the sentence's last line, `text` the words in order, `", "`-joined, unique;
  `sentence` the sentence. It "has a value" when a row of kind `value`,
  `bare`, `n`, `sign` or `list` starts inside it. "Claim word "all" in a
  sentence with a value; check that the value still bears it out, or guard the
  word with an `if` span (rule 5.5.1)." / "Claim words "rose", "largest" in a
  sentence with no value: if it states a result, compute it (rule 5.5.1)."
  `All `r n` sites rose.` → `all, rose`; `[All]{if="all(up)"} sites rose.` →
  `rose`; `[a site | # sites]{n="k"}, all dry` → `all`; `The ratio fell.` under
  `lang: de` → —.
- **L21 `long-guard` (3.1.9; 3b).** An `if` row whose longest arm has more than
  `guard_words` words, counting words of the arm in `prose` and each nested
  `value`/`bare` row as one. `text` = the condition; "A guarded bracket of 31
  words: one condition guards all of it; guard only the words it decides, and
  nest what is computed (rule 3.1.9)."
- **L22 `literal-value` (5.6.1, 5.6.3; 3c).** A `value` or `bare` row, or the
  expression of an `n`, `sign` or `list` row (not a back-reference, not `.`;
  K6, R5), that parses to constants (numeric, integer, string, logical,
  `NULL`) joined only by `+ - * / ^ %% %/% ( == != < > <= >= & | && || ! :`.
  `text` = the expression. `` `r 10` ``, `` `r 2 * 5` ``, `` `r -3`{.num} ``,
  `` `r "ten"` ``, `` `r 1e6` ``, `$p = `r 0.02`$`, `{n="3"}` → each; `` `r pi` ``,
  `` `r c(1, 2)` ``, `` `r x` ``, `{n="#k"}`, unparsable → —. Hint: compute it,
  put it in the dictionary, or write `[10]{.weft-literal why="..."}`.
- **L23 `inert-check` (3.1.6; 3c).** (a) every `claim()`/`weft::claim()` call in
  inline expressions, governor expressions and the code of R chunks whose
  `eval` is not written false: each check argument (all but the first and
  `level`) with no variable (`all.vars()` empty, so no `.`). `text` = the check
  as written. (b) an `if` row, any arm count (K6), whose condition has no
  variable. `claim(x, TRUE)`, `claim(x, 1 > 0)`, `[a]{if="TRUE"}`,
  `[a|b]{if="1 > 0"}` → each; `claim(x, . > 0)`, `claim(x, nrow(d) > 0)` → —.
- **L24 `value-constant` (5.6.2, 5.6.3; 3c).** In a `value`/`bare` row that is not
  literal, each numeric constant other than 0 and 1 (any form), not inside a
  `claim()` check argument and not a later argument of a call L25 names. `text`
  = the constant as written, with a unary minus. `` `r x * 100` `` → `100`;
  `` `r x[2]` `` → `2`; `` `r n - 1` ``, `` `r claim(n, . > 10)` ``,
  `` `r round(x, 2)` `` → —.
- **L25 `value-format` (5.6.4; 3c).** A `value`/`bare` row whose outermost call,
  after removing parentheses, `claim()` (its first argument) and `base::`, is
  `round`, `signif`, `format`, `formatC`, `prettyNum` or `sprintf`. `text` = the
  function name. Hint: return the raw number and use a class or `digits=`.
- **L26 `lone-bar` (5.3.3; 3c).** A `span` region whose attribute block has no
  governor or marker key (any case), outside a pipe-table row, whose bracket
  text holds exactly one `|` that is not `\|` and not inside a nested code
  span or bracket. `text` = the bracket text. `[a site | # sites]{count="k"}`,
  `[a | b]{.smallcaps}` → each; `[a | b]`, `[a \| b]{.x}`, `[a|b|c]{.x}`,
  `[a | b]{n="k"}` → —.
- **L27 `if-zero` (5.3.3; 3c).** An `if` row whose condition holds a call to
  `>`, `<`, `>=`, `<=`, `==` or `!=` with a numeric 0 (`0`, `0L`, `0.0`, `-0`) as
  an argument. `text` = the condition. `if="d > 0"`, `if="n == 0 & ok"` → each;
  `if="d > 0.5"` → —.
- **L28 `name` (5.3.3, 1.1.9, 1.2.10; 3c).** Names are classes (with the dot)
  and keys of `span` and `code_attr` regions. Weft's names: 1.2.5's table,
  `.no`, `.weft-literal`, `why`, and the project's formatter classes; Pandoc's:
  `.smallcaps`, `.underline`, `.mark`, `custom-style`; plus `expected_names`.
  Listed: (a) on a construct, a name that is none of these; (b) on a bracket
  with no governor or marker key, a formatter class or renderer key (1.1.9);
  (c) on any span or code span, a name that is not one of these but is one
  optimal-string-alignment edit from a weft name, comparing keys with keys and
  with class names without the dot, when the name has at least three
  characters, or that equals a weft class ignoring case (K7). A key that
  differs from a weft key only in case is that key, not listed (1.2.10). Two
  weft names one edit apart are not listed (Q8). `text` = the name; the nearest
  weft name in the message. `[1234]{.num}` → `.num` (b); `` `r x`{.Num} `` →
  `.Num`, nearest `.num`; `[add more]{iff="n > 10"}` → `iff`, nearest `if`;
  `{.nmu}`, `{trunk="x"}`, `{count="k"}` → each; `` `r x`{.num .smallcaps} ``,
  `{If="x"}`, `` `x`{.r} ``, `` `x`{.python} `` → —.
- **L29 `cite-key` (5.4.1; 3d).** Each key of a `cite` row, either form (by
  `cite_keys()`, and the keys after `@` in the citation form), not in the
  document's bibliography (L32). Key grammar is the scanner's (`construct`).
- **L30 `cite-bare` (5.4.2; 3d).** A bare-form `cite` row: each key not written
  as `@key`, `-@key` or `@{key}` anywhere in its innermost block (L9).
  `[10 m]{cite="jones2019"}` in a paragraph citing `@jones2019` → —; without it
  → `jones2019`; the same in a table cell, a footnote, a caption: its own block.
- **L31 `citation-key` (5.4.3, 5.4.4; 3d).** Each key of a `citation` region not
  in the bibliography. A bibliography file named but missing is one finding at
  its `bibliography:` line (`text` = the file). `@fig-x` is a cross-reference;
  `a@b.org` is no citation.
- **L32. The bibliography** of a document, statically (5.4.4–5.4.6): files under
  `bibliography:` and entries under `references:` in every metadata block
  (paths from the document's folder), in `_quarto.yml` (from the root) and in
  each `_metadata.yml` from the document's folder up to the root (from its own
  folder), and the `bibliography` setting (from the root). Keys by
  `read_bib_keys()`. No Pandoc, no `quarto_inspect()`.
- **L33. Anchors and references (5.7; 3d).** Anchors: every `{#id}` outside a
  construct's attribute block (a weft `#id` is never emitted, 1.2.8): headings,
  divs, spans, images, `$$..$$ {#eq-x}`, a table's `: cap {#tbl-x}`; an executed
  chunk's explicit label when it starts with a cross-reference prefix (`fig`,
  `tbl`, `lst`, `sec`, `eq`, `thm`, `lem`, `cor`, `prp`, `cnj`, `def`, `exm`,
  `exr`, `sol`, `rem`, then `-`); in an `.Rmd`, every chunk label `x` also as
  `fig:x` and `tab:x`, and `(\#fig:x)`, `(\#tab:x)`, `(\#eq:x)`; a heading's
  automatic id (`pandoc_id()`) for `#x` links only. References: `@prefix-x`,
  `-@prefix-x`, `\@ref(x)`, link targets `#x` and `file#x`.
  - `xref` (1): a reference to no anchor in the project (`file#x`: none in
    that file, when it is a project document). `text` = the id.
  - `anchor-twice` (1): an anchor defined again, anywhere in the project; one
    finding per later definition, naming the first.
  - `ref-label` (1): a span row (`n`, `if`, `sign`, `list`, `cite`, `text`,
    `literal`) whose bracket text, case-folded and white space collapsed, equals
    a reference-definition label of the same document.
  - `anchor-unused` (2): a `fig`, `tbl` or `eq` anchor (`fig:`, `tab:`, `eq:`)
    that no reference in the project names.
  - `xref-code` (2; K8): a code span whose whole text is a reference, `` `@sec-a` ``.
- **L34. Hygiene (5.8).**
  - `section-anchor` (3d): an ATX or setext heading (a `---` under a paragraph
    line is one) with no `{#id}`. `text` = the heading's text.
  - `chunk-label` (3d): an executed chunk of any engine with no label in its
    header, `label=` or `#| label:`. `text` = engine and first code line.
  - `tar-name` (3c): `tar_read(x)`, `tar_load(x)`, `tar_load(c(x, y))`,
    `tar_read_raw("x")`, `tar_load_raw("x")` (also `targets::`) in chunk code,
    inline and governor expressions, naming a target absent from the store's
    metadata (K9, R3): the store is the literal `store=`, else `_targets.yaml`'s
    `main: store:`, else `_targets`, from the root, read with
    `targets::tar_meta(store =, fields = "type")`. No store, or `targets` not
    installed: a note, no finding.
  - `dict-assign` (3c): in chunk code, an assignment (`<-`, `=`, `->`, `<<-`,
    `->>`, `assign("dict", ...)`) whose target's leftmost symbol is `dict`
    (`dict`, `dict$k`, `dict[["k"]]`, `names(dict)`). `text` = the target.
  - `file-link` (3d): a link or image target with no scheme, not `//`, not
    starting `#`, not empty; `?`/`#` parts dropped, `%20` decoded; from the
    document's folder, or from the root when it starts `/`; missing. `text` =
    the target.
  - `above-setup` (3c): in a document with an R chunk calling `weft_setup()`
    (`weft::` or not), no front-matter route (`knitr: opts_knit: weft:`) and no
    `.Rprofile` at the root calling `weft_setup`, every row other than `bare` and
    `link` whose line is above that chunk, front matter included.
  - `dict-key` (3c): reads `dict$k`, `dict$"k"`, `dict[["k"]]`,
    `dict[['k']]` where `k` is not a top-level key of `<root>/dict.yml` (YAML
    names; no `read_dict()`), or is a key of the document's `weft: dict_local:`
    (4.3.2); `dict_local$k` with no local `k`. With no `dict.yml`, every `dict$`
    read. `did_you_mean()` in the message.
  - `tar-cache` (3c): a chunk with a target read (as `tar-name`) whose cache is
    on: its own option, else an earlier literal `knitr::opts_chunk$set(cache =
    TRUE)`, else front matter `execute: cache: true` or `knitr: opts_chunk:
    cache: true`, else `_quarto.yml`/`_metadata.yml` `execute: cache: true`.
  - `config-place` (3d): a `weft:` key in `_quarto.yml` or any `_metadata.yml`
    (context `project`, only when `files` is `NULL`); where `_weft.yml` exists,
    `draft` or `decisions` under a document's `weft:` (stage 4 adds its switch
    key to the same internal list).
  - `engine` (3d): a `.qmd` holding a row of a kind other than `bare`, `link`
    and `literal`, whose name does not start with `_`, that no project document
    includes (`{{< include >}}`, `child=`), and whose own metadata blocks have no
    `engine: knitr`. At line 1.
- **L35. Figures and tables (5.9; 3d).** A figure is a chunk labelled `fig-...`
  or with a figure caption option, an image alone in its paragraph with
  non-empty bracket text, or a `#fig-` div. It needs a label (a `.qmd` chunk's
  starting `fig-`; an image's `{#fig-...}`), a caption (the option, the bracket
  text, the div's last paragraph) and alt text (`fig-alt`/`fig.alt`; an image's
  `fig-alt` or bracket text; in a div, its image's or chunk's). An image with
  empty bracket text and no `fig-alt` has no alt text. A table is a `.qmd` chunk
  labelled `tbl-...`, a pipe or grid table, or a `#tbl-` div; it needs a
  caption (`tbl-cap`, a `:` caption line, or an enclosing `#tbl-` div's). One
  finding per missing part, `figure` or `table-caption` (`text` = the label or
  the target; the message names the part). A chunk that plots with neither
  label nor caption is not seen.

  | Source (one project) | Findings (`rule` `text`) |
  |---|---|
  | `See @fig-depth.`, no `fig-depth` anywhere / `#| label: fig-depth` in another chapter | `xref` `fig-depth` / — |
  | `{#sec-a}` in two chapters | `anchor-twice` `sec-a`, at the second |
  | `[x](#results)` to `## Results` (no id) | `section-anchor` `Results` only |
  | `[x](b.qmd#sec-b)`: no `b.qmd` / `b.qmd` without `sec-b` | `file-link` `b.qmd` / `xref` `sec-b` |
  | `.Rmd`: `\@ref(fig:depth)` and a chunk `depth` | — |
  | `[a site | # sites]{n="k"}` and a line `[a site | # sites]: https://x.org` | `ref-label` |
  | `#| label: fig-depth` never referenced; `` `@sec-a` `` | `anchor-unused` `fig-depth`; `xref-code` `@sec-a` |
  | a `{r}` chunk with no label / `#| label: setup` | `chunk-label` / — |
  | `[d](data/x.csv)` missing; `[x](/img/a.png)` present at the root; `[x](https://x.org)` | `file-link` `data/x.csv`; —; — |
  | `_quarto.yml` with `weft:`; `weft: {draft: true}` in front matter beside `_weft.yml` | `config-place` `weft`; `draft` |
  | `a.qmd` with `[x]{if="ok"}`, no `engine: knitr` / with it / named `_a.qmd` | `engine` / — / — |
  | chunk `fig-d` with `fig-cap`, no `fig-alt`; `.qmd` chunk `depth` with both | `figure` `fig-d` (alt text); `figure` `depth` (label) |
  | `![Depth](d.png)` alone / with `{#fig-d}` / `![](d.png)` | `figure` (label) / — / `figure` (alt text) |
  | a pipe table, no caption / with `: Sites {#tbl-s}` | `table-caption` / — |
  | chunk `dict <- read_dict("dict.yml")`; `dict$lim <- 5` | `dict-assign` `dict`; `dict$lim` |
  | `` `r dict$limt` `` (key `limit`); `dict$x` with a local `x`; `dict_local$y`, no local `y` | `dict-key` `limt` ("Did you mean `limit`?"); `x`; `y` |
  | `#| cache: true` with `tar_read(fit)`; `tar_read(fitt)`, store holds `fit` | `tar-cache` `fit`; `tar-name` `fitt` |
  | `weft_setup()` in a chunk at line 20; `[a]{if="x"}` at line 10 | `above-setup` at 10 |

### `label_seed()` (9.5.5; 3b)

- **L36.** `label_seed(paths = NULL, min_count = 2)`: files as `dict_seed()`.
  Counts each word that starts with an upper-case letter, has at least two
  letters and only letters (a trailing `.` allowed), is followed in the same
  block by a numeral (L19), and is not a cross-reference word, already a label
  word, or one of `In On At By For From To Of The An And Or But With Since
  Until After Before About Around Over Under Between During Than Only All Some
  Each Every Nearly Approximately`. Returns a data frame `word, n, files, where` (up to
  three `<file>:<line>: <word> <numeral>`), words with `n >= min_count`,
  sorted by `n` descending then `word`. Writes nothing.

### `recall_check()` (9.5.1; 3a)

- **L37.** `recall_check(findings, source, rules = NULL, commit = NULL,
  window = 2L, nearly = 0.8)`. `findings`: a data frame with `id` and at
  least `quote` or both `file` and `line`; optional `file` (several paths split
  on `;`, `,` or white space), `rule` (ids split on `;`; `NA` = every rule;
  `""` = no rule, counted in `any` only).
  `source`: a folder, linted with `lints(source, rules = rules, tier = 1:2)`.
  With `commit`, `git -C <source> archive <commit>` is unpacked into a
  temporary folder, which is linted and removed.
- **L38. Locating.** Quote and source prose are normalised alike: NFC,
  emphasis marks and backticks removed, curly quotes made straight, white space
  collapsed, lower case, a map kept back to offsets. A finding is located when
  a 40-character window of its quote, taken every 20 characters (the whole
  quote when shorter, if at least 12), occurs in the prose of a document (its
  `file`s first); its unit is every sentence (L12) a matched window overlaps.
  Without a quote, the sentences on lines `line ± window` of `file`. Else it is
  unlocated.
- **L39. Result.** A `weft_recall` data frame, one row per rule and a last row
  `any` (all rules together): `rule, tier, in_scope, located, reproduced,
  recall, flagged, sentences, flagged_sentences, share, verdict`. Reproduced:
  a finding of the rule starts inside the unit. `share` = sentences holding a
  finding of the rule / all sentences read. `verdict`: `"reproduces none"` when
  `located >= 3` and `reproduced == 0`; `"flags nearly everything"` when
  `share >= nearly`; both joined by `"; "`; else `"ok"`. Attributes `matches`
  (`id, located, file, line, rules`) and `unlocated`. `print()` shows the
  table and the verdicts. Errors: a missing column, a `line` that is not whole,
  `source` not a folder, `commit` unknown, git absent: `weft_tool_error`.

### `changes()` (7.3.5; 3d)

- **L40.** `changes()` adds its tier-2 findings after the entries. Documents:
  the file set of L3 (restricted to `files` when given) that differ from the
  commit: `git -C <root> diff --name-only --relative <commit> --` plus `git -C
  <root> ls-files --others --exclude-standard` (paths relative to the root, as
  2e's measurement 10). Added lines: from `git diff -U0 --no-color
  --no-ext-diff <commit> -- <file>` hunks `+c,d` (lines `c` to `c+d-1`; no `d`
  is 1); a file absent at the commit, untracked, or with no commit yet: every
  line. Then `lints(root, files = those, tier = 2)`; a finding is kept when one
  of its lines (`line` to `end_line`) is added.
- **L41.** `x$findings` keeps exactly `file, line, rule, message` (2e's T29),
  sorted by file and line; a `claim-word` message ends with the sentence in
  quotes. When a file has more `claim-word` findings than its `claim_cap`,
  they are one row: `"N added sentences hold claim words; more than the cap of
  <claim_cap>, so they are counted, not listed (rule 5.5.3)."` at the first's line. A
  lint that stops (a configuration error) leaves the table empty and adds a
  note. `print()` (not `brief`) shows `Tier-2 findings` after `New conditions`:
  `  ? <file>:<line>  <rule>  <message>`. The header line is unchanged; a
  result with findings is not "no changes". `claim_words()` in `R/changes.R`
  becomes `setdiff(claim_lexicon(cfg, "en"), c(one..twelve, "first", "second",
  "third"))` (K10). New git commands, all read-only: `diff`, `ls-files`.

## 3. Where the spec is wrong or silent

Decisions, each the smallest change that can be undone.

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| K1 | who decides what is prose (2.10.3, 5.1.4) | Pandoc's tree always; the package's reader always; R by default, Pandoc on request | R reader default; `reader = "pandoc"` intersects with Pandoc's `Str` ranges; tests compare the two | the 300-line bound without Pandoc; one answer on every machine (a gate counting against `HEAD` must not depend on which Pandoc is installed); no 2 MB JSON walk per chapter. Cost: two readers can disagree, so the parity test (§6) pins them | default `reader = "pandoc"` |
| K2 | 2.10.5's block-type check needs two Pandoc reads | always; never; R's line-start check by default and Pandoc's comparison with `reader = "pandoc"` | the last | catches Q9's case (`# ` re-wrapped into an arm) deterministically and cheaply | drop L18's R half |
| K3 | 5.4.2's "innermost block in Pandoc's tree" | Pandoc; R's blocks (L9) | R's blocks | follows K1; the five block kinds are recognisable by line patterns | — |
| K4 | `p<0.05`, `n=12` are names by 5.2.2's first-character rule | as written; split words at `= < > ≤ ≥ ≈ ≠` | split | a typed p-value is the plainest typed number; no name in 5.2.2's list contains these | L12 |
| K5 | an inline ignore (`<!-- weft-ignore -->`) | add; none | none | `.weft-literal` with its `why` is the record (1.8.10); tolerance is `HEAD`'s; an ignore would be a second escape with no reason recorded | add later as a marker |
| K6 | 3.1.6 names a one-arm `if="TRUE"`; 5.6.1 names values only | as written; also two-arm constant `if`, and literal `n`/`sign`/`list` governors | extend both | `{n="3"}` prints a typed 3 through `#`; a constant two-arm `if` always takes one arm | drop the extra kinds |
| K7 | 5.3.3's "one edit" on short names floods (`.r` on highlighted code is one edit from `.p`) | every name; names of 3+ characters, plus case-only for any length | the latter, optimal string alignment (a transposition is one edit: `.nmu`) | `utils::adist()` counts `.nmu` as two | L28 |
| K8 | a cross-reference written inside a code span prints as literal text, and no rule names it | ignore; tier 2 `xref-code` | tier 2 | a real audit class; blocks nothing | drop the rule |
| K9 | 5.8 rule 2 says "manifest": `tar_manifest()` runs `_targets.R` | manifest; the store's metadata; parse `_targets.R` | store metadata | the lints run no project code (6.1.4); 6 ms. Cost: a target defined and never built is reported | `tar_manifest(callr_function = NULL)` |
| K10 | 5.5.1 makes number words claim words; 7.3.4 keeps one–twelve, first–third out of its ranking and says stage 3's lexicon replaces its list | one lexicon for both; ranking keeps its exclusion | ranking = lexicon minus those 15 words | the 2e and 2i tests rely on the exclusion; listing and ranking answer different questions | L41 |
| K11 | 5.5.1's two cases together are every sentence with an unguarded claim word, since tier 2 is scoped to added material anyway | two rules; one rule, two messages | one rule `claim-word` | same finding, the message says which case | — |
| K12 | 5.7.1 puts the reference-label clash under "book-wide" | book-wide; per document | per document | Pandoc resolves `[foo]: url` within one document | — |
| K13 | 5.9.1 "every figure" is not decidable without running code | run; presence of a figure label, caption option, captioned image, `#fig-` div | presence | static (6.1.4) | — |
| K14 | stage 0 assumes findings with lines; the audit's have quotes and no reliable lines | lines; quotes with a window search | quotes first, lines second (L38) | the only way the recorded findings can be placed | — |
| K15 | `changes()` before stage 3 used `rev-parse`, `ls-tree`, `show`, `check-ignore` only | compute added lines from `git show` and a diff in R; `git diff -U0` | `git diff` | read-only; git already knows what was added (5.1.5's rationale) | — |
| K16 | 2e's T29 fixed `findings` at four columns | widen; keep | keep; the full table is `lints()`'s | T29 and its test | widen later |
| K17 | `lints()` default tier | 1:2; 1 | 1 | 5.1.5: tier 2 is for added material | default |
| K18 | `.md` chapters in a book | lint; ignore; read for anchors only | anchors only | a `.md` has no constructs, but a `.qmd` can cite its sections | lint them |
| K19 | which `if` arm counts for 3.1.9 | sum; longest | longest | the hole is one long arm | — |

**Spec edits** after the build: each K row's choice goes into the rule it
names (K1, K2: 2.10.3, 2.10.5, 5.1.4; K4: 5.2.2; K6: 3.1.6, 5.6.1; K7: 5.3.3;
K8, K12: 5.7; K9: 5.8 rule 2; K10: 7.3.4; K13: 5.9.1; K14: 9.5.1); 9.1.2 and
9.1.5 gain L8's keys; 5.1.6 moves after 5.1.5.

## For Robin

Built as chosen until answered.

- **R1 — The package reads prose itself; Pandoc only on request (K1, K2).**
  Reverse: the default of `reader`. Cost of the reverse: about 0.1 s per
  chapter per read, two reads per file for the block check, and results that
  depend on the Pandoc installed.
- **R2 — The names an author types.** `lints()` (not `lint()`, which masks
  `lintr::lint`, nor `weft_lint()`), `lint_rules()`, the rule ids of §1, and
  the keys `label_words`, `numeral_years`, `claim_words: {add, drop}`,
  `claim_cap`, `guard_words`, `expected_names`. Reverse: renames before
  release; nothing reads them yet.
- **R3 — Target names come from the store, not the manifest (K9).** An
  unbuilt target is reported until it is built.
- **R4 — No inline ignore (K5).**
- **R5 — Tier 1 is wider than the spec in three places (K4, K6):** `p<0.05`
  is a typed number; `{n="3"}` is a literal value; a constant two-arm `if` is
  an inert check. Each fails a commit in stage 4. Reverse: L12, L22, L23.

## 4. Stage 0

Stage 0 runs inside stage 3: `recall_check()` is built in 3a, and each lint
package is checked as it merges, before its review.

- **Inputs** (git-ignored): `dev/trials/stage0/findings.csv` (one row per
  recorded finding: an id, a heuristic category, the files named, the quoted
  claim when there is one) and `dev/trials/stage0/pre/R/`, the manuscript's
  sources at the pre-remediation commit. A script there,
  `dev/trials/stage0/recall.R`, renames `quoted_text` to `quote` and
  `location_files` to `file`, keeps the rows raised from the source, maps
  `category` to `rule` and calls
  `recall_check(f, "dev/trials/stage0/pre/R")`. The `.yml` files there are
  not linted, so findings located only in them are unlocated.
- **Mapping** (category → rules): typed literal, number disagrees, unit or
  precision → `numeral;literal-value;value-format`; caption or alt text →
  `numeral;figure;table-caption`; wording contradicts a value →
  `claim-word`; broken cross-reference → `xref;anchor-twice;numeral;xref-code`;
  citation → `citation-key;cite-key`; the rest (code, layout, argument,
  statistics, tone, terminology, definitions, table design) → `""`: they
  count only in `any` and are reported as out of reach.
- **Sent back to design**: a rule with `located >= 3` that reproduces none;
  a rule whose `share` reaches 0.8; `construct` or `block-start` flagging
  anything (the sources hold no constructs). A low recall that is not zero
  is recorded, not acted on (§22: one corpus does not rank lints).
- **Recorded** in `dev/build-log.md`: the table of counts and verdicts only,
  no quote, no value, no name from the manuscript.

## 5. Work packages

3a first and alone; then 3b, 3c and 3d in parallel worktrees, merged in any
order. NAMESPACE and `man/` are regenerated with roxygen after each merge,
never merged by hand. No package after 3a edits a 3a file; a reader change one
of them needs is reported to the orchestrator and made on `main`.

| Pkg | Creates | Edits | Tests |
|---|---|---|---|
| **3a** foundation | `R/lint.R` (`lints()`, `lint_rules()`, registry, `weft_findings` constructor `new_findings()` and `print()`, `lint_config()`, `claim_lexicon()`, the `construct` and `read` lints), `R/lint-source.R` (`read_source()`, prose mask, regions, blocks, `source_sentences()`, chunks, pieces, offset helpers), `R/recall.R`, `inst/weft-claim-words.yml` | `R/config.R` (L8 keys, `validate_lint_config()`); `R/scan-contexts.R` only if the offsets of L9 cannot be recovered outside it | `helper-3a.R`, `test-lint-findings.R`, `test-lint-config.R`, `test-lint-source.R`, `test-lint-construct.R`, `test-recall.R`, `test-lint-perf.R` |
| **3b** prose | `R/lint-prose.R` (`numeral`, `claim-word`, `long-guard`, `label_seed()`), `R/lint-pandoc.R` (`pandoc_path()`, the masked read, `reader = "pandoc"`, `block-start`) | — | `test-lint-numerals.R`, `test-lint-claims.R`, `test-label-seed.R`, `test-lint-pandoc.R`, `test-lint-block-start.R` |
| **3c** code and constructs | `R/lint-code.R` (`literal-value`, `inert-check`, `value-constant`, `value-format`, `lone-bar`, `if-zero`, `name`, `tar-name`, `dict-assign`, `dict-key`, `tar-cache`, `above-setup`) | — | `test-lint-values.R`, `test-lint-names.R`, `test-lint-hygiene-code.R` |
| **3d** documents and project | `R/lint-doc.R` (citations and the static bibliography, anchors and references, `section-anchor`, `chunk-label`, `file-link`, `config-place`, `engine`, `figure`, `table-caption`) | `R/changes.R` (L40, L41) | `test-lint-cite.R`, `test-lint-xref.R`, `test-lint-hygiene-doc.R`, `test-lint-figures.R`, `test-changes-findings.R` |

`helper-3a.R` gives every later test file two helpers: `lint_fixture(files,
rules = NULL, tier = 1:2, ...)`, which writes a named list of file contents
into a `withr::local_tempdir()` (folders created) and returns `lints()` over
it; and `lint_one(text, rules, ext = "qmd", weft_yml = NULL)`, for one
document. `test-lint-perf.R` is run again by the orchestrator after the last
merge, and `recall.R` after each.

## 6. Tests

Each lint against a fixture pair (§21): the source that gives the finding and
the nearest that does not. Every example in §2 is a case, under `.qmd` and
`.Rmd` where both apply. Fixtures are written by the test. Skips: Pandoc
`skip_if(!nzchar(weft:::pandoc_path()))`, git `skip_if(Sys.which("git") ==
"")`, `targets` `skip_if_not_installed()`, timings and `tar_make()`
`skip_on_cran()`.

- **3a.** `test-lint-findings.R`: L5's columns and types, empty result, order,
  duplicates, `notes`; `lint_rules()`; each L14 error; `files` limiting
  findings, not anchors; the file set (L3); default tier; `print()` exactly,
  none, `max`. `test-lint-config.R`: each L8 key's default, project value,
  front matter winning, each message, the same refusals from `read_config()`;
  `claim_lexicon()` for `en-AU`, `de`, none, `add`, `drop`.
  `test-lint-source.R`: each L11 row as the characters it blanks; each L10
  piece; `fstart`/`fend` in every context; each block type; sentences; §21's
  position stress document (repeated and blank blocks, a block equal to a line
  of the chunk above, CRLF, no final newline, BOM), findings at the same line
  and column as in a plain copy; `read`. `test-lint-construct.R`: L17 in each
  context, `spec` from the message. `test-recall.R`: L37–L39, each locating
  path, each verdict at its threshold, `any`, `commit` with the temporary
  folder gone after, `source` untouched, each error. `test-lint-perf.R`: L16.
- **3b.** `test-lint-numerals.R`: L19, label words as typed, years, a
  construct opening a paragraph, §21's late `abstract` numeral at its YAML
  line. `test-lint-claims.R`: L20 (each lexicon list; `if` and `sign` guard,
  `n` does not; captions read, phrases not; `lang`; `add`/`drop`) and L21 at,
  below and above `guard_words`. `test-label-seed.R`: L36, nothing written,
  errors. `test-lint-pandoc.R`: `pandoc_path()` order; pinned: the `data-pos`
  form and that its columns count characters; §21's masking test (the masked
  tree holds no construct, no shifted position, the unmasked tree's block
  types); parity (R prose inside Pandoc `Str`; `Str` outside citations,
  entities, raw TeX and bare URLs is R prose); `reader = "pandoc"` removing an
  R false positive. `test-lint-block-start.R`: L18, and Q9 through Pandoc.
- **3c.** `test-lint-values.R`: L22–L25 in prose, captions, front matter,
  math and strings; `claim()` in chunk code, not in `eval: false` chunks.
  `test-lint-names.R`: §21's "Names" (each weft name changed by one edit, not
  into another weft name, listed with the nearest; case-only keys, Pandoc's
  names and expected names not listed) and "Text spans" (`[1234]{.num}`,
  `.Num`); short names; L26, L27. `test-lint-hygiene-code.R`: `tar-name` with
  a toy store, no store, `store=`; each `dict-assign` form; `dict-key` with
  and without `dict.yml`, local ambiguity, suggestion; `tar-cache` at each
  level, a chunk `false` over a document `true`; `above-setup` per route.
- **3d.** `test-lint-cite.R`: L29–L32 (BibTeX, CSL JSON, CSL YAML,
  `references:`, `_quarto.yml`, a subfolder's `_metadata.yml`, the setting, a
  missing file, each block kind). `test-lint-xref.R`, `test-lint-hygiene-doc.R`,
  `test-lint-figures.R`: L33–L35 and their table, a `.md` chapter's anchor, a
  weft `#id`, setext headings, an include, a child. `test-changes-findings.R`
  (git): added line listed, unchanged not; a re-wrap listed again; new and
  untracked files; no commit; `files`; the cap at, below, above; four columns;
  `print()` with and without `brief`; findings alone are a change; every
  existing `changes()` test still passing, the 2e-2 and 2i claim-word tests
  among them.

## Readings fixed when the 3a tests were written

The test-writer met these gaps; each reading below is now the contract.

1. **L5 and L17.** Rows are duplicates only when `file`, `line`, `col`,
   `rule` and `text` are all equal. Distinct constructs on one line stay
   separate; a multi-line error gives one finding per line.
2. **L6.** `lint_rules()` lists the ids of section 1 in that order and
   with those tiers, and also `read` and `xref-code`, placed after the
   rules they belong with. Every id it lists is accepted by
   `lints(rules = )`. `scope` is `file` or `project`.
3. **L2.** `lints(path)` on a folder or file inside a project lints only
   what is under `path`; `file` in a finding is relative to the project
   root. Project-scope rules still read the whole project.
4. **L7.** The summary line is singular for one: `1 finding in 1 file`.
5. **`reader`.** A value other than the two allowed is a
   `weft_lint_error`.
6. **`lint_config(root, front)`.** `front` is the whole front matter;
   the function takes its `weft:` list itself. `path` is absolute.
7. **`read_source()`.** `front` is a field of the result. `ext` has no
   leading dot. `fblock` is the offset of the attribute block's opening
   `{`, or `NA`. `chunks$open` and `chunks$close` are line numbers.
   `meta` is a list of blocks, empty when there is no front matter.
8. **L9.** A region's text is the text between its delimiters. A
   `text_span` is a span with a formatter class; `.smallcaps` is not one.
9. **L11.** In `title: "x"` the key and the quotes are blank and the
   words are prose. A raw LaTeX command is blank with its braces'
   content. `(3)` and `(@)` list markers are blank; a task marker
   `- [ ]` blanks five characters; the `:` of a definition blanks one.
10. **L12.** A full stop inside a masked code span or citation does not
    end a sentence. A document with no prose gives a zero-row table.
11. **L39.** `flagged` is the number of findings of the rule over the
    source; `flagged_sentences` the number of sentences holding one.
    `recall` is `reproduced / located`. `in_scope` counts findings whose
    `rule` names the rule or is `NA`; a finding with `rule = ""` counts
    only in the `any` row. `rules = NULL` gives a row per
    `lint_rules()$id`, then `any`. `unlocated` is a data frame with
    `id`. Two verdicts are joined with `; ` in the order "reproduces
    none", "flags nearly everything".
12. **L38.** There is no partial last window. A quote under 12
    characters is unlocated. A quote wins over `file` and `line`.
13. **L37.** A missing column, a non-whole `line`, a source that is not
    a folder, an unknown commit, no git, and a commit asked of a folder
    that is not a repository are each a `weft_tool_error`.
14. **L10.** Captions in an `eval: false` chunk are read; `weft_str()`,
    `lookup()` and `brk()` strings in one are not.
15. The helper file is `tests/testthat/helper-3.R`.

## Readings fixed when the 3d tests were written

1. `col` of a finding whose text starts with a sigil (`@fig-x`, `@key`,
   `#id`) is the column of the sigil.
2. For a list under `bibliography:`, a missing file is reported on the
   item's line.
3. In `anchor-twice` the first definition is the first in sorted path
   order, then by line; an anchor in a `.md` file counts as a definition.
4. `![](d.png)` gives exactly one finding, about alt text.
5. An image inside a `#fig-` div takes its label, caption and alt text
   from the div and gives no finding of its own.
6. `engine: knitr` in `_quarto.yml` does not satisfy the `engine` rule;
   an `.Rmd` is never flagged by it.
7. In `file-link` the text is the target as written, without a quoted
   title; `file#x` checks the file part only.
8. `tar-name` belongs to 3c.
9. An unlabelled chunk with `eval: false` is not flagged by
   `chunk-label`.
