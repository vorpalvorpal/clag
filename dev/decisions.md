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

- **From the trials: an empty list (1.3.4).** A value of length zero is a
  missing value, so `` `r flagged`{.and} `` fails the render on the ordinary
  day when nothing is flagged, and every such list needs an `if` around it.
  A key for the empty case (`none="none"`) would be new syntax. Not made.
- **From the trials: a check that warns.** Every failed check fails the
  render (2.6.1). An unattended report wants some checks to be reported and
  the report still sent. Severity exists for conditions (7.4.2) and not for
  claims. Not made: it changes what a claim is.
- **From the trials: a failed render leaves its output.** Outside draft mode
  knitr has written the document, markers included, before the `document`
  hook fails the render. A sender that looks only for the file would send
  the markers. Deleting the output is not weft's to do under rmarkdown
  (2.6.6 keeps a book's chapters on purpose). Not made; the daily report
  should test the exit status.
- **From the trials: `.num` printing a small number as "0.0" (1.4.13).** A
  standard error or a small difference loses its whole value silently
  unless the author writes `sigfig`. Options: fail when a non-zero number
  prints as zero, or fall back to significant figures. Not made.
- **From the trials: house-style defaults.** The chapter writes a thousands
  mark from 1,000, words up to and including ten, and a serial comma. The
  build's defaults (10,000; digits from ten; none) changed its text.
  `count_threshold` is a setting already; a threshold for the thousands
  mark and a serial-comma setting are not. Not made.
- **From the trials: trimmed arms (1.5.12).** A span whose arm is a whole
  sentence cannot carry the space that follows it. Not made.

- **From the review of 1b: `.p` near a threshold.** 0.046 prints "p =
  0.05", so a sentence can read "significant (p = 0.05)". The two-decimal
  form was the build's choice (decision 21). Options: three decimals below
  0.1, or two significant figures. Not changed.
- **Draft output of a report whose checks chunk has `error=TRUE`.** Each
  failed check prints its own error block into the body (second trial,
  `dev/field-notes.md` report 3). Decide with the warn-level item whether
  a draft of an unattended report should carry them.
- **`last_knit()` is internal.** Export it, or expose `sentence_starts`
  and the construct records some other way.

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
14. **1.4.10, a vector with no collapse class.** The rule was silent and
    the first build ran the elements together ("1.52"). Chosen: joined with
    ", " as stock knitr prints an inline vector. Reverse: `R/format.R`.
15. **2.6.3, what a failed guard is quoted by.** The example in 2.6.2 shows
    the printed sentence. Chosen: the phrase as printed.
16. **2.5.2 and `knit_exit()`.** Chosen: the end-of-document check stops
    where the knit stopped. Reverse: `R/hooks.R`.
17. **2.6.4 against 1.1.8, an error in a bare value.** Chosen: it stops the
    knit as stock does; only constructs are collected. The rule says so now.
18. **9.4.2, the draft-mode JSON file.** Named
    `<document>.weft-failures.json`, beside the document.
19. **§22, the order of 1b and 1c.** Both trials found that most
    value-dependent wording they met lives in captions, table titles and
    strings built in R code, and that a construct written there printed
    raw with no error. Chosen: build `weft_str()`, captions in chunk options
    and front-matter constructs (1c, without `.Rprofile` activation) before
    1b. §22 is edited to say so. Reverse: nothing to reverse.
20. **knitr 1.51 or later.** knitr before 1.51 never calls the
    `before.knit` hook that decision 10 relies on, so a document activated
    from its front matter rendered unresolved with no error. Chosen:
    `Imports: knitr (>= 1.51)`, and `weft_setup()` stops with a clear error
    on an older knitr. Reverse: needs another answer to Q16.
21. **Stages 1b and 1d, formats the rules leave open.** `.p` thresholds and
    decimals, the en dash of `.range`, the sound rule of `.a`, the default
    date format, the "and N others" of `trunc`, the block forms of the list
    classes, the named fractions and tolerance of `about()`, the cases of
    `of_n()`, the argument lists of `ci()`, `pm()` and `clamp()`, and the
    sentence-start list are each decided in `dev/design-1b.md` ("What the
    spec leaves open"). Several are matters of wording and are Robin's to
    confirm. Reverse: each is one function in `R/format.R` or
    `R/phrases.R`.
22. **1.10, captions and strings.** Only a caption written as a literal is
    resolved; a caption computed by R code is data (2.2.4). Bare inline R in
    a caption stays as stock leaves it; in a `weft_str()` string it is
    evaluated. A construct in a front-matter field other than the four of
    1.10.7 is a construct error. Reverse: `R/captions.R`,
    `R/scan-contexts.R`.
23. **3.7, how `rehearse()` runs a case.** A Quarto render inside a project
    writes `_freeze` and the output directory, which 3.7.2 forbids. Chosen:
    `rehearse()` runs the knit only, in a fresh R process with output in a
    temporary directory. Cost: `{{< include >}}` is not expanded and
    project metadata is not read during a rehearsal. Reverse: `R/rehearse.R`.
24. **1.4.6, a list value inside a container.** A `.ul`, `.ol` or `.dl`
    value alone in a paragraph of a list item, block quote or table cell
    was emitted unindented and joined the outer list. Chosen: a construct
    error; the rule says so. Reverse: indent the block by its container's
    prefix in `R/resolve.R`.
25. **3.5, a formatter on a phrase.** `of_n(...)` with `.word` printed
    "three" and dropped the phrase. Chosen: a number or wording class on
    the result of a phrase function is a value error. Reverse:
    `R/format.R`.
26. **1.6.8, `.date`.** It prints English month names. Chosen: a construct
    error under a `lang` that is not English; the rule lists it now.
27. **3.7.2, how a rehearsal's child process starts.** The review of 1e
    found a document activated from the project `.Rprofile` could not be
    rehearsed. Chosen: the child starts in the project root and reads its
    `.Rprofile`, as a render does; the knit's working directory is the
    document's. Reverse: `R/rehearse.R` (add `--vanilla` back).
28. **3.7.2, case names.** A case named after a column of the result
    (`file`, `span`, `reached` and the rest) is an error before anything
    runs. Reverse: `R/rehearse.R`.
29. **3.7.3, a span that chose no arm.** It has a row in `chosen` with
    `arm` `NA` and is not in `unevaluated`. Reverse: `R/rehearse.R`.
