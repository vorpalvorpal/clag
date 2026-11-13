# T2(b): a reader whose literal-name read takes its store from one of its own parameters, the
# default of which is evaluated as R evaluates it at knit time. Shape from a trial: the document
# sits in a subfolder of the project, the reader is defined in a sourced file, the default store
# is rooted at the project (here::here()). Generic fixtures. ASCII only.

ts_reader <- c("attach_fit <- function(envir = parent.frame(), store = here::here(\"store-root\", \"_targets\")) {",
               "  v <- tryCatch(targets::tar_read_raw(\"fit\", store = store), error = function(e) stop(e))",
               "  assign(\"fit\", v, envir = envir)",
               "}")

test_that("T2b: a literal-name read through a store parameter defaulting to here::here() is recorded with its hash", {
  skip_if_not_installed("here")
  p <- cl_two_stores()
  res <- cl_render(c("```{r}", "source(\"R/attach.R\", local = TRUE)", "attach_fit()", "```", "", "Text."), p$sub,
                   code = "here::i_am(\"reports/doc.Rmd\")",
                   files = list("R/attach.R" = ts_reader))
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
  tg <- e1_header(p$sub)$targets
  expect_identical(names(tg), "../store-root/_targets")
  expect_identical(tg[[1]][["fit"]], e1_data_hash(p$other, "fit"))
})

test_that("T2b: the same reader called with a store of its own reads that store, not the default", {
  skip_if_not_installed("here")
  p <- cl_two_stores()
  res <- cl_render(c("```{r}", "source(\"R/attach.R\", local = TRUE)", "attach_fit(store = \"../store-root/_targets\")", "```",
                     "", "Text."), p$sub,
                   code = "here::i_am(\"reports/doc.Rmd\")",
                   files = list("R/attach.R" = ts_reader))
  expect_false(res$failed)
  expect_identical(names(e1_header(p$sub)$targets), "../store-root/_targets")
})

test_that("T2b: a store parameter whose default cannot be evaluated stays one warning and the default store", {
  p <- cl_two_stores()
  res <- cl_render(c("```{r}",
                     "rd <- function(base, store = file.path(base, \"_targets\")) targets::tar_read_raw(\"fit\", store = store)",
                     "v <- rd(\"nowhere\")", "```", "", "Text."), p$sub)
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_true(grepl("7.2.2", e1_flat(d2_msgs(w)), fixed = TRUE))
})
