source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
a <- commandArgs(TRUE)
for (f in a) { cat("=====", f, "\n"); cat(if (grepl("html$", f)) html_txt(f) else if (grepl("docx$", f)) docx_txt(f) else typ_txt(f), "\n") }
