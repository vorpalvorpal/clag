# Review of stages 1f, 1g (empty-arm spacing), 1h, 1i

Snapshot `snap-f` (aaa8d80). Every case below was run against it: `weft_str()`
and function calls with the package installed in a private library, `.Rmd`
through `rmarkdown::render(md_document)`, `.qmd` through `quarto render` in a
project set up by `use_quarto()`. Line numbers in reports are those of the test
file. Code references are to the snapshot.

## Findings

**1. `.range` with no number class prints a small range as "0.0" and records nothing.**
Severity: silent. Stage 1i.
`x <- c(0.01, 0.04)`; `weft_str("`r x`{.range}")` → `"0.0"`, no warning.
Same in a knit: `A2 `r c(0.01, 0.04)`{.range}.` prints "A2 0.0." with no row in
`last_knit()$warnings`. `fmt_range(c(0.01, 0.04))` → `"0.0"`, no warning. Controls:
`{.and}` on the same vector warns ("0.01 printed as 0.0 (2 values printed as
zero)"); `{.num .range}` warns.
Expected: one warned check (1i "Where": the default class of a value; 2.6.11).
Cause: `format.R:579` sets `keys$digits <- cfg$digits` for `.range` (1.4.4), so the
project default counts as given, which 1i and 1.4.13 forbid.

**2. A number re-formatted by a class prints "0.0" silently when the first formatter was given `digits`.**
Severity: silent. Stage 1i.
`weft_str("`r fmt_num(0.04, digits = 2)`{.num}")` → `"0.0"`, no warning; in a
knit (`A4 ...`) "A4 0.0." with no warned row. Also `fmt_num(fmt_num(0.04, digits = 2))`
→ `"0.0"`, no warning.
Expected: the `.num` on the construct has no `digits`/`sigfig`, so the loss is
warned (1i "Warning", "Silencing": digits on *the* construct or call).
Cause: `format.R:563` drops `zero` for any `weft_text` input on the assumption
the first formatter already warned; it did not, because it was given `digits`.

**3. A `list` span with `.ul`/`.ol`/`.dl` prints a block list inside the sentence.**
Severity: wrong output. Stage 1h.
`v3 <- c("a","b","c")`; prose `Sites: [none | # | #]{.ul list="v3"} end.`
→ rendered "Sites: - a - b - c end." with no error and no marker
(`weft_str()` gives `"\n- a\n- b\n- c\n"`). The same class on a value in a
paragraph is a construct error (1.4.6).
Expected: a construct error (1h lists `.or`, `.pairs`, `trunc`, `sep`, `last` as
what acts on `#`; 1.5.19 likewise; a block class has no inline form).

**4. A `clamp()` bound under `.range` makes a valid range a value error.**
Severity: crash (collected value error; the render fails). Stage 1i (bound ruling).
Prose `R `r clamp(c(0.001, 0.02), floor = 0.01)`{.num .range}.` → render fails:
"`.range` needs its first end not above its second; got < 0.01 and 0.0."
The bound prints as written ("< 0.01", number 0.01) while 0.02 prints "0.0"
(number 0), so the order check fails. Control: with `digits="2"` →
"< 0.01–0.02". Related, same cause: `fmt_num(clamp(c(0.001, 0.5, 0.03), floor = 0.01))`
→ `"< 0.01" "0.5" "0.0"` (one warning): an element known to be at least the floor
prints below it.
Expected: no error; 1i's bound ruling did not consider a bound printed beside
an element that prints as zero.

**5. `ci()` and `pm()` print estimates and bounds as "0.0" with nothing recorded.**
Severity: silent (the contracts are silent on phrase functions). Stage 1i.
`ci(0.01, 0.002, 0.03)` → `"0.0 (95% CI 0.0 to 0.0)"`; `pm(0.01, 0.002)` →
`"0.0 ± 0.0"`; `pm(1234.5, 0.04)` → `"1,234.5 ± 0.0"`. No warning outside a knit,
no warned row in a knit (prose `A5 `r ci(0.01, 0.002, 0.03)`.`). Both take
`digits`/`sigfig` (`phrases.R:151,176`), so the 1i silencing rule would apply
as it does to `fmt_num()`. 1i's stated aim is that "the loss must not be silent".

