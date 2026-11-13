# Lint a project's documents without running them

Reads `.qmd` and `.Rmd` documents as text and returns the typed numbers,
construct errors and other problems the rules of
[`lint_rules()`](https://vorpalvorpal.github.io/weft/reference/lint_rules.md)
find. Nothing in a document is run.

## Usage

``` r
# S3 method for class 'weft_findings'
print(x, max = 200, ...)

lints(
  path = ".",
  files = NULL,
  rules = NULL,
  tier = 1,
  reader = c("weft", "pandoc")
)
```

## Arguments

- x:

  A `weft_findings`.

- max:

  The most findings printed.

- ...:

  Not used.

- path:

  One existing file or folder. The project root is found from it.

- files:

  `NULL`, or documents (relative to the root or absolute under it) to
  report on. File-scope rules run on these only; project-scope rules
  still read every document.

- rules:

  `NULL` (every rule of the tiers asked for), or ids from
  [`lint_rules()`](https://vorpalvorpal.github.io/weft/reference/lint_rules.md).

- tier:

  A subset of `1:2`. The default is tier 1.

- reader:

  `"weft"` (the default) or `"pandoc"`.

## Value

A `weft_findings` data frame sorted by file, line, column and rule, with
columns `file`, `line`, `col`, `end_line`, `rule`, `tier`, `spec`,
`context`, `text`, `message`, `hint` and `sentence`, and the attribute
`notes`.
