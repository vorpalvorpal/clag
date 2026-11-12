# Current state

Kept by the orchestrator so the work survives a context reset. Read this
first, then `dev/build-log.md`.

## Standing instructions (13 Nov, from Robin)

- Keep going until everything in `dev/build-prompt.md` is finished: the
  waiting items, stage 0, stage 3, stage 4, then `.Rprofile` activation and
  `use_setup()` (command-line tests only; the Render buttons stay untested).
- Decisions are delegated: think through the alternatives, decide, record the
  reasoning in `dev/decisions.md`.
- TDD with a separate test-writer and implementer. Do not use werkbank.
- 8 GB of RAM: few R jobs at once. Parallel builds go in worktrees
  (`Agent` with `isolation: "worktree"`), cherry-picked onto `main`.
- Commit and push at each boundary with named paths. Never `git add -A`.
- Write only inside this repository. Tests must not write to the user's cache
  directory.

## Cycle for each package

1. Design note by an opus agent (`dev/design-<n>.md`): contract, decisions
   with alternatives, questions.
2. Failing tests by a sonnet test-writer that never reads `R/`.
3. Code by a different sonnet implementer that never edits tests.
4. Whole suite, then an independent opus review that reproduces findings.
5. Rulings, regression tests, fixer, spec editor, build log.

## Done

- Stages 1 and 2, the trial fixes (2i), the speed work and the closing
  review. `main` at 0e65096: check 0 errors, 0 warnings, 2 notes.

## In progress

- **W1 to W4 are built** (b6ec418; filters pass, whole suite not yet
  re-run). STILL OWED: the spec for decision 63 (9.1.10 cache on by
  default; 4.4.20 a compound prints names as typed; 4.4.7 a dictionary's
  units go with the project root; `dict_unmark()` exported) - fold into
  the next spec-editor run.
- **GitHub issues for r-quantities/units**: two drafts shown to Robin
  (export `ud_get_symbol()`/`ud_parse()`; a failed `install_unit()`
  leaves the symbol mapped and `remove_unit()` strips the old unit's
  symbol). NOT posted: wait for Robin's go-ahead and answers (both or
  one; keep the PR offer?). Installing units from GitHub was blocked by
  the permission system; do not retry.
- **Stage 0 inputs are ready** under `dev/trials/stage0/` (git-ignored):
  `audit-summary.md`, `findings.csv` (866 findings; 419 carry a quoted
  claim, 278 of those found verbatim in the sources), `pre/` (sources at
  the pre-remediation commit 5c72119 of the manuscript project, 46
  files). 42% of findings came from the rendered PDF and no source lint
  can reach them. Expected flag-recall of all lints together: 25 to 35%.
  Run `recall_check()` on these once stage 3 is built; a lint with no
  reproduced finding, or flagging nearly everything, goes back to design.
- **Stage 3**: `dev/design-3.md` is the contract (decision 64). Packages:
  3a foundation (`R/lint.R`, `R/lint-source.R`, `R/recall.R`,
  `inst/weft-claim-words.yml`; built first, alone), then 3b prose
  (`R/lint-prose.R`, `R/lint-pandoc.R`), 3c code (`R/lint-code.R`), 3d
  documents (`R/lint-doc.R`, tier-2 listing in `R/changes.R`) in parallel
  worktrees. Progress: 3a tests being written.
- **Stage 0** runs as each lint package merges: script
  `dev/trials/stage0/recall.R` (git-ignored), thresholds in the design
  note; only counts and verdicts go in the build log.

## Queue

1. Waiting items W1 to W4 (decision 63): units cache on by default;
   `dict_unmark()` exported; a compound prints as typed, names included;
   units a dictionary registers are removed with the project.
2. Stage 0: `recall_check()` and lint prototypes against the audit findings.
3. Stage 3: static lints (spec section 5).
4. Stage 4: gate, `verify()`, installers (spec sections 6, 8, 9).
5. `.Rprofile` activation and `use_setup()` (1c leftover).
6. Final: whole suite, check, build log, closing report.
