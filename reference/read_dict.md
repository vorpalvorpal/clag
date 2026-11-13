# Read a dictionary file

`read_dict()` reads a dictionary file, checks every entry against the
schema (see
[dict_file](https://vorpalvorpal.github.io/weft/reference/dict_file.md))
and returns a `weft_dict`: a named list of the values, in file order. In
a knit weft reads `dict.yml` at the project root itself and puts the
result in the document as `dict` (rule 4.1.1), so `read_dict()` is for
use outside a knit.

## Usage

``` r
read_dict(path = "dict.yml")
```

## Arguments

- path:

  One string naming an existing file.

## Value

A `weft_dict`, with the attributes `file`, `scope` (`"project"` or
`"local"`), `entries` (a data frame of the keys' type, definition, unit,
decision, why, line and display), `registered` and `local_keys`.

## Details

Units a quantity names that the `units` package does not know are
installed with
[`units::install_unit()`](https://r-quantities.github.io/units/reference/install_unit.html)
as the file is read, for as long as that project's configuration stays
in force (rule 4.4.7); a unit already known is not installed again. A
read that reports a problem installs no unit. The attribute `registered`
holds the units the dictionary needs that `udunits` does not ship,
whenever and by whomever they were installed, so two reads of one file
give the same `registered`, and
[`print()`](https://rdrr.io/r/base/print.html) lists them.

The units installed are removed when another project's configuration is
read and by `units_reset()`, so a unit one project's dictionary declared
is not known to the next project's document (decision 63). In a knit,
`dict` and `dict_local` are removed at the start of every top-level knit
and assigned again from that knit's own files: a document with neither
sees neither, and an object of the session's own called `dict` is
replaced during a knit that has a dictionary and is not restored.

`dict$key` and `dict[["key"]]` match the key exactly: a key not held is
a `weft_dict_key_error`, never `NULL` (rule 4.1.2). A dictionary is
read-only (rule 4.1.4): assigning to it, `names<-` and `dict[...]` are a
`weft_dict_error`. [`str()`](https://rdrr.io/r/utils/str.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`lapply()`](https://rdrr.io/r/base/lapply.html),
[`Map()`](https://rdrr.io/r/base/funprog.html) and
[`mapply()`](https://rdrr.io/r/base/mapply.html) work on it as they do
on the plain list; `attr<-` and `class<-` cannot be stopped.
[`as.list()`](https://rdrr.io/r/base/list.html) gives the plain named
list of values.

All the problems in a file are collected and raised together as one
`weft_dict_error`. A chunk served from knitr's cache that read `dict` is
not re-run when `dict.yml` changes.

## Examples

``` r
f <- tempfile(fileext = ".yml")
writeLines(c("min_samples:",
             "  value: 5",
             "  type: number",
             "  definition: Fewest samples a site needs."), f)
d <- read_dict(f)
d$min_samples
#> [1] 5
```
