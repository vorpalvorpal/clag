# `weft` — package scoping

**Date:** 2026-11-11
**Status:** scoping. Nothing in this design is built. The syntax and the
runtime were exercised with throwaway stand-ins; Part 3 says exactly what was
run and what was not. Integration facts were checked against knitr 1.51 and
Quarto 1.11.9 (Pandoc 3.10) on macOS.

`weft` lets a manuscript's prose carry computed values, and wording that
depends on them, and adds deterministic checks for computational manuscripts.
It has no users and no backwards-compatibility obligations. Portable by
design: the package knows about knitr, Quarto, Pandoc, `targets` and git, and
nothing about any particular book. The repository and the existing code still
carry the old name, `clag`.

The package is two layers. The **prose core** (the syntax of §1 and the
runtime of §2) makes a computed value cost what knitr inline code already
costs, and makes a checked value cost one function call more. The **integrity
harness** (dictionary, lints, commit gate, ledger, `verify()`) is only
socially sustainable because of that: a rule like "every numeral is a computed
value" survives contact with authors only when writing one is nearly free, and
when the inline R a document already contains counts without being rewritten.

Every weft construct is markdown that knitr, Pandoc and Quarto already accept.
Nothing is compiled, there is no second source tree, and the file the author
edits is the file that renders.

**How this document is arranged.**

| Part | Holds |
|---|---|
| 1 — Rules | what the package does, as numbered rules; no reasons, no test results |
| 2 — Rationale | the problem, the principles, and why each rule is as it is |
| 3 — Evidence | what was run, what was not, and the open questions |
| 4 — Plan | tests and build order |

A rule is cited by its number (rule 1.5.4). An open question is cited as Q7.
Companion document: `~/projects/10.02 Healthy Waterways/MANUSCRIPT-INTEGRITY-PLAN.md`
covers applying the package to one manuscript; §11 maps its layer labels to
the rules here.

---

# Part 1 — Rules

## 1. Syntax

### 1.1 Constructs

**1.1.1** There are two constructs.

```
`r EXPR`{ATTRS}        a value
[PROSE]{ATTRS}         a span
```

**1.1.2** Code spans and attribute values hold R. Brackets hold prose.

**1.1.3** The exception to 1.1.2 is wording that a function prints: the closed
set of function words in the formatters and phrase functions ("and", "of
the", "nearly"; §3.4, §3.5), and the phrases of a `lookup()` or `brk()` (§3.3).

**1.1.4** A value shows the result of an R expression. A value with no
attribute block is plain knitr inline code. With an attribute block, Quarto's
`` `{r} x` `` form and `` `r x` `` behave the same. With none, each prints as
its own form prints in stock (1.3.1).

**1.1.5** A span is a weft construct when its attribute block carries exactly
one of the four keys:

| Key | Kind | The span |
|---|---|---|
| `n`, `if`, `sign` | governor | prints prose chosen by an R value (§1.5) |
| `cite` | marker | prints its prose and names its source (§1.8) |

**1.1.6** A span or a div with the class `.weft-literal` is a marker for the
lints (§1.8). The runtime does one thing with it: it removes the `why` from
the output (1.8.11).

**1.1.7** The attribute block touches the closing backtick or bracket, with
nothing between.

**1.1.8** A construct is a span that carries a weft key (1.1.5), or a value
that has an attribute block. Bare inline R, with no attribute block, is not a
construct. It keeps stock behaviour everywhere: it prints as stock prints it
(1.3.1), and no rule about constructs applies to it, in prose, in `title:`
and the other front-matter fields, in tables and in captions. A `claim()` in
it is still a check (2.4.1), and it still counts as a value for the numeral
rule (5.2.1).

### 1.2 The attribute block

**1.2.1** `{ATTRS}` is Pandoc's attribute syntax: an optional `#id`, classes,
and `key=value` pairs, in any order.

**1.2.2** A value is double-quoted or unquoted. An R string inside a value
uses single quotes: `{if="tier == 'sev'"}`.

**1.2.3** In the block of a weft construct, a single-quoted value, or a `"` or
a `\` inside any value, is a construct error (§5.3). The message says to bind
the expression to a name in a chunk.

**1.2.9** A `"` inside a double-quoted value ends the value early, and what is
left is no longer an attribute block. So braces that directly follow a bracket
or inline code, do not parse as an attribute block, and contain a weft key
followed by `=`, are the same construct error.

**1.2.4** Meaning never depends on the order in which things are written
inside the block.

**1.2.5** weft owns these names. Everything else in a block is passed through
(1.2.6).

| Kind | Names |
|---|---|
| governor and marker keys | `n`, `if`, `sign`, `cite` |
| renderer keys | `digits`, `sigfig`, `sep`, `last`, `trunc` |
| formatter classes | `.num .pct .sci .p .date`, `.no .word .count .ord`, `.and .or .pairs .range .ul .ol .dl`, and project-registered ones (§1.4) |
| text classes | `.a`, `.cap`, `.strong`, `.em` |
| identity | `#id` (§1.7) |
| lint marker | `.weft-literal`, `why` (§1.8) |

**1.2.6** Any class or key weft does not own is put on a Pandoc span around
the construct's output. With nothing to pass through, the output is plain
text. An empty output (an empty arm) emits nothing, with or without
pass-through.

```
`r x`{.num .smallcaps custom-style="Key figure"}   →   [1.2]{.smallcaps custom-style="Key figure"}
```

**1.2.7** An unknown class or key is therefore not an error, however close it
is to a weft name (`.nmu`, `trunk=`). A tier-2 lint lists it (5.3.3).

**1.2.8** An `#id` is never emitted to the output.

### 1.3 Values

```
`r x`                                bare value
`r claim(n_gap, . > 10)`             checked value
`r claim(x, . >= 10, . < 99)`        several checks
`r x`{.num}                          a formatter
`r x`{.num digits="2"}               a formatter with its precision
`r n`{.no .word}                     "no", "one", "two", …
`r claim(depth, . > 0.5)`{.num}      check and formatter
`r k`{.word .cap}                    formatter and text class: "Twelve"
`r sites`{.or}                       "a, b or c"
`r sites`{.and sep="; "}             a renderer key
`r sites`{.and trunc="3"}            "a, b, c and 4 others"
`r means`{.num .pairs}               "A (1.2), B (3.4) and C (5.6)"
`r sites`{.ul}                       bullet list
```

**1.3.1** A bare value prints exactly as stock prints its form:
`` `r x` `` as stock knitr prints it, and `` `{r} x` `` as stock Quarto
prints it.

**1.3.2** A check is written in the expression, with `claim()` (§3.1).
`claim()` returns the raw value, so a check always sees the value as
evaluated and the formatters apply after it.

**1.3.3** A governor key or `cite` on a value is a construct error.

**1.3.4** A missing value is a collected failure (§2.6) of kind "no value",
with the marker `<<weft: no value, line N>>` (2.6.8). A missing value is an
element that is `NA`, `NaN`, `Inf` or `-Inf`, or a value of length zero, that
reaches a formatter, a governor or a phrase function (§3.5). A bare value with
no attribute block still prints as stock knitr prints it (1.3.1).

```
Mean depth was `r depth`{.num} m.      depth is NA   →   <<weft: no value, line 88>>
Mean depth was `r depth` m.            depth is NA   →   Mean depth was NA m.
```

### 1.4 Formatting

**1.4.1** Formatting runs in four fixed stages, whatever order the classes are
written in.

| Stage | Classes | Acts on |
|---|---|---|
| i. number | at most one of `.num .pct .sci .p .date` | each element of the value |
| ii. wording | `.no`, then at most one of `.word .count .ord` | each element, as printed by stage i |
| iii. collapse | at most one of `.and .or .pairs .range .ul .ol .dl` | the vector of elements |
| iv. text | `.a`, then `.cap`, then `.strong` / `.em` | the final text |

**1.4.2** Two classes from one at-most-one group are a construct error.

**1.4.3** What each class prints:

| Class | Prints |
|---|---|
| `.num` | a number, to the document's defaults (§9.1) |
| `.pct` | a proportion as a percentage: 0.12 prints "12%" |
| `.sci` | scientific notation |
| `.p` | a p-value: "p = 0.03", "p < 0.001", never "p = 0.000" |
| `.date` | a date, in the document's default format |
| `.no` | a printed zero as "no" |
| `.word` | a spelled numeral ("three") |
| `.count` | a word below the threshold, digits from it up ("three", "12"); the threshold defaults to ten |
| `.ord` | an ordinal ("3rd") |
| `.and`, `.or` | the elements collapsed with a final "and" / "or" |
| `.pairs` | a named vector as "A (1.2), B (3.4) and C (5.6)" |
| `.range` | a length-2 value as a range ("3–5") |
| `.ul`, `.ol`, `.dl` | a bullet, ordered or definition list |
| `.a` | "a" or "an" before the text, by sound ("an 11-year", "a 12-year") |
| `.cap` | a capital first letter |
| `.strong`, `.em` | markdown emphasis |

**1.4.4** `.range` prints one number when both ends print the same, and
writes "−5 to −3" when either end is negative.

**1.4.5** `.a` applies to numbers and number words only.

**1.4.6** `.ul`, `.ol` and `.dl` produce a block. A value that carries one
must be alone in its paragraph; otherwise it is a construct error.

**1.4.7** Renderer keys:

| Key | Stage | Sets |
|---|---|---|
| `digits` | number | decimal places |
| `sigfig` | number | significant figures |
| `sep` | collapse | the text between items |
| `last` | collapse | the text before the final item |
| `trunc` | collapse | the number of items shown before "and N others" |

`digits` and `sigfig` together are a construct error. Either one on a
construct with no number-stage class implies `.num`.

**1.4.8** A project registers its own formatter (a function, optionally
bundling options) under a class name, and names the stage it belongs to
(number by default). It counts toward that stage's at-most-one rule. A project
name may not shadow a shipped one.

**1.4.9** A unit is printed only for a dictionary quantity (§4.4). No
formatter supplies one.

**1.4.10** Formatter output is markdown, as stock knitr's inline output is.
Text that comes from data is not escaped.

**1.4.11** Every formatted value has a **printed record**: its text, the
number as printed, a flag for whether decimals are shown, and a relation
(`=`, `<` or `>`). "< 0.001" is a bound, not a value. Stage i sets the
number; stages ii to iv reword and pass it through. A collapsed vector and a
date have no number.

**1.4.12** `.word`, `.count` and `.ord` take a whole number that is not
negative, judged on the number as printed. Anything else (a decimal, a
negative, a bound) is a collected failure at knit time (5.3.2). `.word`
prints digits from a limit up, as `.count` does from its threshold; the limit
defaults to one hundred and is configurable (§9.1).

### 1.5 Governed spans

**1.5.1** The bracket holds one or more **arms** separated by `|`. The key
names the kind of governor, and fixes the arm counts allowed.

| Key | The value must be | Arms | Chosen |
|---|---|---|---|
| `n` | a single number | 1 | always (a template for `#`) |
| | | 2 | one / other |
| | | 3 | zero / one / other |
| | | 4 | zero / one / two / other |
| `if` | one or more conditions, each a single `TRUE` or `FALSE` | 2 | true / false; either may be empty |
| | | 1 | always (a guard) |
| `sign` | a single number | 2 | positive / negative |
| | | 3 | positive / negative / zero |

The arm counts for `n` are English's (§1.6).

```
[a person | # people]{n="n"} responded.
[no people | a person | # people]{n="n"} responded.
[never | once | twice | # times]{n="k"}
file[ | s]{n="n"}
The target was [met | not met]{if="x >= target"}.
Sampling was complete[, apart from the estuary sites | ]{if="n_missing > 0"}.
Council will need to [add more sampling sites]{if="n_gap > 10"}.
[All]{if="all(mod$rising)"} `r nrow(mod)` models rise.
Abundance [rose by # | fell by # | did not change]{.pct sign="d"}.
[# metre | # metres]{.num n="claim(depth, . > 0.5)"}
[# site | # sites]{.range n="c(lo, hi)"}
```

**1.5.2** A wrong arm count for the key is a construct error, found from the
source.

**1.5.3** **A case with no arm is a failed claim.** A one-arm `if` whose
conditions are not all `TRUE`, and a two-arm `sign` at zero, are collected and
reported like any failed check (§2.6).

**1.5.4** `if` takes a comma-separated list of conditions, read as R reads an
argument list: `if="n_gap > 10, n_sites >= 3"`. All must be `TRUE` for the
true arm. `&&`, `||` and brackets remain available inside a condition.

**1.5.5** A one-arm `if` is a **guard**. It always prints its phrase. Each
condition that is not `TRUE` is reported separately. A phrase with an empty
second arm (`[, apart from the estuary sites | ]`) is optional text and fails
nothing.

**1.5.6** A governor is checked with `claim()` in its expression, as a value
is.

**1.5.7** Formatter classes and the keys `digits` and `sigfig` on an `n` or
`sign` span format the governor. A formatter on an `if` span is a construct
error. Text classes on any span act on the chosen arm's final text.

**1.5.8** `#` in an arm stands for the governor's printed text. Inside a
`sign` span it is the magnitude as printed, without its sign.

**1.5.9** Selection sees the value as it prints. For `n`, the "one" arm is
chosen only when the printed number is 1 with no decimals shown; the "zero"
arm only when it is 0, and the "two" arm only when it is 2. A value printed as
"1.0" takes the "other" arm. A number printed as a bound ("< 1") takes the
"other" arm.

**1.5.10** `sign` judges zero on the number as printed: a change that prints
as "0.0%" takes the zero arm, whatever its raw value.

**1.5.11** `n` must be a single number. A vector or a string is a collected
failure (5.3.2) whose message says to write `length(x)`. An `NA` is a "no
value" failure (1.3.4). A count is never inferred from a length.
The one exception is a length-2 value with `.range`: `#` is then the range,
and the span takes the plural unless the range collapses to a printed 1.

**1.5.12** Arms are trimmed. `\|` and `\#` mean the same as `|` and `#`. A
doubled `||` or `##` is the literal character.

**1.5.13** Inside a pipe-table cell the arm separator must be written `\|`.
An unescaped one is a construct error.

**1.5.14** A `|` or a `#` inside math, a code span, a link target or raw
content within an arm is neither a separator nor a placeholder.

**1.5.15** The bracket is prose. It can contain markdown, values and further
spans, and every lint that applies to prose applies inside it.

**1.5.16** Only the chosen arm is evaluated. A value or span in an arm that is
not chosen neither renders nor runs its checks, and an id defined there does
not exist.

**1.5.17** A `sign` governor that prints as a bound ("< 0.1%") is a collected
failure at knit time (5.3.2). A bound has a direction and no magnitude to
print; the author writes that case with `if`.

### 1.6 Plural forms

**1.6.1** Plural forms follow the document's `lang`. An `n` span has one arm
for each plural form the language has, in CLDR's order (zero, one, two, few,
many, other), or a single arm that is a template for `#` (1.5.1).

**1.6.2** Two optional arms may be added, in this order of precedence. First,
a leading arm for exactly zero, when the language has no "zero" form. Second,
and only together with the first, an arm for exactly two placed after the
singular, when the language has no "two" form.

| `lang` | Plural forms | Arms allowed | The longest reads |
|---|---|---|---|
| English | one, other | 1, 2, 3, 4 | zero / one / two / other |
| Polish | one, few, many, other | 1, 4, 5, 6 | zero / one / two / few / many / other |
| Arabic | zero, one, two, few, many, other | 1, 6 | its own six forms |

**1.6.3** "One" is the language's singular form, not the number 1, and is
judged on the number as printed (1.5.9). In English it is exactly 1 with no
decimals shown.

**1.6.4** An arm count the language does not allow is a construct error,
found from the source.

**1.6.5** English is shipped. Under a `lang` whose rules are not shipped, an
`n` span with more than one arm is an error. English rules are never applied
to another language.

**1.6.6** Any other exact number is R: `of_n()` (§3.5), a `lookup()`, or a
nested `if`.

**1.6.7** `lang` is matched on its primary subtag: `en-AU` and `en_GB` are
English.

**1.6.8** The wording classes (`.no .word .count .ord`), the collapse classes
that print a word (`.and .or .pairs .range`, and `trunc`), `.a`, and the
phrase functions that print words (`of_n()`, `about()`, `ci()`) print English.
Under a `lang` whose words weft does not ship, using one is a construct error,
found from the source.

### 1.7 Agreement, ids and back-references

**1.7.1** Whole arms are the plain idiom for agreement.

```
[# sample was taken | # samples were taken]{n="n"}
```

**1.7.2** An inner span may inherit the enclosing governor with `n="."`. It is
legal inside an `n` span, and inside a `sign` span, where it agrees with the
magnitude as printed. There is no `sign="."`.

