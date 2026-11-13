# Package 6c: `n` spans in the filter (dev/design-6.md N12, N82; rules 1.5.1, 1.5.2, 1.5.7 to 1.5.12,
# 1.5.18, 1.7.2). English plural forms only (1.6). Each test is one document of many cases through plain
# Pandoc (helper-filter.R). While inst/quarto/weft.lua does not exist every test fails on that.
#
# Not here, left to package 6f: `sign`, `list`, `n` with .range, ids and back-references (`#id`).

CE <- "<<weft: construct error, line {L}>>"
NV <- "<<weft: no value, line {L}>>"

n_block <- function() {
  carrier(k0 = fr_int("0"), k1 = fr_int("1"), k2 = fr_int("2"), k3 = fr_int("3"),
          kf = fr_float("1.0"), kh = fr_float("1.2"), k1234 = fr_int("1234"), kz = fr_float("0.04"),
          miss = fr_missing("not counted"))
}

# a span written for each of k0..k3, and the text each prints
n_table <- function(span, want) {
  ks <- paste0("k", 0:3)
  list(cases = stats::setNames(sprintf("Z %s z.", vapply(ks, function(k) sprintf(span, k), "")),
                               paste0(gsub("[^a-z]+", "_", span), ks)),
       expected = stats::setNames(sprintf("Z %s z.", want), paste0(gsub("[^a-z]+", "_", span), ks)))
}

test_that("1.5.1, 1.5.9: two, three and four arms pick by the number as printed", {
  t2 <- n_table("[a person | # people]{n=\"%s\"}", c("0 people", "a person", "2 people", "3 people"))
  t3 <- n_table("[no people | a person | # people]{n=\"%s\"}", c("no people", "a person", "2 people", "3 people"))
  t4 <- n_table("[never | once | twice | # times]{n=\"%s\"}", c("never", "once", "twice", "3 times"))
  cases <- c(t2$cases, t3$cases, t4$cases)
  expected <- c(t2$expected, t3$expected, t4$expected)
  res <- filter_cases(cases, list(n_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, expected)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.5.1, 1.5.8: a single arm is a template for #", {
  cases <- c(three = "Z [# metre]{n=\"k3\"} z.", zero = "Z [# metre]{n=\"k0\"} z.")
  res <- filter_cases(cases, list(n_block()))
  expect_cases(res, c(three = "Z 3 metre z.", zero = "Z 0 metre z."))
})

test_that("1.5.12: an empty arm is written with a space between the separators", {
  cases <- c(file_one = "Z file[ | s]{n=\"k1\"} z.", file_many = "Z file[ | s]{n=\"k3\"} z.",
             file_zero = "Z file[ | s]{n=\"k0\"} z.", site_zero = "Z site[s | | s]{n=\"k0\"} z.",
             site_one = "Z site[s | | s]{n=\"k1\"} z.", site_three = "Z site[s | | s]{n=\"k3\"} z.")
  res <- filter_cases(cases, list(n_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(file_one = "Z file z.", file_many = "Z files z.", file_zero = "Z files z.",
                      site_zero = "Z sites z.", site_one = "Z site z.", site_three = "Z sites z."))
})

test_that("1.5.9, 1.5.18: the default class prints a whole number with no decimals, and selection sees it", {
  cases <- c(float_whole = "Z [# site | # sites]{n=\"kf\"} z.",
             float_whole_digits = "Z [# site | # sites]{n=\"kf\" digits=\"1\"} z.",
             float_not_whole = "Z [# site | # sites]{n=\"kh\"} z.",
             int_digits = "Z [# site | # sites]{n=\"k1\" digits=\"1\"} z.",
             thousands = "Z [# site | # sites]{n=\"k1234\"} z.",
             class_num_digits = "Z [# metre | # metres]{.num n=\"k3\" digits=\"1\"} z.")
  res <- filter_cases(cases, list(n_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(float_whole = "Z 1 site z.", float_whole_digits = "Z 1.0 sites z.",
                      float_not_whole = "Z 1.2 sites z.", int_digits = "Z 1.0 sites z.",
                      thousands = "Z 1,234 sites z.", class_num_digits = "Z 3.0 metres z."))
})

test_that("1.5.10, 2.6.11: an n governor that prints as zero records no warned check", {
  cases <- c(zero_print = "Z [# site | # sites]{n=\"kz\"} z.")
  res <- filter_cases(cases, list(n_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(zero_print = "Z 0.0 sites z."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.7.2: an inner span with n=\".\" agrees with the enclosing governor", {
  span <- "[# sample[ | s]{n=\".\"} [was | were]{n=\".\"} taken]{n=\"%s\"}"
  cases <- stats::setNames(sprintf("Z %s z.", vapply(c("k1", "k3", "k0"), function(k) sprintf(span, k), "")),
                           c("one", "three", "zero"))
  res <- filter_cases(cases, list(n_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(one = "Z 1 sample was taken z.", three = "Z 3 samples were taken z.",
                      zero = "Z 0 samples were taken z."))
})

test_that("1.5.12: a doubled # is the literal character and a single # the placeholder", {
  cases <- c(literal_one = "Z [## one | # many]{n=\"k1\"} z.", literal_many = "Z [## one | # many]{n=\"k3\"} z.",
             three_in_a_row = "Z [a ### b]{n=\"k1\"} z.")
  res <- filter_cases(cases, list(n_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(literal_one = "Z # one z.", literal_many = "Z 3 many z.", three_in_a_row = "Z a #1 b z."))
})

test_that("N12, E5: n takes a name, `.` or `#id`; a number literal or other text is a construct error", {
  bad <- c("3", "k1 + 1", "'x'")
  cases <- stats::setNames(sprintf("Z [# a | # b]{n=\"%s\"} z.", bad), paste0("n_", seq_along(bad)))
  res <- filter_cases(cases, list(n_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, " z."), length(bad)), names(cases)))
  for (b in bad) expect_true(grepl(fm_msg$E5(b, "n"), res$stderr, fixed = TRUE), label = paste("E5 for", b))
})

test_that("1.3.4, 1.12.6: a governor that is missing, or not published above, is no value", {
  cases <- c(missing = "Z [# a | # b]{n=\"miss\"} z.", unpublished = "Z [# a | # b]{n=\"nothere\"} z.")
  res <- filter_cases(cases, list(n_block()), draft = TRUE)
  expect_cases(res, c(missing = paste0("Z ", NV, " z."), unpublished = paste0("Z ", NV, " z.")))
  expect_true(grepl(fm_msg$E11("miss", "not counted"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E10("nothere"), res$stderr, fixed = TRUE))
})

test_that("1.5.2, 1.6: a wrong arm count for n is a construct error", {
  cases <- c(five = "Z [a | b | c | d | e]{n=\"k1\"} z.")
  res <- filter_cases(cases, list(n_block()), draft = TRUE)
  expect_cases(res, c(five = paste0("Z ", CE, " z.")))
})
