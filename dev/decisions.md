# Decisions made during the build

Each entry: the rule, what was found, what was chosen, how to reverse it.

## For Robin

Choices that are large, hard to undo, or a matter of taste. Not made; built
around.

- **Defaults of the number formatters (9.1.2).** The spec names the settings
  and gives no default values or key names. The build uses the values in
  `dev/design-1a.md` ("Defaults the spec does not give"): one decimal place,
  `.` and `,` marks with the thousands mark from 10,000 up, U+2212 for minus,
  count threshold ten, word limit one hundred. They are all in one list in
  `R/config.R`; change them there and in §9.1.

## Made

1. **How the build was run (build prompt, "How to build").** Robin said,
   just after the start, not to use werkbank. No werkbank skill, agent or
   tool is used. Plain agents instead: a test-writer works from the rules and
   never sees code, the orchestrator checks the tests fail for the right
   reason, a different agent implements without editing tests, and a third
   agent reviews by running cases of its own.
2. **Key names in `_weft.yml` (9.1.2).** Not given by the spec. Chosen: the
   names in `dev/design-1a.md`, now written into §9.1.2. Reverse: rename in
   `R/config.R` and §9.1.2.
3. **"Set up" (9.3.2).** The spec says logs are written only in a project
   set up with `use_weft()` and does not say how that is detected. Chosen: a
   project whose root holds `_weft.yml`. Reverse: one predicate in
   `R/config.R`.
