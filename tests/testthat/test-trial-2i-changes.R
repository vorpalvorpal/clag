# 2i In: I11-I14 (dev/design-2i.md): changes() after the stage 2 trial. Fixtures are hand-written ledgers
# (helper-2e2.R) in temporary git repositories. Non-ASCII is written as \uXXXX. Made-up values only.
if (!exists("i2_run")) source(Filter(file.exists, c(testthat::test_path("helper-2i.R"), testthat::test_path("..", "helper-2i.R")))[[1]])

# ---- I11: "crosses 1.0" is for a ratio or a count, not a quantity ---------------------------------------------------

test_that("2i I11: control - 0.8 to 1.2 with no unit on either side crosses 1.0", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "0.8", raw = 0.8, unit = NA_character_), e2x_entry("x", "1.2", raw = 1.2, unit = NA_character_))
  expect_identical(r$structural, "crosses 1.0")
  r2 <- e2x_rows(e2x_entry("x", "0.8", raw = 0.8), e2x_entry("x", "1.2", raw = 1.2))               # an old ledger: no field
  expect_identical(r2$structural, "crosses 1.0")
})

test_that("2i I11: with a unit on both sides, 0.8 to 1.2 is not a crossing of 1.0", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "0.8 mm", raw = 0.8, unit = "mm"), e2x_entry("x", "1.2 mm", raw = 1.2, unit = "mm"))
  expect_identical(r$structural, "")
  r2 <- e2x_rows(e2x_entry("x", "1.2 mm", raw = 1.2, unit = "mm"), e2x_entry("x", "0.8 mm", raw = 0.8, unit = "mm"))
  expect_identical(r2$structural, "")
})

test_that("2i I11: the reason needs the unit null on both sides", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "0.8", raw = 0.8, unit = NA_character_), e2x_entry("x", "1.2 mm", raw = 1.2, unit = "mm"))
  expect_false(grepl("crosses 1.0", r$structural, fixed = TRUE))
  r2 <- e2x_rows(e2x_entry("x", "0.8 mm", raw = 0.8, unit = "mm"), e2x_entry("x", "1.2", raw = 1.2, unit = NA_character_))
  expect_false(grepl("crosses 1.0", r2$structural, fixed = TRUE))
})

test_that("2i I11: with a unit, the other reasons are unaffected (sign flip, crosses 0, order of magnitude)", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "-2 mm", raw = -2, unit = "mm"), e2x_entry("x", "3 mm", raw = 3, unit = "mm"))
  expect_identical(r$structural, "sign flip")
  r2 <- e2x_rows(e2x_entry("x", "0 mm", raw = 0, unit = "mm"), e2x_entry("x", "4 mm", raw = 4, unit = "mm"))
  expect_identical(r2$structural, "crosses 0")
  r3 <- e2x_rows(e2x_entry("x", "0.06 mm", raw = 0.06, unit = "mm"), e2x_entry("x", "0.6 mm", raw = 0.6, unit = "mm"))
  expect_identical(r3$structural, "order of magnitude")
  r4 <- e2x_rows(e2x_entry("x", "0.8 mm", raw = 0.8, unit = "mm"), e2x_entry("x", "12 mm", raw = 12, unit = "mm"))
  expect_identical(r4$structural, "order of magnitude")
})

test_that("2i I11: the same entries with no unit keep all their reasons (control)", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "-2", raw = -2, unit = NA_character_), e2x_entry("x", "3", raw = 3, unit = NA_character_))
  expect_identical(r$structural, "sign flip, crosses 1.0")
  r2 <- e2x_rows(e2x_entry("x", "0.8", raw = 0.8, unit = NA_character_), e2x_entry("x", "12", raw = 12, unit = NA_character_))
  expect_identical(r2$structural, "crosses 1.0, order of magnitude")
})

