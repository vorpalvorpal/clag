# Books: held failures, one report, and freeze (2.6.6, 2.9.2, 2.9.4, 2.9.5;
# §21 "Freeze"). Two book projects of two short chapters each, made by
# use_quarto(). Each is rendered at most twice; the renders are shared by
# the tests of a project (the slowest tests of the package).

chapter <- function(title, claim, extra = NULL) {
  c("---", sprintf("title: \"%s\"", title), "engine: knitr", "---", "",
    "```{r setup, include=FALSE}", "weft::weft_setup()", "depth <- 12.5", "```", "",
    sprintf("Depth is `r %s` here.", claim), "",
    "Also `r depth`{.num}, [one site | # sites]{n=1} and [met | not met]{if=\"depth > 5\"}.",
    extra)
}

line_of <- function(lines, pattern) grep(pattern, lines, fixed = TRUE)[1]

book_yml <- c(
  "project:", "  type: book", "book:", "  title: \"T\"", "  chapters:",
  "    - index.qmd", "    - two.qmd", "format: html", "execute:", "  freeze: auto"
)

# ---- a book with failures in both chapters ----------------------------------

bk_env <- new.env()
bk <- function() {
  if (is.null(bk_env$dir)) {
    skip_if_no_quarto()
    one <- chapter("One", "claim(depth, . > 100)")
    two <- chapter("Two", "claim(depth, . > 200)")
    bk_env$line1 <- line_of(one, "claim(depth")
    bk_env$line2 <- line_of(two, "claim(depth")
    dir <- mk_project(list(`_quarto.yml` = book_yml, `index.qmd` = one, `two.qmd` = two))
    withr::defer(unlink(dir, recursive = TRUE), teardown_env())
    bk_env$dir <- dir
    bk_env$r1 <- qrender(dir)
    bk_env$r2 <- qrender(dir)
  }
  bk_env
}

report_count <- function(log) n_matches("weft: [0-9]+ claims? failed", log)

test_that("2.6.6: failures in both chapters are held to the end: both chapters are written, with markers", {
  b <- bk()
  expect_true(file.exists(file.path(b$dir, "_book", "index.html")), label = "chapter 1 written")
  expect_true(file.exists(file.path(b$dir, "_book", "two.html")), label = "chapter 2 written")
  h1 <- paste(readLines(file.path(b$dir, "_book", "index.html"), warn = FALSE), collapse = "\n")
  h2 <- paste(readLines(file.path(b$dir, "_book", "two.html"), warn = FALSE), collapse = "\n")
  expect_match(h1, sprintf("weft: failed claim, line %d", b$line1), fixed = FALSE)
  expect_match(h2, sprintf("weft: failed claim, line %d", b$line2), fixed = FALSE)
  # 2.6.8: the printed value stays, the marker follows it
  expect_match(h1, "12.5(&lt;|<)(&lt;|<)weft: failed claim")
  # and what did resolve, resolved
  expect_match(h1, "one site", fixed = TRUE)
  expect_no_match(h1, "{.num}", fixed = TRUE)
})

test_that("2.6.6, 2.6.7: the render exits non-zero, and no chapter was stopped by an ordinary knit error", {
  b <- bk()
  expect_false(identical(b$r1$status, 0L))
  expect_no_match(b$r1$log, "Quitting from")
  expect_match(b$r1$log, "two.qmd", fixed = TRUE)
})

test_that("2.6.6, 2.6.2: ONE report lists every failure of the book, each with its file and line", {
  b <- bk()
  expect_identical(report_count(b$r1$log), 1L)
  expect_match(b$r1$log, sprintf("index\\.qmd:%d\\b", b$line1))
  expect_match(b$r1$log, sprintf("two\\.qmd:%d\\b", b$line2))
  expect_match(b$r1$log, ". > 100", fixed = TRUE)
  expect_match(b$r1$log, ". > 200", fixed = TRUE)
})

test_that("2.9.2: every executed document writes a stamp (a JSON file under .weft/stamps)", {
  b <- bk()
  stamps <- list.files(file.path(b$dir, ".weft", "stamps"), pattern = "\\.json$")
  expect_true(any(grepl("^index", stamps)), label = "a stamp for index.qmd")
  expect_true(any(grepl("^two", stamps)), label = "a stamp for two.qmd")
  for (s in stamps) {
    expect_no_error(jsonlite::fromJSON(file.path(b$dir, ".weft", "stamps", s)))
  }
})

test_that("§21 Freeze, 2.9.4: the same book rendered again, now served from freeze, fails again with the same failures", {
  b <- bk()
  # served from freeze: Quarto does not execute the chapters
  expect_match(b$r1$log, "processing file", fixed = TRUE)
  expect_no_match(b$r2$log, "processing file", fixed = TRUE)
  expect_true(dir.exists(file.path(b$dir, "_freeze")))
  expect_false(identical(b$r2$status, 0L), info = b$r2$log)
  expect_identical(report_count(b$r2$log), 1L)
  expect_match(b$r2$log, "index\\.qmd")
  expect_match(b$r2$log, "two\\.qmd")
  expect_match(b$r2$log, ". > 100", fixed = TRUE)
  expect_match(b$r2$log, ". > 200", fixed = TRUE)
})

# ---- a clean book: freeze is a report, not a failure -----------------------

fc_env <- new.env()
fc <- function() {
  if (is.null(fc_env$dir)) {
    skip_if_no_quarto()
    dir <- mk_project(list(`_quarto.yml` = book_yml,
                           `index.qmd` = chapter("One", "claim(depth, . > 5)"),
                           `two.qmd` = chapter("Two", "claim(depth, . > 10)")))
    withr::defer(unlink(dir, recursive = TRUE), teardown_env())
    fc_env$dir <- dir
    fc_env$r1 <- qrender(dir)
    fc_env$r2 <- qrender(dir)
  }
  fc_env
}

test_that("2.9.2 (control): a clean book renders, executes its chapters, and says nothing about freeze", {
  b <- fc()
  expect_identical(b$r1$status, 0L, info = b$r1$log)
  expect_match(b$r1$log, "processing file", fixed = TRUE)
  expect_no_match(b$r1$log, "freez|frozen", ignore.case = TRUE)
  expect_no_match(b$r1$log, "weft: [0-9]+ ")
  h <- paste(readLines(file.path(b$dir, "_book", "index.html"), warn = FALSE), collapse = "\n")
  expect_no_match(h, "weft: ", fixed = TRUE)
})

test_that("2.9.2: after a clean render each executed document has a stamp", {
  b <- fc()
  stamps <- list.files(file.path(b$dir, ".weft", "stamps"), pattern = "\\.json$")
  expect_true(any(grepl("^index", stamps)))
  expect_true(any(grepl("^two", stamps)))
})

test_that("2.9.2: a second render served from freeze reports how many checks did not run, and fails nothing", {
  b <- fc()
  expect_no_match(b$r2$log, "processing file", fixed = TRUE)
  expect_identical(b$r2$status, 0L, info = b$r2$log)
  expect_match(b$r2$log, "freez|frozen", ignore.case = TRUE)
  expect_match(b$r2$log, "not run|did not run|not executed|were not|was not", ignore.case = TRUE)
  expect_match(b$r2$log, "[0-9]+ +(checks?|claims?|constructs?)", ignore.case = TRUE)
  # a freeze report is not a failure report (2.6.7)
  expect_no_match(b$r2$log, "weft: [0-9]+ claims? failed")
})
