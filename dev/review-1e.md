# Review of stage 1e: `arms()` and `rehearse()`

Snapshot `snap-e` (git archive of 5ccf00e), loaded with `pkgload::load_all()`.
Each finding below was reproduced by a document I ran. "Doc" lines show the
relevant source lines only. Every document below except the one in finding 10
activates weft with a setup chunk (`weft::weft_setup()`).

## Findings

1. **A chunk cached before `weft_setup()` is cached in the project and served to later cases.**
   Severity: wrong output (it also writes to the project silently).
   Doc `c.Rmd`, with `params: k: 1`:
   ```` 
   ```{r data, cache=TRUE, include=FALSE}
   n <- params$k
   ```
   ```{r setup, include=FALSE}
   weft::weft_setup()
   ```
   Found [one site | # sites]{n="n"}.
   ````
   Call: `rehearse("c.Rmd", list(one = list(k = 1), five = list(k = 5)))`.
   Observed: case `five` chose arm 1 ("one site"), because the cache case `one`
   wrote was served to it. `cache/__packages` and `cache/data_*.{RData,rdb,rdx}`
   are left in the document's folder. The same thing happens when the setup
   chunk itself has `cache=TRUE`, or when `knitr::opts_chunk$set(cache = TRUE)`
   runs in a chunk before the setup chunk.
   Expected: case `five` chooses arm 2, and nothing is written. Breaks 3.7.2
   and the contract line "uses no chunk cache (`cache = FALSE` is forced, so no
   cache directory appears)". The force lives only in the `label` opts hook,
   which `weft_setup()` installs. The document's own options override
   `opts_chunk$set(cache = FALSE)` in `rehearse_child()`.

