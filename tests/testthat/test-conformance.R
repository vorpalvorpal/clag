# Package 5h: the conformance table (dev/design-5.md, "Amendment after the
# scoping of architecture (c)", item 3).
#
# The table is the definition of "what weft prints": a fixed corpus of values
# run through weft's own formatter, written to committed files, and compared
# on every test run. It is a regression net for R/format.R now and the
# reference for any second formatter later.
#
# INTERFACE FIXED BY THESE TESTS (the implementer builds to this)
# ---------------------------------------------------------------
# weft:::conformance_rows(set = c("all", "numbers", "words", "lists"))
#   Returns a data frame (stringsAsFactors = FALSE, any row names) with
#   exactly four character columns (five since package 6a: see CONF_COLS and
#   test-lua-num.R, which adds `record`), in this order, no NA:
#     value    how the value is written: R code that parses and evaluates in
#              base R alone (the base environment, no weft, no variables) to
#              the value. One line; no tab, no newline.
#     classes  the weft classes applied, space-separated, without dots:
#              "num", "pct", "word", "ord", "count", "no", "and", "or", "n".
#              A single formatter class is one token. (Extra classes for a
#              row, such as "num pct", are allowed but then the row is not
#              cross-checked against a single fmt_*() call.)
#     keys     "key=value" pairs separated by single spaces, or "". Values
#              hold no space. Keys used by these tests: digits=<k> and
#              sigfig=<k> (numbers), none=<text> (lists). An `n` row (a
#              plural form) puts the arms in its keys in any form the
#              implementer likes; its `value` is the governor.
#     text     what weft prints for that value, classes and keys, as a plain
#              string (U+2212 for the minus sign, as printed).
#   `set` = "numbers", "words" or "lists" returns that part; "all" (the
#   default) is the three parts stacked in the order numbers, words, lists.
#   The "words" set holds the word, ord, count, no and n rows; the "lists"
#   set holds the and and or rows. The function takes no random input and
#   returns the same rows in the same order every call. It never errors on
#   a corpus row: every row prints text.
#
# weft:::conformance_write(dir)
#   Creates `dir` if needed and writes numbers.tsv, words.tsv, lists.tsv in
#   it from the live rows (and no other file). Returns the three paths
#   invisibly. Each file: UTF-8, no BOM, LF line ends, a final newline, one
#   header line "value<TAB>classes<TAB>keys<TAB>text", then one line per row,
#   fields separated by a single tab, nothing quoted or escaped, rows in the
#   order conformance_rows() returns them.
#
# tests/testthat/_conformance/{numbers,words,lists}.tsv
#   The committed expected rows, in that format. Regenerate them with
#     weft:::conformance_write("tests/testthat/_conformance")
#   after a deliberate change to what weft prints, and review the diff.
#
# The corpus must include (these tests check the committed files for it, and
# check the live rows equal the files, so the corpus cannot shrink unseen):
#   numbers: at least 300 rows; classes num and pct; magnitudes from 1e-6 to
#     1e14 (every power of ten in between has a row); ties (0.15, 0.25, 2.5,
#     0.5, 1.5, -2.5 ...); floating-point noise (0.1 + 0.2, 0.1 + 0.2 - 0.3);
#     doubles that are whole, R integers (written with L), negatives, zero;
#     digits 0 to 6 and sigfig 1 to 5 each used; the pinned rows 999999999999999,
#     2^53, 2^70 and 1e23 under "num" with no keys.
#   words: word, ord (including 11, 12, 13, 21, 22, 23, 101, 111), count,
#     no, and n rows (plural forms with governors 0, 1, 2 and 3).
#   lists: and and or over vectors of length 1 to 4, character and numeric,
#     and an empty vector with a none key.

CONF_DIR <- test_path("_conformance")
CONF_SETS <- c("numbers", "words", "lists")
# Package 6a (dev/design-6.md, N131) added the fifth column, `record`: the JSON record N47 makes of
# `value`. test-lua-num.R checks its content; here it only changes the columns and the tab count.
CONF_COLS <- c("value", "classes", "keys", "text", "record")

conf_path <- function(set) file.path(CONF_DIR, paste0(set, ".tsv"))

conf_read <- function(path) {
  d <- utils::read.delim(path, header = TRUE, sep = "\t", quote = "",
                         comment.char = "", colClasses = "character",
                         na.strings = character(), check.names = FALSE,
                         stringsAsFactors = FALSE, encoding = "UTF-8",
                         fileEncoding = "UTF-8", blank.lines.skip = FALSE)
  rownames(d) <- NULL
  d
}

