# Decisions made during the build

Each entry: the rule, what was found, what was chosen, how to reverse it.

## For Robin

Choices that are large, hard to undo, or a matter of taste. Not made; built
around.

- **Stage 2, six items (R1 to R6 in `dev/design-2.md` §5):** the YAML
  layout of a `breaks` entry (built as `below`/`at_most` maps); where the
  canonical spellings for `dict_vale()` live (recommended: an `avoid:`
  field; `dict_vale()` waits); a space before `%` and `°` on a quantity
  (built as rule 4.4.8 says, "35 %"); `jsonlite` to Imports for the ledger;
  the ledger's and condition log's file formats (read before 2d is
  built); an optional `symbol:` field (recommended: not now).
- **Stage 2b: a collapsed list of quantities that ends in a word.** With
  `.word`, `u(c(20, 5), m)` prints "20 and five": the unit follows the
  last numeral only when the last item is a numeral (4.4.2, 4.4.3 read
  literally), so here it is lost. Options: leave; print the unit after
  the last numeral wherever it is ("20 m and five"); make a mixed list a
  value error. Built as the literal reading.
- **Stage 2a: a unit held in a variable.** `u(1, x)` reads the unit
  `x`, as written (D17), so `sapply(c("m", "kg"), function(x) u(1, x))`
  cannot work. Options: leave and document `do.call(u, list(3, "m"))`;
  an argument (`u(1, unit = x, literal = FALSE)`); a second function
  (`u_chr(1, x)`). Not made; `do.call()` is documented.
- **`.Rprofile` activation and `use_setup()`.** Not a choice: they need the
  hooks run under the Render buttons of RStudio or Positron first (§22).

The other items that stood here were delegated by Robin on 2026-11-12
("happy to delegate decisions to you; document alternatives and reasons")
and are entries 30 to 37 under "Made".

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
30. **9.1.2, defaults of the number formatters.** Alternatives: R's own
    printing (seven significant figures); two decimals; one decimal.
    Chosen: keep the build's values (one decimal, `.` and `,` marks, U+2212
    minus, word limit one hundred), with the thousands mark as entry 34.
    Why: one decimal is what both trial documents mostly print, every value
    is a setting, and a longer default hides false precision. Reverse:
    `R/config.R`.
31. **2.6.1, a check that warns.** Alternatives: (a) every failed check
    fails the render, as built; (b) a level on the call, `claim(x, ...,
    level = "warn")`; (c) a project setting that downgrades all checks;
    (d) a second function. Chosen: (b). A warned check that fails is
    recorded and reported at the end of the render under its own heading,
    the value prints, no marker is left and the render does not fail. Why:
    the trials' unattended reports need "tell me, but send it"; the level
    belongs to the one check and is visible where it is written, which (c)
    loses; (d) adds a name for the same act. A guard cannot warn: its
    phrase would print false. Reverse: remove the argument in `R/claim.R`.
32. **2.6.6, a failed render leaves its output.** Alternatives: delete the
    output; rename it; leave it. Chosen: leave it, and say in the help for
    draft mode and `weft_setup()` that a sender must test the exit status.
    Why: the file is knitr's, a book keeps its chapters on purpose, and a
    deleted file hides what failed. No code.
33. **1.4.13, `.num` or `.pct` printing a number that is not zero as zero.**
    Alternatives: leave ("0.0"); fall back to significant figures; fail.
    Chosen: a value error when the digits are the default, with a message
    naming `sigfig` and `digits`; an author who writes `digits` or `sigfig`
    on the construct has chosen and gets what they asked for. Why: "0.0"
    for a real difference is a silently false sentence; a silent fallback
    prints numbers of mixed precision side by side. Reverse: `R/format.R`.
34. **9.1.2, house style.** Alternatives for the thousands mark: from
    10,000 (as built), from 1,000. For the serial comma: none, always, a
    setting. Chosen: new settings `thousands_from` (default 1000) and
    `serial_comma` (default `false`); `count_threshold` stays ten. Why:
    both trial documents write "1,000", so the old default changed their
    text; a serial comma is a house choice with no majority. Cost: a year
    given `.num` prints "2,024" (leave a year bare). Reverse: the default
    in `R/config.R`.
