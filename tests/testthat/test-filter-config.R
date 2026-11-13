# Package 6c: the filter's configuration (dev/design-6.md N84, D18; rules 9.1.1, 9.1.5, 9.1.6). The filter
# reads `_weft.yml` (found upward from the source's folder) and the `weft:` mapping of the source's own
# front matter, as text, with a flat reader: lines `KEY: VALUE` at the top level of _weft.yml and at one
# indent level under `weft:`; VALUE a double-quoted string (JSON escapes), a single-quoted string (''
# for '), true, false, an integer or a bare word, a trailing `# comment` removed; the nested keys of other
# settings are skipped; the document's value wins. Each setting is seen through the number it prints.
# While inst/quarto/weft.lua does not exist every test fails on that.

MINUS <- "\u2212"

cfg_block <- function() {
  carrier(g = fr_float("3.14159"), f = fr_float("1234.5"), i = fr_int("1234567"), j = fr_int("12345"),
          k = fr_int("1234"), neg = fr_float("-3.14159"))
}
cfg_cases <- c(g = "`g`{.num}", f = "`f`{.num}", i = "`i`{.num}", j = "`j`{.num}", k = "`k`{.num}",
               neg = "`neg`{.num}")
cfg_expected <- function(...) {
  base <- c(g = "3.1", f = "1,234.5", i = "1,234,567", j = "12,345", k = "1,234", neg = paste0(MINUS, "3.1"))
  over <- list(...)
  base[names(over)] <- unlist(over)
  base
}

# the output text of each case under a configuration
cfg_run <- function(yml = NULL, head = character(), draft = FALSE, ...) {
  filter_cases(cfg_cases, list(cfg_block()), weft_yml = yml, head = head, draft = draft, ...)
}

test_that("N84: with no configuration the defaults are digits 1, big mark ',', thousands from 1000, minus U+2212", {
  res <- cfg_run()
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected())
})

test_that("N84: an integer value (digits: 2), with trailing spaces and a comment removed", {
  res <- cfg_run(c("digits: 2   # places for a number that is not whole"))
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected(g = "3.14", f = "1,234.50", neg = paste0(MINUS, "3.14")))
})

test_that("N84: double-quoted strings for decimal_mark and big_mark", {
  res <- cfg_run(c("decimal_mark: \",\"", "big_mark: \".\""))
  expect_cases(res, cfg_expected(g = "3,1", f = "1.234,5", i = "1.234.567", j = "12.345", k = "1.234",
                                 neg = paste0(MINUS, "3,1")))
})

test_that("N84, D18: big_mark: \" \" and minus: \"--\" are read exactly (Pandoc's metadata would mangle them)", {
  res <- cfg_run(c("big_mark: \" \"", "minus: \"--\""))
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected(f = "1 234.5", i = "1 234 567", j = "12 345", k = "1 234", neg = "--3.1"))
})

test_that("N84: a single-quoted string, with '' for an apostrophe", {
  res <- cfg_run(c("minus: '-'", "big_mark: ''''"))
  expect_cases(res, cfg_expected(f = "1'234.5", i = "1'234'567", j = "12'345", k = "1'234", neg = "-3.1"))
})

test_that("N84: a double-quoted string takes JSON escapes", {
  res <- cfg_run(c("big_mark: \"\\u202f\""))
  nn <- "\u202f"
  expect_cases(res, cfg_expected(f = paste0("1", nn, "234.5"), i = paste0("1", nn, "234", nn, "567"),
                                 j = paste0("12", nn, "345"), k = paste0("1", nn, "234")))
})

test_that("N84: a bare word, and a # inside quotes is not a comment", {
  res <- cfg_run(c("big_mark: x"))
  expect_cases(res, cfg_expected(f = "1x234.5", i = "1x234x567", j = "12x345", k = "1x234"))
  res2 <- cfg_run(c("big_mark: \"#\"   # a hash"))
  expect_cases(res2, cfg_expected(f = "1#234.5", i = "1#234#567", j = "12#345", k = "1#234"))
})

test_that("N84, 1.4.16: thousands_from sets the smallest absolute value that gets the mark", {
  res <- cfg_run(c("thousands_from: 10000"))
  expect_cases(res, cfg_expected(f = "1234.5", i = "1,234,567", j = "12,345", k = "1234"))
})

test_that("N84: the nested keys of other settings are skipped, unknown keys are ignored, nothing is reported", {
  yml <- c("formatters:", "  .compact:", "    digits: 9", "    big_mark: \"!\"",
           "units:", "  m:", "    digits: 8", "claim_words: {add: [a], drop: []}",
           "foo: bar", "ledger: false", "serial_comma: true")
  res <- cfg_run(yml)
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected())
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N84, 9.1.1: the document's weft: key wins, setting by setting; a top-level key of the front matter is not read", {
  yml <- c("digits: 3", "big_mark: \" \"")
  res <- cfg_run(yml, head = c("---", "weft:", "  digits: 2", "---", ""))
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected(g = "3.14", f = "1 234.50", i = "1 234 567", j = "12 345", k = "1 234",
                                 neg = paste0(MINUS, "3.14")))
  res2 <- cfg_run(yml)
  expect_cases(res2, cfg_expected(g = "3.142", f = "1 234.500", i = "1 234 567", j = "12 345", k = "1 234",
                                  neg = paste0(MINUS, "3.142")))
  res3 <- cfg_run(NULL, head = c("---", "digits: 5", "title: T", "---", ""))
  expect_cases(res3, cfg_expected())
})

test_that("N84: _weft.yml is found upward from the source's folder", {
  res <- cfg_run(c("digits: 2"), name = "sub/a/doc.md", run_in = "sub/a")
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected(g = "3.14", f = "1,234.50", neg = paste0(MINUS, "3.14")))
})

test_that("N84, E33: a value of the wrong kind is one configuration failure, reported once, and the default is used", {
  res <- cfg_run(c("digits: two", "thousands_from: lots"), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected())
  count <- function(rx) lengths(regmatches(res$stderr, gregexpr(rx, res$stderr)))
  expect_identical(count("_weft\\.yml: `digits: two` is not a [a-z ]+; the default is used \\(rule 9\\.1\\.6\\)\\."), 1L)
  expect_identical(count("_weft\\.yml: `thousands_from: lots` is not a [a-z ]+; the default is used \\(rule 9\\.1\\.6\\)\\."), 1L)
})

test_that("N84, E33: in the document's own weft: key the failure names the document", {
  res <- cfg_run(NULL, head = c("---", "weft:", "  digits: two", "---", ""), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, cfg_expected())
  rx <- "doc\\.md: `digits: two` is not a [a-z ]+; the default is used \\(rule 9\\.1\\.6\\)\\."
  expect_identical(lengths(regmatches(res$stderr, gregexpr(rx, res$stderr))), 1L)
})
