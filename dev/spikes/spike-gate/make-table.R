## Markdown table of the per-edit results (from out/results.csv) -> out/edit-table.md
T <- read.csv("out/results.csv", stringsAsFactors = FALSE)
esc <- function(x) gsub("\\|", "\\\\|", x)
dir_of <- function(r) if (r$one_missed > 0) "MISSED removal" else if (r$one_false > 0) "false removal" else if (!r$one_correct) "other" else "ok"
L <- c("| id | edit | correct answer | matcher (proposal) | error direction | equal-gap variant | +verify | no-matching acks (truth) |",
       "|---|---|---|---|---|---|---|---|")
for (i in seq_len(nrow(T))) { r <- T[i, ]
  eqs <- if (r$eq_correct) "ok" else sprintf("%s (fr %d, mr %d)", if (r$eq_missed > 0) "MISSED" else "false", r$eq_false, r$eq_missed)
  vs <- if (r$ver_correct) "ok" else sprintf("%s (fr %d, mr %d)", if (r$ver_missed > 0) "MISSED" else "false", r$ver_false, r$ver_missed)
  L <- c(L, sprintf("| %s | %s | %s | %s | %s | %s | %s | %d (%d) |", r$id, esc(r$desc), esc(r$expected), esc(r$matcher_one), dir_of(r), eqs, vs, r$base_acks, r$n_truth_rm))
}
writeLines(L, "out/edit-table.md"); cat(length(L) - 2, "rows\n")
