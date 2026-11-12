# Review — the closing fix rounds (30d62cb, a1d468a, 247adad, baeffb1, 4cc3481, 5be6263, 5045853, da74174)

Read-only review of the diffs under `R/` and `inst/`, with the surrounding code. Every
finding below was reproduced with `devtools::load_all()` in a temporary folder unless it
says otherwise; the snippets are cut down to what shows the defect. Severity: **high**
(wrong result or failed make on ordinary input), **medium** (wrong result on plausible
input, or a spec rule broken), **low** (noise, edge input, portability).

---

## 1. (high) The dependency guard follows a copy of `dict` into a target's value

`R/targets.R:395`, `R/dict.R:765`, `R/targets.R:413-437`

`tar_dict()` marks the attached dictionary with the attribute `weft_pipeline`; a target that
returns the dictionary stores that attribute with its value, so any downstream target that
reads the stored copy is refused, although it depends on the copy correctly.

Reproduction (`tar_make(callr_function = NULL)` in a temp dir, `dict.yml` with `limit`, `other`):

```r
list(weft::tar_dict("dict.yml"),
     weft::tar_dict_deps(list(tar_target(params, dict),
                              tar_target(y, params$limit + 1))))
```

Actual: the make fails at `y` with "the target `y` reads `dict$limit`, and does not depend on
`dict_limit`" (the message also names `dict$`, which `y` never reads). Expected: `y` builds;
it depends on `params`, which depends on every `dict_<key>`. The same copy read through
`tar_read(params)` in a report knitted under `tar_make()` fails the same way. Dynamic branches
over `dict` were checked and work.

Fix: guard only the attached object, not copies. For example, keep the marker off the value
(an active binding in `weft:dict` that sets a session flag around the access), or strip
`weft_pipeline` from the values the targets in `tar_dict_deps()` return.

## 2. (high) A report whose dictionary reads the walker misses goes stale silently

`R/targets.R:559-581` (`document_children`), `R/targets.R:621-623`; spec 4.6.5, 4.6.8

The guard cannot protect report targets: the knit reads the dictionary `init_dicts()` assigns
(`R/dict.R:721`), not the guarded attached one, and `tar_quarto()` renders in another process
anyway. So every read that `report_reads()` misses is a report that does not re-run. That breaks
4.6.8's "never gives a stale number". Reads it misses:

- a `child=` option that is not a literal (`child = part`, `child = here::here(...)`);
- a Quarto include rooted at the project (`{{< include /_part.qmd >}}`), which `is_abs_path()`
  takes as a filesystem path;
- a quoted include with a space (`{{< include "my part.qmd" >}}`), cut by `[^ >]+`.

Reproduction (in-process `tar_make()`, set-up project, `tarchetypes::tar_render(report, "report.Rmd")`,
the report's setup chunk sets `part <- 'part.Rmd'` and a chunk has `child = part`, where
`part.Rmd` reads `` `r dict$limit`{.num} ``). Make, change `limit` from 3 to 7 in `dict.yml`,
and make again. Actual: `report` is `skipped` and `report.md` still says "The limit is 3." Expected:
`report` re-runs, or the make stops as 4.6.8 promises. `tar_dict_deps()` also prints
"Error in eval(x, envir = envir) : object 'part' not found" to the console while it scans.
Walker level: `report_reads("sub/doc.qmd", globalenv(), "limit")$keys` gives `character(0)` for
the `/`-rooted and the quoted includes, and `"limit"` for `../_part.qmd`.

Fix: resolve a leading `/` against the Quarto project root, and allow quoted paths in the include
regex. Make a report target whose `child=` cannot be evaluated depend on the whole dictionary
(or fail the definition, as 4.6.4 does for an unknown key). Then amend 4.6.8 to say that it covers
non-report targets only.

## 3. (medium) With an empty dictionary, any whole-dictionary read stops the make

`R/targets.R:423`

`paste0("dict_", keys)` with no keys gives `"dict_"`, which no target depends on, so `names(dict)`,
`print(dict)` and `as.list(dict)` in a target always fail when `dict.yml` has no entries yet.
4.1 allows that (an empty file is a dictionary with no keys).

