# Find constants a project defines in more than one document

`dict_seed()` lists names that two or more documents each assign a
literal value, as candidates for `dict.yml`. It parses the code and
never runs it, and it writes nothing.

## Usage

``` r
dict_seed(paths = NULL, min_files = 2)
```

## Arguments

- paths:

  `NULL`, or a character vector of files.

- min_files:

  The least number of files that must assign a name, from 1.

## Value

A data frame with a row per name: `name`, `value` (its text, `NA` when
the values differ), `differs`, `n` (files), `files` and `where` (every
assignment as `<file>:<line>: <value>`). The attribute `skipped` is a
data frame (`file`, `line`, `message`) of pieces of code that did not
parse.

## Details

With `paths = NULL` it reads every `.qmd`, `.Rmd` and `.rmd` file under
the project root, except in folders whose name starts with `_` or `.` or
is `renv`. Given `paths` it reads those files, which may be `.R` files
too; a `.R` file is read only when named. In a document it reads each
`r` chunk except one with `eval = FALSE` or another `engine` in its
header, or `#| eval: false`. A file that is not UTF-8 is read as
Latin-1.

A name counts when a top-level expression of a piece (not inside `{`,
`if`, `function` or any other call) is `name <- literal`,
`name = literal` or `literal -> name`, a literal being a number, a
string, `-` or `+` of a number, or
[`c()`](https://rdrr.io/r/base/c.html) of numbers or of strings with
every argument named or none. Logicals, `NA`, `NULL`, dates, `<<-` and
[`assign()`](https://rdrr.io/r/base/assign.html) do not count.

Limits: a constant written by a computation, or inside a function or a
block, is not seen; inline R is not read; a name reused for unrelated
things in two documents is listed, and the author decides.
