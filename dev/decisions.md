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
4. **3.1.4, a check "as written".** Outside inline R, R keeps a call's
   source text only under `keep.source`. Chosen: quote the kept source where
   there is one and the deparsed call otherwise; the rule now says so.
   Reverse: nothing to reverse, it is a limit of R.
5. **1.4.13, rounding and wholeness.** The rule gave neither. Chosen: half
   away from zero on the decimal number as written (R's `round()` gives 0.15
   as "0.1"), whole within 1e-9, and no "−0.0". Reverse: one function in
   `R/format.R`.
6. **1.4.2, `.pct` or `.sci` with a wording class.** Stage ii acts on the
   text stage i printed, and "3%" has no spelled form the rules give.
   Chosen: a construct error. Reverse: drop the check in `R/scan.R`.
7. **1.9.1, a weft key on a link.** Pandoc reads `[a](u){if="x"}` as a link
   with an attribute, the hooks would never evaluate the guard, and the
   filter looks only at spans. Chosen: a construct error, with the same for
   an attribute block on inline R inside a link target. Reverse: drop the
   two checks in `R/scan.R`.
8. **3.1, a check that raises an error.** 2.6.1 says a failed check is one
   that is not `TRUE`. Chosen: an error in a check is a failed check and is
   reported with its message, so the other checks of the same `claim()` are
   still reported. Reverse: `R/claim.R`.
9. **9.1, unknown and bad settings.** Chosen: an unknown key warns and names
   itself; a value of the wrong type or range is an error when the
   configuration is read. Reverse: `R/config.R`.
10. **2.1.7 / Q16, plain `knit()`.** Found the cause: knitr applies its
    markdown output hooks only if its default hooks are untouched when the
    knit starts. Chosen: install only `before.knit`/`after.knit` outside a
    knit and the rest from `before.knit`. Reverse: `R/hooks.R`.
11. **2.1.8 (new), functions on the search path.** The smallest weft
    document (9.2.8) calls only `weft::weft_setup()`, yet its inline R calls
    `claim()`. Chosen: `weft_setup()` attaches the exported prose functions
    at the end of the search path. Reverse: delete the attach in
    `R/hooks.R`; documents then need `library(weft)`.
12. **9.4.3, draft mode and code that does not parse.** knitr parses inline
    code before any hook runs, so weft cannot turn that error into a marker
    without a preprocessor (2.1.1 excludes one). Chosen: it stays fatal in
    draft mode; the rule says so.
13. **Design note, the collection file.** A Quarto pre-render script cannot
    set an environment variable for the render. Chosen: the collection file
    is found by its existence under the project root. Reverse: the lookup in
    the filter and in `R/state.R`.