Reproduction: `dict.yml` holding only a comment; `tar_target(n, length(names(dict)))` through
`tar_dict_deps()`; `tar_make(callr_function = NULL)`. Actual: "the target `n` reads the whole
dictionary, and does not depend on `dict_`". Expected: `n` builds (it is 0).

Fix: `need <- if (is.null(key)) paste0("dict_", keys)[seq_along(keys)] else paste0("dict_", key)`,
or return early when `length(keys) == 0`.

## 4. (medium) In lists and block quotes, the ledger sentence takes the next item's marker

`R/ledger.R:703-713` (regression from baeffb1)

The marker cuts sit after each block marker (`mk + ml`), and the sentence text is taken from the
unmasked block. So the sentence of an item ends with the next line's `- `, `1.` or `>`. The old
code ended a sentence at the newline before the next list item.

Reproduction: render (rmarkdown, set-up project)

```
- Rain was `r 3`{.num} mm on the day
- Flow was `r 4`{.num} ML
1. Third `r 5`{.num} here
2. Fourth item

> Quoted `r 7`{.num} here.
> Next quoted line.
```

Ledger `sentence` fields: actual `Rain was 3 mm on the day -`, `Flow was 4 ML 1.`,
`Third 5 here 2.`, `Quoted 7 here. >`. Expected: the same without the trailing marker. Because
`align_keys()` lines occurrences up by sentence, turning a bullet list into a numbered one, or
inserting an item, also changes the neighbouring entries' sentences.

Fix: for the end bound, use the start of the next marker's line (`mk - 1` back to the newline),
not `mk + ml`; or strip a trailing run of block markers from `[st, en]` before
`sentence_cut_around()`.

## 5. (medium) A sentence that ends `.^[footnote]` runs into the next sentence

`R/ledger.R:595-606` (`mask_nonprose`)

An inline footnote outside the construct is masked as letters (`Aaaa…`), so ICU sees
`mm.Aaaa… Then`. That has no boundary, so the following sentence is joined on. Pandoc's
usual style puts the footnote straight after the full stop.

Reproduction: `ledger_sentence("It was 3 mm.^[A note. With two sentences.] Then it stopped.", 8, 11)`,
and a rendered document gives the same. Actual: `It was 3 mm.^[A note. With two sentences.] Then it stopped.`
Expected: `It was 3 mm.^[A note. With two sentences.]` (or without the note). The entry's
sentence then changes whenever the next sentence is edited.

Fix: mask an inline footnote that does not hold the construct as closing brackets (`)`), as a
footnote reference `[^1]` already is, so that the boundary after it stands.

## 6. (medium) A reader's default arguments are ignored, so the read is filed under the wrong store

`R/targets.R:147-151`, `R/targets.R:159-178` (`call_wrapper`), `R/targets.R:726-746`

When a reader is called without its `store` argument, the default in its formals is dropped.
The read is recorded under the default store, so the ledger keeps an NA hash, or the hash of an
unrelated target of the same name. The same happens to a default `name`. A store held in a
local variable of the reader is evaluated at the end of the knit in `knit_global()`, where a
global of the same name, if any, is used silently.

Reproduction:

```r
env <- new.env()
eval(quote(rd <- function(name, store = "other/_targets") targets::tar_read_raw(name, store = store)), env)
w <- reads_walker(env, character()); w$add('x <- rd("fit")'); str(w$store_exprs())
```

Actual: `store: NA`, `expr: NULL`, so `chapter_reads()` uses the default store. Expected:
`store: "other/_targets"`. With `rd2 <- function(name) { s <- "other/_targets"; tar_read_raw(name, store = s) }`
the expression recorded is the symbol `s`, and it is evaluated in the global environment.

Fix: in `call_wrapper()`, fall back to `formals(f)[[w$store_param]]` (and `[[w$param]]`) when
the argument is missing. Record a store expression that names a local of the reader as
unresolved, rather than evaluating it globally.

## 7. (medium) The tidyselect reader `tar_load({{ x }})` is not seen

`R/targets.R:92-99` (`literal_names`), `R/targets.R:123-126` (`unparam`); ruling I16 (design-2i)

