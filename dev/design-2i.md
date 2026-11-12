# Package 2i — what the stage 2 trial showed

Report 4 of `dev/field-notes.md` ran both trial documents on stage 2.
This note rules on its findings. Each ruling is testable; the tests are
written from this note and Report 4 before the code. Decisions that
change a rule are in `dev/decisions.md` (58 to 61).

## Built in this package

### Units and printing

- **I1 — Chains of spans (rule 1.5.20).** A run of governed spans with
  nothing between them is one chain. The space before the chain is
  kept when any span of the chain prints, and the space after it
  likewise. `A: [x|]{if="FALSE"}[q|]{if="FALSE"}[y|]{if="TRUE"}.`
  prints `A: y.`. A chain in which nothing prints is treated as one
  empty span is now.
- **I2 — `u()` takes a missing logical.** `u(NA, mm)` is a missing
  quantity and `u(logical(0), mm)` an empty one. `TRUE` and `FALSE`
  are refused as before.
- **I3 — A bare quantity (rule 4.4.10, decision 58).** `` `r q` `` with
  no class or key still prints as stock knitr prints it, without the
  unit, and now raises one `weft_unit_warning` for the construct: the
  value is a quantity, its unit is not printed, add `{.num}` to print
  it or `{.nounit}` to say the unit is not wanted. `{.nounit}` alone
  prints the number with weft's formatting and no warning.
- **I4 — A unit name typed after the value (decision 59).** When a
  construct prints a quantity with its unit, and the prose straight
  after it (after white space) is that unit again, as its symbol or
  its name in the singular or plural, the knit raises one
  `weft_unit_warning` naming the word ("5 days days"). The same when
  an arm types the unit after `#`. Nothing is removed.
- **I5 — A project unit with a name and no symbol.** In `units:`, a
  row that gives `name` and no `symbol` has no symbol (as
  `symbol: false`): it prints by name in every form. A row with
  neither prints its key, as before.
- **I6 — `grade`** joins the misread list (udunits reads it as an
  angle, the gon); the advice names a project unit.
- **I7 — A token is kept as typed inside a compound.** `mm/hr` prints
  `mm/hr`, not `mm/h` (4.4.20).
- **I8 — `.pct` on a quantity in per cent.** Still a value error; the
  message says the unit already prints "%", so drop `.pct`.
- **I9 — Zero on a ladder.** A lone zero takes the rung of the unit
  the quantity is held in when that unit is on the ladder, else the
  first rung. In a vector the vector rule decides, as before.

### The ledger and `changes()`

- **I10 — `ledger: false`** in `_weft.yml` (or the document's `weft:`
  front matter) turns the ledger and the condition log off; the
  default is on in a set-up project. So a project can keep `units:`
  rows in `_weft.yml` without a ledger.
- **I11 — "crosses 1.0"** is a reason only for an entry whose `unit`
  is null on both sides (a ratio or a count), not for a quantity.
- **I12 — Claim words.** Number words (`one` to `twelve`, `first`,
  `second`, `third`) leave the interim list.
- **I13 — An arm that prints nothing.** In the print of `changes()`,
  an entry whose text is `""` shows `(prints nothing)` as its text,
  not a neighbouring sentence.
- **I14 — `print(x, brief = TRUE)`** for a `weft_changes` object
  prints the header line, the structural changes, the not re-rendered
  ledgers and the new conditions, and nothing else.

### Reads (built with the 2e-1 review fixes)

- **I15 — The setup chunk.** The code of the chunk that calls
  `weft_setup()` is walked for reads like any other chunk's.
- **I16 — A reader of the author's.** A function in the knit's
  environment whose body passes one of its own arguments as the name
  to `tar_read()`, `tar_read_raw()`, `tar_load()` or `tar_load_raw()`
  is a reader: a call of it with a literal name (a symbol or a
  string) is a read of that target, from the store its body gives
  (evaluated as the review ruling 5 says, so `here::here("_targets")`
  works). `tr <- function(name) tar_read_raw(name, store =
  here::here("_targets"))` then `tr("fit")` records `fit`.

## Not built: for Robin, in `dev/open-findings.md`

- A quantity compared or added to a bare number outside `claim()`
  fails with the `units` package's own message (4.4.5). weft cannot
  change that operator; the twins it leads to are a drift risk.
- Constructs inside an arm no longer chosen are listed as removed.
- A weft failure in a report rendered by `tar_quarto()` reaches
  `tar_make()` as "quarto CLI failed".
- `dict[[k]]` with a variable key reads every entry, so it re-runs on
  any edit.
- `dict_seed()` does not see literals typed inline or constants that
  are targets.
- No range or vector type in the dictionary; no glossary of the
  entries one chapter uses; `space:` is one setting per unit.
- A threshold used only in code is not seen by "crosses a dictionary
  threshold".
- `weft_setup()` costs about 2.3 s a render: taken up separately as a
  performance task, with no change of behaviour.
