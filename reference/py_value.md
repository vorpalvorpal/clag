# Read a Python value

`py_value()` reads a value that a Python chunk made, in R code, and
checks it as weft checks every value that reaches prose (rules 1.11 and
2.12.4). Each argument is one string, a step of a path: `py_value("n")`
reads the name `n` in Python's main module; `py_value("cfg", "depth")`
reads `cfg`, then its key `depth` when `cfg` is a mapping, else its
attribute `depth`.

## Usage

``` r
py_value(...)
```

## Arguments

- ...:

  One or more non-empty strings: the name in Python's main module, then
  the keys or attributes below it.

## Value

The R form of the value: a logical, integer or double, a character
string, a `Date`, or an atomic vector of one of these for a list, named
when it was a mapping. A missing value is `NA`.

## Details

The value is read from its Python type, never from reticulate's
conversion, which turns a whole number beyond 2^31 into `NA` or a wrong
number. A bool, an integer, a float, a `decimal.Decimal`, a string, a
`datetime.date` and a list of one of these (a list, a tuple, a mapping
with string keys, a one-dimensional numpy array or a pandas Series) are
read. An integer beyond 2^53, a `Decimal` of more than 15 significant
digits, a `datetime`, a set and anything else are refused with a
`weft_guest_value_error` that says what to do. `None`, NaN and
infinities are `NA`.

In prose, in the expressions weft evaluates, `py$n` and `py[["n"]]` are
read the same way, with no
[`library(reticulate)`](https://rstudio.github.io/reticulate/). Use
`py_value()` in the code of an R chunk.

## Examples

``` r
if (requireNamespace("reticulate", quietly = TRUE) &&
    isTRUE(tryCatch(reticulate::py_available(initialize = TRUE),
                    error = function(e) FALSE))) {
  reticulate::py_run_string("depth = 3.14159")
  py_value("depth")
}
#> Downloading uv...
#> Done!
#> [1] 3.14159
```
