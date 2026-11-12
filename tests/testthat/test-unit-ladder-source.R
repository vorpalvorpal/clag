# Package 2h: the scanner and the ladder (1.2.3, 1.5.13, 5.3.1, 4.4.23). Contract: dev/design-2h.md
# "Writing a ladder", "Errors", "Tests" (test-unit-ladder-source.R). Scanner only: no R is evaluated.
# In a pipe-table cell the `|` of a ladder is written `\|`; in an R string that is "\\|".
if (!exists("h2_scan_errs")) source(Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))[[1]])
h2_need()

sc2 <- function(x) weft:::scan_text(x)
# the one-row scan of a text, its `unit` key, arms and error
unit_key <- function(x) { r <- sc2(x); unname(r$keys[[1]][["unit"]]) }

# a pipe table with `cell` in its second column
tbl <- function(cell) paste("| name | n |", "|------|---|", paste0("| 1 | ", cell, " |"), sep = "\n")

# ---- an empty and a repeated rung are construct errors -------------------------------------------------------

test_that("2h 5.3.1: an empty rung in unit is a construct error, whatever the construct", {
  for (bad in c("mm||km", "m|", "|m", "mm| |km", "|")) {
    for (src in c(sprintf("`r x`{unit=\"%s\"}", bad), sprintf("`r x`{.num unit=\"%s\"}", bad),
                  sprintf("[# a | # b]{n=\"x\" unit=\"%s\"}", bad), sprintf("`r x`{unit=\"%s\" .uname}", bad))) {
      e <- h2_scan_errs(src)
      expect_gte(length(e), 1L, label = src)
      expect_match(e[1], "empty rung", fixed = TRUE, label = src)
      expect_match(e[1], "4.4.23", fixed = TRUE, label = src)
    }
  }
})

test_that("2h 5.3.1: a rung written twice is a construct error, spaces around a rung ignored", {
  for (bad in c("m|m", "m| m", "m|km|m", "mm | m | m ", "ug/L|mg/L|ug/L")) {
    e <- h2_scan_errs(sprintf("`r x`{unit=\"%s\"}", bad))
    expect_gte(length(e), 1L, label = bad)
    expect_match(e[1], "on the ladder twice", fixed = TRUE, label = bad)
    expect_match(e[1], "4.4.23", fixed = TRUE, label = bad)
  }
  e <- h2_scan_errs("`r x`{unit=\"m|km|m\"}")
  expect_match(e[1], "`m`", fixed = TRUE)
})

test_that("2h 5.3.1: an empty rung is told apart from other errors: the message says to separate units with |", {
  e <- h2_scan_errs("`r x`{unit=\"mm||km\"}")
  expect_match(e[1], "separate units with `|`", fixed = TRUE)
})

test_that("2h 4.4.23: a well-formed ladder is no error, with or without spaces and with compound rungs (control)", {
  for (ok in c("m|km", "mm|m|km", "mm | m | km", "CFU/100 mL|CFU/L", "ug/L|mg/L", "km", "m")) {
    expect_equal(h2_scan_errs(sprintf("`r x`{unit=\"%s\"}", ok)), character(0), label = ok)
    expect_equal(h2_scan_errs(sprintf("[# a | # b]{n=\"x\" unit=\"%s\"}", ok)), character(0), label = ok)
  }
})

test_that("2h 4.4.23: the scanner keeps the ladder in the unit key", {
  expect_equal(unit_key("`r x`{unit=\"mm|m|km\"}"), "mm|m|km")
  expect_equal(unit_key("`r x`{.num unit=\"m|km\" digits=\"2\"}"), "m|km")
})

# ---- \| in unit -------------------------------------------------------------------------------------------------------

test_that("2h 1.5.13: in a pipe-table cell \\| in a value's unit is read as |", {
  r <- sc2(tbl("`r x`{unit=\"mm\\|m\\|km\"}"))
  expect_equal(nrow(r), 1L)
  expect_true(is.na(r$error))
  expect_equal(unname(r$keys[[1]][["unit"]]), "mm|m|km")
})

test_that("2h 1.5.13: in a pipe-table cell \\| in a span's unit is read as |, and the arm separator stays an arm separator", {
  r <- sc2(tbl("[# was \\| # were]{n=\"x\" unit=\"mm\\|m\\|km\"}"))
  expect_equal(nrow(r), 1L)
  expect_true(is.na(r$error))
  expect_equal(r$kind, "n")
  expect_equal(unname(r$keys[[1]][["unit"]]), "mm|m|km")
  expect_length(r$arms[[1]], 2L)
})

test_that("2h 1.2.3: outside a table \\| in unit is accepted and read as |", {
  r <- sc2("`r x`{unit=\"mm\\|m\\|km\"}")
  expect_true(is.na(r$error))
  expect_equal(unname(r$keys[[1]][["unit"]]), "mm|m|km")
  r2 <- sc2("[# was | # were]{n=\"x\" unit=\"mm\\|m\"}")
  expect_true(is.na(r2$error))
  expect_equal(unname(r2$keys[[1]][["unit"]]), "mm|m")
  expect_length(r2$arms[[1]], 2L)
})

