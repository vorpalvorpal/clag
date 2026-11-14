# Stage 7f (dev/design-7.md, 2 F, notes N90, N93, N97, N98, D26, messages E40, E43): a named value used
# above the chunk that assigns it. The document is knitted through the R hooks (helper-6b.R, b6_knit()),
# and the knit's output goes through the Lua filter (filter_md()). Controls are marked. Made-up content.

fk_chunk <- function(label, ...) c(sprintf("```{r %s, include=FALSE}", label), c(...), "```", "")

# the knit's output through the filter, as a knitr document
fk_filter <- function(res, env = character()) {
  filter_md(res$text, name = "doc.Rmd", to = "plain", env = env)
}

# ---- N90, N97: the hooks publish at the end, the filter finds the value --------------------------

test_that("N97, N90: a named value above the chunk that assigns it prints the value the closing block carries", {
  src <- c("In summary, `n_sites`{.count} sites were sampled.", "",
           fk_chunk("calc", "sites <- data.frame(a = 1:3)", "n_sites <- nrow(sites)"), "End.")
  res <- b6_knit(src)
  b6_expect_knitted(res)
  # nothing changes in the hooks: the construct is left as written, and one block follows the prose
  expect_true(any(grepl("`n_sites`{.count}", res$text, fixed = TRUE)))
  expect_length(res$blocks, 1L)
  expect_identical(res$blocks[[1]]$block$values$n_sites$t, "int")
  expect_true(res$blocks[[1]]$open > b6_line(res$text, "In summary"))
  out <- fk_filter(res)
  expect_identical(out$status, 0L)
  expect_match(out$output, "In summary, three sites were sampled.", fixed = TRUE)
  expect_false(grepl("weft", out$stderr, fixed = TRUE))
})

test_that("N90: the same use with a .num class, and a use above and a use below, print the same value", {
  src <- c("Above `n_sites`{.num} sites.", "", fk_chunk("calc", "n_sites <- 12L"), "Below `n_sites`{.num} sites.")
  res <- b6_knit(src)
  b6_expect_knitted(res)
  out <- fk_filter(res)
  expect_identical(out$status, 0L)
  expect_match(out$output, "Above 12 sites.", fixed = TRUE)
  expect_match(out$output, "Below 12 sites.", fixed = TRUE)
})

test_that("N93, N97, E40: a name the hooks publish with two values, used above, is E40 and fails the render", {
  src <- c("Above `n_sites`{.num} sites.", "", fk_chunk("one", "n_sites <- 1L"), "Middle `n_sites`{.num}.", "",
           fk_chunk("two", "n_sites <- 2L"), "End.")
  res <- b6_knit(src)
  b6_expect_knitted(res)
  expect_gte(length(res$blocks), 2L)
  out <- fk_filter(res, env = c(WEFT_DRAFT = "1"))
  expect_match(out$stderr, f7_msg$E40("n_sites", 2L), fixed = TRUE)
  expect_match(out$stderr, f7_msg$E41, fixed = TRUE)
  expect_match(out$output, "Middle 1.", fixed = TRUE)           # a use below a publication: the latest above it
  expect_false(grepl("Above 1|Above 2", out$output))
  expect_identical(fk_filter(res)$status, 1L)
})

# ---- N98, E43: inline R is not covered ---------------------------------------------------------------

test_that("N98, D26, E43: `r n_sites` above the chunk is the no value failure, with E43 as its hint", {
  src <- c("Above `r n_sites`{.num} sites.", "", fk_chunk("calc", "n_sites <- 3L"))
  res <- b6_knit(src)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_identical(nrow(f), 1L)
  expect_identical(f$kind, "no value")
  expect_match(f$detail, "object 'n_sites' not found", fixed = TRUE)
  expect_identical(f$hint, f7_msg$E43("n_sites"))
  expect_match(res$message, f7_msg$E43("n_sites"), fixed = TRUE)
})

test_that("N98: an expression that is not a single name does not get E43", {
  src <- c("Above `r n_sites + 1`{.num} sites.", "", fk_chunk("calc", "n_sites <- 3L"))
  res <- b6_knit(src)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_identical(nrow(f), 1L)
  expect_identical(f$kind, "no value")
  expect_match(f$detail, "object 'n_sites' not found", fixed = TRUE)
  expect_false(isTRUE(grepl("computed further down", f$hint, fixed = TRUE)))
  expect_false(grepl("computed further down", res$message, fixed = TRUE))
})

test_that("N98 (control): an inline R failure that is not 'object not found' keeps its hint", {
  src <- c("Above `r stop('boom')`{.num} sites.", "", fk_chunk("calc", "n_sites <- 3L"))
  res <- b6_knit(src)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_identical(nrow(f), 1L)
  expect_false(isTRUE(grepl("computed further down", f$hint, fixed = TRUE)))
})

test_that("N98 (control): `r n_sites` below the chunk that assigns it prints as today", {
  src <- c(fk_chunk("calc", "n_sites <- 3L"), "Below `r n_sites`{.num} sites.")
  res <- b6_knit(src)
  b6_expect_knitted(res)
  expect_true("Below 3 sites." %in% res$text)
})
