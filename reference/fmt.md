# Formatter functions

Each `fmt_*()` function is the R form of a formatter class `.x` (rule
3.4.1). It returns a `weft_text`: a character vector whose attributes
hold the printed record (rule 1.4.11), the number as printed, whether
decimals are shown, and the relation (`"="`, `"<"` or `">"`). Passing a
`weft_text` to another formatter carries the record forward (rule
3.4.2).

## Usage

``` r
fmt_num(
  x,
  digits = NULL,
  sigfig = NULL,
  unit = NULL,
  unit_form = NULL,
  plus = FALSE
)

fmt_pct(x, digits = NULL, sigfig = NULL, unit = NULL, plus = FALSE)

fmt_sci(x, digits = NULL, sigfig = NULL, unit = NULL, unit_form = NULL)

fmt_no(x, unit_form = NULL)

fmt_word(x, unit_form = NULL)

fmt_count(x, unit_form = NULL)

fmt_ord(x, unit_form = NULL)

fmt_and(
  x,
  sep = ", ",
  last = NULL,
  trunc = NULL,
  none = NULL,
  unit_form = NULL
)

fmt_or(x, sep = ", ", last = NULL, trunc = NULL, none = NULL, unit_form = NULL)

fmt_p(x, digits = NULL, label = NULL)

fmt_date(x)

fmt_range(
  x,
  digits = NULL,
  sigfig = NULL,
  unit = NULL,
  unit_form = NULL,
  plus = FALSE
)

fmt_pairs(
  x,
  sep = ", ",
  last = NULL,
  trunc = NULL,
  none = NULL,
  unit_form = NULL
)

fmt_ul(x, none = NULL, unit_form = NULL)

fmt_ol(x, none = NULL, unit_form = NULL)

fmt_dl(x, none = NULL, unit_form = NULL)

fmt_cap(x)

fmt_a(x)

fmt_strong(x)

fmt_em(x)
```

## Arguments

- x:

  The value to format. A `weft_text` from another formatter is accepted.

- digits:

  Decimal places. Not together with `sigfig`. For `fmt_p()` and `.p`, a
  whole number from 1 to 6 (rule 1.4.21).

- sigfig:

  Significant figures. Not together with `digits`. Not for `fmt_p()` or
  `.p`.

- unit:

  The unit to print a quantity in, as a string:
  `fmt_num(u(150, "cm"), unit = "m")` is "1.5 m". The quantity is
  converted first, so the number, the unit and the arm an `n` span
  chooses are all in that unit. A unit the quantity cannot be converted
  to, and `unit` on a value that is not a quantity, are a
  `weft_value_error`. Like `digits`, it implies `.num`. A ladder of
  units the author approves, written as one string with `|` between the
  units or as a character vector, `unit = "mm|m|km"` or
  `unit = c("mm", "m", "km")` (rule 4.4.23), prints in the first unit
  that gives a number from 1 up to, not including, 1,000, as the number
  is printed, and in one unit for a whole vector (the unit where most of
  its numbers fit, ties to the earlier). A number that fits no unit
  takes the one whose number is nearest the window, and zero the first.
  The order is the author's preference. Every unit on the ladder is
  checked, whichever is picked: one that does not convert, is refused or
  is the size of another is a `weft_value_error`, and an empty or
  repeated unit is a `weft_construct_error`. A ladder of one unit is
  that unit. The `units` attribute holds the unit picked. `unit` also
  converts a formatter's text that carries a quantity, as it converts
  the quantity itself. `.sci` with a ladder of more than one unit is a
  `weft_value_error`.

- unit_form:

  How a quantity's unit prints (rule 3.4.8): `NULL` (the setting
  `unit_form` in force: `"auto"` unless `_weft.yml` or the document says
  otherwise, and for a `weft_text` input given a collapse class alone,
  each element's own printed form), `"auto"` (the symbol after digits,
  the name after a spelled number), `"symbol"`, `"name"`, or `"none"`
  (the number alone). Anything else is a `weft_construct_error`, and so
  is `"symbol"` on `fmt_no()`, `fmt_word()` and `fmt_count()`, and
  `"name"` when the document's `lang` is not English. A form other than
  `"auto"` on a value with no unit is a `weft_value_error`. `fmt_pct()`
  and `fmt_p()` take none.

- plus:

  `TRUE` to print a number above zero with a plus sign (`fmt_num()`,
  `fmt_pct()`, `fmt_range()`; the class `.plus`, rule 1.4.21). Zero and
  a number that prints as zero have no sign; a negative number prints
  the `minus` setting. Anything but `TRUE` or `FALSE` is a
  `weft_construct_error`.

- sep:

  The text between items of a collapse.

