# Package 6b, rules N42, N43, N45, N48 and N130h steps 1 and 2 (dev/design-6.md):
# in a knit of an .Rmd the hooks write weft-values blocks. The knits are raw
# knitr output (no Pandoc, no filter); a block is read from the output lines.
# Helpers: helper-6b.R. The filter does not exist yet: these tests read what
# the R side writes and never run it.

chunk <- function(label, ..., opts = "include=FALSE") {
  c(sprintf("```{r %s, %s}", label, opts), c(...), "```", "")
}

block_value <- function(b, name) b6_core(b$block$values[[name]])

# ---- a block before the prose that uses the name (N43) ------------------------

test_that("N43: a name the prose mentions, bound in a chunk, is published in a block before that prose", {
  res <- b6_knit(c(
    chunk("calc", "depth <- 3.14159"),
    "The depth is `depth`{.num} metres."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  expect_identical(b$block$weft, 1L)
  expect_identical(b$block$lang, "r")
  expect_identical(block_value(b, "depth"), b6_e_float("3.14159"))
  prose <- b6_line(res$text, "The depth is")
  expect_false(is.na(prose))
  expect_true(b$close < prose)
  # the construct is left for the filter, as written
  expect_true(any(grepl("`depth`{.num}", res$text, fixed = TRUE)))
})

test_that("N20: a block is fenced with four or more backticks, and its text is one line of JSON", {
  res <- b6_knit(c(chunk("calc", "depth <- 1.5"), "Uses `depth`{.num}."))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  expect_gte(b$fence, 4L)
  expect_identical(b$nlines, 1L)
  expect_true(jsonlite::validate(b$text))
  expect_true(startsWith(b$text, "{\"weft\":1,\"lang\":\"r\",\"run\":"))
})

test_that("N43: each kind of R value the prose names is published as N47 says, with its current binding", {
  res <- b6_knit(c(
    chunk("calc",
          "d <- 3.5", "n <- 4L", "ok <- TRUE", "site <- 'north'",
          "when <- as.Date('2026-11-13')", "vec <- c(a = 1L, b = 2L)", "gone <- NA_real_"),
    "Names `d`{.num} `n`{.num} `ok`{.val} `site`{.val} `when`{.val} `vec`{.and} `gone`{.num}."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  expect_setequal(names(b$block$values), c("d", "n", "ok", "site", "when", "vec", "gone"))
  expect_identical(block_value(b, "d"), b6_e_float("3.5"))
  expect_identical(block_value(b, "n"), b6_e_int("4"))
  expect_identical(block_value(b, "ok"), b6_e_bool(TRUE))
  expect_identical(block_value(b, "site"), b6_e_str("north"))
  expect_identical(block_value(b, "when"), b6_e_date("2026-11-13"))
  expect_identical(block_value(b, "vec"),
                   b6_e_list("int", list(b6_e_int("1"), b6_e_int("2")), keys = c("a", "b")))
  expect_identical(block_value(b, "gone"), b6_e_miss("NA"))
})

test_that("N43: a value N47 refuses is published as an error record, and the knit goes on", {
  res <- b6_knit(c(
    chunk("calc", "frame <- data.frame(a = 1)", "len <- units::set_units(5, 'm')", "fine <- 2L"),
    "Names `frame`{.num} `len`{.num} `fine`{.num}."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  vals <- res$blocks[[1]]$block$values
  expect_identical(vals$frame$t, "error")
  expect_match(vals$frame$why, "is an R data.frame, which weft does not publish", fixed = TRUE)
  expect_true(startsWith(vals$frame$why, "{S}"))
  expect_identical(vals$len$t, "error")
  expect_match(vals$len$why, "is a units quantity; named values carry no units", fixed = TRUE)
  expect_identical(vals$fine$t, "int")
})

# ---- N43: later, unchanged, unbound -------------------------------------------

test_that("N43: a name bound after the prose that mentions it is published later, before the next prose", {
  res <- b6_knit(c(
    "First paragraph uses `late`{.num}.", "",
    chunk("b", "late <- 7"),
    "Second paragraph."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  first <- b6_line(res$text, "First paragraph")
  second <- b6_line(res$text, "Second paragraph")
  expect_true(first < b$open)
  expect_true(b$close < second)
  expect_identical(block_value(b, "late"), b6_e_float("7"))
})

test_that("N43: a name bound only in the last chunk, with no prose after, is published at the end of the document", {
  res <- b6_knit(c(
    "Uses `tail_name`{.num}.", "",
    "End of prose.", "",
    chunk("last", "tail_name <- 5", "weft::weft_put(extra = 1L)")
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  # waiting and auto names go into the same block (N43)
  expect_setequal(names(b$block$values), c("tail_name", "extra"))
  expect_true(b$open > b6_line(res$text, "End of prose."))
})

test_that("N43: a name is republished when its binding changes, and not when it does not", {
  res <- b6_knit(c(
    chunk("a", "depth <- 1", "other <- 10"),
    "P1 `depth`{.num} `other`{.num}.", "",
    chunk("b", "other <- 20"),
    "P2 `depth`{.num} `other`{.num}.", "",
    chunk("c", "depth <- 2"),
    "P3 text.", "",
    chunk("d", "other <- 20", "depth <- 2"),
    "P4 text."
  ))
  b6_expect_knitted(res)
  nm <- b6_block_names(res$blocks)
  expect_length(nm, 3L)
  expect_setequal(nm[[1]], c("depth", "other"))
  expect_identical(nm[[2]], "other")
  expect_identical(nm[[3]], "depth")
  expect_identical(block_value(res$blocks[[2]], "other"), b6_e_float("20"))
  expect_identical(block_value(res$blocks[[3]], "depth"), b6_e_float("2"))
  # order in the document: block, P1, block, P2, block, P3
  starts <- vapply(res$blocks, function(b) b$open, 0L)
  p <- c(b6_line(res$text, "P1"), b6_line(res$text, "P2"), b6_line(res$text, "P3"))
  expect_true(all(res$blocks[[1]]$close < p[1], p[1] < starts[2], res$blocks[[2]]$close < p[2],
                  p[2] < starts[3], res$blocks[[3]]$close < p[3]))
})

test_that("N43: a name with no binding in the knit environment publishes nothing and fails nothing", {
  res <- b6_knit(c(
    "Uses `nobody`{.num} and `pi`{.num} and `letters`{.val}.", "",
    "Another paragraph."
  ))
  b6_expect_knitted(res)
  # `pi` and `letters` are bound in base, not in the knit's environment: not found without inheritance
  expect_length(res$blocks, 0L)
  expect_identical(nrow(res$knit$failures), 0L)
})

test_that("N43/N45: the names are found over the whole source: governor values and an included file", {
  res <- b6_knit(
    c(chunk("calc", "k <- 3L", "cmp <- 12", "other <- 5", "incname <- 'in'", "unused <- 1"),
      "A [one | many]{n=\"k\"} and [a | b]{if=\"cmp > 10, 'x' != 'y', other >= 2\"}.", "",
      "{{< include inc.Rmd >}}", "",
      "After."),
    files = list("inc.Rmd" = "From the include: `incname`{.val}.")
  )
  b6_expect_knitted(res)
  published <- unlist(b6_block_names(res$blocks))
  expect_true(all(c("k", "cmp", "other", "incname") %in% published))
  expect_false("unused" %in% published)
})

test_that("N45: names inside a .weft-literal span are taken as any others, the knit does not fail, and the text stays", {
  res <- b6_knit(c(
    chunk("calc", "shown <- 2"),
    "Write [`shown`{.num}]{.weft-literal why=\"the syntax, not a value\"} to print it.", "",
    "::: {.weft-literal why=\"an example\"}", "`shown`{.num}", ":::", "",
    "After."
  ))
  b6_expect_knitted(res)
  expect_identical(nrow(res$knit$failures), 0L)
  expect_true(any(grepl("`shown`{.num}", res$text, fixed = TRUE)))
  # N45 reads the whole file text: the name is published (a name too many costs a few bytes)
  expect_true("shown" %in% unlist(b6_block_names(res$blocks)))
})

# ---- N42: weft_put() in a knit ------------------------------------------------------

test_that("N42: weft_put() in a chunk with include: false publishes, with `cell` the chunk's label, before the next prose", {
  res <- b6_knit(c(
    chunk("pub", "weft::weft_put(depth = 2.5)"),
    "Next prose."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  expect_identical(block_value(b, "depth"), b6_e_float("2.5"))
  expect_identical(b$block$cell, "pub")
  expect_true(b$close < b6_line(res$text, "Next prose."))
})

test_that("N40/N42: weft_put() returns invisible NULL in a knit", {
  res <- b6_knit(c(
    chunk("pub", "vv <- withVisible(weft::weft_put(a = 1L))",
          "stopifnot(is.null(vv$value), !vv$visible)"),
    "Next prose."
  ))
  b6_expect_knitted(res)
  expect_identical(b6_block_names(res$blocks), list("a"))
})

test_that("N43: a name weft_put() published in the block wins over the auto value", {
  res <- b6_knit(c(
    chunk("calc", "depth <- 1", "weft::weft_put(depth = 99)"),
    "Uses `depth`{.num}."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  expect_identical(block_value(res$blocks[[1]], "depth"), b6_e_float("99"))
})

test_that("N26/N42: a name put twice while waiting is one entry, the later value", {
  res <- b6_knit(c(
    chunk("one", "weft::weft_put(n = 1L)"),
    chunk("two", "weft::weft_put(n = 2L)"),
    "Prose."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  expect_identical(block_value(res$blocks[[1]], "n"), b6_e_int("2"))
})

test_that("N26: a name republished after a prose block is a new block with the new value", {
  res <- b6_knit(c(
    chunk("one", "weft::weft_put(n = 1L)"),
    "Prose one.", "",
    chunk("two", "weft::weft_put(n = 2L)"),
    "Prose two."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 2L)
  expect_identical(block_value(res$blocks[[1]], "n"), b6_e_int("1"))
  expect_identical(block_value(res$blocks[[2]], "n"), b6_e_int("2"))
  expect_true(res$blocks[[1]]$close < b6_line(res$text, "Prose one."))
  expect_true(b6_line(res$text, "Prose one.") < res$blocks[[2]]$open)
})

test_that("N42: in a results = asis chunk weft_put() writes the block at once, before the text the chunk prints", {
  res <- b6_knit(c(
    chunk("pub", "weft::weft_put(depth = 2.5)",
          "cat('The asis depth is `depth`{.num}.\\n')",
          opts = "results='asis', echo=FALSE"),
    "Later paragraph."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  b <- res$blocks[[1]]
  expect_identical(block_value(b, "depth"), b6_e_float("2.5"))
  expect_true(b$close < b6_line(res$text, "The asis depth is"))
  # control: it was not also left waiting: the later prose has no second block
  expect_true(b6_line(res$text, "Later paragraph.") > b$close)
})

test_that("N41/N42: a failing claim() put in a knit is recorded on the value and does not fail the knit", {
  res <- b6_knit(c(
    chunk("pub", "n <- 5", "weft::weft_put(n = claim(n, . > 10))"),
    "Uses `n`{.num}."
  ))
  b6_expect_knitted(res)
  expect_identical(nrow(res$knit$failures), 0L)
  expect_length(res$blocks, 1L)
  rec <- res$blocks[[1]]$block$values$n
  expect_length(rec$checks, 1L)
  expect_identical(rec$checks[[1]]$text, ". > 10")
  expect_identical(rec$checks[[1]]$ok, FALSE)
})

# ---- N130h: the end-of-document check, and R constructs in the same document ----------

test_that("N130h: the end-of-document check does not fail on named constructs, which wait for the filter", {
  res <- b6_knit(c(
    chunk("calc", "depth <- 3.14159", "sites <- c('a', 'b')"),
    "Named: `depth`{.num}, `sites`{.and}, `nobody`{digits=\"2\"}, `site`{.val}."
  ))
  b6_expect_knitted(res)
  expect_identical(nrow(res$knit$failures), 0L)
  expect_true(any(grepl("`depth`{.num}", res$text, fixed = TRUE)))
  expect_true(any(grepl("`sites`{.and}", res$text, fixed = TRUE)))
  expect_true(any(grepl("`nobody`{digits=\"2\"}", res$text, fixed = TRUE)))
})

test_that("N130h: R-expression constructs in the same document resolve as today, named ones stay", {
  res <- b6_knit(c(
    chunk("calc", "depth <- 3.14159"),
    "R says `r depth`{.num digits=\"2\"}, the name says `depth`{.num digits=\"2\"}."
  ))
  b6_expect_knitted(res)
  expect_true("R says 3.14, the name says `depth`{.num digits=\"2\"}." %in% res$text)
  expect_identical(nrow(res$knit$failures), 0L)
})

test_that("N130h: a failure of an R construct is still reported with named constructs present", {
  res <- b6_knit(c(
    chunk("calc", "depth <- 3.14159"),
    "Named `depth`{.num} and an R one `r 'text'`{.num}."
  ))
  expect_true(res$failed)
})

# ---- N48: run and time in a knit --------------------------------------------------------

test_that("N48: the block's run is .weft/run from the document's folder, else WEFT_RUN, else null", {
  src <- c(chunk("calc", "depth <- 1"), "Uses `depth`{.num}.")
  res <- b6_knit(src, files = list(".weft/run" = c("run-file-9", "second")),
                 env = c(WEFT_RUN = "run-env"))
  b6_expect_knitted(res)
  expect_identical(res$blocks[[1]]$block$run, "run-file-9")

  res <- b6_knit(src, env = c(WEFT_RUN = "run-env"))
  b6_expect_knitted(res)
  expect_identical(res$blocks[[1]]$block$run, "run-env")

  res <- b6_knit(src)
  b6_expect_knitted(res)
  expect_null(res$blocks[[1]]$block$run)
  expect_match(res$blocks[[1]]$text, "\"run\":null", fixed = TRUE)
})

test_that("N48: the run is read at each publish, so a change between two blocks shows", {
  res <- b6_knit(
    c(chunk("one", "weft::weft_put(a = 1L)"),
      "P1.", "",
      chunk("two", "writeLines('run-two', '.weft/run')", "weft::weft_put(b = 2L)"),
      "P2."),
    files = list(".weft/run" = "run-one")
  )
  b6_expect_knitted(res)
  expect_length(res$blocks, 2L)
  expect_identical(res$blocks[[1]]$block$run, "run-one")
  expect_identical(res$blocks[[2]]$block$run, "run-two")
})

test_that("N21/N48: `at` is whole seconds since 1970 at the time of the publish", {
  before <- as.numeric(Sys.time())
  res <- b6_knit(c(chunk("calc", "depth <- 1"), "Uses `depth`{.num}."))
  after <- as.numeric(Sys.time())
  b6_expect_knitted(res)
  at <- res$blocks[[1]]$block$at
  expect_true(is.numeric(at) && at == floor(at))
  expect_true(at >= floor(before) - 1 && at <= ceiling(after) + 1)
})

# ---- draft mode --------------------------------------------------------------------------

test_that("draft mode: the blocks are written as usual, and a failed claim in a chunk does not stop the knit", {
  src <- c(
    chunk("calc", "depth <- 3.14159", "claim(2, . > 10)"),
    "Uses `depth`{.num}."
  )
  res <- b6_knit(src, draft = TRUE)
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  expect_identical(block_value(res$blocks[[1]], "depth"), b6_e_float("3.14159"))
  # control: the same document without draft stops on the claim
  res2 <- b6_knit(src, draft = FALSE)
  expect_true(res2$failed)
})

# ---- no named value: today's output (the stop-line of 6b) -----------------------------------

test_that("N43: a document with no named value knits byte-identical to today's output, with no block", {
  # the expectation was taken from the knit before 6b: a bound name is not published
  # when the source does not name it, and plain code spans are not names
  res <- b6_knit(c(
    chunk("calc", "depth <- 3.14159"),
    "Depth was `r depth`{.num digits=\"2\"} m.", "",
    "A second paragraph, with `inline`.", "",
    "```{r shown}", "1 + 1", "```", "",
    "End."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 0L)
  got <- readLines(file.path(res$dir, "doc.md"), warn = FALSE)
  expect_identical(got, c("---", "title: \"t\"", "---", "", "", "", "", "",
                          "Depth was 3.14 m.", "",
                          "A second paragraph, with `inline`.", "", "",
                          "``` r", "1 + 1", "```", "", "```", "## [1] 2", "```", "", "End."))
})
