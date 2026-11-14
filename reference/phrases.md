# Phrase functions

Wording that arithmetic fixes (rule 3.5). Each returns a `weft_text`.
They print English words, so under a `lang` weft does not ship they are
a construct error (rule 1.6.8).

## Usage

``` r
of_n(k, n, singular, plural)

about(x, to = 1/2, tolerance = NULL)

ci(
  est,
  lo,
  hi,
  level = NULL,
  digits = NULL,
  sigfig = NULL,
  plus = FALSE,
  pct = FALSE,
  short = NULL
)

pm(est, se, digits = NULL, sigfig = NULL)

clamp(x, floor = NULL, ceiling = NULL)
```

## Arguments

- k, n:

  Whole numbers, `0 <= k <= n`, `n > 0`.

- singular, plural:

  The noun, in each form.

- x:

  A number.

- to:

  The target of `about()`.

- tolerance:

  The largest distance from `to` that `about()` accepts.

- est, lo, hi, se:

  Numbers.

- level:

  The confidence level of `ci()`, as a proportion.

- digits, sigfig:

  Decimal places or significant figures, as for
  [`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md).

- plus, pct, short:

  `TRUE` or `FALSE` (`short` also `NULL`) for `ci()`; see above.

- floor, ceiling:

  The bounds of `clamp()`; `NULL` for none.

## Value

A `weft_text`.

## Details

- `of_n(k, n, singular, plural)` prints "none of the 4 sites", "the only
  site", "both sites", "all 5 sites" or "3 of the 7 sites". Its number
  is `k`, so an `n` span after it agrees with it (rule 3.5.2).

- `about(x, to, tolerance)` prints "nearly half", "just over half" or
  "half". `to` is one of 1/4, 1/3, 1/2, 2/3 and 3/4. `x` and `to` are
  compared as percentages rounded to whole numbers. An `x` further than
  `tolerance` from `to` is a value error, because the sentence would be
  false. The default tolerance is the setting `about_tolerance` (0.05).

- `ci(est, lo, hi, level, digits, sigfig, plus, pct, short)` prints "2.1
  (95% CI 1.3 to 2.9)". The default level is the setting `ci_level`
  (0.95). `plus = TRUE` signs the three numbers as `.plus` does;
  `pct = TRUE` prints each as `.pct` does; `short = TRUE` (default: the
  setting `ci_short`) leaves out "95% CI", and a `level` given with the
  short form is a `weft_value_error`.

- `pm(est, se, digits, sigfig)` prints the estimate, a plus-minus sign
  and the standard error. When `digits` and `sigfig` are not given and a
  number of `ci()` or `pm()` that is not zero prints as zero, one warned
  check of kind "printed as zero" is recorded for the call, as for
  [`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md).

- `clamp(x, floor, ceiling)` prints the value as `.num` does inside the
  bounds, and "\< floor" or "\> ceiling" outside, with the relation of
  the printed record set (rule 3.5.4).

Given a quantity (a `units` value, see
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md)), `of_n()`
and `about()` use its number and print no unit: they print words.
`ci()`, `pm()` and `clamp()` do not take a quantity that has a unit
(rule 4.4.8) and stop with a `weft_value_error`; pass the numbers, or
format the parts with
[`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md); so
does a formatter's text that carries a unit. Given two quantities,
`of_n()` converts `n` to the unit of `k`, and `about()` converts `x` to
the unit of `to`; units that do not convert are a `weft_value_error`. A
ratio, which has no unit left, is a number.

## Examples

``` r
of_n(3, 7, "site", "sites")
#> <weft_text>
#> [1] "3 of the 7 sites"
about(0.49)
#> <weft_text>
#> [1] "nearly half"
ci(2.1, 1.3, 2.9)
#> <weft_text>
#> [1] "2.1 (95% CI 1.3 to 2.9)"
pm(2.1, 0.3)
#> <weft_text>
#> [1] "2.1 ± 0.3"
clamp(150, ceiling = 99)
#> <weft_text>
#> [1] "> 99"
```
