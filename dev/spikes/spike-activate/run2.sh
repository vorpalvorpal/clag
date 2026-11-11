#!/bin/bash
# Routes C, D, B/G project-wide. Usage: ./run2.sh
cd "$(dirname "$0")"; HERE=$PWD
export R_LIBS=$HERE/lib
rm -rf proj; mkdir proj; cd proj
body() { cat <<'B'
FIRST: `r 3.7`{.num} and [a site | # sites]{n="2"} here.

```{r}
#| include: false
x <- 1
```

LATER: `r 3.7`{.num} and [a site | # sites]{n="2"} here.
B
}
qdoc() { { printf -- '---\nformat: html\n---\n\n'; body; } > "$1"; }
rdoc() { { printf -- '---\noutput: html_document\n---\n\n'; body; } > "$1"; }
mkproj() { # name
  mkdir -p $1/sub; ( cd $1; echo "project:
  type: default" > _quarto.yml; qdoc doc.qmd; qdoc sub/doc.qmd; rdoc rdoc.Rmd; rdoc sub/rdoc.Rmd ); }
show() { Rscript $HERE/check.R $1 | sed 's/^/     /'; }
cleanout() { find $1 -name '*.html' -delete; rm -rf $1/_site $1/*_files $1/sub/*_files; }
qrun() { # proj label args...
  p=$1; l=$2; shift 2; echo "--- [$p] quarto render $*  ($l)"; cleanout $p
  ( cd $p; quarto render "$@" 2>&1 | grep -iE "error|unable|Quitting" | head -3 )
  for h in $p/_site/doc.html $p/_site/sub/doc.html $p/doc.html $p/sub/doc.html; do [ -f $h ] && { echo "   $h"; show $h; }; done; }
rrun() { # proj dir file
  echo "--- [$1] rmarkdown::render $3 from cwd=$2"; cleanout $1
  ( cd $1/$2; Rscript -e 'rmarkdown::render(commandArgs(TRUE)[1], quiet=TRUE)' $3 2>&1 | grep -iE "error|unable|Quitting" | head -3 )
  h=$1/$2/${3%.Rmd}.html; echo "   $h"; show $h; }

## C: .Rprofile at root
mkproj c_rprofile
cat > c_rprofile/.Rprofile <<P
cat(Sys.getpid(), getwd(), "\n", file="$HERE/proj/c_rprofile.log", append=TRUE)
weftspike::activate()
P
: > c_rprofile.log
qrun c_rprofile project
cat c_rprofile.log
qrun c_rprofile "single root" doc.qmd
qrun c_rprofile "single sub" sub/doc.qmd
echo "== .Rprofile log:"; cat c_rprofile.log
rrun c_rprofile . rdoc.Rmd
rrun c_rprofile sub rdoc.Rmd
cat c_rprofile.log

## D1: _environment R_DEFAULT_PACKAGES
mkproj d_defpkgs
echo "R_DEFAULT_PACKAGES=datasets,utils,grDevices,graphics,stats,methods,weftspike" > d_defpkgs/_environment
qrun d_defpkgs project
qrun d_defpkgs "single sub" sub/doc.qmd
## D1b: without base set (only the package)
mkproj d_defpkgs_only
echo "R_DEFAULT_PACKAGES=weftspike" > d_defpkgs_only/_environment
qrun d_defpkgs_only project
## D2: _environment R_PROFILE_USER
mkproj d_rpu
echo "weftspike::activate()" > d_rpu/weft-profile.R
echo "R_PROFILE_USER=$HERE/proj/d_rpu/weft-profile.R" > d_rpu/_environment
qrun d_rpu project
qrun d_rpu "single sub" sub/doc.qmd
## D3: _environment.local? same file name check skipped

## B project-wide in _quarto.yml
mkproj b_qyml
printf 'knitr:\n  opts_chunk:\n    weft_act: !expr weftspike::activate()\n' >> b_qyml/_quarto.yml
qrun b_qyml project
qrun b_qyml "single sub" sub/doc.qmd
mkproj b_qyml_knit
printf 'knitr:\n  opts_knit:\n    weft_act: !expr weftspike::activate()\n' >> b_qyml_knit/_quarto.yml
qrun b_qyml_knit project
## B/G: package NOT installed -> use a bogus package name
mkproj b_qyml_missing
printf 'knitr:\n  opts_chunk:\n    weft_act: !expr weftnotinstalled::activate()\n' >> b_qyml_missing/_quarto.yml
qrun b_qyml_missing project
mkproj a_missing; sed -i '' 's/^format: html/format: html\nweft: "`r weftnotinstalled::activate()`"/' a_missing/doc.qmd
qrun a_missing "A not installed" doc.qmd
mkproj c_missing; echo 'weftnotinstalled::activate()' > c_missing/.Rprofile
qrun c_missing "C not installed" doc.qmd
mkproj d_missing; echo "R_DEFAULT_PACKAGES=datasets,utils,grDevices,graphics,stats,methods,weftnotinstalled" > d_missing/_environment
qrun d_missing "D not installed" doc.qmd

## G rmarkdown: _output.yml project-wide
mkdir -p g_output/sub; ( cd g_output; { printf -- '---\ntitle: t\n---\n\n'; body; } > rdoc.Rmd; cp rdoc.Rmd sub/rdoc.Rmd; printf 'weftspike::html_document: default\n' > _output.yml; cp _output.yml sub/ )
rrun g_output . rdoc.Rmd
## G rmarkdown: !expr in output options
mkdir -p g_exprout; ( cd g_exprout; { printf -- '---\noutput:\n  html_document:\n    css: !expr {weftspike::activate(); NULL}\n---\n\n'; body; } > rdoc.Rmd )
rrun g_exprout . rdoc.Rmd
