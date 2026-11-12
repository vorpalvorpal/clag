# Package 2g — weft's default units (Robin, 12 November 2026)

Written before any test or code. Robin: "weft should probably carry a basic
default dictionary that overrides crazy units (like pH). Users can then
provide their own additions as needed", and "possibly there should be a
'units: si' option to use the units package instead of weft's defaults". This
replaces rule 4.4.20's refusals (2f rulings 9/e and b) and builds on
`dev/design-2f.md`. `PACKAGE-SCOPING.md` is amended in the commit that builds
it. `␣` is U+00A0. Every claim about `units` was run on `units` 1.0.0.

## Scope and rules touched

| Rules | Change |
|---|---|
| 4.4.20 | rewritten: weft keeps a unit's token; misreadings are defined by a default table; a short list is refused under `weft` only |
| 4.4.6, 4.4.7, 4.4.14, 4.4.17 | registering the defaults; twin conversions; resolution order |
| 3.4.4, 4.4.3, 4.4.4, 4.4.8 | a unit written before the number |
| 9.1.2, 9.1.5–9.1.7 | `unit_defaults:`; fields `is:`, `before:`; a `false` row |
| new | 3.4.10 `unit_defaults()`, 4.4.21 the table and modes, 4.4.22 `before` |

Out of scope: the 2f shipped name table (4.4.17) stays in R with its en-US
column; values made by `units::set_units()` outside weft; arithmetic between
twin units (`u(1, Sv) + u(1, Gy)`), which is `units`'s.

## Three faults, two fixes

1. **A token stored as another unit's symbol**: `Sv` as `Gy`, `Bq`/`Bd` as
   `Hz`, `VA` as `W`, `Mg` as `t`, `mt` as `kg` (also in `mt/d`), `ut` as `g`,
   `sievert` as `Gy`. `units` stores the symbol udunits maps to the parsed
   unit (option `auto_convert_names_to_symbols`); upstream says this is
   udunits's design (r-quantities/units #325). Reinstalling does not cure it:
   after `remove_unit("Sv"); install_unit("Sv", "1 J/kg")`, `u(1, Gy)` holds
   `Sv`; after the same for `Bq`, `Hz` and `hertz` hold `Bq`; upstream's
   `remove_unit(c("Hz", "Bq"))` leaves `Hz`, `kHz` unparseable. **Fix: weft
   keeps the token**, both modes, changing no database entry.
2. **A valid prefix parse of a common abbreviation**: `pH` picohenry, `mph`
   milliphot, `nmi` nanomile, `Ma`/`ka` mega-/kilo-are; and `gal`, the
   galileo's name (#204). **Fix: the default table redefines them** under
   `unit_defaults: weft`; under `si` they mean what `units` reads.
3. **Units missing or unnamed**: NTU, PSU, CFU, MPN unknown; `ppm`, `ppb`
   with empty names; `CFU/100 mL` printed `CFU/(100mL)`. **Fix: default rows
   that register or name, changing no reading**, applied in both modes.

Measured: a second `install_unit("pH")` errors ("already maps"), a second
identical `install_unit("mph", "1 mi/h")` is silent; `remove_unit("pH")`
restores the picohenry; `gal` needs `remove_unit(name = "gal")` first, and
`install_unit(name = "gal", def = "cm/s^2")` restores it; `install_unit(sym,
def)` errors "Unit already maps to" when an installed symbol has that unit;
`units::load_units_xml()` drops every package's installs (weft never calls it).

## The contract

### Keeping the token (4.4.20, both modes)

Wherever weft parses a unit (`u()`, `fmt_unit()` on a string, `read_dict()`
`unit`/`display`, `dict_local`, `units:` keys and `is:`, `unit=`/`unit =`),
it stores each token as written, except that it takes the symbol `units`
substitutes when that is the symbol of the token's **own** database row with
the same prefix (4.4.17 steps 3–4). Stored as substituted: `metre` `m`,
`degC` and `celsius` `°C`, `lux` `lx`, `degree` `°`. Stored as written: `Sv`,
`Bq`, `Bd`, `VA`, `Mg`, `ut`, `mt` (under `si`), `sievert`, `becquerel`,
`gallon`, `nautical_mile`, `Myr`. weft sets no `units` option globally.