2. **When one line holds the same span twice, a choice is credited to the wrong span.**
   Severity: wrong output.
   Doc, line 17: `Dup [A [x | y]{if="flag"} | B [x | y]{if="flag"}]{if="n > 1"}.`
   with `n <- params$count` and `flag <- params$flag`.
   Call: `rehearse(p, list(one = list(count = 1, flag = FALSE)))`.
   Observed: `chosen` gives span 3 (the inner span in arm A) arm 2. Span 4 (the
   inner span in arm B) is listed as unreached and as "no case evaluated", and
   `chosen` also gives span 2 arm 2 (B). The result contradicts itself: a span
   nested in an arm that was never chosen is shown as evaluated.
   Expected: span 4 arm 2, with span 3 unevaluated. Breaks 3.7.3 ("the arm each
   governed span chose"). `rehearse_chosen()` maps the n-th record with a given
   key to the n-th span in document order. That holds only when every
   duplicate is evaluated.

3. **Caption spans are matched by option, not by chunk, so a chunk that does not run shifts the match.**
   Severity: wrong output.
   Doc, with `params: show: true`:
   ```` 
   ```{r c1, eval=params$show, echo=FALSE, fig.cap='Cap [one | many]{n="d"}'}   # line 24
   ```{r c2, echo=FALSE, fig.cap='Cap [one | many]{n="d"}'}                     # line 28
   ````
   Call: `rehearse(p, list(hide = list(d = 3, show = FALSE)))`.
   Observed: `chosen` has line 24 arm 2. The same case's failures say
   `z.Rmd:24 [unevaluated] a n construct`, and line 28, the caption that did
   run, is not in `chosen`.
   Expected: line 28 arm 2, and line 24 not evaluated. Breaks 3.7.3. The ruling
   accepted matching captions by option, but did not cover a caption that is
   skipped.

4. **Front-matter spans are never matched, so they are always reported as unreached and unevaluated.**
   Severity: wrong output.
   Doc, activated from the front matter (`knitr: opts_knit: weft: !expr weft::weft_setup()`):
   `abstract: |` followed by `  Abstract [one | many]{n="params$a"}.` (line 9),
   with `params: a: 2`.
   Call: `rehearse(p, list(two = list(), one = list(a = 1)))`.
   Observed: both arms are unreached, the case lists the span under "1 span
   that no case evaluated", and no failure is reported. A direct `knitr::knit()`
   of the same file records the span as `line 9, context "prose", chosen 1`.
   `arms()` gives `context "front-matter"`. `rehearse_chosen()` keys prose spans
   by line, key, expression and context, so the two never meet.
   Expected: one arm chosen per case. Breaks 3.7.1 and 3.7.3 (front-matter
   spans are listed but can never be reached).

5. **Literal `weft_str()` spans are never matched, so they are always reported as unreached and unevaluated.**
   Severity: wrong output.
   Doc:
   ```` 
   ```{r loop, results='asis', echo=FALSE}
   for (v in c(TRUE, FALSE)) cat(weft_str("Loop [yes | no]{if=\"v\"}"), "\n")
   ```
   ````
   Call: `rehearse(p, list(x = list()))`.
   Observed: `chosen` is empty, and both arms are unreached and unevaluated. The
   knit records the span as `line NA, context "weft_str", chosen 1` and then
   `chosen 2`. `rehearse_chosen()` drops every record whose line is `NA`,
   except captions.
   Expected: both arms reached. Breaks 3.7.1 and 3.7.3 (literal `weft_str()`
   spans are listed but can never be reached). No test rehearses a
   `weft_str()` span.

6. **A `.qmd` is knitted with the temporary staging folder as its working directory.**
   Severity: wrong output, and for a child document the case stops.
   Probes:
   - A setup chunk writes `getwd()` to a file. Observed:
     `.../weft-rehearse-XXXX/out/stage`.
   - `here <- file.exists("data.csv")`, with `data.csv` beside the `.qmd` in a
     project with `_quarto.yml` and `_weft.yml`, and
     `Data [present | absent]{if="here"}`. Observed: arm 2 ("absent") in every
     case.
   - A chunk with `child='part.Rmd'`, where `part.Rmd` sits beside the `.qmd`.
     Observed: "the knit stopped: cannot open the connection". The same
     document as `.Rmd` knits.

   Expected: the document's folder, as in a render. Breaks the contract line
   "The working directory is the document's, as in a render". knitr evaluates
   in the input's folder (`root.dir` is unset), and the input is the
   `.rmarkdown` copy in `stage/`. The existing `.qmd` test reads no file.

7. **`!r` parameter defaults are evaluated in the caller's session and working directory, and a failure falls back silently.**
   Severity: silent.
   Doc `pr.Rmd`, with `params: v: !r readLines('v.txt')` (a 3-line `v.txt`
   beside it) and `V [one | many]{n="length(params$v)"}`.
   Calls: from another folder, `rehearse("<abs>/pr.Rmd", list(x = list()))`;
   then from the document's folder, `rehearse("pr.Rmd", list(x = list()))`.
   Observed: from another folder, R prints `cannot open file 'v.txt'` and a
   yaml warning ("using default handler"), but the case runs and reports
   `ok` with arm 1 (one). From the document's folder it chooses arm 2. The
   expression also runs in the caller's session before the check for unknown
   names, so an `!r` with side effects acts in the caller's folder.
   Expected: the defaults are evaluated as a render evaluates them (in the
   document's folder), or reading them fails. Breaks "The working directory is
   the document's, as in a render", 3.7.4, and "an error before anything
   runs".

8. **A span that was evaluated but chose no arm is reported as never evaluated.**
   Severity: wrong output.
   Doc: `Change [rose | fell]{sign="d"}.` with `d <- params$d` and
   `params: d: 0`. Call: `rehearse(p, list(off = list()))`.
   Observed: the case's failures list `o.Rmd:16 "rose" ... a two-arm sign has
   no arm for zero`, and the end of the report says "1 span that no case
   evaluated: o.Rmd:16 sign="d"". The same happens to an `if` whose condition
   errors (`[x | y]{if="nosuch > 1"}`) and to an `n` that is `NA`.
   Expected: the span is not in `unevaluated`. Breaks 3.7.3 ("the spans that no
   case evaluated") and the contract ("nested in arms never chosen"). Records
   with `chosen = NA` are dropped before `ever` is computed.

9. **A case whose name matches a column of `arms` overwrites that column.**
   Severity: crash or wrong output.
   Call: `rehearse(p, list(file = list(k = 1)))`.
   Observed: `print()` fails with
   `Error in basename(u): a character vector argument expected`.
   - With a case named `span`, the only span is reported as never evaluated,
     although its arm 1 was chosen.
   - With `text` and `many`, `r$arms$text` becomes `TRUE`/`FALSE`.
   - With `reached`, that column is replaced.

   Expected: such names are rejected, or the case columns are kept apart from
   the others. The contract says "one extra logical column per case" but does
   not reserve any names.

10. **A document activated through the project `.Rprofile` (rule 9.2.1) cannot be rehearsed.**
    Severity: contract mismatch.
    Setup: a Quarto project whose `.Rprofile` is
    `if (requireNamespace('weft', quietly = TRUE)) weft::weft_setup()`.
    `a.qmd` has no setup chunk, and contains
    `Profile-activated [one | many]{n="params$k"}` and
    `` `{r} claim(params$k, . > 3)` ``.
    Call: `rehearse("a.qmd", list(one = list()))`.
    Observed: "the knit stopped: weft: 1 failed claim", "no span chose an arm",
    and every arm unreached. The child runs `Rscript --vanilla`, so the
    `.Rprofile` never runs. The help page's Limits section does not mention it.
    Expected: the case knits as a render does, or the limit is stated. Breaks
    3.7.2 ("renders the document once for each named case") together with
    9.2.1.

11. **Under a non-English `lang`, `arms()` lists English roles and reports no error.**
    Severity: contract mismatch.
    Doc: front matter `lang: pl`, then
    `[a | b]{n="k"} and [a | b | c | d]{n="k"}.` Call: `arms(p)`.
    Observed: roles one/other and zero/one/two/other, and no `errors`
    attribute rows.
    Expected (1.6.4, 1.6.5): a two-arm or four-arm `n` under a language whose
    rules weft does not ship is a construct error, so it goes in `errors` and
    gets no rows. `ARM_ROLES` ignores `lang`.

12. **Arm text that spans lines breaks the print layout.**
    Severity: cosmetic.
    Doc: `Multi [one` / `line | many` / `lines]{n="n"} end.`
    Observed: `print(arms(p))` and `print(rehearse(...))` print
    `1 (one)  one` followed by `line` at column 0, so the second half of the arm
    falls outside the tree.
    Expected: newlines in an arm are collapsed (as the errors section already
    does with `gsub("\n", " ", ...)`).

13. **With duplicate basenames, the errors section of `print.weft_arms` names files differently from the tree.**
    Severity: cosmetic.
    Call: `arms(c("x/doc.Rmd", "y/doc.Rmd"))`, where only `x/doc.Rmd` has
    construct errors.
    Observed: the tree shows full paths, but the errors read `doc.Rmd:3 ...`,
    which does not say which `doc.Rmd`. `display_files()` is computed on
    `err$file` alone.

## Questions

a. Child documents: does `arms()` list spans in a `child=` document, and does
   `rehearse()` report them? Today `arms()` does not list them, and
   `rehearse_chosen()` filters them out by basename. Rule 3.7.1 says "every
   governed span in a document".

b. A span evaluated several times in one case (a `weft_str()` in a loop, or a
   `knit_child()` in a loop): should `chosen` hold every arm it chose, or one
   row per span? The code keeps the last (`duplicated(fromLast = TRUE)`), and
   for prose maps the second and later evaluations to nothing.

c. Should `chosen` carry a span that was evaluated with no arm (`arm = NA`), so
   that findings 8 and 2 can be told apart from a span that was not reached?

d. Should a case value be checked against the default's type or class
   (`list(flag = "no")` for a logical param)? Today it is passed through
   unchecked.

e. `cases = list()` is rejected ("must be a named list"). Is an empty
   rehearsal, which would list every arm as unreached, meant to be an error?

f. `r$arms` is described as "`arms(file)` with extra columns". It is a plain
   `data.frame`: the `weft_arms` class and the `errors` attribute are dropped,
   and `file` is the normalised absolute path, not the path the user gave. Is
   it meant to be identical apart from the added columns?

g. A `.qmd` in a project with `execute-dir: project`: should `rehearse()` use
   the project root as the working directory, as Quarto does?

Probed and sound: `arms()` evaluates no R (inline code, `!r` in YAML,
side-effecting `n`/`if`/`sign` expressions); nesting and
`parent_span`/`parent_arm` (including `n="."`); roles for 1 to 4 `n` arms,
`if` and `sign`; guards and condition lists; back-references `n="#d"`;
several files and span numbering; construct-error listing; missing and empty
inputs. For `rehearse()`: unknown names (with and without `params`); Date
params; a knit that stops; a child process that exits (`quit(status = 3)`);
failing claims and guards; `.qmd` `{r}` inline code and `#| fig-cap:`; nothing
written in a plain folder or in projects with `_weft.yml` and `_quarto.yml`
(apart from finding 1); parent options, knitr hooks and options,
`last_knit()`, working directory and environment unchanged; paths with spaces
and relative paths.