**6. The warnings report is lost whenever the knit stops, not only on a failing chunk claim.**
Severity: silent. Stage 1f (2.6.10). Wider than the open finding.
Body `W `r claim(3, . > 5, level = 'warn')` and `r 0.04`{.num}.` followed by a
chunk `stop('plain error')`: the render error is "plain error" and nothing
"weft: N warned check(s)" reaches stderr, though `last_knit()$warnings` has 2 rows.
Same with a bare value `` `r stop('bare')` ``. The open finding names only a
failing `claim()` in chunk code. 2.6.10: "whether or not the render also fails".
Also confirmed (already open): a chunk served from cache drops its warned rows;
this now includes 1i's "printed as zero" rows (run 1: 3 warned; run 2: 0).

**7. The function forms do not check `none`.**
Severity: wrong output (silent). Stage 1h.
`fmt_and(character(0), none = "")` → `""`; `none = NA` → `NA_character_`
(prints "NA"); `none = c("a","b")` → a 2-element result; `none = 5` → `"5"`.
The key refuses `none=""` and spaces (construct error). 3.4.5: "take
`none = NULL`, as the key does (1.4.14)".

**8. The pre-render script does not see a `list` span, so a `.qmd` without `engine: knitr` gets past it.**
Severity: contract/spec mismatch (caught later by the filter, as a failure). Stage 1h.
Project set up with `use_quarto()`; `b.qmd` with no `engine:` and only
`[No sites were | # was | # were]{list="flagged"} flagged.` → pre-render passes,
Quarto renders it unexecuted, the filter reports "leftover span ... key `list`".
With `n="flagged"` instead, pre-render stops: "holds a weft construct ... and has
no `engine: knitr`". Cause: `inst/quarto/weft-pre-render.R:118` key pattern is
`(n|if|sign|cite)`; the same pattern in `weft-post-render.R:116` (`has_construct`,
the "never checked on this machine" freeze notice) also misses `list`.
Rules 2.5.4, 9.2.8.

**9. Rule 2.6.11 says the zero rule "does not apply to `.no`"; the 1i ruling and the code record it.**
Severity: spec mismatch. Stage 1i.
`fmt_no(0.04)` → `"no"` with a `weft_zero_warning`; prose `` `r 0.04`{.no} `` →
"no" and a warned row. The 1i ruling ("the warned check is still recorded")
agrees with the code; 2.6.11 kept the 1f ruling's wording.

