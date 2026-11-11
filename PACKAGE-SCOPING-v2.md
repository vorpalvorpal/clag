# `weft` — package scoping, v2

**Date:** 2026-11-11
**Status:** scoping. The syntax and the runtime are at spec level and were
exercised with throwaway stand-ins (§13 says exactly what was run). Open points
are in §14. Integration facts were checked against knitr 1.51 and Quarto
1.11.9 (Pandoc 3.10) on macOS.

`weft` lets a manuscript's prose carry computed values, and wording that
depends on them, and adds deterministic checks for computational manuscripts.
It has no users and no backwards-compatibility obligations. Portable by
design: the package knows about knitr, Quarto, Pandoc, `targets` and git, and
nothing about any particular book. The repository and the existing code still
carry the old name, `clag`.

The package is two layers. The **prose core** (the syntax of §0 and the
runtime of §1) makes a computed value cost what knitr inline code already
costs, and makes a checked value cost one function call more. The **integrity
harness** (checks, dictionary, lints, commit gate, ledger) is only socially
sustainable because of that: a rule like "every numeral is a computed value"
survives contact with authors only when writing one is nearly free, and when
the inline R a document already contains counts without being rewritten.

Every weft construct is markdown that knitr, Pandoc and Quarto already accept.
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

`{ATTRS}` is Pandoc's own attribute syntax: an optional `#id`, classes, and
`key="value"` pairs. weft gives meaning to three keys (`n`, `if`, `sign`), to
its own classes (formatters and text classes), and to a short list of renderer
keys (`sep`, `last`, `trunc`).

**weft accepts every attribute block Pandoc accepts**: id, classes and keys in
any order; values double-quoted, single-quoted or unquoted. Pandoc's markdown
writer, and therefore the visual editor, rewrites a block to id, then classes,
then keys, with every value double-quoted. The examples here use that form,
with single quotes for R strings inside a value (`{if="tier == 'sev'"}`). The
gate and the ledger compare parsed attributes, never text.

Meaning never depends on the order in which things are written inside the
block. Formatters run on the evaluated value; then the arm is chosen and `#`
filled; then text classes act on the result.

**Classes are of three kinds.**

- **Formatters** act on the value, left to right (`.num`, `.pct`, `.word`, …).
- **Text classes** act on the final text (`.cap`, `.a`, `.strong`, `.em`),
  in a fixed order: the article, then the capital, then emphasis.
  `.strong` and `.em` emit markdown emphasis, because Pandoc gives those class
  names no meaning.
- **Everything else is passed through.** Any class or key weft does not own,
  and any `#id`, is put on a Pandoc span around the output. So `.smallcaps`,
  `.underline` and `.mark` (the three classes Pandoc itself turns into
  formatting in every format), `custom-style="…"` (Word) and CSS classes
  (HTML) work on a construct:
  `` `r x`{.num .smallcaps custom-style="Key figure"} ``.

An unknown class is therefore not an error. A class within one edit of a
formatter name (`.nmu`) is (§5). A formatter on an `if` span, which has no
number to format, is an error too.

### Values

```
`r x`                                bare value
`r claim(n_gap, . > 10)`             checked value
`r claim(x, . >= 10, . < 99)`        several checks
`r x`{.num}                          one formatter
`r n`{.no .word}                     formatters, left to right
`r claim(depth, . > 0.5)`{.num}      check and formatter
`r k`{.word .cap}                    formatter and text class: "Twelve"
`r sites`{.or}                       "a, b or c"
`r sites`{sep="; "}                  renderer argument
`r sites`{.and trunc="3"}            "a, b, c and 4 others"
`r sites`{.ul}                       bullet list
```

- **A bare value is plain knitr inline code and prints exactly as knitr prints
  it.** A document that already uses inline R is already a weft document.
  Quarto's `` `{r} x` `` form is equivalent.
- **The attribute block must touch the closing backtick.**
- **A check is written in the expression, with `claim()`** (§4). `claim()`
  returns the raw value, so the formatters apply after it and a check always
  sees the value as evaluated.
- **Emphasis is `.strong` or `.em`, or ordinary markdown around the
  construct**: `` **`r x`{.num}** ``.

Shipped formatters:

| Class | Prints |
|---|---|
| `.num`, `.pct`, `.sci` | a number, to the document's defaults |
| `.word` | a spelled numeral ("three") |
| `.count` | a word below ten, digits from ten up ("three sites", "12 sites"); the threshold is a document default |
| `.ord` | an ordinal ("3rd") |
| `.no` | zero as "no" |
| `.p` | a p-value ("p < 0.001", never "p = 0.000") |
| `.range` | a length-2 value as a range ("3–5") |
| `.date` | a date, in the document's default format |
| `.and`, `.or` | a vector collapsed with a final "and" / "or" |
| `.pairs` | a named vector as "A (1.2), B (3.4) and C (5.6)" |
| `.ul`, `.ol`, `.dl` | a bullet, ordered or definition list |

Shipped text classes:

| Class | Does |
|---|---|
| `.cap` | capitalises the first letter ("Twelve sites failed") |
| `.a` | puts "a" or "an" before the text, by sound ("an 11-year record", "a 12-year record") |
| `.strong`, `.em` | markdown emphasis |

- **`.range`** prints one number when both ends print the same, writes
  "−5 to −3" when either end is negative, and gives a unit once ("3–5 m").
- **`.pairs`** takes names and values from one object, so their order cannot
  drift apart. Formatters before it act on the values:
  `` `r means`{.num .pairs} ``.
- **`trunc`** is a renderer key for the collapsing formatters: the number of
  items shown before "and N others".

A project registers its own formatter (a function, optionally bundling options
such as significant figures or a unit) under a class name. A project name may
not shadow a shipped one. Dictionary quantities print with their unit (§4).

