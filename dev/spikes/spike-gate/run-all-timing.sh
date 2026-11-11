#!/bin/bash
cd "$(dirname "$0")"; rm -f out/timing.jsonl
for s in 1 2 3 4; do :; done
./run-timing-1.sh > out/timing-1.txt 2>&1
Rscript --vanilla time-r.R > out/timing-r.txt 2>&1
./run-timing-2.sh > out/timing-2.txt 2>&1
./setup-repo.sh > /dev/null
./run-timing-3.sh > out/timing-3.txt 2>&1
./run-timing-4.sh > out/timing-4.txt 2>&1
echo finished > out/timing-done.txt
