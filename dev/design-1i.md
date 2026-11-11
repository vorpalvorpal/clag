# Stage 1i — a number that prints as zero (Robin, 2026-11-12; replaces the fallback of stage 1g)

Robin doubted the first-non-zero-decimal rule and accepted the
alternative: fixed decimals are the convention, rule 1.5.10 depends on
them, and the loss must not be silent. Amends 1.4.13; 1.5.10 stands as
written. Built after stage 1h.

- **Printing.** Under the default digits a number prints to the default
  digits, whatever its size: 0.04 prints "0.0", -0.04 prints "0.0" (no
  "−0.0", decision 5), and 0.0004 under `.pct` prints "0.0%". The
  one-significant-figure fallback of stage 1g is removed.
- **Noise.** A number whose absolute value (for `.pct`, the percentage's)
  is below 1e-9 is zero: it prints "0" ("0%") and is never warned about.
  This part of stage 1g stays.
- **The warning.** When neither `digits` nor `sigfig` is given for the
  value (a project default `digits` does not count as given) and a number
  that is not zero prints with no digit other than 0, a warned check is
  recorded, exactly as a failed `claim(level = "warn")` is (stage 1f): a
  row in `last_knit()$warnings`, the end-of-knit report on stderr, the
  collection file and draft JSON with `"level": "warn"`, the post-render
  report. Its kind is "printed as zero". Its message gives the value and
  what printed and says to add `sigfig` to show it or `digits` to confirm
  it ("0.04 printed as 0.0: add sigfig to show it, or digits to confirm").
  The value prints, no marker is left, and the render does not fail.
- **Silencing.** `digits` or `sigfig` on the construct or the call: the
  author has chosen, and nothing is recorded.
- **Where.** A value formatted by `.num` or `.pct` (including the default
  class of a value with an attribute block) and `fmt_num()`, `fmt_pct()`.
  One warning per construct or call, however many elements print as zero
  (the message gives the first and the count). Not a governor and not
  `#`: a `sign` governor that prints "0.0" takes its zero arm and that is
  rule 1.5.10 working as designed.
- **Outside a knit.** `fmt_num(0.04)` returns "0.0" and signals a
  `warning()` of class `weft_zero_warning`. In `weft_str()` outside a knit
  the same warning is signalled and the text returned.
- `rehearse()` reports it in the case's `warnings`.

## Tests

`tests/testthat/test-1i.R`; the small-number tests of `test-1g.R` and the
rows amended for stage 1g are amended again by the test-writer (the
`digits="1"` added to older rows may stay: it is still correct and keeps
them quiet).

## Rulings on the test-writer's report

- `.no` replaces a printed zero, and "0.0" is one: `fmt_no(0.04)` prints
  "no" and the warned check is still recorded.
- **A `clamp()` bound is never printed as zero.** When a number class
  under default digits would print the bound as zero, the bound prints as
  the author wrote it (`fmt_num(clamp(0.005, floor = 0.01))` is "< 0.01")
  and nothing is recorded.
- "The count" in the message is the number of elements that printed as
  zero.
- In draft mode the JSON file is written when there are warned checks and
  no failures.
- The record's number for a value that printed "0.0" is 0.

## Rulings on the implementer's report

- **A value with only an id.** The implementer made a number with an id
  print under the default number class, to satisfy a test row. Overruled:
  a value with only an id or pass-through attributes reaches no formatter
  and prints as stock (ruling A on the review of 1b; 1.3.4). The code is
  reverted and the test row now carries `.num` with its id. The contract's
  "default class of a value with an attribute block" was loose: a value
  has a default class only where a key such as `digits` sends it to the
  number stage.
- The draft-mode test had no `_weft.yml`, and outside a set-up project no
  JSON file is written (review B, ruling E). The test now has one.
- The report tags a warning that is not a failed claim with its kind.
  Accepted.
- `.sci` and project formatters record nothing. Accepted.
- Left open (in `dev/open-findings.md`): `clamp()` with no number class
  prints a small in-range value as "0.0" with no warned check.
