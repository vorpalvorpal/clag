# 4b: the commit-msg hook run by real `git commit` commands in temporary repositories (G19-G21, H7, H8,
# H11, H31, F1). Needs gate() (package 4a) and use_hooks(): these tests fail until both exist.
#
# The hook records the installing session's libraries (G21), so the working tree's installed copy
# (weft_test_lib()) is what the hook's R loads. The child environment is the one h4_env() makes: no
# project profile, empty user and site libraries, a temporary cache folder.
#
# READINGS ASSUMED:
#   - a clean commit prints the pass line of G20, "commit-msg: weft passed", on stderr;
#   - the "R missing" and "weft missing" cases are arranged by editing the recorded `weft_rscript` and
#     `weft_libs` values of the installed hook (the hook sets R_LIBS itself, so the environment alone
#     cannot hide weft from it), and by a PATH that holds git but no Rscript;
#   - an amend is judged against HEAD (the amended commit) as the design says (H8).

hc_repo <- function(files = list("ch1.qmd" = G_PROSE), env = parent.frame(), ...) {
  skip_on_os("windows")
  dir <- h4_repo(files, env = env, ...)
  h4_hooks(dir)
  dir
}

test_that("4b G21: a clean commit passes, prints the pass line, and the commit is made", {
  dir <- hc_repo()
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "One more sentence.")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 0L)
  expect_true(r$moved)
  expect_match(r$out, "commit-msg: weft passed", fixed = TRUE)
})

test_that("4b G19/G20: a commit adding a construct error is refused: status non-zero, the report on stderr, HEAD unchanged", {
  dir <- hc_repo()
  g_apply(dir, list("ch1.qmd" = g_bad_doc()))
  g_add(dir)
  r <- h4_commit_split(dir)
  expect_false(identical(r$status, 0L))
  expect_match(r$stderr, "commit-msg: 1 construct error", fixed = TRUE)
  expect_match(r$stderr, "ch1.qmd", fixed = TRUE)
  expect_match(r$stderr, "construct", fixed = TRUE)
  expect_false(grepl("commit-msg:", r$stdout, fixed = TRUE))
  expect_identical(g_ok_git(dir, "rev-list", "--count", "HEAD")[1], "1")
  # what was staged stays staged
  expect_match(paste(g_ok_git(dir, "diff", "--cached", "--name-only"), collapse = "\n"), "ch1.qmd", fixed = TRUE)
})

test_that("4b G20: the status is exactly 1 on a refusal (git reports the hook's status)", {
  dir <- hc_repo()
  g_apply(dir, list("ch1.qmd" = g_bad_doc()))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 1L)
  expect_false(r$moved)
})

