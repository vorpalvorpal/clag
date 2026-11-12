# Package 4a: history cases (dev/design-4.md G17, H6-H9, F6): unborn HEAD, detached HEAD, merge, amend,
# cherry-pick and rebase (git runs no commit-msg hook for the last two).

hist_note_first <- "first commit: findings are not compared, so this commit is the starting point (rule 6.2.5)"

# ---- unborn HEAD (F6, H6) ---------------------------------------------------------------------------------------

test_that("4a G17, F6: on an unborn HEAD the findings are not compared; the first commit is the starting point", {
  d <- g_repo(list("ch1.qmd" = g_num_doc(c("45%", "37%"))), commit = FALSE)
  g_add(d)
  expect_false(g_git(d, "rev-parse", "-q", "--verify", "HEAD^{commit}") |> attr("status") |> identical(0L))   # premise
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$excess), 0L)
  expect_identical(nrow(res$added), 0L)
  expect_true(hist_note_first %in% res$notes)
  expect_true(paste0("commit-msg: note: ", hist_note_first) %in% g_report(res))
})

test_that("4a G17: on an unborn HEAD a construct error still fails", {
  d <- g_repo(list("ch1.qmd" = g_bad_doc()), commit = FALSE)
  g_add(d)
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$errors), 1L)
})

test_that("4a G17: on an unborn HEAD nothing is removed, so a trailer is not demanded and is ignored", {
  d <- g_repo(list("ch1.qmd" = g_vals(c("a1", "a2"))), commit = FALSE)
  g_add(d)
  res <- g_gate(d, c("First commit", "", "Weft-Removed: 4"))
  expect_true(res$ok)
  expect_identical(max(0, res$n_removed), 0)
  expect_identical(nrow(res$removed), 0L)
})

test_that("4a G17: on an unborn HEAD with nothing staged the gate passes", {
  d <- g_repo(list("ch1.qmd" = g_num_doc("45%")), commit = FALSE)
  expect_true(g_gate(d)$ok)
})

test_that("4a G17: the unborn-HEAD note is only given when HEAD is unborn", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = c(G_PROSE, "", "More.")))
  expect_false(hist_note_first %in% g_gate(d)$notes)
})

# ---- detached HEAD -------------------------------------------------------------------------------------------------

test_that("4a G17: a detached HEAD is nothing special", {
  d <- g_repo(list("ch1.qmd" = g_num_doc("45%")))
  g_ok_git(d, "checkout", "-q", "--detach")
  g_write(d, "ch1.qmd", c(g_num_doc("45%"), "", "Edited."))
  g_add(d)
  res <- g_gate(d)
  expect_true(res$ok)
  expect_length(res$notes, 0L)
  g_write(d, "ch1.qmd", g_num_doc(c("45%", "45%")))
  g_add(d)
  expect_false(g_gate(d)$ok)
})

# ---- merge (H7) --------------------------------------------------------------------------------------------------------

# base committed on main; `feature` applied on a branch and committed; `main_after` applied on main and
# committed; then `git merge --no-commit --no-ff feature`, which leaves MERGE_HEAD and the merged index
merge_repo <- function(base, feature, main_after, env = parent.frame()) {
  d <- g_repo(base, env = env)
  g_ok_git(d, "checkout", "-q", "-b", "feature")
  g_apply(d, feature)
  g_add(d)
  g_commit(d, "feature")
  g_ok_git(d, "checkout", "-q", "main")
  g_apply(d, main_after)
  g_add(d)
  g_commit(d, "main work")
  g_git(d, "merge", "--no-commit", "--no-ff", "feature")
  stopifnot(file.exists(file.path(d, ".git", "MERGE_HEAD")))
  d
}

test_that("4a G17: a merge whose other parent added a finding passes (that branch was gated on its own)", {
  d <- merge_repo(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE),
                  list("ch2.qmd" = g_num_doc("45%")),
                  list("ch1.qmd" = c(G_PROSE, "", "Main branch sentence.")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$excess), 0L)
})

test_that("4a G17: a merge whose resolution adds a finding fails (excess is against the maximum over the parents)", {
  d <- merge_repo(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE),
                  list("ch2.qmd" = g_num_doc("45%")),
                  list("ch1.qmd" = c(G_PROSE, "", "Main branch sentence.")))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Main branch sentence.", "", "Flow rose by 45% in May."))
  g_add(d)
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$excess$text, "45%")
  expect_identical(as.integer(res$excess$base), 1L)
  expect_identical(as.integer(res$excess$new), 2L)
})

test_that("4a G17: a merge where both parents held the finding and the merge adds a different one fails", {
  d <- merge_repo(list("ch1.qmd" = g_num_doc("45%"), "ch2.qmd" = G_PROSE),
                  list("ch2.qmd" = c(G_PROSE, "", "Feature sentence.")),
                  list("ch1.qmd" = c(g_num_doc("45%"), "", "Main sentence.")))
  expect_true(g_gate(d)$ok)
  g_write(d, "ch2.qmd", c(G_PROSE, "", "Feature sentence.", "", "A rise of 12% followed."))
  g_add(d)
  expect_false(g_gate(d)$ok)
})

