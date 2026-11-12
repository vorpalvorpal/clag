# Field notes

What it was like to use stage 1a of weft on two real documents, written by
the agents that did the conversions (2026-11-12). The documents were copied
into `dev/trials/`, which is not committed; no data values, names or site
details are in this file. The first section is the orchestrator's summary
and what it changed in the plan. The two reports follow as written.

## Summary

**Both trials worked.** A chapter of the long report (about 1,700 lines)
rendered from a copy with text identical to stock once weft was switched on
and nothing converted; 138 constructs were then written against 113 original
inline values, and every remaining difference from stock was intended. Weft
added about one second to a ten-second render. The daily reports rendered
correctly on usual data and failed or marked as designed on empty, single-row,
zero and all-`NA` data.

**What hurt most, in order.**

1. **Wording built in R code is out of reach.** The daily reports have no
   inline R at all: every sentence comes from `glue`, `paste`, `cat`, a table
   title or a plot label. The chapter's captions are the same. A construct
   written in any of those places printed raw, silently, with exit status 0.
   `weft_str()`, captions in chunk options and front-matter fields (stage 1c)
   matter more than anything in 1b, and until they exist the raw text has to
   be an error, not a pass.
2. **The house style of an existing document is not the default.** `.num`
   printing a small number as "0.0", the thousands mark starting at 10,000,
   `.count` switching to digits at ten, `.and` without a serial comma, and
   U+2212 in prose beside an ASCII minus in tables each changed the text of
   the chapter. All are settings or need to be (see `dev/decisions.md`, "for
   Robin").
3. **A span moves an error; it does not remove it.** One converted span had
   its condition inverted, and the render passed with the opposite wording.
   Only the diff against the stock render caught it. A conversion needs that
   diff as a routine step (the ledger and `changes()` of stage 2 are the
   package's answer).
4. **An unattended report needs things the design does not give.** A failed
   render still writes its output file with markers in it; every failed check
   fails the render (no "tell me, but send it"); an empty list is a missing
   value, so the ordinary "nothing flagged today" needs an `if` around every
   list; and a block of checks in a chunk stops at the first failure and
   names only the chunk.
5. **Small costs that add up.** A value used in a summary before it is
   computed (a chapter's opening paragraph); helpers that return strings
   where a formatter wants a number; `claim()` in a chunk printing its value;
   the one-arm `if` being a guard when the author meant optional text; arms
   being trimmed when a sentence needed its trailing space.

**Bugs found** are listed in each report under "What broke". Those not
already in the runtime review went to the next fixing round.

**What changed in the plan.** Stage 1c's `weft_str()`, captions in chunk
options and front-matter constructs are built before stage 1b, and until
then a construct in any of those places is a construct error. Within 1b the
order follows what the chapter needed: `.p`, `.range`, `.cap`, `sign`, ids,
then the rest.

---

## Report 1: Field notes: converting two daily reports (stage 1a build)

Two real unattended daily reports, converted by someone using only the spec
and the stage-1a docs. Report A: a forecast report (hourly risk windows built
from a weather forecast, one narrative section, many plots, about 2,500 lines,
almost all graphics). Report B: a transactions report (tables, one forecast
table, one plot, no prose at all in the original). Both render to an email
format (`blastula::blastula_email`) from live data. Neither was run as it
stood: the inputs are live services and a mounted drive, and some chunks write
back. Data were replaced with small synthetic extracts with the same columns,
and the side-effecting chunks were dropped. Nothing here contains a data value.

Scenarios rendered for each: realistic, empty, single row, zeros / calm,
all-NA, and (report A) station missing and forecast missing. Normal and draft
(`WEFT_DRAFT=1`) mode. Also rendered once to the real email format
(`blastula::blastula_email`, and through `blastula::render_email()`).

### What was converted

**Kept:** the real prose, the table logic and the narrative logic of both
reports. **Dropped:** package install chunks, caching, every call to a
service, every pin write, the statistical model fit (replaced by a saved
forecast table), and the 1,500 lines of plot construction in report A (one
plot kept, to exercise a label built from a value).

Report B (transactions):
- 7 formatted values, 3 `n` spans, 4 `if` spans (one with two conditions),
  5 checks in one chunk, 2 inline checks, 3 `plural()` calls in chunk code
  (table subtitles).
- Prose was **added**: the original had none. A summary paragraph says how many
  deliveries, the weight, how many were flagged, whether a vehicle was
  still on site, the forecast and its range. This is what the weft constructs
  are for; the original had nothing to convert, which is itself a finding
  (see "What was missing").
- Stayed in R: all the data wrangling; every table title and subtitle (built
  with `glue`/`paste`); the plot title; the "unusual weight / unusual
  registration" notes; the numbers in the forecast table (built with `round()`
  and `glue` into markdown strings: `**62** (42 - 83)`).
- The original's two near-identical anomaly passes (in and out) were folded
  into one function. Weft played no part in that.

Report A (forecast):
- The only text that depends on values is one narrative chunk that builds
  sentences with `paste0`/`glue`/`cat(results = "asis")`: per day, per topic
  (five hourly topics, fire danger, daily rainfall in four cases, hourly
  rainfall intensity), "High risk between 9am and 1pm", "Heavy rainfall (>= N
  mm) likely; >= M mm possible". It could not be converted in place, because
  constructs in `cat()` output are not scanned and `weft_str()` is unbuilt.
- It was rewritten as a template string per day, expanded by code and
  rendered with `knitr::knit_child(text = ..., envir = ...)`. This works. The
  template has about 20 `if` spans (several nested), 3 `.and` values and 7
  `.num` values. The R side shrank to "compute vectors of window phrases"; all
  the "print this sentence only if" logic moved into spans.
- 6 checks in one chunk: the report's own invariants (a "possible" trigger must
  be set above the "likely" trigger, which the original only had as a comment),
  and data freshness and coverage.
- Prose added: a summary paragraph with observed rainfall (three cases:
  none, some, station not reporting) and a count of forecast days.
- The one-off "update" message, shown only on a given date by `if (date == ...)
  cat(...)`, became a child document with `eval = <condition>`. A span cannot do
  this (block-level text), and nothing in weft offers a conditional block.

Blastula: it does not matter to weft. Constructs resolve before pandoc and the
email format rendered identically. One real benefit: `blastula::render_email()`
raises the weft failure as an R error, so no email object is built and a
sending script stops. The cost: the failure text is the whole error message
and the rendered file with its markers is not returned.

### What was awkward

1. **Constructs cannot be used where most of the wording lives.** In both
   reports almost all value-dependent text is built in R (`glue`, `paste`,
   `cat`, gt titles, plot labels). In prose there was almost nothing to
   convert. Report B's table subtitle ended up as
   `glue("... {plural(nrow(d), 'no vehicles', 'one vehicle', '# vehicles')}")`,
   which works but is the same job as before with a weft function. Report A's
   narrative needed a whole structural rewrite (template plus `knit_child`) to
   reach the constructs at all.
2. **Every name must be bound in a chunk first.** Attribute values forbid
   quotes (rule 1.2.3), so every condition that compares to a string, and every
   cell of a data frame, becomes a named variable (`n_flag_in`, `rain_case`).
   Report A's template needs `rain_case == 'l'` style switches because there is
   no multi-way choice: four exclusive `if` spans stand in for a `switch`.
3. **A check in chunk code prints its value.** `claim(x, . > 0)` returns `x`
   visibly, so a chunk of five checks prints five stray `## [1] ...` lines
   into the report (and into the email) unless the chunk has `results = "hide"`
   or each call is wrapped in `invisible()`. In prose the equivalent is
   `` `r invisible(claim(x, . > 0))` ``, which is undocumented and which an
   author has to find by trying. A check whose only job is to check should
   print nothing.
