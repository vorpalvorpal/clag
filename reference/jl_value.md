# Read a Julia value

`jl_value()` reads a value that a Julia chunk made, in prose or in R
code, and checks it as weft checks every value that reaches prose (rules
1.11 and 2.12.15). Each argument is one string, a step of a path:
`jl_value("n")` reads the global `n` of Julia's `Main`;
`jl_value("cfg", "depth")` reads `cfg`, then its key `depth` when `cfg`
is a dictionary (a `String` key, else the `Symbol` key), else its field
`depth`. Only the last value is read.

## Usage

``` r
jl_value(...)
```

## Arguments

- ...:

  One or more non-empty strings: the name in Julia's `Main`, then the
  keys or fields below it.

## Value

The R form of the value: a logical, integer or double, a character
string, a `Date`, or an atomic vector of one of these for a list, named
for a `NamedTuple`. A missing value is `NA`.

## Details

The value is read inside Julia from its type, never by JuliaCall's
conversion, which stops on a whole number beyond 2^31, hands a `UInt8`
over as a raw vector and ends R on a `missing`. A `Bool`, an integer, a
float (`Float16`, `Float32` and `Float64`, widened exactly), a string, a
`Char`, a `Symbol`, a `Dates.Date` and a vector or tuple of one of these
(a `NamedTuple` with names) are read. An integer beyond 2^53, a
`Rational`, an `Irrational`, a `BigFloat`, a `DateTime`, a dictionary, a
set, a matrix and anything else are refused with a
`weft_guest_value_error` that says what to do. `missing`, `nothing`, NaN
and infinities are `NA`.

In an attribute value the argument takes single quotes:
`{if="jl_value('ok')"}`. When Julia is not running, `jl_value()` starts
it with
[`JuliaCall::julia_setup()`](https://rdrr.io/pkg/JuliaCall/man/julia_setup.html)
and defines weft's one module, `WeftGuest`, in Julia's `Main`. weft
never installs Julia or a Julia package.

## Examples

``` r
if (FALSE) { # \dontrun{
# needs Julia, which takes a few seconds to start
JuliaCall::julia_setup()
JuliaCall::julia_command("depth = 3.14159;")
jl_value("depth")
} # }
```
