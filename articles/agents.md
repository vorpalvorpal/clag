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
writes an `AGENTS.md` block and a skill.
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

The weft skill is in the project's skills folders (`.agents/skills/weft/`,
`.claude/skills/weft/`) and has the detail; `weft::agent_docs()` prints it.
```

In the project, the block sits between a `<!-- weft:start ... -->` line
and a `<!-- weft:end -->` line. weft replaces only what lies between
them. Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If the project has
a `CLAUDE.md`, add the line `@AGENTS.md` to it so that it includes the
block.

The second is a skill, `weft/SKILL.md`, which a coding agent loads when
a task touches a weft document or a weft report. It sits in each skills
folder (see the next section), with two files in `references/`,
`syntax.md` and `reports.md`:

``` r
cat(readLines(system.file("agent", "SKILL.md", package = "weft")), sep = "\n")
---
name: weft
description: Use when editing a document of a project that uses the weft R package (inline `r` values, spans with n=, if=, sign=, list=, cite=, claim() checks, _weft.yml), or when a render, a lint or a commit fails with a weft report.
metadata:
  weft-version: "@VERSION@"
---

# weft

weft keeps the numbers in a manuscript computed and the wording that depends
on them chosen by the numbers. This file is written by `weft::use_agent_docs()`.

## References

`references/syntax.md` has the constructs, one example each; `references/reports.md`
shows how to read a failed render, a lint report and a refused commit.
`weft::agent_docs()` lists them, and `Rscript -e "weft::agent_docs('syntax')"` (or
`'reports'`) prints the installed package's version of each; it wins if the copy
here is older.

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

The report gives the line, the expression, the check and the value. Say
which of the check and the value looks wrong and why. Do not decide: the author does. Never edit the
check or the value to make the claim true.

## The trailer

A removal on purpose needs the hook's number: `git commit --trailer "Weft-Removed: N"`.
A wrong number is refused.

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
refuses a draft, and the commit gate ignores it and judges every commit as
usual. Do not leave a project in draft mode to get a result.

## Before you commit and before you hand back

- `weft::lints()` before a commit: it lists every finding. `weft::gate()`
  judges the staged commit as the hook does.
- `weft::verify()` before handing work back: it renders and checks the claims.
<!-- weft-file: use_agent_docs @VERSION@ @HASH@ -->
```

In the project, the placeholders (the version in `metadata` and the last
line, and the hash) hold the weft version and a hash, so that
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
can tell whether you have edited the file.

## Which tools read which folder: `skills`

The skill format is the same for every tool; the tools differ in the
folder they scan. `use_agent_docs(skills = )` takes preset names or
folders relative to the project root, and writes the same files into
each:

| preset | folder | read by |
|----|----|----|
| `agents` | `.agents/skills` | Gemini CLI; reported for Codex, opencode and Cursor |
| `claude` | `.claude/skills` | Claude Code |
| `codex` | `.agents/skills` | reported for Codex |
| `gemini` | `.gemini/skills` | Gemini CLI |
| `opencode` | `.opencode/skills` | reported for opencode |
| `kimi` | `.kimi-code/skills` | Kimi Code |
| `cursor` | `.cursor/skills` | reported for Cursor |

The default is `"agents"`, which writes `.agents/skills` alone. **Claude
Code reads `.claude/skills/` and not `.agents/skills/`**, so Claude Code
users pass `skills = c("agents", "claude")`, or install the plugin with
`/plugin marketplace add vorpalvorpal/weft`. A `.claude/skills/weft`
copy that an earlier weft wrote is left as it is by the default call;
the closing message says that it was not updated and gives that call to
update it, and
[`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
names it. That Codex, opencode and Cursor read `.agents/skills` is
reported by secondary sources; it was not checked against the vendors’
documents. A folder of your own is a path such as `"tools/skills"`; an
absolute path or one with `..` is an error. `skills = character()`
writes only the `AGENTS.md` block. Gemini CLI reads `GEMINI.md`, so if
the project has one, add the line `@AGENTS.md` to it; the call says so.

The copies in a project can be older than the installed package.
[`weft::agent_docs()`](https://vorpalvorpal.github.io/weft/reference/agent_docs.md)
lists the documents and `weft::agent_docs("syntax")` prints the
installed version of one.

## Installing the skill without a project

To give the skill to Claude Code for yourself, in every project, install
the plugin from the GitHub repository. In a Claude Code session:

``` text
/plugin marketplace add vorpalvorpal/weft
/plugin install weft@weft
```

or in one step, on Claude Code 2.1.275 or later:

``` text
/plugin install weft --marketplace vorpalvorpal/weft
```

From a shell, `claude plugin marketplace add vorpalvorpal/weft` then
`claude plugin install weft@weft` do the same. Cross-tool installers
that read a `skills/<name>/SKILL.md` folder from a repository can read
`skills/weft/` from `vorpalvorpal/weft`.

A copy installed this way belongs to you, not to a project. It is not
updated with the R package, so it can fall behind the installed weft;
update it from Claude Code, or run
[`weft::agent_docs()`](https://vorpalvorpal.github.io/weft/reference/agent_docs.md)
to read the current text. The copy that
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
writes into the project is the one
[`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
checks.

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