4. **To collect several checks in a chunk the chunk needs `error = TRUE`.**
   Without it the first failed check stops the chunk and the others never run
   (rule 2.4.2). With it, each is recorded (verified: all failures reported).
   It is the right idiom for a block of data checks, and nothing says so. It
   also prints the error text into the document body.
5. **Arms are trimmed (rule 1.5.12), so a space cannot separate sentences
   inside an arm.** `[. ]{...}` loses its space and two sentences ran
   together ("possible.Very high"). The space has to go outside the span, which
   the author discovers from the output.
6. **A one-arm `if` is a guard that fails when false; optional text needs a
   trailing `|` with an empty arm.** Writing `[, and N tonnes went out]{if="..."}`
   is the natural way to write optional text, and in a daily report it fails
   the render on any day the condition is false. The message is clear
   (it says to write `[phrase | ]`), and it caught the mistake at once, but it
   cost two renders. Most of the `if` spans in a real report are optional text;
   the shorter form is the dangerous one.
7. **Pure checks and the empty "nothing to say" case multiply spans.** A
   section that is silent when empty (`if` with an empty second arm) wraps
   every topic line twice: once for the tier, once for the line.
8. **Sentence-initial numerals and words.** `.word` gives "four" at the start
   of a sentence, and `.cap` is unbuilt, so the author writes "No..." / "One..."
   as separate arms by hand. Where the count can be anything, the sentence has
   to be rephrased to avoid starting with it.
9. **A number and its governor are separate.** `` `r k`{.num} [load | loads]{n="k"} ``
   works but says `k` twice; `[# load | # loads]{n="k"}` is right and shorter. I
   wrote the first by reflex because of the way a value reads in prose.
   (Probably teaching, not design.)
10. **Failure reports do not say which check failed.** A chunk of six checks
    produces `rain-weft.Rmd chunk checks / . >= 4 was FALSE (value 0L)`: no
    line number, no `x` expression, so the author reads the chunk to find
    which one. A `Date` value prints as `structure(20769, class = "Date")`.
    See "What broke".

### What broke

Bugs are few; most problems are silent non-processing, which is worse.

1. **Constructs in chunk-option captions, `knitr::kable(caption=)` and gt
   titles are not processed and not reported.** Minimal source:
   a chunk with ``fig.cap = "Plot of [# site | # sites]{n='x'} today"``, a
   `kable(..., caption = "[a | b]{if='x > 1'}")`, and `gt::tab_header(title =
   "[a | b]{if='x > 1'}")`. Expected (design-1a header, "a 1a build meeting one
   of these names on a construct stops with a construct error that says 'not
   built yet'"; rule 2.3.2): an error naming the unbuilt feature. Got: raw
   `[# site | # sites]{n='x'}` in the output, no error, no marker, exit status 0.
2. **Constructs in `cat(results = "asis")` output are printed raw.**
   `cat("[a | b]{if='n > 1'}\n\n")` in an asis chunk prints "a | b" and no
   failure. The same family as item 1 and the main way a real report would meet
   it, but here there is nothing the scanner can see. The same applies to a
   value in a string: `` `r n`{.num} `` printed from `cat()` prints `r n`.
3. **A span broken by a blank line inside a template is not a construct and
   leaks `]{if="..."}` into the output with no failure.** Minimal: a template
   string ``"[*text*\n\n|]{if=\"nzchar(x)\"}"`` given to `knit_child(text=)`.
   Expected by rule 1.1.5/2.5: the leaked construct is caught. Got: the
   literal `[...|]{if=...}` text in the HTML, exit 0, in draft and normal. The
   backstop is the `weft-check` filter (rule 2.5.3), and 1a has no
   `use_setup()` for rmarkdown (`use_quarto()` only), so under rmarkdown no
   backstop runs. (Rule 2.5 says silence must be made impossible.)
4. **`claim(<vector>, . > 0)` fails when every element passes**, and says
   `check `. > 0` failed (value: c(1, 2))`. By 3.1 a check that is not `TRUE`
   fails, and a length-2 `TRUE` is not `TRUE`, so the behaviour follows the
   rule; but the message does not say why, and `claim(df$x, . > 0)` is the first
   thing an author writes. The message should say "the check returned length 2;
   use `all(.)`".
5. **Failure reports omit the checked expression and the line for checks in
   chunk code** (rule 2.6.2 has the chunk label only). Six checks in one chunk
   produce six reports that differ only in `. >= N` and the value. Include `x`
   as written (`nrow(forecast_7)`) and the check's line.
6. **`#id` on an `if` span is silently accepted and ignored.**
   `[a|b]{if="x > 1" #myid}` renders `a`. Design says `#id` is unbuilt
   (a "not built yet" error); it gave nothing.
7. **Draft mode exits 0.** Per rule 9.4.3. Recorded so no daily pipeline uses
   it. See "For a dynamic report".

Not bugs, confirmed against the rules: a missing value in `.num` gives a
collected "no value" failure and a marker, in place of the construct, in both
modes; `.and` of an empty vector and of a vector with an `NA` element do the
same (rule 1.3.4); `n` of 1.0 with `digits` takes the "other" arm; a bare
`` `r x` `` prints "NA" and nothing fails (1.3.1); a span with an unchosen
arm containing a failing value does not run it (1.5.16); inline `claim()` in
prose prints the value and then the marker. A non-numeric value given to
`.num` (string, Date, factor, difftime, data frame) is a value error whose
message names the class ("character" for a factor, minor).

### What the rules got wrong

1. **A zero-length value is "missing" (rule 1.3.4), which is hostile to lists
   that can legitimately be empty.** The commonest dynamic-report case is
   "list the flagged items": `` `r flagged`{.and} `` with no flagged items
   fails the render. The author must wrap every such list in an `if`. It is
   consistent and keeps silence impossible, but in a daily report the empty
   list is the normal day, and it doubles the construct count. A
   `.and` of nothing could print a stated alternative (`none="none"`).
2. **Arms are trimmed (1.5.12).** Right for the common case, wrong for spans
   that carry sentence-final spaces. See "awkward" 5. A way to keep a trailing
   space (or defining the span to own the space) would fix the template case.
3. **One-arm `if` as a guard (1.5.5).** Defensible as an assertion, but in
   practice the one-arm form is how optional text is written first, and in an
   unattended report the consequence is a failed daily send. The empty second
   arm is an easy rule to state and an easy one to forget. A lint at author
   time (tier 2) would catch it only if the lint exists; the render does not
   warn, it fails.
4. **A check cannot be a warning.** Rule 2.6.1 makes every failed check fail
   the render. Many of an owner's checks are "tell me, but send the report":
   a station offline for one day, a transaction count slightly lower than
   usual. Today the only way to make that work is not to check, or to write the
   wording to cope (which is what I did for the missing station). Severity
   exists for conditions (7.4.2) and not for claims.
5. **Rule 2.4.2: a failed check in chunk code stops the chunk.** The right
   default for a pipeline, wrong for a chunk of independent checks (needs
   `error = TRUE`, see "awkward" 4).

### What was missing

Ranked by how much of these two documents needed it.

1. **`weft_str()` (stage 1c, listed).** Needed by nearly everything in both
   reports: text lives in `glue`/`paste`/gt labels/plot labels/`cat`. Without
   it, the constructs that matter most are unreachable and the author rewrites
   the document's structure (the `knit_child` template) to reach them. A
   plot label built from a value (`paste0(round(x), " mm")`) becomes
   `paste0(fmt_num(x), " mm")`, which is a replacement of one function with
   another and a change of number format (a thousands mark appears from 10,000).
   What the 1a docs do not say: the `knit_child(text=)` route works. It should be
   documented as the supported way until `weft_str()` exists.
2. **Constructs in table captions, gt titles and `fig.cap` (stage 1c).** Every
   table and plot title in report B has the form "{weekday}'s garden waste in",
   and would be a candidate. They are silently unprocessed now (see "What broke"
   1).
3. **`.cap` and `.a` (stage 1b/1c).** Sentence-initial words ("four", "one");
   "a 3-hour ..."; here with `.word`. Without them the sentence has to be
   reordered.
4. **`.date` (listed).** Table subtitles and "on {weekday}" use R's `format()`
   directly; a bare value, so no failure on a missing date. The first real
   use of `.date` gave a "not built yet" error.
5. **`of_n()` (stage 1d, listed).** "Rain of at least 1 mm on zero of the 7
   days" wanted "none of the 7 days". `.no .word` gives "no", which reads wrongly
   there. Nothing in 1a covers this; `of_n()` would.
6. **`brk()` / `lookup()` (listed).** Report A has tier labels ("High",
   "Very high", "Heavy") chosen by thresholds. They stayed in R as a vector
   plus constants. A `brk()` function would let the thresholds live in the
   dictionary with the claim that the "possible" trigger is above the "likely"
   one. (That claim is a check I wrote in R.)
7. **A conditional block (not planned).** The date-conditional special message
   was a `child=` with `eval=`; there is no block-level `if`. Nothing planned
   covers a section that appears or disappears.
8. **`units` (listed, 4.4).** Every value in the weather report is "N mm" and
   "N mm/hr", "N tonnes". The unit is typed next to the value as text.
9. **`.range` (listed).** "likely range 41.7 to 83.2" wrote two values and a
   typed "to". Every forecast in report B has this shape.
10. **A way to say "no listed items" to `.and`/`.or`** (not planned): see "What
    the rules got wrong" 1.
11. **A "pure check" form** that prints nothing (not planned; `invisible()`
    works).
12. **A warning-level check** (not planned).

### For a dynamic report in particular

What an unattended daily render needs that the design does not provide:

1. **A failed render must not leave a sendable file.** The failure arrives at
   the end of the knit, after the output file is written, and the file holds
   `<<weft: ...>>` markers in place of the failed values. Verified: after a
   failed render the output file is on disk and the render exits non-zero. A
   sending script that checks for the file, not the exit status, mails the
   markers. Worth stating in the design: either write the output to a
   different name on failure, or say that the pipeline must test the exit
   status (and why). `blastula::render_email()` is safe because it raises the
   error and builds no message.
2. **Severity.** See "What the rules got wrong" 4. A dynamic report has data
   problems that should send and say so, and others that should not send.
   Today every check is the second kind.
3. **A failed check should say which check.** In a long unattended log the only
   record of a failure is the stderr report. It must name the expression and
   line (see "What broke" 5). A report with six identical-looking lines is
   not usable at 6 a.m.
4. **Silence on empty data is the main hazard, and weft only helps where the
   author wrote the check.** All-NA hourly data in report A rendered a
   narrative with no risks and no failures, because the code treats NA as "no
   risk" and weft never saw it (the values came from `case_when` and windows,
   not from a value in prose). The only thing that caught the station going
   missing was an explicit check on freshness. The design could help here by
   shipping a small set of data-health checks (count, freshness, share missing)
   as documented idioms; the three the author needed in both reports were
   "row count is at least N", "latest date is today or after" and "no missing
   values in this column".
