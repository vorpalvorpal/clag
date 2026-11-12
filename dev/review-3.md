# Review of stage 3 (static lints)

Independent behavioural review of `main` at 8922a85. Contract: `dev/design-3.md`
(decision 64 and its appended readings). Every finding below was reproduced with
an invented fixture in a temporary project, through `lints()`, `recall_check()`
or `changes_tier2()` as named, with `pkgload::load_all()`, R 4.4 in an
`en_AU.UTF-8` locale, Pandoc 3 from Quarto. Nothing in the tree was changed but
this file.

Count: 3 high, 7 medium, 3 low; 6 design questions.

## High

### 1. An inline footnote followed by another sentence crashes `claim-word`

- **Where:** `R/lint-prose.R`, `lint_claim_word()`; cause in `R/lint-source.R`, `source_sentences()`.
- **Reproduce:** `a.qmd` holding the one line
  `Note^[All rose.] that x fell. Most rose here.`, then
  `lints(root, tier = 1:2)` (or `rules = "claim-word", tier = 2`).
- **Happened:** error `'vec' must be sorted non-decreasingly and not contain NAs`.
  `recall_check()` over the same folder fails the same way (it calls
  `lints(tier = 1:2)`). `changes_tier2()` catches the error, so `changes()`
  silently lists no tier-2 finding for the whole project and adds the error
  text as a note.
