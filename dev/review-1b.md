# Review of stages 1b and 1d (behavioural)

Reviewer: an independent agent, working from the snapshot `snap-d`, installed
into a private library. Every finding below was reproduced by running a case
or rendering a document. Documents were rendered with `rmarkdown::render(...,
md_document(variant = "markdown"))` (or `knitr::knit` where it says "knit"),
and with `quarto render --to markdown` where it says Quarto. "Draft" means
`WEFT_DRAFT=1`. Each document starts with the usual setup chunk calling
`weft::weft_setup()`. The variables are defined in that chunk.

Checked and found right (so not listed): `sign` with 2 and 3 arms, zero judged
as printed under `.pct`, the default class and `digits` (1.5.10), a bound
(1.5.17), `n="."` inside `sign` (1.7.2), `.word`/`.count`/`.no` on `sign`, `NA`,
vector and string governors; back-references with and without their own
formatters (1.7.8, 1.7.9), `sign="#d"`, ids on governed spans, ids in chosen
and unchosen arms, references above their definition, the same id in several
documents in one session, ids never emitted (pass-through included); Quarto
`{{< include >}}` (ids defined in an include, duplicates across an include and
its parent, error lines in the right file, even when the line numbers collide);
`.p` at the boundaries; `lookup()` on factors, by label; `NA` never reaching
`TRUE ~`; `cite` in both forms with locators, prefixes, `;`, `-@`, `@{}`, the
project bibliography from `_quarto.yml`, CSL JSON/YAML, inline `references:`,
citeproc output and the reference list (html and markdown); `about()` at and
around the tolerance; `trunc` under `.and`/`.or`/`.pairs`; and 1.6.8 for the
value classes and phrase functions. **Stock parity holds:** a 60-line document
that uses only the 1a/1c names renders byte-identical before this stage
(commit `c1e6d16`) and after it, under rmarkdown (markdown and html) and under
Quarto.

## Findings

### 1. `clamp()` prints its bound at the default digits: `< 0.0` — silent wrong

```r
clamp(0.005, floor = 0.01)        # "< 0.0"   number 0, relation "<"
clamp(-0.004, floor = -0.001)     # "< 0.0"
fmt_range(clamp(c(0.001, 5), floor = 0.01))   # "< 0.0–5"
```
In a document, `` `r clamp(0.004, floor = 0.01)` `` prints "Values below \< 0.0
were set aside". The bound is formatted by `.num` at the default one decimal
place, so a floor of 0.01 prints as "0.0" and the record's number becomes 0.
Rule 3.5.1 gives "< 0.01" as the output. The bound has to print as written (or
at least to enough digits to tell it apart from zero). Every small floor, which
is the reason `clamp()` exists, is affected.

### 2. A number-stage class after `clamp()` drops the bound and its relation — silent wrong

```r
fmt_pct(clamp(0.005, floor = 0.01))   # "0.5%", relation "="
fmt_pct(clamp(0.5, ceiling = 0.4))    # "50%",  relation "="
fmt_num(clamp(0.005, floor = 0.01))   # "0.0",  relation "="
```
Markup does the same: `` `r clamp(x, floor = 0.01)`{.pct} `` with x = 0.005
prints "0.5%", and `{.sci}` prints "5 × 10^−3^". The design says "A following
formatter class keeps the relation", and 3.5.4 says that `clamp()` sets the
relation. The cause is the 1a ruling that a number-stage formatter re-formats
the `raw` value, and `clamp()` keeps the unclamped raw value. The text should
read "< 1%" and "> 40%". The value the author clamped away comes back, with
nothing to show for it.

### 3. A wording or number class on a phrase function's result replaces the phrase — silent wrong

```
`r of_n(3, 7, "site", "sites")`{.word}    →  three
`r of_n(3, 7, "site", "sites")`{.num}     →  3
`r of_n(3, 7, "site", "sites")`{.pct}     →  300%
`r of_n(0, 7, "site", "sites")`{.no}      →  no
`r ci(2.1, 1.3, 2.9)`{.num}               →  2.1
`r ci(2.1, 1.3, 2.9)`{digits="2"}         →  2.10
```
(rmarkdown, draft or not: no failure at all.) The phrase loses its interval or
its "of the 7 sites" without a word. The same classes elsewhere are not
consistent: `` `r pm(2.1, 0.3)`{.word} `` is a value error that quotes "2.1 ±
0.3", and `` `r about(0.49)`{.num} `` is a value error. Rule 1.4.1 says stage
ii acts on each element *as printed by stage i*, and 1.4.12 judges a wording
class on the number as printed. "3 of the 7 sites" is not a whole number, so
`.word` should be a value error, as it is for `pm()`. A number class should
not quietly turn a `weft_text` phrase into its record's number.

