# `clag` — package scoping

**Date:** 2026-08-26
**Grammar revised:** 2026-11-10 (§0 rewritten: governed spans, the chain, no
MAP position, no inference)
**Status:** scoping. Grammar and runtime architecture are at spec level; contested
points are collected in §14. Integration facts below were verified against
knitr 1.51, rmarkdown 2.31, Quarto 1.9 and Vale 3.18.

`clag` is the successor to `gluey`: a markdown templating engine (glue-style
substitutions compiled into knitr inline expressions) extended with deterministic
checks for computational manuscripts. `clag` has no users and no
backwards-compatibility obligations; everything here is a clean design. Portable
by design: the package knows about Quarto, knitr, `targets` and git, and nothing
about any particular book.

The package is two things, and the coupling between them is the design's central
argument. The **templating core** (parser, substitution grammar, formatters)
makes computed values nearly free to write in prose. The **integrity harness**
(claims, dictionary, lints, commit gate, ledger) is only socially sustainable
*because* of that: a tier-1 rule like "every numeral is a computed substitution"
survives contact with authors only when a substitution costs no more keystrokes
than the numeral it replaces, and a checked substitution costs one comma more.
They ship as one package with two strict internal layers — core and harness —
so a split later is mechanical.

`glue` remains the rendering backend for templates (`glue_vec()`'s `.item` /
`.vec` machinery, interpolation inside compiled calls). The outer grammar is
parsed by clag itself: glue assigns `{{` its own meaning (an escaped literal
brace), and its parser has no place to carry governed brackets or the chain.

Companion document: `~/projects/10.02 Healthy Waterways/MANUSCRIPT-INTEGRITY-PLAN.md`
covers applying this to the Healthy Waterways manuscript — the dictionary's
contents, the audit corpus, and the migration order.

---

## 0. The substitution grammar

Two constructs, in documents and inside `clag()` templates in R code alike:

```
{{OBJ, ARGS}.CHAIN}                  a value
[PROSE]{{GOVERNOR, ARGS}.CHAIN}      words governed by a value
```

One rule divides them: **braces hold R; brackets hold prose.** A value
substitution shows the result of an R expression. A governed span shows
ordinary prose whose wording, or whose right to be there at all, depends on an
R value. Prose never sits inside an R string, so it stays visible to the lints,
to spellcheck and to the reader of the source.

