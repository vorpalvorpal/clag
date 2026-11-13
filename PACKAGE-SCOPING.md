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
nothing about any particular book. The old `clag` code is removed, and its
last state is tagged `clag-0.2.0`. The GitHub repository and the local folder
keep the name `clag` for now.

The package is two layers. The **prose core** (the syntax of §1 and the
runtime of §2) makes a computed value cost what knitr inline code already
costs, and makes a checked value cost one function call more. The **integrity
harness** (dictionary, lints, commit gate, ledger, `changes()`, `verify()`)
is only socially sustainable because of that: a rule like "every numeral is a
computed value" survives contact with authors only when writing one is nearly
free, and when the inline R a document already contains counts without being
rewritten. The harness stops accidental changes and lets purposeful ones
through. A commit fails on what it adds that is wrong, and on constructs it
removes without saying so; saying so is one line in the commit message.
Everything else is shown, not stopped, in diffs the author already reads.

Every weft construct is markdown that knitr, Pandoc and Quarto already accept.
Nothing is compiled, there is no second source tree, and the file the author
edits is the file that renders. A `.qmd` becomes a weft document with
`engine: knitr` in its front matter and one call that activates weft (§9.2).

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

**1.1.5** A span is a weft construct when its attribute block carries one of
the five keys, or carries none of them and a weft text class (`.a`, `.cap`,
`.strong`, `.em`). A span with two of the keys is one construct, with a
construct error (5.3.1).

| Key | Kind | The span |
|---|---|---|
| `n`, `if`, `sign`, `list` | governor | prints prose chosen by an R value (§1.5) |
| `cite` | marker | prints its prose and names its source (§1.8) |
| none, with a text class | text | prints its prose with the class applied (1.1.9) |

**1.1.9** In a text span the class acts on the bracket's text, as it does on a
governed span's chosen arm (1.5.7): `[results]{.strong}` prints bold. A text
span has no arms: `|` and `#` in it are ordinary characters. Its bracket is
prose (1.5.15). An `#id` on a text span is a construct error. A formatter
class or a renderer key on a bracket with no governor or marker key is not
weft's there: `[1234]{.num}` is not a construct, the class passes through,
and the lint of 5.3.3 lists it.

**1.1.6** A span or a div with the class `.weft-literal` is a marker for the
lints (§1.8). The runtime does one thing with it: it removes the `why` from
the output (1.8.11).

**1.1.7** The attribute block touches the closing backtick or bracket, with
nothing between.

**1.1.8** A construct is a span that carries a weft key or a weft text class
(1.1.5), or a value that has an attribute block. Bare inline R, with no
attribute block, is not a construct. It keeps stock behaviour everywhere: it
prints as stock prints it (1.3.1), and no rule about constructs applies to
it, in prose, in `title:` and the other front-matter fields, in tables and in
captions. Three things still apply to it, because they are about R and not
about constructs. A weft function called in it behaves as it does anywhere: a
`claim()` is still a check (2.4.1), a `claim()` with no check is an error
(3.1.10), and a phrase function under a `lang` weft does not ship is an error
(1.6.8). An expression that does not parse is an error (5.3.5). And it still
counts as a value for the numeral rule (5.2.1). It is recorded in the ledger
(7.1.2),
and the gate counts it when it is removed (6.3.1), because it prints a value
in the document.

### 1.2 The attribute block

**1.2.1** `{ATTRS}` is Pandoc's attribute syntax: an optional `#id`, classes,
and `key=value` pairs, in any order.

**1.2.2** A value is double-quoted or unquoted. An R string inside a value
uses single quotes: `{if="tier == 'sev'"}`.

**1.2.3** In the block of a weft construct, a single-quoted value, or a `"` or
a `\` inside any value, is a construct error (§5.3), except `\|` in the value of
`unit`, which is read as `|` (4.4.23). The message says to bind
the expression to a name in a chunk.

**1.2.9** A `"` inside a double-quoted value ends the value early, and what is
left is no longer an attribute block. So braces that directly follow a bracket
or inline code, do not parse as an attribute block, and contain a weft key in
any letter case (1.2.10) followed by `=`, are the same construct error.

**1.2.4** Meaning never depends on the order in which things are written
inside the block.

**1.2.5** weft owns these names. Everything else in a block is passed through
(1.2.6).

| Kind | Names |
|---|---|
| governor and marker keys | `n`, `if`, `sign`, `list`, `cite` |
| renderer keys | `digits`, `sigfig`, `unit`, `sep`, `last`, `trunc`, `none` |
| formatter classes | `.num .pct .sci .p .date`, `.no .word .count .ord`, `.and .or .pairs .range .ul .ol .dl`, and project-registered ones (§1.4) |
| unit classes | `.uname`, `.usym`, `.nounit` (1.4.19) |
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

**1.2.10** A key that matches a weft key in any letter case is that key:
`{If="x > 0"}` is `if`, and `{N="k"}` is `n`. The lower-case form is the
written standard, and the adoption helpers and any fixer write it. A key
written twice in one block, in any letter case, is a construct error. Class
names are matched exactly: `.Num` is not `.num`, and on a construct it gets
the warning of 5.3.3, which names the nearest weft name.

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
reaches a formatter, a governor or a phrase function (§3.5). A value of
length zero is not missing where the construct says what to print for it: a
`none` key on a collapsed value (1.4.14), or a `list` span (1.5.19). `NULL` is
missing even there. A bare value with no attribute block still prints as stock
knitr prints it (1.3.1).

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

**1.4.2** Two classes from one at-most-one group are a construct error. So is
a wording class together with `.pct` or `.sci`. The three unit classes
(1.4.19) are one such group, so two of them are a construct error, and so is
`.usym` with `.no`, `.word` or `.count`.

**1.4.3** What each class prints:

| Class | Prints |
|---|---|
| `.num` | a number, to the document's defaults (§9.1); a whole number with no decimals (1.4.13) |
| `.pct` | a proportion as a percentage: 0.12 prints "12%" |
| `.sci` | scientific notation |
| `.p` | a p-value: "p = 0.046", "p < 0.001", never "p = 0.000" (1.4.17) |
| `.date` | a date, in the document's default format |
| `.no` | a printed zero as "no" |
| `.word` | a spelled numeral ("three") |
| `.count` | a word below the threshold, digits from it up ("three", "12"); the threshold defaults to ten |
| `.ord` | an ordinal ("3rd") |
| `.and`, `.or` | the elements collapsed with a final "and" / "or" |
| `.pairs` | a named vector as "A (1.2), B (3.4) and C (5.6)" |
| `.range` | a length-2 value as a range ("3–5") |
| `.ul`, `.ol`, `.dl` | a bullet, ordered or definition list |
| `.uname` | a quantity's unit as its name: "5 metres" (1.4.19) |
| `.usym` | a quantity's unit as its symbol: "5 m" (1.4.19) |
| `.nounit` | a quantity's number with no unit: "5" (1.4.19) |
| `.a` | "a" or "an" before the text, by sound ("an 11-year", "a 12-year") |
| `.cap` | a capital first letter |
| `.strong`, `.em` | markdown emphasis |

**1.4.4** `.range` prints one number when both ends print the same, and
writes "−5 to −3" when either end is negative. A first end above the second
is a collected failure (5.3.2). The ends are compared as numbers, not as
printed, so a bound beside a number that prints as zero is not out of order
("< 0.01" beside "0.0").

**1.4.5** `.a` applies to numbers and number words only.

**1.4.6** `.ul`, `.ol` and `.dl` produce a block. A value that carries one
must be alone in its paragraph, and that paragraph must not be inside a list
item, a block quote or a table cell; otherwise it is a construct error. A
text class or `trunc` with one of them is a construct error too.

**1.4.7** Renderer keys:

| Key | Stage | Sets |
|---|---|---|
| `digits` | number | decimal places |
| `sigfig` | number | significant figures |
| `unit` | number | the unit, or the ladder of units, a quantity is printed in (4.4.14, 4.4.23) |
| `sep` | collapse | the text between items |
| `last` | collapse | the text before the final item |
| `trunc` | collapse | the number of items shown before "and N others" |
| `none` | collapse | the text printed for a vector of length zero (1.4.14) |

`digits` and `sigfig` together are a construct error. Either one, `unit`, or a
unit class (1.4.19), on a construct with no number-stage class implies `.num`.

**1.4.8** A project registers its own formatter (a function, optionally
bundling options) in `_weft.yml` (9.1.2): the class name, the function, and
the stage it belongs to (number by default). It counts toward that stage's
at-most-one rule. A project name may not shadow a shipped one.

```yaml
formatters:
  .compact:
    function: myproject::fmt_compact
    stage: number
```

**1.4.9** A value that is a `units` object prints with its unit (4.4.8). No
formatter supplies a unit of its own.

**1.4.10** Formatter output is markdown, as stock knitr's inline output is.
Text that comes from data is not escaped. A vector that no collapse class
joins prints its elements joined with ", ", as stock knitr prints an inline
vector.

**1.4.11** Every formatted value has a **printed record**: its text, the
number as printed, a flag for whether decimals are shown, and a relation
(`=`, `<` or `>`). "< 0.001" is a bound, not a value. Stage i sets the
number; stages ii to iv reword and pass it through. A collapsed vector and a
date have no number. An `n` or `sign` governor is always formatted, by its own
classes or by the default class (1.5.18), so it always has a record.

**1.4.12** `.word`, `.count` and `.ord` take a whole number that is not
negative, judged on the number as printed. Anything else (a decimal, a
negative, a bound) is a collected failure at knit time (5.3.2). `.word`
prints digits from a limit up, as `.count` does from its threshold; the limit
defaults to one hundred and is configurable (§9.1).

**1.4.13** `.num` prints a whole number with no decimals unless `digits` or
`sigfig` is given on the construct. A number that is not whole prints to the
project's default digits (§9.1). A number is whole when it is within 1e-9 of
its rounding. Rounding is half away from zero on the number as written: 0.15
prints "0.2" and 2.5 prints "3". A number that rounds to zero prints with no
minus sign. A number whose absolute value is below 1e-9 is zero: it prints "0"
("0%" under `.pct`, judged on the percentage), however it was computed, so
`0.1 + 0.2 - 0.3` prints "0". This does not apply to a quantity: a small
quantity goes through the zero rule of 4.4.13. A number that is not zero and prints with no
digit other than 0 under the default digits prints so ("0.04" prints "0.0",
"-0.04" prints "0.0"), and a warned check is recorded (2.6.11). `digits` or
`sigfig` on the construct or the call silences it. A project default `digits`
does not: a setting copied from the project default is not given. The check
reaches every construct and call that prints a number under the default
digits: `.num`, `.pct`, `.range`, `.pairs`, and the phrase functions `ci()`
and `pm()` (3.5.1). It does not reach `.sci`, a project formatter, `about()`
or `of_n()`.

**1.4.14** `none` is the text printed when a value with a collapse class
(`.and`, `.or`, `.pairs`, `.ul`, `.ol`, `.dl`) is an atomic vector of length
zero. It prints as inline text, for a list class as well, and a text class
acts on it.

```
Flagged sites: `r flagged`{.and none="none"}.
```

Without `none`, a value of length zero is a missing value (1.3.4). `NULL` is
missing even with `none`. `none=""`, or `none` of only spaces, is a construct
error, and so is `none` on a value with no collapse class, on a span, or on a
`cite` span. `.range` is not a collapse class here: `none` with `.range` is a
construct error, because a range has two ends.

**1.4.15** With the setting `serial_comma` on (9.1.2), `.and`, `.or`, `.pairs`
and a truncated list put a comma before the last joiner when there are three
or more items. The tail of a truncated list counts as an item. Two items are
unchanged. A `last` key on the construct wins over the setting. With a `sep` key, the
mark before the last joiner is the `sep` without its trailing space, also under
`.pairs` and before the tail of a truncated list.

```
a, b, and c          a, b, and 2 others          a and b
a; b; and c          with sep="; "
```

**1.4.16** A number whose absolute value is at least the setting
`thousands_from` (9.1.2) gets the thousands mark, in `.num`, `.pct` and
`.ord` ("1,000th"); below it, none. The default is 1000. A year given `.num`
prints "2,024", so a year is left bare.

**1.4.17** `.p` prints "p < 0.001" below 0.001 and "p > 0.99" above 0.99.
Between, the value is rounded to three decimals. A result below 0.1 prints with
three decimals ("p = 0.046", "p = 0.004", "p = 0.050"), any other with two
("p = 0.10", "p = 0.20"). The record's number is the number printed.

**1.4.18** The minus sign weft prints is U+2212. In a knit to LaTeX weft
declares the character for pdflatex, which has no definition for it; xelatex
and lualatex set it already. It declares as well the other characters it can
print for a unit that LaTeX does not set: the ohm sign (U+2126), the prime
(U+2032) and double prime (U+2033), the micro sign (U+00B5) and the degree sign
(U+00B0), for pdflatex and, where the default font lacks the glyph, for xelatex
and lualatex. Under xelatex and lualatex the prime and double prime are set
from Latin Modern Math through the LaTeX package `newunicodechar`, which a TeX
installation that installs no packages by itself must have. A document needs
nothing in its preamble.

**1.4.19** A quantity's unit prints as its symbol or as its name (4.4.15), and
the unit classes choose. `.uname` prints the name, `.usym` the symbol and
`.nounit` the number alone: `u(5, m)` prints "5 metres" under `.uname`, "5 m"
under `.usym` and "5" under `.nounit`, and `.word .nounit` on `u(3, m)` prints
"three". The three are one at-most-one group, and not a stage of 1.4.1.

A unit class on a construct with no number-stage class implies `.num` (1.4.7).
On an `n`, `sign` or `list` span it acts on `#` (4.4.4). On a text span with no
key it passes through (1.1.9). On a value with no unit, such as a plain number
or a ratio, a unit class is a value error; so is the argument `unit_form` of
a formatter function when it is not `"auto"` (3.4.8). A setting `unit_form`
applies to anything and is not an error on a value with no unit.

A unit class on an `if` or `cite` span is a construct error, found from the
source, as are two unit classes, `.usym` with `.no`, `.word` or `.count`
(1.4.2), and `.uname` under a `lang` that weft ships no words for (1.6.8).
`.pct` is not a unit: `unit_form: name` leaves
its "%" alone.

**1.4.20** `.cap` never changes a unit's symbol, because the case of a symbol
is its meaning: `fmt_cap(fmt_unit(u(5, mL)))` is "mL", not "ML". This holds
on every route: after a text class, and after `[`. It capitalises
a name: with `unit_form = "name"` the same call is "Millilitres". `.ord` on a
quantity that has a unit is a value error.

### 1.5 Governed spans

**1.5.1** The bracket holds one or more **arms** separated by `|`. The key
names the kind of governor, and fixes the arm counts allowed.

| Key | The value must be | Arms | Chosen |
|---|---|---|---|
| `n` | a single number | 1 | always (a template for `#`) |
| | | 2 | one / other |
| | | 3 | zero / one / other |
| | | 4 | zero / one / two / other |
| `list` | an atomic vector, of any length (1.5.19) | 2 | one / other |
| | | 3 | zero / one / other |
| | | 4 | zero / one / two / other |
| `if` | one or more conditions, each a single `TRUE` or `FALSE` | 2 | true / false; either may be empty |
| | | 1 | always (a guard) |
| `sign` | a single number | 2 | positive / negative |
| | | 3 | positive / negative / zero |

The arm counts for `n` and `list` are English's (§1.6).

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
conditions are not all `TRUE`, a two-arm `sign` at zero, and a two-arm `list`
given a vector of length zero (1.5.19), are collected and reported like any
failed check (§2.6).

**1.5.4** `if` takes a comma-separated list of conditions, read as R reads an
argument list: `if="n_gap > 10, n_sites >= 3"`. All must be `TRUE` for the
true arm. `&&`, `||` and brackets remain available inside a condition.

**1.5.5** A one-arm `if` is a **guard**. It always prints its phrase. Each
condition that is not `TRUE` is reported separately. A phrase with an empty
second arm (`[, apart from the estuary sites | ]`) is optional text and fails
nothing. A guard has no level (3.1.11), and a `level` key on any span is a
construct error.

**1.5.6** A governor is checked with `claim()` in its expression, as a value
is.

**1.5.7** Formatter classes and the keys `digits` and `sigfig` on an `n` or
`sign` span format the governor. With none of them, the default class formats
it (1.5.18). A formatter on an `if` span is a construct error. On a `list` span
a formatter acts on `#` (1.5.19). Text classes on any span act on the chosen
arm's final text.

**1.5.8** `#` in an arm stands for the governor's printed text. Inside a
`sign` span it is the magnitude as printed, without its sign.

**1.5.9** Selection sees the value as it prints. For `n`, the "one" arm is
chosen only when the printed number is 1 with no decimals shown; the "zero"
arm only when it is 0, and the "two" arm only when it is 2. A value printed as
"1.0" takes the "other" arm. A number printed as a bound ("< 1") takes the
"other" arm. Under the default class (1.5.18) a whole number prints with no
decimals: 3 prints "3", and 0, 1 and 2 take the "zero", "one" and "two" arms
by their value. A value prints "1.0" or "0.0" only when the author asked for
decimals: with `digits` or `sigfig` on the span, or through the default
digits for a value that is not whole (1.4.13).

**1.5.10** `sign` judges zero on the number as printed: a change that prints
as "0.0%" takes the zero arm, whatever its raw value. Under the default class
a raw zero prints "0", and a value that is not whole prints to the default
digits, so a small change can print "0.0" and take the zero arm. An `n` or
`sign` governor that prints as zero, and its `#`, record no warned check
(1.4.13).

**1.5.11** `n` must be a single number. A vector or a string is a collected
failure (5.3.2) whose message says to write `length(x)`. An `NA` is a "no value"
failure (1.3.4). A count is never inferred from a length. A list that can be
empty is a `list` span (1.5.19), which chooses its arm by the vector's length
and does not give `n` a count. The one exception is a length-2 value with
`.range`: `#` is then the range, and the span takes the plural unless the range
collapses to a printed 1.

**1.5.12** Arms are trimmed. A `|` or a `#` in an arm is read in two steps.
First, a backslash directly before a `|` or a `#` is removed. Then a doubled
`||` or `##` is the literal character, and a single `|` or `#` is the
separator or the placeholder. Three in a row are read left to right: a
literal, then a single one. An empty arm between two separators is written
with a space between them (`| |`), because `||` is a literal. An
arm that prints nothing takes one space beside it away (1.5.20).

```
[a||b | c]{if="x > 0"}           arms "a|b" and "c"
[a\|\|b \| c]{if="x > 0"}        the same, as Pandoc's writer saves it
[a||| c]{if="x > 0"}             arms "a|" and "c"
site[s | | s]{n="k"}             an empty "one" arm: "sites", "site", "sites"
```

**1.5.13** Inside a pipe-table cell the arm separator must be written `\|`.
An unescaped one is a construct error. So must the `|` of a ladder in `unit`
(4.4.23), in a value or in a span: `` `r x`{unit="mm\|m\|km"} ``.

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

**1.5.18** An `n` or `sign` span with no formatter class, and no `digits` or
`sigfig`, formats its governor with the class named by the default governor
class setting (9.1.2). The setting defaults to `.num`, which prints a whole
number with no decimals (1.4.13). A span that refers to an id uses the
printed record instead (1.7.8).

**1.5.19** A `list` span chooses its arm by the length of an atomic vector: a
character, factor, number, logical or date vector. Its arms and their roles are
those of `n` (1.6): two arms are one / other, three are zero / one / other,
four are zero / one / two / other. One arm is a construct error.

```
[No sites were | # was | # were]{list="flagged"} flagged.
[none | # was | [# site | # sites]{n="."}: #]{list="v"}
```

`#` prints the vector collapsed as `.and` collapses it (1.4.3). Classes and
keys on the span act on `#`: a collapse class (`.or`, `.pairs`), `trunc`, `sep`
and `last`; a number or wording class and `digits` or `sigfig` format each
element first; a text class acts on the result. A number vector with no number
class prints each element as a bare value prints, a date as `format()` prints
it, and a logical as `TRUE` or `FALSE`. A number vector is accepted as it is,
and a count passed by mistake prints "3 was flagged".

A vector of length zero takes the zero arm. With no zero arm (two arms) it is
a failed claim, and its message says to add a first arm for the empty case
(1.5.3). `NULL`, an R `list`, a data frame, a matrix or array, any value that
is not an atomic vector, and a vector with an `NA` element are missing values
(1.3.4): a misspelt column must not print "No sites were flagged". `#` in the
zero arm is a construct error. An `#id` on a `list` span, and `list="."`, are
construct errors, and so is a list class (`.ul`, `.ol`, `.dl`) on a `list`
span, because `#` is inline. `#` prints the vector's elements as a value does,
so a number that prints as zero there records a warned check (1.4.13).
`claim()` in the expression works as in any governor (1.5.6). Inside an inner
`n="."` span `#` is the count (1.7.2), and in the span's own arm `#` is the
collapsed vector: the second example prints "3 sites: a, b and c" for
a vector of three.

**1.5.20** When a governed span prints nothing, because its chosen arm is
empty, one space beside it is removed, so the author writes ordinary spacing
outside the span. Arms are still trimmed (1.5.12).

- A space on both sides: the one before the span is removed.
- At the start of a block, or of a `weft_str()` string, a caption or a
  front-matter field, and followed by a space: that space is removed. The
  start of a block includes the text after a list, heading, quote or
  ordered-list marker, so the marker keeps its space.
- Preceded by a space and followed by the end of the block or string, or by
  one of `. , ; : ! ? ) ]`, the closing quotation marks U+201D and U+2019, or
  the em dash: the space before is removed. A straight quote is not one of
  them, as it may open.
- Otherwise nothing is removed.

```
a [x | ]{if="f"} b                  →   a b
fell [sharply | ]{if="f"}.          →   fell.
```

"A space" is one space character, or one line break inside a paragraph. A tab
is not a space. Only one space is removed, the one before the span, however
many there are. A run of governed spans with nothing between them is one
**chain**. The space before the chain is kept when any span of the chain prints,
and so is the space after it; a chain in which nothing prints is treated as one
empty span. `A: [x|]{if="FALSE"}[q|]{if="FALSE"}[y|]{if="TRUE"}.` prints
"A: y.". An empty span inside an arm is judged against its own arm's text. A span that
prints something changes nothing around it, and a value that prints an empty
string is not a span.

### 1.6 Plural forms

**1.6.1** Plural forms follow the document's `lang`. An `n` span has one arm for
each plural form the language has, in CLDR's order (zero, one, two, few, many,
other), or a single arm that is a template for `#` (1.5.1). A `list` span has
the same arm counts, except that a single arm is a construct error (1.5.19).

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

**1.6.5** English is shipped. Under a `lang` whose rules are not shipped, an `n`
or `list` span with more than one arm is an error. English rules are never
applied to another language.

**1.6.6** Any other exact number is R: `of_n()` (§3.5), a `lookup()`, or a
nested `if`.

**1.6.7** `lang` is matched on its primary subtag: `en-AU` and `en_GB` are
English.

**1.6.8** The wording classes (`.no .word .count .ord`), the collapse classes
that print a word (`.and .or .pairs .range`, and `trunc`), `.a`, `.date`, and the
phrase functions that print words (`of_n()`, `about()`, `ci()`) print English.
Under a `lang` whose words weft does not ship, using one is a construct error,
found from the source.

`.uname` prints a unit's name, which is words, so it is one of them: under such
a `lang` it is a construct error from the source, `unit_form: name` in a
setting is a configuration error when the knit is initialised, and
`unit_form = "name"` on a function is a construct error when it is called. A
symbol is not words, so `auto` and `symbol` still work there. A unit that has
no symbol (`year`, or `symbol: false` in `units:`, 9.1.7) would print by its
name, and is a value error where it would print.

### 1.7 Agreement, ids and back-references

**1.7.1** Whole arms are the plain idiom for agreement.

```
[# sample was taken | # samples were taken]{n="n"}
```

**1.7.2** An inner span may inherit the enclosing governor with `n="."`. It is
legal inside an `n` span, inside a `list` span, where its count is the
vector's length, and inside a `sign` span, where it agrees with the magnitude
as printed. There is no `sign="."` and no `list="."`.

```
[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}
[rose by # point[ | s]{n="."} | fell by # point[ | s]{n="."}]{sign="d"}
```

**1.7.3** A list and its verb are a value and an agreement.

```
`r sites`{.and} [was | were]{n="length(sites)"} sampled.
```

When the list can be empty, the list and its verb are one `list` span (1.5.19).

**1.7.4** A span that names the governor again (`[was | were]{n="n"}`) agrees
with the value as that span prints it.

**1.7.5** An `#id` on a value or a governed span names that one printed
occurrence. It is unique within a document; a duplicate is a construct error.
A `cite` span and a `list` span take no `#id`; one there is a construct
error.

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

**1.7.12** An id is also the construct's key in the ledger (7.1.4).

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
as given, in square brackets, after the span's prose and one space. Everything
Pandoc's citation syntax allows therefore works: a locator
(`cite="@smith2020, p. 4"`), a prefix, several sources separated by `;`, and
`-@smith2020` for the year alone. The author places the citation by choosing
where the bracket closes. Nothing is moved, and adjacent spans are not merged.

**1.8.4** In the bare form the value is keys only, separated by `;`, and the
citation is written elsewhere by the author (rule 5.4.2). Any other text in a
value with no `@` is a construct error.

**1.8.5** Each key must follow Pandoc's grammar for a citation key and must
resolve in the bibliography, in either form. This is checked at knit time and
by a lint (§5.4). At knit time a key that does not resolve is a collected
failure (§2.6), not a stop.

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

**1.8.10** A `.weft-literal` without a `why` is a construct error. A marked
span or block is not a finding: its `why` is its record, in the source, and
nothing else lists it.

**1.8.11** The `why` is removed from the output. The class is left on the span
or div as an ordinary Pandoc class.

### 1.9 What weft leaves alone

**1.9.1** These are never weft constructs:

- a bracket whose attribute block has none of `n`, `if`, `sign`, `list`,
  `cite`, in any letter case, and no weft text class (an ordinary Pandoc span,
  a link, a citation, a footnote), including one that carries a formatter
  class (1.1.9)
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
the output it produces without them. knitr sets its markdown output hooks
only when its default hooks are untouched as the knit starts. So outside a
knit `weft_setup()` installs only `before.knit` and `after.knit` hooks, which
knitr does not count, and the `before.knit` hook installs the rest once knitr
has chosen its output hooks. Called during a knit, `weft_setup()` installs
them at once.

**2.1.8** `weft_setup()` also puts `claim()`, `plural()`, `glue_vec()`, `u()`,
`dict_glossary()` and the `fmt_*()` functions on the search path, below everything else, so inline
R can call them without `library(weft)` and an author's own function of the
same name wins.

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

**2.4.2** Everywhere else a failed check stops at once, unless it is a warned
one (2.4.6): in chunk code, in a pipeline target, in plain R, and in a
document in which the hooks never installed.

**2.4.3** `claim()` does not depend on knitr.

**2.4.4** During a knit, a failed check in chunk code is recorded before it
stops the chunk. A chunk with `error: true` then prints the error and the knit
carries on, and the render still fails at the end with the check in its report
(2.6.2). The same holds for a failed check caught by `try()` or `tryCatch()`:
it is recorded, and the render fails.

**2.4.5** A failed check that stops the knit prints, with its own error, every
failure collected before it. The warned checks collected so far are reported
whenever the knit ends (2.6.10), also when it stops on an error of any kind.

**2.4.6** A check given `level = "warn"` (3.1.11) neither collects a failure
nor stops, in any context. In a knit, in prose, a caption, a `weft_str()`
string or chunk code, the value is returned and prints as if the check had
passed, no marker is left, and the failed check is recorded as a warning
(2.6.10). Outside a knit it signals a warning.

### 2.5 Backstops against silence

**2.5.1** *The visible attribute block.* Without the hooks, a value's
attribute block shows as text (`1.2{.num}`). A `claim()` in its expression
stops the knit when the check fails or when `claim` is not found.

**2.5.2** *The end-of-document check.* The `document` hook compares the
constructs the scanner found in the input file with those that were
evaluated. Every construct outside an arm, and every construct in an arm that
was chosen, must have been evaluated. One that was not fails the render, named
with its line (tier 1). A document that `knitr::knit_exit()` ended is checked
down to the point where it ended.

**2.5.3** *The `weft-check` Lua filter*, installed in a Quarto project by
`use_quarto()`, and in an rmarkdown document or project by `use_setup()`.
After knitting, the render fails on:

- any span that still carries `n`, `if`, `sign`, `list` or `cite`, in any
  letter case (1.2.10), or a weft text class (1.1.5)
- any text that still shows an attribute block
- any code span that carries a weft class or key (1.2.5)
- any code span that has an attribute block and whose text begins `r `, `R `
  or `{r}`, and any code span whose text begins `r ` (5.3.4)
- any leftover placeholder character
- any marker `<<weft:` (2.9.5)

It works when the package was never loaded, and when the file was never knit
(9.2.8). It covers captions. The filter exits through `os.exit(1)` (tier 1).
In draft mode it reports instead (9.4.3). Under rmarkdown, `use_setup()`
places the filter file and names it under the output format in the
document's front matter:

```yaml
output:
  html_document:
    pandoc_args: ["--lua-filter", "weft-check.lua"]
```

**2.5.4** *The `pre-render` check.* In a Quarto project, the `pre-render`
script that `use_quarto()` writes reads every `.qmd` the render will process.
It fails, naming the file, on one that holds a construct and has no
`engine: knitr` in its own front matter (9.2.8). Nothing has rendered by then
(tier 1).

### 2.6 Failures

**2.6.1** A failed check does not stop the knit. A failed check is a `claim()`
check that is not `TRUE` (2.4.1), a guard condition that is not `TRUE`, or a
case with no arm (1.5.3). A check given `level = "warn"` is not a failed check
here (2.6.10).

**2.6.2** Each failure is recorded (file, line, expression, value), a visible
marker is left in the text, and the `document` hook fails the render once,
listing every failure (tier 1). A failure with no line of its own is located
by its chunk label instead: one in chunk code (2.4.4), in a caption (with the
option, 2.3.2), or in a `weft_str()` string (2.6.8).

