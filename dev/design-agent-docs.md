# Agent documents for more than one tool (14 Nov, after v0.1.0)

## Why

`use_agent_docs()` writes one skill, to `.claude/skills/weft/SKILL.md`,
and a block in `AGENTS.md`. The `SKILL.md` format is now an open one
(agentskills.io): a folder named after the skill holding `SKILL.md` with
`name` and `description` front matter. The tools differ only in the
folder they scan. Claude Code reads `.claude/skills/` and, by its own
documentation, not `.agents/skills/`. Gemini CLI reads `.gemini/skills/`
and `.agents/skills/`; Kimi Code reads `.kimi-code/skills/`; Codex,
opencode and Cursor are reported to read `.agents/skills/` (secondary
sources). So one file in two folders reaches the tools named.

## Alternatives

| route | for | against |
|---|---|---|
| the installer writes copies into the project (chosen, widened) | committed, so collaborators and CI agents get it; matches the project's weft version | one copy per folder |
| the agent reads the documents from the installed package (added, as `agent_docs()`) | always the installed version; no copies | found only by an agent that reads `AGENTS.md` |
| a marketplace folder in the repository | install before any project exists | a per-user copy can drift from the R package; not decided, not in this package of work |
| per-user install by weft | no project copies | writes outside the project |
| tool-specific rule files (`.cursor/rules`, `GEMINI.md`) | richer conditions in Cursor | more copies to keep in step; `AGENTS.md` and a note do the job |

Symbolic links between the copies were rejected: they break on Windows
and in some git set-ups.

## Rules

**AD1. The argument.** `use_agent_docs(path = ".", overwrite = FALSE,
skills = c("agents", "claude"))`. `skills` is a character vector; each
item is a preset name or a folder given relative to the project root.
- Presets: `agents` is `.agents/skills`; `claude` is `.claude/skills`;
  `codex` is `.agents/skills`; `gemini` is `.gemini/skills`; `opencode`
  is `.opencode/skills`; `kimi` is `.kimi-code/skills`; `cursor` is
  `.cursor/skills`.
- An item that holds a `/` or starts with `.` is a folder; a trailing
  `/` is dropped. Any other item that is not a preset is an error that
  lists the presets.
- An absolute path, or one with a `..` part, is an error: the skill is
  written inside the project.
- Items that come to the same folder are written once. The order of
  writing is the order given.
- `skills = character()` writes no skill, only the `AGENTS.md` block.
- `NA`, an empty string or a non-character value is an error.

**AD2. What is written.** For each folder `<dir>`: `<dir>/weft/SKILL.md`
and `<dir>/weft/references/<topic>.md` for each shipped reference
(AD4). The texts are the same in every folder. The `AGENTS.md` block is
written once, as now.

**AD3. Each copy stands alone.** The rules of G34 and G40 apply to each
file of each copy: one weft wrote and nobody edited is replaced when its
text would differ; an edited one is left unless `overwrite = TRUE`; a
file with no weft line is another author's and is never replaced. One
copy being edited does not stop the others being written. The call says
what it will write first, one line per file, and returns the paths
written.

**AD4. The skill is thin; detail comes from the package.** The package
ships `inst/agent/SKILL.md` and `inst/agent/references/*.md`. The first
references are `syntax` (the constructs and classes, one screen) and
`reports` (how to read a failed render, a lint report and a refused
commit, and what to do). `SKILL.md` keeps the four rules and the
workflow, names the references by relative path, and says that
`weft::agent_docs()` prints the installed package's version of each.
Front matter: `name`, `description`, and `metadata` with `weft-version`;
no field that only one tool reads. The last line of every written file
is the weft marker, as now.

**AD5. `agent_docs(topic = NULL)`**, exported. With no topic it prints
the topics, one per line: `skill`, then the references in alphabetical
order, each with a short description. With a topic it prints that
document from the installed package (without the marker line) and
returns the text invisibly. An unknown topic is an error that lists the
topics. It writes nothing.

**AD6. Notes.** As now for `CLAUDE.md` without `@AGENTS.md`. The same
for `GEMINI.md`: when it exists and holds no line importing `AGENTS.md`
(`@AGENTS.md` or `@./AGENTS.md`), the call says to add `@AGENTS.md`.
Neither file is written.

**AD7. `status()` and `use_weft()`.** `status()` looks for a weft skill
in every preset folder and reports the agent documents as current only
when the `AGENTS.md` block and every copy found are current; a stale
copy is named with its folder. A project with no copy at all is as now.
`use_weft()` calls `use_agent_docs()` with the default `skills`.

**AD8. Unchanged.** The `AGENTS.md` block's markers and text handling;
the meaning of `overwrite`; an existing project that holds only
`.claude/skills/weft/SKILL.md` gains the `.agents/skills` copy at the
next `use_agent_docs()`.

## Marketplace folder (built 14 Nov)

Built: a generated `skills/weft/` at the repository root (`SKILL.md`,
`references/syntax.md`, `references/reports.md`: the shipped documents
with `@VERSION@` filled and no `weft-file` marker, as the copy is not one
`use_agent_docs()` wrote); `.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`; the internal `agent_repo_skill(dir)`
in `R/use-agent-docs.R`; `dev/make-skill-folder.R`, run at each release,
which also sets the version in both manifests. `^skills$` and
`^\.claude-plugin$` are in `.Rbuildignore`. A test fails when the
committed folder or the manifest versions differ from the generator.

Layout: the repository root is the plugin, and the marketplace's one
entry has `"source": "./"`. The Claude Code documentation supports a
plugin at the marketplace root ("`./`" in the marketplace reference), and
a plugin's default `skills/` directory is `skills/<name>/SKILL.md`, so the
same `skills/weft/` serves the Agent Skills installers and the plugin,
with no second copy to drift. Install id: `weft@weft`. Cost: Claude Code
copies the whole repository into its plugin cache.
