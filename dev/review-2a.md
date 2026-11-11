# Review of package 2a — the dictionary object

Snapshot: `git archive` of 1065cb0. Units 1.0.0, yaml 2.3.12, knitr 1.51,
rmarkdown 2.31, Quarto 1.11. All cases were run. `rend()` means
`rmarkdown::render(<dir>/doc.Rmd, md_document(variant = "markdown"))` in one R
session, from a setup chunk that calls `weft::weft_setup()`. `fx` is
`tests/testthat/_dict/dict.yml`.

## Findings

**1. A knit with no `dict.yml` and no `dict_local` still sees the previous knit's `dict` and `dict_local`.** Severity: silent.
Repro: in one session, `rend("A")` with `dict.yml` = fx and front matter `weft: dict_local: sites: {value: 7, type: number, definition: d, why: w}`. Then `rend("B")` in another folder that has neither, with body
`` B reads dict: `r dict$min_samples`; local `r dict_local$sites`. ``
Observed: `B reads dict: 5; local 7.` and `last_knit()$dict` is `NULL`. The same happens with `exists('dict')` → TRUE in a document with no `dict.yml`.
Expected: "object 'dict' not found". §2 "In a knit": "Every top-level knit re-creates them"; D14: "no chapter sees another's entries". Cause: `init_dicts()` returns early when neither exists and never removes the objects that an earlier knit assigned into `knit_global()`.

**2. A year loses its "no thousands mark" through `c()`, `range()`, `max()`, `seq()` and vector arithmetic, and `.ord` ignores the mark.** Severity: wrong output.
Repro (a knit with fx): `` `r c(dict$method_change, dict$method_change + 10L)`{.range} `` → `2,014--2,024`; `` `r dict$method_change`{.ord} `` → `2,014th`; `` `r dict$method_change + 0:2`{.and} `` → `2,014, 2,015 and 2,016`; `` `r max(dict$method_change, 2020L)`{.num} `` → `2,020`. With the function forms: `fmt_num(c(y, 2015L))` → `2,014 2,015`, and `fmt_range(range(y, y + 10L))` → `2,014–2,024`.
Expected: `2014–2024`, `2014th` and so on. Rule 4.2.1: a year is "never given a thousands mark". A range of years is the most common way a year reaches prose. The contract (§2 Years) covers only scalar arithmetic. `y + 0:2` drops the attribute because R keeps the attributes of the longer operand.

**3. YAML 1.1 leading-zero and hex integers are read as octal and hex.** Severity: silent.
Repro: `a: {value: 010, type: number, definition: d}` → `8`. `012` → `10`, `-012` → `-10`, `0x1F` → `31`. For `type: year`, `value: 03736` → `2014`. A `breaks` bound `below: 010` → `8`. (`08` and `09` are not valid octal, so they come back as strings and `num_literal()` reads them as 8 and 9. A file can therefore hold `07`, `08`, `010` and read them as 7, 8 and 8.)
Expected: an error, or the decimal value. §2 table, `number`: "a number". D7 accepts only decimal literals written as strings (`0o10` is rejected, which is inconsistent).

**4. A YAML merge key (`<<`) overrides the entry's own fields.** Severity: silent.
Repro: `base: &b {value: 1, type: number, definition: Shared text.}`, then `c:` with `<<: *b` and `definition: Own text.` → `entries$definition[2]` is `"Shared text."`. A `value: 2` written beside `<<` reads as 1.
Expected: the entry's own fields win (YAML merge semantics). Comes from the yaml package. weft reads its output without checking for `<<`, so either reject merge keys or document them.

**5. A file with several YAML documents is read only up to the second `---`.** Severity: silent.
Repro: entry `a`, a line `---`, then entry `b` → a dictionary holding only `a`, with no problem reported. Same with a leading `---`.
Expected: an error. §2: "Errors are never warnings; nothing is half-read".

