# Write the agent documents: an AGENTS.md block and a Claude skill

Writes, under the project root, `.claude/skills/weft/SKILL.md` and a
block in `AGENTS.md` (created when absent) that tell a coding agent the
rules of a weft project: a failed claim is a finding to report, a check
is never changed to make a render pass, a commit that removes constructs
carries the `Weft-Removed` trailer, and values for one chapter go in
`dict_local`.

## Usage

``` r
use_agent_docs(path = ".", overwrite = FALSE)
```

## Arguments

- path:

  A directory in the project.

- overwrite:

  Replace a block or skill weft wrote that has since been edited.

## Value

The paths written, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing
changed).

## Details

The block sits between `<!-- weft:start ... -->` and `<!-- weft:end -->`
lines, appended after the file's last line with one blank line before
it; the rest of the file is never touched. The start line and the
skill's last line carry the weft version and a hash. A block or skill
weft wrote and nobody edited is replaced when its text would differ; an
edited one is left as it is unless `overwrite = TRUE`; a `SKILL.md` with
no weft line is another author's and is never replaced. When `CLAUDE.md`
exists and does not hold `@AGENTS.md`, the call says to add that line.
It says what it will write first.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.
