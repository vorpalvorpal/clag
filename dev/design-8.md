# Stage 8: guest chunk claims (G1) and guest table digests (G2)

Designed 14 Nov after v0.1.0, on the owner's ruling that both are built
now. Adopted as written, with G1c (E94) cut if its spike fails and G2b
(guest tables in knitr documents) deferred.


Rule, message and decision numbers carry on from `dev/design-7.md`: rules are GN1 to GN15 and GT1 to GT14, the new message is **E94**, and decisions are D55 to D64. Where D22, N40 and N78 of design-7 conflict with this design, this design replaces them.

---

## G1: `chunk_claims: collect` for Python and Julia claims

### 1. How it works today

**The R side**
- The setting is read at `R/config.R:61` (default `stop`) and checked at `:338-341` (E30). `weftlib/config.lua:20-33` does not know the key, so the filter ignores it.
- What happens to a failure:
  - `claim_fail()` (`R/claim.R:247-256`) asks `claim_collects_in_chunk()` (`:297-302`: the setting, and no running `targets` target).
  - Under collect, the failure goes in with `add_failure()`, `s$claims_collected` goes up, and the function returns.
  - At the end, `finish_document()` (`R/hooks.R:468-520`) either aborts `weft_failures` with every failure listed, or prints the list in draft mode.
  - In a project render, `record_knit()` (`R/collect.R:192-232`) appends the failures to `.weft/failures.jsonl` instead, and the post-render script reports and fails.
- A later error is turned into E31 by `wrap_collected_error()` (`R/claim.R:306-320`). It is called only from the R evaluate hook (`R/conditions.R:114-121`) and from inline values (`R/hooks.R:235`).

**Python** (`inst/python/weft/__init__.py:78-146`, `_backend.py:161-184`)
- `claim()` calls `report()`, then raises `ClaimFailed` (E55) at level `fail`.
- Under knitr, `report()` calls R's `guest_claim_report()` (`R/guest.R:449-465`), which records each failure with the chunk's label.
- Under Jupyter, it displays a block whose `checks` hold `ok: false` (N53).
- Python chunks never pass through the R evaluate hook, so a later Python error is never wrapped in E31.

**Julia** (`inst/julia/Weft/src/Weft.jl:312-360`)
- Under knitr, a failure is pushed onto `CLAIMS`, then `ClaimFailed` is thrown. R drains `CLAIMS` after the chunk (`R/guest.R:288-312`) or on the error (`R/guest-julia.R:147-169`, which uses `withCallingHandlers`, so there is no E31).
- On the julia engine, the block is **printed** with a tilde fence and then the claim throws. The engine drops what a cell displayed if the cell then raises. The filter recovers the printed block at `weft.lua:2010-2042`.
- `WeftGuest.mark_knitr()` (`inst/julia/WeftGuest.jl:146-170`) sets the knitr flag.

**The filter**
- `read_block()` (`weft.lua:495-510`) records each check that did not pass as a `failed claim`, located by the cell's label.
- At the end, the report either exits 1, or appends to the collection file, or (in draft mode) only reports (`:2645-2683`).

**The gate (N59)** counts claims statically, so the setting cannot change the count. `test-chunk-claims.R:295-314` already pins this for R.

**One test must change.** `test-chunk-claims.R:318-330` (N78) pins the old rule that a Python claim still stops under collect. It has to be rewritten.

**Measured facts that matter here** (`dev/design-6.md:55-90`):
- The julia-engine worker keeps a stale `QUARTO_DOCUMENT_FILE`, but `@__FILE__` and `__source__` give the real `.qmd`.
- A fresh Jupyter kernel has the right `QUARTO_DOCUMENT_PATH` and `QUARTO_DOCUMENT_FILE`. A daemon kernel keeps the first render's values.
- In a Jupyter cell with `error: true`, a block displayed before the error survives.

### 2. Alternatives and decisions

