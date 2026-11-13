# Check a value in place

`claim(x, <check>, ...)` returns `x` visibly and unchanged, so a value
can be guarded inside a larger expression: `trend(claim(foo, . > 0))`
(rule 3.1.1). In a check, `.` stands for `x` (rule 3.1.2); other names
are looked up in the caller. Each check is a separate argument and is
reported separately (rule 3.1.3). Checks are captured unevaluated, and a
failure quotes the check as written (rule 3.1.4).

## Usage

``` r
claim(x, ..., level = c("fail", "warn"))
```

## Arguments

- x:

  Any value.

- ...:

  One or more checks, as expressions in `.` and the caller's variables.

- level:

  `"fail"` (the default) or `"warn"`. It must be given by name.

## Value

`x`, unchanged.

## Details

A check passes only when it evaluates to a single `TRUE`.

Outside a knit a failed check stops with an error of class
`weft_claim_failed`. `claim(x)` with no check stops with class
`weft_claim_no_check` (rule 3.1.10).

With `level = "warn"` a check that is not `TRUE` is a warning, not a
failure. In a knit the value prints as if the check had passed, no
marker is left and the render does not fail; the check is recorded in
`last_knit()$warnings`, and the warnings are printed to stderr at the
end of the knit. Outside a knit it is a
[`warning()`](https://rdrr.io/r/base/warning.html) of class
`weft_claim_warning`, and `x` is returned. A check that itself raises an
error is a failed check at the level given.

## Examples

``` r
claim(5, . > 1)
#> [1] 5
claim(c(3, 4), sum(.) == 7, all(. > 0))
#> [1] 3 4
```
