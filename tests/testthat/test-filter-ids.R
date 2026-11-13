# Package 6f: ids and back-references in the filter (dev/design-6.md N12, N13, N100; rules 1.5.16, 1.7.5 to
# 1.7.11). An id on a named value, `depth`{#d .num}, names that printed occurrence; a later n or sign span
# refers to it with n="#d". One document of many cases per test, through plain Pandoc (helper-filter.R).
#
# Left out, because the design is silent or another package owns it (see the report's "Spec gaps"): E6 (a
# span the filter resolves referring to an id on an R value) is found from the source, which is package 6d's;
# the ledger key of an id (1.7.12) is 6g's; whether an id is left on the output (1.2.8 against the ruling
# that an id on a named value goes on the pass-through span).

CE <- "<<weft: construct error, line {L}>>"
VE <- "<<weft: value error, line {L}>>"

ids_block <- function() {
  carrier(
    depth = fr_float("3.14159"), one = fr_int("1"), three = fr_int("3"), neg = fr_float("-0.12"),
    pos = fr_float("0.12"), f104 = fr_float("1.04"), flag = fr_bool(TRUE), noflag = fr_bool(FALSE),
    l2 = fr_list_str(c("a", "b")), s1 = fr_str("north")
  )
}

test_that("1.7.5, 1.7.6: an #id on a named value is referred to by n=\"#id\", and # is the printed text", {
  cases <- c(
    d_cores = "Depth `depth`{#d .num} m. The [core | cores]{n=\"#d\"} were deep.",
    d_hash = "Depth `depth`{#d2 .num} m. The [# core | # cores]{n=\"#d2\"} were deep.",
    one_core = "Depth `one`{#o .num} m. The [core | cores]{n=\"#o\"} was deep.",
    three_cores = "Count `three`{#t .num} here. The [core | cores]{n=\"#t\"} were deep.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(d_cores = "Depth 3.1 m. The cores were deep.", d_hash = "Depth 3.1 m. The 3.1 cores were deep.",
                      one_core = "Depth 1 m. The core was deep.", three_cores = "Count 3 here. The cores were deep."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.7.9: [#]{n=\"#d\"} prints the value again", {
  cases <- c(again = "Depth `depth`{#d .num} m, or [#]{n=\"#d\"} m again.",
             pct = "Change `pos`{#p .pct}, or [#]{n=\"#p\"} again.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, c(again = "Depth 3.1 m, or 3.1 m again.", pct = "Change 12%, or 12% again."))
})

test_that("1.7.8: with no formatter of its own the referring span uses the printed record; with one it formats the raw value afresh", {
  cases <- c(
    printed_one = "Depth `f104`{#a .num digits=\"0\"} m. The [core | cores]{n=\"#a\"} here.",
    afresh_digits = "Depth `f104`{#b .num digits=\"0\"} m. The [core | cores]{n=\"#b\" digits=\"2\"} here.",
    afresh_hash = "Depth `f104`{#c .num digits=\"0\"} m. The [# core | # cores]{n=\"#c\" digits=\"2\"} here.",
    afresh_word = "Count `three`{#e .num} here. The [# core | # cores]{.word n=\"#e\"} there.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(printed_one = "Depth 1 m. The core here.", afresh_digits = "Depth 1 m. The cores here.",
                      afresh_hash = "Depth 1 m. The 1.04 cores here.",
                      afresh_word = "Count 3 here. The three cores there."))
  # a text class does not count as a formatter: the printed record is still used (the id may stay on a span)
  res2 <- f6_cases_html(c(t = "Count `three`{#f .num} here. The [# core | # cores]{.strong n=\"#f\"} there."),
                        list(ids_block()))
  expect_match(res2$got["t"], "The <strong>3 cores</strong> there.</p>$")
})

test_that("1.5.8, 1.7.6: a sign span refers to an id; # is the magnitude as printed, without its sign", {
  cases <- c(neg = "Change `neg`{#c .pct} here. It [rose by # | fell by #]{sign=\"#c\"} overall.",
             pos = "Change `pos`{#c2 .pct} here. It [rose by # | fell by #]{sign=\"#c2\"} overall.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, c(neg = paste0("Change \u2212", "12% here. It fell by 12% overall."),
                      pos = "Change 12% here. It rose by 12% overall."))
})

test_that("1.7.5: an id is unique within a document; a duplicate is a construct error", {
  cases <- c(first = "A `depth`{#dup .num} m.", second = "B `one`{#dup .num} m.", third = "C [x | y]{#dup if=\"flag\"} z.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, c(first = "A 3.1 m.", second = paste0("B ", CE, " m."), third = paste0("C ", CE, " z.")))
})

test_that("1.7.5: a cite span and a list span take no #id", {
  cases <- c(cite = "Z [x]{#ci cite=\"@s\"} z.", list = "Z [none | # was | # were]{#li list=\"l2\"} z.",
             text = "Z [x]{#te .strong} z.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, " z."), length(cases)), names(cases)))
})

test_that("1.7.10: the id must be defined earlier in the document; an unknown id, or one defined further down, is a construct error", {
  cases <- c(unknown = "Z [core | cores]{n=\"#nowhere\"} z.", early = "Z [core | cores]{n=\"#late\"} z.",
             late = "Z `depth`{#late .num} z.", sign_unknown = "Z [up | down]{sign=\"#nowhere\"} z.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, c(unknown = paste0("Z ", CE, " z."), early = paste0("Z ", CE, " z."), late = "Z 3.1 z.",
                      sign_unknown = paste0("Z ", CE, " z.")))
})

test_that("1.7.7: the referring span re-evaluates nothing, so a check carried on the record is reported once", {
  rec <- fr_with(fr_float("3.14159"), fr_check("depth > 5", ok = FALSE, why = "too shallow"))
  cases <- c(a = "Depth `d5`{#d .num} m. The [core | cores]{n=\"#d\"} and the [hole | holes]{n=\"#d\"}.")
  res <- filter_cases(cases, list(carrier(d5 = rec)), draft = TRUE)
  expect_equal(lengths(regmatches(res$stderr, gregexpr("depth > 5 was false", res$stderr, fixed = TRUE))), 1L)
})

test_that("1.5.16, 1.7.11: an id defined in an arm exists only for spans inside the same arm", {
  cases <- c(
    inside = "Z [`three`{#in1 .num} [core | cores]{n=\"#in1\"} | none]{if=\"flag\"} z.",
    outside = "Z [`three`{#in2 .num} | none]{if=\"flag\"} then [core | cores]{n=\"#in2\"} z.",
    not_chosen = "Z [none | `three`{#in3 .num}]{if=\"flag\"} then [core | cores]{n=\"#in3\"} z.",
    again = "Z [`three`{#in4 .num} | none]{if=\"noflag\"} then `one`{#in4 .num} z.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, c(inside = "Z 3 cores z.", outside = paste0("Z 3 then ", CE, " z."),
                      not_chosen = paste0("Z none then ", CE, " z."), again = "Z none then 1 z."))
})

test_that("N12: n and sign take #id; the id of a value that is no number is a failure when used as one", {
  cases <- c(str_id = "Z `s1`{#st .val} then [a | b]{n=\"#st\"} z.")
  res <- filter_cases(cases, list(ids_block()), draft = TRUE)
  expect_cases(res, c(str_id = paste0("Z north then ", VE, " z.")))
})
