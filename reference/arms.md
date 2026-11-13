# List the arms of every governed span of a document

Reads one or more `.qmd` or `.Rmd` files with the scanner and lists, for
every `n`, `if`, `sign` and `list` span, each of its arms: the span's
place, the key and its expression, the arm's role and the text the
author wrote. The spans are those in prose, in captions, in front-matter
fields and in literal
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
strings. No R is run: the file is parsed, never evaluated, so an
expression that stops, writes a file or names an unknown object does
nothing.

## Usage

``` r
arms(file)
```

## Arguments

- file:

  One path, or several, to documents.

## Value

A data frame of class `weft_arms`, one row per arm, with the columns
`file`, `line` (where the span starts), `context`, `span` (the span's
number in the result, in document order), `key` (`"n"`, `"if"`, `"sign"`
or `"list"`), `expr` (the key's value), `arm` (the arm's index in its
span), `role` (`"always"`, `"one"`, `"other"`, `"zero"`, `"two"`,
`"true"`, `"false"`, `"positive"` or `"negative"`), `text` (the arm as
written, trimmed), and `parent_span` and `parent_arm` (the span and arm
it is nested in, or `NA`).

## Details

A file with a construct error is still listed. The errors are in the
attribute `errors`, and the print method ends with them. A span whose
arm count is not one the key accepts is not listed; it is one of the
errors. So is an `n` span with more than one arm in a document whose
`lang` is not English, because weft ships no other plural rules (rules
1.6.4, 1.6.5).

Only the spans of the files given are listed; a document that a chunk
includes with `child=` is listed only when it is given too.

## See also

[`rehearse()`](https://vorpalvorpal.github.io/weft/reference/rehearse.md),
which knits a document under several sets of parameters and reports
which arms they chose.
