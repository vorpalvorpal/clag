#!/bin/bash
# Part 2 items 1, 2, 3 (pandoc side), 7 (pandoc direct vs quarto pandoc). Median of 5 (+1 untimed warm-up).
cd "$(dirname "$0")"; B=./bench.py; D=out/timing/docs
PD=/Applications/quarto/bin/tools/aarch64/pandoc
echo "## 1. Rscript startup"
$B 5 "1a Rscript -e invisible(1)  (no --vanilla)"           "Rscript -e 'invisible(1)'"
$B 5 "1b Rscript --vanilla -e invisible(1)"                 "Rscript --vanilla -e 'invisible(1)'"
$B 5 "1c Rscript --vanilla --default-packages=base"         "Rscript --vanilla --default-packages=base -e 'invisible(1)'"
echo "## 2. package loading (all --vanilla)"
$B 5 "2a base only (default packages)"                      "Rscript --vanilla -e 'invisible(1)'"
$B 5 "2b + library(jsonlite)"                               "Rscript --vanilla -e 'library(jsonlite)'"
$B 5 "2c + library(jsonlite); library(yaml)"                "Rscript --vanilla -e 'library(jsonlite); library(yaml)'"
$B 5 "2d + loadNamespace(yaml) only"                        "Rscript --vanilla -e 'loadNamespace(\"yaml\")'"
$B 5 "2e + library(knitr)"                                  "Rscript --vanilla -e 'library(knitr)'"
$B 5 "2f + loadNamespace(knitr)"                            "Rscript --vanilla -e 'loadNamespace(\"knitr\")'"
echo "## 3. Pandoc"
$B 5 "3a quarto pandoc --version"                           "quarto pandoc --version"
$B 5 "3b direct pandoc --version"                           "$PD --version"
for n in 100 500 2000; do
$B 5 "3c quarto pandoc sourcepos json, $n paragraphs"       "quarto pandoc -f commonmark_x+sourcepos -t json -o out/timing/p$n.sp.json $D/doc$n.qmd"
$B 5 "3d direct pandoc sourcepos json, $n paragraphs"       "$PD -f commonmark_x+sourcepos -t json -o out/timing/p$n.sp.json $D/doc$n.qmd"
$B 5 "3e direct pandoc NO sourcepos json, $n paragraphs"    "$PD -f commonmark_x -t json -o out/timing/p$n.json $D/doc$n.qmd"
done
ls -l out/timing/*.json | awk '{print $5, $9}'