I16 says a reader called "with a literal name (a symbol or a string)" is a read. But
`literal_names()` takes only strings, and `unparam()` does not see through `{{ }}` (or
`!!rlang::enquo()`). The one reader form that works with a symbol at run time is therefore not
recorded.

Reproduction: with `ld <- function(x) targets::tar_load({{ x }})` in the walker's environment,
`ld(fit)` and `ld("fit")` both record no target. Controls: `rd <- function(name) tar_read_raw(name)`
gives `rd("fit")` as `fit`, but `rd(fit)` gives nothing. Expected: `fit` in each case. Without the
target's hash, `changes()` cannot report the chapter as not re-rendered when `fit` changes.

Fix: have `unparam()` unwrap `{`(`{`(x)) and `!!enquo(x)`/`!!ensym(x)`, and have `literal_names()`
take a bare symbol as its name when the reader's parameter is embraced.

## 8. (low) `ledger: false` still runs the reads: warnings about a ledger that is off, and a `tar_network()` process

`R/hooks.R:479`, `R/targets.R:684`; ruling I10

`ledger_finish()` honours `ledger: false` (`R/ledger.R:946`), but `chapter_reads()` checks only
`is_set_up()`. So a project with the ledger off still gets `weft_ledger_warning`s, still
re-sources `_targets.R` in a callr process through `upstream_targets()`, and still writes
`.weft/targets/network.rds`.

Reproduction: `_weft.yml` holding `ledger: false`, and a chunk with
`if (FALSE) targets::tar_read(fit, store = mystore)`; render. Actual: one warning, "the `store` of
the read of `fit` could not be worked out; the read is recorded under the default store (rule 7.2.2)."
No ledger is written. Expected: no ledger warnings.

Fix: return early from `chapter_reads()` when `isFALSE(s$config$ledger)`. If target conditions
should still fail the render, keep only the `target_conditions()` severity path.

## 9. (low) The "unit typed again" warning fires on ordinary words

`R/units.R:453-472`; ruling I4

The check lower-cases the symbol as well as the name (`tolower(word) %in% tolower(c(nms, shown))`),
so a symbol matches a word in another case, and a symbol that is an English word matches that word.

Reproduction (`weft_str()`):

| prose | prints | warning |
|---|---|---|
| `` `r u(3, "in")`{.num} in the first week. `` | 3 in in the first week. | "in in" |
| `` `r u(3, at)`{.num} at the site. `` | 3 at at the site. | "at at" |
| `` `r u(3, m)`{.num} M is the label. `` | 3 m M is the label. | "m M" |
| `` `r u(3, year)`{.num} Year 3. `` | 3 years Year 3. | "years Year" |

Punctuation, `**mm**` and `(mm)` after a value were checked: they correctly raise nothing.

Fix: compare the symbol case-sensitively (4.4.16), and match a name case-insensitively only when
it is lower case in the text. Consider skipping a symbol that is a common word
(`in`, `at`, `a`), or warning only before punctuation or the end of the sentence.

## 10. (low) Non-ASCII characters in R code fail `R CMD check`

`R/units.R:457`, `R/units.R:459`, `R/units.R:461` (5045853)

The regexes in `typed_unit_message()` hold a literal U+00A0 and curly quotes. The rest of the
package was moved to `\u` escapes in the same round.

Reproduction: `tools:::.check_package_ASCII_code(".")` returns `"R/units.R"`, so `R CMD check`
gives "Found the following file with non-ASCII characters … Portable packages must use only
ASCII characters in their R code" (a WARNING).

Fix: write ` `, `”`, `’` in those strings.

## 11. (low) Heading anchors differ from Pandoc's when a heading holds `<` … `>` or inline code

`R/ledger.R:333` (new in 30d62cb) and `R/ledger.R:327` (older)

`gsub("<[^<>]*>", "", x)` takes out any text between `<` and `>`, but Pandoc reads it as text
unless it is a real tag. Removing inline code differs from Pandoc too, which keeps the code's text.

Reproduction: `pandoc_id("Sites with pH < 6 and EC > 500")` gives `sites-with-ph-500`, where
Pandoc 3 gives `sites-with-ph-6-and-ec-500`. `pandoc_id("The \`lm\` fit")` gives `the-fit`, where
Pandoc gives `the-lm-fit`. The `#section` that `changes()` prints then does not resolve in the
output.

