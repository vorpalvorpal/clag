# Build log

Newest state first. Read this before anything else after a context reset.

## Conditions of the run

- Started 2026-11-11 late evening. Mac on battery (29% at the start) and the
  weekly usage window 71% spent, so agents are dispatched one at a time and
  everything is committed at each boundary.
- Method: `dev/decisions.md` entry 1. Internal contract for stage 1a:
  `dev/design-1a.md`.
- `Rscript file.R` is blocked on battery by a hook; append `# battery-ok`.

## State (05:00, 12 Nov)

| Step | State |
|---|---|
| Stage 1a, the kernel | Done, reviewed twice, check clean |
| Trials on two real documents | Done: `dev/field-notes.md` |
| Stage 1c (captions, `weft_str()`, front matter, ten trial bugs) | Done. Reviewed once (`dev/review-1c.md`, 18 findings), rulings in `dev/design-1c.md`, 31 regression tests, all fixed and committed |
| Stages 1b and 1d (contract `dev/design-1b.md`) | Built, 612 tests passed. Reviewed once (`dev/review-1b.md`, 27 findings), rulings in `dev/design-1b.md`, 39 regression tests committed in `test-review-d.R`; fixer running |
| Stage 1e (`arms()`, `rehearse()`, contract `dev/design-1e.md`) | 27 tests written, parked in `tests/testthat/_1e/` until the 1b fixer is out of `R/`; implementer not yet dispatched |
| `.Rprofile` activation and `use_setup()` (rest of 1c) | Not built: §22 holds them until the hooks have been run under the Render buttons (Q2) |
| Stages 0, 2, 3, 4 | not started |
| Usage | weekly window 80% at 07:15. Plan: stop dispatching near 90% |

## How to run things

- Suite: `Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent")); print(r[r$failed>0|r$error, c("file","test")])'` (about 9 minutes).
- Check: `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")` (about 8 minutes; run in the background).
- Usage left: newest file in `~/.claude/usage-live/` (`five_hour`, `seven_day`). The weekly window was 76% used at 03:00.

## Next

1. 1b fixer reports: rule on disputes, run the suite, commit.
2. Move `tests/testthat/_1e/*.R` up, confirm they fail for the missing
   functions, dispatch the 1e implementer, commit.
3. `devtools::check()` from a clean `git archive` export: 0 errors, 0
   warnings.
4. Stage 2 (design note first) only if the weekly window allows.