test_that("4a G17: a merge whose other branch removed constructs needs no trailer (N is the minimum over the parents)", {
  base <- list("ch1.qmd" = G_PROSE, "ch2.qmd" = g_vals(c("a1", "a2", "a3")))
  d <- merge_repo(base,
                  list("ch2.qmd" = g_vals(c("a1", "a2"))),          # feature dropped a construct
                  list("ch1.qmd" = c(G_PROSE, "", "Main sentence.")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(max(0, res$n_removed), 0)
})

test_that("4a G17: a merge that itself removes constructs from both parents needs the trailer", {
  base <- list("ch1.qmd" = G_PROSE, "ch2.qmd" = g_vals(c("a1", "a2", "a3")))
  d <- merge_repo(base,
                  list("ch2.qmd" = g_vals(c("a1", "a2"))),
                  list("ch1.qmd" = c(G_PROSE, "", "Main sentence.")))
  g_write(d, "ch2.qmd", g_vals("a1"))                               # the resolution drops one more
  g_add(d)
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_true(g_gate(d, c("Merge feature", "", "Weft-Removed: 1"))$ok)
})

test_that("4a G17: the merge message file (MERGE_MSG) is read for the trailer", {
  base <- list("ch1.qmd" = G_PROSE, "ch2.qmd" = g_vals(c("a1", "a2", "a3")))
  d <- merge_repo(base, list("ch2.qmd" = g_vals(c("a1", "a2"))), list("ch1.qmd" = c(G_PROSE, "", "Main sentence.")))
  g_write(d, "ch2.qmd", g_vals("a1"))
  g_add(d)
  merge_msg <- file.path(d, ".git", "MERGE_MSG")
  expect_true(file.exists(merge_msg))
  cat("\nWeft-Removed: 1\n", file = merge_msg, append = TRUE)
  expect_true(g_gate(d, merge_msg)$ok)
})

# ---- amend (H8) ---------------------------------------------------------------------------------------------------------

test_that("4a G17: an amend is compared with HEAD, the commit being replaced: only the amendment is judged", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", g_num_doc("45%"))                           # HEAD itself holds a finding
  g_add(d)
  g_commit(d, "Add a finding")
  g_write(d, "ch1.qmd", c(g_num_doc("45%"), "", "Amended sentence."))
  g_add(d)
  expect_true(g_gate(d)$ok)                                         # unchanged finding: the amendment is clean
  g_write(d, "ch1.qmd", g_num_doc(c("45%", "37%")))
  g_add(d)
  expect_false(g_gate(d)$ok)                                        # the amendment adds one
})

test_that("4a G17, 6.3.2: an earlier trailer that no longer matches the amended count fails; the report says what to write", {
  d <- g_repo(list("ch1.qmd" = g_vals(c("a1", "a2", "a3", "a4"))))
  g_write(d, "ch1.qmd", g_vals(c("a1", "a2")))                      # HEAD removes two
  g_add(d)
  g_commit(d, "Drop two\n\nWeft-Removed: 2")
  g_write(d, "ch1.qmd", g_vals("a1"))                               # the amendment removes one more
  g_add(d)
  res <- g_gate(d, c("Drop two", "", "Weft-Removed: 2"))            # the old trailer, kept by the amend
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$trailer, 2L)
  rep <- g_report(res)
  expect_true("commit-msg: 1 weft construct removed, and the message says Weft-Removed: 2" %in% rep ||
                any(grepl("^commit-msg: 1 weft constructs? removed, and the message says Weft-Removed: 2$", rep)))
  expect_true("Weft-Removed: 1" %in% trimws(rep))
  expect_true(g_gate(d, c("Drop three", "", "Weft-Removed: 1"))$ok)
})

test_that("4a G17: an amend that removes nothing ignores the old trailer", {
  d <- g_repo(list("ch1.qmd" = g_vals(c("a1", "a2", "a3"))))
  g_write(d, "ch1.qmd", g_vals("a1"))
  g_add(d)
  g_commit(d, "Drop two")
  g_write(d, "ch1.qmd", c(g_vals("a1"), "", "Amended sentence."))
  g_add(d)
  expect_true(g_gate(d, c("Drop two", "", "Weft-Removed: 2"))$ok)
})

# ---- cherry-pick and rebase: git runs no hook (pinned) ----------------------------------------------------------------

hook_repo <- function(env = parent.frame()) {
  d <- g_repo(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE), env = env)
  hook <- file.path(d, ".git", "hooks", "commit-msg")
  dir.create(dirname(hook), showWarnings = FALSE)
  marker <- file.path(d, ".git", "hook-ran")
  writeLines(c("#!/bin/sh", paste0("echo ran >> '", marker, "'"), "exit 0"), hook)
  Sys.chmod(hook, "755")
  list(dir = d, marker = marker)
}

test_that("4a G17, H9: git commit runs commit-msg, git cherry-pick does not (so verify(since = ) is the check)", {
  skip_on_os("windows")
  h <- hook_repo()
  d <- h$dir
  g_ok_git(d, "checkout", "-q", "-b", "other")
  g_write(d, "ch2.qmd", c(G_PROSE, "", "On the other branch."))
  g_add(d)
  g_ok_git(d, "commit", "-q", "-m", "other work")                  # a real commit: the hook runs
  expect_true(file.exists(h$marker))                                # the control
  unlink(h$marker)
  g_ok_git(d, "checkout", "-q", "main")
  g_ok_git(d, "cherry-pick", "other")
  expect_false(file.exists(h$marker))
})

test_that("4a G17, H9: git rebase does not run commit-msg either", {
  skip_on_os("windows")
  h <- hook_repo()
  d <- h$dir
  g_ok_git(d, "checkout", "-q", "-b", "other")
  g_write(d, "ch2.qmd", c(G_PROSE, "", "On the other branch."))
  g_add(d)
  g_ok_git(d, "commit", "-q", "-m", "other work")
  g_ok_git(d, "checkout", "-q", "main")
  g_write(d, "ch1.qmd", c(G_PROSE, "", "On main."))
  g_add(d)
  g_ok_git(d, "commit", "-q", "-m", "main work")
  unlink(h$marker)
  g_ok_git(d, "checkout", "-q", "other")
  g_ok_git(d, "rebase", "main")
  expect_false(file.exists(h$marker))
})
