# Build log

Newest state first. Read this before anything else after a context reset.

## Conditions of the run

- Started 2026-11-11 late evening. Mac on battery (29% at the start) and the
  weekly usage window 71% spent, so agents are dispatched one at a time and
  everything is committed at each boundary.
- Method: `dev/decisions.md` entry 1. Internal contract for stage 1a:
  `dev/design-1a.md`.
- `Rscript file.R` is blocked on battery by a hook; append `# battery-ok`.

## State (12 Nov)

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
| Stage 1h (`dev/design-1h.md`) | Built and committed: the `list` key and the `none` key. Not reviewed |
| Stage 1i (`dev/design-1i.md`) | A number that prints as zero prints "0.0" and records a warned check: contract written, tests being written; replaces 1g's fallback |
| `PACKAGE-SCOPING.md` | Amended for 1f to 1i in one commit (it states the 1i rule ahead of the code) |
| `.Rprofile` activation and `use_setup()` (rest of 1c) | Not built: §22 holds them until the hooks have been run under the Render buttons (Q2) |
| Stage 2 | `dev/design-2.md`: five packages (2a dictionary object, 2b printing quantities, 2c tooling, 2d ledger and condition log, 2e pipeline and `changes()`); full contracts for 2a and 2b, outlines for the rest |
| Stage 2a, the dictionary object | Built, reviewed, fixed and committed (1065cb0, b0347d9) |
| Stage 2b, printing quantities | Built, reviewed, fixed and committed (ab902cd, 803c91a). `#` carries the unit and the `unit` key, by Robin's ruling of 12 November 2026 (1eaaeff) |
| Stage 2f, unit names and unit settings (`dev/design-2f.md`) | Designed, built, reviewed (`dev/review-2f.md`), fixed and committed (5f2aec1, 898221a). Not in the original §22 order; added on Robin's approval. `PACKAGE-SCOPING.md` amended for it and for the rulings after its review |
| Stage 2c, dictionary tooling (`dev/design-2c.md`) | Designed, built (c440a72), reviewed (`dev/review-2c.md`, rulings f03b1d0, in `dev/design-2c.md`). Fix round in progress: regression tests moved into the suite (0ce4cb6), the fixes not yet committed |
| Stage 2g, weft's default units (`dev/design-2g.md`) | Added on Robin's instruction of 12 November 2026. Designed, built (827e80f). Not yet reviewed |
| `PACKAGE-SCOPING.md` for 2c and 2g | Amended to state both as built, with the rulings so far (2c's review, 2g's test-writer and implementer reports) |
| Stages 2d, 2e | Not started |
| Suite | 1,776 tests passing at 827e80f |
| Stages 0, 3, 4 | not started |
| Usage | weekly window 81% at 08:00; stopped here rather than start stage 2 with too little left to finish a review round |

## How to run things

- Suite: `Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent")); print(r[r$failed>0|r$error, c("file","test")])'` (about 9 minutes).
- Check: `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")` (about 8 minutes; run in the background).
- Usage left: newest file in `~/.claude/usage-live/` (`five_hour`, `seven_day`). The weekly window was 76% used at 03:00.

## Next

1. Finish the fix round for 2c, then review 2g (`dev/design-2g.md`).
2. Stage 2, the rest (2d ledger and condition log, 2e pipeline and
   `changes()`): the same cycle as stage 1 (contract in `dev/design-2.md`,
   tests from it, a different implementer, an independent review, regression
   tests, a fixer). 2a, 2b and 2f are done; 2c and 2g are built.
3. The items in `dev/decisions.md` under "For Robin" and
   `dev/open-findings.md`.
4. `.Rprofile` activation and `use_setup()`, once the hooks have been run
   under the Render buttons.
