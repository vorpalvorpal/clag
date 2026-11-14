# Python and Julia chunks

This article is for authors who compute with Python or Julia and want
weft’s values and checks in the prose around that code. It assumes you
know
[`vignette("values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/values.md)
and
[`vignette("wording", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/wording.md).
After it you will be able to print a Python or Julia value in a
sentence, govern wording with it, call weft’s formatters from Python,
and know what weft checks in such a document and what it cannot check.
For a document that is not knit, see
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md).

The chunks in this article need Python or Julia, so most of them are not
run when the article is built. The output shown was produced by running
them.

## What works and where

weft is an R package that works inside knitr. A document with Python or
Julia chunks works when knitr knits it: an `.Rmd`, or a Quarto `.qmd`
with `engine: knitr` in its front matter. R is installed and runs the
render. Python chunks run through the R package reticulate, and Julia
chunks through the R package JuliaCall. The prose is still R: a Python
or Julia value reaches a sentence through an R expression.

For a Quarto author this means one line in the front matter:

``` yaml
---
title: "River survey"
engine: knitr
---
```

A `.qmd` that Quarto runs with its Jupyter or Julia engine has no R to
evaluate prose, so an R expression in it is not evaluated and prints as
text. Such a document can still use weft: write a value by name,
`` `depth`{.num} ``, publish it from the Python or Julia code, and
weft’s Pandoc filter fills it in. That route is described in
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md).
Everything below is for documents that knitr knits.

## Setting up

You need:

- for Python chunks, the R package reticulate and a Python it can find;
- for Julia chunks, Julia, the R package JuliaCall, and the Julia
  package RCall that JuliaCall uses;
