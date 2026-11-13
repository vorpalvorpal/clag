# Code review A: the rendering core

Scope: `R/scan.R`, `R/scan-contexts.R`, `R/resolve.R`, `R/format.R`, `R/hooks.R`,
`R/claim.R`, `R/arms.R`, `R/phrases.R`, `R/conditions.R`, `R/position.R`,
`R/collect.R`, `R/state.R`, `R/decisions.R`, `R/rehearse.R`, `R/captions.R`,
`R/cite.R`, `R/year.R`, `R/weft-str.R`, `inst/quarto/` (there is no
`inst/rmarkdown/`). Read in full on `main` at `e8c1609`.

Overall: the scanner is in good shape. 4,000 random token strings through
`scan_text()` and `mask_text()`, and 1,500 random documents (front matter,
chunk headers, `#|` captions, quoted chunks, `weft_str()` calls) through
`scan_file()`, raised no error. The bugs found are at the edges: number
printing past double precision, locale and number-mark assumptions, and places
where two code paths that should agree do not (`arms()` against the knit, the R
side against the Quarto scripts). The structural debt is concentrated in two
very long functions and in helpers written several times over.

Every bug and robustness item below was reproduced with the script named in
it, under
`/private/tmp/claude-501/-Users-rjs-dev-clag/329c9209-b43a-4fb0-b9e7-58be3c9db721/scratchpad/rc-a/`.

## Proposals, most worth doing first

### 1. `digits` and `sigfig` past double precision print a wrong number

