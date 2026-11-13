# The cost of lints() grows in step with the size of a document, not with its square. Reading a
# document once cut its lines, pieces and words out of one long string again and again, which for a
# document with non-ASCII characters (every real manuscript has them) grew with the square of its
# size: 3,000 lines took sixteen times as long as 750. Linear is four times; the bound allows eight,
# so a slow machine does not fail it and the square cannot come back unnoticed.

scale_doc <- function(n_lines) {
  out <- c("---", "title: \"A long chapter\"", "---", "")
  i <- 0L
  while (length(out) < n_lines) {
    i <- i + 1L
    if (i %% 20L == 1L) out <- c(out, sprintf("## Section %d {#sec-scale-%d}", i, i), "")
    out <- c(out, sprintf(paste0("Paragraph %d of the naïve chapter says that the café water was low ",
                                 "– and the weather was fine, as noted. Mean was `r zzx%d`{.num} m and ",
                                 "[a site | # sites]{n=\"zzk\"} were dry, so the level [rose | fell]{if=\"zzx%d > 2\"}."),
                         i, i, i), "")
  }
  out[seq_len(n_lines)]
}

time_scale <- function(n_lines) {
  root <- lint_proj(list("ch.qmd" = scale_doc(n_lines)))
  invisible(lints(root, tier = 1:2))               # the first call in a session warms caches
  # processor time, so that another process busy on the machine does not skew the ratio
  cpu_time_min(function() lints(root, tier = 1:2), 2L)
}

test_that("linting 3,000 lines takes under eight times as long as 750", {
  skip_on_cran()
  small <- time_scale(750L)
  large <- time_scale(3000L)
  # a floor under the small time, so a very quick small run cannot make the ratio noisy
  expect_lt(large, 8 * max(small, 0.25))
})