**10. Rule 2.6.11 and 1i say "not `#` in a span"; `#` of a `list` span records a warned check.**
Severity: spec/contract mismatch. Stages 1h/1i.
Prose `A7 [none | # | #]{.num list="c(0.04, 1.2)"}.` → "A7 0.0 and 1.2." and a
warned row (`format`ted through `apply_formatters(..., on_zero = zero_note)`).
The behaviour is arguably right (the list's elements are values, not a governor),
but the spec and 1i say otherwise; see question J.

**11. `.range` with `none` is accepted.**
Severity: contract mismatch (cosmetic). Stage 1h.
`weft_str("`r character(0)`{.range none=\"x\"}")` → `"x"`. 1h and 1.4.14 list the
collapse classes as `.and .or .pairs .ul .ol .dl`, and the construct-error
message says the same; `COLLAPSE_CLASSES` (`format.R:9`) includes `.range`.

**12. The post-render report does not tag "printed as zero"; the knit's report does.**
Severity: cosmetic. Stage 1i.
Knit: `doc.Rmd:9  [printed as zero] `r 0.04``. Quarto project post-render:
`a.qmd:13  `r 0.04`` (no tag), so it reads as a failed claim on `` `r 0.04` ``.
The 1i ruling accepted the tag for the report.

**13. The record of a check inside a `list` span is labelled by the zero arm.**
Severity: cosmetic. Stage 1h.
Prose `[No sites were | # was | # were]{list="claim(v3, length(.) > 5, level = 'warn')"} flagged.`
prints "a, b and c were flagged." and the report row is
`doc.Rmd:14  "No sites were"`. A zero warning in `[none | # | #]{.num list=...}`
is labelled `"none"`. The label is the first arm (as for `n`), which for `list`
is the text that was *not* printed.

**14. `last_knit()`'s help says `warnings` holds only `claim(level = "warn")` checks.**
Severity: cosmetic (doc). Stage 1i.
`man/last_knit.Rd:18`; it also holds kind "printed as zero" rows.

**15. A positional `level` is read as a check and fails with a misleading message.**
Severity: cosmetic. Stage 1f.
`claim(5, . > 10, "warn")` → error `weft_claim_failed`: "check `\"warn\"` failed
(value: 5)"; nothing says `level` must be named (3.1.11). A `lev = "warn"` does
the same.

**16. Message wording differs from the spec's example.**
Severity: cosmetic. Stage 1i.
Code: "0.04 printed as 0.0: add sigfig to show it, or digits to confirm it".
1i and 2.6.11: "... or digits to confirm".

## Questions

A. `#` inside an `if` arm nested in an `n` or `list` span prints a literal "#":
`[none | # | [x #]{if="TRUE"}]{list="v3"}` → "x #"; the same with `n="3"`.
Should it inherit, or be a construct error?

B. Empty arm followed by a character not in the list: `fell [sharply | ]{if="f"}—then`
→ "fell —then"; `"fell [sharply | ]{if="f"}" he said` → `"fell " he said`;
`a [x | ]{if="f"}'s` → "a 's"; before `]`, a footnote ref, or a link's closing
bracket (`[fell [sharply | ]{if="f"}](u)` → "[fell ](u)"). "Otherwise nothing is
removed" covers these; is that intended for closing quotes, `]` and dashes?

C. Freeze: the stamp carries failures but not warned checks, so on a re-render
from freeze a document's warned checks vanish (render 1: "weft: 3 warned
check(s)"; render 2: only the freeze notice). Re-report them from the stamp?

D. A `level` key on an `n`, `sign` or `list` span passes through silently
(`[none | # | #]{list="v3" level="warn"}` → `[a, b and c]{level="warn"}` in the
markdown, no message). The ruling covers only `if`.

E. `.no` on a governor that prints "0.0": `[# unit | # units]{n="0.04" .no}` →
"0.0 units", while `` `r 0.04`{.no} `` → "no". Intended?

F. `serial_comma` with a `sep` key: `{.and sep="; "}` → "a; b, and c". Should the
serial mark follow `sep` ("a; b; and c")?

G. `thousands_from` is judged on the number as printed: 999.96 → "1,000.0".
1.4.16 says "absolute value". Confirm printed.

H. `serial_comma: null` in front matter is accepted (default kept) while
`serial_comma: 1` is an error; same for other settings?

I. A matrix is accepted as a `list` governor (`matrix(1:4, 2)` → "1, 2, 3 and 4").
Intended, or should a value with `dim` be refused like a data frame?

J. Should `#` of a `list` span record a zero warning (finding 10)? If yes, 1i,
2.6.11 and 1.5.19 need the exception; if no, the code must pass a no-op `on_zero`.

K. Should the zero rule reach `ci()`, `pm()` and `fmt_range()` (findings 1, 5)?

Probed and sound: `level` validation (vector, NA, case, a check named `level`,
several checks with mixed results, an erroring check), warned checks in prose,
front matter, captions, `weft_str()` in chunks, chunk code, loops, child
documents (positions file:line correct), alongside failures, draft JSON with
`"level":"warn"`, collection file and post-render order and exit status 0,
`rehearse()` `warnings` and `ok`, `last_knit()` NULL before a knit; zero rule at
0.05/0.049999/−0.05/0.95, vectors, `.pct`, noise below 1e-9, `digits`/`sigfig`,
project `digits: 0` and `3`, `.sci`, `.no`, `sign` zero arm, chunk tables (one
warning per call, located by chunk); `thousands_from` boundary, negatives,
`.pct`, `.ord`, `.range`, `.pairs`, bad values; `serial_comma` with 2/3 items,
`trunc`, `.or`, `.pairs`, `last`; `.p` at every boundary listed, vectors, `.cap`;
empty-arm spacing in emphasis, lists, headings, quotes, footnotes, table cells,
nested arms, two and three in a row, document start/end, line breaks, nbsp, tab,
later failure positions; `list` arm roles, empty/NULL/list/data frame/NA/factor
with unused levels/Date/logical/named/number classes/`trunc`/`sep`/`last`/text
classes/`##`/inner `n="."`/`claim()`/construct errors, Quarto filter on an
unresolved `list`, `arms()`/`rehearse()` with two `list` spans on one line;
`none` with each collapse class, `.cap`, `trunc`, markdown, `NULL`, all-`NA`,
the scanner's errors.
