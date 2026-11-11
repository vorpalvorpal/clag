# Stage 1c — internal contract

Built straight after the kernel, ahead of 1b (`dev/decisions.md` entry 19).
`dev/design-1a.md` still holds for everything it says; this note adds to it.
Where this note and a numbered rule disagree, the rule wins.

## Scope

1. Captions in chunk options (rules 1.10.1–1.10.4, 1.10.6, 2.1.1 rows
   `opts_hooks` and `chunk`, 2.1.4, 2.3.1–2.3.5).
2. `weft_str()` (1.10.10, 3.6, 2.6.8 for its marker, 2.4.1).
3. Constructs in front-matter fields and in a late metadata block
   (1.10.7–1.10.9, 1.10.11, 2.10.6 for the scanner).
4. The scanner over those three places (2.10.2): `scan_file()` returns their
   constructs too.
5. The trial bugs listed at the end.

NOT in this stage: `.Rprofile` activation and `use_setup()` (§22 holds them
for Q2), and everything of 1b (`sign`, ids, `.p`, `.range`, `.cap`, `.a`,
`lookup()`, `brk()`, `cite`, `.weft-literal`), 1d and 1e. Those names still
give the "not built yet" construct error.

## Interfaces

### `weft_str(x)` (exported)

`x` is a character vector of markup; each element is resolved as a prose
block and the same-length character vector is returned (markdown text). It
is evaluated in the caller's environment (`parent.frame()`).

- During a knit, failures are collected (2.4.1, 3.6.3) with the marker naming
  the chunk: `<<weft: failed claim, chunk fig-depth>>` (2.6.8). The record's
  `line` is `NA` and its `chunk` is the current chunk label.
- Outside a knit, a failed check, a missing value, a value error and a
  construct error each stop at once with their class (`weft_claim_failed`,
  `weft_no_value`, `weft_value_error`, `weft_construct_error`).
- A construct error in the string stops the render as one in prose does
  (2.6.5), named by chunk; in draft mode it is a marker.
- It works with no hooks installed (it does not need `weft_setup()`), and
  then behaves as "outside a knit" does.
- Block-only constructs do not apply; the result of each element is inline
  markdown.

### Captions

- The caption options are `fig.cap`, `fig.alt`, `fig.scap`, `fig.subcap`,
  `tbl-cap` (and the names Quarto hands knitr for `fig-cap`, `fig-alt`,
  `fig-subcap`, `tbl-cap`; find them by experiment and pin them in a test).
- A caption with no construct and no parked inline R is left exactly as
  stock leaves it (stock parity).
- A failure in a caption is recorded with `chunk` = the label and the option
  named in `detail`; the report locates it "chunk <label>, <option>"
  (2.3.2, 2.6.2). Its marker is `<<weft: failed claim, chunk <label>>>`.
- Static errors (found when the knit is initialised, from `scan_file()`):
  a caption with a construct that is not a YAML block scalar in a `#|`
  option (1.10.3); a construct in the caption of a chunk with `cache: true`
  (chunk or document level), `eval: false` or a non-R engine (2.3.5); a
  construct in `tab.cap`, or under `!expr` in `fig-subcap` (1.10.4). Under
  rmarkdown a caption written in the chunk header (`fig.cap="..."`) is an R
  string, and a construct in it is legal when the string is a plain literal.

### Front matter

- Fields: `title`, `subtitle`, `abstract`, `description`, in the first YAML
  block and in any later metadata block (1.10.9). Block scalars only
  (1.10.7); a construct in another form of scalar is a construct error found
  when the knit is initialised.
- Bare inline R in any field keeps stock behaviour (1.1.8).
- A construct in `title` in a book or website project is a construct error
  (1.10.11); "book or website" is read from `_quarto.yml` `project: type:`.
- Positions point into the YAML (the line in the file).
- Front-matter constructs need activation that is early enough: the
  front-matter route (9.2.1). With setup-chunk activation the first block is
  not processed (9.2.5) and the end-of-document check reports the construct.

### `scan_file(path)` additions

A new column `context`: `"prose"`, `"caption"`, `"front-matter"`,
`"weft_str"`. For a caption, `chunk` holds the label and `option` the option
name; `line` is the line in the file where the construct sits. A literal
string passed to `weft_str()` in chunk code is scanned (3.6.2, 2.10.2):
`context = "weft_str"`, `chunk` the label, `line` the line of the string's
start in the file. `scan_text()` is unchanged.

## Trial bugs to fix in this stage (from `dev/field-notes.md`)

1. A construct left raw must never pass silently. In a single document
   (no `weft-check` filter), a construct in a caption option, a front-matter
   field or `results: asis` output that the hooks did not resolve is caught:
   captions and front matter by this stage's code; anything else by the
   end-of-document check where the scanner can see it. `results: asis` text
   is built in R and cannot be seen; rule 1.10.10 says it goes through
   `weft_str()`. Document that; no code.
