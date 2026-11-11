r <- readRDS("conds_raw.rds"); r <- r[r$kind != "error", ]; r <- r[!duplicated(r[c("id", "text")]), ]
norm1 <- function(x) gsub("[-+]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?", "<N>", x, perl = TRUE)
## what a smarter second stage adds: ANSI, curly quotes, temp paths, hex addresses, whitespace
norm2 <- function(x) {
  x <- gsub("\033\\[[0-9;]*m", "", x)
  x <- chartr("‘’“”", "''\"\"", x)
  x <- gsub("0x[0-9a-fA-F]+", "<ADDR>", x)
  x <- gsub("(/[^ '\"`]*)?/Rtmp[A-Za-z0-9]+/[^ '\"`]*", "<TMP>", x)
  x <- gsub("[[:space:]]+", " ", x)
  norm1(x)
}
r$norm1 <- norm1(r$text); r$norm2 <- norm2(r$text)
feat <- function(t) c(
  path = grepl("/Rtmp|/nonexistent", t), addr = grepl("0x[0-9a-f]{6,}", t), ansi = grepl("\033", t, fixed = TRUE),
  curly = grepl("[‘’“”]", t), nonenglish = grepl("[A-Za-z]*(Gew|durch Umwandlung)", t),
  wrap = grepl("logic to\nbreak", t, fixed = TRUE))
F <- t(vapply(r$text, feat, logical(6))); rownames(F) <- NULL
r <- cbind(r, F)
r$text1 <- gsub("\n", "\\\\n", r$text); r$n1 <- gsub("\n", "\\\\n", r$norm1)
saveRDS(r, "analysis.rds"); write.csv(r[c("id","kind","text1","n1", colnames(F))], "analysis.csv", row.names = FALSE)
options(width = 250)
for (i in seq_len(nrow(r))) cat(sprintf("%2d %-20s %-3s | %s\n     -> %s\n", i, r$id[i], substr(r$kind[i],1,3), substr(r$text1[i], 1, 150), substr(r$n1[i], 1, 150)))
