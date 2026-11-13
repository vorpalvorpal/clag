# Targets for a project dictionary

`tar_dict()` makes a `targets` pipeline depend on the entries of
`dict.yml` it reads, and on nothing else in the file. It returns the
targets `dict_file` (the file), `dict_values` (the dictionary as
[`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
reads it) and `dict_<key>` (the value of each entry), and attaches the
dictionary as the object `dict` on the search path, as `weft:dict`, so
that commands and functions in the pipeline find it (rule 4.6.1). Pass
the result of the pipeline's targets to
[`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md),
which adds to each target the entries it reads. A changed value then
re-runs exactly the targets that read it, and a changed definition, a
new key or a reordered file re-runs none (rule 4.6.3).

## Usage

``` r
tar_dict(path = "dict.yml")
```

## Arguments

- path:

  The dictionary file, one string.

## Value

A list of target objects.

## Details

Do not define `dict` in `_targets.R`: `targets` would track the whole
object, and every reader would re-run when any entry changed. That is an
error.

Limit: `dict` is attached in the session that defines the pipeline. A
parallel `crew` worker does not have it, so a function that reads `dict`
fails there with "object 'dict' not found". Pass the values the function
needs as arguments, or run the pipeline without workers.

## Examples

``` r
if (FALSE) { # \dontrun{
# _targets.R
library(targets)
c(
  weft::tar_dict("dict.yml"),
  weft::tar_dict_deps(list(
    tar_target(limit_ok, dict$limit > 3)
  ))
)
} # }
```
