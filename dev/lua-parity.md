# Lua path parity: gaps and options

A design study, read-only, written against `main` at `cfcc8db` (the review-6 fixes in). Every
example is invented. Rule numbers are the spec's (`dev/PACKAGE-SCOPING.md`); N and D numbers are
`dev/design-6.md`'s.

## Summary

Parity here means: a sentence written for the filter can say and check what an R sentence says and
checks, wherever that does not need a host language to compute something. The filter will never
evaluate an expression, and should not. Its job is to choose, format and check by comparison; code
computes. Measured against that line, the filter is close. Every construct kind, governor, class,
id and marker of the R path is there, and so are failures, markers, lines, draft mode, the stamp,
the ledger, `changes()`, the gate and `arms()`. The real gaps are of four kinds. Some are small
things not built: `!name`, a date compared with a date literal, `.num`, `.pct`, `.sci` and `.p` on a
list with no collapse class, and `date_format`. One is a grammar decision: boolean structure in
`if`. Some are check features: a warned check stated in prose, and a check that the gate counts as
a claim. The rest need a host language and should stay out: units with conversion, project
formatters, phrase functions, the dictionary as R objects, and arithmetic.

My recommendation is to take the five (A) items below. None changes a writer, and only one
touches the static grammar, by one line in each of its three copies. Then decide B1 (`&&`, `||`,
`!`, brackets) only when a real filter document needs "or". It is the one change that turns three
regular expressions into three parsers. Add nothing that computes a number.

## Parity table

"Deliberate" cites the decision. "Host" means it cannot be done without a language to evaluate in.
"Not built" means nothing stands in the way but work.

