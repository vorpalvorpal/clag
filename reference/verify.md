# Check a project before release

`verify()` is the full check of a project (rule 8.1). It runs the static
lints over the whole project, compares their findings with a commit,
checks the pointers of `dict.yml`, renders the documents with Quarto (or
knits them, under rmarkdown) with the `_freeze` folder backed up and
restored whatever happens, reads the stamp each render writes to see
that every check ran and passed, checks that no ledger is stale, and
prints a report with a verdict. When it fails it signals a
`weft_verify_error`, so that `Rscript -e 'weft::verify()'` exits 1.

## Usage

``` r
verify(files = NULL, since = NULL, static = FALSE, path = ".")

# S3 method for class 'weft_verify'
print(x, ...)
```

## Arguments

- files:

  `NULL` (every document of the project), or documents to verify
  (relative to the project root, or absolute under it). Only these are
  rendered, stamped, judged for ledgers and listed; the rules that read
  across files still read the whole project.

- since:

  `NULL` (the commit `HEAD`, when there is one) or one string naming a
  commit.

- static:

  `TRUE` to run the static parts only: no render, no ledger.

- path:

  A file or folder inside the project.

- x:

  A `weft_verify`.

- ...:

  Not used.

## Value

A `weft_verify`, invisibly, when the check passed: a list with `ok`,
`parts` (`part`, `status`, `detail`), `errors`, `added`, `strict`,
`names`, `tier2` (each a `weft_findings`), `removed`, `decisions`,
`knit`, `unexecuted`, `unfresh`, `stale`, `tolerated`, `log`, `notes`
and `seconds`. The report is printed to stderr with
[`message()`](https://rdrr.io/r/base/message.html).

## Details

A part is skipped when it is named in `verify_skip` in `_weft.yml`
(`lints`, `decisions`, `render`, `ledger`), and the render and ledger
parts are skipped by `static = TRUE`. `verify()` does not run in draft
mode (rule 8.1.5).
