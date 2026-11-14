# Adopting weft in an existing report

This article is for an author with a long report that already renders: a
statistics report in R Markdown or Quarto, with its own helpers, its own
house style and many numbers typed into the prose. After it you will
know what to turn on first, what the first renders will report, and how
to decide how hard each kind of check should fail.

None of the code in this article is run when the article is built.

## The order to work in

Adopt weft in small steps, and commit after each one. Each step leaves a
report that renders.

1.  **Set up, change nothing else.** Run
    [`weft::use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md)
    (see
    [`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md)).
    Render. A document with no constructs renders as it did: weft adds
    the ledger and its checks of the rendered output, and prints the
    same text.
2.  **Read the first render’s report**, below, and fix what it finds.
    Then commit the source with `_weft/ledger/`. The gate passes the
    first commit by design: it refuses only what `HEAD` did not hold.
3.  **Set the house style** in `_weft.yml`, so that values print as the
    report already prints them.
4.  **Convert one chapter**: typed numbers to values, helpers to
    classes, direction words to spans,
    [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) to
    [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md).
5.  **Collect chunk claims**, so that one render lists every failure.
6.  **Add `severity` patterns** for the warnings your models raise.
7.  **Before release**, turn draft mode off and run
    [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md).

## What the first renders report

The first render of an existing report can report three kinds of thing.

