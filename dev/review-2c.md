# Review of package 2c — dictionary tooling

Snapshot: the code of `c440a72` ("Add the dictionary tooling (2c)"),
exported to a plain folder and loaded with `devtools::load_all()`. Every
case below was run against that snapshot; `<tmp>` stands for a temporary
project folder. Knits are `rmarkdown::render()` of an `.Rmd` whose setup chunk
calls `weft::weft_setup()`, with `WEFT_DRAFT=1`, to `html_document` and to
`pdf_document` (pdflatex). The schema was checked with an independent
validator: `ruamel.yaml` (YAML 1.2, as an editor reads the file) and Python
`jsonschema` (`Draft7Validator`), not the package's own test helper. Vale is
not installed: its matching was emulated with Go's `regexp` (RE2, the engine
Vale uses) and the word template Vale documents for `substitution` rules,
`\b(?:<keys>)\b`. No network request was made: the resolver was run with stub
`fetch` functions, and `github_fetch()` only against a closed port on
127.0.0.1.

## Findings

**1. `use_dictionary()` writes through a symlink, so it can overwrite a file it
never named.**
Severity: data loss or unannounced write.
- `<tmp>/_weft/dict.schema.json` is a symlink to `<tmp>/other.json`, which
  holds `{"mine":1}`. `use_dictionary("<tmp>")` prints
  `_weft/dict.schema.json  (exists: replaced by the schema of this version of weft)`
  and `Wrote: dict.yml, _weft/dict.schema.json`. Afterwards `other.json`
  holds weft's schema: its first lines are `{` and
  `  "$schema": "http://json-schema.org/draft-07/schema#",`. Its own content
  is gone, and the messages never named it.
- `<tmp>/dict.yml` is a dangling symlink to `<tmp>/nowhere.yml`.
  `file.exists()` is `FALSE`, so the message says `dict.yml  (new: …)`, and
  `file.copy()` creates `nowhere.yml`, the link's target, which can be outside
  the project.
- Expected: weft announces every file it writes (P10). A symlink at either
  path should be refused, or the message should name the target.
- Cause: `use_dictionary()` (`R/dict-tools.R`) tests with `file.exists()` and
  writes with `file.copy(..., overwrite = TRUE)`, and both follow links.

**2. `use_dictionary()` reports files as written when nothing was written.**
Severity: silent wrong output.
- Read-only folder (`Sys.chmod(d, "555")`): the three "will write" lines, two
  R warnings (`cannot create file …, reason 'Permission denied'`), then
  `Wrote: dict.yml, _weft/dict.schema.json`. It returns
  `c("dict.yml", "_weft/dict.schema.json")`, and the folder is empty.
- `_weft/` is read-only: `Wrote: dict.yml, _weft/dict.schema.json`, but only
  `dict.yml` exists.
- `_weft` is a regular file: the same `Wrote:` line, then the warning `cannot
  create file …/_weft/dict.schema.json, reason 'Not a directory'`. No schema
  is written.
