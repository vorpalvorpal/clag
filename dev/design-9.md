# Design 9: formatters that write TeX (a general output target)

Designed 14 Nov after v0.1.0, on the owner's ruling that a class block
should work inside math ("I think it is worth doing to keep consistency.
Yes, do it."). Adopted with these rulings by the orchestrator:

- The four open questions of T1 and the one of T2 take the recommended
  default: unit characters such as the degree and micro signs pass
  through inside `\text{}`; the `{,}` thousands mark stays although
  Typst output shows a space after it (a texmath defect); a range in
  math always says "to"; `\(...\)` and `\[...\]` are math in `.Rmd`
  files; the filter resolves named values in raw TeX that is not math.
- Rule number 1.4.22 is taken by the options of project formatters
  (`dev/design-formatter-options.md`). Where this design says 1.4.22,
  read 1.4.23.
- TX8 is built on the options design: a registration's `targets:` key
  sits beside `options:`, and `target` reaches the function as the
  weft-supplied argument of PF14, after any options.
- Build order: the options of project formatters first (both touch
  `R/format.R`), then P1 to P6.

## What I found and what I recommend

- **Today.** A value inside math either fails or prints the wrong thing.
  - A class block in `$…$` or `$$…$$` is a construct error (message at `R/scan.R:1316`).
  - The documented workaround, `` `r fmt_num(x)` ``, puts markdown into TeX. `−1,234` gets punctuation spacing ("1, 234"). `.sci` writes `10^6^`, which is a double-superscript error in LaTeX.
  - Raw LaTeX math environments are not treated as math at all. Inline R inside `\begin{align}` is read as prose, a class block there formats as markdown, and nothing reports an error.
- **What to build.** A `target` mechanism with two values now: `"markdown"` (the default, byte-for-byte today's output) and `"tex"`.
  - It applies wherever the scanner knows a value sits in math or raw LaTeX.
  - The R route is phase 1 (T1). The named-value route in the Lua filter is phase 2 (T2).
- **New numbers.** Decisions continue from D65. Messages start at E95, since E94 is retired and the other "E9x" and "E100" strings in the code are hex constants. New spec rules are 1.4.22, 3.4.11, 4.4.25 and 2.13.16, and 5.2.6 is rewritten.
- **One fact the brief needs corrected.** The finding-21 change has landed on `main` (commits 6724eff to 1fe7c1e). The current math message is the "clearer" one at `R/scan.R:1316`, and design 9 replaces it.
- **Two places where I depart from what the brief allowed for. Please confirm both.**
  - **Unit characters are not ASCII.** Characters such as °, µ and Ω inside `\text{}` pass through unchanged. These come from the units database or the project's `units:` table, not from weft's own marks. The ASCII stand-ins I tried each go wrong somewhere: `\mu` is italic, `^{\circ}` comes out as a ring operator in docx and Typst, and `\mathrm{°}` breaks under pdflatex. pdflatex already handles the real characters through `add_latex_minus()` (`R/hooks.R:134`).
  - **Ranges in math always say "to"** (`1.2\ \text{to}\ 3.4`), even for two positive ends. No ASCII en dash works in all four renderers. A dash between two numbers in a formula also reads as subtraction.
- **What I could not check.**
  - I had no KaTeX or MathJax install to test with. The claims below about those two renderers come from their documentation, not from a probe.
  - In Typst output, texmath turns `{,}` into an escaped comma, so Typst shows "1, 234". That is a defect in texmath's Typst output, and `{,}` is still the right TeX.

## Probes (Pandoc 3.8.3, Quarto 1.11.9 with its Pandoc 3.10 and Typst 0.15.1, TinyTeX)

Scratch files are in `/private/tmp/claude-501/-Users-rjs-dev-clag/329c9209-b43a-4fb0-b9e7-58be3c9db721/scratchpad/texmode/`.

- **Forms that pass everywhere.** These convert with no warning to docx (OMML), Typst and MathML, and compile clean under pdflatex: `-1{,}234{,}567.9`, `12.3\%`, `1.2 \times 10^{6}`, `-1.2 \times 10^{-4}`, `p < 0.001`, `q = 0{,}030`, `1.2\ \text{to}\ 3.4`, `5\,\text{mg/L}`, `5\,\text{m}^{-3}`, `20\,\text{°C}`, `45\text{°}`, `5\,\text{µm}`, `5\,\text{kg}{\cdot}\text{m/s}^{2}`, `5\ \text{milligrams per litre}`, `30\%`, `5\,\text{CFU/100}\,\text{mL}`, `30{}^{\prime}`, `\text{pH}\,7`, `\$5`, `1\text{'}234`, `5\text{<<weft: failed claim, line 3>>}`.
- **Forms that fail.**
  - texmath rejects `\textendash`, `\text{\textendash}`, `\text{\textmu m}` and `\mathrel{\text{to}}` (the last is an error in Typst).
  - `\text{ to }` gets double spacing in texmath.
  - `{'}` and `'` print as a prime.
  - `\mathrm{°C}` and `\mathrm{µm}` print ř and ţ under pdflatex.
  - `\,` as a thousands mark comes out right in LaTeX and Typst; ` 1\,234\,567{,}9` gives "1 234 567,9" in LaTeX.
- **Renderers whose `\text{}` reads no macros.** MathJax (2 under rmarkdown; 3 `tex-chtml-full` under Quarto, without textmacros) shows `\text{}` content literally. So weft never writes a macro inside `\text{}`.
- **Pandoc and Quarto leave math text alone.**
  - Pandoc keeps backticks and braces verbatim inside `Math`: `` $p = `p_val`{.p}$ `` becomes `Math InlineMath "p = `p_val`{.p}"`. Quarto's Pandoc gives the same AST.
  - `\begin{align}…\end{align}` becomes a `RawInline (Format "tex")`. The HTML writer emits it as display math. docx and Typst drop it.
- **rmarkdown reads `\(…\)` as math; Quarto does not.** rmarkdown's `from` is `markdown+autolink_bare_uris+tex_math_single_backslash`, so `\(…\)` and `\[…\]` are math there. Under Quarto they are escaped brackets. Today the scanner treats `\(` as an escape (`R/scan.R`, `"\\" = p + 2L`), while `R/lint-source.R:503-504` already treats both forms as math regions.

---

# T1 (phase 1): the knitr route

## 1. How it works today

- **Scanner.**
  - `scan_seq` calls `math_end()` (`R/scan.R:242`) and `scan_math()` (`R/scan.R:~1150`), which reads only backtick spans.
  - It then calls `handle_code(…, in_math = TRUE)`, then `inline_row()`. When a block follows, `inline_row()` adds the 5.2.6 error at `R/scan.R:1316`.
  - Named values in math are skipped: `handle_named(skip = in_math || in_target)`.
  - Rows carry no flag saying they sit in math (`finish_scan`, `R/scan.R:1421`).
- **Formatting.**
  - `render_value()` (`R/resolve.R:753`) calls `apply_formatters()` (`R/format.R:639`).
  - The marks come from `print_one()`, using `cfg$minus`, `big_mark`, `decimal_mark` and `thousands_from`.
  - `format_numbers()` adds `%` and `+`.
  - `sci_one()` writes `" × 10^"exp"^"`.
  - `print_p()` writes `label rel value`.
  - `collapse_range()` writes an en dash, or " to " when either end is negative.
  - `unit_affix()` writes U+00A0 plus `unit_symbol_text()` (markdown: `^n^`, U+2212, U+00B7, `md_escape`) or `unit_name_text()`.
  - Text classes add `*`/`**`. `passthrough()` writes `[text]{.cls}`.
- **Markers.** Failures append `marker()`, which writes `<<weft: KIND, line N>>` (`R/state.R:115`).
- **Ledger.** Entries come from `make_entry` (`R/resolve.R:1169`). The key is file, section, kind and expr (`R/ledger.R:423`); context and text are fields.
- **Configuration.** `decimal_mark`, `big_mark` and `minus` are free strings (`R/config.R:41-57`). There is no locale setting and no setting for a space before `%`. `p_label` is a string, default `p`.
- **Phrases.** `ci()`, `pm()`, `of_n()` and `about()` return finished wording. A number class on them is already a value error (`R/format.R:735`).

## 2. Decisions

| # | Question | Options | Chosen | Why |
|---|---|---|---|---|
| D65 | Who decides the mode | knitr hook; post-processing the output; the scanner | the scanner, through a row column `tex` | it already finds math; the decision is static, so the lints and the gate see it |
| D66 | Name of the switch | `tex = TRUE`; `target = "tex"` | `target`, values `"markdown"` and `"tex"`; more later | adding targets later changes no signature |
| D67 | Minus | map `cfg$minus`; always ASCII `-` | `-` | `-` is TeX's minus sign in math; `minus` stays a prose setting |
| D68 | Comma mark | `{,}`; `\text{1,234}`; `\mathord{,}` | `{,}` | the LaTeX idiom; texmath fails on `\mathord{,}`; `\text` changes the digit font |
| D69 | Ranges | `\text{--}`; `\text{–}`; `\textendash`; "to" | `\ \text{to}\ ` always | see above: MathJax shows `--`, texmath fails `\textendash`, `–` is not ASCII |
| D70 | Units | `\mathrm{}`; `\text{}`; siunitx | `\text{}`; `\,` before a symbol, `\ ` before a name | `\mathrm` breaks °/µ under pdflatex and drops spaces in names; siunitx is not core or texmath |
| D71 | Words, emphasis, collapse classes in math | error; wrap in `\text{}` | error, found from the source | a formula holds numbers; relaxing an error later breaks nothing, the reverse would |
| D72 | `.p` label | verbatim everywhere; converted everywhere | the setting is converted; an explicit `label` (key or argument) is TeX, verbatim | the setting is shared with prose; a key written inside math is the author's TeX |
| D73 | Project formatters | error always; detect a `target` formal; `tex_function:` | `targets: [markdown, tex]` plus a `target` argument | explicit and static; one function serves every target |
| D74 | Public API | `target` on the number `fmt_*()` only; on all | all `fmt_*()`, last argument; no-TeX classes error | the signature is fixed once |
| D75 | Bare inline R in math | auto-TeX a `weft_text`; unchanged | unchanged (stock print) | rule 1.1.8; a new tier-2 `value-format` finding points to the class block |
| D76 | Raw LaTeX | error; defer; include | math environments and `\(…\)`/`\[…\]` in `.Rmd` are math; `{=latex}`/`{=tex}` fences and spans and other `\begin{…}` are TeX inside `\ensuremath{…}` | knitr evaluates in all of them; `\ensuremath` is safe in LaTeX text and math mode |
| D77 | Markers in TeX | as today; split the math | `\text{<<weft: KIND, line N>>}` | stays valid TeX; `weft-check` already reads Math text (`weft-check.lua:203`) |
| D78 | Ledger | new field; new key; context | `text` is the TeX printed; `context` is `"math"` or `"tex"` | no schema change; the key is unchanged |
| D79 | A TeX text later printed in markdown | allow; error | value error E103 | it would show TeX source in prose |
| D80 | Conformance | sixth column; new set | new set `tex.tsv`, with pseudo-key `target=tex` | the four-tab line format is pinned by `test-conformance-6f.R` |

## 3. Specification

**TX1 (where).** A row gets `tex` (character): `""` for prose, `"math"`, or `"raw"`.

- `"math"`:
  - inline or display `$` math, as `math_end()` finds it;
  - `\begin{NAME}…\end{NAME}` in prose, where NAME is one of: equation, align, alignat, gather, multline, flalign, eqnarray (each also with `*`), math, displaymath, aligned, alignedat, gathered, split, cases, array, matrix, pmatrix, bmatrix, Bmatrix, vmatrix, Vmatrix, smallmatrix, subarray, CD. The end is the matching `\end` with nesting of the same name counted;
  - in a `.Rmd` (or a knit by rmarkdown, not Quarto): `\(…\)` and `\[…\]`.
- `"raw"`:
  - any other `\begin{NAME}…\end{NAME}` in prose;
  - the body of a fence whose info string is `{=latex}` or `{=tex}`;
  - a code span followed by `{=latex}` or `{=tex}`.
- Everywhere else stays as today. `{=typst}` and `{=html}` fences keep rule 1.1.10 (markdown). Raw inline commands such as `\textbf{…}` stay prose and are a known gap.

Inside a `"math"` or `"raw"` region only inline R and named values are read. A bracket is never a span there.

**TX2 (classes that work).** In a `tex` region a class block may hold:

- `.num`, `.pct`, `.sci`, `.p`, `.plus`, `.range`, `.uname`, `.usym`, `.nounit`;
- an `#id`;
- the keys `digits`, `sigfig`, `unit`, `label` and `why`;
- a project class whose entry lists `tex` in `targets:`.

Anything else is a construct error from the scanner. There is one message per offending class or key, in the order written. PLACE is `math` or `raw LaTeX`:

- **E95** (`.word .count .ord .no .date .a .cap`, and `.val` on an R value): "`%s` cannot be used inside PLACE: it prints words, and a formula holds numbers. Move the value out of the PLACE, or use a number class such as `.num` (rule 5.2.6)."
- **E96** (`.em .strong`): "`%s` cannot be used inside PLACE: it is markdown emphasis, and PLACE is TeX. Put \mathbf{} or \mathit{} around the value in the formula (rule 5.2.6)."
- **E97** (`.and .or .pairs .ul .ol .dl`, and the keys `sep`, `last`, `trunc`, `none`): "`%s` cannot be used inside PLACE: it joins items into a phrase or a list. Use `.range` for two ends, or move the value out of the PLACE (rule 5.2.6)."
- **E98**: "The project formatter `%s` cannot be used inside PLACE: its entry under `formatters:` in _weft.yml does not list `tex` in `targets:` (rule 5.2.6)."
- **E99** (a class or key that is not weft's): "`%s` cannot be used inside PLACE: it is not weft's, so weft would put the value in a Pandoc span, and PLACE has none. Drop it, or move the value out of the PLACE (rule 5.2.6)."

**TX3 (target).**

- `apply_formatters(…, target = "markdown")`. Every `fmt_*()` gets `target = "markdown"` as its last argument. That includes `fmt_unit()`, `fmt_cap()`, `fmt_a()`, `fmt_em()` and `fmt_strong()`.
- Any other value is a `weft_construct_error`, **E100**: "`target` must be \"markdown\" or \"tex\"; got %s." Here %s is the value in double quotes, or `something else`.
- Under `"tex"`, a class from the E95–E97 lists is **E101** (`weft_construct_error`): "`%s` has no TeX form (target = \"tex\"): %s (rule 3.4.11)." The second %s is "it prints words", "it is markdown emphasis" or "it joins items into a phrase or a list".
- A result made under `"tex"` carries the attribute `target = "tex"`. Under `"markdown"` there is no attribute, so today's objects stay identical.
- If such a text reaches a markdown result without being re-formatted from its raw value (a pass-through, a text class, a collapse), it is a `weft_value_error`, **E103**: "This text was formatted for TeX (target = \"tex\") and would print here as markdown. Format the number again, without `target` (rule 3.4.11)."
- The resolver passes `target = "tex"` for rows whose `tex` is not empty. A `"raw"` row's whole output, markers included, is wrapped in `\ensuremath{…}`.

**TX4 (marks under `"tex"`).**

| Element | TeX |
|---|---|
| minus (any `cfg$minus`) | `-` |
| explicit plus | `+` |
| big or decimal mark `""` | `""` |
| mark `,` | `{,}` |
| mark `.` | `.` |
| mark U+0020, U+00A0, U+2009 or U+202F | `\,` |
| mark `'` or U+2019 | `\text{'}` |
| mark U+00B7 | `{\cdot}` |
| any other mark | `tex_text(mark)` (TX6) |

`thousands_from` and the year rule are unchanged. If both marks map to the same TeX, the decimal mark is written `\text{<mark>}`.

**TX5 (outputs, default configuration, target tex).**

| Input | Output |
|---|---|
| `.num` −1234567.89 | `-1{,}234{,}567.9` |
| `.num` 999.95 | `1{,}000.0` |
| `.num` 3 | `3` |
| `.num digits=2` 0.5 | `0.50` |
| `.num` 0.04 | `0.0`, plus warning "0.04 printed as 0.0: add sigfig to show it, or digits to confirm it" |
| `.num .plus` 3 / −3 / 0 | `+3` / `-3` / `0` |
| `.pct` 0.123 | `12.3\%` |
| `.pct .plus` 0.05 | `+5\%` |
| `.pct` 0.0004 | `0.0\%`, plus warning "0.04% printed as 0.0\%: add sigfig to show it, or digits to confirm it" |
| `.sci` 1234567 | `1.2 \times 10^{6}` |
| `.sci` −0.000123 | `-1.2 \times 10^{-4}` |
| `.sci` 0 | `0` |
| `.sci` 1 | `1 \times 10^{0}` |
| `.sci` 9.96 | `1 \times 10^{1}` |
| `.sci digits=2` 12345 | `1.23 \times 10^{4}` |
| `.p` 0.0001 / 0.03 / 0.5 / 0.995 | `p < 0.001` / `p = 0.030` / `p = 0.50` / `p > 0.99` |
| `.p label=""` 0.5 / 0.995 | `0.50` / `> 0.99` |
| `.p label="\tilde{p}"` 0.046 | `\tilde{p} = 0.046` |
| `.range` c(1.23, 3.45) | `1.2\ \text{to}\ 3.5` |
| `.range` c(−1, 3) | `-1\ \text{to}\ 3` |
| `.range` c(2, 2) | `2` |
| `.range .plus` c(1, 3) | `+1\ \text{to}\ +3` |
| `.num` c(1.5, 2) | `1.5, 2` |
| `clamp(0.004, floor = 0.01)` with `.num` | `< 0.01` |
| `.num` on `weft_year` 2024 | `2024` |
| `.num` NA, in a collected render | `\text{<<weft: no value, line N>>}` |

**The setting `p_label` under TeX** becomes:

- `p` → `p`
- `*p*` → `p` (one ASCII letter, optionally inside one pair of `*` or `_`, becomes the bare letter)
- `""` → no label
- `adj. p` → `\text{adj. p}`
- `p_adj` → `\text{p}\_\text{adj}`

**With other configurations**, 1234567.89 under `.num` prints:

- `decimal_mark: ","` and `big_mark: "."` → `1.234.567{,}9`
- `big_mark: " "` → `1\,234\,567.9`
- `big_mark: "'"` → `1\text{'}234\text{'}567.9`
- `big_mark: ""` → `1234567.9`

`.p` 0.0001 under `decimal_mark: ","` gives `p < 0{,}001`.

**TX6 (`tex_text(s)`, for labels, names and fallback marks).**

- Maximal runs of ordinary characters become `\text{run}`. Ordinary means anything not listed below; spaces and non-ASCII characters are ordinary.
- The other characters map singly:

| Character | TeX |
|---|---|
| `\` | `\backslash` |
| `{` | `\{` |
| `}` | `\}` |
| `$` | `\$` |
| `%` | `\%` |
| `&` | `\&` |
| `#` | `\#` |
| `_` | `\_` |
| `^` | `\hat{}` |
| `~` | `\sim` |
| `<` | `<` |
| `>` | `>` |
| `|` | `|` |
| U+00A0 | `\,` |

**TX7 (units under TeX, rule 4.4.25).** The symbol text is converted from its markdown form:

- `\X` becomes the literal X.
- `^…^` becomes `^{…}` and `~…~` becomes `_{…}`, with U+2212 written `-`.
- U+00B7 → `{\cdot}`; U+00A0 → `\,`.
- U+2032 and `'` → `{}^{\prime}`; U+2033 and `"` → `{}^{\prime\prime}`.
- `%$&#{}<>|` map as in TX6. Runs of everything else go inside `\text{}`.
- Any unescaped `*`, `_`, `` ` ``, `[` or `]` that is left (only possible in a project `symbol:` or `name:`) is a value error, **E102**: "The unit `%s` prints as \"%s\", which holds markdown with no TeX form (only ^...^, ~...~ and backslash escapes have one). Give it a plain `symbol:` or `name:` under `units:` in _weft.yml to use it in math (rule 4.4.25)."
- A symbol after a number: `\,` when the unit's space is on, else nothing. A name: `\ `. Before a number: the symbol plus `\,` (or nothing), or the name plus `\ `.

| Value | Output |
|---|---|
| u(5,"mg/L") | `5\,\text{mg/L}` |
| u(5,"m^2") | `5\,\text{m}^{2}` |
| u(5,"m-3") | `5\,\text{m}^{-3}` |
| u(5,"s^-1") | `5\,\text{s}^{-1}` |
| u(20,"degC") | `20\,\text{°C}` |
| u(45,"°") | `45\text{°}` |
| u(5,"kg*m/s^2") | `5\,\text{kg}{\cdot}\text{m/s}^{2}` |
| u(30,"%") | `30\%` |
| u(5,"CFU/100mL") | `5\,\text{CFU/100}\,\text{mL}` |
| `.uname` u(5,"mg/L") | `5\ \text{milligrams per litre}` |
| `.uname` u(1,"m") | `1\ \text{metre}` |
| `.nounit` | `5` |
| `.range` u(c(1.2,3.4),"m") | `1.2\ \text{to}\ 3.4\,\text{m}` |
| a project unit `pH` with `before: true`, 7 | `\text{pH}\,7` |
| `fmt_unit(u(5,"mg/L"), target = "tex")` | `\text{mg/L}` |

**TX8 (project formatters, rule 1.4.8).**

- A new registration key `targets:` lists target names. The default is `[markdown]`. It must include `markdown` and only known targets, else **E104** (`weft_config_error`): "The formatter `%s` has `targets: %s`; `targets` lists markdown and, optionally, tex (rule 1.4.8)."
- When it lists more than markdown, the function is called `fn(x, target = target)` for every target, and must have a formal `target` or `...`, else **E105** at resolution: "The formatter `%s` lists tex in `targets:`, so its function `%s` must take an argument `target` (rule 1.4.8)."
- When it lists markdown only, the call is `fn(x)` as today.

**TX9 (markers).** Under TeX every marker is written `\text{<<weft: KIND, line N>>}`.

**TX10 (ledger).**

- `text` is exactly what weft wrote, wrapper included.
- `context` is `"math"` for `tex == "math"` and `"tex"` for `"raw"`, but only where it would otherwise be `"prose"`. Captions, front matter and `weft_str` keep their context.
- The key is unchanged. `changes()` shows a value moved into math as a text change.
- An id defined in math stores the markdown governor record, as today.

**TX11 (other checks).** Rows with `tex` set are never sentence starts (5.10.1), and `typed_after()` does not run on them. A bare value in math prints as stock prints it (1.1.8). The phrase functions get no target.

**TX12 (lints).**

- The `construct` lint reports E95–E99.
- `lint-source` regions add the math environments (and `\(`/`\[` already) as `math`, so 5.2.6's exponent exemption applies there.
- `value-format` (tier 2, 5.6.4) adds a finding: a bare value in a `tex` region whose outermost call is a weft `fmt_*()` without `target = "tex"`. Message: "The value in math is formatted with `%s()`, which writes markdown (rule 5.6.4)." Hint: "Give it a class block, `` `r x`{.num} ``, which writes TeX in math."

**TX13 (spec rewrite).**

- 5.2.6 becomes: a class block works in math and raw LaTeX with the TX2 classes, and formatters write TeX there (1.4.22).
- 1.9.1, 2.10.1 and 5.3.1 are rewritten to match.
- New rules: 1.4.22 (TX4–TX6, TX9), 3.4.11 (TX3), 4.4.25 (TX7).

**`weft_str()`.** It needs no `target` now: math inside the string already gets TeX through TX1. When whole-string targets ("plain", "ansi") come, it should take `target` by the same name, with `"tex"` meaning "the whole string is math".

**A "plain" target, as a sanity check only (not to be built).** It would change only these leaf points:

- marks: Unicode minus; `,` for thousands;
- `.sci`: `1.2 × 10⁶`, `−1.2 × 10⁻⁴` (Unicode superscripts);
- units: `5 m²`, `5 m⁻³`, `kg·m/s²`, with no markdown escapes;
- `.pct`, `.p` and ranges: as in markdown;
- words: unchanged;
- `.em` and `.strong`: no markers;
- `.ul`/`.ol`/`.dl`: plain lines;
- markers: as today.

So the mechanism should be one internal table of target forms (marks, exponent, unit converter, range joiner, emphasis, list block, marker). A new target is then one row in that table plus one value in `TARGETS`.

## 4. Tests

- **`test-tex-format.R`** (P1):
  - every row of TX5 and TX7, and the mark table;
  - E100, E101, E103, E104, E105, E102 (with a project `symbol: "*x*"`);
  - markdown outputs identical to today for the same inputs;
  - `attributes()` unchanged under markdown.
- **`test-tex-scan.R`** (P2):
  - the `tex` column for `$`, `$$`, each named environment, `align*` nested inside `align*`, `\(` in `.Rmd` versus `.qmd`, `{=latex}` and `{=tex}` fences, `` `…`{=latex} `` spans, `\begin{tabular}` (raw), `{=typst}` (`""`);
  - E95–E99 texts with PLACE math and raw LaTeX;
  - named values in math produce no row in P2 (T2 adds them).
- **`test-tex-knit.R`** (P2, knit through the existing helpers):
  - `$x = `r v`{.num}$`;
  - `\ensuremath` in a `{=latex}` fence;
  - a draft marker form;
  - ledger `context`/`text`;
  - no sentence-start note;
  - `weft_str("$a = `r v`{.pct}$")` gives `$a = 12.3\%$`;
  - the TX12 lint finding.
- **`test-tex-render.R`** (P3; slow; `skip_on_cran`, skip without Pandoc). One Rmd with `.num`, `.pct`, `.sci`, `.p`, `.range`, units in `$`, `$$` and `align`, rendered to:
  - HTML: assert the exact TeX inside `class="math`;
  - `word_document`: unzip `word/document.xml`; assert the `m:t` runs (e.g. `[−][1][,][234]`, `[×]`, `[ to ]`, `[mg/L]`), and that stderr has no "Could not convert TeX math";
  - `rmarkdown::latex_document()`: grep the `.tex`;
  - Quarto `format: typst` with `keep-typ: true`: assert `upright("mg/L")` and a clean compile (bundled Typst).
- **`test-conformance-tex.R`** (P4): `tex.tsv` equals a fresh generation. Rows cover:
  - num and pct with digits 0–3 and sigfig 1–3;
  - each mark configuration through `cfg.big_mark=`, `cfg.decimal_mark=` and `cfg.minus=-`;
  - the sci corpus, the p corpus with `cfg.p_label=` variants (`*p*`, `adj.%20p`);
  - ranges with plus, and plus.

## 5. Implementation

- **P1 (formatting).** Files: new `R/tex.R` (`TARGETS`, the target table, `tex_mark()`, `tex_text()`, `unit_md_to_tex()`), `R/format.R`, `R/unit-names.R`, `R/units.R`, `R/config.R`.
  - Thread `target` through `print_one`, `zero_noise`, `sci_one`, `print_p`, `collapse_range`, `unit_affix`, `apply_project` and `text_stage`.
  - Build a TeX copy of `cfg` with mapped marks.
  - Risk: `group_int` uses `gsub` with `mark` in the replacement, so escape the backslashes in `\,`.
- **P2 (scanner and knit).** Files: `R/scan.R` (`find_tex_envs`, the `tex` column, checks in `inline_row`, `fence_inline` and `span_inline`), `R/resolve.R` (`target`, wrapper, markers, context, TX11), `R/lint-source.R`, `R/lint-code.R`. Needs P1's signature.
- **P3 (docs and re-pins).** `dev/PACKAGE-SCOPING.md`, `vignettes/values.Rmd` (lines 42 and 60–68), `vignettes/lints.Rmd:111`, `skills/weft/references/syntax.md:23-27`, `inst/agent/references/syntax.md:23-27`, NEWS, plus `test-tex-render.R`. Runs in parallel with P2.
- **P4 (conformance).** `R/conformance.R` (`conf_tex_rows`, `target=` in `conf_parse_keys`, `CONF_TEX_SETS` kept apart from `CONF_NEW_SETS`), `tests/testthat/_conformance/tex.tsv`. After P1; parallel with P2.
- **Order:** P1, then P2 alongside P3 and P4. P2 and P3 both touch `PACKAGE-SCOPING.md`, so P3 owns it.

**Existing pins to re-pin.**

- `tests/testthat/test-lint-construct.R:25`: change to `` $x = `r k`{.word}$ ``.
- `R/scan.R:1149` (comment) and `:1316-1318` (message).
- Spec 1.9.1 (bullet 4), 2.10.1, 5.2.6 (rule, example block, and the rationale at about line 7168), 5.3.1 (the "attribute block inside math" bullet).
- The vignettes and skills listed in P3.
- `tests/testthat/test-scan.R:474` and `test-syntax-fixtures.R:195` stay as they are.

## 6. Open questions (my recommended default in bold)

1. Should unit characters such as °, µ and Ω pass through inside `\text{}`? **Yes.**
2. Typst prints `{,}` as "1, 234". **Accept it as a texmath defect**; the other option is `\text{1,234}`.
3. Should ranges in math always say "to"? **Yes.**
4. Should `\(…\)` and `\[…\]` count as math in `.Rmd` files? **Yes.**

---

# T2 (phase 2): named values in math, through the filter

## 1. How it works today

- **The filter.**
  - `resolve_inlines()` (`inst/quarto/weft.lua:1921`) resolves `Code` only. `Math` and `RawInline` are passed through.
  - `resolve_code_inner()` (`:1301`) goes through `format_vector()` (`:982`), which returns markdown that is then parsed to inlines.
  - Locations come from `tag()` (`:2247`), which needs element attributes; `Math` has none.
  - Failures become a `Span` marker (`:134`).
  - The ledger records `printed` through `entered()` (`:1212`).
  - `num.lua` has `format`, `format_sci` and `format_p` with a config table (`read_config`, `num.lua:31`). `words.collapse_range` takes `minus`.
- **The R scanner** gives named values in math no row (`handle_named` skip), so the lints, the gate and the hooks' publication (2.13.11) never see them.
- **Today's result.** Pandoc keeps `` `x`{.num} `` verbatim in the Math string, and MathJax shows the backticks.

## 2. Decisions

| # | Question | Chosen | Why |
|---|---|---|---|
| D81 | How to find constructs in Math text | scan the string for backtick runs, then `pandoc.read` the snippet `` `name`{…} `` as markdown | reuses Pandoc's own attribute parser and `code_candidate`; a hand-written Lua parser would be a parity risk |
| D82 | How to locate them | at tag time, wrap a Math, RawInline or RawBlock holding candidates in a `Span`/`Div` with class `weft-math` and `weft-at="i:l,i:l"` (document order) | keeps `tag()`'s single sequential source search; unwrapped at resolution |
| D83 | A failure inside math | TX9 marker inside the string; the failure is recorded as usual | splitting a formula breaks `\frac{}{}` and similar |
| D84 | Raw `tex`/`latex` elements | included, with TX1's math/raw split (raw gets `\ensuremath{}`) | parity with T1 |
| D85 | Target in `num.lua` | `config.target` (default `"markdown"`) | no signature change; a future target is one more value |

## 3. Specification

**TL1 (where).**

- Every `Math` element.
- Every `RawInline` or `RawBlock` whose format is `tex` or `latex`. Its target is math when the text is a TX1 math environment, else raw.
- Documents on every engine, knitr documents included: the hooks leave a named value's source in place (N14), so it reaches Pandoc inside the math.

**TL2 (finding).**

- Left to right: a run of k backticks that is not preceded by `\` opens a candidate. The content runs to the next run of exactly k backticks.
- The candidate must be followed directly by `{` and an attribute block that ends at its matching `}`, with quoted values respected.
- The snippet (backticks, content, backticks, block) is read with `pandoc.read(snippet, "markdown")`. It is a construct when the result is exactly one `Code` that passes `code_candidate()`. Otherwise the text is left alone.

**TL3 (checks).**

- The R scanner and the filter both apply TX2, with E95–E99 in identical text. On a named value, `.val` is allowed and `.date` falls under E95.
- R scanner: `handle_named` no longer skips in a `tex` region. It adds a `named` row with `tex` set, so `named-unpublished`, the gate and publication see it.
- Every other named-value check of 1.12 applies unchanged.

**TL4 (output).**

- Each construct is replaced in the string by its TeX text, as `num.lua` prints it with `config.target = "tex"`. The outputs match TX5 exactly for `.num`, `.pct`, `.sci`, `.p`, `.plus` and `.range`, including the `p_label` rule and a verbatim `label` key.
- `.val` prints a number record whose text matches `^-?[0-9]+(\.[0-9]+)?$` as it is, and anything else through `tex_text()` (e.g. `1e+23` becomes `\text{1e+23}`).
- `unit=` is the value error it is today (2.13.3).
- In a raw element, the output is wrapped in `\ensuremath{}`.

**TL5 (ledger and stamp).**

- Entry kind `value`, expr the name, `context` `"math"` or `"tex"`, `printed` the TeX.
- `finish_block` finds the TeX inside the block's stringified text (Math stringifies to its TeX).
- Names used in math count in the stamp's `named` list. Forward references follow 1.12.7 unchanged.

**TL6 (`weft-check.lua`).** A `Math` or raw-TeX text holding a backticked NAME followed directly by `{` that carries a weft class is **E106**: kind `"leftover code"`, detail "math holds a named value the filter did not resolve", with the excerpt.

**TL7 (guests).**

- Under knitr, `` `r py$x`{.num} `` is T1, and named values are T2.
- On the jupyter and julia engines only named values exist.
- Quarto's `` `{python} x` `` inline expressions print the guest's own text. A class block on one stays N7 (E1). There is no new route.

**TL8 (spec).** New rule 2.13.16 (TL1–TL6). Rule 1.12.11 adds "in math, the TeX forms of 1.4.22".

## 4. Tests

- **`test-lua-tex.R`** (P5; needs `pandoc lua`):
  - run `tex.tsv` through `num.lua` and `words.lua`;
  - unit tests for the Lua `tex_text` against R's on 30 strings;
  - `.val` cases.
- **`test-filter-math.R`** (P6; Pandoc):
  - `` $p = `p_val`{.p}$ ``, `$$…$$`, `align` as RawInline, a `{=latex}` block;
  - a missing name gives the `\text{<<weft: no value…>>}` marker and a collected failure with the right line;
  - E95–E99 parity with the scanner's message;
  - a forward reference;
  - ledger context and printed text;
  - E106 when the filter is not run.
- **Engine and knitr cases** in the existing files: one knitr document with a Python name in math (reticulate; skip if absent) in `test-jupyter*.R`, and one in the Julia engine test (skip without Julia).
- **R side:** `test-tex-scan.R` gains named rows in math, with their errors.

## 5. Implementation

- **P5.** `inst/quarto/weftlib/num.lua` (`config.target`, the mark table, `\%`, sci, p label), `inst/quarto/weftlib/words.lua` (the `collapse_range` target), the Lua `tex_text`. After P4; parallel with P6's scanner part.
- **P6.**
  - `inst/quarto/weft.lua`: wrapping in `tag_all`, `resolve_inlines`/blocks for `weft-math`, the string resolver reusing `resolve_code_inner` with `target`, `format_vector(o.target)`, `entered()` with string results;
  - `inst/quarto/weft-check.lua` (E106);
  - `R/scan.R` (the `handle_named` change).
  - After P2 and P5.
- **Risks.**
  - Quarto's global `error` override: keep using `assert`.
  - A `pandoc.read` call for each candidate costs time; candidates are rare.
  - A text-mode `` \` `` accent inside raw LaTeX is excluded by the backslash rule.

## 6. Open question (recommended default in bold)

Should the filter also resolve named values in raw TeX that is not math? **Yes, with `\ensuremath`, for parity with T1.**
