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
