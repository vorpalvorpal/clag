# Write the GitHub Actions workflow that runs weft's static checks

Writes `.github/workflows/weft.yml` at the top of the git repository,
which is the only place GitHub reads workflows from, even when the weft
project is a subfolder (the workflow then checks that folder). On each
pull request it runs `weft::verify(static = TRUE)` from the merge base.
The workflow installs weft from `github::vorpalvorpal/weft`.

## Usage

``` r
use_ci(path = ".", overwrite = FALSE)
```

## Arguments

- path:

  A directory in the project, inside a git work tree.

- overwrite:

  Replace a workflow weft wrote that has since been edited.

## Value

The paths written, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing
changed).

## Details

It says what it will write before it writes anything. The file carries a
`weft-file` line with the weft version and a hash of its other lines: a
file weft wrote and nobody edited is replaced when its text would
differ; an edited one is left as it is unless `overwrite = TRUE`; a file
with no such line is another author's and is never replaced.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.