- **Also:** with a single sentence, `Note^[All sites rose.] that `r x` fell.`,
  no crash, but the claim word `fell` of the outer sentence is dropped (only the
  note's sentence is reported).
- **Why:** `source_sentences()` emits sentences block by block. The inline
  note is a block that starts inside the paragraph, so its sentences come
  after the paragraph's in the table and start before some of them.
  `lint_claim_word()` then calls `findInterval(ps, sent$start)` on starts
  that are not sorted (error), or, when they happen to be sorted, matches a word
  after the note to the note's sentence and drops it.
- **Should:** L20: one finding per sentence with a lexicon word; L12: a
  sentence per block, the note being its own block.
- **Direction:** sort sentences by start and match each word to the innermost
  sentence that contains it (as `src_block_of()` does for blocks), not by
  `findInterval()` alone.

### 2. Parse-data columns are treated as bytes, so code positions and string pieces shift after a non-ASCII character

- **Where:** `R/lint-code.R`, `pd_tree()`; `R/lint-source.R`, `chunk_literals()`;
  the shared helper `parse_col_chars()` in `R/scan-contexts.R` (also used by
  `scan_chunk_strings()`).
- **Reproduce** (each in an executed R chunk with `#| label: a`, or inline):
  1. `s <- "µg°"; weft_str("over 25")`, `rules = "numeral"`: no finding.
     The prose view of that line is `("over ` followed by spaces: the piece
     window starts 3 characters early and ends 3 early, so `25` is blanked.
  2. `s <- "°C"; weft_str("rose over 25")`: `numeral` with `text = "2"`.
  3. `z <- "été"; claim(n, TRUE)`: `inert-check` at col 20 with
     `text = ", TR"` (should be col 22, `TRUE`).
  4. Inline `` `r paste("été", x * 100)` ``: `value-constant` with
     `text = "* 1"`. `dict$limt` after `"été";` is reported 2 columns early.
- **Why:** in a UTF-8 session `getParseData()` gives `col1`/`col2` in
  characters (checked: `paste("été", x * 100)` gives `100` at
  col 18, its character column). `parse_col_chars()` assumes bytes and converts
  again, moving every position left by the number of extra bytes before it.
- **Should:** L5 `col` counts characters; L10 says `substr(text, fstart, fend)`
  is the construct as written; L19 lists `weft_str()` numerals.
- **Direction:** use parse-data columns as characters (or take the byte columns
  from the srcref and convert those); add a test with non-ASCII before a string
  and before an inline value on the same line.

### 3. Capitalised cross-references (`@Fig-x`) are read as citations

- **Where:** `R/lint-source.R`, `P3_PATTERN` (`xr` alternative, `XREF_PREFIX`);
  `R/lint-doc.R`, `doc_refs()`, `lint_citation_key()`.
- **Reproduce:** front matter `bibliography: refs.bib` (one entry `smith2020`),
  an image `![A map](m.png){#fig-map fig-alt="x"}`, and the line
  `@Fig-map shows it.`; `lints(root, rules = c("citation-key", "xref"))`.
- **Happened:** `citation-key` (tier 1) "The citation key `Fig-map` is not in
  the bibliography". The reference is never checked by `xref`, and a figure
  referred to only as `@Fig-map` is reported by `anchor-unused`.
- **Should:** Quarto renders `@Fig-map` as a capitalised "Figure 1"; L31 says
  `@fig-x` is a cross-reference, not a citation. In stage 4 this blocks a commit.
- **Direction:** match the prefix case-insensitively in the first letter
  (`[Ff]ig`, `[Tt]bl`, ...) in `P3_PATTERN`, `XREF_ID_RE` and `doc_refs()`, and
  compare ids with the first letter lowered.

## Medium

### 4. `changes()` lists every line of a changed file when the project is a subfolder of the repository

- **Where:** `R/lint-doc.R`, `changes_added_lines()`.
- **Reproduce:** a git repo with `report/_quarto.yml` and `report/a.qmd`
  (`All sites rose.` / `Most fell.` / `The largest grew.`, blank lines
  between), committed; change only the last line; `changes_tier2(<repo>/report, <HEAD sha>)`.
- **Happened:** three `claim-word` rows (lines 1, 3, 5). The same files at the
  top of a repository give one row (line 5).
- **Why:** `git cat-file -e <commit>:a.qmd` takes the path from the top of the
  repository, not from `-C <root>`, so it fails and the file is treated as new
  ("every line").
- **Should:** L40: only lines from `git diff -U0` hunks, unless the file is
  absent at the commit.
- **Direction:** use `<commit>:./<file>` (relative to the working folder) or
  `git ls-tree <commit> -- <file>`.

### 5. `reader = "pandoc"` misplaces prose after a tab

- **Where:** `R/lint-pandoc.R`, `pandoc_parse()`.
- **Reproduce:** `Some text\twith a tab and 12 sites.` and, after a blank line,
  `- item\twith 7 here`; `lints(root, rules = "numeral", reader = "pandoc")`.
- **Happened:** line 1 gives `text = "1"` (not `12`); line 3 gives nothing.
  The default reader gives `12` and `7`.
- **Why:** the `data-pos` columns of `commonmark_x+sourcepos` expand a tab to
  the next tab stop, so every `Str` range after a tab is shifted right; the
  intersection then cuts or drops words.
- **Should:** L15: a character is prose when both readers say so; the 3b reading
  pins that `data-pos` columns count characters, which holds only without tabs.
- **Direction:** convert Pandoc columns to characters per line with a tab-stop
  of 4, or replace tabs with one space in the text given to Pandoc (lengths kept).

### 6. Pipes hide calls from the code rules

- **Where:** `R/lint-code.R`, `lint_inert_check()`, `value_constants()`,
  `lint_value_format()`, `target_reads()` (all use `call_info()` on the call as
  written).
- **Reproduce:** inline
  `` `r claim(n, . > 10)` `` / `` `r n |> claim(. > 10)` `` / `` `r n |> claim(TRUE)` `` / `` `r n %>% claim(TRUE)` ``
  and `` `r round(x, 2)` `` / `` `r x |> round(2)` `` / `` `r x %>% round(2)` ``,
  rules `inert-check`, `value-constant`, `value-format`.
- **Happened:** the piped `claim(TRUE)` gives no `inert-check` (tier 1 miss);
  `n |> claim(. > 10)` gives `value-constant` `10`; `x |> round(2)` gives no
  `value-format` and a `value-constant` `2`. Only the unpiped forms behave.
  `fit |> tar_read()` is not seen by `tar-cache` either.
- **Should:** L23 (each check argument with no variable), L24 (`claim(n, . > 10)`
  and `round(x, 2)` give nothing), L25 (`round` outermost).
- **Direction:** when the call is the right side of `|>` or `%>%`, shift its
  argument numbering by one (the piped value is argument 1), and look through
  a pipe for the outermost call in `value-format`.

### 7. `table-caption` misses captions Pandoc accepts

- **Where:** `R/lint-doc.R`, `lint_table_caption()`.
- **Reproduce:** (a) `: Sites {#tbl-s}`, blank line, then a pipe table;
  (b) a pipe table, blank line, `table: Sites`; `rules = "table-caption"`.
- **Happened:** a `table-caption` finding (tier 1) for each.
- **Should:** L35 counts "a `:` caption line". Pandoc reads both as the
  table's caption (checked with `pandoc -f markdown`: `Caption ... Str "Sites"`
  and id `tbl-s` for (a)). Only `Table:` is accepted before the table, and only
  `:` or `Table:` after.