- Kind: bug
- Where: `R/format.R` `print_one()` 123-146, `key_number()` 148-157.
- What is wrong: `print_one()` formats with `sprintf("%.<nd>f")`, which prints
  the binary value's noise once more than about 16 significant digits are
  asked for. `key_number()` accepts any whole number.
  Reproduction (`t1.R` and an inline run):
  `fmt_num(0.1, sigfig = 25)` is `"0.0999999999999999916733273"` (a wrong
  value, not just extra digits); `fmt_num(0.1, sigfig = 17)` is
  `"0.10000000000000001"`; `fmt_num(123.456, digits = 15)` is
  `"123.456000000000003"`. `fmt_num(1, digits = 9000)` stops with a plain
  `simpleError` ("required resulting string length ... is greater than
  maximal 8192"), which a value construct reports as kind "no value",
  "error evaluating ...".
- Change: in `print_one()`, after `sprintf()`, replace every digit after the
  15th significant digit with `0` (count from the first non-zero digit,
  skipping the decimal point), so the string never shows noise. In
  `key_number()`, give `digits` and `sigfig` an upper bound (say 15 for
  `sigfig`, 20 for `digits`) and raise the existing `construct_error()` with
  the limit in the message, so the huge case is a construct error at the
  construct and not an R error.
- Risk: numbers printed with large `digits` change from noise to zeros; no
  realistic document relies on the noise. Guarded by `test-format.R`,
  `test-1i.R`, `test-number-forms.R`, `test-1f.R`.
- Size: S

### 2. `.a` chooses "a" before "18,5" when the decimal mark is a comma

- Kind: bug
- Where: `R/format.R` `vowel_sound()` 367-394, `add_article()` 396-401, called
  from `text_stage()` 634.
- What is wrong: `vowel_sound()` reads the leading digits as
  `^[0-9][0-9,]*` and deletes every comma, assuming the comma is the
  thousands mark. With `decimal_mark: ","` (allowed for an English document;
  config only requires the two marks to differ) the decimal comma is deleted
  and the number is read as a larger integer.
  Reproduction (`t1.R`): with `decimal_mark = ","`, `big_mark = "."`,
  `apply_formatters(18.5, c(".num", ".a"), ...)` is `"a 18,5"` and 11.25 gives
  `"a 11,25"`; both should be "an". `vowel_sound("18,5")` is `FALSE`.
- Change: pass `cfg` (or its two marks) from `text_stage()` through
  `add_article()` into `vowel_sound()`. Read the leading run of digits and
  `big_mark` characters only, stop at `decimal_mark`, and delete `big_mark`
  (not `,`) before counting the leading group. Keep the existing behaviour
  when the marks are the defaults.
- Risk: low; the default marks give the same results. Guarded by
  `test-text-classes.R`, `test-units-print.R`, `test-review-d.R`; add a case
  with a decimal comma.
- Size: S

### 3. `arms()` scans a document differently from the knit

- Kind: bug
- Where: `R/arms.R` `arms_one()` 80-150 (line 81 `scan_file(path)`, line 94
  the language); `R/scan-contexts.R` `scan_document()` 740-758;
  compare `R/position.R` `new_file_state()` 136-145.
- What is wrong: three divergences, all reproduced.
  (a) A prose back-reference to an id defined in a caption is reported as an
  error by `arms()`, while the knit accepts it (`new_file_state()` passes
  `known = cap_ids` to `scan_text()`; `scan_document()` does not).
  `t3.R`: a `#| fig-cap:` with `[one site | # sites]{n="k" #nk}` and a later
  `[a site | # sites]{n="#nk"}` gives the `arms()` error "The id `#nk` is not
  defined in this document (rule 1.7.10)."
  (b) `arms()` calls `scan_file()` with no configuration, so a project's
  registered classes are unknown. `t9.R`: with `.compact` registered at stage
  `number`, `[a site | # sites]{n="x" .num .compact}` gives no error from
  `arms()`; `scan_file()` with the configuration reports "Two classes from one
  group".
  (c) The language comes from the front matter only, while the knit uses
  `document_lang()` (Quarto's merged metadata). `t3.R`: with
  `QUARTO_EXECUTE_INFO` naming `lang: de`, `document_lang()` is `"de"` but
  `arms()` lists the two-arm `n` span with no error.
- Change: move lines 136-145 of `new_file_state()` (caption ids, and
  `lenient` when the file has `child=`) into a helper that `scan_document()`
  calls, so both paths judge ids the same way. In `arms_one()`, read the
  configuration with `read_config(find_project_root(path), front$weft, doc =
  path)` and pass it to `scan_file()`, and take the language from
  `document_lang(front, path)`. `lint-source.R` 937 and `targets.R` 730 also
  call `scan_document()` and gain (a) for free.
- Risk: `arms()` can now stop on a broken `_weft.yml`, as a knit does. Guarded
  by `test-arms.R`, `test-rehearse.R`, `test-ids.R`, `test-1h.R`,
  `test-scan-contexts.R`.
- Size: S

### 4. The draft setting is read three different ways

- Kind: bug
- Where: `R/config.R` 162 (cross-area); `inst/quarto/weft-check.lua`
  `truthy()` 178-182 and `draft_mode()` 217-228;
  `inst/quarto/weft-post-render.R` 214-219.
- What is wrong: R accepts `WEFT_DRAFT` of `1` or `true` only, and reads
  `draft:` through yaml, where `on` and `yes` are `TRUE` (`t1.R`:
  `yaml.load("draft: on")$draft` is `TRUE`). The Lua filter accepts
  `1`, `true`, `yes`, `on` for both. The post-render script accepts `1`,
  `true`, `yes`, `on` for the variable but only `true`, `yes`, `1` in
  `_weft.yml`. So `draft: on` makes the knit and the filter run in draft mode
  and the post-render script then fail the render; `WEFT_DRAFT=yes` makes the
  knit stop on its failures while the filter and the post-render script treat
  the run as draft.
- Change: settle one rule: the variable and the `_weft.yml` line are true when
  the value, lower-cased and unquoted, is one of `1`, `true`, `yes`, `on`.
  Apply it in `config.R` 162, in the post-render script's `_weft.yml` branch,
  and leave the Lua as it is (it already follows it). State the rule once in
  the spec next to 9.4.3 so the three copies have one source.
- Risk: none beyond a document that relied on `WEFT_DRAFT=yes` failing.
  Guarded by `test-1f.R`, `test-1g.R`, `test-1i.R`, `test-filter-direct.R`,
  `test-quarto-render.R`.
- Size: S

### 5. `.date` prints the weekday in the session's language

- Kind: bug
- Where: `R/format.R` `format_dates()` 312-322.
- What is wrong: the comment says the result does not depend on the locale,
  and `%B`, `%b`, `%-d`, `%-m` are expanded by hand, but `%A`, `%a` and `%p`
  are left to `format()`. Reproduction (`t1.R`): under
  `LC_TIME = fr_FR.UTF-8`, `format_dates(as.Date("2024-03-05"), "%A %-d %B %Y")`
  is `"mardi 5 March 2024"`.
- Change: add an `EN_WEEKDAYS` constant and expand `%A` and `%a` from
  `lt$wday` the same way the months are expanded, and `%p` from `lt$hour`
  (`AM`/`PM`). Expand `%%` first into a placeholder and restore it last, so a
  literal `%%B` is not rewritten.
- Risk: low. Guarded by `test-number-forms.R` and `helper-1b.R` cases on
  `date_format`; add a weekday case run under a non-English `LC_TIME`.
- Size: S

### 6. The post-render report turns characters outside the BMP into "NANA"

- Kind: bug
- Where: `inst/quarto/weft-post-render.R` `unescape()` 30-43.
- What is wrong: the knit's `json_string()` (`R/collect.R` 5-23) and the
  filter's `json_str()` write a character above U+FFFF as a surrogate pair,
  as JSON requires. `unescape()` decodes each `\uXXXX` on its own, and
  `intToUtf8()` of a lone surrogate is `NA`. Reproduction (`t1.R`):
  `json_string("x \U0001D465")` is `"x 𝑥"`, which `unescape()`
  turns into `"x NANA"`. A failure whose expression or text holds a math
  letter or an emoji is printed wrongly in the one report a Quarto render
  shows.
- Change: in `unescape()`, match a high-surrogate escape followed by a
  low-surrogate escape as one token
  (`\\\\u[dD][89abAB][0-9a-fA-F]{2}\\\\u[dD][c-fC-F][0-9a-fA-F]{2}`) before the
  single escapes, and decode it with
  `0x10000 + (hi - 0xD800) * 1024 + (lo - 0xDC00)`. Keep it plain base R.
- Risk: none. Guarded by `test-quarto-render.R`, `test-review-c.R`,
  `test-trial-bugs.R`; add a failure with an astral character.
- Size: S

### 7. Three source-file readers with different rules

- Kind: robustness
- Where: `R/scan.R` `scan_file()` 1383-1397; `R/position.R`
  `read_view_lines()` 16-28 (used by the knit, `hooks.R`
  `front_matter_lines()` 325, `targets.R` 721); `R/lint-source.R`
  `read_raw_text()` 78-86 (cross-area).
- What is wrong: each strips the BOM and CRLF, but only `read_view_lines()`
  turns a lone CR into a line break, only `scan_file()` and `read_raw_text()`
  check UTF-8, and only `read_raw_text()` handles a NUL byte. Reproduction
  (`t5.R`): a file with CR line endings puts its span on line 1 for `arms()`
  and on line 3 for the knit; a file with a NUL byte makes `arms()` stop with
  the bare R error "embedded nul in string" and no file name.
- Change: one reader, say `read_source_text(path)` in `position.R`: raw
  bytes, BOM off, NUL refused, UTF-8 checked, CRLF and then lone CR to LF; on
  a NUL or invalid UTF-8 it raises `weft_encoding_error` naming the file (the
  message `scan_file()` already uses). `read_view_lines()` splits its result;
  `scan_file()` and `read_raw_text()` call it (the lint can catch the
  condition where it wants `NULL`).
- Risk: a CR-only file changes line numbers in `arms()` and the lint (they
  become the knit's). Guarded by `test-scan.R`, `test-positions.R`,
  `test-lint-source.R`, `test-arms.R`.
- Size: S

### 8. A failed file scan in the knit silently turns off its checks

- Kind: robustness
- Where: `R/position.R` `new_file_state()` 136-138 and 143-145,
  `current_file_state()` 294; also 182, 317 and `R/state.R` 91.
- What is wrong: the knit's whole-file scan (expected constructs for the
  end-of-document check of 2.5.2, the id errors of 1.7.10, the pre-check of
  inline code that does not parse) runs inside
  `tryCatch(..., error = function(e) NULL)`, and so does building the file
  state. Any error there drops those checks with no message. Reproduction
  (`t2.R`): a `.Rmd` with one Latin-1 byte: `new_file_state()` errors
  ("input string 1 is invalid UTF-8"), the knit ends "ok", the output keeps
  `[a site | # sites]{n="x"}` and an unevaluated `claim(x, . > 5)` raw, and
  `last_knit()$failures` is empty. Only knitr's own encoding warning
  remains.
- Change: with the reader of item 7, an encoding problem becomes a
  `weft_encoding_error` that stops the knit naming the file. For other errors,
  replace the `NULL` handlers in `new_file_state()` with one handler that
  calls `ledger_warn()` (or `message()`) with "weft: <file> could not be
  scanned: <message>; the end-of-document check is off for it", so the loss
  is visible. Keep the `NULL` handlers in `current_file_name()` and
  `unlabelled_chunk_line()`, which only lose a position.
- Risk: a document that knitted with silently degraded checks now stops or
  warns. Guarded by `test-positions.R`, `test-failures.R`,
  `test-backstops-rmd.R`.
- Size: S

### 9. An unreadable bibliography file is reported as missing keys

- Kind: message
- Where: `R/cite.R` `read_bib_keys()` 52-82, `bibliography_keys()` 122-149;
  `R/resolve.R` `render_cite()` 1076-1095.
- What is wrong: a CSL JSON or YAML file that does not parse yields no keys
  and is not recorded anywhere, so every `cite` span fails with "the key
  `smith2020` is not in the bibliography (rule 1.8.5)", which sends the author
  to the wrong place. Reproduction (`t6.R`): a `refs.json` or `refs.yaml`
  with a syntax error gives zero keys and an empty `s$bib_missing`.
- Change: have `read_bib_keys()` return the parse error as an attribute (or
  `NULL` for "unreadable"), collect those files in `s$bib_unreadable` in
  `bibliography_keys()`, and add "; the bibliography file `refs.yaml` could
  not be read (<first line of the error>)" to the detail in `render_cite()`,
  as `s$bib_missing` is added now.
- Risk: message text only. Guarded by `test-cite.R`, `test-review-3.R`.
- Size: S

### 10. A stamp that cannot be written is dropped silently

- Kind: robustness
- Where: `R/collect.R` `record_knit()` 199-205; `write_draft_failures()`
  225-228.
- What is wrong: the stamp write is wrapped in
  `tryCatch(..., error = function(e) FALSE, warning = function(w) FALSE)`,
  its result `ok` is never used, and nothing is said. Without the stamp the
  post-render script cannot tell an executed document from one served from
  freeze (2.9.2, 2.9.4). Reproduction (`t8.R`): with `.weft/stamps` made
  read-only, `record_knit()` returns `FALSE`, writes nothing, and emits no
  message or warning. The draft JSON file is swallowed the same way.
- Change: drop `ok`; in both handlers emit one line through `ledger_warn()`:
  "weft: the stamp <path> could not be written: <message> (rule 2.9.2)." and
  the same for the draft file (9.4.2). Do not stop the knit.
- Risk: none. Guarded by `test-verify-freeze.R`, `test-collected.R`,
  `test-book.R`.
- Size: S

### 11. The static class and key checks are written twice, worded differently

- Kind: duplication
- Where: `R/scan.R` `block_errors()` 727-737 (two classes from one group),
  744-747 (`.usym` with a spelling class), 753-755 (`digits` with `sigfig`),
  770-773 (`digits` on `.p`/`.date`); `R/format.R` `apply_formatters()`
  589-618, the same four checks.
- What is wrong: the same rules are checked by the scanner from the source
  and by `apply_formatters()` at run time, with different text, so the same
  mistake reads differently by route: "`digits` with `sigfig` is an error
  (rule 1.4.7)." against "`digits` and `sigfig` together are an error (rule
  1.4.7)."; "Two classes from one group in one block: ..." against "Two
  classes from one group (number) in one construct: ...". The `.p`/`.date`
  message cites a rule in one place and none in the other.
- Change: write one function in `format.R`,
  `class_key_errors(classes, key_names, reg)`, returning the messages for
  these four rules in one wording. `block_errors()` appends its result;
  `apply_formatters()` calls `construct_error()` on its first element.
- Risk: message text changes; snapshot-like `expect_error(regexp =)` tests
  may need their pattern updated. Guarded by `test-scan.R`, `test-format.R`,
  `test-text-classes.R`, `test-unit-forms.R`.
- Size: M

### 12. The registry stage filter and the text-class list are repeated

- Kind: duplication
- Where: the filter "classes registered at stage X":
  `R/scan.R` 704, 741-743, 762, 790, 800; `R/resolve.R` 505, 953, 955-956;
  `R/format.R` 486 (`proj()`), 573-575. The literal
  `c(".a", ".cap", ".em", ".strong")` in place of `TEXT_CLASSES`:
  `R/format.R` 1024, `R/resolve.R` 504, 952, `R/scan.R` 1164.
- What is wrong: ten copies of one `vapply` over the registry, written three
  ways (`r[["stage"]]`, `(reg[[k]] %||% list())[["stage"]]`,
  `reg[[k]][["stage"]] %||% "number"`), and four copies of a constant that
  exists. Config fills in `stage` (`config.R` 303), so the `%||%` defaults
  are dead.
- Change: add `registered_classes(reg, stage)` beside `class_group()` in
  `format.R`, and `text_classes(reg)` = `c(TEXT_CLASSES,
  registered_classes(reg, "text"))`. Replace every copy. Make a choice
  explicit at `scan.R` 1164, which decides whether a bracket is a text span
  from the shipped four only: rule 1.1.9 says "a text class"; whether a
  registered text-stage class makes a text span should be decided and
  written there, not left implicit.
- Risk: low if 1164 keeps its present meaning. Guarded by
  `test-text-classes.R`, `test-scan.R`, `test-collapse.R`, `test-config.R`.
- Size: S

### 13. The English-language test and the Quarto metadata lookup are repeated

- Kind: duplication
- Where: `lang_is_english()` exists in `R/unit-names.R` 8-11; the same test
  is written again in `R/resolve.R` 463-466 (`non_english()`), `R/phrases.R`
  6-15 (`check_english()`), `R/arms.R` 94-95. The "needs the plural rules of"
  message is written in `R/resolve.R` 478-480 and again in `R/arms.R`
  101-103. `R/hooks.R` `document_lang()` 365-386 and `R/cite.R`
  `quarto_metadata()` 102-116 both read `QUARTO_EXECUTE_INFO` and fall back to
  `quarto::quarto_inspect()`.
- Change: call `lang_is_english()` in the three places. Put the plural-rules
  message in one function used by `lang_check()` and `arms_one()`. Build
  `document_lang()` on `quarto_metadata()` (keeping its fallback to
  `x$config$lang`) and keep the metadata on the state so a knit reads it
  once.
- Risk: low. Guarded by `test-phrases.R`, `test-arms.R`, `test-cite.R`,
  `test-unit-names.R`.
- Size: S

### 14. `claim()` builds its per-check lines three times, and they have drifted

- Kind: duplication
- Where: `R/claim.R` `claim_fail()` 187-194 and 208-216, `claim_warn()`
  252-259.
- What is wrong: three nested `ifelse()` blocks format "raised an error",
  "returned N values" and "was FALSE/failed". They have drifted: the
  failing form tells the author "write all(...) to require every element",
  the warned form of the same check does not.
- Change: one helper `check_lines(record, style = c("detail", "report"))`
  returning the line for each check, with the `all()` advice in both styles,
  and the hint appended in one place.
- Risk: message text. Guarded by `test-claim.R`, `test-1f.R`,
  `test-review-2a.R`.
- Size: S

### 15. Two copies of the `.range` collapse and of the unit affix

- Kind: duplication
- Where: `R/format.R` `apply_formatters()` 898-911 and 928-937 (the
  `.range` branch for a governor and for a value); `suffix_of()` 860-871 and
  `prefix_of()` 875-883 against `glue_vec()` 1329-1342.
- What is wrong: the `.range` code is the same 10 lines twice; `glue_vec()`
  rebuilds the unit's prefix and suffix text by hand with the same rules
  (`UNIT_SEP`, name or symbol, `unit_space()`).
- Change: lift `suffix_of()`/`prefix_of()` out of `apply_formatters()` into a
  top-level `unit_affix(un, form, plural, before, word, cfg, lang)` (without
  the memo, or with the memo passed in), use it in `glue_vec()`. Make the
  `.range` branch a local function `range_text()` returning text, suffix and
  forms, called from both places.
- Risk: unit printing is heavily tested. Guarded by `test-collapse.R`,
  `test-unit-before.R`, `test-units-print.R`, `test-unit-forms.R`,
  `test-format.R`.
- Size: S

### 16. Two tokenisers for arm text

- Kind: duplication
- Where: `R/scan.R` `split_arms()` 453-492 and `arm_template_range()`
  545-606.
- What is wrong: both walk a range of the scan, read `\|`, `\#`, `|`, `#` and
  skip atoms, each with its own `push()` closure; `arm_template_range()` adds
  only the item sentinels and the verbatim walk through an atom that holds an
  item. A change to the escape rules of 1.5.12 has to be made twice.
- Change: one `arm_tokens(S, a, b, items = NULL)` returning the four token
  vectors; `split_arms()` is `assemble_arms(arm_tokens(S, b1, b2))` and
  `arm_template_range()` is the same with `items`, keeping only the
  templates.
- Risk: arm splitting is central. Guarded by `test-scan.R`, `test-1g.R`,
  `test-1h.R`, `test-sign.R`, `test-syntax-fixtures.R`.
- Size: M

### 17. Small dead code and unused arguments

- Kind: dead code
- Where and what:
  - `R/scan-contexts.R` 432-435 `parse_col_chars()` is the identity (the
    comment says so); called at 675 and `R/lint-source.R` 243. Delete it and
    use the column.
  - `R/scan-contexts.R` 467-468 `scan_chunk_captions()` takes `optinfo`, never
    used, and takes `label`, `hdr`, `optblk` that are fields of `ch`; the only
    call (730-731) passes `ch$label, ch$hdr, ch$optblk, ch$oi`. Reduce the
    signature to `(lines, ch, doc_exec, file, config, dq)`.
  - `R/scan-contexts.R` 292 `min(j, n + 1L) - 0L`: `j` is never above
    `n + 1L`; write `close = j`.
  - `R/arms.R` 13-16 `if (is.null(r)) NULL else r` returns `r` either way.
  - `R/scan.R` 20: after `paste(collapse =)` the text always has length one
    and is never `NA`; the test is dead.
  - `R/decisions.R` 127 `resolved[num & is.na(resolved) | num & !resolved]`
    is `resolved[num]`.
- Risk: none. Guarded by `test-scan-contexts.R`, `test-lint-source.R`,
  `test-arms.R`, `test-decisions.R`.
- Size: S

### 18. Fences and metadata blocks are found by five different routines

- Kind: structure
- Where: `R/scan.R` `find_fences()` 60-115; `R/scan-contexts.R`
  `metadata_blocks()` 23-62 (its own fence skip), `find_chunks()` 266-301,
  `doc_execute()` 161-172; `R/hooks.R` `front_matter_lines()` 323-330;
  `R/lint-source.R` `fence_blocks()` (cross-area).
- What is wrong: each has its own idea of a fence. `find_fences()` ends a
  fence opened in a block quote at the end of the quote; the others run it to
  the end of the file. Reproduction (`t4.R`): a `> ``` ` that is never closed,
  then a `---` metadata block holding `abstract: |` with a span: the span is
  scanned as context `prose`, and `metadata_blocks()` finds no block.
  `front_matter_lines()` and `metadata_blocks()` also disagree on what opens
  a first block. The cases are rare; the cost is that a fix to one is not a
  fix to the others.
- Change: make `find_fences()` work on lines and return a data frame of
  `open`, `close`, `quoted`, `info`; build `metadata_blocks()`,
  `find_chunks()` and the lint's `fence_blocks()` on it; build
  `front_matter_lines()` on `metadata_blocks()` (first block, opening on
  line 1). The pre-render script stays separate (plain base R).
- Risk: medium; fence handling touches every scan. Guarded by `test-scan.R`,
  `test-scan-contexts.R`, `test-front-matter.R`, `test-captions.R`,
  `test-lint-pandoc.R`, `test-parity.R`.
- Size: M

### 19. Break up `resolve_markup()` and `apply_formatters()`

- Kind: structure
- Where: `R/resolve.R` `resolve_markup()` 249-1263 (about 1,000 lines, some 40
  closures sharing `R`, `L_raw`, `L_rel`, `L_fail`, `gov`, `picked`, `ents`,
  `bare_aux`, `cur_top`, `top_pos` through `<<-`); `R/format.R`
  `apply_formatters()` 472-1030 (about 560 lines).
- What is wrong: neither function can be tested in parts, and the shared
  mutable state makes the order of calls matter in ways that are hard to see
  (`picked` is set by `pick_note()` and cleared in `register_id()`;
  `bare_aux` is set by `render_bare()` and read by `make_entry()`).
  `render_n()`, `render_sign()` and `render_list()` repeat the same preamble
  (`split_classes`, `lang_check`, the label built from the first arm, which is
  written four times as `sprintf("\"%s\"", gsub("[ \t\r\n]+", " ", arms[1L]))`).
- Change: do it in steps, after items 11, 12 and 15. (1) Hoist the closures
  that need no mutable state to top-level functions taking what they read:
  `starts_sentence()`, `source_label()`, `passthrough()`, `split_classes()`,
  `lang_check()`, `has_own_format()`. (2) Hold the per-block state in one
  environment `rv` created at the top of `resolve_markup()` and passed to the
  render functions, so every write is `rv$x <-` and visible. (3) Give the
  three governed renderers one `governed_preamble(rv, k)`. In
  `apply_formatters()`, move the unit-form judgement (`judge_unit()` and the
  `forms` computation, 662-708 and 837-853) and stage iii (917-1004) into
  functions of their own.
- Risk: high; do it behind the full suite. Guarded by most of the suite,
  notably `test-1g.R`, `test-1h.R`, `test-ids.R`, `test-ledger.R`,
  `test-ledger-sentence.R`, `test-sign.R`, `test-collapse.R`,
  `test-weft-str.R`, `test-captions.R`.
- Size: L

## Left alone on purpose

- The hand-written character scanner in `scan.R`. It is long but held up to
  4,000 random strings and 1,500 random documents with no error; a regex or
  parser-package rewrite would lose the exact Pandoc corner cases it encodes.
- `claim()`'s own check of `level` (`claim.R` 37-41) instead of
  `match.arg()`: `match.arg()` would accept `level = "w"` by partial
  matching, which rule 3.1.11 is careful about.
- `resolve_text()` and `resolve_string()` test for `"]{"` as well as `"["`
  before scanning: a span split by a blank line arrives as a block with a
  stray `]{...}` and must still be scanned to be reported.
- The post-render script's report (`weft-post-render.R` 158-208) repeats
  `format_report()` in `state.R`, and the Lua filter repeats the JSON writer
  and the construct patterns: both must run where weft is not installed
  (9.2.8). Keep them; when one layout changes, change the other.
- `json_string()` is hand-written ASCII JSON and JSON is read back with
  `yaml`: jsonlite is not an import.
- `finish_stock()` (`resolve.R` 131-137) discards the result of its
  `tryCatch(as.character(res))`: that call is only a check that the value can
  be coerced; knitr's inline hook does the coercion.
- `weft_env$bare_aux` as a side channel between `stock_bare_text()` and
  `run_inline()`: it is reset before and after every use.
- `knit_nested()` walking `sys.function()` frames, and `state_input()`
  reading `original_input` from rmarkdown's `render()` frame: there is no
  exported way to learn either.
- `resolve_arm()` in `format.R` is a separate reader of arm escapes from the
  scanner's: `plural()` gets arms as separate strings, where `\|` is never a
  separator, so the two inputs differ.
- State between knits: checked that a knit stopped by a chunk error or by
  `weft_failures` leaves no active state, so `claim()`, `note_zero()` and
  `weft_str()` outside a knit warn and stop as documented afterwards.
- `inline_function_names()` leaves out `of_n()`, `about()`, `ci()`, `pm()`
  and `clamp()`: that is the list rule 2.1.8 gives.
- `trim_ws()` is the same as base `trimws()`; replacing it is churn.

## Cross-area notes

- `R/config.R` 162 reads `WEFT_DRAFT` as `1`/`true` only (item 4).
- `R/lint-source.R`: a third file reader (`read_raw_text()`, item 7), a sixth
  fence finder (`fence_blocks()`, item 18), and a fourth way of finding the
  document's language (front matter, then `_quarto.yml`, 925-935; item 13).
  Its `scan_document()` call (937) has the caption-id false error of item 3.
- `R/targets.R` 730 calls `scan_document(..., config = NULL)` inside a
  `tryCatch`: no project classes, and errors hidden.
- `R/decisions.R` 94-105 reads `_weft.yml` with `yaml::read_yaml()` rather
  than through `read_config()`, so its error for a broken file differs from
  every other path's.
- Rule 1.1.9 does not say whether a registered text-stage class makes a
  bracket a text span; the code says no (`scan.R` 1164, item 12). Worth a
  line in the spec either way.
