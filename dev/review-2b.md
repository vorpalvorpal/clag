# Review of package 2b — printing quantities

Snapshot: `git archive` of `5babe9d`, loaded with `pkgload::load_all()`;
renders through rmarkdown (`md_document`, `pdf_document`) and Quarto 1.11 (`markdown`, `html`, `pdf`,
`docx`) with the snapshot installed in a private library. `␣` is U+00A0.
`q <- u(c(3, 5, 7), m)`; `d` is `read_dict()` of the test fixture.

## Findings

**1. A PDF render fails, or silently loses glyphs, for any compound unit or
an exponent other than 1, 2, 3.**
Severity: crash (R Markdown); silent (Quarto).
- R Markdown `output: pdf_document` (pdflatex), body
  `` `r u(1, kg*m)`{.num} ``: the render stops with
  `LaTeX Error: Unicode character ⋅ (U+22C5) not set up for use with LaTeX`.
  `` `r u(3, m^4)`{.num} `` stops the same way on `⁴ (U+2074)`. `m²`, `m³`,
  `°C` and `µg` compile.
- Quarto `format: pdf` (xelatex, Latin Modern) with the same three values:
  the PDF is built, but the log has `Missing character: There is no ⋅
  (U+22C5)` and the same for `⁴` and `⁰`. pdftotext shows `3 m�`, `2 m¹�`,
  `1 kg�m`, so the PDF prints the wrong unit with no warning.
- HTML and docx are correct.
- Expected: a quantity prints "with its unit" in every output (4.4.8,
  1.4.9). D23 picked Unicode superscripts and `⋅` without checking LaTeX,
  and §3 covers only Pandoc's `\ `. (Pandoc's `^4^` would be safe in every
  format: see question f.)

