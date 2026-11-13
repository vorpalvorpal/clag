# The records of the most recent knit

`last_knit()` returns what weft recorded in the most recent top-level
knit in this R session, or `NULL` before any knit. The records are kept
after the knit has ended or failed.

## Usage

``` r
last_knit()
```

## Value

`NULL`, or a list with these elements:

- `constructs`: a data frame with a row for each construct the scanner
  found (its file, line, kind, expression, context, chunk, option, arm
  chosen, whether it was evaluated, and `unit_picked`: for a construct
  with a `unit` key the unit it printed in, as written in its ladder
  (rule 4.4.23), else `NA`), or `NULL` when there was none;

- `failures`: a data frame of the failures, one row for each, with the
  columns `kind`, `file`, `line`, `chunk`, `expr`, `detail`, `hint`,
  `option` and `chunk_line`;

- `warnings`: the checks that were warned about by
  `claim(level = "warn")` and the numbers that "printed as zero" (kind
  "printed as zero"), in the same columns as `failures` (zero rows when
  there are none);

- `conditions`: a data frame of the warnings and messages that chunks
  and inline code raised (`source`, `class`, `text` and `normalised`);

- `ledger`: the entries of the ledger the knit recorded, as a data frame
  of class `weft_ledger` (the columns of the ledger file, one row for
  each construct evaluated), for every top-level knit, set up or not;

- `condition_log`: the lines of the condition log, as a data frame of
  class `weft_condition_log` (`from`, `source`, `class`, `normalised`
  and `text`);

- `output`: the output name the ledger files are named by;

- `written`: the paths of the ledger and the condition log written,
  relative to the project root, each `NA` when nothing was written (the
  project is not set up, the knit is a rehearsal, or it stopped on its
  failures);

- `config`: the configuration the knit used;

- `sentence_starts`: a data frame of the values that start a sentence
  (`file`, `line`, `expr` and `text`);

- `dict` and `dict_local`: the project dictionary and the chapter's own,
  as
  [`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
  returns them, or `NULL` when there was none;

- `reads`: what the chapter read, as the ledger's header records it
  (rule 7.2.2): `dict` and `files` (named character vectors of hashes,
  the key or path as the name) and `targets` (a named list, one named
  character vector for each `targets` store). A hash is `NA` when it
  could not be taken. `NULL` for a rehearsal and for a project that is
  not set up.

## Examples

``` r
last_knit()
#> NULL
```
