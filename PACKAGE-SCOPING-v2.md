# `clag` — package scoping, v2

**Date:** 2026-11-11
**Status:** scoping. The syntax and the runtime are at spec level and were
exercised with throwaway stand-ins (§13 says exactly what was run). Open points
are in §14. Integration facts were checked against knitr 1.51 and Quarto
1.11.9 (Pandoc 3.10) on macOS.

`clag` lets a manuscript's prose carry computed values, and wording that
depends on them, and adds deterministic checks for computational manuscripts.
It has no users and no backwards-compatibility obligations. Portable by
design: the package knows about knitr, Quarto, Pandoc, `targets` and git, and
nothing about any particular book.

The package is two layers. The **prose core** (the syntax of §0 and the
runtime of §1) makes a computed value cost what knitr inline code already
costs, and makes a checked value cost one attribute more. The **integrity
harness** (checks, dictionary, lints, commit gate, ledger) is only socially
sustainable because of that: a rule like "every numeral is a computed value"
survives contact with authors only when writing one is nearly free, and when
the inline R a document already contains counts without being rewritten.

Every clag construct is markdown that knitr, Pandoc and Quarto already accept.
Nothing is compiled, there is no second source tree, and the file the author
edits is the file that renders.

Companion document: `~/projects/10.02 Healthy Waterways/MANUSCRIPT-INTEGRITY-PLAN.md`
covers applying this to the Healthy Waterways manuscript. Layer numbers (L1,
L2, …) match that plan; L7, L9 and L12 are not package layers (§12).

---

## 0. The syntax

Two constructs:

```
`r EXPR`{ATTRS}        a value
[PROSE]{ATTRS}         words governed by a value
```

One rule divides them: **code spans and attribute values hold R; brackets hold
prose.** A value shows the result of an R expression. A governed span shows
ordinary prose whose wording, or whose right to be there at all, depends on an
R value. Prose never sits inside an R string, so it stays visible to the
lints, to spellcheck and to the reader of the source.

### The attribute block

`{ATTRS}` is Pandoc's own attribute syntax: an optional `#id`, then classes,
then `key="value"` pairs. clag gives meaning to three keys (`n`, `if`,
`claim`), to classes (formatters), and to a short list of renderer keys
(`sep`, `last`).

**Canonical form: id, then classes, then keys; every value double-quoted.**
R strings inside a value use single quotes (`{if="tier == 'sev'"}`). Pandoc's
markdown writer, and therefore the visual editor, rewrites any attribute block
into this form, and Quarto 2's parser accepts no other order. A lint enforces
it (§5).

Meaning never depends on the order in which things are written inside the
block. The order of operations is fixed by kind:

```
value  >  checks  >  formatters  >  arm and #
```

### Values

```
`r x`                                bare value
`r n_gap`{claim=". > 10"}            checked value
`r x`{claim=". >= 10, . < 99"}       several checks
`r x`{.num}                          one formatter
`r n`{.no .word}                     formatters, left to right
`r depth`{.num claim=". > 0.5"}      check and formatter
`r sites`{.or}                       "a, b or c"
`r sites`{sep="; "}                  renderer argument
`r sites`{.ul}                       bullet list
```

- **A bare value is plain knitr inline code and prints exactly as knitr prints
  it.** A document that already uses inline R is already a clag document.
  Quarto's `` `{r} x` `` form is equivalent.
- **The attribute block must touch the closing backtick.**
- **`claim` holds an R argument list of checks.** In each, `.` is the raw
  value. Each must evaluate to a single `TRUE`. Checks always see the value as
  evaluated, before any formatter.
- **Classes are formatters**, applied left to right. An unknown class is an
  error.
- **Emphasis is ordinary markdown around the construct**: `` **`r x`{.num}** ``.
  A value that needs a CSS class is wrapped in an ordinary span:
  `` [`r x`{.num}]{.smallcaps} ``.

Shipped formatters:

| Class | Prints |
|---|---|
| `.num`, `.pct`, `.sci` | a number, to the document's defaults |
| `.word` | a spelled numeral ("three") |
| `.ord` | an ordinal ("3rd") |
| `.no` | zero as "no" |
| `.and`, `.or` | a vector collapsed with a final "and" / "or" |
| `.ul`, `.ol`, `.dl` | a bullet, ordered or definition list |

A project registers its own formatter (a function, optionally bundling options
such as significant figures or a unit) under a class name. A project name may
not shadow a shipped one. Dictionary quantities print with their unit (§4).

Each formatter returns two things: the **text** and the **number as printed**
(with a flag for whether decimals are shown). In a chain each formatter
receives the previous result. One that rounds (`.num`, `.pct`) sets the
number; one that only rewords (`.word`, `.no`) passes the number through.

### Governed spans

A bracket followed immediately by an attribute block that carries one of three
keys. The bracket holds one or more **arms** separated by `|`.

| Key | The value must be | Arms | Chosen |
|---|---|---|---|
| `n` | a single number | 1 | always (a template for `#`) |
| | | 2 | one / otherwise |
| | | 3 | zero / one / otherwise |
| `if` | a single `TRUE` or `FALSE` | exactly 2 | true / false; either may be empty |
| `claim` | one or more logical checks | exactly 1 | always; a `FALSE` check is a failed claim |

