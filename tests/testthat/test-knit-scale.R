# The cost of a knit grows in step with the length of the document. Each construct once read
# everything before it (to tell whether it opened a sentence, and which sentence of its
# paragraph it sat in), so a long chapter cost the square of its length. The bound is
# generous: four times the text takes well under eight times the time (a square would be
# sixteen). What a knit costs before it reaches any text (the set-up, the dictionary, the
# configuration) is measured on a short document and taken off first.

scale_doc <- function(n_paras) {
  head <- c("---", "title: \"Scale\"", "---", "",
            "```{r setup, include=FALSE}", "weft::weft_setup()", "v <- round(seq(1, 500, length.out = 400), 1)", "```", "")
  body <- unlist(lapply(seq_len(n_paras), function(i) {
    c(sprintf(paste0("The survey of reach %d found that the water was low and the weather was fine. ",
                     "A value of `r v[%d]`{.num} was recorded, and the level [rose | fell]{if=\"v[%d] > 250\"} ",
                     "over the period. It held."), i, i, i), "")
  }))
  c(head, body)
}

time_knit <- function(n_paras) {
  d <- withr::local_tempdir()
  f <- file.path(d, "ch.qmd")
  writeLines(scale_doc(n_paras), f)
  withr::local_dir(d)
  weft_restore_knitr()
  withr::defer(weft_restore_knitr())
  system.time(suppressMessages(suppressWarnings(
    knitr::knit(f, file.path(d, "ch.md"), quiet = TRUE, envir = new.env())
  )))[["elapsed"]]
}

test_that("a document four times as long knits in well under sixteen times the time", {
  skip_on_cran()
  time_knit(2L)                                    # the first knit in a session warms caches
  t0 <- time_knit(2L)
  t1 <- time_knit(60L)
  t4 <- time_knit(240L)
  expect_lt((t4 - t0) / max(t1 - t0, 0.05), 8)
})
