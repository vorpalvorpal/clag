# Package 6c: `if` spans in the filter (dev/design-6.md N9 to N11, N14, N82; rules 1.5.3 to 1.5.5, 1.5.12,
# 1.5.16, 1.5.20, 1.12.4). Each test is one document of many cases through plain Pandoc (helper-filter.R).
# Cases where the failure is expected run in draft mode (WEFT_DRAFT=1) so that the output is written.
# While inst/quarto/weft.lua does not exist every test fails on that.

CE <- "<<weft: construct error, line {L}>>"
VE <- "<<weft: value error, line {L}>>"
NV <- "<<weft: no value, line {L}>>"

if_block <- function() {
  carrier(
    a = fr_bool(TRUE), f = fr_bool(FALSE), n_gap = fr_int("12"), n_sites = fr_int("3"),
    s = fr_str("north"), sc = fr_str("a,b"),
    dA = fr_date("2026-01-02"), dB = fr_date("2026-01-03"), dB2 = fr_date("2026-01-03"),
    big = fr_int("9007199254740993"), big2 = fr_int("9007199254740992"),
    bigd = fr_dec("9007199254740993.0"), bigd2 = fr_dec("9007199254740992.0"),
    h2 = fr_dec("0.30"), h3 = fr_dec("0.3"), i5 = fr_int("5"), d5 = fr_dec("5.0"),
    x = fr_float("0.1"), f3 = fr_float("0.30000000000000004"), miss = fr_missing("not measured")
  )
}

if_case <- function(cond) sprintf("Z [yes | no]{if=\"%s\"}.", cond)

test_that("N9, N10: conditions on names, number and string literals, and commas, choose the arm", {
  truth <- c(
    "a" = TRUE, "f" = FALSE,
    "n_gap > 10" = TRUE, "n_gap>10" = TRUE, "n_gap >10" = TRUE, "n_gap >= 12" = TRUE, "n_gap>=12" = TRUE,
    "n_gap <= 11" = FALSE, "n_gap<=12" = TRUE, "n_gap < 12" = FALSE, "n_gap == 12" = TRUE,
    "n_gap != 12" = FALSE, "10 < n_gap" = TRUE, "n_gap > n_sites" = TRUE, "n_gap > -1" = TRUE,
    "n_gap < 1e2" = TRUE, "n_gap > 1.5E+1" = FALSE,
    "n_gap > 10, n_sites >= 3" = TRUE, "n_gap > 10, n_sites >= 4" = FALSE, "a, f" = FALSE,
    "a, a, a" = TRUE, "a , a" = TRUE, "sc == 'a,b'" = TRUE, "sc == 'a,b', n_gap > 1" = TRUE,
    "sc == 'a,b', n_gap > 100" = FALSE,
    "s == 'north'" = TRUE, "s != 'north'" = FALSE, "s == 'South'" = FALSE, "s != 'South'" = TRUE,
    "'north' == s" = TRUE,
    "dA < dB" = TRUE, "dB > dA" = TRUE, "dA >= dB" = FALSE, "dB == dB2" = TRUE, "dB <= dB2" = TRUE,
    "dA != dB" = TRUE,
    "big > big2" = TRUE, "big == big" = TRUE, "big == big2" = FALSE, "big == bigd" = TRUE,
    "big > bigd2" = TRUE, "big2 == bigd2" = TRUE, "big < bigd" = FALSE, "i5 == d5" = TRUE,
    "h2 == h3" = TRUE, "h2 < h3" = FALSE,
    "x == 0.1" = TRUE, "x < 0.1" = FALSE, "x >= 0.1" = TRUE, "f3 == 0.3" = FALSE, "f3 > 0.3" = TRUE
  )
  cases <- vapply(names(truth), if_case, "")
  expected <- ifelse(truth, "Z yes.", "Z no.")
  names(expected) <- names(truth)
  res <- filter_cases(cases, list(if_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, expected)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N10, N11, E3: a condition outside the grammar is a construct error quoting the part", {
  parts <- c("a && f", "a || f", "a & f", "a | f", "a and f", "a or f", "not a", "(a)",
             "n_gap + 1 > 5", "len(s) > 2", "s[1] == 'n'", "0 < n_gap < 20", "n_gap = 5", "n_gap <> 5",
             "n_gap == NA", "a == TRUE", "n_gap > Inf", "n_gap > +1", "n_gap > .5", "n_gap > 1_0",
             "n_gap > 0x10", "n_gap > 10L", "n_gap > 1.")
  empties <- c("a,,b", "a,", ",a")
  cases <- vapply(c(parts, empties), if_case, "")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, "."), length(cases)), names(cases)))
  for (p in parts) expect_true(grepl(fm_msg$E3(p), res$stderr, fixed = TRUE), label = paste("E3 for", p))
  expect_true(grepl(fm_msg$E3_tail, res$stderr, fixed = TRUE))
})