```
[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}
[rose by # point[ | s]{n="."} | fell by # point[ | s]{n="."}]{sign="d"}
```

**1.7.3** A list and its verb are a value and an agreement.

```
`r sites`{.and} [was | were]{n="length(sites)"} sampled.
```

**1.7.4** A span that names the governor again (`[was | were]{n="n"}`) agrees
with the value as that span prints it.

**1.7.5** An `#id` on a value or a governed span names that one printed
occurrence. It is unique within a document; a duplicate is a construct error.
A `cite` span takes no `#id`; one there is a construct error.

**1.7.6** A later span refers to an id with `#` and the id as the whole value
of `n` or `sign`.

```
Depth was `r claim(depth, . > 0.5)`{#d .num} m. … The [core | cores]{n="#d"} …
```

**1.7.7** The referring span re-evaluates nothing: the value was evaluated
once and its checks ran once.

**1.7.8** With no formatter classes and no `digits` or `sigfig` of its own, the
referring span uses the printed record of the occurrence. With any of them, it
formats the raw value afresh. Text classes and pass-through attributes do not
count as formatters here.

**1.7.9** `[#]{n="#d"}` prints the value again.

**1.7.10** The id must be defined earlier in the same document. An unknown id,
or one defined further down, is a construct error found from the source. A
book chapter cannot refer to another chapter's id.

**1.7.11** An id defined inside an arm can be referred to only from inside
the same arm (1.5.16).

**1.7.12** An id is also the construct's identity for the gate and the ledger
(§6.1, §7.1).

### 1.8 Marker spans

**1.8.1** A number quoted from a source is a span with the key `cite`. The
value of `cite` takes one of two forms.

| Form | Example | The span prints |
|---|---|---|
| a Pandoc citation (it contains `@`) | `cite="@smith2020"` | its prose, then that citation in brackets |
| bare keys | `cite="smith2020"` | its prose only |

```
[10 m in the upper catchment]{cite="@smith2020"}.
    →  10 m in the upper catchment [@smith2020].

@smith2020 found [10 m]{cite="smith2020"} in the upper catchment.
    →  @smith2020 found 10 m in the upper catchment.
```

**1.8.2** A `cite` span has no arms: `|` and `#` in it are ordinary
characters. The bracket is prose and can hold values and governed spans.

**1.8.3** In the citation form the value is written into the output exactly
as given, in square brackets, directly after the span's prose. Everything
Pandoc's citation syntax allows therefore works: a locator
(`cite="@smith2020, p. 4"`), a prefix, several sources separated by `;`, and
`-@smith2020` for the year alone. The author places the citation by choosing
where the bracket closes. Nothing is moved, and adjacent spans are not merged.

**1.8.4** In the bare form the value is keys only, separated by `;`, and the
citation is written elsewhere by the author (rule 5.4.2). Any other text in a
value with no `@` is a construct error.

**1.8.5** Each key must follow Pandoc's grammar for a citation key and must
resolve in the bibliography, in either form. This is checked at knit time and
by a lint (§5.4).

**1.8.6** A value with an `@` anywhere in it is the citation form, and words
before the `@` are a prefix: `cite="smith2020 and @jones2019"` prints
`[smith2020 and @jones2019]`, in which only `jones2019` is a key.

**1.8.7** Text classes and pass-through attributes on a `cite` span act on
its prose. A formatter class on one is a construct error.

**1.8.8** A citation that the quoting rule (1.2.3) cannot hold (a prefix or
locator that needs a backslash, a key that contains `"`) is written as an
ordinary Pandoc citation after a bare-form span.

**1.8.9** A literal with no source is marked with `.weft-literal` and a `why`,
inline or as a block.

```
filtered through [0.45 µm]{.weft-literal why="pore size, SOP 12"} membranes

::: {.weft-literal why="laboratory method, as specified in the SOP"}
Samples were filtered through 0.45 µm membranes and stored at 4 °C.
:::
```

**1.8.10** A `.weft-literal` without a `why` is a construct error. Each marked
span and block is a baseline item (§6.5).

**1.8.11** The `why` is removed from the output. The class is left on the span
or div as an ordinary Pandoc class.

### 1.9 What weft leaves alone

**1.9.1** These are never weft constructs:

- a bracket whose attribute block has none of `n`, `if`, `sign`, `cite` (an
  ordinary Pandoc span, a link, a citation, a footnote)
- inline R with no attribute block (1.1.8)
- a code span that is not inline R
- math, link targets and raw blocks (inline R in math is read by the numeral
  rule, and an attribute block there is a construct error: 5.2.6)

**1.9.2** Inside a fenced block that is not executed, and inside an HTML
comment, weft changes nothing. Bare inline R there is evaluated exactly as
stock knitr evaluates it, and an attribute block after it is left as text.

### 1.10 Captions, front matter and strings

**1.10.1** A caption in a chunk option is prose. A construct works in
`fig-cap`, `fig-alt`, `fig-subcap` and `tbl-cap` under Quarto, and in
`fig.cap` and `fig.alt` under rmarkdown.

````
```{r}
#| label: fig-depth
#| fig-cap: |
#|   Depth at [a site | # sites]{n="n_sites"}, mean `r depth`{.num} m.
n_sites <- nrow(d)
plot(d)
```
````

**1.10.2** A caption is resolved after its chunk has run, so it sees objects
made in the same chunk. A construct in the caption of a chunk that may not run
is a construct error (2.3.5).

**1.10.3** A caption that contains a construct is written as a YAML block
scalar (`fig-cap: |`). Written as any other form of scalar it is a construct
error, as in front matter (1.10.7).

**1.10.4** Not supported: rmarkdown's `tab.cap`, and `!expr` inside
`fig-subcap`.

**1.10.5** A caption can also be prose in a Quarto figure or table div
(`::: {#fig-a}` or `::: {#tbl-a}` … caption paragraph … `:::`), where both
constructs work as in any paragraph.

**1.10.6** A numbered table takes its caption from `tbl-cap` or a table div,
not from `gt::tab_caption()`.

**1.10.7** A construct works in the front-matter fields `title`, `subtitle`,
`abstract` and `description`, when the field is a YAML block scalar (`|` or
`>`). A construct in any other form of scalar there is a construct error.
Bare inline R is not a construct (1.1.8), so this rule does not apply to it:
``title: "Report `r x`"`` is legal and prints as stock. In a book or a
website, `title` holds no construct at all (1.10.11).

**1.10.8** Front matter is evaluated before any chunk runs. A construct there
sees only what exists at that point: `params`, an object made in `.Rprofile`,
or a call such as `tar_read()`.

**1.10.9** A field that needs values from the document's chunks is written in
a second metadata block at the end of the document. Pandoc merges the two, and
the later block wins.

````
```{r}
n_sites <- nrow(d)
```

