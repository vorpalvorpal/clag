# Review of the stage-1a knitr runtime (reviewer B)

Reviewed: a frozen snapshot of the package (`snap-b`), installed into a private
library. Every finding below was reproduced by rendering a document written for
it, in a fresh R process (`rmarkdown::render(f, rmarkdown::md_document(variant =
"markdown"))`, or `html_fragment()`), or with `quarto render f.qmd --to
markdown`. knitr 1.51, rmarkdown 2.31, Quarto 1.11.9. "Draft" means the render
ran with `WEFT_DRAFT=1`. Line numbers were counted by hand in each fixture.

Every fixture below opens with this setup chunk unless it shows its own:

````
```{r setup, include=FALSE}
weft::weft_setup()
```
````

## What held up

These were attacked and behaved as the rules say. They are listed so that a
later review need not repeat them.

- **Stock parity.** A document with no attribute blocks gave byte-identical md
  and html with and without the hooks, under rmarkdown (on the first render and
  again when served from the cache) and under Quarto (md and html). The
  document had bare `` `r x` `` in a heading, a pipe table and the YAML title;
  inline R in a fenced block, an indented block and an HTML comment; vectors,
  factors, `NULL`, dates, difftime, data frames, `1e-10`, `asis_output`, `I()`
  and `invisible()`; warnings and messages; a plot; `results='asis'`;
  `cache=TRUE`; a bash chunk; `error=TRUE`; `kable`; a tabset; a shortcode; and
  `` `{r} x` `` under Quarto.
- **A realistic report.** It had constructs in headings, list items, pipe
  tables (`\|` arms), block quotes, footnotes (inline ones too), definition
  lists, callouts and divs. Constructs started and ended blocks, sat inside
  link text and touched each other. There were spans nested three deep, values
  inside arms, `n="."` in an `n` span, `.no` with a zero arm, empty arms,
  pass-through classes and keys, and attribute blocks wrapped over a line
  break. All printed correctly.
- **Evaluation order.** Only the chosen arm runs: a `bump()` in an unchosen arm
  never ran. Textual order holds, and a value that assigns is seen by later
  values. `params` work. `knit_print` methods apply to a value with no
  formatter. Data that looks like a span, or holds placeholder characters, is
  printed and never evaluated (2.2.4).
- **Positions in the main file.** LF and CRLF, tabs, a 7-line YAML header,
  identical blocks repeated, multi-line inline code, a span over three lines,
  prose glued to the chunks on both sides, and a failure on the last line with
  no final newline were all reported on the right line.
- **Markers.** The 2.6.8 texts were right, and so were their places: after the
  printed text for a failed claim (also inside a chosen arm and three levels
  deep), and in place of the construct for no value, a value error and a
  construct error.
- **Session hygiene.** In one session, documents were rendered in a loop: plain,
  weft, failing, weft, crashing for a non-weft reason, weft, then plain twice.
  Every weft document resolved, and every plain document was byte-identical to
  a fresh-session render. `weft_setup()` called twice did no harm. An author's
  `inline` hook and `opts_hooks` still applied. After the loop the search path
  had `weft:functions` just above `package:base`. After a crashed knit,
  `claim()` in plain R stops cleanly and its message carries none of the
  crashed document's report.
- **Configuration.** `_weft.yml` at the project root was found from a document
  two directories down, and the document's `weft:` key overrode it setting by
  setting. `lang: en-AU` is English.
- **Conditions.** A warning or message from an inline value is logged with its
  `file:line` and does not reach the document.
- **Children.** `knit_child()` given an `envir`, and called in a loop, resolved
  its constructs against the right values.

## Findings

### 1. Constructs and bare inline values ignore `root.dir` (parity break; silent wrong)

`sub/doc.Rmd`, with `../other/data.csv` present:

````
```{r setup, include=FALSE}
weft::weft_setup()
knitr::opts_knit$set(root.dir = "../other")
```

Bare: `r basename(getwd())`. Value: `r basename(getwd())`{.foo}.
Guard: [data is there]{if="file.exists('data.csv')"}.
````

