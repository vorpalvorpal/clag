T <- read.csv("out/results.csv", stringsAsFactors = FALSE)
agg <- function(T, lab) { cat(sprintf("\n### %s (%d edits)\n", lab, nrow(T)))
  r <- data.frame(variant = c("proposal (gap=1:1)", "variant: equal-size gaps pair", "proposal + verify ids on identical text", "variant: similarity pairing (+verify)", "no matching (baseline)"),
    correct = c(sum(T$one_correct), sum(T$eq_correct), sum(T$ver_correct), sum(T$sim_correct), NA),
    edits_with_false_removal = c(sum(T$one_false > 0), sum(T$eq_false > 0), sum(T$ver_false > 0), sum(T$sim_false > 0), sum(T$base_false > 0)),
    false_removal_events = c(sum(T$one_false), sum(T$eq_false), sum(T$ver_false), sum(T$sim_false), sum(T$base_false)),
    edits_with_missed_removal = c(sum(T$one_missed > 0), sum(T$eq_missed > 0), sum(T$ver_missed > 0), sum(T$sim_missed > 0), sum(T$base_missed > 0)),
    missed_removal_events = c(sum(T$one_missed), sum(T$eq_missed), sum(T$ver_missed), sum(T$sim_missed), sum(T$base_missed)),
    acknowledgements_demanded = c(sum(T$one_acks), sum(T$eq_acks), NA, sum(T$sim_acks), sum(T$base_acks)))
  print(r, row.names = FALSE); cat("truth acknowledgements:", sum(T$n_truth_rm), "\n") }
agg(T, "all edits"); agg(T[T$id != "E16b", ], "excluding E16b (reflow that changes the parse)")
