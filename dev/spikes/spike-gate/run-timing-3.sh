#!/bin/bash
# Part 2 items 6 and 7: end-to-end hook runs. Median of 5 (+1 untimed warm-up; S3 has no warm-up).
cd "$(dirname "$0")"; B=./bench.py; R=out/timing/repo; H=$PWD/hook.R
run() { echo "cd $R && Rscript --vanilla $H $*"; }
files() { n=$1; s=""; for i in $(seq 1 $n); do s="$s ch/ch$(printf %02d $i).qmd"; done; echo $s; }
stage() { n=$1; (cd $R && git reset -q --hard HEAD && for i in $(seq 1 $n); do f=ch/ch$(printf %02d $i).qmd; cp ../ch2/ch$(printf %02d $i).qmd $f; done && git add ch); }
echo "## S1: 1 changed file (300 paragraphs), staged"
stage 1
$B 5 "S1 staged-only, quarto pandoc"            "$(run --pandoc=quarto $(files 1))"
$B 5 "S1 staged-only, direct pandoc"            "$(run --pandoc=direct $(files 1))"
$B 5 "S1 + HEAD version + match, direct pandoc" "$(run --pandoc=direct --compare $(files 1))"
echo "## S2: 5 changed files, staged"
stage 5
$B 5 "S2 staged-only, quarto pandoc, 1 pandoc/file" "$(run --pandoc=quarto $(files 5))"
$B 5 "S2 staged-only, direct pandoc, 1 pandoc/file" "$(run --pandoc=direct $(files 5))"
$B 5 "S2 staged-only, direct pandoc, 1 pandoc total" "$(run --pandoc=direct --once $(files 5))"
$B 5 "S2 + HEAD + match, direct, 1 pandoc/version"  "$(run --pandoc=direct --once --compare $(files 5))"
echo "## S3: whole book, 20 chapters x 300 paragraphs, commit range HEAD~1..HEAD"
(cd $R && git reset -q --hard HEAD && for i in $(seq 1 20); do cp ../ch2/ch$(printf %02d $i).qmd ch/; done && git add ch && git commit -q -m v2)
WARM=0 $B 5 "S3 range, new version only, quarto pandoc, 1/file" "$(run --range --pandoc=quarto $(files 20))"
WARM=0 $B 5 "S3 range, new version only, direct pandoc, 1/file" "$(run --range --pandoc=direct $(files 20))"
WARM=0 $B 5 "S3 range, new version only, direct pandoc, 1 total" "$(run --range --pandoc=direct --once $(files 20))"
WARM=0 $B 5 "S3 range, both versions + match, direct, 1 pandoc/version" "$(run --range --pandoc=direct --once --compare $(files 20))"