**6. A read that fails still installs its units for the session, and the next good read does not list them.** Severity: silent.
Repro: a file with `a: {value: 1, type: quantity, unit: "mgx/L", definition: d}` and `b: {value: oops, type: number, definition: d}`. `read_dict()` raises the error for `b`, yet `units::as_units("mgx")` now parses. Fix `b` and read again: `print()` shows no "Units registered" line, and `attr(, "registered")` is `character(0)`.
Expected: nothing installed by a read that fails ("nothing is half-read"). D16 relies on `print()` and `registered` to show a misspelt unit such as `mgg/L`. Here the misspelling is registered and never listed.

**7. Two reads of an unchanged file are not `identical()`. On any read after the first, `registered` is empty and `print()` drops the units line.** Severity: contract/spec mismatch.
Repro: `d1 <- read_dict(fx); d2 <- read_dict(fx); identical(d1, d2)` → `FALSE`. `all.equal()` reports `Component "registered": Lengths (3, 0) differ`. `print(d2)` has no `Units registered:` line.
Expected: D3 says `identical()` works on the object. D16 says registered units are "listed by `print()`". The object depends on the session's history, so its serialised hash, which matters for 2e, does too. (`saveRDS()`/`readRDS()` is also not `identical()`, because the `labels` and `breaks` closures get new environments. That one is expected.)

**8. `str()`, `summary()`, `ls.str()`, `Map()` and `mapply()` on a dictionary fail.** Severity: crash.
Repro: `str(read_dict(fx))` → ``weft_dict_key_error: `dict[[i]]`: the key must be one string (rule 4.1.2).`` `summary(d)`, `utils::ls.str()` over an environment holding it, `Map(f, d, names(d))` and `mapply(...)` all fail the same way, as does `Filter()` (through `[`). `lapply`, `sapply`, `vapply`, `with`, `attach` and `as.environment` work.
Expected: `str()` works. It is the first thing a user calls on an object, and the RStudio environment pane relies on it. The error blames the user's `[[i]]`, which they never wrote. §2 forbids `[[` with a number for reads by key; it does not ask for these base functions to break.

**9. A whole number beyond the integer range is rejected as "not a number", and an R warning leaks.** Severity: contract/spec mismatch.
Repro: `a: {value: 3000000000, type: number, definition: d}` → `WARNING: NAs introduced by coercion: 3000000000 is out of integer range`, then ``t.yml:1: `a`: `value` must be a number, or a string that is a number literal``. `3000000000.0`, `3e9` and `"3000000000"` all read.
Expected: 3e9. §2: `number` is "a number". A volume in litres or an area in m² easily goes past 2^31.

**10. In `dict_local`, a `labels` map keyed by two YAML 1.1 booleans of the same truth value kills the render before weft runs, with no line.** Severity: crash.
Repro: front matter `weft: dict_local: a: {value: {yes: Y, on: O}, type: labels, definition: d, why: w}`. Under rmarkdown: `Duplicate map key: 'TRUE'`. Under Quarto: `Error in yaml::yaml.load(..., eval.expr = TRUE): Duplicate map key: 'TRUE'` from `parse_yaml_front_matter`. `{yes, no}` alone works.
Expected: D6 / §2 dict_local: "re-parsed with the same boolean handlers", so `yes`/`on`/`true` stay text. rmarkdown parses the front matter first, without the handlers, so in front matter D6 holds only for maps that have at most one true-word key and one false-word key. Document the limit or say that `dict_local` keys must be quoted.

**11. A duplicate key inside an entry is reported under the field's name, at the wrong line.** Severity: wrong output (location).
Repro: `a` (lines 1–5, with `definition` on line 4), then `b:` on line 6 with `definition: d` on line 9 and `definition: again` on line 10 → ``lab.yml:9: `definition`: the key is written twice``. A doubled `value:` in the second entry likewise gives `` `value` `` at the first `value:` line of that entry.
Expected: ``lab.yml:10: `b`: `definition` is written twice``. §2: "`<key>` … the line of the key's own `key:` line". `build_dict()` takes the second `<name>:` line from anywhere in the file, at any indentation.

