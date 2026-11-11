# Package 2f — unit names and unit settings (Robin, 12 November 2026)

Written before any test or code. Robin approved the plan; this note decides
the details. It builds on 2b (`dev/design-2.md` §3 and its rulings) and the
`unit` key (4.4.14). It settles R3 and R6 of `dev/design-2.md` §5 and the
`dev/decisions.md` item on a collapsed list that ends in a word.
`PACKAGE-SCOPING.md` is amended in the commit that builds this. `␣` is
U+00A0, the no-break space; every other space is U+0020.

## Scope and rules touched

| Rules | Change |
|---|---|
| 4.4.2–4.4.4, 4.4.13 | a spelled number, and "no", take the unit's name; a collapse puts the unit after its last item whatever that item is |
| 4.4.7, 4.4.8 | `units:` keys register; a unit typed as a name prints its symbol; no space before `%`, `°`, `′`, `″` (R3); project symbols (R6) |
| 1.2.5, 1.4.2, 1.4.3, 1.4.7, 1.6.8, 5.3.1, 5.3.2 | three unit classes |
| 3.4.4, 4.2.1, 9.1.2, 9.1.5, 9.1.6 | `weft_text` attributes; `display:`; `unit_form`, `units:` |
| new | 1.4.18, 3.4.8, 3.4.9, 4.2.7, 4.4.15–4.4.19, 9.1.7 |

