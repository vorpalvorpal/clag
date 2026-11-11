#!/bin/sh
# add "# battery-ok" to the command line if the battery hook blocks
cd "$(dirname "$0")"
Rscript run.R > results.txt 2>&1
Rscript extra.R > extra_results.txt 2>&1
