# spike-frontmatter: results

Root: `/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-frontmatter/`
(paths below are relative to it). Tools: quarto 1.11.9, knitr 1.51, rmarkdown 2.31, R package `quarto` 1.5.1.
Stand-in: a copy of `../spike-grammar2/setup.R` (unchanged) in each test directory.
Activation used unless stated: `knitr: opts_knit: weft: !expr source("act.R")$value`, where `act.R` installs the
hooks only if `getOption("weft.act")` is unset (see Surprises 1: idempotence is required).
Test content: `We sampled [a site | # sites]{n="3"}, mean `r nrow(mtcars)`{.num} m.`  (resolves to "We sampled 3 sites, mean 32 m.").
Formats: Quarto html/docx/typst (typst checked through the PDF text via pdftotext), rmarkdown html_document/word_document.
Drivers: `A_forms.R`, `A_start.R`, `A_scope.R`, `B_late.R`, `B_hostile.R`, `B_book_div.R`, `C_probe.R` (+ `C_summary.R`), `lib.R`. Logs: `*.log`.

## (i) What I ran and saw

### A1. Do constructs in title / subtitle / abstract / description resolve, and where does the output land?
| Fact | Renderer / format | Shown by |
|---|---|---|
| Yes. All four fields resolve to "... 3 sites, mean 32 m." (attribute block and governed span both). With the hooks off the same text stays as `a site \| # sites` / `32{.num}`. | quarto html | `A_forms/block_quarto_html.qmd`, control `block_noact_quarto_html.qmd` |
| Title, subtitle, abstract (under the "Abstract" heading) resolved in the right place; docx core props `dc:title` and `dc:description` also resolved (title in `Title` style, subtitle `Subtitle`, abstract `Abstract`) | quarto docx | `A_forms/block_quarto_docx.qmd`, `A_forms.log` |
| Title, subtitle, "Abstract" heading + abstract resolved in title-block order (description is not printed in the PDF; its PDF metadata was not inspected) | quarto typst | `A_forms/block_quarto_typst.qmd` |
| Quarto html puts description in a `div.description` in the title block AND `<meta name="description">`, resolved | quarto html | `A_forms/block_quarto_html.html` |
| rmarkdown html_document: title, subtitle, abstract resolved. `description:` is not emitted at all (no meta tag, no div): stock behaviour, not weft | rmarkdown html | `A_forms/block_rmarkdown_html_document.Rmd` |
| rmarkdown word_document: title, subtitle, abstract resolved; `dc:description` resolved | rmarkdown docx | `A_forms/block_rmarkdown_word_document.Rmd` |
| Every format above gives the same result for block (`\|`), folded (`>`), single-quoted, and plain forms | all 5 | `A_forms.log` |