| Capability (R path) | Lua path | Status | Why |
|---|---|---|---|
| Value: `` `r EXPR`{…} ``, any R expression | `` `NAME`{…} ``, a name only | partly | deliberate (D1, N5 to N7); host |
| Bare value, printed as stock | `.val` (a construct: checks, ledger) | present | D2 |
| `n`, `sign`, `list` governors on any R expression | governor is a NAME (`n` also `.` and `#id`, `sign` also `#id`) | partly | deliberate (N12); host |
| `if` on any R expression, commas between | a bool NAME, or one comparison `a OP b`, commas between | partly | deliberate (D4, N9 to N11) |
| Operators: everything R has | `< <= > >= == !=` only | partly | D4. `!`, `&&`, `||`, brackets, `%in%`: not built. Arithmetic, calls: host |
| Kinds compared | numbers exact by text (a float by its shortest text, ruling 16), strings `==`/`!=`, dates in order, bool `==`/`!=` | present | |
| A date against a date literal (`d > '2026-01-01'`; R coerces the string) | value error E19 | absent | not built (6c ruling), see A2 |
| Comparisons on a whole list, or on its length | value error | absent | deliberate; a `list` span chooses by length |
| No truthiness, missing is "no value" | same | present | 1.11.8 |
| Guard (one-arm `if`), each failing part reported | same | present | |
| A case with no arm is a failed claim | same | present | 1.5.3 |
| Arms and escapes (`||`, `##`, `\|`), 1.5.20 spacing, chains | same | present | |
| Only the chosen arm is evaluated | a name in an unchosen arm is never read; code runs before prose; a record's checks count where used | present | 1.5.16 as restated |
| `cite` spans | present; the key is not checked at render (the `cite-key` lint covers it) | partly | deliberate (1.12.11) |
| Text spans, `.weft-literal` and `why` | same | present | N16 |
| Ids, back-references, `n="."` | same; cannot cross resolvers | present | N13 |
| Captions and the four front-matter fields | any caption and any scalar form (more than R) | present | D8 |
| `weft_str()` | none | absent | out (rung 5); host |
| `.num .pct .sci .p .date` | present | present | |
| `.num .pct .sci .p` on a vector with no collapse class (R: element by element, joined ", ") | value error E17; `.date` and `.val` already join | absent | not built ("kept for now", 6f ruling), see A3 |
| `.no .word .count .ord` | present, exact past 2^53 | present | review #4 |
| `.and .or .pairs .range .ul .ol .dl`, `sep last trunc none`, `serial_comma` | present | present | |
| `.a .cap .strong .em` | present | present | |
| `date_format` setting (any format string) | `%-d %B %Y` only, else E20 | partly | not built (N100), see A4 |
| Unit classes `.uname .usym .nounit`, `unit=` and ladders, zero advice | value error E20 | absent | deliberate scope ("out: a loud failure"); records carry no unit (E44) |
| Project formatters (`formatters:`) | value error E21 | absent | host (R functions) |
| Words in another `lang` | refused, as in R | present | 1.6.5 |
| Phrase functions `of_n about ci pm clamp`, `lookup()`, `brk()` | none | absent | scope; host |
| Dictionary reads (`dict$x`) | none | absent | host; see B6 |
| Integers and decimals of any size | exact (more than R) | present | D20 |
| `claim(x, check…)` in a value or governor | no claim in prose; a guard that wraps the value gives a fail-level check | partly | D11; see A5, B3 |
| `claim(…, level = "warn")` in prose | none (guards take no level) | absent | not built; see B3 |
| `claim()` in chunk code (stops) | Python `claim()`, Julia `@claim`: eager, recorded, then raised | present | D11, N50 to N57 |
| Use-site check from code | `weft_put(x = claim(…))` from R (N41); none from Python or Julia | partly | O1 deferred; see B4 |
| A check made in code that ran (block `checks`) | reported once (N25b) | present | |
| Warned checks reported apart | same | present | 2.6.10 |
| Printed-as-zero warned check | float and decimal, not int | present | 6c ruling |
| Failure markers, one report, kinds | same layout | present | N86 |
| Source lines | text search with masking and includes | partly | limit: text a chunk printed; a span whose attribute holds `\|` gets no line (found below) |
| Draft mode, collection file, book report | same | present | N86, N111 |
| Ledger, `changes()` | the filter writes `writer: "filter"` entries | present | N112, N148 |
| Stamp, `verify()`, freshness | same, plus `fresh` | present | N110, N120 |
| Gate counts | a named value counts as a value, a filter span as a span, guest `claim(`/`@claim` as calls | present | N147, N59 |
| Lints | structure, numerals, claim words and the rest apply; R-expression lints do not; two new ones | partly | N142 to N145 |
| `arms()` | lists filter spans from the scanner | present | checked below |
| `rehearse()` | knitr only | absent | not built; see B5 |
| `last_knit()` records | none (the stamp and ledger hold the outcome) | absent | not built |
| Condition log | Python and Julia chunks under knitr only; nothing on the jupyter and julia engines | partly | no evaluate hook on the engines |
| `auto()` | Python yes; Julia no | partly | no post-cell hook on the julia engine (scope) |

## A. Obvious wins

Each is small and fits the existing code. None changes a writer. A2 to A5 change no static
grammar; A1 adds one line to each of the three copies of it.

### A1. `!name`: the negation of one bool name

- **Syntax.** `[the backlog cleared | the backlog grew]{if="n_open < 5, !paused"}`. A guard that
  must be false: `[Sampling ran on schedule]{if="!delayed"}`.
- **Rule text (1.12.4).** "…a condition is a name whose value is a bool, `!` directly before such a
  name, or one comparison… `!` applies to a name only: `!a == b`, `!!a` and `!(a)` are construct
  errors."
- **Why it is safe.** It is the same in R and Julia, so a knitr document's hooks read it as the
  filter does (D5). Allowing `!` only before a bare name avoids the one trap: R reads `!a > b` as
  `!(a > b)` and Julia reads it as `(!a) > b`, and that form stays refused. Today, "a and not b"
  needs a second published name, and a guard that must be false cannot be written at all. The
  two-arm `[ | phrase]{if="a"}` prints the phrase when `a` is false, but fails nothing.