Out of scope: years (`weft_year` is untouched); the adjective ("a 5-metre
core" is written by hand; `.a .word` on `u(5, m)` prints "a five␣metres");
names in a language other than English; a second pronoun.

## The contract

### Forms

A unit prints as its **symbol** ("5␣m") or its **name** ("five␣metres").
The setting nearest the use wins:

| Level | The unit shown | The form | A unit's name, plural, symbol, space |
|---|---|---|---|
| the use | `unit="km"`, `unit =` (4.4.14) | `.uname`, `.usym`, `.nounit`; `unit_form =` | — |
| the dictionary | `display:`, applied when read | — | — |
| the document | — | `weft: unit_form:` | `weft: units:` |
| the project | — | `_weft.yml` `unit_form:` | `_weft.yml` `units:` |
| weft | the value's own | `auto` | shipped table, then the units database |

| Form in force | element in digits | element spelled by a wording class, or "no" |
|---|---|---|
| `auto` | symbol | name |
| `name` (`.uname`) | name | name |
| `symbol` (`.usym`) | symbol | value error |
| none (`.nounit`) | nothing | nothing |

- Every element carries its unit, digits or words. Placement is 4.4.3's:
  once after the last item under `.and`, `.or`, `.range`, `trunc` and
  `glue_vec()`; with every element under `.pairs`, `.ul`, `.ol`, `.dl` and
  in an uncollapsed vector. The unit after the last item takes that item's
  form: `u(c(200, 5), m)` under `.word .and` is "200 and five␣metres"
  (replaces D24).
- **Judged on the classes.** With `.no`, `.word`, `.count` or a project
  wording formatter on a quantity a name may print, so under `auto` the unit
  must have a name even if every number prints in digits, and under `symbol`
  it is a value error. Neither error comes and goes with the data.
- Number and unit are joined by `␣`, for a name too, except before a symbol
  whose space is off. Spaces inside a name are ordinary.
- A unit class, or `unit_form` other than `"auto"`, on a value with no unit
  (a number, a ratio) is a value error. Settings apply to anything.
- A unit class implies `.num` when no number class is given (1.4.7); on an
  `n`, `sign` or `list` span it acts on `#`; on a text span with no key it
  passes through (1.1.9).
- From the source, construct errors: two unit classes; `.usym` with `.no`,
  `.word` or `.count`; a unit class on an `if` or `cite` span; `.uname`
  under a `lang` that is not English.
- `.pct` is not a unit: `unit_form: name` leaves its "%" alone.

### Plurals

A symbol never changes. A name is singular only when its number prints "1"
or "one" (1 exactly, no decimals, relation `=`: the `n`-arm rule, 1.5.9):
"0.5␣metres", "0␣metres", "1.0␣metres", "−1␣metres". In a collapse it is
singular only when exactly one number prints and it is "1" or "one": "3, 5
and 1␣metres", "1␣metre and 2 others" (`trunc="1"`), `.range` with both ends
"1" gives "1␣metre". `.pairs`, list classes and an uncollapsed vector judge
each element; `#` in a `sign` span judges the magnitude.

The plural is the project's `plural`, else the shipped one, else the
database's `name_plural` (`_` as a space), else the English rule on the last
word: "es" after s, x, z, ch, sh; consonant + "y" to "ies"; else "s". A
prefix goes before the plural ("milligrams", "millidegrees Celsius").

### Names

`units` keeps each token as written: `u(10, year)` holds `year`,
`u(2, kilometre)` `kilometre`, `u(5, metre)` `m`, `u(150, "CFU/100 mL")`
`CFU` over `100` and `mL`. weft resolves a token by the first of:

1. a `units:` key that resolves (by 2–5) to the same unit;
2. the shipped table below;
3. a row of `units::valid_udunits()` with the token as its symbol, a symbol
   alias, singular or plural name or alias, or as the English plural of its
   singular name or an alias (`years`);
4. a prefix of `units::valid_udunits_prefixes()` and a rest that 2–3
   resolve: prefix symbol (`u` counts as `µ`) before a symbol, prefix name
   before a name, longest prefix first (`mL`, `kilometers`, `ug`, `dam`);
5. else the token is unknown: its symbol is itself, and it has no name.

So `min` is a minute, `Pa` a pascal, `ha` a hectare. Two tokens are the same
unit when they resolve to the same prefix and row, or are the same unknown
token: `metre` and `m` are; `year`, `years` and `yr` are; `L` and `dm^3` are
not.

A token's name is the project's `name`, else the shipped name, else the
database's singular name with `_` as a space, a prefix name joined with
nothing between ("kilometre"). Under `lang` `en-US` (or `en_US`, any case)
the en-US column applies; under any other English `lang`, or none, the
other, with the prefix "deca" for "deka".

Shipped table, in full (blank: the database's):

| Unit | Name | en-US | Plural | Symbol | Space |
|---|---|---|---|---|---|
| `m` / `L` / `t` | metre / litre / tonne | meter / liter / metric ton | | | |
| `ha`, `hectare` | hectare | | | `ha` | |
| `yr`, `year` | year | | | none | |
| `bar` | bar | | | `bar` | |
| `ft` | foot | | feet | | |
| `in` / `mi` / `lb` | inch / mile / pound | | | | |
| `°` | degree | | | | off |
| `′`, `″` | | | | | off |
| `%` | per cent | percent | as singular | | off |
| `Hz`, `lx`, `S` | | | as singular | | |

**Compounds.** A power of 2 or 3 is "square"/"cubic" before the name of a
length (a unit that converts to `m`), "squared"/"cubed" after any other.
Numerator factors joined by a space, then " per " and the denominator's
joined by a space; no numerator gives "per …". Only the last numerator
factor takes the plural. A whole-unit `units:` key wins over its factors.

**No name** when a factor is unknown with no `units:` entry, when the unit
holds a number (`100`), or when a power is not 1, 2 or 3. weft never guesses.

**Symbol text** is 4.4.8's with three changes. A token typed as a name prints
its unit's symbol (`kilometre` is `km`, `microgram` `µg`); one typed as a
symbol prints as typed (`ug`). A unit with no symbol prints its name, by the
plural rule in a numerator and singular in a denominator ("10␣years",
"5␣kg/year"). A `units:` `symbol:` replaces its unit's text, whole or
factor, as written.

**Space**: none before a unit whose whole symbol is `%`, `°`, `′` or `″`
("35%", "45°"); `␣` before every other symbol ("20␣°C") and every name. A
`units:` `space:` sets it per unit; a compound takes `␣` unless its own key
says otherwise. **Escaping**: what weft derives is escaped as 4.4.8 says;
`units:` text is markdown, printed as written.

### Functions

- `unit_form = NULL` is added, last, to `fmt_num()`, `fmt_sci()`,
  `fmt_range()`, `fmt_no()`, `fmt_word()`, `fmt_count()`, `fmt_ord()`,
  `fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`, `fmt_ol()`,
  `fmt_dl()`. Values `"auto"`, `"name"`, `"symbol"`, `"none"`. `NULL` is the
  form in force for a quantity, and each element's printed form for a
  `weft_text`. Anything else, or `"symbol"` on `fmt_no()`, `fmt_word()`,
  `fmt_count()`, is a `weft_construct_error`. `plural()` takes none:
  `plural(fmt_num(x, unit_form = "name"), …)`.
- `fmt_unit(x, unit_form = NULL, unit = NULL)`, exported and attached
  (2.1.8), prints the unit alone, for a heading: a `weft_text` of length one
  with no record and no unit attributes (so `fmt_cap()` works on it). `x` is
  a quantity of any length (`NA` allowed; no number prints) or one string
  read as `u()` reads a unit. `unit` converts first. `auto` and `symbol`
  print the symbol text, `name` the name; `"none"` is a
  `weft_construct_error`. Plural unless `x` has length one and its number
  prints "1" under `.num`; a string takes the plural. No `.unit` class.

### The `weft_text`

`unit` (3.4.4) is present whenever a unit is in the text, in either form,
and holds the symbol text as printed for a plural number (`m`, `years`).
New: `unit_form`, as long as the text, `"symbol"`, `"name"` or `NA` per
element; `units`, the unit as `units::units()` gives it after conversion. A
number or wording class given such a text formats `raw` afresh in its own
form in force; a collapse with `unit_form = NULL` keeps each element's form:
`fmt_and(fmt_word(u(c(3, 5, 7), m)))` is "three, five and seven␣metres".
Text with no unit carries none of the three.

### Another `lang`

A name is words; a symbol is not. `.uname` is a construct error from the
source (1.6.8); `unit_form: name` a `weft_config_error` at knit
initialisation; `unit_form = "name"` on a function a `weft_construct_error`
when called; a unit with no symbol (`year`, `symbol: false`) a value error
where it would print. Wording classes are already errors there, so `auto`
never reaches a name.

### Expected output

Defaults unless the row says. "table" is the `sites` entry of the YAML below.

| Value | Construct or call | Prints |
|---|---|---|
| `u(5, m)` | `{.num}` / `{.word}` / `{.uname}` / `{.nounit}` | `5␣m` / `five␣metres` / `5␣metres` / `5` |
| `u(1, m)` | `{.word}` / `{.uname}` / `{.uname digits=1}` | `one␣metre` / `1␣metre` / `1.0␣metres` |
| `u(0, m)` / `u(2, m)` | `{.no}` | `no␣metres` / `2␣m` |
| `u(0.04, m)` | `{.uname}` | `0.0␣metres`, the warned check (4.4.13) |
| `u(3, m)` | `{.word .nounit}` / `{.strong .word}` | `three` / `**three␣metres**` |
| `u(5, metre)` / `u(2, kilometre)` | `{.num}` | `5␣m` / `2␣km` |
| `u(5, mg/L)` | `{.uname}` / same, `lang: en-US` | `5␣milligrams per litre` / `5␣milligrams per liter` |
| `u(2, m^2)` / `u(1, m^3)` | `{.uname}` | `2␣square metres` / `1␣cubic metre` |
| `u(9.81, m/s^2)` / `u(1200, kg/m^3)` | `{.uname}` | `9.8␣metres per second squared` / `1,200␣kilograms per cubic metre` |
| `u(2, "1/m^3")` / `u(3, kW*h)` | `{.uname}` | `2␣per cubic metre` / `3␣kilowatt hours` |
| `u(10, year)` / `u(10, yr)` / `u(1, year)` | `{.num}` | `10␣years` / `10␣years` / `1␣year` |
| `u(10, year)` / `u(1, year)` | `{.word}` | `ten␣years` / `one␣year` |
| `u(5, d)` / `u(3, week)` / `u(2, ha)` | `{.num}` | `5␣d` / `3␣weeks` / `2␣ha` |
| `u(5, ft)` / `u(1, ft)` / `u(20, Hz)` | `{.uname}` | `5␣feet` / `1␣foot` / `20␣hertz` |
| `u(35, "%")` / `u(45, "°")` / `u(20, degC)` | `{.num}` | `35%` / `45°` / `20␣°C` |
| `u(5, "%")` | `{.word}` / same, `lang: en-US` | `five␣per cent` / `five␣percent` |
| `u(20, degC)` / `u(2, t)` | `{.word}` / `{.uname}` | `twenty␣degrees Celsius` / `2␣tonnes` |
| `u(c(3, 5, 7), m)` | `{.and}` / `{.word .and}` / `{.uname .and}` | `3, 5 and 7␣m` / `three, five and seven␣metres` / `3, 5 and 7␣metres` |
| `u(c(3, 5), m)` / `u(c(1, 1), m)` | `{.range .uname}` | `3–5␣metres` / `1␣metre` |
| `u(c(3, 5, 7, 9), m)` / `u(c(1, 5, 7), m)` | `{.and .uname}`, `trunc=2` / `trunc=1` | `3, 5␣metres and 2 others` / `1␣metre and 2 others` |
| `u(c(a = 1, b = 3), m)` | `{.pairs .word}` | `a (one␣metre) and b (three␣metres)` |
| `u(c(3, 12), m)` | `{.count}` | `three␣metres, 12␣m` |
| `u(6, m) / u(3, m)` | `{.word}` / `{.uname}` | `two` / value error |
| `u(3, PSU)` / `u(12, PSU)` / `u(3, PSU)` | `{.word}` / `{.count}` / `{.num}` | value error naming `PSU` / the same / `3␣PSU` |
| `u(150, "CFU/100 mL")` | `{.num}` / `{.uname}` | `150␣CFU/(100mL)` / value error |
| `u(1, sites)` / `u(12, sites)` / `u(3, sites)` | table; `{.num}` / `{.num}` / `{.count}` | `1␣site` / `12␣sites` / `three␣sites` |
| `u(5, sites) / u(2, ha)` | table; `{.num}` / `{.uname}` | `2.5␣sites/ha` / `2.5␣sites per hectare` |
| `u(5, m)` | `unit_form: name`; `{.num}` / `{.usym}` | `5␣metres` / `5␣m` |
| `u(3, m)` | `unit_form: symbol`; `{.word}` / `{.word .uname}` | value error / `three␣metres` |
| `u(5, m)` / `u(10, year)` | `lang: de`; `{.num}` | `5␣m` / value error |
| `u(5, m)` / `u(1, m)` | `[# was \| # were]{n=… .word}` | `five␣metres were` / `one␣metre was` |
| `u(3, m)` / `u(-1, m)` | `[# long]{n=… .count}` / `[rose by # \| fell by #]{sign=… .uname}` | `three␣metres long` / `fell by 1␣metre` |
| `u(c(3, 5), m)` | `[none \| # was \| # were]{list=… .word}` | `three and five␣metres were` |
| `u(1, year)` / `u(5, m)` | `plural(x, "# ago")` / `fmt_num(fmt_word(x))` | `1␣year ago` / `5␣m` |
| `u(c(3, 5), m)` | `fmt_and(fmt_num(x), unit_form = "name")` | `3 and 5␣metres` |
| `u(5, mg/L)` | `fmt_unit(x)` / `fmt_unit(x, unit_form = "name")` | `mg/L` / `milligrams per litre` |
| `u(1, m)` / `u(1.04, m)` / `"m^2"` | `fmt_unit(x, unit_form = "name")` | `metre` / `metres` / `square metres` |
| `u(10, year)` / `u(150, cm)` | `fmt_unit(x)` / `fmt_unit(x, unit = "m")` | `years` / `m` |

`attr(fmt_count(u(c(3, 12), m)), "unit_form")` is `c("name", "symbol")`.
Tests turn Pandoc's `\ ` into `␣` before comparing, as in 2b.

## Configuration and dictionary fields

```yaml
# _weft.yml
unit_form: auto            # auto (default), symbol or name
units:
  sites:
    name: site             # plural by the rule: "sites"
    symbol: false          # printed by name in every form: "1 site", "12 sites"
  PSU:
    name: practical salinity unit
  CFU/100 mL:
    name: colony-forming unit per 100 millilitres
    plural: colony-forming units per 100 millilitres
    symbol: CFU/100 mL     # not units' "CFU/(100mL)" (R6)
  d:
    symbol: false          # "5 days", not "5 d"
  "%":
    space: true            # SI's "35 %" (R3)
```

`unit_form` other than `auto`, `symbol`, `name` is a `weft_config_error`
(9.1.6). **`units:`** (9.1.7) maps a unit, written as `u()` takes one, to up
to four fields: `name`, `plural` (non-empty strings; `plural` alone
re-plurals the name weft finds), `symbol` (a non-empty string, or `false`),
`space` (`true`/`false`). When the configuration is read (9.1.3), before the
dictionary, each key's unparseable tokens are registered as 4.4.7 does, and
the table is checked. All problems are raised together as one
`weft_config_error` that stops the knit, in draft mode too: first line
`weft: <file>: N problem(s) in \`units:\``, then one line each, `<file>:
units: \`<key>\`: <what> (rule 9.1.7)`. Problems: `units` not a mapping; a
key that does not parse, parses only with a warning, or has a power that is
not whole; two keys for one unit; an entry that is not a mapping, or empty;
an unknown field (named, the four listed); a field of the wrong type;
`symbol: false` on a unit with no name. A read with problems registers
nothing. A document's `weft: units:` is checked alike, naming the document,
and its entry for a unit replaces the project's whole. After the read
`u(3, sites)` works with no dictionary.

**`display:`** (4.2.7), optional on a `type: quantity` entry, in `dict.yml`
and `dict_local`:

```yaml
reach_len:
  value: 2000
  type: quantity
  unit: m
  display: km
  definition: "Length of the surveyed reach."
```

The value is read in `unit` and converted to `display`: `dict$reach_len` is
`2 [km]`; `{.num}` prints "2␣km", `{.uname}` "2␣kilometres", `{unit="m"}`
"2,000␣m"; arithmetic, checks, `#`, `units::drop_units()` (2) and the
pipeline see km. Registered as `unit` is. Problems (4.2.6): `display` on
another type; one that does not parse; one `unit` does not convert to. The
`entries` attribute gains a `display` column (`NA` where absent); `print()`
shows the display unit. An entry has no form setting.

## Errors

All carry `weft_error`. A value error in a knit is a collected failure with a
marker (5.3.2); outside, it is raised.

| Class | When | The message says |
|---|---|---|
| `weft_value_error` | a name may print and the unit has none | the unit as `units` writes it and why (a factor with no name, a number, a power); to add it to `_weft.yml` under `units:`, with a YAML example keyed by it; or `.usym`, or `.nounit` (4.4.19) |
| `weft_value_error` | form `symbol` from a setting, a wording class on a quantity | the class; the form and where set; a spelled number takes the name; `.uname`, `.nounit`, or drop the class (4.4.15) |
| `weft_value_error` | a unit class or `unit_form` (not `"auto"`) on a value with no unit | the class or argument, the value's class or "no unit left" (1.4.18) |
| `weft_value_error` | a unit with no symbol under another `lang` | the unit, the `lang`, `symbol:` in `units:` (1.6.8) |
| `weft_value_error` / `weft_unit_error` | `fmt_unit()` given neither a quantity nor a string / a string `u()` refuses | as `u()` does (3.4.9) |
| `weft_construct_error`, source | two unit classes; `.usym` with `.no .word .count`; a unit class on `if` or `cite`; `.uname` under another `lang` | the classes, the rule (1.4.2, 1.4.18, 1.6.8) |
| `weft_construct_error`, call | a bad `unit_form`; `"symbol"` on `fmt_no/word/count()`; `"name"` under another `lang`; `fmt_unit(unit_form = "none")` | the argument and the allowed values |
| `weft_config_error` | a bad `unit_form`; `units:` problems; `unit_form: name` under another `lang` | as above (9.1.6, 9.1.7, 1.6.8) |
| `weft_dict_error` | a `display:` problem | a line among the dictionary's problems (4.2.6) |

## What the spec leaves open, decided here

| # | Gap | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| U1 | class names | `.name .symbol`; a key `form=`; `.uname .usym .nounit` | the last, one at-most-one group, not a stage | short like `.num`, `.ul`; `.name` would take a common class from pass-through | `R/format.R`, `R/scan.R` |
| U2 | "no" | no unit (2b); the name | "no␣metres" | "no" is a word | one line |
| U3 | when a missing name errors | when a name prints; when one may | when one may, by the classes | an error that waits for a small number reaches the reader first | one predicate |
| U4 | `symbol` with a spelled number | "five m"; the name; error | error | SI forbids "five m"; the name would make `symbol` equal `auto` | one branch |
| U5 | plural in a collapse | last number; length; numbers printed | singular only for one printed "1"/"one" | `trunc="1"` must read "1 metre and 2 others" | one function |
| U6 | "−1" | singular (CLDR); plural | plural | the `n`-arm rule, as Robin said | with `choose_arm_n()` |
| U7 | names | database only; shipped table first | shipped table, then database | the database has `international_foot`, `tropical_year`, `metric_ton`, US spellings first, and no invariant plurals | the table |
| U8 | spelling | one; by `lang` | `en-US` US; other English, or none, not | Robin's rule | the table |
| U9 | no symbol | print as typed ("10 year"); the name | the name | "10 years", as Robin asked; "3 weeks" | the table |
| U10 | day, hour, year | all names; all symbols | `d`, `h`, `min` symbols; `year` none | SI accepts d, h, min, not `yr` | the table |
| U11 | a unit typed as a name | as typed (2b); its symbol | its symbol | a symbol never changes | one function |
| U12 | powers | "square" always; "squared" always | by dimension; none above 3 | NIST SP 811 | one function |
| U13 | R3 | space always (SI, 2b); not before `%`, `°`, `′`, `″` | the latter, per unit settable | `.pct` prints "35%"; SI's angle exception; `°C` keeps the space | the table |
| U14 | R6 | on the entry; in `units:` | `units:`, whole or factor | it reaches derived values | `R/config.R` |
| U15 | `units:` text | escaped; markdown | markdown | configuration, not data; allows `m^3^` | one call |
| U16 | `units:` registers | no; yes | yes, at read | a key must parse to match. Cost: D16's | `R/config.R` |
| U17 | `units:` problems | warn (decision 9); error | error, collected | a misspelt `plurl` would be silent | `R/config.R` |
| U18 | `display:` | attribute used when printing; convert when read | convert when read | `units` keeps an attribute through `x * 2` but drops it in `c()`, `x[1]`, `mean()`, `y + x`. Cost: the pipeline sees the display unit | `R/dict.R` |
| U19 | attributes | `unit` holds the name; add attributes | `unit` keeps the symbol text; add `unit_form`, `units` | 3.4.4 and old tests keep their meaning | `R/format.R` |
| U20 | space before a name | ordinary; `␣` | `␣` | one join; "5 metres" should not break | a constant |
| U21 | `units:` in front matter | project only; merged | merged per unit | 9.1.1 | `R/config.R` |

## Spec amendments

- **1.2.5** a row for the unit classes; **1.4.2** two of them are an error;
  **1.4.3** three rows; **1.4.7** a unit class implies `.num`; **1.4.18
  (new)** the unit classes ("Forms").
- **1.6.8** add `.uname`, the name form from a setting or function, and a
  unit with no symbol; "a symbol is not words".
- **3.4.4** the attributes and the chain example ("three, five and seven
  metres"); **3.4.8 (new)** `unit_form =`; **3.4.9 (new)** `fmt_unit()`.
- **4.2.1** `display` on `quantity`; **4.2.7 (new)** `display:`.
- **4.4.2** rewritten (symbol after digits, name after a spelled number or
  "no", `.nounit`); **4.4.3** the last item's form, "200 and five metres";
  **4.4.4** `#` takes the name when a wording class made it a word, and
  "the name with digits is `.uname`, the number alone `.nounit`";
  **4.4.7** `units:` keys register; **4.4.8** the symbol text's changes and
  the space rule, replacing "for every unit"; **4.4.13** "0.0 metres".
- **4.4.15–4.4.19 (new)** forms and nearest setting; plurals; resolving and
  the shipped table; compounds; no name is a value error, judged on the
  classes, never guessed.
- **5.3.1** the four construct errors; **5.3.2** "five errors" become eight.
- **9.1.2** rows `unit_form`, `units`; **9.1.5** `unit_form: auto`, `units:
  {}`; **9.1.6** `unit_form`'s values; **9.1.7 (new)** the `units:` table.
- **§13** reasons for 4.4.2 (SI: symbol with numeral, name with word; weft
  prints both and the author types neither), 4.4.17 (the database's names
  are technical), 4.4.19 (an error must not wait for the data), 4.2.7 (U18),
  9.1.7 (R3, R6). `dev/decisions.md`: R3, R6 and the list-ending item move
  to "Made".

## Tests

Four new files; temporary projects and dictionaries as `test-config.R` and
`test-dict.R` make them (the shared `_dict/dict.yml` is unchanged); `lang` by
a rendered document's front matter with the existing helpers; registered
unit names new to the session.

- `test-unit-names.R`: via `fmt_unit()` and `{.uname}`: every shipped row,
  both spellings, database names with `_`, prefixes by symbol and name,
  exact before prefix, the same-unit rule, compounds, plural sources, each
  no-name case and its message.
- `test-unit-forms.R`: the expected-output table; each class and
  `unit_form =` on each listed function; plurals at 0, 0.5, 1, 1.0, −1 and in
  each collapse; `#` in `n`, `sign`, `list` spans and `plural()`; the zero
  rule; a ratio; the attributes and chains; every construct error.
- `test-unit-config.R`: `unit_form` and `units:` in `_weft.yml` and front
  matter, nearest wins, merging, `symbol:`, `space:`, the default spaces,
  registration, every `units:` problem in one error, `lang: en-US` and `de`.
- `test-dict-display.R`: reading and converting, its three problems, the
  `entries` column, `print()`, `{unit=}` over it, `drop_units()`.

Superseded, amended by the test-writer and listed in its report: in
`test-units-print.R`, "2b stage ii: an element turned into a word takes no
unit" (`fmt_word(u(3, m))` is "three␣metres", `fmt_no(u(0, m))`
"no␣metres", `fmt_count(u(3, sites))` a value error without a `units:`
entry), "2b chain" ("three␣metres"), "2b stage iii: when the last element is
a word" ("200 and five␣metres"), and the rendered `.count`, `.word`, `.no`
rows; in `test-review-2b.R`, "a wording class that turns # into a word
leaves the unit off" ("three␣metres long") and the `list` span over `sites`
with `.count` (a value error without an entry); any assertion on the columns
of `attr(dict, "entries")`. D24 and the rows of `dev/design-2.md` §3 that
print a spelled number without a unit are superseded.

## For Robin

Built as recommended until answered.

- **Q1 — class names** `.uname`, `.usym`, `.nounit` (U1). Alternatives
  `.name`/`.symbol`, or a key `form="name"`. Recommended: as built.
- **Q2 — `display:` converts when read** (U18), so targets and
  `drop_units()` see the display unit, and adding `display:` changes a
  target's value (its readers re-run). Applying it when printing works only
  while `units` keeps an attribute it drops in `c()` and `mean()`.
  Recommended: as built.
- **Q3 — "per cent" or "percent"** outside en-US. Recommended "per cent"
  (Australian Government Style Manual, British usage).
- **Q4 — "no metres"** for `.no` on a zero quantity, or "no" alone as in 2b.
  Recommended: "no metres".
- **Q5 — `d`, `h`, `min` as SI symbols** under `auto` ("5␣d"), while year,
  week and month print names. Alternative: ship `symbol: false` for them, so
  prose reads "5 days". Recommended: SI symbols; a project sets `false`.

## Rulings on the implementer's report

- **Two tests were wrong and are edited.** A collapse over elements in
  different forms prints the unit once, in the last item's form
  (`fmt_and(fmt_count(u(c(3, 12), m)))` is "three and 12 m"); the test
  expected a unit on each. A fixture wrote `name:` twice under one
  entry, which YAML refuses before weft reads it.
- A project `name` with no `plural` takes the English rule. Accepted.
- A project name holding " per " takes its plural before " per ".
  Accepted.
- `s^-2`, a negative power with no numerator, has no name; `1/s` is
  "per second". Accepted; a name asked for is the value error.
- Outside a knit the `units:` table of the last configuration read is
  used; `unit_form` is not carried over. Accepted.
- `fmt_unit()` on a string takes the plural. Accepted.
- **Open:** the `#` of a `sign` span built from a formatter's text keeps
  the unit text as printed and is not judged again for the singular; in
  `dev/open-findings.md`.
