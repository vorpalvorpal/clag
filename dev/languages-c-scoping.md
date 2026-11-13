# Architecture (c), scoped again: values by name

Date: 2026-11-13. Section 1 is the one-page summary. This deepens section 4c of
`dev/languages-study.md` ("the study"). Nothing in the repository was changed.

Marks: **[V]** verified here by running it or reading shipped source. **[C]** cited, with URL.
**[M]** from memory.

Run on: Quarto 1.11.9, Pandoc 3.10 (Lua 5.4), knitr 1.51, rmarkdown 2.31, and a real Jupyter
(Python 3.13.5, ipykernel 7.4.0, IPython 9.18.1, nbclient 0.11.0, jupyter-cache 1.0.1) in a
virtualenv inside the scratchpad. Not run: Julia, and the visual editor itself.

---

## 1. Summary

**The study's (c) works on the real Jupyter engine.** Its spike steps 1 to 5 pass [V]. But the
worst downsides it lists have one cause: the value travels through Quarto's inline code. Change
that one decision and most of them go.

**The reshaped design: values by name.** Code publishes typed values once. Prose refers to
names. The filter evaluates no host code.

````
```{python}
import weft; weft.auto()          # or: weft.put(depth=depth, rising=slope > 0)
depth = 3.14159; slope = -0.4; n = 12
```
Mean depth was `depth`{.num} m at [# site | # sites]{n="n"}. Abundance [rose | fell]{if="slope > 0"}.
````

All of this ran here on the Jupyter engine, the knitr engine, `rmarkdown::render()`, plain
Pandoc, and an `.ipynb` executed outside Quarto, with one Lua filter of 680 lines [V].

| Downside of (c) in the study | With values by name | Verified |
|---|---|---|
| Rests on undocumented substitution inside attribute values | Not used. Rests on "a cell can emit markdown", which is documented | V |
| The form `{if="`{python} …`"}` | `{if="rising"}` or `{if="slope > 0"}` | V |
| Lazy arms lost | Failures count only where a value is used. An arm not chosen is never read | V |
| No source lines | Exact lines, two ways | V |
| No captions or front matter | Title, subtitle and a `tbl-cap` cell option resolve | V |
| Jupyter Cache refused | Works | V |
| An inline error stops the render with a bare message | No inline code. A thunk carries an error to where it prints | V |
| A kernel survives between renders | The filter sees the stale run id | V |
| Two formatters drift | A literal Lua port of R's number printing matched R on 67,060 of 67,060 rows | V |
| Units, dates | Unchanged from the study: leave units out, ISO dates only | - |

**What it costs.** Prose holds names and simple comparisons, not expressions. `nrow(mod)` must be
bound to a name in code. That is Quarto's own advice for Jupyter [C], and what rule 1.2.3 already
tells R authors to do when an expression is awkward. R authors keep the hooks and lose nothing.

**Co-benefits for the R path that are real:** exact big integers for Python guests under (a)
(through reticulate `2**53 + 1` printed "1"; through the filter it printed
9,007,199,254,740,993) [V]; frozen documents re-formatted and re-reported from `_freeze` with no
stamp file [V]; captions and titles where the hooks refuse them; chapters that are plain markdown
fed by a values file, with no engine [V]; a conformance table that is also a regression net for
`format.R`. **Not real:** replacing the R scanner, a faster knit, one formatter for R.

**A defect found on the way.** R weft prints digits a double does not hold: `2^70` prints
"1,180,591,620,717,409,992,704" and 1977519933614.724 at `digits="6"` prints "…614.719971" [V].

**Recommendation.** I disagree with the study on the form of (c) and on its timing. Build (c) by
name, with inline carriers as optional sugar at most. Put the typed carrier and a conformance
table into (a) now (days). Build the filter and the Python shim when there is a reason; that is
now about 4 to 7 weeks instead of 6 to 10, and a further language is days, not weeks.

---

## 2. What was run

Everything is in `lang/c2/` under the scratchpad (paths at the end).

| # | Experiment | Result |
|---|---|---|
| E1 | Study spike, step 2: `v()` carriers on the real Jupyter engine, in the body, in `n=` and `if=`, nested | The token survives in every position [V] |
| E2 | Step 3: a failing `claim()` in the arm not chosen and in the chosen arm | First discarded, second reported once, exit 1 [V] |
| E3 | Step 4: `sum(x)/len(x)` in an arm not chosen | Render stops. The whole message is "ZeroDivisionError: division by zero": no file, line or expression [V]. `v(lambda: …)` cures it [V] |
| E4 | Step 5: project with `freeze: auto`, rendered twice | Second render does not execute. The filter reads the carriers from `_freeze`, reports the same failed claim, exits 1, and knows the values are 128 s old [V] |
| E5 | Jupyter Cache | Inline carriers: "Inline expression encountered (v(depth)). Inline expressions cannot be used with Jupyter Cache." By name: works, second render served from cache [V] |
| E6 | Step 7: Pandoc markdown to markdown, which is what a visual-editor save does [M] | Both forms come back intact, with `\|` and `\#` as rule 1.5.12 expects [V]. The editor itself was not run |
| E7 | Values by name on the Jupyter engine: `put()`, then `auto()` | Works. `auto()` published only the names the prose uses [V] |
| E8 | The same filter on the knitr engine with a 20-line R shim, then frozen, then `weft: digits: 3` changed with no re-execution | 3.1 became 3.142 from `_freeze` [V] |
| E9 | The same under `rmarkdown::render()` via `pandoc_args` | Works [V] |
| E10 | Plain Pandoc on a `.md` with a hand-written data block | Works, and a name used above its block fails [V] |
| E11 | A notebook executed by `jupyter nbconvert`, rendered by Quarto with no kernel | Works [V] |
| E12 | A Python guest under the knitr engine publishing `2**53 + 1` and `2**70` | Exact through the filter. reticulate gave "1" [V] |
| E13 | Title, subtitle and `#| tbl-cap:` holding named constructs, Jupyter engine, HTML | All resolved: "Table 1: Mean depth, 3.1 m, at 12 sites" [V] |
| E14 | Lines: text search in the source, and a second parse with `commonmark_x+sourcepos` inside the filter | Both give exact lines. The second parse took 6 to 12 ms and gives columns too [V] |
| E15 | Conformance: 67,060 rows of `weft:::print_one()` against Lua | Literal port: 0 differ. Exact-string algorithm: 742 differ, none at 12 or fewer significant digits [V] |
| E16 | Speed: 8,000 constructs in 70,000 words | Pandoc alone 2.1 to 2.6 s; with the filter 2.8 to 3.1 s. About 0.1 ms a construct [V] |
| E17 | A kernel kept by `--execute-daemon`, two renders with different `WEFT_RUN` | The data block of the second still said the first run's id [V] |

Two facts of the study are corrected. A Python variable does **not** survive between renders:
Quarto runs `%reset` in the kernel's setup and cleanup cells [V, `share/jupyter/lang/python/`,
and E17]. Environment variables and imported modules do survive. And identical inline
expressions in one markdown cell are evaluated once and share one result [V, E1].

