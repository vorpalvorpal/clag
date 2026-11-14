# 7c: F3, changes() and tables (dev/design-7.md N35, N38, N39, messages E70 to E72). Fixtures are
# hand-written ledgers in temporary git repositories (helper-2e2.R). Written before the code.
# Made-up content only; ASCII only. A "control" passes before the feature exists.
if (!exists("t7c_entry")) source(Filter(file.exists, c(testthat::test_path("helper-7c.R"), testthat::test_path("..", "helper-7c.R")))[[1]])
if (!exists("e2x_scenario")) source(Filter(file.exists, c(testthat::test_path("helper-2e2.R"), testthat::test_path("..", "helper-2e2.R")))[[1]])

lines_like <- function(out, pattern) grep(pattern, out, value = TRUE)
labels_n <- function(n) sprintf("tbl-%02d", seq_len(n))

# ---- E70: a changed table ------------------------------------------------------------------------------------

test_that("E70: a changed table prints 'table `label` changed' with its caption under it", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(list(t7c_entry("tbl-sites", T7C_D1, caption = "Site table")),
                     list(t7c_entry("tbl-sites", T7C_D2, caption = "Site table")))
  i <- grep("table `tbl-sites` changed$", out)
  expect_length(i, 1L)
  expect_identical(trimws(out[i + 1L]), "Site table")
  # the digests themselves are not listed as cells or values
  expect_false(any(grepl(T7C_D1, out, fixed = TRUE)))
})

test_that("E70: the second table of a chunk is ' #2'; an unlabelled one is '(unlabelled)'", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(
    list(t7c_entry("tbl-two", T7C_D1, 1L, "First"), t7c_entry("tbl-two", T7C_D1, 2L, "Second"),
         t7c_entry("", T7C_D1, 1L, "Loose")),
    list(t7c_entry("tbl-two", T7C_D1, 1L, "First"), t7c_entry("tbl-two", T7C_D2, 2L, "Second"),
         t7c_entry("", T7C_D2, 1L, "Loose")))
  expect_length(grep("table `tbl-two` #2 changed$", out), 1L)
  expect_length(grep("table \\(unlabelled\\) changed$", out), 1L)
  expect_length(grep("table `tbl-two` changed$", out), 0L)
})

test_that("E70: an unchanged table, or one whose caption alone changed, is not listed", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(
    list(t7c_entry("tbl-a", T7C_D1, caption = "Old caption"), t7c_entry("tbl-b", T7C_D1)),
    list(t7c_entry("tbl-a", T7C_D1, caption = "New caption"), t7c_entry("tbl-b", T7C_D2)))
  expect_length(grep("table `tbl-b` changed$", out), 1L)
  expect_length(grep("table `tbl-a`", out), 0L)
})

test_that("N35: tables are listed after the ranked value changes", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(
    list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-sites", T7C_D1)),
    list(e2x_entry("depth", "2", raw = 2), t7c_entry("tbl-sites", T7C_D2)))
  v <- grep("after: +2", out)
  tb <- grep("table `tbl-sites` changed$", out)
  expect_length(v, 1L)
  expect_length(tb, 1L)
  expect_gt(tb, v)
})

test_that("N35: several changed tables are listed in file order", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(
    list(t7c_entry("tbl-a", T7C_D1), t7c_entry("tbl-b", T7C_D1)),
    list(t7c_entry("tbl-a", T7C_D2), t7c_entry("tbl-b", T7C_D2)))
  ia <- grep("table `tbl-a` changed$", out)
  ib <- grep("table `tbl-b` changed$", out)
  expect_length(ia, 1L)
  expect_length(ib, 1L)
  expect_lt(ia, ib)
})

# ---- E71, E72: added and removed --------------------------------------------------------------------------------

test_that("E71: added tables are one line per ledger, naming the labels", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)),
                     list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-a"), t7c_entry("tbl-b")))
  expect_length(grep("a\\.qmd: 2 tables added: tbl-a, tbl-b$", out), 1L)
  expect_length(grep("\\+ +a\\.qmd +table", out), 0L)      # not one line per table as well
})

test_that("E71: one added table is '1 table added'", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)),
                     list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-a")))
  expect_length(grep("a\\.qmd: 1 table added: tbl-a$", out), 1L)
})

test_that("E72: removed tables are one line per ledger", {
  skip_if(Sys.which("git") == "")
  out <- t7c_changes(list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-a"), t7c_entry("tbl-b")),
                     list(e2x_entry("depth", "1", raw = 1)))
  expect_length(grep("a\\.qmd: 2 tables removed: tbl-a, tbl-b$", out), 1L)
  expect_length(grep("- +a\\.qmd +table", out), 0L)
})