Rendered with rmarkdown. weft prints `Bare: sub. Value: [sub]{.foo}`, and the
guard fails with `file.exists('data.csv') was FALSE`. Stock (the same file
without `weft_setup()`) prints `Bare: other.`

**Rules:** 1.3.1 and 2.2.5 (a bare value prints as stock prints it), and 2.2.3
(a construct sees the environment a stock inline expression would).
`root.dir` is a common setting (`here::here()`), and this is a silent wrong
answer for any value or condition that reads a file. The cause, read in the
code after the render: knitr evaluates inline code inside `in_input_dir()`,
but weft evaluates everything later, from the `text` hook, which runs outside
it.

### 2. A vector with no collapse class prints its elements run together (silent wrong)

```
Num `r c(1.5, 2)`{.num}; word `r c(1,2)`{.word}; pct `r c(.1,.2)`{.pct};
bare `r c(1.5, 2)`; strong `r c("a","b")`{.strong}; foo `r c("a","b")`{.foo}.
```

Output: `Num 1.52; word onetwo; pct 10%20%; bare 1.5, 2; strong **a, b**; foo
[a, b]{.foo}.`

"1.52" reads as a single number. Stock knitr joins an inline vector with
`", "`, and weft itself does so for a value that has only a text class or a
pass-through class.

**Rule:** 1.4.10 says "prints its elements run together, as stock knitr
prints an inline vector". The two halves of that sentence disagree (see
ambiguity A). Whichever reading wins, the stock reading or a construct error,
"1.52" is a wrong number printed with no warning.

### 3. An error in bare inline R is reported at the wrong line (wrong position)

```
Line five `r undefined_thing`.

Line seven `r 1`.

Line nine `r 2`.
```

Here "Line five" is on line 5 of the file. weft gives `Quitting from err.Rmd:9-9`
followed by `object 'undefined_thing' not found`. Stock gives `Quitting from
err0.Rmd:5-5`.

**Rules:** 1.1.8 (a bare value keeps stock behaviour) and 2.7.1. The cause:
knitr's position is the last inline code it parked in the block, because weft
evaluates only after knitr has moved past all of them. Every bare-value error
in a paragraph with several inline expressions names the wrong line.

### 4. A child knitted more than once reports lines past the end of its file (wrong position)

`child2.Rmd` (5 lines):

```
Intro line one.

Claim on line three: `r claim(v, . > 2)`{.num}.

Line five `r v`{.num}.
```

The parent knits it twice:

````
```{r, results='asis', echo=FALSE}
for (i in 1:2) { v <- i; cat(knitr::knit_child("child2.Rmd", quiet = TRUE)) }
```
````

The report gives `child2.Rmd:3` and then `child2.Rmd:7`. The second line is
past the end of a 5-line file.

**Rules:** 2.7.1, 2.7.2 and 2.1.5. The search cursor for the child's file is
kept from the first knit, so the second knit cannot find its block and falls
back to the cursor. Knitting a child in a loop is the standard way to template
sections.

### 5. Failures in `knit_child(text = …)` are placed at an unrelated line of the parent (wrong position)

````
```{r, results='asis', echo=FALSE}
for (i in 1:2) cat(knitr::knit_child(text = c("", "Section `r i`: value `r claim(i, . > 5)`{.num} and [# x | # xs]{n=\"i\"}.", ""), quiet = TRUE))
```
````

Both failures are reported at `doc.Rmd:2`, which is the `weft::weft_setup()`
line of the setup chunk.

**Rule:** 2.7.3. A text child has no file, so its position should be relative
to the block, or the chunk should be named. It should not be a real-looking
line of the parent.

### 6. Quarto: a nested include in a subdirectory throws off every later position (wrong position)

Quarto resolves an include path against the main document's directory, not
against the including file. With `deep/b.qmd` written relative to
`parts/a.qmd`, Quarto stopped with `could not find file …/inc/deep/b.qmd`. So
the working form is:

