# Stage 7b, F1 in the filter: `.plus` on named values (dev/design-7.md section 2.A, N1 to N8, N13, N14;
# the messages E1 and E2 of section 7). The filter must print what R prints, so the expected texts are the
# design's own examples and the committed conformance rows (numbers.tsv, collapse.tsv, text.tsv), read
# through the whole filter (helper-6f.R, f6_rows()). Whole-document cases cover the class, the way it goes
# with the others, the construct errors and weft-check.lua. ASCII only (the minus is U+2212, written
# as an escape). `ci()` has no filter side (N13).
#
# Left out, because a named value's record schema does not say how to write them: a quantity (`u(5, m)`,
# N2 and N5, unit before the number) and a clamp relation (`> +99`); and the E1 on a project formatter,
# which the filter cannot know (it is an R function: E21 of design-6 applies there).

PM <- "−"
PE1 <- function(cls) {
  sprintf("`.plus` cannot go with `%s`: it signs a number that `.num` or `.pct` prints (rule 1.4.21).", cls)
}
PE2 <- function(key) sprintf("`.plus` does not apply to a span with `%s=` (rule 1.4.21).", key)
PCE <- "<<weft: construct error, line {L}>>"
PVE <- "<<weft: value error, line {L}>>"

plus_block <- function() {
  carrier(
    pos = fr_float("1.25"), neg = fr_float("-1.25"), zero = fr_float("0"), negzero = fr_float("-0"),
    small = fr_float("0.04"), negsmall = fr_float("-0.04"), tiny = fr_float("1e-10"),
    big = fr_float("1234.5"), near1 = fr_float("0.999"), eight = fr_float("8"), twelve = fr_int("12"),
    pct = fr_float("0.12"), negpct = fr_float("-0.12"), pctsmall = fr_float("0.004"), pctzero = fr_float("0"),
    r_pos = fr_list_float(c("1.2", "3.4")), r_mix = fr_list_float(c("-0.5", "1.2")),
    r_zero = fr_list_float(c("0", "1.2")), r_same = fr_list_float(c("1.2", "1.2")),
    r_neg = fr_list_float(c("-3", "-1")), r_zz = fr_list_float(c("0", "0")),
    l_mix = fr_list_float(c("1.2", "-3.4", "5.6")), l_two = fr_list_float(c("1.2", "3.4")),
    word = fr_str("north"), p = fr_float("0.04"), dt = fr_date("2024-06-03"), flag = fr_bool(TRUE),
    k = fr_int("3"), v3 = fr_list_int(c("1", "2", "3"))
  )
}

# ---- N2 to N4: one number ---------------------------------------------------------------------------

