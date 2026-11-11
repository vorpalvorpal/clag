#!/bin/bash
# Routes A,B,E,F + control: single-file docs in docs/. Usage: ./run1.sh
cd "$(dirname "$0")"; HERE=$PWD
export R_LIBS=$HERE/lib
rm -rf work; mkdir work; cp docs/* work/; cd work
for f in *.qmd; do echo "=== quarto $f"; quarto render $f 2>&1 | grep -iE "error|warn|unable|Quitting" | head -5; Rscript ../check.R ${f%.qmd}.html; done
for f in *.Rmd; do echo "=== rmarkdown $f"; Rscript -e 'rmarkdown::render(commandArgs(TRUE)[1], quiet=TRUE)' $f 2>&1 | grep -iE "error|warn|unable|Quitting" | head -5; Rscript ../check.R ${f%.Rmd}.html; done
