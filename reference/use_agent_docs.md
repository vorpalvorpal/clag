# Write the agent documents: an AGENTS.md block and a skill

Writes, under the project root, a block in `AGENTS.md` (created when
absent) and the weft skill, that tell a coding agent the rules of a weft
project: a failed claim is a finding to report, a check is never changed
to make a render pass, a commit that removes constructs carries the
`Weft-Removed` trailer, and values for one chapter go in `dict_local`.

## Usage

``` r
use_agent_docs(path = ".", overwrite = FALSE, skills = "agents")
```

## Arguments

- path:

  A directory in the project.

- overwrite:

  Replace a block or skill file weft wrote that has since been edited.

- skills:

  The skills folders to write into: a character vector of preset names
  or folders relative to the project root. The default, `"agents"`,
  writes `.agents/skills` alone. Claude Code reads `.claude/skills` and
  not `.agents/skills`, so Claude Code users pass
  `skills = c("agents", "claude")`, or install the plugin with
  `/plugin marketplace add vorpalvorpal/weft`. The presets are `agents`
  (`.agents/skills`), `claude` (`.claude/skills`), `codex`
  (`.agents/skills`), `gemini` (`.gemini/skills`), `opencode`
  (`.opencode/skills`), `kimi` (`.kimi-code/skills`) and `cursor`
  (`.cursor/skills`). An item with a `/` or starting with `.` is a
  folder; an absolute path or one with a `..` part is an error. Folders
  that come to the same place are written once.
  [`character()`](https://rdrr.io/r/base/character.html) writes the
  `AGENTS.md` block only. A weft-written copy in a preset folder that is
  not named, and is older than this weft, is not touched; the call says
  so and how to update it.

## Value

The paths written, invisibly
([`character()`](https://rdrr.io/r/base/character.html) when nothing
changed): `AGENTS.md` first, then the skill files folder by folder in
the order given.

## Details

The skill is `<folder>/weft/SKILL.md` with `references/syntax.md` and
`references/reports.md` beside it, written into each skills folder named
by `skills`. The same texts go into every folder.
[`agent_docs()`](https://vorpalvorpal.github.io/weft/reference/agent_docs.md)
prints the installed package's version of each.

The `AGENTS.md` block sits between `<!-- weft:start ... -->` and
`<!-- weft:end -->` lines, appended after the file's last line with one
blank line before it; the rest of the file is never touched. The start
line and the last line of each skill file carry the weft version and a
hash. Each file is judged alone: one weft wrote and nobody edited is
replaced when its text would differ; an edited one is left as it is
unless `overwrite = TRUE`; a file with no weft line is another author's
and is never replaced. One copy being edited does not stop the others
being written.

When `CLAUDE.md` exists and does not hold `@AGENTS.md`, or `GEMINI.md`
exists and holds neither `@AGENTS.md` nor `@./AGENTS.md`, the call says
to add that line; neither file is written. It says what it will write
first. [`suppressMessages()`](https://rdrr.io/r/base/message.html)
silences it.
