# spike-failures: results

Root: `/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-failures/`
(abbreviated `SF/` below). quarto 1.11.9, knitr 1.51, macOS. "quarto" = `quarto render x.qmd --to html`;
"rmarkdown" = `rmarkdown::render()` (html_document unless stated). The unmodified stand-in is
`SF/docs/setup_orig.R` (copy of spike-grammar2/setup.R); the modified one is `SF/setup.R` (also copied to
`SF/docs/setup.R` and `SF/marker/setup.R`; the marker-style switch was added after `docs/setup.R` was copied, which does not matter for part 1/2 results).
Docs/logs for parts 1-2 are in `SF/docs/`, part 3 in `SF/marker/`, part 4 in `SF/conds/`.
`SF/docs/rr.sh <doc> qmd|Rmd` renders one doc and prints the exit status and files left; `WEFT_SETUP=setup_orig.R` selects the unmodified stand-in.

## (i) What I ran and saw

### 1. claim() in a chunk with error: true

Exit status is the process status of the render command. "output" = whether the .html was left on disk.
Logs: `SF/docs/t1_<case>.<qmd|Rmd>.<setup>.log`.

| Fact | Renderer | Observed | Shown by |
|---|---|---|---|
| UNMODIFIED stand-in, `error: true`, failing `claim()` in chunk: render SUCCEEDS | quarto html, rmarkdown html | exit 0, html written. Problem confirmed. | `t1_errtrue.{qmd,Rmd}.setup_orig.R.log` |
| UNMODIFIED, `tryCatch(claim(..), error=)` and `try(claim(..))`: render succeeds | both | exit 0, html written | `t1_tryCatch.*`, `t1_try.*` `.setup_orig.R.log` |
| UNMODIFIED, `error: false`: stops at once | both | exit 1, no html, single R error "claim failed: . > 0.5 was FALSE (value 0.3)" | `t1_errfalse.*.setup_orig.R.log` |
| FIXED, `error: true`: render fails at the end | both | exit 1, no html. Log: `Error: clag: 1 claim failed / t1_errtrue.qmd, chunk 'first'  claim() in chunk code / . > 0.5 was FALSE (value 0.3)` (Rmd analogous). quarto log shows chunks 4/7 [first] and 6/7 [second] both ran before the failure. | `t1_errtrue.*.setup.R.log` |
| FIXED, `error: true`: chunk shows the error, later chunk runs (seen in the knit output) | knitr::knit with `options(clag.draft=TRUE)` (report becomes a message so the .md is written) | .md has `## Error:` `## ! claim failed: ...` under the first chunk and `## SECOND CHUNK RAN` after it | `docs/t1_errtrue.draft.md` |
| FIXED, `error: false`: unchanged, stops at once, reported ONCE | both | exit 1, no html, only the R error + "Quitting from t1_errfalse.qmd:12-16 [first]"; no "clag: N claims failed" report (the document hook never runs) | `t1_errfalse.*.setup.R.log` |
| FIXED, `tryCatch(claim(..), error=function(e) "caught")`: failure still recorded, render fails | both | exit 1, no html; report lists the claim in chunk 'first'. The author's handler ran (the failure was caught) and the render fails anyway. | `t1_tryCatch.*.setup.R.log` |
| FIXED, `try(claim(..), silent=TRUE)`: same | both | exit 1, no html, claim listed | `t1_try.*.setup.R.log` |
| FIXED, passing claim in chunk: no change | both | exit 0, html written | `t1_pass.*` |
| Outside a knit (plain Rscript), `claim()` stops at once and records nothing | Rscript | `in_knit(): FALSE`; error "claim failed: . > 0.5 was FALSE (value 0.3)"; `length(clag$fails)` = 0 after | `SF/docs/plain.R`, `plain.out` |
| `knitr::current_input()` is NULL again after a knit ends | Rscript | printed `TRUE` for `is.null()` after `knit()` returned | ran inline, `SF/probe.Rmd` |

Mechanism (in `SF/setup.R`, function `claim()` and `in_knit()`):
- Knit in progress: `!is.null(knitr::current_input())`. `current_input()` is exported. It is non-NULL during `knit()` and NULL before/after (checked). Under quarto it returns the intermediate `x.rmarkdown`.
- Chunk code vs text hook: this does NOT come from knitr. The stand-in's own flag `clag$collecting` is TRUE only while `clag_text()` (the text hook, or `weft_str()`) is scanning; `claim()` collects there. If it is FALSE and a knit is in progress, the call is chunk code: record into `clag$fails`, then `stop()`.
- Chunk label for the report: `knitr::opts_current$get("label")` (exported). No non-exported knitr function is needed by the new code. (The existing prose line locator `clag_locator()` still uses non-exported `knitr:::knit_concord`; unchanged and not part of this part.)
- Location reported for a chunk-code failure is `<file>, chunk '<label>'`, not a line: I did not find a way to get the line of a call inside chunk code from exported functions.