```
[a person | # people]{n="n"} responded.
[no people | a person | # people]{n="n"} responded.
file[ | s]{n="n"}
Invertebrate numbers [rose | fell]{if="slope > 0"}.
Council will need to [add more sampling sites | ]{if="n_gap > 10"}.
Council will need to [add more sampling sites]{claim="n_gap > 10"}.
[All]{claim="all(mod$rising)"} `r nrow(mod)` models rise.
[# metre | # metres]{.num n="depth" claim=". > 0.5"}
```

- **The key says what kind of governor it is.** The arm count allowed for each
  key is fixed, so a wrong count is found from the source without running R.
  A span carries exactly one of `n` and `if`, or `claim` alone.
- **`claim` beside `n` or `if`** checks the governor, with `.` as its raw
  value, exactly as on a value.
- **`claim` alone is a phrase guard.** It prints its phrase and fails when a
  check is false. It is the idiom for a phrase whose truth depends on a value
  the sentence never displays.
- **`#` stands for the governor's printed text**, so the number and its noun
  are one unit.
- **Selection sees the value as it prints.** Formatters run before the arm is
  chosen. The "one" arm is chosen only when the printed number is 1 and no
  decimals are shown; the "zero" arm only when it is 0. A depth of 1.2 printed
  by `.num` to zero decimals shows "1" and takes the singular; a value printed
  as "1.0" takes the plural, as English does.
- **`n` must be a single number.** A vector, a string or `NA` is an error that
  says to write `length(x)`. A count is never inferred from a length.
- **Arms are trimmed.** `\|` and `\#` mean the same as `|` and `#` (the visual
  editor adds those backslashes). A doubled `||` or `##` is the literal
  character.
- **The bracket is prose.** It can contain markdown, values and further spans.
  Every lint that applies to prose applies inside it.
- **Only the chosen arm is evaluated.** A value or span in an arm that is not
  chosen neither renders nor runs its checks.

**Agreement.** Whole arms are the plain idiom:

```
[# sample was taken | # samples were taken]{n="n"}
```

An inner span may instead inherit the enclosing governor with `n="."`:

```
[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}
```

`n="."` is legal only inside an `n` span. Agreement at a distance names the
governor again: `[was | were]{n="n"}`.

**A list and its verb** are written as a value and an agreement:

```
`r sites`{.and} [was | were]{n="length(sites)"} sampled.
```

### What is never a clag construct

- a bracket whose attribute block has none of `n`, `if`, `claim` (an ordinary
  Pandoc span, a link, a citation, a footnote)
- a code span that is not inline R
- anything inside a fenced block that is not executed: there, nothing is
  evaluated, including bare inline R (stock knitr would evaluate it)
- math, link targets and raw blocks; a `|` inside math, a code span or a link
  inside an arm does not split the arm

### Lookups and range phrases are plain R

A phrase chosen by key or by range is an ordinary function call in a value:
`` `r tier_lab(tier)` ``, `` `r trend(foo)` ``. `lookup()` builds a keyed
function from a named vector, takes a string or a factor (by label, never by
integer code) and errors on a key it does not hold. `brk()` builds a
range-to-phrase function from formulas
(`brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")`).
A named `lookup()` or `brk()` is a stipulation and belongs in the dictionary
(§4).

### In R code and in chunk options

The markup exists only in prose. In R code each construct has a function:

| Prose | R |
|---|---|
| `claim="…"` | `claim(x, …)` |
| `[…]{n="…"}` | `plural(n, "a person", "# people")` |
| `.num`, `.pct`, … | `num()`, `pct()`, … |

Chunk options are not prose and are never scanned. A caption that needs a
value or a governed span is written as prose in a Quarto figure div
(`::: {#fig-a}` … caption paragraph … `:::`), where both constructs work. A
clag construct inside a `fig-cap:` string is an error (§1, §5).

---

## 1. Runtime

### Four knitr hooks

clag attaches to a knit through hooks. There is no preprocessor.

| Hook | What clag does with it |
|---|---|
| `evaluate.inline` | does not evaluate; parks the code and returns a placeholder |
| `text` | receives each block of prose between chunks, resolves every construct in it, in textual order |
| `evaluate` | records every warning, message and error a chunk raises, then hides what the author asked to hide |
| `document` | at the end: checks that everything was evaluated, writes the logs, fails the render if any check failed |

**The `text` hook owns a block of prose.** Because inline code is parked
rather than evaluated, clag decides what runs and in what order: it picks an
arm first and evaluates only what that arm contains. Parking also gives every
expression an index within its block, and means a data value whose text
happens to look like a span is printed, never evaluated.

**Values are read at the right moment.** A block of prose is processed after
the chunks above it and before the chunks below it, so a construct sees the
same environment a stock inline expression would.

**Bare values print as stock knitr prints them.** A value with no attribute
block is evaluated through knitr's own default inline evaluator, so
`knit_print` methods and the `inline` hook apply as usual.

