# Ruling on design 9, TX3 (orchestrator, 14 Nov): the \ensuremath{} wrapper in raw LaTeX belongs to
# output a formatter wrote for TeX. An inline value with no class block is not formatted for TeX
# (in math it prints as today), so in raw LaTeX it prints as today too: a string in a tabular cell
# must not be set in math mode. A construct beside it is still wrapped.

d2_need()

rb_knit <- function(lines) {
  render_rmd(lines, code = "nm <- 'Site A'; v <- 0.123", format = "knit", in_process = TRUE,
             env = c(WEFT_DRAFT = NA_character_, WEFT_COLLECT = NA_character_))
}

test_that("TX3 (ruling): a bare string in raw LaTeX is not wrapped in \\ensuremath{}", {
  res <- rb_knit(c("\\begin{tabular}{l}", "`r nm`", "\\end{tabular}"))
  expect_match(unesc(res$md), "\\begin{tabular}{l}\nSite A\n\\end{tabular}", fixed = TRUE)
})

test_that("TX3 (ruling): a bare number in raw LaTeX is not wrapped, a construct beside it is", {
  res <- rb_knit(c("```{=latex}", "\\textbf{`r v`} and `r v`{.pct}", "```"))
  md <- unesc(res$md)
  expect_match(md, "\\textbf{0.123} and \\ensuremath{12.3\\%}", fixed = TRUE)
  expect_identical(lengths(regmatches(md, gregexpr("ensuremath", md, fixed = TRUE))), 1L)
})
