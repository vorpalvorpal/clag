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
| Stage 1c (captions, `weft_str()`, front matter, ten trial bugs) | Built and committed; 422 tests pass. Independent review running from a snapshot (covers the Quarto side of 1a too); report will be `dev/review-1c.md`. `R CMD check` on that commit running. One known fault to fix in the review round: bare inline R in a caption is evaluated, and stock leaves it literal (ruling at the end of `dev/design-1c.md`) |
| Stages 1b and 1d (contract `dev/design-1b.md`) | 185 failing tests committed in `tests/testthat/`; implementer running. Older tests that assert "not built yet" for these names are superseded: delete them when the implementer lists them |
| `.Rprofile` activation and `use_setup()` (rest of 1c) | Not built: §22 holds them until the hooks have been run under the Render buttons (Q2) |
| 1e, stages 2 to 4 | not started |
| Usage | weekly window 78% at 04:50. Plan: stop dispatching near 90% |

## How to run things

- Suite: `Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent")); print(r[r$failed>0|r$error, c("file","test")])'` (about 5 minutes).
- Check: `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")` (about 8 minutes; run in the background).
- Usage left: newest file in `~/.claude/usage-live/` (`five_hour`, `seven_day`). The weekly window was 76% used at 03:00.

## Next

1. 1b implementer reports: rule on disputes, delete superseded tests, run
   the suite, commit.
2. 1c review reports: rule, regression test-writer, fixer (the fixer runs
   after the 1b implementer, both touch `R/`).
3. Review of 1b+1d (opus), then its fix round. Run `devtools::check()`.
4. 1e (`arms()`, `rehearse()`), then stage 2 if usage allows.
