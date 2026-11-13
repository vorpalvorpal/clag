# The cost of a knit grows in step with the length of the document. Each construct once read
# everything before it (to tell whether it opened a sentence, and which sentence of its
# paragraph it sat in), so a long chapter cost the square of its length. The bound is
# set so that the quadratic work fails it: four times the text takes under 5.5 times the
# time (a square would be sixteen, but the fixed cost of a knit dilutes it to about 7).

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
  # processor time, so that another process busy on the machine does not skew the ratio
  tm <- system.time(suppressMessages(suppressWarnings(
    knitr::knit(f, file.path(d, "ch.md"), quiet = TRUE, envir = new.env())
  )))
  tm[["user.self"]] + tm[["sys.self"]]
}

test_that("a document four times as long knits in well under sixteen times the time", {
  skip_on_cran()
  time_knit(20L)                                   # the first knit in a session warms caches
  t1 <- min(time_knit(80L), time_knit(80L))
  t4 <- min(time_knit(320L), time_knit(320L))
  # measured: about 4.3 now, 6.3 to 7.2 with the quadratic work
  expect_lt(t4 / t1, 5.5)
})
