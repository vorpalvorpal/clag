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

The report gives the line, the expression, the check and the value. Say
which of the check and the value looks wrong and why. Do not decide: the author does. Never edit the
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
refuses a draft, and the commit gate ignores it and judges every commit as
usual. Do not leave a project in draft mode to get a result.

## Before you commit and before you hand back

- `weft::lints()` before a commit: it lists every finding. `weft::gate()`
  judges the staged commit as the hook does.
- `weft::verify()` before handing work back: it renders and checks the claims.
<!-- weft-file: use_agent_docs @VERSION@ @HASH@ -->
