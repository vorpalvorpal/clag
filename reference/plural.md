# Choose a plural form

The R form of an `n` span (rule 3.2.1):
`plural(n, "a person", "# people")`. Arms are separate arguments, in the
order a span writes them (rule 3.2.2): one arm is a template for `#`;
two are one and other; three are zero, one and other; four are zero,
one, two and other. `#` stands for the governor as printed by the
default governor class. `||` and `##` are a literal `|` and `#`; a
backslash before either is removed.

## Usage

``` r
plural(n, ...)
```

## Arguments

- n:

  A single number, or a `weft_text` from a formatter (selection then
  uses its printed record). A vector or a string is an error of class
  `weft_value_error` that says to write `length(x)`; a missing value is
  an error of class `weft_no_value`.

- ...:

  One to four arms, as strings.

## Value

A character vector of length one.

## Examples

``` r
plural(1, "a person", "# people")
#> [1] "a person"
plural(3, "a person", "# people")
#> [1] "3 people"
plural(0, "never", "once", "twice", "# times")
#> [1] "never"
```
