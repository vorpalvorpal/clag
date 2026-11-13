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
- **As of e8c1609 the BUILD IS FINISHED**: every package on `main`,
  both reviews fixed (`dev/review-3.md`, `dev/review-4.md`), spec
  current for stages 0 to 4 (decisions 1 to 67), the 72 gate edits
  ported. Whole suite at ac4a339: 3,955 tests, 0 failing, 1 skipped
  (plus 74 gate-edits tests run apart). `devtools::check()` was
  started on e8c1609 (output in the scratchpad `suite/check.out`);
  put its result in the build log.
- **Post-build work Robin asked for (13 Nov)**, in his words: "Look
  through the entire code base and look for what should be refactored
  or simplified or made more robust or otherwise improved, and then
  do it. And also create thorough documentation for the package and
  publish it on GitHub." "Rename the repo as well." (done: the
  repository is `vorpalvorpal/weft`, public; the local folder stays
  `/Users/rjs/dev/clag`.) "Also include speed optimisations and the
  test suite in the code review. Speed optimisations should only be
  taken when they are real and they don't degrade code quality."
  "Real meant both that it existed, and that it was an actual gain.
  Eg 1ms speed up on a rarely used function isn't real. Look where
  actual bottlenecks are, and target those."
  - PROFILE (done; installed package, medians): knit of a realistic
    chapter 1.1 s with weft against 0.02 s plain (quadratic per
    document in `starts_sentence` / `ledger_sentence_at`, and a second
    scan at knit start); `lints()` on a real-size project 52 s tier 1,
    67 s tiers 1:2, of which 28 s is the reading floor (`line_texts()`
    slicing the whole text per line, about seven times per file) and
    `mask_prose()` recomputed per rule; `gate()` cold 5 to 10 s,
    `verify(static = TRUE)` 8 s, `changes()` 2.9 s (all lints);
    test suite 18.6 min, 20 slowest files 583 s (real renders and
    `tar_make`). NOT worth touching: package load 0.07 s, config and
    dictionary reads, `status()`, `use_weft()`, warm gate 0.12 s, the
    filter's 0.3 s, the first unit use 0.6 s cold.
  - RUNNING in worktrees: two speed fixers (lint reader: `R/scan*.R`,
    `R/lint-*.R`, `R/changes.R`; knit path: `R/resolve.R`,
    `R/ledger.R`, `R/hooks.R`), outputs to stay identical.
  - RUNNING read-only: four opus reviewers writing
    `dev/review-code-a.md` (rendering core), `-b.md` (units,
    dictionary, targets, ledger, config), `-c.md` (lints, gate,
    verify, installers), `-tests.md` (the test suite). THEN: rule on
    the proposals (append rulings to each file), carry them out after
    the speed fixes merge, in small behaviour-preserving commits by
    area in worktrees, whole suite after each merge.
  - THEN documentation: README, articles (getting started, values and
    formatters, wording and claims, units and the dictionary, targets,
    lints, the gate and verify, setting up a project, for agents),
    complete reference pages with examples, `_pkgdown.yml`, the site
    built and published to GitHub Pages of `vorpalvorpal/weft`
    (`gh-pages` branch or a Pages workflow), `URL` in DESCRIPTION.
    Nothing to CRAN, no release.
  - CLEAN UP at the end: delete the scratchpad folder `prof/real/` (a
    copy of the real manuscript made by the profiler), scratch
    libraries, worktrees; `find dev/trials -type l` must give 0.
  - THEN the closing report (what is built and passing, trial and
    stage 0 headlines, decisions one line each, items waiting on
    Robin incl. units PR #447 / issue #448 and `dev/open-findings.md`,
    what is untested: Render buttons, interactive chunks, Windows,
    real renv).
  Lesson: a helper defined twice in `R/` silently replaces the first;
  after every merge run
  `grep -hoE '^[A-Za-z_.][A-Za-z0-9_.]* *(<-|=) *function' R/*.R | sed -E 's/ *(<-|=).*//' | sort | uniq -d`
  (must print nothing).
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

## Note: the specification is now `dev/PACKAGE-SCOPING.md` (moved 13 Nov)

## Position at bcc3062 (13 Nov, evening; read this before the sections above)

The sections above are history; this one is current.

- **Refactor after the build.** Merged: lint and knit speed fixes;
  the foundations pass (`R/io.R`); the three behaviour fixers. All
  tests of `test-review-code-{a,b,c}.R` pass. What each review still
  has open is structural only and is listed at the end of
  `dev/review-code-a.md`, `-b.md`, `-c.md` ("State after the first
  fixer"). `dev/review-code-tests.md` (17 proposals, all accepted) is
  NOT started: bare `expect_error()`, skips that hide regressions, git
  under the user's config, slow gate-edits and renders, wall-clock
  bounds (review A #28 and `test-lint-perf.R:42` fail under load).
- **Documentation.** README, nine articles, `_pkgdown.yml` and the
  Pages workflow are on `main`; the site is live at
  https://vorpalvorpal.github.io/weft/ and rebuilds on each push. The
  specification moved to `dev/PACKAGE-SCOPING.md`. Owed: reference
  examples, `vignettes/languages.Rmd` (5g), spec edits for decision 68.
- **Other languages (Robin, 13 Nov: "Do a", "Install Julia and build
  (a) with it").** Studies: `dev/languages-study.md`,
  `dev/languages-c-scoping.md` (values by name; spike in
  `dev/spikes/lang-c2/`). Contract: `dev/design-5.md` (decision 68;
  read its rulings and amendments at the end). Built and on `main`:
  5a exact integers, 5h conformance table
  (`tests/testthat/_conformance/`), 5b Python reader (`R/guest.R`,
  `inst/python/weft_guest.py`), 5e and 5f lints. Tests on `main`,
  failing by design until built: 5c and 5d (`test-guest-setup`,
  `-forms`, `-conditions`, `-reads`; implementer running in a
  worktree), 5J Julia (`helper-5j.R`, `test-julia-*.R`; implementer
  starts when 5c/5d land, same files). Then 5g the article, the spec
  editor for section 6 of the note, and a check workflow with Python
  and Julia (O3, O16).
- **Installed outside the repository for this:** Julia 1.13.3
  (Homebrew, with its dependencies), the R package JuliaCall,
  `~/.julia` (RCall); earlier, Homebrew `udunits`. Scratch virtualenvs
  with Jupyter, numpy and pandas live only in the scratchpad.
- **Waiting on Robin:** whether to build the resolver filter (stage 2
  of `dev/languages-c-scoping.md`); the rmarkdown issue and PR draft
  (scratchpad `rmdfix/`, nothing posted); units PR #447 / issue #448.
- **Suite:** always through the scratchpad `suite/fresh-suite.sh`,
  which exports `HEAD` first (an earlier run tested a stale copy).
  Push only after a run whose failures are all by design.
- **Then:** test-suite fixes; structure pass; `devtools::check()`;
  re-measure lint and knit times; clean up (scratchpad `prof/real/`,
  `lang/`, virtualenvs; `find dev/trials -type l` must give 0);
  closing report.

## Queue

1. Waiting items W1 to W4 (decision 63): units cache on by default;
   `dict_unmark()` exported; a compound prints as typed, names included;
   units a dictionary registers are removed with the project.
2. Stage 0: `recall_check()` and lint prototypes against the audit findings.
3. Stage 3: static lints (spec section 5).
4. Stage 4: gate, `verify()`, installers (spec sections 6, 8, 9).
5. `.Rprofile` activation and `use_setup()` (1c leftover).
6. Final: whole suite, check, build log, closing report.