### Installing the hooks

- **Loading the package installs the hooks, idempotently**, whether or not a
  knit is in progress. A conditional install fails silently when the package
  was loaded before the knit began (an `.Rprofile`, or a session that called
  `library()` earlier).
- **`clag_setup()` does the same explicitly** and is what `use_clag()` writes
  into a document's setup chunk. It also reads the project configuration.
- **Hooks alone write nothing.** The condition log, the ledger and the
  failure report are written only in a project that has been set up with
  `use_clag()` (P10).

Prose above the chunk that loads the package is not processed. That is caught
by the two backstops below.

### Failing loudly

A construct that is valid markdown renders as plausible text when nothing
evaluates it, so silence has to be made impossible by other means.

1. **A value's attribute block is visible when unprocessed.** Without the
   hooks, `` `r depth`{.num} `` renders as `1.2{.num}`.
2. **The end-of-document check.** When the hooks are installed clag scans the
   input file and counts its constructs; the `document` hook compares that
   with what was evaluated and fails, naming each construct that was missed
   and its line.
3. **The `clag-check` Lua filter**, installed in the project by
   `use_quarto()`. After knitting, any span that still carries `n`, `if` or
   `claim`, or any text that still shows an attribute block, fails the render.
   This is the one backstop that works when the package was never loaded. It
   also catches a construct in a `fig-cap:` string. (The filter exits through
   `os.exit(1)`: under Quarto a Lua `error()` prints but does not fail the
   render.)

### Failed checks are collected

A failed check does not stop the knit. It is recorded (file, line, expression,
value), a visible marker is left in the text, and the `document` hook fails
the render once with every failure listed:

