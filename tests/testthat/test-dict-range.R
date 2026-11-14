# Stage 7h (dev/design-7.md, 2 H, notes N110 to N115): the `range` dictionary type, `.range` on
# it, in_range(), changes() at each bound, the glossary, print() and tar_dict().
# Expected values and texts come from the design (2 H, 7: E60, E61). Controls (existing behaviour
# that must not change) are marked as such. EN is the en dash.

EN <- "–"

# ---- N110 problems ---------------------------------------------------------------------------

RANGE_ONE <- "a: {value: 1, type: number, definition: \"Fine.\"}"

# name, the entry's lines, the field the problem line names, the text it must hold
RANGE_PROBLEMS <- list(
  list("a scalar", "b: {value: 7, type: range, definition: x}", "value",
       "must be a sequence of two numbers, lower then upper"),
  list("one number", "b: {value: [6.5], type: range, definition: x}", "value",
       "must be a sequence of two numbers, lower then upper"),
  list("three numbers", "b: {value: [1, 2, 3], type: range, definition: x}", "value",
       "must be a sequence of two numbers, lower then upper"),
  list("an empty sequence", "b: {value: [], type: range, definition: x}", "value",
       "must be a sequence of two numbers, lower then upper"),
  list("text bounds", "b: {value: [low, high], type: range, definition: x}", "value",
       "must be a sequence of two numbers, lower then upper"),
  list("a mapping", "b: {value: {lower: 1, upper: 2}, type: range, definition: x}", "value",
       "must be a sequence of two numbers, lower then upper"),
  list("bounds the wrong way round", "b: {value: [8.5, 6.5], type: range, definition: x}", "value",
       "the lower bound must be below the upper bound"),
  list("equal bounds", "b: {value: [7, 7], type: range, definition: x}", "value",
       "the lower bound must be below the upper bound"),
  list("an infinite upper bound", "b: {value: [6.5, .inf], type: range, definition: x}", "value",
       "a bound must be finite; a limit on one side is a `number` or `quantity` entry"),
  list("an infinite lower bound", "b: {value: [-.inf, 8.5], type: range, definition: x}", "value",
       "a bound must be finite; a limit on one side is a `number` or `quantity` entry"),
  list("a hex bound", "b: {value: [0x1F, 40], type: range, definition: x}", "value", "decimal"),
  list("a leading zero", "b: {value: [010, 40], type: range, definition: x}", "value", "decimal"),
  list("display without a unit", "b: {value: [6.5, 8.5], type: range, display: g/L, definition: x}",
       "display", "display")
)

test_that("N110: the table of problems has its thirteen cases", {
  expect_length(RANGE_PROBLEMS, 13L)
})

for (case in RANGE_PROBLEMS) {
  local({
    nm <- case[[1]]; entry <- case[[2]]; field <- case[[3]]; text <- case[[4]]
    test_that(sprintf("N110: %s is one problem with its text, its field and the entry's line (4.2.6)", nm), {
      lines <- c(RANGE_ONE, entry)
      r <- r7h_err(lines)
      expect_weft_cond(r$error, "weft_dict_error", nm)
      msg <- conditionMessage(r$error)
      expect_true(startsWith(msg, sprintf("weft: %s: 1 problem(s) in the dictionary", r$path)))
      pl <- grep(sprintf("%s:2: `b`", r$path), strsplit(msg, "\n")[[1]], fixed = TRUE, value = TRUE)
      expect_length(pl, 1L)
      expect_match(pl, field, fixed = TRUE)
      expect_match(pl, text, fixed = TRUE)
      expect_match(pl, "(rule 4.2.1", fixed = TRUE)
    })
  })
}

