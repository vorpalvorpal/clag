# Is a value inside a range?

`in_range(x, range)` is `TRUE` where `range[1] <= x` and
`x <= range[2]`, element by element, and `NA` where `x` is `NA`. The
bounds are inside the range. `range` is a `range` entry of the
dictionary, as in `in_range(do_mean, dict$do_band)`, or any two numbers
in order.

## Usage

``` r
in_range(x, range)
```

## Arguments

- x:

  A number or a quantity (a `units` value, see
  [`u()`](https://vorpalvorpal.github.io/weft/reference/u.md)).

- range:

  Two numbers, lower first; a `units` pair for a quantity.

## Value

A logical vector the length of `x`.

## Details

A quantity `x` is converted to the unit of the range. Units that do not
convert, a number against a range with a unit (or the reverse), and a
`range` that is not two numbers with the lower below the upper are a
`weft_value_error`. It is an R function: the filter has no dictionary,
so it is written in a governor's `if` where R evaluates it.

## Examples

``` r
in_range(c(6, 7, 9), c(6.5, 8.5))
#> [1] FALSE  TRUE FALSE
```