```
clag: 2 claims failed
  14-percentile-bands.qmd:412  "All 10 models rise"
      all(mod$rising) was FALSE
  14-percentile-bands.qmd:431  `r shift$n_down`
      . >= 10 was FALSE (value 7)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

- **In a book** a failing chapter would stop the project, so the failures are
  held until the end: a `pre-render` script opens a collection file, each
  chapter appends to it, and a `post-render` script prints one report for the
  whole book and exits non-zero. The chapters' output has been written by
  then; it carries the visible markers.
- **Draft mode** fails nothing: the markers appear in the output and the
  failures are written to a JSON file beside the document.
- **An expression that cannot be evaluated** (an unknown object, a syntax
  error) is reported the same way, naming the expression and its line.

### Positions

Every error and every log entry names the source file and the exact line of
the construct: the block's first line plus the newlines before the construct.
Placeholders contain no newlines, so the count is stable.

- The block's first line comes from `knitr:::knit_concord`, which is not
  exported. An integration test pins it (§11); without it clag falls back to
  the block's line range.
- Under Quarto, knitr reads an intermediate file with `{{< include >}}`
  already expanded. clag maps lines back through the includes, so an error in
  an included file names that file.

### Conditions

knitr writes chunk warnings and messages into the rendered document, or
discards them when the author hides them; neither reaches anyone. clag wraps
knitr's `evaluate` hook so that every warning, message and error is logged
with its chunk label and source expression, and then removes from the output
exactly what the author's `warning:` and `message:` settings would have
removed. The rendered document is identical to a stock render.

- **Inline conditions** are caught where the value is evaluated and logged
  with their line. They never appear in the document.
- **A severity list** decides which logged conditions fail the render (§7).
- **A chunk loaded from knitr's cache raises nothing**, so its conditions are
  logged only on the render that computed it.

### Caching and freeze

- **knitr's chunk cache is safe.** The prose hooks run on every render and
  check the cached values.
- **Quarto's `freeze` skips everything.** A frozen chapter is not executed, so
  none of its checks run, and freeze is keyed on the source file alone: a
  change in the data does not thaw it. Every executed document writes a stamp;
  the `post-render` script fails if a document with constructs has no stamp
  from this render. `verify()` never passes a chapter served from freeze.

### The scanner, and the two parsers

The runtime scanner is a small hand-written R function over the characters of
a prose block. It finds placeholders with their attribute blocks and brackets
with theirs, honours nesting and escapes, and skips the carve-outs of §0. It
costs about a third of a millisecond per construct.

The static lints (§5) and the commit gate (§6) do not use it. They read the
tree that Pandoc builds from the source with positions on every node
(`commonmark_x+sourcepos`, from the Pandoc that Quarto ships), in which a
value is a `Code` node with classes and attributes and a governed span is a
`Span`. That reader does not parse citations, so the lints carry their own
carve-out for citation brackets.

Two readers of one syntax can disagree. The fixture suite (§11) asserts that
they find the same constructs, and the end-of-document check compares them on
every render.

### Other output formats

The hooks run before Pandoc, so they do not depend on the output format.

---

## 2. What problem the harness solves

Ten failure modes in computational manuscripts, grouped by where the break
happens. The grouping matters: the first group corrupts the value before prose
is involved, and no amount of prose discipline detects it.

### A — the pipeline yields a wrong value

| # | Mode | Layer |
|---|---|---|
| A1 | **Silent success of a failed computation.** A join drops rows, a filter matches nothing, a model fails to converge, and the code carries on. | L6, §8 |
| A2 | **Stale or wrong input.** The computation is correct; the data it consumed is not the data intended. | §8 |

### B — the link between value and prose breaks

| # | Mode | Layer |
|---|---|---|
| B1 | **Silent deletion.** A `sed` or heredoc removes a paragraph, a section, or a value. What remains is valid markdown, renders clean, looks fine. | L1 |
| B2 | **Reversion to literal.** `` `r pcf(x)` `` becomes the literal `12`. Renders perfectly, forever, silently decoupled from the pipeline. | L2 |
| B3 | **Staleness.** What was rendered predates what it was rendered from, and everything downstream reports PASS. | L5, L6 |

### C — the prose is wrong about a correct value

| # | Mode | Layer |
|---|---|---|
| C1 | **Prose/value divergence.** The number updates on refit; the sentence still says "rose sharply" when the value went to −1. | L3, L5 |
| C2 | **Assertion never computed.** A set fact, ranking, direction or comparison is stated that was never calculated. | L2, L3 |
| C3 | **Misattribution.** Value and sentence are each correct but refer to different quantities. | none — tier 3 |
| C4 | **Definitional drift.** The same term carries different meanings in different chapters. | L10 |
| C5 | **Stale shape description.** A caption describes an object's contents, and the object changed. | L11 |

C2 is typically the largest class, and it is the one a number-focused scheme
misses entirely.

### The layers

| Layer | What it checks | Runs at |
|---|---|---|
| L1 | structural diff: removals are acknowledged | commit gate |
| L2 | claim tokens: numerals and claim words in prose | gate |
| L3 | checks: `claim=` and `claim()` | knit |
| L4 | cross-references and citations | gate |
| L5 | value ledger | knit |
| L6 | surfacing: conditions, unevaluated constructs, frozen chapters | knit |
| L8 | hygiene | gate |
| L10 | dictionary: keys resolve, shadowing rules | gate |
| L11 | figures and tables | gate + knit |

### The failure that shapes the design

Checks whose output nobody reads reproduce the failure they were built to
prevent. In the manuscript that motivated this package, both recorded
incidents were **signal-existed-but-unread**: knitr wrote the warning into the
document, the boundary-fit message was emitted, and both sat in plain sight
for weeks.

**Surfacing beats coverage.** Every layer must fail loudly at a checkpoint
someone passes through, or not exist. A printed count is not a checkpoint; a
count that may not rise is (§6).

---

## 3. Design principles

**P1 — Every check must have a machine-checkable ground truth.** A mechanism
that enforces *form* rather than *content* is satisfiable without thought.

**P2 — The machine observes and reports; the author acknowledges what is
destroyed.** The gate computes what a commit changed and says so. It asks for
a declaration only where something was removed, because that is the change
that is invisible afterwards.

**P3 — Prevention where anticipated, detection everywhere.** A check protects
a value someone thought to guard; the ledger catches drift in the ones nobody
guarded.

**P4 — Prefer categories with an external referent.** A check on a real fact
(does this key exist in the bib?) is worth several that check a shape.

**P5 — Keep category sets small.** Every category is a place to hide. This
governs *categories*, not *triggers*.

**P6 — Fast checks gate commits; slow checks gate tasks.** Anything needing a
knit cannot live in a git hook.

**P7 — A convention that is only documented will rot.** Every convention gets
a validator, a ratchet, or an explicit place on a human worklist.

**P8 — Generated and authored records never share a directory.**

**P9 — Partial coverage beats none, and every check declares its tier.**

| Tier | Mechanism | Behaviour | Example |
|---|---|---|---|
| 1 | **Hard rule** — decidable from source | fails the gate | no bare numerals |
| 2 | **Warning on new material** — heuristic trigger | prints, does not block | "these added sentences look like claims" |
| 3 | **Human read** — flagged, ranked, never adjudicated | worklist | misattribution |

Tier 2 scopes to newly added material, not to the corpus.

**P10 — Installation is always an explicit call.** Loading the package changes
only the R session. Every file the package places, and every file it writes
during a render, exists because a `use_*()` function was called.

**P11 — Every construct is markdown the toolchain already accepts.** The
visual editor must be able to round-trip it, the next parser must be able to
read it, and inline R that already exists must already count.

**P12 — Measure before building.** A layer is built when a prototype of it
reproduces findings from a real audit (§15).

---

## 4. Public API

### Checks

One mechanism, two spellings. In prose a check is the `claim` attribute, on a
value, on a governor, or alone on a phrase (§0). In R code it is a function:

```r
claim(x, <expression>, ...)
```

- **`x` is any type**, and `claim()` returns it visibly, so a value can be
  guarded in place inside a larger expression:
  `` `r trend(claim(foo, . > 0))` ``.
- **`.` pronoun** — `claim(shift$n_down, . >= 10)`.
- **Varargs, not `&&`** — each check is reported separately.
- **NSE** — checks are captured unevaluated. The error text *is* the feature.

`checkmate::test_*` is the right half of that package to use inside a check:
it returns a logical.

**A guarded bracket is still prose.** The L2 lint recurses into it, so a
numeral inside must be its own value. The idiom is to wrap the trigger word,
or the clause, and nest what is computed:

```
[All]{claim="all(mod$rising)"} `r nrow(mod)` models rise
[All `r nrow(mod)` models rise]{claim="all(mod$rising)"}
```

The hole that remains is a long bracket with one loose check. An advisory
lists guarded brackets longer than a token count.

**Design rule shipped in the docs:** a good bound is the widest range over
which the sentence stays honest. Too tight and it fires on every refit and
gets widened without thought; too loose and it is inert.

**A check that cannot fail is flagged statically**: one with no `.` and no
variable, such as `claim="TRUE"`.

### Literals

A number that cannot be computed is written as a literal value, and should
carry a check saying why it is trusted:

```
`r 10`{claim="cite(smith2020)"}
`r 2020`{claim="is_year(.)"}
```

A bare `` `r 10` `` is allowed. It is the deliberate escape hatch: nobody
types it by accident, and a rule demanding a check would be met with
`claim="TRUE"`. What a bare literal cannot do is hide: it is counted, the
count may not rise unnoticed (§6), and a computed value replaced by a literal
is reported at the commit.

| Check | For | What it verifies |
|---|---|---|
| `cite(key)` | a number quoted from a source | the key resolves in the bibliography |
| `is_year(.)` | a year not held in the dictionary | 1–4 digits, plausible range |

**Before writing a literal, ask why the number cannot be computed.** A project
constant goes in the dictionary; a count of things in the document gets
counted; an ordinal gets computed. Documents extend the set by defining their
own check function.

### Dictionary

```r
dict$era_split
dict_local$sites       # chapter override, deliberately a different accessor
```

In prose: `` The manual era ends in `r dict$era_split`. ``

`dict` is not a plain list. Its `$` errors on any name that is not an exact
key: no `NULL` on a typo, no partial matching. The key is a plain token in the
parsed expression, so a static lint verifies every read without running R.

**What belongs in a dictionary: stipulations, never derivations.** Things that
were *chosen* — era boundaries, band cuts, confidence levels, canonical
labels, the thresholds behind a `brk()`. Anything computable belongs in the
pipeline.

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

salinity_res:
  value: 0.01
  type: quantity
  unit: PSU
  definition: "Resolution at which the logger records salinity."
```

