# Activate weft in a project's documents

Sets up the activation of weft (rule 9.2): the project `.Rprofile` that
calls
[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
in every knit, or the same call in each document's front matter,
together with the `_weft.yml` that records the weft version. It says
what it will write before it writes anything, and running it again
changes nothing.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.

## Usage

``` r
use_setup(path = ".", route = c("auto", "rprofile", "front-matter"))
```

## Arguments

- path:

  A folder or one document. Default: the current folder.

- route:

  `"auto"`, `"rprofile"` or `"front-matter"`.

## Value

The paths written, relative to the root, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing
changed).

## Details

`path` is a folder or one `.qmd`, `.Rmd` or `.rmd` file. A folder in a
Quarto project (a `_quarto.yml` here or above it) is set up at the
project root. The `route` is `"rprofile"` in a Quarto project and
`"front-matter"` otherwise, unless you choose.

It writes:

- `_weft.yml`, when there is none (a comment and `weft_version:`), or
  the `weft_version:` line appended to one that lacks it. An existing
  line is left as it is.

- route `"rprofile"`: the `.Rprofile` at the project root. A new file
  sources `~/.Rprofile` first, because R reads one profile only; an
  existing file gains a comment and the activation line after its last
  line (after `source("renv/activate.R")`, so weft is found in renv's
  library). A file that already calls
  [`weft::weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
  is kept.

- route `"front-matter"`:
  `knitr: opts_knit: weft: !expr weft::weft_setup()` in each document's
  front matter.

- `engine: knitr` in each `.qmd` that has no `engine:` or `jupyter:` key
  and is not another engine's alone, except files and folders whose
  names start with `_` or `.` (includes). A page of Python or Julia
  chunks alone gains the line only when it holds a weft construct (a
  value, a count, a governor, a sign or a list); without one it stays as
  it is.

- for an `.Rmd` outside a Quarto project, `weft-check.lua` beside the
  document (weft's own file: kept when identical, replaced when it
  differs) and, under each format of `output:`,
  `pandoc_args: ["--lua-filter", "weft-check.lua"]`.

Front matter is edited as text and checked by parsing it again. When an
edit cannot be made safely (flow-style `knitr:` or `pandoc_args`, a YAML
anchor, another `weft:` value under `opts_knit`), or a file's place
holds a folder or a symbolic link, nothing is written, and the error
prints the lines to add by hand.
