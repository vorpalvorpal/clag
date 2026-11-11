# weft spike: `cite` spans and marked literals

Root: `/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/`
(paths below are relative to it). Tools: quarto 1.11.9 (bundled Pandoc 3.10), knitr 1.51, rmarkdown 2.31
(which uses the system Pandoc **3.8.3**, a different Pandoc from Quarto's), R packages yaml 2.3.12 / jsonlite 2.0.0.
Extended stand-in: `setup.R` (copy of spike-grammar2/setup.R, unmodified original untouched). Captions use `caption.R`
(copy of spike-captions/caption.R, one `source()` line changed). Test drivers: `harness.R`, `t1_forms.R` ... `t7_bare_all.R`.
Outputs of every rendered test doc are in `docs/` (`<name>.qmd|.Rmd`, `<name>_q_html.html`, `_q_docx.docx`, `_q_typst.pdf` + `<name>.typ`,
`_r_html_document.html`, `_r_word_document.docx`, `*.log`). Full-run transcript: `full_run.txt`.

## What the stand-in now does (what I implemented)
- `cite` is a wrapper key (never printed). Citation form (value contains `@`): `<prose> [<value verbatim>]`. Bare form: prose only.
- Keys are checked against the bibliography; unknown key is an error with `file:line`.
- Bare form: the span's "paragraph" must cite each key (rules under 2.).
- Attribute values: double-quoted or unquoted only (`clag_attr`). Backslash anywhere in a value, a single-quoted value, or `"` in an unquoted value is an error.
- `why` is dropped from `weft-literal` spans (by cutting the attribute's characters out of the `]{...}` tail) and divs (by rewriting the opening fence line before scanning).

# (i) What I ran and saw

## 1. Citation form (quarto html/docx/typst, rmarkdown html_document/word_document). Doc `docs/forms.qmd|.Rmd`, driver `t1_forms.R`
| Fact | Renderer / format | Evidence |
|---|---|---|
| All variants (`@k`, `@k, p. 4`, `see @k`, `@a; @b`, `-@k`, `@{k}`, unquoted `cite=@k`) are real citations; citeproc formats them: `(Smith 2020)`, `(Smith 2020, 4)`, `(see Smith 2020)`, `(Smith 2020; Jones 2019)`, `(2020)`; reference list has both entries | quarto html, quarto docx, rmarkdown html, rmarkdown docx | `docs/forms_q_html.html`, `forms_q_docx.docx`, `forms_r_html_document.html`, `forms_r_word_document.docx` |
| Same text is a citation when the span ends a sentence (`...catchment (Smith 2020).`), before punctuation (`(Smith 2020), and`), in a heading, list item, table cell, block quote | all five | same files (html source shows `<span class="citation" data-cites="smith2020">(<a href="#ref-smith2020" ...>Smith 2020</a>)</span>.` directly followed by `.`) |
| Inline footnote `^[...]` and `[^1]:` definition: citation resolved inside the footnote text, entries in reference list | quarto html, docx (checked `word/footnotes.xml`), rmarkdown html, docx | `forms_q_docx.docx`, `forms_r_word_document.docx` |
| Caption in chunk option (`#\| fig-cap: \|`) resolves to a citation; the bare caption prints `Figure 1: Caption with 10 m (Smith 2020) in it.` | quarto html/docx/typst, rmarkdown html/docx (rmarkdown has no "Figure 1:" prefix) | `forms_q_html.html`, `forms_r_html_document.html` |
| **Typst**: Pandoc writes native Typst citations (`@smith2020`, `@smith2020[p.~4]`, `(#cite(<smith2020>, form: "year"))`) and Typst's own bibliography (numeric `[1]`), not citeproc. Citations in heading, list, table, quote, footnote, caption all resolve (pdftotext) | quarto typst | `docs/forms.typ`, `docs/forms_q_typst.pdf` |
| **Typst drops the prefix**: `cite="see @smith2020"` prints `[1]`, "see" is lost. Locator survives (`[1, p. 4]`). Two keys print `[1], [2]` | quarto typst | `forms.typ` line `Prefix: ... @smith2020 upstream.`, pdf text |
| Citation inside a heading puts the key in the heading's auto id (`heading-with-a-catchment-smith2020-here`) and in the typst label | quarto html, rmarkdown html, typst | `forms_q_html.html`, `forms.typ` |
| `@fig-a` cross-reference is Quarto-only; in the Rmd it stays `(fig-a?)` (my test artefact, not a weft issue) | rmarkdown | `forms_r_html_document.html` |

## 2. Bare form and the "paragraph cites each key" check (`t2_bare.R`, 40 cases x quarto-html + rmarkdown-html_document; `bare_results.csv`, `bare_run.txt`)
| Fact | Evidence |
|---|---|
| 78 of 80 renders matched my expectation; the 2 mismatches are one case (b39, see (iii)). quarto and rmarkdown agree in every case | `bare_run.txt`, `bare_results.csv` |
| PASS: same paragraph; key cited before or after span; `[@k]`; `-@k`; `[see @k, p. 4; @j]` covering `cite="k; j"`; `@{k}`; hard-wrapped paragraph; inside one list item; one block-quote paragraph; one table row; inside a `^[note]`; inside a `[^1]:` definition; inside the caption string; value nested in the span (`` `r x`{.dec1} ``) | cases b01, b03, b04, b05, b08, b09, b12, b14, b17, b20, b22, b23, b26, b30, b31, b34, b40 |
| FAIL (error with the right `file:line`, e.g. `b02_next_para.qmd:16: the paragraph holding [10 m]{cite=...} does not cite @smith2020; cite it in the same paragraph`): key cited only in the next paragraph; one of two keys missing; `@smith2020a` (longer key) ; `` `@smith2020` `` in a code span; `foo@smith2020` (e-mail); cite in a different tight-list item, a loose-list item, another table row, the table header; heading + citation on the next line; cite in the body but span in the `[^1]:` definition; cite outside `^[...]` but span inside; span outside the note but cite inside it; span and cite in different paragraphs of a div; span before a code chunk and cite after it (different text blocks); caption span with cite only in a body paragraph (before or after the chunk) | cases b02, b06, b07, b10, b11, b13, b15, b16, b18, b19, b21, b24, b25, b32, b33, b35, b36 |
| Unknown key is an error in both forms (`unknown citation key nosuchkey (not in the bibliography: 1 file(s) via QUARTO_EXECUTE_INFO)`), also the second key of `@a; @nosuch` | b27-b29 |
| `cite` with `n=` is an error ("a cite span has no arms and cannot carry n"); `cite="smith2020;"` is an error | b37, b38 |
| Bare form prints prose only in all five formats, incl. heading, list, quote, table, both footnote forms and caption (`Heading: Depth 10 m per Smith (2020)`) | quarto html/docx/typst, rmarkdown docx: `docs/bare_all_*` (`t7_bare_all.R`) |

**How a paragraph is delimited (decision).** The `text` hook gets all prose between two code chunks as one string, so I split it myself (`clag_scoper`, `setup.R`). A *unit* is a maximal run of non-blank lines, additionally cut before: an ATX heading line (and after it), a list marker line (`-`, `*`, `+`, `1.`, `1)`), a `[^id]:` line, a pipe-table row (`|` first), a `:::` fence line. Leading `>` is ignored. A `^[...]` inline note is its own scope: a span inside it is checked against the note's text only, and a span outside it ignores note text (found by bracket matching, `drop_notes`). Cites inside backtick spans are ignored; a key counts as cited only as Pandoc citation syntax `-?@key` or `@{key}` not preceded by a word character and not followed by a key character.
- Implementable with only block text: all of the above, 78/80 expected results. The caption case needs nothing extra: `clag_str` hands the caption string to the same code, so the caption string is its own scope (cite must be in the caption).
- Awkward: (1) the line-start heuristics are not a Markdown parser: a wrapped line that begins `1986. ` or `- ` or `#` splits a paragraph wrongly; indented/nested constructs, setext headings, grid/simple tables, multiline pipe cells, definition lists, line blocks and fenced divs containing list continuation paragraphs were not tested. (2) Table cell = whole row (cells are not separated; splitting on `|` conflicts with arms and `\|`), so a cite in a different cell of the same row passes. (3) A paragraph cannot straddle a code chunk, so span-before-chunk/cite-after always fails, which is also what Pandoc would see only if the chunk emits nothing. (4) Text produced by chunks with `results: asis` is not in the text hook at all (not tested). (5) Whole-block text only: an `{{< include >}}` or shortcode is not expanded.

## 3. Finding the bibliography at knit time (`bib/`, probe `bib/probe.R`, outputs `bib/**/probe_*.txt`, `bib/**/execinfo_*.json`; `t*`/hook runs in `hookbib/`)
| Case | Accessor that works | Where it fails | Evidence |
|---|---|---|---|
| `bibliography:` single file in front matter, quarto | `rmarkdown::metadata$bibliography` -> `"../refs.bib"`; also `QUARTO_EXECUTE_INFO` JSON `format$metadata$bibliography` -> `["../refs.bib"]` | - | `bib/probe_a1_quarto.txt` |
| same, rmarkdown | `rmarkdown::metadata$bibliography` (and `rmarkdown::yaml_front_matter(knitr::current_input(dir=TRUE))`) | no QUARTO_* env vars | `bib/probe_a2_rmd.txt` |
| list of files, quarto / rmarkdown | `rmarkdown::metadata$bibliography` -> character vector; quarto JSON list | - | `bib/probe_b1_quarto.txt`, `probe_b2_rmd.txt` |
| `bibliography:` only in `_quarto.yml` (document in project root and in a subdirectory), quarto | `QUARTO_EXECUTE_INFO` -> JSON file; `format$metadata$bibliography`; Quarto already rewrote the path relative to the document (`refs.bib`, and `../refs.bib` from `sub/`) | `rmarkdown::metadata` and `yaml_front_matter` are **NULL** here (front matter only) | `bib/proj/probe_p1_quarto.txt`, `bib/proj/sub/probe_p2_sub_quarto.txt` |
| project `_quarto.yml` bib + document bib | quarto JSON gives the merge, project first: `["refs.bib","refs2.bib"]`; inline `references` also in JSON | `rmarkdown::metadata$bibliography` gives only the document's `"refs2.bib"` | `bib/proj/probe_p4_doc_plus_project.txt` |
| book (`project: type: book`, bibliography in `_quarto.yml`), index + chapter | `QUARTO_EXECUTE_INFO` -> `format$metadata$bibliography` -> `["refs.bib","refs2.bib"]` in every chapter | `rmarkdown::metadata` is an empty list in book chapters | `bib/book/probe_book_ch1.txt`, `probe_book_index.txt` |
| rmarkdown doc inside a Quarto project dir | nothing (project bibliography is not applied by rmarkdown anyway) | `rmarkdown::metadata$bibliography` NULL; hook errors "0 file(s)" | `bib/proj/probe_p3_rmd_in_quarto_project.txt`, `hookbib/proj/p3.Rmd` run |
| rmarkdown `output: html_document: pandoc_args: ["--bibliography=refs.bib"]` | **nothing** at knit time (`rmarkdown::metadata$bibliography` NULL) though Pandoc resolves `Smith (2020)` | invisible to the hook | `bib/proj/probe_p5_rmd_pandoc_args.txt`, `bib/proj/p5.html` |
| inline `references:` in front matter | `rmarkdown::metadata$references` (both renderers); quarto JSON `format$metadata$references` (also merged into JSON for project docs) | - | `bib/proj/probe_p4*`, `probe_p5*`; hook run `hookbib/fmt/f_inline.qmd|.Rmd` |
| `QUARTO_PROJECT_DIR`, `QUARTO_DOCUMENT_PATH` | **do not use**: in this environment both held the same ancestor directory of the scratchpad for every document and project, not the project root | wrong | `bib/*/probe_*.txt` env lines |
| `QUARTO_DOCUMENT_FILE` is right (`p1.qmd`); `document-path` inside the JSON is the full correct path of the `.qmd` | usable | | `bib/proj/execinfo_p1_quarto.json` |

Implemented accessor (`bib_sources()` in `setup.R`): if `QUARTO_EXECUTE_INFO` exists read the JSON (`jsonlite`) and use `format$metadata$bibliography` + `$references`, resolving paths against `dirname(document-path)`; else `rmarkdown::metadata`, resolving against `dirname(knitr::current_input(dir=TRUE))`. Verified with the hook: front matter single/list (`docs/*`), `_quarto.yml` only (`hookbib/proj/p1.qmd`, `sub/p2.qmd` ok), book (`hookbib/book/_book/*.html`, both chapters resolved), inline references, rmarkdown + front matter. Only failure: rmarkdown + project-level or `pandoc_args` bibliography (hook reports 0 files, so every `cite` key errors as unknown).

**Key extraction** (500 entries each; generated by `bib/keys/gen.R`; run `bib/keys/run_keys.R`, `run_pcc.R`; table in `key_extraction_results.txt`; extraction code `weft_keys.R`)
| Method | BibTeX | BibLaTeX | CSL JSON | CSL YAML (plain `references:`) | CSL YAML (`---` delimited) |
|---|---|---|---|---|---|
| `quarto pandoc -f <reader> -t csljson FILE`, parse ids (`keys_pandoc`) | ok 500, 0.88 s (first call) | ok 500, 0.38 s | ok 500, 0.22 s, but **needs `-f csljson`** (without it: "JSON parse error", exit 64) | **needs wrapping in `---`**; unwrapped gives `[]` (0 keys, no error) | ok 500, 0.36 s, but ids are **smartened**: `o'brien2017` comes back `o’brien2017` (markdown reader) |
| native R (regex on `^@type{key,`; `jsonlite`; `yaml::read_yaml`) (`keys_native`) | ok 500, 0.01 s | ok 500, 0.02 s | ok 500, <0.01 s | ok 500, 0.01 s | ok 500, 0.01 s |
| `rmarkdown::pandoc_citeproc_convert(f, "list")` (runs `pandoc FILE -s -t csljson`) | ok 500, 0.27 s | ok 500, 0.15 s | **error 64** | returns 0 entries silently | ok 500, 0.16 s |
| `quarto pandoc nocite.md --citeproc --bibliography=FILE -t csljson` (as a format-detecting trick) | returns `[]` for all five (does not work) | | | | |
- There is no single portable Pandoc call: reader must be chosen from the file extension (`.bib`->biblatex, `.bibtex`->bibtex, `.json`->csljson, yaml->markdown with `---`). Native parsing matched Pandoc's id set exactly for all five formats on my generated files (incl. keys with `:`, `.`, `-`, `_`, `ü`, `'`).
- Hook runs with each format as the bibliography, both renderers, 500-entry files: `hookbib/fmt/f_{bibtex,biblatex,csljson,cslyaml,cslyamldelim,inline}.qmd|.Rmd` all rendered, the citation resolved, two reference entries. (The native parser accepted plain CSL YAML without `---`, as Pandoc's `--bibliography` does.)

## 4. What Pandoc itself does with an unknown key (`t4_unknown.R`, `unknown_run.txt`, docs `unk*`)
| Renderer / format | Result |
|---|---|
| quarto html, quarto docx, rmarkdown html_document, rmarkdown word_document (bibliography present) | `[WARNING] Citeproc: citation nosuchkey not found` (also for the bare `@nosuch2`), **exit status 0**, output produced; citation printed as `(nosuchkey?)` (checked in rmarkdown html; quarto html output contains `nosuchkey?` too) |
| same four, **no bibliography at all** | no warning, exit 0; `[@nosuchkey]` stays as literal text |
| quarto typst | **exit status 1**, no output: `error: label <nosuchkey> does not exist in the document` / `error: citation key nosuch2 is not present in the bibliography` (with no bibliography: `the document does not contain a bibliography`) |
So the backstop is a warning only (html, docx), a hard error only in typst, nothing when there is no bibliography.

## 5. Does the quoting restriction bite? (`t3_quote_nested.R`; docs `quote_ok`, `quote_err1..11`)
Legal Pandoc citations that **cannot** be written as a double-quoted or unquoted value:
- A suffix or prefix containing `"`: `[@smith2020, ch. 2 "Methods"]`. Error with my rule. **Workaround that works**: `cite="@smith2020, ch. 2 &quot;Methods&quot;"` renders `ch. 2 "Methods"` (quarto html, rmarkdown html).
- A suffix containing a backslash escape or raw LaTeX: `p. 4 \S 2`, `\*x\*`, `\textit{..}`. Error. `&#92;` gives a *literal* backslash (`p.\ 4`), `&sect;` gives the character; but an escape or raw-TeX command cannot be written. 
- A braced key containing `"`: `@{quote"key}` is a valid Pandoc citation (resolves in Pandoc: `(Quoted 2016)`; CSL JSON id `quote"key`). Cannot be written; `&quot;` does **not** work inside a key (Pandoc: `citation quote&quot;key not found`). (BibTeX/BibLaTeX keys cannot contain quotes, only CSL JSON/YAML ids.)
- An *unquoted* braced key `cite=@{https://doi.org/10.1000/xyz}`: the `}` ends the attribute block (error). Must be quoted.
Not a problem: URL/DOI keys when quoted (`cite="@{https://doi.org/10.1000/xyz}, p. 2"` resolves, `(Doi 2017, 2)`); apostrophes (`Smith's 'own' table`) are fine; `[sic]` brackets are fine; `@{key with spaces}` is **not a Pandoc citation at all** (Pandoc leaves `[@{key with spaces}]` as literal text) so nothing to write.
Detecting the rule: a backslash, a single-quoted value and a `"` inside an unquoted value are caught directly. A `"` inside a double-quoted value just ends the value early; what follows is usually not an attribute, so without a heuristic the whole `{...}` silently becomes prose. I added one (a `]{` whose block is not well-formed but contains `key=` is an error, "malformed attribute block after ']'", `quote_err7`). This also now applies to every key (`claim`, `why`, ...): `claim="\"a\""` and `why="the \"SOP\""` are errors too.

## 6. Nested content in `cite` spans (`docs/nested.qmd|.Rmd`, `t3_quote_nested.R`; all five formats rendered)
| Fact | Evidence |
|---|---|
| `[depth `r x`{.dec1} m at [a site \| # sites]{n="n_sites"}, a\|b and #1 and \\\| and \\#]{cite="@smith2020"}` prints `depth 0.6 m at 5 sites, a\|b and #1 and \| and # (Smith 2020)`: bare `\|` and `#` are literal, the nested value and nested governed span resolve | `nested_q_html.html`, `_q_docx.docx`, `_r_html_document.html`, `_r_word_document.docx`, typst pdf (`nested_q_typst.pdf`: `... #1 and \| and # [1]`) |
| Bare form with same nested content prints prose only: `Smith (2020) found depth 0.6 m at 5 sites, a\|b and #1` (the `@smith2020` in prose is Pandoc's narrative citation) | same |
| A cite span inside an `n` arm keeps its own `\|` and `#` literal: `5 sites, 10 m \| x #y (Smith 2020)` | same |
| In a table cell, `[x \\\| y # z]{cite="@smith2020"}` prints `x \| y # z (Smith 2020)` | same |

## Construct 2: marked literals (`t5_literal.R`, `t5b_check.R`, `t5c.R`, `t6_nohook.R`; docs `nohook`, `lit_basic`, `lit_split`, `lit_nest`, `lit_chars`, `lit_forms`)
### 1. No hooks (`docs/nohook.qmd|.Rmd`; `quarto pandoc -f markdown ... -t latex`)
| Format | Span `[0.45 µm]{.weft-literal why="..."}` | Div `::: {.weft-literal why="..."}` | `why` visible? | Evidence |
|---|---|---|---|---|
| quarto html (Pandoc 3.10) | `<span class="weft-literal" data-why="pore size, SOP 12">0.45 µm</span>` | `<div class="weft-literal" data-why="laboratory method, ...">` | **yes, `data-why`** on both | `docs/nohook_q_html.html` |
| rmarkdown html_document (Pandoc 3.8.3) | `<span class="weft-literal" why="pore size, SOP 12">` | `<div class="weft-literal" why="...">` | **yes, as a bare `why=` attribute** (not `data-`) | `docs/nohook_r_html_document.html` |
| quarto docx, rmarkdown docx | plain run `0.45 µm`, no style, no attribute | plain `BodyText` paragraph | no (0 occurrences of `why`/`weft` in document.xml) | `nohook_q_docx.docx`, `nohook_r_word_document.docx` |
| quarto typst | `0.45 µm` plain | `#block[ ... ]` | no | `docs/nohook.typ` |
| LaTeX (`quarto pandoc -f markdown -t latex`, also system pandoc 3.8.3) | `{0.45 µm}` (a TeX group), class and why dropped | paragraph only, no wrapper | no | `lit/nohook.tex`, `lit/` |

### 2-3. With the hook
| Fact | Renderer / format | Evidence |
|---|---|---|
| `why` removed from span and div; class `weft-literal` passes through (`<span class="weft-literal">`, `<div class="weft-literal">`); no `data-why`/`why=` in any html; no reason text in docx/typst; text intact (`0.45 µm were used`, `stored at 4 °C`) | quarto html/docx/typst, rmarkdown html/docx | `lit_basic_*`, `lit_check_run.txt`, `t5c.R` run |
| Works when the opening fence and closing fence are in different text blocks (a chunk between) | same five | `lit_split_*` (1 weft-literal div in html, no why) |
| Works for a div nested in a div, in a list item, in a block quote, and for a `::::` four-colon fence | same five | `lit_nest_*` (4 divs, 0 `data-why`) |
| `why` containing a comma, semicolon, apostrophe, `#`, `\|` and `\|\|`, `[x] {y} (z) ] }`, and an unquoted value all work, in both div and span form | same five | `lit_chars_*` (11 literal elements, 0 `why`) |
| Attribute order independent (`{why=".." .weft-literal}`), `#id`, `lang=en`, extra class and `data-k` kept (`<span id="lit1" class="weft-literal" lang="en">`) | quarto html | `lit_forms_q_html.html` |
| `why` on a span without `.weft-literal` is left untouched (`data-why` still emitted) and a div inside a non-executed code fence is not rewritten | quarto html, rmarkdown html | `lit_forms_*` |
| Inside a governed arm and inside a `fig-cap` the span resolves and loses `why` (`Inside an arm: 0.45 µm at 5 sites.`; `Caption with 0.45 µm pores.`) | all five | `lit_basic_*` |
| `why` containing `"` or `\` is an error: `attribute why: a backslash inside a value is not allowed` | quarto html | `quote_err9`, `quote_err10` |
All 25 renders (5 docs x 5 combos) succeeded (`full_run.txt`). `lit_check_run.txt` flags "unq" and "with id" hits: both are my substring false positives (they match the words "unquoted" and "div with id" in body text); `t5c.R` confirms the only `why` left in `lit_forms` is the visible code-fence line.

# (ii) What I did not run
- LaTeX/PDF (only `quarto pandoc -t latex` for the no-hook literal; no `cite` under LaTeX/biblatex/natbib).
- `output: bookdown::*`, blogdown, `_site.yml`, `_output.yml`, `_bookdown.yml`, `_metadata.yml`, Quarto profiles, `csl:` style changes, `link-citations`.
- bibliography given as a list including a `.yaml`/`.bibtex`/`.ris`/`.enl`/`.xml` file; BibTeX `@string` macros; `crossref`; keys with non-ASCII punctuation beyond `ü`; duplicated keys across files.
- The paragraph check inside a Quarto `{{< include >}}`, `results: asis` output, shortcodes, callouts with titles, definition lists, setext headings, grid tables, line blocks, tight lists with continuation lines, nested lists, and tables with spans containing `\|` plus a cite in a neighbouring cell.
- Other attributes on a `cite` span (`.num`, `#id`) are dropped by my implementation; not tested.
- Timing of the whole hook on a large document; only key-file parsing was timed.
- `why` removal under `n`/`if` arms where the opening fence of a div sits *inside* a bracketed span; `:::` fences written without braces plus `why` (not possible: no attribute block); divs written with `<div>` HTML.
- Pandoc 3.10 vs 3.8.3 differences beyond the `data-why` attribute naming and typst.
- Not committed anywhere: the spike directory is not a git repo.

# (iii) Surprises and rules that are not implementable as written
1. **"A `"` inside a value is an error" is only partly detectable.** `\`, single-quoted values and `"` in unquoted values are. A `"` inside a double-quoted value is indistinguishable from the closing quote; it needs a heuristic ("a `]{` block that fails to parse but contains `key=`"), which I added; not exact, and tuned only on my test strings.
2. **Legal Pandoc citations that cannot be written** (section 5): suffix/prefix with raw backslash escapes or raw LaTeX; a braced key containing `"` (only possible via CSL JSON/YAML ids). `&quot;` and `&#92;` work for literal characters in prose, not in keys.
3. **`cite` value containing any `@` is citation form**, so a bare list with one stray `@` (`cite="smith2020 and @jones2019"`, case b39) silently becomes `[smith2020 and @jones2019]`, passes the key check (jones2019 is known) and prints a citation with prefix `smith2020 and`. The paragraph check is not applied to citation form, by design.
4. **Passing the key check does not guarantee Pandoc sees a citation**: `cite="@{key with spaces}"` passes (CSL JSON id exists) but Pandoc leaves `[@{key with spaces}]` as literal text (docs `quote_ok_*`). The check should also validate the key against Pandoc's key grammar (or reject spaces).
5. **Typst loses the prefix** (`see`) and numbers citations with Typst's own default style; unknown key is a typst compile error (exit 1) but only a warning in html/docx.
6. **Quarto-only project bibliography.** Under rmarkdown there is no way at knit time to learn a `_quarto.yml`/`pandoc_args` bibliography; the hook cannot check keys there, and an Rmd in a Quarto project errors with "0 file(s)". The Quarto accessor is `QUARTO_EXECUTE_INFO` (JSON), not `QUARTO_PROJECT_DIR`, which was wrong here.
7. **Two different Pandocs**: `quarto render` uses 3.10, `rmarkdown::render` the system 3.8.3; raw `why` is `data-why` vs `why=` in html. After weft removes `why` this no longer matters for `weft-literal`, but any attribute weft leaves behind (a non-literal `why`) differs.
8. **Smart-typography on ids**: reading CSL YAML through Pandoc's markdown reader changes `o'brien2017` to `o’brien2017`; parse YAML natively instead. Plain CSL YAML needs `---` for Pandoc's reader; `.json` needs `-f csljson`.
9. **Headings with a citation-form span** put the key into the heading's anchor id / typst label.
10. A paragraph boundary heuristic is the weakest implemented part (section 2, "Awkward"). Everything the design asked for in 1-6 and construct 2 otherwise worked as written on the cases run.
