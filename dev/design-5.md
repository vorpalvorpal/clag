# Stage 5: Python and Julia chunks as guests of knitr

Written before any test or code. It is the build contract for architecture
(a) of `dev/languages-study.md`: weft stays an R package on knitr, and Python
and Julia chunks in an `.Rmd`, or in a `.qmd` with `engine: knitr`, become
documented, tested and safe guests (the study's rungs 1 and 2). Robin chose
(a). The choices inside it were delegated; each is a decision in §3 with its
alternatives. Every example is invented.

A test-writer works from §2 and §5 only and never reads `R/`. An implementer
then works from §2, §4 and the tests. Rule numbers such as 2.12.5 are the
spec numbers proposed in §6; G numbers are this note's contract.

## What was measured

R 4.4.3, knitr 1.51, reticulate 1.43.0, Python 3.15.0 (Homebrew,
`/opt/homebrew/bin/python3`), macOS. The default Python has neither numpy
nor pandas. For the numpy and pandas rows a temporary virtual environment
was made in the scratchpad with numpy 2.5.4 and pandas 3.1.1
(`.../scratchpad/g5/venv`, made with `uv`; nothing was installed into the
user's environment). Each probe ran as `R_USER_CACHE_DIR=$(mktemp -d)
Rscript ...` with `RETICULATE_PYTHON` set and
`RETICULATE_USE_MANAGED_VENV=no`, one process at a time. Julia and
JuliaCall are not installed. Scripts are in `.../scratchpad/g5/`.

**1. How reticulate converts a Python value (`py[[name]]`, the same as
`py$name`).**

| Python | R value | |
|---|---|---|
| `2**31 - 1` | `2147483647L` | right |
| `2**31` | `NA_integer_` | wrong |
| `2**53` | `0L` | wrong, silent |
| `2**53 + 1` | `1L` | wrong, silent |
| `2**63`, `2**70`, `-2**70` | `-1L` | wrong, and a Python `OverflowError` is left pending: the next `py_eval("1+1")` failed with it |
| `[1, 2**53 + 1]` | `c(1L, 1L)` | wrong, silent |
| `[]` | `list()` | a list, not an atomic vector |
| `[1, 'a']` | `list(1L, "a")` | prints "1 and a" under `.and` |
| `(1, 2)` | `list(1L, 2L)` | |
| `{'a': 1.5, 'b': 2}` | named `list` | |
| `{1, 2}`, `Decimal('0.15')`, `Fraction(1, 3)` | Python object references | |
| `None` | `NULL` | |
| `float('nan')`, `math.inf` | `NaN`, `Inf` | |
| `True`, `0`, `''` | `TRUE`, `0L`, `""` | |
| `datetime.date(2026, 11, 13)` | `Date` | right |
| `datetime.datetime(2026, 11, 13, 10, 30)` | `POSIXct` | |
| `numpy.int64(2**53 + 1)` | `9007199254740992` (double) | wrong by one, silent |
| `numpy.uint64(2**64 - 1)` | `18446744073709551616` | wrong, silent |
| `numpy.int32(7)`, `numpy.float64(3.14)`, `numpy.bool_(True)`, `numpy.nan` | `7L`, `3.14`, `TRUE`, `NaN` | right |
| `numpy.array([1, 2**53 + 1])` | `c(1, 9007199254740992)` (array) | wrong, silent |
| `pandas.NA` | `NA` | |
| `pandas.NaT` | error "NaTType does not support timestamp" | |
| `pandas.Timestamp('2026-11-13')`, `numpy.datetime64('2026-11-13')` | `POSIXct` "2026-11-13 11:00:00" (local zone) | |
| `pandas.Series(...)`, `pandas.DataFrame(...)` | Python object references: reticulate 1.43.0 does not convert pandas 3.1.1 objects at all | |

**2. Where the wrong value arises.** In reticulate's C++ `py_to_r_cpp()`,
called by `py_maybe_convert()` inside `$.python.builtin.module` and
`[[`, before any R code sees the value. `py_to_r()` is an S3 generic, but it
calls `py_to_r_cpp()` first and dispatches only on what is still a Python
object: a method `py_to_r.python.builtin.int` registered in reticulate's
namespace was never called (`py$x`, `py$list`, `py_eval()`). So weft cannot
intercept the conversion, and after it cannot tell a wrong integer from a
right one: `1L` is a valid value. Only `2**31` (to `NA`) shows, as a
misleading "no value".

**3. The way round it.** `reticulate::import_main(convert = FALSE)` and
`py_get_attr(main, "x")` give the unconverted object;
`py_str()` of `2**53 + 1` is `"9007199254740993"`. A small Python
classifier, called on the unconverted object, returned the right kind and
refused `2**53 + 1`, `[1, 'a']` and a `datetime` (spike `p7.R`).

**4. Python calling R.** `r.g(2**53 + 1)` from a Python chunk hands R the
integer `1`, through the same conversion. An R function wrapped with
`reticulate::r_to_py(f, convert = FALSE)` receives the unconverted Python
`int` (it printed `9007199254740993`); its R string result arrives in Python
as a `str`. A `types.ModuleType` put into `sys.modules` from R made
`from weftmod import fmt_num` work in Python, keyword arguments included.

**5. weft today, working tree, on an `.Rmd` with a Python chunk.**
`` `r py$b53`{.num} `` (`2**53 + 1`) printed "1" with no failure. `2**31`
gave "no value". `` `r py$empty`{.and none="none"} `` gave "no value".
`[1, 'a']` printed "1 and a". `{if="py$zero"}` and `{if="py$estr"}` were
already value errors ("must be a single TRUE or FALSE"). `{if="py$empty"}`
was "no value". `Decimal` was a value error ("needs a number; the value is
of class decimal.Decimal"). `r.fmt_num(3.14159)` printed "3.1" and
`r.plural(3, "# site", "# sites")` "3 sites". The Python warning appeared in
the chunk output as `## <string>:1: UserWarning: a python warning`.

**6. knitr's hooks around a Python chunk.** The `label` option hook and the
`chunk` output hook both run for `engine = "python"` chunks. A Python error
under `error = TRUE` reaches R as no condition at all; it shows in the
output. `reticulate::py_last_error()` holds it after the chunk, and
`reticulate::py_clear_last_error()` clears it, so it can be read per chunk.

**7. reticulate's initialisation hook.** reticulate 1.43.0 runs the hooks set
with `setHook("reticulate.onPyInit", f)` when Python starts
(`reticulate:::call_init_hooks`). Setting the hook does not load reticulate.

**8. A defect in R weft, found on the way.** `fmt_num(999999999999999)`
prints "1,000,000,000,000,000"; `fmt_num(2^53)` prints
"9,007,199,254,740,990". The cause is base R's `signif(x, 15)` inside
`round_half_away()` (`signif(999999999999999, 15)` is `1e15` in R 4.4.3).
It reaches R values too. A Python integer read exactly would still print
wrong, so this stage fixes it first (G1 to G3).

## 1. Scope

| What | Pkg | |
|---|---|---|
| Whole numbers up to 2^53 print exactly (measurement 8) | 5a | build |
| Typed values: the language-neutral rule set (1.11) | 5b | build, R as the first carrier |
| Guarded reads of Python values in prose, bare values, captions, `weft_str()`; `py_value()` for R code | 5b | build |
| `if`, `n`, `sign`, `list` given a guest value of the wrong kind | 5b | build |
| `py` availability and its messages | 5b, 5c | build |
| Function forms from Python (`from weft import fmt_num`), `weft_str()` from Python for `asis` text | 5c | build |
| Python warnings and errors in the condition log | 5d | build |
| Project Python modules, `source_python()` and `py_run_file()` in the ledger's reads | 5d | build |
| The reads walker reads R chunks only | 5d | build |
| Lints `guest-inline`, `guest-call`, `guest-read`; the `engine` message by case; `use_setup()` on a Python-only `.qmd` that holds a construct | 5e | build |
| Lint `ojs-value` | 5f | build |
| Article `vignettes/languages.Rmd`, reference entry | 5g | build |
| Julia: static parts (lint messages, `{julia}` inline, JuliaCall calls listed) | 5e | build |
| Julia: reading values, warnings, reads (J1 to J5) | 5J | designed, not built: no Julia here (V15) |
| Spec text (§6) | spec editor | after the build |
| The Jupyter and julia engines (rungs 3 to 6) | | out: architecture (c) or later |
| A Lua formatter | | out |
| Units and the dictionary from Python or Julia | | out: `u()`, `fmt_unit()` and `dict` stay R |
| `claim()` written in Python | | out: checks are R, in prose |
| Python data files (`pd.read_csv()`) in the ledger | | out, as R's `read.csv()` is today (7.2.2 records sources, not data) |
| A Python `weft_str()` literal read by the lints and counted by the gate | | out (V18, O7) |
| R values at or above 2^53 under `.num` | | out (O4) |

## 2. Contract

### Exports, conditions, dependencies

- **G4. Exports and dependencies.** One new export, `py_value()` (G8). It is
  also put on the search path by `weft_setup()` with the other prose
  functions (rule 2.1.8). `reticulate (>= 1.43.0)` joins Suggests. No new
  Imports. `JuliaCall` is not added. Nothing in weft loads reticulate or
  starts Python unless a document or a call needs Python (G15, G18).
- **G4a. Condition classes.**
  - `weft_guest_error` (also `weft_error`): a guest read that cannot be
    done: reticulate absent, Python not startable, a name or attribute not
    there (M13 to M16).
  - `weft_guest_value_error` (also `weft_value_error`, `weft_error`): a
    guest value outside the typed set, or one R cannot hold exactly (M1 to
    M12).
  - `weft_guest_warning` (also `weft_warning`): M17.
- **G4b. Test seam.** `options(weft.reticulate = FALSE)` makes weft behave
  as if reticulate were not installed. It is internal and undocumented to
  authors.

### A. Whole numbers print exactly (5a, rule 1.4.13)

- **G1.** A number-stage printer given a double that is an exact integer of
  magnitude at most 2^53 (9007199254740992) prints every digit of it, with
  no `digits` or `sigfig` given:
  `fmt_num(999999999999999)` is "999,999,999,999,999";
  `fmt_num(1e15 + 1)` is "1,000,000,000,000,001";
  `fmt_num(2^53)` is "9,007,199,254,740,992";
  `fmt_num(-(2^53))` is "−9,007,199,254,740,992" (U+2212);
  `fmt_num(2147483648)` is "2,147,483,648". The same holds for a value in
  prose, `` `r x`{.num} ``, and for the `#` of an `n` span.
- **G2.** With `digits = k` such a value prints its integer digits exactly
  and `k` zeros: `fmt_num(2^53, digits = 2)` is
  "9,007,199,254,740,992.00". `sigfig` still rounds as 1.4.13 rounds:
  `fmt_num(2^53, sigfig = 3)` is "9,010,000,000,000,000".
- **G3.** `fmt_ord(1e15 + 1)` is "1,000,000,000,000,001st";
  `fmt_count(1e15 + 1)` is "1,000,000,000,000,001". Values that are not
  integers, and values above 2^53, print as they print today (the existing
  tests stand).

### B. Typed values and reading Python values (5b)

The typed-value rule set (1.11, §6) is language-neutral. In this stage R is
its only carrier: a guest value is read into a typed value, and the typed
value becomes one R form. From then on R's rules apply unchanged.

- **G5. The reading table.** A Python value read by weft (G8, G9) has the
  kind and R form below. "Refused" is a `weft_guest_value_error` with the
  message named. `S` in a message is the subject (G7).

  | Python value | Kind | R form |
  |---|---|---|
  | `True`, `False`, `numpy.bool_(x)` | bool | `TRUE`, `FALSE` |
  | an `int` (not a `bool`) with abs value at most `2**31 - 1`; `numpy.int8` to `numpy.int64`, `numpy.uint8` to `numpy.uint64` with such a value | integer | that R `integer` |
  | an integer from `2**31` to `2**53` in abs value (both inclusive at the top), as above | integer | that R `double`, exact |
  | an integer beyond `2**53` in abs value | | refused, M1 |
  | a `float`, `numpy.float16`/`32`/`64`, finite | float | that R `double`, exact (widened for 16 and 32 bits) |
  | `decimal.Decimal`, finite, at most 15 significant digits after `normalize()` | decimal | the `double` nearest it (`float(d)`) |
  | `decimal.Decimal`, finite, more than 15 significant digits | | refused, M2 |
  | a `str`, `numpy.str_` | string | a UTF-8 `character` of length one |
  | `datetime.date` (not a `datetime`), `numpy.datetime64` with unit `D` | date | an R `Date` |
  | `datetime.datetime`, `pandas.Timestamp`, `numpy.datetime64` with any other unit | | refused, M5 |
  | `None`, `float('nan')`, `float('inf')`, `-float('inf')`, numpy NaN and infinities, `Decimal('NaN')`, `Decimal('Infinity')`, `pandas.NA`, `pandas.NaT`, `numpy.datetime64('NaT')` | missing | `NA` (logical) |
  | `list`, `tuple`, a one-dimensional `numpy.ndarray`, `pandas.Series` | list | G6 |
  | `dict` (and any `collections.abc.Mapping`) | list with names | G6 |
  | `set`, `frozenset` | | refused, M7 |
  | a `numpy.ndarray` of 0 dimensions | as its one element | |
  | a `numpy.ndarray` of 2 or more dimensions | | refused, M9 |
  | anything else (`complex`, `bytes`, `fractions.Fraction`, a function, a module, `pandas.DataFrame`, `datetime.time`, `datetime.timedelta`, an instance of the author's class) | | refused, M6 |

  The kind is decided from the Python type, never from the printed form. A
  bool is never an integer, though Python's `bool` is a subclass of `int`.
  `pandas.Series` and `numpy.ndarray` are read through their `tolist()`.
- **G6. Lists.** Each element is read by G5 as a scalar. Then:
  - Elements that are missing are allowed anywhere. The other elements must
    be of one kind, with two promotions: integers with floats make a float
    list; integers with decimals make a decimal list. Any other mix (float
    with decimal, bool with a number, string with anything else) is refused,
    M3. An element that is itself a list, tuple, dict, set or array is
    refused, M4.
  - R form: an atomic vector of the element kind's R type, the elements in
    order, missing elements `NA` of that type. An integer list is an R
    `integer` vector when every element is within `±(2**31 - 1)`, else a
    `double` vector. A list whose elements are all missing is a `logical`
    vector of `NA`. An empty list (`[]`, `()`, `{}`, an empty array or
    Series) is `logical(0)`.
  - A mapping: every key must be a `str` (else refused, M8); its values are
    read as the list above, in the mapping's own order; the R form carries
    the keys as names. `{'a': 1.5, 'b': 2}` is `c(a = 1.5, b = 2)`. An empty
    mapping is `logical(0)` with no names.
  - Examples: `[1, 2]` is `c(1L, 2L)`; `[1, 2.5]` is `c(1, 2.5)`;
    `[1, None]` is `c(1L, NA)`; `[None, None]` is `c(NA, NA)`;
    `[1, 2**31]` is `c(1, 2147483648)`; `[1, Decimal('0.5')]` is
    `c(1, 0.5)`; `['a', 'b']` is `c("a", "b")`;
    `[datetime.date(2026, 1, 2)]` is `as.Date("2026-01-02")`;
    `[True, 1]` is refused with kinds "bool, integer"; `[1, 'a']` with
    "integer, string"; `[1.5, Decimal('2')]` with "float, decimal";
    `[[1]]` is refused, M4 with `{inner}` "list".
- **G7. Messages.** Exact texts. `{S}` is the subject: for a read in an
  expression, the read as R deparses it in backticks (`` `py$big` ``,
  `` `py[["big"]]` ``, `` `py$cfg$depth` ``, `` `py_value("big")` ``); for an
  argument of a function form, "Argument N of fmt_num()" or "Argument
  `digits` of fmt_num()" (G21). `{type}` is Python's
  `type(x).__module__ + "." + type(x).__qualname__` with a leading
  `builtins.` removed (`int`, `list`, `decimal.Decimal`, `numpy.ndarray`).
  `{kinds}` lists the kinds of G5 (bool, integer, float, decimal, string,
  date) in the order they first occur, joined by ", ".

  | Id | Text |
  |---|---|
  | M1 | `{S} is the Python int {digits}, beyond ±2^53, where R cannot hold a whole number exactly. Scale it in Python, or bind str() of it and print the text (rule 2.12.5).` |
  | M2 | `{S} is the Python Decimal {str(d)}, with {n} significant digits; R holds 15 exactly. Round it in Python with quantize() (rule 2.12.5).` |
  | M3 | `{S} is a Python {type} whose elements are of more than one kind ({kinds}); weft reads a list whose elements are all of one kind (rule 1.11.4).` |
  | M4 | `{S} is a Python {type} that holds a {inner}; weft reads a flat list (rule 1.11.4).` (`{inner}` is the `{type}` of the first such element) |
  | M5 | `{S} is a Python {type}, which holds a date and a time; weft reads a date. Convert it in Python, in the time zone you mean, with .date() (rule 1.11.6).` |
  | M6 | `{S} is a Python {type}, which weft does not read as a value. Bind a bool, int, float, Decimal, str, date, or a list of one of these (rule 1.11.1).` |
  | M7 | `{S} is a Python {type}, which has no order. Bind sorted() of it in a Python chunk (rule 1.11.4).` |
  | M8 | `{S} is a Python {type} whose keys are not all str (rule 1.11.4).` |
  | M9 | `{S} is a numpy array of {d} dimensions; weft reads a flat list (rule 1.11.4).` |
  | M10 | `` `{read}` is a Python {type}; an `if` condition must be a bool (rule 1.11.8). `` |
  | M11 | for `n`: `` `{read}` is a Python {type}; an `n` governor must be a number (rule 1.11.9). `` For `sign`: `` `{read}` is a Python {type}; a `sign` governor must be a number (rule 1.11.9). `` |
  | M12 | `` `{read}` is a Python {type}; a `list` span needs a list (rule 1.11.10). `` |
  | M13 | `` `{read}`: Python's main module has no name `{name}`. Run the Python chunk that sets it before this point (rule 2.12.6). `` |
  | M14 | `` `{read}`: the Python value `{prefix}` has no attribute or key `{name}` (rule 2.12.6). `` (`{prefix}` is the read so far, deparsed: `py$cfg`) |
  | M15 | `` `{read}` reads a Python value, and the R package reticulate is not installed. Install it with install.packages("reticulate") (rule 2.12.6). `` |
  | M16 | `` `{read}` reads a Python value, and reticulate could not start Python: {reason} (rule 2.12.6). `` (`{reason}` is reticulate's message, first line) |
  | M17 | ``A Python module named `weft` is already loaded, so weft's function forms are not registered (rule 2.12.8).`` |
- **G8. `py_value(...)`.** Each argument is one string, a step of a path:
  `py_value("n")` reads the name `n` in Python's main module;
  `py_value("cfg", "depth")` reads `cfg`, then its key `depth` when `cfg`
  is a mapping, else its attribute `depth`. The last object is read by G5
  and G6 and its R form returned. A refusal raises
  `weft_guest_value_error`; a missing name M13 or M14 as
  `weft_guest_error`; no reticulate M15, no Python M16, both
  `weft_guest_error`. It works without `library(reticulate)`. It works
  outside a knit. A step that is not one non-empty string is an error of
  class `weft_error`: ``py_value() takes names as strings: py_value("n").``
  It is the documented route in R chunk code.
- **G9. Guest reads in expressions weft evaluates.** In the expression of a
  value (`` `r x`{...} ``), a bare value (`` `r x` ``), a governor (`n`,
  `if`, `sign`, `list`), a caption construct on an R chunk, and a markup
  string given to `weft_str()`, each of these is a **guest read** and is
  read by G5 and G6 (that is, as `py_value()` reads), not by reticulate's
  conversion:
  - `py$name`, `py[["name"]]` with a literal string, and chains of them
    (`py$cfg$depth`, `py[["cfg"]][["depth"]]`, mixed), each step a key of a
    mapping or else an attribute (G8);
  - the same with `reticulate::py` in place of `py`;
  - `py_value(...)` and `weft::py_value(...)`.

  The read is taken whole, from its first step to its last. What R then does
  with the R form is R's: `py$x[1]`, `length(py$sites)`, `py$slope > 0`,
  `claim(py$n, . > 10)`, `py$df$a` (a pandas column, through an attribute
  step, read as a list). `{.num}` on `py$b53` (`2**53 + 1`) is a value
  error, never "1".
- **G10. Where `py` is not Python.** A form of G9 whose `py` is a symbol is a
  guest read only when `py`, looked up from the evaluation environment, is
  not found or is a Python module whose `__name__` is `"__main__"`. A
  document whose R chunk assigns `py <- list(x = 3)` prints
  `` `r py$x`{.num} `` as "3". `py$f(2)`, a call whose function is a read,
  is left to reticulate unchanged (and is listed by `guest-read`, G37). An
  expression with no guest read evaluates exactly as it does today.
- **G11. Bare values.** A guest read in a bare value is read by G9, and the
  R form prints as stock knitr prints it (1.3.1): `` `r py$n` `` with
  `n = 12` prints "12"; with `n = 2**53 + 1` the value is a collected value
  error with the marker `<<weft: value error, line N>>`, as a
  `weft_value_error` in a bare value is today; with `n` not defined the knit
  stops with M13, as an error in a bare value stops it (2.6.4). With
  `x = None`, `` `r py$x` `` prints "NA".
- **G12. Constructs.** A refused guest value in a construct is a collected
  value error (2.6.9): marker `<<weft: value error, line N>>`, and the
  failure's `detail` is the message (M1 to M12). A guest read that cannot be
  done (M13 to M16) is a collected "no value" whose `detail` is
  `error evaluating {label}: {message}`, as 2.6.4 does today. A missing
  guest value (`None`) reaching a formatter is "no value" by 1.3.4.
- **G13. Governors given a guest value.** When a governor's expression,
  trimmed, is exactly one guest read, or a `claim()` whose first argument is
  exactly one guest read, the kind read (before its R form) must suit the
  key, else a collected value error with M10, M11 or M12; `{read}` is the
  read as R deparses it:
  - `if`: bool. `[yes | no]{if="py$t"}` with `t = True` prints "yes".
    `t = []`, `[True]`, `0`, `''`, `'False'` are each M10 (`{type}` list,
    list, int, str, str). In an `if` with several conditions each condition
    is judged on its own: `{if="py$a, py$b"}`.
  - `n`, `sign`: integer, float or decimal. A list (even of one number), a
    bool, a string, a date are M11. `n="claim(py$sites, length(.) > 0)"`
    with `sites = ['a']` is M11.
  - `list`: a list. A string or a number is M12. `list="py$sites"` with
    `sites = ['a', 'b']` works as 1.5.19 says.
  - A missing value is "no value" (1.3.4), not M10 to M12.
  - Any other expression is judged by R's rules on the R form as today:
    `{if="length(py$empty) > 0"}` with `empty = []` chooses the false arm.
- **G14. When Python is not there.** In prose a guest read never needs
  `library(reticulate)` or a `py` object (G10). Without reticulate (the
  seam of G4b) a value `` `r py$x`{.num} `` is a collected "no value" with
  M15; a bare `` `r py$x` `` stops the knit with M15. When reticulate cannot
  start Python (`RETICULATE_PYTHON` naming a file that does not exist, in a
  fresh process) the same with M16. weft never installs Python or a Python
  package, and never lets reticulate make a managed environment on its
  behalf: it does not change reticulate's settings.
- **G15. R-only documents are unaffected.** Knitting, with weft set up, a
  document that has no Python chunk and no guest read leaves
  `"reticulate" %in% loadedNamespaces()` `FALSE` (fresh process), and its
  output identical to today's.
- **G16. Python's state is left alone.** A guest read never assigns a name
  in Python's main module, and never leaves a Python error pending: after a
  refused read of `2**70` in prose, the next Python chunk runs and the knit
  reaches its end (with the one value error). weft's Python helpers live in
  a module of their own (`weft_guest`), not in `__main__`.
- **G17. Quarto.** In a `.qmd` with `engine: knitr`, rendered by Quarto,
  `` `{r} py$b53`{.num} `` is the same value error and
  `` `{r} py$depth`{.num} `` (3.14159) prints "3.1".
- **G17a. Other weft-evaluated places.** A caption construct on an R chunk
  (`fig-cap: | Depth `r py$depth`{.num} m.`) and `weft_str()` called in an R
  chunk (`weft_str("[rose | fell]{if=\"py$slope > 0\"}")`) read Python
  values by G9 and fail as G12 and G13 say. R chunk code itself is knitr's,
  not weft's: `x <- py$b53` in an R chunk is reticulate's conversion (and is
  listed by `guest-read`, G37).

### C. Activation and function forms from Python (5c)

- **G18. `weft_setup()` and Python.** `weft_setup()` never loads reticulate
  and never starts Python. When reticulate is loaded and Python is already
  running, it registers weft's Python helpers at once (the module of G19,
  the warning recorder of G25). Otherwise it adds one hook to
  `"reticulate.onPyInit"` that registers them when Python starts. Calling
  it twice adds no second hook (`length(getHook("reticulate.onPyInit"))`
  is 1). The helpers are also registered by the first guest read (G9) and
  by the first Python chunk of a knit, whichever comes first. In a fresh
  process: `weft::weft_setup()`; `"reticulate" %in% loadedNamespaces()` is
  `FALSE`; then `library(reticulate)` and
  `py_run_string("from weft import fmt_num; s = fmt_num(3.14159)")` leaves
  `py$s` equal to "3.1".
- **G19. The module `weft`.** Registered in Python's `sys.modules` under the
  name `weft`. It holds exactly these names, each callable: `fmt_num`,
  `fmt_pct`, `fmt_sci`, `fmt_p`, `fmt_date`, `fmt_no`, `fmt_word`,
  `fmt_count`, `fmt_ord`, `fmt_and`, `fmt_or`, `fmt_pairs`, `fmt_range`,
  `fmt_ul`, `fmt_ol`, `fmt_dl`, `fmt_a`, `fmt_cap`, `fmt_strong`, `fmt_em`,
  `plural`, `ci`, `pm`, `about`, `of_n`, `weft_str`, and the attribute
  `__weft_r__` (`True`). `claim`, `u`, `fmt_unit`, `lookup`, `brk`,
  `glue_vec` and the dictionary functions are not there:
  `from weft import claim` raises Python's `ImportError`.
- **G20. Same output.** A function of G19 called with Python arguments
  returns what the R function of that name returns given the R forms (G5,
  G6) of the same arguments, positional and keyword alike: one R string is
  a Python `str`; several are a Python `list` of `str`. Cases:
  `fmt_num(3.14159)` "3.1"; `fmt_num(3.14159, digits=3)` "3.142";
  `fmt_num(2**40)` "1,099,511,627,776"; `fmt_num([1.5, 2.25])`
  `["1.5", "2.3"]` (as R: `fmt_num(c(1.5, 2.25))`); `fmt_pct(0.12)` "12%";
  `fmt_p(0.0456)` "p = 0.046"; `fmt_word(3)` "three"; `fmt_ord(3)` "3rd";
  `fmt_and(['a', 'b', 'c'])` "a, b and c";
  `fmt_pairs({'A': 1.2, 'B': 3.4})` as `fmt_pairs(c(A = 1.2, B = 3.4))`;
  `fmt_date(datetime.date(2026, 11, 13))` as R's on the same `Date`;
  `plural(3, "# site", "# sites")` "3 sites"; `plural(1, "# site", "# sites")`
  "1 site". The test compares each with the R call; the literal strings
  above are what R prints today.
- **G21. Arguments are read, not converted.** Each argument is read by G5
  and G6 before R sees it. `fmt_num(2**53 + 1)` raises a Python exception
  whose message contains M1 with `{S}` "Argument 1 of fmt_num()";
  `fmt_num(1.5, digits=2**53 + 1)` contains M1 with "Argument `digits` of
  fmt_num()"; `fmt_and([1, 'a'])` contains M3. An R error the function
  raises (a value error of its own) reaches Python as an exception whose
  message contains the R message. In a Python chunk with no `error: true`
  that exception stops the knit, as any Python error does.
- **G22. `weft_str` from Python.** In a Python chunk with `results: asis`,
  `print(weft_str('Depth [rose | fell]{if="py$slope > 0"}.'))` with
  `slope = 0.4` writes "Depth rose." into the document. The markup's
  expressions are R, and guest reads in them follow G9. A failed check in it
  is collected as 3.6.3 says, located by the Python chunk's label: a string
  `'[x]{if="py$f"}'` with `f = False` leaves
  `<<weft: failed claim, chunk p2>>` and fails the render once at the end.
  Outside a knit it raises at once, as `weft_str()` stops outside a knit.
- **G23. A module named `weft` already loaded.** When `sys.modules["weft"]`
  exists and lacks `__weft_r__`, weft does not replace it and raises
  `weft_guest_warning` with M17, once per R session.
- **G24. Python chunks run by the knitr python engine of reticulate** (the
  default). With `python.reticulate = FALSE` each chunk is a separate Python
  process and a guest read gives M13: weft does not support that setting,
  and says so in the article.

### D. Conditions and reads (5d)

- **G25. Python warnings in the condition log.** Every warning Python shows
  (through `warnings.showwarning`) while a weft knit runs is logged once,
  class `warning`, text `{Category}: {message}` (`UserWarning: a python
  warning`), with the source of rule 7.4.5:
  - raised by a Python chunk: that chunk, `from` `chunk`, source its label;
  - raised by Python code an R chunk calls (`reticulate::py_run_string()`):
    that R chunk;
  - raised during a guest read or a function form in prose: the prose
    source of 2.8.2 (`from` `prose`).
  For a chunk `p3` the condition log holds the line
  `{"from":"chunk","source":"p3","class":"warning","normalised":"UserWarning: a python warning","text":"UserWarning: a python warning"}`
  and `last_knit()$conditions` the row. The rendered document is identical
  to the same knit without weft (2.8.1): the warning still prints where it
  printed.
- **G26. Severity.** A Python warning is matched against the severity list
  (7.4.2) as an R chunk warning is. With `severity: ["ConvergenceWarning"]`
  in `_weft.yml`, a Python chunk that warns `ConvergenceWarning: fit did not
  converge` fails the render at the end, its failure's `detail`
  `warning: ConvergenceWarning: fit did not converge`, hint
  `matched the severity pattern ConvergenceWarning`.
- **G27. Python errors under `error: true`.** A Python exception raised in a
  chunk with `error: true` is logged, class `error`, text
  `{ExceptionType}: {message}` (`ValueError: boom`), source the chunk's
  label. Without `error: true` the knit stops, as stock does.
- **G28. Cache.** A Python chunk with `cache: true` served from knitr's cache
  replays the conditions logged when it was computed, as an R chunk does
  (7.4.1): rendering twice gives the same condition log.
- **G29. What is not logged.** Text a Python chunk prints to `sys.stderr`,
  `logging` output, and warnings that a warnings filter hides. A test pins
  that a `print('x', file=sys.stderr)` adds no line.
- **G30. Python modules in the ledger's reads.** In a set-up project, at the
  end of a top-level knit in which Python was running, every module in
  Python's `sys.modules` whose `__file__` lies inside the project root, and
  not under a folder named `site-packages`, `dist-packages`, `.venv`,
  `venv`, `renv` or any folder starting with `.`, is a file the chapter
  read: it is in the header's `files` (7.2.2) by its path relative to the
  root, with its hash, and in `last_knit()$reads$files`. A chunk `import
  helpers` with `helpers.py` in the project root gives `helpers.py`; a
  helper imported by `helpers.py` from the project is there too. Editing
  `helpers.py` afterwards makes the chapter's entries "not re-rendered"
  (7.2.4). A knit in which Python never started records no module and does
  not start Python.
- **G31. Literal Python sources in R code.** A literal path given to
  `reticulate::source_python()` or `reticulate::py_run_file()` (with or
  without `reticulate::`) in R chunk code is a file the chapter read, as a
  literal `source()` is.
- **G32. The reads walker reads R chunks only.** The code of a chunk whose
  engine is not R adds no target, dictionary entry or file to the header. A
  Python chunk `v = dict["depth"]` (valid Python) adds no dictionary entry
  `depth`; a Python chunk `x = tar_read("fit")` adds no target `fit`.

### E. Lints, the gate, captions, set-up (5e)

New lint rules, in a new table 5.11 of the spec (rule numbers as
`lint_rules()` cites them):

| # | Id | Tier | Scope |
|---|---|---|---|
| 1 | `guest-inline` | 1 | file |
| 2 | `guest-call` | 1 | file |
| 3 | `guest-read` | 2 | file |
| 4 | `ojs-value` | 2 | file (5f) |

- **G33. `lint_rules()`** lists the three rules of 5e with these ids, tiers,
  rule numbers "5.11.1" to "5.11.3" and scope `file`; after 5f also
  `ojs-value`, "5.11.4".
- **G34. `guest-inline`.** In the prose of a document that knitr knits (an
  `.Rmd` or `.rmd`; a `.qmd` with `engine: knitr` in its own front matter,
  or with an executed `{r}` chunk and no `engine:` or `jupyter:` key), a
  code span whose text starts `{LANG}` and a space, where `LANG` matches
  `[A-Za-z][A-Za-z0-9_]*` and is not `r`, `R` or `ojs`, is a finding at the
  code span, text the code span as written. Message, for `{python} depth`:
  ``"`{python} depth` is inline Python, which the knitr engine does not run: it would print as code. Bind the value to a name in a Python chunk and write `r py$name` (rule 5.11.1)."``
  For another language (`{julia} x`, `{bash} x`):
  ``"`{julia} x` is inline julia code, which the knitr engine does not run: it would print as code (rule 5.11.1)."``
  Hint for both: `A value from another language reaches prose through R; see vignette("languages", package = "weft").`
  An attribute block after it does not change the finding. Not a finding:
  the same in a `.qmd` with no `engine: knitr`, no `{r}` chunk, or with
  `engine: jupyter`; inside a fenced code block; inside a `.weft-literal`
  span or div.
- **G35. `guest-call`.** In the code of an executed Python chunk (engine
  `python`, `eval` not false), a call `r.NAME(` where `NAME` is one of G19's
  names, not preceded by a letter, digit, `_` or `.`, on a line whose first
  non-blank character is not `#`, is a finding at `r.`, text `r.NAME(`.
  Message:
  ``"`r.fmt_num()` passes its arguments through reticulate, which can turn a Python int into a wrong number with no error. Write `from weft import fmt_num` and call `fmt_num()` (rule 5.11.2)."``
  For `r.claim(`:
  ``"`claim()` cannot be called from Python: a check is written in R, in prose, as `r claim(py$n, . > 10)` (rule 5.11.2)."``
  A match inside a Python string literal is a finding too (accepted: the
  lint does not parse Python). `from weft import fmt_num` and `fmt_num(x)`
  are not findings. `r.depth` (an R value read from Python) is not a
  finding.
- **G36. Code rules ignore guest code** (rule 5.1.4, unchanged and now
  pinned): a Python chunk `dict = {'a': 1}` gives no `dict-assign`; a
  Python chunk with `cache: true` and the text `tar_read(x)` gives no
  `tar-cache`; a Python chunk `claim = 3` adds nothing to the gate's count.
- **G37. `guest-read`** (tier 2, listed over added lines by `changes()` and
  `verify(since = )`, or over a file when asked for):
  - In the code of an executed R chunk: each read `py$...` or `py[[...]]`
    (and with `reticulate::py`) whose `py` is a symbol, except the target
    of an assignment (`py$x <- 1`, `py$x = 1`). One finding per outermost
    read, text the read as written. Message:
    ``"`py$n` in R code is converted by reticulate, which can turn a Python int into a wrong number with no error. For a value that reaches prose, read it with py_value("n") (rule 5.11.3)."``
    (`py_value(...)` shows the path of the read as strings:
    `py$cfg$depth` gives `py_value("cfg", "depth")`.)
  - In an expression weft evaluates (G9's places): a call of `py_eval`,
    `py_to_r`, `py_get_attr`, `py_call`, `import_main`, `py$f(...)` (a call
    of a read), `julia_eval`, `julia_call`, `julia_get` (each with or
    without its package prefix). Message for `` `r py_eval("x")` ``:
    ``"`py_eval("x")` is converted by reticulate, which weft does not check (rule 5.11.3)."``
    and for JuliaCall:
    ``"`JuliaCall::julia_eval("x")` is converted by JuliaCall, which weft does not check (rule 5.11.3)."``
    The text quoted is the call as written.
- **G38. The `engine` lint's message, by case** (rule 5.8.9; when it fires
  is unchanged). For `a.qmd`:
  1. Front matter `engine:` other than `knitr` (`jupyter`, `julia`,
     `markdown`), or a `jupyter:` key:
     ``"a.qmd holds weft constructs and is marked `engine: jupyter`; weft constructs are evaluated only under `engine: knitr` (rule 5.8.9)."``
     (for a `jupyter:` key, "is marked `jupyter: python3`" with its value
     as written), hint ``"Change it to `engine: knitr`. Python chunks then run through reticulate, and a Python value reaches prose as `r py$x`."``
  2. Otherwise, no executed `{r}` chunk and at least one Python chunk:
     ``"a.qmd holds weft constructs and Python chunks but is not marked `engine: knitr`, so Quarto would run it with Jupyter, which does not evaluate weft constructs (rule 5.8.9)."``
     hint ``"Add `engine: knitr` to its front matter. Python chunks then run through reticulate, and a Python value reaches prose as `r py$x`."``
  3. Otherwise, no `{r}` chunk and at least one Julia chunk:
     ``"a.qmd holds weft constructs and Julia chunks but is not marked `engine: knitr`, so Quarto would run it with its julia engine, which does not evaluate weft constructs (rule 5.8.9)."``
     hint ``"Add `engine: knitr` to its front matter. Julia chunks then run through JuliaCall, whose values weft does not check (rule 2.12.13)."``
  4. Otherwise the message and hint of today, unchanged.
- **G39. Captions on guest chunks** stay refused (2.3.5), with today's text.
  A `fig-cap` holding `[# site | # sites]{n="k"}` on Python chunk `p1` is a
  construct error, from the source (the lints' `construct` rule) and at
  knit time, with the message
  ``"A `n` construct in a caption of chunk `p1`, which uses the `python` engine, not R: write the caption in a figure or table div instead, `::: {#fig-name}` ... caption paragraph ... `:::` (rules 1.10.5, 2.3.5)."``
  Bare inline R in a guest chunk's caption stays literal (1.1.8).
- **G40. The gate on guest documents.** Nothing changes in how it counts
  (6.3.1): values and spans in prose, `claim()` in R chunks. Findings of
  `guest-inline` and `guest-call` are tier-1 findings like any other: one
  added fails a commit. A `weft_str('…')` call in Python chunk code is not
  read: its constructs are not counted and its prose is not linted (V18).
- **G41. `use_setup()` and a Python-only `.qmd`.** `use_setup()` adds
  `engine: knitr` to a `.qmd` that holds only another engine's chunks when
  it holds a weft construct (a scanner row other than bare, link or
  literal) and has no `engine:` or `jupyter:` key. A `.qmd` with only Python
  chunks and no construct is left as today (H29). `status()` flags exactly
  the files `use_setup()` would change (the existing test `review-code-c
  #10` keeps passing, and gains the Python-only case).

### F. Observable JS (5f)

- **G42. `ojs-value`** (tier 2). In a `.qmd`: a code span in prose whose
  text starts `{ojs}` and a space; and, in the code of an `{ojs}` chunk, each
  `${` inside a template literal tagged `md` or `html`. Finding at it, text
  the code span or the `${...}` as written. Message for `` `{ojs} total` ``:
  ``"`{ojs} total` is computed in the reader's browser after weft's checks have run, so weft cannot vouch for it (rule 5.11.4)."``
  for a template, ``"`${total}` in an Observable template is computed in the reader's browser after weft's checks have run, so weft cannot vouch for it (rule 5.11.4)."``
  Hint: ``"Compute the value when the document renders, in R or Python, and print it as a weft value; or mark the text [...]{.weft-literal why=\"...\"}."``
  Not a finding inside a `.weft-literal` span or div, or in an `.Rmd`.

### G. The article (5g)

- **G43.** `vignettes/languages.Rmd` exists, with title "Python and Julia
  chunks", is listed in `_pkgdown.yml` under "Writing", and builds with no
  Python: its chunks are `eval = FALSE` and the output shown was printed by
  a real run, as `gate.Rmd` does. `py_value` is in the reference index.
  `R CMD check` and `pkgdown::check_pkgdown()` pass.

### J. Julia (5J): designed, not built in this stage

No code and no tests now. To be built only on a machine with Julia and
JuliaCall, by the same pattern as 5b to 5d.

- **J1.** `jl_value(...)` reads a global of Julia's `Main` through JuliaCall,
  by 1.11: `Bool` bool; `Int8` to `Int128`, `UInt8` to `UInt128`, `BigInt`
  integer (±2^53 as G5); `Float16`/`32`/`64` float, `NaN` and `Inf`
  missing; `String`, `SubString` string; `Dates.Date` date; `DateTime`
  refused; `nothing`, `missing` missing; a one-dimensional `AbstractVector`
  or a `Tuple` a list (`Union{Missing, T}` elements allowed); a `NamedTuple`
  or an `OrderedDict` with `String` or `Symbol` keys a list with names;
  `Dict` refused (no order); `Rational`, `BigFloat`, `Char`, a `Matrix`
  refused. The classifier is a Julia function weft defines once in a module
  of its own and calls on the unconverted value, returning kinds and
  decimal strings.
- **J2.** In prose `jl_value("x")` only; there is no `jl$x` object to
  rewrite. `JuliaCall::julia_eval()` in prose stays unchecked and listed by
  `guest-read` (built now, G37).
- **J3.** Warnings: a Julia logger installed by weft records `@warn` records
  as G25 does for Python.
- **J4.** Reads: a literal `include("x.jl")` in a Julia chunk is a file read.
- **J5.** Function forms from Julia: none (rung 5).

## 3. Decisions

Smallest undoable change first. "Reverse" names the place to change.

| # | Point | Alternatives | Chosen | Why | Reverse |
|---|---|---|---|---|---|
| V1 | Where to guard a Python value | (a) check the converted value afterwards; (b) an S3 method `py_to_r.python.builtin.int`; (c) put a weft `py` object in the knit's environment, so R chunk code is guarded too; (d) an accessor only, plain `py$x` in prose left to reticulate and linted; (e) read twice, converted and unconverted, and compare | read every `py$...` in an expression weft evaluates as `py_value()` reads (G9), plus `py_value()` for R code | (a) and (b) cannot work: measured 2. (c) changes what R chunk code does, breaks `py_has_attr(py, ...)` and the like, and writes into the author's environment. (d) leaves the spelling every reticulate tutorial teaches silently wrong. (e) needs the same rewrite, then does the work twice. | G9 off: eval as today |
| V2 | Integers beyond what R holds | `bit64::integer64`; a decimal string under a weft class; refuse | refuse beyond ±2^53 (M1) | the formatter is double-only (1.4.13 reads a double); a new number type through `format.R` is architecture (c)'s job, where Lua prints any size; such numbers are rare in prose and a refusal is honest | G5 row |
| V3 | `decimal.Decimal` | refuse all; always nearest double | nearest double up to 15 significant digits, else refuse | 1.4.13 reads a double to 15 digits, so up to 15 the decimal comes back exactly and "0.15" rounds to "0.2" as written; beyond, the nearest double would be a silent change | G5 row |
| V4 | `[]` given to `if` is a value error (the study), but 1.3.4 calls length zero "no value" | carry the guest kind on the R value as an attribute; make every length-zero `if` a value error; leave it "no value" | judge the kind when the governor's expression is exactly a guest read (G13); R's own length-zero vector stays "no value" | an attribute survives arithmetic (`py$n > 0` would keep "integer") and prints in chunk output; changing R's rule changes 1.3.4; R has no list-scalar distinction, a guest does, and the exact read is where it is still known | G13 off |
| V5 | A `dict` (the task's set has no mapping) | refuse | a list with names (G6) | `.pairs` on a dict works today through `unlist()`; names are cheap in any carrier, Lua's included | G6 bullet |
| V6 | pandas and numpy | refuse all; convert DataFrames | `Series` and one-dimensional arrays as lists (`tolist()`), DataFrames refused | a column is the common way a number list arrives; a two-dimensional table has no place in prose; reticulate 1.43.0 does not convert pandas 3.1.1 objects anyway (measured 1) | G5 rows |
| V7 | Bare values | stock (1.1.8), as reticulate converts | guarded too (G11) | `` `r py$n` `` is the commonest spelling a Python author will write; a silent wrong number there defeats the stage. The only visible change is `None` printing "NA" instead of "" | G11 |
| V8 | `py` availability | attach an active binding `py` at the end of the search path; attach `py` only when reticulate is loaded at `weft_setup()`; nothing | prose needs no `py` (G10); `weft_setup()` loads nothing and hooks Python's start (G18); R chunk code uses `py_value()`, or stock `library(reticulate)` | a `py` in every session invites the unguarded route in chunk code; reticulate is usually loaded by the first Python chunk, after `weft_setup()` | G18 |
| V9 | Function forms from Python | document `r.fmt_num()` (measured 4: `r.g(2**53 + 1)` is 1); a formatter written in Python | a module `weft` of R functions that receive unconverted arguments (G19 to G21); `r.fmt_num()` is a tier-1 finding (G35) | same output as R by construction, safe arguments, about 60 lines; a Python formatter is rung 5 and a second formatter | G19 |
| V10 | Guest warnings and errors | parse the chunk's output text; nothing | wrap `warnings.showwarning`; read `py_last_error()` after a chunk with `error: true` (G25 to G27) | both measured; the output is untouched; parsing printed text breaks with locale and wording | G25 |
| V11 | Files a Python chunk reads | regular expressions on `import` lines; wrap `builtins.__import__`; nothing | modules in `sys.modules` under the project root at the end of the knit (G30), and literal `source_python()` (G31) | exact under Quarto (one process per document) and cheap; a session that knits several documents may list a module an earlier one imported, which makes an entry stale when it need not be, never the reverse | G30 |
| V12 | Tiers of the new lints | all tier 2; all tier 1 | `guest-inline`, `guest-call` tier 1; `guest-read`, `ojs-value` tier 2 | the first two are always wrong and have a mechanical remedy; `py$df` in R code is often right (a data frame for a plot) and `py_value()` refuses a DataFrame | the table in E |
| V13 | The `engine` message | one message | four cases (G38) | a Python author needs to be told what to write, and that Jupyter is why | G38 |
| V14 | `use_setup()` on a Python-only `.qmd` (H29 left it) | leave it | add `engine: knitr` when it holds a construct (G41) | such a file is broken on Jupyter anyway: its constructs are not evaluated, and the pre-render script fails it | G41 |
| V15 | Julia, with none installed | build untested code; tests that skip without Julia; designed only | static parts built (G34, G37, G38), runtime designed (J1 to J5), no Julia tests | code that has never run once is a liability, and a test that always skips here cannot be checked to fail for the right reason | 5J |
| V16 | Observable JS lint | out of the stage | in, tier 2, last package (G42) | about 40 lines; weft's promise is that every value in prose is vouched for or marked, and a reactive value is the one kind that can never be | drop 5f |
| V17 | The exact-integer defect in `format.R` | leave it; refuse whole numbers above 1e15 | fix up to 2^53 (G1 to G3), first | a guarded Python integer would still print wrong; R values were wrong too | `round_half_away()` |
| V18 | `weft_str('…')` in Python code | read simple Python string literals | not read | the lints read R literals through R's parser; a Python reader of quotes, triple quotes, escapes and f-strings is a parser to keep; few authors will build markup in Python | O7 |
| V19 | Section numbers | one new section | 1.11 (typed values, language-neutral, reused by a Lua design) and 2.12 (the runtime under knitr), 5.11 (lints) | the typed rules must outlive this architecture | §6 |
| V20 | Python module name | `weftr`; `weft_r` | `weft` (O1) | the same import line would serve architecture (c)'s Python package | G19 |

**Contradictions and gaps found:** the study's 6.2 ("a Python `[]` given to
`if` is a value error") against 1.3.4 ("length zero is missing"), settled by
V4; 1.1.8 (bare values are stock) against the stage's purpose, settled by
V7; H29 against a Python-only document that holds constructs (V14); 7.2.2
records source files, not data files, for R too, so the study's finding 7 is
narrower than it read; 1.4.13's "as written" is not met by R weft for whole
numbers of 15 or more digits (measured 8).

## 4. Work packages

Start after the `R/io.R` refactor is on `main`. 5a, 5b and 5e have no file
in common and can run in parallel worktrees; 5c needs 5b; 5d needs 5c; 5f
needs 5e (shared lint files); 5g last. NAMESPACE and `man/` are regenerated
with roxygen after each merge, never merged by hand. Each package is one
implementer session; the test-writer for it works from §2 and §5.

| Pkg | Creates | Edits | Tests |
|---|---|---|---|
| **5a** exact integers (G1 to G3) | | `R/format.R` (`round_half_away()`, `print_one()`) | `test-format-exact.R` |
| **5b** reading (G4 to G17a) | `R/guest.R` (the reader, the rewrite of G9, `py_value()`, messages), `inst/python/weft_guest.py` (the classifier) | `R/resolve.R` (`eval_expr()`, `stock_bare_text()`, the governor check of G13 in `render_if`, `render_n`, `render_sign`, `render_list`), `R/weft-str.R` (`inline_function_names()` gains `py_value`), `DESCRIPTION` (Suggests), `_pkgdown.yml` (reference) | `helper-5.R`, `test-guest-types.R`, `test-guest-prose.R`, `test-guest-governors.R` |
| **5c** activation and function forms (G18 to G24) | | `R/guest.R` (the module, registration, the hook), `R/hooks.R` (`weft_setup()`; the option hook registers on a Python chunk), `inst/python/weft_guest.py` | `test-guest-setup.R`, `test-guest-forms.R` |
| **5d** conditions and reads (G25 to G32) | | `R/conditions.R`, `R/captions.R` (`install_chunk_wrapper()`: the chunk hook drains a guest chunk's warnings and errors), `R/resolve.R` (`run_inline()`: prose drain), `R/targets.R` (`note_chunk_code()` keeps the engine; the walker skips non-R; modules; `source_python()`), `R/guest.R`, `inst/python/weft_guest.py` (the warning recorder) | `test-guest-conditions.R`, `test-guest-reads.R` |
| **5e** lints and set-up (G33 to G41) | | `R/lint.R` (the registry), `R/lint-doc.R` (`lint_engine()`, `guest-inline`, `guest-call`), `R/lint-code.R` (`guest-read`), `R/lint-source.R` only if Python chunk code is not yet kept, `R/setup.R` and `R/use-weft.R` (one shared predicate for G41) | `test-lint-guest.R`, `test-lint-engine-guest.R`, `test-use-setup-guest.R` |
| **5f** Observable (G42) | | `R/lint.R`, `R/lint-doc.R` | `test-lint-ojs.R` |
| **5g** article (G43) | `vignettes/languages.Rmd` | `_pkgdown.yml` | none (R CMD check builds it) |
| **5J** Julia (J1 to J5) | `R/guest-julia.R`, `inst/julia/Weft.jl` | as 5b to 5d | later, on a machine with Julia |

The spec editor applies §6 after 5g.

## 5. Tests

**Which need a real Python.** Every test of 5b, 5c and 5d. They skip only
when reticulate is not installed or reticulate cannot find and start a
Python; never otherwise (no `skip_on_cran()`, no `skip_on_ci()`). Cases that
need numpy or pandas skip only when that module does not import. Tests of
5a, 5e and 5f need no Python: they never skip for it. The Quarto case (G17)
also follows `helper-quarto.R`'s skips. The orchestrator should run the
numpy and pandas cases once with `RETICULATE_PYTHON` set to the
scratchpad's virtual environment (measured), since the default Python here
has neither.

**`helper-5.R`** (loaded for the files below):

- `skip_if_no_python()`: `skip_if_not_installed("reticulate")`; then, only
  if reticulate has not yet started Python in this process, set
  `RETICULATE_USE_MANAGED_VENV=no` and, when `RETICULATE_PYTHON` is unset
  and `Sys.which("python3")` is not empty, `RETICULATE_PYTHON` to it; then
  skip with "reticulate found no Python" unless
  `reticulate::py_available(initialize = TRUE)`. No test downloads or
  installs anything.
- `skip_if_no_py_module(m)`: skips unless `reticulate::py_module_available(m)`.
- `py_set(...)`: `reticulate::py_run_string()` of `name = <python
  expression>` lines.
- `k5(lines, files = list(), weft_yml = NULL)`: writes a temporary project
  (with `_weft.yml` when given), knits `doc.Rmd` in process with weft set
  up from a setup chunk, and returns the output lines, `last_knit()`, the
  condition log lines and the ledger header. `k5_fresh()`: the same in a
  fresh `Rscript` process (for G14's M16, G15, G18).
- Python's state is shared by every test in one process: each test uses
  names of its own (`t_g5_b53`), and the missing-name tests use names never
  set.

**Files and what each covers.**

- `test-format-exact.R` (5a): every example of G1 to G3, in prose
  (`` `r x`{.num} ``, `#` of an `n` span) and as functions; a check that
  `fmt_num(0.15)` is still "0.2" and `fmt_num(2.5)` still "2.5".
- `test-guest-types.R` (5b): G5 row by row through `py_value()`, outside a
  knit: kind, R type and value with `expect_identical()`; every refusal's
  class and exact message (M1 to M9) with `{S}` `` `py_value("x")` ``;
  G6's examples, including promotions, names, empty, all-missing, nested,
  mixed; numpy rows (`skip_if_no_py_module("numpy")`), pandas rows
  (`"pandas"`); G8's path steps (mapping key, then attribute), its argument
  error, M13 and M14; a refused `2**70` leaves no pending Python error
  (`reticulate::py_eval("1 + 1")` is 2 afterwards).
- `test-guest-prose.R` (5b): G9's forms in values (`py$x`, `py[["x"]]`,
  chains, `reticulate::py$x`, `py_value("x")`), each printing a guarded
  value, and `{.num}` on `2**53 + 1` a value error with the exact `detail`;
  G10 (`py <- list(x = 3)`, `py$f(2)` left to reticulate); G11's four bare
  cases; G12's marker and detail texts; G14 with the seam and, in a fresh
  process, M16; G15 in a fresh process; G16 (a later Python chunk runs);
  G17 with Quarto; G17a (an R chunk caption, `weft_str()` in an R chunk, and
  `x <- py$b53` in an R chunk printing reticulate's "1": pinned as the
  documented limit); no `library(reticulate)` anywhere in these documents.
- `test-guest-governors.R` (5b): G13's every listed case, with exact M10
  to M12 texts and markers; `claim()` around a read; several `if`
  conditions; missing is "no value"; a non-exact expression judged by R.
- `test-guest-setup.R` (5c): G18 in fresh processes (nothing loaded; the
  hook registers on start; one hook after two calls; registration when
  Python is already running); G23 (a dummy `weft` module put in
  `sys.modules` first; the warning once; the dummy kept); G24 pinned.
- `test-guest-forms.R` (5c): G19's exact set of names, `__weft_r__`,
  `ImportError` for `claim`; G20's cases against the R calls; G21's
  exception messages caught in Python (`try: ... except Exception as e:
  msg = str(e)`) and read in R; G22 in an `asis` chunk: the text, a failed
  guard's marker with the chunk label, the render failing once; outside a
  knit, raising.
- `test-guest-conditions.R` (5d): G25's exact log line, the
  `last_knit()$conditions` row, an R chunk calling Python, a prose source;
  the document identical to a plain `knitr::knit()` of the same file
  without weft (a document whose prose has no construct); G26 with a
  project `severity:` pattern; G27; G28 (render twice, the log equal); G29
  (stderr print, `logging.warning`, a filtered warning: no line).
- `test-guest-reads.R` (5d): G30 (`helpers.py` and a module it imports in
  the header with hashes; a module in a `.venv` folder of the project not
  there; edit the file, then `changes()` or the ledger state says not
  re-rendered; a knit with no Python leaves Python unstarted, checked in a
  fresh process); G31 (`source_python("tools.py")` in an R chunk, with and
  without `reticulate::`); G32's two cases.
- `test-lint-guest.R` (5e): G33's `lint_rules()` rows; G34 (`.Rmd`,
  `engine: knitr` `.qmd`, `.qmd` with an `{r}` chunk, a Jupyter `.qmd` with
  none, a fenced block, a `.weft-literal` span, `{julia}`, with and without
  an attribute block, exact messages); G35 (`r.fmt_num(`, `r.claim(`, a
  comment line, `from weft import`, `r.depth`, an `eval: false` chunk);
  G36's three cases; G37 (R chunk reads, chains, assignment targets not
  flagged, `eval: false` not read, prose calls of each listed function,
  exact messages, tier 2 and so absent from `lints()` with no `tier`); G39
  (static and knit-time message for a Python chunk caption, exact); G40
  (`gate()` fails on an added `` `{python} x` ``; a `weft_str('...')`
  removed from a Python chunk needs no trailer).
- `test-lint-engine-guest.R` (5e): G38's four cases, exact messages and
  hints; the existing R-only message unchanged.
- `test-use-setup-guest.R` (5e): G41 (Python-only with a construct gains
  the line; without one, kept; `engine: jupyter` and `jupyter: python3`
  kept; `status()` agrees in each case).
- `test-lint-ojs.R` (5f): G42 (inline `{ojs}`, `md` and `html` templates,
  a template with no `${`, a plain JavaScript string with `${` outside a
  tagged template, `.weft-literal`, an `.Rmd`), exact messages, tier 2.

**CI.** The package has no check workflow, only `pkgdown.yaml`. The
article does not run Python (G43), so that workflow needs nothing new. The
guest tests therefore run only where a developer runs them (O3).

## 6. Spec changes (for the spec editor, after 5g)

### New section 1.11 Typed values

**1.11.1** A value that comes from another language is a **typed value**:
exactly one of bool, integer, float, decimal, string, date, list, or
missing. Anything else is a value error that names the value's type in its
language.

**1.11.2** An integer is a whole number, held exactly. A float is an IEEE
double. A carrier that cannot hold a value exactly refuses it with a value
error; it never rounds it. (R holds integers exactly up to ±2^53, 2.12.5.)

**1.11.3** A decimal is an exact decimal number. 1.4.13 rounds it on the
number as written.

**1.11.4** A list is a flat, ordered sequence whose elements are missing or
of one kind among bool, integer, float, decimal, string and date. Integers
with floats are floats; integers with decimals are decimals; any other mix
is a value error, and so is an element that is itself a list, a set or an
array. An unordered collection (a set) is a value error. A mapping whose
keys are all strings is a list with names, in the mapping's order; other
keys are a value error.

**1.11.5** A string is text. Text from data is not escaped (1.4.10).

**1.11.6** A date is a calendar date with no time and no zone. A date with a
time is a value error: the author converts it in the source language, in
the zone they mean.

**1.11.7** What is missing, by language:

| Language | Missing |
|---|---|
| R | `NA` of any type, `NaN`, `Inf`, `-Inf`, `NULL`, and length zero (1.3.4) |
| Python | `None`, a float NaN or infinity (numpy's too), `Decimal` NaN and infinity, `pandas.NA`, `pandas.NaT`, `numpy.datetime64('NaT')` |
| Julia | `nothing`, `missing`, `NaN`, `Inf`, `-Inf` |
| JavaScript | `null`, `undefined`, `NaN`, `Infinity` |

An empty list is not missing; it is a list of length zero, and 1.3.4 says
where length zero is missing.

**1.11.8** No truthiness. An `if` condition is a bool. Any other kind, an
empty list, a list of one bool, `0`, `1`, `""` and `"false"` included, is a
value error, not false. A missing condition is "no value".

**1.11.9** An `n` or `sign` governor is an integer, a float or a decimal. A
bool is not a number, and a list of one number is not a number.

**1.11.10** A `list` span takes a list.

**1.11.11** No carrier reads a language's printed form of a value. The kind
comes from the value's type.

For an R value, 1.3.4 and §1.5 are these rules as R states them: R has no
difference between a value and a vector of one.

### New section 2.12 Guest languages under knitr

**2.12.1** In an `.Rmd`, and in a `.qmd` with `engine: knitr`, Python chunks
run through reticulate (knitr's default python engine) and Julia chunks
through JuliaCall. R is the host: expressions in prose are R (1.1.2), and a
value from another language reaches prose through R. weft supports
reticulate's engine only.

**2.12.2** A **guest read** is `py$name`, `py[["name"]]`, a chain of them,
the same with `reticulate::py`, or `py_value(...)`. In an expression weft
evaluates (a value, a bare value, a governor, a caption construct, a
`weft_str()` string) every guest read is read by §1.11, not by reticulate's
conversion. `py` is Python's main module unless the expression's
environment binds `py` to something else. A call whose function is a guest
read (`py$f(2)`) is reticulate's.

**2.12.3** Prose needs no `library(reticulate)`.

**2.12.4** `py_value("name", ...)` reads by §1.11 from R code. Each further
argument is a key of a mapping, or else an attribute. It is the route for a
value that R chunk code passes to prose.

**2.12.5** The R form of a typed value:

| Kind | R form |
|---|---|
| bool | `TRUE` or `FALSE` |
| integer | an `integer` within ±(2^31−1); a `double` up to ±2^53; beyond, a value error |
| float | a `double` |
| decimal | the nearest `double`, for at most 15 significant digits; beyond, a value error |
| string | a `character` of length one |
| date | a `Date` |
| list | an atomic vector of its kind, missing elements `NA`, names from a mapping; empty: `logical(0)` |
| missing | `NA` |

**2.12.6** A guest read that cannot be done (no reticulate, no Python, no
such name) is an expression that cannot be evaluated (2.6.4). A value
refused by §1.11 is an error that depends on the value (5.3.2). In a bare
value the first stops the knit and the second is collected, as for any
bare value.

**2.12.7** When a governor's expression is exactly one guest read, or a
`claim()` of one, 1.11.8 to 1.11.10 are applied to the kind read.

**2.12.8** In a Python chunk the function forms are a Python module:
`from weft import fmt_num, plural, weft_str`. It holds the formatter
functions of §3.4 (not `fmt_unit()`), `plural()`, `ci()`, `pm()`,
`about()`, `of_n()` and `weft_str()`. Arguments are read by §1.11; each
returns the text the R function returns. `claim()` is not there. weft does
not replace a module named `weft` that is already loaded.

**2.12.9** Text a Python chunk prints with `results: asis` is not resolved,
and the check filter catches what is left (2.5). `weft_str()` from the
module resolves it, as 3.6 says, located by the chunk's label.

**2.12.10** A warning Python shows, and an error a chunk with `error: true`
raises, are logged as conditions of the chunk that raised them (7.4.1), and
the severity list applies (7.4.2). Text printed to standard error and the
`logging` module are not logged.

**2.12.11** A Python module whose file is in the project, loaded when a
top-level knit ends, and a literal path given to `source_python()` or
`py_run_file()`, are files the chapter read (7.2.2).

**2.12.12** The code of a guest chunk is not read by the code lints, the
reads walker or the gate, except by the rules of 5.11. Its captions hold no
construct (2.3.5).

**2.12.13** Not checked by weft: a value R chunk code takes with `py$x`
(listed by `guest-read`); a Julia value (`JuliaCall::julia_eval()`, listed
by `guest-read`); units and dictionary entries from Python; a markup string
built in Python code (not linted, not counted by the gate); data files a
Python chunk reads (as for R).

**2.12.14** `weft_setup()` loads no Python. When Python starts, or when
weft first reads from it, weft registers its Python module and its warning
recorder.

### Amendments

- **1.1.2** add: "A value from another language reaches them through R, by
  a guest read (2.12.2)."
- **1.1.8** add: "A guest read in a bare value is read by 2.12.2."
- **1.3.4** add: "What is missing in another language is given by 1.11.7."
- **1.4.13** add: "A number that is an integer of magnitude at most 2^53
  prints every digit exactly, under any `digits`."
- **2.8.1** add: "For a Python chunk, 2.12.10."
- **3.2.4** (new): "From a Python chunk the function forms are a module
  (2.12.8)."
- **3.6.4** (new): "From a Python chunk, `weft_str()` is in the module
  (2.12.8)."
- **5.1.4** add: "The code of a guest chunk is read only by rules 5.11.2 and
  5.11.4."
- **5.8.9** the four messages of G38 in its notes.
- **5.11 Guest languages and reactive values** (new table): rows 1 to 4 of
  E's table, each with its tier and the rule text of G34, G35, G37, G42.
- **7.2.2** add to the header's files: "every Python module of 2.12.11".
- **7.4.1** add a fifth source: "warnings and errors from Python chunks
  (2.12.10)".
- **9.2.8 and 9.3.1** (`use_setup()` row): a `.qmd` that holds only another
  engine's chunks gains `engine: knitr` when it holds a construct (G41).
- **§16** add: the Jupyter and julia engines, a Lua formatter, units and the
  dictionary in another language, `claim()` in Python.
- **§19** add: Julia and JuliaCall not run; Jupyter not run; numpy and
  pandas run only in a temporary environment.
- **§21** add the test files of §5; **§22** add stage 5 with the packages
  of §4.

### Article outline: `vignettes/languages.Rmd` ("Python and Julia chunks")

For an author who writes Python (or Julia) and wants weft's values and
checks. Written in the style of the other articles; chunks `eval = FALSE`
with output from a real run.

1. **What works and where.** `.Rmd`, and `.qmd` with `engine: knitr`. Not
   the Jupyter or julia engines. R is installed and runs the render.
2. **Set-up.** `engine: knitr`, reticulate installed, `weft_setup()` (or
   `use_setup()`). No `library(reticulate)` is needed for prose.
3. **A Python value in a sentence.** `` `r py$depth`{.num} ``, a claim
   (`claim(py$n, . > 10)`), `n`, `if`, `list` spans, `.and`, `.date`.
4. **The kinds weft reads.** The table of 2.12.5, missing values, and why
   it refuses: the `2**53 + 1` that reticulate prints as 1.
5. **Conditions are bools.** Why `[]` and `0` are errors; write the test in
   Python (`has_sites = len(sites) > 0`) or in R.
6. **Python values in R code.** `py_value()`; plain `py$x` and the
   `guest-read` list; data frames for plots stay reticulate's.
7. **Formatting from Python.** `from weft import fmt_num, plural`; why not
   `r.fmt_num()`.
8. **Text with constructs from Python.** `weft_str()` with `results: asis`.
9. **Captions.** Figure and table divs (1.10.5).
10. **Warnings and errors.** What reaches the condition log, what does not,
    the severity list with a Python warning.
11. **Files.** Python modules in the ledger; data files are not, as in R.
12. **The lints and the gate on a Python document.** What they read and what
    they cannot (a markup string built in Python).
13. **Julia.** Chunks run through JuliaCall; weft does not check Julia
    values yet; `guest-inline` and `guest-read`.
14. **Observable JS.** Values computed in the browser; `ojs-value`;
    `ojs_define()` from a checked R or Python value.
15. **Limits**, in one list.

## 7. Open questions for the orchestrator

Each has a recommended answer; the build follows it unless told otherwise.

- **O1. The Python module's name.** `weft` (as G19) or `weftr`.
  Recommended: `weft`, with G23's guard. The same `from weft import ...`
  would serve architecture (c)'s Python package, and no real conflict is
  known.
- **O2. reticulate's minimum version.** `>= 1.43.0` (the one measured) or
  lower and untested. Recommended: 1.43.0, raised or lowered only on
  evidence.
- **O3. A check workflow with Python.** The package has no
  `R-CMD-check` workflow; the guest tests run only on a developer's
  machine. Recommended: add one as a small separate task (r-lib's
  `check-standard` plus `actions/setup-python` and
  `pip install numpy pandas`), so that the skip-guarded tests run somewhere.
- **O4. R values at or above 2^53 under `.num`.** Today they print through
  the 15-digit reading, which is right for `1e23` as written and wrong for
  an exact count such as `2^60`. Recommended: leave them in this stage;
  decide when an author has such a number.
- **O5. `use_setup()` on a Python-only `.qmd` with a construct (G41)**
  reverses part of H29. Recommended: yes, as G41.
- **O6. The Observable lint in this stage (5f).** Recommended: yes, tier 2,
  last; drop it if time is short, nothing depends on it.
- **O7. Markup strings built in Python code.** Not linted, not counted by
  the gate (V18). Recommended: accept and document; revisit when a Python
  author builds markup in Python.
- **O8. Julia at runtime (5J).** Recommended: build only on a machine with
  Julia and JuliaCall, and only when a Julia author asks.
- **O9. The author's CI from `use_ci()`** does not set up Python for a
  project with Python chunks. Recommended: say so in the article now; add a
  `python = TRUE` argument when a project needs it.
- **O10. `guest-read` in R chunk code at tier 2.** Recommended: tier 2; tier
  1 would block the common, correct `py$df` for a plot.

## Rulings on the open questions (orchestrator, 13 Nov, under delegation)

Every recommended answer is accepted: O1 `weft`; O2 reticulate
`>= 1.43.0` in Suggests; O3 a check workflow with Python, as its own
small task after 5e; O4 left; O5 yes, as G41; O6 in, last; O7 accepted
and documented; O9 said in the article; O10 tier 2.

O8 with one change: Robin has since allowed Julia to be installed for
the study of architecture (c). If that study installs it, 5J is built
and tested here after 5d; if not, 5J waits as recommended.

The exact-integer defect in `round_half_away()` (5a) is a fault in
weft for R values too, so it goes first and does not wait on the rest.

## Amendment after the scoping of architecture (c) (orchestrator, 13 Nov)

`dev/languages-c-scoping.md` asks that three things be shaped now so a
later resolver filter is not made harder. Ruled, under delegation:

1. **The typed record is the reader's product (5b).** The Python
   reader returns, for each value, a record: one of bool, int (as a
   digit string), float (shortest round-trip text), decimal (as
   written), string, date (ISO), list of one type, missing (with why),
   or error (with why). The record is turned into an R value in one
   function, and the refusals of V2 and V3 live there. Alternatives:
   convert inside the reader (smaller now, and the big integer is lost
   before anything could print it); carry digit strings through
   `format.R` now (the scoping's stage 0 in full, days more, and a new
   number type through every formatter). Chosen: the record now, the
   refusal kept, the digit-string printer left to the filter stage,
   because a refusal is honest and the record is what keeps that later
   step small.
2. **Rule 1.4.13 past 15 significant digits (5a).** A double is read to
   15 significant digits, so the digits after the fifteenth print as
   zeros: `2^70` prints "1,180,591,620,717,410,000,000", not the
   binary expansion. Alternatives: refuse (breaks `1e23`, which is
   right as written); leave (false digits). This replaces the answer
   to O4.
3. **A conformance table (new package 5h, after 5a).** R writes value,
   classes, keys and printed text for a fixed corpus (numbers first,
   then `.word`, `.and`, `n`) to `tests/testthat/_conformance/`; a
   test compares on every run. It is a regression net for `format.R`
   now and the definition of "what weft prints" for any second
   formatter. The scoping's literal Lua port matched R on 67,060 rows.

Also reserved, with nothing built: the class `weft-values`, the named
value form (a code span holding one name, with a class) and the class
`val`. `weft-check.lua` already fails on a code span carrying a weft
class, which stays the right error until a resolver exists.