5. **Zero and empty are normal days.** The "no transactions", "no rain" and
   "no forecast" days need their own wording, and in these reports that wording
   was ten spans for the cases and three lines of sentence for the normal day.
   `n` with a zero arm covers a count; it does not cover "the whole section
   has nothing to report" (nothing planned), and headings under an empty
   forecast render as empty headings.
6. **Weekday-dependent expectations.** "Zero deliveries" is a failure on a
   weekday and normal on a weekend. The claim `. > 0 | is_weekend` works, but
   the report then states "none" in the prose using a second `if`. The check
   and the wording should read from one place (the dictionary is meant for
   this; it is not built).
7. **Draft mode is the wrong tool for a daily run** (exit 0, markers in the
   output). It is the right tool for a developer to see the whole report with
   its failures; it is not a mode to leave on. Nothing prevents it being set in
   the environment of a scheduled job.
8. **The `<<weft:` markers are in the output of a failing render only if
   something reads them.** A grep step in the sending script is trivial, and
   would be a useful documented line.

---

## Report 2: Field notes: converting one chapter of a long report (stage 1a)

Trial of the 1a kernel on one real chapter of a long scientific report: a Quarto
book on a `targets` pipeline, about 1,700 lines per dense chapter, prose full of
computed values. I converted it as its author would, rendered it, and wrote down
what hurt. No data values, names or site names are given here.

### What was converted

**Route: the whole chapter, not a section.** The chapter reads everything through
`here::here()` and a `targets` store (`tar_read_raw`, plus a sourced "data layer"
that is itself read from the store). I made a trial project whose `R/` holds only
a copy of the chapter, an `R.Rproj`, and symlinks to the original's `_targets`,
`helpers`, `data-layer`, `data` and so on. It reads the store read-only and writes
nothing there. The chapter renders in about 10 s from that, with 47 chunks and
a few thousand rows, so there was no reason to cut a section. The book targets
PDF only; I rendered the chapter to html, pdf (lualatex) and docx.

Stock first: the chapter copy, with `format: html`, rendered with no weft. That
text (pandoc to plain text) is the baseline for every diff.

**Counts** (the converted file has 138 weft constructs in prose; the original had
113 inline R values):

| Kind | n |
|---|---|
| values with an attribute block | 96 |
| of which `.num` / `.pct` | 35 / 30 |
| of which `.no .count` / `.word` / `.ord` / `.and` | 14 / 9 / 4 / 4 |
| `claim()` inside a value | 10 |
| `n` spans (plurals, `none/one/#`, nested `n="."`) | 28 |
| `if` spans (guards, two-arm swaps) | 14 |
| bare inline R left alone | 32 |

Of the 113 original inline values, 81 were rewritten as classes or spans and 32 stay
bare (p-value helpers, pre-built strings such as a tie description, quoted site
codes). The remaining constructs replace typed wording: a window length in years,
the number of reference sites in a methods document, the percentile ranks, the
"burnt over N%" threshold, a count of sensitivity refits, "about half a point" (x2),
"none up", "exactly one".

**Existing inline R needed no change.** With only `engine: knitr` and
`weft::weft_setup()` added, the whole chapter's text is byte-identical to stock
(0-line diff). All 113 values print as before.

**Supporting changes in code chunks** (needed so a construct had something to
name): about 15 lines. Moving a definition above the prose that uses it (a table of
calibration windows; a fitted estimate re-read from the store), adding a few
numerics next to strings the chapter already built (`reset_mv`, `pile_pub`,
`ex_shift`), a named threshold, `sens <- list(...)` so that "four refits" is
`length(sens)`, and one chunk of bindings.

**Text diff against stock, after fixing my own mistakes** (all intended, none
surprising, but 3 are rule-level choices, see below): digits to words (`5` to
`five`, `0` to `none`), `-0.02` to `−0.02` (U+2212), `1,234` to `1234` (a four-digit count), the Oxford
comma dropped in a three-item list, and "ten" held as "ten" only after setting
`count_threshold: 11` in the document's `weft:` front matter.

