# Value-dependent wording and claims

This article is for authors whose sentences depend on the data: a count
that may be one or many, a trend that may rise or fall, a statement that
is only true above a threshold. After it you will be able to let a value
choose its own wording, check what a sentence asserts with
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md), and
list every wording a document can produce before the data arrive.

## Spans

A **span** is a bracket of prose followed by an attribute block that
holds a **governor key**: `n`, `list`, `if` or `sign`. The key’s value
is an R expression, in double quotes. The bracket holds one or more
**arms**, separated by `|`. The governor’s value chooses one arm, and
only that arm prints.

``` markdown
[a site | # sites]{n="n_sites"}
```

Inside an arm, `#` stands for the governor’s value as printed. Arms are
trimmed, so spaces around `|` do not matter.

| Key | The value must be | Arms | Chosen |
|----|----|----|----|
| `n` | a single number | 1 | always (a template for `#`) |
|  |  | 2 | one / other |
|  |  | 3 | zero / one / other |
|  |  | 4 | zero / one / two / other |
| `list` | a vector of any length | 2 | one / other |
|  |  | 3 | zero / one / other |
|  |  | 4 | zero / one / two / other |
| `if` | one or more conditions, each `TRUE` or `FALSE` | 2 | true / false |
|  |  | 1 | always (a guard) |
| `sign` | a single number | 2 | positive / negative |
|  |  | 3 | positive / negative / zero |

A wrong number of arms for the key is a construct error, found from the
source before anything runs.

The examples in this article come from one document. Its data chunk is:

``` r

n_sites <- 1
n_lost <- 0
n_visits <- 3
flagged <- c("Upper", "Lower")
none_flagged <- character(0)
slope <- 0.31
d_abund <- -0.042
d_cover <- 0
depth <- 2.46
mod <- data.frame(rising = c(TRUE, TRUE, TRUE))
n_missing <- 0
core <- 1
trend <- weft::brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "no change in",
                   TRUE ~ "a rise in")
ratio <- 1.12
```

## Counts: `n`

An `n` span chooses a plural form.

``` markdown
We visited [a site | # sites]{n="n_sites"}.

[No samples were | One sample was | # samples were]{n="n_lost"} lost.

The logger was cleaned [never | once | twice | # times]{n="n_visits"}.
```

``` text
We visited a site.

No samples were lost.

The logger was cleaned 3 times.
```

The span sees the value as it prints. The “one” arm is chosen only when
the number prints as exactly “1”, so a value printed with decimals takes
the “other” arm:

``` markdown
The core was [# metre | # metres]{n="core"} long, or
[# metre | # metres]{n="core" digits="1"}.
```

``` text
The core was 1 metre long, or 1.0 metres.
```

Formatter classes and the keys `digits` and `sigfig` on an `n` or `sign`
span format the number that `#` prints. With none, `.num` formats it.

An `n` governor must be one number. A vector is an error that tells you
to count it:

``` r

v <- c("Upper", "Lower")
weft_str('[a site | # sites]{n="v"}')
#> Error:
#> ! weft: chunk unnamed-chunk-6: An `n` governor must be a single number, not a vector; write `length(x)` to count the elements of a vector (rule 1.5.11)
```

## Lists: `list`

A `list` span chooses its arm by the length of a vector, and `#` prints
the vector joined with “and”. Use it when a list can be empty:

``` markdown
[No sites were | # was | # were]{list="flagged"} flagged.

[No sites were | # was | # were]{list="none_flagged"} flagged.
```

``` text
Upper and Lower were flagged.

No sites were flagged.
```

A list class on the span, such as `.or`, changes how `#` joins the
items. A vector that holds an `NA`, or a value that is not a vector at
all (a data frame, `NULL`), is a missing value, so a misspelt column
cannot print “No sites were flagged”.

## Conditions: `if`

An `if` span with two arms chooses between them. Its value is one or
more conditions separated by commas, and all must be `TRUE` for the
first arm.

``` markdown
Phosphorus [rose | fell]{if="slope > 0"} over the period.
```

``` text
Phosphorus rose over the period.
```

