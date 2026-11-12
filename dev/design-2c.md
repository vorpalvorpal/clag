# Package 2c — dictionary tooling

Written before any test or code. It turns the outline of `dev/design-2.md`
§4 ("2c — dictionary tooling") into a contract, and builds on 2a (§2 of that
note and its rulings) and 2f (`display:`, the `units:` table).
`PACKAGE-SCOPING.md` is amended in the commit that builds this. `␣` is
U+00A0, the no-break space; every other space is U+0020. Robin delegated the
open choices, R2 among them; each is decided here and the large ones are
listed under "For Robin", built as recommended.

## Scope and rules touched

| Rules | Change |
|---|---|
| 4.2.1 | two optional fields, `term` and `avoid` |
| 4.5.1, 4.5.2; new 4.5.3, 4.5.4 | the three resolver routes; "could not check" is not "unresolved" |
| 4.7.1, 4.7.2; new 4.7.3, 4.7.4 | `dict_glossary()`; `dict_vale()`; `term`; `avoid` |
| 9.1.2, 9.1.4, 9.1.5; new 9.1.8 | the `decisions` setting |
| 9.3.1, 9.3.3, P10 | what `use_dictionary()` writes; `inst/dict/`; `dict_vale()` writes a file |
| 9.5.2 | `dict_seed()` |
| 2.1.8 | `dict_glossary()` joins the attached functions |

Adds `R/dict-tools.R` (glossary, Vale, seed), `R/decisions.R` (the
resolver), `inst/dict/dict.schema.json`, `inst/dict/dict.yml` (the starter).
Touches `R/use.R` (`use_dictionary()`), `R/dict.R` (`term`, `avoid`),
`R/config.R` (`decisions`), `R/weft-str.R` (`inline_function_names()`),
`DESCRIPTION` (`curl` in Suggests), `NAMESPACE`. `dev/design-2.md` §1 listed
only `R/use.R` and `R/config.R`; `R/dict.R` is touched because R2 is decided
here.

Out of scope: `verify()` (stage 5) and how it reports pointers (below,
"Deferred to `verify()`"); a JSON Schema for `_weft.yml`; Vale vocabularies
(`accept.txt`); per-label spellings of a `labels` entry.

## Exported functions

```r
use_dictionary(path = ".")
dict_glossary(dict = NULL, values = TRUE, sort = TRUE)
dict_vale(dict = NULL, path = "styles/Weft/Terms.yml", level = "warning")
dict_seed(paths = NULL, min_files = 2)
```

Internal, called by tests through `weft:::`:

```r
check_decisions(dict, resolver = NULL, root = NULL, fetch = github_fetch)
github_fetch(url, token)              # the default `fetch`
parse_github_remote(url)              # c(owner = , repo = ) or NULL
decisions_route(resolver)             # list(kind = , ...) or weft_config_error
has_curl()                            # requireNamespace("curl", quietly = TRUE)
```

`dict_glossary` is added to `inline_function_names()`, so chunk code and
inline R in a weft document can call it without `library(weft)` (2.1.8).

## Two new dictionary fields: `term` and `avoid` (R2)

```yaml
min_samples:
  value: 5
  type: number
  term: minimum sample size
  avoid: [min sample size, minimum sample-size]
  definition: "Fewest samples a site needs before its mean is reported."
study_area:
  value: "Northern catchment"
  type: string
  definition: "Name used for the study region."
  avoid: ["northern catchment", "Nth. catchment"]
```

- **`term`** (4.7.3), optional on every type, in `dict.yml` and
  `dict_local`: a string that is not blank. It is the words a reader knows
  the entry by. The glossary heads the entry with it; it is the spelling
  `dict_vale()` keeps.
- **`avoid`** (4.7.4), optional, in `dict.yml` only: one string, or a
  non-empty list of strings, none blank; each is trimmed of white space at
  its ends. They are spellings to replace by the entry's **canonical
  spelling**: its `term`, or, for a `string` entry with no `term`, its
  `value`.
- `DICT_FIELDS` becomes `value, type, definition, unit, display, decision,
  why, term, avoid` (in that order), so the unknown-field problem lists the
  nine.
- The `entries` attribute gains two columns after `display`: `term`
  (character, `NA` where absent) and `avoid` (a list column, `character(0)`
  where absent; trimmed, in the order written). `print()` is unchanged.

Problems, each a line among `read_dict()`'s problems in its usual form
(`<file>:<line>: \`<key>\`: <what> (rule <n>)`), all of class
`weft_dict_error`:

| Case | `<what> (rule)` |
|---|---|
| `term` not a non-blank string | `` `term` must be a string that is not blank (rule 4.7.3) `` |
| `avoid` empty, not text, or holding a blank or non-string item | `` `avoid` must be a string, or a list of strings, none blank (rule 4.7.4) `` |
| `avoid` on an entry that is not `string` and has no `term` | `` `avoid` needs a `term`: the spelling the avoided ones are replaced by (rule 4.7.4) `` |
| a spelling equal to the entry's own canonical spelling | `` `avoid` lists `<v>`, which is the entry's own spelling (rule 4.7.4) `` |
| a spelling listed twice in one entry | `` `avoid` lists `<v>` twice (rule 4.7.4) `` |
| a spelling another entry's `avoid` also lists (on the later entry) | `` `avoid` lists `<v>`, which `<key2>` also lists (rule 4.7.4) `` |
| a spelling found, as whole words, inside any entry's canonical spelling (its own included) | `` `avoid` lists `<v>`, which is part of the spelling `<canon>` of `<key2>`; Vale would flag that spelling (rule 4.7.4) `` |
| `avoid` in `dict_local` | `` `avoid` is for dict.yml; a chapter's own entries write no Vale rules (rule 4.7.4) `` |

Comparisons are case-sensitive. "As whole words": `<v>` matches the PCRE
`(?<![[:alnum:]_])<v escaped>(?![[:alnum:]_])` in `<canon>`; equality is
reported by the fourth row only. The cross-entry rows are checked after
every entry is read, in file order, and only between entries whose own
`term`/`avoid` had no problem. Canonical spellings are not required to be
unique.

## `use_dictionary(path = ".")`

1. `path` must be one string naming an existing directory, else
   `weft_tool_error`: `` use_dictionary(): `path` must be a directory; got
   `<path>`. `` (`<path>` as given; "something else" when not one string).
2. The project root is `find_project_root(path)` (`_weft.yml`, else
   `_quarto.yml`, walking up; else `path`). When it differs from
   `normalizePath(path)`: message `weft: the project root is <root> (it holds
   <marker>); writing there.`, `<marker>` being `_weft.yml` when the root
   holds one, else `_quarto.yml`.
3. Two files are considered:
   - `dict.yml` at the root: written (copied byte for byte from
     `inst/dict/dict.yml`) only when absent. An existing `dict.yml` is never
     changed.
   - `_weft/dict.schema.json` at the root: copied byte for byte from
     `inst/dict/dict.schema.json` when absent, or when its MD5 differs from
     the shipped file (weft's own file, replaced by this version's). The
     directory `_weft/` is created if missing.
4. When at least one file will be written, the messages, each a separate
   `message()`, in this order:

   ```
   weft will write, under <root>:
     dict.yml  (new: a starter dictionary, with two examples commented out)
     _weft/dict.schema.json  (new: the JSON Schema an editor checks dict.yml against)
   ```

   with these alternatives for the two lines:

   ```
     dict.yml  (exists: left as it is)
     _weft/dict.schema.json  (exists and is current: left as it is)
     _weft/dict.schema.json  (exists: replaced by the schema of this version of weft)
   ```

   then the files are written, then `Wrote: <a>, <b>` naming what was
   written, in the order above. When nothing will be written, one message
   only: `Nothing to change: dict.yml and its schema are in place.`
5. When `dict.yml` existed and has no line containing
   `yaml-language-server: $schema=`, a further message after the others:

   ```
   dict.yml has no schema line; for an editor to check it, add this as its first line:
     # yaml-language-server: $schema=_weft/dict.schema.json
   ```

6. Returns, invisibly, the paths written, relative to the root
   (`c("dict.yml", "_weft/dict.schema.json")`, either, or `character()`).
7. It never asks. Interactive or not, it says what it will write and then
   writes it: the call is the consent (P10, 9.3.1). `suppressMessages()`
   silences it.

### The starter: `inst/dict/dict.yml`, exactly