**12. A problem's line is found by a pattern that ignores indentation, so it can point at a nested line of another entry.** Severity: wrong output (location).
Repro: `zone_lab:` written in block style with `    upper: Upper reach` on line 3, then a top-level key `upper:` on line 7 whose `value: x` is not a number → ``lab.yml:3: `upper`: …``. A top-level key named like a field (`type`, `value`, `unit`, `definition`, `decision`) gets the first entry's field line: key `type:` on line 5 was reported at line 3.
Expected: line 7 (line 5). §2: "the line of the key's own `key:` line". Match only lines at the top level's indentation.

**13. A duplicate top-level key hides every other problem in the file.** Severity: contract/spec mismatch.
Repro: entries `a`, `b` (with `value: x` under `type: number`), and `a` again → one problem, ``t.yml:9: `a`: the key is written twice``. The bad value of `b` is not listed.
Expected: D5, "all, one message". A duplicate is not a syntax error, but it is read through the parser's error, which ends the read.

**14. The 4.4.5 hint is missing from a warned check (`level = "warn"`).** Severity: contract/spec mismatch.
Repro: `claim(read_dict(fx)$core_len, . < 1, level = "warn")` outside a knit → a warning with no hint. In a knit, `last_knit()$warnings$hint` is `NA` and the "warned check(s)" report has no hint line. With `level = "fail"`, the hint appears in all four contexts: prose, chunk, `weft_str()` and outside a knit.
Expected: the hint is given whenever the check's error message matches (§2 "Arithmetic and checks"). `claim_warn()` is never passed `hints`.

**15. `%in%`, `match()`, `cut()` and `findInterval()` compare a quantity with a bare number without an error.** Severity: silent.
Repro: `claim(dict$core_len, . %in% 0.5)` passes and returns `0.5 [m]`. `match(u(0.5, m), 0.5)` → 1; `cut(u(0.5, m), c(0, 1))` → `(0,1]`.
Expected: rule 4.4.5, "Comparing … a quantity and a bare number is an error". The reason given in §13 (a check passing after a change of unit) applies here too. The units package's choice, but the rule is weft's: either a check in `claim()` refuses to strip units, or the rule's limits are documented.

**16. A failed claim on a quantity shows a truncated `deparse()` as its value.** Severity: cosmetic.
Repro: `claim(dict$core_len, . < 1)` → `(value: structure(0.5, units = structure(list(numerator = "m", denominator = characte...)`. This text is in `last_knit()$failures$detail`, in the collected report and in `rehearse()`.
Expected: `0.5 [m]` or `0.5 m`. This is the line the reader sees beside the 4.4.5 hint.

**17. Raw R warnings leak from `read_dict()` and `u()`.** Severity: cosmetic.
Repro: `unit: "m/(s"` → `Could not parse expression: 'm/(s'. Returning as a single symbolic unit()`, followed by the weft problem. `u(5, "m/(s")` does the same. A key `~:`, or a labels key `~`, → `Empty character vector used as a list name`. See also 9. On the open finding in the rulings: with units 1.0.0, `"m/(s"` and `"mL/(100 g"` are now reported as problems (rule 4.4.7) and nothing is installed for them. Only the stray warning remains.

**18. A key that YAML types (`null`, `~`, `010`) is reported misleadingly.** Severity: cosmetic.
Repro: `null:` as a key → ``t.yml: the top level must be a mapping from key to entry``, with no key and no line. `010:` → ``t.yml: `8`: a key must be a valid R name``, with no line.
Expected: name the key as written, with its line.

**19. The key `..1` is accepted.** Severity: contract/spec mismatch.
Repro: `..1: {value: 1, type: number, definition: d}` reads. `make.names("..1") == "..1"`.
Expected: §2: "a valid R symbol (… so no reserved word)". `..1` is reserved (`?Reserved`), and a static lint (4.1.2) or `tar_dict()`'s `dict_..1` will trip on it.

**20. Reading time grows quadratically with the number of entries.** Severity: cosmetic.
Repro: N entries of 4 lines each: 500 → 0.3 s, 2000 → 3.5 s, 4000 → 13.1 s. This is paid on every knit and every chapter. Causes: `locate()` scans every line for every key, and the entries table is built by `rbind()` row by row.

