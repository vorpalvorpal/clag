# Review of stage 1a, reviewer A

An independent review of `R/scan.R`, `R/format.R`, `R/claim.R` and `R/config.R`
at commit `c3c115b`. Every finding below was reproduced by running it. The
result shown is what the build printed. The "rule" line says what the spec
(or `dev/design-1a.md`) requires. Where Pandoc's or knitr's behaviour decides
the question, it was checked against pandoc 3.10 (`-f markdown -t native`) or
knitr 1.51 (`knitr::knit(text = ...)`).

Shorthand: `st()` is `weft:::scan_text()`, and `af(v, cls)` is
`weft:::apply_formatters(v, cls, list(), weft:::default_config())`.

Counts: **15 wrong output, 6 wrong error, 2 crash, 5 cosmetic** (28 in all),
plus 11 places where the rule is ambiguous and 3 design notes for stage 1b.

## Findings

### Scanner

1. **An attribute block that spans lines is not seen at all.**
   `st('[a]{if="y"\n.em}')`, `st('[a]{\nif="y"}')` and the CRLF form
   `st('[a | b]{if="x"\r\n}')` all give 0 rows and no error.
   `mask_text()` leaves them unmasked. Pandoc reads each one as a `Span` with
   `if="y"`, because its attribute parser allows a newline between
   attributes. `parse_block()` stops at the end of the line (`lim`), and so
   does the 1.2.9 fallback. Hard-wrapping editors produce exactly this.
   Rule: 2.10.1 and 2.10.2 (the scanner is the single source of the
   constructs), 1.1.5. **Wrong output** (a construct is missed silently).

2. **Arms cannot tell the `#` placeholder from a literal `##`.**
   `st('[# item | ## items]{n="k"}')$arms[[1]]` gives `"# item" "# items"`.
   `split_arms()` turns `#` into `#` and `##` into `#` as well, and `###`
   becomes `##`. Feeding the second arm to the package's own
   `resolve_arm(arm, "5")` gives `"5 items"`. The author wrote a literal `#`.
   The separator positions (`seps`) are computed but dropped from the
   returned data frame, so the next stage cannot recover the arms from the
   source either. Rules: 1.5.12 and 1.5.8. **Wrong output** once 1b resolves
   spans (the contract makes the bug unavoidable).

3. **Wording classes accept a number printed with decimals.**
   `fmt_word(2.04)` gives "two" (stage i printed "2.0", `decimals = TRUE`).
   `fmt_word(1.96)` gives "two", `fmt_ord(1.96)` gives "2nd" and
   `fmt_count(3.04)` gives "three". The check in stage ii only tests
   `number != round(number)` and ignores `decimals`. Rule: 1.4.12 says a
   decimal, judged as printed, is a failure (`weft_value_error`). This is
   consistent with 1.5.9 ("1.0" is not "one") and with the 1a ruling that
   "0.0 stays 0.0" under `.no`. Note that a comment in
   `tests/testthat/test-format.R` (the 1.4.12 "whole-ness" test) says "3.0000
   is whole as printed", so the test-writer read the rule the other way. The
   orchestrator needs to rule on it. **Wrong output.**

4. **`is_whole()` uses a tolerance that scales with the number's size.**
   `fmt_num(1e10 + 0.3)` gives "10,000,000,000" and
   `fmt_num(123456789012.3)` gives "123,456,789,012", both with
   `decimals = FALSE`. At the other end, `fmt_num(1e-10)` gives "0", so
   `fmt_no(1e-10)` gives "no", and as a governor 1e-10 takes the "zero" arm.
   The tolerance is `1e-9 * max(1, |v|)`. Rule: 1.4.13 (a number that is not
   whole prints to the default digits: "10,000,000,000.3", "0.0").
   **Wrong output.**

5. **`plural()` accepts a `weft_text` that has no number.**
   `plural(fmt_and(c("a","b")), "x", "y")` gives "y", and
   `plural(fmt_strong("abc"), "x", "y")` gives "y". Rule: 1.5.11 (a string is
   a value error that says to write `length(x)`). **Wrong output.**

