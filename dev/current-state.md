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
- **units upstream**: bug posted as r-quantities/units#448 with the fix
  as PR #447 (branch `refuse-install-before-mapping` on the fork
  vorpalvorpal/units; scratch clone in the scratchpad `unitsfix/src`).
  Watch for the maintainers' CI and replies; act on them only with
  Robin's say. When the fix is released, weft's `units:::` workaround in
  `ud_install_one()` (`R/unit-defaults.R`) can go, with its check note.
  Installed units is CRAN 1.0.1; Homebrew `udunits` 2.2.28 was installed
  for the test build.
- **Stage 0 inputs are ready** under `dev/trials/stage0/` (git-ignored):
  `audit-summary.md`, `findings.csv` (866 findings; 419 carry a quoted
  claim, 278 of those found verbatim in the sources), `pre/` (sources at
  the pre-remediation commit 5c72119 of the manuscript project, 46
  files). 42% of findings came from the rendered PDF and no source lint
  can reach them. Expected flag-recall of all lints together: 25 to 35%.
  Run `recall_check()` on these once stage 3 is built; a lint with no
  reproduced finding, or flagging nearly everything, goes back to design.
- **Stage 3**: `dev/design-3.md` is the contract (decision 64). 3a is
  built and on `main` (5940aeb; its 206 tests pass after test faults
  were fixed). Implementers for 3b (`R/lint-prose.R`,
  `R/lint-pandoc.R`), 3c (`R/lint-code.R`) and 3d (`R/lint-doc.R`,
  tier-2 listing in `R/changes.R`) are running in worktrees; each
  commits on its branch, the orchestrator cherry-picks onto `main`,
  runs `devtools::document()`, removes the worktree. The rule registry
  interface they were given is in the scratchpad `registry.md` (a rule
  is a function `lint_<id>` found by name). Some `changes()` tests of 3d
  need 3b's `claim-word`. After all three: stage 0
  (`dev/trials/stage0/recall.R`), whole suite, opus review, fixes, spec.
- **Stage 4**: `dev/design-4.md` is the contract (decision 65). 4d
  (`use_setup()`, `.Rprofile` activation, `R/setup.R`) is built and on
  `main` (3c0b255); its tests pass. 4a (gate) tests are committed
  (19011f6) and wait for the stage 3 rules; then the 4a implementer,
  then 4b installers and 4c `verify()` (test-writers, then
  implementers, in parallel). Owed: `test-gate-edits.R`.
- **As of def127c**: ALL packages are built and on `main`: stage 3
  (3a to 3d), the stage 3 review fixes (`dev/review-3.md` with rulings;
  decision 66 trimmed the claim-word list), 4a gate, 4b installers
  (6cca012), 4c `verify()` (def127c), 4d `use_setup()`. The lint, gate
  and installer filters were clean at 621dbc9 (1,208 tests). A test
  editor is settling four disputed `verify` tests (uncommitted until
  it reports). NEXT, in order: commit those; whole suite on a `git
  archive` export; opus review of stage 4 (gate, installers, verify,
  setup) with reproduction, rulings, regression tests, fixer;
  `test-gate-edits.R` (owed); spec editor for stages 3 and 4 and
  decisions 64 to 66; `devtools::check()`; build log; closing report.
  Lesson: a helper defined twice in `R/` silently replaces the first
  (it broke `lints()` once); check with
  `grep -hoE '^[A-Za-z_.][A-Za-z0-9_.]* *(<-|=) *function' R/*.R | sed -E 's/ *(<-|=).*//' | sort | uniq -d`
  after every merge.
- **Stage 0 has run** (scripts and outputs under
  `dev/trials/stage0/`, git-ignored). Counts are to go into
  `dev/build-log.md`: 46 files, 5,508 sentences, 83.5 s; `construct`
  and `block-start` flag nothing; all rules reproduce 247 of 419 (59%)
  but `claim-word` flags 66% of sentences; without it 145 of 419
  (34.6%) at 29% of sentences; `numeral` 2,340 flags, 38 located, 22
  reproduced; a sample of 60 numeral flags: 22 real results, 20 years
  or dates, 14 section numbers, 3 identifiers, 1 other.
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
