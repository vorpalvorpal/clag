# A Vale rule from the dictionary's `avoid` fields

`dict_vale()` writes one [Vale](https://vale.sh) `substitution` rule
that replaces each spelling an entry lists under `avoid` by the entry's
canonical spelling: its `term`, or, for a `string` entry with no `term`,
its value. It says what it will write before it writes.

## Usage

``` r
dict_vale(dict = NULL, path = "styles/Weft/Terms.yml", level = "warning")
```

## Arguments

- dict:

  A dictionary, as
  [`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
  returns, or `NULL` to read `dict.yml` at the project root. A
  dictionary with problems raises its error and nothing is written.

- path:

  The rule file, relative to the project root:
  `<styles>/<Style>/<Rule>.yml`.

- level:

  The rule's level: `"suggestion"`, `"warning"` or `"error"`.

## Value

The path written or removed, invisibly;
[`character()`](https://rdrr.io/r/base/character.html) when nothing was
changed.

## Details

The rule matches each spelling as written (`ignorecase: false`): list a
case variant as a spelling of its own. Spellings are keys of a regular
expression in Vale, so their metacharacters are escaped; longer
spellings come first.

It replaces only a file it wrote (the first line says so) and stops with
an error on any other, on a path outside the project, and on a symbolic
link or a folder in place of the rule file or its folders. When the
project's own dictionary (`dict = NULL`) has no `avoid` left, a file it
wrote is removed; a dictionary given as `dict` never removes anything.
It never writes `.vale.ini`: when that file does not list the style in
`BasedOnStyles`, it says what the file needs.
