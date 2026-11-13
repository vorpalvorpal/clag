# Set up a project for weft: every installer, from one plan

Runs, in order,
[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md),
[`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
(a Quarto project only),
[`use_dictionary()`](https://vorpalvorpal.github.io/weft/reference/use_dictionary.md),
[`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md)
(in a git work tree),
[`use_ci()`](https://vorpalvorpal.github.io/weft/reference/use_ci.md)
(when `origin` is on github.com) and
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md),
then sets the `weft_version` line of `_weft.yml` to the installed
version (it updates an existing line in place). Run it again after
updating weft to bring the files weft installed up to date.

## Usage

``` r
use_weft(path = ".")
```

## Arguments

- path:

  A folder or one document, as for
  [`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md).

## Value

The paths written, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing
changed).

## Details

It plans every step first, prints the plan (`weft will set up <root>:`,
then one line per step), and then writes. When any step cannot be done
safely (a `_quarto.yml` or front matter it cannot edit, a link or a
folder in a file's place) it writes nothing and stops with that step's
message. A step that fails while writing (a folder that cannot be
written to) undoes what the earlier steps wrote: files it created are
removed and files it changed are put back, and the message says what was
undone. It never asks, whether the session is interactive or not: the
call is the consent.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.
[`dict_vale()`](https://vorpalvorpal.github.io/weft/reference/dict_vale.md)
is not called: it is a tool, not set-up.
