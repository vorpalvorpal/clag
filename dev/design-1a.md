# Stage 1a — internal contract

Written by the orchestrator before any test or code. `PACKAGE-SCOPING.md`
(the spec) says what the package does; this note fixes only what the spec
leaves open and the internal interfaces that tests may rely on. Where this
note and a numbered rule disagree, the rule wins and the disagreement is
reported.

Stage 1a scope is the list under "1a — the kernel" in spec §22. NOT in 1a
(do not test, do not build; a later stage does): `sign`, `#id` and
back-references, `.p`, `.range`, `.cap`, `.a`, `.date`, `.pairs`, `trunc`,
`.ul/.ol/.dl`, `lookup()`, `brk()`, `cite`, `.weft-literal`, captions in chunk
options, front-matter constructs, `weft_str()`, phrase functions, units,
dictionary, ledger. A 1a build meeting one of these names on a construct
stops with a construct error that says "not built yet" (so nothing passes
silently).

## Files

| File | Holds |
|---|---|
| `R/scan.R` | the scanner and attribute-block parser (rules 1.1, 1.2, 1.5.12–14, 1.9, 2.10.1) |
| `R/format.R` | printed record, `weft_text`, `fmt_*()`, `glue_vec()`, `plural()`, the four stages (1.4, 3.2, 3.4) |
| `R/claim.R` | `claim()` (3.1, 2.4) |
| `R/config.R` | `_weft.yml`, front-matter `weft:` key, defaults (9.1, 9.4.1) |
| `R/state.R` | per-knit state, failure records, markers, the report (2.6) |
| `R/hooks.R` | `weft_setup()`, the knitr hooks, per-knit init, child documents (2.1, 2.2, 2.8) |
| `R/resolve.R` | resolving a prose block: values, spans, pass-through (2.2, 1.2.6) |
| `R/position.R` | line positions, includes (2.7) |
| `R/conditions.R` | condition log, normalising, severity list (2.8, 7.4.2, 7.4.5) |
| `R/use.R` | `use_quarto()` |
| `inst/quarto/` | `weft-check.lua`, `weft-pre-render.R`, `weft-post-render.R` |

## Exported in 1a

`weft_setup()`, `claim()`, `plural()`, `glue_vec()`, `fmt_num()`, `fmt_pct()`,
`fmt_sci()`, `fmt_no()`, `fmt_word()`, `fmt_count()`, `fmt_ord()`,
`fmt_and()`, `fmt_or()`, `fmt_strong()`, `fmt_em()`, `use_quarto()`.

- `fmt_num(x, digits = NULL, sigfig = NULL)`, `fmt_pct(...)` and `fmt_sci(...)`
  take the same two arguments. `fmt_and(x, sep = ", ", last = " and ")`,
  `fmt_or(x, sep = ", ", last = " or ")`. `glue_vec(x, sep = ", ", last = " and ")`.
  The others take `x` only.
- Every `fmt_*()` returns a `weft_text`: a character vector of class
  `c("weft_text", "character")` with attributes `number` (numeric, `NA` when
  there is none), `decimals` (logical: decimals shown), `relation` (`"="`,
  `"<"` or `">"`). Stages i and ii are element-wise; a collapse returns
  length 1 with `number = NA`.
- A missing value (1.3.4) given to a `fmt_*()` or to `plural()` outside a
  knit is an error of class `weft_no_value`; a value-dependent error (5.3.2)
  is an error of class `weft_value_error`. During a knit, inside inline R,
  they are collected (2.6.9).
- `plural(n, ...)`: arms as strings, counts as rule 1.5.1 for `n`; `#` is
  the governor printed by the default governor class; `||`, `##`, `\|`, `\#`
  as rule 1.5.12 (no separators: each argument is one arm). Returns a
  length-1 character.
- `claim()` outside inline R during a knit stops with an error of class
  `weft_claim_failed` whose message quotes the check as written and the value
  (as in the report of 2.6.2). `claim(x)` with no check stops with class
  `weft_claim_no_check`.