```yaml
# yaml-language-server: $schema=_weft/dict.schema.json
#
# The project dictionary: the values this project chose, each with its
# definition. Prose and code read an entry as dict$key. Every entry has a
# value, a type and a definition; the types are number, quantity, year,
# date, string, labels and breaks. See ?weft::dict_file for every field.
#
# A unit the units package does not know (sites, PSU) is registered when
# this file is read; give it a name under `units:` in _weft.yml.
#
# Two examples follow. Remove the "# " before an entry's lines to use it.
#
# core_len:
#   value: 50
#   type: quantity
#   unit: cm
#   display: m            # read in cm, shown in m: dict$core_len is 0.5 m
#   definition: "Length of each sediment core."
#   decision: 12          # the issue where the length was chosen
#
# study_area:
#   value: "Northern catchment"
#   type: string
#   definition: "Name used for the study region."
#   avoid: ["northern catchment", "North catchment"]   # see dict_vale()
```

LF line endings, a final newline, no trailing spaces. As written it is a
dictionary with no keys. With `sub("^# ?", "", x)` applied to every line from
`# core_len:` to the end, it is a dictionary of two keys that `read_dict()`
and the schema both accept (`dict$core_len` is `0.5 [m]`).

The schema line's path is relative to `dict.yml`, which the
`yaml-language-server` (the VS Code and Positron YAML extension, and others)
resolves against the file's own folder.

### The schema: `inst/dict/dict.schema.json`, exactly

JSON Schema draft-07. Two-space indentation as below; a final newline.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "weft dictionary",
  "description": "A weft project dictionary (dict.yml): a mapping from key to entry. Read by weft::read_dict(), which checks more than this schema can (see ?weft::dict_file).",
  "type": "object",
  "propertyNames": { "$ref": "#/definitions/key" },
  "additionalProperties": { "$ref": "#/definitions/entry" },
  "definitions": {
    "key": {
      "description": "A syntactic R name that is not reserved, and not `file` (rule 4.1.3).",
      "type": "string",
      "pattern": "^(?:[A-Za-z][A-Za-z0-9._]*|[.](?:[A-Za-z._][A-Za-z0-9._]*)?)$",
      "not": {
        "anyOf": [
          { "enum": ["if", "else", "repeat", "while", "function", "for", "next", "break", "in",
                     "TRUE", "FALSE", "NULL", "Inf", "NaN", "NA", "NA_integer_", "NA_real_",
                     "NA_character_", "NA_complex_", "file"] },
          { "pattern": "^[.][.](?:[.]|[0-9]+)$" }
        ]
      }
    },
    "text": {
      "type": "string",
      "pattern": "\\S"
    },
    "numberish": {
      "description": "A number, or a string that is a number literal such as \"1e-3\".",
      "anyOf": [
        { "type": "number" },
        { "type": "string", "pattern": "^\\s*[+-]?(?:[0-9]+[.]?[0-9]*|[.][0-9]+)(?:[eE][+-]?[0-9]+)?\\s*$" }
      ]
    },
    "year": {
      "description": "A whole number from 1000 to 9999.",
      "anyOf": [
        { "type": "integer", "minimum": 1000, "maximum": 9999 },
        { "type": "string", "pattern": "^\\s*[+-]?(?:[0-9]+[.]?[0-9]*|[.][0-9]+)(?:[eE][+-]?[0-9]+)?\\s*$" }
      ]
    },
    "date": {
      "description": "A date written YYYY-MM-DD.",
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    },
    "labels": {
      "description": "A mapping from label to phrase.",
      "type": "object",
      "minProperties": 1,
      "additionalProperties": { "type": "string" }
    },
    "breaks": {
      "description": "Bands, in order: each a phrase and at most one of `below` and `at_most`; only the last may have no bound.",
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["phrase"],
        "additionalProperties": false,
        "properties": {
          "phrase": { "type": "string" },
          "below": { "$ref": "#/definitions/numberish" },
          "at_most": { "$ref": "#/definitions/numberish" }
        },
        "not": { "required": ["below", "at_most"] }
      }
    },
    "entry": {
      "type": "object",
      "required": ["value", "type", "definition"],
      "additionalProperties": false,
      "properties": {
        "value": { "description": "The value, written as its `type` says." },
        "type": {
          "description": "How the value is read.",
          "enum": ["number", "quantity", "year", "date", "string", "labels", "breaks"]
        },
        "definition": {
          "description": "What the value is; the glossary's text (rule 4.7.1).",
          "$ref": "#/definitions/text"
        },
        "unit": {
          "description": "The unit the value is written in; a quantity only (rule 4.2.1).",
          "$ref": "#/definitions/text"
        },
        "display": {
          "description": "The unit the value is read in; a quantity only (rule 4.2.7).",
          "$ref": "#/definitions/text"
        },
        "decision": {
          "description": "Where the choice is recorded: an issue number, or an id the project's resolver knows (rule 4.5).",
          "anyOf": [
            { "type": "integer", "minimum": 1 },
            { "$ref": "#/definitions/text" }
          ]
        },
        "term": {
          "description": "The term the glossary shows, and the spelling dict_vale() keeps (rule 4.7.3).",
          "$ref": "#/definitions/text"
        },
        "avoid": {
          "description": "Spellings to avoid; dict_vale() writes a rule that replaces each with the term (rule 4.7.4).",
          "anyOf": [
            { "$ref": "#/definitions/text" },
            { "type": "array", "minItems": 1, "items": { "$ref": "#/definitions/text" } }
          ]
        }
      },
      "allOf": [
        { "if": { "properties": { "type": { "const": "number" } }, "required": ["type"] },
          "then": { "properties": { "value": { "$ref": "#/definitions/numberish" } } } },
        { "if": { "properties": { "type": { "const": "quantity" } }, "required": ["type"] },
          "then": { "required": ["unit"], "properties": { "value": { "$ref": "#/definitions/numberish" } } } },
        { "if": { "properties": { "type": { "const": "year" } }, "required": ["type"] },
          "then": { "properties": { "value": { "$ref": "#/definitions/year" } } } },
        { "if": { "properties": { "type": { "const": "date" } }, "required": ["type"] },
          "then": { "properties": { "value": { "$ref": "#/definitions/date" } } } },
        { "if": { "properties": { "type": { "const": "string" } }, "required": ["type"] },
          "then": { "properties": { "value": { "type": "string" } } } },
        { "if": { "properties": { "type": { "const": "labels" } }, "required": ["type"] },
          "then": { "properties": { "value": { "$ref": "#/definitions/labels" } } } },
        { "if": { "properties": { "type": { "const": "breaks" } }, "required": ["type"] },
          "then": { "properties": { "value": { "$ref": "#/definitions/breaks" } } } },
        { "if": { "properties": { "type": { "not": { "const": "quantity" } } }, "required": ["type"] },
          "then": { "properties": { "unit": false, "display": false } } },
        { "if": { "required": ["avoid"] },
          "then": { "anyOf": [
            { "required": ["term"] },
            { "properties": { "type": { "const": "string" } }, "required": ["type"] }
          ] } }
      ]
    }
  }
}
```

`why` is absent on purpose: the schema is for `dict.yml`, where `why` is an
error (4.3.3), and `additionalProperties: false` refuses it.

**How the schema and `read_dict()` agree.** The schema is never stricter
than `read_dict()`, with two stated exceptions, and `read_dict()` checks
more than the schema can.

- *Schema never refuses what `read_dict()` reads*, except **E1**: a field
  that wants text written as a bare `true` or `false` (`definition: true`).
  weft reads it as text (4.2.5); an editor reads YAML 1.2, where it is a
  boolean, and asks for quotes. Kept: an unquoted `true` where text is meant
  is nearly always a slip. **E2**: a key with a letter outside A–Z
  (`café`). R accepts it in a UTF-8 locale and not in others; the schema
  refuses it, so an editor warns of a key that breaks on another machine.
- *Only `read_dict()` refuses*: a number with a leading zero, hex or octal;
  a merge key; two documents; a duplicate key; an unquoted `null` key; a
  date that is not in the calendar (`2024-02-30`); a year outside 1000–9999
  written as a string; a `breaks` bound that decreases, repeats, or a bare
  item that is not last; a non-finite `number` (`.inf`); a unit that does
  not parse or is misread (4.4.20); a `display` that does not convert; every
  `avoid` problem but the shape and the missing `term`; `why` rules in
  `dict_local` (not a file the schema sees).

## `dict_glossary(dict = NULL, values = TRUE, sort = TRUE)`

Returns the glossary as Pandoc markdown, a `knit_asis` string
(`knitr::asis_output()`), so a chunk prints it as markdown with no `results:
asis`. It writes nothing (P10).

```{r}
dict_glossary()
```

- `dict`: a `weft_dict`, or `NULL`. `NULL` in a knit that weft initialised:
  the knit's project `dict`; if the knit has none, `weft_tool_error`
  `` dict_glossary(): this document's project has no dict.yml; give `dict`. ``
  `NULL` outside a knit: `read_dict(file.path(root, "dict.yml"))`, `root`
  being `find_project_root(getwd())`; if that file is absent,
  `weft_tool_error` `` dict_glossary(): there is no dict.yml at <root>; give
  `dict`, or create one with use_dictionary(). `` Anything else that is not a
  `weft_dict`: `` dict_glossary(): `dict` must be a dictionary, as read_dict()
  returns; got <first class>. ``
- `values`, `sort`: `TRUE` or `FALSE`, else `` dict_glossary(): `values` must
  be TRUE or FALSE. `` (or `sort`), `weft_tool_error`.
- A local dictionary (`dict_local`) is accepted and treated alike. The
  default is the project dictionary only: a chapter's local entries narrow a
  key for that chapter and are not the project's glossary. `why` is never
  shown (4.3.3: nothing else lists it).

**An entry**, every entry of every type, is two lines:

```
<heading>
:   <definition>
```

- `<heading>`: the entry's `term` as written (markdown), or the key in code
  (`` `core_len` ``); then, when `values` is `TRUE` and the type is
  `number`, `quantity`, `year`, `date` or `string`, a space and
  `(<value>)`. `labels` and `breaks` show no value.
- `<value>`: `number`, `quantity`, `year`: `fmt_num(x, digits = d)`, where
  `d` is the count of characters after the `.` in `format(v, digits = 15,
  scientific = FALSE, trim = TRUE)` (0 when there is none) and `v` is the
  number (`units::drop_units()` for a quantity, so in its `display` unit).
  The stipulated value prints as written, with the configuration in force:
  marks, minus, `thousands_from`, `unit_form`, the `units:` table. `date`:
  `fmt_date(x)`. `string`: the value. A formatter's error propagates.
- `<definition>` and a `string` value: white-space runs (newlines included)
  become one space, then trimmed. Markdown is printed as written.
- Order: `sort = TRUE` sorts by `tolower(<heading text>)` with
  `method = "radix"`, the heading text being the `term` or the key without
  backticks, ties by key; `sort = FALSE` keeps file order.
- The string is `"\n"`, the entries joined by `"\n\n"`, and `"\n"`. The
  leading newline separates the list from text knitr puts straight above
  the chunk's output. An empty dictionary gives `""`.

Example, with the fixture `tests/testthat/_dict-tools/dict.yml` (test plan)
and the default configuration:

```

