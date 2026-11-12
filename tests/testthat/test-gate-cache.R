# Package 4a: the cache (dev/design-4.md G14, H1, H13). Layers src (needs G4a, the lint reader hook of stage 3),
# file and proj, kept under <git common dir>/weft/cache/ as <layer>-<key>.rds.
# The observable for "not re-read" is the number of calls to weft:::read_source() (g_count_reads(), helper-4a.R).

local_cache <- function(on = TRUE, env = parent.frame()) withr::local_options(weft.gate_cache = on, .local_envir = env)

warm_scenario <- function(env = parent.frame()) {
  g_scenario(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE, "ch3.qmd" = G_PROSE),
             list("ch1.qmd" = g_num_doc("45%")), env = env)
}

test_that("4a G14: the cache lives under the git common directory, as <layer>-<key>.rds, three layers", {
  local_cache()
  d <- warm_scenario()
  expect_false(dir.exists(file.path(d, ".git", "weft")))
  g_gate(d)
  files <- g_cache_files(d)
  expect_gt(length(files), 0L)
  expect_match(basename(files), "^(src|file|proj)-[0-9a-f]{32}\\.rds$")
  expect_setequal(unique(sub("-.*$", "", basename(files))), c("src", "file", "proj"))
  expect_identical(normalizePath(dirname(files[[1]])), normalizePath(file.path(d, ".git", "weft", "cache")))
  for (f in files) expect_no_error(readRDS(f))
})

test_that("4a G14: in a linked worktree the cache is in the main repository's git directory", {
  local_cache()
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  wt <- file.path(dirname(d), "linked")
  g_ok_git(d, "worktree", "add", "-q", "-b", "side", wt)
  g_write(wt, "ch1.qmd", g_num_doc("45%"))
  g_add(wt)
  res <- g_gate(wt)
  expect_false(res$ok)
  expect_gt(length(g_cache_files(d)), 0L)
  gitdir <- trimws(g_ok_git(wt, "rev-parse", "--absolute-git-dir"))
  expect_false(dir.exists(file.path(gitdir, "weft")))
  expect_false(dir.exists(file.path(wt, ".git", "weft")))
})

test_that("4a G14: the cache writes nothing into the work tree", {
  local_cache()
  d <- warm_scenario()
  before <- g_snapshot(d)
  g_gate(d)
  g_gate(d)
  expect_identical(g_snapshot(d), before)
  expect_identical(names(g_snapshot(d)), names(before))
})

test_that("4a G14: options(weft.gate_cache = FALSE) turns the cache off: nothing is written", {
  local_cache(FALSE)
  d <- warm_scenario()
  res <- g_gate(d)
  expect_false(res$ok)
  expect_false(dir.exists(file.path(d, ".git", "weft")))
  expect_length(g_cache_files(d), 0L)
})

test_that("4a G14: a second run gives the same answer and reads no document", {
  local_cache()
  d <- warm_scenario()
  n_cold <- g_count_reads(r1 <- g_gate(d))
  n_warm <- g_count_reads(r2 <- g_gate(d))
  expect_gt(n_cold, 0L)
  expect_identical(n_warm, 0L)                 # every entry hit: no side is materialised, no document read
  expect_identical(g_sig(r2), g_sig(r1))
})

test_that("4a G14: a commit that changes one document of several reads only that document", {
  local_cache()
  d <- g_repo(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE, "ch3.qmd" = G_PROSE, "ch4.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "First edit."))
  g_add(d)
  expect_true(g_gate(d)$ok)                      # warms HEAD's blobs for the next commit
  g_commit(d, "first edit")
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Second edit."))
  g_add(d)
  n <- g_count_reads(res <- g_gate(d))
  expect_true(res$ok)
  expect_lte(n, 1L)
})

test_that("4a G14: a changed document invalidates its entries: the new text is judged, not the old", {
  local_cache()
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Clean edit."))
  g_add(d)
  expect_true(g_gate(d)$ok)
  g_write(d, "ch1.qmd", g_num_doc("45%"))
  g_add(d)
  expect_false(g_gate(d)$ok)
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Clean again."))
  g_add(d)
  expect_true(g_gate(d)$ok)
})

test_that("4a G14, G8: a changed _weft.yml misses the document entries: every document is read again, and the answer is right", {
  local_cache()
  d <- g_repo(list("ch1.qmd" = "Samples came from Station 7.", "ch2.qmd" = G_PROSE, "ch3.qmd" = G_PROSE,
                   "_weft.yml" = c("draft: false", "label_words: [Station]")))
  g_write(d, "ch2.qmd", c(G_PROSE, "", "Clean edit."))
  g_add(d)
  expect_true(g_gate(d)$ok)                      # warm
  g_commit(d, "clean edit")
  g_write(d, "_weft.yml", "draft: false")        # the label word dropped: ch1's "7" is a finding now
  g_add(d)
  n <- g_count_reads(res <- g_gate(d))
  expect_false(res$ok)
  expect_true("7" %in% res$excess$text)
  expect_gte(n, 3L)
})

test_that("4a G14: another project file changing (a dictionary) misses the file layer", {
  local_cache()
  d <- g_repo(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE, "dict.yml" = "a_key: 1"))
  g_write(d, "ch2.qmd", c(G_PROSE, "", "Clean edit."))
  g_add(d)
  expect_true(g_gate(d)$ok)
  g_commit(d, "clean edit")
  g_write(d, "dict.yml", "a_key: 2")
  g_add(d)
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$excess), 0L)
})