6. **Code spans that knitr does not evaluate are recorded as inline R.**
   `` st('a ` r x ` b') `` gives a `bare` row (CommonMark strips the padding
   spaces first). `` st('a `r\tx` b') `` gives a `bare` row too. With
   `{.num}` added, each becomes a `value` construct. knitr 1.51's pattern is
   `` `r[ #]([^`]+)\s*` ``, and `knitr::knit` leaves both as literal code.
   Rules: 1.1.8 and 1.3.1 (inline R is what the stock form evaluates).
   **Wrong output.**

7. **Inline R that holds several expressions is a construct error.**
   `` st('E `r a; b` F') `` and `` st('`r a\nb`{.num}') `` report "not a
   single R expression (rule 5.3.5)". Stock knitr evaluates both and prints
   the last value ("E 2 F"). Rule: 5.3.5 is an error only for an expression
   that does not parse. 1.1.8 says bare inline R keeps stock behaviour.
   **Wrong error.**

8. **Passing a formatted value to a number formatter formats the rounded
   number again.**
   `fmt_pct(fmt_num(0.12))` gives "10%" (the value is 12%).
   `fmt_pct(fmt_pct(0.12))` gives "1200%".
   `fmt_num(fmt_num(3.14159), digits = 3)` gives "3.100", a precision the
   value never had. Rules: 3.4.2 and 1.4.11 (the record is carried forward).
   Either the number stage should refuse a value that already has a record
   (`weft_value_error`), or it should keep the record unchanged. Printing a
   different number is not an option the rules allow. **Wrong output.**

9. **A missing value inside a list gets past the check.**
   `fmt_and(list(NA, "b"))` gives "NA and b", `fmt_and(list(Inf, 1))` gives
   "Inf and 1", and `fmt_strong(list(NULL))` gives "\*\*NULL\*\*". The cause
   is that `check_present()` returns early for any list. Rule: 1.3.4.
   **Wrong output.**

10. **A broken block that holds a renderer key reads as a bare value.**
    `` st('`r x`{.and sep="a"b"}') `` and
    `` st('`r x`{.num digits="2"x"}') `` each give one `bare` row with no
    error. The 1.2.9 fallback regex in `parse_block()` knows only
    `n|if|sign|cite`, although `WEFT_KEYS` (1.2.5) also has `digits`,
    `sigfig`, `sep`, `last` and `trunc`. Rule: 1.2.9 ("a weft key in any
    letter case followed by `=`"), 1.2.3. **Wrong output** (a construct
    error is missed).

11. **An unclosed `<!--` in the middle of a line hides the rest of the
    text.**
    `` st('a <!-- unclosed `r x`{.num}') `` gives 0 rows. Pandoc does not
    treat it as a comment: it gives `Code ("",["num"],[]) "r x"`.
    `comment_end()` returns `n` when no `-->` follows. That is right only for
    an HTML block at the start of a line. Rule: 1.9.2 (only a real comment is
    left alone). **Wrong output.**

12. **The target of an autolink inside an arm is not protected.**
    `st('[see <http://a.b/c#d> | # x]{n="k"}')$arms[[1]][1]` is
    `"see <http://a.b/c#d>"`, with a single `#` that becomes the placeholder
    (see finding 2). `st('[a <http://x.y/a|b> | c]{if="x"}')` splits into
    three arms and reports an arm-count error. Pandoc reads
    `<http://a.b/c#d>` as a `Link`. Rule: 1.5.14 (a link target).
    **Wrong output / wrong error.**

13. **A table that Pandoc does not see gives a pipe-table error.**
    `st('Heading\n---|---\n[x | y]{if="z"}')` and
    `st('para\n-|-\n[x | y]{if="z"}')` both report the 1.5.13 error. Pandoc
    parses each as a paragraph: the one-cell header does not match the
    two-cell delimiter row. `find_tables()` does not compare cell counts.
    Rule: 1.5.13. **Wrong error.**

14. **Inline R in a link target is not recorded.**
    `` st('[a](`r url`)') `` and `` st('[a](http://x.y/`r p`)') `` give
    0 rows, but knitr evaluates them (`[L](3)`). Rules: 1.1.8 and 2.10.2 (a
    bare value is a row, for the numeral rule, the ledger and the gate).
    **Wrong output** (a missed row). The `{.num}` variant is listed under
    ambiguous rules (item E).

15. **Front matter that is not at character 1 is scanned as prose.**
    `scan_file()` on `"\n---\ntitle: \"`r x`{.num}\"\n---\nbody"` gives a
    `value` row on line 3. A second YAML block in the body
    (`---\nb: "[a]{if='x'}"\n---`, after a blank line) gives a
    single-quoted-value construct error. Pandoc reads both as metadata.
    `blank_front_matter()` matches only `^---` at character 1. Rule: design
    note (front matter joins in 1c, and until then it is skipped).
    **Wrong output.**