- **Direction:** accept `:`, `Table:` and `table:` both before and after.

### 8. A span that holds a citation is masked whole, hiding its numbers and claim words

- **Where:** `R/lint-source.R`, `P3_PATTERN` (`cb` alternative) in `mask_prose()`.
- **Reproduce:** `We saw [see @smith2020 for 3 sites]{.mark} here.` and the same
  with `{if="ok"}`; `rules = "numeral"`.
- **Happened:** no finding. The bracket is taken as a citation group, blanked,
  and recorded as a `citation` region.
- **Should:** a `[...]` followed by an attribute block is a span (Pandoc reads it
  so); its text is prose (L11, "a span's bracket text is prose"), and only the
  `@smith2020` inside is a citation. `3` should be a `numeral` finding.
- **Direction:** exclude from `cb` a bracket whose `]` is followed by `{`, so the
  inner `@key` falls to the `ct` alternative.

### 9. Asking for a tier-2 rule without `tier` returns nothing, silently

- **Where:** `R/lint.R`, `lints()` (the `sel` line).
- **Reproduce:** `a.qmd` = `All sites rose.`; `lints(root, rules = "claim-word")`.
- **Happened:** zero findings, no note; `tier = 1:2` gives one.
- **Should:** L2 does not say that `rules` is filtered by the default `tier`.
  An author who names a rule reads "no findings" as "the rule passed".
- **Direction:** when `rules` is given and `tier` is missing, take the tiers of
  those rules; or at least add a note naming the rules dropped by `tier`.

### 10. Building findings one at a time costs about 5 ms each

- **Where:** `R/lint.R`, `new_findings()` (calls `lint_rule_table()` every
  time; that function `rbind`s 33 one-row data frames); used per item by
  `value-constant`, `inert-check`, `name`, `anchor-twice`, `anchor-unused`,
  `above-setup`, `cite-key` and others.
- **Reproduce:** 1,000 lines `Line i has `r x[i] * 100` here.`;
  `lints(root, rules = "value-constant", tier = 2)` takes 14 s for 1,999
  findings (`numeral` over the same file: 0.8 s). A generated 4,960-line
  chapter with every rule takes 9.8 s on the second call; the profile puts
  51% of it in `lint_rule_table()`. `lint_rule_table()` alone: 5.5 ms a call.
- **Should:** L16 (1,800 lines under 3 s). A document at adoption, before its
  numbers are made values, is exactly the case with thousands of findings.
- **Direction:** build the rule table once (a package-level constant) and have
  rules collect vectors and call `finding_at()` once.

## Low

### 11. `section-anchor` takes a multi-line paragraph over `---` for a heading

- **Where:** `R/lint-source.R`, `mask_prose()` / `build_blocks()` (setext detection).
- **Reproduce:** `Para line one` / `line two` / `---` / blank / `After.`;
  `rules = "section-anchor"`.
- **Happened:** `section-anchor` (tier 1) `Para line one line two`.
- **Should:** Pandoc markdown reads this as one paragraph ending in an em dash
  (checked); a setext heading is a single line. The `---` is also blanked from
  the prose.
- **Direction:** recognise a setext underline only under a one-line paragraph.

### 12. One-edit name check flags common code-span classes