Each formatter returns the **text** and the **number as printed**: the number,
a flag for whether decimals are shown, and a **relation** (`=`, `<`, `>`,
`≈`). "< 0.001" is a bound, not a value, and arm selection, the ledger and
the reports all need to know that. In a chain each formatter receives the
previous result. One that rounds (`.num`, `.pct`) sets the number; one that
only rewords (`.word`, `.count`, `.no`) passes the number through.

### Governed spans

A bracket followed immediately by an attribute block that carries one of three
keys. The bracket holds one or more **arms** separated by `|`.

| Key | The value must be | Arms | Chosen |
|---|---|---|---|
| `n` | a single number | 1 | always (a template for `#`) |
| | | 2 | one / other |
| | | 3 | zero / one / other |
| | | 4 | zero / one / two / other |
| `if` | one or more conditions, each a single `TRUE` or `FALSE` | 2 | true / false; either may be empty |
| | | 1 | always (a guard): a `FALSE` is a failed claim |
| `sign` | a single number | 2 | positive / negative |
| | | 3 | positive / negative / zero |

```
[a person | # people]{n="n"} responded.
[no people | a person | # people]{n="n"} responded.
[neither site | one site | both sites | all # sites]{n="n"}
file[ | s]{n="n"}
Invertebrate numbers [rose | fell]{if="slope > 0"}.
Council will need to [add more sampling sites | ]{if="n_gap > 10"}.
Council will need to [add more sampling sites]{if="n_gap > 10"}.
[All]{if="all(mod$rising)"} `r nrow(mod)` models rise.
Abundance [rose | fell | did not change]{sign="d"} by `r abs(d)`{.pct}.
[# metre | # metres]{.num n="claim(depth, . > 0.5)"}
[# site | # sites]{.range n="c(lo, hi)"}
```

- **The key says what kind of governor it is.** The arm counts allowed for
  each key are fixed, so a wrong count is found from the source without
  running R. A span carries exactly one of `n`, `if` and `sign`.
- **A case with no arm fails the render.** A one-arm `if` whose value is
  `FALSE` and a two-arm `sign` at zero are failed claims, collected and
  reported like any other (§1).
- **`if` takes a comma-separated list of conditions**, read as R reads an
  argument list: `if="n_gap > 10, n_sites >= 3"`. All must be `TRUE` for the
  true arm, as in `dplyr::filter()`. In a guard each failing condition is
  reported separately, as the checks of a `claim()` are. `&&`, `||` and
  brackets remain for anything a list cannot say.
- **A one-arm `if` is a phrase guard.** It always prints its phrase, and fails
  when a condition is `FALSE`. It is the idiom for a phrase whose truth depends
  on a value the sentence never displays. The same phrase with an empty second
  arm (`[add more sampling sites | ]`) is optional text, and fails nothing.
- **A governor is checked with `claim()` in its expression**, exactly as a
  value is.
- **`sign` judges zero on the number as printed.** A change that prints as
  "0.0%" takes the zero arm, whatever its raw value. Inside a `sign` span `#`
  is the magnitude as printed, without its sign.
- **`#` stands for the governor's printed text**, so the number and its noun
  are one unit.
- **Selection sees the value as it prints.** Formatters run before the arm is
  chosen. The "one" arm is chosen only when the printed number is 1 and no
  decimals are shown; the "zero" arm only when it is 0, and the "two" arm only
  when it is 2. A depth of 1.2 printed by `.num` to zero decimals shows "1"
  and takes the singular; a value printed as "1.0" takes the plural, as
  English does. A number printed as a bound ("< 1") takes the "other" arm.