An empty second arm makes optional text. Write the empty arm with a
space before the closing bracket:

``` markdown
Sampling was complete[, apart from the estuary sites | ]{if="n_missing > 0"}.
```

``` text
Sampling was complete.
```

When an arm prints nothing, weft removes one space beside it, so you
write ordinary spacing around the span.

### Guards

An `if` span with one arm is a **guard**. It always prints its words,
and it fails the render when a condition is not `TRUE`. Wrap the word
that makes the claim:

``` markdown
[All]{if="all(mod$rising)"} `r nrow(mod)` models rise.
```

``` text
All 3 models rise.
```

If one model stops rising, the sentence is false. Here is a short
document, `guard.Rmd`, with that data and an empty list:

```` markdown
```{r data}
mod <- data.frame(rising = c(TRUE, FALSE, TRUE))
flagged <- character(0)
```

[All]{if="all(mod$rising)"} `r nrow(mod)` models rise.

[# was | # were]{list="flagged"} flagged.
````

Its render fails with:

``` text
weft: 2 claims failed
  guard.Rmd:14  "All"
      all(mod$rising) was FALSE
      optional text is written [phrase | ]{if="…"}
  guard.Rmd:16  "# was"
      the list is empty, and a two-arm `list` span has no arm for the empty case (rule 1.5.3); add a first arm for the empty case
      add a first arm for the empty case
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

The second failure in that report is another **case with no arm**: a
two-arm `list` span given an empty vector. A two-arm `sign` span at zero
is one too. weft treats each as a failed claim, because no wording was
written for it.

## Direction: `sign`

A `sign` span chooses by the sign of a number. `#` prints the size
without its sign, so the arm carries the direction:

``` markdown
Abundance [rose by # | fell by # | did not change]{.pct sign="d_abund"}.

Cover [rose by # | fell by # | did not change]{.pct sign="d_cover"}.
```

``` text
Abundance fell by 4.2%.

Cover did not change.
```

A `sign` span judges zero on the number as printed: a change that prints
as “0.0%” takes the zero arm.

``` r

d <- -0.0004
weft_str("Cover [rose by # | fell by # | did not change]{.pct sign=\"d\"}.")
#> [1] "Cover did not change."
```

## Agreement

Whole arms are the plain way to make words agree. An inner span can also
follow the enclosing count with `n="."`:

``` markdown
[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n_sites"}.

`r flagged`{.and} [was | were]{n="length(flagged)"} sampled.
```

``` text
1 sample was taken.

Upper and Lower were sampled.
```

A value or a span can carry an **id**, written `#name` in its attribute
block. A later span refers to it with `n="#name"`, and agrees with the
value as it printed there, without evaluating it again:

``` markdown
Depth was `r depth`{#d .num} m, and the [core was | cores were]{n="#d"} kept.
```

``` text
Depth was 2.5 m, and the cores were kept.
```

The id must be defined earlier in the same document.

## Writing `|` and `#` in an arm

A doubled `||` or `##` in an arm is a literal `|` or `#`. A backslash
before either is removed first, so `\|` also works, and inside a
pipe-table cell the separator itself must be written `\|`.

``` r

weft_str('[a||b | c]{if="TRUE"}')
#> [1] "a|b"
```

## Checks: `claim()`

`claim(x, check, ...)` returns `x` unchanged after checking it. In a
check, `.` stands for `x`. Each check is a separate argument and is
reported on its own.

``` r

claim(5, . > 1)
#> [1] 5
claim(c(3, 4), sum(.) == 7, all(. > 0))
#> [1] 3 4
```

Use [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
inside a value, so the render fails when the sentence around it stops
being true: `` `r claim(n_exceed, . >= 10)` ``. It works inside a larger
expression too, as in `` `r trend(claim(ratio, . > 0))` ``, and in a
governor: `[a site | # sites]{n="claim(k, . > 0)"}`.

Where the check runs decides what happens when it fails:

- In inline R during a knit (prose, a caption, a
  [`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
  string), the failure is collected and the render fails at the end with
  the full report.
- Everywhere else (chunk code, a targets pipeline, the console), it
  stops at once with an error of class `weft_claim_failed`. A project
  can collect failures in chunk code too: see “Collecting failures in
  chunk code” below.

``` r

n_exceed <- 7
claim(n_exceed, . >= 10)
#> Error:
#> ! weft: 1 failed claim
#>   check `. >= 10` failed (value: 7)
```

A check written with `level = "warn"` never fails. In a knit the value
prints as if the check passed, and the check is listed at the end of the
knit:

``` markdown
Gauges that fell: `r claim(n_down, . >= 10, level = "warn")` in all.
```

``` text
weft: 1 warned check(s)
  extra.Rmd:18  `r claim(n_down, . >= 10, level = "warn")`
      . >= 10 was FALSE (value 7)
```

Outside a knit it is an R warning:

``` r

claim(7, . >= 10, level = "warn")
#> Warning: weft: check `. >= 10` failed (value: 7)
#> [1] 7
```

`claim(x)` with no check is an error, and so is a check with no variable
in it, such as `claim(x, TRUE)`: the lint `inert-check` finds it.

When a check fails, the report asks you to read the sentence. Either the
sentence, the check or the data is wrong. Loosening the check until it
passes hides a sentence that is no longer true.

### Collecting failures in chunk code

A long report makes most of its values in chunks. By default the first
claim that fails there stops the knit, and the claims after it never
run. To see them all in one render, set in `_weft.yml` (or under a
document’s `weft:` key):

``` yaml
chunk_claims: collect
```

A claim in chunk code that fails is then recorded,
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
returns its value as if the check had passed, and the knit goes on. The
render fails at the end with every failure listed. Here is a chunk,
`data`, with two claims that fail:

``` r

up <- c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE)
n_sites <- length(up)
n_up <- claim(sum(up), . >= 10)
share <- claim(n_up / n_sites, . > 0.8)
```

``` text
weft: 2 claims failed
  a.Rmd chunk data
      . >= 10 was FALSE (value 7L)
  a.Rmd chunk data
      . > 0.8 was FALSE (value 0.7)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

This covers chunk code, the functions it calls, the files it
[`source()`](https://rdrr.io/r/base/source.html)s and the chunk options
knitr evaluates. In draft mode the failures are reported and the render
does not fail.

A value that failed its claim can make a later chunk fail with an
ordinary error. When the knit stops on such an error, weft lists the
claims first, because the error may follow from them:

``` text
weft: the knit stopped on an error after 2 failed claims in chunk code. The claims are listed first: the error may follow from a value that failed its claim.
weft: 2 claims failed
  b.Rmd chunk data
      . >= 10 was FALSE (value 7L)
  b.Rmd chunk data
      . > 0.8 was FALSE (value 0.7)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
The error that stopped the knit:
  the model did not fit
```

Some claims still stop at once, whatever the setting:

- a claim outside a knit, at the console or in a script;
- a claim in a running `targets` target, so that a value that failed its
  claim is never stored as good;
- a claim in another process, such as a `callr`, `future` or `mirai`
  worker; its error reaches the chunk as an ordinary error;
- a [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
  in a Python or Julia chunk.

The setting changes nothing in the commit gate: a claim counts there as
before.

### Check a value once, where it is made

A value that several sentences rely on tends to be checked in each of
them: a guard here, a claim there. The checks drift. One sentence guards
`turb_max > trigger`, a later one `turb_max >= trigger`, and when the
stricter one is deleted with its sentence, the document checks less than
it did and nobody sees it.

Check the value once, in the chunk that makes it, and use the name
after:

``` r

n_up <- claim(sum(trend$up), . >= 10)
```

``` markdown
Turbidity rose at `r n_up` sites. Of the `r n_up` sites that rose, ...
```

[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
returns its value, so `n_up` is the checked value, and every sentence
that prints it rests on that one check. Combined with
`chunk_claims: collect`, a failure there is listed at the end of the
render with the rest.

### Seeing every check: `checks()`

[`checks()`](https://vorpalvorpal.github.io/weft/reference/checks.md)
reads the documents of a project, runs nothing, and lists each check by
the value it checks: one-arm guards,
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
checks, and the conditions of two-arm `if` spans, which choose wording
and fail nothing. Here a document checks `n_up` in three places, and
`turb_max` against the trigger with two operators:

``` text
weft checks: 15 checks of 3 values in 1 document; 1 value flagged

report.qmd
  n_up
    n_up >= 10              3  lines 8, 44, 90
      checked in 3 places with the same condition: check it once where the value is made
  turb_max  [operators]
    turb_max >= trigger     9  lines 12, 20, 31, 40, 52, 70, 88, 97, 105
    turb_max > trigger      1  line 64
  max(turb)
    max(turb) < u(50, NTU)  1  line 120
  not read
    claim(diffs, all(. > 0))  1  line 126
```

- `[operators]` marks a value checked against the same thing with `>` in
  one place and `>=` in another (or `<` and `<=`). `[literals]` marks a
  value checked against two different numbers in one direction, such as
  `x > 5` and `x > 3`. A lower and an upper bound, `x > 0` and `x < 10`,
  are not flagged.
- A check repeated with the same condition in three or more places gets
  the advice to check it once; `repeats` sets the count.
- A value assigned in more than one place is marked, because its checks
  may be of different values.

[`checks()`](https://vorpalvorpal.github.io/weft/reference/checks.md)
returns a data frame, one row per check, so you can filter it.

What it reads. A check is read when it is a comparison with one of `<`,
`<=`, `>`, `>=`, `==` and `!=`, each side a name, a dictionary read such
as `dict$trigger`, a number, a quoted string or date, `TRUE` or `FALSE`,
a quantity such as `u(50, NTU)`, or a value expression such as
`max(turbidity)` or `x[1]`; or when it is a bare name or `!name`. In a
claim, `.` stands for the value: the name claimed, the value piped in,
or the name the result is assigned to, so
`n_up <- claim(sum(trend$up), . >= 10)` reads as `n_up >= 10`. Two
expressions are one value only when they are written alike once spacing,
line breaks, comments, quote marks and the native pipe are set aside:
`max(t)` and `base::max(t)` are two values, and `x < 2 * lim` says
nothing about `x < lim`.

Not read, and listed under “not read”: a check that is itself a call
(`all(. > 0)`, `is.na(.)`, `in_range(., r)`), a check with `&&`, `||` or
`%in%` at its top, a `.` inside an expression (`mean(.) > 3`), and an
expression that reads no name, assigns, defines a function, calls a
method, or calls something whose value changes between two calls
([`runif()`](https://rdrr.io/r/stats/Uniform.html),
[`Sys.time()`](https://rdrr.io/r/base/Sys.time.html),
[`get()`](https://rdrr.io/r/base/get.html)). Python and Julia checks are
not read. Binding a name, as above, is the way to have every check on a
value grouped under it.

The commit gate uses the same reading to say, when a check is removed,
whether one that remains still covers it. See
[`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md).

## Phrases chosen by key or by range

[`lookup()`](https://vorpalvorpal.github.io/weft/reference/lookup.md)
builds a function that turns a key into a phrase.
[`brk()`](https://vorpalvorpal.github.io/weft/reference/lookup.md)
builds one that turns a number into a phrase by ranges, tried in order:

``` r

tier_lab <- lookup(c(ref = "Reference", mod = "Moderately disturbed"))
tier_lab("mod")
#> [1] "Moderately disturbed"
trend <- brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "no change in",
             TRUE ~ "a rise in")
trend(c(0.9, 1, 1.12))
#> [1] "a fall in"    "no change in" "a rise in"
```

In prose the call is an ordinary value:

``` markdown
The index showed `r trend(ratio)` abundance.
```

``` text
The index showed a rise in abundance.
```

Both functions stop on a key or a value they cannot place, and an `NA`
is a “no value” failure: it never falls through to a default phrase.

``` r

tier_lab("high")
#> Error:
#> ! lookup(): "high" is not a key; the keys are "ref", "mod" (rule 3.3.2).
trend(NA)
#> Error:
#> ! A brk() function was given a missing value (NA, NaN, Inf, -Inf or a value of length zero).
```

A [`lookup()`](https://vorpalvorpal.github.io/weft/reference/lookup.md)
or [`brk()`](https://vorpalvorpal.github.io/weft/reference/lookup.md)
that a project uses in more than one place belongs in the dictionary, as
a `labels` or `breaks` entry (see
[`vignette("units", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/units.md)).

## Phrase functions

Some wording is fixed by arithmetic. These functions print it:

``` r

of_n(3, 7, "site", "sites")
#> <weft_text>
#> [1] "3 of the 7 sites"
of_n(0, 4, "site", "sites")
#> <weft_text>
#> [1] "none of the 4 sites"
of_n(1, 1, "site", "sites")
#> <weft_text>
#> [1] "the only site"
of_n(2, 2, "site", "sites")
#> <weft_text>
#> [1] "both sites"
of_n(5, 5, "site", "sites")
#> <weft_text>
#> [1] "all 5 sites"
about(0.48)
#> <weft_text>
#> [1] "nearly half"
about(0.52)
#> <weft_text>
#> [1] "just over half"
about(0.32, to = 1/3)
#> <weft_text>
#> [1] "nearly a third"
ci(2.1, 1.3, 2.9)
#> <weft_text>
#> [1] "2.1 (95% CI 1.3 to 2.9)"
pm(2.1, 0.3)
#> <weft_text>
#> [1] "2.1 ± 0.3"
clamp(0.004, floor = 0.01)
#> <weft_text>
#> [1] "< 0.01"
```

[`about()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
refuses a value that is further than its tolerance from the target,
because “nearly half” would then be false:

``` r

about(0.3)
#> Error:
#> ! about(0.3, to = 0.5): the value is further than the tolerance (0.05) from the target, so "half" would not be true.
```

[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
does not put these functions on the search path. In a document, write
[`weft::of_n()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
or call [`library(weft)`](https://vorpalvorpal.github.io/weft/) in a
chunk.

The tolerance of
[`about()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
and the level of
[`ci()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) come
from the settings `about_tolerance` (0.05) and `ci_level` (0.95).

[`ci()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) has
three switches. `short = TRUE` drops the level text, `pct = TRUE` prints
each number as `.pct` does, and `plus = TRUE` signs each number as
`.plus` does:

``` r

ci(2.1, 1.3, 2.9, short = TRUE)
#> <weft_text>
#> [1] "2.1 (1.3 to 2.9)"
ci(0.12, 0.08, 0.16, pct = TRUE)
#> <weft_text>
#> [1] "12% (95% CI 8% to 16%)"
ci(-0.4, -1.2, 0.4, plus = TRUE)
#> <weft_text>
#> [1] "−0.4 (95% CI −1.2 to +0.4)"
ci(0.031, 0.012, 0.052, pct = TRUE, plus = TRUE, short = TRUE)
#> <weft_text>
#> [1] "+3.1% (+1.2% to +5.2%)"
```

The setting `ci_short: true` makes the short form the default for a
project. A short interval that names its own level is an error, because
the reader would take a 90% interval for a 95% one:

``` r

ci(2.1, 1.3, 2.9, level = 0.9, short = TRUE)
#> Error:
#> ! ci(): the short form prints no level, and `level = 0.9` was given; give `short = FALSE` to print it, or drop `level` (rule 3.5.3).
```

## Spans in R code

[`plural()`](https://vorpalvorpal.github.io/weft/reference/plural.md) is
the function form of an `n` span:

``` r

plural(1, "a person", "# people")
#> [1] "a person"
plural(0, "never", "once", "twice", "# times")
#> [1] "never"
```

`if` and `sign` spans have no function form. In R code an `if` is R’s
own, and a `sign` span is written as markup in a
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
string.

## Numbers from a source

A number quoted from another study is not computed, so it goes in a
`cite` span. The span prints its words and, with an `@`, the citation:

``` markdown
Earlier work found [0.5 m in the upper reach]{cite="@doe2019"}.
```

``` text
Earlier work found 0.5 m in the upper reach (Doe 2019).
```

With a bare key, `cite="doe2019"`, the span prints only its words, and
you write the citation elsewhere in the same paragraph. Each key must be
in the bibliography: weft checks this at knit time and in the lints.

A fixed number with no source, such as a method’s filter size, is marked
with the class `.weft-literal` and a `why` that records the reason:

``` markdown
Samples were filtered through
[0.45 µm]{.weft-literal why="pore size set by the laboratory method"} membranes.
```

``` text
Samples were filtered through 0.45 µm membranes.
```

The `why` is removed from the output. Both marks exempt the number from
the `numeral` lint (see
[`vignette("lints", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/lints.md)).

When the number was chosen by a recorded decision, point at it with
`decision`, on a `.weft-literal` span or div, on a `cite` span, or in a
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md):

``` markdown
filtered through [0.45 µm]{.weft-literal why="method" decision="12"} membranes
reached [10 m]{cite="@doe2019" decision="31"} in the upper reach
`r claim(n_sites, . >= 10, decision = 31)` sites
```

The pointer prints nothing and is removed from the output. A failed
claim says which decision set its bound: “. \>= 10 was FALSE (value 7);
decision 31”.
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
checks that each pointer resolves, as it does for the dictionary’s (see
[`vignette("units", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/units.md));
a `decision` in
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) is
checked when it is written as a literal. A blank `decision`, or one on
any other construct, is a construct error. Python and Julia
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) take
no `decision` yet.

## Every wording a document can produce

A document that renders on new data each day can say things nobody has
read yet. weft gives two tools to see them in advance.

[`arms()`](https://vorpalvorpal.github.io/weft/reference/arms.md) reads
a document, runs no R, and lists every arm of every span:

``` r

f <- file.path(tempdir(), "daily.Rmd")
writeLines(c(
  "---",
  "title: \"Daily turbidity\"",
  "output: md_document",
  "params:",
  "  readings: [4.2, 7.9, 12.6]",
  "knitr:",
  "  opts_knit:",
  "    weft: !expr weft::weft_setup()",
  "---",
  "",
  "```{r data}",
  "x <- unlist(params$readings)",
  "n_high <- sum(x > 10)",
  "change <- x[length(x)] - x[1]",
  "```",
  "",
  "[No gauge | One gauge | # gauges]{n=\"n_high\"} read above 10 NTU today.",
  "Turbidity [rose by # | fell by # | did not change]{sign=\"change\"} NTU over the day."
), f)
arms(f)
```

    #> daily.Rmd:17  n="n_high"
    #>   1 (zero)  No gauge
    #>   2 (one)  One gauge
    #>   3 (other)  # gauges
    #> daily.Rmd:18  sign="change"
    #>   1 (positive)  rose by #
    #>   2 (negative)  fell by #
    #>   3 (zero)  did not change

[`rehearse()`](https://vorpalvorpal.github.io/weft/reference/rehearse.md)
knits the document once for each **case**, a named list of `params`,
each in a fresh R process, and reports which arm each span chose and
which arms no case reached. It writes nothing to the project.

``` r

rehearse("daily.Rmd", cases = list(
  usual = list(),
  calm  = list(readings = c(3.1, 3.4, 3.1)),
  storm = list(readings = c(11.2, 14.8, 30.5))
))
```

``` text
case usual: ok
  arms chosen:
    daily.Rmd:17  n="n_high"  arm 2 (one)  One gauge
    daily.Rmd:18  sign="change"  arm 1 (positive)  rose by #
case calm: ok
  arms chosen:
    daily.Rmd:17  n="n_high"  arm 1 (zero)  No gauge
    daily.Rmd:18  sign="change"  arm 3 (zero)  did not change
case storm: ok
  arms chosen:
    daily.Rmd:17  n="n_high"  arm 3 (other)  # gauges
    daily.Rmd:18  sign="change"  arm 1 (positive)  rose by #

1 arm that no case reached:
  daily.Rmd:18  sign="change"  arm 2 (negative)  fell by #
Every span was evaluated by some case.
```

No case made turbidity fall over the day, so “fell by \#” has never been
rendered. Add a case that does, and read the sentence it produces.
[`rehearse()`](https://vorpalvorpal.github.io/weft/reference/rehearse.md)
changes only `params`: a document that reads its data some other way
renders the same data in every case.
