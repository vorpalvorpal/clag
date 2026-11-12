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
- **As of 5ca2514**: ALL packages are built and on `main` (stage 3 with
  its review fixes and decision 66; 4a gate; 4b installers; 4c
  `verify()`; 4d `use_setup()`). Whole suite at def127c: 3,902 tests,
  4 failing, all four since corrected as test faults (eaa865a).
  `dev/review-4.md` (17 findings, 7 design questions, rulings at its
  end, two of them refined) has its failing regression tests on `main`
  (`test-review-4.R`, 52 tests, 35 failing by design). WAITING for the
  5-hour usage window to reset (a background sleep notifies), THEN:
  1. stage 4 fixer (sonnet, worktree): make `test-review-4.R` pass per
     the rulings; it will change the hook and CI templates (#13, #14),
     after which `h4_hook_expected` / `h4_ci_expected` in
     `helper-4b.R` need a test editor; no test for #9 (cache identity)
     exists, the fixer implements it from the ruling;
  2. `test-gate-edits.R` (owed, design-4 section 5);
  3. spec editor: `PACKAGE-SCOPING.md` for stage 3 (section 5,
     design-3 readings, review-3 rulings, decision 66), stage 4
     (sections 6, 8, 9, design-4 readings, review-4 rulings), and
     decisions 64 to 67 (write 67 for the review-4 design changes);
  4. whole suite on a `git archive` export, `devtools::check()`;
  5. build log totals;
  6. NEW from Robin (13 Nov, after the stage 4 review): "When you have
     finished the build. Look through the entire code base and look
     for what should be refactored or simplified or made more robust
     or otherwise improved, and then do it. And also create thorough
     documentation for the package and publish it on GitHub." So after
     the build: (a) an opus survey of the whole code base for
     refactoring, simplification and robustness, rulings, then the
     work under the whole suite (behaviour-preserving, in small
     commits); (b) thorough documentation (README, vignettes or
     articles, reference pages, a pkgdown site) published on GitHub.
     This lifts the build prompt's "do not publish a website" for the
     documentation only. Check the repository's visibility first
     (`gh repo view --json visibility`): if it is private, a Pages
     site would be public, so say so and choose with care;
  7. closing report.
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
