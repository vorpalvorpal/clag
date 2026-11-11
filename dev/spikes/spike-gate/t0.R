source("lib.R")
x <- c("We saw `r n_sites`{.num} [a site | # sites]{n=\"n_sites\"} and `r claim(x, . >  10)`{.num .dec1} and `r d`{#d .num} `r plain` [^1] [x|y]{.mark}.",
 "## Methods for `r n_sites`{.num} sites {#sec-m}")
for (t in x) print(scan_ids(t))