### 2. Failed check inside weft_str()

`weft_str()` added to `SF/setup.R` (from spike-captions `clag_str`, but using no quotes in the location, see 3). Docs: `SF/docs/t2_str.{qmd,Rmd}`, `t2_bare.{qmd,Rmd}`.

| Fact | Renderer | Observed | Shown by |
|---|---|---|---|
| `weft_str()` with failing check in `labs(title=)` and `kable(caption=)`, plus a failing inline in prose: all three collected, render fails once at the end | quarto html, rmarkdown html | exit 1, no html. Report: `clag: 3 claims failed` listing `chunk plot-chunk`, `chunk kable-chunk`, and `t2_str.qmd:30` / `t2_str.Rmd:25`. Chunk `after` ran (7/9 etc. in log for quarto). | `t2_str.qmd.html.log`, `t2_str.Rmd.html.log` |
| Marker is in the ggplot title (draft mode so output is produced) | quarto html | Plot PNG title reads `mean depth 0.3**[weft: failed claim, chunk plot-chunk]** m` (asterisks literal, markdown not rendered) | `docs/t2_str_files/figure-html/plot-chunk-1.png` (note: the file is from the last quarto render; `t2_str.Rmd.plot.png` is the rmarkdown copy) |
| Marker in kable caption | quarto html, rmarkdown html | `<caption>Depth 0.3<strong>[weft: failed claim, chunk kable-chunk]</strong> m</caption>` (quarto) | `docs/t2_str.qmd.draft.html`, `t2_str.Rmd.draft.html` |
| Bare `claim()` in chunk code (error: false) still stops at once | both | exit 1, no html, R error + `Quitting from t2_bare.qmd:18-21 [bare]`; chunk `never` did not run | `t2_bare.{qmd,Rmd}.html.log` |
| Outside a knit `weft_str("... `r claim(0.3, . > 0.5)`{.num} ...")` stops at once, records nothing | Rscript | error `claim failed: error evaluating `claim(0.3, . > 0.5)`: claim failed: . > 0.5 was FALSE (value 0.3)`; fails recorded = 0. A passing one returns the string. | `docs/plain.out` |
| Using `weft_str()` outside a knit needed an extra switch: `ev()` catches the claim's error and turns it into a collected failure, so I added `clag$strict`, set when no knit is running, which makes `clag_collect()` re-stop. | Rscript | works as above | `SF/setup.R` (`clag_collect`, `clag_text`) |

### 3. The failure marker

Text-level tests: a template with the marker in each context, converted with `quarto pandoc` to html, typst, latex, docx, and inspected (`SF/marker/template.md`, `gen.py`, `check.py`, `cand_*.md|html|typst|latex|docx`).
Contexts in the template: title (single-quoted YAML), heading, paragraph, link text, table cell, bullet and numbered list, footnote, plus bold, emphasis, bold-italic, strikeout, a span, immediately followed by `(`, `[ref]`, `{.cls}`, at start of line, adjacent to code.
Integrated tests: a real document with failing claims (`SF/marker/int.qmd`, `int.Rmd`) in heading, paragraph, link text, table cell, list, footnote, bold, emphasis, chunk-option `fig-cap` via `weft_str()` and an evaluation error ("no value").