My own mistakes that the diff caught and the render did not (see "What was
awkward"): an inverted two-arm `if` that turned "more lenient / lower" into "more
demanding / higher", and an `if` used for a verb agreement where an `n` span was
right ("sites has samples").

### What was awkward

- **The prose is mostly arithmetic on pre-formatted strings.** The chapter's
  helpers (`f1`, `f2`, `pcf`, `n_word`, `spell`, `n_fmt`) all return strings, and
  many tables are built with those strings in cells. To make a value a `.pct` I had
  to find or build the number behind it. 8 values read a cell of a string table
  (`tbl$"col"[2]`); each needed a numeric twin computed beside the table. Cost: a
  few lines per table, and the table and the numeric can now drift. No weft feature
  covers it; the honest fix is to keep numbers numeric until the last step.
- **Reproducing a house helper needs a pair of options on every use.** `pcf()` is
  "1 decimal under 10%, else whole". `.pct` alone prints 15.3%; `.pct sigfig="2"`
  reproduces `pcf` exactly (verified in the diff). I wrote `sigfig="2"` 30 times.
  A project formatter in `_weft.yml` fixes that, but `function:` is documented as
  `pkg::fun` and this project has no package. A bare global function defined in the
  setup chunk (`function: pcf`) did work in a probe, which is not in the docs. This is the same class of thing as
  `f1/f2/f3`: 21 uses of `.num digits="N"`.
- **Single quotes inside, double quotes outside.** The author's R is full of
  `"literal"`; in an attribute value they must become `'literal'`
  (`n="sum(x == 'urban')"`). Rule 1.2.2 says so, and it is easy. But 1.2.3's first
  clause ("a single-quoted value ... is a construct error") reads on a first pass
  as banning single quotes. It means an attribute value delimited by single
  quotes. I wrote it wrong once on purpose and the error was fine. Binding names in
  chunks was needed only twice (a name with a space and quotes, a column read as
  `x$"col name"`).
- **A governor repeats the noun phrase.** `[# slightly disturbed site | # slightly
  disturbed sites]{n="n_sd_sites"}` writes the adjective twice. The nested form
  `[# slightly disturbed site[ | s]{n="."}]{n="n"}` is worse to read. For a noun
  with a long modifier I fell back to `` `r n`{.num} `` plus a hand-typed plural,
  which is what the span was meant to retire. A span form for "pluralise the next
  word" would be the saving; nothing planned does that.
- **Hard-wrapped lines are fine.** A span or arm broken across source lines
  renders correctly. Line numbers in reports pointed at the right line every time.
- **Long expressions in attribute values** were not a real problem here: the
  attributes that grew long were `if="abs(did_est) > 0.4, abs(did_est) < 0.6"` (two
  conditions, readable) and `n="sum(baci$burnt & baci$post)"`. The real problem
  is the reverse: the expression often needs a name anyway, so I made a binding
  chunk of about 10 lines.
- **Forward references.** The chapter opens with a summary of findings whose
  values (a window length, a fitted estimate, a tie count) are computed hundreds of
  lines below. To use a construct up there I had to move a definition into the
  first chunk and, for one fitted estimate, read it from the store a second time.
  I did it for 2 of 4 such values; the other two (the summary's "one of those
  re-derived sets has it", "two exceptions") stayed typed. The author would face
  the same choice for every summary paragraph in the book.
- **Counting list items by hand** ("Three findings", "Five things ... three of
  them are changes") has no object to name. Same for the chapter's typed totals of
  items in a numbered list. I left them. Nothing in 1a flags them; if the numeral
  rule (5.2.1) is meant to, it is not on in 1a.
- **Tables are built by an R helper, `tbl(x, caption, id)`,** which emits a pipe
  table with the caption as an R string. A construct in that string is emitted as
  chunk output after weft has scanned the source, so it is left raw. Probe: output
  from `results: asis` containing `[a site | # sites]{n="k"}` and `` `r k`{.num} ``
  came out as the literal text `a site | # sites` and `` `r k` ``, with no error in
  a single-document render. The `weft-check` filter does catch the span in a
  project render; it did not report the inline value.
- **Chunk-option captions use `!expr` with `paste0(...)` of 30 lines** (two of
  them, one with a nested `local()`). They were not converted: constructs in
  `fig-cap` are not built, and with `!expr` the rule 1.10.4 says `!expr` in
  `fig-subcap` is out of scope anyway.
- **A claim that replaces a hand check.** The chapter has 11 `stopifnot()` lines
  asserting what the prose says ("the most of any reference site", "no rating
  moved up"). `claim()` does the same where the number is printed, with the
  sentence quoted in the failure. That was the best fit in the trial. Fewer
  checks stand apart from the sentence they guard.
- **Hand-written sign logic is easy to get backwards and nothing notices.** I
  defined a gap as "kept minus excluded" the wrong way round. The span
  `[**more lenient** | **more demanding**]{if="ept_gap < 0"}` then printed the
  opposite sentence, with "lower" changed to "higher", and the render passed. Only
  the diff against stock caught it. A span that picks wording from a computed sign
  is exactly as safe as the sign. It is better than typed wording (it can change
  when data change), but it hides an error from a reader who skims the output.
  `sign` (not built) would have made the direction a property of the number.

### What broke

Reproductions use `k <- 3` and a standard setup chunk. Rule numbers are from
`PACKAGE-SCOPING.md`.

1. **A vector with no collapse class prints its elements with no separator.**
   `` `r c(1.5, 2, 3)`{.num} `` prints `1.523`; `` `r c(1, 2)`{.pct} `` prints
   `100%200%`; `` `r 100*c(.2,.4,.6,.8)`{.ord} `` prints `20th40th60th80th`.
   Rule 1.4.10: "joined with ', '". Expected `1.5, 2, 3`.
2. **A construct in front matter (`abstract: |`) is left raw, with no error.**
   `We saw [# site | # sites]{n="k"} here.` renders as
   `We saw # site | # sites here.` in a single-document render. 1.10.7 says this
   works; in 1a it is not built, and the task says unbuilt things give a "not built
   yet" error. They do for `.p`, `.range`, `.cap`, `sign`, but not here.
3. **Same for a construct in `fig-cap: |`:** the caption carries
   `<span data-n="k">a site | # sites</span>` with no error (1.10.1).
4. **`#id` on a span is accepted and ignored** (`[# site | # sites]{n="k" #nsites}`
   passes). The task lists `#id` as "not built yet", so it should say so. The
   follow-up `n="#nsites"` gave a misleading `[no value] "it": An n governor has
   length zero` (the `#` starts an R comment).
5. **Wrong cause in a construct-error message.**
   `[a | b]{if="x == \"a\""}` reports "the attribute block does not parse: spaces
   around `=` are not allowed (rules 1.2.3, 1.2.9)". The spaces are inside a value
   and are fine; the escaped quote is the cause. The remedy ("bind the expression
   to a name") is right, the diagnosis is not.
6. **A report quotes the phrase where it should quote the condition.** A guard
   `[% EPT]{if="widest_fac == 'x'"}` with `widest_fac` undefined reports
   `[no value] "% EPT"` and `error evaluating "% EPT": object 'widest_fac' not
   found`. The expression that failed is not shown, only the object name inside
   the R error message. Fine for one construct; slow for a paragraph with five.
7. **Report text carries JSON escapes** in the project (post-render) report:
   `chapters/b.qmd:21  \"guard\"` and `optional text is written [phrase |
   ]{if=\"…\"}` (backslashes before every quote).
8. **Leftover spans with no line collapse in the project report.** Two different
   unprocessed spans (one in front matter, one in a caption) were both listed by the
   filter ("4 leftover weft constructs") but the post-render report listed one
   (`[leftover span]` once, no line). The author cannot tell which file position
   holds the second, or that there is one.
9. **The pre-render message points at a function that is not built:** "or run
   `weft::use_setup()`". That is the rmarkdown installer; in a Quarto project it is
   not there.
10. **A claim in an unlabelled chunk is located by a generated label**
    (`chunk unnamed-chunk-2`), a name that appears nowhere in the source. The
    chapter has an unlabelled chunk. 2.6.2 says "located by its chunk label"; no
    line is given and the label cannot be searched for.
11. **`.num` at default digits turns a small value into `0.0`.** `` `r 0.00012`{.num} ``
    prints `0.0` (1.4.13: non-whole numbers print to the default of one decimal).
    Not a bug in the rule's terms; see "What the rules got wrong".

Not bugs but worth knowing: a failing guard in a render with no draft mode stops
the render with no HTML written. A single `.qmd` render gives the report but not the
page with its markers; you need `WEFT_DRAFT=1` for that. In a project the pages are
written. Both behave as the spec says.

### What the rules got wrong

- **1.4.13 / default digits for small numbers (`.num` prints `0.0`).** In a
  statistics report, quantities such as a standard error, a small proportion or a
  difference of 0.0004 are common and must keep significant figures. The default
  that prints one decimal for any non-whole number loses the whole value, silently.
  A guard that would help: a `.num` that rounds a non-zero number to zero should be
  a failure, or print in `sigfig`. As it is, the author must remember
  `sigfig="2"` on every such value, and a render will not tell them.
- **`big_mark` from 10,000 up, never below (9.1.2).** The report writes counts of
  1,000 and over with a comma in prose and in tables (its own helper does). Weft
  prints `1234` in prose where the table beside it prints `1,234`. The rule is a
  defensible style, but it is not configurable by threshold. Either a setting for
  the threshold, or a documented way to have the marks everywhere.
- **`.count` threshold ("digits from it up", default ten) vs the author's habit
  of words up to and including ten.** It collides exactly at ten ("ten related
  tests" printed as "10"). `count_threshold: 11` fixed it. A 10-and-under habit is
  common enough that the default is worth reconsidering, or the doc should say
  "below" in the same breath as the default.
- **`.and` drops the serial comma** where the report's existing helper
  (`knitr::combine_words`) kept it. That is correct for en-AU but it is a visible
  change in every list of three or more. It is the one difference in the text diff
  that a reader could notice and an author might dispute. Worth a setting or a
  note in the adoption advice.
- **Minus sign U+2212 only on `.num`.** In prose weft prints `−0.02` and the
  chapter's tables (built with `sprintf`) print `-0.02`. Both on one page look
  inconsistent. The rule is right for typesetting; the adoption path (tables built
  by hand) leaves a mixed page.
- **The `if` guard cannot tell "wrong direction" from "right direction".** A
  two-arm `if` is checked by its form, not by meaning. That is fine, but the
  appeal of replacing typed wording with a span is that it is safe; here it moved
  the error from the prose to the condition. See "What was awkward".
- **The error-or-not split for unbuilt features is uneven.** Class and key errors
  (`.p`, `.range`, `.cap`, `sign`) fail with a clear message naming the line;
  front matter, captions and `#id` pass silently. For a manuscript where a raw
  `[...]{n=...}` could reach a reader, silent is the wrong default. (Listed under
  bugs 2 to 4.)

### What was missing

Ranked by how many places in this chapter wanted it. "Planned" is the stage-1b-1e
feature that would cover it, as named in the task, or "nothing planned".

1. **`.p`** (about 9 places: the p-value helpers `ppe`/`pp` are used for every
   test). I left them as bare helper calls. Planned: `.p`.
2. **A prose "range" `a to b`** (8 places: confidence intervals, `x to y`
   boundaries). I wrote two `.num` values and the word "to". Planned: `.range`
   (note 1.4.4's "to" and its minus rule would also fix mixed-sign intervals).
3. **Captions with constructs** (2 `!expr` captions, 4 more table captions built by
   the `tbl()` helper; all of them carry counts that are already computed). Planned:
   constructs in `fig-cap`/`tbl-cap`. Table captions built as an R string by a
   helper: nothing planned, and the case is common in this report (nearly every
   table is built that way).
4. **Sentence case on a value** (`str_to_sentence(spell(n))` at the start of a
   sentence: 1 place; `.cap` would remove the helper). Planned: `.cap`.
5. **`sign`** (3 places: "lost / gained X points", "rose / fell", "falls / rises").
   I used `if` plus an absolute value, which is two names and a possible mistake.
   Planned: `sign`.
6. **`.range`-like phrase functions** (`of_n`, `about`, `ci`, `pm`): 1 place each
   for "N of M", "about X" and an interval. Planned: phrase functions.
7. **`#id` back-references**: 3 places in the chapter that repeat a count already
   stated (a sample count restated in a caption and a paragraph). Planned: `#id`.
8. **A formatter that bundles options without a package** (`.pcf`): 30 uses. Works
   today with a global function, undocumented. Needs documentation more than code.
9. **Numbers already in the output of a pipeline** (e.g. a value in a
   `targets` object, a fit): not weft's job; the point is that `tr("name")` has to
   be called early for a forward reference. Nothing planned.
10. **A guard that says "this typed numeral is a count of that list"** (list item
    counts, "Three findings"): the numeral rule (5.2.1) is the nearest. Not built.
11. **Units:** not needed in this chapter (scores are unitless; "percentage points"
    is typed after a `.word`). Planned: units.
12. **`lookup()`, `brk()`, dictionary:** no place wanted them here. (A "burnt
    over 90%" threshold shared by code and prose wanted a *named constant* more.)

### For a long report in particular

- **Every chapter needs its own `engine: knitr` and a `weft_setup()` call.** The
  book has no `_metadata.yml`, and `engine:` in `_quarto.yml` or `_metadata.yml`
  does not count (9.2.8). 20 files, plus an appendix. `use_quarto()` writes a
  pre-render check that fails the whole render, naming the file; that worked and
  the message is good. A chapter with no constructs and no setup is silently outside
  weft, which is right.
- **`use_quarto()` in a Quarto project worked as described.** It said what it
  would write, then wrote the filter, the pre-render and post-render scripts and
  `_weft.yml`, and edited `_quarto.yml`. A test project of two chapters: the
  pre-render failed on a file with a construct and no engine; after fixing, every
  chapter rendered, the collection file filled, and the post-render script printed
  one report for the book and exited non-zero (the page files were written, with
  markers). The `filters:` line it adds at the top level of `_quarto.yml` is where
  Quarto expects it. Friction: one file's leftover constructs in front matter and
  captions are reported by the filter at render time and again, less fully, by the
  post-render script (bug 8).
- **Render time.** Chapter, html, stock: 10.0 s and 10.4 s. Same chapter with weft
  and 76 edits: 10.9 s and 11.6 s. About 1 s, mostly the extra chunk and the
  package load. 4,000 inline values across the book would add a second per chapter,
  not minutes. The book's real cost is the targets build, and weft does not touch
  it.
- **Targets.** weft needs the objects it names to be in the knit environment at the
  point of use. A chapter that reads everything from a store with `tr("name")` is
  fine, but a construct near the top that needs a value computed at the bottom
  means moving the read up (above). A target that returns a string table, not
  numbers, makes the work harder than anything in weft.
- **Cross-references work as before** (`@sec-x`, `@tbl-y`) in the prose around
  constructs. `[@cite; @cite2]` and `[1]{.num}` passed through as expected
  (`[1]{.num}` is not a construct, 1.1.9). Cross-reference warnings in the
  chapter rendered alone are the stock ones (the other chapters are not in the
  trial project).
- **Freeze and caching.** The book sets `cache: false` and no `freeze`, so
  nothing to test here. The `.weft/stamps` directory appears under the project
  root after a render. Not exercised: `verify()` and the freeze round trip (not
  built).
- **Output formats.** The same converted chapter rendered to html, pdf (lualatex)
  and docx with no weft-specific problem. The Unicode minus and `×` of `.sci`
  survived all three.
- **Hand-written checks.** The strongest argument for weft in this report is the
  `stopifnot(...)` lines and the "DERIVED, not typed" comments the author had to
  write by hand to stop a sentence going stale. The chapter's own history, in
  comments, is a list of exactly those failures. `claim()` and `if` guards turn
  each into one line in the sentence. Typed numbers in prose are not the main
  residual risk after conversion; the **window years, threshold percentages and
  list counts** are (about 30 typed in this chapter after conversion), and 1a
  does not look for them.
- **Time to convert:** the chapter's 113 values and about 25 pieces of
  value-dependent wording took one pass of mechanical edits (a script of 76
  string replacements) plus about 8 render-and-fix cycles. Most of the cycles were
  my own mistakes in conditions and moved definitions, not weft.

## Report 3: the trials again, on the finished stage 1

Both trials were run again after stages 1b to 1e and three review fix
rounds, with the converted documents unchanged.

- **Chapter.** Stock and converted renders both ran (about 10.8 s and
  11.2 s). The converted chapter's text is identical, line for line, to
  the text the first trial produced; no marker and no raw construct.
- **Daily reports.** The cases that should pass (normal, single, calm)
  render with text identical to the first trial. The cases whose data
  break a check (empty, zeros, all missing, no forecast, no station) now
  stop an ordinary render and leave no output; in draft mode they finish
  and the sentences are unchanged.
- **A draft-mode difference to decide.** The reports' checks chunk has
  `error=TRUE`, so in draft mode each failed check now prints an "Error:
  weft: 1 failed claim" block into the report body, where the first trial
  showed one claims report. If a draft is meant to be sendable, those
  blocks are noise. In `dev/decisions.md` under "for Robin", with the
  warn-level and failed-render items it belongs to.
- **`arms()`** lists the three converted documents with no errors: 5 spans
  and 10 arms, 8 spans and 18 arms (2 nested), and 42 spans and 81 arms
  for the chapter, matching the counts above.
- **`rehearse()`** on one daily report with four `params` cases: two pass,
  two report their failures, the unreached arms and unevaluated spans are
  listed, and the folder's listing (names, sizes, times) is the same
  before and after.
- **`last_knit()` is not exported.** The design notes and the tests use
  it, and an author who wants `sentence_starts` has to write
  `weft:::last_knit()`. For Robin: export it, or give the report another
  way in.

## Report 4: the trials on stage 2

Both trials were run again on the stage 2 build (snapshot of HEAD, installed
into a private library under `dev/trials/lib`). The converted documents were
first rendered unchanged. They were then converted to stage 2: quantities,
a `dict.yml` for each project, the ledger, `changes()` in a throwaway git
repository, and a small `targets` pipeline with `tar_dict()`. The daily
reports run on the same made-up data cases as before, plus a made-up "next
day". The chapter renders against the real store through the read-only links,
which were removed again afterwards. No data value, site or person is named
here.

### What was converted

**Unchanged documents on the stage 2 build.**

- *Daily reports.* There are three differences from the last trial's text, all
  from rule 1.5.20 (the space beside an empty span).
  - An empty span on a source line of its own no longer leaves a blank line.
    Sentences written on consecutive lines of one paragraph now stay in one
    paragraph. Before, a false span between two of them split the paragraph:
    in the summary, and between a day's forecast text and its first topic
    line. The source says one paragraph, so this change is wanted.
  - **Not wanted:** in the rain report, "**Rainfall**:" is now followed by no
    space in the cases where the sentence that prints is not the first of a
    chain of alternative `if` spans. See "What broke".
  - Nothing else changed. The cases that should pass still pass, and the
    failing cases still stop, with the same sentences in draft mode.
- *Chapter.* The stock text is identical. The converted chapter differs from
  the last trial in one value: a four-digit count under `.num` now has the
  thousands mark, because `thousands_from` now defaults to 1,000. That
  matches stock, so one of Report 2's unintended differences is gone.
- *The zero rule.* It changed nothing in either document. Every number that
  could print as zero already had `digits=`, and neither document held a
  quantity yet. No warned check was recorded.

**Conversion to stage 2.** The work was done on copies in `dev/trials/s2/`
and `dev/trials/chapter/`.

- **Daily reports.** The two reports share one `dict.yml` of 24 entries:
  - seven rainfall thresholds, as quantities in `mm` and `mm/hr`;
  - eight index thresholds, two of which (the UV ones) were typed inline as
    bare numbers rather than held as constants;
  - the station's name and code;
  - the weighbridge site code and two item names;
  - the weight of one truckload, as a quantity in `t`;
  - the lightest weight used to learn a vehicle's usual weight;
  - the two standard-deviation multipliers of the anomaly rule.

  Quantities replaced the typed units in:
  - the observed and forecast rainfall;
  - the hourly intensity sentences, which are built with `paste0()` and now go
    through `weft_str()`;
  - the plot label;
  - the forecast day count (`u(n, day)`);
  - the weights in tonnes and the forecast range (`.range` on a pair of
    quantities);
  - the count of truckloads, as a project unit `load`.

  Two claims were rewritten against `dict$…`. The garden-waste report sets
  `unit_form: name` in its front matter so that weights still print "tonnes".
  A ladder, `unit="kg|t"`, was tried on the outgoing weight.
- **Chapter.**
  - A `dict.yml` of eight entries: the burn-extent threshold, as a quantity in
    `percent`; six years (the bounds of two calibration windows, the fire
    season and the first year after it), as `year`; and a fire date, as `date`.
  - Four `units:` rows in `_weft.yml`: site, point, grade and family.
  - About 15 code edits, to read the years and the threshold from `dict$`.
  - 13 prose edits: three "N points", one "N grades", two "N families", one
    span of years, one count of sites, four uses of the threshold, and one
    window in prose.
  - Two table labels that had the threshold typed in them.
  - A glossary section that calls `dict_glossary()`.

  After the fixes below, the text is identical to the stage 1 text, except for
  no-break spaces between numbers and unit names and the new glossary.
- **Left typed in the chapter:** the calibration window appears in about 20
  strings: list names used as keys (`scored[["<window>, reference + …"]]`),
  captions, subtitles and comments. The dictionary can hold the years, but
  every one of those strings would have to be rebuilt with `paste0()`.

**Timings.** Wall time of one render; daily reports are the median of three
runs, the chapter the median of three `quarto render` runs.

| Document | stock | stage 2, no ledger | stage 2, with ledger |
|---|---|---|---|
| rain report | 2.9 s | 3.1 s | 3.1 s |
| garden-waste report | 3.1 s | 3.4 s | 3.4 s |
| chapter | 10.8 s | 14.2 s | 14.2 s |

The originals of the daily reports cannot run here, so "stock" for them is
the stage 1 converted document with `weft_setup()` removed. The ledger adds
nothing measurable. On the chapter, weft's cost has grown from about 0.4 s
(Report 3) to about 3.4 s, and the stage 1 converted chapter on this build
takes the same 14 s. See "What broke". `changes()` takes about 1.3 s on the
daily project.

### What was awkward

1. **A quantity cannot be used as a number in the code around it (rule
   4.4.5).**
   - Every comparison or sum of a quantity and a bare number failed with the
     `units` package's message, "both operands of the expression should be
     "units" objects". The message names neither weft nor the fix.
   - Places this happened:
     - `ifelse()`, which strips the unit;
     - `filter(prop_burnt > burn_thr)`, where the data hold fractions and the
       dictionary holds per cent;
     - the forecast table's arithmetic on the left-over weight;
     - `claim(x, . > 0)`.
   - Inside `claim()` the message is good: "state the check's unit, as in
     . < u(0.45, ug)". Outside a claim the author gets the `units` message.
   - The fixes were `u()` on the other side, or a bare-number twin kept beside
     the quantity (`burn_frac <- as.numeric(units::set_units(dict$burn_thr,
     1))`, a twin for the left-over weight, `drop_units()` on the load weight).
     Twins are the drift risk of Report 2 again.
2. **A bare quantity drops its unit, silently (rule 4.4.10).** I deleted the
   typed unit word after a value and forgot `{.num}` in six places. The prose
   then read "over N of their area", "at least N on", "N of N (N%)" for sites,
   and "(≥N)" inside `weft_str()`. Nothing warned; only the diff against the
   last text caught them. Deleting the unit word and leaving the value bare is
   the natural edit.
3. **A unit name typed in an arm is printed twice (rule 4.4.4).** "N family
   family", "N years years", "N loads loads" and "seven days days" came from
   `[# family | # families]{n=…}` spans and from a `.word` value followed by
   "days", once the value became a quantity. That is four places, with no
   warning.
4. **Count nouns as units need `symbol: false` on every row.** A `units:` row
   with `name:` and no `symbol:` prints its key as the symbol after digits, so
   the noun is never plural: "N site", "N point", "N site were". Every
   count-noun row needed `symbol: false`. A key that had to be renamed (see
   item 5) printed the new key as text, "N sf_grade", until it had
   `symbol: false` too.
5. **`grade` is silently an angle.** `u(x, grade)` is accepted, prints
   "grades", and converts to degrees (udunits' gon). Writing a `units:` row
   for `grade` is refused ("`is` cannot redefine `grade` … choose another
   key"), which is how I found out. It is not in the list rule 4.4.20 refuses
   (`mt`, `kt`, `kph`); a score's "grade" is the same kind of misreading.
6. **`mm/hr` prints as "mm/h".** The token was not kept as written (rule
   4.4.20 says it is), so the hourly sentences changed until I added
   `units: mm/hr: symbol: mm/hr`.
7. **House spacing cannot be kept.** The rain report wrote "≥Nmm" in one place
   and "N mm/hr" in another. `space:` is one setting per unit, so I took the
   SI space, which changes every daily rainfall line.
8. **`.pct` on a quantity in per cent is a value error.** The message says
   "give it a number with no unit". That steers the author to
   `drop_units()` and `.pct`, when the simpler fix is to drop `.pct`, since
   the unit prints "%".
9. **`u()` refuses a logical.** `u(NA, mm)` and `u(logical(0), mm)` both fail
   with "must be a number or a units value, not a logical". `ifelse()` on a
   data frame with no rows returns `logical(0)`, so the no-forecast case
   stopped with an R error: not a collected failure, and not rescued by draft
   mode. Workaround: `as.numeric()`.
10. **`_weft.yml` is both the units table and the switch for the ledger.** A
    file that exists turns the ledger on (`is_set_up()`), so an author who
    only needs `units:` rows gets a ledger written at every render. The same
    rows in front matter under `weft: units:` do work, but then they must be
    repeated in every document.
11. **Typed constants inside strings.** The table labels ("Burnt >N% in …")
    had to be rebuilt as `paste0("Burnt >", fmt_num(burn_thr), …)`. The
    hourly sentences needed `` `r dict$…`{.num} `` written inside a
    `paste0()` string for `weft_str()`, which takes careful quoting.
12. **A useful surprise.** Making "load" a unit showed that the report uses the
    word for two things: one delivery ("N loads were delivered") and a
    truckload of fixed weight ("at least N loads waiting"). The glossary would
    show it; nothing in weft could.

### What broke

1. **Rule 1.5.20 removes a space in a chain of alternative spans.**
   - `A: [x|]{if="FALSE"}[y|]{if="TRUE"}.` prints "A: y.".
   - `A: [x|]{if="FALSE"}[q|]{if="FALSE"}[y|]{if="TRUE"}.` prints "A:y.".
   - The second empty span takes away the space before the first. The rule
     says "otherwise nothing is removed", and the space is not beside it.
   - In the rain report this is the rainfall line of every day whose wording
     is not the first case. It regressed from stage 1.
2. **Reads in the chunk that calls `weft_setup()` are not recorded in the
   ledger header.** The hooks are installed by that chunk, so its own code is
   never scanned for `dict$key` or `tar_read()`.
   - Garden-waste report: the two item names read in the setup chunk were
     missing from the header. Changing one in `dict.yml` did not mark the
     ledger as not re-rendered, while a change to a key read in a later chunk
     did.
   - Pipeline report: `targets: {}`, though it reads two targets in its setup
     chunk. Moving the reads into a second chunk recorded them.
   - Most documents read their constants in the setup chunk.
3. **The chapter's targets are invisible to the ledger.**
   - The chapter reads the store through a wrapper,
     `tr <- function(name) tar_read_raw(name, store = here::here("_targets"))`.
     The walker follows the function, but `name` is a variable and `store` is
     not a literal, so none of the nine reads was recorded.
   - Instead it recorded one target from a function of the sourced data layer,
     with the default store taken from the knit's working directory
     (`chapters/_targets`), which does not exist.
   - `changes()` says so honestly ("the store chapters/_targets does not
     exist; the pipeline was not checked").
   - The effect is that rules 7.2 (not re-rendered since a target changed) and
     7.4.1 (the conditions of targets read) do nothing for this book. The
     book's model fits are targets, so the severity list's singular-fit
     pattern never sees them either.
4. **`weft_setup()` now costs about 2.3 s per render**, even in a document
   with no quantity. A profile of the chapter's knit put about 0.8 s in
   reading the units tables (`read_units_tables`, `units::valid_udunits`) and
   about 1.3 s in scanning the file (`new_file_state`, `scan_block`). The
   first `u()` in a session costs about 1 s on its own. For a three-second
   daily report this is most of weft's cost.
5. **A failed render under `tar_quarto()` hides weft's report.** A weft failure
   in a report the pipeline renders comes back from `tar_make()` as "Error
   running quarto CLI … Rerun with `quiet = FALSE`". The real project gives
   exactly this as its reason not to use `tar_quarto()`.

### What the rules got wrong

1. **Rule 1.5.20, for chains** (above). A chain of alternative `if` spans is
   the ordinary way to write a three- or four-way choice, and the space before
   the chain belongs to the text before it.
2. **A ladder picks the first rung for an exact zero (rule 4.4.13).**
   "Weighing 0.0 tonnes in total, and 0 kilograms went out." A zero has no
   natural rung, and the smallest rung reads as a different measurement beside
   its neighbour. The unit the quantity is held in, or the last rung, would
   read better.
3. **A bare quantity printing without its unit (rule 4.4.10)** keeps stock
   behaviour for values stock never had. A quantity the author made with `u()`
   or read from the dictionary has a unit on purpose. It should print it, or
   be a warned check.
4. **"Crosses 1.0" applies to quantities (rule 7.3.4).** An observed rainfall
   that moved below one millimetre was ranked structural, "crosses 1.0, order
   of magnitude". Crossing 1.0 means something for a ratio, not for a number
   in mm.
5. **Number words count as claim words.** Entries were ranked for the claim
   words "four" and "seven", which were the printed counts themselves, and
   "least" (from "at least"). Every sentence with a spelled count ranks above
   the others, so the ranking below the structural changes was mostly noise.
6. **"Crossing a dictionary threshold" cannot see a threshold used in code.**
   The rain report's most important event, a day's forecast moving into
   "very heavy", came through only as arm flips of the tier wording, which did
   rank first. The forecast value itself was listed with no reason, because
   its expression does not name `dict$`.
7. **Rule 4.6.3, "a new key re-runs none", has an exception.** A target that
   reads `dict[[k]]` with a variable key is taken to read every entry. It
   re-ran when a key was added and on every value change of any key: here, a
   function that looks up two labels.
8. **An arm that prints nothing is shown as the next sentence.** In
   `changes()`, a governed span whose new arm printed nothing showed the
   following sentence as its "after" text. Another one showed an empty line.
   "(prints nothing)" would not mislead.

### What was missing

1. **A check for a unit name repeated after `#` or after a value** ("days
   days", "family family"), and for a bare quantity whose unit is dropped.
   Between them they caught every conversion mistake I made.
2. **A range or vector type in the dictionary.** Calibration windows are pairs,
   band probabilities and index breaks are vectors. I split each window into
   two `year` keys. The glossary then shows a window by its first year only,
   and the code writes `c(dict$cal_start, dict$cal_end)` everywhere.
3. **A way to name the store a document reads.** A `_weft.yml` setting, or
   following a wrapper's `store =` argument. Without it the ledger cannot link
   this book's chapters to the pipeline.
4. **`dict_seed()` that sees inline literals and constant targets.**
   - On the whole book (all chapters, the pipeline functions and
     `_targets.R`) it proposed 4 names: two label vectors, a list of site
     codes and a list of parameter names.
   - It did not see the two constants that most need a dictionary: the
     burn-extent threshold, typed inline in comparisons in four chapters and
     three times in the pipeline code, and the calibration window, typed in
     19 files.
   - It did not see the constants that are targets (`tar_target(x, <a number>)` and
     named vectors).
   - On the two daily reports it found nothing with the default
     `min_files = 2`. With `min_files = 1` it proposed a list of packages and
     a vector of colours along with the thresholds, and missed the inline UV
     thresholds and the site code written into `filter()` calls.
5. **A per-chapter glossary.** `dict_glossary()` lists the whole project
   dictionary, which for a book means every chapter's terms in every chapter.
   Entries with no `term` show their key in code (`cal_end`, `fire13_date`),
   which a reader of a report should not see.
6. **A ledger switch separate from `_weft.yml`**, and a word about `.weft/`.
   That folder appeared untracked in every project (stamps, a network cache),
   and nothing says to ignore it.
7. **A short form of `changes()` for a run nobody watched**: the structural
   changes and the new conditions only.

### For a dynamic report in particular

- **The ledger of a daily report.** The rain report's ledger is 148 entries,
  about 74 KB; the garden-waste report's is 18 entries, about 6 KB. On an
  ordinary day the condition log is a header line. One day to the next, the
  git diff of the ledgers was about 120 KB (85 lines added and 101 removed in
  the rain report).
- **The diff is not readable.** Every entry stores its whole sentence, and in
  this report a "sentence" is a long run of HTML (`<span style=…>`, `<br>`).
  `<br>` is not a sentence boundary, and the day headings, made in a
  `knit_child()`, are glued to the first sentence ("Today *…*<br>**Dust**:
  …"). One changed number rewrites every entry whose sentence holds it: 14 of
  18 lines in the garden-waste ledger changed. `changes()` is the only
  readable view.
- **`changes()` after a second day.** It listed 38 changed and 16 removed
  entries.
  - The structural section (9 entries) was the right list to read first:
    risk tiers moving up or down, the "vehicle still on site" sentence going
    away, the fire-danger line, and the observed rainfall (for the wrong
    reason, rule 7.3.4).
  - The 29 ranked below it were mostly noise (number words as claim words).
  - The "removed" entries were constructs inside arms not chosen that day,
    such as the thresholds inside a rainfall sentence. They had not left the
    document; they just did not print.
- **Rolling day sections are compared by position.** All four day sections are
  one section to the ledger (their headings come from one chunk), so entries
  are keyed by their order in the loop. When the days roll forward, each
  section's day name is reported as changed.
- **A dictionary edit that emptied the report.** Changing one item name in
  `dict.yml` made the garden-waste report say that no garden waste was
  delivered. The render passed: the checks allow no deliveries when something
  went out. `changes()` put it first, as five structural changes. This is the
  strongest case for running `changes()` after an unattended run. The
  not-re-rendered check missed the same edit, because of the setup-chunk gap
  in "What broke".
- **A check that errors before it runs passes the render.** A claim whose
  first argument raised an error (a quantity minus a bare number), in the
  report's `error=TRUE` checks chunk, printed the error into the report body.
  The render passed. It was logged, and `changes()` listed it as a new
  condition, so it is not lost, but the check did not run.
- **Who commits?** Committing is the acceptance (rule 7.3.7). An unattended
  service would have to commit the ledger itself every day, about 74 KB of
  churn for the rain report. Someone has to read `changes()` before that
  commit, or the ledger only records what was sent.
- **Empty and all-missing data.** The no-forecast case broke on `u()` given
  `logical(0)` (see "What was awkward"). In the all-missing case the
  failure markers no longer carry the typed "tonnes", which is better.

### For a long report in particular

- **The units a scientific chapter has are mostly count nouns** (sites,
  samples, families, score points, grades, years), not physical units. Each
  one needs a `units:` row with `symbol: false`. The `n` spans already
  handled plurals, so where units really gained was small: `.word` on
  `u(n, year)` printing "twelve years", and a per-cent threshold that prints
  its own "%". Each quantity cost arithmetic friction in the code around it.
- **The real gain is constants typed in many files.** The burn-extent
  threshold is typed in four chapters and three times in the pipeline's
  functions; the calibration window is typed in 19 files.
  - With a dictionary in the chapter only, changing the threshold changed only
    the printed threshold in four sentences. `changes()` listed four ordinary
    changes, and nothing said that the model fits in the store were computed
    with the old value.
  - The dictionary has to be read by the pipeline too (`tar_dict()`). Even
    then, the ledger cannot tell the chapter is stale, because of the store
    gap in "What broke".
- **The real pipeline's shape.**
  - **There are no parallel workers.** There is no `crew` controller in
    `_targets.R`, `targets-src/` or `_targets.yaml`, and `crew` is not
    installed. The only parallelism is inside three targets' functions: a
    permutation test with `parallel = 4`, which forks on macOS.
  - The other features `tar_dict()` must handle:
    - `tar_source("targets-src")`;
    - a custom `tar_format()` (qs2) set as the default format;
    - targets generated by `lapply()` with `tar_target_raw(substitute(…))`;
    - constants held as targets (whole numbers and named vectors);
    - `error = "stop"`.
  - The chapters are not targets. `tar_quarto()` is ruled out on purpose, and
    the `.qmd` files are hashed as a file target. A chapter reads the store
    through a `tar_read_raw()` wrapper, so `tar_dict_deps()`' report support
    does not apply to this book. The link from the dictionary to a chapter is
    only the ledger's not-re-rendered check.
- **The trial pipeline** (`dev/trials/pipeline/`, its own store) copied that
  shape with made-up data: `tar_source()` functions that read `dict$`, a qs2
  default format, `lapply()`-generated targets, a `tar_map()`, a constant
  moved from a target to `dict.yml`, a `tar_quarto()` report and a
  `tar_render()` report.
  - `tar_dict()` and `tar_dict_deps()` handled all of it. The `dict_<key>`
    targets were stored under the custom format without trouble, and the edges
    were exactly the entries each target reads.
  - What re-ran, and whether it matched what I expected as an author:
    - a value: exactly its readers and their downstream targets, plus the
      variable-key reader (rule 4.6.3 above);
    - a definition, or the order of the file: no target downstream;
    - a new key: none downstream except the variable-key reader;
    - a key only the report reads: the report alone.

    That was what I expected, except the variable-key reader. Any edit to
    `dict.yml` rebuilds every `dict_<key>` target: cheap, but all of them show
    as completed in the progress output.
- **Glossary.** `dict_glossary()` rendered in the chapter, as a definition list
  of 8 entries, sorted with terms and bare keys mixed. A window's "term" sits
  on its first year alone.
- **Ledger for the chapter.** 177 entries, about 72 KB. A dictionary edit made
  without re-rendering was reported correctly: "not re-rendered; dict$… changed;
  the chapter changed". A sentence edit with no value change is not a change
  (rule 7.1.7). It rewrote every ledger line in that sentence (19 lines with
  the dictionary edit), but `changes()` lists nothing for it.
