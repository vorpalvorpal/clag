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

## Rulings on the review of stages 1f to 1i (`dev/review-1f.md`)

Findings 1 to 15 are accepted as the reviewer states them, with these
particulars; 16 (message wording) is settled by amending the spec's
example to the code's wording.

- **1, 5, K. Where the zero rule reaches.** Every place weft prints a
  number under the default digits with no `digits` or `sigfig` given:
  `.num`, `.pct`, `.range` and `fmt_range()`, `.pairs`, and the phrase
  functions `ci()` and `pm()` (one warned check per call, however many of
  its numbers print as zero). A setting copied from the project default is
  not "given". Not `about()` or `of_n()` (they print no decimals), not
  `.sci`, not a project formatter.
- **2.** A number class applied to text a formatter already made warns by
  what it prints itself: if this class prints zero for a number that is
  not zero and has no `digits` or `sigfig` of its own, it records the
  check, whatever the earlier formatter was given.
- **3.** A list class (`.ul`, `.ol`, `.dl`) on a `list` span is a
  construct error: `#` is inline.
- **4.** The ends of a range are compared as numbers, not as printed, so a
  `clamp()` bound beside a small number is not a value error.
- **6.** The warned checks collected so far are reported whenever the knit
  ends, also when it stops on an error of any kind.
- **7.** `none` in a function form must be one non-empty string that is
  not only spaces; anything else is an error of class
  `weft_construct_error`.
- **9.** `.no` replaces a printed zero and the warned check is still
  recorded (as ruled above). The spec's 2.6.11 is amended to say so.
- **10, J.** The exemption is for an `n` or `sign` governor and its `#`.
  The `#` of a `list` span prints the vector's elements, as a value does,
  and records the warned check. 1i and 2.6.11 are amended.
- **11.** `none` with `.range` is a construct error: a range has two ends.
- **13.** A record made inside a governed span is labelled by the span's
  governor expression, not by an arm's text.
- **15.** A check that is the bare string `"warn"` or `"fail"` is an error
  that says to write `level = `.
- **A.** `#` in an `if` arm nested in an `n` or `list` span is literal
  text, as 1.5.8 has it. Left; in `dev/open-findings.md`.
- **B.** The characters before which an empty arm takes its space are
  `. , ; : ! ? ) ]` and the closing quotation marks U+201D and U+2019,
  and the em dash. A straight quote is not in the list (it may open).
- **C.** A frozen document does not replay its warned checks. Left; in
  `dev/open-findings.md` with the cached-chunk case.
- **D.** A `level` key on any span is a construct error.
- **E, G, H.** Left.
- **F.** With `serial_comma` on and a `sep` key, the separator before the
  last joiner is the `sep` ("a; b; and c").
- **I.** A matrix or array is not a vector for a `list` span: a "no
  value" failure, as a data frame is.

## Rulings on the fixer's report for the review of stages 1f to 1i

- A bare `"warn"` check is an error of class `weft_claim_level`, not a
  failed claim; the older 1f assertion is amended.
- Ruling 13 holds for records made while a governor is evaluated and for
  the zero check of a `list` span; a span's own failure rows keep their
  label. Accepted.
- With `serial_comma` and a `sep` key the mark before the last joiner is
  the `sep` without its trailing space ("a; b; and c"), also under
  `.pairs` and before a `trunc` tail. Accepted.
