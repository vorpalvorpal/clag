library(knitr)
cat("knitr", as.character(packageVersion("knitr")), "\n")
x <- 5
# T1 newline after `r
cat("T1:", knit(text = "A `r\nx`{.num} B and `r x` C", quiet = TRUE), "\n")
# T2 syntax error before evaluate.inline hook
knit_hooks$set(evaluate.inline = function(code, envir) { cat("[hook called with:", code, "]\n"); "PARKED" })
r <- tryCatch(knit(text = "A `r x +` B `r x` C", quiet = TRUE), error = function(e) paste("ERROR:", conditionMessage(e)))
cat("T2:", r, "\n")
knit_hooks$restore()
# T8 stock inline numbers
for (v in list(1e5, 100000L, 123456789, 1234567.891, 0.00001234, 1e-4, 1/3, 1, 1.0000001, 1e15, 2e6))
  cat("T8:", format(v, digits = 15), "->", knit(text = "`r v`", quiet = TRUE), "\n")
cat("T8 NA:", knit(text = "`r NA_real_` | `r NULL` | `r character(0)` | `r c(1.5,2.5)` | `r NaN` | `r Inf`", quiet = TRUE), "\n")