| # | Point | Alternatives | Chosen | Why |
|---|---|---|---|---|
| D55 | Who decides under knitr | the guest reads the files; R decides | R decides | R already has the config and the `targets` rule, and one decision maker cannot disagree with itself |
| D56 | Where the engines get the setting | an env var set by the pre-render script; Quarto metadata (`QUARTO_EXECUTE_INFO`); an explicit `weft.chunk_claims()` call; the guest reads `_weft.yml` and the front matter | the guest reads the files at each failed claim | the server and kernel environments go stale (measured 5); pre-render runs only in projects and misses front matter; an explicit call would put the setting in a second place (D17) |
| D57 | How a collected failure reaches the report on the engines | a new record kind in `.weft/failures.jsonl`; a side file; the existing block `checks` | the existing block `checks` | the filter already reports them, with draft mode, books, stamps and the collection file, so no new schema is needed |
| D58 | A later error on the engines | nothing; an IPython custom exception handler; Julia `showerror` piracy | IPython handler (E94) for Python; Julia deferred | a render that stops on a cell error never runs the filter or the post-render script; Python has a supported hook, Julia has none without piracy |
| D59 | Collecting in an interactive Jupyter session | always; only under a Quarto render | only when `QUARTO_DOCUMENT_PATH` is set | same as R: outside a knit a claim stops (2.4.2) |

### 3. Specification

- **GN1. The setting.** It is `chunk_claims` (N70), read from `_weft.yml` and the document's `weft:` mapping. The document's value wins. There is no new setting.

- **GN2. Who decides, by back end.**
  - **(a) knitr, Python by reticulate or Julia by JuliaCall in a weft knit:** R decides with `claim_collects_in_chunk()`.
  - **(b) jupyter:** the claim is collected when `QUARTO_DOCUMENT_PATH` is not empty and GN4 returns `collect`.
  - **(c) julia engine** (`kind() === :engine`): the claim is collected when GN4 returns `collect`.
  - **(d) none** (plain Python or plain Julia): never collected.

- **GN3. A collected claim.** This applies to a claim with at least one failed check at level `fail`, when collecting is on.
  - Each failure is recorded as today: one per failed check, with the `expr` and `detail` texts of N58.
  - The claim then returns `x` and raises nothing. Python returns the same object. Julia returns the value of the macro's first operand. The rest of the chunk or cell runs.
  - **A failure that no back end recorded is never collected.** Examples: the knitr callback raised, or the display raised. The claim then raises `ClaimFailed` (E55) as under stop.
  - **Python, knitr:** `guest_claim_report(level, expr, detail)` returns:
    - `FALSE` when there is no knit;
    - `TRUE` when it recorded the failure and did not collect it;
    - the string `"collected"` when it recorded a level-`fail` failure and R collects.

    `_backend.report()` returns `False`, `True` or `"collected"`. It returns `"collected"` only when every callback for the claim returned `"collected"`.
  - **Julia, knitr:**
    - Before each Julia chunk, R calls `WeftGuest.mark_knitr(collect::Bool)`, passing `claim_collects_in_chunk()`. `WeftGuest` keeps `COLLECT = Ref(false)`.
    - `Weft._claim` reads `Main.WeftGuest.COLLECT[]` (false when that is not defined). It pushes onto `CLAIMS` as now and does not throw.
  - **jupyter:** the block of N53 is displayed exactly as today: `values` is `{}`, and each check has `level` `"fail"` and `ok` `false`. Then `x` is returned.
  - **julia engine:** the block is **displayed** as a `Weft.Values`, as level `warn` does today, and not printed with a tilde fence. The claim does not throw.
  - **Julia's spelling:** Julia has only `@claim`. `_claim` stays internal and gains a `file` argument, which is `string(__source__.file)`.

