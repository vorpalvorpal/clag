# weft against a long report's own integrity system

A survey of the home-grown system one long computational report built to keep its
manuscript correct, mapped against weft. It prepares the item-3 trial ("run weft on some of
the long-report material"); the trial itself is a separate run. The detailed survey, with
paths and counts, is git-ignored under `dev/trials/`. This file names no data values,
people, places or manuscript text.

## The project, in general terms

- A Quarto book of about twenty chapters plus an executive summary and an appendix, about
  43,000 source lines, rendered to PDF (LaTeX) and HTML. It has several thousand inline R
  values, a few thousand numerals still typed in prose, and several hundred table
  cross-references.
- A `targets` pipeline holds every model fit and every value that more than one chapter
  uses. The chapters are not targets. Each chapter reads the store through a small wrapper
  function, with the store path in a variable.
- There is no git hook, no CI and no prose linter. Every check is a script that someone
  runs by hand, and the results go into commit trailers as free text.
- An audit by people and agents raised about 870 findings. Many of the mechanisms below
  were built after a finding to stop that class of defect coming back.
- The project's own integrity plan was the design ancestor of weft. Its layers L1 to L12
  map to weft's sections (§11 of the scoping document). Its L13, checks on the rendered
  output, was added later and has no counterpart in weft.

## The mapping

**SUP** means weft does it fully. **PART** means weft does part of it. **NOT** means weft
does nothing comparable.

| Mechanism in the project | Verdict | weft feature, or what is missing |
|---|---|---|
| A written rule that a number in prose is computed, never typed; never computed when it is quoted from a source; and computing it stops drift but does not make it right | **SUP** as enforcement | `numeral` lint and the commit gate, which refuse only new typed numbers; `verify()` counts the ones that remain, and `strict` is the end state. `cite` spans mark numbers quoted from a source, which the project has no way to mark. `.weft-literal why=` covers fixed numbers. The "not right" half is `claim()`. Migration: install the gate, then let the tolerated count fall. |
| Formatting helpers pasted into every chapter: fixed decimals, percentages with a precision rule, p-values, spelled small numbers, sentence case, joined lists, thousands marks, signed-zero removal. About 20 copies of each, and the copies have drifted. | **SUP** mostly | `.num digits=`, `.pct`, `.p`, `.count` with `count_threshold: 11`, `.no`, `.cap`, `.and` with `serial_comma: true`, `.range`, `ci()`, the zero rule, `thousands_from`, and a project formatter for the percentage rule. **Missing:** an explicit plus sign (a couple of hundred signed estimates and intervals use one); `digits` and a label (q) for `.p`; a short form of `ci()` without the level text. Helpers that return strings have to give way to numbers. |
| Several hundred `stopifnot()` guards in chunks, each asserting that the value still bears out the wording beside it: direction, an interval covering zero, a count, "the most" | **SUP** in prose, **PART** in chunks | A `claim()` in the sentence is collected, and its failure quotes the sentence. `sign` and `if` spans replace typed direction words together with the guards on their sign. **Missing:** a failed claim in chunk code still stops at once. The project's worst recorded trap was "the first failing guard hides every guard below it", and that trap survives conversion unless the guards move into prose. |
| Tolerance pins on typed numbers | **SUP** | Print the value instead, or use `claim()`. |
| A rule that turns a value into a word ("about a half"). It is defined in one chapter and re-asserted, with a copy of the rule, in two synthesis chapters. | **SUP** | A `breaks` dictionary entry read by all three, plus `about()`. |
| A list of what is still typed in the synthesis chapter, which generates a paragraph about itself | **SUP** | `.weft-literal why=`, the lint listing and the tolerated count. |
| Tagged code comments ("load-bearing", "superseded", "voice") that record why prose must not change | **NOT** | A convention. Stays with the project. `claim()` mechanises the value half. |
| Values used across chapters are pipeline targets, and the summaries read them | **PART** | The ledger records the targets a document read, and its not-re-rendered check spans chapters, provided the wrapper read is recorded. The trial must confirm this, because the stage-2 trial found it unrecorded. Cross-chapter `#id` is not allowed (1.7.10). |
| Captions and alt text computed by `!expr` chunk options built with `paste`, some 30 lines long. A rule about two YAML traps in those options. | **PART** | Constructs in block-scalar captions are resolved after the chunk runs, which avoids both traps. Migration is heavy: the code moves into the chunk. `!expr` stays out of scope. |
| One table helper that builds every table and takes a caption string and an id; prose refers to the id | **PART** | `weft_str()` on the caption. **Missing:** the lints cannot see captions or anchors made in R. `xref` is likely to flag every reference to such a table, and `table-caption` is blind. |
| A whole-book cross-reference scanner: dangling and duplicate ids, a usage inventory, and whether each use renders | **SUP** for the checks (`xref`, `anchor-twice`, `cite-key`, `xref-code`, `anchor-unused`, `section-anchor`, `chunk-label`); **PART** for the inventory | Anchors made by a helper, as above. weft has no CSV inventory. |
| Label vectors (tier names, factor names) redefined in up to six places | **SUP** | `labels` dictionary entries; `tar_dict()` for the copy in the pipeline. |
| Published threshold tables (bands with open and closed bounds) kept as an R data object | **PART** | `breaks` covers a one-dimensional ladder. **Missing:** range, vector and table types, also asked for in Report 4. |
| Constants typed in many files (a window, a threshold) | **SUP** | `dict.yml` and `tar_dict()`. `dict_seed()` missed them in Report 4. |
| Typed units, with inconsistent spellings | **SUP** in principle | Quantities, `dict_vale()`. In this book the gain is small and the friction from count nouns is real. |
| A knit-and-grep checker. It knits each chapter with errors fatal, reads the output back, and greps for warnings, errors, singular-fit messages and convergence messages, because those reach the document and are never seen. | **SUP** | The condition hook logs every condition even under `warning: false`. `severity` patterns fail the render (add the lme4 and glmmTMB convergence patterns). A committed condition log is diffed in `changes()`. `verify(files=)`. The project's checker stays the faster inner loop until `verify(files=)` is timed on these chapters. |
| Two scripts: a kept knit baseline, and projections of the prose and every number from it, diffed between versions. They see numbers in tables. | **SUP** for constructs, **PART** overall | The ledger and `changes()` (structural first, ranked, new conditions, not re-rendered). **Missing:** numbers in tables and in typed prose are not in the ledger. |
| A hand-kept log of where each changed value had to be carried | **PART** | `changes()` lists every entry a render changed. The log itself stays with the project. |
| A decision log, decision and finding ids cited in hundreds of source comments, and a "do not fix" list keyed to locations | **PART** | `decision:` pointers on dictionary entries, with a resolver checked by `verify()`. **Missing:** pointers on anything else, such as a `.weft-literal`, a claim or a caption. |
| Audit registers, a status vocabulary, and tools that count findings and check the counts stated in headers | **NOT**, by design (§16, "Keep registers") | Stays with the project. |
| A client question list held in per-chapter YAML and printed into chapters with `results: asis`. Its typed numbers carry pins: the words, an R expression, the expected value and a tolerance, all checked on every render. | **PART** | `weft_str()`, or a named value with `weft_put()`, makes that text computable, so a pin can become a value. weft has no "typed but checked" text construct. |
| Hand-run typesetting gates on the LaTeX log, the `.tex` and the PDF: overfull boxes, longtable orphans and caption paths | **NOT** | Outside weft's scope. Stays with the project. |
| No `freeze`, on purpose: freeze keys on the source only and cannot see the pipeline | **PART** | Stamps, a post-render report of documents served from freeze, and ledger input hashes. **Missing:** failing a document served from freeze when the targets or dictionary entries it read have changed. |
| Planned rendered-output checks: no `NA`, raw markup or unresolved reference in the output; xref numbering the same in HTML and PDF; alt text present; deploy inventory | **PART** | `weft-check` fails on raw inline R, leftover constructs and draft markers, and formatted missing values fail. **Missing:** a bare value that prints `NA`, unresolved Quarto references, parity between formats, and checks on the output alt text and inventory. |
| Long agent rules: git hygiene for a shared index, number rules, recommendation etiquette, delegation, measured costs and named traps | **PART** | `use_agent_docs()` covers the four weft rules. The rest stays with the project. The project needs a `CLAUDE.md` that includes `AGENTS.md`. |
| Commit-message conventions: four competing id prefixes and free-text "gates" trailers | **PART** | The gate enforces `Weft-Removed:`. The rest is out of scope. |

### What weft would add here

- The project has no counterpart for:
  - a commit gate and CI, where today every check is run by hand;
  - accounting for removed checks;
  - a structured ledger and a committed condition log;
  - detection of stale renders;
  - value-dependent wording;
  - claims that are collected and quote their sentence.
- `ci()` refuses an estimate outside its own interval. The project's rules record that
  defect being published after the number had been made computed.
- `about()` refuses a gloss that is out of tolerance.
- A dictionary with a glossary and Vale terms.
- `cite` spans, so a number quoted from a source is marked as quoted rather than only
  remembered.
- `verify()` and `status()` as one entry point, where today there are about ten scripts.

### Where weft's way would be worse here

- **Setup:** every chapter needs an edit to its front matter, and `weft_setup()` costs about
  2 to 3 seconds per chapter.
- **House style:**
  - it needs several settings and a project formatter;
  - signed estimates have no clean form;
  - `.p` prints its own "p =", so every conversion deletes typed text.
- **Units:** count nouns cost more than they give.
- **Ledger churn:**
  - about 70 KB per chapter is rewritten on each render commit;
  - a sentence edit rewrites every entry in that sentence;
  - tables, which hold most of the book's numbers, are invisible to the ledger.
- **`claim-word` noise:** at this density it flagged about two thirds of the sentences in
  stage 0.
- **Forward references:** weft needs a definition moved above its first use, and the
  project's rules forbid moving a chunk.
- **Lint time:** the lints ran for about 80 s over the whole book in stage 0. The gate lints
  only changed files, but `xref` reads the whole project.

## Candidate improvements to weft, ranked

### OBVIOUS WIN: small, general, low risk

1. **A bare value that prints `NA`, `NaN` or `Inf` becomes a warned check.**
   - Bare values are already recorded, so the hook sees what they print.
   - It closes the "published `NA`" class for the thousands of values a project will not
     convert soon.
   - A warned check never fails a render.
2. **The `xref` lint learns anchors that a helper makes.**
   - A `_weft.yml` setting would name the function, its argument and the prefix, for
     example `anchor_calls: [{fun: tbl, arg: id, prefix: "tbl-"}]`.
   - The lint would then read literal arguments from chunk code.
   - Building tables with a helper is common in books, and without this the rule is unusable
     on them.
3. **An explicit plus sign for `.num`, `.pct`, `.range` and `ci()`, and a short form of
   `ci()`.**
   - The plus sign would be a key or a setting. The short form, "est (lo to hi)", leaves
     out the level text.
   - Signed estimates are standard in statistics reports.
   - It needs parity in the Lua filter.
4. **`digits` and a label (`q`) for `.p`.** House styles differ (three decimals always, or
   q-values), and the `.p` class otherwise forces either a project formatter or a bare
   helper.
5. **The `severity` defaults, or a documented recipe, for mixed-model convergence
   messages.**
   - The messages are lme4's "failed to converge" and convergence-code messages, and
     glmmTMB's "false convergence" messages.
   - Recommendation: a documented recipe first. Changing what fails by default is
     riskier.
6. **A document served from freeze whose ledger inputs have changed is reported, and fails
   under `verify()`.**
   - The stamps and the ledger header hashes already exist.
   - This is the check that makes `freeze: auto` safe on a `targets` project, which this
     project names as its condition for using freeze.
7. **An adoption recipe for an existing statistics report, as documentation.**
   - Settings: `serial_comma`, `count_threshold: 11`, `numeral_years`, `label_words`.
   - A percentage-rule project formatter.
   - `severity` patterns.
   - Mapping helpers to classes.
   - `@AGENTS.md` in `CLAUDE.md`.

### MAJOR: design change or new surface, to raise with the owner

**A. Claims in chunk code: collect, or stop at once?**

- The project's worst trap was that one failing guard hides the guards below it. weft keeps
  that trap for chunk code (2.4.2).
- Options:
  - (i) Keep it.
  - (ii) A setting under which, during a knit, a failed `claim()` in a chunk is recorded
    and returns its value, and the render fails at the end.
  - (iii) A `claims()` block that evaluates every check before stopping.
- **Recommendation:** (ii) as an opt-in setting. The render still fails, and the author sees
  every failure at once.

**B. Forward references for named values.**

- An executive summary or a chapter's opening paragraph cites values computed later. Today
  weft needs the definition moved up.
- Options:
  - (i) Leave it.
  - (ii) The resolver falls back to a name's value at the end of the document when the name
    takes exactly one value in that document. A name that takes several values is a
    construct error.
- **Recommendation:** (ii). It is the one general fix that does not move code, and the hooks
  already publish at the end of the document.

**C. Tables in the ledger.**

- Most of a statistics report's numbers sit in tables, and `changes()` cannot see them.
- Options:
  - (i) None.
  - (ii) Record a digest of each chunk's printed table or asis output, so that `changes()`
    reports "table X changed".
  - (iii) Record the numbers of each table, cell by cell.
- **Recommendation:** (ii). It is cheap and gives most of the value. (iii) multiplies
  ledger churn.

**D. A rendered-output layer, L13.**

- Candidate checks:
  - an unresolved cross-reference left in the output;
  - a literal `NA`;
  - leftover markup;
  - alt text that is present and is not the caption;
  - xref numbering that matches between formats;
  - a deploy inventory.
- **Recommendation:**
  - Fold the first three into the post-render script and `verify()`'s render part. They are
    small and general.
  - Leave the format parity, the inventory and all typesetting checks to projects, or to a
    separate package.

**E. Decision pointers beyond the dictionary.**

- A `decision=` key would go on `.weft-literal`, `cite` and claims, and `verify()` would
  resolve it with the existing resolver.
- **Recommendation:** yes, for the key.
- Scanning source comments for decision ids would be possible, but it would add a register
  convention to weft, which §16 excludes. Recommendation: no.

**F. Typed but checked text.**

- The project pins numbers in text that cannot run code.
- Options:
  - (i) A construct for a pinned literal.
  - (ii) Document the `weft_str()` and `weft_put()` route, which makes such text computed
    instead.
- **Recommendation:** (ii). It needs no new construct.

**G. Range, vector and table types in the dictionary.**

- **Recommendation:** a `range` type, yes. Threshold tables stay as R data.

**H. Generating registers from commit trailers** (`Decision:`, `Closes:`).

- **Recommendation:** no. It is out of scope by §16, and belongs in a separate tool.

## What should stay with the project

- The audit corpus, the status vocabulary and the register tools.
- The decision, propagation, recommendation and judgement logs, and the "do not fix" list.
  The `decision:` pointers can point at them.
- The client question list: its content, ranking and validation.
- The data-layer provenance checks for scripts run by hand, and the `targets` design.
- The table helper, the plot theme, and the LaTeX and PDF typesetting gates.
- The review and annotation workflow and the distribution plan.
- The tagged-comment convention, and the agent rules about delegation, the shared git
  index, the targets write lock and measured costs.
- Domain traps: the briefs on data quirks.

## The trial

- The previous trial converted one rating chapter. This one takes three:
  - a small chapter, with targets read through the wrapper and a question list that carries
    pins;
  - the synthesis chapter, which carries cross-chapter values, the shared rule that turns a
    value into a word, and sign assertions;
  - a whole-book static pass of the lints and the gate on copies of the current sources.
- The order and the steps are in the git-ignored survey.
