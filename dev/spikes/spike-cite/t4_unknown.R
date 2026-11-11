source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
mk("unk", c('Known [@smith2020] and unknown [@nosuchkey] and bare @nosuch2.', '', '# Refs'), setup = FALSE)
mk("unk_nobib", c('Unknown [@nosuchkey] and bare @nosuch2.'), setup = FALSE, bib = "")
for (nm in c("unk", "unk_nobib")) for (cm in COMBOS) { r <- render(nm, cm[1], cm[2])
  l <- strsplit(r$log, "\n")[[1]]; w <- grep("nosuch|itation|rror|WARN", l, value = TRUE)
  cat(sprintf("%-10s %-10s %-14s status=%s outfile=%s | %s\n", nm, cm[1], cm[2], r$status, file.exists(r$out), paste(substr(gsub("\033\\[[0-9;]*m", "", w), 1, 110), collapse = " // "))) }
