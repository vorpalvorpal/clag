# Review of package 2d — the ledger and the condition log

Reviewer: independent, from the frozen snapshot `snap-2d` (commit 401b969),
installed into a private library. Every finding below was reproduced by a
render or a direct call; the probe scripts are in the scratch folder
`rev2d/` (`p1.R` … `p19.R`, plus a Quarto project `p/q1`). Values are
invented. Tools: R with rmarkdown 2.31, knitr 1.51, Quarto 1.11.9,
Pandoc 3.8.3, macOS.

## Summary

The core of 2d holds up well: an unchanged document writes byte-identical
files across repeated renders, a served chunk cache, a different working
directory, a project render against a single-file render, and `freeze`.
The JSON is valid and `read_ledger()` round-trips the writer's output for
quotes, backslashes, control characters, astral-plane characters,
latin1-marked strings, NaN/Inf and huge or tiny numbers. Entries for
children (relative and absolute `child=` paths), `knit_child(text=)` loops,
Quarto includes, nested spans, front matter, `weft_str()` and draft-mode
failures are as the contract says. The serious problems are at the edges of
*which* knit and *which* file. A nested `rmarkdown::render()` in a chunk
silently drops every entry and condition the outer document recorded before
it. A `doc.Rmd` that sits beside a `doc.qmd` files its ledger under
`doc.qmd`. The writer follows a symlinked `_weft` or `_weft/ledger` out of
the project, against weft's own never-through-a-link rule. A non-ASCII
character in the source's path under the root stops both files being
written. One malformed line in the condition log does the same at every
render until someone fixes it by hand. Smaller items: an `integer64` raw
value is garbage; `format: gfm` and `format: typst` documents raise the
`-o` warning at every render; three heading cases disagree with D10; and the
no-permission case raises two warnings. A 200-construct document costs about
10% more to render when set up (0.44 s → 0.49 s).

Counts: silent wrong output 3, data written outside the project 1, crash 2,
contract mismatch 5.

## Findings

### 1. A nested `rmarkdown::render()` inside a chunk drops the outer document's earlier entries and conditions — silent wrong output

Reproduction (`p15c.R`): `doc.Rmd`, set up, rendered with
`rmarkdown::render("doc.Rmd", md_document())`:

````
```{r setup, include=FALSE}
weft::weft_setup()
```
## Out

```{r ow}
warning('outer warn before')
```

Before `r 1+0`.

```{r nest, include=FALSE}
rmarkdown::render('inner.Rmd', rmarkdown::md_document(), quiet = TRUE, envir = new.env())
```

Outer `r 1+1`.
````

with `inner.Rmd` holding `Inner `r 2+2`.` (with or without its own
`weft_setup()` chunk).

- Actual: `doc.md` prints "Before 1." and "Outer 2.", but
  `_weft/ledger/doc.Rmd/doc.jsonl` holds only the `1 + 1` entry, and
  `doc.conditions.jsonl` holds the header alone. The warning "outer warn
  before" and the entry `1 + 0` are gone. Separately, `inner.Rmd` gets its
  own files, even when it never called `weft_setup()`.
- Expected: the outer ledger has both entries (`1 + 0`, `1 + 1`), and the
  outer log has the `ow` warning (D7, D15). Nothing the outer knit recorded
  should be lost. Whether the inner render gets files is a question (D21
  covers children only), but it must not cost the outer render anything.
- Likely cause: the single knit state in `weft_env$state`. When the inner
  top-level knit starts, `ensure_knit()` (`R/hooks.R`) creates a new state
  and replaces the outer one, which is never restored. The outer
  `finish_document()` then writes from a state that holds only what came
  after the nested render. Stage 1's failures and stamps probably suffer
  the same way; I checked only the ledger and the log.

### 2. Rendering `doc.Rmd` that sits beside a `doc.qmd` files the ledger under `doc.qmd` — silent wrong output

Reproduction (`p17.R`): the project holds `_weft.yml`, `doc.Rmd`
(`Rmd version `r 1`.`) and `doc.qmd` (`Qmd version `r 2`.`). Render
`rmarkdown::render("doc.Rmd", md_document())`.

- Actual: `_weft/ledger/doc.qmd/doc.jsonl`, header
  `{"weft":"ledger","version":1,"source":"doc.qmd","output":"doc"}`, and an
  entry with `"file":"doc.Rmd"`. A later `quarto render doc.qmd` overwrites
  it, and the Rmd's render overwrites the qmd's in turn. This is common
  while a document is being moved from R Markdown to Quarto.
