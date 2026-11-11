#!/bin/bash
# throwaway repo: 20 chapters x 300 paragraphs. HEAD = v1; out/timing/ch2 holds the edited v2 of each chapter.
cd "$(dirname "$0")/out/timing" || exit 1
rm -rf repo && mkdir -p repo/ch && cd repo && git init -q -b main . && git config user.email t@example.invalid && git config user.name spike
cp ../ch1/*.qmd ch/ && git add ch && git commit -q -m v1 && echo "repo ready: $(git rev-parse --short HEAD)"