test_that("4a G14: a corrupt entry is a miss, is deleted (and rewritten), and does not change the answer", {
  local_cache()
  d <- warm_scenario()
  r1 <- g_gate(d)
  files <- g_cache_files(d)
  for (f in files) writeBin(as.raw(c(1, 2, 3, 4, 5)), f)
  r2 <- g_gate(d)
  expect_identical(g_sig(r2), g_sig(r1))
  now <- g_cache_files(d)
  expect_gt(length(now), 0L)
  for (f in now) expect_no_error(readRDS(f))
})

test_that("4a G14: a hit touches the entry's time", {
  local_cache()
  d <- warm_scenario()
  g_gate(d)
  files <- g_cache_files(d)
  old <- Sys.time() - 86400
  Sys.setFileTime(files, old)
  g_gate(d)
  expect_true(all(file.mtime(files[file.exists(files)]) > old + 3600))
})

test_that("4a G14: after a run with more than 1,000 entries the oldest are deleted down to 800", {
  local_cache()
  d <- warm_scenario()
  g_gate(d)
  dir <- g_cache_dir(d)
  keys <- vapply(seq_len(1100L), function(i) cli::hash_md5(paste("fake", i)), "")
  fake <- file.path(dir, sprintf("file-%s.rds", keys))
  for (f in fake) saveRDS(1L, f)
  Sys.setFileTime(fake, Sys.time() - 7200 - seq_along(fake))        # fake[1] the newest of the fakes, fake[1100] the oldest
  ch2 <- c(G_PROSE, "", "Another edit.")
  g_write(d, "ch2.qmd", ch2)
  g_add(d)
  g_gate(d)
  left <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
  expect_identical(length(left), 800L)
  expect_false(file.exists(fake[[1100]]))                             # the oldest went
  expect_true(any(grepl("^(src|file|proj)-", basename(left)) & file.mtime(left) > Sys.time() - 600))   # this run's entries stayed
})

test_that("4a G14: a folder that cannot be written means no cache, and a note; the answer is unchanged", {
  local_cache()
  d <- warm_scenario()
  r_ref <- g_gate(d)
  unlink(file.path(d, ".git", "weft"), recursive = TRUE)
  writeLines("in the way", file.path(d, ".git", "weft"))              # a file where the folder must be
  res <- g_gate(d)
  expect_identical(g_sig(res)$ok, r_ref$ok)
  expect_identical(g_sig(res)$excess, g_sig(r_ref)$excess)
  expect_true(any(grepl("cache", res$notes, ignore.case = TRUE)))
})

test_that("4a G14: cache on cold, cache on warm and cache off give the same answer for every shared case", {
  for (cs in g_cases()) {
    d <- cs$build(environment())
    off <- withr::with_options(c(weft.gate_cache = FALSE), g_sig(g_gate(d, cs$msg)))
    expect_false(dir.exists(file.path(d, ".git", "weft")), label = paste("no cache dir:", cs$name))
    cold <- withr::with_options(c(weft.gate_cache = TRUE), g_sig(g_gate(d, cs$msg)))
    warm <- withr::with_options(c(weft.gate_cache = TRUE), g_sig(g_gate(d, cs$msg)))
    expect_identical(cold, off, label = paste("cold vs off:", cs$name))
    expect_identical(warm, off, label = paste("warm vs off:", cs$name))
    expect_identical(off$ok, cs$ok, label = paste("verdict:", cs$name))
  }
})

test_that("4a G14: a cache warmed on one commit does not leak into another repository's answer", {
  local_cache()
  a <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  b <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = c(G_PROSE, "", "Clean.")))
  expect_false(g_gate(a)$ok)
  expect_true(g_gate(b)$ok)
  expect_false(g_gate(a)$ok)
})

test_that("4a G3, G14: with the cache on, nothing is written outside the git directory and tempdir()", {
  local_cache()
  d <- warm_scenario()
  work <- g_snapshot(d)
  gitd <- g_git_snapshot(d)
  tmp <- sort(list.files(tempdir(), all.files = TRUE, no.. = TRUE))
  g_gate(d)
  expect_identical(g_snapshot(d), work)
  expect_identical(g_git_snapshot(d), gitd)
  expect_identical(sort(list.files(tempdir(), all.files = TRUE, no.. = TRUE)), tmp)
})
