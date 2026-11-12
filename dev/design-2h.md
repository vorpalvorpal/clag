# Package 2h — the unit ladder (Robin, 12 November 2026)

Written before any test or code. Robin approved the plan: weft never picks a
display unit by itself (decision 51), but the author may give a **ladder** of
units they approve, and weft picks from it by the value: `unit="mm|m|km"` on a
value or a governed span, the same in the argument `unit =` of the formatter
functions and in the dictionary field `display:`. weft picks the first unit
that gives a number from 1 up to, not including, 1,000, and one unit for a
whole vector. This note decides the rest. It builds on `dev/design-2f.md` and
`dev/design-2g.md` with their rulings and on `dev/design-1i.md`.
`PACKAGE-SCOPING.md` is amended in the commit that builds it. `␣` is U+00A0,
`−` U+2212. Every claim about `units` and Pandoc was run (`units` 1.0.0,
Pandoc 3.8.3).

## Scope and rules touched

| Rules | Change |
|---|---|
| 4.4.14, 1.4.7, 3.4.4, 3.4.9 | `unit` takes a ladder; the functions' `unit =` too; `fmt_unit()` |
| 4.2.7, 4.2.1 | `display:` takes a ladder, applied when the dictionary is read |
| 4.4.9, 4.4.13, 2.6.11, 4.4.15 | arms, the zero rule's advice, the order of the unit shown |
| 1.2.3, 1.5.13, 5.3.1, 5.3.2 | `\|` in a `unit` value; pipe-table cells; the errors |
| 3.7.5 | `last_knit()$constructs` gains `unit_picked` |
| new | 4.4.23, the ladder |

Out of scope: a ladder that weft makes up (decision 51 stands); a ladder that
travels with a computed value; a ladder per column of a table (a column is a
vector and takes one rung by the vector rule). A ladder is accepted wherever
`unit` is today (`fmt_pct()` included) and changes nothing else there.

## The contract

### Writing a ladder

- **A ladder is one string of rungs separated by `|`**: `unit="mm|m|km"`. White
  space around a rung is trimmed (`"mm | m | km"` is the same); white space
  inside a rung is kept (`"CFU/100 mL|CFU/L"`). Each rung is read as `u()` reads
  a unit, under the `unit_defaults` mode and `units:` rows in force. A ladder of
  one rung is today's `unit="m"`, unchanged in every respect.
- **Where a language has lists**, the ladder may be one: a YAML sequence in
  `display:` (`display: [mm, m, km]`), a character vector for a function's
  `unit =` (`unit = c("mm", "m", "km")`). Each item is one rung and holds no
  `|`. A one-item list is the rung (as `unit: [m]` is read today).