conf_live <- function(set = "all") {
  d <- weft:::conformance_rows(set)
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  rownames(d) <- NULL
  d
}

# the first rows where two tables differ, as a message
conf_diff <- function(live, file, n = 5) {
  if (!identical(names(live), names(file))) {
    return(paste0("columns differ: live ", paste(names(live), collapse = ","),
                  "; file ", paste(names(file), collapse = ",")))
  }
  m <- max(nrow(live), nrow(file))
  pad <- function(d) {
    d[seq_len(m), , drop = FALSE]
  }
  a <- pad(live); b <- pad(file)
  bad <- which(vapply(seq_len(m), function(i) {
    !identical(unlist(a[i, ], use.names = FALSE), unlist(b[i, ], use.names = FALSE))
  }, logical(1)))
  bad <- utils::head(bad, n)
  paste0(nrow(live), " live rows, ", nrow(file), " committed rows; first differences:\n",
         paste(vapply(bad, function(i) {
           paste0("  row ", i, "\n    live:      ",
                  paste(unlist(a[i, ]), collapse = " | "),
                  "\n    committed: ", paste(unlist(b[i, ]), collapse = " | "))
         }, character(1)), collapse = "\n"))
}

conf_eval <- function(v) eval(parse(text = v), envir = baseenv())

conf_tokens <- function(x) strsplit(x, " ", fixed = TRUE)

conf_keys <- function(k) {
  if (!nzchar(k)) return(list())
  parts <- strsplit(k, " ", fixed = TRUE)[[1]]
  nm <- sub("=.*$", "", parts)
  val <- sub("^[^=]*=", "", parts)
  stats::setNames(as.list(val), nm)
}

conf_has_class <- function(d, cls) {
  vapply(conf_tokens(d$classes), function(t) cls %in% t, logical(1))
}

# ---- the function ------------------------------------------------------------

test_that("5h: conformance_rows() returns a five-column character data frame (6a added record)", {
  d <- weft:::conformance_rows()
  expect_s3_class(d, "data.frame")
  expect_identical(names(d), CONF_COLS)
  expect_true(all(vapply(d, is.character, logical(1))))
  expect_gt(nrow(d), 0)
  expect_false(anyNA(d))
  for (s in CONF_SETS) {
    x <- weft:::conformance_rows(s)
    expect_identical(names(x), CONF_COLS)
    expect_gt(nrow(x), 0)
  }
})

test_that("5h: the default is the three sets stacked in order", {
  all <- conf_live("all")
  expect_identical(conf_live(), all)
  stacked <- rbind(conf_live("numbers"), conf_live("words"), conf_live("lists"))
  rownames(stacked) <- NULL
  expect_identical(all, stacked)
})

test_that("5h: the rows are deterministic", {
  expect_identical(conf_live("all"), conf_live("all"))
})

test_that("5h: every value is code that evaluates in base R, on one line", {
  d <- conf_live()
  expect_false(any(grepl("[\t\n\r]", unlist(d))))
  for (v in unique(d$value)) {
    r <- tryCatch(conf_eval(v), error = function(e) e)
    expect_false(inherits(r, "error"), info = v)
  }
})

# ---- the committed files ------------------------------------------------------

test_that("5h: the committed files exist, with the fixed format", {
  for (s in CONF_SETS) {
    p <- conf_path(s)
    expect_true(file.exists(p), info = p)
    if (!file.exists(p)) next
    raw <- readBin(p, "raw", file.size(p))
    expect_gt(length(raw), 0)
    expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), info = "no BOM")
    expect_false(as.raw(13) %in% raw, info = "LF line ends only")
    expect_identical(raw[length(raw)], as.raw(10), info = "final newline")
    txt <- rawToChar(raw)
    Encoding(txt) <- "UTF-8"
    expect_true(validUTF8(txt))
    lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
    expect_identical(lines[1], paste(CONF_COLS, collapse = "\t"))
    expect_true(all(lengths(regmatches(lines, gregexpr("\t", lines, fixed = TRUE))) == 4L),
                info = "four tabs on every line")
  }
})

test_that("5h: every row weft computes equals the committed row", {
  for (s in CONF_SETS) {
    p <- conf_path(s)
    expect_true(file.exists(p), info = p)
    if (!file.exists(p)) next
    live <- conf_live(s)
    file <- conf_read(p)
    ok <- identical(live, file)
    expect(ok, paste0("set ", s, ": ", conf_diff(live, file)))
  }
})

