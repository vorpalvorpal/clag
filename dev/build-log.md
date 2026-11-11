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
| 1a design note | written |
| 1a work package A (scanner, formatters, `claim()`, config; no knitr) | tests being written |
| 1a work package B (hooks, resolving, failures, positions, conditions) | not started |
| 1a work package C (Lua filter, render scripts, `use_quarto()`, pinned internals) | not started |
| Trials on two real documents | not started |
| 1b to 1e, stages 2 to 4 | not started |

## Next

Dispatch the test-writer for package A.