`decision:` is an optional pointer to wherever the project records decisions.
A `type: labels` entry is returned as a `lookup()`.

**Overrides.** A chapter may narrow a key, rarely, and a shadowing entry must
be read through a different accessor: `dict_local$sites`, never `dict$sites`.
A paragraph moved to a chapter with no local `sites` then errors, instead of
quietly changing meaning. `dict_local$x` with no local `x` is an error;
`dict$x` where the chapter defines a local `x` is an ambiguity error. Local
entries require a `why:` field.

**The pipeline reads the same dictionary.** A stipulation matters most where
it is computed with. `tar_dict()` exposes each key as its own target, so a
changed entry invalidates exactly the targets that read it.

**Two things the dictionary removes rather than checks:** the glossary is
generated from `definition:`, and a `type: quantity` entry prints with its
`unit:`.

### Formatters and plurals

Each shipped formatter is a class in prose and a function in R (`num()`,
`pct()`, `n_word()`, …), returning the text and the number as printed (§0).
`plural(n, ...)` is the function form of an `n` span. The collapse engine
behind `.and`, `.or` and the list formatters is `glue_vec()`, which is
exported.

---

## 5. Lints

Each ships as a function returning a structured result, and as an entry in the
gate. All static lints read one tree: Pandoc's, with source positions (§1).
What the lints skip is decided by node type (code, math, link target,
citation, raw block), not by pattern.

### L2 — claim tokens

**No bare claim tokens in prose.** Two kinds, two tiers.

- **Numerals — tier 1.** Every numeral in prose is a value. This also catches
  B2 mechanically: a value reverted to its literal *is* a bare numeral.

  A **numeral** is a standalone numeric token: digits, with an optional sign,
  separators, decimal part or `%`. A token that mixes letters and digits
  (CO2, PM2.5) is a name and is exempt.

  **A block can opt out, with a reason.** Methods text, legislation and
  quotations are dense with numbers that are not data claims:

  ```
  ::: {.clag-literal why="laboratory method, as specified in the SOP"}
  Samples were filtered through 0.45 µm membranes and stored at 4 °C.
  :::
  ```

  Opted-out blocks are counted, and the count may not rise unnoticed (§6).
- **Number words, quantifiers, extrema, direction words — tier 2.** "two",
  "all", "none", "only", "largest", "rose", "majority". These carry a data
  claim often but not reliably.

Tier 2 has two triggers:

1. **A claim word in the same sentence as a value.**
2. **A claim word in a newly added sentence with no value at all.**

A claim word inside a governed span is guarded and triggers neither. Both
print, neither blocks, and the list is capped: beyond a set number of added
sentences (a new chapter, a moved section) it prints a count.

