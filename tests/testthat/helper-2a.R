# Helpers for the 2a tests (the dictionary object). Contract: dev/design-2.md.

a2_fixture <- function() testthat::test_path("_dict", "dict.yml")
a2_fixture_lines <- function() readLines(a2_fixture(), warn = FALSE)

# write lines to a fresh temp .yml (removed when the calling test ends)
a2_file <- function(lines, env = parent.frame()) {
  p <- withr::local_tempfile(fileext = ".yml", .local_envir = env)
  writeLines(lines, p)
  p
}

# the error an expression raises, or NULL
a2_err <- function(expr) tryCatch({ expr; NULL }, error = function(e) e)

# a condition of the given class that also carries weft_error
expect_weft_cond <- function(e, class, label = NULL) {
  testthat::expect_false(is.null(e), label = paste(label, "raised an error"))
  testthat::expect_true(inherits(e, class), label = paste(label, "has class", class))
  testthat::expect_true(inherits(e, "weft_error"), label = paste(label, "has class weft_error"))
}

# a quantity: a `units` value equal to `num` in `unit` (so it must convert)
expect_qty <- function(x, num, unit) {
  testthat::expect_s3_class(x, "units")
  testthat::expect_equal(
    as.numeric(units::set_units(x, unit, mode = "standard")), num)
}

# `fixed` pieces all occur in the text
expect_has <- function(txt, ...) {
  for (p in c(...)) testthat::expect_true(grepl(p, txt, fixed = TRUE),
                                          label = sprintf("text holds `%s`", p))
}

# the printed text of a weft_text (or a character) as one plain string
b_txt_2a <- function(x) as.character(unclass(x))[1]
