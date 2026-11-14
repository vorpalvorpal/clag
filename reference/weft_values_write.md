# Write a values file

`weft_values_write()` writes the values it is given to a JSON file in
the form of a `weft-values` block (schema 1), for a document to read
with a `weft-values` block that names the file. It works outside a knit,
and in a `targets` pipeline. The arguments are those of
[`weft_put()`](https://vorpalvorpal.github.io/weft/reference/weft_put.md):
named values, or names of variables, and calls of
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md).

## Usage

``` r
weft_values_write(path, ...)
```

## Arguments

- path:

  The file to write. A relative path is relative to the working
  directory.

- ...:

  Named values, as for
  [`weft_put()`](https://vorpalvorpal.github.io/weft/reference/weft_put.md).

## Value

`path`, invisibly.

## Details

The file is written atomically, as UTF-8 with `\\n` line ends. Nothing
is written when an argument is refused, and the old file stays.

## See also

[`weft_put()`](https://vorpalvorpal.github.io/weft/reference/weft_put.md)

## Examples

``` r
f <- tempfile(fileext = ".json")
weft_values_write(f, n = 12L, site = "north")
cat(readLines(f), sep = "\n")
#> {"weft":1,"lang":"r","run":null,"at":1794624174,"values":{"n":{"t":"int","v":"12"},"site":{"t":"string","v":"north"}}}
```
