# Package 6f: the remaining classes in the filter (dev/design-6.md N83, N100; rules 1.4.1 to 1.4.17, 1.1.9,
# 1.6.8, 1.12.2). One document of many cases per test, through plain Pandoc (helper-filter.R). The big
# tables of values are test-lua-words.R's; here are each class's rule examples and its failures.
#
# Expected texts come from the rules' own examples or, where a configuration changes what R prints, from
# R's formatter under that configuration (helper-6f.R, f6_r_text()). Text that is markdown (a superscript,
# bold) is compared as Pandoc reads it (f6_want_html()).
#
# Left out, because the design is silent (see the report's "Spec gaps"): the kind of failure and the message
# for `.p` outside 0 to 1, for `.pairs` on a list with no keys, for `.a` on text that is no number word, and
# for `.em` together with `.strong`.

CE <- "<<weft: construct error, line {L}>>"
VE <- "<<weft: value error, line {L}>>"
NV <- "<<weft: no value, line {L}>>"
MINUS <- "\u2212"

cls_block <- function() {
  carrier(
    p46 = fr_float("0.046"), p4 = fr_float("0.004"), p50 = fr_float("0.05"), p10 = fr_float("0.1"),
    p20 = fr_float("0.2"), plo = fr_float("0.0004"), phi = fr_float("0.995"), p12 = fr_float("0.1234"),
    p001 = fr_float("0.001"), p99 = fr_float("0.99"), pdec = fr_dec("0.046"), pint0 = fr_int("0"),
    pint1 = fr_int("1"),
    dt = fr_date("2026-11-13"), dt2 = fr_date("2024-03-05"),
    i1 = fr_int("1234567"), i3 = fr_int("3"), i2 = fr_int("2"), ineg = fr_int("-3"), i0 = fr_int("0"),
    i11 = fr_int("11"), f15 = fr_float("1.5"), f2 = fr_float("2.0000000001"), d25 = fr_dec("2.5"),
    f1 = fr_float("3.14159"), fsmall = fr_float("1.5e-7"), fbig = fr_float("12345"), fneg = fr_float("-2500"),
    s1 = fr_str("north"), b1 = fr_bool(TRUE), l1 = fr_list_int(c("1", "2", "3")),
    lab = fr_list_str(c("a", "b")), labc = fr_list_str(c("a", "b", "c")),
    lnone = '{"t":"list","v":[],"of":"string","keys":null}',
    r35 = fr_list_int(c("3", "5")), rneg = fr_list_int(c("-5", "-3")), r53 = fr_list_int(c("5", "3")),
    r123 = fr_list_int(c("1", "2", "3")), r1 = fr_list_int("1"), r55 = fr_list_int(c("5", "5")), rsmall = fr_list_float(c("0.03", "0.04")),
    rbad = fr_list_float(c("0.04", "0.03")),
    pairs = '{"t":"list","v":[{"t":"float","v":"1.2"},{"t":"float","v":"3.4"},{"t":"float","v":"5.6"}],"of":"float","keys":["A","B","C"]}',
    dl = '{"t":"list","v":[{"t":"string","v":"x"},{"t":"string","v":"y"}],"of":"string","keys":["a","b"]}',
    lnum = fr_list_float(c("1.5", "2")), lstr = fr_list_str(c("a", "b"))
  )
}

# ---- .p (1.4.3, 1.4.17) -------------------------------------------------------------------------------

