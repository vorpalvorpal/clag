# Package 6f: `cite` spans in the filter (dev/design-6.md N100; rules 1.8.1 to 1.8.8, 1.1.5). In the citation
# form the value is written after the span's prose in square brackets, exactly as given, and Pandoc reads it
# as a citation; in the bare form only the prose is printed. The expected output of every case is the text
# the rule gives, read as markdown by Pandoc with no filter (helper-6f.R, f6_want_html()), both through the
# HTML writer. The render-time check of the key is not done by the filter (the static cite-key lint is the
# check, N100): an unknown key prints and fails nothing.

CE <- "<<weft: construct error, line {L}>>"

cite_block <- function() {
  carrier(depth = fr_float("3.14159"), three = fr_int("3"), flag = fr_bool(TRUE), pos = fr_float("0.12"))
}

test_that("1.8.1: the citation form prints the prose, a space, and the citation in brackets", {
  cases <- c(
    plain = "[10 m in the upper catchment]{cite=\"@smith2020\"}.",
    mid = "Depth was [10 m]{cite=\"@smith2020\"} in the upper catchment.",
    year_only = "[10 m]{cite=\"-@smith2020\"}.")
  res <- f6_cases_html(cases, list(cite_block()))
  want <- f6_want_html(c(plain = "10 m in the upper catchment [@smith2020].", mid = "Depth was 10 m [@smith2020] in the upper catchment.",
                         year_only = "10 m [-@smith2020]."))
  expect_identical(res$status, 0L)
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
  expect_match(res$got["plain"], "data-cites=\"smith2020\"", fixed = TRUE)
})

test_that("1.8.3, 1.8.6: the value is written in the brackets exactly as given: locator, prefix, several sources", {
  cases <- c(
    locator = "[10 m]{cite=\"@smith2020, p. 4\"}.", prefix = "[10 m]{cite=\"see @smith2020\"}.",
    several = "[10 m]{cite=\"@smith2020; @jones2019\"}.", words_before = "[10 m]{cite=\"smith2020 and @jones2019\"}.",
    adjacent = "[10 m]{cite=\"@a\"}[11 m]{cite=\"@b\"}.")
  res <- f6_cases_html(cases, list(cite_block()))
  want <- f6_want_html(c(
    locator = "10 m [@smith2020, p. 4].", prefix = "10 m [see @smith2020].", several = "10 m [@smith2020; @jones2019].",
    words_before = "10 m [smith2020 and @jones2019].", adjacent = "10 m [@a]11 m [@b]."))
  expect_identical(res$status, 0L)
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
})

test_that("1.8.1, 1.8.4: the bare form prints the prose only, and its value is keys separated by ;", {
  cases <- c(bare = "@smith2020 found [10 m]{cite=\"smith2020\"} in the upper catchment.",
             two = "[10 m]{cite=\"smith2020; jones2019\"} here.")
  res <- f6_cases_html(cases, list(cite_block()))
  want <- f6_want_html(c(bare = "@smith2020 found 10 m in the upper catchment.", two = "10 m here."))
  expect_identical(res$status, 0L)
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
})

test_that("1.8.4: any other text in a value with no @ is a construct error", {
  cases <- c(spaces = "Z [10 m]{cite=\"not a key\"} z.", comma = "Z [10 m]{cite=\"a, b\"} z.")
  res <- filter_cases(cases, list(cite_block()), draft = TRUE)
  expect_cases(res, c(spaces = paste0("Z ", CE, " z."), comma = paste0("Z ", CE, " z.")))
})

test_that("1.8.2: a cite span has no arms, and holds values and governed spans", {
  cases <- c(arms = "[a | b # c]{cite=\"@s\"}.", value = "[`depth`{.num} m]{cite=\"@s\"}.",
             governed = "[`three`{.num} [core | cores]{n=\"three\"}]{cite=\"@s\"}.",
             bare_arms = "[a | b # c]{cite=\"s\"}.")
  res <- f6_cases_html(cases, list(cite_block()))
  want <- f6_want_html(c(arms = "a | b # c [@s].", value = "3.1 m [@s].", governed = "3 cores [@s].", bare_arms = "a | b # c."))
  expect_identical(res$status, 0L)
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
})

test_that("1.8.7: text classes and pass-through attributes act on the prose; a formatter class is a construct error", {
  cases <- c(strong = "[10 m]{.strong cite=\"@s\"}.", smallcaps = "[10 m]{.smallcaps cite=\"@s\"}.",
             cap = "[north]{.cap cite=\"@s\"}.", bare_strong = "[10 m]{.strong cite=\"s\"}.")
  res <- f6_cases_html(cases, list(cite_block()))
  want <- f6_want_html(c(strong = "**10 m** [@s].", smallcaps = "[10 m]{.smallcaps} [@s].", cap = "North [@s].",
                         bare_strong = "**10 m**."))
  expect_identical(res$status, 0L)
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
  bad <- filter_cases(c(num = "Z [10 m]{.num cite=\"@s\"} z.", pct = "Z [10 m]{.pct cite=\"s\"} z.",
                        word = "Z [10 m]{.word cite=\"@s\"} z."), list(cite_block()), draft = TRUE)
  expect_cases(bad, c(num = paste0("Z ", CE, " z."), pct = paste0("Z ", CE, " z."), word = paste0("Z ", CE, " z.")))
})

test_that("1.8.5, N100: the key is not looked up at render; an unknown key prints and fails nothing", {
  res <- filter_cases(c(a = "Z [10 m]{cite=\"@neverdefined\"} z."), list(cite_block()), draft = FALSE)
  expect_identical(res$status, 0L)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.1.5, 1.3.3: cite on a named value, or with another governor key, is a construct error", {
  cases <- c(on_value = "Z `depth`{.num cite=\"@s\"} z.", two_keys = "Z [a | b]{n=\"three\" cite=\"@s\"} z.")
  res <- filter_cases(cases, list(cite_block()), draft = TRUE)
  expect_cases(res, c(on_value = paste0("Z ", CE, " z.")))
  expect_match(res$got["two_keys"], "^Z <<weft: construct error(, line [0-9]+)?>> z\\.$")
})
