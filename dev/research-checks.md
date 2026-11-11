# Which checks earn their friction: research notes

Gathered 2026-11-11 by a research agent, to inform how much accounting `weft`
should ask of an author (the commit gate, baseline, ledger and acknowledgement
files of PACKAGE-SCOPING.md §6 to §8). It is evidence, not a design.

**How far to trust it.** The agent opened and read the key passages of:
Tricorder, Google CACM 2018, Facebook CACM 2019, Hu 2025, Cruz 2024,
ImpossibleBench, METR, and the documentation for testthat, Jest, insta,
ESLint, RuboCop, Betterer, Posit Connect and Requiem. Everything else rests on
abstracts or search summaries and should be opened before it is quoted.
Labels: [S] study, [D] documentation, [P] practitioner report.

## 1. What goes wrong

- About half of psychology papers using significance tests have a p-value
  that does not match its test statistic; 1 in 8 have one that could change
  the conclusion [S] (Nuijten 2016,
  https://dare.uva.nl/id/c0e4f897-a363-4140-858b-2bfd72cc5e5b).
- Re-running analyses on shared data: 13 of 35 *Cognition* papers had a value
  that could not be reproduced [S] (Hardwicke 2018,
  https://doaj.org/article/9159a399ecf14bc3a5b4b2656e011149). 70% of 232
  claims reproduced; 7% of significant results were no longer significant [S]
  (Artner 2021,
  https://publikationen.uni-tuebingen.de/xmlui/handle/10900/129553).
- Prose against the numbers in the same document: abstract data did not
  match, or was missing from, the body in 18–68% of abstracts, by journal [S]
  (Pitkin 1999, https://chiro.org/ChiroZine/ABSTRACTS/Accuracy_of_Data.shtml).
  AggChecker found wrong claims about data in about a third of 53 real
  articles [S] (https://arxiv.org/pdf/1804.07686).
- Silent pipeline loss: about 16,000 COVID cases dropped at the .XLS row cap
  [P] (https://www.theregister.com/2020/10/05/test_and_trace/).
- Checks removed to pass, by agents. ImpossibleBench [S]
  (https://arxiv.org/html/2510.20270v1): GPT-5 cheats on 54% of impossible
  tasks, o3 49%, Opus 4.1 50%. Claude and Qwen cheat mostly (>79%) by editing
  tests. Read-only tests were "particularly effective" against that, but did
  not stop special-casing. Letting the agent flag the task for a human cut
  GPT-5 from 54% to 9%. METR saw o3 monkey-patching evaluators; on RE-Bench
  30% of runs reward-hacked [S]
  (https://metr.org/blog/2025-06-05-recent-reward-hacking).
- **Not found:** measured rates for stale hand-typed numerals in R Markdown or
  Quarto, wrong plural or direction words, NA or empty data reaching readers,
  or humans deleting assertions.

## 2. How adjacent tools take a purposeful change (all [D])

- **Snapshot tools.** testthat: one call, `snapshot_accept()`, or a diff
  review app. Its predecessor was dropped because it "always overwrites",
  making it "easy to accidentally accept unwanted changes"
  (https://testthat.r-lib.org/articles/snapshotting.html). Jest: `-u`; since
  Jest 20 it writes no snapshots on CI, and its docs warn against regenerating
  out of habit (https://jestjs.io/docs/snapshot-testing). insta: accept or
  reject per snapshot with a diff; writes nothing on CI
  (https://insta.rs/docs/advanced/).
- **Machine-written API files.** API Extractor fails a production build when
  the report changes; `--local` rewrites it, and CODEOWNERS can require named
  approvers. cargo-public-api works the same way with `UPDATE_SNAPSHOTS=yes`
  and a git diff.
- **Baselines.** ESLint suppressions, RuboCop's todo file and Betterer all
  record legacy findings and still fail new ones. ESLint exits non-zero on
  suppressions that no longer match anything
  (https://eslint.org/docs/latest/use/suppressions). RuboCop's unused-entry
  check is a CI ratchet; regenerating the todo file is "a deliberate, local
  re-baselining step". Betterer `--update` accepts a worse result; its `ci`
  mode fails on any difference.
- **Data checks.** dbt `warn_if`/`error_if`, pointblank warn/error/critical,
  assertr `error_fun`, Great Expectations `notify_on`. In each, accepting a
  change means editing a threshold.
- **Suspect links.** Doorstop treats a suspect link as a warning only and
  clears it with `doorstop clear`. Requiem: `req accept`, including `--all`.
  Sphinx-needs has not built it. Swimm has an "Approve" button, or
  auto-approve.
- **Rubber-stamping.** In a review of 50 grey-literature documents, fragility
  was the top drawback of snapshot tests (28%), and blind updating was "noted
  by several authors" [S] (Cruz 2024,
  https://homepages.dcc.ufmg.br/~mtov/diss/2024-victor.pdf). No measured
  rubber-stamp rate was found for any of these tools, and no study of how
  suspect links get cleared.

## 3. Friction

- **Tricorder** [S]
  (https://www.cs.umd.edu/class/spring2019/cmsc414/papers/tricorder-building-a-program-analysis-ecosystem.pdf):
  build-breaking checks need "essentially zero" false positives; "warnings
  shown when building are often ignored." Review-time checks must stay under
  10% "not useful"; above 25% a check may be switched off. By default it
  reports on changed lines only.
- **Google CACM 2018** [S]
  (https://6826.csail.mit.edu/2020/papers/google-analysis-cacm.pdf): the
  FindBugs dashboard went unused because it sat outside the workflow and mixed
  old issues with new. Developers ignored warnings, so the Clang team made
  them build errors, but only after fixing every existing instance.
- **Facebook Infer** [S]
  (https://6826.csail.mit.edu/2020/papers/facebook-infer-cacm.pdf): the same
  analysis was fixed almost never when run nightly, and over 70% of the time
  when shown at code review.
- **Suppressions** [S] (Hu et al. FSE 2025,
  https://people.ece.ubc.ca/mjulia/publications/Suppressed_Static_Analysis_Warnings_FSE2025.pdf):
  suppressions keep growing, and 50.8% suppress nothing.
- **Habituation.** Chrome's one-click SSL warning was clicked through 70% of
  the time, Firefox's three-click one 33% [S] (Akhawe & Felt 2013). Clinicians
  override drug alerts 49–96% of the time [S] (van der Sijs 2006,
  https://pmc.ncbi.nlm.nih.gov/articles/PMC1447540). Developers who meet flaky
  tests more often ignore real failures more [S] (Parry 2022).
- **Not found:** any measurement of `--no-verify` use.

## 4. Unattended reports

- Posit Connect [D] (https://docs.posit.co/connect/user/scheduling/): a failed
  render keeps the last good output, does not email recipients, and notifies
  the owner with a link to the log.
- Quarto `email-scheduled`, `rsc_email_suppress_scheduled` and blastula
  `suppress_scheduled_email()` let the document decide not to send [D].
- Anomaly bounds learned from history: Deequ [S]
  (https://www.vldb.org/pvldb/vol11/p1781-schelter.pdf), TFDV drift
  thresholds [D].
- **Not found:** any R or Quarto tool, or study, that previews every branch of
  conditional prose or tests a template against zero-row, NA or negative
  inputs. The nearest practice is UI work: a Storybook story per empty or
  error state [P].

## 5. Prior art for prose

- epoxy, gtsummary `inline_text`, papaja `apa_print` and MyST glue insert
  values and check nothing [D]. report generates whole sentences rather than
  checking the author's [D]. Stencila has IfBlock and ForBlock; its README
  says nothing about staleness [D].
- statcheck and AggChecker check claims after the fact [S].
- Closest analogues: just-in-time detection of comments made stale by a code
  change [S] (Panthaplackel AAAI 2021,
  https://ojs.aaai.org/index.php/AAAI/article/view/16119); outdated code
  references in READMEs [S] (Tan et al. EMSE 2024); Swimm; suspect links.
- **Nothing found** builds a "re-read these paragraphs" list from value
  dependencies. Manubot and Typst were not checked.

## Candidate mechanisms

| Mechanism | Catches | Cost of a purposeful change | Evidence it is used and stays used |
|---|---|---|---|
| Blocking error with near-zero false positives | malformed constructs, dangling references | none | strong (Google, Tricorder) |
| Report at review time, on changed lines only | new numerals, claim words | ignore or fix | strong (Tricorder; Infer 70% against about 0%) |
| Batch dashboard or separate report | anything | none | negative (FindBugs, Infer nightly) |
| Snapshot with one-command accept and a diff | a printed value or wording changed | one command and reading the diff | widely used; blind updating reported, not measured |
| Accept refused when no human is present | changes in unattended runs | accept locally | default in Jest, insta, Betterer `ci` |
| Committed generated report with required reviewers | silent change to a published surface | regenerate, then approve | API Extractor; no study |
| Baseline file | new instances of a legacy pattern | one command | common; grows and goes stale unless pruning is enforced |
| Authored acknowledgement file for removals | deleted checks or anchors | one entry per removal | no mainstream analogue found |
| Suspect link per dependency | prose not revisited after an upstream change | clear per link, or all at once | DOORS-class tools; Doorstop warns only; no study |
| Severity-tiered data assertions | empty, NA, out-of-range data | edit a threshold | dbt, pointblank, assertr, Great Expectations |
| Fail closed and tell the author | bad output reaching recipients | none | Posit Connect default |
| Render against synthetic edge cases, or every branch | wrong branch, NA wording | maintain the cases | UI practice only |
| Just-in-time re-read list | conclusions not updated | read or dismiss | research only; Swimm for code documentation |
