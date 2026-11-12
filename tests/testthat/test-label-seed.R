# Package 3b: label_seed() (L36, rule 9.5.5; contract: dev/design-3.md).
# The working folder is a fresh project, as for dict_seed(). Invented prose only. ASCII only.

LS_COLS <- c("word", "n", "files", "where")

ls_two <- function(env = parent.frame()) {
  ls_proj(list(
    "a.qmd" = c("We visited Site 3 and Site 4 today.", "",
                "Zone 2 was wet and Zone 5 was dry. Stage 1 began.", "",
                "In 2019 and Since 2020 we saw Figure 3 and Table 2 and Fig. 4."),
    "b.qmd" = c("Site 7 was dry and Site 10 too.", "",
                "Over 5 years Between 6 sites site 9 and A 3 and CO2 4.", "",
                "Stage 8 began. Plot 1 was dry.")),
    env = env)
}

test_that("3b L36: the counts, the order and the columns", {
  ls_two()
  r <- suppressMessages(label_seed())
  expect_s3_class(r, "data.frame")
  expect_identical(names(r), LS_COLS)
  expect_type(r$word, "character")
  expect_type(r$n, "integer")
  expect_type(r$where, "character")
  expect_identical(r$word, c("Site", "Stage", "Zone"))
  expect_identical(r$n, c(4L, 2L, 2L))
  expect_true(.row_names_info(r) <= 0, label = "automatic row names")
})

test_that("3b L36: where holds up to three places, as file:line: word numeral", {
  ls_two()
  r <- suppressMessages(label_seed())
  expect_identical(r$where[r$word == "Site"],
                   "a.qmd:1: Site 3; a.qmd:1: Site 4; b.qmd:1: Site 7")
  expect_identical(r$where[r$word == "Zone"], "a.qmd:3: Zone 2; a.qmd:3: Zone 5")
  expect_identical(r$where[r$word == "Stage"], "a.qmd:3: Stage 1; b.qmd:5: Stage 8")
})

test_that("3b L36: the files column names the files that hold the word", {
  ls_two()
  r <- suppressMessages(label_seed())
  expect_true("files" %in% names(r))
  if (is.character(r$files)) {
    expect_identical(r$files[r$word == "Site"], "a.qmd, b.qmd")
    expect_identical(r$files[r$word == "Zone"], "a.qmd")
  } else {
    expect_identical(as.integer(r$files[r$word == "Site"]), 2L)
    expect_identical(as.integer(r$files[r$word == "Zone"]), 1L)
  }
})

test_that("3b L36: min_count sets the lowest count listed", {
  ls_two()
  expect_identical(suppressMessages(label_seed(min_count = 1))$word,
                   c("Site", "Stage", "Zone", "Plot"))
  expect_identical(suppressMessages(label_seed(min_count = 3))$word, "Site")
  r <- suppressMessages(label_seed(min_count = 5))
  expect_identical(nrow(r), 0L)
  expect_identical(names(r), LS_COLS)
})

test_that("3b L36: cross-reference words, the stop list, short words and names are not counted", {
  ls_two()
  r <- suppressMessages(label_seed(min_count = 1))
  expect_false(any(c("Figure", "Fig.", "Fig", "Table", "In", "Since", "Over", "Between", "A",
                     "CO2", "site") %in% r$word))
  ls_proj(list("c.qmd" = c(
    "Figure 1 and Figure 2. Table 3 and Table 4. Section 5 and Section 6.",
    "Chapter 7 and Chapter 8. Equation 9 and Equation 10. Appendix 1 and Appendix 2.",
    "In 2019 and In 2020. On 5 May and On 6 May. At 5 sites and At 6 sites.",
    "By 5 sites and By 6 sites. For 5 days and For 6 days. From 5 to From 6.",
    "To 5 and To 6. Of 5 and Of 6. The 5 and The 6. An 5 and An 6. And 5 and And 6.",
    "Or 5 and Or 6. But 5 and But 6. With 5 and With 6. Since 5 and Since 6.",
    "Until 5 and Until 6. After 5 and After 6. Before 5 and Before 6.",
    "About 5 and About 6. Around 5 and Around 6. Over 5 and Over 6. Under 5 and Under 6.",
    "Between 5 and Between 6. During 5 and During 6. Than 5 and Than 6. Only 5 and Only 6.",
    "All 5 and All 6. Some 5 and Some 6. Each 5 and Each 6. Every 5 and Every 6.",
    "Nearly 5 and Nearly 6. Approximately 5 and Approximately 6.")))
  expect_identical(nrow(suppressMessages(label_seed(min_count = 1))), 0L)
})

