# Stages 1b and 1d — internal contract

One build stage covering §22's 1b (agreement and direction) and 1d (phrases
and lists): they touch the same files and the trials wanted pieces of both.
`dev/design-1a.md` and `dev/design-1c.md` still hold. Where this note and a
numbered rule disagree, the rule wins and the disagreement is reported.

After this stage no weft name gives a "not built yet" error.

## Scope and the rules for each

| Piece | Rules |
|---|---|
| `sign` spans, `#` as the magnitude | 1.5.1, 1.5.3, 1.5.8, 1.5.10, 1.5.17, 1.7.2 |
| ids and back-references | 1.2.8, 1.7.5–1.7.12, 1.5.16, 5.3.1 (duplicate, unknown, later) |
| `.p`, `clamp()`, the relation | 1.4.3, 1.4.11, 1.5.9, 3.5.1, 3.5.4 |
| `.range`, alone and as an `n` governor | 1.4.4, 1.5.11, 5.3.2 |
| `.cap`, `.a` | 1.4.1 stage iv, 1.4.5, 5.3.2 |
| the sentence-start report | 5.10.1 |
| `lookup()`, `brk()` | 3.3 |
| `cite` spans, the knit-time bibliography check | 1.8.1–1.8.8, 5.4.1, 5.4.4–5.4.6, 2.1.6 |
| `.weft-literal` | 1.1.6, 1.8.9–1.8.11 |
| `of_n()`, `about()`, `ci()`, `pm()` | 3.5 |
| `.pairs`, `trunc`, `.date` | 1.4.3, 1.4.7, 1.3 examples |
| `.ul`, `.ol`, `.dl` | 1.4.3, 1.4.6 |
| language errors for the new word-printing names | 1.6.8 |

Function forms (3.4.1): `fmt_p()`, `fmt_range()`, `fmt_cap()`, `fmt_a()`,
`fmt_pairs()`, `fmt_date()`, `fmt_ul()`, `fmt_ol()`, `fmt_dl()`; `fmt_and()`
and `fmt_or()` gain `trunc = NULL`. Exported too: `lookup()`, `brk()`,
`clamp()`, `of_n()`, `about()`, `ci()`, `pm()`.

## What the spec leaves open, decided here (each is in dev/decisions.md)

- **`.p`.** `p < 0.001` below 0.001; three decimals below 0.01 ("p = 0.004");
  two decimals from 0.01 ("p = 0.03", "p = 0.20"); "p > 0.99" above 0.99. A
  value outside 0 to 1 is a value error. The record's number is the number
  printed and its relation `<`, `=` or `>`. `digits`/`sigfig` are a construct
  error with `.p`.
- **`.range`.** An en dash with no spaces ("3–5"); " to " when either end is
  negative; each end printed by the number stage (or `.num` by default). As
  an `n` governor the plural arm is taken unless both ends print "1".
