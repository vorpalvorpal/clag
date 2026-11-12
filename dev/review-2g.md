# Review of package 2g — weft's default units

Snapshot: the plain export `snap-2g` made at the start of the review, loaded
with `devtools::load_all()` in a fresh `Rscript` process per probe (state
carried between steps only where the finding is about state). `units` 1.0.0,
R 4.4. Knits are `knitr::knit()` of an `.Rmd` with `weft::weft_setup()`,
`WEFT_DRAFT=1`, in a temp project. Renders go through rmarkdown
(`md_document`, `html_document`, `pdf_document` with pdflatex and with
xelatex). `~` is U+00A0. "Read `<yml>`" means `weft:::read_config(dir)` of a
temp project holding that `_weft.yml`; the calls after it run outside a knit,
where the last configuration read is in force. `zzq`, `zzr`, `zzd` are made-up
tokens.

## Findings

**1. A failed configuration read leaves a project token installed, and it
then breaks a later, valid configuration.**
Severity: session state left wrong.
- Read `units: {zzr: {is: 1 m}, zzq: {is: 1 zzr}}` → `weft_config_error`
  "`zzq`: `is` `1 zzr` is not a unit the units package can read: Unit already
  maps to "zzr"". Then `u(10, zzr)` → `weft_unit_error` (gone, as it
  should be), but `fmt_num(u(10, zzq), unit = "m")` → `10 m`.
  `ud_state$installed` does not list `zzq`.
- The same with `is: 1 gal`, `is: 1 NTU`, `is: degC`, `is: mi/h`: each read
  fails and the token stays, as gallons, NTU, °C, mi/h.
- In a knit: the document above stops in `setup`; a second knit in the same
  session, of a project with no `units:`, prints `` `r u(2, zzq)`{unit="m"} ``
  as `X 2~m`.
- It poisons the next good read. Read `units: {zzq: {is: mi/h}}` (fails, as
  above), then read `units: {zzq: {is: 2 m}}` → `weft_unit_error` "`zzq` was
  installed in this session, not by weft, as a unit that is not `2 m`, which
  `units:` defines it as. Remove it with units::remove_unit("zzq") …". Weft
  installed it.
- `pkgload::unload("weft")` leaves it: `units::deparse_unit(units::as_units("zzq"))`
  → `m`.
- Expected: 4.4.21, "A failed read leaves the session as though no
  configuration had been read … 'registers nothing' stands for project
  tokens".
- Cause: `units::install_unit(tok, def)` maps the symbol to the unit and then
  fails when it maps the unit back to a symbol, which another symbol already
  has ("Unit already maps to"). `ud_install_one()` (`R/unit-defaults.R`)
  returns the error without removing the half-installed token or recording
  it, so neither `fail()` nor `ud_sync()` nor `ud_unload()` knows about it.
  Finding 8 is the same failure from the author's side.

**2. A `base` key that the units package already reads case-insensitively is
silently the database's unit.**
Severity: silent wrong output.
- Read `units: {Bags: {is: base, name: bag}}` → ok.
  `fmt_num(u(3, Bags))` → `3~Bags`, `fmt_num(u(3, Bags), unit = "kg")` →
  `127.9~kg`. udunits reads `Bags` as its `bag`, 94 pounds of cement.
  `bag: {is: base}` is refused as "a unit of the units database".
- `Hours: {is: base}` → ok; `fmt_num(u(1, Hours), unit = "h")` → `1~h`.
- Foreign install, the same: `units::install_unit("NTU", "1 m")` before weft's
  first use; `fmt_num(u(3, NTU), unit = "m")` → `3~m`, and its name is still
  "nephelometric turbidity units".
- `Meter: {is: 1 ft}` takes the other branch and gets finding 9's false
  message.
- Expected: 4.4.21, "weft accepts it when it reads as the row says (… a
  `base` token does not convert to the database's reading)". G5 meant to
  refuse redefining a database unit.
- Cause: in `ud_install_one()`, a token that already parses and does not
  redefine returns `NULL` at `if (identical(def, "base")) return(NULL)`
  without any check. The G5 check in `units_table_rows()` uses
  `tok_resolve_db()`, which matches names case-sensitively, while udunits
  matches them case-insensitively (`Days`, `Counts`, `Cups`, `Grains`,
  `Bags` all parse).