- last:

  The text before the final item of a collapse. The default is " and "
  (" or " for `fmt_or()`), with a comma before it when the
  `serial_comma` setting is on and there are three or more items; a
  `last` given here is used as it is.

- trunc:

  The number of items a collapse shows before "and N others".

- none:

  Text to print in place of a collapse when `x` is a vector of length
  zero (`fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`, `fmt_ol()`,
  `fmt_dl()`). The default, `NULL`, makes an empty vector a
  `weft_no_value` error. `NULL` itself is always an error.

- label:

  For `fmt_p()`, the text before the relation: "q" prints "q = 0.046",
  `""` prints "0.046". `NULL` takes the setting `p_label` (default "p").
  With `digits`, `fmt_p()` takes a whole number from 1 to 6 (and the
  setting `p_digits`): below 10^-digits it prints "p \< 0.001", above 1
  less that "p \> 0.999", else that many decimals (rule 1.4.17).

## Value

A `weft_text`.

## Details

A missing value (`NA`, `NaN`, `Inf`, `-Inf` or a value of length zero)
stops with an error of class `weft_no_value`. A value a class cannot
take (a decimal given to `fmt_word()`, say) stops with class
`weft_value_error`.

A number whose absolute value (for `fmt_pct()`, the percentage's) is
below 1e-9 is zero and prints "0"; the quantity of a unit is not
snapped, and a small one goes through the rule below as any other number
does. Any other number prints to the default digits, however small:
`fmt_num(0.04)` is "0.0" and `fmt_pct(0.0004)` is "0.0%", never "-0.0".
When neither `digits` nor `sigfig` is given (a project default `digits`
does not count) and `fmt_num()` or `fmt_pct()` prints a number that is
not zero with no digit other than 0, the loss is not silent: a warned
check of kind "printed as zero" is recorded as a failed
`claim(level = "warn")` is (see
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)),
and outside a knit it is a
[`warning()`](https://rdrr.io/r/base/warning.html) of class
`weft_zero_warning`. The value still prints. One warning is recorded for
each call, however many elements print as zero; its message gives the
first value, what printed and the count, and says to add `sigfig` to
show the number or `digits` to confirm the zero. A bound of
[`clamp()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) is
never printed as zero: it prints as it was written.

A `units` value (see
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md)) prints with
its unit, after a no-break space. The unit is its symbol or its name
(rules 4.4.2, 4.4.15): the symbol after digits ("5 m"), the name after a
spelled number or "no" ("five metres"), and `unit_form` can ask for
either, or for none. The symbol text is Pandoc markdown: an exponent is
a superscript (`m^2^`, and `m` to the minus three as `m^-3^` with a true
minus sign), a product is a middle dot, a unit with no numerator is
written with negative powers, and characters markdown reads are escaped.
A name is singular only when its number prints "1" or "one". A wording
class that prints a word (`fmt_word()`, `fmt_count()`, `fmt_no()`) needs
a name for the unit, judged on the class and never on the data: a unit
with none is a `weft_value_error` (add it under `units:` in `_weft.yml`,
or use `unit_form = "none"`). `fmt_and()`, `fmt_or()`, `fmt_range()` and
[`glue_vec()`](https://vorpalvorpal.github.io/weft/reference/glue_vec.md)
print the unit once, after the last item, in that item's form;
`fmt_pairs()`, `fmt_ul()`, `fmt_ol()`, `fmt_dl()` and a vector no
collapse class joins print it with every element. `fmt_pct()`, `fmt_p()`
and `fmt_date()` on a quantity that still has a unit are a
`weft_value_error`; a ratio with no unit left is a plain number, and
`unit_form` other than `"auto"` on it is a `weft_value_error`, as is
`fmt_ord()` on a quantity with a unit (a rank has no unit). The result
carries the attributes `unit` (the symbol text, for a plural number),
`unit_form` (`"symbol"`, `"name"` or `NA` for each element) and `units`
(the unit as the `units` package gives it), so
`fmt_and(fmt_num(u(c(3, 5), m)))` prints the unit once, and a number or
wording class given the text formats its `raw` value afresh in the form
then in force. The record's `number` and `raw` never hold the unit. `#`
in a span or
[`plural()`](https://vorpalvorpal.github.io/weft/reference/plural.md)
prints what the governor prints as a value, unit included. See
[`fmt_unit()`](https://vorpalvorpal.github.io/weft/reference/fmt_unit.md)
for the unit alone.

## Examples

``` r
fmt_num(3.14159)
#> <weft_text>
#> [1] "3.1"
fmt_pct(0.12)
#> <weft_text>
#> [1] "12%"
fmt_word(3)
#> <weft_text>
#> [1] "three"
fmt_and(c("a", "b", "c"))
#> <weft_text>
#> [1] "a, b and c"
```