test_that("N110: two bad ranges are two problems, each at its own line, and the good entry is not named", {
  lines <- c(RANGE_ONE, "b: {value: [8, 6], type: range, definition: x}", "c: {value: 5, type: range, definition: x}")
  r <- r7h_err(lines)
  expect_weft_cond(r$error, "weft_dict_error", "two")
  msg <- conditionMessage(r$error)
  expect_true(startsWith(msg, sprintf("weft: %s: 2 problem(s) in the dictionary", r$path)))
  expect_match(msg, sprintf("%s:2: `b`", r$path), fixed = TRUE)
  expect_match(msg, sprintf("%s:3: `c`", r$path), fixed = TRUE)
  expect_false(grepl("`a`", msg, fixed = TRUE))
  expect_match(grep("`b`", strsplit(msg, "\n")[[1]], value = TRUE), "the lower bound must be below the upper bound", fixed = TRUE)
  expect_match(grep("`c`", strsplit(msg, "\n")[[1]], value = TRUE), "must be a sequence of two numbers, lower then upper", fixed = TRUE)
})

test_that("N110: unit is optional on a range, and the same file reads with or without it", {
  expect_s3_class(r7h_read(c(RANGE_ONE, r7h_band())), "weft_dict")
  expect_s3_class(r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L"))), "weft_dict")
  expect_s3_class(r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L", display = "g/L"))), "weft_dict")
})

test_that("control N110: a number entry with a unit is still a problem (the type list grew, the rules did not)", {
  r <- r7h_err(c(RANGE_ONE, "b: {value: 1, type: number, unit: m, definition: x}"))
  expect_weft_cond(r$error, "weft_dict_error", "unit on a number")
})

# ---- N111 the reader ---------------------------------------------------------------------------

test_that("N111: a range without a unit is a numeric vector of length 2 named lower and upper", {
  d <- r7h_read(c(RANGE_ONE, r7h_band()))
  expect_false(inherits(d$band, "units"))
  expect_identical(d$band, c(lower = 6.5, upper = 8.5))
  expect_identical(d$band[["lower"]], 6.5)
  expect_identical(d$band[["upper"]], 8.5)
})

test_that("N111: a range with a unit is a units vector of that shape; [[ reads one bound", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L")))
  expect_s3_class(d$band, "units")
  expect_length(d$band, 2L)
  expect_identical(names(d$band), c("lower", "upper"))
  expect_qty(d$band[["lower"]], 6.5, "mg/L")
  expect_qty(d$band[["upper"]], 8.5, "mg/L")
})

test_that("N111: display converts both bounds, and the vector is in the display unit", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L", display = "g/L")))
  expect_s3_class(d$band, "units")
  expect_identical(names(d$band), c("lower", "upper"))
  expect_qty(d$band[["lower"]], 0.0065, "g/L")
  expect_qty(d$band[["upper"]], 0.0085, "g/L")
  expect_identical(units::deparse_unit(d$band), "g/L")
})

test_that("N111: bounds written as decimal strings that are literals read as numbers (control of 4.2.5)", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(value = "[\"1e-3\", \"2\"]")))
  expect_equal(unname(d$band), c(0.001, 2))
})

test_that("N111: .range prints the bounds with an en dash and the unit once", {
  res <- r7h_knit("The band is `r dict$band`{.range}.", c(RANGE_ONE, r7h_band(unit = "mg/L")))
  expect_match(res$all, paste0("The band is 6.5", EN, "8.5 mg/L."), fixed = TRUE)
  expect_false(grepl("mg/L.*mg/L", res$all))
})

test_that("N111: .range of a range with no unit prints the two numbers", {
  res <- r7h_knit("The band is `r dict$band`{.range}.", c(RANGE_ONE, r7h_band()))
  expect_match(res$all, paste0("The band is 6.5", EN, "8.5."), fixed = TRUE)
})

test_that("N111: .range of a range in display units prints the display unit", {
  res <- r7h_knit("The band is `r dict$band`{.range}.",
                  c(RANGE_ONE, r7h_band(unit = "mg/L", display = "g/L")))
  expect_match(res$all, paste0("The band is 0.0065", EN, "0.0085 g/L."), fixed = TRUE)
})