test_that("5h: the committed files have no duplicate keys", {
  for (s in CONF_SETS) {
    p <- conf_path(s)
    expect_true(file.exists(p), info = p)
    if (!file.exists(p)) next
    d <- conf_read(p)
    key <- paste(d$value, d$classes, d$keys, sep = "\r")
    expect_false(anyDuplicated(key) > 0,
                 info = paste(s, "duplicate:", d$value[anyDuplicated(key)]))
  }
})

# ---- what the corpus covers ---------------------------------------------------

conf_numbers <- function() {
  p <- conf_path("numbers")
  if (!file.exists(p)) stop("committed file missing: ", p, call. = FALSE)
  d <- conf_read(p)
  d$val <- lapply(d$value, conf_eval)
  d
}

test_that("5h corpus, numbers: size and classes", {
  d <- conf_numbers()
  expect_gte(nrow(d), 300)
  expect_true(any(conf_has_class(d, "num")))
  expect_true(any(conf_has_class(d, "pct")))
  expect_true(all(vapply(d$val, is.numeric, logical(1))))
})

test_that("5h corpus, numbers: every power of ten from 1e-6 to 1e14", {
  d <- conf_numbers()
  num <- d[conf_has_class(d, "num"), ]
  v <- abs(vapply(num$val, function(x) as.numeric(x)[1], numeric(1)))
  for (k in -6:14) {
    lo <- 10^k * (1 - 1e-9)
    hi <- 10^(k + 1) * (1 - 1e-9)
    expect_true(any(v >= lo & v < hi), info = paste("magnitude 1e", k))
  }
})

test_that("5h corpus, numbers: digits 0 to 6 and sigfig 1 to 5 each appear", {
  d <- conf_numbers()
  keys <- lapply(d$keys, conf_keys)
  dig <- unlist(lapply(keys, `[[`, "digits"))
  sig <- unlist(lapply(keys, `[[`, "sigfig"))
  for (k in 0:6) expect_true(as.character(k) %in% dig, info = paste("digits", k))
  for (k in 1:5) expect_true(as.character(k) %in% sig, info = paste("sigfig", k))
  expect_true(any(d$keys == ""), info = "rows with no key")
})

test_that("5h corpus, numbers: ties, noise, integers, negatives, zero, pinned rows", {
  d <- conf_numbers()
  vals <- vapply(d$val, function(x) as.numeric(x)[1], numeric(1))
  for (x in c(0.15, 0.25, 0.35, 2.5, 0.5, 1.5, -2.5, -0.15, 1.005)) {
    expect_true(any(vals == x), info = paste("tie", x))
  }
  expect_true(any(vals == 0.1 + 0.2 & vals != 0.3), info = "0.1 + 0.2")
  expect_true(any(abs(vals) < 1e-9 & vals != 0), info = "noise below 1e-9")
  expect_true(any(vals == 0), info = "zero")
  expect_true(any(vals < 0), info = "negatives")
  expect_true(any(vapply(d$val, is.integer, logical(1))), info = "R integers")
  expect_true(any(vapply(d$val, function(x) is.double(x) && x == round(x) && abs(x) >= 1, logical(1))),
              info = "whole doubles")
  pinned <- c("999999999999999" = "999,999,999,999,999",
              "2^53" = "9,007,199,254,740,992",
              "2^70" = "1,180,591,620,717,410,000,000",
              "1e23" = "100,000,000,000,000,000,000,000")
  for (i in seq_along(pinned)) {
    want <- conf_eval(names(pinned)[i])
    rows <- d[vapply(d$val, function(x) identical(as.numeric(x), want), logical(1)) &
                d$classes == "num" & d$keys == "", ]
    expect_gte(nrow(rows), 1, label = paste("pinned row", names(pinned)[i]))
    expect_true(all(rows$text == pinned[[i]]), info = names(pinned)[i])
  }
})

test_that("5h corpus, numbers: the printed text is what the public formatter prints", {
  d <- conf_numbers()
  f <- list(num = fmt_num, pct = fmt_pct)
  checked <- 0L
  for (i in seq_len(nrow(d))) {
    cl <- d$classes[i]
    if (!cl %in% names(f)) next
    k <- conf_keys(d$keys[i])
    if (!all(names(k) %in% c("digits", "sigfig"))) next
    args <- c(list(d$val[[i]]), lapply(k, as.integer))
    want <- suppressWarnings(as.character(unclass(do.call(f[[cl]], args))))
    expect_identical(d$text[i], want, info = paste(d$value[i], cl, d$keys[i]))
    checked <- checked + 1L
  }
  expect_gte(checked, 250L)
})

