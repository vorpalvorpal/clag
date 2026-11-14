# Checks of one value, compared

`checks()` lists every check a project's documents make on a value and
groups them by value, so that a value checked in several places with
conditions that differ a little (`x > 5` here, `x >= 5` there) shows. A
check is a guard (each comma part of a one-arm `if`), a check argument
of a
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md), or,
here only, a comma part of a two-arm `if`, which chooses wording and
fails nothing (a `branch`). Only checks weft can read are compared: a
comparison whose sides are names, dictionary reads, expressions such as
`max(turbidity)` and literals, or a bool name; the rest are listed under
`not read`. Nothing in a document is run.

## Usage

``` r
checks(path = ".", files = NULL, repeats = 3L)

# S3 method for class 'weft_checks'
print(x, ...)
```

## Arguments

- path:

  One existing file or folder. The project root is found from it.

- files:

  `NULL`, or documents (relative to the root or absolute under it) to
  report on.

- repeats:

  A whole number from 2: how many places make a hint.

- x:

  A `weft_checks`.

- ...:

  Not used.

## Value

A `weft_checks` data frame, one row per check, with columns `file`,
`line`, `role`, `level`, `value`, `op`, `other`, `cond` (`NA` when the
check is not readable), `text`, `always`, `rebound`, `flag` and
`repeated`, and the attribute `notes`. Printing it shows the report.

## Details

A value is *flagged* when two of its checks compare it with the same
other operand under operators that differ only in strictness
(`operators`), or with different literals in one direction (`literals`).
The report hints at checks made in `repeats` places or more with the
same condition: check once, where the value is made.

## Examples

``` r
dir <- file.path(tempdir(), "checks-example")
dir.create(dir, showWarnings = FALSE)
writeLines(c("The site [exceeded]{if=\"flow > limit\"} the limit.", "",
             "In March it [reached]{if=\"flow >= limit\"} the limit."), file.path(dir, "report.Rmd"))
checks(dir)
#> weft checks: 2 checks of 1 value in 1 document; 1 value flagged
#> 
#> report.Rmd
#>   flow  [operators]
#>     flow > limit   1  line 1
#>     flow >= limit  1  line 3
#> 
```