### A2. YAML scalar forms
| Fact | Renderer / format | Shown by |
|---|---|---|
| Block `\|` and folded `>`: work in all 5 formats with `{`, `#`, `\|`, backtick, `"` all literal. Both forms make Pandoc parse the value as a markdown BLOCK, so HTML gets `<h1 class="title"><p>TITLE ...</p></h1>` and `<h3 class="subtitle"><p>..</p></h3>` (a `<p>` inside a heading); quoted and plain give a bare inline | quarto + rmarkdown html | `A_forms/block_quarto_html.html` vs `sq_quarto_html.html` (raw_h1 rows in `A_forms.log`) |
| Single-quoted `'...'` with `n="3"` (double quotes inside): works in all 5 formats | all 5 | `A_forms/sq_*` |
| Single-quoted with the attribute written `n='3'`: YAML doubles it to `n=''3''` in the raw text knitr sees. The stand-in does not resolve it and does NOT error: title comes out as "a site \| # sites sampled" (silent non-resolution) | quarto + rmarkdown html | `A_start/bracket_sq_quarto.qmd` |
| Double-quoted with the usual `n=\"3\"`: FAILS at render. knitr sees the raw YAML text, with the backslashes: `error evaluating \"3\": unexpected INCOMPLETE_STRING` | all 5 | `A_forms/dq_*.qmd`, `A_forms.log` |
| Double-quoted with `n='3'` instead: works in all 5 formats | all 5 | `A_forms/dq2_*` |
| Plain unquoted: works for the test string even though ` # sites` is a YAML comment start. The first YAML parse (before knitr) just truncates the value; knitr runs on the raw text and the post-knitr YAML parse sees the resolved text | all 5 | `A_forms/plain_*` |
| Plain value STARTING with `[` (a governed span first) FAILS before knitr: "while parsing a flow sequence ... did not find expected ',' or ']'" | quarto html, rmarkdown html | `A_start/bracket_plain_*` |
| Plain value STARTING with a backtick (a value first) FAILS before knitr: "found character that cannot start any token" | quarto html, rmarkdown html | `A_start/backtick_plain_*` |
| Starting with a construct is fine in double-quoted (with `n='3'`), single-quoted, block, folded forms | quarto html, rmarkdown html | `A_start.log` |
| Failure AFTER knitr: if the resolved text contains `"`, `'`, `: ` and ` #` (I used the string `" : #1'` from `intToUtf8(c(34,32,58,32,35,49,39))`), double-quoted, single-quoted and plain forms all FAIL when the rendered front matter is re-parsed ("mapping values are not allowed" / "did not find expected key"). Block and folded survive (the text prints as typographic quotes). I did not isolate which character breaks which form | all 5 | `A_forms/haz_*`, `A_forms.log` |
| Failure BEFORE knitr when the R code itself holds the delimiter: `"X `r "a"` x"` (dq) and `'X `r 'a' ` x'` (sq) give a YAML parse error at once. Quarto reports `YAMLException: bad indentation of a mapping entry (2:19)` with a stack trace; rmarkdown a yaml.load error | quarto html, rmarkdown html | `A_forms/preq_dq_*`, `preq_sq_*` |
| Net: block `\|` (or folded `>`) is the only form with no escaping trouble before or after knitr; its cost is the `<p>`-in-heading output | | |

### A3. Scope of front-matter constructs (evaluated before any chunk)
| Fact | Renderer / format | Shown by |
|---|---|---|
| Object defined in a LATER chunk: NOT visible. `exists('later')` is FALSE in the title and TRUE in the body; a `` `r later`{.num} `` in the title fails: `doc.qmd:2  object 'later' not found` (the error cites the right file and line 2) | quarto html, rmarkdown html | `A_scope/fm_probe_*`, `fm_later_construct_*` |
| Object defined in `.Rprofile` (`rp <- 1`): visible (`exists('rp')` TRUE, value 1) | quarto html, rmarkdown html | `A_scope/fm_params_construct_*` |
| `params$p` (from front-matter `params: {p: 7}`): visible, `exists('params')` TRUE, value 7 | quarto html, rmarkdown html | `A_scope/fm_probe_*`, `fm_params_construct_*` |
| `nrow(mtcars)` (datasets and base calls): works, 32 | quarto html, rmarkdown html | same |

### A4. Is each activation route early enough for a construct in the same front matter?
| Fact | Renderer / format | Shown by |
|---|---|---|
| Front matter `knitr: opts_knit: weft: !expr ...`: YES. Resolves in the same front matter (all of A1/A2 used it) | all 5 | `A_forms/` |
| `.Rprofile` in the document directory: YES. Title resolves (`S 32 3 sites`) | quarto html, rmarkdown html | `A_scope/rprofile_construct_*` |
| Setup chunk (`source("setup.R"); clag_install()`): TOO LATE. Title keeps `32{.num} a site \| # sites` (the span reduced to Pandoc span text, no error), body is resolved | quarto html, rmarkdown html | `A_scope/setupchunk_construct_*` |
| The `!expr` in the front matter is evaluated three times per render (stack: `yaml::yaml.load(eval.expr=TRUE)` via `parse_yaml_front_matter` / `yaml_front_matter`), including once DURING knitting. So activation must be idempotent. | quarto html, rmarkdown html | `dbg/act.R`, `dbg/t.Rmd`, `dbg/tq.qmd` |