- Expected: `_weft/ledger/doc.Rmd/doc.jsonl` with `"source":"doc.Rmd"`
  (D1: "the `.qmd`, not the `.rmarkdown` copy", which concerns Quarto's
  intermediate file only).
- Likely cause: `state_source()` in `R/collect.R` maps
  `\.(rmarkdown|rmd)$` (case-insensitive) to `.qmd` whenever that file
  exists. Under rmarkdown the input is the author's own `.Rmd`. Only
  `.rmarkdown`, and only under Quarto (`QUARTO_EXECUTE_INFO` set), should
  be mapped. The same function names the source for the collection file and
  the stamps, so they share the error.

### 3. The writer follows a symlinked `_weft` or `_weft/ledger` out of the project — data written outside the project

Reproduction (`p5.R`, cases A and B): in a set-up project,
`_weft/ledger` is a symlink to a folder `outside/` that is not in the
project (case B: `_weft` itself is the link). Render a document that has a
value and a warning.

- Actual: `outside/doc.Rmd/doc.jsonl` and
  `outside/doc.Rmd/doc.conditions.jsonl` are created, outside the project.
  There is no warning. (Case B: `outside/ledger/doc.Rmd/...`.) A symlink
  that is committed to git travels with a clone.
- Expected: D6 says "Only the two files and their directory are touched".
  Weft's own rule since review 2c, finding 1, is that it never writes
  through a link (`use_dictionary()` refuses, `R/dict-tools.R`). The writer
  should refuse with a `weft_ledger_warning` naming the link (D26 style),
  or at least refuse when the resolved path leaves the root.
- Held: a symlinked ledger *file* (case C) is replaced by a regular file
  through the rename. Its target outside the project is not written.
- Likely cause: `write_whole_file()` in `R/ledger.R` calls
  `dir.create(recursive = TRUE)` and `file.rename()` on the joined path
  with no link check.

### 4. A non-ASCII character in the source's path under the root writes neither file — crash (caught as a warning)

Reproduction (`p7b.R`, `p14.R`): a set-up project with
`rapports-é/doc.Rmd`, `Résumé.Rmd` or `x/Résumé.Rmd`, holding
`A `r 1`.`, rendered with `rmarkdown::render()` in an `en_AU.UTF-8`
session.

- Actual: `weft: the ledger could not be built: Character encoding must be
  UTF-8, Latin-1 or bytes (rule 7.1.3).` No `_weft/ledger` is written, the
  condition log included, and the same happens at every render. A
  non-ASCII project root with an ASCII source is fine, and so are a
  non-ASCII child file name, chunk label, `#id`, expression and heading.
- Expected: `_weft/ledger/rapports-é/doc.Rmd/doc.jsonl` with
  `"file":"rapports-é/doc.Rmd"` (D1, D8). French, German or Scandinavian
  folder and file names are ordinary.
- Likely cause: `ledger_entries()` (and `condition_rows()` for a
  `<file>#<section>` source) sorts with `order(..., method = "radix")`,
  which refuses non-ASCII strings in native ("unknown") encoding. The
  `file` field comes from `normalizePath()`/`substring()` in
  `ledger_file()`, and `source` from `state_source()`, both in native
  encoding. An `enc2utf8()` on `file`, `section` and `source` before the
  sort (and in `state_source()`) should fix it.

### 5. A condition-log line whose `text` is null or missing stops both files being written, at every render — crash (caught as a warning)

Reproduction (`p10.R`, case D): render a document whose chunk `load`
warns "Removed 12 rows", then replace the log's entry line with

```
{"from":"chunk","source":"load","class":"warning","normalised":"Removed <n> rows","text":null}
```

(or the same line with no `text` field) and render again.

- Actual: `weft: the ledger could not be built: missing value where
  TRUE/FALSE needed (rule 7.1.3).` Neither the ledger nor the log is
  rewritten. The bad line stays, so every later render fails the same way
  and the ledger stops tracking the document.
- Expected: D18, "Reading the file on disk for D16 is lenient". A line
  with no usable `text` should not supply one: use this knit's text and
  write both files.
- Likely cause: `condition_rows()` in `R/ledger.R` carries
  `prior$text[j]` forward even when it is `NA` (`read_condition_log()`
  turns null or missing into `NA`). `json_str(NA)` then fails at
  `if (!validUTF8(x))`. The ledger and the log share one `tryCatch` in
  `finish_document()`, so a fault in either loses both.

### 6. An `integer64` value's `raw` is a denormal number — silent wrong output

Reproduction (`p12.R`; `p3.R` directly): `b <- bit64::as.integer64('5000000000')`,
then `Big int `r b` here.`