test_that("control N111: .range of a plain pair prints as before", {
  res <- r7h_knit("Sites `r c(3, 5)`{.range}.", c(RANGE_ONE))
  expect_match(res$all, paste0("Sites 3", EN, "5."), fixed = TRUE)
})

test_that("N112: in_range() works as a governor in a knit, both arms", {
  body <- "The mean was [within | outside]{if=\"in_range(do_mean, dict$band)\"} the band."
  dl <- c(RANGE_ONE, r7h_band(unit = "mg/L"))
  inside <- r7h_knit(body, dl, code = "do_mean <- units::set_units(7.2, 'mg/L')")
  outside <- r7h_knit(body, dl, code = "do_mean <- units::set_units(9.1, 'mg/L')")
  expect_match(inside$all, "The mean was within the band.", fixed = TRUE)
  expect_match(outside$all, "The mean was outside the band.", fixed = TRUE)
})

# ---- N112 in_range() ---------------------------------------------------------------------------

test_that("N112: in_range() is exported", {
  expect_true("in_range" %in% getNamespaceExports("weft"))
})

test_that("N112: in_range() on numbers is TRUE where lower <= x <= upper, bounds included, NA stays NA", {
  r <- c(lower = 6.5, upper = 8.5)
  expect_equal(unname(in_range(c(6.4, 6.5, 7, 8.5, 8.6, NA), r)), c(FALSE, TRUE, TRUE, TRUE, FALSE, NA))
  expect_equal(unname(in_range(7, r)), TRUE)
  expect_equal(unname(in_range(c(6.5, 8.5), c(6.5, 8.5))), c(TRUE, TRUE))   # an unnamed pair is a range too
  expect_length(in_range(numeric(), r), 0L)
})

test_that("N112: in_range() on quantities converts x to the range's unit", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L")))
  x <- u(c(7, 9, NA), "mg/L")
  expect_equal(unname(in_range(x, d$band)), c(TRUE, FALSE, NA))
  expect_equal(unname(in_range(u(c(0.007, 0.009), "g/L"), d$band)), c(TRUE, FALSE))
  expect_false(inherits(in_range(x, d$band), "units"))
})

test_that("N112: in_range() takes a range read from the dictionary, or built by hand from its bounds", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L")))
  expect_true(unname(in_range(u(7, "mg/L"), c(d$band[["lower"]], d$band[["upper"]]))))
})

test_that("E60: a number against a quantity range names both sides", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L")))
  e <- a2_err(in_range(7, d$band))
  expect_weft_cond(e, "weft_value_error", "number vs quantity")
  expect_match(conditionMessage(e),
               "in_range(): `x` in no unit cannot be compared with a range in mg/L (rule 4.2.8).", fixed = TRUE)
})

test_that("E60: a quantity against a number range names both sides", {
  d <- r7h_read(c(RANGE_ONE, r7h_band()))
  e <- a2_err(in_range(u(7, "mg/L"), d$band))
  expect_weft_cond(e, "weft_value_error", "quantity vs number")
  expect_match(conditionMessage(e),
               "in_range(): `x` in mg/L cannot be compared with a range in no unit (rule 4.2.8).", fixed = TRUE)
})

test_that("E60: units that do not convert", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L")))
  e <- a2_err(in_range(u(7, "m"), d$band))
  expect_weft_cond(e, "weft_value_error", "m vs mg/L")
  expect_match(conditionMessage(e),
               "in_range(): `x` in m cannot be compared with a range in mg/L (rule 4.2.8).", fixed = TRUE)
})

test_that("E61: a range that is not two numbers in order", {
  msg <- "in_range(): `range` must be two numbers, the lower first (rule 4.2.8)."
  bad <- list("reversed" = c(8.5, 6.5), "one" = 6.5, "three" = c(1, 2, 3), "text" = c("a", "b"),
              "an NA bound" = c(1, NA), "equal" = c(7, 7))
  expect_length(bad, 6L)
  for (nm in names(bad)) {
    e <- a2_err(in_range(7, bad[[nm]]))
    expect_weft_cond(e, "weft_value_error", nm)
    expect_match(conditionMessage(e), msg, fixed = TRUE)
  }
  e <- a2_err(in_range(7, NULL))
  expect_weft_cond(e, "weft_value_error", "NULL")
})

