# Review of the stage-2 fixes (units and the dictionary)

Snapshot reviewed: the `git archive` export in the session scratchpad (`snap-fix`), loaded with
`devtools::load_all()`. R 4.4, `units` 1.0.0, Pandoc and TinyTeX present. `~` in an output
below stands for U+00A0. "`ws(s)`" is `weft_str(s)` run from a fresh project folder (with the
`_weft.yml` shown, if any); "knit" is `knitr::knit()` of a small `.Rmd` with `weft::weft_setup()`
in its setup chunk, in draft mode so that markers show. Scripts and renders are in the
scratchpad folder `fixrev/`.

## Summary

Most of the fixes hold. The ladder fixes from 2h hold for the cases the review gave and their
near variants: the offset refusal, the whole-number rule for `.word`, the zero-avoiding vector rule,
the gap rule, `.nounit` with a ladder, `unit_picked`, and the messages. The registration lifecycle
works as 4.4.21 describes: loading changes nothing, the first use installs, a read in `si` mode
undoes it and a read in `weft` mode puts it back, and unloading restores `gal`, `Myr`, `pH` and
`mph`. The LaTeX path renders U+2212, µ, °, Ω, ′, ″ and `·` under both pdflatex and xelatex.
Some fixes, though, were made only for the reproduction the review gave:
- the glossary's trailing blank line (2c #5) is in the string but is lost in a real knit, so the
  paragraph after the chunk is still swallowed;
- `.cap` keeps a symbol only when it is applied directly to `fmt_unit()`;
- the no-numerator rule covers `m^-3` but not `1/m^3`, the spec's own example;
- `unit=` works on a back-reference but not on a formatter's text.

New problems:
- a prefixed year typed by name prints `kFALSE`;
- composing text-class functions moves the unit out of the markup or breaks it;
- the no-name, no-symbol and `lang` errors still come and go with the data under a ladder;
- under `en-US` a prefixed tonne is named "megametric ton".

Count: 5 silent wrong output (findings 1–4 and 8), 2 wrong error (5, 7), 1 contract mismatch (6),
1 wording (9).

## Findings

### 1. A prefixed year typed by name prints the symbol `kFALSE`

Severity: silent wrong output.

- `fmt_num(u(3, kiloyear))` gives `3~kFALSE`. The same happens with:
  - `u(3, megayear)`, which gives `3~MFALSE`;
  - `u(3, gigayear)`, which gives `3~GFALSE`;
  - `u(3, kiloyears)`, which gives `3~kFALSE`;
  - `u(3, "m/kiloyear")`, which gives `3~m/kFALSE`;
  - `fmt_unit("kiloyear")`, which gives `kFALSE`;
  - `fmt_num(u(3000, year), unit = "year|kiloyear")` and `unit = "kiloyear"`, which give
    `3~kFALSE`;
  - `fmt_num(u(3, Myr), unit = "kiloyear")`, which gives `3,000~kFALSE`;
  - `ws('`r u(3, megayear)`{.num}')`, which gives `3~MFALSE`.
- In the dictionary, `k: {value: 2000, type: quantity, unit: year, display: kiloyear, ...}` prints
  `2~kFALSE`, and `dict_glossary()` writes `` `k` (2 kFALSE) ``. A `unit: kiloyear` entry
  gives `` `age` (3 kFALSE) ``. There is no error or warning.
- Expected: 4.4.8 says a prefixed unit of a row with no symbol prints its symbol (`kyr`, as
  `u(3, kyr)` prints `3~kyr`), and a token typed as a name prints its unit's symbol. The name
  forms are right: `fmt_word(u(3, kiloyear))` gives `three~kiloyears`.
- Likely cause: `tok_symbol()` in `R/unit-names.R`. The shipped row `yr` has `symbol = FALSE`.
  For a prefixed token the early return (`is.na(r$pre)`) is skipped. For a token typed as a name,
  `sym <- S$symbol %||% db$v$symbol[r$row]` then yields `FALSE`, `nzchar(FALSE)` is `TRUE`, and
  `paste0(prefix, FALSE)` gives `kFALSE`.