35. **`.p` near a threshold.** Alternatives: two decimals from 0.01 (as
    built: 0.046 prints "p = 0.05"); two significant figures; three
    decimals below 0.1. Chosen: three decimals below 0.1, two from 0.1 up
    ("p = 0.046", "p = 0.20"); below 0.001 and above 0.99 as before. Why:
    the values near 0.05 are the ones a reader acts on; two significant
    figures prints "0.0046". Reverse: `R/format.R`.
36. **Draft output of a report whose checks chunk has `error=TRUE`.**
    Alternatives: silence a failed check in chunk code in draft mode;
    leave it. Chosen: leave it. Why: `error=TRUE` is the author asking to
    see errors, a draft is not for sending, and the sendable case is
    entry 31. No code.
37. **`last_knit()`.** Alternatives: keep it internal; one accessor per
    record; export it. Chosen: export it with a help page. Why: one name,
    already the name the notes use, and `rehearse()` returns the same
    records. Reverse: drop the export.
38. **1.4.13, a small number under the default digits (Robin, 2026-11-12;
    replaces the value error of entry 33).** Robin asked for the first
    non-zero decimal instead of a failed render, safe against floating
    point noise. Chosen: one significant figure when the default digits
    would print zero; a number below 1e-9 in absolute value is zero.
    Alternatives for the noise rule: a relative tolerance (needs a second
    number to compare with); `zapsmall()` over a vector (the same value
    would print differently beside different neighbours). Contract:
    `dev/design-1g.md`. Reverse: `R/format.R`.
39. **1.5.12, an empty arm and the space beside it (Robin's choice,
    2026-11-12).** Of four options (leave; stop trimming; keep one edge
    space; the span owns the space beside it) Robin chose the last. When a
    span prints nothing, one adjacent space is removed. Contract:
    `dev/design-1g.md`. Reverse: `R/resolve.R`.
40. **1.3.4, a list that can be empty (Robin's choice, 2026-11-12).** Of
    five options (leave it and document `n="length(x)"`; a `list` key on a
    span; `n` taking a character vector; a `none` key on a value; a
    project-wide word) Robin chose the `list` key and the `none` key, with
    vectors of any type accepted. Guard kept: `NULL` is still a missing
    value, so a misspelt column cannot print the empty arm. Guard dropped
    at Robin's word: a number vector needs no class. Contract:
    `dev/design-1h.md`. Reverse: `R/scan.R`, `R/resolve.R`.
41. **1.4.13, a number that prints as zero (Robin, 2026-11-12; replaces
    entries 33 and 38).** Robin asked for pushback on the fallback.
    Alternatives: (a) one significant figure (entry 38): undoes 1.5.10,
    since no change is ever "unchanged", and mixes precision in one
    sentence; (b) a value error (entry 33): fails an unattended report on
    an ordinary small reading; (c) a bound, "< 0.1": awkward for negative
    numbers and inside "rose by"; (d) print "0.0" and record a warned
    check that `digits` or `sigfig` silences. Chosen with Robin: (d).
    Why: fixed decimals are the convention, the render still succeeds and
    the loss is reported. Contract: `dev/design-1i.md`. Reverse:
    `R/format.R`.
42. **Stage 2, thirty gaps in §4 and §7.** Each is in the table of
    `dev/design-2.md` §6 with its alternatives, the choice, the reason and
    how to reverse it (D1 to D30). The three with most reach: a year is an
    integer with an attribute, not a class (a class breaks `vctrs`); `dict`
    and `dict_local` are assigned into `knitr::knit_global()` at the start
    of a knit; an unknown field in a dictionary entry is an error while an
    unknown unit registers silently. Eight contradictions in the spec
    (K1 to K8, §10 of the note) are read as the note says and are to be
    amended in the spec with the package that meets them.
43. **4.2.1, how a year is held (reverses D8 of `dev/design-2.md`).** The
    review of 2a showed an attribute is lost by `c()`, `range()`, `seq()`
    and `year + 0:2`, so "2,014–2,024" printed. Alternatives: keep the
    attribute and document the loss; treat any whole number from 1000 to
    9999 as a year (wrong for counts); a class with the methods that keep
    it. Chosen: the class `weft_year`, with `vctrs` methods registered
    only when `vctrs` is loaded, which meets D8's objection. Reverse:
    `R/dict.R`.
44. **Stage 2a, the YAML that a dictionary may use.** A number with a
    leading zero or in hex or octal, a merge key, and a second YAML
    document are each a problem, never read silently. Alternative: read
    them as YAML 1.1 does (`010` is 8). Why: a committed file of
    constants must not hold a value its author cannot see. Reverse:
    `R/dict.R`.
45. **4.4.8, how a unit's exponent and product are written (replaces D23
    of `dev/design-2.md`).** The review of 2b showed Unicode superscripts
    and U+22C5 stop a pdflatex render and vanish silently under xelatex.
    Alternatives: keep Unicode and require a font; raw LaTeX for PDF only
    (two code paths); Pandoc markdown. Chosen: Pandoc superscripts
    (`m^2^`) and the middle dot U+00B7, as `.sci` already writes its
    power. Cost: a formatter's text for a quantity is markdown, not plain
    text, so a plot label needs its own unit. Reverse: `R/units.R`.