**3. A project `name:` over a default row keeps the default's plural.**
Severity: silent wrong output.
- Read `units: {pH: {name: acidity}}`:
  `fmt_num(u(c(1, 7.2), pH), unit_form = "name")` → `acidity~1`, `pH~7.2`.
- `units: {Ma: {name: megaannum}}`: `fmt_num(u(c(1, 65), Ma), unit_form =
  "name")` → `1~megaannum`, `65~million years`.
- `units: {ka: {name: kiloannum}}`, `` `r u(1, ka)`{.uname} and `r u(12, ka)`{.uname} ``
  → `1~kiloannum and 12~thousand years`.
- Control: `units: {NTU: {name: turbidity unit}}` (the default row has no
  `plural`) → `1~turbidity unit`, `3~turbidity units`.
- Expected: one unit, one name. In 2f a `name:` alone derives its plural; an
  author who renames a unit does not expect to restate a field they did not
  write.
- Cause: the per-field merge (G14) in `unit_entry()` (`R/unit-defaults.R`)
  treats `name` and `plural` as independent fields.

**4. `weft_str()` in a project whose `_weft.yml` has any error loses the
default rows' fields.**
Severity: silent wrong output.
- `_weft.yml` = `digits: many`; from that directory,
  `` weft_str('`r u(7.2, pH)`{.num} / `r u(150, "CFU/100 mL")`{.num} / `r u(c(6.5,8.5), pH)`{.range} / `r u(60, mph)`{.num}') ``
  → `7.2~pH / 150~CFU/(100mL) / 6.5–8.5~pH / 60~mph`.
  `` `r u(3, NTU)`{.uname} `` and `` `r u(5, ppm)`{.uname} `` → value error
  "has no name to print".
- The same strings from an empty project → `pH~7.2 / 150~CFU/100 mL / …`,
  `3~nephelometric turbidity units`.
- No error or warning says the configuration was not read (also with
  `unit_defaults: si` in the broken file: the session is silently `weft`).
- Expected: 4.4.21, a failed read leaves "`weft`, the default rows only", so
  `pH~7.2`.
- Cause: `string_state()` (`R/weft-str.R`) catches the read's error and uses
  `default_config()`, which has `units = list()` and no `units_default`;
  `unit_entry()` reads `cfg$units_default`. (Swallowing the error is older
  than 2g; losing the default rows is new.)

**5. `is:` on a key the database reads as a prefix and a unit rewrites a
common unit for the session.**
Severity: silent wrong output.
- Read `units: {km: {is: 1 mi}}` → ok. `fmt_num(u(5000, m), unit = "km")` →
  `3.1~km`; `fmt_num(u(5, km/h), unit = "m/s")` → `2.2~m/s`;
  `fmt_num(u(5, km), unit_form = "name")` → value error, no name.
- `units: {mL: {is: 1 L}}` → ok; `fmt_num(u(5, mL), unit = "L")` → `5~L`.
- `units: {kft: {is: 1 m}}` → ok; `u(3, kft)` is 3 m.
- Expected: the contract's rule ("a symbol or name of its own row (not by
  prefix)") lets these through, but G5's reason, "`m: {is: ft}` rewrites every
  derived unit for the session", applies to `km` and `mL` as much as to `m`.
  See question e.
- Cause: `units_table_rows()` refuses only `r$known && is.na(r$pre)`.

**6. A conflicting `mph` installed by someone else makes every `u()` fail.**
Severity: crash.
- `units::install_unit("mph", "1 km/h")` before weft's first use; then
  `u(5, m)` → `weft_unit_error` "`mph` was installed in this session, not by
  weft, as a unit that is not `1 mi/h`, which weft's default table defines it
  as. …". So does `fmt_num(u(5, NTU))`, and every later call.
- Reading a project with `unit_defaults: si` clears it (`fmt_num(u(5, m))` →
  `5~m`). Reading any `weft` project afterwards (an empty `_weft.yml`) raises
  the same error again. At the console there is no `_weft.yml` to set.