- **Where:** `R/lint-code.R`, `lint_name()`, `nearest()`.
- **Reproduce:** `` `int x`{.cpp} ``, `` `x`{.end} ``, `[u]{.data}``; `rules = "name"`.
- **Happened:** `name` findings: `.cpp` "one edit from `.cap`", `.end` from
  `.and`, `.data` from `.date`.
- **Should:** K7 aims to spare highlighting classes (`` `x`{.python} `` gives
  nothing); `.cpp` is a standard Pandoc highlighting language.
- **Direction:** skip classes that are Pandoc highlighting languages on code
  spans (`pandoc --list-highlight-languages`), or require 4+ characters for the
  edit test on a code span.

### 13. Two messages lose their punctuation

- **Where:** `R/lint.R`, `lints()` (unknown rule); `R/lint-code.R`, `lint_dict_key()`.
- **Reproduce:** `lints(root, rules = "numerals")` gives
  "Unknown rule: `numerals` Did you mean `numeral`? (rule 5.1.1)."; a `dict$zzz`
  with no near key gives "`dict$zzz` is not a key of dict.yml. (rule 5.8.6)."
- **Direction:** join with "; " in the first; drop the "." before the empty
  suggestion in the second.

## Looked at and found sound

- Positions: CRLF, BOM, no final newline, several trailing newlines, non-ASCII
  and emoji in prose before a numeral, findings in front-matter scalars, folded
  and block scalars, a late metadata block, `#|` captions (scalar and block),
  header `fig.cap`, `weft_str()` strings without non-ASCII before them.
- The prose mask: code spans, fenced and raw blocks, indented code (tab and
  spaces, list continuations kept as prose), HTML comments and tags, entities,
  URLs, autolinks, DOIs, e-mail addresses, citations with locators, shortcodes,
  footnote markers, link and image targets and titles, list markers inside and
  outside a paragraph, definitions, block quotes, pipe and grid tables, display
  and inline math, `$` amounts.
- `numeral`: ordinals, decades, ranges, percentages, `3:1`, `label_words`
  (including a no-break space), `numeral_years`, the cross-reference message.
- `claim-word` guards (`if` guards, `n` does not), captions, front matter,
  tables, `claim_words` add and drop, `lang`.
- Project handling: a file, a folder, a subfolder and `files =`; ignored
  folders; `weft_env$lint_reader`; an invalid UTF-8 file (one `read` finding
  and a note, others still linted); empty, front-matter-only and unparsable
  documents; bad YAML front matter.
- `.Rmd` `\@ref()`, derived `fig:`/`tab:` anchors and `(\#fig:x)` in a header
  caption; `above-setup` (including `weft_setup()` in a string); `tar-cache` at
  front-matter and chunk level; `dict-key`/`dict-assign` with variable keys and
  shadowing; figure divs, sub-figures and inline images; `chunk-label` across
  engines; `literal-value` and `if-zero` on their table.
- `recall_check()`: quote and line locating, the `any` row, an invalid file in
  the source.

## Design questions

The code follows the design in each of these; the design looks wrong.

1. **`block-start` (L18, K2; spec 2.10.5, Q9) assumes CommonMark.** Quarto and
   R Markdown render with Pandoc's `markdown` reader, whose
   `blank_before_header`, `blank_before_blockquote` and list rules keep a span
   whole when a wrapped line starts with `#`, `>`, `-`, `+`, `*`, `1.`, `:::` or
   `~~~` (checked: `We saw [a site |` / `# sites]{n="k"} today.` is one `Span`
   under `-f markdown`). Only a backtick fence cuts it. So the R half reports
   tier-1 findings for spans that render correctly. The same choice of
   `commonmark_x` under `reader = "pandoc"` drops prose that renders: the
   text of `<div class="note">` / `Raw 10 text` / `</div>` is a `RawBlock` to
   CommonMark but a `Para` to `markdown`, so `10` is lost.