### 4. A list formatter in an indented block breaks out of the enclosing list — silent wrong

```
1. First

    `r v`{.ol}

2. Second
```
With v = c("alpha", "beta") this renders as `1. First  2. alpha  3. beta  4.
Second`. The emitted lines are not indented, so the nested list joins the
outer one and renumbers it. The value is alone in its paragraph, which is
legal by 1.4.6, and no error or marker is raised. The same holds for `.ul`
and `.dl`.

### 5. A list value alone in a list item or a block quote is called "not alone in its paragraph" — wrong error

```
- `r v`{.ul}

> `r v`{.ul}
```
Each is a construct error: "`.ul` makes a block, so the value must be alone in
its paragraph (rule 1.4.6)". Each *is* alone in its paragraph. Refusing may be
the safe thing, given finding 4, but the message is wrong and points the
author at the wrong fix. Either support these cases, indenting or prefixing
`> ` on each emitted line, or give a message that names the real limit.

### 6. Text classes and `trunc` on list formatters produce broken or ignored output — wrong output

The document was rendered with knit:
```
`r v`{.ol .strong}    →  "**\n1. alpha\n2. **beta**\n3. gamma *x*\n**"
                          (md: "** 1. alpha 2.** beta **3. gamma *x***")
`r v`{.ul trunc="2"}  →  all three items, trunc silently ignored
`r v`{.ul .cap}       →  nothing capitalised (the text starts with "\n-")
`r v`{.ul .a}         →  value error quoting the whole list
```
None of these is a construct error, and each prints something wrong or does
nothing. See also lettered item I.

### 7. Ids across an R Markdown child document: false errors and a missed duplicate — wrong error