Fix: strip only tag-shaped runs (`</?[A-Za-z][^<>]*>`), as `mask_nonprose()` does, and keep the
text inside backticks.

## 12. (low) A project unit stays in the session's units database and blocks another project

`R/unit-defaults.R:292` and the registration of keys without `is` (`units_entries()`,
`ud_install_one()`), which is the code around the reviewed changes

A key that one project registers (a row without `is`) is not removed when another project's
tables are read. In the same session, a second project that defines the same key with `is:` then
fails, and a project with no such row can still use the unit.

Reproduction (`weft_str()` in three temp projects, one session):

- A has `units: {zzsite: {name: site}}`.
- B has `units: {zzsite: {name: site, is: 2 m}}`.
- E has no `units:`.

B alone prints "3 sites and 6 m". After A, B fails with "`zzsite`: is read by the units package
as a unit that is already installed". After A, E's `` `r u(3, zzsite)`{.num} `` prints "3 zzsite",
where an unknown unit is expected. (B then A is clean.) This matters to test suites and to
sessions that render more than one project.

Fix: track the tokens registered for a project's tables in `ud_state` and remove them in
`units_reset()` and before reading another project's tables, as the `is:` installs already are.

---

## Checked and found sound

- Chains of governed spans (I1): eleven spacing cases at block start, before punctuation and
  between printing and empty spans.
- Zero on a ladder (I9), including `-0`, `.word` and a held unit off the ladder.
- `.pct` on per cent (I8), and `u(NA, mm)` / `u(logical(0), mm)` (I2).
- Compounds kept as typed (I7).
- `ledger:` validation (I10).
- Duplicate `tar_dict()` detection in process, including repeated `tar_manifest()` calls in one
  session.
- `report_files()` for `tar_quarto`, `tar_quarto_rep`, `tar_render`, `tar_render_rep`.
- `child=` and `#| child:` literals.
- The guard in dynamic branches.
- Most sentence cases: abbreviations, `U.S.`, `vs.`, URLs, `$5.`, `?`/`!`, French.

---

## Rulings (orchestrator)

All twelve are accepted. Tests are titled `review closing #n:`.

1. **Fix.** Only the attached `dict` is guarded. A value a target
   returns never carries the guard's marker, so a copy stored by one
   target reads freely in another. The message names only what was
   read.
2. **Fix.** An include rooted at `/` resolves against the Quarto
   project root; a quoted include path may hold spaces. A report with a
   `child=` (or include) the scanner cannot resolve to a file depends on
   every key, and the scan prints nothing to the console. 4.6.8 is
   amended: a report is protected by the scan, and what the scan cannot
   follow makes the report depend on the whole dictionary. Alternative:
   fail the definition; refused, since a computed child path is ordinary
   knitr.
3. **Fix.** With no keys a whole-dictionary read is allowed.
4. **Fix.** A sentence ends before the next block marker.
5. **Fix.** A boundary after `.^[note]` stands; the note stays with the
   sentence before it.
6. **Fix.** A reader's default `store` and `name` are used when the
   call omits them. A store that names a local of the reader is
   unresolved: default store and the one warning of 7.2.2.
7. **Fix.** `{{ x }}`, `!!enquo(x)` and `!!ensym(x)` are seen through,
   and a bare symbol at the call is the name for such a reader. A
   reader that passes its argument plainly to `tar_read_raw()` still
   needs a string.
8. **Fix.** With `ledger: false` no reads are collected: no ledger
   warnings, no network cache, no background process. Upstream
   conditions are then not looked for either; that is the cost of
   turning the ledger off, and 7.1.3 says so.
9. **Fix.** A symbol is compared as typed. A name is compared in lower
   case and as typed. No warning when the symbol is one of `a`, `am`,
   `as`, `at`, `in`. Alternative: warn only before punctuation; refused,
   since "5 mm mm of rain" is the case the trial found.
10. **Fix.** ASCII only in `R/`.
11. **Fix.** Only tag-shaped runs are stripped, and the text of inline
    code is kept.
12. **Fix.** A token a project registers is removed when the tables of
    another project are read and in `units_reset()`.
