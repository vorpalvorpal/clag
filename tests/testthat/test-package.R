test_that("the package namespace loads", {
  expect_true("weft" %in% loadedNamespaces())
})