core length (0.5␣m)
:   Length of each sediment core.

Method change (2014)
:   First year of the instrument method.

minimum sample size (5)
:   Fewest samples a site needs before its mean is reported.

`salinity_res` (0.01␣PSU)
:   Logger resolution for salinity.

`study_area` (Northern catchment)
:   Name used for the study region.

`survey_start` (1 June 2024)
:   First day of the summer survey.

`trend_word`
:   Wording for the ratio of this year's mean to last year's.

zone names
:   Display names for the survey zones.
```

With `values = FALSE` the headings lose their parentheses; with `sort =
FALSE` the entries are in file order.

## `dict_vale(dict = NULL, path = "styles/Weft/Terms.yml", level = "warning")`

Writes one Vale `substitution` rule from the `avoid` fields.

- `dict`: as `dict_glossary()` outside a knit (`NULL` reads `dict.yml` at
  `find_project_root(getwd())`); the same errors, naming `dict_vale()`. A
  dictionary with problems raises its `weft_dict_error` and nothing is
  written.
- `path`: relative to the project root (absolute kept). It must end in
  `.yml` and have at least two parts above the file (`<styles>/<Style>/
  <Rule>.yml`), else `weft_tool_error` `` dict_vale(): `path` must name a rule
  file inside a style folder, as styles/Weft/Terms.yml; got `<path>`. ``
- `level`: `suggestion`, `warning` or `error`, else `weft_tool_error`
  `` dict_vale(): `level` must be one of suggestion, warning or error. ``

**The rule**, exactly (UTF-8, LF, final newline), for the fixture:

```yaml
# Generated by weft::dict_vale() from dict.yml. Do not edit: change the
# `avoid:` fields in dict.yml and run weft::dict_vale() again.
extends: substitution
message: "Use '%s' instead of '%s' (the project dictionary's spelling)."
level: warning
ignorecase: false
swap:
  'minimum sample-size': 'minimum sample size'
  'northern catchment': 'Northern catchment'
  'min sample size': 'minimum sample size'
  'Nth\. catchment': 'Northern catchment'
```

- `dict.yml` in the header is `basename(attr(dict, "file"))`. `level` is
  the argument.
- One `swap` line per avoided spelling: key the spelling with the RE2
  metacharacters `\ . + * ? ( ) | [ ] { } ^ $` escaped by a backslash (Vale
  reads keys as regular expressions); value the entry's canonical spelling.
  Both in YAML single quotes, a `'` written `''`. Sorted by the spelling's
  length (unescaped, in characters) from longest, then by the spelling with
  `method = "radix"`, so a longer spelling wins where Vale's alternation
  would match a shorter one at the same place.
- `ignorecase: false`: each spelling matches as written. An author lists a
  case variant ("northern catchment") as a spelling of its own.

**Behaviour.** In order:

1. With no `avoid` in the dictionary: if `path` holds a file whose first
   line starts with `# Generated by weft::dict_vale()`, message `weft will
   remove <abs path>: <dict file> has no avoid: spellings now.`, remove it,
   message `Removed: <abs path>`, return it invisibly. Otherwise message
   `<dict file> has no avoid: spellings, so there is no rule to write.` and
   return `character()` invisibly.
2. If `path` holds a file that does not start with that line:
   `weft_tool_error` `` dict_vale(): <abs path> exists and was not written by
   dict_vale(); nothing was written. Move it, or give another `path`. ``
3. If the file holds exactly the text above: message `Nothing to change:
   <abs path> is up to date.`, return `character()` invisibly.
4. Else message `weft will write <abs path>: a Vale substitution rule with N
   avoided spelling(s) from <dict file>.`, create the folders, write, message
   `Wrote: <abs path>`, return it invisibly.
