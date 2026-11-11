#!/bin/bash
# Reproduce the spike. Builds throwaway package weftspike into ./lib (never the user library), then runs all routes.
cd "$(dirname "$0")"; mkdir -p lib
R_LIBS=$PWD/lib R CMD INSTALL --no-test-load pkg/weftspike >/dev/null && echo "installed weftspike into ./lib"
./run1.sh   # routes A, B (document), E, F, controls
./run2.sh   # routes C, D, B/G project-wide, not-installed cases, rmarkdown _output.yml
./run3.sh   # extra probes: _metadata.yml, _quarto.yml params, .Rprofile placement