- Related, after weft's first use: `units::remove_unit("pH")` (the picohenry
  comes back) is not noticed. `fmt_num(u(7.2, pH))` → `pH~7.2`,
  `fmt_num(u(7.2, pH), unit = "nH")` → `0.0~nH` (warned 0.0072). A new read
  changes nothing, because `ud_state$installed` still says `pH` is installed.
- Expected: the contract gives the `weft_unit_error` for the token. It does
  not say that every unit fails, including `m`.
- Cause: `units_ready()` → `read_units_tables()` → `ud_sync()` aborts on the
  first conflict, `ud_state$ready` stays `FALSE`, and every later parse retries
  and aborts again.

**7. After weft's first use, a plain `units` user sees other symbols, and
cannot define some units.**
Severity: session state left wrong (the contract does not state it).
- Fresh session, `units::set_units(5, "Myr")` → `5 [Myr]`. After
  `weft::u(1, m)`: `5 [Ma]`. Likewise `kyr` → `[ka]`, `gallon` and
  `US_liquid_gallon` → `[gal]`, `nautical_mile` and `nmile` → `[nmi]`.
- `units::install_unit("myr", "1 Myr")` → error `Unit already maps to "Ma"`;
  `install_unit("gall", "gallon")` → `Unit already maps to "gal"`.
- `Gal` (udunits reads names case-insensitively, so `Gal` was the galileo) →
  not recognised. With the name `gal` removed, the galileo cannot be written at
  all in that session.
- A diff of 1,341 tokens (every database symbol, alias and name, and seven
  prefixes on every symbol) before and after weft's first use: 14 differ.
  These are the 6 the contract states, plus `Myr`, `kyr`, `gallon`,
  `US_liquid_gallon`, `liquid_gallon`, `nautical_mile`, `nmile`, `Gal`, `GAL`.
- Weft keeps its own tokens (`u(5, Myr)` holds `Myr`). Unload restores all of
  them.
- Expected: 4.4.21 lists what changes for others (`pH`, `mph`, `nmi`, `Ma`,
  `ka`, `gal`). It does not mention the symbol udunits now gives for
  `Myr`/`kyr`/`gallon`/`nautical_mile`, nor a failed `install_unit()`.
- Cause: `install_unit("Ma", "1 Myr")` (and `ka`, `gal`, `nmi`) also maps the
  unit to the new symbol. udunits keeps one symbol per unit. See question g.

**8. An `is:` that is exactly a unit weft installed is refused, as a unit
"the units package cannot read".**
Severity: contract mismatch (and an unclear error).
- `units: {zzr: {is: 1 m}, zzq: {is: 1 zzr}}` → "`zzq`: `is` `1 zzr` is not a
  unit the units package can read: Unit already maps to "zzr"". With
  `is: 2 zzr` it reads, and `fmt_num(u(10, zzq), unit = "m")` → `20~m`.
- `zzq: {is: 1 gal}`, `{is: 1 NTU}`, `{is: 1 pH}`, `{is: 1 Ma}`, `{is: degC}`,
  `{is: mi/h}` → the same message, each naming a different symbol.
- `zzw: {is: 1 sec}` after `zzq: {is: 1 s}` → "`1 sec` is not a unit the
  units package can read: Unit already maps to "zzq"". It is the same unit as
  `zzq`, the problem the contract words as "`is` gives the same unit as
  `<other>`". That problem is only found when the text is the same.
- Expected: 9.1.7, `is:` is "parsed … against the database and the rows
  installed before it", so a backward reference works. A unit equal to
  another row's is the "same unit" problem. "Not a unit the units package can
  read" is false.
- Cause: udunits will not map a second symbol to a unit that already has one.
  `ud_sync()` reports `install_unit()`'s error as unreadable. Each of these
  also leaves the token installed (finding 1).

**9. "Installed in this session, not by weft" for tokens nobody installed.**
Severity: unclear error.
- `units: {zzq: {is: 1 s}, kzzq: {is: 1 m}}` → `weft_unit_error` "`kzzq` was
  installed in this session, not by weft, as a unit that is not `1 m`, …
  Remove it with units::remove_unit("kzzq"), or set `unit_defaults: si`".
  `kzzq` is kilo-`zzq`. In the other order, both read.
