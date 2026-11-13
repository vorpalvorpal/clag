# A year in a dictionary

A `year` entry of a dictionary is a `weft_year`: an integer with a
class, so that it keeps its place through
[`c()`](https://rdrr.io/r/base/c.html), `[`, `[[`,
[`rev()`](https://rdrr.io/r/base/rev.html),
[`sort()`](https://rdrr.io/r/base/sort.html),
[`unique()`](https://rdrr.io/r/base/unique.html),
[`min()`](https://rdrr.io/r/base/Extremes.html),
[`max()`](https://rdrr.io/r/base/Extremes.html),
[`range()`](https://rdrr.io/r/base/range.html) and
[`seq()`](https://rdrr.io/r/base/seq.html), and `year + n` and
`year - n` are years. `year - year` and every other arithmetic give a
plain number, and a comparison works as it does on integers.
[`as.integer()`](https://rdrr.io/r/base/integer.html),
[`as.numeric()`](https://rdrr.io/r/base/numeric.html),
[`format()`](https://rdrr.io/r/base/format.html) and
[`print()`](https://rdrr.io/r/base/print.html) show the bare integer.
Every number and wording class (`.num`, `.ord`, `.and`, `.range` and the
rest) prints a year with no thousands mark.

## Usage

``` r
# S3 method for class 'weft_year'
c(...)

# S3 method for class 'weft_year'
x[...]

# S3 method for class 'weft_year'
x[[...]]

# S3 method for class 'weft_year'
rev(x)

# S3 method for class 'weft_year'
sort(x, decreasing = FALSE, ...)

# S3 method for class 'weft_year'
unique(x, incomparables = FALSE, ...)

# S3 method for class 'weft_year'
seq(from, ...)

# S3 method for class 'weft_year'
Summary(..., na.rm = FALSE)

# S3 method for class 'weft_year'
Ops(e1, e2)

# S3 method for class 'weft_year'
Math(x, ...)

# S3 method for class 'weft_year'
format(x, ...)

# S3 method for class 'weft_year'
print(x, ...)
```

## Arguments

- ...:

  Further arguments, passed on.

- x, e1, e2, from:

  A `weft_year`, or a value to combine with one.

- decreasing:

  Whether to sort downwards.

- incomparables:

  Not used.

- na.rm:

  Whether to drop missing values.

## Value

A `weft_year`, or a plain number where the text says so.

## Details

When the vctrs package is loaded, a year combined with an integer or a
double gives a plain integer or double, and a year with a year gives a
year.
