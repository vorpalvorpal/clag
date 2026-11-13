# The R route and the Lua route on one real chapter

Analysis only, 14 Nov 2026, on the trial copies of the small chapter (see `hw-trial.md`): the
unconverted copy and the R-route conversion. The Lua route was read from the named-values article,
spec 1.12, 2.13, 3.8, 3.9 and 5.12, `lua-parity.md` (A built, B not built, B1 and B2 declined) and
`weft.lua`. Every value was classified by reading; the scanner gave the first counts. This note
names no data values, people, places or manuscript text.

## Inventory: 225 computed things

**153 inline values in prose** (the scanner sees 152: one sits where its result becomes part of a
code span, so the gate and lints never see it). By what each needs:

| Needs | n | Lua today a / b / c |
|---|---:|---|
| count or plain number | 57 | 18 / 39 / 0 |
| number with fixed decimals | 27 | 3 / 24 / 0 |
| interval end written as its own value | 22 | 0 / 22 / 0 |
| percent | 15 | 3 / 12 / 0 |
| count word (small counts spelled) | 7 | 4 / 3 / 0 |
| signed estimate | 7 | 0 / 7 / 0 |
| interval built by a project helper (estimate and CI in one call) | 5 | 0 / 5 / 0 |
| year (min or max of a column) | 4 | 0 / 4 / 0 |
| percent change from a log-scale estimate | 3 | 0 / 3 / 0 |
| wording chosen in code by if/else, printed as a string | 3 | 3 / 0 / 0 |
| list joined in prose, with code formatting | 1 | 0 / 0 / 1 |
| signed list | 1 | 0 / 0 / 1 |
| value inside a code span | 1 | 0 / 0 / 1 |

Across them: 16 intervals, 7 signed estimates, no p-values, no units objects (units are typed),
no dictionary reads, no cross-chapter values (all come from the chapter's own chunks reading about
20 store targets), 1 wording guard (a `stopifnot` pinning "exactly one").

