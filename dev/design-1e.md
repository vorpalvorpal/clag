# Stage 1e — internal contract: `arms()` and `rehearse()`

Rules 3.7.1 to 3.7.4. The earlier design notes still hold.

## `arms(file)` (exported)

Runs no R (no evaluation; `parse()` only, as the scanner does). Takes one
path, or several. Returns a data frame of class `c("weft_arms",
"data.frame")`, one row per arm of every governed span (`n`, `if`, `sign`)
that `scan_file()` finds, in prose, captions, front-matter fields and
literal `weft_str()` strings:

| Column | |
|---|---|
| `file`, `line` | where the span starts |
| `context` | as `scan_file()` gives it |
| `span` | the span's number within the result, in document order |
| `key`, `expr` | `"n"`, `"if"` or `"sign"`, and the value of the key |
| `arm` | the arm's index within its span |
| `role` | what the arm is for: `"always"`, `"one"`, `"other"`, `"zero"`, `"two"`, `"true"`, `"false"`, `"positive"`, `"negative"` |
| `text` | the arm as the author wrote it (trimmed) |
| `parent_span`, `parent_arm` | the span and arm it is nested in, or `NA` |

The print method lists each span as `file:line  key="expr"` with its arms
indented under it and a nested span indented under its arm.

A file with a construct error is still listed; the errors are given in an
attribute `errors` and the print method ends with them.

## `rehearse(file, cases)` (exported)

`cases` is a named list; each case is a named list of `params`. For each
case the document is knitted once, in a fresh R process, and the knit's
records are read back.

- **What is run.** The knit only (`knitr::knit()`), not Pandoc and not
  Quarto: a rehearsal needs the records, not the output. Draft mode is on,
  so a case with failures runs to its end. `params` are the document's
  defaults with the case's values over them (an unknown name is an error
  before anything runs). The working directory is the document's, as in a
  render.
- **Nothing is written to the project (3.7.2).** The output and figures go
  to a temporary directory that is removed. The environment variable
  `WEFT_REHEARSE=1` is set for the child, and with it weft writes no stamp,
  no collection line, no draft JSON file, no ledger and no condition log,
  and uses no chunk cache (`cache = FALSE` is forced, so no cache directory
  appears). A chunk of the document that itself writes files is the
  author's affair.
- **Limits, stated in the help page.** Because Quarto does not run, a
  `{{< include >}}` is not expanded and project-level metadata is not read;
  a `.qmd` whose inline code uses the `{r}` form is knitted with a stand-in
  for Quarto's `.QuartoInlineRender` (rule 3.7.4 is otherwise unchanged: a
  document that reads its data some other way renders the same data in
  every case).

Returns an object of class `weft_rehearsal`, a list:

- `cases`: a named list, one per case, each a list with `ok` (no failures
  and the knit finished), `error` (the message when the knit itself
  stopped, else `NA`), `failures` (the data frame of `last_knit()$failures`)
  and `chosen` (a data frame: `span`, `file`, `line`, `key`, `expr`, `arm`,
  `role`, `text` for each governed span the case evaluated; `span` matches
  `arms(file)`)
- `arms`: `arms(file)` with one extra logical column per case (did this
  case choose this arm) and a column `reached` (did any)
- `unreached`: the rows of `arms` no case reached
- `unevaluated`: the spans no case evaluated at all (nested in arms never
  chosen)

The print method reports case by case (the failures in the layout of
2.6.2, then the arm each span chose), then the unreached arms and the
unevaluated spans. A case that fails is reported and the next case runs
(3.7.3).

## Tests

`test-arms.R`, `test-rehearse.R`. Fixtures: a small `.Rmd` with `params`
(a count and a flag) driving `n`, `if` and `sign` spans, one nested span,
one caption, one claim that fails for one case, and one chunk that stops
for one case. Assert on the returned objects, loosely on printed output,
and that the fixture's directory holds exactly the same files before and
after (3.7.2), in a project with `_weft.yml` too.

## Rulings on the implementer's report

- The control of the "plain folder" test knitted bare, which defines no
  `params`; it now renders with rmarkdown. The test's subject (nothing
  written by `rehearse()`) is unchanged.
- Chosen arms are read from `last_knit()$constructs` and matched to
  `arms(file)` by line, key, expression and context; a caption by its
  option. Accepted.
- A span with a wrong arm count is left out of the rows and given in
  `errors`. Accepted.
- A `.qmd` is staged in a temporary directory as Quarto's `.rmarkdown`
  copy, with `_weft.yml` and `_quarto.yml`. A bibliography given relative
  to the project root is not staged, so a `cite` span in a rehearsed
  `.qmd` can report an unknown key (in `dev/open-findings.md`).

## Rulings on the review of stage 1e (`dev/review-1e.md`)

Findings 1 to 13 are accepted as the reviewer states them, with these
particulars:

- **1.** In a rehearsal no chunk is cached, wherever the chunk sits and
  however its cache was set: the child turns the cache off before the knit
  starts, not from `weft_setup()`.
- **2 to 5.** A choice is credited to the span that made it. The knit's
  record of a governed span carries what is needed to identify it (its
  context, chunk and option for a caption, its place among the spans of
  its line), and `rehearse()` matches on that, never on evaluation order
  alone. Front-matter and literal `weft_str()` spans are matched.
- **6.** A `.qmd` is knitted with the document's own folder as the working
  directory, so relative reads and `child=` work as in a render.
- **7.** `params` defaults are evaluated in the child, in the document's
  folder. The check for unknown names reads the names only and evaluates
  no `!r` expression in the caller's session. A default that cannot be
  evaluated stops that case with the error.
- **8, c.** `chosen` has a row for every governed span the case evaluated;
  `arm` and `role` are `NA` when it chose none. Such a span is not in
  `unevaluated`.
- **9.** A case named after a column of the result (`file`, `line`,
  `context`, `span`, `key`, `expr`, `arm`, `role`, `text`, `parent_span`,
  `parent_arm`, `reached`) is an error before anything runs.
- **10.** The child is started in the project root (the nearest folder
  upward holding `_weft.yml` or `_quarto.yml`, else the document's folder)
  and reads that folder's `.Rprofile`, as a render does; it is not
  `--vanilla`. The knit's working directory is still the document's.
- **11.** A span that is a construct error in its language (1.6.4, 1.6.5)
  goes in `errors` and has no rows.
- **12, 13.** Accepted.
- **a.** `arms()` lists the spans of the files it is given; a child
  document is listed when it is given. `rehearse()` reports the spans of
  the file rehearsed. Stated in the help pages; left.
- **b.** One row per span and case: the last choice. Left.
- **d.** Case values are not type-checked. Left.
- **e.** An empty `cases` is an error. Left.
- **f.** `r$arms` keeps the class `weft_arms`, the `errors` attribute and
  the `file` values of `arms(file)`.
- **g.** `execute-dir` is project metadata and is not read (the limits
  already say so). Left.
