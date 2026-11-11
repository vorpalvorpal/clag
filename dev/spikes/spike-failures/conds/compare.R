rd <- function(f) { r <- readRDS(f); r <- r[r$kind != "error", ]; r$key <- paste(r$id, ave(seq_along(r$id), r$id, FUN = seq_along), sep = "#"); r }
A <- rd("conds_raw.rds"); B <- rd("conds_raw_B.rds"); C <- rd("conds_raw_C.rds")
num <- "[-+]?(?:[0-9]+(?:\\.[0-9]+)*(?:[eE][-+]?[0-9]+)?|\\.[0-9]+(?:[eE][-+]?[0-9]+)?)"
n1 <- function(x) gsub(num, "<N>", x, perl = TRUE)
n2 <- function(x) {
  x <- gsub("\033\\[[0-9;]*m", "", x)                                   # ANSI
  x <- chartr("‘’“”", "''\"\"", x)                    # curly quotes
  x <- gsub("0x[0-9a-fA-F]+", "<ADDR>", x)                              # hex addresses
  x <- gsub("[^ '\"`]*/Rtmp[A-Za-z0-9]+/[^ '\"`]*", "<TMP>", x)         # temp paths
  x <- gsub("\u2500+|-{2,}", "--", x)                                    # cli rules
  x <- chartr("\u2139\u2022\u2716\u2714", "i*xv", x)                         # cli bullets (info, bullet, cross, tick) -> ASCII fallbacks
  x <- gsub("[[:space:]]+", " ", x)                                     # wrapping
  n1(trimws(x))
}
cmp <- function(X, Y, nm) {
  m <- merge(X[c("key", "text")], Y[c("key", "text")], by = "key", suffixes = c(".x", ".y"))
  m$raw <- m$text.x == m$text.y; m$n1 <- n1(m$text.x) == n1(m$text.y); m$n2 <- n2(m$text.x) == n2(m$text.y)
  cat(sprintf("%s: %d paired conditions; identical raw %d, after N1 (digits only) %d, after N2 (digits+ANSI+quotes+tmp+hex+whitespace) %d\n", nm, nrow(m), sum(m$raw), sum(m$n1), sum(m$n2)))
  list(raw = m$key[!m$raw], n1 = m$key[!m$n1], n2 = m$key[!m$n2], m = m)
}
ac <- cmp(A, C, "run A vs run C (same settings, new process)")
ab <- cmp(A, B, "run A vs run B (width 60, cli.unicode FALSE, fancy quotes off)")
cat("\nA vs C, differing raw:\n"); print(ac$raw)
cat("A vs C, still differing after N1:\n"); print(ac$n1)
cat("A vs C, still differing after N2:\n"); print(ac$n2)
cat("\nA vs B, differing raw:\n"); print(ab$raw)
cat("A vs B, still differing after N1:\n"); print(ab$n1)
cat("A vs B, still differing after N2:\n"); print(ab$n2)
## collisions: distinct raw texts that normalise to the same string, in the whole pool
P <- unique(rbind(A[c("id", "text")], B[c("id", "text")], C[c("id", "text")])); P$n <- n1(P$text); P$n2 <- n2(P$text)
g <- split(P, P$n2); g <- g[vapply(g, function(d) length(unique(d$text)) > 1 && length(unique(n2(d$text))) == 1, NA)]
cat("\nCollision groups (distinct raw texts -> same N2 key): ", length(g), "\n")
for (d in g) { cat("--- key:", gsub("\n", "\\\\n", substr(d$n2[1], 1, 110)), "\n"); for (i in seq_len(nrow(d))) cat("     ", d$id[i], "|", gsub("\n", "\\\\n", substr(d$text[i], 1, 120)), "\n") }
saveRDS(list(A = A, B = B, C = C), "abc.rds")
