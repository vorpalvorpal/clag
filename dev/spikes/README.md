# Spikes

These are throwaway experiments, kept for reference when building the package. Each one tested a mechanism of the `weft` design (formerly `clag`): knitr hooks, a Lua filter, a static scanner, the commit gate. The "stand-in" code in them is not the design. `PACKAGE-SCOPING.md` section 18 lists how it differs. Most results files say they ran on quarto 1.11.9 (Pandoc 3.10 bundled), knitr 1.51, rmarkdown 2.31 (system Pandoc 3.8.3), R 4.4.3, macOS. The scripts still carry paths into the old scratchpad (`/private/tmp/claude-501/...`), so edit those before you run anything. Rendered output, logs, caches, git repos, installed libraries and generated fixtures were left out; the runners recreate them.

## Stand-in lineage

- `spike-grammar2/` has the unmodified base stand-in in `lib.R`, `cases.R` and `extras.R`; its `setup.R` is the base parser and hooks (copied unchanged into most other spikes, which were dropped).
- `spike-cite/setup.R` is the most extended copy (cite spans, marked literals). Use it as the latest base.
- `spike-failures/setup.R` adds failure-marker styles; `spike-failures/setup_orig.R` is a copy of the base.
- `spike-grammar/setup.R` is the earlier grammar stand-in (same as `spike-activate/pkg/weftspike/inst/setup.R`).
- `spike-captions/setup.R` and `spike-activate/pkg/weftspike/inst/setup.R` are earlier variants.
- Identical copies were dropped; where a folder sources `setup.R` and has none, take the base above.
- `spike-plumbing/q*/clag.R` and `spike-knitr/*/clag.R` are the older, smaller `clag` stand-in (collect-and-fail).

## Folders

Commands are run from inside the folder.

- `spike-activate/`: ways to switch the hooks on (front matter, `.Rprofile`, `_quarto.yml`, a package). `./run.sh` (builds a throwaway package, then `run1.sh` to `run3.sh`); `Rscript check.R file.html` reads a result.
- `spike-captions/`: resolving constructs in figure and table captions. `./run.sh`. Needs gt, ggplot2, xml2.
- `spike-cite/`: `cite` spans, bare citation keys, marked literals, bibliography key extraction. `Rscript t1_forms.R` ... `t7_bare_all.R` (use `harness.R`). Has `RESULTS.md`. Base stand-in: itself.
- `spike-class/`: how the span class is read and rejected. Render `ok.qmd`, `bad.qmd`, `none.qmd` (they source `setup.R`).
- `spike-engine/`: a Quarto engine extension written in TypeScript (`clag/src/clag.ts`) and documents that use it. `quarto render single/doc.qmd`; `book/` is a book project.
- `spike-failures/`: how knitr warnings, messages and errors are captured and normalised, plus marker styles. Has `RESULTS.md`. Runner: render the files in `docs/`, `marker/`, `conds/`.
- `spike-freeze/`: forcing Quarto to re-execute when `freeze: auto` is on. `./run.sh [book|site]`.
- `spike-frontmatter/`: where hook activation can live and when it takes effect (cases A, B, C). `Rscript A_forms.R`, `A_scope.R`, `A_start.R`, `B_late.R`, `B_hostile.R`, `B_book_div.R`, `C_probe.R`, then `C_summary.R`. Has `RESULTS.md`. Base stand-in: `spike-grammar2/setup.R` (copies dropped).
- `spike-gate/`: the commit gate: scan staged files, match old against new, time it. `Rscript run.R` (edit cases in `edits.R`); `./setup-repo.sh` and `./run-all-timing.sh` for timing; `bench.py`. Has `RESULTS.md`. It does not keep the test git repos; the scripts that generate the edits are `edits.R`, `gen-docs.R`, `manuscript.R`. Base stand-in: `spike-grammar2/setup.R`.
- `spike-grammar/`, `spike-grammar2/`: the span grammar and attribute parser, as a case matrix across quarto and rmarkdown. `Rscript run.R [--skip-extras]`. `spike-grammar2/` is the later one and holds the base stand-in.
- `spike-gtdocx/`: what the constructs turn into in docx, html and typst. `./run.sh`.
- `spike-inline/`: knitr inline-code handling and a Lua filter (`t5/clag.lua`). Render the `.qmd`/`.Rmd` in `t1` to `t5`.
- `spike-knitr/`: knitr hook points, error and warning locations, includes, books, route A. `single/`, `book/`, `err/` (`Rscript err/t.R`), `routeA/`; render the documents in each, `norm.py` and `insp.py` inspect output.
- `spike-lines/`: finding where each block starts in the input file (line numbers). `Rscript run.R [--quick]`; also `stress.R`, `timing.R`.
- `spike-plumbing/`: seven questions (`q1` to `q7`) about how the hooks, a check filter (`q4/clag-check.lua`), a stub package (`q6/clagstub`) and books plug together. Render the documents in each `q*` folder.
- `spike-q2/`: seven small documents for the Quarto 2 `{{ }}` syntax. `quarto render t1.qmd` and so on.
- `spike-tardict/`: a targets dictionary of project values and how it reacts to edits. `./run.sh` (runs `run.R` then `extra.R`); `common/` holds the two designs.
- `spike-text/`: the knitr text hook, ordering and lazy evaluation. Render the files.
- `chk-engine/`, `chk-env/`, `review/`, `review-x/`: small checks made while reviewing the earlier spikes (engine detection per version `v1` to `v5`, Quarto environment variables, hook behaviour across repeated knits, `luaerr`, book freeze, late loading). `review/hooktest.R`, `review/childtest.R`, `review-x/k/t1.R` to `t5.R`; render the documents elsewhere. No notes file; read the scripts.

## Skipped

- `spike-static/`, `spike-style/`, `spike-misc/`, `chk-esc/`: a handful of one-line probes, trivially re-created (misc is also a copy of the base stand-in).
- `verify-cldr/`: only downloaded CLDR plural XML.
- Inside kept folders: `spike-cite/docs/`, `spike-cite/bib/keys/n500_*` (generated), `spike-freeze/work` and `base`, `spike-tardict/work` (generated by the runners), the `lib/` installs, `q2-src`, `q2-dl`, and every `out/` folder.
