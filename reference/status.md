# What weft has installed in a project

Reports the state of each part of the set-up: `setup` (`_weft.yml` and
the version it records), `activation`, `quarto`, `dictionary`, `hooks`,
`ci`, `agent docs`, `draft`, `verify_skip` and `strict`. It writes
nothing, starts no R process and uses no network.

## Usage

``` r
status(path = ".")
```

## Arguments

- path:

  A directory in the project.

## Value

A `weft_status`: a data frame with `part`, `state` and `detail`, and the
attribute [`next`](https://rdrr.io/r/base/Control.html).

## Details

`state` is one of `ok`, `missing`, `outdated` (weft's file is from
another version, or the hook's recorded `Rscript` has gone), `edited` (a
file weft wrote has been changed by hand: it is left alone and never
makes a next step), `off` (draft mode on, or parts of
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
skipped) and `n/a`. The [`next`](https://rdrr.io/r/base/Control.html)
attribute is the first part, in the order of
[`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md),
that is `missing` or `outdated`, as a sentence; otherwise it says there
is nothing to install.
