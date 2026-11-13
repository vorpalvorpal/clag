# Package 3a: L16, the performance bounds of lints() with reader = "weft".
# Design: a 300-line chapter (40 constructs, 2 chunks with captions, an abstract), all rules of
# both tiers, under 0.5 s on the second call in a session; 1,800 lines under 3 s. "The tests allow
# twice these": 1 s and 6 s.

chapter_lines <- function(n_lines = 300L, n_constructs = 40L) {
  head <- c("---", "title: \"A chapter\"", "abstract: |",
            "  This chapter reports `r zzn`{.num} sites and what was found there.", "---", "")
  chunk <- function(k) c(
    "```{r}", sprintf("#| label: fig-perf-%d", k), "#| fig-cap: |",
    sprintf("#|   Depth at [a site | # sites]{n=\"zzk\"} in section %d.", k),
    sprintf("#| fig-alt: Depth by site, figure %d", k), "x <- 1", "plot(x)", "```", "")
  body <- character(0)
  made <- 0L
  i <- 0L
  while (length(head) + length(body) + 18L < n_lines) {
    i <- i + 1L
    body <- c(body, sprintf("## Section %d {#sec-perf-%d}", i, i), "")
    for (j in 1:3) {
      cons <- if (made < n_constructs) {
        made <- made + 1L
        sprintf(" Mean was `r zzx%d`{.num} m and [a site | # sites]{n=\"zzk\"} were dry.", made)
      } else ""
      body <- c(body, sprintf("Paragraph %d.%d of the chapter says that the water was low and the weather was fine, as noted.%s", i, j, cons), "")
    }
  }
  # the two chunks with captions, then pad to the length asked
  all <- c(head, chunk(1), chunk(2), body)
  all[seq_len(min(length(all), n_lines))]
}

# Processor time of the second lints() call on a project (the first warms caches), the least of
# three, so that a busy machine does not skew it. The tests compare a chapter with the same chapter
# a quarter of the size (a quarter of the constructs): linear work gives about four, and the fixed
# cost of a call lowers that. Quadratic work gives sixteen. The design's absolute bounds (L16: 0.5 s
# and 3 s on the development Mac, allowed at twice) are wall-clock and fail on a loaded machine.
lints_cpu <- function(root) {
  invisible(lints(root, tier = 1:2))
  cpu_time_min(function() lints(root, tier = 1:2), 3L)
}

lints_ratio <- function(ext, small_lines, small_constructs, large_lines, large_constructs) {
  name <- paste0("ch.", ext)
  small <- lint_proj(stats::setNames(list(chapter_lines(small_lines, small_constructs)), name))
  large <- lint_proj(stats::setNames(list(chapter_lines(large_lines, large_constructs)), name))
  # measured 3.0 (300 lines), 3.9 (1,800 lines), 3.6 (.Rmd)
  lints_cpu(large) / max(lints_cpu(small), 0.01)
}

test_that("3a L16: a 300-line chapter with 40 constructs lints in under eight times the time of a 75-line one with 10", {
  skip_on_cran()
  expect_gte(length(chapter_lines(300L, 40L)), 250L)
  expect_lt(lints_ratio("qmd", 75L, 10L, 300L, 40L), 8)
})

test_that("3a L16: a 1,800-line chapter lints in under eight times the time of a 450-line one", {
  skip_on_cran()
  expect_gte(length(chapter_lines(1800L, 240L)), 1700L)
  expect_lt(lints_ratio("qmd", 450L, 60L, 1800L, 240L), 8)
})

test_that("3a L16: the same work as .Rmd stays within the bound", {
  skip_on_cran()
  expect_lt(lints_ratio("Rmd", 75L, 10L, 300L, 40L), 8)
})

test_that("3a L16: the long chapter is read without findings of the wrong kind (it holds valid constructs only)", {
  skip_on_cran()
  root <- lint_proj(list("ch.qmd" = chapter_lines(300L, 40L)))
  x <- lints(root, rules = "construct", tier = 1:2)
  expect_equal(nrow(x), 0L)
})
