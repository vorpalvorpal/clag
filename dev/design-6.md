# Stage 6: values by name, resolved by a Lua filter

Written before any test or code. It is the build contract for
architecture (c) as `dev/languages-c-scoping.md` reshaped it: code
publishes typed values by name, prose refers to the names, and a Pandoc
Lua filter resolves and formats those constructs. Documents on Quarto's
`jupyter` and `julia` engines, plain markdown, and the places the knitr
hooks cannot reach then carry weft's values, wording and checks. The R
package stays the project's checker: scanner, lints, gate, ledger,
`verify()`. The hooks are not removed and R authors lose nothing.

Robin's words: "Start on implementing option c". The choices inside it
were delegated; each is a decision in §3 with its alternatives, its
reason and how to reverse it. A later message from Robin added `claim()`
for Python and Julia, in both back ends; it is package 6k (section D).
Every example is invented.

A test-writer works from §2 and §5 only and never reads `R/`, `inst/`
or `python/`. An implementer then works from §2, §4 and the tests. Rule
numbers such as 1.12.4 are the spec numbers proposed in §6; N numbers
are this note's contract; E numbers are exact message texts.

## What was measured

Quarto 1.11.9; Pandoc 3.10 (Quarto's own, Lua 5.4) and Pandoc 3.8.3
(Homebrew, on the `PATH`, the one rmarkdown finds); Julia 1.13.3
(Homebrew) with QuartoNotebookRunner, which the `julia` engine installed
under `~/.julia` on its first use; Python 3.13.5 with ipykernel 7.4.0
and jupyter-cache 1.0.1 in the scratchpad virtualenv `lang/c2/venv`;
R 4.4.3. Scripts and documents are in the scratchpad under `lang/c3/`
(`jl1/`, `py1/`, `j.lua`). One process at a time. The earlier runs of
the scoping (E1 to E17 of `dev/languages-c-scoping.md`) are not
repeated.

**1. The julia engine, `output: asis`.** A cell with `#| output: asis`
that `println`s a fenced block reaches Pandoc as a `CodeBlock` with the
class `weft-values` and the JSON as its text. The cell's own `div` is
gone: asis output is spliced into the document raw. First render 72 s
(QuartoNotebookRunner installed and precompiled); with the server warm,
6.6 s; with the server cold, 13.6 s.

**2. The julia engine, markdown display.** An object whose type has a
method `Base.show(io, ::MIME"text/markdown", x)` reaches Pandoc as raw
markdown inside a `div.cell-output.cell-output-display.cell-output-markdown`,
with no `output: asis`, whether it is `display()`ed mid-cell or is the
cell's last value. `display("text/markdown", s)` and
`display(MIME("text/markdown"), s)` with a `String` emitted nothing at
all. A cell with `include: false` emitted nothing.

**3. The julia engine, an error.** A cell that reads an undefined name,
without `error: true`, stops the render. Quarto prints
"ERROR: Julia server returned error after receiving "run" command:",
"Failed to run notebook: <path>", "EvaluationError: Encountered 1 error
during evaluation", "@ <path>/err.qmd:14" (the cell's first line),
"UndefVarError: `undefined_thing` not defined in `Main.Notebook`", a
Julia stack trace whose line (`err.qmd:17`) is not the line of the
error, then a Deno stack trace. With `error: true` the error is shown in
a `div.cell-output.cell-output-error` and the render goes on. `0/0` is
`NaN` in Julia, not an error.

**4. The julia engine, state between renders.** A global defined in one
render is not defined in the next: each render gets a fresh module
`Main.Notebook`.

**5. The julia engine, the environment.** A notebook worker sees the
environment of the julia *server* process, which outlives renders.
`WEFT_RUN` set to `run-one` at the first render stayed `run-one` in a
second render with another value, after `--execute-daemon-restart`, and
after `quarto call engine julia close a.qmd`. Only
`quarto call engine julia kill` refreshed it (`run-five` after the
kill). `QUARTO_DOCUMENT_FILE` inside `b.qmd` said `a.qmd`, the first
document that server ran. `QUARTO_DOCUMENT_PATH` was the folder, right
only because both were in one folder. `@__FILE__` inside a cell gave
the real path of `b.qmd`. A file read inside a cell (`.weft/run`) gave
its current content.

**6. Labels in the tree.** julia engine: a cell labelled `pub` is a
`div.cell` with id `pub`; its outputs are divs `pub-1`, `pub-2`.
Jupyter engine: the cell div's id is `cell-pub`; its markdown output
div's id is `pub`.

**7. Jupyter, a block then an error.** A cell with `error: true` that
`display`s `Markdown` holding a fenced `weft-values` block and then
raises: the block reaches Pandoc, the error sits in
`div.cell-output-error`, the render goes on. `QUARTO_DOCUMENT_FILE` was
right in a fresh kernel.

**8. Julia macros.** `_ > 10` passed to a macro arrives as an expression
(`_` is readable syntax in a macro argument, though Julia refuses to
read `_` as a value) and `string()` of it is `"_ > 10"`.

**9. `pandoc.json` (Pandoc 3.8.3 and 3.10).** `pandoc.json.decode(s,
false)` of an object with a key written twice keeps the *first* value.
Of malformed text (`{"values":`) it returns `nil` and raises nothing. A
JSON number beyond 2^53 becomes a Lua float. `null` decodes to
`pandoc.json.null`.

**10. Settings through Pandoc's metadata.** A YAML string `" "` read by
`pandoc.read()` as metadata stringifies to something other than a
space, and `"--"` to an en dash. So the filter cannot take
`big_mark` or `minus` from Pandoc's reading of YAML.

## 1. Scope

| What | Pkg | |
|---|---|---|
| The Lua number printer, conformant with R on the committed table | 6a | build |
| The carrier (block schema 1) and `weft_put()`, auto-publishing by the hooks | 6b | build |
| `claim()` from Python and Julia, knitr back end; the Python package and `Weft.jl` skeletons; gate count and `guest-call` | 6k | build, first |
| The resolver filter: collect, `.num`, `.pct`, `.val`, `if`, `n`, markers, one report, lines, draft, collection | 6c | build |
| Scanner, lints, gate, `engine` rule, pre-render script, installers for named values | 6d | build |
| Python package for Jupyter: `put`, `auto`, the engine back end of `claim`; `use_quarto()`, `use_setup()`, `status()` for Jupyter projects | 6e | build |
| The other classes in Lua: `.sci .p .date .no .word .count .ord .and .or .pairs .range .ul .ol .dl .a .cap .strong .em`, `sign`, `list`, ids and back-references, `cite`, text spans | 6f | build |
| Stamps, collection lines and ledger rows from the filter; `verify()` on engine documents | 6g | build |
| `Weft.jl` for the julia engine: `@put`, `put`, the engine back end of `@claim` | 6h | build |
| Values files and engine-free chapters | 6i | build |
| Article and spec text | 6j | build |
| Observable JS | | out (5f's lint stands) |
| Units in Lua: `.uname .usym .nounit`, `unit=` | | out: a loud failure on a named value |
| Project formatters (functions in `_weft.yml`) | | out: a loud failure |
| `knit_print`, phrase functions (`ci()`, `pm()`, `about()`, `of_n()`), `lookup()`, `brk()` in the filter | | out |
| Expressions in the filter beyond the one-comparison grammar | | out |
| A Quarto engine extension; inline carriers (`v()`) | | out |
| `fmt_*()` in Python or Julia on the jupyter or julia engines | | out (rung 5) |
| `auto()` for Julia | | out: no post-cell hook exists on that engine |
| Languages other than English for words in Lua | | out: as R, a construct error |

## 2. Contract

### Exports, conditions, dependencies

- **N1. R exports.** Two new: `weft_put()` (N40) and
  `weft_values_write()` (N46). `weft_setup()` also puts `weft_put` on the
  search path (rule 2.1.8). No new Imports or Suggests: `jsonlite`
  already serves the guest reader.
- **N2. R condition classes.** `weft_values_error` (also `weft_error`):
  a `weft_put()` or `weft_values_write()` call that cannot publish
  (E40 to E44). Guest claim failures under knitr are ordinary collected
  failures (N52); nothing new is signalled in R for them.
- **N3. Python exceptions** (module `weft`): `WeftError(Exception)`;
  `ClaimFailed(WeftError, AssertionError)`; `PublishError(WeftError,
  TypeError)`. **Julia** (module `Weft`): `Weft.ClaimFailed <:
  Exception`, `Weft.PublishError <: Exception`.
- **N4. Pandoc.** The filter needs Pandoc 3.1 or later (`pandoc.json`).
  Under an older Pandoc it writes E30 to stderr and exits 1 (not in draft
  mode). Tests run on Quarto's Pandoc and on the `PATH` Pandoc when that
  is another version of 3.1 or later.

### A. Syntax (rules 1.12; packages 6c, 6d)

- **N5. A named value** is a code span whose text is a NAME (N6),
  directly followed by an attribute block (1.1.7) that carries at least
  one of: a formatter class (1.2.5), a wording, collapse or text class,
  `.val` (N8), or a renderer key (`digits`, `sigfig`, `sep`, `last`,
  `trunc`, `none`). `` `depth`{.num} ``, `` `site`{.val} ``,
  `` `sites`{.and} ``, `` `n`{digits="2"} `` are named values.
  `` `depth`{.python} `` and `` `depth`{#d} `` are not (no weft class or
  key): they stay code. Pandoc's trimming of one space inside the
  backticks applies: `` ` depth `{.num} `` is the name `depth`.
- **N6. NAME.** ASCII only: a letter or `_`, then letters, digits, `_`
  or `.`, not ending in `.`, at most 64 characters, matching
  `^[A-Za-z_][A-Za-z0-9_.]{0,63}$` and not `[.]$`. A dot is an ordinary
  character (R's `n.sites`), never a path: there is no `site.depth`
  access into a value. These words are not names, in any language:
  `TRUE FALSE True False true false NA NULL None nothing missing Inf
  NaN`.
- **N7. A code span with a weft class whose text is not a NAME** and does
  not start `r `, `R ` or `{r}` is a construct error (E1), found from the
  source (6d) and by the filter (6c): `` `x + 1`{.num} ``,
  `` `cfg.depth[1]`{.num} ``, `` `{python} x`{.num} ``.
- **N8. `.val`** prints a value as itself, with no formatting: an int its
  digits, a float its shortest round-trip text as the record holds it
  (`0.30000000000000004`), a decimal as written, a string as is, a date
  in ISO form, a bool `true` or `false`, a list its elements so printed
  and joined by ", " (1.4.10). The minus is the record's `-`, not
  U+2212. `.val` is in the number stage's at-most-one group (1.4.2), and
  a wording class with it is a construct error (E2). Text and collapse
  classes may go with it (`` `sites`{.val .and} ``). It is the named
  value's form of a bare value, but it is a construct: a missing value is
  "no value", a check counts, the ledger records it.
- **N9. A condition** (the value of `if`, in a construct the filter
  resolves, N14) is, after trimming spaces:
  - a NAME, whose value must be a bool (1.11.8); or
  - `OPERAND OP OPERAND`, with spaces optional around `OP`, where `OP` is
    one of `<`, `<=`, `>`, `>=`, `==`, `!=` and each `OPERAND` is a NAME,
    a number literal or a string literal; at least one operand is a NAME.
  - A number literal matches `^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$`
    (no `+`, no leading `.`, no `_`, no hex, no `L`).
  - A string literal is single-quoted text holding no `'` and no `\`:
    `'north'`. (A `"` cannot occur inside an attribute value, 1.2.3.)
- **N10. Several conditions** are joined by commas, as 1.5.4: the value is
  split at every comma that is not inside a string literal, and every
  part must be a condition. `if="n_gap > 10, n_sites >= 3"`. An empty part
  (`if="a,,b"`, `if="a,"`) is a construct error (E3).
- **N11. Refused**, each a construct error with E3, which quotes the
  part: anything else, including `&&`, `||`, `&`, `|`, `and`, `or`,
  `not`, `!x`, brackets, arithmetic (`a + 1 > b`), calls (`len(x) > 2`),
  indexing, a chained comparison (`0 < x < 1`), `=`, `<>`, a literal
  compared with a literal (`3 > 2`, E4), and a reserved word of N6 used as
  an operand.
- **N12. Governor values** in a construct the filter resolves: `n` is a
  NAME, `.` (1.7.2) or `#id` (1.7.6); `sign` is a NAME or `#id`; `list` is
  a NAME. A number literal or any other text there is a construct error
  (E5). A back-reference `#id` names an id defined by a construct the
  filter resolves (N13).
- **N13. Ids.** `` `depth`{#d .num} `` defines `d` for the filter's
  constructs, under 1.7.5 to 1.7.12 (6f). In a knitr document a span the
  hooks resolve cannot refer to an id on a named value, and a span the
  filter resolves cannot refer to an id on an R value: either is a
  construct error from the source (E6).
- **N14. Who resolves what.**
  - In a document the knitr hooks resolve (an `.Rmd`; a `.qmd` with
    `engine: knitr`, or with an executed `{r}` chunk and no `engine:` or
    `jupyter:` key; weft active), the hooks resolve every R value and
    every span they reach, as today, and leave named values alone. The
    filter resolves named values, and any span that reaches Pandoc still
    carrying a governor key (text a chunk printed, a caption the hooks
    refuse), if its governor fits N9 and N12.
  - In every other document (jupyter, julia, `markdown` engine, plain
    Pandoc) the filter resolves every construct: named values and spans.
  - Arms are unchanged (1.5.12 to 1.5.15, 1.5.20): an arm of a span the
    hooks resolve may hold a named value, which then reaches the filter
    only if its arm was chosen. A named value in an arm not chosen is
    never read (1.5.16).
- **N15. When to write a name.** In a knitr document, write R
  expressions as today. Write a name where the hooks cannot reach (text a
  chunk prints with `results: asis`, a caption on a cached, `eval: false`
  or non-R chunk, a front-matter field that needs a chunk's value), or
  for a value from Python or Julia that must print exactly. On the
  jupyter and julia engines and in plain markdown, write names: there is
  no R to evaluate an expression.
- **N16. `.weft-literal`.** In a document the filter resolves, the filter
  removes the `why` attribute from every span and div of class
  `.weft-literal` (1.8.11), and keeps the class (6c).
- **N17. The other syntax rules** apply to named values unchanged: the
  attribute block touches the backtick (1.1.7); quoting (1.2.2, 1.2.3);
  keys in any letter case (1.2.10); at most one class per group (1.4.2);
  `digits` with `sigfig` (1.4.7); `digits` and `sigfig` whole numbers from
  0 to 100 (E7, E8, R's texts); pass-through of other classes and keys to
  a span around the output (1.2.6); `none` only with a collapse class
  (1.4.14); a governor key on a named value is a construct error (1.3.3,
  E9).

### B. The carrier (rules 2.13.1 to 2.13.12; 6b writes, 6c reads)

- **N20. The block.** A fenced code block whose classes include
  `weft-values`, written with four backticks so that a backtick fence in
  a string cannot close it:

  ````
  ````{.weft-values}
  {"weft":1,"lang":"python","run":"20261113T101500-123-000042","at":1794822900,"values":{"depth":{"t":"float","v":"3.14159"}}}
  ````
  ````

  Its text is one JSON object (schema 1, N21). Other classes and
  attributes on the block are ignored, except `file` (N30).
- **N21. Schema 1.** The object's members:

  | Member | Required | Value |
  |---|---|---|
  | `weft` | yes | the integer `1` |
  | `values` | yes | an object; each key a NAME (N6), each value a record (N22); may be empty |
  | `lang` | no | `"r"`, `"python"`, `"julia"` or `"none"` (hand-written); who wrote it |
  | `run` | no | the run id (N48), a string, or `null` |
  | `at` | no | when the block was written, whole seconds since 1970-01-01 UTC, or `null` |
  | `cell` | no | the label of the chunk or cell that wrote it, when the writer knows it, or `null` |
  | `checks` | no | an array of check objects (N23): claims made in code where they ran |

  Unknown members are ignored. The shims never write a key twice (a
  duplicate key decodes to its first value, measured 9, and is not
  detected).
- **N22. The record** is stage 5's, unchanged (rule 1.11; `R/guest.R`
  header; `inst/python/weft_guest.py`): an object with `t` and, by kind:

  | `t` | `v` | other members |
  |---|---|---|
  | `bool` | `true` or `false` | |
  | `int` | a string matching `^-?(0\|[1-9][0-9]*)$`, any length | |
  | `float` | a string, the shortest text that reads back as the same double, matching `^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$` (`3.14159`, `1e+23`, `1.0e23`) | |
  | `decimal` | a string, the decimal as written, matching `^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$` | |
  | `string` | a string | |
  | `date` | a string `YYYY-MM-DD`, a valid calendar date | |
  | `list` | an array of scalar records (no `list` inside) | `of`: the element kind after promotions, or `"missing"`; `keys`: `null` or an array of strings as long as `v` |
  | `missing` | absent or `null` | `why`: a string |
  | `error` | absent or `null` | `why`: a string; `{S}` in it stands for the subject |

  Optional on any record: `type` (the host's type name, for messages)
  and `checks` (an array of check objects, N23, with use-site meaning,
  N25a). A record that breaks this table is read as an error record whose
  `why` is E31.
- **N23. A check object:** `text` (the check as written, a string),
  `ok` (`true`, `false`, or `null` when it could not be evaluated),
  `level` (`"fail"` or `"warn"`; absent means `"fail"`), `why` (string or
  `null`: the reason when `ok` is not `true`), and, in the block's own
  `checks` only, `expr` (the call as the shim shows it, N58), `value` (a
  record of the value checked), `line` (an integer line in the source,
  or `null`).
- **N24. Where a block may appear.** Anywhere in the document body that
  Pandoc reads a code block: at the top level, in a cell's output div, in
  any div, a block quote or a list item. A block in metadata is not read.
  A fenced block with another class that holds the same JSON is code.
- **N25. Order.** The filter walks the body in document order. A block
  adds its names when the walk reaches it. A construct in the body sees
  the names published above it. A name used above every block that
  publishes it is "no value" (E10).
  - **N25a. Checks on a record** count where the name is used, each time a
    construct prints the value or reads it in a condition (rule 1.5.16 as
    restated in §6): a record whose `checks` hold one with `ok` not `true`
    and level `fail` makes that construct a failed claim (E14); level
    `warn` a warned check. A name never used reports nothing.
  - **N25b. The block's own `checks`** are claims made where they ran.
    Every one with `ok` not `true` is reported once, whether or not any
    construct uses a name (E15).
- **N26. Republishing.** A later block that publishes a name replaces it
  for the constructs below. Front matter and captions see each name's last
  published value (N81).
- **N27. Scope.** One Pandoc run: the document, its `{{< include >}}`
  files and knitr children (text in the same output). Names do not cross
  documents. Chapters of a book share values only by each reading the same
  values file (N30).
- **N28. A malformed block** (text that does not decode, a top level that
  is not an object, `weft` missing or not `1`, `values` missing or not an
  object, a key of `values` that is not a NAME) is one construct error
  (E12, E13) located at the block (N89), and the block adds no names. A
  later use of its names is then "no value" too: the report is loud,
  never silent.
- **N29. Size.** A block's text above 5,000,000 bytes is refused as
  malformed (E13). The shims refuse a list of more than 10,000 elements
  (E42, E52) so a data column is not published by accident.
- **N30. A values file.** A block with a `file` attribute and an empty body
  reads a JSON file in schema 1 at that point in the order:
  ```` ````{.weft-values file="_weft/values/survey.json"}```` ```` then
  ```` ```` ````. The path is relative to the document's folder, or to the
  project root (the folder holding `_weft.yml`, else `_quarto.yml`) when
  it starts with `/`. A file that cannot be read is E32 (6i).
- **N31. Removal.** The filter removes every `weft-values` block from the
  output, then removes any div of class `cell-output` (any variant) or
  `cell` left with no content. A document that only published values
  shows no trace of it.

### C. Publishing from R (rules 3.8; package 6b)

- **N40. `weft_put(...)`.** Each argument publishes one name:
  - `weft_put(depth = mean(d$depth))`: the name `depth`;
  - `weft_put(depth, n_sites)`: an unnamed argument that is a symbol
    publishes under the symbol's name;
  - any other unnamed argument is E40; a name that is not a NAME (N6) is
    E41; a name given twice in one call is E43.
  It returns `invisible(NULL)`. Each value becomes a record by N47.
- **N41. `claim()` in `weft_put()`.** An argument whose expression is a
  call of `claim()` (or `weft::claim()`) is captured before evaluation:
  its first argument is the value, its checks are evaluated as `claim()`
  evaluates them, the value's record carries a check object for each
  (`text` the check as written in the source, `ok`, `level`, `why`), and
  nothing is stopped. Such a check counts where the name is used (N25a,
  rule 2.4.1: a construct). `claim()` anywhere else in chunk code keeps
  2.4.2.
- **N42. Where the block goes, in a knit with the hooks.**
  - In a chunk whose `results` option is `"asis"`, `weft_put()` writes the
    block to the chunk's output at once, so text the chunk prints after it
    sees the names.
  - Otherwise the names wait in the knit's state and the hooks write them
    as one block (with `cell` the chunk's label) at the start of the next
    prose block the `text` hook receives, or, when no prose block follows,
    at the end of the document. A chunk with `include: false` therefore
    publishes under knitr.
- **N43. Auto-publishing by the hooks.** At the start of each prose block,
  and at the end of the document, the hooks publish every name that the
  document's source names (N45), that is bound in the knit's environment
  (`knitr::knit_global()`, found without inheritance), and whose record
  differs from the last one published in this knit (or was never
  published). These go into the same block as N42's waiting names; a name
  `weft_put()` published wins over the auto value in that block. An R
  author never needs `weft_put()` for a name the source names, except for
  text an `asis` chunk prints with names set in that chunk (N42).
  A value that N47 refuses is published as an error record, so the
  failure shows where the name is used, not where it was set.
- **N44. Outside a knit** `weft_put()` returns the block's text (a
  character string of class `weft_values`) and prints it when printed;
  nothing is stored.
- **N45. The names a source names** (shared by R's N43 and Python's
  `auto()`, N71, so both agree). Over the whole file text, front matter
  and chunks included:
  1. every `` `NAME`{ `` (a backtick, a NAME, a backtick, `{` at once);
  2. every value of an `n`, `if`, `sign` or `list` key written
     `KEY="..."` (key in any letter case, `=` with no spaces, double
     quotes): from it, string literals in single quotes are removed, then
     every NAME token (N6's pattern, maximal) is taken.
  A reserved word of N6 is never a name. Names in a file `{{< include >}}`
  names (relative to the source, recursively, at most 8 deep) are taken
  too. A name too many costs a few bytes; a name missed is "no value"
  where it is used.
- **N46. `weft_values_write(path, ...)`** writes a values file (N30): the
  arguments as `weft_put()`'s (N40, N41), `lang` `"r"`, `run` from N48,
  `at` now, written atomically, UTF-8, `\n`. It returns `path`
  invisibly. It works outside a knit and in a `targets` pipeline
  (`tar_target(values, weft_values_write("_weft/values/survey.json", n =
  nrow(d)), format = "file")`).
- **N47. An R value as a record:**

  | R value | Record |
  |---|---|
  | `TRUE`, `FALSE` | bool |
  | an `integer` of length 1, not `NA` | int, its digits |
  | a `double` of length 1, finite | float, the first of `sprintf("%.15g")`, `"%.16g"`, `"%.17g"` that reads back as the same double |
  | a `character` or `factor` of length 1 | string (the level for a factor) |
  | a `Date` of length 1 | date |
  | `NA` of any type, `NaN`, `Inf`, `-Inf` | missing, `why` `"NA"`, `"NaN"`, `"Inf"`, `"-Inf"` |
  | `NULL` | missing, `why` `"NULL"` |
  | an atomic vector of length 0 or of length 2 or more, of the kinds above | list; `of` its kind (`"missing"` when every element is); names give `keys` |
  | `integer64` (bit64) | int, its digits |
  | a `units` object | error, E44 |
  | anything else (a data frame, a list, a `POSIXct`, a function) | error, E45 |

  A length-1 named vector is a scalar; its name is dropped.
- **N48. Run id and time.** Every writer (R, Python, Julia) takes `run`
  as: the first line of `.weft/run` found by walking up from the
  document's folder (at most 8 levels), when that file exists; else the
  environment variable `WEFT_RUN` when set and not empty; else `null`.
  It is read at each publish, never cached (measured 5: a kept process
  holds a stale environment). `at` is the time of the publish.

### D. `claim()` from Python and Julia (rules 3.9; package 6k, with its engine halves in 6e and 6h)

One spelling per language, the same in both back ends. The meaning is
R's for `claim()` in chunk code (2.4.2, 2.4.4): **a claim in code is
checked where it runs.** A failed check is recorded, then stops the
chunk. A check that should count only where a sentence uses the value is
written in the sentence, as a guard (`[...]{if="n > 10"}`), or published
from R with `weft_put(n = claim(n, . > 10))` (N41), or carried in a
values file.

- **N50. Python: `claim(x, *checks, level="fail")`**, from
  `from weft import claim`.
  - Each check is a `str`. One that starts, after leading spaces, with
    `<`, `<=`, `>`, `>=`, `==` or `!=` is read as `_ ` followed by it:
    `claim(n, "> 10")` checks `_ > 10`. Any other string is a Python
    expression in which `_` is the value: `claim(n, "_ % 2 == 0")`.
  - It is evaluated with `eval()` with the caller's globals, and locals
    that are the caller's locals with `_` bound to `x` (so
    `claim(n, "_ > threshold")` sees `threshold`).
  - Its result must be a `bool` or `numpy.bool_`. Anything else
    (`0`, `[]`, `None`, a numpy array) is a failed check with `why`
    E53 (rule 1.11.8: no truthiness). An exception raised while
    evaluating is a failed check with `why` `"{Type}: {message}"`.
  - No check: `TypeError` E50. A check that is not a `str` (a lambda):
    `TypeError` E51. `level` other than `"fail"` or `"warn"`:
    `ValueError` E54.
  - It returns `x` unchanged when every check passes, or when the failed
    ones are all at level `warn`.
- **N51. A failed check** (level `fail`): the failure is recorded by the
  back end (N52, N53), then `claim()` raises `weft.ClaimFailed` with
  message E55. At level `warn` it is recorded as a warned check (2.6.10)
  and nothing is raised.
- **N52. knitr back end** (Python run by reticulate in a weft knit). The
  failure joins R's failure list, as a failed check in R chunk code does
  (2.4.4): kind `failed claim`, located by the chunk's label (2.6.2),
  `expr` E56, `detail` E57. With `error: true` on the chunk, the chunk
  goes on and the render fails at the end with it in the report; without,
  the knit stops with the `ClaimFailed` error, as any Python error stops
  it. A warned check joins `last_knit()$warnings`.
- **N53. Jupyter back end** (the cell runs in an IPython kernel). Before
  raising, `claim()` displays a block (N20) with `values` `{}`, `lang`
  `"python"`, `run` and `at` (N48), and `checks` holding one check object
  (N23) with `expr` E56 and `value` the record of `x`. With `error: true`
  the render goes on and the filter reports the check (N25b, E15),
  located by the cell (N89); without, the render stops with Quarto's
  traceback whose last line is E55. A warned check is displayed the same
  way and the filter lists it under warned checks.
- **N54. No back end** (plain Python, no IPython shell): a failed check
  raises at once; a warned one calls `warnings.warn(E55, UserWarning)`.
- **N55. Julia: `@claim`**, from `using Weft`.
  - `@claim x > 10`: one comparison (`<`, `<=`, `>`, `>=`, `==`, `!=`)
    whose left operand is the value; it returns the left operand's value.
  - `@claim expr check...`: each further argument is an expression in
    which `_` stands for the value of `expr`:
    `@claim mean(d) (_ > 0.5) (_ < 9)`. The macro replaces `_` by a
    hidden variable bound to the value, so `_` may be read here.
  - `@claim x check... level=:warn` sets the level.
  - The check's text is `string()` of its expression as Julia prints it
    (`"x > 10"`, `"_ > 0.5"`), not the source's spacing. Its result must
    be a `Bool` (a `missing` or a `BitVector` is a failed check with E53);
    an exception while evaluating is a failed check with
    `why` `"{Type}: {message}"`. `@claim x` with nothing to check is a
    macro expansion error E50.
- **N56. Julia, knitr back end** (Julia run by JuliaCall in a weft knit,
  `Weft` loaded by R, N60). A failure is pushed onto a vector in `Weft`;
  weft drains it after the chunk, as it drains `@warn` records (J3), and
  each becomes a failure as N52 says. Then `@claim` throws
  `Weft.ClaimFailed(E55)`, which stops the knit (a Julia error stops it
  even under `error: true`, J18); the drained failure and the error are
  both in the knit's report. No RCall call is made.
- **N57. Julia, julia-engine back end.** As N53: the block is displayed as
  a value of type `Weft.Values`, which has a `text/markdown` `show`
  method (measured 2), then `ClaimFailed` is thrown. `line` in the check
  object is `__source__.line` of the macro call when `__source__.file`
  ends `.qmd`, `.md` or `.ipynb`, else `null`.
- **N58. Texts.** For a Python claim `expr` is `claim(…, "> 10")`: the
  word `claim`, `(`, the character U+2026, `, `, each check as `repr()`
  shows it joined by `, `, and `)`; for Julia, `@claim` and the macro's
  arguments as Julia prints them, joined by spaces (`@claim n > 10`).
  `detail` is `{check} was false (value {val})`, where `{check}` is the
  check's text and `{val}` is the value as `.val` prints it (N8); with a
  `why`, `; {why}` is added. A check that gave no bool:
  `{check} gave a {type}, not True or False`.
- **N59. The gate and the lints for guest claims.**
  - **Counting (6.3.1).** In the code of an executed chunk whose engine is
    `python`, each match of `(?<![A-Za-z0-9_.])(weft\.)?claim\(` on a line
    whose first non-blank character is not `#`, and that is not
    `def claim(`, counts as one `claim()` call. In a `julia` chunk, each
    match of `(?<![A-Za-z0-9_])(Weft\.)?@claim\b` on a line whose first
    non-blank character is not `#`. A match inside a string literal counts
    (accepted: no parser). A false count that is in `HEAD` too costs
    nothing; only a change counts.
  - **`guest-call` (rule 5.11.2).** The message for `r.claim(` becomes
    E58. `from weft import claim` and `claim(n, "> 10")` are not findings.
  - The names of the in-knitr module (G19) gain `claim`, `put`, `auto`,
    `ClaimFailed`, `WeftError`, `PublishError`; `from weft import claim`
    no longer raises `ImportError`.
- **N60. Where the code lives.**
  - **Python:** one package, `inst/python/weft/` (`__init__.py`,
    `_record.py` holding the classifier, `_backend.py`), with
    `inst/python/pyproject.toml` (distribution name `weft-prose`, import
    name `weft`, no dependencies). It installs with
    `pip install "git+https://github.com/vorpalvorpal/weft#subdirectory=inst/python"`.
    Under knitr, R loads this same package from the R package's own copy
    and registers it in `sys.modules["weft"]`, sets its knitr back end,
    and attaches the function forms of G19 to it. `weft_guest.py` imports
    its classifier from `weft/_record.py`, so there is one classifier.
    G23 changes: a `weft` module already loaded that has the attribute
    `__weft_package__` (this package, installed by pip) is used, not
    refused: R attaches its back end and forms to it.
  - **Julia:** one package, `inst/julia/Weft/` (`Project.toml` with a
    fixed UUID, `src/Weft.jl`, `src/record.jl` holding the classifier).
    `WeftGuest.jl` includes `Weft/src/record.jl`, so there is one
    classifier. Under knitr, R adds `system.file("julia", package =
    "weft")` to Julia's `LOAD_PATH` (once, at the end) so `using Weft`
    loads this copy, then calls `Weft.use_knitr()`. For the julia engine
    it installs with `Pkg.add(url = "https://github.com/vorpalvorpal/weft",
    subdir = "inst/julia/Weft")`.
  - The author's code is the same in both back ends: `from weft import
    claim` / `using Weft`.

### E. The Python package for Jupyter (rules 3.8, 3.9; package 6e)

- **N70. `put(*maps, **named)`.** Publishes names: each keyword, and each
  key of a `Mapping` given positionally (all keys `str` and NAMEs, else
  `PublishError` E41p). Values become records by the classifier of
  stage 5 (G5, G6), with no refusal for size: an `int` of any size is an
  int record. A value the classifier refuses is published as its error
  record (N43's reason). By back end:
  - Jupyter: one block is displayed with `IPython.display.Markdown`;
  - knitr: the records go to R's waiting names (N42); when the running
    chunk has `results: asis`, the block is printed to `sys.stdout`
    instead, at once;
  - none: the block's text is printed to `sys.stdout`.
  It returns `None`.
- **N71. `auto(path=None)`** (Jupyter only; under knitr it makes the hooks
  also look in Python's `__main__` for a name R does not bind, N43; with
  no back end it raises `WeftError` E59). It registers one IPython
  `post_run_cell` callback (a second call replaces it, never adds) and
  empties its memory of what it published. After every cell, it publishes
  in one block each top-level name of `__main__` that the source names
  (N45), does not start with `_`, is not a module, function or class,
  and whose record differs from the one it last published. `path` is the
  source; by default `QUARTO_DOCUMENT_PATH` joined to
  `QUARTO_DOCUMENT_FILE`. When that file cannot be read, `auto()` raises
  `WeftError` E60 at once. It returns the path used.
- **N72. Its traps, each loud.** A cell with `include: false` or
  `output: false` displays nothing, so names published only there are
  "no value" where used, and E10's hint names this. A daemon kernel kept
  from an earlier render keeps its environment: `run` is read from
  `.weft/run` (N48) and `verify()` restarts kernels (N122). A kernel kept
  from an earlier render of *another* document could read the wrong
  source: `auto()` is called at the top of each render, which re-reads
  the path from the environment.
- **N73. The back end** is chosen when `weft` is imported: knitr when R
  registered it (attribute `__weft_r__` true); Jupyter when
  `IPython.get_ipython()` returns a shell with a kernel; else none.
- **N74. Installers for Jupyter and Julia projects** (6e for Jupyter,
  6h for Julia; their R files are shared with 6d, so they follow it):
  - `use_quarto()` installs the extension of N80 whatever the engine,
    the two project scripts as today, and prints, for a project with a
    jupyter-engine document, E61; with a julia-engine document, E62.
    It installs no Python or Julia package.
  - `use_setup()` no longer adds `engine: knitr` to a `.qmd` whose
    constructs are all named values and spans that fit N9 and N12 (G41
    narrowed); it still does for one holding an R value
    (`` `r x`{...} ``) or a span outside the grammar.
  - `status()` gains one row: for a project with a jupyter-engine
    document, whether `import weft` succeeds in the Python Quarto would
    use (`QUARTO_PYTHON`, else `python3` on the `PATH`), run as
    `<python> -I -c "import weft"`; `ok`, `missing`, or `not checked`
    when no Python is found. Julia: `not checked` (starting Julia costs
    seconds).

### F. The filter (rules 2.13; packages 6c, 6f)

- **N80. Files.** The extension stays named `weft-check` so existing
  `_quarto.yml` files keep working. `_extensions/weft-check/` holds
  `_extension.yml` listing two filters in this order, `weft.lua` then
  `weft-check.lua`, and the folder `weftlib/` (`num.lua`, `words.lua`
  (6f), `cond.lua`, `config.lua`, `lines.lua`, `report.lua`,
  `stamp.lua` (6g), `ledger.lua` (6g)). In the package these live in
  `inst/quarto/`. `weft.lua` loads its modules with `dofile()` from its
  own folder (`PANDOC_SCRIPT_FILE`'s directory), so the same files run
  under Quarto, under rmarkdown (`pandoc_args`) and under plain Pandoc.
  Every `weftlib/*.lua` returns a table and has no side effect on load,
  so it can be run alone under `pandoc lua`.
- **N81. Passes, in order.**
  1. Read the configuration (N84) and the source (N89).
  2. Body, in document order (topdown): a `weft-values` block adds names
     and its own checks (N25b); a construct is resolved with the names so
     far. Figure captions, table captions and image captions are skipped
     in this pass.
  3. Captions (pass 2's skipped ones), then the front-matter fields
     `title`, `subtitle`, `abstract`, `description`, each with every name
     as last published (N26).
  4. Remove blocks and empty cell divs (N31); in LaTeX output add the
     minus declaration (N90).
  5. Report (N86), write the stamp, collection lines and ledger (6g), and
     exit as N86 says.
- **N82. Classes in 6c.** `.num`, `.pct`, `.val`; the keys `digits`,
  `sigfig`; text classes are 6f. Governors: `if` (N9 to N11, 1.5.3 to
  1.5.5, guards, empty arms, 1.5.20 spacing), `n` with 1 to 4 arms
  (English, 1.6), `n="."` (1.7.2) inside an `n` span, `#` (1.5.8), arm
  escapes (1.5.12). The default governor class (1.5.18) when it is `.num`
  or `.pct`. Pass-through (1.2.6). Printed as zero (2.6.11) under `.num`
  and `.pct`.
- **N83. Not implemented is loud.** A construct the filter resolves that
  carries a weft class, key or form this filter does not implement is a
  value error with E20 in place of the construct. Never a pass-through,
  never the record's text. After 6f this leaves: `.uname`, `.usym`,
  `.nounit`, `unit=`, project formatter classes (E21), and a `lang`
  whose words weft does not ship (E22, as 1.6.5 and 1.6.8).
- **N84. Configuration.** The filter reads `_weft.yml` (found upward from
  the source's folder, at most 8 levels) and the `weft:` mapping in the
  source file's own front matter, as text, with a flat reader, never
  through Pandoc's metadata (measured 10). The reader takes lines
  `KEY: VALUE` at the top level of `_weft.yml`, and at one indent level
  under `weft:` in front matter; `VALUE` is a double-quoted string (JSON
  escapes), a single-quoted string (`''` for `'`), `true`, `false`, an
  integer, or a bare word, with a trailing `# comment` removed. Nested
  keys of other settings are skipped. Keys read: `digits`,
  `decimal_mark`, `big_mark`, `thousands_from`, `minus`,
  `governor_class`, `pct_proportion`, `serial_comma`, `count_threshold`,
  `word_limit`, `date_format`, `draft`, `ledger`. The document's value
  wins (9.1.1). A value of the wrong kind for its key (`digits: two`) is
  one configuration failure E33, reported once, and the default is used.
  `lang` comes from Pandoc's metadata (`lang`, stringified). A
  `formatters:` key whose mapping is not empty makes the filter note the
  names under it, so E21 can name them.
- **N85. Number printing.** By record kind:
  - `float`: the literal Lua port of R's `round_half_away()`,
    `fixed_text()`, `print_one()` and `zero_noise()` as they are in
    `R/format.R` on `main` (after 5a and the amendment: digits after the
    fifteenth print as zeros; whole numbers up to 2^53 exact). It must
    give R's text on every row of the conformance table (N131 in §5).
  - `int` and `decimal`: an exact algorithm on the digit string: no
    double is used to decide a digit. Whole when every fraction digit is
    0 (an int always is). `digits = k` rounds half away from zero at `k`
    places on the decimal value as written; `sigfig = s` at `s`
    significant digits. An int of any size prints every digit: the
    refusal beyond 2^53 of stage 5 (M1, JM1) does not apply to named
    values. `.pct` multiplies by 100 by moving the decimal point.
  - On every row of the table where the value is an int or decimal of at
    most 15 significant digits, the exact path gives R's text too.
  - The "one", "zero" and "two" of `n` (1.5.9), the printed record's
    number, decimals flag and relation (1.4.11) come from the printed
    text, as in R.
- **N86. Failures and the report.**
  - Each failure has a kind (`failed claim`, `no value`, `value error`,
    `construct error`), the file, the line (N89, or none), the chunk
    label when it came from a block's own checks, the construct as shown
    (N87), and a detail (E10 to E22).
  - The marker (2.6.8) replaces the construct, or follows the printed text
    for a failed claim, as `<<weft: KIND, line N>>`; with no line but a
    chunk, `<<weft: KIND, chunk LABEL>>`; with neither,
    `<<weft: KIND>>`. The filter wraps each marker it makes in a span of
    class `weft-marker`, which `weft-check.lua` unwraps (N94).
  - At the end, when there are failures or warned checks, one report on
    stderr in the layout of `inst/quarto/weft-post-render.R` (2.6.2):
    failed claims first under `weft: N claim(s) failed` with the two
    closing lines "Read each sentence. If FALSE is right, rewrite the
    sentence." and "Do not loosen a claim to clear this."; then the other
    failures under `weft: N failure(s)`, each entry tagged `[KIND]`; then
    warned checks under `weft: N warned check(s)`. An entry is
    `  FILE:LINE  CONSTRUCT` (or `  FILE chunk LABEL  ...`, or `  FILE
    ...`), then each detail line indented six spaces.
  - Then: with a collection file open (2.6.6, found as `weft-check.lua`
    finds it), append one line per failure and warned check (N111) and
    do not exit; else in draft mode (`WEFT_DRAFT`, or `draft: true`,
    9.4.1) do not exit; else, when any failure was found,
    `os.exit(1)`. Warned checks alone never fail.
  - Construct errors are collected like the rest, not fatal at once:
    the filter is the end of the document, so one report holds them all.
- **N87. A construct as shown.** A named value:
  `` `NAME`{ATTRS} `` with ATTRS the id as `#id`, then each class as
  `.class`, then each key as `key="value"`, in the tree's order, joined by
  spaces. A span: `[TEXT]{KEY="VALUE"}`, where TEXT is Pandoc's
  stringify of the content with runs of white space made one space,
  cut to 60 characters with `...` added when cut, and only the governor
  key shown.
- **N88. Draft mode** changes only the exit (N86): markers, report,
  collection lines and stamp are the same.
- **N89. Lines.**
  - The filter reads the source: `quarto.doc.input_file` under Quarto,
    else the first of `PANDOC_STATE.input_files` that is not `-`.
  - It builds a searchable text: the source with each `{{< include F >}}`
    line replaced by F's searchable text (relative to the including
    file, recursively, at most 8 deep), keeping a map from each position
    to its file and line; then fenced code blocks are blanked except
    their lines that start `#|`, and HTML comments are blanked, positions
    kept.
  - Before anything is resolved, the filter visits every construct in
    tree order, chosen arm or not, and finds for each the next occurrence
    of its needle after the previous occurrence of the same needle: for a
    named value `` `NAME`{ ``, for a span `KEY="VALUE"` as the tree holds
    them. The found position gives the file and line.
  - A construct whose needle is not found has no line: its marker names
    none and its report entry shows the file only. This is the case for
    text a chunk printed, and for a knitr child's text.
  - A block, or a block's own check, is located by the cell it sits in:
    the nearest enclosing `div.cell`, whose id is the label with a leading
    `cell-` removed (measured 6); with a check's `line`, that line.
- **N90. Output formats.** The filter's text is the same for every
  format: the minus is the `minus` setting (U+2212 by default), the
  thousands mark the `big_mark` setting, as plain `Str` text. When
  `FORMAT` is `latex` or `beamer` and the output holds U+2212, the filter
  adds to `header-includes` the declaration R adds for pdflatex
  (`\usepackage{iftex}\ifPDFTeX\DeclareUnicodeCharacter{2212}{\ensuremath{-}}\fi`),
  once. HTML, docx, Typst and gfm need nothing. `.ul`, `.ol` and `.dl`
  (6f) make Pandoc list blocks, which every writer handles.
- **N91. Freshness.** The current run is `WEFT_RUN` in the filter's
  environment, else the first line of `.weft/run` found upward. When a
  current run exists and a block's `run` differs (or is `null`), the
  values were not computed in this render (served from freeze or a cache,
  or a kept kernel without a run file). The filter prints the notice E34
  once per document and records it in the stamp (N110). This fails
  nothing in an ordinary render; `verify()` fails on it (N122).
- **N92. Leftover spans in a knitr document.** A span that reaches the
  filter with a governor key in a knitr document is resolved by N14 when
  its governor fits N9 and N12; when it does not, it is left for
  `weft-check.lua`, which fails on it as today.
- **N93. The filter changes nothing else.** It does not touch inline R,
  code spans that are not named values, or a span with no weft key or
  text class.
- **N94. `weft-check.lua` changes.** (a) It unwraps `span.weft-marker`
  and does not report the marker text inside it (weft.lua reported it).
  (b) A code span that is a named value (N5) left in the tree gets the
  message E35 in place of "a code span carries the weft class". (c)
  Everything else is as today.
- **N100. 6f classes**, each to the R rule it names and to its
  conformance set (N131): `.sci` (1.4.3), `.p` (1.4.17), `.date` (ISO
  date record only; `date_format` with the tokens R's default uses,
  `%-d %B %Y`, English month names, 1.6.8; another format string is
  E20), `.no`, `.word`, `.count`, `.ord` (1.4.12; limits from
  configuration), `.and`, `.or`, `.pairs` (a list with `keys`), `.range`
  (1.4.4), `.ul`, `.ol`, `.dl` (1.4.6), `sep`, `last`, `trunc`, `none`,
  `serial_comma` (1.4.15), `.a`, `.cap`, `.strong`, `.em` (stage iv),
  text spans (1.1.9), `sign` (1.5.1, 1.5.10, 1.5.17), `list` (1.5.19),
  `n` with `.range` (1.5.11), ids and back-references (1.7.5 to 1.7.12),
  `cite` spans (1.8.1 to 1.8.7; the key check at render is not done, the
  static `cite-key` lint covers it).

### G. Stamps, collection, ledger, `verify()` (package 6g)

- **N110. The stamp.** One file per document,
  `.weft/stamps/<stamp_file_name(source)>` (R's naming), in a set-up
  project only. Members as R writes them (`source`, `run`, `executed`,
  `checks`, `failures`), plus `writers` (an array: `"knit"`,
  `"filter"`), `named` (the count of constructs the filter resolved),
  and `fresh` (`true` when every block's `run` equals the current run,
  `false` when one differs, `null` with no current run or no block).
  - The filter writes last. When a stamp for the same source and the same
    `run` exists (the hooks wrote it in this render), it adds `"filter"`
    to `writers`, adds its counts to `checks` and its failures to
    `failures` (source `"resolve"`), and sets `named` and `fresh`.
    Otherwise it writes a new stamp, `run` the current run, `executed`
    the oldest `at` of its blocks in R's `"%Y-%m-%d %H:%M:%S"` local
    form (or now with no block).
- **N111. Collection lines** (2.6.6) have R's layout with `"source":
  "resolve"`. The post-render script treats `resolve` lines as it treats
  `knit` lines: listed, and able to explain a `<<weft:` marker that a
  `filter` line found.
- **N112. Ledger.** In a set-up project with `ledger: true`, the filter
  writes an entry for every construct it resolved into
  `_weft/ledger/<source>/<output name>.jsonl` (7.1.3), keyed by 7.1.4
  with: kind `value` for a named value, the span's key for a span;
  expression the NAME, or the governor value with runs of spaces made
  one; `writer` `"filter"`. The printed text, chosen arm, raw value
  (the record's `v`, or `null`) are as R writes them. The sentence is
  the containing block's stringified text, cut at the last `. `, `? ` or
  `! ` before the construct and the first after it (not ICU: 7.1.1's
  sentence is for display only). It merges: entries with `writer`
  `"filter"` from an earlier render are dropped, the hooks' entries are
  kept, its own added, the lines sorted by 7.1.5. With no ledger file it
  writes the header with `files` holding the source and every file of
  N89's include map and every values file read (N30), with their hashes
  (md5 of the bytes with line ends made `\n`, as R); `targets` and
  `dict` empty.
- **N113. Under knitr**, the hooks write their stamp, collection lines and
  ledger first, as today, and the filter merges (N110 to N112). The
  hooks' end-of-document check (2.5.2) does not count named values.
- **N120. `verify()` reads** the merged stamps: a failure in a stamp of
  this run fails; a verified document with a construct and no stamp of
  this run fails (8.3.4); a stamp with `fresh` `false` fails with E36.
- **N121. Freeze.** "Served from freeze" for a filter document means its
  blocks came from `_freeze` (N91). The post-render report's freeze
  notice uses the stamp's `fresh`.
- **N122. Kept kernels.** Before rendering, `verify()` writes `.weft/run`
  with this run's id (the pre-render script overwrites it with the same
  id), passes `--execute-daemon-restart` to `quarto render`, and, when a
  rendered document uses the julia engine, runs
  `quarto call engine julia kill` first (measured 5), saying so in its
  report.

### H. Coexistence in one knitr document (packages 6b, 6c, 6g)

- **N130h. Order of events.** (1) The knit: `weft_put()` and guest
  `claim()` record as chunks run; each prose block gets its waiting and
  auto names first (N42, N43), then the hooks resolve its R constructs and
  leave named values. (2) The `document` hook: a final block; the
  end-of-document check without named values; the hooks' report, stamp,
  collection lines, ledger. (3) Pandoc: `weft.lua` (N81), then
  `weft-check.lua`.
- **N131h. A value published by R and used by name** prints what the same
  value prints as `` `r x`{.num} ``: an R double is a float record, which
  the literal port prints as R (N85).
- **N132h. A named governor with R-expression arms**
  (`[`r a`{.num} rose | fell]{if="rising"}`) in a knitr document is the
  hooks' (the span is theirs, N14). A span the filter resolves holds only
  named values and text in its arms; inline R there was already evaluated
  by knitr.
- **N133h. Double reporting.** A failure is reported by the resolver that
  owns its construct. When the hooks stop the render (2.6.2), Pandoc does
  not run, and failures of named values show at the next render; in a
  project render with the collection file both go to the one post-render
  report.

### I. The static side in R (package 6d)

- **N140. Scanner rows.** A named value is a row of kind `named`
  (`expr` the NAME); a span in a document the filter resolves keeps its
  kind (`n`, `if`, `sign`, `list`, `cite`, `text`) with `resolver`
  `"filter"`; rows in a knitr document have `resolver` `"hooks"`, except
  `named` rows (`"filter"`). Every scanner consumer (lints, gate, ledger
  keys, `arms()`) takes the column.
- **N141. Construct errors from the source** (rule `construct`, 5.3.1):
  N7, N8's wording-class rule, N10, N11, N12, N13, N17's rules on named
  values; and in a filter document a span governor that is not N9 or N12
  (E3, E5). `expr_errors()` (R parse, 5.3.5) is not applied to `named`
  rows or to filter spans.
- **N142. Lints that apply unchanged** to named values and filter spans:
  `numeral`, `construct` (structure), `read`, `block-start`, `lone-bar`,
  `name` (with `.val` among weft names), `long-guard`, `if-zero` (on the
  condition text), `claim-word` (a named value is a value), the
  citation, cross-reference, anchor, `section-anchor`, `chunk-label`,
  `file-link`, `config-place`, `figure`, `table-caption` rules.
- **N143. Lints that cannot occur:** `literal-value` and `inert-check`
  (a name is not a literal; a condition of literals is E4),
  `value-constant`, `value-format` (no expression). `tar-*` and `dict-*`
  read R only.
- **N144. New lint `named-unpublished`** (tier 2, rule 5.12.1, scope
  file): a NAME used by a named value or a filter span (N45's names,
  restricted to constructs the filter resolves) that occurs nowhere as a
  whole-word token (`(?<![A-Za-z0-9_.])NAME(?![A-Za-z0-9_])`) in the code
  of any executed chunk of the document or its includes, in any
  language, nor as a key in a hand-written `weft-values` block of the
  document, nor in a values file the document reads (N30). Message E70.
- **N145. New lint `publish-hidden`** (tier 1, rule 5.12.2, scope file):
  in a document on the jupyter or julia engine, an executed chunk with
  `include: false` or `output: false` whose code calls `put(`,
  `weft.put(`, `@put` or `Weft.put(` (N59's line rules). Message E71.
  The same chunk calling `auto(` is a tier-2 finding of the same rule
  number, id `publish-hidden-auto`, message E72.
- **N146. The `engine` rule (5.8.9).** A `.qmd` rendered on its own that
  holds a construct is valid when either it is knit (`engine: knitr`, as
  today), or all of its constructs are `named` rows and filter spans and
  the resolver is installed (the project's `_quarto.yml` lists the filter
  `weft-check` under `filters:`, or the document's own front matter
  does). It is a finding when it is not knit and holds an R value or a
  span outside the grammar: G38's messages, with one sentence added to
  each hint, E73. It is a finding when it holds only named constructs
  and the resolver is not installed: E74.
- **N147. The gate's counts (6.3.1).** A `named` row counts as a value. A
  filter span counts as a span. Guest `claim()` calls count by N59. A
  hand-written block's names and a values file are not counted.
- **N148. `changes()`** reads ledger entries whatever their `writer`; a
  named entry's expression is its NAME.
- **N149. Ledger key for a name** (7.1.4): kind `value`, expression the
  NAME as written. For a filter span, the governor value with runs of
  spaces made one, unparsed.
- **N150. The pre-render script** (2.5.4) fails a `.qmd` that has no
  `engine: knitr` in its own front matter and holds an R value
  (`` `r `` or `` `{r} `` code span with an attribute block) or a span
  whose governor value does not fit N9 and N12 (a base-R regular
  expression of both, given in the script); a file with only named
  values and grammar spans passes. Message as today with the construct
  quoted, plus E75's sentence.

## 3. Decisions

Smallest undoable change first. "Reverse" names the place to change.

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| D1 | Form of a named value | `[depth]{.num}` (a span); a shortcode `{{< weft depth >}}`; `{depth}` braces; a code span with a class | the code span with a weft class (N5) | a bracket with only a formatter class is already "not weft's" (1.1.9) and would need its rule reversed; a shortcode is Quarto-only and fails under rmarkdown and Pandoc; braces collide with attribute blocks. A code span is inert without the filter, survives a Pandoc round trip (E6 of the scoping), and `weft-check.lua` already fails on it, so the form was free (reserved in design-5's amendment) | N5, scanner `handle_code()` |
| D2 | A name with no class | print `` `depth` `` as a value; require a class | require a class; `.val` prints as is | `` `depth` `` is ordinary code in every document; reading it as a value would change existing prose | N5, N8 |
| D3 | Dots in names | a path (`site.depth` into a mapping); forbidden; an ordinary character | ordinary character | R names hold dots (`n.sites`) and `weft_put()` must publish them; Python and Julia names never hold one, so nothing clashes; paths are a second grammar to keep in three languages | N6 |
| D4 | The condition grammar | expressions in the host language evaluated by the kernel; `and`/`or`/`not`; arithmetic | one comparison of names and literals, commas between (N9 to N11) | the intersection of R, Python and Julia; `and` and `/` differ across them; the scanner checks it with one pattern; the spike's 60 lines (scoping 3.4) | N9 to N11 |
| D5 | Who resolves a span in a knitr document | the filter always; the hooks always | the hooks for what they reach; the filter for named values and leftover spans (N14) | the hooks give R expressions, laziness and the condition log; a span in grammar means the same in both, so a leftover span (asis text) can still resolve | N14, N92 |
| D6 | Carrier | YAML metadata from a cell; a sidecar file; `{{< meta >}}`; a fenced block | the fenced block (N20) | metadata strings are read as markdown (measured 10, scoping 3.1); a sidecar is not held by freeze; the block is ordinary cell output on every engine (measured 1, 2, 7) and in `_freeze` as readable JSON | N20 |
| D7 | Record | a new record; stage 5's | stage 5's, plus optional `checks` (N22) | one classifier per language already makes it; the R side already reads it | N22 |
| D8 | Captions and front matter | in document order; after the body with final names | after the body, final names (N81, N26) | knitr writes waiting names after the chunk (N42), after the chunk's own figure caption; a name is usually set once | N81 step 3 |
| D9 | Publishing in a knit | `weft_put()` only; hooks auto-publish; hooks resolve named values in R themselves | `weft_put()` plus auto-publish at each prose block (N42, N43) | an R author writes nothing new; a named construct means the same on every engine because the filter resolves it everywhere; `include: false` is harmless under knitr | N43 off: only `weft_put()` |
| D10 | Names `auto` publishes | parse with each language's parser; the scanner's rows; a shared token pattern | the shared pattern (N45) | Python and Julia cannot run R's scanner; one pattern makes R and Python agree; a miss fails loudly | N45 |
| D11 | Guest `claim()` meaning | eager where it runs, recorded then raised (R's chunk rule); use-site, the outcome riding on the published value; eager on knitr and use-site on the engines | eager everywhere, record then raise (N50 to N57); use-site checks through sentence guards, `weft_put(x = claim(...))` and values files | one spelling must mean one thing; Python and Julia evaluate `claim()` before `put()` sees it, so use-site would need a wrapper value that breaks arithmetic or an identity table that small interned ints fool; R's own chunk claims are eager; a guard keeps the check in the sentence it supports. Robin asked for use-site on the engines; this is O1 | N51; add `checked()` (O1) |
| D12 | How a Python check is written | a callable (`lambda v: v > 10`); a string; both | a string, `"> 10"` or `"_ > 10"` (N50) | the text as written can be quoted in the report and the ledger; a lambda's source is not reliably readable in a kernel; the leading-operator form reads like the condition grammar | N50 |
| D13 | How a Julia check is written | `claim(n, >(10))` (a `Fix2`, which prints as a type); a macro | `@claim n > 10` and `@claim x (_ > 10)` (N55) | a macro has the expression, its text and its source line; `_` works inside a macro (measured 8) | N55 |
| D14 | Guest claim under knitr | through RCall into R; recorded in the guest and drained | Python calls R through the registered module (as `weft_str()` does, G22); Julia records in `Weft` and R drains (N56) | no RCall needed for Julia, and the drain already exists for `@warn` (J3) | N52, N56 |
| D15 | Python packaging | a file copied into the project by `use_quarto()`; a separate repository; a package inside this one | `inst/python/weft/`, pip-installable from a subdirectory, the same code under knitr (N60) | a copied file is importable only from the folder it sits in (a Jupyter kernel's working folder is the document's); one source keeps the two back ends and the classifier from drifting | N60 |
| D16 | Julia packaging | `WeftGuest.jl` only; a package | `inst/julia/Weft/`, `Pkg.add(subdir=)`, the same code under knitr (N60) | `using Weft` works the same in both back ends | N60 |
| D17 | One filter or two | merge the resolver into `weft-check.lua`; two files in one extension | two files, one extension still named `weft-check` (N80) | the backstop stays small and independent of the resolver, and checks its output; existing `_quarto.yml` entries keep working | N80 |
| D18 | Configuration in Lua | Pandoc metadata; a JSON copy written at set-up; read the YAML text | read the text with a flat reader (N84) | metadata mangles `" "` and `--` (measured 10); a copy goes stale when `_weft.yml` is edited; every setting the filter needs is a flat scalar | N84 |
| D19 | Formatting conformance | one exact algorithm for all; the literal port for all | literal port for floats, exact for int and decimal (N85) | the port gives R's text on every row (scoping E15); the exact path is right where R has no equal (big integers, decimals) | N85 |
| D20 | Big integers by name | keep stage 5's refusal; print exactly | print exactly | the refusal was R's limit, not the filter's; a Python `2**70` printing right is the point (scoping E12) | N85 |
| D21 | Lines | a second parse with `commonmark_x+sourcepos`; text search | text search with masking and the include map (N89) | exact on the spike's pages, no second reader whose blocks differ from `markdown`'s (2.10.3 needs masking for that), and the include map is R's 2.7.4 again | N89 |
| D22 | Run id in a kept process | the environment; a per-render file | `.weft/run` first, then `WEFT_RUN` (N48) | the julia server keeps its environment through restarts and closes (measured 5), Jupyter daemons too (scoping E17); a file is read fresh | N48 |
| D23 | Stamps when both write | two stamp files; the filter merges | merge into one (N110) | `verify()` and the post-render script read one file per document | N110 |
| D24 | Failure deferral under knitr | the hooks hand their failures to the filter so one report holds both | no deferral (N133h) | if the filter is not installed or not run (rmarkdown without `pandoc_args`), deferred failures would pass silently | N133h |
| D25 | Unimplemented classes | pass through; print the record's text | a value error (N83) | a silent pass-through prints an unformatted number as if formatted | N83 |
| D26 | `named-unpublished` tier | 1; 2 | 2 | names may come from `from helpers import *` or a sourced script, which a token search cannot see; the render fails loudly anyway | N144 |
| D27 | `publish-hidden` tier | 1; 2 | 1 for `put`, 2 for `auto` | a `put` in a hidden cell is always lost; `auto()` in a hidden set-up cell is common and loses only what that cell assigns | N145 |
| D28 | Order of packages | the scoping's order; claim after the resolver | claim (6k) first, beside 6a and 6b | its knitr half needs no filter, and it decides the Python and Julia package layout that 6e and 6h fill | §4 |

**Contradictions and gaps found:** rule 1.5.16 ("only the chosen arm is
evaluated") cannot hold for code that runs before the prose; for named
values it becomes "counts where used" (§6). Rule 1.1.2 names R as the
language of code spans and attribute values; named values and the
grammar are language-neutral. G19 excludes `claim` from the Python
module and G35's message says checks cannot be written in Python; both
change (N59). G41 adds `engine: knitr` to a Python-only document with a
construct; it is narrowed (N74). The pre-render script and the `engine`
rule fail every non-knitr document with a construct; both are narrowed
(N146, N150). 2.5.3's "a code span that carries a weft class" was the
right error until now; it becomes "a named value was not resolved"
(N94).

## 4. Work packages

Each package is one implementer session; its test-writer works from §2
and §5. NAMESPACE and `man/` are regenerated with roxygen after each
merge, never merged by hand.

| Pkg | Creates | Edits | Tests |
|---|---|---|---|
| **6a** Lua number printer (N85) | `inst/quarto/weftlib/num.lua`, `tests/testthat/_conformance/exact.tsv` (hand-curated rows of N131) | `R/conformance.R` (a `record` column: the JSON record N47 makes of each row's value; `exact.tsv` is not generated), the three committed `.tsv` files regenerated | `helper-lua.R`, `test-lua-num.R` |
| **6k** guest `claim()`, knitr back end (N50 to N52, N55, N56, N58 to N60) | `inst/python/weft/__init__.py`, `_record.py`, `_backend.py`, `inst/python/pyproject.toml`; `inst/julia/Weft/Project.toml`, `src/Weft.jl`, `src/record.jl` | `inst/python/weft_guest.py` (imports the classifier), `inst/julia/WeftGuest.jl` (includes `record.jl`), `R/guest.R` (load the package as `weft`, its back end, G23's refinement, the failure callback), `R/guest-julia.R` (`LOAD_PATH`, `Weft.use_knitr()`, drain claims), `R/constructs.R` (`claim_calls()` by engine, N59), `R/lint-doc.R` (`guest-call` text) | `test-guest-claim-py.R`, `test-guest-claim-jl.R`, `test-gate-guest-claim.R` |
| **6b** carrier and R publishing (N40 to N48, N130h step 1 and 2) | `R/values.R` (`weft_put()`, `weft_values_write()`, the record of N47, the block writer, N45's names, N48) | `R/hooks.R` (`weft_setup()` attaches `weft_put`; the `text` and `document` hooks write blocks), `R/state.R` (waiting names, last published), `R/resolve.R` (end-of-document check skips `named` rows; this is the only change there) | `helper-6b.R`, `test-values-record.R`, `test-weft-put.R`, `test-values-knit.R` |
| **6c** resolver core (N5 to N17 at render, N20 to N31, N80 to N94) | `inst/quarto/weft.lua`, `weftlib/cond.lua`, `config.lua`, `lines.lua`, `report.lua` | `inst/quarto/_extension.yml` (two filters), `inst/quarto/weft-check.lua` (N94), `inst/quarto/weft-post-render.R` (`resolve` lines, N111), `R/use.R` (copy `weft.lua` and `weftlib/` into the extension; nothing else) | `helper-filter.R`, `test-filter-carrier.R`, `test-filter-values.R`, `test-filter-if.R`, `test-filter-n.R`, `test-filter-report.R`, `test-filter-lines.R`, `test-filter-config.R`, `test-weft-check-named.R` |
| **6d** static side and installers (N140 to N150, N74's `use_setup()`) | `R/lint-named.R` (`named-unpublished`, `publish-hidden`) | `R/scan.R` (`named` rows, `resolver` column, grammar errors), `R/scan-contexts.R` (front matter and captions on filter documents), `R/lint.R` (registry), `R/lint-doc.R` (`lint_engine()`), `R/constructs.R` (gate counts of N147), `R/ledger.R` (key of N149), `R/setup.R` and `R/use-weft.R` (G41 narrowed; under rmarkdown `use_setup()` copies `weft.lua` and `weftlib/` beside the document and names `weft.lua` before `weft-check.lua` in `pandoc_args`), `inst/quarto/weft-pre-render.R` (N150) | `test-scan-named.R`, `test-lint-named.R`, `test-lint-engine-named.R`, `test-gate-named.R`, `test-pre-render-named.R`, `test-use-setup-named.R` |
| **6e** Python for Jupyter (N53, N54, N70 to N74) | | `inst/python/weft/__init__.py`, `_backend.py` (Jupyter and plain back ends, `put`, `auto`), `R/use.R` (`use_quarto()` message), `R/setup.R` (`status()` row) | `helper-jupyter.R`, `test-py-put.R`, `test-py-auto.R`, `test-py-claim-jupyter.R`, `test-jupyter-render.R`, `test-use-quarto-jupyter.R` |
| **6f** remaining classes (N100) | `inst/quarto/weftlib/words.lua`, `tests/testthat/_conformance/` new sets (N131) | `inst/quarto/weft.lua`, `weftlib/num.lua` (`.sci`, `.p`), `R/conformance.R` (the new sets) | `test-lua-words.R`, `test-filter-classes.R`, `test-filter-sign-list.R`, `test-filter-ids.R`, `test-filter-cite.R` |
| **6g** stamps, collection, ledger, `verify()` (N110 to N122, N130h step 3) | `inst/quarto/weftlib/stamp.lua`, `ledger.lua` | `inst/quarto/weft.lua`, `R/verify-render.R` (N122, `fresh`), `inst/quarto/weft-post-render.R` (freeze notice from `fresh`) | `test-filter-stamp.R`, `test-filter-ledger.R`, `test-verify-named.R`, `test-coexist-knitr.R` |
| **6h** `Weft.jl` for the julia engine (N55, N57, Julia `put`) | | `inst/julia/Weft/src/Weft.jl` (`@put`, `put`, `Weft.Values` and its `show`, engine back end), `R/use.R` (E62) | `helper-julia-engine.R`, `test-jl-put.R`, `test-jl-claim-engine.R`, `test-julia-render.R` |
| **6i** values files (N30, N46 file side) | | `inst/quarto/weft.lua` (`file=`), `weftlib/ledger.lua` (files in the header) | `test-filter-values-file.R`, `test-values-write.R` |
| **6j** article and spec | `vignettes/named-values.Rmd` | `vignettes/languages.Rmd` (a pointer), `_pkgdown.yml` | none (R CMD check builds it) |

**Julia `put`.** `Weft.put(; kw...)`, `Weft.put(pairs...)` and
`@put a b c` (each argument a variable, published under its own name)
publish as N70 says, with Julia's classifier (J1, without the 2^53
refusal); the engine back end displays a `Weft.Values` (measured 2), the
knitr back end hands records to R's waiting names through the drain, and
with no back end the block is printed.

**Order and parallel work.**

- First, in parallel worktrees: **6a**, **6k**, **6b**. Their file sets do
  not meet. (6b reads no file 6k writes; both are R, but 6k edits
  `R/guest.R` and `R/guest-julia.R`, 6b edits `R/hooks.R` and
  `R/state.R`.)
- **6c** after 6a (it calls `num.lua`). It does not need 6b's code: its
  tests write blocks by hand, which is the schema of §2B.
- **6d** after 6k (both edit `R/constructs.R` and `R/lint-doc.R`). It
  can run beside 6c: 6c edits `R/use.R` only to copy files, 6d edits
  `R/setup.R` and `R/use-weft.R`; if both touch `R/use.R`, 6d rebases.
- **6f** after 6c. **6g** after 6c and 6b. 6f and 6g both edit
  `weft.lua`: run them one after the other (6f first).
- **6e** after 6c and 6d (it needs the filter for its render tests and
  edits `R/use.R` and `R/setup.R` after 6d).
- **6h** after 6e (it mirrors it, and edits `R/use.R`).
- **6i** after 6g. **6j** last.

Why 6k first: its knitr half works today with no filter (a guest claim
under knitr is an R failure), it is what Robin asked for, and it fixes
the layout of the Python and Julia packages that 6e and 6h then fill.
Its engine halves (N53, N57) need the filter to report and are tested in
6e and 6h.

**What would stop a stage.**

- 6a: the literal port fails a row of the regenerated table after 5a's
  changes to `round_half_away()`. Stop and report the rows; do not change
  `format.R` to fit.
- 6k: R cannot register the package as `weft` without breaking G19 to
  G23's tests; or `LOAD_PATH` with a package directory does not let
  `using Weft` load under JuliaCall (see R6).
- 6b: the `text` hook cannot prepend a block without changing knitr's
  output for a document with no named value (G15-like pin: a document
  without names is byte-identical to today's output).
- 6c: Quarto runs extension filters after its crossref filter in some
  format, so captions show unresolved text (scoping E13 says not, for
  HTML). Stop and measure PDF and docx.
- 6e: `IPython.display.Markdown` from inside a `post_run_cell` callback
  does not reach the cell's output under Quarto (scoping E7 says it
  does).
- 6h: `Pkg.add(url=..., subdir=...)` cannot install from this repository
  layout.

## 5. Tests

**Lua from testthat.** `helper-lua.R`:

- `lua_pandoc()`: the Pandoc to run. Quarto's bundled Pandoc when
  `quarto` is on the `PATH` (`quarto pandoc --version` gives it), else
  `Sys.which("pandoc")`, else `rmarkdown::pandoc_exec()` when rmarkdown
  is installed. It must report 3.1 or later. `skip_if_no_pandoc()` skips
  only when none of these exists; an older Pandoc is a failure, not a
  skip.
- `lua_run(script, args)`: runs `pandoc lua <file>` in a fresh process
  with `system2()`, returns stdout, stderr and status.
- `filter_md(md, files = list(), to = "html", env = character(),
  weft_yml = NULL)`: writes `doc.md` and the files into a temporary
  project, runs `pandoc doc.md --lua-filter <inst>/quarto/weft.lua
  --lua-filter <inst>/quarto/weft-check.lua -t <to>` and returns output,
  stderr, status and the files written under `.weft/` and `_weft/`.
  Plain Pandoc is the default route for 6c, 6f, 6g, 6i tests: fast, and
  the filter must work there.
- A second Pandoc: when the `PATH` Pandoc differs in version from
  Quarto's, `test-lua-num.R` and `test-filter-values.R` run once with
  each.

**Real Jupyter and Julia.** `helper-jupyter.R`: `skip_if_no_jupyter()`
skips only when `quarto` is absent, or when no Python with `jupyter` and
`ipykernel` is found: `QUARTO_PYTHON` first, then `python3`; the probe
is `<python> -I -c "import jupyter_client, ipykernel"`. The tests add
`inst/python` to `PYTHONPATH` for the kernel (so the package under test
is used, not one installed). `helper-julia-engine.R`:
`skip_if_no_julia_engine()` skips only when `quarto` or `julia` is
absent; the first render may install QuartoNotebookRunner (allowed,
minutes); the helper sets `JULIA_LOAD_PATH` so `using Weft` finds
`inst/julia`, and runs `quarto call engine julia kill` at the end of
each file. No test installs Python or Python packages. Neither skips on
CRAN or CI by name.

**Knitr-side guests** (6k) use `helper-5.R` and `helper-5j.R` and their
skips.

**Files.**

- `test-lua-num.R` (6a): every row of `numbers.tsv` through
  `num.lua` with its `record` column gives `text` exactly; every row of
  `exact.tsv`; a float record and an int record of the same whole value
  up to 2^53 print the same; the printed info (`zero`, `one`, `two`,
  `decimals`) for 0, 1, 1.0 with `digits=1`, 2, 0.04.
- `test-guest-claim-py.R` (6k): N50's forms (`"> 10"`, `"_ % 2 == 0"`,
  a global in the check, several checks, a non-bool result, an exception
  in a check, no check E50, a lambda E51, a bad level E54); N52 in a knit:
  the failure's kind, chunk label, `expr` E56, `detail` E57; `error: true`
  then the render failing once at the end; without it the knit stopping
  with E55; a warned check in `last_knit()$warnings` and no raise;
  N54 in a fresh Python with no IPython; `from weft import claim, put`
  works and `__weft_r__` is true; a pip-style `weft` already imported
  (simulated: the package imported from `inst/python` before R
  registers) gets R's forms attached (N60); `weft_guest`'s classifier is
  the package's (one source: `weft_guest.classify is
  weft._record.classify`).
- `test-guest-claim-jl.R` (6k): N55's forms with exact `text`; N56 in a
  knit: the drained failure with the chunk's label and the knit stopping
  with `ClaimFailed`; `level=:warn` drained as a warning; `@claim x` with
  no check E50; `missing` given to a check E53.
- `test-gate-guest-claim.R` (6k): N59's patterns (Python `claim(`,
  `weft.claim(`, a comment line, `def claim(`, a string; Julia `@claim`,
  `Weft.@claim`, a comment line); a removed guest claim needs the
  trailer; `guest-call` on `r.claim(` with E58.
- `test-values-record.R` (6b): N47 row by row with exact JSON; floats
  `0.1`, `1/3`, `2^53`, `1e23`, `-0.0` round-trip; N45's names on a fixed
  source (code spans, governor values with strings removed, reserved
  words, an include).
- `test-weft-put.R` (6b): N40, N41 (a check text as written, `ok`, a
  failing check not stopping), N44, E40 to E45, `weft_values_write()`
  (N46) file content and atomic write.
- `test-values-knit.R` (6b): a knit of an `.Rmd` with named values: the
  output holds one block before the first prose block, with `cell`; a
  name changed in a later chunk is republished, unchanged ones are not;
  `include: false` chunk's names published; `results: asis` chunk
  printing a named construct after `weft_put()` (block before the text);
  a document with no named value knits byte-identical to the same knit
  with the auto-publishing off.
- `helper-filter.R`, `test-filter-carrier.R` (6c): N20 to N31: a block
  adds names; order (a name above its block: E10); republishing; a
  block inside a div and a list item; malformed blocks (E12, E13, each
  case of N28); duplicate keys (first wins, pinned); size limit; blocks
  and empty cell divs removed; `weft:` 2 refused.
- `test-filter-values.R` (6c): `.num`, `.pct`, `.val` on each record kind,
  `digits`, `sigfig`, E7, E8, the default governor class, pass-through
  (`.smallcaps` kept on a span), missing (E11), error records (E16 with
  `{S}` replaced), wrong kinds (E17), unimplemented classes (E20, E21,
  E22), big ints exact, printed-as-zero warned check.
- `test-filter-if.R` (6c): N9 to N11 every listed case with E3, E4,
  E18, E19; guards (1.5.5) and their message; empty arms and spacing
  (1.5.20's examples); comparisons: int vs decimal exact, float vs
  literal through doubles, strings `==`/`!=`, dates; a missing operand.
- `test-filter-n.R` (6c): 1 to 4 arms, `#`, `n="."`, E5, escapes
  (1.5.12's examples), choice by printed text (1.5.9).
- `test-filter-report.R` (6c): the report's exact text for one of each
  kind; markers with line, chunk, neither; exit 1; draft (`WEFT_DRAFT=1`
  and `draft: true`); collection file lines (`"source":"resolve"`); a
  use-site check on a record (N25a: once per use, never when unused);
  a block's own failed check (N25b, located by `div#cell-chk`).
- `test-filter-lines.R` (6c): lines for repeated identical constructs,
  a construct in a chosen and in an unchosen arm, inside a fenced block
  (not matched), in an HTML comment (not matched), a `#| tbl-cap:` line
  (matched), an included file (its own file and line), text a chunk
  printed (no line).
- `test-filter-config.R` (6c): N84's reader on each value form; the
  document wins; a wrong value E33 once; `big_mark: " "` and `minus:
  "--"` read exactly.
- `test-weft-check-named.R` (6c): N94 (a) and (b); the existing
  weft-check tests unchanged.
- `test-scan-named.R`, `test-lint-named.R`,
  `test-lint-engine-named.R`, `test-gate-named.R`,
  `test-pre-render-named.R`, `test-use-setup-named.R` (6d): N140 to N150
  case by case with exact messages; a jupyter `.qmd` with only names and
  the filter installed gives no `engine` finding; the same with
  `` `r x`{.num} `` gives G38 case 1 with E73.
- `test-py-put.R`, `test-py-auto.R`, `test-py-claim-jupyter.R` (6e):
  through a real kernel (`jupyter_client`), the displayed block's exact
  JSON; `auto()` publishing only the names the source names, only on
  change, one callback after two calls, E60; the claim block then
  `ClaimFailed`.
- `test-jupyter-render.R` (6e): `quarto render` of small `.qmd` files on
  the jupyter engine: values print; a hidden cell's name is E10 with its
  hint; a caption (`#| tbl-cap:`) and the title resolve; a failed claim
  under `error: true` reported once with the cell's label and exit 1; a
  project with `freeze: auto` rendered twice gives E34 on the second.
- `test-use-quarto-jupyter.R` (6e): N74's messages and the `status()`
  row.
- `test-lua-words.R`, `test-filter-classes.R`,
  `test-filter-sign-list.R`, `test-filter-ids.R`, `test-filter-cite.R`
  (6f): every row of `words.tsv`, `lists.tsv` and the new sets through
  the Lua side; each class's R rule examples.
- `test-filter-stamp.R`, `test-filter-ledger.R`, `test-verify-named.R`,
  `test-coexist-knitr.R` (6g): N110 to N122 and N130h to N133h: a knitr
  `.qmd` with both kinds rendered in a set-up project gives one stamp with
  `writers` both and one ledger file with both writers' entries; a second
  render replaces only the filter's entries; `verify()` failing on
  `fresh: false`.
- `test-jl-put.R`, `test-jl-claim-engine.R`, `test-julia-render.R` (6h):
  as 6e for Julia; `@put a b`; the `Weft.Values` display; a cell error
  stopping the render (pinned with measured 3's first line).
- `test-filter-values-file.R`, `test-values-write.R` (6i): N30, E32, a
  file read by two chapters, the ledger header's file hash.

**How the conformance sets grow (N131).** Each set is a `.tsv` with
the columns `value`, `classes`, `keys`, `text`, `record`, written by
`R/conformance.R` from R's own formatters and committed. 6a adds
`record` to the three existing sets and the hand-curated `exact.tsv`
(columns `record`, `classes`, `keys`, `text`, about 60 rows: ints of
16 to 40 digits, decimals of 16 to 30 digits, ties at every position,
`digits` 0 to 6, `sigfig` 1 to 5, `.pct`; each row's text derived by
hand from the rule and reviewed). 6f adds `dates.tsv`, `sci.tsv`,
`p.tsv`, `collapse.tsv` (`.pairs`, `.range`, `sep`, `last`, `trunc`,
`serial_comma`), `text.tsv` (`.a`, `.cap`), `governors.tsv` (`n` arms,
`sign` arms, `list` arms). A change to `format.R` that changes a row
fails the R conformance test first; the regenerated file then fails the
Lua test until the port follows.

## 6. Spec changes (for the spec editor, after 6j)

### New section 1.12 Named values

**1.12.1** A **named value** is a code span holding one name, directly
followed by an attribute block that carries a weft class or renderer key:
`` `depth`{.num} ``. The name is published by code (2.13). A name is
ASCII letters, digits, `_` and `.`, starting with a letter or `_`, not
ending in `.`, at most 64 characters, and not one of `TRUE FALSE True
False true false NA NULL None nothing missing Inf NaN`. A dot is part
of the name, never a path.

**1.12.2** `.val` prints a named value as itself: digits, the shortest
text of a float, a decimal as written, a string, an ISO date, `true` or
`false`. It is in the number stage's group, and takes no wording class.

**1.12.3** A code span with a weft class whose text is neither a name
nor inline R is a construct error.

**1.12.4** In a construct the filter resolves (2.13.2), a condition is a
name whose value is a bool, or one comparison `a OP b` with `OP` one of
`< <= > >= == !=` and each side a name, a number literal or a
single-quoted string, at least one a name. Conditions are joined by
commas (1.5.4). Anything else is a construct error: bind the value to a
name in code. Numbers compare exactly, except that a float is compared as
a double; strings compare with `==` and `!=` only; dates in calendar
order.

**1.12.5** In such a construct `n` takes a name, `.` or `#id`; `sign` a
name or `#id`; `list` a name.

**1.12.6** A construct sees the names published above it. A name used
above any publication of it is a "no value" failure. Captions and the
front-matter fields of 1.10.7 see each name's last published value.

**1.12.7** A named value means the same in every document and on every
engine. In a knitr document R values and spans stay R (1.1.2); write a
name where the hooks cannot reach, or for a value from Python or Julia.

### New section 2.13 The resolver filter

**2.13.1** Code publishes values as a fenced block of class
`weft-values` holding one JSON object of schema 1: `weft`, `values`
(name to typed record, §1.11), and optionally `lang`, `run`, `at`,
`cell`, `checks`. The filter removes it from the output.

**2.13.2** The Lua filter `weft.lua` resolves named values everywhere,
every construct in a document that is not knit, and a span that reaches
Pandoc in a knit document still carrying a governor in the grammar of
1.12.4. It runs before `weft-check.lua`, in the same extension.

**2.13.3** Formatting is §1.4 for the classes the filter implements. A
float prints as R prints it. An integer or a decimal prints exactly,
whatever its size. A class the filter does not implement is a value
error, never a pass-through. Units and project formatters are not
available to named values.

**2.13.4** A check carried on a published value counts where the name is
used, each time it is used. A check made in code where it ran, carried
in the block's own `checks`, counts once.

**2.13.5** Failures are collected, marked as 2.6.8, and reported once at
the end of the filter; the render then fails (tier 1), except in draft
mode or when a collection file is open.

**2.13.6** A failure's line is found by searching the source, its
includes and its chunk-option lines for the construct's text, in order.
Text a chunk printed has no line.

**2.13.7** The filter reads `_weft.yml` and the document's `weft:` key
as text.

**2.13.8** The run id a publisher records is read from `.weft/run`,
else `WEFT_RUN`, at each publish. A block whose run is not the current
run was not computed in this render; the filter says so, and
`verify()` fails on it.

**2.13.9** In a set-up project the filter writes the stamp, collection
lines and ledger entries for what it resolved, merging with what the
hooks wrote in the same render.

**2.13.10** A values file is a JSON file of schema 1, read where a
`weft-values` block with a `file` attribute and an empty body stands. It
is a file the chapter read (7.2.2).

**2.13.11** In a knit, the hooks publish every name the source names
that is bound in the knit's environment and has changed, at the start of
each prose block and at the end of the document, and `weft_put()`
publishes explicitly (3.8).

**2.13.12** A cell on the jupyter or julia engine with `include: false`
or `output: false` publishes nothing.

### New section 3.8 Publishing

`weft_put(...)` publishes names in a knit (2.13.11); a `claim()` given
directly to it is carried on the value (2.13.4). `weft_values_write(path,
...)` writes a values file. From Python: `from weft import put, auto`;
from Julia: `using Weft`, `@put a b`.

### New section 3.9 `claim()` from Python and Julia

`claim(x, "> 10")` in Python and `@claim x > 10` in Julia check where
they run, as `claim()` in R chunk code does (2.4.2, 2.4.4): a failed check
is recorded, then raises. A Python check is a string; one that starts with
a comparison operator applies to the value, any other is an expression in
which `_` is the value. A Julia check is an expression in which `_` is the
value, or the one comparison whose left side is the value. The result
must be a bool. `level="warn"` (`level=:warn`) records and goes on. Under
knitr the failure joins the knit's report with the chunk's label; on the
jupyter and julia engines it is carried in a block to the filter.

### Amendments

- **1.1.1** three constructs: add the named value (1.12.1).
- **1.1.2** add: "Named values and the conditions of 1.12.4 hold names,
  which mean the same in every language."
- **1.1.8** add: "A named value always has an attribute block, so it is
  always a construct; `.val` is its bare form."
- **1.5.16** add: "For a named value, what runs in code runs before the
  prose. A missing value, a carried error and a check carried on a value
  count only where the name is used."
- **1.10.1, 1.10.7, 2.3.5** add: "A named value works in any caption and
  front-matter field, on any chunk, since the filter resolves it after
  the body."
- **2.5.3** the filter list gains `weft.lua` before `weft-check.lua`; a
  named value left unresolved is a finding of its own.
- **2.5.4** the pre-render check fails only a document that holds an R
  value or a span outside 1.12.4.
- **2.9.2** a filter document "served from freeze" is one whose blocks
  carry another run.
- **5.1.4** add: "A named value's name is not parsed as R."
- **5.8 rule 9** (`engine`): valid without `engine: knitr` when every
  construct is named and the resolver is installed; E73, E74 in its
  notes.
- **5.11.2** `r.claim(` points at `claim` from the module (E58).
- **5.12** (new table): `named-unpublished` (tier 2), `publish-hidden`
  (tier 1) and `publish-hidden-auto` (tier 2).
- **6.3.1** add: named values count as values; `claim(` in Python chunks
  and `@claim` in Julia chunks count as `claim()` calls, by pattern.
- **7.1.4** a named value's expression is its name; a filter span's is
  its governor value with spaces collapsed, unparsed.
- **8.3** `verify()` writes `.weft/run`, restarts Jupyter kernels and
  kills the julia server before rendering; a stamp with `fresh: false`
  fails.
- **9.3.1** `use_quarto()` installs `weft.lua` and `weftlib/` in the
  extension; `use_setup()` copies them under rmarkdown; G41 narrowed.
- **2.12.8, G19** the module holds `claim`, `put`, `auto` as well.
- **§16** add: units, project formatters, phrase functions and
  `knit_print` for named values; expressions in the filter; Observable;
  an engine extension; `auto()` for Julia.
- **§19** add: Julia's engine and Jupyter run on the developer's machine
  only.
- **§21, §22** add stage 6 with §4's packages.

### Article outline: `vignettes/named-values.Rmd` ("Values by name")

1. What a named value is, and when to write a name instead of `r`.
2. Publishing: `weft_put()` and the automatic publishing under knitr;
   `put()` and `auto()` in Python; `@put` in Julia; a hand-written block.
3. Jupyter and Julia set-up: the extension, the package install lines,
   R and weft still needed for the gate and `verify()`.
4. Conditions: the grammar and why it stops there.
5. Checks: `claim()` in Python and Julia; guards in the sentence;
   `weft_put(x = claim(...))`.
6. Captions and front matter.
7. Exact numbers: Python's big integers, decimals.
8. Freeze, kept kernels and `verify()`.
9. Engine-free chapters with a values file from a pipeline.
10. The traps, each with its message: a hidden cell, a name used too
    early, an unimplemented class.
11. Limits, in one list.

## 7. Messages

`{name}` is a NAME; `{kind}` one of bool, integer, float, decimal,
string, date, list; `{c}` a class without its dot. Each is the failure's
`detail` (filter) or the condition's message (R, Python, Julia).

| Id | Text |
|---|---|
| E1 | `` `{text}` is not a name, so it cannot carry a weft class: a named value holds one name. Bind the value to a name in code (rule 1.12.3). `` |
| E2 | `` `.val` prints a value as it is and cannot take `.{c}` (rule 1.12.2). `` |
| E3 | `` `{part}` is not a name or one comparison of names, numbers and 'strings'; bind the condition to a name in code (rule 1.12.4). `` |
| E4 | `` `{part}` compares two literals and has no name, so it is always the same (rule 1.12.4). `` |
| E5 | `` `{value}` is not a name for `{key}`; it takes a name{extra} (rule 1.12.5). `` (`{extra}`: for `n` ``, `.` or `#id` ``; for `sign` `` or `#id` ``; for `list` nothing) |
| E6 | `` `#{id}` names an id on {a named value \| an R value}, which the {hooks \| filter} cannot read; refer to an id of the same form (rule 1.12.5). `` |
| E7 | `` `digits` must be a whole number, not negative (got `{v}`). `` (and the same for `sigfig`; R's text) |
| E8 | `` `{key}` must be at most 100 (got `{v}`). `` (R's text) |
| E9 | `` A named value takes no `{key}`: a governor key belongs on a span (rule 1.3.3). `` |
| E10 | `` no value is published under the name `{name}` above this point (rule 1.12.6). `` Hint: `` Publish it in code above: weft_put({name} = ...) in R, put({name}=...) in Python, @put {name} in Julia. A cell with include: false or output: false publishes nothing on the jupyter and julia engines. `` |
| E11 | `` `{name}` is missing ({why}) (rule 1.3.4). `` |
| E12 | `` a weft-values block that does not read: {reason} (rule 2.13.1). `` (`{reason}`: `not JSON`; `not a JSON object`; `` `weft` is not 1 ``; `` no `values` object ``; `` `{key}` in `values` is not a name ``) |
| E13 | `` a weft-values block of {n} bytes; the limit is 5000000 (rule 2.13.1). `` |
| E14 | `` {check} was false (value {val}){; why} `` (a check carried on `{name}`) |
| E15 | `` {check} was false (value {val}){; why} `` with `expr` the claim (N58) |
| E16 | the record's `why` with `{S}` replaced by `` `{name}` `` |
| E17 | `` `.{c}` needs a {needs}; `{name}` is a {kind} (rule 1.4.3). `` (`{needs}` number, date, list) |
| E18 | `` a condition must be true or false, and `{name}` is a {kind} (rule 1.11.8). `` |
| E19 | `` `{part}` compares a {kind} with a {kind} (rule 1.12.4). `` and for strings with an order: `` `{part}` orders two strings; strings compare only with == and != (rule 1.12.4). `` |
| E20 | `` `.{c}` on a named value is not available in this version of weft.lua (rule 2.13.3). `` (for a key: `` `{key}=` ``) |
| E21 | `` `.{c}` is a project formatter, which is an R function; a named value cannot use it (rule 2.13.3). `` |
| E22 | R's text of 1.6.5 or 1.6.8 for the `lang` |
| E30 | `` weft.lua needs Pandoc 3.1 or later; this is Pandoc {v}. `` |
| E31 | `` the record of `{name}` does not read: {what} (rule 2.13.1). `` |
| E32 | `` the values file {path} cannot be read: {reason} (rule 2.13.10). `` |
| E33 | `` {file}: `{key}: {value}` is not a {what}; the default is used (rule 9.1.6). `` |
| E34 | `` weft: the values in {file} were published by run {run}, not this run ({current}): served from freeze or a cache, or by a kernel kept from an earlier render. Their checks did not run now (rule 2.13.8). `` |
| E35 | `` a named value was not resolved: the filter weft.lua is not installed before weft-check.lua (rule 2.5.3). `` |
| E36 | `` {file}: its values were not computed in this run (rule 2.13.8). `` |
| E40 | `` weft_put() takes named arguments or names: weft_put(n = nrow(d)) or weft_put(n) (rule 3.8). `` |
| E41 | `` `{name}` is not a name weft can publish: ASCII letters, digits, _ and ., starting with a letter or _ (rule 1.12.1). `` (Python `PublishError` E41p: the same text) |
| E42 | `` `{name}` is a list of {n} elements; weft publishes at most 10000 (rule 2.13.1). `` |
| E43 | `` `{name}` is given twice in one weft_put() call. `` |
| E44 | `` `{name}` is a units quantity; named values carry no units. Publish the number in the unit you mean (rule 2.13.3). `` |
| E45 | `` `{name}` is an R {class}, which weft does not publish. Publish a bool, number, string, Date, or a vector of one of these (rule 1.11.1). `` |
| E50 | `claim() needs at least one check.` (Julia: `@claim needs at least one check.`) |
| E51 | `a check is a string, such as "> 10" or "_ % 2 == 0".` |
| E52 | as E42, from Python or Julia |
| E53 | `` {check} gave a {type}, not True or False (rule 1.11.8). `` (Julia: `not true or false`) |
| E54 | `level is "fail" or "warn".` |
| E55 | `` weft: a claim failed: {check} was false (value {val}). `` |
| E56 | N58's `expr` |
| E57 | N58's `detail` |
| E58 | ``"`claim()` cannot be called through `r.`: reticulate converts its argument with no check. Write `from weft import claim` and `claim(n, "> 10")` (rule 5.11.2)."`` |
| E59 | `auto() works in a Jupyter kernel or a weft knit.` |
| E60 | `` auto() cannot read the document {path}; give it: auto("doc.qmd"). `` |
| E61 | `` Install the Python package in the Python Quarto uses: pip install "git+https://github.com/vorpalvorpal/weft#subdirectory=inst/python" `` |
| E62 | `` Install the Julia package: using Pkg; Pkg.add(url = "https://github.com/vorpalvorpal/weft", subdir = "inst/julia/Weft") `` |
| E70 | `` `{name}` is used by name but no chunk of this document mentions it; publish it with put(), weft_put() or @put (rule 5.12.1). `` |
| E71 | `` chunk `{label}` has {opt}, so what it publishes never reaches the document; publish in a chunk that shows its output, with echo: false if the code should not show (rule 5.12.2). `` |
| E72 | `` chunk `{label}` calls auto() and has {opt}, so the names it sets are not published (rule 5.12.2). `` |
| E73 | added to each G38 hint: `` Or write each value as a name, `x`{.num}, and publish it in code: then no knitr is needed (rule 1.12.7). `` |
| E74 | `` {file} holds named values, and the filter weft.lua is not installed: run use_quarto() (rule 5.8.9). `` |
| E75 | added to the pre-render message: `` A document on another engine can use named values instead (rule 1.12.7). `` |

## 8. Risks

- **R1. Quarto changes how cell output reaches Pandoc.** Unlikely (the
  cell divs are how every format works). The render tests pin it per
  engine.
- **R2. The julia engine's text/markdown handling** is
  QuartoNotebookRunner's, not documented by Quarto. `test-julia-render.R`
  pins it; `output: asis` with `println` is the fallback (measured 1).
- **R3. Kept processes.** A kernel or julia server keeps a stale
  environment (measured 5). Mitigated by N48 and N122; a render with no
  run file and a kept server records a stale `run`, which only misleads
  the freeze notice, never a value.
- **R4. `auto()` and the source path.** A kept kernel could read another
  document's path. Mitigated by calling `auto()` each render (N72) and by
  the loud failure of every missed name.
- **R5. The literal port drifts from `format.R`.** The conformance test
  fails first; that is its job.
- **R6. `using Weft` under JuliaCall from a package directory in
  `LOAD_PATH`.** Not measured. If it fails, R `include`s
  `Weft/src/Weft.jl` into `Main` as a module and the author writes
  `using .Weft` under knitr, which breaks the one-spelling promise for
  Julia; stop 6k's Julia half and ask.
- **R7. Python package name.** `weft` may be taken on PyPI; installing
  from git avoids it (O4).
- **R8. Two resolvers in one document** confuse an author when a span in
  grammar sits in asis text in a knitr document (the filter resolves it,
  N92). The `engine`-like lints do not see asis text; the render does.
- **R9. Size.** `auto()` on a large array is refused (N29), but a
  thousand scalars still make large `_freeze` JSON. Accepted.

## 9. Open questions for the orchestrator

Each has a recommended answer; the build follows it unless told
otherwise.

- **O1. Use-site checks from Python and Julia.** Robin's message asked
  that on the engines a claim's outcome ride in the record and count
  where the name is used. D11 makes `claim()` eager everywhere instead,
  because one spelling must mean one thing and Python evaluates it before
  `put()` sees it. Recommended: keep D11, and if an author wants use-site
  checks in code, add later a separate `put(n=checked(n, "> 10"))` (a
  holder that only `put()` accepts) and `@put n => @checked(n > 10)`;
  the schema already carries them (N22) and the filter already honours
  them (N25a), so this is small.
- **O2. A guest claim that fails under knitr stops the knit** (N52, R's
  2.4.4). The alternative is to collect and go on, as `weft_str()` does.
  Recommended: stop, as R chunk code does; `error: true` is the author's
  way to go on.
- **O3. Hooks auto-publishing (N43)** costs a record per named name per
  prose block. Recommended: build it; measure the knit time on the
  largest real chapter at 6b's end, and turn it into "names whose binding
  changed" (compare `identical()` before building the record) if it
  costs more than 50 ms a chapter.
- **O4. The Python distribution name** `weft-prose` (import name
  `weft`). Recommended: yes, and publish to PyPI only when an outside
  author asks.
- **O5. Failures not deferred under knitr (D24).** A single-file knitr
  render with both an R failure and a named failure shows them in two
  renders. Recommended: accept; revisit only if the filter can be known
  to run (Quarto's execute info lists it).
- **O6. `verify()` kills the julia server (N122).** It ends any other
  Julia notebook the author has open in that server. Recommended: yes,
  and say so in the report; there is no narrower command that refreshes
  the environment (measured 5).
- **O7. `named-unpublished` at tier 2 (D26).** Recommended: tier 2.
- **O8. Captions and front matter use the last published value (D8).**
  Recommended: yes; a document that republishes a name and captions it in
  between is rare, and the alternative breaks knitr captions.
- **O9. A check workflow** with Jupyter and Julia, beside O3 and O16 of
  stage 5. Recommended: add `quarto` and `pip install jupyter ipykernel`
  to that workflow's task; the Julia engine adds minutes and can wait.

## Rulings on the open questions (orchestrator, 13 Nov, under delegation)

Every recommended answer is accepted.

- O1: `claim()` is eager on every back end (D11). The request that an
  engine claim "count where the name is used" was the orchestrator's
  wording in the brief, not Robin's; his question was only whether
  Python and Julia versions of `claim` can ship with weft. `checked()`
  waits for an author who wants it.
- O2: a failed guest claim under knitr stops the knit, as R chunk code
  does.
- O3: build automatic publishing, measure at the end of 6b, and narrow
  it to changed bindings if it costs more than 50 ms a chapter.
- O4: the distribution is `weft-prose`, import name `weft`. Nothing is
  published to PyPI or a Julia registry: installing is from git.
- O5: accepted.
- O6: `verify()` ends the julia server, only for a document on the
  julia engine, and says so in its report.
- O7: tier 2. O8: the last published value. O9: Jupyter joins the
  check workflow; the julia engine waits.

R6 is measured first in 6k: if `using Weft` does not load under
JuliaCall from a package directory on `LOAD_PATH`, the Julia half
stops and the orchestrator decides.

## Rulings after 6c (orchestrator, 13 Nov, under delegation)

The implementer of 6c chose these where the design was silent. All are
accepted and are spec text for 6j unless noted.

- Config problems (E33) are failures of kind "construct error": they
  fail the render outside draft mode.
- E19 names the kinds "integer", "number" (literals) and "list".
  bool == bool is allowed; ordering bools, and a date against a string
  literal, are E19.
- An `n` governor that is not a number is a value error citing 1.5.11.
  `pct_proportion: false` is a value error.
- A named value with only a renderer key prints as `.num`, or `.pct`
  when `governor_class` is `pct`. `digits` on `.val` is ignored.
  `none` with no collapse class, and `sigfig` below 1, are construct
  errors.
- The printed-as-zero warning applies to float and decimal records,
  not int. `#` and `##` are read only inside an `n` arm.
- A guard's detail is "X was false" and the "optional text is
  written" hint.
- Until 6f: `sign`, `list` and `n=#id` give E20. Spans with only text
  classes, and `cite`, are left alone. Until 6i: a block with `file=`
  is a construct error.
- The stale-run notice (E34) goes to stderr once and fails nothing.
- An id on a named value goes on the pass-through span.
- Front matter: only title, subtitle, abstract and description are
  resolved.
- A block's own check with no `line` and no enclosing cell shows the
  file only. Reported paths are relative to the working folder when
  under it.
- Lines (N89): a construct's line is the next occurrence of its text
  in the source. Text a chunk printed that also appears later in the
  source therefore takes that later line. Accepted as a limit.
- **Not yet built: N92.** The filter resolves every construct and does
  not detect a knitr document, so a leftover span whose governor does
  not fit N9/N12 is reported by `weft.lua`, not left for
  `weft-check.lua`. 6g builds the detection with `test-coexist-knitr.R`.

Seven 6c tests were amended: Pandoc writes `class="sourceCode json"`;
one line number was miscounted; Pandoc does not read an attribute value
with leading spaces as a span; a failing render writes no output, so
two exit-1 checks run the document directly; and the stand-ins for
chunk-printed text now use names the source line cannot match.

## Rulings after 6d (orchestrator, 13 Nov, under delegation)

Accepted choices of the 6d implementer, spec text for 6j:

- A filter document is decided from source lines: an `.Rmd` never is;
  `engine: knitr` is not; otherwise an `engine:` or `jupyter:` key, or
  no executed `{r}` chunk, makes it one. So a bare `.qmd` with no chunk
  is the filter's.
- R values always have resolver `hooks`. `unit` counts as a renderer
  key for N5. E7/E8 are not checked statically.
- `named-unpublished` gives one finding per name, at its first use,
  and its hint covers open finding 5 (a governor name in a document
  with no named span is not published automatically).

Older pins changed because the rules changed: the G38/J25 engine tests
use a span outside the filter's grammar and their hints gain E73; a
literal-against-literal `if` in a bare `.qmd` is E4 (N143), not
`inert-check`; a pipe inside a named value is E1 (N7); `n=3` in a bare
`.qmd` is E5; the gate scenario for added named values lists the
filter, since E74 otherwise is a new finding.

## Rulings after 6f (orchestrator, 13 Nov, under delegation)

Accepted choices of the 6f implementer, spec text for 6j:

- `.p` outside 0 to 1, `.a` on text that is not a number word: value
  errors with R's text. `.pairs` and `.dl` on a list with no keys:
  value error "needs a named vector".
- `.em` with `.strong` is a construct error (one at-most-one group).
- `sign` or `n` given a non-number is a value error. A missing `list`
  element is "no value". `list` over bools prints TRUE/FALSE.
- An id stays on the pass-through span. A duplicate id is a construct
  error. An id defined inside an arm is dropped at the end of the arm.
- `.ord` as an `n` governor chooses by the number as printed.
- A `date_format` other than `%-d %B %Y` is E20.
- `.num`, `.sci` and `.p` on a list with no collapse class are E17.
  R prints a vector per element there: a parity gap, kept for now.
- `word_limit` defaults to 100 in the filter, as in R (6c had 10).
- The row `c(A = 1.25)` with `.pairs` is out of `collapse.tsv`: a
  named vector of length 1 is a scalar record (N47), so its name
  cannot reach the filter (open finding 9).
