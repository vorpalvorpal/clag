# Set up a Quarto project for weft

Installs the `weft-check` Lua filter (rule 2.5.3) as a project
extension, and the `pre-render` and `post-render` scripts (rules 2.5.4,
2.6.6, 2.9.4), and names them in `_quarto.yml`. It says what it will
write before it writes anything.

## Usage

``` r
use_quarto(path = ".")
```

## Arguments

- path:

  A directory in the project. `use_quarto()` walks up from it to the
  directory that holds `_quarto.yml`, says which directory it took, and
  writes there. Where there is none, it stops: it does not turn a
  directory into a Quarto project.

## Value

The paths it wrote or changed, relative to `path`, invisibly.

## Details

It writes:

- `_extensions/weft-check/_extension.yml` and `weft-check.lua`

- `_weft/pre-render.R` and `_weft/post-render.R`

- `_weft.yml`, only when there is none (empty but for a comment)

and edits `_quarto.yml`: `weft-check` is added under `filters:`, and the
two scripts under `project: pre-render:` and `post-render:`. The file is
edited as text, line by line, and never rewritten from parsed YAML:
every other line, comments and anchors included, stays as it was. When
the edit cannot be made safely (a flow-style `filters: [a, b]`, say)
`use_quarto()` stops before it writes anything and prints the lines to
add by hand. Running it again changes nothing.

The scripts are plain base R and run when weft is not installed. The
pre-render script fails the render, before anything renders, on a `.qmd`
that holds a construct and has no `engine: knitr` in its own front
matter (9.2.8). It also opens the collection file
`.weft/failures.jsonl`, which the filter and the documents append to and
the post-render script reports.