test_that("4b G10: a commit adding a typed numeral is refused with the findings-added report", {
  dir <- hc_repo()
  g_apply(dir, list("ch1.qmd" = g_num_doc("45%")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 1L)
  expect_match(r$out, "1 finding added that HEAD did not hold", fixed = TRUE)
  expect_match(r$out, "45%", fixed = TRUE)
})

test_that("4b G10: a finding already in HEAD does not stop an unrelated edit", {
  dir <- hc_repo(list("ch1.qmd" = g_num_doc("45%")))
  g_apply(dir, list("ch1.qmd" = c(g_num_doc("45%"), "", "Edited.")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 0L)
  expect_true(r$moved)
})

test_that("4b G8: git commit --no-verify skips the hook, even with a construct error", {
  dir <- hc_repo()
  g_apply(dir, list("ch1.qmd" = g_bad_doc()))
  g_add(dir)
  r <- h4_commit(dir, args = "--no-verify")
  expect_identical(r$status, 0L)
  expect_true(r$moved)
  expect_false(grepl("commit-msg:", r$out, fixed = TRUE))
})

test_that("4b G13: removing constructs without the trailer is refused; the report names the trailer to add", {
  vals <- g_vals(c("rain_mean", "n_sites", "depth_max"))
  dir <- hc_repo(list("ch1.qmd" = vals))
  g_apply(dir, list("ch1.qmd" = vals[1:3]))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 1L)
  expect_false(r$moved)
  expect_match(r$out, "1 weft construct removed, and the message does not say so", fixed = TRUE)
  expect_match(r$out, "Weft-Removed: 1", fixed = TRUE)
})

test_that("4b G13: the trailer in the message lets the same commit through", {
  vals <- g_vals(c("rain_mean", "n_sites", "depth_max"))
  dir <- hc_repo(list("ch1.qmd" = vals))
  g_apply(dir, list("ch1.qmd" = vals[1:3]))
  g_add(dir)
  r <- h4_commit(dir, msg_args = c("-m", "Drop a paragraph", "-m", "Weft-Removed: 1"))
  expect_identical(r$status, 0L)
  expect_true(r$moved)
})

test_that("4b G20: git commit --trailer 'Weft-Removed: 1' passes the same commit", {
  vals <- g_vals(c("rain_mean", "n_sites", "depth_max"))
  dir <- hc_repo(list("ch1.qmd" = vals))
  g_apply(dir, list("ch1.qmd" = vals[1:3]))
  g_add(dir)
  r <- h4_commit(dir, args = c("--trailer", "Weft-Removed: 1"), msg = "Drop a paragraph")
  expect_identical(r$status, 0L)
  expect_true(r$moved)
})

test_that("4b G13: a wrong count in the trailer is refused", {
  vals <- g_vals(c("rain_mean", "n_sites", "depth_max"))
  dir <- hc_repo(list("ch1.qmd" = vals))
  g_apply(dir, list("ch1.qmd" = vals[1:3]))
  g_add(dir)
  r <- h4_commit(dir, msg_args = c("-m", "Drop", "-m", "Weft-Removed: 2"))
  expect_identical(r$status, 1L)
  expect_match(r$out, "the message says Weft-Removed: 2", fixed = TRUE)
})

# ---- merge and amend (H7, H8) --------------------------------------------------------------------

test_that("4b H7: a merge whose other parent added a finding passes (each side was gated on its own branch)", {
  skip_on_os("windows")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE))
  g_ok_git(dir, "checkout", "-q", "-b", "side")
  g_apply(dir, list("ch2.qmd" = g_num_doc("45%")))
  g_add(dir)
  g_commit(dir, "side adds a numeral")
  g_ok_git(dir, "checkout", "-q", "main")
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "Main edit.")))
  g_add(dir)
  g_commit(dir, "main edit")
  h4_hooks(dir)
  out <- g_git(dir, "merge", "--no-ff", "-m", "merge side", "side")
  expect_identical(attr(out, "status"), 0L)
  expect_identical(g_ok_git(dir, "rev-list", "--count", "--merges", "HEAD")[1], "1")
})

test_that("4b H7: a merge whose conflict resolution adds a finding is refused", {
  skip_on_os("windows")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  g_ok_git(dir, "checkout", "-q", "-b", "side")
  g_apply(dir, list("ch1.qmd" = c("Side sentence.", G_PROSE[-1])))
  g_add(dir); g_commit(dir, "side")
  g_ok_git(dir, "checkout", "-q", "main")
  g_apply(dir, list("ch1.qmd" = c("Main sentence.", G_PROSE[-1])))
  g_add(dir); g_commit(dir, "main")
  h4_hooks(dir)
  out <- g_git(dir, "merge", "-m", "merge side", "side")
  expect_false(identical(attr(out, "status"), 0L))   # the conflict
  g_apply(dir, list("ch1.qmd" = g_num_doc("77%", lead = "Resolved.")))
  g_add(dir)
  r <- h4_commit(dir, msg = "resolve")
  expect_identical(r$status, 1L)
  expect_match(r$out, "77%", fixed = TRUE)
  expect_true(file.exists(file.path(dir, ".git", "MERGE_HEAD")))
})

test_that("4b H8: an amend is judged against HEAD, the amended commit: an unrelated amendment passes though HEAD holds a finding", {
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  g_apply(dir, list("ch1.qmd" = g_num_doc("45%")))
  g_add(dir)
  g_commit(dir, "adds a numeral")          # no hook yet: HEAD holds a finding
  h4_hooks(dir)
  g_apply(dir, list("ch1.qmd" = c(g_num_doc("45%"), "", "Edited.")))
  g_add(dir)
  r <- h4_commit(dir, msg = "adds a numeral, edited", args = "--amend")
  expect_identical(r$status, 0L)
  expect_identical(g_ok_git(dir, "rev-list", "--count", "HEAD")[1], "2")
})

test_that("4b H8: an amend that adds a finding on top of HEAD is refused", {
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  g_apply(dir, list("ch1.qmd" = g_num_doc("45%")))
  g_add(dir)
  g_commit(dir, "adds a numeral")
  h4_hooks(dir)
  g_apply(dir, list("ch1.qmd" = g_num_doc(c("45%", "37%"))))
  g_add(dir)
  r <- h4_commit(dir, msg = "more", args = "--amend")
  expect_identical(r$status, 1L)
  expect_match(r$out, "37%", fixed = TRUE)
})

# ---- the hook's own environment (G21, H11, H31, F1) ----------------------------------------------

