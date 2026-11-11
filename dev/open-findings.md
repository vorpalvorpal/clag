# Open findings

Findings from the second pair of reviews of `PACKAGE-SCOPING.md` (2026-11-11)
that are not yet in the document. Everything else the reviews raised and the
author agreed to is folded in. Delete an entry when it is folded in or
dropped.

## Open

- **Netting.** Two limits of the gate are accepted (rules 6.2.6 and 6.3.6):
  a finding removed and the same text added elsewhere in one commit nets to
  zero, and a removal and an unrelated addition in one commit net out. How
  often either hides something in a real history is not known (Q18).
- **The hook under other git operations.** On `git commit --amend` the hook
  compares with the commit being amended, so the count is of the new changes
  only. Merge commits, `git rebase` and `git cherry-pick` (which may not run
  the hook at all) are untested (Q17).
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
