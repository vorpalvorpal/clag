# Package 6f: the `sign` and `list` governors, and `n` with .range, in the filter (dev/design-6.md N12, N83,
# N100; rules 1.5.1 to 1.5.3, 1.5.7, 1.5.8, 1.5.10, 1.5.11, 1.5.17, 1.5.19, 1.7.2). One document of many
# cases per test, through plain Pandoc (helper-filter.R). The arm-by-arm tables are governors.tsv's, run by
# test-lua-words.R; here are the rule examples and the failures.
#
# Left out, because the design is silent (see the report's "Spec gaps"): the kind of failure for a `sign`
# or `list` governor of the wrong kind of value (a string for `sign`), and `list` over a logical vector.

CE <- "<<weft: construct error, line {L}>>"
VE <- "<<weft: value error, line {L}>>"
NV <- "<<weft: no value, line {L}>>"

sl_block <- function() {
  carrier(
    dpos = fr_float("0.12"), dneg = fr_float("-0.12"), dzero = fr_float("0"), dtiny = fr_float("0.0004"),
    ipos = fr_int("5"), ineg = fr_int("-5"), ione = fr_int("1"), ineg2 = fr_int("-2"), izero = fr_int("0"),
    decneg = fr_dec("-0.5"), plo = fr_float("0.0004"), k3 = fr_int("3"),
    l0 = '{"t":"list","v":[],"of":"string","keys":null}', l1 = fr_list_str("a"), l2 = fr_list_str(c("a", "b")),
    l3 = fr_list_str(c("a", "b", "c")), l4 = fr_list_str(c("a", "b", "c", "d")),
    lna = '{"t":"list","v":[{"t":"string","v":"a"},{"t":"missing","why":"NA"}],"of":"string","keys":null}',
    r35 = fr_list_int(c("3", "5")), r11 = fr_list_int(c("1", "1")),
    s1 = fr_str("north"), miss = fr_missing("not counted")
  )
}

# ---- sign (1.5.1, 1.5.7, 1.5.8, 1.5.10) ----------------------------------------------------------------

