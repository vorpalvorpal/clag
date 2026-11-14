# Setting up a project

This article is for anyone setting weft up in a project, or taking it
out again. After it you will know what each `use_*()` function writes
and why, how to choose how weft is activated, how weft treats files it
wrote that you have since edited, and how to remove each part. The last
section lists every setting in `_weft.yml`.

The examples change files in a project, so they are not run when this
article is built. Each was run in a scratch project, and the output
shown is what it printed. Paths have been shortened.

## One call: `use_weft()`

[`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md)
runs every installer in order, from one plan:

| Step | Runs when | Writes |
|----|----|----|
| [`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md) | always | `_weft.yml`, and the activation (a `.Rprofile` line or front matter) |
| [`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md) | in a Quarto project | the `weft-check` extension (the filters `weft.lua` and `weft-check.lua`), the render scripts, entries in `_quarto.yml` |
| [`use_dictionary()`](https://vorpalvorpal.github.io/weft/reference/use_dictionary.md) | always | `dict.yml` and its schema |
| [`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md) | in a git work tree | the `commit-msg` hook |
| [`use_ci()`](https://vorpalvorpal.github.io/weft/reference/use_ci.md) | when `origin` is on github.com | a GitHub Actions workflow |
| [`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md) | always | a block in `AGENTS.md` and the weft skill, in `.agents/skills` (`skills = c("agents", "claude")` adds `.claude/skills`, which Claude Code reads) |

It prints the plan, then writes. In a Quarto website with a GitHub
remote:

``` r

weft::use_weft()
#> weft will set up creek-site:
#>   use_setup       .Rprofile (edit), _weft.yml (new), index.qmd (edit)
#>   use_quarto      _extensions/weft-check/_extension.yml (new), _extensions/weft-check/weft.lua (new), _extensions/weft-check/weftlib/ (new), _extensions/weft-check/weft-check.lua (new), _extensions/weft-check/weft-output.lua (new), _weft/pre-render.R (new), _weft/post-render.R (new), _quarto.yml (edit)
#>   use_dictionary  dict.yml (new), _weft/dict.schema.json (new)
#>   use_hooks       .git/hooks/commit-msg (new)
#>   use_ci          .github/workflows/weft.yml (new)
#>   use_agent_docs  AGENTS.md (new), .agents/skills/weft/SKILL.md (new), .agents/skills/weft/references/reports.md (new), .agents/skills/weft/references/syntax.md (new)
#> Wrote: .Rprofile, _weft.yml, index.qmd, _extensions/weft-check/_extension.yml, ...
```

The call is the consent: it never asks. If any step cannot be done
safely, it writes nothing and says why. If a step fails part-way, it
undoes what the earlier steps wrote.

Running it again changes nothing:

``` r

weft::use_weft()
#> weft will set up creek-site:
#>   use_setup       nothing to change
#>   use_quarto      nothing to change
#>   use_dictionary  nothing to change
#>   use_hooks       nothing to change
#>   use_ci          nothing to change
#>   use_agent_docs  nothing to change
#> Nothing to change: the project is already set up.
```

After you update weft, run
[`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md)
again. It brings the files weft wrote up to date and records the new
version in `_weft.yml`.

Every installer can also be run on its own, and each is silenced by
[`suppressMessages()`](https://rdrr.io/r/base/message.html).

## What is in the project now: `status()`

[`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
reports each part, and the next step to take. In an R Markdown folder
that has not been set up:

``` r

weft::status()
#> weft status: rmd
#>   setup        missing   no _weft.yml
#>   activation   missing   no .Rprofile line and no front-matter route
#>   quarto       n/a       not a Quarto project
#>   dictionary   missing   no dict.yml
#>   hooks        n/a       not a git repository
#>   ci           n/a       not a git repository
#>   agent docs   missing   AGENTS.md block: missing; skill: missing
#>   draft        ok        draft mode is off
#>   verify_skip  ok        verify() skips nothing
#>   strict       ok        no rule is strict
#> Next: run weft::use_setup() to write _weft.yml and record the weft version.
```

A part’s state is one of:

- `ok`;
- `missing`;
- `outdated`: the file is from another version of weft, or the hook’s
  `Rscript` has gone;
- `edited`: a file weft wrote has been changed by hand (see below);
- `off`: draft mode is on, or
  [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
  skips a part;
- `n/a`: the part does not apply here.

[`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
writes nothing.

## Activation: `use_setup()`

weft does nothing in a document until it is **activated**, which means
[`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
has run before the knit reaches any prose. Loading the package with
[`library(weft)`](https://vorpalvorpal.github.io/weft/) does not
activate it.
[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
chooses one of two routes:

- **`.Rprofile`**, the default in a Quarto project. R runs the project’s
  `.Rprofile` before every knit, so every document is covered, including
  one added later.
- **front matter**, the default elsewhere. Each document gets the line
  itself, so a document copied out of the project still works.

`use_setup(route = "rprofile")` or `use_setup(route = "front-matter")`
chooses for you.

### The `.Rprofile` route

A new `.Rprofile` looks like this:

``` r

# weft: activates weft in every knit of this project (weft::use_setup(), rule 9.2.1).
# R reads this file instead of your ~/.Rprofile; the next line keeps yours.
if (file.exists("~/.Rprofile")) source("~/.Rprofile")
if (requireNamespace("weft", quietly = TRUE)) weft::weft_setup()
```

R reads only one profile, so the new file runs yours first. An existing
`.Rprofile` gains the two weft lines at its end, after renv’s activation
line, so weft is found in renv’s library:

``` r

# my profile
source("renv/activate.R")

# weft: activates weft in every knit of this project (weft::use_setup(), rule 9.2.1).
if (requireNamespace("weft", quietly = TRUE)) weft::weft_setup()
```

[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) means R
still starts in the project for a collaborator who does not have weft.
Their renders, though, do not resolve the constructs: a span prints as
plain text, and an inline value that calls
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) or
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) stops with
“could not find function”.

### The front-matter route

[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
in a folder of R Markdown documents edits each one:

``` r

weft::use_setup()
#> weft will write, under rmd:
#>   _weft.yml  (new: settings, and the weft version that set the project up)
#>   survey.Rmd  (edit: adds the weft setup line and names the weft-check filter)
#>   weft-check.lua  (new: the weft-check filter for rmarkdown)
#>   weft-output.lua  (new: the rendered-output check for rmarkdown)
#>   weft.lua  (new: the weft filter for rmarkdown)
#>   weftlib/...  (new: the modules weft.lua loads, one line each)
#> Wrote: _weft.yml, survey.Rmd, weft-check.lua, weft-output.lua, weft.lua, weftlib/...
```

The document’s front matter was `output: html_document`. It is now:

``` yaml
---
title: "Survey"
output:
  html_document:
    pandoc_args: ["--lua-filter", "weft.lua", "--lua-filter", "weft-check.lua", "--lua-filter", "weft-output.lua"]
knitr:
  opts_knit:
    weft: !expr weft::weft_setup()
---
```

`weft-check.lua` is a Pandoc filter. It reads the output after the knit
and reports any construct left unresolved, such as a span whose key was
misspelt. `weft.lua` resolves named values (see
[`vignette("named-values", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/named-values.md))
and runs first; it loads its modules from `weftlib/`. `weft-output.lua`
runs last and checks the rendered text for unresolved references,
missing values and leftover markup (see
[`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md)).
A document set up before that check gets `weft-output.lua` named last
when you run
[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
again. In a Quarto project,
[`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
installs the same filters as an extension.

### Quarto documents need `engine: knitr`

Quarto chooses an engine for each document from the code it holds, and
weft runs only under knitr.
[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
therefore adds `engine: knitr` to each `.qmd` that names no engine, so
that every document with constructs is knitted. It leaves a document
that names `jupyter:` alone, and files and folders whose names start
with `_` or `.` (included files).

The key must be in each document’s own front matter. An `engine:` in
`_quarto.yml` does not count, and the lint `engine` finds a document
that lacks it.

### When an edit is not safe

[`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
and
[`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
edit YAML as text, line by line, and keep every other line, comments
included. When a file is written in a way they cannot edit safely, they
change nothing and print the lines to add by hand:

``` r

weft::use_quarto()
#> Error: use_quarto(): weft cannot edit _quarto.yml as text without risking what is in it, so it has changed nothing. Add these lines by hand, then run use_quarto() again:
#>
#> filters:
#>   - weft-check
#>   - path: _extensions/weft-check/weft-output.lua
#>     at: post-render
#> project:
#>   pre-render: _weft/pre-render.R
#>   post-render: _weft/post-render.R
#>
#> (merge them into the `filters:` and `project:` entries the file already has; each of those holds a list, and `weft-check` and the two scripts go into it.)
```

This `_quarto.yml` had `filters: [a, b]` on one line.

## A Quarto project: `use_quarto()`

[`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
writes three things and names them in `_quarto.yml`:

``` yaml
project:
  type: website
  pre-render:
    - _weft/pre-render.R
  post-render:
    - _weft/post-render.R
filters:
  - quarto
  - weft-check
  - path: _extensions/weft-check/weft-output.lua
    at: post-render
```

- `_extensions/weft-check/` holds the filters `weft.lua` and
  `weft-check.lua`, and the folder `weftlib/` that `weft.lua` loads.
- It also holds `weft-output.lua`, the rendered-output check. That
  filter must run after Quarto’s own filters, and an extension cannot
  place a filter there, so
  [`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
  names it in `_quarto.yml` by its path, with `at: post-render`. **A
  project set up before this check gets the entry only when you run
  [`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
  again;** until then
  [`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
  reports the `quarto` row as `missing`. See
  [`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md)
  for what the check finds.
- `_weft/pre-render.R` runs before anything renders. It stops the
  render, naming the file, when a `.qmd` holds a construct and has no
  `engine: knitr`.
- `_weft/post-render.R` runs after the render. It prints one report of
  the failures from every chapter, then fails the render if there were
  any. A book or website therefore reports all its failures at once,
  rather than stopping at the first chapter.

Both scripts are plain base R, so they run where weft is not installed.

[`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
stops in a folder with no `_quarto.yml`. It does not turn a folder into
a Quarto project.

## The dictionary: `use_dictionary()`

[`use_dictionary()`](https://vorpalvorpal.github.io/weft/reference/use_dictionary.md)
writes `dict.yml`, a starter with two examples commented out, and
`_weft/dict.schema.json`. The first line of `dict.yml` points an editor
such as VS Code or Positron at the schema, so the editor checks each
entry as you type:

``` yaml
# yaml-language-server: $schema=_weft/dict.schema.json
```

An existing `dict.yml` is never changed. See
[`vignette("units", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/units.md)
for the entries themselves.

## The commit gate: `use_hooks()`

[`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md)
writes `.git/hooks/commit-msg`, which runs the commit gate on each
commit. It needs a git work tree:

``` r

weft::use_hooks()
#> Error: use_hooks() needs a git work tree, and rmd is not in one (not a git repository). Run git init first.
```

The hook records the `Rscript` and library paths of the session that
installed it. Run
[`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md)
again after you upgrade R or move your library. When the repository
already has a `commit-msg` hook from another tool,
[`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md)
leaves it alone and prints the line to add to it. See
[`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md).

Git does not copy hooks with a repository, so each collaborator runs
[`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md)
(or
[`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md))
once in their own clone.

## Pull requests: `use_ci()`

[`use_ci()`](https://vorpalvorpal.github.io/weft/reference/use_ci.md)
writes `.github/workflows/weft.yml` at the top of the repository. On
each pull request it installs weft and runs
`weft::verify(static = TRUE)`, compared with the point where the branch
left its base. It needs `origin` to be on github.com.

## Coding agents: `use_agent_docs()`

[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
tells a coding agent the rules of a weft project. It appends a block to
`AGENTS.md`, creating the file if needed, and writes a skill to
`.agents/skills/weft/`. Claude Code reads `.claude/skills/` and not
`.agents/skills/`, so Claude Code users call
`use_agent_docs(skills = c("agents", "claude"))` (or install the plugin:
`/plugin marketplace add vorpalvorpal/weft`). If the project has a
`CLAUDE.md` that does not include `AGENTS.md`, it says so:

``` text
Claude Code reads CLAUDE.md: add the line @AGENTS.md to it, or move the block there.
```

[`vignette("agents", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/agents.md)
describes what the block and the skill say.

## Files you have edited

Each file weft writes carries a marker: a `weft-file:` line, or for
`AGENTS.md` a `<!-- weft:start ... -->` line. The marker holds the weft
version and a hash of the file’s other lines. With it, an installer can
tell three cases apart:

- **weft’s file, unedited**: replaced when this version of weft would
  write something different;
- **weft’s file, edited by you**: left as it is.
  [`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
  reports it as `edited`, and `overwrite = TRUE` replaces it;
- **no marker**: another author’s file. It is never replaced, even with
  `overwrite = TRUE`.

``` r

weft::use_agent_docs()
#> weft will write, under creek-site:
#>   AGENTS.md  (keep: the weft rules for coding agents)
#>   .agents/skills/weft/SKILL.md  (edited: edited since weft wrote it; left as it is (use overwrite = TRUE to replace it))
#>   .agents/skills/weft/references/reports.md  (keep: the weft skill for coding agents)
#>   .agents/skills/weft/references/syntax.md  (keep: the weft skill for coding agents)
#> Nothing to change: the agent documents are already set up.
```

[`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md),
[`use_ci()`](https://vorpalvorpal.github.io/weft/reference/use_ci.md)
and
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
take `overwrite`.

## What weft writes while it works

Besides the files above, weft writes:

- `_weft/ledger/`: the ledgers, one folder per source. Commit them. See
  [`vignette("gate", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/gate.md).
- `.weft/`: working files for a render, such as each document’s record
  of the checks it ran. It holds its own `.gitignore`, so git ignores
  it.
- `.git/weft/`: the gate’s cache.
- A cache of the units database, under
  `tools::R_user_dir("weft", "cache")`, outside the project.

## Removing weft

To take weft out of a project, undo each part. Only the hook has a
function; the rest are files to delete or lines to remove.

| Part | Remove |
|----|----|
| hook | `use_hooks(remove = TRUE)`, which also removes `.git/weft/` |
| activation, `.Rprofile` route | the two `# weft:` and [`weft::weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md) lines in `.Rprofile`, or the file if weft created it |
| activation, front-matter route | the `knitr: opts_knit: weft:` lines in each document |
| R Markdown filter | `weft.lua`, `weft-check.lua`, `weft-output.lua`, `weftlib/`, and the `pandoc_args` line that names them |
| Quarto | `_extensions/weft-check/`, `_weft/pre-render.R`, `_weft/post-render.R`, and their entries in `_quarto.yml`: `weft-check` and the `weft-output.lua` item under `filters:`, and the two scripts |
| dictionary | `dict.yml` and `_weft/dict.schema.json` |
| continuous integration | `.github/workflows/weft.yml` |
| agent documents | the block between `<!-- weft:start` and `<!-- weft:end -->` in `AGENTS.md`, and `.agents/skills/weft/` (and `.claude/skills/weft/` when you ask for it) |
| records | `_weft/ledger/` and `.weft/` |
| settings | `_weft.yml` |

``` r

weft::use_hooks(remove = TRUE)
#> weft will remove, under creek-site:
#>   .git/hooks/commit-msg  (remove: the weft commit-msg hook)
#> Removed: .git/hooks/commit-msg
```

Remove the constructs from the documents first, or render with weft
still active. Without weft, a document that holds them prints each span
as plain text, and
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) and
[`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) are not
found.

## Settings

`_weft.yml` sits at the project root. Every key has a default, so the
file holds only what you change. A document can set most of them for
itself under a `weft:` key in its front matter:

``` yaml
weft:
  digits: 2
```

`draft`, `decisions` and `verify_skip` belong to the project and may
only be set in `_weft.yml`. Never put a `weft:` key in `_quarto.yml`;
the lint `config-place` finds one there. A misspelt key is kept, with a
warning that names it.

| Setting | Default | What it does | Read more |
|----|----|----|----|
| `digits` | `1` | decimal places for a value | `values` |
| `decimal_mark`, `big_mark` | `"."`, `","` | the marks in a number | `values` |
| `thousands_from` | `1000` | the smallest number that gets a thousands mark | `values` |
| `minus` | `"−"` (U+2212) | the minus sign | `values` |
| `pct_proportion` | `true` | whether `.pct` reads 0.12 as 12% | `values` |
| `count_threshold` | `10` | where `.count` switches from words to digits | `values` |
| `serial_comma` | `false` | a comma before the final “and” or “or” of three or more items | `values` |
| `word_limit` | `100` | where `.word` switches to digits | `values` |
| `date_format` | `"%-d %B %Y"` | the format of `.date` | `values` |
| `governor_class` | `".num"` | the class that formats the number of an `n` or `sign` span | `values` |
| `formatters` | none | project formatters, with the options each takes | `values` |
| `p_digits` | `null` | the decimals of `.p`, 1 to 6; `null` keeps the default rule | `values` |
| `p_label` | `"p"` | the text before a p-value’s relation; may be `""` | `values` |
| `ci_level` | `0.95` | the level [`ci()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) reports | `wording` |
| `ci_short` | `false` | whether [`ci()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) drops the level text | `wording` |
| `chunk_claims` | `"stop"` | `collect` records a failed claim in chunk code and goes on; the render fails at the end | `wording` |
| `about_tolerance` | `0.05` | how close [`about()`](https://vorpalvorpal.github.io/weft/reference/phrases.md) must be | `wording` |
| `sentence_start_fail` | `false` | fail on a number printed as a numeral at the start of a sentence | `wording` |
| `unit_form` | `"auto"` | whether units print as symbols or names (`auto`, `symbol`, `name`) | `units` |
| `unit_defaults` | `"weft"` | `si` skips the rows of weft’s unit table that redefine a unit the units package already reads, such as pH | `units` |
| `units` | none | units the project defines | `units` |
| `decisions` | `"github"` | where a dictionary entry’s `decision` pointer resolves | `units` |
| `bibliography` | none | bibliography files the lints read for citation keys | `lints` |
| `label_words`, `numeral_years`, `claim_words`, `claim_quantifiers`, `claim_cap`, `guard_words`, `expected_names`, `strict` |  | the lints | `lints` |
| `bare_missing` | `true` | whether a bare value that prints `NA`, `NaN`, `Inf` or `-Inf` is a warned check | `values` |
| `anchor_calls` | none | helper calls that define anchors for the cross-reference lints | `lints` |
| `severity` | two patterns | regular expressions: a warning or message that matches one fails the render | below |
| `output_refs` | `"fail"` | unresolved references in the rendered output: `fail`, `warn` or `off` | `gate` |
| `output_missing` | `"warn"` | `NA`, `NaN` and `Inf` printed in the rendered prose | `gate` |
| `output_markup` | `"fail"` | markup Pandoc did not read, left in the rendered text | `gate` |
| `ledger` | `true` | whether a render writes a ledger | `gate` |
| `draft` | `false` | draft mode | `gate` |
| `verify_skip` | none | parts [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md) skips | `gate` |
| `weft_version` |  | the version that set the project up; [`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md) maintains it |  |

`severity` starts with patterns for a singular model fit and a
non-positive-definite Hessian. A project adds its own. With
`severity: ["NAs introduced"]`, the coercion warning from a laboratory
value written “\<0.5” stops the render:

``` text
Error: weft: 2 failures
  t.Rmd chunk data  [condition]
      warning: NAs introduced by coercion
      matched the severity pattern NAs introduced
  t.Rmd:14  [sentence start] k
      a printed "3" opens a sentence; write .cap (with .count or .word for a number) (rule 5.10.1)
```

The second failure comes from `sentence_start_fail: true`, set in the
same `_weft.yml`, for the sentence “`` `r k` `` sites were dry.”
