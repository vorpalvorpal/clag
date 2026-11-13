# Package 6L: conformance rows past 2^53 (dev/review-stage6.md finding 4 and its ruling: "Conformance rows past
# 2^53 for .ord, .word, .count, .range, sign, n"). The rows are in _conformance/exact-words.tsv, in the style
# of exact.tsv: HAND-DERIVED, not generated. R's own formatters take a double, which cannot hold an integer
# past 2^53 (9007199254740993 reads as 9007199254740992), and values_record() writes such a value as a float
# with 15 to 17 significant digits, so no generator in R/conformance.R can make these records. The columns
# are exact.tsv's: record, classes, keys, text. For a governor row `classes` names the governor first and
# `keys` holds `span=TEXT` as in governors.tsv. Each row goes through the whole filter (f6_rows(), as every
# set of 6f does), and the ord suffixes are checked here against an independent rule on the digit text.
# ASCII only.

x6_path <- function() test_path("_conformance", "exact-words.tsv")

x6_read <- function() {
  p <- x6_path()
  testthat::expect(file.exists(p), paste("the committed file is missing:", p))
  if (!file.exists(p)) return(data.frame(record = character(), classes = character(), keys = character(),
                                         text = character(), value = character()))
  d <- utils::read.delim(p, header = TRUE, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                         na.strings = character(), check.names = FALSE, stringsAsFactors = FALSE,
                         encoding = "UTF-8", fileEncoding = "UTF-8", blank.lines.skip = FALSE)
  d$value <- d$record
  d
}

test_that("review-6 #4: exact-words.tsv has the fixed format of the committed sets", {
  p <- x6_path()
  expect_true(file.exists(p), info = p)
  if (!file.exists(p)) return(invisible())
  raw <- readBin(p, "raw", file.size(p))
  expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), info = "no BOM")
  expect_false(as.raw(13) %in% raw, info = "LF only")
  expect_identical(raw[length(raw)], as.raw(10), info = "final newline")
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  expect_true(validUTF8(txt))
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  expect_identical(lines[1], "record\tclasses\tkeys\ttext")
  expect_true(all(lengths(regmatches(lines, gregexpr("\t", lines, fixed = TRUE))) == 3L),
              info = "three tabs on every line")
  d <- x6_read()
  expect_gte(nrow(d), 30L)
  expect_true(all(vapply(d$record, jsonlite::validate, logical(1))))
  expect_false(anyDuplicated(paste(d$record, d$classes, d$keys, sep = "\r")) > 0)
})

test_that("review-6 #4: exact-words.tsv covers .ord, .word, .count, .range, sign and n, every one past 2^53", {
  d <- x6_read()
  covered <- unique(unlist(strsplit(d$classes, " ", fixed = TRUE)))
  expect_true(all(c("ord", "word", "count", "range", "sign", "n") %in% covered))
  nums <- unlist(regmatches(d$record, gregexpr("-?[0-9]{16,}", d$record)))
  expect_gt(length(nums), 30L)
  big <- function(s) {
    s <- sub("^-", "", s)
    nchar(s) > 16L || (nchar(s) == 16L && s >= "9007199254740992")
  }
  for (cl in c("ord", "word", "count", "range", "sign", "n")) {
    rows <- d[vapply(strsplit(d$classes, " ", fixed = TRUE), function(t) cl %in% t, logical(1)), ]
    v <- unlist(regmatches(rows$record, gregexpr("-?[0-9]{16,}", rows$record)))
    expect_gt(length(v), 0L, label = paste(cl, "has rows with an integer of 16 digits or more"))
    expect_true(all(vapply(v, big, logical(1))), label = paste(cl, "rows are all at or past 2^53"))
  }
  # the ord rows end in each of the four suffixes, and in the teens
  ords <- d[d$classes == "ord", ]
  expect_setequal(sub("^[0-9,]+", "", ords$text), c("st", "nd", "rd", "th"))
})

test_that("review-6 #4: the ord suffix in every ord row follows the last two digits of the exact integer", {
  d <- x6_read()
  ords <- d[d$classes == "ord", ]
  expect_gt(nrow(ords), 10L)
  for (i in seq_len(nrow(ords))) {
    digits <- jsonlite::fromJSON(ords$record[i])$v
    last2 <- as.integer(substr(digits, nchar(digits) - 1L, nchar(digits)))
    last1 <- last2 %% 10L
    suffix <- if (last2 %in% 11:13) "th" else switch(as.character(last1), "1" = "st", "2" = "nd", "3" = "rd", "th")
    want_digits <- gsub(",", "", sub("[a-z]+$", "", ords$text[i]), fixed = TRUE)
    expect_identical(want_digits, digits, label = paste("row", i, "digits"))
    expect_identical(sub("^[0-9,]+", "", ords$text[i]), suffix, label = paste("row", i, "suffix"))
  }
})

test_that("review-6 #4: every row of exact-words.tsv prints through the filter as the file says", {
  d <- x6_read()
  r <- f6_rows(d)
  f6_expect_rows(d, r, "exact-words")
})

test_that("review-6 #4: a .range whose first end is one above the second, past 2^53, is a value error, not a range", {
  blk <- carrier(r = '{"t":"list","v":[{"t":"int","v":"9007199254740993"},{"t":"int","v":"9007199254740992"}],"of":"int","keys":null}',
                 ok = '{"t":"list","v":[{"t":"int","v":"9007199254740992"},{"t":"int","v":"9007199254740993"}],"of":"int","keys":null}')
  res <- filter_cases(c(bad = "A `r`{.range} z.", good = "A `ok`{.range} z."), list(blk), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(bad = "A <<weft: value error, line {L}>> z.",
                      good = "A 9,007,199,254,740,992\u20139,007,199,254,740,993 z."))
})