### B. A late metadata block
| Fact | Renderer / format | Shown by |
|---|---|---|
| A closing `---` block holding `abstract: \|` with a governed span and a value, after the chunks that define `n_sites` and `depth`: resolved ("LATEABS We sampled 3 sites, mean depth 12 m.") and appears in the abstract position under the "Abstract" heading | quarto html, docx, typst | `B_late/late_abstract_quarto_*` |
| Same | rmarkdown html_document, word_document | `B_late/late_abstract_rmarkdown_*` |
| Late block closed with `...` instead of `---`: same result | all 5 | `B_late/late_dots_*` |
| `title:` set only in a late block (no title at top): works, title block / `Title` style / `dc:title` carry the resolved text | all 5 | `B_late/late_title_*` |
| When a field is set in BOTH the front matter and the late block, the LATE value wins (abstract and title) | all 5 | `B_late/both_abstract_*`, `both_title_*` |
| Quarto emits no warning. Its `pandoc` metadata dump in the log lists the late block's abstract, in its raw unresolved form (`` `r depth`{.num} ``). | quarto html | `B_late/late_abstract_quarto_html.qmd` (log of re-run) |
| Quarto reads the late block as YAML BEFORE knitr: a late block that is invalid before resolution fails with `ERROR: Error reading metadata from <file>` (tested: plain scalar starting with a backtick; plain scalar starting with `[`). rmarkdown does not: both of those render fine | quarto html vs rmarkdown html | `B_hostile/*`, `B_hostile.log` |
| Book chapter (`ch2.qmd` with activation in its own front matter, late abstract at chapter end): renders and resolves, no warning. In the book HTML it appears as an Abstract block at the top of that chapter page. In the book DOCX it becomes the abstract of the WHOLE book, before chapter 1 | quarto book html + docx | `B_book/ch2.qmd`, `B_book/_book/ch2.html`, `B_book/_book/BookT.docx` |
| Body div as an abstract (`::: {.abstract}`, `::: {#abstract}`): NO supported route. It is an ordinary div and prints as a body paragraph, with no Abstract heading, in every format tested | quarto html/docx/typst, rmarkdown html/word | `B_div/div_*`, `B_book_div.log` |
| `::: {custom-style="Abstract"}` in docx applies Word's Abstract paragraph style to that paragraph only, at its place in the body: no "Abstract" title, not moved to the title block. Not a metadata route | quarto docx, rmarkdown word | `B_div/div_quarto_docx.qmd`, `div_rmarkdown_word_document.Rmd` |

### C. What the R session can read at knit time
Probe: `C/probe.R`, run from a chunk AND from a knitr `text` hook (installed in `.Rprofile`, fires on the first text block = front matter). Chunk and hook gave identical values in every case (`probe_chunk.rds` / `probe_hook.rds` in `C/cases/*/probe_out_*`). Summary: `Rscript C_summary.R`.

