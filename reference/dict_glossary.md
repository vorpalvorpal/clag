# The glossary of a dictionary

`dict_glossary()` returns the dictionary as a glossary in Pandoc
markdown: a definition list, one entry per key. It is a `knit_asis`
string, so a chunk prints it as markdown with no `results: asis`:

## Usage

``` r
dict_glossary(dict = NULL, values = TRUE, sort = TRUE)
```

## Arguments

- dict:

  A dictionary, as
  [`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
  returns, or `NULL`. `NULL` in a knit is the knit's project dictionary;
  outside a knit it reads `dict.yml` at the project root. A chapter's
  `dict_local` is accepted when given.

- values:

  Whether to show the values: `TRUE` or `FALSE`.

- sort:

  Whether to sort the entries by heading, ignoring case (`TRUE`), or
  keep the order of the file (`FALSE`).

## Value

A `knit_asis` string holding the markdown; `""` for an empty dictionary.

## Details

    dict_glossary()

It writes nothing. It is attached in a weft document as
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) and
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) are.

An entry is two lines: a heading and `: <definition>`. The heading is
the entry's `term` as written (markdown), else the key in code; then,
when `values` is `TRUE` and the entry is a `number`, `quantity`,
`range`, `year`, `date` or `string`, its value in parentheses: numbers
and quantities through
[`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md) with
the decimals written in the file (`0.50` prints `0.50`; a quantity
converted by `display:` prints as
[`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
prints it), dates through
[`fmt_date()`](https://vorpalvorpal.github.io/weft/reference/fmt.md), so
the configuration in force (marks, `thousands_from`, `unit_form`, the
`units:` table) applies; outside a knit that is the `_weft.yml` of the
project root, if there is one. A `labels` or `breaks` entry shows no
value. White space in a definition and in a string value becomes one
space (a blank line in a definition starts a paragraph, indented four
spaces so that Pandoc keeps it in the same definition); markdown is kept
as written. `why` is never shown. The string ends with a blank line, so
text after the chunk is not read as part of the last definition; a chunk
adds an HTML comment after it, since knitr drops trailing blank lines.

## Examples

``` r
f <- tempfile(fileext = ".yml")
writeLines(c("min_samples:",
             "  value: 5",
             "  type: number",
             "  term: minimum sample size",
             "  definition: Fewest samples a site needs."), f)
cat(dict_glossary(read_dict(f)))
#> 
#> minimum sample size (5)
#> :   Fewest samples a site needs.
#> 
```