5. After 3 or 4: unless `.vale.ini` at the root has a line matching
   `^\s*BasedOnStyles\s*=.*\b<Style>\b`, message `Vale uses this rule when
   .vale.ini, at <root>, sets StylesPath = <styles> and lists <Style> in
   BasedOnStyles.` (`<styles>` the path's folder above the style, relative to
   the root; `<Style>` the style folder's name). weft never writes
   `.vale.ini`.

`<abs path>` is `normalizePath(<path>, mustWork = FALSE)` under the root;
`<dict file>` is `basename(attr(dict, "file"))`. Each message is one
`message()`.

## `dict_seed(paths = NULL, min_files = 2)`

Finds constants a project defines in more than one document, as candidates
for `dict.yml` (9.5.2). It parses; it never evaluates. It writes nothing.

- `paths`: `NULL`, or a character vector of files. `NULL`: every file under
  `root = find_project_root(getwd())` whose name ends `.qmd`, `.Rmd` or
  `.rmd`, recursively, except under a folder whose name starts with `_` or
  `.` or is `renv`; shown relative to the root and sorted with `method =
  "radix"`. Given: each must exist (else `weft_tool_error` `dict_seed(): no
  such file: <a>, <b>.`) and end `.qmd`, `.Rmd`, `.rmd`, `.R` or `.r` (else
  `dict_seed(): <file> is not a .qmd, .Rmd or .R file.`); shown as given, in
  the order given. With `NULL` and no file found: message `dict_seed(): no
  .qmd or .Rmd files under <root>.` and the empty result.
- `min_files`: a whole number from 1, else `weft_tool_error` `dict_seed():
  `min_files` must be a whole number from 1.`
- **What is read.** A `.R` file: the whole file. A `.qmd`/`.Rmd`: each
  chunk whose engine is `r` or `R`, as stage 1's `find_chunks()` finds them
  (after `dequote_chunks()`), its lines between the fences (to the end of the
  file for an unclosed chunk). A chunk is left out when its header matches
  `\beval\s*=\s*(FALSE|F)\b` or it has a line `#| eval: false` (or `no`, any
  case). Each piece is `parse(text = , keep.source = TRUE)`; a piece that does
  not parse is skipped and recorded.
- **What counts.** A top-level expression of the piece (not inside `{`,
  `if`, `function`, `local()` or any other call) that is a call to `<-` or
  `=` (`->` parses as `<-`) whose left side is a symbol and whose right side
  is a literal. `<<-`, `->>`, `assign()` do not count. A **literal**: a
  number constant (double or integer, finite, not complex); a string
  constant; `-` or `+` applied to a number constant; `c(...)` of one or more
  of those, all numbers or all strings, with every argument named or none.
  Logical constants, `NA`, `NULL`, dates and anything else do not count.
  Folding a literal (negating, combining with `c`) is done on the parse
  tree; no code runs.
- **A value's text**: `paste(deparse(v, width.cutoff = 500L), collapse = "
  ")` with integers made doubles (`2000L` is `2000`, `5e-2` is `0.05`). Two
  values are the same when, integers made doubles, they are `identical()`.
- **The line** of an assignment is its first line in the file.

Returns a data frame, one row per name assigned a literal in at least
`min_files` distinct files, sorted by `n` (largest first) then `name`
(`method = "radix"`), row names `NULL`, with columns:

| Column | Type | Holds |
|---|---|---|
| `name` | character | the name |
| `value` | character | the value's text when every assignment gives the same value, else `NA` |
| `differs` | logical | whether the values differ |
| `n` | integer | the number of files |
| `files` | character | the files, in the order of the file list, joined by `", "` |
| `where` | character | every assignment, `<file>:<line>: <value text>`, by file in that order then line, joined by `"; "` |

Attribute `skipped`: a data frame `file`, `line` (the chunk's opening fence,
or 1 for a `.R` file), `message` (the first line of the parse error), zero
rows when none. When it has rows, a message `dict_seed(): N piece(s) of code
could not be parsed and were skipped; see attr(<result>, "skipped").`
The empty result has these columns and zero rows.

Limits, said in the help: a constant written by a computation, or inside a
function or a block, is not seen; inline R is not read; a `.R` file is read
only when named; a name reused for unrelated things in two documents is
listed (the author decides).

## The `decision:` resolver (4.5)

### The setting `decisions` (9.1.8)

In `_weft.yml`; default `github`. Read by `decisions_route()`:

| Written | Route |
|---|---|
| `github` | GitHub issues of the repository named by `git remote get-url origin` |
| `github:<owner>/<repo>`, matching `^github:([A-Za-z0-9-]+)/([A-Za-z0-9._-]+)$` | GitHub issues of that repository |
| any string holding `{id}` (`decisions/{id}-*.md`) | a file glob, relative to the project root |
| `pkg::fun`, or a syntactic R name (`^[A-Za-z.][A-Za-z0-9._]*$`) | a function of the id |

Anything else (or not one string) is a `weft_config_error` when the
configuration is read (`validate_config()`) and in `check_decisions()`:
`` The setting `decisions` must be `github`, `github:<owner>/<repo>`, a file
pattern holding `{id}` (as decisions/{id}-*.md), or a function written
pkg::fun; got `<value>` (rule 9.1.8). `` A `github:` value that does not match
the pattern is in "anything else".

`decisions` is a project setting (9.1.4): in a document's `weft:` front
matter where `_weft.yml` exists it is a `weft_config_error`: `` `decisions` is
a project setting: set it in _weft.yml, not in a document's `weft:` front
matter (rule 9.1.4). `` A single document with no `_weft.yml` may set it.
`decisions` joins `default_config()`, so it no longer warns as unknown.

### `check_decisions(dict, resolver = NULL, root = NULL, fetch = github_fetch)`

- `dict`: a `weft_dict` (project or local). `root`: `NULL` means
  `find_project_root(attr(dict, "file"))`. `resolver`: `NULL` means the
  `decisions` value of `_weft.yml` at `root` (read with `yaml::read_yaml`; an
  unreadable file is the `weft_config_error` `read_config()` gives), else
  `"github"`.
- One row per entry whose `decision` is not `NA`, in file order:

| Column | Type | Holds |
|---|---|---|
| `file` | character | `attr(dict, "file")` |
| `line` | integer | the entry's line |
| `key` | character | the key |
| `decision` | character | the pointer as stored (`"31"`, `"zones-2023"`) |
| `resolved` | logical | `TRUE` resolved, `FALSE` does not resolve, `NA` **could not check** |
| `detail` | character | below; begins `could not check: ` exactly when `resolved` is `NA` |

  With no pointers: zero rows, these columns and types, and no call to
  `fetch`, git or a function.
- Each distinct pointer is checked once per call; rows that share it share
  the result. Nothing is cached between calls.

**GitHub** (`github`, `github:o/r`). A pointer that does not match
`^[1-9][0-9]*$` is `FALSE`: `` `<id>` is not an issue number; the github
resolver takes whole numbers (rule 4.5.3) ``, with no request. If no pointer
is a number, nothing else happens. Otherwise:

1. Repository. `github:o/r` gives it. `github`: when `Sys.which("git")` is
   empty, every number row is `NA`, `could not check: no GitHub repository
   (git is not installed); set decisions: github:<owner>/<repo> in
   _weft.yml`. Else `git -C <root> remote get-url origin`; a non-zero exit
   gives the same with `(no git remote `origin`)`; a URL that
   `parse_github_remote()` refuses, the same with `(the remote `origin` is not
   on github.com)`. The remote URL is never printed (it may hold a token).
2. Token: `Sys.getenv("GITHUB_PAT")`, else `Sys.getenv("GITHUB_TOKEN")`;
   empty means none (`token = NULL`). `<VAR>` below is the variable used. The
   token is never printed.
3. `fetch("https://api.github.com/repos/<o>/<r>", token)`, then for each
   number in order of first appearance `fetch("https://api.github.com/repos/
   <o>/<r>/issues/<id>", token)`. `fetch` returns `list(status = <integer or
   NA>, error = <NULL or string>)`.
4. Results. The repository call: 200 goes on; anything else makes every
   number row `NA` with the detail below and stops. An issue call: 200 is
   `TRUE` (an issue or a pull request, open or closed); 404 or 410 is
   `FALSE`; anything else makes that row and every later number row `NA`
   with the detail below, and no further call is made.

| Outcome | `detail` |
|---|---|
| issue 200 | `<o>/<r>#<id> exists` |
| issue 404, 410 | `<o>/<r> has no issue or pull request #<id>` |
| repository 404, no token | `could not check: <o>/<r> is not visible (private without a token, or misnamed); set GITHUB_PAT` |
| repository 404, token | `could not check: <o>/<r> is not visible with the token in <VAR>` |
| 401 | `could not check: GitHub refused the token in <VAR> (401)` |
| 403 or 429, no token | `could not check: GitHub refused the request (<status>), usually its limit of 60 requests an hour without a token; set GITHUB_PAT` |
| 403 or 429, token | `could not check: GitHub refused the request (<status>) with the token in <VAR>` |
| `status` `NA` | `could not check: GitHub could not be reached (<error>)` |
| any other status | `could not check: GitHub answered <status>` |

The repository is checked first because GitHub answers 404 for an issue in
a private repository it will not show: without that check a missing token
would read as "unresolved".

`parse_github_remote(url)` accepts, with an optional `.git` and trailing
`/`: `https://github.com/<o>/<r>`, `http://` and `www.` forms, `https://<any
credentials>@github.com/<o>/<r>`, `git@github.com:<o>/<r>`,
`ssh://git@github.com[:port]/<o>/<r>`. It returns `c(owner = , repo = )`;
anything else (another host, a path that is not two parts) `NULL`.

`github_fetch(url, token)`: when `has_curl()` is `FALSE`, returns
`list(status = NA_integer_, error = "the curl package is not installed;
install.packages(\"curl\")")` with no request. Else a GET with
`curl::curl_fetch_memory()`, headers `Accept: application/vnd.github+json`,
`User-Agent: weft (R package)`, `X-GitHub-Api-Version: 2022-11-28`, and
`Authorization: Bearer <token>` when a token is given; timeout 10 s,
redirects followed. Returns the status code, or `NA` and the error's message
when the request fails. It is the only code in weft that touches the
network, and no test calls it except with `has_curl()` mocked to `FALSE`.

**Glob** (a string holding `{id}`). A pointer holding any of `* ? [ ] / \`
is `FALSE`: `` `<id>` holds a character a file pattern cannot match
literally (* ? [ ] / \) ``. Else every `{id}` is replaced by the pointer and
the result, relative to the root unless absolute, is passed to `Sys.glob()`;
directories are dropped. One or more files: `TRUE`, detail the first match
relative to the root (sorted, `method = "radix"`), plus ` and N more` when
N > 0 more match. None: `FALSE`, `no file matches <pattern with the id put
in>`. A pattern is a glob and nothing more: `decisions/{id}*.md` matches
`31-x.md` for pointer 3, which is why the examples write `{id}-*.md`.

**Function** (`pkg::fun` or a name). Found as `resolve_formatter()` finds a
formatter: `pkg::fun` in the namespace of `pkg`, a bare name in the global
environment. Not found: `weft_config_error` `` Cannot find the decisions
function `<fun>` (rule 9.1.8). `` Called once per distinct pointer with the
pointer as one string. `TRUE`: `<fun> returned TRUE`. `FALSE`: `<fun>
returned FALSE`. `NA` (logical): `could not check: <fun> returned NA`. An
error: `could not check: <fun> failed: <first line of the message>`.
Anything else: `could not check: <fun> returned <description>, not TRUE,
FALSE or NA`, `<description>` being `a <class> of length <n>`.

### Deferred to `verify()` (stage 5)

`check_decisions()` has no caller in 2c but its tests. Stage 5 decides: that
`verify()` calls it for `dict.yml` and for each verified document's
`dict_local`, in step 2 of 8.1.1 and under `static = TRUE`; how the rows are
printed (`<file>:<line>: \`<key>\`: decision <id>: <detail>`); that `FALSE`
fails `verify()` (4.5.2, tier 1). Recommended for `NA`: reported with its
detail, counted, and not failing, unless the rule is made strict (8.1.3). A
machine offline then does not fail, and CI, which has the network and
`GITHUB_TOKEN`, checks every pointer.

