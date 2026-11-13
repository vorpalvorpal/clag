# Set up the project dictionary

Writes a starter `dict.yml` and the JSON Schema an editor checks it
against. It says what it will write, then writes it: the call is the
consent, and it never asks.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.

## Usage

``` r
use_dictionary(path = ".")
```

## Arguments

- path:

  A directory in the project.

## Value

The paths written, relative to the root, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing was
written).

## Details

It writes, under the project root (see below):

- `dict.yml`, only when there is none: a starter that reads as a
  dictionary with no keys, with two examples commented out. An existing
  `dict.yml` is never changed; when it has no `yaml-language-server`
  schema line, or one that points somewhere else than
  `_weft/dict.schema.json`, `use_dictionary()` prints the line to use.

- `_weft/dict.schema.json`, when it is missing or differs from the
  schema of this version of weft (it is weft's own file). The folder
  `_weft/` is created if needed.

The project root is the nearest folder from `path` upward that holds
`_weft.yml`, else `_quarto.yml`, else `path` itself; when it is not
`path`, `use_dictionary()` says so and writes there.

Nothing is written through a symbolic link (`dict.yml`, `_weft` or the
schema file being one is an error, before anything is written), and a
failed write is a `weft_tool_error` naming the file: `Wrote:` names only
files that were written.

The schema covers what an editor can see of a dictionary file;
[`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
checks more (see
[dict_file](https://vorpalvorpal.github.io/weft/reference/dict_file.md)),
and a file the schema accepts can still be refused when it is read.

## Examples

``` r
if (FALSE) { # \dontrun{
use_dictionary()
} # }
```
