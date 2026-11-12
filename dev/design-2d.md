# Package 2d — the ledger and the condition log

Written before any test or code. It fills in the outline of 2d in
`dev/design-2.md` §4 and answers its six open points, R5 (the file formats,
for Robin to read before the build) and the 2d half of contradiction K3.
Robin delegated the choices on 12 November 2026; each one is in the decision
table with its alternatives, so it can be reversed. The earlier notes still
hold. Every example value below is invented.

Two facts were measured for this note (rmarkdown 2.31, knitr 1.51, Quarto
as installed here):

- Under `rmarkdown::render()` no API names the output file during the knit,
  but the frame of `render()` holds `output_file` once the knit starts:
  `render("d.Rmd", output_file = "site-b.md")` gave `site-b.md`, and the
  default gave `d.md`.
- Under Quarto, `QUARTO_EXECUTE_INFO` holds `format$pandoc[["output-file"]]`
  (`q.html` for `quarto render q.qmd --to html`). With `-o other.md` the
  field is **absent**, and no `QUARTO_*` variable names the output.

## Scope

| Rules | What 2d does |
|---|---|
| 7.1.1–7.1.8 | the entries, their key, the file per source and output, sorting; "changed" is defined by the fields 2d writes (2e compares) |
| 7.4.1, first three sources | chunk conditions, conditions from values in prose, conditions replayed from the chunk cache (stage 1 logs all three; 2d writes them) |
| 7.4.3–7.4.6 | the committed condition log: one line per key, sorted, text carried forward; the report of new conditions in an ordinary render |
| 9.3.2, 3.7.2 | written only in a set-up project, never in a rehearsal |
| 2.9.1 (extended) | constructs recorded in a cached chunk are replayed into the ledger |

**Left to 2e:** the fourth condition source (`tar_meta()`, 7.4.1); the
targets a chapter reads and their hashes in the ledger's header (7.2.2); the
third state (7.2.1, 7.2.3); `changes()` and its ranking (7.3); any exported
reader; reporting ledgers whose source or output is gone. 2d leaves two
places for 2e to fill (D27).

## The contract

### Files

- **D1 — Where.** For a top-level knit of a source file in a set-up project
  (a root holding `_weft.yml`, decision 3), two files under the project root:
  `_weft/ledger/<source path>/<output name>.jsonl` (the ledger) and
  `_weft/ledger/<source path>/<output name>.conditions.jsonl` (the condition
  log). `<source path>` is the source's path relative to the root, with `/`
  and its extension (`reports/survey.qmd`); under Quarto it is the `.qmd`,
  not the `.rmarkdown` copy. The spec says `generated/ledger/`; see G2.
- **D2 — The output name** is the output file's base name without its
  extension, found in this order: (1) the environment variable
  `WEFT_OUTPUT`, when set and not empty; (2) under `rmarkdown::render()`, the
  `output_file` of the innermost `render()` frame on the call stack; (3)
  under Quarto, `format$pandoc[["output-file"]]` from `QUARTO_EXECUTE_INFO`;
  (4) otherwise the source's base name. Under Quarto, when (3) is absent
  (`quarto render -o`), (4) is used and the knit raises one
  `weft_ledger_warning` saying that renders to other outputs will overwrite
  this ledger and that `WEFT_OUTPUT` names it. A plain `knitr::knit()` uses
  (4). One output in two formats (`doc.html`, `doc.pdf`) has one name and
  one ledger; the last knit writes it.
- **D3 — Encoding.** UTF-8, no byte-order mark, `\n` line ends on every
  platform, a final newline. One JSON object per line, no spaces between
  tokens, keys in the fixed order given below. Strings escape `"`, `\`,
  characters below U+0020 (`\n`, `\t`, `\r`, else `\u00XX`) and invisible
  characters as `\uXXXX` with lower-case hex: U+00A0, U+00AD, U+2000–U+200F,
  U+2028, U+2029, U+202F, U+205F, U+2060, U+FEFF. Every other character is
  written as itself (`−`, `²`, `µ`).
- **D4 — Header.** Line 1 of each file is a header object, not sorted with
  the rest: `{"weft":"ledger","version":1,"source":"<source path>","output":"<output name>"}`,
  and the same with `"weft":"conditions"`. It holds no time, no weft or R
  version and no machine name, so an unchanged document writes an unchanged
  file. A document with no entries, or no conditions, writes the header
  alone.
- **D5 — Versions.** `version` is 1. A reader ignores fields it does not
  know, in the header and in entries, so a later field is additive; the
  version rises only when a field is removed or changes meaning. A reader
  reads every version up to its own.
- **D6 — Writing.** The file is written to a hidden temporary file in the
  same directory (`.<name>.tmp<pid>`) and renamed over the old one; if the
  rename fails, the temporary file is copied over and removed. When the new
  bytes equal the file's bytes the file is not written, so its time stamp
  does not change. Only the two files and their directory are touched.

### The ledger entry

- **D7 — Which constructs.** One entry for each construct of kind `value`,
  `bare`, `n`, `if`, `sign`, `list` or `cite` that was evaluated in the knit,
  in prose, captions, front-matter fields and `weft_str()` strings, nested
  ones included. A construct in an arm not chosen has no entry. Text spans
  (`.strong`) and links have none; the values inside them do.
- **D8 — Fields**, in this order, all always present:

| Field | JSON | Value |
|---|---|---|
| `file` | string | the file the construct is written in, relative to the root, `/`: the child's or the included file's own path |
| `section` | string | D10 |
| `kind` | string | one of D7's seven |
| `expr` | string | D9 |
| `occ` | integer ≥ 1 | the occurrence among entries with the same `file`, `section`, `kind` and `expr`, in knit order |
| `id` | string or null | the `#id` without `#` |
| `context` | string | `prose`, `caption`, `front-matter` or `weft_str` |
| `text` | string or null | what the construct put in the document, as emitted (markdown, U+00A0 and all); for a governed span the chosen arm as printed (`""` when none); for a bare value the text knitr printed; `null` when the construct failed |
| `arm` | string or null | for a governed span, the role of the chosen arm as `arms()` names it (`one`, `other`, `zero`, `two`, `true`, `false`, `positive`, `negative`, `always`), or the arm's number as a string where `arms()` has no role; `null` when no arm was chosen and for other kinds |
| `rel` | string or null | the relation of the printed record (`=`, `<`, `>`); for a governed span, its governor's; `null` when there is no record (bare value, collapsed vector, date, text) |
| `raw` | number or null | D11 |
| `failed` | string or null | the failure kind (`failed claim`, `no value`, `value error`, `construct error`) in draft mode or a collection-file render; else `null` |
| `dict` | array of strings | the dictionary entries the expression names, written `dict$key` or `dict_local$key` (`dict[["key"]]` is written `dict$key`), unique, sorted; `[]` when none |
| `sentence` | string | D12 |

