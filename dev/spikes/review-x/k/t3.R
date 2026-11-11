library(knitr)
out1 <- knit("doc.Rmd", output = "stock.md", quiet = TRUE)
# install a wrapping text hook BEFORE the knit, as .Rprofile activation would
old <- knit_hooks$get("text"); knit_hooks$set(text = function(x) old(x))
out2 <- knit("doc.Rmd", output = "hooked.md", quiet = TRUE)
cat("identical:", identical(readLines("stock.md"), readLines("hooked.md")), "\n")
cat("--- stock\n"); cat(readLines("stock.md"), sep = "\n"); cat("--- hooked\n"); cat(readLines("hooked.md"), sep = "\n")