- **`.a`.** By the sound of the printed text's first word. "an" before a
  number whose spoken form opens with a vowel sound: 8, 11, 18, 80–89,
  800–899, 8,000 …, 11,000, 18,000 (digits or words: "an eight", "an
  eleven", "an eighteen", "an eighty"); "a" otherwise ("a one", "a 1", "a
  12"). The article is lower case; `.cap` then capitalises it.
- **`.cap`** capitalises the first letter of the final text, skipping
  leading markdown emphasis marks.
- **`.date`.** Config key `date_format`, default `"%-d %B %Y"` ("3 June
  2024"), applied with `format()`; the value must be a `Date` or `POSIXt`,
  anything else a value error.
- **`.pairs`.** A named vector prints "A (1.2), B (3.4) and C (5.6)": names
  as they are, values by the number stage, joined as `.and` joins. An
  unnamed vector is a value error.
- **`trunc="k"`.** With more than `k` items: the first `k`, then "and N
  others" ("and 1 other"), under `.and`, `.or` and `.pairs` ("a, b, c and 4
  others"). `trunc` implies `.and` when no collapse class is given.
- **Lists.** `.ul` prints `- item` lines, `.ol` prints `1. item` lines,
  `.dl` prints a Pandoc definition list from a named vector (`name` then
  `:   value`), each as a block with a blank line before and after. Alone
  in its paragraph or a construct error (1.4.6).
- **`about(x, to = 1/2, tolerance = <config about_tolerance, default 0.05>)`.**
  `to` is one of 1/4 ("a quarter"), 1/3 ("a third"), 1/2 ("half"), 2/3
  ("two-thirds"), 3/4 ("three-quarters"); another `to` is an error. `x` and
  `to` are compared as percentages rounded to whole numbers: equal prints
  the phrase, below prints "nearly …", above prints "just over …". An `x`
  further than `tolerance` from `to` is a value error (the sentence would
  be false).
- **`of_n(k, n, singular, plural)`.** "none of the 4 sites" (k = 0); "the
  only site" (k = n = 1); "both sites" (k = n = 2); "all 5 sites" (k = n >
  2); otherwise "3 of the 7 sites". `n = 0`, `k > n`, or a value that is not
  a whole non-negative number is a value error. The result is a `weft_text`
  whose number is `k` (3.5.2).
- **`ci(est, lo, hi, level = <config ci_level, default 0.95>, digits =
  NULL, sigfig = NULL)`** prints "2.1 (95% CI 1.3 to 2.9)"; **`pm(est, se,
  digits = NULL, sigfig = NULL)`** prints "2.1 ± 0.3". Numbers print as
  `.num` prints them. The record's number is `est`.
- **`clamp(x, floor = NULL, ceiling = NULL)`** returns a `weft_text`: the
  value as `.num` prints it when inside the bounds, "< floor" or "> ceiling"
  outside, with the relation set. A following formatter class keeps the
  relation.
- **`lookup(map)`** takes a named character vector and returns a function of
  one argument; **`brk(...)`** takes formulas whose left side uses `.` and
  whose right side is a string, tried in order. Both vectorise over their
  argument, and raise `weft_no_value` on `NA` (3.3.5). An unknown key, or a
  value no formula takes, is an error of class `weft_value_error`.
- **Sentence starts.** `last_knit()$sentence_starts`: a data frame (`file`,
  `line`, `expr`, `text`) of each value and span whose printed text opens a
  sentence (start of a block, or after `. `, `? `, `! `) with a digit or a
  lower-case letter. Config key `sentence_start_fail`, default `false`; when
  `true` each is a collected failure of kind "sentence start".
- **`cite`.** Bibliography files: `bibliography:` and `references:` in the
  front matter, the project's from Quarto's metadata (2.1.6), and config key
  `bibliography` (a vector of paths relative to the project root). Keys are
  read in R from `.bib` (BibTeX and BibLaTeX), `.json` and `.yaml`/`.yml`
  (CSL), 5.4.5. A key that does not resolve is a collected failure of kind
  "unknown citation key" with the marker `<<weft: unknown key, line N>>`
  after the span's text. With no bibliography at all, every key fails.
- **Ids.** `last_knit()$constructs` gains `id`. A back-reference
  (`n="#d"`, `sign="#d"`) has `expr` `"#d"`.

## Scanner

`scan_text()` kinds gain `"sign"`, `"cite"` and `"literal"` (a
`.weft-literal` span; a `.weft-literal` div is a row with kind `"literal"`
whose range is its opening fence line). The construct errors of 5.3.1 for
these pieces are found from the source: an id on a text span or `cite`
span; a duplicate id; a back-reference to an id that is unknown, defined
later, or defined in a different arm (1.7.11); `sign="."`; `n="."` outside
an `n` or `sign` span; a wrong arm count for `sign`; a bare-form `cite` that
is not keys only; a key outside Pandoc's grammar; a formatter class on a
`cite` span; `.weft-literal` with no `why`; a list class on a value that is
not alone in its paragraph; a word-printing name under a `lang` that is not
English (1.6.8).

## Tests

New files only: `test-sign.R`, `test-ids.R`, `test-number-forms.R` (`.p`,
`clamp()`, `.range`, `.date`), `test-text-classes.R` (`.cap`, `.a`,
sentence starts), `test-lookup.R`, `test-cite.R`, `test-literal.R`,
`test-phrases.R`, `test-collapse.R` (`.pairs`, `trunc`, lists). Function
forms are tested directly; markup through the fixture table style of
`test-syntax-fixtures.R` under both engines, batched.