- Under `suppressMessages()` (C7's way of silencing it) only the base
  warnings are left. The return value still claims both files.
- Expected: a `weft_tool_error` naming the file that could not be written,
  and never `Wrote:` for a file that does not exist.
- Cause: `use_dictionary()` ignores the return values of `file.copy()` and
  `dir.create()`.

**3. A Vale rule that starts or ends with punctuation never fires.**
Severity: silent wrong output.
- `avoid: ['approx.', 'e.g.', '(v2) code', 'say "x"', '- dash', '{brace}', '[sq]', '`tick`']`
  (each made a valid entry). `dict_vale()` writes the keys correctly escaped
  (`'approx\.'`, `'e\.g\.'`, `'\(v2\) code'`, …), and both `ruamel.yaml` and
  R's `yaml` read the file. Vale wraps the swap keys in `\b(?:…)\b` unless
  the rule sets `nonword: true`. Matching each key that way in RE2:
  - `"It is approx. 5 m."` matches nothing.
  - `"Use e.g. this."` matches nothing.
  - `"The (v2) code runs."` matches nothing.
  - `"We say \"x\" here."` matches nothing.
  - The same holds for the dash, brace, bracket and backtick spellings.
  - Controls: `"see Nth. catchment"` matches `Nth\. catchment`, and
    `"it is #1 now"` matches `it is #1`.
- So any spelling that begins or ends with a character that is not a word
  character never matches. `read_dict()` accepts these spellings, and
  `dict_vale()` counts them in "a Vale substitution rule with 22 avoided
  spelling(s)". Nothing tells the author that some of them are dead.
- The conflict check has the same mismatch: `word_in()` (`R/dict.R`) treats
  any non-alphanumeric character as a boundary, while Vale's `\b` does not.
- Expected: either the rule matches these spellings (`nonword: true` with
  boundaries written into each key), or `read_dict()` refuses a spelling Vale
  cannot match.
- Caveat: Vale itself was not run. The template comes from Vale's
  documentation of `nonword`.
- Cause: `dict_vale()` and `vale_escape()`, `R/dict-tools.R`.

**4. The glob resolver reports "does not resolve" for every pointer when the
project path holds `[` or `]`.**
Severity: silent wrong output (`FALSE` fails `verify()`, 4.5.2).
- Project `<tmp>/proj[1]`, file `decisions/12-core.md`, `decision: 12`,
  `decisions: decisions/{id}-*.md` gives
  `12  FALSE  no file matches decisions/12-*.md`. The same project at
  `<tmp>/proj*` or `<tmp>/proj{a,b}` gives `TRUE decisions/12-core.md`.
- A folder named like `Survey [2024]` is ordinary on OneDrive and Windows
  shares.
- C28 says "unresolved" must mean the record is missing. Here the record is
  present.
- Expected: `TRUE`, because only the pattern after the root is a glob.
- Cause: `decisions_glob()` (`R/decisions.R`) calls
  `Sys.glob(file.path(root, pat))`, so the root's characters are read as
  pattern characters.

**5. In a knit, the glossary swallows the paragraph after its chunk.**
Severity: silent wrong output.
- `.Rmd`: ` ```{r}`, `dict_glossary()`, ` ``` `, then `After.` on the next
  line with no blank line between. HTML:
  `<dt><code>start</code> (1 June 2024)</dt><dd>Start. After.</dd>`. The
  paragraph has become part of the last definition (a Pandoc lazy
  continuation).
- The contract adds a leading `"\n"` so that text directly above the chunk
  is kept apart. Nothing does the same for text directly below.
- Expected: a separate paragraph `After.`, so the string should end `"\n\n"`.
- Cause: `dict_glossary()`, `R/dict-tools.R`. The final `paste0(…, "\n")`.

**6. A `term` written as a YAML block scalar breaks its glossary entry and puts
a trailing space in the Vale rule.**
Severity: silent wrong output.
- `term: >` followed by `minimum` and `sample size` reads as
  `"minimum sample size\n"`. `read_dict()` accepts it, because `str1()` only
  asks for a non-blank string. The glossary string is
  `"\nminimum sample size\n (5)\n:   d\n\n…"`, which Pandoc renders as
  `<p>minimum sample size (5) : d</p>`, outside the `<dl>`.
- With `avoid: [min size]`, `dict_vale()` writes
  `'min size': 'minimum sample size` plus a newline and `'` at column 0. That
  is valid YAML and reads back as `"minimum sample size "`: Vale would suggest
  a trailing space.
- A `term` with surrounding spaces (`'sample size '`) is kept as written. With
  `avoid: [sample size]` the problem reported is "`avoid` lists `sample size`,
  which is part of the spelling `sample size ` of `a`". That should be the
  own-spelling row, and the glossary and Vale both get the space.
- A multi-line `string` value used as the canonical spelling (no `term`)
  gives the Vale value `'Northern\ncatchment\n'` in the same way.
- Expected: `term` trimmed and white space collapsed as the glossary does for
  definitions (or a newline refused), and the same for a string canonical in
  `vale_swaps()`.
- Cause: `build_dict()` (`R/dict.R`) keeps `e[["term"]]` untrimmed.
  `dict_glossary()` applies `one_line()` to values and definitions but not to
  `term`. `vale_swaps()` uses the raw canonical.

**7. Some `decision:` numbers are mangled or silently dropped before the
resolver sees them.**
Severity: silent wrong output.
- `decision: 012` stores the pointer `"012"`. Under `github:o/r` the row is
  `FALSE`, "`` `012` is not an issue number; the github resolver takes whole
  numbers (rule 4.5.3) ``", with no request. An editor (YAML 1.2) reads `012`
  as 12, and the schema accepts it. `value: 012` is refused as "a whole number
  written with a leading zero". `decision:` is not.
- `decision: 0x1F` stores `"0x1F"` in the same way.
- `decision: 99999999999` gives only R's warning `NAs introduced by coercion
  to integer range`. The entry's `decision` becomes `NA`, and
  `check_decisions()` returns no row for it: the pointer is gone.
- `decision: 1e3` stores `"1e3"`, which is `FALSE` under `github`. The
  schema reads it as the integer 1000.
- Expected: a leading-zero, hex or octal `decision` is a problem, as for
  `value`. A number past the integer range is kept as text or refused, never
  dropped.
- Cause: `build_dict()`, the `decision` branch (`R/dict.R`):
  `as.character(as.integer(d))`, and the `int#oct`/`int#hex` handlers that
  keep the text, which `str1()` then accepts.

**8. The schema refuses dictionaries that `read_dict()` reads, beyond E1 and E2.**
Severity: contract mismatch ("Schema never refuses what `read_dict()` reads,
except E1, E2").
Each case was read by `read_dict()` without a problem and refused by the
draft-07 validator:
- An empty or null optional field: `term:`, `avoid:`, `display:` on a
  quantity, `decision:`, `unit: ~` on a `number`, `display:` on a `number`,
  and `why:` in `dict.yml`. `read_dict()` treats each as absent. The schema
  says `None is not of type 'string'`, `False schema does not allow None`, or
  `Additional properties are not allowed ('why' was unexpected)`.
- A one-item flow list where text is wanted: `definition: [d]`,
  `term: [the a]`, `decision: [12]`, `unit: [m]`, `display: [cm]` and
  `value: [5]` under `number`. R's YAML reads a one-item sequence as a
  length-1 vector. The entries read as `term = "the a"`, `decision = "12"`,
  `b` = `500 [cm]`. The schema refuses each with `is not of type 'string'`.
- A definition that is only a no-break space (`definition: "\u00a0"`).
  `trimws()` keeps it, but JSON Schema's `\S` is Unicode-aware. The
  glossary then prints `:    ` with an empty definition.
- The opposite direction (`read_dict()` refuses, schema accepts), for
  instance `'05'`, `'2014.5'` as a year, `-.inf` and two unbounded bands, is
  allowed by the contract.
- Expected: either `read_dict()` refuses these (the null `why:` in
  `dict.yml` and the list forms are slips), or the contract lists them as
  exceptions.
- Cause: `build_dict()` uses `is.null(e[[f]])` for absence and accepts length-1
  vectors (`str1()`). Neither is mirrored in `inst/dict/dict.schema.json`.

**9. `dict_vale()` given any other dictionary deletes the project's rule.**
Severity: wrong output (removes a file the call did not concern).
- In a project whose rule `styles/Weft/Terms.yml` was generated from
  `dict.yml`, running `dict_vale(read_dict("other.yml"))`, where `other.yml`
  has no `avoid`, prints
  `weft will remove <tmp>/styles/Weft/Terms.yml: other.yml has no avoid:
  spellings now.` and then `Removed: …`. A chapter's `dict_local` (which may
  never hold `avoid`) does the same. So does a dictionary file with another
  name, which rewrites the rule with the header
  `# Generated by weft::dict_vale() from proj-terms.yml`.
- The header records which dictionary wrote the rule, but nothing compares
  it before replacing or removing.
- The second header line always says `dict.yml`, whatever the file is called.
- Expected: replace or remove only a rule generated from the same dictionary
  file (or refuse a `dict_local`, whose `avoid` is always empty).
- Cause: `dict_vale()`, `generated()` (`R/dict-tools.R`).

**10. `check_decisions()` stops when `fetch` throws or returns something
malformed.**
Severity: crash (contract: "`check_decisions()` raises nothing for a pointer:
every outcome is a row").
- `fetch` that calls `stop("boom …")`: the error comes straight out of
  `check_decisions()`, with its text unchanged. In the stub that text held
  the token.
- `fetch` returning `list(error = NULL)` (no status) fails with `argument is
  of length zero`. Returning `list(status = c(200L, 404L))` fails with `the
  condition has length > 1`. Returning a bare `200L` fails with `$ operator
  is invalid for atomic vectors`.
- `github_fetch()` catches errors only around `curl_fetch_memory()`. The calls
  before it (`new_handle()`, `handle_setheaders()`) are not caught.
  No failing input was found for them.
- The contract defines `fetch`'s return value, so most of these are misuse
  of an internal function. The thrown error is the case that matters: the
  injectable `fetch` exists for stage 5 and for tests, and a thrown error
  should become "could not check" like any other failure.
- Cause: `decisions_github()` (`R/decisions.R`) calls `fetch()` unguarded.

**11. Two calls stop with a base R error when the target is a folder.**
Severity: crash.
- `dict.yml` is a directory: `use_dictionary()` announces and writes the
  schema, then fails with `Error: cannot open the connection` (after a
  warning that `dict.yml` "is not a regular file"). It is not a
  `weft_tool_error`, and it fails after it has written.
- `dict_vale(path = "styles/Dir/Terms.yml")`, where that path is a directory,
  fails with `cannot open the connection`.
- Cause: `readLines()` on a directory, in `use_dictionary()` (the schema-line
  check) and in `dict_vale()`'s `generated()`.

**12. `parse_github_remote()` accepts junk in the repository name and refuses
some genuine github.com remotes.**
Severity: wrong output.
- `https://user@github.com/o/r?x=1` gives repo `r?x=1`, and
  `https://github.com/o/r#frag` gives repo `r#frag`. The API URLs become
  `…/repos/o/r#frag` and `…/repos/o/r#frag/issues/12`. curl drops the
  fragment, so every issue request would ask for the repository and get 200:
  every pointer would be `TRUE`.
- These are refused (`NULL`, so every pointer row is `NA` "not on
  github.com"):
  - `ssh://git@ssh.github.com:443/o/r.git`, GitHub's documented SSH-over-443
    host. It is the workaround on a network that blocks port 22.
  - `https://GitHub.com/o/r` (the host is case-insensitive).
  - `https://github.com:443/o/r.git`.
  - `ssh://github.com/o/r.git` (no user).
- Cause: `parse_github_remote()` (`R/decisions.R`). Its patterns allow
  `[^/]+?` in the repository name and only the literal host `github.com`.

**13. `dict_seed()` misreads some chunk headers and options.**
Severity: wrong output.
- `{r, fig.cap='eval=FALSE is off'}`: the chunk is skipped, because the
  regex finds `eval=FALSE` inside the caption string.
- `#| eval: false  # not now` (a YAML comment after the value): the chunk is
  read.
- `{r engine='python'}` with `xi = 1`: the chunk is read as R, and `xi` is
  counted.
- `{r, eval=0}`: read (knitr evaluates no expression). `#| eval: !expr
  FALSE`: read. The contract names only the literal forms, so these two are
  by design.
- A ` ```{r} ` chunk that shows a nested ` ````{r} ` example is reported
  skipped with `attempt to use zero-length variable name`.
- A Latin-1 file gives six R warnings (`input string 1 is invalid UTF-8`,
  `unable to translate …`) and then a skipped piece. The skip is right; the
  warnings are noise.
- `paths = c("a.qmd", ".")` gives `dict_seed(): no such file: ..` (the
  folder `.` followed by the sentence's full stop).
- Confirmed safe: a chunk holding `file.create("<marker>")` creates nothing.
  `<<-`, `assign()`, `m1 <- m2 <- 1`, `TRUE`, `NA`, `NULL`, `1i`, `1e400`
  and `c(1, 'a')` are not counted. `-1 -> nn`, `0x10`, `5L` and `5`, and
  `"é"` are handled as the contract says. 2 × 4,000 chunks take 5 s.
- Cause: `seed_chunks()` (`R/dict-tools.R`). It matches the header text and
  ignores the `engine` option.

**14. The glob and function resolvers reach outside their stated scope.**
Severity: wrong output (low).
- Glob, pattern `{id}/x.md`:
  - The pointer `..` gives `TRUE ../x.md`, a file outside the root.
  - The pointer `~` looks up `$HOME/x.md`: the pattern is treated as
    absolute and `Sys.glob()` expands the tilde.
- A dangling symlink `decisions/5-x.md` counts as `TRUE`.
- Function: a bare name is found through the search path, not the global
  environment the contract names. `decisions: isTRUE` makes every pointer
  `FALSE` ("isTRUE returned FALSE"), and `decisions: file.exists` does the
  same. `decisions: c` makes every row "could not check".
- Cause: `decisions_glob()`. In `decisions_function()`,
  `get(fun, envir = globalenv(), mode = "function")` with the default
  `inherits = TRUE`.

**15. Messages that mislead or that an author cannot act on.**
Severity: unclear error.
- Issue call answered 401 with no token set: "`could not check: GitHub
  refused the token in GITHUB_PAT (401)`". No token was sent.
  (`var %||% "GITHUB_PAT"` in `refused()`.)
- `decisions: GitHub` (capital G) is accepted by `read_config()` and then
  fails as "`Cannot find the decisions function `GitHub` (rule 9.1.8).`"
  Nothing hints at `github`. The same happens with any typo that is a
  syntactic name.
- A function returning `NA_integer_` gives "`na_int returned a integer of
  length 1, not TRUE, FALSE or NA`": the grammar is wrong, and it says "not
  NA" of an NA. `NULL` gives "a NULL of length 0". `stop("")` gives "`failed:
  `" with nothing after it.
- `github_fetch()`'s curl error spans two lines (`Could not connect to server
  [127.0.0.1]:\nFailed to connect …`), and the GitHub detail keeps the
  newline. The function route keeps only the first line. Stage 5 prints one
  line per row.
- `use_dictionary()` and `dict_vale()` let base R errors and warnings through
  (findings 2 and 11).

**16. Small things in `dict_vale()` and `use_dictionary()` messages.**
Severity: cosmetic.
- When `.vale.ini` has `BasedOnStyles = Vale, Weft-old`, the hint is not
  printed, because `\bWeft\b` matches inside `Weft-old`. `StylesPath` is never
  compared, so a `.vale.ini` listing `Weft` under another `StylesPath` also
  passes.
- `path = "../../escaped/Weft/Terms.yml"` writes outside the project. The
  message shows `<root>/../../escaped/Weft/Terms.yml` unnormalised, because
  `normalizePath()` cannot resolve a path that does not exist yet.
- An absolute `path` under the root, written through a symlink (`/tmp/…` for
  `/private/tmp/…`), gives a hint with an absolute `StylesPath`.
- `use_dictionary()` counts a schema line anywhere, even inside a value
  (`definition: 'see yaml-language-server: $schema=x'`). It says nothing about
  a schema line that points somewhere else
  (`$schema=https://example.org/old.json`).

## Questions

**A. Vale's `swap` order (C11).** Vale reads `swap` into a Go
`map[string]string`, which does not keep key order. So writing the keys
longest first either does nothing (Vale sorts them itself) or gives no
guarantee (it does not). Recommend: check Vale's source. If it does not
sort, depend on the conflict checks rather than on order, and drop the claim
from the help.

**B. Spellings Vale cannot match (finding 3).** Either (a) refuse an `avoid`
that starts or ends with a character that is not a word character, or (b)
write `nonword: true` and put the boundary into each key. Option (b) is
awkward, because RE2 has no lookbehind. Recommend (a): it is a one-line
check in `read_dict()`, it matches what Vale can do, and the message can
explain the reason.

**C. Text weft prints that an `avoid` can flag.** The check covers only
canonical spellings. An `avoid` equal to the string value of an entry that
has a `term` is accepted (`b: avoid: [Northern catchment]` beside `a: value:
Northern catchment, term: study area`). So is a `labels` phrase
(`avoid: [Upper reach]`) and a `dict_local` `term` (`min sample size`, which
`dict.yml` avoids). Vale would then flag text that weft itself put in the
document. Recommend: check every string weft prints (string values, `labels`
phrases, `breaks` phrases) as well as canonicals, and check a `dict_local`'s
terms against the project's `avoid`.

**D. Forks and 410 (C30).** In a fork, `origin` is the author's own
repository, where issues are usually off and GitHub answers 410. Every
pointer then reads "does not resolve", although the issues exist upstream.
410 also means "issues disabled", not only "deleted". Recommend: treat 410 as
"could not check" unless the repository response has `has_issues: true`, and
say in the detail to set `github:<owner>/<repo>`. (`fetch` would then have to
return the body, or at least that flag.)

**E. A remote that belongs to another project.** A project folder inside an
unrelated repository gets that repository's `origin`. In the case run, a
dotfiles repository gave `TRUE someone/dotfiles#12 exists`. Recommend: use
the `origin` only when the git top level is the project root or inside it.
Otherwise give "could not check" and ask for `github:<owner>/<repo>`.

**F. `decision: "#12"`.** It is a natural way to write an issue, and it is
`FALSE` ("not an issue number"), which fails `verify()`. Recommend: accept an
optional leading `#` under the GitHub route, or make `read_dict()` refuse it
with a hint. Do not leave it as "unresolved".

**G. The glossary outside a knit ignores `_weft.yml`.** `dict_glossary()` at
the console in a project with `decimal_mark: ','` prints `12,345.5` and
`0.5 m`. The same chunk in a knit prints `12.345,5` and `0,5 m`. The contract
says "the configuration in force", and outside a knit that is the defaults.
Because the function already finds the project root to read `dict.yml`,
recommend: read that root's `_weft.yml` too, so the preview matches the
document.

**H. "The stipulated value prints as written."** It does not when YAML has
already parsed the number, or when `display` converts it:
- `value: 0.50` (unit `m`) prints `0.5 m`, losing the second decimal the
  author wrote.
- `value: 1`, `unit: m`, `display: ft` prints `3.28083989501312 ft`.

Recommend: take the decimals from the text as written (the reader has the
line), and for a `display` conversion either keep the written decimals plus
the conversion's order of magnitude, or print the value in its `unit`.

**I. Markdown in `term` (C3).** "As written" lets `term: '# Heading?'` turn
into an `<h1>` and leave the list, and `term: 'C:\temp\x'` print as `C:`
because Pandoc reads `\temp` as raw TeX. Recommend: keep markdown, but refuse
a `term` that starts with a block marker (`#`, `>`, `-`, `*`, `:`, a digit
followed by `.`) or holds a newline (finding 6).

**J. A blank line inside a definition.** A definition with two paragraphs is
joined into one ("First paragraph. Second paragraph."). That is per contract,
but silent. Recommend: keep the joining and say so in `?dict_file`, or
indent continuation paragraphs four spaces, which Pandoc reads as one
definition with several paragraphs.

**K. `decisions` in a single document's front matter.** It is allowed when
there is no `_weft.yml` (C35), but `check_decisions(resolver = NULL)` reads
only `_weft.yml`, so for that document the front-matter value is never used.
Recommend: stage 5 passes the document's resolved `decisions` explicitly.
Note it in "Deferred to `verify()`".

**L. `use_dictionary()` and a schema line that points elsewhere.** An
existing `dict.yml` whose `$schema=` names an old URL or another file gets no
message (finding 16). Recommend: when the line exists but does not end in
`_weft/dict.schema.json`, print the line to use instead, and still never edit
the file.

**M. Symlinks (finding 1).** Recommend: refuse to write through a symlink at
either path, with a `weft_tool_error` naming the link and its target. The
other choice is to announce the target. That keeps a project that keeps its
schema in a shared location working, but it is harder to read.
