# The dictionary file

The project dictionary is `dict.yml` at the project root: a YAML mapping
from key to entry. An empty file, or one holding only comments, is a
dictionary with no keys. A chapter's own entries are written in its
front matter under `weft:` / `dict_local:`, in the same form with a
`why` (see below); `dict_local` is not allowed in `_weft.yml`.

## Details

Each entry has these fields; any other is an error, and so is a mistake
in any of them. All the problems in a file are reported together.

- `value` (required): by `type`, see below.

- `type` (required): one of `number`, `quantity`, `year`, `date`,
  `string`, `labels`, `breaks`.

- `definition` (required): a string that is not blank; it is the text
  the glossary shows.

- `unit`: a string, for a `quantity` only.

An empty field (`term:` with nothing after it) is read as absent. A
one-item list where a string or number is wanted (`unit: [m]`) is read
as its item.

- `display`: one unit, for a `quantity` only (rule 4.2.7): the unit to
  show the value in. The value is read in `unit` and converted to
  `display` when the file is read, so `dict$key` is already in
  `display`, and arithmetic, checks, `#` and
  [`units::drop_units()`](https://r-quantities.github.io/units/reference/drop_units.html)
  see it. A `display` that does not parse, or that `unit` does not
  convert to, is a problem; `unit =` at the use converts back. A ladder
  of units (a string with `|`, or a list of more than one item) is a
  problem: write the ladder in a `unit` key where the value is printed
  (`unit="m|km"`, rule 4.4.23), so that the unit an entry is held in
  never depends on its value. A list of one item is that unit.

- `decision`: a whole number from 1, or a string that is not blank; it
  is not resolved when the file is read. `"#12"` is read as 12; text
  such as `012`, `0x1F` or `1e3`, or a number with more digits than an
  issue number can have, is kept as written and does not resolve.

- `why`: a string that is not blank, for a `dict_local` entry only,
  where it is required.

- `term`: a string that is not blank, on any type: the words a reader
  knows the entry by.
  [`dict_glossary()`](https://vorpalvorpal.github.io/weft/reference/dict_glossary.md)
  heads the entry with it and
  [`dict_vale()`](https://vorpalvorpal.github.io/weft/reference/dict_vale.md)
  keeps it as the entry's spelling (rule 4.7.3). White space around it
  is trimmed; a `term` that holds a line break, or that starts with what
  markdown reads as a block (`#`, `>`, `-`, `*`, `+` or `:` and a space,
  `1.`, a fence), is a problem.

- `avoid`: one string, or a non-empty list of strings, none blank, in
  `dict.yml` only (rule 4.7.4). They are spellings
  [`dict_vale()`](https://vorpalvorpal.github.io/weft/reference/dict_vale.md)
  replaces by the entry's canonical spelling: its `term`, or, for a
  `string` entry with no `term`, its value; any other entry needs a
  `term`. A spelling that is the entry's own, is listed twice, is listed
  by another entry, or is found as whole words inside any entry's
  canonical spelling is a problem, and so is a spelling that starts or
  ends with a character that is not a letter or digit (Vale matches at
  word boundaries and could never match it). The `entries` columns
  `term` and `avoid` hold `NA` and `character(0)` where absent.

A key is a valid R name (`make.names(key) == key`) that is not reserved
(`..1` and `...` are refused) and is not `file`. A whole number written
with a leading zero, or in hex or octal (`010`, `0x1F`, `0o17`), is an
error: write it in decimal. A merge key (`<<`) is an error, and so is a
file of more than one YAML document; anchors and aliases without a merge
key are allowed. A whole number too large for an integer is a number (a
double), but under `year` is still an error. In a document's front
matter, `dict_local` keys that YAML reads as booleans (`yes`, `on`,
`true`) should be quoted if two of one truth value are used in one map,
since knitr and Quarto read the front matter before weft does.

|  |  |  |
|----|----|----|
| `type` | `value` | read as |
| `number` | a number, or a string that is a number literal | a double |
| `quantity` | as `number`, with `unit` | a `units` value |
| `year` | a whole number from 1000 to 9999 | a [weft_year](https://vorpalvorpal.github.io/weft/reference/weft_year.md): an integer, printed with no thousands mark |
| `date` | a string `YYYY-MM-DD` | a `Date` |
| `string` | a string (quote a number) | a character string |
| `labels` | a non-empty mapping of label to phrase | a [`lookup()`](https://vorpalvorpal.github.io/weft/reference/lookup.md) function |
| `breaks` | a non-empty list of items | a [`brk()`](https://vorpalvorpal.github.io/weft/reference/lookup.md) function |

A `breaks` item is a mapping with a `phrase` and at most one of `below`
(the value is less than the bound) or `at_most` (less than or equal to
it); the bound is a number, `.inf` or `-.inf`. Only the last item may
have no bound, and then it takes every value left. Bounds may not
decrease, and a bound may not repeat the one before it so that no value
is left for its band (`at_most: 1` then `below: 1`, or equal bounds of
one kind). A bound may be a number written in a string, as `number` may.

YAML is read so that `yes`, `no`, `on`, `off`, `true` and `false` stay
as text. A duplicate key is an error.

    core_len:
      value: 0.5
      type: quantity
      unit: m
      definition: "Length of each sediment core."
    trend_word:
      value:
        - {below: 0.95, phrase: "a fall in"}
        - {at_most: 1.05, phrase: "steady"}
        - {phrase: "a rise in"}
      type: breaks
      definition: "Wording for the ratio of this year's mean to last year's."

## See also

[`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md),
[weft_year](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