- **GN4. The guest's reader.** It is called only when a claim has a level-`fail` failure on the jupyter or julia engine. Nothing is cached between calls.
  - **Where it looks:**
    - Python: the source is `QUARTO_DOCUMENT_PATH` joined to `QUARTO_DOCUMENT_FILE` when both are non-empty. The folder is `QUARTO_DOCUMENT_PATH`.
    - Julia: the source is the macro's `file` when it ends `.qmd` or `.md`. A relative path is made absolute against `QUARTO_DOCUMENT_PATH`, else `pwd()`. The folder is its directory. Otherwise there is no source, and the folder is `QUARTO_DOCUMENT_PATH`, else `pwd()`.
  - **`_weft.yml`:** the first one found in the folder or up to 8 parents. Read the first line that starts at column 1 with `chunk_claims`, optional spaces or tabs, then `:`.
    - The value is the rest of that line, with a `#` comment that follows white space removed.
    - Then trim it and remove one pair of surrounding `"` or `'`.
    - CR LF is read as LF.
  - **Front matter** (a source ending `.qmd` or `.md`; for `.ipynb` only `_weft.yml` is read, as `weftlib/config.lua` does):
    - The front matter starts at a first line of `---` and runs to the next `---` or `...`.
    - It holds a line `weft:` at column 1. If what follows `weft:` (comment removed, trimmed) starts with `{`, it is a flow mapping, read over several lines until the braces balance; take its top-level key `chunk_claims` (the key may be quoted).
    - Otherwise it is a block. The block is the lines after `weft:` that are blank or indented. Its indent is that of its first non-blank line. Take a `chunk_claims:` line at exactly that indent, and clean the value as for `_weft.yml`.
  - **Result:** `collect` exactly when the value that applies is `collect`. The document's value, when present, wins over `_weft.yml`. Otherwise the result is `stop`; this includes `Collect`, `true` and an empty value.
  - **Where the code lives:** Python in `weft/_config.py` as `chunk_claims(source, folder) -> str`, standard library only. Julia in `Weft/src/config.jl` as `Weft.chunk_claims_setting(source, folder)::String`, Base only.

- **GN5. The Lua config.** `weftlib/config.lua` learns `chunk_claims`:
  - default `"stop"`;
  - it accepts `stop` or `collect`, bare or quoted;
  - any other value is a problem (E33, with what = `"stop or collect"`), and the default is used.

  So an engine document with a bad value fails its render with E33, as a knitr document fails with E30. The filter does nothing else with the setting.

- **GN6. The report at the end.**
  - **knitr:** as N73, through `finish_document()` or the collection file. Failures are listed in the order collected, located by chunk label. In draft mode the list is printed and the render does not fail.
  - **Engines:** the filter's existing N25b path: kind `failed claim`, E15, the cell's label, exit 1, or a line in the collection file for the post-render script, and draft mode only reports.
  - Nothing changes in `weft.lua`'s reading of blocks.

- **GN7. Counting for E31.** `guest_claim_record()` adds 1 to `s$claims_collected` for each level-`fail` failure it records while `claim_collects_in_chunk()` is TRUE. This covers both the Python callback and Julia's drained rows.

- **GN8. A later error under knitr.**
  - **(a) Python:** weft wraps knitr's `python` engine once, as `julia_wrap_engine()` does. An R error that comes out of the engine is re-signalled as `wrap_collected_error(s, e)`. This happens in a chunk without `error: true`.
  - **(b) Julia:** `julia_wrap_engine()` changes to `tryCatch`. It drains the chunk's claims first, then re-signals `wrap_collected_error(s, e)`.
  - **(c)** An R chunk error or a bare inline error after a guest claim was collected is wrapped already. Its E31 count includes the guest claims.
  - E31's text and class (`weft_claims_collected`, with the error as parent) are unchanged. With no collected claim, the error and its class are unchanged.

