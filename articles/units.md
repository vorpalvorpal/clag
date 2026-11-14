# Units and the dictionary

This article is for authors whose numbers have units, and for projects
that fix some values by choice: a trigger level, a reporting year, the
name of a study area. After it you will be able to print a number with
its unit in the right form, convert it as you print it, give weft the
names of your own units, and keep a project’s chosen values in one
dictionary file that every document and pipeline reads.

``` r

library(weft)
```

## Quantities

A **quantity** is a number with a unit.
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) makes one.
The unit is written as it is, never evaluated as R, or as a string:

``` r

u(35, m)
#> 35 [m]
u(5, mg/L)
#> 5 [mg/L]
u(150, "CFU/100 mL")
#> 150 [CFU/(100mL)]
```

[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) is a short
form of
[`units::set_units()`](https://r-quantities.github.io/units/reference/units.html),
and all arithmetic is the units package’s. Units combine, cancel and
convert, and adding two units that do not convert is an error:

``` r

u(3, m) + u(20, cm)
#> 3.2 [m]
u(3, m) / u(50, cm)
#> 6 [1]
u(3, m) + u(2, kg)
#> Error:
#> ! cannot convert kg into m
```

A quantity cannot be compared with a bare number. A check states its
unit:

``` r

claim(u(3, m), . > 2)
#> Error:
#> ! weft: 1 failed claim
#>   check `. > 2` raised an error: both operands of the expression should be "units" objects (value: 3 [m])
#>     state the check's unit, as in . < u(0.45, ug) (rule 4.4.5)
claim(u(3, m), . > u(2, m))
#> 3 [m]
```

## Printing a quantity

A formatter prints the unit after the number, separated by a no-break
space. You do not type the unit in the prose.

``` r

fmt_num(u(35, m))
#> <weft_text>
#> [1] "35 m"
fmt_num(u(1.2, m^2))
#> <weft_text>
#> [1] "1.2 m^2^"
fmt_num(u(20, degC))
#> <weft_text>
#> [1] "20 °C"
fmt_num(u(35, "%"))
#> <weft_text>
#> [1] "35%"
fmt_num(u(7.2, pH))
#> <weft_text>
#> [1] "pH 7.2"
```

The symbol text is Pandoc markdown, so `m^2^` renders as a superscript.
Some units have no space before them (`%`, `°`), and `pH` goes before
the number.

### Symbol or name

A unit prints in one of two **forms**: its symbol (“5 m”) or its name
(“five metres”). By default the form follows the number: digits take the
symbol, and a spelled number takes the name.

``` r

fmt_num(u(3, m))
#> <weft_text>
#> [1] "3 m"
fmt_word(u(3, m))
#> <weft_text>
#> [1] "three metres"
```

Three unit classes choose the form for one value: `.usym` the symbol,
`.uname` the name, `.nounit` no unit at all. In R code the same choice
is the `unit_form` argument:

``` r

fmt_num(u(5, m), unit_form = "name")
#> <weft_text>
#> [1] "5 metres"
fmt_num(u(1, m), unit_form = "name")
#> <weft_text>
#> [1] "1 metre"
fmt_num(u(5, m), unit_form = "none")
#> <weft_text>
#> [1] "5"
fmt_num(u(12, NTU), unit_form = "name")
#> <weft_text>
#> [1] "12 nephelometric turbidity units"
```

A name is singular only when its number prints as “1” or “one”. The
setting `unit_form` (`auto`, `symbol` or `name`) in `_weft.yml`, or
under a document’s `weft:` key, changes the default for a project or a
document.

[`fmt_unit()`](https://vorpalvorpal.github.io/weft/reference/fmt_unit.md)
prints the unit alone, for a table heading:

``` r

fmt_unit(u(5, mg/L))
#> <weft_text>
#> [1] "mg/L"
fmt_unit(u(5, mg/L), unit_form = "name")
#> <weft_text>
#> [1] "milligrams per litre"
```

### Converting as you print

The key `unit="m"` on a value or a span, and the argument `unit` in R
code, print the quantity in another unit. The number, the unit and the
arm a span chooses are all in that unit:

``` r

fmt_num(u(150, cm), unit = "m")
#> <weft_text>
#> [1] "1.5 m"
```

A **ladder** is a list of units you accept, separated by `|`. weft
prints the quantity in the first unit that gives a number from 1 up to
1,000:

``` r

fmt_num(u(2500, m), unit = "mm|m|km")
#> <weft_text>
#> [1] "2.5 km"
fmt_num(u(0.004, m), unit = "mm|m|km")
#> <weft_text>
#> [1] "4 mm"
```

A vector takes one unit for all its numbers, the one where most of them
fit:

``` r

fmt_num(u(c(0.4, 2500), m), unit = "mm|m|km")
#> <weft_text>
#> [1] "400 mm"       "2,500,000 mm"
```

Inside a pipe-table cell, write the ladder’s bars as `\|`.

### Lists of quantities

A list prints the unit once, after the last item. `.pairs`, `.ul`, `.ol`
and `.dl` print it with each item.

``` r

fmt_and(fmt_num(u(c(3, 5, 7), m)))
#> <weft_text>
#> [1] "3, 5 and 7 m"
fmt_range(u(c(3, 5), m))
#> <weft_text>
#> [1] "3–5 m"
```

### Quantities that print as zero

A small quantity that prints as “0.0” records the same warned check as a
plain number, and the message suggests a prefixed unit where one would
help:

``` r

fmt_num(u(0.04, m))
#> Warning: weft: 0.04 printed as 0.0: add sigfig to show it, or digits to confirm
#> it; or show it in a prefixed unit, such as unit = "mm"
#> <weft_text>
#> [1] "0.0 m"
```

## In a document

This document reads a project dictionary and a `units:` table, both
shown further down.

```` markdown
---
title: "Units"
output: html_document
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
weft:
  dict_local:
    lab_sites:
      value: 4
      type: number
      definition: "Sites sent to the laboratory in this chapter."
      why: "Only the autumn survey sent samples away."
---

```{r data}
depth <- u(c(0.42, 0.65, 1.31), m)
visited <- u(12, sites)
core <- u(150, cm)
last_year <- 2024
```

The reach is `r dict$reach_len`{.num} long, or `r dict$reach_len`{unit="m"}.

Depths were `r depth`{.num .and}, a range of `r range(depth)`{.range}.

We visited `r visited`{.num}, and the cores were `r core`{.uname unit="m"} long.

[# core was | # cores were]{n="core" unit="m"} kept.

Turbidity above `r dict$trigger`{.num} is reported.

Salinity is logged to `r dict$salinity_res`{.uname}, or `r dict$salinity_res`{.uname sigfig="1"}.

Records start in `r dict$first_year`, and the logger ran for `r last_year - dict$first_year`{.word} years.

`r dict_local$lab_sites`{.word .cap} sites went to the laboratory.

The first depth was `r depth[1]`.
````

It renders as:

``` text
The reach is 2 km long, or 2,000 m.

Depths were 0.4, 0.7 and 1.3 m, a range of 0.4–1.3 m.

We visited 12 sites, and the cores were 1.5 metres long.

1.5 m cores were kept.

Turbidity above 10 NTU is reported.

Salinity is logged to 0.0 practical salinity units, or 0.01 practical
salinity units.

Records start in 2014, and the logger ran for ten years.

Four sites went to the laboratory.

The first depth was 0.42.
```

and the knit ends with two warnings, which do not fail the render:

``` text
weft: 2 warned check(s)
  units.Rmd:33  [printed as zero] `r dict$salinity_res`
      0.01 printed as 0.0: add sigfig to show it, or digits to confirm it
  units.Rmd:39  [unit warning] `r depth[1]`
      weft: `r depth[1]` is a quantity (0.42) and its unit is not printed. Add `{.num}` to print it with its unit, or `{.nounit}` to say the unit is not wanted (rule 4.4.10).
```

A bare value prints a quantity as knitr prints it, without the unit, and
weft warns because the reader loses the unit. Add `{.num}` to print it,
or `{.nounit}` to say you meant to drop it.

## Units weft does not know

weft starts from the units package’s database, and adds a table of its
own for units common in environmental reports:

``` r

unit_defaults()[, c("unit", "is", "name", "symbol", "before")]
#>          unit       is                         name     symbol before
#> 1          pH     base                           pH       <NA>   TRUE
#> 2         mph   1 mi/h                mile per hour       <NA>  FALSE
#> 3         nmi   1852 m                nautical mile       <NA>  FALSE
#> 4          Ma    1 Myr                million years       <NA>  FALSE
#> 5          ka    1 kyr               thousand years       <NA>  FALSE
#> 6         gal 1 gallon                       gallon       <NA>  FALSE
#> 7         ppm     <NA>             part per million       <NA>  FALSE
#> 8         ppb     <NA>             part per billion       <NA>  FALSE
#> 9         NTU     base nephelometric turbidity unit       <NA>  FALSE
#> 10        PSU     base      practical salinity unit       <NA>  FALSE
#> 11        CFU     base          colony-forming unit       <NA>  FALSE
#> 12        MPN     base                         <NA>       <NA>  FALSE
#> 13 CFU/100 mL     <NA>                         <NA> CFU/100 mL  FALSE
#> 14 MPN/100 mL     <NA>                         <NA> MPN/100 mL  FALSE
```

A unit that neither knows is an error:

``` r

u(5, sites)
#> Error:
#> ! u(): `sites` is not a unit the units database knows. A project's own unit is registered when the dictionary that names it is read (rule 4.4.7), or with units::install_unit(). The units package says: In 'sites', 'sites' is not recognized by udunits.
```

There are two ways to add one. A dictionary entry with that unit
registers it when the dictionary is read. The `units:` table in
`_weft.yml` registers it when the configuration is read, and gives it a
name, a plural, a symbol, or a definition. The document above used this
`_weft.yml`:

``` yaml
units:
  sites:
    name: site
    symbol: false
  PSU:
    name: practical salinity unit
```

`symbol: false` makes `sites` print by its name in every form (“12
sites”). The `PSU` row gives a name to a unit the default table already
has, so `.uname` can print it. Each row takes up to six fields:

| Field | Sets |
|----|----|
| `name` | the singular name |
| `plural` | the plural, when the English rule gets it wrong |
| `symbol` | the symbol text, or `false` for none |
| `space` | whether a space goes between the number and the symbol |
| `is` | what the unit is: `base`, a number, or an amount of another unit (`4.54609 L`) |
| `before` | `true` to write the unit before the number |

Some unit symbols mean something unexpected to the units package. weft
refuses those rather than print a wrong value:

``` r

u(5, mt)
#> Error:
#> ! u(): `mt` is read by the units package as a millitonne (`m` + `t`), which is 1 kg. Write `t` for a tonne, or `Mt` for a megatonne. To take that reading, set `unit_defaults: si` in _weft.yml (rule 4.4.20).
```

weft keeps the units tables in R’s user cache folder
(`tools::R_user_dir("weft", "cache")`) so that a new session starts
faster. `options(weft.units_cache = FALSE)` turns that off.

## The dictionary

The **dictionary** holds the values a project chose, as opposed to
values it computed. Each **entry** has a key, a `value`, a `type` and a
`definition`. It lives in `dict.yml` at the project root. This one has
an entry of every type:

``` r

writeLines(c(
  "trigger:",
  "  value: 10",
  "  type: quantity",
  "  unit: NTU",
  "  term: turbidity trigger",
  "  definition: \"Turbidity above which a site is reported.\"",
  "reach_len:",
  "  value: 2000",
  "  type: quantity",
  "  unit: m",
  "  display: km",
  "  definition: \"Length of the surveyed reach.\"",
  "min_samples:",
  "  value: 5",
  "  type: number",
  "  definition: \"Fewest samples a site needs in a season.\"",
  "do_band:",
  "  value: [6.5, 8.5]",
  "  type: range",
  "  unit: mg/L",
  "  definition: \"Acceptable band of dissolved oxygen.\"",
  "first_year:",
  "  value: 2014",
  "  type: year",
  "  definition: \"First year of the logger record.\"",
  "survey_start:",
  "  value: 2024-09-02",
  "  type: date",
  "  definition: \"First day of the spring survey.\"",
  "catchment:",
  "  value: \"Eastern catchment\"",
  "  type: string",
  "  definition: \"Name used for the study area.\"",
  "  avoid: [\"east catchment\"]",
  "tier_lab:",
  "  value: {ref: Reference, mod: Moderately disturbed, high: Highly disturbed}",
  "  type: labels",
  "  definition: \"Display names for the disturbance tiers.\"",
  "trend_word:",
  "  value:",
  "    - {below: 0.95, phrase: \"a fall in\"}",
  "    - {at_most: 1.05, phrase: \"no change in\"}",
  "    - {phrase: \"a rise in\"}",
  "  type: breaks",
  "  definition: \"Wording for this year's mean over last year's.\""
), "dict.yml")
```

| `type` | `value` | Read as |
|----|----|----|
| `number` | a number | a number |
| `quantity` | a number, with a `unit` | a quantity, in its `display` unit when it has one |
| `range` | two numbers, lower then upper, with an optional `unit` | a pair named `lower` and `upper`, a quantity pair when it has a unit |
| `year` | a four-digit year | a year, which never gets a thousands mark |
| `date` | `YYYY-MM-DD` | a `Date` |
| `string` | text | a string |
| `labels` | a map from key to phrase | a [`lookup()`](https://vorpalvorpal.github.io/weft/reference/lookup.md) function |
| `breaks` | a list of bands, each with `below` or `at_most` and a `phrase` | a [`brk()`](https://vorpalvorpal.github.io/weft/reference/lookup.md) function |

In a knit, weft reads `dict.yml` itself and makes the object `dict`, so
the prose and the chunks read `dict$trigger`. At the console,
[`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
reads it:

``` r

dict <- read_dict("dict.yml")
dict
#> <weft_dict> dict.yml: 9 keys
#>   trigger  quantity  10 NTU
#>   reach_len  quantity  2 km
#>   min_samples  number  5
#>   do_band  range  range 6.5 to 8.5 mg/L
#>   first_year  year  2014
#>   survey_start  date  2024-09-02
#>   catchment  string  Eastern catchment
#>   tier_lab  labels  3 labels
#>   trend_word  breaks  3 bands
#> Units registered: NTU
dict$reach_len
#> 2 [km]
dict$first_year + 1
#> [1] 2015
dict$tier_lab("mod")
#> [1] "Moderately disturbed"
dict$trend_word(1.02)
#> [1] "no change in"
fmt_range(range(c(dict$first_year, dict$first_year + 10)))
#> <weft_text>
#> [1] "2014–2024"
```

`dict$key` matches the key exactly. A key that is not there is an error,
never `NULL`, and the dictionary cannot be changed from R:

``` r

dict$triger
#> Error:
#> ! `dict$triger`: no such key in dict.yml (rule 4.1.2). Did you mean `trigger`?
dict$trigger <- 5
#> Error:
#> ! weft: the dictionary is read-only; change dict.yml (rule 4.1.4).
```

[`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
checks every entry and reports every problem in the file at once, each
with its line:

``` r

writeLines(c(
  "depth:", "  value: 010", "  type: number", "  definition: Mean depth.",
  "spot:", "  value: 3", "  type: count", "  definition: A spot check."
), "bad.yml")
read_dict("bad.yml")
#> Error:
#> ! weft: bad.yml: 2 problem(s) in the dictionary
#> bad.yml:1: `depth`: `value` is a whole number written with a leading zero, or in hex or octal; write it in decimal (rule 4.2.1)
#> bad.yml:5: `spot`: `type` `count` is not one of number, quantity, year, date, string, labels, breaks, range (rule 4.2.1)
```

Besides the three required fields, an entry may have `unit` and
`display` (quantities and ranges only; `display` only with `unit`),
`decision`, `term` and `avoid`. `decision` points at the record of why
the value was chosen, such as a GitHub issue number;
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
checks that each pointer resolves. The setting `decisions` in
`_weft.yml` says where pointers resolve: `github` (the default),
`github:<owner>/<repo>`, a file pattern such as `decisions/{id}-*.md`,
or a function. A typed number in prose, a `cite` span and a
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) can
carry a pointer too (see
[`vignette("wording", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/wording.md)).

### Bands: the `range` type and `in_range()`

A `range` entry holds an accepted band: two finite numbers, the lower
strictly below the upper. A limit on one side only is a `number` or
`quantity` entry. `.range` prints the band with the unit once, and
[`in_range()`](https://vorpalvorpal.github.io/weft/reference/in_range.md)
tests a value against it, bounds included:

``` r

dict$do_band
#> Units: [mg/L]
#> lower upper 
#>   6.5   8.5
fmt_range(dict$do_band)
#> <weft_text>
#> [1] "6.5–8.5 mg/L"
dict$do_band[["lower"]]
#> 6.5 [mg/L]
in_range(u(c(6.1, 7.2), mg/L), dict$do_band)
#> [1] FALSE  TRUE
```

In a document the test chooses the wording:

``` markdown
The acceptable band is `r dict$do_band`{.range}, and the mean was
[within | outside]{if="in_range(do_mean, dict$do_band)"} it.
```

A quantity is converted to the band’s unit first. A plain number against
a band with a unit, or a unit that does not convert, is a value error:

``` r

in_range(7.2, dict$do_band)
#> Error:
#> ! in_range(): `x` in no unit cannot be compared with a range in mg/L (rule 4.2.8).
```

[`in_range()`](https://vorpalvorpal.github.io/weft/reference/in_range.md)
gives `NA` where the value is `NA`. It is R only: a document the filter
resolves has no dictionary, so publish the result as a bool (see
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md)).
[`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
treats both bounds of a band as thresholds a value can cross.

### A chapter’s own values

A value that holds for one document only goes in that document’s front
matter, under `weft:` and `dict_local:`, with a `why` that says why it
is not in the project dictionary. The document above has one. It is read
as `dict_local$key`, never `dict$key`, so a reader of the source sees at
once that the value is local.

### The glossary

[`dict_glossary()`](https://vorpalvorpal.github.io/weft/reference/dict_glossary.md)
writes the dictionary as a Pandoc definition list. A chunk that calls it
is the glossary; it needs no `results: asis`:

``` r

cat(dict_glossary(dict))
#> 
#> `catchment` (Eastern catchment)
#> :   Name used for the study area.
#> 
#> `do_band` (6.5–8.5 mg/L)
#> :   Acceptable band of dissolved oxygen.
#> 
#> `first_year` (2014)
#> :   First year of the logger record.
#> 
#> `min_samples` (5)
#> :   Fewest samples a site needs in a season.
#> 
#> `reach_len` (2 km)
#> :   Length of the surveyed reach.
#> 
#> `survey_start` (2 September 2024)
#> :   First day of the spring survey.
#> 
#> `tier_lab`
#> :   Display names for the disturbance tiers.
#> 
#> `trend_word`
#> :   Wording for this year's mean over last year's.
#> 
#> turbidity trigger (10 NTU)
#> :   Turbidity above which a site is reported.
```

In a knit,
[`dict_glossary()`](https://vorpalvorpal.github.io/weft/reference/dict_glossary.md)
with no argument uses the knit’s dictionary.

### Spellings to avoid

`avoid` lists spellings that should be the entry’s `term`, or for a
string entry its value.
[`dict_vale()`](https://vorpalvorpal.github.io/weft/reference/dict_vale.md)
writes them as a rule for the prose linter [Vale](https://vale.sh). It
says what it will write first:

``` r

dict_vale(dict)
#> weft will write /tmp/RtmpIDYQZq/units-article/styles/Weft/Terms.yml: a Vale substitution rule with 1 avoided spelling(s) from dict.yml.
#> Wrote: /tmp/RtmpIDYQZq/units-article/styles/Weft/Terms.yml
#> Vale uses this rule when .vale.ini, at /tmp/RtmpIDYQZq/units-article, sets StylesPath = styles and lists Weft in BasedOnStyles.
cat(readLines("styles/Weft/Terms.yml"), sep = "\n")
#> # Generated by weft::dict_vale() from dict.yml. Do not edit: change the
#> # `avoid:` fields in dict.yml and run weft::dict_vale() again.
#> extends: substitution
#> message: "Use '%s' instead of '%s' (the project dictionary's spelling)."
#> level: warning
#> ignorecase: false
#> swap:
#>   'east catchment': 'Eastern catchment'
```

### Finding values to put in the dictionary

[`dict_seed()`](https://vorpalvorpal.github.io/weft/reference/dict_seed.md)
reads a project’s documents, runs nothing, and lists names that two or
more documents assign a literal value to, as candidates for the
dictionary:

``` r

writeLines(c("```{r}", "trigger <- 10", "n_sites <- 3", "```"), "spring.Rmd")
writeLines(c("```{r}", "trigger <- 10", "n_sites <- 4", "```"), "autumn.Rmd")
dict_seed(c("spring.Rmd", "autumn.Rmd"))[, c("name", "value", "differs", "n")]
```

    #>      name value differs n
    #> 1 n_sites  <NA>    TRUE 2
    #> 2 trigger    10   FALSE 2

`trigger` holds one value in both documents, so it is a stipulation that
belongs in `dict.yml`. `n_sites` differs, and the author decides what it
is.

[`use_dictionary()`](https://vorpalvorpal.github.io/weft/reference/use_dictionary.md)
writes a starter `dict.yml` and a schema that editors use to check it as
you type. See
[`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md).
