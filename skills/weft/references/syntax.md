# weft syntax

One example for each construct. Write these as shown; do not invent others.

## An inline value

A computed value, printed by its class. The class and options go in `{}`.

```markdown
Mean turbidity was `r mean_ntu`{.num}, or `r mean_ntu`{.num digits="2"} to two places.
`r share`{.pct} of samples exceeded the guideline (`r p_val`{.p}).
The mean rose by `r d_mean`{.num .plus} mg/L.
We sampled `r sites`{.and trunc="3"}.
```

Classes in use: `.num`, `.pct`, `.p`, `.sci`, `.ord`, `.count`, `.word`, `.date`,
`.range`, `.pairs`, `.and`, `.or`. `.plus` signs a number.

weft reads inline R wherever knitr evaluates it: prose, a code span, a fenced
block that is not a chunk, an HTML comment, math. Wrapping text in an HTML
comment does not switch its values or checks off.

Inside math (`$...$`, `$$...$$`, a math environment such as `align`) and raw
LaTeX (a `{=latex}` fence, another `\begin{...}` environment) a class block
writes TeX, not markdown:

```markdown
$a = `r x`{.num digits=2}$, $b = `r share`{.pct}$ -> $a = 8.23$, $b = 12.3\%$
```

Use `.num`, `.pct`, `.sci`, `.p`, `.plus`, `.range` and the unit classes there.
`.p` prints its own label, so write `` $`r p_val`{.p}$ ``. The words, emphasis
and list classes (`.word`, `.count`, `.ord`, `.date`, `.a`, `.cap`, `.em`,
`.strong`, `.and`, `.or`, `.pairs`, `.ul`, `.ol`, `.dl`) are a construct error
in math. A bare `` `r x` `` there prints as stock prints it, and `fmt_num(x)`
in it writes markdown; for code that builds a formula, `fmt_num(x, target =
"tex")` writes TeX. A project formatter needs `targets: [markdown, tex]` in
`_weft.yml` to be used in math. A named value (`` $`depth`{.num}$ ``) works in
math and raw LaTeX too: the filter resolves it and writes the same TeX.

## Spans that choose wording

```markdown
[No site | One site | # sites]{n="n_high"} read above the trigger.
```
`n`: the wording follows a count (none, one, many); `#` prints the count.

```markdown
Turbidity [rose | fell]{if="slope > 0"} over the year.
```
`if`: the first word when the condition is true, the second when false.

```markdown
Abundance [rose by # | fell by # | did not change]{.pct sign="d_abund"}.
```
`sign`: the wording follows the sign of the value; `#` prints it.

```markdown
[No sites were | # was | # were]{list="flagged"} flagged.
```
`list`: the wording follows the length of a vector; `#` prints the list.

```markdown
Earlier work found [0.5 m in the upper reach]{cite="@doe2019"}.
```
`cite`: a number quoted from a source; the key is in the bibliography.

## A check

```r
n_sites <- claim(nrow(d), . >= 30)
n_obs <- claim(nrow(d), . >= 30, level = "warn")
```

`claim(x, check)` returns `x` and fails when `check` is false; `.` is the value.
A failed claim is a finding to report; do not edit the check to pass it.
In prose: `` `r claim(max(turbidity), . < u(50, NTU))`{.num} ``.

## Named values

A value with a name is published to the prose: a bare name in the inline block
reads it.

```r
weft_put(n_sites = length(turbidity))
weft_put(worst, n_high)
```

```markdown
The worst reading was `worst`{.num} NTU.
```
`weft_put()` in R, `put()` in Python and `@put` in Julia publish by hand.

## A literal that must stay

```markdown
Samples were filtered through [0.45 um]{.weft-literal why="pore size set by the laboratory method"} membranes.
```
`.weft-literal` needs a real `why`. Do not use it to silence a finding.