| Candidate | Result | Shown by |
|---|---|---|
| A: `**[weft: failed claim, line 412]**` | Survives as literal bold text, and is never read as a link, citation, span or reference, in: title, heading, paragraph, link text, table cell, list, footnote, caption, emphasis, followed by `(`, `[ref]` or `{.cls}` (html, docx, typst, latex checked at pandoc level; html, docx, typst checked in the integrated quarto doc). **BREAKS inside `**bold**`**: `**mean 0.3**[weft: ...]** m**` leaves the marker un-bold and two literal `**` in the output (html, docx, typst, latex all). In bold-italic (`***x***`) the marker survives but is not bold. Observed in html (quarto, rmarkdown), docx, typst. | `cand_a.html`, `cand_a.latex`, `cand_a.typst`, `int_q_bold.html`, `int_q_bold.docx` |
| A in a ggplot title | Literal `**` characters visible in the plot | plot PNG above |
| B: `\[weft: failed claim, line 412\]` (escaped brackets, no bold) | Fine under Quarto/pandoc in every context incl. inside bold. **BREAKS under rmarkdown**: rmarkdown's default markdown flags include `tex_math_single_backslash`, so `\[...\]` is parsed as display math. Rmd docx text became `weft:failedclaim,line11` (math, spaces lost), html became MathJax. Also a backslash is a YAML escape error in a double-quoted `title:`. | `cand_b.*`, `int_r_plain.docx`, `int_r_plain.html` |
| C: `[weft: ...]{.weft-marker}` | Pandoc consumes the brackets as span delimiters, so the visible text has no brackets. Not usable as is. | `cand_c.md` (checked via check.py) |
| H: unescaped `[weft: failed claim, line 412]` | Fine except when directly followed by `(`: becomes a link and loses the brackets (and `{.cls}` makes a span). `0.3[weft...](n=3)` is plausible prose. Rejected. | `cand_h.md` via check.py |
| **F (proposed): `<<weft: failed claim, line 412>>`** and `<<weft: no value, line 412>>` | In every context above, incl. inside bold, emphasis, link text, footnote, table cell, heading, caption, followed by `(`/`[ref]`/`{.cls}`. html: `&lt;&lt;weft: ...&gt;&gt;`; docx: literal; typst: `\<\<weft: ...\>\>`; latex: `\textless\textless weft: ...\textgreater\textgreater` (so no `<<` ligature; the LaTeX was NOT compiled, only produced). Integrated: 10 of 10 expected markers found in quarto html and docx; typst contains them. rmarkdown html and docx: markers present (counts 12 html (the caption appears in both caption and alt) and 11 docx). | `cand_f.*`, `int_q_angle.html`, `int_q_angle.docx`, `int_q_angle.typ`, `int_r_angle.html`, `int_r_angle.docx` |
| Candidate F cost | Not bold, so less eye-catching in rendered output. It is searchable with `<<weft:`. In a ggplot title it displays as typed (no stray asterisks or backslashes) by construction; I did not render a plot with it. | |
| Quote characters in the location | Pandoc's smart typography turned `chunk 'kable-chunk'` into curly quotes. Fixed by writing `chunk kable-chunk` (no quotes). | seen in my first run |
| Line numbers | quarto: `line 12` for the heading at `int.qmd` line 12 (mapped back to the authored .qmd); rmarkdown: `line 11` (no `#|` lines). Marker for a string made in chunk code uses `chunk <label>`. | `int_q_*.html`, `int_r_*.html` |
| Title in front matter | `title: 'Title `r claim(depth, . > 0.5)`{.dec1} m'` fails quarto html with `could not find function "claim"`: the YAML `r` is evaluated before the setup chunk runs, whatever the marker. Literal marker text in a title (not produced by weft) survives (cand_*.md). | `int.qmd` first attempt log; `cand_*` |

The stand-in's three marker call sites were changed from a constant to `mark_fail(ctx, pos)` and `mark_noval(ctx, pos)`; option `weft.marker` = `bold` (default), `plain` (B) or `angle` (F) switches the style for the experiment.

### 4. Matching conditions whose text varies

Scripts: `SF/conds/conds.R` (triggers, three runs: A = default, B = `width 60, cli.unicode=FALSE, useFancyQuotes=FALSE, cli.width=60`, C = same as A in a new process), `compare.R`, `classify.R`. Data: `conds_raw.rds`/`.csv` (A), `conds_raw_B.rds`, `conds_raw_C.rds`, `classified.csv`, `compare.out`.
Packages used (all installed): base, dplyr, tidyr, ggplot2, readr, lme4, mgcv, glmmTMB, cli, stringr, lubridate, lifecycle, data.table, sf.
Counts (run A): 83 conditions captured by a calling handler: 56 warnings, 16 messages, 11 errors. Errors are not logged by weft and are excluded from counts below; 72 warning/message conditions, 58 distinct texts. Some triggers I wrote did not yield a condition (for example `gam.check` and `mgcv-conv` only printed or errored) and are simply absent.
Four texts are synthetic (my own `message()`/`warning()` calls shaped like real ones, not produced by a package): the time message, the `<environment: 0x...>` message, a German string and a curly-quote string. The rest are real conditions from the packages.