# ---- N113 changes() ------------------------------------------------------------------------------

DICT_BAND <- function(lo, hi) sprintf("band: {value: [%s, %s], type: range, definition: \"The band.\"}", lo, hi)

test_that("N113: a value that crosses the lower bound is `crosses dict$band`", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("do_mean", "6.0", raw = 6.0, dict = "dict$band"),
                e2x_entry("do_mean", "7.0", raw = 7.0, dict = "dict$band"),
                dict_before = DICT_BAND(6.5, 8.5))
  expect_identical(r$structural, "crosses dict$band")
})

test_that("N113: a value that crosses the upper bound is `crosses dict$band`", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("do_mean", "8.0", raw = 8.0, dict = "dict$band"),
                e2x_entry("do_mean", "9.0", raw = 9.0, dict = "dict$band"),
                dict_before = DICT_BAND(6.5, 8.5))
  expect_identical(r$structural, "crosses dict$band")
})

test_that("N113: a value that jumps across the whole band is one crossing, not two", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("do_mean", "6.0", raw = 6.0, dict = "dict$band"),
                e2x_entry("do_mean", "9.0", raw = 9.0, dict = "dict$band"),
                dict_before = DICT_BAND(6.5, 8.5))
  expect_identical(r$structural, "crosses dict$band")
})

test_that("control N113: a value that stays inside the band is not a crossing", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("do_mean", "7.0", raw = 7.0, dict = "dict$band"),
                e2x_entry("do_mean", "7.5", raw = 7.5, dict = "dict$band"),
                dict_before = DICT_BAND(6.5, 8.5))
  expect_identical(r$structural, "")
})

test_that("N113: the same raw is a crossing when a bound of the dictionary moved past it", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("do_mean", "7.0 (old)", raw = 7.0, dict = "dict$band"),
                e2x_entry("do_mean", "7.0 (new)", raw = 7.0, dict = "dict$band"),
                dict_before = DICT_BAND(6.5, 8.5), dict_after = DICT_BAND(7.5, 8.5))
  expect_identical(r$structural, "crosses dict$band")
  r2 <- e2x_rows(e2x_entry("do_mean", "8.0 (old)", raw = 8.0, dict = "dict$band"),
                 e2x_entry("do_mean", "8.0 (new)", raw = 8.0, dict = "dict$band"),
                 dict_before = DICT_BAND(6.5, 8.5), dict_after = DICT_BAND(6.5, 7.5))
  expect_identical(r2$structural, "crosses dict$band")
})

test_that("N113: a band named by another entry in the same sentence counts", {
  skip_if(Sys.which("git") == "")
  sb <- "The mean was 8.0, within the band."
  sa <- "The mean was 9.0, within the band."
  dir <- e2x_scenario(
    list(e2x_entry("do_mean", "8.0", raw = 8.0, section = "q", sentence = sb),
         e2x_entry("in_range(do_mean, dict$band)", ", within the band", kind = "if", arm = "true",
                   section = "q", dict = "dict$band", sentence = sb)),
    list(e2x_entry("do_mean", "9.0", raw = 9.0, section = "q", sentence = sa),
         e2x_entry("in_range(do_mean, dict$band)", ", within the band", kind = "if", arm = "true",
                   section = "q", dict = "dict$band", sentence = sa)),
    dict_before = DICT_BAND(6.5, 8.5))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$expr, "do_mean")
  expect_identical(r$structural, "crosses dict$band")
})