Every construct opens with `{{` or closes a bracket with `]{{`. Single braces
are literal, so Pandoc attribute syntax (`{#sec-foo .class}`) and raw LaTeX
(`\emph{a \textbf{b}}`) pass through untouched. Quarto's own double-brace
constructs do not collide: shortcodes require `{{<`, and verbatim cells
(` ```{{r}} `) apply only to fence info strings, never prose (confirmed against
the Pandoc manual and Quarto docs: plain `{{foo}}` in prose has no assigned
meaning and survives to output untouched). `[text]{{…}}` is equally free:
Pandoc 3.8.3 reads it as plain text, nested brackets, checks and chain
included, because `{{…}}` is not valid attribute syntax. The one exception is
a bracket whose text matches a defined reference-link label (`[foo]: url`),
which Pandoc reads as a link; clag's parser runs first and treats `]{{` as a
governed span regardless. A bare `quarto render` (1.11.9) likewise passes
every form through as literal text.

### Inside the braces: an R argument list

The content of `{{…}}` is parsed by R itself, as the argument list of a call:
the compiler wraps it as `f(<content>)` and hands it to
`parse(keep.source = TRUE)`. Nothing inside the braces is clag-specific
syntax.

- **Commas, strings, backticks and nested calls** are split by R's parser, not
  by a hand-written tokeniser. `{{c(1, 2, 3)}}` is one argument.
- **The closing brace is the first `}` at which the content parses** and which
  is followed by an optional chain and a `}`. Braces inside the expression are
  therefore allowed: `{{if (x) {a} else {b}}}`, as is a `}}` inside a string.
  Tried in R 4.x on some twenty cases; two guards are needed beyond "it
  parses". The result must be a single call to the wrapper (or `x)) + g(y`
  closes the wrapper early and parses), and an empty argument (`{{x, }}`,
  which R accepts) is rejected.
- **`getParseData()` gives token positions**, so the L2 `NUM_CONST` check (§5)
  and error messages point at exact columns.

The arguments are read by position and name:

| Argument | Meaning |
|---|---|
| first, unnamed | OBJ (or GOVERNOR): the value |
| first, named without a dot | **reserved**: a compile-time error. Held for a possible binding form (`{{n = nrow(mod)}}`), deferred because a chunk assignment already does the job |
| later, unnamed | a **check** on the value, with `.` as its pronoun |
| named with a leading dot | passed to the rendering engine (`.sep`, `.last`, `.width`, …) |

**Unnamed args are validation checks.** `{{n_gap, . > 10}}` compiles to
`claim(n_gap, . > 10)` — checks in the grammar *are* claims, one
implementation, one loosening-report target (§4). `cite(key)` is the check
that the value comes from a listed reference: `{{10, cite(smith2020)}}`. At a
minimum it checks that the key exists in the bibliography.

Dot-named args should be rare. Formatting is generally handled by a
document-wide default set in YAML or by a chain name (below).

An empty `{{}}` is a compile-time error. There is no inference of a missing
value from elsewhere in the sentence; see "Scope" below for what replaces it.

### The chain

After the closing inner brace comes an optional chain of dot-names:
`{{x}.num}`, `{{sites}.ul}`, `{{n}.no.word}`, `{{p}.pct.strong}`. Each name is
a legal R name starting with `.`, and each resolves, statically, to one of two
kinds. An unknown name is a compile-time error.

- **Formatters** change how the value prints. They apply left to right.
  - numbers: `.num`, `.pct`, `.sci`, unit-aware printing from the dictionary
  - `.word` spells a numeral ("three"); `.ord` gives an ordinal ("3rd")
  - `.no` prints zero as "no" (cli's `no()`)
  - markdown structures: `.ul` (bullet list), `.ol` (ordered list), `.dl`
    (definition list), `.yaml` (YAML block), `.todo` (task list), `.or`
    (collapse with a final "or")
- **Styles** wrap the finished output in a Pandoc span (`[text]{.style}`) that
  the project styles per format via CSS or LaTeX. `.em`, `.strong` and `.code`
  ship.

A project can define a chain name in YAML that bundles formatter options
(significant figures, units) with or without a span class. A project name may
not shadow a shipped one; that is a compile-time error.

The structural formatters (`.ul`, `.ol`, `.dl`, `.yaml`, `.todo`) are named
after the HTML tags where one exists. On a governed span they are a
compile-time error: an arm is a phrase, not a list.

With no formatter, vectors collapse `cli`-style ("a, b, and c"), data frames
render as pandoc tables, and ggplot objects render as saved figures.

Formatters are implemented over `glue_vec()`, which is the exported engine for
anything the grammar doesn't cover.

The chain replaces two things in the predecessor: leading formatter tokens
(`{{- x}}`, which whitespace alone told apart from unary minus) and the
separate trailing STYLE slot.

### Governed spans

```
[PROSE]{{GOVERNOR, ARGS}.CHAIN}
```

The bracket holds one or more **arms** separated by `/`. The governor's value
chooses the arm. The bracket and the braces must be adjacent: a space between
`]` and `{{` breaks the binding and leaves both as they are.

**The governor is a count or a logical.**

| Governor | Arms | Chosen when |
|---|---|---|
| count | `[a]` | always (a template, see "Scope") |
| | `[a/b]` | n == 1 / otherwise |
| | `[a/b/c]` | n == 0 / n == 1 / n >= 2 |
| | `[a/b/c/d]` | 0 / 1 / 2 / 3+, extending leftward one exact count at a time |
| logical | `[a/b]` | TRUE / FALSE |
| | `[a]` | TRUE; FALSE is a claim failure |

A single-arm span with a FALSE governor stops the render: the phrase is a
claim, and the claim failed. To drop the phrase silently instead, give it an
empty false arm: `[add more sampling sites/]{{n_gap > 10}}`.

A logical governor with three or more arms is an error. So is a governor that
is `NA`, or that is neither a count nor a logical.

How a governor becomes a count:

- a single number is the count
- a single logical is a logical, not a count
- anything else (a vector, a list, a data frame's rows via `nrow()`) counts as
  its length

A numeric vector that happens to have one element is read as that number, not
as "one thing". Where that can happen, write `length(x)`.

The count ladder is cli's, with one difference at the bottom. cli's single-arm
`{?s}` means "plural only"; here a single arm is a template, so the suffix
form is written with its empty first arm: `file[/s]{{n}}`.

**Examples:**

```
[a person/# people]{{n}} responded.
[no people/a person/# people]{{n}} responded.
Invertebrate numbers [rose/fell]{{slope > 0}}.
[All]{{all(mod$rising)}} {{nrow(mod)}} models rise.
Council will need to [add more sampling sites]{{n_gap > 10}}.
```

**`#` stands for the governor's value**, printed exactly as
`{{GOVERNOR}.CHAIN}` would print it (taken from ICU MessageFormat). The number
and its noun become one unit: `[# site/# sites]{{n}}`. With a vector governor,
`#` is the collapsed vector: `[# was/# were]{{sites}}` gives "Blaxland and
Katoomba were".

**Selection sees the value as it prints.** Formatters run before the arm is
chosen. A depth of 1.2 printed to zero decimals shows "1" and takes the
singular arm; a value printed as "1.0" takes the plural, as English does.
`.no` composes with this: `[# file/# files]{{n}.no}` gives "no files",
"1 file", "12 files".

The mechanics: a formatter returns two things, the **text** and the **number
as printed** (with a flag for whether decimals are shown). The result is
computed once and read twice. Its number picks the arm; its text fills `#`.
For `[# metre/# metres]{{depth, . > 0.5}.num}` with `depth` 1.2 and `.num` at
zero decimals:

1. `depth` evaluates to 1.2
2. the check `. > 0.5` runs on 1.2
3. `.num` returns the text "1" and the printed number 1, no decimals
4. the printed number is 1 with no decimals, so the first arm is chosen
5. `#` is replaced by the text "1", giving "1 metre"

The singular arm is chosen only when the printed number is 1 and no decimals
are shown; the zero arm only when it is 0. In a chain, each formatter receives
the previous result. One that rounds (`.num`, `.pct`) sets the number; one that
only rewords (`.word`, `.no`) passes the number through and changes the text.
A vector governor's count is its length, which no formatter changes.

**The bracket is prose.** It can contain markdown and nested substitutions:

```
[All {{nrow(mod)}} models rise]{{all(mod$rising)}}
```

Every lint that applies to prose applies inside the bracket. In particular a
numeral inside a governed span must itself be a substitution (L2, §5).

**Checks work as in a value substitution.** Later unnamed args are claims on
the governor: `[a person/# people]{{n, . < 500}}`. A single-arm span with a
logical governor is itself the claim, and it is the idiom for guarding a
phrase whose truth depends on a value the sentence never displays (§4).

**Only the chosen arm is evaluated**, so a nested substitution in an arm that
is not chosen neither renders nor runs its checks.

**Escapes and carve-outs:**

- `\/`, `\#`, `\[` and `\]` are the literal characters inside a governed
  bracket
- a bracket that opens with `@` or `^` (a citation or a footnote) is never a
  governed span
- arms are `str_trim`med, so alternations can be spaced for readability

### Scope: nested brackets inherit the governor

A bare bracket inside a governed span, with no `{{…}}` of its own, takes the
governor of the span that encloses it:

```
[# sample[/s] [was/were] taken]{{n}}
```

renders "1 sample was taken" or "12 samples were taken". The outer bracket has
one arm, so it is a template; its job is to mark how far the governor reaches.

The rules for a bracket inside a governed span:

- followed by `{{…}}`: it has its own governor
- followed by `(…)`: it is a markdown link
- neither, and containing an unescaped `/`: it inherits the enclosing governor
- otherwise: literal text

Outside a governed span, a bare bracket has no clag meaning.

This replaces the predecessor's sentence-scoped inference, in which a
substitution with no OBJ searched the sentence for one. Lexical scope is
resolved statically without a sentence segmenter, it cannot bind silently to
the wrong value, and the binding moves with the text when an edit moves the
span. Agreement at a distance is written by widening the bracket or by naming
the governor again: `[was/were]{{n}}`.

### Lookups and range phrases are plain R

The predecessor's MAP position is gone. A phrase chosen by key or by range is
an ordinary function call inside the braces.

**Range-to-phrase.** The shipped constructor is `brk()`, whose flat form reads
left to right:

```r
trend <- brk("a fall in", 1, "steady", 1, "a rise in")
```

```
There was {{trend(foo)}} invertebrate numbers.
```

Labels alternate with break values; each label covers `[lo, hi)`, and a break
repeated twice makes the label between the repeats match exactly that value
(so the example reads: `< 1`, `== 1`, `> 1`). For anything the flat form can't
say, `brk()` also takes formulas (`brk(. < 1 ~ "a fall in", . == 1 ~ "steady",
. > 1 ~ "a rise in")`).

**Keyed lookup.** `lookup()` builds the same kind of function from a named
vector:

```r
tier_lab <- lookup(mod = "Moderate", sev = "Severe")
```

`"The site is rated {{tier_lab(tier)}}"` renders `"The site is rated Severe"`.
A lookup takes a string or a factor (by its label, never its integer code) and
errors on a key it does not hold. Plain `tier_levels[[tier]]` is legal R but
indexes a factor by its code, silently; `lookup()` exists to close that hole.

Both are vectorised, so a vector of keys feeds a list formatter:
`{{tier_lab(tiers)}.ul}`. A dictionary entry of `type: labels` (§4) is returned
as a lookup, so `{{dict$tier_lab(tier)}}` works directly.

A named `brk()` or `lookup()` is a **stipulation**: someone chose where
"steady" ends and "a rise" begins. That makes it dictionary material (§4) —
defined once, decision-logged, and reused by every report that renders the
phrase — which is exactly where a recurring report's phrase thresholds belong.

**Guarding the value behind a phrase.** Checks in `{{trend(foo), …}}` see the
phrase, not `foo`. Because `claim()` returns its first argument (§4), the
value is guarded in place: `{{trend(claim(foo, . > 0))}}`.

### Order of operations

```
OBJ or GOVERNOR  >  CHECKS  >  FORMATTERS  >  ARM and #  >  STYLES
```

Checks guard the **value** as evaluated, before any formatter touches it.
Formatters then fix how it prints. For a governed span the arm is chosen from
the printed value and `#` is filled in. Styles wrap whatever comes out: the
formatted value, or the chosen arm.

---

## 1. Runtime architecture

The design here is dictated by what knitr and Quarto actually expose, all of it
verified against source or maintainer statements (2026-08).

### What is not available

- **`knit:` in the YAML header is an RStudio-button convention.**
  `rmarkdown::render()` (2.31) never reads the `knit` front-matter key — the
  whole namespace greps clean — and Quarto's knitr engine is literally a call to
  `rmarkdown::render()`, so it ignores it too. The predecessor's
  `knit: gluey::knit` runtime silently did nothing on CI, under agents, and
  under Quarto. Nothing may depend on that field.
- **Quarto has no document-level pre-engine hook.** Lua filters and shortcodes
  run on the Pandoc AST *after* knitr has executed (maintainer-confirmed,
  quarto-cli discussion #7357); project pre-render scripts are project-only
  (issue #13032, open) and cannot redirect a single input to a transformed
  copy; `{{< var >}}` / `{{< meta >}}` are static. A pre-render script *can*
  write the project's inputs before Quarto reads them, which is what the
  project route below uses.
- **knitr's custom patterns cannot host the grammar.** A package can register a
  custom `inline.code` pattern before `knit()` starts, and knitr will evaluate
  matches per-expression in document order — but the matched text must parse as
  valid R (`parse_inline` → `parse_only`, no transform hook in between), and
  capture groups can only reproduce substrings of the source. `{{foo,
  . > 10}}` is not R and never reaches evaluation. The route would also hang
  document correctness off `.Rprofile` state under Quarto (plausible but
  unverified). Rejected.

### What clag does instead

**clag owns the compile step, and never mutates the author's source.** There
are two routes.

*A single file.* `clag_render()` parses the source, compiles each
substitution, writes the compiled document to a **temp copy**, and invokes
`rmarkdown::render()` or `quarto render` on the copy. This is the pattern
Quarto itself uses internally (its `execute.R` writes preprocessed markdown to
a temp `.rmarkdown` file and renders that).

*A Quarto project (book or website).* Authored sources live in `_src/`, which
Quarto ignores because of the underscore. A project `pre-render` script,
installed by `use_clag()`, calls the compiler, which writes each compiled
`.qmd` to its place in the project, where Quarto renders it. Compiled files are
gitignored, carry a "generated, do not edit" header, and are rewritten only
when their content changes. `clag_render()` on a project compiles and then
calls `quarto render`.

Tried with a two-chapter book and a stand-in compiler, on macOS (Quarto
1.11.9, R 4.4.3) and on Windows 11 (Quarto 1.9.38, R 4.5.1), with the same
results on both:

- compiled inputs render in the same run, and `_src/` is not rendered
- `freeze: auto` holds: an unchanged source is not re-executed, an edited one is
- `quarto render ch1.qmd` inside the project runs the pre-render step too
- relative data paths resolve, because a compiled file sits where a source
  would have
- knitr hooks set by an injected setup chunk capture warnings and messages
  (see "Condition capture" below)
- sources with CRLF line endings compile and render
- a pre-render entry naming an `.R` file is run by Quarto itself, so the
  compile step needs no shell and no `Rscript` on `PATH`

Two limits, both loud:

- **A clean clone needs one compile first.** Quarto checks that every book
  chapter exists *before* it runs pre-render, so a bare `quarto render` on a
  clone with no compiled files stops with "Book chapter 'index.qmd' not
  found". `clag_render()` compiles first and does not hit this.
- **`quarto preview` does not watch `_src/`.** It runs pre-render once at
  start. Recompiling while it runs does make it re-render, so `clag_preview()`
  is `quarto preview` plus a watcher on `_src/` that recompiles on save.

**Error positions map back to `_src/` by a fixed offset; there is no map
file.** An error raised while Quarto renders a compiled file names a line in
that file. Three rules make the mapping trivial:

- the compiler preserves line counts: a substitution spanning several lines
  compiles to an inline expression spanning the same number (knitr accepts
  this), and caption sugar rewrites within one line
- the injected setup chunk has a fixed length, so a source line is the
  compiled line minus that length. Observed: knitr reports `Quitting from
  ch1.qmd:12-16 [boom]` for a chunk at source lines 5-9 under a 7-line header
- `clag_render()` rewrites `file:line` in error text to the `_src/` path
- the "generated, do not edit" header of each compiled file states the
  offset and the source path, for anyone reading an error from a bare
  `quarto render`
- compiled files are written read-only, so an editor that jumps to an error
  cannot save a change to the wrong file

Most errors need less than this. A knitr error names the chunk label, which
L8 makes mandatory, and clag's own failures carry the source position embedded
at compile time.

**The editor's Render button gets a replacement.** The button renders the
file being edited, and a file under `_src/` rendered directly runs with
`_src/` as its working directory: relative data paths fail, and without them
the output shows literal braces. Loud either way, but the author's most
natural action does not work. clag ships an RStudio addin and a Positron task
that call `clag_render()` on the current file, installed by `use_clag()`.
(The button's behaviour was not clicked in a GUI; it is inferred from running
`quarto render _src/ch1.qmd` and `quarto preview _src/ch1.qmd`.)

This behaviour is observed, not documented by Quarto as far as was found. It
is pinned by an integration test and by the version check (§10).

A source rendered *without* the compiler — bare `quarto render` on a single
file, or on a file under `_src/` — shows literal `{{…}}` in the output. That is
a feature: unlike every failure mode in §2, it is loud, visible, and caught by
the L2 lint besides. In a project, bare `quarto render` is safe, because the
pre-render step is the compiler.

**One parser, three consumers.** The parser is the package's core artifact,
shared by the preprocessor, the static lints (§5), and the commit-gate AST
differ (§6). No off-the-shelf parser does the job — `parsermd` (active,
`parse_qmd()`, `#|` support) carries no source positions at all; `lightparser`
likewise; there is no R-usable tree-sitter markdown grammar — so the parser is
built on `commonmark::markdown_xml(sourcepos = TRUE)` (exact line/col spans on
every node, the tinkr approach) with a chunk-header/YAML pre-pass for the
Quarto-specific structure. The carve-out list — spans the preprocessor must not
rewrite and the lints must not flag — is defined once, in the parser: fenced
blocks, non-`r` inline spans, YAML, math spans, link targets and URLs, citation
keys, footnote markers, `{#…}` attribute blocks.

A governed span can cross inline nodes (`[*All* models]{{…}}` is text, emphasis,
text), so the substitution scanner runs over source spans under the carve-out
mask, not over individual text nodes.

**One compiled call per substitution.** Each `{{…}}` and each governed span
compiles to its own inline expression — `` `r clag::subst(<id>)` `` — with the
source file, position, expression text, checks, and (for a governed span) the
arms and the resolved governor of any nested bracket embedded at compile time.
Substitutions nested inside an arm keep their own ids. Because `subst()` knows
its own identity, the value ledger (§7) is emitted by the runtime itself, with
exact provenance.

**Where R evaluates outside prose** (so the preprocessor's boundaries are
principled): chunk options are evaluated in `knit_global()` before the chunk
runs (`fig.cap`/`fig.alt` after, so they can use the chunk's results); Quarto
`#|` cell options are literal YAML unless tagged `!expr`; YAML front matter
honours `!r`/`!expr` via rmarkdown. The preprocessor does not rewrite inside any
of these, with one exception: **captions get sugar.** A `{{…}}` or governed
span inside a `#| fig-cap:`, `#| fig-alt:` or `#| tbl-cap:` string is compiled
to `!expr clag("…")`. Every other cell option, chunk header option and YAML
field stays a carve-out. L11 checks captions regardless of how they were
built.

**Condition capture.** Confirmed: chunk warnings and messages are written into
the rendered document and do **not** echo to the console — the exact
signal-existed-but-unread failure this package exists to prevent. Confirmed:
`rmarkdown::render()` sets `error = FALSE` (overriding knitr's permissive
default), so a chunk error aborts with exit status 1, and Quarto behaves the
same; but nothing built-in promotes warnings or messages to failures. The
compiler therefore injects a hidden setup chunk at the top of every compiled
document. It sets knitr's `warning`/`message` hooks to tee every condition into
a machine-readable log alongside the document, and clag applies its own
severity rules there (§7). The chunk travels with the document, so capture
works on both routes above, including a bare `quarto render` of a project. The `evaluate.inline` hook — which receives
the source code and environment, unlike the `inline` output hook which receives
only the value — is set as a backstop ledger for any raw `` `r ` `` inline code
that bypasses clag syntax.

---

## 2. What problem the harness solves

Ten failure modes in computational manuscripts, grouped by where the break
happens. The grouping matters: the first group corrupts the value before prose is
involved, and no amount of prose discipline detects it.

### A — the pipeline yields a wrong value

| # | Mode | Layer |
|---|---|---|
| A1 | **Silent success of a failed computation.** A join drops rows, a filter matches nothing, a model fails to converge, and the code carries on. | L12, L6 |
| A2 | **Stale or wrong input.** The computation is correct; the data it consumed is not the data intended. | L12 |

### B — the link between value and prose breaks

| # | Mode | Layer |
|---|---|---|
| B1 | **Silent deletion.** A `sed` or heredoc removes a paragraph, a section, or a substitution. What remains is valid markdown, renders clean, looks fine. | L1 |
| B2 | **Reversion to literal.** `{{pcf(x)}}` becomes the literal `12`. Renders perfectly, forever, silently decoupled from the pipeline. | L2 |
| B3 | **Artefact staleness.** The rendered `.md` predates the `.qmd`, so everything downstream of it reads fiction and reports PASS. | L6 |

### C — the prose is wrong about a correct value

| # | Mode | Layer |
|---|---|---|
| C1 | **Prose/value divergence.** The number updates on refit; the sentence still says "rose sharply" when the value went to −1. | L3, L5 |
| C2 | **Assertion never computed.** A set fact, ranking, direction or comparison is stated that was never calculated. Nothing decoupled — it was never coupled. | L2, L3 |
| C3 | **Misattribution.** Value and sentence are each correct but refer to different quantities. `claim(n_sites, . > 50)` passes happily while the sentence is about creeks. | none — tier 3 |
| C4 | **Definitional drift.** The same term carries different meanings in different chapters, each internally consistent. | L10 |
| C5 | **Stale shape description.** Prose or a caption describes an object's columns, row count, or what it draws, and the object changed. | L11 |

C2 is typically the largest class, and it is the one a number-focused scheme
misses entirely.

### The layers

| Layer | What it checks | Runs at |
|---|---|---|
| L1 | structural AST diff — declared vs observed changes | commit gate |
| L2 | claim-token coverage (static) and literal checks (knit) | gate + knit |
| L3 | `claim()` evaluation | knit |
| L4 | cross-references and citations | gate |
| L5 | value ledger | knit |
| L6 | render wrapper: condition surfacing, artefact hashing | knit |
| L7 | prose linting (Vale) | `verify()` |
| L8 | hygiene | gate |
| L9 | trailer and register validation | commit gate |
| L10 | dictionary lints — keys resolve, shadowing rules | gate |
| L11 | figure and table contracts | knit |
| L12 | pipeline data contracts | pipeline |

### The failure that shapes the design

Checks whose output nobody reads reproduce the failure they were built to
prevent. In the manuscript that motivated this package, both recorded incidents
were **signal-existed-but-unread**: knitr wrote the warning into the document,
the boundary-fit message was emitted, and both sat in plain sight for weeks.
(§1 confirms this is knitr's default plumbing: conditions land in the rendered
output and nowhere else.)

**Surfacing beats coverage.** Every layer must fail loudly at a checkpoint
someone passes through, or not exist.

---

## 3. Design principles

**P1 — Every check must have a machine-checkable ground truth.** A mechanism that
enforces *form* rather than *content* is satisfiable without thought.

**P2 — The machine observes; the author declares; the machine checks the
declaration.** A declaration made *before* acting is a prediction, and predictions
are falsifiable. Never ask a component to grade its own work after the fact — the
misclassification and the damage share a root cause.

**P3 — Prevention where anticipated, detection everywhere.** `claim()` protects
values someone thought to guard; the ledger catches drift in the ones nobody
guarded. The second is the safety net under the first.

**P4 — Prefer categories with an external referent.** A category whose sub-lint
checks a real fact (does this key exist in the bib?) is worth several whose
sub-lint checks a shape.

**P5 — Keep category sets small.** Every category is a place to hide. This governs
*categories*, not *triggers*: the shipped literal checks stay at two or three, while the
lexicon deciding which sentences need looking at should be as broad as possible.

**P6 — Fast checks gate commits; slow checks gate tasks.** Anything needing a knit
cannot live in a git hook. A gate that fires constantly gets ignored.

**P7 — A convention that is only documented will rot.** Every convention gets a
validator, a warning, or an explicit place on a human worklist.

**P8 — Generated and authored records never share a directory.**

**P9 — Partial coverage beats none, and every check declares its tier.**

| Tier | Mechanism | Behaviour | Example |
|---|---|---|---|
| 1 | **Hard rule** — decidable from source | fails the gate | no bare numbers |
| 2 | **Warning on new material** — heuristic trigger | prints, does not block | "these added sentences look like claims" |
| 3 | **Human read** — flagged, ranked, never adjudicated | worklist | misattribution |

A tier-1 rule on a tier-2 problem produces an exception list without end; a
tier-2 warning on a tier-1 problem is a gate people learn to ignore.

**Tier 2 scopes to newly added material, not to the corpus.** A heuristic across a
whole book returns a thousand lines and is read once; across the sentences a
commit *adds*, it returns a handful and is read every time. The backlog becomes a
ratchet. The commit gate already holds both ASTs, so the added-sentence set costs
nothing extra.

**P10 — Installation is always an explicit call.** Nothing is written to a user's
repository as a side effect of `library()`. Every file the package places is
placed by a `use_*()` function that says what it will write.

---

## 4. Public API

### Claims

Two spellings, one mechanism. The common case is the **inline check** — unnamed
ARGS in a substitution:

```
The gap is {{n_gap, . > 10}} sites.
```

which compiles to `claim(n_gap, . > 10)`. A **phrase** whose truth depends on a
value the sentence never displays is guarded by a single-arm governed span
(§0):

```
Council will need to [add more sampling sites]{{n_gap > 10}}.
```

which compiles to `claim("add more sampling sites", n_gap > 10)`. The
standalone call is the same mechanism for use in R code, and for guarding a
value in place inside a larger expression (`{{trend(claim(foo, . > 0))}}`).

```r
claim(x, <expression>, ...)
```

- **`x` is any type.** A number, or the phrase a governed span guards.
- **`.` pronoun** — `claim(shift$n_down, . >= 10)` rather than naming it twice.
- **Varargs, not `&&`** — `claim(x, . >= 10, test_int(.))` reports which half
  failed; `&&` collapses them into one opaque boolean.
- **NSE** — capture unevaluated via `rlang::enquos()`. The error
  text *is* the feature; without NSE you get "claim failed".
- **Returns `x` visibly** — otherwise the substitution renders nothing and the
  co-location that is the whole idea is lost.

`checkmate::test_*` is the right half of that package to use inside a claim: it
returns a logical. `assert_*` returns invisibly and throws with checkmate's own
variable-centric message, bypassing ours.

**Scope: a governed span guards its bracket, and the bracket is still prose.**
The L2 lint recurses into it, so a numeral inside must be its own substitution.
If `n_gap > 10` is what makes *"add two more sampling sites"* true, the "two"
is written `{{n_extra}.word}` inside the bracket. The idiom is to wrap the
trigger word, or the clause, and nest what is computed:

```
[All]{{all(mod$rising)}} {{nrow(mod)}} models rise
[All {{nrow(mod)}} models rise]{{all(mod$rising)}}
```

This narrows a hole the string form had: `claim("the 47 sites rose 12%",
x > 0)` was one weak guard over four claims, and its numerals were invisible to
L2. The hole that remains is a long bracket with one loose governor; an
advisory listing governed spans whose text exceeds a token count catches the
lazy case. A standalone `claim()` with a string first argument, in R code,
keeps the old limit: its string is not linted.

**The error message is the deliverable, not the assertion:**

```
14-percentile-bands.qmd:412 — "All 10 models rise"
Claim "All" failed
  all(mod$rising) was FALSE
Read the sentence. If FALSE is right, rewrite the sentence.
Do not loosen the claim to clear this.
```

**Design rule shipped in the docs:** a good bound is the widest range over which
the sentence stays honest. Too tight and it fires on every refit and gets widened
without thought; too loose and it is inert.

**Known limit:** arbitrary expressions are opaque to later analysis — you cannot
mechanically find claims with vacuous bounds. A problem for the version after the
one that reveals whether it matters.

### Literals

A number that cannot be computed is written as a literal, and should carry a
check saying why it is trusted: `{{10, cite(smith2020)}}`,
`{{2020, is_year(.)}}`. A bare `{{10}}` is allowed. It is the deliberate escape
hatch: nobody types the braces by accident, and a rule demanding a check would
be met with `{{10, TRUE}}`, which is worse because it looks checked. What a
bare literal cannot do is hide: it is reported when added and counted
book-wide (§5), and a computed value replaced by a literal is reported at the
commit (§6).

These are ordinary checks, not a second mechanism. Two ship:

| Check | For | What it verifies |
|---|---|---|
| `cite(key)` | a number quoted from a source | the key resolves in the bib. A real external check, and it covers the "10% (Smith 2020)" case that has no pipeline provenance |
| `is_year(.)` | a year not held in the dictionary | 1–4 digits, plausible range |

**Before writing a literal, ask why the number cannot be computed.** Most
candidates fail the test — a project constant goes in the dictionary; a count
of things in the document gets counted; an ordinal gets computed. A number
inside a proper name ("Site 12") belongs in the dictionary, read from it, so
renaming propagates rather than being certified as correctly typed. Documents
extend the set by defining their own check function, which is why the
extension mechanism is R itself.

### Dictionary

```r
dict$era_split
dict_local$sites       # chapter override, deliberately a different accessor
```

In prose: `The manual era ends in {{dict$era_split}}.`

`dict` is not a plain list. A plain list's `$` returns `NULL` on a typo and
partial-matches a prefix (`$era` finds `era_split`), silently — the exact
failure class this package exists to remove. `dict` carries its own `$`
method, which errors on any name that is not an exact key. The key is also a
plain token in the parsed expression, so a **static** lint verifies that every
read names a real key without running R, and key errors surface at the commit
gate rather than at knit.

**What belongs in a dictionary: stipulations, never derivations.** Things that
were *chosen* — era boundaries, band cuts, confidence levels, canonical labels.
Anything computable belongs in the pipeline. That boundary is the residue left by
the "why can't this be computed?" test above, so one question governs both.

**Consequence: every entry is a decision, and dependency is derived rather than
declared.** A chapter that reads `era_split` depends on the decision behind it;
moving a paragraph between chapters moves the dependency with it. This is the
part of P7 documentation cannot hold — a decision log stays accurate through
edits and rearrangements only if nothing is maintained by hand.

Schema:

```yaml
era_split:
  value: 2014
  type: year
  definition: "Boundary between the manual and instrument eras."
  decision: D-31

tier_lab:
  value: {reference: Reference, slightly_disturbed: Slightly disturbed, urban: Urban}
  type: labels
  definition: "Display names for the disturbance tiers."
  decision: D-12

salinity_res:
  value: 0.01
  type: quantity
  unit: PSU
  definition: "Resolution at which the logger records salinity."
  decision: D-08
```

**Overrides.** A chapter may narrow a key, rarely. One rule governs it:

> A shadowing entry must be read through a different accessor: `dict_local$sites`,
> never `dict$sites`.

This is not bookkeeping. Silent shadowing is the most dangerous failure available
here: chapter 14 redefines `sites`, someone later moves a paragraph from 14 into
15, and `dict$sites` quietly changes meaning with nothing visible in the diff.
With `dict_local$` the moved paragraph **errors**, because chapter 15 has no
local `sites`. A silent semantic change becomes a loud failure at the moment of
the move.

Statically linted both ways: `dict_local$x` with no local `x` is an error;
`dict$x` where the chapter *does* define a local `x` is an ambiguity error. Local
entries require a `why:` field, and the lint prints a book-wide shadowed-key
count — a visible cost rather than a gate.

**Two things the dictionary removes rather than checks:** the glossary is
generated from `definition:`, so a term's stated meaning and its value in use
stop being two artefacts that can disagree; and `unit:` makes unit consistency
true by construction rather than lintable.

### Formatters

`pcf()`-style number formatting, `n_word()` for spelled numerals, unit-aware
printing driven by the dictionary's `unit:` — all exposed as chain names in
the grammar (`{{n_gap}.sci}`, `{{nrow(mod)}.num}`, `{{n}.word}`; §0) and as
ordinary functions. Each formatter returns the text and the number as printed,
because arm selection in a governed span reads the printed value (§0).
Implemented over `glue_vec()`, which named ARGS pass through to. The lint that
pairs with them: no raw `round()` output reaching prose.

---

## 5. Lints

Each ships as a function returning a structured result, and as an entry in the
gate. Defaults ship with the package; projects supply additions only. All static
lints read the same parsed AST the preprocessor uses (§1) — one parser, one
carve-out list.

### L2 — claim tokens

**No bare claim tokens in prose.** Two kinds, two tiers:

- **Numerals — tier 1.** A numeral in prose almost always encodes a data claim, so
  the rule is absolute: every numeral in prose sits inside a substitution.
  The rule stops at the braces; what is typed inside them is tier 2 (below).
  This also catches B2 mechanically: a
  substitution reverted to its literal value *is* a bare numeral.

  A **numeral** is a standalone numeric token: digits, with an optional sign,
  separators, decimal part or `%`. A token that mixes letters and digits
  (CO2, PM2.5, 3D) is a name and is exempt. "Site 12" is two tokens, so the
  12 is flagged and belongs in the dictionary (§4).
- **Quantifiers, extrema, direction words — tier 2.** "all", "none", "every",
  "only", "largest", "first", "rose", "more", "majority". These carry a data claim
  often but not reliably: *"limits at all"*, *"populated only from 2020"* and *"no
  longer"* are not claims and never will be. A ban here would need a semantic
  exception list, failing P1 and P5.

Tier 2 has two triggers, both computed from what the gate already holds:

1. **A claim word in the same sentence as a substitution** — the strongest,
   because the sentence is by construction about a computed value. This set grows
   on its own as tier 1 lands: *"the list contains two wetland sites"* must become
   `{{n_wet}}`, dragging the sentence into the trigger set for free.
2. **A claim word in a newly added sentence with no computed value at all** —
   noisier, but scoped to the delta it stays a handful per commit.

A claim word inside a governed span (§0) is guarded and triggers neither.

Both print, neither blocks:

```
tier 2 — 3 added sentences read as claims with no guard:
  13-current-rating.qmd:204
    "All four rise, and every one of them is steeper than the third."
```

**Static checking** (gate, no knit): parse each substitution and report every
`NUM_CONST` in a value expression that carries no check. Constants inside the
checks themselves are exempt. All of it is **tier 2**: it prints for newly
added material and never blocks.

- **An unchecked literal** (`{{10}}`) is listed with the suggestion to say why
  it is trusted: `cite()`, `is_year()`, or the dictionary.
- **A constant buried in a computation** (`x * 100`, `sites[1]`) is listed
  separately and more quietly; most are benign.

`status()` and `verify()` print the book-wide count of unchecked literals — a
visible cost rather than a gate, as with shadowed dictionary keys (§4). The
coverage half of this check — a check stripped from a substitution by a
transform — is caught at the commit by the loosening report (§6).

**Semantic checking** (knit): `cite()` resolves its key; `is_year()`
range-checks. Fatal via the render wrapper's `error = FALSE`.

**Carve-outs, decidable by AST position** — which is what makes "scan and say with
confidence" achievable: the parser's carve-out list (§1). The same list bounds
the preprocessor, so "what the lint skips" and "what clag rewrites" cannot
drift apart.

### L4 — cross-references and citations

Book-wide by necessity: ids share one namespace, so per-file checking is
incoherent.

- anchors resolve; duplicates discriminated ("same id twice in one file" and "id
  redefined in a moved chapter" are different problems)
- **dangling citation keys flagged** — a `@key` absent from the bib renders as
  literal `@key` in the output
- **governed span colliding with a reference label** — tier 2. `[foo]{{…}}`
  where `[foo]: url` is defined reads as a link in any render that bypasses
  the compiler (§0)
- **orphan anchors** — defined, never referenced. Not an error; the signature of a
  content move that stranded a figure

**Limit, stated in the docs:** L4 checks that a reference *resolves*, not that the
target still says what the citing sentence claims. That is tier 3.

### L8 — hygiene

Generic, shipped on by default:

1. **Every section anchored, every chunk labelled.** Duplicate labels break knitr,
   and unanchored sections have no stable identity, which L1 depends on.
2. **Targets hygiene** — every `tar_read()`/`tar_load()` names a target in the
   manifest. Catches renames immediately.
3. **No chapter-local redefinition of a dictionary key.**
4. **Number formatting consistency** — no raw `round()` output in prose.
5. **Seed discipline** — `sample`/`rnorm`/`runif` without `set.seed()` in scope.
6. **Internal file links resolve.** External URLs skipped with a warning offline.
7. **Orphaned build artefacts** — every `.pdf` and `_files` directory corresponds
   to a live source file. Catches rename drift.
8. **Register `FIXED` claims resolve** — every status claiming a fix cites a commit
   hash that resolves or a `file:line` that exists. Ships because the register
   format ships; ~20 lines and the highest value-per-line item here.

Unit consistency and figure completeness are absent by design: L10 and L11 make
them structural rather than lintable.

### L10 / L11 / L12 lints

Covered under the dictionary (§4), contracts (§7) and pipeline contracts (§8).

---

## 6. The AST layer and the commit gate

### Predicate identity

Granularity is set by which nodes carry stable ids across two versions:

| Node | Identity | Predicate |
|---|---|---|
| xref anchors | globally unique (L4 enforces) | exact: removed / added |
| `{#sec-…}` sections | stable across heading rewording | exact |
| labelled chunks | exact where labelled | exact |
| prose substitutions `{{…}}` | none | multiset comparison only — advisory |

### Substitutions are advisory, not declarable

Counting substitution deletions is the wrong measure: rewording a sentence
containing two substitutions registers as two deletions plus two additions when
nothing was lost. **Compare the multiset of substitution texts instead**
(governed spans included, bracket and braces together) —
rewording leaves them present, a `sed` that eats them removes them from the set.
Check file-wide, so a move between sections does not trip it. A net loss prints
as an advisory line alongside the verdict.

### The gate

**`commit-msg`, not `pre-commit`** — `pre-commit` runs before the message exists
and cannot check a declaration in it. Paired with `prepare-commit-msg` to populate
a template, which fills the **file list only, never the observed predicates**.
Show the author the answer and the declaration becomes theatre (P2).

Reads `git show :<file>` — **the index, not the worktree.** Staged and working
copies differ; checking the worktree gates the wrong content.

**One executable, one report.** Agents commit frequently, and every tool call
replays context and adds to it, so a gate assembled from a dozen calls
discourages the commit discipline it exists to support. The same applies to
anything the report *recommends*: if the gate can tell that removing an anchor
strands three chapters, it runs the xref scan itself and includes the result. It
never asks the author to go and run something.

### Trailer vocabulary

Strict single-line git trailers, keys repeat. Extraction is then
`git log --format='%(trailers:key=Removed,valueonly)'` — no custom parser, only a
validator. Verb-as-key also makes the query dimension the verb, which is the
dimension worth querying after the fact.

**Structural keys** — value grammar `<file> (<anchor> <note>)+`:

| Key | Note |
|---|---|
| `Removed:` | |
| `Added:` | |
| `Renamed:` | heading text changed, anchor stable |
| `Relabeled:` | own grammar: `<file> <old> <new> <note>` |
| `Edited:` | body text changed, anchor stable |

**Register keys:**

| Key | Grammar | Consumer |
|---|---|---|
| `Decision:` | `<id> — <text>` | decision log |
| `Propagates:` | `<was> → <is> in <files>` | propagation log |
| `Closes:` | `<id>` | task closed, commit is the evidence |
| `Partial:` | `<id> (left: <text>)` | task advanced, still open |
| `Refs:` | `<id>` | backlink, no status change |

`Partial:` stays separate from `Closes:` rather than being a modifier — otherwise
the regex distinguishing `C-43` from `C-43 (left: …)` is doing semantics, and a
malformed note silently closes a live task. `Refs:` earns its place despite P5:
without it, work that touches a task without finishing it has no way to say so,
and the pressure runs toward writing `Closes:` early — the false-`FIXED` failure.

Notes are free text, capped short, and **may not contain `#`**, since the parser
splits on the next `#`-initial token.

**Validation:**

- **Unknown key is an error.** A typo'd `Close:` would silently drop a closure —
  the exact drift being fixed. Whitelist the ten, plus a passthrough list
  (`Signed-off-by`, `Co-authored-by`, and any project additions).
- **Ids must resolve** in the register they name.
- **No ordering requirement** — sorting is the generator's job.
- At least one structural entry per touched file.

Example:

```
C-44: drop the provisional band table, tidy the Method text

Removed: 14-percentile-bands.qmd #sec-prov provisional band table
Edited: 14-percentile-bands.qmd #sec-bands/Method removed repetition
Decision: D54 — provisional bands dropped; the revised set supersedes them
Propagates: @tbl-prov-bands → ch15 §window, ch17 §arms
Closes: C-44
```

Rejection:

```
commit-msg: undeclared structural change

  14-percentile-bands.qmd  #sec-bands  changed, not declared

  advisory: 2 substitutions no longer appear anywhere in this file
      - {{band_cut$lower}}
      - {{band_cut$upper}}
    A sed that matched in more than one section is the usual cause.

  xref: removing anchor `tbl-prov-bands` strands 3 references
      15-revised-rating.qmd:88   @tbl-prov-bands
      17-management-arms.qmd:204 @tbl-prov-bands
      17-management-arms.qmd:251 @tbl-prov-bands

  tier 2 — 1 added sentence reads as a claim with no guard:
      14-percentile-bands.qmd:96
        "Every creek in the revised set shifts down at least one band."
```

### Known limit

`--no-verify` bypasses it, and that is correct. There is always a circumstance
needing an escape hatch. The aim is not to stop active cheating (rare) but to
catch unintended mistakes.

### The claim-loosening report

The pressure runs toward widening a bound rather than rewriting a sentence, and
the author is the wrong person to police it. **Every commit that modifies an
existing check — inline or `claim()` — lists the before and after**, computed
from the two ASTs, not self-reported. A legitimate loosening survives the
question; a reflexive one does not. This also gives a failing claim a defined
exit, without which the discipline decays. Because inline checks compile to
`claim()` (§0), one report covers both spellings.

The same report lists two neighbouring changes, found the same way: a check
**removed** from a substitution that still exists, and a **computed value
replaced by a literal** (`{{pcf(x)}}` becoming `{{12}}`). The second is B2
wearing braces. A literal is legal (§4); swapping one in for a computation is
the event worth a line in the commit report.

---

## 7. Knit-time: ledger, wrapper, contracts

### The value ledger (L5)

Because L2 makes every number a substitution, and every substitution compiles to
a `clag::subst()` call carrying its own identity (§1), the runtime captures every
rendered value at the moment it renders: expression text, value, file, position,
chapter. For a governed span it records the governor's value and which arm was
chosen. A **typed ledger**, exact and keyed on the substitution itself — no
knitr introspection required. (The knitr `evaluate.inline` hook, which receives
source and environment but no position, backstops any raw `` `r ` `` code that
bypasses clag syntax; it records occurrence order only.) Commit the ledger; diff
it on re-render.

**Format.** One JSON-lines file per source file, under `generated/ledger/`
(P8), one line per substitution. Each line is keyed on section anchor,
expression text and occurrence index within the section — the stable
identities of §6. Line numbers are **not** stored: they shift on every edit
and would bury real value changes in the diff. They are recomputed when a
report is printed.

**Partial knits.** An agent refits a model chapter 17 also reads, knits only
chapter 14, and 17's numbers move with nobody rendering 17. Two mechanisms:

- the ledger records which pipeline targets each chapter's values depend on —
  available from `targets` at render time, not inferred
- **a stale entry is a distinct state from a changed one.** `verify()` reports
  "chapter 17: 34 values stale, not re-rendered since `fit_reband` changed." No
  partial knit passes silently as clean.

**Why the layer exists alongside L2 and L3.** L2 guarantees numbers are *computed*
and says nothing about whether the sentence is still true. L3 guarantees numbers
*someone guarded* stay in range, and coverage is never complete — the uncovered
set is not random, it is precisely the numbers nobody thought hard about, which is
the highest-risk population by selection. A refit moves forty numbers; five have
claims.

**Triage.** The raw diff is dozens of lines, nearly all benign; the problem is
ranking, not detection.

- **Structural, no language needed** — sign flip, order-of-magnitude change,
  crossing zero, crossing 1.0, crossing a dictionary threshold, a governed
  span choosing a different arm. Unambiguous must-reads.
- **Claim-word proximity** — the same lexicon L2 uses for tier 2, asking a
  different question: not "is this sentence guarded" but "did a value next to a
  claim word just move". One lexicon, two uses.

**Honest limit, stated in the docs:** both families are heuristics that *narrow
the human read*. Nothing here verifies English against a number, and no tool
claiming to should be trusted.

### The render wrapper (L6)

The defaults hide failures — each of these confirmed against knitr 1.51 /
rmarkdown 2.31 source or empirically (§1):

- knitr writes chunk warnings and messages into the **rendered document**, and
  they do not echo to the console at all
- a direct `knitr::knit()` defaults to `error = TRUE` — a chunk can fail and the
  process still exits 0. (`rmarkdown::render()` overrides this to
  `error = FALSE`; the injected setup chunk (§1) sets it explicitly in every
  compiled document, so it never relies on the caller's path.)
- nothing built-in promotes warnings or messages to render failure
- not everything reporting a broken model is a warning — `lme4`'s
  `boundary (singular) fit` and `glmmTMB`'s non-positive-definite Hessian arrive
  as **messages**

The wrapper therefore tees all conditions through knitr's `warning`/`message`
hooks into a machine-readable log, applies a severity pattern list there (the
model-fit messages above ship in it), and fails the render on anything the list
marks fatal. Plus: **surface L2, L3 and L11 failures distinctly** from ordinary
knit errors, because their fix differs in kind (rewrite prose vs fix code).

**Artefact hashing (B3).** Every generated artefact records the hash of every
source it was built from, and every consumer checks before reporting. A hash
mismatch is a hard error, not a warning: a PASS from a stale artefact is worse
than no check, because it consumes the attention a real check would have earned.

### Figure and table contracts (L11)

Computed captions are not checked captions. A caption built by `glue` from the
wrong object is still wrong.

Assert properties of the **built object**, not the code that made it —
`ggplot_build()` exposes what actually reached the panel:

- every mapped aesthetic has a guide, or is named in the alt text
- the alt text names every variable the plot maps
- free scales flagged — they make panels visually comparable that are not
- the row count behind the figure matches any count the caption states
- `fig-cap`/`fig-alt` present and non-empty; `tbl-cap` on every table

The first four catch C5. Presence checks live here rather than in L8 because they
share the introspection pass.

**Not mechanisable, and the package does not pretend:** generating alt-text
*prose* from plot code is judgement. The contract checks correspondence between
text and object; it does not write the text.

---

## 8. Pipeline contracts (L12)

Every other layer protects the prose and assumes the numbers are right. A1 and A2
say that is the assumption most likely to have already failed.

Unit tests check functions against fixed inputs. Data contracts check *actual*
data at pipeline boundaries, which is the only place a corrupt cache or a join
that silently dropped 40% of rows becomes visible. The backend is **pointblank**
(resolved): the package wraps it and supplies the assertion set:

- **row-count deltas across joins** — the single most common place rows vanish
  without warning. Assert the expected relationship, not an absolute count
- **key uniqueness and completeness** on anything used as a join key
- **domain and range** on measured variables, against the dictionary's `unit:` and
  any stated resolution
- **no unexpected `NA` introduction** — count entering, count leaving
- **cardinality of grouping variables** — so a filter matching nothing fails
  loudly instead of producing an empty, valid, plausible table
- **model convergence as an assertion** rather than a message to be grepped, so a
  singular fit raises where it happens and the render wrapper's pattern list
  becomes a backstop rather than the only defence

**Vintage (A2).** The pipeline records the identity of its inputs — hash and mtime
of every source file — into the target, so a value can be traced to the bytes it
came from. This is the pipeline half of L6's artefact hashing, and it makes "did
this come from the corrupt cache?" a question with an answer.

---

## 9. Prose linting (L7)

Cross-chapter prose consistency — terminology drift, spelling, heading
capitalisation, sentence length — is a real problem in any multi-author book and
nothing else in the scheme touches it. Vale is the right tool (active, v3.18 at
`vale-cli/vale`); no R wrapper package exists, so clag ships a thin `processx`
wrapper — `vale --output=JSON` emits per-alert `Line`/`Span` fields, and the
binary is discovered via `PATH` or explicit config.

**Run it on the rendered `.md`, not the source.** Substitutions are resolved, so
Vale reads "12.3" rather than an opaque brace span, and readability and
terminology rules become meaningful instead of noise. Captions and alt text —
invisible to a source-linting Vale because they live in chunk headers — appear as
ordinary prose. No `TokenIgnores` for `{{…}}` spans, no chunk-header handling.

**Map hits back automatically.** Prose survives knitting close to verbatim, so
mapping a `.md` hit to its source line is a search for the matched span,
disambiguated by the enclosing section from the AST the gate already builds. The
residue prints as "`.md` only" with the surrounding sentence. **An agent should
never be handed a line number in a file it does not edit.**

**Two tiers, do not fight this:** published prose (terminology, spelling,
readability, captions) goes to Vale on the `.md`; source structure (anchors,
check coverage, chunk labels) goes to the R lints on the source, where that
information exists and Vale cannot see it.

**`BlockIgnores` for `::: {.callout-…}` divs is still needed** — divs are Pandoc
markup, not R, and reach the `.md` untouched.

The terminology style is **generated from the dictionary**, so a term's canonical
spelling has one home rather than two. Vale styles are plain YAML files (`.yml`
extension required), so generation is `yaml::write_yaml()` — no custom emitter.

Placement: `verify()`, after the knit check — not a commit gate. Terminology drift
should not block a commit.

---

## 10. Installers and shipped assets

All under P10: explicit calls, never side effects of loading.

| Function | Writes |
|---|---|
| `use_clag()` | everything below, with a summary of what it will do first |
| `use_hooks()` | `commit-msg`, `prepare-commit-msg` shims calling the gate |
| `use_dictionary()` | dictionary skeleton and schema |
| `use_vale()` | `.vale.ini`, the shipped style, the generated terminology rule |
| `use_registers()` | `generated/` directory and the trailer-driven generators |
| `use_agent_docs()` | agent-facing conventions and the Claude skill |
| `use_contracts()` | pipeline contract scaffolding for an existing `targets` project |

### `inst/` contents

- git hook templates
- Vale style and default `.vale.ini`
- dictionary JSON schema
- **a Claude skill** — the agent-facing conventions: render via `clag_render()`
  only, knit at end of task, commit trailer format, never loosen a claim to
  clear a failure, `dict_local` rules
- templates for `AGENT-RULES.md` and `STATUS-CONVENTION.md`
- default claim-word lexicon and carve-out list (these are English, not project
  facts, so they ship as defaults and projects add to them)

### Adoption helpers

- **`dict_seed()`** — harvests candidate dictionary keys by finding constants
  defined in more than one chapter. The migration this package most wants people
  to do is mechanically discoverable, so the tool ships rather than the advice.
- **`status()`** — reports which layers are installed, which are configured off,
  and what the next step in the adoption order is.
- **`recall_check()`** — given a set of recorded findings and a pre-remediation
  commit, runs a lint against the historical state and reports what fraction of
  those findings it reproduces. Turns "is this check good enough to replace the
  manual audit?" into a measurement.

### Version pinning

The project config records the package version, and `verify()` warns on mismatch.
Without this a package update silently changes gate behaviour mid-project, which
is artefact staleness wearing the tooling's clothes.

---

## 11. `verify()`

One entry point. Runs, in order:

```
L12 → L4 → L2-static → L10 → L1 → L8 → L9
     → render via clag_render() (L6) → L2-semantic + L3 + L11 → L5 → L7
```

The git hook calls the pre-knit subset as a single tool. Each layer is
individually switchable in config; `verify()` reports which were skipped and why,
because a silently disabled check is worse than an absent one.

---

## 12. Tests

`testthat`, seeded by the parser and compiler (the component everything else
consumes), then `claim()`, `dict$`, `dict_local$`, `cite()` and `is_year()` —
the functions with the sharpest contracts. Then the lints, each against a
fixture pair (a source that should pass, one that should fail).

The grammar and the AST differ need the most fixtures. Grammar: every clause of
§0 (finding the closing `}}`, argument roles, every rung of the count ladder,
logical governors and their failure, `#`, selection on the printed value,
nested brackets and what they inherit, escapes, unknown chain names, carve-out
boundaries). Differ: reworded headings with stable anchors,
moved sections, a `sed` that ate two substitutions across sections, a relabel.
These are the cases where the package is either useful or a nuisance.

Note that `testthat` covers the *functions*. The pipeline itself needs data
contracts (§8); they are complementary, not alternatives.

---

## 13. What the package deliberately does not do

- **Judge prose.** No layer verifies English against a number. Heuristics narrow a
  human read and are labelled as such.
- **Write alt text or captions.** It checks correspondence; generation is
  judgement.
- **Catch misattribution (C3).** A right value beside a right sentence about a
  different quantity passes everything here. Stated in the docs so nobody assumes
  otherwise.
- **Hold a project's constants.** The dictionary schema ships; the values do not.
- **Support rendering that bypasses the compiler.** A single file, or a file
  under `_src/`, rendered by bare `quarto render` shows literal `{{…}}` in its
  output — loud by design, and caught by L2 besides. A project is the one case
  where bare `quarto render` is safe, because its pre-render step is the
  compiler (§1).
- **Install itself.** P10.

---

## 14. Open design questions

None at present.

Settled since the last revision, and now written into the sections named:
sentence inference dropped and MAP removed (§0); binding form deferred (§0);
chain names and the shadowing rule (§0); vectorised lookups (§0); `dict$key`
(§4); numeral definition (§5); ledger format (§7); caption sugar (§1); project
render through pre-render (§1); reference-label warning (§5, L4); selection
on the printed value (§0); constants in braces are tier 2 (§4, §5); error
positions on the project route (§1); the Render-button addin and task (§1). Static
exhaustiveness checking for lookups was considered and dropped: the levels of
an arbitrary R value are not knowable without running R, and `lookup()`
already errors on an unknown key at knit.

---

## 15. Build order

Proposed. Each stage leaves something usable on its own, and the order follows
the argument in the introduction: the harness is only sustainable once a
substitution is cheap, so the core comes first.

**Stage 1 — the templating core.** Usable alone as the successor to `gluey`.

- the parser: commonmark with source positions, the carve-out mask, the
  closing-brace rule
- the compiler, `clag::subst()`, and `clag()` for templates in R code
- value substitutions, checks compiling to `claim()`, `cite()`, `is_year()`
- the chain, with the shipped formatters and styles
- governed spans: the count ladder, logical governors, `#`, nested brackets
- `brk()` and `lookup()`
- `clag_render()` for a single file
- the §0 grammar fixtures (§12)

**Stage 2 — projects and the render wrapper (L6).**

- the project route: `_src/`, the pre-render compile, `clag_preview()`, the
  RStudio addin and Positron task
- the injected setup chunk, the condition log and the severity list
- caption sugar
- artefact hashing
- `use_clag()` and `use_hooks()` in minimal form, version pinning

**Stage 3 — dictionary and ledger (L10, L5).**

- `dict`, `dict_local`, the schema, the generated glossary
- the ledger: emit, diff, stale-versus-changed, triage

**Stage 4 — static lints and the commit gate (L2, L4, L8, L1, L9).**

- L2 static coverage and the tier-2 claim-word triggers
- L4 and L8
- the AST differ, the trailer vocabulary, the `commit-msg` gate
- the claim-loosening report

**Stage 5 — contracts, prose and adoption (L11, L12, L7).**

- figure and table contracts
- pipeline contracts over pointblank
- the Vale wrapper and the generated terminology style
- `verify()` as the single entry point
- `dict_seed()`, `status()`, `recall_check()`, the agent docs and skill

Stage 3 comes before stage 4 because L2's tier-1 rule sends constants to the
dictionary: the gate cannot be switched on until there is somewhere for them
to go.