**72 pieces outside running prose, in 7 places:** a figure caption built by `sprintf()` in `!expr`
(12 pieces, with two is/are and a conditional sentence), the same figure's alt text (13), a plot
subtitle (2), a computed table caption (7), 10 helper-formatted table columns, a verdict table
whose cells are sentences built with `paste0()` (27), and one question section printed `asis`
from YAML (20 typed figures pinned by the project's own checks).

## The split, Lua route today

(a) the prose names an existing variable; (b) the value is an expression and must first be bound
to a name in code; (c) not expressible on the filter; (d) not a prose value.

| Class | Prose (153) | Overall (225) | Code the author adds |
|---|---:|---:|---|
| (a) | 31 (20.3%) | 13.8% | none under knitr (27 names, published automatically); one `put` argument per name elsewhere |
| (b) | 119 (77.8%) | 52.9% | 102 distinct expressions, 112 names (a helper interval becomes three): about 112 lines |
| (c) | 3 (2.0%) | 1.3% | plus sign on list elements; markdown in a published string; a value in a code span |
| (d) | - | 72 (32.0%) | 47 reachable by names once bound (two captions, verdict cells, the asis section); 25 not (alt text is an attribute, plot text, table columns) |

Every (a) and (b) value maps onto filter grammar that exists: `.num` with `digits`, `.pct`,
`.count` with the document's `count_threshold`, `.val` for code-made strings, a `sign` span with
`#` arms for signed estimates, two names for an interval, and a guard
`[...]{if="lo <= est, est <= hi"}` for the check `ci()` makes.

What (b) consists of: 45 calls on a data frame (row counts, distinct counts, sums of a
condition, min/max), 36 field or element accesses, 32 model-object accessors or transforms, 6
ratios or products of variables.

**The R-route conversion read for the Lua route** (101 constructs): 27 (a), 61 (b) (55 values on
an expression, 5 conditions outside the grammar: field access, arithmetic, a call; 1 `sign` on a
field), 13 (c): 4 `ci()`, 1 `about()`, 8 dictionary reads.

## When the approved rulings land

- Plus sign (with Lua parity): 7 `sign` spans become a key on a plain value; the signed list moves
  (c) to (b). `ci()` stays an R phrase function unless a filter form is designed; one over a
  published est/lo/hi would cut 48 interval names to 16.
- `.p` digits and label: no effect (no p-values here).
- Forward references: binding lines can sit in one place; the number of them does not change.
- Chunk claims, table digests, rendered-output check, `decision=`, documenting the
  `weft_str()`/`weft_put()` routes, a `range` dictionary type: no change to the split.

After them: 31 / 120 / 2. **The biggest blocker is not a missing feature.** 78% of the values are R
expressions, and a named value is a bare name with no expression and no field access. That is
deliberate (the filter chooses, formats and compares; code computes) and no ruling touches it. Far
behind it: the dictionary (8 reads) and `about()`.

## The two routes compared on this chapter

- **Code added** for a full conversion: R route about 10 lines plus 4 dictionary entries; Lua
  route about 112 binding lines (plus 2 bools for conditions, 4 if dictionary numbers are
  published). Prose edits: about the same count either way.
- **Readability**, one invented sentence:
  - original: `` `r n_fmt(nrow(d))` `` ... `` `r sgn(100 * coef(m)[["yr"]], f1)` `` ...
    `` (95% CI `r f1(100 * ci_m[1])` to `r f1(100 * ci_m[2])`) ``
  - R route: `` `r nrow(d)`{.num} `` ... `` `r ci(100 * coef(m)[["yr"]], 100 * ci_m[1], 100 * ci_m[2], digits = 1)` ``
  - Lua route: `weft_put(n_samp = nrow(d), trend = ..., trend_lo = ..., trend_hi = ...)` in a
    chunk, then `` `n_samp`{.num} `` ... `[+# | −# | #]{.num digits="1" sign="trend"}` ...
    ``[(95% CI `trend_lo`{.num digits="1"} to `trend_hi`{.num digits="1"})]{if="trend_lo <= trend, trend <= trend_hi"}``

  The Lua sentence is cleanest for a ready name and longest for an interval or a sign, and the
  meaning of each name lives elsewhere.
- **R only:** `claim()` on any expression, `ci()`, `about()`, the dictionary (ledger key and hash,
  `dict-*` lints), units, formatters, any R condition, the R-expression lints, `rehearse()`, the
  condition log. **Lua only:** values in text a chunk prints, captions without `!expr`, a check
  that travels with the value (`weft_put(x = claim(...))`), run ids and freshness, values files
  hashed in the ledger header. **Both:** markers and one report, ledger and `changes()`, stamp,
  `verify()`, gate counts; but a Lua guard counts as a span, an R `claim()` as a claim.
- **Render cost:** the R conversion added 2.1 to 3.8 s on 8.9 s (trial). The Lua route was not
  rendered; the filter alone on a synthetic page of 300 named constructs took about 0.2 s.
- **Mixed use:** both work side by side in a knitr document. Names earn their place in this chapter
  for the asis section (tested: no chunk edit), the verdict table, the computed table caption and
  the figure caption (a markdown string with names and `n`/`sign` spans instead of `sprintf()` in
  `!expr`). Elsewhere the R route is shorter and keeps the computation visible.

## Judgement

For an R/knitr statistics report the Lua route is a complement, not a main route. On this chapter
it would cost about 112 new names and lines of code where the R route needed about 10, because
78% of the values are expressions over data frames and model objects; only 2% are blocked by a
missing feature, the approved rulings move one of those, and the main blocker is deliberate. The
R conversion also uses what the filter lacks (`ci()`, `about()`, the dictionary). The Lua route
wins on text R prints rather than reads: about 47 pieces here (the asis section, a text-built
table, two captions), plus Python or Julia chapters and values a pipeline publishes once for
several chapters.
