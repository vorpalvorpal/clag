test_that("rel_to() drops the root and one separator", {
  expect_identical(rel_to("/a/b/c.qmd", "/a/b"), "c.qmd")
  expect_identical(rel_to("/a/b/d/c.qmd", "/a/b"), "d/c.qmd")
  expect_identical(rel_to("C:/proj/c.qmd", "C:/proj"), "c.qmd")
})

test_that("rel_to() is right when the root is `/` or `C:/`", {
  expect_identical(rel_to("/a/b.qmd", "/"), "a/b.qmd")
  expect_identical(rel_to("C:/a/b.qmd", "C:/"), "a/b.qmd")
  expect_identical(rel_to("C:/b.qmd", "C:/"), "b.qmd")
})

test_that("rel_to() leaves a path that is not inside the root alone", {
  expect_identical(rel_to("/a/bc/x.qmd", "/a/b"), "/a/bc/x.qmd")
  expect_identical(rel_to("/other/x.qmd", "/a/b"), "/other/x.qmd")
  expect_identical(rel_to("/a/b", "/a/b"), "/a/b")
  expect_identical(rel_to("x.qmd", "/a/b"), "x.qmd")
})

test_that("rel_to() works on a vector of paths", {
  expect_identical(rel_to(c("/r/a.qmd", "/z/b.qmd", "/r/s/c.qmd"), "/r"),
                   c("a.qmd", "/z/b.qmd", "s/c.qmd"))
  expect_identical(rel_to(character(), "/r"), character())
})