16. **A tilde fence inside a block quote is not skipped.**
    `` st('> ~~~\n> `r x`{.num}\n> ~~~\n\n`r y`{.num}') `` gives a `value`
    row for `x`. The backtick version comes out right only by accident: the
    triple backticks pair up as a code span. Rule: 1.9.2. **Wrong output.**

17. **`digits` or `sigfig` on a value that is not a number is ignored.**
    `af("abc", character())` with `keys = list(digits = "2")` gives "abc". A
    `weft_text` input also ignores `digits`:
    `apply_formatters(fmt_num(3.14159), character(), list(digits = "3"))`
    gives "3.1". Rule: 1.4.7 (either key implies `.num`, and `.num` on a
    string is a value error). **Wrong output.**

### Configuration

18. **Bad values for several settings are accepted.**
    - `digits: 1.5` is accepted and used as 1.
    - `digits: .inf` is accepted, and `fmt_num(3.14)` then crashes with
      "invalid format '%.NA'".
    - `governor_class: .and`, `.bogus` and `num` are all accepted. With
      `.and`, `plural(1, "a site", "# sites")` gives "1 sites".

    Rules: 9.1.2/9.1.5 and 1.5.18 (the governor class is a number-stage
    class). **Wrong error** (it leads to wrong output and a crash).

19. **A badly shaped `formatters:` or front matter is ignored silently.**
    In `_weft.yml`, `formatters: 3` and `formatters: [.a1]` both give
    `list()` with no error, because `modifyList` drops unnamed elements.
    `read_config(d, front = list(1, 2))` (an unnamed `weft:` key) is also
    accepted. Rules: 1.4.8 and 9.1.1. **Wrong error.**

### Attribute blocks and messages

20. **Two ids in one block are a construct error.**
    `st('[a]{if="y" #x #z}')` reports "does not parse". Pandoc accepts it
    (the last id wins: `Span ("z", ...)`). This error is not in the list of
    5.3.1. **Wrong error** (minor: ids are not built yet).

21. **The "does not parse" message names the wrong cause.**
    `st('[a]{n = "k"}')`, `st('[a]{if=}')` and `st('[a]{# if="y"}')` all say
    "a `\"` or a `\\` inside a value ends it early". The real cause is
    spaces around `=`, an empty value, or a bare `#`. Rule: 1.2.3 (the
    message names the remedy). **Cosmetic.**

### claim()

22. **An empty check argument is not treated as "no check".**
    `` st('`r claim(k, )`') `` gives no error. At run time `claim(5, )`
    stops with a base error, 'argument "ck" is missing'. Rule: 3.1.10.
    **Wrong error.**

### Crashes

23. **A file that is not UTF-8 crashes `scan_file()`.**
    `writeBin(c(charToRaw("caf"), as.raw(0xe9), charToRaw(" `r y`{.num}")), f); weft:::scan_file(f)`
    stops with the base error "input string 1 is invalid UTF-8". The error
    has no weft class and does not name the file. **Crash.**

24. **`fmt_sci()` crashes on a denormal number.**
    `fmt_sci(5e-324)` stops with "missing value where TRUE/FALSE needed".
    **Crash** (minor).

### Cosmetic

25. **Bold applied to an empty string prints four asterisks.**
    `fmt_strong("")` gives `"****"`. Rule: 1.2.6 (an empty output emits
    nothing). **Cosmetic.**

26. **A very large ordinal prints base warnings.**
    `fmt_ord(1e20)` warns "probable complete loss of accuracy in modulus"
    twice. During a knit that warning lands in the condition log (7.4).
    **Cosmetic.**

27. **A failed claim does not quote the check as written.**
    `claim(5, . > 1e6)` reports `` check `. > 1e+06` ``, and
    `claim(5, . >= 10.50)` reports `` `. >= 10.5` ``. The cause is that
    `deparse()` rewrites the call. Rule: 3.1.4. **Cosmetic.**

28. **The scanner slows down faster than the text grows.**
    77k characters take 0.63 s, 154k take 1.7 s and 308k take 5.05 s
    (`scan_text` on repeated paragraphs, 4 constructs each). Likely causes:
    `S$rows` grows by copying, and `code_span()`/`math_end()` filter whole
    vectors on every call. The knit-time per-block scans are fine; only a
    whole-book static scan is at risk. **Cosmetic** (performance).

