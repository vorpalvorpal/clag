# Review of stage 6 (values by name, the resolver filter)

Independent review, 14 Nov. Scope: the files listed in the brief, at `5da827f`. Every
finding below was reproduced in a temp folder; commands are given from that folder. `F` stands
for `/Users/rjs/dev/clag/inst/quarto`, and `R1` for
`R_USER_CACHE_DIR=$(mktemp -d) Rscript -e 'suppressMessages(devtools::load_all("/Users/rjs/dev/clag", quiet=TRUE)); ...'`.
PATH Pandoc is 3.8.3. Where it matters I also ran `quarto pandoc` (3.10) and got the same
result. Open findings 1 to 19 of `dev/open-findings.md` are not repeated here.

Counts: 6 high, 6 medium, 10 low.

## Findings

### 1. High: `unit=` on a named value is left as code by both filters, and the render passes

- Rule: 2.13.3 and N83 say a class or key the filter does not implement is "a value error that
  says so, never a pass-through". The 6d ruling says "`unit` counts as a renderer key for N5",
  and `R/scan.R:15` (`NAMED_KEYS`) follows it.
- Where: `weft.lua:70` (`RENDERER_KEYS` has no `unit`), so `code_candidate()` (`weft.lua:452-462`)
  returns false for a span whose only weft key is `unit`. `weft-check.lua:27` has the same table,
  so it says nothing either.
- Repro: `t3.md`:

  ````
  ````{.weft-values}
  {"weft":1,"values":{"x":{"t":"float","v":"2.5"}}}
  ````

  A `x`{unit="m"} B `x`{UNIT="m"}
  ````

  `pandoc t3.md -t plain --lua-filter F/weft.lua --lua-filter F/weft-check.lua; echo $?`
  - Observed: `A x B x`, exit 0. R's `scan_document()` on the same text as a `.qmd` gives two
    rows, `kind named`, `resolver filter`, `error NA`, so the lints are silent too.
  - Expected: two value errors ("`unit=` on a named value is not available"), as
    `` `x`{.num unit="m"} `` already gives. Exit 1.
- Fix direction: add `unit` to the keys that make a named value, in `weft.lua` and in
  `weft-check.lua`'s E35 test.

### 2. High: a governor value with a leading space is not a span to Pandoc, and both filters print it raw

- Rule: 2.13.2. A construct in a filter document is resolved, or it fails. The brief's open item
  on N92 asks for "a construct neither resolves".
- Where: Pandoc reads `{n=" k"}` as text, not as an attribute. `weft.lua` sees only `Span`
  elements. `weft-check.lua:62-70` (`attr_block_shown`) deliberately skips `]{`. The R side trims
  the value (`R/scan.R:950`, `trim_ws`) and accepts the span, so neither the lints nor the
  pre-render script object.
- Repro: `t6.md`:

  ````
  ````{.weft-values}
  {"weft":1,"values":{"k":{"t":"int","v":"2"}}}
  ````

  A [one | many]{n=" k"} B.
  ````

  `pandoc t6.md -t plain --lua-filter F/weft.lua --lua-filter F/weft-check.lua; echo $?`
  (and the same with `quarto pandoc`)
  - Observed: `A [one | many]{n=” k”} B.`, exit 0. The same happens for `if=" ok"` and
    `if=' ok'`. A trailing space (`if="ok "`) parses.
  - Expected: a failure. A knitr document resolves the same text, because the hooks read the
    source.
- See "Tests" below: c81c882 removed exactly this case (`"  n_gap > 10  "`) from
  `test-filter-if.R` instead of pinning a failure.
- Fix direction: make it a construct error in the scanner (a governor value that starts with a
  space is not read by Pandoc), and let `weft-check.lua` flag `]{KEY=` in text in a filter
  document.

### 3. High: Lua's `%s` matches byte 0xA0 under the locale Pandoc runs in, which corrupts a no-break-space `big_mark` (and report text)