**Twin units.** The database defines `Sv` and `Gy` alike, `Bq`, `Bd`, `Hz`
alike, `VA` and `W` alike. A weft conversion (`unit=`, `unit =`, `display:`)
from one member of a group to another, with any prefix, alone or in a
compound (`Bq/L` to `Hz/L`), is a value error (a `display:` problem). Within
a member (`mSv` to `Sv`) and to the SI definition (`Sv` to `J/kg`) it
converts.

### Modes (4.4.21)

`unit_defaults:` in `_weft.yml` or a document's `weft:`, `weft` (default) or
`si`. A row **redefines** when it has `is:` and `units` already parses its key
(alone or as prefix + unit): `pH`, `mph`, `nmi`, `Ma`, `ka`, `gal`.

| | `weft` | `si` |
|---|---|---|
| redefining default rows | registered, all fields apply | skipped whole |
| other default rows; the 2f shipped name table | apply | apply |
| keeping the token; twin conversions refused | yes | yes |
| refusals: misread list, traps (4.4.20) | for a token no row in force defines | none |
| a prefix on a default row with `is:` in force | refused | refused (`NTU`, `PSU`, `CFU`, `MPN`) |
| project and document `units:` rows | on top | on top |

Under `si`, `u(7.2, pH)` is 7.2 picohenries; a project wanting `pH` alone
copies that row into `units:`.

### Registration (4.4.21)

- **Not at package load.** Loading weft changes nothing in `units`.
- **Before weft first parses or converts a unit in a session**, and at every
  configuration read (9.1.3), weft brings the database to what the
  configuration in force wants: the default rows of its mode, then the
  project's rows, then the document's. Outside a knit that is the last
  configuration read; before any read, `weft` and no project rows.
- **Idempotent.** weft records each token it installed, with its definition,
  and each database mapping it removed (the name `gal`; a misread-list token
  a project redefines). A read wanting what is installed does nothing; a
  changed definition is removed and reinstalled; a token no longer wanted is
  removed and a removed mapping restored from the database's definition.
  So two documents knit in one session in different modes each see their
  own. A quantity holds only its token: `pH` made under `weft` and printed
  under `si` is picohenries.