## Configuration keys

```yaml
# _weft.yml
decisions: github          # default; or github:<owner>/<repo>, decisions/{id}-*.md, pkg::fun
```

No other key. The glossary prints values under the configuration in force,
`units:` included (9.1.7).

## Errors

All carry `weft_error`. `weft_tool_error` is new.

| Class | When | The message says |
|---|---|---|
| `weft_tool_error` | a bad argument to one of the four exports | the function, the argument, what it must be (strings above) |
| `weft_tool_error` | `dict = NULL` and no `dict.yml` (outside a knit) or no project dict (in a knit) | where it looked; give `dict`; `use_dictionary()` |
| `weft_tool_error` | `dict_vale()`'s `path` holds a file it did not write | the path; nothing written; move it or give another `path` |
| `weft_tool_error` | `dict_seed()` given a missing file or another extension | the files |
| `weft_dict_error` | a `term` or `avoid` problem | a line among the dictionary's problems (4.7.3, 4.7.4) |
| `weft_config_error` | a bad `decisions`; `decisions` in front matter where `_weft.yml` exists; a decisions function that cannot be found | the value, the four forms; the rule (9.1.4, 9.1.8) |

`check_decisions()` raises nothing for a pointer: every outcome is a row.

## What the spec leaves open, decided here

| # | Gap | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| C1 | R2: where canonical spellings live | (a) `avoid` on `string`/`labels`, value canonical; (b) `type: term`; (c) `terms.yml`; (d) `term` + `avoid` on any entry | (d), a `string`'s value canonical when it has no `term` | one field serves the glossary heading and Vale; any type can carry a term; no second file to keep in step; a pure term is a `string` entry | `R/dict.R`, the schema |
| C2 | glossary: file or function | a file under `generated/`; a markdown string; `knit_asis` | `knit_asis` from `dict_glossary()` | writes nothing (P10); no `results: asis` to forget | `R/dict-tools.R` |
| C3 | what heads an entry | the key; a prettified key; `term` | `term`, else the key in code | a key is an R symbol; a prettified key ("Min samples") is guessed text | one function |
| C4 | values in the glossary | none; on the definition line; in the heading | in the heading, through `fmt_num()`/`fmt_date()` with the decimals as stipulated; `values = FALSE` drops them | the value is the stipulation; the house style and unit names apply; default digits would print 0.01 as "0.0" | one function |
| C5 | order | file; alphabetical | alphabetical, `sort = FALSE` for file order | a glossary is looked up | an argument default |
| C6 | `labels`, `breaks` | show the map or the bands; definition only | definition only | no reading of a map or bands as one phrase is obvious | one branch |
| C7 | `dict_local` in the glossary | merged; never; on request | on request (`dict = dict_local`), never `why` | 4.3.3; a chapter's narrowing is not the project's term | one default |
| C8 | `avoid` in `dict_local` | allowed; a problem | a problem | a Vale rule is project-wide | one check |
| C9 | conflicts among spellings | let Vale find out; check when read | checked by `read_dict()` (dup, own, inside a canonical) | a spelling inside a canonical makes Vale flag the right word in every document | `R/dict.R` |
| C10 | Vale case | `ignorecase: true`; false | false; case variants listed | true would match the canonical spelling against a variant that differs only in case | one line |
| C11 | Vale key order | as written; longest first | longest first | an alternation takes its first match | one sort |
| C12 | `.vale.ini` | write it; leave it, say | leave it and say what it needs | a user's Vale configuration has other styles; not weft's file | one message |
| C13 | `dict_vale()` overwriting | always; its own file only | its own file (header line); removed when no spellings remain | never destroy an authored rule; no stale rule | `R/dict-tools.R` |
| C14 | `dict_vale()`'s `path` | relative to the working folder; to the root | to the root | `dict.yml` and `.vale.ini` are at the root | one call |
| C15 | starter `dict.yml` | empty; one live entry; commented examples | two commented examples: a quantity with `display` and `decision`, a string with `avoid` | it reads as zero keys, so a knit works at once; the fields hardest to guess are shown | the inst file |
| C16 | an existing `dict.yml` | add the schema line; leave it | leave it; print the line to add | an authored file is not edited | one message |
| C17 | the schema's place | a URL; `system.file()` path; copied to `_weft/` | copied to `_weft/`, replaced when it differs | works offline and per project; `_weft/` is where `use_quarto()` puts weft's files and Quarto ignores it | `R/use.R` |
| C18 | schema dialect | draft 2020-12; draft-07 | draft-07 | the editor YAML servers support it fully | the file |
| C19 | schema and reader | equal; schema looser; schema stricter | never stricter but E1, E2 | a correct file must not be marked wrong; what YAML 1.2 cannot see stays the reader's | the file |
| C20 | testing the schema | `jsonvalidate` (V8) in Suggests; a small validator in the tests | a test helper that interprets the keywords the schema uses, and fails on any other | no heavy dependency; the helper cannot silently skip a keyword | `helper-schema.R` |
| C21 | `units:` in a schema | a schema for `_weft.yml` too; none | none now; the starter points at `units:` | `units:` is a setting, not a dictionary field; no settings schema exists | a second schema |
| C22 | `dict_seed()` literals | numbers only; numbers, strings, `c()`; also logicals, dates | numbers, strings and `c()` of one kind | the dictionary's types; `TRUE` constants are switches, not stipulations | one predicate |
| C23 | differing values | omitted; listed and flagged | listed, `differs`, every assignment in `where` | two values for one name is the finding that matters | columns |
| C24 | `eval = FALSE` chunks | read; skipped | skipped when written literally | example code is not a definition | one regex |
| C25 | `.R` files | never; always; when named | when named | a project's scripts are many and not chapters (9.5.2) | the default |
| C26 | the setting's form | a mapping; one string | one string with four forms | one line in `_weft.yml`; the forms do not overlap | `decisions_route()` |
| C27 | GitHub access | base `url()`; the `gh` CLI; the `gh` package; `curl` | `curl` in Suggests | exact status codes and headers; base R reports a status only inside a message's text; no CLI to install | `github_fetch()` |
| C28 | offline, no token, private | `FALSE`; error; `NA` | `NA`, "could not check", with the reason | "unresolved" must mean the record is missing | `R/decisions.R` |
| C29 | after a refusal | keep calling; stop | stop | offline or rate-limited, every further call fails the same way | one loop |
| C30 | a pull request number | refused; resolved | resolved | GitHub numbers them with issues; a decision may be recorded in one | one line |
| C31 | a string pointer under `github` | error when read; row `FALSE` | row `FALSE` with the reason | the outline's "error" would stop a read for a check that belongs to `verify()` (4.5.2) | one branch |
| C32 | cache | in the session; on disk; none | none | one call per pointer is within GitHub's limit; a cache file is a generated file (P8), a session cache hides a deleted issue | — |
| C33 | glob semantics | glob; glob plus a boundary after `{id}` | glob only; examples write `{id}-*.md` | what is written is what matches | `R/decisions.R` |
| C34 | a function not found | `NA` rows; error | `weft_config_error` | a configuration mistake, as for a formatter | one call |
| C35 | `decisions` in front matter | per document; project only | project only, as `draft` | the resolver serves `dict.yml`, a project file | `R/config.R` |
| C36 | `check_decisions()`'s resolver argument | the configuration list; the setting's string | the string, or read from `_weft.yml` | testable without reading a configuration (which registers units) | the signature |
| C37 | an error class | plain `stop()` as `use_quarto()`; a weft class | `weft_tool_error` | testable by class like every other weft error | `R/dict-tools.R` |
| C38 | `dict_glossary()` without `library(weft)` | no; attached | attached (2.1.8) | a weft document calls it as it calls `u()` | one name |

