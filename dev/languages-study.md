# weft and other languages: a design study

Date: 2026-11-13. Section 1 is the one-page summary; the rest is the evidence, about 25 minutes in
full. Facts are for Quarto 1.11.9 (Pandoc 3.10, Deno 2.9.8), knitr 1.51, rmarkdown 2.31,
reticulate 1.43.0 and Python 3.15.0, on this Mac. Nothing in the repository was changed.

How each fact is marked:

- **[V]** verified here (by running it, or by reading the code Quarto ships in `/Applications/quarto`).
- **[C]** cited from current documentation (URL given).
- **[M]** from memory, not checked.

What could not be tested here: the Jupyter engine (Python has no `jupyter` module, per `quarto check`),
Julia (not installed), JuliaCall (not installed). Statements about those rest on Quarto's shipped source
or on documentation, and say so.

---

## 1. Summary

### The ladder

| Rung | What the author gets | Needs R to render | Needs R for lints, gate, `verify()` | Reached by |
|---|---|---|---|---|
| 0 | Today. R only. A `.qmd` must say `engine: knitr`. Python chunks through reticulate happen to work, undocumented, with holes (section 4a). | yes | yes | exists |
| 1 | Documented and tested: Python and Julia chunks in an `.Rmd` or a knitr-engine `.qmd`, values reach prose as `py$x`. The holes are closed. | yes | yes | a |
| 2 | Guest languages are comfortable under knitr: `fmt_*()` and `plural()` callable from Python chunks, guest warnings in the condition log, guest inputs in the ledger's reads. | yes | yes | a, more of it |
| 3 | A document on the `jupyter` or `julia` engine renders weft constructs. Expressions are in the host language. R still formats. | yes | yes | b |
| 4 | The same, and no R runs at render. R is a project tool only, as Node is for a Python project that uses Prettier. | no | yes | c, f |
| 5 | Function forms in the host language (`fmt_num()`, `plural()`, `claim()` in Python or Julia code, same output as in prose), dictionary and units there too. | no | yes | c plus larger shims, or d |
| 6 | A Julia author never installs R. Lints, gate and `verify()` run without it. | no | no | d or e |

Observable JS is not on the ladder. It runs in the reader's browser after the render, so no
render-time check can see its values (section 6.9).

### The architectures

Effort is relative to what exists: 24,300 lines of R and 51,100 lines of tests [V, `wc -l`].

| | Architecture | Author writes (Python) | New code, roughly | Calendar | Top rung | R Markdown (`.Rmd`, no Quarto) |
|---|---|---|---|---|---|---|
| a | Stay R, be a good neighbour | `` `r py$depth`{.num} `` | 0.5k R, 1.5k tests | 1 to 2 weeks | 2 | Native to it. R is always the host there. Works today. |
| b | Host evaluates, R formats | `` `{python} v(depth)`{.num} `` | 0.6k per language shim, 0.8k Lua, 0.5k R, 4k tests | 4 to 6 weeks | 3 | Not needed: (a) already is this, with R as host. |
| c | Lua filter formats and resolves | same as b | 2.5k Lua, 0.6k per shim, 6k tests and a conformance table | 6 to 10 weeks, then 2 to 3 per language | 4 | Works: rmarkdown runs Lua filters. Would be a second route beside the hooks. |
| d | Neutral core plus bindings | same as b | 12k to 20k, in a new toolchain | 4 to 6 months | 6 | Bound through R as now, or through the filter. |
| e | Native ports | native syntax per language | 9k code and 20k tests per language | 3 to 5 months per language, then drift for ever | 6 | Unaffected. |
| f | Hybrid: a now; later c for other engines; R tooling kept as the project's checker | as a, then as c | sum of a and c | staged | 4 | Covered by the first stage. |

### Recommendation

Do (a) now. It is cheap, it is what R Markdown can do at all, and the test here found two real
defects in it: big Python integers print as wrong numbers with no error, and an empty Python list is
a "no value" even with `none=`. Then stop, unless there is an author who will not use the knitr engine.

If there is one, do (c) for the Jupyter engine with a small Python package, and keep the R package as
the project's checker (f). Do not do (b): it carries nearly all of (c)'s cost and still needs R at
render. Do not do (d) or (e) for a package that has no users yet.

The spike that removes most uncertainty (two days): on a machine with Jupyter, a 150-line Lua filter and
a 60-line Python module, rendering one page with a value, a `claim()`, an `if` span and an `n` span,
then the same page from `_freeze`, then with a failing claim. Section 7 lists what it must answer.

R Markdown does not change the order. It is rung 1 and 2 exactly, because under rmarkdown other
languages are guests of knitr and R is always there.

---

## 2. How Quarto and R Markdown run other languages

### 2.1 Quarto's engines

