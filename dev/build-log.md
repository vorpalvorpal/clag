# Build log

Newest state first. Read this before anything else after a context reset.

## Conditions of the run

- Started 2026-11-11 late evening. Mac on battery (29% at the start) and the
  weekly usage window 71% spent, so agents are dispatched one at a time and
  everything is committed at each boundary.
- Method: `dev/decisions.md` entry 1. Internal contract for stage 1a:
  `dev/design-1a.md`.
- `Rscript file.R` is blocked on battery by a hook; append `# battery-ok`.

## State

| Step | State |
|---|---|
| 1a design note | written; rulings on the first review appended |
| 1a package A (scanner, formatters, `claim()`, config) | built, reviewed (28 findings, `dev/review-1a-A.md`), fixed, committed. 185 of 186 tests pass; the one failing (`\#` in an arm, rule 1.5.12) is in B's implementer's brief |
| 1a package B (hooks, resolving, failures, positions, conditions) | failing tests committed in `tests/testthat/`; implementer running |
| 1a package C (Lua filter, render scripts, `use_quarto()`, freeze, pinned internals) | test-writer running, writing into `tests/testthat/_c/` (partly committed by accident; move up when B is done) |
| Trials on two real documents | not started |
| 1b to 1e, stages 2 to 4 | not started |

## Next

1. B's implementer reports: run the suite and check, rule on disputed tests,
   commit, send a reviewer (opus) that runs its own documents.
2. C: move tests up, confirm they fail for the right reason, implementer,
   reviewer.
3. Trials (build prompt step 2), writing `dev/field-notes.md`.
