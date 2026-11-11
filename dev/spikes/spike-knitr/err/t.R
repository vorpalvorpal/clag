knitr::opts_chunk$set(error=FALSE)
txt <- c("a","","```{r}","x<-1","```","","b `r 1+1` c","","```{r}","stop('boom')","```", "", "tail `r stop('inl')`")
where <- function(e) {
  for (f in sys.frames()) if (exists("groups", f, inherits=FALSE) && exists("i", f, inherits=FALSE)) fr <- f
  g <- fr$groups; i <- fr$i
  str(g[[i]], max.level=1)
  cat("block", i, "of", length(g), "\n")
  print(sapply(g, function(x) if (is.list(x)) paste(names(x), collapse=",") else "chr"))
}
for (k in 1:2) {
t2 <- if (k==1) txt[1:11] else txt[c(1:8,12,13)]
r <- tryCatch(withCallingHandlers(knitr::knit_child(text=t2, quiet=TRUE), error=where), error=function(e) cat("ERR:", conditionMessage(e), "\n"))
}
