# 4d: use_setup() on .Rmd documents (G35, 9.2.7, 2.5.3): the filter copied
# beside the document and named under each format of `output:`. No render here.

rmd_with <- function(front) c("---", front, "---", "", "Some text.")

filter_in <- function(dir, sub = "") file.path(dir, sub, "weft-check.lua")

test_that("4d G35: an .Rmd with no `output:` gets html_document with the filter line, written exactly", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: \"t\"")))
  u4_use(d)
  fm <- u4_front(file.path(d, "a.Rmd"))
  expect_true(u4_has_run(fm, c("output:", "  html_document:", paste0("    ", U4_FILTER_ARGS))))
  expect_true(u4_has_run(fm, U4_OPTS_KNIT))
})

test_that("4d G35: a scalar `output: pdf_document` becomes a mapping for that format", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output: pdf_document"))))
  u4_use(d)
  fm <- u4_front(file.path(d, "a.Rmd"))
  expect_false("output: pdf_document" %in% fm)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(names(y$output), "pdf_document")
  expect_identical(y$output$pdf_document$pandoc_args, U4_LUA_ARGS)
})

test_that("4d G35: a mapping format keeps its options and gains the filter under pandoc_args", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output:", "  html_document:", "    toc: true"))))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_true(y$output$html_document$toc)
  expect_identical(y$output$html_document$pandoc_args, U4_LUA_ARGS)
})

test_that("4d G35: two formats each get the filter", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output:", "  html_document:", "    toc: true",
                                        "  pdf_document:", "    toc: false"))))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args, U4_LUA_ARGS)
  expect_identical(y$output$pdf_document$pandoc_args, U4_LUA_ARGS)
})

test_that("4d G35: block-style pandoc_args get the two items appended, after the author's", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output:", "  html_document:", "    pandoc_args:",
                                        "      - \"--toc\"", "      - \"--number-sections\""))))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args,
                   c("--toc", "--number-sections", U4_LUA_ARGS))
})

test_that("4d G35: flow-style pandoc_args cannot be edited safely: nothing is written and the lines to add are printed", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output:", "  html_document:",
                                        "    pandoc_args: [\"--toc\"]"))))
  before <- u4_md5(d)
  err <- tryCatch(suppressMessages(weft::use_setup(d)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_identical(u4_md5(d), before)
  expect_match(conditionMessage(err), "--lua-filter", fixed = TRUE)
  expect_match(conditionMessage(err), "weft-check.lua", fixed = TRUE)
  expect_false(file.exists(filter_in(d)))
})

test_that("4d G35: the filter is copied beside the document, and is weft's shipped file", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: t")))
  u4_use(d)
  expect_true(file.exists(filter_in(d)))
  expect_identical(unname(tools::md5sum(filter_in(d))), unname(tools::md5sum(weft_filter_path())))
})

test_that("4d G35: a filter copy that is identical is kept; one that differs is replaced, and the message says so", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: t")))
  u4_use(d)
  # identical: kept (file untouched, a second run has nothing to change)
  mt <- file.mtime(filter_in(d))
  Sys.sleep(1.1)
  says <- u4_says(d)
  expect_identical(file.mtime(filter_in(d)), mt)
  expect_match(says, "Nothing to change", fixed = TRUE)
  # differing: replaced by weft's own file
  writeLines(c("-- edited by hand"), filter_in(d))
  says2 <- u4_says(d)
  expect_identical(unname(tools::md5sum(filter_in(d))), unname(tools::md5sum(weft_filter_path())))
  expect_match(says2, "weft-check\\.lua  \\(replace: ")
  expect_match(says2, "Wrote: [^\n]*weft-check.lua")
})

test_that("4d G35: a folder of two .Rmd documents sets up both, with one filter copy and one _weft.yml", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: a"), `b.Rmd` = rmd_with(c("title: b", "output: html_document"))))
  u4_use(d)
  for (f in c("a.Rmd", "b.Rmd")) {
    y <- u4_yaml(file.path(d, f))
    expect_identical(y$output$html_document$pandoc_args, U4_LUA_ARGS, label = f)
    expect_identical(y$knitr$opts_knit$weft, "!expr weft::weft_setup()", label = f)
  }
  # 6d: weft.lua and the folder weftlib/ go beside the document with weft-check.lua; 7d (N50) adds weft-output.lua
  libs <- file.path("weftlib", list.files(system.file("quarto", "weftlib", package = "weft"), recursive = TRUE))
  expect_identical(sort(tree(d)), sort(c("_weft.yml", "a.Rmd", "b.Rmd", "weft-check.lua", "weft-output.lua", "weft.lua", libs)))
})

test_that("4d G35: a mixed folder: the .qmd gets its engine line but no filter line, the .Rmd the filter", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: a"), `b.qmd` = u4_qmd()))
  u4_use(d)
  expect_false(any(grepl("lua-filter", u4_read(d, "b.qmd"), fixed = TRUE)))
  expect_identical(u4_yaml(file.path(d, "b.qmd"))$engine, "knitr")
  expect_false(any(grepl("^engine:", u4_read(d, "a.Rmd"))))
})

test_that("4d G35: a second run on .Rmd documents changes nothing", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output: pdf_document")), `b.Rmd` = rmd_with("title: b")))
  u4_use(d)
  before <- u4_md5(d)
  says <- u4_says(d)
  expect_identical(u4_md5(d), before)
  expect_match(says, "Nothing to change", fixed = TRUE)
})

test_that("4d G35: the .Rmd's body is untouched", {
  body <- c("", "Some text.", "", "```{r}", "x <- 1", "```")
  d <- u4_dir(list(`a.Rmd` = c("---", "title: t", "---", body)))
  u4_use(d)
  x <- u4_read(d, "a.Rmd")
  expect_identical(tail(x, length(body)), body)
})

test_that("4d G35: .rmd (lower case) is a document too", {
  d <- u4_dir(list(`a.rmd` = rmd_with("title: t")))
  u4_use(d)
  expect_true(u4_has_run(u4_front(file.path(d, "a.rmd")), U4_OPTS_KNIT))
  expect_true(file.exists(filter_in(d)))
})

test_that("4d G35: a single .Rmd given by path gets its filter beside it", {
  d <- u4_dir(list(`sub/a.Rmd` = rmd_with("title: t")))
  u4_use(file.path(d, "sub", "a.Rmd"))
  expect_true(file.exists(filter_in(d, "sub")))
  expect_identical(u4_yaml(file.path(d, "sub", "a.Rmd"))$output$html_document$pandoc_args,
                   U4_LUA_ARGS)
})
