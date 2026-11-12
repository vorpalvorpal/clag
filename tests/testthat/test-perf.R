# The caches that make weft_setup() and the ledger's sentences cheap: each is keyed on its
# input, so a changed input is never answered from a stale entry.

test_that("the units database read is kept in the session and on disk, keyed on the database", {
  withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir())
  uc <- weft:::un_cache
  tb <- uc$tables
  tbk <- uc$tables_key
  withr::defer({ uc$tables <- tb; uc$tables_key <- tbk })
  uc$tables <- NULL
  a <- weft:::ud_tables()
  expect_true(is.data.frame(a$v) && is.data.frame(a$pf))
  expect_identical(weft:::ud_tables(), a)          # the session's copy
  key <- weft:::ud_tables_key()
  skip_if(is.null(key))
  f <- weft:::ud_tables_file(key)
  expect_true(file.exists(f))                      # and the disk copy
  uc$tables <- NULL
  expect_identical(weft:::ud_tables()$v, a$v)      # read back from disk
  # a damaged disk copy is a read of the XML
  writeLines("not an rds file", f)
  uc$tables <- NULL
  expect_identical(weft:::ud_tables()$v, a$v)
  # another database (a changed file) is another key, and another file
  key2 <- key
  key2$mtime <- key2$mtime + 1
  expect_false(identical(weft:::ud_tables_file(key2), f))
  testthat::local_mocked_bindings(ud_tables_key = function() key2, .package = "weft")
  expect_identical(weft:::ud_tables()$key, key2)
})

test_that("a paragraph's sentence cuts are kept, and a changed paragraph or language is not answered from them", {
  p1 <- "First sentence here. The mean was 4.5 mm today. Last one."
  at <- function(p, lang = "") {
    a <- regexpr("4.5", p, fixed = TRUE)[[1L]]
    weft:::sentence_cuts(p, c(a, a + 2L), lang)
  }
  c1 <- at(p1)
  expect_identical(at(p1), c1)
  p2 <- "Another opening. First sentence here. The mean was 4.5 mm today. Last one."
  c2 <- at(p2)
  expect_false(identical(c1$cuts, c2$cuts))
  expect_identical(c2$cuts, at(p2)$cuts)
  # the same paragraph under another language is its own entry
  at(p1, "fr")
  expect_true(exists(paste("fr", p1, sep = "\r\001"), envir = weft:::sentence_cache))
  # an inline footnote makes the window depend on the position: not kept
  p3 <- "Text ^[a note, with 4.5 in it. Two sentences.] and more."
  a3 <- regexpr("4.5", p3, fixed = TRUE)[[1L]]
  w_in <- weft:::sentence_cuts(p3, c(a3, a3 + 2L), "")$win
  w_out <- weft:::sentence_cuts(p3, c(1L, 2L), "")$win
  expect_false(identical(w_in, w_out))
})