- **`n` must be a single number.** A vector, a string or `NA` is an error that
  says to write `length(x)`. A count is never inferred from a length. The one
  exception is a length-2 value with `.range`: `#` is then the range, and the
  span takes the plural (CLDR's rule for English ranges) unless the range
  collapses to a printed 1.
- **Arms are trimmed.** `\|` and `\#` mean the same as `|` and `#` (the visual
  editor adds those backslashes). A doubled `||` or `##` is the literal
  character.
- **The bracket is prose.** It can contain markdown, values and further spans.
  Every lint that applies to prose applies inside it.
- **Only the chosen arm is evaluated.** A value or span in an arm that is not
  chosen neither renders nor runs its checks.

**Plural forms follow the document's language.** The arm counts in the table
are English's. The general rule: one arm for each plural form the language
has, in CLDR's order (zero, one, two, few, many, other); then, optionally, a
leading arm for exactly zero; then one, after the singular, for exactly two.

| `lang` | Plural forms | Arms allowed | The longest reads |
|---|---|---|---|
| English | one, other | 2, 3, 4 | zero / one / two / other |
| Polish | one, few, many, other | 4, 5, 6 | zero / one / two / few / many / other |
| Arabic | zero, one, two, few, many, other | 6 | its own six forms |

- **"One" is the language's singular form, not the number 1.** In English it
  is exactly 1 with no decimals shown. In Russian 21 takes it; in French so
  do 0 and 1.5. Forms are judged on the number as printed.
- **The arm count is checked against `lang` from the source.** A count the
  language does not allow is a construct error, so an arm can never be one
  that the language never selects.
- **English is shipped.** Under a `lang` whose rules are not shipped, an `n`
  span with more than one arm is an error; English rules are never applied to
  another language. The rules are a small table generated from CLDR.
- **Other exact numbers are R.** "All three", "a dozen": `of_n()` (§4), a
  `lookup()` or a nested `if`.

**Agreement.** Whole arms are the plain idiom:

```
[# sample was taken | # samples were taken]{n="n"}
```

An inner span may instead inherit the enclosing governor with `n="."`:

```
[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}
```

`n="."` is legal only inside an `n` span.

**Agreement at a distance uses an `#id`.** An id names one printed occurrence
of a value. A later span refers to it with `#` and the id as the whole value
of `n` or `sign`:

```
Depth was `r claim(depth, . > 0.5)`{#d .num} m. … The [core | cores]{n="#d"} …
```

- **The value is evaluated once and its checks run once.** The referring span
  re-evaluates nothing.
- **The formatter travels.** With no classes of its own, the referring span
  uses the number as it was printed there, so agreement follows what the
  reader saw (1.04 printed as "1" takes the singular). With formatters of its
  own, it formats the raw value afresh.
- **`[#]{n="#d"}` prints the value again.**
- **The id must be defined earlier in the same document.** An unknown id, or
  one defined further down, is a construct error found from the source. A
  book chapter cannot refer to another chapter's id.
- **An id is defined once.** A duplicate is a construct error. An id defined
  inside an arm exists only when that arm is chosen, so it can be referred to
  only from inside the same arm.
- **A back-reference is the whole value of the key.** `#` begins a comment in
  R, so `"#d"` can never be mistaken for an expression.
- **An R variable names a value; an id names a printed occurrence.** Compute
  with the variable, agree with the id. Naming the governor again
  (`[was | were]{n="n"}`) still works, and agrees with the raw value.

The id also serves as the construct's identity for the ledger and the gate
(§6, §7), and is passed through to the output as an anchor.

**A list and its verb** are written as a value and an agreement:

```
`r sites`{.and} [was | were]{n="length(sites)"} sampled.
```

### What is never a weft construct

- a bracket whose attribute block has none of `n`, `if`, `sign` (an ordinary
  Pandoc span, a link, a citation, a footnote)
- a code span that is not inline R
- anything inside a fenced block that is not executed: there weft changes
  nothing. Bare inline R is evaluated exactly as stock knitr evaluates it, and
  an attribute block after it is left as text
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

The markup exists in prose. In R code each construct has a function, and a
check is the same function in both places:

| Prose | R |
|---|---|
| `[…]{n="…"}` | `plural(n, "a person", "# people")` |
| `.num`, `.pct`, … | `num()`, `pct()`, … |
| `claim(x, …)` in the expression | `claim(x, …)` |

**Captions in chunk options are prose.** A construct works in `fig-cap`,
`fig-alt`, `fig-subcap` and `tbl-cap` under Quarto, and in `fig.cap` and
`fig.alt` under rmarkdown. The caption is resolved after its chunk has run,
so it sees objects made in the same chunk (§1):

````
```{r}
#| label: fig-depth
#| fig-cap: |
#|   Depth at [a site | # sites]{n="n_sites"}, mean `r depth`{.num} m.
n_sites <- nrow(d)
plot(d)
```
````

- **A caption with a construct is written as a YAML block scalar**
  (`fig-cap: |`). An unquoted scalar is cut at ` #`, silently; that is a
  construct error (§5).
- **Not supported:** rmarkdown's `tab.cap`, and `!expr` inside `fig-subcap`.
- **A caption can also be prose in a Quarto figure or table div**
  (`::: {#fig-a}` or `::: {#tbl-a}` … caption paragraph … `:::`), where both
  constructs work as in any paragraph.

**`weft_str()` renders a markup string** (exported provisionally). It is for
the text slots no chunk option reaches: `ggplot2::labs()`, a `gt` footnote or
column label, `knitr::kable(caption = )`. The lints read a literal string
passed to it as prose.

**A numbered table takes its caption from `tbl-cap`.** `gt` drops a caption
set with `tab_caption()` from Word output, so that form is not portable.

---

## 1. Runtime

### The hooks

weft attaches to a knit through knitr's hooks. There is no preprocessor.

| Hook | What weft does with it |
|---|---|
| `evaluate.inline` | does not evaluate; parks the code and returns a placeholder |
| `text` | receives each block of prose between chunks, resolves every construct in it, in textual order |
| `evaluate` | records every warning, message and error a chunk raises, then hides what the author asked to hide |
| `document` | at the end: checks that everything was evaluated, writes the logs, fails the render if any check failed |
| `opts_hooks` on the caption options | turns a caption string that contains a construct into a call, which knitr evaluates after the chunk |
| `chunk` | removes a `NULL` `tbl-cap`, which Quarto would otherwise forward to every cell |

**The `text` hook owns a block of prose.** Because inline code is parked
rather than evaluated, weft decides what runs and in what order: it picks an
arm first and evaluates only what that arm contains. Parking also gives every
expression an index within its block, and means a data value whose text
happens to look like a span is printed, never evaluated.

**Values are read at the right moment.** A block of prose is processed after
the chunks above it and before the chunks below it, so a construct sees the
same environment a stock inline expression would.

**Bare values print as stock knitr prints them.** A value with no attribute
block is evaluated through knitr's own default inline evaluator, so
`knit_print` methods and the `inline` hook apply as usual.

**Captions are evaluated after their chunk.** The caption options are added
to knitr's `eval.after` list, so a caption string is resolved once the chunk's
code has run, in the chunk's environment. An error in a caption names the
chunk label and the option. Figure and table numbering and cross-references
are unaffected.

**`claim()` behaves by context.** Under the hooks a failed check is collected
and the value is returned, so the render continues to the single report at
the end. Anywhere else (a pipeline, plain R, a document in which the hooks
never installed) it stops at once. A check on a value therefore runs even
when nothing else of weft does.

### Installing the hooks

- **Loading the package installs the hooks, idempotently**, whether or not a
  knit is in progress. A conditional install fails silently when the package
  was loaded before the knit began (an `.Rprofile`, or a session that called
  `library()` earlier).
- **`weft_setup()` does the same explicitly.** It also reads the project
  configuration.
- **Hooks alone write nothing.** The condition log, the ledger and the
  failure report are written only in a project that has been set up with
  `use_weft()` (P10).

There are three places to activate a document. **The first two are the
recommended routes**: they run before any prose is read, so a construct in the
first paragraph resolves. A setup chunk also works.

| Where | What is written | Covers |
|---|---|---|
| the document's front matter | `knitr:` / `opts_knit:` / `weft: !expr weft::weft_setup()` | one document, under Quarto and rmarkdown |
| `.Rprofile` at the project root | `weft::weft_setup()` | every document in a Quarto project, wherever it sits |
| a setup chunk | `library(weft)` | the prose below that chunk |

- **The front-matter form works because R evaluates `!expr` when it reads the
  document's own YAML.** The same line in `_quarto.yml` is passed through
  unevaluated and activates nothing, silently, so there is no `_quarto.yml`
  route. `params:` with `!expr` also works.
- **`use_weft()` writes the `.Rprofile` line** in a Quarto project. Quarto
  starts R in the project root even for a document in a subdirectory. A
  missing package is then a render error.
- **Under rmarkdown the project-wide form is `_output.yml`** naming a weft
  output format that carries the hooks.
- **Inline R in a YAML field is not a route.** knitr fetches its inline
  evaluator once for the first block, so hooks installed from inside that
  block miss the values in it.

Prose above a setup chunk that loads the package is not processed. That is
caught by the two backstops below.

### Failing loudly

A construct that is valid markdown renders as plausible text when nothing
evaluates it, so silence has to be made impossible by other means.

1. **A value's attribute block is visible when unprocessed, and its check
   still runs.** Without the hooks, `` `r depth`{.num} `` renders as
   `1.2{.num}`, and a `claim()` in the expression stops the knit when it
   fails.
2. **The end-of-document check.** When the hooks are installed weft scans the
   input file and counts its constructs; the `document` hook compares that
   with what was evaluated and fails, naming each construct that was missed
   and its line.
3. **The `weft-check` Lua filter**, installed in the project by
   `use_quarto()`. After knitting, any span that still carries `n`, `if` or
   `sign`, or any text that still shows an attribute block, fails the render.
   This is the one backstop that works when the package was never loaded. It
   also catches an unresolved construct in a caption. (The filter exits through
   `os.exit(1)`: under Quarto a Lua `error()` prints but does not fail the
   render.)

### Failed checks are collected

A failed check does not stop the knit. It is recorded (file, line, expression,
value), a visible marker is left in the text, and the `document` hook fails
the render once with every failure listed:

```
weft: 2 claims failed
  14-percentile-bands.qmd:412  "All 10 models rise"
      all(mod$rising) was FALSE
  14-percentile-bands.qmd:431  `r claim(shift$n_down, . >= 10)`
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
- **A construct error stops the render at once**: a wrong arm count, an
  unknown id, a near-miss class, a governor of the wrong type. These are the
  errors the lints find from the source (§5), and nothing after one can be
  trusted.
- **A failed guard is reported by its phrase**, with each failing condition.

### Positions

Every error and every log entry names the source file and the exact line of
the construct: the block's first line plus the newlines before the construct.
Placeholders contain no newlines, so the count is stable.

- **The block's first line is found by searching for the block in the file
  knitr is reading**, forward from the end of the previous block. The `text`
  hook receives each block in order; weft puts the parked expressions' source
  back and matches whole lines, requiring a chunk boundary on each side, so a
  block that repeats a line of the chunk above it cannot match there. Only
  exported functions are used.
- A block that cannot be found is reported with the end of the previous block
  as a lower bound. `knit(text = )` has no file, so its positions are relative
  to the block.
- knitr's own unexported record of block positions agreed with the search on
  every block tested (§13). weft does not depend on it.
- Under Quarto, knitr reads an intermediate file with `{{< include >}}`
  already expanded. weft maps lines back through the includes, so an error in
  an included file names that file.

### Conditions

knitr writes chunk warnings and messages into the rendered document, or
discards them when the author hides them; neither reaches anyone. weft wraps
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
  change in the data does not thaw it. Every executed document writes a stamp.
  After an ordinary render the `post-render` script reports each document
  with constructs that was served from freeze: how many checks did not run,
  and when they last did. It fails nothing. `verify()` fails on a chapter
  served from freeze.

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
carve-out for citation brackets. It does not hold chunk options either, so
captions written there are read in a second pass over the chunk headers.

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
| L3 | checks: `claim()` and one-arm `if` | knit |
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
baseline that a commit must change in order to add to it is (§6).

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
visual editor must be able to round-trip it, and inline R that already exists
must already count.

**P12 — Measure before building.** A prototype of each layer is run against
the findings of a real audit, and the result ranks the layers (§15). The
evidence is suggestive, not decisive: it comes from one corpus, and the
package is for more than one project. It does not remove a layer.

---

## 4. Public API

### Checks

One mechanism: a function, the same in a value, in a governor and in a
pipeline.

```r
claim(x, <expression>, ...)
```

```
`r claim(n_gap, . > 10)`
`r claim(depth, . > 0.5)`{.num}
[# metre | # metres]{.num n="claim(depth, . > 0.5)"}
```

- **`x` is any type**, and `claim()` returns it visibly and unchanged, so a
  value can be guarded in place inside a larger expression
  (`` `r trend(claim(foo, . > 0))` ``) and formatters apply to the raw value
  after the check.
- **`.` pronoun** — `claim(shift$n_down, . >= 10)`.
- **Varargs, not `&&`** — each check is reported separately.
- **NSE** — checks are captured unevaluated. The error text *is* the feature.
- **Collected under the hooks, immediate elsewhere** (§1).

`checkmate::test_*` is the right half of that package to use inside a check:
it returns a logical.

**A phrase is guarded by a one-arm `if`** (§0). It has no function form,
because the guarded words must stay prose.

**A guarded bracket is still prose.** The L2 lint recurses into it, so a
numeral inside must be its own value. The idiom is to wrap the trigger word,
or the clause, and nest what is computed:

```
[All]{if="all(mod$rising)"} `r nrow(mod)` models rise
[All `r nrow(mod)` models rise]{if="all(mod$rising)"}
```

The hole that remains is a long bracket with one loose check. An advisory
lists guarded brackets longer than a token count.

**Design rule shipped in the docs:** a good bound is the widest range over
which the sentence stays honest. Too tight and it fires on every refit and
gets widened without thought; too loose and it is inert.

**A check that cannot fail is flagged statically**: one with no `.` and no
variable, such as `claim(x, TRUE)` or a one-arm `if="TRUE"`.

### Literals

A number that cannot be computed is written as a literal value, and should
carry a check saying why it is trusted:

```
`r claim(10, cite(smith2020))`
`r claim(2020, is_year(.))`
```

A bare `` `r 10` `` is allowed. It is the deliberate escape hatch: nobody
types it by accident, and a rule demanding a check would be met with
`claim(10, TRUE)`. What a bare literal cannot do is hide: each one is an item
in the baseline, a new one fails the commit until the baseline lists it (§6),
and a computed value replaced by a literal is reported at the commit.

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
The package keeps no register of its own (§12), but every id pointer it reads
resolves through a configured resolver: a GitHub issue in the repository's
remote (the default), a file glob (`decisions/{id}*.md`), or a project
function. A lint checks that each pointer resolves (L10).

A `type: labels` entry is returned as a `lookup()`.

**Overrides.** A chapter may narrow a key, rarely, and a shadowing entry must
be read through a different accessor: `dict_local$sites`, never `dict$sites`.
A paragraph moved to a chapter with no local `sites` then errors, instead of
quietly changing meaning. `dict_local$x` with no local `x` is an error;
`dict$x` where the chapter defines a local `x` is an ambiguity error. Local
entries require a `why:` field.

**The pipeline reads the same dictionary, with the same spelling.** A
stipulation matters most where it is computed with.

```r
# _targets.R
dict <- weft::dict("dict.yml")        # the same object prose reads
list(
  tar_dict("dict.yml"),
  tar_dict_deps(list(
    tar_target(era_fit, fit_eras(obs, split = dict$era_split))
  ))
)
```

- **`tar_dict()`** returns a file target for the YAML and one target per key,
  holding the value only.
- **`tar_dict_deps()`** walks each target's command, and the functions it
  calls, for `dict$key` and `dict[["key"]]`, and declares the per-key targets
  as dependencies. A changed value re-runs exactly the targets that read it;
  a changed definition, a new key or a reorder re-runs no consumer.
- **An unknown key errors when the pipeline is defined**, before anything
  runs.
- **A `.qmd` rendered by `tar_quarto()` is scanned for `dict$key` the same
  way.** Without that, a dictionary change does not re-render the report.
- **Dynamic access (`dict[[k]]`) and a bare `dict`** depend on the whole
  dictionary.
- **Keys must be valid R symbols**, and `file` is reserved.
- `tar_outdated()` over-reports what a dictionary edit will re-run;
  `tar_make()` is authoritative.

**Three things the dictionary removes rather than checks:** the glossary is
generated from `definition:`, a `type: quantity` entry prints with its
`unit:`, and `dict_vale()` writes Vale terminology rules from the canonical
spellings (§12).

### Formatters and plurals

Each shipped formatter is a class in prose and a function in R (`num()`,
`pct()`, `n_word()`, …), returning the text and the number as printed (§0).
`plural(n, ...)` is the function form of an `n` span. The collapse engine
behind `.and`, `.or`, `.pairs` and the list formatters is `glue_vec()`, which
is exported.

### Phrases built from numbers

Some wording is fixed by arithmetic, and goes stale silently when it is typed
by hand. These are functions called in a value. The function words they
print ("of the", "nearly") are a closed set, like the "and" of `.and`.

| Function | Prints |
|---|---|
| `of_n(k, n)` | "none of the 4", "the only", "both", "all 5", "3 of the 7" |
| `about(x, to = 1/2)` | "nearly half", "just over half", "half" |
| `ci(est, lo, hi)` | "2.1 (95% CI 1.3 to 2.9)" |
| `pm(est, se)` | "2.1 ± 0.3" |
| `clamp(x, floor, ceiling)` | "< 0.01", "> 99" for a value outside the bounds |

- **`of_n()`** returns `k` as its number as printed, so a following `n` span
  agrees with it. It prevents "all 2 sites" and "both of the 3".
- **`about()`** takes its tolerance from the dictionary: how near is "nearly"
  is a stipulation.
- **`ci()`** takes its level from the dictionary and writes "to" between the
  bounds, never a dash beside a minus sign.
- **`clamp()`** sets the relation in the printed record (§0), as `.p` does.

**Not built, with the package to use instead.** Fractions and multiples in
words ("two-thirds", "twice") come from `nombre`. Compact and signed numbers
("1.2 million", "+3.2%") come from `scales`, registered as a project
formatter.

**Planned, deferred.** `drange()` for date ranges ("3–5 June 2024") and
`dur()` for durations ("2 years and 3 months"). Both need calendar arithmetic
and a decision on date order (§15).

---

## 5. Lints

Each ships as a function returning a structured result, and as an entry in the
gate. All static lints read one tree: Pandoc's, with source positions (§1),
plus the captions written in chunk options and the literal strings passed to
`weft_str()`, which are parsed the same way. What the lints skip is decided by
node type (code, math, link target, citation, raw block), not by pattern.

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
  ::: {.weft-literal why="laboratory method, as specified in the SOP"}
  Samples were filtered through 0.45 µm membranes and stored at 4 °C.
  :::
  ```

  Each opted-out block is an item in the baseline, so a new one fails the
  commit until the baseline lists it (§6).
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
(`x * 100`) is listed separately and more quietly. Constants inside the check
arguments of a `claim()` call are exempt.

### Construct errors

Tier-1 errors, found without running R:

- a wrong arm count for its key, or for the document's language
- a back-reference to an id that is unknown or defined later
- a class within one edit of a formatter or text-class name (`.nmu`). The
  rule applies to names of three or more letters; one edit from `.no` or `.a`
  is half the alphabet
- a key within one edit of a weft key (`sing=`, `trunk=`). Other unknown keys
  and classes are passed through (§0), so only a near miss can be told from an
  attribute meant for Pandoc
- a caption that contains a construct and is written as an unquoted YAML
  scalar

One tier-2 warning sits beside them. A governor key misspelt beyond a near
miss (`[a site | # sites]{count="k"}`) leaves an ordinary Pandoc span that
prints both arms. A bracketed span with an unescaped `|` between its words and
no governor key is listed as a probable construct.

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
8. **No construct above the chunk that loads the package**, in a document
   activated from a setup chunk.

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
| other constructs | none | the multiset of their parsed form, per file |

A construct's parsed form is its expression, classes, keys and arms, so the
order and quoting of an attribute block never count as a change. Rewording a
sentence leaves its constructs present; a `sed` that eats them removes them
from the multiset. The comparison is file-wide, so a move between sections
does not trip it.

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
opted-out blocks, shadowed dictionary keys. Each tolerated one is a line in a
committed baseline file: its file, its source text, and how many times it
occurs there.

- **An item that is not in the baseline fails the commit until the commit
  adds it**, which puts the addition in the diff where a reviewer sees it.
- **An item that has gone is pruned automatically.**
- **A swap is caught.** Removing one literal and adding another leaves the
  total unchanged but adds an item the baseline does not hold. The exception
  is a swap between two items with the same text in the same file.

Items are sorted, one per line, so the file merges cleanly. Moving a paragraph
to another file shows as one item removed and one added.

### The check-loosening report

The pressure runs toward widening a bound rather than rewriting a sentence.
**Every commit that changes a check lists the before and after**, computed
from the two trees: the `claim()` calls are parsed out of each expression, the
conditions out of each guard, and compared. The same report lists a check **removed** from a construct that
still exists, a **guard turned into optional text** (a one-arm `if` that
gained an empty arm), and a **computed value replaced by a literal**. A construct
is matched across versions by its `#id` where it has one, and otherwise by its
section and expression; a check worth tracking through rewording is given an
id.

---

## 7. Knit-time: ledger, conditions, figures

### The value ledger (L5)

The `text` hook evaluates every value and every governed span, so it records
each one as it renders: expression, raw value, printed text with its relation
(§0), file, line, section, and for a span the arm chosen. Commit the ledger;
diff it on re-render.

**Format.** One JSON-lines file per source file, under `generated/ledger/`
(P8). Each line is keyed on the construct's `#id`, or on section anchor,
parsed form (§6) and occurrence index within the section. Line numbers are not
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
- **Captions are prose.** A caption, whether written in a chunk option or in
  a figure or table div, is scanned like any paragraph: its numerals must be
  values and it can carry checks. A count stated in a caption is guarded the
  way any count is.
- **Free scales are flagged** (tier 2): they make panels look comparable that
  are not.

The package does not write alt text and does not judge whether alt text
describes the figure.

### Sentence starts

A recomputed value can open a sentence with a digit or a lowercase word
("12 sites failed"; "no sites failed"). The `text` hook lists every construct
whose text opens a sentence that way (tier 2; a project can make it fail).
The fix is `.cap`, with `.count` or `.word` for a number.

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
| `use_weft()` | everything below, with a summary first |
| `use_setup()` | the `weft::weft_setup()` line in the project's `.Rprofile` (Quarto), or the front-matter line in a single document; the project config |
| `use_quarto()` | the `weft-check` Lua filter as a project extension; the `pre-render` and `post-render` scripts |
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
  findings it reproduces, and how much else it flags. The result ranks the
  layers for that project; it is one corpus, and proves nothing about another.
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
L4 → L2 → construct errors → L10 → L1 → L8 → ratchet
   → render, re-executing every document (L6) → L3 + L11 → L5
```

**The render step re-executes every document it verifies.** `verify()` moves
those documents' entries in `_freeze` aside, runs one ordinary project render,
and puts the entries back if the render fails.

- Each document executes once, and the freezer is left holding the verified
  results, so the next ordinary render serves what was checked.
- Moving the whole folder verifies the project; moving one document's entry
  verifies that document (`verify(files = )`).
- Overriding `freeze` from the command line (`-M freeze:false`, or a profile)
  also re-executes everything, but removes `_freeze`, and the next ordinary
  render then executes everything again.
- A single render keeps the single end-of-book report (§1), which separate
  renders of each file would not.

A chapter that is nevertheless served from freeze fails `verify()`. An
ordinary render only reports it (§1).

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
- **Attribute forms.** Each fixture is also run with its attribute blocks
  reordered, single-quoted and unquoted, and must render the same text.
- **Positions.** The block search against a stress document: repeated
  blocks, blank blocks, a block identical to a line of the chunk above it,
  CRLF, no final newline, a byte-order mark.
- **Pinned internals.** One test each for the
  signature of knitr's `evaluate` hook, knitr's evaluation of `eval.after`
  options after the chunk, Quarto's `.QuartoInlineRender` wrapper, Quarto's
  forwarding of a `NULL` `tbl-cap`, and a Lua `os.exit` failing a Quarto
  render. Each is a place where an upgrade could change behaviour silently.
- **Stock parity.** A document with no attribute blocks renders byte-identical
  with and without the hooks, including inline R inside a fenced block that is
  not executed.

---

## 12. What the package deliberately does not do

- **Judge prose.** No layer verifies English against a number.
- **Write alt text or captions.**
- **Catch misattribution (C3).**
- **Hold a project's constants.** The dictionary schema ships; the values do
  not.
- **Define its own syntax.** No construct needs a compile step or a custom
  engine.
- **Pluralise nouns automatically.** Explicit arms are visible in the source
  and spellchecked; an inflector gets taxa, genera and "data" wrong.
- **Render a fallback.** A construct that cannot be evaluated fails the
  render; nothing is printed in its place and carried on from.
- **Keep registers.** Decision logs, task registers and status conventions are
  a project's own. The dictionary's `decision:` field points at them through
  a configurable resolver (§4), so the package is tied to no one tracker.
- **Lint prose style (L7).** Vale does that and needs no runner. The one
  thing the package knows that Vale does not is the dictionary, so
  `dict_vale()` writes Vale terminology rules from it.
- **Wrap a data-validation package (L12).** §8.
- **Install itself.** P10.

### One package, two parts

The package is built as one, with a hard internal boundary.

- **The prose core** (scanner, hooks, formatters, `claim()`, `plural()`)
  imports nothing from the harness, and emits a record of every construct it
  evaluates.
- **The harness** (lints, gate, ledger, dictionary, `verify()`) subscribes to
  that record.

They split into two packages when the core has a user who does not want the
harness. Integration with Vale, data validation and an issue tracker belongs
in a project template, not in package code.

Names held in reserve for a split. All were free on CRAN's index on
2026-11-11.

| Name | Idea |
|---|---|
| `inlay` | values inlaid in prose |
| `dovetail` | a joint that holds without glue |
| `vouch` | every number vouched for |
| `warrant` | in Toulmin's model, the warrant links data to claim |
| `tally` | to count and to agree (hard to search beside `dplyr::tally()`) |
| `stet` | the proofreader's "let it stand" |

---

## 13. Verification status

Everything here was run with throwaway stand-ins, on macOS, with knitr 1.51
and Quarto 1.11.9 (Pandoc 3.10). "Both" means under `quarto render` and under
`rmarkdown::render()`.

| Fact | Run under |
|---|---|
| The `text` hook receives each prose block, in order, with the environment of that point in the document | both |
| Parked inline code: unchosen arms never run; data that looks like a span is printed | both |
| 250 syntax cases in the form §0 gives: values, formatters and text classes, `claim()`, `n` with one to four arms, `if` with two arms, guards and condition lists, `sign`, back-references, pass-through, attribute blocks in every order and quoting, escapes, nesting, `n="."`, carve-outs, spans in headings, lists, quotes, table cells, footnotes, divs, and every error path | both (two cases Quarto-only) |
| `.range` alone and as an `n` governor, `.p` with its relation, `.count`, `.pairs`, `trunc`, and the error for an `n` span under a non-English `lang` | both |
| `claim()` outside a knit returns its value when it passes and stops at once when it fails | R |
| Inline R inside a fence that is not executed: output identical with and without the hooks | both |
| `.strong` reaches docx as a bold run and Typst as `#strong[…]` | Quarto |
| Every error names the exact source line | both |
| The block search finds the same first line as knitr's own record on 4,320 of 4,320 blocks, across stress documents, the syntax cases, includes and child documents; a block identical to a line in the chunk above it needs the chunk-boundary rule | both |
| Bare values print as stock knitr, 23 kinds of value | both |
| Quarto's `` `{r} x` `` form, bare and with attribute blocks | Quarto |
| A caption written as prose in a figure div or a table div resolves, and the float is numbered and referenced | Quarto |
| Constructs in `fig-cap`, `fig-alt`, `fig-subcap` and `tbl-cap` (kable and gt) resolve through an option hook and `eval.after`, and see objects made in the same chunk; numbering and cross-references hold | Quarto (html, docx, Typst) |
| Constructs in `fig.cap` and `fig.alt` resolve the same way | rmarkdown |
| A caption resolved inside the option hook itself reads the values from before the chunk; `tab.cap` and `!expr` in `fig-subcap` do not work; an unquoted YAML caption is cut at ` #` | both / Quarto |
| A failed check in a caption stops the render, naming the chunk and the option | Quarto |
| Stock knitr evaluates inline R inside a fenced block that is not executed | knitr |
| Constructs in an included file resolve | Quarto |
| docx and Typst output | Quarto |
| Of span classes, Pandoc turns only `.smallcaps`, `.underline` and `.mark` into formatting, in html, docx, LaTeX and Typst; `custom-style` reaches docx | Pandoc |
| Pandoc accepts attribute blocks written key-first, unquoted and single-quoted, and its writer rewrites them to id, classes, keys with double quotes | Pandoc |
| `tar_dict()` and `tar_dict_deps()`: a changed value re-runs exactly its readers, through commands and through functions; a changed definition, a new key or a reorder re-runs no consumer; an unknown key errors at definition | targets 1.12.0 |
| A `tar_quarto()` report notices a dictionary change only when its `.qmd` is scanned for `dict$key`; then exactly | targets, Quarto |
| CLDR's plural-range data gives every English range the plural | CLDR |
| Failed checks collected, one report, exit 1, no output written; draft mode | both |
| Book: failures from all chapters in one report through pre/post-render scripts | Quarto |
| Hidden warnings and messages logged, output byte-identical to stock | both |
| End-of-document check catches a construct above the setup chunk | both |
| `weft-check` filter fails the render when the hooks are absent, passes when present | both |
| Hooks installed on package load, including when loaded before the knit | both |
| Activation from the document's front matter (`!expr` under `knitr:` or `params:`): a construct in the first paragraph resolves | both |
| Activation from `.Rprofile` at the project root, for documents in the root and in a subdirectory, project and single-file render | Quarto |
| `!expr` in `_quarto.yml` or `_metadata.yml` is not evaluated; inline R in a YAML field installs the hooks too late for values in the first block | Quarto |
| Activation from `_output.yml` through an output format that carries the hooks | rmarkdown |
| Chunk cache: checks still run on cached values | both |
| `freeze: auto`: checks do not run; the stamp mechanism detects it | Quarto |
| With `_freeze` (or one document's entry) moved aside, one project render re-executes those documents once and rewrites their entries; `-M freeze:false` and a profile re-execute but remove `_freeze`; `--execute`, `--cache-refresh` and `touch` do not thaw; book and website | Quarto |
| Pandoc's markdown writer keeps values and governed spans as constructs, writing `\|` and `\#` inside them | Pandoc |
| Pandoc's position-tracking reader parses values and spans into nodes with line and column | Pandoc |
| Knit time with 4,000 constructs: about 1.6 s against 0.2 s stock | knitr |
| `gt` 1.3.0 drops a `tab_caption()` or `gt(caption = )` caption from docx output, with no hooks installed; `tbl-cap` with a `tbl-` label is correct in docx, html and Typst | Quarto |

Not run in the syntax stand-in: the end-of-document check together with the
new forms (it was run with the earlier ones), `.date`, `.sci`, `.ord`,
`.ol`, `.dl`, and the functions `of_n()`, `about()`, `ci()` and `pm()`.

Not run at all: Windows; the Render button in RStudio or Positron; running
chunks interactively with the hooks loaded; LaTeX PDF; bookdown; nested
includes; knitr child documents. For captions in chunk options: LaTeX, books
and `cache: true`. For `tar_dict()`: branching, parallel workers and functions
in a package namespace.

Quarto 2 (experimental, 0.43.0): its parser accepts a governed span whose key
has a quoted value, and rejects a key written before a class and an unquoted
`.`. Values with attribute blocks, and execution, were not tested under it.

---

## 14. Open questions

1. **Windows.** The fixture runner is portable and has not been run there. The
   placeholder characters are private-use Unicode and exist only in memory.
2. **The editors.** Whether the Render button, chunk-by-chunk execution and
   the inline preview behave with the hooks loaded.
3. **A render that fails part-way through `verify()`.** What `_freeze` holds
   after a chunk errors mid-render is untested, and the put-back step of §10
   depends on it.
4. **Quarto 2 execution.** It hands knitr text re-serialised from its parsed
   tree. Whether the hooks then see the constructs unchanged is untested.
5. **`tar_dict()` beyond the toy pipeline.** Not run: branching, parallel
   workers, functions in a package namespace, Windows.
6. **Matching a construct across versions** when it has no `#id` is a
   heuristic. How often the check-loosening report mismatches is unmeasured.
7. **Plural rules for languages other than English are not shipped.** The
   table would be generated from CLDR's `plurals.xml`; no R package was found
   that exposes those rules.
8. **`weft_str()`** is exported provisionally. Whether a string renderer in R
    code earns its place beside the function forms is open.
9. **`.Rprofile` activation beside `renv`**, which owns that file, and under
    the editors' Render buttons, is untested.

---

## 15. Build order

Each stage leaves something usable on its own.

**Stage 0 — measure.** `recall_check()` and rough prototypes of the candidate
lints, run against the audit corpus of the companion plan. The result ranks
the layers. It is suggestive: one corpus cannot remove a layer from a package
meant for more than one project (P12).

**Stage 1 — the prose core.** Usable alone. It is built in four steps. Each
step ends when its fixtures pass under Quarto and rmarkdown and a real chapter
renders with it.

*1a — the kernel.* Enough to write a chapter.

- the scanner; the `evaluate.inline`, `text` and `document` hooks
- values; the formatters `.num`, `.pct`, `.sci`, `.word`, `.count`, `.ord`,
  `.no`, `.and`, `.or`; project-registered formatters
- governed spans with `n` (English) and `if`: two arms, guards, condition
  lists; `n="."`
- `claim()`, `plural()`
- pass-through of classes, keys and ids; `.strong`, `.em`
- collected failures, exact positions, draft mode
- the end-of-document check and the `weft-check` filter; `use_quarto()`
- activation from front matter and from a setup chunk
- the syntax fixtures, the conformance test and the pinned-internals tests

*1b — agreement and direction.*

- `sign`; back-references (`n="#d"`)
- the relation in the printed record; `.p`, `clamp()`; `.range`, alone and as
  an `n` governor
- `.cap`, `.a`; the sentence-start report
- `lookup()`, `brk()`, `cite()`, `is_year()`

*1c — captions and conditions.*

- captions in chunk options; `weft_str()`
- the `evaluate` hook: the condition log and severity list
- `.Rprofile` activation and `use_setup()`. These wait until the hooks have
  been run under the Render buttons of RStudio and Positron, and with chunks
  run interactively (§14)

*1d — phrases and lists.*

- `of_n()`, `about()`, `ci()`, `pm()`
- `.pairs`, `trunc`, `.date`; `.ul`, `.ol`, `.dl`

**Stage 2 — dictionary and ledger (L10, L5).**

- `dict`, `dict_local`, the schema, the generated glossary, the pointer
  resolver, `dict_vale()`
- `tar_dict()` and `tar_dict_deps()`
- the ledger: emit, three states, `ledger_review()`

**Stage 3 — static lints (L2, L4, L8, L11).**

- the Pandoc-tree reader, the citation carve-out and the second pass over
  chunk-option captions
- L2 with the opt-out block; construct errors; L4; L8; figure presence

**Stage 4 — the commit gate (L1).**

- the structural diff and the `Removed:` trailer
- the itemised baseline and the check-loosening report
- `verify()` as the single entry point, including the commit-range form

Stage 2 comes before stage 3 because L2's tier-1 rule sends constants to the
dictionary: the lint cannot be switched on until there is somewhere for them
to go.

**Planned, after stage 4.** Neither is in a stage.

- `drange()` and `dur()` (§4): both need calendar arithmetic and a decision on
  date order.
- Plural rules for languages other than English (§0).
