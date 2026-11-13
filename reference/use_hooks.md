# Install the commit-msg hook that runs the commit gate

Writes a `commit-msg` git hook that runs
[`gate()`](https://vorpalvorpal.github.io/weft/reference/gate.md) on
each commit (rules 6.1 to 6.3). It says what it will write before it
writes anything, and running it again changes nothing.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.

## Usage

``` r
use_hooks(
  path = ".",
  remove = FALSE,
  overwrite = FALSE,
  rscript = NULL,
  lib = NULL
)
```

## Arguments

- path:

  A directory in the project, which must hold `_weft.yml` and be inside
  a git work tree.

- remove:

  Remove the hook instead of installing it.

- overwrite:

  Replace a hook weft wrote that has since been edited.

- rscript:

  The `Rscript` the hook runs. Default: the one of this R.

- lib:

  The library paths the hook gives R, which must hold weft. Default:
  [`.libPaths()`](https://rdrr.io/r/base/libPaths.html).

## Value

The paths written, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing
changed).

## Details

The script is POSIX `sh`, written to the repository's hooks folder (the
one `git rev-parse --git-path hooks` names, so a linked worktree uses
the main repository's). It records the `Rscript` and the library paths
of the session that ran `use_hooks()`, and runs R with
`--no-init-file --no-environ`, so the project's `.Rprofile` (renv,
[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md))
and `.Renviron` (which could replace the recorded library paths) are not
read by the hook. When R or weft cannot be found the commit fails with a
message that names `use_hooks()` and `git commit --no-verify`; the
latter skips the hook for one commit.

- No `commit-msg` hook, and `core.hooksPath` unset: the hook is written.

- A hook weft wrote (it has a `weft-file: use_hooks` line) and has not
  been edited: rewritten when its text would differ, else kept. Edited:
  left as it is, unless `overwrite = TRUE`.

- Another tool's hook, or `core.hooksPath` set (a hook manager): left
  alone, also under `overwrite = TRUE`. The script goes to
  `<git common dir>/weft/commit-msg`, and the call prints the line to
  add to the hook your setup runs (and a `repo: local` entry when there
  is a `.pre-commit-config.yaml`).

`remove = TRUE` deletes the hook when it is weft's (edited or not) and
the folder `<git common dir>/weft/` (the script copy and the gate's
cache). Another tool's hook is left, and the call says to remove the
weft line from it.