## Contradictions with the spec

- **K7 (`dev/design-2.md`).** `dict_vale()` writes rules "from the
  canonical spellings" (4.7.2), which 4.2 has no field for. Resolved by C1.
- **K9 — P10 and 9.3.1 against 4.7.2.** "Every file the package places …
  exists because a `use_*()` function was called", yet `dict_vale()` writes
  a rule file. Read: P10 asks that nothing be written without an explicit
  call that says first what it writes; `dict_vale()` is such a call. P10 and
  9.3.1 are amended to name it.
- **K10 — 4.5.1's example.** `decisions/{id}*.md` resolves pointer 3 to the
  file of decision 31. Read as a glob (C33); the example becomes
  `decisions/{id}-*.md`.
- **K11 — 4.5.2.** "One that does not resolve fails it" does not say what
  a pointer that could not be checked does. Read as: not resolved means the
  record is missing; could not check is its own outcome (4.5.4).

## Spec amendments

- **2.1.8** add `dict_glossary()` to the functions put on the search path.
- **4.2.1** the fields list gains `term` (any type) and `avoid` (4.7.4).
- **4.5.1** the example glob becomes `decisions/{id}-*.md`.
- **4.5.3 (new)** the three routes: GitHub (issues and pull requests of the
  `origin` repository or `github:<owner>/<repo>`; a pointer that is not a
  whole number does not resolve), a glob relative to the root (a pointer
  that holds a pattern character does not resolve), a function returning
  `TRUE`, `FALSE` or `NA`.
- **4.5.4 (new)** a pointer resolves, does not resolve, or could not be
  checked (no network, no token, a private repository, a refusal, a
  function's `NA` or error). Could not check is never reported as does not
  resolve. Nothing is cached.
- **4.7.1** the glossary is `dict_glossary()`: Pandoc definition-list
  markdown for a chunk, written nowhere; headed by `term`, else the key;
  the value as stipulated after the heading for the five scalar types;
  alphabetical; `why` never shown.
- **4.7.2** `dict_vale()` writes one Vale substitution rule from the
  `avoid` fields, says so first, replaces only a file it wrote, and removes
  it when no spelling is left.
- **4.7.3 (new)** `term`. **4.7.4 (new)** `avoid`, the canonical spelling,
  `dict.yml` only, and the four conflicts that are problems.
- **9.1.2** the row "the `decision:` resolver" names the setting
  `decisions` and 9.1.8. **9.1.4** `decisions` is a project setting.
  **9.1.5** `decisions: github`. **9.1.8 (new)** the four forms of
  `decisions`.
- **9.3.1** `use_dictionary()` writes "`dict.yml` when absent (a starter
  that reads as no keys, with two examples commented out) and
  `_weft/dict.schema.json`"; and the sentence on what places files names
  `dict_vale()`. **P10** likewise.
- **9.3.3** `inst/` holds the dictionary schema and the starter dictionary.
- **9.5.2** `dict_seed()`: literal top-level assignments in R chunks,
  parsed and never run, of names in two or more files, with differing values
  listed.
