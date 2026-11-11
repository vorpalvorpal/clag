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
| Stages 1b and 1d (contract `dev/design-1b.md`) | Done. Reviewed once (`dev/review-1b.md`, 27 findings), rulings in `dev/design-1b.md`, 39 regression tests, all fixed and committed |
| Stage 1e (`arms()`, `rehearse()`, contract `dev/design-1e.md`) | Done. Reviewed once (`dev/review-1e.md`, 13 findings), rulings in `dev/design-1e.md`, 13 regression tests, all fixed and committed |
| Trials again on the finished stage 1 | Done: `dev/field-notes.md` report 3. Same text as the first trials |
| Stage 1f (the decisions Robin delegated, `dev/design-1f.md`) | Built and committed: `claim(level = "warn")`, `thousands_from`, `serial_comma`, the new `.p`, `last_knit()` exported. Not reviewed |
| Stage 1g (`dev/design-1g.md`) | Built and committed: small numbers under default digits (open with Robin), an empty arm takes the space beside it. Not reviewed |
| Stage 1h (`dev/design-1h.md`) | The `list` key and the `none` key: contract written, tests next |
| **Owed: `PACKAGE-SCOPING.md`** | The rules changed by 1f, 1g and 1h (2.6.1, 3.1, 1.4.13, 1.5.10, 1.5.12, 9.1.2, 1.3.4, 1.5) are not yet amended in the spec; do it once the small-number rule is settled |
| `.Rprofile` activation and `use_setup()` (rest of 1c) | Not built: §22 holds them until the hooks have been run under the Render buttons (Q2) |
| Stages 0, 2, 3, 4 | not started |
| Usage | weekly window 81% at 08:00; stopped here rather than start stage 2 with too little left to finish a review round |

## How to run things

- Suite: `Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent")); print(r[r$failed>0|r$error, c("file","test")])'` (about 9 minutes).
- Check: `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")` (about 8 minutes; run in the background).
- Usage left: newest file in `~/.claude/usage-live/` (`five_hour`, `seven_day`). The weekly window was 76% used at 03:00.

## Next

1. Stage 2 (dictionary, quantities, ledger, `changes()`): write
   `dev/design-2.md` first, then the same cycle as stage 1 (tests from the
   contract, a different implementer, an independent review, regression
   tests, a fixer).
2. The items in `dev/decisions.md` under "For Robin" and
   `dev/open-findings.md`.
3. `.Rprofile` activation and `use_setup()`, once the hooks have been run
   under the Render buttons.
