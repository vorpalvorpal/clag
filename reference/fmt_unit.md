# Print a unit alone

`fmt_unit()` prints the unit of a quantity, or of a string read as
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) reads a
unit, with no number: for a heading or a table column. It is a
`weft_text` of length one with no printed record and no unit attributes,
so [`fmt_cap()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
works on it.

## Usage

``` r
fmt_unit(x, unit_form = NULL, unit = NULL, target = "markdown")
```

## Arguments

- x:

  A quantity of any length (a missing value is allowed: no number
  prints), or one string naming a unit.

- unit_form:

  `NULL` (the setting `unit_form`, else `"auto"`), `"auto"`, `"symbol"`
  or `"name"`. `"none"` is a `weft_construct_error`.

- unit:

  A unit to convert `x` to first, as a string, or a ladder of units (one
  string with `|` between the units, or a character vector; see
  [`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)).

- target:

  `"markdown"` (the default) or `"tex"`, which writes the symbol or name
  as TeX for use inside math (rule 4.4.25); anything else is a
  `weft_construct_error`.

## Value

A `weft_text` of length one.

## Details

`"auto"` and `"symbol"` print the symbol text ("mg/L"; a unit with no
symbol prints its name); `"name"` prints the name ("milligrams per
litre"). The name is plural unless `x` has length one and its number
prints "1" (a string takes the plural). A unit with no name is a
`weft_value_error`; add one under `units:` in `_weft.yml`. A name there
that is written with markdown needs its own `plural:`, as the English
plural is added to the end of the markup (`*site*` would print
`*site*s`). `.cap` leaves a symbol as it is, since its case is its
meaning, and capitalises a name. `unit` converts `x` first, a string as
well as a quantity; the unit of a formatter's text is not read, so pass
the quantity. With a ladder of units (`unit = "mm|m|km"`, rule 4.4.23)
and a quantity, the unit is picked as
[`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
picks it for `x` (one number, or the vector rule), and printed plural
unless `x` has length one and prints "1"; a ladder of more than one unit
with a string is a `weft_value_error`.

## Examples

``` r
fmt_unit(u(5, mg/L))
#> <weft_text>
#> [1] "mg/L"
fmt_unit(u(5, mg/L), unit_form = "name")
#> <weft_text>
#> [1] "milligrams per litre"
```