Step 6 (Julia) was not run. I did not install Julia: the reshaped design needs only that a cell
can print markdown, so the julia engine's inline behaviour no longer decides anything.

---

## 3. The reshaped design

### 3.1 How values travel

A shim turns each value into a typed record and prints one fenced block into the cell's output:

````
````{.weft-values}
{"values":{"depth":{"t":"float","v":"3.14159"},"n":{"t":"int","v":"12","checks":[…]}},"run":…,"at":…}
````
````

The filter walks the document in order. A block adds its names. A construct sees the names
published above it, as a stock inline expression sees the chunks above it. The front matter is
resolved last, with everything [V].

Why a code block and not metadata: a YAML block emitted from a cell does reach `doc.meta`, but
Pandoc reads each string as markdown, so "a--b and \*c\*" arrives as an en dash and emphasis [V].
Why not `{{< meta >}}` or `{{< var >}}`: the shortcode page documents printing a value, not use
inside an attribute value [C, https://quarto.org/docs/authoring/shortcodes.html]. Why not a
sidecar file: freeze would not hold it (study 6.8). Why not `.content-hidden`: the filter
removes its own block, so nothing of Quarto's is needed.

One more route exists and I would not take it first: the kernel reads the source, evaluates every
attribute expression after each cell and publishes the results keyed by expression text. That
gives `{if="len(x) > 2"}` in the host language. It needs a prose scanner in each language that
agrees with Pandoc. `auto()` below is its cheap cousin: it scans for names only, and a miss
fails loudly.

What this route depends on is documented: `output: asis` "enables you to generate raw markdown
output", and Jupyter cells can use `IPython.display.Markdown`
[C, https://quarto.org/docs/computations/execution-options.html]. The inline-code page says
nothing about attribute values [C, https://quarto.org/docs/computations/inline-code.html].

### 3.2 Three ways to publish, all run here

| | Author writes | Cost per value | Notes |
|---|---|---|---|
| `put()` | `weft.put(depth=depth, rising=slope > 0)` | one argument | Explicit. Also takes a thunk and a `claim()` |
| `auto()` | `weft.auto()` once | none | After each cell, an IPython `post_run_cell` hook publishes each top-level variable the prose names, if it changed. It reads the names from the source file by pattern. A missed name fails loudly in the filter. An unnamed variable (a password, say) is not published [V] |
| no shim | `print()` of the block with `output: asis` | hand-written JSON | For a language with no shim yet, or a pipeline writing a file [V] |

`auto()` makes a named value cost what inline code costs, which is the scoping document's test for
the prose core. It needs the document's path. The kernel had `QUARTO_DOCUMENT_PATH` and
`QUARTO_DOCUMENT_FILE` in a fresh process [V]; a daemon kernel keeps the first render's
environment (E17), so the path should be passed or the daemon restarted.

### 3.3 What each rule becomes

| Topic | Inline carriers (the study's c) | Values by name |
|---|---|---|
| Laziness (1.5.16) | Every expression runs. A failed check in a dead arm is dropped [V] | Values are computed in code. A check, a missing value or a carried error counts only where the name is used; a dead arm is never read [V]. Side effects and time are not lazy |
| `claim()` | `v(claim(n, '_ > 10'))` in the span | Either at publish, `put(n=claim(n, "_ > 10"))`, with the outcome riding in the record, or in the sentence as a guard `[…]{if="n > 10"}` |
| Errors | Stop the render, bare message [V] | An error in a cell is an ordinary cell error, with Quarto's traceback. A thunk defers it |
| Jupyter Cache | Refused [V] | Works [V] |
| Freeze | Works [V]; `_freeze` holds base64 | Works [V]; `_freeze` holds readable JSON, so a diff shows a value change |
| Lines | The tree holds the carrier, not the source text. Order-matching broke as soon as the page held one stock inline expression [V] | The tree holds the text as written, so a search or a second parse gives the exact line [V] |
| Messages | "`(carrier)`{.num}" | "`n_gap`{.num}", "[rose \| fell]{if="rising"}" |
| Captions, title | Not possible: no inline code in YAML [C] | Work [V] |
| `.ipynb` edited in Jupyter | No: inline code needs Quarto to execute [C] | Works [V] |
| Static lints | Need the host's parser, or tokens | A name is checkable against the code by token: "named in prose, assigned nowhere". `literal-value` and `inert-check` cannot occur. No host parser |
| Ledger key | The expression as written | The name: stable, and already normal |
| Visual editor | Survives a Pandoc round trip [V] | Same [V], and nothing nested to damage |

### 3.4 A tiny expression language: where it pays and where it is a trap

I built the smallest one: a condition is a name, or `operand OP operand`, where an operand is a
name, a number or a single-quoted string, and OP is one of `< <= > >= == !=`. Conditions are joined
by the comma of rule 1.5.4. Numbers are compared exactly as decimal strings, so a 22-digit integer
compares correctly. About sixty lines of Lua [V].

**Worth it at exactly this size.** Three reasons. This grammar is the intersection of R, Python
and Julia, so the same text means the same thing in each, and under knitr the R hooks already
evaluate it. It keeps a check in the sentence it supports, which is the point of `claim()`: a
guard `[All sites exceed it]{if="min_depth > 0.5"}` needs no helper name. And the scanner can
validate it with one pattern.

**A trap one step further.** `and`, `or` and `not` are spelt differently in each language.
Arithmetic disagrees on `/`, `^`, `%` and integer overflow. Function calls have no end. Each
would be a third language in the document, with its own missing-value rules, and the lints would
have to parse it. The filter refused `len(sites) > 2` with a value error naming it [V]. The rule
to write: anything else is bound to a name in code.

### 3.5 What values by name gives up

- **Expressions in prose.** This is the real loss, and why R keeps its hooks. For Jupyter it is
  also Quarto's advice: inline expressions "should be confined to simple values that you have
  pre-computed within normal code cells" [C, inline-code page].
- **`knit_print`, phrase functions (`ci()`, `pm()`) and project formatters**, unless the host
  builds the string. Interval and pair types can be added to the record later.
- **A bare value with no attribute block.** `` `depth` `` is just code. A named value needs a
  class; `{.val}` would mean "print as is".
- **A new silent-looking trap, caught loudly.** A publishing cell with `include: false` emits
  nothing, on both engines. The filter then fails every name with "no value is published" [V].
  The message should mention `include`.

---

## 4. Each downside the study lists, and its remedy

| Downside | Remedy | Cost | Status |
|---|---|---|---|
| Undocumented substitution in attributes | Values by name; no inline code at all | The design of section 3 | V |
| | Or keep carriers and pin the behaviour with a test in CI against each Quarto release | A day; the risk stays | not done |
| Lazy arms | Use-site failure (section 3.3); thunks for values that may not exist | In the shim, 6 lines | V |
| Source lines | (1) search the source for the construct's text, in order, before arms are chosen: 40 lines, exact on the test page. (2) a second parse of the source with `commonmark_x+sourcepos` inside the filter: 6 to 12 ms, lines and columns. (3) the R scanner maps text to line afterwards | (2) needs the masking of rule 2.10.3 for a document where the two readers disagree, and the include map of 2.7.4 for included files | V for 1 and 2 on single files |
| Captions and front matter | Named constructs are plain markdown, so Quarto carries them to the tree. Resolve the body first, then the metadata | 8 lines | V |
| Jupyter Cache | By name it is ordinary cell output | none | V |
| Inline errors | No inline code; or a thunk | none | V |
| Surviving kernel | Less than feared: `%reset` clears Python names [V]. What survives is the environment and modules. The record carries the run id the kernel was started with; the filter compares it with `WEFT_RUN`. `verify()` passes `--execute-daemon-restart` | none | V |
| Two formatters | See 4.1 | | V in part |
| Units | As the study says: magnitude plus a unit key from `weft-units.yml`, conversion in the host. Not in the first stages | later | not run |
| Dates | ISO date in the record; `.date` from an English month table printed "3 March 2026" [V]. The shim refuses a datetime | 10 lines | V |

### 4.1 Two formatters

I tested how hard conformance is for the core, number printing (rule 1.4.13). R produced 67,060
rows from `print_one()`: random magnitudes from 1e-6 to 1e14, 1,500 ties, floating-point noise,
integers, with `digits` 0 to 6 and `sigfig` 1 to 5.

- **A literal port** of `round_half_away()` and `print_one()` to Lua, 65 lines, using the same
  IEEE doubles and the same C `printf`: **0 rows differ** [V]. It needed R's `signif()` ported
  too (its half-even step on a scaled double) [M for the algorithm, V for the result].
- **An exact algorithm on decimal strings** ("read to 15 significant digits, then round"):
  742 rows differ. 696 print more than 15 significant digits, where R prints binary noise. The
  rest are double-rounding cases at 13 or more digits. None at 12 or fewer.

So the rule is: a double goes through the literal port and agrees with R to the last character. An
integer or a decimal goes through the exact algorithm, where R has no equal today. The table then
pins both. Words, ordinals, lists and plurals are string work with no arithmetic; I expect them to
be tedious, not hard [M].

**Could R call the Lua formatter, so there is one?** `pandoc lua script.lua` runs Lua with no
document and starts in 0.03 s [V]. But `fmt_num()` is called in plain R, in tables and in
`targets` pipelines, where a process per call and a hard need for Pandoc are a poor trade.
Project formatters are R functions. Units need udunits before printing. R users would gain
nothing visible and lose speed and independence. Keep R as the reference, generate the table from
it, and run the Lua side under `pandoc lua` in CI. The filter can still run beside the hooks
under rmarkdown [V].

---

## 5. Co-benefits for the R path, honestly

| Claimed benefit | Real? | What the R path must change | What it loses |
|---|---|---|---|
| Exact rounding, big integers | **Real for guests, and it exposes a defect.** R values are doubles, so R gains nothing for its own numbers. A Python guest that publishes by name prints `2**70` exactly, bypassing reticulate [V]. And R today prints false digits past 15 [V] | Give `format.R` a digit-string path for integers and decimals; decide what 1.4.13 means past 15 digits | nothing |
| Frozen documents | **Partly.** No architecture re-runs a check without executing. But `_freeze` then carries its own evidence: values, check outcomes, run id, time. Today that lives in `.weft/stamps/`, which `.weft/.gitignore` keeps out of git (9.3.2), so a fresh clone with a committed `_freeze` has none. And formatting settings apply without re-execution [V] | Publish values by name for what should survive | nothing; the stamp stays for the hook path |
| The tree replacing the hand scanner | **Not real.** Lazy arms need R to choose the arm before it evaluates, so R must scan at knit time. The lints and the gate need the scanner anyway (2.10.2) | - | - |
| Format-aware output | **Marginal.** knitr already knows the format. A filter can add the LaTeX declarations of `add_latex_minus()` with no knitr | A few lines in the existing filter | nothing |
| Places the `text` hook cannot see | **Real.** `asis` output, tables and text built by code, a caption on a cached, `eval: false` or non-R chunk (refused today, 2.3.5), front matter. A named construct there resolves in the filter [V for title, caption, guest] | `weft_put()` in R, about 20 lines [V], and the resolver filter | lazy arms and expressions in those places only |
| `.ipynb`, plain `.md`, no engine | **Real and maybe the largest for a `targets` user.** A chapter with no chunks can be plain markdown plus a values file the pipeline writes. It renders with no R process [V with Pandoc] | A project-level values file the filter reads; `verify()` checks it against the store | everything the hooks do in that chapter: expressions, the condition log |
| Knit speed | **Not real for the hook path.** The filter costs 0.1 ms a construct [V], against a resolver the brief puts at 1.4 s a chapter (not measured here). But only named constructs take that route | - | - |
| One check filter | **Not real.** The hooks stay, so both stay | - | - |
| Visual editor | **Neutral.** Both forms round-trip through Pandoc [V] | - | - |

One friction to plan for: `weft-check.lua` today fails on "a code span carries the weft class"
[V, `check_code()`]. That is exactly the named-value syntax. It is the right error now, and it
means the syntax is free to take.

---

## 6. A staged path

Every stage is useful alone. The hooks are never removed.

| Stage | What is built | Size | Pays for itself with no non-R author? |
|---|---|---|---|
| 0, inside (a) | The typed record as a written rule and one R function; `format.R` prints digit-string integers and decimals; the reticulate guard converts through it | days | Yes. It is the fix for (a)'s silent wrong numbers |
| 1, inside (a) | The conformance table: R writes value, classes, keys and text for a fixed corpus; a test compares | 2 to 3 days | Yes. A regression net for `format.R`, and the definition of "what weft prints" outside R. 67,060 rows took seconds [V] |
| 2 | `weft.lua` resolves named values: number classes, `if`, `n`, markers, lines. `weft_put()` in R. Ships beside the hooks | 2 to 3 weeks | Partly: guests exact, constructs in `asis` text and refused captions, `_freeze` re-formatted, engine-free chapters. Build it when one of those is wanted |
| 3 | Python shim (`put`, `auto`, `claim`), about 150 lines; the scanner, lints and `engine` rule accept the named form; `use_quarto()` for Jupyter | 1 to 2 weeks | No. This is rung 4 for a Jupyter author |
| 4 | The other classes in Lua (words, lists, ranges, `.p`, `.sci`, `sign`, `list`, ids); stamp and ledger written by the filter; a Julia shim | 2 to 3 weeks | No |
| 5, optional | `v()` inline carriers as sugar; units by vocabulary; `fmt_*()` in the host language | open | No |

**Where (a) fits.** It is stages 0 and 1 plus its own work. **What to design in (a) now** so that
(c) is not made harder:

1. **The record.** Exactly one of bool, int (digits), float (shortest round-trip text), decimal,
   string, date, list of one type, missing (with why), error (with why); plus checks, run id,
   time. The guard for reticulate should produce this, not an R vector, so the empty list, the
   mixed list, `Decimal` and the big integer are decided once, in the rule the shims will copy.
2. **A pure formatter core.** `(record, classes, keys, config) → text and print record`, with no
   knitr and no locale. Project formatters stay outside it and outside the table.
3. **Rule 1.4.13 past 15 significant digits.** Refuse, or print zeros, but not noise. Decide
   before the table freezes it.
4. **Check text as written.** A failure message should quote the check's text, not R's `deparse()`,
   so a check that arrives in a record reads the same.
5. **The ledger key** should allow "as written" for a name (study 6.1).
6. **Reserve** the class `weft-values`, the named-value form, and `.val`.
7. **A stamp schema the filter can also write.** The spike wrote one [V].

---

## 7. Recommendation

**Where I differ from the study.**

1. **The form.** The study's (c) is inline carriers. They work [V], but they bring the Jupyter
   Cache refusal, bare errors, no captions, opaque messages, and a dependency on Quarto internals.
   Values by name have none of these, and need less from each language: the R shim was 20 lines.
2. **Three "losses" are not losses of (c).** Captions and front matter, Jupyter Cache and source
   lines are lost by inline code, not by the filter.
3. **The timing.** The study says wait for a non-R author. Stages 0 and 1 are worth doing now,
   inside (a), because they fix (a)'s own defects. Stage 2 has reasons that are not about Python.
4. **The spike is done**, so its uncertainty is gone except Julia and the editor.

**What I would do.** Build (a) with stages 0 and 1 in it. Then stop and look at stage 2 on its own
merits: does the owner want Python guests exact, constructs in generated text, or chapters with no
engine? If yes to any, build stage 2; stage 3 is then a fortnight whenever a Jupyter author
appears. If no, the path is still open and nothing is stranded.

**What the reshaped (c) costs in all.** About 2,000 to 2,500 lines of Lua (the spike is 680 for
perhaps a quarter of the classes), 150 to 250 per language shim, 500 of R for the scanner and
lints, and tests: 4 to 7 weeks to rung 4 for Python [M, an estimate], then days per language.

**What would change my mind.**

- *Against by name:* the owner finds binding a name for each computed value unacceptable in real
  writing. Then inline carriers, with their limits, or stay at (a). A week with `auto()` on a
  real chapter would tell.
- *Against starting stage 2:* the non-number classes turn out hard to make conform. A table for
  `.word`, `.and` and `n` in stage 1 would show it early.
- *Against the whole:* Quarto changing how cell output reaches Pandoc. Unlikely, since the cell
  divs are how every output works.
- *For going faster:* a real Jupyter or Julia author; or the owner wanting engine-free chapters.
- *For inline carriers after all:* Quarto documenting inline code in attributes, or giving
  filters the expression text.
- *Still open:* the julia engine (needs only `output: asis`, not run); the visual editor itself;
  `revealjs` and dashboards, where an emptied cell might leave a mark; `auto()` under a daemon
  kernel; lines in included files.

---

## Installed, and how to remove it

Nothing was installed outside the scratchpad. The virtualenv `lang/c2/venv` (204 MB) is inside
it, with `jupyter`, `ipykernel` and `jupyter-cache`; uv's download cache was kept in the scratchpad
and has been deleted. `uv venv` used a Python 3.13.5 that uv already had. No kernel spec was
registered, no kernel is left running, and no Julia was installed. To remove: delete `lang/c2/`.

## Files

All under `/private/tmp/claude-501/-Users-rjs-dev-clag/329c9209-b43a-4fb0-b9e7-58be3c9db721/scratchpad/lang/c2/`:

| Path | Holds |
|---|---|
| `weft-c2.lua`, `weftnum.lua` | the spike resolver and the number printing (both algorithms) |
| `weft.py`; `kproj/shim.R` | the Python shim (`v`, `claim`, `put`, `auto`); the R shim |
| `spike/` | E1 to E3, E5: `inline.qmd`, `err.qmd`, `err2.qmd` |
| `proj/` | E4: frozen Jupyter project |
| `jnames/`, `auto/`, `caps/`, `daemon/` | E5, E7, E11, E13, E17 |
| `kproj/`, `rmd/`, `guest/` | E8, E9, E12 |
| `names/plain.md`, `pos/`, `rt/` | E10, E14, E6 |
| `conf/` | E15: `gen.R`, `table.tsv`, `cmp3.lua` |
| `speed/` | E16 |

## Sources

- https://quarto.org/docs/computations/inline-code.html
- https://quarto.org/docs/computations/execution-options.html
- https://quarto.org/docs/authoring/shortcodes.html
- https://quarto.org/docs/authoring/conditional.html
- https://quarto.org/docs/extensions/filters.html
- https://quarto.org/docs/computations/julia.html
- Read locally: `/Applications/quarto/share/jupyter/notebook.py`,
  `/Applications/quarto/share/jupyter/lang/python/setup.py` and `cleanup.py`,
  `/Applications/quarto/bin/quarto.js` (`QUARTO_DOCUMENT_PATH`, the Jupyter Cache refusal),
  `/Applications/quarto/share/extension-subtrees/julia-engine/src/julia-engine.ts` (no inline
  handling in it; that is done in Julia, not checked).
