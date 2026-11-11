source("lib.R")
lines <- readLines("out/timing/docs/doc100.qmd")
u <- extract_units(lines)
tx <- vapply(u, `[[`, "", "text")
for (k in 2:20) { t <- paste(tx[1:k], collapse = "\n\n"); a <- length(scan_ids(t)); b <- length(unlist(lapply(u[1:k], `[[`, "ids")))
  cat(k, a, b, substr(tx[k], 1, 90), "\n") ; if (a != b) break }