- **In a pipe-table cell** the separator is written `\|`, as the arm separator
  is (1.5.13): `` `r x`{unit="mm\|m\|km"} ``. Pandoc's reader, and so the
  visual editor, splits a row at an unescaped `|` in a span's attribute block
  (a value's block survives; one rule covers both), and reads `\|` there as
  `|` (both run). weft's scanner reads `\|` as `|` in `unit` only, in a table
  or not; an unescaped `|` in `unit` in a pipe-table cell is a construct
  error. A `\` anywhere else in any value stays the 1.2.3 error.
- **The order is the author's preference**, not sorted. Ascending
  (`mm|m|km`) is the usual and recommended form; weft does not require it.
- **Every rung is checked against the quantity**, whichever is picked: one that
  does not parse, is refused (4.4.20), does not convert, converts only by
  inversion, or is a twin of the quantity's unit (4.4.14) is a value error
  naming the rung. Two rungs written alike (`m|m`, `m| m`) or an empty rung
  (`mm||km`, `m|`) are construct errors. Two rungs of the same size (`m|metre`,
  `L|dm^3`, `mg/L|g/m^3`; factor 1 within 1e-9) are a value error: the later one
  could never be picked.
- Compound units, the default table's units, project units and a unit written
  before the number are rungs like any other. The picked rung prints exactly
  as `unit="<rung>"` would: symbol as typed (`ug/L`), name, plural, space and
  `before:` (4.4.22).

### Picking the rung (4.4.23)

For each rung, the quantity is converted and its numbers are printed as the
use's classes and keys would print them (number stage, 1.4.11, with `digits`,
`sigfig`, `.range`'s shared decimals; before any wording class). What is tested
is the absolute value of each **number as printed** (the record's number), so
"999.96 m" is never printed "1,000.0 m". A number **fits** a rung when
1 ≤ |n| < 1,000. Missing and non-finite elements are not tested.

- **One number**: the first rung, in the ladder's order, where it fits. If none
  fits, the rung whose number is nearest the window, measured as a ratio
  (|n| below 1 is 1/|n| away, |n| of 1,000 or more is |n|/1,000 away); ties go
  to the earlier rung. A number that prints 0 is infinitely far in every rung,
  so **zero takes the first rung**. With an ascending ladder a number too small
  for every rung takes the smallest unit, and one too large the largest.
- **A vector** (also under `.and`, `.or`, `.range`, `.pairs`, list classes,
  `trunc`, an uncollapsed vector, `glue_vec()`, the `#` of a `list` span): the
  rung where the most of its tested numbers fit; ties go to the earlier rung.
  If no rung has any fit, the rung its largest absolute value takes alone by
  the one-number rule. Every element counts, also those `trunc` hides. A vector
  with nothing to test (length zero, all `NA`) takes the first rung.
- A **negative** number is judged by its magnitude, and so is a `sign`
  governor.
- **Determinism**: the rung depends only on the value's own numbers, the ladder
  and the use's classes and keys. The same value with the same ladder and keys
  always prints in the same rung, in every call, chunk and session. A value
  whose numbers change may print in another rung; the ledger then shows a
  changed printed text (7.1.7), as for any other change.
- Everything after the pick happens in the picked rung: the printed record,
  arm selection (4.4.9), `#`, names and plurals (4.4.16), the `weft_text`
  attributes `unit`, `unit_form`, `units` (3.4.4), and the zero rule.
- **`last_knit()$constructs`** gains a column `unit_picked`: for a construct
  with a `unit` key, the rung it printed in, as written in the ladder (`"km"`);
  `NA` otherwise. The ledger stores nothing new.

### Interactions

- **Back-references.** An `#id` on a construct with a ladder records the
  quantity converted to its picked rung. A referring span prints what the
  value printed: with no formatter of its own it uses the record (1.7.8);
  formatting afresh, it starts from the quantity in that rung, so `.uname` or
  `digits` keeps the unit. A `unit` on the referring span converts again (one
  unit, or a ladder that picks afresh).
- **`n="."`** inherits the governor as printed, in the picked rung.
- **The zero rule.** A ladder prints "0.0" only when every rung prints zero
  (a rung whose number is not zero is nearer). Then the rung is the first, the
  warned check is recorded as today (4.4.13), and its advice names, when the
  first rung is one SI token, the ladder with the prefixed unit that would
  print 1 up to 1,000 put first: `unit="mm|m|km"` for 0.04 m under
  `unit="m|km"`. For a compound rung, and for a vector whose picked rung
  prints only some elements as zero (`u(c(0.0001, 500), m)` under `m|km`
  prints "0.0 and 500 m"), it names `digits` and `sigfig` only, as 2g does
  for a compound. `digits` or `sigfig` silences it as before.
- **`display:`** (4.2.7) takes a ladder, applied **once, when the dictionary
  is read**, to the entry's own value: it is converted to the rung it picks,
  tested as `.num` prints under weft's shipped default digits (1) whatever
  `_weft.yml` sets, so `read_dict()` in a pipeline and a knit agree.
  `dict$x` then **is** in that rung for arithmetic, checks, `#`,
  `units::drop_units()`, the glossary (2c) and the pipeline, as for a single
  `display:`. **The ladder does not travel**: a value computed from the entry
  stays in the entry's rung; for a ladder on it, write `unit=` at the use
  (L13). The `entries` column `display` holds the rungs joined by `|`
  (`"m|km"`), `NA` where absent; `print()` shows the unit the entry is held
  in. Problems (4.2.6): 4.2.7's, per rung; an empty or repeated rung; two
  rungs of the same size; a list item holding `|`; a value that is neither a
  string nor a list of strings.
- **Precedence.** `unit` at the use wins over `display:` (4.4.15): the use's
  ladder picks from the value in whatever rung the dictionary gave it.
- **`unit_form`, `.uname`, `.usym`, `.nounit`**: unchanged; they act on the
  picked rung. **`unit_defaults: si`**: rungs are read in the mode in force,
  so `mph` on a ladder is a milliphot under `si` and does not convert from
  km/h.
- **`fmt_unit(x, unit_form, unit)`** with a ladder and a quantity picks as
  `.num` would print `x` (one number or the vector rule) and prints that
  rung, plural unless `x` has length one and prints "1". With a string `x` a
  ladder of more than one rung is a value error. A heading agrees with a
  column given the same ladder; with `digits` on the column they can differ
  only for a number within rounding of the window's edge.

### Expected output

Defaults, mode `weft`, `.num` unless the row says. "L" is `unit="mm|m|km"`.

| Value | Construct or call | Prints |
|---|---|---|
| `u(1500, m)` / `u(250, m)` / `u(0.25, m)` | `{L}` | `1.5␣km` / `250␣m` / `250␣mm` |
| `u(1, m)` / `u(1000, m)` | `{L}` | `1␣m` / `1␣km` |
| `u(999.96, m)` / `u(0.99996, m)` | `{L}` | `1.0␣km` / `1.0␣m` |
| `u(0.0004, m)` / `u(5e6, m)` | `{L}` | `0.4␣mm` / `5,000␣km` |
| `u(0, m)` / `u(-1500, m)` | `{L}` | `0␣mm` / `−1.5␣km` |
| `u(1500, m)` | `{unit="mm \| m \| km"}`, outside a table; `fmt_num(x, unit = c("mm", "m", "km"))` | `1.5␣km`; `1.5␣km` |
| `u(0.05, m)` | `{unit="mm\|cm\|m"}` / `{unit="cm\|mm\|m"}` | `50␣mm` / `5␣cm` |
| `u(5, m)` | `{unit="mm\|km"}` (a gap) | `5,000␣mm` |
| `u(150, cm)` | `{unit="m"}` (a ladder of one) | `1.5␣m` |
| `u(0.002, mg/L)` / `u(5, mg/L)` | `{unit="ug/L\|mg/L"}` | `2␣ug/L` / `5␣mg/L` |
| `u(0.002, mg/L)` | `{.uname unit="ug/L\|mg/L"}` | `2␣micrograms per litre` |
| `u(0.002, ppm)` | `{unit="ppm\|ppb"}` / `{.uname unit="ppm\|ppb"}` | `2␣ppb` / `2␣parts per billion` |
| `u(1000, m)` / `u(2500, m)` | `{.uname L}` | `1␣kilometre` / `2.5␣kilometres` |
| `u(3000, m)` | `{.word unit="m\|km"}` | `three␣kilometres` |
| `u(0, m)` | `{.no unit="mm\|m"}` | `no␣millimetres` |
| `u(1234.5, m)` / `u(999.6, m)` | `{unit="m\|km" digits="2"}` / `{unit="m\|km" sigfig="2"}` | `1.23␣km` / `1.0␣km` |
| `u(0.04, m)` | `{unit="m\|km"}` | `0.0␣m`; one warned check whose message has `unit="mm\|m\|km"` |
| `u(1000, m)` / `u(999, m)` | `[# was \| # were]{n="x" L}` | `1␣km was` / `999␣m were` |
| `u(-0.5, m)` | `[rose by # \| fell by #]{sign="x" unit="mm\|m"}` | `fell by 500␣mm` |
| `u(c(1500, 2500), m)` | `[none \| # was \| # were]{list="x" unit="m\|km"}` | `1.5 and 2.5␣km were` |
| `u(c(3, 50, 800, 2500), m)` | `{.and unit="m\|km"}` | `3, 50, 800 and 2,500␣m` |
| `u(c(500, 2000), m)` | `{.and unit="km\|m"}` (a tie: the earlier) | `0.5 and 2␣km` |
| `u(c(0.5, 2), m)` / `u(c(0.5, 0.8), m)` | `{.range L}` / `{.range unit="mm\|m"}` | `500–2,000␣mm` / `500–800␣mm` |
| `u(c(1500, 2500, 300, 400), m)` | `{.and trunc="2" unit="m\|km"}` | `1,500, 2,500␣m and 2 others` |
| `u(c(a = 0.4, b = 2), km)` | `{.pairs unit="m\|km"}` | `a (400␣m) and b (2,000␣m)` |
| `u(c(0.5, 0.7), km)` / `u(c(0, 0), m)` | `{unit="m\|km"}` / `{.and unit="mm\|m"}` | `500␣m, 700␣m` / `0 and 0␣mm` |
| `u(1500, m)` | `` `r x`{#d unit="m\|km"} ``, then `[#]{n="#d"}` / `{n="#d" .uname}` / `{n="#d" unit="m"}` | `1.5␣km`, then `1.5␣km` / `1.5␣kilometres` / `1,500␣m` |
| `u(100, km/h)` | `{unit="mph\|km/h"}` / same under `unit_defaults: si` | `62.1␣mph` / value error naming `mph` |
| `u(2, Sv)` | `{unit="mSv\|Sv\|Gy"}` | value error naming `Gy` (twins), though `Sv` would be picked |
| `u(5, m)` | `{unit="mm\|kg"}` / `{unit="m\|1/m"}` | value error naming `kg` / naming `1/m` |
| `u(5, t)` | `{unit="kg\|mt"}` | value error naming `mt` (refused, 4.4.20) |
| `u(5, m)` | `{unit="m\|metre"}` / `{unit="m\|m"}` / `{unit="mm\|\|km"}` | value error (same size) / construct error / construct error |
| entry 2000 m, `display: m\|km` / the same, value 900 | `` `r dict$x`{.num} `` | `2␣km` / `900␣m` |
| the same two entries | `` `r dict$x * 3`{.num} `` | `6␣km` / `2,700␣m` |
| entry 2000 m, `display: [m, km]` / `display: m\|km` and `{unit="mm\|m"}` | `{.num}` | `2␣km` / `2,000␣m` |
| entry 1 m, `display: m\|kg` | `read_dict()` | `weft_dict_error`, a problem naming `kg` |
| `u(1500, m)` | `fmt_unit(x, unit = "m\|km")` / with `unit_form = "name"` | `km` / `kilometres` |
| `u(1000, m)` / `u(c(NA, 1500), m)` / `u(numeric(0), m)` | `fmt_unit(x, unit = "m\|km", unit_form = "name")` / `fmt_unit(x, unit = "m\|km")` / `fmt_unit(x, unit = "km\|m")` | `kilometre` / `km` / `km` |
| `"m"` | `fmt_unit(x, unit = "mm\|m")` | value error |

In the source the `|` of a ladder is not escaped outside a table; the `\|` in
the table above is this file's own table syntax. `attr(fmt_num(u(1500, m), unit
= "m|km"), "units")` is `km`. After a knit of `` `r x`{unit="m|km"} `` with
`x <- u(1500, m)`, that construct's `unit_picked` is `"km"`; `{unit="km"}` gives
`"km"`; a construct with no `unit` gives `NA`. `units::deparse_unit(dict$x)`
is `"km"` for the 2000 m entry. Tests turn Pandoc's `\ ` into `␣`, as in 2f.

## Errors

All carry `weft_error`. A value error in a knit is a collected failure with a
marker (5.3.2); outside, it is raised. Messages end with the rule.

| Class | When | The message says |
|---|---|---|
| `weft_construct_error`, source and call | an empty rung | "`unit = mm\|\|km`: the ladder has an empty rung; separate units with `\|`, such as `unit="mm\|m\|km"` (rule 4.4.23)." |
| same | a rung written twice | "`unit = m\|km\|m`: `m` is on the ladder twice (rule 4.4.23)." |
| same, call | a list item holding `\|`; an `NA` or blank item | that the ladder is one string with `\|` or a vector of single units |
| `weft_construct_error`, source | an unescaped `\|` in `unit` in a pipe-table cell | "An unescaped `\|` in the `unit` of a construct in a pipe-table cell (rule 1.5.13); write `\\|`." (the message shows a backslash and a bar) |
| `weft_value_error` | a rung that does not parse, is refused, does not convert, converts only by inversion, or is a twin | "`unit = <ladder>`: rung `<r>`: " then 4.4.14's or 4.4.20's text for one unit |
| `weft_value_error` | two rungs of the same size | "`unit = m\|metre`: `m` and `metre` are the same size, so `metre` could never be picked; keep one (rule 4.4.23)." |
| `weft_value_error` | `fmt_unit()` with a string and a ladder | "fmt_unit(): a ladder picks its unit by the quantity's numbers, and a string has none; pass the quantity, or one unit (rule 3.4.9)." |
| `weft_dict_error` | a `display:` problem | one line among the dictionary's problems (4.2.6), naming the key, the field, the rung |

`unit` on a value that is not a quantity stays 4.4.14's value error.

## Decisions

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| L1 | separator | `,`; a space; lists only | `\|`, escaped `\|` in a pipe-table cell | reads as "or" and Robin approved it; a space is multiplication in a unit; Pandoc reads `\|` as `\|` in an attribute (run); the arm rule already teaches the escape | the splitter and one scanner check |
| L2 | list forms | refuse; accept | accept a YAML sequence and an R character vector | what a YAML or R writer types; refusing it is pedantry | the reader |
| L3 | order | sorted by size; preference | preference | Robin's "the first unit on the ladder"; overlapping rungs (`mm\|cm\|m`) need an order | one loop |
| L4 | rung checks | the picked rung only; every rung | every rung | an error must not come and go with the data (U3) | the checker |
| L5 | duplicates | allow; error | same text a construct error; same size a value error | both are dead rungs, the first visible from the source | two checks |
| L6 | number tested | raw; as printed | as printed in that rung | "999.96 m" would print "1,000.0 m"; arms already follow the printed number (1.5.9) | one call |
| L7 | window | 0.1–1,000 (SI Brochure 5.4); configurable; 1–1,000 | 1 ≤ \|n\| < 1,000, fixed | Robin's rule; another window is another ladder | one constant |
| L8 | no fit | first rung; last rung; nearest | nearest by ratio, ties earlier; zero first | gives smallest and largest for an ascending ladder and handles gaps by one rule | one function |
| L9 | a vector | largest value; median; most fit | most fit, ties earlier, none: the largest alone | the largest value prints small elements "0.0" ("0.0, 0.1, 0.8 and 2.5 km"); a tie to the earlier rung of an ascending ladder keeps digits, as a number below 1 loses them under fixed decimals | one function |
| L10 | `trunc` | printed elements; all | all | the unit is the vector's, and the hidden elements are part of it | one argument |
| L11 | `NA` | fail; ignore | ignore in picking | the "no value" failure (4.4.13) already reports it | one filter |
| L12 | negatives | signed; magnitude | magnitude | a fall of 0.5 m is "500 mm", as a rise | `abs()` |
| L13 | `display:` ladder | an attribute read at print; first rung at read; out of scope; picked at read | picked at read from the entry's value | measured on `units` 1.0.0: an attribute survives `x * 2`, `x + y`, `round()` and **`x * y`** (a length ladder on an area) but not `x[1]`, `c()`, `mean()`, `sum()`, `max()`, `set_units()`; a ladder of one is today's `display:` exactly | `R/dict.R` |
| L14 | `display:` digits | `_weft.yml`'s; shipped default | shipped default | `read_dict()` in a pipeline does not read `_weft.yml`; a knit and a target must agree | one argument |
| L15 | back-reference | raw in the held unit; in the picked rung | in the picked rung | "print what the value printed" (1.7.8) | the id record |
| L16 | zero advice | as 2g; add the rung | the ladder with the prefixed unit first | the author keeps the ladder and gains the rung that shows the value | the message |
| L17 | recording | none; the ledger; `last_knit()` | `unit_picked` in `last_knit()$constructs` | the printed text already shows a change in the ledger; the column answers "why km?" | one column |
| L18 | `fmt_unit("m", unit = ladder)` | first rung; error | error | a heading that guesses its rung can disagree with its column | one branch |

## Spec amendments

- **1.2.3** a `\` inside a value is an error except `\|` in the value of
  `unit`, read as `|`.
- **1.4.7** the `unit` row: "the unit, or a ladder of units, a quantity is
  printed in (4.4.14, 4.4.23)".
- **1.5.13** add: "So must the `|` of a ladder in `unit` (4.4.23), in a value
  or a span".
- **2.6.11** and **4.4.13** the advice with a ladder (L16).
- **3.4.4** `unit =` takes a ladder as the key does, also as a character
  vector; `units` holds the picked rung.
- **3.4.9** `fmt_unit()` with a ladder; a string with a ladder is a value
  error.
- **3.7.5** `constructs` holds `unit_picked`.
- **4.2.1** `display` is a unit or a ladder (`m|km`, or a list).
- **4.2.7** rewritten for the ladder: picked once at read from the entry's
  value under the shipped default digits; the ladder does not travel; the
  `display` column holds the ladder joined by `|`; `print()` shows the held
  unit; the new problems.
- **4.4.9** "after any conversion by `unit` (4.4.14), in the rung a ladder
  picked (4.4.23)".
- **4.4.14** first sentence: "`unit="m"`, or a ladder `unit="mm|m|km"`
  (4.4.23), …"; the conversion errors apply to every rung.
- **4.4.15** the unit shown: "`unit=` at the use, one unit or a ladder
  (4.4.14, 4.4.23), then `display:`, …".
- **4.4.23 (new)** the ladder: writing it, the rung checks, picking one number
  and a vector, determinism, back-references, `display:`, `unit_picked`
  ("Writing a ladder" and "Picking the rung" above).
- **5.3.1** add: an empty or repeated rung in `unit`; an unescaped `|` in `unit`
  in a pipe-table cell (1.5.13, 4.4.23).
- **5.3.2** add "a unit or a rung the quantity cannot be converted to, or two
  rungs of the same size (4.4.14, 4.4.23)", and the count rises by one.
- **§13** 4.4.23: decision 51's reasons are why weft never picks alone; a
  ladder is the author's approval; the printed number is tested because arms
  follow it; most-fit because the largest value prints zeros; `display:`
  picks at read because a ladder attribute survives `x * y` onto the wrong
  dimension and is lost in `c()` and `mean()` (L13).
- **`dev/decisions.md`** 51's last sentence: "built as package 2h"; a new
  entry 52 points to this note. **`inst/dict/dict.schema.json`** `display`:
  a string or an array of strings, at least one; **`inst/dict/dict.yml`** a
  comment showing `display: m|km`.

## Tests

Three new files; temporary projects and dictionaries as 2f's helpers make them;
tests that set `unit_defaults: si` restore `weft` on exit, as 2g's do.

- `test-unit-ladder.R`: every expected-output row, through `weft_str()` and
  the functions; the window's edges with and without `digits`; zero,
  negatives, gaps, order, the fallback both ways; the vector rule (a tie, no
  fit, `NA`, length zero, `trunc`) under every collapse class and uncollapsed;
  `#` in `n`, `sign`, `list` spans and `n="."`; back-references; names and
  plurals; the unit classes and `unit_form`; the zero rule, its advice and
  `digits` silencing it; `si`; the `units` attribute; `unit_picked`;
  determinism (one value twice in a document and across two knits); every
  error from a construct and a function, the rung named; a ladder of one on
  the 2b and 2f `unit=` rows.