**Value expressions.** Every numeric constant in a value expression that
carries no check is tier 2: an unchecked literal (`` `r 10` ``) is listed with
the suggestion to say why it is trusted; a constant buried in a computation
(`x * 100`) is listed separately and more quietly. Constants inside checks are
exempt.

### Canonical form

An attribute block not in canonical form (§0), an unknown class, an unknown
key, a wrong arm count for its key, and a clag construct in a chunk option are
tier-1 errors, found without running R.

### L4 — cross-references and citations

Book-wide by necessity: ids share one namespace.

- anchors resolve; duplicates discriminated
- dangling citation keys flagged
- a governed span whose text matches a defined reference-link label
  (`[foo]: url`), which Pandoc reads as a link
- orphan anchors: defined, never referenced

L4 checks that a reference *resolves*, not that the target still says what
the citing sentence claims. That is tier 3.

### L8 — hygiene

1. **Every section anchored, every chunk labelled.** A heading that contains
   a construct has no stable automatic id, so the explicit anchor matters
   twice.
2. **Targets hygiene** — every `tar_read()`/`tar_load()` names a target in the
   manifest.
3. **No chapter-local redefinition of a dictionary key.**
4. **No raw `round()` output in prose.**
5. **Seed discipline** — `sample`/`rnorm`/`runif` without `set.seed()`.
6. **Internal file links resolve.**
7. **Orphaned build artefacts.**
8. **No construct above the chunk that loads the package.**

### L10, L11

Covered under the dictionary (§4) and figures (§7).

---

## 6. The commit gate

### What the gate compares

| Node | Identity | What is compared |
|---|---|---|
| xref anchors | globally unique (L4 enforces) | exact: removed / added |
| `{#sec-…}` sections | stable across heading rewording | exact |
| labelled chunks | exact where labelled | exact |
| constructs with an `#id` | the id | exact, including their checks |
| other constructs | none | the multiset of their source text, per file |

Rewording a sentence leaves its constructs present; a `sed` that eats them
removes them from the multiset. The comparison is file-wide, so a move between
sections does not trip it.

### Removals are acknowledged; everything else is reported

**A commit that removes an anchored section, a labelled chunk, a referenced
anchor, or leaves a file with a net loss of constructs must say so**, with one
trailer line per removal:

```
Removed: 14-percentile-bands.qmd #sec-prov provisional band table
```

Nothing else is declared. Additions, edits and renames appear in the report
and need no trailer.

- **`commit-msg`, not `pre-commit`** — the message does not exist earlier.
- **The index, not the worktree** — the gate reads `git show :<file>`.
- **One executable, one report.** If the gate can tell that removing an anchor
  strands three references, it runs the scan and prints them. It never asks
  the author to go and run something.
- **The same check runs over a range of commits** (`verify(range = )`), which
  is how a pull request is checked: a local hook is neither installed by a
  clone nor proof of anything.
- **`--no-verify` bypasses it, and that is correct.** The aim is to catch
  unintended mistakes, not to stop active cheating.

```
commit-msg: removal not acknowledged

  14-percentile-bands.qmd  #sec-prov  removed

  2 values no longer appear anywhere in this file
      `r band_cut$lower`
      `r band_cut$upper`

  removing anchor `tbl-prov-bands` strands 3 references
      15-revised-rating.qmd:88   @tbl-prov-bands
      17-management-arms.qmd:204 @tbl-prov-bands
      17-management-arms.qmd:251 @tbl-prov-bands

  tier 2 — 1 added sentence reads as a claim with no guard:
      14-percentile-bands.qmd:96
        "Every creek in the revised set shifts down at least one band."
```

### The ratchet

Some costs are legal one at a time and corrosive in bulk: unchecked literals,
opted-out blocks, shadowed dictionary keys. Their counts live in a committed
baseline file. **A commit that raises a count fails unless it also raises the
baseline**, which puts the increase in the diff where a reviewer sees it.
Counts that fall lower the baseline automatically.

### The check-loosening report

The pressure runs toward widening a bound rather than rewriting a sentence.
**Every commit that changes a check lists the before and after**, computed
from the two trees. The same report lists a check **removed** from a construct
that still exists, and a **computed value replaced by a literal**. A construct
is matched across versions by its `#id` where it has one, and otherwise by its
section and expression; a check worth tracking through rewording is given an
id.

---

## 7. Knit-time: ledger, conditions, figures

### The value ledger (L5)

The `text` hook evaluates every value and every governed span, so it records
each one as it renders: expression, raw value, printed text, file, line,
section, and for a span the arm chosen. Commit the ledger; diff it on
re-render.

**Format.** One JSON-lines file per source file, under `generated/ledger/`
(P8). Each line is keyed on the construct's `#id`, or on section anchor,
source text and occurrence index within the section. Line numbers are not
stored. Numbers are stored to a fixed number of significant figures alongside
the printed text, so two machines produce the same file.

**Three states, not two.** A value is *unchanged*, *changed*, or *not
re-rendered*: its chapter was not rendered, or was served from freeze, since
something it depends on changed. The ledger records which pipeline targets
each chapter reads, from `targets`. `verify()` reports "chapter 17: 34 values
not re-rendered since `fit_reband` changed." No partial render passes as
clean.

