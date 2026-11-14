# Options for project formatters (rule 1.4.22)

Designed 14 Nov after v0.1.0, on the owner's ruling "do options and TeX
now. Mark other languages as deferred." Adopted as written.

## Findings

I probed today's behaviour with `apply_formatters()` and `scan_text()`, using a registered `.millions` (`in_millions`, number stage), `.shout` (`toupper`, text stage) and a collapse-stage class:

| Construct | Number-stage `.millions` | Text-stage `.shout` |
|---|---|---|
| `digits=2` | No scan error. At render the option is **silently dropped** and `fn(x)` prints "1.2 million". | `digits` implies `.num`, so weft prints "0.12" and `fn` gets the text. |
| `sigfig=2` | **Silently dropped**. | Consumed by `.num`. |
| `unit="ML"` | Weft consumes it first. On a plain number it is a value error ("`unit = ML` needs a quantity"). On `u(1234567,"L")` weft converts, calls `fn(1.234567)` and appends the unit: "0.0 million ML". | Weft converts. |
| `foo=2` | No error. It passes through as a Pandoc attribute (`[...]{foo="2"}`), and the 5.3.3 `name` lint lists it. | Same. |
| `.pct` | Construct error 1.4.2, at scan and at render. | Legal: `.pct` formats the number, then `.shout` acts on the text. |
| `digits=x` | **No error anywhere** (dropped). | Render construct error from `key_number()`. |
| collapse class with `sep`/`last`/`trunc` | — | **Silently dropped** (`trunc` is checked for ≥1 first). `none` is weft's: it prints for an empty vector without calling `fn`. |

Code locations:
- `R/config.R:362-394`, `check_formatters()`: reads only `function` and `stage`. Any other key in a registration is ignored silently.
- `R/config.R:253-263`, `merge_config()`: merges registrations with a recursive `modifyList`. Probe: a later `options` mapping is merged key by key, and a later sequence replaces the earlier one. That is inconsistent.
- `R/format.R:647`, `apply_formatters()`: lower-cases **every** key name, not only weft's.
- `R/format.R:1215`, `apply_project()`: calls `fn(x)`. Its call sites:
  - `:815` text stage: character.
  - `:925` number stage: the bare numeric, after unit conversion; weft adds the unit afterwards.
  - `:986` wording stage: a `weft_text`.
  - `:1104` collapse stage: character with the unit attached; `text[1]` is kept.
