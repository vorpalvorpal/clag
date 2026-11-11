source("lib.R"); source("manuscript.R"); source("edits.R")
dir.create("out/edits", showWarnings = FALSE)
lb <- render_doc(D0, 72); writeLines(lb, "out/manuscript.qmd")
score <- function(exp, act_keys) {
  miss <- ms_diff(exp, act_keys); extra <- ms_diff(act_keys, exp)
  list(miss = miss, extra = extra,
       false_rm = sum(grepl("^removed >> ", extra)), missed_rm = sum(grepl("^removed >> ", miss)),
       correct = !length(miss) && !length(extra))
}
sh <- function(k, max = 4) { if (!length(k)) return("-")
  f <- function(x) { p <- strsplit(x, " >> ", fixed = TRUE)[[1]]; sx <- function(z) sub("\\|num$", "", sub("^v:", "", z))
    switch(p[1], edited = sprintf("E[%s -> %s]", sx(p[2]), sx(p[3])), removed = sprintf("R[%s]", sx(p[2])), added = sprintf("A[%s]", sx(p[2]))) }
  v <- vapply(sort(k), f, ""); if (length(v) > max) paste0(paste(v[1:max], collapse = ", "), sprintf(", +%d more", length(v) - max)) else paste(v, collapse = ", ") }
rows <- list(); detail <- character()
for (e in EDITS) {
  la <- render_doc(e$f(D0), e$width, e$hash_safe); writeLines(la, file.path("out/edits", paste0(e$id, ".qmd")))
  e$exp <- if (is.function(e$exp)) unname(e$exp(lb, la)) else e$exp
  r <- list()
  for (mode in c("one", "equal", "verify", "sim")) {
    m <- match_versions(lb, la, gap = if (mode %in% c("equal", "sim")) mode else "one", verify = mode %in% c("verify", "sim")); ak <- ev_keys(m$events); s <- score(e$exp, ak)
    ## what was reported instead for each missed removal
    why <- vapply(grep("^removed >> ", s$miss, value = TRUE), function(k) { id <- sub("^removed >> ", "", sub(" >> $", "", k))
      hit <- Filter(function(x) x$status != "unchanged" && (x$id == id || identical(x$after, id)), m$events)
      if (length(hit)) paste(vapply(hit, function(x) paste(x$status, x$id, if (nzchar(x$after)) paste0("->", x$after)), ""), collapse = "; ") else "nothing" }, "")
    r[[mode]] <- list(s = s, ak = ak, why = why, m = m)
  }
  ml <- match_versions(lb, la, "one", strict = FALSE); sl <- score(e$exp, ev_keys(ml$events))
  bk <- R_(baseline_removals(lb, la)); bs <- score(e$exp[grepl("^removed", e$exp)], bk)
  o <- r$one; q <- r$equal; v <- r$verify; sm <- r$sim
  dir <- if (o$s$missed_rm) "MISSED removal" else if (o$s$false_rm) "false removal" else if (!o$s$correct) "other" else "ok"
  rows[[e$id]] <- data.frame(id = e$id, desc = e$desc, expected = sh(e$exp), matcher_one = sh(o$ak), matcher_equal = sh(q$ak), n_truth_rm = sum(grepl("^removed", e$exp)),
    one_correct = o$s$correct, one_false = o$s$false_rm, one_missed = o$s$missed_rm, one_dir = dir,
    sim_correct = sm$s$correct, sim_false = sm$s$false_rm, sim_missed = sm$s$missed_rm, sim_acks = sum(grepl("^removed", sm$ak)), sim_expl = sh(c(sm$s$miss, sm$s$extra)),
    ver_correct = v$s$correct, ver_false = v$s$false_rm, ver_missed = v$s$missed_rm,
    eq_correct = q$s$correct, eq_false = q$s$false_rm, eq_missed = q$s$missed_rm,
    len_correct = sl$correct, len_false = sl$false_rm, len_missed = sl$missed_rm,
    base_acks = length(bk), one_acks = sum(grepl("^removed", o$ak)), eq_acks = sum(grepl("^removed", q$ak)),
    base_false = bs$false_rm, base_missed = bs$missed_rm, sem = e$sem, stringsAsFactors = FALSE)
  detail <- c(detail, sprintf("== %s: %s", e$id, e$desc), paste("  expected :", if (length(e$exp)) paste(e$exp, collapse = " | ") else "(no events)"),
    paste("  matcher  :", if (length(o$ak)) paste(o$ak, collapse = " | ") else "(no events)"),
    if (!o$s$correct) paste("  one-mode :", dir, "| missing:", paste(o$s$miss, collapse = " | "), "| extra:", paste(o$s$extra, collapse = " | ")),
    if (length(o$why)) paste("  missed-removal reported as:", paste(o$why, collapse = " ; ")),
    paste("  sim-variant:", if (sm$s$correct) "correct" else paste("missing:", paste(sm$s$miss, collapse = " | "), "| extra:", paste(sm$s$extra, collapse = " | "))),
    paste("  equal-gap:", if (q$s$correct) "correct" else paste("missing:", paste(q$s$miss, collapse = " | "), "| extra:", paste(q$s$extra, collapse = " | "))),
    if (!identical(sl$correct, o$s$correct)) paste("  lenient-scan (newline after `r read as space) result:", if (sl$correct) "correct" else paste("missing:", paste(sl$miss, collapse = " | "), "| extra:", paste(sl$extra, collapse = " | "))),
    paste("  baseline (no matching) acks:", length(bk), if (length(bk)) paste(":", paste(bk, collapse = " | "))), "")
}
T <- do.call(rbind, rows); rownames(T) <- NULL
write.csv(T, "out/results.csv", row.names = FALSE); writeLines(detail, "out/per-edit.txt")
cat("edits:", nrow(T), "\n")
for (md in c("one", "eq", "ver", "sim")) {
  cat(sprintf("\n[%s] correct=%d  false-removals(events)=%d in %d edits  missed-removals(events)=%d in %d edits\n", md, sum(T[[paste0(md, "_correct")]]),
      sum(T[[paste0(md, "_false")]]), sum(T[[paste0(md, "_false")]] > 0), sum(T[[paste0(md, "_missed")]]), sum(T[[paste0(md, "_missed")]] > 0)))
}
cat(sprintf("\n[lenient scan, one] correct=%d false=%d missed=%d\n", sum(T$len_correct), sum(T$len_false), sum(T$len_missed)))
cat(sprintf("\nacks: truth=%d  matcher(one)=%d  matcher(equal)=%d  baseline(no matching)=%d\n", sum(T$n_truth_rm), sum(T$one_acks), sum(T$eq_acks), sum(T$base_acks)))
cat(sprintf("baseline: false=%d (in %d edits) missed=%d\n", sum(T$base_false), sum(T$base_false > 0), sum(T$base_missed)))
print(T[!T$one_correct, c("id", "one_dir", "one_false", "one_missed", "eq_correct", "eq_false", "eq_missed", "ver_correct", "ver_missed")], row.names = FALSE)