2. A span broken by a blank line (`[a\n\nb]{if="x"}`) leaks `]{if=...}` into
   the output with exit 0. A `]{...}` holding a weft key, with no opening
   bracket in its paragraph, is a construct error ("the span is split by a
   blank line").
3. `claim(vec, . > 0)` where the check returns a vector: the message says
   the check returned N values and suggests `all()`.
4. A failed check in chunk code is reported with its chunk AND the check as
   written and the value (2.6.2), one entry per check; a Date or factor
   value is shown as `format()` prints it, not as `structure(...)`.
5. An `#id` on a value or a governed span is a "not built yet" construct
   error until 1b builds ids (it was silently accepted).
6. `if="x == \"a\""` reports the quoting rule (1.2.3), not "spaces around =".
7. A report line for a failed guard gives the phrase and each failing
   condition as written (2.6.3).
8. The post-render report prints text unescaped (no `\"`), and keeps two
   findings with no line as two entries.
9. The pre-render message does not name `use_setup()` while it is unbuilt;
   it says to add `engine: knitr` to the file's front matter.
10. A chunk with no label is located by "the chunk at line N" as well as
    knitr's generated label.

## Rulings on the implementer's report

- Bare inline R in a caption is left exactly as stock leaves it (rule
  1.1.8): literal text. Only constructs are resolved in a caption. (The
  first build evaluated it; to be corrected in the review round.)
- A construct in a front-matter field other than the four of 1.10.7 is a
  construct error found from the source.
- The `chunk` wrapper is installed from the first option hook of any chunk
  (the `label` option), not only from a caption hook, because Quarto
  forwards a `NULL` `tbl-cap` whether or not the document has captions.
  Rule 2.1.4 already says "from the first call of an option hook".

## Rulings on the review of stage 1c and the Quarto side (`dev/review-1c.md`)

Findings 1 to 18 are accepted as the reviewer states them; 19 (cosmetic) is
left. On the lettered items:

- **A.** A construct in `kable(caption = )` or any other string in R code is
  not weft's unless it goes through `weft_str()` (1.10.10). Left; recorded
  in `dev/open-findings.md` for a stage-3 lint.
- **B.** The freeze notice counts constructs, and says so: "N constructs
  were not checked".
- **C.** The filter looks for `<<weft:` in a code block that is chunk output
  (a block with no language class, or with a `cell-output` class), and not
  in a fenced block that carries a language class (```` ```markdown ````).
- **D.** A filter finding has no line. The report keys filter findings by
  file, kind and text, never merges two different texts, and drops a filter
  finding only when it is a `<<weft:` marker that a knit record already
  explains (same file, kind and line).
- **E.** Bare inline R in a `weft_str()` string is evaluated: the string is
  markup, and there is no stock behaviour for it to keep.
- **F.** A caption with a construct on a chunk whose cache is on at run
  time (however it was set) is a construct error raised by the option hook,
  with the remedy of 2.3.5 (write the caption in a figure or table div).
- **G.** `use_quarto(path)` walks up from `path` to the directory that holds
  `_quarto.yml` and says which directory it took.
- **Computed captions (finding on `fig.cap = paste0(...)`).** Only a caption
  written as a literal in the source is resolved. A caption computed by R
  code is data and is printed as it is (2.2.4); it goes through
  `weft_str()` if it holds markup.
- **`use_quarto()` and `_quarto.yml` (finding 1).** The file is edited as
  text, line by line, and never rewritten from parsed YAML. When the edit
  cannot be made safely the function stops and prints the lines to add by
  hand.
- **A stale collection file (finding 5).** The pre-render script writes the
  run id into the collection file's first line; a knit or filter that finds
  a collection file whose run is not the one in `.weft/run`, or that is
  older than an hour with no `.weft/run`, ignores it. A plain
  `rmarkdown::render()` or single-file render outside a project render
  never uses a collection file left by another run.
- **A frozen document with no stamp (finding 6).** Reported in the freeze
  notice as "never checked on this machine", and it fails `verify()` later
  (2.9.3); an ordinary render does not fail on it.

## Rulings on the fixer's report for the review of stage 1c

- The `computed` case of the first test in `test-trial-bugs.R` is dropped:
  it predates the "computed captions" ruling above and contradicts it.
- A caption set through `opts_chunk$set()` is a character value and counts
  as literal, so it is resolved.
- A knit is in a project render only when `QUARTO_EXECUTE_INFO` is set;
  otherwise a collection file found by existence is ignored.
  `WEFT_COLLECT` is always used as given.
- Left open (in `dev/open-findings.md`): the prose scan reads the code
  lines of a block-quoted chunk as prose; the filter still uses a stale
  collection file that is empty and has no run id; `.weft/` is not added
  to `.gitignore` by `use_quarto()`.