`child2.Rmd`: `` Child defines `r k`{#cid} here. ``
`par2.Rmd`:
```
Para.

```{r, child="child2.Rmd"}
```

After child [#]{n="#cid"}.
```
The render (not draft) stops with: `weft: par2.Rmd:15: The id #cid is not
defined in this document (rule 1.7.10)`, yet the output already reads "After
child 3": the runtime resolved the reference. The reverse fails the same way:
a child that refers to an id from the parent's earlier prose gets "not defined
in this document". And when the parent and the child both define `#cid`, no
duplicate is reported (`Para `r k`{#cid}.` plus the child above renders with
no failure at all). A knitr child is part of the same document (1.7.10 rules
out only another *chapter's* ids). Quarto includes get this right.

### 8. Ids in captions: the static check and the runtime disagree — wrong error

```
Prose `r k`{#a}.

```{r c1, fig.cap="Cap [#]{n=\"#a\"} and `r k`{#b}"}
plot(1)
```

Then [#]{n="#b"}.
```
In draft mode the caption prints "Cap 3 and 3", so the reference to `#a` was
resolved. Even so, the report has a construct error on line 12 for that same
caption reference ("The id `#a` is not defined in this document"; the expr
column reads "a `n` construct"), and another for the prose `[#]{n="#b"}`. A
non-draft render stops at the first of these. Separately, a caption that
repeats a prose id (`#x` in prose, then again in `fig.cap`) is not reported as
a duplicate. Only the *second prose* use is. Captions should share the
document's id space (1.7.5, 1.7.10), both ways.

### 9. A reference to an id whose value failed is reported as an undefined id, and stops the render — wrong error

```
A `r nosuch`{#q} then [#]{n="#q"}.
```
Not draft: the render stops with `weft_construct_error`: "ev.Rmd:9: The id `#q`
is not defined before this span, or its arm was not chosen (rule 1.7.10)". The
real cause, the "object 'nosuch' not found" failure, is in `last_knit()` but
not in the message the author sees. The id *is* defined before the span, and a
construct error by definition is found from the source (5.3.1). It should be a
collected failure that follows from the first one (or the reference should be
skipped silently, as unevaluated).

### 10. `.bib` reading takes keys from `@comment` blocks and from inside field values — silent wrong

```bibtex
@comment{This mentions @article{commented2020, title={x}} inside a comment}
@article{smith2020,
  title = {Smith with an embedded @misc{fieldkey2020, x} in a field}, ...}
```
`[x]{cite="@commented2020"}` and `[x]{cite="@fieldkey2020"}` pass the knit check,
and Pandoc then warns "citation commented2020 not found" and prints
"(**commented2020?**)". The regex runs over the raw text and only skips the
entry types `comment`/`string`/`preamble`, not their contents. Rule 1.8.5 says
every key must resolve.

### 11. Non-ASCII citation keys: false failure at knit, false construct error in the bare form — wrong error

The bib holds `@misc{ké2021, ...}`. Then `[x]{cite="@ké2021"}` is reported as
"the key `k` is not in the bibliography", although Pandoc resolves it (output
"(*Unicode* 2021)"). The bare form `[x]{cite="ké2020"}` is a construct error
("is not a key"), while the scanner accepts `@ké` in the citation form. Pandoc's
key grammar allows Unicode letters. Both the key-extraction regex and the
bare-form check are ASCII-only.

### 12. A `.weft-literal` div inside a block quote is not seen — wrong output

```
> ::: {.weft-literal why="in quote"}
> Quote div `r k`{.word}.
> :::
```
The output keeps `why="in quote"` (1.8.11 says the `why` is removed), and the
same div with no `why` is not a construct error: `scan_text()` returns no row
for it (1.8.10). Divs nested in a list item or in another div are handled.

### 13. A literal div written in Pandoc's bare-class form is not recognised — wrong error (missed)

`::: weft-literal` (no braces, and no `why`) has no row in `scan_text()`, so the
missing `why` is not a construct error. The same goes for `::: {.weft-literal
why="a"} :::`, which has trailing colons. Both are legal Pandoc fences, and
Pandoc's own markdown writer emits the first form, as the output of this very
package shows. After one round trip through the visual editor or Pandoc, the
literal therefore drops out of the lint.

### 14. A literal div or span loses its `#id` — wrong output (minor)

`::: {#did .weft-literal why="with id"}` renders as `::: weft-literal`, and
`[y]{.weft-literal why="ok" .smallcaps #lid}` loses `#lid`. Rule 1.1.6 says
the runtime "does one thing" with a literal: it removes the `why`. A div id
is a Pandoc anchor that the author may link to.

### 15. `.a` on a text or `cite` span is not a language error — silent wrong

With `lang: fr`, `[3 sites]{.a}` renders "a 3 sites" with no error, and
`[x]{.a cite="@a"}` gets only a value error. The same document correctly gives
the 1.6.8 construct error for `` `r k`{.a} `` and `[haut | bas]{sign="k" .a}`.
Rule 1.6.8 says `.a` under a `lang` weft does not ship is a construct error
from the source, wherever it appears.

### 16. `.a` refuses negative numbers and emphasised numbers — wrong error

```r
fmt_a(-8)          # weft_value_error: "−8" is neither a number nor a number word
```
`[**8**]{.a .cap}` is a value error too ("**8**" is neither), although `.cap`
skips emphasis marks by design. Rule 1.4.5 restricts `.a` to numbers and
number words, and "−8" is a number ("a minus eight").

### 17. `.cap` skips `*`/`**` but not `_`, link brackets or `~~` — wrong output

```r
fmt_cap("_hi_")        # "_hi_"
fmt_cap("[link](u)")   # "[link](u)"
fmt_cap("~~del~~")     # "~~del~~"
```
`[_italic start_]{.cap}` renders "*italic start*", uncapitalised. The design
says `.cap` skips leading markdown emphasis marks, and `_` is one.

### 18. `.range` prints the same number twice when the ends differ in wholeness — wrong output

```r
fmt_range(c(1, 1.04))   # "1–1.0"
fmt_range(c(3, 3.02))   # "3–3.0"
```
As an `n` governor, `[# site | # sites]{.range n="c(1, 1.04)"}` prints
"1–1.0 sites". Each end is formatted alone, so a whole end prints with no
decimals and the other end with one. Rule 1.4.4 prints one number when both
ends print the same, and these two print the same number. Both ends should
share one precision, or the comparison should be made on the number.

### 19. Sentence starts that are missed — silent wrong under `sentence_start_fail: true`

With `sentence_start_fail: true`, none of these is listed or fails:
```
End. [three]{.strong} strong text span.            (a text span)
End. [`r w`]{.cap} capped span.                    (w = "x": prints "X", fine)
End. [`r k`]{.cap} ...                             (prints "3": not listed)
End. [`r k`]{.weft-literal why="x"} literal.       (a value inside a literal)
End. [x]{cite="@a"} cited.                         (a cite span)
S18 **Bold.** `r k` after bold sentence.           (sentence ends inside emphasis)
Term
:   `r k` definition                               (start of a definition block)
```
Rule 5.10.1 covers "every value, bare or not, and every span". Values nested
inside text, literal and `cite` spans are not looked at, and a full stop
followed by a closing `**` hides the sentence end.

### 20. Sentence-start failures leave no marker; an `if` span is reported by its condition — wrong output (minor)

With `sentence_start_fail: true` and draft mode, the failures are in the
report but the output text carries no `<<weft: ...>>` marker (2.6.2 says every
recorded failure leaves one). For `[`r k` items | none]{if="TRUE"}`, the
report's expression is `TRUE` rather than the phrase.

### 21. `.p` at two decimals turns a significant p into "p = 0.05" — silent wrong (design decision)

`` `r 0.046`{.p} `` prints "p = 0.05", with relation "=". In the trial report,
`[significant (`r pval`{.p}) | not significant]{if="pval < 0.05"}` with
p = 0.046 reads "significant (p = 0.05)". Likewise 0.0499 prints "p = 0.05".
The decision in `dev/design-1b.md` ("two decimals from 0.01") causes this. A
reader takes "p = 0.05" as not below 0.05. Either three decimals below 0.1 or
a rule never to round onto 0.05 would avoid it. Raised for Robin, not re-ruled.

### 22. `brk()` and `lookup()` accept inputs that give silently wrong phrases — silent wrong (low) / wrong error

```r
brk(. < 10 ~ "small", TRUE ~ "big")("9")    # "big": "9" < 10 compares as strings
lookup(c(a = "x", a = "y"))("a")            # "x": a duplicate key is not an error
brk(. < 1 ~ 2)(0)                           # "2": a non-string phrase is coerced
brk(. < 1 ~ c("a", "b"))(0)                 # plain simpleError "values must be length 1"
lookup(list(a = "x", b = 2))("b")           # "2"
```
The design says `brk()` takes formulas "whose right side is a string" and
`lookup()` "a named character vector". A character value from a CSV fed to a
numeric `brk()` gives the wrong phrase with no error.

### 23. `n="#d + 1"` is read as an R comment — wrong error (minor)

`` `r k`{#d} then [one | # many]{n="#d + 1"} `` raises no construct error. At
knit time it is a "no value" failure: "An `n` governor has length zero". The
`#` makes R read the whole value as a comment. By contrast `if="#d"` *is* a
construct error ("does not parse as R: unexpected end of input"). A governor
value that starts with `#` but is not exactly `#id` should be a construct
error that names the back-reference form (1.7.6, 5.3.5). `n=" #d"`, with a
leading space, is accepted as a back-reference.

### 24. A bibliography file that does not exist is silently ignored — wrong error (minor)

The `_weft.yml` holds `bibliography: nofile.bib`. Each key is then reported as
"the key `smith2020` is not in the bibliography (rule 1.8.5)", and the missing
file is never mentioned. The same holds for a missing file named in the front
matter, as far as weft's check goes (Pandoc errors separately).

### 25. Smaller wrong errors in the phrase functions and `clamp()` — wrong error (minor)

- `clamp(NA, 1)` (logical `NA`) is `weft_value_error` "needs a number, not a
  logical", while `clamp(NA_real_, 1)` is `weft_no_value`. By 1.3.4 an `NA` is a
  missing value in either case.
- `clamp(5, floor = 10, ceiling = 1)` prints "< 10" with no error.
- `of_n(2, 3, "site")`, with the plural missing, is a plain `simpleError`.
- `of_n(fmt_num(3), 7, ...)` is a value error ("not a weft_text"), although
  3.4.2 has `weft_text` passed between functions.

### 26. Messages on `sign` spans speak of `n` — cosmetic

A vector, string or `NA` `sign` governor is reported as "An `n` governor must
be a single number … write `length(x)`". A failed `claim()` in a `sign`
governor is quoted by the first arm's source ("rose") while the output printed
"fell". `n` governors do the same (quoting "one" while the output printed "3
many"), which comes from 1a. Under `lang: fr`, `trunc` is called "The class
`trunc`". `trunc="0"` says "must be at least 1", while `trunc="-1"` says "must
be a whole number, not negative".

### 27. `date_format` expansion by hand — cosmetic

`"%%B is %B"` prints "June is June", because the literal `%%B` is expanded too.
`"%A %-d %B"` under `LC_TIME=fr_FR.UTF-8` prints "lundi 3 June": the weekday
follows the locale while the month is forced to English.

## The rule is ambiguous or silent

A. **A value with only an `#id` or only pass-through attributes, given `NA`.**
   `` `r na`{#r} `` and `` `r na`{.smallcaps} `` print "NA" with no failure,
   although each is a construct (1.1.8). Rule 1.3.4 fails a missing value
   that "reaches a formatter", and nothing formats these. A later
   `[#]{n="#r"}` then fails with "has no printed number".

B. **`.date` under a non-English `lang`.** It prints English month names
   ("3 June 2024" under `lang: fr`), and 1.6.8 does not list `.date`.

C. **A reversed `.range` (`c(5, 3)`)** prints "5–3". Nothing says whether that
   is an error. The same question applies to `ci()` with `lo > hi` or `est`
   outside the interval, and to `pm()` with a negative `se` ("2.1 ± −0.3").

D. **`.cap` on text that opens with a quotation mark or a bracket.**
   `"quoted"` and `(bracket)` are left alone. Is the "first letter" the first
   character or the first letter?

E. **What counts as a sentence start.** These are listed: after "e.g. ", after
   an ellipsis, after `."` and after `.)`. These are not: a table cell's start,
   and a value that prints "-2". The design's ". ? !" rule gives the first
   group, but an abbreviation is not a sentence end.

F. **1.7.11 and a one-arm guard.** In `[`r k`{#g} m]{if="TRUE"}`, `#g` is not
   visible after the span, although a guard always prints its phrase. The rule
   as written makes this an error.

G. **Two ids in one block** (`` `r 2`{#e #f} ``). The last one wins silently,
   and a reference to `#e` gets "not defined". Is that a construct error,
   like a key written twice (1.2.10)?

H. **`.p` between 0.0095 and 0.01** prints "p = 0.01" (two decimals), though
   the design says "three decimals below 0.01". This is consistent if the
   comparison is made after rounding, but the design does not say so.

I. **Text classes and `trunc` on `.ul`/`.ol`/`.dl`.** Stage iv acts on "the
   final text", which for a list is a block. Nothing says whether `.cap`
   acts on each item, `.strong` on each item, or either is an error, nor what
   `trunc` does to a list (finding 6).

J. **Renderer keys on a `cite` span** (`digits`, `trunc`). They are dropped
   silently. Rule 1.8.7 names only formatter classes as an error.

K. **`cite="email x@y.com"`.** By 1.8.6 this is the citation form with the key
   `y.com`, and the knit check fails that key. Pandoc does not read
   `x@y.com` as a citation at all, so it prints "\[email <x@y.com>\]".

L. **`of_n(0, 1, ...)`** prints "none of the 1 site". The design covers k = 0
   with no special case for n = 1.

M. **A back-reference to an `if` span's id.** `[yes | no]{if="k > 1" #i}` is
   accepted (1.7.5 allows an id on "a governed span"), and only a later
   reference fails, at knit time ("no printed number"). Could this be found
   from the source?

N. **A block value inside a list item or a block quote.** Rule 1.4.6 makes
   it legal. Should weft indent or prefix the block, or is refusing it the
   intended limit (findings 4 and 5)?