test_that("N11, E4: a literal compared with a literal is a construct error", {
  parts <- c("3 > 2", "'a' == 'a'", "1 == 1")
  cases <- vapply(parts, if_case, "")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, "."), length(cases)), names(cases)))
  for (p in parts) expect_true(grepl(fm_msg$E4(p), res$stderr, fixed = TRUE), label = paste("E4 for", p))
})

test_that("E18: a lone name must be a bool; any other kind is a value error", {
  tbl <- c(s = "string", dA = "date", x = "float", bigd = "decimal")
  cases <- vapply(names(tbl), if_case, "")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", VE, "."), length(cases)), names(cases)))
  for (nm in names(tbl)) {
    expect_true(grepl(fm_msg$E18(nm, tbl[[nm]]), res$stderr, fixed = TRUE), label = paste("E18 for", nm))
  }
})

test_that("E19: a comparison of unlike kinds, or an order on strings, is a value error", {
  kinds <- list(c("s == a", "string", "bool"), c("dA == s", "date", "string"),
                c("x == s", "float", "string"), c("a == 'x'", "bool", "string"))
  orders <- c("s < 'z'", "s >= sc", "'a' < s")
  cases <- vapply(c(vapply(kinds, `[`, "", 1L), orders), if_case, "")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", VE, "."), length(cases)), names(cases)))
  for (k in kinds) expect_true(grepl(fm_msg$E19(k[1], k[2], k[3]), res$stderr, fixed = TRUE), label = k[1])
  for (o in orders) expect_true(grepl(fm_msg$E19_order(o), res$stderr, fixed = TRUE), label = o)
})

test_that("E10, E11: an operand that is missing, or not published above, is no value", {
  cases <- c(missing = if_case("miss > 1"), unpublished = if_case("nothere > 1"), bool_unpublished = if_case("nothere"))
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", NV, "."), 3), names(cases)))
  expect_true(grepl(fm_msg$E11("miss", "not measured"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E10("nothere"), res$stderr, fixed = TRUE))
})

test_that("1.5.5: a one-arm guard always prints its phrase; a condition that is not true also fails", {
  g <- function(cond) sprintf("Council will need to [add more sampling sites]{if=\"%s\"}.", cond)
  cases <- c(holds = g("n_gap > 10"), both_hold = g("n_gap > 10, n_sites >= 3"), fails = g("n_gap > 100"),
             one_of_two_fails = g("n_sites >= 3, n_gap > 100"))
  ok <- "Council will need to add more sampling sites"
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(holds = paste0(ok, "."), both_hold = paste0(ok, "."),
                      fails = paste0(ok, "<<weft: failed claim, line {L}>>."),
                      one_of_two_fails = paste0(ok, "<<weft: failed claim, line {L}>>.")))
  expect_match(fm_headings(res$stderr), rx_claims(2), all = FALSE)
  expect_true(grepl("optional text is written [phrase | ]{if=\"", res$stderr, fixed = TRUE))
  expect_true(grepl("n_gap > 100", res$stderr, fixed = TRUE))
  # the failing guard is a failure in a render without draft mode
  res2 <- filter_md(fm_doc(cases[c("holds", "fails")], list(if_block()), character())$md, to = "plain")
  expect_identical(res2$status, 1L)
})

test_that("1.5.5: each condition of a guard that is not true is reported separately", {
  cases <- c(two = "Needs [more sites]{if=\"n_gap > 100, n_sites > 100\"}.")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_match(fm_headings(res$stderr), rx_claims(2), all = FALSE)
  expect_true(grepl("n_gap > 100", res$stderr, fixed = TRUE))
  expect_true(grepl("n_sites > 100", res$stderr, fixed = TRUE))
})

