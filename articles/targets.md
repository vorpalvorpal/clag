# Using weft with targets

This article is for projects whose analysis runs in a
[targets](https://docs.ropensci.org/targets/) pipeline and whose reports
are written with weft. It assumes you know
[`vignette("units", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/units.md),
which introduces the dictionary. After it you will be able to make a
pipeline read `dict.yml` so that changing one entry re-runs exactly the
targets that use it, and you will know what weft checks when a report
reads targets.

The chunks in this article need a targets pipeline, so they are not run
when the article is built. The output shown was produced by running
them.

## One target per entry

A pipeline could read the whole dictionary as one object. Then every
target that reads any entry would depend on the whole file, and a change
to one definition would re-run everything.
[`tar_dict()`](https://vorpalvorpal.github.io/weft/reference/tar_dict.md)
avoids that. It returns:

- `dict_file`, a file target for `dict.yml`;
- `dict_values`, which reads the file once per run;
- one target per entry, `dict_<key>`, holding that entry’s value only.

It also attaches the dictionary as `dict` on the search path, so
commands and functions read `dict$trigger` as they would in a document.
[`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md)
then walks the command of each target, and the functions it calls, finds
every `dict$key` and `dict[["key"]]`, and makes `dict_<key>` a
dependency of that target.

Take this `dict.yml`:

``` yaml
trigger:
  value: 10
  type: number
  definition: "Turbidity, in NTU, above which a reading counts as high."
min_samples:
  value: 3
  type: number
  definition: "Fewest readings a gauge needs to be summarised."
```

and this `_targets.R`:

``` r

library(targets)

count_high <- function(readings) {
  sum(readings$ntu > dict$trigger)
}

list(
  weft::tar_dict("dict.yml"),
  weft::tar_dict_deps(list(
    tar_target(readings, data.frame(gauge = c("Upper", "Lower", "Lower"),
                                    ntu = c(4.2, 12.6, 9.1))),
    tar_target(n_high, count_high(readings)),
    tar_target(enough, nrow(readings) >= dict$min_samples)
  ))
)
```

`n_high` reads `dict$trigger` through the function `count_high()`, and
`enough` reads `dict$min_samples` directly. Both are found.

``` r

targets::tar_make()
#> + dict_file dispatched
#> ✔ dict_file completed [1ms, 212 B]
#> + readings dispatched
#> ✔ readings completed [1ms, 156 B]
#> + dict_values dispatched
#> ✔ dict_values completed [1ms, 422 B]
#> + dict_min_samples dispatched
#> ✔ dict_min_samples completed [1ms, 51 B]
#> + dict_trigger dispatched
#> ✔ dict_trigger completed [0ms, 51 B]
#> + enough dispatched
#> ✔ enough completed [1ms, 48 B]
#> + n_high dispatched
#> ✔ n_high completed [0ms, 48 B]
#> ✔ ended pipeline [159ms, 7 completed, 0 skipped]
targets::tar_read(n_high)
#> [1] 1
```

## A changed value re-runs its readers only

Change `trigger` to 9 and run the pipeline again. The per-entry targets
rebuild, but only `n_high` reads the changed value, so `n_high` runs
again and `enough` does not:

``` r

targets::tar_make()
#> + dict_file dispatched
#> ✔ dict_file completed [0ms, 211 B]
#> + dict_values dispatched
#> ✔ dict_values completed [2ms, 421 B]
#> + dict_min_samples dispatched
#> ✔ dict_min_samples completed [1ms, 51 B]
#> + dict_trigger dispatched
#> ✔ dict_trigger completed [0ms, 51 B]
#> + n_high dispatched
#> ✔ n_high completed [1ms, 49 B]
#> ✔ ended pipeline [116ms, 5 completed, 2 skipped]
targets::tar_read(n_high)
#> [1] 2
```

Now reword the definition of `trigger` and run again. No value changed,
so neither reader runs:

``` r

targets::tar_make()
#> + dict_file dispatched
#> ✔ dict_file completed [0ms, 203 B]
#> + dict_values dispatched
#> ✔ dict_values completed [1ms, 416 B]
#> + dict_min_samples dispatched
#> ✔ dict_min_samples completed [1ms, 51 B]
#> + dict_trigger dispatched
#> ✔ dict_trigger completed [0ms, 51 B]
#> ✔ ended pipeline [116ms, 4 completed, 3 skipped]
```

A new entry, or a reordered file, likewise re-runs no reader.

## Mistakes the pipeline catches

The attached `dict` checks, while a target runs, that the target depends
on every entry it reads. A target left out of
[`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md)
stops the run instead of using a value the pipeline does not track:

``` r

# _targets.R
list(
  weft::tar_dict("dict.yml"),
  tar_target(limit, dict$trigger * 2)
)
```

``` text
Error in tar_make():
  weft: the target `limit` reads `dict$trigger`, and does not depend on `dict_trigger`. Pass the target through tar_dict_deps(), which adds the entries it reads; a read it cannot see, such as eval(parse(text = )), cannot be tracked (rule 4.6.2).
  See https://books.ropensci.org/targets/debugging.html
```

A key the dictionary does not hold is an error before anything runs,
with the nearest key:

``` r

# _targets.R
list(
  weft::tar_dict("dict.yml"),
  weft::tar_dict_deps(list(tar_target(limit, dict$triger * 2)))
)
```

``` text
Error in tar_make():
  weft: dict.yml: 1 unknown key(s) read by the pipeline
  `limit` reads `dict$triger`, which dict.yml does not hold (rule 4.6.4). Did you mean `trigger`?
  See https://books.ropensci.org/targets/debugging.html
```

An object called `dict` in `_targets.R` is an error too, because targets
would track the whole object:

``` text
Error in tar_make():
  weft: `dict` is an object in the pipeline's environment (the global environment when `callr_function = NULL`, so it may come from this R session), so targets tracks it and every target that reads it re-runs when any entry changes, its definition included. Remove `dict <- ...` from _targets.R, or `rm(dict)` in the session: tar_dict() provides `dict` (rule 4.6.3).
  See https://books.ropensci.org/targets/debugging.html
```

So are a second
[`tar_dict()`](https://vorpalvorpal.github.io/weft/reference/tar_dict.md)
call, and a target of your own called `dict_file`, `dict_values` or
`dict_<key>`.

A read of the whole dictionary, such as `dict[[k]]` with a computed `k`,
depends on every entry.

## Reports in the pipeline

A report rendered by
[`tarchetypes::tar_render()`](https://docs.ropensci.org/tarchetypes/reference/tar_render.html)
or
[`tarchetypes::tar_quarto()`](https://docs.ropensci.org/tarchetypes/reference/tar_quarto.html),
passed through
[`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md),
is scanned the same way: its chunks, its inline R and the expressions of
its spans, and the files it includes. This report reads one target and
one entry:

```` markdown
---
title: "Turbidity"
output: md_document
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---

```{r data}
n_high <- targets::tar_read(n_high)
```

[No gauge | One gauge | # gauges]{n="n_high"} read above `r dict$trigger` NTU.
````

``` r

# _targets.R
library(targets)
library(tarchetypes)

list(
  weft::tar_dict("dict.yml"),
  weft::tar_dict_deps(list(
    tar_target(readings, data.frame(ntu = c(4.2, 12.6, 9.1))),
    tar_target(n_high, sum(readings$ntu > dict$trigger)),
    tar_render(report, "report.Rmd")
  ))
)
```

``` r

targets::tar_make(reporter = "silent")
e <- targets::tar_network(targets_only = TRUE)$edges
e[e$to == "report", ]
#> # A tibble: 2 × 2
#>   from         to
#>   <chr>        <chr>
#> 1 dict_trigger report
#> 2 n_high       report
```

The report renders “One gauge read above 10 NTU.” and re-renders when
`trigger` or `n_high` changes, and not when `min_samples` does. A child
document or an include whose path the scan cannot work out makes the
report depend on every entry.

## What weft records when a document reads targets

In a set-up project (see
[`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md)),
each render writes a **ledger** for the document. Its first line records
what the document read: the dictionary entries, its source files, and
each target read with
[`tar_read()`](https://docs.ropensci.org/targets/reference/tar_read.html)
or
[`tar_load()`](https://docs.ropensci.org/targets/reference/tar_load.html)
with a literal name, each with a hash. For the report above:

``` text
{"weft":"ledger","version":1,"source":"report.Rmd","output":"report","dict":{"trigger":"b9cd8368c7b4cdea"},"files":{"report.Rmd":"0b4b641383bc84b3"},"targets":{"_targets":{"n_high":"7aad2777504291d0"}}}
```

When a target changes after the document was rendered, the document’s
values were **not re-rendered**.
[`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
marks them, and
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
fails on them until the document is rendered again. See
[`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md).

The ledger’s condition log also records the warnings and errors that
[`targets::tar_meta()`](https://docs.ropensci.org/targets/reference/tar_meta.html)
holds for each target the document reads and the targets upstream of it,
so a warning raised inside the pipeline shows in the diff of the log.

Two lints concern targets (see
[`vignette("lints", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/lints.md)):

- `tar-name`: every
  [`tar_read()`](https://docs.ropensci.org/targets/reference/tar_read.html)
  and
  [`tar_load()`](https://docs.ropensci.org/targets/reference/tar_load.html)
  names a target in the store. The names come from the store’s metadata,
  so no project code runs.
- `tar-cache`: a chunk that reads a target does not have `cache: true`,
  because knitr’s cache would not see the target change.

## Limits

`dict` is attached in the R session that defines the pipeline. A
parallel `crew` worker does not have it, so a function that reads `dict`
fails there with “object ‘dict’ not found”. Pass the values the function
needs as arguments, or run the pipeline without workers.

A read that
[`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md)
cannot see, such as code built with `eval(parse(text = ))`, stops the
first run with the error above. It never gives a stale number.