## Rulings on gaps the test-writer raised

- The record's `number` is the number as printed: `fmt_pct(0.12)` has 12.
- `classes` keeps the leading dot, as written.
- `.no` acts when the printed number is 0 with no decimals shown, as the
  "zero" arm does (1.5.9). "0.0" stays "0.0".
- `plural()` accepts a `weft_text` and then selects on its record without
  formatting again; a bound takes the "other" arm.
- A wrong arm count in `plural()`, and `digits` with `sigfig` in a
  `fmt_*()` call, are errors of class `weft_construct_error`.
- `.strong` prints `**x**` and `.em` prints `*x*`. Both together are allowed.
- The `.sci` mantissa prints as `.num` prints it (a whole one with no
  decimals); a negative exponent uses the configured minus.
- Stage names for a project formatter: `number`, `wording`, `collapse`, `text`.
- `mask_text()` masks bare inline R too.
- `read_config(dir, front = list())`: `dir` is the project root.

## Defaults the spec does not give (see dev/decisions.md)

`_weft.yml` keys, all optional, the same names under a document's `weft:`
front-matter key:

```yaml
digits: 1              # default decimal places for a number that is not whole
decimal_mark: "."
big_mark: ","          # thousands mark; applied from 10,000 up, never below
minus: "−"        # the minus sign printed
governor_class: .num   # 1.5.18
pct_proportion: true   # .pct reads 0.12 as 12%
count_threshold: 10    # .count: words below, digits from it up
word_limit: 100        # .word: digits from it up
draft: false
formatters:            # 1.4.8
  .compact:
    function: pkg::fun
    stage: number
severity:              # 7.4.2: regular expressions; shipped defaults are added to
  - "singular"
```

- `.pct` prints a whole percentage with no decimals and otherwise the default
  digits, as `.num` does (1.4.13 applied to the percentage).
- `.sci` prints `1.2 × 10^3^` (markdown superscript), mantissa to the default
  digits unless `digits`/`sigfig` is given.
- `.ord` prints "1st", "2nd", "3rd", "4th", "11th", "21st".
- `.word` spells with hyphens and no "and": "twenty-one".
- The project root is the nearest directory, from the input file upward,
  that holds `_weft.yml`; failing that, one that holds `_quarto.yml`; failing
  that, the input file's directory.
- A project "has been set up" (9.3.2) when its root holds `_weft.yml`.

## Internal interfaces tests may use (`weft:::`)

Nothing else internal may be touched by a test.

### `scan_text(text, file = NA_character_, first_line = 1L)`

Scans one string of markdown (a whole file or one prose block). Runs no R
except `parse()` on expressions (5.3.5). Returns a data frame, one row per
construct or bare inline value, in textual order (a parent before the
constructs nested in it):

| Column | |
|---|---|
| `kind` | `"bare"` (inline R, no attribute block), `"value"`, `"n"`, `"if"`, `"text"`; later stages add `"sign"`, `"cite"`, `"literal"` |
| `file`, `line` | `line` counts from `first_line`; the line of the construct's first character |
| `start`, `end` | 1-based character offsets in `text` of the whole construct, attribute block included |
| `expr` | the inline code without its `r `/`{r} ` prefix; for a span the value of its governor key; `NA` for a text span |
| `classes` | list column: character vector, as written, in order |
| `keys` | list column: named character vector of the other `key=value` pairs, keys lower-cased when they match a weft key (1.2.10) |
| `id` | `NA` or the id |
| `arms` | list column: character vector of trimmed arms with escapes resolved (1.5.12); `NULL` for values |
| `parent` | row number of the enclosing span, or `NA` |
| `arm` | which arm of the parent holds it, or `NA` |
| `error` | `NA`, or the message of the construct error (5.3.1) found from the source |

It skips what rule 1.9 leaves alone. `scan_file(path)` reads a `.qmd`/`.Rmd`
(BOM, CRLF, no final newline all accepted), skips chunks, YAML and
non-executed fences, and returns the same data frame for its prose, with
`line` the line in the file. (Captions and front matter join in 1c.)

