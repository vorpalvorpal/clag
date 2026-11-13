# Add the dictionary entries a pipeline reads to its targets

`tar_dict_deps()` finds, in the command of each target and in the
functions it calls from the pipeline's environment, the entries of the
dictionary it reads (`dict$key`, `dict[["key"]]`; any other use of
`dict` counts as reading every entry), and adds `dict_<key>` to the
target's dependencies (rule 4.6.2). A target made by
[`tarchetypes::tar_quarto()`](https://docs.ropensci.org/tarchetypes/reference/tar_quarto.html)
or
[`tarchetypes::tar_render()`](https://docs.ropensci.org/tarchetypes/reference/tar_render.html)
is read the same way through its source files: chunk code, inline R and
the code of constructs, included files too (rule 4.6.5). Includes rooted
at `/` resolve against the Quarto project root. A report with a `child=`
or include that the scan cannot resolve to a file (a computed path)
depends on every key. A key that the dictionary does not hold is an
error that lists every target that reads one (rule 4.6.4).

## Usage

``` r
tar_dict_deps(targets, path = "dict.yml")
```

## Arguments

- targets:

  A target object, or a list of target objects and lists, nested to any
  depth.

- path:

  The dictionary file, as given to
  [`tar_dict()`](https://vorpalvorpal.github.io/weft/reference/tar_dict.md).

## Value

`targets`, in the same structure. The target objects are changed in
place.

## Details

See
[`tar_dict()`](https://vorpalvorpal.github.io/weft/reference/tar_dict.md)
for the limit with `crew` workers: the dictionary is not visible to a
parallel worker.

## Examples

``` r
if (FALSE) { # \dontrun{
weft::tar_dict_deps(list(targets::tar_target(t, dict$limit + 1)))
} # }
```
