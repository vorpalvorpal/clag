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
| Stage 2c, dictionary tooling (`dev/design-2c.md`) | Designed, built (c440a72), reviewed (`dev/review-2c.md`, rulings in `dev/design-2c.md`), fixed (d37e33f) |
| Stage 2g, weft's default units (`dev/design-2g.md`) | Added on Robin's instruction of 12 November 2026. Designed, built (827e80f), reviewed (`dev/review-2g.md`, rulings in `dev/design-2g.md`), fixed (818020e) |
| Stage 2h, the unit ladder (`dev/design-2h.md`) | Added on Robin's approval of 12 November 2026 (completes decision 51, entry 52). Designed, built (80d3ff9), reviewed (`dev/review-2h.md`, rulings in `dev/design-2h.md`). Regression tests written (27 failing before the fix), fixes built. Finding 6 was re-ruled as decision 54 on the test-writer's report; decision 53 removed ladders from `display:` |
| `PACKAGE-SCOPING.md` for 2c, 2g and 2h | Amended to state all three as built, with the rulings after the reviews of 2c and 2g (rule 4.4.23 is new), and again for the rulings on the review of 2h (rules 4.2.1, 4.2.7, 4.4.13, 4.4.23) |
| Stage 2d, the ledger and the condition log (`dev/design-2d.md`) | Designed, tests written, built, reviewed (`dev/review-2d.md`, 11 findings, rulings in `dev/design-2d.md`), review fixes built. Not yet reviewed again |
| Review of the stage 2 fix rounds (`dev/review-2-fixes.md`) | Done: 9 findings, all fixed; rulings at the end of that file |
| Stage 2e-1, the pipeline (`dev/design-2e.md`) | Built; reviewed (`dev/review-2e1.md`, 14 findings, all ruled in `dev/design-2e.md`); regression tests (ef27b79) and fixes (4cc3481) done |
| Stage 2e-2, `changes()` and the third state (`dev/design-2e.md`) | Built (a22c9e5); reviewed (`dev/review-2e2.md`, 14 findings, ruled in `dev/design-2e.md`); fixes built |
| Sentences by `stringi` (decision 57, `dev/design-2d.md`) | Built. Replaces the abbreviation list the 2d build used |
| `PACKAGE-SCOPING.md` for 2e and decision 57 | Amended to state the pipeline (4.6.1 to 4.6.8), the third state (7.2), `changes()` (7.3), the conditions from `tar_meta()` (7.4), the ledger entry's `unit` and the sentence rule (7.1.1), `.weft/.gitignore` (9.3.2), and the "Did you mean" rule (4.1.2) |
| `PACKAGE-SCOPING.md` for 2d and the stage 2 fix rounds | Amended to state the ledger (7.1, `_weft/ledger/`), the condition log (7.4), 2.9.1 and 9.4.2 as built, and the rulings on the reviews of 2d and of the fix rounds (rules in 1.4.13, 1.4.20, 4.2.7, 4.4.1, 4.4.4, 4.4.8, 4.4.13, 4.4.14, 4.4.16, 4.4.19 to 4.4.21, 4.4.23, 4.7.1) |
| Fix round for the review of the pipeline (`dev/review-2e1.md`, rulings in `dev/design-2e.md`) | Regression tests written (ef27b79), fixes built (4cc3481). The guard on `dict` in a running target, `dict_values`, reports followed through `child=` and includes, `source()` paths in the header, the network cache keyed on the store's meta file, a non-literal `store`, one "Did you mean" rule, one `tar_dict()` per pipeline, `.weft/.gitignore`. Whole-suite count pending |
| Stage 2i, what the stage 2 trial showed (`dev/design-2i.md`, decisions 58 to 61) | Rulings I1 to I16 written (d9aa011), tests written (c801155), fixes built (5be6263 for the ledger and `changes()`, 5045853 for units and formats), follow-up for a project unit printed with `is:` by its name and four tests settled (da74174). I15 and I16 (reads in the setup chunk and through a reader function of the author's) were built with the 2e-1 review fixes. Whole-suite count pending |
| `bit64` in Suggests (e25a75d) | Two tests use `bit64`; it is now declared. Package check before it: 0 errors, 1 warning, 2 notes. Check after it not yet run |
| `PACKAGE-SCOPING.md` for 2i and the 2e-1 review fixes | Amended in place: 1.5.20 (chains), 2.6.12 (unit warning, new), 4.4.6, 4.4.8, 4.4.10, 4.4.20, 4.4.23, 4.4.24 (new), 4.6.4, 4.6.7, 4.6.8, 7.1.3, 7.2.2, 7.3.4, 7.3.9 (new), 7.4.1, 9.1.2, 9.1.5 to 9.1.7, 9.1.9 (new), 9.3.2 and the test list of section 21. Not committed by the spec editor |
| Performance (decision 62) | Made faster (26712d1), then the disk copy of the units tables made opt-in (69ac93b, `options(weft.units_cache = TRUE)`). Installed package, 245-line document: first `weft_setup()` in a session 1.08 s to about 0.6 s, or 0.15 s with the disk copy; later calls 0.12 s to 0.04 s; sentence extraction per entry 0.73 ms to 0.33 ms |
| Closing review of the fix rounds (`dev/review-closing.md`) | Done: 12 findings, all accepted. Review and rulings (a1c0e3b, "Record and rule on the closing review of the fix rounds"), tests (509f504), fixes (4d30004 for the ledger and units, 3519b3d "Fix what the closing review found in the pipeline"), one test narrowed to weft's own scan (49e8658). Whole-suite count pending |
| `PACKAGE-SCOPING.md` for the closing review and decision 62 | Amended in place: 4.4.24, 4.6.5, 4.6.6, 4.6.8, 7.1.1, 7.1.3, 7.1.4, 7.2.2, 7.4.1, the unit-registration text of section 4.4 (project units removed on another project's read and by `units_reset()`), 9.1.9 and 9.1.10 (new, the `weft.units_cache` option). Not committed by the spec editor |
| Suite | 2,758 tests at the code of 49e8658, the last whole-suite run: 1 failing, 0 skipped. The one failure was a test that the closing review's finding 12 made out of date; it is amended (407ca32) and its file passes. The whole suite has not been run since that amendment |
| Stages 0, 3, 4 | not started |
| Usage | 12 Nov evening: the weekly window was reset by Robin; about 10% of it used by the end of the fix rounds |

## For Robin (from the 2h review)

- Decisions 53 (no ladder in `display:`) and 54 (which rung a number takes when
  it fits none) were taken by the orchestrator, not by Robin. Both are
  reversible: 53 in `R/dict.R`, 54 in `ladder_pick()` in `R/units.R`.
- The cost of 54: under `mm|km`, 940 m prints "940,000 mm", not "0.9 km". The
  rule keeps every digit of a long number rather than lose the digits of a short
  one.

## For Robin (from 2d and 2e)

- Decisions 55 and 56 were taken by the orchestrator under delegation, not by
  Robin. Their Q/E question lists are in `dev/design-2d.md` and
  `dev/design-2e.md`.
- Decision 57 (the sentence stored in the ledger is cut with `stringi`, ICU)
  was asked for by Robin. ICU's abbreviation lists are thin, so a short list of
  weft's own stays (`dev/design-2d.md`). Built; stated in 7.1.1.
- The run-time guard on `dict` in a pipeline (4.6.8) was the reviewer's
  proposal and is adopted: a target that reads `dict` without passing through
  `tar_dict_deps()` stops the first make with a `weft_pipeline_error`, where it
  would otherwise give a stale number.
- `crew` workers are still unsupported by `tar_dict()`: they do not see the
  attached `dict`. Not run; in 4.6.7 and Q5.
- The ledger entry has a new field, `unit`, after `raw` (rule 7.1.1; the version
  stays 1). Dictionary thresholds are converted to that unit before `changes()`
  looks for a crossing.
- Three behaviours were left as built and are in `dev/open-findings.md`.

## For Robin (from the trial fixes, the closing review and the speed work)

- Decisions 58 to 62 were taken by the orchestrator under delegation.
  62: the copy of the units tables in the user's cache directory is
  written only under `options(weft.units_cache = TRUE)`. With it the
  first `weft_setup()` of a session is 0.15 s, without it about 0.6 s
  (1.08 s before the work).
- A bare quantity now warns (decision 58), so an inline `claim()` on a
  quantity with no format class warns too.
- With `ledger: false` weft does not look for upstream target
  conditions (7.1.3). That is the orchestrator's ruling on closing
  review 8 and is one early return in `chapter_reads()`.
- The repeated-unit warning never fires for the symbols `a`, `am`,
  `as`, `at`, `in` (4.4.24), to spare ordinary prose.
- A second `tar_dict()` in a plain `_targets.R` is found by a frame of
  `targets` on the call stack; see `dev/open-findings.md`.
- `R CMD check` notes the `units:::` calls and a `weft:::dict_unmark`
  that `tar_dict_deps()` writes into each target's command. Exporting
  `dict_unmark()` would clear the second.
- The fixes for the closing review were not themselves reviewed.

## How to run things

- Suite: `Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent")); print(r[r$failed>0|r$error, c("file","test")])'` (15 to 20 minutes).
- Check: `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")` (about 8 minutes; run in the background).
- Usage left: newest file in `~/.claude/usage-live/` (`five_hour`, `seven_day`). The weekly window was 76% used at 03:00.

## Next

1. The items in `dev/decisions.md` under "For Robin" and
   `dev/open-findings.md`.
2. `.Rprofile` activation and `use_setup()`, once the hooks have been run
   under the Render buttons.
3. Stages 0, 3 and 4.
