# Getting started with weft

This article is for anyone who writes reports in R Markdown or Quarto
and wants the numbers in the prose to come from the analysis. After it
you will be able to turn weft on in a document, print computed values
with formatters, choose wording from a value, check a value with
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md), and
read the report weft gives when a check fails.

## What weft adds

weft adds two things to the markdown you already write.

A **value** is inline R code. With no attribute block, `` `r x` ``
prints exactly as knitr prints it. With an attribute block,
`` `r x`{.num} `` prints through one of weft’s formatters.

A **span** is a bracket of prose with an attribute block that names a
weft key: `[a site | # sites]{n="k"}`. The key’s R expression chooses
which part of the bracket prints.

Both are ordinary Pandoc syntax. A value with an attribute block or a
span with a weft key is a **construct**. The rest of your document is
left alone.

## Turn weft on

weft does nothing until a document calls
[`weft::weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md).
The smallest way is the document’s own front matter:

``` yaml
---
title: "Creek monitoring"
output: html_document
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---
```

A Quarto document needs `engine: knitr` in its front matter as well, so
that knitr runs it.
[`library(weft)`](https://vorpalvorpal.github.io/weft/) in a chunk does
not turn weft on: it only attaches the package. The other ways to turn
weft on, and the installers that write them for you, are in
[`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md).

Once weft is on, inline R in the document can call
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md),
[`plural()`](https://vorpalvorpal.github.io/weft/reference/plural.md),
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md),
[`glue_vec()`](https://vorpalvorpal.github.io/weft/reference/glue_vec.md),
[`dict_glossary()`](https://vorpalvorpal.github.io/weft/reference/dict_glossary.md)
and the `fmt_*()` functions without `weft::`. Call other weft functions,
such as
[`of_n()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) or
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md),
as
[`weft::of_n()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
or attach the package with
[`library(weft)`](https://vorpalvorpal.github.io/weft/) in a chunk.

## A first document

This R Markdown document summarises three turbidity readings.

```` markdown
---
title: "Creek monitoring"
output: html_document
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---

```{r data}
sites <- c("Upper", "Middle", "Lower")
turbidity <- c(Upper = 4.2, Middle = 7.9, Lower = 12.6)
n_high <- sum(turbidity > 10)
change <- -0.084
```

We sampled `r length(sites)`{.word} sites: `r sites`{.and}.
Mean turbidity was `r mean(turbidity)`{.num} NTU, and
[no site | one site | # sites]{n="n_high"} read above the trigger.
Turbidity [rose by # | fell by #]{.pct sign="change"} since last year.
The highest reading was `r claim(max(turbidity), . < 50)`{.num} NTU,
at `r names(which.max(turbidity))`.
````

The paragraph renders as:

``` text
We sampled three sites: Upper, Middle and Lower. Mean turbidity was 8.2 NTU,
and one site read above the trigger. Turbidity fell by 8.4% since last year.
The highest reading was 12.6 NTU, at Lower.
```

Each construct did one job:

- `{.word}` spelled the count, and `{.and}` joined the names.
- `{.num}` rounded the mean to the project’s default of one decimal
  place.
- The `n` span chose “one site” because `n_high` is 1. With no reading
  above 10 it prints “no site”, and with two it prints “2 sites”.
- The `sign` span chose “fell by” because `change` is negative, and
  printed its size as a percentage in place of `#`.
- [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
  checked that the highest reading is below 50 and returned it unchanged
  for `{.num}` to print.
- The last value has no attribute block, so it printed as knitr prints
  it.

When the reading at Lower is 9.6 instead, the same source renders as:

``` text
We sampled three sites: Upper, Middle and Lower. Mean turbidity was 7.2 NTU,
and no site read above the trigger. Turbidity fell by 8.4% since last year.
The highest reading was 9.6 NTU, at Lower.
```

The words changed with the data. Nobody edited the sentence.

## When a check fails

Suppose a storm pushes the reading at Lower to 61.0. The claim that the
highest reading is below 50 is now false, and the render stops with this
message:

``` text
weft: 1 claim failed
  storm.Rmd:20  `r claim(max(turbidity), . < 50)`
      . < 50 was FALSE (value 61)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

A failed check does not stop the knit at once. weft collects every
failure in the document, then fails the render once, with each failure’s
file and line. Read each sentence the report names and decide which is
wrong: the sentence, the check or the data.

A value that cannot be printed is collected the same way. An `NA` given
to `{.num}` is a “no value” failure, and an error in a construct’s
expression is reported with its line.

## Draft mode

While you write, you may want to see the whole document even though a
check fails. Set the environment variable `WEFT_DRAFT=1`, or put
`draft: true` in the project’s `_weft.yml`. In draft mode the render
finishes, the failures are listed in the knit log, and each failed
construct carries a visible marker:

``` text
The highest reading was 61<<weft: failed claim, line 20>> NTU, at Lower.
```

Every marker starts with `<<weft:`, so you can search for it. Draft mode
covers the render only.
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
refuses to run in draft mode, and the commit gate ignores it.

## If weft is not on

A document whose constructs are never resolved does not print plausible
text. Without
[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md),
the attribute blocks print as text, for example “We sampled 3{.word}
sites”, and a
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) call
stops the knit because `claim` is not found. In a set-up project the
`weft-check` filter also fails the render on any leftover construct.

## weft from R code

Each formatter class has a function of the same name, for use in chunks,
plots and tables:

``` r

library(weft)
fmt_num(8.2333)
#> <weft_text>
#> [1] "8.2"
fmt_word(3)
#> <weft_text>
#> [1] "three"
fmt_and(c("Upper", "Middle", "Lower"))
#> <weft_text>
#> [1] "Upper, Middle and Lower"
fmt_pct(-0.084)
#> <weft_text>
#> [1] "−8.4%"
```

[`plural()`](https://vorpalvorpal.github.io/weft/reference/plural.md) is
the function form of an `n` span:

``` r

plural(1, "a site", "# sites")
#> [1] "a site"
plural(4, "a site", "# sites")
#> [1] "4 sites"
```

[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
resolves weft markup in a string, for text that no chunk option reaches,
such as a table caption:

``` r

n_sites <- 3
weft_str("Turbidity at `r n_sites`{.word} sites.")
#> [1] "Turbidity at three sites."
```

Outside a knit, a failed check stops at once with an error:

``` r

claim(61, . < 50)
#> Error:
#> ! weft: 1 failed claim
#>   check `. < 50` failed (value: 61)
```

## Where next

- [`vignette("values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/values.md):
  every formatter class and its settings.
- [`vignette("wording", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/wording.md):
  spans, claims, and how to see every wording a document can produce.
- [`vignette("units", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/units.md):
  quantities with units, and the project dictionary.
- [`vignette("targets", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/targets.md):
  the dictionary in a targets pipeline.
- [`vignette("lints", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/lints.md):
  the static checks.
- [`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md):
  the commit gate, the ledger,
  [`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
  and
  [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md).
- [`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md):
  setting up a project.
- [`vignette("agents", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/agents.md):
  what an AI coding agent needs to know.