- weft turned on in the document, as for any weft document (see
  [`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md)).

Prose needs no
[`library(reticulate)`](https://rstudio.github.io/reticulate/) and no
[`library(JuliaCall)`](https://github.com/JuliaInterop/JuliaCall).
[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
loads neither, and starts neither Python nor Julia. A document with no
Python or Julia in it never loads them.

weft never installs Python, Julia or a package for either. To choose a
Python, set `RETICULATE_PYTHON` in your `.Renviron`. When weft starts
Python itself and `RETICULATE_USE_MANAGED_VENV` is not set, it sets it
to `no` for that start, so reticulate does not download a Python of its
own. R code of yours that starts Python first follows reticulate’s own
rules. For Julia, run
[`JuliaCall::julia_setup()`](https://rdrr.io/pkg/JuliaCall/man/julia_setup.html)
once by hand: it installs RCall. weft starts Julia with
`installJulia = FALSE` and `install = FALSE`, so it installs nothing.

Python chunks must run through reticulate’s engine, knitr’s default.
With the chunk option `python.reticulate = FALSE` each chunk is a
separate Python process, and weft cannot read its values.

## A Python value in a sentence

Write a Python value in prose as reticulate’s documentation does:
`` `r py$depth` ``. Every weft construct takes it.

```` markdown
---
title: "River survey"
output: md_document
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---

```{python survey}
depth = 3.14159
visits = 12
sites = ['Upper', 'Lower', 'Weir']
flagged = ['Weir']
rising = True
```

Mean depth was `r py$depth`{.num} m at `r py$sites`{.and}.
We made `r py$visits`{.word} visits, and
[no site was | # was | # were]{list="py$flagged"} flagged.
Turbidity [rose | fell]{if="py$rising"} over the year.
The deepest reading was `r claim(py$depth, . < 5)`{.num} m.
````

renders as:

``` text
Mean depth was 3.1 m at Upper, Lower and Weir. We made twelve visits,
and Weir was flagged. Turbidity rose over the year. The deepest reading
was 3.1 m.
```

`claim(py$depth, . < 5)` is a check, as in any weft document. In a
Quarto document the value is written `` `{r} py$depth`{.num} ``.

## Why weft reads Python values itself

A Python integer can be any size. R holds whole numbers exactly only up
to 2^53, about 9 × 10^15. reticulate converts a Python value to an R
value in its compiled code, before any R code sees it, and for some
large integers the result is a wrong number with no error. `2**53 + 1`
arrives in R as `1`. Once it is `1`, nothing can tell it from a right
`1`.

So in every expression weft evaluates (a value, a bare value, a
governor, a caption on an R chunk, a string given to
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)),
weft reads `py$name`, `py[["name"]]` and chains such as `py$cfg$depth`
itself. It reads the Python object, decides its kind from its Python
type, and refuses a value that R cannot hold exactly:

```` markdown
```{python count}
particles = 2**53 + 1
```

```{r compare}
reticulate::py$particles
```

The filter caught `r py$particles`{.num} particles.
````

The R chunk shows what reticulate’s conversion gives:

``` text
reticulate::py$particles
## [1] 1
```

The sentence does not print “1”. The render fails with:

``` text
weft: 1 failure
  count.Rmd:17  [value error] `r py$particles`
      `py$particles` is the Python int 9007199254740993, beyond ±2^53, where R cannot hold a whole number exactly. Scale it in Python, or bind str() of it and print the text (rule 2.12.5).
```

What R does with the value after weft has read it is R’s:
`` `r length(py$sites)` `` and `` `r py$slope > 0` `` work as they would
on an R vector. If an R chunk binds an object called `py`, prose reads
that object, not Python. A call such as `py$f(2)` is reticulate’s,
unchanged.

## What each Python type becomes

The kind comes from the Python type, never from how the value prints.

| Python | In R |
|----|----|
| `True`, `False`, `numpy.bool_` | `TRUE`, `FALSE` |
| `int` and numpy integers, up to 2^31 − 1 in size | an integer |
| the same, from 2^31 to 2^53 in size | a double, exact |
| the same, beyond 2^53 | refused |
| `float` and numpy floats | a double |
| `decimal.Decimal`, up to 15 significant digits | the nearest double |
| `decimal.Decimal`, more digits | refused: round it with `quantize()` |
| `str` | a string |
| `datetime.date`, `numpy.datetime64` in days | a `Date` |
| `datetime.datetime`, `pandas.Timestamp` | refused: convert with `.date()` |
| `list`, `tuple`, a one-dimensional numpy array, `pandas.Series` | a vector |
| `dict` whose keys are all `str` | a vector with names, in the dict’s order |
| `set`, `frozenset` | refused: bind `sorted()` of it |
| a numpy array of two or more dimensions | refused |
| anything else (`complex`, `bytes`, `fractions.Fraction`, `pandas.DataFrame`, an object of your own class) | refused |

A bool is never read as a number, though Python’s `bool` is a kind of
`int`.

A list is read element by element. Its elements must be of one kind,
with two mixes allowed: integers with floats make floats, and integers
with decimals make decimals. `[1, 'a']` is refused, and so is a list
that holds a list:

``` text
`py$mixed` is a Python list whose elements are of more than one kind (integer, string); weft reads a list whose elements are all of one kind (rule 1.11.4).
`py$nested` is a Python list that holds a list; weft reads a flat list (rule 1.11.4).
```

A refusal found on one element names it: “Element 2 of `` `py$x` `` is a
Python datetime.datetime, …”.

## Missing values

These Python values are **missing**: `None`, a float NaN or infinity
(numpy’s too), `Decimal('NaN')` and `Decimal('Infinity')`, `pandas.NA`,
`pandas.NaT` and `numpy.datetime64('NaT')`. A missing element of a list
is allowed anywhere: `[3, None, 5]` is `c(3L, NA, 5L)`.

A missing value given to a formatter or a governor is a “no value”
failure, as an R `NA` is. A bare `` `r py$gap` `` with `gap = None`
prints “NA”. An empty list is not missing: it is a list of length zero,
and the rules for length zero apply
([`vignette("values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/values.md)).

## Conditions are bools

Python treats `[]`, `0` and `''` as false in an `if`. weft does not.
When an `if` condition is exactly one Python read, the value must be a
bool. Anything else is a value error, not false, because a sentence
chosen by an accident of truthiness is a wrong sentence:

```` markdown
```{python flags}
flagged = []
has_flags = len(flagged) > 0
```

[Some sites were | No site was]{if="py$flagged"} flagged.
[Some sites were | No site was]{if="py$has_flags"} flagged.
[Some sites were | No site was]{if="length(py$flagged) > 0"} flagged.
````

``` text
weft: 1 failure
  truth.Rmd:14  [value error] "Some sites were"
      `py$flagged` is a Python list; an `if` condition must be a bool (rule 1.11.8).
```

The second and third lines print “No site was flagged.”. Write the test
in Python, as `has_flags` does, or in R, as the third line does. The
same holds for the other governors: an `n` or `sign` governor that is
exactly one Python read must be a number (a list of one number is not),
and a `list` span needs a list.

## Python values in R code

In an R chunk, `py$x` is reticulate’s conversion: weft does not rewrite
R chunk code. To read a value in R code by the same rules as prose, use
[`py_value()`](https://vorpalvorpal.github.io/weft/reference/py_value.md).
Each argument is one step of a path: a name, then a key of a dict or an
attribute.

```` markdown
```{python fit}
means = {'Upper': 1.25, 'Lower': 3.4}
```

```{r in-r}
py_value("means")
py_value("means", "Upper")
```
````

``` text
py_value("means")
## Upper Lower
##  1.25  3.40
py_value("means", "Upper")
## [1] 1.25
```

[`py_value()`](https://vorpalvorpal.github.io/weft/reference/py_value.md)
works at the console too, and needs no
[`library(reticulate)`](https://rstudio.github.io/reticulate/). A pandas
`DataFrame` for a plot is still reticulate’s to convert:
[`py_value()`](https://vorpalvorpal.github.io/weft/reference/py_value.md)
refuses a table, because a table has no place in a sentence.

## Formatting from Python

weft’s function forms are a Python module, `weft`, while a document is
knitted. Import from it as from any module:

```` markdown
```{python labels}
from weft import fmt_num, fmt_and, plural
print(fmt_num(3.14159))
print(fmt_and(['Upper', 'Lower', 'Weir']))
print(plural(3, "# site", "# sites"))
try:
    fmt_num(2**53 + 1)
except Exception as e:
    print(e)
print(r.fmt_num(2**53 + 1))
```
````

``` text
## 3.1
## Upper, Lower and Weir
## 3 sites
## Argument 1 of fmt_num() is the Python int 9007199254740993, beyond ±2^53, where R cannot hold a whole number exactly. Scale it in Python, or bind str() of it and print the text (rule 2.12.5).
## 1
```

Each function returns what the R function of that name returns: one
string as a `str`, several as a `list` of `str`. Its arguments are read
by the rules above, so `fmt_num(2**53 + 1)` raises an exception with
weft’s message.

The last line shows why `r.fmt_num()` is a lint finding. reticulate’s
`r` object hands the Python arguments to R through the same conversion,
and `2**53 + 1` arrives as `1`.

The module holds `fmt_num`, `fmt_pct`, `fmt_sci`, `fmt_p`, `fmt_date`,
`fmt_no`, `fmt_word`, `fmt_count`, `fmt_ord`, `fmt_and`, `fmt_or`,
`fmt_pairs`, `fmt_range`, `fmt_ul`, `fmt_ol`, `fmt_dl`, `fmt_a`,
`fmt_cap`, `fmt_strong`, `fmt_em`, `plural`, `ci`, `pm`, `about`, `of_n`
and `weft_str`. The module also holds `claim`, `put` and `auto`:
`claim(n, "> 10")` checks in Python where it runs, and `put()` and
`auto()` publish names for the filter (see
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md)).
`u`, `fmt_unit`, `lookup`, `brk` and the dictionary functions are not
there. A check on a value in prose is still written in R, as
`` `r claim(py$n, . > 10)` ``. If a module called `weft` is already
loaded in Python, weft leaves it in place and warns once.

## Text with constructs from Python

Text a Python chunk prints with `results = "asis"` is not resolved by
weft. To print a sentence with constructs from Python, pass it through
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
from the module. The expressions inside the markup are R, so they read
Python values with `py$`:

```` markdown
```{python summary, results = "asis"}
from weft import weft_str
print(weft_str('Turbidity [rose | fell]{if="py$slope > 0"} over the year.'))
```
````

``` text
Turbidity rose over the year.
```

A check that fails inside it is collected, located by the chunk’s label,
and fails the render once at the end.

## Captions

weft resolves a caption written in an R chunk’s options (see
[`vignette("values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/values.md)),
but not one written in a Python or Julia chunk’s options. A construct
there is a construct error, found by the lints and at knit time. A named
value does work in any caption (see
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md)).
In a Quarto document that knitr knits, write the caption in a figure or
table div instead, where it is prose:

```` markdown
::: {#fig-depth}
```{python depth-plot}
plot_depths()
```

Depth at [one site | # sites]{n="py$n_sites"}.
:::
````

## Warnings and errors

Every warning Python shows while a document is knitted goes into the
document’s condition log, as an R warning does (see
[`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md)).
It still prints where it printed before. For a chunk `model` that runs
`warnings.warn("fit did not converge")`, the log holds:

``` text
{"from":"chunk","source":"model","class":"warning","normalised":"UserWarning: fit did not converge","text":"UserWarning: fit did not converge"}
```

A Python exception in a chunk with `error = TRUE` is logged too, with
class `error` and text such as `ValueError: no readings for Weir`.
Without `error = TRUE` the knit stops, as it does without weft. A chunk
served from knitr’s cache replays the conditions it logged when it ran.

The `severity` list in `_weft.yml` applies to Python warnings. With
`severity: ["did not converge"]` the same document fails the render:

``` text
weft: 1 failure
  fit.Rmd chunk model  [condition]
      warning: UserWarning: fit did not converge
      matched the severity pattern did not converge
```

Not logged: text a chunk prints to `sys.stderr`, output of Python’s
`logging` module, and warnings that a warnings filter hides.

## Files the document read

The ledger’s header records the files a document read, with a hash of
each (see
[`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md)).
A Python module whose file lies inside the project, and that is loaded
when the knit ends, is one of them. With `import trend` in a chunk and
`trend.py` beside the document:

``` text
{"weft":"ledger","version":1,"source":"fit.Rmd","output":"fit","dict":{},"files":{"fit.Rmd":"fed61ddb49d8fa42","trend.py":"5dc4f531ced53f1e"},"targets":{}}
```

Edit `trend.py` and the document’s values are listed as not re-rendered
until it is rendered again. Modules under `site-packages`, a virtual
environment, `renv` or a folder whose name starts with `.` are left out.
A literal path given to
[`reticulate::source_python()`](https://rstudio.github.io/reticulate/reference/source_python.html)
or
[`reticulate::py_run_file()`](https://rstudio.github.io/reticulate/reference/py_run.html)
in an R chunk is recorded too. Data files that Python reads, such as a
CSV given to `pandas.read_csv()`, are not, as for R.

## The lints

The static lints read a Python or Julia document as they read any other
(see
[`vignette("lints", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/lints.md)).
Code rules read R chunks only, so a Python chunk that assigns `dict` or
reads `tar_read` gives no finding. Four rules are about other languages:

| Id | Tier | Finds | What to do |
|----|----|----|----|
| `guest-inline` | 1 | inline code in another language, such as `` `{python} depth` ``, which knitr prints as code | bind the value to a name in a chunk and write `` `r py$depth` `` or `` `r jl_value("depth")` `` |
| `guest-call` | 1 | `r.fmt_num()` and the other function forms called from Python through reticulate’s `r` object | `from weft import fmt_num`; a [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) belongs in prose |
| `guest-read` | 2 | `py$x` in R chunk code, and a reticulate or JuliaCall call (`py_eval()`, `julia_eval()`) in an expression weft evaluates | read the value with [`py_value()`](https://vorpalvorpal.github.io/weft/reference/py_value.md) or [`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md); leave a data frame for a plot as it is |
| `ojs-value` | 2 | an Observable value in prose | see “Observable JS” below |

This project has one `.Rmd` with each kind of mistake, and a `.qmd` set
to run with Jupyter:

``` r

library(weft)
writeLines("", "_weft.yml")
writeLines(c(
  "---",
  "title: \"Depths\"",
  "---",
  "",
  "```{python depths}",
  "depth = 3.14159",
  "label = r.fmt_num(depth)",
  "```",
  "",
  "```{python depth-plot}",
  "#| fig-cap: |",
  "#|   Depth at [one site | # sites]{n=\"k\"}.",
  "#| fig-alt: \"Depth by site.\"",
  "plot_depths()",
  "```",
  "",
  "```{r plot-data}",
  "d <- py$depth",
  "```",
  "",
  "Mean depth was `{python} depth` m.",
  "Mean depth was `r py_eval(\"depth\")`{.num} m."
), "depths.Rmd")
writeLines(c(
  "---",
  "title: \"Report\"",
  "jupyter: python3",
  "---",
  "",
  "```{python}",
  "#| label: count",
  "n = 12",
  "```",
  "",
  "We visited [one site | # sites]{n=\"n\"}."
), "report.qmd")
lints(tier = 1:2)
```

    #> weft lints: 6 findings in 2 files (4 tier 1, 2 tier 2)
    #> 
    #> depths.Rmd
    #>   7:9    guest-call    `r.fmt_num()` passes its arguments through reticulate, which can turn a Python int into a wrong number with no error. Write `from weft import fmt_num` and call `fmt_num()` (rule 5.11.2).
    #>   12:15  construct     A `n` construct in a caption of chunk `depth-plot`, which uses the `python` engine, not R: write the caption in a figure or table div instead, `::: {#fig-name}` ... caption paragraph ... `:::` (rules 1.10.5, 2.3.5).
    #>   18:6   guest-read    `py$depth` in R code is converted by reticulate, which can turn a Python int into a wrong number with no error. For a value that reaches prose, read it with py_value("depth") (rule 5.11.3).
    #>   21:16  guest-inline  `{python} depth` is inline Python, which the knitr engine does not run: it would print as code. Bind the value to a name in a Python chunk and write `r py$name` (rule 5.11.1).
    #>                        A value from another language reaches prose through R; see vignette("languages", package = "weft").
    #>   22:19  guest-read    `py_eval("depth")` is converted by reticulate, which weft does not check (rule 5.11.3).
    #> 
    #> report.qmd
    #>   1:1  engine  report.qmd holds named values, and the filter weft.lua is not installed: run use_quarto() (rule 5.8.9).
    #>                Run use_quarto() to install the weft-check extension, which carries the filter.

[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
leaves `report.qmd` as it is, because it names the Jupyter engine. It
adds `engine: knitr` to a `.qmd` of Python or Julia chunks alone, with
no engine named, only when that page holds an R value or a span outside
the filter’s grammar. A page whose constructs are all named values is
left for the filter. The `engine` finding above says so: `report.qmd`’s
span names its governor, so it is the filter’s, and the filter is not
installed in this folder.
[`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
installs it.

The commit gate treats `guest-inline` and `guest-call` like any tier-1
rule: a commit that adds one fails. A markup string built in Python
code, such as `weft_str('...')` in a Python chunk, is not read: its
constructs are not counted by the gate and its prose is not linted.

## Julia

### A Julia value in a sentence

A Julia chunk runs through JuliaCall. Julia runs inside the R process:
the first Julia chunk starts it, which takes 5 to 10 seconds, and its
variables then carry from chunk to chunk, and from document to document
in one R session.

A Julia value reaches prose through
[`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md),
an R function. Its first argument names a variable of Julia’s `Main`.
Each further argument is a key of a dictionary or a field of a
`NamedTuple` or struct.

```` markdown
```{julia survey}
include("trend.jl");
depth = 3.14159;
sites = ["Upper", "Lower", "Weir"];
rising = slope([1.0, 1.4, 1.9]) > 0;
means = (Upper = 1.25, Lower = 3.4);
@warn "fit did not converge"
```

```{r in-r}
jl_value("sites")
jl_value("means", "Upper")
```

Mean depth was `r jl_value("depth")`{.num} m at `r jl_value("sites")`{.and}.
Turbidity [rose | fell]{if="jl_value('rising')"} over the year.
Mean turbidity was `r jl_value("means")`{.num .pairs} NTU.
````

``` text
jl_value("sites")
## [1] "Upper" "Lower" "Weir"
jl_value("means", "Upper")
## [1] 1.25

Mean depth was 3.1 m at Upper, Lower and Weir. Turbidity rose over the
year. Mean turbidity was Upper (1.3) and Lower (3.4) NTU.
```

Inside an attribute value, write the name in single quotes:
`{if="jl_value('rising')"}`. A double quote escaped as `\"` ends the
attribute value, so the block does not parse.

[`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md)
means the same in prose, in an R chunk and at the console. It starts
Julia when Julia is not yet running. It reads the value inside Julia and
hands R only text, so JuliaCall’s conversion never runs on it.

### Why the spelling differs from Python’s

For Python, weft reads `py$x` because that is what every reticulate
author already writes, and reticulate’s conversion of it is wrong
without an error. JuliaCall has no such common spelling, and its own
conversion fails loudly: it stops with an error on a whole number of
2^31 or more, and it ends the R process on a Julia `missing`. So weft
offers a plain function, the same in every place, and adds no `jl`
object. Prose copied into an R chunk keeps working.

`JuliaCall::julia_eval("x")` in an R chunk is JuliaCall’s, and weft does
not list it. In prose the `guest-read` lint lists it:

``` text
`JuliaCall::julia_eval("depth")` is converted by JuliaCall, which stops on a whole number beyond ±2^31 and crashes R on a Julia missing. Read a Julia value with jl_value() (rule 5.11.3).
```

### What each Julia type becomes

| Julia | In R |
|----|----|
| `true`, `false` | `TRUE`, `FALSE` |
| any other integer (`Int64`, `UInt8`, `BigInt`, …), up to 2^31 − 1 in size | an integer; `UInt8(200)` is `200L` |
| the same, from 2^31 to 2^53 in size | a double, exact |
| the same, beyond 2^53 | refused |
| `Float64`, `Float32`, `Float16` | a double; `Float32(0.1)` is the double it holds, 0.10000000149011612, and prints “0.1” under `{.num}` |
| `Rational` (`1//3`), `Irrational` (`pi`), `BigFloat` | refused: convert with `Float64()` |
| `String`, `Char`, `Symbol` | a string; `:north` is “north” |
| `Dates.Date` | a `Date` |
| `Dates.DateTime` | refused: convert with `Dates.Date()` |
| `missing`, `nothing`, and `NaN`, `Inf`, `-Inf` of any float type | missing |
| a vector, a range such as `1:3`, a `Tuple` | a vector |
| a `NamedTuple` | a vector with names, in its order |
| a `Dict` or any other dictionary, a `Set` | refused: bind a `NamedTuple` or a sorted vector |
| an array of two or more dimensions | refused |
| anything else (`Complex`, a function, a `DataFrame`, a struct of your own) | refused |

The list rules are Python’s, with one allowed mix: integers with floats
make floats. Julia has no decimal kind. Missing values, `if`, `n`,
`sign` and `list` follow the same rules as for Python.

A `Dict` is refused because its order is the order of its hashes, not
the order you wrote, so a sentence would list its entries in an order
nobody chose. A `Rational`, `pi` or `BigFloat` is refused because R
cannot hold it exactly, and weft does not round on your behalf:

```` markdown
```{julia kinds}
share = 1//3;
means = Dict("Upper" => 1.25, "Lower" => 3.4);
```

A third is `r jl_value("share")`{.num}.
Mean turbidity was `r jl_value("means")`{.num .pairs} NTU.
````

``` text
weft: 2 failures
  kinds.Rmd:14  [value error] `r jl_value("share")`
      `jl_value("share")` is a Julia Rational{Int64}, which R cannot hold exactly. Convert it in Julia with Float64(), and round it there if it should print as written (rule 1.11.2).
  kinds.Rmd:15  [value error] `r jl_value("means")`
      `jl_value("means")` is a Julia Dict{String, Float64}, which has no order. Bind a NamedTuple, or a sorted vector, in a Julia chunk (rule 1.11.4).
```

Write `share = Float64(1//3)` and `means = (Upper = 1.25, Lower = 3.4)`
instead. A `Dict` may sit on the path of a read, as in
`jl_value("cfg", "depth")`; only the last value must be readable.

### Warnings, errors and included files

Julia’s `@warn` and `@error` records go into the condition log, with
class `warning` or `error` and the message as the text. The chunk
`survey` above logs:

``` text
{"from":"chunk","source":"survey","class":"warning","normalised":"fit did not converge","text":"fit did not converge"}
```

A warning raised in a file the chunk includes belongs to that chunk.
Julia still prints the warning to the render log, never into the
document. A record with `maxlog = 1` is logged once. The `severity` list
applies.

Not logged: `@info` and `@debug`, text printed to `stderr`, and records
that a chunk’s own logger takes. A chunk that replaces Julia’s global
logger ends weft’s recording for the R session. Julia code that an R
chunk runs before the first Julia chunk and before the first
[`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md)
is not logged.

A Julia error stops the knit, with or without `error = TRUE`, because
JuliaCall’s engine raises it as an R error. A chunk whose last line’s
value is a single `missing` also stops it: end that line with `;`, as in
`gap = missing;`.

A file that `include()` loads from the project is a file the document
read, with its hash in the ledger’s header. The chunk above gives:

``` text
{"weft":"ledger","version":1,"source":"survey.Rmd","output":"survey","dict":{},"files":{"survey.Rmd":"f43c73333eead6a1","trend.jl":"bd0afd2a856b00d8"},"targets":{}}
```

So is a literal path given to
[`JuliaCall::julia_source()`](https://rdrr.io/pkg/JuliaCall/man/julia_source.html)
in an R chunk. A file that a package loads through `using` is not.

### Julia on Linux

On Linux, R puts the system’s library folders first on the library
search path. Julia started inside R could then load the system’s
`libunwind` instead of its own, and crash with a segmentation fault the
first time it handled an exception, even one caught at once
(precompiling a package does this). weft now loads Julia’s own
`libunwind` before it starts Julia, and starts any Julia child process,
such as a render on the Julia engine from
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md),
without those folders on the path. If an R chunk calls
[`JuliaCall::julia_setup()`](https://rdrr.io/pkg/JuliaCall/man/julia_setup.html)
itself before the first Julia chunk or
[`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md)
read, weft cannot step in first, and with JuliaCall 0.17.6 (the CRAN
release) the crash can still happen. Leave starting Julia to weft. macOS
is not affected.

### Calling weft from Julia

weft offers no Julia module of function forms. (The Julia package `Weft`
has `put`, `@put` and `@claim`, none of them a function form.) Julia
code can call weft’s R functions through RCall, as it calls any R
function (`R"weft::fmt_num($x)"`), and gets RCall’s conversion. RCall
stops with an error on a whole number of 2^31 or more and on `missing`,
hands R a `Rational` or `pi` as an object that
[`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
refuses, and hands it a `UInt8` as a raw byte, which
[`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
refuses too. An R error reaches Julia with an empty message. Format in
prose with
[`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md)
instead.

## Observable JS

An `{ojs}` chunk runs in the reader’s browser, after the render and
after every weft check has run. A value it computes can change with what
the reader does, so weft cannot vouch for it. In a `.qmd` the
`ojs-value` lint (tier 2) lists each inline `` `{ojs} total` `` in
prose, and each `${...}` inside an `md` or `html` template in an `{ojs}`
chunk:

``` text
`{ojs} total` is computed in the reader's browser after weft's checks have run, so weft cannot vouch for it (rule 5.11.4).
```

Compute a number that a sentence states when the document renders, in R
or Python, and print it as a weft value. To draw a chart from the same
checked value, pass it to Observable with `ojs_define()`. Text that must
stay reactive can be marked `[...]{.weft-literal why="..."}`.

## Limits

- Units and the dictionary stay in R.
  [`u()`](https://vorpalvorpal.github.io/weft/reference/u.md),
  [`fmt_unit()`](https://vorpalvorpal.github.io/weft/reference/fmt_unit.md)
  and `dict` are not in the Python module, and no value from Python or
  Julia carries a unit.
- A caption on a Python or Julia chunk cannot hold a construct. Use a
  figure or table div.
- Observable values cannot be vouched for.
- Your CI needs Python or Julia set up to render.
  [`use_ci()`](https://vorpalvorpal.github.io/weft/reference/use_ci.md)
  writes a job that runs the static checks only, which need neither. A
  job that renders documents with Python chunks must install Python and
  the modules they import; one with Julia chunks must install Julia,
  JuliaCall and RCall.
- A Julia `OrderedDict` is refused, as every dictionary is. Bind a
  `NamedTuple`.
- weft offers no function forms from Julia.
- A whole number beyond 2^53 is refused. Bind
  [`str()`](https://rdrr.io/r/utils/str.html) (Python) or `string()`
  (Julia) of it and print the text.
- A markup string built in Python code is neither linted nor counted by
  the gate.
- A Python module or Julia file loaded only by a chunk served from
  knitr’s cache is not recorded in that render.
- An R session that knits several documents may record a Python module
  that an earlier document imported. That can mark a value as not
  re-rendered when it need not be, never the reverse.
- Python chunks need reticulate’s engine; `python.reticulate = FALSE` is
  not supported.
- A Python or Julia
  [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
  stops its chunk at once even under `chunk_claims: collect`, and takes
  no `decision` pointer.
- Tables that a Python or Julia chunk prints are not recorded in the
  ledger, nor are tables in a document on the Jupyter or Julia engine.
- [`checks()`](https://vorpalvorpal.github.io/weft/reference/checks.md)
  and the gate’s check lines do not read Python or Julia checks; they
  list them as not read.
