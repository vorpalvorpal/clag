source("compare.R", echo = FALSE) 
A <- readRDS("abc.rds")$A
## extra real pair for class (b): same chunk, different substantive number
suppressPackageStartupMessages(library(glmmTMB)); set.seed(1)
dt <- data.frame(g = gl(6, 10), x = rnorm(60)); dt$y <- rpois(60, 2)
m2 <- tryCatch(withCallingHandlers(glmmTMB(y ~ x + I(x * 2) + (1 | g), data = dt, family = poisson), message = function(m) { cat("RAW2:", conditionMessage(m)); invokeRestart("muffleMessage") }), error = function(e) NULL)
m3 <- tryCatch(withCallingHandlers(glmmTMB(y ~ x + I(x * 3) + (1 | g), data = dt, family = poisson), message = function(m) { cat("RAW3:", conditionMessage(m)); invokeRestart("muffleMessage") }), error = function(e) NULL)
cat("\n")
A$n1 <- n1(A$text); A$n2 <- n2(A$text)
varN1 <- unique(c(ac$n1, ab$n1)); 
A$digit_changed <- A$text != n1(A$text)
b_ids <- c("tidyr-separate", "tidyr-separate-b", "tidyr-separate-c", "tidyr-sep3", "glmmTMB-hess")
b_rows <- (A$id %in% b_ids) | grepl("^convergence code", A$text)
A$c_flag <- A$key %in% varN1
A$class <- ifelse(b_rows, "b", ifelse(A$digit_changed, "a", "none"))
cat("\nDigit-fate class over", nrow(A), "logged warnings/messages (all conditions from run A, errors excluded):\n"); print(table(A$class))
cat("Also varies for non-digit reasons across run A/C/B (class c flag):", sum(A$c_flag), "of", nrow(A), "\n")
kinds <- function(k) { t <- A$text[A$key == k]; c(tmp = grepl("/Rtmp", t), addr = grepl("0x[0-9a-f]{5,}", t), wrap = grepl("\n", t) , ansi = grepl("\033", t, fixed = TRUE), curly = grepl("[‘’]", t), bullet = grepl("[ℹ•─]", t)) }
K <- t(sapply(A$key[A$c_flag], kinds)); print(K)
A$n1s <- gsub("\n", "\\\\n", n1(A$text)); A$raws <- gsub("\n", "\\\\n", A$text); A$n2s <- gsub("\n", "\\\\n", n2(A$text))
out <- A[c("key", "kind", "class", "c_flag", "raws", "n1s", "n2s")]; write.csv(out, "classified.csv", row.names = FALSE)