- **One engine per document.** "Currently there is one execution engine per Quarto document"
  [C, https://quarto.org/docs/extensions/engine.html].
- **Built in: `knitr`, `jupyter`, `julia`, and `markdown` (no execution).** Binding for a `.qmd`:
  an `{r}` block gives knitr; any other executable block gives Jupyter, with the kernel chosen from
  the first block's language; R and Python together give knitr, with Python run by reticulate; `engine:`
  or a `jupyter:` or `knitr:` key overrides [C, https://quarto.org/docs/computations/execution-options.html].
  `quarto inspect` on this machine gave: Python only → `jupyter`; R and Python → `knitr`; Julia only →
  `julia`; OJS only → `markdown` [V]. The Julia page still says Jupyter is the default for Julia code
  [C, https://quarto.org/docs/computations/julia.html]; 1.11.9 binds a `{julia}` block to the native
  engine, because the bundled `julia-engine` extension claims the language [V, its `claimsLanguage`].
- **Engine extensions exist since 1.9.** A third party can add an engine as a TypeScript module:
  "Markdown-in, Markdown-out", still one engine per document, and "the Quarto API is likely to change
  significantly over the next year or two" [C, https://quarto-dev.github.io/dev-notes/posts/2026-03-04;
  types read at `/Applications/quarto/share/extension-build/quarto-types.d.ts`, V]. marimo is the
  example given. The API offers Jupyter helpers (`quartoMdToJupyter`, `toMarkdown`) but no call that
  runs the built-in Jupyter engine, so an extension cannot simply wrap it [V, by reading the types].
- **TypeScript.** There is no TypeScript engine. Deno ships inside Quarto for Quarto's own use, for
  `quarto run` and for project scripts. TypeScript cells at render time need a separately installed
  Jupyter kernel (Deno has one, `deno jupyter --install`) [C, https://docs.deno.com/runtime/reference/cli/jupyter/;
  that Quarto then treats it as any kernel is M].
- **Observable JS** cells are compiled at render and run in the browser. Quarto turns an inline
  `` `{ojs} x` `` into the text `${x}` for the runtime; no value exists at render
  [V, `quarto.js` line 128413; C, https://quarto.org/docs/interactive/ojs/]. HTML formats only [M].

### 2.2 Inline code, engine by engine

This is the fact the options turn on.

- **knitr engine.** `` `r x` `` is knitr's own. Quarto rewrites `` `{r} x` `` to
  `` `r .QuartoInlineRender(x)` `` before knitr sees it [V, `resolveInlineExecute` in `quarto.js`].
  A `` `{python} x` `` in a knitr-engine document is **not** evaluated: it reached Pandoc as the code
  span `{python} depth` [V, rendered here]. knitr's inline pattern is R only [V,
  `knitr::all_patterns$md$inline.code`]. A Python value reaches prose as `` `r py$x` ``.
- **jupyter engine.** For each markdown cell, in document order, Quarto finds every
  `` `{python} expr` `` with a regular expression, sends the kernel one empty `execute` request with
  the expressions as `user_expressions`, and stores the replies in the cell's metadata. An error in
  any expression raises at once and stops the render [V, `cell_execute_inline` in
  `share/jupyter/notebook.py`]. Quarto then replaces each expression in the markdown text by its
  result: `text/markdown` as is, `text/plain` with quotes stripped and markdown escaped
  [V, `resolveUserExpressions` in `quarto.js`]. Three consequences:
  1. What follows the code span stays. `` `{python} depth`{.num} `` becomes the text `3.14159{.num}`.
     If the expression returns markdown `` `…` ``, it becomes a code span that carries `.num`.
  2. The replacement is textual, so it also happens inside an attribute value.
     `[rose | fell]{if="`{python} slope > 0`"}` reaches Pandoc as a span with `if="True"`
     [V for the pattern, run in Node on that string; V for the knitr engine, where
     `{if="`{r} slope > 0`"}` reached Pandoc as `if="FALSE"` with no weft loaded].
  3. Every expression in the cell is evaluated, whatever arm it sits in, and with Jupyter Cache on
     Quarto refuses: "Inline expressions cannot be used with Jupyter Cache" [V, same function].
  The kernel must implement `user_expressions`; one that does not fails
  [C, https://github.com/quarto-dev/quarto-cli/issues/10979]. The documentation advises that inline
  expressions be "simple values that you have pre-computed" because the protocol "is not compatible
  with some Python libraries" [C, https://quarto.org/docs/computations/inline-code.html].
- **julia engine.** Runs QuartoNotebookRunner.jl in a worker process per notebook, kept alive five
  minutes by default; R and Python cells are possible through RCall and PythonCall
  [C, https://quarto.org/docs/computations/julia.html]. It supports `` `{julia} x` `` [C, inline-code
  page]. How it evaluates and escapes inline code, and what an inline error does, I could not check.

### 2.3 After the engine

- **A Lua filter sees the same Pandoc tree whatever the engine was.** Engines hand Quarto markdown;
  Pandoc parses it; filters run on the tree. A span `[a | b]{if="True"}` is a `Span` with an `if`
  attribute and the inlines `a`, `|`, `b`. An escaped `\|` and a bare `|` are both `Str "|"`, which is
  what rule 1.5.12 already assumes [V, `format: native` renders here]. Filters have no source line
  numbers: Pandoc's `markdown` reader records none [M].
- **Freeze** applies to whole-project renders; a single-file render always executes. `_freeze` holds
  the engine's output, and Pandoc and the filters still run on it. Cache is per engine: knitr's chunk
  cache, Jupyter Cache, or the julia engine's own [C, https://quarto.org/docs/projects/code-execution.html].
- **The Jupyter kernel persists between renders**: `--execute-daemon` "defaults to 300 seconds", and
  `--execute-daemon-restart` restarts it [V, `quarto render --help`].
- **Project scripts.** `pre-render` and `post-render` may be TypeScript (Deno, bundled, nothing to
  install), Lua, Python or R (from the `PATH`), or a shell command
  [C, https://quarto.org/docs/projects/scripts.html]. weft's two are R [V, `inst/quarto/`].

### 2.4 R Markdown without Quarto

- **Engines.** knitr 1.51 here lists 52 [V, `names(knitr::knit_engines$get())`]: `python`, `julia`,
  `bash`, `sh`, `zsh`, `sql`, `mysql`, `psql`, `Rcpp`, `c`, `cc`, `fortran`, `stan`, `js`, `node`,
  `css`, `sass`, `scss`, `perl`, `ruby`, `go`, `haskell`, `octave`, `sas`, `stata`, `awk`, `sed`,
  `dot`, `tikz`, `asy`, `targets`, `exec`, `Rscript`, and display engines such as `asis`, `cat`,
  `verbatim`, `embed`. A project adds its own with `knitr::knit_engines$set()` [M].
- **State.** "Only R, Python, and Julia code chunks are executed in the same session"; the others run
  each chunk on its own [C, https://pkg.yihui.org/rmarkdown-cookbook/other-languages.html]. Python runs
  in one session embedded in R: "All objects created within Python chunks are available to R using
  the `py` object", and R objects are `r.x` in Python
  [C, https://rstudio.github.io/reticulate/articles/r_markdown.html]. Julia runs through JuliaCall,
  and its values reach R with `JuliaCall::julia_eval()` [M]. `sql` and `stan` hand a result to R
  through `output.var`; `Rcpp` defines R functions [M]. A `bash` chunk shares nothing but its output.
- **Inline code is R only**: `` `r … `` `` [V, the pattern above]. Another language's value reaches a
  sentence through R (`py$x`, `julia_eval("x")`) or not at all.
- **`py` needs `library(reticulate)`.** Without it a stock `knitr::knit()` stops with "object 'py' not
  found" [V].
- **rmarkdown runs Pandoc Lua filters**, through `pandoc_args`. weft already installs its check filter
  that way (`use_setup()`, rule 2.5.3) [V, `R/setup.R` `fm_add_filter()`]. So a Lua design is not
  Quarto-only.
- Under R Markdown R is always the host. "Evaluate in the host language" means R there, and
  architecture (a) is simply how it works.

---

## 3. What in weft is neutral and what is R

### 3.1 Where R and knitr are assumed (the true cost)

**The knit (prose core).**

| File | Function | The assumption |
|---|---|---|
| `R/hooks.R` | `weft_setup()`, `install_boundary_hooks()`, `install_hooks()` | knitr 1.51 hooks: `before.knit`, `after.knit`, `evaluate.inline`, `text`, `evaluate`, `document`. No other engine has a `text` hook. |
| | `park_inline()`, `eager_row()` | inline code is knitr's, parked and evaluated later |
| | `install_option_hook()` | `knitr::opts_hooks` on `label` |
| | `attach_functions()` | weft's functions go on R's search path |
| | `add_latex_minus()` | `knitr::knit_meta_add()` for LaTeX |
| | `document_lang()` | `rmarkdown::metadata`, `QUARTO_EXECUTE_INFO`, `quarto::quarto_inspect()` |
| | `finish_document()` | the end-of-document check and the one report |
| `R/resolve.R` | `resolve_markup()` (line 458), `stock_bare_text()` | `eval(parse(text = ))` in `knitr::knit_global()` |
| | `split_args()` | an `if` value is split with R's parser (`getParseData`) |
| | `stock_print()`, `finish_stock()` | `knit_print`, `knitr::sew`, the `inline` hook |
| `R/position.R` | `knit_input_path()`, block search, `protect_inline_patterns()` | `knitr::current_input()`, `knitr::all_patterns$md`, `knit_patterns$set()` |
| `R/captions.R` | `install_caption_hooks()`, `not_resolved_why()` | `eval.after`, `opts_hooks`; refuses a caption construct on a chunk whose engine is not R |
| `R/conditions.R` | `make_evaluate_hook()` | wraps knitr's `evaluate` hook, which R chunks use |
| `R/claim.R` | `claim()`, `written_checks()` | checks captured unevaluated, the `.` pronoun, `eval()`, `deparse()` |
| `R/weft-str.R` | `weft_str()` | knitr's inline pattern, R strings |
| `R/scan.R` | `handle_code()` | a value is `` `r ` `` or `` `{r} ` `` only; `` `{python} x`{.num} `` is not seen |
| | `expr_errors()`, `claim_without_check()` | every expression must `parse()` as R (rule 5.3.5) |
| `R/scan-contexts.R` | chunk and caption readers, `weft_str()` literals | `parse()` and `getParseData()` on R chunk code |
| `R/format.R` | `apply_formatters()`, `format_numbers()`, `apply_project()` | pure R, `as.numeric()` on the value, R Dates, named vectors for `.pairs`, project formatters are R functions |
| `R/units.R`, `unit-names.R`, `unit-defaults.R` | `u()`, `convert_unit()`, ladders | the `units` package over udunits (about 2,000 lines) |

**The harness.**

| File | Function | The assumption |
|---|---|---|
| `R/lint-code.R` | `literal-value`, `inert-check`, `value-constant`, `value-format`, `if-zero`, `tar-name`, `tar-cache`, `dict-assign`, `dict-key`, `above-setup` | read expressions and chunk code with R's parser; skip chunks whose engine is not R |
| `R/lint-doc.R` | `lint_engine()` | rule `engine`: a `.qmd` with constructs must say `engine: knitr` |
| `R/constructs.R` | `claim_calls()` | the gate counts `claim()` calls with `getParseData()`, in R chunks only; it has a regular-expression fallback for code that does not parse |
| `R/targets.R` | `note_chunk_code()`, `chapter_reads()`, the reads walker | walks every chunk's code as R to find target, dictionary and file reads; a guest chunk's code goes in too and is dropped when it does not parse |
| `R/targets.R`, `dict.R`, `dict-tools.R` | `tar_dict_deps()`, the `dict` object | `targets` and R objects |
| `R/ledger.R` | keys, sentences | expressions normalised by `parse()` and `deparse()`; sentences by ICU through `stringi` |
| `R/gate.R`, `gate-git.R`, `inst/hooks/commit-msg` | `gate()` | a shell hook that starts `Rscript` and needs weft installed there |
| `R/verify.R`, `verify-render.R` | `verify()` | an R process that runs `quarto render` or `rmarkdown::render()` and reads stamps |
| `R/setup.R`, `use-weft.R`, `use.R` | `use_setup()`, `use_quarto()` | write `engine: knitr`, an `.Rprofile` or front-matter route, and R project scripts |
| `inst/quarto/weft-pre-render.R` | | fails a `.qmd` with a construct and no `engine: knitr`; needs `Rscript` |
| `inst/quarto/weft-post-render.R` | | base R, needs `Rscript` |

### 3.2 What is neutral already

- **The syntax.** Spans, classes, keys, arms, `#`, ids, `cite`, `.weft-literal`: all Pandoc markdown.
  Only rule 1.1.2 ("code spans and attribute values hold R") names a language.
- **`weft-check.lua`** (357 lines): reads only the tree, writes to `.weft/failures.jsonl`, exits 1.
- **The files.** `_weft.yml`, `dict.yml` (with a JSON schema), `weft-units.yml`, stamps (JSON in
  `.weft/stamps/`), the collection file and the ledger (JSON lines). Any language can read and write
  them. The ledger's key holds an expression "parsed", which is R's normal form.
- **Most lints.** Of the 33 rules, 22 read prose or the document's structure and no code: `numeral`,
  `construct` (its structural part), `read`, `block-start`, `lone-bar`, `name`, `long-guard`, the three
  citation rules, `claim-word`, the five cross-reference and anchor rules, `section-anchor`,
  `chunk-label`, `file-link`, `config-place`, `figure`, `table-caption`. Ten read R: the list in
  3.1. One, `engine`, is the rule this study is about.
- **The gate's logic.** Counting findings and constructs against `HEAD`, the trailer. Language enters
  only through the scanner (what is a value) and `claim_calls()`.

### 3.3 What is R by nature

`targets` and `tar_dict_deps()`; the `dict` R object and `dict$key` reads; `knit_print` methods;
project formatters given as R functions; the phrase functions (`ci()`, `pm()`, `about()`, `of_n()`,
`lookup()`, `brk()`), which are called inside expressions and so belong to whichever language
evaluates; `weft_str()`; `rehearse()` and `arms()` as R functions. Other ecosystems have pipeline
tools (Snakemake, DVC, Pluto's reactivity); they are out of scope.

---

## 4. The architectures

### a. Stay R, be a good neighbour

**The document** (an `.Rmd`, or a `.qmd` with `engine: knitr`):

````
```{r}
#| include: false
library(reticulate)
weft::weft_setup()
```

```{python}
depth = 3.14159; slope = -0.4; n = 12; sites = ['a', 'b', 'c']
```

Mean depth was `r py$depth`{.num} m at [# site | # sites]{n="claim(py$n, . > 10)"}.
Abundance [rose | fell]{if="py$slope > 0"} at `r py$sites`{.and}.
````

**What works today** [V, knit here with the working tree loaded, `.Rmd` by `knitr::knit()` and `.qmd`
by `quarto render`]: `.num` with `digits`, `claim()` on a Python value (a failing one is collected and
reported with its line), `if`, `n`, `list` spans, `.and`, `.date` on a `datetime.date`, `.pairs` on a
dict through `unlist()`, pass-through classes, `None` and `nan` as "no value". A caption construct on
a Python chunk is already refused with a clear message (`not_resolved_why()`). From inside a Python
chunk, `r.fmt_num(depth)` returns "3.1" and `r.plural(3, "# site", "# sites")` returns "3 sites".

**What breaks** [V]:

1. **Big integers print wrong, silently.** `2**31` printed `NA`, `2**53 + 1` printed `1`, and
   `` `r py$b53`{.num} `` printed "1" with no failure. `2**70` printed `-1` and left a Python error
   that broke a later chunk. The three results are what truncation to 32 bits gives, on this pair of
   versions (reticulate 1.43.0, Python 3.15.0); with an older Python reticulate may convert to a
   double instead [M], which loses digits above 2^53 quietly. Either way
   a wrong number can reach the page, which is the failure weft exists to stop.
2. **An empty list is a "no value"** even with `none="none"`: `[]` arrives as R `list()`, not an
   atomic vector. `[1, 'a']` arrives as an R list and printed "1 and a".
3. **`decimal.Decimal`** arrives as a Python object reference, not a number.
4. **`py` is not found** unless `library(reticulate)` was called. This is stock behaviour.
5. **Text a Python chunk prints with `results='asis'`** is not resolved. `weft_str()` is the route in
   R; Python has none. The check filter does catch the leftover span.
6. **A Python warning is not in the condition log.** The log held the R warning and not the Python
   one, so the severity list of rule 7.4.2 cannot see guest warnings.
7. **A file a Python chunk reads is not in the ledger's reads**, so "not re-rendered" (7.2.2) cannot
   see it. By reading `chapter_reads()`, not run.
8. **Lints on a guest chunk's code do nothing**, by design (they skip non-R engines). `claim()` cannot
   be written in Python chunk code, so the gate has nothing to count there.

**Small changes that make it solid:** a guard where a value is taken from a reticulate object (refuse
a Python `int` outside ±2^53, or read it with `convert = FALSE` and its decimal string; treat an empty
list as a vector of length zero; convert `Decimal`; refuse a mixed list); attach `py` in
`weft_setup()` when reticulate is loaded, or say so in the "object 'py' not found" case; record guest
stderr warnings; a documented `py_str()` for `asis` text; a test matrix in CI with a real Python and,
if wanted, Julia. Julia through JuliaCall was not tested here; expect the same class of bridge
problems (`missing`, `nothing`, `BigInt`, `Rational`).

**For `.Rmd`:** this is the whole story. weft's existing `.Rmd` path already covers guest chunks to
the extent above, and the filter installed by `use_setup()` is unaffected by them.

**Cost and risk:** 1 to 2 weeks. Low risk. Nothing changes for R users or the spec, apart from a new
section on guest values. Everything stays R. The author must have R, write R expressions in prose
(`py$x`, `claim(py$n, . > 10)`), and use the knitr engine, which a Python user who wants Jupyter
tooling, widgets or `ipynb` sources will not accept.

### b. Evaluate in the host language, format in R

The construct carries a host expression, a small package in the kernel evaluates it and emits a typed
value, and R turns it into text. Because every engine substitutes inline code textually before Pandoc
(2.2), the host evaluation needs no new machinery:

````
---
filters: [weft]
---
```{python}
from weft import v, claim
depth = 3.14159; slope = -0.4; n = 12
```

Mean depth was `{python} v(depth)`{.num} m at [# site | # sites]{n="`{python} v(claim(n, '_ > 10'))`"}.
Abundance [rose | fell]{if="`{python} v(slope > 0)`"}.
````

`v()` returns markdown that is a code span holding the typed value in an attribute-safe encoding, so
`{.num}` attaches to it and the same token is legal inside `if="…"`. A Lua filter reads the tree,
chooses arms, and sends one batch of values and classes to an `Rscript` process that calls
`apply_formatters()`. (The alternative, R as a Pandoc JSON filter, means teaching `resolve.R` to
work on a tree instead of text: more work for the same result.)

**Verdict:** it reuses `format.R` and the units code unchanged, which is its only advantage. It needs
the shim, the carrier format, a Lua resolver for arms, spacing and back-references, and an R process
per render. That is most of (c), and the author still installs R to render. A Python author gains
little over (a) except the engine. I would not build it, except as a two-week bridge inside (c) while
the Lua formatter is being written.

For `.Rmd` it has no meaning: R is the host there.

### c. Formatting and resolution in the Lua filter

Same document as (b). The engine's only job is to emit typed values; a Lua filter, which runs under
every engine and under rmarkdown, does the rest. A throwaway filter of 83 lines, run here on a page
that imitates the Jupyter engine's output, did `.num` with half-away rounding on the decimal string
("0.15" → "0.2"), a 22-digit integer with thousands marks, `if`, `n`, a nested `n="."`, and collected
a failed claim to report at the end [V, Lua 5.4 in Quarto's Pandoc].

**What Lua can do well:** number printing (better than R's: it can round the decimal text exactly, and
print integers of any size); `.pct`, `.sci`, `.p`; `.word`, `.count`, `.ord`, `.no`; collapse classes
and the serial comma; arms, `#`, the space rule 1.5.20, chains, ids and back-references (the tree makes
nesting easy, and the hand scanner is not needed at render); `.a`, `.cap`; `cite`; English plural
rules, and CLDR rules for other languages as small tables; reading `_weft.yml` (Pandoc has a YAML
reader for metadata; a JSON copy written at setup is simpler); writing stamps, the collection file and
the ledger; exit 1 at the end with one report.

**What Lua cannot reasonably do:** unit conversion in general (no udunits; it can print a unit from
`weft-units.yml` and move between SI prefixes, which is powers of ten); dates beyond formatting an ISO
date with English month names (no time zones, no locale data); ICU sentence boundaries for the ledger's
`sentence` field (display only, so a simpler splitter or none); source line numbers (errors would name
the expression and quote the sentence; the R scanner can map that to a line when R is present);
project formatters written as R functions; anything that calls back into the kernel, which has gone
by then.

**What the spec gives up outside knitr:**
- Rule 1.5.16, "only the chosen arm is evaluated". Under Jupyter every inline expression runs. The
  rule becomes: a failed check in an arm that is not chosen is discarded (it rides in the arm, so it
  falls away with it); an error raised there still stops the render unless the shim catches it.
- Rule 1.1.2 becomes "code spans hold the document's language".
- An `if` on another engine is written `{if="`{python} …`"}`. It is longer and it looks odd. Removing
  the inner code span needs a hook in the kernel that knows the prose (IPython's `post_run_cell` event
  plus a scan of the source file [M]), which is a scanner per language, or a Quarto feature that does
  not exist.
- Captions and front matter: Quarto says inline expressions "are not generally supported inside YAML
  strings" [C, inline-code page]. Only figure and table divs remain (rule 1.10.5).
- `execute: cache: true` is not available with any inline expression under Jupyter (2.2).

**R Markdown and R users.** Two choices. Keep the hooks for R and add Lua for other engines: two
formatters, held together by a conformance table generated from the R one (a few thousand rows of
value, classes, keys → text). Or move R to the Lua route too, with the hooks shrinking to an emitter:
one formatter, but R still needs `fmt_*()` and `plural()` as functions for tables, plots and
`weft_str()`, so the R formatter cannot be deleted anyway. I would keep the hooks. The R path has
exact lines, arm-lazy evaluation and captions, and nothing is gained by taking them away.

**Cost and risk:** about 2,500 lines of Lua, 600 per language shim, and the conformance table: 6 to 10
weeks for Python, then 2 to 3 per further kernel language. Risks: Quarto's inline substitution is an
implementation detail read from source, not a documented contract; the julia engine's inline
behaviour is unverified; two implementations drift without the table.

### d. A neutral core with per-language bindings

A written specification of the construct semantics, one implementation of scanner, formatter,
resolver, lints and gate, and thin bindings for evaluation and `claim()`.

- **In Lua:** this is (c) with the lints added. Lua is the only runtime present in both Quarto and
  rmarkdown without installing anything. It is a poor language for a 10,000-line linter and a git hook.
- **In TypeScript on Deno:** ships inside Quarto, so project scripts, a gate (`quarto run gate.ts`)
  and an engine extension cost the author no install. Not present under rmarkdown. Cannot run inside
  the Pandoc filter stage, so the resolver would still be Lua or a JSON filter started through Quarto.
- **In Rust, as a binary and as WASM:** one fast binary for the gate and lints, bindings for R, Python
  and Julia so `fmt_num()` is the same everywhere. It also means per-platform builds, three package
  registries and a toolchain the owner does not use today.

It reaches rung 6. It is a rewrite of 24,000 lines whose spec is still moving and which has no users.
Not now. If rung 6 ever matters, the piece to move first is the static half (scanner, prose lints,
gate), because it is the half that forces R onto a project that does not otherwise have it.

### e. Full native ports

A Python weft on IPython hooks and a Julia weft on QuartoNotebookRunner, sharing the spec and a
conformance suite. Each could have native syntax, exact lines and lazy arms. Each is the prose core
again (scanner, resolver, formatter, `claim()`: about 9,000 lines and 20,000 of tests), then the
harness again. Three codebases for one maintainer. No.

### f. The hybrid I would build

1. (a), finished: rungs 1 and 2, for `.Rmd` and knitr-engine `.qmd`.
2. Only on demand, (c) for the Jupyter engine: a Python package `weft` with `v()` and `claim()`, and
   `weft.lua` for resolution and formatting. No R at render.
3. The R package stays the project's checker: `lints()`, `gate()`, `verify()`, `changes()` learn to
   read documents on other engines (section 5). A project with a Python manuscript installs R as a
   development tool.
4. Units and the dictionary stay R-side until someone needs them elsewhere.

What stays R-only for ever under (f): `targets`, `tar_dict_deps()`, project formatters as functions,
`knit_print`, `weft_str()`, `rehearse()`, lazy arms, exact source lines, caption and front-matter
constructs, the condition log, and the code lints at full strength.

### Julia and Observable under each

- **Julia.** (a): Julia chunks through JuliaCall, values by `` `r JuliaCall::julia_eval("x")` ``, wordy
  enough to want a helper `jl("x")`. (b), (c): `` `{julia} v(depth)`{.num} `` with a `Weft.jl` shim;
  `claim(n, >(10))` reads well in Julia. Works on the Jupyter engine with IJulia if IJulia answers
  `user_expressions` [M]; on the native engine it depends on behaviour I could not verify.
- **Observable and TypeScript.** OJS: nothing, under any architecture (6.9). TypeScript at render:
  a Jupyter kernel like any other, with a JS shim, if that kernel answers `user_expressions`.

---

## 5. Levels of support, and the enforcement half

The ladder is in the summary. What each rung needs from the harness:

- **Rungs 1 and 2 (a).** Nothing new. Expressions in prose are R (`py$x`), so every lint, the gate's
  counts and the ledger's keys work as they are. This is why (a) is cheap.
- **Rungs 3 and 4 (b, c).** Without changes the harness is wrong on such a document, not merely
  weaker: `handle_code()` does not see `` `{python} x`{.num} `` as a value, so the gate would not count
  it and removing it would cost nothing; `expr_errors()` would report "does not parse as R" on valid
  Python; `lint_engine()` and the pre-render script would fail the file outright.
  **A credible minimum for rung 4:**
  1. the scanner accepts `` `{lang} expr` `` for the document's language, and the nested form in
     attribute values;
  2. all 22 prose and structure rules run unchanged (they will, once 1 is done);
  3. expression rules fall back to a token-level reading that needs no parser: `literal-value` and
     `inert-check` become "the expression holds no identifier", `if-zero` a pattern. A real parser is
     optional, as Pandoc is optional today (`python -c "import ast"` when Python is there);
  4. the gate counts values, spans and `claim(` calls, the last by the regular expression
     `claim_calls()` already falls back to;
  5. `verify()` runs `quarto render` and reads stamps, which the Lua filter writes, with the run id
     from `WEFT_RUN`;
  6. the ledger is written by the Lua filter with the expression as written, not normalised.
  Skipped at this rung: `value-format`, `value-constant`, `tar-*`, `dict-*`, the condition log,
  reads and staleness beyond the source file's own hash.
  All of this runs in R. The author's project needs R and weft installed for the commit hook and CI,
  even though the document is Python. That is acceptable as a development dependency and should be
  said plainly in the README. A weft that formats numbers in a Python document and enforces nothing is
  not weft: the scoping document's own argument is that the prose core exists to make the harness
  bearable.
- **Rung 5.** Host-language `fmt_*()`: either each shim grows a formatter (a third and fourth copy,
  tied to the conformance table) or the shim calls the Lua or core implementation. Dictionary and
  units in the host language are a port of `dict.R` and the units files per language.
- **Rung 6.** The gate, lints and `verify()` without R: only (d) or (e).

---

## 6. The hard problems

**6.1 Static analysis in several languages.** Covered in section 5. The honest position: structure and
prose are fully checkable in any language; expressions are checkable at token level without a parser
and properly only with the host's own parser, called as an optional tool. The ledger key should stop
depending on a parsed normal form for non-R documents (white space collapsed is enough).

**6.2 Truthiness and missing values.** weft's rule is strict already: each `if` condition is a single
`TRUE` or `FALSE`, and `NA`, `NaN`, `Inf` and length zero are "no value" (1.3.4). Keep it strict and
put it in the carrier: the shim emits exactly one of bool, int, float, decimal, string, date, list, or
missing. Python `None`, `float('nan')`, `pandas.NA`, `numpy.nan`; Julia `nothing`, `missing`, `NaN`;
JS `null`, `undefined`, `NaN`: all "missing". No truthiness: a Python `[]`, `0` or `""` given to `if`
is a value error, not false. `numpy.bool_` is normalised to bool by the shim. The filter never parses
a language's printed form: the test in (a) shows what guessing costs, and numpy 2 prints a scalar as
`np.float64(3.14)` [M].

**6.3 Number types and exact printing.** `format_numbers()` calls `as.numeric()`, so R weft itself is
double-only, with a special case for `integer64` in the ledger. A carrier that sends integers and
decimals as digit strings and floats as their shortest round-trip text lets Lua print exactly. Rule
1.4.13 must then be restated: "rounds half away from zero on the number as written" is defined in R by
reading the double to 15 significant digits (`round_half_away()`), and on a decimal string it is exact.
The two differ only on doubles that need 16 or 17 digits. The conformance table has to pin those.

**6.4 Units.** pint, Unitful.jl and R's `units` disagree on names, symbols and what parses. A neutral
layer that converts between arbitrary units is a units library, and writing one is not realistic. A
realistic one: the carrier holds a magnitude and a unit named in weft's own vocabulary (the keys of
`weft-units.yml`); each shim maps its library's unit to that vocabulary and fails on one it does not
know; Lua prints symbol or name, and moves along an SI-prefix ladder. Conversion between different
units is done in the host before the value is emitted. Dictionary quantities (spec 4.4, the largest
section) stay R. I would leave units out of the first non-R rung entirely.

**6.5 Dates and time zones.** The carrier holds an ISO date. A datetime must be converted to a date in
the host, in a zone the author chose; the filter does not guess. `.date` prints English month names
from a table, as rule 1.6.8 already limits it to English.

**6.6 Evaluation order and state.** knitr: the `text` hook resolves each block between chunks, in
order, and only chosen arms. Jupyter: all inline expressions of a markdown cell in one request after
the cells above it [V]; order is right, laziness is lost, and `claim()` in an arm not chosen still
runs. The kernel may also survive from the previous render (2.3), so a name deleted from the source
can still exist and a claim can pass on stale state. `verify()` must pass
`--execute-daemon-restart` (or `daemon: false`), and the stamp should record that it did.

**6.7 Errors.** In the kernel there is no end-of-document hook, and an inline error stops the render at
once [V]. So `claim()` in inline position must not raise: it returns the value with the failed checks
attached, `v()` writes them into the carrier, and the Lua filter is the end of the document. It
collects every failure, leaves the marker, writes the stamp and exits 1 once, as `weft-check.lua`
does today. An expression that itself raises (a `KeyError`) stops the render with Quarto's message and
no weft report, unless the shim replaces IPython's `user_expressions` method to catch per expression
[M that this is patchable]. An unevaluated construct (rule 2.5.2) is a span whose key holds no
carrier: the filter fails on it, which is the existing backstop.

**6.8 Freeze and caching.** Under (c) a frozen document still passes through the filter, so
formatting, arm choice and the failure report are recomputed from the frozen carriers on every
render. That is better than today, where a frozen document runs no weft code at all. What is frozen
is the values and the outcome of each check. The stamp's meaning ("the checks ran in this run") is kept
by having the shim put the run id and time into a carrier at execution; the filter compares it with
`WEFT_RUN` and reports "served from freeze" as rule 2.9.3 needs. If the carriers pointed to a sidecar
file instead of holding the data, freeze would break, so the data must be in the token. Jupyter Cache
cannot be used at all (2.2). knitr's cache is unchanged.

**6.9 Observable JS.** OJS values are computed in the reader's browser, after every check weft has
could run, and can change as the reader moves a slider. Plainly: weft cannot format them at render,
cannot check them, cannot record them in the ledger, and a `claim()` on one is impossible. The options
are (1) a lint that lists an inline `${…}` or `` `{ojs} …` `` as a value weft cannot vouch for, the
way a typed numeral is listed; (2) values made at render in Python or R and passed with
`ojs_define()` are checked on the producing side, and that is all; (3) a JavaScript build of the
formatter for reactive text, which gives consistent printing and no integrity. I would do (1) and
write (2) down.

---

## 7. Recommendation

**First: (a), to rung 2.** One to two weeks. It serves every R Markdown user and every Quarto user
willing to say `engine: knitr`; it is the only thing R Markdown can do; it needs no spec change; and
the test here shows it is not safe as it stands. The big-integer case is a silent wrong number in a
package whose purpose is that there are none. Fix that even if nothing else in this study is done.

**Second, only when a real author needs the Jupyter or julia engine: (c) inside (f).** The Python
shim and the Lua resolver, with the R package as checker.

**Not: (b)** except as scaffolding. **Not: (d) or (e).** **Not: an engine extension.** The API is
young, declared unstable, and cannot wrap the Jupyter engine. **Not: OJS.** **Not: units or the
dictionary outside R** until asked for. **Not: a neutral units layer**, at any rung.

**The spike (two days), on a machine with Jupyter and ideally Julia:**

1. `weft.py`: `v()` emitting an attribute-safe token as `text/markdown`; `claim()` returning a checked
   value. `weft.lua`: `.num`, `if`, `n`, failures collected, a stamp written, exit 1.
2. Render a page with a value, a claim, `{if="`{python} …`"}` and a nested `n`. Does the token
   survive Quarto's substitution and Pandoc's attribute parser in both positions?
3. Fail a claim in a chosen arm and in one not chosen. Is there one report, and is the second
   discarded?
4. Raise an error in an inline expression. What does the author see?
5. Render the project twice with `freeze: auto`. Does the filter see the carriers the second time, and
   can it tell the run is frozen?
6. The same page with `engine: julia` and with IJulia. Does inline evaluation behave the same?
7. Open the file in the visual editor and save. Does `{if="`{python} …`"}` survive?

**What would change my mind:**

- Step 2, 5 or 7 failing. Then (c) needs a hook in the kernel or a Quarto change, its cost roughly
  doubles, and I would stay at (a).
- The julia engine not substituting inside attribute values. Then Julia is Jupyter-only or (a)-only.
- Quarto documenting a pre-engine markdown hook or letting engine extensions wrap built-in engines.
  Then the plain `{if="slope > 0"}` form is reachable for every language and (c) gets much better.
- Two or more real non-R authors. Then the conformance table and a TypeScript gate (Deno, nothing to
  install) start to pay, and (d) for the static half is worth pricing properly.
- No such author in a year. Then rung 2 was the right place to stop.

---

## Sources

- https://quarto.org/docs/computations/execution-options.html
- https://quarto.org/docs/computations/inline-code.html
- https://quarto.org/docs/computations/julia.html
- https://quarto.org/docs/extensions/engine.html
- https://quarto-dev.github.io/dev-notes/posts/2026-03-04
- https://quarto.org/docs/projects/scripts.html
- https://quarto.org/docs/projects/code-execution.html
- https://quarto.org/docs/interactive/ojs/
- https://github.com/quarto-dev/quarto-cli/issues/10979
- https://rstudio.github.io/reticulate/articles/r_markdown.html
- https://pkg.yihui.org/rmarkdown-cookbook/other-languages.html
- https://github.com/PumasAI/QuartoNotebookRunner.jl
- https://docs.deno.com/runtime/reference/cli/jupyter/
- Read locally: `/Applications/quarto/share/jupyter/notebook.py` (`cell_execute_inline`),
  `/Applications/quarto/bin/quarto.js` (`executeInlineCodeHandler`, `resolveUserExpressions`,
  `resolveInlineExecute`), `/Applications/quarto/share/extension-build/quarto-types.d.ts`,
  `/Applications/quarto/share/extension-subtrees/julia-engine/src/julia-engine.ts`.
- Experiments are in `/private/tmp/claude-501/-Users-rjs-dev-clag/329c9209-b43a-4fb0-b9e7-58be3c9db721/scratchpad/lang/`:
  `a/` (guest Python under knitr, with weft), `b/` (engine binding and a knitr-engine `.qmd`),
  `c/` (the throwaway Lua filter), `d/` (inline code inside an attribute value).
