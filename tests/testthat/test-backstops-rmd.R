# Backstops under rmarkdown (2.5.3, 9.2.7, 9.2.6, §21 "Backstops" and
# "Activation"): the document names the filter through pandoc_args, the
# hooks are missing, and the render fails in Pandoc through the filter.

expect_filter_stopped_render <- function(r, label) {
  expect_true(r$failed, label = paste(label, "- the render failed"))
  expect_match(r$log, "pandoc|filter|lua|weft", ignore.case = TRUE)
  expect_false(nzchar(r$output), label = paste(label, "- no output written"))
}

test_that("§21 Backstops, 2.5.3: each kind of construct, never activated, fails the render through the filter", {
  bodies <- kind_bodies()
  for (kind in c("value", "n", "if", "text")) {
    r <- render_rmd_filtered(bodies[[kind]])
    expect_filter_stopped_render(r, kind)
  }
})

test_that("§21 Backstops, 2.5.3: a value written with a capital R fails the render", {
  r <- render_rmd_filtered(kind_bodies()$capital_R)
  expect_filter_stopped_render(r, "capital R")
})

test_that("§21 Activation, 9.2.6: a setup chunk that only calls library(weft) is caught by the filter", {
  bodies <- kind_bodies(setup = "library(weft)")
  r <- render_rmd_filtered(bodies$value)
  expect_filter_stopped_render(r, "library(weft) only")
  r2 <- render_rmd_filtered(bodies$n)
  expect_filter_stopped_render(r2, "library(weft) only, n span")
})

test_that("§21 Backstops (controls): the same document activated renders; so does one with no constructs", {
  chunk_after <- kind_bodies(setup = "weft::weft_setup()")
  body <- c(chunk_after$value,
            "", "Found [one site | # sites]{n=\"k\"} here.",
            "", "It was [met | not met]{if=\"depth > 5\"} here.",
            "", "A [result]{.strong} and a [note]{.em} here.")
  r <- render_rmd_filtered(body)
  expect_false(r$failed, info = r$log)
  expect_match(r$output, "12.5", fixed = TRUE)
  expect_match(r$output, "one site", fixed = TRUE)
  expect_no_match(r$output, "{.num}", fixed = TRUE)
  expect_no_match(r$output, "<<weft:", fixed = TRUE)

  plain <- render_rmd_filtered(c("```{r}", "x <- 1", "```", "", "Plain text, `code` and a [link](https://example.org)."))
  expect_false(plain$failed, info = plain$log)
})

test_that("9.2.7, 2.5.3: the filter named in pandoc_args is what stops it (no filter, no failure)", {
  skip_if_no_pandoc()
  dir <- tempfile("weft-rmd-nofilter-"); dir.create(dir)
  writeLines(c("---", "title: t", "output:", "  md_document:", "    variant: markdown", "---", "",
               kind_bodies()$value), file.path(dir, "doc.Rmd"))
  withr::local_dir(dir)
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                  c("--no-save", "-e", shQuote("rmarkdown::render('doc.Rmd', quiet = TRUE)")),
                                  stdout = TRUE, stderr = TRUE))
  expect_null(attr(out, "status"))
  expect_match(paste(readLines("doc.md"), collapse = "\n"), "{.num}", fixed = TRUE)
})