```
weft: 2 claims failed
  14-percentile-bands.qmd:412  "All 10 models rise"
      all(mod$rising) was FALSE
      optional text is written [phrase | ]{if="…"}
  14-percentile-bands.qmd:431  `r claim(shift$n_down, . >= 10)`
      . >= 10 was FALSE (value 7)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

**2.6.3** A failed guard is reported by its phrase as printed, with each
failing condition. The message says that optional text is written with an empty
second arm: `[phrase | ]{if="…"}` (1.5.5).

**2.6.4** An expression in a construct that cannot be evaluated (an unknown
object, a call that raises an error) is collected and reported the same way,
naming the expression and its line. An error in a bare value stops the knit
as stock does (1.1.8), and names its line. An expression that does not parse is a construct
error instead (5.3.5).

**2.6.5** A construct error (§5.3) stops the render at once, except in draft
mode (9.4.3).

**2.6.6** In a book the failures are held to the end. A `pre-render` script
opens a collection file, each chapter appends to it, and a `post-render`
script prints one report for the whole book and exits non-zero. The chapters'
output has been written by then, and carries the visible markers. The
collection file holds a warned check with `"level": "warn"`, the `post-render`
report lists warned checks after the failures, and a warned check does not fail
the render (2.6.10). While the file is open a chapter prints no warnings of its
own.

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

**2.6.10** A warned check (2.4.6) that is not `TRUE` is recorded apart from the
failures, with the same fields: file, line, expression and value. The value
prints, no marker is left, and the render does not fail, in draft mode or out
of it. At the end of the knit the warnings are printed to stderr in the layout
of 2.6.2, under a heading of their own, whether or not the render also fails. A
failed render's error message lists failures only. The warnings are in
`last_knit()$warnings` (3.7.5), and in the draft JSON file (9.4.2).

```
weft: 1 warned check(s)
  14-percentile-bands.qmd:431  `r claim(n_down, . >= 10, level = "warn")`
      . >= 10 was FALSE (value 7)
```

**2.6.11** A number that prints as zero is a warned check of kind "printed as
zero". When neither `digits` nor `sigfig` is given for the value, and a number
that is not zero prints with no digit other than 0, one is recorded for the
construct or the call, however many of its elements print so: the message
gives the first value, what printed and the count. A project default `digits`
does not count as given. It applies wherever weft prints a number under the
default digits (1.4.13): to a value formatted by `.num`, `.pct`, `.range` or
`.pairs`, including the default class of a value with an attribute block, to
`fmt_num()`, `fmt_pct()` and `fmt_range()`, and to `ci()` and `pm()`, which
record one check per call. `.no` replaces a printed zero and the check is
still recorded. A number class applied to text that a formatter already made
warns by what it prints itself: if the class prints zero for a number that is
not zero, and has no `digits` or `sigfig` of its own, it records the check,
whatever the earlier formatter was given. The rule does not apply to `.sci`,
to `about()` or `of_n()`, or to a project formatter. An `n` or `sign`
governor, and its `#`, are exempt: a `sign` governor that prints "0.0" takes
its zero arm (1.5.10). The `#` of a `list` span is not exempt (1.5.19). A
number below 1e-9 is zero (1.4.13) and is never warned about.

```
0.04 printed as 0.0: add sigfig to show it, or digits to confirm it
```

When the value is a quantity in one SI unit that takes a prefix (`m`, `g`, `L`,
`Hz`, `Pa` and the like), and a prefixed unit would print it as a number from 1
up to 1,000, the message adds it: "... or digits to confirm it; or show it in a
prefixed unit, such as unit = "mm"". A compound unit gets `digits` and `sigfig`
only. Under a ladder (4.4.23) the advice is the ladder with that unit put first
(4.4.13). weft does not rescale by itself.

Outside a knit, `fmt_num(0.04)` returns "0.0" and signals a `warning()` of
class `weft_zero_warning`. `weft_str()` outside a knit signals the same
warning and returns the text.

**2.6.12** A unit warning (4.4.10, 4.4.24) is a warned check of kind "unit
warning", recorded as 2.6.10 records one: it is reported at the end of the
knit, fails nothing, and is in `last_knit()$warnings`. It is not a `warning()`
of R, and the condition log does not record it. Outside a knit the same
conditions signal a `weft_unit_warning`.

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
and check the cached values. A cached chunk replays the constructs it recorded
into the ledger, as it replays its conditions (7.4.1). Stage 1 refuses a
caption construct in a cached chunk, so what is replayed is the chunk's
`weft_str()` strings.

**2.9.2** A document served from Quarto's `freeze` is not executed, and none
of its checks run. Every executed document writes a stamp. After an ordinary
render the `post-render` script reports each document with constructs that
was served from freeze: how many checks did not run, and when they last did.
For a document whose stamp records no failures, this is a report and fails
nothing.

**2.9.3** `verify()` fails on a document it verifies that was served from
freeze (8.1.1, 8.2.1; tier 1).

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
`weft_str()`. The lints, the gate, the ledger, `arms()` and the
end-of-document check all take from it what the constructs are and where.

**2.10.3** The static lints tell prose from code, math, links and raw content
with the package's own reader, a function over the source text that returns
the prose as a string as long as the file, every other character blanked.
It runs no Pandoc, and gives the same answer on every machine. Under
`lints(reader = "pandoc")` the source is also parsed with
`commonmark_x+sourcepos` by Pandoc, taken from the option `weft.pandoc`, the
variable `WEFT_PANDOC`, Quarto's own copy, `rmarkdown`'s or the path, at
version 3.0 or later, with the range of every construct's code and attribute
block masked first (2.10.5), so positions are unchanged. A character is then
prose only when both readers say so. Without Pandoc that call is an error.
Pandoc is optional, and is also the reference the tests compare the own
reader with.

**2.10.4** Neither reader parses citations. Citation brackets are recognised by
pattern (5.1.4).

**2.10.5** A construct is masked with one letter repeated to the length of
its range, never with spaces. A line break inside the range is kept. The
rule `block-start` (tier 1) finds a line inside a span that Pandoc's
`markdown` reader, the one Quarto and R Markdown use, cuts a paragraph at,
since the span is then cut in two. Only three lines cut one: a closed
backtick fence, a lone line of `-` or `=` (a setext underline) and a
definition line (`:` and spaces, then text). `#`, `>`, a list marker, `:::`,
`~~~`, `$$`, a pipe-table line and a fence with no closer do not, and are not
findings. It also finds a construct that starts a line indented four spaces or
more after a blank line outside a list, which is code. Under
`reader = "pandoc"` the unmasked source is read too, and any block whose type
or start line differs between the two trees is a finding at that line.

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
claim(x, <check>, ..., level = c("fail", "warn"))
```

**3.1.1** `x` is any type. `claim()` returns it visibly and unchanged, so a
value can be guarded in place inside a larger expression:
`` `r trend(claim(foo, . > 0))` ``.

**3.1.2** `.` in a check stands for `x`: `claim(shift$n_down, . >= 10)`.

**3.1.3** Each check is a separate argument and is reported separately.

**3.1.4** Checks are captured unevaluated, and a failure quotes the check as
written. In inline R the text is the document's. In other R code it is the
kept source where R kept it (`keep.source`), and the deparsed call where it
did not, so `1e6` may read `1e+06` there. A check that raises an error is a
failed check, reported with the error's message.

**3.1.5** A failure is collected or immediate by context (§2.4), unless the
check is a warned one (3.1.11).

**3.1.6** A check with no `.` and no variable cannot fail (`claim(x, TRUE)`,
`claim(x, 1 > 0)`), and an `if` whose condition holds no symbol and no call
other than operators and parentheses always takes the same arm (`if="TRUE"`,
`if="1 > 0"`), with one arm or two. Both are the tier-1 rule `inert-check`.
A call can vary, so `if="knitr::is_html_output()"` and `if="interactive()"`
are not inert. A check piped to `claim()` is read as the call it makes.

**3.1.7** A phrase is guarded by a one-arm `if` (1.5.5). There is no function
form.

**3.1.8** A guarded bracket is prose (1.5.15), so a numeral inside it must be
its own value. The idiom is to wrap the trigger word, or the clause, and nest
what is computed.

```
[All]{if="all(mod$rising)"} `r nrow(mod)` models rise
[All `r nrow(mod)` models rise]{if="all(mod$rising)"}
```

**3.1.9** A guarded bracket whose longest arm is longer than a set count of
words is listed (tier 2, `long-guard`). The count is `guard_words`, 25 unless
set; a value inside the arm counts as one word.

**3.1.10** `claim(x)` with no check is an error. Written in prose or in an
attribute value, it is a construct error found from the source (§5.3).
Anywhere else it stops at run time.

**3.1.11** `level` is `"fail"` (the default) or `"warn"`, and is given by name.
With `"fail"` nothing changes. With `"warn"`, a check that is not `TRUE` is
recorded as a warning (2.4.6, 2.6.10) and the value is returned. Outside a
knit it signals a `warning()` of class `weft_claim_warning`, whose message
quotes the check and the value, and returns the value. A check that itself
errors is a failed check at the level given. Any other `level` is an error. A
bare `"warn"` or `"fail"` in the position of a check is an error that says to
write `level = `. A guard has no level (1.5.5).

### 3.2 Function forms

**3.2.1** The markup exists in prose. In R code a construct has a function:

| Prose | R |
|---|---|
| `[…]{n="…"}` | `plural(n, "a person", "# people")` |
| a formatter or text class `.x` | `fmt_x()` (§3.4) |
| `claim(x, …)` in the expression | `claim(x, …)` |

**3.2.2** `plural()` takes its arms as separate arguments, in the order a span
writes them, and allows the same counts (§1.6):
`plural(k, "never", "once", "twice", "# times")`. A `#` in its arms prints
as a span's does, with the unit of a quantity (4.4.4).

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