- **Base registrations are never undone** in a session (`is: base` rows,
  4.4.7's tokens); `false` removes only their names.
- **Installed by someone else.** If `units` already maps a token, weft
  accepts it when it reads as the row says (an `is:` unit converts with
  factor 1 within 1e-9; a `base` token does not convert to the database's
  reading), else `weft_unit_error`. weft never removes what it did not
  install.
- **A failed read** leaves the session as though no configuration had been
  read: `weft`, the default rows only. 2f's "registers nothing" stands for
  project tokens.
- **Unloading weft** removes what it installed, except base registrations,
  and restores `gal`.

### A unit before the number (4.4.22)

`before: true` puts the unit before the number, joined by the space: "pH␣7.2".
Only when the unit printed is that token alone, power 1; in a compound it
follows ("0.2␣pH/h"). `space: false` removes the space before the symbol.
A collapse (`.and`, `.or`, `.range`, `trunc`, `glue_vec()`) puts it once
**before the first item printed**, in the form 4.4.3 gives; `.pairs`, list
classes and an uncollapsed vector, before each element. `#` carries it;
`.nounit` prints the number; a text class wraps both; `.cap` never changes a
symbol; the printed record holds the number; `fmt_unit()` prints "pH". New
`weft_text` attribute `unit_before`: logical, as long as the text, `TRUE`
before, `FALSE` after, `NA` with no unit; absent when no element has a unit.

### `unit_defaults()` (3.4.10)

Exported, not attached, no argument. A data frame of the table in file order,
columns `unit`, `is`, `name`, `plural`, `symbol` (character, `NA` blank),
`space` (logical, `NA` blank), `before` (logical, `FALSE` blank), `redefines`
(logical); attribute `file`, the YAML path. Registers nothing.

## Expected output

Mode `weft`, no project rows, unless the row says. `{unit=…}` uses `.num`.

| Value | Construct | Prints |
|---|---|---|
| `u(7.2, pH)` | `{.num}` / `{.uname}` / `{.nounit}` | `pH␣7.2` / `pH␣7.2` / `7.2` |
| `u(7, pH)` | `{.word}` | `pH␣seven` |
| `u(c(6.5, 8.5), pH)` / `u(c(6.5, 7.2), pH)` | `{.range}` / `{.and}` | `pH␣6.5–8.5` / `pH␣6.5 and 7.2` |
| `u(c(a = 6.5, b = 7.2), pH)` | `{.pairs}` | `a (pH␣6.5) and b (pH␣7.2)` |
| `u(7.2, pH)` | `[# was \| # were]{n=…}` / `{.strong}` / `space: false` | `pH␣7.2 was` / `**pH␣7.2**` / `pH7.2` |
| `u(0.2, pH/h)` | `{.num}` / `{.uname}` | `0.2␣pH/h` / `0.2␣pH per hour` |
| `u(60, mph)` / `u(1, mph)` | `{.uname}` | `60␣miles per hour` / `1␣mile per hour` |
| `u(60, mph)` | `{.num}` / `{unit="km/h"}` | `60␣mph` / `96.6␣km/h` |
| `u(3, nmi)` / `u(1, nmi)` | `{.uname}` | `3␣nautical miles` / `1␣nautical mile` |
| `u(3, nmi)` | `{.num}` / `{unit="km"}` | `3␣nmi` / `5.6␣km` |
| `u(65, Ma)` / `u(1, Ma)` | `{.uname}` | `65␣million years` / `1␣million years` |
| `u(65, Ma)` / `u(12, ka)` | `{unit="ka"}` / `{unit="yr"}` | `65,000␣ka` / `12,000␣years` |
| `u(12, ka)` | `{.num}` / `{.uname}` | `12␣ka` / `12␣thousand years` |
| `u(10, gal)` / `u(1, gal)` | `{.uname}` | `10␣gallons` / `1␣gallon` |
| `u(10, gal)` | `{.num}` / `{unit="L"}` | `10␣gal` / `37.9␣L` |
| `u(5, ppm)` / `u(1, ppm)` | `{.word}` / `{.uname}` | `five␣parts per million` / `1␣part per million` |
| `u(5, ppm)` / `u(20, ppb)` | `{unit="ppb"}` / `{.uname}` | `5,000␣ppb` / `20␣parts per billion` |
| `u(3, NTU)` / `u(1, NTU)` | `{.word}` / `{.uname}` | `three␣nephelometric turbidity units` / `1␣nephelometric turbidity unit` |
| `u(35, PSU)` / `u(40, CFU)` | `{.uname}` | `35␣practical salinity units` / `40␣colony-forming units` |
| `u(40, MPN)` | `{.num}` / `{.uname}` | `40␣MPN` / value error naming `MPN` |
| `u(150, "CFU/100 mL")` / `u(150, "MPN/100 mL")` | `{.num}` | `150␣CFU/100 mL` / `150␣MPN/100 mL` |
| `u(150, "CFU/100 mL")` | `{.uname}` | value error (a number, 4.4.19) |
| `u(2, Sv)` / `u(1500, mSv)` | `{.uname}` / `{unit="Sv"}` | `2␣sieverts` / `1.5␣Sv` |
| `u(40, Bq)` / `u(2, kBq)` | `{.uname}` / `{unit="Bq"}` | `40␣becquerels` / `2,000␣Bq` |
| `u(5, kVA)` / `u(3, Mg)` | `{.num}` / `{.uname}`, `{unit="t"}` | `5␣kVA` / `3␣megagrams`, `3␣t` |
| `u(2, Sv)` / `u(2, Bq/L)` | `{unit="Gy"}` / `{unit="Hz/L"}` | value error (twins) |
| `u(2, Gy)` / `u(5, Hz)` | `{.num}` | `2␣Gy` / `5␣Hz` |
| `u(5, mt)`, `u(5, kph)`, `u(1, Ga)`, `u(1, kmph)`, `u(1, kNTU)` | `u()` | `weft_unit_error` (4.4.20) |
| `u(7.2, pH)` | `si`; `{.num}` / `{.uname}` | `7.2␣pH` / `7.2␣picohenries` |
| `u(60, mph)` / `u(65, Ma)` / `u(3, nmi)` | `si`; `{.uname}` | `60␣milliphots` / `65␣megaares` / `3␣nanomiles` |
| `u(5, gal)` / `u(5, mt)` | `si`; `{.uname}` | `5␣gals` / `5␣millitonnes` |
| `u(60, mph)` | `si`; `{unit="km/h"}` | value error (does not convert) |
| `u(5, ppm)` / `u(3, NTU)` / `u(2, Sv)` | `si`; `{.uname}` | `5␣parts per million` / `3␣nephelometric turbidity units` / `2␣sieverts` |
| `u(7.2, pH)` | `si`, the `pH` row copied into `units:` | `pH␣7.2` |
| `u(10, gal)` | `units: {gal: {is: 4.54609 L}}`; `{unit="L"}` / `{.uname}` | `45.5␣L` / `10␣gallons` |
| `u(7.2, pH)` | `units: {pH: false}` | `weft_unit_error` |
| `u(3, NTU)` | `units: {NTU: {name: turbidity unit}}`; `{.uname}` | `3␣turbidity units` |

`attr(fmt_and(fmt_num(u(c(6.5, 7.2), pH))), "unit_before")` is `TRUE`.
`units::deparse_unit()` of `u(2, Sv)` is `"Sv"`, of `u(1, metre)` `"m"`, of
`u(1, sievert)` `"sievert"`, of `u(1, mt/d)` under `si` `"mt/d"`. Tests turn
Pandoc's `\ ` into `␣`, as in 2f.

## The default table, in full

`inst/weft-units.yml` (`system.file("weft-units.yml", package = "weft")`).
Rows install in file order.

```yaml
# weft's default units (rule 4.4.21). Each row is written as a row of
# `units:` in _weft.yml is, and may be copied there. See unit_defaults().
units:
  # Read by the units package as a prefix and another unit, or another unit.
  # Redefined under `unit_defaults: weft`; skipped under `si`.
  pH:
    is: base               # units: picohenry
    name: pH
    plural: pH
    before: true           # "pH 7.2"
  mph:
    is: 1 mi/h             # units: milliphot
    name: mile per hour
  nmi:
    is: 1852 m             # units: nanomile
    name: nautical mile
  Ma:
    is: 1 Myr              # units: megaare
    name: million years
    plural: million years
  ka:
    is: 1 kyr              # units: kiloare
    name: thousand years
    plural: thousand years
  gal:
    is: 1 gallon           # units: the galileo; the US gallon, as units' `gallon`
    name: gallon
  # Names the units database lacks.
  ppm:
    name: part per million
  ppb:
    name: part per billion
  # Units the database lacks, each a unit of its own.
  NTU:
    is: base
    name: nephelometric turbidity unit
  PSU:
    is: base
    name: practical salinity unit
  CFU:
    is: base
    name: colony-forming unit
  MPN:
    is: base
  CFU/100 mL:
    symbol: CFU/100 mL     # units writes "CFU/(100mL)"
  MPN/100 mL:
    symbol: MPN/100 mL
```

Why each row. The six redefinitions are every misreading 2f found that a
report means. `ppm`, `ppb`: in every water and air report, no database name.
`NTU`, `PSU`, `CFU`, `MPN`: turbidity, salinity, microbial counts, the units
4.4.7 was written for, now usable by `u()` with no dictionary; with `pH` they
are the dimensionless units of their own. `MPN` has no name ("40 most
probable numbers" is not English). The `/100 mL` rows: recreational-water
units, symbol only, as a number in a unit has no name (4.4.19) and a name with
"millilitres" has no en-US form in `units:`.

Left out. `ppt`: parts per trillion in the database, per thousand in salinity
work (Q2). `Sv`, `Bq`, `Bd`, `VA`, `Mg`, `ut`: fixed by keeping the token.
`meq`, `M` (molar), `kn`, `FNU`, `Ga`: not basic; a project adds them. `µS/cm`,
`dS/m`, `ML`, `mmol/L`, `mg/kg`: the database reads and names them.

## Configuration fields

```yaml
# _weft.yml
unit_defaults: weft        # weft (default) or si
units:
  gal:
    is: 4.54609 L          # the imperial gallon replaces the default's
  ppth:
    is: 0.001              # a number alone: dimensionless
    name: part per thousand
  Ga:
    is: 1 Gyr              # a misreading the defaults leave out
    name: billion years
    plural: billion years
  pH:
    space: false           # merged into the default row: "pH7.2"
  NTU: false               # removes the default row (NTU stays registered)
```

- **`unit_defaults`**: `weft` or `si`, else `weft_config_error` (9.1.6). A
  document may set it.
- **`is`** (9.1.7): `base`; a positive finite number; or an optional positive
  number, a space and a unit expression (`1 mi/h`, `mi/h`). A YAML string or
  number. Parsed as `u()` parses, against the database and the rows installed
  before it (defaults, project, document, each in file order), so a forward or
  circular reference fails. With `is:` the key is one token: no space, no
  digit first, none of `* / ^ ( ) . + -`. Without `is:` a key only names (2f).
- **Redefining a database unit**: `is:` on a key the database holds as a
  symbol or name of its own row (not by prefix) is a problem, unless the key
  is on 4.4.20's misread list or in the default table. `m: {is: ft}`, `ppt:
  {is: 0.001}` are problems; `gal`, `mt`, `pH` are not.
- **`before`**: `true` or `false` (default).
- **`false`** as a row's value removes the default row for that unit: its
  redefinition is undone (under `weft` the token is then refused if on the
  misread list) and its names drop; a base registration stays.
- **Precedence**, per unit: the default row; over it the document's row if
  any, else the project's. Over the default it merges **per field**; the
  document's row still replaces the project's whole (2f). The fields are
  `name`, `plural`, `symbol`, `space`, `is`, `before`.

## Errors

Refusals are a `weft_unit_error` from `u()` (text prefixed `u(): `) and a
problem from `read_dict()` (4.2.6), alone or in a compound.

| When | Text |
|---|---|
| under `weft`, a misread-list token no row in force defines | "`<tok>` is read by the units package as <reading>. <advice> To take that reading, set `unit_defaults: si` in _weft.yml (rule 4.4.20)." |
| under `weft`, a prefix on the phot or the are, except `ha` (`kph`, `Ga`, `ca`) | the same form |
| a prefix on a default row with `is:` in force | "`<tok>` is read as the prefix `<p>` (<prefix name>) on `<row>`, a unit of weft's default table, and weft refuses a prefix on its own units. Write the unit you mean (`km/h` for kilometres per hour) (rule 4.4.20)." |
| a token someone else installed that reads otherwise (`weft_unit_error`) | "`<tok>` was installed in this session, not by weft, as a unit that is not `<is>`, which weft's default table defines it as. Remove it with units::remove_unit(\"<tok>\"), or set `unit_defaults: si` (rule 4.4.21)." |
| a twin conversion (`weft_value_error`; `display:` problem) | "`<to>`: the quantity is in `<from>`, and the units package defines the <name> and the <name> alike; they measure different things, so weft does not convert one to the other (rule 4.4.14)." |
| bad `unit_defaults` (`weft_config_error`) | "`unit_defaults` must be `weft` or `si`; got `<v>` (rule 9.1.6)." |

| Token | `<reading>` | `<advice>` |
|---|---|---|
| `pH`, `mph`, `nmi`, `Ma`, `ka`, `gal` | a picohenry (`p` + `H`); a milliphot (`m` + `ph`); a nanomile (`n` + `mi`); a megaare (`M` + `a`); a kiloare (`k` + `a`); the galileo, a unit of acceleration | "weft's default table defines it, and `<tok>: false` in `units:` removed that row; define it there with `is:` (see unit_defaults())." |
| `mt` | a millitonne (`m` + `t`), which is 1 kg | "Write `t` for a tonne, or `Mt` for a megatonne." |
| a trap | a <prefix name><phot\|are> (`<p>` + `<ph\|a>`) | "Write the unit you mean (`km/h` for kilometres per hour, `Gyr` for a billion years)." |

New 9.1.7 problem lines (``<file>: units: `<key>`: <what> (rule 9.1.7)``):
"`is` must be `base`, a positive number, or a number and a unit, such as `1
mi/h`"; "`is` `<v>` is not a unit the units package can read: <message>";
"`is` `<v>`: <refusal text without the rule>"; "`is` defines one unit, so the
key must be one token, with no space and none of * / ^ ( ) . + -"; "`is`
cannot redefine `<key>`, a unit of the units database; choose another key";
"`is` gives the same unit as `<other>`; give it one row" ("(weft's default
table)" after a default key); "`before` must be true or false"; "`false`
removes a row of weft's default table, and it has no row `<key>`". The
unknown-field line lists the six fields.

## Decisions

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| G1 | swapped tokens | refuse (2f); reinstall; own base units; keep the token | keep, both modes | reinstalling turns `Gy` into `Sv`, `Hz` into `Bq` (measured, #325); base units break `Ci`→`Bq` and other packages' `1/s` | one function, `R/units.R` |
| G2 | twin conversions | allow; refuse | refuse in weft's conversions | a sievert is not a gray | beside `converts_by_inversion()` |
| G4 | the field | `def`; `definition` (a dictionary entry's prose); `is` | `is`, with `base` | "mph is 1 mi/h"; `base` covers `pH`, which parses | `UNITS_FIELDS` |
| G5 | redefining a database unit | allow; refuse | refuse but the misread list and default keys | `m: {is: ft}` rewrites every derived unit for the session | one check |
| G6 | `pH` | "7.2 pH"; `before` | `before: true` | "7.2 pH" is wrong in every style guide | the field |
| G7 | before-unit in a collapse | each item; once | once, before the first | mirrors 4.4.3: "pH 6.5–8.5" | one branch |
| G8 | when registered | `.onLoad`; first use; a call | first parse or conversion, and each read | loading weft must not change picohenries for other packages | the trigger |
| G9 | mode change | per session; per read | reconciled per read | a book or test run knits mixed modes | the reconciler |
| G11 | the off switch | `default_units: false`; two modes | `unit_defaults: weft\|si` (Robin) | names what the author gets instead | `R/config.R` |
| G12 | refusals under `si` | keep for swaps; none | none | under `si` swaps already print as typed, as SI writes them; refusing SI's units under `si` inverts the setting | G1 |
| G13 | names under `si` | none; all | all but redefining rows' | a name changes no meaning; "pH" for a picohenry would | the mode table |
| G14 | over the default | whole row; per field | per field | adding `space:` should not restate `is:` | the merge |
| G16 | prefix on a default row | allow; refuse | refuse | `kmph` is 1609 km/h (measured) | one check |
| G17 | detecting misreads | a heuristic; a list | a list and two traps | a prefix parse is valid udunits and weft has no list of common units; the phot and the are are never meant with a prefix | the list |
| G18 | `mt` | define as tonne; SI; refuse | refuse under `weft` | the author means a tonne, SI a millitonne: 10⁶ | the list |
| G19 | `gal` | US; imperial | US, as `units`'s `gallon` and 2f's name | one gallon in one package | the row |
| G20 | undoing | never; on unload | per read and on unload; base never | the only undo of `gal` that spares other packages | the reconciler |

**Can weft detect misreads in general? No.** A misreading is a valid parse;
weft knows a list. It can and does detect the swaps (G1) generally.

## Spec amendments

- **3.4.4** attribute `unit_before`; **3.4.10 (new)** `unit_defaults()`.
- **4.4.3, 4.4.4, 4.4.8** a unit written before the number precedes the
  first item and `#`'s number; the space rule applies on that side.
- **4.4.6** "So is a unit … misreads (4.4.20)" becomes "and a unit 4.4.20
  refuses"; "`u()` registers no unit" gains "of its own; the first parse in a
  session registers the default table (4.4.21)".
- **4.4.7** the default table is registered first; a failed read leaves the
  defaults; `is:` installs a definition.
- **4.4.14** twin conversions refused, as inversion is.
- **4.4.17** step 1: a row of `units:` in force, the project's or the
  document's over the default table's; a token a row defines with `is:`
  resolves as itself, never split into a prefix.
- **4.4.20 (rewritten)** keeping the token (both modes, own-row rule); the
  misread list (`pH`, `mph`, `nmi`, `Ma`, `ka`, `gal`, `mt`) and the two
  traps refused under `weft` unless a row in force defines the token, never
  under `si`; a prefix on a default row refused in both; "weft cannot detect
  a misreading in general; it knows a list".
- **4.4.21 (new)** the table, its file, which rows redefine, the modes,
  registration and undoing, someone else's installation. **4.4.22 (new)**
  `before:`.
- **9.1.2** row `unit_defaults`; **9.1.5** `unit_defaults: weft`; **9.1.6**
  its values; **9.1.7** `is`, `before`, `false`, redefining a database unit,
  precedence over the default, the new problems.
- **§13** 4.4.20 (G1, G17, #325, #204), 4.4.21 (G8, G9, G12, G13), 4.4.22
  (G6).

## Tests

New `test-unit-defaults.R` and `helper-2g.R`. The suite is one session, so a
test that knits under `si` or with project `is:` rows restores the default
state on exit (`withr::defer` of `weft_str()` in an empty project). Project
`is:` keys are tokens new to the session. Three tests need a fresh session,
by `Rscript -e` with `pkgload::load_all()`, `skip_on_cran()`: attaching weft
leaves `pH` convertible to `H`, and the first `u()` makes it not; a `pH`
installed before weft's first use is accepted; an `mph` installed as `1 km/h`
is the `weft_unit_error`.

- every expected-output row; `unit_defaults()` (columns, 14 rows,
  `redefines` true for exactly the six, `file` exists, registers nothing);
- keeping the token both ways via `units::deparse_unit()`, through
  `read_dict()`, `display:` and `unit=`; twin conversions;
- `before`: each collapse class, `trunc`, `.pairs`, `.ul`, `#` in `n`, `sign`,
  `list` spans, `.nounit`, `.strong`, `.cap` at a sentence start, `space:
  false`, a compound, `unit_before` through a chain;
- modes: `si`, `weft`, `si` in one session, each knit right, and outside a
  knit after each; a failed read returns to `weft`; a second read and a
  second `u()` change nothing;
- configuration: every new problem in one error with 2f's; each `is:` form;
  file-order and forward references; a same-unit pair; per-field merge; a
  document over a project over a default; `false`;
- every refusal in `u()` and `read_dict()`, alone and in a compound (`mt/d`):
  class, token, the reading's words, `unit_defaults: si` where given, rule.

**Superseded**, amended by the test-writer and listed in its report:

| File: test | Old | New |
|---|---|---|
| `test-review-2f.R`: "#9/e: u() refuses a unit that units reads as a different unit" | `Sv Bq Mg Bd VA mt ut` refused, `Sv`'s message names `Gy` | `Sv Bq Mg Bd VA ut` accepted, token kept; `mt` refused, message has "millitonne" |
| same: "#9/e: read_dict() has a problem for such a unit" | `unit: Sv` a problem | reads; holds `Sv` |
| same: "#b: u() refuses the tokens units misreads" | `mph pH nmi Ma ka gal` refused | accepted under `weft`; refused with a `false` row |
| same: "#1: a database row with a symbol and an empty name has no name" | `ppm` in the loop | out of it; `psi kt cmH2O rpm` stay |
| `test-review-2b.R`: "#3: plural() keeps a unit with regex characters" | `150␣CFU/(100mL) counts` | `150␣CFU/100 mL counts` |
| `test-unit-forms.R`: "2f table: CFU/100 mL prints units' symbol …" | `150␣CFU/(100mL)` | `150␣CFU/100 mL`; `.uname` still an error |
| `test-unit-forms.R`: "2f table: PSU …"; `test-unit-names.R`: "an unknown token has no name", "no name: a unit with an unknown factor", "the message carries a YAML example", "judged on the classes", "fmt_unit: a name that does not exist" | `PSU` has no name | the same on a made-up token; `PSU` named |
| `test-unit-names.R`: "control, a unit with a name in the units: table" | the project name equals the default's | use a name that differs, to show it wins |

The 2f expected-output rows for `u(3, PSU)` under `.word`/`.count` and
`u(150, "CFU/100 mL")` under `.num` are superseded likewise; the `#9/e` and
`#b` controls are unchanged.

## For Robin

Built as recommended until answered.

- **Q1 — swapped units kept as typed**, in both modes (G1, G12): `Sv`, `Bq`,
  `Bd`, `VA`, `Mg`, `ut` print as written and convert as SI defines them,
  except between twins. The alternatives were refusing them under `si` (the
  coordinator's suggestion) or redefining them, which turns `Gy` into `Sv`.
  Recommended: as built.
- **Q2 — `ppt`** stays the database's parts per trillion, unnamed, so a
  wording class makes the author name it. Alternatives: refuse it under
  `weft`; define it as parts per thousand. Recommended: as built.
- **Q3 — `mt` refused** under `weft` (G18). Alternative: a row making it a
  tonne. Recommended: refuse.
- **Q4 — "pH 7.2"**: `before:` and its collapse rule (G6, G7). Alternative:
  "7.2 pH", no field. Recommended: as built.
- **Q5 — no redefining a database unit** with `is:` (G5), so salinity uses
  `ppth` or `g/kg`. Alternative: allow any. Recommended: as built.

## Rulings on the test-writer's report

- **"pH 7.2 was".** The row of the expected-output table is wrong: 7.2
  takes the plural arm, so `[# was | # were]` prints "pH 7.2 were", and
  "pH 1 was". The tests are right.
- **`pH` under `si`.** A redefining row whose definition is `base` is
  removed under `si`, as the other redefinitions are. "Never undone"
  covers the units of weft's own that redefine nothing (`NTU`, `PSU`,
  `CFU`, `MPN`).
- Two `is:` rows are "the same unit" when their definitions are the same
  text. Accepted.
- The test-writer's other readings are accepted. Not tested, and left to
  the review: `dict_local`, a `list` span, and mixed `unit_before`.
- One more older assertion is superseded than the contract lists: the
  control of review 2f #13 (`CFU/L` now has a name) needs a factor with
  no name.

## Rulings on the implementer's report

- **Nine tests were faulty and are edited** (no rule changed): fixtures
  the `units` library cannot accept (a second symbol for an equal unit,
  a key ending in a digit used in a definition, a quotient that
  `deparse_unit()` writes with negative powers); three wrong
  expectations (the plural of a name with no " per ", a small number at
  the default digits, a refusal in prose, which is the "no value"
  failure there); and three plain test bugs.
- **New problem (9.1.7).** A project row with `is:` whose key ends in a
  digit is a problem: `units` reads a trailing digit as a power, and
  cannot remove such a symbol again.
- The default rows are held apart from the project's `units:` entries
  and merged field by field when a unit is looked up. Accepted.
- `space: false` governs a unit written before the number in its name
  form too ("pH7.2"). Accepted; it differs from 4.4.8, where `space:`
  governs the symbol only, and is in `dev/open-findings.md`.
- `.cap` is not applied to a text whose unit is written before the
  number. Accepted.
- A prefixed unit of a row with no symbol prints its symbol ("3,000
  Myr"); the plain unit prints its name ("years"). Accepted.
- A refusal is a `weft_unit_error` from `u()` and a `weft_value_error`
  from the `unit` key. Accepted.
