#!/bin/sh
# Reproduce the caption spike. Needs quarto 1.11.x, knitr 1.51, rmarkdown, gt, ggplot2, xml2.
# CAP_MODE = after (opts_hook -> language -> eval.after; recommended) | early (opts_hook resolves immediately) | none
cd "$(dirname "$0")" || exit 1
for m in after early none chunk; do
  CAP_MODE=$m quarto render main.qmd -o main_$m.html >/dev/null 2>&1 && echo "== main.qmd [$m]" && Rscript ex.R main_$m.html
  CAP_MODE=$m Rscript -e 'rmarkdown::render("main.Rmd", output_file=paste0("main_rmd_", Sys.getenv("CAP_MODE"), ".html"), quiet=TRUE)' >/dev/null 2>&1 && echo "== main.Rmd [$m]" && Rscript ex.R main_rmd_$m.html
  CAP_MODE=$m quarto render quote.qmd -o quote_$m.html >/dev/null 2>&1 && echo "== quote.qmd [$m]" && Rscript ex.R quote_$m.html
  CAP_MODE=$m quarto render timing.qmd -o timing_$m.html >/dev/null 2>&1 && echo "== timing.qmd [$m]" && Rscript ex.R timing_$m.html
done
CAP_MODE=after quarto render main.qmd --to docx
CAP_MODE=after quarto render main.qmd --to typst -M keep-typ:true
# expected failures (message shows chunk label + option):
for f in err_fig err_tbl err_expr err_chunkvar err_subcap_expr; do echo "== $f"; CAP_MODE=after quarto render $f.qmd 2>&1 | grep -i "error"; done