- `test-unit-ladder-source.R` (scanner, no R evaluated): an empty and a
  repeated rung are construct errors; in a pipe-table cell `\|` is read as `|`
  and an unescaped `|` in `unit` is an error, in a value and in a span; `\|`
  outside a table is accepted; `\` elsewhere in `unit` and in any other key
  stays an error (controls); a `|` in `unit` does not change a span's arm
  count.
- `test-unit-ladder-dict.R`: `display:` as a string and as a YAML list; 2000 m
  and 900 m pick `km` and `m`; arithmetic keeps the held unit; the `display`
  column and `print()`; every new problem in one error with the old ones;
  `{unit=}` over a ladder; `dict_local`; a `_weft.yml` `digits: 3` does not
  change the pick; the glossary prints the held unit.

**Superseded**, amended by the test-writer and listed in its report: none
known. Candidates to check: any assertion that `unit =` must be one string
(a character vector is now a ladder), and any that a two-item list as
`display:` is a problem. The 2c schema cases (`display: [cm]`) stand.

## For Robin

Built as recommended until answered.

- **Q1 — `display:` with a ladder picks once, when the dictionary is read**
  (L13), so `dict$x` is held in the rung its value picks and the pipeline
  sees that unit: editing a value from 900 to 2,000 m moves the entry from m
  to km, and a `units::drop_units()` in a target changes scale by 1,000 with
  it. The ladder does not follow a computed value. Alternatives: leave
  `display:` a single unit and write ladders only at the use (no pipeline
  effect), or an attribute (rejected: measured to survive `x * y` onto an
  area and be lost in `c()` and `mean()`). Recommended: as built.
- **Q2 — a vector takes the rung where most of its numbers fit**, ties to the
  earlier rung (L9). So `u(c(0.5, 2), m)` with `mm|m|km` is "500–2,000 mm",
  not "0.5–2.0 m". Alternative: the largest value picks, as plot scales do,
  which prints small elements as "0.0". Recommended: as built.
- **Q3 — `|` and `\|` in a table** (L1). Alternative: a comma
  (`unit="mm,m,km"`), which needs no escape anywhere. Recommended: `|`.
- **Q4 — the order is a preference** (L3): `cm|mm|m` prints 0.05 m as "5 cm"
  and `mm|cm|m` as "50 mm". Alternative: sort by size and ignore the order.
  Recommended: as built.