```
doc.qmd:             parts/a.qmd:                         parts/deep/b.qmd:
  …                    Part A line 1.                       Deep B line 1 `r claim(v, . > 6)`{.num}.
  Main line 11 claim   (blank)
  {{< include          Part A claim line 3 `r claim(v, . > 5)`{.num}.
    parts/a.qmd >}}    (blank)
  Main line 15 claim   {{< include parts/deep/b.qmd >}}
  {{< include          (blank)
    parts/a.qmd >}}    Part A line 7 [x]{if="v > 5"}.
  Main line 19 claim
```

The report gave `doc.qmd:11` and `parts/a.qmd:3` correctly. After that it gave
`parts/a.qmd:5` (should be `parts/deep/b.qmd:1`), `doc.qmd:14` (should be
`parts/a.qmd:7`), `parts/a.qmd:1` (should be `doc.qmd:15`), then
`parts/a.qmd:5`, `parts/a.qmd:7`, `doc.qmd:34` and `doc.qmd:37`. The last of
those should be `doc.qmd:19`, and `doc.qmd` has only 19 lines.

**Rule:** 2.7.4. weft's `expand_includes()` resolves against
`dirname(path)` of the including file, so it does not find the nested include.

### 7. Quarto: an include whose path is quoted is not mapped (wrong position)

```
{{< include "_p.qmd" >}}
```

The include is on line 10 of `doc.qmd`, and `_p.qmd` has a failing claim on its
line 3. The report gave `doc.qmd:12` (should be `_p.qmd:3`) and `doc.qmd:15`
(should be `doc.qmd:12`). Quarto accepts the quoted form. weft's pattern
`([^ >]+)` captures the quotes, and the file is then "not found".

**Rule:** 2.7.4.

### 8. `knitr::knit_exit()` makes the render fail with a misleading "hooks were not installed" (wrong error)

````
```{r}
knitr::knit_exit()
```

After exit `r v`{.num} and [a | b]{if="TRUE"}.
````

The render fails with two `[unevaluated]` entries at line 18: "It was never
evaluated: the hooks were not installed when knitr reached it (rule 2.5.2);
call weft_setup() above it." The hooks were installed. `knit_exit()` is the
author asking knitr to drop the rest.

**Rule:** 2.5.2, read literally, demands the failure (see ambiguity C). The
message is wrong whichever way that is decided: it names a cause that is not
the cause.

### 9. A failed claim in an `error=TRUE` chunk puts the whole report into the document and the condition log (wrong output)

The document has failures collected in prose above this chunk:

````
```{r err, error=TRUE}
claim(v, . > 6)
```
````

The chunk's printed error in the document is the claim's own two lines and then
the whole collected report: `weft: 7 claims failed …`, every earlier failure
with its path, and `weft: 4 failures …`, about 30 lines. In draft mode, and in
a book chapter (whose output is written, 2.6.6), that text ships. The same text
is the `text` of the chunk's `error` entry in the condition log. Its
normalised form therefore changes whenever any unrelated failure elsewhere
changes.

**Rules:** 2.4.4 (the chunk "prints the error and the knit carries on").
2.4.5 adds the collected failures only to a check that *stops the knit*, which
this one does not. 7.4.3 and 7.4.6 (a log line is keyed on the condition's
own text).

### 10. Under `lang: fr`, English-only constructs in an unchosen arm pass (silent wrong)

```
---
lang: fr
---
…
Unchosen: [`r k`{.word} | rien]{if="FALSE"}.
Unchosen: [[# chose | # choses]{n="k"} | rien]{if="FALSE"} and [`r c("a","b")`{.and} | rien]{if="FALSE"}.
```

Both render, printing `rien`, with no error. The same constructs in a chosen
arm are construct errors.

