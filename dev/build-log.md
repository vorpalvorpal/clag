# Build log

Newest state first. Read this before anything else after a context reset.

## Conditions of the run

- Started 2026-11-11 late evening. Mac on battery (29% at the start) and the
  weekly usage window 71% spent, so agents are dispatched one at a time and
  everything is committed at each boundary.
- Method: `dev/decisions.md` entry 1. Internal contract for stage 1a:
  `dev/design-1a.md`.
- `Rscript file.R` is blocked on battery by a hook; append `# battery-ok`.

## State (03:10, 12 Nov)

| Step | State |
|---|---|
| **Stage 1a, the kernel** | **Done.** 365 tests pass under rmarkdown and Quarto; `devtools::check()` gives 0 errors, 0 warnings, 2 notes (clock; `cli` and `units` imported but not yet used). Two independent reviews (`dev/review-1a-A.md`, `dev/review-1a-B.md`), 45 findings fixed with a regression test each. Package C (filter, `use_quarto()`, book report, freeze) has tests but has not had its own independent review |
| Trials on two real documents | Done. `dev/field-notes.md`; six taste items under "for Robin" in `dev/decisions.md`. Trial files are in `dev/trials/` (not committed); the symlinks into the waterways project were removed because they broke `R CMD build` (list in `dev/trials/chapter/SYMLINKS-removed.txt`) |
| Stage 1c (captions, `weft_str()`, front matter, ten trial bugs), moved ahead of 1b | contract in `dev/design-1c.md`; test-writer running, writing into `tests/testthat/_1c/` |
| 1b, 1d, 1e, stages 2 to 4 | not started |

## How to run things

- Suite: `Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent")); print(r[r$failed>0|r$error, c("file","test")])'` (about 5 minutes).
- Check: `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")` (about 8 minutes; run in the background).
- Usage left: newest file in `~/.claude/usage-live/` (`five_hour`, `seven_day`). The weekly window was 76% used at 03:00.

## Next

1. 1c: move tests up, confirm they fail for the right reason, commit,
   implementer (sonnet), reviewer (opus) covering 1c and package C together.
2. 1b: design note, then the same cycle. Order inside 1b from the trials:
   `.p`, `.range`, `.cap`, `sign`, ids, then `.a`, `lookup()`, `brk()`,
   `cite`, `.weft-literal`.
3. Then 1d, 1e, and stages 2 to 4 as far as the usage allows.
