#!/bin/bash
# Part 2 item 7 (pure Pandoc, no R): 20 chapters x 300 paragraphs. Plus Rscript default-packages variant on the S1 hook.
cd "$(dirname "$0")"; B=./bench.py; C=out/timing/ch2; PD=/Applications/quarto/bin/tools/aarch64/pandoc; F="$(ls $C/ch*.qmd | tr '\n' ' ')"
F1="$C/ch01.qmd"; F5="$(ls $C/ch0[1-5].qmd | tr '\n' ' ')"
$B 5 "7a 20 files, quarto pandoc, 20 processes" "for f in $F; do quarto pandoc -f commonmark_x+sourcepos -t json -o /dev/null \$f; done"
$B 5 "7b 20 files, direct pandoc, 20 processes" "for f in $F; do $PD -f commonmark_x+sourcepos -t json -o /dev/null \$f; done"
$B 5 "7c 20 files, quarto pandoc, 1 process"    "quarto pandoc -f commonmark_x+sourcepos -t json -o /dev/null $F"
$B 5 "7d 20 files, direct pandoc, 1 process"   "$PD -f commonmark_x+sourcepos -t json -o /dev/null $F"
$B 5 "7e 5 files, direct pandoc, 5 processes"  "for f in $F5; do $PD -f commonmark_x+sourcepos -t json -o /dev/null \$f; done"
$B 5 "7f 5 files, direct pandoc, 1 process"    "$PD -f commonmark_x+sourcepos -t json -o /dev/null $F5"
$B 5 "7g 20 files, direct pandoc, 20 procs, 4 at a time (xargs -P4)" "ls $C/ch*.qmd | xargs -P4 -n1 $PD -f commonmark_x+sourcepos -t json -o /dev/null"
$B 5 "7h 1 file (300 para), direct pandoc"     "$PD -f commonmark_x+sourcepos -t json -o /dev/null $F1"
$B 5 "7i 1 file (300 para), direct pandoc, NO sourcepos" "$PD -f commonmark_x -t json -o /dev/null $F1"
echo "## default-packages variant on the S1 hook (staged-only, direct pandoc)"
R=out/timing/repo; (cd $R && git reset -q --hard HEAD~1 >/dev/null 2>&1; git reset -q --hard HEAD; cp ../ch2/ch01.qmd ch/ch01.qmd; git add ch)
$B 5 "S1 hook, Rscript --vanilla (default packages)" "cd $R && Rscript --vanilla $PWD/hook.R --pandoc=direct ch/ch01.qmd"
$B 5 "S1 hook, --default-packages=base,methods,utils,stats" "cd $R && Rscript --vanilla --default-packages=base,methods,utils,stats $PWD/hook.R --pandoc=direct ch/ch01.qmd"
(cd $R && git reset -q --hard HEAD)