**Rules:** 1.6.8 (using an English-only class under such a `lang` is "a
construct error, found from the source") and 1.6.4. The check is made in the
resolver at evaluation time, so it depends on the data. The day the condition
flips, the render breaks.

### 11. Quarto: a project-level `lang` is ignored (silent wrong)

`_quarto.yml`:

```yaml
project:
  type: default
lang: fr
```

`doc.qmd` has `engine: knitr` and no `lang`:

```
Mots `r k`{.word} et [# chose | # choses]{n="k"}.
```

Output: `Mots three et 3 choses.` That is English words and English plural
rules in a French document.

**Rules:** 2.1.6 (read Quarto's merged metadata for a project-level `lang`)
and 1.6.5 ("English rules are never applied to another language"). weft reads
only the document's own `lang`.

### 12. Front-matter constructs pass silently (silent wrong)

```
---
title: "T"
abstract: |
  We found [one | many]{if="FALSE"} and `r 3`{.num} sites.
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
output:
  md_document:
    variant: markdown
    preserve_yaml: true
---

Body `r 3`{.num}.
```

The render succeeds. The abstract keeps `[one | many]{if="FALSE"}` and `3{.num}`,
and in HTML the span prints "one | many". The end-of-document check does not
see them, because it blanks the front matter before scanning.

**Rule:** design-1a, scope: a 1a build meeting a construct it has not built
"stops with a construct error that says 'not built yet' (so nothing passes
silently)". Front-matter constructs are on that list. The filter would catch
this under Quarto, or under rmarkdown where `use_setup()` added it, but nothing
in the knit does.

### 13. `n="."` inside an `if` that is inside an `n` span is a construct error (wrong error)

```
[# x, [and it [is | are]{n="."} fine | no]{if="TRUE"} | # xs [is | are]{n="."}]{n="n"}
```

With `n <- 1`, the output has the marker `<<weft: construct error, line 7>>`
in place of the inner span, with "`n=\".\"` outside an `n` or `sign` span (rule
1.7.2)".

**Rule:** 1.7.2: `n="."` "is legal inside an `n` span". This span is inside
one. Only the immediate parent is looked at.

### 14. A project text-stage formatter on an `if` span is a construct error (wrong error)

`_weft.yml`:

```yaml
formatters:
  .up:
    function: base::toupper
    stage: text
```

```
Up: `r s`{.up} and [shout | no]{if="TRUE" .up}.
```

`` `r s`{.up} `` works. The span is a construct error: "A formatter on an `if`
span is an error (rule 1.5.7): .up."

**Rule:** 1.5.7: "Text classes on any span act on the chosen arm's final text."
A formatter registered in the text stage (1.4.8) is a text class. See also
ambiguity F.

### 15. Chunk-cache replay misses a chunk whose label has a space, so a severity condition stops failing the render (silent wrong)

````
```{r model fit, cache=TRUE}
message("boundary (singular) fit: see help('isSingular')")
```
````

The first render fails (`weft: 1 failure`, the singular fit). The second
render, served from the cache, **succeeds**. A label with a dot (`model.fit`)
or a hyphen is replayed correctly.

**Rules:** 2.9.1, 7.4.1 and 7.4.2. knitr names the cache files with the label
as written (`my chunk_<hash>.rdx`). The replay looks for the label with every
character outside `[[:alnum:]_.-]` turned into `_` (`my_chunk_…`), so it finds
nothing.

### 16. Span-like text inside a raw HTML attribute is scanned as a construct (wrong error)

```
Raw: <span title="[a]{if='FALSE'}">t</span>.
```

Not in draft mode, the render stops with a construct error at line 23 (single
quotes, 1.2.3). In draft mode the marker is written into the HTML attribute:
`[t]{title="<<weft: construct error, line 23>>"}`. Stock leaves the attribute
alone.

**Rule:** 1.9.1. Raw content is never a construct. Inline raw HTML is the
inline case of it.

### 17. Two `.em` constructs side by side break the emphasis (wrong output)

```
Adjacent: [rose]{.em}[sharply]{.em} and [a]{.em}[b]{.strong} and `r n`{.num .em}`r n`{.num .em}.
```

Rendered to HTML: `*rose<strong>sharply* and <em>a</em></strong>b** and
*2**2*`. That is literal asterisks and wrongly nested `<strong>`. The cause is
`*rose**sharply*`, which Pandoc reads as the opening of strong emphasis.