- **§13** reasons: 4.5.4 (C28; the repository is checked first because
  GitHub hides a private repository's issues as 404), 4.7.1 (C3, C4),
  4.7.3–4.7.4 (C1, C9, C10), 9.5.2 (C23), and the schema's E1 and E2.
- `dev/decisions.md`: R2 moves to "Made" with C1; a new entry for 2c.

## Dependencies

| Package | Now | 2c | Why |
|---|---|---|---|
| `curl` | not listed | **Suggests** | the GitHub route only; without it every GitHub row is "could not check" naming `install.packages("curl")` |
| `jsonlite` | Suggests | tests only | the schema test reads the schema; `skip_if_not_installed("jsonlite")` |
| `knitr`, `yaml` | Imports | `asis_output()`; reading `_weft.yml` | — |

No new Imports. No JSON Schema validator package.

## Test plan

No test touches the network: every GitHub case passes `fetch`, and
`github_fetch()` itself is tested only with `has_curl()` mocked to `FALSE`
(`testthat::local_mocked_bindings(has_curl = function() FALSE)`). Temporary
projects are made with `withr::local_tempdir()` and `withr::local_dir()`.
Unit names new to the session where a unit is registered.

**Fixtures.**

`tests/testthat/_dict-tools/dict.yml`:

```yaml
# yaml-language-server: $schema=_weft/dict.schema.json
min_samples:
  value: 5
  type: number
  term: minimum sample size
  avoid: [min sample size, minimum sample-size]
  definition: "Fewest samples a site needs before its mean is reported."
core_len:
  value: 50
  type: quantity
  unit: cm
  display: m
  term: core length
  definition: "Length of each sediment core."
  decision: 12
salinity_res:
  value: 0.01
  type: quantity
  unit: PSU
  definition: "Logger resolution for salinity."
method_change:
  value: 2014
  type: year
  term: Method change
  definition: |
    First year of the
    instrument method.
  decision: "dec-method"
survey_start:
  value: 2024-06-01
  type: date
  definition: "First day of the summer survey."
study_area:
  value: "Northern catchment"
  type: string
  definition: "Name used for the study region."
  avoid: ["northern catchment", "Nth. catchment"]
zone_lab:
  value: {upper: Upper reach, lower: Lower reach, yes: Included}
  type: labels
  term: zone names
  definition: "Display names for the survey zones."
trend_word:
  value:
    - {below: 0.95, phrase: "a fall in"}
    - {below: .inf, phrase: "a rise in"}
  type: breaks
  definition: "Wording for the ratio of this year's mean to last year's."
```

`tests/testthat/_seed/` (line numbers matter):

`ch1.qmd`, lines 1–26:

````
---
title: "One"
---

```{r}
alpha <- 0.05
n_boot = 1000
site_name <- "Northern catchment"
zones <- c(upper = "Upper reach", lower = "Lower reach")
f <- function() { inner <- 3 }
x <- mean(1:3)
```

```{r, eval = FALSE}
alpha <- 0.1
```

```{r}
if (TRUE) {
  hidden <- 4
}
```

```{r}
broken <- (
```
````

`ch2.Rmd`, lines 1–7:

````
```{r setup}
alpha <- 0.05
n_boot <- 2000L
site_name = "Northern catchment"
-1 -> offset
zones <- c(upper = "Upper reach", lower = "Lower reach")
```
````

`sub/ch3.qmd`, lines 1–11:

````
```{r}
#| label: consts
alpha <- 5e-2
offset <- -1
1000 -> n_boot
inner <- 3
```

```{python}
alpha = 0.5
```
````

`_freeze/old.qmd`: a chunk with `alpha <- 9`. `R/consts.R`: line 1 `alpha
<- 0.01`, line 2 `site_name <- "Southern catchment"`.

**`helper-schema.R`.** `schema_view(text)`: the YAML as an editor sees it,
`yaml::yaml.load()` with handlers `seq` → `structure(as.list(x), json_array
= TRUE)`; `bool#yes`/`bool#no` → `TRUE`/`FALSE` only for the text `true`/
`false` (any case), else the text; `int` → `as.numeric()`; `int#oct`,
`int#hex` → the text; an empty document → an empty named list. JSON type: a
list with `json_array` is an array, any other list an object, `NULL` null,
logical boolean, numeric number (integer when finite and whole), character
string. `schema_ok(text)`: validates against `inst/dict/dict.schema.json`
read with `jsonlite::fromJSON(simplifyVector = FALSE)`, interpreting exactly
`$schema`, `title`, `description`, `type`, `properties`, `required`,
`additionalProperties`, `propertyNames`, `pattern` (PCRE), `enum`, `const`,
`minimum`, `maximum`, `minItems`, `minProperties`, `items`, `anyOf`,
`allOf`, `not`, `if`, `then`, `$ref` (`#/definitions/<name>`),
`definitions`, and boolean schemas; any other keyword in the schema is a
test failure. (This was prototyped while writing this note: about seventy
lines.)

**`test-use-dictionary.R`.**
- Empty folder: the five messages in order (header, two lines, `Wrote:
  dict.yml, _weft/dict.schema.json`); both files equal to the inst files
  byte for byte; return value; the starter's text equals the block above.
- Second run: one message, `Nothing to change: …`; files untouched (mtime
  and content); returns `character()`.
- Existing `dict.yml` without the schema line: left byte for byte; the
  "exists: left as it is" line; the schema-line message.
- Schema altered on disk: replaced, the "replaced" line.
- A subfolder of a folder holding `_weft.yml`: the root message, files at the
  root.
- `path` a file, a missing folder, `NA`: `weft_tool_error`.
- `suppressMessages()` silences everything; no `readline()` is called
  (non-interactive run: `rlang::local_interactive(FALSE)` gives the same
  files).
- The starter reads as zero keys; uncommented as above it reads as two keys
  with `dict$core_len` 0.5 m and `study_area`'s `avoid`.

**`test-dict-schema.R`** (`skip_if_not_installed("jsonlite")`).
- The schema file is valid JSON; `$schema` is draft-07; the helper finds no
  keyword outside its list.
- **Both accept** (`read_dict()` reads, `schema_ok()` TRUE): `_dict/dict.yml`,
  `_dict-tools/dict.yml`, the starter, the starter uncommented, an empty
  file, `value: "1e-3"` under `number`, a year `"2014"`, `labels` keyed
  `yes`/`no`, a `breaks` bound `.inf`, a string `decision`, `display` on a
  quantity, `avoid` as one string on a `string` entry.
- **Both refuse**, one case each: missing `value`, `type`, `definition`;
  blank `definition`; unknown `type`; unknown field; `why` in `dict.yml`;
  `unit` on a `number`; `quantity` with no `unit`; `display` on a `string`;
  keys `file`, `2x`, `if`, `..1`, `...`; year `214`, `2014.5`; date `1 June
  2024`; string given `0.10`; `labels` `{}` and `{x: 1}`; `breaks` `[]`, an
  item with both bounds, an item with no `phrase`, an item with an unknown
  field; `decision` `0` and `""`; `term` blank; `avoid` `[]`, `[""]`, and on a
  `number` with no `term`; a top level that is a list.
- **Only `read_dict()` refuses** (the schema's answer not asserted, but the
  case asserts `read_dict()` refuses): `010`, `0x1F`, a merge key, two
  documents, a duplicate key, `2024-02-30`, decreasing bounds, a bare item
  not last, `value: .inf` under `number`, a unit `m//s`-like that `units`
  refuses, a `display` that does not convert, each `avoid` conflict.
- **E1**: `definition: true` (and a `string` `value: true`): `read_dict()`
  reads it as `"true"`, `schema_ok()` FALSE. **E2**: key `café`, when
  `make.names("café") == "café"` in the test's locale: `read_dict()` reads
  it, `schema_ok()` FALSE.

**`test-dict-terms.R`.** `term`, `avoid` read from `_dict-tools/dict.yml`:
`entries$term`, `entries$avoid` (list column, `character(0)` where absent,
trimmed); the unknown-field problem lists nine fields; each problem row of
the table in "Two new dictionary fields", one dictionary each, class
`weft_dict_error`, message naming the key, the line and 4.7.3 or 4.7.4;
`term` allowed in `dict_local` (front matter of a rendered `.Rmd`), `avoid`
there a `weft_dict_error`; a `string` entry with `avoid` and no `term` reads;
a spelling equal to another entry's canonical spelling is the "part of"
problem; two problems in one file listed together.

**`test-dict-glossary.R`.**
- The example output above, exactly (U+00A0 where shown), with the fixture
  read outside a knit; `class()` includes `knit_asis`.
- `values = FALSE`; `sort = FALSE` (file order); an empty dictionary `""`;
  a local dictionary built from front matter shows no `why`.
- With `withr::local_dir()` in a project holding the fixture as `dict.yml`,
  `dict_glossary()` reads it; with none, `weft_tool_error` naming the root.
- Bad `dict` (a list), bad `values`: `weft_tool_error`.
- A `units:` name in `_weft.yml` changes nothing in the symbol form; a
  `thousands_from: 10000` configuration in force prints `1200` for a value
  of 1200 (the configuration is the formatter's).
- Rendered (`rmd_html()`, one document): a chunk with `dict_glossary()` and
  no `library(weft)` gives `<dl>` with `<dt>core length (0.5 m)</dt>` (after
  normalising U+00A0) and a `<dd>` holding "Length of each sediment core.";
  a project with no `dict.yml`: the knit stops with the `weft_tool_error`
  message.

**`test-dict-vale.R`.**
- The rule above, exactly, from the fixture in a temporary project; the
  messages "weft will write …", "Wrote: …", and the `.vale.ini` hint; return
  value.
- Again: "Nothing to change"; no write.
- `.vale.ini` with `BasedOnStyles = Vale, Weft`: no hint.
- An authored file at `path`: `weft_tool_error`, file unchanged.
- A dictionary with no `avoid` and weft's file present: removed, messages,
  return; absent: the "no rule to write" message.
- `level = "error"` in the file; `level = "loud"`, `path = "Terms.yml"`,
  `path = "styles/Terms.txt"`: `weft_tool_error`.
- Escaping: a spelling `a.b (c)` gives the key `'a\.b \(c\)'`; a `'` in a
  spelling or a canonical is doubled.
- Order: equal-length spellings sort by radix.

**`test-dict-seed.R`** (in `_seed/` with `withr::local_dir()`).
- Default: exactly the rows `alpha` (`"0.05"`, `FALSE`, 3, `"ch1.qmd,
  ch2.Rmd, sub/ch3.qmd"`, `"ch1.qmd:6: 0.05; ch2.Rmd:2: 0.05;
  sub/ch3.qmd:3: 0.05"`), `n_boot` (`NA`, `TRUE`, 3, same files,
  `"ch1.qmd:7: 1000; ch2.Rmd:3: 2000; sub/ch3.qmd:5: 1000"`), `offset`
  (`"-1"`, `FALSE`, 2, `"ch2.Rmd, sub/ch3.qmd"`, `"ch2.Rmd:5: -1;
  sub/ch3.qmd:4: -1"`), `site_name` (`"\"Northern catchment\""`, `FALSE`, 2,
  `"ch1.qmd, ch2.Rmd"`), `zones` (`c(upper = "Upper reach", lower = "Lower
  reach")`, `FALSE`, 2); column names and types; no `inner`, `hidden`, `x`,
  `f`, Python's `alpha`, `_freeze`'s 9 or `eval = FALSE`'s 0.1.
- `attr(, "skipped")`: one row, `ch1.qmd`, line 24; the skipped message.
- `paths = c("ch1.qmd", "R/consts.R")`: rows `alpha` and `site_name`, both
  `differs`, `where` in the order given.
- `min_files = 1`: every literal name, including `inner` (once, from
  `sub/ch3.qmd`).
- Nothing is evaluated: a chunk holding `stop("ran")` and `x <-
  system("false")` changes nothing and raises nothing.
- Errors: a missing file, a `.txt`, `min_files = 0` and `1.5`.
- A folder with no documents: the message and a zero-row result.

**`test-decisions.R`.**
- Setting: each of `github`, `github:example/proj`, `decisions/{id}-*.md`,
  `pkgname::fun`, `fun` is accepted by `read_config()` with no warning;
  `githb`, `github:example`, `decisions/*.md`, `1`, a list: the
  `weft_config_error`; `decisions:` in front matter with `_weft.yml`: error,
  without: accepted.
- No pointers: zero rows, typed columns, a `fetch` that fails if called is
  not called.
- GitHub with a recording fake `fetch` over `_dict-tools`-like pointers 12,
  31, 12 (two entries), `"zones-2023"`, resolver `github:example/proj`:
  all 200 → `TRUE`, detail `example/proj#12 exists`; calls exactly the
  repository URL then `issues/12`, `issues/31`; `"zones-2023"` `FALSE` with
  its detail and no call.
- Issue 404 → `FALSE`, its detail; 410 the same.
- Repository 404 without a token → number rows `NA`, the "not visible"
  detail naming `GITHUB_PAT`; one call. With `GITHUB_PAT` set (by
  `withr::local_envvar`): the token reaches `fetch`, the detail names the
  variable, the token's text is in no detail.
- `GITHUB_PAT` empty and `GITHUB_TOKEN` set: that token, detail names
  `GITHUB_TOKEN`.
- 401; 403 and 429 with and without a token; status `NA` with an error;
  500: each detail; after the first, no further calls and every later number
  row `NA`.
- `resolved` is `NA` exactly when `detail` starts `could not check: `, over
  every case above.
- `github` with a temporary git repository (`skip_if(Sys.which("git") ==
  "")`): origin `git@github.com:example/proj.git` → URLs for
  `example/proj`; no origin → `NA`, `(no git remote `origin`)`; origin on
  another host → `NA`, the "not on github.com" detail; `Sys.which` mocked to
  `""` → the "git is not installed" detail.
- `parse_github_remote()`: the seven accepted forms (with and without
  `.git`, with credentials, ssh with a port) give `c(owner = "example", repo
  = "proj")`; `https://gitlab.com/example/proj`, `https://github.com/example`
  give `NULL`.
- `github_fetch()` with `has_curl()` mocked `FALSE`: the status `NA` and the
  install message, and the GitHub row's detail quoting it.
- Glob: files `decisions/12-core.md`, `decisions/121-other.md`,
  `decisions/dec-method-a.md`, `decisions/dec-method-b.md`, a folder
  `decisions/7-dir/`; pattern `decisions/{id}-*.md`: 12 `TRUE` (detail
  `decisions/12-core.md`), 121 `TRUE`, `dec-method` `TRUE` with ` and 1 more`,
  7 `FALSE` (a folder does not count), `a*b` `FALSE` with its detail;
  pattern `decisions/{id}*.md`: 12 also matches `121-other.md` (the glob
  pitfall, asserted as the documented behaviour).
- Function: a global function returning `TRUE` for `"12"` and `FALSE`
  otherwise; one returning `NA`; one that stops; one returning `"yes"`; each
  detail; called once per distinct pointer; `base::is.character` gives
  `TRUE`; `nopkg::f` is the `weft_config_error`.
- `resolver = NULL` reads `decisions` from `_weft.yml` in the root; absent,
  `github`.

**Existing tests amended**, listed by the test-writer: any assertion on the
columns of `attr(dict, "entries")` (two columns added); any assertion on the
exact list of fields in the unknown-field problem; any test expecting an
unknown-setting warning for `decisions`.

**Not testable here:** the GitHub API itself (no network in tests; the one
network path, `github_fetch()` with `curl`, is exercised only by hand);
Vale itself (not installed; the rule's shape follows Vale's documented
`substitution` fields); an editor reading the schema line.

## For Robin

Built as recommended until answered.

- **Q1 — R2: `term` and `avoid` (C1).** A `term` field on any entry is its
  reader-facing name and canonical spelling; `avoid` lists spellings that a
  Vale rule replaces by it; a `string` entry with no `term` uses its value.
  Alternatives: `avoid` only on `string` and `labels` (your original
  recommendation; `labels` needs a per-label map, and numbers get no
  term); a `type: term`; a separate `terms.yml`. Recommended: as built.
- **Q2 — the glossary's heading and value (C3, C4).** `term`, else the key
  in code, then the value as stipulated in parentheses: "core length
  (0.5 m)", "`salinity_res` (0.01 PSU)". Alternatives: definitions only, no
  values; the value on the definition line. Recommended: as built; an entry
  meant for readers gets a `term`.
- **Q3 — `curl` in Suggests for the GitHub route (C27).** Base R's `url()`
  can send the token but reports a status only inside a message's text,
  which differs between R versions; the `gh` CLI needs installing and
  signing in. Recommended: `curl`, which nearly every R library already
  has.
- **Q4 — a pointer that could not be checked, in `verify()` (stage 5).**
  Recommended: reported and counted, not failing unless the rule is strict,
  so a laptop offline passes and CI (network and `GITHUB_TOKEN`) checks.
  Alternative: fail, which makes `verify()` need the network.

## Rulings on the test-writer's report

- **`decisions: githb`.** A syntactic R name is a function route, so
  `read_config()` accepts it and `check_decisions()` raises "Cannot find
  the decisions function". The test plan's line that made it a
  configuration error is wrong. A value that is no route at all (`1`) is
  the configuration error.
- With no pointers, a resolver that cannot be found is not looked for:
  zero rows, no error.
- The test-writer's other readings (its items 3 to 11) are accepted.

## Rulings on the implementer's report

- **Four tests had faulty fixtures and are edited:** an unquoted
  `github:` that YAML refuses before weft reads it; a recording `fetch`
  that dropped a `NULL` token, so the "no token" checks passed on
  nothing; and two tests that read a fixture by a relative path after
  changing directory. No expectation changed.
- `read_dict()`'s problem lines are no longer indented. Accepted.
- A problem in an entry's own `term` or `avoid` leaves that entry out of
  the checks across entries, so one mistake is reported once. Accepted.
- A `decisions` value that is no route is an error even with no
  pointers. Accepted.
- The other choices (comparing the schema byte for byte, `.` as no
  folder, the knit's dictionary only in a weft knit) are accepted.

## Rulings on the review of 2c (`dev/review-2c.md`)

Findings 1 to 16 are accepted as the reviewer states them, with these
particulars. Where a ruling differs from the contract above, the ruling
wins.

- **1, M.** `use_dictionary()` and `dict_vale()` never write through a
  symbolic link: a target, or the `_weft` or style folder, that is a
  link is a `weft_tool_error` before anything is written.
- **2, 11.** "Wrote:" is printed, and a path returned, only for a file
  that was written; a write that fails, and a target that is a folder,
  are a `weft_tool_error` naming the path.
- **3, B.** An `avoid` spelling that starts or ends with a character
  that is not a letter or digit is a `read_dict()` problem (4.7.4): Vale
  could never match it.
- **4, 14.** The project root is never read as part of a glob pattern,
  and the glob and function routes do not reach outside the project.
- **5, J.** The glossary ends with a blank line, so text after its chunk
  stays out of it; a definition with a blank line keeps its paragraphs,
  indented as Pandoc needs.
- **6, I.** A `term` that holds a line break, or starts with a markdown
  block marker, is a `read_dict()` problem; surrounding white space is
  trimmed.
- **7, F.** A `decision` written `012`, `"#12"` or with more digits than
  an issue number can have is never changed silently: `#12` is read as
  12; the others are rows that do not resolve, with the reason.
- **8.** The schema accepts everything `read_dict()` reads, except E1
  and E2: where they differ beyond those, the schema is loosened.
- **9.** `dict_vale()` removes weft's rule file only when the dictionary
  it was given is the project's own (`dict = NULL`); given another
  dictionary with no spellings it writes nothing and removes nothing.
- **10.** A `fetch` that throws or returns something malformed is a row
  "could not check: ...", and the rows after it are not attempted.
- **12.** A remote's repository name takes letters, digits, `.`, `_` and
  `-` only; `ssh.github.com` with a port and any letter case of
  `github.com` are read as GitHub.
- **D.** An answer of 410 (issues are off, as in a fork) is "could not
  check", never "does not resolve".
- **E.** The git remote is used only when the repository's top level is
  the project root or inside it.
- **G, H.** Outside a knit the glossary reads the project's `_weft.yml`.
  A value prints with the decimals it was written with ("0.50"); a
  value converted by `display:` prints as `fmt_num()` prints it.
- **L.** `use_dictionary()` prints the schema line to use when the
  file's own points somewhere else.
- **A.** Whether Vale honours the order of a `swap` map is not checked
  here (Vale is not installed); in `dev/open-findings.md`.
- **C, K.** Left; in `dev/open-findings.md`. K belongs to `verify()`.