- **D9 — Expression.** For a value or a bare value, its inline R (the Quarto
  `{r}` prefix removed), parsed with `keep.source = FALSE` and deparsed with
  `width.cutoff = 500`, lines joined by one space, several expressions joined
  by `"; "`. So `` `r  mean( x )` `` and `` `r mean(x)` `` are `mean(x)`.
  For a governed span, the value of its key treated the same way; a
  back-reference (`#d`) and `.` are kept as written. For a `cite` span, the
  value of `cite` and the bracket text, each with runs of white space made
  one space, joined by `" | "`: `survey2020; review2021 | as reported`.
  Formatter classes, other keys and arm text are not part of it (7.1.4).
- **D10 — Section.** The anchor of the nearest heading above the construct,
  of any level, ATX or setext, outside code chunks, fenced blocks and front
  matter, in the text knitr reads (a child document's own file; under
  Quarto the document with its includes spliced in). The anchor is the
  heading's `{#id}` when it has one; otherwise Pandoc's identifier rule
  applied to the heading's source text with its inline code and attribute
  blocks removed: drop everything but letters, digits, `_`, `-`, `.` and
  white space; lower-case; trim; runs of white space to one `-`; drop everything
  before the first letter; `section` if nothing is left. A repeated anchor
  in one text takes `-1`, `-2`, … in order, as Pandoc does. Text above the
  first heading, and front matter, is in section `""`. A caption, a
  `weft_str()` string and text knitted from a string (`knit_child(text = )`)
  take the section of the line their chunk starts on, and the `file` of
  that chunk.
- **D11 — Raw value.** The value of the expression (for a governed span, of
  the governor), before any formatter or `unit=` conversion, with its unit
  dropped: when it is one finite number (double, integer, a year, a `units`
  value, or a `weft_text` with a numeric `raw` attribute), it is rounded to
  6 significant figures and written as `formatC(x, digits = 6, format =
  "g")` prints it (`0.823457`, `1500`, `1.23457e+06`, `1e-10`), zero as `0`.
  Anything else (a vector, text, a date, a logical, `NA`, `Inf`) is `null`.
  It ranks changes only (7.1.7); 4.4.23's picked rung is not stored.
- **D12 — Sentence.** The sentence of the rendered block that holds the
  construct's printed text (for a nested construct, its outermost
  construct's): from the end of the previous sentence (`.`, `?` or `!`
  followed by white space, or the start of the block) to the end of its own,
  white space made one space, markdown kept. In a table cell it is the cell;
  in a caption, the caption; in a front-matter field, the field; in a
  `weft_str()` string, the string. Over 400 characters it is cut at word
  boundaries to at most 200 characters either side of the printed text, each
  cut marked `…`. Every entry in one sentence carries the same sentence. It
  is for display (7.3.3) and plays no part in "changed".
- **D13 — Key and order.** An entry without an id is keyed on (`file`,
  `section`, `kind`, `expr`, `occ`); one with an id on (`id`, its occurrence
  among entries with that id). Lines after the header are sorted on
  (`file`, `section`, `kind`, `expr`, `occ`), comparing strings byte by byte
  (C locale) and `occ` as a number, ids or not, so the order is total and the
  same on every machine.
- **D14 — Changed (for 2e).** Two entries with the same key differ when
  `text` or `arm` differ (7.1.7); `null` and `""` differ.

### The condition log

- **D15 — Lines.** One line per distinct (`from`, `source`, `class`,
  `normalised`) among the conditions the knit logged, sorted on those four
  byte by byte. Fields in this order:

