# Propose label words from the prose

Reads the project's `.qmd` and `.Rmd` documents and counts each
capitalised word that is followed, in the same block, by a typed number
("Site 3", "Stage 2"). Such words are candidates for the `label_words`
setting, which exempts the number after them from the `numeral` lint.
Cross-reference words (`Figure`, `Table`, ...), common function words
and words already in `label_words` are left out. Nothing is written.

## Usage

``` r
label_seed(paths = NULL, min_count = 2)
```

## Arguments

- paths:

  `NULL` (every document of the project the working folder is in, by the
  rules of
  [`dict_seed()`](https://vorpalvorpal.github.io/weft/reference/dict_seed.md)),
  or document paths.

- min_count:

  The fewest times a word must occur to be listed.

## Value

A data frame with `word`, `n` (how many times), `files` (in how many
files) and `where` (up to three places as
`<file>:<line>: <word> <numeral>`), sorted by `n` and then `word`.