test_that("E71: eleven added tables name ten labels then ' and 1 other'; twelve ' and 2 others'", {
  skip_if(Sys.which("git") == "")
  mk <- function(n) lapply(labels_n(n), t7c_entry)
  o11 <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)), c(list(e2x_entry("depth", "1", raw = 1)), mk(11)))
  want11 <- paste0("a\\.qmd: 11 tables added: ", paste(labels_n(10), collapse = ", "), " and 1 other$")
  expect_length(grep(want11, o11), 1L)
  expect_length(grep("tbl-11", o11), 0L)
  o12 <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)), c(list(e2x_entry("depth", "1", raw = 1)), mk(12)))
  want12 <- paste0("a\\.qmd: 12 tables added: ", paste(labels_n(10), collapse = ", "), " and 2 others$")
  expect_length(grep(want12, o12), 1L)
  o10 <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)), c(list(e2x_entry("depth", "1", raw = 1)), mk(10)))
  expect_length(grep(paste0("10 tables added: ", paste(labels_n(10), collapse = ", "), "$"), o10), 1L)
})

test_that("E72: twelve removed tables name ten labels then ' and 2 others'", {
  skip_if(Sys.which("git") == "")
  mk <- lapply(labels_n(12), t7c_entry)
  out <- t7c_changes(c(list(e2x_entry("depth", "1", raw = 1)), mk), list(e2x_entry("depth", "1", raw = 1)))
  expect_length(grep(paste0("a\\.qmd: 12 tables removed: ", paste(labels_n(10), collapse = ", "), " and 2 others$"), out), 1L)
})

test_that("N35: the first render after the package lists every table as added, once", {
  skip_if(Sys.which("git") == "")
  old <- list(e2x_entry("depth", "1", raw = 1))
  out1 <- t7c_changes(old, c(old, list(t7c_entry("tbl-a"), t7c_entry("tbl-b"))))
  expect_length(grep("2 tables added: tbl-a, tbl-b$", out1), 1L)
  # and the next render, with the same tables, lists none
  dir <- e2x_scenario(c(old, list(t7c_entry("tbl-a"), t7c_entry("tbl-b"))),
                      c(old, list(t7c_entry("tbl-a"), t7c_entry("tbl-b"))))
  out2 <- capture.output(print(weft::changes(path = dir)))
  expect_length(grep("tables? (added|removed)|table `", out2), 0L)
})

# ---- brief ---------------------------------------------------------------------------------------------------------

test_that("N35: print(brief = TRUE) shows no table lines", {
  skip_if(Sys.which("git") == "")
  before <- list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-a", T7C_D1), t7c_entry("tbl-gone"))
  after <- list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-a", T7C_D2), t7c_entry("tbl-new"))
  full <- t7c_changes(before, after)
  expect_length(grep("table `tbl-a` changed$", full), 1L)
  expect_length(grep("table added|tables added", full), 1L)
  expect_length(grep("table removed|tables removed", full), 1L)
  brief <- t7c_changes(before, after, brief = TRUE)
  expect_length(grep("table `|tables? (added|removed)", brief), 0L)
})

# ---- N38: old ledgers, and the rest unchanged (controls) -------------------------------------------------------------

test_that("control N38: a ledger written before this package (no table entries) reads, and compares with no table lines", {
  skip_if(Sys.which("git") == "")
  lines <- e2x_ledger_lines("a.qmd", "a", list(e2x_entry("depth", "1", raw = 1, file = "a.qmd")))
  l <- weft:::read_ledger(lines = lines)
  expect_identical(nrow(l), 1L)
  expect_false("table" %in% l$kind)
  out <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)), list(e2x_entry("depth", "2", raw = 2)))
  expect_length(grep("table", out), 0L)
  expect_length(grep("after: +2", out), 1L)
})

test_that("control N38: a ledger line of kind table reads, with the v1 columns", {
  lines <- e2x_ledger_lines("a.qmd", "a", list(t7c_entry("tbl-sites")))
  l <- weft:::read_ledger(lines = lines)
  expect_identical(nrow(l), 1L)
  expect_identical(l$kind, "table")
  expect_identical(l$id, "tbl-sites")
  expect_identical(l$text, T7C_D1)
  expect_identical(l$context, "chunk")
  expect_true(is.na(l$raw))
})

test_that("N35: the value changes of a ledger that also holds tables print as they do without them", {
  skip_if(Sys.which("git") == "")
  vals <- function(x) x[grepl("depth|before:|after:", x)]
  with <- t7c_changes(list(e2x_entry("depth", "1", raw = 1), t7c_entry("tbl-a", T7C_D1)),
                      list(e2x_entry("depth", "2", raw = 2), t7c_entry("tbl-a", T7C_D2)))
  without <- t7c_changes(list(e2x_entry("depth", "1", raw = 1)), list(e2x_entry("depth", "2", raw = 2)))
  expect_identical(vals(with), vals(without))
  expect_length(grep("table `tbl-a` changed$", with), 1L)
})