conf_set <- function(set) {
  p <- conf_path(set)
  if (!file.exists(p)) stop("committed file missing: ", p, call. = FALSE)
  d <- conf_read(p)
  d$val <- lapply(d$value, conf_eval)
  d
}

conf_vals <- function(d, cls) {
  rows <- d[conf_has_class(d, cls), ]
  unlist(lapply(rows$val, as.numeric))
}

test_that("5h corpus, words: word, ord, count, no and n rows", {
  d <- conf_set("words")
  for (cl in c("word", "ord", "count", "no", "n")) {
    expect_true(any(conf_has_class(d, cl)), info = cl)
  }
  expect_true(all(0:12 %in% conf_vals(d, "word")), info = "word 0 to 12")
  expect_true(all(c(1:4, 11:13, 21:23, 101, 111) %in% conf_vals(d, "ord")), info = "ord edge cases")
  expect_true(all(c(1, 9, 10, 11, 12) %in% conf_vals(d, "count")), info = "count around the threshold")
  expect_true(all(0:3 %in% conf_vals(d, "n")), info = "n governors 0 to 3")
  expect_true(all(d$text != ""))
})

test_that("5h corpus, words: the text is what the public formatter prints", {
  d <- conf_set("words")
  f <- list(word = fmt_word, ord = fmt_ord, count = fmt_count, no = fmt_no)
  checked <- 0L
  for (i in seq_len(nrow(d))) {
    cl <- d$classes[i]
    if (!cl %in% names(f) || nzchar(d$keys[i])) next
    expect_identical(d$text[i], as.character(unclass(f[[cl]](d$val[[i]]))),
                     info = paste(d$value[i], cl))
    checked <- checked + 1L
  }
  expect_gte(checked, 30L)
})

test_that("5h corpus, lists: and and or over vectors of 1 to 4, and an empty one", {
  d <- conf_set("lists")
  for (cl in c("and", "or")) {
    rows <- d[conf_has_class(d, cl), ]
    expect_gt(nrow(rows), 0, label = cl)
    lens <- vapply(rows$val, length, integer(1))
    for (n in 1:4) expect_true(n %in% lens, info = paste(cl, "length", n))
    expect_true(any(vapply(rows$val, is.character, logical(1))), info = paste(cl, "character"))
    expect_true(any(vapply(rows$val, is.numeric, logical(1))), info = paste(cl, "numeric"))
    expect_true(any(lens == 0L & grepl("(^| )none=", rows$keys)), info = paste(cl, "empty with none"))
  }
})

test_that("5h corpus, lists: the text is what the public formatter prints", {
  d <- conf_set("lists")
  f <- list(and = fmt_and, or = fmt_or)
  checked <- 0L
  for (i in seq_len(nrow(d))) {
    cl <- d$classes[i]
    if (!cl %in% names(f)) next
    k <- conf_keys(d$keys[i])
    if (!all(names(k) %in% "none")) next
    args <- c(list(d$val[[i]]), k)
    expect_identical(d$text[i], as.character(unclass(do.call(f[[cl]], args))),
                     info = paste(d$value[i], cl, d$keys[i]))
    checked <- checked + 1L
  }
  expect_gte(checked, 8L)
})

# ---- regeneration -------------------------------------------------------------

test_that("5h: conformance_write() writes exactly the committed files, byte for byte", {
  out <- file.path(withr::local_tempdir(), "regen")
  paths <- weft:::conformance_write(out)
  # package 6f writes six more sets (test-conformance-6f.R checks them)
  expect_setequal(list.files(out), paste0(c(CONF_SETS, CONF_6F), ".tsv"))
  expect_setequal(basename(unlist(paths)), paste0(c(CONF_SETS, CONF_6F), ".tsv"))
  for (s in CONF_SETS) {
    p <- conf_path(s)
    expect_true(file.exists(p), info = p)
    if (!file.exists(p)) next
    a <- readBin(file.path(out, paste0(s, ".tsv")), "raw", 1e8)
    b <- readBin(p, "raw", 1e8)
    expect_identical(a, b, info = s)
  }
})

test_that("5h: conformance_write() writes from the live rows into an existing directory", {
  out <- withr::local_tempdir()
  weft:::conformance_write(out)
  for (s in CONF_SETS) {
    expect_identical(conf_read(file.path(out, paste0(s, ".tsv"))), conf_live(s), info = s)
  }
})