**2. `#` carries the unit when the governor is the `weft_text` of a
quantity.**
Severity: wrong output.
- `weft_str('[# metre | # metres]{n="fmt_num(u(5, m))"}')` → `5␣m metres`.
- `` `r fmt_num(u(3, m))`{#k1} then [# a | # b]{n="#k1"} `` → `3␣m then
  3␣m b`.
- `` [outer [# a | # b]{n="."}]{n="fmt_num(u(3, m))"} `` → `outer 3␣m b`.
- `[up by # | down by # | flat]{sign="fmt_num(u(-0.3, m))"}` → `down by
  0.3␣m`.
- Expected: `5 metres`, `3 b`, `0.3`. §3 says "`#` never carries one",
  breaking 4.4.4 and K1.
- Cause: `render_n()` and `render_sign()` use a `weft_text` governor as its
  own record (`rec <- v`), and `governor_record()` does the same for an id.
  Neither takes off the `unit` that `plural()` takes off.

**3. `plural()` leaves the unit in `#` when the unit text has regex
metacharacters, or when a text class has wrapped it.**
Severity: wrong output.
- `plural(fmt_num(d$coliform_limit), "# count", "# counts")` →
  `150␣CFU/(100mL) counts`.
- `plural(fmt_strong(u(2, m)), "# x", "# xs")` → `**2␣m** xs`.
- Expected: `150 counts` and `**2** xs` (or `2 xs`), by 4.4.4. The `?fmt`
  help says "[plural()] never carries it."
- Cause: `sub(paste0(UNIT_SEP, unit, "$"), ...)` treats the unit as a regex
  (`(100mL)` becomes a group). It also strips only a trailing unit.

**4. `#` of a `list` span carries the unit when the span has a number or
wording class, and loses it silently when it has none.**
Severity: contract mismatch.
- `[# was | # were]{list="u(c(3,5), m)"}` → `3 and 5 were`.
- `[# was | # were]{list="u(c(3,5), m)" .num}` → `3 and 5␣m were`.
- With `.num .or` → `3 or 5␣m were`; with `.count` on `sites` → `three and
  12␣sites were`; with `.range` → `3–5␣m were`.
- §3: "An `n`, `sign` or `list` governor that is a quantity … is formatted
  with `governor = TRUE`, which never adds a unit, so `#` never carries
  one." `render_list()` calls `apply_formatters()` without
  `governor = TRUE`. Without a class it calls `stock_print()` on each
  element. So the same vector prints with or without its unit depending on
  an unrelated class. See question a.

**5. A list of quantities, or a `mixed_units` vector, loses every unit
without a word.**
Severity: silent.
- `fmt_and(list(u(3, m), u(4, s)))` → `3 and 4`.
- `` `r list(u(3,m), u(4,s))`{.and} `` → `3 and 4`.
- `mu <- units::mixed_units(c(1, 2), c("m", "s")); fmt_and(mu)` → `1 and 2`;
  `weft_str("`r mu`{.and}")` gives the same. (`mixed_units` is what
  `units`' own error for `c(u(3, m), u(4, s))` tells the user to use.)
- Expected: each element with its unit, or an error. 1.4.9: "A unit belongs
  to the value"; 4.4.5 forbids a silent drop (D27's reason). The list path
  is `as.character()` on each element.

**6. `ci()` and `pm()` given the `weft_text` of a quantity drop the unit
silently.**
Severity: silent.
- `ci(fmt_num(u(2, m)), 1, 3)` → `2 (95% CI 1 to 3)`, in a knit too.
- `pm(fmt_num(u(2.1, m)), 0.3)` → `2.1 ± 0.3`.
- Expected: the D28 `weft_value_error`, as for `ci(u(2, m), …)`. The
  `weft_text` carries `unit` (D29), but `no_unit()` checks only
  `inherits(x, "units")`, and `one_number()` then takes `attr(x, "number")`.
- (`clamp(fmt_num(u(150, m)), …)` errors, only by chance: "needs a number,
  not a weft_text".)

**7. `of_n()` compares the bare numbers of quantities in different units,
and accepts a quantity with a bare number.**
Severity: wrong output.
- `of_n(u(3, m), u(700, cm), "site", "sites")` → `3 of the 700 sites`.
- `of_n(u(300, cm), u(7, m), …)` → value error "`k` (300) is more than `n`
  (7)", which is false: 3 m < 7 m.
- `of_n(u(3, m), 7, …)` → `3 of the 7 sites`.
- Expected: `k` converted into `n`'s unit (or an error when they do not
  convert), and an error for a quantity with a bare number (4.4.5). D28
  says only "take the number". `bare_number()` drops each unit on its own.
  `about(u(49, cm), to = u(0.5, m))` reads `to` as 0.5 against `x` = 49.

**8. `glue_vec()` on a quantity rounds the numbers. On a plain number or a
ratio it does not.**
Severity: contract mismatch.
- `glue_vec(u(c(1.234, 2), m))` → `1.2 and 2␣m`.
- `glue_vec(c(1.234, 2))` → `1.234 and 2`.
- `glue_vec(u(c(0.25, 2), m) / u(1, m))` → `0.25 and 2`.
- `glue_vec(u(c(0.04, 2), m))` → `0.0 and 2␣m`, plus a
  `weft_zero_warning`.
- §3 stage i: the number is formatted "exactly as it formats a plain
  number". Having a unit changes the digits printed, and a ratio prints
  differently from a length. `glue_vec()` runs `.num` on a value with a
  unit only.

**9. A collapse given the `weft_text` of a text class repeats the unit on
every element.**
Severity: wrong output.
- `fmt_and(fmt_strong(q))` → `**3␣m**, **5␣m** and **7␣m**`.
- `fmt_and(fmt_em(q))` gives the same with `*`.
- `fmt_range(fmt_strong(u(c(3, 5), m)))` → `**3␣m**–**5␣m**`.
- §3: "a collapse given one places it as stage iii says" (once, after the
  last number). The result carries `unit` (`placed` is TRUE), but `strip`
  matches only a text that ends with the unit, so nothing is stripped. Also
  against the ruling "A `weft_text` carries `unit` only when the unit is in
  its text", as stated: the unit is not at its end.

**10. Base subsetting of a quantity's `weft_text` drops `unit`, so a later
collapse repeats it.**
Severity: cosmetic.
- `f <- fmt_num(q)`:
  - `fmt_and(f[2:3])` → `5␣m and 7␣m`.
  - `fmt_range(f[1:2])` → `3␣m–5␣m`.
  - `fmt_and(rev(f))` → `7␣m, 5␣m and 3␣m`.
- With plain numbers the record is lost the same way (no `[.weft_text`),
  but the text stays right. With a unit the text goes wrong (4.4.3: "once").

**11. `glue_vec()` on a quantity with `NA`, or of length zero, names the
wrong function.**
Severity: cosmetic.
- `glue_vec(u(c(3, NA), m))` and `glue_vec(u(numeric(0), m))` → "A formatter
  was given a missing value". A plain vector says "A collapse …".

**12. A unit's text is written into markdown unescaped.**
Severity: cosmetic.
- After `units::install_unit("_ab_")`, `` `r u(5, "_ab_")`{.num} and `r
  u(5, "_ab_") * u(2, "_ab_")`{.num} `` renders as `5␣*ab* and
  10␣\_ab_²`. The first unit becomes italic "ab" and loses its underscores.
- A dictionary can register such a symbol (4.4.7). `*` is safe only because
  it becomes `⋅`. See question g.

## Questions

a. What is `#` of a `list` span over quantities: the numbers alone (as §3's
   governor line says), or the collapsed list with its unit once (as
   stage iii says for `.and`)? Finding 4 shows both today.

b. A value construct with only an id or a pass-through class prints stock,
   with no unit: `` `r u(3, m)`{#onlyid} `` → `3`, `{.myclass}` →
   `[3]{.myclass}`. Is that intended? An id is not a formatter (4.4.8), but
   adding an id changes nothing else about how a value prints.

c. An inverse unit prints in `units`' `neg_power = FALSE` form:
   `u(2, "m^-3")` → `2␣1/m³`, `u(5, "s^-1")` → `5␣1/s`. "2 1/m³" reads as
   "21/m³". SI style is `2 m⁻³`. The superscript minus that D23 provides for
   is never used.

d. A plane angle prints `5␣°` (`arc_degree`, `degree`). SI writes `5°`
   with no space. §3 says "for every unit". Keep it?

e. `of_n()` and `about()` with quantities in different units: convert,
   error, or as now (finding 7)? D28 is silent.

f. Should the text for LaTeX outputs differ? Pandoc's `m^2^` superscript
   and `\cdot`-free forms such as `kg m` render in every writer. The
   Unicode forms need a font with U+2070–2079 and U+22C5 (finding 1).

g. Escape a unit's markdown-significant characters (`_`, `~`, `[`), or
   treat a registered unit as data under 1.4.10 and leave it?

h. `d$method_change * u(1, a)` prints `2,014␣a`: arithmetic with a unit
   drops the year treatment. Probably right for a duration. Noted only
   because the year check reads `attr(value, "weft_type")` after
   `bare_number()` has stripped attributes.

i. (Outside 2b; for `u()`.) `u(1, "m^0.5")` succeeds and prints `1␣5`:
   `units` parses it as a unit named `5`. `u()` could refuse a symbolic
   unit that is all digits.

Probed and sound: the unit-text table (§3 rows), superscripts and `⋅`,
`mm/hr`, `CFU/100 mL`, `%`, `°C`, `µg`, ratios and `1`. Also every shipped
class with a quantity, including `digits`, `sigfig`, `.sci`, thousands
marks, `thousands_from` and `big_mark`. Also `.no`/`.word`/`.count`/`.ord`
unit placement, `.a`/`.cap`/`.strong`/`.em`, and `.and`/`.or`/`trunc`/
`sep`/`last`/`.pairs`/`.ul`/`.ol`/`.dl`. Also `.range` (negative, equal,
same-printing ends, wrong order, wrong length), `none`, zero-length and
`NA` quantities, `c()` of convertible quantities, and chained
`fmt_and(fmt_num())` and `fmt_num(fmt_num())`. Also the `.pct`/`.p`/
`.date` errors inside and outside a knit, `n`/`sign` governors that are
quantities, the zero rule and zero arm, ids with a formatter of their own,
and the record holding no unit. Also project formatters in all four stages
(D26), bare values, tables, headings, figure captions, `weft_str()`, and
Quarto/rmarkdown markdown, HTML and docx output. Plain numbers take
unchanged code paths: every new branch is gated on `ut`/`strip`, as the
diff of `ab902cd` shows.