**Rule:** 1.4.3 and the design ruling (`.em` prints `*x*`) assume the result
reads as emphasis. It does not when two such constructs touch. Low frequency.

### 18. Cosmetic: the failure report

Each was reproduced in the fixtures above.

- An integer value is shown as `(value 1L)`. The 2.6.2 example shows
  `(value 7)`.
- A multi-line inline expression puts a raw line break into the report's
  header line (`lf.Rmd:25  `r claim(v,` / `  . > 9)``). This breaks the 2.6.2
  layout.
- Under Quarto, a bare `` `{r} claim(…)` `` is quoted as
  `` `r .QuartoInlineRender(claim(v, . >= 10))` ``, and a `{r}` construct as
  `` `r claim(…)` ``. Neither is what the author wrote.
- In Quarto's output, and in any `Rscript` render, the report is followed by a
  10-line rlang backtrace ending `weft:::finish_document()` /
  `rlang::abort(...)`. That is noise after the 2.6.2 report.

### 19. Performance (observation, no rule)

These are wall-clock times for whole `Rscript` runs.

- **Spread over 10 blocks.** A 500-paragraph document with 2,000 constructs
  took 2.3 s, against 0.9 s for the same document written with bare values: at
  most about 0.7 ms per construct.
- **One block, no chunks.**
  - 1,000 inline items: 2.0 s, against 0.5 s stock.
  - 2,000 inline items: 2.6 s, against 0.6 s stock.
  - 4,000 inline items: 6.6 s, against 1.0 s stock.

  The cost grows faster than the block. It is acceptable for real documents,
  but it is 2 to 4 times the spike's figure of 0.33 ms per construct.

## Where the rule is ambiguous or silent

A. **1.4.10, a vector with no collapse class.** "prints its elements run
together, as stock knitr prints an inline vector". Stock knitr prints them
joined with `", "`. The implementer took "run together" literally (finding 2).
The rule should say which, and should consider making a number-stage class on
a vector longer than 1 with no collapse class a value error, since "1.52"
cannot be told from a number.

B. **2.6.2 and 2.6.3, what a failed guard is quoted by.** The 2.6.2 example
quotes the printed sentence (`"All 10 models rise"` for `[All]{if=…}`). The
text of 2.6.3 says "reported by its phrase". weft quotes the raw first arm
(`"a"`, `"# thing"`). The example implies the sentence as printed, which is
far more useful in a long document.

C. **2.5.2 and `knitr::knit_exit()`.** The rule requires every construct
outside an arm to have been evaluated. It does not say what happens to
constructs that knitr was told to skip.

D. **2.1.2 and `evaluate.inline`.** "Each weft hook wraps the hook installed
before it and calls it." weft calls an author's `evaluate.inline` for bare
values only. For constructs it never does, because 2.2.1 says the hook only
parks. An author's hook that counts or transforms inline code silently misses
every construct.

E. **9.4.2, draft mode in a set-up project.** The failures should also be
"written to a JSON file beside the document". In a project with `_weft.yml`,
no file is written. design-1a neither builds this nor lists it among the parts
deferred.

F. **1.1.5, 1.1.9 and 1.4.8, project text-stage formatters.** 1.1.5 names
only the shipped text classes as making a text span. Under that reading,
`[a [inner]{.up} b]` leaves `.up` as an ordinary Pandoc class, and weft does
just that. The rules do not say whether a project text-stage class counts.

G. **2.6.4 and 1.1.8, an error in a bare value.** 2.6.4 says "an expression
that cannot be evaluated … is collected". 1.1.8 says a bare value keeps stock
behaviour and that no construct rule applies to it. weft stops, as stock does.
The rules should say which one wins.

H. **Grid tables.** A construct whose printed text has a different width from
its source moves the column border, and Pandoc then misreads the grid table.
Stock has the same problem with bare inline R. The rules are silent. It may
deserve a lint.