2. **L3 skips folders starting with `_`, so included files there hold no
   anchors.** `See @sec-methods.` with `{{< include _partials/_methods.qmd >}}`
   (which defines `{#sec-methods}`) gives a tier-1 `xref`. Quarto's own
   convention puts includes in such folders. Read `_` folders for anchors (as
   `.md` files are), without linting them.
3. **`file-link` (L34) checks the source tree only.** `[the other page](other.html)`
   beside `other.qmd` is a tier-1 finding, as is a link to a PDF the render
   produces. Treat `x.html` as present when `x.qmd`/`x.Rmd` exists, or make
   output-type targets tier 2.
4. **`section-anchor` (L34) applies to callout titles and tabset tabs.**
   `::: {.callout-tip}` / `## Tip with a title` and the `## Tab A` headings
   inside `::: {.panel-tabset}` are tier-1 findings, though they are not
   sections and an id on them serves nothing. Skip headings inside those divs.
5. **`inert-check` (L23, `all.vars()` empty) flags varying conditions.**
   `[text]{if="knitr::is_html_output()"}` and `[b]{if="interactive()"}` are
   tier-1 findings with the message "always takes the same arm", which is false.
   Exempt calls with no arguments, or a short list of known output and session
   predicates.
6. **The claim lexicon (L8a) is wide.** `above`, `below`, `more`, `one`, `two`,
   `no`, `any`, `each`, `first`, `last`, `record` make `See the section above.`,
   `More details below.` and `Use one of the two options.` claim-word
   sentences. It is tier 2 and capped, but the `share` verdict of
   `recall_check()` will read "flags nearly everything" on most prose.
   Consider moving the navigation words (`above`, `below`) and bare number
   words out, or requiring a value in the sentence for them.

A note on L5, not a defect: L5 drops duplicates on `file, line, col, rule,
text`, which would merge `figure`'s separate "no label", "no caption" and "no
alt text" findings for one chunk (same place, same text). The code adds
`message` to the key, which keeps them; L5 should say so.

## Rulings (orchestrator, 13 Nov, under delegation)

Findings 1 to 13 are accepted and are fixed as the review suggests, with
these readings:

- 3: a reference whose prefix is a Quarto cross-reference type in any
  letter case (`@Fig-map`, `@Tbl-x`, `@Sec-y`) is a cross-reference.
- 5: the Pandoc reader maps columns through tab stops of four.
- 6: both the native pipe and `%>%` are read as the call they make.
- 9: a rule named in `rules` is run whatever its tier, when `tier` is
  not given. With `tier` given and a named rule outside it, a note says
  so.
- 12: the one-edit check does not flag a class on a code span unless a
  weft class is at distance one and the span has a governor or key.

Design questions:

1. `block-start` fires only at a marker that Pandoc's `markdown` reader
   really cuts a paragraph at. The test-writer checks each marker with
   `quarto pandoc` and pins what it finds; the others give no finding.
2. Anchors are collected from documents in folders that start with `_`
   (not `_site`, `_book`, `_freeze`, `_extensions`), so `xref` sees
   included files. No finding is reported in those files.
3. `file-link` passes a link to a rendered output whose source document
   exists beside it (`other.html` with `other.qmd`, `.Rmd` or `.md`).
4. `section-anchor` skips a heading inside a callout div or a
   `.panel-tabset` div.
5. `inert-check` calls a condition inert only when it holds no symbol
   and no call other than operators and parentheses.
6. The claim-word list is trimmed (decision 66).

From stage 0 (counts in `dev/build-log.md`):

- S1. `recall_check()` credits a flag outside a prose sentence (a chunk
  header or option, a caption) by its lines: a finding located on a
  line a rule flagged is reproduced.
- S2. Under `numeral_years: true` a year range (`2016-17`,
  `2016-2017`), a decade (`2010s`) and a possessive (`2019's`) are
  years.
- S3. `xref-code` does not fire inside an HTML comment of several lines
  that holds a blank line and an indented line.
- S4. The default claim-word list is the 30 words of decision 66.

Not fixed, recorded in `dev/open-findings.md`: a label word joined to
another by a hyphen (`SIGNAL-SF 2`) is not exempt; `table-caption`
flags a table whose caption a helper function supplies.