- Actual: `"text":"5000000000"`, `"raw":2.47033e-314`.
  `weft:::ledger_raw(bit64::as.integer64("5"))` gives `2.470328e-323`.
- Expected: `5e+09`, or `null` (D11 lists double, integer, year, `units` and
  `weft_text`). `raw` ranks changes (7.1.7), so a garbage value misranks
  every change to such a value.
- Likely cause: `ledger_raw()` passes `is.numeric()` (true for
  `integer64`) and then `as.numeric(unclass(v))`, which reinterprets the
  64-bit integer as a double's bits. Drop the `unclass()`, or keep only
  `double`/`integer` storage with known classes.

### 7. `format: gfm` and `format: typst` raise the `-o` warning at every render — contract mismatch

Reproduction (`p/q1`, `d.qmd` with `format: gfm`, plain `quarto render d.qmd`,
no `-o`):

- Actual: `weft: this render's output file is not visible to weft, so its
  ledger is named after the source (d) …` at every render. A project render
  repeats it for each such document. In `QUARTO_EXECUTE_INFO`,
  `format$pandoc[["output-file"]]` is absent for `gfm` and `typst`, and
  present for html, md, markdown, commonmark, docx, odt and revealjs.
- Expected: D2 raises the warning only "when (3) is absent
  (`quarto render -o`)". Here the output is `d.md`, named after the source,
  so the ledger name is right and the warning is noise. People learn to
  ignore it, and then miss it for a real `-o`.
- Likely cause: `ledger_output_name()` treats any missing `output-file` as
  `-o`. The `-o` case could be told apart by `format$pandoc$to` with the
  known gaps, or by comparing the source's base name with the output files
  Quarto reports. Otherwise state in D2 which formats lack the field and
  stay quiet for them.

### 8. Lines Pandoc does not read as headings become sections — contract mismatch (D10)

Reproduction (`p4.R`):

```
## Other {#methods}

M2 `r x`.

<!--
## Hidden
-->

After comment `r x`.
```

and

```
Para line
## Not a heading

NH `r x`.
```