46. **4.4.4, `#` carries the unit; 4.4.14, the `unit` key (Robin, 12
    November 2026; reverses 4.4.4 and the first ruling on the review of
    2b).** `#` printed the unit on some routes and not on others. The
    first ruling made it never. Robin's ruling: always, because a unit
    typed in the arm goes wrong when the quantity changes unit. `#` is
    what the governor prints as a value under the span's classes. With
    it comes a way to choose the unit shown: `unit="m"` on a value or
    span and `unit =` on the number formatters convert first, so the
    number, the unit and the arm agree. Alternatives for the display
    unit: `units::set_units()` in the expression (long); a `display:`
    field per dictionary entry (not built; for Robin). Reverse:
    `R/resolve.R`, `R/format.R`.
47. **The minus sign in a PDF built with pdflatex.** U+2212, the default
    `minus` since stage 1, stops rmarkdown's default PDF build; no test
    rendered a negative number to PDF until the review of 2b. Chosen:
    in a knit to LaTeX weft declares the character for pdflatex.
    Alternatives and reasons are in `dev/design-2.md` (rulings on the
    fixer's report for the review of 2b). Reverse: one function in the
    knit setup.
48. **Package 2f, unit names and unit settings (Robin approved the plan,
    12 November 2026).** A spelled number takes the unit's name ("five
    metres", changing 4.4.2); names and plurals are printed by weft;
    `unit_form` and a `units:` table in `_weft.yml`; `display:` on a
    dictionary entry; no second pronoun; a year stays a class, not a
    unit (a calendar year is a point, and `year` in `units` is the
    duration). The details the plan left open are decided in
    `dev/design-2f.md` (U1 to U21) with alternatives and reasons; its
    questions Q1 to Q5 are built as recommended and are for Robin.
49. **Package 2c, dictionary tooling: contract in `dev/design-2c.md`.**
    Its decisions C1 to C38 each give alternatives, the choice and the
    reason. The ones with reach: the dictionary gains the optional
    fields `term` (the reader's name for an entry and the spelling to
    keep) and `avoid` (spellings to replace), which settles R2;
    `dict_vale()` writes a file and says so first; the glossary is a
    function that writes nothing; a decision pointer that could not be
    checked is "could not check", never "unresolved"; `curl` goes in
    Suggests for the GitHub route. Its questions Q1 to Q4 are built as
    recommended and are for Robin.
50. **Units the `units` package misreads (Robin, 12 November 2026;
    replaces the refusals of rule 4.4.20).** weft ships a default units
    table that redefines them (`pH`, `mph`, `Sv` and the like), and a
    project adds to it. A setting chooses between weft's defaults and
    the `units` package's own strict reading. Contract:
    `dev/design-2g.md`.
51. **Whether weft picks the unit to print in.** No: with no `unit` key
    and no `display:` a quantity prints in the unit it is held in.
    Alternative: scale to the "best" SI prefix. Rejected because the
    unit would change with the data from one day's report to the next
    and within a table, because the right unit is a convention of the
    field (rain in mm, a concentration in its limit's unit), because a
    compound unit has no single best scaling, and because the arm
    chosen follows the number as printed. Built instead: the zero
    rule's warning names a unit that would show the value. The ladder the author approves
    (`unit="mm|m|km"`) is decision 52, built as package 2h.
52. **Package 2h, the unit ladder (Robin approved, 12 November 2026;
    completes decision 51).** `unit="mm|m|km"`, a vector for `unit =`,
    or a list in `display:` names the units the author approves; weft
    prints in the first that gives a number from 1 up to 1,000 as
    printed, one unit for a whole vector. Contract and decisions L1 to
    L18 in `dev/design-2h.md`. The one with most reach: a ladder in
    `display:` is applied once, when the dictionary is read, so a value
    computed from the entry stays in the unit the entry's own value
    picked (an attribute carrying the ladder is lost by `c()`, `mean()`
    and subsetting). Its questions Q1 to Q4 are built as recommended
    and are for Robin.
53. **A ladder is not allowed in `display:` (reverses part of decision
    52).** The review of 2h measured the hazard: the unit an entry is
    held in followed its value, so editing 800 to 8000 changed
    `units::drop_units()` of the entry by a factor of 1,000 silently.
    Alternatives: keep it and document the hazard; carry the ladder on
    the quantity (lost by `c()`, `mean()`, subsetting). Chosen: one
    unit in `display:`, ladders in the `unit` key at the use. Reverse:
    `R/dict.R`; the tests are in git history at 80d3ff9.
54. **Which rung a number takes when it fits none (re-rules finding 6
    of the 2h review).** Built first: the rung whose printed number is
    nearest the window as a ratio; under `mm|km` that printed 149 m as
    "0.1 km" and 50 m as "0.1 km". Alternatives: measure the ratio
    before rounding (the reviewer's suggestion; it changes none of
    those cases and makes 32.5 m at two decimals "0.03 km"); refuse a
    rung whose printed number is off by more than some share (needs an
    arbitrary threshold). Chosen: a rung that prints 1,000 or more
    before any that prints below 1, since a long number keeps every
    digit and a short one loses them; then the smallest such number,
    or failing any the largest number below 1. Cost: 940 m under
    `mm|km` prints "940,000 mm", not "0.9 km". Reverse: `ladder_pick()`
    in `R/units.R`.
55. **Package 2d, the ledger and the condition log (Robin delegated the
    file formats, R5).** Contract D1 to D30 and choices G1 to G24, each
    with its alternatives, in `dev/design-2d.md`. Those with most
    reach: the files are JSON lines under `_weft/ledger/<source>/`, not
    the spec's `generated/ledger/` (Quarto ignores `_` folders; weft's
    committed files are already in `_weft/`); each entry stores its
    sentence as printed, so `changes()` needs no render, at the cost
    that rewording a sentence changes the line of every value in it;
    the key adds the file and takes its section from weft's own anchor
    of the source heading; arms are stored by role; `jsonlite` moves to
    Imports; `git` is called, when present, to report new conditions.
    Questions Q1 to Q5 are for Robin; built as recommended.
56. **Package 2e, the pipeline and `changes()`, split in two (2e-1,
    2e-2).** Contract and choices T1 to T32 in `dev/design-2e.md`. The
    one with most reach: in a pipeline `dict` comes from `tar_dict()`,
    which attaches it to the search path, and a global `dict` in
    `_targets.R` is an error. Measured: `targets` tracks a global and
    re-runs every reader, through functions too, when any definition
    changes; the earlier spike that seemed to show otherwise had
    dropped all automatic dependencies. Alternatives: the spec's global
    (re-runs too much); wrapping each command (kept as the way to
    support `crew` workers, which cannot see an attached `dict`).
    Others: dependencies are appended to the internal `t$deps`, pinned
    by a test; the ledger header records hashes of the targets,
    dictionary entries and source files a chapter reads; upstream
    conditions run `tar_network()` once per project render. Questions
    E1 to E5 are for Robin; built as chosen.
57. **Sentences are split by `stringi` (Robin asked for a package,
    12 November 2026).** The sentence stored in a ledger entry was cut
    by weft's own rule and an abbreviation list. Tried here (ICU 71.1):
    `stri_split_boundaries(type = "sentence")` with the locale keyword
    `@ss=standard`, which turns on ICU's abbreviation suppressions for
    the language, kept "Mr. Smith", "Jan. 2024", "et al.", "e.g." and
    the French "M. Dupont", "p. ex." whole. Alternatives: `tokenizers`
    (built on `stringi`, adds `Rcpp`, no suppressions); `corpus` (own
    lists, not tried); weft's list (ours to maintain, English only).
    Chosen: `stringi` in Imports, the document's `lang` as the locale,
    and one rule on top (no boundary before a lower-case letter or a
    digit). Cost: a hard dependency, and a machine with another ICU
    could cut a sentence elsewhere, which would change a ledger line
    but never what counts as changed. Reverse: `R/ledger.R`.
58. **A bare quantity warns (rule 4.4.10 kept, with a warning).** In
    the stage 2 trial the natural edit, deleting a typed unit and
    leaving the value bare, printed a number with no unit in six
    places and nothing said so. Alternatives: print the unit (changes
    what stock knitr prints for a bare value, against the rule that a
    bare value is knitr's); leave it. Chosen: keep the output, raise a
    `weft_unit_warning`; `{.nounit}` says the bare number is meant.
    For Robin: printing the unit may be the better end state.
59. **A unit typed again after its value warns.** "5 days days" came
    from four converted spans. Alternative: remove the repeated word
    (weft would be editing the author's prose). Chosen: a warning.
60. **A `units:` row with a name and no symbol has no symbol.** Count
    nouns ("site") otherwise print the key after digits and never
    take a plural. Alternative: keep the key as the default symbol.
61. **`ledger: false`** separates the ledger from the existence of
    `_weft.yml`.

## 62. The disk copy of the units tables is off unless asked for

The performance work keeps what `units::valid_udunits()` returns for
the session, and can keep it in the user's cache directory
(`tools::R_user_dir("weft", "cache")`) for the next one. The disk copy
is written only under `options(weft.units_cache = TRUE)`.

- First `weft_setup()` in a session, installed package: 1.08 s before,
  about 0.6 s with the session copy alone, 0.15 s with the disk copy.
  Later calls: 0.12 s before, 0.04 s after.
- Alternative: write the disk copy by default. Refused for now: a
  package that writes outside the project without being asked is a
  choice for Robin, and the build was told to write only inside this
  repository. Turning it on by default is a one-line change.

## 63. The items that waited on Robin, decided under delegation (13 Nov)

Robin delegated these and asked for the alternatives and the reasons.

- **Units cache on disk: on by default** (reverses the default of 62).
  `options(weft.units_cache = FALSE)` turns it off. For: 0.45 s saved at
  the start of every fresh session, which is every run of an unattended
  report; the folder is R's own user cache folder; a bad or stale copy
  falls back to a read. Against: a package writing outside the project
  unasked. Alternative: keep it opt-in; refused, since nobody sets an
  option they have not heard of. Alternative: ship the tables in the
  package; refused, since they belong to the installed `units`. Reverse:
  the default in `ud_tables()` in `R/unit-names.R`.
- **`ledger: false` stops the upstream-conditions check too.** Kept.
  Alternative: still fail a render on an upstream error; refused, since
  it needs the background process the author turned off.
- **A bare quantity warns** (58), an inline `claim()` on one included.
  Kept.
- **The repeated-unit warning skips `a`, `am`, `as`, `at`, `in`.** Kept.
- **A second `tar_dict()` is found through a frame of `targets`.** Kept:
  if the frame moves, `targets` still stops the make with its own error.
- **`dict_unmark()` is exported**, marked internal, because generated
  target commands call it by name. Alternative: put the function itself
  in each command; refused, since it bloats every command and its hash.
- **The `units:::` calls stay.** There is no exported route.
- **A compound prints as typed, names included** (`kilometre/hr` prints
  so). Alternative: turn names into symbols inside a compound; refused,
  since `mm/day` is ruled to print as typed and `day` is a name, so the
  rule would need a list of exceptions.
- **Units a dictionary registers are removed with the project**, as
  closing review 12 did for rows of `units:`.
- **Decisions 53 to 61 stand.**

## 64. Stage 3 is built to `dev/design-3.md` (13 Nov)

The designer's choices K1 to K19 and the five marked for Robin are
adopted under delegation; each is set out in the note with its
alternative and how to reverse it. In one line each:

- **R1** prose is read by the package's own reader; Pandoc only under
  `reader = "pandoc"` and in parity tests (departs from 2.10.3; keeps a
  chapter under half a second and the answer the same on every machine).
- **R2** the entry point is `lints()`, not `lint()` (which would mask
  `lintr::lint`); rule ids and `_weft.yml` keys as the note lists them.
- **R3** target names come from the store's metadata, so no `_targets.R`
  is run.
- **R4** no inline ignore comment: `.weft-literal` with its `why` is the
  only exemption in the source.
- **R5** tier 1 is wider than the spec in three places (`p<0.05` and
  `n=12` are typed numbers; `{n="3"}` is a literal value; a constant
  two-arm `if` cannot fail).

## 65. Stage 4 is built to `dev/design-4.md` (13 Nov)

The designer's choices H1 to H30 and the six marked for Robin are
adopted under delegation; the note gives each alternative and how to
reverse it.

- **F1** the commit hook fails the commit when R or weft cannot be
  found, and says how to bypass. A gate that passes when it cannot run
  is no gate. Alternative: pass with a warning.
- **F2** names: `gate()`; keys `strict`, `verify_skip`, `weft_version`;
  the trailer `Weft-Removed`.
- **F3** `use_ci()` writes at the top of the repository even when the
  project is a subfolder (GitHub reads workflows nowhere else), and
  installs weft from its GitHub repository until it is on CRAN.
- **F4** agent conventions go in an `AGENTS.md` block and a Claude
  skill. Alternative: `CLAUDE.md`.
- **F5** a new project `.Rprofile` sources `~/.Rprofile`, since R reads
  only one of the two.
- **F6** the first commit of a repository is the baseline: its findings
  are not compared with anything.

## 66. The default claim-word list is trimmed to 69 words (13 Nov)

Stage 0 ran the lints over a real manuscript as it stood before an
audit (46 files, 5,508 sentences). With the list of design-3 L8a (119
words) `claim-word` flagged 66% of all sentences, and every rule
together 75%, so a flag carried almost no information: all rules
reproduced 59% of the audit's quoted findings, little above what
flagging at random would. The words doing it were number words (`one`
alone was 21% of the flags, `two` 14%), loose quantifiers (`any`,
`many`, `several`, `few`, `single`), the bare comparatives (`more`,
`less`, `above`, `below`) and `record`, `top`, `last`.

- **Chosen: 69 words.** The absolute quantifiers, eleven extremum words
  and the direction words without the bare comparatives. It flags 42%
  of sentences, reproduces 11 of the 16 audit findings the rule could
  locate (the full list: 12), and of 20 sampled sentences flagged only
  by a direction word, 14 were statements about data that a check
  could back.
- Alternative: the same without the direction words (30 words, 37% of
  sentences, 10 of 16). Refused: wording that says which way a number
  moved is what `claim()` exists for, and it costs five points.
- Alternative: drop only the number words (53%, 11 of 16). Refused:
  still more than half of all sentences.
- Alternative: keep the full list and lean on `claim_cap`. Refused:
  the cap hides the excess, it does not make a flag mean more.
- Alternative: make `claim-word` fire only next to a number. Not
  tried; it would be a new rule and needs its own measurement.

The rule is tier 2 and only lists sentences a change touched, so the
share matters less than at tier 1, but a list that flags most prose
teaches an author to ignore it. A project restores any word through
its own claim-word setting. The evidence is thin (16 located
findings, one manuscript); undo by restoring the list in
`inst/weft-claim-words.yml` from commit 5940aeb.

## 67. The stage 3 and stage 4 reviews changed the designs (13 Nov)

Each review (`dev/review-3.md`, `dev/review-4.md`) ended in rulings under
delegation. Most findings were fixed as the reviewer directed; these
design questions were decided otherwise than the design had it. The
spec's chapter 5 and the notes of 2.10 carry the stage 3 ones.

Stage 3:

- **`block-start` is narrowed to what Pandoc's `markdown` reader cuts a
  paragraph at**: a closed backtick fence, a lone line of `-` or `=`, a
  definition line. Alternative: CommonMark's list (`#`, `>`, list
  markers, `:::`, `~~~`); refused, since a check with Pandoc as Quarto
  ships it showed those keep a span whole, so the rule flagged spans
  that render correctly.
- **A rule named in `rules` runs whatever its tier** when `tier` is not
  given, with a note when `tier` is given and excludes it. Alternative:
  filter by the default tier and say nothing; refused, since "no
  findings" then reads as "the rule passed".
- **Anchors are read from documents in `_` folders** (not `_site`,
  `_book`, `_freeze`, `_extensions`), and those files are not linted.
  Alternative: keep skipping them; refused, since Quarto's include
  convention put `{#sec-x}` there and every reference to it was a
  tier-1 `xref`.
- **Ruling 12 as revised:** a Pandoc highlighting-language class on a
  code span is never a `name` finding; any other class one edit from a
  weft class is still flagged on a code span. Alternative (the first
  ruling): flag only a name on a span with a governor or key; refused,
  since a mistyped `.num` on an inline value would pass, and six design
  tests pin it.

Stage 4:

- **Q1, G12: claims are counted apart from values and spans** (positive
  part of removed less added for each). Alternative: one net count;
  refused, since a deleted `claim()` hid behind an added value.
- **Q3, G25 step 1: the manifest records the run id**, and a backup
  from a killed run is restored unless a later complete render made the
  entry. Alternatives: restore always (the build), which replaces fresh
  entries with stale ones; and decide by file times, refused since the
  killed run's half-written files are newer than its manifest.
- **Q5, G23: when `_weft.yml` is absent at `since`, nothing counts as
  added**, and the report says so (as F6 does for the gate). Alternative:
  count every tolerated finding as added; refused, since a new project
  in an old repository then failed `verify()`.
- **Q7, G18: when `_weft.yml` does not read at HEAD only the findings
  comparison is skipped**; the removal count still runs. Alternative:
  skip both (the build); refused, since a commit could then remove
  constructs with no trailer.

To undo: each is a reading in code and tests, set out with its ruling in
the review's "Rulings" section; reverse by restoring the design's
original sentence in `dev/design-3.md` or `dev/design-4.md` and the test
that pins the ruling.

## 68. Python and Julia chunks are designed as guests of knitr (13 Nov)

Robin chose architecture (a) of `dev/languages-study.md`: weft stays an
R package on knitr, and Python and Julia chunks in an `.Rmd` or a
knitr-engine `.qmd` become documented, tested and safe guests. The
choices inside it were delegated. `dev/design-5.md` is the contract
(G1 to G43, J1 to J5) and gives each choice (V1 to V20) with its
alternatives; open questions O1 to O10 carry a recommended answer.

What was measured first (reticulate 1.43.0, Python 3.15.0; numpy 2.5.4
and pandas 3.1.1 only in a temporary environment):

- The wrong integers arise inside reticulate's C++ conversion, before any
  R code or S3 method sees the value: `2**53 + 1` arrives as `1L`,
  `2**53` as `0L`, `2**70` as `-1L` with a Python error left pending.
  numpy's `int64(2**53 + 1)` arrives one short. weft cannot tell such a
  value from a right one afterwards, so it must read the unconverted
  object.
- Python calling `r.fmt_num(2**53 + 1)` hands R the same wrong `1`.
- reticulate 1.43.0 does not convert pandas 3.1.1 objects at all.
- R weft itself printed `fmt_num(999999999999999)` as
  "1,000,000,000,000,000" and `fmt_num(2^53)` as
  "9,007,199,254,740,990", through base R's `signif()` in
  `round_half_away()`. Fixed first, in package 5a.

Chosen, in one line each:

- **V1** every `py$...` in an expression weft evaluates is read by weft's
  own typed reader, not by reticulate's conversion; `py_value()` is the
  route in R chunk code. Alternatives: a check after conversion
  (impossible), an S3 method (never called), a weft `py` object in the
  knit's environment (changes R chunk code), an accessor only (leaves the
  usual spelling wrong).
- **V2, V3** integers beyond ±2^53, and decimals of more than 15
  significant digits, are refused, never rounded.
- **V4** a guest value of the wrong kind given to `if`, `n`, `sign` or
  `list` is a value error when the governor is exactly that read; R's own
  length-zero vector stays "no value" (1.3.4 unchanged).
- **V7** bare values are guarded too.
- **V8** `weft_setup()` loads no Python; prose needs no `py` object.
- **V9** function forms from Python are a module, `from weft import
  fmt_num`, whose arguments are read by the typed rules;
  `r.fmt_num()` is a tier-1 lint finding.
- **V10, V11** Python warnings and `error: true` errors reach the
  condition log; project Python modules reach the ledger's reads.
- **V15** Julia: the static parts are built; reading Julia values is
  designed and not built until a machine has Julia.
- **V16** an Observable JS lint (tier 2) is in, as the last package.

To undo: each V row of `dev/design-5.md` §3 names the place to change.

## 69. The spec is brought up to decision 68 (13 Nov)

`dev/PACKAGE-SCOPING.md` now says what stage 5 built. It gains section
1.11 (typed values), section 2.12 (guest languages under knitr, Julia
in 2.12.15 to 2.12.21) and the lint table 5.11 (`guest-inline`,
`guest-call`, `guest-read`, `ojs-value`), taken from section 6 of
`dev/design-5.md` as corrected by its rulings and "as built" notes:
digits after the fifteenth print as zeros (1.4.13); `NaN` and `Inf`
are missing for Julia; a refusal on one element of a Python list says
"Element N of ...", while M1, M2 and every Julia element refusal name
the read with no index; weft sets `RETICULATE_USE_MANAGED_VENV=no` for
its own start of Python only when the variable is unset (2.12.14);
`py_value()` with a non-literal argument reads the name it evaluates
to. Amended: 1.1.2, 1.1.8, 1.3.4, 1.4.13, 2.8.1, 3.2.4 and 3.6.4 (new),
5.1.1, 5.1.4, the notes of 5.8 rule 9 (the `engine` message by case,
with the Julia hints), 7.2.2, 7.4.1 (a fifth source), 9.2.8, 9.3.1 and
9.3.5 (`use_setup()` on a Python-only `.qmd` with a construct), §16,
§19, §21 and §22 (stage 5). Two items from the documentation and the
first code review are folded in too: the settings `date_format`,
`ci_level`, `about_tolerance` and `sentence_start_fail` join the key
list of 9.1.5, and 9.4.4 states the draft rule (`draft:` takes `true`
or `false`; `WEFT_DRAFT` takes `true` or `1`, and `false`). To
reverse: the spec text only; no code changed.