- **The rendered-output check.** A cross-reference Quarto could not
  resolve, which it printed as “?@sec-…” and only warned about in its
  log, now fails the render. An “NA” in the prose is a warned check. A
  fence Pandoc did not read fails. These were in the output before; weft
  now says so. See
  [`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md).
- **Conditions.** The condition log records every warning and message a
  chunk raised, `warning: false` or not. A warning or message fails
  nothing unless it matches a `severity` pattern, but
  [`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
  lists each new one.
- **Construct errors**, once you start writing constructs: a misspelt
  class, two classes from one group. They stop the render at once and
  name the line.

[`lints()`](https://vorpalvorpal.github.io/weft/reference/lints.md)
reports typed numbers, but the gate tolerates every one already
committed. The count of tolerated findings that
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
prints is how far adoption has come.

A project that upgrades weft rather than adopting it sees one more thing
once: the first render after the upgrade lists every table of each
ledger as added. Commit the ledgers and it is gone.

## The house style

Most reports have a style weft can reproduce with settings. A typical
`_weft.yml` for a statistics report:

``` yaml
serial_comma: true        # "A, B, and C"
count_threshold: 11       # .count spells one to ten, digits from 11
numeral_years: true       # a year in prose is not a typed number
label_words: [Site, Plot, Model]
anchor_calls: [fig_with_label]
p_digits: 3               # "p = 0.046", "p < 0.001", "p = 0.120"
p_label: "*p*"            # an italic p
ci_short: true            # "2.1 (1.3 to 2.9)"
chunk_claims: collect     # see below
```

`numeral_years` and `label_words` cut the `numeral` lint’s findings to
the numbers that are quantities.
[`label_seed()`](https://vorpalvorpal.github.io/weft/reference/label_seed.md)
proposes label words from the prose. `anchor_calls` names your own
helpers that create a figure or table label, so the cross-reference
lints know those anchors exist (see
[`vignette("lints", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/lints.md)).

A rule no class covers goes in a **project formatter**. A report that
prints whole percentages from 10% up and two significant figures below:

``` yaml
formatters:
  .pctrule:
    function: pct_rule
    stage: number
```

``` r

pct_rule <- function(x) {
  ifelse(abs(x) >= 0.1, weft::fmt_pct(x, digits = 0), weft::fmt_pct(x, sigfig = 2))
}
```

`` `r share`{.pctrule} `` then prints “23%” for 0.234 and “4.6%” for
0.0456.

## Helpers to classes

A report’s own formatting helpers map onto classes. Replace each call in
the prose, and keep the helper only where code still needs it:

| In the report | With weft |
|----|----|
| `` `r scales::percent(x)` ``, `` `r sprintf('%.1f%%', 100 * x)` `` | `` `r x`{.pct} `` |
| `` `r format(x, big.mark = ',')` `` | `` `r x`{.num} `` |
| `` `r nice_p(p)` `` | `` `r p`{.p} `` |
| `` `r paste0(ifelse(d > 0, '+', ''), round(d, 1))` `` | `` `r d`{.num .plus} `` |
| `` `r paste(est, ' (', lo, '–', hi, ')')` `` | `` `r ci(est, lo, hi)` `` |
| `` `r paste(x, collapse = ', ')` `` | `` `r x`{.and} `` |
| a word chosen with `ifelse(d > 0, "rose", "fell")` | `[rose \| fell \| did not change]{sign="d"}` |
| `stopifnot(n >= 10)` before a sentence | `n <- claim(n, . >= 10)` where `n` is made |

The last two are the ones that matter most. A direction word chosen by a
span cannot disagree with its number, and a claim fails the render with
the sentence quoted, where
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) stopped with a
bare message. See
[`vignette("wording", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/wording.md).

Text that a chunk prints with `results: asis`, such as a list of
questions or one sentence per site, is converted with
[`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
or with named values (see “Text a chunk prints” in
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md)).

## Reads weft can and cannot follow

The ledger records each target a document reads, so that
[`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
and
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
can say when a value was not re-rendered. A report that reads its store
through a helper of its own is followed when the helper passes one of
its arguments as the name:

``` r

read_t <- function(name, store = here::here("_targets")) {
  targets::tar_read_raw(name, store = store)
}
read_t("fit_main")      # recorded: target fit_main, from the default store
```

A `store` that is not a literal is evaluated at the end of the knit, so
the default above resolves. These are not followed:

``` r

read_shared <- function(id) targets::tar_read_raw(paste0("shared_", id))
#   the helper builds the name, so no call names a target
read_local <- function(name) {
  s <- file.path(root, "_targets")
  targets::tar_read_raw(name, store = s)
}
#   the store is a local of the helper: the read is recorded under the
#   default store, with a warning that names it
source(here::here("R", "helpers.R"))
#   only a literal path is recorded as a file the document read
```

Where a read matters to the report, pass the name and the store as
arguments, or read the target by its literal name. See
[`vignette("targets", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/targets.md).

## Activation: `.Rprofile` or front matter

[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
activates weft through the project’s `.Rprofile` in a Quarto project,
and through each document’s front matter elsewhere.

- Choose the **`.Rprofile`** for a book or website: every chapter is
  covered, including one added later. The file keeps your own
  `~/.Rprofile` and renv’s activation.
- Choose **front matter** for documents that travel on their own, or
  where a project `.Rprofile` would be a surprise to others.

A collaborator without weft can still start R in the project. Their
renders print each span as plain text, so render releases where weft is
installed.

## Coding agents

[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
writes the rules a coding agent should follow into `AGENTS.md` and a
skill. Claude Code reads `CLAUDE.md`, not `AGENTS.md`: add the line
`@AGENTS.md` to `CLAUDE.md`. See
[`vignette("agents", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/agents.md).

## Choosing how hard a check fails

weft has three strengths for a check, and a report needs all three.

**A failing check** stops the render, or fails it at the end, with the
sentence quoted. Use it when the sentence is false if the check fails:
“most sites rose” needs `n_up > n_sites / 2`.

``` r

n_up <- claim(sum(trend$up), . > n_sites / 2)
```

**A warned check**, `level = "warn"`, is listed at the end of the render
and never fails it. Use it for a condition worth a look that does not
make any sentence false, such as a sample smaller than the method
prefers:

``` r

n_obs <- claim(nrow(d), . >= 30, level = "warn")
```

Do not weaken a failing check to a warned one to get a render through.
The commit gate treats them differently: a warned check that remains
does not cover a failing one that was removed.

**Settings** set the strength of weft’s own checks, each `fail`, `warn`
or `off`:

| Setting          | Default | Checks                                    |
|------------------|---------|-------------------------------------------|
| `output_refs`    | `fail`  | references Quarto could not resolve       |
| `output_missing` | `warn`  | `NA`, `NaN` or `Inf` printed in the prose |
| `output_markup`  | `fail`  | markup Pandoc did not read                |

Three more settings move a check between levels: `bare_missing: false`
turns off the warning on a bare value that prints `NA`;
`sentence_start_fail: true` fails a numeral at the start of a sentence;
`chunk_claims: collect` keeps the knit going after a failing claim in a
chunk and fails the render at the end. A lint is tolerated while old
findings remain, and fails on any finding once it is listed in `strict`.

Draft mode is not a strength. It reports every failure and fails
nothing, for a chapter half written;
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
refuses to run in it.

### Model-convergence warnings

A model that did not converge usually warns and returns estimates
anyway, and the report prints them. The `severity` list in `_weft.yml`
turns a warning or message that matches one of its patterns into a
failure. weft ships two patterns: a singular fit and a
non-positive-definite Hessian. For lme4 and glmmTMB add:

``` yaml
severity:
  - "failed to converge"
  - "Model failed to converge with max\\|grad\\|"
  - "false convergence"
```

The patterns are regular expressions, so the bars in `max|grad|` are
escaped. lme4 prints “failed to converge” and “Model failed to converge
with max\|grad\| = …”; glmmTMB prints “false convergence” and
“non-positive-definite Hessian matrix”, the second of which the shipped
pattern already covers. A project’s patterns add to the shipped ones.

A warning raised inside a `targets` pipeline is matched too, when the
document reads that target: the condition log takes the warnings that
[`targets::tar_meta()`](https://docs.ropensci.org/targets/reference/tar_meta.html)
holds for it. A message raised there is not.
