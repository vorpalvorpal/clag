# Open findings

Findings from the second pair of reviews of `PACKAGE-SCOPING.md` (2026-11-11)
that are not yet in the document. Everything else the reviews raised and the
author agreed to is folded in. Delete an entry when it is folded in or
dropped.

## Waiting on the gate decision

The author is reconsidering how much accounting §6 to §8 should ask for
(`dev/research-checks.md`). The proposal on the table: one machine-written,
committed record of every construct, check and tolerated typed number, and of
what each printed; the hook fails on what is wrong now or on a record that is
out of date; updating the record is one command, run by a person by default;
additions are judged against `HEAD`, so there is no hand-kept baseline;
`removals.yml`, `accepted.yml`, the paragraph matcher and the separate
integrity report go. A branch-preview function for dynamic reports (every arm
of every span, and a render against named test cases) is proposed alongside.

These wait on that decision, and some dissolve under it:

- **Stale baseline slot.** A numeral deleted in one commit leaves a baseline
  entry that a new, uncomputed numeral can fill in the next (6.5.5 does not
  catch it). Fix if the baseline stays: judge additions against `HEAD`'s
  count; add `baseline_add()`.
- **"Literal value" is undefined** (5.6.1): say it means an expression of
  constants and operators only.
- **No baseline kind** for the anchor, label and alt-text rules (§5.8, §5.9),
  so they fail on every existing chapter at adoption.
- **Loosened checks are only reported.** `. > 10` changed to `. > 0`, or an
  empty arm added to a guard, passes the commit, the render and `verify()`.
- **Gate blind spots found by the spike and the reviews:** a move across
  files, an expression changed under an unchanged `#id`, an unrelated swap
  inside one paragraph, a file rename, unequal counts netting out across a
  range, and append-only files conflicting on merge.
- **6.1.1 and 6.2.1 count bare inline R as a construct.** Rule 1.1.8 now says
  it is not one. The gate has to say whether it still counts bare values.
- **CI cannot re-render a clean clone** that lacks the data. `verify()` needs
  a static mode for CI.
- **`verify(files = )` always fails in a frozen project**; it should render
  and judge only the named files. `verify()` is not defined for rmarkdown.
- **The ledger does not say** what "changed" compares against, how an
  acceptance is keyed, or what a document rendered several times with
  different `params` records.
- **Project formatter names** must be declared in `_weft.yml` if static checks
  are to know their stage.

## Waiting on the author's reply

- **Units through arithmetic (§4.4).** `dict$a / dict$b` would print a unit.
  Proposal: the unit survives `+`, `-`, and `*` or `/` by a plain number;
  drops when two quantities multiply or divide; adding different units is an
  error.

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
