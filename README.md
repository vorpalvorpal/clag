# weft

weft puts computed values, and wording that depends on them, into Quarto and
R Markdown prose. It also adds checks for computational manuscripts, so that a
number in the text is the number the analysis produced. Every construct is
markdown that knitr, Pandoc and Quarto already accept.

**Status:** weft is being built from the design in `PACKAGE-SCOPING.md`. It is
not usable yet.

| Write | Prints |
|---|---|
| `` `r depth`{.num} `` | the value of `depth`, formatted as a number |
| `` `r claim(x, . > 10)` `` | the value of `x`, after checking it is above 10 |
| `[rose \| fell]{if="slope > 0"}` | "rose" when `slope` is positive, otherwise "fell" |
| `[# site \| # sites]{n="k"}` | "1 site" or "3 sites", depending on `k` |
| `` `r sites`{.or} `` | a list of values: "a, b or c" |

The earlier `clag` package, a string templating package that weft replaces, is
at the tag `clag-0.2.0`.