Normalisation tested.
- N1 (the proposal): replace every run of digits, with decimal part(s), sign and exponent, by `<N>`: `[-+]?(?:[0-9]+(?:\.[0-9]+)*(?:[eE][-+]?[0-9]+)?|\.[0-9]+(?:[eE][-+]?[0-9]+)?)`. My first regex `[0-9]+\.?[0-9]*` turned `xyz_9917.csv` into `xyz_<N>csv`, eating the full stop; the fixed form needs digits after the point.
- N2 (what I recommend adding): strip ANSI (`\033[...m`), fold curly quotes to straight, replace `0x...` hex and `.../RtmpXXXX/...` temp paths, map cli's Unicode bullets/rules to their ASCII fallbacks (`ℹ`->`i`, `•`->`*`, `✖`->`x`, `✔`->`v`, runs of `─` or `-` -> `--`), collapse all whitespace (incl. newlines) to one space, then N1.

Run-to-run stability (same settings, new process; 72 paired conditions):

| Normalisation | Conditions identical between run A and run C |
|---|---|
| none | 68 of 72 (4 differ: time, hex address, temp path in a base warning, temp path in a cli warning) |
| N1 digits only | 69 of 72 (only the time message is fixed; the other three differ by letters in the temp dir name, tempfile name, or hex address) |
| N2 | 72 of 72 |

Settings stability (run A vs run B, same code, different console width, UTF-8 vs ASCII cli output, fancy quotes off):

| Normalisation | identical |
|---|---|
| none | 45 of 72 |
| N1 digits only | 46 of 72 |
| N2 without the bullet/rule mapping | 64 of 72 (8 differ: cli bullets `ℹ`/`•` and `──` vs `i`/`*`/`--`) |
| N2 | 72 of 72 |

Classification of the 58 distinct texts (the digit outcome; digits changed or not, and whether the substance was a digit):
- (a) digits vary or are present and neutralising is right or harmless: 28 texts. Examples: `Removed 37 rows containing missing values...` and `Removed 38 rows...` -> `Removed <N> rows...`; `max|grad| = 0.0826208 (tol = 0.002, component 1)` ; `Fitted at 16:26:14 in 0.42 secs`; `Row 1 of x matches multiple rows in y`; `1 parsing failure.`; `Rows: 2 Columns: 3`; `bins = 30`.
- (b) a number that is the substance is lost, so different problems match: 9 texts (rows with these texts). Real collisions seen in my data:
  - `Expected 2 pieces. Missing pieces filled with NA in 1 rows [2]` (tidyr::separate into 2 columns) and `Expected 3 pieces. Missing pieces filled with NA in 2 rows [1, 2]` (into 3 columns) give the same key.
  - `convergence code 4 from Nelder_Mead` vs another code from the same optimiser would match (I only got code 1 from bobyqa and code 4 from Nelder_Mead, which differ in the optimiser name, so I saw no actual collision for this one; the text pattern is the risk).
  - glmmTMB `dropping columns from rank-deficient conditional model: I(x * 2)` and `... I(x * 3)` (both produced, texts differ only by the number) give the same key.
  - Same effect for magnitude: `Removed 5 rows` and `Removed 5000 rows` match (the 28 (a) rows include this; I count it as (a) because the problem is the same, but a big jump in size is invisible). The `lme4` `max|grad|` value and `tol` are in the same position.
  - Not logged by weft, but the same pattern: `Can't select columns... Column x1 doesn't exist` vs `x2` (both produced as errors).
