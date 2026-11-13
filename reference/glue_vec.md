# Join items into a phrase

The collapse engine behind `.and`, `.or` and the list formatters (rule
3.4.3): `glue_vec(c("a", "b", "c"))` is `"a, b and c"`. With two items
only `last` is used.

## Usage

``` r
glue_vec(x, sep = ", ", last = " and ")
```

## Arguments

- x:

  A character vector, or a `weft_text`.

- sep:

  The text between items.

- last:

  The text before the final item.

## Value

A `weft_text` of length one with no number.

## Examples

``` r
glue_vec(c("a", "b", "c"))
#> <weft_text>
#> [1] "a, b and c"
glue_vec(c("a", "b", "c"), last = " or ")
#> <weft_text>
#> [1] "a, b or c"
```
