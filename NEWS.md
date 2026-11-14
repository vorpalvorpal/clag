# weft (development version)

- The ledger now records the tables of a document on the Jupyter or Julia engine, and of Markdown run through the filter. The filter writes one `table` entry for each Pandoc table or HTML table in a cell, keyed by the cell's label, with a digest of the cells' text, so `changes()` reports "table `tbl-sites` changed" there as it does for R. A table that a script fills in after the page loads is recorded by the HTML it holds, pandas in PDF output prints text and records nothing, and knitr documents are unchanged. These digests do not compare with the R route's. The first render after you upgrade lists each such table as added, once.
- The hint for a name published nowhere no longer says "above": it now reads "Publish it in code in this document", since a named value may be published below its use.
- The `claim-word` lint is quieter. The shipped list drops `each`, `both`, `either` and `whole` (65 words), skips idioms such as "at least" and "no longer" (`claim_words: {idioms: [...]}` adds your own), and skips a word with a hyphen beside it or a capital that does not start its sentence. A quantifier is now listed only in a sentence with a value or a digit; the new setting `claim_quantifiers` (`number`, `any` or `none`) changes that.
- A `claim-word` finding in a blockquote no longer shows the `>` markers, and the last sentence of a list item no longer runs on into the next item's marker.
- `fmt_num()` and `fmt_pct()` no longer round a number of exactly 15 significant digits one digit early when it lies just below a power of ten: `fmt_pct(999999999999999)` prints "99,999,999,999,999,900%", not "100,000,000,000,000,000%". The Lua filter prints the same.
- `.sci` prints a mantissa that rounds up to 10 as an exact 1, so 999000 prints "1 x 10^6^", as 1e6 does, not "1.0 x 10^6^". Zero prints as "0" with no exponent.
- The gate no longer counts a `claim()` in an R chunk set to `eval: false`, as it never counted one in a Python or Julia chunk. Turning `eval` off on a chunk that holds a claim is now a removal.

# weft 0.1.0

First release.

## Values in prose

* Inline R with an attribute block prints a computed value through a
  formatter class: numbers, percentages, p-values, scientific notation,
  dates, spelled and ordinal counts, lists, ranges and pairs, with keys
  for decimals, significant figures and list joins. `.plus` signs a
  difference; `.p` takes `digits` and `label`.
* Every class has a function form (`fmt_num()`, `fmt_pct()`, `fmt_p()` and
  the rest), and `weft_str()` resolves weft markup in a string from R code.
* Quantities with units (`u()`), printed by symbol or name and converted on
  request.
* Project settings in `_weft.yml` for the house style, and project
  formatters for rules no class covers.

## Wording and claims

* Spans whose wording depends on a value: counts (`n`), lists (`list`),
  conditions and guards (`if`), and direction (`sign`), with agreement
  through ids and back-references.
* `claim()` checks a value where it is used and fails the render with the
  sentence quoted. `level = "warn"` lists a check without failing.
  `chunk_claims: collect` collects failures in chunk code and fails the
  render at the end.
* Phrase functions: `of_n()`, `about()`, `ci()` (with short, percentage
  and signed forms), `pm()`, `clamp()`, `lookup()`, `brk()` and
  `in_range()`.
* `arms()` lists every wording a document can produce; `rehearse()` knits
  it under several sets of parameters.

## The dictionary

* `dict.yml` holds a project's chosen values (numbers, quantities, ranges,
  years, dates, strings, label maps and breaks), each with a definition and
  an optional decision pointer that `verify()` resolves. Decision pointers
  also go on literals, `cite` spans and claims.
* A glossary, a Vale rule for spellings to avoid, and `dict_seed()` to find
  values that belong in the dictionary.
* `tar_dict()` and `tar_dict_deps()` for `targets` pipelines.

## Other languages and named values

* Python and Julia values reach prose in knitr documents through `py$` and
  `jl_value()`, read exactly or refused.
* Named values: `` `depth`{.num} `` in a document on any engine, published
  from R (`weft_put()`, `weft_values_write()`), Python (`put()`, `auto()`)
  or Julia (`@put`) and resolved by a Pandoc filter. A name can be used
  above the code that publishes it when it takes one value.

## Checking a project

* `lints()` reads documents without running them and reports typed
  numbers, construct errors, cross-reference and citation problems and
  more.
* Each render checks its output for unresolved references, values printed
  as missing and leftover markup, in every format.
* Each render writes a ledger of the values, wording and tables it printed,
  and a log of the conditions it raised; `changes()` compares them with a
  commit.
* A commit gate refuses new typed numbers and construct errors, and asks
  for a trailer when computed values are removed. `checks()` lists the
  checks of a project by the value they check.
* `verify()` runs the lints, resolves decision pointers, renders every
  document and checks that no ledger is stale.

## Setting up

* `use_weft()` sets a project up in one call: activation, Quarto
  extension and scripts, dictionary, commit hook, GitHub Actions workflow
  and instructions for coding agents. `status()` reports what is in place.