- (c) something else varies that digits do not cover: observed to vary between runs/settings after N1 in 23 of the 58 distinct texts, by cause:
  - Line wrapping (width-dependent, in cli, tidyr, dplyr, ggplot2 and readr messages): the largest group. Appears when the console width changes. Under knitr the width is whatever `options(width)` is, so it can differ between machines or between quarto and rmarkdown.
  - cli Unicode bullets and rules (`ℹ`, `•`, `──`) vs ASCII in a non-UTF-8 session: dplyr, tidyr, readr, purrr messages.
  - Temp path `/var/folders/.../RtmpXXXX/fileNNNNNN.csv` (base and cli): varies by letters as well as digits, so N1 leaves it different.
  - Hex address (`<environment: 0x...>`): letters and digits mixed.
  - Curly vs straight quotes (`use of the ‘data’ argument` vs `'data'`): glmmTMB (R's own `useFancyQuotes`).
  - Locale-dependent words: a real German message (`NAs durch Umwandlung erzeugt` vs `NAs introduced by coercion`) under `LANGUAGE=de`; text differs entirely, no normalisation fixes this other than fixing the language.
  - ANSI styling: `\033[1m...` appeared only because I forced `cli.num_colors=256`; knitr and quarto render with no colour, so I did not see it vary on its own. N2 strips it.
  - Time of day: neutralised by N1 (digits).
- (none) no digits, unaffected: 21 texts (`NaNs produced`, `longer object length is not a multiple of shorter object length`, `NAs introduced by coercion`, `boundary (singular) fit: see help('isSingular')`, `Joining with `by = join_by(k)``, ...). `glm.fit: fitted probabilities numerically 0 or 1 occurred` falls in (a) because of the `0 or 1` digits (harmless, constant).
(28 + 9 + 21 = 58; the 23 (c) texts overlap with these three groups, since a text can have a digit effect and a non-digit effect; wrapped texts are mostly in (a) or (none).)

Recommendation (smallest set I saw to be necessary): N1 (digits, with the fixed regex) is not enough on its own, 3 of the 4 run-to-run differences and 26 of the 72 conditions in the cross-setting comparison still differ. The smallest set that gave 72 of 72 in both comparisons: N1 + collapse whitespace (wrapping) + fold curly quotes + map cli bullets/rules to ASCII + replace `0x` addresses and `RtmpXXXX` temp paths. ANSI stripping is cheap and avoids a future surprise.
Cannot handle: locale-translated messages; numbers that carry meaning (`Expected 2 pieces`, convergence codes, `I(x * 2)`, magnitude of `Removed N rows`); messages that embed a path other than a temp path, a package version, a date, or a data value; messages whose wording changes when a package is upgraded (the baseline goes stale, as it should); identical text from two different calls in the same chunk.
Mitigation is available because matching is by chunk label plus text: a collision only matters inside one chunk.

## (ii) What I did not run

- LaTeX/PDF compile: only `quarto pandoc -t latex` text output was inspected, no TeX engine run, so font behaviour is unverified.
- Part 1 and 2 under docx/typst: html only. Part 3 integrated docs: quarto html, docx, typst; rmarkdown html and docx. Not rmarkdown pdf/typst.
- Part 3 integrated typst for the bold marker: `int.typ` is overwritten by each render, so the typst text shown for the bold style is from pandoc-level `cand_a.typst`, not from the integrated doc. `int_q_angle.typ` is a saved copy of the integrated typst for style F.
- A plot with the angle marker in the title (only reasoned from the string).
- `knit_child()`, `eval = FALSE` chunks, a claim inside a function defined in a package and called from chunk code, and `claim()` in an `eval.after` option (caption) when evaluated by knitr itself, under the fix.
- Front-matter title containing a construct under rmarkdown.
- mgcv: most of my mgcv triggers errored or only printed, so mgcv contributed 0 warning/message texts to part 4. `dplyr` `filter()`-type and `across()` warnings did not fire. No vroom/readr column-spec colour output.
- A normalisation designed to survive a package upgrade; no cross-version data.

## (iii) Surprising, or not implementable as written

1. With the fix, a failing `claim()` in chunk code when `error: false` is recorded and stops at once, but the end-of-document report never runs, so only the R error appears. Nothing is reported twice, but a failure collected EARLIER (for example from a `weft_str()` or from prose in an earlier chunk) is lost from that run's report; observed in `t2_bare`: the failing `weft_str()` in chunk `s` is not listed, only the bare claim in chunk `bare`. Fixing would need an `on.exit`/error handler to flush the collector when a knit stops; not tried.
2. A recorded failure survives `tryCatch`/`try` (reported plainly above): an author cannot suppress or handle a failed claim in chunk code. A deliberate negative test (`expect_error(claim(...))`, `tryCatch(claim(...))` to show a fallback) now fails the render during a knit.
3. The bold marker `**[weft: ...]**` is NOT safe inside `**bold**` (leaves literal `**`), and `\[weft: ...\]` is NOT safe under rmarkdown (`tex_math_single_backslash`). A bracket-free marker (`<<weft: ...>>`) was the one that passed everywhere I tried, at the cost of not being bold. Bracketed markers followed immediately by `(` become links.
4. A construct in front-matter YAML cannot work: knitr evaluates inline R in the YAML before any setup chunk installs the hooks (`could not find function "claim"`).
5. The proposed digit rule needs care: the naive `[0-9]+\.?[0-9]*` swallows the full stop of `xyz_9917.csv`; and N1 alone does little for stability in practice because most run-to-run variation I saw was layout (wrapping, bullets, quotes) and paths, not digits.
6. `weft_str()` outside a knit needed an extra "strict" flag, since the stand-in's evaluator catches `claim()`'s own error and turns it into a collected failure; the proposed rule is implementable but not by `collecting=FALSE` alone.
7. In a weft_str string made in chunk code there is no line number to report, only the chunk label (and, for options, the option name when passed).