---
abstract: |
  We sampled [a site | # sites]{n="n_sites"}, to a mean depth of
  `r depth`{.num} m.
---
````

**1.10.10** `weft_str()` renders a markup string in R code (§3.6). Text that a
chunk prints with `results: asis` is not prose the hooks see; it goes through
`weft_str()`.

**1.10.11** In a book or a website project, a construct in a document's
`title`, in either metadata block, is a construct error found from the source.

---

## 2. Runtime

### 2.1 Hooks

**2.1.1** weft attaches to a knit through knitr's hooks. There is no
preprocessor.

| Hook | What weft does with it |
|---|---|
| `evaluate.inline` | does not evaluate; parks the code and returns a placeholder |
| `text` | receives each block of prose between chunks and resolves every construct in it |
| `evaluate` | records every warning, message and error a chunk raises, then hides what the author asked to hide |
| `document` | at the end: checks that everything was evaluated, writes the logs, fails the render if any check failed |
| `opts_hooks` on the caption options | turns a caption string that contains a construct into a call, which knitr evaluates after the chunk |
| `chunk` | removes a `NULL` `tbl-cap`, which Quarto would otherwise forward to every cell |

**2.1.2** Each weft hook wraps the hook that was installed before it, and
calls it.

**2.1.3** The hooks are installed only by `weft_setup()`. Attaching the
package (`library(weft)`) installs nothing, and neither does loading the
namespace (`weft::claim()`, `requireNamespace()`). Installing is idempotent,
and works whether or not a knit is in progress. A call made while a knit is
running changes none of that knit's state.

**2.1.4** The `chunk` wrapper is installed late, from the first call of an
option hook.

**2.1.5** At the first hook call of each knit, weft initialises that knit: it
reads the configuration (§9.1), creates `dict` when the project has a
dictionary (§4.1), scans the input file (2.10.2), and empties its records.
Nothing is read when the hooks are installed. A knit is initialised only at
the top level. A child document (`knitr::knit_child()`, the `child` chunk
option) shares its parent's records, and its constructs are scanned from its
own file.

**2.1.6** The document's own front matter is read from `rmarkdown::metadata`,
under Quarto and under rmarkdown. Under Quarto that object does not hold what
`_quarto.yml` or `_metadata.yml` set. When weft needs a project-level `lang`
or `bibliography`, it reads Quarto's merged metadata from the JSON file named
by the environment variable `QUARTO_EXECUTE_INFO`. Where that variable is not
set it calls `quarto::quarto_inspect()` on the source file, once per document.

**2.1.7** Installing the hooks leaves a plain `knitr::knit()` call producing
the output it produces without them. How weft meets this is not settled
(Q16).

### 2.2 Prose

**2.2.1** Inline code is parked, not evaluated: the `evaluate.inline` hook
returns a placeholder of private-use characters, with no newline in it.

**2.2.2** The `text` hook resolves the constructs and bare values of a block
in textual order.
For a governed span it chooses the arm first, and evaluates only what the
chosen arm contains.

**2.2.3** A block of prose is processed after the chunks above it and before
the chunks below it, so a construct sees the environment a stock inline
expression would.

**2.2.4** A data value whose text looks like a span is printed, never
evaluated.

**2.2.5** A bare value is evaluated through knitr's own default inline
evaluator, so `knit_print` methods and the `inline` hook apply as usual.
Under Quarto a bare `` `{r} x` `` keeps Quarto's escaping (1.3.1).

**2.2.6** Within one construct the order is: evaluate the expression (its
checks run); formatter stages i to iii; choose the arm and fill `#`; text
classes; pass-through.

### 2.3 Captions

**2.3.1** The caption options are in knitr's `eval.after` list, and an option
hook turns a caption string that contains a construct into a call. The caption
is therefore resolved once the chunk's code has run, in the chunk's
environment.

**2.3.2** An error in a caption names the chunk label and the option.

**2.3.3** A failed check in a caption is collected like one in prose (§2.6).

**2.3.4** Figure and table numbering and cross-references are unaffected.

**2.3.5** A caption is not resolved again when its chunk is served from
knitr's cache, has `eval: false`, or uses an engine other than R. A construct
in the caption of a chunk with `cache: true` (set on the chunk or for the
document), `eval: false` or another engine is a construct error, found from
the source. The message says to write the caption in a figure or table div
(1.10.5).

### 2.4 `claim()` by context

**2.4.1** A failed check is collected, and the value returned, only when the
`claim()` call is evaluated in inline R during a knit, in a construct or a
bare value: in prose, in a caption, or in a string given to `weft_str()`.

**2.4.2** Everywhere else a failed check stops at once: in chunk code, in a
pipeline target, in plain R, and in a document in which the hooks never
installed.

**2.4.3** `claim()` does not depend on knitr.

**2.4.4** During a knit, a failed check in chunk code is recorded before it
stops the chunk. A chunk with `error: true` then prints the error and the knit
carries on, and the render still fails at the end with the check in its report
(2.6.2). The same holds for a failed check caught by `try()` or `tryCatch()`:
it is recorded, and the render fails.

**2.4.5** A failed check that stops the knit prints, with its own error, every
failure collected before it.

### 2.5 Backstops against silence

**2.5.1** *The visible attribute block.* Without the hooks, a value's
attribute block shows as text (`1.2{.num}`). A `claim()` in its expression
stops the knit when the check fails or when `claim` is not found.

**2.5.2** *The end-of-document check.* The `document` hook compares the
constructs the scanner found in the input file with those that were
evaluated. Every construct outside an arm, and every construct in an arm that
was chosen, must have been evaluated. One that was not fails the render, named
with its line (tier 1).

**2.5.3** *The `weft-check` Lua filter*, installed in a Quarto project by
`use_quarto()`, and in an rmarkdown document or project by `use_setup()`.
After knitting, the render fails on any span that still carries `n`, `if`,
`sign` or `cite`, any text that still shows an attribute block, any leftover
placeholder character, and any marker `<<weft:` (2.9.5). It works when the
package was never loaded, and it covers captions. The filter exits through
`os.exit(1)` (tier 1). In draft mode it reports instead (9.4.3). Under
rmarkdown, `use_setup()` places the filter file and names it under the output
format in the document's front matter:

```yaml
output:
  html_document:
    pandoc_args: ["--lua-filter", "weft-check.lua"]
```

### 2.6 Failures

**2.6.1** A failed check does not stop the knit. A failed check is a `claim()`
check that is not `TRUE` (2.4.1), a guard condition that is not `TRUE`, or a
case with no arm (1.5.3).

**2.6.2** Each failure is recorded (file, line, expression, value), a visible
marker is left in the text, and the `document` hook fails the render once,
listing every failure (tier 1). A failure with no line of its own is located
by its chunk label instead: one in chunk code (2.4.4), in a caption (with the
option, 2.3.2), or in a `weft_str()` string (2.6.8).

```
weft: 2 claims failed
  14-percentile-bands.qmd:412  "All 10 models rise"
      all(mod$rising) was FALSE
  14-percentile-bands.qmd:431  `r claim(shift$n_down, . >= 10)`
      . >= 10 was FALSE (value 7)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

**2.6.3** A failed guard is reported by its phrase, with each failing
condition. The message says that optional text is written with an empty
second arm: `[phrase | ]{if="…"}` (1.5.5).

**2.6.4** An expression that cannot be evaluated (an unknown object, a call
that raises an error) is collected and reported the same way, naming the
expression and its line. An expression that does not parse is a construct
error instead (5.3.5).

**2.6.5** A construct error (§5.3) stops the render at once, except in draft
mode (9.4.3).

**2.6.6** In a book the failures are held to the end. A `pre-render` script
opens a collection file, each chapter appends to it, and a `post-render`
script prints one report for the whole book and exits non-zero. The chapters'
output has been written by then, and carries the visible markers.

**2.6.7** Failed checks, unevaluated constructs and fatal conditions (§7.4)
are reported distinctly from ordinary knit errors.

**2.6.8** The marker is visibly a marker, not a value, and no fallback text is
printed for a construct that failed. It is plain ASCII with no markdown in it:

| Case | Marker | Placed |
|---|---|---|
| a failed check | `<<weft: failed claim, line 412>>` | directly after the text the construct printed |
| an expression that could not be evaluated; a missing value (1.3.4) | `<<weft: no value, line 412>>` | in place of the construct |
| an error that depends on the value (5.3.2) | `<<weft: value error, line 412>>` | in place of the construct |
| a construct error, in draft mode (9.4.3) | `<<weft: construct error, line 412>>` | in place of the construct |

A string rendered by `weft_str()` has no line, and its marker names the chunk:
`<<weft: failed claim, chunk fig-depth>>`. The marker is the same in draft
mode. Every marker can be found by searching for `<<weft:`.

**2.6.9** Three other kinds of failure are collected as a failed check is,
each with its marker, and fail the render at the end with the rest: an
expression that cannot be evaluated (2.6.4), a missing value (1.3.4), and an
error that depends on the value (5.3.2).

### 2.7 Positions

**2.7.1** Every error and every log entry names the source file and the exact
line of the construct: the block's first line plus the newlines before the
construct.

**2.7.2** The block's first line is found by searching for the block's
content in the file knitr is reading, forward from the end of the previous
block. weft puts the parked expressions' source back and matches whole lines,
requiring a chunk boundary on each side.

**2.7.3** A block that cannot be found is reported with the end of the
previous block as a lower bound. `knit(text = )` has no file, so its positions
are relative to the block.

**2.7.4** Under Quarto, knitr reads an intermediate file with
`{{< include >}}` already expanded. weft maps lines back through the includes,
so an error in an included file names that file.

**2.7.5** Only exported knitr functions are used.

### 2.8 The condition hook

**2.8.1** The `evaluate` wrapper logs every warning, message and error a chunk
raises, with the chunk label and the source expression. It then removes from
the output exactly what the author's `warning:` and `message:` settings would
have removed. The rendered document is identical to a stock render.

**2.8.2** A condition raised by a value in prose is caught where the value is
evaluated and logged with its line. It never appears in the document.

**2.8.3** What is done with the log is in §7.4.

### 2.9 Caching and freeze

**2.9.1** Under knitr's chunk cache the prose hooks still run on every render,
and check the cached values.

**2.9.2** A document served from Quarto's `freeze` is not executed, and none
of its checks run. Every executed document writes a stamp. After an ordinary
render the `post-render` script reports each document with constructs that
was served from freeze: how many checks did not run, and when they last did.
For a document whose stamp records no failures, this is a report and fails
nothing.

**2.9.3** `verify()` fails on a document served from freeze (§8; tier 1).

**2.9.4** The stamp records the failures the document's render collected. The
`post-render` script fails the render while any document served from freeze
has recorded failures, and lists them as 2.6.2 does (tier 1).

**2.9.5** The `weft-check` filter fails on the text `<<weft:` anywhere in a
document (2.5.3). In a project where the `pre-render` script has opened the
collection file (2.6.6), the filter adds what it finds to that file instead of
exiting, and the `post-render` script fails the render.

### 2.10 The scanner and the Pandoc tree

**2.10.1** The scanner is a hand-written R function over characters. It finds
inline code with its attribute block and brackets with theirs, honours nesting
and escapes, and skips what §1.9 leaves alone, except that it reads inline R
inside math (5.2.6).

**2.10.2** The scanner is the single source of what the constructs are and
where: at knit time over each prose block, and statically over the source
file, its captions in chunk options and the literal strings passed to
`weft_str()`. The lints, the gate and the end-of-document check all take
construct identity and position from it.

**2.10.3** The static lints read Pandoc's tree only for the prose between
constructs. The source is parsed with `commonmark_x+sourcepos` by the Pandoc
that Quarto ships, with the range of every construct's code and attribute
block masked first (2.10.5), so positions are unchanged.

**2.10.4** That reader does not parse citations. Citation brackets are
recognised by pattern (5.1.4).

**2.10.5** A construct is masked with one letter repeated to the length of
its range, never with spaces. A line break inside the range is kept. The
scanner then checks that masking changed the type of no block. A change is a
tier-1 failure naming the line.

**2.10.6** Every YAML metadata block, the front matter and any later one
(1.10.9), is masked before the prose is parsed. The text of `title`,
`subtitle`, `abstract` and `description` is then linted as prose, with
positions that point into the YAML.

### 2.11 Output formats

**2.11.1** The hooks run before Pandoc, and do not depend on the output
format.

---

## 3. Functions

### 3.1 `claim()`

```r
claim(x, <check>, ...)
```

**3.1.1** `x` is any type. `claim()` returns it visibly and unchanged, so a
value can be guarded in place inside a larger expression:
`` `r trend(claim(foo, . > 0))` ``.

**3.1.2** `.` in a check stands for `x`: `claim(shift$n_down, . >= 10)`.

**3.1.3** Each check is a separate argument and is reported separately.

**3.1.4** Checks are captured unevaluated, and a failure quotes the check as
written.

**3.1.5** A failure is collected or immediate by context (§2.4).

**3.1.6** A check with no `.` and no variable cannot fail (`claim(x, TRUE)`, a
one-arm `if="TRUE"`). It is a tier-1 lint error.

**3.1.7** A phrase is guarded by a one-arm `if` (1.5.5). There is no function
form.

**3.1.8** A guarded bracket is prose (1.5.15), so a numeral inside it must be
its own value. The idiom is to wrap the trigger word, or the clause, and nest
what is computed.

```
[All]{if="all(mod$rising)"} `r nrow(mod)` models rise
[All `r nrow(mod)` models rise]{if="all(mod$rising)"}
```

**3.1.9** A guarded bracket longer than a set token count is listed (tier 2).

**3.1.10** `claim(x)` with no check is an error. Written in prose or in an
attribute value, it is a construct error found from the source (§5.3).
Anywhere else it stops at run time.

### 3.2 Function forms

**3.2.1** The markup exists in prose. In R code a construct has a function:

| Prose | R |
|---|---|
| `[…]{n="…"}` | `plural(n, "a person", "# people")` |
| a formatter or text class `.x` | `fmt_x()` (§3.4) |
| `claim(x, …)` in the expression | `claim(x, …)` |

**3.2.2** `plural()` takes its arms as separate arguments, in the order a span
writes them, and allows the same counts (§1.6):
`plural(k, "never", "once", "twice", "# times")`.

**3.2.3** `if` and `sign` spans have no function. In R code an `if` is R's
own, and a `sign` span is written as markup in a `weft_str()` string.

### 3.3 `lookup()` and `brk()`

**3.3.1** A phrase chosen by key or by range is an ordinary function call in a
value: `` `r tier_lab(tier)` ``, `` `r trend(foo)` ``.

**3.3.2** `lookup()` builds a keyed function from a named vector. The function
takes a string or a factor (by label, never by integer code) and errors on a
key it does not hold.

**3.3.3** `brk()` builds a range-to-phrase function from formulas:
`brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")`.

**3.3.4** A named `lookup()` or `brk()` is a stipulation and belongs in the
dictionary (§4).

**3.3.5** Given `NA`, a `lookup()` or `brk()` function raises the "no value"
failure of 1.3.4. It never falls through to a default phrase, such as a
`TRUE ~` formula.

### 3.4 Formatter functions

**3.4.1** Every formatter class `.x` has a function `fmt_x()`: `fmt_num()`,
`fmt_pct()`, `fmt_word()`, `fmt_and()` and so on.

**3.4.2** A formatter function returns a `weft_text`: a character vector whose
attributes hold the printed record (1.4.11). Passing one to another formatter
function carries the record forward.

**3.4.3** `glue_vec()`, the collapse engine behind `.and`, `.or`, `.pairs` and
the list formatters, is exported.

### 3.5 Phrase functions

**3.5.1** Wording that is fixed by arithmetic is a function called in a value.

| Function | Prints |
|---|---|
| `of_n(k, n, "site", "sites")` | "none of the 4 sites", "the only site", "both sites", "all 5 sites", "3 of the 7 sites" |
| `about(x, to = 1/2)` | "nearly half", "just over half", "half" |
| `ci(est, lo, hi)` | "2.1 (95% CI 1.3 to 2.9)" |
| `pm(est, se)` | "2.1 ± 0.3" |
| `clamp(x, floor, ceiling)` | "< 0.01", "> 99" for a value outside the bounds |

**3.5.2** `of_n()` returns `k` as its number as printed, so a following `n`
span agrees with it.

**3.5.3** `about()` takes a `tolerance` argument and `ci()` a `level`
argument. Their defaults are configuration settings (§9.1), as the default
digits are. A project that stipulates them in its dictionary passes
`level = dict$ci_level`. `ci()` writes "to" between the bounds.

**3.5.4** `clamp()` sets the relation in the printed record, as `.p` does.

**3.5.5** Not built: fractions and multiples in words ("two-thirds", "twice")
come from `nombre`; compact and signed numbers ("1.2 million", "+3.2%") come
from `scales`, registered as a project formatter (1.4.8).

**3.5.6** Deferred: `drange()` for date ranges ("3–5 June 2024") and `dur()`
for durations ("2 years and 3 months").

### 3.6 `weft_str()`

**3.6.1** `weft_str()` renders a markup string, for the text slots no chunk
option reaches: `ggplot2::labs()`, a `gt` footnote or column label,
`knitr::kable(caption = )`, text printed with `results: asis`.

**3.6.2** The lints read a literal string passed to `weft_str()` as prose.

**3.6.3** A string given to `weft_str()` is prose wherever it is called from.
During a knit, a failed check in it is collected as one in a paragraph is
(2.4.1). Outside a knit it stops at once.

---

## 4. Dictionary

### 4.1 The object

```r
dict$era_split
dict_local$sites       # a chapter's own entry, deliberately a different accessor
```

**4.1.1** `dict` holds the project's stipulations. `read_dict("dict.yml")`
constructs one. In a knit, weft creates `dict` when the knit is initialised
(2.1.5).

**4.1.2** `$` on a `dict` errors on any name that is not an exact key. It
never returns `NULL`, and never matches partially.

**4.1.3** Keys are valid R symbols. `file` is reserved.

**4.1.4** Chunk code may not assign to `dict` or redefine one of its keys
(tier 1, §5.8).

### 4.2 Entries

```yaml
era_split:
  value: 2014
  type: year
  definition: "Boundary between the manual and instrument eras."
  decision: 31

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

**4.2.1** An entry has a `value`, a `type` and a `definition`. `unit` and
`decision` are optional.

| `type` | `value` is | Read as |
|---|---|---|
| `number` | a number | a number |
| `quantity` | a number, with a `unit` | a number that prints with its unit (§4.4) |
| `year` | a four-digit year | an integer; never given a thousands mark |
| `date` | an ISO date | a `Date` |
| `string` | text | a string |
| `labels` | a map from key to phrase | a `lookup()` (3.3.2) |
| `breaks` | a list of bound and phrase | a `brk()` (3.3.3) |

Any other `type` is an error when the dictionary is read.

**4.2.2** A dictionary holds stipulations, never derivations: things that were
chosen. Anything computable belongs in the pipeline.

**4.2.3** A `type: labels` entry is returned as a `lookup()` (3.3.2).

### 4.3 Local entries

**4.3.1** A chapter may narrow a key. The local entry is read through
`dict_local$sites`, never `dict$sites`.

**4.3.2** `dict_local$x` with no local `x` is an error. `dict$x` where the
chapter defines a local `x` is an ambiguity error.

**4.3.3** A local entry requires a `why:` field, and each one is a baseline
item (§6.5).

**4.3.4** A chapter's local entries are written in its front matter, under
`weft:` / `dict_local:`, in the form of §4.2 plus the `why`.

### 4.4 Quantities

**4.4.1** A `type: quantity` entry prints with its `unit`.

**4.4.2** The unit follows the digits. It is printed when the value prints as
digits, and not when a wording class has turned it into a word ("three", not
"three m"): a unit symbol belongs with a numeral, and a spelled number takes
the unit's name, which the author writes.

**4.4.3** A collapse prints the unit once, after the last number: "3–5 m",
"3, 5 and 7 m". `.pairs` and the list formatters print it with every number.

**4.4.4** `#` in an arm never carries the unit, and the printed record
(1.4.11) does not hold it. A quantity that governs a span is written with its
unit's name in the arms: `[# metre | # metres]{n="dict$core_len"}`.

### 4.5 Decision pointers

**4.5.1** `decision:` points at wherever the project records decisions. It is
resolved by a configured resolver (§9.1): a GitHub issue number in the
repository's remote (the default), a file glob (`decisions/{id}*.md`), or a
project function.

**4.5.2** Pointers are checked only in `verify()` (§8). One that does not
resolve fails it (tier 1).

### 4.6 The pipeline

```r
# _targets.R
dict <- weft::read_dict("dict.yml")        # the same object prose reads
list(
  tar_dict("dict.yml"),
  tar_dict_deps(list(
    tar_target(era_fit, fit_eras(obs, split = dict$era_split))
  ))
)
```

**4.6.1** `tar_dict()` returns a file target for the YAML and one target per
key, holding the value only.

**4.6.2** `tar_dict_deps()` walks each target's command, and the functions it
calls, for `dict$key` and `dict[["key"]]`, and sets the per-key targets as
that target's dependencies explicitly.

**4.6.3** A changed value re-runs exactly the targets that read it. A changed
definition, a new key or a reorder re-runs no consumer.

**4.6.4** An unknown key errors when the pipeline is defined, before anything
runs.

**4.6.5** A `.qmd` rendered by `tar_quarto()` is scanned for `dict$key` the
same way.

**4.6.6** Dynamic access (`dict[[k]]`) and a bare `dict` depend on the whole
dictionary.

### 4.7 Generated from the dictionary

**4.7.1** The glossary is generated from `definition:`.

**4.7.2** `dict_vale()` writes Vale terminology rules from the canonical
spellings.

---

## 5. Lints

### 5.1 General

**5.1.1** Each lint ships as a function returning a structured result, and as
an entry in the gate (§6.4) or in `verify()` (§8).

**5.1.2** Every lint and check declares a tier.

| Tier | Mechanism | Behaviour |
|---|---|---|
| 1 | hard rule, decidable from the source or from one evaluation | fails: the commit, the render or `verify()`, as stated |
| 2 | heuristic trigger on newly added material | listed in the integrity report (§6.6); blocks nothing |
| 3 | human read | a ranked worklist; never adjudicated |

**5.1.3** The lints read the prose of each source file, the captions written
in chunk options, the literal strings passed to `weft_str()`, and the
front-matter fields of 1.10.7 in every metadata block (2.10.6).

**5.1.6** The phrases of a `lookup()` or `brk()` written in a document's chunk
are read for numerals (§5.2): a numeral in a phrase usually repeats a bound
that the same call computes with. Their claim words are not listed, because
the call that chooses the phrase is the guard (5.5.2). Phrases held in the
dictionary or in a package's R code are not read.

**5.1.4** Constructs come from the scanner (2.10.2), prose tokens from
Pandoc's tree (2.10.3). What a lint skips is decided by node type: code, math,
link target, raw block. There are two exceptions. A citation bracket is
recognised by pattern (2.10.4). The numeral rule reads math (5.2.6).

**5.1.5** Tier 2 scopes to newly added material, not to the corpus.

### 5.2 Numerals — tier 1

**5.2.1** Every numeral in prose is a value, or sits inside a `cite` span or a
`.weft-literal` span or block.

**5.2.2** A numeral is judged at character level, word by word. A word whose
first letter-or-digit is a digit is a numeral, whatever follows it: "12",
"−0.5", "45%", "11-year", "3rd", "1990s", "10x". A word whose first
letter-or-digit is a letter is a name, whatever digits it contains: "CO2",
"PM2.5".

**5.2.3** The numerals a document holds when the lint is adopted are baseline
items (§6.5). The rule fails on a numeral the baseline does not list.

**5.2.4** Two exemptions are configurable (§9.1). A numeral that follows a
label word is exempt by default; the shipped words are Figure, Fig., Table,
Chapter, Section, Equation, Appendix, Box and Part. A four-digit year is not
exempt by default: a year in prose is often a stipulation that belongs in the
dictionary.

**5.2.5** A `.weft-literal` mark exempts numerals only. Every other prose lint
still reads the marked text.

**5.2.6** The numeral rule reads inline and display math. A numeral that is an
exponent or a subscript, directly after `^` or `_` or inside the braces that
follow one, is exempt. A value inside math is written as inline R inside the
dollars. A `.weft-literal` span around the whole formula exempts it. An
attribute block inside math is a construct error.

```
$p = 0.02$                          fails: 0.02 is a typed number
$p = `r p_val`$                     a value inside math
$x^2 + \beta_{1}$                   exempt: an exponent and a subscript
[$\bar{x} = \frac{1}{n} \sum x_i$]{.weft-literal why="definition of the mean"}
$p = `r p_val`{.p}$                 construct error
```

### 5.3 Construct errors — tier 1

**5.3.1** A construct error is found from the source by the scanner, without
running R. The gate fails on one, and a render stops at one (2.6.5).

- more than one of `n`, `if`, `sign`, `cite` in one block; any of them on a
  value (1.1.5, 1.3.3)
- a code span that opens with `r` and a line break (5.3.4)
- a single-quoted value, or a `"` or `\` inside a value (1.2.3, 1.2.9)
- an inline expression, or the value of `n`, `if` or `sign`, that does not
  parse as R (5.3.5)
- `claim()` with no check (3.1.10)
- a bare-form `cite` value that is not keys only; a key outside Pandoc's key
  grammar; a formatter class on a `cite` span; an `#id` on a `cite` span
  (1.8.4, 1.8.5, 1.8.7, 1.7.5)
- two classes from one at-most-one group; `digits` with `sigfig` (1.4.2, 1.4.7)
- `.ul`, `.ol` or `.dl` on a value that is not alone in its paragraph (1.4.6)
- a wrong arm count for the key, or for the document's language (1.5.2, 1.6.4)
- an `n` span with more than one arm under a `lang` that is not shipped (1.6.5)
- a wording class, a collapse class that prints a word, `.a` or a phrase
  function that prints words, under a `lang` whose words are not shipped
  (1.6.8)
- a formatter on an `if` span (1.5.7)
- an unescaped arm separator in a pipe-table cell (1.5.13)
- `n="."` outside an `n` or `sign` span (1.7.2)
- a duplicate id; a back-reference to an id that is unknown or defined later
  (1.7.5, 1.7.10)
- a `.weft-literal` with no `why` (1.8.10)
- a caption or a front-matter field that contains a construct and is not a
  YAML block scalar (1.10.3, 1.10.7)
- a construct in the caption of a chunk with `cache: true`, `eval: false` or
  an engine other than R (2.3.5)
- a construct in `title` in a book or a website (1.10.11)
- an attribute block inside math (5.2.6)

**5.3.2** Five errors need the value and are found only at knit time: a
governor of the wrong type (1.5.1, 1.5.11), `.a` on text that is not a number
(1.4.5), `.range` on a value that is not of length 2, a wording class on a
number that is not whole and non-negative (1.4.12), and a `sign` governor that
prints as a bound (1.5.17). They are not construct errors, and none of them
stops the render. Each is a collected failure with a marker (2.6.8, 2.6.9),
and the render fails at the end with all of them listed, as it does for
failed checks. A missing value is collected the same way (1.3.4).

**5.3.3** Three tier-2 warnings sit beside them.

- A bracketed span with an unescaped `|` between its words and no governor key
  is listed as a probable construct.
- An `if` whose condition compares a value with zero is listed as probably
  wanting `sign`.
- A class or key on a weft construct that is not weft's (1.2.5), not one of
  Pandoc's (`.smallcaps`, `.underline`, `.mark`, `custom-style`), and not
  listed in the configuration as a name the project expects (9.1.2) is
  listed. The report gives the nearest weft name when one is close.

**5.3.4** knitr reads inline R only when `r` is followed by a space on the
same line. A code span that opens with `r` and then a line break is left by
knitr as literal code, and prints its expression. It is a construct error,
with or without an attribute block, and the `weft-check` filter fails on a
code span whose text begins `r ` (2.5.3).

**5.3.5** An inline expression, or the value of `n`, `if` or `sign` other than
a back-reference (1.7.6), that does not parse as R is a construct error found
from the source. knitr stops on such an expression before any weft hook runs.

### 5.4 Marker spans and citations — tier 1

**5.4.1** Every key of a `cite` span follows Pandoc's key grammar and resolves
in the bibliography. This is checked statically, and again at knit time.

**5.4.2** The block that holds a `cite` span in the bare form cites each of
its keys, as `@key`, `-@key` or `@{key}`. The block is the innermost one in
Pandoc's tree: a paragraph, a list item, a table cell, a footnote or a
caption. A span in the citation form meets this by what it emits. This check
is static only.

**5.4.3** Every citation key in the document resolves in the bibliography.

**5.4.4** The bibliography is every file named by `bibliography:`, and every
entry under `references:`, in the document's front matter and in the project
(`_quarto.yml`, `_metadata.yml`), plus any file named by `bibliography:` in
the configuration (§9.1). At knit time the project's part comes from Quarto's
merged metadata (2.1.6); the static check reads the files.

**5.4.5** Keys are read in R from BibTeX, BibLaTeX, CSL JSON and CSL YAML
files. Pandoc is not called for this.

**5.4.6** Under rmarkdown, a bibliography given only through `pandoc_args` is
not seen. It is named in the configuration.

### 5.5 Claim words — tier 2

**5.5.1** Number words, quantifiers, extrema and direction words ("two",
"all", "none", "only", "largest", "rose", "majority") are listed in two cases:
a claim word in the same sentence as a value, and a claim word in a newly
added sentence with no value at all.

**5.5.2** A claim word inside an `if` or a `sign` span is guarded, and is not
listed. An `n` span chooses a plural form and checks nothing about the words,
so a claim word inside one is listed as it would be outside.

**5.5.3** The list is capped. Beyond a set number of added sentences it gives
a count.

**5.5.4** The lexicon ships with the package and is configurable.

### 5.6 Value expressions

**5.6.1** A value whose whole expression is a literal (`` `r 10` ``) is
allowed. Each one is a baseline item (§6.5), so a new one fails the commit
until the baseline lists it (tier 1).

**5.6.2** A numeric constant inside a computation (`x * 100`) is listed
(tier 2).

**5.6.3** Constants inside the check arguments of a `claim()` call are exempt.

**5.6.4** A value whose outermost call is `round()`, `signif()`, `format()`,
`formatC()`, `prettyNum()` or `sprintf()` is listed (tier 2). It formats
outside the stages, so it has no printed record, and `round()` drops trailing
zeros ("1.50" prints "1.5").

### 5.7 Cross-references

**5.7.1** Book-wide, because ids share one namespace. Tier 1:

- every reference resolves to an anchor; no anchor is defined twice
- no governed span's text matches a defined reference-link label
  (`[foo]: url`), which Pandoc would read as a link

**5.7.2** Tier 2: a figure, table or equation anchor that is defined and never
referenced.

### 5.8 Hygiene

| # | Rule | Tier |
|---|---|---|
| 1 | every section has an explicit anchor, and every chunk a label | 1 |
| 2 | every `tar_read()` and `tar_load()` names a target in the manifest | 1 |
| 3 | chunk code does not assign to `dict` or redefine one of its keys | 1 |
| 4 | internal file links resolve | 1 |
| 5 | in a document activated from a setup chunk, no construct sits above that chunk | 1 |
| 6 | every `dict$key` and `dict_local$key` read names a key that exists, under the rules of §4.3 | 1 |
| 7 | a chunk that reads a pipeline target (`tar_read()`, `tar_load()`) does not have `cache: true` | 1 |
| 8 | no `weft:` key in `_quarto.yml` or `_metadata.yml` (9.1.1); where `_weft.yml` exists, no `draft` and no part switched off in a document's front matter (9.1.4) | 1 |

### 5.9 Figures and tables

**5.9.1** Tier 1: every figure has a label, a caption and alt text; every
table has a caption.

**5.9.2** A caption is prose, whether it is written in a chunk option or in a
figure or table div. Every prose lint applies to it.

**5.9.3** The package does not write alt text, and does not judge whether alt
text describes the figure.

### 5.10 Sentence starts — tier 2

**5.10.1** At knit time the `text` hook lists every value, bare or not, and
every span whose printed text opens a sentence with a digit or a lowercase
letter. A project can configure the list to fail the render.

---

## 6. Gate, baseline and report

### 6.1 Identities

**6.1.1** The gate compares identities, never text.

| Node | Identity |
|---|---|
| a cross-reference anchor | the anchor |
| a section | its explicit `{#sec-…}` anchor |
| a chunk | its label |
| a construct with an `#id` | the id |
| a value without one | its parsed expression and its formatter classes |
| a governed span without one | its key and the parsed value of that key |
| a `cite` span without one | its keys and its bracket text |

**6.1.2** Arm text is not part of a governed span's identity. The text of a
`cite` span is: it is the quoted number, so `[10]` changed to `[12]` is a
removal and an addition. Neither is the order or the
quoting of an attribute block.

**6.1.3** The ledger uses the same identities (§7.1).

### 6.2 Removals — tier 1

**6.2.1** A removal is one of:

- an anchored section, a labelled chunk or a referenced anchor that no longer
  exists
- a construct identity whose count falls in a file and does not rise by as
  much elsewhere in the range of commits being compared

**6.2.2** An identity removed and another added in the same paragraph is an
edit, not a removal.

**6.2.4** "The same paragraph" is decided between the two versions of a file
like this. Within each anchored section the two sequences of paragraphs are
aligned, with the paragraphs whose words are unchanged fixing the alignment.
Between two fixed points, an old paragraph and a new one are the same
paragraph when they share at least half of their distinct words. Paragraphs
left over are then compared across sections on the same test, with a higher
threshold, so that a moved or re-anchored paragraph is still recognised.
Anything still unpaired has no counterpart: an identity that was in it is
removed, or added.

**6.2.5** Two paragraphs with the same words are still compared construct by
construct. Re-wrapping the lines of a paragraph changes nothing; a paragraph
whose words survive and whose constructs do not is a removal.

**6.2.6** A caption, a list item, a table row and a footnote are each a
paragraph for this purpose.

**6.2.3** Every removal must be acknowledged (§6.3). Nothing else is declared:
additions, edits, moves and renames are reported (§6.6).

### 6.3 Acknowledgements

**6.3.1** Acknowledgements are entries in an authored, append-only file,
`weft/removals.yml`. An entry gives the file, the identity and a note.

**6.3.2** A removal passes when the commit, or the range, also adds its entry.
There is no commit-message trailer.

**6.3.3** A change to an existing entry, or the deletion of one, fails the
gate (tier 1).

### 6.4 The hook

**6.4.1** The gate is a `pre-commit` hook, installed by `use_hooks()`.

**6.4.2** It runs the tier-1 static checks only: construct errors, numerals
and literals against the baseline, removals against the acknowledgements,
marker spans and citations, cross-references, hygiene and figure presence. It
does not knit, and it does not use the network.

**6.4.3** It reads the index (`git show :<file>`), not the worktree.

**6.4.4** `use_hooks()` records the paths of R and of Pandoc, and the hook
uses those. It calls the Pandoc binary itself, not `quarto pandoc`.

**6.4.7** The hook reads the staged files that changed, and for the removal
check their versions in `HEAD`. What it needs from the rest of the book (the
anchors and the reference labels) comes from a cache of each file's scan,
keyed on the file's git blob hash and kept under `.git/`.

**6.4.8** The hook prints how long it took.

**6.4.5** One executable prints one report. Where the gate can tell that
removing an anchor strands references, it lists them.

```
pre-commit: removal not acknowledged

  14-percentile-bands.qmd  #sec-prov  removed

  2 values no longer appear anywhere in this commit
      `r band_cut$lower`
      `r band_cut$upper`

  removing anchor `tbl-prov-bands` strands 3 references
      15-revised-rating.qmd:88   @tbl-prov-bands
      17-management-arms.qmd:204 @tbl-prov-bands
      17-management-arms.qmd:251 @tbl-prov-bands
```

**6.4.6** `--no-verify` bypasses the hook.

### 6.5 The baseline

**6.5.1** The baseline is a committed file, `weft/baseline.tsv`, that lists
every tolerated item: its kind, its file, its source text, and how many times
it occurs there.

| Kind | Item |
|---|---|
| numeral | a bare numeral in prose at adoption (5.2.3) |
| literal value | a value whose expression is a literal (5.6.1) |
| marked literal | a `.weft-literal` span or block (1.8.10) |
| local entry | a `dict_local` entry (4.3.3) |
| condition | a known condition (7.4.3) |

**6.5.2** An item that is not in the baseline fails until the same commit adds
it (tier 1). Condition items are checked by `verify()`; the rest by the hook.

**6.5.3** A swap is caught: removing one literal and adding another adds an
item the baseline does not hold. The exception is a swap between two items
with the same text in the same file.

**6.5.4** Items are sorted, one per line.

**6.5.5** An item whose text has gone from its file, or whose count has
fallen, is **stale**. The hook passes with stale items and says how many there
are; it never writes to the baseline. `baseline_prune()` removes them.
`verify()` fails while any remain (tier 1), because a stale item would let the
same text come back unlisted.

### 6.6 The integrity report

**6.6.1** `verify(range = )` compares two commits and writes the integrity
report. It lists:

- removals, each with its acknowledgement
- additions to the baseline, by kind
- edited constructs (6.2.2), each with its expression before and after
- constructs whose expression changed under an unchanged `#id`
- checks loosened or removed, each with its before and after
- guards made optional (a one-arm `if` that gained an empty arm)
- computed values replaced by literals
- new conditions (7.4.4)
- ledger must-reads and their acceptances (7.3.3)
- tier-2 findings on the added material

**6.6.2** A check is compared across versions by pairing constructs: by `#id`
where there is one, otherwise as the two sides of an edit (6.2.2). The
`claim()` calls are parsed out of each expression and the conditions out of
each guard.

**6.6.3** The same call checks a pull request.

### 6.7 CI

**6.7.1** `use_ci()` writes a workflow that runs `verify(range = )` on each
pull request. GitHub Actions is the default.

---

## 7. Ledger and conditions

### 7.1 The ledger

**7.1.1** The `text` hook records every value, governed span and `cite` span
as it renders: identity, expression, printed text with its relation, raw
value, file, section, and for a governed span the arm chosen.

**7.1.2** There is one JSON-lines file per source file, under
`generated/ledger/`. The ledger is committed.

**7.1.3** A line is keyed on the construct's `#id`, or on its section anchor,
its identity (§6.1) and its occurrence index within the section. Line numbers
are not stored.

**7.1.5** Lines are sorted by key, one construct per line, so a merge conflict
is local to the constructs both sides changed. The ledger is output: a
conflict is resolved by rendering the chapter again, never by hand.

**7.1.6** Inserting a construct above another with the same identity in the
same section shifts the occurrence index, and each later one is then compared
with its predecessor's entry. Where the printed text differs, that shows as a
change to review. It cannot hide a change. An `#id` removes it.

**7.1.4** A ledger entry has **changed** when its printed text or its chosen
arm differs. Raw values are stored to a fixed number of significant figures,
and are used only to rank changes.

### 7.2 Three states

**7.2.1** An entry is *unchanged*, *changed*, or *not re-rendered*: its
chapter was not rendered, or was served from freeze, since something it
depends on changed.

**7.2.2** The ledger records which pipeline targets each chapter reads, from
`targets`.

**7.2.3** `verify()` reports entries that were not re-rendered ("chapter 17:
34 values not re-rendered since `fit_reband` changed"), and does not pass
(tier 1).

### 7.3 Review

**7.3.1** `ledger_review()` shows each change as the sentence before and
after, ranked.

**7.3.2** A change is a **must-read** when it is structural: a sign flip, an
order-of-magnitude change, crossing zero, crossing 1.0, crossing a dictionary
threshold, or a governed span choosing a different arm.

**7.3.3** Acceptances are recorded in an authored file, `weft/accepted.yml`.
`verify()` fails on a must-read that has not been accepted (tier 1).

**7.3.4** Other changes are a ranked worklist (tier 3). A change to a value
next to a claim word ranks above one that is not.

### 7.4 Conditions

**7.4.1** The condition log is machine-readable and sits beside the ledger. It
has four sources:

- chunk conditions, from the `evaluate` hook (2.8.1)
- conditions raised by values in prose (2.8.2)
- for a chunk served from knitr's cache, the conditions logged when it was
  computed, stored under the chunk's cache hash and replayed
- the warnings and errors that `targets::tar_meta()` holds for each target a
  chapter reads, and for the targets upstream of those. `tar_meta()` stores no
  messages, so a message raised inside a target is not seen (§15).

**7.4.2** A **severity list** of patterns decides which conditions fail the
render (tier 1). It ships with patterns for the model-fit conditions that do
not stop a fit: `lme4`'s singular fit, which arrives as a message, and
`glmmTMB`'s non-positive-definite Hessian, which is a warning. It is
configurable. A message is matched only where it is logged: in a chunk or in
prose, not inside a target (7.4.1).

**7.4.3** Every other condition is either known or new. A known condition is
a baseline item (§6.5).

**7.4.4** A new condition fails `verify()` until the baseline lists it
(tier 1). An ordinary render reports it and carries on.

**7.4.5** A condition is matched to the baseline by its source (chunk label or
target name), its class (warning, message or error) and its text after
normalising. Normalising, in order:

1. remove ANSI styling
2. replace hexadecimal addresses and R's temporary paths with a placeholder
3. replace every number (digits with any sign, decimal part or exponent) with
   a placeholder
4. turn curly quotes into straight ones, and `cli`'s bullets and rules into
   their ASCII forms
5. collapse every run of whitespace, including line breaks, to one space

**7.4.6** The baseline keeps the text as first seen beside the normalised
form, so a reader sees a real message.

**7.4.7** Two limits are accepted. Messages that differ only in a number
match, so "Removed 5 rows" and "Removed 5000 rows" are one item. A message
translated by the session's language, or reworded by a package upgrade, is a
new condition.

---

## 8. `verify()`

**8.1** `verify()` is the one entry point for everything that needs a render.
It runs, in order:

1. every static lint, at every tier (§5), and the gate's comparison (§6)
2. the `decision:` pointers (4.5.2)
3. the render, re-executing every document it verifies (8.3)
4. the knit-time results: failed checks, unevaluated constructs, documents
   served from freeze, conditions (§2.6, 2.5.2, 2.9.3, §7.4)
5. the ledger: entries not re-rendered, and must-reads not accepted (§7)
6. the integrity report, when a range is given (§6.6)

**8.2** `verify()` takes `files =` to verify some documents, and `range =` to
compare two commits. With no range it compares the working tree with `HEAD`,
as the hook would if everything were staged, and writes no integrity report.

**8.3** The render step re-executes each document once:

1. if a backup from an earlier run exists, restore it first
2. copy the documents' entries in `_freeze` to a backup, and remove the
   originals
3. run one ordinary project render
4. on success, delete the backup; on failure, restore it

**8.4** The freezer is left holding the verified results, so the next ordinary
render serves what was checked.

**8.5** `verify()` refuses to run in draft mode (§9.4).

**8.6** Each part can be switched off in the configuration. `verify()` reports
which parts were skipped, and why.

**8.7** Rendering needs no wrapper: `quarto render`, an editor's Render button
and `rmarkdown::render()` all run the hooks.

---

## 9. Configuration, activation, installers, draft mode

### 9.1 Configuration

**9.1.1** Project configuration is `_weft.yml` at the project root. A
document overrides it with a top-level `weft:` key in its front matter.
weft merges the two setting by setting, except as 9.1.4 says. A `weft:` key
in `_quarto.yml` or `_metadata.yml` is an error found from the source (5.8
rule 8), and its message names `_weft.yml`.

**9.1.2** It sets:

| Setting | Governs |
|---|---|
| default digits; decimal and thousands marks; the minus sign | the number formatters |
| whether `.pct` reads its value as a proportion (the default) | `.pct` |
| the `.count` threshold; the `.word` limit | `.count`, `.word` (1.4.12) |
| the level of `ci()`; the tolerance of `about()` | 3.5.3 |
| `dict_local` (front matter only) | 4.3.4 |
| `bibliography`, for files the front matter and the project do not name | 5.4.4 |
| the date format | `.date` |
| `draft` (project only where `_weft.yml` exists) | §9.4, 9.1.4 |
| the severity list | 7.4.2 |
| numeral exemptions: label words, four-digit years | 5.2.4 |
| the claim-word lexicon | 5.5.4 |
| the classes and keys the project expects on a construct, from other systems | 5.3.3 |
| the `decision:` resolver | 4.5.1 |
| parts switched off (project only where `_weft.yml` exists) | 8.6, 9.1.4 |
| the package version | 9.5.4 |

**9.1.3** The configuration is read when a knit is initialised (2.1.5), not
when the hooks are installed.

**9.1.4** `draft` and the parts switched off are project settings. Where a
`_weft.yml` exists, either one in a document's front matter is an error,
found from the source (5.8 rule 8) and when the knit is initialised. A single
document with no `_weft.yml` may set them in its front matter. `WEFT_DRAFT=1`
is unchanged (9.4.1).

### 9.2 Activation

**9.2.1** There are three places to activate a document.

| Where | What is written | Covers |
|---|---|---|
| the document's front matter | `knitr:` / `opts_knit:` / `weft: !expr weft::weft_setup()` | one document, under Quarto and rmarkdown |
| `.Rprofile` at the project root | `if (requireNamespace("weft", quietly = TRUE)) weft::weft_setup()` | every document in a Quarto project, wherever it sits |
| a setup chunk | `weft::weft_setup()` | the prose below that chunk |

**9.2.2** The `weft:` key under `knitr: opts_knit:` only carries the
activating call. It is not the configuration key of 9.1.1.

**9.2.3** There is no `_quarto.yml` route, and no project-wide route under
rmarkdown.

**9.2.4** Inline R in a YAML field is not a route.

**9.2.5** Prose above a setup chunk that calls `weft_setup()` is not
processed. The backstops of §2.5 catch it, and a lint forbids it (§5.8).

**9.2.6** Attaching the package is not a route (2.1.3): `library(weft)` in a
setup chunk activates nothing.

**9.2.7** Under rmarkdown, each document also names the `weft-check` filter
in its front matter (2.5.3). `use_setup()` writes the filter line beside the
activating one.

### 9.3 Installers

**9.3.1** Every file the package places exists because a `use_*()` function
was called. Each says what it will write.

| Function | Writes |
|---|---|
| `use_weft()` | everything below, with a summary first |
| `use_setup()` | the `.Rprofile` line (Quarto project) or the front-matter line (single document); `_weft.yml`; under rmarkdown, the `weft-check` Lua filter and the `pandoc_args` line that names it (2.5.3) |
| `use_quarto()` | the `weft-check` Lua filter as a project extension; the `pre-render` and `post-render` scripts |
| `use_hooks()` | the `pre-commit` shim, with the paths of R and Pandoc; `weft/baseline.tsv`; `weft/removals.yml`; `weft/accepted.yml` |
| `use_ci()` | the CI workflow (6.7.1) |
| `use_dictionary()` | a dictionary skeleton and its schema |
| `use_agent_docs()` | agent-facing conventions and the Claude skill |

**9.3.2** The hooks alone write nothing. The condition log, the ledger and
the failure files are written only in a project that has been set up with
`use_weft()`.

**9.3.3** `inst/` holds the hook template, the Lua filter, the render scripts,
the dictionary schema, the default claim-word lexicon and severity list, and
the Claude skill (never loosen a check to clear a failure; acknowledge
removals in the file; the `dict_local` rules).

### 9.4 Draft mode

**9.4.1** Draft mode is `draft: true` in the configuration, or the environment
variable `WEFT_DRAFT=1`.

**9.4.2** In draft mode nothing fails the render. The markers appear in the
output, the failures are listed in the knit log, and in a project that has
been set up they are written to a JSON file beside the document.

**9.4.3** Draft mode covers the render only. Knit-time failures, and
construct errors met during a render, are reported and marked (2.6.8), not
fatal. The `weft-check` filter reads the same setting, and reports instead of
exiting. The `pre-commit` hook is not affected by draft mode, and `verify()`
refuses to run in it (8.5).

### 9.5 Adoption helpers

**9.5.1** `recall_check()`: given recorded findings and a pre-remediation
commit, runs a lint against the historical state and reports what fraction of
the findings it reproduces, and how much else it flags. It is a sanity check
on one lint: a result of none reproduced, or of nearly everything flagged,
sends the lint back to design. It does not rank layers and does not remove
one.

**9.5.2** `dict_seed()` harvests candidate dictionary keys by finding
constants defined in more than one chapter.

**9.5.3** `status()` reports which parts are installed, which are switched
off, and what the next step is.

**9.5.4** The configuration records the package version. `verify()` warns on
a mismatch.

---

# Part 2 — Rationale

## 10. The problem

Ten failure modes in computational manuscripts, grouped by where the break
happens. The grouping matters: the first group corrupts the value before prose
is involved, and no amount of prose discipline detects it.

### A — the pipeline yields a wrong value

| # | Mode | Met by |
|---|---|---|
| A1 | **Silent success of a failed computation.** A join drops rows, a filter matches nothing, a model fails to converge, and the code carries on. | §7.4, §15 |
| A2 | **Stale or wrong input.** The computation is correct; the data it consumed is not the data intended. | §15 |

### B — the link between value and prose breaks

| # | Mode | Met by |
|---|---|---|
| B1 | **Silent deletion.** A `sed` or heredoc removes a paragraph, a section, or a value. What remains is valid markdown, renders clean, looks fine. | §6.2 |
| B2 | **Reversion to literal.** `` `r pcf(x)` `` becomes the literal `12`. Renders perfectly, forever, silently decoupled from the pipeline. | §5.2, §5.6 |
| B3 | **Staleness.** What was rendered predates what it was rendered from, and everything downstream reports PASS. | §2.9, §7.2 |

### C — the prose is wrong about a correct value

| # | Mode | Met by |
|---|---|---|
| C1 | **Prose/value divergence.** The number updates on refit; the sentence still says "rose sharply" when the value went to −1. | §1.5, §3.1, §7.3 |
| C2 | **Assertion never computed.** A set fact, ranking, direction or comparison is stated that was never calculated. | §1.5, §5.5 |
| C3 | **Misattribution.** Value and sentence are each correct but refer to different quantities. | nothing: tier 3 |
| C4 | **Definitional drift.** The same term carries different meanings in different chapters. | §4 |
| C5 | **Stale shape description.** A caption describes an object's contents, and the object changed. | §1.10, §5.9 |

C2 is typically the largest class, and it is the one a number-focused scheme
misses entirely.

### The failure that shapes the design

Checks whose output nobody reads reproduce the failure they were built to
prevent. In the manuscript that motivated this package, both recorded
incidents were **signal-existed-but-unread**: knitr wrote the warning into the
document, the boundary-fit message was emitted, and both sat in plain sight
for weeks.

**Surfacing beats coverage.** Every check must fail loudly at a checkpoint
someone passes through, or not exist. A printed count is not a checkpoint; a
baseline that a commit must change in order to add to it is.

## 11. Layer labels

The companion plan and the first scoping document number the checks as layers.
This document does not use the labels anywhere else.

| Label | What it is | Rules |
|---|---|---|
| L1 | structural diff: removals are acknowledged | §6.1 to §6.3 |
| L2 | claim tokens: numerals and claim words in prose | §5.2, §5.5, §5.6 |
| L3 | checks: `claim()` and the one-arm `if` | §3.1, 1.5.3 to 1.5.5 |
| L4 | cross-references and citations | §5.4, §5.7 |
| L5 | the value ledger | §7.1 to §7.3 |
| L6 | surfacing: conditions, unevaluated constructs, frozen chapters | §2.5, §2.8, §2.9, §7.4 |
| L7 | prose style | not a package layer: Vale (§16); `dict_vale()` (4.7.2) |
| L8 | hygiene | §5.8 |
| L9 | trailer and register validation | not a package layer: no trailer (6.3.2), no register (§16) |
| L10 | the dictionary | §4, 5.8 rule 6 |
| L11 | figures and tables | §1.10, §5.9 |
| L12 | data contracts in the pipeline | not a package layer: §15 |

## 12. Principles

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

**P9 — Partial coverage beats none, and every check declares its tier.** The
tiers are defined in 5.1.2.

**P10 — Installation is always an explicit call.** Calling `weft_setup()`
changes only the R session: it installs the hooks. Attaching the package or
loading the namespace changes nothing. Every file the package places, and
every file it writes during a render, exists because a `use_*()` function was
called.

**P11 — Every construct is markdown the toolchain already accepts.** The
visual editor must be able to round-trip it, and inline R that already exists
must already count.

**P12 — Check a lint against a real audit before building it, as a sanity
check and nothing more.** A prototype of a lint, run against the recorded
findings of a real audit, can show a major problem: it reproduces none of
them, or it flags nearly everything. That sends the lint back to design before
it is built. The result does not rank layers and does not remove one. One
corpus is not evidence enough for either, and the package is for more than one
project.

## 13. Why the rules are as they are

Each note is keyed to the rule it explains.

### Syntax

**1.1.2** Prose never sits inside an R string, so it stays visible to the
lints, to spellcheck and to the reader of the source.

**1.1.3** The exception is small and closed. The function words a formatter
prints ("and", "of the") are fixed by the package; the phrases of a `lookup()`
or `brk()` are stipulations held in the dictionary, where they are read and
reviewed in one place.

**1.1.4** A document that already uses inline R is already a weft document.
Adoption rewrites nothing. Stock Quarto escapes markdown characters in the
output of `` `{r} x` `` and not in the output of `` `r x` ``, so the two bare
forms are not the same, and each keeps what its author chose.

**1.1.8** The rules about constructs exist for what weft adds to markdown.
Bare inline R adds nothing, so a document with no attribute blocks renders as
it did before weft (1.9.2), wherever its inline R sits.

**1.2.2, 1.2.3** The file is read by four parsers: Pandoc's markdown reader
(the render), Pandoc's position-tracking reader (the lints), the visual
editor's writer, and weft's scanner. They agree on double-quoted and unquoted
values. They do not agree on the rest: the position-tracking reader has a
stricter attribute grammar and does not parse `{n='k'}`, `{if='tier == "sev"'}`
or `{if="tier == \"sev\""}` as attributes at all, and the readers double
backslashes differently. One written form that every parser reads the same way
is worth more than three that mostly work. An expression that needs a double
quote or a backslash is bound to a name in a chunk, which also keeps it short.

**1.2.4** Pandoc's markdown writer, and therefore the visual editor, rewrites
a block to id, then classes, then keys, with every value double-quoted. Order
cannot carry meaning if a save in the editor may change it.

**1.2.6** Pandoc itself turns three span classes into formatting in every
format (`.smallcaps`, `.underline`, `.mark`); `custom-style` works in Word and
CSS classes in HTML. Passing through what weft does not own lets all of those
work on a construct.

**1.2.7** Everything weft does not own is passed through, so that weft works
alongside other systems: a Lua filter, a Quarto extension or a stylesheet may
use any name. A name close to a weft name may be one of theirs, so it cannot
be an error. The lint lists it, and the project's list of expected names
keeps the report short.

**1.2.8** An id is a name for weft's own use: agreement, the gate and the
ledger. Emitting it would put every one into the document's anchor namespace,
where the cross-reference rules and Quarto's reserved prefixes apply.

**1.3.2** A check that ran after formatting would test a rounded number.

**1.3.4, 3.3.5** "Mean depth was NA m" reads as a sentence, and a default
phrase for `NA` is a sentence nobody chose (1.5.3). A bare value is left as
stock prints it, so that a document with no attribute blocks renders as it
did before weft (1.1.8).

**1.4.1** Left-to-right chaining would make meaning depend on the order of
classes (1.2.4), and would allow chains that mean nothing (a collapse before a
number format). Four stages with at most one choice in each give every legal block
one meaning.

**1.4.3** `.strong` and `.em` emit markdown emphasis because Pandoc gives
those class names no meaning. `.pairs` takes names and values from one object,
so their order cannot drift apart.

**1.4.7** The key is `sigfig`, not `sig`, because `sig` reads as an
abbreviation of `sign`. Without a number class, `digits="2"` can
only mean one thing, so it is not made an error.

**1.4.9** A unit belongs to the quantity, not to the way a number is printed.
Held in one place, it cannot differ between two sentences.

**1.4.10** This is what stock knitr does, and a formatter's own output is
markdown. Escaping would break both.

**1.4.11** Arm selection, the ledger and the reports all need to know that
"< 0.001" is a bound.

**1.4.12** "One point five sites" and "minus third" are not things an author
means. Past a limit a spelled number is harder to read than digits.

**1.5.1** The key says what kind of governor it is, and each key fixes its arm
counts, so a wrong count is found from the source without running R.

**1.5.3** The alternative is a default arm, and a default arm prints a
sentence nobody chose.

**1.5.4** As in `dplyr::filter()`. Separate conditions are reported
separately, which `&&` cannot do.

**1.5.5** The guard is the idiom for a phrase whose truth depends on a value
the sentence never displays. It has no function form, because the guarded
words must stay prose.

**1.5.8** With `#`, the number and its noun are one unit and cannot be edited
apart.

**1.5.9, 1.5.10** Agreement follows what the reader sees. A depth of 1.2
printed to zero decimals shows "1" and takes the singular; a value printed as
"1.0" takes the plural, as English does. A change printed as "0.0%" did not
rise.

**1.5.17** `#` in a `sign` arm is the magnitude. For a bound there is none,
and "fell by < 0.1%" beside "rose by < 0.1%" would turn on a sign the printed
text no longer shows.

**1.5.11** A count inferred from a length silently turns a vector of two
depths into "2". For ranges, CLDR's plural-range data gives every English
range the plural.

**1.5.12** The visual editor writes `\|` and `\#` inside a span.

**1.5.13** The render is not the problem: the hooks resolve the span before
Pandoc sees the table. But the source is also read by Pandoc's
position-tracking reader (the lints) and by the visual editor, and their
pipe-table parsers split a row on every unescaped `|` before any span exists.

**1.5.16** An arm written for a case that did not happen may not be
computable in the case that did.

**1.6.1 to 1.6.4** "One" is a grammatical form: in Russian 21 takes it, in
French so do 0 and 1.5. Checking the arm count against `lang` means an arm can
never be one that the language never selects. The exact-two arm is allowed
only after the exact-zero arm so that an arm count has one reading: three arms
in English are always zero / one / other.

**1.6.5** Applying English rules to another language would print wrong
grammar without an error. The rules are a small table generated from CLDR.

**1.6.7** Quarto and Pandoc take tags such as `en-AU`, and R writes locales as
`en_GB`. Plural forms and function words belong to the language, not the
region.

**1.6.8** English words in a French sentence ("les sites A, B and C") are as
wrong as English plural rules (1.6.5), and as silent.

**1.7.4, 1.7.6 to 1.7.8** An R variable names a value; an id names a printed
occurrence. Compute with the variable, agree with the id. With no formatter of
its own, the referring span uses the number as it was printed there, so
agreement follows what the reader saw (1.04 printed as "1" takes the
singular). `#` begins a comment in R, so `"#d"` can never be mistaken for an
expression.

**1.7.5** (`cite` spans) The text of a `cite` span is part of its identity,
because it is the quoted number (6.1.2). An id would keep the identity when
the number changed.

**1.8.1, 1.8.5** A marker that cannot fail is decoration (P1). `cite` can
fail twice, each time against an external referent (P4): the key must exist
in the bibliography, and the paragraph must cite it. It is a span, not a
function, for two reasons. The quoted number is prose, and belongs in a
bracket (1.1.2). And `utils` exports a function called `cite`, so a `cite()`
check would depend on the search path.

**1.8.3, 1.8.4** The citation form writes the citation where the bracket
closes, and nowhere else. Moving it to the end of the sentence would need
sentence detection, which is a heuristic ("e.g.", "et al.", "Fig. 2"), and a
wrong guess would rewrite published text; it would also put a citation where
the author typed none, and merging would hide which number came from which
source. The bare form exists for the in-text case ("Smith (2020) found …"),
where a second citation after the number would be wrong.

**1.8.9, 1.8.10, 5.6.1** A bare `` `r 10` `` is the deliberate escape hatch:
nobody types it by accident, and a rule demanding a check would be met with
`claim(10, TRUE)`. What a literal cannot do is hide. Each one is a baseline
item, a new one fails the commit until the baseline lists it, and a computed
value replaced by a literal is reported. Before writing a literal, ask why the
number cannot be computed: a project constant goes in the dictionary, a count
of things in the document gets counted, an ordinal gets computed. Methods
text, legislation and quotations are dense with numbers that are not data
claims, which is what the block form is for.

**1.8.5** `@{key with spaces}` resolves in a bibliography and is still left
as literal text by Pandoc, so resolving alone does not show that a citation
will print.

**1.8.11** Pandoc writes an unknown attribute into HTML (`data-why="…"`). The
reason belongs to the source and the baseline, not to the published page.

**1.9.2** Stock knitr evaluates inline R inside a fenced block that is not
executed, and inside an HTML comment. A document with no attribute blocks must
render the same with and without weft.

**1.10.3** YAML cuts an unquoted scalar at ` #`, silently, and `#` is what an
arm uses for its number. One written form for every YAML field that holds a
construct, in a chunk option or in front matter, is easier to keep than one
per field (1.10.7).

**1.10.4, 1.10.6** Neither form works (§18). `gt` drops a caption set with
`tab_caption()` from Word output, with or without weft.

**1.10.7** knitr evaluates inline R in the front matter as raw text, before
YAML has decoded its escapes. In a double-quoted scalar `\"` reaches R as two
characters and fails; in a single-quoted one a doubled `''` leaves the span
unresolved with no error. A block scalar has no escapes.

**1.10.9** The abstract holds more claims than any other paragraph, and it is
read before a single chunk has run. Neither Quarto nor Pandoc moves a body
div into the abstract position.

**1.10.11** Quarto reads every chapter's title for the sidebar and the table
of contents without knitting it, so a construct there shows raw in every one
of them.

### Runtime

**2.1.3** A conditional install fails silently when the package was loaded
before the knit began (an `.Rprofile`, or a session that called `library()`
earlier), so installing does not test for a knit. It does not happen on
namespace load, because a pipeline that calls `weft::claim()` must not change
how that session knits (P10). It does not happen on attach, because attaching
happens once per R session: `library(weft)` in a setup chunk activated only
the first knit, and in a loop of `rmarkdown::render()` calls every document
from the second on printed raw spans, with nothing failing. `weft_setup()` in
the same chunk runs on every knit.

**2.1.3** (repeat calls) R evaluates the front matter's `!expr` three times in
one render, once of them while the knit is running.

**2.1.4** The output format sets its own `chunk` hook after the project's
start-up code has run. A wrapper installed at that time would be replaced.
The late install has not been run (§19).

**2.1.5** `weft_setup()` can run from `.Rprofile`, before any document is
being knitted. A child document re-enters the hooks, and initialising it
again emptied the parent's failure records, so a failure above the child was
lost.

**2.1.7** `weft_setup()` can run from `.Rprofile`, so the hooks may be in
place for a knit that is not weft's.

**2.1.6** `knitr::current_input()` under Quarto names an intermediate file,
and asking Quarto about that file loses a book's metadata.

**2.2.1, 2.2.2** Because inline code is parked, weft decides what runs and in
what order. Parking also gives every expression an index within its block.

**2.3.5** knitr resolves a caption after its chunk runs (2.3.1). A chunk that
does not run, or is served from the cache, does not resolve it again, so the
caption prints raw or prints the numbers of an earlier render. A caption div
is prose, and has neither problem.

**2.4.1, 2.4.2** Collecting needs a report at the end, and only a knit under
the hooks has one. Anywhere else a collected failure would be a failure nobody
is told about. A check on a value therefore runs even when nothing else of
weft does.

**2.4.4** `error: true` is a common document-wide setting. Without the record
it would turn every failed check in chunk code into printed text and a passing
render.

**2.4.4** (caught checks) A check is a statement about the manuscript, not a
test to branch on. Wording that depends on a value is written with `if`.

**2.6.8** Markdown emphasis in a marker breaks when the construct already sits
inside bold, and is printed as asterisks where markdown is not rendered, such
as a plot title. Square brackets become a link when "(" follows.

**2.5** A construct that is valid markdown renders as plausible text when
nothing evaluates it, so silence has to be made impossible by other means.
The filter is the one backstop that works when the package was never loaded.
It exits through `os.exit(1)` because under Quarto a Lua `error()` prints but
does not fail the render. rmarkdown gets the filter too, because there the
end-of-document check is itself a hook: when the hooks are missing it does not
run, and nothing else fails.

**2.5.2** A construct in an arm that was not chosen is rightly not evaluated
(1.5.16), so a plain count of constructs would fail every document that has a
nested one.

**2.6.1, 2.6.2** One report with every failure lets the author read all the
affected sentences in one pass. Stopping at the first hides the rest.

**2.6.5** A construct error is found from the source, and nothing rendered
after one can be trusted.

**2.6.6** A failing chapter would otherwise stop the project at that chapter.

**2.7.2, 2.7.5** knitr keeps its own record of block positions, but does not
export it. The search agreed with that record on every block tested (§18).
The chunk-boundary rule is needed for a block that repeats a line of the chunk
above it.

**2.8.1** knitr writes chunk warnings and messages into the rendered
document, or discards them when the author hides them. Neither reaches anyone.

**2.9.2** Freeze is keyed on the source file alone: a change in the data does
not thaw a chapter.

**2.9.4, 2.9.5** A chapter whose render had failed claims is stored in
`_freeze` with its markers, and the second render serves it and passes. The
failure would last one render.

**2.10.2, 2.10.3** Two readers of one syntax can disagree, and Pandoc's
position-tracking reader does disagree with its markdown reader on attribute
blocks (1.2.3). So one reader, the scanner, owns the constructs. Pandoc is
kept for what it does well: telling prose from code, math, links and raw
content in everything that is not a construct.

**2.10.5** Four spaces at the start of a line make an indented code block. A
paragraph that begins with a construct, masked with spaces, became code, and
the lints skipped it. A letter keeps a paragraph a paragraph; the check
catches any case the letter does not, such as `# ` left at the start of a line
inside an arm (Q9).

**2.10.6** The lints read no front matter, and the abstract holds more claims
than any other paragraph (1.10.9). Unmasked, the position-tracking reader read
a late metadata block as a horizontal rule and a heading.

### Functions

**3.1.3, 3.1.4** The error text is the feature: the report quotes the check
the author wrote, next to the value that failed it. `checkmate::test_*` is the
right half of that package to use inside a check, because it returns a
logical.

**3.1.6** The pressure to satisfy a rule with `claim(x, TRUE)` is real.

**3.1.10** `claim(x)` passes every value, and reads in the source as a
checked one.

**3.1.9** The hole that remains in a guard is a long bracket with one loose
check.

**A good bound**, for the documentation: the widest range over which the
sentence stays honest. Too tight and it fires on every refit and gets widened
without thought; too loose and it is inert.

**3.4.1** One naming rule, so the function for a class never has to be looked
up.

**3.5** This wording goes stale silently when it is typed by hand. `of_n()`
prevents "all 2 sites" and "both of the 3". How near is "nearly" is a
setting of the function, like the default digits, and a project that treats
it as a stipulation passes it from its dictionary. `ci()` writes "to" so that
a dash never sits beside a minus sign.

**3.6.1, 3.6.3** A plot title, a table footnote and a `kable()` caption are
prose that no chunk option reaches. A string is prose whoever calls the
function, so a caption built in R fails the same way as one written in a chunk
option.

**3.2.3** A function for each governor would be a second syntax to keep in
step with the first. The markup already works in a string.

### Dictionary

**4.1.2** The key is a plain token in the parsed expression, so a static lint
verifies every read without running R (5.8 rule 6).

**4.2.2** A derivation in the dictionary is a number typed by hand.

**4.3.1, 4.3.2** A paragraph moved to a chapter with no local `sites` errors,
instead of quietly changing meaning.

**4.4.2 to 4.4.4** SI style puts a unit symbol with a numeral and a unit name
with a spelled number. A unit inside `#` would print twice in every arm that
names it.

**4.5.1, 4.5.2** The package keeps no register of its own (§16), so the
pointer goes through a resolver and is tied to no one tracker. The default
resolver needs the network, which a commit hook must not (P6).

**4.6** A stipulation matters most where it is computed with, so the pipeline
reads the same object with the same spelling. `targets` cannot see `dict$key`
as a dependency on one key, so the walker sets it. `tar_outdated()`
over-reports what a dictionary edit will re-run; `tar_make()` is
authoritative. Without 4.6.5 a dictionary change does not re-render the
report.

**4.7** Three things the dictionary removes rather than checks: the glossary,
the unit, and terminology rules.

### Lints

**5.2.1** This also catches B2 mechanically: a value reverted to its literal
*is* a bare numeral.

**5.2.2** Pandoc makes "11-year" one token, so a rule on Pandoc's tokens would
exempt it as a mix of letters and digits. It is a number.

**5.2.3** A rule that fails on every numeral already in a manuscript cannot be
switched on. Baselined, it stops new ones at once and leaves the old ones as a
visible, shrinking list.

**5.2.6** `$p = 0.02$` is a number typed by hand, as it would be outside the
dollars. An exponent or a subscript is notation, not a value. Math reaches
Pandoc as TeX, so a formatter's markdown, or a span weft emits, has no place
inside it; plain inline R prints a bare number, which TeX reads.

**5.3.2** These depend on the data, not on what the author wrote, so they
arrive together after a refit, as failed checks do. Stopping at the first
would hide the rest (2.6.1).

**5.3.5** knitr parses an inline expression before any weft hook sees it, so
weft cannot collect a syntax error. Found from the source, it is named with
its line before the render starts.

**5.3.4** An editor's re-wrap does this without the author typing anything,
and the page then shows R code where a number was.

**5.3.3** A misspelt governor key (`[a site | # sites]{count="k"}`) leaves an
ordinary Pandoc span that prints both arms. An `if` on a sign has no arm for
zero and no rule for a value that prints as zero.

**5.5** Claim words carry a data claim often but not reliably, so they are
tier 2.

**5.7** The check is that a reference *resolves*, not that the target still
says what the citing sentence claims. That is tier 3.

**5.8 rule 1** A heading that contains a construct has no stable automatic
id, so the explicit anchor matters twice.

**5.8 rule 7** knitr builds a chunk's cache key from its code and options, not
from the target's value, so a cached chunk serves the old target after the
pipeline has changed it.

**5.8 rule 8** See 9.1.1 and 9.1.4.

**5.10.1** A recomputed value can open a sentence with a digit or a lowercase
word ("12 sites failed"; "no sites failed"). The fix is `.cap`, with `.count`
or `.word` for a number.

### Gate, baseline and report

**6.1.2** Rewording a sentence leaves its constructs present; a `sed` that
eats them removes them. Leaving arm text out of the identity is what lets the
gate tell the two apart.

**5.6.4** The stages are where the printed record is made (1.4.11). A value
rounded in its own expression still prints, but agreement and the ledger see
only a raw number.

**6.2.1** Counting across the range means a paragraph moved to another file is
not a removal.

**6.2.4** Pairing by position alone called a deleted paragraph with a new one
written in its place an edit, and called two neighbouring edits removals.
Asking for shared words fixed both on the test edits (§18). The case left is
a sentence replaced by another from the same template about a different
thing; the report shows it as an edit, with both expressions, so it is
visible but not acknowledged.

**6.2.5** A re-wrap can break a line directly after `` `r `` (5.3.4), or leave
`# ` at the start of a line inside an arm. Either way the words survive and
the constructs do not.

**6.3.1, 6.3.2** An entry in a file is in the diff, where a reviewer sees it,
and survives a squash or a rebase. A trailer needs the commit message, which
does not exist until after `pre-commit`.

**6.4.2** P6. Tier 2 is left out of the hook because output that prints on
every commit and blocks nothing is not read.

**6.4.3** The worktree is not what is being committed.

**6.4.4** A git hook started from an editor or a GUI client does not have the
shell's `PATH`.

**6.4.6** Correct. See §14.

**6.4.4, 6.4.7** `quarto pandoc` costs about 0.15 s more per call than the
binary it wraps. A book of twenty chapters took about nine seconds to scan in
full (§18), which is too long to do on every commit.

**6.5** Some costs are legal one at a time and corrosive in bulk. Requiring
the commit to add the item puts the addition in the diff. Sorted, one per
line, the file merges cleanly, and moving a paragraph to another file shows as
one item removed and one added.

**6.6.1** (edits and ids) An edit is not acknowledged, and an `#id` keeps its
identity whatever its expression becomes. The report is the only place either
change shows.

**6.6.1** The pressure runs toward widening a bound rather than rewriting a
sentence, so every changed check is shown with its before and after.

**6.5.5** A commit hook cannot change the commit it is checking, so it cannot
prune. Leaving stale items until `verify()` keeps ordinary commits quiet and
still closes the gap before anything is merged.

**6.6.3, 6.7.1** A clone does not install the hook, so the checks run again
where every collaborator's work passes through (§14).

### Ledger and conditions

**7.1.4** Raw floating-point values differ between machines. A ledger that
changed whenever they did would be all noise.

**7.1.5, 7.1.6** How often a committed ledger conflicts, and how often the
occurrence index shifts, can only be learned in use. Both fail towards more
to read, never less.

**7.2.1** With two states, a partial render passes as clean.

**7.3** Both families of ranking are heuristics that narrow a human read.
Nothing here verifies English against a number.

**7.4.1** A chunk loaded from knitr's cache raises nothing, and a target built
last week raised its warning last week. Without the replay and the
`tar_meta()` reading, the log would show only what happened to be recomputed.
`tar_meta()` keeps warnings and errors and drops messages, which is why a fit
made in a target is checked there (§15).

**7.4.5** Most numbers in a message change from run to run ("Removed 12
rows"), and the same message wraps differently at another console width.
Without normalising, a known condition would read as new on every render.

**7.4.3, 7.4.4** An unread log is the failure of §10. A baseline of known
conditions turns "a warning appeared" into a diff someone must commit.

### `verify()` and activation

**8.3** Overriding `freeze` from the command line (`-M freeze:false`, or a
profile) also re-executes everything, but removes `_freeze`, and the next
ordinary render then executes everything again. A single render keeps the
single end-of-book report, which separate renders of each file would not. The
backup is restored first because an interrupted run leaves the freezer empty.

**8.5** A draft render fails nothing, so it can verify nothing.

**9.1.1** (`weft:` in Quarto's files) A key there looks like configuration and
does nothing. A setting that is silently ignored is worse than one that is
refused.

**9.1.4** `draft: true` left in one chapter's front matter made `verify()`
pass for that chapter. A setting that decides what fails belongs where the
whole project reads it.

**9.4.3** Draft mode is for writing: an author wants the whole document, with
every problem marked in place. The hook checks the source, which draft mode
does not change.

**9.2.1** The front-matter form works because R evaluates `!expr` when it
reads the document's own YAML. The first two routes run before any prose is
read, so a construct in the first paragraph resolves. Quarto starts R in the
project root even for a document in a subdirectory. The `requireNamespace()`
guard keeps R starting in a library that does not have the package yet; a
render there is caught by the filter (2.5.3).

**9.2.3** The same line in `_quarto.yml` is passed through unevaluated and
activates nothing, silently.

**9.2.4** knitr fetches its inline evaluator once for the first block, so
hooks installed from inside that block miss the values in it.

## 14. Who the checks are for

The harness is a tool an author uses on their own work. It holds a discipline
the author has chosen: every number in the prose is computed, every claim
about a number is checked, and nothing leaves the manuscript unnoticed. Nobody
is trying to get past it, and it is not built to stop anyone. "Author"
includes an AI agent editing the manuscript on the author's behalf.

What it catches is the slip made in good faith and in a hurry: a `sed` across
a chapter, a check loosened late at night to clear a failure, a paragraph lost
in a restructure.

What follows from that:

- **Every way out is open, and leaves a record.** A bare literal, a
  `.weft-literal` block, a widened bound, an acknowledged removal and a
  baselined condition are all allowed. Each one appears in a committed file or
  in the integrity report. The package's job is to make each of them a choice
  the author made, and can read back later, instead of something that
  happened unnoticed.
- **The hook can be skipped** with `--no-verify`. It gives an early answer; it
  is not a lock.
- **The range check on CI is the same checks run again from a clean clone**
  (§6.7). It is there because a local setup can be incomplete: a clone does
  not install the hook, and a freeze can be stale.
- **How strict a check is, is the author's call.** A check that cannot fail is
  flagged (3.1.6), because it is almost always a mistake. A check that is
  merely generous is a judgement, and the package has no view on it.

## 15. Pipeline patterns

Everything else protects the prose and assumes the numbers are right. A1 and
A2 say that is the assumption most likely to have already failed. The package
adds no pipeline layer of its own; it documents the patterns and supplies the
one function they share.

- **`claim()` works anywhere in R**, including inside a target. There a
  failed check stops the target (2.4.2).
- **Joins state their relationship**: `dplyr`'s `relationship =` and
  `unmatched = "error"`.
- **Convergence is asserted where the model is fitted**
  (`claim(fit, !lme4::isSingular(.))`), so the severity list is a backstop
  rather than the only defence. A fit made in a target is checked with
  `claim()` inside the target. `tar_meta()` stores warnings and errors, not
  messages, so `lme4`'s singular-fit message never reaches the severity list
  from a target (7.4.1).
- **Inputs are file targets**, so `targets` records what bytes a value came
  from.
- **Stipulations come from the dictionary** (§4.6).

## 16. What the package does not do

- **Judge prose.** Nothing verifies English against a number.
- **Write alt text or captions.**
- **Catch misattribution (C3).**
- **Hold a project's constants.** The dictionary schema ships; the values do
  not.
- **Define its own syntax.** No construct needs a compile step or a custom
  engine.
- **Pluralise nouns automatically.** Explicit arms are visible in the source
  and spellchecked; an inflector gets taxa, genera and "data" wrong.
- **Render a fallback.** A construct that cannot be evaluated fails the
  render.
- **Keep registers.** Decision logs, task registers and status conventions are
  a project's own. The dictionary's `decision:` field points at them (§4.5).
- **Lint prose style.** Vale does that and needs no runner. The one thing the
  package knows that Vale does not is the dictionary, so `dict_vale()` writes
  Vale terminology rules from it.
- **Wrap a data-validation package.** §15.
- **Check randomness.** There is no lint for `sample()` without `set.seed()`.
- **Install itself.** P10.
- **Complete weft's names in an editor.** Completion of weft's classes and
  keys is a possible later addition. It is not in scope.

## 17. One package, two parts

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

# Part 3 — Evidence

## 18. What was run

Everything here was run with throwaway stand-ins, on macOS, with knitr 1.51
and Quarto 1.11.9 (Pandoc 3.10). "Both" means under `quarto render` and under
`rmarkdown::render()`.

**The stand-in is not the rules.** It differs from Part 1 in four ways: it
accepts single-quoted values (rule 1.2.3 makes them an error), it runs
formatters left to right (rule 1.4.1 fixes four stages), it passes ids through
to the output (rule 1.2.8 does not), and a failed check in a caption stops the
render (rule 2.3.3 collects it). A row below is evidence for the mechanism it
names, not for those four rules.

Marker spans, front matter, the failure paths and the gate's matching were
each run in a copy of the stand-in extended for that purpose. Under rmarkdown
the Pandoc was 3.8.3, not the 3.10 that Quarto ships.

A row whose source is "review" was found by a reviewer of this design, not run
with the stand-in.

### Syntax and the prose hooks

| Fact | Run under |
|---|---|
| The `text` hook receives each prose block, in order, with the environment of that point in the document | both |
| Parked inline code: unchosen arms never run; data that looks like a span is printed | both |
| A matrix of 250 syntax cases: 250 pass under Quarto and 248 under rmarkdown (two are Quarto-only). It covers values, formatters and text classes, `claim()`, `n` with one to four arms, `if` with two arms, guards and condition lists, `sign`, back-references, pass-through, attribute blocks in every order and quoting, escapes, nesting, `n="."`, carve-outs, spans in headings, lists, quotes, table cells, footnotes and divs, and every error path | both |
| `.range` alone and as an `n` governor, `.p` with its relation, `.count`, `.pairs`, `trunc`, and the error for an `n` span under a non-English `lang` | both |
| `claim()` outside a knit returns its value when it passes and stops at once when it fails | R |
| Bare values print as stock knitr, 23 kinds of value | both |
| Quarto's `` `{r} x` `` form, bare and with attribute blocks | Quarto |
| Stock Quarto escapes markdown characters in the output of `` `{r} x` ``, and not in the output of `` `r x` `` | review |
| With the hooks installed before a plain `knitr::knit()` call, the output loses knitr's markdown output formatting | review |
| Inline R inside a fence that is not executed: output identical with and without the hooks | both |
| Stock knitr evaluates inline R inside a fenced block that is not executed, and inside an HTML comment | knitr |
| Constructs in an included file resolve | Quarto |
| `.strong` reaches docx as a bold run and Typst as `#strong[…]`; docx and Typst output generally | Quarto |
| Knit time with 4,000 constructs: about 1.6 s against 0.2 s stock, or about a third of a millisecond per construct | knitr |

### Positions

| Fact | Run under |
|---|---|
| Every error names the exact source line | both |
| The content search finds the same first line as knitr's own record on 4,320 of 4,320 blocks, across stress documents, the syntax cases, includes and child documents | both |
| A block identical to a line in the chunk above it needs the chunk-boundary rule | both |
| A child document (`knitr::knit_child()`, the `child` chunk option) re-enters the hooks, and initialising again empties the parent's failure records | review |

### Pandoc

| Fact | Run under |
|---|---|
| Pandoc's markdown reader accepts attribute blocks written key-first, unquoted and single-quoted; its writer rewrites them to id, classes, keys with double quotes | Pandoc |
| Pandoc's markdown writer keeps values and governed spans as constructs, writing `\|` and `\#` inside them | Pandoc |
| Pandoc's position-tracking reader (`commonmark_x+sourcepos`) parses values and spans into nodes with line and column | Pandoc |
| That reader does not parse `{n='k'}`, `{if='tier == "sev"'}` or `{if="tier == \"sev\""}` as attributes, and doubles backslashes differently from the markdown reader | Pandoc |
| That reader makes "11-year" one token | Pandoc |
| Masking a construct with spaces turns a paragraph that begins with one into an indented code block, which the lints then skip | review |
| The position-tracking reader reads a late metadata block (1.10.9) as a horizontal rule and a heading | review |
| Of span classes, Pandoc turns only `.smallcaps`, `.underline` and `.mark` into formatting, in html, docx, LaTeX and Typst; `custom-style` reaches docx | Pandoc |
| `utils` exports a function named `cite` | R |
| CLDR's plural-range data gives every English range the form "other" | CLDR |

### Captions

| Fact | Run under |
|---|---|
| A caption written as prose in a figure div or a table div resolves, and the float is numbered and referenced | Quarto |
| Constructs in `fig-cap`, `fig-alt`, `fig-subcap` and `tbl-cap` (kable and gt) resolve through an option hook and `eval.after`, and see objects made in the same chunk; numbering and cross-references hold | Quarto (html, docx, Typst) |
| Constructs in `fig.cap` and `fig.alt` resolve the same way | rmarkdown |
| A caption resolved inside the option hook itself reads the values from before the chunk | both |
| `tab.cap` and `!expr` in `fig-subcap` do not work; an unquoted YAML caption is cut at ` #` | Quarto |
| `gt` 1.3.0 drops a `tab_caption()` or `gt(caption = )` caption from docx output, with no hooks installed; `tbl-cap` with a `tbl-` label is correct in docx, html and Typst | Quarto |
| A caption is not resolved again when its chunk is served from knitr's cache, has `eval: false`, or uses an engine other than R | review |

### Marker spans

| Fact | Run under |
|---|---|
| The citation form (`@k`, `@k, p. 4`, `see @k`, `@a; @b`, `-@k`, `@{k}`) prints a citation that citeproc formats, with its reference-list entry: at a sentence end, before punctuation, in a heading, a list item, a table cell, a block quote, both kinds of footnote and a `fig-cap` | Quarto (html, docx), rmarkdown (html, Word) |
| Under Typst the citation is a native Typst one, and a prefix ("see") is dropped | Quarto (Typst) |
| A citation in a heading puts the key into the heading's automatic anchor | both |
| A `cite` span prints `\|` and `#` literally, and resolves a value and an `n` span nested in it, in both forms | both |
| A bare-form check that the same block cites each key, written with line heuristics in the `text` hook: correct on 78 of 80 renders, the other two being one case the test itself expected wrongly. It fails across paragraphs, list items, table rows, a chunk, and a footnote boundary | both |
| The heuristic splits a paragraph wrongly at a wrapped line that begins "1986. " or "- " | both |
| Keys read in R (a pattern for `.bib`, `jsonlite`, `yaml`) match Pandoc's own list exactly for BibTeX, BibLaTeX, CSL JSON and CSL YAML files of 500 entries, in under 0.02 s | R |
| Pandoc has no one call that reads all four formats: plain CSL YAML returns an empty list with no error, and its markdown reader turns `o'brien2017` into a key with a curly quote | Pandoc |
| An unknown key: Pandoc warns ("citation … not found"), exits 0 and prints "(key?)"; with no bibliography there is no warning at all; Typst fails the render | both |
| `@{key with spaces}` resolves in a bibliography and is left as literal text by Pandoc | both |
| A `"` inside a double-quoted value ends the value, and the block becomes prose with no error | both |
| Not writable under the quoting rule: a prefix or locator needing a backslash; a key containing `"`. `&quot;` works in a prefix or locator, not in a key | both |
| With no hooks, `why` on a span or div reaches HTML as an attribute (`data-why`) and is invisible in docx, Typst and LaTeX | Pandoc |
| The hook removes `why` and leaves the class, for a span and for a div: nested in a div, a list or a block quote; with its two fences in different text blocks; with a comma, apostrophe, `#`, `\|` or brackets in the `why` | both (html, docx, Typst) |

### Front matter and metadata

| Fact | Run under |
|---|---|
| A value and a governed span in `title`, `subtitle`, `abstract` and `description`, written as block scalars, resolve and print in the right place | Quarto (html, docx, Typst), rmarkdown (html, Word) |
| In a double-quoted scalar `\"` reaches R undecoded and fails; in a single-quoted scalar a doubled quote leaves the span unresolved with no error; a plain scalar that begins with `[` or a backtick fails before knitr runs | both |
| A block-scalar title is wrapped in a paragraph inside its heading in HTML | both |
| A construct in the front matter cannot see an object made in a later chunk. It sees `params`, an object from `.Rprofile`, and a function call | both |
| Activation from the front matter and from `.Rprofile` is early enough for a construct in the same front matter; a setup chunk is not | both |
| The front matter's `!expr` is evaluated three times in one render, one of them during the knit; an install that reset state broke every such document | both |
| A second metadata block at the end of the document, holding `abstract:` or `title:`, resolves with the chunks' values and prints in the abstract or title position; where both blocks set a field the later wins | Quarto (html, docx, Typst, book html), rmarkdown (html, Word) |
| In a book's docx, a chapter's late abstract becomes the abstract of the whole book | Quarto |
| Quarto reads the late block as YAML before knitr runs, so a plain scalar there that begins with `[` or a backtick fails | Quarto |
| No div in the body reaches the abstract position | Quarto, Pandoc |
| `rmarkdown::metadata$weft` returns a nested front-matter key, in a chunk and in the `text` hook | both |
| `rmarkdown::metadata` does not hold what `_quarto.yml`, `_metadata.yml` or a book set. The file named by `QUARTO_EXECUTE_INFO` and `quarto::quarto_inspect()` on the `.qmd` both do, for `bibliography`, `lang` and a custom key | Quarto |
| Quarto rewrites a project-level bibliography path relative to the document, and joins the project's list to the document's | Quarto |
| `knitr::current_input()` names the intermediate `.rmarkdown` file; `quarto_inspect()` on that file loses a book's metadata | Quarto |
| In a Quarto book, a construct in a chapter's `title:` shows raw in every sidebar and table of contents: Quarto reads titles for navigation without knitting | review |

### Failures, backstops and conditions

| Fact | Run under |
|---|---|
| Failed checks collected, one report, exit 1, no output written; draft mode | both |
| Book: failures from all chapters in one report through pre-render and post-render scripts | Quarto |
| Hidden warnings and messages logged by the `evaluate` wrapper, output byte-identical to stock | both |
| End-of-document check catches a construct above the setup chunk (run with an earlier form of the syntax) | both |
| `weft-check` filter fails the render when the hooks are absent, passes when present | both |
| A failed `claim()` in a chunk with `error: true`, or inside `try()` or `tryCatch()`: stock, the render passes. With the failure recorded first (2.4.4), the chunk prints its error, later chunks run, and the render fails at the end with no output written | both (html) |
| With `error: false` a failed `claim()` in chunk code still stops at once and is reported once | both (html) |
| That stop loses any failure collected earlier in the render (rule 2.4.5 is the answer, and has not been run) | both (html) |
| A failed check in a `weft_str()` string is collected during a knit, from `labs(title = )` and `kable(caption = )`; outside a knit it stops at once | both (html) |
| Whether a knit is running is known from `knitr::current_input()`, which is exported | knitr |
| A bold marker in square brackets survives as literal text in a title, heading, paragraph, table cell, list, footnote, link text and caption, but breaks when the construct is already inside bold, and prints its asterisks in a plot title | Pandoc (html, docx, Typst, LaTeX source) |
| `<<weft: … >>` survives all of those, including inside bold | Quarto (html, docx, Typst), rmarkdown (html, Word), Pandoc (LaTeX source) |
| Pandoc turns straight quotes in a marker into curly ones | both |
| 83 real conditions from 11 packages, 58 distinct texts among the warnings and messages: 28 hold a number that normalising rightly removes, 9 hold a number that is the substance (two different problems then match), 21 hold none | R |
| Across a narrower console, `cli` without Unicode and plain quotes, 45 of 72 conditions keep the same text unnormalised, 46 with numbers replaced, and 72 with the five steps of 7.4.5 | R |


### The gate

Run on an Apple M2 under moderate load, with the stand-in scanner,
which is unoptimised R.

| Fact | Run under |
|---|---|
| A test manuscript of 10 anchored sections and 156 constructs, and 72 scripted edits with known answers. With no paragraph matching, every real removal is reported, and 35 edits also report a removal that was an edit or a move (139 acknowledgements asked for, against 98 that were due) | R |
| Pairing by position alone: 61 of 72 right; 8 edits report a false removal; 3 call a real removal an edit | R |
| Pairing on shared words (at least half within a section, 0.6 across sections), and comparing constructs even when the words are the same: 71 of 72 right, no false removal. The one miss is a templated sentence replaced by the same template about another thing | R |
| A plain re-wrap at 55 columns removed 32 constructs from a paragraph without changing a word: 31 where the line broke directly after `` `r ``, one where `# ` landed at the start of a line. Matching on words alone saw one of them; comparing construct by construct saw all 32 | R, knitr, Pandoc |
| Three changes the rules themselves do not call a removal: an identity removed from one paragraph and added in another (counted as a move); an expression changed under an unchanged `#id`; an unrelated construct put in place of another within one paragraph (counted as an edit) | R |
| A section headed in the underlined (setext) style was not seen as a section by the spike's line-based splitter | R |
| Blocks split on blank lines agree with Pandoc's paragraphs, headings and list items on every block start Pandoc reports (93 against 90; the extra ones are inside a table and a code block) | Pandoc |
| R starts in 0.13 s; loading `jsonlite` and `yaml` adds nothing measurable, `knitr` 0.06 s | R |
| The Pandoc binary starts in 0.03 s, `quarto pandoc` in 0.18 s | Pandoc |
| `commonmark_x+sourcepos` to JSON, 2,000 paragraphs: 0.9 s and 11 MB, against 0.5 s and 1.8 MB without positions; reading the 11 MB into R takes 0.3 s | Pandoc, R |
| The hook end to end, one changed file of 300 paragraphs: 0.7 to 1.0 s for the staged version alone, 1.7 s with the `HEAD` version and the matching | R, Pandoc, git |
| Five changed files: 2.9 s staged alone, 8.9 s with matching, of which 5.2 s is the scanner and matcher | R, Pandoc, git |
| A book of 20 chapters of 300 paragraphs over a commit range: 8.8 s for one version, 28.5 s for both with matching | R, Pandoc, git |
| Twenty files through one Pandoc process take 1.8 s, against 2.8 s for twenty processes; end to end the gain is lost in reading one large JSON file | Pandoc, R |
| A line wrap directly after `` `r `` stops knitr reading inline R: the code prints as a code span, with no error. A plain re-wrap at 55 columns did this to 530 of 5,500 values in a test document | knitr |

### Activation

| Fact | Run under |
|---|---|
| Hooks installed when the namespace is loaded take effect, including when it is loaded before the knit begins | both |
| Activation from the document's front matter (`!expr` under `knitr:` or `params:`): a construct in the first paragraph resolves | both |
| Activation from `.Rprofile` at the project root, for documents in the root and in a subdirectory, project and single-file render | Quarto |
| `!expr` in `_quarto.yml` or `_metadata.yml` is not evaluated | Quarto |
| Inline R in a YAML field installs the hooks too late for values in the first block | Quarto |
| Activation from `_output.yml` through an output format that carries the hooks works (the route is not offered: 9.2.3) | rmarkdown |
| `library(weft)` in a setup chunk activates only the first knit of an R session, because attaching happens once: in a loop of `rmarkdown::render()` calls, every document from the second on printed raw spans, and nothing failed | review |

### Cache and freeze

| Fact | Run under |
|---|---|
| Chunk cache: checks still run on cached values | both |
| `freeze: auto`: checks do not run; the stamp mechanism detects it | Quarto |
| With `_freeze` (or one document's entry) moved aside, one project render re-executes those documents once and rewrites their entries; book and website | Quarto |
| `-M freeze:false` and a profile re-execute but remove `_freeze` | Quarto |
| `--execute`, `--cache-refresh` and `touch` do not thaw | Quarto |
| In a book with `freeze`, a chapter whose render had failed claims is stored in `_freeze`, and the second render passes | review |

### Dictionary and `targets`

| Fact | Run under |
|---|---|
| `tar_dict()` and `tar_dict_deps()`: a changed value re-runs exactly its readers, through commands and through functions; a changed definition, a new key or a reorder re-runs no consumer; an unknown key errors at definition | targets 1.12.0 |
| A `tar_quarto()` report notices a dictionary change only when its `.qmd` is scanned for `dict$key`; then exactly | targets, Quarto |
| `targets::tar_meta()` stores warnings and errors, not messages: `lme4`'s singular fit, a message, is not recorded; `glmmTMB`'s non-positive-definite Hessian, a warning, is | review |

### Quarto 2

Quarto 2 (experimental, 0.43.0): its parser accepts a governed span whose key
has a quoted value, and rejects a key written before a class and an unquoted
`.`. Values with attribute blocks, and execution, were not tested under it.

## 19. What was not run

**Rules the stand-in does not implement.** None of these has run in any
form:

- the single-quote and escape errors (1.2.3); ids kept out of the output
  (1.2.8)
- the four formatter stages and their at-most-one errors (1.4.1, 1.4.2);
  `digits` and `sigfig` (1.4.7); the limits on the wording classes (1.4.12)
- `sign` on a bound (1.5.17); `n="."` inside a `sign` span (1.7.2)
- units through the stages (§4.4)
- for `cite` spans: the bare-form check made on Pandoc's tree (5.4.2; the
  spike used line patterns in the hook), the keys-only and key-grammar errors
  (1.8.4, 1.8.5), classes and pass-through on the span (1.8.7), and the static
  reading of the bibliography (5.4.4)
- the unparsed-block error (1.2.9), beyond a pattern tuned on the spike's own
  cases
- a failed check in a caption being collected (2.3.3)
- a stopping failure printing the ones collected before it (2.4.5)
- the marker `<<weft: … >>` in a rendered plot title
- installing the hooks only from `weft_setup()` (2.1.3); the late install of
  the `chunk` wrapper (2.1.4); per-knit initialisation, with a child sharing
  its parent's records (2.1.5)
- the end-of-document check counting chosen arms only (2.5.2); the filter's
  test for a leftover placeholder and for a marker (2.5.3, 2.9.5)
- masking construct ranges with a letter before Pandoc reads the prose, the
  check on block types, and masking metadata blocks (2.10.3, 2.10.5, 2.10.6)
- the "no value" failure for a missing value, in the formatters, governors,
  phrase functions, `lookup()` and `brk()` (1.3.4, 3.3.5)
- the value-dependent errors collected instead of stopping (5.3.2); the parse
  check on inline expressions and attribute values (5.3.5); `claim()` with no
  check (3.1.10)
- the caption error for a chunk that is cached, not evaluated or not R
  (2.3.5)
- the stamp's record of failures, and the `post-render` script failing on a
  frozen document that has them (2.9.4)
- draft mode for construct errors and for the filter (9.4.3); the settings
  errors of 9.1.1 and 9.1.4
- matching `lang` on its primary subtag, and the English-only errors (1.6.7,
  1.6.8)
- the condition sources beyond the `evaluate` wrapper (7.4.1), and the
  condition baseline (7.4.4)
- the backup-and-restore sequence of `verify()` as a whole (8.3); only the
  freeze behaviour it relies on was run

**Parts of the design with no stand-in at all:** every lint; the baseline and
`baseline_prune()`; the acknowledgements file and the integrity report; the
hook's cache (6.4.7); the ledger; `use_ci()`; the `decision:` resolver; `dict`
and `dict_local` as objects (the `targets` side was run). Of the gate, only
the paragraph matching and the timings were run.

**Rules that follow from how a tool works, not from a run.** Hygiene rule 7
(§5.8): that knitr's cache serves an old target to a chunk that reads one.
It follows from how the cache key is built.

**Formatters and functions not in the syntax matrix:** `.date`, `.sci`,
`.ord`, `.ol`, `.dl`; `of_n()`, `about()`, `ci()`, `pm()`.

**Environments:** Windows; the Render button in RStudio or Positron; running
chunks interactively with the hooks loaded; LaTeX PDF (for `cite` spans and
the marker, only Pandoc's LaTeX source was read); bookdown; nested includes.
The failure paths of 2.4.4 and 3.6.3 were run to HTML only. A late metadata
block was run with front-matter activation only. Child documents were covered
for positions only: the syntax matrix was not run on them. For captions in
chunk options: LaTeX and books. For `tar_dict()`: branching, parallel workers
and functions in a package namespace.

## 20. Open questions

### Environment and toolchain, carried over

**Q1 — Windows.** The fixture runner is portable and has not been run there.
The placeholder characters are private-use Unicode and exist only in memory.

**Q2 — The editors.** Whether the Render button, chunk-by-chunk execution and
the inline preview behave with the hooks loaded. Also `.Rprofile` activation
beside `renv`, which owns that file.

**Q3 — A render that fails part-way through `verify()`.** What `_freeze` holds
after a chunk errors mid-render is untested, and the restore step of 8.3
depends on it.

**Q4 — Quarto 2 execution.** It hands knitr text re-serialised from its parsed
tree. Whether the hooks then see the constructs unchanged is untested.

**Q5 — `tar_dict()` beyond the toy pipeline.** Not run: branching, parallel
workers, functions in a package namespace, Windows.

**Q6 — Plural rules for languages other than English.** The table would be
generated from CLDR's `plurals.xml`; no R package was found that exposes those
rules.

### Raised by the spikes

**Q7 — `QUARTO_EXECUTE_INFO`.** Rule 2.1.6 reads Quarto's merged metadata
from the file this variable names. It worked in every case run. Whether Quarto
documents it and intends to keep it was not checked. The fallback,
`quarto_inspect()`, is documented and costs about 0.4 s per document.

**Q8 — Weft names close to each other.** `.or`, `.ol`, `.ul` and `.dl` are
one edit from each other, and `.or` is one edit from `.ord`. The lint of 5.3.3
does not list a slip between them, because both names are weft's. Each slip
prints something visibly different, except `.or` written for `.ord` on a
single number, which prints the bare number.

**Q9 — When the scanner and Pandoc disagree.** A re-wrap can leave `# ` at
the start of a line inside an arm. At knit time the scanner still resolves the
span. Pandoc's static tree reads a heading there. Rule 6.2.5 catches the edit
that causes it, and the block-type check of 2.10.5 now fails a file already in
that state, naming the line. That check needs the unmasked tree as well as
the masked one; its cost to the gate (Q11) is not measured.

**Q10 — A late abstract in a book.** In a book's docx, a chapter's late
`abstract:` becomes the abstract of the whole book (1.10.9).

**Q11 — The gate's time.** With the stand-in scanner, a commit of five
chapters took about nine seconds, most of it in R code scanning and matching.
The cost follows the size of the files touched, not the size of the change.
About one second for a commit that touches one chapter looks reachable; more
than that needs the scan limited to the paragraphs that differ from `HEAD`,
which was not tried. Whether the cache of 6.4.7 keeps a book-wide check off
every commit is not known. No budget is set, and the timings were taken on a
machine under load.

**Q12 — The matching thresholds.** The shared-word thresholds of 6.2.4 were
chosen on the same 72 edits they were scored on, in one synthetic manuscript.
They have not met a real history.

**Q13 — Conditions whose number is the point.** Rule 7.4.7 accepts that
"Removed 5 rows" and "Removed 5000 rows" match. Nine of 58 real messages were
of this kind.

**Q14 — `cite` spans under Typst and LaTeX.** Typst drops a citation's
prefix. PDF through LaTeX was not run.

**Q15 — The ledger in use.** How often a committed ledger conflicts on merge,
and how often the occurrence index shifts (7.1.5, 7.1.6).

**Q16 — Plain `knit()` with the hooks installed.** With the hooks installed
before a plain `knitr::knit()` call, the output lost knitr's markdown output
formatting (§18). Rule 2.1.7 requires that it does not. The cause, and how
weft avoids it, are not settled.

---

# Part 4 — Plan

## 21. Tests

`testthat`, seeded by the scanner and the `text` hook, then `claim()`, `dict$`
and `dict_local$`. Then the lints, each against a fixture pair.

- **The syntax fixtures are a table**: source, setup, expected text or
  expected error with its line. Each case is rendered under Quarto and under
  rmarkdown and compared. The stand-in's matrix (§18) is the seed, corrected
  for the four differences listed there.
- **One scanner, two uses.** For every fixture, the scanner over the source
  file and the scanner over the prose blocks at knit time must find the same
  constructs at the same positions.
- **Masking.** For every fixture, Pandoc's tree of the masked source must
  hold no construct and no shifted position, and the same block types as the
  unmasked source. The fixtures include a paragraph that begins with a
  construct, and a late metadata block whose `abstract` holds a numeral that
  the lints must report with its line in the YAML.
- **Round trip.** Every fixture, passed through Pandoc's markdown writer, must
  render to the same text.
- **Attribute forms.** Each fixture is also run with its attribute blocks
  reordered and unquoted, and must render the same text. With its values
  single-quoted it must give the construct error of 1.2.3.
- **Stages.** Each fixture with more than one formatter class is run with the
  classes in every order, and must render the same text.
- **Positions.** The content search against a stress document: repeated
  blocks, blank blocks, a block identical to a line of the chunk above it,
  CRLF, no final newline, a byte-order mark.
- **Pinned internals.** One test each for the signature of knitr's `evaluate`
  hook, knitr's evaluation of `eval.after` options after the chunk, Quarto's
  `.QuartoInlineRender` wrapper, Quarto's forwarding of a `NULL` `tbl-cap`,
  the point at which the output format sets its `chunk` hook, and a Lua
  `os.exit` failing a Quarto render. Each is a place where an upgrade could
  change behaviour silently.
- **Stock parity.** A document with no attribute blocks renders byte-identical
  with and without the hooks, including inline R inside a fenced block that is
  not executed and inside an HTML comment, bare `` `{r} x` `` and `` `r x` ``
  each against its own stock output, and bare inline R in a quoted `title:`.
  A `.Rmd` knitted with plain `knitr::knit()` gives the same markdown with the
  hooks installed and without them (2.1.7).
- **Activation.** A loop of `rmarkdown::render()` calls over documents whose
  setup chunk calls `weft_setup()` resolves every document, not only the
  first. A document whose setup chunk calls only `library(weft)` is caught by
  the filter.
- **Backstops.** With the hooks missing, a document holding each kind of
  construct fails its render under Quarto and under rmarkdown, through the
  filter.
- **Child documents.** A failure in the parent above a child, one in the
  child, and one below it are all reported, each with its own file and line.
- **Collected failures.** A document with two value-dependent errors (5.3.2),
  a missing value under each formatter class, governor key and phrase
  function (1.3.4), and a failed check renders to the end and reports every
  one. A bare value that is `NA` prints as stock.
- **Freeze.** A book chapter with a failed claim, rendered twice under
  `freeze: auto`, fails both renders (2.9.4).
- **Draft mode.** A document with a construct error, a failed check and a
  missing value renders in draft mode with a marker for each, and the filter
  reports instead of failing.
- **`verify()`.** The backup-and-restore sequence against a render that
  succeeds, one that fails, and one that is killed (Q3).
- **Names.** Every weft name changed by one edit, where the result is not
  another weft name, is listed by the lint of 5.3.3 with a weft name as the
  nearest. Pandoc's names and the project's expected names are not listed.
- **Paragraph matching.** The spike's 72 scripted edits (§18) are kept as a
  fixture, and edits taken from a real manuscript's history are added to them
  (Q12).
- **Condition matching.** The spike's recorded messages, each under two
  console widths, with and without `cli` Unicode.

## 22. Build order

Each stage leaves something usable on its own.

**Stage 0 — a sanity check.** `recall_check()` and a rough prototype of each
candidate lint, run against the recorded findings of the companion plan's
audit. It can show a major problem: a lint that reproduces none of the
findings, or one that flags nearly everything. Either sends that lint back to
design before it is built. Stage 0 does not rank layers and does not remove
one: one corpus is not evidence enough for either, and the package is for
more than one project (P12).

**Stage 1 — the prose core.** Usable alone. It is built in four steps. Each
step ends when its fixtures pass under Quarto and rmarkdown and a real chapter
renders with it.

*1a — the kernel.* Enough to write a chapter.

- the scanner; the `evaluate.inline`, `text`, `document` and `evaluate` hooks;
  installing from `weft_setup()`; per-knit initialisation, with child
  documents
- values; the four formatter stages, with `.num`, `.pct`, `.sci`, `.word`,
  `.count`, `.ord`, `.no`, `.and`, `.or`; `digits`, `sigfig`, `sep`, `last`;
  project-registered formatters
- governed spans with `n` (English) and `if`: two arms, guards, condition
  lists; `n="."`
- `claim()`, `plural()`, the `fmt_*()` functions
- pass-through of classes and keys; `.strong`, `.em`
- collected failures, including the record made by a failed check in chunk
  code (2.4.4), missing values and value-dependent errors; the marker; exact
  positions; draft mode; `_weft.yml`
- the condition log from the `evaluate` wrapper and from values in prose, the
  cache replay, and the severity list
- the end-of-document check and the `weft-check` filter; `use_quarto()`
- activation from front matter and from a setup chunk
- the syntax fixtures, the scanner and masking tests, and the pinned-internals
  tests

*1b — agreement and direction.*

- `sign`; ids and back-references (`n="#d"`)
- the relation in the printed record; `.p`, `clamp()`; `.range`, alone and as
  an `n` governor
- `.cap`, `.a`; the sentence-start report
- `lookup()`, `brk()`
- `cite` spans, with the knit-time bibliography check; `.weft-literal`, with
  its `why` removed from the output

*1c — captions and project activation.*

- captions in chunk options, with the option hooks and the late `chunk`
  wrapper; `weft_str()`
- constructs in front-matter fields and in a late metadata block
- `.Rprofile` activation and `use_setup()`, with the filter under rmarkdown.
  These wait until the hooks have been run under the Render buttons of
  RStudio and Positron, and with chunks run interactively (Q2)

*1d — phrases and lists.*

- `of_n()`, `about()`, `ci()`, `pm()`
- `.pairs`, `trunc`, `.date`; `.ul`, `.ol`, `.dl`

**Stage 2 — dictionary and ledger.**

- `dict`, `read_dict()`, `dict_local`, the schema, the generated glossary,
  the pointer resolver, `dict_vale()`
- `tar_dict()` and `tar_dict_deps()`
- the ledger: records, three states, `ledger_review()`, acceptances
- conditions read from `tar_meta()`, which needs the ledger's record of the
  targets each chapter reads

**Stage 3 — static lints, with the baseline.**

- the scanner over source files, chunk-option captions and `weft_str()`
  strings; the masked Pandoc read; the citation pattern
- the baseline file, built in this stage because the numerals rule cannot be
  switched on without it
- numerals, with the exemptions and `.weft-literal`; literal values; construct
  errors; marker spans and citations; cross-references; hygiene; figure
  presence
- the tier-2 lints (claim words, constants in computations, probable
  constructs), available as functions until stage 4 gives them a report

**Stage 4 — the gate.**

- identities, removals and the acknowledgements file
- the `pre-commit` hook and `use_hooks()`
- `verify()`, with the freeze sequence and the condition baseline
- the integrity report (`verify(range = )`) and `use_ci()`

Stage 2 comes before stage 3 because the numerals rule sends constants to the
dictionary: the lint cannot be switched on until there is somewhere for them
to go.

**Planned, after stage 4.** Neither is in a stage.

- `drange()` and `dur()` (3.5.6): both need calendar arithmetic and a decision
  on date order.
- Plural rules for languages other than English (Q6).
