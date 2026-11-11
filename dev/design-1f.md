# Stage 1f — the delegated decisions (entries 31, 33, 34, 35, 37)

Small changes to the prose core, decided in `dev/decisions.md`. The earlier
design notes still hold. `PACKAGE-SCOPING.md` is amended in the commit that
builds this.

## A check that warns (entry 31; amends 2.6.1, 3.1)

`claim(x, ..., level = c("fail", "warn"))`. `level` must be given by name.
With `"fail"` nothing changes. With `"warn"`, for each check that is not
`TRUE`:

- In a knit (prose, a caption, `weft_str()`, chunk code): the value is
  returned and prints as if the check had passed. No marker is left. The
  render does not fail on it, in draft mode or out of it.
- It is recorded in `last_knit()$warnings`, a data frame with the same
  columns as `last_knit()$failures` (it has zero rows when there are none);
  `last_knit()$failures` does not hold it.
- At the end of the knit the warnings are printed to stderr in the layout
  of 2.6.2 under a line "weft: N warned check(s)", whether or not the
  render also failed. A failed render's error message lists failures only.
- A collection file and the draft JSON file carry a warned check with
  `"level": "warn"`; the post-render report lists warned checks after the
  failures and does not fail on them.
- Outside a knit: a `warning()` of class `weft_claim_warning` whose message
  quotes the check and the value, and the value is returned.
- A check that itself errors is a failed check at the level given (so a
  warned check that errors is a warning).
- Any other `level` is an error. A guard (`if` with one arm) has no level.
- `rehearse()`: each case gains `warnings` (the data frame); `ok` ignores
  them.

## A number that prints as zero (entry 33; amends 1.4.13)

`.num` and `.pct` (and `fmt_num()`, `fmt_pct()`): when neither `digits` nor
`sigfig` is given for the value, and a number that is not zero prints with
no digit other than 0 (for `.pct`, the percentage does), it is a value
error (collected in a knit; class `weft_value_error` outside), whose
message says the number prints as zero and names `sigfig` and `digits`.
With `digits` or `sigfig` given on the construct or the call, it prints as
asked ("0.0"). A project default `digits` in `_weft.yml` or front matter
does not count as given. Exact zero prints as before.

## House style (entry 34; amends 9.1.2)

- `thousands_from`: a whole number, default `1000`. A number whose
  absolute value is at least this gets the thousands mark; below it, none.
  `thousands_from: 10000` gives the old behaviour.
- `serial_comma`: `true` or `false`, default `false`. With `true`, `.and`,
  `.or`, `.pairs` and a truncated list put a comma before the last joiner
  when there are three or more items ("a, b, and c"; "a, b, and 2
  others"); two items are unchanged ("a and b"). A `last` key given on the
  construct wins over the setting.
- Both are read from `_weft.yml` and from front matter like the other
  settings, and a bad value is an error (decision 9).

## `.p` (entry 35; amends the `.p` format in `dev/design-1b.md`)

Below 0.001: "p < 0.001". Otherwise the value is rounded to three
decimals; a result below 0.1 prints with three decimals ("p = 0.046", "p =
0.004", "p = 0.050"), any other with two ("p = 0.10", "p = 0.20"); above
0.99: "p > 0.99". The record's number is the number printed.

## `last_knit()` (entry 37)

Exported, with a help page that lists its elements (`failures`,
`warnings`, `constructs`, `sentence_starts`, and the others it has).
Before any knit it returns `NULL`.

## Tests

One new file, `tests/testthat/test-1f.R`. Existing tests that assert the
old `.p` form, the old thousands default, or that `last_knit` is internal
are amended by the test-writer and listed in its report.

## Rulings on the test-writer's report

- **Where the zero rule applies.** To a value construct formatted by `.num`
  or `.pct` (including a value whose default class is `.num`) and to
  `fmt_num()` and `fmt_pct()`, per element. It does not apply to `.no`, to
  a governor, or to `#` in a span: a `sign` or `n` governor that prints as
  zero takes its zero arm as before (1.5.10).
- **A `level` key on an `if` span** is a construct error.
- **A truncated list's tail** counts as an item for the serial comma.
- **`fmt_p(0.0095)`** may print "p = 0.009" or "p = 0.010" (binary
  rounding); the existing test accepts either.