- `units: {Meter: {is: 1 ft}}` → the same message for `Meter`, which udunits
  reads as the metre's name.
- The leftover of finding 1 gets the same message.
- Its advice does not work. `units::remove_unit("kzzq")` returns silently
  (there is no such symbol to remove). The same file with
  `unit_defaults: si` fails with the same message, because `si` skips no
  project row. It is also a
  `weft_unit_error`, where the read's other problems are one
  `weft_config_error`.
- Expected: a 9.1.7 problem that says what the key is read as ("`kzzq` is
  read as the prefix `k` on `zzq`, a row above"; "`Meter` is the metre's name
  to the units package").
- Cause: `ud_install_one()` takes "it already parses" to mean "someone else
  installed it".

**10. A spelled number, `.no`, or `space: false` with a unit written before.**
Severity: wrong output.
- `fmt_no(u(0, pH))` → `pH~no`. `fmt_and(fmt_no(u(c(0, 0), pH)))` →
  `pH~no and no`. `fmt_word(u(0, pH))` → `pH~zero`.
- With `units: {pH: {space: false}}`: `fmt_word(u(7, pH))` → `pHseven`,
  `fmt_count(u(3, pH))` → `pHthree`, `fmt_no(u(0, pH))` → `pHno`.
- A project row `zzd: {is: base, before: true, symbol: "$", space: false, name:
  dollar}`: `` `r u(5, zzd)`{.uname} `` → `dollars5`, `{.word}` →
  `dollarsfive`, `fmt_num(u(1, zzd), unit_form = "name")` → `dollar1`.
- Expected: the ruling "`space: false` governs a unit written before the
  number in its name form too ("pH7.2")" did not consider spelled numbers. "pH
  no" is not English under any setting. See question c.
- Cause: `prefix_of()` in `apply_formatters()` (`R/format.R`) joins the
  unit's text and the element by `unit_space()`, whatever the element is.

**11. The `/100 mL` rows apply only to the exact unit, and their symbol can
break across a line.**
Severity: wrong output (misleading), and cosmetic.
- `fmt_num(u(150, "CFU/100 mL") / u(1, d))` → `150~CFU/(100d·mL)`.
- `fmt_num(u(150, "CFU/100 mL") * u(100, mL))` → `15,000~CFU/100`, which is
  150 CFU. `* u(1, L)` → `150,000~CFU/100`.
- `u(150, "CFU/100 L")` → `150~CFU/(100L)`; `"CFU/10 mL"` → `CFU/(10mL)`;
  `"MPN/100 g"` → `MPN/(100g)`; `"CFU/0.1 L"` → `CFU/(0.1L)`.
- In the HTML render, `150~CFU/100 mL` has U+00A0 after `150` and an ordinary
  space between `100` and `mL` (bytes checked), so a line can break inside the
  unit. The `.tex` has the same plain space.
- Expected: design 2g's third fault was "`CFU/100 mL` printed `CFU/(100mL)`".
  The fix covers two strings, and the obvious next step (a daily rate, a
  count in a sample) brings the old form back or worse.
- Cause: the rows are whole-unit `symbol:` overrides (`unit_entry()` by
  `unit_whole_id()`), and udunits writes a numeric factor in the
  denominator. The symbol's space is the YAML's plain space.

**12. A document `units:` row without `is:` for a project's `is:` token
fails, and the problem names `_weft.yml`.**
Severity: unclear error.
- `_weft.yml` `units: {zzq: {is: 1 m}}`, front matter
  `weft: {units: {zzq: {name: zebra}}}` → `weft_config_error`
  "`…/_weft.yml: units: `zzq`: is not a unit the units package can read`".
  The same with `{plural: zebrae}` over a project row that has `is:`.
- Expected: the contract says the document's row replaces the project's whole
  (so `is:` goes; see question d). At least, the problem should name the
  document and say that its row has no `is:`. The project file is not at
  fault.
- Cause: `read_units_tables()` builds `W` from the top row (the document's,
  no `is`), so `zzq` is never installed. `units_entries()` then fails on the
  project's row, which still lists `zzq`.

**13. A refused or duplicate `is:` row gets a second, false problem.**
Severity: unclear error.
- `units: {zzq: {is: 1 s}, zzw: {is: 1 s}}` → two problems: "`zzw`: `is` gives
  the same unit as `zzq`; give it one row" and "`zzw`: is not a unit the units
  package can read".
- The same second line follows `is: 1 mt` (refusal), `is: 1 kNTU`, `is: 1 Ga`
  and `zzq: {is: 1 mi/h}` (same unit as the default `mph`).
- Cause: `read_units_tables()` drops the row from `Wk` but not from
  `tb[[t]]$rows`, so `units_entries()` tries to parse a token that was never
  installed.

**14. `is:` accepts forms the contract does not list.**
Severity: contract mismatch.
- Each reads with no problem: `is: 2 m 3` (`10 zzq` → `60~m`), `is: 3 2 m`
  (`60~m`), `is: m 2` (`20~m`), `is: 2m`, `is: 2*m`, `is: 1/2` (`10 zzq` with
  `unit = "1"` → `5`).
- Expected: 9.1.7, "`base`; a positive finite number; or an optional positive
  number, a space and a unit expression". Harmless, but `2 m 3` is not that.
  Either the rule widens to "any unit expression `units` reads" or these are
  the format problem.
- Cause: `units_is_text()` checks only a leading sign and the number-only
  form; the rest goes to udunits.

**15. `units_options(auto_convert_names_to_symbols = FALSE)` set before weft's
first use changes weft's output for the session.**
Severity: cosmetic.
- `units::units_options(auto_convert_names_to_symbols = FALSE)`, then
  `fmt_num(u(5, degC))` → `5~degC`. `units::deparse_unit(u(5, metre))` →
  `metre` (it prints `5~m`).
- If the option is set after a token's first use, the earlier result is
  cached and stays: `u(5, celsius)` → `5~°C` both before and after.
- Expected: 4.4.20, "Stored as substituted: `metre` `m`, `degC` and
  `celsius` `°C`". The user's option is a legitimate setting.
- Cause: `unit_own_symbol()` reads `as_units(tok)` under the session's
  option, and caches it in `un_cache$sym`.

**16. The trap message gives the same advice for every token.**
Severity: unclear error.
- `u(1, ca)` → "`ca` is read by the units package as a centiare (`c` + `a`).
  Write the unit you mean (`km/h` for kilometres per hour, `Gyr` for a billion
  years). …". `daa` → "a dekaare (`da` + `a`)" with the same advice. `fmt_unit("kph")`
  starts "u(): ", though the author called `fmt_unit()`.
- Expected: advice that fits (`m^2` for `ca`; `daa` is a real unit in
  Scandinavian land records, so say how to get it).
- Cause: one fixed string in `unit_token_refusal()`.

**17. Names newly reachable through the kept token.**
Severity: cosmetic.
- `fmt_num(u(2, MVA), unit_form = "name")` → `2~megavoltamperes` (the
  twin message, hard-coded, says "volt-ampere"). `u(2, Bd)` → `2~bauds`.
- These were refused under 2f, so 2g is the first to print them. The SI
  Brochure writes "volt-ampere"; "baud" is usually invariable.
- Cause: the database names (`voltampere`); no row in the shipped name table.

**18. A contract line about `deparse_unit()`.**
Severity: cosmetic (contract text).
- Under `si`, `units::deparse_unit(u(5, mt/d))` → `"mt d-1"`; the contract's
  Expected-output note says `"mt/d"`. The token is kept, which is the point;
  only the quoted form is wrong.

## Questions

a. **Twins by another route.** The refusal covers members only. Measured:
   `` `r u(2, Ci)`{unit="Hz"} `` → `74,000,000,000~Hz`; `u(2, rem)` to `Gy`
   converts; `units: {zzq: {is: 1 Sv}}` converts to `Gy` and to `Sv`;
   `u(u(2, Bq), "1/s")` then `Hz` converts in two steps. Phrases and claims:
   `of_n(u(2, Sv), u(4, Gy), …)` → "2 of the 4 doses" while `Sv` with `m` is
   a value error. `claim(u(2, Sv), . > u(1, Gy))` passes, and
   `about(u(1, Sv)/u(2, Gy))` → "half". **Recommend:** put `Ci` in the
   becquerel group and `rem` in the sievert group, and make `match_units()`
   (used by `of_n()`) apply `unit_twin_problem()`. Leave arithmetic and
   `claim()`'s operators to `units`, as the contract says, and add a line to
   `?u` saying so.

b. **A negative number with a unit before.** `u(-5, zzd)` (`$`, before,
   no space) → `$−5`; `u(c(-5, 5), zzd)` `.range` → `$−5 to 5`.
   `u(-0.4, pH)` → `pH~−0.4`, which is right for pH. The contract does not
   say. **Recommend:** state that the unit goes before the sign
   (`pH −0.4`). The `before:` field is for `pH`; a currency is not a unit
   weft supports.

c. **Spelled numbers with a unit before** (finding 10). **Recommend:** `.no`
   with a unit written before is a value error ("pH no" has no reading).
   `.word`/`.count` keep "pH seven" as the table says. `space: false` applies
   to the symbol form only, which reverses the implementer ruling for the
   name form ("pH7.2" in `.uname` is also odd).

d. **A document row over a project `is:` row.** Replacing whole (2f) drops
   the project's definition, so a document cannot rename a project's own
   unit without restating `is:` (finding 12). **Recommend:** merge `is:` and
   `before:` per field from the project, as from the default (G14). Or keep
   "replaces whole" and make the problem name the document.

e. **Which keys may take `is:`.** Today: refuse a key that is a database
   symbol or name in weft's case-sensitive index. Allow a prefix parse
   (`km`, `mL`, `kft`) and a case variant (`Bags`, `Meter`, `Hours`)
   (findings 2, 5, 9). **Recommend:** refuse any key `units` already parses
   (ask udunits, not `tok_resolve_db()`), except the misread list and the
   default keys; and say so in 9.1.7. The cost is that a project cannot reuse
   a prefix-parse spelling, which is the point.

f. **`weft_str()` and a broken `_weft.yml`.** It swallows the error (older
   than 2g), but under 2g that silently switches mode and units (finding 4).
   **Recommend:** `weft_str()` raises the `weft_config_error`, as a knit
   does. At least, fall back to the default rows.

g. **What weft changes for a plain `units` user** (finding 7). The symbol
   substitution (`Myr` → `Ma`, `gallon` → `gal`, `nautical_mile` → `nmi`) and
   the failed `install_unit()` of an alias follow from installing `Ma`, `ka`,
   `gal`, `nmi` with definitions. **Recommend:** state it in 4.4.21 and in
   `?unit_defaults`. Do not work around it; reinstalling differently is the
   #325 trap G1 avoided.

h. **One bad foreign token disables weft** (finding 6). **Recommend:** a
   conflicting token disables only its own row, with the
   `weft_unit_error` raised when that token is used, so `u(5, m)` still
   works. Also check, at each read, that a token weft recorded as installed
   still converts as its row says.

i. **A refusal inside a knit is filed as "[no value]".** `` `r u(1, mt)` ``
   → `doc.Rmd:9 [no value] … u(): `mt` is read by the units package as a
   millitonne …`. The class is `weft_unit_error` outside a knit. **Recommend:**
   leave it if every `u()` error has always been "no value" in a knit (it is
   the code that failed). Otherwise file it under the class's own heading.

j. **A unit made under one mode and printed under the other.** The contract
   states one direction ("`pH` made under `weft` and printed under `si` is
   picohenries"). The other is also true: `x <- u(7.2, pH)` after a `si`
   read, then printed from a `weft` project → `pH~7.2`, a picohenry printed
   as acidity, and convertible to `nH`. **Recommend:** state both directions.
   In a book that knits chapters in both modes, a value carried between them
   is wrong either way.

k. **`MVA` and `Bd` names** (finding 17). **Recommend:** add `VA` (name
   "volt-ampere") and `Bd` (plural "baud") to the shipped name table, since
   2g now admits them.