### `mask_text(text)`

Returns `text` with every construct's code and attribute-block range replaced
as rule 2.10.5 says (same length, line breaks kept).

### `last_knit()`

The records of the most recent top-level knit in this R session, a list:

- `constructs`: the `scan_text()` rows found at knit time over the prose
  blocks (with `file` and `line` in the source file), plus `evaluated`
  (logical) and `chosen` (the arm index taken, `NA` otherwise)
- `failures`: data frame with `kind` (`"failed claim"`, `"no value"`,
  `"value error"`, `"construct error"`, `"unevaluated"`, `"condition"`),
  `file`, `line`, `chunk`, `expr`, `detail`
- `conditions`: data frame with `source` (chunk label, or `file:line` for
  prose), `class` (`"warning"`, `"message"`, `"error"`), `text`, `normalised`
- `config`: the merged configuration as a named list

### `normalise_condition(text)`

Rule 7.4.5, steps 1 to 5. Placeholders: `<addr>`, `<path>`, `<n>`.

## Errors a render ends with

- A construct error stops the knit with class `weft_construct_error`; its
  message is `weft: <file>:<line>: <what is wrong>` and names the rule's
  remedy where the rule gives one (1.2.3).
- Collected failures end the knit, from the `document` hook, with class
  `weft_failures`; the message has the layout of rule 2.6.2 and starts
  `weft: N claims failed` / `weft: N failures` (claims and the other kinds
  counted separately, each kind under its own heading line so 2.6.7 holds).
- In draft mode neither is raised: the report goes to the knit log through
  `message()`, and the markers of 2.6.8 are in the output.

## The Quarto side (rules 2.5.3, 2.5.4, 2.6.6, 2.9.2, 2.9.4, 2.9.5)

`use_quarto(path = ".")` says what it will write, then writes:

- `_extensions/weft-check/_extension.yml` and `weft-check.lua`, and adds the
  filter to `_quarto.yml` (`filters: [weft-check]`)
- `_weft/pre-render.R` and `_weft/post-render.R`, and names them under
  `project: pre-render:` / `post-render:` in `_quarto.yml`
- `_weft.yml` when there is none (empty but for a comment)

The collection file is `.weft/failures.jsonl` under the project root; the
freeze stamps are `.weft/stamps/<source path with / as __>.json`. The
pre-render script cannot set an environment variable for the render, so
the collection file is found by its existence: the knits and the filter use
`WEFT_COLLECT` when it is set, and otherwise an existing
`.weft/failures.jsonl` in the project root (found by walking up from the
input file). The pre-render script creates it empty; the post-render script
reads it, reports and deletes it. Each line is a JSON object with `source`
(`"knit"` or `"filter"`), `kind`, `file` (relative to the project root),
`line`, `chunk`, `expr`, `detail`. The filter repeats every `<<weft:` marker
the knit already recorded, so the report drops a filter line that matches a
knit line on file, line and kind. The filter reads
draft mode from `WEFT_DRAFT` and from `draft: true` in `_weft.yml`.

## Tests

`tests/testthat/`. A render helper `helper-render.R` gives:

- `render_rmd(lines, setup = TRUE, ...)`: writes a `.Rmd` in a temp dir,
  renders to markdown (`rmarkdown::md_document(variant = "markdown")`, or
  `knitr::knit` where said), returns `list(text, error, log)`
- `render_qmd(lines, ...)`: the same through `quarto render --to markdown`
  (`skip_if` Quarto is missing; `skip_on_cran()`)
- `both(lines, expect)`: runs a case under each and compares

A document activates with a setup chunk calling `weft::weft_setup()` unless a
test is about activation. Quarto renders are slow (about 2 s each): put many
cases in one document where the cases do not interfere, one case per
paragraph, and split the output on a marker line.

## Rulings on the review of package A (`dev/review-1a-A.md`)

Findings 1 to 28 are accepted as the reviewer states them unless listed here.

