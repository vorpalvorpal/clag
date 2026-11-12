# Review of package 2h — the unit ladder

Snapshot: the plain export `snap-2h` of commit 80d3ff9, loaded with
`devtools::load_all()` in a fresh `Rscript` process per probe. `units` 1.0.0,
R 4.4, Pandoc 3.8.3. "`ws(s)`" is `weft_str(s)` run from an empty project (or
one holding the `_weft.yml` named); the R objects it names are set first in
the global environment. Knits are `knitr::knit()` of an `.Rmd` with
`weft::weft_setup()` and `WEFT_DRAFT=1` in a temp project; renders go through
`pandoc -t plain`. `~` is U+00A0 (also Pandoc's `\ `). The contract is
`dev/design-2h.md` with its rulings; the rule text quoted is 4.4.23 as amended
in 9d499d5 (after the snapshot; the snapshot's `PACKAGE-SCOPING.md` has no
4.4.23). `zzd` is a made-up token.

## Findings

**1. `.nounit` with a ladder prints a bare number in a unit no reader can
see.**
Severity: silent wrong output.
- A hand-written pipe table, heading from `fmt_unit()`, one construct per cell
  (`a <- u(1500, m)`, `b <- u(400, m)`):

  ```
  | Reach | Length (`r fmt_unit(a, unit="m|km")`) |
  |---|---|
  | A | `r a`{.nounit unit="m\|km"} |
  | B | `r b`{.nounit unit="m\|km"} |
  ```
  → `| Reach | Length (km) |`, `| A | 1.5 |`, `| B | 400 |`. Reach B reads as
  400 km.
- `fmt_num(u(400, m), unit = "m|km", unit_form = "none")` → `400`;
  `fmt_num(u(1500, m), unit = "m|km", unit_form = "none")` → `1.5`. No warning
  either way. `last_knit()$constructs$unit_picked` holds the rung, but nothing
  printed does.
- Expected: the scope note says a column takes one rung "by the vector rule",
  but a pipe table is written cell by cell, so each cell is one value and picks
  alone. L18 refuses `fmt_unit("m", unit = ladder)` because "a heading that
  guesses its rung can disagree with its column". The same reason applies, more
  strongly, to a number printed without its unit. A ladder of more than one
  rung under `.nounit` or `unit_form = "none"` should be a value error.
- Cause: `apply_formatters()` (`R/format.R`) picks the rung in
  `convert_unit()` (`R/units.R`) and then drops the unit for `none`. Nothing
  checks the two together.

**2. With `display:` a ladder, a one-character edit to `dict.yml` changes a
downstream number by a factor of 1,000 or more, and the unit of a sum depends
on the order of its operands.**
Severity: silent wrong output (the hazard Q1 names, stated precisely).
- `dict.yml`: `pipe: {value: 800, type: quantity, unit: m, display: m|km, …}`
  and `rate: {value: 12, type: number, …}`. In a pipeline,
  `units::drop_units(dict$pipe) * dict$rate` → `9600`. Edit `800` to `8000`
  (one character added): → `96`. The pipe got ten times longer and the cost
  fell a hundredfold. `as.numeric(dict$pipe)` goes from `800` to `8`.
- The threshold is where `.num` at one decimal stops printing under 1,000:
  999.94 m is held in m, 999.95 m in km. Any exit to bare numbers crosses it
  silently: `drop_units()`, `as.numeric()`, a CSV export, a `targets` hash, a
  plot axis. Arithmetic in `units` stays right.
- Entries `long: 2000 m` and `short: 900 m`, both `display: m|km`:
  `` `r dict$long + dict$short`{.num} `` → `2.9~km`;
  `` `r dict$short + dict$long`{.num} `` → `2,900~m`.
  `drop_units()` of the two gives `2.9` and `2900`.
- The same entry also differs from what a single `display:` gives. With
  `display: km` the held unit never moves.
- Expected: the contract states the edit-moves-the-unit case (Q1) but not
  the operand order, and not that `drop_units()` of the same quantity changes
  scale. See question a.
- Cause: `build_dict()` (`R/dict.R`) converts the value to the picked rung at
  read, by design (L13).

**3. A ladder with an offset unit (`degC|K`) prints temperatures near freezing
in kelvin, and zero is not "the first rung".**
Severity: silent wrong output (contract mismatch for zero).
- `ws('`r x`{unit="degC|K"}')` with `x <- u(t, degC)`: 20 → `20~°C`;
  −5 → `−5~°C`; **0.5 → `273.7~K`**; **−0.5 (under `mK|degC|K`) → `272.7~K`**;
  **0 → `273.2~K`**. `{.no unit="degC|K"}` on 0 °C → `273.2~K`.
- `u(300, K)` → `26.9~°C`; `u(1500, degC)` under `degC|kK` → `1.8~kK`.
- In the dictionary: `d: {value: 0.5, type: quantity, unit: degC, display:
  degC|K, …}` → `print(dict)` shows `273.65 K`, and `dict$d` is held in K.
- Expected: 4.4.23 says "Zero is infinitely far in every rung and takes the
  first". For an offset unit, zero in one rung is 273.15 in another. The
  window 1 ≤ |n| < 1,000 is a rule about magnitude on a ratio scale, and a
  Celsius temperature is not one. An author who writes `degC|K` for air
  temperatures does not expect a frost of 0.5 °C to print as 273.7 K.
- Cause: `ladder_pick()` and `ladder_far()` (`R/units.R`) test each rung's
  number with no regard to offsets. `ladder_same_size()` accepts `degC|K`
  because its factor at 1 is 274.15. See question e.

**4. A spelled-number class with a ladder fails for some values and prints for
others. The error comes and goes with the data.**
Severity: crash (data-dependent).
- `` `r x`{.word unit="m|km"} ``: 999 m → `999~m`; 1000 m → `one~kilometre`;
  **1200 m → value error** "`.word` needs a whole number that is not negative,
  judged as printed (rule 1.4.12); got "1.2""; **1500 m, 2500 m → the same
  error**; 2000 m, 3000 m → `two~kilometres`, `three~kilometres`.
- The same values with `{.word unit="m"}` all print: `1,500~m`.
- `.count`: the same. `u(c(1000, 1500), m)` `{.and .count unit="m|km"}` →
  error "got "1.5""; with `unit="m"` → `1,000 and 1,500~m`.
- `[# was | # were]{n="x" .word unit="m|km"}` with 1500 m → the same error.
- Expected: L4 checks every rung "so that an error does not come and go with
  the data". Here the error does exactly that. A report that says "two
  kilometres" today fails tomorrow at 1.5 km. Either the pick skips a rung
  where the class cannot print the number (it is not whole), or a wording
  class with a ladder of more than one rung is a value error.
- Cause: `ladder_pick()` tests the number as `.num` prints it ("before any
  wording class", accepted in the rulings). The wording stage of
  `apply_formatters()` then refuses it.

**5. The vector rule picks a rung that prints elements as "0.0" when another
rung prints every element, and one added element can flip a whole vector to
it.**
Severity: wrong output (warned).
- `u(c(0.3, 0.4, 2000, 3000), m)` `{.and unit="m|km"}` (and `km|m`) →
  `0.0, 0.0, 2 and 3~km`, with the warned check "0.0003 printed as 0.0 (2
  values printed as zero): add sigfig … or digits …". `unit="m"` prints
  `0.3, 0.4, 2,000 and 3,000 m`.
- Ten values, `c(5, 6, 7, 8, 9, 25000, 30000, 40000, 50000, 60000)` m,
  `{.and unit="m|km"}` → `5, 6, 7, 8, 9, 25,000, … and 60,000~m` (a 5–5 tie,
  the earlier rung). Add `70000` → `0.0, 0.0, 0.0, 0.0, 0.0, 25, 30, 40, 50,
  60 and 70~km`. One new reading wipes five old ones.
- A descending ladder: `u(c(0.0002, 0.003, 5), mg/L)`
  `{.and unit="mg/L|ug/L|ng/L"}` → `0.0, 0.0 and 5~mg/L` (a three-way tie of
  one fit each, the earliest wins). Under `ug/L` it is `0.2, 3 and
  5,000 ug/L`.
- `u(c(0.0001, 5e6), m)` under `mm|m|km` (no rung fits; the largest decides)
  → `0.0 and 5,000~km`. Under `mm` nothing would be zero.
- The advice "digits to confirm it" silences the check and keeps the zeros.
- Expected: L9 chose most-fit because "the largest value prints small elements
  '0.0'". The rule still does so whenever the large elements outnumber the
  small, and L9's tie argument ("a tie to the earlier rung of an ascending
  ladder keeps digits") fails for a descending ladder. See question b.
- Cause: `ladder_pick()` counts fits only. A rung that prints a non-zero
  element as zero is not penalised.

**6. With a gap in the ladder, the "nearest" rung is judged on the rounded
number, so it prefers a rung that destroys the value.**
Severity: silent wrong output.
- `fmt_num(u(v, m), unit = "mm|km")`: 5 → `5,000~mm`; 40 → `40,000~mm`;
  46 → `46,000~mm`; **50 → `0.1~km`; 60 → `0.1~km`; 140 → `0.1~km`;
  149 → `0.1~km`**; 151 → `0.2~km`.
- So 149 m prints as 100 m (a third lost), 46 m prints exactly, and nothing
  warns. The output is not monotone: 46 m and 50 m print in different units.
- Expected: the author put `mm` on the ladder. 4.4.23 measures distance from
  the window on the number as printed, so the 0.149 that printed "0.1" counts as
  10 away and beats 149,000 at 149 away. It is the right test for fitting (L6)
  but the wrong one for nearness.
- Cause: `ladder_far()` is given `shown` (the printed numbers) in the
  no-fit branch of `ladder_pick()`. Measuring nearness on the unrounded
  number, or refusing a rung whose printed number has lost more than rounding
  to one significant figure, would pick `mm`.

**7. A `display:` ladder is picked under the default digits, so a project with
`digits: 0` prints the number the ladder exists to avoid. The determinism
statement leaves `_weft.yml` out.**
Severity: wrong output (contract mismatch in 4.4.23's determinism clause).
- `dict.yml`: `reach: {value: 999.6, type: quantity, unit: m, display: m|km,
  …}`. `_weft.yml` `digits: 0`. In a knit, `` `r dict$reach`{.num} `` →
  **`1,000~m`**. `` `r dict$reach`{unit="m|km"} `` → `1~km`. The glossary:
  `` `reach` (1,000~m) ``.
- Same value, same ladder, no keys at the use: `` `r x`{unit="m|km"} `` with
  `x <- u(999.6, m)` → `999.6~m` in an empty project and `1~km` under
  `digits: 0`. `u(0.9996, m)` under `mm|m` → `999.6~mm` and `1~m`.
- Expected: 4.4.23, "What is tested is … the number as printed, so that 999.96
  m is never printed '1,000.0 m'", and "the rung depends only on the value's own
  numbers, the ladder and the use's classes and keys". The project's (and the
  document's) `digits` also decide. L14 chose the shipped digits for
  `display:` so that a pipeline and a knit agree. The cost is this case, which
  neither the contract nor `?dict_file` mentions.
- Cause: `build_dict()` passes `default_config()` to `ladder_pick()`. At the
  use, `apply_formatters()` passes the configuration in force.

**8. `plural()` on the quantity disagrees with the ladder's printed number.**
Severity: wrong output (low; the author's composition).
- `x <- u(1000, m)`:
  `` `r x`{unit="m|km"} `r plural(x, "was", "were")` `` → `1~km were`. Before
  2h the natural form, `` `r x`{.num} `r plural(…)` ``, gave `1,000~m were`,
  which agrees.
- `plural(fmt_num(x, unit = "m|km"), "was", "were")` → `was`. So does the span
  `[# was | # were]{n="x" unit="m|km"}`.
- Expected: not stated. `?plural` could say that with a ladder you pass the
  formatted value or use a span.
- Cause: `plural()` (`R/format.R`) judges the raw 1000.

**9. `unit_picked` is filled for a construct that failed after the pick.**
Severity: contract mismatch.
- Knit `` `r vv`{.and unit="m|km"} `` with `vv <- u(c(NA, 1500), m)` → the
  marker `<<weft: no value, line 28>>`, and that row of
  `last_knit()$constructs` has `unit_picked` `"km"`. `` `r x`{unit="m|kg"} ``
  (a failure before the pick) → `NA`.
- Expected: 3.7.5/4.4.23, "the rung it printed in". It printed nothing.
- Cause: `pick_note()` (`R/resolve.R`) writes `R$unit_picked[k]` from inside
  `convert_unit()`, before the formatting that then fails. `record_fail()`
  does not clear it.
- Every other route checked is right: a value, a vector, `n`, `sign`, the `#`
  of a `list` span, `n="."` (`NA`), a back-reference without `unit` (`NA`),
  one with `unit="m|mm"` (`m`), a single `unit="km"` (`km`), and
  `fmt_num(x, unit = "m|km")` inside inline code (`NA`, no key).

**10. Dictionary messages for a ladder: the rule is cited twice, a list item
holding `|` is shown as a valid-looking ladder, and a one-item list holding
`|` is accepted.**
Severity: unclear error (and contract mismatch for the one-item list).
- `display: "m||km"` → "`display` `m||km`: the ladder has an empty rung; …
  (rule 4.4.23). (rule 4.4.23)". The same doubling for `[m, m]`, `"|"`,
  `["", km]`, `[m|km, mm]`.
- `display: [m|km, mm]` → "`display` `m|km|mm`: the ladder is one string with
  `|` between the units, or a vector of single units, …". `m|km|mm` is a
  valid ladder as written. The message should name the item that holds `|`.
- `display: [m|km]` → no problem. `entries$display` is `m|km`, and the entry
  is held in km. The contract says "a list item holding `|`" is a problem.
  (YAML reads `[m|km]` and `m|km` alike as one string, so the check cannot be
  made after `yaml.load()`.)
- Expected: "one line … naming the key, the field, the rung" (Errors table).
- Cause: `strip_rule()` (`R/dict.R`) removes " (rule x)" only at the very
  end, and `ladder_split()`'s text ends "(rule 4.4.23)." with a full stop.
  `ladder_split()` writes `written` by pasting the items with `|`.

**11. The twin message names the rung twice.**
Severity: cosmetic.
- `` `r u(2, Sv)`{unit="mSv|Sv|Gy"} `` → "`unit = mSv|Sv|Gy`: rung `Gy`:
  `Gy`: the quantity is in `Sv`, …". In the dictionary: "`display` `Gy`:
  `Gy`: the quantity is in `Sv`, …".
- The other rung failures read cleanly ("rung `kg`: the quantity (m) cannot
  be converted to it. cannot convert m into kg"). These, like the single-unit
  text before 2h, end without a rule, against "Messages end with the rule".
- Cause: `convert_one()` (`R/units.R`) adds `pre` to `unit_twin_problem()`'s
  text, which already begins with the unit.

**12. `unit =` errors still say "one string" though a vector is now a
ladder.**
Severity: unclear error.
- `fmt_num(x, unit = character(0))`, `unit = NA_character_`,
  `unit = list("m", "km")`, `unit = factor("km")` → "`unit` must be one
  string that names a unit, such as "m" (rule 4.4.14)."
- `unit = c("m", NA)` → the ladder message, rightly.
- Expected: the message names both forms, a string or a character vector of
  units (4.4.23).
- Cause: `convert_unit()` (`R/units.R`) keeps the 2b text.

**13. Small contract-text and behaviour points.**
Severity: cosmetic.
- `dev/decisions.md` 51 still ends "… not built". The contract's spec
  amendments say it becomes "built as package 2h".
- 4.4.23's back-reference example writes `{n="#d" .uname}`. Written on a value
  (`` `r x`{n="#d" .uname} ``) it is the construct error "The key `n` on a
  value is an error (rule 1.3.3)". The form that works is `[#]{n="#d" .uname}`
  → `1.5~kilometres`.
- `.sci` with a ladder tests the `.num` number and prints, for example,
  `fmt_sci(u(1500, m), unit = "m|km")` → `1.5 × 10^0^~km`. That is harmless
  but pointless.
- `.pct`/`fmt_pct()`/`.p` with any quantity is the 4.4.8 error. With a ladder
  it names the picked rung ("cannot format a quantity in km" for 1500 m), so
  the contract's "a ladder is accepted … (`fmt_pct()` included)" can never
  print.

### Checked and as the contract says

The window's edges (0.9995, 0.99949, 999.5, 999.94 → m; 999.95, 999.96 →
`1.0~km`; 1000 → `1~km`; 0.0009999 → `1.0~mm`), with `digits` 0 to 4 and
`sigfig` 3 and 4. `(0.1 + 0.2) * 1e4` → `3~km`. Negatives and `sign`. Integer
input. `Inf`, `NaN` and `NA` give the "no value" failure; all rungs are still
checked for `NA` and length zero. Overlapping and non-SI ladders (`cm|mm|m`,
`in|ft|mi`, `gal|kL`, `Ma|ka|yr`, `m/s|km/h`, `mph|km/h`, `mg/L|ug/L|ng/L`).
`pH` with a refused `mpH`. A project unit with `before: true` as a rung. The
`si` mode (`mph` and `Ma` do not convert; `kg|mt` is "same size"). The
same-size check (`m|metre`, `L|dm^3`, `mg/L|g/m^3`, `m|1000 mm`, and
`1.0000000001 m` within 1e-9). The scanner: `\|` in a pipe-table cell in a value
and a span, render included; an unescaped `|` in either (a marker in a knit,
an error from `weft_str()`); `\|` outside a table; `\` in another key; grid
tables and captions accept a bare `|` (the scanner marks only pipe tables).
`arms()` and `rehearse()` cope with a ladder in a span, in and out of a table.
`trunc`, `.pairs`, `.dl`, `none` with length zero, named vectors.
Back-references and `n="."`, with ids on `n` and `sign` spans. `entries`,
`print()`, `dict_glossary()` and the schema (`display` already took a list).
Construct and value errors from a function inside a knit become markers of the
right kind. Front matter was not exercised: `knitr::knit()` does not run the
`opts_knit` activation.

## Questions

a. **Q1, a `display:` ladder applied at read.** I recommend against it: keep
   `display:` a single unit and write ladders only at the use. The evidence is
   finding 2. The held unit of `dict$x`, and so every exit to bare numbers,
   moves when the value crosses 999.95. A sum's unit depends on the order of its
   operands. A frost of 0.5 °C is held in kelvin (finding 3). Under
   `digits: 0` the entry prints "1,000 m" (finding 7). None of this happens
   with a ladder at the use, which converts only what it prints. The cost is
   that an author writes `{unit="m|km"}` at each use of the entry. If the
   feature stays, `?dict_file` should state the `drop_units()` hazard in
   those words, with the 999.95 threshold (measured: `value: 999.94` →
   `drop_units()` 999.94; `value: 999.95` → 0.99995).

b. **Q2, the vector rule.** Most-fit is better than largest-value, but finding 5
   shows it still prints "0.0" for real values whenever the large outnumber the
   small, and that one reading can flip a vector. **Recommend:** keep most-fit
   but first drop any rung that prints a non-zero element as zero when another
   rung prints none as zero. Then take most fit, ties to the earlier rung. That
   gives `0.3, 0.4, 2,000 and 3,000 m`, keeps the ten-and-eleven-value vectors
   in m, and gives `0.2, 3 and 5,000 ug/L`, all without changing any row of the
   contract's table. Also state in 4.4.23 that one value can print in a
   different unit alone and in a vector (`u(400, m)` → `400~m`; in
   `c(400, 2500, 3000)` → `0.4~km`). With `trunc` the elements shown are
   printed in a unit chosen by those hidden (`c(1500, 300, 400, 500)`,
   `trunc="1"` → `1,500~m and 3 others`). That is defensible but should be
   said.

c. **Q3, `|` against a comma.** **Recommend `|`, as built.** A comma breaks the
   most common dictionary form silently. `yaml.load("x: {value: 5, display:
   m,km}")` gives `display: "m"` and a stray key `km` with no value, while
   `m|km` reads as one string in flow and block style. The escape works: the
   scanner and Pandoc agree in pipe tables (rendered), grid tables and
   captions need none, and an unescaped `|` is caught in a knit and in
   `weft_str()`. The one gap is finding 10 (`[m|km]`), which no separator fixes.

d. **Q4, order as preference against sorted.** **Recommend preference, as
   built,** since overlaps need it (`cm|mm|m` → `5~cm`, `mm|cm|m` → `50~mm`, both
   sensible). But the contract's guarantees ("too small takes the smallest unit,
   too large the largest"; L9's tie argument) hold only for an ascending
   ladder. A descending ladder with a vector ties to the large unit and prints
   zeros (finding 5, `mg/L|ug/L|ng/L`). The rule in b removes most of that. In
   addition, 4.4.23 should say in one line that a descending ladder breaks ties
   towards the larger unit.

e. **Offset units on a ladder** (finding 3). The contract is silent.
   **Recommend:** a rung whose conversion from the quantity has an offset (°C,
   °F, K among themselves) is a value error on a ladder of more than one rung,
   in `unit` and in `display:`. "1 to 1,000" has no meaning on an interval scale.

f. **Wording classes on a ladder** (finding 4). **Recommend:** a rung is
   eligible for `.word`/`.count` only if the number prints whole in it. Or, more
   simply, make a wording class with a ladder of more than one rung a value
   error. The current behaviour is the one L4 was written to prevent.

g. **`.nounit` on a ladder** (finding 1). **Recommend:** a value error for a
   ladder of more than one rung, with the same reasoning as L18.

h. **Back-references re-formatted with other `digits`.** After
   `` `r y`{#e unit="m|km"} `` with 999.6 m (→ `999.6~m`),
   `[#]{n="#e" digits="0"}` → `1,000~m` and `[# is | # are]{n="#e" digits="0"}` →
   `1,000~m are`. That is the contract ("formatting afresh … `digits` keeps the
   unit"), and it agrees with "print what the value printed". But it is the
   "1,000 m" the ladder promises never to print. **Recommend:** keep it, since
   the alternative breaks 1.7.8, and add the example to 4.4.23 so that an author
   who adds `digits` to a reference knows to add `unit=` too.

i. **The gap fallback** (finding 6). **Recommend:** measure nearness on the
   unrounded number (`ladder_far(abs(nums))`), keeping the printed number for
   fit and for zero. This changes no row of the contract's table (`u(5, m)`
   under `mm|km` stays `5,000~mm`).

j. **The zero rule's advice with a prefixed first rung.** `u(0.00004, m)`
   under `mm|m` → "0.04 printed as 0.0 …" with no unit named, as 2g gives for
   `unit="mm"`. Under `km|m` there is no advice either. "When the first rung is
   one SI token" reads as if `mm` qualified. **Recommend:** say "an unprefixed
   SI unit" in 4.4.13. Leave the behaviour.