test_that("2i I11: a unit does not hide a crossing of a dictionary value", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "0.8 km", raw = 0.8, unit = "km", dict = "dict$lim"),
                e2x_entry("x", "1.2 km", raw = 1.2, unit = "km", dict = "dict$lim"),
                dict_before = "lim: {value: 1, unit: km, type: quantity, definition: \"The limit.\"}")
  expect_identical(r$structural, "crosses dict$lim")
})

# ---- I12: number words are not claim words ---------------------------------------------------------------------------------

claim_i2 <- function(sentence_before, sentence_after, text = "7", text_after = "8") {
  r <- e2x_rows(e2x_entry("n", text, raw = 7, sentence = sentence_before),
                e2x_entry("n", text_after, raw = 8, sentence = sentence_after))
  r$claim_word
}

test_that("2i I12: a sentence whose only candidate is a number word has no claim word", {
  skip_if(Sys.which("git") == "")
  expect_true(is.na(claim_i2("Of the sites, seven were open.", "Of the sites, eight were open.")))
  expect_true(is.na(claim_i2("Seven sites were open.", "Seven sites were open on the day.")))
  expect_true(is.na(claim_i2("Of the sites, four were open.", "Of the sites, four were open today.")))
})

test_that("2i I12: each of one to twelve, first, second and third is out of the list", {
  skip_if(Sys.which("git") == "")
  for (w in c("one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
              "first", "second", "third")) {
    got <- claim_i2(sprintf("There were %s samples here.", w), sprintf("There were %s samples there.", w))
    expect_true(is.na(got), label = w)
  }
})

test_that("2i I12: a number word beside a real claim word gives the real one", {
  skip_if(Sys.which("git") == "")
  expect_identical(claim_i2("Of the sites, seven were open, all of them.", "Of the sites, eight were open, all of them."), "all")
  expect_identical(claim_i2("None of the seven sites were open.", "None of the eight sites were open."), "none")
})

test_that("2i I12: all and none are still found (control)", {
  skip_if(Sys.which("git") == "")
  expect_identical(claim_i2("All sites were visited.", "All sites were visited twice."), "all")
  expect_identical(claim_i2("Samples came back and none failed.", "Samples came back and none failed again."), "none")
  r <- e2x_rows(e2x_entry("n", "7", raw = 7, sentence = "Flow rose to 7 units."),
                e2x_entry("n", "8", raw = 8, sentence = "Flow rose to 8 units."))
  expect_identical(r$claim_word, "rose")
})

# ---- I13: an arm that prints nothing ------------------------------------------------------------------------------------------

i2_if_entry <- function(text, sentence) {
  e2x_entry("ratio < dict$limit", text, kind = "if", section = "quality", arm = if (nzchar(text)) "true" else NA_character_,
            dict = "dict$limit", sentence = sentence)
}

test_that("2i I13: an entry whose text is empty after shows (prints nothing), not the neighbouring sentence", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(i2_if_entry(", below the limit", "The mean ratio was 0.98, below the limit.")),
                      list(i2_if_entry("", "Then the next sentence follows.")))
  out <- i2_print(changes(path = dir))
  i <- grep("^  ~ a.qmd#quality  if  ratio < dict\\$limit", out)
  expect_length(i, 1L)
  if (length(i) != 1L) return(invisible())
  expect_identical(out[i + 1L], "      before: The mean ratio was 0.98, below the limit.")
  expect_identical(out[i + 2L], "      after:  (prints nothing)")
  expect_false(any(grepl("Then the next sentence follows.", out, fixed = TRUE)))
})

test_that("2i I13: the same on the before side", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(i2_if_entry("", "A neighbouring sentence stands here.")),
                      list(i2_if_entry(", below the limit", "The mean ratio was 0.98, below the limit.")))
  out <- i2_print(changes(path = dir))
  i <- grep("^  ~ a.qmd#quality  if  ratio < dict\\$limit", out)
  expect_length(i, 1L)
  if (length(i) != 1L) return(invisible())
  expect_identical(out[i + 1L], "      before: (prints nothing)")
  expect_identical(out[i + 2L], "      after:  The mean ratio was 0.98, below the limit.")
  expect_false(any(grepl("neighbouring sentence", out, fixed = TRUE)))
})

