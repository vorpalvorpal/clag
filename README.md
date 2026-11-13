# weft

weft lets the prose of an R Markdown or Quarto document carry computed
values, and wording that depends on those values. It checks that what a
sentence says is still true of the data each time the document renders. For
a long report or a book, it also stops the commits that would break the link
between a number in the text and the analysis that produced it.

Every weft construct is markdown that knitr, Pandoc and Quarto already
accept. Nothing is compiled, and the file you edit is the file that renders.

## An example

A Quarto document. The front matter turns weft on for this one document.

````markdown
---
title: "Creek monitoring"
engine: knitr
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---

```{r}
#| label: data
turbidity <- c(Upper = 4.2, Middle = 7.9, Lower = 12.6)
n_high <- sum(turbidity > 10)
change <- -0.084
```

We sampled `r length(turbidity)`{.word} sites.
[No site | One site | # sites]{n="n_high"} read above the trigger.
Mean turbidity [rose by # | fell by #]{.pct sign="change"} on last year,
and the highest reading was `r claim(max(turbidity), . < 50)`{.num} NTU.
````

It renders as:

> We sampled three sites. One site read above the trigger. Mean turbidity
> fell by 8.4% on last year, and the highest reading was 12.6 NTU.

If the data change so that no site reads above the trigger, the second
sentence becomes "No site read above the trigger." If the highest reading
reaches 50, the render fails and names the line, instead of printing a
sentence that has stopped being true.

## Installation

weft is not on CRAN. Install the development version from GitHub:

```r
# install.packages("pak")
pak::pak("vorpalvorpal/weft")
```

or

```r
# install.packages("remotes")
remotes::install_github("vorpalvorpal/weft")
```

weft uses the units package, which needs the udunits-2 library. The CRAN
binaries for macOS and Windows include it. On Linux, install your
distribution's udunits-2 development package first (for example
`libudunits2-dev` on Debian and Ubuntu).

## The main ideas

**Values and formatters.** Inline R with an attribute block, such as
`` `r x`{.num} ``, prints a computed value through a formatter: a number, a
percentage, a spelled count, a list joined with "and". Inline R with no
attribute block prints exactly as knitr prints it. See
[Values and formatters](https://vorpalvorpal.github.io/weft/articles/values.html).

**Wording that depends on a value.** A span such as
`[a site | # sites]{n="k"}` chooses its words from a value: a plural form, a
direction, a condition being true. Each case you expect gets its own
wording. See
[Value-dependent wording and claims](https://vorpalvorpal.github.io/weft/articles/wording.html).

**Claims.** `claim(x, . > 10)` returns `x` unchanged and checks it. When a
check fails, the render fails with a report that names the sentence, instead
of printing a sentence the data no longer support. See
[Value-dependent wording and claims](https://vorpalvorpal.github.io/weft/articles/wording.html).

**Units and the dictionary.** `u(35, m)` makes a number with a unit, and weft
prints the unit for you. The dictionary file `dict.yml` holds the values a
project chose, such as a threshold or a reporting year, each with its
definition. See
[Units and the dictionary](https://vorpalvorpal.github.io/weft/articles/units.html)
and [Using weft with targets](https://vorpalvorpal.github.io/weft/articles/targets.html).

**Lints.** `lints()` reads a project's documents without running them and
lists typed numbers, construct errors and other problems. See
[The static lints](https://vorpalvorpal.github.io/weft/articles/lints.html).

**The commit gate and `verify()`.** A git hook refuses a commit that adds a
typed number or a construct error, or that removes computed values without
saying so. `verify()` renders the whole project and checks every claim before
a release. See
[The commit gate, the ledger and verify()](https://vorpalvorpal.github.io/weft/articles/gate.html).

**Setting up a project.** `use_weft()` writes everything a project needs, and
says what it will write first. See
[Setting up a project](https://vorpalvorpal.github.io/weft/articles/setup.html).
If an AI coding agent edits your documents, read
[Working with coding agents](https://vorpalvorpal.github.io/weft/articles/agents.html).

Start with [Getting started](https://vorpalvorpal.github.io/weft/articles/weft.html).

## Status

weft is a development version (0.0.0.9001). It is not on CRAN, and its
functions and file formats may still change. The design is in
`dev/PACKAGE-SCOPING.md` in the repository. Please report problems at
<https://github.com/vorpalvorpal/weft/issues>.