| Field | Value |
|---|---|
| `from` | `chunk` (the `evaluate` wrapper, and a replay from the chunk cache) or `prose` (a value in prose, a caption or front matter); 2e adds `target` |
| `source` | a labelled chunk: its label; an unlabelled chunk, or prose: `<file>#<section>` of where it sits (D10), `<file>` when the section is `""` |
| `class` | `warning`, `message` or `error` |
| `normalised` | rule 7.4.5 applied to `text` (stage 1's normaliser) |
| `text` | D16 |

- **D16 — Text.** The condition's message with ANSI styling removed and
  trailing new lines dropped; otherwise as raised. If the condition log on
  disk (the working tree, before this write) has a line with the same four
  key fields, that line's `text` is kept (7.4.6). Within one knit the first
  text seen is used. `text` and `normalised` over 1,000 characters are cut
  to 999 and `…` (the key is the cut form).
- **D17 — Left out.** A condition that matched the severity list (7.4.2) is
  a failure, not a log line. Line numbers are never written.
- **D18 — Reading the file on disk** for D16 is lenient: lines that are not
  JSON objects (merge-conflict markers) are skipped, a missing header is
  accepted, and with two lines of one key the first wins. A header with a
  version above 1 makes the file count as absent, and raises a
  `weft_ledger_warning` that it is rewritten as version 1.
- **D19 — New conditions (7.4.4).** After writing, the knit compares the log
  with the one at the comparison point: `git -C <root> show HEAD:./<path>`
  when `git` is on the path and the root is in a work tree (a path not in
  `HEAD`, or no commit yet, is an empty log); otherwise the file on disk
  before this write. Each line whose key is not there is new. When there are
  any, one message of class `weft_new_condition` (through `rlang::inform`)
  lists them: `weft: 2 new conditions since HEAD (rule 7.4.4)` (or `since
  the last render`), then one line each, `  <source>  <class>: <text>`. A new
  condition fails nothing, in any mode.

### When it is written

- **D20 — Who and when.** The `document` hook of the top-level knit writes
  both files, after the failure report has been decided: when the knit does
  not stop there. So: a clean knit writes; a draft-mode knit writes, failed
  constructs carrying `failed` (D8); a knit inside a Quarto project render
  with the collection file open writes (its output is written and the
  `post-render` script fails the render); a knit that stops on its failures
  (not draft, no collection file) writes nothing, because its output is not
  written either; a knit stopped earlier (a chunk error, a fatal construct
  error) writes nothing. `knit_exit()` ends the document: entries above it
  are written.
- **D21 — Not written** when the project is not set up, when
  `WEFT_REHEARSE=1` (so `rehearse()` writes neither), and for a child knit
  (its entries go in the parent's files with their own `file`). A source
  rendered on its own has its own files; as a child it has none.
- **D22 — Chunk cache.** Prose is resolved on every render (2.9.1), so its
  entries are always complete. A chunk computed with `cache=TRUE` also
  stores the ledger rows it recorded (its `weft_str()`
  strings) as `<cache hash>.weft-ledger.rds` beside the conditions stage 1
  stores there, and serving the chunk from the cache adds them, as the
  conditions are replayed. A render from the cache writes the same ledger as
  the render that filled it. A rehearsal uses no cache (1e).
- **D23 — Freeze.** A document served from Quarto's `freeze` is not knitted;
  its files are left as they are.
- **D24 — Several documents, several outputs.** Each source has its own
  directory and each output its own pair of files, so a book's chapters,
  and renders of one document to several outputs, never share a file. A
  render that overwrites an output overwrites its pair (7.1.3). Files whose
  source or output no longer exists are left (G21).
- **D25 — Concurrent renders.** Each write is a whole file renamed into
  place (D6): a reader never sees half a file, and of two renders of the same
  output the later rename wins. Renders of different outputs touch
  different files.
- **D26 — Write failures.** A file that cannot be written (no permission, a
  file where the directory should be) raises one `weft_ledger_warning`
  naming the path; the render carries on.

### Read back, and by whom

- **D27 — For 2e.** Internal, not exported:
  - `read_ledger(file = NULL, lines = NULL, lenient = FALSE)`: a data frame
    of class `c("weft_ledger", "data.frame")`, one row per entry in file
    order, columns as D8 (`occ` integer, `raw` double, `dict` a list of
    character vectors, JSON `null` as `NA`), attribute `header` (a list).
    `lines` takes the output of `git show`. Strict mode raises
    `weft_ledger_error` for a first line that is not a ledger header, a
    version above 1, or a line that is not a JSON object (the message names
    the line number).
  - `read_condition_log(file = NULL, lines = NULL, lenient = FALSE)`: the
    same, class `c("weft_condition_log", "data.frame")`, columns as D15.
  - `ledger_paths(root, source, output)`: `c(ledger = , conditions = )`,
    relative to the root.
  - `heading_anchors(lines)`: a data frame `line`, `anchor` for a text's
    headings (D10).
  - `expr_key(code)`: D9 for one piece of R code.
  - `git_show(root, path, rev = "HEAD")`: the file's lines at `rev`, or
    `NULL` (no git, no work tree, not in `rev`).
  - Two places 2e fills before the `document` hook writes: `s$ledger_header`
    (a named list added to the header after the four fixed fields, names
    sorted) and `s$condition_rows` (rows with D15's fields, `from =
    "target"`, merged before sorting).
- **D28 — `last_knit()`** gains four elements: `ledger` (the entries as
  `read_ledger()` returns them, without the attribute, for every top-level
  knit, set up or not), `condition_log` (likewise), `output` (the output
  name), and `written` (`c(ledger = , conditions = )`, the paths written
  relative to the root, `NA` each when nothing was written). `conditions`
  is unchanged.
- **D29 — Nothing new is exported.** `changes()` (2e) is the reader for
  people.
- **D30 — Dependencies.** `jsonlite` moves to Imports (R4): 2d reads JSON at
  every render in a set-up project (D16, D19). Writing is weft's own (G14).
  `git` is optional at render time (D19).

### Example

`reports/survey.qmd`, rendered to `survey.html`, in a project with
`_weft.yml`:

````markdown
```{r load}
d <- read.csv("survey.csv")
```

Of the `r n_sites` sites, [# was | # were]{n="n_dry"} dry.

## Water quality {#quality}

The mean ratio was `r ratio`{#ratio .num digits="2"}[, below the limit]{if="ratio < dict$limit"}.
Reach length was `r len`{unit="m|km"}.
````

`_weft/ledger/reports/survey.qmd/survey.jsonl`:

```
{"weft":"ledger","version":1,"source":"reports/survey.qmd","output":"survey"}
{"file":"reports/survey.qmd","section":"","kind":"bare","expr":"n_sites","occ":1,"id":null,"context":"prose","text":"14","arm":null,"rel":null,"raw":14,"failed":null,"dict":[],"sentence":"Of the 14 sites, 3 were dry."}
{"file":"reports/survey.qmd","section":"","kind":"n","expr":"n_dry","occ":1,"id":null,"context":"prose","text":"3 were","arm":"other","rel":"=","raw":3,"failed":null,"dict":[],"sentence":"Of the 14 sites, 3 were dry."}
{"file":"reports/survey.qmd","section":"quality","kind":"if","expr":"ratio < dict$limit","occ":1,"id":null,"context":"prose","text":", below the limit","arm":"always","rel":null,"raw":null,"failed":null,"dict":["dict$limit"],"sentence":"The mean ratio was 0.82, below the limit."}
{"file":"reports/survey.qmd","section":"quality","kind":"value","expr":"len","occ":1,"id":null,"context":"prose","text":"1.5\u00a0km","arm":null,"rel":"=","raw":1500,"failed":null,"dict":[],"sentence":"Reach length was 1.5\u00a0km."}
{"file":"reports/survey.qmd","section":"quality","kind":"value","expr":"ratio","occ":1,"id":"ratio","context":"prose","text":"0.82","arm":null,"rel":"=","raw":0.823457,"failed":null,"dict":[],"sentence":"The mean ratio was 0.82, below the limit."}
```

`_weft/ledger/reports/survey.qmd/survey.conditions.jsonl`, after a first
render that removed 12 rows and a second that removed 30:

```
{"weft":"conditions","version":1,"source":"reports/survey.qmd","output":"survey"}
{"from":"chunk","source":"load","class":"warning","normalised":"Removed <n> rows with missing values.","text":"Removed 12 rows with missing values."}
{"from":"prose","source":"reports/survey.qmd#quality","class":"warning","normalised":"NAs introduced by coercion","text":"NAs introduced by coercion"}
```

### Errors, warnings and messages

All errors carry `weft_error`. Messages end with the rule.

| Class | Kind | When |
|---|---|---|
| `weft_ledger_warning` | warning | Quarto `-o` with no `WEFT_OUTPUT` (D2); a file on disk of a later version (D18); a file that cannot be written (D26) |
| `weft_new_condition` | message | new conditions after a render (D19) |
| `weft_ledger_error` | error | `read_ledger()` / `read_condition_log()` in strict mode on a file that is not one, of a later version, or with a line that does not parse (D27) |

No ledger problem stops a render.

### Touches

New `R/ledger.R`. `R/resolve.R`: each construct row records `text`, `raw`,
`rel`, the arm's role, the sentence. `R/conditions.R`: `from` on each
logged condition; cached ledger rows stored and replayed (D22).
`R/hooks.R`: `finish_document()` writes after the report decision (D20).
`R/state.R`: D28. `DESCRIPTION`: `jsonlite` to Imports. Nothing the document
shows changes.

## Decisions

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| G1 | file format | JSON lines; CSV; YAML; RDS | JSON lines (the spec's) | one entry per line keeps a merge conflict to the entries both sides changed (7.1.5); escapes any text; holds the `dict` array; CSV quotes multi-line text badly and has no place for a header; YAML spreads an entry over lines, so diffs and conflicts are not local; RDS is binary and does not diff | the writer and the readers |
| G2 | location | `generated/ledger/` (spec); `.weft/ledger/`; `_weft/ledger/` | `_weft/ledger/` | weft's committed files already live in `_weft/` (schema, render scripts); Quarto ignores folders starting `_`; `generated/` is a common name for an author's own output folder; `.weft/` holds weft's transient files and reads as ignorable | one constant |
| G3 | granularity | one file per project; per source; per source and output | per source and output (spec) | parallel chapter renders never share a file; a render rewrites only its own | `ledger_paths()` |
| G4 | child documents | own files; the parent's, with `file` | the parent's | the knit, and so the output, is the parent's; a child knitted twice is two sets of entries | D21 |
| G5 | key | spec's four; plus `file`; ids required | spec's four plus `file` | a parent and its child, or an included file, can both have a section `methods`; the cost is that a paragraph moved between files shows as removed and added | D13 |
| G6 | section anchor | Pandoc's identifier from the rendered heading; ours from the source; line numbers | ours from the source (Pandoc's rule, inline code removed) | the key must not change with a value printed in a heading, and 7.1.4 forbids line numbers; equals Pandoc's id for a plain heading; renaming a heading re-keys its section, which `{#id}` prevents | `heading_anchors()` |
| G7 | the sentence (K3) | in the ledger; rebuilt by 2e from the source at the comparison point; a separate uncommitted file | in the ledger | 7.3.6 forbids rendering and the before-sentence exists only at the comparison point; rebuilding from the source needs the line numbers 7.1.4 forbids. Cost: editing a sentence's words, or another value in it, changes the line of every entry in it | drop the field (additive) |
| G8 | arm | index; role | role | adding a `zero` arm to `n` shifts indices but not roles; a one-arm `if` (`always`) that gains an empty arm becomes `true`, so a guard made optional shows (closes the first entry of `dev/open-findings.md`) | D8 |
| G9 | raw | the printed number; the expression's value; in SI base units | the expression's value, unit dropped | not moved by a formatter or a ladder (4.4.23 keeps the rung out of the ledger) | D11 |
| G10 | characters | ASCII with `\u` escapes (stage 1's writer); UTF-8 throughout; UTF-8 with invisible ones escaped | UTF-8, invisible characters escaped | the diff shows `35 m²` and `−4`, not `²`; a no-break space looks like a space, so it is shown as `\u00a0` | D3 |
| G11 | header | none; with time and versions; type, version, source, output | the last | a time or version would change the file at every render or upgrade; `version` lets a later weft change a field | D4 |
| G12 | empty fields | omitted; `null` | always present, `null` | every line has the same shape; a field appearing reads as a change of value | D8 |
| G13 | order | document order; key order | key order on the location tuple | moving a paragraph within a section moves no line; same order on every machine (C locale) | D13 |
| G14 | writer | `jsonlite::toJSON()`; weft's own | weft's own | byte-for-byte control of key order, number format and escapes, independent of `jsonlite`'s version | D3 |
| G15 | reader | `yaml` (as stage 1 reads `QUARTO_EXECUTE_INFO`); own parser; `jsonlite` | `jsonlite`, to Imports | YAML 1.1 reads `1e-10` as text and is fragile on escapes; a parser of our own is code to maintain; `jsonlite` has no system requirement | R4 |
| G16 | writes | in place; temporary file and rename; skip when unchanged | rename, and skip when unchanged | no half-written file under concurrent renders or a crash; an untouched file does not wake watchers or `quarto preview` | D6 |
| G17 | a render that stops on failures | write; write nothing | nothing, unless draft or collection file | the ledger follows the output (7.1.3), and such a render leaves the old output | D20 |
| G18 | output name | require a setting; frame lookup; source name only | `WEFT_OUTPUT`, then the frame's `output_file` (rmarkdown), then `output-file` (Quarto), then the source name | 7.1.3 needs it and only the frame holds it under rmarkdown; Quarto's `-o` hides it, so the variable is the only route there. Cost: the frame lookup reads an rmarkdown internal, pinned by a test | D2 |
| G19 | condition source, prose and unlabelled chunks | `file:line`; knitr's `unnamed-chunk-N`; `file#section` | `file#section` | a line number or `N` shifts with every edit above it, and every line of the log would change | D15 |
| G20 | sizes | cap all; cap nothing; cap display fields | cap `sentence` (400) and condition `text`/`normalised` (1,000); never `text` of an entry | a cap on `text` would hide a change (7.1.7); files are rewritten whole, so they grow only with the document; no rotation | D12, D16 |
| G21 | stale files | delete siblings; leave | leave | 2d cannot know whether another output still exists; 2e can list ledgers without a source | — |
| G22 | cached captions and strings | lost on a cached render; stored with the cache | stored and replayed | otherwise every cached render would show them removed | D22 |
| G23 | new-condition report | none in a render; against `HEAD` by `git`; against the last render | `HEAD` when `git` works, else the last render, and the message says which | 7.4.4 asks the render to report against the comparison point; a machine without git still gets a report | D19 |
| G24 | export | `read_ledger()` now; nothing | nothing | `changes()` is the reader for people; 2e decides | D29 |

## For Robin

Built as recommended until answered.

- **Q1 — `_weft/ledger/`, not `generated/ledger/`** (G2). Quarto ignores it
  and weft's other committed files are there. Alternative: the spec's
  folder. One constant either way, but it is a path users commit.
- **Q2 — The ledger stores the sentence** (G7, K3). `changes()` can then
  show "before and after" without rendering. Cost: rewording a sentence, or
  changing one value in it, changes the ledger line of every value in that
  sentence. Alternative: no sentence, and `changes()` shows only text and
  section.
- **Q3 — The key adds the file, and sections are weft's anchors from the
  source** (G5, G6). Renaming a heading re-keys its section (an explicit
  `{#id}` prevents it); moving a paragraph between files shows as removed
  and added.
- **Q4 — `quarto render -o` needs `WEFT_OUTPUT`** (G18). Without it the
  ledger is named after the source and the render warns. Alternative: no
  warning, and accept that `-o` renders share one ledger.
- **Q5 — `jsonlite` to Imports** (R4, G15), and **`git` called at render
  time** for the new-condition report (G23), optional.

## Tests

Three files. Documents are written by `render_rmd()` / `render_qmd()` of
`helper-render.R` into a temporary folder; a project is set up by
`files = list("_weft.yml" = "draft: false")`. A test that needs
`last_knit()` renders `in_process = TRUE`. Read files with
`readLines(p, encoding = "UTF-8")` and `jsonlite::fromJSON(line)` per line,
or `weft:::read_ledger(p)`. Paths below are relative to the test project.

**`test-ledger.R`**

- Not set up (no `_weft.yml`): no `_weft` folder after the render;
  `last_knit()$ledger` has the rows; `written` is `c(ledger = NA,
  conditions = NA)`.
- Set up, the example of this note as an `.Rmd` without the `load` chunk
  (`n_sites`, `n_dry`, `ratio`, `len <- u(1500, m)` set in the setup chunk;
  `dict.yml` with `limit` above 0.82): `_weft/ledger/doc.Rmd/doc.jsonl` and `doc.conditions.jsonl`
  exist and nothing else in that folder; the header line is exactly
  `{"weft":"ledger","version":1,"source":"doc.Rmd","output":"doc"}`; the
  entry lines equal the example's with `reports/survey.qmd` replaced by
  `doc.Rmd`, byte for byte, in that order; no `\r`, no BOM, final newline;
  `last_knit()$output` is `"doc"`; `written` names both paths;
  `last_knit()$ledger` equals `read_ledger()` of the file without the
  attribute.
- Field values, one construct each: a `sign` span (−2 → `negative`, `rel`
  `=`); a `list` span over three names (`other`, `raw` null); a `cite` span
  `[as reported]{cite="survey2020"}` with a `refs.bib` (expr
  `survey2020 | as reported`); a caption `fig.cap` construct (`context`
  `caption`, section of its chunk, sentence the caption); `weft_str()` in a
  chunk (`weft_str`); a `title:` construct (`front-matter`, section `""`);
  `.p` printing `< 0.001` (`rel` `<`).
- Expression: `` `r  mean( x )` `` and `` `r mean(x)` `` give one `expr`
  `mean(x)`, so `occ` 1 and 2; an expression over two lines; `{.num}`
  changed to `{.pct}` between two renders keeps every key field and changes
  `text`; `dict[["limit"]]` gives `dict` `["dict$limit"]`; `dict$b` and
  `dict$a` give `["dict$a","dict$b"]`.
- Occurrence and order: two `` `r x` `` in one section are `occ` 1, 2; in
  two sections each is 1; lines 2..n are sorted on (`file`, `section`,
  `kind`, `expr`, `occ`) in C locale; inserting a paragraph with a value in
  section B leaves every line of section A unchanged.
- Sections: `## Mean ratio, 2024` → `mean-ratio-2024`; `{#quality}` →
  `quality`; two `## Methods` → `methods`, `methods-1`; a setext heading; a
  `# comment` line inside a chunk is not a heading; `` ## Sites in `r yr` ``
  → `sites-in`; text above the first heading `""`. The same cases through
  `weft:::heading_anchors()` without a render.
- Raw: 0.8234567 → `0.823457`; 1234567 → `1.23457e+06` (as a JSON number);
  `u(1500, m)` printed with `unit="m|km"` → `raw` 1500 and `text`
  `1.5\u00a0km` (the escape in the file); `NA` → null with `failed` set in
  draft; `c(1, 2)` and `"a"` → null; an `if` → null; 0 → `0`.
- Characters: `−3` written with a literal U+2212; `"` and `\` escaped; a
  value printing a new line has `\n`; U+00A0 written `\u00a0`; `²` literal.
- Arms: `[# was | # were]{n="k"}` with 1 → `one`, with 3 → `other`; a
  one-arm `if` true → `always`, false → `arm` null and `text` `""`; the same
  `if` with an empty second arm, true → `true`; a value nested in the chosen
  arm has an entry, one in the other arm has none.
- Sentence: two values in one sentence carry the same sentence; a 600-character
  sentence is cut, contains the value's text, starts or ends with `…` and is at
  most 402 characters plus the length of the value's text; a table-cell value's sentence is the cell.
- When written: a failed claim in draft mode (`WEFT_DRAFT=1`) writes the
  entry with `text` null, `failed` `"failed claim"` and `raw` set; the same
  without draft mode stops the render and leaves both files byte-identical
  to a previous good render; a chunk error leaves them unchanged too; a
  second identical render does not rewrite the file (modification time
  unchanged after a 1.1 s sleep); no `.tmp` file is left.
- Outputs: one document rendered with `output_file = "site-a.md"`,
  `params = list(site = "a")` and then `"site-b.md"`, `site = "b"` gives
  `site-a.jsonl` and `site-b.jsonl` with their own text; rendering site-a
  again with `site = "c"` rewrites `site-a.jsonl` only. `format = "knit"`
  (plain `knit()`) names the output `doc`. `WEFT_OUTPUT=other` gives
  `other.jsonl`.
- Placement: a source in `reports/water.Rmd` under a root with `_weft.yml`
  gives `_weft/ledger/reports/water.Rmd/water.jsonl` and `file`
  `reports/water.Rmd`; a child `part.Rmd` (`child=`) puts its entries in the
  parent's ledger with `file` `part.Rmd`, and no `_weft/ledger/part.Rmd`;
  `knit_child(text = )` in a loop of three gives `occ` 1 to 3, the parent's
  `file`, and the section of the calling chunk.
- Cache: a `cache=TRUE` chunk with a `weft_str()` construct and a warning;
  the second render (served from the cache) writes byte-identical files.
- Rehearsal: `WEFT_REHEARSE=1` writes no `_weft/ledger`; `rehearse()` on a
  set-up project leaves the folder's file list unchanged.
- Versions and errors: an existing ledger with header version 2 is
  rewritten as version 1 with a `weft_ledger_warning`; `read_ledger()` on it
  (before the render) raises `weft_ledger_error`, as on a file whose first
  line is `{"weft":"conditions",...}` and on one with a line `<<<<<<< HEAD`
  (message names line 3); `read_ledger(lenient = TRUE)` on the last skips
  that line. A file at `_weft/ledger` (not a folder): the render succeeds and
  warns `weft_ledger_warning` (skip on Windows).
- Pinned internal: `rmarkdown::render()` has a local `output_file` during
  the knit (fails loudly if rmarkdown renames it).

**`test-condition-log.R`**

- Header exact; a document with no conditions writes the header alone.
- A warning in chunk `load` (`warning("Removed 12 rows")`): the line
  `{"from":"chunk","source":"load","class":"warning","normalised":"Removed <n> rows","text":"Removed 12 rows"}`.
  A message and an error under `error=TRUE`: classes `message`, `error`.
- An unlabelled chunk below `## Results` warns: `source` `doc.Rmd#results`;
  above any heading: `doc.Rmd`. A value in prose that warns:
  `from` `prose`, `source` `doc.Rmd#results`; no line number anywhere.
- A loop raising "Removed 1 rows", "Removed 2 rows", "Removed 3 rows": one
  line, text "Removed 1 rows".
- Carry-forward: render with 12, then with 5000: the file is byte-identical.
  A hand edit of `text` on disk to "Removed 7 rows" survives the next render.
  A reworded message adds a line and drops the old one. A file with conflict
  markers and two versions of one line: the render rewrites it clean, with
  one of the two texts.
- A message matching the severity list in draft mode is in
  `last_knit()$failures`, not in the log.
- ANSI styling is removed from `text`; a 3,000-character warning gives
  `text` and `normalised` of 1,000 characters ending `…`.
- Sorted on (`from`, `source`, `class`, `normalised`); a cached chunk's
  replayed warning keeps its line on the cached render.
- New conditions (skip without `git`): in a temporary repository with the
  log committed, a render adding a warning emits one `weft_new_condition`
  message naming "since HEAD" and the text, and a render with only committed
  conditions emits none; outside a repository the second render compares
  with the first ("since the last render"). Not set up: no message, no file.
- `last_knit()$condition_log` equals `read_condition_log()` of the file;
  `last_knit()$conditions` keeps its stage-1 columns and rows.

**`test-ledger-quarto.R`** (`skip_if_no_quarto()`)

- `render_qmd()` in a set-up folder: `_weft/ledger/doc.qmd/doc.jsonl`,
  source `doc.qmd`, output `doc`, `file` `doc.qmd`.
- `{{< include _part.qmd >}}` below `## Data`: the included values have
  `file` `_part.qmd` and section `data`, in `doc.jsonl`.
- `quarto render doc.qmd -o other.md`: the log of the render holds
  `WEFT_OUTPUT`, and `doc.jsonl` is written; with `WEFT_OUTPUT=other`,
  `other.jsonl` and no warning.
- `format: md` without `-o` names the output `doc` (checks that
  `output-file` is present for `md`). Two formats in one render (`html`,
  `md`) give one `doc.jsonl`.

**Superseded candidates**, for the test-writer to check: tests that list
every file of a set-up project after a render (`tree()` in
`helper-quarto.R`, the 1e snapshot) now see `_weft/ledger/`; tests that
read `DESCRIPTION`'s Imports.

## Where the spec is silent, wrong or contradicts the build

Each with the smallest change to `PACKAGE-SCOPING.md`.

1. **7.1.3, the place** (G2): `generated/ledger/` becomes `_weft/ledger/`,
   and the condition log is named `<output name>.conditions.jsonl`.
2. **7.1.3, the output name** is not knowable under `quarto render -o`.
   Add: "The output name is that of the output file; under Quarto's `-o`,
   which weft cannot see, it is the source's unless `WEFT_OUTPUT` names it."
3. **7.1.4, the key** (G5, G6, D10): add the file as a fifth part; define
   the anchor (heading `{#id}` or Pandoc's rule on the source text without
   inline code; `""` above the first heading and in front matter; a
   caption's, a string's and a child text's the section of its chunk); an
   id's key is the id with its occurrence; a `cite` span's expression is
   written `keys | bracket text`.
4. **7.1.1 with 7.3.3 (K3)**: add to the entry its sentence as printed and
   the dictionary entries its expression names; say the arm is recorded by
   its role, and the raw value is the expression's before any formatter or
   unit conversion. 4.4.23's "the ledger holds nothing of it" stands.
5. **7.1.5**: "sorted by key" becomes "sorted on file, section, kind,
   expression and occurrence", which places entries with ids too.
6. **When the ledger is written** is silent: add to 7.1.3 "It is written
   when the knit reaches the end of the document and its output is written:
   in draft mode, with each failed construct marked; not by a render that
   stops on its failures." 9.4.2 gains the same clause.
7. **2.9.1 / 7.4.1**: a cached chunk replays the constructs it recorded into
   the ledger, as it replays its conditions.
8. **7.4.5 against 2.8.2**: the source of a condition from prose, or from an
   unlabelled chunk, is its file and section in the log; 2.8.2's line stays
   in the knit's own records. Add that sentence to 7.4.5.
9. **7.4.4**: "an ordinary render reports it" needs the comparison point at
   render time. Add: "against `HEAD` when git is available, else against the
   log of the previous render, and the report says which."
10. **7.4.6**: add "from the log in the working tree"; and the 1,000-character
    cap.
11. **`dev/open-findings.md`**, first open entry (a guard made optional): a
    one-arm `if` is recorded with the role `always` and a two-arm one with
    `true`, so the change shows in the ledger and in `changes()`. Delete the
    entry once 2d is built. (`arms()` calls the single arm of an `if`
    "always" though it prints only when true; harmless, and left.)
12. **`dev/design-2.md` §4, 2d** says `generated/ledger/`, and its open
    points (1)–(6) are answered here: (1) D10; (2) D2; (3) D12, G7; (4) D3–D15;
    (5) D30; (6) D16. Point to this note.

## Rulings on the test-writer's report

- **D8, a one-arm `if` that is false** is a failed claim, so D8's row
  for a failed construct governs: in draft mode `text` is `null`, `arm`
  is `null` and `failed` is `failed claim`. The Tests section's "false →
  `arm` null and `text` `""`" was wrong; `""` is the text of a governed
  span that chose an empty arm.
- **D8, `rel` of a `list` span** is `null` (a collapsed vector has no
  record).
- **D10, a construct inside a heading** takes that heading's anchor.
- **D19, one new condition** is worded `weft: 1 new condition since …`.
- **D19, outside a repository with no log on disk yet**: there is no
  earlier render to compare with, so no message. Inside a repository a
  path not in `HEAD` is an empty log and every line is new, as D19
  says.
- **Not tested, accepted for this round**: D20's collection-file case,
  D23, D25, a nested `render()`, and D26's no-permission case. The
  reviewer is asked to try them.

## Rulings on the implementer's report

- Six tests in `test-ledger.R` were test faults and were corrected by
  the test-writer (an integer compared as a double, a wrong count, a
  regex that could not match, a quoted expression not in its deparsed
  form, a chunk error that plain `knit()` captures). A bare `NA` is not
  a failure: its entry has `text` "NA", `raw` null, `failed` null.
- **D2**: under Quarto, `QUARTO_EXECUTE_INFO` is read before the
  `render()` frame, because Quarto's engine runs inside its own
  `rmarkdown::render()`. Accepted; D2's order is (1), then (3) under
  Quarto, else (2), then (4).
- **D8**: an unknown `cite` key is recorded as `value error`; `arm` is
  null for every failed construct; `raw` is set for a failed claim.
  Accepted.
- **D28**: `written` names the paths when the bytes were unchanged and
  the write was skipped. Accepted.
- Whole suite after the build: 2,197 tests, none failing, none skipped.

## Rulings on the review of 2d (`dev/review-2d.md`)

Findings 1 to 11 are accepted as the reviewer states them, with these
particulars:

- **1.** A render started inside a chunk is its own top-level knit: it
  writes its own files, and when it ends the outer knit's state is as
  it was, so the outer ledger and condition log are complete.
- **2.** The source is the file that was knitted. An `.Rmd` is mapped
  to a `.qmd` only when Quarto is running the knit.
- **3.** Nothing is written through a symbolic link: when `_weft`,
  `_weft/ledger`, the source's folder under it, or either file is a
  link, neither file is written and one `weft_ledger_warning` names
  the link (as 2c's tools refuse).
- **4, 5.** Accepted. A condition-log line on disk without a usable
  `text` is skipped, as other unreadable lines are (D18).
- **6.** `raw` for an `integer64` is its value when a double holds it
  exactly, else `null`.
- **7.** Under Quarto with no `output-file`, the warning is raised
  unless the format is one Quarto gives no `output-file` for (`gfm`,
  `typst`); for those the source's name is used quietly.
- **8, 9.** A heading inside an HTML comment, or an ATX heading with no
  blank line before it, is not a heading. An explicit `{#id}` is kept
  as written, repeated or not.
- **10.** One `weft_ledger_warning` with the reason; no other warning
  escapes.
- **11.** Under `rmarkdown::render()` the source is the file the author
  named, read from the same frame D2 reads, not rmarkdown's copy.

Questions:

- **A.** Before the identifier rule, link and image targets, footnote
  references, raw HTML tags and emphasis markers are dropped from the
  heading's text.
- **B.** A `.` followed by white space and a lower-case letter or a
  digit does not end a sentence, nor does one after `e.g`, `i.e`, `cf`,
  `al`, `Mr`, `Mrs`, `Ms`, `Dr`, `Fig`, `approx`, `vs`.
- **C.** In `sentence`, a failure marker is written without its line
  number (`<<weft: failed claim>>`).
- **D.** U+0085, U+061C, U+202A to U+202E and U+2066 to U+2069 join the
  characters written as escapes (D3).
- **E.** When the condition log is not tracked by git (ignored, or no
  commit holds it), the comparison is with the last render, and the
  message says so.
- **F.** In a session whose locale is not UTF-8 nothing is written and
  one `weft_ledger_warning` names the locale.
- **G.** `WEFT_OUTPUT` loses its extension and any folder, as the other
  sources of the name do.
- **H.** An output name ending `.conditions` is refused: nothing is
  written and one `weft_ledger_warning` says why.
- **I.** A footnote's definition marker is not part of its sentence.
- **J.** D22 is corrected: stage 1 refuses a caption construct in a
  cached chunk, so only `weft_str()` rows are stored and replayed.
- Two renders of one output at the same moment were not run by the
  reviewer either; filed in `dev/open-findings.md`.

## Ruling on D12: sentences by `stringi` (decision 57)

Replaces D12's boundary rule and ruling B's abbreviation list. The rest
of D12 stands (a table cell, a caption, a front-matter field and a
`weft_str()` string are each one sentence; white space made one space;
markdown kept; the cut at 400 characters).

The sentence is cut from the block of knitted markdown that holds the
construct's text. Block markers are not part of it: a list marker
(`-`, `1.`, `(a)`), a block-quote `>`, a heading's `#`, a line block's
`|`, a footnote definition's `[^1]:`, a div fence `:::`.

1. **Masking.** Boundaries are found on a copy of the block, of the
   same length, in which what is not prose is replaced so that its
   punctuation cannot end a sentence. Measured: ICU otherwise cuts
   inside `` `x.y(). Z` ``, `$p < 0.05. Q$`, a link's text and target,
   an inline footnote, an attribute block and an HTML tag.
   - Replaced by letters: inline code; inline math (`$…$`, `\(…\)`);
     the target of a link or image (`](…)`, `][ref]`), an autolink;
     a raw HTML tag; an attribute block (`{…}` after `]`, `)` or a
     code span); a shortcode (`{{< … >}}`); a citation (`[@key, p. 4;
     @other]`, `@key`, `-@key`) and a cross-reference (`@fig-x`,
     `\@ref(fig:x)`), keys with full stops included; an inline
     footnote (`^[…]`), unless the construct is inside it, when the
     footnote's text is the block.
   - Replaced by closing brackets, so that a boundary falls after
     them: emphasis and strike-out markers (`*`, `**`, `_`, `~~`) and
     a footnote reference (`[^1]`). So "**Note.** The value was 5."
     is cut after `**`, and "…was 7.2.[^1] Then" after `[^1]`.
2. **ICU.** `stringi::stri_locate_all_boundaries(type = "sentence")`
   on the masked copy, locale the document's `lang` (`en` when unset,
   `en-AU` passed as `en_AU`) with `@ss=standard`.
3. **Boundaries dropped** after ICU:
   - before a lower-case letter or a digit;
   - inside square brackets that close later in the block (a link's or
     a span's text);
   - after a single capital letter and its full stop (initials:
     "J. R. Smith", "E. Coli");
   - after one of weft's abbreviations, as a whole word: in any
     language `e.g.`, `i.e.`, `cf.`, `ca.`, `viz.`, `vs.`, `et al.`;
     in English also `Dr.`, `St.`, `No.`, `Nos.`, `Vol.`, `approx.`,
     `est.`, `incl.`, `excl.`. Not `etc.`, which often ends a
     sentence; not `Fig.`, `Eq.`, `Tab.`, `Ch.`, `Sec.`, which a
     cross-reference writes in a Quarto document.

Left as ICU gives them: "U.S. E.P.A." is cut after "U.S."; "9 a.m.
Rain" is cut; a Unicode ellipsis before a capital is not a boundary.
`stringi` joins Imports.

### Rulings on the build of the D12 ruling

- A masked span is filled as a capital then lower-case letters, because
  ICU does not end a sentence after an all-capital word.
- Block markers are blanked in the masked copy and the end of each is a
  forced sentence start, so list items stay apart. A table row's `|` is
  left to the table-cell rule.
- Brackets "close later" when any `]` follows the boundary in the
  block.
- Abbreviations are matched without regard to case, except `Dr`, `St`,
  `No`, `Nos` and `Vol`.
- An unknown `lang` falls back to `en`.
- The test that proved the locale with "M. Dupont" was a test fault
  (an initial is kept in any language); it now uses `janv.`, which
  ICU keeps whole in French and cuts after in English.
- Cost: about 0.9 ms an entry, twice the old rule.
