#!/bin/bash
cd "$(dirname "$0")"; B=./bench.py; R=out/timing/repo
echo "## 4. git show :<file> (files staged first), sequential processes"
(cd $R && for i in $(seq -w 1 20); do cp ../ch2/ch$i.qmd ch/ch$i.qmd; done; git add ch)
mk() { n=$1; s=""; for i in $(seq 1 $n); do i=$(printf %02d $i); s="$s git show :ch/ch$i.qmd >/dev/null;"; done; echo "$s"; }
$B 5 "4a git show :f x1  (1 process)"  "cd $R && $(mk 1)"
$B 5 "4b git show :f x5  (5 processes)" "cd $R && $(mk 5)"
$B 5 "4c git show :f x20 (20 processes)" "cd $R && $(mk 20)"
$B 5 "4d git cat-file --batch, 20 files (1 process)" "cd $R && for i in \$(seq -w 1 20); do echo :ch/ch\$i.qmd; done | git cat-file --batch >/dev/null"
(cd $R && git reset -q --hard HEAD)