- `R/resolve.R:547-554`, `apply_text_classes()`: a **fifth path**. It applies text classes, project ones included, with `keys = list()`. `finish()` (`:557`) uses it for span arms, and `render_value` (`:768`) uses it when nothing else formats.
- `R/resolve.R:7`: `owned_keys()` is global. `R/resolve.R:290-295`: `split_classes()` builds `pass_keys` from it.
- `R/scan.R:9`: `WEFT_KEYS`. `:638`: `block_errors()` does not check unknown keys. `:906`: `lower_keys()` lower-cases weft keys only. `:1267-1270`: every key except governor keys is kept on the row.
- `R/lint-code.R:699-760`, `lint_name()`: its known keys are weft keys, `custom-style` and `expected_names`.
- Ledger: `R/changes.R:213-223` matches entries on file, section, kind, expr and occ (or id). Keys play no part. An option change shows only through `text` (`R/ledger.R:82`).
- Gate: it judges construct errors in documents whose **blob** changed (`R/gate.R:368-392`). A `_weft.yml` that does not read is reported as a `construct` finding (`:384`).
- Lua: `config.lua:205-212` (`formatters_flow`) and `:333-351` (`read_formatters`) record class names only. Deeper lines are skipped, and flow nesting is depth-counted. `weft.lua:811-813` raises E21.
- Free rule number: 1.4.22 (the spec's 1.4 runs to 1.4.21). `dev/design-9.md` does not exist yet.

## Alternatives

1. **Inspect the function's formals.** Rejected. The function is often defined in a document chunk, so the scanner, `lints()` and the gate cannot know it without running R (rationale 1.4.8). Legality would also change whenever the function changes, and `...` would swallow `custom-style`.
2. **Pass every non-weft key as a string** (through `...` or an `opts` list). Rejected. It allows no static legality check, ends pass-through on every project-class construct, and leaves values untyped.
3. **Declare typed options in `_weft.yml`.** Chosen. This is static, gives typo help in the lint, and allows type checks at scan time.

Two sub-choices:
- **Types are declared, not inferred from quoting.** Pandoc and weft read `digits=2` and `digits="2"` alike, and the spec writes `digits="2"`.
- **An undeclared non-weft key keeps passing through, with a tier-2 lint finding**, instead of becoming an error. This keeps 1.2.6/1.2.7, so `custom-style` and HTML attributes still work. It matches `{.num digts=2}` today.

## Specification

```yaml
formatters:
  .millions:
    function: in_millions        # as today
    stage: number                # as today
    options:                     # new, optional
      digits: integer            # weft key: its own type, or empty (`digits:`)
      word: string
      long: logical
# or the list form: options: [digits, word]
```

**PF1. Form of `options`.** `options` is optional. It is either:
- a sequence of names (a single name counts as a list of one), or
- a mapping from name to type.

An absent, empty or null `options` declares nothing. `check_formatters()` stores the declaration as a named character vector, name to type, in declaration order. For example, `cfg$formatters$.millions$options` is `c(digits = "integer", word = "string")`.

**PF2. Names.** A name matches `^[a-z][a-z0-9_]*$`.

**PF3. Types.** The types are `number`, `integer`, `string` and `logical`. In the list form every name that is not a weft key gets `string`.

**PF4. Weft keys a class may declare.** Only the weft keys of the class's own stage, each with its own type:

| Stage | Weft keys it may declare |
|---|---|
| number | `digits`, `sigfig` (integer) |
| collapse | `sep`, `last` (string); `trunc` (integer) |
| wording, text | none (`digits`/`sigfig` keep implying `.num`) |

A weft key may be written with an empty value or with its own type.

**PF5. Reserved names.** These may never be declared:
- `n`, `if`, `sign`, `list`, `cite`
- `unit`, `none`, `label`
- `why`, `decision`, `claim`, `level`
- `target` (kept for weft-supplied arguments, PF14).

Declaring a Pandoc attribute name such as `lang` is allowed; that key is then consumed instead of passed through.

**PF6. Later registrations.** A registration of the same class in a later source (front matter after `_weft.yml`) **replaces** `options` as a whole. Its other keys still merge as today.

**PF7. Unknown keys in a registration.** A key other than `function`, `stage` and `options` gives warning W1 and is ignored.

**PF8. Keys on a construct.** On a construct that carries a project class C, a key matches an option C declares in any letter case (1.2.10). A matched key:
- is consumed: it is not passed through and the 5.3.3 lint does not list it;
- takes part in the duplicate-key check.

If two classes on one construct declare the same name, each receives the one value, parsed by its own type. On a construct without C, the key is an ordinary key: it passes through and the lint lists it (L2).

**PF9. Undeclared weft keys.** A weft key of C's stage (PF4) that C does not declare is a construct error (M8). This applies to every kind except named values, and is raised at scan and at render. For example, `{.millions digits=2}` with no `digits` declared is M8. `digits` with `sigfig` stays error 1.4.7. `unit` and `none` keep weft's meaning on every stage.

**PF10. Values.** Each value is parsed by its type.

| Type | Accepted (trimmed) | Arrives as |
|---|---|---|
| `number` | `^[+-]?([0-9]+([.][0-9]*)?\|[.][0-9]+)([eE][+-]?[0-9]+)?$` | a double of length 1 |
| `integer` | `^[+-]?[0-9]+$`, within integer range | an integer of length 1 |
| `logical` | `true` or `false`, any case | `TRUE` or `FALSE` |
| `string` | anything, untrimmed | the string as written |

- A value outside its type is construct error M9, at scan and at render.
- Declared weft keys are checked by weft's own rules, as on `.num`: `key_number()` and `sigfig` ≥ 1, at render, with the same messages. They arrive as integers.
- Options are always scalars, even though `x` is a vector. A `|` inside a string stays text.

**PF11. The call.** At every call path (text, number, wording, collapse, and the text-class path of `apply_text_classes`), weft calls:
- `fn(x)` when no option is written on the construct (and nothing weft-supplied, PF14);
- otherwise `do.call(fn, c(list(x), args))`.

`args` holds only the options of C that are written on the construct, named as declared and in declaration order, followed by any weft-supplied arguments. An option that is not written is not passed, so the function's own default applies. `x` is exactly what it is at that site today. Weft does not apply a declared `digits` itself: as today, a number-stage project class prints the number, and the zero rule does not reach it. Governors (`n`/`sign` spans and `#`) follow the same rule.

**PF12. Checking the function.** On every call through a class that declares options, before `fn` runs, whether or not an option is written, weft checks `formals(args(fn))`:
- each declared name must be a formal, unless `fn` has `...` → otherwise M10;
- no declared name may equal the first formal → otherwise M11.

Both are `weft_construct_error`s, and the render stops. This check cannot happen when the configuration is read, because the function may not exist yet.

**PF13. Backward compatibility.** A registration with no `options` makes calls identical to today: `fn(x)`, without `do.call`. The one intended change is that `digits`/`sigfig` on a number-stage class, and `sep`/`last`/`trunc` on a collapse-stage class, change from silently dropped to M8. No test, vignette or spec example uses that.

**PF14. Weft-supplied arguments (for design-9, TeX).** Weft may append named arguments after the options, such as `target = "tex"`, through the same `args` list. They are subject to PF12. Design-9 decides when they are supplied (for example, only for registrations that opt in), so a one-argument function never receives one. The name `target` is reserved (PF5).

**PF15. Lint 5.3.3 `name`.**
- On a construct, the options declared by its project classes are known keys.
- A key one edit from such an option gives L1 (checked before the weft-name near miss).
- A key that is an option of a project class absent from the construct gives L2.
- The other messages are unchanged.

**PF16. Named values (filter route).** Unchanged. A project class there is E21 at the filter. The R scanner skips PF9 and PF10 for `kind == "named"`. `config.lua` needs **no change**: it skips the nested `options` lines and depth-counts flow nesting. Tests (below) pin this.

**PF17. Ledger and gate.** No format change. As with `{.num digits=1}` → `digits=2`, an option change on a project class changes the entry's `text` and not its key, so `changes()` reports a text change. M1–M7 make `_weft.yml` fail to read, which is already a gate `construct` finding. M8 and M9 are scanner construct errors, so the gate fails on them in changed documents. M10 and M11 need R and are render-only. As for any `_weft.yml` edit today, unchanged documents that a new declaration breaks surface at the next `lints()` or render.

### Messages

| Id | Class, when | Text |
|---|---|---|
| M1 | config error, read | "The `options` of the formatter `%s` must be a list of option names or a mapping from option name to type (rule 1.4.22)." |
| M2 | config error | "The option name `%s` of the formatter `%s` must start with a lower-case letter and have only lower-case letters, digits and `_` (rule 1.4.22)." |
| M3 | config error | "The option `%s` is declared twice for the formatter `%s` (rule 1.4.22)." |
| M4 | config error | "The option `%s` of the formatter `%s` has the unknown type `%s`; the types are number, integer, string and logical (rule 1.4.22)." |
| M5 | config error | "The formatter `%s` cannot declare `%s` as an option: weft reads that key itself (rule 1.4.22)." |
| M6 | config error | "The formatter `%s` cannot declare `%s` as an option: `%s` belongs to weft's %s stage, and `%s` is a %s-stage formatter (rule 1.4.22)." |
| M7 | config error | "The option `%s` of the formatter `%s` is weft's key, of type %s, and cannot be declared as %s (rule 1.4.22)." |
| W1 | `weft_config_warning` | "Unknown key `%s` in the formatter `%s`; it is ignored (rule 1.4.8)." |
| M8 | construct error, scan and render | "`%s` does not apply to `%s`: the formatter declares no option `%s` (rule 1.4.22)." |
| M9 | construct error, scan and render | "The option `%s` of `%s` must be %s; got `%s` (rule 1.4.22)." (%s is "a number", "a whole number" or "true or false") |
| M10 | construct error, render | "The function `%s` of the formatter `%s` takes no argument `%s`, which the formatter declares as an option; add the argument or `...` (rule 1.4.22)." |
| M11 | construct error, render | "The option `%s` of the formatter `%s` has the name of the first argument of `%s`, which receives the value; rename the option (rule 1.4.22)." |
| L1 | lint `name`, tier 2 | "`%s` is not an option of `%s`; it is one edit from `%s` (rule 5.3.3)." |
| L2 | lint `name`, tier 2 | "`%s` is an option of `%s`, which is not on this construct, so it passes through (rule 5.3.3)." |

### The `fmt_*()` side and the docs example

The `fmt_*()` functions do not change. Idiom: give forwarded options a `NULL` default, so the project's own `digits` setting still applies when the construct writes none.

```r
in_millions <- function(x, digits = NULL, word = "million") {
  paste(weft::fmt_num(x / 1e6, digits = digits), word)
}
```

With `options: {digits: integer, word: string}`, `` `r volume`{.millions digits=2} `` prints "1.23 million", `{.millions word="M"}` prints "1.2 M", and `{.millions sigfig=2}` is M8.

## Test plan

- **`tests/testthat/test-config.R`**:
  - PF1 both forms, with the stored vector checked by `expect_identical`; the scalar shorthand; an empty `options`.
  - M1 for `options: [1]` and for `options: {a: {b: c}}`.
  - M2 for `Scale` and for `my-opt`; M3; M4 for `scale: float`.
  - M5 for `unit`, `n` and `target`.
  - M6 for `sep` on number and for `digits` on text.
  - M7 for `digits: string`; W1 for `option:`; PF6 replacement from front matter.
- **New `tests/testthat/test-formatter-options.R`**, using `apply_formatters()` with a config and a recording function that captures `list(...)`:
  - All four stages and the `apply_text_classes` path receive exactly the options written, in declaration order, and nothing else.
  - The PF10 typing table: `2` → `2L`, `"1e3"` → `1000`, `TRUE` / `False`, a string kept with its spaces.
  - M9 for each type; M8 for `digits`, `sigfig`, `sep` and `trunc`.
  - M10 for `function(x)`; no error with `function(x, ...)`; M11.
  - PF13 with `substitute(x)` inside `fn`, which must still see `x`.
  - A governor `[a | b]{n="v" .millions digits=0}` and a text-stage class on a span arm.
- **`scan_text()` cases** in the same file: M8 and M9 found from source; `Scale=2 scale=3` is the 1.2.10 duplicate; a named value gets no PF error.
- **`tests/testthat/test-lint-names.R`**: declared option not listed; L1 for `scael`; L2 for `{.num scale=2}`; `foo` listed as today.
- **`tests/testthat/test-filter-config.R`** (N84): block and flow `options:` report no problem, and E21 is still raised.
- **One rmarkdown render** (`helper-render.R`): `{.millions digits=2 foo="x"}` → `[1.23 million]{foo="x"}`.
- **One ledger test**: changing `digits=1` → `2` on `.millions` changes `text` only.

## Implementation notes

- **`R/config.R`**: options parsing and M1–M7, W1 in `check_formatters()`; PF6 in `merge_config()`.
- **`R/format.R`**:
  - shared constants and helpers: stage keys, reserved names, `project_options(reg, cls)`, and `option_value(type, v, opt, cls)`, which the scanner uses too;
  - M8/M9 in the error block that needs no value;
  - `apply_project(spec, x, number_source, args = list())` with the PF12 check, and the four call sites pass `args`.
- **`R/resolve.R`**: `split_classes()` takes `reg` so declared options leave `pass_keys`; `apply_text_classes()` and `finish()` take `cc$keys`.
- **`R/scan.R`**: `lower_keys(nms, opts)`; PF9/PF10 in `block_errors()`, skipped for `named`.
- **`R/lint-code.R`**: `lint_name()`.
- **Spec**: amend 1.4.8 and the 9.1.2 table row; add 1.4.22 with its rationale; add M8/M9 to 5.3.1 and M10/M11 to 5.3.2 (as errors that need the function); amend 5.3.3.
- **Docs**: `vignettes/values.Rmd` (~467), `vignettes/adopting.Rmd` (~95), the setup table, NEWS.
- **Risks**:
  - The all-key lower-casing at `format.R:647`: match options case-insensitively everywhere.
  - Use `formals(args(fn))` so primitives work.
  - Miss the fifth path and text-stage options vanish on spans.
  - The M8 behaviour break (PF13).

## Deferred

Project formatters for named values on the Lua-filter route (Jupyter and Julia documents) are deferred by the owner (14 Nov). The three shapes considered were formatting in the guest language, a Lua formatter supplied by the project, and declarative formatters interpreted by both R and Lua, with declarative recommended when it is taken up.
