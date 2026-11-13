# Two documents never share a stamp file (review C 18): `a/b.qmd` and
# `a__b.qmd` both used to be written to `.weft/stamps/a__b.qmd.json`.

sn_stamp <- function(d, rel) {
  path <- file.path(d, rel)
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines("x", path)
  s <- weft:::new_state()
  s$input_path <- normalizePath(path)
  s$input_name <- basename(path)
  weft:::record_knit(s, weft:::failures_frame(s))
}

sn_project <- function(env = parent.frame()) {
  d <- normalizePath(withr::local_tempdir(.local_envir = env))
  writeLines("draft: false", file.path(d, "_weft.yml"))
  dir.create(file.path(d, ".weft", "stamps"), recursive = TRUE)
  d
}

sn_sources <- function(d) {
  fs <- list.files(file.path(d, ".weft", "stamps"), pattern = "\\.json$", full.names = TRUE)
  vapply(fs, function(f) {
    sub("^.*\"source\": \"([^\"]*)\".*$", "\\1", paste(readLines(f, warn = FALSE), collapse = " "))
  }, "", USE.NAMES = FALSE)
}

test_that("stamp names: a/b.qmd and a__b.qmd have separate stamp files", {
  d <- sn_project()
  sn_stamp(d, "a/b.qmd")
  sn_stamp(d, "a__b.qmd")
  expect_length(list.files(file.path(d, ".weft", "stamps"), pattern = "\\.json$"), 2L)
  expect_setequal(sn_sources(d), c("a/b.qmd", "a__b.qmd"))
})

test_that("stamp names: a top-level document and a nested one keep the plain names", {
  d <- sn_project()
  sn_stamp(d, "top.qmd")
  sn_stamp(d, "sub/inner.qmd")
  expect_setequal(list.files(file.path(d, ".weft", "stamps")),
                  c("top.qmd.json", "sub__inner.qmd.json"))
})

test_that("stamp names: the name is one-to-one for awkward paths", {
  rels <- c("a/b.qmd", "a__b.qmd", "a_/b.qmd", "a/_b.qmd", "a___b.qmd", "a%b.qmd", "a/b/c.qmd",
            "a__b/c.qmd", "a/b__c.qmd", "x_y.qmd")
  nm <- vapply(rels, weft:::stamp_file_name, "")
  expect_false(anyDuplicated(nm) > 0L)
  expect_false(any(grepl("/", nm, fixed = TRUE)))
})
