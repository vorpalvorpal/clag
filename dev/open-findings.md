# Open findings

Findings from the second pair of reviews of `PACKAGE-SCOPING.md` (2026-11-11)
that are not yet in the document. Everything else the reviews raised and the
author agreed to is folded in. Delete an entry when it is folded in or
dropped.

## Open

- **A guard made optional shows nowhere but the source diff.** A one-arm
  `if` that gains an empty arm keeps its ledger key, and prints the same
  while its condition holds, so `changes()` does not list it.

## Raised and not yet put to the author

- A prefix word in a citation-form `cite` span that resolves as a
  bibliography key (a stray `@`) should be an error.
- The position-tracking reader lets a list or a block quote interrupt a
  paragraph where Pandoc's markdown reader does not, and does not parse
  inline footnotes. Rule 2.10.5's block-type check does not cover a
  disagreement between the two readers.

## Raised by the build's reviews, left as they are

- An indented code block: knitr evaluates inline R in it and Pandoc prints
  a code block. The scanner reads a construct there; 1.9.2 names only fenced
  blocks.
- A `|` inside a shortcode, an inline note or a footnote label within an arm
  splits the arm. 1.5.14 does not list them.
- Two project formatters in the text stage run in the order written, so
  their result depends on order (1.4.1 fixes the order of shipped classes
  only).

- An author's own `evaluate.inline` hook is called for bare values only. A
  construct's code is parked (2.2.1) and never reaches it, so 2.1.2 does not
  hold for that one hook.
- A project formatter in the text stage does not make a bracket a text span
  (1.1.5 names only the shipped text classes).
- In a grid table a construct whose printed text is wider or narrower than
  its source moves the column border, as bare inline R does in stock.
- Time per construct grows with the size of the block: 4,000 inline items in
  one paragraph took 6.6 s against 1.0 s stock.

- A construct in a string in R code that does not go through `weft_str()`
  (a `kable(caption = )`, a `labs()` title) prints raw and nothing but the
  `weft-check` filter sees it. A stage-3 lint could read such literals.

- The sentence-start list treats "e.g. " and an ellipsis as sentence ends,
  and does not look at the start of a table cell (5.10.1).
- `cite="email x@y.com"` is read as the citation form with the key `y.com`
  (1.8.6); Pandoc does not read it as a citation.
- `of_n(0, 1, ...)` prints "none of the 1 site".

## Considered and not adopted

So a later review does not raise them again without a new argument.

- Cutting `recall_check()`, the list formatters, `.a`, or the non-English arm
  tables: the argument was cost only, and these are the author's decisions.
- A hand-written near-miss list for `n` and `if`. The near-miss rule itself
  is gone: unknown names pass through, with a warning.
- A render stamp keyed on the tree hash for CI.
- A wrapper that turns messages into warnings inside targets.
- An `_output.yml` route for the rmarkdown filter.
- A lint for free scales in facetted figures.
- An acknowledgement file with an entry per removal: it charges for every
  purposeful deletion, and no mainstream tool asks for one. The commit
  message's `Weft-Removed` trailer replaces it.
- A machine-written record with an accept command: a second step for every
  purposeful change, and accept steps get clicked through. Committing the
  ledger is the acceptance.
- Requiring a person to accept changes to checks: what we want to stop is
  accidental changes, not make purposeful changes needlessly complicated. A
  changed check shows in the source diff and in `changes()`.

## From the fix round for the review of stage 1c

- The prose scan reads the code lines of a chunk inside a block quote as
  prose (only caption and `weft_str()` rows handle the quote).
- The Lua filter cannot see a file's age, so a stale collection file that
  is empty and carries no run id is still used by the filter.
- `use_quarto()` does not add `.weft/` to `.gitignore`.
- An unstamped frozen document is reported but cannot yet fail `verify()`
  (stage 4).

## From the fix round for the review of stages 1b and 1d

- A text class or `trunc` together with `.ul`, `.ol` or `.dl` is refused
  in markup (scanner) but not when the function forms are combined in R.
- A back-reference to the id of a value that prints only text is not
  caught from the source (it cannot be); nothing catches it at knit time
  either unless the governor fails to be a number.
- A missing bibliography file is reported only when the document has a
  `cite` span.

## From stage 1e

- `rehearse()` on a `.qmd` does not stage a bibliography that is given
  relative to the project root, so its `cite` spans can fail in a
  rehearsal and pass in a render.
- Stage 1e has had no independent review.

## From stage 1f

- When a `claim()` in chunk code fails at level "fail" and stops the knit,
  the warned checks collected so far are not reported.
- A warned check inside a cached chunk is not replayed when the chunk is
  served from cache (failures are).
- Stage 1f has had no independent review.

## From stages 1g to 1i

- `clamp(x, ...)` with no number class on the construct prints a small
  in-range value as "0.0" and records no warned check.
- No test asserts the record's number of a value that printed "0.0".

## From the review of stages 1f to 1i

- `#` in an `if` arm nested inside an `n` or `list` span prints a literal
  "#" (review question A).
- A document served from freeze, like a chunk served from cache, does not
  replay its warned checks (question C).
- `.no` on a governor that prints "0.0" (question E); `thousands_from`
  judged on the number as printed, so 999.96 prints "1,000.0" (G);
  `serial_comma: null` accepted as the default (H).

## From stage 2a

- A unit string that `units` cannot parse but only warns about
  (`"m/(s"`) is accepted by `read_dict()` and registered as a new unit.
- Stage 2a has had no independent review yet.

## From the review of 2a

- `%in%`, `match()`, `cut()` and `findInterval()` compare a quantity with
  a bare number without an error (base R; finding 15).
- After a render that stops on a dictionary error, `last_knit()` returns
  the previous knit's record (question f).
- `attr<-` and `class<-` can change a dictionary (question g).
- Units installed by one project's dictionary stay installed for the next
  document knitted in the same session (question k).

- A `labels` map in `dict_local` keyed by two YAML 1.1 booleans of the same
  truth value (`yes` and `on`) stops in knitr before weft runs (finding 10).

## From the review of 2b

- A year multiplied by a unit is a quantity and prints with a thousands
  mark ("2,014 a"; question h).
- A value with only an id prints its number without its unit (question
  b; rule 4.4.10).

## From the fix round for the review of 2a

- `[[` with a number on a dictionary decides by the calling function's
  namespace (base and utils may, user code may not): fragile.
- `fmt_ord()` given a formatter's text of years prints a thousands mark.
- `Filter()` over a dictionary fails (`[` is refused).

## From the fix round for the review of 2b

- `[` on a formatter's text keeps the class and record only when the
  text carries a unit; a plain one becomes a bare character vector.
- `of_n()` and `about()` given one quantity and one bare number use the
  bare numbers (the review wanted an error).

## From the build of 2f

- `#` of a `sign` span over a formatter's text keeps the unit text as
  printed; a name is not judged again for the singular.

## From the fix round for the review of 2f

- A knit to PDF under xelatex or lualatex needs the LaTeX package
  `newunicodechar` (TinyTeX installs it on first use).
- A back-reference to an id whose span used `.nounit` has no unit to
  print.
- The refusal message for a misread unit ends "so weft cannot print it
  truthfully" after the advice; reword.

## From the review of 2c

- Whether Vale honours the order of the `swap` map (longest spelling first)
  is unverified; Vale was not installed for the review.
- The `avoid` checks cover the kept spellings only, not other text weft
  prints (string values, `labels`, `breaks` phrases, `dict_local` terms).
- A `decisions` setting in front matter is not used by `check_decisions()`;
  for `verify()` in stage 5.