test_that("1.5.1, 1.5.8: sign picks positive or negative, and # is the magnitude as printed, without its sign", {
  tbl <- list(
    pos = c("[rose by # | fell by #]{.pct sign=\"dpos\"}", "rose by 12%"),
    neg = c("[rose by # | fell by #]{.pct sign=\"dneg\"}", "fell by 12%"),
    int_pos = c("[up # | down #]{sign=\"ipos\"}", "up 5"), int_neg = c("[up # | down #]{sign=\"ineg\"}", "down 5"),
    decimal_neg = c("[up # | down #]{sign=\"decneg\"}", "down 0.5"),
    digits = c("[up # | down #]{digits=\"2\" sign=\"dneg\"}", "down 0.12"),
    point_one = c("[rose by # point[ | s]{n=\".\"} | fell by # point[ | s]{n=\".\"}]{sign=\"ione\"}", "rose by 1 point"),
    point_neg = c("[rose by # point[ | s]{n=\".\"} | fell by # point[ | s]{n=\".\"}]{sign=\"ineg2\"}", "fell by 2 points"),
    point_five = c("[rose by # point[ | s]{n=\".\"} | fell by # point[ | s]{n=\".\"}]{sign=\"ipos\"}", "rose by 5 points"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(sl_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.5.10: sign judges zero on the number as printed", {
  tbl <- list(
    zero_int = c("[rose by # | fell by # | did not change]{sign=\"izero\"}", "did not change"),
    zero_raw = c("[rose by # | fell by # | did not change]{.pct sign=\"dzero\"}", "did not change"),
    tiny_pct = c("[rose by # | fell by # | did not change]{.pct sign=\"dtiny\"}", "did not change"),
    tiny_default = c("[rose by # | fell by # | did not change]{sign=\"dtiny\"}", "did not change"),
    tiny_digits2 = c("[rose by # | fell by # | did not change]{.pct digits=\"2\" sign=\"dtiny\"}", "rose by 0.04%"),
    pos_three_arms = c("[rose by # | fell by # | did not change]{.pct sign=\"dpos\"}", "rose by 12%"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(sl_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
  expect_false(grepl("weft:", res$stderr, fixed = TRUE), label = "a governor that prints as zero records no warned check")
})

test_that("1.5.3: a two-arm sign whose value prints as zero is a failed claim", {
  res <- filter_cases(c(zero = "Z [rose by # | fell by #]{sign=\"izero\"} z."), list(sl_block()), draft = TRUE)
  expect_true(any(grepl(rx_claims(1), fm_headings(res$stderr))), label = "one failed claim in the report")
})

test_that("1.5.17: a sign governor that prints as a bound is a failure, not an arm", {
  res <- filter_cases(c(bound = "Z [rose to # | fell to #]{.p sign=\"plo\"} z."), list(sl_block()), draft = TRUE)
  expect_false(grepl("rose to|fell to", res$got["bound"]), label = "no arm is printed")
  expect_true(grepl("weft:", res$got["bound"], fixed = TRUE), label = "a marker stands in its place")
  expect_gte(length(fm_headings(res$stderr)), 1L)
})

test_that("1.5.1, 1.5.2: sign takes two or three arms; any other count is a construct error", {
  cases <- c(one = "Z [rose by #]{sign=\"dpos\"} z.", four = "Z [a | b | c | d]{sign=\"dpos\"} z.",
             two = "Z [rose | fell]{sign=\"dpos\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, c(one = paste0("Z ", CE, " z."), four = paste0("Z ", CE, " z."), two = "Z rose z."))
})

test_that("1.3.4, 1.12.6: a sign or list governor that is missing, or not published above, is no value", {
  cases <- c(sign_miss = "Z [up | down]{sign=\"miss\"} z.", sign_none = "Z [up | down]{sign=\"nothere\"} z.",
             list_miss = "Z [none | # was | # were]{list=\"miss\"} z.",
             list_none = "Z [none | # was | # were]{list=\"nothere\"} z.",
             list_na_element = "Z [none | # was | # were]{list=\"lna\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", NV, " z."), length(cases)), names(cases)))
  expect_true(grepl(fm_msg$E11("miss", "not counted"), res$stderr, fixed = TRUE))
  # N94, E42: a name published nowhere has the detail of E42
  expect_true(grepl(f7_msg$E42("nothere"), res$stderr, fixed = TRUE))
})

# ---- N12, E5 -------------------------------------------------------------------------------------------

test_that("N12, E5: sign takes a name or #id, list takes a name; any other text is a construct error", {
  bad_sign <- c("3", "dpos + 1", "'x'", ".")
  bad_list <- c("3", "l1 + 1", "'x'", ".")
  cases <- c(stats::setNames(sprintf("Z [a | b]{sign=\"%s\"} z.", bad_sign), paste0("sign_", seq_along(bad_sign))),
             stats::setNames(sprintf("Z [none | # a | # b]{list=\"%s\"} z.", bad_list), paste0("list_", seq_along(bad_list))))
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, " z."), length(cases)), names(cases)))
  for (b in bad_sign) expect_true(grepl(fm_msg$E5(b, "sign"), res$stderr, fixed = TRUE), label = paste("E5 sign", b))
  for (b in bad_list) expect_true(grepl(fm_msg$E5(b, "list"), res$stderr, fixed = TRUE), label = paste("E5 list", b))
})

