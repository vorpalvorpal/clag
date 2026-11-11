# Review of package 2f — unit names and unit settings

Snapshot: `f06bb2b` (the code of `5f2aec1`, with the spec amended and the rule
for the unit classes renumbered to 1.4.19), loaded with
`devtools::load_all()`. Knits are `knitr::knit()` of an `.Rmd` with
`weft::weft_setup()`, `WEFT_DRAFT=1`, in a temp project; renders through
rmarkdown (`html_document`, `pdf_document` with pdflatex and with xelatex).
`␣` is U+00A0. `ws(s)` is `weft_str(s)`. "Knit with `_weft.yml` …" means a
temp project holding that file.

## Findings

**1. A unit the database lists with a symbol and no name prints the name "s"
or nothing.**
Severity: silent wrong output.
- `fmt_word(u(5, ppm))` → `five␣s`; `fmt_count(u(3, psi))` → `three␣s`;
  `fmt_no(u(0, kt))` → `no␣s`.
- `fmt_num(u(1, ppm), unit_form = "name")` → `1␣` (an empty name);
  `fmt_unit(u(5, ppm), unit_form = "name")` → `s`.
- 21 rows of `units::valid_udunits()` have a symbol and an empty
  `name_singular`: `ppm`, `ppb`, `ppt`, `ppq`, `ppv`, `rpm`, `cc`, `psi`, `ksi`,
  `kt` (knot; `kts` too), `cmH2O`, `cmHg`, `e`, `bev`, the `B…` bel units.
  `u(5, cmH2O)` under `.uname` → `5␣s`.
- Expected: a value error (4.4.19: "weft never guesses"), as for `PSU`. "five
  s" reads as five seconds.
- Cause: `tok_name()` (`R/unit-names.R`) takes
  `gsub("_", " ", db$v$name_singular[r$row])` without checking it is
  non-empty, and `english_plural("")` is `"s"`.

**2. `#` loses the unit, or the span fails, when a back-reference or a
formatter's text governs and the span has a class of its own.**
Severity: silent wrong output (and a value error that says the wrong thing).
- `` ws('`r u(5, m)`{#a} [# x | # xs]{n="#a" .word}') `` → `5 five xs`
  (expected `five␣metres xs`).