test_that("1.5.5: a phrase with an empty second arm is optional text and fails nothing", {
  cases <- c(absent = "Sampling was complete[, apart from the estuary sites | ]{if=\"f\"}.",
             present = "Sampling was complete[, apart from the estuary sites | ]{if=\"a\"}.")
  res <- filter_cases(cases, list(if_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(absent = "Sampling was complete.", present = "Sampling was complete, apart from the estuary sites."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.5.12: arms are trimmed, and || and \\| read as the literal bar", {
  cases <- c(trimmed = "Z [ yes | no ]{if=\"a\"}.", bar = "Z [a||b | c]{if=\"a\"}.",
             bar_false = "Z [a||b | c]{if=\"f\"}.", bar_as_pandoc_saves_it = "Z [a\\|\\|b \\| c]{if=\"a\"}.",
             bar_then_separator = "Z [a||| c]{if=\"a\"}.")
  res <- filter_cases(cases, list(if_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(trimmed = "Z yes.", bar = "Z a|b.", bar_false = "Z c.",
                      bar_as_pandoc_saves_it = "Z a|b.", bar_then_separator = "Z a|."))
})

test_that("1.5.20: one space beside a governed span that prints nothing is removed (the spec's cases)", {
  e <- "[x | ]{if=\"f\"}"
  em <- "\u2014"
  cases <- c(
    both_sides = paste0("a ", e, " b"), before_full_stop = paste0("fell [sharply | ]{if=\"f\"}."),
    block_start = paste0(e, " rest"), list_item = paste0("- ", e, " item"), block_end = paste0("end ", e),
    before_comma = paste0("x ", e, ", z"), before_semicolon = paste0("x ", e, "; z"),
    before_colon = paste0("x ", e, ": z"), before_bang = paste0("x ", e, "! z"),
    before_question = paste0("x ", e, "? z"), before_paren = paste0("(x ", e, ") z"),
    before_right_quote = paste0("said ", e, "\u201d"), before_right_single = paste0("said ", e, "\u2019"),
    before_em_dash = paste0("w ", e, em, "z"),
    touching_both = paste0("a", e, "b"), space_before_only = paste0("a ", e, "b"),
    space_after_only = paste0("a", e, " b"), line_breaks = paste0("a\n", e, "\nb"),
    prints_something = "a [x | y]{if=\"f\"} b",
    chain_one_prints = "A: [x|]{if=\"f\"}[q|]{if=\"f\"}[y|]{if=\"a\"}.",
    chain_nothing_prints = "B [x|]{if=\"f\"}[q|]{if=\"f\"} c",
    chain_keeps_spaces = "C [x|]{if=\"a\"}[q|]{if=\"f\"} d"
  )
  res <- filter_cases(cases, list(if_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(
    both_sides = "a b", before_full_stop = "fell.", block_start = "rest", list_item = "- item",
    block_end = "end", before_comma = "x, z", before_semicolon = "x; z", before_colon = "x: z",
    before_bang = "x! z", before_question = "x? z", before_paren = "(x) z",
    before_right_quote = "said\u201d", before_right_single = "said\u2019", before_em_dash = paste0("w", em, "z"),
    touching_both = "ab", space_before_only = "a b", space_after_only = "a b", line_breaks = "a b",
    prints_something = "a y b", chain_one_prints = "A: y.", chain_nothing_prints = "B c",
    chain_keeps_spaces = "C x d"
  ))
})

test_that("1.5.15, 1.5.16: a named value in the chosen arm prints; one in an arm not chosen is never read", {
  cases <- c(chosen = "Z [`n_gap`{.num} gaps | none]{if=\"a\"}.",
             unchosen_first = "Z [x | `nothere`{.num}]{if=\"a\"}.",
             unchosen_second = "Z [`nothere`{.num} | y]{if=\"f\"}.")
  res <- filter_cases(cases, list(if_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(chosen = "Z 12 gaps.", unchosen_first = "Z x.", unchosen_second = "Z y."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.5.15: a missing named value in the chosen arm is no value, in place of that value", {
  cases <- c(chosen = "Z [`nothere`{.num} | y]{if=\"a\"}.")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, c(chosen = paste0("Z ", NV, ".")))
  expect_true(grepl(fm_msg$E10("nothere"), res$stderr, fixed = TRUE))
})

test_that("1.5.2: an if span with three arms is a construct error", {
  cases <- c(three = "Z [a | b | c]{if=\"a\"}.")
  res <- filter_cases(cases, list(if_block()), draft = TRUE)
  expect_cases(res, c(three = paste0("Z ", CE, ".")))
})