test_that("1.4.17: .p prints p < 0.001, p > 0.99, three decimals below 0.1 and two from there", {
  tbl <- list(
    p46 = c("`p46`{.p}", "p = 0.046"), p4 = c("`p4`{.p}", "p = 0.004"), p50 = c("`p50`{.p}", "p = 0.050"),
    p10 = c("`p10`{.p}", "p = 0.10"), p20 = c("`p20`{.p}", "p = 0.20"), p12 = c("`p12`{.p}", "p = 0.12"),
    plo = c("`plo`{.p}", "p < 0.001"), phi = c("`phi`{.p}", "p > 0.99"), p001 = c("`p001`{.p}", "p = 0.001"),
    p99 = c("`p99`{.p}", "p = 0.99"), pdec = c("`pdec`{.p}", "p = 0.046"), pint0 = c("`pint0`{.p}", "p < 0.001"),
    pint1 = c("`pint1`{.p}", "p > 0.99"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.4.3, E17: .p, .sci and .date need a number or a date, and name what they got", {
  tbl <- list(p_str = c("`s1`{.p}", VE), p_bool = c("`b1`{.p}", VE), p_date = c("`dt`{.p}", VE),
              sci_str = c("`s1`{.sci}", VE), sci_bool = c("`b1`{.sci}", VE), sci_date = c("`dt`{.sci}", VE),
              sci_list = c("`l1`{.sci}", VE), date_int = c("`i1`{.date}", VE), date_str = c("`s1`{.date}", VE),
              date_float = c("`f1`{.date}", VE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
  msgs <- c(fm_msg$E17("p", "number", "s1", "string"), fm_msg$E17("p", "number", "b1", "bool"),
            fm_msg$E17("p", "number", "dt", "date"), fm_msg$E17("sci", "number", "s1", "string"),
            fm_msg$E17("sci", "number", "l1", "list"), fm_msg$E17("date", "date", "i1", "integer"),
            fm_msg$E17("date", "date", "s1", "string"), fm_msg$E17("date", "date", "f1", "float"))
  for (m in msgs) expect_true(grepl(m, res$stderr, fixed = TRUE), label = m)
})

# ---- .sci and .date (1.4.3, 1.6.8, N100) ---------------------------------------------------------------

test_that("N84, 1.4.18: .sci and .p use the decimal mark and the minus of the configuration", {
  cases <- c(sci_comma = "A `fbig`{.sci} z.", sci_minus = "A `fsmall`{.sci} z.", sci_neg = "A `fneg`{.sci} z.",
             p_comma = "A `p46`{.p} z.")
  res <- f6_cases_html(cases, list(cls_block()), weft_yml = c("decimal_mark: \",\"", "minus: \"-\""))
  texts <- c(f6_r_text(12345, ".sci", cfg = list(decimal_mark = ",", minus = "-")),
             f6_r_text(1.5e-7, ".sci", cfg = list(decimal_mark = ",", minus = "-")),
             f6_r_text(-2500, ".sci", cfg = list(decimal_mark = ",", minus = "-")),
             f6_r_text(0.046, ".p", cfg = list(decimal_mark = ",")))
  expect_identical(texts, c("1,2 \u00d7 10^4^", "1,5 \u00d7 10^-7^", "-2,5 \u00d7 10^3^", "p = 0,046"))
  want <- f6_want_html(stats::setNames(paste0("A ", texts, " z."), names(cases)))
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
})

test_that("1.4.2: a wording class with .sci or .pct is a construct error, and two number-stage classes are too", {
  tbl <- list(sci_word = c("`i3`{.sci .word}", CE), pct_word = c("`i3`{.pct .word}", CE),
              sci_count = c("`i3`{.sci .count}", CE), sci_ord = c("`i3`{.sci .ord}", CE),
              sci_num = c("`f1`{.sci .num}", CE), sci_p = c("`p46`{.sci .p}", CE), date_pct = c("`dt`{.date .pct}", CE),
              p_num = c("`p46`{.p .num}", CE), date_sci = c("`dt`{.date .sci}", CE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("1.4.3, 1.6.8, N100: .date prints the default date_format, and another format string is E20", {
  cases <- c(d1 = "A `dt`{.date} z.", d2 = "A `dt2`{.date} z.")
  res <- filter_cases(cases, list(cls_block()), draft = TRUE)
  expect_cases(res, c(d1 = "A 13 November 2026 z.", d2 = "A 5 March 2024 z."))
  res2 <- filter_cases(cases, list(cls_block()), draft = TRUE, weft_yml = "date_format: \"%-d %B %Y\"")
  expect_cases(res2, c(d1 = "A 13 November 2026 z.", d2 = "A 5 March 2024 z."))
  expect_false(grepl("weft", res2$stderr, fixed = TRUE))
  res3 <- filter_cases(cases, list(cls_block()), draft = TRUE, weft_yml = "date_format: \"%Y/%m/%d\"")
  expect_cases(res3, c(d1 = paste0("A ", VE, " z."), d2 = paste0("A ", VE, " z.")))
  expect_true(grepl("not available in this version of weft.lua", res3$stderr, fixed = TRUE))
})

# ---- the wording classes (1.4.12, 1.4.16, N84) ---------------------------------------------------------

test_that("1.4.12, N84: count_threshold and word_limit come from the configuration", {
  cases <- c(c2 = "A `i2`{.count} z.", c3 = "A `i3`{.count} z.", c11 = "A `i11`{.count} z.",
             w3 = "A `i3`{.word} z.", w11 = "A `i11`{.word} z.", o3 = "A `i3`{.ord} z.")
  res <- filter_cases(cases, list(cls_block()), draft = TRUE, weft_yml = c("count_threshold: 3", "word_limit: 5"))
  expect_cases(res, c(c2 = "A two z.", c3 = "A 3 z.", c11 = "A 11 z.", w3 = "A three z.", w11 = "A 11 z.",
                      o3 = "A 3rd z."))
  res2 <- filter_cases(cases, list(cls_block()), draft = TRUE)
  expect_cases(res2, c(c2 = "A two z.", c3 = "A three z.", c11 = "A 11 z.", w3 = "A three z.",
                       w11 = "A eleven z.", o3 = "A 3rd z."))
})

test_that("1.4.12, 1.4.13: a wording class needs a whole number that is not negative, judged as printed", {
  tbl <- list(word_dec = c("`f15`{.word}", VE), word_neg = c("`ineg`{.word}", VE), word_decimal = c("`d25`{.word}", VE),
              ord_dec = c("`f15`{.ord}", VE), count_neg = c("`ineg`{.count}", VE), ord_neg = c("`ineg`{.ord}", VE),
              word_near_whole = c("`f2`{.word}", "two"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("1.4.1, 1.4.3: .no then one wording class, and .no alone, on a count", {
  tbl <- list(no_zero = c("`i0`{.no}", "no"), no_three = c("`i3`{.no}", "3"), no_word_zero = c("`i0`{.no .word}", "no"),
              no_word_three = c("`i3`{.no .word}", "three"), word_no = c("`i3`{.word .no}", "three"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("1.4.2: two wording classes, two collapse classes, two list classes are construct errors", {
  tbl <- list(word_count = c("`i3`{.word .count}", CE), word_ord = c("`i3`{.word .ord}", CE),
              count_ord = c("`i3`{.count .ord}", CE), and_or = c("`lab`{.and .or}", CE),
              pairs_range = c("`pairs`{.pairs .range}", CE), and_range = c("`r35`{.and .range}", CE),
              ul_ol = c("`lab`{.ul .ol}", CE), and_pairs = c("`pairs`{.and .pairs}", CE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

# ---- the collapse classes (1.4.4, 1.4.14, 1.4.15, N8) --------------------------------------------------

test_that("1.4.3: .pairs prints a named vector as A (1.2), B (3.4) and C (5.6)", {
  res <- filter_cases(c(p = "A `pairs`{.pairs} z.", t = "A `pairs`{.pairs trunc=\"1\"} z."), list(cls_block()), draft = TRUE)
  expect_cases(res, c(p = "A A (1.2), B (3.4) and C (5.6) z.", t = "A A (1.2) and 2 others z."))
})

test_that("1.4.4: .range prints one number for equal ends, an en dash, or 'to' when an end is negative", {
  tbl <- list(plain = c("`r35`{.range}", "3\u20135"), neg = c("`rneg`{.range}", paste0(MINUS, "5 to ", MINUS, "3")),
              same = c("`r55`{.range}", "5"), small = c("`rsmall`{.range}", "0.0"))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("1.4.4: a first end above the second, and a value of any other length, are failures; ends compare as numbers", {
  tbl <- list(out_of_order = c("`r53`{.range}", VE), raw_order = c("`rbad`{.range}", VE),
              three = c("`r123`{.range}", VE), one_element = c("`r1`{.range}", VE), scalar = c("`f1`{.range}", VE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("1.4.14: none is the text of an empty vector under a collapse class; without it the value is missing", {
  tbl <- list(and_none = c("`lnone`{.and none=\"nobody\"}", "nobody"), or_none = c("`lnone`{.or none=\"nobody\"}", "nobody"),
              no_none = c("`lnone`{.and}", NV), pairs_none = c("`lnone`{.pairs none=\"nobody\"}", "nobody"),
              empty_none = c("`lnone`{.and none=\"\"}", CE),
              none_on_num = c("`i3`{.num none=\"x\"}", CE), none_on_range = c("`r35`{.range none=\"x\"}", CE),
              none_on_val = c("`i3`{.val none=\"x\"}", CE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("1.4.14: none prints as inline text for a list class as well", {
  res <- f6_cases_html(c(ul = "`lnone`{.ul none=\"nobody\"}", ol = "`lnone`{.ol none=\"nobody\"}"), list(cls_block()))
  expect_identical(unname(res$got["ul"]), "<p>nobody</p>")
  expect_identical(unname(res$got["ol"]), "<p>nobody</p>")
})

test_that("1.4.14: a text class acts on none", {
  res <- f6_cases_html(c(a = "A `lnone`{.and .strong none=\"nobody\"} z."), list(cls_block()))
  want <- f6_want_html(c(a = "A **nobody** z."))
  expect_identical(unname(res$got["a"]), unname(want["a"]))
})

test_that("1.4.15, N84: serial_comma from _weft.yml, and the front matter's value wins", {
  cases <- c(three = "A `labc`{.and} z.", two = "A `lab`{.and} z.", or3 = "A `labc`{.or} z.",
             sep = "A `labc`{.and sep=\"; \"} z.", last = "A `labc`{.and last=\", then \"} z.")
  res <- filter_cases(cases, list(cls_block()), draft = TRUE, weft_yml = "serial_comma: true")
  expect_cases(res, c(three = "A a, b, and c z.", two = "A a and b z.", or3 = "A a, b, or c z.",
                      sep = "A a; b; and c z.", last = "A a, b, then c z."))
  res2 <- filter_cases(cases, list(cls_block()), draft = TRUE, weft_yml = "serial_comma: true",
                       head = c("---", "weft:", "  serial_comma: false", "---", ""))
  expect_cases(res2, c(three = "A a, b and c z.", two = "A a and b z.", or3 = "A a, b or c z.",
                       sep = "A a; b and c z.", last = "A a, b, then c z."))
  res3 <- filter_cases(cases, list(cls_block()), draft = TRUE)
  expect_cases(res3, c(three = "A a, b and c z.", two = "A a and b z.", or3 = "A a, b or c z.",
                       sep = "A a; b and c z.", last = "A a, b, then c z."))
})

test_that("N8: .val takes a collapse class and prints each element as the record holds it", {
  res <- filter_cases(c(strs = "A `lab`{.val .and} z.", ints = "A `l1`{.val .and} z.", floats = "A `lnum`{.val .or} z.",
                        plain = "A `l1`{.val} z."), list(cls_block()), draft = TRUE)
  expect_cases(res, c(strs = "A a and b z.", ints = "A 1, 2 and 3 z.", floats = "A 1.5 or 2 z.", plain = "A 1, 2, 3 z."))
})

# ---- .ul, .ol and .dl (1.4.6, 1.4.10, 1.4.14) ----------------------------------------------------------

test_that("1.4.6: .ul, .ol and .dl make a block when alone in their paragraph", {
  cases <- c(ul = "`lab`{.ul}", ol = "`labc`{.ol}", dl = "`dl`{.dl}", ul_one = "`s1`{.ul}",
             ol_num = "`lnum`{.num .ol digits=\"1\"}")
  res <- f6_cases_html(cases, list(cls_block()))
  texts <- c(ul = f6_r_text(c("a", "b"), ".ul"), ol = f6_r_text(c("a", "b", "c"), ".ol"),
             dl = f6_r_text(c(a = "x", b = "y"), ".dl"), ul_one = f6_r_text("north", ".ul"),
             ol_num = f6_r_text(c(1.5, 2), c(".num", ".ol"), list(digits = 1L)))
  want <- f6_want_html(texts)
  expect_identical(res$status, 0L)
  for (nm in names(cases)) {
    expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
  }
  expect_match(res$got["ul"], "<ul>", fixed = TRUE)
  expect_match(res$got["ol"], "<ol", fixed = TRUE)
  expect_match(res$got["dl"], "<dl>", fixed = TRUE)
})

test_that("1.4.6: a list class beside other text, in a list item, a block quote or a table cell, is a construct error", {
  cases <- c(inline = "A `lab`{.ul} z.", item = "- `lab`{.ol}", quote = "> `lab`{.dl}",
             cell = paste(c("| a | b |", "|---|---|", "| `lab`{.ul} | x |"), collapse = "\n"))
  res <- f6_cases_html(cases, list(cls_block()))
  for (nm in names(cases)) {
    expect_true(grepl("weft: construct error", res$got[nm], fixed = TRUE), label = nm)
  }
  expect_false(grepl("<li>a</li>", res$got["inline"], fixed = TRUE))
})

test_that("1.4.6: a text class or trunc with a list class is a construct error", {
  cases <- c(strong = "`lab`{.ul .strong}", cap = "`lab`{.ol .cap}", trunc = "`labc`{.ul trunc=\"2\"}",
             em = "`lab`{.dl .em}")
  res <- f6_cases_html(cases, list(cls_block()))
  for (nm in names(cases)) {
    expect_true(grepl("weft: construct error", res$got[nm], fixed = TRUE), label = nm)
    expect_false(grepl("<ul>|<ol|<dl>", res$got[nm]), label = paste(nm, "no list"))
  }
})

# ---- text classes (1.1.9, 1.4.1, 1.4.5) ----------------------------------------------------------------

test_that("1.1.9: a text span applies its class to the bracket's text; | and # in it are ordinary", {
  cases <- c(strong = "A [results]{.strong} z.", em = "A [results]{.em} z.", bar = "A [a | b # c]{.strong} z.",
             cap_strong = "A [the site]{.cap .strong} z.", a11 = "A [11-year]{.a} z.", a12 = "A [12-year]{.a} z.",
             a_eight = "A [eight]{.a} z.", a_cap = "A [11-year]{.a .cap} z.", cap = "A [the site]{.cap} z.")
  res <- f6_cases_html(cases)
  want <- f6_want_html(c(strong = "A **results** z.", em = "A *results* z.", bar = "A **a | b # c** z.",
                         cap_strong = "A **The site** z.", a11 = "A an 11-year z.", a12 = "A a 12-year z.",
                         a_eight = "A an eight z.", a_cap = "A An 11-year z.", cap = "A The site z."))
  expect_identical(res$status, 0L)
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.1.9: an #id on a text span is a construct error", {
  res <- f6_cases_html(c(id = "A [x]{#t .strong} z.", ok = "A [x]{.strong} z."))
  expect_true(grepl("weft: construct error", res$got["id"], fixed = TRUE))
  expect_false(grepl("weft", res$got["ok"], fixed = TRUE))
})

test_that("1.1.9: a formatter class on a bracket with no governor or marker is not a construct and passes through", {
  res <- f6_cases_html(c(a = "A [1234]{.num} z.", b = "A [1234]{.pct digits=\"1\"} z."))
  expect_identical(res$status, 0L)
  expect_match(res$got["a"], "<span class=\"num\">1234</span>", fixed = TRUE)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("1.4.1: a text class acts on a named value's final text; the class order does not matter", {
  cases <- c(strong = "A `i1`{.num .strong} z.", em = "A `i1`{.num .em} z.", cap = "A `lab`{.and .cap} z.",
             a_word = "A `i11`{.a .word} z.", word_a = "A `i11`{.word .a} z.", a_num = "A `i11`{.a .num} z.")
  res <- f6_cases_html(cases, list(cls_block()))
  want <- f6_want_html(c(strong = "A **1,234,567** z.", em = "A *1,234,567* z.", cap = "A A and b z.",
                         a_word = "A an eleven z.", word_a = "A an eleven z.", a_num = "A an 11 z."))
  for (nm in names(cases)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
})

# ---- the language (1.6.5, 1.6.7, 1.6.8, E22) -----------------------------------------------------------

test_that("1.6.8, E22: under a lang whose words weft does not ship, a wording, collapse, .a or .date class is a value error", {
  lang <- c("---", "lang: pl", "---", "")
  tbl <- list(word = c("`i3`{.word}", VE), count = c("`i3`{.count}", VE), ord = c("`i3`{.ord}", VE),
              no = c("`i0`{.no}", VE), and = c("`lab`{.and}", VE), or = c("`lab`{.or}", VE),
              pairs = c("`pairs`{.pairs}", VE), range = c("`r35`{.range}", VE), a = c("`i3`{.a}", VE),
              date = c("`dt`{.date}", VE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(cls_block()), draft = TRUE, head = lang)
  expect_cases(res, x$expected)
  for (cl in c(".word", ".count", ".ord", ".no", ".and", ".or", ".pairs", ".range", ".a", ".date")) {
    m <- sprintf("The class `%s` prints English words, and the document's `lang` is `pl` (rule 1.6.8).", cl)
    expect_true(grepl(m, res$stderr, fixed = TRUE), label = m)
  }
})

test_that("1.6.5, E22: under such a lang an n span with more than one arm is a value error; one arm and numbers still work", {
  lang <- c("---", "lang: pl", "---", "")
  cases <- c(n2 = "A [# site | # sites]{n=\"i3\"} z.", n1 = "A [# metre]{n=\"i3\"} z.", num = "A `i1`{.num} z.",
             pct = "A `p46`{.pct} z.", sci = "A `fbig`{.sci} z.", p = "A `p46`{.p} z.", val = "A `s1`{.val} z.")
  res <- filter_cases(cases, list(cls_block()), draft = TRUE, head = lang)
  expect_cases(res, c(n2 = paste0("A ", VE, " z."), n1 = "A 3 metre z.", num = "A 1,234,567 z.", pct = "A 4.6% z.",
                      sci = "A 1.2 \u00d7 10\u2074 z.", p = "A p = 0.046 z.", val = "A north z."))
  m <- paste0("A `n` span with more than one arm needs the plural rules of `pl`, which weft does not ship; ",
              "English rules are never applied to another language (rules 1.6.5, 1.6.7).")
  expect_true(grepl(m, res$stderr, fixed = TRUE))
})

test_that("1.6.7: lang is matched on its primary subtag, so en-AU and en_GB are English", {
  for (l in c("en-AU", "en_GB", "en")) {
    res <- filter_cases(c(a = "A `i3`{.word} z.", b = "A [# site | # sites]{n=\"i3\"} z."), list(cls_block()),
                        draft = TRUE, head = c("---", paste0("lang: ", l), "---", ""))
    expect_cases(res, c(a = "A three z.", b = "A 3 sites z."))
  }
})
