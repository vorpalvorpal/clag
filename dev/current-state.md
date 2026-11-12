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

- (nothing yet; updated below as work starts)

## Queue

1. Waiting items W1 to W4 (decision 63): units cache on by default;
   `dict_unmark()` exported; a compound prints as typed, names included;
   units a dictionary registers are removed with the project.
2. Stage 0: `recall_check()` and lint prototypes against the audit findings.
3. Stage 3: static lints (spec section 5).
4. Stage 4: gate, `verify()`, installers (spec sections 6, 8, 9).
5. `.Rprofile` activation and `use_setup()` (1c leftover).
6. Final: whole suite, check, build log, closing report.
