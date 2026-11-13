# Package 4a: the timing bound (dev/design-4.md G15). Budget: a commit changing one 300-line chapter of a ten-chapter
# project, cache warm, <= 1.5 s end to end through `git commit` on the development Mac; the test allows 3 s for
# gate() itself and is skipped on CRAN and on CI. The commit-msg hook is package 4b's, so the git commit leg is
# not timed here.

perf_chapter <- function(k) {
  unlist(lapply(seq_len(150L), function(i) c(sprintf("Paragraph %d of this chapter reads `r v_%d_%d`{.num} sites.", i, k, i), "")))[-300L]
}

# Processor time of gate() (and of the git it runs) for a one-chapter edit in a project of `n`
# chapters, cache warm: one edit is committed to warm the cache, then two more are timed and the
# least is kept. Returns the seconds and the last report.
gate_cpu <- function(n) {
  files <- stats::setNames(lapply(seq_len(n), perf_chapter), sprintf("ch%02d.qmd", seq_len(n)))
  d <- g_repo(files)
  expect_length(files[[1]], 299L)
  edit <- function(text) {
    g_write(d, "ch01.qmd", c(files[[1]], "", text))
    g_add(d)
  }
  edit("A first edit.")
  expect_true(g_gate(d)$ok)
  g_commit(d, "first edit")
  secs <- numeric()
  res <- NULL
  for (text in c("A second edit.", "A third edit.")) {
    edit(text)
    secs <- c(secs, cpu_time(res <- g_gate(d), children = TRUE))
    expect_true(res$ok)
    g_commit(d, text)
  }
  list(seconds = min(secs), report = attr(res, "report"))
}

test_that("4a G15: a one-chapter commit, cache warm, costs about the same in a ten-chapter project as in a two-chapter one", {
  skip_on_cran()
  withr::local_options(weft.gate_cache = TRUE)
  small <- gate_cpu(2L)
  large <- gate_cpu(10L)
  # the work follows the changed file and not the project, so the ratio is about one; a gate that read
  # every chapter would give about five, and one that compared every pair, far more. The floor keeps a
  # very quick small run from making the ratio noisy. Measured 1.6.
  ratio <- large$seconds / max(small$seconds, 0.05)
  expect_lt(ratio, 3)
  expect_match(large$report[[length(large$report)]],
               "^commit-msg: weft passed \\(1 changed file(s)?, [0-9]+\\.[0-9] s\\)$")
})
