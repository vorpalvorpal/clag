# Working with coding agents

This article is for authors who let a coding agent, such as Claude Code,
edit a weft project, and for the agents themselves. After it you will
know what weft tells an agent, why, and how each kind of finding should
be answered.

## Why an agent needs rules

weft’s checks fail on purpose. A failed claim says that the prose and
the numbers disagree. The commit gate refuses a typed number. Removing a
construct needs a line in the commit message.

An agent asked to “make the render pass” has easy ways to do it that
defeat the point: loosen the claim, delete the check, type the number
back in as a literal, turn on draft mode, or commit with `--no-verify`.
Each makes the error go away and leaves the report wrong. The rules
below close those ways, and say what to do instead.

## What `use_agent_docs()` writes

[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
writes two files.
[`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md)
runs it, or you can run it alone (see
[`vignette("setup", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/setup.md)).

The first is a block in `AGENTS.md`, the file many coding agents read
when they start. weft appends it after any text already there:

``` r
cat(readLines(system.file("agent", "AGENTS.md", package = "weft")), sep = "\n")
## weft

This project uses the weft R package: numbers in the prose are computed
(`` `r x` ``), wording that depends on them is chosen by spans
(`[a site | # sites]{n="k"}`), and `claim()` checks what the prose says.

- A failed claim is a finding to report to the author, not an error to clear.
- Do not change or remove a check (`claim()`, a guard, a bound) to make a
  render or a commit pass, unless the author asks for exactly that.
- When a commit removes weft constructs on purpose, add the line the
  commit-msg hook prints, `Weft-Removed: N`, with its number. Do not use
  `--no-verify` to get past the hook.
- Values that hold for one chapter only go in that document's front matter
  under `weft: dict_local:`, each with a `why:`; read them as
  `dict_local$key`, never `dict$key`.

The weft skill (`.claude/skills/weft/`) has the detail.
```

In the project, the block sits between a `<!-- weft:start ... -->` line
and a `<!-- weft:end -->` line. weft replaces only what lies between
them. Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If the project has
a `CLAUDE.md`, add the line `@AGENTS.md` to it so that it includes the
block.

The second is a skill, `.claude/skills/weft/SKILL.md`, which Claude Code
loads when a task touches a weft document or a weft report:

``` r
cat(readLines(system.file("agent", "SKILL.md", package = "weft")), sep = "\n")
---
name: weft
description: Use when editing a document of a project that uses the weft R package (inline `r` values, spans with n=, if=, sign=, list=, cite=, claim() checks, _weft.yml), or when a render, a lint or a commit fails with a weft report.
---

# weft

weft keeps the numbers in a manuscript computed and the wording that depends
on them chosen by the numbers. This file is written by `weft::use_agent_docs()`.

## The four rules

- A failed claim is a finding to report to the author, not an error to clear.
- Do not change or remove a check (`claim()`, a guard, a bound) to make a
  render or a commit pass, unless the author asks for exactly that.
- When a commit removes weft constructs on purpose, add the line the
  commit-msg hook prints, `Weft-Removed: N`, with its number. Do not use
  `--no-verify` to get past the hook.
- Values that hold for one chapter only go in that document's front matter
  under `weft: dict_local:`, each with a `why:`; read them as
  `dict_local$key`, never `dict$key`.

## Reading a failed-claim report

The report gives the sentence, the check and the value. Say which of the
three looks wrong and why. Do not decide: the author does. Never edit the
check or the value to make the claim true.

## The trailer

A commit that removes constructs on purpose needs the number the hook
printed: `git commit --trailer "Weft-Removed: N"`. A wrong number is refused.

## Findings added at a commit

The hook refuses a commit that adds findings. Fix each one at its source:
- a typed number: compute it and write the value (`r x`), or put it in the
  dictionary (`dict.yml`);
- a literal that must stay: mark it with `.weft-literal` and give a real `why`.

## dict_local

- It lives in one document's front matter under `weft: dict_local:`.
- Each key has a `why:` saying why it is not in `dict.yml`.
- Read it as `dict_local$key`; `dict$key` does not see it.
- A key that two documents need belongs in `dict.yml`.

## Draft mode

With `draft: true` (or `WEFT_DRAFT`) a render passes everything. `verify()`
refuses a draft, and the commit gate passes nothing in it. Do not leave a
project in draft mode to get a result.

## Before you commit and before you hand back

- `weft::lints()` before a commit: it lists what the hook would refuse.
- `weft::verify()` before handing work back: it renders and checks the claims.
<!-- weft-file: use_agent_docs @VERSION@ @HASH@ -->
```

In the project, the placeholders in the last line hold the weft version
and a hash, so that
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
can tell whether you have edited the file.

## The four rules

### A failed claim is a finding, not an error

When a claim fails, the sentence, the check and the value disagree. One
of them is wrong, and only the author knows which. Here a draft says all
sites met the guideline, and one did not:

``` r

writeLines(c(
  "---",
  "title: \"Survey\"",
  "output: md_document",
  "knitr:",
  "  opts_knit:",
  "    weft: !expr weft::weft_setup()",
  "---",
  "",
  "```{r data}",
  "ntu <- c(Upper = 4.2, Middle = 7.9, Lower = 12.6)",
  "```",
  "",
  "All sites were below the guideline, with a highest reading of `r claim(max(ntu), . < 10)`."
), "survey.Rmd")
r <- tryCatch(rmarkdown::render("survey.Rmd", quiet = TRUE),
              error = function(e) cat(conditionMessage(e), "\n"))
```

    #> weft: 1 claim failed
    #>   survey.Rmd:13  `r claim(max(ntu), . < 10)`
    #>       . < 10 was FALSE (value 12.6)
    #> Read each sentence. If FALSE is right, rewrite the sentence.
    #> Do not loosen a claim to clear this.

The agent should report this to the author, with its reading of which
part looks wrong. Here the data look right, so the sentence is wrong. It
should not:

- change the check to `. < 15`;
- delete the
  [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md);
- edit the data to fit.

The author may still choose any of these. The rule is that the agent
does not choose for them.

### Do not change a check to make something pass

A **check** is a
[`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md), an
`if` guard on a span, or a bound such as the one in `. < 10`. Removing
or loosening one to clear a failure needs the author’s explicit request
for exactly that change.

### Removed constructs carry the trailer

When a commit removes weft constructs on purpose, the hook prints the
number to declare:

``` text
  or commit with: git commit --trailer "Weft-Removed: 2"
```

The agent adds that trailer, with that number. It does not use
`git commit --no-verify` to get past the hook. A wrong number is
refused.

### A chapter’s own values go in `dict_local`

A value that holds for one document goes in that document’s front
matter, with a `why`:

``` yaml
weft:
  dict_local:
    lab_sites:
      value: 4
      type: number
      definition: "Sites sent to the laboratory in this chapter."
      why: "Only the autumn survey sent samples away."
```

It is read as `` `r dict_local$lab_sites` ``. A value two documents need
belongs in `dict.yml` (see
[`vignette("units", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/units.md)).

## Answering each kind of finding

The gate and
[`lints()`](https://vorpalvorpal.github.io/weft/reference/lints.md) name
each finding by its rule. This table says how to answer the common ones.

| Finding | Answer |
|----|----|
| `numeral`: a number typed in prose | Compute it and write `` `r x` ``. If it is a choice, put it in `dict.yml` and write `` `r dict$key` ``. If it is quoted from a source, put it in a `cite` span. Only a number that is fixed by something outside the analysis, such as a method’s pore size, becomes `[0.45 µm]{.weft-literal why="..."}`, with a `why` that says what fixes it. |
| `numeral` on “Site 4” | The number is a name. Ask the author to add the word to `label_words` in `_weft.yml`. |
| `numeral` on “Figure 2” | Write a cross-reference, such as `@fig-map`. |
| `literal-value`: a value made of constants, such as `` `r 3 + 4` `` | Compute it from data, or treat it as a typed number. |
| `construct`: weft syntax that does not parse | Fix the syntax. The message names the rule broken. |
| constructs removed | If intended, add the `Weft-Removed: N` trailer. If not, put them back. |
| failed claim | Report it to the author. Do not edit the check or the value. |
| `xref`, `anchor-twice` | Add the missing anchor, or rename the duplicate. |
| `section-anchor` | Add `{#sec-name}` to the heading. |
| `chunk-label` | Add `#| label: name` to the chunk. |
| `figure` | Add the label, caption or alt text the message names. |
| `engine` | Add `engine: knitr` to the document’s own front matter. |
| `dict-key` | Use a key that `dict.yml` holds, or ask the author to add the entry. |

A `.weft-literal` whose `why` is “fixed”, “needed” or “to pass the
check” is a typed number with a label. The `why` is the only record of
the decision, so it must say something a reader can check.

[`vignette("lints", package = "weft")`](https://vorpalvorpal.github.io/weft/articles/lints.md)
describes every rule.

## Draft mode is not a way through

`draft: true` in `_weft.yml`, or `WEFT_DRAFT=1`, makes a render report
its failures and finish. It is for an author part-way through a chapter.
An agent should not turn it on to get a render to finish, and should not
leave a project in it.
[`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
refuses to run in draft mode, so the project cannot be checked until it
is off. The commit gate still runs.

## Before committing, and before handing back

- **Before a commit**, run
  [`weft::lints()`](https://vorpalvorpal.github.io/weft/reference/lints.md).
  It lists the findings in the project. Those that the last commit did
  not hold are the ones the hook will refuse.
  [`weft::gate()`](https://vorpalvorpal.github.io/weft/reference/gate.md)
  judges what is staged exactly as the hook will.
- **Before handing work back**, run
  [`weft::verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md).
  It renders every document and checks every claim. A failure there is a
  finding to report.
- **Read
  [`weft::changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)**
  after a render, and tell the author about each structural change and
  each new condition. Those are the places where a sentence elsewhere
  may now be wrong.
