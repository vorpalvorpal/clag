# Changelog

## weft (development version)

- The hint for a name published nowhere no longer says “above”: it now
  reads “Publish it in code in this document”, since a named value may
  be published below its use.
- The `claim-word` lint is quieter. The shipped list drops `each`,
  `both`, `either` and `whole` (65 words), skips idioms such as “at
  least” and “no longer” (`claim_words: {idioms: [...]}` adds your own),
  and skips a word with a hyphen beside it or a capital that does not
  start its sentence. A quantifier is now listed only in a sentence with
  a value or a digit; the new setting `claim_quantifiers` (`number`,
  `any` or `none`) changes that.
- A `claim-word` finding in a blockquote no longer shows the `>`
  markers, and the last sentence of a list item no longer runs on into
  the next item’s marker.

## weft 0.1.0

First release.

### Values in prose

- Inline R with an attribute block prints a computed value through a
  formatter class: numbers, percentages, p-values, scientific notation,
  dates, spelled and ordinal counts, lists, ranges and pairs, with keys
  for decimals, significant figures and list joins. `.plus` signs a
  difference; `.p` takes `digits` and `label`.
- Every class has a function form
  ([`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md),
  [`fmt_pct()`](https://vorpalvorpal.github.io/weft/reference/fmt.md),
  [`fmt_p()`](https://vorpalvorpal.github.io/weft/reference/fmt.md) and
  the rest), and
  [`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
  resolves weft markup in a string from R code.
- Quantities with units
  ([`u()`](https://vorpalvorpal.github.io/weft/reference/u.md)), printed
  by symbol or name and converted on request.
- Project settings in `_weft.yml` for the house style, and project
  formatters for rules no class covers.

### Wording and claims

- Spans whose wording depends on a value: counts (`n`), lists (`list`),
  conditions and guards (`if`), and direction (`sign`), with agreement
  through ids and back-references.
- [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md)
  checks a value where it is used and fails the render with the sentence
  quoted. `level = "warn"` lists a check without failing.
  `chunk_claims: collect` collects failures in chunk code and fails the
  render at the end.
- Phrase functions:
  [`of_n()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
  [`about()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
  [`ci()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
  (with short, percentage and signed forms),
  [`pm()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
  [`clamp()`](https://vorpalvorpal.github.io/weft/reference/phrases.md),
  [`lookup()`](https://vorpalvorpal.github.io/weft/reference/lookup.md),
  [`brk()`](https://vorpalvorpal.github.io/weft/reference/lookup.md) and
  [`in_range()`](https://vorpalvorpal.github.io/weft/reference/in_range.md).
- [`arms()`](https://vorpalvorpal.github.io/weft/reference/arms.md)
  lists every wording a document can produce;
  [`rehearse()`](https://vorpalvorpal.github.io/weft/reference/rehearse.md)
  knits it under several sets of parameters.

### The dictionary

- `dict.yml` holds a project’s chosen values (numbers, quantities,
  ranges, years, dates, strings, label maps and breaks), each with a
  definition and an optional decision pointer that
  [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
  resolves. Decision pointers also go on literals, `cite` spans and
  claims.
- A glossary, a Vale rule for spellings to avoid, and
  [`dict_seed()`](https://vorpalvorpal.github.io/weft/reference/dict_seed.md)
  to find values that belong in the dictionary.
- [`tar_dict()`](https://vorpalvorpal.github.io/weft/reference/tar_dict.md)
  and
  [`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md)
  for `targets` pipelines.

### Other languages and named values

- Python and Julia values reach prose in knitr documents through `py$`
  and
  [`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md),
  read exactly or refused.
- Named values: `` `depth`{.num} `` in a document on any engine,
  published from R
  ([`weft_put()`](https://vorpalvorpal.github.io/weft/reference/weft_put.md),
  [`weft_values_write()`](https://vorpalvorpal.github.io/weft/reference/weft_values_write.md)),
  Python (`put()`, `auto()`) or Julia (`@put`) and resolved by a Pandoc
  filter. A name can be used above the code that publishes it when it
  takes one value.

### Checking a project

- [`lints()`](https://vorpalvorpal.github.io/weft/reference/lints.md)
  reads documents without running them and reports typed numbers,
  construct errors, cross-reference and citation problems and more.
- Each render checks its output for unresolved references, values
  printed as missing and leftover markup, in every format.
- Each render writes a ledger of the values, wording and tables it
  printed, and a log of the conditions it raised;
  [`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
  compares them with a commit.
- A commit gate refuses new typed numbers and construct errors, and asks
  for a trailer when computed values are removed.
  [`checks()`](https://vorpalvorpal.github.io/weft/reference/checks.md)
  lists the checks of a project by the value they check.
- [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
  runs the lints, resolves decision pointers, renders every document and
  checks that no ledger is stale.

### Setting up

- [`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md)
  sets a project up in one call: activation, Quarto extension and
  scripts, dictionary, commit hook, GitHub Actions workflow and
  instructions for coding agents.
  [`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
  reports what is in place.