### 2. The glossary still swallows the paragraph after its chunk (2c #5 not fixed)

Severity: silent wrong output.

- This is the original reproduction. `dict.yml` holds
  `start: {value: 2.5, type: quantity, unit: km, definition: "Start distance."}`. The `.Rmd`
  has a chunk ` ```{r} ` / `dict_glossary()` / ` ``` `, then `After.` on the next line.
  `rmarkdown::render(..., html_fragment)` gives:
  `<dt><code>start</code> (2.5 km)</dt><dd>Start distance. After.</dd>`
- The intermediate `.knit.md` has no blank line: `":   Start distance."`, `"After."`.
  `knitr::knit()` gives the same, and with `echo=FALSE` too.
- Expected: ruling 2c-5 and 4.7.1, "The string starts and ends with a blank line, so that the
  text above and below the chunk stays out of the list."
- Likely cause: `dict_glossary()` (`R/dict-tools.R`) ends its `asis_output()` with `"\n\n"`,
  but knitr trims trailing newlines from chunk output, so the blank line never reaches the
  document. The regression test (`test-review-2c.R`, "#5") checks only `endsWith(s, "\n\n")` on
  the string and never knits.

### 3. `.cap` still turns a unit symbol into another unit when the text passes through a text class or `[`

Severity: silent wrong output (the 2f #7 fix covers the direct call only).

- `fmt_cap(fmt_strong(fmt_unit(u(1, mL))))` gives `**ML**`, which is megalitres. Other routes
  do the same:
  - `fmt_cap(fmt_em(fmt_unit(u(1, mg/L))))` gives `*Mg/L*`;
  - `` ws('`r fmt_strong(fmt_unit(u(1, mL)))`{.cap}') `` gives `**ML**`;
  - `fmt_cap(fmt_unit(u(1, mL))[1])` gives `ML`, and so do `fmt_cap(rev(fmt_unit(u(1, mL))))`
    and `fmt_cap(c(fmt_unit(u(1, mL))))`.
- Controls that are right:
  - `fmt_cap(fmt_unit(u(1, mL)))` gives `mL`;
  - `` `r fmt_unit(u(1, mL))`{.strong .cap} `` gives `**mL**`.
- Expected: 1.4.20, "`.cap` never changes a unit's symbol". The help says that `fmt_unit()`
  returns a text "so `fmt_cap()` works on it".
- Likely cause: the symbol flag (`attr(, "is_symbol")`, read as `keep_case` in
  `apply_formatters()`, `R/format.R`) is not carried into the `weft_text` that a text-stage
  function returns. `` `[.weft_text` `` (`R/units.R`) drops it too, because a `fmt_unit()` text
  has no `unit` attribute and takes the `unclass_text()` path.

### 4. Text-class functions on a quantity's text move the unit out of the markup, or break it

Severity: silent wrong output (markup).

| Call | Output | Pandoc reads it as |
|---|---|---|
| `fmt_strong(fmt_num(u(3, m)))` (control) | `**3~m**` | right |
| `fmt_em(fmt_strong(fmt_num(u(3, m))))` | `***3**~m*` | *(**3** m)*: the bold no longer covers the unit |
| `fmt_strong(fmt_strong(fmt_num(u(3, m))))` | `****3**~m**` | the text "****3", then **m** in bold |
| `fmt_cap(fmt_strong(fmt_word(u(3, m))))` | `**Three**~metres` | |
| `fmt_cap(fmt_strong(fmt_num(u(3, m))))` | `**3**~m` | `.cap` alone moves the unit out |
| `fmt_em(fmt_strong(fmt_num(u(7, pH))))` | `*pH~**7***` | |
| `[# was \| # were]{n="fmt_strong(fmt_num(x))" .em}` | `***3~m** were*` | |

- The same classes written in one construct are right: `` `r x`{.strong .em} `` gives
  `***3~m***`.
- Expected: 4.4.8, "A quantity with a text class, `.strong` for one, keeps its unit inside the
  markup (`**3 m**`)". The rule that a collapse puts the unit after the closing markup is 2b's
  ruling for collapses, not for a text class on a text class.
- Likely cause: `apply_formatters()` (`R/format.R`). For a `weft_text` that carries a unit,
  `strip_unit()` cuts the unit out from inside the markup (`**3 m**` becomes `**3**`), then
  `add_unit()` puts it back after the old markup, before `text_stage()` wraps the result.

### 5. Under a ladder, the no-name, no-symbol and `lang` errors still come and go with the data

Severity: wrong error (data-dependent). The 2h #4 fix covers only the whole-number case.

- `_weft.yml` `units: {zzl: {is: 1 L}}` (a project unit with no name):
  - `` `r u(500, mL)`{.uname unit="mL|zzl"} `` gives `500~millilitres`;
  - the same construct on `u(3000, mL)` gives the value error "The unit `zzl` has no name to
    print". `.word` and `.count` do the same (`500~mL`, then the error).
- `_weft.yml` `unit_form: symbol`:
  - `` `r u(5, year)`{.word unit="yr|kyr"} `` gives `five~years`;
  - on `u(3000, year)` it gives "`.word` cannot print a quantity under `unit_form: symbol`".
- Front matter `lang: fr`:
  - `` `r u(5, year)`{unit="yr|kyr"} `` gives `<<weft: value error>>` (the unit has no symbol,
    and a name is English);
  - on `u(3000, year)` it gives `3~kyr`.
- `units: {sites: {is: base, name: site, symbol: false}}`:
  - `` `r u(5, sites)`{.word unit="sites|ksites"} `` gives `five~sites`;
  - on 3000 it gives the no-name error for `ksites`.
- Expected:
  - 4.4.19, "It is judged on the classes, not on the data … Neither error comes and goes with
    the data";
  - 4.4.23, "Every rung is checked against the quantity, whichever rung is picked, so that an
    error does not come and go with the data".
- Likely cause: `convert_unit()` / `convert_one()` (`R/units.R`) check each rung only for
  parsing, refusal, conversion, inversion and twins. The name check (`unit_name_text()` at the
  "judged on the classes" block of `apply_formatters()`), the symbol-form check and
  `symbol_needs_name()` run later, on the picked unit only.

### 6. A unit with no numerator, written as a quotient, still prints `1/…`

Severity: contract mismatch (silent). The 2b ruling c fix covers `m^-3` input only.

- Wrong:
  - `fmt_num(u(2, "1/m^3"))` gives `2~1/m^3^`; this is the spec's own example;
  - `fmt_num(u(2, "1/s"))` gives `2~1/s`;
  - `fmt_num(u(2, Hz), unit = "1/s")` gives `2~1/s`;
  - `fmt_num(u(2000, "Bq/L"), unit = "1/s/L")` gives `2,000~1/(s·L)`;
  - `fmt_unit("1/s")` gives `1/s`.
- Right: `fmt_num(u(2, "m^-3"))` gives `2~m^−3^`, and `fmt_unit("s-1")` gives `s^−1^`.
- Expected: 4.4.8 and ruling 2b-c: "a unit with no numerator is written with negative powers
  (`m^−3^`), not '1/m^3^'". "2 1/s" reads as "21/s".
- The name form is right (`per cubic metre`). The no-name error for `m^-3` tells the author to
  write `1/m^3`, which then prints the symbol this rule forbids.
- Likely cause: `unit_symbol_text()` (`R/unit-names.R`) calls
  `as.character(un2, neg_power = !length(un$numerator))`. `units` stores `"1/s"` with
  numerator `"1"`, so the length is 1 and the quotient is kept. The test of the fix
  (`test-review-2b.R`, "#c") uses only `m^-3` and `s^-1`.

### 7. `unit=` on a span governed by a formatter's text is an error

Severity: wrong error (contract mismatch). This is a route that the 2f #2 fix did not reach.

- With `x <- u(1500, m)`, these give "`unit = km` needs a quantity (see u()); the value is of
  class weft_text" (the ladder cases name the ladder):
  - `[# x | # xs]{n="fmt_num(x)" unit="km"}`;
  - `[# x | # xs]{n="fmt_num(x)" unit="m|km"}`;
  - `[up # | down #]{sign="fmt_num(u(-3, m))" unit="cm"}`;
  - `[none | # was | # were]{list="fmt_num(u(c(1500, 2500), m))" unit="km"}`;
  - `` `r fmt_num(x)`{unit="m|km"} ``.
- Under the same governor, `.word`, `.uname`, `digits` and `.nounit` all work, and so does
  `unit=` through a back-reference (`[# x | # xs]{n="#b" unit="km"}` gives `1.5~km xs`).
- `fmt_num(fmt_num(x), unit = "km")` fails the same way.
- Expected: 4.4.4, "a back-reference and a formatter's text keep the quantity, number and unit,
  so `.word`, `digits`, `.uname`, `.nounit` and `unit=` on the span act on `#` as on the quantity
  itself".
- Likely cause: `apply_formatters()` (`R/format.R`) calls `convert_unit()` first. That function
  refuses anything that is not a `units` object (`R/units.R`, top of `convert_unit()`) before the
  `weft_text` branch takes the quantity's `units` and raw numbers.

### 8. Under `lang: en-US` a prefixed tonne is named "megametric ton"

Severity: silent wrong output (a word).

- Front matter `lang: en-US`:
  - `` `r u(1, Mt)`{.word} `` gives `one~megametric ton`;
  - `` `r u(3, Mt)`{.uname} `` gives `3~megametric tons`.
- With no `lang` the output is `one~megatonne`, which is right.
- Expected: 4.4.16, "A prefix goes before the plural". The shipped en-US name "metric ton" is
  two words, so prefixing the first gives no English word. "megaton" or "megatonne" would be
  English.
- Likely cause: `tok_name()` (`R/unit-names.R`) runs `paste0(prefix_name, sg)` whatever the
  name is. The shipped table's `t` row has `us = "metric ton"`.

### 9. Advice that cannot be followed

Severity: wording.

- `units: {hdg: {is: 1 degree}}` gives "`is` `1 degree` is the unit the units package already
  writes `°` …; give a factor (`2 1 degree`), or use `°`". `ud_install_problem()`
  (`R/unit-defaults.R`) pastes "2 " before a definition that already has its number.
- In the dictionary, `display: "m||km"`, `display: "|"` and `display: [m, m]` give "write the
  ladder in a `unit` key …, such as `unit="m||km"`" (`unit="|"`, `unit="m|m"`). Each is quoted
  back as a ladder that is itself a construct error (an empty or repeated rung). The message is
  built in `R/dict.R` from the written ladder.

## Earlier findings re-run

| Finding | Re-run | Holds? |
|---|---|---|
| 2h #1 `.nounit` with a ladder | `fmt_num(u(400,m), unit="m\|km", unit_form="none")`; value, `n`, `sign` spans | Holds: value error on every route |
| 2h #2 `display:` ladder | `display: m\|km`, `[km, m]`, `[m\|km]`, `[m\|km, mm]` | Holds: each is a `read_dict()` problem |
| 2h #3 offset rungs | `degC\|K`, `degF\|degC`, `K\|mK` on °C, `degC\|kK` on K, `celsius\|K` | Holds. A compound with an offset unit (`degC/m\|degC/km`) is allowed, as it should be |
| 2h #4 `.word` with a ladder | 1500, 2000, 1499.6 m; `.count`, `.and`, `n` spans, `sigfig`, `digits` | Holds for the whole-number case. A sibling is still open (finding 5) |
| 2h #5 vector rule | all four reproductions, plus `c(0.04, 0.06, 5e6)` | Holds |
| 2h #6 gap | `mm\|km` at 5 to 960 m, negatives, `.range`, `.and` | Holds (149 m gives `149,000~mm`) |
| 2h #7 project `digits` | `digits: 0`, 999.6 m under `m\|km` gives `1~km` | As now specified (the determinism clause names the settings) |
| 2h #8 `plural()` | `plural(fmt_num(x, unit="m\|km"), …)` gives `was` | Holds as ruled |
| 2h #9 `unit_picked` | NA vector, failed `.word`, `unit="m\|kg"` | Holds: `NA` for each failure |
| 2h #10, #11, #12 messages | the listed inputs | Hold (rule cited once, rung named once, both forms named) |
| 2g #1 failed read leaves a token | `zzq` defined as `1 zzr`, `1 gal`, `1 NTU`, `degC`, `mi/h`, `1 Ma`, `1 pH` | Holds: nothing is left installed, and a later good read installs it |
| 2g #3 project name over a default row | `pH`, `ka`, `Ma` | Holds |
| 2g #5 `is:` on a prefix key | `km`, `mL`, `kft`, `Bags`, `BAG`, a foreign `ftn` | Holds |
| 2g #10 unit before the number with a spelled number | `.no`, `.word`, `space: false`, a `$` row with negatives and a sign span | Holds |
| 2g #11 `/100 mL` | `/ u(1, d)` gives `CFU/(100·d·mL)`; `* u(100, mL)` is a value error; the no-break space is present | Holds as ruled |
| 2g #15 `units_options` | `auto_convert_names_to_symbols = FALSE` before the first use | Holds |
| 2g #16 trap advice | `ca`, `daa`, `fmt_unit("kph")` | Holds |
| 2f #2 `#` through a formatter's text with a class | `.word`, `.uname`, `digits`, `.nounit` | Holds; `unit=` does not (finding 7) |
| 2f #4 collapse over spelled numbers | `fmt_and(fmt_word(...))` with `auto` and with `symbol` | Holds |
| 2f #5 plural-only prefixed row | `km/h`, `ug/L`, `km^2`, `km*h` | Holds |
| 2f #6 `.range` decimals with a unit class | `.uname`, `.nounit`, `.num`, `unit=`, ladder, `n` span | Holds |
| 2f #7 `.cap` on a symbol | the direct call | Holds for the direct call only (finding 3) |
| 2f #11 `space: false` on a name | `sites`, `yr`, `.range`, `glue_vec`, `.pairs` | Holds |
| 2f #3, 2b #1 PDF glyphs | pdflatex and xelatex render of −, `m^−3^`, µg, Ω, ′, ″, °C, `kg·m`, ×, `pH` range | Holds |
| 2c #5 glossary and the next paragraph | the original `.Rmd` | **Does not hold** (finding 2) |
| 2b c negative powers | `m^-3` and `s^-1` | Holds for those inputs; `1/m^3` and `1/s` do not (finding 6) |
| 2b #3, #9, #10 | `plural()` with `^`, brackets, `CFU/100 mL`, a ladder; a collapse over `.strong`; subsetting | Hold |
| 2a #1, #6, #7 | a knit after a knit with a dictionary; a failed read with an unknown unit; two reads `identical()` | Hold |
| Registration (4.4.21) | first use, `si` read, `weft` read, project `gal`/`ppth`/`mt`/base rows, unload | As documented: restored on unload, base rows kept |

## Questions for the author

These are consistent with the contract but look unwise. Each one was reproduced.

a. **Hz to rpm converts by 2π.**
   - `fmt_num(u(2000, Hz), unit = "rpm")` gives `19,098.6~rpm`. 2,000 cycles a second is
     120,000 rpm.
   - A dictionary entry `{unit: Hz, display: rpm, value: 2}` reads with no problem and prints
     `19.1~rpm`. `Bq` to `rpm` converts too.
   - `units` reads a hertz as a radian per second. This is the same kind of fault as the twins of
     4.4.14, but it is outside the list.

b. **`kt` is a knot.**
   - `u(3, kt)` prints `3~kt`. `.uname` gives the no-name error, whose advice is to add
     `kt: {name: …}`.
   - An author who follows the advice and writes `kt: {name: kilotonne}` gets `5~kilotonnes`
     for 5 knots, and `` {unit="km/h"} `` gives `9.3~km/h`.
   - `kt: {is: 1000 t}` is refused ("a unit of the units database"), so a project cannot fix it.
     `mt` is on the misread list, and `kt` is the commoner tonnage abbreviation.

c. **The 1e-9 zero rule applies to quantities in their base unit.**
   - `fmt_num(u(5e-10, g))` gives `0~g` with no warning. So does `u(5e-10, "mol/L")`.
   - `fmt_range(u(c(0, 5e-10), g))` gives `0~g`.
   - `u(c(5e-10, 2e-9), "mol/L")` warns only for the second value.
   - With `sigfig = 2` the same value prints `0.00000000050~g`.
   - 1.4.13 aims at floating-point noise in plain numbers, but here it hides a stipulated
     0.5 ng.

d. **A ladder can collapse a range.** `fmt_range(u(c(999.6, 1000.4), m), unit = "m|km")` gives
   `1.0~km`, because both ends print "1.0", while `unit = "m"` gives `999.6–1,000.4~m`.

e. **A glossary value can print as zero.** For `dose: {value: 2, unit: mSv, display: Sv}`,
   `dict_glossary()` prints `` `dose` (0.0 Sv) ``, with a warning that suggests `unit = "mSv"`.
   The glossary has no way to take that advice. The stipulated value is lost from the glossary.

f. **`.sci` with a ladder** picks by the `.num` number and prints `1.5 × 10^0^~km` (2h #13,
   unchanged).

g. **`.a` with a unit name:** `` `r u(18, m)`{.a .word} `` gives `an eighteen~metres`, and
   `{.a .uname unit="m|km"}` on 8000 m gives `an 8~kilometres`.

h. **A pH difference prints as a pH value.** `u(7, pH) - u(6.5, pH)` prints `pH~0.5`, and 4.4.22
   prints a change as "pH −0.4". Both read as an absolute pH.

## Rulings (orchestrator, 12 November 2026)

Findings 1 to 9 are accepted as stated, with these particulars:

- **1.** A row whose `symbol` is `false` has no symbol in any form: a
  prefixed token of it prints by name where a name is allowed and is
  the no-symbol value error where it is not; `FALSE` is never pasted.
- **2.** The test is a real knit through Pandoc: the paragraph after
  the glossary chunk is its own paragraph. How the text is made to
  survive knitr's trimming is the fixer's choice.
- **3, 4.** A unit's symbol is never re-cased and a quantity's unit
  stays inside the markup on every route: a text class on a text
  class, `.cap` after a text class, and after `[`. Text classes nest
  outside-in (`fmt_em(fmt_strong(x))` is `***3~m***`); the same class
  twice is applied once.
- **5.** Every check that 4.4.19 and 4.4.23 say is judged on the
  classes is made on every rung of the ladder before the pick: a name
  for each rung under `.uname`/`.word`/`.count`, `unit_form: symbol`
  with a spelled number, and the `lang` rule.
- **6.** A unit with no numerator prints with negative powers however
  it was typed (`1/s` prints `s^-1^` with U+2212). The no-name advice
  no longer suggests `1/m^3`.
- **7.** `unit=` (one unit or a ladder) acts on a formatter's text that
  carries a quantity, on every route 4.4.4 lists.
- **8.** A prefix is joined only to a one-word name. Where the
  language's name has more than one word (en-US "metric ton"), the
  prefixed unit takes the default name ("megatonne").
- **9.** Both messages corrected: no factor pasted before a definition
  that has one; a `display:` that is not a well-formed ladder is not
  quoted back as one.

Questions:

- **a.** Converting between a frequency or activity unit (`Hz`, `Bq`
  and their prefixes) and a unit of angle per time (`rpm`, `rad/s`,
  `degree/s`) is a value error and a `read_dict()` problem, as the
  twins of 4.4.14 are.
- **b.** `kt` joins `mt` on the misread list (refused, with advice
  naming `knot` for the knot and a project unit for the kilotonne;
  the units database has no `kn`).
- **c.** The 1e-9 snap of 1.4.13 does not apply to a quantity: a small
  quantity goes through the ordinary zero rule (4.4.13), which prints
  it as zero with the warning and its advice.
- **e.** In the glossary an entry whose `display:` unit prints its
  value as zero is printed in the entry's own `unit`, with no warning.
- **f.** `.sci` with a ladder of more than one rung is a value error.
- **d, g, h.** Left as built and filed in `dev/open-findings.md` for
  Robin: a ladder can collapse a range to one number; `.a` with a
  spelled quantity ("an eighteen metres"); a pH difference prints as a
  pH.