test_that("N113: a number entry's threshold still works in a dictionary that also holds a range", {
  skip_if(Sys.which("git") == "")
  dl <- c("limit: {value: 0.85, type: number, definition: \"The limit.\"}", DICT_BAND(6.5, 8.5))
  r <- e2x_rows(e2x_entry("ratio", "0.8", raw = 0.8, dict = "dict$limit"),
                e2x_entry("ratio", "0.9", raw = 0.9, dict = "dict$limit"),
                dict_before = dl)
  expect_identical(r$structural, "crosses dict$limit")
})

# ---- N114 glossary, print, tar_dict ----------------------------------------------------------------

test_that("N114: the glossary prints the range as .range does", {
  d <- r7h_read(c("band: {value: [6.5, 8.5], type: range, unit: mg/L, term: acceptable band, definition: \"A band.\"}",
                  "plain: {value: [1, 3], type: range, definition: \"A plain pair.\"}"))
  out <- r7h_nb(dict_glossary(d))
  expect_match(out, paste0("acceptable band (6.5", EN, "8.5 mg/L)\n:   A band."), fixed = TRUE)
  expect_match(out, paste0("`plain` (1", EN, "3)\n:   A plain pair."), fixed = TRUE)
})

test_that("N114: values = FALSE drops the range from the heading", {
  d <- r7h_read(c(r7h_band(unit = "mg/L")))
  out <- r7h_nb(dict_glossary(d, values = FALSE))
  expect_false(grepl("(", out, fixed = TRUE))
  expect_match(out, "`band`\n:   An acceptable band.", fixed = TRUE)
})

test_that("N114: print() of a dictionary shows `range 6.5 to 8.5 mg/L`", {
  d <- r7h_read(c(RANGE_ONE, r7h_band(unit = "mg/L"), r7h_band(key = "pair", value = "[1, 3]")))
  out <- r7h_nb(capture.output(print(d)))
  expect_match(out[1], "3 keys", fixed = TRUE)
  expect_match(grep("^.*band", out, value = TRUE)[1], "range 6.5 to 8.5 mg/L", fixed = TRUE)
  expect_match(grep("pair", out, value = TRUE)[1], "range 1 to 3", fixed = TRUE)
  expect_false(grepl("range 1 to 3 mg/L", paste(out, collapse = "\n"), fixed = TRUE))
})

test_that("N114: the entries attribute carries the type `range`", {
  d <- r7h_read(c(RANGE_ONE, r7h_band()))
  e <- attr(d, "entries")
  expect_identical(e$type[e$key == "band"], "range")
})

test_that("N114: tar_dict() passes the vector, and a target reads a bound from it", {
  skip_if_not_installed("targets")
  skip_on_cran()
  d <- e1_tmp()
  writeLines(c(r7h_band(unit = "mg/L")), file.path(d, "dict.yml"))
  writeLines(c("library(targets)",
               "c(weft::tar_dict(\"dict.yml\"),",
               "  weft::tar_dict_deps(list(tar_target(t_up, as.numeric(dict$band[[\"upper\"]]) * 2))))"),
             file.path(d, "_targets.R"))
  built <- e1_make(d)
  expect_true("t_up" %in% built)
  b <- withr::with_dir(d, targets::tar_read(dict_band))
  expect_equal(as.numeric(b), c(6.5, 8.5))
  expect_identical(names(b), c("lower", "upper"))
  expect_equal(withr::with_dir(d, targets::tar_read(t_up)), 17)
})

# ---- N115 lints --------------------------------------------------------------------------------------

test_that("control N115: dict-key lint still flags a read of an unknown key, and passes a read of a range key", {
  src <- c("---", "title: t", "---", "", "Band `r dict$band`{.range} and `r dict$bnad`{.range}.")
  f <- lint_fixture(list("a.qmd" = src, "dict.yml" = c(RANGE_ONE, r7h_band())), rules = "dict-key")
  expect_equal(length(lf_texts(f)), 1L)
  expect_match(lf_texts(f), "bnad", fixed = TRUE)
})
