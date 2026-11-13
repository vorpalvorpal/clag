# Check how well the lints reproduce recorded findings

Locates each recorded finding in a source folder by its quoted text (or
by file and line), lints the folder, and reports per rule how many
located findings the rule reproduces and how much of the source it
flags.

## Usage

``` r
recall_check(
  findings,
  source,
  rules = NULL,
  commit = NULL,
  window = 2L,
  nearly = 0.8
)

# S3 method for class 'weft_recall'
print(x, ...)
```

## Arguments

- findings:

  A data frame with `id`, and `quote` or both `file` and `line`;
  optionally `file` (several paths split on `;`, `,` or white space) and
  `rule` (ids split on `;`; `NA` is every rule; `""` no rule).

- source:

  A folder of documents.

- rules:

  `NULL` (every rule) or rule ids.

- commit:

  `NULL`, or a git commit whose archive of `source` is linted.

- window:

  Half-width, in lines, used when a finding has no quote.

- nearly:

  The share of sentences at or above which a rule "flags nearly
  everything".

- x:

  A `weft_recall`.

- ...:

  Passed on.

## Value

A `weft_recall` data frame, one row per rule and a last row `any`, with
the attributes `matches` and `unlocated`.
