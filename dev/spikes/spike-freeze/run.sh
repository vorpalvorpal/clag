#!/bin/bash
# Spike: ways to force Quarto to re-execute despite freeze: auto.
# Usage: ./run.sh [book|site]   (default both). Work in ./work, base snapshots in ./base.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
export QUARTO_PRINT_STACK=

mkproj() { # type dir
  local type=$1 d=$2
  rm -rf "$d"; mkdir -p "$d"; cd "$d"
  echo alpha > data.txt
  local chunk='```{r}
cat(format(Sys.time(), "%H:%M:%OS3"), knitr::current_input(), "\n", file = "../log.txt", append = TRUE)
cat("VALUE=", readLines("data.txt"), "\n", sep = "")
```'
  if [ $type = book ]; then
    cat > _quarto.yml <<Y
project:
  type: book
book:
  title: Spike
  chapters: [index.qmd, ch2.qmd, ch3.qmd]
execute:
  freeze: auto
format: {html: default}
Y
  else
    cat > _quarto.yml <<Y
project:
  type: website
website:
  title: Spike
execute:
  freeze: auto
format: {html: default}
Y
  fi
  if [ $type = book ]; then
    printf '# One {#sec-one}\n\n%s\n' "$chunk" > index.qmd
    printf '# Two\n\nSee @sec-one.\n\n%s\n' "$chunk" > ch2.qmd
    printf '# Three\n\nSee @sec-one.\n\n%s\n' "$chunk" > ch3.qmd
  else
    printf -- '---\ntitle: One\n---\n\n[two](ch2.qmd)\n\n%s\n' "$chunk" > index.qmd
    printf -- '---\ntitle: Two\n---\n\n[one](index.qmd)\n\n%s\n' "$chunk" > ch2.qmd
    printf -- '---\ntitle: Three\n---\n\n[one](index.qmd)\n\n%s\n' "$chunk" > ch3.qmd
  fi
  cat > _quarto-verify.yml <<Y
execute:
  freeze: false
Y
  printf 'execute:\n  freeze: false\n' > meta-nofreeze.yml
  cd "$HERE"
}

DOCS="index ch2 ch3"
outdir() { [ -d _book ] && echo _book || echo _site; }
vals_out() { local o=$(outdir); for x in $DOCS; do v=$(grep -Eo 'VALUE=[a-z]+' $o/$x.html 2>/dev/null | head -1 | cut -d= -f2); printf '%s=%s ' $x "${v:--}"; done; }
vals_frz() { # value stored in _freeze per doc
  for x in $DOCS; do v=$(grep -rhEo 'VALUE=[a-z]+' _freeze/$x 2>/dev/null | head -1 | cut -d= -f2); printf '%s=%s ' $x "${v:--}"; done; }
logcount() { for x in $DOCS; do printf '%s=%s ' $x "$(grep -c "^[0-9:.]* $x\." ../log.txt 2>/dev/null)"; done; }
exec_delta() { # args: before-counts as 3 numbers via global; prints which executed
  local r=""; for x in $DOCS; do n=$(grep -c "^[0-9:.]* $x\." ../log.txt); eval "b=\$B_$x"; [ "$n" -gt "$b" ] && r="$r$x*$((n-b)) "; done; echo "${r:-none}"; }
snap_counts() { for x in $DOCS; do eval "B_$x=$(grep -c "^[0-9:.]* $x\." ../log.txt 2>/dev/null)"; done; }
intact() { local o=$(outdir); local ok=Y
  for x in $DOCS; do [ -f $o/$x.html ] || ok="N(missing $x)"; done
  if [ $o = _book ]; then
    grep -q '?@sec-one' $o/ch2.html $o/ch3.html 2>/dev/null && ok="N(unresolved xref)"
    for x in ch2 ch3; do grep -q 'quarto-xref"><span>Chapter 1</span>' $o/$x.html 2>/dev/null || ok="N(xref not resolved in $x)"; done
    ls $o | grep -qi 'search.json' || ok="$ok(no search.json)"
    # sidebar lists all chapters in every page
    for x in $DOCS; do grep -q 'ch3.html' $o/$x.html 2>/dev/null || ok="$ok(sidebar $x lacks ch3)"; done
  fi; echo $ok; }
srchash() { (cd work/proj && find . -type f ! -path './_book/*' ! -path './_site/*' ! -path './_freeze/*' ! -path './.quarto/*' ! -name '*_files' -print0 | sort -z | xargs -0 shasum | shasum | cut -c1-8); }
freezehash() { (cd work/proj && [ -d _freeze ] && find _freeze -type f -print0 | sort -z | xargs -0 shasum | shasum | cut -c1-8 || echo none); }

# test NAME TYPE -- command...   (command runs inside project dir)
t() {
  local name=$1 type=$2; shift 3
  rm -rf work; mkdir -p work; cp -R base/$type work/proj; : > work/log.txt
  cd work/proj
  echo bravo > data.txt                       # data changed, .qmd untouched
  local src0=$(cd "$HERE" && srchash) frz0=$(cd "$HERE" && freezehash)
  snap_counts
  ( "$@" ) > ../mech.out 2>&1; local rc=$?
  local ex=$(exec_delta) out=$(vals_out) frz=$(vals_frz) ok=$(intact)
  local frz1=$(cd "$HERE" && freezehash)
  local fstate; [ "$frz1" = none ] && fstate=REMOVED || { [ "$frz1" = "$frz0" ] && fstate=UNCHANGED || fstate=REWRITTEN; }
  local src1=$(cd "$HERE" && srchash) side; [ "$src0" = "$src1" ] && side=none || side="SOURCE FILES CHANGED"
  # followed by a plain render
  snap_counts
  quarto render > ../plain.out 2>&1
  local pex=$(exec_delta) pout=$(vals_out) pfrz=$(vals_frz)
  local src2=$(cd "$HERE" && srchash); [ "$src1" = "$src2" ] || side="$side; plain render changed source"
  printf '\n### [%s] %s (rc=%s)\n  mech executed: %s\n  output  : %s\n  _freeze : %s  (%s)\n  intact  : %s\n  side    : %s\n  plain executed: %s | output: %s | _freeze: %s\n' \
    "$type" "$name" $rc "$ex" "$out" "$fstate" "$frz" "$ok" "$side" "$pex" "$pout" "$pfrz"
  cd "$HERE"
}

mkbase() { # build pristine, rendered once with alpha
  local type=$1
  mkproj $type base/$type
  rm -rf work; mkdir work; cp -R base/$type work/proj; : > work/log.txt
  (cd work/proj && quarto render >/dev/null 2>&1)
  mkdir -p base/$type.rendered; rm -rf base/$type; cp -R work/proj base/$type
  echo "[$type] base built: freeze=$(cd work/proj; vals_frz) out=$(cd work/proj; vals_out)"
}

run_all() {
  local ty=$1
  t "control: plain render (freeze auto)" $ty -- quarto render
  t "control: --execute" $ty -- quarto render --execute
  t "control: --cache-refresh" $ty -- quarto render --cache-refresh
  t "1a profile: --profile verify" $ty -- quarto render --profile verify
  t "1b profile: QUARTO_PROFILE=verify" $ty -- env QUARTO_PROFILE=verify quarto render
  t "2a -M freeze:false" $ty -- quarto render -M freeze:false
  t "2b -M execute.freeze:false" $ty -- quarto render -M execute.freeze:false
  t "2c -M 'execute:{freeze: false}'" $ty -- quarto render -M 'execute:{freeze: false}'
  t "2d --metadata-file meta-nofreeze.yml" $ty -- quarto render --metadata-file meta-nofreeze.yml
  t "2e --metadata freeze:false" $ty -- quarto render --metadata freeze:false
  t "3a single: ch2.qmd only" $ty -- quarto render ch2.qmd
  t "3b single: each of index, ch2, ch3 in turn" $ty -- bash -c 'quarto render index.qmd; quarto render ch2.qmd; quarto render ch3.qmd'
  t "3c single: ch2.qmd with --profile verify" $ty -- quarto render ch2.qmd --profile verify
  t "3d single: ch2.qmd with -M execute.freeze:false" $ty -- quarto render ch2.qmd -M execute.freeze:false
  t "4a mv _freeze aside, render" $ty -- bash -c 'mv _freeze ../freeze.aside; quarto render'
  t "4b rm -rf _freeze/ch2, render" $ty -- bash -c 'rm -rf _freeze/ch2; quarto render'
  t "4c mv _freeze aside, render, move back (restore old)" $ty -- bash -c 'mv _freeze ../freeze.aside; quarto render; rm -rf _freeze; mv ../freeze.aside _freeze'
  t "5a --no-cache" $ty -- quarto render --no-cache
  t "5b touch ch2.qmd" $ty -- bash -c 'touch ch2.qmd; quarto render'
  t "5c touch data.txt only" $ty -- bash -c 'touch data.txt; quarto render'
  t "5d --to html" $ty -- quarto render --to html
  t "5e execute-dir via -M execute-dir:project" $ty -- quarto render -M execute-dir:project
  t "5f temp edit _quarto.yml freeze: false then git-style revert" $ty -- bash -c 'cp _quarto.yml ../q.bak; sed -i.tmp "s/freeze: auto/freeze: false/" _quarto.yml; rm _quarto.yml.tmp; quarto render; cp ../q.bak _quarto.yml'
  t "5g freeze: false profile on one doc after book (ch2 then project render)" $ty -- bash -c 'quarto render ch2.qmd --profile verify; quarto render'
  t "5h --profile verify then --profile verify-not (plain) " $ty -- bash -c 'quarto render --profile verify; quarto render --profile nonexist'
  t "5i QUARTO_FREEZE-ish: --execute-daemon-restart" $ty -- quarto render --execute-daemon-restart
}

which=${1:-all}
[ $which = all ] || [ $which = book ] && { mkbase book; run_all book; }
[ $which = all ] || [ $which = site ] && { mkbase site; run_all site; }