test_that("2i I13: the table keeps the text as stored (an empty string), and an empty sentence is no sentence either", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(i2_if_entry(", below the limit", "The mean ratio was 0.98, below the limit.")),
                      list(i2_if_entry("", "")))
  ch <- changes(path = dir)
  expect_identical(ch$entries$text_after, "")
  out <- i2_print(ch)
  expect_true("      after:  (prints nothing)" %in% out)
})

test_that("2i I13: control - an entry that prints text after still shows its sentence", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(i2_if_entry(", below the limit", "The mean ratio was 0.98, below the limit.")),
                      list(i2_if_entry(", above the limit", "The mean ratio was 1.04, above the limit.")))
  out <- i2_print(changes(path = dir))
  expect_true("      after:  The mean ratio was 1.04, above the limit." %in% out)
  expect_false(any(grepl("(prints nothing)", out, fixed = TRUE)))
})

# ---- I14: print(x, brief = TRUE) ---------------------------------------------------------------------------------------------

test_that("2i I14: the default print has every section (control), and brief = FALSE is the same", {
  skip_if(Sys.which("git") == "")
  dir <- i2_big_project()
  ch <- changes(path = dir)
  full <- i2_print(ch)
  for (h in I2_SECTIONS) expect_true(h %in% full, label = h)
  expect_identical(i2_print(ch, brief = FALSE), full)
})

test_that("2i I14: brief prints the header line, the structural changes, the not re-rendered ledgers and the new conditions", {
  skip_if(Sys.which("git") == "")
  dir <- i2_big_project()
  ch <- changes(path = dir)
  full <- i2_print(ch)
  out <- i2_print(ch, brief = TRUE)
  expect_identical(out[1], full[1])
  expect_match(out[1], "^weft changes since HEAD \\([0-9a-f]{7}\\): ")
  for (h in c("Not re-rendered", "Structural changes", "New conditions")) expect_true(h %in% out, label = h)
  expect_true("  reports/survey.qmd: 3 entries; reports/survey.qmd changed" %in% out)
  expect_true("  ~ reports/survey.qmd#quality  value  ratio {#ratio}  [crosses 1.0] (not re-rendered)" %in% out)
  expect_true(any(grepl("^  ! reports/survey.qmd  target fit  warning: Model failed to converge", out)))
  expect_lt(length(out), length(full))
})

test_that("2i I14: brief prints none of the other sections", {
  skip_if(Sys.which("git") == "")
  dir <- i2_big_project()
  out <- i2_print(changes(path = dir), brief = TRUE)
  for (h in c("Other changes, ranked", "Added", "Removed", "Ledgers")) expect_false(h %in% out, label = h)
  expect_false(any(grepl("reports/water.qmd", out, fixed = TRUE)))                                   # only an other change, an added and a removed entry
  expect_false(any(grepl("reports/flow.qmd", out, fixed = TRUE)))                                    # a new ledger
  expect_false(any(grepl("source gone", out, fixed = TRUE)))
})

test_that("2i I14: print(x, brief = TRUE) returns x invisibly", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  ch <- changes(path = dir)
  v <- NULL
  capture.output(v <- withVisible(print(ch, brief = TRUE)))
  expect_false(v$visible)
  expect_identical(v$value, ch)
})

test_that("2i I14: with only other changes, brief prints the header line and nothing more", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  ch <- changes(path = dir)
  out <- i2_print(ch, brief = TRUE)
  expect_identical(out, i2_print(ch)[1])
  expect_false("Other changes, ranked" %in% out)
})

test_that("2i I14: an unchanged project prints the same single line in brief", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "1")))
  ch <- changes(path = dir)
  expect_identical(i2_print(ch, brief = TRUE), i2_print(ch))
  expect_length(i2_print(ch, brief = TRUE), 1L)
})
