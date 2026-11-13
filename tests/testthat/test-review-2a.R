# Regression tests for the review of package 2a (dev/review-2a.md) and the rulings on it
# (dev/design-2.md, "Rulings on the review of 2a"). Helpers: helper-2a.R, helper-render.R and
# the kn()/all_text() helpers of test-dict-knit.R (redefined here so that this file stands alone).
# Names: `review 2a #<finding or ruling letter>: <what must hold> (<rule or ruling>)`.
# Unit names used here are letters only and unique to one test: units stay registered for the session.

r2a_fx <- function() read_dict(a2_fixture())

# the warnings an expression raises (errors are swallowed)
r2a_warns <- function(expr) {
  w <- character()
  withCallingHandlers(
    tryCatch(expr, error = function(e) NULL),
    warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
  w
}

# the message of the weft_dict_error a read raises (fails the test if it raises none)
r2a_msg <- function(lines, env = parent.frame()) {
  p <- a2_file(lines, env = env)
  e <- a2_err(read_dict(p))
  expect_weft_cond(e, "weft_dict_error", "read")
  list(path = p, msg = if (is.null(e)) "" else conditionMessage(e))
}

# a one-document project render in this process
r2a_kn <- function(lines, front = NULL, files = list(), ...) {
  if (is.null(files[["dict.yml"]])) files[["dict.yml"]] <- a2_fixture_lines()
  render_rmd(lines, front = front, files = files, in_process = TRUE, ...)
}

# render a document in this process into a given environment, so that two renders share one
# knit_global() the way two knits in one R session do
r2a_render_shared <- function(lines, env, front = NULL, files = list(), env_local = parent.frame()) {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  d <- write_doc(lines, TRUE, NULL, front, files, "doc", "rmd")
  old <- setwd(d$dir)
  on.exit({ setwd(old); weft_restore_knitr() }, add = TRUE)
  err <- tryCatch({
    f <- rmarkdown::md_document(variant = "markdown", pandoc_args = "--wrap=none")
    f$knitr$opts_chunk$echo <- FALSE
    f$knitr$opts_chunk$comment <- ""
    rmarkdown::render(d$input, f, output_file = "doc.md", quiet = TRUE, envir = env)
    NULL
  }, error = function(e) e)
  out <- file.path(d$dir, "doc.md")
  list(error = err, message = if (is.null(err)) "" else conditionMessage(err),
       text = tidy_output(out),
       knit = tryCatch(weft:::last_knit(), error = function(e) NULL))
}

# ---- 1, a: objects removed at the next knit ------------------------------------------------------------

R1_LOCAL <- c("weft:", "  dict_local:",
              "    sites: {value: 7, type: number, definition: d, why: w}")

test_that("review 2a #1: a knit with neither dict.yml nor dict_local does not see the previous knit's dict and dict_local (2.1.5, D14; ruling 1, a)", {
  shared <- new.env()
  a <- r2a_render_shared(c("A `r dict$min_samples` `r dict_local$sites`"), shared,
                         front = R1_LOCAL, files = list("dict.yml" = a2_fixture_lines()))
  expect_null(a$error)
  expect_match(paste(a$text, collapse = " "), "A 5 7", fixed = TRUE)            # control: knit A sees both
  b <- r2a_render_shared(c("B dict `r exists('dict')`; local `r exists('dict_local')`."), shared)
  expect_null(b$error)
  expect_match(paste(b$text, collapse = " "), "B dict FALSE; local FALSE.", fixed = TRUE)
  expect_false(exists("dict", envir = shared, inherits = FALSE))
  expect_false(exists("dict_local", envir = shared, inherits = FALSE))
})

test_that("review 2a #1: reading dict in a knit with no dictionary stops with `object 'dict' not found` (2.1.5; ruling 1)", {
  shared <- new.env()
  a <- r2a_render_shared(c("A `r dict$min_samples`"), shared,
                         files = list("dict.yml" = a2_fixture_lines()))
  expect_null(a$error)
  b <- r2a_render_shared(c("B reads dict: `r dict$min_samples`"), shared)
  expect_false(is.null(b$error), label = "knit B stops")
  expect_match(b$message, "object 'dict' not found", fixed = TRUE)
})

test_that("review 2a #1 control: a knit with dict.yml but no dict_local gets an empty dict_local, not the previous knit's (D14)", {
  shared <- new.env()
  a <- r2a_render_shared(c("A `r dict_local$sites`"), shared, front = R1_LOCAL,
                         files = list("dict.yml" = a2_fixture_lines()))
  expect_null(a$error)
  b <- r2a_render_shared(c("B local `r length(dict_local)` dict `r length(dict)`."), shared,
                         files = list("dict.yml" = a2_fixture_lines()))
  expect_null(b$error)
  expect_match(paste(b$text, collapse = " "), "B local 0 dict 12.", fixed = TRUE)
})

# ---- 2, c: the weft_year class -------------------------------------------------------------------------

r2a_year <- function() r2a_fx()$method_change

test_that("review 2a #2: a year is a weft_year with an integer underneath; as.integer(), as.numeric(), format() and print() show the bare integer (ruling 2, c)", {
  y <- r2a_year()
  expect_s3_class(y, "weft_year")
  expect_type(y, "integer")
  expect_identical(as.integer(y), 2014L)
  expect_identical(as.numeric(y), 2014)
  expect_false(inherits(as.integer(y), "weft_year"))
  expect_identical(format(y), "2014")
  expect_identical(capture.output(print(y)), "[1] 2014")
  expect_identical(capture.output(print(c(y, y + 1L))), "[1] 2014 2015")
})

test_that("review 2a #2: c(), [, [[, rev(), sort(), unique(), min(), max(), range() and seq() keep the year (ruling 2, c)", {
  y <- r2a_year()
  v <- c(y, y + 10L, y + 3L)
  expect_s3_class(v, "weft_year")
  expect_identical(as.integer(v), c(2014L, 2024L, 2017L))
  expect_s3_class(c(y, 2015L), "weft_year")                                  # a year with a plain integer
  expect_s3_class(v[2], "weft_year")
  expect_s3_class(v[[3]], "weft_year")
  expect_identical(as.integer(v[[3]]), 2017L)
  expect_s3_class(rev(v), "weft_year")
  expect_identical(as.integer(rev(v)), c(2017L, 2024L, 2014L))
  expect_s3_class(sort(v), "weft_year")
  expect_identical(as.integer(sort(v)), c(2014L, 2017L, 2024L))
  u1 <- unique(c(y, y, y + 1L))
  expect_s3_class(u1, "weft_year")
  expect_identical(as.integer(u1), c(2014L, 2015L))
  expect_s3_class(min(v), "weft_year")
  expect_identical(as.integer(min(v)), 2014L)
  expect_s3_class(max(v), "weft_year")
  expect_identical(as.integer(max(v)), 2024L)
  expect_s3_class(max(y, 2020L), "weft_year")
  expect_identical(as.integer(max(y, 2020L)), 2020L)
  r <- range(y, y + 10L)
  expect_s3_class(r, "weft_year")
  expect_identical(as.integer(r), c(2014L, 2024L))
  s <- seq(y, y + 3L)
  expect_s3_class(s, "weft_year")
  expect_identical(as.integer(s), 2014:2017)
})

test_that("review 2a #2: year + n and year - n are years, including a vector n; year - year and any other arithmetic is a plain number (ruling 2, c)", {
  y <- r2a_year()
  for (z in list(y + 1L, y + 1, y - 1L, y - 1, y + 0:2)) expect_s3_class(z, "weft_year")
  expect_identical(as.integer(y + 0:2), 2014:2016)
  expect_identical(as.integer(y - 4L), 2010L)
  expect_false(inherits(y - y, "weft_year"))
  expect_identical(as.numeric(y - y), 0)
  expect_false(inherits(y - (y + 10L), "weft_year"))
  expect_identical(as.numeric((y + 10L) - y), 10)
  expect_false(inherits(y * 1000, "weft_year"))
  expect_identical(as.numeric(y * 1000), 2014000)
  expect_false(inherits(2024L - y, "weft_year"))
  expect_identical(as.numeric(2024L - y), 10)
  expect_false(inherits(y / 2, "weft_year"))
})

test_that("review 2a #2: comparisons on a year work as on integers (ruling 2, c)", {
  y <- r2a_year()
  expect_true(y < 2020)
  expect_true(y == 2014L)
  expect_true(y + 1L > y)
  expect_identical(c(y, y + 5L) >= 2019L, c(FALSE, TRUE))
  expect_false(is.object(y == 2014L))
})

test_that("review 2a #2: with vctrs loaded, year with integer or double gives a plain integer or double, year with year gives a year (ruling 2, c)", {
  skip_if_not_installed("vctrs")
  y <- r2a_year()
  expect_identical(vctrs::vec_ptype2(y, 1L), integer())
  expect_identical(vctrs::vec_ptype2(1L, y), integer())
  expect_identical(vctrs::vec_ptype2(y, 1.5), double())
  expect_identical(vctrs::vec_ptype2(1.5, y), double())
  expect_s3_class(vctrs::vec_ptype2(y, y), "weft_year")
  expect_s3_class(vctrs::vec_c(y, y + 1L), "weft_year")
  expect_identical(as.integer(vctrs::vec_c(y, y + 1L)), c(2014L, 2015L))
  v <- vctrs::vec_c(y, 5L)
  expect_false(inherits(v, "weft_year"))
  expect_identical(v, c(2014L, 5L))
  expect_identical(vctrs::vec_cast(y, integer()), 2014L)
  expect_identical(vctrs::vec_cast(y, double()), 2014)
})

test_that("review 2a #2: no thousands mark on a year under .num, .ord, .and and .range, through c(), range(), max() and arithmetic (4.2.1; ruling 2, c)", {
  y <- r2a_year()
  expect_identical(b_txt_2a(fmt_ord(y)), "2014th")
  expect_identical(b_txt_2a(fmt_and(y + 0:2)), "2014, 2015 and 2016")
  expect_identical(b_txt_2a(fmt_num(max(y, 2020L))), "2020")
  expect_identical(b_txt_2a(fmt_num(y + 1L)), "2015")
  expect_identical(b_txt_2a(fmt_range(range(y, y + 10L))), "2014–2024")
  expect_identical(b_txt_2a(fmt_range(c(y, y + 10L))), "2014–2024")
  expect_identical(as.character(unclass(fmt_num(c(y, 2015L)))), c("2014", "2015"))
  # control: a plain number of the same size keeps the mark
  expect_identical(b_txt_2a(fmt_num(2014 * 10)), "20,140")
})

test_that("review 2a #2: in a knit the inline classes print the years with no thousands mark (4.2.1; ruling 2, c)", {
  res <- r2a_kn(c(
    "R `r c(dict$method_change, dict$method_change + 10L)`{.range} end.",
    "",
    "O `r dict$method_change`{.ord} end.",
    "",
    "A `r dict$method_change + 0:2`{.and} end.",
    "",
    "N `r max(dict$method_change, 2020L)`{.num} end."))
  expect_false(res$failed, label = res$message)
  txt <- paste(res$text, collapse = "\n")
  expect_match(txt, "R 2014--2024 end.", fixed = TRUE)
  expect_match(txt, "O 2014th end.", fixed = TRUE)
  expect_match(txt, "A 2014, 2015 and 2016 end.", fixed = TRUE)
  expect_match(txt, "N 2020 end.", fixed = TRUE)
})

# ---- 3, j: leading-zero, hex and octal numbers are problems --------------------------------------------

R3_NUM <- c("010", "012", "-012", "0x1F", "0o17", "08")
R3_YEAR <- c("03736", "0x7DE", "0o3736")

for (lit in R3_NUM) for (type in c("number", "quantity")) local({
  lit <- lit; type <- type
  test_that(sprintf("review 2a #3: `value: %s` under %s is a problem that says to write it in decimal, never read as octal or hex (ruling 3, j)", lit, type), {
    unit <- if (type == "quantity") ", unit: m" else ""
    r <- r2a_msg(sprintf("a: {value: %s, type: %s%s, definition: d}", lit, type, unit))
    expect_match(r$msg, sprintf("%s:1: `a`", r$path), fixed = TRUE)
    expect_match(r$msg, "decimal", fixed = TRUE)
  })
})

for (lit in R3_YEAR) local({
  lit <- lit
  test_that(sprintf("review 2a #3: `value: %s` under year is a problem that says to write it in decimal (ruling 3, j)", lit), {
    r <- r2a_msg(sprintf("a: {value: %s, type: year, definition: d}", lit))
    expect_match(r$msg, sprintf("%s:1: `a`", r$path), fixed = TRUE)
    expect_match(r$msg, "decimal", fixed = TRUE)
  })
})

for (b in c("below: 010", "at_most: 0x10", "below: 0o10", "below: 08")) local({
  b <- b
  test_that(sprintf("review 2a #3: a bound `%s` is a problem that says to write it in decimal (ruling 3, j)", b), {
    r <- r2a_msg(c("a:", "  value:", sprintf("    - {%s, phrase: x}", b), "    - {phrase: z}",
                   "  type: breaks", "  definition: d"))
    expect_match(r$msg, sprintf("%s:1: `a`", r$path), fixed = TRUE)
    expect_match(r$msg, "decimal", fixed = TRUE)
  })
})

test_that("review 2a #3 control: plain decimal numbers, 0, 0.5, -0.5 and 10 read as written (4.2.1)", {
  d <- read_dict(a2_file(c("a: {value: 10, type: number, definition: d}",
                           "b: {value: 0, type: number, definition: d}",
                           "c: {value: 0.5, type: number, definition: d}",
                           "e: {value: -0.5, type: number, definition: d}",
                           "f: {value: \"12.5\", type: number, definition: d}")))
  expect_equal(unlist(as.list(d)), c(a = 10, b = 0, c = 0.5, e = -0.5, f = 12.5))
})

# ---- 4: merge key ---------------------------------------------------------------------------------------

test_that("review 2a #4: a merge key (<<) is a problem, not a silent override of the entry's own fields (ruling 4)", {
  lines <- c("base: &b {value: 1, type: number, definition: Shared text.}",
             "c:",
             "  <<: *b",
             "  definition: Own text.")
  r <- r2a_msg(lines)
  expect_match(r$msg, "merge keys are not read", fixed = TRUE)
  r2 <- r2a_msg(c("base: &b {value: 1, type: number, definition: Shared text.}",
                  "c:", "  <<: *b", "  value: 2"))
  expect_match(r2$msg, "merge keys are not read", fixed = TRUE)
})

test_that("review 2a #4 control: an anchor and an alias without a merge key are allowed (ruling 4)", {
  d <- read_dict(a2_file(c("base: &b {value: 1, type: number, definition: Shared text.}",
                           "copy: *b")))
  expect_identical(names(d), c("base", "copy"))
  expect_equal(d$copy, 1)
})

# ---- 5: several documents -------------------------------------------------------------------------------

test_that("review 2a #5: a file with a second YAML document is a problem, not read up to the `---` (2a: nothing is half-read; ruling 5)", {
  r <- r2a_msg(c("a: {value: 1, type: number, definition: d}", "---",
                 "b: {value: 2, type: number, definition: d}"))
  expect_match(r$msg, "document", ignore.case = TRUE)
  r2 <- r2a_msg(c("---", "a: {value: 1, type: number, definition: d}", "---",
                  "b: {value: 2, type: number, definition: d}"))
  expect_match(r2$msg, "document", ignore.case = TRUE)
})

test_that("review 2a #5 control: one document with a leading `---` reads (ruling 5)", {
  d <- read_dict(a2_file(c("---", "a: {value: 1, type: number, definition: d}")))
  expect_identical(names(d), "a")
})

# ---- 6, 7, e: registered ---------------------------------------------------------------------------------

test_that("review 2a #6: a read that fails installs no unit, and the next good read lists it in `registered` and print() (D16; ruling 6, e)", {
  bad <- a2_file(c("a: {value: 1, type: quantity, unit: rvquxa, definition: d}",
                   "b: {value: oops, type: number, definition: d}"))
  expect_error(units::as_units("rvquxa"), regexp = "rvquxa")                                   # control: unknown before
  expect_weft_cond(a2_err(read_dict(bad)), "weft_dict_error", "failed read")
  expect_error(units::as_units("rvquxa"), regexp = "rvquxa")                                   # still unknown: nothing installed
  good <- a2_file("a: {value: 1, type: quantity, unit: rvquxa, definition: d}")
  d <- read_dict(good)
  expect_identical(attr(d, "registered"), "rvquxa")
  expect_match(paste(capture.output(print(d)), collapse = "\n"), "Units registered: rvquxa", fixed = TRUE)
})

test_that("review 2a #7: two reads of an unchanged file give the same `registered` and print() shows the units line on both (D3, D16; ruling 7, e)", {
  p <- a2_file(c("a: {value: 1, type: quantity, unit: rvquxb, definition: d}",
                 "b: {value: 2, type: number, definition: d}"))
  d1 <- read_dict(p)
  d2 <- read_dict(p)
  d3 <- read_dict(p)
  expect_identical(attr(d1, "registered"), "rvquxb")
  expect_identical(attr(d2, "registered"), "rvquxb")
  expect_identical(attr(d3, "registered"), "rvquxb")
  expect_identical(d1, d2)                                                   # a file with no closures
  expect_identical(d2, d3)
  for (d in list(d1, d2, d3))
    expect_match(paste(capture.output(print(d)), collapse = "\n"), "Units registered: rvquxb", fixed = TRUE)
})

test_that("review 2a #7: two reads of the fixture differ in nothing but the closures' environments (D3; ruling 7)", {
  d1 <- r2a_fx(); d2 <- r2a_fx()
  expect_identical(attr(d1, "registered"), attr(d2, "registered"))
  expect_true(isTRUE(all.equal(d1, d2)))
  expect_true(identical(d1, d2, ignore.environment = TRUE))
})

test_that("review 2a #e: `registered` is the units the dictionary needs that udunits lacks, however they came to be installed (ruling e)", {
  units::install_unit("rvquxc")                                              # installed by someone else
  p <- a2_file("a: {value: 1, type: quantity, unit: rvquxc, definition: d}")
  d <- read_dict(p)
  expect_identical(attr(d, "registered"), "rvquxc")
  expect_identical(attr(read_dict(p), "registered"), "rvquxc")
})

test_that("review 2a #e: `registered` of a later read in a long session equals that of the first read in a fresh R process (D16; ruling e)", {
  p <- a2_file(c("a: {value: 1, type: quantity, unit: rvquxd, definition: d}"))
  read_dict(p)
  later <- attr(read_dict(p), "registered")
  lib <- weft_test_lib()
  out <- system2(file.path(R.home("bin"), "Rscript"),
                 c("--no-save", "--no-restore", "-e",
                   shQuote(paste0("a <- commandArgs(TRUE); if (nzchar(a[1])) .libPaths(c(a[1], .libPaths()));",
                                  "d <- weft::read_dict(a[2]);",
                                  "cat('REG:', paste(attr(d, 'registered'), collapse = ','), '\\n');",
                                  "cat('PRINT:', any(grepl('Units registered', capture.output(print(d)))), '\\n')")),
                   shQuote(lib), shQuote(p)),
                 stdout = TRUE, stderr = TRUE)
  expect_true(any(grepl("^REG: rvquxd", out)), label = paste(out, collapse = " | "))
  expect_identical(later, "rvquxd")
  expect_true(any(grepl("^PRINT: TRUE", out)))
})

# ---- 8: str(), summary(), Map(), mapply() ----------------------------------------------------------------

test_that("review 2a #8: str(), summary(), lapply(), Map() and mapply() over a dictionary work and give what they give for the plain list (ruling 8)", {
  d <- r2a_fx()
  pl <- as.list(d)
  expect_no_error(out <- capture.output(str(d)))
  expect_true(any(grepl("min_samples", out, fixed = TRUE)))
  expect_no_error(sm <- summary(d))
  expect_equal(sm, summary(pl))
  f <- function(v, n) paste(n, class(v)[1])
  expect_no_error(m <- Map(f, d, names(d)))
  expect_equal(m, Map(f, pl, names(pl)))
  expect_no_error(mm <- mapply(f, d, names(d)))
  expect_equal(mm, mapply(f, pl, names(pl)))
  expect_equal(lapply(d, class), lapply(pl, class))                          # control (worked before)
})

# ---- 9: whole numbers beyond the integer range ----------------------------------------------------------

test_that("review 2a #9: a whole number beyond the integer range is a number (a double) and no R warning leaks (ruling 9)", {
  p <- a2_file(c("a: {value: 3000000000, type: number, definition: d}",
                 "b: {value: 3000000000, type: quantity, unit: m, definition: d}",
                 "c: {value: -3000000000, type: number, definition: d}"))
  w <- r2a_warns(d <- read_dict(p))
  expect_identical(w, character())
  expect_s3_class(d, "weft_dict")
  expect_type(d$a, "double")
  expect_equal(d$a, 3e9)
  expect_qty(d$b, 3e9, "m")
  expect_equal(d$c, -3e9)
})

test_that("review 2a #9: beyond the integer range under year is still a problem, with no R warning (ruling 9)", {
  p <- a2_file("a: {value: 3000000000, type: year, definition: d}")
  expect_identical(r2a_warns(read_dict(p)), character())
  expect_weft_cond(a2_err(read_dict(p)), "weft_dict_error", "big year")
})

test_that("review 2a #9 control: 3e9 and \"3000000000\" read as numbers", {
  d <- read_dict(a2_file(c("a: {value: 3e9, type: number, definition: d}",
                           "b: {value: \"3000000000\", type: number, definition: d}")))
  expect_equal(d$a, 3e9)
  expect_equal(d$b, 3e9)
})

# ---- 10: dict_local booleans in front matter -------------------------------------------------------------

test_that("review 2a #10 control: a labels map keyed yes and no in dict_local front matter reads with both as text (D6)", {
  res <- r2a_kn(c("Body."), front = c(
    "weft:", "  dict_local:",
    "    a: {value: {yes: Y, no: N}, type: labels, definition: d, why: w}"))
  expect_false(res$failed, label = res$message)
  expect_identical(as.character(res$knit$dict_local$a("yes")), "Y")
  expect_identical(as.character(res$knit$dict_local$a("no")), "N")
})

# ---- 11: duplicate key inside an entry ------------------------------------------------------------------

R11_FIRST <- c("a:", "  value: 1", "  type: number", "  definition: d", "  decision: 31")

test_that("review 2a #11: a duplicate field inside an entry is reported at the second line, under the entry's key (2a: line of the key's own line)", {
  r <- r2a_msg(c(R11_FIRST, "b:", "  value: 2", "  type: number", "  definition: d", "  definition: again"))
  expect_match(r$msg, sprintf("%s:10: `b`: `definition` is written twice", r$path), fixed = TRUE)
})

test_that("review 2a #11: a doubled `value:` in the second entry is reported at the second `value:` line (2a)", {
  r <- r2a_msg(c(R11_FIRST, "b:", "  value: 2", "  type: number", "  value: 3", "  definition: d"))
  expect_match(r$msg, sprintf("%s:9: `b`: `value` is written twice", r$path), fixed = TRUE)
})

# ---- 12: a problem's line must be at the top level's indentation ----------------------------------------

test_that("review 2a #12: a problem in a top-level key named like a nested key of an earlier entry is reported at the top-level line (2a)", {
  r <- r2a_msg(c("zone_lab:", "  value:", "    upper: Upper reach", "  type: labels",
                 "  definition: d", "",
                 "upper: {value: x, type: number, definition: d}"))
  expect_match(r$msg, sprintf("%s:7: `upper`", r$path), fixed = TRUE)
  expect_false(grepl(sprintf("%s:3:", r$path), r$msg, fixed = TRUE))
})

test_that("review 2a #12: a top-level key named like a field (`type`) gets its own line, not the first entry's field line (2a)", {
  r <- r2a_msg(c("a:", "  value: 1", "  type: number", "  definition: d",
                 "type: {value: x, type: number, definition: d}"))
  expect_match(r$msg, sprintf("%s:5: `type`", r$path), fixed = TRUE)
  expect_false(grepl(sprintf("%s:3:", r$path), r$msg, fixed = TRUE))
})

for (fld in c("value", "unit", "definition", "decision")) local({
  fld <- fld
  test_that(sprintf("review 2a #12: a top-level key `%s` that has a problem is reported at its own line, not at the first entry's `%s:` line (2a)", fld, fld), {
    r <- r2a_msg(c("a:", "  value: 1", "  type: quantity", "  unit: m", "  definition: d", "  decision: 31",
                   sprintf("%s: {value: x, type: number, definition: d}", fld)))
    expect_match(r$msg, sprintf("%s:7: `%s`", r$path, fld), fixed = TRUE)
    expect_false(grepl(sprintf("%s:[1-6]:", r$path), r$msg))
  })
})

# ---- 13: a duplicate top-level key does not hide other problems ----------------------------------------

test_that("review 2a #13: a duplicate top-level key is one problem among the others (D5; ruling 13)", {
  r <- r2a_msg(c("a: {value: 1, type: number, definition: d}",
                 "b: {value: x, type: number, definition: d}",
                 "a: {value: 2, type: number, definition: d}"))
  expect_true(startsWith(r$msg, sprintf("weft: %s: 2 problem(s) in the dictionary", r$path)))
  expect_match(r$msg, sprintf("%s:2: `b`", r$path), fixed = TRUE)
  expect_match(r$msg, sprintf("%s:3: `a`", r$path), fixed = TRUE)
  expect_match(r$msg, "written twice", fixed = TRUE)
})

# ---- 14: the 4.4.5 hint on a warned check -----------------------------------------------------------------

R14_HINT <- "state the check's unit, as in . < u(0.45, ug) (rule 4.4.5)"

test_that("review 2a #14: a warned check outside a knit carries the 4.4.5 hint (4.4.5; 2a Arithmetic and checks)", {
  d <- r2a_fx()
  w <- NULL
  withCallingHandlers(claim(d$core_len, . < 1, level = "warn"),
                      warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
  expect_false(is.null(w), label = "a warning was raised")
  expect_match(paste(w, collapse = "\n"), R14_HINT, fixed = TRUE)
})

test_that("review 2a #14: in a knit a warned check carries the hint in last_knit()$warnings and in the warned-checks report (4.4.5)", {
  res <- r2a_kn(c("Prose `r claim(dict$core_len, . < 1, level = 'warn')`{.num}.", "",
                  "```{r}", "claim(dict$core_len, . < 1, level = 'warn')", "```"))
  expect_false(res$failed, label = res$message)
  w <- res$knit$warnings
  expect_equal(NROW(w), 2L)
  expect_false(anyNA(w$hint))
  expect_true(all(grepl(R14_HINT, w$hint, fixed = TRUE)))
  expect_match(paste(res$log, collapse = "\n"), R14_HINT, fixed = TRUE)
})

test_that("review 2a #14 control: a failed check (level = fail) carries the hint outside a knit", {
  e <- a2_err(claim(r2a_fx()$core_len, . < 1))
  txt <- paste(c(conditionMessage(e), unlist(lapply(unclass(e), function(x) if (is.character(x)) x))),
               collapse = "\n")
  expect_match(txt, R14_HINT, fixed = TRUE)
})

# ---- 16: the value of a failed claim on a quantity ---------------------------------------------------------

test_that("review 2a #16: a failed claim on a quantity shows its value as `0.5 [m]` or `0.5 m`, not a truncated deparse() (2a Arithmetic and checks)", {
  e <- a2_err(claim(r2a_fx()$core_len, . < 1))
  expect_weft_cond(e, "weft_claim_failed", "bare number")
  txt <- paste(c(conditionMessage(e), unlist(lapply(unclass(e), function(x) if (is.character(x)) x))),
               collapse = "\n")
  expect_false(grepl("structure(", txt, fixed = TRUE))
  expect_match(txt, "0.5 \\[m\\]|0\\.5 m")
})

# ---- 17: raw R warnings -----------------------------------------------------------------------------------

test_that("review 2a #17: a unit that does not parse is a problem with no stray R warning from read_dict() (4.4.7)", {
  p <- a2_file("a: {value: 1, type: quantity, unit: \"m/(s\", definition: d}")
  expect_identical(r2a_warns(read_dict(p)), character())
  expect_weft_cond(a2_err(read_dict(p)), "weft_dict_error", "bad unit")
})

test_that("review 2a #17: u() with an unparseable unit raises no stray R warning (4.4.6)", {
  expect_identical(r2a_warns(u(5, "m/(s")), character())
  expect_s3_class(a2_err(u(5, "m/(s")), "weft_error")
})

test_that("review 2a #17: a key `~` and a labels key `~` raise no stray R warning (4.2.1)", {
  expect_identical(r2a_warns(read_dict(a2_file("~: {value: 1, type: number, definition: d}"))), character())
  expect_identical(r2a_warns(read_dict(a2_file(
    "a: {value: {~: x}, type: labels, definition: d}"))), character())
})

# ---- 18: a key that YAML types ----------------------------------------------------------------------------

for (k in c("null", "~", "010")) local({
  k <- k
  test_that(sprintf("review 2a #18: the key `%s` is named as written, with its line (2a)", k), {
    r <- r2a_msg(c("a: {value: 1, type: number, definition: d}",
                   sprintf("%s: {value: 1, type: number, definition: d}", k)))
    expect_match(r$msg, sprintf("%s:2: `%s`", r$path, k), fixed = TRUE)
  })
})

# ---- 19: reserved names as keys ---------------------------------------------------------------------------

for (k in c("..1", "...", "..2")) local({
  k <- k
  test_that(sprintf("review 2a #19: the key `%s` is refused as a reserved name (2a keys; ruling 19)", k), {
    r <- r2a_msg(c("a: {value: 1, type: number, definition: d}",
                   sprintf("\"%s\": {value: 1, type: number, definition: d}", k)))
    expect_match(r$msg, sprintf("%s:2: `%s`", r$path, k), fixed = TRUE)
  })
})

test_that("review 2a #19 control: an ordinary key with dots and digits reads (2a keys)", {
  d <- read_dict(a2_file("a.b_1: {value: 1, type: number, definition: d}"))
  expect_identical(names(d), "a.b_1")
})

# ---- 21: print() -------------------------------------------------------------------------------------------

test_that("review 2a #21: print() of a one-key dictionary says `1 key`, not `1 keys` (2a print)", {
  d <- read_dict(a2_file("a: {value: 1, type: number, definition: d}"))
  out <- capture.output(print(d))
  expect_match(out[1], "1 key$")
  expect_false(grepl("1 keys", out[1], fixed = TRUE))
})

test_that("review 2a #21: print() shows a 300-character string value as a short value, not in full (2a print)", {
  long <- strrep("x", 300)
  d <- read_dict(a2_file(sprintf("a: {value: %s, type: string, definition: d}", long)))
  out <- capture.output(print(d))
  expect_false(any(grepl(long, out, fixed = TRUE)))
  expect_lt(max(nchar(out)), 150)
  expect_true(any(grepl("a", out[-1])))
})

# ---- 22: u() with no value --------------------------------------------------------------------------------

test_that("review 2a #22: u(unit = m) with no value is a weft_unit_error, not a plain R error (4.4.6)", {
  e <- a2_err(u(unit = m))
  expect_weft_cond(e, "weft_unit_error", "missing value")
  expect_false(inherits(e, "simpleError"))
})

# ---- b: a child with its own dict_local -------------------------------------------------------------------

R_CHILD <- c("---", "weft:", "  dict_local:",
             "    cl: {value: 7, type: number, definition: d, why: w}", "---", "",
             "Child reads `r dict_local$cl`.")

test_that("review 2a #b: a child document with its own `weft: dict_local:` is a weft_dict_error naming the child (4.3.1; ruling b)", {
  res <- render_rmd(c("```{r, child='child.Rmd'}", "```"), in_process = TRUE,
                    files = list("dict.yml" = a2_fixture_lines(), "child.Rmd" = R_CHILD))
  expect_true(res$failed)
  expect_true("weft_dict_error" %in% res$error$class, label = paste(res$error$class, collapse = ", "))
  expect_match(res$message, "child.Rmd", fixed = TRUE)
})

test_that("review 2a #b control: a child with no dict_local of its own sees the parent's dict_local (4.3.1)", {
  res <- render_rmd(c("```{r, child='child.Rmd'}", "```"), in_process = TRUE,
                    front = c("weft:", "  dict_local:",
                              "    cl: {value: 7, type: number, definition: d, why: w}"),
                    files = list("dict.yml" = a2_fixture_lines(),
                                 "child.Rmd" = c("Child reads `r dict_local$cl`.")))
  expect_false(res$failed, label = res$message)
  expect_match(paste(res$text, collapse = " "), "Child reads 7.", fixed = TRUE)
})

# ---- d: unreachable bands; a bound as a numeric string -----------------------------------------------------

r2a_bands <- function(...) c("a:", "  value:", paste0("    - {", c(...), ", phrase: p}"),
                             "    - {phrase: z}", "  type: breaks", "  definition: d")

R_D_BAD <- list(
  "an at_most followed by a below of the same number" = c("at_most: 1", "below: 1"),
  "equal below bounds"                                = c("below: 1", "below: 1"),
  "equal at_most bounds"                              = c("at_most: 1", "at_most: 1")
)
for (nm in names(R_D_BAD)) local({
  nm <- nm; items <- R_D_BAD[[nm]]
  test_that(sprintf("review 2a #d: %s leave a band that can never be chosen and are a problem (ruling d)", nm), {
    r <- r2a_msg(r2a_bands(items))
    expect_match(r$msg, "`a`", fixed = TRUE)
  })
})

R_D_OK <- list(
  "a below followed by an at_most of the same number" = c("below: 1", "at_most: 1"),
  "an at_most followed by a larger below"             = c("at_most: 1", "below: 2"),
  "increasing below bounds"                           = c("below: 1", "below: 2")
)
for (nm in names(R_D_OK)) local({
  nm <- nm; items <- R_D_OK[[nm]]
  test_that(sprintf("review 2a #d control: %s is reachable and reads (ruling d)", nm), {
    expect_s3_class(read_dict(a2_file(r2a_bands(items))), "weft_dict")
  })
})

test_that("review 2a #d: a bound written as a number in a string is accepted, as `number` accepts one, and picks the same band (D7; ruling d)", {
  d <- read_dict(a2_file(c("a:", "  value:", "    - {below: \"1\", phrase: lo}",
                           "    - {at_most: \"2.5\", phrase: mid}", "    - {phrase: hi}",
                           "  type: breaks", "  definition: d")))
  expect_identical(as.character(d$a(c(0.5, 1, 2.5, 3))), c("lo", "mid", "mid", "hi"))
})

# ---- g: names<- --------------------------------------------------------------------------------------------

test_that("review 2a #g: names<- on a dictionary is a weft_dict_error and leaves it unchanged (4.1.4; ruling g)", {
  d <- r2a_fx()
  n <- names(d)
  e1 <- a2_err(names(d) <- rev(n))
  expect_weft_cond(e1, "weft_dict_error", "names<-")
  e2 <- a2_err(names(d)[1] <- "zzz")
  expect_weft_cond(e2, "weft_dict_error", "names(d)[1]<-")
  expect_identical(names(d), n)
  expect_equal(d$min_samples, 5)
  expect_error(d$zzz, class = "weft_dict_key_error")
})