test_that("4b F1/G21: Rscript gone at the recorded path and not on the PATH: the commit fails, the message names use_hooks() and --no-verify", {
  path <- h4_path_without_rscript()
  skip_if(is.null(path), "Rscript shares a PATH folder with git here")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  gone <- file.path(withr::local_tempdir(), "no-such-dir", "Rscript")
  h4_hooks(dir, rscript = gone)
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "More.")))
  g_add(dir)
  r <- withr::with_envvar(c(PATH = path), h4_commit(dir))
  expect_identical(r$status, 1L)
  expect_false(r$moved)
  expect_match(r$out, "commit-msg: weft cannot find R:", fixed = TRUE)
  expect_match(r$out, gone, fixed = TRUE)
  expect_match(r$out, "use_hooks()", fixed = TRUE)
  expect_match(r$out, "--no-verify", fixed = TRUE)
})

test_that("4b G21: a recorded Rscript that is gone falls back to the Rscript on the PATH, and the gate runs", {
  skip_if(!nzchar(Sys.which("Rscript")), "no Rscript on the PATH")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  gone <- file.path(withr::local_tempdir(), "no-such-dir", "Rscript")
  h4_hooks(dir, rscript = gone)
  g_apply(dir, list("ch1.qmd" = g_bad_doc()))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 1L)
  expect_match(r$out, "commit-msg: 1 construct error", fixed = TRUE)
  expect_false(grepl("cannot find R", r$out, fixed = TRUE))
})

test_that("4b F1/G21: weft not installed in the library the hook's R sees: the commit fails, the message names use_hooks() and --no-verify", {
  skip_if(dir.exists(file.path(.Library, "weft")), "weft is in R's own library here")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  h4_hooks(dir)
  # point the recorded libraries at a folder with no weft in it (the hook sets R_LIBS from this line)
  hp <- h4_hook_path(dir)
  empty <- normalizePath(withr::local_tempdir())
  x <- readLines(hp)
  i <- grep("^weft_libs=", x)
  expect_length(i, 1L)
  x[i] <- paste0("weft_libs='", empty, "'")
  writeLines(x, hp)
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "More.")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 1L)
  expect_false(r$moved)
  expect_match(r$out, "commit-msg: weft is not installed for the R at ", fixed = TRUE)
  expect_match(r$out, "use_hooks()", fixed = TRUE)
  expect_match(r$out, "--no-verify", fixed = TRUE)
})

test_that("4b H31: the hook runs R with --no-init-file: the project's .Rprofile does not run", {
  dir <- hc_repo(list("ch1.qmd" = G_PROSE, ".Rprofile" = "cat('PROFILE-RAN\\n'); stop('profile')"))
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "More.")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 0L)
  expect_false(grepl("PROFILE-RAN", r$out, fixed = TRUE))
})

test_that("4b G21: a repository in a path with a space and a quote, and a library with a quote, commit and refuse correctly", {
  skip_on_os("windows")
  dir <- h4_repo_named("my repo's \"dir\"", list("ch1.qmd" = G_PROSE))
  qlib <- file.path(withr::local_tempdir(), "it's a lib")
  dir.create(qlib)
  h4_hooks(dir, lib = c(qlib, h4_lib()))
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "More.")))
  g_add(dir)
  ok <- h4_commit(dir, "clean")
  expect_identical(ok$status, 0L)
  expect_match(ok$out, "commit-msg: weft passed", fixed = TRUE)
  g_apply(dir, list("ch1.qmd" = g_bad_doc()))
  g_add(dir)
  bad <- h4_commit(dir, "bad")
  expect_identical(bad$status, 1L)
  expect_match(bad$out, "commit-msg: 1 construct error", fixed = TRUE)
})

test_that("4b G22: the hook installed from a linked worktree runs for commits made in that worktree", {
  skip_on_os("windows")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  wt <- file.path(withr::local_tempdir(), "wt")
  g_ok_git(dir, "worktree", "add", "-q", "-b", "wt-branch", wt)
  wt <- normalizePath(wt)
  h4_hooks(wt)
  g_apply(wt, list("ch1.qmd" = g_bad_doc()))
  g_add(wt)
  r <- h4_commit(wt)
  expect_identical(r$status, 1L)
  expect_match(r$out, "commit-msg: 1 construct error", fixed = TRUE)
})

test_that("4b G3: committing through the hook writes nothing in HOME, the cache folder or the repository's parent", {
  skip_on_os("windows")
  rp <- h4_repo_in_parent(list("ch1.qmd" = G_PROSE))
  h4_hooks(rp$dir)
  before <- h4_outside_snap(rp$parent)
  g_apply(rp$dir, list("ch1.qmd" = c(G_PROSE, "", "More.")))
  g_add(rp$dir)
  h4_commit(rp$dir)
  expect_identical(h4_outside_snap(rp$parent), before)
})