- Same with `{n="#a" digits=2}` → `5.00 xs` (expected `5.00␣m xs`).
- `{n="#a" .uname}` → value error "`.uname needs a quantity with a unit, and
  this value is not a quantity (class numeric)`". `{n="#a" .nounit}` and
  `{n="#a" unit="cm"}` fail the same way, the last with "`unit = cm` needs a
  quantity … class numeric". The value is a quantity.
- `` ws('[up # | down #]{sign="fmt_num(u(-3, m))" .word}') `` → `down three`;
  with `.uname` the same value error.
- Without a class of its own the unit is there: `{n="#a"}` after
  `{#a .uname}` → `5␣metres xs`.
- Expected: 4.4.4, "This holds whatever the governor is: a quantity, a
  formatter's text for a quantity, an id, …".
- Cause: `backref_value()` in `R/resolve.R` formats the id's `raw`, and
  `raw_of()` keeps only `as.numeric(v)`. `render_sign()` formats
  `abs(raw_of(v))` for a `weft_text` governor. Neither keeps the unit
  (`attr(v, "units")`). (The "`.uname` needs …" message also lacks backticks
  round the class: `R/format.R`, `apply_formatters()`.)

**3. A PDF render stops for `ohm`, `arcmin` or `arc_second` under pdflatex,
and loses the glyph under xelatex.**
Severity: crash (pdflatex); silent wrong output (xelatex).
- `output: pdf_document`, body `` `r u(5, ohm)`{.num} `` → `LaTeX Error:
  Unicode character Ω (U+03A9) not set up for use with LaTeX`.
  `` `r u(5, arcmin)`{.num} `` → the same for `′ (U+2032)`; `arc_second` for
  `″`.
- `latex_engine: xelatex`: the PDF builds, the log has `Missing character:
  There is no ′ (U+2032) in font [lmroman10-regular]` and the same for `″`;
  `pdftotext` gives `B 5�. C 5�.`. `Ω`, `µg` and `Å` survive.
- New in 2f: a token typed as a name now prints its unit's symbol (4.4.8),
  so `u(5, ohm)` prints `Ω` where 2b printed `ohm`. `units` turns a typed
  `'` and `"` into `′` and `″` too.
- Expected: 1.4.18 settles U+2212 for pdflatex; these three need the same
  `\DeclareUnicodeCharacter` (`add_latex_minus()`, `R/hooks.R`), or a
  LaTeX-safe text.

**4. A collapse given the text of spelled numbers puts the symbol after them
under `unit_form = "symbol"` or `"auto"`.**
Severity: wrong output.
- `q <- u(c(3, 5), m)`:
  - `fmt_and(fmt_word(q), unit_form = "symbol")` → `three and five␣m`.
  - `fmt_and(fmt_word(q), unit_form = "auto")` → `three and five␣m`.
  - `fmt_range(fmt_word(q), unit_form = "symbol")` → `three–five␣m`.
  - `fmt_and(fmt_no(u(c(0, 0), m)), unit_form = "symbol")` → `no and no␣m`.
- `unit_form = "name"` and `NULL` print `three and five␣metres`.
- Expected: under `auto`, a spelled element takes the name (4.4.15). Under
  `symbol` it is a value error: U4, "SI forbids 'five m'". The class form is
  safe only because `.usym` implies `.num`: `` `r fmt_word(q)`{.and .usym} ``
  → `3 and 5␣m`.
- Cause: in `apply_formatters()` an explicit `unit_form` sets
  `keep_forms <- FALSE`. `spelled` is computed only from this call's wording
  classes, so each spelled element of the incoming text counts as digits.

**5. A `plural:`-only entry for a prefixed unit gets the prefix again when the
unit is a factor.**
Severity: wrong output.
- Knit with `_weft.yml` `units: {km: {plural: klicks}, ug: {plural: mikes}}`:
  `` `r u(5, km)`{.uname} `` → `5␣klicks`, but `` `r u(5, km/h)`{.uname} `` →
  `5␣kiloklicks per hour`, and `` `r u(5, ug/L)`{.uname} `` →
  `5␣micromikes per litre`.
- Expected: `klicks per hour`, `mikes per litre`.
- Cause: `tok_name()` (`R/unit-names.R`) takes `pl <- E$plural`, then in the
  `!is.na(r$pre)` branch does `pl <- paste0(p, pl)`. The whole-unit path
  (`unit_name_text()`, `W$plural`) does not, hence the two outputs.

**6. A unit class on `.range` changes the number of decimals.**
Severity: wrong output.
- `` ws('`r u(c(1,1.25), m)`{.range} / `r u(c(1,1.25), m)`{.range .uname} /
  `r u(c(1,1.25), m)`{.range .usym} / `r u(c(1,1.25), m)`{.range .nounit}') ``
  → `1.0–1.3␣m / 1–1.3␣metres / 1–1.3␣m / 1–1.3`.
- `fmt_range(u(c(1, 1.25), m), unit_form = "name")` → `1.0–1.3␣metres`, so
  the class and the argument disagree.
- `[# x | # xs]{n="u(c(1,1.25), m)" .range .uname}` → `1–1.3␣metres xs`.
- Expected: 1.4.4, both ends to the same decimals. A unit class should change
  the unit only.
- Cause: a unit class implies `.num` (1.4.7). `ncls` is then `".num"`, and
  `format_numbers()` is called without `range = TRUE`. Explicit
  `{.range .num}` does the same (`1–1.3␣m`): an older bug that 2f makes
  reachable by adding `.uname`.

**7. `fmt_cap(fmt_unit(x))`, the use the contract advertises, turns a prefix
into another one.**
Severity: silent wrong output.
- `fmt_cap(fmt_unit(u(1, mL)))` → `ML` (megalitre).
  `fmt_cap(fmt_unit(u(1, mg/L)))` → `Mg/L`. `fmt_cap(fmt_unit(u(1, ms)))` →
  `Ms`.
- `` ws('# Volume (`r fmt_unit(u(1, mL))`{.cap})') `` → `# Volume (ML)`.
  `` `r fmt_unit(u(2, mm))`{.cap} `` → `Mm`.
- The default form is `auto`, so `fmt_unit()` gives the symbol; the name form
  is fine (`Millilitre`).
- Expected: a symbol never changes (4.4.16). The help says `fmt_unit()` has
  no unit attributes "so fmt_cap() works on it". `.cap` should leave a
  symbol alone (an error, or capitalise only a name).
- Cause: `fmt_unit()` returns a bare `weft_text` that does not say it is a
  symbol; `capitalise()` uppercases the first letter.

**8. Under the default form, a unit typed by a common name that has no
database symbol now prints the database's technical name.**
Severity: wrong output (a change from 2b in default output).
- `fmt_num(u(5, x))`, `auto`:

  | typed | prints |
  |---|---|
  | `knot` | `5␣international knots` |
  | `cup` / `quart` / `gallon` | `5␣US liquid cups` / `…quarts` / `…gallons` |
  | `ton` | `5␣short tons` |
  | `byte` / `kilobyte` / `megabyte` | `5␣octets` / `5␣kilooctets` / `5␣megaoctets` |
  | `revolution`, `cycle` | `5␣circles` |
  | `Btu` | `5␣IT Btus` |
  | `torr` | `5␣mm\_Hg` (renders `mm_Hg`) |

- 2b printed each as typed (`5␣knot`). Name forms show more database
  artefacts: `u(1, kcal)` under `.word` → `one␣kiloIT calorie`
  (`kiloIT calories`); `u(1, degF)` → `1␣fahrenheit`, `u(5, degF)` →
  `5␣degrees fahrenheit` (singular and plural disagree, lower-case F);
  `u(5, hp)` → `5␣shaft horsepowers`; `u(5, mmHg)` → `5␣millimeters Hg`
  outside en-US.
- Expected: by the letter of 4.4.8 and 4.4.17 this is the contract (a
  no-symbol unit prints its name, the name is the database's). But U7 says
  these names are "technical", and the shipped table was meant to stop them.
  "5 circles" for revolutions and "5 octets" for bytes are wrong to a reader.
- Cause: `tok_symbol()` returns `name = TRUE` for any row with an empty
  symbol. Over 40 such rows are reached by a common word. Suggest: a unit
  typed as a name whose row has no symbol prints as typed (2b), or the shipped
  table grows (`knot`, `cup`, `gallon`, `ton`, `byte`, `revolution`, `degF`,
  `cal`, `Btu`, `hp`, `torr`).

**9. Some units print as another unit, by name as well as by symbol.**
Severity: silent wrong output (the cause is in `units`; the contract's claim
is false).
- `fmt_num(u(5, Sv))` → `5␣Gy`; with `unit_form = "name"` → `5␣grays`.
  `u(5, Bq)` → `5␣Hz` / `5␣hertz`; `u(5, Mg)` → `5␣t` / `5␣tonnes`.
- `units::set_units(1, "Sv", mode = "standard")` stores `Gy`. Over the
  database's symbols, `units` rewrites `Bq→Hz`, `Sv→Gy`, `Bd→Hz`, `VA→W`,
  `Mg→t`, `mt→kg`, `ut→g` (and `'`, `"`, `°K`, `℃` to their canonical forms).
- 4.4.17 says "`units` keeps each token as written". A sievert is not a
  gray, and a volt-ampere is not a watt. In 2b the symbol was already wrong;
  2f now prints the wrong name too. See question e.

**10. `mbar`, `kbar` and `Mbar` have no name, while `millibar` does.**
Severity: contract mismatch.
- `fmt_num(u(5, mbar), unit_form = "name")` → value error "`mbar` is not a
  unit weft knows a name for". `u(5, millibar)` → `5␣mbar` / `5␣millibars`.
- Expected: 4.4.17 step 4, a prefix symbol before a symbol that step 2
  resolves. The shipped table gives `bar` the symbol `bar`, so `mbar` is
  milli + bar. Millibar is common in rainfall and weather reports.
- Cause: `tok_resolve()` matches the rest with `ud_core()`, which finds `bar`
  only as a database *name* (the row has no symbol), so `kind` is `"name"`
  and the symbol prefix `m` is refused. `SHIPPED_UNITS$bar$symbol` is never
  consulted.

**11. `space: false` on a unit with no symbol takes the space off its name.**
Severity: contract mismatch.
- Knit with `_weft.yml` `units: {sites: {name: site, symbol: false, space:
  false}, yr: {space: false}}`:
  - `` `r u(5, sites)`{.num} `` → `5sites`.
  - `` `r u(5, sites)`{.uname} `` → `5␣sites`.
  - `` `r u(5, year)`{.num} `` → `5years`.
- Expected: 4.4.8, "a no-break space … before every name"; `space:` is for a
  symbol. One unit should not print two ways.
- Cause: `suffix_of()` (`apply_formatters()`) and `glue_vec()` ask
  `unit_space()` whenever the form is `symbol`, even when
  `unit_symbol_text()` has fallen back to the name.

**12. `fmt_unit()` misreads a formatter's text, ignores `unit` on a string, and
words the blank-string error unlike `u()`.**
Severity: unclear error / contract mismatch.
- `fmt_unit(fmt_num(u(5, m)))` → `weft_unit_error` "u(): `5 m` is not a unit
  the units database knows… ‘ m’ is not recognized". The text carries
  `units`. Expected `m`, or an error saying to pass the quantity.
  `fmt_unit(fmt_word(u(1, m)))` says "`one metre` is not a unit".
- `fmt_unit("m", unit = "cm")` → `m`. 3.4.9: "`unit` converts first". `cm`
  was expected, or an error; it is silently dropped.
- `fmt_unit("")` → "needs a quantity with a unit; this one has no unit left".
  The contract says "as `u()` does": `u()` says "the unit is blank".
- Cause: `fmt_unit()` tests `is.character(x)` before `inherits(x, "units")`
  or a `weft_text`, and applies `unit` only in the quantity branch.

**13. The no-name advice for `CFU/100 mL` sends the author round twice.**
Severity: unclear error.
- `fmt_word(d$a)` with `unit: "CFU/100 mL"` → "The unit `CFU/(100mL)` has no
  name to print: `CFU` is not a unit weft knows a name for. Add … `CFU: name:
  …`".
- Following it (`units: {CFU: {name: colony-forming unit}}`) gives a second
  error: "it holds a number (`100`) … `"CFU/(100*mL)": name: …`". That key
  works, but it is not what the author typed. The first message could not
  have been met.
- Expected: when any factor is a number, or the whole unit needs an entry,
  say so first, keyed as written (`"CFU/100 mL"` also matches).
- Cause: `unit_name_text()` checks the factors in order (numerator first), and
  the key text comes from `unit_key_text()`.

**14. The negative-power message shows the quotient it asks the author to
write.**
Severity: unclear error.
- `fmt_num(u(3, "s^-2"), unit_form = "name")` → "The unit `1/s^2` has no name
  to print: it is written with a negative power, which has no name (write it
  as a quotient, `1/...`)".
- `u(3, "1/s^2")` under `.uname` → `3␣per second squared`, so the message
  names as its unit the very spelling that would work, and calls it
  negative.
- Cause: `no_name_error()` prints `as.character(un)`, which `units` writes as
  `1/s^2`. The message should quote the author's `s^-2` (or say "units
  holds it as `s^-2`") and give `u(3, "1/s^2")` as the fix.

**15. The `unit_form: symbol` error quotes "three m" whatever the class, and
fires for units that have no symbol.**
Severity: unclear error.
- Knit with `_weft.yml` `unit_form: symbol`:
  - `` `r u(2, m)`{.no} `` → "`.no` cannot print a quantity under
    `unit_form: symbol` … and \"three m\" is not written". Nothing printed
    "three", and `.no` on 2 prints `2␣m`.
  - `` `r u(5, sites)`{.word} `` with `sites: {name: site, symbol: false}`
    gives the same error. A unit with no symbol prints by name "in every form"
    (9.1.7), so `five␣sites` is the only possible output. `year` is the
    same.
- See question c. The fixed example is in `apply_formatters()`
  (`R/format.R`).

**16. `units:` accepts keys that are no unit, and two messages cite two
rules.**
Severity: cosmetic.
- `_weft.yml` `units: {"1": {name: one}, "m/m": {name: ratio}, "100": {name:
  hundred}, foo bar: {name: w}}` reads with no problem. The first two have no
  unit, the third is a number, and the fourth registers `foo` and `bar` as two
  base units. Suggest: "a key with no unit" and "a key that is a number" as
  problems.
- `units: {"m^0.5": …}` → "… is not supported (rule 4.4.6) (rule 9.1.7)". A
  dictionary's `display: "m^0.5"` → "… (rule 4.4.6) (rule 4.2.7)".

## Questions

a. **`.ord` on a quantity.** `fmt_ord(u(3, m), unit_form = "name")` →
   `3rd␣metres`, and with 1 → `1st␣metre`. A rank has no unit. Recommend: a
   value error for `.ord` with a unit class or `unit_form = "name"` (or for
   `.ord` on any quantity).

b. **Names that expose a misreading by `units`.** The name now shows what
   `units` parsed: `u(60, mph)` → `60␣milliphots`, `u(7, pH)` →
   `7␣picohenries`, `u(5, nmi)` → `5␣nanomiles` (1.6 mm), `u(5, Ma)` →
   `5␣megaares`, `u(5, ka)` → `5␣kiloares`, `u(5, gal)` → `5␣gals` (galileo),
   `u(5, oz)` → `5␣US fluid ounces`. The symbol still reads `60␣mph`, so a
   `.num` document never shows the error. Recommend: a short shipped list
   (`mph`, `pH`, `nmi`, `Ma`, `ka`, `gal`) that `u()` refuses with the
   intended spelling, since the value is wrong as well as the word.

c. **`unit_form: symbol` and a unit with no symbol.** Is `.word` on `year`, or
   on a `symbol: false` unit, a value error (as built, finding 15) or "ten
   years"? U4's reason ("five m") does not apply when there is no symbol.
   Recommend: print the name, since `symbol` cannot be honoured either way.

d. **`display:` and `unit =` that invert a value.** `display: "1/m"` on
   `unit: m`, value 3, reads with no problem as `0.3333333 [1/m]`, and
   `fmt_num(u(4, m), unit = "1/m")` → `0.3␣1/m`: udunits counts a reciprocal
   as convertible. One case is meant: `unit: L/(100*km)`, `display: km/L`
   gives `12.5␣km/L`. Recommend: refuse a `display:` whose dimension differs
   from `unit`'s, unless the author marks it (or document it). Claims and
   arithmetic would otherwise see the inverse.

e. **`units`' rewriting of tokens (finding 9).** Should `u()` keep the typed
   token where `units` substitutes another unit of the same dimension
   (Sv, Bq, Bd, VA)? The value is unaffected; the printed unit is not.
   Recommend: in `u_make()`, when the stored symbol differs from a typed
   database symbol, re-attach the typed one. Failing that, list the cases in
   4.4.17 instead of "keeps each token as written".

f. **A failed read leaves the previous project's table in use.** After a good
   knit of project A and a failed read of project B, `fmt_num()` outside a knit
   uses A's `units:`. (`weft_env$units` is set only after a successful read.)
   The ruling says "the last configuration read". Recommend: clear it on a
   failed read, so that nothing from A leaks into B's console work.

g. **Markdown in a project name and the English plural.** `name: "*site*"`
   prints `three *site*s` (HTML `<em>site</em>s`). U15 makes `units:` text
   markdown, and the plural rule appends to the markup. Recommend: document
   that a name with markup needs its own `plural:`.

h. **Prefixed years.** `u(5, Myr)` → `5␣megayears`, `u(5, kyr)` →
   `5␣kiloyears` by default, because `yr` has no symbol (U10). Geology writes
   "5 Myr" or "5 Ma". Recommend: leave it; a project gives `Myr: {symbol:
   Myr}`. Mention it in 4.4.17's notes.

i. **`.or` with a repeated 1.** `fmt_or(u(c(1, 1), m), unit_form = "name")` →
   `1 or 1␣metres`. An "or" picks one item, so a reader expects the singular.
   Recommend: as built (rare). Noted because U5's "exactly one number prints"
   was written for `.and`.

## Probed and sound

- **Names:** the expected-output table of the contract, rerun.
  - Prefixes by symbol and by name: `mL`, `ug`, `µg`, `dam`/`decametres`,
    `kilometers`, `uS/cm`.
  - Compounds: `m/s^2`, `kg/m^3`, `1/m^3`, `kW*h`, `g/(m^2*d)`, `m*m`, `mg/L/d`.
  - Powers: square and cubic only for a length (`ft^2`, `mi^2`, `L^2` →
    "litres squared"); a power of 4 is refused.
  - Durations: `d`, `h`, `min`, `s`, `week`, `month`, `fortnight`, `year`,
    `years`, `yr`; `yr^-1` and `1/yr`.
  - The angle and percent spaces: `%`, `°`, `°C`, `°/s`, `%/yr`.
  - `en-US`, `EN_us`, `en-AU`, `en`; `de` and `fr` with each form and setting.
- **Plurals:** at 0, 0.5, 1, 1.0, −1, 0.96, 1.04, `digits=0`, `sigfig=1`.
  - Collapses: `.and`, `.or`, `trunc` 1 and 2, `.range` with ends equal and
    unequal, `.pairs`, `.ul`, `.ol`, `.dl`.
  - An uncollapsed vector, `glue_vec()`, `NA`, length zero with and without
    `none`, and the zero rule with `.uname` and `.no`.
- **Spans, chains and project formatters:** `#` in `n`, `sign` and `list`
  spans with each unit class; `n="."` inherited both ways; `plural()` on a
  quantity and on texts. Chains `fmt_num(fmt_word())`, `fmt_word(fmt_num())`,
  `fmt_and(fmt_count())`, subsetting, `.strong`/`.cap`/`.a`. Project
  number, wording, collapse and text formatters with units.
- **Settings:** precedence default < `_weft.yml` < front matter < `display:` <
  `unit=`, and front matter replacing a project entry whole. Two knits with
  different tables in one session, and a project with no `_weft.yml` after
  one with a table.
- **The `units:` problems:** every listed problem, collected in one error
  naming each file, in draft mode too. A failed read registers nothing.
- **`display:`:** conversion, its three problems, `dict_local`, `print()`, the
  `entries` column, claims against a converted entry, `drop_units()`.
- **Construct errors** from the source, collected with markers; value errors
  in a knit collected with markers.
- **Output:** HTML output of names, `^2^`, `′`/`″`, a project `symbol:` with a
  space, and the no-break space.

Not covered: Quarto renders.
