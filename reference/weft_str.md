# Resolve markup in a string

`weft_str()` resolves weft's constructs in a character vector from R
code: the text of a `results = "asis"` chunk, the `caption` of
[`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html), the labels
of a plot (rule 1.10.10). Each element is resolved as a block of prose
and the result is returned as markdown text, in the same length.
Constructs are evaluated in the caller's environment.

## Usage

``` r
weft_str(x)
```

## Arguments

- x:

  A character vector of markup.

## Value

A character vector of the same length: markdown text.

## Details

During a knit with weft active a failed check, a missing value or a
value error is collected as it is in prose (rules 2.4.1, 3.6.3) and
marked in the text with the chunk that holds the call (rule 2.6.8).
Outside a knit, and in a knit where
[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
was not called, the first failure stops at once, with the class of the
failure (`weft_claim_failed`, `weft_no_value`, `weft_value_error`,
`weft_construct_error`). A `_weft.yml` with an error is a
`weft_config_error` outside a knit as in one.

Block-only constructs do not apply; each element is read as inline
markup. Bare inline R in a string is evaluated as knitr evaluates it
(rule 1.1.8).

## Examples

``` r
n_sites <- 3
weft_str("Found [a site | # sites]{n=\"n_sites\"}.")
#> [1] "Found 3 sites."
```
