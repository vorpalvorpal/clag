# Package 2d under Quarto (dev/design-2d.md D1, D2, D10; "Tests", test-ledger-quarto.R).
# Written before the code. Made-up values only.
if (!exists("d2_render")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])
d2_need()

d2q_doc <- function(body, formats = "markdown", extra = NULL) {
  fmt <- if (length(formats) == 1L) c(paste0("format: ", formats)) else c("format:", paste0("  ", formats, ": default"))
  c("---", "title: \"t\"", "engine: knitr", fmt, "execute:", "  echo: false", extra, "---", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 1; pv <- 2", "```", "", body, "")
}

# a fresh set-up folder with doc.qmd and `files`; returns its path
d2q_dir <- function(lines, files = NULL, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir <- normalizePath(dir)
  put_files(dir, c(D2_SETUP, files))
  writeLines(lines, file.path(dir, "doc.qmd"), useBytes = TRUE)
  dir
}

test_that("2d D1: a .qmd in a set-up folder gets _weft/ledger/doc.qmd/doc.jsonl, source doc.qmd, output doc", {
  skip_if_no_quarto()
  dir <- d2q_dir(d2q_doc(c("## Data", "", "Value `r k` here.")))
  r <- qrender(dir, c("doc.qmd"))
  expect_identical(r$status, 0L, label = r$log)
  p <- d2_path(dir, source = "doc.qmd")
  expect_true(file.exists(p))
  h <- d2_header(p)
  expect_identical(h$source, "doc.qmd")
  expect_identical(h$output, "doc")
  e <- d2_entries(p)
  expect_identical(d2_one(e, expr = "k")$file, "doc.qmd")
  expect_identical(d2_one(e, expr = "k")$section, "data")
  expect_false(dir.exists(file.path(dir, "_weft", "ledger", "doc.rmarkdown")))
  expect_setequal(list.files(dirname(p)), c("doc.jsonl", "doc.conditions.jsonl"))
})

test_that("2d D8 + D10: values of an included file have that file and the section of the include's place", {
  skip_if_no_quarto()
  dir <- d2q_dir(d2q_doc(c("## Data", "", "{{< include _part.qmd >}}", "", "Own `r k` value.")),
                 files = list("_part.qmd" = c("Included `r pv` value.")))
  r <- qrender(dir, c("doc.qmd"))
  expect_identical(r$status, 0L, label = r$log)
  e <- d2_entries(d2_path(dir, source = "doc.qmd"))
  inc <- d2_one(e, expr = "pv")
  expect_identical(inc$file, "_part.qmd")
  expect_identical(inc$section, "data")
  expect_identical(d2_one(e, expr = "k")$file, "doc.qmd")
})

test_that("2d D2: `quarto render -o other.md` writes doc.jsonl and warns that WEFT_OUTPUT names the ledger", {
  skip_if_no_quarto()
  dir <- d2q_dir(d2q_doc(c("Value `r k` here.")))
  r <- qrender(dir, c("doc.qmd", "--to", "markdown", "-o", "other.md"))
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(d2_path(dir, source = "doc.qmd")))
  expect_false(file.exists(d2_path(dir, source = "doc.qmd", output = "other")))
  expect_match(r$log, "WEFT_OUTPUT", fixed = TRUE)
})

test_that("2d D2: with WEFT_OUTPUT=other the same render writes other.jsonl, and no warning", {
  skip_if_no_quarto()
  dir <- d2q_dir(d2q_doc(c("Value `r k` here.")))
  r <- qrender(dir, c("doc.qmd", "--to", "markdown", "-o", "other.md"), env = c(WEFT_OUTPUT = "other"))
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(d2_path(dir, source = "doc.qmd", output = "other")))
  expect_false(file.exists(d2_path(dir, source = "doc.qmd")))
  expect_false(grepl("WEFT_OUTPUT", r$log, fixed = TRUE))
})

test_that("2d D2: `format: md` without -o names the output doc (output-file is present for md)", {
  skip_if_no_quarto()
  dir <- d2q_dir(d2q_doc(c("Value `r k` here."), formats = "md"))
  r <- qrender(dir, c("doc.qmd"))
  expect_identical(r$status, 0L, label = r$log)
  expect_true(file.exists(d2_path(dir, source = "doc.qmd")))
  expect_false(grepl("WEFT_OUTPUT", r$log, fixed = TRUE))
})

test_that("2d D2: two formats in one render (html, md) give one doc.jsonl", {
  skip_if_no_quarto()
  dir <- d2q_dir(d2q_doc(c("Value `r k` here."), formats = c("html", "md")))
  r <- qrender(dir, c("doc.qmd"))
  expect_identical(r$status, 0L, label = r$log)
  expect_setequal(list.files(file.path(dir, "_weft", "ledger", "doc.qmd")), c("doc.jsonl", "doc.conditions.jsonl"))
  expect_identical(d2_header(d2_path(dir, source = "doc.qmd"))$output, "doc")
})
