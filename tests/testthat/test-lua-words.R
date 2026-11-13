# Package 6f: every row of the committed conformance sets that 6f owns, through the Lua side
# (dev/design-6.md N100, N131, section 5). words.tsv and lists.tsv are 5h's sets; dates, sci, p,
# collapse, text and governors are 6f's. The Lua side here is the whole filter (inst/quarto/weft.lua with
# weftlib/words.lua), because words.lua's own interface is not fixed by the design: each row becomes a
# named value (or a governed span) in one document, and what the filter prints must be what R printed.
#
# How a row becomes a document is in helper-6f.R (f6_rows()). The expected text of a row is the `text`
# column read as markdown by Pandoc, because formatter output is markdown (rule 1.4.10): "10^3^" is a
# superscript, "**3**" is bold. Both sides go through the HTML writer.
#
# While a class or governor is not implemented the filter answers E20 for the row, and every row of the
# set fails with its marker as the "got".

test_that("N100, N131: every row of words.tsv (word, ord, count, no, n) prints what R printed", {
  d <- f6_read("words")
  r <- f6_rows(d)
  f6_expect_rows(d, r, "words")
})

test_that("N100, N131: every row of lists.tsv (and, or, none) prints what R printed", {
  d <- f6_read("lists")
  r <- f6_rows(d)
  f6_expect_rows(d, r, "lists")
})

test_that("N100, N131: every row of dates.tsv (.date, with .and and .or over dates) prints what R printed", {
  d <- f6_read("dates")
  expect_gte(nrow(d), 20L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "dates")
})

test_that("N100, N131: every row of sci.tsv (.sci with digits and sigfig) prints what R printed", {
  d <- f6_read("sci")
  expect_gte(nrow(d), 100L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "sci")
})

test_that("N100, N131: every row of p.tsv (.p) prints what R printed", {
  d <- f6_read("p")
  expect_gte(nrow(d), 40L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "p")
})

test_that("N100, N131: every row of collapse.tsv (.pairs, .range, sep, last, trunc, none, serial_comma) prints what R printed", {
  d <- f6_read("collapse")
  expect_gte(nrow(d), 130L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "collapse")
})

test_that("N100, N131: every row of text.tsv (.a, .cap, .strong, .em) prints what R printed", {
  d <- f6_read("text")
  expect_gte(nrow(d), 130L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "text")
})

test_that("N100, N131: every row of governors.tsv (n, sign and list arms) prints what R printed", {
  d <- f6_read("governors")
  expect_gte(nrow(d), 350L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "governors")
})

test_that("1.4.10, 1.4.1: a vector that no collapse class joins prints its elements joined with a comma and a space", {
  d <- data.frame(value = "x", classes = "date", keys = "", text = "5 January 2024, 25 December 2024",
                  record = '{"t":"list","v":[{"t":"date","v":"2024-01-05"},{"t":"date","v":"2024-12-25"}],"of":"date","keys":null}',
                  stringsAsFactors = FALSE)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "join")
})

test_that("1.4.1: the order the classes are written in does not matter", {
  one <- f6_read("collapse")
  rows <- list(
    c("c(1, 2, 3)", "and word"), c("c(1, 2, 3)", "word and"),
    c("c(1, 2, 3)", "and ord"), c("c(1, 2, 3)", "ord and"))
  want <- c("one, two and three", "one, two and three", "1st, 2nd and 3rd", "1st, 2nd and 3rd")
  rec <- vapply(c("1", "2", "3"), function(x) sprintf('{"t":"float","v":"%s"}', x), "")
  record <- sprintf('{"t":"list","v":[%s],"of":"float","keys":null}', paste(rec, collapse = ","))
  d <- data.frame(value = vapply(rows, `[`, "", 1), classes = vapply(rows, `[`, "", 2), keys = "",
                  text = want, record = record, stringsAsFactors = FALSE)
  expect_gt(nrow(one), 0L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "order")
})