| Fact | Renderer / format | Shown by |
|---|---|---|
| Document-level custom key IS readable: `rmarkdown::metadata$weft` gives the full nested list (`digits` integer 2, `dict_local$sites$value` 4, `$why` "x"). Same accessor under both renderers, in a chunk and in a hook | quarto html; rmarkdown html | `C/cases/c1_doc/` |
| `rmarkdown::metadata` under Quarto holds only the document's own front matter (names: `format, weft, bibliography, lang`); it holds NOTHING from `_quarto.yml` or `_metadata.yml` (names were just `format`; book chapter just `title`) | quarto html | `C/cases/c2_project`, `c3_metadata`, `c4_book` |
| `bibliography:` in the document front matter: readable as `rmarkdown::metadata$bibliography` = "refs.bib" (as written, relative) | quarto, rmarkdown | `c1_doc` |
| `bibliography:` only in `_quarto.yml`, only in `_metadata.yml` (sub-directory of a project), or in a book's `_quarto.yml`: NOT in `rmarkdown::metadata` (NULL), under Quarto. Under rmarkdown, `_quarto.yml` / `_metadata.yml` are not applied at all | quarto; rmarkdown | `c2_project`, `c3_metadata`, `c4_book` |
| `lang:` behaves the same as `bibliography:`: in `rmarkdown::metadata$lang` only when in the document ("fr"); project / `_metadata.yml` / book `lang` are not there | quarto, rmarkdown | `c1_doc`, `c2_project`, `c3_metadata`, `c4_book` |
| What DOES expose the merged project metadata under Quarto, all verified to return `weft`, `lang` and `bibliography` for `_quarto.yml`, `_metadata.yml`, and the book (`de` / `it` / `es`): (a) `quarto::quarto_inspect(<the .qmd path>)$formats[[1]]$metadata` (about 0.4 s per call); (b) the JSON file named by env var `QUARTO_EXECUTE_INFO`: `jsonlite::read_json(...)$format$metadata`. Quarto sets the env vars `QUARTO_PROJECT_DIR`, `QUARTO_PROJECT_ROOT`, `QUARTO_DOCUMENT_PATH` (directory), `QUARTO_DOCUMENT_FILE` (e.g. `q.qmd`), `QUARTO_EXECUTE_INFO` | quarto html | `C/cases/c2..c6` |
| `knitr::current_input()` under Quarto is the intermediate `q.rmarkdown`, NOT the `.qmd`. Calling `quarto_inspect()` on it misses book-level metadata (a book chapter returned `lang=en`, no `weft`; the same call on the `.qmd` returned `es` and `weft`). Build the path from `QUARTO_DOCUMENT_PATH` + `QUARTO_DOCUMENT_FILE`. (A first run of the probe used the wrong path and showed this.) | quarto html | `C/probe.R`, `c4_book` |
| `quarto_inspect()` also works from an rmarkdown render (needs the quarto binary on PATH) and returns what QUARTO would apply (project `lang` "de", `bibliography`), which rmarkdown itself does NOT apply to the output: do not trust it as "what this render uses" under rmarkdown | rmarkdown html | `c2_project/probe_out_rmarkdown`, `c3_metadata/probe_out_rmarkdown` |
| `_metadata.yml` WITHOUT any `_quarto.yml` is still applied by Quarto (`lang` "it" reached `QUARTO_EXECUTE_INFO` and `quarto_inspect`). Quarto sets `QUARTO_PROJECT_DIR` to the document's own directory even with no project file | quarto html | `C/cases/c3b_metadata_noproject` |
| `QUARTO_*` variables are unset under rmarkdown. | rmarkdown | `c1_doc/probe_out_rmarkdown` |
| Precedence: doc `lang: fr` beats `_quarto.yml` `lang: de`; doc `weft: {digits: 9}` REPLACES the project `weft` (the project's `dict_local` is gone in the merged value: shallow merge of that key, not deep) | quarto html | `C/cases/c5_conflict` (`weft=digits=9` only; `exec_info` and `inspect` agree) |
| Project keys written under `format: html:` in `_quarto.yml` also arrive (`lang` "de", `bibliography`) via inspect and execute-info; not in `rmarkdown::metadata` | quarto html | `C/cases/c6_project_format` |
| Relative paths: Quarto rewrites bibliography paths from a project-level `_quarto.yml` so they are relative to the DOCUMENT's directory: root `refs.bib` seen from `sub/q.qmd` reads `../refs.bib`. A `_metadata.yml` path is relative to its own directory (`sub.bib` stays `sub.bib` for a doc in `sub/`). `_quarto.yml` and `_metadata.yml` bibliography lists are concatenated (`../refs.bib, sub.bib`) rather than replaced. A document-level path is left as written, relative to the document. `getwd()` in the chunk was the document directory in all cases | quarto html | `C/cases/c7_relpaths`, `c8_relpaths_root` |

Least fragile reading of project-level metadata under Quarto, from what I observed: `quarto::quarto_inspect(file.path(Sys.getenv("QUARTO_DOCUMENT_PATH"), Sys.getenv("QUARTO_DOCUMENT_FILE")))` (documented R API, merged result including `_metadata.yml`, book and profile-free project, paths already made document-relative; costs about 0.4 s and a `quarto` subprocess, so cache it per render). `QUARTO_EXECUTE_INFO` gives the same merged data without a subprocess but is an undocumented temp file I only know to exist during execution. Reading `_quarto.yml` directly (from `QUARTO_PROJECT_DIR`) would miss `_metadata.yml` (which Quarto applies even without a `_quarto.yml`), and I did not test it further. For the document's own keys, `rmarkdown::metadata$<key>` is simplest and works under both renderers. For lang/bibliography/weft at project level under rmarkdown there is no mechanism (rmarkdown does not apply them either).

## (ii) What I did not run
- Any LaTeX/PDF, revealjs, website, or blog format; Quarto website `description:` card behaviour; book typst/pdf.
- Typst PDF metadata (the `description` in the PDF info dictionary); only the visible text was checked.
- `subtitle:` / `description:` in the late block, a late block under rmarkdown book/bookdown, a late block in a typst book.
- A late block when activation is through `.Rprofile` or the setup chunk (activation was by front matter throughout B).
- Profiles (`_quarto-<profile>.yml`), `metadata-files:`, `--metadata` on the command line, and `execute-dir` set to project root (so `getwd()` may differ).
- Whether the cited `refs.bib` actually resolves citations (I only read the paths).
- Reading `_quarto.yml` directly with yaml (judged on reasoning above, not run).
- A Lua filter that moves a body div into the abstract metadata (not a built-in route; not tried).
- Isolating which of `"`, `'`, `: `, ` #` breaks which quoted/plain form after knitr (all four were present together).
- Windows.

## (iii) Surprising
1. The front-matter `!expr` is evaluated 3 times per render, one of them during knitting (`yaml_front_matter()` re-parses and re-evaluates it; the stand-in's own `clag_lang()` calls `rmarkdown::yaml_front_matter` and triggered it). With a non-idempotent `clag_install()` that resets the parked-inline list, rendering died with `Error in clag$pend[[nd$idx]] : subscript out of bounds` on every document with a construct in the title (first run: all 25 cells failed). Activation must be re-entrant and must not reset state. (`dbg/`)
2. knitr sees the RAW YAML text, before escapes are decoded: `\"` in a double-quoted scalar reaches the construct parser as a backslash and a quote; `''` in a single-quoted scalar reaches it doubled and fails SILENTLY (no error, construct left unresolved).
3. Plain scalars work although ` # sites` is a YAML comment, because the first parse is only used for `knitr:` keys; but a plain value that starts with `[` or a backtick breaks before knitr runs.
4. Block-scalar title / subtitle produce `<p>` inside `<h1>` / `<h3>`.
5. A late block wins over the same field in the front matter, but Quarto parses the late block as YAML pre-knitr (errors out on `Error reading metadata`), rmarkdown does not, and in a Quarto book DOCX a chapter's late abstract becomes the abstract of the whole book.
6. Project-level `lang`, `bibliography`, and any custom key are invisible in `rmarkdown::metadata` under Quarto; the doc-level value of a key replaces (not merges into) the project-level value of the same key.
7. `knitr::current_input()` is the `.rmarkdown` intermediate under Quarto, so tools that re-read the source (`quarto_inspect`, `yaml_front_matter`) must use `QUARTO_DOCUMENT_PATH`/`QUARTO_DOCUMENT_FILE` instead.