**21. `print()` details.** Severity: cosmetic.
Repro: one key → `1 keys`. A 300-character `string` value is printed in full, not as "a short value". After `names(d)[1] <- "zzz"` (which works; see question g), `print(d)` shows `min_samples  number  NULL`.

**22. `u()` with no `value` raises a plain R error.** Severity: cosmetic.
Repro: `u(unit = m)` → `simpleError: argument "value" is missing, with no default`.
Expected: a `weft_unit_error`, as for a missing unit.

## Questions

a. Finding 1: should `init_knit()` remove a `dict`/`dict_local` that an earlier knit assigned when this knit has neither? Should it restore a session's own `dict` after the knit? D2 accepts that the session's `dict` is replaced, but not that it is gone for good.
b. A child document's own `weft: dict_local:` is silently ignored. The child sees the parent's `dict_local`, and `dict_local$cl` → "this chapter defines no local `cl`". Should that be an error, a merge, or a documented limit?
c. Years (finding 2): which mechanism is intended — a class (D8 rejected one for `vctrs`), restoring the mark in the collapse stage, or documenting `c()`? And the reverse: arithmetic keeps the mark on values that are not years. `2024L - year` is a 10 typed as a year, and `year * 1000` prints `2014000` with no mark.
d. `breaks`: equal bounds are allowed, so `at_most: 1` followed by `below: 1` gives a band that can never be chosen, without a word. Should that be an error? Also, a bound written as a string (`below: "1"`) is rejected while `number` accepts strings (D7): should they match?
e. `registered` (finding 7): should it mean "the units this read installed" (as now) or "the units this dictionary needs that udunits lacks"? Only the second is stable across sessions and serves D16.
f. After a render that stops on a dictionary error, `last_knit()` returns the previous document's record (and its `$dict`). Is that intended?
g. `names<-`, `attr<-` and `class<-` change a dictionary without error, so `dict$zzz` works after a rename. Is rule 4.1.4 meant to reach them?
h. `u()` cannot take a unit held in a variable: `sapply(c("m", "kg"), function(x) u(1, x))` reads the unit `x`, and `Map(u, 1:2, c("m", "kg"))` reads `dots[[2L]][[1L]]`. `do.call(u, list(3, "m"))` works. Should there be a documented route, such as `units::set_units(x, un, mode = "standard")`?
i. `decision: true` is accepted as the string `"true"`, because the boolean handlers keep it text. Is that intended?
j. Finding 3: which fix? Reject integers with a leading zero and hex, or read YAML ints as decimal with an `int` handler?
k. Units installed by one project's dictionary stay installed for the next document in the session. `u(5, PSU)` then works in a project that never declared PSU, but fails in a fresh session. Is that acceptable, given D16's aim?

Probed and found sound: the checks for `date`, `string`, `labels`, `decision`, `definition`, `type` and unknown fields; several problems collected with correct lines in ordinary files, including CRLF, BOM and tab (reported as a YAML error with its line); `dict_local` lines and errors under rmarkdown and Quarto (`.qmd` named, correct line), a missing or blank `why`, `weft_dict_ambiguous`, local units, `dict_local` without `dict.yml`, and a second knit getting an empty `dict_local`; the errors from `$`, `[[`, `[` and the three assignments, near-miss suggestions, and `as.list`, `lapply`, `with`, `attach`, `saveRDS`; `u()` with an expression, a string, a vector, `NA_real_`, conversion and its errors, with no evaluation of a variable named like the unit; the 4.4.5 hint in prose, chunk, `weft_str()` and outside a knit; years under `.num`, `+ 1` and bare values; `rehearse()` and Quarto with `dict.yml` at the root and the document in a subfolder; a cached chunk (D22 as documented); a user's own `dict` assigned in a chunk; front-matter activation with `dict` used first inline; a `dict.yml` error stopping the render in draft mode too, with file and line; and stage 1 output for a document with no dictionary, which is unchanged against f23d270 (diffed: only `last_knit()` gains `$dict` and `$dict_local`).