test_that("N2: a number above zero prints with + where the minus would stand", {
  tbl <- list(pos = c("`pos`{.num .plus}", "+1.3"), big = c("`big`{.num .plus}", "+1,234.5"),
              eight = c("`eight`{.num .plus}", "+8"), int = c("`twelve`{.num .plus}", "+12"),
              near1 = c("`near1`{.num .plus digits=\"2\"}", "+1.00"),
              d2 = c("`pos`{.num .plus digits=\"2\"}", "+1.25"), sf2 = c("`pos`{.num .plus sigfig=\"2\"}", "+1.3"),
              pct = c("`pct`{.pct .plus}", "+12%"), pctsmall = c("`pctsmall`{.pct .plus}", "+0.4%"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
})

test_that("N3: zero, minus zero and a value below 1e-9 have no sign; 0.04 prints 0.0 with no sign", {
  tbl <- list(zero = c("`zero`{.num .plus}", "0"), negzero = c("`negzero`{.num .plus}", "0"),
              tiny = c("`tiny`{.num .plus}", "0"), small = c("`small`{.num .plus}", "0.0"),
              negsmall = c("`negsmall`{.num .plus}", "0.0"), pctzero = c("`pctzero`{.pct .plus}", "0%"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("N3: 0.04 under .plus records the printed-as-zero warned check, as without .plus", {
  blk <- plus_block()
  for (cls in c("{.num .plus}", "{.num}")) {
    res <- filter_md(c(blk, "", paste0("A `small`", cls, " z.")), to = "plain")
    expect_identical(res$status, 0L, label = cls)
    expect_identical(trimws(res$output), "A 0.0 z.", label = cls)
    expect_match(fm_headings(res$stderr), rx_warned(1), all = FALSE)
    expect_true(grepl("0.04 printed as 0.0: add sigfig to show it, or digits to confirm it", res$stderr,
                      fixed = TRUE), label = cls)
  }
  # a value that prints as nonzero under .plus warns nothing
  res <- filter_md(c(blk, "", "A `pos`{.num .plus} z."), to = "plain")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N4: a negative number prints the minus setting, unchanged; the setting applies", {
  tbl <- list(neg = c("`neg`{.num .plus}", paste0(PM, "1.3")), negpct = c("`negpct`{.pct .plus}", paste0(PM, "12%")),
              ctl = c("`neg`{.num}", paste0(PM, "1.3")))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
  res2 <- filter_cases(c(neg = "A `neg`{.num .plus} z.", pos = "A `pos`{.num .plus} z."), list(plus_block()),
                       draft = TRUE, weft_yml = "minus: \"-\"")
  expect_cases(res2, c(neg = "A -1.3 z.", pos = "A +1.3 z."))
})

# ---- N1: how the class goes with the others ---------------------------------------------------------

test_that("N1: .plus alone implies .num, the order of classes does not matter, .pct goes with it", {
  tbl <- list(alone = c("`pos`{.plus}", "+1.3"), negalone = c("`neg`{.plus}", paste0(PM, "1.3")),
              swapped = c("`pos`{.plus .num}", "+1.3"), withd = c("`pos`{.plus digits=\"2\"}", "+1.25"),
              pct = c("`pos`{.plus .pct}", "+125%"), pct2 = c("`pct`{.pct .plus}", "+12%"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("N1: .plus goes with .strong, .em and .cap", {
  res <- f6_cases_html(c(strong = "A `pos`{.num .plus .strong} z.", em = "A `pos`{.num .plus .em} z.",
                         both = "A `pct`{.plus .pct .strong} z."), list(plus_block()))
  want <- f6_want_html(c(strong = "A **+1.3** z.", em = "A *+1.3* z.", both = "A **+12%** z."))
  expect_identical(res$status, 0L)
  for (nm in names(want)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
})

test_that("N1: each element of a list under a collapse class is signed before the collapse", {
  tbl <- list(and = c("`l_mix`{.and .plus}", paste0("+1.2, ", PM, "3.4 and +5.6")),
              or = c("`l_two`{.or .plus}", "+1.2 or +3.4"), ctl = c("`l_two`{.and}", "1.2 and 3.4"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

# ---- N6: .range -------------------------------------------------------------------------------------

test_that("N6: .range with .plus signs the ends and joins with ' to ' when an end has a sign", {
  tbl <- list(pos = c("`r_pos`{.range .plus}", "+1.2 to +3.4"), mix = c("`r_mix`{.range .plus}", paste0(PM, "0.5 to +1.2")),
              zero = c("`r_zero`{.range .plus}", "0.0 to +1.2"), same = c("`r_same`{.range .plus}", "+1.2"),
              neg = c("`r_neg`{.range .plus}", paste0(PM, "3 to ", PM, "1")), zz = c("`r_zz`{.range .plus}", "0"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("N6: without .plus a range is unchanged (control: en dash, and ' to ' only for a negative end)", {
  tbl <- list(pos = c("`r_pos`{.range}", "1.2–3.4"), zero = c("`r_zero`{.range}", "0.0–1.2"),
              neg = c("`r_neg`{.range}", paste0(PM, "3 to ", PM, "1")), same = c("`r_same`{.range}", "1.2"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

# ---- N7: .a -----------------------------------------------------------------------------------------

test_that("N7: .a reads a leading + as it reads a minus", {
  tbl <- list(plus = c("`eight`{.num .plus .a}", "a +8"), ctl = c("`eight`{.num .a}", "an 8"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(plus_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

# ---- N8: construct errors ---------------------------------------------------------------------------

test_that("E1: .plus with .sci, .p, .date, .no, .word, .count, .ord or .val is a construct error with R's text", {
  cls <- c(".sci", ".p", ".date", ".no", ".word", ".count", ".ord", ".val")
  rec <- function(cl) switch(cl, .date = "dt", .val = "word", .p = "p", "k")
  cases <- stats::setNames(sprintf("A `%s`{%s .plus} z.", vapply(cls, rec, ""), cls), sub("^\\.", "e1_", cls))
  res <- filter_cases(cases, list(plus_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("A ", PCE, " z."), length(cls)), names(cases)))
  for (cl in cls) {
    expect_true(grepl(PE1(cl), res$stderr, fixed = TRUE), label = PE1(cl))
  }
})

test_that("E1: the order of the classes does not matter, and .num or .pct with the conflicting class is the same error", {
  cases <- c(first = "A `k`{.plus .word} z.", num = "A `k`{.num .plus .sci} z.", pct = "A `pct`{.pct .plus .p} z.")
  res <- filter_cases(cases, list(plus_block()), draft = TRUE)
  expect_cases(res, c(first = paste0("A ", PCE, " z."), num = paste0("A ", PCE, " z."), pct = paste0("A ", PCE, " z.")))
  expect_true(grepl(PE1(".word"), res$stderr, fixed = TRUE))
  expect_true(grepl(PE1(".sci"), res$stderr, fixed = TRUE))
})

test_that("E1: the conflicting class without .plus is not an error (control)", {
  res <- filter_cases(c(word = "A `k`{.word} z.", p = "A `p`{.p} z.", sci = "A `big`{.sci} z."),
                      list(plus_block()), draft = TRUE)
  expect_cases(res, c(word = "A three z.", p = "A p = 0.040 z.", sci = "A 1.2 × 10³ z."))
  expect_false(grepl("cannot go with", res$stderr, fixed = TRUE))
})

test_that("E2: .plus on a span with n, if, sign, list or cite is a construct error with R's text", {
  cases <- c(n = "A [# site | # sites]{.plus n=\"k\"} z.",
             `if` = "A [yes | no]{.plus if=\"flag\"} z.",
             sign = "A [rose by # | fell by # | flat]{.pct .plus sign=\"pct\"} z.",
             list = "A [none | # | both # | all #]{.plus list=\"v3\"} z.",
             cite = "A [10 m]{.plus cite=\"@smith2020\"} z.")
  res <- f6_cases_html(cases, list(plus_block()))
  expect_identical(length(res$got), length(cases))
  for (key in names(cases)) {
    expect_true(grepl("weft: construct error", res$got[[key]], fixed = TRUE), label = paste("marker for", key))
    expect_true(grepl(PE2(key), res$stderr, fixed = TRUE), label = PE2(key))
  }
})

test_that("E2: the same governor spans without .plus are not an error (control)", {
  cases <- c(n = "A [# site | # sites]{n=\"k\"} z.", `if` = "A [yes | no]{if=\"flag\"} z.")
  res <- f6_cases_html(cases, list(plus_block()))
  expect_identical(res$status, 0L)
  expect_false(grepl("does not apply to a span", res$stderr, fixed = TRUE))
  expect_match(res$got[["n"]], "3 sites", fixed = TRUE)
  expect_match(res$got[["if"]], "yes", fixed = TRUE)
})

test_that("N8: .plus on a value that is no number is a value error, never a pass-through", {
  res <- filter_cases(c(str = "A `word`{.num .plus} z.", date = "A `dt`{.num .plus} z.", bool = "A `flag`{.plus} z."),
                      list(plus_block()), draft = TRUE)
  expect_cases(res, c(str = paste0("A ", PVE, " z."), date = paste0("A ", PVE, " z."), bool = paste0("A ", PVE, " z.")))
})

# ---- weft-check.lua ---------------------------------------------------------------------------------

test_that("N13: weft-check.lua knows .plus: a named value left unresolved under .plus is reported", {
  for (md in c("Change `d`{.plus} m.", "Change `d`{.num .plus} m.", "Change `d`{.range .plus} m.")) {
    res <- filter_md(md, filters = "weft-check.lua")
    expect_identical(res$status, 1L, label = md)
    expect_true(grepl(fm_msg$E35, res$stderr, fixed = TRUE), label = md)
  }
  # not a name: the old text, naming .plus
  res <- filter_md("Change `d + 1`{.plus} m.", filters = "weft-check.lua")
  expect_identical(res$status, 1L)
  expect_true(grepl("a code span carries the weft class `.plus`", res$stderr, fixed = TRUE))
})

test_that("N13: after weft.lua no .plus is left over, and the whole run reports nothing", {
  res <- filter_md(c(plus_block(), "", "A `pos`{.plus} and `r_pos`{.range .plus} z."), to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "A +1.3 and +1.2 to +3.4 z.")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

# ---- N14: the committed conformance rows, through the filter -------------------------------------------

plus_rows <- function(set, classes) {
  d <- f6_read(set)
  d[d$classes %in% classes, , drop = FALSE]
}

test_that("N14: every `num plus` and `pct plus` row of numbers.tsv prints what R printed", {
  d <- plus_rows("numbers", c("num plus", "pct plus"))
  expect_identical(sum(d$classes == "num plus"), 9L)
  expect_identical(sum(d$classes == "pct plus"), 10L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "numbers.tsv plus")
})

test_that("N14: every `range plus` row of collapse.tsv prints what R printed", {
  d <- plus_rows("collapse", "range plus")
  expect_identical(nrow(d), 9L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "collapse.tsv range plus")
})

test_that("N14: every `num plus a` row of text.tsv prints what R printed", {
  d <- plus_rows("text", "num plus a")
  expect_identical(nrow(d), 8L)
  r <- f6_rows(d)
  f6_expect_rows(d, r, "text.tsv num plus a")
})

test_that("N14: the rows without plus are still what R printed (control: .plus touches no unsigned construct)", {
  for (set in c("numbers", "collapse", "text")) {
    d <- f6_read(set)
    has_plus <- vapply(strsplit(d$classes, " ", fixed = TRUE), function(t) "plus" %in% t, NA)
    d <- d[!has_plus & d$classes %in% c("num", "pct", "range", "a"), , drop = FALSE]
    expect_gt(nrow(d), 0L)
    d <- utils::head(d, 60L)
    r <- f6_rows(d)
    f6_expect_rows(d, r, paste(set, "without plus"))
  }
})
