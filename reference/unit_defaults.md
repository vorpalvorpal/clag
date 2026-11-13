# The default units weft registers

`unit_defaults()` returns weft's default table of units (rule 4.4.21),
the rows of `inst/weft-units.yml`, in file order. It registers nothing:
the table is registered the first time weft parses or converts a unit in
a session, and again as each configuration is read (see
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md)).

## Usage

``` r
unit_defaults()
```

## Value

A data frame with one row per default unit and the columns `unit`, `is`
(`"base"`, or the definition as the table writes it), `name`, `plural`,
`symbol` (character, `NA` where the row has none), `space` (logical,
`NA` where the row does not say), `before` (logical, `FALSE` where the
row does not say) and `redefines` (logical). The attribute `file` is the
path of the YAML file.

## Details

A row is written as a row of `units:` in `_weft.yml` is, and may be
copied there. A row **redefines** (`redefines` is `TRUE`) when it has
`is` and the units package already reads its unit, alone or as a prefix
and another unit: `pH` as a picohenry, `mph` as a milliphot, `gal` as
the galileo. Redefining rows apply under `unit_defaults: weft` (the
default) and are skipped under `si`; the other rows apply in both.

## Examples

``` r
unit_defaults()
#>          unit       is                         name         plural     symbol
#> 1          pH     base                           pH             pH       <NA>
#> 2         mph   1 mi/h                mile per hour           <NA>       <NA>
#> 3         nmi   1852 m                nautical mile           <NA>       <NA>
#> 4          Ma    1 Myr                million years  million years       <NA>
#> 5          ka    1 kyr               thousand years thousand years       <NA>
#> 6         gal 1 gallon                       gallon           <NA>       <NA>
#> 7         ppm     <NA>             part per million           <NA>       <NA>
#> 8         ppb     <NA>             part per billion           <NA>       <NA>
#> 9         NTU     base nephelometric turbidity unit           <NA>       <NA>
#> 10        PSU     base      practical salinity unit           <NA>       <NA>
#> 11        CFU     base          colony-forming unit           <NA>       <NA>
#> 12        MPN     base                         <NA>           <NA>       <NA>
#> 13 CFU/100 mL     <NA>                         <NA>           <NA> CFU/100 mL
#> 14 MPN/100 mL     <NA>                         <NA>           <NA> MPN/100 mL
#>    space before redefines
#> 1     NA   TRUE      TRUE
#> 2     NA  FALSE      TRUE
#> 3     NA  FALSE      TRUE
#> 4     NA  FALSE      TRUE
#> 5     NA  FALSE      TRUE
#> 6     NA  FALSE      TRUE
#> 7     NA  FALSE     FALSE
#> 8     NA  FALSE     FALSE
#> 9     NA  FALSE     FALSE
#> 10    NA  FALSE     FALSE
#> 11    NA  FALSE     FALSE
#> 12    NA  FALSE     FALSE
#> 13    NA  FALSE     FALSE
#> 14    NA  FALSE     FALSE
```
