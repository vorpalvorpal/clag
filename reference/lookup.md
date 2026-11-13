# Phrases chosen by key or by range

`lookup()` builds a function from a named character vector (rule 3.3.2):
the function takes a string or a factor (by label, never by integer
code) and stops with a `weft_value_error` on a key it does not hold.
`brk()` builds a function from formulas, tried in order (rule 3.3.3):
`brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")`.
A value no formula takes is a `weft_value_error`. Both functions
vectorise, and given `NA` they stop with a `weft_no_value` error and
never fall through to a default phrase (rule 3.3.5).

## Usage

``` r
lookup(map)

brk(...)
```

## Arguments

- map:

  A named character vector: key to phrase.

- ...:

  Formulas whose left side is a condition on `.` and whose right side is
  the phrase.

## Value

A function of one argument.

## Examples

``` r
tier <- lookup(c(hi = "high", lo = "low"))
tier("hi")
#> [1] "high"
trend <- brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")
trend(c(0.9, 1, 2))
#> [1] "a fall in" "steady"    "a rise in"
```
