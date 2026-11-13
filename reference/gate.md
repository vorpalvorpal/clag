# The commit gate

`gate()` is what the `commit-msg` hook runs. It compares the index (what
the commit will hold) with `HEAD` for every project of the repository, a
project being a folder that holds `_weft.yml`, and fails the commit on a
construct error in a changed document, on a tier-1 finding that `HEAD`
did not hold, and on weft constructs removed when the message does not
say so with a `Weft-Removed: N` trailer (rules 6.1 to 6.3). It reads git
only and changes nothing in the repository; its cache lives under the
git directory.

## Usage

``` r
gate(message = NULL, path = ".")

# S3 method for class 'weft_gate'
print(x, ...)
```

## Arguments

- message:

  `NULL`, or the path of a file holding the commit message. With none,
  the message has no trailer.

- path:

  A folder inside a git work tree. The whole repository is judged.

- x:

  A `weft_gate`.

- ...:

  Not used.

## Value

A `weft_gate`, invisibly: a list with `ok`, `errors` and `added` (a
`weft_findings` each), `excess` (a data frame of `project`, `rule`,
`text`, `base`, `new`), `removed` (`project`, `file`, `line`, `kind`,
`text`, from `HEAD`), `n_removed`, `trailer`, `changed`, `notes` and
`seconds`. The report is printed to stderr with
[`message()`](https://rdrr.io/r/base/message.html).
