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
