# Stage 1h — a list that can be empty (Robin, 2026-11-12: "options 1+3, but allow vectors")

Built after stage 1g. Amends 1.3.4, 1.5 (a fourth governor key) and 1.4
(a key on a collapsed value); `PACKAGE-SCOPING.md` is amended in the commit
that builds this. Rule 1.5.11 stands: `n` never takes a count from a
length.

## The `list` key on a span

```
[No sites were | # was | # were]{list="flagged"} flagged.
```

- The governor is a vector: any atomic vector (character, factor, number,
  logical, date). The arm is chosen by its length, with the arm counts and
  roles of `n` (1.6): two arms are one/other, three are zero/one/other,
  four are zero/one/two/other. One arm is a construct error.
- `#` prints the vector collapsed as `.and` collapses it. Classes and keys
  on the span act on `#`: a collapse class (`.or`, `.pairs`), `trunc`,
  `sep`, `last`; a number or wording class and `digits`/`sigfig` format
  each element first; a text class acts on the result. A number vector
  with no number class prints each element as a bare value prints.
- **No numeric guard.** A number vector is accepted as it is (site
  numbers are a natural list). A count passed by mistake prints "3 was
  flagged", which shows on every render.
- **Empty.** A vector of length zero takes the zero arm. With no zero arm
  (two arms) it is a failed claim whose message says to add a first arm
  for the empty case (1.5.3).
- **`NULL` is not an empty list.** `NULL`, an R `list`, a data frame or
  any value that is not an atomic vector is a "no value" failure (1.3.4):
  a misspelt column must not print "No sites were flagged". An `NA`
  element is a "no value" failure.
- `#` in the zero arm is a construct error found from the source.
- An inner `n="."` inherits the length as its count.
- `claim()` in the expression works as in any governor (1.5.6).
- An id on a `list` span, and `list="."`, are construct errors.
- Under a `lang` that is not English, as `n` (1.6.4, 1.6.5).
- `arms()` lists it with `key` `"list"` and the roles of `n`;
  `rehearse()` records its choice.

## The `none` key on a value

```
Flagged sites: `r flagged`{.and none="none"}.
```

- On a value with a collapse class (`.and`, `.or`, `.pairs`, `.ul`, `.ol`,
  `.dl`): when the value is an atomic vector of length zero, the key's
  text is printed in its place (as inline text, also for a list class). A
  text class acts on it.
- Without `none`, a value of length zero is a "no value" failure as now.
- `none=""` or only spaces is a construct error. `none` on a value with no
  collapse class, on a span, or on a `cite` span is a construct error.
- `NULL` is a "no value" failure even with `none`.
- Function forms: `fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`,
  `fmt_ol()`, `fmt_dl()` gain `none = NULL`.

## Tests

One new file `tests/testthat/test-1h.R`.

## Rulings on the test-writer's report

- Inside an inner `n="."` span, `#` is the count (the length); in the
  `list` span's own arm text `#` is the collapsed vector. So
  `[none | # was | [# site | # sites]{n="."}: #]{list="v"}` prints "3
  sites: a, b and c".
- A date prints as `format()` prints it and a logical as `TRUE`/`FALSE`
  unless a class says otherwise.
- `none` on a value whose classes include no collapse class (`.num`,
  `.strong`, or none) is a construct error.
- Exact texts the test-writer guessed (`.cap`, `.word` on a vector,
  `sep`/`last`) follow what the same classes print on a value today; the
  implementer reports any that differ rather than bending the code.

## Rulings on the implementer's report

- Two test fixtures were wrong and are corrected: the `rehearse()`
  fixture never bound its parameter, and one expected text assumed
  `trunc` under `.or` drops the tail ("and N others" is what `trunc`
  prints under every collapse class, `dev/design-1b.md`).
- A number vector with no number or wording class prints each element as
  stock knitr prints it, inside a `list` span only. Accepted.
- `none` is an owned key: it is never passed through, and it is a
  construct error on a text, `if` or `cite` span. Accepted.
