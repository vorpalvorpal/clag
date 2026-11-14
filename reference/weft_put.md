# Publish values by name

`weft_put()` publishes R values under names, so that prose can refer to
them by name: a code span holding the name, with a formatter class,
`` `depth`{.num} ``. The values travel in a `weft-values` block, which
the resolver filter reads (rules 2.13, 3.8). In an R document the hooks
publish a name that the source mentions and the knit has bound, so
`weft_put()` is needed only for text a chunk prints with
`results = "asis"`, for a claim that travels with its value, and from a
chunk that has no value of its own to show.

## Usage

``` r
weft_put(...)
```

## Arguments

- ...:

  Named values, or names of variables. An argument may be a call of
  [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md).

## Value

Inside a knit, `NULL`, invisibly. Outside one, the text of the block, of
class `weft_values`, which prints as the text.

## Details

Each argument publishes one name: `weft_put(depth = mean(d$depth))`, or
`weft_put(depth, n_sites)` for variables of the same names. A name is
ASCII letters, digits, `_` and `.`, starting with a letter or `_`, at
most 64 characters. An argument that is a call of
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) is
captured: its checks are run and recorded with the value, nothing is
stopped, and each check counts where the name is used.

A bool, a whole or decimal number, a string, a factor, a `Date`, an
`integer64` or an atomic vector of these (up to 10000 elements) is
published with its kind. `NA`, `NaN`, `Inf` and `NULL` are published as
missing. A value with units is refused, and any other object (a data
frame, a list, a `POSIXct`, a function) is published as an error that is
reported where the name is used.

In a knit with the hooks the block is written before the next block of
prose, or at once in a chunk with `results = "asis"`. Outside a knit
nothing is stored: the text of the block is returned.

## See also

[`weft_values_write()`](https://vorpalvorpal.github.io/weft/reference/weft_values_write.md)

## Examples

``` r
depth <- c(1.5, 2.5, 6)
weft_put(depth_mean = mean(depth), n = length(depth))
#> ````{.weft-values}
#> {"weft":1,"lang":"r","run":null,"at":1794633160,"values":{"depth_mean":{"t":"float","v":"3.3333333333333335"},"n":{"t":"int","v":"3"}}}
#> ````
weft_put(depth_mean = claim(mean(depth), . > 1, . < 10))
#> ````{.weft-values}
#> {"weft":1,"lang":"r","run":null,"at":1794633160,"values":{"depth_mean":{"t":"float","v":"3.3333333333333335","checks":[{"text":". > 1","ok":true,"level":"fail","why":null},{"text":". < 10","ok":true,"level":"fail","why":null}]}}}
#> ````
```