- Actual: the entries are filed in sections `"hidden"` and
  `"not-a-heading"`. Neither heading exists in the output: Pandoc shows the
  first as a comment and the second as `Para line \## Not a heading` (the
  `blank_before_header` extension, on in both Pandoc's markdown and
  Quarto's).
- Expected: the nearest real heading, `"methods-1"` (see finding 9) and the
  section above the paragraph. D10 says "the anchor of the nearest
  heading". A commented-out heading is a normal way to hide a draft
  section, and removing the comment markers later re-keys nothing, while
  the hidden heading meanwhile re-keys everything below it.
- Likely cause: `heading_anchors()` in `R/ledger.R` skips front matter and
  fences, but not `<!-- … -->` spans, and does not require a blank line
  (or the start of a block) before an ATX heading.

### 9. An explicit `{#id}` that repeats an earlier anchor is given `-1` — contract mismatch (D10)

Reproduction (`p4.R`): `## Methods`, then later `## Other {#methods}`.

- Actual: the second section is `"methods-1"`.
- Expected: D10, "The anchor is the heading's `{#id}` when it has one".
  Pandoc keeps the explicit `methods` (with a duplicate-identifier
  warning). Weft's suffix means that adding an unrelated `## Methods` above
  re-keys a section the author pinned with an id, which is the case `{#id}`
  is meant to prevent (G6).
- Likely cause: in `heading_anchors()` the `while (a %in% used)` loop runs
  for explicit ids as well as for generated ones.

### 10. A ledger folder without write permission raises two warnings, and the weft one gives no reason — contract mismatch (D26)

Reproduction (`p5.R`, case D): render, `chmod 555 _weft/ledger/doc.Rmd`,
change a value, render again.

- Actual: first a base `simpleWarning` "cannot open file
  '…/.doc.jsonl.tmp76003': Permission denied", then
  `weft_ledger_warning` "weft: could not write …/doc.jsonl: cannot open the
  connection (rule 7.1.3)." The render carries on, which is correct.
- Expected: D26, "one `weft_ledger_warning` naming the path". The reason
  ("Permission denied") should be in the weft message, and the raw warning,
  which also exposes the temporary file's name, should not escape.
- Likely cause: `write_whole_file()` in `R/ledger.R` catches errors but not
  warnings from `writeBin()`/`file()`.

### 11. A source whose file name has a space is filed under rmarkdown's temporary copy — contract mismatch (D1)

Reproduction (`p18.R`, `p8.R`): `my reports/a b.Rmd`, rendered from its own
folder with `rmarkdown::render("a b.Rmd", md_document())`.

- Actual: `_weft/ledger/my reports/a-b.Rmd/a-b.jsonl`, with
  `"source":"my reports/a-b.Rmd"` and `"file":"my reports/a-b.Rmd"`. That
  file is rmarkdown's copy, deleted after the render. Rendered from the
  project root by an absolute path, it is `_weft/ledger/a-b.Rmd/…` and the
  folder is lost. The same happens to other shell characters (`x/d'x.Rmd` →
  `d-x.Rmd`).
- Expected: D1, the source's own path, `my reports/a b.Rmd`. The output
  name `a-b` is right, because rmarkdown names the output `a-b.md`.
- Likely cause: rmarkdown knits a sanitised copy, and `state_source()` sees
  only that copy. rmarkdown keeps the original name in its `render()`
  frame (the frame D2 already reads for `output_file`), so `state_source()`
  could map it back. Otherwise say in D1 that such names are not supported.

## Tried and held

- **Byte-identical rewrites:** a second identical render; a render served
  from the chunk cache (with `weft_str()` and a warning in the cached
  chunk), a render after the cache was invalidated, and a re-render from
  that cache; a Quarto project render against a single-file render; a
  render from another working directory; `freeze: auto` (files and their
  modification times untouched when served from freeze); rewritten after an
  edit.
- **Locales:** the sort is bytewise (`_part.qmd` < `a.qmd`, `zürich` <
  `ärger-über-öl`), and number formatting does not depend on the locale.
  Under `LC_ALL=C`, knitr and rmarkdown themselves mangle non-ASCII text in
  the *document* (`# R<c3><a9>sum…`, `nchar("é")` = 8 under Quarto), and
  the ledger follows what was knitted. Not a 2d defect; see question F.
- **JSON:** valid and round-tripped for `"`, `\`, U+0007, U+001F, U+2028,
  U+00A0, astral characters, latin1-marked strings, `NaN`, `Inf`, 2^40,
  1e-300 and 3,000-word text. `read_ledger()` equals `last_knit()$ledger`.
  `-0` is written `0`. `json_str()` turns invalid UTF-8 into U+FFFD.
  (Invalid UTF-8 in a printed value or a warning stops the render earlier,
  in stage 1, whether or not the project is set up: outside 2d.)
- **Entries:** `child=` given relatively and as an absolute path
  (`file.path(getwd(), …)`) both give `file` `parts/part.Rmd` and `occ`
  1, 2. A non-ASCII child file name, chunk label, `#id` and expression all
  work. `knit_child(text=)` in a loop gives `occ` 1–3 and the calling
  chunk's section. Constructs in lists, block quotes, footnotes and table
  cells, a value nested in an `if` arm, a block-scalar `title:` and a
  multi-line `subtitle:` (context `front-matter`, section `""`), a value in
  a heading (section is the heading's anchor without the value), and a
  Quarto include (its `file`, the spliced section, in the parent's ledger)
  all hold.
- **Sections against Pandoc:** these give Pandoc's identifier:
  `{-}`/`{.unnumbered}`, a leading number (`2024 Zürich` → `zürich`),
  accented letters, `A.B. 3.5 test`, `Footnotes & lists`, emphasis with
  `*`, a heading in a `:::` div, and duplicate headings (`-1`).
- **Sentences:** decimals do not end a sentence; `?` and `!` do; a value at
  the start or end of a block or without a final stop; a two-line
  paragraph is joined; a 1,400-character sentence is cut to 400 characters
  with `…`, multibyte-safe.
- **When written:** `knit_exit()` (entries above it written); a chunk error
  after a good render leaves both files byte-identical; a failed claim
  under a Quarto project render with the collection file writes the entry
  `failed: "failed claim"`, `raw` set; `WEFT_REHEARSE=1` writes no
  `_weft`; `rehearse()` leaves the files unchanged.
- **Output names:** `output_dir`, `output_file = "README"`,
  `output_format = "all"` with two formats (one `doc` ledger), `WEFT_OUTPUT`
  with `..`, `.`, `/`, `\`, a newline or a space (nothing escapes
  `_weft/ledger/<source>/`), Quarto `-o other.html` (warns, uses `a`),
  `format: html` + `gfm` (one `c` ledger), and a Quarto project with a
  subfolder (`sub/b.qmd`).
- **Condition log:** carry-forward of a hand-edited text; a conflicted file
  (markers skipped, the first of two lines kept); a version-2 header
  (warns, rewritten as 1); an unknown extra field; `"version":"1"` as a
  string; `text` as an array (first element); CRLF and a BOM. New-condition
  report: a repository whose root is above the project and whose path has
  spaces; a dirty index (compares with `HEAD`, as D19 says); no commits
  (every line new, as the ruling says).
- **Speed:** 200 constructs over 40 sections: 0.44 s not set up, 0.49 s set
  up (median of 3, outside a git repository).
- **Not run:** two renders of one output at the same moment. The brief
  allows one R process at a time. By reading, the temporary name carries
  the process id and the rename is atomic.

## Questions for the author

**A. Anchors that are not Pandoc's.** D10 applies the identifier rule to
the source text, so markup that Pandoc removes stays in the anchor:
`## See [the site](http://example.org/a)` → `see-the-sitehttpexample.orga`
(Pandoc: `see-the-site`), and `## The _real_ data` keeps its underscores.
G6 says the anchor equals Pandoc's for a plain heading, which is true, but
people put links and `_emphasis_` in headings, and 2e will show these
anchors to readers. *Recommend:* before filtering, drop link and image
targets (`](…)`), footnote references (`[^…]`), raw HTML tags and emphasis
markers. The keys stay stable, and they then match the document's real
anchors more often.

**B. Abbreviations end sentences.** `For example, e.g. `r x` sites were
dry.` gives the sentence `5 sites were dry.`, and `Mr. Smith had `r y`.`
gives `Smith had 7.`. This matches D12 as written. *Recommend:* treat
`.` followed by a space and a lower-case letter or a digit as no boundary,
or keep a short list (e.g., i.e., cf., et al., Mr., Dr., Fig., approx.).
The sentence only feeds `changes()`'s display, so a cheap fix is enough.

**C. Failure markers with line numbers in `sentence`.** In draft mode and
under a collection file, a failed construct's sentence (and that of every
other entry in the same sentence) holds
`<<weft: failed claim, line 13>>`. Inserting a line above it then changes
those ledger lines, which is the line-number churn G19 and 7.1.4 set out to
avoid. *Recommend:* remove weft's markers from `sentence`, or replace each
with a fixed token.

**D. Invisible and bidirectional characters written raw.** U+202E, U+2066
(bidi controls) and U+0085 are written as themselves, so `a‮b` in a diff
displays reversed (the "Trojan Source" problem). *Recommend:* add U+0085,
U+061C, U+200E/F (already in), U+202A–U+202E and U+2066–U+2069 to
`JSON_INVISIBLE`.

**E. A log that git never holds.** If `_weft/ledger/` is in `.gitignore`,
or the repository has no commit, every render reports every condition as
"new since HEAD", for ever. *Recommend:* when the log is not tracked
(`git ls-files --error-unmatch`), compare with the last render and say so,
as is done outside a repository.

**F. A non-UTF-8 session.** Under `LC_ALL=C` or `POSIX`, which is common
on CI runners and in Docker images, knitr changes the document's non-ASCII
text, and weft's own `expr_key()` deparses `"é"` as `"<U+00E9>"`
(`LC_ALL=C Rscript -e 'weft:::expr_key(…)'`). Every key under a non-ASCII
heading, and every such expression, then differs from a UTF-8 render, and
the ledger churns between a laptop and CI. *Recommend:* when
`!l10n_info()[["UTF-8"]]`, do not write and raise one
`weft_ledger_warning` that names the locale.

**G. `WEFT_OUTPUT` keeps its extension.** `WEFT_OUTPUT=other.html quarto
render a.qmd -o other.html` writes `other.html.jsonl`, but
`rmarkdown::render(output_file = "other.html")` writes `other.jsonl`. So
one output has two ledgers depending on the route, and the warning's
advice invites the extension. *Recommend:* strip the extension from
`WEFT_OUTPUT` as from the other sources (D2 says "base name without its
extension"), and say so in the warning.

**H. Output names ending `.conditions`.** `WEFT_OUTPUT=doc.conditions` (or
an output file `doc.conditions.md`) writes its ledger to
`doc.conditions.jsonl`, which is output `doc`'s condition log. Unlikely,
but the files would overwrite each other silently. *Recommend:* refuse
such a name with a `weft_ledger_warning`, or name the log
`<output>.jsonl` and `<output>/conditions.jsonl`.

**I. Footnote sentences.** A value in a footnote has the sentence
`[^1]: A note with 7 in it.`. *Recommend:* strip the definition marker,
as list markers already are.

**J. Captions in cached chunks.** D22 and G22 promise that cached captions
are replayed, but stage 1 (rules 1.10.5, 2.3.5) refuses a caption construct
in a `cache=TRUE` chunk, so only `weft_str()` rows can be replayed.
*Recommend:* reword D22 so that 2e does not count on cached captions.
