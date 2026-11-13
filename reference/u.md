# A number with a unit

`u(value, unit)` makes a `units` value. The unit is taken as written and
never evaluated as R: `u(35, m)`, `u(5, mg/L)`, `u(1, m^2)`; or it is a
string, `u(150, "CFU/100 mL")`. `value` is a numeric vector, or a
`units` value, which is converted: `u(dict$core_len, cm)`.

## Usage

``` r
u(value, unit)
```

## Arguments

- value:

  A numeric vector or a `units` value.

- unit:

  A unit expression, written as it is, or a string.

## Value

A `units` value.

## Details

A unit held in a variable cannot be given to `u()`, which takes it as
written; `do.call(u, list(3, "m"))` does that, and so does
`units::set_units(x, un, mode = "standard")`. `u()` makes a quantity,
and weft cannot stop base R's `%in%`,
[`match()`](https://rdrr.io/r/base/match.html),
[`cut()`](https://rdrr.io/r/base/cut.html) and
[`findInterval()`](https://rdrr.io/r/base/findInterval.html) from
comparing one with a bare number, as they work on the bare numbers (rule
4.4.5 is kept by
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) and
the comparison operators only).

`u()` registers no unit of its own. The first time weft parses or
converts a unit in a session, and each time a configuration is read, it
brings the `units` database to weft's default table (see
[`unit_defaults()`](https://vorpalvorpal.github.io/weft/reference/unit_defaults.md):
`pH`, `mph`, `nmi`, `Ma`, `ka`, `gal`, `NTU`, `PSU`, `CFU`, `MPN`, and
names for `ppm` and `ppb`) and the project's `units:` rows (rules
4.4.21, 9.1.7); loading weft changes nothing. A unit the `units`
database does not know is a `weft_unit_error`; a project's own unit is
registered when the dictionary that names it is read (rule 4.4.7), or
with
[`units::install_unit()`](https://r-quantities.github.io/units/reference/install_unit.html).
A unit that does not convert, a `value` that is not numeric and a
missing `unit` are a `weft_unit_error` too.

A unit is kept as written: `u(2, Sv)` holds `Sv`, not the `Gy` the
`units` package substitutes, and weft refuses to convert between units
the database defines alike (`Sv`, `Gy` and `rem`; `Bq`, `Hz` and `Ci`;
`VA` and `W`; and `Hz` or `Bq` and an angle per time such as `rpm`), in
[`of_n()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
[`about()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
and a
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
comparison as in a conversion; arithmetic is left to `units`. Under
`unit_defaults: weft` (the default in `_weft.yml`) a unit the `units`
package reads as a prefix and another unit that a report does not mean
(`mt` as a millitonne, `kt` as a knot, `kph` as a kilophot) is a
`weft_unit_error` whose message says what it was read as and what to
write; under `unit_defaults: si` it is read as the `units` package reads
it (rule 4.4.20).

`u(NA, mm)` is a missing quantity and `u(logical(0), mm)` an empty one;
`TRUE` and `FALSE` are refused. Inside a compound unit each token is
kept as typed and prints as typed (`mm/hr` prints `mm/hr`, rule 4.4.20).
`grade` is refused like `mt`: the `units` package reads it as an angle;
name a project unit in `units:` instead. A bare quantity in prose
(`` `r u(3, mm)` `` with no class) prints as stock knitr prints it and
raises a `weft_unit_warning`; add `{.num}` or `{.nounit}`. The same
warning is raised when the prose after a printed quantity types its unit
again.

## Examples

``` r
u(35, m)
#> 35 [m]
u(5, mg/L)
#> 5 [mg/L]
```
