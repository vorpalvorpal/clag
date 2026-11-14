# Reading weft reports

What each report looks like, and what to do. Each one is a finding for the
author. The same rule holds for all: never loosen, delete or edit a check, a
value or the data to make a report go away.

## A failed render

```text
weft: 1 claim failed
  survey.Rmd:14  `r claim(max(ntu), . < 10)`
      . < 10 was FALSE (value 12.6)
Read each sentence. If FALSE is right, rewrite the sentence.
Do not loosen a claim to clear this.
```

The line (`survey.Rmd:14`), the expression, the check (`. < 10`) and the value
(`12.6`). Read the sentence the claim sits in. Say which looks wrong, the
sentence or the value, and why. Report it; the author decides. Never change
`10`, delete the `claim()` or edit the data. A report can list several claims;
report all of them.

## lints()

```text
weft lints: 1 finding in 1 file (1 tier 1, 0 tier 2)

survey.Rmd
  15:14  numeral  "3.4" is a number typed in prose (rule 5.2.1).
                  Write it as a value, put it in the dictionary, or mark it [3.4]{.weft-literal why="..."}.
```

Each finding gives `line:column`, the rule name and a hint. Fix it at its
source: compute the number and write the value, put it in `dict.yml`, or, for
a number fixed by something outside the analysis, mark it `.weft-literal` with
a real `why`. Never mark a literal to silence a finding. `lints()` lists every
finding; `gate()` judges the staged commit as the hook does.

## A refused commit

```text
commit-msg: 1 finding added that HEAD did not hold
  survey.Rmd
       15  numeral  "7.2" is a number typed in prose (rule 5.2.1).

commit-msg: 2 weft constructs removed, and the message does not say so

  If the removal is intended, add this line at the end of the commit
  message, after a blank line:

      Weft-Removed: 2

  or commit with: git commit --trailer "Weft-Removed: 2"
```

A finding the commit adds: fix it as for `lints()`, then commit again. A
removal: only if the author asked for it, add the `Weft-Removed: N` trailer
with the number printed. A wrong number is refused. Never use `--no-verify`.

## verify()

```text
weft verify: failed
  lints      1 tolerated finding
  render     quarto exited with status 1; 1 failure, 0 not executed
  ledger     1 ledger checked

Knit-time failures
  report.qmd
       17  failed claim  . < u(50, NTU) was FALSE (value 79 [NTU])
```

`verify()` renders and checks the claims before you hand work back. One line
per stage, then the details. `failed` is not done: report the failures as
above. It refuses a document in draft mode; do not leave one in draft mode to
get a result.

## changes()

```text
weft changes since HEAD (9e34dd7): 1 ledger compared; 2 changed, 0 added, 0 removed; 1 new condition

Structural changes
  ~ report.qmd#sec-sites  n  n_high  [arm one -> zero, crosses 0]
      before: One site read above the trigger of 10 NTU.
      after:  No site read above the trigger of 10 NTU.
```

What the rendered prose says now against what it said at the last commit.
Tell the author any sentence whose meaning changed. It changes nothing.

## checks()

```text
weft checks: 2 checks of 2 values in 1 document; 0 values flagged

survey.Rmd
  max(ntu)
    max(ntu) < 10     1  line 14
```

Every check, with the value it guards and its line. Use it to see what still
checks a number before and after an edit. Do not edit a check to change what
it lists.