- **Finding 2 (arms).** `arms` stays as it is (the text an author reads,
  for `arms()`). A new list column `arm_templates` holds the same arms with
  each `#` placeholder written as U+E001 and each literal `#` as `#`. The
  resolver fills templates; nothing splits the source a second time.
- **Finding 3.** A wording class on a number printed with decimals shown is
  a `weft_value_error` (1.4.12, as printed). `fmt_word(3)` and
  `fmt_word(3.0000)` print "three"; `fmt_word(2.04)` fails.
- **Finding 4.** A number is whole when it differs from its rounding by less
  than 1e-9, absolutely.
- **Findings 6, 7.** Inline R is exactly what knitr 1.51's inline pattern
  evaluates. Several expressions in one span are legal; only code that does
  not parse is the error of 5.3.5.
- **Finding 8.** A `weft_text` keeps its raw value in an attribute `raw`. A
  number-stage formatter given a `weft_text` formats the raw value afresh
  (as 1.7.8 does): `fmt_pct(fmt_pct(0.12))` is "12%". Wording, collapse and
  text stages use the record.
- **A (rounding).** Half away from zero on the decimal number as written:
  0.05 → "0.1", 0.15 → "0.2", 2.5 → "3" at `digits = 0`, −0.05 → "−0.1". A
  result that rounds to zero prints without a minus sign.
- **B.** A wording class together with `.pct` or `.sci` is a construct error.
- **C, H, I.** Left as they are; recorded in `dev/open-findings.md`.
- **D, E.** A weft key on a link (`[a](u){if="x"}`), and an attribute block
  on inline R inside a link target, are construct errors.
- **F.** A check that raises an error is a failed check; its report line
  gives the check as written and the error's message.
- **G.** An unknown configuration key is a warning that names the key.
- **J.** On a text span a formatter class or renderer key passes through
  (1.1.9).
- **K, and the bad configuration values.** `decimal_mark` equal to
  `big_mark`, a `digits`, `count_threshold` or `word_limit` that is not a
  whole non-negative finite number, a `governor_class` that is not a number-
  or wording-stage class, and a malformed `formatters:` entry are errors
  from `read_config()`.
- **For the resolver.** `apply_formatters(value, classes, keys, config,
  governor = FALSE)`: with `governor = TRUE` it runs stages i and ii only,
  and with no formatter class, `digits` or `sigfig` it uses
  `config$governor_class`. Text classes are applied by the resolver to the
  chosen arm's final text.

## Rulings on the review of package B (`dev/review-1a-B.md`)

Findings 1 to 17 are accepted as the reviewer states them. Finding 18
(cosmetic) and 19 (performance) are left. On the lettered items:

- **A.** A vector that no collapse class joins prints its elements joined
  with ", ", as stock knitr prints an inline vector. Rule 1.4.10 is corrected.
- **B.** A failed guard is reported by its phrase as printed (the chosen
  arm's final text, markdown and all), not by the source of the arm.
- **C.** `knitr::knit_exit()` ends the document: constructs below the point
  where the knit stopped are not part of the end-of-document check (2.5.2).
- **D, F, H.** Left as they are; recorded in `dev/open-findings.md`.
- **E.** In draft mode, in a project that has been set up, the failures are
  also written to `<document name without extension>.weft-failures.json`
  beside the document, an array of objects in the collection-line schema
  (9.4.2). Without draft mode, or outside a set-up project, no such file is
  written, and a stale one from an earlier draft render is removed by a
  render that has no failures.
- **G.** An error in a bare value stops the knit as stock does (1.1.8 wins
  over 2.6.4), and the error names the right line.
- **Finding 12.** A construct in a front-matter field is a "not built yet"
  construct error in 1a, found when the knit is initialised, whichever way
  the document is activated.
- **Finding 11.** Project-level `lang` is read as rule 2.1.6 says:
  `QUARTO_EXECUTE_INFO` first, then `quarto::quarto_inspect()` when the
  `quarto` package is installed, else the document's own front matter only.
