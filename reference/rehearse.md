# Knit a document under several cases and see which arms they choose

Knits `file` once for each case, each in a fresh R process, and reads
back what the knit recorded: the failures, and the arm that each
governed span chose. The result says which arms no case reached and
which spans no case evaluated, so that a manuscript's wording can be
checked for every value its parameters may take (rules 3.7.1 to 3.7.4).

## Usage

``` r
rehearse(file, cases)
```

## Arguments

- file:

  The path of a `.qmd` or `.Rmd` document.

- cases:

  A named list. Each element is a named list of the parameters that case
  sets (an empty list for the defaults).

## Value

An object of class `weft_rehearsal`, a list:

- `cases`: a named list, one element per case, each a list of `ok` (no
  failures and the knit finished), `error` (the message when the knit
  itself stopped, else `NA`), `failures` (the data frame of
  `last_knit()$failures`), `warnings` (the data frame of
  `last_knit()$warnings`; `ok` ignores it) and `chosen` (a data frame of
  `span`, `file`, `line`, `key`, `expr`, `arm`, `role` and `text`, one
  row for each governed span the case evaluated; `span` matches
  [`arms()`](https://vorpalvorpal.github.io/weft/reference/arms.md);
  `arm`, `role` and `text` are `NA` for a span that was evaluated and
  chose no arm);

- `arms`:
  [`arms()`](https://vorpalvorpal.github.io/weft/reference/arms.md) of
  the file (the same object, with its class and `errors` attribute) with
  one logical column for each case (did the case choose this arm) and
  `reached` (did any);

- `unreached`: the rows of `arms` that no case reached;

- `unevaluated`: the rows of the spans that no case evaluated at all
  (those nested in arms that were never chosen).

## Details

Each case is a named list of `params`. The knit has the document's
default parameters with the case's values over them; a name that the
document does not declare is an error, raised before anything runs. A
default written `!r` is evaluated in the child process, in the
document's folder, and one that cannot be evaluated stops that case with
the error. A case cannot be named after a column of the result (`file`,
`line`, `context`, `span`, `key`, `expr`, `arm`, `role`, `text`,
`parent_span`, `parent_arm` or `reached`). The knit's working directory
is the document's, as in a render, for a `.qmd` too. Draft mode is on,
so a case with failures runs to its end; a case whose knit stops is
reported in its `error` and the next case runs.

Nothing is written to the project. The output and the figures go to a
temporary directory that is removed, and the child process runs with the
environment variable `WEFT_REHEARSE=1`, which makes weft write no stamp,
no collection line, no draft JSON file and no ledger, and use no chunk
cache (`cache = FALSE` is forced for every chunk, wherever its cache was
set, so no cache directory appears). A chunk of the document that itself
writes files is the author's affair.

## Limits

Only [`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html) runs:
not Pandoc and not Quarto, because a rehearsal needs the records and not
the output. Because Quarto does not run, a `{{< include >}}` is not
expanded and project-level metadata is not read; that includes
`execute-dir`, so the working directory is always the document's folder,
never the project root. A `.qmd` whose inline code uses the `{r}` form
is knitted with a stand-in for Quarto's `.QuartoInlineRender`. A
document that reads its data some other way than through its parameters
renders the same data in every case (rule 3.7.4).

The child process is started in the project root (the nearest folder
upward that holds `_weft.yml` or `_quarto.yml`, else the document's
folder) and reads that folder's `.Rprofile`, as a render does, so a
document that activates weft there can be rehearsed. It is not run with
`--vanilla`.

Only the spans of the file rehearsed are reported: a span in a document
that a chunk includes with `child=` is not listed or reported. A span
that a case evaluates more than once (a
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
in a loop) is reported once, with the last arm it chose. A case value is
not checked against the default's type, and `cases` cannot be empty.

The child process loads the same weft as this one: when it was loaded by
`pkgload` (as `devtools::load_all()` does) from a source directory, the
child loads that directory, and otherwise it calls
[`library(weft)`](https://vorpalvorpal.github.io/weft/).

## See also

[`arms()`](https://vorpalvorpal.github.io/weft/reference/arms.md)
