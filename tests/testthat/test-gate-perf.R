# Package 4a: the timing bound (dev/design-4.md G15). Budget: a commit changing one 300-line chapter of a ten-chapter
# project, cache warm, <= 1.5 s end to end through `git commit` on the development Mac; the test allows 3 s for
# gate() itself and is skipped on CRAN and on CI. The commit-msg hook is package 4b's, so the git commit leg is
# not timed here.

perf_chapter <- function(k) {
  unlist(lapply(seq_len(150L), function(i) c(sprintf("Paragraph %d of this chapter reads `r v_%d_%d`{.num} sites.", i, k, i), "")))[-300L]
}

test_that("4a G15: a one-chapter commit in a ten-chapter project, cache warm, is judged within 3 seconds", {
  skip_on_cran()
  skip_on_ci()
  withr::local_options(weft.gate_cache = TRUE)
  files <- stats::setNames(lapply(1:10, perf_chapter), sprintf("ch%02d.qmd", 1:10))
  d <- g_repo(files)
  expect_length(files[[1]], 299L)
  # warm the cache with one edit, commit it, then time the next edit
  g_write(d, "ch01.qmd", c(files[[1]], "", "A first edit."))
  g_add(d)
  expect_true(g_gate(d)$ok)
  g_commit(d, "first edit")
  g_write(d, "ch01.qmd", c(files[[1]], "", "A second edit."))
  g_add(d)
  t0 <- proc.time()[["elapsed"]]
  res <- g_gate(d)
  wall <- proc.time()[["elapsed"]] - t0
  expect_true(res$ok)
  expect_lt(wall, 3)
  expect_lt(res$seconds, 3)
  expect_match(attr(res, "report")[[length(attr(res, "report"))]], "^commit-msg: weft passed \\(1 changed file(s)?, [0-9]+\\.[0-9] s\\)$")
})