test_that("2h 1.2.3: a ladder read from \\| is checked as a ladder (an empty or repeated rung is the error)", {
  e1 <- h2_scan_errs("`r x`{unit=\"mm\\|\\|km\"}")
  expect_length(e1, 1L)
  expect_match(e1, "empty rung", fixed = TRUE)
  e2 <- h2_scan_errs("`r x`{unit=\"m\\|m\"}")
  expect_length(e2, 1L)
  expect_match(e2, "on the ladder twice", fixed = TRUE)
  e3 <- h2_scan_errs(tbl("`r x`{unit=\"m\\|m\"}"))
  expect_length(e3, 1L)
  expect_match(e3, "on the ladder twice", fixed = TRUE)
})

# ---- an unescaped | in unit in a pipe-table cell ---------------------------------------------------------------------

test_that("2h 1.5.13, 5.3.1: an unescaped | in the unit of a value in a pipe-table cell is a construct error", {
  e <- h2_scan_errs(tbl("`r x`{unit=\"mm|m|km\"}"))
  expect_gte(length(e), 1L)
  expect_match(e[1], "unescaped `|`", fixed = TRUE)
  expect_match(e[1], "unit", fixed = TRUE)
  expect_match(e[1], "rule 1.5.13", fixed = TRUE)
  expect_match(e[1], "\\|", fixed = TRUE)                    # the message shows a backslash and a bar
})

test_that("2h 1.5.13, 5.3.1: the same in a span's unit, in any column", {
  e <- h2_scan_errs(tbl("[# was | # were]{n=\"x\" unit=\"mm|m|km\"}"))
  expect_gte(length(e), 1L)
  expect_true(any(grepl("rule 1.5.13", e, fixed = TRUE)))
  e2 <- h2_scan_errs(paste("| name | n |", "|------|---|", "| `r x`{unit=\"m|km\"} | 1 |", sep = "\n"))
  expect_gte(length(e2), 1L)
  expect_true(any(grepl("unit", e2, fixed = TRUE)))
})

test_that("2h 1.5.13: an unescaped | in unit outside a pipe table is not that error (control)", {
  expect_equal(h2_scan_errs("`r x`{unit=\"mm|m|km\"}"), character(0))
  expect_equal(h2_scan_errs("A line with a | bar and `r x`{unit=\"m|km\"}."), character(0))
})

test_that("2h 1.5.13: a table cell with a unit of one rung needs no escape (control)", {
  expect_equal(h2_scan_errs(tbl("`r x`{unit=\"km\"}")), character(0))
})

# ---- a \ elsewhere stays the 1.2.3 error (controls) -------------------------------------------------------------------

test_that("2h 1.2.3 control: a \\ elsewhere in unit stays an error", {
  for (bad in c("m\\x", "m\\\\km", "mm\\ m", "\\m", "m\\")) {
    e <- h2_scan_errs(sprintf("`r x`{unit=\"%s\"}", bad))
    expect_gte(length(e), 1L, label = bad)
    expect_match(e[1], "rule 1.2.3", fixed = TRUE, label = bad)
  }
})

test_that("2h 1.2.3 control: \\| in a key other than unit stays an error", {
  for (src in c("`r x`{digits=\"1\\|2\"}", "[a | b]{if=\"x\\|y\"}", "[a | b]{n=\"x\\|y\"}", "`r x`{.num sigfig=\"2\\|3\"}")) {
    e <- h2_scan_errs(src)
    expect_gte(length(e), 1L, label = src)
    expect_match(e[1], "rule 1.2.3", fixed = TRUE, label = src)
  }
})

test_that("2h 1.2.3 control: a \\ in a value that is not \\| in unit is the error, with a ladder beside it", {
  expect_gte(length(h2_scan_errs("`r x`{unit=\"mm\\|m\" if=\"a\\b\"}")), 1L)
  expect_gte(length(h2_scan_errs("`r x`{unit=\"mm\\|m\\x\"}")), 1L)
})

# ---- a | in unit does not change a span's arm count ---------------------------------------------------------------------

test_that("2h 1.1.9: a | in unit does not change a span's arm count", {
  r1 <- sc2("[# was | # were]{n=\"x\" unit=\"mm|m|km\"}")
  r0 <- sc2("[# was | # were]{n=\"x\" unit=\"m\"}")
  expect_equal(nrow(r1), 1L)
  expect_true(is.na(r1$error))
  expect_equal(r1$arms[[1]], r0$arms[[1]])
  expect_length(r1$arms[[1]], 2L)
  r3 <- sc2("[none | # was | # were]{list=\"x\" unit=\"m|km\"}")
  expect_true(is.na(r3$error))
  expect_length(r3$arms[[1]], 3L)
  r4 <- sc2("[rose by # | fell by #]{sign=\"x\" unit=\"mm|m\"}")
  expect_true(is.na(r4$error))
  expect_length(r4$arms[[1]], 2L)
})

test_that("2h 1.1.9: a ladder in a span inside an arm does not split the outer arms", {
  r <- sc2("[a `r x`{unit=\"m|km\"} b | c]{if=\"z\"}")
  expect_equal(nrow(r), 2L)
  expect_true(all(is.na(r$error)))
  expect_length(r$arms[[1]], 2L)
  expect_equal(r$kind, c("if", "value"))
})

test_that("2h 1.5.13: in a table cell the arm separator and the ladder separator are both written \\| and both read", {
  r <- sc2(tbl("[# was \\| # were]{n=\"x\" unit=\"m\\|km\"}"))
  expect_true(is.na(r$error))
  expect_length(r$arms[[1]], 2L)
  expect_equal(unname(r$keys[[1]][["unit"]]), "m|km")
})