test_that("1.1.5: a span with two governor keys is one construct, with a construct error", {
  cases <- c(n_sign = "Z [a | b]{n=\"k3\" sign=\"dpos\"} z.", list_n = "Z [none | a | b]{list=\"l2\" n=\"k3\"} z.",
             sign_list = "Z [a | b | c]{sign=\"dpos\" list=\"l2\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  # which of its keys N89 searches for to give the line is not fixed for a span with two, so the line is not
  for (nm in names(cases)) {
    expect_match(res$got[nm], "^Z <<weft: construct error(, line [0-9]+)?>> z\\.$", label = nm)
  }
})

# ---- list (1.5.1, 1.5.19) ------------------------------------------------------------------------------

test_that("1.5.19: a list span picks its arm by the length of the vector and # is the vector collapsed as .and does", {
  span <- "[No sites were | # was | # were]{list=\"%s\"}"
  cases <- stats::setNames(sprintf("Z %s flagged.", vapply(c("l0", "l1", "l2", "l3", "l4"), function(k) sprintf(span, k), "")),
                           c("zero", "one", "two", "three", "four"))
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(zero = "Z No sites were flagged.", one = "Z a was flagged.", two = "Z a and b were flagged.",
                      three = "Z a, b and c were flagged.", four = "Z a, b, c and d were flagged."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.5.19: four arms are zero, one, two and other; the inner n=\".\" counts the vector", {
  cases <- c(k0 = "Z [none | one: # | two: # | several: #]{list=\"l0\"} z.", k1 = "Z [none | one: # | two: # | several: #]{list=\"l1\"} z.",
             k2 = "Z [none | one: # | two: # | several: #]{list=\"l2\"} z.", k3 = "Z [none | one: # | two: # | several: #]{list=\"l3\"} z.",
             inner0 = "Z [none | # was | [# site | # sites]{n=\".\"}: #]{list=\"l0\"} z.",
             inner1 = "Z [none | # was | [# site | # sites]{n=\".\"}: #]{list=\"l1\"} z.",
             inner3 = "Z [none | # was | [# site | # sites]{n=\".\"}: #]{list=\"l3\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, c(k0 = "Z none z.", k1 = "Z one: a z.", k2 = "Z two: a and b z.", k3 = "Z several: a, b and c z.",
                      inner0 = "Z none z.", inner1 = "Z a was z.", inner3 = "Z 3 sites: a, b and c z."))
})

test_that("1.5.19: classes and keys on a list span act on #", {
  cases <- c(or = "Z [none | # was | # were]{.or list=\"l3\"} z.", trunc = "Z [none | # was | # were]{trunc=\"1\" list=\"l3\"} z.",
             sep = "Z [none | # was | # were]{sep=\"; \" list=\"l3\"} z.", last = "Z [none | # was | # were]{last=\"/\" list=\"l2\"} z.",
             cap = "Z [none | # was | # were]{.cap list=\"l2\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, c(or = "Z a, b or c were z.", trunc = "Z a and 2 others were z.", sep = "Z a; b and c were z.",
                      last = "Z a/b were z.", cap = "Z A and b were z."))
})

test_that("1.5.3, 1.5.19: an empty vector with no zero arm is a failed claim that says to add a first arm", {
  res <- filter_cases(c(two_arm = "Z [# was | # were]{list=\"l0\"} z."), list(sl_block()), draft = TRUE)
  expect_true(any(grepl(rx_claims(1), fm_headings(res$stderr))), label = "one failed claim in the report")
  expect_true(grepl("first arm", res$stderr, fixed = TRUE), label = "the message says to add a first arm")
})

test_that("1.5.19, 1.7.5: a list span with one arm, # in its zero arm, an #id, a list class or a formatter is a construct error", {
  cases <- c(one_arm = "Z [# were]{list=\"l2\"} z.", hash_in_zero = "Z [none # | # was | # were]{list=\"l2\"} z.",
             id = "Z [none | # was | # were]{#x list=\"l2\"} z.", ul = "Z [none | # was | # were]{.ul list=\"l2\"} z.",
             ok = "Z [none | # was | # were]{list=\"l2\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, c(one_arm = paste0("Z ", CE, " z."), hash_in_zero = paste0("Z ", CE, " z."),
                      id = paste0("Z ", CE, " z."), ul = paste0("Z ", CE, " z."), ok = "Z a and b were z."))
})

test_that("1.5.19: a list governor may be a single value, which is a vector of length one", {
  res <- filter_cases(c(one = "Z [none | # was | # were]{list=\"s1\"} z."), list(sl_block()), draft = TRUE)
  expect_cases(res, c(one = "Z north was z."))
})

# ---- n with .range, and the single-number rule (1.5.11) ------------------------------------------------

test_that("1.5.11: n with .range takes a length-2 value; # is the range and the span is plural unless it prints 1", {
  cases <- c(range = "Z [# site | # sites]{.range n=\"r35\"} z.", collapsed_one = "Z [# site | # sites]{.range n=\"r11\"} z.",
             r35_one_arm = "Z [# metre]{.range n=\"r35\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, c(range = "Z 3\u20135 sites z.", collapsed_one = "Z 1 site z.", r35_one_arm = "Z 3\u20135 metre z."))
})

test_that("1.5.11: n must be a single number; a vector or a string is a failure that says to write length(x)", {
  cases <- c(vec = "Z [# a | # b]{n=\"l3\"} z.", str = "Z [# a | # b]{n=\"s1\"} z.", vec_range = "Z [# a | # b]{.range n=\"l3\"} z.")
  res <- filter_cases(cases, list(sl_block()), draft = TRUE)
  expect_cases(res, c(vec = paste0("Z ", VE, " z."), str = paste0("Z ", VE, " z."), vec_range = paste0("Z ", VE, " z.")))
  expect_true(grepl("length(", res$stderr, fixed = TRUE), label = "the message names length(x)")
})
