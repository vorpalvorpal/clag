# Review of stage 1c and the Quarto side

Reviewer: an independent agent, working from a frozen snapshot of the package
(installed into a private library). Quarto 1.11.9, knitr 1.51, rmarkdown 2.31,
R 4.4. Every finding below was reproduced by rendering a document or project
of my own. Unless said otherwise, a Quarto document is activated from its
front matter:

```yaml
engine: knitr
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
```

and an rmarkdown document from a setup chunk that calls `weft::weft_setup()`.
"rr" means `rmarkdown::render(f, md_document(variant = "markdown"))` and "rq"
means `quarto render f --to markdown` (or `--to html` where it says so).

## Findings

### 1. `use_quarto()` always rewrites `_quarto.yml` from its parsed form, which breaks Quarto's own validation — crash

The text edit path in `quarto_yml_with_weft()` can never succeed. Its last
expression is `ok && identical(...) && identical(...) && x`, where `x` is the
edited character vector. `&&` on a character vector is an error ("invalid 'y'
type"). The `tryCatch` turns that into `FALSE`, so every edit falls back to
`yaml::as.yaml()` of the parsed file. That writes YAML 1.1 booleans
(`yes`/`no`), drops every comment, expands anchors, and flattens mapping
entries.

Repro: a project whose `_quarto.yml` is

```yaml
project:
  type: default
format:
  html:
    toc: true
    code-fold: false
execute:
  echo: false
filters:
  - early.lua
```

Run `weft::use_quarto(".")` and then `quarto render a.qmd`. The file now says
`toc: yes`, `code-fold: no`, `echo: no`. The render stops: `_quarto.yml
validation failed ... Field "echo" has value no, which must instead be true
or false. Quarto uses YAML 1.2.` A file with only `project: type: default`
plus `execute: echo: false` is rewritten the same way.

The same fallback turns a filter entry `- at: post-render\n  path: late.lua`
into two string entries, `- post-render` and `- late.lua`. It also drops `#`
comments and expands `&d`/`*d` anchors. Nearly every real project has a
boolean in it, so `use_quarto()` breaks nearly every project it is run on.
The test "keeps what was there" passes because R's `yaml` reads `yes` back as
`TRUE`.

Rule: design-1a, "adds the filter to `_quarto.yml`"; 9.3.1. Severity:
**crash**.

### 2. A caption given as `!expr` stops working when weft is on — parity break

```
#| label: fig-e
#| fig-cap: !expr paste("Built", n)
```

and `#| fig-alt: !expr paste("Alt", n)`, under Quarto. Stock prints "Built 3"
and alt "Alt 3". With weft the caption is lost from the markdown output, and
in html it is the deparsed code `paste(“Built”, n)`. The alt text is
`paste("Alt", n)`.

The cause: knitr holds an `!expr` option as an `expression` object.
`is.language()` is TRUE for it, so `caption_option_hook()` wraps it in
`caption_resolver(<expression>, o)`. Evaluating that call returns the
expression unevaluated, and knitr never evaluates it again. There is no
construct in these captions, so the caption must be left exactly as stock
leaves it (design-1c "stock parity", 2.1.7). The rmarkdown header form
`fig.cap=paste(...)` is not affected. Severity: **parity break**.

### 3. A chunk label written differently from the scanner's expectation gives a false "unevaluated" failure — false positive

knitr reads `{r, fig5}` as label `fig5`. `parse_header()` takes the label
only when it comes right after the engine with no comma, so the scanner
names the chunk `unnamed-chunk-N`. The caption is resolved, but
`note_caption_recorded()` matches on the label, finds nothing, and the
end-of-document check fails the render.

```
```{r, fig5, fig.cap='Comma label [a site | # sites]{n="n"}.'}
plot(1)
```

```{r, fig6}
#| fig.cap: |
#|   Comma pipe [a site | # sites]{n="n"}.
plot(1)
```
```

rr gives exit 1: `b.Rmd:10 [unevaluated] a n construct ... It was never
evaluated: the caption's chunk did not run`, and the same for line 16. The
output shows both captions were resolved ("3 sites").

The same happens under Quarto with a YAML comment on the label,
`#| label: fig-a   # the depth figure`. The scanner takes the label as
`fig-a   # the depth figure`, and the render fails with `c.qmd:16
[unevaluated]`. Rules 2.5.2 and 2.1.5 (the scan must agree with the knit).
Severity: **false positive** (a correct document fails).

### 4. Captions in a child document: false "unevaluated", and failures named in the parent file — false positive and wrong position

Parent `q.Rmd` has a setup chunk and then
`` ```{r child, child='k.Rmd'} ``. The child `k.Rmd` is:

```
K.

```{r}
#| fig.cap: |
#|   Kid [a site | # sites]{n="n"}.
plot(2)
```
```

rr gives exit 1: `k.Rmd:5 [unevaluated] a n construct`. The caption was
resolved: in draft mode the figure reads "Kid 3 sites." and its file is
`unnamed-chunk-3-1.png`. knitr numbers the child's unlabelled chunk 3, while
the scanner of `k.Rmd` numbers it 1. A labelled chunk in the child works.

In the same set-up, a failed claim in a child's caption is reported as
`m.Rmd chunk kfig, fig.cap` (the parent's file) and not as `kid2.Rmd`. So is
a failed claim in a child's `weft_str()`: `a.Rmd chunk kidchunk`, though
`kidchunk` is in `kid.Rmd`.

Rules 2.1.5 (a child's constructs are scanned from its own file), 2.5.2,
2.6.2 and 2.7.1 (name the source file). Severity: **false positive**, and
**wrong position**.

### 5. A collection file left behind by an aborted render makes later knits in the project pass silently — silent wrong

Any ordinary error in a chapter stops `quarto render` before the post-render
script runs. A failed `claim()` in chunk code (2.4.2) does the same. Then
`.weft/failures.jsonl` and `.weft/run` stay on disk.

Repro: book project `bk` set up with `use_quarto()`. Add a chunk
`stop("boom")` to `ch2.qmd` and run `quarto render` (exit 1, files left
behind). Then add `notes.Rmd` to the project root:

```
```{r}
weft::weft_setup()
n <- 3
```

Note `r claim(n, . > 50)`{.num}.
```

`rmarkdown::render("notes.Rmd")` exits **0**. The output reads `Note
3<<weft: failed claim, line 10>>`, and the failure has been appended to the
stale `.weft/failures.jsonl`, which no script will read. Every later knit in
the project that is not a full `quarto render` behaves the same way. Neither
`.weft/` nor this file is added to `.gitignore`, so the file can also be
committed.

In the same aborted render, failures of earlier chapters are never reported.
With `ch1.qmd` failing a prose claim and `ch2.qmd` stopping on
`claim(n, . > 99)` in chunk code, the console shows only ch2's failures. The
ch1 failure (`ch1.qmd:13`) sits only in the stale file. Rule 2.4.5: "a failed
check that stops the knit prints, with its own error, every failure
collected before it". Rules 2.6.5, 2.6.6, 2.9.5. Severity: **silent wrong**.

### 6. A document served from freeze with no stamp passes silently — silent wrong

This is what a fresh clone looks like: `_freeze/` is meant to be committed,
and `.weft/stamps/` is not. Project `fz` has `execute: freeze: auto` and is
set up. `a.qmd` holds:

```
```{r}
#| label: s1
n <- 3
weft::weft_str('S `r claim(n, . > 7)`{.num}')
```

```{r}
#| label: fig-h
#| include: false
#| fig-cap: |
#|   Hidden `r claim(n, . > 8)`{.num}.
plot(1)
```
```

Render 1 exits 1. Render 2, served from freeze, exits 1 (correct, from the
stamp). Then `rm -rf .weft` and render 3: **exit 0**. There is no report, and
no "served from freeze" notice. The html still carries `<<weft: failed claim,
chunk s1>>`.

Rule 2.9.2: report "each document with constructs that was served from
freeze". Rule 2.9.4: fail while a frozen document has recorded failures. A
frozen document whose record is missing is unknown, and the post-render
script treats it as clean. Severity: **silent wrong**.

### 7. The filter does not look in code blocks, so a marker in printed chunk output is missed — silent wrong

A `weft_str()` result printed normally (`## [1] "S 3<<weft: failed claim,
chunk s1>>"`) ends up in a CodeBlock. The filter walks only Inlines, Span and
Code. In the book render, `ch2.qmd`'s filter pass listed the `line 17` marker
but not the `chunk s2` marker. This is what lets findings 6 and 8 through
with exit 0. Rules 2.5.3 ("any marker `<<weft:`") and 2.9.5 ("the text
`<<weft:` anywhere in a document"). Severity: **silent wrong**. (See item C
for the tension with documents that show markers in fenced code.)

### 8. A failure in `weft_str()` inside a cached chunk is reported once, then passes — silent wrong

rmarkdown:

```
```{r cached, cache=TRUE}
x <- weft::weft_str('C `r claim(n, . > 9)`{.num}')
cat(x)
```
```

Render 1 fails. Render 2 exits **0**, and the output holds `## C 3<<weft:
failed claim, chunk cached>>`.

Under Quarto it is the same, even inside a set-up project with the filter
(project `fz`, chunk `#| cache: true`, `weft::weft_str(...)` printed):
EXIT1 1, EXIT2 **0**, and the marker is in `k.html` (see finding 7). A
caption in a cached chunk is a static error for exactly this reason (2.3.5).
`weft_str()` in a cached chunk has neither that static error nor a stored
failure. Rule 2.9.1 (in spirit), and rule 2.6.8 with trial bug 1 ("a
construct left raw must never pass silently"). Severity: **silent wrong**.

### 9. A construct in a caption set by `opts_chunk$set()` is left raw on a cached chunk, with exit 0 — silent wrong

```
```{r setup}
weft::weft_setup()
n <- 3
knitr::opts_chunk$set(fig.cap = 'Global [a site | # sites]{n="n"}')
```

```{r a}
plot(1)
```

```{r b, cache=TRUE}
plot(2)
```
```

rr exits **0**. Chunk `a` gives `![Global 3 sites]`. Chunk `b` gives
`![Global [a site \| \# sites]{n="n"}]`, raw. `caption_not_resolved()`
returns the options untouched, the scanner cannot see the caption, and
nothing records it. Rule 2.3.5 (a construct in the caption of a cached chunk
is a construct error) and trial bug 1. Severity: **silent wrong**.

### 10. A caption computed by R code is resolved as markup — silent wrong

rmarkdown header captions:

```
```{r h, fig.cap=paste0("[a site | # sites]{n=", '"n"', "}")}
plot(1)
```
```

This prints `![3 sites]`. The same holds for `fig.cap = cap`, where `cap` is
a character variable, and for any value an R expression returns. The span
text came from data, and it was evaluated as a construct with its `n=` code
run.

Rule 2.2.4: "A data value whose text looks like a span is printed, never
evaluated". Design-1c: "a construct in it is legal when the string is a plain
literal". Under Quarto, `!expr` captions do not get this far (finding 2).
Severity: **silent wrong**: R code taken from data is run.

### 11. Some caption static errors are missed and reported as a bare "unevaluated" — wrong error

Each document below has a construct in the caption of an otherwise ordinary
R chunk:

- (a) document-level `cache: true` under `knitr: opts_chunk:` (Quarto)
- (b) `#| eval: !expr FALSE`
- (c) `#| cache: !expr TRUE`
- (d) under rmarkdown, `knitr::opts_chunk$set(cache = TRUE)` in the setup
  chunk (same path)

`scan_file()` gives no error for any of them. The render fails only at the
end, as `c5.qmd:19 [unevaluated] a n construct`. That message names no chunk
and no option, and gives no div remedy.

`doc_execute()` reads only `execute:`. `co()` compares the raw text
(`"!expr FALSE"`) with `falsy()`. The legal neighbours are all correctly
left alone: `cache: false`, `eval: true`, `execute: cache: true` with a chunk
`cache: false`, `cache: yes`/`1`, `eval: no`/`False`. Rule 2.3.5 ("set on the
chunk or for the document ... a construct error, found from the source. The
message says to write the caption in a figure or table div") and design-1c.
Severity: **wrong error**.

### 12. `weft_str()` called from inline R in prose is located by a chunk that does not exist — wrong position

```
Inline fail: `r weft::weft_str(s9)`.
```

Here `s9 <- "IF `r claim(n, . > 9)`{.num}"`, on line 31 of `a.Rmd`. The
report says `a.Rmd chunk unnamed-chunk-7`, and the marker says `<<weft:
failed claim, chunk unnamed-chunk-7>>`. The document has two unlabelled
chunks, and the call is in prose at line 31. `current_chunk_label()` reads
`opts_current` during inline evaluation, which holds a stale or synthetic
label.

Rule 3.6.3: a `weft_str()` string "is prose wherever it is called from".
Rules 2.6.2 and 2.7.1: a failure that has a line is located by it. Severity:
**wrong position**.

### 13. The book report drops filter findings: entries with no line and the same kind are merged — wrong error

The post-render script de-duplicates on `file + line + kind`. Filter lines
have `line: null`, so every leftover span in a document after the first is
dropped.

Repro: an unactivated `raw.qmd` (engine knitr) in project `fz`, with leftover
spans in the title, a heading, a table caption, an image caption, a callout,
a footnote, a `fig-cap`, a `tbl-cap` and a figure-div caption. The filter
prints "10 leftover weft constructs". The post-render report says `weft: 2
failures`, with one `[leftover span]` entry and one `[leftover attribute
block]` entry.

The same happens with two `[leftover attribute block]` findings in different
paragraphs: the report says "1 failure". Trial bug 8 says two findings with
no line stay as two entries. Filter findings also have no line at all: in
the book, `ch3.qmd:8` and `ch3.qmd:10` were printed as bare `ch3.qmd` (rule
2.6.2; see item D). Severity: **wrong error** (report).

### 14. A `---` rule followed directly by text is taken for a metadata block, and the constructs in it pass raw — silent wrong

```
Before the rule.

---
Between the rules, [yes | no]{if="x"} and `r 1+1`.

---

After.
```

rr exits **0**, and `[yes | no]{if="x"}` is in the output raw.
`metadata_blocks()` treats any `---` that follows a blank line and is
followed by a non-blank line as a metadata block, up to the next `---`. It
does not check that the content is a YAML mapping, as Pandoc does. So the
prose scan and the end-of-document check skip it, and the text hook does not
resolve it. In my repro, Pandoc rendered the block as a table. The pattern is
plausible in revealjs decks, where `---` separates slides. Rules 2.5.2 and
2.10.2. Severity: **silent wrong**.

### 15. The pre-render check fires on construct-like text inside inline code and escaped brackets — false positive

In a project, a plain markdown `.qmd` (no `engine: knitr`, no R) that
documents weft syntax stops the whole render:

- ``Something like `]{n=1}` `` gives `legit.qmd: holds a weft construct
  (Something like ]{.x} and `]{n=1}`.)`
- a double-backtick span `` `` `r x`{.num} `` ``
- `Escaped \[a | b\]{if="x"}?`

`first_construct()` runs regexes on whole prose lines without removing code
spans or escapes. Pandoc reads none of these as a construct, and the filter
correctly passes the same document. Rule 2.5.4 (fail on "one that holds a
construct"), and rule 1.9 (code spans and escapes are not constructs).
Severity: **false positive**.

### 16. The filter flags braces in ordinary prose and metadata as an attribute block — false positive

`Text with {braces}, {n=3}, a set {if=1} and JSON {"n": 1}.` in the body,
and `abstract: "Uses [x]{.smallcaps} and {n=3} text."`, give "text still
shows an attribute block" and fail the render. A leftover attribute block
touches the text before it (1.1.7: `3{.num}`), and these follow a space.

As a side effect, the excerpt printed for the abstract holds a NUL byte
(`Uses ^@ and {n=3} text.`) where the smallcaps span was. Rule 2.5.3 ("text
that still shows an attribute block"), read with 1.1.7. Severity: **false
positive**. The NUL byte is cosmetic.

### 17. Outside a knit, an unknown object in `weft_str()` is a plain `simpleError` — wrong error

`weft_str("E `r nope`{.num}")` stops with `simpleError: object 'nope' not
found`. During a knit the same string is collected as `[no value]`, with the
marker `<<weft: no value, chunk s1>>`. Design-1c lists four classes for the
outside-a-knit stop. An expression that cannot be evaluated is a "no value"
failure (2.6.4, 2.6.8), so `weft_no_value` would be expected. Severity:
**wrong error**.

### 18. Block-quoted chunks are run by knitr but not seen by `scan_file()` — wrong output (scanner)

knitr's chunk pattern is ``^[\t >]*```+\s*\{...``. `find_chunks()` only
accepts leading spaces and tabs. A chunk written as `` > ```{r} `` with a
`fig-cap: |` construct and a `weft_str("Q [l]{.strong}")` call yields no
caption or `weft_str` rows. The hooks still resolve the caption, so this is
not silent at render time, but the lints (3.6.2, 2.10.2) miss these
constructs. Severity: **wrong output** (scanner rows missing).

### 19. Cosmetic

- Every Quarto render with weft active prints `Warning message: In
  readLines(con, ...) : incomplete final line found on
  '/var/folders/.../quarto-session...'`. A stock render prints nothing. It
  comes from a `readLines()` without `warn = FALSE`, presumably on Quarto's
  execute-info file.
- A stray `]{if="x"}` with no blank line anywhere (`Text ]{if="x"} alone.`,
  or `[a]{n="k"}]{if="y"}`) is reported as "The span is split by a blank
  line", which is not true.
- A failed check on an integer prints `(value 4L)` (`params$k: 4`), and trial
  bug 4 says `format()` style.
- `weft_str(c(a = ..., c = ...))` drops the names. A named vector given to
  `labs()` or scale labels loses its mapping.
- `use_quarto()` run from a subdirectory of a project says "Create the
  project first (`quarto create project`)", though the project exists.
- The freeze notice prints the time with no zone (`last run 2026-11-12
  02:56:40`).

## Ambiguous or silent rules

A. **A raw construct in `knitr::kable(caption = )` (no `weft_str()`).** In
rmarkdown, and in a single Quarto document with no filter, `kable(head(cars),
caption = 'Kable [a site | # sites]{n="n"}')` prints the construct raw, with
exit 0. Rule 1.10.10 says such text goes through `weft_str()`. Trial bug 1
says a raw construct must never pass silently "where the scanner can see it".
The scanner could see a literal `caption =` string as easily as a
`weft_str()` literal. Does the rule want that?

B. **What counts as a "check" in the freeze notice (2.9.2).** `index.qmd`,
whose only construct is `` `r 1+1`{.num} `` with no `claim()`, is reported as
"1 check did not run". `ch2.qmd` counts a two-arm `if` as a check. Is it
claims, all constructs, or claims plus guards?

C. **"`<<weft:` anywhere" against documents about weft (2.9.5 against
1.9.2).** Finding 7 needs the filter to read printed chunk output, which is a
CodeBlock. A fenced ```` ```markdown ```` block that shows a marker on
purpose is a CodeBlock too. The rules do not say whether chunk output and
non-executed fences are told apart: for example, by the `cell-output` class
under Quarto, or by `##`-prefixed knitr output.

D. **Lines for filter findings.** 2.6.2 says each failure is recorded with
its line. The filter works on the Pandoc tree and has none. Should the
post-render script find the line by searching the source, as 2.7.2 does for
blocks? Without lines, finding 13's merging is unavoidable unless entries are
keyed by their text.

E. **Bare inline R inside a `weft_str()` string.** It is evaluated ("as
knitr evaluates it", says the help page). In a caption, the ruling leaves it
as literal text. Rule 1.1.8 says stock behaviour everywhere, but there is no
stock behaviour for a string in R code. Which one is intended?

F. **Doc-level cache under rmarkdown (2.3.5).** "Set for the document" can
only be found from the source under Quarto (`execute:` and `knitr:
opts_chunk:`). Under rmarkdown it is `opts_chunk$set(cache = TRUE)` in a
chunk. Should that be a runtime construct error with the div remedy (see
finding 11), or is it outside the rule?

G. **`use_quarto()` from inside a project.** Should it walk up to the
project root, as the pre-render script and the knit do, or insist on being
pointed at it?