**Review, not a diff.** `ledger_review()` shows each change as the sentence
before and after, ranked, and records acceptance:

- **Structural, no language needed** — sign flip, order-of-magnitude change,
  crossing zero, crossing 1.0, crossing a dictionary threshold, a governed
  span choosing a different arm. Must-reads.
- **Claim-word proximity** — a value next to a claim word moved.

Both families are heuristics that narrow a human read. Nothing here verifies
English against a number.

### Conditions (L6)

The condition log (§1) is machine-readable and sits beside the ledger. A
severity pattern list decides what fails the render. It ships with the
model-fit messages that arrive as messages rather than warnings (`lme4`'s
singular fit, `glmmTMB`'s non-positive-definite Hessian). Failed checks,
unevaluated constructs and fatal conditions are reported distinctly from
ordinary knit errors, because their fix differs in kind: rewrite prose, fix
the document's setup, or fix code.

### Figures and tables (L11)

- **Presence, static:** every figure has a label, a caption and alt text;
  every table a caption.
- **Captions are prose.** A caption written in a figure div is scanned like
  any paragraph: its numerals must be values and it can carry checks. A count
  stated in a caption is guarded the way any count is.
- **Free scales are flagged** (tier 2): they make panels look comparable that
  are not.

The package does not write alt text and does not judge whether alt text
describes the figure.

---

## 8. Pipeline patterns

Every other layer protects the prose and assumes the numbers are right. A1 and
A2 say that is the assumption most likely to have already failed. The package
adds no pipeline layer of its own; it documents the patterns and supplies the
one function they share.

- **`claim()` works anywhere in R**, including inside a target, and reports
  the same way.
- **Joins state their relationship**: `dplyr`'s `relationship =` and
  `unmatched = "error"`.
- **Convergence is asserted where the model is fitted**
  (`claim(fit, !lme4::isSingular(.))`), so the condition log's pattern list is
  a backstop rather than the only defence.
- **Inputs are file targets**, so `targets` records what bytes a value came
  from.
- **Stipulations come from the dictionary** (§4).

---

## 9. Installers and shipped assets

All under P10: explicit calls, each saying what it will write.

| Function | Writes |
|---|---|
| `use_clag()` | everything below, with a summary first |
| `use_setup()` | the `clag_setup()` line in each document's setup chunk; the project config |
| `use_quarto()` | the `clag-check` Lua filter as a project extension; the `pre-render` and `post-render` scripts |
| `use_hooks()` | the `commit-msg` shim calling the gate; the baseline file |
| `use_dictionary()` | dictionary skeleton and schema |
| `use_agent_docs()` | agent-facing conventions and the Claude skill |

`inst/` holds the hook template, the Lua filter, the render scripts, the
dictionary schema, the default claim-word lexicon and severity list, and the
Claude skill (never loosen a check to clear a failure; write removals in the
trailer; `dict_local` rules).

### Adoption helpers

- **`recall_check()`** — given recorded findings and a pre-remediation commit,
  runs a lint against the historical state and reports what fraction of the
  findings it reproduces.
- **`dict_seed()`** — harvests candidate dictionary keys by finding constants
  defined in more than one chapter.
- **`status()`** — reports which layers are installed, which are configured
  off, and what the next step is.

### Version pinning

The project config records the package version, and `verify()` warns on
mismatch.

---

## 10. `verify()`

One entry point. Runs, in order:

```
L4 → L2 → canonical form → L10 → L1 → L8 → ratchet
   → render with freeze disabled (L6) → L3 + L11 → L5
```

The git hook calls the pre-render subset as a single tool. Each layer is
individually switchable in config; `verify()` reports which were skipped and
why.

Rendering itself needs no wrapper: `quarto render`, the editor's Render
button and `rmarkdown::render()` all run the hooks.

---

## 11. Tests

`testthat`, seeded by the scanner and the `text` hook, then `claim()`,
`dict$`, `dict_local$`, `cite()`, `is_year()`. Then the lints, each against a
fixture pair.

- **The syntax fixtures are a table**: source, setup, expected text or
  expected error with its line. Each case is rendered under Quarto and under
  rmarkdown and compared. The spike's table (§13) is the seed.
- **Conformance.** For every fixture, the runtime scanner and the Pandoc tree
  must find the same constructs at the same positions.
- **Round trip.** Every fixture, passed through Pandoc's markdown writer, must
  render to the same text.
- **Pinned internals.** One test each for `knitr:::knit_concord`, the
  signature of knitr's `evaluate` hook, Quarto's `.QuartoInlineRender`
  wrapper, and a Lua `os.exit` failing a Quarto render. Each is a place where
  an upgrade could change behaviour silently.
- **Stock parity.** A document with no attribute blocks renders byte-identical
  with and without the hooks.

---

## 12. What the package deliberately does not do

- **Judge prose.** No layer verifies English against a number.
- **Write alt text or captions.**
- **Catch misattribution (C3).**
- **Hold a project's constants.** The dictionary schema ships; the values do
  not.
- **Define its own syntax.** No construct needs a compile step or a custom
  engine.
- **Keep registers.** Decision logs, task registers and status conventions are
  a project's own; the dictionary's `decision:` field points at them.
- **Lint prose style (L7).** Vale does that and needs no wrapper to run on a
  rendered file.
- **Wrap a data-validation package (L12).** §8.
- **Install itself.** P10.

---

## 13. Verification status

Everything here was run with throwaway stand-ins, on macOS, with knitr 1.51
and Quarto 1.11.9 (Pandoc 3.10). "Both" means under `quarto render` and under
`rmarkdown::render()`.

| Fact | Run under |
|---|---|
| The `text` hook receives each prose block, in order, with the environment of that point in the document | both |
| Parked inline code: unchosen arms never run; data that looks like a span is printed | both |
| 108 syntax cases: values, formatters, checks, every arm rule, escapes, nesting, `n="."`, carve-outs, spans in headings, lists, quotes, table cells, footnotes, divs | both (two cases Quarto-only) |
| Every error names the exact source line | both |
| Bare values print as stock knitr, 24 kinds of value | both |
| Quarto's `` `{r} x` `` form, bare and with attribute blocks | Quarto |
| A caption written as prose in a figure div resolves, and the figure is numbered and referenced | Quarto |
| Constructs in an included file resolve | Quarto |
| docx and Typst output | Quarto |
| Failed checks collected, one report, exit 1, no output written; draft mode | both |
| Book: failures from all chapters in one report through pre/post-render scripts | Quarto |
| Hidden warnings and messages logged, output byte-identical to stock | both |
| End-of-document check catches a construct above the setup chunk | both |
| `clag-check` filter fails the render when the hooks are absent, passes when present | both |
| Hooks installed on package load, including when loaded before the knit | both |
| Chunk cache: checks still run on cached values | both |
| `freeze: auto`: checks do not run; the stamp mechanism detects it | Quarto |
| Pandoc's markdown writer keeps values and governed spans as constructs, rewriting them to canonical form with `\|` and `\#` | Pandoc |
| Pandoc's position-tracking reader parses values and spans into nodes with line and column | Pandoc |
| Knit time with 4,000 constructs: about 1.5 s against 0.2 s stock | knitr |

Not run: Windows; the Render button in RStudio or Positron; running chunks
interactively with the hooks loaded; LaTeX PDF; bookdown; nested includes;
knitr child documents.

Quarto 2 (experimental, 0.43.0): its parser accepts a governed span whose key
has a quoted value, and rejects a key written before a class and an unquoted
`.`. Values with attribute blocks, and execution, were not tested under it.

---

## 14. Open questions

1. **Windows.** The fixture runner is portable and has not been run there. The
   placeholder characters are private-use Unicode and exist only in memory.
2. **The editors.** Whether the Render button, chunk-by-chunk execution and
   the inline preview behave with the hooks loaded.
3. **`knitr:::knit_concord`.** Exact lines depend on it. Ask for an exported
   accessor, or accept the pin.
4. **Disabling freeze for `verify()`.** Editing the file, `execute: freeze:
   false`, deleting `_freeze` and a single-file render all re-execute; there
   is no command-line flag. The mechanism `verify()` uses is undecided.
5. **Quarto 2 execution.** It hands knitr text re-serialised from its parsed
   tree. Whether the hooks then see the constructs unchanged is untested.
6. **`tar_dict()`.** Per-key dictionary targets are a proposal, not yet tried
   against `targets`.
7. **Matching a construct across versions** when it has no `#id` is a
   heuristic. How often the check-loosening report mismatches is unmeasured.

---

## 15. Build order

Each stage leaves something usable on its own.

**Stage 0 — measure.** `recall_check()` and rough prototypes of the candidate
lints, run against the audit corpus of the companion plan. The result ranks
the layers and can remove one from this list (P12).

**Stage 1 — the prose core.** Usable alone.

- the scanner and the four hooks
- values, checks, formatters, governed spans; `claim()`, `plural()`,
  `lookup()`, `brk()`, `cite()`, `is_year()`
- collected failures, exact positions, draft mode
- the condition log and severity list
- the end-of-document check and the `clag-check` filter
- `use_setup()`, `use_quarto()`
- the syntax fixtures, conformance and pinned-internals tests

**Stage 2 — dictionary and ledger (L10, L5).**

- `dict`, `dict_local`, the schema, the generated glossary, `tar_dict()`
- the ledger: emit, three states, `ledger_review()`

**Stage 3 — static lints (L2, L4, L8, L11).**

- the Pandoc-tree reader and the citation carve-out
- L2 with the opt-out block; the canonical-form lint; L4; L8; figure presence

**Stage 4 — the commit gate (L1).**

- the structural diff and the `Removed:` trailer
- the ratchet and the check-loosening report
- `verify()` as the single entry point, including the commit-range form

Stage 2 comes before stage 3 because L2's tier-1 rule sends constants to the
dictionary: the lint cannot be switched on until there is somewhere for them
to go.
