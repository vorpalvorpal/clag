You are the orchestrator for building `weft`, an R package, from its design
document. I am asleep while you work, so do not ask me questions: make the
call, write down what you chose, and keep going. I will read the result in the
morning.

## Where things are

- **Repository:** `/Users/rjs/dev/clag`. The package is now named `weft`; the
  folder and the GitHub repository (`vorpalvorpal/clag`) keep the old name for
  now. Leave both names alone.
- **The spec:** `PACKAGE-SCOPING.md` (about 3,700 lines). Part 1 (§1–§9) is
  the rules, numbered; build from these. Part 2 is the reasons. Part 3 (§18
  to §20) says what was actually run in spikes, what was not, and the open
  questions. §21 lists the tests and §22 the build order.
- **`dev/spikes/`:** the throwaway code the design was tested with, with a
  README. `spike-cite/setup.R` is the most complete stand-in for the knitr
  hooks and is worth reading before writing the real ones. It is not the
  design: the start of §18 lists how it differs from the rules.
- **`dev/open-findings.md`:** what is still open, and a list of things already
  considered and turned down. Do not reopen those.
- **`dev/research-checks.md`:** evidence behind the design of the commit gate.
- The old `clag` code is gone from the tree (tag `clag-0.2.0`). Use none of it.

Start by reading the top of the spec, §22, §21, and then §1 to §3 as you need
them. The document is long: give sub-agents rule numbers and line ranges
rather than the whole file, and keep file dumps out of your own context.

## What to do, in order

1. **Build the kernel**, stage 1a of §22: the scanner, the knitr hooks,
   `weft_setup()`, values and formatters, `n` and `if` spans, `claim()`,
   collected failures with markers, the end-of-document check, the Lua filter
   and the pre-render check, under both Quarto and rmarkdown.

2. **Try it on two real documents**, and write down what hurt.
   - A daily report: `~/dev/report_service/Rmd/` (`rain.Rmd`,
     `garden_waste.Rmd`). These are rendered unattended on new data, which is
     the first use case in §10.
   - One chapter of a long report:
     `~/projects/10.02 Healthy waterways/R/chapters/`, a Quarto book on a
     `targets` pipeline. This is the second use case.
   - Both projects are read-only to you. Copy what you need into
     `dev/trials/`, which is git-ignored because it may hold council data, and
     work there. If a chapter cannot render from a copy, convert a section of
     it against objects saved into the trial folder, and say so.
   - Convert each document to weft constructs as an author would: typed
     numbers become values, wording that depends on a value becomes a span or
     gets a `claim()`. Then record in `dev/field-notes.md` what was awkward,
     what broke, what the rules got wrong, and what was missing. Keep data
     values and names of people out of that file; it is committed.

3. **Carry on through §22**: stages 1b to 1e, then 2 (dictionary, units,
   ledger, `changes()`), 3 (static lints) and 4 (the commit gate and
   `verify()`). Let the field notes change the order or the detail where they
   give a reason to. Get as far as you can.

## How to build

- **Tests first, by a different agent from the one that writes the code.** A
  test-writer works from the rules and §21 and never sees an implementation.
  Check the tests fail for the right reason. A separate implementer makes them
  pass and may not edit them; if it thinks a test is wrong it reports back and
  you decide. My global instructions set this out, and the `werkbank:tdd-plan`
  skill is built for it: use it where it fits.
- **A step is finished when** its tests pass under Quarto and under
  rmarkdown, `devtools::check()` has no errors or warnings, and it is
  committed and pushed. Commit at every such boundary, with named paths.
- **Pick the model for the job:** a small model for searching and reading,
  a mid-sized one for implementation and debugging, the largest for design,
  review and disputes. Run agents in parallel only when their work does not
  touch the same files.
- **Have someone other than the implementer look at each stage** before you
  move on: a fresh agent that runs the code against cases of its own, not one
  that reads the diff and agrees.

## When the spec turns out to be wrong

It will, somewhere: nothing in it has been built before. When a rule is
unbuildable, contradicts another, or the trial documents show it is a bad
idea:

- Choose the smallest change that is easy to undo.
- Change the rule in `PACKAGE-SCOPING.md` in the same commit as the code, so
  the document stays the truth about what the package does.
- Add an entry to `dev/decisions.md`: the rule number, what you found, what
  you chose, and how to reverse it.

Where a choice is large, hard to undo, or a matter of my taste (a change to
the syntax an author types, dropping a feature, a new dependency), do not
make it. Build around it, note it in `dev/decisions.md` under "for Robin",
and move to the next thing.

## Keep a log

Keep `dev/build-log.md` current: after each step, what is built, what
passes, what is failing and why, and what comes next. It is how the work
survives a context reset, and it is the first thing I will read.

## Limits

- Write only inside this repository. Read anything you need elsewhere.
- No force-pushes and no rewriting history. Do not rename the repository or
  the folder. Do not publish anything (CRAN, a website, a release).
- Do not install hooks, filters or `.Rprofile` lines into my real projects.
- Do not use the Windows laptop. Anything that needs Windows, or the Render
  button of RStudio or Positron, cannot be tested tonight: build what does not
  depend on it, and leave the item in §19. §22 already holds `.Rprofile`
  activation and `use_setup()` back for that reason.
- API keys are in the environment (my global instructions name the
  variables). Never write a key's value into a file.

## Practical notes

- macOS, R 4.4, knitr 1.51, Quarto 1.11.9. The Pandoc binary Quarto ships is
  `/Applications/quarto/bin/tools/aarch64/pandoc`.
- A hook may block `Rscript` to save battery. Its message says how to proceed.
- Pushing over SSH works at home. If it fails with an access-rights message,
  my global instructions give the HTTPS fallback.

## When you stop

End with a short report: what is built and passing, how far through §22 you
got, the headline findings from the two trial documents, every entry in
`dev/decisions.md` in one line each, and anything waiting on me.