test_that("3b L36: a word that is already a label word is not proposed", {
  ls_proj(list("a.qmd" = "Site 3, Site 4, Zone 5 and Zone 6."), weft_yml = "label_words: [Site]")
  expect_identical(suppressMessages(label_seed())$word, "Zone")
})

test_that("3b L36: a year is a numeral unless numeral_years is on", {
  files <- list("a.qmd" = "Survey 2020 and Survey 2021 were run.")
  ls_proj(files)
  expect_identical(suppressMessages(label_seed())$word, "Survey")
  ls_proj(files, weft_yml = "numeral_years: true")
  expect_identical(nrow(suppressMessages(label_seed())), 0L)
})

test_that("3b L36: the numeral must follow in the same block, and be a numeral", {
  ls_proj(list("a.qmd" = c(
    "Site", "3 sites.", "", "Site", "", "4 sites.", "", "site 5 and site 6.", "",
    "Plot 3 and Plot 4 then Plot 5.", "", "Zone ten and Zone twelve.")))
  r <- suppressMessages(label_seed(min_count = 1))
  # "Site\n3" is in one block: one count; the one split by a blank line is none
  expect_identical(r$word, c("Plot", "Site"))
  expect_identical(r$n, c(3L, 1L))
})

test_that("3b L36: words in code, code spans and chunks are not counted", {
  ls_proj(list("a.qmd" = c(
    "Prose with `Site 3` and `Site 4` in code.", "", "```{r}", "Site 5", "Site 6", "```", "",
    "    Site 7 indented", "", "<!-- Site 8 -->", "", "Site 9 and Site 10 are real.")))
  r <- suppressMessages(label_seed(min_count = 1))
  expect_identical(r$word, "Site")
  expect_identical(r$n, 2L)
})

test_that("3b L36: a word needs at least two letters and only letters", {
  ls_proj(list("a.qmd" = "A 1, A 2, Ab 3, Ab 4, Ab2 5, Ab2 6, Abc 7, Abc 8, Abc 9."))
  r <- suppressMessages(label_seed())
  expect_identical(r$word, c("Abc", "Ab"))
  expect_identical(r$n, c(3L, 2L))
})

test_that("3b L36: both .qmd and .Rmd are read, folders by the dict_seed() rules", {
  ls_proj(list("a.qmd" = "Site 3 here.", "sub/b.Rmd" = "Site 4 here.", "sub/deep/c.rmd" = "Site 5 here.",
               "_hidden/d.qmd" = "Site 6 here.", ".dot/e.qmd" = "Site 7 here.",
               "renv/f.qmd" = "Site 8 here.", "notes.txt" = "Site 9 here."))
  r <- suppressMessages(label_seed())
  expect_identical(r$word, "Site")
  expect_identical(r$n, 3L)
  expect_identical(r$where, "a.qmd:1: Site 3; sub/b.Rmd:1: Site 4; sub/deep/c.rmd:1: Site 5")
})

test_that("3b L36: paths limits the files", {
  ls_two()
  r <- suppressMessages(label_seed(paths = "a.qmd"))
  expect_identical(r$word, c("Site", "Zone"))
  expect_identical(r$n, c(2L, 2L))
  r2 <- suppressMessages(label_seed(paths = c("b.qmd", "a.qmd")))
  expect_identical(r2$n, suppressMessages(label_seed())$n)
})

test_that("3b L36: a folder with no documents gives a zero-row result with the columns", {
  ls_proj(list("readme.txt" = "Site 3 and Site 4."))
  r <- suppressMessages(label_seed())
  expect_identical(nrow(r), 0L)
  expect_identical(names(r), LS_COLS)
})

test_that("3b L36: nothing is written", {
  root <- ls_two()
  before <- n3_tree(root)
  suppressMessages(label_seed())
  suppressMessages(label_seed(min_count = 1))
  expect_identical(n3_tree(root), before)
})

# ---- errors ------------------------------------------------------------------------------------

test_that("3b L36/L14: a missing file, another extension and a bad min_count are weft_tool_errors", {
  ls_proj(list("a.qmd" = "Site 3 and Site 4.", "notes.txt" = "x"))
  expect_error(label_seed(paths = c("nope.qmd", "a.qmd")), class = "weft_tool_error")
  expect_error(label_seed(paths = c("a.qmd", "notes.txt")), class = "weft_tool_error")
  for (bad in list(0, 1.5, -2, "a", NA, c(1, 2), NULL, Inf)) {
    expect_error(label_seed(min_count = bad), class = "weft_tool_error")
  }
  expect_no_error(suppressMessages(label_seed(min_count = 2L)))
})