- **GN9. A later error on the jupyter engine** (step G1c; cut it if the spike fails).
  - When a kernel collects its first claim, and `ip.custom_exceptions` is empty, weft calls `ip.set_custom_exc((Exception,), handler)`.
  - Each collected claim is kept with the run id that `run_id()` gave when it was collected.
  - When a cell raises and at least one kept claim has the current run id (`None` matches `None`), the handler returns:
    1. **E94:** `weft: this cell raised an error after %d failed claim%s collected in this run. The claims are listed first: the error may follow from a value that failed its claim.`
    2. one line per claim: two spaces, the `expr`, `": "`, the `detail`;
    3. `The error that stopped the cell:`;
    4. then IPython's own structured traceback.
  - Otherwise it returns IPython's own traceback unchanged.
  - The julia engine has no counterpart (deferred; see GN14).

- **GN10. Unchanged under collect:**
  - level `warn`;
  - `eval: false` (nothing runs, nothing is recorded);
  - plain Python and plain Julia (they raise);
  - interactive Jupyter, where `QUARTO_DOCUMENT_PATH` is empty (it raises);
  - knitr with `python.reticulate: false` (back end none);
  - freeze and cache: a frozen engine output keeps its blocks, and the filter reports them with the stale notice;
  - the gate count (N59, N77), whatever the setting;
  - `rehearse()` (N76): guest claims are listed for each case.

- **GN11. `error: true`.**
  - In collect mode a guest claim raises nothing, so no traceback is shown and the rest of the chunk runs. This holds in both routes, as in R.
  - On the julia engine, a block displayed by a collected claim is lost if a later statement in the same cell raises under `error: true`. Quarto drops what a cell displayed when it raises (N57). This is a documented limit.

- **GN12. Draft mode:** as today on each route.

- **GN13. Books.**
  - knitr chapters: as N73.
  - Engine chapters: each claim reads its own chapter's front matter and the project's `_weft.yml`. The filter appends to the collection file, and the post-render script reports once.

- **GN14. Limits, stated in the languages article:**
  - On the engines, a claim collected in a cell with `include: false` or `output: false` is lost. Level `warn` has the same gap today.
  - The julia engine has no E94.
  - A Jupyter daemon kernel may read another document's front matter, because its environment is stale. The article recommends setting `chunk_claims` in `_weft.yml`.

- **GN15. Spec text.**
  - 2.4.2: drop "and a Python or Julia `claim()`".
  - 2.4.4 and 2.4.5: add guests (GN3, GN8).
  - 3.9.3: rewrite.
  - 9.1.5: the filter and the guest packages read `chunk_claims`.
  - D22, N72 (the guest item) and N78: superseded.

### 4. Tests

**`_conformance/chunk-claims.tsv`.** Columns: `case`, `weft_yml`, `front`, `want`, `problem`. `\n` escapes newlines.

| Case | Input | `want` | `problem` |
|---|---|---|---|
| 1 | none | stop | |
| 2 | bare `collect` | collect | |
| 3 | `"collect"` | collect | |
| 4 | `'collect'  # opt in` | collect | |
| 5 | `stop` | stop | |
| 6 | nested under another key | stop | |
| 7 | block front matter `collect` over yml `stop` | collect | |
| 8 | flow `{chunk_claims: collect}` | collect | |
| 9 | flow with other keys, quoted | collect | |
| 10 | front matter `stop` over yml `collect` | stop | |
| 11 | `sometimes` | stop | yes (R: E30) |
| 12 | key deeper under `formatters:` | stop | |
| 13 | the line in the body, not in front matter | stop | |
| 14 | `_weft.yml` two folders up | collect | |
| 15 | `Collect` | stop | yes |
| 16 | CRLF line ends | collect | |

