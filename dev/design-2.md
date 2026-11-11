# Stage 2 — internal contract: dictionary, quantities, ledger

Written before any test or code. `PACKAGE-SCOPING.md` (the spec) says what
the package does; this note splits stage 2 (§22) into packages, fixes the
internal contract of the first two, outlines the rest, and records the gaps
it closes. Where this note and a numbered rule disagree, the rule wins and
the disagreement is reported. The stage 1 notes (`design-1a.md` to
`design-1i.md`) still hold; the hooks stage 2 needs from them are listed
under "Hooks into stage 1".

## 1. Work packages

| Package | Scope | Rules | Depends on | Adds | Touches |
|---|---|---|---|---|---|
| **2a** dictionary object | `read_dict()`, the schema, `dict` and `dict_local` in a knit, the seven types, registering units, `u()` | 4.1–4.3, 4.4.1, 4.4.5–4.4.7, 4.4.11, 9.1.2 (`dict_local`) | stage 1 | `R/dict.R`, `R/units.R`, `tests/testthat/_dict/`, `test-dict.R`, `test-dict-knit.R` | `R/config.R`, `R/hooks.R`, `R/state.R`, `R/weft-str.R`, `R/format.R` (years only), `R/claim.R` (one hint), `NAMESPACE` |
| **2b** printing quantities | any `units` value through the four formatter stages, the `fmt_*()` functions, governors and phrase functions | 1.4.9, 3.4.4, 4.4.2–4.4.4, 4.4.8–4.4.10 | 2a (`u()`, a dictionary to read quantities from) | `test-units-print.R` | `R/format.R`, `R/phrases.R`, `R/resolve.R` (governor path only, if needed) |
| **2c** dictionary tooling | the schema file, `use_dictionary()`, the glossary, `dict_vale()`, `dict_seed()`, the `decision:` resolver | 4.5, 4.7, 9.3.1, 9.3.3, 9.5.2 | 2a | `R/dict-tools.R`, `inst/dict/` | `R/use.R`, `R/config.R` |
| **2d** ledger and condition log | ledger records, key, one file per source and output; the committed condition log with carried-forward text | 7.1, 7.4.1 (first three sources), 7.4.3–7.4.6, 9.3.2 | stage 1 records; 2b (a quantity's printed text) | `R/ledger.R`, `test-ledger.R`, `test-condition-log.R` | `R/resolve.R`, `R/conditions.R`, `R/hooks.R`, `R/collect.R` |
| **2e** pipeline and `changes()` | `tar_dict()`, `tar_dict_deps()`, the `.qmd` scan of 4.6.5, the targets a chapter reads, `tar_meta()` conditions, the third state, `changes()` | 4.6, 7.2, 7.3, 7.4.1 (fourth source) | 2a, 2d | `R/targets.R`, `R/changes.R` | `R/ledger.R` |

Why this split. 2a gives values and 2b prints them: the formatter stages are
the riskiest change to stage 1 and get their own review. Registering units
and `u()` sit in 2a because a dictionary with a `quantity` entry cannot be
read without them. 2c needs no `targets` and no git. 2d writes files at the
end of a knit and needs no git or `targets` either. Everything that reads
git history or a `targets` store is in 2e, so the machine-dependent tests
are in one place. 2e is the largest; it may split into 2e (pipeline) and 2f
(`changes()`) when its contract is written.

## 2. Package 2a — the dictionary object (full contract)

### Exported

`read_dict()`, `u()`, and S3 methods for class `weft_dict`: `$`, `[[`, `[`,
`$<-`, `[[<-`, `[<-`, `print`, `as.list`.

### The file and the schema

The project dictionary is `dict.yml` at the project root (the root of
`design-1a.md`: `_weft.yml`, else `_quarto.yml`, else the input's folder). It
is a YAML mapping from key to entry. An empty file, or one holding only
comments, is a dictionary with no keys.

| Field | Type | Required | Notes |
|---|---|---|---|
| `value` | by `type` (table below) | yes | |
| `type` | one of `number`, `quantity`, `year`, `date`, `string`, `labels`, `breaks` | yes | any other is an error (4.2.1) |
| `definition` | string, not blank | yes | the glossary's text (4.7.1) |
| `unit` | string, not blank | for `quantity` only | on any other type, an error |
| `decision` | whole number ≥ 1, or a string that is not blank | no | not resolved when read (4.5.2) |
| `why` | string, not blank | local entries only | required there (4.3.3); in `dict.yml`, an error |

Any other field is an error. Keys: a valid R symbol (`make.names(k) == k`,
so no reserved word), and not `file` (4.1.3).

| `type` | `value` in YAML | Read as |
|---|---|---|
| `number` | a number, or a string that is a number literal (`"1e-3"`) | a double |
| `quantity` | as `number`, with `unit` | `units::set_units(value, unit, mode = "standard")` |
| `year` | a whole number 1000–9999 (or such a string) | an integer with attribute `weft_type = "year"` |
| `date` | a string `YYYY-MM-DD` that is a calendar date | a `Date` |
| `string` | a string (a YAML number is an error: quote it) | a character string |
| `labels` | a non-empty mapping, every value a string | `lookup(c(key = phrase, ...))` |
| `breaks` | a non-empty sequence of mappings (below) | `brk(...)` |

A `breaks` item is a mapping with `phrase` (a string) and at most one of
`below` (`. < b`) or `at_most` (`. <= b`), where `b` is a number, `.inf` or
`-.inf`. Only the last item may have no bound (it takes every value left).
Bounds may not decrease. The formulas are built with `baseenv()` as their
environment. (This layout is open with Robin, §5 R1.)

YAML is read with `yaml::read_yaml(path, handlers = list("bool#yes" =
identity, "bool#no" = identity))`, so `yes`, `no`, `on`, `off`, `true` and
`false` stay as text (a `labels` map keyed `yes`/`no` otherwise fails as a
duplicate key, `TRUE`). A duplicate key is an error.

Example (`tests/testthat/_dict/dict.yml`; made-up content):

```yaml
# yaml-language-server: $schema=_weft/dict.schema.json
min_samples:
  value: 5
  type: number
  definition: "Fewest samples a site needs before its mean is reported."
core_len:
  value: 0.5
  type: quantity
  unit: m
  definition: "Length of each sediment core."
reach_len: {value: 2, type: quantity, unit: m, definition: "Length of each surveyed reach."}
sample_mass: {value: 3, type: quantity, unit: kg, definition: "Mass of each bulk sample."}
salinity_res: {value: 0.01, type: quantity, unit: PSU, definition: "Logger resolution for salinity."}
coliform_limit: {value: 150, type: quantity, unit: "CFU/100 mL", definition: "Count that closes a swim site."}
site_density: {value: 4, type: quantity, unit: sites/ha, definition: "Planned density of survey sites."}
method_change:
  value: 2014
  type: year
  definition: "First year of the instrument method."
  decision: 31
survey_start:
  value: 2024-06-01
  type: date
  definition: "First day of the summer survey."
region_name:
  value: "Northern catchment"
  type: string
  definition: "Name used for the study region."
zone_lab:
  value: {upper: Upper reach, lower: Lower reach, yes: Included, no: Excluded}
  type: labels
  definition: "Display names for the survey zones."
  decision: "zones-2023"
trend_word:
  value:
    - {below: 0.95, phrase: "a fall in"}
    - {at_most: 1.05, phrase: "steady"}
    - {phrase: "a rise in"}
  type: breaks
  definition: "Wording for the ratio of this year's mean to last year's."
```

### `read_dict(path = "dict.yml")`

- `path`: one string naming an existing file, else `weft_dict_error`.
- Reads and validates every entry, then registers units (below), and
  returns a `weft_dict`. All problems are collected and raised together as
  one `weft_dict_error` whose message starts `weft: <path>: N problem(s) in
  the dictionary` and has one line per problem: `<path>:<line>: \`<key>\`:
  <what is wrong> (rule <n>)`. `<line>` is the line of the key's own
  `key:` line, found by pattern; it is left out when not found. A YAML
  syntax error, or a top level that is not a mapping, is one problem with
  no key. Each problem names the field (`value`, `type`, `unit`, …); an
  unknown `type` lists the seven; an unknown field names it and lists the
  allowed ones.
- Errors are never warnings; nothing is half-read.

### Registering units (4.4.7)

For each `unit` string: its tokens are the maximal runs of characters other
than white space, digits and `*/^().+-`. Each token that
`units::as_units(token)` cannot parse is installed with
`units::install_unit(token)`. Then `units::as_units(unit)` must parse, else
a problem naming the unit and quoting the `units` message. A token already
known is never installed again (`install_unit()` errors on a second call),
so reading a dictionary twice in a session is silent and idempotent. The
tokens installed are kept in attribute `registered`. Installing is
session-wide.

### The object

A `weft_dict` is a named list of the values, in file order, with class
`"weft_dict"` and attributes:

| Attribute | |
|---|---|
| `file` | the path as given (local: the document's path) |
| `scope` | `"project"` or `"local"` |
| `entries` | data frame: `key`, `type`, `definition`, `unit`, `decision` (character), `why`, `line`; `NA` where absent |
| `registered` | character: unit symbols this read installed |
| `local_keys` | character: in a knit, the keys of the chapter's `dict_local`; else `character()` |

- `dict$k` and `dict[["k"]]`: exact match only, never partial, never `NULL`
  (4.1.2). On a project dict, `k` in `local_keys` is a
  `weft_dict_ambiguous` error: `` `dict$k`: this chapter defines a local `k`;
  read it as `dict_local$k` (rule 4.3.2).`` Otherwise a key not held is a
  `weft_dict_key_error`: `` `dict$k`: no such key in <file> (rule 4.1.2).``,
  plus `` Did you mean `x`?`` when exactly one key is within edit distance 2.
  `dict[[i]]` with a number, or with anything but one string, is a
  `weft_dict_key_error`.
- On a local dict the accessor is named `dict_local` in messages; a key not
  held: `` `dict_local$k`: this chapter defines no local `k` (rule 4.3.2).``,
  plus `` The project's entry is `dict$k`.`` when the project holds `k`.
- Every error class here also carries `weft_error` (as `weft_abort()`
  gives).
- `dict[...]` is a `weft_dict_error`: `use dict$key or dict[["key"]]`.
- `$<-`, `[[<-`, `[<-` are a `weft_dict_error`: `the dictionary is
  read-only; change dict.yml (rule 4.1.4).`
- `names()`, `length()` work as on a list. `as.list()` returns the plain
  named list of values.
- `print()` writes a header `<weft_dict> <file>: N keys`, then one line per
  key: key, type, and a short value (`0.01 PSU`; a date as `2024-06-01`;
  `labels`/`breaks` as `<n> labels`/`<n> bands`), then, when any,
  `Units registered: PSU, CFU, sites`. Tests match it loosely.

### `dict_local` (4.3)

- Written in a document's front matter under `weft:` / `dict_local:`, a
  mapping in the form of the schema plus `why`. The front matter is
  re-parsed for this with the same boolean handlers.
- `dict_local` in `_weft.yml` is a `weft_config_error`: `` `dict_local` is
  written in a document's front matter, not in _weft.yml (rules 4.3.4,
  9.1.2).``
- A local key need not exist in `dict.yml`, and its type is not compared
  with the project entry's.
- Problems are raised as for `read_dict()`, with the document's path, as
  `weft_dict_error`.

### In a knit (2.1.5)

At knit initialisation (`init_knit()`), after the configuration is read:

1. When the project root holds `dict.yml`, it is read with `read_dict()`.
2. The document's `dict_local` entries, if any, are read into a local
   `weft_dict`.
3. When either exists: the project dict's `local_keys` is set to the local
   keys; `dict` (when `dict.yml` exists) and `dict_local` (always, empty when
   the document has no local entries) are assigned into
   `knitr::knit_global()`, replacing what was there. They are also kept in
   the knit state and returned by `last_knit()` as `$dict` and `$dict_local`
   (`NULL` when absent).
4. A `weft_dict_error` here stops the knit, in draft mode too.

A child knit uses its parent's objects. Every top-level knit re-creates
them. Nothing is read when the hooks are installed.

Errors met while a value is evaluated behave as any R error there does in
stage 1: in a construct, a "no value" failure whose detail quotes the
message (so it names the key); in a bare value or chunk code, the knit stops
as stock knitr stops.

A chunk served from knitr's cache that read `dict` is not re-run when
`dict.yml` changes (decision D22).

### `u(value, unit)` (4.4.6)

- `unit` is a unit expression taken as written and never evaluated as R:
  `u(35, m)`, `u(5, mg/L)`, `u(1, m^2)`, `u(0.05, PSU)`; or a string,
  `u(150, "CFU/100 mL")`.
- `value` is a numeric vector or a `units` object (then converted:
  `u(dict$core_len, cm)` is 50 cm).
- Returns a `units` object.
- `u()` does not register units. An unknown unit is a `weft_unit_error`:
  `` u(): `NTU` is not a unit the units database knows. A project's own
  unit is registered when the dictionary that names it is read (rule
  4.4.7), or with units::install_unit().`` A unit that does not convert
  (`u(dict$core_len, kg)`), a non-numeric `value`, or a missing `unit` is a
  `weft_unit_error` that quotes the `units` message or says what is wrong.
- `u` joins `claim`, `plural`, `glue_vec` and `fmt_*` on the search path
  that `weft_setup()` attaches (2.1.8), so inline R and chunk code can call
  it without `library(weft)`.

### Arithmetic and checks (4.4.1, 4.4.5)

All arithmetic is the `units` package's; weft adds nothing. A check that
compares a quantity with a bare number errors in `units`; under `claim()`
that is a failed check (ruling F of `design-1a.md`). When the error's
message contains `both operands of the expression should be "units"
objects`, the failure's hint is `state the check's unit, as in . <
u(0.45, ug) (rule 4.4.5)`.

### Years (4.2.1)

A value with attribute `weft_type = "year"` is printed by the number stage
with no thousands mark, whatever `thousands_from` says: `{.num}` on
`dict$method_change` prints "2014". Arithmetic keeps the attribute (R copies
attributes), so `dict$method_change + 1` prints "2015". A bare value prints
as stock knitr prints it ("2014").

### Rules met in 2a

4.1.1 `read_dict()`, creation at init. 4.1.2 `$`/`[[` methods. 4.1.3 key
check. 4.1.4 at runtime only for `$<-` and friends; the lint is stage 3.
4.2.1 schema. 4.2.2 not checkable (a stipulation is a human judgement).
4.2.3 `labels` → `lookup()`. 4.3.1–4.3.4 `dict_local`, ambiguity, `why`.
4.4.1, 4.4.5 the `units` package. 4.4.6 `u()`. 4.4.7 registering. 4.4.11
already met (`units` is in Imports).

## 3. Package 2b — printing quantities (full contract)

No new exports. Every formatter class, the `fmt_*()` functions and
`glue_vec()` accept a `units` value. Below, `␣` is U+00A0.

### The unit's text

From `as.character(units(x), neg_power = FALSE)`:

1. A value with no unit left (empty numerator and denominator, e.g. a
   ratio of metres to metres) prints the number alone (4.4.8).
2. Each `^n` (an integer, perhaps negative) becomes superscript characters
   (`⁰¹²³⁴⁵⁶⁷⁸⁹`, minus `⁻`).
3. Each `*` becomes `⋅` (U+22C5).
4. Nothing else is changed: `°C`, `mg/L`, `mm/h` (from `mm/hr`), `sites/ha`,
   `CFU/(100mL)`, `%`, `ug` are printed as `units` writes them.

The number and the unit are joined by U+00A0, for every unit (§5 R3).

### Through the stages (4.4.2, 4.4.3, 4.4.8, 1.4.9)

- **Stage i.** The number stage formats the number (`units::drop_units()`)
  exactly as it formats a plain number; the record's `number` and `raw` hold
  the number without its unit. A project formatter (1.4.8) receives the
  bare number; weft adds the unit after it.
- **Stage ii.** An element that a wording class turns into a word, or that
  `.no` turns into "no", takes no unit. An element still in digits
  (`.count` at or above its threshold, `.word` at or above its limit, `.ord`)
  takes it.
- **Stage iii.** `.and`, `.or`, `.range` and `glue_vec()`: the unit once,
  after the last number printed, when that element is in digits. With
  `trunc`, the last number printed is the one before "and N others".
  `.pairs`, `.ul`, `.ol`, `.dl`, and a vector no collapse class joins
  (1.4.10): every element in digits takes it. A project collapse formatter
  receives each element with its unit.
- **Stage iv.** Text classes act on the text with its unit.
- `.pct`, `.p` and `.date` on a value that has a unit are a
  `weft_value_error`: `` `.pct` cannot format a quantity in m: give it a
  number with no unit (rule 4.4.8).`` A value with no unit left is a plain
  number to them.
- A missing element (`NA`) is the "no value" failure, as for a number.

The `weft_text` returned carries attribute `unit` (the unit's text, or
absent) beside the record, which does not hold it (4.4.4). A number-stage
formatter given such a `weft_text` formats `raw` afresh and adds the unit
again; a collapse given one places it as stage iii says. So
`fmt_and(fmt_num(u(c(3, 5, 7), m)))` is "3, 5 and 7␣m".

### Governors and bare values

- An `n`, `sign` or `list` governor that is a quantity contributes its
  number (4.4.9): it is formatted with `governor = TRUE`, which never adds a
  unit, so `#` never carries one (4.4.4). `plural(u(1, m), "# metre",
  "# metres")` is "1 metre".
- A bare value prints as stock knitr prints it: the number alone (4.4.10).

### Phrase functions

`of_n()` and `about()` use the number of a quantity. `ci()`, `pm()` and
`clamp()` given a quantity that has a unit are a `weft_value_error`:
`` `ci()` does not take a quantity with a unit; pass the numbers, or format
the parts with fmt_num().`` (D28.)

### Expected output (default configuration; `x` is `dict$core_len`, `y` `dict$reach_len`)

| Value | Construct or call | Prints |
|---|---|---|
| `x * 100` | `{.num}` | `50␣m` |
| `x / y` | `{.num digits=2}` | `0.25` |
| `x / y` | `{.pct}` | `25%` |
| `x * y` | `{.num}` | `1␣m²` |
| `x + dict$sample_mass` | any | "no value" failure quoting `cannot convert kg into m` |
| `dict$salinity_res * 2` | `{.num digits=2}` | `0.02␣PSU` |
| `u(5, sites) / u(2, ha)` | `{.num}` | `2.5␣sites/ha` |
| `u(9.81, m/s^2)` | `{.num}` | `9.8␣m/s²` |
| `u(1, kg*m)` | `{.num}` | `1␣kg⋅m` |
| `u(20, degC)` | `{.num}` | `20␣°C` |
| `u(1200, m)` | `{.sci}` | `1.2 × 10^3^␣m` |
| `u(c(3, 5), m)` | `{.range}` | `3–5␣m` |
| `u(c(-3, 5), m)` | `{.range}` | `−3 to 5␣m` |
| `u(c(3, 5, 7), m)` | `{.and}` / `{.or}` | `3, 5 and 7␣m` / `3, 5 or 7␣m` |
| `u(c(3, 5, 7, 9), m)` | `{.and trunc=2}` | `3, 5␣m and 2 others` |
| `u(c(a = 3, b = 5), m)` | `{.pairs}` | `a (3␣m) and b (5␣m)` |
| `u(c(3, 5), m)` | no class | `3␣m, 5␣m` |
| `u(3, sites)` / `u(12, sites)` | `{.count}` | `three` / `12␣sites` |
| `u(3, m)` | `{.word}` | `three` |
| `u(0, m)` | `{.no}` | `no` |
| `u(8, m)` / `u(3, m)` | `{.a}` / `{.strong}` | `an 8␣m` / `**3␣m**` |
| `u(3, m)` | `{.pct}` | value error naming `.pct` and `m` |
| `x` | `[# metre \| # metres]{n="dict$core_len"}` | `0.5 metres` |
| `x` | bare `` `r dict$core_len` `` | `0.5` |

Pandoc's markdown writer may write U+00A0 as `\ `: tests compare after
turning `\ ` into U+00A0.

### Rules met in 2b

1.4.9, 3.4.4, 4.4.2, 4.4.3, 4.4.4, 4.4.8, 4.4.9, 4.4.10.

## 4. Later packages (outline)

### 2c — dictionary tooling

- `use_dictionary(path = ".")`: says what it will write, then writes
  `dict.yml` (when absent) with the `yaml-language-server` schema comment and
  one commented example entry, and `_weft/dict.schema.json` copied from
  `inst/dict/dict.schema.json` (a JSON Schema of §2's table). 9.3.1, 9.3.3.
- The glossary (4.7.1). To decide: a function returning markdown (a Pandoc
  definition list, key or a display term, then `definition`) that an author
  prints in a `results: asis` chunk, which writes nothing (P10); or a file
  under `generated/`. Recommended: the function, `dict_glossary(dict =
  read_dict())`. Also to decide: what term heads an entry (the key is an R
  symbol, not a phrase), which ties to R2.
- `dict_vale(dict = read_dict(), path = "styles/Weft/Terms.yml")`: a Vale
  `substitution` rule. Blocked on R2 (where the canonical spellings live).
- `dict_seed(paths = <the project's .qmd/.Rmd>)`: parses chunk code (no
  evaluation) for top-level `name <- <literal>` and `name = <literal>`, and
  returns a data frame `name`, `value`, `files`, `n` of names assigned in
  more than one file, with equal or differing values. To decide: whether
  differing values are listed (recommended: yes, flagged).
- The `decision:` resolver (4.5). Configuration key `decisions:` in
  `_weft.yml`: `github` (default), a glob with `{id}` (`decisions/{id}*.md`),
  or `pkg::fun` (a function of the id returning `TRUE`/`FALSE`). Internal
  `check_decisions(dict, config)` returns `key`, `decision`, `resolved`,
  `detail`; `verify()` (stage 5) calls it. Hard parts: the GitHub route
  needs the remote's owner and name (`git remote get-url origin`), network
  and, past 60 calls an hour, a token (`GITHUB_PAT`); whether it uses the
  `gh` CLI, base `url()` or a package. A string `decision` under `github`
  is an error.

### 2d — the ledger and the condition log

- Entries made by the `text` hook as each value, governed span and `cite`
  span resolves, and for every bare value (7.1.1, 7.1.2): key, kind,
  expression (parsed and deparsed, so spacing does not count), printed text,
  relation, raw value to 6 significant figures, file, section anchor, arm
  chosen, `#id`.
- Key (7.1.4): `#id`, else `(anchor, kind, expression, occurrence)`.
- Written by the `document` hook only in a set-up project, never in a
  rehearsal (9.3.2, 3.7.2), to `generated/ledger/<source path>/<output
  name>.jsonl`, sorted by key (7.1.5). The condition log beside it,
  `<output name>.conditions.jsonl`, one line per (source, class,
  normalised text), sorted, with `text` carried forward from the committed
  line while the normalised form matches (7.4.6).
- Must be decided before the contract: (1) the section anchor of text with
  no explicit anchor, and of text above the first heading; (2) the output
  name at knit time: under rmarkdown from `rmarkdown::render()`'s output
  file, under Quarto from `QUARTO_EXECUTE_INFO` or the `-o`/`params` case
  name — not yet known to be available (needs a probe; 7.1.3); (3) what a
  line holds so `changes()` can show the sentence (7.3.3; contradiction
  K3); (4) the exact JSON fields, which become a format committed to users'
  repositories (§5 R5); (5) JSON reading (jsonlite, §5 R4); (6) how the
  condition log's "text as first seen" is found: from the file on disk (the
  working tree), not from `HEAD`.
- Known hard parts: a child document's entries keyed under its own file or
  its parent's; constructs in captions and front matter (their section);
  a cached chunk's replayed conditions (stage 1 replays them; 2d writes
  them).

### 2e — the pipeline and `changes()`

- `tar_dict(path = "dict.yml")` (4.6.1): a `format = "file"` target
  `dict_file`, and one target `dict_<key>` per key whose command reads that
  key's value from `dict_file`. A changed definition re-runs `dict_<key>`
  but its value's hash is unchanged, so no consumer re-runs (4.6.3). This is
  why `file` is reserved (4.1.3): `dict_file` would collide.
- `tar_dict_deps(targets, path = "dict.yml")` (4.6.2): walks each target's
  command and the functions it calls (in `tar_option_get("envir")`) for
  `dict$key` and `dict[["key"]]`; an unknown key errors at definition
  (4.6.4); `dict[[k]]` or a bare `dict` depends on every key (4.6.6).
  Hard parts: setting dependencies on an existing target object (the spike
  wrote `t$command$deps` and `t$deps`, internals of targets 1.12.0, and
  copied targets with an internal of `tarchetypes`); making sure the global
  `dict` itself is not also a dependency, or a changed definition re-runs
  every reader; branching, parallel workers and functions in a package
  namespace (Q5); a worker process reading a `units` value whose unit was
  registered only in the main process (it must read the dictionary, or
  register, before it unserialises).
- 4.6.5: a `.qmd` rendered by `tarchetypes::tar_quarto()` scanned for
  `dict$key`. To decide: a wrapper (`tar_dict_quarto()`) or documenting
  `tar_dict_deps(list(tar_quarto(...)))`.
- The targets a chapter reads (7.2.2): static `tar_read()`/`tar_load()`
  names in its chunks (§5.8 rule 2 already reads them), plus their
  upstream from `tar_network()`; recorded with each target's `data` hash at
  render time in the ledger file's header line.
- The third state (7.2.1): an entry is not re-rendered when its chapter's
  recorded hashes differ from `tar_meta()` now, or when its chapter was
  served from freeze (the stamp of 2.9.2).
- `tar_meta()` conditions (7.4.1): `warnings` and `error` of each target
  read and upstream, logged with source = the target name.
- `changes(since = "HEAD")` (7.3): reads ledgers and condition logs from the
  working tree and from `git show <since>:<path>`; lists structural changes
  first (arm, sign, crossing 0, crossing 1.0, crossing a dictionary
  threshold, order of magnitude), then the rest ranked by a claim word
  beside the value; entries added and removed; new conditions; tier-2
  findings once stage 3 exists; marks entries not re-rendered. Writes
  nothing. To decide: how "crossing a dictionary threshold" is known (the
  ledger would need the dictionary keys an expression or its claim reads);
  the claim-word lexicon before stage 3 ships it; the printed layout and
  the returned object.

## 5. For Robin

Not decided. The contract is written so the build proceeds without an
answer.

- **R1 — the YAML layout of a `breaks` entry.** Options: (a) pairs
  `[bound, phrase]`, each meaning `. < bound`, the last bound `.inf`;
  (b) maps with `phrase` and one of `below` (`<`) or `at_most` (`<=`), the
  last with no bound; (c) the formulas of `brk()` as strings, parsed. (a) is
  shortest but cannot say `<=`, which `brk()`'s own example uses (3.3.3);
  (c) puts R code in a data file. Recommended: (b). Built as (b), in one
  internal parser; changing it touches that parser and the fixture.
- **R2 — where the canonical spellings for `dict_vale()` live (4.7.2).**
  The schema of 4.2 has no field for them. Options: (a) an optional `avoid:`
  list on `string` and `labels` entries, the value being the canonical form;
  (b) a new `type: term` with `value` the spelling and `avoid` the variants;
  (c) a separate `terms.yml`. Recommended: (a). 2a rejects `avoid` as an
  unknown field, so adding it later is additive; 2c's `dict_vale()` waits.
- **R3 — a space before `%` and `°`.** Rule 4.4.8 puts U+00A0 before every
  unit symbol (SI style: "35 %"), while `.pct` prints "35%". Options: keep
  the rule; or no space before `%`, and before `°` as an angle (SI's own
  exception for angles). Recommended: no space before `%` and angular `°`,
  so a document does not print both "35%" and "35 %". Built as the rule
  says; changing it touches one function in 2b.
- **R4 — `jsonlite` from Suggests to Imports.** The ledger and the
  condition log are JSON lines that `changes()` must read back. Stage 1
  writes JSON by hand and reads `QUARTO_EXECUTE_INFO` as YAML, which is
  fragile for arbitrary text (escapes). Recommended: Imports (small, no
  system requirement, ubiquitous). Needed from 2d; 2a and 2b do not need it.
- **R5 — the ledger's and the condition log's file format.** They are
  committed to users' repositories, so their fields and layout are hard to
  change. The 2d contract will propose them; recommended that Robin reads
  that section before 2d is built.
- **R6 — a printed symbol other than the `units` package's.** `units`
  rewrites `mm/hr` as `mm/h` and `CFU/100 mL` as `CFU/(100mL)`. An optional
  `symbol:` field on a `quantity` entry would let the author choose, but
  only for the entry's own unit, not one derived by arithmetic.
  Recommended: not now; wait for a real document that needs it.

## 6. What the spec leaves open, decided here

Alternatives, the choice, why, and where to reverse it.

| # | Gap | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| D1 | where the dictionary is | fixed name; a `dictionary:` setting | `dict.yml` at the root | the spec's examples; no setting to validate | add a setting read in `init_knit()` |
| D2 | where `dict` lives in a knit | `knit_global()`; the attached `weft:functions` env | `knit_global()` | a document object like any other, found before an attached package's `dict`; same in `rehearse()`. Cost: replaces a session's own `dict` | one assignment |
| D3 | the object | classed list; environment; R6 | classed list + attributes | `as.list()`, `names()`, `identical()`, serialising into a `targets` store all work; read-only by methods | `R/dict.R` |
| D4 | unknown field in an entry | warning (as `_weft.yml`); error | error | committed, hand-kept file: a misspelt `decison` would drop a pointer silently; later fields stay additive | one check |
| D5 | several problems | first only; all | all, one message | one read fixes the file | stop at the first |
| D6 | YAML booleans | `TRUE`/`FALSE`; text | text | `labels` keyed `yes`/`no`/`on` collide as `TRUE`; no logical type exists | drop the handlers |
| D7 | number written as a string | error; accept a number literal | accept | YAML 1.1 reads `1e-3` as text | one branch |
| D8 | how a year is marked | class `weft_year`; attribute; plain integer | integer + attribute `weft_type = "year"` | a class breaks `vctrs` (`vec_c()` refuses `<weft_year>` with `<integer>`, so `dplyr` code fails); a plain integer prints "2,014" under `{.num}`. Cost: the console shows the attribute | `R/dict.R`, one test in `R/format.R` |
| D9 | a date | ISO string; YAML timestamp | `YYYY-MM-DD` string (`yaml` returns text anyway) | | one parser |
| D10 | YAML number under `string` | coerce; error | error | `0.10` would become "0.1" | one branch |
| D11 | `decision` | number; number or string | either | the glob resolver's ids may be text | narrow the check |
| D12 | local entry with no project entry | required; not | not required, type not compared | smallest reading of 4.3.1 | a check in `R/dict.R` |
| D13 | `dict_local` as a setting | — | known setting, front matter only; in `_weft.yml` an error | 9.1.2 says "front matter only"; stage 1 warns it is unknown | `R/config.R` |
| D14 | empty `dict_local` | absent; empty object | empty object whenever `dict` exists, re-created each knit | 4.3.2 wants its error, not "object not found"; no chapter sees another's entries | assign only when there are entries |
| D15 | dictionary error in a draft render | collected; fatal | fatal, as a configuration error | every value downstream would be wrong | `init_knit()` |
| D16 | registering units | silent; message; allow-list | silent; listed by `print()` and `registered` | a message each knit is noise. Cost: a misspelt `mgg/L` registers a new unit; it fails at the first conversion, never compares silently | a message, or an allow-list (schema: Robin) |
| D17 | `u()`'s unit | evaluated; as written | as written, or a string; never registers | `u(35, m)` must not read a variable `m` | `R/units.R` |
| D18 | `u()` on the search path | not attached (2.1.8's list); attached | attached | 4.4's example calls it inline; 4.4.11 "always available" | one name |
| D19 | why `file` is reserved | — | the target `dict_file` of `tar_dict()` | the spec gives no reason | none |
| D20 | check against a bare number | `units`' message; plus a hint | plus a hint | the message does not say what to write | drop it |
| D21 | near-miss key | name only; suggest | one key within edit distance 2 | | drop it |
| D22 | cached chunk that read `dict` | leave; dictionary hash in the cache key | leave; say so in the help | a stage-1 policy change; §5.8 rule 7 already keeps target reads out of cached chunks | an option hook setting `cache.extra` |
| D23 | the unit's text | `units`' form; a weft symbol table | `units`' form, superscript exponents, `⋅` for a product, no `u`→`µ` | smallest change that gives "m²"; `units` accepts `µg` as written | one function |
| D24 | unit with `trunc`, or last item a word | — | after the last number printed; none if it is a word | literal 4.4.3 | one function |
| D25 | vector no collapse class joins | once; every element | every element | 4.4.3's "once" is for collapse classes; ", " is stock printing | one branch |
| D26 | project formatters | — | number stage gets the bare number, weft adds the unit (1.4.9); a collapse one gets each element with its unit | | `apply_project()` |
| D27 | `.pct`, `.p` on a quantity | use the number; error | error when a unit is left; a ratio is a number | dropping a unit is the silent error 4.4.5 forbids | one check |
| D28 | phrase functions | — | `of_n()`, `about()` take the number (they print words, 4.4.2); `ci()`, `pm()`, `clamp()` error on a unit | not guess where the unit goes | `R/phrases.R` |
| D29 | chained formatter calls | — | attribute `unit` on the `weft_text` | `fmt_and(fmt_num(x))` prints the unit once | `R/format.R` |
| D30 | a unit of "1" | — | no unit | 4.4.8's ratio | — |

## 7. Hooks into stage 1

Stage 2 changes no stage-1 behaviour except at these points:

| Where | What |
|---|---|
| `R/config.R` `default_config()`, `read_config()` | `dict_local` a known setting (no warning); in `_weft.yml` a `weft_config_error` |
| `R/hooks.R` `init_knit()` | read `dict.yml` and `dict_local`; assign into `knit_global()`; keep in state |
| `R/hooks.R` front matter | re-parse `weft: dict_local:` with the boolean handlers |
| `R/state.R` `new_state()`, `last_knit()` | `s$dict`, `s$dict_local`; `last_knit()$dict`, `$dict_local` |
| `R/weft-str.R` `inline_function_names()` | add `"u"` |
| `R/format.R` stage i | no thousands mark for `weft_type = "year"` (2a); `units` values (2b) |
| `R/claim.R` | the 4.4.5 hint |
| `R/phrases.R` | 2b's phrase-function rules |

## 8. Dependencies

| Package | In DESCRIPTION | Stage 2 | Recommendation |
|---|---|---|---|
| `units` | Imports | 2a, 2b | stays (4.4.11) |
| `yaml` | Imports | 2a | stays |
| `targets` | no | 2e | Suggests: only a pipeline project needs it; `tar_dict()` checks with `rlang::check_installed()` |
| `tarchetypes` | no | 2e (4.6.5, if wrapped) | Suggests, only if 2e wraps `tar_quarto()`; not for `tar_copy_targets()` (internal) |
| `jsonlite` | Suggests | 2d, 2e | Imports (R4) |
| `vctrs`, `codetools` | no | — | not needed (the walker is weft's own) |

No new dependency for 2a or 2b.

## 9. Tests for 2a and 2b

Fixtures: `tests/testthat/_dict/dict.yml` (the example above). Bad
dictionaries are written per case to a temp file (`withr::local_tempfile`).
Units registered by one test stay registered for the session, so tests do
not assume a unit is unknown unless they use a name no other test uses.

**`test-dict.R`** (no render):

- `read_dict()` on the fixture: class, `names()` in file order, each type's
  R class (`numeric`, `units`, `integer` with the year attribute, `Date`,
  `character`, function, function); `lookup` and `brk` behaviour of
  `zone_lab` (`"yes"` → "Included") and `trend_word` (0.9, 1, 1.05, 2).
- `$`: exact key; partial name errors (`dict$core` with `core_len` held);
  unknown key `weft_dict_key_error` naming the key and file; suggestion for
  `dict$core_lne`; `[[` the same; `[[1]]` errors; `[` errors; the three
  assignment forms error `weft_dict_error`.
- Schema errors, one case each, all `weft_dict_error`, message naming file,
  key, field and the line: missing `value`/`type`/`definition`; blank
  `definition`; unknown type (lists the seven); unknown field; `unit` on a
  `number`; `quantity` without `unit`; key `file`; key `2x`; key `if`;
  `year` 214 and 2014.5; `date` `2024-02-30`; `string` given `0.10`;
  `labels` empty and with a number value; `breaks` with a bound that
  decreases, with a bare item not last, with both `below` and `at_most`;
  `decision` 0 and `""`; `why` in `dict.yml`; duplicate key; YAML syntax
  error; a top level that is a list. A file with two problems lists both.
- Empty file: zero keys. `"1e-3"` under `number` reads as 0.001.
- Units: `PSU`, `sites` and `CFU/100 mL` read; reading twice is silent;
  `attr(d, "registered")`; an unparseable unit (`m//s`) is a problem.
- §18 arithmetic through `dict` (21 "Units"): `x * 100` is 50 m; `x / y` has
  no unit; `x * y` is m²; `x + dict$sample_mass` errors "cannot convert";
  `dict$salinity_res * 2` is 0.02 PSU; `u(5, sites) / u(2, ha)` is 2.5
  sites/ha; `x > 0.3` errors.
- `u()`: `u(35, m)`, `u(5, mg/L)`, `u(1, "CFU/100 mL")` after the fixture is
  read; `u(dict$core_len, cm)` is 50; unknown unit, non-numeric value,
  missing unit and `u(x, kg)` are `weft_unit_error`; `m` in the caller's
  environment is not evaluated.
- `claim(dict$core_len, . < u(1, m))` passes; `claim(dict$core_len, . < 1)`
  fails with class `weft_claim_failed` and the 4.4.5 hint.
- A year: `fmt_num(dict$method_change)` is "2014", `+ 1` is "2015".

**`test-dict-knit.R`** (`render_rmd(..., files = list("dict.yml" = ...))`;
batch cases where they do not interfere; one `both()` case for Quarto):

- `dict` is there in chunk code and inline without `library(weft)`; `u()`
  inline without `library(weft)`; `last_knit()$dict` is the object.
- An unknown key in a `{.num}` value: a "no value" failure whose detail names
  the key; in a bare value the knit stops with that message.
- `dict_local` from front matter (with a `yes:` label); `dict_local$k` with
  no local `k`: error naming 4.3.2 and pointing at `dict$k`; `dict$k` where
  the chapter defines `k`: `weft_dict_ambiguous`; a local entry without
  `why`: the knit stops with `weft_dict_error`, in draft mode too.
- `dict_local` in `_weft.yml`: `weft_config_error`. `dict_local` under a
  document's `weft:` gives no unknown-setting warning.
- Two knits in one session: the second document, with no local entries, has
  an empty `dict_local`.
- `{.num}` on the year prints "2014"; a bare value prints "2014".
- A failed check against a bare number is a failed claim with the hint.

**`test-units-print.R`** (2b): every row of the table in §3 through the
function forms (`fmt_*()`, `glue_vec()`, `plural()`), and through one
batched `.Rmd` render for the construct forms and the span; `\ ` normalised
to U+00A0; the `weft_text` attributes (`number`, `raw` without unit,
`unit`); `.pct` on `x / y` and on a unit; `ci()`/`pm()`/`clamp()` errors;
`of_n()` with quantities; the record of a governor holds no unit. One
`both()` case for a quantity under Quarto.

**Not testable on this machine:** Windows and Linux installation of `units`
(udunits-2; §19); the Render buttons (Q2). For 2e later: branching and
parallel workers with `tar_dict()` (Q5) need a toy pipeline under
`tests/testthat/_targets/`, run with `callr`, skipped on CRAN.

## 10. Contradictions

- **K1 — 4.4.4 against 3.4.2 and 3.4.4.** 4.4.4: "the printed record does
  not hold" the unit. 3.4.2: a formatter function returns a `weft_text`
  holding the record; 3.4.4: given a `units` value it prints the unit. Read
  here as: the text includes the unit, the record's `number` does not, and a
  governor never adds one (§3). The wording of 4.4.4 needs a clause.
- **K2 — 2.1.8 against 4.4.6/4.4.11.** 2.1.8 lists the functions attached
  for inline R without `u()`; 4.4's example calls `u()` inline and 4.4.11
  says it is always available. D18.
- **K3 — 7.1.1 against 7.3.3.** The ledger's fields (7.1.1) hold no
  sentence, but `changes()` shows "each changed entry as its sentence
  before and after" without rendering (7.3.6). The before-sentence exists
  only in `HEAD`'s ledger, so the ledger must store it. Also 7.3.4's
  "crossing a dictionary threshold" needs the dictionary keys an entry was
  compared with, which 7.1.1 does not record. For 2d.
- **K4 — 9.1.2/4.3.4 against built stage 1.** `dict_local` is a front-matter
  setting, but 9.1.5 does not list it and stage 1's `read_config()` warns
  "Unknown weft setting `dict_local`". D13.
- **K5 — 4.2.1, text against table.** "`unit` and `decision` are optional",
  but the table makes `unit` part of a `quantity`. Read as: required for
  `quantity`, an error elsewhere.
- **K6 — 4.2.1 `breaks` against 3.3.3.** "A list of bound and phrase" cannot
  express `brk()`'s own `. <= 1.05`. R1.
- **K7 — 4.7.2 against 4.2.** `dict_vale()` writes rules "from the canonical
  spellings", which the schema has no field for. R2.
- **K8 — 4.4.8 against `.pct`.** A unit symbol always follows a no-break
  space ("35 %"), while `.pct` prints "35%". R3.

Two further frictions are not rule conflicts and are listed as 2d/2e hard
parts: a per-key target holding a `units` value read by a worker that has
not registered its unit (4.6.1 with 4.4.7), and the output name that
7.1.3 keys the ledger on, which a Quarto knit may not be told.