- Rule: 2.13.7 (the filter reads `big_mark` as R does) and 2.13.3 (the same text as R).
- Where: `weftlib/config.lua:30` (`trim`) and `:61-62` strip `%s`, which takes the 0xA0 byte of
  U+00A0 (`C2 A0`) and leaves a lone `C2`. `pandoc lua` with `print(("à"):find("%s"))` prints a
  match under `en_AU.UTF-8`. `weft.lua:443` (`shown_span`) and `:1595` use `%s+` too, and turn
  `à` (`C3 A0`) into `C3 20`.
- Repro (number): `_weft.yml` holds `big_mark:` followed by one U+00A0, unquoted (YAML 1.2
  reads it as text). `d.md` publishes `n` as the int `"1234567"` and holds `` `n`{.num} ``.
  `pandoc d.md -t plain --lua-filter F/weft.lua | od -An -tx1`
  - Observed: `31 ef bf bd 32 33 34 ef bf bd 35 36 37`, that is "1�234�567". Exit 0.
  - R: `R1 cfg <- read_config("."); charToRaw(cfg$big_mark)` gives `c2 a0`, so R values in the
    same document print "1 234 567".
- Repro (report): a failing `[voilà | là]{if="nope"}`. The report line holds `voil\303 ` (od
  shows `l 303 space |`). In the stamp and the collection line, `json_str` then gives
  `"(unreadable text)"`.
- Fix direction: use explicit `[ \t\r\n]` classes, as `squash()` at `weft.lua:1048` already
  does, everywhere text can hold UTF-8.

### 4. High: `.ord` prints an exact integer through a double, so it prints the wrong digits and suffix past 2^53

- Rule: 2.13.3: "An integer or a decimal prints exactly, whatever its size".
- Where: `weft.lua:966-968`. `string.format("%.0f", nk)` uses `nk = it.number`, a double, and
  `words.ordinal_suffix(nk)` uses the same double.
- Repro: `t2.md` publishes `k` as the int `"9007199254740993"` and `m` as the int
  `"123456789012345678901"`, and holds `` `k`{.ord} `m`{.ord} `k`{.num} ``.
  `pandoc t2.md -t plain --lua-filter F/weft.lua`
  - Observed: `9,007,199,254,740,992nd`, `123,456,789,012,345,683,968th`,
    `9,007,199,254,740,993`. Exit 0.
  - Expected: `9,007,199,254,740,993rd` and `123,456,789,012,345,678,901st`.
- Fix direction: build the `.ord` digits and suffix from the printed text (the exact path's
  `ip`), not from `number`.

### 5. High: a document-level `weft:` mapping in flow style is ignored, so named values print with other settings than R values

- Rule: N84 and 2.13.7: "the `weft:` mapping in the source file's own front matter ... The
  document's value wins". R accepts the flow form.
- Where: `weftlib/config.lua:108`. `front_matter_weft` matches only `^weft:%s*$`. A
  `formatters:` mapping in flow style is missed the same way, so a project formatter class
  would then be left as code with no E21.
- Repro: `d.md`:

  ```
  ---
  weft: {digits: 3}
  ---
  ```

  followed by a block that publishes `x` as the float `"3.14159"` and the text
  `` `x`{.num} ``. Command: `pandoc d.md -t plain --lua-filter F/weft.lua`
  - Observed: `X is 3.1.`, exit 0, no warning.
  - R: `R1 read_config(tempdir(), front = yaml_read_text("{digits: 3}"))$digits` gives 3, so
    `` `r x`{.num} `` in the same knitr document prints 3.142.
  - Expected: 3.142, or a configuration failure that says the form is not read.
- Fix direction: refuse (E33) any `weft:` value on the key's own line, rather than ignore it.

### 6. High: on the jupyter engine, `auto()` keeps an earlier value when a later hidden cell changes the name

- Rule: N72 ("Its traps, each loud") and 2.13.12. The design covers a name published *only* in
  a hidden cell (it becomes "no value"). A name published earlier and changed in a hidden cell
  prints its old value with no error, and no lint fires: `publish-hidden` needs a `put()` or
  `auto()` call in the hidden cell.
- Where: `inst/python/weft/__init__.py:227-247` (`_publish_changes`). Its block is dropped with
  the cell's output, but `_auto["last"]` is updated, so the name is not published again until it
  changes again.
