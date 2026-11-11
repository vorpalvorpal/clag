# Stage 1g — two changes Robin asked for on 2026-11-12

Built after stage 1f. The earlier design notes still hold;
`PACKAGE-SCOPING.md` is amended in the commit that builds this.

## A small number under the default digits (replaces the value error of 1f; amends 1.4.13, 1.5.10)

Robin: "can the default be something like show the first non zero decimal
... Needs to survive floating point noise."

- When neither `digits` nor `sigfig` is given for the value (a project
  default `digits` does not count as given), and a number that is not zero
  would print with no digit other than 0, it prints instead to its first
  non-zero decimal, that is, rounded to one significant figure: 0.04
  prints "0.04", 0.0449 "0.04", 0.00061 "0.0006", -0.04 "−0.04"; under
  `.pct`, 0.0004 prints "0.04%".
- **Noise.** A number whose absolute value (for `.pct`, the percentage's)
  is below 1e-9 is zero and prints "0" ("0%"), as a whole number does
  (decision 5). `0.1 + 0.2 - 0.3` prints "0". A value such as
  `0.3 - 0.26` prints "0.04", not "0.03999…".
- With `digits` or `sigfig` given on the construct or the call the number
  prints as asked ("0.0").
- It is how the default digits print, so it holds wherever they do:
  `.num`, `.pct`, `fmt_num()`, `fmt_pct()`, the default class of a value,
  a governor and `#`. A `sign` governor that prints "0.02" takes the
  positive arm; one below 1e-9, or one given `digits` that prints "0.0",
  takes the zero arm (1.5.10). `.no` replaces only a printed zero.
- Each element of a vector is printed by this rule on its own ("3.2" and
  "0.04").
- The record's number is the number printed.
- No value error is raised for a number that prints as zero.

## An empty arm and the space beside it (amends 1.5.12)

Robin chose this from four options. Arms are still trimmed. When a
governed span (`n`, `if`, `sign`) prints nothing (its chosen arm is
empty), one space beside it is removed, so the author writes ordinary
spacing outside the span:

- a space on both sides: the one before the span is removed
  (`a [x | ]{if="f"} b` prints "a b");
- at the start of a block, or of a `weft_str()` string, a caption or a
  front-matter field, and followed by a space: that space is removed;
- preceded by a space and followed by the end of the block or string, or
  by one of `. , ; : ! ? )`: the space before is removed
  (`fell [sharply | ]{if="f"}.` prints "fell.");
- otherwise nothing is removed.

"A space" is one space character, or one line break inside a paragraph.
A span that prints something changes nothing around it. A value that
prints an empty string is not a span and changes nothing.

## Tests

One new file `tests/testthat/test-1g.R`; the 1f tests for the value error
and older assertions that conflict are amended by the test-writer.

## Rulings on the test-writer's report

- Only one space is removed, the one before the span, however many there
  are.
- A line break inside a paragraph is a space in every bullet.
- Two empty spans in a row each remove the space before them.
- An empty span inside an arm is judged against its own arm's text.
- A bare value with no attribute block is not formatted by weft (1.3.1);
  the rule for small numbers does not reach it.