**3.4.4** A formatter function given a `units` value prints its unit as the
class does (4.4.8), and takes `unit =` as the key does (4.4.14), and a ladder (4.4.23) as a string
(`"mm|m|km"`) or as a character vector (`c("mm", "m", "km")`). The `weft_text`
it returns carries the unit as the attribute `unit` whenever a unit is in its
text, in either form: it holds the unit's markdown text as printed for a plural
number (`m`, `years`). Two attributes go with it. `unit_form` is as long as the
text and holds `"symbol"`, `"name"` or `NA` for each element, and `units` holds
the unit as `units::units()` gives it after conversion, in the rung a ladder
picked. A text with no unit
carries none of the three. A fourth attribute, `unit_before`, is present only
when some element has its unit written before the number (4.4.22): it is as long
as the text and holds `TRUE` where the unit is before the number, `FALSE` where
it is after, and `NA` where there is no unit. The printed record does not hold
the unit (4.4.4).
A formatter function given such a `weft_text` formats the number afresh, in the
form in force for its own class, and places the unit as the class does, so
`fmt_and(fmt_num(u(c(3, 5, 7), m)))` is "3, 5 and 7 m". A collapse function
with `unit_form = NULL` keeps each element's form: `fmt_and(fmt_word(u(c(3, 5,
7), m)))` is "three, five and seven metres".
`glue_vec()` prints a quantity's number as it prints a plain number, with no
rounding of its own, then the unit.

**3.4.5** `fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`, `fmt_ol()` and
`fmt_dl()` take `none = NULL`, as the key does (1.4.14). A `none` that is
given must be one non-empty string that is not only spaces; anything else is
an error of class `weft_construct_error`. `last` on `fmt_and()`,
`fmt_or()` and `fmt_pairs()` defaults to `NULL`, so that the `serial_comma`
setting applies (1.4.15).

**3.4.6** `fmt_num()`, `fmt_pct()` and `fmt_range()` record a number that prints
as zero as the classes do (2.6.11).

**3.4.7** Subsetting a `weft_text` that carries a unit keeps the unit.

**3.4.8** `fmt_num()`, `fmt_sci()`, `fmt_range()`, `fmt_no()`, `fmt_word()`,
`fmt_count()`, `fmt_ord()`, `fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`,
`fmt_ol()` and `fmt_dl()` take `unit_form = NULL`, as the last argument. Its
values are `"auto"`, `"name"`, `"symbol"` and `"none"`, the forms of 4.4.15 and
the classes `.uname`, `.usym` and `.nounit`. `NULL` leaves the form in force for
a quantity (4.4.15), and the printed form of each element for a `weft_text`
(3.4.4). Any other value, and `"symbol"` on `fmt_no()`, `fmt_word()` or
`fmt_count()`, is a `weft_construct_error`; `"name"` is one too under a `lang`
weft ships no words for (1.6.8). A value other than `"auto"` on a value with no
unit is a value error (1.4.19), and `fmt_ord()` on a quantity that has a unit
is a value error (1.4.20). `plural()` takes no `unit_form`: write
`plural(fmt_num(x, unit_form = "name"), "# ago")`.

**3.4.9** `fmt_unit(x, unit_form = NULL, unit = NULL)` prints a unit alone, for
a heading. It is exported and attached (2.1.8). It returns a `weft_text` of
length one with no record and no unit attributes, so `fmt_cap()` works on it.
`x` is a quantity of any length (an `NA` is allowed, and no number is printed)
or one string, read as `u()` reads a unit. `unit` converts first, as it does
for the key (4.4.14). With a ladder (4.4.23) and a quantity, it picks as `.num`
would print `x`, one number or the vector rule, and prints that rung, in the
plural unless `x` has length one and prints "1": `fmt_unit(u(1500, m), unit =
"m|km")` is "km", with `unit_form = "name"` "kilometres", and `u(1000, m)` gives
"kilometre". A quantity with nothing to test (length zero, all `NA`) takes the
first rung. A ladder of more than one rung with a string is a
`weft_value_error`: a string has no number to pick by. `auto` and `symbol` print the symbol text and `name` the
name: `fmt_unit(u(5, mg/L))` is "mg/L", and with `unit_form = "name"` it is
"milligrams per litre". `"none"` is a `weft_construct_error`. The name is plural
unless `x` has length one and its number prints "1" under `.num`, and a string
takes the plural: `fmt_unit(u(1, m), unit_form = "name")` is "metre",
`u(1.04, m)` gives "metres" and `"m^2"` gives "square metres". A value that is
neither a quantity nor a string is a `weft_value_error`; a string `u()` refuses
is a `weft_unit_error`, as in 4.4.6. There is no `.unit` class. A unit that is
written before the number (4.4.22) prints as the unit alone: `fmt_unit(u(7.2,
pH))` is "pH".

**3.4.10** `unit_defaults()` takes no argument and is exported, not attached. It
returns weft's default units (4.4.21) as a data frame, one row per row of the
table in file order, with the columns `unit`, `is`, `name`, `plural`, `symbol`
(character, `NA` where blank), `space` (logical, `NA` where blank), `before`
(logical, `FALSE` where blank) and `redefines` (logical: whether the row
redefines a unit that `units` already reads, 4.4.21). The attribute `file` holds
the path of the YAML file the table is read from. It registers nothing.

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

**3.5.7** `of_n()` and `about()` given a quantity use its number: they print
words, and print no unit of their own. Given two quantities, they convert the
second to the first's unit before they compare, and units that do not
convert are a value error. `ci()`, `pm()` and `clamp()` given a quantity that
has a unit, or a formatter's text that carries one, are a value error whose
message says to pass the numbers or to format the parts with `fmt_num()`:
weft does not guess where the unit goes. A ratio, with no unit left, is a
number to them.

### 3.6 `weft_str()`

**3.6.1** `weft_str()` renders a markup string, for the text slots no chunk
option reaches: `ggplot2::labs()`, a `gt` footnote or column label,
`knitr::kable(caption = )`, text printed with `results: asis`.

**3.6.2** The lints read a literal string passed to `weft_str()` as prose.

**3.6.3** A string given to `weft_str()` is prose wherever it is called from.
During a knit, a failed check in it is collected as one in a paragraph is
(2.4.1). Outside a knit it stops at once. It reads the configuration as a knit
does: a configuration error is raised, and it never prints with half a
configuration.

### 3.7 `arms()` and `rehearse()`

```r
arms("daily.qmd")
rehearse("daily.qmd", cases = list(
  usual   = list(data = "tests/usual.csv"),
  empty   = list(data = "tests/no-rows.csv"),
  missing = list(data = "tests/all-na.csv")
))
```

**3.7.1** `arms(file)` lists every governed span in a document: its key (`n`,
`if`, `sign` or `list`), its expression, its file and line, and the text of
each arm. A span nested in an
arm is listed under that arm. It takes the spans from the scanner (2.10.2),
in prose, captions, front-matter fields and literal `weft_str()` strings, and
runs no R.

**3.7.2** `rehearse(file, cases = )` renders the document once for each named
case. A case is a list of `params`. Each render goes to a temporary
directory, and writes nothing to the project: no output, no ledger, no
condition log, no freeze entry.

**3.7.3** `rehearse()` reports, case by case, the failures the render collected
(as 2.6.2 lists them) and the arm each governed span chose, with the warned
checks it recorded (2.6.10), which do not make a case fail. It then lists the
arms that no case reached, and the spans that no case evaluated. A case that
fails is reported, and the next case runs.

**3.7.4** `rehearse()` changes nothing but `params`. A document that reads
its data some other way renders the same data in every case (§15).

**3.7.5** `last_knit()` is exported. It returns the records of the most recent
knit: `failures`, `warnings` (a data frame with the columns of `failures`,
and no rows when there are none), `constructs`, `sentence_starts` and the
others its help page lists. Before any knit it returns `NULL`. `rehearse()`
returns the same records for each case. `constructs` has a column
`unit_picked`: for a construct with a `unit` key, the unit it printed in, as
written in the ladder (`"km"`), and `NA` for a construct with no `unit`
(4.4.23).

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
never returns `NULL`, and never matches partially. The error says "Did you
mean" for the one key nearest the name within an edit distance of 2, and for
none when two keys are equally near. The dictionary reader and the pipeline
(4.6.4) use the same rule.

**4.1.3** Keys are valid R symbols, and not reserved words: `..1` and `...`
are refused. `file` is reserved.

**4.1.4** Chunk code may not assign to `dict` or redefine one of its keys
(tier 1, §5.8).

**4.1.5** A dictionary is read-only. `dict$x <- v`, `dict[["x"]] <- v`,
`dict["x"] <- v` and `names(dict) <- v` are errors, and so is `dict["x"]`:
write `dict$x` or `dict[["x"]]`. `names()`, `length()`, `str()`, `summary()`
and `lapply()` work as they do on the plain list of values.

**4.1.6** At the start of each top-level knit, weft removes the `dict` and
`dict_local` that it assigned in an earlier knit, before it reads this knit's.
A document with neither dictionary sees neither. A session's own object named
`dict` is replaced during a knit that has a dictionary, and is not restored.

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

**4.2.1** An entry has a `value`, a `type` and a `definition`. `decision` is
optional, and so are `term` (any type, 4.7.3) and `avoid` (4.7.4). `unit` is required for `type: quantity` and an error on any other
type. `display`, one unit, is optional on a `type: quantity` entry
(4.2.7) and an error on any other type. A field that is not named here is an error; the problem lists
the nine fields: `value`, `type`, `definition`, `unit`, `display`, `decision`,
`why`, `term` and `avoid`.

| `type` | `value` is | Read as |
|---|---|---|
| `number` | a number | a number |
| `quantity` | a number, with a `unit` | a `units` object (§4.4), in its `display` unit when it has one |
| `year` | a four-digit year | a year (4.2.4), an integer that is never given a thousands mark |
| `date` | an ISO date | a `Date` |
| `string` | text | a string |
| `labels` | a map from key to phrase | a `lookup()` (3.3.2) |
| `breaks` | a list of bound and phrase | a `brk()` (3.3.3) |

Any other `type` is an error when the dictionary is read.

**4.2.2** A dictionary holds stipulations, never derivations: things that were
chosen. Anything computable belongs in the pipeline.

**4.2.3** A `type: labels` entry is returned as a `lookup()` (3.3.2).

**4.2.4** A `type: year` entry is read as a year: an integer with class
`weft_year`. A year stays a year through `c()`, `[`, `[[`, `rev()`, `sort()`,
`unique()`, `min()`, `max()`, `range()` and `seq()`. `year + n`, `n + year`
and `year - n` are years, and a result that is not whole is a plain number.
`year - year` and any other arithmetic give a plain number. Comparisons work
as on integers, and `as.integer()`, `as.numeric()`, `format()` and `print()`
show the bare integer. Every number and wording class prints a year with no
thousands mark whatever `thousands_from` says (1.4.16), `.ord` included:
`dict$era_split` prints "2014", `dict$era_split + 1` prints "2015", and
`range(c(dict$era_split, dict$era_split + 10))` in `.range` prints
"2014–2024". When `vctrs` is loaded, a year combined with a year is a year,
and a year combined with an integer or a double is a plain integer or double.

**4.2.5** The YAML of a dictionary file is restricted to what its author can
read at a glance. Each of these is a problem, never read silently:

- a number written with a leading zero (`010`), whether or not it is quoted,
  or in hex or octal (`0x1F`, `0o17`), under `number`, `quantity`, `year` or
  a bound of `breaks`. The problem says to write it in decimal;
- a merge key (`<<`). Anchors and aliases without one are allowed;
- more than one YAML document in the file;
- an unquoted `null` as a key. A quoted `"null"` is a key;
- a duplicate key.

`yes`, `no`, `on`, `off`, `true` and `false` stay as text, so a `labels` map
may be keyed by them. A number written as a string (`"1e-3"`) is accepted
where a number is wanted, and so is a whole number beyond the integer range
(read as a double; under `year` it is an error). A string entry must be
quoted if it looks like a number.

**4.2.6** A dictionary that has problems is not half-read. `read_dict()`
collects every problem, from every entry, and raises them together as one
error, one line per problem with the file, the line of the entry's key, the
field and the rule. A read that reports problems registers no unit of the project's (4.4.7).
Two bands of a `breaks` entry that leave a band which can never be chosen
(an `at_most` followed by a `below` of the same number, or equal bounds of
the same kind) are a problem.

**4.2.7** `display:` is optional on a `type: quantity` entry, in `dict.yml` and
in `dict_local`. The value is read in `unit` and converted to `display`:

```yaml
reach_len:
  value: 2000
  type: quantity
  unit: m
  display: km
  definition: "Length of the surveyed reach."
```

`dict$reach_len` is 2 km. `.num` prints "2 km", `.uname` "2 kilometres", and
`{unit="m"}` "2,000 m". Arithmetic, checks, `#`, `units::drop_units()` and the
pipeline all see km. The `display` unit is registered as `unit` is (4.4.7). The
glossary prints the held unit when `display` would print the value as zero
(4.7.1).

`display:` takes one unit. A ladder (4.4.23) in it, written as a `|` string
(`display: m|km`) or as a list of more than one item (`display: [m, km]`), is a
`read_dict()` problem that tells the author to write the ladder in a `unit` key
where the value is printed. A list of one item is that unit. A `unit` at the use
wins over `display:` (4.4.15), and its ladder picks from the value in whatever
unit the dictionary gave it.

These are problems of the dictionary (4.2.6): `display` on another type, one
that does not parse, one that `unit` does not convert to, and one that `units`
reaches only by inverting the value (4.4.14), and a `display` that is a
ladder, as above, or is neither a string nor a list of strings. The `entries`
attribute of the dictionary holds a `display` column, `NA` where an entry has
none, then a `term` column (`NA` where absent) and an `avoid` column (a list
column, `character(0)` where absent), and `print()` shows the unit the entry is held in. An entry holds no form setting:
the form is the reader's choice (4.4.15).

### 4.3 Local entries

**4.3.1** A chapter may narrow a key. The local entry is read through
`dict_local$sites`, never `dict$sites`.

**4.3.2** `dict_local$x` with no local `x` is an error. `dict$x` where the
chapter defines a local `x` is an ambiguity error.

**4.3.3** A local entry requires a `why:` field. The `why` is its record, in
the source, and nothing else lists it.

**4.3.4** A chapter's local entries are written in its front matter, under
`weft:` / `dict_local:`, in the form of §4.2 plus the `why`. `dict_local` in
`_weft.yml` is a configuration error. `dict_local` is empty, not absent, in a
chapter with no local entries and a project that has a dictionary, so that
4.3.2 gives its error instead of "object not found".

**4.3.5** Local entries belong to the document that is knitted. A child
document with its own `weft: dict_local:` is an error naming the child. A
local entry need not exist in `dict.yml`, and its type is not compared with
the project entry's.

### 4.4 Quantities

```r
x <- dict$core_len            # 0.5 m
y <- dict$reach_len           # 2 m
x * 100                       # 50 m
x / y                         # 0.25, with no unit
x * y                         # 1 m²
x + dict$sample_mass          # error: cannot convert kg into m
claim(dict$salinity_res, . < u(0.05, PSU))
```

**4.4.1** A `type: quantity` entry is read as a `units` object, made with
the `units` package from its `value` and its `unit`. All arithmetic on it is
that package's: a unit survives addition and scaling, combines under
multiplication and division, cancels in a ratio, and converts where it can.
Adding two units that do not convert is an error.

**4.4.5** Comparing or adding a quantity and a bare number is an error. A
check states its unit: `claim(x, . < u(0.45, ug))`. The failed check's report
says so: "state the check's unit, as in `. < u(0.45, ug)`".

**4.4.6** weft exports `u(value, unit)`, a short wrapper for
`units::set_units()`: `u(35, m)`. The unit is written as it is, or as a
string (`u(150, "CFU/100 mL")`), and is never evaluated as R, so a variable
named `m` is not read. The value is a number or a `units` object, which is
converted: `u(dict$core_len, cm)` is 50 cm. `u()` registers no unit of its own;
the first parse of a unit in a session registers weft's default units (4.4.21).
A unit the units database does not know, a unit the value does not convert to, a
unit with a power that is not a whole number (`m^0.5`), a value that is not
a number and a missing unit are each an error of class `weft_unit_error`.
So is a unit that 4.4.20 refuses. A missing logical is a number here: `u(NA,
mm)` is a missing quantity and `u(logical(0), mm)` an empty one. `TRUE` and
`FALSE` are refused.

**4.4.7** When it reads the dictionary, weft registers every unit symbol the
units database does not know, with `units::install_unit()`. `PSU`, `NTU` and
`sites` are examples. Reading the same file twice is silent and gives the same
object: the unit symbols the dictionary needs that the units database does
not have are listed in the attribute `registered`, whoever installed them. A
unit that cannot be parsed, or that `units` parses only with a warning, is a
problem with the dictionary (4.2.6), not a new unit. A power that is not a
whole number is a problem too, and so is a unit that 4.4.20 refuses. A key of
the `units:` table (9.1.7) registers its unparseable tokens in the same way,
when the configuration is read, before the dictionary. weft's default units
(4.4.21) are registered before either. A read that has problems leaves the
default units registered and registers nothing of the project's. A row of
`units:` with `is:` installs the definition it gives (9.1.7).

**4.4.8** Any `units` value, from the dictionary or from the pipeline,
prints with its unit when it has a weft formatter. The number stage formats
the number. The unit follows after a no-break space (U+00A0) except where the
space rule below says otherwise, and its symbol text is Pandoc markdown, as
`.sci` writes its power: an exponent is a superscript, so
"1.2 m²" is written `1.2 m^2^`; a negative exponent uses the minus sign
U+2212 (`m^−3^`); a product is written with the middle dot U+00B7 (`kg·m`).
A unit with a numerator keeps its quotient (`mg/L`, `m/s^2^`); a unit with no
numerator is written with negative powers (`m^−3^`), not "1/m^3^", however it
was typed: `1/s` prints `s^−1^`. Anything
else is written as `units` writes it (`°C`, `sites/ha`). Characters that
markdown reads (`_`, `*`, `~`, `^`, `[`, `]`, `` ` ``, `\`) are escaped, except
the superscript marks weft writes. A value with no unit left, such as a
ratio, prints the number alone.

Three things differ in the symbol text. A token typed as a name, standing
alone, prints its unit's symbol, so `kilometre` prints `km` and `microgram`
`µg` (in a compound it prints as typed, 4.4.20); a token typed as a symbol
prints as typed (`ug`). A unit with no symbol prints its name, in
the plural in a numerator and the singular in a denominator ("10 years",
"5 kg/year"); a prefixed unit of such a row prints its symbol, as typed
("3,000 Myr"). A row of `units:` whose `symbol` is `false` has no symbol in any
form, and so has a row that gives a `name` and no `symbol` for a unit the project
defines: a unit that neither weft's default table nor the `units` database knows,
or one the row defines with `is:`. Such a unit prints by name in every form ("1
site", "12 sites"). A row that gives a `name` to a unit weft or the database
already knows (`m`, `NTU`, `PSU`) keeps that unit's symbol, and a row with
neither a name nor a symbol prints its key. For a unit with no symbol: a prefixed token of it prints by name where a name is allowed, and is a
value error that says it has no symbol where it is not. A `symbol:` in `units:` (9.1.7) replaces its unit's text, whole
or one factor, as written.

**The space.** The space is between the number and the unit on whichever side the
unit is written (4.4.22). There is none before a unit whose whole symbol is `%`,
`°`, `′` or `″` ("35%", "45°"). Before every other symbol there is a no-break space
("20 °C"), and before every name. A `space:` in `units:` sets it for one unit's
symbol only, and a compound takes the space unless its own key says otherwise;
a name always has its space, so `space: false` never removes the space before a
name. What weft
derives is escaped as above; the text of a `units:` entry is markdown, printed
as written.

The number stage gives a project formatter (1.4.8) the bare number, and weft
adds the unit after it. A project collapse formatter receives each element
with its unit. A quantity with a text class, `.strong` for one, keeps its
unit inside the markup (`**3 m**`), on every route. Text classes nest as they
are applied (`fmt_em(fmt_strong(x))`), the unit stays inside the markup of
each, and the same class applied twice applies once.

`.pct`, `.p` and `.date` given a quantity that has a unit are a value error:
dropping the unit would be the silent error of 4.4.5. A quantity with no unit
left is a plain number to them. For `.pct` on a quantity in per cent the message
says that the unit already prints "%", so `.pct` is to be dropped.

**4.4.2** The unit follows the number, in the form that goes with it. A number
in digits takes the unit's symbol ("5 m"). A number a wording class has
spelled, and "no", take the unit's name ("five metres", "no metres"): a unit
symbol belongs with a numeral, and a spelled number takes the name. The author
writes neither; weft prints both. A number still in digits keeps the symbol:
`.count` at or above its threshold and `.word` at or above its limit, and so
does a `.no` that prints a number ("2 m"). `.ord` on a quantity is a value
error (1.4.20). `.nounit` drops the unit
(1.4.19): `.word .nounit` on `u(3, m)` prints "three". The forms and the
settings that change them are 4.4.15's.

**4.4.3** A collapse prints the unit once, after the last item, in that item's
form: "3–5 m", "3, 5 and 7 m"; a unit that is written before the number goes
before the first item instead (4.4.22). With `trunc` the last item is the last one
printed: "3, 5 m and 2 others". Whatever the last item is, the unit follows it:
`u(c(200, 5), m)` under `.word .and` prints "200 and five metres", and
`.count .and` on `u(c(3, 12), m)` prints "three and 12 m". `.pairs`, `.ul`,
`.ol` and `.dl` print the unit with every element, each in its own form. A collapse over spelled numbers takes the unit's name
under `auto`: `.word .and` on `u(c(3, 5), m)` prints "three and five metres",
and under `symbol` it is the value error of 4.4.15. A
vector that no collapse class joins prints it with every element as well ("3 m,
5 m"), as stock prints the vector; `.count` on `u(c(3, 12), m)` prints "three
metres, 12 m".

**4.4.4** `#` in an arm prints what the governor would print as a value
under the span's classes, so it carries the unit in the form 4.4.2 gives: the
symbol after digits, the name after a number a wording class has spelled. This
holds whatever the governor is: a quantity, a formatter's text for a
quantity, an id, `n="."`, a `sign` span, `plural()`. `#` keeps the unit
whatever classes or keys the span has: a back-reference and a formatter's text
keep the quantity, number and unit, so `.word`, `digits`, `.uname`, `.nounit`
and `unit=` on the span act on `#` as on the quantity itself. A unit written
before the number (4.4.22) precedes `#`'s number. In a `list` span over
quantities `#` is the collapsed list with the unit once after the last number
(4.4.3), with or without a number class. The author does not write the unit
in the arm: `[# was | # were]{n="dict$core_len"}` prints "5 m were", the
number and the unit joined by a no-break space, and with `.word` it prints
"five metres were". The printed record (1.4.11) holds the number, not the
unit. An author who wants the name with digits writes `.uname`, and the number
alone writes `.nounit` (1.4.19), or gives the number alone with
`units::drop_units()`. A `unit=`, one unit or a ladder, on a span governed by a
formatter's text that carries a quantity acts on that text, on every route
above.

**4.4.9** A quantity that governs a span contributes its number. Selection
sees the number as it prints, as for any governor (1.5.9), after any
conversion by `unit` (4.4.14), in the rung a ladder
picked (4.4.23).

**4.4.10** A bare value with no attribute block prints as stock knitr prints
it (1.3.1): the number, without the unit. When the value is a quantity with a
unit, the construct raises one unit warning (2.6.12; class `weft_unit_warning`
outside a knit) saying that the value is a quantity whose unit is not printed,
and that `{.num}` prints it and `{.nounit}` says the unit is not wanted. A
quantity with `{.nounit}` alone prints the number as weft formats it, with no
warning.

**4.4.11** `units` is a dependency of weft (`Imports`), so `u()` is always
available. Its system requirement is the udunits-2 library. The CRAN
binaries for macOS and Windows carry it; on Linux it is one system package,
which every weft installation there needs.

**4.4.12** A list of quantities, and a vector of mixed units
(`units::mixed_units()`), given to a formatter, a governor or `glue_vec()` are
a value error: weft prints one unit for one vector.

**4.4.13** A quantity that prints as zero under the default digits prints "0.0"
and its unit, and records the warned check, as a number does (1.4.13):
`u(0.04, m)` under `.uname` prints "0.0 metres". A
missing element is the "no value" failure, as for a number. The warned check
says how to show the value: `digits` or `sigfig` and, when the unit is an SI
unit with no prefix, the prefixed unit that would print a number from 1 up
to 1,000 (`unit = "mm"` for 0.04 m). For a compound unit it names `digits` and
`sigfig` only. weft does not pick the unit itself, except from a ladder the
author wrote (4.4.23).

Under a ladder a quantity prints "0.0" only when every rung prints zero, since
a rung that shows a number other than zero is nearer; the rung is then the
first. When the first rung is an SI unit with no prefix, the advice is the
ladder with the prefixed unit that would print from 1 up to 1,000 put first:
`unit="mm|m|km"` for 0.04 m under `unit="m|km"`. For a compound first rung, and
for a vector of which the picked rung prints only some elements as zero
(`u(c(0.0001, 500), m)` under `m|km` prints "0.0 and 500 m"), it names `digits`
and `sigfig` only. `digits` or `sigfig` silences the check as before.

**4.4.14** The key `unit="m"` on a value construct or a governed span, and the
argument `unit =` of the number-stage formatter functions, give the unit to
print in, or a ladder of units, `unit="mm|m|km"` (4.4.23), to pick it from. The quantity is converted before anything else, so the number, the
unit printed and the arm chosen are all in that unit: a value of 150 cm with
`unit="m"` prints "1.5 m", and `[# is | # are]{n="x" unit="m"}` with `x` of
100 cm prints "1 m is". A unit the quantity cannot be converted to, and
`unit` on a value that is not a quantity, are value errors, for every rung of a
ladder. So is a unit that
`units` reaches only by inverting the value: `unit="1/m"` on a length and
`unit="Hz"` on a time are refused, and an author who wants the reciprocal writes
it in the expression. A conversion between two quotients is allowed:
`L/(100*km)` to `km/L`. A conversion from one of the twin units to another is a
value error: the `units` package defines the sievert, the gray and the rem
alike, the becquerel, the curie, the baud and the hertz alike, and the
volt-ampere and the watt alike, though each group measures different things. A
unit that a project defines as a twin is one too. `u(2, Sv)` with `unit="Gy"` and
`u(2, Bq/L)` with `unit="Hz/L"` are refused, with any prefix and alone or in a
compound. A conversion within one of them (`mSv` to `Sv`) and to the SI
definition (`Sv` to `J/kg`) is allowed. A conversion between a frequency or
activity unit (`Hz`, `Bq` and their prefixes) and a unit of angle per time
(`rpm`, `rad/s`, `degree/s`) is a value error too, as the twins are, because
`units` reads a hertz as a radian per second. `of_n()`, `about()` and `claim()` given
a comparison of twins raise the same error; a `claim()` raises it, and it is not
a failed check. Arithmetic between twins is the `units` package's own, so a
ratio of two of them is a plain number. `display:` (4.2.7) follows the same
rule, and is a problem of the dictionary.

**4.4.15** A unit prints in one of two forms: its **symbol** ("5 m") or its
**name** ("five metres"). The setting nearest the use decides the form: the
use first (`.uname`, `.usym`, `.nounit`, or `unit_form =` on a function), then
the document (`weft: unit_form:`), then the project (`unit_form:` in
`_weft.yml`), then `auto`. The unit shown follows an order of its own: `unit=`
at the use, one unit or a ladder (4.4.14, 4.4.23), then the dictionary's `display:` (4.2.7, one unit), then the
value's own unit. What the form in force prints:

| Form in force | A number in digits | A number a wording class has spelled, or "no" |
|---|---|---|
| `auto` | the symbol | the name |
| `name` (`.uname`) | the name | the name |
| `symbol` (`.usym`) | the symbol | a value error |
| none (`.nounit`) | nothing | nothing |

Every element carries its unit, in digits or in words, and 4.4.3 places it. A
`.word` count that prints in digits (`u(12, m)`) prints "12 m" under `auto`.
The number and a name are joined by a no-break space, as a symbol is, except
before a symbol whose space is off (4.4.8). A value error under `symbol` says
which class made the number a word, the form and where it was set, that a
spelled number takes the name, and that `.uname`, `.nounit` or dropping the
class would print: SI style has no "five m". A unit that has no symbol, under `symbol`, prints its name with a spelled
number and is no error: `u(5, year)` prints "5 years" under `.usym`. A setting
`unit_form` on a value with no unit changes nothing (1.4.19).

**4.4.16** A symbol never changes. A name is singular only when its number
prints "1" or "one": 1 exactly, with no decimals, and the relation `=` (1.5.9).
So "0.5 metres", "0 metres", "1.0 metres" and "−1 metres" are plural, and
`u(1, m)` prints "1 metre" under `.uname` and "one metre" under `.word`. In a
collapse the name is singular only when exactly one number prints and it is "1"
or "one": "3, 5 and 1 metres", "1 metre and 2 others" (`trunc="1"`), and a
`.range` with both ends "1" prints "1 metre". `.pairs`, the list classes and
a vector that no class joins judge each element, and `#` in a `sign` span
judges the magnitude.

The plural is the project's `plural` (9.1.7), else the shipped one (4.4.17), else
the database's plural name (`_` as a space), else the English rule on the last
word: "es" after s, x, z, ch and sh; consonant and "y" to "ies"; otherwise "s".
A project `name` given with no `plural` takes the English rule. A prefix goes
before the plural ("milligrams", "millidegrees Celsius"), and a name that holds
" per " takes its plural before it. A prefix is joined only to a one-word name:
where the language's name has more than one word (en-US "metric ton"), the
prefixed unit takes the default name ("megatonne").

**4.4.17** `units` keeps each token as written: `u(10, year)` holds `year`,
`u(2, kilometre)` `kilometre`, `u(5, metre)` `m`, and `u(150, "CFU/100 mL")`
holds `CFU` over `100` and `mL`. weft resolves a token by the first of these
that fits:

1. a row of `units:` in force (9.1.7) whose key resolves, by 2 to 5, to the same
   unit: the document's row, else the project's, over weft's default table's
   (4.4.21). A token that a row defines with `is:` resolves as itself, and is
   never split into a prefix and a unit;
2. the shipped table below;
3. a row of `units::valid_udunits()` that has the token as its symbol, a symbol
   alias, a singular or plural name or alias, or has it as the English plural
   of its singular name or an alias (`years`);
4. a prefix of `units::valid_udunits_prefixes()` and a rest that 2 or 3
   resolve: a prefix symbol (`u` counts as `µ`) before a symbol, or a prefix
   name before a name, the longest prefix first (`mL`, `kilometers`, `ug`,
   `dam`);
5. otherwise the token is unknown: its symbol is itself, and it has no name.

So `min` is a minute, `Pa` a pascal and `ha` a hectare. Two tokens are one unit
when they resolve to the same prefix and row, or are the same unknown token:
`metre` and `m` are one, and so are `year`, `years` and `yr`; `L` and `dm^3` are
not.

A token's name is, in this order:

1. the `name` of a row of `units:` in force (the document's, else the project's,
   over the default table's, field by field);
2. the shipped name;
3. what the author typed, when it is a name or alias of the unit, with `_`
   printed as a space and the plural from the database's alias plural, else
   the English rule: `u(3, knot)` is "3 knots", `u(2, light_year)` is "2 light
   years";
4. the database's singular name, only when it is one plain word ("pascal",
   "gram"), with a prefix name joined to it with nothing between
   ("kilometre").

A technical name of the database (`international_knot`, `IT_calorie`,
`US_liquid_cup`) is never printed: the unit has no name (4.4.19), and its symbol
form prints as the author typed it. Under a `lang` of `en-US` or `en_US`, in any
letter case, the en-US column applies; under any other English `lang`, or none,
the other, with the prefix "deca" for "deka". The shipped table is in full:

| Unit | Name | en-US | Plural | Symbol | Space |
|---|---|---|---|---|---|
| `m`, `L`, `t` | metre, litre, tonne | meter, liter, metric ton | | | |
| `ha`, `hectare` | hectare | | | `ha` | |
| `yr`, `year` | year | | | none | |
| `bar` | bar | | | `bar` | |
| `ft` | foot | | feet | | |
| `in`, `mi`, `lb` | inch, mile, pound | | | | |
| `°` | degree | | | | off |
| `′`, `″` | | | | | off |
| `%` | per cent | percent | as the singular | | off |
| `Hz`, `lx`, `S` | | | as the singular | | |
| `VA` | volt-ampere | | | | |
| `Bd` | baud | | as the singular | | |
| `knot`, `calorie`, `horsepower`, `ton`, `gallon`, `Btu` | knot, calorie, horsepower, ton, gallon, Btu | | | | |
| `degF`, `degC` | degree Fahrenheit, degree Celsius | | | `°F`, `°C` | |
| `mmHg` | millimetre of mercury | millimeter of mercury | | `mmHg` | |

A blank cell takes the database's. A unit the table does not hold and whose
database name is technical prints as the author typed it, by 4.4.17's third
rule: `byte`, `cycle`, `revolution`, `cup` and `quart` print as typed. The day, hour and minute (`d`, `h`, `min`)
are not in the table, so they print as symbols; a project that wants "5 days"
writes `symbol: false` for `d` (9.1.7).

**4.4.18** A compound unit's name is built from its factors. A power of 2 or 3
is "square" or "cubic" before the name of a length (a unit that converts to
`m`) and "squared" or "cubed" after any other. The numerator's factors are
joined by a space, then " per " and the denominator's, joined by a space; with
no numerator the name starts "per". Only the last numerator factor takes the
plural. `u(5, mg/L)` is "5 milligrams per litre", and "5 milligrams per liter"
under `en-US`; `u(2, m^2)` is "2 square metres"; `u(9.81, m/s^2)` is "9.8
metres per second squared"; `u(3, kW*h)` is "3 kilowatt hours"; `u(2,
"1/m^3")` is "2 per cubic metre"; `u(5, sites) / u(2, ha)` with `sites` named in
`units:` is "2.5 sites per hectare". A whole-unit key of `units:` wins over the
names of its factors.

**4.4.19** A unit has no name when a factor is unknown with no `units:` entry, when
its only name in the database is technical and the author did not type a name
(4.4.17), when its database row has no name (a row with a symbol and an empty
name is never named by its symbol: `s` is not a name), when the unit holds a
number (`100` in `CFU/100 mL`), or when a power is not 1, 2
or 3 (a negative power with no numerator, such as `s^-2`, is one; `1/s` is "per
second"). weft never guesses a name. A name that may print for a unit that has
none is a value error, raised in a knit as a collected failure (5.3.2). It is
judged on the classes, not on the data: `.no`, `.word`, `.count` or a project
wording formatter on a quantity may print a name, so under `auto` the unit
needs one even when every number in the vector prints in digits, and under
`symbol` the wording class is the error of 4.4.15. Neither error comes and goes
with the data. Under a ladder (4.4.23) each is judged on every rung, before the
pick: a name for each rung under a wording or `.uname` class, the symbol form
with a spelled number, and the `lang` rule. The message names the unit as `units` writes it and says why it
has no name, shows how to add it to `_weft.yml` under `units:` with a YAML
example keyed by it (9.1.7), and offers `.usym` or `.nounit` instead.

**4.4.20** weft prints the unit the author wrote. It keeps each token as written,
wherever it reads a unit: `u()`, `fmt_unit()` on a string, the `unit` and
`display` of the dictionary and of `dict_local`, the keys and `is:` of `units:`,
and `unit=`. The one exception is the symbol that the `units` package
substitutes, when that is the symbol of the token's own database row with the
same prefix: `metre` is held as `m`, `degC` and `celsius` as `°C`, `lux` as `lx`. Left as
written are `Sv`, `Bq`, `Bd`, `VA`, `Mg`, `ut`, `sievert`, `becquerel`,
`gallon` and `nautical_mile`: the `units` package would store `Sv` as the gray,
`Bq` and `Bd` as the hertz, `VA` as the watt, `Mg` as the tonne and `ut` as the
gram, and a number would print with a unit the author did not write. weft sets
no option of `units` for this, and changes no entry of its database. This
holds in both modes of 4.4.21. In a compound unit every token prints as the
author typed it: `mm/hr` prints "mm/hr", not "mm/h", and `mm/day` and `ha/yr`
print as typed, and so do names: `kilometre/hr` prints "kilometre/hr".

A token that `units` reads as a prefix and another unit, or as another unit, can
only be told from the one the author meant by a list, because the reading is a
valid one. weft cannot detect a misreading in general; it knows a list. Under
`unit_defaults: weft` (4.4.21):

- `pH`, `mph`, `nmi`, `Ma`, `ka` and `gal` are defined by weft's default table,
  so `u(7.2, pH)` is a pH and `u(60, mph)` miles per hour, not a picohenry and
  a milliphot. A project that removes a row with `false` (9.1.7) and defines
  nothing in its place has the token refused;
- `mt` is refused: `units` reads a millitonne, which is a kilogram, and the
  author means a tonne;
- `kt` is refused: `units` reads a knot, and the author may mean a kilotonne.
  The advice names `knot` for the knot and a project unit for the kilotonne, as
  the units database has no `kn`;
- a prefix on the phot or the are, other than `ha`, is refused (`kph`, `Ga`,
  `ca`): the author means "per hour" or "a billion years";
- `grade` is refused: `units` reads an angle, the gon, and the author means a
  grade of something. The advice names a project unit (9.1.7);
- a token that a row in force defines, the project's or the document's, is never
  refused.

Under `unit_defaults: si` none of these is refused and each token means what
`units` reads: `u(7.2, pH)` is 7.2 picohenries. In both modes a prefix on a unit
of weft's default table that has `is:` (`NTU`, `PSU`, `CFU`, `MPN`) is refused:
`kNTU` is not a unit.

`u()` raises a `weft_unit_error`, the `unit` key a `weft_value_error`, and
`read_dict()` and a `units:` key report a problem (4.2.6), for the unit alone or
inside a compound (`mt/d`). The message says what `units` read and what to
write: `mt` is read as a millitonne, so write `t` for a tonne or `Mt` for a
megatonne; `kph` is read as a kilo-phot, so write `km/h`. For a token of the
default table it says that `unit_defaults: si` takes the other reading.

**4.4.21** weft carries a table of default units. It is the YAML file
`inst/weft-units.yml`, whose rows are written as rows of `units:` are (9.1.7)
and may be copied there, and `unit_defaults()` (3.4.10) returns it:

```yaml
units:
  pH:
    is: base
    name: pH
    plural: pH
    before: true
  mph:
    is: 1 mi/h
    name: mile per hour
  nmi:
    is: 1852 m
    name: nautical mile
  Ma:
    is: 1 Myr
    name: million years
    plural: million years
  ka:
    is: 1 kyr
    name: thousand years
    plural: thousand years
  gal:
    is: 1 gallon
    name: gallon
  ppm:
    name: part per million
  ppb:
    name: part per billion
  NTU:
    is: base
    name: nephelometric turbidity unit
  PSU:
    is: base
    name: practical salinity unit
  CFU:
    is: base
    name: colony-forming unit
  MPN:
    is: base
  CFU/100 mL:
    symbol: CFU/100 mL
  MPN/100 mL:
    symbol: MPN/100 mL
```

The first six rows **redefine**: the `units` package already reads the key (as a
prefix and a unit, or as another unit), and the row gives it the meaning a report
intends. `gal` is the US gallon, as `units` has it. The other rows name or
register a unit and change no reading. `MPN` has no name, so a wording class on
it is the error of 4.4.19. The symbol of the two `/100 mL` rows holds a no-break
space between `100` and `mL`, so that the unit stays on one line, and arithmetic
on such a quantity never prints a mangled unit. The table is of what a report is likely to write; a
project adds the rest under `units:`.

`unit_defaults:` sets one of two modes, in `_weft.yml` or a document's `weft:`:
`weft`, the default, and `si`.

| | `weft` | `si` |
|---|---|---|
| the redefining rows | registered, every field applies | not applied at all |
| the other rows, and the shipped names (4.4.17) | apply | apply |
| a token kept as written; twin conversions refused (4.4.14, 4.4.20) | yes | yes |
| the refusals of 4.4.20 | for a token no row in force defines | none |
| a prefix on a unit of the table that has `is:` | refused | refused |
| the project's and the document's `units:` rows | on top | on top |

Under `si`, `u(7.2, pH)` prints "7.2 pH" and is 7.2 picohenries, `u(60, mph)`
prints "60 mph" and is 60 milliphots, and `u(5, ppm)` is still "five parts per
million" under `.word`. A project that wants `pH` alone under `si` copies the
`pH` row into `units:`. A row whose definition is `base` and that redefines a
unit (`pH`) is removed under `si` as the others are.

*When the table is registered.* Loading or attaching weft changes nothing in the
`units` package. The table is registered the first time weft parses or converts
a unit in a session, and at every configuration read (9.1.3), and the database
is then made to hold what the configuration in force wants: the default rows of
its mode, then the project's rows, then the document's. Outside a knit that is
the last configuration read, and before any read it is mode `weft` with no
project rows. Registering is idempotent. weft records each token it installed
and each mapping it removed (the name `gal`, and a token on the misread list
that a project redefines). A read that wants what is already installed does
nothing; a changed definition is removed and installed again; a token no longer
wanted is removed and a removed mapping is restored from the database's own
definition. So two documents knit in one session in different modes each see
their own. A quantity holds only its token: `u(7.2, pH)` made under `weft` and
printed under `si` prints picohenries. Registrations of a unit of weft's own
that redefines nothing (`NTU`, `PSU`, `CFU`, `MPN`, and the tokens of 4.4.7) are
not undone during the session; `false` removes only their names. A read that
fails removes every token installed since it began and returns the session to
mode `weft` with the default rows only; it does not restore an earlier
project's. A unit that a project registers, through `units:` or through its
dictionary (4.4.7), belongs to the project root: it is removed when
another root's configuration is read, and by `units_reset()`.
When the package is unloaded, what it installed is
removed (the base registrations apart) and `gal` is restored. A project unit
defined as a unit with a non-ASCII symbol is refused before anything is
installed, and the units database is left as it was.

*A unit installed by someone else.* When `units` already maps a token that a row
defines, weft accepts it if it reads as the row says: a row with `is:` and a
unit expression converts with a factor of 1, within 1e-9; a `base` row's token
does not convert to the database's reading. Otherwise that row, and only that
row, is disabled: the configuration read gives a warning of class
`weft_unit_warning` that names the token, says that it was installed in the
session and not by weft, and says to remove it with `units::remove_unit()` or to
set `unit_defaults: si`; every other unit works; and using the disabled token is
a `weft_unit_error` with the same words. weft checks the tokens it installed
again at each read. weft never removes what it did not install.

*What a plain `units` user sees.* From weft's first use in a session, the
redefining rows change what the `units` package itself prints: `Myr` prints as
`Ma`, `gallon` as `gal` and `nautical_mile` as `nmi`, and the galileo, whose
symbol is `gal`, cannot be written. This follows from redefining a symbol, and
weft does not work around it.

**4.4.22** A unit that a row writes with `before: true` is written before the
number, joined to it by the space: `u(7.2, pH)` prints "pH 7.2" (the space is
U+00A0). The unit is written before the number only when the unit printed is
that token alone, with a power of 1: in a compound it follows, as for any unit
("0.2 pH/h"). `space: false` removes the space before the symbol: "pH7.2". It governs the
symbol only, for a unit before the number as for one after, and a name keeps its
space (4.4.8). A negative number prints the unit, the space, then the sign: "pH
−0.4".

- A collapse (`.and`, `.or`, `.range`, `trunc`, `glue_vec()`) writes the unit
  once, before the first item printed, in the form 4.4.3 gives: `.range` on
  `u(c(6.5, 8.5), pH)` prints "pH 6.5–8.5", `.and` on `u(c(6.5, 7.2), pH)`
  prints "pH 6.5 and 7.2". `.pairs`, the list classes and a vector that no
  class joins write it before each element.
- `#` carries it: `[# was | # were]{n="dict$ph"}` with a value of 7.2 prints "pH
  7.2 were", and with a value of 1 "pH 1 was". A text class wraps the unit and
  the number together: `.strong` prints `**pH 7.2**`. `.nounit` prints the
  number, "7.2"; `.word` on `u(7, pH)` prints "pH seven". `fmt_unit()` prints
  "pH". `.no` on a unit written before the number is a value error; a spelled
  number keeps the space ("pH seven").
- `.cap` leaves a text whose unit is written before the number as it is.
- The printed record (1.4.11) holds the number. The `weft_text` attribute
  `unit_before` records the side (3.4.4).

**4.4.23** A **ladder** is the set of units the author approves for a quantity. weft
picks from it the unit to print in, by the value. It is written `unit="mm|m|km"`
on a value or a governed span, or as `unit =` of a formatter function: it is
written at the use only, and `display:` in the dictionary takes one unit (4.2.7).
weft never picks a unit the author did not name (4.4.14).

*Writing a ladder.*

- A ladder is one string of rungs separated by `|`. White space around a rung is
  trimmed (`"mm | m | km"` is the same) and white space inside a rung is kept
  (`"CFU/100 mL|CFU/L"`). Each rung is read as `u()` reads a unit, under the
  `unit_defaults` mode and the `units:` rows in force. A ladder of one rung is
  `unit="m"`, unchanged in every respect.
- Where a language has lists the ladder may be one: a character vector for
  `unit =` (`unit = c("mm", "m", "km")`). Each item is one rung and holds no `|`.
  A one-item list is the rung.
- In a pipe-table cell the separator is written `\|` (1.5.13): `` `r x`{unit="mm\|m\|km"} ``.
  weft reads `\|` as `|` in `unit`, in a table or not, and in no other value; a
  `\` elsewhere stays the error of 1.2.3. An unescaped `|` in `unit` in a
  pipe-table cell is a construct error. The `|` of a ladder does not change a
  span's arm count.
- The order is the author's preference, not sorted. Ascending (`mm|m|km`) is the
  usual form, and weft does not require it: `u(0.05, m)` prints "50 mm" under
  `mm|cm|m` and "5 cm" under `cm|mm|m`.
- Every rung is checked against the quantity, whichever rung is picked, so that
  an error does not come and go with the data. A rung that does not parse, is
  refused (4.4.20), does not convert, converts only by inversion, or is a twin of
  the quantity's unit (4.4.14) is a value error that names the rung: `unit="mm|kg"`
  on a length, `unit="m|1/m"`, and `unit="mSv|Sv|Gy"` on a sievert, though `Sv`
  would be picked. An empty rung (`mm||km`, `m|`) and a rung written twice
  (`m|km|m`) are construct errors. Two rungs of one size (`m|metre`, `L|dm^3`,
  `mg/L|g/m^3`; the factor is 1 within 1e-9) are a value error, since the later
  could never be picked.
- A rung with an offset (`degC`, `degF`, against `K`) on a ladder of more than
  one rung is a value error that names the rung, since a ratio window means
  nothing across an offset. `.nounit`, or `unit_form="none"`, with a ladder of
  more than one rung is a value error, since the reader could not tell which
  unit the number is in. So is `.sci` with a ladder of more than one rung.
- Compound units, the default table's units, project units and a unit written
  before the number are rungs like any other. The picked rung prints exactly as
  `unit="<rung>"` would: its symbol as typed (`ug/L`), name, plural, space and
  place (4.4.22).

*Picking the rung.* For each rung the quantity is converted and its numbers are
printed as the use's classes and keys would print them (`digits`, `sigfig`,
`.range`'s shared decimals), before any wording class. With a class that spells
the number (`.word`, `.count`) a rung is eligible only where the number prints
whole, when any rung does; if none does, the error is 1.4.12's, as for any
number that is not whole. What is tested is the
absolute value of each number **as printed**, so that 999.96 m is never printed
"1,000.0 m". A number **fits** a rung when 1 ≤ |n| < 1,000. Missing and
non-finite elements are not tested.

- **One number** takes the first rung, in the ladder's order, where it fits. If
  none fits, a rung that prints the number as 1,000 or more is taken before any
  rung that prints it below 1, because the first keeps every digit and the
  second loses them. Among rungs that print 1,000 or more, the one with the
  smallest number; if there is none, among rungs that print below 1, the one with
  the largest number; ties go to the earlier rung. All of this is measured on the
  number as printed. A lone zero takes the rung of the unit the quantity is held in when that unit
  is on the ladder, else the first rung. With `mm|km`, every length from 1 m
  up to the one that prints "1.0 km" prints in mm: 149 m is "149,000 mm", 940 m is
  "940,000 mm" and 960 m is "1.0 km". A number too small for every rung takes the
  smallest unit and one too large the largest.
- **A vector** takes one rung for all its elements. A rung that prints an element
  that is not zero as zero is passed over when another rung prints none as zero.
  Of the rungs left, it takes the one where the most of its tested numbers fit,
  ties to the earlier rung. If no rung has a fit, the rung its largest absolute
  value takes alone, by the one-number rule. This holds
  under `.and`, `.or`, `.range`, `.pairs`, the list classes, `trunc`, an
  uncollapsed vector, `glue_vec()` and the `#` of a `list` span, and every
  element counts, those `trunc` hides too. A vector with nothing to test (length
  zero, all `NA`) takes the first rung.
- A negative number is judged by its magnitude, and so is a `sign` governor.
- The rung depends only on the value's own numbers, the ladder, the use's
  classes and keys, and the `digits` and `sigfig` settings of the project and the
  document, which decide how the number prints: the same value with the same
  ladder and settings prints in the same rung in every call, chunk and session.
  A value whose numbers change may print in another rung.
- A value may print in one unit alone and in another inside a vector, since the
  vector takes one rung for all its elements. The elements `trunc` hides take
  part in the choice. A descending ladder breaks ties toward the larger unit,
  since ties go to the earlier rung.
- Everything after the pick happens in the picked rung: the printed record, the
  arm chosen (4.4.9), which `plural()` follows as it follows the number as printed
  in the picked rung, `#`, names and plurals (4.4.16), the attributes `unit`,
  `unit_form` and `units` (3.4.4), and the zero rule (4.4.13).
- `last_knit()$constructs` has a column `unit_picked`: for a construct with a
  `unit` key, the rung it printed in, as written in the ladder; `NA` for a
  construct with no `unit`, and for a construct that failed (3.7.5). The ledger
  holds nothing of it.

*Examples.* With `L` for `unit="mm|m|km"`, and `.num`:

| Value | Construct or call | Prints |
|---|---|---|
| 1500 m / 250 m / 0.25 m | `{L}` | "1.5 km" / "250 m" / "250 mm" |
| 1 m / 1000 m | `{L}` | "1 m" / "1 km" |
| 999.96 m / 0.99996 m | `{L}` | "1.0 km" / "1.0 m" |
| 0.0004 m / 5,000,000 m | `{L}` | "0.4 mm" / "5,000 km" |
| 0 m / −1500 m | `{L}` | "0 m" / "−1.5 km" |
| 5 m | `{unit="mm\|km"}`, a gap | "5,000 mm" |
| 150 cm | `{unit="m"}`, a ladder of one | "1.5 m" |
| 0.002 mg/L / 5 mg/L | `{unit="ug/L\|mg/L"}` | "2 ug/L" / "5 mg/L" |
| 2500 m | `{.uname L}` | "2.5 kilometres" |
| 3000 m | `{.word unit="m\|km"}` | "three kilometres" |
| 0 m | `{.no unit="mm\|m"}` | "no metres" |
| 1234.5 m | `{unit="m\|km" digits="2"}` | "1.23 km" |
| 1000 m / 999 m | `[# was \| # were]{n="x" L}` | "1 km was" / "999 m were" |
| 1500 m and 2500 m | `[none \| # was \| # were]{list="x" unit="m\|km"}` | "1.5 and 2.5 km were" |
| 3, 50, 800, 2500 m | `{.and unit="m\|km"}` | "3, 50, 800 and 2,500 m" |
| 500 m and 2000 m | `{.and unit="km\|m"}`, a tie | "0.5 and 2 km" |
| 0.5 m and 2 m | `{.range L}` | "500–2,000 mm" |
| 0.4 km and 2 km | `{.pairs unit="m\|km"}` | "a (400 m) and b (2,000 m)" |

In the source the `|` of a ladder is not escaped outside a pipe-table cell; the
`\|` in the table is this table's own syntax. `u(1500, m)` with `unit =
c("mm", "m", "km")` and with `unit="mm | m | km"` prints "1.5 km". With `u(0.04,
m)` under `unit="m|km"` the result is "0.0 m" and a warned check whose advice is
`unit="mm|m|km"` (4.4.13).

*With other rules.*

- **Back-references.** An `#id` on a construct with a ladder records the quantity
  converted to its picked rung, and a referring span prints what the value
  printed: with no formatter of its own it uses the record (1.7.8), and formatting
  afresh it starts from the quantity in that rung, so `.uname` or `digits` keeps
  the unit. A `unit` on the referring span converts again, by one unit or by a
  ladder that picks afresh: after `` `r x`{#d unit="m|km"} `` with 1500 m,
  `[#]{n="#d"}` prints "1.5 km", `[#]{n="#d" .uname}` "1.5 kilometres" and
  `[#]{n="#d" unit="m"}` "1,500 m". `n="."` inherits the governor as printed, in
  the picked rung. A back-reference formatted again may print outside the
  window: after `` `r y`{#e unit="m|km"} `` with 999.6 m, which prints "999.6 m",
  `[#]{n="#e" digits="0"}` prints "1,000 m". It starts from the quantity in the
  rung already picked and a `unit` of its own is what picks afresh, so an author
  who adds `digits` to a reference adds `unit=` too.
- **`display:`** takes one unit (4.2.7), so a ladder is not picked when the dictionary
  is read. A ladder in it is a `read_dict()` problem.
- **`unit_form`, `.uname`, `.usym`, `.nounit`** act on the picked rung.
  **`unit_defaults: si`** reads the rungs in the mode in force, so `mph` on a
  ladder is a milliphot under `si` and does not convert from km/h.
- **Errors.** An empty or repeated rung is a construct error that names the
  ladder and says to separate units with `|`, as in `unit="mm|m|km"` (rule
  4.4.23). A list item holding `|`, or an `NA` or blank item, is a construct error
  that says a ladder is one string with `|` or a vector of single units. A
  `unit =` that is neither a string nor a character vector says so, naming both
  forms (4.4.14, 4.4.23). A rung
  that fails the checks above, and two rungs of one size, are value errors that
  name the ladder and the rung, in a knit a collected failure (5.3.2).

**4.4.24** When a construct prints a quantity with its unit and the prose
straight after it, after white space, is that unit again, as its symbol or as
its name in the singular or the plural, the knit raises one unit warning (2.6.12)
naming the word ("5 days days"). The symbol is compared as typed; the name is
compared as typed and in lower case. No warning is raised when the symbol is
`a`, `am`, `as`, `at` or `in`. The same holds when an arm types the unit after
`#`. Nothing is removed, and the text printed is unchanged.

### 4.5 Decision pointers

**4.5.1** `decision:` points at wherever the project records decisions. It is
resolved by a configured resolver (§9.1): a GitHub issue number in the
repository's remote (the default), a file glob (`decisions/{id}-*.md`), or a
project function.

**4.5.2** Pointers are checked only in `verify()` (§8). One that does not
resolve fails it (tier 1).

**4.5.3** The setting `decisions` (9.1.8) chooses one of three routes. An
internal function, `check_decisions()`, takes a dictionary and returns one row
for each entry that has a `decision`, in file order, with the columns `file`,
`line`, `key`, `decision` (the pointer as the dictionary stores it, a string),
`resolved` (`TRUE`, `FALSE` or `NA`) and `detail`. Each distinct pointer is
checked once per call, and rows that share one share the result.

- **GitHub.** The pointer is an issue number, and an issue or a pull request of
  that number in the repository of `origin` (or the repository `github:<owner>/
  <repo>` names) resolves it, open or closed. A pointer that is not a whole
  number from 1 does not resolve, and no request is made. A pointer written
  `#12` is read as 12. One written with a leading zero, in hex or in octal, or
  with more than ten digits, or as a number above 2,147,483,647 (the most an
  issue number can be), is kept as it was written and does not resolve; its
  detail says why. The repository is checked before
  any issue. The `origin` is used only when the top level of its git repository
  is the project root or a folder inside it. `GITHUB_PAT`, else `GITHUB_TOKEN`,
  is sent as the token when set, and is never printed. A repository's remote may
  be an `https` URL, with or without credentials, an `ssh` URL, with or without
  a port, or the `git@` form, on `github.com` or `ssh.github.com` in any letter
  case; its repository name holds letters, digits, `.`, `_` and `-` only.
  Anything else is "not on github.com". The request is made with the `curl`
  package, a suggested one; without it every GitHub row could not be checked.
- **File glob.** The pattern holds `{id}`, which is replaced by the pointer, and
  is relative to the project root. A glob is a glob and nothing more:
  `decisions/{id}*.md` matches `31-x.md` for the pointer 3, which is why the
  pattern is written `{id}-*.md`. The project root is never read as part of the
  pattern, so a root whose path holds `[` or `*` resolves as any other. A
  pointer that holds a pattern character (`* ? [ ] / \`) does not resolve, and a
  match that is a folder, a link to nowhere or a file outside the project root
  does not count.
- **Function.** A function of the pointer, written `pkg::fun`, or a bare name in
  the global environment. It returns `TRUE` (resolves), `FALSE` (does not) or
  `NA` (could not check). A function that cannot be found is a
  `weft_config_error`, unless the dictionary holds no pointer. A function that
  fails, or returns anything else, is "could not check".

**4.5.4** A pointer resolves, does not resolve, or could not be checked. Does not
resolve means the record is missing. Could not be checked is a result of its
own, and is never reported as does not resolve: there is no network, no token
for a private repository, GitHub refused or limited the request, the repository
has issues switched off (an answer of 410, as in a fork whose `origin` is the
author's own; set `github:<owner>/<repo>`), the repository is not on
github.com, a `fetch` threw, or a function returned `NA` or failed. After the
first refusal of GitHub no further request is made for the call, and the later
rows are could not check. Each row of the result says which it is, and a
could-not-check detail begins `could not check: ` and is one line. Nothing is
cached between calls.

### 4.6 The pipeline

```r
# _targets.R
list(
  tar_dict("dict.yml"),
  tar_dict_deps(list(
    tar_target(era_fit, fit_eras(obs, split = dict$era_split))
  ))
)
```

**4.6.1** `tar_dict()` returns a file target for the YAML (`dict_file`), a
target `dict_values` that reads the file once per make, and one target per key
(`dict_<key>`), holding the value only. Each target's command is wrapped in
`weft::dict_unmark()`, which strips the marker of the attached dictionary from the value.
The function is exported, marked internal, because the generated commands name it; it is
not for direct use.

**4.6.2** `tar_dict_deps()` walks each target's command, and the functions it
calls, for `dict$key` and `dict[["key"]]`, and sets the per-key targets as
that target's dependencies explicitly. A literal `"dict"` given to `get()`,
`get0()`, `mget()` or `exists()` is a read of every key. It follows the
functions bound in a closure's own environment, and for a call `g()` the
`g.<class>` functions in the pipeline's environment.

**4.6.3** A changed value re-runs exactly the targets that read it. A changed
definition, a new key or a reorder re-runs no consumer.

**4.6.4** An unknown key is a `weft_pipeline_error` when the pipeline is defined,
before anything runs. The error names the nearest key as 4.1.2 does.

**4.6.5** A `.qmd` rendered by `tar_quarto()`, and a source rendered by
`tar_render()`, is scanned for `dict$key` the same way: chunk code, inline R and
construct keys. `tar_quarto_rep()` and `tar_render_rep()` targets are report
targets too. A report's sources are followed through knitr `child=` files, Quarto
includes and any source that `tarchetypes` lists, whatever its extension, to any
depth. A Quarto include whose path starts with `/` is resolved against the Quarto
project root, the folder that holds `_quarto.yml`, else the document's own
folder; a quoted include path may hold spaces. A report with a `child=` that is
computed rather than a literal, or a child or include that does not resolve to a
file, depends on every key (4.6.8). The scan prints nothing to the console.

**4.6.6** Dynamic access (`dict[[k]]`) and a bare `dict` depend on the whole
dictionary. With no keys, a read of the whole dictionary is allowed.

**4.6.7** `tar_dict()` attaches the dictionary as `dict` on the search path. A
`dict` object in the pipeline's environment is a `weft_pipeline_error`, because
`targets` would track it. So is a second `tar_dict()` call, or a target of the
author's named `dict_file`, `dict_values` or `dict_<key>`: a pipeline has one
dictionary. A
`crew` worker does not see the attached `dict`.

**4.6.8** The attached `dict` checks its own dependency. While a target runs, a
read of key `k` requires `dict_k` among that target's dependencies, and a read of
the whole dictionary requires every `dict_<key>`. Otherwise it is a
`weft_pipeline_error` naming the target and the key, and saying to pass the
target through `tar_dict_deps()`. A read outside a running target checks
nothing. The check guards only the attached `dict`: a value that a target
returns never carries the guard's marker, so a copy of `dict` that one target
stores reads freely in another, and the message names only what was read. A
target left out of `tar_dict_deps()`, or a
read the walker cannot see, stops the first make and never gives a stale number.
A report is not protected by this check, because it knits against its own
dictionary (and `tar_quarto()` renders in another process): it is protected by
the scan (4.6.5), and what the scan cannot follow makes the report depend on the
whole dictionary.

### 4.7 Generated from the dictionary

**4.7.1** `dict_glossary(dict = NULL, values = TRUE, sort = TRUE)` returns the
glossary as Pandoc markdown, a string that knitr prints as markdown with no
`results: asis`, so a chunk that calls it is the glossary. It writes nothing
(P10). `dict` is a dictionary, or `NULL`: in a knit, the knit's project
dictionary; outside a knit, `dict.yml` at the project root, with the root's
`_weft.yml` in force, so that the preview at the console prints as the knit
does. A `_weft.yml` that cannot be read leaves the preview on the defaults, so
that a bad file does not stop it. No dictionary to read, and a `dict` that is not one, are errors of class
`weft_tool_error`, and so is a `values` or `sort` that is not `TRUE` or `FALSE`.
A `dict_local` is accepted and treated alike; `why` is never shown (4.3.3).

An entry is a Pandoc definition: a heading line, then `:   ` and the
definition.

```
core length (0.5 m)
:   Length of each sediment core.
```

- The heading is the entry's `term`, as written (markdown), else the key in
  code (`` `salinity_res` ``). When `values` is `TRUE` and the type is `number`,
  `quantity`, `year`, `date` or `string`, a space and the value in parentheses
  follow. `labels` and `breaks` show no value.
- The value is the value as stipulated, printed with the configuration in force:
  the marks, the minus sign, `thousands_from`, the unit form and the `units:`
  table. It keeps the decimals it was written with: `value: 0.50` prints
  "0.50". The decimals a value was written with are held in the attribute
  `decimals` of the dictionary. A quantity that `display:` converts prints as `fmt_num()` prints it, except
  that an entry whose `display` unit prints its value as zero is printed in the
  entry's own `unit`, with no warning.
  A date prints through `fmt_date()` and a string as written.
- The definition and a string value have each run of white space, newlines
  included, made one space; the markdown is printed as written. A definition
  that holds a blank line keeps its paragraphs, indented as Pandoc needs.
- Entries are in alphabetical order of the term, or of the key without its
  backticks, ignoring case, ties by key; `sort = FALSE` keeps file order.
- The string starts and ends with a blank line, so that the text above and
  below the chunk stays out of the list: the paragraph after the chunk is its own
  paragraph. An empty dictionary gives `""`.

**4.7.2** `dict_vale(dict = NULL, path = "styles/Weft/Terms.yml", level =
"warning")` writes one Vale `substitution` rule from the `avoid` fields (4.7.4).
Each avoided spelling is a key, escaped as a regular expression, and its value
is the entry's canonical spelling; the keys are written longest first, then in
radix order, and the rule matches case-sensitively, so an author lists a case
variant as a spelling of its own. `dict` is as for `dict_glossary()`, and a
dictionary with problems raises its `weft_dict_error` and writes nothing. `path`
is relative to the project root, and one that climbs out of it is a
`weft_tool_error` (an absolute `path` outside the project is allowed); it ends `.yml` and has a style folder above the
file (`styles/Weft/Terms.yml`); `level` is `suggestion`, `warning` or `error`.
Either wrong is a `weft_tool_error`. The first lines of the file say that
`dict_vale()` generated it from the dictionary file and that it is not to be
edited.

`dict_vale()` is an explicit call that writes a file, and it says what it will
write first. It replaces only a file that it wrote, found by its first line: any
other file at `path` is a `weft_tool_error` and nothing is written. A file that
is already as it would write it is left alone, and the call says so. A path or a
folder on the way that is a link, a target that is a folder, and a write that
fails are each a `weft_tool_error` naming the path; "Wrote:" is printed only for
a file that was written. Once the rule is in place it says what `.vale.ini` at
the root must hold for Vale to use it: `StylesPath` set to the style's folder
and the style listed by its whole name in `BasedOnStyles`. weft never writes
`.vale.ini`.

A dictionary that has no `avoid` removes a file that `dict_vale()` wrote, and
says so first, when the dictionary is the project's own (`dict = NULL`). Given
any other dictionary with no `avoid`, a `dict_local` or one read from another
file, `dict_vale()` writes nothing and removes nothing.

**4.7.3** `term:` is optional on an entry of any type, in `dict.yml` and in
`dict_local`: the words a reader knows the entry by. It is a string that is not
blank, with surrounding white space trimmed and the white space inside it kept;
`*emph* term` is allowed. A `term` that holds a line break,
or starts with a markdown block marker (`#`, `>`, `-`, `*`, `:`, or a number
and a point), is a problem of the dictionary (4.2.6): `read_dict()` reports it.
The glossary heads the entry with it, and it is the canonical spelling that
`dict_vale()` keeps.

**4.7.4** `avoid:` is optional, in `dict.yml` only: one string, or a non-empty
list of strings, none blank, each trimmed. They are spellings to replace by the
entry's **canonical spelling**: its `term`, or, for a `string` entry with no
`term`, its value, with white space made one space. `avoid` on an entry that is
neither a `string` nor has a `term` is a problem, and so is `avoid` in
`dict_local` (a chapter's own entries write no Vale rule). Each of these is a
problem of the dictionary (4.2.6), reported by `read_dict()`; comparisons are
case-sensitive:

- a spelling that is the entry's own canonical spelling, or is listed twice in
  one entry;
- a spelling that another entry's `avoid` also lists (reported on the later
  entry);
- a spelling that is found, as whole words, inside any entry's canonical
  spelling, its own included, because Vale would flag the right spelling;
- a spelling that starts or ends with a character that is not a letter or a
  digit (`approx.`), because Vale could never match it.

The checks across entries leave out an entry whose own `term` or `avoid` had a
problem, so one mistake is reported once. Canonical spellings need not be
unique.

---

## 5. Lints

### 5.1 General

**5.1.1** Each lint is a rule with a stable id, run by `lints()`, which
returns a data frame of findings, and is an entry in the gate (§6) or in
`verify()` (§8). A finding has the file, the line and column where its text
starts, the last line it covers, the rule id, the tier, the number of the
rule in this chapter, the context it was found in (prose, caption, front
matter, `weft_str()` string, phrase, chunk or project), the text the gate
counts (6.2.3), a message that ends with the rule number, and a hint. Rows
that agree in file, line, column, rule, text and message are one.
`lint_rules()` lists the ids, rule numbers, tiers and scopes (`file` or
`project`). The ids are given in this chapter, and the rule numbers in the
tables of 5.3.3 and 5.8 are the ones `lint_rules()` cites.

**5.1.2** Every lint and check declares a tier.

| Tier | Mechanism | Behaviour |
|---|---|---|
| 1 | hard rule, decidable from the source or from one evaluation | fails: the commit, the render or `verify()`, as stated |
| 2 | heuristic trigger on newly added material | listed by `changes()` and `verify(since = )` (7.3.5, 8.2.2); blocks nothing |
| 3 | human read | a ranked worklist; never adjudicated |

**5.1.3** The lints read the prose of each source file, the captions written
in chunk options, the literal strings passed to `weft_str()`, and the
front-matter fields of 1.10.7 in every metadata block (2.10.6). A file that is
not UTF-8 gives one finding, `read` (tier 1), and no other.

**5.1.4** Constructs come from the scanner (2.10.2), prose from the package's
own reader (2.10.3). What a lint skips is decided by what the source is: code,
math, link target, raw block. There are two exceptions. A citation bracket is
recognised by pattern (2.10.4), and the pattern leaves a bracket that is
followed by an attribute block to be a span, whose text is prose. The numeral
rule reads math (5.2.6). Code rules read executed R chunks only: a chunk with
`eval: false` or another engine gives nothing. A pipe (`|>` or `%>%`) is read
as the call it makes, so `n |> claim(. > 10)` is `claim(n, . > 10)`.

**5.1.5** Tier 2 scopes to newly added material, not to the corpus. Newly
added material is the lines git's diff shows as added since the comparison
point (7.3.2).

**5.1.6** The phrases of a `lookup()` or `brk()` written in a document's chunk
are read for numerals (§5.2): a numeral in a phrase usually repeats a bound
that the same call computes with. Their claim words are not listed, because
the call that chooses the phrase is the guard (5.5.2). Phrases held in the
dictionary or in a package's R code are not read.

**5.1.7** `lints(path, files, rules, tier, reader)`. `path` is a file or a
folder; the project root is found from it, and a project need not be set up.
`files` limits the findings reported to those documents. `rules` names rules
by id, and `tier` is 1, 2 or both. When `tier` is not given, a rule named in
`rules` runs whatever its tier, and with no `rules` the tier is 1: tier 2 is
listed over added material by `changes()` (5.1.5), and over a whole file only
when asked for. When `tier` is given and a named rule lies outside it, a note
says so. `reader` is `"weft"`, the package's own reader and the default, or
`"pandoc"` (2.10.3). An unknown rule id is an error that offers the nearest.

**5.1.8** Every `.qmd`, `.Rmd` and `.rmd` under the root is read, whatever
`files` says, because ids, anchors, includes and child documents are
project-wide. Folders whose name starts with `.`, and `renv`, are skipped.
Folders whose name starts with `_` (an include folder, `_partials`) are read
for anchors and for what they include, and are not linted; `_site`, `_book`,
`_freeze` and `_extensions` are not read. A `.md` file is read for anchors
only. Each document's settings are `_weft.yml` merged with its own `weft:`
key; the lints read the YAML and install no units.

### 5.2 Numerals — tier 1

**5.2.1** Every numeral in prose is a value, or sits inside a `cite` span or a
`.weft-literal` span or block. The rule is `numeral`. It reads the body, the
captions, the fields of 1.10.7, the strings of `weft_str()` and the phrases
of 5.1.6, and reports each numeral with its position.

**5.2.2** A numeral is judged at character level, word by word. A word whose
first letter-or-digit is a digit is a numeral, whatever follows it: "12",
"−0.5", "45%", "11-year", "3rd", "1990s", "10x". A word whose first
letter-or-digit is a letter is a name, whatever digits it contains: "CO2",
"PM2.5". A word ends at white space and at `=`, `<`, `>`, `≤`, `≥`, `≈` and
`≠`, so `p<0.05` and `n=12` hold the typed numerals `0.05` and `12`.

**5.2.3** The rule is judged against `HEAD` (6.2.2): a commit fails when it
adds a typed numeral. The numerals a document held when weft was adopted are
tolerated because they are in `HEAD`, and nothing lists them. `verify()`
reports how many remain (8.1.2), and fails on any once the rule is made
strict (8.1.3).

**5.2.4** Two exemptions are configurable (§9.1). A numeral that follows a
label word is exempt. The label words are the author's, set in `_weft.yml` or
a document's front matter, and the list starts empty. A label word is matched
as typed, with punctuation around it ignored (`(Site 3)`, `Site: 3`).
`label_seed()` proposes candidates (9.5.5). A numeral after a word Quarto can
cross-reference (Figure, Fig., Table, Section, Chapter, Equation, Appendix,
in any letter case and in the plural) fails like any other typed numeral, and
its message says to use a cross-reference. The author may still add such a
word to the list, for a document that cites another document's tables. A
four-digit year is not exempt by default: a year in prose is often a
stipulation that belongs in the dictionary. `numeral_years: true` exempts a
four-digit year from 1000 to 2999, a year range (`2016-17`, `2016-2017`), a
decade (`2010s`) and a possessive year (`2019's`).

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
running R. The gate fails on one, and a render stops at one (2.6.5). The rule
is `construct`; it gives one finding per line of the scanner's message, in
every context, and cites the rule number the message names, else 5.3.1.
A line inside a span that Pandoc cuts a paragraph at is a separate rule,
`block-start` (2.10.5).

- more than one of `n`, `if`, `sign`, `list`, `cite` in one block; any of
  them on a value (1.1.5, 1.3.3)
- a code span that opens with `r` and a line break (5.3.4)
- a single-quoted value, or a `"` or `\` inside a value (1.2.3, 1.2.9), but
  for `\|` in `unit`
- a key written twice in one block, in any letter case (1.2.10)
- an `#id` on a text span (1.1.9)
- an inline expression, or the value of `n`, `if`, `sign` or `list`, that
  does not parse as R (5.3.5)
- `claim()` with no check (3.1.10)
- a bare-form `cite` value that is not keys only; a key outside Pandoc's key
  grammar; a formatter class on a `cite` span; an `#id` on a `cite` span
  (1.8.4, 1.8.5, 1.8.7, 1.7.5)
- two classes from one at-most-one group; `digits` with `sigfig` (1.4.2, 1.4.7)
- `.ul`, `.ol` or `.dl` on a value that is not alone in its paragraph (1.4.6)
- a wrong arm count for the key, or for the document's language (1.5.2, 1.6.4)
- an `n` or `list` span with more than one arm under a `lang` that is not
  shipped (1.6.5)
- a wording class, `.uname`, a collapse class that prints a word, `.a` or a
  phrase function that prints words, under a `lang` whose words are not shipped
  (1.6.8)
- two unit classes; `.usym` with `.no`, `.word` or `.count` (1.4.2)
- a unit class on an `if` or `cite` span (1.4.19)
- a formatter on an `if` span (1.5.7); a `level` key on any span (1.5.5)
- a `list` span with `#` in its zero arm, or with the value `.` (1.5.19); a
  `list` span with an `#id` (1.7.5); a `list` span with `.ul`, `.ol` or `.dl`
  (1.5.19)
- `none` that is empty, or on a value with no collapse class, on a span or on
  a `cite` span (1.4.14); `none` with `.range` (1.4.14)
- a wording class with `.pct` or `.sci` (1.4.2)
- a weft key on a link (`[a](u){if="x"}`), or an attribute block on inline R
  inside a link target
- an unescaped arm separator in a pipe-table cell (1.5.13)
- an empty or repeated rung in `unit`; an unescaped `|` in `unit` in a pipe-table
  cell (1.5.13, 4.4.23)
- `n="."` outside an `n`, `list` or `sign` span (1.7.2)
- a duplicate id; a back-reference to an id that is unknown or defined later
  (1.7.5, 1.7.10)
- a `.weft-literal` with no `why` (1.8.10)
- a caption or a front-matter field that contains a construct and is not a
  YAML block scalar (1.10.3, 1.10.7)
- a construct in the caption of a chunk with `cache: true`, `eval: false` or
  an engine other than R (2.3.5)
- a construct in `title` in a book or a website (1.10.11)
- an attribute block inside math (5.2.6)

**5.3.2** Ten errors need the value and are found only at knit time: a
governor of the wrong type (1.5.1, 1.5.11), `.a` on text that is not a number
(1.4.5), `.range` on a value that is not of length 2 or with its first end above its
second, a wording class on a
number that is not whole and non-negative (1.4.12), a `sign` governor that
prints as a bound (1.5.17), a name that may print for a unit that has none
(4.4.19), the form `symbol` with a number a wording class has spelled (4.4.15),
a unit class on a value with no unit (1.4.19), a unit with no symbol that
would print by its name under a `lang` whose words are not shipped (1.6.8), and
a unit or a rung that the quantity cannot be converted to, or two rungs of the
same size (4.4.14, 4.4.23). They
are not construct errors, and none of them
stops the render. Each is a collected failure with a marker (2.6.8, 2.6.9),
and the render fails at the end with all of them listed, as it does for
failed checks. A missing value is collected the same way (1.3.4).

**5.3.3** Three tier-2 warnings sit beside them, each its own rule, all
numbered 5.3.3.

- `lone-bar`: a bracketed span with a single `|` (1.5.12) between its words
  and no governor or marker key is listed as a probable construct. A span in
  a pipe-table row, an escaped `\|` and a `|` inside nested code or brackets
  do not count.
- `if-zero`: an `if` whose condition compares a value with zero (`>`, `<`,
  `>=`, `<=`, `==`, `!=`) is listed as probably wanting `sign`.
- `name`: a class or key on a weft construct that is not weft's (1.2.5), not
  one of Pandoc's (`.smallcaps`, `.underline`, `.mark`, `custom-style`), and
  not listed in the configuration as a name the project expects (9.1.2) is
  listed. So is a formatter class or a renderer key on a bracket with no
  governor or marker key (1.1.9). So is a key or a class within one edit of a
  weft name on any bracketed span or inline code, construct or not
  (`[add more]{iff="n_gap > 10"}`): a misspelt key leaves an ordinary span,
  and this is the only place it shows. An edit is an insertion, a deletion, a
  substitution or the swap of two neighbours (`.nmu`). A name of fewer than
  three characters is compared only for letter case. The report gives the
  nearest weft name when one is close, including a class that differs from
  one only in letter case (`.Num`, 1.2.10). A key that differs from a weft key
  only in letter case is that key (1.2.10). Two weft names one edit apart are
  not listed. On a code span, a class that is a Pandoc highlighting language
  (the fixed list of `pandoc --list-highlight-languages`: `.cpp`, `.r`,
  `.python`) is never listed.

**5.3.4** knitr reads inline R only when `r` is followed by a space on the
same line. A code span that opens with `r` and then a line break is left by
knitr as literal code, and prints its expression. It is a construct error,
with or without an attribute block, and the `weft-check` filter fails on a
code span whose text begins `r ` (2.5.3).

**5.3.5** An inline expression, or the value of `n`, `if`, `sign` or `list`
other than a back-reference (1.7.6), that does not parse as R is a construct
error found from the source. knitr stops on such an expression before any weft
hook runs.

### 5.4 Marker spans and citations — tier 1

**5.4.1** Every key of a `cite` span follows Pandoc's key grammar and resolves
in the bibliography. This is checked statically (`cite-key`), and again at
knit time.

**5.4.2** The block that holds a `cite` span in the bare form cites each of
its keys, as `@key`, `-@key` or `@{key}`. The block is the innermost one as
the package's reader finds it (2.10.3): a paragraph, a list item, a table
cell, a footnote or a caption. A span in the citation form meets this by what
it emits. This check is static only (`cite-bare`).

**5.4.3** Every citation key in the document resolves in the bibliography
(`citation-key`). A reference whose prefix is a Quarto cross-reference type,
in any letter case (`@fig-x`, `@Fig-x`, `@Tbl-x`), is a cross-reference
(5.7.1), not a citation, and `a@b.org` is neither. A bibliography file that is
named and missing is one finding, at the line that names it.

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

**5.5.1** Quantifiers, extrema and direction words ("all", "none", "only",
"largest", "rose", "significantly") are listed in two cases: a claim word in
the same sentence as a value, and a claim word in a newly added sentence with
no value at all. The rule is `claim-word`, and it gives one finding per
sentence, naming its claim words. It reads prose, captions, front matter and
`weft_str()` strings, and not phrases (5.1.6). A sentence has a value when a
value, a bare value, an `n`, a `sign` or a `list` span starts inside it; an
`if` guard or a `cite` span is not a value. Number words ("one", "two") and
the bare comparatives ("more", "less", "above", "below") are not claim words:
on a real manuscript they flagged most sentences, and a flag that most prose
carries tells an author nothing.

**5.5.2** A claim word inside an `if` or a `sign` span is guarded, and is not
listed. An `n` span chooses a plural form and checks nothing about the words,
so a claim word inside one is listed as it would be outside.

**5.5.3** The list is capped. When a file has more added sentences with claim
words than `claim_cap` (20 unless set), `changes()` gives one count instead of
the sentences.

**5.5.4** The default lexicon is 69 English words in three lists, `quantifier`,
`extremum` and `direction`, shipped as `inst/weft-claim-words.yml`. It is used
when the document's `lang` is missing or starts `en`, and under any other
`lang` there are no claim words. `claim_words` in the configuration adds
words (`add`) and drops them (`drop`), so a project can restore a word the
default leaves out.

### 5.6 Value expressions

**5.6.1** A **literal value** is a value whose expression is made only of
constants and operators: `` `r 10` ``, `` `r 2 * 5` ``. It renders. A commit
that adds one fails (6.2.2, tier 1, `literal-value`). The expression of an
`n`, `sign` or `list` governor is read the same way, so `{n="3"}` is a
literal value, and a back-reference is not. A number that cannot be computed
is written as a `.weft-literal` with its `why` (1.8.9).

**5.6.2** A numeric constant inside a computation (`x * 100`) is listed
(tier 2, `value-constant`). `0` and `1` are not listed, and neither is a later
argument of a formatting call named in 5.6.4 (`round(x, 2)`).

**5.6.3** Constants inside the check arguments of a `claim()` call are exempt.

**5.6.4** A value whose outermost call is `round()`, `signif()`, `format()`,
`formatC()`, `prettyNum()` or `sprintf()` is listed (tier 2, `value-format`),
looking through parentheses, `base::`, a pipe and the first argument of
`claim()`. It formats outside the stages, so it has no printed record, and
`round()` drops trailing zeros ("1.50" prints "1.5").

### 5.7 Cross-references

**5.7.1** Book-wide, because ids share one namespace. Tier 1:

- every reference resolves to an anchor (`xref`); no anchor is defined twice
  (`anchor-twice`, one finding for each later definition, naming the first)
- no governed span's text matches a reference-link label defined in the same
  document (`[foo]: url`), which Pandoc would read as a link (`ref-label`);
  Pandoc resolves a label within one document, so this check is per document

An anchor is any `{#id}` outside a construct, a chunk label that starts with a
cross-reference prefix, and, in an `.Rmd`, a chunk label as `fig:` and `tab:`.
Anchors are read from every document of the project, including those in `_`
folders (5.1.8) and `.md` files. A heading's automatic id serves `#x` links
only. A reference is `@prefix-x` (the prefix in any letter case), `\@ref(x)`
or a link to `#x` or `file#x`.

**5.7.2** Tier 2: a figure, table or equation anchor that is defined and never
referenced (`anchor-unused`); and a cross-reference written inside a code
span, which prints as literal text (`xref-code`), except inside an HTML
comment.

### 5.8 Hygiene

| # | Id | Rule | Tier |
|---|---|---|---|
| 1 | `section-anchor`, `chunk-label` | every section has an explicit anchor, and every chunk a label | 1 |
| 2 | `tar-name` | every `tar_read()` and `tar_load()` names a target in the pipeline's store | 1 |
| 3 | `dict-assign` | chunk code does not assign to `dict` or redefine one of its keys | 1 |
| 4 | `file-link` | internal file links resolve | 1 |
| 5 | `above-setup` | in a document activated from a setup chunk, no construct sits above that chunk | 1 |
| 6 | `dict-key` | every `dict$key` and `dict_local$key` read names a key that exists, under the rules of §4.3 | 1 |
| 7 | `tar-cache` | a chunk that reads a pipeline target (`tar_read()`, `tar_load()`) does not have `cache: true` | 1 |
| 8 | `config-place` | no `weft:` key in `_quarto.yml` or `_metadata.yml` (9.1.1); where `_weft.yml` exists, no `draft` and no part switched off in a document's front matter (9.1.4) | 1 |
| 9 | `engine` | a `.qmd` that holds a construct, and is rendered on its own rather than included or knit as a child, has `engine: knitr` in its own front matter (9.2.8) | 1 |

- Rule 1: `section-anchor` skips a heading inside a callout or a
  `.panel-tabset` div, which is not a section, and reads a setext underline
  only under a one-line paragraph. `chunk-label` reads an executed chunk of
  any engine, and not one with `eval: false`.
- Rule 2: target names come from the store's metadata (the literal `store=`,
  else `_targets.yaml`, else `_targets`), so no `_targets.R` and no project
  code runs. A target defined and never built is reported until it is built.
  With no store, or without `targets` installed, there is a note and no
  finding. A name that is not a literal is not guessed.
- Rule 4: a link or image target with no scheme, read from the document's
  folder, or from the root when it starts with `/`. A link to a rendered
  output (`other.html`) passes when its source document (`other.qmd`,
  `.Rmd` or `.md`) exists beside it; a PDF the render produces is not
  checked.
- Rule 8: `config-place` reports a `weft:` key in the project files only when
  the whole project is linted.
- Rules 2, 3, 6 and 7 read executed R chunks, inline expressions and governor
  expressions, and read a piped call as the call it makes (5.1.4).

### 5.9 Figures and tables

**5.9.1** Tier 1: every figure has a label, a caption and alt text (`figure`);
every table has a caption (`table-caption`). A figure or table is recognised
by its source, not by running code: a chunk labelled `fig-` or `tbl-` or given
a caption option, an image alone in its paragraph, a pipe or grid table, or a
`#fig-` or `#tbl-` div, which supplies the label, caption and alt text of what
it holds. A table's caption is a `:` line or a `Table:` line (also `table:`),
before or after it. A chunk that plots with neither label nor caption is not
seen. One finding is made for each missing part.

**5.9.2** A caption is prose, whether it is written in a chunk option or in a
figure or table div. Every prose lint applies to it.

**5.9.3** The package does not write alt text, and does not judge whether alt
text describes the figure.

### 5.10 Sentence starts — tier 2

**5.10.1** At knit time the `text` hook lists every value, bare or not, and
every span whose printed text opens a sentence with a digit or a lowercase
letter. A project can configure the list to fail the render. This is a
knit-time list and the one exception to 5.1.5: it covers every value in the
document, not only added material, because whether a value opens a sentence
with a digit depends on what it prints.

---

## 6. The commit gate

### 6.1 The hook

**6.1.1** The gate is a `commit-msg` hook, installed by `use_hooks()`.

**6.1.2** It compares each staged file that weft reads with its version in
`HEAD`. A new file has an empty `HEAD` version, and a deleted file an empty
staged one. The files weft reads are the documents and the project files the
lints read (5.4.4, §5.8).

**6.1.3** It reads the staged version from the index (`git show :<file>`),
not the worktree. It reads the commit message's trailers with
`git interpret-trailers --parse`.

**6.1.4** It runs static checks only. It does not knit, and it does not use
the network.

**6.1.5** `use_hooks()` records the paths of R and of Pandoc, and the hook
uses those. It calls the Pandoc binary itself, not `quarto pandoc`.

**6.1.6** Each file's scan is cached under `.git/`, keyed on the file's git
blob hash. The `HEAD` version of a file, and what the hook needs from the
files not staged (the anchors and reference labels of 5.7, the citation keys
of 5.4), come from that cache when they are in it.

**6.1.7** The hook prints one report, listing every reason the commit failed,
each with its file and line. It prints how long it took.

**6.1.8** `--no-verify` skips the hook. Draft mode does not affect it
(9.4.3).

### 6.2 What stops a commit

**6.2.1** A commit fails on three things (tier 1):

1. a construct error (§5.3) in a staged file, whenever it is present
2. a finding the commit adds (6.2.2)
3. constructs removed without saying so (§6.3)

**6.2.2** Every other tier-1 static rule is judged against `HEAD`: typed
numerals (5.2), literal values (5.6.1), marker spans and citations (5.4),
cross-references (5.7), hygiene (5.8), and figures and tables (5.9). The
commit fails when the staged files hold more instances of a finding than
their `HEAD` versions did.

**6.2.3** Instances are counted by rule and by the finding's text (the
numeral, the expression, the key, the anchor), summed over all the files in
the commit. Moving a paragraph from one file to another adds nothing.

**6.2.4** The rules that read across files (5.4.1, 5.4.3, 5.7.1) count over
the whole project, with the files not staged read from the cache (6.1.6).
Removing an anchor that another chapter cites adds a finding in that chapter.

**6.2.5** What a document already held when weft was adopted is tolerated,
because it is in `HEAD`. Nothing lists it. `verify()` reports how many
remain (8.1.2).

**6.2.6** One limit is accepted. A finding removed and the same text added
elsewhere in one commit nets to zero.

**6.2.7** The hook judges no tier-2 rule (5.1.2).

### 6.3 Constructs removed

**6.3.1** The hook counts three things in every staged file and in its
`HEAD` version: inline R values, with or without an attribute block; weft
spans (1.1.5); and `claim()` calls anywhere in the file, chunk code
included. A value whose expression holds a `claim()` counts once as a value
and once as a call.

**6.3.2** When the total over the commit is lower than the total in `HEAD`
by N, the commit message must carry the trailer `Weft-Removed: N`. Without
it, or with a different number, the commit fails.

**6.3.3** There is one total. Turning a value into a span, renaming a
variable in forty expressions, or changing a bound changes no count, and
costs nothing. A changed expression is not a removal.

**6.3.4** The failure lists what is gone, each with its text and its line in
`HEAD`, and prints the exact trailer line to add. What is gone is every
construct whose text occurs fewer times in the commit than in `HEAD`, so the
list is longer than N when the commit also adds constructs.

```
commit-msg: 3 weft constructs removed, and the message does not say so

  14-percentile-bands.qmd, as in HEAD
      412  `r band_cut$lower`
      413  `r band_cut$upper`
      431  claim(shift$n_down, . >= 10)

  If the removal is intended, add this line at the end of the commit
  message, after a blank line:

      Weft-Removed: 3

commit-msg: 0.8 s
```

**6.3.5** A `Weft-Removed` trailer on a commit that removes nothing is
ignored.

**6.3.6** Two limits are accepted. A removal and an unrelated addition in one
commit net out. The trailer is lost when commits are squashed.

---

## 7. Ledger and conditions

### 7.1 The ledger

**7.1.1** The `text` hook records every value, governed span and `cite` span
as it renders: its key (7.1.4), its expression, its printed text with its
relation, its raw value, the unit the raw value is in, its file and section, its sentence as printed, the
dictionary entries its expression names, and for a governed span the arm
chosen, recorded by its role (`one`, `other`, `true`, `always` and so on). The
raw value is the expression's own, before any formatter or unit conversion.
Its unit is written as `units::deparse_unit()` writes it, and is `null` for a
plain number. A
construct that failed in draft mode is recorded with its failure kind, and has
no printed text, arm, raw value or unit. The sentence is found by sentence-boundary
rules for the document's language: ICU's, through `stringi` (an `Imports`
package), for the document's `lang` (`en` when unset). They are applied to the
block of markdown that holds the construct's text, after what is not prose is
masked: code, maths, link targets, citations and cross-references, footnotes,
attribute blocks and raw HTML. A boundary is dropped before a lower-case letter
or a digit, inside brackets, after an initial, and after a short list of
abbreviations. A sentence ends before the next block marker (a list item's `-`,
`*`, `+` or number, a block quote's `>`), which is no part of it. An inline
footnote that does not hold the construct is masked as closing brackets, so a
boundary after `.^[note]` stands, and the note stays with the sentence before it. The list is weft's own, because ICU's are thin; it is in
`dev/design-2d.md` under decision 57. The sentence is for display (7.3.3) and
ranking only, and never decides whether an entry has changed. A failure marker inside a stored
sentence has no line number. A footnote's definition marker is not part of its
sentence.

**7.1.2** Every inline R value is recorded, with or without an attribute
block. A bare value is not a construct (1.1.8), but it prints in the
document. It has no printed record (1.4.11), so its entry holds the text
knitr printed.

**7.1.3** The ledger is one JSON-lines file per source file and output, at
`_weft/ledger/<source file>/<output name>.jsonl`. The condition log (7.4.1) is
beside it, at `<output name>.conditions.jsonl`. The source file is the file
that was knitted, relative to the project root, as the author named it: under
`rmarkdown::render()` not rmarkdown's copy of it, and an `.Rmd` is taken as a
`.qmd` only when Quarto is running the knit. The output name is the output
file's name without its folder or its extension. The output name is that of the
output file; under Quarto's `-o`, which weft cannot see, it is the source's
unless `WEFT_OUTPUT` names it, and the knit warns that other outputs will
overwrite this ledger. Quarto gives no `output-file` for `gfm` and `typst`, and
for those the source's name is used without the warning. An output name that
ends `.conditions` is refused: nothing is written, and one warning says why. A
document rendered with different `params` to different outputs keeps a ledger
for each, and a render that overwrites an output overwrites its ledger. The
ledger is committed. It is written when the knit reaches the end of the
document and its output is written: in draft mode, with each failed construct
marked; not by a render that stops on its failures, and not with `ledger: false`
(9.1.9), which also leaves the condition log unwritten. With `ledger: false` no
reads are collected (7.2.2): there are no ledger warnings, no network cache
(7.4.1) and no background process, and the conditions of the targets upstream
are not looked for.

**7.1.4** An entry is keyed on its `#id` where it has one, with the id's
occurrence. Otherwise it is keyed on five things: the file the construct is
written in; the anchor of its section; its kind (a value, an `n`, `if` or
`sign` span, or a `cite` span); its expression; and its occurrence index among
the entries in that file and section with the same kind and expression.
The expression of a value is its inline R, parsed, so spacing and line
breaks do not count. That of a governed span is the value of its key,
parsed. That of a `cite` span is its keys and its bracket text, written
`keys | bracket text`. Formatter classes and arm text are not part of the key.
Line numbers are not stored.

The anchor of a section is its heading's `{#id}` where it has one, kept as
written, repeated or not. Otherwise it is Pandoc's identifier rule applied to
the heading's source text, from which attribute blocks, link
targets, footnote references, inline R code, tag-shaped runs of raw HTML (`<` and a
letter, to the next `>`) and emphasis markers are first removed. The text of
other inline code is kept, and a `<` or `>` that opens no tag is text.
A heading in an HTML comment is not a heading. The anchor is `""` above the
first heading and in front matter. A caption, a string and a child's text are
in the section of their chunk. A construct inside a heading takes that
heading's anchor.

**7.1.5** Lines are sorted on file, section, kind, expression and occurrence,
ids included, one entry per line, so a merge conflict is
local to the entries both sides changed. The ledger is output: a conflict is
resolved by rendering the chapter again, never by hand.

**7.1.6** Inserting a construct above another with the same kind and
expression in the same section shifts the occurrence index, and each later
one is then compared with its predecessor's entry. Where the printed text
differs, that shows as a change. It cannot hide a change. An `#id` removes
it.

**7.1.7** An entry has **changed** when its printed text or its chosen arm
differs from the entry with the same key at the comparison point (7.3.2).
Raw values are stored to a fixed number of significant figures, and are used
only to rank changes. The raw value of an `integer64` is its value when a
double holds it exactly, else none.

**7.1.8** A changed expression is a changed key. The entry under the old key
is removed, one under the new key is added, and `changes()` lists both
(7.3.5). A check loosened inside a value's expression shows this way.

**7.1.9** Both files are UTF-8 with `\n` line ends on every platform. Besides
`"`, `\` and the control characters, these invisible characters are written as
`\uXXXX` escapes: U+0085, U+00A0, U+00AD, U+061C, U+2000 to U+200F, U+2028,
U+2029, U+202A to U+202F, U+205F, U+2060, U+2066 to U+2069 and U+FEFF. Every
other character is written as itself. Nothing is written
in a session whose locale is not UTF-8, and one warning names the locale.
Nothing is written through a symbolic link: when `_weft`, `_weft/ledger`, the
source's folder under it, or either file is a link, neither file is written
and one warning names the link. A file that cannot be written is one warning,
and the render carries on. A render started inside a chunk is its own top-level
knit and writes its own files; when it ends the outer knit's state is as it
was.

### 7.2 Three states

**7.2.1** An entry is *unchanged*, *changed*, or *not re-rendered*: its
chapter was not rendered, or was served from freeze, since something it
depends on changed. An entry is not re-rendered when any of what 7.2.2 records
differs now.

**7.2.2** The ledger's header records, with a hash of each, the targets the
chapter reads, the dictionary entries its code reads and its source files. All
three are objects, always present, with names sorted. They are found in a
top-level knit of a set-up project, from the code of every chunk that runs
(children and cached chunks included, and the chunk that calls `weft_setup()`)
and of every entry, with the functions it calls followed. The header's files are the source, every file an entry is
written in, every child, and every file a literal `source()` or `sys.source()`
names. A target is read by `tar_read()`, `tar_read_raw()`, `tar_load()` and
`tar_load_raw()` with a literal name (a symbol or a string), and is recorded
under the store it is read from: a literal `store`, else the knit's configured
store. A function of the author's, in the knit's environment, whose body passes
one of its own arguments as the name to one of these four is a reader: a call of
it with a literal name is a read of that target, from the store its body gives,
evaluated as follows. The reader's default `store` and default `name` are used
when the call leaves them out. The argument may be passed as `{{ x }}`,
`!!enquo(x)` or `!!ensym(x)`, which are seen through, and a bare symbol at the
call is then the name; a reader that passes its argument plainly to
`tar_read_raw()` needs a string. A `store` that is not a literal is evaluated at the end
of the knit, in the knit's environment; when it gives one string, that is the
store. A `store` that is a local of the reader is unresolved. When it cannot be
evaluated, or is unresolved, the read is recorded under the default store
and the knit raises one `weft_ledger_warning` naming the read. A target's hash is the `data` hash in `tar_meta()`; a
dictionary entry's is of its JSON with names sorted at every level, so reordering
its fields changes nothing; a file's is of its bytes with line ends made `\n`. A
hash of what cannot be read is `null`. The condition log's header holds none of
this.

**7.2.3** `verify()` reports entries that were not re-rendered ("chapter 17:
34 values not re-rendered since `fit_reband` changed"), and does not pass
(tier 1).

**7.2.4** A chapter is judged from its own header: a target whose hash differs
now or that is not in the store, a dictionary entry that differs or is gone, and a
file that differs or is gone. A chapter served from freeze keeps its old header,
so it shows what has changed since. The freeze stamp (2.9.2) is not part of this.
A header written before these fields is not stale. A missing `targets` package,
a store that does not exist, a store that exists but cannot be read, and a
`dict.yml` with problems are each a note saying what was not checked, not a
reason. A ledger whose source is gone is noted as such, and is not also stale.

### 7.3 `changes()`

**7.3.1** `changes()` compares the ledger and the condition log in the
working tree with their versions in `HEAD`. `changes(since = "<commit or
tag>")` compares them with their versions at any commit. Without git it is an
error. Before the first commit, everything is new. A ledger whose source was
renamed is compared with the old one (7.3.8).

**7.3.2** "Changed" always means: against the committed version at the
comparison point, which is `HEAD` or the commit given to `since`.

**7.3.3** `changes()` shows each changed entry as its sentence before and
after. Where a section anchor exists only at the comparison point and another
only now in the same file, the removed and added entries with equal kind,
expression and occurrence are paired and shown as changed, marked `(section
renamed from #<old>)`. Within a group of entries with the same file, section,
kind and expression whose counts differ between the two sides, the occurrences
are lined up by their sentences before the occurrence index is used, so deleting
one of three identical expressions reports that one as removed.

**7.3.4** Structural changes come first: a governed span choosing a
different arm, a sign flip, crossing zero, crossing 1.0 (for an entry whose
`unit` is null on both sides, a ratio or a count, and not for a quantity),
crossing a dictionary threshold, and an order-of-magnitude change. A change can have
several, and they are shown in that order. They are judged from the raw values.
A sign flip is two non-zero values of opposite sign; crossing zero is exactly one
of the two being zero; crossing 1.0 is strict, the value being on one side of 1
and then on the other, so starting or ending at 1 is not a crossing. Crossing a
dictionary threshold is the same test against a number, quantity or year that the
entry's expression or its sentence names, taken from `dict.yml` at the
comparison point and now; a quantity threshold is converted to the unit of the
raw value first, and with no unit on either side, or no conversion between
them, or no readable `dict.yml` on a side, there is no crossing for that key. An
order-of-magnitude change is a factor of ten or more, with a tolerance for
rounding. The rest follow, ranked (tier 3): a change to a value next to a claim
word, that is, in the same sentence, ranks above one that is not. The entry's
own text is removed from the sentence, as a whole word, before the claim words
are looked for. The claim words are the default lexicon of 5.5.4, English
only. The number words (`one` to `twelve`, `first`, `second`, `third`) are not
on it.

**7.3.5** It also lists the entries added and removed, each with its
sentence; the new conditions (7.4.4); and the tier-2 findings on material
added since the comparison point (5.1.5; from stage 3).

**7.3.6** It marks the entries not re-rendered (7.2.1), every listed entry of
such a ledger carrying "(not re-rendered)". It renders nothing, writes nothing
and runs no pipeline, so a store behind its code is not seen; `tar_outdated()`
shows it.

**7.3.7** Nothing is accepted. Committing the ledger is the acceptance.

**7.3.8** Every `*.jsonl` file under `_weft/ledger/` is a ledger on both sides,
whatever its name. A ledger that exists only at the comparison point, or whose
source is gone, is a candidate for a rename of one that exists only now. The two
are paired when at least half the entries of the first match an entry of the
second by section, kind, expression and occurrence, or by id, and either the
output names are equal or each output name is its own source's base name; the
largest share wins, and a tie pairs nothing. A paired ledger is compared entry
by entry with each entry's file mapped from the old source to the new. A ledger
that cannot be read, on either side, is a note, and prints a count as a new or
deleted ledger does. When `_weft/ledger/` is ignored by git, one note says so. A ledger whose source is gone carries that note
only: its third state is not computed.

**7.3.9** `print()` of what `changes()` returns shows a header line, then the
ledgers not re-rendered, the structural changes, the other changes ranked, the
entries added, the entries removed, the new conditions and the ledgers whose
status is not a comparison. A ledger that is new, deleted or unreadable is
listed there with a count of its entries, an unreadable one too. An entry whose
text is `""`, an arm that prints nothing, shows `(prints nothing)` as its text,
and never a neighbouring sentence. `print(x, brief = TRUE)` shows the header line, the
structural changes, the ledgers not re-rendered and the new conditions, and
nothing else.

### 7.4 Conditions

**7.4.1** The condition log is machine-written and committed. It sits beside
the ledger, one file for each ledger file. It has four sources:

- chunk conditions, from the `evaluate` hook (2.8.1)
- conditions raised by values in prose (2.8.2)
- for a chunk served from knitr's cache, the conditions logged when it was
  computed, stored under the chunk's cache hash and replayed
- the warnings and errors that `targets::tar_meta()` holds for each target a
  chapter reads, and for the targets upstream of those, in every store the
  chapter reads from. `tar_meta()` stores no messages, so a message raised inside
  a target is not seen (§15). It joins a target's warnings into one text, which
  is one line, and a branch's condition is logged under its pattern. Finding the
  targets upstream runs the pipeline's script once per project render, and the
  edges are kept, keyed on the store's `meta` file (its size and modification
  time) and the script's path, not on the run, so a render of one file reuses
  them. They are found for every store a chapter reads (not with `ledger: false`, 7.1.3), and a store whose script
  cannot be found is one warning. A script that cannot
  be run is one warning, and the targets read are still logged.

**7.4.2** A **severity list** of patterns decides which conditions fail the
render (tier 1). It ships with patterns for the model-fit conditions that do
not stop a fit: `lme4`'s singular fit, which arrives as a message, and
`glmmTMB`'s non-positive-definite Hessian, which is a warning. It is
configurable. A message is matched only where it is logged: in a chunk or in
prose, not inside a target (7.4.1). A warning that `tar_meta()` holds is
matched too.

**7.4.3** Every other condition is recorded in the log, one line each, keyed
on its source, its class and its normalised text (7.4.5). The lines are
sorted. Nothing is listed by hand as known.

**7.4.4** A condition that the log at the comparison point (7.3.2) does not
hold is **new**. It shows as an added line in the log's diff, and `changes()`
lists it. An ordinary render reports it and carries on, comparing against
`HEAD` when git is available, else against the log of the previous render, and
the report says which. A log that git does not track (ignored, or in no commit)
is compared with the previous render. Outside a repository with no log on disk
yet there is no earlier render, and no report. A new condition fails nothing.

**7.4.5** A condition in one render is matched to one in another by its
source (chunk label or target name), its class (warning, message or error)
and its text after normalising. Normalising, in order:

1. remove ANSI styling
2. replace hexadecimal addresses and R's temporary paths with a placeholder
3. replace every number (digits with any sign, a decimal part, which needs a
   digit after the point, or an exponent) with a placeholder
4. turn curly quotes into straight ones, and `cli`'s bullets and rules into
   their ASCII forms
5. collapse every run of whitespace, including line breaks, to one space

The source of a condition from prose, or from a chunk with no label, is its
file and section in the log; the line of 2.8.2 stays in the knit's own
records.

**7.4.6** The log keeps the text as first seen beside the normalised form,
so a reader sees a real message, cut to 1,000 characters. A later render
carries that text forward, from the log in the working tree, while the
normalised form matches, so a changed number in a message does not
change its line.

**7.4.7** Two limits are accepted. Messages that differ only in a number
match, so "Removed 5 rows" and "Removed 5000 rows" are one line. A message
translated by the session's language, or reworded by a package upgrade, is a
new condition.

---

## 8. `verify()`

### 8.1 What it runs

**8.1.1** `verify()` is the one entry point for everything that needs a
render. It runs, in order:

1. every static lint, at every tier (§5), and the comparison of §6 (8.2.2)
2. the `decision:` pointers (4.5.2)
3. the render, re-executing every document it verifies (§8.3)
4. the knit-time results: failed checks, unevaluated constructs, documents
   served from freeze, and conditions on the severity list (§2.6, 2.5.2,
   2.9.3, 7.4.2)
5. the ledger: entries not re-rendered (7.2.3)

**8.1.2** It reports the total of every tolerated finding (6.2.5), rule by
rule, without failing on them: "412 typed numerals remain".

**8.1.3** A per-rule setting in `_weft.yml` makes a rule strict (9.1.2).
Then any instance of that rule's finding fails `verify()`, whether or not
`HEAD` held it. An author turns it on when adoption of that rule is finished.

**8.1.4** Each part can be switched off in the configuration. `verify()`
reports which parts were skipped, and why.

**8.1.5** `verify()` refuses to run in draft mode (§9.4).

**8.1.6** Rendering needs no wrapper: `quarto render`, an editor's Render
button and `rmarkdown::render()` all run the hooks.

### 8.2 Arguments

**8.2.1** `verify(files = )` renders and judges only the named files.
Documents it was not given, served from freeze or not, are not its concern.
The rules that read across files (6.2.4) still read the whole project.

**8.2.2** `verify(since = "<commit>")` runs the hook's comparison (§6)
between that commit and the working tree. It fails on findings added
(6.2.2). It reports constructs removed (§6.3), and does not fail on them,
because trailers may not survive. With no `since`, it compares with `HEAD`.

**8.2.3** `verify(static = TRUE)` runs only what needs no render: steps 1 and
2 of 8.1.1.

### 8.3 The render

**8.3.1** Under Quarto, the render step re-executes each document once:

1. if a backup from an earlier run exists, restore it first
2. copy the documents' entries in `_freeze` to a backup, and remove the
   originals
3. run one ordinary project render
4. on success, delete the backup; on failure, restore it

**8.3.2** The freezer is left holding the verified results, so the next
ordinary render serves what was checked.

**8.3.3** Under rmarkdown, `verify()` renders each `.Rmd` with
`rmarkdown::render()`. There is no freeze step.

### 8.4 CI

**8.4.1** `use_ci()` writes a workflow that runs
`verify(static = TRUE, since = <the merge base>)` on a pull request. GitHub
Actions is the default.

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
| `thousands_from`, the smallest absolute value that gets the thousands mark; `serial_comma` | 1.4.16, 1.4.15 |
| the default governor class: the class that formats an `n` or `sign` governor with no formatter of its own; `.num` unless set | 1.5.18 |
| whether `.pct` reads its value as a proportion (the default) | `.pct` |
| the `.count` threshold; the `.word` limit | `.count`, `.word` (1.4.12) |
| the level of `ci()`; the tolerance of `about()` | 3.5.3 |
| `dict_local` (front matter only) | 4.3.4 |
| `bibliography`, for files the front matter and the project do not name | 5.4.4 |
| the date format | `.date` |
| `unit_form`: whether a quantity's unit prints as its symbol or its name | 4.4.15 |
| `unit_defaults`: whether weft's default units are used (`weft`) or the `units` package's readings (`si`) | 4.4.21 |
| `units`: a unit's name, plural, symbol, space, meaning (`is`) and side of the number (`before`) | 9.1.7 |
| `ledger`: whether the ledger and the condition log are written | 7.1.3, 9.1.9 |
| `draft` (project only where `_weft.yml` exists) | §9.4, 9.1.4 |
| `decisions` (project only where `_weft.yml` exists): where `decision:` pointers resolve | 4.5.3, 9.1.4, 9.1.8 |
| project formatters: class name, function, stage | 1.4.8 |
| the severity list | 7.4.2 |
| the rules made strict (none unless set) | 8.1.3 |
| numeral exemptions: label words (none unless set), four-digit years | 5.2.4 |
| the claim-word lexicon, words added and dropped; the cap on listed sentences | 5.5.4, 5.5.3 |
| the word count above which a guarded bracket is listed | 3.1.9 |
| whether the sentence-start list fails the render (it does not unless set) | 5.10.1 |
| the classes and keys the project expects on a construct, from other systems | 5.3.3 |
| parts switched off (project only where `_weft.yml` exists) | 8.1.4, 9.1.4 |
| the package version | 9.5.4 |

**9.1.5** The settings built so far have these keys and defaults, in
`_weft.yml` and under a document's `weft:` key alike. A project is "set up"
(9.3.2) when its root holds `_weft.yml`.

```yaml
digits: 1              # decimal places for a number that is not whole
decimal_mark: "."
big_mark: ","          # thousands mark, applied from thousands_from up
thousands_from: 1000   # 1.4.16
serial_comma: false    # 1.4.15
minus: "−"
governor_class: .num   # 1.5.18
pct_proportion: true
count_threshold: 10
word_limit: 100
draft: false
ledger: true           # false turns the ledger and the condition log off (9.1.9)
unit_form: auto        # auto, symbol or name (4.4.15)
unit_defaults: weft    # weft or si (4.4.21)
units: {}              # 9.1.7
decisions: github      # github, github:<owner>/<repo>, a file pattern, a function (9.1.8)
formatters: {}         # 1.4.8
severity: []           # 7.4.2, added to the shipped patterns
label_words: []        # 5.2.4: words after which a numeral is exempt, as typed ("Site")
numeral_years: false   # 5.2.4: true exempts a four-digit year, 1000 to 2999
claim_words: {add: [], drop: []}   # 5.5.4
claim_cap: 20          # 5.5.3: claim-word sentences listed per file by changes()
guard_words: 25        # 3.1.9: words in the longest arm of an `if` before it is listed
expected_names: []     # 5.3.3: classes (".foo") and keys ("foo") the project expects
```

A wrong value for `label_words`, `numeral_years`, `claim_words`, `claim_cap`,
`guard_words` or `expected_names` is a `weft_config_error` naming the setting
and the rule.

**9.1.6** `thousands_from` is a whole number, and `serial_comma` is `true` or
`false`, and so is `ledger`. `unit_form` is `auto`, `symbol` or `name`. Any other value is an error
when the configuration is read (9.1.3); for `unit_form` it is a
`weft_config_error`. `unit_defaults` is `weft` or `si`, and may be set in a
document's `weft:` as well; any other value is a `weft_config_error`:
"`unit_defaults` must be `weft` or `si`; got `<value>` (rule 9.1.6)."
`decisions` is one of the four forms of 9.1.8.

**9.1.7** `units:` maps a unit, written as `u()` takes one, to up to six
fields: `name`, `plural`, `symbol`, `space`, `is` and `before`.

```yaml
units:
  sites:
    name: site             # the plural by the rule: "sites"
    symbol: false          # printed by name in every form: "1 site", "12 sites"
  PSU:
    name: practical salinity unit
  CFU/100 mL:
    name: colony-forming unit per 100 millilitres
    plural: colony-forming units per 100 millilitres
    symbol: CFU/100 mL     # not units' "CFU/(100mL)"
  d:
    symbol: false          # "5 days", not "5 d"
  "%":
    space: true            # "35 %"
  gal:
    is: 4.54609 L          # the imperial gallon replaces the default's
  ppth:
    is: 0.001              # a number alone is a dimensionless unit
    name: part per thousand
  pH:
    space: false           # merged into the default row: "pH7.2"
  NTU: false               # removes the default row; NTU stays registered
```

`space` governs the symbol only, on whichever side of the number the unit is
written; a name always has its space (4.4.8).
`name` and `plural` are non-empty strings (`plural` alone re-plurals the name
weft finds, 4.4.17), `symbol` is a non-empty string or `false`, and `space` is
`true` or `false`. A row of a unit the project defines that gives `name` and no
`symbol` has no symbol, as `symbol: false` has (4.4.8); `symbol: false` is
needed only to take the symbol from a unit weft or the database already knows. A `name` with no `plural` takes the English rule (4.4.16), over a default row as
well: the plural of the new name, never the default's.
The text of an entry is markdown, printed as written (4.4.8). When the
configuration is read (9.1.3), before the dictionary, each key's unparseable
tokens are registered as 4.4.7 says and the table is checked. Every problem is
raised together as one `weft_config_error` that stops the knit, in draft mode too.
Its first line is ``weft: <file>: N problem(s) in `units:` ``, then one line each:
``<file>: units: `<key>`: <what> (rule 9.1.7)``. The problems are: `units` that
is not a mapping; a key that does not parse, parses only with a warning, or has
a power that is not whole; two keys for one unit; an entry that is not a mapping,
or is empty; an unknown field, which is named; a field of the wrong type; a key that is a
number, cancels to nothing (`m/m`) or holds no unit; and `symbol: false` on a
unit with no name; an `is` that is not one of the forms below (`2 m 3`), or that the
`units` package cannot read, or that 4.4.20 refuses; a key with `is` that is more
than one token or ends in a digit; an `is` that redefines a unit of the database
or gives the same unit as another row; a `before` that is not `true` or `false`;
and `false` for a key the default table has no row for. The unknown-field line
lists the six fields. A read with problems registers nothing of the project's
(4.4.7), and a row whose install fails leaves nothing behind: what
`units::install_unit()` half-installed is removed.
A document's `weft: units:` is checked alike, naming the document, and its
entry for a unit replaces the project's entry for that unit whole, and when that
drops a definition the problem names the document and the field; the other
units merge (9.1.1). Over a row of weft's default table (4.4.21), the project's
or the document's row merges field by field. After the read `u(3, sites)` works with no dictionary. Outside
a knit the `units:` table of the last configuration read is used, and
`unit_form` is not carried over. The table kept for that use is cleared at the
start of every read, so a read that fails leaves none.

`is` says what a unit is. It is `base`, a unit of its own that converts to
nothing; a positive finite number, a dimensionless unit; or an optional
positive number, a space and a unit expression (`1 mi/h`, `mi/h`), as a YAML
string or number. It is read as `u()` reads a unit, against the database and the
rows installed before it (weft's default table, then the project's, then the
document's, each in file order), so a forward or a circular reference is a
problem. A key with `is` is one token: no space, no digit first, none of
`* / ^ ( ) . +` or `-`, and no digit last (`units` reads a trailing digit as a
power). Without `is` a key only names a unit. Two rows with the same `is` text
are the same unit, and a problem. A key takes `is` only when the `units`
package does not already read it, asked of `units` itself and so without regard
to letter case. `is` on a key that `units` reads, as a unit of its own or as a
prefix and a unit, is a problem that says what `units` reads the key as
(`m: {is: ft}`, `ppt: {is: 0.001}`, `km: {is: 1 mi}`, `Bags: {is: base}`),
because it would rewrite every unit derived from it; the exceptions are a token
on the misread list of 4.4.20 and a key of the default table (`gal`, `mt`,
`pH`). An `is` that names a unit weft installed is read against it; where its
definition is exactly that unit (`is: 1 zzr`) and `units` cannot hold two symbols
for one unit, the problem is the "same unit" one, naming the other key.

`before` is `true` or `false` (the default) and puts the unit before the number
(4.4.22).

A key whose value is `false` removes weft's default row for that unit: its
redefinition is undone, so under `weft` the token is refused if it is on the
misread list (4.4.20), and its names drop. A registration of `is: base` stays.

The fields of one unit come from the default row, and over it the document's row
if there is one, else the project's, so a project's `name` for `PSU` changes the
name, and the default row's `is` still applies.

**9.1.3** The configuration is read when a knit is initialised (2.1.5), not
when the hooks are installed.

**9.1.4** `draft` and the parts switched off are project settings. Where a
`_weft.yml` exists, either one in a document's front matter is an error,
found from the source (5.8 rule 8) and when the knit is initialised. A single
document with no `_weft.yml` may set them in its front matter. `WEFT_DRAFT=1`
is unchanged (9.4.1). `decisions` is a project setting too: in a document's
front matter, where a `_weft.yml` exists, it is a `weft_config_error` when the
knit is initialised ("`decisions` is a project setting: set it in _weft.yml, not
in a document's `weft:` front matter (rule 9.1.4)."). A single document with no
`_weft.yml` may set it.

**9.1.8** `decisions` is where `decision:` pointers resolve (4.5.3), as one string
of four forms:

| Written | Route |
|---|---|
| `github` (the default) | GitHub issues of the repository named by `git remote get-url origin` |
| `github:<owner>/<repo>` | GitHub issues of that repository |
| a string that holds `{id}` (`decisions/{id}-*.md`) | a file glob, relative to the project root |
| `pkg::fun`, or a bare R name | a function of the pointer |

```yaml
decisions: github:example-org/example-repo
```

Any other value, or a value that is not one string, is a `weft_config_error`
when the configuration is read: "The setting `decisions` must be `github`,
`github:<owner>/<repo>`, a file pattern holding `{id}` (as decisions/{id}-*.md),
or a function written pkg::fun; got `<value>` (rule 9.1.8)." A value that is the
name of the route in another letter case (`GitHub`) is that error too, and it
offers `github`, so a typo is not read as a function. A function that cannot be
found is a `weft_config_error`: "Cannot find the decisions function `<fun>` (rule
9.1.8)."

**9.1.9** `ledger` is `true` (the default in a set-up project) or `false`. With
`ledger: false` in `_weft.yml` or in a document's `weft:` front matter, the
ledger and the condition log are not written (7.1.3), so a project can keep
`units:` rows in `_weft.yml` without a ledger. The front matter overrides the
project file in either direction. With `ledger: false` the knit also collects no
reads (7.1.3).

**9.1.10** The units tables are kept for the session. A copy in the user's cache
directory (`tools::R_user_dir("weft", "cache")`) is written only under
on by default; `options(weft.units_cache = FALSE)` turns it off. A bad or stale copy
falls back to a read of the tables.

### 9.2 Activation

**9.2.8** A `.qmd` is a weft document when it has two things: `engine: knitr`
in its own front matter, and the activating call, `weft::weft_setup()`, by one
of the routes of 9.2.1. `use_setup()` writes both. `engine: knitr` in
`_quarto.yml` or `_metadata.yml` does not count. Under rmarkdown an `.Rmd` is
always knit, so the activating call is enough there. The smallest weft
document activates from its front matter:

```yaml
---
title: "Survey results"
engine: knitr
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---
```

**9.2.1** There are three places to activate a document.

| Where | What is written | Covers |
|---|---|---|
| the document's front matter | `knitr:` / `opts_knit:` / `weft: !expr weft::weft_setup()` | one document, under Quarto and rmarkdown |
| `.Rprofile` at the project root | `if (requireNamespace("weft", quietly = TRUE)) weft::weft_setup()` | every document in a Quarto project that is knit (9.2.8), wherever it sits |
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
was called, or because `dict_vale()` was, which writes a Vale rule file. Each
says what it will write before it writes it.

| Function | Writes |
|---|---|
| `use_weft()` | everything below, with a summary first |
| `use_setup()` | the `.Rprofile` line (Quarto project) or the front-matter line (single document); `engine: knitr` in the front matter of the document, or of each `.qmd` a Quarto project renders (9.2.8); `_weft.yml`; under rmarkdown, the `weft-check` Lua filter and the `pandoc_args` line that names it (2.5.3) |
| `use_quarto()` | the `weft-check` Lua filter as a project extension; the `pre-render` and `post-render` scripts |
| `use_hooks()` | the `commit-msg` shim, with the paths of R and Pandoc (6.1.5) |
| `use_ci()` | the CI workflow (8.4.1) |
| `use_dictionary()` | `dict.yml` when absent (a starter that reads as no keys, with two examples commented out) and `_weft/dict.schema.json` |
| `dict_vale()` | one Vale rule file, `styles/Weft/Terms.yml` unless `path` says otherwise (4.7.2) |
| `use_agent_docs()` | agent-facing conventions and the Claude skill |

**9.3.2** The hooks alone write nothing. The condition log, the ledger, the
freeze stamps (2.9.2) and the failure files are written only in a project
that has been set up with `use_weft()`. Whatever creates the folder `.weft/`
also writes `.weft/.gitignore` holding `*`, so that its files are not committed
by accident; the `pre-render` script of `use_quarto()` is one of them. With
`ledger: false` (9.1.9) neither the ledger nor the condition log is written.

**9.3.3** `inst/` holds the hook template, the Lua filter, the render scripts,
the CI workflow template, the dictionary schema and the starter dictionary, the
table of default units (4.4.21), the default claim-word lexicon and severity
list, and the Claude skill. The skill says:

- a failed claim is a finding to report to the author, not an error to clear
- do not change or remove a check to make a render pass unless asked
- when a commit removes constructs on purpose, add the `Weft-Removed` trailer
  with the count the hook gives
- the `dict_local` rules (§4.3)

**9.3.4** `use_dictionary(path = ".")` writes under the project root: the folder
holding `_weft.yml`, else `_quarto.yml`, found from `path` upwards, else `path`.
When that differs from `path` it says so. `path` that is not one existing
folder is a `weft_tool_error`. It considers two files. `dict.yml` is written
only when absent, and an existing one is never changed. `_weft/dict.schema.json`
is written when absent or when it differs from the schema that ships with this
version, which is weft's own file. It says what it will write, and for each file
whether it is new, left as it is, or replaced, then writes, then names what it
wrote. When nothing is to be written it says only that nothing changes. It never
asks, interactive or not: the call is the consent (P10). It returns, invisibly,
the paths written, relative to the root. A file that is a link, a folder in the
file's place, and a write that fails are each a `weft_tool_error` naming the
path, raised before anything is written where that can be known, and a file is
never reported as written that was not. When `dict.yml` exists and its own
schema line is missing, or points somewhere else, the call prints the line to
use: `# yaml-language-server: $schema=_weft/dict.schema.json`.

The starter reads as a dictionary with no keys; its two commented examples, a
quantity with a `display` and a `decision` and a string with an `avoid`, read as a
dictionary of two keys when uncommented. The schema is JSON Schema draft-07, for
an editor's YAML support; the `dict.yml` line `# yaml-language-server:
$schema=_weft/dict.schema.json` points at it. It accepts every dictionary that
`read_dict()` reads, except two: text written as a bare `true` or `false`
(`definition: true`, which an editor reads as a boolean), and a key with a
letter outside A to Z (`café`, which R reads in a UTF-8 locale and not in
others). `read_dict()` refuses more than a schema can say, so a file the schema
accepts may still be refused.

### 9.4 Draft mode

**9.4.1** Draft mode is `draft: true` in the configuration, or the environment
variable `WEFT_DRAFT=1`.

**9.4.2** In draft mode nothing fails the render. The markers appear in the
output, the failures are listed in the knit log, the ledger is written with
each failed construct marked (7.1.3), and in a project that has
been set up they are written to a JSON file beside the document,
`<document>.weft-failures.json`. A warned check (2.6.10) is in that file too,
with `"level": "warn"`.

**9.4.3** Draft mode covers the render only. Knit-time failures, and
construct errors met during a render, are reported and marked (2.6.8), not
fatal. One construct error stays fatal in draft mode: inline code that does
not parse (5.3.5), because knitr stops on it before any hook runs. The
`weft-check` filter reads the same setting, and reports instead of
exiting. The commit hook is not affected by draft mode, and `verify()`
refuses to run in it (8.1.5).

### 9.5 Adoption helpers

**9.5.1** `recall_check()`: given recorded findings and a pre-remediation
commit, runs a lint against the historical state and reports what fraction of
the findings it reproduces, and how much else it flags. A recorded finding
carries a quotation, or a file and a line; the quotation is searched for in
the prose of the documents, and a finding with neither is not located. A
finding is reproduced when a finding of the rule starts in a sentence its
location overlaps, or, for a location outside any prose sentence (a chunk
header or option, a caption), on a line the rule flagged. It returns one row
per rule and a last row for all rules together, with the verdicts below. It is a sanity check
on one lint: a result of none reproduced, or of nearly everything flagged,
sends the lint back to design. It does not rank layers and does not remove
one.

**9.5.2** `dict_seed(paths = NULL, min_files = 2)` harvests candidate dictionary
keys by finding constants defined in more than one chapter. It parses and never
runs code, and writes nothing. With `paths = NULL` it reads every `.qmd`,
`.Rmd` and `.rmd` under the project root, outside folders whose name starts with
`_` or `.` or is `renv`; given files, it reads those (`.R` files too, which are
read only when named). A `.qmd` or `.Rmd` is read as its R chunks, except those
with `eval = FALSE` (or `#| eval: false`) written literally. A constant is a
top-level assignment (`<-`, `=` or `->`, not `<<-` or `assign()`) of a symbol to a
number, a string, a minus or plus on a number, or `c()` of numbers or of strings;
anything inside `{`, `if`, `function` or `local()` does not count. A piece that
does not parse is skipped and listed, and a chunk that holds a nested code fence
is listed the same way; the other chunks are read. It returns a data frame of
the names assigned a literal in at least `min_files` files, one row each, with
the columns `name`, `value` (the text, or `NA` when the values differ), `differs`,
`n`, `files` and `where` (each assignment as `<file>:<line>: <value>`), sorted by
`n`, largest first, then `name`; the attribute `skipped` lists the pieces left
out, with `file`, `line` and `message`. A constant written by a computation, or
inside a function or a block, is not seen; a name reused for unrelated things in
two documents is listed, and the author decides. A missing file or another
extension is a `weft_tool_error`, and so is a `min_files` that is not a whole
number from 1.

**9.5.3** `status()` reports which parts are installed, which are switched
off, and what the next step is.

**9.5.4** The configuration records the package version. `verify()` warns on
a mismatch.

**9.5.5** `label_seed()` counts each capitalised word followed by a numeral
("Site 3", "Zone 2", "Stage 1") in the existing prose, and proposes the words
as candidate label words (5.2.4), each with its count. The author chooses
which go in the list. A word counts only when the very next word is a numeral;
cross-reference words, label words already set and common prepositions and
quantifiers are not proposed.

---

# Part 2 — Rationale

## 10. The problem

### Two uses

The package is built for two kinds of document.

**A dynamic report.** A document rendered on data that is not known in
advance, such as an email rendered daily from new data. The author wants what
it says to fit their mental model of the data, as a programmer declares types
and writes a branch for each case. Each case the author expects gets its own
wording (§1.5), each assumption is a check (§3.1), and a case nobody expected
fails the render instead of printing a plausible sentence. `arms()` and
`rehearse()` (§3.7) show what the document can say before the data arrives.
This use needs nothing from git.

**A long report or a book, through many iterations.** A change in one place,
such as a method changed early on, must flow through to the rest, or the
author is warned where it does not. Computed values carry the change. The
ledger and `changes()` (§7) list the sentences that now say something
different. The commit gate (§6) stops the accidents that break the link
between a value and its prose.

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
| B1 | **Silent deletion.** A `sed` or heredoc removes a paragraph, a section, or a value. What remains is valid markdown, renders clean, looks fine. | §6.3 |
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

**Surfacing beats coverage.** A signal nobody reads is no check. A check that
must stop something fails at a checkpoint someone passes through, and the
checkpoint is the commit itself and its message: the hook judges what the
commit adds and what it removes, and the message says what was removed on
purpose (§6). What need not stop anything is put where the author already
looks: the diff of the ledger and of the condition log, and the list
`changes()` prints (§7). A separate report on its own schedule is not that
place. FindBugs's dashboard went unused, and the same Infer analysis was
acted on almost never when run nightly and over 70% of the time when shown at
code review (`dev/research-checks.md` §3).

## 11. Layer labels

The companion plan and the first scoping document number the checks as layers.
This document does not use the labels anywhere else.

| Label | What it is | Rules |
|---|---|---|
| L1 | structural diff: the commit says how many constructs it removes | §6.3 |
| L2 | claim tokens: numerals and claim words in prose | §5.2, §5.5, §5.6 |
| L3 | checks: `claim()` and the one-arm `if` | §3.1, 1.5.3 to 1.5.5 |
| L4 | cross-references and citations | §5.4, §5.7 |
| L5 | the value ledger, and `changes()` | §7.1 to §7.3 |
| L6 | surfacing: conditions, unevaluated constructs, frozen chapters | §2.5, §2.8, §2.9, §7.4 |
| L7 | prose style | not a package layer: Vale (§16); `dict_vale()` (4.7.2) |
| L8 | hygiene | §5.8 |
| L9 | trailer and register validation | one trailer, `Weft-Removed` (6.3.2); no register (§16) |
| L10 | the dictionary | §4, 5.8 rule 6 |
| L11 | figures and tables | §1.10, §5.9 |
| L12 | data contracts in the pipeline | not a package layer: §15 |

## 12. Principles

**P1 — Every check must have a machine-checkable ground truth.** A mechanism
that enforces *form* rather than *content* is satisfiable without thought.

**P2 — The machine observes and reports; the author says what was
removed.** The gate computes what a commit changed and says so. It asks for a
word only where constructs were removed, because that is the change that is
invisible afterwards, and the word is one line in the commit message.

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
called. `dict_vale()` is the one other function that writes a file, and it is
a call that says first what it will write.

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

**P13 — Stop accidents; let purposeful changes through.** In the author's
words: "What we want to stop is accidental changes, not make purposeful
changes needlessly complicated." Authors increasingly work through coding
agents, where every extra step is an extra paid tool call. A purposeful change
costs at most one line in the commit message. What the harness wants seen, it
shows in a diff the author already reads.

## 13. Why the rules are as they are

Each note is keyed to the rule it explains.

### Syntax

**1.1.2** Prose never sits inside an R string, so it stays visible to the
lints, to spellcheck and to the reader of the source.

**1.1.3** The exception is small and closed. The function words a formatter
prints ("and", "of the") are fixed by the package; the phrases of a `lookup()`
or `brk()` are stipulations held in the dictionary, where they are read and
reviewed in one place.

**1.1.4** The inline R a document already holds counts as it stands.
Adoption adds front matter (9.2.8) and rewrites no prose. Stock Quarto
escapes markdown characters in the output of `` `{r} x` `` and not in the
output of `` `r x` ``, so the two bare forms are not the same, and each keeps
what its author chose.

**1.1.8** The rules about constructs exist for what weft adds to markdown.
Bare inline R adds nothing, so a document with no attribute blocks renders as
it did before weft (1.9.2), wherever its inline R sits.

**1.1.5, 1.1.9** Without this, `[results]{.strong}` does nothing: a weft
class the author wrote on a bracket is passed over without a word. A text
class means the same on any bracket. A formatter class on typed text has no computed number
to format (5.2.1), so it is left to the warning. On a plain bracket an `#id`
is an anchor; on a text span it would be dropped from the output (1.2.8), and
the anchor lost without a word.

**1.2.2, 1.2.3** Pandoc's markdown writer, and so the visual editor, rewrites
every value to double quotes. `{if='tier == "sev"'}` comes back from a save
as `{if="tier == \"sev\""}` (§18): a backslash and an inner double quote,
which weft's scanner would then have to unescape exactly as Pandoc does. One
written form that survives a save unchanged is the rule: double quotes, or
none, with nothing inside to unescape. An expression that needs a double
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

**1.2.8** An id is a name for weft's own use: agreement and the ledger. Emitting it would put every one into the document's anchor namespace,
where the cross-reference rules and Quarto's reserved prefixes apply.

**1.2.10** Editors and phones capitalise the first letter after a brace or at
the start of a line. A capitalised key otherwise leaves an ordinary span that
prints every arm, with no check. Class names stay case-sensitive, because a
capitalised class may belong to a stylesheet; the lint lists it instead
(5.3.3).

**1.3.2** A check that ran after formatting would test a rounded number.

**1.3.4, 3.3.5** "Mean depth was NA m" reads as a sentence, and a default
phrase for `NA` is a sentence nobody chose (1.5.3). A bare value is left as
stock prints it, so that a document with no attribute blocks renders as it
did before weft (1.1.8). A vector of length zero is the one case where
silence can be right, a list that may be empty, so it is a value only where the
author said what to print (1.4.14, 1.5.19). `NULL` stays missing: a misspelt
column is `NULL`, and must not print "No sites were flagged".

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

**1.4.8** The static checks must know a project class, and its stage, without
running R: a class that is not registered is listed as unknown (5.3.3), and
the at-most-one rule is a construct error found from the source (1.4.2).
`_weft.yml` is read without R.

**1.4.9** A unit belongs to the value, not to the way a number is printed.
Carried by the value, it cannot differ between two sentences, and a
computation that changes it changes what prints.

**1.4.19** Short names, like `.num` and `.ul`. `.name` and `.symbol` would take
common class names away from pass-through (1.2.6). The unit classes are one
group that is not a stage because they do not reword the number: they choose
how the unit goes beside it. `.pct` is not a unit, so `unit_form: name` leaves
its "%" alone.

**1.4.20** A symbol's case is its meaning ("mL" and "ML" are different units),
so a capital would change what is said. "5th m" has no reading.

**1.4.10** This is what stock knitr does, and a formatter's own output is
markdown. Escaping would break both.

**1.4.11** Arm selection, the ledger and the reports all need to know that
"< 0.001" is a bound.

**1.4.12** "One point five sites" and "minus third" are not things an author
means. Past a limit a spelled number is harder to read than digits.

**1.4.13, 1.5.18** Arm choice follows the printed number (1.5.9), so a
governor has to print in a known way, and without a default class how a
governor with no formatter printed was undefined. A count is whole. Printed
to the default digits it would read "3.0 sites", and a governor of 1 would
print "1.0" and take the plural.

**1.4.13, 2.6.11** (a printed zero) Fixed decimals are the convention, and
1.5.10 judges zero on what prints, so a change of 0.04 prints "0.0". But "0.0"
for a real difference is a sentence that is silently false, so it is reported.
Failing the render would stop an unattended report on an ordinary small
reading, and a fallback to one significant figure would put numbers of mixed
precision side by side and leave no change ever "unchanged". `digits` or
`sigfig` is the author choosing, so it silences the report. Below 1e-9 a
number is the noise of floating-point arithmetic, and is zero. The report
follows the default digits wherever they print a number, so a small range, a
pair list or an interval cannot print "0.0" unseen, and it is one check for
each construct or call so that a vector does not bury the report. A setting
copied from the project default is not the author choosing, and a class
applied to text another formatter made reports what it prints itself, so
`digits` given earlier does not hide a loss that this class causes. `.sci`,
`about()`, `of_n()` and a project formatter print no fixed decimals the rule
could judge. A governor is exempt because its zero is an arm; the `#` of a
`list` span prints the vector as a value does, so it is reported.

**1.4.14** A list that is empty is a fact a sentence may need to state, and
without the key a vector of length zero fails (1.3.4). The wording belongs
beside the value. On a span or a value with no collapse class there is nothing
for the key to apply to, which is why it is an error. A range always has two
ends, so there is no empty range for `none` to name. A blank `none` would
print nothing where the author meant a word.

**1.4.15** A serial comma is a house choice with no majority, so it is a
setting. A `last` on the construct is the author's own wording, and wins. A
`sep` is the author's mark between items, so the mark before the last joiner
follows it ("a; b; and c") and a comma does not appear among semicolons.

**1.4.16** Both trial documents write "1,000", so a default of 10,000 changed
their text. A year is not a quantity, and is left bare.

**1.4.17** The values near 0.05 are the ones a reader acts on, and two decimals
print 0.046 as "p = 0.05". Three decimals below 0.1 keep them apart; from 0.1
up two are enough.

**1.4.18** rmarkdown builds a PDF with pdflatex by default, and without the
declaration every negative number stops the build with an error that does not
name weft. The ohm, prime, double prime, micro and degree signs are the same
case: a unit written with one stops the same build the same way.

**1.5.1** The key says what kind of governor it is, and each key fixes its arm
counts, so a wrong count is found from the source without running R.

**1.5.3** The alternative is a default arm, and a default arm prints a
sentence nobody chose. A `list` span with no zero arm fails for an empty
vector for the same reason: the empty case is a sentence nobody wrote.

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
rise. An `n` or `sign` governor that prints "0.0" takes the zero arm by design, so
there is nothing to warn about.

**1.5.17** `#` in a `sign` arm is the magnitude. For a bound there is none,
and "fell by < 0.1%" beside "rose by < 0.1%" would turn on a sign the printed
text no longer shows.

**1.5.11** A count inferred from a length silently turns a vector of two
depths into "2". For ranges, CLDR's plural-range data gives every English
range the plural. A vector that may be empty has its own span (1.5.19), so
that no count is ever read from a length.

**1.5.12** A backslash cannot be the escape. Pandoc's markdown writer, and so
the visual editor, puts a backslash before every `|` and `#` inside a span,
separators included, and Pandoc's reader removes it again, so `\|` and `|` have
to mean the same thing. Removing backslashes first and then reading doubles
gives every form the writer produces the meaning it had before the save (§18).
An empty arm needs its space because `||` is taken. The space beside an empty
span is the span's to remove (1.5.20) because arms are trimmed, so the arm
cannot hold it, and the author writes ordinary spacing outside the span.

**1.5.13** The render is not the problem: the hooks resolve the span before
Pandoc sees the table. But the source is also read by Pandoc's
position-tracking reader (the lints) and by the visual editor, and their
pipe-table parsers split a row on every unescaped `|` before any span exists, and
they split one inside a span's attribute block too, so a ladder's `|` is written
`\|` there, which Pandoc reads back as `|`.

**1.5.16** An arm written for a case that did not happen may not be
computable in the case that did.

**1.5.19** `n="length(x)"` fails when `x` is empty, and `n` never takes a count
from a length (1.5.11), so the span that chooses by length is a separate key
with its own rules. A matrix has a length and a shape, so it is not taken for
a list of sites, as a data frame is not. A list class makes a block, and a
`list` span is inline. A `NULL` is not an empty list, because a misspelt column is
`NULL`. A number vector needs no guard: site numbers are a natural list, and a
count passed by mistake prints "3 was flagged", which shows on every render.

**1.5.20** Without it an empty arm leaves two spaces, or a space before a full
stop, and the author must write the spacing inside the arms, where it is
easily lost. The list is the marks that close a clause or a quotation. A
straight quote may open or close, so a space before it is kept.

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
wrong as English plural rules (1.6.5), and as silent. A unit's name is words
and its symbol is not, so a symbol still prints under another language and a
name does not.

**1.6.1, 1.7.2, 1.7.3, 1.7.5** (`list`) A `list` span chooses its arm as an
`n` span does, so the rules of the language apply without being stated twice.
The inner count must agree with the vector, so `n="."` inside it takes its
length. A list and its verb in one span cannot disagree. An id names a printed
number (1.7.6), and a `list` span prints a vector.

**1.7.4, 1.7.6 to 1.7.8** An R variable names a value; an id names a printed
occurrence. Compute with the variable, agree with the id. With no formatter of
its own, the referring span uses the number as it was printed there, so
agreement follows what the reader saw (1.04 printed as "1" takes the
singular). `#` begins a comment in R, so `"#d"` can never be mistaken for an
expression.

**1.7.5** (`cite` spans) The text of a `cite` span is part of its key in the
ledger, because it is the quoted number (7.1.4). An id would keep the key when
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

**1.8.9, 1.8.10, 5.6.1** A `` `r 10` `` reads in the source as a computed
value and is not one. It is also what a computed value turns into when it is
reverted to its number by hand (B2). So a new one fails the commit, and the
ones a document held at adoption are counted. The escape that is open is the
`.weft-literal` mark, which says in the source that the number is typed, and
why. Its `why` is the record, so nothing else lists it. Before writing a
literal, ask why the number cannot be computed: a project constant goes in
the dictionary, a count of things in the document gets counted, an ordinal
gets computed. Methods text, legislation and quotations are dense with
numbers that are not data claims, which is what the block form is for.
"Literal" is defined by constants and operators so that the rule is decided
from the parsed expression alone.

**1.8.5** `@{key with spaces}` resolves in a bibliography and is still left
as literal text by Pandoc, so resolving alone does not show that a citation
will print.

**1.8.11** Pandoc writes an unknown attribute into HTML (`data-why="…"`). The
reason belongs to the source, not to the published page.

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

**2.4.6, 2.6.10, 3.1.11** An unattended report needs "tell me, but send it".
The level belongs to the one check and is visible where it is written, which a
project setting would lose, and a second function would be a new name for the
same act. A guard cannot warn: its phrase would print false, and no span has a
level. A bare `"warn"` reads as a check that is a string, so the error says
what to write. Warnings are reported when the knit ends in an error too, so a
stopped render does not hide what was already found.

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

**2.5.3, 2.5.4** In a file that is not knit (9.2.8), the hooks and the
end-of-document check never run, and a value with an attribute block reaches
Pandoc as a code span that keeps its attributes, so no attribute block shows
as text. The `pre-render` check names the file before anything renders; the
filter catches it afterwards, and catches a capital `R` (`` `R x`{.num} ``),
which knitr does not read as inline code even in a file that is knit.

**2.6.1, 2.6.2** One report with every failure lets the author read all the
affected sentences in one pass. Stopping at the first hides the rest.

**2.6.5** A construct error is found from the source, and nothing rendered
after one can be trusted.

**2.6.6** A failing chapter would otherwise stop the project at that chapter.
Warned checks go in the same file so that one report lists them.

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
blocks (§18). So one reader, the scanner, owns the constructs. The prose
between them is read by the package's own reader by default, because a gate
that counts findings against `HEAD` must not depend on which Pandoc is
installed, and a Pandoc read of each chapter costs more than the budget of
half a second. Pandoc stays available, and the tests hold the two readers to
the same answer.

**2.10.5** Four spaces at the start of a line make an indented code block. A
paragraph that begins with a construct, masked with spaces, became code, and
the lints skipped it. A letter keeps a paragraph a paragraph; the check
catches any case the letter does not, such as a closed fence or a lone line of
`-` left at the start of a line inside an arm (Q9). Not every line start cuts
a span: Pandoc's `markdown` reader keeps one whole across a wrapped `#`, `>` or
list marker, so those are not findings.

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

**3.4.5** `last` defaults to `NULL`, not to "and", so that the setting can
apply when the author gave none. Otherwise the function could not tell an
explicit "and" from the default.

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

**3.7** A dynamic report is rendered on data nobody has read first (§10). The
author writes a branch for each case they expect, and needs to read every
sentence the document could print, not only the ones today's data chose.
`arms()` shows them without running anything. `rehearse()` runs the document
against the cases the author fears, such as no rows, a missing value or a
negative change, before the data brings them, and the arms no case reached
are the sentences never yet seen in place. No R or Quarto tool, and no study,
was found that previews every branch of conditional prose or tests a
template against such inputs; the nearest practice is UI work, with a story
for each empty or error state (`dev/research-checks.md` §4). A case is a
list of `params` because `params` is the one input a render takes from
outside the document. Rehearsal writes nothing to the project, so a rehearsed
case never reaches the ledger. A `list` span's arms are listed like any other,
and a case that warns is reported although it does not fail.

**3.7.5** A script needs what failed and what warned after a knit, and
`rehearse()` returns the same records, so one name serves both.

**3.4.4** A unit that printed through the class and not through the function
would make the two forms of 3.2.1 print different text. The attributes keep
what a function given the text needs to format it again; a collapse keeps each
element's form, so a chain of functions prints what the class would.

**3.4.8** A function that could not choose the form would make the two forms of
3.2.1 differ, as 3.4.4 says. `NULL` is the default so that the nearest
setting can apply when the author gave none (3.4.5). `plural()` takes its
arms as text, so the form is chosen on the formatter that makes its governor.

**3.4.9** A heading or an axis label needs the unit with no number, spelled as
the text spells it, and resolved by the same rules. A plural name is the common
case in a heading ("Length (metres)").

### Dictionary

**4.1.2** The key is a plain token in the parsed expression, so a static lint
verifies every read without running R (5.8 rule 6).

**4.2.2** A derivation in the dictionary is a number typed by hand.

**4.2.4** A year is held as a class because an attribute is lost by `c()`,
`range()`, `seq()` and `year + 0:2`, and "2,014–2,024" would print. A plain
integer prints "2,014" under `.num`. The `vctrs` methods are registered only
when `vctrs` is loaded, so weft does not depend on it.

**4.2.7** A quantity is held in the unit the data came in and read in the unit
the reader expects, as 4.4.14 says. `display:` converts when the dictionary is
read, not when it is printed, because `units` keeps an attribute through
`x * 2` but drops it in `c()`, `x[1]`, `mean()` and `y + x`, so a display unit
kept as an attribute would be lost in the pipeline. A ladder is not
allowed in `display:` for the reason that picking at read would give: the unit an
entry is held in would follow its value, so changing 800 m to 8,000 m would change
`units::drop_units(dict$x)` by a factor of 1,000 with no error, and `a + b` and
`b + a` would print in different units. An attribute carrying the ladder would
survive `x * y` onto the wrong dimension and be lost in `c()` and `mean()`. So the
ladder is written where the value is printed (decision 53). The cost is that the
pipeline sees the display unit, so adding `display:` changes the value a
target reads, and the readers of that target re-run.

**4.2.5** A dictionary is a committed file of constants, so it must not hold a
value its author cannot see: YAML 1.1 reads `010` as 8, and a merge key or a
second document silently changes what an entry holds.

**4.3.1, 4.3.2** A paragraph moved to a chapter with no local `sites` errors,
instead of quietly changing meaning.

**4.4.1** A unit has to survive arithmetic, or it is wrong as soon as a
quantity is used: `dict$a / dict$b` is a ratio, `dict$depth * 100` is still
metres, and adding kilograms to metres is a mistake. The `units` package does
exactly this, and is widely used: 111 CRAN packages depend on it, `sf` among
them. Writing weft's own unit arithmetic would repeat it, worse.

**4.4.5** A check states its unit, so that if the quantity is later held in
another unit the check converts, or fails, instead of comparing the wrong
numbers. `claim(x, . < 0.45)` written for micrograms would pass a value
later held in milligrams that is a thousand times too large. The error on a
bare number is therefore intended, not a cost.

**4.4.6** `units::set_units(35, m)` in every check is long enough to be
skipped. `u()` is the same call, short.

**4.4.7** Domain units such as practical salinity and turbidity units are not
in the udunits database, and a count noun such as "sites" never is. Without
registering them, a dictionary that names one could not be read.

**4.4.8** SI style puts a space between a number and its unit symbol. A
no-break space keeps them on one line. A ratio has no unit to print. The
unit's text is Pandoc markdown, not Unicode superscripts: a Unicode
superscript stops a pdflatex render and vanishes under xelatex without a
font, while `m^2^` survives pdflatex, xelatex, HTML and Word. The cost is that
a formatter's text for a quantity is markdown, so a plot label needs its own
unit.

**4.4.2, 4.4.3** SI style puts a unit symbol with a numeral and a unit name
with a spelled number, and forbids "five m". weft prints both forms, and the
author types neither, so the unit cannot drift from the quantity. A name
with a spelled number reads as the sentence it is in. The unit goes once after
the last item, in that item's form, because the reader meets the unit at the
end of the list.

**4.4.15, 4.4.16** The setting nearest the use wins, as for every other
setting. Under `symbol` a spelled number is an error rather than "five m"
because SI forbids it, and printing the name instead would make `symbol` the
same as `auto`. A name is singular only for a number that prints "1" or "one",
the rule of arm choice (1.5.9), so that `trunc="1"` reads "1 metre and 2
others", and "−1 metres" is plural.

**4.4.14** A conversion that `units` makes by inverting the value (metres to
"1/m") turns a length into a different quantity without a word of warning;
a quotient to a quotient is a true conversion.

**4.4.17** The units database's names are technical (`international_foot`,
`tropical_year`, `metric_ton`), give the US spelling first, and have no
invariant plurals, so a shipped table comes before it. A day, hour and minute print as
SI symbols, which SI accepts, and a year prints by name because SI has no symbol
for it. weft never guesses a name for a unit it does not know (4.4.19).

**4.4.18** The names follow NIST SP 811: "square metre" for a length and "metres
per second squared" for anything else.

**4.4.20** A unit that `units` reads as another prints a true number with a
wrong unit, which weft cannot detect afterwards. Reinstalling the symbol does
not cure it: after `Sv` is removed and defined again the gray holds `Sv`, and
after the same for `Bq` the hertz holds `Bq`, because the `units` package stores
the symbol udunits maps to the parsed unit, which its maintainers say is
udunits's design. Keeping the token the author wrote, and changing nothing in
the database, is the only fix that leaves the other packages' readings alone. A
misreading that is a valid prefix parse (`pH` as a picohenry, `mph` as a
milliphot) cannot be told from the unit meant, and weft has no list of the
units a report uses, so it knows a list of the ones found, and redefines the six
that a report means in the default table. The phot and the are are never meant
with a prefix, so the two traps are general. `mt` is refused rather than
defined, because the author means a tonne and SI a millitonne, a factor of a
million. Under `si` nothing is refused: the setting asks for what `units` reads,
and refusing SI's own units under it would invert the setting. A prefix on a
unit of weft's own (`kmph` is 1609 km/h) is never what was meant. The lists are of
units found to misread, and are pruned or grown as more are found.

**4.4.21** weft's defaults are the units a water or air report writes, so that
`u(3, NTU)` and `u(7.2, pH)` work with no dictionary and print as the report
does. The table is data, in a file a project can read and copy from, and not
code. Loading weft must not change what a picohenry is for any other package,
so the table is registered when weft first reads a unit, and each read brings
the database to what that read wants: a book or a test run knits in mixed modes.
The mode is named for what the author gets instead (`si` is what `units` reads),
and a name changes no meaning, so the names apply in both; a name for `pH` would
call a picohenry "pH", so the redefining rows do not. A twin conversion is
refused because a sievert is not a gray. `is:` may not redefine a unit of the
database because `m: {is: ft}` would rewrite every unit derived from it for the
session. A prefix on a default unit with `is:` is refused because `kNTU` was never a
unit anyone wrote on purpose. The merge is per field so that adding `space:` to
the default `pH` row does not restate `is:`. What someone else installed is not
weft's to remove.

**4.4.22** "7.2 pH" is wrong in every style guide, and "pH 7.2" is the form a
report uses. The unit goes once before the first item of a collapse, as the unit
goes once after the last item in 4.4.3: "pH 6.5–8.5". In a compound the pH is
not the token alone, so the unit follows ("0.2 pH/h").

**4.4.23** weft does not choose a unit by itself, because the unit would change
with the data from one day's report to the next and within a table, and because
the right unit is a convention of the field: rain in mm, a concentration in the
unit of its limit. A ladder is the set the author approves, so the choice stays
the author's and weft only applies it to the value. The number is tested as it
prints because the arm chosen follows the printed number (1.5.9), and 999.96 m
would otherwise print "1,000.0 m" and be in the wrong rung. A vector takes the
rung where most of its numbers fit because the largest value would print the
small elements as "0.0" ("0.0, 0.1, 0.8 and 2.5 km"). Every rung is checked so
that an error does not come and go with the data, as in 4.4.19. The order is the
author's because overlapping rungs (`mm|cm|m`) need one. The `|` is written
`\|` in a pipe-table cell for the reason given at 1.5.13, and `display:` takes
one unit for the reason given at 4.2.7. When no rung fits, a rung that prints
1,000 or more is taken before one that prints below 1 because the first keeps
every digit and the second loses them; the cost is that 940 m under `mm|km`
prints "940,000 mm" (decision 54).

**4.4.19** An error that waited for a number that prints a word would arrive
months after the document was written, on the day the count fell below the
threshold. Judging on the classes makes the error appear the first time the
document is knit, whatever the data.

**4.4.4** A unit the author types in the arm is wrong as soon as the quantity
is held in another unit; a unit weft prints cannot be.

**4.4.14** A quantity is stored in the unit the data came in and read in the
unit the reader expects. Converting in the expression (`units::set_units()`)
is long and hides the intent.

**4.4.10** A bare value prints as stock prints it (1.1.8), and stock knitr
prints a `units` value as its number (§18).

**4.4.11** One code path: `u()` is always there, and any `units` value
prints with its unit without a check for whether the package is installed. A
suggested package would make a quantity print differently on a machine that
lacked it. The cost falls on Linux, where udunits-2 is one system package.

**4.5.1, 4.5.2** The package keeps no register of its own (§16), so the
pointer goes through a resolver and is tied to no one tracker. The default
resolver needs the network, which a commit hook must not (P6).

**4.5.3** GitHub numbers issues and pull requests together, and a decision may be
recorded in a pull request. A glob is what is written and nothing more, so a
pattern that wants a boundary writes one. The `curl` package gives the status
code and headers exactly; base R's `url()` reports a status only inside the text
of a message, which differs between R versions, and the `gh` command needs
installing and signing in. The remote is used only inside the project because a
project folder inside another repository would otherwise resolve against that
repository's issues. The project root is not part of the pattern, because a
folder named `Survey [2024]` is ordinary. A string pointer under the GitHub
route does not resolve, with its reason, instead of stopping a read for a check
that belongs to `verify()`.

**4.5.4** "Unresolved" must mean that the record is missing. An offline machine,
a private repository without a token and a rate limit all make GitHub answer
something other than "here it is", and GitHub answers 404 for an issue in a
private repository it will not show, so the repository is asked about first:
without that, a missing token would read as an unresolved decision. After a
refusal every further call would fail the same way, so the check stops. A
cache would be a generated file (P8), or in a session would hide a deleted
issue; one call per pointer is within GitHub's limit.

**4.6** A stipulation matters most where it is computed with, so the pipeline
reads the same object with the same spelling. `targets` cannot see `dict$key`
as a dependency on one key, so the walker sets it. `tar_outdated()`
over-reports what a dictionary edit will re-run; `tar_make()` is
authoritative. Without 4.6.5 a dictionary change does not re-render the
report.

**4.7** Three things the dictionary removes rather than checks: the glossary,
the unit, and terminology rules.

**4.7.1** The glossary is a string a chunk prints, not a file: it writes
nothing (P10), and there is no `results: asis` to forget. It is headed by the
`term` and not by a key, because a key is an R symbol and a prettified key is
guessed text. The value is the stipulation, so it prints as written, with the
house style and the unit names, and with the decimals the author wrote: default
digits would print 0.01 as "0.0". It ends with a blank line because a paragraph
below the chunk would otherwise be read as part of the last definition. `labels`
and `breaks` show no value because no one reading of a map or of bands as one
phrase is obvious. Outside a knit it reads `_weft.yml` so that the preview at
the console is the glossary the document prints.

**4.7.2** `dict_vale()` replaces only a file it wrote, so that it never destroys
a rule an author wrote, and removes it when no spelling remains so that no stale
rule is left. It leaves `.vale.ini` to the author and says what it needs: a
user's Vale configuration holds other styles, and is not weft's file. It
removes only the project's own rule, because a `dict_local` or another
dictionary says nothing about the project's.

**4.7.3, 4.7.4** One field serves the glossary heading and the Vale rule, any
type can carry a term, and there is no second file to keep in step; a term that
is only a spelling is a `string` entry. The checks are made when the dictionary
is read, because a spelling inside a canonical spelling makes Vale flag the
right word in every document. A spelling that Vale's word boundary cannot match
would never fire, and nothing would say so. A term that holds a line break or
starts with a block marker would break its glossary entry or become a heading.
The rule is case-sensitive because a case-insensitive one would match the
canonical spelling against a variant that differs only in case. The schema is
copied into the project and replaced when it differs, so that it works offline
and per project, and `_weft/` is where weft's files go. It is never stricter than
`read_dict()`, so that a correct file is not marked wrong; what YAML 1.2 cannot
see stays with the reader. Text that an editor reads as YAML 1.2 differs from
the reader's on a bare `true` where text is meant, which is nearly always a
slip, and a key with a letter outside A to Z breaks on a machine whose locale
is not UTF-8.

### Lints

**5.2.1** This also catches B2 mechanically: a value reverted to its literal
*is* a bare numeral.

**5.2.2** Pandoc makes "11-year" one token, so a rule on Pandoc's tokens would
exempt it as a mix of letters and digits. It is a number.

**5.2.3** A rule that fails on every numeral already in a manuscript cannot be
switched on. Judged against `HEAD`, it stops new ones at once and leaves the
old ones in place, counted by `verify()` until the count reaches zero and the
rule can be made strict. A file listing what `HEAD` already holds would be a
second copy of `HEAD` for someone to keep (6.2.5).

**5.2.4** A typed "Table 3" goes stale when floats are reordered; a
cross-reference does not. The words that genuinely need the exemption ("Site
3", "Zone 2", "Stage 1") differ by document, so a shipped list would exempt
the wrong words in every one.

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
tier 2. The list is short because a long one, with number words and bare
comparatives, flagged two sentences in three of a real manuscript (decision
66).

**5.1.5** git's diff already knows what was added, and a check that judges
only changed material is the one that gets read (Tricorder reports on changed
lines by default: `dev/research-checks.md` §3). A re-wrapped paragraph shows
as added, and is listed again; that errs towards more to read.

**5.6.4** The stages are where the printed record is made (1.4.11). A value
rounded in its own expression still prints, but agreement and the ledger see
only a raw number.

**5.7** The check is that a reference *resolves*, not that the target still
says what the citing sentence claims. That is tier 3.

**5.8 rule 1** A heading that contains a construct has no stable automatic
id, so the explicit anchor matters twice.

**5.8 rule 7** knitr builds a chunk's cache key from its code and options, not
from the target's value, so a cached chunk serves the old target after the
pipeline has changed it.

**5.8 rule 8** See 9.1.1 and 9.1.4.

**5.8 rule 9** See 9.2.8. An included file or a child document is knit as
part of the file that takes it in (2.7.4, 2.1.5), so it needs no engine of its
own.

**5.10.1** A recomputed value can open a sentence with a digit or a lowercase
word ("12 sites failed"; "no sites failed"). The fix is `.cap`, with `.count`
or `.word` for a number.

### Commit gate

**§6** An earlier design charged for every purposeful deletion: an
entry with a note in an append-only `weft/removals.yml`, a second authored
file, `weft/accepted.yml`, for the ledger's must-reads, a hand-kept
`weft/baseline.tsv` with rules for stale entries, and a paragraph matcher to
decide what was an edit. Each was a step for every purposeful change, and
through a coding agent each step is a paid tool call (P13). The checks that
are kept are the ones the research supports: a check that blocks needs almost
no false alarms and should judge changed material only, a separate report
goes unread, and one-step acceptance with a diff is the common pattern. No
mainstream tool asks for a written entry per removal
(`dev/research-checks.md` §2, §3 and the table of candidate mechanisms).

**6.1.1** The gate reads the commit message, and the message does not exist
until after `pre-commit` has run. A `commit-msg` hook reads the staged files
and the message's trailers both (§18).

**6.1.3** The worktree is not what is being committed.

**6.1.4** P6. Tier 2 is left out of the hook because output that prints on
every commit and blocks nothing is not read: "warnings shown when building
are often ignored" (Tricorder, `dev/research-checks.md` §3).

**6.1.5** A git hook started from an editor or a GUI client does not have the
shell's `PATH`. `quarto pandoc` costs about 0.15 s more per call than the
binary it wraps.

**6.1.6** A book of twenty chapters took about nine seconds to scan in full
(§18), which is too long to do on every commit. The `HEAD` version of a file
was usually the staged version at the previous commit, so its scan is
usually in the cache already.

**6.1.8** Correct. See §14.

**6.2.1, 6.2.2** A construct error is never right, so it fails wherever it
is. Any other finding fails only when the commit adds it. Adopting weft then
fails no commit on what the document already held, and a new finding is
stopped in the commit that made it. A check that blocks must almost never be
wrong (Tricorder asks for "essentially zero" false positives), and judging
only what the commit changed is how the default analysers keep to that
(`dev/research-checks.md` §3).

**6.2.3** Counting by text across the commit lets a paragraph move between
files at no cost, with nothing to pair. An earlier design paired paragraphs
across versions, and needed a matcher and two thresholds to do it.

**6.2.4** An anchor is removed in one file and its references dangle in
others, which the commit may not touch.

**6.2.5** A file that lists what `HEAD` already holds is a second copy of
`HEAD` for someone to keep. Such files grow, and go stale unless pruning is
enforced: ESLint and RuboCop each need a separate step to prune theirs, and
in one study 50.8% of suppressions suppressed nothing
(`dev/research-checks.md` §2, §3). `HEAD` is never stale.

**6.2.6** A typed number moved within a commit is not a new typed number. The
case the limit lets through, the same text removed in one place and typed
again in another, is rare, and the second one is still counted by
`verify()`.

**6.3.1, 6.3.2** A deletion is the change that leaves nothing to look at
afterwards (B1). Every removal is allowed; the commit says how many. The
hook prints the line, so the author or the agent copies one line into a
message it was writing anyway, and anyone who reviews the commit sees the
count. Values, spans and checks are what an accident removes and what the
rest of the harness depends on. Bare inline R is counted because it prints a
number in the document (7.1.2), and `claim()` in chunk code because a check
deleted there is as silent as one deleted in prose.

**6.3.3** The changes that move constructs between kinds, or rewrite their
expressions, are never accidents. An accident removes: a `sed` that eats a
paragraph, a re-wrap that breaks a line directly after `` `r `` (5.3.4), a
heredoc that overwrites a chapter. Counts per kind or per expression would
charge for renames and conversions, and a charge paid on every commit is
paid without reading (Chrome's one-click warning was clicked through 70% of
the time: `dev/research-checks.md` §3).

**6.3.5** A stale trailer, left in a message after the removal was undone,
harms nothing.

**6.3.6** The trailer is for the moment of the commit, and for whoever
reviews an agent's work, who sees it then. After a squash the history no
longer holds the removal as a separate step either. Over a range,
`verify(since = )` reports removals instead of judging them (8.2.2).

### Ledger and conditions

**7.1.2** The ledger is the record of what the document said, and a bare
value prints a number in the document as surely as a formatted one.

**7.1.3** A dynamic report is rendered again and again, sometimes to several
outputs with different `params`. A ledger per output keeps one render from
overwriting the record of another. One output in two formats shares one
ledger, because the knit is the same.

**7.1.4** Line numbers change with every edit above a construct, so the key
uses what such an edit does not touch. An `#id` is the author's own name for
an occurrence, and survives a change of expression. Formatter classes and arm
text are left out of the key so that changing them shows as a change to the
same entry, with its sentence before and after.

**7.1.7** Raw floating-point values differ between machines. A ledger that
changed whenever they did would be all noise.

**7.1.5, 7.1.6** How often a committed ledger conflicts, and how often the
occurrence index shifts, can only be learned in use. Both fail towards more
to read, never less.

**7.1.8** A widened bound is the change most often made to clear a failure.
No rule can tell it from a corrected one, so it is shown, not stopped (§14).

**7.2.1** With two states, a partial render passes as clean.

**7.3** This is the "re-read these sentences" list of the second use (§10):
a change in one place flows through, and `changes()` says where the prose
may no longer fit. It takes over what an earlier design's separate integrity
report listed. Nothing found in the research builds such a list from value
dependencies (`dev/research-checks.md` §5).

**7.3.4** Both families of ranking are heuristics that narrow a human read.
Nothing here verifies English against a number.

**7.3.7** Committing is already a step the author takes, and the ledger's
diff is reviewed where every other diff is. A second acceptance step, kept in
a second file, was the cost an earlier design charged for every structural
change. Accept steps get clicked through: testthat dropped a predecessor
that "always overwrites", and blind updating is reported for every snapshot
tool (`dev/research-checks.md` §2).

**7.4.1** A chunk loaded from knitr's cache raises nothing, and a target built
last week raised its warning last week. Without the replay and the
`tar_meta()` reading, the log would show only what happened to be recomputed.
`tar_meta()` keeps warnings and errors and drops messages, which is why a fit
made in a target is checked there (§15).

**7.4.3, 7.4.4** An unread log is the failure of §10. Committed, the log turns
"a warning appeared" into an added line in a diff the author commits, and an
entry in `changes()`. A list of known conditions kept by hand held nothing the
log written by the render does not. A new condition fails nothing because
most are harmless; the ones that are not belong on the severity list
(7.4.2), which fails the render.

**7.4.5** Most numbers in a message change from run to run ("Removed 12
rows"), and the same message wraps differently at another console width.
Without normalising, every condition would read as new on every render.

**7.4.6** Carrying the first text forward keeps the log's diff to real
changes.

### `verify()` and activation

**8.1.2, 8.1.3** A count nobody sees can only grow. A printed total shows how
far adoption has gone, and a rule made strict once its count is zero cannot
slip back. Clang's developers made warnings into errors only after fixing
every existing instance (Google CACM 2018, `dev/research-checks.md` §3).

**8.1.5** A draft render fails nothing, so it can verify nothing.

**8.2.1** In a frozen project the documents not named are served from
freeze, so a `verify(files = )` that judged them failed every time.

**8.2.2** A squash, a rebase or a hosting service's merge may drop the
trailer, so over a range the removals are reported, not judged.

**8.2.3, 8.4.1** A clean clone usually lacks the data to render, and the
static checks and the comparison with the merge base need only the sources. A
clone does not install the hook, so the checks run again where every
collaborator's work passes through (§14).

**8.3.1** Overriding `freeze` from the command line (`-M freeze:false`, or a
profile) also re-executes everything, but removes `_freeze`, and the next
ordinary render then executes everything again. A single render keeps the
single end-of-book report, which separate renders of each file would not. The
backup is restored first because an interrupted run leaves the freezer empty.

**8.3.3** rmarkdown has no freezer, and each `.Rmd` renders on its own.

**9.1.8** One setting with four forms that do not overlap is one line in
`_weft.yml`. It is a project setting because the resolver serves `dict.yml`, a
project file.

**9.3.1, 9.3.4** `dict_vale()` writes a file, and P10 asks that nothing be
written without an explicit call that says first what it writes: the call is the
consent, so it is named beside the `use_*()` functions. `use_dictionary()` never
asks because a prompt in a non-interactive run is a hang, and it says what it
will write first. It leaves an authored `dict.yml` alone and prints the line to
add, because an authored file is not edited. The starter reads as no keys so
that a knit works at once, and shows the fields that are hardest to guess. A
write through a link could change a file outside the project, which the call did
not announce.

**9.5.2** A constant written by two documents with two values is the finding that
matters, so it is listed with every assignment. `.R` files are read only when
named, because a project's scripts are many and are not chapters. An `eval =
FALSE` chunk is example code, and not a definition.

**9.3.3** (the skill) Agents edit checks to get past them. In ImpossibleBench,
Claude models cheated mostly by editing tests, and letting an agent flag a
task for a human cut GPT-5's cheating from 54% to 9%
(`dev/research-checks.md` §1). The skill makes reporting a failed claim the
finished job, and tells the agent the one line a purposeful removal needs.

**9.1.1** (`weft:` in Quarto's files) A key there looks like configuration and
does nothing. A setting that is silently ignored is worse than one that is
refused.

**9.1.4** `draft: true` left in one chapter's front matter made `verify()`
pass for that chapter. A setting that decides what fails belongs where the
whole project reads it.

**9.1.2, 9.1.6** Every choice in how a number prints is a setting, as the
default digits are. A bad value is refused when the configuration is read,
so that it cannot be ignored (9.1.1).

**9.1.7** A project's unit symbols and names are configuration, not data, so
they sit in `units:` and reach every value with that unit, derived ones too: a
symbol written on a dictionary entry would not reach `u(150, "CFU/100 mL")`
in the pipeline. `.pct` prints "35%", and SI itself puts no space before the
signs for degrees, minutes and seconds of angle, so those units default to no
space, and a project that wants "35 %" sets `space: true`; `°C` keeps its space.
Its text is markdown so that it can write `m^3^`. A key registers at read, since
a key must parse to match a unit, at the cost of 4.4.7's. All its problems are
raised together as an error, because a misspelt `plurl` would otherwise be
silent. A document's entries merge with the project's per unit, as every
setting does (9.1.1).

**9.4.3** Draft mode is for writing: an author wants the whole document, with
every problem marked in place. The hook checks the source, which draft mode
does not change.

**9.2.8** A `.qmd` with no code chunk is not knit, so R never starts: every
value prints as code and nothing fails. In the file's own front matter,
`engine: knitr` selects knitr, and so does any `knitr:` key; so does an empty
R chunk in the body. Nothing at project level does: `engine: knitr` at the
top level of `_quarto.yml` or in `_metadata.yml`, `execute: engine: knitr`
in `_quarto.yml`, and a `knitr:` key there all left such a file unknit, and
so did inline R with no chunk (§18). weft cannot set the engine from R,
because R never starts. The front-matter route's `knitr:` key already selects
knitr; `engine: knitr` is written on every route so that one line, the same
everywhere, says the file is knit. Three backstops catch a file without it:
the hygiene rule at commit (5.8 rule 9), the `pre-render` check before
anything renders (2.5.4), and the filter after (2.5.3).

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
a chapter, a paragraph lost in a restructure, a typed number put back where a
computed one was. A check loosened late at night to clear a failure is not
stopped. It shows in the source's diff and in `changes()` (7.1.8).

What follows from that:

- **Every way out is open, and shows.** A `.weft-literal` block, a widened
  bound, a removal and a new condition are all allowed. Each shows in the
  source, in the commit message, or in the ledger's diff. The package's job
  is to make each of them a choice the author made, and can read back later,
  instead of something that happened unnoticed.
- **A purposeful change costs at most one line.** Nothing is accepted by a
  command and nothing is listed by hand (P13).
- **The hook can be skipped** with `--no-verify`. It gives an early answer; it
  is not a lock.
- **The check on CI is the same static checks run again from a clean clone**
  (8.4.1). It is there because a local setup can be incomplete: a clone does
  not install the hook.
- **How strict a check is, is the author's call.** A check that cannot fail is
  flagged (3.1.6), because it is almost always a mistake. A check that is
  merely generous is a judgement, and the package has no view on it. Making a
  rule strict once its count reaches zero (8.1.3) is also the author's call.

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
- **A dynamic report takes its data through `params`.** `rehearse()` (§3.7)
  renders a document once per case by changing its `params` and nothing
  else, so a document that reads its data any other way renders the same
  data in every case.

  ```yaml
  params:
    data: "data/latest.csv"
  ```

  ```r
  d <- readr::read_csv(params$data)
  ```

- **An unattended render fails closed.** A failed render exits non-zero and
  writes the failure file (9.3.2), so a scheduler that sends only on success
  sends nothing, and tells the author. Posit Connect does this by default: a
  failed scheduled render keeps the last good output, does not email
  recipients, and notifies the owner with a link to the log
  (`dev/research-checks.md` §4).

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
- **Keep authored accounting files.** There is no baseline, no file of
  removals and no file of acceptances. `HEAD` holds what was tolerated, the
  commit message says what was removed, and committing the ledger is the
  acceptance (§6, 7.3.7).
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
- **The harness** (lints, gate, ledger, `changes()`, `rehearse()`,
  dictionary, `verify()`) subscribes to that record. `arms()` reads only the
  scanner, and sits with the core.

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

Marker spans, front matter, the failure paths and the gate's construct counts
were each run in a copy of the stand-in extended for that purpose. Under
rmarkdown the Pandoc was 3.8.3, not the 3.10 that Quarto ships.

A row whose source is "review" was found by a reviewer of this design, not run
with the stand-in. A row whose source is "check, 2026-11-11" was run on that
date directly against Quarto 1.11.9, Pandoc 3.10, git or the `units` package,
with no stand-in.

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
| Pandoc's markdown writer, markdown to markdown, puts a backslash before every bar and `#` inside a span, separators included, and Pandoc's reader removes it. The three forms tried are listed below the table; read in the order of 1.5.12, each comes back with the meaning it had | check, 2026-11-11 |
| Pandoc's markdown writer rewrites `{if='tier == "sev"'}` as `{if="tier == \"sev\""}` | check, 2026-11-11 |
| Pandoc's position-tracking reader (`commonmark_x+sourcepos`) parses values and spans into nodes with line and column | Pandoc |
| That reader does not parse `{n='k'}`, `{if='tier == "sev"'}` or `{if="tier == \"sev\""}` as attributes, and doubles backslashes differently from the markdown reader | Pandoc |
| That reader makes "11-year" one token | Pandoc |
| Masking a construct with spaces turns a paragraph that begins with one into an indented code block, which the lints then skip | review |
| The position-tracking reader reads a late metadata block (1.10.9) as a horizontal rule and a heading | review |
| Of span classes, Pandoc turns only `.smallcaps`, `.underline` and `.mark` into formatting, in html, docx, LaTeX and Typst; `custom-style` reaches docx | Pandoc |
| `utils` exports a function named `cite` | R |
| CLDR's plural-range data gives every English range the form "other" | CLDR |

The forms the writer produced (check, 2026-11-11):

```
[rose | fell]{if="x > 0"}     →   [rose \| fell]{if="x > 0"}
[a||b | c]{n="k"}             →   [a\|\|b \| c]{n="k"}
##                            →   \##
```

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
which is unoptimised R. The spike was built for an earlier design that paired
paragraphs across versions. Rows that supported only that matcher are
dropped. The spike counted each construct identity separately; the single
total of 6.3.1 was not run. The timings "with matching" include the matcher,
which the hook no longer runs, so they are an upper bound for the comparison
with `HEAD`.

| Fact | Run under |
|---|---|
| A test manuscript of 10 anchored sections and 156 constructs, and 72 scripted edits with known answers. Counting constructs with no paragraph matching, every real removal is reported, and 35 edits also report a removal that was an edit or a move (139 removals reported, against 98 real ones) | R |
| A plain re-wrap at 55 columns removed 32 constructs from a paragraph without changing a word: 31 where the line broke directly after `` `r ``, one where `# ` landed at the start of a line. Matching on words alone saw one of them; comparing constructs saw all 32 | R, knitr, Pandoc |
| A `commit-msg` hook reads the staged files with `git show :<file>`, and the message's trailers with `git interpret-trailers --parse`. It stopped a commit with no trailer and one with a wrong count, and passed one with the right count. `--no-verify` skips it | check, 2026-11-11 |
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
| Hooks installed when the namespace is loaded take effect, including when it is loaded before the knit begins. Rule 2.1.3 no longer installs on load; the row is evidence only that hooks installed before a knit take effect | both |
| Activation from the document's front matter (`!expr` under `knitr:` or `params:`): a construct in the first paragraph resolves | both |
| Activation from `.Rprofile` at the project root, for documents in the root and in a subdirectory, project and single-file render | Quarto |
| `!expr` in `_quarto.yml` or `_metadata.yml` is not evaluated | Quarto |
| A `.qmd` with no code chunk is not knit: every value prints as code, and nothing fails | check, 2026-11-11 |
| In the file's own front matter, `engine: knitr` selects knitr, and so does any `knitr:` key; so does an empty R chunk in the body | check, 2026-11-11 |
| None of these selects knitr for a file with no chunk: `engine: knitr` at the top level of `_quarto.yml`; `execute: engine: knitr` there; a `knitr:` key there; `engine: knitr` in `_metadata.yml` | check, 2026-11-11 |
| A file whose only R is inline (`` `{r} 1+1` ``) is not knit | check, 2026-11-11 |
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
| `tar_dict()` and `tar_dict_deps()`: a changed value re-runs exactly its readers, through commands and through functions; a changed definition, a new key or a reorder re-runs no consumer; an unknown key errors at definition; a changed function re-runs its target | targets 1.12.0, re-measured for 2e with the dictionary on the search path |
| A `tar_quarto()` report notices a dictionary change only when its `.qmd` is scanned for `dict$key`; then exactly | targets, Quarto |
| `targets::tar_meta()` stores warnings and errors, not messages: `lme4`'s singular fit, a message, is not recorded; `glmmTMB`'s non-positive-definite Hessian, a warning, is | review |

### Units

All with `units` 1.0.0, and `x` 0.5 m, `y` 2 m, `k` 3 kg.

| Fact | Run under |
|---|---|
| `x * 100` is 50 m; `x / y` is 0.25 with no unit; `x * y` is 1 m²; `x + y` is 2.5 m; `x + k` is an error ("cannot convert kg into m"); `x` converted to cm is 50 cm; `round()`, `mean()` and `sqrt()` keep the right unit | check, 2026-11-11 |
| `x > 0.3`, `x == 0.5` and `x + 1` each stop with "both operands of the expression should be "units" objects" | check, 2026-11-11 |
| `PSU`, `NTU`, `sites` and `people` are errors until registered with `units::install_unit()`; after registering, 35 PSU × 2 is 70 PSU, and 5 sites / 2 ha is 2.5 sites/ha | check, 2026-11-11 |
| Known to the units database without registering: `mg/L`, `uS/cm`, `%`, `ha`, `ML/d`, `degC`, `m3/s`, `t/yr` | check, 2026-11-11 |
| Stock knitr prints an inline value of 0.5 m as `0.5` | check, 2026-11-11 |
| On macOS the CRAN binary links the udunits library statically and ships its database, so nothing else is installed. The package's system requirement is udunits-2. 111 CRAN packages depend on `units`, `sf` among them | check, 2026-11-11 |

### Quarto 2

Quarto 2 (experimental, 0.43.0): its parser accepts a governed span whose key
has a quoted value, and rejects a key written before a class and an unquoted
`.`. Values with attribute blocks, and execution, were not tested under it.

## 19. What was not run

**Rules the stand-in does not implement.** None of these has run in any
form:

- the single-quote and escape errors (1.2.3); ids kept out of the output
  (1.2.8); keys matched in any letter case (1.2.10)
- text spans (1.1.9)
- the order of reading `|` and `#` in an arm, and three in a row (1.5.12),
  beyond the three writer outputs of §18
- the default governor class, and `.num` printing a whole number with no
  decimals (1.5.18, 1.4.13)
- the four formatter stages and their at-most-one errors (1.4.1, 1.4.2);
  `digits` and `sigfig` (1.4.7); the limits on the wording classes (1.4.12)
- `sign` on a bound (1.5.17); `n="."` inside a `sign` span (1.7.2)
- units through the formatter stages and the collapses (4.4.2, 4.4.3,
  4.4.8); how weft writes a unit's symbol as text, with its superscripts
  (4.4.8); a compound unit with a number in it, such as "CFU/100 mL" (4.4.7)
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
  test for a leftover placeholder and for a marker (2.5.3, 2.9.5); the
  filter's tests on code spans, on keys in any letter case and on text
  classes (2.5.3)
- the `pre-render` check for `engine: knitr` (2.5.4)
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
  committed condition log with its carried-forward text (7.4.3, 7.4.6)
- the backup-and-restore sequence of `verify()` as a whole (8.3.1); only the
  freeze behaviour it relies on was run

**Parts of the design with no stand-in at all:** every lint; judging
findings against `HEAD` (§6.2); the single total of constructs and the
failure report that lists what is gone (6.3.1, 6.3.4); the hook's cache
(6.1.6); the ledger, its key and its file per output (7.1.3, 7.1.4);
`changes()`; `verify()`'s `files`, `since` and `static` arguments, its
totals and strict rules (§8.1, §8.2); `verify()` under rmarkdown (8.3.3);
`use_ci()`; `arms()` and `rehearse()` (§3.7); `u()` and the registering of
units when the dictionary is read (4.4.6, 4.4.7); the `decision:` resolver;
`dict` and `dict_local` as objects (the `targets` side was run); the adoption
helpers of §9.5, `label_seed()` among them. Of the gate, the timings, a count
of constructs per identity (§18), and a `commit-msg` hook that reads a
trailer were run.

**git operations the hook was not run under.** `git commit --amend`: the hook
compares with the commit being amended, so its count is of the new changes
only. Merge commits. `git rebase` and `git cherry-pick`, which may not run
the hook at all (Q17).

**Installation not checked.** That the CRAN binary of `units` for Windows,
like the one for macOS, needs nothing else installed; the udunits-2 system
package on Linux (4.4.11).

**Rules that follow from how a tool works, not from a run.** Hygiene rule 7
(§5.8): that knitr's cache serves an old target to a chunk that reads one.
It follows from how the cache key is built. Hygiene rule 9: that an included
file or a child document needs no `engine:` of its own. It follows from
Quarto expanding includes before knitr reads the file (2.7.4), and from knitr
knitting a child from inside its parent.

**A toolchain fact not checked.** Whether Pandoc's markdown writer keeps the
letter case of a key on a round trip (1.2.10). Rule 1.2.10 reads `If` as `if`
either way.

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
after a chunk errors mid-render is untested, and the restore step of 8.3.1
depends on it.

**Q4 — Quarto 2 execution.** It hands knitr text re-serialised from its parsed
tree. Whether the hooks then see the constructs unchanged is untested.

**Q5 — `tar_dict()` beyond the toy pipeline.** Not run: branching, parallel
workers, functions in a package namespace, Windows. `crew` workers do not see
the dictionary `tar_dict()` attaches.

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

**Q9 — When the scanner and Pandoc disagree.** A re-wrap can leave a line at
the start of a line inside an arm that Pandoc cuts a paragraph at: a closed
fence, a lone line of `-` or `=`, a definition line (2.10.5). At knit time the
scanner still resolves the span, and Pandoc's tree cuts it. The span is still
counted, so the gate sees no removal; `block-start` fails a file in that
state, naming the line. By default it finds these from the source text with no
Pandoc; the comparison of the unmasked tree with the masked one runs only under
`reader = "pandoc"`, and its cost to the gate (Q11) is not measured.

**Q10 — A late abstract in a book.** In a book's docx, a chapter's late
`abstract:` becomes the abstract of the whole book (1.10.9).

**Q11 — The gate's time.** With the stand-in scanner, a commit of five
chapters took about nine seconds, most of it in R code scanning and in a
paragraph matcher the hook no longer runs. The cost follows the size of the
files touched, not the size of the change. About one second for a commit that
touches one chapter looks reachable. Whether the cache of 6.1.6 holds the
`HEAD` version of most files, and keeps the book-wide rules of 6.2.4 off
every commit, is not known. No budget is set, and the timings were taken on
a machine under load.

**Q13 — Conditions whose number is the point.** Rule 7.4.7 accepts that
"Removed 5 rows" and "Removed 5000 rows" match. Nine of 58 real messages were
of this kind.

**Q14 — `cite` spans under Typst and LaTeX.** Typst drops a citation's
prefix. PDF through LaTeX was not run.

**Q15 — The ledger in use.** How often a committed ledger conflicts on merge,
and how often the occurrence index shifts (7.1.5, 7.1.6).

**Q16 — Plain `knit()` with the hooks installed.** Settled in the build:
rule 2.1.7 now gives the cause and the remedy.


**Q17 — The hook under other git operations.** On `git commit --amend` the
hook compares with the commit being amended, so a removal made in the
original commit is no longer counted, and the original trailer may no longer
match. How it behaves on a merge commit, and whether `git rebase` and
`git cherry-pick` run it at all, is untested.

**Q18 — Netting.** Two limits are accepted: a finding removed and the same
text added elsewhere in one commit nets to zero (6.2.6), and a removal and an
unrelated addition in one commit net out (6.3.6). How often either hides
something in a real history is not known.

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
  render to the same text. The fixtures include the three writer outputs of
  §18 for 1.5.12: a separator saved as `\|`, a doubled `||` saved as `\|\|`,
  and `##` saved as `\##`.
- **Attribute forms.** Each fixture is also run with its attribute blocks
  reordered, unquoted, and with the first letter of each key capitalised, and
  must render the same text (1.2.10). With its values single-quoted it must
  give the construct error of 1.2.3.
- **Text spans.** `[results]{.strong}`, and the same with each text class,
  prints the class's effect; `[1234]{.num}` passes through and is listed by
  5.3.3; `.Num` on a construct is listed with `.num` as the nearest name.
- **Governors.** A governor with no formatter class prints 0, 1, 2 and 3 as
  "0", "1", "2" and "3" and takes the arm for each; a value that is not whole
  prints to the default digits; the setting of 9.1.2 changes the class
  (1.5.18).
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
  filter. A `.qmd` that holds constructs and no R chunk, and has no
  `engine: knitr`, fails in the `pre-render` script, naming the file
  (2.5.4); with that script absent, the filter fails it (2.5.3). So does a
  value written with a capital `R`.
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
  succeeds, one that fails, and one that is killed (Q3). In a frozen project,
  `verify(files = )` passes when the named files pass (8.2.1). A tolerated
  finding is counted and fails nothing until its rule is made strict (8.1.2,
  8.1.3). `verify(static = TRUE)` renders nothing. `verify(since = )` fails on
  a finding added and reports, without failing, a removal with no trailer
  (8.2.2). Under rmarkdown each `.Rmd` is rendered once (8.3.3). In draft
  mode it refuses to run (8.1.5).
- **Names.** Every weft name changed by one edit, where the result is not
  another weft name, is listed by the lint of 5.3.3 with a weft name as the
  nearest. A key changed only in letter case is the key itself (1.2.10), and
  is not listed. Pandoc's names and the project's expected names are not
  listed.
- **The gate.** Scripted commits against a fixture repository, each with a
  known answer. A construct error fails whether or not `HEAD` held it. A
  finding already in `HEAD` passes; the same finding added fails; one moved
  to another file passes. Removing an anchor that an unstaged chapter cites
  fails (6.2.4). A removal fails with no trailer and with a wrong count,
  and passes with the right one; the report lists what is gone with its
  `HEAD` line and prints the trailer line. A value turned into a span, a
  variable renamed in forty expressions, a bound changed, a paragraph moved
  between files, and a file renamed each pass with no trailer. A trailer on a
  commit that removes nothing is ignored. A new file and a deleted file are
  compared with an empty version. The spike's 72 scripted edits (§18) are
  kept as a fixture, and edits taken from a real manuscript's history are
  added to them (Q18).
- **Ledger and `changes()`.** A bare value is recorded with the text knitr
  printed. Renders of one document to two outputs with different `params`
  keep two ledgers (7.1.3). A changed expression lists one entry removed and
  one added (7.1.8). `changes()` lists structural changes before the rest,
  and `changes(since = )` compares with the named commit. A new condition is
  an added line and fails nothing (7.4.4); a message whose number changed
  keeps its line (7.4.6). A ratio crossing 1.0 is a reason and a quantity doing
  so is not; the number words are no claim words; an arm that prints nothing
  shows `(prints nothing)`; `print(x, brief = TRUE)` (7.3.9); `ledger: false`
  in the project file and in front matter, each overriding the other (9.1.9).
  The header's reads: the setup chunk, a reader function of the author's, a
  literal `source()` path, a non-literal `store` and the warning when it cannot
  be evaluated (7.2.2); the upstream cache keyed on the store's `meta` file and
  the script (7.4.1).
- **`arms()` and `rehearse()`.** `arms()` lists every arm of every governed
  span in a fixture, nested ones under their arm, with no R run.
  `rehearse()` over three cases reports the arm each span chose in each, the
  arms no case reached, and the failures of a case that fails, and writes
  nothing to the project.
- **Units.** The arithmetic of §18 through `dict`: a ratio prints no unit, a
  product prints "m²", adding kilograms to metres errors, and a check against
  a bare number errors. A quantity prints its unit after a no-break space
  under each number class, once after a collapse, with every number under
  `.pairs`, and as the unit's name after a spelled number or "no". `#` carries it by the same rules. A bare value
  prints the number alone, and warns (4.4.10); a unit typed again after its
  value warns (4.4.24); a project unit with a name and no symbol prints by name;
  `mm/hr` prints as typed (4.4.20); a lone zero on a ladder (4.4.23); a chain of
  governed spans (1.5.20). A dictionary that names `PSU` or `sites` reads,
  and so does one with a compound unit such as "CFU/100 mL".
- **Unit names and forms.** Each shipped name, both spellings, the database's
  names with `_` as a space, prefixes by symbol and by name, the same-unit
  rule, compounds, the plural sources and every no-name case with its message,
  through `fmt_unit()` and `.uname`. Each unit class and `unit_form =` on each
  function that takes it; plurals at 0, 0.5, 1, 1.0 and −1 and in each
  collapse; `#` in `n`, `sign` and `list` spans and in `plural()`; the
  attributes `unit`, `unit_form` and `units` and a chain of formatter
  functions; every construct error. `unit_form` and `units:` in `_weft.yml` and
  in front matter: the nearest wins, the per-unit merge, `symbol:`, `space:`,
  the default spaces, registration, every `units:` problem in one error, and
  `lang` `en-US` and another. `display:` on a dictionary entry: the conversion
  when read, its three problems, the `entries` column, `print()`, `unit=` over
  it and `units::drop_units()`. Which name a unit gets, in each of the four
  steps of 4.4.17, and a technical or empty database name as a no-name error;
  `#` over every class and key of a span; a collapse over spelled numbers; `.cap`
  on a symbol and on a name; `.ord` on a quantity; `space:` on a name; a unit
  with no symbol under `symbol`; a conversion by inversion refused and one
  between quotients allowed, by `unit=` and `display:`; each unit `u()` and
  `read_dict()` refuse, alone and in a compound, with the message; each `units:`
  key problem; the table kept outside a knit cleared by a failed read.
- **Unit ladder.** Every example of 4.4.23 through `weft_str()` and the
  functions: the window's edges with and without `digits`; zero, negatives, a
  gap, the order, the fallback both ways; the vector rule (a tie, no fit, `NA`,
  length zero, `trunc`) under every collapse class and uncollapsed; `#` in `n`,
  `sign` and `list` spans and `n="."`; back-references; names and plurals; the
  unit classes and `unit_form`; the zero rule, its advice and `digits` silencing
  it; mode `si`; the attributes `unit`, `unit_form` and `units`; `unit_picked`;
  the same value twice in a document and across two knits; every error from a
  construct and from a function, with the rung named; a ladder of one on the
  rows of `unit=` above; `fmt_unit()` with a ladder and with a string. The
  scanner, with no R run: an empty and a repeated rung; `\|` read as `|` in a
  pipe-table cell and an unescaped `|` there an error, in a value and in a span;
  `\|` outside a table accepted; `\` elsewhere in `unit` and in any other key
  still an error; a `|` in `unit` leaving a span's arm count alone. `display:`
  as one unit, and as a `|` string and a list of more than one item refused with
  the advice to write the ladder in a `unit` key, a list of one item accepted,
  every problem in one error with the old ones, `unit=` over a `display:`,
  `dict_local`, and the glossary printing the held unit.
- **Default units.** Every example of 4.4.20 to 4.4.22 in each mode: the token
  kept as written, by `units::deparse_unit()`, through `u()`, `read_dict()`,
  `display:` and `unit=`; the twin conversions refused and the conversions
  within a member and to the SI definition allowed; `unit_defaults()` (its
  columns, its rows, `redefines` true for exactly the six, `file`, registering
  nothing); each redefining row, `ppm` and `ppb`, `NTU`, `PSU`, `CFU`, `MPN`
  and the two `/100 mL` rows; mode `weft`, `si` and `weft` again in one session,
  each knit right and outside a knit after each, a failed read returning to
  `weft` and removing what it installed (also a row whose install fails), a second read and a second `u()` changing nothing; a project row over
  a default, per field, a document's over a project's, `false`, a project's
  `is` in each of its forms, in file order and by a forward reference; each
  new `units:` problem in one error with the others; each refusal in `u()`,
  `unit=` and `read_dict()`, alone and in a compound, with its message; a unit
  installed by someone else, accepted, or disabled with a `weft_unit_warning`
  while every other unit works and using it a `weft_unit_error`, checked again at
  each read. `Ci` and `rem` among the twins, a project unit defined as a twin,
  and `of_n()`, `about()` and `claim()` over twins. `is:` on a key that `units`
  already reads, in any letter case (`km`, `Bags`) and on one weft installed
  (`is: 1 zzr`); a `name` with no `plural` over a default row; a document's row
  that drops a definition; the names of `VA` and `Bd`; the no-break space in
  `CFU/100 mL`; `weft_str()` outside a knit with a bad configuration. A unit written before the
  number in each collapse class, `trunc`, `.pairs`, the list classes, `#` in
  `n`, `sign` and `list` spans, `.nounit`, `.strong`, `.cap`, `space: false` (the
  symbol only, before the unit as after it) and a compound, a negative number,
  `.no` as a value error, and the attribute `unit_before` through a chain. Three tests need a
  fresh R session: loading weft leaves `pH` a picohenry until the first unit is
  read, a `pH` installed before weft's first use is accepted, and an `mph`
  installed as another unit is the `weft_unit_error`.
- **Dictionary tooling.** `term` and `avoid` read and trimmed, the `entries`
  columns, every problem of 4.7.3 and 4.7.4 one dictionary each and two in one
  file, `avoid` in `dict_local`. `use_dictionary()`: an empty folder, a second
  run, an existing `dict.yml` with and without a schema line and with another,
  an altered schema, a subfolder of a project, a bad `path`, a link in place of
  either file, a folder in place of `dict.yml`, a folder that cannot be written
  to (no "Wrote:" and a `weft_tool_error`), silence under `suppressMessages()`,
  the starter read as no keys and, uncommented, as two. The schema: valid
  draft-07 JSON, checked by a test helper that interprets only the keywords the
  schema uses and fails on any other; the dictionaries that both it and
  `read_dict()` accept, those both refuse, those only `read_dict()` refuses, the
  two exceptions of 9.3.4, and an empty or null optional field, a one-item list
  where text is wanted and a definition of only a no-break space. The glossary
  exactly, with `values` and `sort` off, an empty dictionary, a `dict_local`, a
  project with and without `dict.yml`, the `_weft.yml` in force outside a knit,
  a value written `0.50` and the attribute `decimals`, a `_weft.yml` that cannot
  be read, a `display` conversion, a term and a definition with a
  blank line, a paragraph below the chunk, and a render under rmarkdown.
  `dict_vale()`: the rule exactly, the messages, a relative `path` that climbs out
  and an absolute one outside the project, a second run, `.vale.ini` with
  the style listed, with `Weft-old`, and absent, an authored file at `path`, a
  dictionary with no `avoid` and the file present, removed only for the
  project's own dictionary, a `dict_local`, a bad `level` and `path`, a link, a
  folder, escaping, and the order. `dict_seed()` over a fixture project:
  the rows exactly, `skipped`, `paths`, `min_files`, a nested code fence, a
  chunk header that holds `eval=FALSE` in a caption, that nothing is evaluated,
  and each error.
- **Decision pointers.** The setting in each form and each wrong one, including
  `GitHub`, in `_weft.yml` and in front matter. With a recording `fetch` and no
  network: no pointers and no call, every status of 4.5.4 and its detail, the
  token reaching `fetch` and appearing in no detail, `GITHUB_PAT` over
  `GITHUB_TOKEN`, no call after a refusal, a `fetch` that throws or returns
  something malformed, a 410, `#12`, `012`, `0x1F` and a pointer of 11 digits and the numbers 2147483647 and 2147483648,
  `resolved` `NA` exactly when the detail starts `could not check: `. The
  remote of a temporary repository in each form `parse_github_remote()` takes,
  one outside the project, none, and another host; `github_fetch()` with
  `curl` absent. The glob with `{id}-*.md` and `{id}*.md`, a folder that does not
  count, a pointer that holds `..`, `~` or a pattern character, a root whose
  path holds `[`, and a link to nowhere. The function route with `TRUE`,
  `FALSE`, `NA`, a failure, another value, `pkg::fun`, a bare name that is
  found only in the global environment, and a function that cannot be found.
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

**Stage 1 — the prose core.** Usable alone. It is built in six steps. Each
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
  lists; `n="."`; the default governor class; keys in any letter case
- `claim()`, `plural()`, the `fmt_*()` functions, `glue_vec()`
- pass-through of classes and keys; `.strong`, `.em`; text spans
- collected failures, including the record made by a failed check in chunk
  code (2.4.4), missing values and value-dependent errors; the marker; exact
  positions; draft mode; `_weft.yml`
- the condition log from the `evaluate` wrapper and from values in prose, the
  cache replay, and the severity list
- the end-of-document check, the `weft-check` filter and the `pre-render`
  check; the `post-render` report for a book and the freeze stamp (2.6.6,
  2.9.2, 2.9.4); `use_quarto()`
- activation from front matter and from a setup chunk, with `engine: knitr`
- the syntax fixtures, the scanner and masking tests, and the pinned-internals
  tests

The trials on two real documents (`dev/field-notes.md`) moved the first two
items of 1c ahead of 1b: captions, `weft_str()` and front-matter constructs
were built straight after the kernel.

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

*1e — rehearsal.*

- `arms()` and `rehearse()` (§3.7). `rehearse()` belongs to the harness (§17)
  and is built here because it needs only the core's record, and a dynamic
  report needs it before anything else in the harness.

*1f — warnings, lists and house style.*

- warn-level checks: `claim(level = )`, the warnings report, and `last_knit()`
  exported (2.6.10, 3.7.5)
- the `list` key on a span and the `none` key on a value (1.5.19, 1.4.14)
- the house-style settings `thousands_from` and `serial_comma`, and `.p` to
  three decimals below 0.1 (1.4.15 to 1.4.17)
- the space rule for an empty arm (1.5.20)
- the report for a number that prints as zero (2.6.11)

**Stage 2 — dictionary and ledger.**

- `dict`, `read_dict()`, `dict_local`, the schema, the generated glossary,
  the pointer resolver, `dict_vale()`, `use_dictionary()`, `dict_seed()`
- quantities as `units` objects, `u()`, registering unknown units, and the
  printing of any `units` value (§4.4)
- `tar_dict()` and `tar_dict_deps()`
- the ledger: records, its key, a file per output, three states; the
  committed condition log; `changes()`, which lists tier-2 findings once
  stage 3 has built them
- conditions read from `tar_meta()`, which needs the ledger's record of the
  targets each chapter reads

**Stage 3 — static lints.**

- the scanner over source files, chunk-option captions and `weft_str()`
  strings; the masked Pandoc read; the citation pattern
- numerals, with the exemptions, `label_seed()` and `.weft-literal`; literal
  values; checks that cannot fail (3.1.6); construct errors; marker spans and
  citations; cross-references; hygiene; figure presence
- the tier-2 lints (claim words, long guards, constants and formatting calls
  in values, the three warnings of 5.3.3, unreferenced anchors), which
  `changes()` lists

**Stage 4 — the gate.**

- findings judged against `HEAD`, and the construct count with its trailer
  (§6.2, §6.3)
- the `commit-msg` hook, its cache, and `use_hooks()`
- `verify()`, with the freeze sequence, the totals and strict rules, and its
  `files`, `since` and `static` arguments
- `use_ci()`; `use_agent_docs()` and the skill; `use_weft()`; `status()` and
  the version check (9.5.3, 9.5.4)

Stage 2 comes before stage 3 because the numerals rule sends constants to the
dictionary: the lint cannot be switched on until there is somewhere for them
to go.

**Planned, after stage 4.** Neither is in a stage.

- `drange()` and `dur()` (3.5.6): both need calendar arithmetic and a decision
  on date order.
- Plural rules for languages other than English (Q6).