- **Files.** `weftlib/cond.lua` (`parse_part`: before `find_op`, a part matching `^![ \t]*NAME$`
  becomes `{neg = true, a = …}`; `evaluate` returns `not v` after the bool check), `R/scan.R`
  (`cond_part_error`: one branch), `inst/quarto/weft-pre-render.R` (`cond_ok`: one branch), the E3
  text, spec 1.12.4, and the vignette's grammar list. The N45 name extraction needs no change: it
  already takes `a` from `!a`.
- **Tests.** `test-filter-if.R`: truth rows `!a`, `!f`, `a, !f`. `!a` moves out of the refused
  list, and `!!a`, `!a == f` and `! (a)` are added to it. `!s` gives an E18 value error.
  `test-pre-render-named.R`: `!x` moves from `BAD_GOVERNORS` to `GOOD_DOCS`, and `!a == b` joins
  the bad list. One scanner case in `test-lint-engine-named.R`.
- **Size.** About 10 lines of Lua, 4 of R and 4 in the pre-render script. Three tests amended,
  about 10 cases.
- **Risks.** R's `!` on a number is truthiness (`!5` is `FALSE`). So in a knitr document the hooks
  accept `!n` for a number, where the filter gives a value error. That is the error-versus-value
  direction only, and the same as today's bare name. Python authors will write `not a`, and E3
  could say "write `!a`".

### A2. A date compared with a date literal

- **Syntax.** `[before | after]{if="sampled < '2026-07-01'"}`.
- **Rule text (1.12.5).** "A string literal that is a valid `YYYY-MM-DD` date compares with a date
  in calendar order. Any other string literal compared with a date is a value error, and so is a
  date compared with a string *name*." The second sentence keeps 1.11.11: a string record is data,
  and no carrier reads a value's printed form.
- **Why.** R compares a Date with a character string by coercing the string, so in R
  `d > '2026-01-01'` is already legal and true. The filter refuses it (E19). The scanner and the
  pre-render script already accept the syntax, so the static side and the render disagree today:
  the source passes the lints, and the render fails. The strict ISO form is safer than R, which
  silently reads `"05/03/2026"` as 20 March of year 5 (run below).
- **Files.** `weftlib/cond.lua` only (`evaluate`: a date against a `{str}` literal; a small
  calendar check, or `valid_date` moved out of `weft.lua` into `cond.lua`). Spec 1.12.5 and the
  vignette.
- **Tests.** `test-filter-if.R`: about 6 truth rows (both orders, `==`, `!=`, a leap day). Value
  errors for `'2026-1-3'`, `'2026-02-30'` and `'03/01/2026'`. `dA == s` (a string name) stays E19.
- **Size.** About 12 lines of Lua, 1 new test of about 9 cases.
- **Risks.** None found. The literal is the author's own text, so nothing published is
  reinterpreted.

### A3. `.num`, `.pct`, `.sci` and `.p` on a list with no collapse class

- **Syntax.** `` `depths`{.num} `` prints "1.3, 3.5", as `` `r depths`{.num} `` does (1.4.10).
- **Rule text.** Delete from 1.12.11 the sentence "`.num`, `.sci` and `.p` on a list with no
  collapse class are value errors, where R prints a vector element by element".
- **Why.** `format_vector` in `weft.lua` already formats each element and already joins with ", "
  when there is no collapse class. `.date` and `.val` on a list take that path today (run below).
  Three explicit guards (`if ncl and rec.t == "list" and not collapse then vfail(e17(…)) end`)
  refuse it for the number classes. R prints per element (`fmt_num(c(1, 2.5))` is `"1" "2.5"`, and
  `weft_str()` gives "1, 2.5"), so the filter's per-element printer matches R as it does under
  `.and`.