## Where the rule is ambiguous

A. **Rounding mode.** R's `round()` gives `fmt_num(0.05)` "0.0",
   `fmt_num(0.15)` "0.1", `fmt_num(0.25)` "0.2" but `fmt_num(2.45)` "2.5".
   `fmt_num(2.5, digits = 0)` gives "2" and `fmt_num(3.5, digits = 0)` gives
   "4" (half to even). The spec does not say which rounding to use.

B. **`.pct` or `.sci` followed by a wording class drops the unit.**
   `af(0.03, c(".pct", ".word"))` gives "three", `.pct .ord` gives "3rd", and
   `af(30, c(".sci", ".word"))` gives "thirty". 1.4.1 says stage ii acts "as
   printed by stage i", and stage i printed "3%". Should it print "three
   percent", or is this a construct error?

C. **Indented code blocks.** `` st('para\n\n    `r x`{.num}') `` gives a
   `value` row and `mask_text()` masks it. knitr evaluates inline R there and
   Pandoc renders a code block. 1.9.2 names only fenced blocks.

D. **A link that carries a weft key.** `st('[a](u){if="x"}')` gives 0 rows.
   Pandoc makes a `Link` with `if="x"`. The guard is never evaluated, and the
   2.5.3 filter checks only spans. 1.9.1 leaves links alone, but its wording
   ("a bracket whose attribute block has none of n, if...") suggests this
   bracket is not left alone.

E. **A value with a block inside a link target.**
   `` st('[a](`r u`{.num})') `` gives no row and no error. knitr evaluates
   it, and `{.num}` stays in the URL.

F. **A check that errors.** `claim(5, . > 10, stop("second"))` surfaces only
   the base error "second" (a `simpleError`), so the failed `. > 10` is never
   reported. 2.6.1 defines a failure as a check "that is not TRUE". Is an
   error a failure, and what is collected in a knit?

G. **Unknown configuration keys.** `digts: 2` is kept silently. With no lint
   for it, a misspelt setting does nothing.

H. **Other inline syntax inside an arm.** A `|` inside a shortcode
   `{{< var x|y >}}`, an inline note `^[a | b]` or a footnote label `[^n|m]`
   splits the arm. 1.5.14 does not list them. Does an inline note count as
   "prose", so that the split is correct?

I. **Project formatters in the text stage.** They run after `.strong`/`.em`
   and in the order written, so two of them depend on order. 1.4.1 fixes the
   order only for shipped classes.

J. **A text span with a formatter class.** `st('[x]{.num .strong}')` gives a
   `text` span with no error. 1.1.9 does not say whether `.num` passes
   through there.

K. **`decimal_mark` equal to `big_mark`.** Setting both to `,` is accepted.

## Design notes for stage 1b

- **Run `scan_text()` on the raw prose, before knitr evaluates inline
  code.** Run on text in which inline code has been replaced, it loses the
  value. `st("A \001W1\001{.num} B")`, ``st("A `W1`{.num} B")`` and
  `st("A 3.14159{.num} B")` all give 0 rows, with the `{.num}` left behind.
  A value nested in an arm loses its row the same way:
  `st('[a \001W1\001{.num} | b]{if="x"}')` gives one row. A placeholder put
  into an `if=` value fails to parse. So 1b must scan the source block
  first and then map offsets onto the knitted text.
- **Arms need more structure (see finding 2).** Return arm start and end
  offsets, or the separator positions, and keep `#` and `##` apart (for
  example, leave `##` unresolved, or return the positions of the
  placeholders). Without that, the resolver has to split the source a second
  time and could disagree with the scanner.
- **`apply_formatters()` for governed spans.** The record and the choice of
  arm work: `af(0, ".no")` with `choose_arm_n(.., 2)` gives "no sites". Two
  things go wrong if the resolver passes the span's classes straight in.
  1. Text classes land on the governor. `af(3, c(".word", ".strong"))`
     followed by `#` gives "\*\*three\*\* sites", where 1.5.7 wants
     "\*\*three sites\*\*".
  2. With no formatter class it falls back to `.num`, not to
     `config$governor_class` (only `plural()` substitutes that).

  A `governor = TRUE` mode, or a `stages =` argument that formats the number
  and wording stages only and applies the default class, would make 1.5.7
  and 1.5.18 hard to get wrong.