- Repro: `d.qmd` (`jupyter: python3`, with `weft.lua` and `weft-check.lua` as `filters:`):
  - cell 1: `from weft import auto; auto(); n_sites = 10`
  - cell 2 (`#| include: false`): `n_sites = 12`
  - prose: `` We visited `n_sites`{.num} sites. ``

  Command: `PYTHONPATH=/Users/rjs/dev/clag/inst/python QUARTO_PYTHON=<scratchpad venv python> quarto render d.qmd --to gfm --no-execute-daemon`
  - Observed: "We visited 10 sites.", exit 0, nothing on stderr.
  - Expected: 12, or a failure.
- Fix direction: do not record a name as published from a callback whose cell output is
  dropped (not knowable in the kernel). Otherwise extend `publish-hidden` to a hidden cell that
  assigns a name the source uses when `auto()` is on.
- Note: open finding 13 (auto's missing gate) understates the risk of `auto()`. This is the
  worse case.

### 7. Medium: a document that reads a values file is always "not fresh", so `verify()` fails it with E36

- Rule: N120 (`verify()` fails a stamp with `fresh: false`) and N46 (`weft_values_write()`
  "works ... in a `targets` pipeline"). A values file is computed before the render by design.
  The filter applies the run test of N91 to it as if it came from freeze.
- Where: `weft.lua:394-402`. A `file=` block goes through the same freshness code as an inline
  block.
- Repro: in a folder with `_weft.yml`:
  - `R1 Sys.setenv(WEFT_RUN="PIPE-1"); weft_values_write("_weft/values/survey.json", n_sites = 12L)`
  - `doc.md` holds a `file="_weft/values/survey.json"` block and `` `n_sites`{.num} ``.
  - `WEFT_RUN=RENDER-2 pandoc doc.md -t plain --lua-filter F/weft.lua`

  Observed: the notice "served from freeze or a cache, or by a kernel kept ...", and the stamp
  has `"fresh": false`. `verify_read_stamps()` puts the document in `unfresh`, which counts as
  a failure reason (`R/verify.R:166`).
- Fix direction: leave values files out of `fresh` and E34. If their age matters, say so with a
  message of their own.

### 8. Medium: the filter's own config check rejects settings R accepts, and fails the render (even in draft)

- Rule: 2.13.7 ("A value of the wrong kind for its key"). R's reader (`R/io.R:59-66`) takes
  `true` and `false` in any letter case, and numbers such as `2.0` for whole-number keys.
- Where: `weftlib/config.lua:63-65` (only lowercase `true`/`false`, and only `^%d+$`).
- Repro: `_weft.yml` holds `draft: TRUE` and `serial_comma: True`; `d.md` holds one named value.
  Command: `pandoc d.md -t plain --lua-filter F/weft.lua; echo $?`
  - Observed: two `[construct error]` entries, exit 1. `R1 read_config("cfg1")` gives
    `draft = TRUE` and `serial_comma = TRUE`.
  - So a project that asked for draft mode fails its render because of that same line.
- Fix direction: accept the YAML 1.2 core booleans and whole-valued decimals, as R does.

### 9. Medium: under rmarkdown the filter takes `doc.knit.md` as the source: wrong file and line, and a separate stamp and ledger

- Rule: N89 (lines from the source), N110 (merge into the hooks' stamp), N112 (one ledger per
  source).
- Where: `weft.lua:1985-1994` (`source_path` takes `PANDOC_STATE.input_files[1]`) and
  `:2277-2283`. `.knit.md` is recognised as knitr's (`:2099`) but is never mapped back to the
  `.Rmd`.
- Repro: an `.Rmd` with `weft_setup()`, `pandoc_args` naming both filters, and a missing name on
  source line 19. Command: `WEFT_RUN=RUN9 WEFT_DRAFT=1 R1 rmarkdown::render("doc.Rmd")`
  - Observed: "doc.knit.md:22  [no value]", and the marker says line 22.
  - `.weft/stamps/` holds both `doc.Rmd.json` (hooks; no `writers`, no filter failure) and
    `doc.knit.md.json` (`writers: ["filter"]`).
  - `_weft/ledger/doc.knit.md/doc.jsonl` sits beside `_weft/ledger/doc.Rmd/`.
- Fix direction: when the input ends `.knit.md`, use the `.Rmd` (or `.Rmarkdown`) beside it for
  the source, the lines and the stamp name.

### 10. Medium: a frozen knitr document with named values loses its recorded failures from the stamp

- Rule: N110 and N121, and the 6g ruling ("A knitr document with no hooks stamp of this run ...
  gets no stamp"). The post-render script re-reports "the failures recorded in the stamp of
  every document served from freeze".
- Where: `weft.lua:2172-2202`. When the old stamp's `run` is not this run, the filter writes a
  new stamp: `writers ["filter"]`, its own `checks`, `failures` only its own. The early return
  at `:2182` applies only when the document has no blocks and no entries. `weft-post-render.R:99-107`
  then treats the new stamp as same-run and `fresh: false`, with `failures = list()`.
- Repro (filter level): `_weft.yml`, a `doc.qmd` with an `{r}` chunk and a block of run `R0`,
  and a stamp of run `R0` with `writers ["knit","filter"]`, `checks 5` and one knit failure.
  Command: `WEFT_RUN=R1 pandoc -f markdown doc.qmd -o doc.html --lua-filter F/weft.lua`.
  The stamp becomes `run R1`, `checks 1`, `failures []`, `writers ["filter"]`, `fresh false`.
  The knit failure and its count are gone. A marker left in the frozen text still fails the
  render through `weft-check.lua`, but as an unexplained `filter` finding, not as the knit
  failure.
- Fix direction: when `S.knitr` and the old stamp is from another run, keep its knit failures,
  its checks and its `executed`.

### 11. Medium: `status()` says `quarto: ok` with a stale `weft.lua` or a missing `weftlib` module

- Rule: the stage 6 installers ship `weft.lua` and `weftlib/` (N80). `status()` reports
  `outdated` or `missing` for weft's own files.
- Where: `R/use-weft.R:4-8` (`QUARTO_COPIES` lists neither) and `:477-503` (`status_quarto`).
- Repro: `_quarto.yml` and `R1 use_quarto("proj1")`. Then overwrite
  `_extensions/weft-check/weft.lua`, delete `weftlib/stamp.lua`, and run
  `status_quarto(normalizePath("proj1"))`.
  - Observed: `state "ok"`, "extension, scripts and _quarto.yml entries are in place".
  - Expected: `outdated` or `missing`, naming the files.
- Fix direction: put `weft.lua` and each `weftlib/*.lua` in the status (and rollback) list.

### 12. Medium: `.val` with a text or collapse class reads the string as markdown; bare `.val` does not

- Rule: N8 and 1.12.2: "`.val` prints a named value as itself ... a string as it is ... A text
  or collapse class may go with it".
- Where: `weft.lua:1164-1169` uses `pandoc.Str` only for bare `.val`. Every other combination
  goes through `md_inlines(..., data = true)` → `pandoc.read`.
- Repro: `t1.md` publishes `c = "a*b*c"`, `d = ["x*y","z*w"]` and `e = "<b>hi</b>"`. Command:
  `pandoc t1.md -t html --lua-filter F/weft.lua`
  - `` `c`{.val} `` → `a*b*c`, but `` `c`{.val .cap} `` → `A<em>b</em>c`.
  - `` `d`{.val .and} `` → `x<em>y and z</em>w`.
  - `` `e`{.val .cap} `` → raw HTML `<B>hi</b>`.
- Fix direction: for `.val`, build the inlines from `Str` pieces before the text and collapse
  stages, or rule that 1.4.10 overrides N8 and print bare `.val` through markdown too.

### 13. Low: the same float prints differently under `.val` depending on the writer

- Rule: 1.12.8 ("A named value means the same in every document and on every engine") and N8
  ("the shortest text that reads back as the same double").
- Repro (records):
  - `R1 values_record(100000)$json` gives `"100000"`, `1e23` gives `"1e+23"`, `-0` gives `"-0"`,
    and `5e-324` gives `"4.94065645841247e-324"` (not the shortest).
  - Python `put` gives `"100000.0"`, `"1e+23"`, `"-0.0"`, `"5e-324"`.
  - Julia `Weft.put` gives `"100000.0"`, `"1.0e23"`, `"-0.0"`, `"5.0e-324"`.
- `` `x`{.val} `` prints the record's text, so it prints differently from each language.
  `.num` agrees across all three.
- Fix direction: normalise in the filter's `.val` (or in the writers) to one shortest form.

### 14. Low: a one-element named vector is a scalar from R but a list from Python and Julia

- Rule: N47 ("A length-1 named vector is a scalar") against N70 and Julia's `put`.
- Repro: Julia `Weft.classify((a=1,))` gives `{"t":"list",...,"keys":["a"]}`. Python
  `record_of({"a": 1})` gives the same. `` `x`{.num} `` is then E17 ("is a list") from Python
  or Julia, and prints from R.
- Fix direction: pick one rule for all three writers (open finding 9 is the R side of this).

### 15. Low: R publishes `complex` and `raw` values as strings, not as E45 errors

- Rule: N47's last row ("anything else ... error, E45").
- Where: `R/values.R:119-123` (the `else` branch of `values_scalars`).
- Repro: `R1 values_record(1+2i)$json` gives `{"t":"string","v":"1+2i"}`.
  `values_record(as.raw(255))$json` gives `{"t":"string","v":"ff"}`.
- Fix direction: refuse types that are not logical, integer, double, character, factor, Date or
  integer64.

### 16. Low: conditions compare a float exactly by its text, where 1.12.5 says "a float is compared as a double"

- Where: `weftlib/cond.lua:199-200`.
- Repro: `f` is the float `"0.1"` and `d` is the decimal `"0.1"`. `[same | differ]{if="f == d"}`
  prints `same`. Compared as a double, 0.1000000000000000055… is not 0.1. The same holds
  against a literal with more digits than the shortest text.
- Fix direction: amend the rule, or compare a float through its double.

### 17. Low: the run is looked for differently by the filter and by the writers

- The filter looks in 8 folders (`weft.lua:314`, the document's folder and 7 parents). R and
  Python look in 9 (0:8 and `range(9)`), and Julia in 9 too.
- The filter takes `WEFT_RUN` before `.weft/run` (N91), and every writer takes the file first
  (N48).
- A document 8 levels deep, or a stale `WEFT_RUN` in the shell, gives a false E34 notice, and a
  false E36 under `verify()` only if the env is stale.
- Fix direction: one search, used by all four.

### 18. Low: malformed `checks` are ignored without a word

- Rule: N22 and N23 ("A record that breaks this table is read as an error record").
- Where: `weft.lua:286-302` and `:404-418`. `ipairs` over a `checks` object (not an array)
  yields nothing.
- Repro: a record with `"checks":{"text":"x > 1","ok":false}` prints with no failure.
- Fix direction: validate `checks` in `record_problem()`.

### 19. Low: an author's `.weft-marker` span hides what it holds from `weft-check.lua`

- Where: `weft-check.lua` (N94a block, `Pandoc()`) drops every `span.weft-marker` before
  checking. In a knitr document, weft.lua leaves an out-of-grammar span inside such a span (N92),
  so `[[a | b]{n="nrow(d)"}]{.weft-marker}` is checked by neither filter. Deliberate only.
- Fix direction: mark weft.lua's own markers with an attribute the filter sets, such as a run
  nonce, and unwrap only those.

### 20. Low: odd messages and reads at the edges

- (a) A named value in a front-matter field the filter does not resolve (`date: "`d`{.date}"`)
  gets E35, "the filter weft.lua is not installed", which is false.
  Repro: `pandoc t8.md -s -t html --lua-filter F/weft.lua --lua-filter F/weft-check.lua`.
- (b) `lint_named_unpublished` (`R/lint-named.R:60-64`) reads a `file=` values file with no
  check that it lies inside the root, so it accepts names that the filter then refuses with E32.
- (c) `values_file_text` (`weft.lua:2085`) reads the whole file before the 5,000,000-byte check.
  A large file under the root is read into memory first.

## Suspected, not reproduced

- Julia engine: if a QuartoNotebookRunner version keeps the `display()` output of a cell that
  raises, a failed `@claim` is read twice: once from the displayed block and once from the
  printed `~~~~` carrier (`Weft.jl:346-352`). It would then be reported twice. Not run: it needs
  a julia-engine render, and the measured version drops the display.
- Python under knitr in Quarto: Quarto's knitr sets `comment = NA` (`share/rmd/execute.R:322`),
  so `put()` in a Python chunk prints a bare fenced block into a `cell-output-stdout` code
  block. `printed_carrier` (`weft.lua:1793`) would then read it as a carrier. That would make
  `put()` work under Quarto's knitr, against 3.8.9, and not under rmarkdown (comment `##`).
  Not run: it needs weft installed for a Quarto knitr render.
- A kept Jupyter daemon kernel's `run_id()` walks up from the kernel's own
  `QUARTO_DOCUMENT_PATH`. When the kernel was started for a document of another project, it can
  read that project's `.weft/run`. I expect a false E34 rather than a silent pass. Not run.

## Looked at and found sound

- Values-file paths: `..`, `/..`, `/sub/../..`, `C:/`, `//host`, `%2e%2e` and a directory are
  all refused. `../x` inside the root and `/x` from the root are read.
- The carrier fence: all three writers put the JSON on one line, with `\n` escaped. A string
  holding a run of backticks, U+2028 or newlines cannot close the fence or start a block.
- Exact `.num` and `.pct` on ints and decimals of any size, and ties half away from zero.
  `num_cmp` across signs, exponents and `-0`. Decimal and exponent forms from Python (`1E+2`) and
  Julia (`1.0e23`) parse.
- The three writers on bools, big ints, NaN/Inf/missing, dates, strings with quotes, newlines,
  DEL and non-ASCII, empty lists and lone surrogates (Python) or invalid UTF-8 (Julia): each
  gives a record the filter reads, or an error record. Only the texts in 13 and 14 differ.
- Lua under Quarto: no plain `error(` is left. The `pcall` sites take a string or a failure
  table. `os.exit(1)` fails `quarto render`. Failures in subfigure and image captions are
  reported under Quarto.
- N92: R's `filter_resolves()` and Lua's `source_is_knitr()` agree on `engine:`, `jupyter:`,
  `eval=FALSE`, `#| eval: false|no|FALSE`, `.Rmd` and `.knit.md`. A chunk inside a list item
  followed by indented prose keeps the list.
- A two-format Quarto render executes knitr once per format. So the second filter pass merges
  into a fresh hooks stamp. Run in plain Pandoc twice against one hooks stamp, the second pass
  does overwrite it, but Quarto never does that.
- The condition grammar in `cond.lua`, in `R/scan.R` (`cond_part_error`) and in the pre-render
  script: the same answers on `=`, `!==`, `'a>b'`, reserved words, `1.`, `-x` and literal
  against literal.
- `stamp.lua`, `report.lua` and the collection lines (layout and escaping). The XXH3 hash is
  compared with R in the tests.

## Tests that cannot fail or hide a defect

- `c81c882`, `test-filter-if.R`: the case `"  n_gap > 10  " = TRUE` was deleted on the ground
  that "Pandoc does not read an attribute value with leading spaces as a span". The test should
  have become one that expects a failure. As it stands, the silent pass-through of finding 2 is
  untested.
- `_conformance/exact.tsv` checks the exact path for `.num` and `.pct` only. No row puts an int
  past 2^53 through `.ord`, `.word`, `.count`, `.range`, `sign` or `n`, and finding 4 is in
  `.ord`.
- The conformance tables' `record` column comes only from R's `values_record()`. Python and
  Julia record texts reach the filter only in a few spot tests, so a writer-specific difference
  (13, 14) cannot fail a conformance row.
- No test renders a values file under a current run different from the file's `run`
  (finding 7), and no test reads a config with `TRUE`, `2.0` or a flow-style `weft:` (findings
  5 and 8).
- `412c0e6` regenerated `collapse.tsv` and dropped the four-element `.pairs` rows with `trunc`.
  That is coverage lost, not a defect hidden: I checked the filter by hand, and it gives R's
  "A (1.2), B (3.4) and 2 others".
- The other amendments read as correct: line numbers, `sourceCode` classes, `nil` for the
  reserved `nothing`, the xxhash in place of md5, and `true` under `.val`. `c0d6e9d`'s
  loosened "leftover|construct error" was tightened again in `81bdbfa`.

## Rulings (orchestrator, 14 Nov, under delegation)

All twenty findings are accepted as real except 19 (recorded, not
fixed: it takes a deliberate act by the author). The fixes are built
test-first in two packages, 6L (the filter) and 6R (R, Python, Julia),
with the stage-6 open findings 11 to 19 of `dev/open-findings.md`.

| # | Ruling |
|---|---|
| 1 | `unit` is a renderer key in both filters. The filter has no units, so a named value with `unit=` is a failure with E20 ("not available in the filter"), never left as code. |
| 2 | The scanner makes a governor value that starts with a space a construct error (Pandoc does not read it). `weft-check.lua` flags literal `]{KEY=` text for a weft key in a document the filter resolves. The deleted test case returns as one that expects a failure. |
| 3 | No `%s` on text that can hold UTF-8: explicit `[ \t\r\n]` classes everywhere in the Lua. |
| 4 | `.ord` (and every other class) builds digits and suffix from the exact printed text, never from a double. Conformance rows past 2^53 for `.ord`, `.word`, `.count`, `.range`, `sign`, `n`. |
| 5 | A `weft:` or `formatters:` mapping in flow style is read, with the same result as the block form. If a form cannot be read it is E33, never ignored. |
| 6 | Not knowable in the kernel. `publish-hidden` also fires on a hidden cell that assigns a name the prose uses, in a document that calls `auto()`. The article's Limits says so. |
| 7 | A values file is left out of `fresh` and E34. Its own `run` is not compared. |
| 8 | The filter accepts what R's reader accepts: booleans in any letter case, whole-valued decimals for whole-number keys. |
| 9 | An input ending `.knit.md` is mapped to the `.Rmd` or `.Rmarkdown` beside it for source, lines, stamp and ledger. |
| 10 | In a knitr document whose old stamp is from another run, the filter keeps the stamp's knit failures, checks and `executed`. |
| 11 | `status()` and the rollback list hold `weft.lua` and each `weftlib/*.lua`. |
| 12 | Published text is data, not markdown: `.val` with a text or collapse class builds from `Str` pieces. |
| 13 | The filter prints a float under `.val` in one form whatever the writer: the shortest digits, no trailing `.0`, exponent as R writes it (`1e+23`). R's own writer gives the shortest text for subnormals too. |
| 14 | One rule for all writers, replacing N47's sentence: a named vector of length 1 is a list of one with its key (R changes). In the filter a list of exactly one element prints as that element under a scalar class, so `.num` works and `.pairs` keeps the name. Closes open finding 9; the `collapse.tsv` row returns. |
| 15 | `complex`, `raw` and anything not listed in N47 is E45. |
| 16 | The rule is amended, not the code: a float is compared by its shortest text as an exact decimal. `0.1 == 0.1` across kinds is what an author means. |
| 17 | One search for the run in all four: the document's folder and 8 parents; `.weft/run` first, then `WEFT_RUN`. |
| 18 | `checks` that is not an array of well-formed check objects makes the record an error record. |
| 19 | Not fixed. Recorded. |
| 20 | (a) a front-matter field the filter does not resolve gets a message that says so; (b) the lint refuses a values file outside the root as the filter does; (c) the size is checked before the file is read. |

Suspected items: on the julia engine a failed `@claim` prints its
carrier and does not also `display()` it, so no version can report it
twice. Python and Julia `put` under knitr are wired to R's waiting
names (open findings 12 and 17), which also settles what Quarto's knitr
does with a printed block.

Open findings folded in: 11 (under Quarto the filter is silent on
stderr when the post-render script will report, so the report prints
once), 13 (`auto()` publishes automatically only names the source
uses, as R; a too-long list raises in `auto()` as in `put()`), 14
(`list` over bools prints true/false), 15 (a carrier fence at the end
of a stdout block is read, whatever was printed before it), 16 (the
eight Julia tests amended), 18 (E62 names the `_quarto.yml` form that
was measured to work), 19 (find the order dependence or isolate it).