- **Files.** `inst/quarto/weft.lua` (remove three guards), spec 1.12.11, the vignette's Limits,
  and `R/conformance.R` (rows of vectors with no collapse class for the four classes).
- **Tests.** New conformance rows in `lists.tsv`, about 8. Three pinned expectations flip:
  `test-filter-values.R:202` (`l1` under `.num`), `test-review6-filter-2.R:143` (the "control"
  that a list of two under `.num` is E17), and `test-filter-classes.R:66` (`.sci` on `l1`). Each
  becomes a row that prints, or an element-kind E17 when the elements are not numbers.
- **Size.** About -3 / +2 lines of Lua, 5 of R, 3 tests amended, about 8 rows.
- **Risks.** The printed-as-zero check is one per construct however many elements print as zero
  (2.6.11). `format_vector` already counts hits that way. Confirm it with one row.

### A4. `date_format` beyond the default

- **Syntax.** `date_format: "%d/%m/%Y"` in `_weft.yml` now prints `` `d`{.date} `` as "05/03/2026"
  in the filter too, where today it is E20.
- **Rule text (1.12.11).** "The filter reads in `date_format` the tokens `%d %-d %e %m %-m %B %b
  %A %a %Y %y %j %%` and literal text; any other token is a value error (E20)."
- **Why.** R's `format_dates()` already expands the month and weekday names itself, in English,
  and leaves the numeric tokens to `format()`. The numeric tokens of a date with no time are pure
  arithmetic on Y-M-D. A token outside the list stays loud. The one that needs a calculation is the
  weekday, which is Sakamoto's formula, a few lines.
- **Files.** `weftlib/words.lua` (`M.date`: a token loop), spec 1.12.11, the vignette's Limits,
  and `R/conformance.R` (`dates.tsv` rows with `cfg.date_format=…`, which the generator already
  supports).
- **Tests.** About 12 conformance rows (each token; a leap day; a weekday across a century). Amend
  `test-filter-classes.R:96` so that "another format string is E20" uses an unsupported token
  (`%U`).
- **Size.** About 35 lines of Lua, 5 of R, about 12 rows.
- **Risks.** R's `%e` and `%j` come from the platform's `strftime`. Generate the rows on this
  machine and check that the Linux CI agrees, or drop `%e`.

### A5. A failing guard names the values it read

- **Syntax.** Unchanged. A guard that wraps a value is the filter's claim in prose today:
  `` The worst reading was [`worst`{.num}]{if="worst < 50"} NTU. `` It prints the value, places the
  marker after it, and fails the render (run below). Its report says only `worst < 50 was false`,
  where a `claim()` says `(value 52.5)`.
- **Rule text (2.13.4).** "A guard whose condition is false reports `X was false (a = …, b = …)`,
  naming each name it read with its value as `.val` prints it."
- **Why.** `cond.evaluate` already returns the records it read, and `val_text` prints them. This
  makes the guard idiom report as well as a claim. The vignette's Checks section should show the
  value-wrapping form as the way to check a printed value from prose.
- **Files.** `inst/quarto/weft.lua` (`resolve_if`: build the parenthesis from `reads`), spec
  2.13.4, the vignette.
- **Tests.** `test-filter-if.R` (the 1.5.5 guard tests) and `test-filter-report.R`, where they pin
  the detail. About 3 expectations amended, plus 1 new case for a two-name comparison.
- **Size.** About 8 lines of Lua.
- **Risks.** The filter's guard text then differs from the hooks' (`x > 3 was FALSE`). That is
  harmless, because each resolver reports its own constructs (N133h). The hooks could gain the
  same text later for names, but not for arbitrary expressions.

## B. Worth raising

### B1. Boolean structure in `if`: `&&`, `||`, `!` and brackets

- **Syntax.** `[a gap | no gap]{if="n_gap > 10 || (n_sites < 3 && !complete)"}`.
- **Grammar (R's subset).** `cond := or ("," or)*`; `or := and ("||" and)*`;
  `and := unary ("&&" unary)*`; `unary := "!" (NAME | "(" or ")") | atom`;
  `atom := NAME | cmp | "(" or ")"`. `&&` and `||` mixed without brackets is a construct error.
  This is unambiguous in R, but the reader should not have to know the precedence. `!` before a
  comparison without brackets stays refused (the R/Julia split noted in A1). Commas stay: each
  part of a guard is still reported separately.
- **Why R's spelling.** In a knitr document the hooks resolve the same span as R (D5, N14), so the
  filter's grammar must stay a subset of R that means the same. That rules out
  `and`/`or`/`not`.
- **The decision inside it: evaluation order.** R short-circuits (`FALSE && NA` is `FALSE`).
  Strict evaluation reads every name, so a missing or unpublished operand is always "no value", and
  every record read counts its checks. That is simpler to explain, and it matches the static view
  (every name must be published). But `has_n && n > 3` with `n` missing then fails, where R's hooks
  take `FALSE`. I would choose strict and say so in 1.12.4. Either choice is easy in Lua.
- **Costs.**
  - The three copies of the grammar (`cond.lua`, `R/scan.R`, the base-R pre-render script) become
    three tokenizers and recursive-descent parsers. Each is 60 to 90 lines, and the pre-render
    copy cannot share code with the scanner.
  - `||` inside a pipe-table cell must be written `\|\|` (run below: unescaped, the cell splits and
    the span becomes text, which `weft-check.lua` catches). Rule 1.2.3 then needs a second
    exception beside `unit`. The filter's line search must also try the escaped needle: today such
    a span has no line.
  - `a && b` is the canonical out-of-grammar fixture in `test-filter-if.R`,
    `test-pre-render-named.R`, `test-use-setup-named.R` and `test-lint-engine-named.R`, so those
    fixtures move.
  - E4 generalises to "no name anywhere".
  - The guard report should name the failing part, which A5 helps with.
- **Size.** About 90 lines of Lua, 70 of R and 70 in the pre-render script. About 25 new cases
  across 5 test files.
- **Risks.** Three parsers drifting apart. A shared table of cases, run against all three, would
  be the guard, like the conformance tables.

### B2. `%in%`: membership in a published list

- **Syntax.** `[a flagged site | an unflagged site]{if="site %in% flagged"}`; the left side is a
  name or literal, the right side a list name.
- **Semantics.** The element kinds compare as in 1.12.5. An empty list gives `false`, and a missing
  element is "no value" (as a `list` governor treats one). R's own `%in%` means the same for a
  scalar on the left, so a knitr document agrees.
- **Trade-off.** It is the first list operand in a condition, and an R-only spelling that Python
  and Julia authors will not guess (`in`, `∈`). Without B1 there is no "not in". The alternative,
  publishing `site_flagged = site in flagged` from code, costs one line.
- **Files and size.** `cond.lua` about 25 lines, one operator in `COND_RE` and in the pre-render
  regex, spec 1.12.4 and 1.12.5. About 10 cases in `test-filter-if.R`, 2 in pre-render.

### B3. A `claim` key on a named value

- **Syntax.** `` `worst`{.num claim="worst < 50"} `` and `` `worst`{.num claim="worst < 50" level="warn"} ``.
  The condition grammar is the filter's, and the value's own name is written out, not as `.` or
  `_`.
- **What it adds over the A5 guard idiom.** A warned check in prose, which the filter cannot state
  today because guards have no level. And a claim the gate counts as a claim, apart from values
  and spans (6.3.1), so deleting one is not netted against an added value. The report and marker
  would follow N25a's record-check form.
- **Trade-off.** It is a second way to write a check in a filter document, and a key whose name
  is an R function but whose grammar is the filter's. On an R value it would have to be a
  construct error ("write `claim()` in the expression"), and on a span too. It touches the owned
  key sets in `weft.lua`, `R/scan.R` and `weft-check.lua`, plus the gate's claim count.
- **Note.** Today `claim="…"` on a named value is passed through silently at render, with only the
  tier-2 `name` lint (run below). If B3 is declined, making `claim` on a construct a construct
  error that points to the guard idiom would remove that trap.
- **Size.** About 30 lines of Lua, 25 of R scanner and gate, and 2 in `weft-check.lua`. About 8
  tests.

### B4. `checked()` from Python and Julia (O1)

- **Syntax.** `put(worst=checked(worst, "< 50"))`; `@put worst => @checked(worst < 50)` or
  `Weft.put(worst = Weft.checked(worst, :(_ < 50)))`.
- **What it adds.** A use-site check made in code, the Python and Julia twin of
  `weft_put(x = claim(…))`. The schema (N22 `checks`) and the filter (N25a) already carry and
  honour it, so the filter does not change.
- **Trade-off.** Two spellings in each language with different timing: `claim` checks now,
  `checked` checks where the name is used. The holder must be refused by everything but
  `put()`/`auto()`. The gate must count `checked(` and `@checked` (N59 patterns). It was deferred
  "until an author wants it".
- **Size.** About 40 lines of Python, 50 of Julia and 10 of R (gate). About 10 tests across
  `test-py-put.R`, `test-jl-put.R` and `test-gate-guest-claim.R`.

### B5. `rehearse()` for filter documents, over values instead of params

- **Shape.** `rehearse("survey.qmd", cases = list(empty = list(n = 0L, flagged = character())))`.
  For a document the filter resolves, each case's values are written as a block (R's
  `values_record()`). Plain Pandoc then runs the filter with an environment variable that pins
  those names (later publications of them are ignored) and makes the filter write its chosen arms
  and failures to a temporary JSON file instead of the stamp and ledger.
- **What it adds.** Every arm can be exercised with no kernel and no Julia server, which is cheap
  where the R path is slow.
- **Trade-off.** It rehearses the wording against values, not the code against params, so it
  cannot find a code path that never yields the value tried. It also adds a mode to the filter.
- **Size.** About 120 lines of R and 40 of Lua. About 8 tests in `test-rehearse.R`.

### B6. Dictionary entries as a values file

- **Shape.** A helper (or a `tar_dict` step) writes the dictionary's plain scalar entries to
  `_weft/values/dict.json` under names such as `dict.era_split`: a dot is an ordinary name
  character (D3). A filter document reads it with ```` ````{.weft-values file="/_weft/values/dict.json"} ````.
- **What it adds.** Stipulated thresholds reach Python and Julia documents, and conditions can
  name them (`[above | within]{if="worst > dict.limit"}`). The filter does not change.
- **Trade-off.** Only scalars cross. Quantities with units are refused (E44), and `lookup()` and
  `brk()` are functions. The ledger's `dict` field stays empty for these reads, and the `dict-*`
  lints do not see them. Authors can already do it by hand with `weft_values_write()`.
- **Size.** About 40 lines of R. About 5 tests.

### B7. Units, symbol and name only, no conversion

- **Shape.** A record gains an optional `unit` (weft's unit text, such as `"mg/L"`). R publishes a
  `units` object with it instead of E44. Python and Julia take an explicit `quantity(3.2, "m")`,
  not pint or Unitful. The filter prints `.usym`, `.uname` and `.nounit` from a Lua table generated
  from `unit_defaults()`. `unit=` stays E20 unless it equals the published unit.
- **What it adds.** The commonest unit use (print "3.2 m" or "3.2 metres") in engine documents.
- **Trade-off.** It is the largest item here. The record schema changes in three writers, and a
  generated table must be kept in step with the R side. It has no conversion, no ladders, no
  zero-rescale advice (2.6.11), and no project `units:` (9.1.7, which is a nested mapping that the
  flat reader cannot read). I would not do it until an engine document needs units.
- **Size.** About 200 lines of Lua, 60 of R and 40 each of Python and Julia, plus a units
  conformance set.

## C. Not recommended

- **`and`, `or` and `not` as words.** R cannot parse them, and the hooks resolve the same span in
  a knitr document (D5). E3 can hint at `,` and `!` instead.
- **Arithmetic in conditions, or derived values in the filter** (sum, difference, ratio, percent
  change, `abs`).
  - Exact decimal arithmetic and the hosts' doubles disagree: `0.1 + 0.2 > 0.3` is `TRUE` in R
    and would be false exactly.
  - Division is not exact.
  - A derived number has no record, no checks and no raw value for the ledger.
  - One line of code publishes it. This is the line: the filter chooses, formats and compares;
    code computes.
- **Calls** (`len`, `length`, `nrow`, `abs`) in conditions or governors. They need a host. A
  `list` span already chooses by length.
- **Chained comparisons** (`0 < x < 1`). R refuses them at parse, while Python and Julia read
  them as "and". Commas already say it: `x > 0, x < 1`.
- **`between`.** Commas already say it.
- **`true`/`false` literals.** The reserved words differ by language, and a bare name and `!name`
  already say it.
- **Comparisons on whole lists or list lengths.** `==` on two lists has no single meaning across
  the hosts. Publish the count, or use a `list` span.
- **A filter-evaluated block of claims** (`{.weft-checks}` listing conditions over names). It
  detaches the check from both the sentence (the guard) and the code (`claim()`), and D11's
  argument applies. The guard, A5 and B3 cover what it would.
- **Project formatters, phrase functions, `lookup()`, `brk()` and `weft_str()` in the filter.**
  They are R functions. Publish the phrase as a string from code if it must cross.
- **Unit conversion and ladders.** They need udunits' conversion tables.
- **Julia `auto()`.** The julia engine has no post-cell hook (design-6 scope).
- **A condition log on the engines built from shown output.** `warning: false` hides warnings
  before Pandoc sees them, so the log would look complete when it is not.
- **Checking `cite` keys at render.** The `cite-key` lint covers the source, and a render check
  adds a bibliography read as a new way to fail.

## Found along the way (not options)

- `claim="…"` on a named value passes through at render with no failure (tier-2 `name` lint
  only). `level="warn"` on a named value is swallowed by the filter: `level` is in `OWNED_KEYS`,
  so it is neither passed through nor an error. R passes `level` through on an R value.
- A span whose attribute value holds `\|` (the form a pipe table needs) is reported with no line.
  The filter searches for the unescaped text the tree holds.
- Rule numbers in messages are one behind the spec:
  - E19 cites 1.12.4 for kinds, which are 1.12.5.
  - The no-value text cites 1.12.6 for order, which is 1.12.7.
  - `filter_governor_errors()` cites 1.12.5 for governor values, which are 1.12.6.
  - Spec 1.12.5 and the vignette still say "a float is compared as a double", which ruling 16
    amended to "by its shortest text, exactly".
- The vignette's Limits still lists items the review-6 fixes closed: named length-1 vectors, the
  `TRUE`/`FALSE` list governor, `put()` under knitr, `auto()`'s gate and the double report.

## What I checked by running

Pandoc 3.8.3, filters from `inst/quarto/`, draft mode, plain output, in a temp directory. Each
document starts with a hand-written block that publishes bools `a` (true) and `f` (false), int
`n` 12, `m` 3, date `d` 2026-03-05, float `worst` 52.5, a list of two strings `sites`, float
lists `xs` (1.25, 3.5) and `ps` (0.046, 0.0004), a list of two dates `ds`, the string `region`
("north") and a missing `miss`.

```sh
WEFT_DRAFT=1 pandoc t.md -f markdown -t plain --wrap=none \
  --lua-filter inst/quarto/weft.lua --lua-filter inst/quarto/weft-check.lua
```

Candidate conditions today (`[yes | no]{if="…"}`):

```
!a                    construct error  `!a` is not a name or one comparison … (rule 1.12.4).
a && f                construct error  (same text)
a || f                construct error
(a)                   construct error
region %in% sites     construct error
d > '2026-01-01'      value error      `d > '2026-01-01'` compares a date with a string (rule 1.12.4).
a == true             construct error
" a" (leading space)  not a span; weft-check: "Pandoc does not read an attribute value that starts
                      with a space; it is shown as text"
a and f               construct error
```

So `!`, `&`, `|`, `%`, brackets and quotes inside a double-quoted attribute all reach the filter
intact. Pandoc mangles none of them outside a table.

Claims, lists and stray keys:

```
G1 The worst reading was [`worst`{.num}]{if="worst < 50"} NTU.
   → The worst reading was 52.5<<weft: failed claim, line 5>> NTU.
     report: [worst]{if="worst < 50"} / worst < 50 was false / optional text is written …
G2 `worst`{.num claim="worst < 50"}   → 52.5   (no failure: the key passes through)
G9 `worst`{.num level="warn"}         → 52.5   (no failure, no pass-through)
G3 `xs`{.num}   → value error: `.num` needs a number; `xs` is a list (rule 1.4.3).
G4 `ps`{.p}     → value error (same)
   `xs`{.pct}   → value error (same)
G5 `ds`{.date .and} → 5 March 2026 and 1 April 2026
G6 `ds`{.date}      → 5 March 2026, 1 April 2026      (joins with ", " already)
H1 `xs`{.num .and}  → 1.3 and 3.5;  `ps`{.p .and} → p = 0.046 and p < 0.001
H4 [x]{if="n > 20, m < 1"} → two failed claims, one per part
G8 [x]{if="miss > 1"} → no value: `miss` is missing (None) (rule 1.3.4).
```

A pipe table (`pandoc -t native`):

```
| r1  | [yes \| no]{if="a || f"} |    → cell text "[yes | no]{if=“a"; the span is lost
| r2  | [yes \| no]{if="a \|\| f"} |  → Span ("if", "a || f")
```

The same `\|\|` outside a table also reaches the filter as `a || f`. In both places the filter's
report has no line for it (`t5.md  [construct error] …`).

The R scanner (`R_USER_CACHE_DIR=$(mktemp -d) Rscript -e 'devtools::load_all(quiet=TRUE); …'`):

```
filter_governor_errors("if", x) for x in
  !a, ! a, a && f, a || f, region %in% sites, (a)  → the E3 text
  d > '2026-01-01'                                  → no error (the render then fails: A2)
  a == true                                         → E3
lints(doc.qmd, tier = 2): `claim` is not a name weft knows on a construct (rule 5.3.3).
                          `level` is not a name weft knows on a construct (rule 5.3.3).
arms(doc.qmd): lists the filter spans, keys and arm roles, and the three construct errors.
lints on `if="a \|\| f"`: "A `\` inside a value (rule 1.2.3) …" plus E3.
```

R's semantics, for the R-compatibility arguments:

```
as.Date("2026-03-05") > "2026-01-01"   TRUE      (R coerces a string to a Date)
as.Date("05/03/2026")                  "0005-03-20"   (silently, the wrong date)
as.Date("2026-03-05") > "2026-02-30"   error: not in a standard unambiguous format
!a > b                                 parsed as !(a > b)
5 && TRUE                              TRUE      (truthiness)
c(1, 2) > 1 && TRUE                    error: 'length = 2' in coercion to 'logical(1)'
0 < 0.5 < 1                            parse error: unexpected '<'
"north" %in% c("north", "south")       TRUE;   NA %in% c(1, NA)  TRUE
0.1 + 0.2 > 0.3                        TRUE
fmt_num(c(1, 2.5))                     "1" "2.5";  weft_str("`r c(1,2.5)`{.num}")  "1, 2.5"
fmt_p(c(0.046, 0.0004))                "p = 0.046" "p < 0.001"
```
