# Remove the dictionary marker from a target's value

Generated target commands call this; it is not for direct use. It
returns `x` without the marker of the attached dictionary, in `x` and in
its lists.

## Usage

``` r
dict_unmark(x)
```

## Arguments

- x:

  A target's value.

## Value

`x`, without the marker.
