#!/bin/sh
# usage: rr.sh <doc-base> <ext qmd|Rmd> [to=html]  ; env WEFT_SETUP selects setup
b=$1; e=$2; to=${3:-html}
rm -f $b.html $b.docx $b.typ $b.pdf $b.tex $b.md; rm -rf ${b}_files
if [ "$e" = qmd ]; then quarto render $b.qmd --to $to > $b.$e.$to.log 2>&1; st=$?
else Rscript -e "rmarkdown::render('$b.Rmd', output_format='${to}_document', quiet=TRUE)" > $b.$e.$to.log 2>&1; st=$?; fi
echo "== $b [$e->$to] setup=${WEFT_SETUP:-setup.R} exit=$st; output files: $(ls $b.html $b.docx $b.typ 2>/dev/null | tr '\n' ' ')"