**`test-conformance-chunk-claims.R`** reads the table through four readers:
- R's config reader (`want`, or E30 where `problem` is yes);
- Lua (`config.load` via `lua_run`, with the problem's `what`);
- Python (`py_plain`, calling `weft._config.chunk_claims`);
- Julia (`jle_cases`, in one process, with `skip_if_julia_disabled()`).

**`test-guest-chunk-claims.R`** knits with knitr in process (`k5`, `pc6k`, `skip_if_no_python()`). Python cases:
- two failing claims in two chunks without `error: true`: the knit reaches the end, `last_knit()$failures` holds both with their labels, the render fails with both listed, and the value is returned (`print` after the claim runs);
- control: under stop the knit stops, as old N78;
- level `warn` is never collected;
- `error: true`: no traceback is shown;
- `eval: false` records nothing;
- draft mode reports and does not fail;
- a collected claim, then `raise ValueError` in a later Python chunk: `weft_claims_collected` with the parent, E31 counts 1;
- a collected Python claim, then an R `stop()`: E31;
- control: the same error with no claim keeps its class.

The same file has the Julia cases (`skip_if_julia_disabled()`):
- collected, the knit goes on, the drained rows are failures;
- a collected claim, then `error("x")` in a Julia chunk: E31.

**Rewrite** `test-chunk-claims.R:318-330` as a stop-mode control.

**`test-guest-claims-engine.R`** needs no render.
- Jupyter (`skip_if_no_jupyter()`): `jup_session` with `QUARTO_DOCUMENT_PATH` and `QUARTO_DOCUMENT_FILE` pointing at a temporary project.
  - collect: status `ok`, one block whose check has `ok: false`, `execute_result` is `7`, and the next statement runs;
  - stop: `ClaimFailed`;
  - collect setting but no Quarto variables: raises;
  - document front matter overrides the yml;
  - with G1c: a collected claim, then `1/0` gives a traceback whose first line is E94 and holds the claim line. When nothing is collected, the traceback is untouched.
- Julia (`jle_cases`): fake the engine with `Core.eval(Main, :(module QuartoNotebookWorker end))`, then `include_string(mod, "@claim n > 10", "<tmp>/doc.qmd")`.
  - collect: no throw, and the value is returned. The block is displayed, not printed: the stdout holds no tilde fence, and `display` is captured through a `TextDisplay`.
  - stop: the tilde print and a throw, as now.

**Slow renders** (`test-guest-claims-render.R`, two only):
- jupyter (`QUARTO_PYTHON`), collect, two failing cells: the HTML holds both cells' later output, the exit status is not 0, and stderr lists both failed claims with their labels;
- julia engine (`skip_if_no_julia_engine()`): the same.

### 5. Implementation notes

**Order:**
1. **G1a, knitr:** `R/guest.R` (callback return, counting, `python_wrap_engine()` called from the option hook at `R/hooks.R:311`), `R/guest-julia.R` (`mark_knitr(collect)`, the `tryCatch` wrap), `_backend.py` and `__init__.py`, `WeftGuest.jl` and `Weft.jl`.
2. **G1b, engines:** `_config.py`, `config.jl` (with `include("config.jl")`), the engine branches, `weftlib/config.lua` (DEFAULTS, KINDS, WHAT with kind `"claims"`).
3. **G1c:** E94.
4. Docs: the languages vignette, `PACKAGE-SCOPING.md`, NEWS.

All of this fits one implementer session. G1c is the part to cut.

**Risks:**
- reticulate's conversion of the R return value: `r_to_py("collected")` should be a Python `str`. The tests pin it.
- `set_custom_exc`'s handler contract differs between IPython versions. Spike it first with `jup_session`.
- The daemon kernel staleness (GN14).

**Defer:**
- Julia-engine E94;
- the side channel for claims in hidden cells.

### 6. Open questions

1. Hidden engine cells (`include: false` or `output: false`) lose collected claims. **Recommended default:** accept it and document it, as for level `warn`. Add a side file `.weft/claims.jsonl` that the filter reads only if a real document hits this.
2. Under `error: true` on Jupyter, the E94 lines also appear in the document's error output. **Recommended default:** accept.

---

## G2: table digests for jupyter-engine and julia-engine documents

### 1. How it works today

**The R side.**
- `record_chunk_tables()` (`R/tables.R:35-60`) runs only from the R evaluate hook (`R/conditions.R:132`).
- It hashes the N33 visible text of `knit_asis` elements and asis text with `cli::hash_raw_xxhash64`.
- An entry is kind `table`, expr is the label or `""`, id is the label, context is `chunk`, and sentence is the caption or the first 80 characters.

**Python chunks under knitr never reach that hook.** reticulate's `eng_python_autoprint` returns a pandas DataFrame as printed text, which is verbatim. A `_repr_html_` object is pushed as `knitr::raw_html` inside reticulate's engine. So a knitr document records no guest tables (N40).

**The ledger of a jupyter or julia document** is written by `weft.lua`'s `write_ledger()` (`weft.lua:2528-2556`):
- `weftlib/ledger.lua:350-416` drops the earlier `writer: "filter"` lines, keeps the lines the hooks wrote, and numbers `occ` per (file, section, kind, expr).
- `ledger.xxh3` (`ledger.lua:122-165`) equals `cli::hash_raw_xxhash64`.
- It is written only when the render does not stop on its failures, or in draft mode, or with the collection file open (`:2664`).

**The filter's walk.**
- The `Div` handler (`weft.lua:2073-2104`) sets `ctx.cell` through `cell_label()` (`:1993-1997`, which strips `cell-`). An unlabelled cell gives `nil`.
- `Table` captions are resolved by `restore_captions()` (`:2138-2178`).
- The stamp's `named` count (`:2459-2463`) counts every entry, so tables would inflate it.

**`weft-output.lua`** runs post-render, for each format, after Quarto's filters, and writes no ledger.

**`changes()`** reads entries of kind `table` without regard to the writer (`R/changes.R:733-739, 877-915`; E70 to E72).

**D16's worry, and the answer.** Depending on Quarto's HTML table processing, a Jupyter table reaches the filter as raw HTML or as a `Table`. Reading the raw HTML through `pandoc.read` gives both forms the same text.

### 2. Alternatives and decisions

| # | Point | Alternatives | Chosen | Why |
|---|---|---|---|---|
| D60 | Where the digest is computed | guest display hooks (IPython formatters for pandas and polars, Julia `show` wrappers); an explicit `weft.table(df)`; `weft-output.lua`; `weft.lua` | `weft.lua` | one implementation for every library and both languages; no guest code and no optional dependencies; it is the filter that writes these documents' ledger; an explicit call is opt-in and easy to forget, where R's route is automatic; `weft-output.lua` writes no ledger and sees the tree after Quarto restructures it |
| D61 | What is hashed | the data (CSV of the frame); N33 on the HTML; the `Table`'s cell text | the cell text, tab and LF joined | D32's principle (what the reader sees; a style change is not a change), applied to the AST; a pipe table and an HTML table with the same cells agree |
| D62 | Raw HTML | N33 on the text; `pandoc.read(text, "html")` | `pandoc.read` | the result does not depend on whether Quarto had already turned the HTML into a `Table` |
| D63 | knitr documents | the filter also records their guest cells; the hooks only | the hooks only (the filter skips them when `S.knitr`) | with `echo: false` the filter cannot tell a Python cell from an R one, so it would record R tables twice |
| D64 | Caption in the digest | in; out | out | captions hold named values, which already have entries; N33 has no caption either under Quarto's `tbl-cap` |

### 3. Specification

- **GT1. Scope.** Documents that the filter resolves and the knitr hooks do not (`S.knitr` false): the jupyter engine, the julia engine, and Markdown run through the filter. The project must be set up and the ledger on (`S.ledger_on`). knitr documents are unchanged; G2b is deferred.

- **GT2. A table** is either of these, inside a Div with class `cell` at any depth (including inside a `Figure`):
  - a Pandoc `Table`;
  - a `RawBlock` of format `html`, `html4` or `html5` whose text holds `<table` (any case). It is read with `pcall(pandoc.read, text, "html")`, and each `Table` in the result is one table. A read that fails, or holds no `Table`, records nothing.

  These are not tables:
  - a table outside every cell;
  - a `CodeBlock` (printed output);
  - raw LaTeX or Typst (deferred);
  - a `RawInline`;
  - a table inside another table's cell (only the outer one counts).

- **GT3. The canonical text.**
  - Row order: the head rows, then for each body its head rows and then its body rows, then the foot rows.
  - A cell is `pandoc.utils.stringify` of its contents. U+00A0 is made a space, runs of space, TAB, CR, LF, FF or VT are made one space, and the ends are trimmed.
  - The cells of a row are joined by one TAB; rows are joined by one LF. Rows themselves are not trimmed.
  - Row and column spans are ignored. The caption is not included.
  - A table whose cells are all empty is not recorded.

- **GT4. The digest** is `ledger.xxh3` of the UTF-8 bytes of the canonical text: 16 lower-case hex digits, equal to `cli::hash_raw_xxhash64(charToRaw(enc2utf8(text)))`. The same cells give the same digest on any Pandoc version from 3.1, any platform, either engine and either language, whether the table arrived as Markdown, as raw HTML or as a `Table` Quarto made.

- **GT5. The key.**
  - kind: `table`.
  - expr: `cell_label()` of the nearest enclosing `.cell` Div, or `""`.
  - id: that label, or `null`.
  - occ: as `ledger.write` numbers it. The second table of cell `tbl-two` is occ 2, and two unlabelled cells in one section are occ 1 and 2.
  - file: `S.src_rel`. A cell from an included file is recorded under the main source; this is a limit.
  - section: the identifier of the last `Header` above the table, or `""`.

- **GT6. The other fields.**
  - context: `"chunk"`.
  - text: the digest.
  - sentence, the first of:
    1. the `Table`'s long caption, resolved, stringified and with white space squashed, when not empty;
    2. else the enclosing cell's `tbl-cap` attribute, squashed, when not empty;
    3. else the first 80 UTF-8 characters of the canonical text with TAB and LF made spaces, followed by `...` when cut.
  - arm, rel, raw, failed: `null`. unit: `null`. dict: `[]`. writer: `"filter"`.

- **GT7. Where in the run.** One pass in document order, after `restore_captions()` and before `remove_empty_cells()`. A named value in a caption keeps its own entry, and a change in it never changes the table's `text`.

- **GT8. Counting.** Table entries count in neither `checks` nor `named` of the stamp.

- **GT9. When the entries are written.** Under the existing rule of the filter's ledger (written unless the render stops on its failures; also in draft mode or with the collection file open). Never with `ledger: false` or without `_weft.yml`.
  - A cell with `error: true` records every table that reached the document (N37).
  - Draft mode records as usual.
  - A frozen document records again from its frozen output, with the same digests.

- **GT10. `changes()`** is unchanged: E70 to E72 apply, `brief = TRUE` hides tables, and the first render lists every table as added, once.

- **GT11. Unchanged:** the gate, the lints, `verify()`, and the ledger version (1).

- **GT12.** These digests do not compare with the R route's (N33). A document is resolved by one route, so no key is ever shared. `dev/lua-parity.md` gains a row saying so.

- **GT13. Limits, in the article:**
  - tables whose rows a script fills (itables) are recorded by the HTML they hold (in practice the headers);
  - pandas in PDF output prints text, so no table is recorded;
  - raw LaTeX tables are not recorded;
  - a library update that changes what prints shows as a change, once.

- **GT14. Deferred, G2b: guest tables under knitr.** The route would be `guest_chunk_end()` reading the `{=html}` fences of the chunk's output that hold `<table`, with N33 hashing.

### 4. Tests

**`test-ledger-tables-filter.R`** uses `filter_md`, which needs only Pandoc: no Quarto, no Jupyter, no Julia.
- **Cell markup used:** `::: {#cell-tbl-sites .cell}` (jupyter-style) and `::: {#pub .cell}` (julia-style).
- **Exact form:** a pipe table gives one entry with the exact field values, and `text` equals `t7c_hash("a\tb\n1\t2")` (GT3 to GT6).
- **Digest equality:**
  - a raw-HTML table with the same cells gives the same digest;
  - pandas-like HTML with `<style>`, ids and classes gives the same digest;
  - with and without `<thead>` gives the same digest;
  - one cell changed gives a different digest.
- **Keys and occurrences:**
  - two tables in one cell are occ 1 and 2;
  - two unlabelled cells give expr `""`, id `null`, occ 1 and 2;
  - one raw block holding two tables gives two entries;
  - the julia-style and jupyter-style labels both give `pub` and the same digest.
- **Not recorded:** a prose table, a `CodeBlock` in a cell, an all-empty table, a `.qmd` with `engine: knitr` (GT1).
- **Captions:** a caption holding a named value gives the resolved sentence, and changing that value changes only the value's entry.
- **Stamp and ledger:**
  - the stamp's `named` and `checks` are unchanged by tables;
  - `ledger: false` writes no file;
  - control: a failing non-draft run writes no ledger.
- **Across Pandocs:** loop over `lua_pandocs()` and expect equal digests (GT4).
- **`changes()`:** two runs with one cell changed give E70 `table \`tbl-sites\` changed`, then E71 and E72, reusing the `test-changes-tables.R` scaffolding.

**`test-ledger-tables-engine.R`** has two slow renders:
- jupyter (`QUARTO_PYTHON`): a labelled `tbl-` cell with `IPython.display.HTML("<table>...")` and a `Markdown` pipe table. pandas is used only under `skip_if_no_py_module("pandas")`.
- julia engine: `display("text/html", ...)` and a Markdown table.

Each expects entries with the labels and the digests that the canonical text predicts.

### 5. Implementation notes

**Files.** All the work is in `inst/quarto/weft.lua`:
- a new `record_tables(blocks)`, built on `ledger.xxh3`;
- the `named` exclusion at `:2462`;
- `write_ledger()` already passes `e.printed` and `e.sentence`, so a table entry sets `printed` to the digest.

There is no Python, Julia or R code change except documentation (`PACKAGE-SCOPING.md` 7.1.1 and 7.1.4, 2.13; `dev/lua-parity.md`; the languages article; NEWS; N40 amended).

**Size and order.** It fits one implementer session, so no split is needed (G2b is deferred). Steps:
1. **Spike first:** a debug filter in a scratchpad copy that prints the block types, classes, ids and `tbl-cap` attribute that `weft.lua` sees for a labelled `tbl-` cell, on both engines. This settles whether Quarto's custom float nodes or its HTML table parsing have changed the structure before user filters run. If `.cell` does not survive, widen GT2 to Divs whose class starts `cell-output`.
2. The Lua.
3. The tests.

**Risks:**
- pure-Lua XXH3 speed on very large tables (pandas shows 60 rows by default);
- `pandoc.read` on unusual HTML (it is guarded with `pcall`).

### 6. Open question

1. Should G2b (Python and Julia tables in knitr documents) be built now? **Recommended default:** no. The ruling named Jupyter and Julia documents, and G2b needs output parsing on the R side.

---

### Critical files for implementation
- inst/quarto/weft.lua
- R/guest.R
- R/guest-julia.R
- inst/python/weft/_backend.py
- inst/julia/Weft/src/Weft.jl

Also touched: `inst/python/weft/__init__.py`, `inst/julia/WeftGuest.jl`, `inst/quarto/weftlib/config.lua`, `R/claim.R` (no change: `wrap_collected_error` is reused), `tests/testthat/test-chunk-claims.R` (N78 rewrite).
